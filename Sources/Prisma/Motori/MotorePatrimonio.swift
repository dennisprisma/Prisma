import Foundation

/// Il patrimonio del cliente nel tempo: tutte le posizioni insieme, anno per anno, com'è oggi e con le
/// proposte aperte. Investimenti, risparmio e previdenza seguono la proiezione di ciascuno (ferma alla
/// scadenza); i conti crescono al loro rendimento; gli immobili restano al valore di oggi; i debiti
/// scendono fino a zero alla scadenza. Valori prima delle imposte finali.
struct PatrimonioNelTempo {
    struct Traguardo: Identifiable {
        let obiettivo: Obiettivo
        let anno: Int
        var id: String { obiettivo.id }
    }

    let anni: Int
    /// Patrimonio netto (attività meno debiti) anno per anno; `versato` è il netto di oggi più i versamenti futuri.
    let oggi: [PuntoProiezione]
    /// Lo stesso con le proposte aperte (nil se non ce ne sono).
    let conProposte: [PuntoProiezione]?
    let proposte: [Posizione]
    let traguardi: [Traguardo]
    /// Versamenti di un anno, oggi e con le proposte.
    let versamentiAnnui: Double
    let versamentiAnnuiProposte: Double

    var nettoOggi: Double { oggi.first?.valore ?? 0 }
    func valore(_ anno: Int, conProposte: Bool = false) -> Double {
        let serie = conProposte ? (self.conProposte ?? oggi) : oggi
        return serie.first { $0.anno == anno }?.valore ?? serie.last?.valore ?? 0
    }
    /// In euro di oggi, con l'inflazione delle ipotesi di Prisma.
    func reale(_ v: Double, anno: Int) -> Double { v / pow(1 + IpotesiCalcolo.inflazione / 100, Double(anno)) }
    var differenzaProposte: Double? { conProposte.map { _ in valore(anni, conProposte: true) - valore(anni) } }
    var vuoto: Bool { oggi.allSatisfy { abs($0.valore) < 0.5 } && conProposte == nil }
}

enum MotorePatrimonio {
    static let orizzonte = 20

    static func calcola(_ posizioni: [Posizione], obiettivi: [Obiettivo] = [], anni: Int = orizzonte, oggi: Date = Date()) -> PatrimonioNelTempo {
        let inEssere = posizioni.filter { $0.stato == .inEssere }
        let proposte = posizioni.filter { $0.stato == .proposta && $0.esito != .rifiutata && $0.esito != .accettata && $0.area.proiettabile }
        let base = serie(inEssere, anni: anni)
        var conProposte: [PuntoProiezione]?
        if !proposte.isEmpty {
            // Il versamento iniziale delle proposte viene dalla liquidità: non si conta due volte
            let iniziale = proposte.reduce(0) { $0 + $1.versamentoIniziale }
            let liquidita = inEssere.filter { $0.area == .liquidita }.reduce(0) { $0 + $1.valore }
            let presoDaiConti = min(iniziale, liquidita)
            let extra = serie(proposte, anni: anni)
            conProposte = zip(base, extra).map { a, b in
                PuntoProiezione(anno: a.anno, versato: a.versato + b.versato - presoDaiConti, valore: a.valore + b.valore - presoDaiConti)
            }
        }
        let cal = Calendar.current
        let traguardi = obiettivi.compactMap { o -> PatrimonioNelTempo.Traguardo? in
            let mesi = cal.dateComponents([.month], from: oggi, to: o.scadenza).month ?? 0
            let anno = Int((Double(mesi) / 12).rounded())
            return (0...anni).contains(anno) ? .init(obiettivo: o, anno: anno) : nil
        }.sorted { $0.anno < $1.anno }
        return PatrimonioNelTempo(anni: anni, oggi: base, conProposte: conProposte, proposte: proposte, traguardi: traguardi,
                                  versamentiAnnui: inEssere.filter(\.area.proiettabile).reduce(0) { $0 + $1.premioAnnuo },
                                  versamentiAnnuiProposte: proposte.reduce(0) { $0 + $1.premioAnnuo })
    }

    /// La somma anno per anno delle posizioni: valore (debiti in negativo) e versato cumulato.
    static func serie(_ posizioni: [Posizione], anni: Int) -> [PuntoProiezione] {
        var valori = [Double](repeating: 0, count: anni + 1)
        var versati = valori
        for p in posizioni {
            for (i, v) in andamento(p, anni: anni).enumerated() {
                valori[i] += v.valore
                versati[i] += v.versato
            }
        }
        return (0...anni).map { PuntoProiezione(anno: $0, versato: versati[$0], valore: valori[$0]) }
    }

    /// Valore e versato di una posizione anno per anno (anni + 1 punti).
    static func andamento(_ p: Posizione, anni: Int) -> [(valore: Double, versato: Double)] {
        let punti = 0...anni
        switch p.area {
        case .protezione:
            return punti.map { _ in (0, 0) }
        case .immobili:
            return punti.map { _ in (p.valore, p.valore) }
        case .debiti:
            // Rimborso lineare fino alla scadenza; senza scadenza resta com'è
            let durata = p.anniAllaScadenza.map(Double.init)
            return punti.map { a in
                let residuo = durata.map { p.valore * max(0, 1 - Double(a) / $0) } ?? p.valore
                return (-residuo, -residuo)
            }
        case .liquidita:
            let r = (p.rendimentoAtteso ?? 0) / 100
            return punti.map { a in (p.valore * pow(1 + r, Double(a)), p.valore) }
        case .investimento, .risparmio, .previdenza:
            var par = ParametriProiezione(posizione: p)
            let durata = min(anni, p.anniAllaScadenza ?? anni)
            par.anni = durata
            let e = MotoreProiezione.calcola(par)
            return punti.map { a in
                // Dopo la scadenza il capitale resta (prima delle imposte), senza nuovi versamenti
                let pt = e.punti[min(a, e.punti.count - 1)]
                return (pt.valore, pt.versato)
            }
        }
    }

    /// Le righe per Eve e per le schede.
    static func sintesi(_ p: PatrimonioNelTempo) -> [String] {
        var righe = ["Patrimonio netto oggi \(Formati.euro(p.nettoOggi)); tra 10 anni circa \(Formati.euro(p.valore(10))), tra \(p.anni) circa \(Formati.euro(p.valore(p.anni))) (\(Formati.euro(p.reale(p.valore(p.anni), anno: p.anni))) in euro di oggi), con i versamenti attuali di \(Formati.euro(p.versamentiAnnui)) l'anno."]
        if let d = p.differenzaProposte {
            righe.append("Con le proposte aperte (\(p.proposte.map(\.nome).joined(separator: ", "))): \(Formati.euro(p.valore(p.anni, conProposte: true))) tra \(p.anni) anni, \(d >= 0 ? "+" : "")\(Formati.euro(d)) rispetto a oggi.")
        }
        for t in p.traguardi.prefix(3) {
            righe.append("Obiettivo «\(t.obiettivo.titolo)» tra \(t.anno) anni (\(Formati.euro(t.obiettivo.importo))): il patrimonio stimato allora è \(Formati.euro(p.valore(t.anno, conProposte: p.conProposte != nil))).")
        }
        return righe
    }
}
