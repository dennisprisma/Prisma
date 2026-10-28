import SwiftUI

// MARK: - Gettoni delle multiramo a due parti (tema Liquid Glass)
// Composizione «gestione separata + fondi» nel modulo della posizione, nella scheda prodotto e nel dettaglio:
// barra a due colori, colonne affiancate delle due parti, cursore della quota.
// Le tinte vengono da quelle che i documenti usano già per le parti (StileDocumenti: GS #6f86a6, FI #c4913f),
// schiarite nell'aspetto scuro. Su carta (PDF) restano solo `Colori.Documento.prisma.parte(_:)`.

extension Tema.Colore {
    /// Colori delle due parti di una multiramo.
    enum Multiramo {
        /// La parte in gestione separata (Ramo I): barra, pallino della colonna, linea nel grafico.
        static let gestione = Color.dinamico(chiaro: Color(hex: "#5F7EA3"), scuro: Color(hex: "#93B2D8"))
        /// La parte nei fondi (Ramo III).
        static let fondi = Color.dinamico(chiaro: Color(hex: "#C4913F"), scuro: Color(hex: "#D9AA5E"))
        /// Fondo delle due colonne del modulo: il pozzetto dei campi.
        static let fondoColonna = Tema.Colore.pozzetto
        /// Filo attorno alle colonne.
        static let bordoColonna = Tema.Colore.separatore
        /// Avvisi: quota stimata, quota fuori dai limiti del contratto, multiramo calcolata a comparto unico.
        static let avviso = Tema.Colore.arancio
        /// Testi delle colonne: etichette dei campi e note.
        static let etichetta = Tema.Colore.inchiostroSecondario
        static let nota = Tema.Colore.inchiostroTerziario
        /// Testo della barra (quote ed euro delle due parti).
        static let testoBarra = Tema.Colore.inchiostroSecondario
    }
}

extension Tema.Misura {
    /// Misure delle due parti di una multiramo.
    enum Multiramo {
        /// Altezza della barra a due colori e raggio dei suoi tratti.
        static let barra: CGFloat = 8
        static let raggioBarra: CGFloat = Tema.Raggio.barraCanali
        /// Stacco tra i due tratti della barra: quello della barra dei canali.
        static let staccoBarra: CGFloat = Tema.Misura.Componenti.spazioBarraCanali
        /// Spazio tra le due colonne «Gestione separata» e «Fondi», larghezza minima di una colonna
        /// (sotto due colonne minime vanno una sopra l'altra).
        static let spazioColonne: CGFloat = 16
        static let colonnaMinima: CGFloat = 230
        /// Larghezza del cursore della quota in gestione separata, passo del cursore (punti percentuali).
        static let larghezzaCursore: CGFloat = 220
        static let passoCursore: Double = 5
        /// Pallino del colore della parte, nelle testate delle colonne e nelle etichette della barra.
        static let pallino: CGFloat = 8
        /// Spazio tra le righe della sezione, tra i campi di una colonna, tra un'etichetta e il suo campo.
        static let spazioRighe: CGFloat = 12
        static let spazioCampi: CGFloat = 9
        static let spazioEtichetta: CGFloat = 3
        /// Spazio tra i controlli di una riga (cursore, campo, nota) e tra le etichette e la barra.
        static let spazioRiga: CGFloat = 10
        static let spazioBarra: CGFloat = 5
        /// Margini interni delle colonne.
        static let margineColonna = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        /// Spazio tra le coppie etichetta-campo delle parti nelle condizioni del contratto (come le righe vicine).
        static let spazioCondizioni: CGFloat = 14
        /// Tendine: SRI dei fondi, ribilanciamento.
        static let tendinaSRI: CGFloat = 140
        static let tendinaRibilanciamento: CGFloat = 340
        /// Pannello della composizione nel dettaglio: etichette delle righe, spazio sotto la barra e tra gli
        /// avvisi, margini del pulsante «Completa i dati».
        static let etichettaPannello: CGFloat = 130
        static let spazioPannello: CGFloat = 8
        static let margineAzione = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
    }
}

extension Tema.Testo {
    /// Caratteri delle due parti di una multiramo.
    enum Multiramo {
        /// Testata di una colonna («Gestione separata», «Fondi»).
        static let testataColonna = Tema.Testo.Inserimento.gruppo
        /// Quota accanto alla testata e riepilogo «40% gestione separata · 60% fondi».
        static let quota = Tema.Testo.sf(12, .semibold).monospacedDigit()
        /// Etichette della barra e note.
        static let barra = Tema.Testo.didascalia
        static let nota = Tema.Testo.Inserimento.nota
    }
}
