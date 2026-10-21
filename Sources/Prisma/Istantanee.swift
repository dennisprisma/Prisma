import AppKit
import SwiftUI

/// Modalità istantanea (`Prisma --istantanee <cartella>`): disegna le schermate principali
/// in PNG senza aprire finestre e senza toccare l'archivio. La usa il workflow di build
/// per pubblicare le anteprime a ogni modifica.
@MainActor
enum Istantanee {
    static let dimensione = CGSize(width: 1440, height: 900)

    static let scene: [(nome: String, prepara: (StatoShell) -> Void)] = [
        ("1-scrivania", { _ in }),
        ("2-posizioni", { $0.apri(.posizioni) }),
        ("3-impostazioni-archivio", { s in
            s.apri(.impostazioni)
            s.schedaImpostazioni = .archivio
        }),
        ("4-finestra-non-ingrandita", { s in
            s.apri(.clienti)
            s.alternaIngrandimento(.clienti)
        }),
    ]

    /// Metodi di disegno, in ordine di preferenza sul server di build:
    /// - "finestra": NSHostingView in una finestra fuori schermo + cacheDisplay (senza Metal)
    /// - "livello": come sopra, ma con CALayer.render(in:)
    /// - "renderer": ImageRenderer di SwiftUI (richiede Metal)
    static func genera(in cartella: URL, metodo: String) -> Int32 {
        _ = NSApplication.shared
        do {
            try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        } catch {
            print("ERRORE: cartella delle istantanee non creata: \(error.localizedDescription)")
            return 1
        }
        for scena in scene {
            let stato = StatoShell(persistente: false)
            stato.area = ShellView.area(per: dimensione)
            scena.prepara(stato)
            let vista = ShellView()
                .environmentObject(stato)
                .environment(\.modoIstantanea, true)
                .frame(width: dimensione.width, height: dimensione.height)
            let png: Data?
            switch metodo {
            case "renderer": png = conRenderer(vista)
            case "livello": png = conFinestra(vista, livello: true)
            default: png = conFinestra(vista, livello: false)
            }
            guard let png else {
                print("ERRORE: istantanea \(scena.nome) non disegnata (metodo \(metodo))")
                return 1
            }
            do {
                try png.write(to: cartella.appendingPathComponent("\(scena.nome).png"))
                print("OK: \(scena.nome).png (metodo \(metodo))")
            } catch {
                print("ERRORE: \(scena.nome).png non salvata: \(error.localizedDescription)")
                return 1
            }
        }
        return 0
    }

    private static func conRenderer<V: View>(_ vista: V) -> Data? {
        let renderer = ImageRenderer(content: vista)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return nil }
        return pngVerificato(NSBitmapImageRep(cgImage: cg))
    }

    private static func conFinestra<V: View>(_ vista: V, livello: Bool) -> Data? {
        let host = NSHostingView(rootView: vista)
        host.frame = NSRect(origin: .zero, size: dimensione)
        let finestra = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        finestra.contentView = host
        finestra.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        finestra.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        defer { finestra.orderOut(nil) }

        if livello {
            let scala: CGFloat = 2
            guard let strato = host.layer,
                  let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                             pixelsWide: Int(dimensione.width * scala), pixelsHigh: Int(dimensione.height * scala),
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let contesto = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
            let cg = contesto.cgContext
            cg.scaleBy(x: scala, y: scala)
            if !host.isFlipped {
                strato.render(in: cg)
            } else {
                cg.translateBy(x: 0, y: dimensione.height)
                cg.scaleBy(x: 1, y: -1)
                strato.render(in: cg)
            }
            return pngVerificato(rep)
        }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        return pngVerificato(rep)
    }

    /// Scarta le immagini vuote (tutte dello stesso colore): vuol dire che il metodo non disegna.
    private static func pngVerificato(_ rep: NSBitmapImageRep) -> Data? {
        let campioni = [(0.1, 0.1), (0.5, 0.5), (0.9, 0.2), (0.3, 0.8), (0.7, 0.95), (0.5, 0.02)]
        let colori = campioni.compactMap { c in
            rep.colorAt(x: Int(Double(rep.pixelsWide) * c.0), y: Int(Double(rep.pixelsHigh) * c.1))
        }
        let diversi = Set(colori.map { "\(Int($0.redComponent * 255))-\(Int($0.greenComponent * 255))-\(Int($0.blueComponent * 255))" })
        guard diversi.count > 1 else {
            print("ATTENZIONE: immagine vuota")
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}

private struct ChiaveModoIstantanea: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// true quando la vista viene disegnata per un'istantanea (niente viste AppKit).
    var modoIstantanea: Bool {
        get { self[ChiaveModoIstantanea.self] }
        set { self[ChiaveModoIstantanea.self] = newValue }
    }
}
