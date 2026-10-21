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
        print("OK: risorse trovate in \(bundle.bundlePath)")
        return 0
    }
}

/// Immagine dalle risorse con ripiego trasparente se manca.
struct ImmagineRisorsa: View {
    let percorso: String
    var scala: CGFloat = 1

    var body: some View {
        if let img = Risorse.immagine(percorso, scala: scala) {
            Image(nsImage: img).resizable()
        } else {
            Color.clear
        }
    }
}
