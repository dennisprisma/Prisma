import AppKit
import Foundation

/// Accesso alle risorse dell'app (icone, ecc.).
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

    static func icona(_ nome: String) -> NSImage? {
        guard let url = cartella?.appendingPathComponent("Icone/\(nome).png") else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Usato dal workflow di build (`Prisma --verifica-risorse`) per
    /// controllare che le risorse vengano davvero trovate a runtime.
    static func verifica() -> Int32 {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent(nomeBundle),
              FileManager.default.fileExists(atPath: url.path) else {
            print("ERRORE: \(nomeBundle) non trovato in Contents/Resources")
            return 1
        }
        guard icona("Prisma") != nil else {
            print("ERRORE: icona Prisma non caricabile dal bundle \(bundle.bundlePath)")
            return 1
        }
        print("OK: risorse trovate in \(bundle.bundlePath)")
        return 0
    }
}
