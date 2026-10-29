import Foundation
import PDFKit

/// Prova delle «ipotesi stimate» nei documenti (completezza dei dati), dentro `Prisma --prova-prospetti`:
/// la pagina in più nel prospetto del check-up, la slide prima della sintesi nel report, nessuna pagina in più
/// per un cliente con tutti i dati, la sezione «Dati per l'analisi» nel riesame annuale.
/// La chiama `ProvaProspetti.esegui` prima del riepilogo, con la sua funzione di verifica.
@MainActor
enum ProvaProspettiCompletezza {
    static func esegui(_ verifica: (String, Bool, String) -> Void, cartella: URL?) {
        let stato = StatoShell(persistente: false)
        stato.clienteAttivoId = "andrea"
        let completezza = stato.completezzaCliente("andrea")
        verifica("Completezza: i dati di Andrea hanno voci da completare", !(completezza?.daCompletare.isEmpty ?? true),
                 "\(completezza?.percentuale ?? -1)% · \(completezza?.daCompletare.count ?? 0) voci")

        // Prospetto del check-up: una pagina in più in fondo, con i dati mancanti e le ipotesi stimate
        let senzaIpotesi = DocumentoStampabile(stato.testiCheckUp("andrea"), report: false).pagine.count
        if let d = stato.documentoProspetto(.checkUp(report: false)), let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) {
            verifica("Ipotesi stimate nel prospetto del check-up: una pagina in più", d.pagine.count == senzaIpotesi + 1,
                     "\(senzaIpotesi) → \(d.pagine.count) pagine")
            verifica("Ipotesi stimate nel prospetto del check-up: PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count,
                     "\(documento.pageCount) pagine")
            let pagine = StampaCarta.testo(pdf).map { ProvaProspetti.spazi($0) }
            let ultima = pagine.last ?? ""
            let conTitolo = ultima.contains(TestiIpotesiStimate.titoloProspetto)
            let conOrizzonte = ultima.contains("Orizzonte temporale")
            verifica("Ipotesi stimate nel prospetto del check-up: l'ultima pagina con «\(TestiIpotesiStimate.titoloProspetto)» e l'orizzonte",
                     conTitolo && conOrizzonte, "")
            // La numerazione conta anche la pagina nuova
            verifica("Ipotesi stimate nel prospetto del check-up: «pag. \(d.pagine.count) di \(d.pagine.count)»",
                     ultima.contains("pag. \(d.pagine.count) di \(d.pagine.count)"), "")
            if let cartella { try? pdf.write(to: cartella.appendingPathComponent("ipotesi-andrea-prospetto.pdf")) }
        } else {
            verifica("Ipotesi stimate nel prospetto del check-up: PDF creato", false, "")
        }

