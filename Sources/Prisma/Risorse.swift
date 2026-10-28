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
        // Icona della Scrivania nel dock, base e riflesso dell'icona Agenda, simbolo Alleanza delle etichette.
        let necessarie = ["Icone/Prisma.png", "Icone/Agenda_base.png", "Icone/Agenda_vetro.png",
                          "Loghi/Alleanza_simbolo.png"]
        for p in necessarie where immagine(p) == nil {
            print("ERRORE: \(p) non caricabile dal bundle \(bundle.bundlePath)")
            return 1
        }
        for app in AppPrisma.allCases where icona(app.icona) == nil {
            print("ERRORE: icona \(app.icona) mancante")
            return 1
        }
        // Le icone ridotte ai pixel di uno schermo Retina con il dock ingrandito (fino a 1,55 volte) devono uscire intere
        let latoIcona = Tema.Misura.dockIcona
        let ingrandimento = Tema.Misura.dockIngrandimento
        let latoDock = CGSize(width: latoIcona, height: latoIcona)
        let pixelAttesi = Int((latoIcona * 2 * ingrandimento).rounded())
        for app in AppPrisma.allCases {
            // La bitmap vera (cgImage(forProposedRect:) ridisegnerebbe l'immagine ai punti dello schermo del server)
            guard let img = immagineNitida("Icone/\(app.icona).png", in: latoDock, scala: 2 * ingrandimento),
                  let rep = img.representations.first,
                  rep.pixelsWide == pixelAttesi, rep.pixelsHigh == pixelAttesi,
                  abs(img.size.width - latoIcona) < 0.5 else {
                let trovato = immagineNitida("Icone/\(app.icona).png", in: latoDock, scala: 2 * ingrandimento)
                print("ERRORE: icona \(app.icona) non ridotta ai pixel dello schermo (attesi \(pixelAttesi) px, trovati \(trovato?.representations.first?.pixelsWide ?? -1) px, \(trovato?.size.width ?? -1) pt)")
                return 1
            }
        }
        if immagineNitida("Loghi/Alleanza_simbolo.png", in: CGSize(width: CGFloat.infinity, height: 15), scala: 2) == nil {
            print("ERRORE: logo Alleanza non ridotto")
            return 1
        }
        print("OK: risorse trovate in \(bundle.bundlePath)")
        return 0
    }
}

extension Risorse {
    /// Un'immagine già ridotta, i suoi pixel e quando è servita l'ultima volta.
    private struct VoceNitida {
        let immagine: NSImage
        let pixel: Int
        var uso: Int
    }

    /// Un'immagine da preparare fuori dal thread principale.
    private struct LavoroNitido {
        let chiave: String
        let percorso: String
        let larghezza: Int?
        let altezza: Int?
        let scala: CGFloat
    }

