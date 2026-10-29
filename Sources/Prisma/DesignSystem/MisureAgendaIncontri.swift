import SwiftUI

// MARK: - Impaginazione adattiva di Agenda, Attività, Note e Incontri
// Le colonne laterali (dettaglio, indice, priorità del cliente) hanno una larghezza proporzionata alla
// finestra, con un minimo e un massimo: a tutto schermo respirano, affiancate restano leggibili.
// Le schede si dispongono in griglia e riempiono la larghezza; sotto le soglie le colonne vanno sotto.

extension Misure {
    /// Agenda: barra degli strumenti in alto, a sinistra calendario e giornata, a destra il dettaglio
    /// dell'appuntamento a tutta altezza (come l'ispettore del Calendario del Mac).
    enum AgendaImpaginazione {
        /// Quota della larghezza che va al dettaglio, con i suoi limiti.
        static let quotaDettaglio: CGFloat = 0.42
        static let dettaglioMinimo: CGFloat = 320
        static let dettaglioMassimo: CGFloat = 580
        /// La giornata (a sinistra) non scende sotto questa larghezza finché la finestra lo consente.
        static let paginaMinima: CGFloat = 320
        /// Margini della fascia in testa (una riga sola).
        static let fasciaCompatta = EdgeInsets(top: 9, leading: 18, bottom: 9, trailing: 18)
        /// Spazio tra il titolo della fascia e il periodo.
        static let spazioFascia: CGFloat = 14
        /// Margini della striscia della settimana e della griglia del mese sotto la barra.
        static let calendario = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        /// Le note dei giorni («2 incontri») si stringono un poco prima di troncarsi.
        static let scalaNotaGiorno: CGFloat = 0.8
        /// Spazio tra le azioni del dettaglio.
        static let spazioAzioni: CGFloat = 6
        /// Spazio tra il nome del cliente e il collegamento alla sua scheda.
        static let spazioCliente: CGFloat = 8
        /// Barra degli strumenti: margini dei pulsanti ‹ Oggi ›, menu dei clienti (largo e, nelle finestre
        /// strette, compatto, con «＋» al posto di «＋ Appuntamento»).
        static let pulsanteBarra = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        static let menuClienti: CGFloat = 190
        static let menuClientiCompatto: CGFloat = 130
        /// Il dettaglio che scorre sfuma sopra le azioni in fondo.
        static let sfumaturaDettaglio: CGFloat = 22

        /// Larghezza del dettaglio per la larghezza disponibile.
        static func dettaglio(_ totale: CGFloat) -> CGFloat {
            let ideale = min(max(totale * quotaDettaglio, dettaglioMinimo), dettaglioMassimo)
            // Nelle finestre strettissime le due colonne si dividono lo spazio a metà
            return max(0, min(ideale, max(totale - paginaMinima, totale * 0.5)))
        }
    }

    /// Attività: elenco a sinistra, dettaglio a destra.
    enum AttivitaImpaginazione {
        static let quotaDettaglio: CGFloat = 0.4
        static let dettaglioMinimo: CGFloat = 300
        static let dettaglioMassimo: CGFloat = 520
        static let elencoMinimo: CGFloat = 340
        /// Sotto questa larghezza dell'elenco scadenza e priorità vanno sotto il titolo, non in colonna.
        static let sogliaRigaCompatta: CGFloat = 440
        /// Spazio tra scadenza e priorità nella riga compatta.
        static let spazioRigaCompatta: CGFloat = 8

        static func dettaglio(_ totale: CGFloat) -> CGFloat {
            let ideale = min(max(totale * quotaDettaglio, dettaglioMinimo), dettaglioMassimo)
            return max(0, min(ideale, max(totale - elencoMinimo, totale * 0.5)))
        }
    }

    /// Note: indice a sinistra, pagina a destra.
    enum NoteImpaginazione {
        static let quotaIndice: CGFloat = 0.24
        static let indiceMinimo: CGFloat = 210
        static let indiceMassimo: CGFloat = 290

        static func indice(_ totale: CGFloat) -> CGFloat {
            min(max(totale * quotaIndice, indiceMinimo), indiceMassimo, max(0, totale - Misure.Note.minimaPagina))
        }
    }

    /// Incontri: le tre fasi (Preparazione, Ascolto, Prossimi passi) si impaginano sulla larghezza disponibile.
    enum IncontriImpaginazione {
        /// Spazio tra le schede e tra le schede e la colonna laterale.
        static let spazio: CGFloat = 12
        /// Larghezza delle tre fasi (01 · 02 · 03).
        static let fasi: CGFloat = 460
        /// Colonna laterale (priorità del cliente, prossimo passo): quota della larghezza e limiti.
        static let quotaColonna: CGFloat = 0.28
        static let colonnaMinima: CGFloat = 280
        static let colonnaMassima: CGFloat = 400
        /// Sotto questa larghezza la colonna laterale va sotto le schede, a tutta larghezza.
        static let sogliaColonnaSotto: CGFloat = 760
        /// Larghezza minima di una scheda dei temi: decide quante schede stanno in una fila (4, 2 o 1).
        static let temaMinimo: CGFloat = 250
        static let temaAltezzaMinima: CGFloat = 150
        /// Margine interno di schede e colonne.
        static let margine: CGFloat = 12
        /// Stacco minimo prima dei pulsanti in fondo alla colonna delle priorità.
        static let staccoPulsanti: CGFloat = 8
        /// Stacco sopra la nota della chiusura e tra lo stato di una scheda e il suo collegamento.
        static let staccoNota: CGFloat = 6
        /// Larghezza minima di una domanda dell'ascolto: sotto, le tre domande vanno una sotto l'altra.
        static let domandaMinima: CGFloat = 260
        /// Larghezza minima di appunti e decisioni affiancati.
        static let appuntiMinimi: CGFloat = 320
        /// Altezza dei campi delle domande: quota dell'altezza disponibile, con i suoi limiti.
        static let quotaDomanda: CGFloat = 0.2
        static let domandaAltezza: ClosedRange<CGFloat> = 110...200
        /// Altezza di appunti e decisioni: il resto della pagina, tolto lo spazio di titoli e pulsanti.
        static let riservaAscolto: CGFloat = 230
        static let appuntiAltezza: ClosedRange<CGFloat> = 160...520
        /// Margine interno dei pozzetti di domande, appunti e decisioni: il testo non tocca il bordo.
        static let margineFoglio: CGFloat = 10
        /// Spazio tra il segno colorato e l'occhiello di una proposta («BISOGNO», «ATTIVITÀ») e lato del segno.
        static let spazioSegnoProposta: CGFloat = 5
        static let segnoProposta: CGFloat = 7

        static func colonna(_ totale: CGFloat) -> CGFloat {
            min(max(totale * quotaColonna, colonnaMinima), colonnaMassima)
        }

        /// Schede dei temi per fila: 4, 2 o 1 (mai 3, che lascerebbe una scheda sola sotto).
        static func colonneTemi(_ larghezza: CGFloat) -> Int {
            if larghezza >= temaMinimo * 4 + spazio * 3 { return 4 }
            if larghezza >= temaMinimo * 2 + spazio { return 2 }
            return 1
        }

        static func limita(_ valore: CGFloat, _ intervallo: ClosedRange<CGFloat>) -> CGFloat {
            min(max(valore, intervallo.lowerBound), intervallo.upperBound)
        }
    }
}
