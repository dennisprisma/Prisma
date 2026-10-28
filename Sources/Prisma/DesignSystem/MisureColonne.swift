import SwiftUI

// MARK: - Gettoni delle colonne degli strumenti
// Analisi 360, Prodotti, Simulazioni, Confronti, Obiettivi (e le altre app nella CorniceStrumento):
// un solo contenitore in vetro arrotondato, come la rubrica di Clienti e il dossier di Posizioni.
// Dentro, le colonne (elenco laterale, ipotesi o elenco, risultati) si toccano con un filo sottile
// e le testate e i piedi hanno la stessa altezza, così i fili orizzontali proseguono da una colonna all'altra.

extension Misure {
    /// Misure delle colonne dentro la cornice degli strumenti.
    enum ColonneStrumento {
        /// Gli angoli del contenitore: quelli delle schede del tema (come Clienti).
        static let raggio: CGFloat = Tema.Raggio.scheda
        /// L'elenco laterale (percorso, filtri, collegati): la stessa larghezza di quello di Posizioni.
        static let rail: CGFloat = Misure.Analisi.rail
        /// Colonna centrale a larghezza fissa: ipotesi, elenco dei prodotti, dei documenti, delle posizioni.
        static let elenco: CGFloat = Misure.Strumenti.ipotesi
        /// Colonna dei comandi del simulatore.
        static let comandi: CGFloat = Misure.Strumenti.console
        /// Colonna del dettaglio a destra (Obiettivi).
        static let dettaglio: CGFloat = 340
        /// Testata di una colonna: alta quanto le schede dei risultati (Sintesi, Piani, Metodo).
        static let testata: CGFloat = Tema.Misura.Componenti.barraSchede
        /// Piede di una colonna (Confermati con il cliente, Ipotesi da verificare): uguale in tutte le colonne.
        static let piede: CGFloat = Misure.Strumenti.piede
        /// Margine ai lati di testate e piedi.
        static let margine: CGFloat = 12
        /// Spazio tra gli elementi di una testata (campo di ricerca e pulsante).
        static let spazioTestata: CGFloat = 8
        /// Il filo tra le colonne e sotto le testate.
        static let filo: CGFloat = Tema.Misura.filo
    }
}

extension Colori {
    /// Colori delle colonne dentro la cornice degli strumenti.
    enum ColonneStrumento {
        /// Il filo tra le colonne, sotto le testate e sopra i piedi.
        static let divisore = Tema.Colore.separatore
        /// Il fondo leggero dei piedi di colonna (come le righe al passaggio del mouse).
        static let piede = Tema.Colore.rigaSopra
        /// Il testo di testate e piedi.
        static let testata = Tema.Colore.inchiostro
        static let piedeTesto = Tema.Colore.inchiostroSecondario
    }
}
