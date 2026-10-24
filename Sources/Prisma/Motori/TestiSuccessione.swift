import Foundation

/// I testi del passaggio generazionale. Il report si rivolge al cliente con il tu, con delicatezza:
/// non si parla di morte, ma di proteggere chi si ama e di non lasciare sorprese.
struct TestiSuccessione {
    let s: Successione
    let cliente: String
    let data: Date

    init(_ s: Successione, cliente: Cliente?, data: Date = Date()) {
        self.s = s
        self.cliente = cliente?.nome ?? "Cliente"
        self.data = data
    }

    static let titolo = "Il passaggio generazionale"
    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Stima semplificata della successione senza testamento: non sostituisce il parere di un notaio."

    var beneficiari: [Successione.Voce] { s.voci.filter { $0.destino == .beneficiari } }
    var asse: [Successione.Voce] { s.voci.filter { $0.destino == .asse } }

    var canali: [Canale] { Canale.allCases.filter { c in s.voci.contains { $0.posizione.canale == c } } }

    var ruoloConsulente: String {
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Consulente Alleanza Assicurazioni e consulenza finanziaria"
    }

    var titoloQuadro: String {
        "Alla tua famiglia andrebbero circa \(CifreDoc.euro(s.totale)): \(CifreDoc.euro(s.fuoriAsse)) subito, \(CifreDoc.euro(s.asseNetto)) dopo la successione"
    }

    var titoloEredi: String {
        s.eredi.isEmpty ? "Senza testamento, nessuno dei tuoi familiari registrati erediterebbe"
            : "Senza testamento, la legge dividerebbe così"
    }

    var titoloSistemare: String {
        let n = s.daSistemare.count + (s.conviventeEscluso == nil ? 0 : 1)
        return n == 0 ? "Tutto in ordine: beneficiari indicati e famiglia tutelata"
            : "\(n == 1 ? "Una cosa" : "\(n) cose") da sistemare, per non lasciare sorprese"
    }

    /// Perché una polizza con il beneficiario designato è diversa da un conto.
    static let perchePolizza = "Una polizza vita non entra nell'eredità: va direttamente alle persone che hai indicato come beneficiari, anche se non sono tuoi eredi, senza imposta di successione e in poche settimane. Un conto o un fondo, invece, si blocca fino alla dichiarazione di successione e si divide secondo la legge."

    var sintesi: [(String, String)] {
        var punti: [(String, String)] = []
        punti.append(("Subito, ai beneficiari", "\(CifreDoc.euro(s.fuoriAsse)) da polizze, coperture e previdenza, fuori dall'eredità e senza imposta di successione."))
        punti.append(("Dopo la successione", "\(CifreDoc.euro(s.asseNetto)) agli eredi, debiti tolti, dopo alcuni mesi."))
        if !s.eredi.isEmpty {
            punti.append(("Chi eredita", s.eredi.map { "\($0.nome) \(MotoreSuccessione.frazione($0.quota))" }.joined(separator: ", ") + "."))
        }
        punti.append(("Le imposte", s.impostaSuccessione > 0.5 ? "Circa \(CifreDoc.euro(s.imposte)), di cui \(CifreDoc.euro(s.impostaSuccessione)) di successione."
            : (s.ipocatastali > 0.5 ? "Nessuna imposta di successione, entro le franchigie; circa \(CifreDoc.euro(s.ipocatastali)) di ipotecaria e catastale sugli immobili." : "Nessuna imposta di successione, entro le franchigie.")))
        if let cv = s.conviventeEscluso {
            punti.append(("Chi resta scoperto", "\(cv) non erediterebbe: lo tutelano solo un testamento o una polizza con lui come beneficiario."))
        } else if let v = s.daSistemare.first {
            punti.append(("Da sistemare", "\(v.posizione.nome): \((v.avviso ?? "").prefix(1).lowercased() + (v.avviso ?? "").dropFirst())"))
        }
        return punti
    }

    var prossimiPassi: [String] {
        var passi: [String] = []
        for v in s.daSistemare.prefix(3) {
            passi.append(v.posizione.beneficiari.isEmpty ? "Indicare i beneficiari di \(v.posizione.nome)." : "Rivedere i beneficiari di \(v.posizione.nome).")
        }
        if let cv = s.conviventeEscluso { passi.append("Tutelare \(cv): beneficiario di una polizza o testamento, con il notaio.") }
        if s.eredi.contains(where: \.minorenne) { passi.append("Valutare chi gestirebbe i beni dei figli minorenni (tutore, polizza con capitale rateizzato).") }
        passi.append("Rivedere i beneficiari a ogni cambiamento di famiglia: matrimonio, figli, separazione.")
        return passi
    }

    var metodo: [String] {
        [
            "Fuori dall'asse ereditario, ai beneficiari: polizze vita (valore), coperture caso morte (capitale assicurato), previdenza complementare (valore). Le coperture infortuni non sono contate.",
            "Nell'asse: fondi e titoli, conti, immobili (al valore indicato in Posizioni), meno i debiti.",
            "Eredi senza testamento dai familiari registrati: coniuge e figli (al coniuge metà con un figlio, un terzo con più figli); senza figli, coniuge due terzi e il resto a genitori e fratelli; senza coniuge né figli, genitori e fratelli. Il convivente non eredita.",
            "Imposta di successione per erede: coniuge, figli e genitori \(CifreDoc.condizione(MotoreSuccessione.aliquotaLineaRetta)) oltre \(CifreDoc.euro(MotoreSuccessione.franchigiaLineaRetta)); fratelli e sorelle \(CifreDoc.condizione(MotoreSuccessione.aliquotaFratelli)) oltre \(CifreDoc.euro(MotoreSuccessione.franchigiaFratelli)); altri \(CifreDoc.condizione(MotoreSuccessione.aliquotaAltri)). Ipotecaria e catastale \(CifreDoc.condizione(MotoreSuccessione.ipocatastale)) sugli immobili, \(CifreDoc.euro(MotoreSuccessione.ipocatastaleFissa)) fissi per la prima casa.",
            "Gli immobili si tassano sul valore catastale, di solito più basso di quello indicato: la stima delle imposte è prudente.",
        ]
    }
}
