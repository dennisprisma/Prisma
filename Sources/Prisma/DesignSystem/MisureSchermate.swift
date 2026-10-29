import SwiftUI

// Misure, colori e caratteri delle schermate che si adattano alle finestre strette
// (non ingrandite o affiancate negli spazi), ricavati dal template.

extension Misure.Rubrica {
    /// Schede del dossier nelle finestre strette (.clients-tabs a 520 px: gap 16, padding 7px 10px).
    static let spazioSchedeStretto: CGFloat = 12
    static let schedaMargineStretto: CGFloat = 10
    /// Larghezza minima di una scheda del dossier collegato: sotto, una colonna in meno.
    static let schedaAppMinima: CGFloat = 190
}

extension Misure.Pulsante {
    /// Altezza del pulsante principale dell'intestazione (pulsante normale del tema, 32); anche quello che gli sta accanto.
    static let altezzaAqua: CGFloat = Tema.Misura.pulsante
}

extension Misure.Strumenti {
    /// Colonna dell'unità accanto ai campi delle ipotesi ("%", "€/mese"): i campi restano allineati.
    static let unita: CGFloat = 42
    /// Piede delle colonne di Analisi 360 (ipotesi e risultati), alla stessa altezza.
    static let piede: CGFloat = 32
}

extension Misure.Agenda {
    /// Spazio tra il simbolo e il titolo dei pulsanti d'azione del dettaglio (come i pulsanti del tema).
    static let spazioSimbolo: CGFloat = Tema.Misura.Componenti.spazioSimboloPulsante
}

extension Misure {
    /// Scheda di un prodotto: il riquadro "Fonte" accanto alle condizioni.
    enum SchedaProdotto {
        static let fonte: CGFloat = 280
        static let fonteMinima: CGFloat = 200
    }
}

extension Tipo {
    /// Schede del dossier nelle finestre strette (.clients-tabs button a 520 px: 10 px).
    static let schedaRubricaStretta = Tipo.contenuto(10.5, .semibold)
}

extension Colori.Scrivania {
    /// Indicazioni in fondo alla scrivania, direttamente sullo sfondo d'acqua (piede del tema).
    static let piedeLeggibile = Tema.Colore.inchiostroSfondoSecondario
}
