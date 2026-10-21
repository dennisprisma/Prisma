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

    static func genera(in cartella: URL) -> Int32 {
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
            let renderer = ImageRenderer(content: vista)
            renderer.scale = 2
            guard let immagine = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: immagine).representation(using: .png, properties: [:]) else {
                print("ERRORE: istantanea \(scena.nome) non disegnata")
                return 1
            }
            do {
                try png.write(to: cartella.appendingPathComponent("\(scena.nome).png"))
                print("OK: \(scena.nome).png")
            } catch {
                print("ERRORE: \(scena.nome).png non salvata: \(error.localizedDescription)")
                return 1
            }
        }
        return 0
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
