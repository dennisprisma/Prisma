import SwiftUI
import AppKit
import Metal
import MetalKit
import QuartzCore

// Lo sfondo della scrivania: acqua vista dall'alto con gocce al rallentatore (prototipo approvato
// anteprima-sfondo.html). Metal disegna l'acqua; sotto c'è sempre il fermo-immagine in SwiftUI,
// che resta da solo nelle istantanee, senza Metal o se lo shader non si compila.

// MARK: - Token

extension Colori {
    /// I colori «Acqua» del tema Liquid Glass usati dallo sfondo animato e dal fermo-immagine.
    enum Acqua {
        /// --cielo-1/2/3 del prototipo: il gradiente a 160° del fondo.
        static let cieloChiaro: [UInt32] = [0xF3F5F6, 0xDDE4E8, 0xB7C5CD]
        static let cieloScuro: [UInt32] = [0x123648, 0x0E2533, 0x081A25]

        /// Fermo-immagine: la luce dello studio riflessa in alto a sinistra.
        static let lampadaChiaro = Color.white.opacity(0.55)
        static let lampadaScuro = Color(.sRGB, red: 0.45, green: 0.62, blue: 0.80, opacity: 0.5)
        /// Fermo-immagine: il filo chiaro e l'ombra dei cerchi d'acqua.
        static let anelloLuceChiaro = Color.white.opacity(0.9)
        static let anelloOmbraChiaro = Color(.sRGB, red: 0.06, green: 0.14, blue: 0.20, opacity: 0.2)
        static let anelloLuceScuro = Color.white.opacity(0.32)
        static let anelloOmbraScuro = Color.black.opacity(0.42)

        static func cielo(scuro: Bool) -> [UInt32] { scuro ? cieloScuro : cieloChiaro }

        static func colore(_ v: UInt32) -> Color {
            Color(.sRGB, red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255,
                  blue: Double(v & 0xff) / 255, opacity: 1)
        }
    }
}

/// Un cerchio d'acqua del fermo-immagine: centro in frazioni dello schermo, raggio in frazioni
/// del lato lungo, forza 0…1.
struct AnelloAcqua {
    let x: CGFloat
    let y: CGFloat
    let raggio: CGFloat
    let forza: Double
}

extension Misure {
    enum Acqua {
        /// È un rallentatore: 30 fotogrammi al secondo bastano e risparmiano energia.
        static let fotogrammiAlSecondo = 30
        /// Fotogrammi preparati in anticipo per la GPU.
        static let fotogrammiInVolo = 3
        /// Passo di tempo massimo (s): dopo una pausa si riparte senza scatti.
        static let passoMassimo: Double = 0.05
        /// Dissolvenza della prima immagine disegnata sopra il fermo-immagine (s).
        static let comparsa: Double = 0.4

        /// Direzione del gradiente CSS a 160° (sin, −cos) e posizione del tono di mezzo.
        static let direzioneGradiente = CGVector(dx: 0.342, dy: 0.940)
        static let tappaMezzo: CGFloat = 0.55
        /// La luce dello studio: centro in frazioni dello schermo, semiassi in altezze dello schermo
        /// (dove la sfumatura si è quasi spenta).
        static let lampadaCentro = CGPoint(x: 0.24, y: 0.10)
        static let lampadaSemiassi = CGSize(width: 0.42 * 1.8, height: 0.22 * 1.8)
        /// Profilo della sfumatura della luce (posizione, quota di colore).
        static let lampadaTappe: [(CGFloat, Double)] = [(0, 1), (0.28, 0.67), (0.56, 0.2), (0.78, 0.04), (1, 0)]

