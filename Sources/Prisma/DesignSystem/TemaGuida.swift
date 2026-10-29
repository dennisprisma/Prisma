import SwiftUI

// Proprietario: G7 (guida). Gettoni della «Guida di Prisma», delle «i» accanto alle parole tecniche, dei vuoti
// guidati e delle aggiunte alla schermata di benvenuto e al dock. Ricavati dal tema Liquid Glass: vetro dei
// pannelli, accento, inchiostri. I pulsanti usano le taglie dei bottoni (`TagliaPulsante`), non misure proprie.

extension Tema.Misura {
    enum Guida {
        // Pannello
        static let larghezza: CGFloat = 880
        static let altezza: CGFloat = 620
        /// Distanza minima della scheda dai bordi della finestra.
        static let bordo: CGFloat = 24
        static let margine: CGFloat = 28
        static let spazio: CGFloat = 16
        static let spazioTestata: CGFloat = 12
        static let logoPannello: CGFloat = 26
        // Introduzione
        static let spazioPunti: CGFloat = 10
        static let iconaIntro: CGFloat = 72
        static let logoIntro: CGFloat = 64
        static let spazioIcone: CGFloat = 14
        static let colonnaIcone: CGFloat = 200
        static let pallinoPunto: CGFloat = 7
        static let rientroPallino: CGFloat = 6
        static let iconaPercorso: CGFloat = 40
        static let spazioPercorso: CGFloat = 8
        static let puntoPagina: CGFloat = 7
        static let puntoPaginaAttivo: CGFloat = 20 // il puntino attivo si allunga
        static let spazioPuntiPagina: CGFloat = 6
        // Le app e le parole
        static let iconaElencoApp: CGFloat = 28
        static let elencoApp: CGFloat = 250
        static let elencoParole: CGFloat = 240
        static let rigaElenco = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        static let spazioRigaElenco: CGFloat = 10
        static let spazioElenco: CGFloat = 2
        static let chipMargine = EdgeInsets(top: 5, leading: 11, bottom: 5, trailing: 11)
        static let spazioChip: CGFloat = 6
        static let esempioMargine: CGFloat = 12
        // Scheda «Come si usa» e scheda della parola
        static let numeroPasso: CGFloat = 26
        static let schedaApp: CGFloat = 380
        static let margineScheda: CGFloat = 18
        static let schedaTermine: CGFloat = 320
        static let spazioScheda: CGFloat = 10
        static let spazioBlocchi: CGFloat = 16
        static let spazioPasso: CGFloat = 10
        static let spazioNumeroPasso: CGFloat = 8
        static let spazioTermine: CGFloat = 2
        static let spazioEsempio: CGFloat = 3
        static let spazioPercorsoNome: CGFloat = 4
        // La «i»: riquadro visivo 22, area di clic 28 (con `Tema.Misura.Componenti.allargamentoClic`)
        static let infoTocco: CGFloat = 22
        static let spazioInfo: CGFloat = 3
        // Vuoti guidati
        static let vuotoLarghezza: CGFloat = 520
        static let iconaVuoto: CGFloat = 30
        static let cerchioVuoto: CGFloat = 64
        static let spazioVuoto: CGFloat = 14
        static let vuotoMargine: CGFloat = 24
        // Schermata di benvenuto
        static let descrizioneBenvenutoMassima: CGFloat = 440
        /// Sotto questa altezza della finestra la schermata lascia le capsule dei canali (resta il nome dello studio).
        static let altezzaBenvenutoCompleta: CGFloat = 760
        static let studioSpazio: CGFloat = 8
        static let marchioStudio: CGFloat = 14
        /// Spazio tra la nota e l'invito del primo avvio.
        static let invitoBenvenuto: CGFloat = 16
        static let invitoMargine = EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        static let invitoMassimo: CGFloat = 460
        static let invitoSpazio: CGFloat = 10
        static let canaliSpazio: CGFloat = 8
        // Dock
        static let descrizioneDockMassima: CGFloat = 240
        static let descrizioneDockSpazio: CGFloat = 2
    }
}