    /// Immagini già ridotte ai pixel dello schermo: chiave "percorso#LxA" (pixel del riquadro richiesto).
    /// Solo dal thread principale (SwiftUI valuta i body lì).
    private static var cacheNitide: [String: VoceNitida] = [:]
    private static var pixelInCache = 0
    private static var orologioUso = 0
    /// Oltre questo budget (≈ 12 MB a 4 byte per pixel) si tolgono le immagini usate meno di recente: il Mac ha 8 GB.
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
        let larghezza = vincolo(misura.width, scala)
        let altezza = vincolo(misura.height, scala)
        guard larghezza != nil || altezza != nil else { return nil }
        let chiave = chiaveNitida(percorso, larghezza: larghezza, altezza: altezza)
        if var voce = cacheNitide[chiave] {
            orologioUso += 1
            voce.uso = orologioUso
            cacheNitide[chiave] = voce
            return voce.immagine
        }
        guard let ridotta = riduzione(percorso, larghezza: larghezza, altezza: altezza) else { return nil }
        let immagine = nitida(ridotta, scala: scala)
        metti(immagine, pixel: ridotta.width * ridotta.height, chiave: chiave)
        return immagine
    }

    /// Prepara fuori dal thread principale le immagini che si disegneranno presto (dock, finestre, «app aperte»):
    /// stessi argomenti di `immagineNitida`. Si chiama dal thread principale; le immagini entrano nella cache
    /// sul thread principale, solo se nel frattempo non ci sono già.
    static func preparaNitide(_ richieste: [(percorso: String, misura: CGSize, scala: CGFloat)]) {
        var lavori: [LavoroNitido] = []
        var viste = Set<String>()
        for r in richieste {
            let scala = max(1, r.scala)
            let larghezza = vincolo(r.misura.width, scala)
            let altezza = vincolo(r.misura.height, scala)
            guard larghezza != nil || altezza != nil else { continue }
            let chiave = chiaveNitida(r.percorso, larghezza: larghezza, altezza: altezza)
            guard cacheNitide[chiave] == nil, viste.insert(chiave).inserted else { continue }
            lavori.append(LavoroNitido(chiave: chiave, percorso: r.percorso, larghezza: larghezza, altezza: altezza, scala: scala))
        }
        guard !lavori.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async {
            var pronte: [(chiave: String, ridotta: CGImage, scala: CGFloat)] = []
            for l in lavori {
                // Un pool per immagine: GCD svuota il suo solo alla fine del blocco (i PNG decodificati sono da 512 px)
                autoreleasepool {
                    guard let ridotta = Risorse.riduzione(l.percorso, larghezza: l.larghezza, altezza: l.altezza) else { return }
                    pronte.append((chiave: l.chiave, ridotta: ridotta, scala: l.scala))
                }
            }
            DispatchQueue.main.async {
                for p in pronte where Risorse.cacheNitide[p.chiave] == nil {
                    Risorse.metti(Risorse.nitida(p.ridotta, scala: p.scala), pixel: p.ridotta.width * p.ridotta.height,
                                  chiave: p.chiave)
                }
            }
        }
    }

    private static func chiaveNitida(_ percorso: String, larghezza: Int?, altezza: Int?) -> String {
        "\(percorso)#\(larghezza ?? 0)x\(altezza ?? 0)"
    }

    /// Decodifica e riduzione ai pixel del riquadro: niente stato condiviso, va bene anche fuori dal thread principale.
    /// La sorgente non va in cache: dopo la riduzione i 512 px non servono più.
    private static func riduzione(_ percorso: String, larghezza: Int?, altezza: Int?) -> CGImage? {
        guard let url = cartella?.appendingPathComponent(percorso),
              let originale = NSImage(contentsOf: url),
              let sorgente = originale.cgImage(forProposedRect: nil, context: nil, hints: nil),
              sorgente.width > 0, sorgente.height > 0 else { return nil }

        let fattore = min(larghezza.map { CGFloat($0) / CGFloat(sorgente.width) } ?? .infinity,
                          altezza.map { CGFloat($0) / CGFloat(sorgente.height) } ?? .infinity)
        let pixel = (larghezza: max(1, Int((CGFloat(sorgente.width) * fattore).rounded())),
                     altezza: max(1, Int((CGFloat(sorgente.height) * fattore).rounded())))
        return riduci(sorgente, a: pixel)
    }

    /// Punti = pixel del riquadro / scala dello schermo (la riserva d'ingrandimento resta nei pixel).
    /// Rappresentazione bitmap esplicita: NSImage(cgImage:size:) dichiara i pixel pari ai punti
    /// e perderebbe la densità; la bitmap invece porta i 118 px veri sotto i 52 pt.
    private static func nitida(_ ridotta: CGImage, scala: CGFloat) -> NSImage {
        let punti = NSSize(width: CGFloat(ridotta.width) / scala, height: CGFloat(ridotta.height) / scala)
        let bitmap = NSBitmapImageRep(cgImage: ridotta)
        bitmap.size = punti
        let immagine = NSImage(size: punti)
        immagine.addRepresentation(bitmap)
        immagine.cacheMode = .never
        return immagine
    }

    /// Mette in cache; oltre il budget toglie le immagini usate meno di recente, mai tutta la cache in un colpo.
    private static func metti(_ immagine: NSImage, pixel: Int, chiave: String) {
        while pixelInCache + pixel > limitePixelCache,
              let vecchia = cacheNitide.min(by: { $0.value.uso < $1.value.uso }) {
            pixelInCache -= vecchia.value.pixel
            cacheNitide.removeValue(forKey: vecchia.key)
        }
        orologioUso += 1
        cacheNitide[chiave] = VoceNitida(immagine: immagine, pixel: pixel, uso: orologioUso)
        pixelInCache += pixel
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
    /// Riserva per gli ingrandimenti animati (`scaleEffect`): 1,55 nel dock.
    var riservaIngrandimento: CGFloat = 1
    @Environment(\.displayScale) private var scala

    init(percorso: String, lato: CGFloat, riservaIngrandimento: CGFloat = 1) {
        self.percorso = percorso
        misura = CGSize(width: lato, height: lato)
        self.riservaIngrandimento = riservaIngrandimento
    }

    init(percorso: String, altezza: CGFloat) {
        self.percorso = percorso
        misura = CGSize(width: CGFloat.infinity, height: altezza)
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
