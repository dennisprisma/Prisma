import SwiftUI

// MARK: - Gettoni dell'inserimento dei dati per l'analisi (tema Liquid Glass)
// Le sezioni ripiegabili «Dati per l'analisi» dei moduli (posizione, cliente, familiare, condizioni,
// scheda prodotto): movimenti datati, penali, lavoro e contributi. Quello che non sta tra i gettoni
// comuni del tema.

extension Tema.Colore {
    /// Colori dell'inserimento dei dati per l'analisi.
    enum Inserimento {
        /// Fondo del contenuto di una sezione aperta: il pozzetto dei campi, appena accennato.
        static let fondoSezione = Tema.Colore.pozzetto
        /// Filo attorno al contenuto della sezione aperta.
        static let bordoSezione = Tema.Colore.separatore
        /// Freccia, conteggio e note della testa della sezione.
        static let freccia = Tema.Colore.inchiostroTerziario
        static let titolo = Tema.Colore.inchiostroSecondario
        static let nota = Tema.Colore.inchiostroTerziario
        /// Azioni dentro la sezione («＋ Movimento», «Togli»).
        static let azione = Tema.Colore.link
        static let togli = Tema.Colore.rosso
        /// La stima della pensione, in evidenza nel riquadro del lavoro.
        static let stima = Tema.Colore.inchiostro
    }
}

extension Tema.Raggio {
    /// Raggi dell'inserimento dei dati per l'analisi.
    enum Inserimento {
        /// Contenuto della sezione ripiegabile aperta.
        static let sezione: CGFloat = Tema.Raggio.gruppo
    }
}

extension Tema.Misura {
    /// Misure dell'inserimento dei dati per l'analisi.
    enum Inserimento {
        /// Testa della sezione ripiegabile: spazio tra freccia, titolo e nota; lato della freccia.
        static let spazioTesta: CGFloat = 8
        static let freccia: CGFloat = 10
        /// Spazio tra la testa e il contenuto, tra i campi e tra i gruppi di campi.
        static let spazioSezione: CGFloat = 10
        static let spazioCampi: CGFloat = 10
        /// Spazio in più sopra il sottotitolo di un gruppo di campi, e tra il sottotitolo e la sua frase.
        static let sopraGruppo: CGFloat = 6
        static let spazioGruppo: CGFloat = 2
        /// Margini interni del contenuto aperto.
        static let margineSezione = EdgeInsets(top: 14, leading: 12, bottom: 14, trailing: 12)
        /// Spazio tra un campo e la sua unità di misura, e tra i controlli di una riga.
        static let spazioUnita: CGFloat = 6
        static let spazioRiga: CGFloat = 8
        /// Larghezze dei campi: importi, percentuali, anni (età, mesi, anno del primo contributo).
        static let campoEuro: CGFloat = 110
        static let campoPercento: CGFloat = 70
        static let campoAnni: CGFloat = 60
        /// Movimenti datati: tendina del tipo, larghezza minima della nota.
        static let tipoMovimento: CGFloat = 150
        static let notaMovimento: CGFloat = 110
        /// Penali per anno: etichetta «2° anno».
        static let annoPenale: CGFloat = 52
        /// Tendine: persona assicurata, consolidamento, tipo di lavoratore.
        static let tendinaPersona: CGFloat = 280
        static let tendinaConsolidamento: CGFloat = 250
        static let tendinaLavoro: CGFloat = 290
        /// Altezza del modulo del familiare, ora con i dati per l'analisi (il contenuto scorre).
        static let moduloFamiliare: CGFloat = 560
    }
}

extension Tema.Testo {
    /// Caratteri dell'inserimento dei dati per l'analisi.
    enum Inserimento {
        static let titolo = Tema.Testo.occhiello
        static let nota = Tema.Testo.didascalia
        static let freccia = Tema.Testo.sf(9.5, .bold)
        /// Sottotitolo di un gruppo di campi dentro la sezione («Riscatto», «Gestione separata»…).
        static let gruppo = Tema.Testo.sf(11.5, .semibold)
        static let azione = Tema.Testo.didascalia
        /// La stima della pensione.
        static let stima = Tema.Testo.sf(13, .semibold).monospacedDigit()
    }
}

extension Tema.Moto {
    /// Apertura e chiusura delle sezioni ripiegabili.
    static let sezioneRipiegabile = Tema.Moto.uscita(0.2)
}
