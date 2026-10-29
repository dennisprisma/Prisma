#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

/// Caratteri delle schermate nel tema «Liquid Glass»: il font di sistema (SF), come `--font` del tema.
/// I nomi restano quelli del tema iOS 5; le dimensioni seguono il tema dove non rompono le impaginazioni.
/// - "sistema" e "contenuto": SF (prima Lucida Grande e Helvetica Neue)
/// - "serif": i titoli delle pagine, ora SF semibold (prima Georgia)
enum Tipo {
    /// Non serve più per scegliere il carattere (resta per compatibilità).
    static let lucidaDisponibile: Bool = FontPiattaforma(name: "LucidaGrande", size: 12) != nil

    /// Ingrandimento dei testi dell'interfaccia (Impostazioni → Dimensione del testo). Si fissa all'avvio,
    /// prima che si disegni qualcosa: i caratteri sono costanti. Prospetti e report hanno i loro caratteri
    /// (Tipo.Documento, Tipo.Report, Tipo.Carta) e restano impaginati per la carta.
    nonisolated(unsafe) static var fattore: CGFloat = 1

    /// SF alla dimensione data sulla scala leggibile (`Tema.Testo.leggibile`), moltiplicata per la Dimensione del testo.
    static func sistema(_ dimensione: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        Font.system(size: Tema.Testo.leggibile(dimensione) * fattore, weight: peso)
    }

    /// Eccezioni alla scala leggibile (badge, tessere data, dock, assi, barra superiore, scrivania):
    /// la dimensione del tema, moltiplicata solo per la Dimensione del testo.
    static func fisso(_ dimensione: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        Font.system(size: dimensione * fattore, weight: peso)
    }

    /// Come `fisso`, arrotondato.
    static func fissoArrotondato(_ dimensione: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        let disegno: Font.Design = .rounded
        return Font.system(size: dimensione * fattore, weight: peso, design: disegno)
    }

    /// Come `sistema`: nel tema c'è un solo carattere.
    static func contenuto(_ dimensione: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        sistema(dimensione, peso)
    }

    /// SF arrotondato (`--font-r` del tema): numeri grandi, avatar, date.
    static func arrotondato(_ dimensione: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        let disegno: Font.Design = .rounded
        return Font.system(size: Tema.Testo.leggibile(dimensione) * fattore, weight: peso, design: disegno)
    }

    // Barra superiore
    static let barraLogo = fisso(25, .bold)
    static let barraMarchio = fisso(13, .bold)
    static let barraOS = fisso(10)
    static let barraApp = fisso(13, .medium)
    static let barraOra = fisso(13, .medium).monospacedDigit()
    static let barraTasto = fisso(11, .medium)
    static let barraAvatar = fissoArrotondato(10, .bold)
    static let badgePiccolo = fisso(9.5, .bold)

    // Scrivania
    static let scrivaniaKicker = fisso(11, .medium)
    static let scrivaniaTitolo = fisso(30, .bold)
    static let scrivaniaSottotitolo = fisso(13)
    static let scrivaniaSezione = fisso(14, .bold)
    static let scrivaniaPiede = fisso(11)
    static let pulsanteVetro = fisso(12.5, .medium)
    static let lanciatoreNome = fisso(12, .semibold)
    static let lanciatoreSottotitolo = fisso(10.5)
    static let badgeGrande = fisso(10, .bold)

    // Colonna del cliente
    static let colonnaEtichetta = contenuto(10.5, .medium)
    static let colonnaNome = contenuto(18, .bold)
    static let colonnaTema = contenuto(12)
    static let colonnaScheda = sistema(11, .medium)
    static let colonnaIntestazione = sistema(10.5, .semibold)
    static let colonnaCollegamento = sistema(11, .semibold)
    static let rigaSecondario = fisso(11)
    static let rigaNome = fisso(13, .semibold)
    static let rigaFreccia = fisso(17)
    static let dataGiorno = arrotondato(19, .semibold)
    static let dataMese = fisso(9.5, .bold)
    static let eveTitolo = contenuto(13, .semibold)
    static let eveTesto = contenuto(11)
    static let avatar = arrotondato(13, .semibold)

