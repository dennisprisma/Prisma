import SwiftUI

// MARK: - Gettoni delle analisi nuove di Analisi 360 e Obiettivi (tema Liquid Glass)
// Probabilità di raggiungere un obiettivo (scenari con le probabilità), pensione pubblica stimata con il
// contributivo, protezione persona per persona e fisco delle coperture e della previdenza.
// Quello che non sta tra i gettoni comuni del tema e tra quelli dell'analisi.

extension Tema.Colore {
    /// Colori delle analisi nuove di Analisi 360 e Obiettivi.
    enum MotoriAnalisi {
        /// Ventaglio degli scenari: fascia tra il caso sfavorevole e il favorevole, linea mediana, obiettivo.
        static let fasciaVentaglio = Colori.Analisi.linea.opacity(0.16)
        static let bordoVentaglio = Colori.Analisi.linea.opacity(0.4)
        static let mediana = Colori.Analisi.linea
        static let traguardo = Colori.Analisi.prudente
        /// Probabilità di arrivarci: buona (da 7 su 10), incerta (da 4 su 10), bassa.
        static let probabilitaAlta = Colori.Analisi.okTesto
        static let probabilitaMedia = Colori.Analisi.attenzioneTesto
        static let probabilitaBassa = Colori.Analisi.erroreTesto
        /// Cifre che mancano (scoperto) e cifre a posto.
        static let scoperto = Colori.Strumenti.negativo
        static let coperto = Colori.Strumenti.positivo
        /// Avvisi sotto le cifre (requisiti, coperture che scadono presto).
        static let avviso = Colori.Analisi.attenzioneTesto
        /// Testo delle spiegazioni e delle note.
        static let spiegazione = Tema.Colore.inchiostroSecondario
        static let valore = Tema.Colore.inchiostro
        /// Collegamento che apre le ipotesi.
        static let apriIpotesi = Tema.Colore.link
    }
}

extension Tema.Misura {
    /// Misure delle analisi nuove di Analisi 360 e Obiettivi.
    enum MotoriAnalisi {
        /// Larghezza delle etichette delle righe: area dei risultati dell'Analisi 360 e colonna dell'obiettivo.
        static let etichettaRiga: CGFloat = 230
        static let etichettaDettaglio: CGFloat = 130
        /// Spazio tra le parti di un pannello, tra le righe di un elenco e dentro un valore.
        static let spazioSezioni: CGFloat = 10
        static let spazioElenco: CGFloat = 4
        static let spazioValore: CGFloat = 6
        /// Spaziatura delle lettere degli occhielli in maiuscolo (come nella colonna dell'obiettivo).
        static let spaziaturaOcchiello: CGFloat = 0.8
        /// Pulsanti di vetro piccoli dentro i pannelli.
        static let marginePulsante = EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)
        /// Scheda di una persona (protezione persona per persona).
        static let schedaPersona = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        /// Colonne delle cifre nella tabella dei rischi di una persona.
        static let colonnaCifra: CGFloat = 104
        static let colonnaProposte: CGFloat = 122
        /// Ventaglio degli scenari dell'obiettivo: altezza, margine sinistro per le cifre, linee.
        static let ventaglio: CGFloat = 118
        static let ventaglioSinistra: CGFloat = 40
        static let ventaglioBasso: CGFloat = 16
        static let lineaMediana: CGFloat = 2
        static let lineaTraguardo: CGFloat = 1.2
        static let lineaBordo: CGFloat = 0.8
        static let trattiTraguardo: [CGFloat] = [5, 4]
    }
}

extension Tema.Testo {
    /// Caratteri delle analisi nuove di Analisi 360 e Obiettivi.
    enum MotoriAnalisi {
        /// «7 possibilità su 10».
        static let probabilita = Tema.Testo.sf(22, .bold)
        /// Nome della persona nella protezione persona per persona.
        static let persona = Tema.Testo.titolo
        /// Titoletto di una parte di un pannello.
        static let sottotitolo = Tema.Testo.occhiello
        /// Freccia del collegamento che apre le ipotesi.
        static let freccia = Tema.Testo.sf(9, .semibold)
    }
}
