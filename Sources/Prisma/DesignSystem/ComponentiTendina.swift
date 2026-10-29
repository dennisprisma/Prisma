import AppKit
import SwiftUI

extension Tema.Misura.Componenti {
    /// Menu a tendina: alto come i pulsanti normali e i campi (32), margini della capsula.
    static let altezzaTendina: CGFloat = 32
    static let margineSinistroTendina: CGFloat = 14
    static let margineDestroTendina: CGFloat = 11
    static let spazioTendina: CGFloat = 8
}

extension Tema.Testo.Componenti {
    /// Le frecce su e giù a destra dell'etichetta del menu a tendina.
    static let frecciaTendina = Font.system(size: 9, weight: .bold)
}

/// Il menu a tendina di Prisma: l'etichetta è una capsula come i pulsanti del tema e il clic apre
/// il menu del Mac con la voce scelta spuntata, nella posizione del puntatore.
/// Al posto del `Picker` di sistema.
///
///     MenuTendina(selezione: $canale, opzioni: [(.alleanza, "Alleanza"), (.indipendente, "Indipendente")])
///     MenuTendina(selezione: $area, opzioni: AreaPosizione.allCases.map { ($0, $0.nome) }, stile: .carta, larghezza: 160)
struct MenuTendina<Valore: Hashable>: View {
    /// `vetro`: capsula di vetro chiaro (.btn); `carta`: pozzetto come i campi (.field);
    /// `scuro`: capsula di vetro più coprente, per i fondi scuri.
    enum Stile { case vetro, carta, scuro }

    @Binding var selezione: Valore
    let opzioni: [(Valore, String)]
    var stile: Stile = .vetro
    /// Larghezza fissa (nil: quanto serve all'etichetta più lunga, dentro lo spazio disponibile).
    var larghezza: CGFloat? = nil
    @Environment(\.isEnabled) private var attivo

    private var etichetta: String { opzioni.first { $0.0 == selezione }?.1 ?? "" }

    var body: some View {
        let m = Tema.Misura.Componenti.self
        Button(action: apri) {
            fondo(
                HStack(spacing: m.spazioTendina) {
                    Text(verbatim: etichetta)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: larghezza == nil ? nil : .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(Tema.Testo.Componenti.frecciaTendina)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
                .font(Tema.Testo.pulsante)
                .foregroundColor(Tema.Colore.inchiostro)
                .padding(.leading, m.margineSinistroTendina)
                .padding(.trailing, m.margineDestroTendina)
                .frame(width: larghezza)
                .frame(minHeight: m.altezzaTendina)
            )
            .contentShape(FormaVetro.capsula)
        }
        .buttonStyle(.plain)
        .opacity(attivo ? 1 : 0.5)
        .accessibilityLabel(etichetta)
    }

    @ViewBuilder private func fondo<V: View>(_ contenuto: V) -> some View {
        switch stile {
        case .vetro:
            // Come i pulsanti di vetro: pozzetto, filo e ombra corta, visibili anche sulle schede bianche
            contenuto.vetro(.chip, forma: .capsula, interattivo: true)
        case .scuro:
            contenuto.vetro(.chip, forma: .capsula, riempimento: Tema.Colore.chipSopra)
        case .carta:
            contenuto
                .background { FormaVetro.capsula.fill(Tema.Colore.pozzetto) }
                .overlay {
                    FormaVetro.capsula.strokeBorder(Tema.Colore.separatore, lineWidth: Tema.Misura.filo).allowsHitTesting(false)
                }
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
