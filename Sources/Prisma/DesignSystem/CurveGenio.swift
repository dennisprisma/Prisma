import CoreGraphics
import Foundation
import QuartzCore

/// Il genio come mesh: l'istantanea della finestra divisa in `strisce` orizzontali, ognuna portata su un trapezio
/// esatto dell'imbuto (GenioImbuto). Così i lati diventano curvi a S, la parte vicina all'icona è larga quanto
/// lei e il corpo della finestra viene «risucchiato» (riferimento: il genio vero del Mac dell'utente).
/// Solo conti: per i conti coordinate «y in giù» della finestra; Core Animation le riceve convertite in «y in su»
/// (vedi `trasformazione`). Tempi e misure in Tema.Moto.Finestre.
enum CurveGenio {
    /// Le righe della finestra (0 = cima, 1 = fondo, frazione dell'altezza) dove si tagliano le strisce.
    static func tagli(strisce n: Int) -> [CGFloat] {
        let n = max(1, n)
        return (0...n).map { CGFloat($0) / CGFloat(n) }
    }

    /// Le y (coordinate della finestra, in giù) di cima e fondo della finestra deformata al progresso p, il collo
    /// (la cima dell'icona) e l'imbuto. Fase 1: il fondo si stringe e scende fino all'icona (fino a genioFineFondo)
    /// mentre i lati si piegano (fino a genioFinePiega). Fase 2 (da genioInizioCima): la cima scende lungo l'imbuto.
    /// Icona più in alto del fondo della finestra (finestra ingrandita, dock che riappare): il fondo sale.
    static func forma(progresso p: CGFloat, larghezza w: CGFloat, altezza h: CGFloat,
                      bersaglio: CGPoint, lato: CGFloat) -> (cima: CGFloat, fondo: CGFloat, collo: CGFloat, imbuto: GenioImbuto) {
        let m = Tema.Moto.Finestre.self
        let p = GenioImbuto.limita(p)
        let mezzo = lato / 2
        // L'icona sta sotto la cima della finestra: l'imbuto non si rovescia mai
        let ty = max(bersaglio.y, mezzo)
        let collo = ty - mezzo
        let imbuto = GenioImbuto(larghezza: w, centroIcona: bersaglio.x, lato: lato, collo: collo,
                                 piega: GenioImbuto.esce(GenioImbuto.limita(p / m.genioFinePiega)))
        // Fondo: accelera e rallenta arrivando sul fondo dell'icona
        let fondo = GenioImbuto.verso(h, ty + mezzo, GenioImbuto.morbido(GenioImbuto.limita(p / m.genioFineFondo)))
        // Cima: parte piano, scivola lungo l'imbuto e si posa sulla cima dell'icona; mai sotto il fondo
        let c = GenioImbuto.morbido(GenioImbuto.limita((p - m.genioInizioCima) / (1 - m.genioInizioCima)))
        let cima = min(collo * c, max(0, fondo - lato))
        return (cima, fondo, collo, imbuto)
    }

    /// La y (in giù, coordinate della finestra) della riga r (0 = cima, 1 = fondo).
    /// Finché la cima è ferma è uno stiramento lineare fino al fondo. Poi la finestra tiene la sua lunghezza
    /// «virtuale» e scorre giù: le righe oltre il collo (la cima dell'icona) si comprimono dentro l'icona, fra
    /// il collo e il fondo. L'allungamento virtuale cresce con quanto il fondo è già entrato nell'icona
    /// (`lato`), così la funzione è continua anche quando la cima parte prima che il fondo arrivi al collo.
    /// Crescente in r; riga(0) = cima, riga(1) = fondo.
    static func riga(_ r: CGFloat, cima: CGFloat, fondo: CGFloat, collo: CGFloat, lato: CGFloat = 0) -> CGFloat {
        let dentro: CGFloat = lato > 0 ? GenioImbuto.limita((fondo - collo) / lato) : (fondo > collo ? 1 : 0)
        let virtuale = fondo + cima * dentro
        let y = cima + r * (virtuale - cima)
        guard fondo > collo, virtuale - collo > 0.5, y > collo else { return y }
        return collo + (y - collo) * (fondo - collo) / (virtuale - collo)
    }

