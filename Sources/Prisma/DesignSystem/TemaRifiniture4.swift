#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

// MARK: - Gettoni delle rifiniture dei documenti su carta (gruppo 4)
// Prospetti, report, fascicolo e scheda di adeguatezza: misure, corpi e colori nuovi. Sempre su carta:
// colori fissi e opachi, niente vetro.

extension Misure.Documento {
    /// Spazio tra le schede di una fila di cifre (`FilaCifre`).
    static let spazioCifre: CGFloat = 6
    /// Righe della nota sotto una cifra in evidenza: va a capo invece di troncarsi.
    static let righeNotaCifra = 2
}

extension Tipo.Documento {
    /// Note dei prospetti da leggere davvero (metodo e dati delle ipotesi stimate): non sotto i 6,5 pt.
    static let pNotaLeggibile = sf(6.5)
}

extension Misure.Carta {
    /// Righe al massimo di una cella di testo nelle tabelle su carta: oltre, il testo si tronca.
    static let righeCella = 3
    /// Interlinea delle celle su più righe e margine sopra e sotto il testo della riga.
    static let interlineaCella: CGFloat = 1
    static let margineCella: CGFloat = 2.5
    /// Righe dell'intestazione di una colonna (le intestazioni lunghe vanno a capo, non si troncano).
    static let righeTesta = 2
    /// Spazio tra le etichette dei canali nella stessa cella.
    static let spazioEtichette: CGFloat = 4
    /// Riga del logo nella testata della prima pagina: alta quanto il logo con il genere sotto, che non c'è più.
    static let rigaLogoPrima: CGFloat = 24
}

extension Colori.Carta {
    /// La carta dei prospetti composti (posizione, confronto, portafoglio, riesame): bianca come quella dei
    /// prospetti dei motori (`FoglioProspetto`), perché le due famiglie abbiano la stessa veste.
    static let foglioProspetto = Colori.Documento.moderna.foglio
}

extension Tipo.Carta {
    /// Gemelli AppKit dei caratteri delle celle, per misurare le righe a capo.
    static let nsTabella = nsFont(8)
    static let nsTabellaForte = nsFont(8, grassetto: true)
}

extension Tipo.Report {
    /// Nella sala della presentazione (`documentoInSala`): il piede e le etichette dei valori finali dei grafici
    /// due punti più grandi, per leggerli da lontano. Nel PDF restano `piede` e il corpo del grafico.
    static let piedeSala = Tipo.Documento.sf(7.8)
    static let etichettaFinaleSala = Tipo.Documento.sf(8.5, grassetto: true)
}
