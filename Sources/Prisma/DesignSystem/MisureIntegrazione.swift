import SwiftUI

// Misure aggiunte nell'integrazione del giro 1 (grafica e impaginazione che si adatta alla finestra).

extension Misure.SchedaProdotto {
    /// Larghezza sotto cui, nella scheda di un prodotto, Condizioni e Fonte vanno una sotto l'altra
    /// (etichetta del rischio 150 + scala SRI + margini del pannello, spazio 28, Fonte almeno 200).
    static let affiancate: CGFloat = 620
    /// Spazio tra Condizioni e Fonte quando stanno affiancate e quando vanno una sotto l'altra.
    static let spazioAffiancate: CGFloat = 28
    static let spazioImpilate: CGFloat = 16
}
