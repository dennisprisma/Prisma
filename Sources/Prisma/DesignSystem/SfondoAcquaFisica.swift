import Foundation
import Accelerate

// Fisica dello sfondo d'acqua, portata dal prototipo approvato (anteprima-sfondo.html).
// Onde capillari-gravitazionali (problema di Cauchy-Poisson): ogni impatto è un profilo radiale
// h'(r) = Σ w(k) J1(k r), ricalcolato a ogni fotogramma solo per gli impatti vivi.
// Scala: 6,7 px per millimetro; rallentatore 55 volte. Tutto in punti.

/// Le tabelle che non cambiano mai: numeri d'onda, pulsazioni, smorzamenti e J1(k r).
/// Calcolate una volta sola (fuori dal thread principale) e condivise; non si liberano.
final class TabelleAcqua {
    static let condivise = TabelleAcqua()

    static let pxm = 6700.0, rall = 55.0, g = 9.81, sig = 7.28e-5, nu = 1.0e-6
    /// Campioni del profilo radiale (1 punto l'uno).
    static let nr = 1024
    /// Passo in k (punti⁻¹): niente echi entro 2400 punti.
    static let dk = 2 * Double.pi / 2400
    static let kMax = 1.05

    let nk: Int
    let k: UnsafeMutablePointer<Float>
    let om: UnsafeMutablePointer<Float>          // pulsazione vista al rallentatore
    let smz: UnsafeMutablePointer<Float>         // smorzamento viscoso per secondo
    let costante: UnsafeMutablePointer<Float>    // filtro · (k / ω) · k² · dk
    let j1t: UnsafeMutablePointer<Float>         // J1(k r) per ogni k (righe) e ogni r (colonne)

    private init() {
        let nr = TabelleAcqua.nr
        let nk = Int((TabelleAcqua.kMax / TabelleAcqua.dk).rounded(.up))
        self.nk = nk
        k = .allocate(capacity: nk)
        om = .allocate(capacity: nk)
        smz = .allocate(capacity: nk)
        costante = .allocate(capacity: nk)
        j1t = .allocate(capacity: nk * nr)
        for i in 0..<nk {
            let kd = (Double(i) + 0.5) * TabelleAcqua.dk
            let kp = kd * TabelleAcqua.pxm
            let omega = TabelleAcqua.pulsazione(kd)
            // niente onde più corte di ~11 punti: meno trame fitte
            let filtro = exp(-pow(kd / 0.56, 6))
            k[i] = Float(kd)
            om[i] = Float(omega)
            smz[i] = Float(2 * TabelleAcqua.nu * kp * kp / TabelleAcqua.rall)
            costante[i] = Float(filtro * (kd / omega) * kd * kd * TabelleAcqua.dk)
            let riga = j1t + i * nr
            for j in 0..<nr { riga[j] = Float(TabelleAcqua.j1(kd * Double(j))) }
        }
    }

    /// Pulsazione ω(k) al rallentatore.
    static func pulsazione(_ kd: Double) -> Double {
        let kp = kd * pxm
        return (g * kp + sig * kp * kp * kp).squareRoot() / rall
    }

    /// Velocità di gruppo, per sapere fin dove è arrivato il treno d'onde.
    static func velocitaGruppo(_ kd: Double) -> Double {
        let e = 1e-4
        return (pulsazione(kd + e) - pulsazione(kd - e)) / (2 * e)
    }

    /// Funzione di Bessel J1 (approssimazione razionale, come nel prototipo).
    static func j1(_ x: Double) -> Double {
        let ax = abs(x)
        if ax < 8 {
            // polinomi in forma di Horner, un passo alla volta (il compilatore ringrazia)
            let y = x * x
            var num: Double = 15704.48260 + y * -30.16036606
            num = -2972611.439 + y * num
            num = 242396853.1 + y * num
            num = -7895059235.0 + y * num
            num = 72362614232.0 + y * num
            var den: Double = 376.9991397 + y
            den = 99447.43394 + y * den
            den = 18583304.74 + y * den
            den = 2300535178.0 + y * den
            den = 144725228442.0 + y * den
            return x * num / den
        }
        let z = 8 / ax
        let xx = ax - 2.356194491
        let y = z * z
        var p1: Double = 0.2457520174e-5 + y * -0.240337019e-6
        p1 = -0.3516396496e-4 + y * p1
        p1 = 0.183105e-2 + y * p1
        p1 = 1 + y * p1
        var p2: Double = -0.88228987e-6 + y * 0.105787412e-6
        p2 = 0.8449199096e-5 + y * p2
        p2 = -0.2002690873e-3 + y * p2
        p2 = 0.04687499995 + y * p2
        let ampiezza = (0.636619772 / ax).squareRoot()
        let r = ampiezza * (cos(xx) * p1 - z * sin(xx) * p2)
        return x < 0 ? -r : r
    }
}

