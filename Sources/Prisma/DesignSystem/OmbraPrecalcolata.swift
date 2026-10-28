import AppKit
import SwiftUI

// Ombre delle finestre già sfocate in una bitmap a 9 fette, con il buco della forma ritagliato («mai sotto il vetro»).
// Si disegnano una volta con CoreGraphics per (raggio, strati, scala) e poi si stirano: aprire, spostare, scalare
// o cambiare finestra attiva costa quanto un'immagine, senza sfocature né maschere fuori schermo a ogni fotogramma.

extension Tema.Ombra {
    /// Fin dove si disegna la sfocatura, in multipli della sfocatura CSS: 1,25 = 2,5 σ (oltre resta meno dello 0,3 %).
    static let estensionePrecalcolata: CGFloat = 1.25
    /// Sfocatura di CoreGraphics per un punto di sfocatura CSS (CG blur ≈ CSS blur, come il raggio/2 di SwiftUI).
    static let fattoreSfocaturaPrecalcolata: CGFloat = 1
    /// Ombre tenute in memoria (attiva e inattiva, normale e ingrandita, 1x e 2x): oltre si ricomincia.
    static let limitePrecalcolate = 12
}

/// Le bitmap delle ombre. Solo dal thread principale (SwiftUI valuta i body lì).
enum OmbraPrecalcolata {
    /// L'immagine e dove tagliarla: `margine` = quanto esce dalla forma, `bordo` = lato delle fette d'angolo.
    struct Pronta {
        let immagine: NSImage
        let margine: CGFloat
        let bordo: CGFloat
    }

    private static var cache: [String: Pronta] = [:]

    static func ombra(raggio: CGFloat, strati: [StratoOmbra], scala: CGFloat) -> Pronta? {
        let scala = max(1, scala)
        let voce = chiave(raggio: raggio, strati: strati, scala: scala)
        if let pronta = cache[voce] { return pronta }
        guard let pronta = disegna(raggio: raggio, strati: strati, scala: scala) else { return nil }
        if cache.count >= Tema.Ombra.limitePrecalcolate { cache.removeAll() }
        cache[voce] = pronta
        return pronta
    }

    private static func chiave(raggio: CGFloat, strati: [StratoOmbra], scala: CGFloat) -> String {
        var parti = ["\(raggio)@\(scala)"]
        for s in strati {
            let c = NSColor(s.colore).usingColorSpace(.sRGB) ?? NSColor.black
            let colore = [c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent].map { "\($0)" }
            parti.append("\(s.y),\(s.sfocatura),\(s.espansione)," + colore.joined(separator: ","))
        }
        return parti.joined(separator: "|")
    }

    /// La forma al centro è grande abbastanza perché a metà di ogni lato l'ombra sia quella di un lato lungo:
    /// le fette d'angolo (`bordo`) contengono tutto ciò che dipende dagli angoli, il centro (2 pt) si stira.
    private static func disegna(raggio: CGFloat, strati: [StratoOmbra], scala: CGFloat) -> Pronta? {
        guard !strati.isEmpty else { return nil }
        var margine: CGFloat = 0
        var interno = max(0, raggio)
        for s in strati {
            let estensione = s.sfocatura * Tema.Ombra.estensionePrecalcolata
            let rientro = max(0, -s.espansione)
            margine = max(margine, estensione + abs(s.y))
            interno = max(interno, estensione + rientro + abs(s.y) + max(0, raggio - rientro))
        }
        margine = margine.rounded(.up)
        interno = interno.rounded(.up)
        let bordo = margine + interno
        let lato = 2 * bordo + 2
        let pixel = Int((lato * scala).rounded(.up))
        guard pixel > 0, let spazio = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: pixel, height: pixel, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: spazio, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                      | CGBitmapInfo.byteOrder32Big.rawValue)
        else { return nil }
        // Tutto in pixel: offset e sfocatura delle ombre di CoreGraphics non seguono la trasformazione corrente
        let forma = CGRect(x: margine * scala, y: margine * scala,
                           width: (lato - 2 * margine) * scala, height: (lato - 2 * margine) * scala)
        ctx.setFillColor(NSColor.black.cgColor)
        for s in strati {
            // Come OmbreVetro: la forma rientra di -espansione (anche negli angoli) e l'ombra cade sotto di y
            let rientro = max(0, -s.espansione)
            let r = forma.insetBy(dx: rientro * scala, dy: rientro * scala)
            guard r.width > 0, r.height > 0 else { continue }
            let colore = NSColor(s.colore).usingColorSpace(.sRGB)?.cgColor ?? NSColor(s.colore).cgColor
            ctx.saveGState()
            // L'asse y di CoreGraphics va in su: l'ombra «in giù» di SwiftUI ha l'offset negativo
            ctx.setShadow(offset: CGSize(width: 0, height: -s.y * scala),
                          blur: s.sfocatura * Tema.Ombra.fattoreSfocaturaPrecalcolata * scala, color: colore)
            ctx.addPath(percorso(r, raggio: max(0, raggio - rientro) * scala))
            ctx.fillPath()
            ctx.restoreGState()
        }
        // Il buco: sotto il vetro nessuna ombra (toglie anche il nero delle forme, che stanno tutte dentro)
        ctx.setBlendMode(.clear)
        ctx.addPath(percorso(forma, raggio: raggio * scala))
        ctx.fillPath()
        guard let cg = ctx.makeImage() else { return nil }
        let punti = NSSize(width: CGFloat(pixel) / scala, height: CGFloat(pixel) / scala)
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = punti
        let immagine = NSImage(size: punti)
        immagine.addRepresentation(rep)
        return Pronta(immagine: immagine, margine: margine, bordo: bordo)
    }

    /// Lo stesso rettangolo ad angoli continui di FormaVetro (simmetrico: l'asse y capovolto non conta).
    private static func percorso(_ r: CGRect, raggio: CGFloat) -> CGPath {
        RoundedRectangle(cornerRadius: raggio, style: .continuous).path(in: r).cgPath
    }
}

/// Al posto di OmbreVetro per le finestre: la bitmap pronta, stirata alla misura della finestra.
struct OmbraVetroPronta: View {
    let raggio: CGFloat
    let strati: [StratoOmbra]
    @Environment(\.displayScale) private var scala

    var body: some View {
        if let pronta = OmbraPrecalcolata.ombra(raggio: raggio, strati: strati, scala: scala) {
            let b = pronta.bordo
            Image(nsImage: pronta.immagine)
                .resizable(capInsets: EdgeInsets(top: b, leading: b, bottom: b, trailing: b), resizingMode: .stretch)
                .padding(-pronta.margine)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
