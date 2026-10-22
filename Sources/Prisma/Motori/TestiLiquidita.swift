import Foundation

/// I testi del capitale in scadenza e della liquidità. Il report si rivolge al cliente con il tu.
struct TestiLiquidita {
    let e: EsitoLiquidita
    let cliente: String
    let data: Date

    init(_ e: EsitoLiquidita, cliente: Cliente?, data: Date = Date()) {
        self.e = e
        self.cliente = cliente?.nome ?? "Cliente"
        self.data = data
    }

    static let titolo = "Capitale in scadenza e liquidità"
    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Destinazione indicativa per orizzonte: i prodotti si scelgono insieme, con il loro KID."

    var canali: [Canale] {
        Canale.allCases.filter { c in (e.scadenze.map(\.posizione) + e.liquidita + e.proposte).contains { $0.canale == c } }
    }

    var ruoloConsulente: String {
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Consulente Alleanza Assicurazioni e consulenza finanziaria"
    }

    var titoloArrivo: String {
        if e.scadenze.isEmpty { return "Nessun capitale in scadenza: hai \(CifreDoc.euro(e.liquiditaAttuale)) di liquidità" }
        if let primo = e.scadenze.first, e.scadenze.count == 1 {
            return "Il \(CifreDoc.dataBreve(primo.data)) ti arrivano circa \(CifreDoc.euro(primo.netto)) netti"
        }
        return "Nei prossimi 12 mesi ti arrivano circa \(CifreDoc.euro(e.nettoInScadenza)) netti"
    }

    var titoloSalvadanai: String { "\(CifreDoc.euro(e.totale)) in quattro salvadanai, secondo quando ti serviranno" }

    var titoloFermo: String {
        e.vantaggioDestinare > 1 ? "Lasciarli fermi costa: circa \(CifreDoc.euro(e.erosioneAnnua)) di potere d'acquisto ogni anno"
            : "La liquidità è già proporzionata ai bisogni"
    }

    var sintesi: [(String, String)] {
        var punti: [(String, String)] = []
        if !e.scadenze.isEmpty {
            punti.append(("Cosa arriva", "\(CifreDoc.euro(e.nettoInScadenza)) netti da \(e.scadenze.count == 1 ? "una posizione in scadenza" : "\(e.scadenze.count) posizioni in scadenza")."))
        }
        punti.append(("Quanto tenere", "Una riserva di \(CifreDoc.euro(e.riservaNecessaria)): \(e.mesiRiserva) mesi di spese, sempre disponibili."))
        let investibile = e.salvadanai.filter { $0.tipo != .riserva }.reduce(0) { $0 + $1.importo }
        if investibile > 0.5 {
            punti.append(("Cosa destinare", "\(CifreDoc.euro(investibile)) tra progetti vicini, medio periodo e crescita."))
        }
        if e.vantaggioDestinare > 1 {
            punti.append(("Perché non lasciarli fermi", "In \(IpotesiLiquidita.anniConfronto) anni, in euro di oggi: circa \(CifreDoc.euro(e.vantaggioDestinare)) in più destinandoli."))
        }
        return punti
    }

    var prossimiPassi: [String] {
        var passi: [String] = []
        if let s = e.scadenze.first { passi.append("Decidere prima del \(CifreDoc.dataBreve(s.data)) dove far confluire \(s.posizione.nome).") }
        for p in e.proposte.prefix(2) { passi.append("Valutare la proposta \(p.nome).") }
        passi.append("Tenere la riserva su un conto separato e rivederla ogni anno.")
        return passi
    }
}
