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
            ("proposta-giulia-previdenza", "giulia", .posizione("pos-giulia-piano-previdenziale-integrativo")),
            ("posizione-giulia-etf", "giulia", .posizione("pos-giulia-etf-azionario-globale")),
            ("copertura-marco-infortuni", "marco", .posizione("pos-marco-infortuni-famiglia")),
        ]
        var tutti = casi
        tutti.append(("portafoglio", "", .portafoglio))
        tutti.append(("riesame-giulia", "giulia", .riesame))
        tutti.append(("riesame-marco", "marco", .riesame))
        // Il riesame vuole la fonte completa del cliente: lo compone lo stato dell'app
        let statoRiesame = StatoShell(persistente: false)
        let voci = ElementoConfronto.elenco(dati, cliente: "marco")
        let coppia = ElementoConfronto.coppia(voci, a: nil, b: nil, posizioni: dati.posizioni.filter { $0.clienteId == "marco" })
        if let a = coppia.0, let b = coppia.1 {
            tutti.append(("confronto-marco", "marco", .confronto(a.voce, b.voce)))
        } else {
            verifica("Confronto di prova per Marco", false)
        }

        for (nome, cliente, scelta) in tutti {
            var composto = CompositoreProspetti.componi(scelta, dati: dati, cliente: cliente)
            if case .riesame = scelta {
                statoRiesame.clienteAttivoId = cliente
                composto = statoRiesame.contenutoProspetto(scelta)
            }
            guard let c = composto else {
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
            case .confronto:
                verifica("\(nome): differenza B − A presente", testo.contains("B − A"))
            case .portafoglio:
                let pf = MotorePortafoglio.calcola(dati.posizioni, clienti: dati.clienti)
                let totale = spazi(Formati.euro(pf.riepilogo.attivita))
                verifica("\(nome): patrimonio seguito \(totale) nel PDF", testo.contains(totale))
                verifica("\(nome): tutti i clienti e i due canali nel PDF",
                         dati.clienti.allSatisfy { testo.contains($0.nome) } && Canale.allCases.allSatisfy { testo.contains($0.nomeBreve) })
            case .riesame:
                verifica("\(nome): ordine del giorno e domande nel PDF", testo.contains("Ordine del giorno") && testo.contains("Domande da fare"))
            case .valutazione, .resoconto, .sostituzione, .previdenza, .protezione, .obiettivo, .liquidita, .checkUp, .resistenza, .costi, .successione, .patrimonio, .fascicolo:
                break
            }
        }

        // PDF protetto da password: chiuso senza, si apre con la password giusta, stesse pagine
        if let c = CompositoreProspetti.componi(.portafoglio, dati: dati, cliente: ""), let chiaro = StampaCarta.pdf(c),
           let cifrato = StampaCarta.protetto(chiaro, password: "15031985"), let doc = PDFDocument(data: cifrato) {
            verifica("PDF protetto: chiuso senza password", doc.isLocked && doc.isEncrypted)
            verifica("PDF protetto: la password sbagliata non lo apre", !doc.unlock(withPassword: "00000000"))
            verifica("PDF protetto: si apre con la password", doc.unlock(withPassword: "15031985") && doc.pageCount == (PDFDocument(data: chiaro)?.pageCount ?? -1))
        } else {
            verifica("PDF protetto creato", false)
        }
        var regole = ImpostazioniPDF()
        var nato = dati.clienti[0]
        nato.dataNascita = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1985, month: 3, day: 15, hour: 12))
        nato.codiceFiscale = "rssgli85c55h501z"
        verifica("PDF protetto: password dalla data di nascita", regole.password(per: nato) == "15031985", regole.password(per: nato))
        regole.regola = .codiceFiscale
        verifica("PDF protetto: password dal codice fiscale", regole.password(per: nato) == "RSSGLI85C55H501Z", regole.password(per: nato))

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

        // Resoconto delle posizioni in essere: prospetto e report per ogni cliente con posizioni in essere
        for cliente in dati.clienti where dati.posizioni.contains(where: { $0.clienteId == cliente.id && $0.stato == .inEssere }) {
            let t = TestiResoconto(dati.posizioni.filter { $0.clienteId == cliente.id }, cliente: cliente, prodotti: dati.prodotti)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "resoconto-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 5 : 3),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                let netto = spazi(CifreDoc.euro(t.e.riepilogo.patrimonioNetto))
                verifica("\(nome): patrimonio netto \(netto) nel PDF", testo.contains(netto))
                if t.e.versato > 0 {
                    let valore = spazi(CifreDoc.euro(t.e.valoreFinanziario))
                    verifica("\(nome): valore delle posizioni finanziarie \(valore) nel PDF", testo.contains(valore))
                }
                verifica("\(nome): cliente e consulente", testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                // Nel report l'occhiello spaziato non si legge come testo: si cerca il sottotitolo
                if !t.andamenti.isEmpty {
                    verifica("\(nome): andamento rispetto all'atteso (\(t.andamenti.count) posizioni)", testo.lowercased().contains(report ? "ci aspettavamo" : "rispetto all"))
                }
                for c in t.e.canaliPresenti {
                    verifica("\(nome): etichetta \(c.nomeBreve) nel PDF", testo.contains(c.nome))
                }
                if !report {
                    // Ogni posizione in essere compare nel prospetto
                    let mancanti = t.e.voci.filter { !testo.contains(spazi($0.posizione.nome)) }.map(\.posizione.nome)
                    verifica("\(nome): tutte le posizioni in essere", mancanti.isEmpty, mancanti.joined(separator: ", "))
                }
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Check-up del primo incontro: prospetto e report per ogni cliente
        for cliente in dati.clienti {
            let mie = dati.posizioni.filter { $0.clienteId == cliente.id }
            let analisi = Analisi360(cliente: cliente, posizioni: mie)
            let e = MotoreCheckUp.calcola(cliente: cliente, posizioni: mie, analisi: analisi, obiettivi: dati.obiettivi.filter { $0.clienteId == cliente.id })
            verifica("checkup-\(cliente.id): sette indicatori", e.indicatori.count == 7)
            let t = TestiCheckUp(e)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "checkup-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 6 : 2),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("\(nome): patrimonio netto \(CifreDoc.euro(e.riepilogo.patrimonioNetto)) nel PDF", testo.contains(spazi(CifreDoc.euro(e.riepilogo.patrimonioNetto))))
                verifica("\(nome): cliente e consulente", testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Capitale in scadenza e liquidità: prospetto e report per ogni cliente
        for cliente in dati.clienti {
            let mie = dati.posizioni.filter { $0.clienteId == cliente.id }
            let analisi = Analisi360(cliente: cliente, posizioni: mie)
            let e = MotoreLiquidita.calcola(mie, obiettivi: dati.obiettivi.filter { $0.clienteId == cliente.id }, analisi: analisi.protezione, prodotti: dati.prodotti)
            verifica("liquidita-\(cliente.id): i salvadanai sommano il disponibile", abs(e.salvadanai.reduce(0) { $0 + $1.importo } - e.totale) < 0.01)
            let t = TestiLiquidita(e, cliente: cliente)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "liquidita-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 5 : 2),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("\(nome): totale \(CifreDoc.euro(e.totale)) nel PDF", testo.contains(spazi(CifreDoc.euro(e.totale))))
                verifica("\(nome): cliente e consulente", testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Piano obiettivo: prospetto e report per ogni obiettivo di prova
        for o in dati.obiettivi {
            let mie = dati.posizioni.filter { $0.clienteId == o.clienteId }
            let cliente = dati.clienti.first { $0.id == o.clienteId }
            let e = MotoreObiettivo.calcola(o, posizioni: mie)
            let altri = dati.obiettivi.filter { $0.clienteId == o.clienteId }.map { ($0, AvanzamentoObiettivo($0, posizioni: mie)) }
            let t = TestiObiettivo(e, cliente: cliente, altri: altri)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "\(o.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 5 : 3),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("\(nome): proiezione \(CifreDoc.euro(e.proiezione)) e titolo nel PDF",
                         testo.contains(spazi(CifreDoc.euro(e.proiezione))) && testo.contains(spazi(o.titolo)))
                verifica("\(nome): cliente e consulente", testo.contains(cliente?.nome ?? "?") && testo.contains(TestiValutazione.consulente))
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Protezione della famiglia: prospetto e report per ogni cliente
        for cliente in dati.clienti {
            let mie = dati.posizioni.filter { $0.clienteId == cliente.id }
            let analisi = Analisi360(cliente: cliente, posizioni: mie)
            let e = MotoreProtezioneFamiglia.calcola(mie, cliente: cliente, analisi: analisi.protezione)
            let t = TestiProtezione(e, cliente: cliente)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "protezione-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 7 : 3),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("\(nome): fabbisogno \(CifreDoc.euro(e.fabbisogno)) nel PDF", testo.contains(spazi(CifreDoc.euro(e.fabbisogno))))
                verifica("\(nome): cliente e consulente", testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                if !report {
                    let mancanti = (e.coperture + e.proposte).filter { !testo.contains(spazi($0.nome)) }.map(\.nome)
                    verifica("\(nome): tutte le coperture", mancanti.isEmpty, mancanti.joined(separator: ", "))
                }
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Piano previdenziale: prospetto e report per ogni cliente con un piano in essere o proposto
        for cliente in dati.clienti {
            let mie = dati.posizioni.filter { $0.clienteId == cliente.id }
            guard mie.contains(where: { $0.regime == .previdenza && $0.stato != .chiusa }) else { continue }
            let analisi = Analisi360(cliente: cliente, posizioni: mie)
            let e = MotorePrevidenza.calcola(mie, cliente: cliente, analisi: analisi.previdenza)
            let t = TestiPrevidenza(e, cliente: cliente)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "previdenza-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 7 : 3),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("\(nome): divario \(CifreDoc.euro(e.divario)) nel PDF", testo.contains(spazi(CifreDoc.euro(e.divario))))
                verifica("\(nome): cliente e consulente", testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                if !report {
                    let mancanti = e.piani.filter { !testo.contains(spazi($0.posizione.nome)) }.map(\.posizione.nome)
                    verifica("\(nome): tutti i piani", mancanti.isEmpty, mancanti.joined(separator: ", "))
                }
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Prova di resistenza: prospetto e report per ogni cliente con posizioni in essere
        for cliente in dati.clienti {
            let mie = dati.posizioni.filter { $0.clienteId == cliente.id }
            let r = MotoreResistenza.calcola(mie, profilo: cliente.profilo)
            guard !r.vuota else { continue }
            let t = TestiResistenza(r, cliente: cliente)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "resistenza-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 4 : 2),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("\(nome): cliente e consulente", testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                if let m = t.mercati, !m.voci.isEmpty {
                    verifica("\(nome): perdita sui mercati \(CifreDoc.togli(m.perdita)) nel PDF", testo.contains(spazi(CifreDoc.togli(m.perdita))))
                    if !report {
                        let mancanti = m.voci.filter { !testo.contains(spazi($0.posizione.nome)) }.map(\.posizione.nome)
                        verifica("\(nome): tutte le posizioni esposte ai mercati", mancanti.isEmpty, mancanti.joined(separator: ", "))
                    }
                }
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Costo degli investimenti: prospetto e report per ogni cliente con posizioni finanziarie con i costi
        for cliente in dati.clienti {
            let mie = dati.posizioni.filter { $0.clienteId == cliente.id }
            let a = MotoreCosti.calcola(mie, prodotti: dati.prodotti, cliente: cliente.id)
            guard !a.voci.isEmpty else { continue }
            let t = TestiCosti(a, cliente: cliente)
            verifica("costi-\(cliente.id): il grafico parte dallo stesso valore e i costi tolgono", t.serie.con.first == t.serie.senza.first
                     && (t.serie.con.last ?? 0) < (t.serie.senza.last ?? 0))
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "costi-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 5 : 2),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("\(nome): cliente e consulente", testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                verifica("\(nome): costi di quest'anno \(CifreDoc.euro(a.euroAnno)) nel PDF", testo.contains(spazi(CifreDoc.euro(a.euroAnno))))
                if !report {
                    let mancanti = a.voci.filter { !testo.contains(spazi($0.posizione.nome)) }.map(\.posizione.nome)
                    verifica("\(nome): tutte le posizioni con i costi", mancanti.isEmpty, mancanti.joined(separator: ", "))
                }
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Passaggio generazionale: prospetto e report per ogni cliente con posizioni in essere
        for cliente in dati.clienti {
            let mie = dati.posizioni.filter { $0.clienteId == cliente.id }
            let su = MotoreSuccessione.calcola(cliente: cliente, posizioni: mie)
            guard !su.vuota else { continue }
            let t = TestiSuccessione(su, cliente: cliente)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "successione-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 5 : 2),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("\(nome): cliente e consulente", testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                verifica("\(nome): ai beneficiari \(CifreDoc.euro(su.fuoriAsse)) nel PDF", testo.contains(spazi(CifreDoc.euro(su.fuoriAsse))))
                if !report {
                    let mancanti = su.voci.filter { !testo.contains(spazi($0.posizione.nome)) }.map(\.posizione.nome)
                    verifica("\(nome): tutte le posizioni", mancanti.isEmpty, mancanti.joined(separator: ", "))
                    let eredi = su.eredi.filter { !testo.contains(spazi($0.nome)) }.map(\.nome)
                    verifica("\(nome): tutti gli eredi", eredi.isEmpty, eredi.joined(separator: ", "))
                }
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Patrimonio nel tempo: prospetto e report per ogni cliente con posizioni
        for cliente in dati.clienti {
            let mie = dati.posizioni.filter { $0.clienteId == cliente.id }
            let pn = MotorePatrimonio.calcola(mie, obiettivi: dati.obiettivi.filter { $0.clienteId == cliente.id })
            guard !pn.vuoto else { continue }
            let t = TestiPatrimonio(pn, posizioni: mie, cliente: cliente)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "patrimonio-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 5 : 2),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("\(nome): cliente e consulente", testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                verifica("\(nome): patrimonio di oggi \(CifreDoc.euro(pn.nettoOggi)) nel PDF", testo.contains(spazi(CifreDoc.euro(pn.nettoOggi))))
                if !report, pn.conProposte != nil {
                    let mancanti = pn.proposte.filter { !testo.contains(spazi($0.nome)) }.map(\.nome)
                    verifica("\(nome): tutte le proposte aperte", mancanti.isEmpty, mancanti.joined(separator: ", "))
                }
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Fascicolo dell'incontro: copertina, indice e i report scelti, in ordine
        do {
            let stato = StatoShell(persistente: false)
            stato.clienteAttivoId = "marco"
            stato.sceltaFascicolo = [.resoconto, .patrimonio, .successione]
            let parti = [SceltaProspetto.resoconto(report: true), .patrimonio(report: true), .successione(report: true)].compactMap { stato.documentoProspetto($0) }
            if let d = stato.documentoFascicolo(), let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) {
                let attese = 2 + parti.reduce(0) { $0 + $1.pagine.count }
                verifica("fascicolo-marco: \(attese) pagine (copertina, indice, tre report)", documento.pageCount == attese, "\(documento.pageCount) pagine")
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                verifica("fascicolo-marco: l'indice elenca i documenti", parti.allSatisfy { testo.contains(spazi($0.titolo)) })
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("fascicolo-marco.pdf")) }
            } else {
                verifica("fascicolo-marco: PDF creato", false)
            }
            stato.sceltaFascicolo = []
            verifica("Fascicolo vuoto: nessun documento", stato.documentoFascicolo() == nil)
        }

        // Sostituzione o confronto: prospetto e report per ogni cliente con una coppia da confrontare
        for cliente in dati.clienti {
            let mie = dati.posizioni.filter { $0.clienteId == cliente.id }
            guard let coppia = MotoreSostituzione.coppia(mie),
                  let pa = mie.first(where: { $0.id == coppia.0 }), let pb = mie.first(where: { $0.id == coppia.1 }) else { continue }
            let e = MotoreSostituzione.calcola(attuale: pa, alternativa: pb, prodotti: dati.prodotti, orizzonteCliente: cliente.profilo.orizzonteAnni)
            let t = TestiSostituzione(e, cliente: cliente)
            verifica("sostituzione-\(cliente.id): serie di \(e.anni + 1) anni", e.serie.count == e.anni + 1)
            for report in [false, true] {
                let d = DocumentoStampabile(t, report: report)
                let nome = "sostituzione-\(cliente.id)-\(report ? "report" : "prospetto")"
                guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                    verifica("\(nome): PDF creato", false)
                    continue
                }
                verifica("\(nome): PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count && d.pagine.count >= (report ? 6 : 3),
                         "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
                let orizzontale = (documento.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) > (documento.page(at: 0)?.bounds(for: .mediaBox).height ?? 0)
                verifica("\(nome): \(report ? "A4 orizzontale" : "A4 verticale")", orizzontale == report)
                let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
                if let f = e.finale {
                    for cifra in [CifreDoc.euro(f.nettoResto), CifreDoc.euro(f.nettoCambio)] {
                        verifica("\(nome): netto finale \(cifra) nel PDF", testo.contains(spazi(cifra)))
                    }
                }
                verifica("\(nome): le due posizioni, il cliente e il consulente",
                         testo.contains(spazi(pa.nome)) && testo.contains(spazi(pb.nome)) && testo.contains(cliente.nome) && testo.contains(TestiValutazione.consulente))
                for c in Set([pa.canale, pb.canale]) {
                    verifica("\(nome): etichetta \(c.nomeBreve) nel PDF", testo.contains(c.nome))
                }
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(nome).pdf")) }
            }
        }

        // Il commento del consulente: pagina «Due parole per te» dopo la copertina, solo nei report
        let stato = StatoShell(persistente: false)
        stato.dati.impostazioni.eve.motore = .sintesi
        stato.clienteAttivoId = "giulia"
        for scelta in [SceltaProspetto.checkUp(report: true), .previdenza(report: true), .resoconto(report: true)] {
            let senza = stato.documentoProspetto(scelta)?.pagine.count ?? 0
            stato.scriviCommentoConEve(scelta)
            let testoCommento = stato.commento(scelta)?.testo ?? ""
            guard let d = stato.documentoProspetto(scelta), let pdf = StampaCarta.pdf(d) else {
                verifica("Commento in «\(scelta.tipo.nome)»: PDF creato", false)
                continue
            }
            let testo = spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
            let primaRiga = testoCommento.components(separatedBy: "\n").first ?? "—"
            verifica("Commento in «\(scelta.tipo.nome)»: una pagina in più, con il commento e la firma",
                     d.pagine.count == senza + 1 && testo.contains("Due parole per te") && testo.contains(spazi(primaRiga)),
                     "\(senza) → \(d.pagine.count) pagine")
            if case .checkUp = scelta {
                verifica("Il prospetto del check-up non ha il commento", stato.documentoProspetto(.checkUp(report: false)).map {
                    !(spazi(StampaCarta.testo(StampaCarta.pdf($0) ?? Data()).joined()).contains("Due parole per te"))
                } ?? false)
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("checkup-giulia-report-commento.pdf")) }
            }
        }

        if errori == 0 {
            print("OK: prospetti verificati")
            return 0
        }
        print("ERRORE: \(errori) verifiche non riuscite")
        return 1
    }

    static func spazi(_ s: String) -> String {
        // Le legature tipografiche (ﬁ, ﬃ…) tornano lettere separate: "autosufficienza" resta cercabile
        let legature = ["\u{FB00}": "ff", "\u{FB01}": "fi", "\u{FB02}": "fl", "\u{FB03}": "ffi", "\u{FB04}": "ffl"]
        return legature.reduce(s.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")) {
            $0.replacingOccurrences(of: $1.key, with: $1.value)
        }
    }
}
