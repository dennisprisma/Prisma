#if os(macOS)
// Solo Mac (AppKit): su iPhone e iPad questo file non si compila.
import AppKit
import QuartzCore
import SwiftUI

/// L'istantanea in bitmap di una finestra interna, per il genio e la chiusura di Core Animation (MotoreGenio).
/// Si disegna nella «camera oscura»: una NSHostingView riusata dentro una finestra senza bordi fuori dallo
/// schermo, con la stessa vista delle istantanee di --istantanee (`modoIstantanea`: vetro disegnato, coprente)
/// e `cacheDisplay`, come il metodo «finestra» del workflow. ImageRenderer no: su macOS non disegna le viste
/// AppKit (ScrollView, campi, interruttori) e la finestra uscirebbe rotta.
/// Limite noto: la copia rifà la vista da capo, quindi lo stato locale dell'app (scorrimento di una lista, una
/// scheda interna) nella copia torna quello iniziale; il movimento dura 0,4 s e finisce sulla finestra vera.
/// Solo dal thread principale.
enum IstantaneaFinestra {
    struct Pronta {
        let immagine: CGImage
        /// Pixel per punto.
        let scala: CGFloat
        /// La misura della finestra, in punti.
        let misura: CGSize
        /// CACurrentMediaTime() della cattura.
        let quando: CFTimeInterval
    }

    /// Quanto è durata l'ultima cattura (secondi).
    nonisolated(unsafe) private(set) static var ultimaDurata: Double = 0
    /// true se l'ultima cattura ha superato genioAttesaMassimaIstantanea (o non è riuscita).
    static var lenta: Bool { ultimaDurata > Tema.Moto.Finestre.genioAttesaMassimaIstantanea }
    /// App che non si copiano: la copia farebbe girare il loro onAppear/onDisappear (la Ricerca installa i suoi
    /// tasti e li spegne all'uscita: romperebbe quella vera). Per loro c'è il ripiego.
    static let senzaCopia: Set<AppPrisma> = [.ricerca]

    nonisolated(unsafe) private static var camera: NSWindow?
    nonisolated(unsafe) private static var ospite: NSHostingView<AnyView>?

    /// Cattura sincrona della finestra `f` com'è nell'area `area`. Misura il tempo in `ultimaDurata`; nil se
    /// non si può (app senza copia, un foglio aperto, un'importazione in corso) o se l'immagine esce vuota.
    static func cattura(_ f: StatoShell.Finestra, stato: StatoShell, area: CGRect, scala: CGFloat, scuro: Bool) -> Pronta? {
        guard !senzaCopia.contains(f.app), stato.aggiornaValori == nil, stato.importazione == nil,
              stato.importazionePosizioni == nil else { return nil }
        // Con un foglio aperto la copia rifarebbe anche lui: niente istantanea
        if let w = MotoreGenio.condiviso.strato?.window, w.attachedSheet != nil || !w.sheets.isEmpty { return nil }
        let c = stato.cornice(di: f, in: area)
        guard c.width >= 1, c.height >= 1 else { return nil }
        let scala = max(1, scala)
        let forma = FormaVetro.arrotondata(f.ingrandita ? Tema.Raggio.finestraIngrandita : Tema.Raggio.finestra)
        let vista = FinestraInterna(finestra: f, attiva: true, area: area)
            .frame(width: c.width, height: c.height, alignment: .topLeading)
            // Sotto il vetro disegnato un fondo coprente, come la finestra vera sul vetro di Apple
            .background(forma.fill(Tema.Colore.Shell.fondoIstantaneaFinestra))
            // L'ombra la fa uno strato a parte: qui solo la forma della finestra
            .clipShape(forma)
            .environmentObject(stato)
            .environmentObject(stato.sistema)
            .environment(\.modoIstantanea, true)
            .environment(\.colorScheme, scuro ? .dark : .light)
        let inizio = CACurrentMediaTime()
        let immagine = disegna(AnyView(vista), misura: c.size, scala: scala, scuro: scuro)
        ultimaDurata = CACurrentMediaTime() - inizio
        guard let immagine, piena(immagine) else {
            // Non disegna: la volta dopo si va dritti al ripiego (l'istantanea si riprova al giro dopo)
            ultimaDurata = max(ultimaDurata, 2 * Tema.Moto.Finestre.genioAttesaMassimaIstantanea)
            return nil
        }
        return Pronta(immagine: immagine, scala: scala, misura: c.size, quando: CACurrentMediaTime())
    }

