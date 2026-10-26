import Foundation

/// I testi del piano previdenziale, ricavati dai numeri. Il report si rivolge al cliente con il tu.
struct TestiPrevidenza {
    let e: EsitoPianoPrevidenziale
    let cliente: String
    let data: Date

    init(_ e: EsitoPianoPrevidenziale, cliente: Cliente?, data: Date = Date()) {
        self.e = e
        self.cliente = cliente?.nome ?? "Cliente"
        self.data = data
    }

    static let titolo = "Piano previdenziale"
    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Stime illustrative in euro di oggi: la pensione pubblica va verificata sull'estratto conto INPS, la rendita sui coefficienti del piano."

    var ruoloConsulente: String {
        let canali = Set(e.piani.map(\.posizione.canale))
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Alleanza Assicurazioni · consulenza finanziaria"
    }

    var canali: [Canale] { Canale.allCases.filter { c in e.piani.contains { $0.posizione.canale == c } } }

    var anniAllaPensione: String { e.anniAccumulo == 1 ? "1 anno" : "\(e.anniAccumulo) anni" }

    /// Euro al mese: "1.400 € al mese".
    static func mese(_ v: Double) -> String { "\(CifreDoc.euro(v)) al mese" }

    var titoloDivario: String {
        e.divario < 1 ? "La pensione pubblica copre il reddito che desideri"
            : "Alla pensione ti mancheranno circa \(Self.mese(e.divario))"
    }

    var sottotitoloDivario: String {
        "Desideri \(Self.mese(e.redditoDesiderato)) netti, la pensione pubblica stimata è di \(Self.mese(e.pensionePubblica)). Importi in euro di oggi, tra \(anniAllaPensione), a \(e.etaPensione) anni."
    }

    var titoloCopertura: String {
        guard e.divario >= 1 else { return "I tuoi piani aggiungono \(Self.mese(e.renditaInEssere))" }
        if e.inEssere.isEmpty { return "Oggi nessun piano integra la pensione pubblica" }
        let quota = min(100, e.renditaInEssere / e.divario * 100)
        return "I piani di oggi coprono il \(CifreDoc.percento(quota, decimali: 0)) di ciò che manca"
    }

    var titoloColmare: String {
        if e.divarioConProposte < 1 { return e.proposte.isEmpty ? "Il divario è già coperto" : "Con la proposta il divario è coperto" }
        if let v = e.versamentoMancante { return "Per colmare il resto servono circa \(CifreDoc.euro(v)) al mese in più" }
        return "Restano \(Self.mese(e.divarioConProposte)) da coprire"
    }

    var titoloFisco: String {
        guard e.aliquotaMarginale != nil else { return "Il vantaggio fiscale dei versamenti" }
        let r = e.proposte.isEmpty ? e.risparmioOggi : e.risparmioConProposte
        return r > 0.5 ? "Ogni anno lo Stato ti restituisce circa \(CifreDoc.euro(r))" : "Il vantaggio fiscale dei versamenti"
    }

    var sottotitoloFisco: String {
        guard let a = e.aliquotaMarginale else { return "Indicando il reddito lordo annuo calcoliamo quanto si risparmia di IRPEF con i versamenti." }
        return "I versamenti si deducono dal reddito fino a \(CifreDoc.euroCentesimi(RegoleFiscali.limiteDeducibilita)) l'anno: con la tua aliquota IRPEF del \(CifreDoc.condizione(a)) ogni 100 € versati ne costano \(CifreDoc.euro(100 - a))."
    }

    /// I messaggi della sintesi.
    var sintesi: [(String, String)] {
        var punti: [(String, String)] = [("Il divario", e.divario < 1 ? "La pensione pubblica stimata copre il reddito desiderato." : "Mancano circa \(Self.mese(e.divario)) rispetto al reddito che desideri.")]
        if !e.inEssere.isEmpty {
            punti.append(("I piani di oggi", "Aggiungono circa \(Self.mese(e.renditaInEssere)) per \(e.anniIntegrazione) anni."))
        }
        if !e.proposte.isEmpty {
            punti.append(("Con la proposta", "Altri \(Self.mese(e.renditaProposte)): restano \(Self.mese(e.divarioConProposte)) da coprire."))
        } else if let v = e.versamentoMancante {
            punti.append(("Per colmare il resto", "Circa \(CifreDoc.euro(v)) al mese in più, da oggi alla pensione."))
        }
        if e.aliquotaMarginale != nil, e.risparmioConProposte > 0.5 {
            punti.append(("Il vantaggio fiscale", "Circa \(CifreDoc.euro(e.risparmioConProposte)) l'anno di IRPEF in meno grazie ai versamenti."))
        }
        return punti
    }

    var prossimiPassi: [String] {
        var passi = ["Verificare la pensione pubblica sull'estratto conto INPS."]
        if !e.proposte.isEmpty { passi.append("Decidere sulla proposta \(e.proposte[0].posizione.nome).") }
        if e.spazioResiduo > 100, e.aliquotaMarginale != nil {
            passi.append("Valutare di usare lo spazio di deducibilità che resta: \(CifreDoc.euro(e.spazioResiduo)) l'anno.")
        }
        passi.append("Rivedere il piano ogni anno, con il resoconto.")
        return passi
    }
}
