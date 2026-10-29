import SwiftUI

// MARK: - Gettoni del confronto «documento contro dossier» (specifica 9, giro 5, tema Liquid Glass)
// Tabella «Nel documento / In Prisma» nella scheda «Confronto» di Documenti, impatto del nuovo KID, storico degli
// aggiornamenti (anche in Prodotti). Solo misure e alias dei colori del tema: niente valori di colore nuovi.

extension Misure {
    enum ConfrontoDossier {
        /// Colonne della tabella: casella, nome del dato, esito (le due colonne dei valori si dividono il resto).
        static let colonnaScelta: CGFloat = 34
        static let colonnaDato: CGFloat = 200
        static let colonnaEsito: CGFloat = 124
        /// Menu a tendina delle candidate per il collegamento.
        static let menu: CGFloat = 300
        /// Segmenti «Scheda prodotto / Posizione» quando il documento è collegato a tutte e due.
        static let segmenti: CGFloat = 240
        static let margine: CGFloat = 12
        static let spazio: CGFloat = 8
        static let spazioSezioni: CGFloat = 14
        static let spazioRiga: CGFloat = 2
        static let tracciaOcchiello: CGFloat = 0.8
        static let pulsante = EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        static let pulsantePiccolo = EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)
        static let margineRigaCliente = EdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0)
        /// Variazioni mostrate nello storico prima di «Mostra tutti».
        static let storicoVisibile = 8
        /// Clienti nell'avviso di Prodotti, poi «e altri N».
        static let clientiAvviso = 4
        /// Righe al massimo della nota sotto un valore del documento.
        static let righeNota = 2
    }
}

extension Colori {
    /// Solo alias dei colori del tema: niente valori nuovi (chiaro e scuro dal tema).
    enum ConfrontoDossier {
        static let uguale = Colori.Analisi.okTesto
        static let diverso = Colori.Analisi.attenzioneTesto
        static let peggiora = Colori.Analisi.erroreTesto
        static let vuoto = Colori.Analisi.kpiNota
        static let testo = Colori.Analisi.tabellaTesto
        static let occhiello = Colori.Strumenti.occhiello
        static let collegamento = Colori.Colonna.collegamento
        static let riga = Colori.Analisi.tabellaRiga
    }
}