    // Rubrica (Clienti)
    static let indiceTitolo = contenuto(11.5, .semibold)
    static let contatore = contenuto(11, .bold)
    static let rubricaNome = contenuto(14, .bold)
    static let rubricaTema = contenuto(11)
    static let rubricaFreccia = contenuto(20, .bold)
    static let rubricaPiede = contenuto(11)
    static let profiloOcchiello = contenuto(10.5, .semibold)
    static let profiloNome = contenuto(22, .bold)
    static let profiloTema = contenuto(12)
    static let stellaGrande = contenuto(26)
    static let pulsanteCuoio = contenuto(11.5, .medium)
    static let schedaRubrica = contenuto(12, .semibold)
    static let sezioneOcchiello = contenuto(11, .semibold)
    static let sezioneSottile = contenuto(11)
    static let metricaEtichetta = contenuto(11)
    static let metricaValore = contenuto(24, .medium)
    static let campoEtichetta = contenuto(11)
    static let campoValore = contenuto(13)
    static let schedaAppTitolo = contenuto(13, .bold)
    static let pulsanteAqua = contenuto(12.5, .medium)
    static let moduloTitolo = sistema(15, .semibold)

    // Analisi (Posizioni)
    static let railTitolo = contenuto(14, .bold)
    static let railEtichetta = contenuto(10.5, .semibold)
    static let segAnalisi = contenuto(11.5, .medium)
    static let navAnalisi = contenuto(12.5, .medium)
    static let navAnalisiAttiva = contenuto(12.5, .semibold)
    static let kpiTitolo = contenuto(11)
    static let kpiValore = contenuto(20, .semibold)
    static let kpiNota = contenuto(11)
    static let chip = contenuto(10.5, .medium)
    static let pill = contenuto(10.5, .semibold)
    static let pannelloAnalisi = contenuto(14, .semibold)
    static let tabellaTesta = contenuto(11.5, .semibold)
    static let tabellaCella = contenuto(12)
    static let tabellaCellaForte = contenuto(13, .semibold)
    static let assi = fisso(10)
    static let numeroTabella = contenuto(12).monospacedDigit()

    // Widget
    static let widgetTitolo = fisso(13, .semibold)
    static let widgetGiorno = fisso(30, .bold)
    static let widgetGiornoNome = fisso(13, .medium)
    static let widgetTesto = fisso(12)
    static let widgetNumero = fisso(22, .medium)
    static let piastrellaGiorno = fisso(42)
    static let piastrellaMese = fisso(11)
    static let kpiValoreWidget = fisso(16, .semibold)
    static let kpiEtichettaWidget = fisso(11)
    static let portafoglioTotale = fisso(26, .bold)
    static let widgetMetricaValore = fisso(17)
    static let widgetMetricaEtichetta = fisso(10)
    static let calendarioMese = fisso(13, .bold)
    static let calendarioGiornoSettimana = fisso(17, .medium)
    static let calendarioNumero = fisso(70, .light)
    static let calendarioAnno = fisso(12)
    static let calendarioOra = fisso(13, .bold)
    static let clienteNome = fisso(21, .bold)
    static let cartoncinoValore = fisso(19, .medium)
    static let borsaTotale = fisso(30, .light)
    static let borsaRiga = fisso(13, .medium)
    static let borsaPillola = fisso(12, .bold)
    /// Ex scrittura a mano delle note: nel tema anche le note sono in SF.
    static let manoTitolo = sistema(19, .bold)
    static let mano = sistema(14)
    static let manoPiccola = sistema(12)
    static let promemoriaTitolo = contenuto(18, .bold)

