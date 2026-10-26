import Foundation

/// I testi del resoconto delle posizioni in essere, ricavati dai numeri. Il report si rivolge al
/// cliente con il tu; il prospetto parla del cliente in terza persona.
struct TestiResoconto {
    let e: EsitoResoconto
    /// Nome completo e nome di battesimo del cliente.
    let cliente: String
    let nome: String

    init(_ posizioni: [Posizione], cliente: Cliente?, prodotti: [Prodotto] = [], data: Date = Date()) {
        let nomeCompleto = cliente?.nome ?? "Cliente"
        self.cliente = nomeCompleto
        nome = nomeCompleto.split(separator: " ").first.map(String.init) ?? nomeCompleto
        e = MotoreResoconto.calcola(posizioni, cliente: nomeCompleto, prodotti: prodotti, data: data)
    }

    static let titolo = "Resoconto delle posizioni in essere"

    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(e.data)) · \(TestiValutazione.consulente)" }

    static let avvertenza = "Valori dichiarati nelle posizioni alla data indicata: non sostituiscono gli estratti conto e le comunicazioni delle compagnie."

    var ruoloConsulente: String {
        let canali = e.canaliPresenti
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Alleanza Assicurazioni · consulenza finanziaria"
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

    /// Le posizioni finanziarie con un andamento (almeno due valori rilevati), nell'ordine del resoconto.
    var andamenti: [(voce: VoceResoconto, andamento: AndamentoPosizione)] {
        e.finanziarie.compactMap { v in MotoreAndamento.calcola(v.posizione).map { (v, $0) } }
    }

    /// Effettivo e atteso in una riga: "+4,9% l'anno contro il 5,0% atteso".
    static func rendimento(_ a: AndamentoPosizione) -> String {
        a.rendimentoAnnuo.map { "\(CifreDoc.variazione($0)) l'anno" } ?? "\(CifreDoc.variazione(a.rendimentoPeriodo)) in \(mesi(a.anni))"
    }

    static func mesi(_ anni: Double) -> String {
        let m = max(1, Int((anni * 12).rounded()))
        return m == 1 ? "1 mese" : "\(m) mesi"
    }

    /// Il titolo della pagina del report sull'atteso.
    func titoloAtteso(_ elenco: [AndamentoPosizione]) -> String {
        let giudicate = elenco.compactMap(\.giudizio)
        guard !giudicate.isEmpty else { return "Come sono andati i tuoi risparmi nel tempo" }
        let sotto = giudicate.filter { $0 == .sotto }.count
        if sotto == 0 { return giudicate.count == 1 ? "In linea o meglio di quanto ci aspettavamo" : "Tutte in linea o meglio di quanto ci aspettavamo" }
        return sotto == 1 ? "Una posizione è andata meno bene del previsto: ne parliamo" : "\(sotto) posizioni sono andate meno bene del previsto: ne parliamo"
    }

    static let sottotitoloAtteso = "Il rendimento di ogni posizione dai valori rilevati nel tempo, al netto dei costi e senza contare i tuoi versamenti, accanto a quello che ci aspettavamo."

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

    var titoloNetto: String {
        "Se chiudessi tutto oggi: circa \(CifreDoc.euro(e.nettoFinanziario)) netti"
    }

    var sottotitoloNetto: String {
        var s = "Dal valore di oggi si tolgono "
        s += e.penaliFinanziarie > 0.5 ? "le penali di riscatto, il bollo maturato e le imposte sul guadagno" : "le imposte sul guadagno"
        if let r = e.rendimentoNettoAnnuo { s += ": il rendimento dei tuoi versamenti, dopo le imposte, è di circa il \(CifreDoc.percento(r)) l'anno" }
        return s + "."
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
            s += " Chiudendo tutto oggi, dopo imposte e penali, incasseresti circa \(CifreDoc.euro(e.nettoFinanziario))."
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
        ("Andamento e atteso", "rendimento tra un valore rilevato e il successivo, tolti i versamenti del periodo (se manca il versato, stimati dai premi periodici), concatenato su tutto lo storico e reso annuo da circa un anno; confrontato con il rendimento atteso della posizione meno i costi annui: in linea entro un punto all'anno."),
        ("Costi stimati", "costo annuo di gestione, trattenuto sul rendimento della gestione separata e imposta di bollo (0,20% del valore; 34,20 € per i conti correnti), sul valore attuale."),
        ("Imposte e netto", "polizze vita, fondi ed ETF: 26% sul guadagno al netto della penale, 12,5% sulla parte in titoli di Stato; nelle polizze il bollo maturato si paga al riscatto. Conti e depositi: interessi già tassati all'accredito."),
        ("Previdenza", "si tassano solo i contributi dedotti: 15% fino al 15° anno di partecipazione, poi 0,30 punti in meno ogni anno fino al 9%, per pensionamento, riscatti agevolati e spese sanitarie; 23% per anticipazioni casa e ulteriori esigenze e per i riscatti per altre cause."),
        ("Quote", "per area e per canale calcolate sulle attività in essere, debiti esclusi."),
    ] + Semplificazioni.resoconto
}
