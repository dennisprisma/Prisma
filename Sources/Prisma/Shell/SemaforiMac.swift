#if os(macOS)
import AppKit
#endif
import SwiftUI

// Le misure (spazioDopoSemafori, bordoSemaforiTipico) stanno in DesignSystem/TemaShell.swift.

/// Dove sono i tre pulsanti veri della finestra del Mac, nelle coordinate della vista che li legge
/// (origine in alto a sinistra: quella della barra superiore).
struct PosizioneSemafori: Equatable {
    /// Bordo destro del pulsante più a destra (il verde).
    var bordoDestro: CGFloat
    /// Centro verticale dei pulsanti.
    var centroVerticale: CGFloat
}

// Da qui in poi solo Mac (AppKit): su iPhone e iPad i pulsanti della finestra non ci sono e la barra resta senza.
#if os(macOS)

/// Vista invisibile, da mettere dietro la barra superiore: legge dove AppKit ha messo i pulsanti della
/// finestra e lo dice alla barra (`nil` se non ci sono: schermo intero, finestra senza pulsanti).
/// Si aggiorna quando i pulsanti si spostano, quando la finestra cambia misura, schermo o modo
/// (schermo intero) e quando la vista passa a un'altra finestra.
struct LettoreSemafori: NSViewRepresentable {
    let cambiata: (PosizioneSemafori?) -> Void

    final class Vista: NSView {
        var cambiata: ((PosizioneSemafori?) -> Void)?
        /// L'ultima posizione detta alla barra (per non ripeterla).
        private var ultima: PosizioneSemafori?
        private var detta = false
        /// I pulsanti osservati (per smettere quando la vista cambia finestra).
        private var osservati: [NSView] = []
        private weak var finestraOsservata: NSWindow?

        // Coordinate dall'alto, come SwiftUI
        override var isFlipped: Bool { true }

        // Non prende mai il mouse: sopra c'è la zona che trascina la finestra
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            smettiDiOsservare()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let w = window else { return }
            osserva(w)
            misura()
            // La barra del titolo può impaginarsi dopo: si rilegge al giro successivo
            rileggiTraPoco()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            misura()
        }

        override func setFrameOrigin(_ newOrigin: NSPoint) {
            super.setFrameOrigin(newOrigin)
            misura()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        private func osserva(_ w: NSWindow) {
            let centro = NotificationCenter.default
            let nomi: [Notification.Name] = [
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didChangeScreenNotification,
                NSWindow.didChangeBackingPropertiesNotification
            ]
            for nome in nomi {
                centro.addObserver(self, selector: #selector(cambiato(_:)), name: nome, object: w)
            }
            finestraOsservata = w
            // I pulsanti si spostano anche da soli (la barra del titolo si reimpagina): si seguono le loro cornici
            for bottone in pulsanti(di: w) {
                bottone.postsFrameChangedNotifications = true
                centro.addObserver(self, selector: #selector(cambiato(_:)), name: NSView.frameDidChangeNotification, object: bottone)
                osservati.append(bottone)
            }
        }

        private func smettiDiOsservare() {
            let centro = NotificationCenter.default
            if let w = finestraOsservata {
                centro.removeObserver(self, name: nil, object: w)
            }
            for bottone in osservati {
                centro.removeObserver(self, name: NSView.frameDidChangeNotification, object: bottone)
            }
            osservati = []
            finestraOsservata = nil
        }

        @objc private func cambiato(_ nota: Notification) {
            misura()
            // Entrando o uscendo dallo schermo intero AppKit rimette i pulsanti un attimo dopo
            rileggiTraPoco()
        }

        /// Rilegge al giro successivo del run loop (anche mentre si ridimensiona la finestra).
        private func rileggiTraPoco() {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(rileggi), object: nil)
            perform(#selector(rileggi), with: nil, afterDelay: 0, inModes: [.common])
        }

        @objc private func rileggi() {
            misura()
        }

        /// I pulsanti visibili della finestra, da sinistra: chiudi, riduci, ingrandisci.
        private func pulsanti(di w: NSWindow) -> [NSButton] {
            let tipi: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            return tipi.compactMap { w.standardWindowButton($0) }
        }

        /// Legge la posizione dei pulsanti e, se è cambiata, la dice alla barra (sempre al giro dopo:
        /// mai durante un aggiornamento delle viste).
        private func misura() {
            let nuova = posizione()
            if detta && nuova == ultima { return }
            detta = true
            ultima = nuova
            let avvisa = cambiata
            DispatchQueue.main.async { avvisa?(nuova) }
        }

        private func posizione() -> PosizioneSemafori? {
            guard let w = window, !w.styleMask.contains(.fullScreen) else { return nil }
            let visibili = pulsanti(di: w).filter { b in
                !b.isHiddenOrHasHiddenAncestor && b.alphaValue > 0 && b.window === w
            }
            guard !visibili.isEmpty else { return nil }
            var unione = CGRect.null
            for b in visibili {
                unione = unione.union(b.convert(b.bounds, to: self))
            }
            guard !unione.isNull, unione.width > 0, unione.height > 0 else { return nil }
            return PosizioneSemafori(bordoDestro: unione.maxX, centroVerticale: unione.midY)
        }
    }

    func makeNSView(context: Context) -> Vista {
        let v = Vista()
        v.cambiata = cambiata
        return v
    }

    func updateNSView(_ nsView: Vista, context: Context) {
        nsView.cambiata = cambiata
    }
}
#endif
