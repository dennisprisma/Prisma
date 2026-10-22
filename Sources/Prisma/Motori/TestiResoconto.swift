import Foundation

/// I testi del resoconto delle posizioni in essere, ricavati dai numeri. Il report si rivolge al
/// cliente con il tu; il prospetto parla del cliente in terza persona.
struct TestiResoconto {
    let e: EsitoResoconto
    /// Nome completo e nome di battesimo del cliente.
    let cliente: String
    let nome: String

    init(_ posizioni: [Posizione], cliente: Cliente?, data: Date = Date()) {
        let nomeCompleto = cliente?.nome ?? "Cliente"
        self.cliente = nomeCompleto
        nome = nomeCompleto.split(separator: " ").first.map(String.init) ?? nomeCompleto
        e = MotoreResoconto.calcola(posizioni, cliente: nomeCompleto, data: data)
    }

    static let titolo = "Resoconto delle posizioni in essere"

    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(e.data)) · \(TestiValutazione.consulente)" }

    static let avvertenza = "Valori dichiarati nelle posizioni alla data indicata: non sostituiscono gli estratti conto e le comunicazioni delle compagnie."

    var ruoloConsulente: String {
        let canali = e.canaliPresenti
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Consulente Alleanza Assicurazioni e consulenza finanziaria"
    }

    /// "1 posizione", "8 posizioni".
    static func posizioni(_ n: Int) -> String { n == 1 ? "1 posizione" : "\(n) posizioni" }

    /// Data breve di una posizione, se c'è.
    static func quando(_ d: Date?) -> String { d.map { CifreDoc.dataBreve($0) } ?? "—" }

    /// "+ € 3.521 (+7,0%)".
    static func risultato(_ euro: Double?, _ percento: Double?) -> String {
        guard let euro else { return "—" }
        return CifreDoc.euroSegno(euro) + (percento.map { " (\(CifreDoc.variazione($0)))" } ?? "")
    }

    // MARK: - Report

    var titoloQuadro: String {
        "Tutto ciò che hai costruito, in una pagina"
    }

    var sottotitoloQuadro: String {
        var s = "Patrimonio netto di \(CifreDoc.euro(e.riepilogo.patrimonioNetto))"
        if e.riepilogo.debiti > 0 {
            s += ": \(CifreDoc.euro(e.riepilogo.attivita)) di beni e risparmi, meno \(CifreDoc.euro(e.riepilogo.debiti)) di debiti residui."
        } else {
            s += ", senza debiti."
        }
        return s
    }

    var titoloAndamento: String {
        guard e.versato > 0 else { return "Come stanno andando i tuoi risparmi" }
        let r = e.risultato
        if abs(r) < 1 { return "Oggi vale quanto hai versato: \(CifreDoc.euro(e.valoreFinanziario))" }
        return "Hai versato \(CifreDoc.euro(e.versato)): oggi vale \(CifreDoc.euro(e.valoreFinanziario))"
    }

    var sottotitoloAndamento: String {
        guard e.versato > 0 else { return "Investimenti, risparmio e previdenza: quanto hai versato e quanto vale oggi." }
        var s = "Investimenti, risparmio e previdenza insieme: "
        s += e.risultato >= 0 ? "un guadagno di \(CifreDoc.euro(e.risultato)) " : "una perdita di \(CifreDoc.euro(-e.risultato)) "
        s += "(\(CifreDoc.variazione(e.risultatoPercento))) su quanto hai versato"
        if let r = e.rendimentoAnnuo { s += ", pari a circa il \(CifreDoc.percento(r)) l'anno" }
        return s + ", già al netto dei costi dei prodotti."
    }

    var titoloTutele: String {
        e.coperture.isEmpty ? "Le tue tutele: oggi nessuna copertura in essere"
            : "Le tue tutele: \(CifreDoc.euro(e.riepilogo.capitaleAssicurato)) di capitali assicurati"
    }

    var sottotitoloTutele: String {
        e.coperture.isEmpty
            ? "Proteggere il reddito, la famiglia e la salute è la base di ogni piano: ne parliamo al prossimo incontro."
            : "\(e.coperture.count == 1 ? "Una copertura" : "\(e.coperture.count) coperture") per \(CifreDoc.euro(e.premiCoperture)) di premi l'anno. Ecco cosa proteggono e fino a quando."
    }

    var titoloScadenze: String {
        switch e.scadenze.count {
        case 0: return "I prossimi 12 mesi: nessuna scadenza"
        case 1: return "I prossimi 12 mesi: una scadenza da preparare"
        default: return "I prossimi 12 mesi: \(e.scadenze.count) scadenze da preparare"
        }
    }

    var impegnoAnnuo: Double { e.versamentiAnnui + e.premiCoperture + e.rateAnnue }

    var titoloCosti: String {
        e.costoAnnuo > 0 ? "Quanto costano i tuoi prodotti: circa \(CifreDoc.euro((e.costoAnnuo / 10).rounded() * 10)) l'anno"
            : "Quanto costano i tuoi prodotti"
    }

    var sottotitoloCosti: String {
        guard let i = e.incidenzaCosti, e.costoAnnuo > 0 else {
            return "Per stimarli servono i costi annui delle posizioni: li aggiungiamo insieme."
        }
        return "Circa il \(CifreDoc.percento(i)) del valore ogni anno. I costi sono già compresi nei valori che vedi: non si pagano a parte."
    }

    /// I messaggi della sintesi, dal più importante.
    var sintesi: [(String, String)] {
        var punti: [(String, String)] = []
        if e.versato > 0 {
            var s = "Hai versato \(CifreDoc.euro(e.versato)) e oggi vale \(CifreDoc.euro(e.valoreFinanziario)): \(CifreDoc.euroSegno(e.risultato)) (\(CifreDoc.variazione(e.risultatoPercento)))."
            if let v = e.variazione12, let p = e.variazione12Percento {
                s += " Negli ultimi 12 mesi \(CifreDoc.euroSegno(v)) (\(CifreDoc.variazione(p))), al netto dei nuovi versamenti."
            }
            punti.append(("Come sta andando", s))
        }
        if !e.coperture.isEmpty {
            punti.append(("Le tutele", "\(CifreDoc.euro(e.riepilogo.capitaleAssicurato)) di capitali assicurati per \(CifreDoc.euro(e.premiCoperture)) l'anno."))
        } else {
            punti.append(("Le tutele", "Nessuna copertura in essere: è il primo punto da affrontare insieme."))
        }
        if let s = e.scadenze.first {
            let altre = e.scadenze.count > 1 ? " e altre \(e.scadenze.count - 1) nei prossimi 12 mesi" : ""
            punti.append(("Da preparare", "\(s.posizione.nome): \(s.cosa) il \(CifreDoc.dataBreve(s.data))\(altre)."))
        }
        if impegnoAnnuo > 0 {
            punti.append(("Ogni mese", "Tra versamenti, premi e rate circa \(CifreDoc.euro(impegnoAnnuo / 12)) al mese."))
        }
        return punti
    }

    /// I prossimi passi: scadenze da preparare e proposte ancora aperte.
    var prossimiPassi: [String] {
        var passi = e.scadenze.prefix(3).map { "Preparare \($0.cosa) di \($0.posizione.nome) (\(CifreDoc.dataBreve($0.data)))." }
        passi += e.proposte.prefix(3).map { "Decidere sulla proposta \($0.nome)." }
        if passi.isEmpty { passi = ["Rivedere insieme il resoconto tra sei mesi."] }
        return passi
    }

    // MARK: - Metodo

    static let metodo: [(String, String)] = [
        ("Valore", "controvalore dichiarato nella posizione alla data indicata; se manca, il totale versato."),
        ("Risultato", "valore meno totale versato, già al netto dei costi del prodotto; prima delle imposte sul guadagno."),
        ("Rendimento medio annuo", "tasso che porta i versamenti, alle loro date, al valore di oggi: il versamento iniziale alla decorrenza e gli altri distribuiti mese per mese. Solo per le posizioni con almeno un anno."),
        ("Ultimi 12 mesi", "variazione rispetto al valore rilevato circa un anno fa, tolti i versamenti del periodo e misurata sul valore di partenza più metà dei versamenti."),
        ("Costi stimati", "costo annuo percentuale della posizione per il valore attuale."),
        ("Quote", "per area e per canale calcolate sulle attività in essere, debiti esclusi."),
    ]
}
