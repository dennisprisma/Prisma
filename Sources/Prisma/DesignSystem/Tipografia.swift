import AppKit
import SwiftUI

/// Caratteri del template.
/// - "sistema": Lucida Grande, con ripiego su Helvetica Neue (stesso ordine del CSS)
/// - "contenuto": Helvetica Neue
enum Tipo {
    static let lucidaDisponibile: Bool = NSFont(name: "LucidaGrande", size: 12) != nil

    static func sistema(_ dimensione: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        let nome = lucidaDisponibile ? "Lucida Grande" : "Helvetica Neue"
        return Font.custom(nome, fixedSize: dimensione).weight(peso)
    }

    static func contenuto(_ dimensione: CGFloat, _ peso: Font.Weight = .regular) -> Font {
        Font.custom("Helvetica Neue", fixedSize: dimensione).weight(peso)
    }

    // Barra superiore
    static let barraLogo = sistema(25, .bold)
    static let barraMarchio = sistema(12, .bold)
    static let barraOS = sistema(9)
    static let barraApp = sistema(11, .bold)
    static let barraOra = sistema(11)
    static let barraTasto = sistema(10)
    static let barraAvatar = sistema(9, .semibold)
    static let badgePiccolo = sistema(8)

    // Scrivania
    static let scrivaniaKicker = sistema(9)
    static let scrivaniaTitolo = contenuto(26)
    static let scrivaniaSottotitolo = sistema(11)
    static let scrivaniaSezione = contenuto(13)
    static let scrivaniaPiede = contenuto(9)
    static let pulsanteVetro = sistema(11)
    static let lanciatoreNome = contenuto(12, .bold)
    static let lanciatoreSottotitolo = contenuto(10)
    static let badgeGrande = contenuto(10, .bold)

    // Colonna del cliente
    static let colonnaEtichetta = contenuto(9)
    static let colonnaNome = contenuto(17, .bold)
    static let colonnaTema = contenuto(11)
    static let colonnaScheda = sistema(11)
    static let colonnaIntestazione = sistema(9, .bold)
    static let colonnaCollegamento = sistema(10)
    static let rigaSecondario = contenuto(10)
    static let rigaNome = contenuto(13, .medium)
    static let rigaFreccia = contenuto(17)
    static let dataGiorno = contenuto(21)
    static let dataMese = contenuto(8)
    static let eveTitolo = contenuto(12, .bold)
    static let eveTesto = contenuto(10)
    static let avatar = contenuto(13, .medium)

    // Rubrica (Clienti)
    static let indiceTitolo = contenuto(11, .heavy)
    static let contatore = contenuto(11, .black)
    static let rubricaNome = contenuto(14, .bold)
    static let rubricaTema = contenuto(11)
    static let rubricaFreccia = contenuto(20, .bold)
    static let rubricaPiede = contenuto(11)
    static let profiloOcchiello = contenuto(9, .semibold)
    static let profiloNome = contenuto(22, .medium)
    static let profiloTema = contenuto(12)
    static let stellaGrande = contenuto(26)
    static let pulsanteCuoio = contenuto(11)
    static let schedaRubrica = contenuto(12, .bold)
    static let sezioneOcchiello = contenuto(11, .semibold)
    static let sezioneSottile = contenuto(11)
    static let metricaEtichetta = contenuto(11)
    static let metricaValore = contenuto(24, .medium)
    static let campoEtichetta = contenuto(11)
    static let campoValore = contenuto(13)
    static let schedaAppTitolo = contenuto(13, .bold)
    static let pulsanteAqua = contenuto(12)
    static let moduloTitolo = sistema(15)

    // Widget
    static let widgetTitolo = sistema(11, .bold)
    static let widgetGiorno = contenuto(30, .bold)
    static let widgetGiornoNome = contenuto(13, .medium)
    static let widgetTesto = contenuto(12)
    static let widgetNumero = contenuto(22, .medium)

    // Dock
    static let dockSuggerimento = sistema(11, .bold)

    // Finestre
    static let finestraTitolo = sistema(12)
    static let finestraContesto = sistema(10)
    static let finestraAffianca = sistema(16)
    static let semaforo = Font.custom("Arial", fixedSize: 11)
    static let appTitolo = sistema(17)
    static let appOcchiello = sistema(9)
    static let pannelloTitolo = contenuto(14, .semibold)
    static let pannelloTesto = contenuto(12)

    // Pulsanti ed etichette
    static let pulsanteBlu = sistema(12, .bold)
    static let etichettaCanale = contenuto(11, .bold)
    static let etichettaCanalePiccola = contenuto(9, .bold)

    // Impostazioni
    static let rigaTitolo = contenuto(13, .bold)
    static let rigaSottotitolo = contenuto(10)
    static let rigaValore = contenuto(11)
    static let schedaApp = sistema(12)
    static let interruttore = contenuto(11, .bold)
    static let informazioniOcchiello = contenuto(8, .semibold)
    static let informazioniTitolo = contenuto(24)
    static let informazioniTesto = contenuto(11)
    static let informazioniPiccolo = contenuto(9)
    static let intestazioneGruppo = contenuto(10, .semibold)
    static let numero = contenuto(26, .light)
    static let numeroEtichetta = contenuto(10)

    // Avvisi
    static let avviso = sistema(10)

    // Icona Agenda (proporzioni ricavate dai tracciati dell'SVG originale)
    static func agendaGiorno(_ lato: CGFloat) -> Font {
        Font.custom("HelveticaNeue-CondensedBold", fixedSize: lato * 0.64)
    }

    static func agendaMese(_ lato: CGFloat) -> Font {
        Font.custom("Helvetica Neue", fixedSize: lato * 0.13).weight(.medium)
    }
}
