import SwiftUI

// Il pannello di ricerca ⌘K come Spotlight, dal tema Liquid Glass (.spot, .spot-in, .spot-res, .sr-g, .sr-i,
// .spot-foot di tema-liquid-glass.html): capsula di vetro in alto al centro, campo grande con la lente,
// risultati sotto raggruppati, colonna di anteprima a destra, piede con i tasti.

extension Misure {
    enum Spotlight {
        /// Distanza dal bordo alto della shell (tema: top 15vh), mai sopra la barra superiore.
        static let distanzaAltoQuota: CGFloat = 0.15
        static let distanzaAltoMinima: CGFloat = Tema.Misura.barra + 16
        /// Larghezza: il campo del tema (660) più lo spazio per la colonna di anteprima.
        static let larghezza: CGFloat = 760
        /// Margine minimo dai lati della shell (tema: 100vw − 32px).
        static let margineLato: CGFloat = 16
        static let raggio: CGFloat = Tema.Raggio.ricerca
        /// Margine interno del vetro (tema: padding 8px).
        static let cornice: CGFloat = 8
        // Campo (.spot-in)
        static let campoAltezza: CGFloat = 52
        static let campoMargine: CGFloat = 14
        static let campoSpazio: CGFloat = 12
        /// Altezza massima del pannello rispetto alla shell (tema: max-height 70vh).
        static let altezzaQuota: CGFloat = 0.7
        /// Altezza dell'area dei risultati: cresce con i risultati, tra questi due valori.
        static let risultatiMinima: CGFloat = 300
        static let risultatiMassima: CGFloat = 470
        /// Altezza dell'area quando non c'è niente da mostrare (nessun risultato).
        static let nessunRisultato: CGFloat = 64
        /// Spazio tenuto per la striscia dei filtri e per il piede quando si calcola quanto crescono i risultati.
        static let riservaStrisciaPie: CGFloat = 72
        // Elenco (.spot-res, .sr-g, .sr-i)
        static let colonnaElenco: CGFloat = 330
        static let margineElenco: CGFloat = 4
        static let gruppoMargine = EdgeInsets(top: 10, leading: 10, bottom: 4, trailing: 10)
        static let rigaMargine = EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
        static let rigaSpazio: CGFloat = 10
        static let rigaTestoSpazio: CGFloat = 1
        static let icona: CGFloat = 28
        /// Stime per far crescere il pannello con i risultati (non servono al disegno).
        static let stimaRiga: CGFloat = 46
        static let stimaEstratto: CGFloat = 15
        static let stimaGruppo: CGFloat = 30
        // Anteprima
        static let anteprimaMargine: CGFloat = 18
        static let anteprimaSpazio: CGFloat = 14
        static let iconaAnteprima: CGFloat = 52
        static let intestazioneSpazio: CGFloat = 12
        static let cifraMargineVerticale: CGFloat = 6
        static let azioniSpazio: CGFloat = 8
        static let testoAnteprimaRighe = 6
        // Striscia dei filtri e dei totali
        static let strisciaMargine = EdgeInsets(top: 0, leading: 12, bottom: 8, trailing: 12)
        static let pillolaSpazio: CGFloat = 6
        static let pillolaMargine = EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)
        static let pillolaAltezza: CGFloat = 22
        static let totaleSpazio: CGFloat = 6
        // Pannello vuoto (ricerche salvate e filtri)
        static let vuotoMargine = EdgeInsets(top: 4, leading: 4, bottom: 8, trailing: 4)
        /// Oltre queste ricerche salvate l'elenco scorre, alto così.
        static let salvateSenzaScorrere = 5
        static let salvateAltezza: CGFloat = 236
        static let messaggioMargine = EdgeInsets(top: 22, leading: 12, bottom: 22, trailing: 12)
        // Piede (.spot-foot)
        static let pieMargine = EdgeInsets(top: 8, leading: 14, bottom: 4, trailing: 8)
        static let pieSpazio: CGFloat = 14
        static let nomeRicercaLarghezza: CGFloat = 260
    }
}

