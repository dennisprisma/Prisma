import Foundation

/// Come è andata davvero una posizione: dallo storico dei valori rilevati, periodo per periodo,
/// il guadagno tolti i versamenti e il rendimento (metodo di Dietz), concatenati in un rendimento
/// dell'intero periodo che non dipende da quanto e quando si è versato. Il confronto è con il
/// rendimento atteso della posizione, tolti i costi annui (i valori rilevati sono già al netto).
struct AndamentoPosizione {
    struct Periodo: Identifiable {
        let dal: Date
        let al: Date
        let valoreIniziale: Double
        let valoreFinale: Double
        /// Versamenti del periodo (negativi se il versato è sceso, per esempio con un riscatto parziale).
        let versamenti: Double
        /// true se i versamenti sono stimati dai premi periodici (manca il versato in una delle due date).
        let stimati: Bool

        var id: Date { dal }
        var guadagno: Double { valoreFinale - valoreIniziale - versamenti }
        /// Il capitale su cui si misura il guadagno: il valore iniziale più metà dei versamenti.
        var base: Double { valoreIniziale + versamenti / 2 }
        /// Rendimento del periodo in percentuale (nil se la base non è positiva).
        var rendimento: Double? { base > 0 ? guadagno / base * 100 : nil }
        var anni: Double { max(0, al.timeIntervalSince(dal)) / MotoreAndamento.anno }
    }

    struct Punto: Identifiable {
        let data: Date
        let valore: Double
        let versato: Double?
        /// Dove sarebbe la posizione se avesse reso esattamente l'atteso netto dal primo valore.
        let atteso: Double?

        var id: Date { data }
    }

    enum Giudizio {
        case sopra, inLinea, sotto

        var nome: String {
            switch self {
            case .sopra: return "sopra l'atteso"
            case .inLinea: return "in linea con l'atteso"
            case .sotto: return "sotto l'atteso"
            }
        }

        var etichetta: String { nome.prefix(1).uppercased() + nome.dropFirst() }
    }

    let periodi: [Periodo]
    let punti: [Punto]
    /// Rendimento dell'intero periodo in percentuale, periodi concatenati.
    let rendimentoPeriodo: Double
    /// Lo stesso, all'anno: solo con circa un anno di storico (prima non ha senso annualizzare).
    let rendimentoAnnuo: Double?
    /// Atteso annuo netto (atteso meno costi annui), se la posizione ha un rendimento atteso.
    let attesoAnnuo: Double?
    let guadagno: Double
    let versamenti: Double

    var dal: Date { punti.first?.data ?? Date() }
    var al: Date { punti.last?.data ?? Date() }
    var anni: Double { max(0, al.timeIntervalSince(dal)) / MotoreAndamento.anno }
    var stimati: Bool { periodi.contains(where: \.stimati) }

    /// L'atteso netto sullo stesso orizzonte del rendimento mostrato (annuo o del periodo).
    var attesoConfrontabile: Double? {
        guard let a = attesoAnnuo else { return nil }
        return rendimentoAnnuo != nil ? a : (pow(1 + a / 100, anni) - 1) * 100
    }

    /// Effettivo meno atteso, in punti percentuali.
    var scarto: Double? {
        attesoConfrontabile.map { (rendimentoAnnuo ?? rendimentoPeriodo) - $0 }
    }

    var giudizio: Giudizio? {
        guard let s = scarto else { return nil }
        // Un punto all'anno di tolleranza; sui periodi brevi in proporzione (almeno mezzo punto)
        let tolleranza = rendimentoAnnuo != nil ? MotoreAndamento.tolleranza : max(0.5, MotoreAndamento.tolleranza * anni)
        if s > tolleranza { return .sopra }
        if s < -tolleranza { return .sotto }
        return .inLinea
    }
}

enum MotoreAndamento {
    static let anno = 365.25 * 86_400
    /// Punti percentuali all'anno entro cui l'effettivo è «in linea» con l'atteso.
    static let tolleranza = 1.0
    /// Da quanto storico si annualizza: un anno, con qualche giorno di margine sulle date degli estratti.
    static let anniMinimi = 0.95

