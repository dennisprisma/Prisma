import Foundation

/// I testi del piano obiettivo, ricavati dai numeri. Il report si rivolge al cliente con il tu.
struct TestiObiettivo {
    let e: EsitoObiettivo
    let cliente: String
    let data: Date
    /// Gli altri obiettivi del cliente, per il quadro d'insieme.
    let altri: [(Obiettivo, AvanzamentoObiettivo)]

    init(_ e: EsitoObiettivo, cliente: Cliente?, altri: [(Obiettivo, AvanzamentoObiettivo)] = [], data: Date = Date()) {
        self.e = e
        self.cliente = cliente?.nome ?? "Cliente"
        self.altri = altri
        self.data = data
    }

    var o: Obiettivo { e.obiettivo }
    static let genere = "Piano obiettivo"
    var piede: String { "\(Self.genere) · \(o.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Proiezione illustrativa con rendimenti ipotetici e non garantiti: non sostituisce il KID dei prodotti."

    var canali: [Canale] { Canale.allCases.filter { c in e.contributi.contains { $0.posizione.canale == c } } }

    var ruoloConsulente: String {
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Consulente Alleanza Assicurazioni e consulenza finanziaria"
    }

    var quando: String {
        let mesi = e.mesi
        if mesi < 12 { return mesi == 1 ? "tra 1 mese" : "tra \(mesi) mesi" }
        let anni = mesi / 12, resto = mesi % 12
        return "tra \(anni) \(anni == 1 ? "anno" : "anni")" + (resto > 0 ? " e \(resto) \(resto == 1 ? "mese" : "mesi")" : "")
    }

    var titoloTraguardo: String { "\(o.titolo): \(CifreDoc.euro(o.importo)) entro il \(CifreDoc.data(o.scadenza))" }

    var titoloOggi: String {
        let q = e.importoOggi > 0 ? e.disponibileOggi / e.importoOggi * 100 : 100
        return "Hai già da parte \(CifreDoc.euro(e.disponibileOggi)): il \(CifreDoc.percento(min(q, 100), decimali: 0)) dell'obiettivo"
    }

    var titoloArrivo: String {
        e.mancante < 1 ? "Così arrivi al traguardo: \(CifreDoc.euro(e.proiezione)) alla scadenza"
            : "Così arrivi a \(CifreDoc.euro(e.proiezione)): ne mancano \(CifreDoc.euro(e.mancante))"
    }

    var sottotitoloArrivo: String {
        "Alla scadenza l'obiettivo varrà \(CifreDoc.euro(e.importoScadenza)) per effetto dell'inflazione. Con ciò che hai e i versamenti di oggi (\(CifreDoc.euro(e.versamentiAttivi)) al mese) arrivi al \(CifreDoc.percento(e.copertura * 100, decimali: 0))."
    }

    var tenuta: String {
        let raggiunti = e.scenari.filter { $0.proiezione >= e.importoScadenza - 0.5 }.count
        switch raggiunti {
        case 3: return "L'obiettivo si raggiunge in tutti e tre gli scenari di mercato."
        case 0: return "Senza interventi l'obiettivo non si raggiunge in nessuno scenario."
        default: return "Si raggiunge in \(raggiunti) scenari su 3: conviene tenersi un margine."
        }
    }

    var sintesi: [(String, String)] {
        var punti: [(String, String)] = [("Il traguardo", "\(CifreDoc.euro(o.importo)) di oggi \(quando), cioè \(CifreDoc.euro(e.importoScadenza)) alla scadenza.")]
        punti.append(("Dove arrivi così", "\(CifreDoc.euro(e.proiezione)), il \(CifreDoc.percento(e.copertura * 100, decimali: 0)) dell'obiettivo."))
        if let s = e.strade.first {
            punti.append(("La strada più semplice", "\(s.titolo): \(s.valore), \(s.spiegazione)."))
        }
        punti.append(("Quanto è solido", tenuta))
        return punti
    }

    var prossimiPassi: [String] {
        var passi: [String] = []
        if let v = e.versamentoNecessario { passi.append("Attivare un piano di accumulo di circa \(CifreDoc.euro(v)) al mese.") }
        if e.contributi.isEmpty { passi.append("Collegare all'obiettivo le posizioni che lavorano per lui.") }
        passi.append("Rivedere l'obiettivo ogni anno e a ogni cambiamento dell'importo o della data.")
        return passi
    }
}
