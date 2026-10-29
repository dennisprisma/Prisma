import AppKit
import QuartzCore
import SwiftUI

// Il genio vero (riduci e ripristina) e la chiusura, in Core Animation su un'istantanea della finestra.
// Perché: una prospettiva sulla finestra viva non si disegna col vetro di Apple (video del 29 ottobre: la finestra
// tagliata in diagonale per un fotogramma, poi solo l'ombra). Qui la finestra vera resta ferma e nascosta
// (StatoFinestre.nascoste) mentre la sua istantanea, divisa in strisce, scorre nell'imbuto. Tutte le curve si
// calcolano una volta (CurveGenio.fotogrammi) e si consegnano al render server prima dei ridisegni di SwiftUI:
// anche se il thread principale si ferma 200 ms (dock, scrivania, app), il genio scorre lo stesso.
// Solo dal thread principale.

/// Lo strato degli effetti: una vista trasparente sopra la shell (nello ZStack di CorpoShell, prima della
/// presentazione e del benvenuto) che ospita solo le istantanee durante gli effetti. Non riceve mai clic.
/// Layer-hosting (lo strato si assegna prima di `wantsLayer`): AppKit non tocca la geometria dei sottostrati,
/// coordinate di Core Animation native, y in su.
final class StratoEffetti: NSView {
    private var ultimaMisura: CGSize = .zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        let radice = CALayer()
        radice.masksToBounds = false
        layer = radice
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("StratoEffetti non si carica da un archivio")
    }

    override var isFlipped: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        // La shell non si ridimensiona durante un effetto; se succede gli effetti si tolgono (al giro dopo:
        // i completamenti cambiano lo stato, mai durante l'impaginazione)
        guard bounds.size != ultimaMisura else { return }
        let prima = ultimaMisura
        ultimaMisura = bounds.size
        if prima != .zero, MotoreGenio.condiviso.haEffetti {
            DispatchQueue.main.async { MotoreGenio.condiviso.annullaTutto() }
        }
    }
}

/// Lo strato degli effetti in SwiftUI: registra la vista nel motore.
struct StratoEffettiVista: NSViewRepresentable {
    func makeNSView(context: Context) -> StratoEffetti {
        let v = StratoEffetti(frame: .zero)
        MotoreGenio.condiviso.installa(v)
        return v
    }

    func updateNSView(_ nsView: StratoEffetti, context: Context) {}

    static func dismantleNSView(_ nsView: StratoEffetti, coordinator: ()) {
        MotoreGenio.condiviso.disinstalla(nsView)
    }
}

/// Il motore degli effetti delle finestre: un piano (CALayer) per effetto, con le strisce dell'istantanea.
final class MotoreGenio {
    static let condiviso = MotoreGenio()

    enum Verso { case riduci, ripristina }

    private(set) weak var strato: StratoEffetti?
    /// Il motore, se lo strato è in una finestra visibile (nelle istantanee e nelle prove non c'è: tutto come prima).
    var pronto: MotoreGenio? {
        guard let s = strato, s.window?.isVisible == true, s.bounds.height > 0 else { return nil }
        return self
    }
    /// Le istantanee pronte (preparate sui semafori, o tenute per il ripristino delle finestre ridotte).
    var pronte: [AppPrisma: IstantaneaFinestra.Pronta] = [:]
    /// Quando si è preparata l'ultima istantanea (CACurrentMediaTime): niente catture a raffica.
    var ultimaPreparazione: CFTimeInterval = 0
    /// Le istantanee delle finestre ridotte: restano per il ripristino, le altre si liberano.
    private var tenute: [AppPrisma] = []
    private var effetti: [AppPrisma: Effetto] = [:]
    private var giro = 0
    private var osservatore: NSObjectProtocol?

    /// Un effetto in corso: il piano, le strisce e i fotogrammi (per invertirlo dal punto in cui è).
    private final class Effetto {
        let piano: CALayer
        let strisce: [CALayer]
        let ombra: CALayer?
        var verso: Verso?
        var valori: [[CATransform3D]]
        var inizio: CFTimeInterval
        var durata: Double
        var giro: Int
        var fatto: (() -> Void)?

