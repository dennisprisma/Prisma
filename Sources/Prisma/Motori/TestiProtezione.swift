import Foundation

/// I testi della protezione della famiglia, ricavati dai numeri. Il report si rivolge al cliente con il tu.
struct TestiProtezione {
    let e: EsitoProtezioneFamiglia
    let cliente: String
    let data: Date

    init(_ e: EsitoProtezioneFamiglia, cliente: Cliente?, data: Date = Date()) {
        self.e = e
        self.cliente = cliente?.nome ?? "Cliente"
        self.data = data
    }

    static let titolo = "Protezione della famiglia"
    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Stime basate sulle ipotesi indicate: fanno fede le condizioni di assicurazione delle singole polizze."

    var ruoloConsulente: String {
        if e.canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if e.canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Alleanza Assicurazioni · consulenza finanziaria"
    }

    /// "Luca (convivente), Anna (figlia, 9 anni)".
    var chiEFamiglia: String {
        e.famiglia.map { f in
            let nome = f.nome.split(separator: " ").first.map(String.init) ?? f.nome
            var dettagli = [f.relazione.nome.lowercased()]
            if let eta = f.eta, [.figlio, .figlia].contains(f.relazione) { dettagli.append("\(eta) anni") }
            return "\(nome) (\(dettagli.joined(separator: ", ")))"
        }.joined(separator: ", ")
    }

    static func anni(_ v: Double) -> String {
        let n = Int(v.rounded(.down))
        return n == 1 ? "1 anno" : "\(n) anni"
    }

    var titoloMorte: String {
        if e.fabbisogno < 1 { return "La famiglia avrebbe già quanto serve" }
        if e.divario < 1 { return "Le coperture di oggi bastano alla famiglia" }
        return "Alla famiglia mancherebbero \(CifreDoc.euro(e.divario))"
    }

    var sottotitoloMorte: String {
        "Per estinguere i debiti, affrontare le prime spese e mantenere il tenore di vita per \(e.ipotesi.anniSostegno) anni servirebbero \(CifreDoc.euro(e.fabbisogno)), oltre a ciò che è già disponibile. Oggi le coperture caso morte valgono \(CifreDoc.euro(e.capitaleVita))."
    }

    var titoloInvalidita: String {
        e.ammanco < 1 ? "Le entrate sostitutive coprono il fabbisogno" : "Se non potessi lavorare mancherebbero \(CifreDoc.euro(e.ammanco)) al mese"
    }

    var titoloMappa: String {
        switch e.scoperti.count {
        case 0: return "Le tutele importanti sono tutte coperte"
        case 1: return "Una tutela importante è ancora scoperta"
        default: return "\(e.scoperti.count) tutele importanti sono ancora scoperte"
        }
    }

    var titoloCosti: String {
        e.premiAnnui < 1 ? "Oggi non paghi premi per la protezione" : "Proteggere la famiglia costa \(CifreDoc.euro(e.premiAnnui / 12)) al mese"
    }

    var sintesi: [(String, String)] {
        var punti: [(String, String)] = []
        punti.append(("Caso morte", e.divario < 1 ? "Le coperture di oggi bastano al fabbisogno stimato." : "Mancano \(CifreDoc.euro(e.divario)); con le proposte \(CifreDoc.euro(e.divarioConProposte))."))
        punti.append(("Invalidità e malattia", fraseInvalidita))
        if !e.scoperti.isEmpty {
            punti.append(("Da valutare", e.scoperti.map { $0.rischio.nome.lowercased() }.joined(separator: ", ") + "."))
        }
        if e.premiAnnui + e.premiProposte > 0.5 {
            punti.append(("Il costo", "\(CifreDoc.euro(e.premiAnnui)) l'anno oggi" + (e.premiProposte > 0.5 ? ", \(CifreDoc.euro(e.premiAnnui + e.premiProposte)) con le proposte" : "") + "; detrazione IRPEF di circa \(CifreDoc.euro(e.detrazioneConProposte))."))
        }
        return punti
    }

    private var fraseInvalidita: String {
        if e.ammanco < 1 { return "Le entrate sostitutive coprono il fabbisogno." }
        let riserva = e.riservaMancante < 1 ? "la riserva disponibile copre \(e.ipotesi.mesiRiserva) mesi."
                                            : "riserva da costruire \(CifreDoc.euro(e.riservaMancante))."
        return "Mancherebbero \(CifreDoc.euro(e.ammanco)) al mese; " + riserva
    }

    var prossimiPassi: [String] {
        var passi: [String] = []
        if e.divarioConProposte > 1 { passi.append("Valutare un capitale caso morte di almeno \(CifreDoc.euro(e.divarioConProposte)) in più.") }
        if let p = e.proposte.first { passi.append("Decidere sulla proposta \(p.nome).") }
        for a in e.avvisi.prefix(2) { passi.append(a.testo) }
        if e.riservaMancante > 1 { passi.append("Costruire una riserva di liquidità di \(CifreDoc.euro(e.riservaMancante)).") }
        passi.append("Rivedere le tutele a ogni cambiamento della famiglia.")
        return Array(passi.prefix(5))
    }
}
