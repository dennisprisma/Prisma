import Foundation

/// I testi della sostituzione (o del confronto tra due proposte), ricavati dai numeri.
/// Il report si rivolge al cliente con il tu.
struct TestiSostituzione {
    let e: EsitoSostituzione
    let cliente: String
    let data: Date

    init(_ e: EsitoSostituzione, cliente: Cliente?, data: Date = Date()) {
        self.e = e
        self.cliente = cliente?.nome ?? "Cliente"
        self.data = data
    }

    var a: Posizione { e.resto.posizione }
    var b: Posizione { e.cambio.posizione }

    var titolo: String { e.sostituzione ? "Sostituzione: \(a.nome) → \(b.nome)" : "Confronto: \(a.nome) e \(b.nome)" }
    static let genere = "Sostituzione o confronto"

    /// Come si chiamano le due strade.
    var nomeResto: String { e.sostituzione ? "Restare" : a.nome }
    var nomeCambio: String { e.sostituzione ? "Cambiare" : b.nome }

    var piede: String { "\(TestiSostituzione.genere) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Simulazione illustrativa con rendimenti ipotetici: non sostituisce il KID e la documentazione dei prodotti."

    var ruoloConsulente: String {
        let canali = Set([a.canale, b.canale])
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Alleanza Assicurazioni · consulenza finanziaria"
    }

    var periodo: String { e.anni == 1 ? "1 anno" : "\(e.anni) anni" }

    // MARK: - Il verdetto

    /// true se nello scenario atteso conviene la seconda strada.
    var convieneCambiare: Bool { (e.finale?.differenza ?? 0) > 0 }

    var titoloVerdetto: String {
        let d = abs(e.finale?.differenza ?? 0)
        if d < 50 { return "Dopo \(periodo) le due strade si equivalgono" }
        if e.sostituzione {
            return convieneCambiare ? "Cambiare conviene: \(CifreDoc.euroSegno(d)) netti dopo \(periodo)"
                                    : "Restare conviene: \(CifreDoc.euro(d)) netti in più dopo \(periodo)"
        }
        return "\(convieneCambiare ? b.nome : a.nome): \(CifreDoc.euro(d)) netti in più dopo \(periodo)"
    }

    var sottotitoloVerdetto: String {
        guard let f = e.finale else { return "" }
        var s = "Nello scenario atteso, dopo penali, bollo e imposte: \(nomeResto.lowercased()) \(CifreDoc.euro(f.nettoResto)), \(nomeCambio.lowercased()) \(CifreDoc.euro(f.nettoCambio))."
        if e.sostituzione && e.costoUscita > 0.5 {
            s += " Il costo dell'uscita (\(CifreDoc.euro(e.costoUscita))) "
            if let p = e.pareggio { s += p == 1 ? "si recupera già nel primo anno." : "si recupera in \(p) anni." }
            else { s += "non si recupera entro \(periodo)." }
        }
        return s
    }

    /// Quanto è solida la conclusione: in quanti scenari vince la stessa strada.
    var tenuta: String {
        let vince = e.scenari.filter { ($0.differenza > 0) == convieneCambiare }.count
        switch vince {
        case 3: return "La conclusione regge in tutti e tre gli scenari di mercato."
        case 2: return "La conclusione regge in due scenari su tre: in quello \(scenarioContrario) cambia."
        default: return "La conclusione dipende dai mercati: vale solo nello scenario atteso."
        }
    }

    /// Il nome dello scenario in cui vince l'altra strada.
    private var scenarioContrario: String {
        e.scenari.first(where: { ($0.differenza > 0) != convieneCambiare })?.nome.lowercased() ?? ""
    }

    // MARK: - Cosa si perde e cosa si guadagna

    /// Punti a sfavore del cambio (cosa si perde o si paga).
    var siPerde: [String] {
        var punti: [String] = []
        if e.penaleUscita > 0.5 { punti.append("Penale di riscatto di \(CifreDoc.euro(e.penaleUscita)).") }
        if e.bolloUscita > 0.5 { punti.append("Bollo maturato da pagare all'uscita: \(CifreDoc.euro(e.bolloUscita)).") }
        if e.impostaUscita > 0.5 { punti.append("Imposte pagate oggi invece che alla fine: \(CifreDoc.euro(e.impostaUscita)).") }
        if e.ingressoCambio > 0.5 { punti.append("Costo d'ingresso del nuovo prodotto: \(CifreDoc.euro(e.ingressoCambio)).") }
        if !a.garanzie.isEmpty { punti.append("Le garanzie di oggi: \(a.garanzie)") }
        if e.cambio.costoAnnuo > e.resto.costoAnnuo + 0.05 {
            punti.append("Costi annui più alti: \(CifreDoc.percento(e.cambio.costoAnnuo, decimali: 2)) contro \(CifreDoc.percento(e.resto.costoAnnuo, decimali: 2)).")
        }
        if let ra = a.sri, let rb = b.sri, rb > ra { punti.append("Più rischio: indicatore \(rb) su 7 invece di \(ra).") }
        if e.riscattoPrevidenza != nil { punti.append("I vantaggi fiscali della previdenza: si esce al 23% e si perdono gli anni di partecipazione.") }
        return punti
    }

    /// Punti a favore del cambio.
    var siGuadagna: [String] {
        var punti: [String] = []
        if e.resto.costoAnnuo > e.cambio.costoAnnuo + 0.05 {
            let risparmio = (e.resto.costoAnnuo - e.cambio.costoAnnuo) / 100 * e.reinvestito
            punti.append("Costi annui più bassi: \(CifreDoc.percento(e.cambio.costoAnnuo, decimali: 2)) contro \(CifreDoc.percento(e.resto.costoAnnuo, decimali: 2)), circa \(CifreDoc.euro(risparmio)) l'anno.")
        }
        if e.cambio.rendimento > e.resto.rendimento + 0.05 {
            punti.append("Rendimento ipotizzato più alto: \(CifreDoc.percento(e.cambio.rendimento)) contro \(CifreDoc.percento(e.resto.rendimento)) lordi.")
        }
        if !b.garanzie.isEmpty { punti.append("Le garanzie del nuovo prodotto: \(b.garanzie)") }
        if let ra = a.sri, let rb = b.sri, rb < ra { punti.append("Meno rischio: indicatore \(rb) su 7 invece di \(ra).") }
        if e.trasferimento { punti.append("Trasferimento senza imposte: gli anni di partecipazione alla previdenza restano.") }
        if e.cambio.aliquota < e.resto.aliquota - 0.05 {
            punti.append("Imposta sul guadagno più bassa: \(CifreDoc.percento(e.cambio.aliquota, decimali: 2)) contro \(CifreDoc.percento(e.resto.aliquota, decimali: 2)).")
        }
        if let s = b.scadenza { punti.append("Scadenza definita: \(CifreDoc.dataBreve(s)).") }
        return punti
    }

    var prossimiPassi: [String] {
        var passi: [String] = []
        if convieneCambiare && e.sostituzione {
            passi.append("Verificare le condizioni di riscatto di \(a.nome) e la data migliore per uscire.")
            passi.append("Leggere insieme il KID di \(b.nome).")
        } else if e.sostituzione {
            passi.append("Lasciare \(a.nome) dove si trova e rivederla al prossimo resoconto.")
        } else {
            passi.append("Scegliere tra le due proposte e leggere insieme il KID.")
        }
        if let s = a.scadenza, e.sostituzione, s < (Calendar.current.date(byAdding: .year, value: 1, to: data) ?? data) {
            passi.append("\(a.nome) scade il \(CifreDoc.dataBreve(s)): decidere prima della scadenza.")
        }
        return passi
    }
}