        init(piano: CALayer, strisce: [CALayer], ombra: CALayer?, verso: Verso?, valori: [[CATransform3D]],
             inizio: CFTimeInterval, durata: Double, giro: Int, fatto: @escaping () -> Void) {
            self.piano = piano
            self.strisce = strisce
            self.ombra = ombra
            self.verso = verso
            self.valori = valori
            self.inizio = inizio
            self.durata = durata
            self.giro = giro
            self.fatto = fatto
        }
    }

    var haEffetti: Bool { !effetti.isEmpty }

    func inCorso(_ app: AppPrisma) -> Bool { effetti[app] != nil }

    // MARK: Installazione

    func installa(_ s: StratoEffetti) {
        strato = s
        guard osservatore == nil else { return }
        // Prisma passa in secondo piano: restano solo le istantanee delle finestre ridotte (memoria: 8 GB)
        osservatore = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                                             object: nil, queue: .main) { [weak self] _ in
            self?.liberaNonTenute()
        }
    }

    func disinstalla(_ s: StratoEffetti) {
        guard strato === s else { return }
        annullaTutto()
        strato = nil
    }

    // MARK: Istantanee

    /// Mette da parte un'istantanea (oltre il limite si toglie la più vecchia che non serve a un effetto).
    func tieni(_ app: AppPrisma, _ foto: IstantaneaFinestra.Pronta) {
        pronte[app] = foto
        let limite = Tema.Moto.Finestre.genioIstantaneeTenute + 1
        while pronte.count > limite {
            let liberabili = pronte.filter { effetti[$0.key] == nil && $0.key != app }
            guard let vecchia = liberabili.min(by: { $0.value.quando < $1.value.quando })?.key else { break }
            pronte[vecchia] = nil
            tenute.removeAll { $0 == vecchia }
        }
    }

    /// Alla chiusura (o al ripristino finito): l'istantanea non serve più.
    func dimentica(_ app: AppPrisma) {
        pronte[app] = nil
        tenute.removeAll { $0 == app }
    }

    private func liberaNonTenute() {
        pronte = pronte.filter { tenute.contains($0.key) || effetti[$0.key] != nil }
        IstantaneaFinestra.libera()
    }

    // MARK: Genio

    /// Avvia il genio. `cornice` e `icona` in coordinate della shell (y in giù). Il completamento arriva sul
    /// thread principale una volta sola (anche con `annullaTutto`); con `inverti` lo sostituisce quello nuovo.
    func genio(_ app: AppPrisma, _ verso: Verso, istantanea: IstantaneaFinestra.Pronta, cornice: CGRect,
               icona: CGPoint, lato: CGFloat, durata: Double, ombra: OmbraPrecalcolata.Pronta?,
               fatto: @escaping () -> Void) {
        guard let strato, let radice = strato.layer else {
            fatto()
            return
        }
        annulla(app)
        let m = Tema.Moto.Finestre.self
        let n = m.genioStrisce
        let altezzaPiano = strato.bounds.height
        let valori = CurveGenio.fotogrammi(cornice: cornice, bersaglio: icona, lato: lato, altezzaPiano: altezzaPiano,
                                           durata: durata,
                                           controlli: verso == .riduci ? m.controlliGenio : m.controlliRipristino,
                                           strisce: n, inverso: verso == .ripristina)
        let scala = strato.window?.backingScaleFactor ?? 2
        let g = nuovoGiro()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Prima delle animazioni: vale solo per quelle aggiunte dopo
        CATransaction.setCompletionBlock { [weak self] in self?.finito(app, giro: g) }
        let piano = CALayer()
        piano.frame = strato.bounds
        piano.masksToBounds = false
        // I conti sono in y in su: se AppKit ha capovolto la geometria sopra lo strato, il piano la raddrizza
        piano.isGeometryFlipped = radice.contentsAreFlipped()
        let strisceOmbra = ombra.flatMap { stratoOmbra($0, cornice: cornice, altezzaPiano: altezzaPiano, scala: scala) }
        if let s = strisceOmbra { piano.addSublayer(s) }
        var strisce: [CALayer] = []
        strisce.reserveCapacity(n)
        for i in 0..<n {
            let ultimo = valori[i].last ?? CATransform3DIdentity
            let s = MotoreGenio.striscia(i, di: n, immagine: istantanea.immagine, scala: istantanea.scala,
                                         cornice: cornice, trasformazione: ultimo)
            s.add(MotoreGenio.animazione(valori[i], durata: durata), forKey: "genio")
            piano.addSublayer(s)
            strisce.append(s)
        }
        // L'insieme svanisce dentro l'icona (e ricompare uscendone)
        let d = Double(m.genioInizioDissolvenza)
        if verso == .riduci {
            piano.opacity = 0
            piano.add(MotoreGenio.opacita([1, 1, 0], tempi: [0, d, 1], durata: durata), forKey: "opacita")
        } else {
            piano.opacity = 1
            piano.add(MotoreGenio.opacita([0, 1, 1], tempi: [0, 1 - d, 1], durata: durata), forKey: "opacita")
        }
        // L'ombra della finestra va via subito (e torna alla fine del ripristino)
        if let o = strisceOmbra {
            let q = min(1, m.genioDurataOmbra / max(durata, 0.01))
            if verso == .riduci {
                o.opacity = 0
                o.add(MotoreGenio.opacita([1, 0, 0], tempi: [0, q, 1], durata: durata), forKey: "opacita")
            } else {
                o.opacity = 1
                o.add(MotoreGenio.opacita([0, 0, 1], tempi: [0, 1 - q, 1], durata: durata), forKey: "opacita")
            }
        }
        radice.addSublayer(piano)
        effetti[app] = Effetto(piano: piano, strisce: strisce, ombra: strisceOmbra, verso: verso, valori: valori,
                               inizio: CACurrentMediaTime(), durata: durata, giro: g, fatto: fatto)
        if verso == .riduci {
            if !tenute.contains(app) { tenute.append(app) }
        } else {
            tenute.removeAll { $0 == app }
        }
        CATransaction.commit()
        // Al render server PRIMA dei ridisegni di SwiftUI
        CATransaction.flush()
        sicurezza(app, giro: g, dopo: durata)
    }

    /// Inverte un genio in corso dal punto in cui è (clic sull'icona a metà riduzione, ⌘M a metà ripristino).
    /// Il completamento vecchio non arriva più: arriva `fatto`. false se non c'è un genio in corso per l'app.
    func inverti(_ app: AppPrisma, durata: Double, fatto: @escaping () -> Void) -> Bool {
        guard let e = effetti[app], let verso = e.verso, let quanti = e.valori.first?.count, quanti >= 2 else { return false }
        let m = Tema.Moto.Finestre.self
        let trascorso = CACurrentMediaTime() - e.inizio
        let frazione = min(1, max(0, trascorso / max(e.durata, 0.001)))
        let k = max(1, min(quanti - 1, Int((frazione * Double(quanti - 1)).rounded())))
        let nuovo: Verso = verso == .riduci ? .ripristina : .riduci
        let d = max(0.02, durata * Double(k) / Double(quanti - 1))
        let valori = e.valori.map { Array($0[0...k].reversed()) }
        let g = nuovoGiro()
        let opacitaPiano = e.piano.presentation()?.opacity ?? e.piano.opacity
        let opacitaOmbra = e.ombra.map { $0.presentation()?.opacity ?? $0.opacity } ?? 0

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in self?.finito(app, giro: g) }
        for (i, s) in e.strisce.enumerated() where i < valori.count {
            s.removeAnimation(forKey: "genio")
            s.transform = valori[i].last ?? CATransform3DIdentity
            s.add(MotoreGenio.animazione(valori[i], durata: d), forKey: "genio")
        }
        let o = Double(opacitaPiano)
        let dissolvenza = Double(m.genioInizioDissolvenza)
        e.piano.removeAnimation(forKey: "opacita")
        if nuovo == .riduci {
            e.piano.opacity = 0
            e.piano.add(MotoreGenio.opacita([o, o, 0], tempi: [0, dissolvenza, 1], durata: d), forKey: "opacita")
        } else {
            e.piano.opacity = 1
            e.piano.add(MotoreGenio.opacita([o, 1, 1], tempi: [0, 1 - dissolvenza, 1], durata: d), forKey: "opacita")
        }
        if let ombra = e.ombra {
            let q = min(1, m.genioDurataOmbra / d)
            let oo = Double(opacitaOmbra)
            ombra.removeAnimation(forKey: "opacita")
            if nuovo == .riduci {
                ombra.opacity = 0
                ombra.add(MotoreGenio.opacita([oo, 0, 0], tempi: [0, q, 1], durata: d), forKey: "opacita")
            } else {
                ombra.opacity = 1
                ombra.add(MotoreGenio.opacita([oo, oo, 1], tempi: [0, 1 - q, 1], durata: d), forKey: "opacita")
            }
        }
        e.verso = nuovo
        e.valori = valori
        e.inizio = CACurrentMediaTime()
        e.durata = d
        e.giro = g
        e.fatto = fatto
        if nuovo == .riduci {
            if !tenute.contains(app) { tenute.append(app) }
        } else {
            tenute.removeAll { $0 == app }
        }
        CATransaction.commit()
        CATransaction.flush()
        sicurezza(app, giro: g, dopo: d)
        return true
    }

    // MARK: Chiusura

    /// Chiusura: l'istantanea svanisce con un lieve rimpicciolimento attorno al centro (un'unica bitmap: niente
    /// fantasma del vetro), in durataChiusura con la curva controlliChiusura.
    func dissolvi(_ app: AppPrisma, istantanea: IstantaneaFinestra.Pronta, cornice: CGRect, fatto: @escaping () -> Void) {
        guard let strato, let radice = strato.layer else {
            fatto()
            return
        }
        annulla(app)
        let m = Tema.Moto.Finestre.self
        let altezzaPiano = strato.bounds.height
        let g = nuovoGiro()
        let c = m.controlliChiusura

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in self?.finito(app, giro: g) }
        let piano = CALayer()
        piano.frame = strato.bounds
        piano.masksToBounds = false
        // I conti sono in y in su: se AppKit ha capovolto la geometria sopra lo strato, il piano la raddrizza
        piano.isGeometryFlipped = radice.contentsAreFlipped()
        let s = CALayer()
        s.contents = istantanea.immagine
        s.contentsScale = istantanea.scala
        s.contentsGravity = .resize
        s.bounds = CGRect(origin: .zero, size: cornice.size)
        s.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        s.position = CGPoint(x: cornice.midX, y: altezzaPiano - cornice.midY)
        s.opacity = 0
        s.transform = CATransform3DMakeScale(m.scalaChiusura, m.scalaChiusura, 1)
        let opacita = CABasicAnimation(keyPath: "opacity")
        opacita.fromValue = 1
        opacita.toValue = 0
        let scala = CABasicAnimation(keyPath: "transform.scale")
        scala.fromValue = 1
        scala.toValue = m.scalaChiusura
        let gruppo = CAAnimationGroup()
        gruppo.animations = [opacita, scala]
        gruppo.duration = m.durataChiusura
        gruppo.timingFunction = CAMediaTimingFunction(controlPoints: Float(c.0), Float(c.1), Float(c.2), Float(c.3))
        gruppo.fillMode = .both
        gruppo.isRemovedOnCompletion = false
        s.add(gruppo, forKey: "chiusura")
        piano.addSublayer(s)
        radice.addSublayer(piano)
        effetti[app] = Effetto(piano: piano, strisce: [s], ombra: nil, verso: nil, valori: [],
                               inizio: CACurrentMediaTime(), durata: m.durataChiusura, giro: g, fatto: fatto)
        CATransaction.commit()
        CATransaction.flush()
        sicurezza(app, giro: g, dopo: m.durataChiusura)
    }

    // MARK: Fine e annullamento

    /// Toglie di colpo l'effetto dell'app (se c'è) e ne chiama il completamento.
    func annulla(_ app: AppPrisma) {
        guard let e = effetti.removeValue(forKey: app) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        e.piano.removeFromSuperlayer()
        CATransaction.commit()
        let fatto = e.fatto
        e.fatto = nil
        fatto?()
    }

    /// Blocco, presentazione, stop del Mac: toglie tutto di colpo e chiama i completamenti.
    func annullaTutto() {
        for app in Array(effetti.keys) { annulla(app) }
    }

    private func nuovoGiro() -> Int {
        giro &+= 1
        return giro
    }

    /// Se il completamento di Core Animation non arrivasse, l'effetto finisce lo stesso.
    private func sicurezza(_ app: AppPrisma, giro g: Int, dopo durata: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + durata + 0.3) { [weak self] in self?.finito(app, giro: g) }
    }

    /// L'effetto è finito: prima il completamento (la finestra vera torna o resta nascosta), poi il piano si toglie
    /// dopo genioRitardoRimozione, così la finestra vera già disegnata sta sotto l'istantanea (mai un fotogramma vuoto).
    private func finito(_ app: AppPrisma, giro g: Int) {
        guard let e = effetti[app], e.giro == g else { return }
        effetti[app] = nil
        if e.verso == .ripristina { dimentica(app) }
        let fatto = e.fatto
        e.fatto = nil
        fatto?()
        let piano = e.piano
        DispatchQueue.main.asyncAfter(deadline: .now() + Tema.Moto.Finestre.genioRitardoRimozione) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            piano.removeFromSuperlayer()
            CATransaction.commit()
        }
    }

    // MARK: Strati

    /// Uno strato-striscia dell'istantanea: la stessa CGImage per tutte (una texture), ognuna con il suo pezzo.
    static func striscia(_ i: Int, di n: Int, immagine: CGImage, scala: CGFloat, cornice: CGRect,
                         trasformazione t: CATransform3D) -> CALayer {
        let s = CALayer()
        s.contents = immagine
        s.contentsRect = CurveGenio.rettangoloContenuto(striscia: i, di: n, altezza: cornice.height)
        s.contentsGravity = .resize
        s.contentsScale = scala
        // Vicino all'icona la striscia è molto rimpicciolita
        s.minificationFilter = .trilinear
        s.magnificationFilter = .linear
        s.anchorPoint = .zero
        s.position = .zero
        s.bounds = CGRect(x: 0, y: 0, width: cornice.width,
                          height: CurveGenio.altezzaStriscia(i, di: n, altezza: cornice.height))
        s.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge]
        s.allowsEdgeAntialiasing = true
        s.isDoubleSided = true
        s.transform = t
        return s
    }

    /// I fotogrammi chiave di una striscia: tempo lineare (la curva è già nei valori), fermi alla fine.
    private static func animazione(_ valori: [CATransform3D], durata: Double) -> CAKeyframeAnimation {
        let a = CAKeyframeAnimation(keyPath: "transform")
        a.values = valori.map { NSValue(caTransform3D: $0) }
        a.calculationMode = .linear
        a.timingFunction = CAMediaTimingFunction(name: .linear)
        a.duration = durata
        a.fillMode = .both
        a.isRemovedOnCompletion = false
        return a
    }

    private static func opacita(_ valori: [Double], tempi: [Double], durata: Double) -> CAKeyframeAnimation {
        let a = CAKeyframeAnimation(keyPath: "opacity")
        a.values = valori.map { NSNumber(value: Float($0)) }
        a.keyTimes = tempi.map { NSNumber(value: min(1, max(0, $0))) }
        a.calculationMode = .linear
        a.duration = durata
        a.fillMode = .both
        a.isRemovedOnCompletion = false
        return a
    }

    /// L'ombra della finestra: la bitmap a 9 fette di OmbraPrecalcolata, stirata attorno alla cornice.
    private func stratoOmbra(_ ombra: OmbraPrecalcolata.Pronta, cornice: CGRect, altezzaPiano: CGFloat, scala: CGFloat) -> CALayer? {
        let misura = ombra.immagine.size
        guard misura.width > 0, misura.height > 0,
              let cg = ombra.immagine.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let o = CALayer()
        o.contents = cg
        o.contentsScale = CGFloat(cg.width) / misura.width
        o.contentsGravity = .resize
        let b = ombra.bordo
        o.contentsCenter = CGRect(x: b / misura.width, y: b / misura.height,
                                  width: max(0, 1 - 2 * b / misura.width), height: max(0, 1 - 2 * b / misura.height))
        let r = ombra.margine
        o.frame = CGRect(x: cornice.minX - r, y: altezzaPiano - cornice.maxY - r,
                         width: cornice.width + 2 * r, height: cornice.height + 2 * r)
        return o
    }

    // MARK: Prova

    /// Il verso dell'immagine nelle strisce (gira sul server di build, chiamata da --prova-fluidita): un piano a
    /// p = 0 con un'immagine metà rossa in alto e metà blu in basso, disegnato con render(in:) (a p = 0 le
    /// trasformazioni sono affini); in alto deve venire rosso. nil = tutto bene, altrimenti il messaggio.
    static func provaVerso() -> String? {
        let lato = 100
        guard let spazio = CGColorSpace(name: CGColorSpace.sRGB),
              let sorgente = CGContext(data: nil, width: lato, height: lato, bitsPerComponent: 8, bytesPerRow: 0,
                                       space: spazio, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                           | CGBitmapInfo.byteOrder32Big.rawValue)
        else { return "Genio: contesto di prova non creato" }
        // CoreGraphics ha la y in su: la metà alta è da y = 50 in su
        sorgente.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        sorgente.fill(CGRect(x: 0, y: 50, width: 100, height: 50))
        sorgente.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        sorgente.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
        guard let immagine = sorgente.makeImage() else { return "Genio: immagine di prova non creata" }

        let cornice = CGRect(x: 0, y: 0, width: 100, height: 100)
        let n = Tema.Moto.Finestre.genioStrisce
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let piano = CALayer()
        piano.frame = cornice
        for i in 0..<n {
            let t = CurveGenio.trasformazione(striscia: i, di: n, progresso: 0, cornice: cornice,
                                              bersaglio: CGPoint(x: 50, y: 400), lato: 50, altezzaPiano: 100)
            piano.addSublayer(striscia(i, di: n, immagine: immagine, scala: 1, cornice: cornice, trasformazione: t))
        }
        CATransaction.commit()
        guard let destinazione = CGContext(data: nil, width: lato, height: lato, bitsPerComponent: 8, bytesPerRow: 0,
                                           space: spazio, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                               | CGBitmapInfo.byteOrder32Big.rawValue)
        else { return "Genio: contesto di prova non creato" }
        piano.render(in: destinazione)
        guard let dati = destinazione.data?.assumingMemoryBound(to: UInt8.self) else { return "Genio: pixel di prova illeggibili" }
        let riga = destinazione.bytesPerRow
        // Nella memoria del contesto la prima riga è quella in alto
        func colore(_ y: Int) -> (r: UInt8, b: UInt8) {
            let i = y * riga + 50 * 4
            return (dati[i], dati[i + 2])
        }
        let alto = colore(10)
        let basso = colore(90)
        if alto.r > 200, alto.b < 60, basso.b > 200, basso.r < 60 { return nil }
        if alto.b > 200, basso.r > 200 {
            return "Genio: l'istantanea nelle strisce esce capovolta (correggere CurveGenio.rettangoloContenuto)"
        }
        return "Genio: le strisce di prova non si disegnano (in alto r=\(alto.r) b=\(alto.b), in basso r=\(basso.r) b=\(basso.b))"
    }
}
