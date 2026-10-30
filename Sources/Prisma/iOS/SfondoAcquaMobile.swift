#if os(iOS)
import SwiftUI
import UIKit
import Metal
import QuartzCore

// Lo sfondo d'acqua animato di iPhone e iPad: lo stesso shader (ShaderAcqua, compilato una volta da ProgrammaAcqua),
// la stessa fisica (FisicaAcqua) e la stessa pioggia della scrivania del Mac, in una UIView con CAMetalLayer e
// CADisplayLink. Mai una versione semplificata: sul telefono le gocce sono quelle del Mac (CLAUDE.md).
// Regole del Mac (CLAUDE.md, Sfondo della scrivania):
// - 30 fotogrammi al secondo, 20 con il risparmio energetico (rallenta, non si ferma);
// - il disegno (fisica, uniformi, GPU) è sulla coda propria, fuori dal thread principale: il battito dello schermo
//   sul thread principale sceglie solo il fotogramma e lo accoda;
// - si ferma con l'app in background o la scena inattiva (Centro di controllo, elenco delle app), con «Riduci
//   movimento», con «Sfondo fermo» nelle Impostazioni e sotto la presentazione (`animato` falso); con il dispositivo
//   caldo potrà rallentare a 20 fotogrammi come con il risparmio energetico (`Misure.Acqua.caldoRallenta`, spento);
// - senza Metal, se lo shader non si compila o mancano i buffer resta il fermo-immagine (`rinuncia`): succede anche
//   nel simulatore senza GPU vera del runner.
// Le istantanee iOS restano col fermo-immagine (SfondoAcqua decide). Una sola acqua per scena: RadiceMobile.
// La pioggia è in gocce al secondo, come sul Mac (non per area): sul telefono sembra più fitta. Se un giorno
// andasse diradata, si fa solo qui (intensità × area vista / 1440 × 900), mai in SfondoAcquaFisica.swift.

/// La tela: una UIView il cui layer è il CAMetalLayer, che non riceve tocchi.
final class TelaAcquaMobile: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    // swiftlint:disable:next force_cast
    var strato: CAMetalLayer { layer as! CAMetalLayer }

    /// La misura in punti e in pixel del drawable è cambiata (thread principale).
    var cambioMisura: ((CGSize, CGSize) -> Void)?
    /// La vista è entrata in una finestra o ne è uscita (con la scena della finestra, nil fuori da una finestra).
    var cambioFinestra: ((UIWindowScene?) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        aggiornaRisoluzione()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        aggiornaRisoluzione()
        // La scena si legge qui: prima di entrare in una finestra è nil
        cambioFinestra?(window?.windowScene)
    }

    /// Pixel del drawable: `Misure.Acqua.pixelPerPunto` per punto, come il Mac Retina (l'acqua è morbida, la GPU fa
    /// meno lavoro). iPhone a 3× → metà dei pixel dello schermo; iPad e iPhone a 2× → tre quarti, come il Mac.
    func aggiornaRisoluzione() {
        let scala = window?.screen.scale ?? traitCollection.displayScale
        let lato = bounds.size
        let q = min(1, Misure.Acqua.pixelPerPunto / max(1, scala))
        let pixel = CGSize(width: max(1, (lato.width * scala * q).rounded()), height: max(1, (lato.height * scala * q).rounded()))
        strato.contentsScale = scala * q
        cambioMisura?(lato, pixel)
    }
}

/// La tela in SwiftUI. `rinuncia` arriva (a giro finito) se Metal non può disegnare: resta il fermo-immagine.
struct TelaAcquaMetalMobile: UIViewRepresentable {
    let animato: Bool
    let intensita: Double
    let scuro: Bool
    let rinuncia: () -> Void

    func makeCoordinator() -> RendererAcquaMobile { RendererAcquaMobile() }

    func makeUIView(context: Context) -> TelaAcquaMobile {
        let v = TelaAcquaMobile(frame: .zero)
        context.coordinator.rinuncia = rinuncia
        context.coordinator.configura(v, animato: animato, intensita: intensita, scuro: scuro)
        return v
    }