    /// I quattro angoli (y in giù, coordinate della finestra) della striscia fra le righe r0 e r1. Ordine: in alto
    /// a sinistra, in alto a destra, in basso a destra, in basso a sinistra.
    static func trapezio(progresso p: CGFloat, r0: CGFloat, r1: CGFloat, larghezza w: CGFloat, altezza h: CGFloat,
                         bersaglio: CGPoint, lato: CGFloat) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let f = forma(progresso: p, larghezza: w, altezza: h, bersaglio: bersaglio, lato: lato)
        let y0 = riga(r0, cima: f.cima, fondo: f.fondo, collo: f.collo, lato: lato)
        let y1 = riga(r1, cima: f.cima, fondo: f.fondo, collo: f.collo, lato: lato)
        let alto = f.imbuto.lati(a: y0)
        let basso = f.imbuto.lati(a: y1)
        return (CGPoint(x: alto.sinistra, y: y0), CGPoint(x: alto.destra, y: y0),
                CGPoint(x: basso.destra, y: y1), CGPoint(x: basso.sinistra, y: y1))
    }

    /// L'altezza (pt) dello strato della striscia i: la sua parte della finestra più la sovrapposizione verso il
    /// basso (non l'ultima, che finisce sul bordo).
    static func altezzaStriscia(_ i: Int, di n: Int, altezza h: CGFloat) -> CGFloat {
        let n = max(1, n)
        let parte = h / CGFloat(n)
        return parte + (i < n - 1 ? min(Tema.Moto.Finestre.genioSovrapposizione, parte) : 0)
    }

    /// L'omografia che porta il rettangolo (0, 0, w, h) sul quadrilatero a0 a1 a2 a3 ((0,0) → a0, (w,0) → a1,
    /// (w,h) → a2, (0,h) → a3): quadrato → quadrilatero di Heckbert, preceduta dalla scala del rettangolo sul
    /// quadrato unitario. Core Animation moltiplica il vettore riga (x, y, 0, 1), come ProjectionTransform.
    /// Con il rettangolo stesso dà l'identità.
    static func omografia(larghezza w: CGFloat, altezza h: CGFloat,
                          _ a0: CGPoint, _ a1: CGPoint, _ a2: CGPoint, _ a3: CGPoint) -> CATransform3D {
        let w = max(w, 0.0001)
        let h = max(h, 0.0001)
        let dx1 = a1.x - a2.x
        let dx2 = a3.x - a2.x
        let dx3 = a0.x - a1.x + a2.x - a3.x
        let dy1 = a1.y - a2.y
        let dy2 = a3.y - a2.y
        let dy3 = a0.y - a1.y + a2.y - a3.y
        let den = dx1 * dy2 - dx2 * dy1
        var g: CGFloat = 0
        var k: CGFloat = 0
        if abs(den) > 1e-9 {
            g = (dx3 * dy2 - dx2 * dy3) / den
            k = (dx1 * dy3 - dx3 * dy1) / den
        }
        var t = CATransform3DIdentity
        t.m11 = (a1.x - a0.x + g * a1.x) / w
        t.m12 = (a1.y - a0.y + g * a1.y) / w
        t.m14 = g / w
        t.m21 = (a3.x - a0.x + k * a3.x) / h
        t.m22 = (a3.y - a0.y + k * a3.y) / h
        t.m24 = k / h
        t.m41 = a0.x
        t.m42 = a0.y
        return t
    }

    /// La trasformazione dello strato-striscia i (anchorPoint e position a zero, bounds = (0, 0, w, altezzaStriscia),
    /// geometria non capovolta, y in su) al progresso p. `cornice` (la finestra) e `bersaglio` (il centro
    /// dell'icona) sono in coordinate della shell, y in giù; `altezzaPiano` è l'altezza dello strato che contiene
    /// le strisce (y_su = altezzaPiano − y_giù). L'angolo (0, 0) dello strato è quello in basso a sinistra.
    static func trasformazione(striscia i: Int, di n: Int, progresso p: CGFloat, cornice: CGRect,
                               bersaglio: CGPoint, lato: CGFloat, altezzaPiano: CGFloat) -> CATransform3D {
        let n = max(1, n)
        let w = max(cornice.width, 1)
        let h = max(cornice.height, 1)
        let r0 = CGFloat(i) / CGFloat(n)
        let alta = altezzaStriscia(i, di: n, altezza: h)
        let rFine = r0 + alta / h
        let icona = CGPoint(x: bersaglio.x - cornice.minX, y: bersaglio.y - cornice.minY)
        let q = trapezio(progresso: p, r0: r0, r1: rFine, larghezza: w, altezza: h, bersaglio: icona, lato: lato)
        func su(_ punto: CGPoint) -> CGPoint {
            CGPoint(x: cornice.minX + punto.x, y: altezzaPiano - (cornice.minY + punto.y))
        }
        return omografia(larghezza: w, altezza: alta, su(q.3), su(q.2), su(q.1), su(q.0))
    }

    /// Tutti i fotogrammi chiave: [striscia][k], k = 0…m−1, con t_k = k/(m−1) e p_k = bezier(t_k) (con `inverso`
    /// p_k = 1 − bezier(t_k): il ripristino, dall'icona alla finestra). Il tempo è già «cotto» nei valori:
    /// l'animazione di Core Animation usa un tempo lineare. 40 strisce × ~49 fotogrammi: meno di un millisecondo.
    static func fotogrammi(cornice: CGRect, bersaglio: CGPoint, lato: CGFloat, altezzaPiano: CGFloat,
                           durata: Double, controlli: (Double, Double, Double, Double),
                           strisce n: Int, inverso: Bool = false) -> [[CATransform3D]] {
        let n = max(1, n)
        let m = numeroFotogrammi(durata: durata)
        var valori = Array(repeating: [CATransform3D](), count: n)
        for i in 0..<n { valori[i].reserveCapacity(m) }
        for k in 0..<m {
            let t = Double(k) / Double(m - 1)
            let b = CGFloat(bezier(t, controlli))
            let p = inverso ? 1 - b : b
            for i in 0..<n {
                valori[i].append(trasformazione(striscia: i, di: n, progresso: p, cornice: cornice,
                                                bersaglio: bersaglio, lato: lato, altezzaPiano: altezzaPiano))
            }
        }
        return valori
    }

    /// Quanti fotogrammi chiave per una durata (almeno 2).
    static func numeroFotogrammi(durata: Double) -> Int {
        max(2, Int((max(0, durata) * Tema.Moto.Finestre.genioFotogrammiAlSecondo).rounded(.up)) + 1)
    }

    /// Curva di Bézier cubica del tempo (come cubic-bezier del CSS e CAMediaTimingFunction): risolve x(s) = t con
    /// Newton e, se non converge, con la bisezione; rende y(s).
    static func bezier(_ t: Double, _ c: (Double, Double, Double, Double)) -> Double {
        let t = min(max(t, 0), 1)
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        func x(_ s: Double) -> Double {
            let u = 1 - s
            return 3 * u * u * s * c.0 + 3 * u * s * s * c.2 + s * s * s
        }
        func y(_ s: Double) -> Double {
            let u = 1 - s
            return 3 * u * u * s * c.1 + 3 * u * s * s * c.3 + s * s * s
        }
        func dx(_ s: Double) -> Double {
            let u = 1 - s
            return 3 * u * u * c.0 + 6 * u * s * (c.2 - c.0) + 3 * s * s * (1 - c.2)
        }
        var s = t
        for _ in 0..<8 {
            let e = x(s) - t
            if abs(e) < 1e-7 { return y(s) }
            let d = dx(s)
            if abs(d) < 1e-6 { break }
            s -= e / d
            if s < 0 || s > 1 { break }
        }
        var basso = 0.0
        var alto = 1.0
        s = t
        for _ in 0..<50 {
            let v = x(s)
            if abs(v - t) < 1e-7 { break }
            if v < t { basso = s } else { alto = s }
            s = (basso + alto) / 2
        }
        return y(s)
    }

    /// contentsRect della striscia i (coordinate unitarie y in su, come Core Animation su macOS con un'immagine
    /// dritta): dalla riga r0 alla riga r0 + altezzaStriscia/h, contate dall'alto.
    /// Se sul Mac l'immagine risultasse capovolta (lo controlla MotoreGenio.provaVerso), si corregge qui.
    static func rettangoloContenuto(striscia i: Int, di n: Int, altezza h: CGFloat) -> CGRect {
        let n = max(1, n)
        let h = max(h, 1)
        let r0 = CGFloat(i) / CGFloat(n)
        let rFine = min(1, r0 + altezzaStriscia(i, di: n, altezza: h) / h)
        return CGRect(x: 0, y: 1 - rFine, width: 1, height: rFine - r0)
    }

    /// Dove va il punto (x, y) dello strato con la trasformazione `t` (vettore riga, divisione prospettica);
    /// nil se il fattore prospettico w non è positivo (lo strato si rovescerebbe).
    static func applica(_ t: CATransform3D, _ x: CGFloat, _ y: CGFloat) -> CGPoint? {
        let w = x * t.m14 + y * t.m24 + t.m44
        guard w > 0 else { return nil }
        return CGPoint(x: (x * t.m11 + y * t.m21 + t.m41) / w, y: (x * t.m12 + y * t.m22 + t.m42) / w)
    }
}

