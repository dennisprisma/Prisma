import Foundation

/// I testi del documento sui costi. Il report si rivolge al cliente con il tu: quanto paga, quanto pesa
/// nel tempo, cosa riceve in cambio e dove potrebbe spendere meno senza cambiare rischio.
struct TestiCosti {
    let a: AnalisiCosti
    let cliente: String
    let data: Date
    /// Valore complessivo anno per anno, con e senza i costi dei prodotti.
    let serie: (con: [Double], senza: [Double])

    init(_ a: AnalisiCosti, cliente: Cliente?, data: Date = Date()) {
        self.a = a
        self.cliente = cliente?.nome ?? "Cliente"
        self.data = data
        serie = MotoreCosti.serie(a)
    }

    static let titolo = "Il costo dei tuoi investimenti"
    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Costi dai contratti e dai KID; proiezioni con i rendimenti ipotizzati, non garantiti."

    var canali: [Canale] { Canale.allCases.filter { c in a.voci.contains { $0.posizione.canale == c } } }

    var ruoloConsulente: String {
        if canali == [.alleanza] { return "Consulente Alleanza Assicurazioni" }
        if canali == [.indipendente] { return "Consulenza finanziaria" }
        return "Alleanza Assicurazioni · consulenza finanziaria"
    }

    var titoloOggi: String {
        guard let m = a.costoMedio else { return "Mancano i costi dei tuoi investimenti" }
        return "Quest'anno i tuoi investimenti costano circa \(CifreDoc.euro(a.euroAnno)), il \(CifreDoc.percento(m, decimali: 2)) del loro valore"
    }

    var titoloTempo: String {
        "In 20 anni i costi tolgono circa \(CifreDoc.euro(a.perso20)) a quello che ti resta"
    }

    var titoloAlternative: String {
        a.conAlternativa.isEmpty ? "I tuoi costi sono già in linea: nessuna alternativa conviene"
            : "Con lo stesso rischio potresti tenere circa \(CifreDoc.euro(a.risparmioPossibile)) in più"
    }

    /// Cosa offre in cambio una posizione: garanzie e coperture del contratto, o la sua natura.
    static func inCambio(_ p: Posizione) -> String {
        if !p.garanzie.isEmpty { return p.garanzie }
        if p.gestioneSeparata { return "Capitale garantito e rendimenti consolidati ogni anno." }
        if p.regime == .polizza { return "Polizza vita: beneficiari designati, fuori dall'asse ereditario." }
        if p.regime == .previdenza { return "Previdenza: versamenti deducibili, imposte ridotte alla pensione." }
        return "Gestione professionale e diversificazione."
    }

    var sintesi: [(String, String)] {
        var punti: [(String, String)] = []
        if let m = a.costoMedio {
            punti.append(("Quanto paghi", "Circa \(CifreDoc.euro(a.euroAnno)) quest'anno, in media il \(CifreDoc.percento(m, decimali: 2)) l'anno."))
            punti.append(("Quanto pesa nel tempo", "\(CifreDoc.euro(a.perso10)) in 10 anni e \(CifreDoc.euro(a.perso20)) in 20, contando anche i rendimenti che quei soldi non producono."))
        }
        if let v = a.voci.first(where: { $0.livello == .alto }) {
            punti.append(("Il costo più alto", "\(v.posizione.nome), il \(CifreDoc.percento(v.annuo, decimali: 2)) l'anno: in cambio \(Self.inCambio(v.posizione).prefix(1).lowercased() + Self.inCambio(v.posizione).dropFirst())"))
        }
        if let v = a.conAlternativa.first, let x = v.alternativa {
            punti.append(("Dove risparmiare", "Per \(v.posizione.nome), \(x.prodotto.nome) con lo stesso rischio lascerebbe circa \(CifreDoc.euro(x.guadagno)) in più in \(x.anni) anni, uscita compresa."))
        } else if !a.voci.isEmpty {
            punti.append(("Nessun cambio necessario", "Con lo stesso rischio non c'è un'alternativa che lasci abbastanza di più da giustificare il cambio."))
        }
        if !a.senzaDati.isEmpty {
            punti.append(("Da completare", "Mancano i costi di \(a.senzaDati.map(\.nome).joined(separator: ", ")): li leggiamo insieme dal KID."))
        }
        return punti
    }

    var prossimiPassi: [String] {
        var passi: [String] = []
        for v in a.conAlternativa.prefix(2) {
            if let x = v.alternativa { passi.append("Valutare insieme il passaggio da \(v.posizione.nome) a \(x.prodotto.nome), con il confronto completo.") }
        }
        if !a.senzaDati.isEmpty { passi.append("Recuperare il KID di \(a.senzaDati.map(\.nome).joined(separator: ", ")).") }
        passi.append("Rivedere i costi ogni anno, al riesame: anche mezzo punto, in vent'anni, conta.")
        return passi
    }

    var metodo: [String] {
        [
            "Costo annuo: costi di gestione più trattenuto sul rendimento, in percentuale del valore; costo d'ingresso sui versamenti futuri. Costi di quest'anno: costo annuo sul valore di oggi più l'ingresso sui versamenti dell'anno.",
            "Quanto tolgono: differenza tra il netto finale della stessa posizione senza i costi del prodotto e quello con i costi, in 10 e 20 anni o fino alla scadenza; imposte e bollo restano in entrambi i calcoli.",
            "Giudizio: sotto il \(CifreDoc.condizione(MotoreCosti.sogliaBasso)) l'anno contenuto, oltre il \(CifreDoc.condizione(MotoreCosti.sogliaAlto)) alto.",
            "Alternative: prodotti del catalogo con la stessa area e lo stesso indicatore di rischio, almeno \(CifreDoc.condizione(MotoreCosti.scartoMinimo)) l'anno meno cari, con lo stesso rendimento lordo; contano penali, imposte d'uscita e costo d'ingresso, e devono lasciare almeno \(CifreDoc.euro(MotoreCosti.guadagnoMinimo)) in più in 10 anni. Una gestione separata si confronta solo con un'altra.",
        ]
    }

    /// Le etichette dell'asse del grafico: oggi, poi ogni 5 anni.
    var etichetteAsse: [String] {
        serie.con.indices.map { $0 == 0 ? "oggi" : ($0 % 5 == 0 ? "\($0)° anno" : "") }
    }
}