/// Lo stato dell'acqua: gocce che cadono, conche, impatti e i loro profili.
/// Vive sulla coda del disegno di RendererAcqua (mai sul thread principale); nessuna allocazione per fotogramma.
/// `passo` riceve il tempo vero trascorso: l'acqua va sempre alla stessa velocità, anche se un fotogramma salta.
final class FisicaAcqua {
    struct Impatto {
        var x: Float, y: Float, t: Float, a: Float, amp: Float, vf: Float
        var getto: Float, vita: Float, dissolvi: Float
        var rmax: Int
    }

    struct Perla {
        enum Tipo { case cade, tuffo, getto }
        var tipo: Tipo
        var x: Float, y: Float, t: Float, peso: Float, r: Float
    }

    struct Conca {
        var x: Float, y: Float, r: Float, t: Float, seme: Float
    }

    private struct Taratura {
        let amp1: Float
        let vf: Float
    }

    /// Pendenza delle onde all'impatto e profondità della conca (in raggi).
    static let ampOnde: Float = 1.1
    static let profConca: Float = 0.8
    /// Limiti delle liste (le gocce sono poche: il rallentatore le diluisce).
    private static let massimoImpatti = 64
    private static let massimoPerle = 32
    /// I cerchi già nell'acqua alla partenza: x, y (frazioni), età (s), peso.
    private static let partenza: [(Float, Float, Float, Float)] = [
        (0.22, 0.62, 3.4, 0.7), (0.74, 0.30, 1.8, 0.9), (0.50, 0.90, 5.5, 0.6), (0.92, 0.78, 0.9, 0.5),
    ]
    /// Alla partenza la pioggia è già in corso: mezza goccia già «maturata», così la prima nuova goccia
    /// cade dopo pochi secondi (con la pioggia leggera ~3,5 s) e non dopo un'attesa intera da acqua vuota.
    private static let gocciaMaturata: Float = 0.5

    private let tab = TabelleAcqua.condivise
    private let nr = TabelleAcqua.nr
    private let maxi = ShaderAcqua.maxImpatti
    private let maxp = ShaderAcqua.maxPerline
    private let maxc = ShaderAcqua.maxConche

    private var impatti: [Impatto] = []
    private var perle: [Perla] = []
    private var conche: [Conca] = []
    private(set) var tempo: Double = 0
    private var daCreare: Float = 0
    private var larghezza: Float = 0
    private var altezza: Float = 0
    private var avviata = false

    // Appunti di calcolo, allocati una volta
    private let pesi: UnsafeMutablePointer<Float>
    private let inviluppo: UnsafeMutablePointer<Float>
    private let somma: UnsafeMutablePointer<Float>
    private let appunti: UnsafeMutablePointer<Float>
    /// Tarature per raggio della goccia (chiave: raggio × 10).
    private var tarature: [Taratura?] = Array(repeating: nil, count: 200)

    init() {
        let nk = TabelleAcqua.condivise.nk
        pesi = .allocate(capacity: nk)
        inviluppo = .allocate(capacity: nk)
        somma = .allocate(capacity: TabelleAcqua.nr + 4)
        appunti = .allocate(capacity: TabelleAcqua.nr * 2)
        pesi.initialize(repeating: 0, count: nk)
        inviluppo.initialize(repeating: 0, count: nk)
        somma.initialize(repeating: 0, count: TabelleAcqua.nr + 4)
        appunti.initialize(repeating: 0, count: TabelleAcqua.nr * 2)
        impatti.reserveCapacity(FisicaAcqua.massimoImpatti + 1)
        perle.reserveCapacity(FisicaAcqua.massimoPerle + 1)
        conche.reserveCapacity(ShaderAcqua.maxConche + 1)
    }

    deinit {
        pesi.deallocate()
        inviluppo.deallocate()
        somma.deallocate()
        appunti.deallocate()
    }

