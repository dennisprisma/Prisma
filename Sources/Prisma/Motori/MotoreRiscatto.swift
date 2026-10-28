import Foundation

/// Un riscatto totale della posizione a una data, anno per anno da oggi: valore, penale, imposte, netto.
struct RiscattoAnno: Identifiable, Hashable {
    /// Anni da oggi (0 = oggi; per una proposta 0 = alla sottoscrizione).
    let anni: Int
    let data: Date
    /// Anno di contratto in cui cade il riscatto (1 = primi 12 mesi, 2 = dal 13° mese).
    let annoContratto: Int
    /// false nei mesi di blocco del riscatto: le cifre restano un'ipotesi, il riscatto non si può chiedere.
    let possibile: Bool
    let versato: Double
    /// Valore ipotizzato del contratto, già al netto dei costi del prodotto e del bollo annuo.
    let valore: Double
    /// Penale dell'anno di contratto più il costo d'uscita (% del valore).
    let penalePercento: Double
    let penale: Double
    let imposta: Double
    /// Bollo maturato fino a oggi, trattenuto al riscatto (polizze).
    let bollo: Double
    let netto: Double

    var id: Int { anni }
    var guadagno: Double { netto - versato }
    /// Il riscatto si può chiedere e restituisce almeno quanto versato.
    var recuperaVersato: Bool { possibile && versato > 0 && netto >= versato - 0.005 }
}

/// Il riscatto anno per anno di una polizza o di un investimento, con le penali del contratto.
struct EsitoRiscatto {
    let posizione: Posizione
    let righe: [RiscattoAnno]
    /// Mesi di blocco del riscatto dalla decorrenza (nil se non indicati).
    let mesiBlocco: Int?
    /// Data da cui il riscatto si può chiedere, se oggi è ancora bloccato.
    let riscattabileDal: Date?
    /// Primo anno di contratto senza penali (1 = nessuna penale) e la sua data d'inizio.
    let annoSenzaPenali: Int
    let senzaPenaliDal: Date?
    /// Costo d'uscita fisso (%), che resta anche senza penali.
    let costoUscita: Double

    /// Il primo riscatto possibile che restituisce almeno quanto versato (criterio dichiarato in `criterio`).
    var primoRecupero: RiscattoAnno? { righe.first { $0.recuperaVersato } }
    /// Il primo riscatto possibile senza penali.
    var primoSenzaPenali: RiscattoAnno? { righe.first { $0.possibile && $0.annoContratto >= annoSenzaPenali } }

    static let metodo = "Valore di riscatto anno per anno: proiezione al rendimento atteso con i costi del prodotto e il bollo annuo; penale dell'anno di contratto (della posizione o della scheda prodotto) più il costo d'uscita, sul valore; imposta sul guadagno (valore − penale − versato) con l'aliquota della posizione; bollo maturato fino a oggi trattenuto al riscatto. Nei mesi di blocco il riscatto non si può chiedere. Multiramo: bollo sulla sola parte in fondi; la garanzia della gestione separata secondo il consolidamento (senza, vale solo a scadenza)."
    static let criterio = "Primo anno conveniente: il primo riscatto possibile (fuori dai mesi di blocco) il cui netto, tolte penale, costo d'uscita, bollo maturato e imposte, è almeno pari a quanto versato fino a quel momento."
}

/// Valore di riscatto anno per anno: la proiezione della posizione (rendimento atteso, costi, bollo) e, per
/// ogni anno, la penale dell'anno di contratto (della posizione o della scheda prodotto), il costo d'uscita,
/// il blocco del riscatto, l'imposta sul guadagno (valore − penale − versato) e il bollo maturato fino a oggi.
/// Solo polizze, fondi ed ETF: la previdenza si riscatta secondo le sue cause (`CausaPrevidenza`).
enum MotoreRiscatto {
    /// Anni mostrati al massimo.
    static let anniMassimi = 40

