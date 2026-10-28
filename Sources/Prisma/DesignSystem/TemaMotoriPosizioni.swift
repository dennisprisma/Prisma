import SwiftUI

// MARK: - Gettoni delle analisi nuove di Posizioni (tema Liquid Glass)
// Dettaglio della posizione (rendimento dei versamenti, costi come nel KID, riscatto anno per anno,
// gestione separata), crisi del passato nella prova di resistenza e coerenza con il profilo nel dossier.
// Quello che non sta tra i gettoni comuni del tema e tra quelli dell'analisi.

extension Tema.Colore {
    /// Colori delle analisi nuove di Posizioni.
    enum MotoriPosizioni {
        /// Riga in evidenza nelle tabelle: il primo riscatto senza perdite, la crisi peggiore.
        static let rigaEvidenza = Colori.Analisi.okFondo
        static let rigaPeggiore = Colori.Analisi.erroreFondo
        /// Testo delle righe che non valgono (riscatto bloccato): grigio terziario.
        static let rigaSpenta = Tema.Colore.inchiostroTerziario
        /// Cifre negative o in perdita, e guadagni.
        static let negativo = Colori.Analisi.erroreTesto
        static let positivo = Colori.Analisi.okTesto
        /// Barre delle quote (emittenti e canali) e segno della soglia.
        static let soglia = Colori.Analisi.assi
    }
}

extension Tema.Misura {
    /// Misure delle analisi nuove di Posizioni.
    enum MotoriPosizioni {
        /// Colonna destra del dettaglio (costi, fiscalità, storico) e larghezza delle etichette delle righe.
        static let etichettaRiga: CGFloat = 118
        static let etichettaRigaLarga: CGFloat = 170
        /// Spazio tra il valore di una riga e la sua pillola.
        static let spazioPillola: CGFloat = 8
        /// Riscatto anno per anno: colonne della tabella e righe mostrate prima di «tutti gli anni».
        static let colonnaContratto: CGFloat = 84
        static let colonnaImporto: CGFloat = 100
        static let colonnaPenale: CGFloat = 70
        static let colonnaNetto: CGFloat = 118
        static let righeRiscatto = 6
        /// Crisi del passato: colonne dell'anno e delle cifre.
        static let colonnaAnnoCrisi: CGFloat = 54
        static let colonnaPerditaCrisi: CGFloat = 120
        static let colonnaQuotaCrisi: CGFloat = 64
        static let colonnaGiudizioCrisi: CGFloat = 150
        /// Coerenza con il profilo: emittenti mostrati, colonna del canale e delle quote.
        static let righeEmittenti = 4
        static let colonnaQuota: CGFloat = 44
        static let colonnaValore: CGFloat = 96
        static let colonnaTipoCoerenza: CGFloat = 120
        static let spazioColonne: CGFloat = 24
        static let segnoSoglia = CGSize(width: 2, height: 12)
        /// Spazio tra le sezioni di un pannello e tra le righe di un elenco.
        static let spazioSezioni: CGFloat = 12
        static let spazioElenco: CGFloat = 6
    }
}

extension Tema.Testo {
    /// Caratteri delle analisi nuove di Posizioni.
    enum MotoriPosizioni {
        /// Sottotitolo di una parte del pannello («Se tornassero le crisi del passato», «Per emittente»).
        static let sottotitolo = Tema.Testo.occhiello
    }
}