/// Prova pura del genio (solo conti, gira anche sul server di build): la chiama `--prova-fluidita`.
/// Restituisce i messaggi di errore (vuoto = tutto bene).
enum ProvaGenio {
    static func esegui() -> [String] {
        var errori: [String] = []
        let m = Tema.Moto.Finestre.self
        let n = m.genioStrisce
        let lato: CGFloat = 50
        let altezzaPiano: CGFloat = 900
        // Finestra normale sopra il dock; ingrandita con l'icona sul bordo; icona lontana a sinistra; a destra
        let casi: [(nome: String, cornice: CGRect, icona: CGPoint)] = [
            ("finestra al centro", CGRect(x: 100, y: 80, width: 800, height: 600), CGPoint(x: 700, y: 860)),
            ("finestra ingrandita", CGRect(x: 0, y: 40, width: 1440, height: 800), CGPoint(x: 300, y: 870)),
            ("icona a sinistra", CGRect(x: 800, y: 60, width: 600, height: 400), CGPoint(x: 150, y: 870)),
            ("icona sotto il fondo", CGRect(x: 20, y: 40, width: 1400, height: 790), CGPoint(x: 1200, y: 830)),
        ]

        // Il tempo: Bézier ai capi e crescente
        for (nome, c) in [("genio", m.controlliGenio), ("ripristino", m.controlliRipristino), ("chiusura", m.controlliChiusura)] {
            if abs(CurveGenio.bezier(0, c)) > 1e-9 || abs(CurveGenio.bezier(1, c) - 1) > 1e-9 {
                errori.append("Genio: la curva del \(nome) non parte da 0 o non arriva a 1")
            }
            var prima = -1.0
            for k in 0...100 {
                let v = CurveGenio.bezier(Double(k) / 100, c)
                if v < prima - 1e-6 { errori.append("Genio: la curva del \(nome) torna indietro a t = \(k)%"); break }
                prima = v
            }
        }
        let tagli = CurveGenio.tagli(strisce: n)
        if tagli.count != n + 1 || tagli.first != 0 || tagli.last != 1 {
            errori.append("Genio: i tagli delle strisce non vanno da 0 a 1 in \(n) parti")
        }

        for caso in casi {
            let c = caso.cornice
            let icona = CGPoint(x: caso.icona.x - c.minX, y: caso.icona.y - c.minY)
            // riga: crescente in r, ai capi cima e fondo
            for k in 0...20 {
                let p = CGFloat(k) / 20
                let f = CurveGenio.forma(progresso: p, larghezza: c.width, altezza: c.height, bersaglio: icona, lato: lato)
                let r0 = CurveGenio.riga(0, cima: f.cima, fondo: f.fondo, collo: f.collo, lato: lato)
                let r1 = CurveGenio.riga(1, cima: f.cima, fondo: f.fondo, collo: f.collo, lato: lato)
                if abs(r0 - f.cima) > 0.01 || abs(r1 - f.fondo) > 0.6 {
                    errori.append("Genio (\(caso.nome)): a p = \(p) le righe non vanno da cima a fondo")
                    break
                }
                var prima = -CGFloat.infinity
                for j in 0...40 {
                    let y = CurveGenio.riga(CGFloat(j) / 40, cima: f.cima, fondo: f.fondo, collo: f.collo, lato: lato)
                    if y < prima - 0.001 { errori.append("Genio (\(caso.nome)): a p = \(p) le righe tornano indietro"); break }
                    prima = y
                }
            }
            let valori = CurveGenio.fotogrammi(cornice: c, bersaglio: caso.icona, lato: lato, altezzaPiano: altezzaPiano,
                                               durata: m.durataGenio, controlli: m.controlliGenio, strisce: n)
            guard valori.count == n, let quanti = valori.first?.count, quanti >= 2 else {
                errori.append("Genio (\(caso.nome)): fotogrammi mancanti")
                continue
            }
            var rovesciata = false
            var filo: CGFloat = 0
            for i in 0..<n {
                let alta = CurveGenio.altezzaStriscia(i, di: n, altezza: c.height)
                let angoli = [(CGFloat(0), CGFloat(0)), (c.width, 0), (c.width, alta), (0, alta)]
                for k in 0..<quanti {
                    for (x, y) in angoli where CurveGenio.applica(valori[i][k], x, y) == nil { rovesciata = true }
                    // Strisce contigue: la riga dove finisce la striscia i è la cima della striscia i+1
                    if i < n - 1 {
                        let alta2 = CurveGenio.altezzaStriscia(i + 1, di: n, altezza: c.height)
                        for x in [CGFloat(0), c.width / 2, c.width] {
                            if let a = CurveGenio.applica(valori[i][k], x, alta - c.height / CGFloat(n)),
                               let b = CurveGenio.applica(valori[i + 1][k], x, alta2) {
                                filo = max(filo, ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot())
                            }
                        }
                    }
                }
                // p = 0: la striscia è esattamente al suo posto (y in su)
                let r0 = CGFloat(i) / CGFloat(n)
                let atteso = [CGPoint(x: c.minX, y: altezzaPiano - c.minY - r0 * c.height - alta),
                              CGPoint(x: c.maxX, y: altezzaPiano - c.minY - r0 * c.height - alta),
                              CGPoint(x: c.maxX, y: altezzaPiano - c.minY - r0 * c.height),
                              CGPoint(x: c.minX, y: altezzaPiano - c.minY - r0 * c.height)]
                for (j, (x, y)) in angoli.enumerated() {
                    guard let q = CurveGenio.applica(valori[i][0], x, y),
                          abs(q.x - atteso[j].x) < 0.01, abs(q.y - atteso[j].y) < 0.01 else {
                        errori.append("Genio (\(caso.nome)): all'inizio la striscia \(i) non è al suo posto")
                        break
                    }
                }
                // p = 1: tutto dentro il quadrato dell'icona
                let mezzo = lato / 2 + 0.5
                let centro = CGPoint(x: caso.icona.x, y: altezzaPiano - max(caso.icona.y, lato / 2))
                for (x, y) in angoli {
                    guard let q = CurveGenio.applica(valori[i][quanti - 1], x, y),
                          abs(q.x - centro.x) <= mezzo, abs(q.y - centro.y) <= mezzo else {
                        errori.append("Genio (\(caso.nome)): alla fine la striscia \(i) non è dentro l'icona")
                        break
                    }
                }
            }
            if rovesciata { errori.append("Genio (\(caso.nome)): una striscia si rovescia (fattore prospettico ≤ 0)") }
            // La sovrapposizione copre lo scarto fra due omografie vicine: oltre 3 pt i conti sono sbagliati
            if filo > 3 {
                errori.append("Genio (\(caso.nome)): tra due strisce c'è uno scarto di \(String(format: "%.2f", Double(filo))) pt")
            }
            // Il ripristino: gli stessi trapezi al contrario, dall'icona alla finestra
            let indietro = CurveGenio.fotogrammi(cornice: c, bersaglio: caso.icona, lato: lato, altezzaPiano: altezzaPiano,
                                                 durata: m.durataRipristino, controlli: m.controlliRipristino,
                                                 strisce: n, inverso: true)
            if let ultimo = indietro.first?.last, let q = CurveGenio.applica(ultimo, 0, CurveGenio.altezzaStriscia(0, di: n, altezza: c.height)),
               abs(q.x - c.minX) > 0.01 || abs(q.y - (altezzaPiano - c.minY)) > 0.01 {
                errori.append("Genio (\(caso.nome)): il ripristino non finisce sulla finestra")
            }
        }
        // Il contenuto delle strisce copre tutta l'immagine, dall'alto in basso
        let rettangoli = (0..<n).map { CurveGenio.rettangoloContenuto(striscia: $0, di: n, altezza: 600) }
        if let primo = rettangoli.first, let ultimo = rettangoli.last,
           abs(primo.maxY - 1) > 1e-6 || abs(ultimo.minY) > 1e-6 {
            errori.append("Genio: le strisce non coprono tutta l'istantanea")
        }
        return errori
    }
}