extension Tema.Testo {
    enum Guida {
        static let titoloPannello = Tema.Testo.sf(19, .bold)
        static let titoloPagina = Tema.Testo.sf(26, .bold)
        static let testoPagina = Tema.Testo.sf(15)
        static let puntoPagina = Tema.Testo.sf(14)
        static let titoloBlocco = Tema.Testo.sf(12, .semibold)
        static let testoBlocco = Tema.Testo.sf(14)
        static let aCosaServe = Tema.Testo.sf(15)
        static let numeroPasso = Tema.Testo.sf(13, .bold, arrotondato: true)
        static let termine = Tema.Testo.sf(24, .bold)
        static let perEsteso = Tema.Testo.sf(13).italic()
        static let spiegazione = Tema.Testo.sf(15)
        static let voceElenco = Tema.Testo.sf(13, .semibold)
        static let breveElenco = Tema.Testo.sf(12)
        static let titoloApp = Tema.Testo.sf(15, .semibold)
        static let chip = Tema.Testo.sf(12.5, .medium)
        static let info = Tema.Testo.sf(13)
        static let percorso = Tema.Testo.sf(12, .medium)
        static let interlinea: CGFloat = 4
        static let spaziaturaTitolo = Tema.Testo.spaziatura(-0.02, 26)
        static let spaziaturaBlocco = Tema.Testo.spaziatura(0.04, 12)
        // Vuoti guidati
        static let titoloVuoto = Tema.Testo.sf(19, .bold)
        static let percheVuoto = Tema.Testo.sf(14)
        static let titoloPassoVuoto = Tema.Testo.sf(13, .semibold)
        static let testoPassoVuoto = Tema.Testo.sf(13)
        static let iconaVuoto = Font.system(size: Tema.Misura.Guida.iconaVuoto * Tipo.fattore, weight: .medium)
        // Schermata di benvenuto (testi nuovi pensati grandi: scala leggibile)
        static let descrizioneBenvenuto = Tema.Testo.sf(14)
        static let studioBenvenuto = Tema.Testo.sf(15, .semibold)
        static let entraBenvenuto = Tema.Testo.sf(14)
        static let notaBenvenuto = Tema.Testo.sf(12)
        static let invitoTitolo = Tema.Testo.sf(14, .semibold)
        static let invitoTesto = Tema.Testo.sf(13)
        // Dock (fuori dalle app la scala resta quella di oggi)
        static let descrizioneDock = Tema.Testo.sfFisso(11.5)
    }
}

extension Tema.Raggio {
    enum Guida {
        static let invito: CGFloat = 18
        static let suggerimentoDock: CGFloat = 14
        static let esempio: CGFloat = 12
        static let rigaElenco: CGFloat = 10
    }
}

extension Tema.Moto {
    enum Guida {
        static let entrata = Tema.Moto.conMolla(risposta: 0.28, smorzamento: 1)
        static let uscita = Animation.easeIn(duration: 0.12)
        static let scala: CGFloat = 0.95
        /// Cambio di pagina dell'introduzione: dissolvenza breve, niente scorrimenti.
        static let pagina = Animation.easeInOut(duration: 0.18)
    }
}

extension Tema.Colore {
    enum Guida {
        static let info = Tema.Colore.inchiostroTerziario
        static let numeroPasso = Tema.Colore.accento
        static let numeroPassoTesto = Tema.Colore.Componenti.testoSuColore
        static let pallinoPunto = Tema.Colore.accento
        static let puntoPagina = Tema.Colore.inchiostroTerziario
        static let puntoPaginaAttivo = Tema.Colore.accento
        static let fondoEsempio = Tema.Colore.pozzetto
        static let selezioneElenco = Tema.Colore.chipControlloSopra
        static let fondoChip = Tema.Colore.pozzetto
        static let filoChip = Tema.Colore.separatore
        static let cerchioVuoto = Tema.Colore.pozzetto
        static let iconaVuoto = Tema.Colore.accento
        static let titoloBlocco = Tema.Colore.inchiostroSecondario
        static let frecciaPercorso = Tema.Colore.inchiostroTerziario
    }
}