    /// Misure della superficie in punti; alla prima volta mette qualche cerchio già nell'acqua,
    /// così anche da ferma l'immagine non è vuota.
    /// Finché l'acqua non si è mossa (tempo 0) i cerchi di partenza seguono la misura: se la prima immagine è nata a
    /// una misura provvisoria della finestra, non restano ammucchiati in un angolo.
    func misura(larghezza w: Float, altezza h: Float) {
        let cambiata = w != larghezza || h != altezza
        larghezza = w
        altezza = h
        guard w > 0, h > 0 else { return }
        if !avviata {
            avviata = true
            daCreare = FisicaAcqua.gocciaMaturata
            for q in FisicaAcqua.partenza {
                impatta(x: w * q.0, y: h * q.1, a: 4.5 + q.3 * 2, pendenza: FisicaAcqua.ampOnde, getto: 3 + q.3 * 2.5, vita: 12)
                impatti[impatti.count - 1].t = q.2
            }
            return
        }
        guard cambiata && tempo == 0 else { return }
        for (i, q) in FisicaAcqua.partenza.enumerated() where i < impatti.count {
            impatti[i].x = w * q.0
            impatti[i].y = h * q.1
        }
    }

    /// Fa passare dt secondi con `intensita` gocce al secondo.
    func passo(_ dt: Float, intensita: Float) {
        daCreare += max(0, intensita) * dt
        while daCreare >= 1 {
            daCreare -= 1
            nuovaGoccia()
        }
        avanza(dt)
    }

    // MARK: - Profilo radiale

    /// Profilo radiale di un impatto all'istante t: coppie (pendenza h'(r), laplaciano) in `uscita`.
    /// Ridà il raggio fin dove il profilo è scritto.
    @discardableResult
    private func profilo(_ im: Impatto, t: Float, lontano: Float, uscita: UnsafeMutablePointer<Float>) -> Int {
        let nk = tab.nk
        let a2 = im.a * im.a / 4
        var mx: Float = 0
        for i in 0..<nk {
            let k = tab.k[i]
            let inv = expf(-k * k * a2 - tab.smz[i] * t) * tab.costante[i]
            pesi[i] = inv * sinf(tab.om[i] * t) * im.amp
            inviluppo[i] = inv
            if inv > mx { mx = inv }
        }
        var imin = nk, imax = -1
        let soglia = mx * 2e-3
        for i in 0..<nk where inviluppo[i] > soglia {
            if i < imin { imin = i }
            imax = i
        }
        // solo fin dove è arrivato il fronte e non oltre l'angolo più lontano dello schermo
        let fronte = min(im.vf * t + 5 * im.a + 24, lontano).rounded(.up)
        let rmax = fronte.isFinite ? max(0, Int(min(Float(nr - 2), fronte))) : nr - 2
        let n = rmax + 2
        if imax < imin {
            vDSP_vclr(somma, 1, vDSP_Length(n))
        } else if n * 2 < nr {
            // fronte ancora vicino: si sommano solo le colonne che servono
            vDSP_vclr(somma, 1, vDSP_Length(n))
            for i in imin...imax {
                var w = pesi[i]
                if w == 0 { continue }
                vDSP_vsma(tab.j1t + i * nr, 1, &w, somma, 1, somma, 1, vDSP_Length(n))
            }
        } else {
            // vettore dei pesi × blocco della tabella J1 (righe imin...imax, tutte le colonne)
            vDSP_mmul(pesi + imin, 1, tab.j1t + imin * nr, 1, somma, 1,
                      1, vDSP_Length(nr), vDSP_Length(imax - imin + 1))
        }
        // il getto (Worthington): una cupola stretta al centro, non lineare, aggiunta a mano
        if im.getto > 0 {
            let u = (t - 0.1) / 0.62
            if u > 0 && u < 1 {
                let s = sinf(Float.pi * u)
                let hj = im.getto * s * s
                let bj = im.a * 0.9
                let bj2 = bj * bj
                let fine = min(rmax, Int((bj * 4).rounded(.up)))
                var j = 0
                while j < fine {
                    let fj = Float(j)
                    somma[j] += -2 * fj / bj2 * hj * expf(-fj * fj / bj2)
                    j += 1
                }
            }
        }
        // laplaciano h'' + h'/r, per le caustiche sul fondo
        let dis = im.dissolvi
        for j in 0...rmax {
            let d2: Float = j > 0 ? (somma[j + 1] - somma[j - 1]) * 0.5 : somma[1] * 2
            let lap: Float = j > 0 ? d2 + somma[j] / Float(j) : d2
            uscita[j * 2] = somma[j] * dis
            uscita[j * 2 + 1] = lap * dis
        }
        var j = rmax + 1
        while j < min(nr, rmax + 4) {
            uscita[j * 2] = 0
            uscita[j * 2 + 1] = 0
            j += 1
        }
        return rmax
    }