    /// L'andamento dallo storico dei valori: servono almeno due valori, il primo positivo.
    /// Le coperture e i debiti non hanno un andamento da misurare.
    static func calcola(_ p: Posizione) -> AndamentoPosizione? {
        guard p.area != .protezione, !p.area.passivo else { return nil }
        let storico = p.storicoValori.filter { $0.controvalore >= 0 }.sorted { $0.data < $1.data }
        guard storico.count >= 2, let primo = storico.first, primo.controvalore > 0 else { return nil }

        var periodi: [AndamentoPosizione.Periodo] = []
        for (a, b) in zip(storico, storico.dropFirst()) where b.data > a.data {
            let anni = b.data.timeIntervalSince(a.data) / anno
            let versamenti: Double
            let stimati: Bool
            if let va = a.versato, let vb = b.versato {
                versamenti = vb - va
                stimati = false
            } else {
                // Senza il versato in una delle due date: i premi periodici del periodo
                versamenti = p.premioAnnuo * anni
                stimati = versamenti > 0
            }
            periodi.append(.init(dal: a.data, al: b.data, valoreIniziale: a.controvalore, valoreFinale: b.controvalore,
                                 versamenti: versamenti, stimati: stimati))
        }
        guard !periodi.isEmpty else { return nil }

        // Periodi concatenati: ognuno pesa per il suo rendimento, non per quanto c'era investito
        let fattore = periodi.reduce(1.0) { f, q in f * (1 + (q.rendimento ?? 0) / 100) }
        let cumulato = (fattore - 1) * 100
        let anniTotali = periodi.reduce(0) { $0 + $1.anni }
        let annuo = anniTotali >= anniMinimi && fattore > 0 ? (pow(fattore, 1 / anniTotali) - 1) * 100 : nil
        let atteso = p.rendimentoAtteso.map { $0 - (p.costoComplessivo ?? 0) }

        // La linea dell'atteso: dal primo valore, con gli stessi versamenti (a metà periodo)
        var punti = [AndamentoPosizione.Punto(data: primo.data, valore: primo.controvalore, versato: primo.versato,
                                              atteso: atteso.map { _ in primo.controvalore })]
        var corrente = primo.controvalore
        for q in periodi {
            var prossimo: Double?
            if let a = atteso {
                let r = 1 + a / 100
                corrente = corrente * pow(r, q.anni) + q.versamenti * pow(r, q.anni / 2)
                prossimo = corrente
            }
            let versato = storico.first { $0.data == q.al }?.versato
            punti.append(.init(data: q.al, valore: q.valoreFinale, versato: versato, atteso: prossimo))
        }

        return AndamentoPosizione(periodi: periodi, punti: punti, rendimentoPeriodo: cumulato, rendimentoAnnuo: annuo,
                                  attesoAnnuo: atteso, guadagno: periodi.reduce(0) { $0 + $1.guadagno },
                                  versamenti: periodi.reduce(0) { $0 + $1.versamenti })
    }

    /// Uno scarto in punti percentuali: "+1,2 punti", "−0,8 punti".
    static func punti(_ s: Double) -> String {
        let n = CifreDoc.variazione(s).replacingOccurrences(of: "%", with: "")
        return "\(n) \(abs(s) >= 0.95 && abs(s) < 1.05 ? "punto" : "punti")"
    }

    /// Una frase sull'andamento, per il dettaglio e per Eve.
    static func sintesi(_ a: AndamentoPosizione, nome: String) -> String {
        let quando = "dal \(Formati.dataEstesa.string(from: a.dal)) al \(Formati.dataEstesa.string(from: a.al))"
        let rendimento = a.rendimentoAnnuo.map { "\(CifreDoc.variazione($0)) all'anno" }
            ?? "\(CifreDoc.variazione(a.rendimentoPeriodo)) nel periodo"
        var testo = "\(nome) \(quando) ha reso \(rendimento): \(a.guadagno >= 0 ? "guadagno" : "perdita") di \(Formati.euro(abs(a.guadagno))) tolti i versamenti."
        if let g = a.giudizio, let atteso = a.attesoConfrontabile, let s = a.scarto {
            testo += " È \(g.nome) (atteso \(CifreDoc.percento(atteso)) al netto dei costi"
            testo += g == .inLinea ? ")." : ", \(punti(s)))."
        }
        if a.stimati { testo += " Alcuni versamenti sono stimati dai premi periodici: indicare il versato rende il calcolo esatto." }
        return testo
    }
}
