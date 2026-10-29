import SwiftUI

// MARK: - Colonne affiancate dentro la cornice degli strumenti

/// Filo verticale tra due colonne dello stesso contenitore (come tra rubrica e dossier in Clienti).
struct DivisoreColonne: View {
    var body: some View {
        Rectangle()
            .fill(Colori.ColonneStrumento.divisore)
            .frame(width: Misure.ColonneStrumento.filo)
            .frame(maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

/// Due colonne nello stesso contenitore in vetro: una a larghezza fissa (ipotesi, elenco, comandi)
/// e una che prende il resto (risultati, dettaglio), separate da un filo sottile.
/// Le colonne sono alte quanto il contenitore: testate e piedi si allineano tra loro.
struct ColonneAffiancate<Fissa: View, Flessibile: View>: View {
    enum Lato { case sinistra, destra }

    var larghezza: CGFloat = Misure.ColonneStrumento.elenco
    var lato: Lato = .sinistra
    @ViewBuilder let fissa: () -> Fissa
    @ViewBuilder let flessibile: () -> Flessibile
    #if os(iOS)
    @Environment(\.larghezzaApp) private var larghezzaApp
    #endif

    var body: some View {
        #if os(iOS)
        // iPad: la colonna fissa si stringe fino a `colonnaMinima` perché l'altra resti leggibile; se non basta
        // ancora, le due colonne vanno una sotto l'altra
        if let l = larghezzaApp {
            if let f = ImpaginazioneMobile.larghezzaFissa(disponibile: l, ideale: larghezza) {
                affiancate(f, resto: l - f - Misure.ColonneStrumento.filo)
            } else {
                impilate
            }
        } else {
            affiancate(larghezza, resto: nil)
        }
        #elseif os(macOS)
        HStack(spacing: 0) {
            if lato == .sinistra {
                fissa().colonnaFissa(larghezza)
                DivisoreColonne()
                flessibile().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                flessibile().frame(maxWidth: .infinity, maxHeight: .infinity)
                DivisoreColonne()
                fissa().colonnaFissa(larghezza)
            }
        }
        #endif
    }

    #if os(iOS)
    private func affiancate(_ f: CGFloat, resto: CGFloat?) -> some View {
        HStack(spacing: 0) {
            if lato == .sinistra {
                fissa().colonnaFissa(f)
                DivisoreColonne()
                flessibile().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.larghezzaApp, resto)
            } else {
                flessibile().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.larghezzaApp, resto)
                DivisoreColonne()
                fissa().colonnaFissa(f)
            }
        }
    }

    /// Una sotto l'altra: la colonna fissa (ipotesi, elenco) prende al più `quotaColonnaImpilata` dell'altezza,
    /// sopra se stava a sinistra, sotto se stava a destra.
    private var impilate: some View {
        GeometryReader { g in
            let l = g.size.width
            let alta = (g.size.height * Tema.Misura.Mobile.quotaColonnaImpilata).rounded()
            VStack(spacing: 0) {
                if lato == .sinistra {
                    fissa().frame(width: l, height: alta, alignment: .top)
                    filo
                    flessibile().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    flessibile().frame(maxWidth: .infinity, maxHeight: .infinity)
                    filo
                    fissa().frame(width: l, height: alta, alignment: .top)
                }
            }
            .environment(\.larghezzaApp, l)
            .frame(width: g.size.width, height: g.size.height)
        }
    }

    private var filo: some View {
        Rectangle()
            .fill(Colori.ColonneStrumento.divisore)
            .frame(height: Misure.ColonneStrumento.filo)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
    }
    #endif
}

extension View {
    /// Colonna a larghezza fissa, alta quanto il contenitore, con il contenuto in alto.
    func colonnaFissa(_ larghezza: CGFloat = Misure.ColonneStrumento.elenco) -> some View {
        frame(width: larghezza)
            .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Testata di una colonna (Dati e ipotesi, ricerca dell'elenco, barra del simulatore): alta quanto le schede
    /// dei risultati, con il filo sotto, così i fili delle colonne vicine stanno sulla stessa riga.
    func testataColonna() -> some View {
        padding(.horizontal, Misure.ColonneStrumento.margine)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Misure.ColonneStrumento.testata)
            .bordoBasso(Colori.ColonneStrumento.divisore)
    }

    /// Piede di una colonna (Confermati con il cliente, Ipotesi da verificare): dentro il contenitore,
    /// alla stessa altezza in tutte le colonne, fondo leggero e filo sopra.
    func piedeColonna() -> some View {
        padding(.horizontal, Misure.ColonneStrumento.margine)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Misure.ColonneStrumento.piede)
            .background(Colori.ColonneStrumento.piede)
            .bordoAlto(Colori.ColonneStrumento.divisore)
    }
}

#if os(iOS)
/// I calcoli dell'impaginazione dell'iPad.
enum ImpaginazioneMobile {
    /// La larghezza di una colonna fissa (ideale quella del Mac) che lascia all'altra almeno `flessibileMinima`,
    /// stretta al più fino a `colonnaMinima`; nil se nemmeno così c'è posto (le colonne vanno impilate).
    static func larghezzaFissa(disponibile l: CGFloat, ideale: CGFloat) -> CGFloat? {
        let M = Tema.Misura.Mobile.self
        let massima = l - Misure.ColonneStrumento.filo - M.flessibileMinima
        let minima = min(ideale, M.colonnaMinima)
        guard massima >= minima else { return nil }
        return min(ideale, massima)
    }
}

private struct ColonnaFissaAdattiva: ViewModifier {
    let ideale: CGFloat
    @Environment(\.larghezzaApp) private var larghezzaApp

    func body(content: Content) -> some View {
        let l = larghezzaApp.map {
            ImpaginazioneMobile.larghezzaFissa(disponibile: $0, ideale: ideale) ?? min(ideale, Tema.Misura.Mobile.colonnaMinima)
        } ?? ideale
        content.colonnaFissa(l)
    }
}
#endif

extension View {
    /// Una colonna fissa accanto al contenuto (il dettaglio di Obiettivi): sul Mac `colonnaFissa`, come prima;
    /// sull'iPad si stringe fino a `colonnaMinima` perché l'altra colonna resti leggibile.
    @ViewBuilder
    func colonnaFissaAdattiva(_ ideale: CGFloat) -> some View {
        #if os(iOS)
        modifier(ColonnaFissaAdattiva(ideale: ideale))
        #elseif os(macOS)
        colonnaFissa(ideale)
        #endif
    }
}
