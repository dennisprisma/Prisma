import Foundation

/// Il rendimento effettivo (money-weighted) di flussi di denaro datati: il tasso annuo che porta
/// versamenti e incassi del cliente al valore finale (XIRR, anni contati a giorni / 365).
/// Serve al resoconto (rendimento dei versamenti) e all'incidenza dei costi come nel KID.
enum Rendimenti {
    /// Giorni di un anno nei calcoli a date reali (convenzione dell'XIRR).
    static let giorniAnno = 365.0
    /// Intervallo dei tassi cercati: da −99% a +1000% l'anno.
    static let tassoMinimo = -0.99
    static let tassoMassimo = 10.0

    /// Giorni interi tra due date (arrotondati: l'ora legale non sposta i conti).
    static func giorni(da inizio: Date, a fine: Date) -> Double {
        (fine.timeIntervalSince(inizio) / 86_400).rounded()
    }

    /// Il tasso annuo (%) dei flussi datati: importi positivi = versamenti del cliente, negativi = somme
    /// incassate (riscatti parziali, cedole); `valoreFinale` = valore alla data `fine`. I flussi dopo la
    /// fine non contano. Nessun risultato senza almeno un versamento e un'entrata per il cliente, o se
    /// il calcolo non converge.
    static func xirr(_ flussi: [(data: Date, importo: Double)], valoreFinale: Double, al fine: Date) -> Double? {
        var elenco: [(anni: Double, importo: Double)] = []
        for f in flussi {
            let g = giorni(da: f.data, a: fine)
            if g >= 0 { elenco.append((anni: g / giorniAnno, importo: f.importo)) }
        }
        return tasso(elenco, valoreFinale: valoreFinale)
    }

    /// Il tasso annuo (%) tale che Σ importo · (1 + r)^anni = valoreFinale, con `anni` = tempo dal flusso
    /// alla fine. Newton dal 5%; se non converge, bisezione nell'intervallo con il cambio di segno più
    /// vicino a zero. nil se i flussi non cambiano segno o se non c'è soluzione tra −99% e +1000%.
    static func tasso(_ flussi: [(anni: Double, importo: Double)], valoreFinale: Double) -> Double? {
        let elenco = flussi.filter { $0.importo.isFinite && $0.anni.isFinite && $0.anni >= 0 && $0.importo != 0 }
        guard valoreFinale.isFinite, valoreFinale >= 0 else { return nil }
        // Serve almeno un versamento e almeno un'entrata per il cliente (il valore finale o un incasso)
        guard elenco.contains(where: { $0.importo > 0 }),
              valoreFinale > 0 || elenco.contains(where: { $0.importo < 0 }) else { return nil }
        // Senza tempo tra i flussi e la fine il tasso non si può misurare
        guard elenco.contains(where: { $0.anni > 0 }) else { return nil }

        func eccesso(_ r: Double) -> Double {
            let base = 1 + r
            var somma = -valoreFinale
            for f in elenco { somma += f.importo * Foundation.pow(base, f.anni) }
            return somma
        }
        func derivata(_ r: Double) -> Double {
            let base = 1 + r
            var somma = 0.0
            for f in elenco where f.anni > 0 { somma += f.importo * f.anni * Foundation.pow(base, f.anni - 1) }
            return somma
        }
        let scala = max(valoreFinale, elenco.reduce(0.0) { $0 + abs($1.importo) })
        let precisione = scala * 1e-9
        func valido(_ r: Double) -> Bool {
            r.isFinite && r >= tassoMinimo && r <= tassoMassimo && abs(eccesso(r)) <= precisione
        }

        // Newton
        var r = 0.05
        for _ in 0..<60 {
            let v = eccesso(r)
            if !v.isFinite { break }
            if abs(v) <= precisione { break }
            let d = derivata(r)
            guard d.isFinite, abs(d) > 1e-12 else { break }
            let nuovo = r - v / d
            guard nuovo.isFinite, nuovo > tassoMinimo - 0.009, nuovo < tassoMassimo * 2 else { break }
            let passo = abs(nuovo - r)
            r = min(max(nuovo, tassoMinimo), tassoMassimo)
            if passo < 1e-13 { break }
        }
        if valido(r) { return r * 100 }

        // Bisezione: l'intervallo con il cambio di segno più vicino a zero
        let griglia: [Double] = [-0.99, -0.9, -0.75, -0.5, -0.25, -0.1, 0, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10]
        var intervalli: [(Double, Double)] = []
        for (a, b) in zip(griglia, griglia.dropFirst()) {
            let fa = eccesso(a), fb = eccesso(b)
            guard fa.isFinite, fb.isFinite else { continue }
            if fa == 0 { return a * 100 }
            if fa * fb < 0 { intervalli.append((a, b)) }
        }
        if let ultimo = griglia.last, eccesso(ultimo) == 0 { return ultimo * 100 }
        guard let scelto = intervalli.min(by: { min(abs($0.0), abs($0.1)) < min(abs($1.0), abs($1.1)) }) else { return nil }
        var basso = scelto.0, alto = scelto.1
        let segnoBasso = eccesso(basso) < 0
        for _ in 0..<200 {
            let medio = (basso + alto) / 2
            if (eccesso(medio) < 0) == segnoBasso { basso = medio } else { alto = medio }
            if alto - basso < 1e-14 { break }
        }
        return (basso + alto) / 2 * 100
    }
}
