import SwiftUI

// MARK: - Gettoni del seguito delle proposte (giro 3, specifica 5)
// Modulo e riquadro dell'esito, pannello «Proposte da riprendere» del Portafoglio, riga del widget.

extension Misure {
    enum Seguito {
        /// Il modulo dell'esito (sheet).
        static let modulo = CGSize(width: 520, height: 560)
        static let spazio: CGFloat = 10
        /// Tra l'etichetta e il campo nella versione compatta.
        static let spazioCampo: CGFloat = 4
        static let margineRiquadro = EdgeInsets(top: 10, leading: 11, bottom: 10, trailing: 11)
        static let campoEuro: CGFloat = 120
        static let colonnaGiorni: CGFloat = 92
        static let colonnaValore: CGFloat = 110
        static let pulsante = EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)
        /// Righe del pannello del Portafoglio prima di «…e altre N».
        static let righePortafoglio = 12
    }
}

extension Colori {
    /// Solo alias dei colori del tema: niente valori nuovi.
    enum Seguito {
        static let fondoRichiesta = Tema.Colore.fondoProposta
        static let testoRichiesta = Tema.Colore.testoProposta
        static let ferma = Tema.Colore.scadenzaVicina
        static let urgente = Tema.Colore.scadenzaOra
        static let bloccante = Colori.Analisi.erroreTesto
        static let avviso = Colori.Analisi.attenzioneTesto
    }
}