    /// L'immagine è davvero la finestra: campiona 64 punti dentro la forma (una griglia 8 × 8 lontana dagli
    /// angoli arrotondati) e almeno l'80% deve essere coprente (alfa > 0,5).
    static func piena(_ img: CGImage) -> Bool {
        let lato = 10
        var coprenti = 0
        var dati = [UInt8](repeating: 0, count: lato * lato * 4)
        let riuscito: Bool = dati.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress, let spazio = CGColorSpace(name: CGColorSpace.sRGB),
                  let ctx = CGContext(data: base, width: lato, height: lato, bitsPerComponent: 8, bytesPerRow: lato * 4,
                                      space: spazio, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                          | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: lato, height: lato))
            return true
        }
        guard riuscito else { return false }
        for riga in 1..<(lato - 1) {
            for colonna in 1..<(lato - 1) where dati[(riga * lato + colonna) * 4 + 3] > 127 {
                coprenti += 1
            }
        }
        return coprenti * 10 >= 64 * 8
    }

    /// Libera la camera oscura (la si ricrea al primo uso).
    static func libera() {
        ospite?.rootView = AnyView(EmptyView())
        camera?.orderOut(nil)
        camera?.contentView = nil
        camera = nil
        ospite = nil
    }

    // MARK: La camera oscura

    private static func preparaCamera() -> (NSWindow, NSHostingView<AnyView>) {
        if let camera, let ospite { return (camera, ospite) }
        let h = NSHostingView(rootView: AnyView(EmptyView()))
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10), styleMask: [.borderless],
                         backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.ignoresMouseEvents = true
        w.hasShadow = false
        w.isOpaque = false
        w.backgroundColor = .clear
        w.isExcludedFromWindowsMenu = true
        w.collectionBehavior = [.transient, .ignoresCycle]
        w.contentView = h
        w.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        camera = w
        ospite = h
        return (w, h)
    }

    /// Disegna la vista nella camera alla scala data (pixel per punto) e la toglie subito: niente resta acceso
    /// (né l'albero copiato né i suoi abbonamenti). Nessun giro del run loop: la cattura resta nel giro.
    private static func disegna(_ vista: AnyView, misura: CGSize, scala: CGFloat, scuro: Bool) -> CGImage? {
        let (finestra, ospite) = preparaCamera()
        let aspetto = NSAppearance(named: scuro ? .darkAqua : .aqua)
        finestra.appearance = aspetto
        ospite.appearance = aspetto
        ospite.rootView = vista
        finestra.setContentSize(misura)
        finestra.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        ospite.frame = NSRect(origin: .zero, size: misura)
        // Come conFinestra di Istantanee: senza bordi non diventa né principale né quella dei tasti
        finestra.orderFront(nil)
        defer {
            ospite.rootView = AnyView(EmptyView())
            finestra.orderOut(nil)
        }
        ospite.layoutSubtreeIfNeeded()
        let larghezza = Int((misura.width * scala).rounded(.up))
        let altezza = Int((misura.height * scala).rounded(.up))
        guard larghezza > 0, altezza > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: larghezza, pixelsHigh: altezza,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        rep.size = misura
        // Il bitmap parte trasparente (fuori dagli angoli arrotondati non c'è niente)
        if let contesto = NSGraphicsContext(bitmapImageRep: rep) {
            contesto.cgContext.clear(CGRect(x: 0, y: 0, width: larghezza, height: altezza))
        }
        let scatta = { ospite.cacheDisplay(in: ospite.bounds, to: rep) }
        if let aspetto {
            aspetto.performAsCurrentDrawingAppearance(scatta)
        } else {
            scatta()
        }
        return rep.cgImage
    }
}
#endif
