import Foundation

/// I testi del check-up del primo incontro. Il report si rivolge al cliente con il tu.
struct TestiCheckUp {
    let e: EsitoCheckUp
    let cliente: String
    let data: Date

    init(_ e: EsitoCheckUp, data: Date = Date()) {
        self.e = e
        self.cliente = e.cliente?.nome ?? "Cliente"
        self.data = data
    }

    static let titolo = "Check-up"
    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Prima fotografia basata su quanto raccolto al primo incontro: le cifre si precisano negli incontri successivi."

    var canali: [Canale] { e.cliente?.canali.isEmpty == false ? (e.cliente?.canali ?? []) : [.alleanza] }

    var ruoloConsulente: String {
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Consulente Alleanza Assicurazioni e consulenza finanziaria"
    }

    /// "35 anni · Infermiere · celibe"
    var chiSei: String {
        guard let c = e.cliente else { return "" }
        var parti: [String] = []
        if let eta = c.eta { parti.append("\(eta) anni") }
        if !c.professione.isEmpty { parti.append(c.professione) }
        if let s = c.statoCivile { parti.append(s.nome.lowercased()) }
        if !c.famiglia.isEmpty { parti.append(c.famiglia.count == 1 ? "1 familiare" : "\(c.famiglia.count) familiari") }
        return parti.joined(separator: " · ")
    }

    var titoloSemaforo: String {
        switch (e.rossi.count, e.gialli.count) {
        case (0, 0): return "Le aree principali sono in ordine"
        case (0, _): return "Nessuna urgenza: \(e.gialli.count) \(e.gialli.count == 1 ? "area da migliorare" : "aree da migliorare")"
        default: return "\(e.rossi.count) \(e.rossi.count == 1 ? "area da affrontare" : "aree da affrontare") per prima"
        }
    }

    var sintesi: [(String, String)] {
        var punti: [(String, String)] = [("La fotografia", "Patrimonio netto \(CifreDoc.euro(e.riepilogo.patrimonioNetto)), di cui \(CifreDoc.euro(e.riepilogo.perArea[.liquidita] ?? 0)) di liquidità.")]
        punti.append(("Il semaforo", "\(e.verdi.count) in ordine, \(e.gialli.count) da migliorare, \(e.rossi.count) da affrontare."))
        if let primo = e.daAffrontare.first { punti.append(("Da dove partire", "\(primo.titolo): \(primo.azione)")) }
        if !e.proposte.isEmpty { punti.append(("Le proposte", e.proposte.prefix(3).map(\.nome).joined(separator: ", ") + ".")) }
        return punti
    }

    var prossimiPassi: [String] {
        var passi = e.daAffrontare.prefix(3).map { "\($0.titolo): \($0.azione)" }
        let grigi = e.indicatori.filter { $0.semaforo == .grigio }
        for g in grigi.prefix(2) { passi.append(g.azione) }
        passi.append("Portare al prossimo incontro l'estratto conto INPS e le polizze in essere.")
        return Array(passi.prefix(5))
    }
}
