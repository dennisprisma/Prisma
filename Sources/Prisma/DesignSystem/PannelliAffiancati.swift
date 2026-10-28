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

    var body: some View {
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
    }
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