extension Tipo {
    /// Il campo grande (tema: 400 21px).
    static let spotlightCampo = Tema.Testo.ricerca
    static let spotlightLente = Tema.Testo.sf(19, .medium)
    static let spotlightGruppo = Tema.Testo.occhiello
    static let spotlightTitolo = Tema.Testo.titolo
    static let spotlightDettaglio = Tema.Testo.secondario
    static let spotlightEstratto = Tema.Testo.secondario.italic()
    static let spotlightPie = Tema.Testo.didascalia
    static let spotlightPillola = Tema.Testo.chipPiccolo
    static let spotlightPillolaNota = Tema.Testo.sf(11)
    static let spotlightAnteprimaTitolo = Tema.Testo.sezione
    static let spotlightAnteprimaSottotitolo = Tema.Testo.secondarioGrande
    static let spotlightCifraEtichetta = Tema.Testo.secondario
    static let spotlightCifraValore = Tema.Testo.importo
    static let spotlightTesto = Tema.Testo.corpo
    static let spotlightMessaggio = Tema.Testo.corpo
    static let spotlightSimboloAzione = Tema.Testo.sf(14, .semibold)
    static let spotlightSimboloAnteprima = Tema.Testo.sf(24, .semibold)
}

extension Colori {
    enum Spotlight {
        /// Velo sotto il pannello (.scrim del tema).
        static let velo = Tema.Colore.velo
        /// Vetro del pannello: coprente, le finestre dietro non si leggono attraverso.
        static let fondo = Tema.Colore.PannelliShell.coprente
        static let lente = Tema.Colore.inchiostroSecondario
        static let testo = Tema.Colore.inchiostro
        static let cancella = Tema.Colore.inchiostroTerziario
        static let separatore = Tema.Colore.separatore
        static let gruppo = Tema.Colore.inchiostroSecondario
        static let titolo = Tema.Colore.inchiostro
        static let dettaglio = Tema.Colore.inchiostroSecondario
        static let estratto = Tema.Colore.inchiostroSecondario
        /// Voce scelta: accento al 18% (.sr-i.sel); al passaggio un velo leggero.
        static let selezione = Tema.Colore.selezioneRicerca
        static let sopra = Tema.Colore.rigaSopra
        static let pie = Tema.Colore.inchiostroTerziario
        static let collegamento = Tema.Colore.link
        static let messaggio = Tema.Colore.inchiostroSecondario
        // Azioni: tessera neutra con il simbolo
        static let tesseraAzione = Tema.Colore.pozzetto
        static let simboloAzione = Tema.Colore.accento
        // Anteprima
        static let etichettaCifra = Tema.Colore.inchiostroSecondario
        static let valoreCifra = Tema.Colore.inchiostro
        static let testoAnteprima = Tema.Colore.inchiostroSecondario
        // Pillole: suggerimenti (pozzetto), filtri riconosciuti (accento), filtri a metà (arancio)
        static let pillola = Tema.Colore.pozzetto
        static let pillolaSopra = Tema.Colore.chipSopra
        static let pillolaTesto = Tema.Colore.inchiostro
        static let pillolaNota = Tema.Colore.inchiostroTerziario
        static let filtro = Tema.Colore.selezione
        static let filtroTesto = Tema.Colore.link
        static let incompleto = Tema.Colore.fondoProposta
        static let incompletoTesto = Tema.Colore.testoProposta
    }
}

extension Tema.Moto {
    /// Entrata e uscita del pannello (showOv del tema: 240 ms, cubic-bezier(.22,1,.36,1), da −6 pt e scala 0,97).
    enum Spotlight {
        static let entrata = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)
        static let uscita = Animation.easeIn(duration: 0.12)
        static let scala: CGFloat = 0.97
        static let spostamento: CGFloat = -6
    }
}