    static func calcola(_ p: Posizione, prodotto: Prodotto? = nil, anni: Int? = nil, data: Date = Date()) -> EsitoRiscatto? {
        guard p.area.proiettabile, p.stato != .chiusa else { return nil }
        switch p.regime {
        case .polizza, .fondo: break
        case .previdenza, .deposito, .esente: return nil
        }
        let cal = Calendar.current
        let inEssere = p.stato == .inEssere
        // Una proposta parte oggi; una posizione in essere serve la decorrenza per l'anno di contratto
        let partenza: Date? = inEssere ? p.decorrenza : Optional(data)
        guard let inizio = partenza else { return nil }
        let blocco = p.bloccoRiscatto(prodotto: prodotto)
        let uscita = max(0, p.costoUscita ?? 0)

        // Primo anno di contratto da cui non ci sono più penali
        var ultimoConPenale = 0
        for anno in 1...60 where p.penale(anno: anno, prodotto: prodotto) > 0 { ultimoConPenale = anno }
        let annoSenzaPenali = ultimoConPenale + 1

        // Quanti anni: fino alla scadenza o, senza scadenza, almeno 10 e fino alla fine delle penali
        let annoOggi = (cal.dateComponents([.year], from: inizio, to: data).year ?? 0) + 1
        let predefiniti: Int
        if let mesi = p.mesiResidui(al: data) {
            predefiniti = max(1, Int((Double(mesi) / 12).rounded(.up)))
        } else {
            predefiniti = max(IpotesiCalcolo.orizzontePredefinito, annoSenzaPenali - annoOggi)
        }
        let n = min(max(1, anni ?? predefiniti), anniMassimi)

        var par = ParametriProiezione(posizione: p)
        par.anni = n
        par.mesiEsatti = nil
        let punti = MotoreProiezione.calcola(par).punti
        let aliquota = MotoreFiscale.aliquotaGuadagno(p)
        // Polizze: il bollo maturato fino a oggi si paga al riscatto (stima sul valore di oggi, come nel resoconto);
        // quello degli anni futuri è già tolto dal valore ipotizzato
        var bollo = 0.0
        if inEssere, p.regime == .polizza, p.soggettaBollo {
            let anniTrascorsi = max(0, data.timeIntervalSince(inizio) / (365.25 * 86_400))
            bollo = RegoleFiscali.bollo / 100 * p.valore * p.quotaBollo * anniTrascorsi
        }

        var righe: [RiscattoAnno] = []
        for k in 0...n {
            guard k < punti.count, let quando = cal.date(byAdding: .year, value: k, to: data) else { break }
            let annoContratto = (cal.dateComponents([.year], from: inizio, to: quando).year ?? 0) + 1
            let mesiTrascorsi = cal.dateComponents([.month], from: inizio, to: quando).month ?? 0
            let possibile = blocco.map { mesiTrascorsi >= $0 } ?? true
            let valore = punti[k].valore
            let versato = punti[k].versato
            let percento = p.penale(anno: annoContratto, prodotto: prodotto) + uscita
            let penale = valore * percento / 100
            // Multiramo a due parti: l'aliquota pesata sul valore di ogni parte nell'anno del riscatto
            let aliquotaK = p.multiramoDivisa
                ? p.aliquotaPesata(valore: valore, valoreGestione: punti[k].valoreGestione ?? 0) : aliquota
            let imposta = max(0, valore - penale - versato) * aliquotaK / 100
            righe.append(RiscattoAnno(anni: k, data: quando, annoContratto: annoContratto, possibile: possibile,
                                      versato: versato, valore: valore, penalePercento: percento, penale: penale,
                                      imposta: imposta, bollo: bollo, netto: valore - penale - imposta - bollo))
        }

        var riscattabileDal: Date? = nil
        if let mesi = blocco, let d = cal.date(byAdding: .month, value: mesi, to: inizio), d > data { riscattabileDal = d }
        let senzaPenaliDal: Date? = annoSenzaPenali > 1 ? cal.date(byAdding: .year, value: annoSenzaPenali - 1, to: inizio) : nil
        return EsitoRiscatto(posizione: p, righe: righe, mesiBlocco: blocco, riscattabileDal: riscattabileDal,
                             annoSenzaPenali: annoSenzaPenali, senzaPenaliDal: senzaPenaliDal, costoUscita: uscita)
    }
}
