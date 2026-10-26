import AppKit
import Foundation
import SwiftUI

/// Accesso alle risorse dell'app (icone, sfondi, materiali, loghi).
///
/// Nel pacchetto Prisma.app il bundle delle risorse SwiftPM sta in
/// Contents/Resources, dove `Bundle.module` non lo cerca: per questo lo
/// cerchiamo prima lì e solo in sviluppo (`swift run`) ripieghiamo su
/// `Bundle.module`.
enum Risorse {
    static let nomeBundle = "Prisma_Prisma.bundle"

    static let bundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent(nomeBundle),
           let b = Bundle(url: url) {
            return b
        }
        return Bundle.module
    }()

    /// Cartella "Risorse" copiata così com'è nel bundle.
    static var cartella: URL? {
        bundle.resourceURL?.appendingPathComponent("Risorse", isDirectory: true)
    }

    private static var cache: [String: NSImage] = [:]

    /// Immagine dalla cartella Risorse. `scala` 2 = PNG disegnati a doppia risoluzione.
    static func immagine(_ percorso: String, scala: CGFloat = 1) -> NSImage? {
        let chiave = "\(percorso)@\(scala)"
        if let img = cache[chiave] { return img }
        guard let url = cartella?.appendingPathComponent(percorso),
              let img = NSImage(contentsOf: url) else { return nil }
        if scala != 1, let rep = img.representations.first {
            img.size = NSSize(width: CGFloat(rep.pixelsWide) / scala, height: CGFloat(rep.pixelsHigh) / scala)
        }
        cache[chiave] = img
        return img
    }

    static func icona(_ nome: String) -> NSImage? {
        immagine("Icone/\(nome).png")
    }

    /// Usato dal workflow di build (`Prisma --verifica-risorse`) per
    /// controllare che le risorse vengano davvero trovate a runtime.
    static func verifica() -> Int32 {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent(nomeBundle),
              FileManager.default.fileExists(atPath: url.path) else {
            print("ERRORE: \(nomeBundle) non trovato in Contents/Resources")
            return 1
        }
        let necessarie = ["Icone/Prisma.png", "Icone/Agenda_base.png", "Icone/Agenda_vetro.png",
                          "Sfondi/Gocce.jpg", "Materiali/Grana.png", "Materiali/Lino_trama.png",
                          "Materiali/Pelle.png", "Loghi/Alleanza_simbolo.png"]
        for p in necessarie where immagine(p) == nil {
            print("ERRORE: \(p) non caricabile dal bundle \(bundle.bundlePath)")
            return 1
        }
        for app in AppPrisma.allCases where icona(app.icona) == nil {
            print("ERRORE: icona \(app.icona) mancante")
            return 1
        }
        // Le icone ridotte ai pixel di uno schermo Retina con il dock ingrandito devono uscire intere
        let latoDock = CGSize(width: Misure.Dock.icona, height: Misure.Dock.icona)
        let pixelAttesi = Int((Misure.Dock.icona * 2 * Misure.Dock.ingrandimento).rounded())
        for app in AppPrisma.allCases {
            guard let img = immagineNitida("Icone/\(app.icona).png", in: latoDock, scala: 2 * Misure.Dock.ingrandimento),
                  let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  cg.width == pixelAttesi, cg.height == pixelAttesi,
                  abs(img.size.width - Misure.Dock.icona) < 0.01 else {
                print("ERRORE: icona \(app.icona) non ridotta ai pixel dello schermo")
                return 1
            }
        }
        if immagineNitida("Loghi/Alleanza_simbolo.png", in: CGSize(width: .infinity, height: 15), scala: 2) == nil {
            print("ERRORE: logo Alleanza non ridotto")
            return 1
        }
        print("OK: risorse trovate in \(bundle.bundlePath)")
        return 0
    }
}

extension Risorse {
    /// Immagini già ridotte ai pixel dello schermo: chiave "percorso#LxA" (pixel del riquadro richiesto).
    /// Solo dal thread principale (SwiftUI valuta i body lì).
    private static var cacheNitide: [String: NSImage] = [:]
    private static var pixelInCache = 0
    /// Oltre questo budget (≈ 12 MB a 4 byte per pixel) la cache si svuota: il Mac ha 8 GB.
    private static let limitePixelCache = 3_000_000

