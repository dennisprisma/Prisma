import AppKit
import SwiftUI

/// La presentazione all'incontro: le pagine di un documento a tutto schermo, una alla volta,
/// da sfogliare con le frecce mentre il cliente guarda. Si abbina alla modalità cliente.
struct Presentazione {
    let titolo: String
    let cliente: String
    let formato: CGSize
    let pagine: [AnyView]
    var pagina = 0
    /// La modalità cliente l'ha accesa la presentazione: all'uscita si spegne.
    var haAccesoModoCliente = false
    /// La finestra è passata a tutto schermo per la presentazione: all'uscita torna com'era.
    var haAccesoSchermoIntero = false
}

extension StatoShell {
    /// Mostra il documento a tutto schermo. Per un documento di un cliente accende anche la modalità cliente.
    func presenta(_ d: DocumentoStampabile, delCliente: Bool = true) {
        guard !d.pagine.isEmpty else { return }
        var p = Presentazione(titolo: d.titolo, cliente: d.cliente, formato: d.formato, pagine: d.pagine)
        if delCliente, !inModoCliente {
            entraModoCliente()
            p.haAccesoModoCliente = inModoCliente
        }
        if persistente, let finestra = NSApp.keyWindow, !finestra.styleMask.contains(.fullScreen) {
            finestra.toggleFullScreen(nil)
            p.haAccesoSchermoIntero = true
        }
        pannelloNotifiche = false
        presentazione = p
    }

    func paginaSeguente() {
        guard var p = presentazione, p.pagina < p.pagine.count - 1 else { return }
        p.pagina += 1
        presentazione = p
    }

    func paginaPrecedente() {
        guard var p = presentazione, p.pagina > 0 else { return }
        p.pagina -= 1
        presentazione = p
    }

    func chiudiPresentazione() {
        guard let p = presentazione else { return }
        presentazione = nil
        if p.haAccesoModoCliente { esciModoCliente() }
        if p.haAccesoSchermoIntero, let finestra = NSApp.keyWindow, finestra.styleMask.contains(.fullScreen) {
            finestra.toggleFullScreen(nil)
        }
    }
}

/// Il velo scuro con la pagina al centro, grande quanto lo schermo permette, e una barra discreta in basso.
struct VistaPresentazione: View {
    @EnvironmentObject var stato: StatoShell
    let p: Presentazione

    var body: some View {
        GeometryReader { geo in
            let spazio = CGSize(width: geo.size.width - Misure.Presentazione.margine * 2,
                                height: geo.size.height - Misure.Presentazione.margine * 2 - Misure.Presentazione.barra)
            let scala = max(0.1, min(spazio.width / p.formato.width, spazio.height / p.formato.height))
            ZStack {
                Colori.Presentazione.sfondo.ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer(minLength: Misure.Presentazione.margine)
                    p.pagine[min(p.pagina, p.pagine.count - 1)]
                        .frame(width: p.formato.width, height: p.formato.height)
                        .scaleEffect(scala)
                        .frame(width: p.formato.width * scala, height: p.formato.height * scala)
                        .shadow(color: Colori.Presentazione.ombra, radius: 24, y: 8)
                        .id(p.pagina)
                        .transition(.opacity)
                    Spacer(minLength: 0)
                    barra
                        .frame(height: Misure.Presentazione.barra)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // Un clic sulla pagina va avanti, come in Presentazioni
            .contentShape(Rectangle())
            .onTapGesture { stato.paginaSeguente() }
        }
    }

    private var barra: some View {
        HStack(spacing: 16) {
            Text("\(p.titolo) · \(p.cliente)").lineLimit(1)
            Spacer()
            Button("←") { stato.paginaPrecedente() }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(p.pagina == 0)
            Text("\(p.pagina + 1) / \(p.pagine.count)").monospacedDigit()
            Button("→") { stato.paginaSeguente() }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(p.pagina >= p.pagine.count - 1)
            // Spazio e Invio vanno avanti, come in Keynote
            Button("") { stato.paginaSeguente() }.keyboardShortcut(.space, modifiers: []).frame(width: 0).opacity(0)
            Button("") { stato.paginaSeguente() }.keyboardShortcut(.return, modifiers: []).frame(width: 0).opacity(0)
            Button("Esci  esc") { stato.chiudiPresentazione() }
                .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(StileSemplice())
        .font(Tipo.barraOra)
        .foregroundColor(Colori.Presentazione.testo)
        .padding(.horizontal, Misure.Presentazione.margine)
    }
}