    /// Ampiezza: si sceglie in modo che la parete del cratere abbia la pendenza voluta.
    private func taratura(_ a: Float) -> Taratura {
        let chiave = Int((a * 10).rounded())
        let valida = chiave >= 0 && chiave < tarature.count
        if valida, let t = tarature[chiave] { return t }
        let prova = Impatto(x: 0, y: 0, t: 0, a: a, amp: 1, vf: 400, getto: 0, vita: 0, dissolvi: 1, rmax: 0)
        var mx: Float = 0
        var t = 0.03
        while t < 0.25 {
            let rm = profilo(prova, t: Float(t), lontano: .greatestFiniteMagnitude, uscita: appunti)
            for j in 0...rm { mx = max(mx, abs(appunti[j * 2])) }
            t += 0.02
        }
        // fronte: velocità di gruppo dove lo spettro si spegne
        let ad = Double(a)
        let kc = min(0.56, (4 * 7 / (ad * ad)).squareRoot())
        let risultato = Taratura(amp1: mx > 0 ? 1 / mx : 0, vf: Float(TabelleAcqua.velocitaGruppo(kc)))
        if valida { tarature[chiave] = risultato }
        return risultato
    }

    // MARK: - Gocce

    private func caso(_ a: Float, _ b: Float) -> Float { a + Float.random(in: 0..<1) * (b - a) }

    private func impatta(x: Float, y: Float, a: Float, pendenza: Float, getto: Float, vita: Float) {
        let tr = taratura(a)
        if impatti.count >= FisicaAcqua.massimoImpatti { impatti.remove(at: 0) }
        impatti.append(Impatto(x: x, y: y, t: 0, a: a, amp: tr.amp1 * pendenza, vf: tr.vf,
                               getto: getto, vita: vita, dissolvi: 1, rmax: 0))
    }

    /// La conca scavata dalla goccia: dura poco (circa 0,25 s), è irregolare e ha il bordo rialzato.
    private func scava(x: Float, y: Float, r: Float) {
        conche.append(Conca(x: x, y: y, r: r, t: 0, seme: Float.random(in: 0..<1) * 6.28))
        if conche.count > maxc { conche.remove(at: 0) }
    }

    private func aggiungi(_ p: Perla) {
        guard perle.count < FisicaAcqua.massimoPerle else { return }
        perle.append(p)
    }

    /// Nuova goccia lontana dagli impatti recenti: niente trame fitte di cerchi incrociati.
    private func nuovaGoccia() {
        let w = larghezza, h = altezza
        var x: Float = 0, y: Float = 0, n = 0
        repeat {
            x = caso(w * 0.04, w * 0.96)
            y = caso(h * 0.06, h * 0.96)
            n += 1
        } while n < 10 && impatti.contains(where: { im in
            let dx = im.x - x, dy = im.y - y
            return im.t < 4 && dx * dx + dy * dy < 260 * 260
        })
        // la goccia cade (vista dall'alto si rimpicciolisce scendendo), buca, risale col getto e la perlina
        let peso = 0.4 + Float.random(in: 0..<1) * 0.6
        aggiungi(Perla(tipo: .cade, x: x, y: y, t: 0, peso: peso, r: 6 + peso * 3))
    }

    private func avanza(_ dt: Float) {
        tempo += Double(dt)
        var i = perle.count - 1
        while i >= 0 {
            perle[i].t += dt
            let p = perle[i]
            if p.tipo == .cade && p.t >= 0.42 {
                // tocca l'acqua: la goccia affonda (resta visibile un attimo), si apre la conca, partono le onde
                perle[i].tipo = .tuffo
                perle[i].t -= 0.42
                impatta(x: p.x, y: p.y, a: 4.5 + p.peso * 2, pendenza: FisicaAcqua.ampOnde, getto: 3 + p.peso * 2.5, vita: 10.5)
                scava(x: p.x, y: p.y, r: p.r * 2.1)
                aggiungi(Perla(tipo: .getto, x: p.x, y: p.y, t: 0, peso: p.peso, r: p.r * 0.5))
            } else if p.tipo == .tuffo && p.t >= 0.07 {
                perle.remove(at: i)
            } else if p.tipo == .getto && p.t >= 1.25 {
                perle.remove(at: i)
                impatta(x: p.x, y: p.y, a: 2.6 + p.peso, pendenza: 0.8, getto: 1.2, vita: 6.5)
            }
            i -= 1
        }
        i = conche.count - 1
        while i >= 0 {
            conche[i].t += dt
            if conche[i].t > 0.32 { conche.remove(at: i) }
            i -= 1
        }
        i = impatti.count - 1
        while i >= 0 {
            impatti[i].t += dt
            let im = impatti[i]
            let f = (im.vita - im.t) / 2.5
            impatti[i].dissolvi = f >= 1 ? 1 : (f <= 0 ? 0 : f * f * (3 - 2 * f))
            if im.t > im.vita || (im.rmax >= nr - 2 && im.t > 4) { impatti.remove(at: i) }
            i -= 1
        }
    }

