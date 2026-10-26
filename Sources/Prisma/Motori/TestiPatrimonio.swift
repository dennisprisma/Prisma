import Foundation

/// I testi del documento «Il tuo patrimonio nei prossimi 20 anni». Il report si rivolge al cliente con il tu.
struct TestiPatrimonio {
    struct Area: Identifiable {
        let area: AreaPosizione
        let oggi: Double
        let dieci: Double
        let finale: Double
        var id: String { area.rawValue }
    }

    let p: PatrimonioNelTempo
    let cliente: String
    let data: Date
    let posizioni: [Posizione]
    /// Il patrimonio per area (in essere): oggi, tra 10 anni e alla fine.
    let perArea: [Area]
    /// Gli anni mostrati nella tabella.
    let anniTabella: [Int]

    init(_ p: PatrimonioNelTempo, posizioni: [Posizione], cliente: Cliente?, data: Date = Date()) {
        self.p = p
        self.cliente = cliente?.nome ?? "Cliente"
        self.data = data
        self.posizioni = posizioni
        let inEssere = posizioni.filter { $0.stato == .inEssere && $0.area != .protezione }
        perArea = AreaPosizione.allCases.compactMap { a in
            let mie = inEssere.filter { $0.area == a }
            guard !mie.isEmpty else { return nil }
            let s = MotorePatrimonio.serie(mie, anni: p.anni)
            return Area(area: a, oggi: s.first?.valore ?? 0, dieci: s[min(10, s.count - 1)].valore, finale: s.last?.valore ?? 0)
        }.sorted { $0.area.ordine < $1.area.ordine }
        anniTabella = [0, 1, 2, 3, 5, 10, 15, 20].filter { $0 <= p.anni }
    }

    static let titolo = "Il tuo patrimonio nei prossimi anni"
    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Proiezione con i rendimenti ipotizzati, non garantiti, prima delle imposte finali; immobili al valore di oggi."

    var canali: [Canale] {
        Canale.allCases.filter { c in posizioni.contains { $0.canale == c && $0.stato != .chiusa } }
    }

    var ruoloConsulente: String {
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Alleanza Assicurazioni · consulenza finanziaria"
    }

    var titoloPercorso: String {
        "Da \(CifreDoc.euro(p.nettoOggi)) di oggi a circa \(CifreDoc.euro(p.valore(p.anni))) tra \(p.anni) anni"
    }

    var titoloProposte: String {
        guard let d = p.differenzaProposte else { return "Il percorso di oggi, e dove si può migliorare" }
        return d >= 0 ? "Con le proposte, circa \(CifreDoc.euro(d)) in più tra \(p.anni) anni" : "Le proposte cambiano il percorso di \(CifreDoc.euroSegno(d))"
    }

    var sintesi: [(String, String)] {
        var punti: [(String, String)] = [
            ("Oggi", "Il tuo patrimonio netto è di \(CifreDoc.euro(p.nettoOggi)), debiti tolti."),
            ("Tra \(p.anni) anni", "Circa \(CifreDoc.euro(p.valore(p.anni))), cioè \(CifreDoc.euro(p.reale(p.valore(p.anni), anno: p.anni))) in euro di oggi, con i versamenti attuali di \(CifreDoc.euro(p.versamentiAnnui)) l'anno."),
        ]
        if let d = p.differenzaProposte {
            punti.append(("Con le proposte", "\(CifreDoc.euro(p.valore(p.anni, conProposte: true))) tra \(p.anni) anni: \(CifreDoc.euroSegno(d)) rispetto al percorso di oggi."))
        }
        if let t = p.traguardi.first {
            punti.append(("Il primo traguardo", "«\(t.obiettivo.titolo)» tra \(t.anno) \(t.anno == 1 ? "anno" : "anni") (\(CifreDoc.euro(t.obiettivo.importo))): allora il patrimonio stimato è di \(CifreDoc.euro(p.valore(t.anno, conProposte: p.conProposte != nil)))."))
        }
        if let debiti = perArea.first(where: { $0.area == .debiti }), debiti.oggi < -0.5 {
            punti.append(("I debiti", "\(CifreDoc.euro(-debiti.oggi)) oggi, \(debiti.finale > -0.5 ? "estinti entro \(p.anni) anni" : "\(CifreDoc.euro(-debiti.finale)) tra \(p.anni) anni")."))
        }
        return punti
    }

    var prossimiPassi: [String] {
        var passi = p.proposte.prefix(2).map { "Decidere insieme sulla proposta \($0.nome)." }
        if p.traguardi.isEmpty { passi.append("Fissare gli obiettivi con una data: casa, studi dei figli, pensione.") }
        passi.append("Rivedere il percorso ogni anno, al riesame, con i valori aggiornati.")
        return passi
    }

    var metodo: [String] {
        [
            "Investimenti, risparmio e previdenza: la proiezione di ogni posizione con il suo rendimento ipotizzato, i costi e i versamenti, fino alla scadenza; dopo, il capitale resta fermo, prima delle imposte finali.",
            "Conti al loro rendimento (zero se non indicato); immobili al valore di oggi; debiti in rimborso lineare fino alla scadenza; coperture assicurative non contate.",
            "Con le proposte: le proposte aperte si aggiungono con il loro versamento iniziale, tolto dalla liquidità per non contarlo due volte.",
            "In euro di oggi: tolta un'inflazione del \(CifreDoc.condizione(IpotesiCalcolo.inflazione)) l'anno.",
        ]
    }

    /// Le etichette dell'asse dei grafici: oggi, poi ogni 5 anni.
    var etichetteAsse: [String] { p.oggi.map { $0.anno == 0 ? "oggi" : ($0.anno % 5 == 0 ? "\($0.anno)° anno" : "") } }
}
