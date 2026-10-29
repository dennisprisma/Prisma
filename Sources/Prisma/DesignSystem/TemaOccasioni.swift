import SwiftUI

// Valori grafici del calendario delle occasioni (Agenda, Impostazioni › Occasioni). Solo token esistenti del
// tema: il canale ha i suoi colori (blu Alleanza, cuoio indipendente), ciò che non ha canale usa l'inchiostro
// secondario. L'alias `TC` di Colori.swift è privato: qui si scrive `Tema.Colore`.

extension Colori.Agenda {
    /// Il colore di un'occasione: blu Alleanza (#2563EB), cuoio indipendente (#B06E12), neutro senza canale.
    static func occasione(_ c: Canale?) -> Color { c.map(Tema.Colore.canale) ?? Tema.Colore.inchiostroSecondario }
    /// Il fondo del simbolo: il vetro del canale (come la capsula del canale) o il pozzetto.
    static func fondoOccasione(_ c: Canale?) -> Color { c.map(Tema.Colore.fondoCanale) ?? Tema.Colore.pozzetto }
    static let occasioneOcchiello = Tema.Colore.inchiostroSecondario
    static let occasioneFonte = Tema.Colore.inchiostroTerziario
}

extension Misure {
    /// Le occasioni in Agenda.
    enum Occasioni {
        /// Il cerchio del simbolo nella riga e nel dettaglio, e il glifo dentro.
        static let simbolo: CGFloat = 22
        static let glifo: CGFloat = 11
        static let simboloDettaglio: CGFloat = 30
        static let glifoDettaglio: CGFloat = 14
        /// L'anello sotto il giorno (settimana e mese): lato e bordo.
        static let anello: CGFloat = 5
        static let bordoAnello: CGFloat = 1.5
        /// Il selettore Settimana · Mese · Occasioni.
        static let segmentiVista: CGFloat = 250
        /// Il filtro per gruppo della vista «Occasioni».
        static let menuGruppo: CGFloat = 170
        /// L'occhiello del mese nella vista «Occasioni» e della sezione nella giornata.
        static let occhiello = EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16)
        /// La riga (come quella delle scadenze).
        static let riga = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 15)
        /// La testata della vista «Occasioni».
        static let testata = EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 12)
        /// Le opzioni dell'anticipo e delle età nelle impostazioni.
        static let menuImpostazioni: CGFloat = 150
        static let menuEta: CGFloat = 110

        // Spazi interni (come la riga e il dettaglio dell'appuntamento)
        /// Spaziatura delle lettere degli occhielli e delle etichette dei riquadri.
        static let tracciaOcchiello: CGFloat = 1.2
        static let tracciaEtichetta: CGFloat = 0.3
        /// Tra la colonna di sinistra, il centro e la freccia della riga.
        static let spazioRiga: CGFloat = 12
        /// Tra le tre righe di testo della riga.
        static let spazioTesti: CGFloat = 3
        /// Tra simbolo, titolo ed etichetta del canale nella prima riga.
        static let spazioTitolo: CGFloat = 6
        /// Tra giorno e mese nella colonna di sinistra della vista «Occasioni».
        static let spazioData: CGFloat = 5
        /// Il segno a capsula della riga scelta: quanto resta sopra e sotto.
        static let margineSegno: CGFloat = 10
        /// Il riquadro della posizione e della persona nel dettaglio.
        static let riquadro: CGFloat = 9
        static let spazioRiquadro: CGFloat = 5
        static let sottoRiquadro: CGFloat = 8
        /// Il riquadro «COSA CAMBIA» (come le note dell'appuntamento).
        static let nota = EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
        static let spazioNota: CGFloat = 4
        static let intornoNota: CGFloat = 8
        /// I pulsanti dentro i riquadri.
        static let pulsanteRiquadro = EdgeInsets(top: 4, leading: 9, bottom: 4, trailing: 9)
        static let sopraPulsante: CGFloat = 2
        /// Tra il simbolo grande e il titolo nel dettaglio; sopra e sotto il titolo.
        static let spazioIntestazione: CGFloat = 10
        static let intornoTitolo: CGFloat = 5
        static let sottoCliente: CGFloat = 7
        /// Lo spazio a destra del testo del dettaglio, per la barra di scorrimento.
        static let margineScorrimento: CGFloat = 4
        /// Le azioni in fondo al dettaglio: spazio sopra.
        static let sopraAzioni: CGFloat = 7
        /// Il dettaglio «quieto» della vista: spazio tra le righe e sopra il suggerimento.
        static let spazioQuieto: CGFloat = 8
        static let sopraSuggerimento: CGFloat = 10
        /// La pagina vuota della vista «Occasioni».
        static let vuoto = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        static let spazioVuoto: CGFloat = 6
        static let sopraPulsanteVuoto: CGFloat = 6
        /// Il nome del mese nella pagina vuota si stringe prima di troncarsi.
        static let scalaMeseVuoto: CGFloat = 0.6
        /// Il riepilogo sotto la testata della vista e le voci della riga di testa.
        static let spazioRiepilogo: CGFloat = 4
        static let spazioTestata: CGFloat = 8
        /// Fra TCM e LTC nella riga delle età limite.
        static let spazioEta: CGFloat = 8
    }
}