        /// Fermo-immagine: spessore dei cerchi e scarto tra luce (in alto a sinistra) e ombra.
        static let spessoreAnello: CGFloat = 1.6
        static let scartoAnello: CGFloat = 0.8
        /// I cerchi del fermo-immagine: gli stessi impatti con cui parte l'acqua animata.
        static let anelli: [AnelloAcqua] = {
            let centri: [(CGFloat, CGFloat, CGFloat)] = [
                (0.22, 0.62, 0.25), (0.74, 0.30, 0.15), (0.50, 0.90, 0.38), (0.92, 0.78, 0.09), (0.60, 0.46, 0.035),
            ]
            let quote: [(CGFloat, Double)] = [(1.0, 0.35), (0.84, 0.7), (0.68, 1.0), (0.52, 0.75), (0.36, 0.4)]
            var lista: [AnelloAcqua] = []
            for c in centri {
                for q in quote { lista.append(AnelloAcqua(x: c.0, y: c.1, raggio: c.2 * q.0, forza: q.1)) }
            }
            return lista
        }()
    }
}

// MARK: - Viste pubbliche

/// Lo sfondo d'acqua animato della scrivania.
/// `intensita` = gocce al secondo (`pioggiaLeggera`, `pioggiaMedia`, `pioggiaForte`).
/// Si ferma da solo con la finestra nascosta, a basso consumo e con «Riduci movimento».
struct SfondoAcqua: View {
    static let pioggiaLeggera = 0.14
    static let pioggiaMedia = 0.3
    static let pioggiaForte = 0.55

    let animato: Bool
    let intensita: Double
    let scuro: Bool
    @Environment(\.modoIstantanea) private var modoIstantanea

    init(animato: Bool, intensita: Double, scuro: Bool) {
        self.animato = animato
        self.intensita = intensita
        self.scuro = scuro
    }