    /// L'immagine della risorsa ridotta con CoreGraphics ai pixel esatti con cui verrà mostrata.
    ///
    /// Sugli schermi Retina CoreAnimation riduce le bitmap da 512 px con un filtro lineare senza mipmap:
    /// con rapporti di 5–12× le linee sottili delle icone si spezzano. Qui la riduzione la fa CoreGraphics
    /// a passi ≤ 2:1 (lo stesso percorso delle istantanee del server), e a SwiftUI arriva una bitmap 1:1.
    ///
    /// - misura: lo spazio in punti in cui deve stare, mantenendo le proporzioni; una dimensione
    ///   infinita o zero non vincola (es. logo: solo l'altezza)
    /// - scala: `displayScale` dello schermo (1 o 2), moltiplicata se serve per una riserva
    ///   d'ingrandimento (1,13 nel dock) così l'icona resta nitida anche ingrandita
    static func immagineNitida(_ percorso: String, in misura: CGSize, scala: CGFloat) -> NSImage? {
        let scala = max(1, scala)
        let riquadro = (larghezza: vincolo(misura.width, scala), altezza: vincolo(misura.height, scala))
        guard riquadro.larghezza != nil || riquadro.altezza != nil else { return nil }
        let chiave = "\(percorso)#\(riquadro.larghezza ?? 0)x\(riquadro.altezza ?? 0)"
        if let pronta = cacheNitide[chiave] { return pronta }

        // La sorgente non va in cache: dopo la riduzione i 512 px non servono più
        guard let url = cartella?.appendingPathComponent(percorso),
              let originale = NSImage(contentsOf: url),
              let sorgente = originale.cgImage(forProposedRect: nil, context: nil, hints: nil),
              sorgente.width > 0, sorgente.height > 0 else { return nil }

        let fattore = min(riquadro.larghezza.map { CGFloat($0) / CGFloat(sorgente.width) } ?? .infinity,
                          riquadro.altezza.map { CGFloat($0) / CGFloat(sorgente.height) } ?? .infinity)
        let pixel = (larghezza: max(1, Int((CGFloat(sorgente.width) * fattore).rounded())),
                     altezza: max(1, Int((CGFloat(sorgente.height) * fattore).rounded())))
        guard let ridotta = riduci(sorgente, a: pixel) else { return nil }

        // Punti = pixel del riquadro / scala dello schermo (la riserva d'ingrandimento resta nei pixel)
        let punti = NSSize(width: CGFloat(pixel.larghezza) / scala, height: CGFloat(pixel.altezza) / scala)
        let immagine = NSImage(cgImage: ridotta, size: punti)
        immagine.cacheMode = .never

        if pixelInCache + pixel.larghezza * pixel.altezza > limitePixelCache {
            cacheNitide.removeAll()
            pixelInCache = 0
        }
        cacheNitide[chiave] = immagine
        pixelInCache += pixel.larghezza * pixel.altezza
        return immagine
    }

    private static func vincolo(_ punti: CGFloat, _ scala: CGFloat) -> Int? {
        guard punti.isFinite, punti >= 1 else { return nil }
        return max(1, Int((punti * scala).rounded()))
    }

    /// Riduzione a passi di al massimo 2:1: a ogni passo il filtro di CoreGraphics media tutti i pixel
    /// d'origine, qualunque sia il rapporto totale (512 → 44 px compreso), e nessuna linea viene saltata.
    /// L'ultimo passo normalizza sempre spazio colore (sRGB) e alfa (premoltiplicata) per Metal.
    private static func riduci(_ sorgente: CGImage, a pixel: (larghezza: Int, altezza: Int)) -> CGImage? {
        var corrente = sorgente
        while corrente.width > pixel.larghezza * 2 && corrente.height > pixel.altezza * 2 {
            guard let meta = disegna(corrente, larghezza: corrente.width / 2, altezza: corrente.height / 2) else { return nil }
            corrente = meta
        }
        return disegna(corrente, larghezza: pixel.larghezza, altezza: pixel.altezza)
    }

    private static func disegna(_ immagine: CGImage, larghezza: Int, altezza: Int) -> CGImage? {
        guard larghezza > 0, altezza > 0,
              let spazio = CGColorSpace(name: CGColorSpace.sRGB),
              let contesto = CGContext(data: nil, width: larghezza, height: altezza,
                                       bitsPerComponent: 8, bytesPerRow: 0, space: spazio,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                           | CGBitmapInfo.byteOrder32Big.rawValue)
        else { return nil }
        contesto.interpolationQuality = .high
        contesto.setShouldAntialias(true)
        contesto.draw(immagine, in: CGRect(x: 0, y: 0, width: larghezza, height: altezza))
        return contesto.makeImage()
    }
}

/// Immagine delle risorse disegnata già ridotta ai pixel dello schermo: nessuna riduzione sulla GPU.
/// Per icone e loghi (misure note). Per gli sfondi a tutta finestra resta `ImmagineRisorsa`.
struct ImmagineNitida: View {
    let percorso: String
    /// Spazio in punti; l'immagine vi si adatta mantenendo le proporzioni (`.infinity` = libero).
    let misura: CGSize
    /// Riserva per gli ingrandimenti animati (`scaleEffect`): 1,13 nel dock.
    var riservaIngrandimento: CGFloat = 1
    @Environment(\.displayScale) private var scala

    init(percorso: String, lato: CGFloat, riservaIngrandimento: CGFloat = 1) {
        self.percorso = percorso
        misura = CGSize(width: lato, height: lato)
        self.riservaIngrandimento = riservaIngrandimento
    }

    init(percorso: String, altezza: CGFloat) {
        self.percorso = percorso
        misura = CGSize(width: .infinity, height: altezza)
    }

    var body: some View {
        if let img = Risorse.immagineNitida(percorso, in: misura, scala: scala * riservaIngrandimento) {
            // Non resizable: SwiftUI la disegna ai suoi punti; la riserva d'ingrandimento (≤ 2:1)
            // è l'unica riduzione che resta a CoreAnimation, e il filtro lineare la fa bene
            Image(nsImage: img)
                .interpolation(.high)
                .frame(width: img.size.width, height: img.size.height)
        } else {
            Color.clear.frame(width: misura.width.isFinite ? misura.width : nil,
                              height: misura.height.isFinite ? misura.height : nil)
        }
    }
}

/// Immagine dalle risorse con ripiego trasparente se manca.
struct ImmagineRisorsa: View {
    let percorso: String
    var scala: CGFloat = 1

    var body: some View {
        if let img = Risorse.immagine(percorso, scala: scala) {
            // Riduzione di qualità: le icone a 512 pixel restano nitide anche piccole
            Image(nsImage: img).resizable().interpolation(.high).antialiased(true)
        } else {
            Color.clear
        }
    }
}