    func updateUIView(_ v: TelaAcquaMobile, context: Context) {
        context.coordinator.rinuncia = rinuncia
        context.coordinator.imposta(animato: animato, intensita: intensita, scuro: scuro)
    }

    static func dismantleUIView(_ v: TelaAcquaMobile, coordinator: RendererAcquaMobile) {
        coordinator.stacca()
    }
}

/// Il CADisplayLink trattiene il suo bersaglio: questo intermediario lo lascia al renderer senza trattenerlo.
private final class BersaglioBattito: NSObject {
    weak var renderer: RendererAcquaMobile?

    init(_ r: RendererAcquaMobile) {
        renderer = r
    }

    @objc func scatta(_ link: CADisplayLink) {
        renderer?.battito(ora: link.targetTimestamp, periodo: link.duration)
    }
}

/// Il disegno dell'acqua su iPhone e iPad, come RendererAcqua sul Mac:
/// - thread principale: quando muoversi (background, scena inattiva, Riduci movimento, impostazioni) e il ritmo;
/// - CADisplayLink (thread principale, pochissimo lavoro): sceglie il fotogramma e lo accoda;
/// - coda del disegno: fisica, profili, uniformi e GPU, con il tempo vero dello schermo.
/// Fra i thread passa solo `Condiviso`, sotto `serratura` (tenuta per poche istruzioni, mai durante il disegno).
final class RendererAcquaMobile: NSObject {
    private struct Condiviso {
        var inMoto = false
        var intensita: Float = 0
        var scuro = false
        var lato = CGSize.zero
        var pixel = CGSize.zero
        var ripartenza = true
        var motoInCoda = false
        var fermoInCoda = false
        var ultimoBattito: CFTimeInterval = 0
        var istanteMisura: CFTimeInterval = 0
        var intervallo: Double = 1.0 / Double(Misure.Acqua.fotogrammiAlSecondo)
    }

    private let serratura = NSLock()
    private var condiviso = Condiviso()
    private let codaDisegno = DispatchQueue(label: "prisma.acqua.disegno.ios", qos: .userInteractive,
                                            autoreleaseFrequency: .workItem)

    // Solo thread principale
    private weak var vista: TelaAcquaMobile?
    var rinuncia: (() -> Void)?
    private var comparsaAvviata = false
    private var animato = true
    private var scuro = false
    private var inMoto = false
    private var ritmo = Misure.Acqua.fotogrammiAlSecondo
    private var pronta = false
    private var staccato = false
    private var inBackground = false
    /// La scena della finestra è attiva (non coperta dal Centro di controllo, dall'elenco delle app, da un avviso).
    private var scenaAttiva = true
    private weak var scena: UIWindowScene?
    private var link: CADisplayLink?

    // Solo coda del disegno
    private var strato: CAMetalLayer?
    private var pipeline: MTLRenderPipelineState?
    private var comandiGPU: MTLCommandQueue?
    private var fisica: FisicaAcqua?
    private var profili: [MTLBuffer] = []
    private var prossimo = 0
    private let semaforo = DispatchSemaphore(value: Misure.Acqua.fotogrammiInVolo)
    private var uniformi = [Float](repeating: 0, count: ShaderAcqua.Strato.totale)
    private var ultimo: CFTimeInterval = 0
    private var mostrata = false

