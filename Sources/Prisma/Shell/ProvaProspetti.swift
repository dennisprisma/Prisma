import Foundation
import PDFKit

/// Prova dei prospetti (`Prisma --prova-prospetti [cartella]`), eseguita dal workflow.
/// Compone i prospetti dei clienti di prova, controlla le cifre contro i motori di calcolo,
/// verifica che l'impaginazione non superi mai la pagina e crea i PDF (salvati nella cartella, se indicata).
@MainActor
enum ProvaProspetti {
    static func esegui(cartella: URL?) -> Int32 {
        var errori = 0
        func verifica(_ nome: String, _ ok: Bool, _ dettaglio: String = "") {
            print("\(ok ? "OK   " : "ERRORE") \(nome)\(dettaglio.isEmpty ? "" : ": \(dettaglio)")")
            if !ok { errori += 1 }
        }
        if let cartella { try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true) }

        let dati = DatiPrisma.demo()
        let casi: [(String, String, SceltaProspetto)] = [
            ("quadro-giulia", "giulia", .quadro),
            ("proposta-giulia-previdenza", "giulia", .posizione("pos-giulia-piano-previdenziale-integrativo")),
            ("posizione-giulia-etf", "giulia", .posizione("pos-giulia-etf-azionario-globale")),
            ("copertura-marco-infortuni", "marco", .posizione("pos-marco-infortuni-famiglia")),
            ("quadro-marco", "marco", .quadro),
        ]
        var tutti = casi
        let voci = ElementoConfronto.elenco(dati, cliente: "marco")
        let coppia = ElementoConfronto.coppia(voci, a: nil, b: nil, posizioni: dati.posizioni.filter { $0.clienteId == "marco" })
        if let a = coppia.0, let b = coppia.1 {
            tutti.append(("confronto-marco", "marco", .confronto(a.voce, b.voce)))
        } else {
            verifica("Confronto di prova per Marco", false)
        }

        for (nome, cliente, scelta) in tutti {
            guard let c = CompositoreProspetti.componi(scelta, dati: dati, cliente: cliente) else {
                verifica("Prospetto \(nome) composto", false)
                continue
            }
            let pagine = ImpaginatoreProspetto.pagine(c)
            // Ogni blocco della scelta finisce in pagina, e nessuna pagina va oltre lo spazio utile
            let blocchiTabella = c.blocchi.reduce(0) { n, b in if case .tabella(let t) = b { return n + t.righe.count } else { return n } }
            let righeImpaginate = pagine.flatMap { $0 }.reduce(0) { n, b in if case .tabella(let t) = b.blocco { return n + t.righe.count } else { return n } }
            verifica("\(nome): tutte le righe delle tabelle in pagina", blocchiTabella == righeImpaginate, "\(righeImpaginate) di \(blocchiTabella)")
            for (i, p) in pagine.enumerated() {
                let spazio = Misure.Carta.pagina.height - Misure.Carta.margineAlto - Misure.Carta.margineBasso - Misure.Carta.piede
                    - (i == 0 ? Misure.Carta.testataPrima : Misure.Carta.testataCorrente)
                let usato = p.reduce(0) { $0 + $1.altezza } + CGFloat(max(0, p.count - 1)) * Misure.Carta.spazioBlocchi
                if usato > spazio + 0.5 {
                    verifica("\(nome): pagina \(i + 1) entro i margini", false, "\(Int(usato)) su \(Int(spazio)) punti")
                }
                if let ultimo = p.last?.blocco, ultimo.eTitolo {
                    verifica("\(nome): pagina \(i + 1) non finisce con un titolo", false)
                }
            }
            guard let pdf = StampaCarta.pdf(c), let documento = PDFDocument(data: pdf) else {
                verifica("\(nome): PDF creato", false)
                continue
            }
            verifica("\(nome): PDF di \(pagine.count) pagine", documento.pageCount == pagine.count, "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
            // Spazi unificati: il PDF può restituire spazi normali al posto di quelli non divisibili
            let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
            verifica("\(nome): nel PDF il nome del cliente e il titolo",
                     testo.contains(c.cliente) && testo.contains(c.titolo.prefix(18)))
            if let cartella {
                try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf"))
            }

            // Le cifre del prospetto sono quelle dei motori
            switch scelta {
            case .posizione(let id):
                guard let p = dati.posizioni.first(where: { $0.id == id }) else { break }
                let par = ParametriProiezione(posizione: p, orizzonteCliente: dati.clienti.first { $0.id == cliente }?.profilo.orizzonteAnni)
                if p.area.proiettabile {
                    let netto = spazi(Formati.euro(MotoreProiezione.calcola(par).netto))
                    verifica("\(nome): netto atteso \(netto) nel PDF", testo.contains(netto))
                    let anni = c.blocchi.compactMap { b -> TabellaProspetto? in
                        if case .tabella(let t) = b, t.colonne.first?.titolo == "Anno" { return t } else { return nil }
                    }.first
                    verifica("\(nome): anno per anno da oggi alla fine", anni?.righe.count == par.anni + 1, "\(anni?.righe.count ?? 0) righe")
                } else if p.area == .protezione, let mille = CompositoreProspetti.costoPerMille(p) {
                    verifica("\(nome): costo per 1.000 € assicurati", testo.contains(spazi(Formati.euroDecimali(mille))), Formati.euroDecimali(mille))
                }
            case .quadro:
                let r = RiepilogoPosizioni(dati.posizioni.filter { $0.clienteId == cliente && $0.stato != .chiusa })
                verifica("\(nome): patrimonio netto \(Formati.euro(r.patrimonioNetto)) nel PDF", testo.contains(spazi(Formati.euro(r.patrimonioNetto))))
                verifica("\(nome): entrambi i canali nella ripartizione", testo.contains("Alleanza") && testo.contains("Indipendente"))
            case .confronto:
                verifica("\(nome): differenza B − A presente", testo.contains("B − A"))
            case .valutazione:
                break
            }
        }

        // Valutazione di un investimento: prospetto (A4 verticale) e report (A4 orizzontale)
        if let v = dati.valutazioni.first, let p = dati.prodotti.first(where: { $0.id == v.prodottoId }), let c = p.condizioni {
            let t = TestiValutazione(v, prodotto: p, condizioni: c)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = report ? "valutazione-report" : "valutazione-prospetto"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 12 : 4),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                for cifra in ["€ 52.227", "€ 50.178", "€ 47.168"] {
                    verifica("\(nome): incasso al 13° mese \(cifra) nel PDF", testo.contains(cifra))
                }
                verifica("\(nome): intestatari e consulente", testo.contains(v.intestatari) && testo.contains(TestiValutazione.consulente))
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        } else {
            verifica("Valutazione di prova presente", false)
        }

        if errori == 0 {
            print("OK: prospetti verificati")
            return 0
        }
        print("ERRORE: \(errori) verifiche non riuscite")
        return 1
    }

    static func spazi(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
