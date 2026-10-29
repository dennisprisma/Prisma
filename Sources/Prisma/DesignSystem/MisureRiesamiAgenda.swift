import SwiftUI

extension Misure {
    /// La striscia «Riesami del mese» dell'Agenda e la scelta dei giorni di lavoro.
    enum RiesamiAgenda {
        /// Sotto questa altezza della finestra la striscia è una riga sola.
        static let sogliaAltezzaPiena: CGFloat = 760
        static let margine = EdgeInsets(top: 9, leading: 14, bottom: 10, trailing: 14)
        static let margineCompatta = EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        static let margineScheda = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        static let pulsante = EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)
        static let larghezzaScheda: CGFloat = 248
        static let spazioSchede: CGFloat = 8
        static let spazioRighe: CGFloat = 5
        static let avatar: CGFloat = 26
        static let avatarCompatto: CGFloat = 18
        static let puntoCanale: CGFloat = 7
        static let massimoSchede = 12
        /// Pulsanti dei giorni di lavoro in Impostazioni.
        static let giorno: CGFloat = 26
        static let spazioGiorni: CGFloat = 4
        static let menuOra: CGFloat = 92

        // Spazi interni della striscia (riga di testa, schede, pastiglie compatte)
        /// Spazio tra le voci della riga di testa.
        static let spazioTesta: CGFloat = 8
        /// Spazio tra la riga di testa e le schede.
        static let spazioSotto: CGFloat = 8
        /// Spazio tra gli elementi di una riga della scheda.
        static let spazioScheda: CGFloat = 6
        /// Spazio tra le etichette di canale nella scheda e tra i punti di canale nella pastiglia.
        static let spazioCanali: CGFloat = 3
        /// Margini di una pastiglia compatta.
        static let marginePastiglia = EdgeInsets(top: 3, leading: 4, bottom: 3, trailing: 4)
        /// Margini del pulsante «Pianifica» piccolo nelle pastiglie compatte.
        static let pulsanteCompatto = EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
        /// Spaziatura delle lettere dell'occhiello «RIESAMI DEL MESE».
        static let trackingOcchiello: CGFloat = 1.2
        /// Spazio tra i menu delle ore e il trattino tra inizio e fine.
        static let spazioOre: CGFloat = 6
        /// Spazio sotto il riquadro dell'esito della proposta nel dettaglio dell'appuntamento (come le note).
        static let sottoEsito: CGFloat = 8
    }
}

extension Colori.Agenda {
    static let riesameFondo = Tema.Colore.chip
    static let riesameScaduto = Colori.Analisi.attenzioneTesto
    static let riesameDovuto = Colori.Agenda.eventoDettagli
    static let giornoLavoroScelto = Tema.Colore.accento
    static let giornoLavoroSceltoTesto = Tema.Colore.Componenti.testoSuColore
    static let giornoLavoroTesto = Tema.Colore.inchiostroSecondario
    /// Il punto del canale nelle pastiglie compatte (stessi colori delle etichette di canale).
    static func puntoCanale(_ c: Canale) -> Color { Tema.Colore.canale(c) }
}

extension Tipo {
    /// La lettera di un giorno di lavoro (L M M G V S D) nella scelta dei giorni in Impostazioni.
    static let giornoLavoro = contenuto(11, .semibold)
    /// Il pulsante «Pianifica» piccolo nelle pastiglie compatte e il collegamento «Nel Portafoglio ›».
    static let riesameCompatto = contenuto(11, .medium)
}
