import SwiftUI

// Gettoni della scheda di adeguatezza (giro 4, specifica 1): il pannello nel dettaglio della proposta, la scheda
// «Proposte» delle Impostazioni e il PDF su carta. Nessun colore nuovo: solo alias dei colori del tema (dinamici
// chiari e scuri) e, sulla carta, i colori fissi di `paletteDocumento` (`coloreSemaforo`).

extension Tema.Misura {
    /// Il pannello «Scheda di adeguatezza» nel dettaglio della proposta.
    enum Adeguatezza {
        static let colonnaScelte: CGFloat = 300
        static let pallino: CGFloat = 9
        static let spazioRighe: CGFloat = 8
        static let spazioColonne: CGFloat = 24
        static let spazioSezioni: CGFloat = 14
        static let altezzaMotivazione: CGFloat = 76
        static let margineRiga = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        static let spazioPallino: CGFloat = 10
        static let larghezzaPopover: CGFloat = 340
        /// Tra il titolo e il campo di una scelta, tra le righe di testo di una voce.
        static let spazioCampo: CGFloat = 4
        static let spazioTesto: CGFloat = 2
        /// Una voce dell'elenco dei documenti: spazio tra casella e testo, margine verticale.
        static let spazioSpunta: CGFloat = 8
        static let margineDocumento = EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        /// I pulsanti del PDF e della firma (come quelli della barra del dettaglio).
        static let marginePulsante = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        static let spazioPulsanti: CGFloat = 6
        /// Il campo della motivazione: margine del testo e del segnaposto.
        static let margineMotivazione = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        static let raggioMotivazione: CGFloat = 8
        /// Il popover di una voce in Impostazioni › Proposte.
        static let marginePopover: CGFloat = 14
        static let spazioPopover: CGFloat = 10
        static let menuPer: CGFloat = 300
        /// Le voci non pertinenti, attenuate.
        static let opacitaNonPertinente: Double = 0.5
    }
}

extension Tema.Colore {
    enum Adeguatezza {
        static let verde = Tema.Colore.testoInEssere
        static let giallo = Tema.Colore.testoProposta
        static let rosso = Tema.Colore.scadenzaOra
        static let grigio = Tema.Colore.inchiostroTerziario
        /// La casella spuntata dei documenti (come le proposte degli Incontri) e quella vuota.
        static let spunta = Colori.Analisi.navBasso
        static let spuntaVuota = Tema.Colore.inchiostroSecondario
        /// Testi del pannello.
        static let testo = Colori.Analisi.tabellaTesto
        static let nota = Colori.Analisi.kpiNota
        static let riga = Colori.Analisi.tabellaRiga
        static let collegamento = Colori.Colonna.collegamento
        static let elimina = Colori.Analisi.erroreTesto
        /// Il campo della motivazione (pozzetto del tema) e il segnaposto.
        static let campo = Tema.Colore.pozzetto
        static let segnaposto = Tema.Colore.inchiostroTerziario

        static func semaforo(_ s: Semaforo) -> Color {
            switch s {
            case .verde: return verde
            case .giallo: return giallo
            case .rosso: return rosso
            case .grigio: return grigio
            }
        }
    }
}

extension Pillola.Tono {
    /// verde → .ok, giallo → .attenzione, rosso → .errore, grigio → .neutro
    static func semaforo(_ s: Semaforo) -> Pillola.Tono {
        switch s {
        case .verde: return .ok
        case .giallo: return .attenzione
        case .rosso: return .errore
        case .grigio: return .neutro
        }
    }
}

extension Misure.Documento {
    /// La scheda di adeguatezza su carta.
    static let spuntaCarta: CGFloat = 8.5
    static let trattoSpunta: CGFloat = 0.8
    static let segnoSpunta: CGFloat = 1.1
    static let pallinoCarta: CGFloat = 6
    static let altezzaFirma: CGFloat = 34
    /// La linea su cui si firma e lo spazio tra la linea e l'etichetta.
    static let lineaFirma: CGFloat = 0.8
    static let spazioEtichettaFirma: CGFloat = 3
    static let spazioFirme: CGFloat = 18
    static let rigaControllo: CGFloat = 44
    static let rigaDocumento: CGFloat = 17
    static let rigaEsperienza: CGFloat = 14
    /// Oltre 12 documenti la riga si abbassa di 3 punti; oltre 16 si scrivono i primi 16.
    static let documentiPieni = 12
    static let documentiMassimi = 16
    static let rigaDocumentoStretta: CGFloat = 3
    /// La testa delle tabelle della scheda, la colonna della data e lo spazio tra le sezioni.
    static let testaScheda: CGFloat = 18
    static let colonnaData: CGFloat = 90
    static let spazioScheda: CGFloat = 10
    static let spazioSchedaPiccolo: CGFloat = 4
    /// Righe di testo della colonna «Cosa risulta».
    static let righeCosaRisulta = 4
}
