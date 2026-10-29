import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Tipi comuni a Mac e iPhone/iPad
//
// Lo stesso codice compila per macOS (AppKit) e per iOS (UIKit). Qui stanno i soli nomi comuni che il resto
// dell'app usa al posto dei tipi NS*/UI*. Sul Mac ogni nome è esattamente il tipo o la chiamata AppKit di
// prima: il comportamento non cambia. Regola: sempre `#if os(macOS) … #elseif os(iOS) … #endif`, mai un
// `#else` nudo che sul Mac prenderebbe un'altra strada.

#if os(macOS)
/// Carattere della piattaforma (NSFont sul Mac, UIFont su iPhone e iPad).
typealias FontPiattaforma = NSFont
/// Colore della piattaforma (NSColor sul Mac, UIColor su iPhone e iPad).
typealias ColorePiattaforma = NSColor
/// Immagine della piattaforma (NSImage sul Mac, UIImage su iPhone e iPad).
typealias ImmaginePiattaforma = NSImage
#elseif os(iOS)
/// Carattere della piattaforma (NSFont sul Mac, UIFont su iPhone e iPad).
typealias FontPiattaforma = UIFont
/// Colore della piattaforma (NSColor sul Mac, UIColor su iPhone e iPad).
typealias ColorePiattaforma = UIColor
/// Immagine della piattaforma (NSImage sul Mac, UIImage su iPhone e iPad).
typealias ImmaginePiattaforma = UIImage
#endif

extension Image {
    /// Immagine SwiftUI da un'immagine della piattaforma (`Image(nsImage:)` sul Mac, `Image(uiImage:)` su iOS).
    init(piattaforma immagine: ImmaginePiattaforma) {
        #if os(macOS)
        self.init(nsImage: immagine)
        #elseif os(iOS)
        self.init(uiImage: immagine)
        #endif
    }
}

// MARK: - Stili dei controlli

extension View {
    /// Casella di spunta: `.checkbox` sul Mac, interruttore su iPhone e iPad (dove la casella non esiste).
    func stileCasella() -> some View {
        #if os(macOS)
        return self.toggleStyle(.checkbox)
        #elseif os(iOS)
        return self.toggleStyle(.switch)
        #endif
    }

    /// Campo della data: `.field` sul Mac, `.compact` su iPhone e iPad.
    func stileDataCampo() -> some View {
        #if os(macOS)
        return self.datePickerStyle(.field)
        #elseif os(iOS)
        return self.datePickerStyle(.compact)
        #endif
    }
}

// MARK: - Appunti

/// Appunti di sistema (NSPasteboard sul Mac, UIPasteboard su iPhone e iPad): solo testo.
enum Appunti {
    /// Mette il testo negli appunti al posto di quello che c'era.
    static func copia(_ testo: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(testo, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = testo
        #endif
    }

    /// Il testo negli appunti (nil se non c'è testo).
    static var testo: String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #elseif os(iOS)
        return UIPasteboard.general.string
        #endif
    }
}

// MARK: - Apertura di file e indirizzi

/// Apre un file o un indirizzo con l'app di sistema adatta.
enum ApriFile {
    /// Sul Mac `NSWorkspace.shared.open` (Anteprima, browser, Mail…), con lo stesso esito.
    /// Su iPhone e iPad apre gli indirizzi web e di posta con `UIApplication.open`; un file locale non si può
    /// passare a un'altra app così (servirà l'anteprima o la condivisione, giro 2) e il risultato è `false`.
    @discardableResult
    static func apri(_ url: URL) -> Bool {
        #if os(macOS)
        return NSWorkspace.shared.open(url)
        #elseif os(iOS)
        guard !url.isFileURL else { return false }
        Task { @MainActor in UIApplication.shared.open(url, options: [:], completionHandler: nil) }
        return true
        #endif
    }
}
