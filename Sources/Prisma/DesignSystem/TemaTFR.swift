import SwiftUI

// Gettoni del confronto «TFR in azienda o nel fondo» (giro 6, specifica 11 §7.1): Simulazioni › TFR a schermo
// (stessa console a cristalli liquidi del simulatore) e il prospetto e il report su carta. Nessun colore nuovo:
// a schermo solo alias dei colori del tema (dinamici chiari e scuri); su carta solo la tavolozza del documento.

extension Tema.Colore {
    enum TFR {
        /// Le tre strade nei grafici e nei pallini a schermo.
        static let azienda = Colori.Analisi.barre
        static let fondo = Colori.Analisi.area(.previdenza)
        static let fondoContributi = Colori.Analisi.linea
        /// Le quote di TFR accantonate (linea tratteggiata del grafico).
        static let quote = Colori.Analisi.lineaTratteggiata
        /// «La scelta non si può revocare» e gli avvisi della vista.
        static let avviso = Tema.Colore.arancio
        /// Differenze a favore o contro il fondo.
        static let positivo = Colori.Strumenti.positivo
        static let negativo = Colori.Strumenti.negativo
        /// Etichette, note e collegamenti (come il risultato del simulatore).
        static let etichetta = Colori.Strumenti.consoleEtichetta
        static let titolo = Colori.Strumenti.consoleTitolo
        static let cifra = Colori.Strumenti.risultato
        static let nota = Colori.Strumenti.risultatoNota
        static let notaKPI = Colori.Analisi.kpiNota
        static let collegamento = Colori.Colonna.collegamento
        static let spia = Colori.Strumenti.spia
        static let filo = Tema.Colore.separatore

        /// Il colore di una differenza: verde se il fondo è avanti, rosso se è indietro, inchiostro se pari.
        static func segno(_ v: Double) -> Color {
            if v > TestiTFR.sogliaEquivalenza { return positivo }
            if v < -TestiTFR.sogliaEquivalenza { return negativo }
            return cifra
        }
    }
}

extension Tema.Misura {
    enum TFR {
        /// Spazio tra le colonne delle cifre grandi del risultato.
        static let spazioCifre: CGFloat = 18
        /// Tabella anno per anno a schermo: tutti gli anni fino a `anniTabellaCompleta`, poi uno ogni `passoTabella`.
        static let anniTabellaCompleta = 15
        static let passoTabella = 5
        static let colonnaTabella: CGFloat = 104
        static let colonnaAnnoTabella: CGFloat = 64
        /// Pallino del colore della strada sotto le cifre grandi e spia della barra.
        static let pallino: CGFloat = 8
        static let spia: CGFloat = 7
        /// Console e risultati (come il simulatore).
        static let margineConsole = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        static let margineRisultati = EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22)
        static let spazioConsole: CGFloat = 16
        static let spazioRisultati: CGFloat = 16
        static let spazioScelta: CGFloat = 6
        static let spazioTestata: CGFloat = 8
        static let spazioLegenda: CGFloat = 16
        static let spazioCifra: CGFloat = 4
        static let spazioPallino: CGFloat = 6
        static let spazioTesti: CGFloat = 1
        /// Margine dei pulsanti di vetro della testata (come la barra di Prospetti).
        static let marginePulsante = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        /// Margine del riquadro «Dal dossier» nel rail.
        static let margineRail: CGFloat = 3
        /// Ritardo prima di scrivere le ipotesi nell'archivio, dopo l'ultimo movimento di un cursore (nanosecondi).
        static let pausaSalvataggio: UInt64 = 600_000_000
    }
}

extension Tema.Testo {
    enum TFR {
        /// La cifra grande del risultato e il suo occhiello (come il simulatore).
        static let cifraTFR = Tipo.risultatoGrande
        static let occhielloTFR = Tipo.risultatoOcchiello
        static let tracciatoOcchiello: CGFloat = 1.2
        static let notaCifra = Tipo.risultatoNota
        static let etichettaCifra = Tipo.kpiNota
        static let etichettaConsole = Tipo.consoleEtichetta
        static let titoloBarra = Tipo.consoleTitolo
        static let testo = Tipo.strumentoTesto
        static let nota = Tipo.kpiNota
        static let collegamento = Tipo.colonnaCollegamento
        static let fondo = Tipo.chip
    }
}

// MARK: - Su carta

extension Misure.Documento {
    /// Misure del prospetto e del report del TFR.
    enum TFR {
        // Prospetto (A4 verticale)
        static let spazioPagina: CGFloat = 10
        static let spazioTesta: CGFloat = 4
        static let spazioCampi: CGFloat = 14
        static let spazioCifre: CGFloat = 6
        static let colonnaData: CGFloat = 90
        static let rigaTabella: CGFloat = 14
        static let rigaAnno: CGFloat = 13
        static let testaTabella: CGFloat = 12
        static let margineCella: CGFloat = 4
        static let spazioElenco: CGFloat = 3
        static let graficoProspetto: CGFloat = Misure.Documento.Motori.graficoMontante
        /// Tutti gli anni fino a 25; oltre, un anno sì e uno no più l'ultimo (al massimo 26 righe).
        static let anniTabellaCompleta = 25
        static let righeTabellaMassime = 26
        /// Etichette dell'asse degli anni: una ogni 5 anni.
        static let passoAsse = 5
        static let opacitaFondoGrafico: Double = 0.5
        // Report (A4 orizzontale)
        static let spazioSlide: CGFloat = 16
        static let spazioRiquadri: CGFloat = 12
        static let margineRiquadro: CGFloat = 16
        static let spazioRiquadro: CGFloat = 6
        static let graficoReport: CGFloat = Misure.Documento.Motori.graficoMontanteReport
        static let graficoReportBreve: CGFloat = 200
        static let barra: CGFloat = 30
        static let barraMinima: CGFloat = 40
        static let spazioBarre: CGFloat = 8
        static let colonnaEtichettaBarra: CGFloat = 130
        static let raggioBarra: CGFloat = 3
        static let spazioPunti: CGFloat = 6
        static let interlinea: CGFloat = 1.5
    }
}
