import AppKit
import SwiftUI

/// Il menu a tendina di Prisma (.os-select del template): l'etichetta è disegnata come i pulsanti
/// e il clic apre il menu del Mac con la voce scelta spuntata, nella posizione del puntatore.
/// Al posto del `Picker` di sistema, che sullo stile iOS 5 stona.
///
///     MenuTendina(selezione: $canale, opzioni: [(.alleanza, "Alleanza"), (.indipendente, "Indipendente")])
///     MenuTendina(selezione: $area, opzioni: AreaPosizione.allCases.map { ($0, $0.nome) }, stile: .carta, larghezza: 160)
struct MenuTendina<Valore: Hashable>: View {
    enum Stile { case vetro, carta, scuro }

    @Binding var selezione: Valore
    let opzioni: [(Valore, String)]
    var stile: Stile = .vetro
    /// Larghezza fissa (nil: quanto serve all'etichetta più lunga, dentro lo spazio disponibile).
    var larghezza: CGFloat? = nil
    @Environment(\.isEnabled) private var attivo

    private var etichetta: String { opzioni.first { $0.0 == selezione }?.1 ?? "" }

    var body: some View {
        Button(action: apri) {
            HStack(spacing: Misure.Tendina.spazio) {
                Text(verbatim: etichetta)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: larghezza == nil ? nil : .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: Misure.Tendina.freccia, weight: .bold))
                    .foregroundColor(stile == .scuro ? Colori.Tendina.scuroFreccia : Colori.Tendina.freccia)
            }
            .font(Tipo.pulsanteVetro)
            .foregroundColor(testo)
            .padding(Misure.Tendina.margine)
            .frame(width: larghezza, height: Misure.Tendina.altezza)
            .background(fondo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(attivo ? 1 : 0.5)
        .accessibilityLabel(etichetta)
    }

    private var testo: Color {
        switch stile {
        case .vetro: return Colori.Pulsante.testo
        case .carta: return Colori.Tendina.cartaTesto
        case .scuro: return Colori.Tendina.scuroTesto
        }
    }

    @ViewBuilder private var fondo: some View {
        let forma = RoundedRectangle(cornerRadius: Misure.Tendina.raggio)
        switch stile {
        case .vetro:
            forma.fill(Gradienti.vetro)
                .luceInterna(.white, raggio: Misure.Tendina.raggio)
                .overlay(forma.strokeBorder(Colori.Pulsante.vetroBordo, lineWidth: 1))
                .ombraCSS(Colori.Pulsante.vetroOmbra, y: 1, sfocatura: 2)
        case .carta:
            forma.fill(Colori.Tendina.cartaFondo)
                .overlay(forma.strokeBorder(Colori.Tendina.cartaBordo, lineWidth: 1))
        case .scuro:
            forma.fill(Colori.Tendina.scuroFondo)
                .overlay(forma.strokeBorder(Colori.Tendina.scuroBordo, lineWidth: 1))
        }
    }

    /// Il menu del Mac: modale finché non si sceglie, quindi il bersaglio delle voci vive abbastanza.
    private func apri() {
        let menu = NSMenu()
        let bersaglio = BersaglioMenu { i in if i < opzioni.count { selezione = opzioni[i].0 } }
        var scelta: NSMenuItem?
        for (i, o) in opzioni.enumerated() {
            let voce = NSMenuItem(title: o.1, action: #selector(BersaglioMenu.scegli(_:)), keyEquivalent: "")
            voce.target = bersaglio
            voce.tag = i
            voce.state = o.0 == selezione ? .on : .off
            if o.0 == selezione { scelta = voce }
            menu.addItem(voce)
        }
        withExtendedLifetime(bersaglio) {
            menu.popUp(positioning: scelta, at: NSEvent.mouseLocation, in: nil)
        }
    }
}

private final class BersaglioMenu: NSObject {
    let scelto: (Int) -> Void
    init(_ scelto: @escaping (Int) -> Void) { self.scelto = scelto }
    @objc func scegli(_ voce: NSMenuItem) { scelto(voce.tag) }
}