    var body: some View {
        ZStack {
            // sotto c'è sempre il fermo-immagine: la tela Metal compare sopra alla prima immagine
            SfondoAcquaFermo(scuro: scuro)
            if !modoIstantanea && ProgrammaAcqua.condiviso.device != nil {
                TelaAcquaMetal(animato: animato, intensita: intensita, scuro: scuro)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Fermo-immagine dello sfondo d'acqua, tutto in SwiftUI (niente Metal, niente Canvas):
/// il gradiente del tema, la luce dello studio e qualche cerchio d'acqua in rilievo.
/// Va bene per le istantanee PNG e come ripiego.
struct SfondoAcquaFermo: View {
    let scuro: Bool

    init(scuro: Bool) {
        self.scuro = scuro
    }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            ZStack(alignment: .topLeading) {
                gradiente(w: w, h: h)
                lampada(w: w, h: h)
                ForEach(Misure.Acqua.anelli.indices, id: \.self) { i in
                    anello(Misure.Acqua.anelli[i], w: w, h: h)
                }
            }
            .frame(width: w, height: h)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    /// Come il CSS linear-gradient(160deg): la linea passa per il centro ed è lunga |w·sin| + |h·cos|.
    private func gradiente(w: CGFloat, h: CGFloat) -> some View {
        let d = Misure.Acqua.direzioneGradiente
        let mezza = (abs(w * d.dx) + abs(h * d.dy)) / 2
        let inizio = UnitPoint(x: (w / 2 - d.dx * mezza) / w, y: (h / 2 - d.dy * mezza) / h)
        let fine = UnitPoint(x: (w / 2 + d.dx * mezza) / w, y: (h / 2 + d.dy * mezza) / h)
        let c = Colori.Acqua.cielo(scuro: scuro)
        return LinearGradient(stops: [
            .init(color: Colori.Acqua.colore(c[0]), location: 0),
            .init(color: Colori.Acqua.colore(c[1]), location: Misure.Acqua.tappaMezzo),
            .init(color: Colori.Acqua.colore(c[2]), location: 1),
        ], startPoint: inizio, endPoint: fine)
    }

    /// La grande sorgente morbida dello studio, riflessa in alto a sinistra.
    private func lampada(w: CGFloat, h: CGFloat) -> some View {
        let luce = scuro ? Colori.Acqua.lampadaScuro : Colori.Acqua.lampadaChiaro
        let tappe = Misure.Acqua.lampadaTappe.map { Gradient.Stop(color: luce.opacity($0.1), location: $0.0) }
        let semiassi = Misure.Acqua.lampadaSemiassi
        return EllipticalGradient(stops: tappe, center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            .frame(width: 2 * semiassi.width * h, height: 2 * semiassi.height * h)
            .position(x: Misure.Acqua.lampadaCentro.x * w, y: Misure.Acqua.lampadaCentro.y * h)
    }

    /// Un cerchio d'acqua in rilievo: filo chiaro verso la luce, ombra dall'altra parte.
    private func anello(_ a: AnelloAcqua, w: CGFloat, h: CGFloat) -> some View {
        let r = a.raggio * max(w, h)
        let s = Misure.Acqua.spessoreAnello
        let d = Misure.Acqua.scartoAnello
        let luce = scuro ? Colori.Acqua.anelloLuceScuro : Colori.Acqua.anelloLuceChiaro
        let ombra = scuro ? Colori.Acqua.anelloOmbraScuro : Colori.Acqua.anelloOmbraChiaro
        return ZStack {
            Circle()
                .stroke(LinearGradient(colors: [ombra.opacity(0.2), ombra], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: s)
                .offset(x: d, y: d)
            Circle()
                .stroke(LinearGradient(colors: [luce, luce.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: s)
                .offset(x: -d, y: -d)
        }
        .frame(width: 2 * r, height: 2 * r)
        .opacity(a.forza)
        .position(x: a.x * w, y: a.y * h)
    }
}

// MARK: - Programma Metal condiviso

/// Il programma Metal dell'acqua: compilato una volta sola, fuori dal thread principale,
/// insieme alla tabella J1. Se manca Metal o la compilazione fallisce resta il fermo-immagine.
final class ProgrammaAcqua {
    static let condiviso = ProgrammaAcqua()

    let device: MTLDevice?
    private var pipeline: MTLRenderPipelineState?
    private var finito = false
    private var avviato = false
    private var inAttesa: [(MTLRenderPipelineState?) -> Void] = []

    private init() {
        device = MTLCreateSystemDefaultDevice()
    }

    /// Chiede il programma dal thread principale; la risposta arriva sul thread principale.
    func richiedi(_ fatto: @escaping (MTLRenderPipelineState?) -> Void) {
        guard let device else {
            fatto(nil)
            return
        }
        if finito {
            fatto(pipeline)
            return
        }
        inAttesa.append(fatto)
        if avviato { return }
        avviato = true
        DispatchQueue.global(qos: .userInitiated).async {
            _ = TabelleAcqua.condivise
            let stato = ProgrammaAcqua.compila(device)
            DispatchQueue.main.async { ProgrammaAcqua.condiviso.consegna(stato) }
        }
    }

    private func consegna(_ stato: MTLRenderPipelineState?) {
        pipeline = stato
        finito = true
        let lista = inAttesa
        inAttesa = []
        for f in lista { f(stato) }
    }

    private static func compila(_ device: MTLDevice) -> MTLRenderPipelineState? {
        do {
            let libreria = try device.makeLibrary(source: ShaderAcqua.sorgente, options: MTLCompileOptions())
            guard let vs = libreria.makeFunction(name: "vs_acqua"),
                  let fs = libreria.makeFunction(name: "fs_acqua") else { return nil }
            let descrittore = MTLRenderPipelineDescriptor()
            descrittore.vertexFunction = vs
            descrittore.fragmentFunction = fs
            descrittore.colorAttachments[0].pixelFormat = .bgra8Unorm
            return try device.makeRenderPipelineState(descriptor: descrittore)
        } catch {
            print("Sfondo d'acqua: shader non compilato (\(error.localizedDescription)), resta il fermo-immagine")
            return nil
        }
    }
}

// MARK: - Tela Metal

/// La MTKView dell'acqua: non prende i clic e avvisa quando entra o esce da una finestra.
final class TelaAcqua: MTKView {
    var cambioFinestra: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        cambioFinestra?()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct TelaAcquaMetal: NSViewRepresentable {
    let animato: Bool
    let intensita: Double
    let scuro: Bool

    func makeCoordinator() -> RendererAcqua { RendererAcqua() }

    func makeNSView(context: Context) -> TelaAcqua {
        let v = TelaAcqua(frame: .zero, device: ProgrammaAcqua.condiviso.device)
        context.coordinator.configura(v, animato: animato, intensita: intensita, scuro: scuro)
        return v
    }

    func updateNSView(_ v: TelaAcqua, context: Context) {
        context.coordinator.imposta(animato: animato, intensita: intensita, scuro: scuro)
    }

    static func dismantleNSView(_ v: TelaAcqua, coordinator: RendererAcqua) {
        coordinator.stacca()
    }
}

/// Disegna l'acqua: fa avanzare la fisica, scrive profili e uniformi, lancia lo shader.
/// Gira sul thread principale (MTKView chiama draw(in:) da lì). In pausa non ridisegna niente.
final class RendererAcqua: NSObject, MTKViewDelegate {
    private weak var vista: TelaAcqua?
    private var animato = true
    private var intensita = Float(SfondoAcqua.pioggiaLeggera)
    private var scuro = false

    private var pipeline: MTLRenderPipelineState?
    private var coda: MTLCommandQueue?
    private var fisica: FisicaAcqua?
    private var profili: [MTLBuffer] = []
    private var prossimo = 0
    private let semaforo = DispatchSemaphore(value: Misure.Acqua.fotogrammiInVolo)
    private var uniformi = [Float](repeating: 0, count: ShaderAcqua.Strato.totale)

    private var ultimo: CFTimeInterval = 0   // 0 = si riparte senza scatti
    private var inMoto = false
    private var mostrata = false
    private var staccato = false

    override init() {
        super.init()
        let centro = NotificationCenter.default
        centro.addObserver(self, selector: #selector(statoCambiato(_:)),
                           name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        centro.addObserver(self, selector: #selector(statoCambiato(_:)),
                           name: .NSProcessInfoPowerStateDidChange, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(statoCambiato(_:)),
                                                          name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                          object: nil)
    }

    func configura(_ v: TelaAcqua, animato: Bool, intensita: Double, scuro: Bool) {
        vista = v
        self.animato = animato
        self.intensita = Float(max(0, intensita))
        self.scuro = scuro
        v.colorPixelFormat = .bgra8Unorm
        v.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        v.framebufferOnly = true
        v.autoResizeDrawable = true
        v.preferredFramesPerSecond = Misure.Acqua.fotogrammiAlSecondo
        v.isPaused = true
        v.enableSetNeedsDisplay = true
        v.alphaValue = 0   // compare alla prima immagine disegnata
        v.delegate = self
        v.cambioFinestra = { [weak self] in self?.aggiornaMoto() }
        ProgrammaAcqua.condiviso.richiedi { [weak self] stato in self?.pronto(stato) }
    }

    func imposta(animato: Bool, intensita: Double, scuro: Bool) {
        let cambiaColore = scuro != self.scuro
        self.animato = animato
        self.intensita = Float(max(0, intensita))
        self.scuro = scuro
        aggiornaMoto()
        if cambiaColore && !inMoto { vista?.needsDisplay = true }
    }

    func stacca() {
        staccato = true
        inMoto = false
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        vista?.isPaused = true
        vista?.delegate = nil
        vista?.cambioFinestra = nil
    }

    private func pronto(_ stato: MTLRenderPipelineState?) {
        guard !staccato, let stato, let device = ProgrammaAcqua.condiviso.device,
              let coda = device.makeCommandQueue() else { return }   // resta il fermo-immagine
        let lunghezza = ShaderAcqua.maxImpatti * TabelleAcqua.nr * 2 * MemoryLayout<Float>.stride
        var buffer: [MTLBuffer] = []
        for _ in 0..<Misure.Acqua.fotogrammiInVolo {
            guard let b = device.makeBuffer(length: lunghezza, options: [.storageModeShared, .cpuCacheModeWriteCombined])
            else { return }
            buffer.append(b)
        }
        profili = buffer
        self.coda = coda
        fisica = FisicaAcqua()
        pipeline = stato
        aggiornaMoto()
        vista?.needsDisplay = true
    }

    @objc private func statoCambiato(_ nota: Notification) {
        // le notifiche del risparmio energetico arrivano da un thread qualsiasi
        DispatchQueue.main.async { [weak self] in self?.aggiornaMoto() }
    }

    /// L'acqua si muove solo se richiesto, con la finestra visibile, senza basso consumo
    /// e senza «Riduci movimento». In pausa la MTKView non ridisegna niente.
    func aggiornaMoto() {
        guard !staccato, let v = vista else { return }
        let visibile = v.window?.occlusionState.contains(.visible) ?? false
        let muovi = animato && visibile && pipeline != nil
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard muovi != inMoto else { return }
        inMoto = muovi
        ultimo = 0
        if muovi {
            v.enableSetNeedsDisplay = false
            v.isPaused = false
        } else {
            v.isPaused = true
            v.enableSetNeedsDisplay = true
            v.needsDisplay = true   // un'ultima immagine ferma, poi niente
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if !inMoto { view.needsDisplay = true }
    }

    func draw(in view: MTKView) {
        guard !staccato, let pipeline, let coda, let fisica, !profili.isEmpty else { return }
        let lato = view.bounds.size
        let px = view.drawableSize
        guard lato.width >= 1, lato.height >= 1, px.width >= 1, px.height >= 1 else { return }
        let w = Float(lato.width)
        let h = Float(lato.height)
        fisica.misura(larghezza: w, altezza: h)
        if inMoto {
            let ora = CACurrentMediaTime()
            if ultimo > 0 {
                fisica.passo(Float(min(ora - ultimo, Misure.Acqua.passoMassimo)), intensita: intensita)
            }
            ultimo = ora
        }

        semaforo.wait()
        let buffer = profili[prossimo]
        prossimo = (prossimo + 1) % profili.count
        let dati = buffer.contents().bindMemory(to: Float.self, capacity: ShaderAcqua.maxImpatti * TabelleAcqua.nr * 2)
        let scuro = self.scuro
        let tempo = Float(fisica.tempo)
        let dpr = Float(px.width / lato.width)
        uniformi.withUnsafeMutableBufferPointer { u in
            guard let p = u.baseAddress else { return }
            fisica.scrivi(profili: dati, uniformi: p)
            let c = ShaderAcqua.Strato.camera
            p[c] = w * 0.5
            p[c + 1] = h * 0.42
            p[c + 2] = max(w, h) * 1.15
            p[c + 3] = tempo
            let cielo = Colori.Acqua.cielo(scuro: scuro)
            RendererAcqua.scrivi(colore: cielo[0], in: p + ShaderAcqua.Strato.cielo1)
            RendererAcqua.scrivi(colore: cielo[1], in: p + ShaderAcqua.Strato.cielo2)
            RendererAcqua.scrivi(colore: cielo[2], in: p + ShaderAcqua.Strato.cielo3)
            let r = ShaderAcqua.Strato.risoluzione
            p[r] = w
            p[r + 1] = h
            p[r + 2] = dpr
            p[r + 3] = scuro ? 1 : 0
        }

        guard let passaggio = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let comandi = coda.makeCommandBuffer() else {
            semaforo.signal()
            return
        }
        passaggio.colorAttachments[0].loadAction = .dontCare
        guard let enc = comandi.makeRenderCommandEncoder(descriptor: passaggio) else {
            semaforo.signal()
            return
        }
        enc.setRenderPipelineState(pipeline)
        uniformi.withUnsafeBytes { b in
            if let base = b.baseAddress { enc.setFragmentBytes(base, length: b.count, index: 0) }
        }
        enc.setFragmentBuffer(buffer, offset: 0, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        comandi.present(drawable)
        let s = semaforo
        comandi.addCompletedHandler { _ in s.signal() }
        comandi.commit()

        if !mostrata {
            mostrata = true
            NSAnimationContext.runAnimationGroup({ contesto in
                contesto.duration = Misure.Acqua.comparsa
                view.animator().alphaValue = 1
            }, completionHandler: nil)
        }
    }

    /// Un colore 0xRRGGBB come float RGB (+ 1) nelle uniformi.
    private static func scrivi(colore v: UInt32, in p: UnsafeMutablePointer<Float>) {
        p[0] = Float((v >> 16) & 0xff) / 255
        p[1] = Float((v >> 8) & 0xff) / 255
        p[2] = Float(v & 0xff) / 255
        p[3] = 1
    }
}