    override init() {
        super.init()
        let centro = NotificationCenter.default
        centro.addObserver(self, selector: #selector(entraInBackground(_:)),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
        centro.addObserver(self, selector: #selector(tornaInPrimoPiano(_:)),
                           name: UIApplication.willEnterForegroundNotification, object: nil)
        centro.addObserver(self, selector: #selector(statoCambiato(_:)),
                           name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        centro.addObserver(self, selector: #selector(statoCambiato(_:)),
                           name: .NSProcessInfoPowerStateDidChange, object: nil)
        centro.addObserver(self, selector: #selector(statoCambiato(_:)),
                           name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        inBackground = UIApplication.shared.applicationState == .background
    }

    deinit {
        link?.invalidate()
    }

    func configura(_ v: TelaAcquaMobile, animato: Bool, intensita: Double, scuro: Bool) {
        vista = v
        self.animato = animato
        self.scuro = scuro
        let s = v.strato
        s.device = ProgrammaAcqua.condiviso.device
        s.pixelFormat = .bgra8Unorm
        s.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        s.framebufferOnly = true
        s.isOpaque = true
        s.presentsWithTransaction = false
        s.allowsNextDrawableTimeout = true
        s.maximumDrawableCount = Misure.Acqua.drawable
        v.alpha = 0   // compare alla prima immagine disegnata
        serratura.lock()
        condiviso.intensita = Float(max(0, intensita))
        condiviso.scuro = scuro
        serratura.unlock()
        v.cambioMisura = { [weak self] lato, pixel in self?.misura(lato: lato, pixel: pixel) }
        v.cambioFinestra = { [weak self] scena in
            self?.osserva(scena)
            self?.aggiornaMoto()
        }
        v.aggiornaRisoluzione()
        codaDisegno.async { [weak self] in self?.strato = s }
        ProgrammaAcqua.condiviso.richiedi { [weak self] stato in self?.pronto(stato) }
    }

    func imposta(animato: Bool, intensita: Double, scuro: Bool) {
        let cambiaColore = scuro != self.scuro
        self.animato = animato
        self.scuro = scuro
        serratura.lock()
        condiviso.intensita = Float(max(0, intensita))
        condiviso.scuro = scuro
        serratura.unlock()
        aggiornaMoto()
        if cambiaColore && !inMoto { chiediFermo() }
    }

    func stacca() {
        staccato = true
        NotificationCenter.default.removeObserver(self)
        fermaBattito()
        inMoto = false
        serratura.lock()
        condiviso.inMoto = false
        serratura.unlock()
        vista?.cambioFinestra = nil
        vista?.cambioMisura = nil
        codaDisegno.async { [weak self] in self?.strato = nil }
    }

    private func pronto(_ stato: MTLRenderPipelineState?) {
        guard !staccato else { return }
        guard let stato, let device = ProgrammaAcqua.condiviso.device,
              let comandi = device.makeCommandQueue() else {
            avvisaRinuncia()
            return
        }
        let lunghezza = ShaderAcqua.maxImpatti * TabelleAcqua.nr * 2 * MemoryLayout<Float>.stride
        var buffer: [MTLBuffer] = []
        for _ in 0..<Misure.Acqua.fotogrammiInVolo {
            guard let b = device.makeBuffer(length: lunghezza, options: [.storageModeShared, .cpuCacheModeWriteCombined]) else {
                avvisaRinuncia()
                return
            }
            buffer.append(b)
        }
        let nuova = FisicaAcqua()
        let pronti = buffer
        codaDisegno.async { [weak self] in
            guard let self else { return }
            self.pipeline = stato
            self.comandiGPU = comandi
            self.profili = pronti
            self.fisica = nuova
        }
        pronta = true
        aggiornaMoto()
        chiediFermo()
    }

    private func avvisaRinuncia() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.staccato else { return }
            self.rinuncia?()
        }
    }

    // MARK: Quando muoversi (thread principale)

    private func misura(lato: CGSize, pixel: CGSize) {
        serratura.lock()
        let cambiata = condiviso.lato != lato || condiviso.pixel != pixel
        condiviso.lato = lato
        condiviso.pixel = pixel
        if cambiata { condiviso.istanteMisura = CACurrentMediaTime() }
        serratura.unlock()
        if cambiata && !inMoto { chiediFermo() }
    }

    @objc private func entraInBackground(_ nota: Notification) {
        sulMain { [weak self] in
            self?.inBackground = true
            self?.aggiornaMoto()
        }
    }

    @objc private func tornaInPrimoPiano(_ nota: Notification) {
        sulMain { [weak self] in
            self?.inBackground = false
            self?.aggiornaMoto()
        }
    }

    /// La tela è entrata in un'altra finestra: si seguono l'attivazione e la disattivazione della sua scena
    /// (sull'iPad in Split View e Stage Manager la scena resta attiva: l'acqua continua).
    private func osserva(_ nuova: UIWindowScene?) {
        if let nuova, nuova === scena { return }
        let centro = NotificationCenter.default
        if let vecchia = scena {
            centro.removeObserver(self, name: UIScene.willDeactivateNotification, object: vecchia)
            centro.removeObserver(self, name: UIScene.didActivateNotification, object: vecchia)
        }
        scena = nuova
        guard let nuova else {
            scenaAttiva = true
            return
        }
        centro.addObserver(self, selector: #selector(scenaDisattivata(_:)),
                           name: UIScene.willDeactivateNotification, object: nuova)
        centro.addObserver(self, selector: #selector(scenaAttivata(_:)),
                           name: UIScene.didActivateNotification, object: nuova)
        // All'avvio la scena può essere ancora inattiva: l'acqua parte con `didActivate`
        scenaAttiva = nuova.activationState == .foregroundActive
    }

    @objc private func scenaDisattivata(_ nota: Notification) {
        sulMain { [weak self] in
            self?.scenaAttiva = false
            self?.aggiornaMoto()
        }
    }

    @objc private func scenaAttivata(_ nota: Notification) {
        sulMain { [weak self] in
            self?.scenaAttiva = true
            self?.aggiornaMoto()
        }
    }

    @objc private func statoCambiato(_ nota: Notification) {
        // la notifica del risparmio energetico arriva da un thread qualsiasi
        DispatchQueue.main.async { [weak self] in self?.aggiornaMoto() }
    }

    private func sulMain(_ fai: @escaping () -> Void) {
        if Thread.isMainThread { fai() } else { DispatchQueue.main.async(execute: fai) }
    }

    /// L'acqua si muove se richiesto, con la vista in una finestra, l'app in primo piano con la scena attiva e senza
    /// «Riduci movimento». Con il risparmio energetico (o il dispositivo caldo) solo un ritmo più basso. Da ferma il
    /// CAMetalLayer tiene l'ultima immagine.
    func aggiornaMoto() {
        guard !staccato, let v = vista else { return }
        let muovi = animato && pronta && v.window != nil && !inBackground && scenaAttiva
            && !UIAccessibility.isReduceMotionEnabled
        aggiornaRitmo()
        guard muovi != inMoto else { return }
        inMoto = muovi
        serratura.lock()
        condiviso.inMoto = muovi
        if muovi {
            condiviso.ripartenza = true
            condiviso.ultimoBattito = 0
        }
        serratura.unlock()
        if muovi { avviaBattito() } else { fermaBattito() }
    }

    private func aggiornaRitmo() {
        let info = ProcessInfo.processInfo
        let caldo = Misure.Acqua.caldoRallenta && (info.thermalState == .serious || info.thermalState == .critical)
        let nuovo = info.isLowPowerModeEnabled || caldo
            ? Misure.Acqua.fotogrammiAlSecondoBassoConsumo : Misure.Acqua.fotogrammiAlSecondo
        guard nuovo != ritmo else { return }
        ritmo = nuovo
        serratura.lock()
        condiviso.intervallo = 1.0 / Double(nuovo)
        serratura.unlock()
        link?.preferredFrameRateRange = Self.intervallo(nuovo)
    }

    private static func intervallo(_ fps: Int) -> CAFrameRateRange {
        CAFrameRateRange(minimum: Float(fps), maximum: Float(fps), preferred: Float(fps))
    }

    // MARK: Battito

    private func avviaBattito() {
        guard link == nil else { return }
        let l = CADisplayLink(target: BersaglioBattito(self), selector: #selector(BersaglioBattito.scatta(_:)))
        l.preferredFrameRateRange = Self.intervallo(ritmo)
        l.add(to: .main, forMode: .common)
        link = l
    }

    private func fermaBattito() {
        link?.invalidate()
        link = nil
    }

    /// Un battito dello schermo: `ora` è l'istante in cui l'immagine andrà sullo schermo, `periodo` il periodo
    /// dello schermo. Un fotogramma ogni intervallo, mai due in coda; il disegno va sulla coda propria.
    fileprivate func battito(ora: CFTimeInterval, periodo: Double) {
        serratura.lock()
        let intervallo = condiviso.intervallo
        let margine = periodo > 0
            ? min(periodo * Misure.Acqua.tolleranzaBattito, intervallo * 0.5)
            : intervallo * Misure.Acqua.tolleranzaOrologio
        var accoda = false
        if condiviso.inMoto && !condiviso.motoInCoda
            && (condiviso.ultimoBattito == 0 || ora - condiviso.ultimoBattito >= intervallo - margine) {
            condiviso.motoInCoda = true
            condiviso.ultimoBattito = ora
            accoda = true
        }
        serratura.unlock()
        guard accoda else { return }
        codaDisegno.async { [weak self] in self?.disegna(ora: ora, moto: true) }
    }

    private func chiediFermo(dopo ritardo: Double = 0) {
        serratura.lock()
        let gia = condiviso.fermoInCoda
        condiviso.fermoInCoda = true
        serratura.unlock()
        guard !gia else { return }
        let lavoro: () -> Void = { [weak self] in self?.disegna(ora: CACurrentMediaTime(), moto: false) }
        if ritardo > 0 {
            codaDisegno.asyncAfter(deadline: .now() + ritardo, execute: lavoro)
        } else {
            codaDisegno.async(execute: lavoro)
        }
    }

    // MARK: Disegno (coda del disegno)

    private func disegna(ora: CFTimeInterval, moto: Bool) {
        serratura.lock()
        let c = condiviso
        if moto && c.inMoto { condiviso.ripartenza = false }
        if !moto { condiviso.fermoInCoda = false }
        serratura.unlock()
        let riprova = autoreleasepool { fotogramma(c, ora: ora, moto: moto) }
        if moto {
            serratura.lock()
            condiviso.motoInCoda = false
            serratura.unlock()
        } else if riprova {
            chiediFermo(dopo: Misure.Acqua.riprovaFermo)
        }
    }

    /// Come sul Mac: avanza la fisica con il tempo vero, scrive profili e uniformi, lancia lo shader e presenta.
    /// Non aspetta mai la GPU; ridà true se un'immagine ferma va riprovata.
    private func fotogramma(_ c: Condiviso, ora: CFTimeInterval, moto: Bool) -> Bool {
        if moto && c.ripartenza { ultimo = 0 }
        guard let strato, let pipeline, let comandiGPU, let fisica, !profili.isEmpty else { return false }
        if moto && !c.inMoto { return false }
        let lato = c.lato
        let px = c.pixel
        guard lato.width >= 1, lato.height >= 1, px.width >= 1, px.height >= 1 else { return false }
        if !mostrata && ora - c.istanteMisura < Misure.Acqua.attesaMisura { return !moto }
        guard semaforo.wait(timeout: .now()) == .success else { return !moto }

        if strato.drawableSize != px {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            strato.drawableSize = px
            CATransaction.commit()
        }
        let w = Float(lato.width)
        let h = Float(lato.height)
        fisica.misura(larghezza: w, altezza: h)
        if moto {
            if ultimo > 0 {
                let dt = min(max(0, ora - ultimo), Misure.Acqua.passoMassimo)
                if dt > 0 { fisica.passo(Float(dt), intensita: c.intensita) }
            }
            ultimo = ora
        }

        let buffer = profili[prossimo]
        prossimo = (prossimo + 1) % profili.count
        let dati = buffer.contents().bindMemory(to: Float.self, capacity: ShaderAcqua.maxImpatti * TabelleAcqua.nr * 2)
        let scuro = c.scuro
        let tempo = Float(fisica.tempo)
        let dpr = Float(px.width / lato.width)
        uniformi.withUnsafeMutableBufferPointer { u in
            guard let p = u.baseAddress else { return }
            fisica.scrivi(profili: dati, uniformi: p)
            let cam = ShaderAcqua.Strato.camera
            p[cam] = w * 0.5
            p[cam + 1] = h * 0.42
            p[cam + 2] = max(w, h) * 1.15
            p[cam + 3] = tempo
            let cielo = Colori.Acqua.cielo(scuro: scuro)
            RendererAcquaMobile.scrivi(colore: cielo[0], in: p + ShaderAcqua.Strato.cielo1)
            RendererAcquaMobile.scrivi(colore: cielo[1], in: p + ShaderAcqua.Strato.cielo2)
            RendererAcquaMobile.scrivi(colore: cielo[2], in: p + ShaderAcqua.Strato.cielo3)
            let r = ShaderAcqua.Strato.risoluzione
            p[r] = w
            p[r + 1] = h
            p[r + 2] = dpr
            p[r + 3] = scuro ? 1 : 0
        }

        guard let drawable = strato.nextDrawable(), let comandi = comandiGPU.makeCommandBuffer() else {
            semaforo.signal()
            return false
        }
        let passaggio = MTLRenderPassDescriptor()
        passaggio.colorAttachments[0].texture = drawable.texture
        passaggio.colorAttachments[0].loadAction = .dontCare
        passaggio.colorAttachments[0].storeAction = .store
        guard let enc = comandi.makeRenderCommandEncoder(descriptor: passaggio) else {
            semaforo.signal()
            return false
        }
        enc.setRenderPipelineState(pipeline)
        uniformi.withUnsafeBytes { b in
            if let base = b.baseAddress { enc.setFragmentBytes(base, length: b.count, index: 0) }
        }
        enc.setFragmentBuffer(buffer, offset: 0, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        if !mostrata {
            mostrata = true
            // Sul simulatore iOS `addPresentedHandler` del drawable non c'è: basta il completamento del comando
            comandi.addCompletedHandler { [weak self] (_: MTLCommandBuffer) in
                DispatchQueue.main.async { [weak self] in self?.mostra() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Misure.Acqua.riservaComparsa) { [weak self] in self?.mostra() }
        }
        comandi.present(drawable)
        let s = semaforo
        comandi.addCompletedHandler { _ in s.signal() }
        comandi.commit()
        return false
    }

    /// Dissolvenza della prima immagine sopra il fermo-immagine (thread principale).
    private func mostra() {
        guard !staccato, !comparsaAvviata, let v = vista else { return }
        comparsaAvviata = true
        UIView.animate(withDuration: Misure.Acqua.comparsa) { v.alpha = 1 }
    }

    private static func scrivi(colore v: UInt32, in p: UnsafeMutablePointer<Float>) {
        p[0] = Float((v >> 16) & 0xff) / 255
        p[1] = Float((v >> 8) & 0xff) / 255
        p[2] = Float(v & 0xff) / 255
        p[3] = 1
    }
}

extension SfondoAcqua {
    /// Su iPhone e iPad l'acqua si muove come sul Mac (fuori dalle istantanee, dove resta il fermo-immagine).
    static var animabileSuiOS: Bool { !CommandLine.arguments.contains("--istantanee-ios") }
}

extension Misure.Acqua {
    /// Pixel del drawable per punto, come il Mac Retina (2 × quotaRisoluzione 0,75): l'acqua è morbida e il drawable
    /// resta sotto gli 0,8 Mpx anche sull'iPhone più grande. `dpr` per lo shader vale 1,5 ovunque: i fili delle onde
    /// hanno lo spessore del Mac.
    static let pixelPerPunto: CGFloat = 1.5
    /// Proposta da far confermare all'utente (per ora spenta: l'acqua resta quella del Mac, 30 fotogrammi, 20 solo
    /// con il risparmio energetico): con il dispositivo caldo (`thermalState` serio o critico) rallentare a 20
    /// fotogrammi, come con il risparmio energetico. Rallenta, non si ferma.
    static let caldoRallenta = false
}
#endif