    // Agenda e Attività: i titoli delle pagine (prima in Georgia) sono SF semibold
    static func serif(_ dimensione: CGFloat, corsivo: Bool = false) -> Font {
        let carattere = sistema(dimensione, .semibold)
        return corsivo ? carattere.italic() : carattere
    }
    static let agendaOcchiello = contenuto(10.5, .semibold)
    static let agendaTitolo = contenuto(21, .medium)
    static let agendaPeriodo = contenuto(12)
    static let targhettaMese = fisso(9.5, .bold)
    static let targhettaGiorno = arrotondato(24, .semibold)
    static let targhettaSettimana = fisso(9)
    static let giornoSettimana = contenuto(11)
    static let giornoNumero = contenuto(22)
    static let giornoNota = contenuto(10)
    static let paginaOcchiello = contenuto(10.5, .semibold)
    static let paginaTitolo = serif(18)
    static let paginaNota = contenuto(11)
    static let eventoOra = contenuto(12, .semibold)
    static let eventoFine = contenuto(11)
    static let eventoTitolo = contenuto(14, .semibold)
    static let eventoCliente = contenuto(12)
    static let eventoDettagli = contenuto(11)
    static let eventoFreccia = contenuto(22, .medium)
    static let etichettaStato = contenuto(9.5, .semibold)
    static let notaSettimana = contenuto(11)
    static let notaSettimanaForte = contenuto(11, .medium)
    static let dettaglioOcchiello = contenuto(10, .semibold)
    static let dettaglioTitolo = serif(22)
    static let dettaglioCliente = contenuto(12)
    static let voceEtichetta = contenuto(11)
    static let voceValore = contenuto(13)
    static let simboloQuieto = contenuto(28)
    static let quietoTitolo = serif(21)
    static let quietoTesto = contenuto(12)
    static let quietoSuggerimento = contenuto(10)
    static let vuotoData = serif(30, corsivo: true)
    static let vuotoTitolo = serif(18)
    static let vuotoTesto = contenuto(11)
    static let pulsantePiccolo = contenuto(10)
    static let cellaMese = contenuto(13)
    static let attivitaNumero = contenuto(22, .light)
    static let attivitaNumeroEtichetta = contenuto(11)
    static let elencoTitolo = contenuto(11)
    static let attivitaTitolo = contenuto(14, .semibold)
    static let attivitaSotto = contenuto(11)
    static let spunta = Font.system(size: 12, weight: .bold)

    // Incontri
    static let incontroDomanda = serif(17)
    static let incontroTitolo = contenuto(14, .semibold)
    static let incontroTesto = contenuto(13)
    static let incontroNota = contenuto(11)
    static let incontroOcchiello = contenuto(10, .semibold)
    static let incontroScrittura = sistema(15)

    // Profilo dei bisogni
    static let bisognoTitolo = contenuto(13, .bold)
    static let bisognoTesto = contenuto(12)
    static let bisognoNota = contenuto(10)
    static let bisognoArea = contenuto(10, .semibold)
    static let ruotaCentro = contenuto(10, .semibold)
    static let ruotaValore = contenuto(14, .bold)
    static let prioritaNumero = serif(22)

    // Eve
    static let eveOcchiello = contenuto(10.5, .semibold)
    static let eveSaluto = contenuto(21, .bold)
    static let eveSottotitolo = contenuto(12)
    static let eveAvviso = contenuto(11, .semibold)
    static let eveAvvisoNota = contenuto(11)
    static let eveIntestazione = contenuto(12, .semibold)
    static let eveDisplay = contenuto(10, .semibold)
    static let eveAutore = contenuto(10, .semibold)
    static let eveTitoloRisposta = contenuto(14, .bold)
    static let eveMessaggio = contenuto(13)
    static let eveAzione = contenuto(11)
    static let eveSpunto = contenuto(11)
    static let eveCampo = contenuto(13)
    static let eveBenvenuto = serif(22)
    static let eveGiornataData = contenuto(15, .bold)
    static let eveTappa = contenuto(12, .semibold)
    static let eveTappaNota = contenuto(10)
    static let evePostit = sistema(14)
    static let eveQuadroNumero = contenuto(20, .light)

