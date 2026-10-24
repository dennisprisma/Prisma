import Foundation

/// I testi della prova di resistenza. Il report si rivolge al cliente con il tu, con parole semplici:
/// non per spaventare, ma per sapere prima cosa può succedere e se è sopportabile.
struct TestiResistenza {
    let r: ProvaResistenza
    let cliente: String
    let data: Date

    init(_ r: ProvaResistenza, cliente: Cliente?, data: Date = Date()) {
        self.r = r
        self.cliente = cliente?.nome ?? "Cliente"
        self.data = data
    }

    static let titolo = "Prova di resistenza"
    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Stime prudenti su scenari ipotetici, non previsioni: i rendimenti e le perdite future non sono garantiti."

    var mercati: ProvaResistenza.Scenario? { r.scenario(.mercati) }
    var inflazione: ProvaResistenza.Scenario? { r.scenario(.inflazione) }
    var immobili: ProvaResistenza.Scenario? { r.scenario(.immobili) }

    /// Le posizioni in essere che entrano nella prova (quelle con un valore), per il canale in copertina.
    var canali: [Canale] {
        let voci = r.scenari.flatMap(\.voci).map(\.posizione)
        return Canale.allCases.filter { c in voci.contains { $0.canale == c } }
    }

    var ruoloConsulente: String {
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Consulente Alleanza Assicurazioni e consulenza finanziaria"
    }

    /// La perdita di uno scenario in euro e in percentuale, per i titoli.
    func perdita(_ s: ProvaResistenza.Scenario?) -> String {
        guard let s, !s.voci.isEmpty else { return "nessuna perdita" }
        return "circa \(CifreDoc.euro(s.perdita)), il \(CifreDoc.percento(s.quota * 100))"
    }

    var titoloScenari: String {
        guard let m = mercati, !m.voci.isEmpty else { return "I tuoi risparmi non sono esposti ai mercati" }
        return "In un anno di crisi i tuoi investimenti potrebbero perdere circa \(CifreDoc.euro(m.perdita))"
    }

    var titoloProfilo: String {
        switch r.giudizio {
        case .dentro?: return "È una perdita che il tuo profilo può sopportare"
        case .alLimite?: return "È una perdita al limite di quanto il tuo profilo sopporta"
        case .oltre?: return "È una perdita più grande di quanto il tuo profilo sopporta"
        case nil: return "Quanto rischio sei disposto a correre?"
        }
    }

    var spiegazioneProfilo: String {
        guard let m = mercati else { return "" }
        let quota = CifreDoc.percento(m.quota * 100)
        guard let s = r.sopportabile, let p = r.propensione else {
            return "La stima è il \(quota) dei tuoi risparmi. Per dire se è sopportabile serve il tuo profilo di rischio: lo definiamo insieme."
        }
        return "La stima è il \(quota) dei tuoi risparmi; con una propensione \(p.nome.lowercased()) hai indicato di poter sopportare fino al \(CifreDoc.condizione(s))."
    }

    var sintesi: [(String, String)] {
        var punti: [(String, String)] = []
        if let m = mercati, !m.voci.isEmpty {
            punti.append(("Se i mercati crollano", "In un anno come il 2008 o il 2022 la perdita stimata è di \(perdita(m)) dei tuoi risparmi."))
        }
        if let g = r.giudizio, let s = r.sopportabile {
            punti.append(("Il tuo profilo", "\(g.etichetta): sopporti fino al \(CifreDoc.condizione(s))."))
        }
        if r.patrimonioFinanziario > 0 {
            punti.append(("Cosa è al riparo", "Il \(CifreDoc.percento(r.quotaProtetta * 100, decimali: 0)) dei tuoi risparmi ha il capitale garantito o non dipende dai mercati."))
        }
        if let i = inflazione, !i.voci.isEmpty {
            punti.append(("Se i prezzi corrono", "Con l'inflazione al \(CifreDoc.condizione(MotoreResistenza.inflazioneAlta)) per \(MotoreResistenza.anniInflazione) anni perderesti circa \(CifreDoc.euro(i.perdita)) di potere d'acquisto."))
        }
        if let c = immobili, !c.voci.isEmpty {
            punti.append(("Se la casa vale meno", "Un calo del \(CifreDoc.condizione(MotoreResistenza.caloImmobili)) toglierebbe \(CifreDoc.euro(c.perdita)) dal patrimonio, ma solo sulla carta finché non vendi."))
        }
        return punti
    }

    var prossimiPassi: [String] {
        var passi: [String] = []
        switch r.giudizio {
        case .oltre?: passi.append("Spostare una parte su soluzioni con il capitale garantito, o rivedere insieme il profilo di rischio.")
        case .alLimite?: passi.append("Decidere insieme se ridurre un po' il rischio o tenerlo, sapendo cosa può succedere.")
        case .dentro?: passi.append("Restare investiti anche negli anni difficili: vendere dopo un calo trasforma una perdita sulla carta in una perdita vera.")
        case nil: passi.append("Definire insieme il profilo di rischio, per sapere quanta perdita è sopportabile.")
        }
        if let i = inflazione, i.quota > 0.08 { passi.append("Far lavorare la liquidità oltre la riserva di emergenza, perché non perda valore con i prezzi.") }
        passi.append("Rifare la prova ogni anno, al riesame, e ogni volta che cambia qualcosa.")
        return passi
    }

    /// Il metodo, per il prospetto: come si stimano le tre perdite.
    var metodo: [String] {
        let soglie = MotoreResistenza.caloPerSRI.sorted { $0.key < $1.key }.map { "SRI \($0.key) \(CifreDoc.condizione($0.value))" }.joined(separator: ", ")
        return [
            "Mercati: perdita di un anno di forte crisi secondo l'indicatore di rischio del KID (\(soglie)). Conti e gestioni separate (Ramo I) non perdono: il capitale è garantito; nelle multiramo perde solo la parte fuori dalla gestione separata (50% se non indicata). Senza SRI si stima dall'area: risparmio 2, previdenza 3, investimento 4.",
            "Inflazione: \(CifreDoc.condizione(MotoreResistenza.inflazioneAlta)) l'anno per \(MotoreResistenza.anniInflazione) anni; perde potere d'acquisto ciò che rende meno, al netto dei costi annui (i conti senza rendimento indicato rendono zero).",
            "Immobili: calo del \(CifreDoc.condizione(MotoreResistenza.caloImmobili)) del valore; i debiti restano uguali, quindi il calo pesa tutto sul patrimonio netto.",
            "Profilo: perdita sopportabile in un anno sul patrimonio finanziario secondo la propensione (prudente 5%, moderata 10%, dinamica 20%, aggressiva 30%); fino a un quarto oltre è «al limite».",
        ]
    }
}
