import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import Metal
import QuartzCore
import CoreVideo

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
        /// Un solo ritmo, sempre uguale (scrivania libera o coperta da finestre, anche ingrandite, Prisma attiva
        /// o no, durante le animazioni): l'acqua è al rallentatore e 30 fotogrammi al secondo, battuti dallo
        /// schermo (a 60 Hz uno ogni due), bastano e lasciano GPU e processori al resto dell'interfaccia su un M1 con 8 GB.
        static let fotogrammiAlSecondo = 30
        /// Con il risparmio energetico l'acqua non si ferma: rallenta il ritmo dei fotogrammi (a 60 Hz uno ogni tre).
        /// La fisica segue sempre il tempo vero, quindi le gocce vanno alla stessa velocità, solo meno fluide.
        static let fotogrammiAlSecondoBassoConsumo = 20
        /// Drawable del CAMetalLayer e fotogrammi preparati in anticipo per la GPU (uno in meno),
        /// così nextDrawable non fa aspettare la coda del disegno.
        static let drawable = 3
        static let fotogrammiInVolo = 2
        /// Passo di tempo massimo (s): la fisica segue il tempo vero, anche con un fotogramma saltato (1/15 s a 30
        /// al secondo, 1/10 s a 20). Oltre (un intoppo lungo, tipico dei primi istanti dopo l'apertura) l'acqua
        /// rallenta un attimo invece di saltare in avanti: al rallentatore un salto di 1/4 s si vede (la caduta di
        /// una goccia dura 0,42 s). Le pause vere (riposo, finestra nascosta) ripartono già senza recupero.
        static let passoMassimo: Double = 0.1
        /// Un battito dello schermo vale come puntuale se arriva entro questa quota del periodo dello schermo.
        static let tolleranzaBattito: Double = 0.5
        /// Lo stesso, in quota dell'intervallo, per il timer di ripiego (senza CVDisplayLink).
        static let tolleranzaOrologio: Double = 0.25
        /// Riprova di un'immagine ferma quando la GPU è indietro (s).
        static let riprovaFermo: Double = 1.0 / 60
        /// Pixel del drawable rispetto a quelli dello schermo Retina: l'acqua è morbida, così la GPU fa poco più di metà del lavoro.
        static let quotaRisoluzione: CGFloat = 0.75
        /// Dissolvenza della prima immagine disegnata sopra il fermo-immagine (s).
        static let comparsa: Double = 0.4
        /// La prima immagine aspetta che la misura dello sfondo resti ferma per questo tempo (s): all'apertura la finestra
        /// passa per misure provvisorie, e un'immagine disegnata lì verrebbe stirata o metterebbe le onde fuori posto.
        static let attesaMisura: Double = 0.15
        /// La dissolvenza parte quando la prima immagine è sullo schermo; se il Mac non lo dice, parte comunque dopo (s).
        static let riservaComparsa: Double = 0.3

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
/// Si muove sempre allo stesso ritmo, fuori dal thread principale, anche mentre l'interfaccia si anima e
/// anche con le app aperte sopra (finestre ingrandite comprese): lo sfondo è sempre attivo.
/// Si ferma solo con `animato` falso («Sfondo fermo» nelle Impostazioni, o la sala della presentazione che lo
/// copre del tutto), con la finestra del Mac nascosta, ridotta nel Dock o coperta, con «Riduci movimento» e con
/// il Mac a riposo. Con il risparmio energetico continua a muoversi a un ritmo più basso
/// (`fotogrammiAlSecondoBassoConsumo`). Nelle istantanee resta il fermo-immagine.
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

    /// Lo shader non si è compilato (o mancano i buffer): resta il fermo-immagine completo.
    @State private var senzaMetal = false

    var body: some View {
        #if os(macOS)
        let conMetal = !modoIstantanea && !senzaMetal && ProgrammaAcqua.condiviso.device != nil
        #elseif os(iOS)
        // iPhone e iPad: la stessa acqua animata del Mac (iOS/SfondoAcquaMobile.swift, CAMetalLayer e CADisplayLink);
        // istantanee iOS: il fermo-immagine
        let conMetal = SfondoAcqua.animabileSuiOS && !modoIstantanea && !senzaMetal && ProgrammaAcqua.condiviso.device != nil
        #endif
        ZStack {
            // Sotto c'è sempre il fermo-immagine: la tela Metal compare sopra alla prima immagine. Quando Metal disegna,
            // sotto restano solo cielo e luce, senza i cerchi: i cerchi disegnati a mano non coincidono con le onde
            // vere, e nella dissolvenza dell'apertura si vedevano trasformarsi in altri cerchi
            SfondoAcquaFermo(scuro: scuro, anelli: !conMetal)
            #if os(macOS)
            if conMetal {
                TelaAcquaMetal(animato: animato, intensita: intensita, scuro: scuro, rinuncia: { senzaMetal = true })
                    .allowsHitTesting(false)
            }
            #elseif os(iOS)
            if conMetal {
                TelaAcquaMetalMobile(animato: animato, intensita: intensita, scuro: scuro, rinuncia: { senzaMetal = true })
                    .allowsHitTesting(false)
            }
            #endif
        }
        .accessibilityHidden(true)
    }
}