    // Strumenti di analisi
    static let consoleTitolo = contenuto(12, .semibold)
    static let consoleEtichetta = contenuto(12)
    /// Ex display a cristalli liquidi: cifre tabellari nel pozzetto.
    static let lcd = Font.system(size: 15, weight: .semibold).monospacedDigit()
    static let lcdUnita = contenuto(10, .semibold)
    static let risultatoOcchiello = contenuto(10, .semibold)
    static let risultatoGrande = contenuto(32, .semibold)
    static let risultatoNota = contenuto(12)
    static let risultatoDettaglio = contenuto(15, .medium)
    static let strumentoOcchiello = contenuto(10)
    static let strumentoTitolo = contenuto(22, .bold)
    static let strumentoTesto = contenuto(13)
    static let schedaAreaNumero = contenuto(11)
    static let schedaAreaTitolo = contenuto(18, .semibold)
    static let schedaAreaValore = contenuto(22, .semibold)
    static let schedaAreaNota = contenuto(12)
    static let schedaRisultati = contenuto(12)
    static let ipotesiTitolo = contenuto(12, .semibold)
    static let ipotesiCampo = contenuto(13)
    static let ipotesiNota = contenuto(11)
    static let metodo = contenuto(12)
    static let verdetto = contenuto(14)

    // Dock
    static let dockSuggerimento = fisso(12, .semibold)
    static let dockEtichetta = fisso(10, .medium)

    // Finestre
    static let finestraTitolo = fisso(13, .semibold)
    static let finestraContesto = sistema(11)
    static let finestraAffianca = sistema(15)
    /// I simboli ×, −, + sui semafori (7 pt nel tema, su cerchi da 13).
    static let semaforo = Font.system(size: 9, weight: .bold)
    static let appTitolo = sistema(17, .bold)
    static let appOcchiello = sistema(11, .medium)
    static let pannelloTitolo = contenuto(14, .semibold)
    static let pannelloTesto = contenuto(12)

    // Pulsanti ed etichette
    static let pulsanteBlu = sistema(12.5, .semibold)
    /// L'etichetta del canale va anche nei PDF: resta in Helvetica Neue alle misure di prima
    /// (le impaginazioni dei documenti non cambiano).
    static let etichettaCanale = Font.custom("Helvetica Neue", fixedSize: 11 * fattore).weight(.bold)
    static let etichettaCanalePiccola = Font.custom("Helvetica Neue", fixedSize: 9 * fattore).weight(.bold)

    // Impostazioni
    static let rigaTitolo = contenuto(13, .medium)
    static let rigaSottotitolo = contenuto(11)
    static let rigaValore = contenuto(11)
    static let schedaApp = sistema(12, .medium)
    static let interruttore = contenuto(11, .bold)
    static let informazioniOcchiello = contenuto(10, .semibold)
    static let informazioniTitolo = contenuto(22, .bold)
    static let informazioniTesto = contenuto(11)
    static let informazioniPiccolo = contenuto(10)
    static let intestazioneGruppo = contenuto(11, .semibold)
    static let numero = arrotondato(24, .semibold)
    static let numeroEtichetta = contenuto(10)

    // Avvisi
    static let avviso = sistema(12.5, .medium)

    // Icona Agenda (proporzioni del tema, vedi Design/Icone/LEGGIMI.txt): giorno SF leggero, mese SF bold
    static func agendaGiorno(_ lato: CGFloat) -> Font {
        Font.system(size: lato * 0.4395, weight: .light)
    }

    static func agendaMese(_ lato: CGFloat) -> Font {
        Font.system(size: lato * 0.1538, weight: .bold)
    }

    /// Spaziatura (tracking) del mese e del giorno sull'icona Agenda.
    static func agendaMeseSpaziatura(_ lato: CGFloat) -> CGFloat { lato * 0.0123 }
    static func agendaGiornoSpaziatura(_ lato: CGFloat) -> CGFloat { lato * -0.0146 }
}