        // Report del check-up: la slide «Le ipotesi da confermare insieme», subito prima della sintesi
        if let d = stato.documentoProspetto(.checkUp(report: true)), let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) {
            let pagine = StampaCarta.testo(pdf).map { ProvaProspetti.spazi($0) }
            verifica("Ipotesi stimate nel report del check-up: PDF di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count,
                     "\(documento.pageCount) pagine")
            let penultima = pagine.count >= 2 ? pagine[pagine.count - 2] : ""
            let slideIpotesi = penultima.contains(TestiIpotesiStimate.titoloReport)
            let sintesi = (pagine.last ?? "").contains("Il tuo check-up, in poche righe")
            verifica("Ipotesi stimate nel report del check-up: «\(TestiIpotesiStimate.titoloReport)» prima della sintesi",
                     slideIpotesi && sintesi, "")
            if let cartella { try? pdf.write(to: cartella.appendingPathComponent("ipotesi-andrea-report.pdf")) }
        } else {
            verifica("Ipotesi stimate nel report del check-up: PDF creato", false, "")
        }

        // Previdenza e protezione: la pagina in più quando le loro analisi girano su ipotesi
        let previdenza = completezza?.ipotesi(per: .previdenza) ?? []
        let senzaPrevidenza = DocumentoStampabile(stato.testiPrevidenza("andrea"), report: false).pagine.count
        let conPrevidenza = stato.documentoProspetto(.previdenza(report: false))?.pagine.count ?? 0
        verifica("Ipotesi stimate nel prospetto della previdenza: \(previdenza.isEmpty ? "nessuna pagina" : "una pagina") in più",
                 conPrevidenza == senzaPrevidenza + (previdenza.isEmpty ? 0 : 1), "\(senzaPrevidenza) → \(conPrevidenza) pagine")
        let protezione = completezza?.ipotesi(per: .protezione) ?? []
        let senzaProtezione = DocumentoStampabile(stato.testiProtezione("andrea"), report: false).pagine.count
        let conProtezione = stato.documentoProspetto(.protezione(report: false))?.pagine.count ?? 0
        verifica("Ipotesi stimate nel prospetto della protezione: \(protezione.isEmpty ? "nessuna pagina" : "una pagina") in più",
                 conProtezione == senzaProtezione + (protezione.isEmpty ? 0 : 1), "\(senzaProtezione) → \(conProtezione) pagine")

        // Un cliente con tutti i dati (il caso C4 delle prove dei calcoli): nessuna pagina e nessuna slide in più
        let completo = StatoShell(persistente: false)
        let (cliente, etf, analisi) = clienteCompleto()
        completo.salvaCliente(cliente)
        completo.salvaPosizione(etf)
        completo.salvaAnalisi(cliente.id, analisi)
        completo.clienteAttivoId = cliente.id
        let k = completo.completezzaCliente(cliente.id)
        let restanti: [String] = k?.daCompletare.map { $0.id } ?? []
        verifica("Completezza: il cliente con tutti i dati è al 100%", k?.percentuale == 100 && restanti.isEmpty,
                 "\(k?.percentuale ?? -1)% · \(restanti.joined(separator: ", "))")
        for report in [false, true] {
            let senza = DocumentoStampabile(completo.testiCheckUp(cliente.id), report: report).pagine.count
            let con = completo.documentoProspetto(.checkUp(report: report))?.pagine.count ?? 0
            verifica("Dati completi: nessuna \(report ? "slide" : "pagina") di ipotesi nel \(report ? "report" : "prospetto") del check-up",
                     con == senza, "\(senza) → \(con) pagine")
        }

        // Riesame annuale: la sezione «Dati per l'analisi» prima delle domande
        stato.clienteAttivoId = "giulia"
        if let c = stato.contenutoProspetto(.riesame) {
            let titoli = c.blocchi.compactMap { b -> String? in
                if case .sezione(_, let titolo) = b { return titolo } else { return nil }
            }
            let dati = titoli.firstIndex(of: "Dati per l'analisi")
            let domande = titoli.firstIndex(of: "Domande da fare")
            // Condizioni separate: il controllo dei tipi resta leggero
            var primaDelleDomande = false
            if let x = dati, let y = domande { primaDelleDomande = x < y }
            verifica("Riesame di Giulia: la sezione «Dati per l'analisi» prima delle domande",
                     primaDelleDomande, titoli.joined(separator: " · "))
        } else {
            verifica("Riesame di Giulia composto", false, "")
        }
    }

    /// Il cliente «completo» delle prove dei calcoli (C4): anagrafica, reddito, lavoro, profilo recente,
    /// un ETF con valore, costi, SRI e rendimento, l'Analisi 360 confermata per previdenza e protezione.
    private static func clienteCompleto() -> (Cliente, Posizione, Analisi360) {
        let oggi = AiutiProva.oggi
        let cal = Calendar(identifier: .gregorian)
        var c = Cliente(id: "prova", nome: "Prova Completa", iniziali: "PC", tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: oggi)
        c.dataNascita = AiutiProva.data(1980, 5, 10)
        c.statoCivile = .coniugato
        c.profilo.redditoLordoAnnuo = 40_000
        c.profilo.redditoNettoAnnuo = 28_000
        c.profilo.lavoro = DatiLavoro(tipo: .dipendente, redditoLavoro: 40_000, anniContributi: 20, annoPrimoContributo: 2006,
                                      montanteContributivo: 200_000)
        c.profilo.propensione = .moderata
        c.profilo.aggiornatoIl = cal.date(byAdding: .month, value: -5, to: oggi)
        c.profilo.orizzonteAnni = 10
        let etf = AiutiProva.posizione("ETF prova", .investimento, 10_000) {
            $0.tipologia = "ETF"
            $0.dataValore = cal.date(byAdding: .month, value: -3, to: oggi)
            $0.costoAnnuo = 0.2
            $0.sri = 4
            $0.rendimentoAtteso = 5
        }
        var a = Analisi360()
        a.confermate = [.previdenza, .protezione]
        return (c, etf, a)
    }
}