    // MARK: - Verso la GPU

    /// Scrive i profili degli impatti vivi (una riga di NR coppie ciascuno) e le uniformi
    /// di impatti, perline e conche. Il resto delle uniformi lo scrive la vista.
    func scrivi(profili: UnsafeMutablePointer<Float>, uniformi u: UnsafeMutablePointer<Float>) {
        let w = larghezza, h = altezza
        var n = 0
        var i = 0
        while i < impatti.count && n < maxi {
            let im = impatti[i]
            if im.dissolvi > 0 {
                let dx = max(im.x, w - im.x), dy = max(im.y, h - im.y)
                let lontano = (dx * dx + dy * dy).squareRoot() + 4
                let rm = profilo(im, t: im.t, lontano: lontano, uscita: profili + n * nr * 2)
                impatti[i].rmax = rm
                let o = ShaderAcqua.Strato.impatti + n * 4
                u[o] = im.x
                u[o + 1] = im.y
                u[o + 2] = Float(rm)
                u[o + 3] = Float(n)
                n += 1
            }
            i += 1
        }
        let np = scriviPerle(u + ShaderAcqua.Strato.perline)
        // conche: si aprono in 35 ms, si allargano un poco e si richiudono entro 0,25 s
        var nc = 0
        for c in conche where nc < maxc {
            let t = c.t
            let apre = min(1, t / 0.035)
            let chiude: Float = t < 0.1 ? 1 : max(0, 1 - (t - 0.1) / 0.16)
            let prof = c.r * FisicaAcqua.profConca * apre * apre * (3 - 2 * apre) * chiude * chiude * (3 - 2 * chiude)
            if prof <= 0.01 { continue }
            let o = ShaderAcqua.Strato.conche + nc * 4
            u[o] = c.x
            u[o + 1] = c.y
            u[o + 2] = c.r * (0.75 + 0.35 * min(1, t / 0.08))
            u[o + 3] = prof
            let ob = ShaderAcqua.Strato.concheB + nc * 4
            u[ob] = c.seme
            u[ob + 1] = 0.22 + 0.1 * min(1, t / 0.1)
            u[ob + 2] = 0
            u[ob + 3] = 0
            nc += 1
        }
        let oc = ShaderAcqua.Strato.conti
        u[oc] = Float(n)
        u[oc + 1] = Float(np)
        u[oc + 2] = Float(nc)
        u[oc + 3] = 0
    }

    /// Posizione e raggio apparente di ogni perlina (x, y, quota del centro, raggio).
    private func scriviPerle(_ out: UnsafeMutablePointer<Float>) -> Int {
        var n = 0
        for p in perle where n < maxp {
            let z: Float, alfa: Float
            var r: Float
            switch p.tipo {
            case .cade:
                if p.t < 0 { continue }
                let u = p.t / 0.42
                z = 70 * (1 - u * u) + p.r * 0.6
                r = p.r
                alfa = min(1, p.t / 0.12)
            case .tuffo:
                // affonda nella conca che si apre: scende sotto il pelo e si rimpicciolisce
                let w = p.t / 0.07
                z = p.r * (0.6 - 1.1 * w)
                r = p.r * (1 - 0.55 * w)
                alfa = 1 - w * w
            case .getto:
                // il getto spunta (0,18 s), la perlina si stacca e sale, poi ricade
                if p.t < 0.16 { continue }
                let s = (p.t - 0.16) / (1.25 - 0.16)
                z = 46 * p.peso * 4 * s * (1 - s) + p.r * 0.2
                r = p.r * min(1, 0.45 + s * 4)
                alfa = min(1, (p.t - 0.16) / 0.1)
            }
            r *= 1 + z / 110   // dall'alto: più sale, più sembra vicina
            out[n * 4] = p.x
            out[n * 4 + 1] = p.y
            out[n * 4 + 2] = z
            out[n * 4 + 3] = r * alfa
            n += 1
        }
        return n
    }
}