/// Fermo-immagine dello sfondo d'acqua, tutto in SwiftUI (niente Metal, niente Canvas):
/// il gradiente del tema, la luce dello studio e qualche cerchio d'acqua in rilievo.
/// Va bene per le istantanee PNG e come ripiego.
struct SfondoAcquaFermo: View {
    let scuro: Bool
    /// false: solo cielo e luce (sotto l'acqua animata, che porta da sé i suoi cerchi).
    let anelli: Bool

    init(scuro: Bool, anelli: Bool = true) {
        self.scuro = scuro
        self.anelli = anelli
    }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            ZStack(alignment: .topLeading) {
                gradiente(w: w, h: h)
                lampada(w: w, h: h)
                if anelli {
                    ForEach(Misure.Acqua.anelli.indices, id: \.self) { i in
                        anello(Misure.Acqua.anelli[i], w: w, h: h)
                    }
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

// La tela animata (NSView, CVDisplayLink, finestre e sonno del Mac) esiste solo sul Mac.
#if os(macOS)

/// La vista dell'acqua: un CAMetalLayer che non prende i clic. Avvisa quando entra o esce da una finestra e quando
/// cambia misura; il drawable è a `Misure.Acqua.quotaRisoluzione` dei pixel dello schermo (il layer stira l'immagine).
/// Non disegna da sé: il disegno lo fa RendererAcqua sulla sua coda, fuori dal thread principale.
final class TelaAcqua: NSView {
    let strato = CAMetalLayer()
    var cambioFinestra: (() -> Void)?
    /// Misura in punti e in pixel del drawable (dal thread principale).
    var cambioMisura: ((CGSize, CGSize) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
    }

    required init?(coder: NSCoder) {
        fatalError("TelaAcqua si crea solo dal codice")
    }

    override func makeBackingLayer() -> CALayer { strato }

    // AppKit non disegna niente nel layer: le immagini le presenta Metal
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {}

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        aggiornaRisoluzione()
        cambioFinestra?()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        aggiornaRisoluzione()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        aggiornaRisoluzione()
    }

    /// Misura del drawable: punti × scala dello schermo × quota (mai sotto 1 pixel per punto).
    func aggiornaRisoluzione() {
        let schermo = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let f = max(1, schermo * Misure.Acqua.quotaRisoluzione)
        let lato = bounds.size
        let pixel = CGSize(width: max(1, (lato.width * f).rounded()), height: max(1, (lato.height * f).rounded()))
        cambioMisura?(lato, pixel)
    }
}

private struct TelaAcquaMetal: NSViewRepresentable {
    let animato: Bool
    let intensita: Double
    let scuro: Bool
    /// Metal non può disegnare: SfondoAcqua torna al fermo-immagine completo (thread principale).
    let rinuncia: () -> Void

    func makeCoordinator() -> RendererAcqua { RendererAcqua() }

    func makeNSView(context: Context) -> TelaAcqua {
        let v = TelaAcqua(frame: .zero)
        context.coordinator.rinuncia = rinuncia
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

/// Disegna l'acqua fuori dal thread principale, a un ritmo solo e sempre uguale.
/// - Thread principale: impostazioni, notifiche e quando muoversi; accende e spegne il battito.
/// - Battito: l'orologio dello schermo (CVDisplayLink) sceglie un fotogramma ogni 1/`fotogrammiAlSecondo` s
///   (1/`fotogrammiAlSecondoBassoConsumo` s con il risparmio energetico)
///   e lo mette in coda, mai due alla volta.
/// - Coda del disegno: fisica, profili, uniformi e GPU. La fisica segue il tempo vero dello schermo: un fotogramma
///   saltato (GPU indietro, coda occupata) non ferma il tempo, quindi l'acqua non rallenta mai mentre il resto
///   dell'interfaccia si anima, e non lo fa aspettare.
/// Fra i tre passa solo `Condiviso`, sotto `serratura` (tenuta per poche istruzioni, mai durante il disegno).
final class RendererAcqua: NSObject {
    /// Ciò che il thread principale e il battito passano alla coda del disegno.
    private struct Condiviso {
        var inMoto = false
        var intensita: Float = 0
        var scuro = false
        var lato = CGSize.zero
        var pixel = CGSize.zero
        /// L'acqua è appena ripartita: la fisica riprende da qui, senza recuperare la pausa.
        var ripartenza = true
        /// Un fotogramma in moto è in coda o in corso: il battito non ne accoda un altro.
        var motoInCoda = false
        /// Un'immagine ferma è in coda.
        var fermoInCoda = false
        /// Istante (orologio dello schermo) dell'ultimo fotogramma accodato.
        var ultimoBattito: CFTimeInterval = 0
        /// Istante (stesso orologio) dell'ultimo cambio di misura: la prima immagine aspetta che la misura si fermi.
        var istanteMisura: CFTimeInterval = 0
        /// Secondi fra due fotogrammi in moto (1/30, o 1/20 con il risparmio energetico).
        var intervallo: Double = 1.0 / Double(Misure.Acqua.fotogrammiAlSecondo)
    }

    /// Secondi per tick dell'orologio di sistema (lo stesso di CACurrentMediaTime e del CVDisplayLink).
    private static let secondiPerTick: Double = {
        var info = mach_timebase_info_data_t()
        _ = mach_timebase_info(&info)
        return info.denom > 0 ? Double(info.numer) / Double(info.denom) / 1_000_000_000 : 1e-9
    }()

    private let serratura = NSLock()
    private var condiviso = Condiviso()
    private let codaDisegno = DispatchQueue(label: "prisma.acqua.disegno", qos: .userInteractive,
                                            autoreleaseFrequency: .workItem)

    // Solo thread principale
    private weak var vista: TelaAcqua?
    /// Chiamata se Metal non può disegnare (shader non compilato, buffer mancanti).
    var rinuncia: (() -> Void)?
    /// La dissolvenza della prima immagine è partita.
    private var comparsaAvviata = false
    private var animato = true
    private var scuro = false
    private var inMoto = false
    /// Fotogrammi al secondo in uso (cambia con il risparmio energetico).
    private var ritmo = Misure.Acqua.fotogrammiAlSecondo
    private var pronta = false
    private var staccato = false
    /// Mac (o schermo) a riposo: ferma fino a poco dopo il risveglio.
    private var aRiposo = false
    private var ripresaRisveglio: DispatchWorkItem?
    private var link: CVDisplayLink?
    private var battitoAcceso = false
    /// Ripiego se il Mac non dà il CVDisplayLink: un timer preciso fuori dal thread principale.
    private var orologio: DispatchSourceTimer?

    // Solo coda del disegno
    private var strato: CAMetalLayer?
    private var pipeline: MTLRenderPipelineState?
    private var comandiGPU: MTLCommandQueue?
    private var fisica: FisicaAcqua?
    private var profili: [MTLBuffer] = []
    private var prossimo = 0
    private let semaforo = DispatchSemaphore(value: Misure.Acqua.fotogrammiInVolo)
    private var uniformi = [Float](repeating: 0, count: ShaderAcqua.Strato.totale)
    private var ultimo: CFTimeInterval = 0   // 0 = si riparte senza scatti
    private var mostrata = false

    override init() {
        super.init()
        let centro = NotificationCenter.default
        centro.addObserver(self, selector: #selector(statoCambiato(_:)),
                           name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        centro.addObserver(self, selector: #selector(statoCambiato(_:)),
                           name: .NSProcessInfoPowerStateDidChange, object: nil)
        centro.addObserver(self, selector: #selector(schermoCambiato(_:)),
                           name: NSWindow.didChangeScreenNotification, object: nil)
        let spazio = NSWorkspace.shared.notificationCenter
        spazio.addObserver(self, selector: #selector(statoCambiato(_:)),
                           name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        for nome in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            spazio.addObserver(self, selector: #selector(riposo(_:)), name: nome, object: nil)
        }
        for nome in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            spazio.addObserver(self, selector: #selector(risveglio(_:)), name: nome, object: nil)
        }
    }

    deinit {
        if let l = link, battitoAcceso { _ = CVDisplayLinkStop(l) }
        orologio?.cancel()
    }

    func configura(_ v: TelaAcqua, animato: Bool, intensita: Double, scuro: Bool) {
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
        v.alphaValue = 0   // compare alla prima immagine disegnata
        serratura.lock()
        condiviso.intensita = Float(max(0, intensita))
        condiviso.scuro = scuro
        serratura.unlock()
        v.cambioMisura = { [weak self] lato, pixel in self?.misura(lato: lato, pixel: pixel) }
        v.cambioFinestra = { [weak self] in self?.cambioFinestra() }
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
        ripresaRisveglio?.cancel()
        ripresaRisveglio = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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
        // senza programma, coda o buffer resta il fermo-immagine completo, con i suoi cerchi
        guard let stato, let device = ProgrammaAcqua.condiviso.device,
              let comandi = device.makeCommandQueue() else {
            avvisaRinuncia()
            return
        }
        let lunghezza = ShaderAcqua.maxImpatti * TabelleAcqua.nr * 2 * MemoryLayout<Float>.stride
        var buffer: [MTLBuffer] = []
        for _ in 0..<Misure.Acqua.fotogrammiInVolo {
            guard let b = device.makeBuffer(length: lunghezza, options: [.storageModeShared, .cpuCacheModeWriteCombined])
            else {
                avvisaRinuncia()
                return
            }
            buffer.append(b)
        }
        let nuova = FisicaAcqua()
        let pronti = buffer
        // Da qui in poi programma, buffer e fisica li tocca solo la coda del disegno
        codaDisegno.async { [weak self] in
            guard let self else { return }
            self.pipeline = stato
            self.comandiGPU = comandi
            self.profili = pronti
            self.fisica = nuova
        }
        pronta = true
        aggiornaMoto()
        chiediFermo()   // la prima immagine sopra il fermo-immagine, anche se l'acqua resta ferma
    }

    /// Avvisa SfondoAcqua che resta il fermo-immagine; sempre a giro finito, perché la risposta del programma può
    /// arrivare dentro makeNSView, cioè durante l'aggiornamento della vista.
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
        // in moto ci pensa il prossimo fotogramma
        if cambiata && !inMoto { chiediFermo() }
    }

    private func cambioFinestra() {
        collegaSchermo()
        aggiornaMoto()
    }

    @objc private func statoCambiato(_ nota: Notification) {
        // le notifiche del risparmio energetico arrivano da un thread qualsiasi
        DispatchQueue.main.async { [weak self] in self?.aggiornaMoto() }
    }

    /// La finestra è passata su un altro schermo: il battito segue quello schermo.
    @objc private func schermoCambiato(_ nota: Notification) {
        sulMain { [weak self] in self?.collegaSchermo() }
    }

    /// Stop del Mac, schermo spento o utente cambiato: ferma subito.
    @objc private func riposo(_ nota: Notification) {
        sulMain { [weak self] in
            guard let self else { return }
            self.ripresaRisveglio?.cancel()
            self.ripresaRisveglio = nil
            self.aRiposo = true
            self.aggiornaMoto()
        }
    }

    /// Risveglio: l'interfaccia c'è già; l'acqua riparte dopo `ripresaAcquaDopoRisveglio`.
    @objc private func risveglio(_ nota: Notification) {
        sulMain { [weak self] in
            guard let self else { return }
            self.ripresaRisveglio?.cancel()
            let lavoro = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.ripresaRisveglio = nil
                self.aRiposo = false
                self.aggiornaMoto()
            }
            self.ripresaRisveglio = lavoro
            DispatchQueue.main.asyncAfter(deadline: .now() + Tema.Moto.Blocco.ripresaAcquaDopoRisveglio, execute: lavoro)
        }
    }

    private func sulMain(_ fai: @escaping () -> Void) {
        if Thread.isMainThread { fai() } else { DispatchQueue.main.async(execute: fai) }
    }

    /// L'acqua si muove se richiesto («Sfondo animato» e sfondo non coperto dalla presentazione), con la finestra
    /// del Mac visibile, senza «Riduci movimento» e con il Mac sveglio. Sempre allo stesso ritmo: niente pause
    /// durante le animazioni dell'interfaccia, niente pause né rallentamenti con finestre aperte (anche ingrandite)
    /// o Prisma in secondo piano. Con il risparmio energetico solo un ritmo più basso, mai ferma.
    /// Da ferma il CAMetalLayer tiene l'ultima immagine e non si disegna niente.
    func aggiornaMoto() {
        guard !staccato, let v = vista else { return }
        let visibile = v.window?.occlusionState.contains(.visible) ?? false
        let muovi = animato && visibile && pronta && !aRiposo
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
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

    /// Il ritmo segue il risparmio energetico: il battito dello schermo legge l'intervallo nuovo dal prossimo
    /// fotogramma; il timer di ripiego (senza CVDisplayLink) si riprogramma.
    private func aggiornaRitmo() {
        let nuovo = ProcessInfo.processInfo.isLowPowerModeEnabled
            ? Misure.Acqua.fotogrammiAlSecondoBassoConsumo : Misure.Acqua.fotogrammiAlSecondo
        guard nuovo != ritmo else { return }
        ritmo = nuovo
        serratura.lock()
        condiviso.intervallo = 1.0 / Double(nuovo)
        serratura.unlock()
        if let t = orologio, battitoAcceso {
            t.schedule(deadline: .now(), repeating: 1.0 / Double(nuovo), leeway: .milliseconds(1))
        }
    }

    // MARK: Battito

    private func avviaBattito() {
        guard !battitoAcceso else { return }
        if link == nil && orologio == nil {
            var nuovo: CVDisplayLink?
            if CVDisplayLinkCreateWithActiveCGDisplays(&nuovo) == kCVReturnSuccess, let l = nuovo {
                // Arriva sul thread dello schermo: niente thread principale, solo la scelta del fotogramma
                _ = CVDisplayLinkSetOutputHandler(l) { [weak self] _, _, uscita, _, _ in
                    let t = uscita.pointee
                    let periodo = t.videoTimeScale > 0 ? Double(t.videoRefreshPeriod) / Double(t.videoTimeScale) : 0
                    let ora = t.hostTime > 0 ? Double(t.hostTime) * RendererAcqua.secondiPerTick : CACurrentMediaTime()
                    self?.battito(ora: ora, periodo: periodo)
                    return kCVReturnSuccess
                }
                link = l
            }
        }
        battitoAcceso = true
        if let l = link {
            collegaSchermo()
            _ = CVDisplayLinkStart(l)
        } else {
            let t = DispatchSource.makeTimerSource(flags: .strict, queue: DispatchQueue.global(qos: .userInteractive))
            t.schedule(deadline: .now(), repeating: 1.0 / Double(ritmo), leeway: .milliseconds(1))
            t.setEventHandler { [weak self] in self?.battito(ora: CACurrentMediaTime(), periodo: 0) }
            t.resume()
            orologio = t
        }
    }

    private func fermaBattito() {
        guard battitoAcceso else { return }
        battitoAcceso = false
        if let l = link { _ = CVDisplayLinkStop(l) }
        orologio?.cancel()
        orologio = nil
    }

    /// Il battito segue lo schermo su cui sta la finestra.
    private func collegaSchermo() {
        guard let l = link, let schermo = vista?.window?.screen,
              let numero = schermo.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
        _ = CVDisplayLinkSetCurrentCGDisplay(l, CGDirectDisplayID(numero.uint32Value))
    }

    /// Un battito dello schermo (thread del CVDisplayLink o del timer): `ora` è l'istante in cui l'immagine
    /// andrà sullo schermo, `periodo` il periodo dello schermo (0 se non si sa). Un fotogramma ogni intervallo,
    /// allineato ai battiti (a 60 Hz uno ogni due, uno ogni tre con il risparmio energetico), e mai due in coda.
    private func battito(ora: CFTimeInterval, periodo: Double) {
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

    /// Un'immagine ferma (colore o misura cambiati, prima immagine), da qualsiasi thread; le richieste si sommano.
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

    /// `moto`: fotogramma dal battito, la fisica avanza; altrimenti un'immagine ferma.
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

    /// Fa avanzare la fisica con il tempo vero, scrive profili e uniformi, lancia lo shader e presenta.
    /// Non aspetta mai: se la GPU è indietro salta il fotogramma (il passo successivo recupera il tempo).
    /// Ridà true se un'immagine ferma va riprovata.
    private func fotogramma(_ c: Condiviso, ora: CFTimeInterval, moto: Bool) -> Bool {
        if moto && c.ripartenza { ultimo = 0 }
        guard let strato, let pipeline, let comandiGPU, let fisica, !profili.isEmpty else { return false }
        if moto && !c.inMoto { return false }   // fermata nel frattempo
        let lato = c.lato
        let px = c.pixel
        guard lato.width >= 1, lato.height >= 1, px.width >= 1, px.height >= 1 else { return false }
        // Prima immagine: solo a misura ferma (all'apertura la finestra passa per misure provvisorie). Un'immagine ferma
        // si riprova; in moto si salta il battito, e con `ultimo` ancora a 0 il primo passo resta senza recupero
        if !mostrata && ora - c.istanteMisura < Misure.Acqua.attesaMisura { return !moto }
        guard semaforo.wait(timeout: .now()) == .success else { return !moto }

        if strato.drawableSize != px {
            // fuori dal thread principale si cambia il layer solo in una transazione esplicita
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
            RendererAcqua.scrivi(colore: cielo[0], in: p + ShaderAcqua.Strato.cielo1)
            RendererAcqua.scrivi(colore: cielo[1], in: p + ShaderAcqua.Strato.cielo2)
            RendererAcqua.scrivi(colore: cielo[2], in: p + ShaderAcqua.Strato.cielo3)
            let r = ShaderAcqua.Strato.risoluzione
            p[r] = w
            p[r + 1] = h
            p[r + 2] = dpr
            p[r + 3] = scuro ? 1 : 0
        }

        // Con un drawable in meno dei fotogrammi in volo, nextDrawable di solito non aspetta
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
            // La dissolvenza parte quando questa immagine è davvero sullo schermo, non sopra un layer ancora vuoto
            mostrata = true
            drawable.addPresentedHandler { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.mostra() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Misure.Acqua.riservaComparsa) { [weak self] in self?.mostra() }
        }
        comandi.present(drawable)
        let s = semaforo
        comandi.addCompletedHandler { _ in s.signal() }
        comandi.commit()
        // La prova guidata della fluidità conta i fotogrammi d'acqua in moto (contatore sicuro da ogni thread)
        if moto { MisuratoreFluidita.segnaFotogrammaAcqua() }
        return false
    }

    /// Dissolvenza della prima immagine sopra il fermo-immagine (thread principale).
    private func mostra() {
        guard !staccato, !comparsaAvviata, let v = vista else { return }
        comparsaAvviata = true
        NSAnimationContext.runAnimationGroup({ contesto in
            contesto.duration = Misure.Acqua.comparsa
            v.animator().alphaValue = 1
        }, completionHandler: nil)
    }

    /// Un colore 0xRRGGBB come float RGB (+ 1) nelle uniformi.
    private static func scrivi(colore v: UInt32, in p: UnsafeMutablePointer<Float>) {
        p[0] = Float((v >> 16) & 0xff) / 255
        p[1] = Float((v >> 8) & 0xff) / 255
        p[2] = Float(v & 0xff) / 255
        p[3] = 1
    }
}
#endif
