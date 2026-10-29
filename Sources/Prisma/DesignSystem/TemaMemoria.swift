import SwiftUI

// Gettoni della memoria del riesame (specifica 12, giro 6), ricavati dal tema Liquid Glass:
// colori dinamici chiari e scuri già esistenti, nessun valore sparso nelle viste.

extension Tema.Colore {
    enum Memoria {
        /// In meglio: il verde del testo «in essere».
        static let meglio = Tema.Colore.testoInEssere
        /// In peggio: il rosso delle scadenze.
        static let peggio = Tema.Colore.scadenzaOra
        /// Da non giudicare (profilo, famiglia, patrimonio, semafori grigi).
        static let neutro = Tema.Colore.inchiostroSecondario

        static func verso(_ v: VariazioneRiesame.Verso) -> Color {
            switch v {
            case .meglio: return meglio
            case .peggio: return peggio
            case .neutro: return neutro
            }
        }

        /// Pallino della fotografia più recente nella linea del tempo, e delle altre.
        static let pallinoUltima = Tema.Colore.accento
        static let pallino = Tema.Colore.inchiostroSecondario
        /// Il filo verticale della linea del tempo e i fili tra le righe del pannello.
        static let linea = Tema.Colore.separatore
        /// Il testo delle variazioni (resta inchiostro: la riga si legge anche senza colori).
        static let testo = Tema.Colore.inchiostro
        static let secondario = Tema.Colore.inchiostroSecondario
        /// I collegamenti («Mostra tutte», «Cronologia ↗»).
        static let collegamento = Tema.Colore.link

        /// verde → verde del tema, giallo → arancio, rosso → rosso; grigio e sconosciuti → inchiostro secondario.
        static func semaforo(_ s: Semaforo?) -> Color {
            switch s {
            case .verde?: return Tema.Colore.verde
            case .giallo?: return Tema.Colore.arancio
            case .rosso?: return Tema.Colore.rosso
            case .grigio?, nil: return Tema.Colore.inchiostroSecondario
            }
        }
    }
}

extension Tema.Misura {
    enum Memoria {
        /// Spazio tra le sezioni della scheda Riesami.
        static let spazioSezioni: CGFloat = 14
        /// Spazio tra l'occhiello e il suo contenuto.
        static let spazioOcchiello: CGFloat = 8
        static let spazioPulsanti: CGFloat = 8
        static let marginePannello: CGFloat = 12
        static let spazioRiga: CGFloat = 8
        /// Spazio verticale tra le righe del pannello delle variazioni.
        static let righePannello: CGFloat = 7
        /// Spazio tra le righe compatte (riquadri brevi e piede della scheda).
        static let righeCompatte: CGFloat = 5
        static let colonnaSimbolo: CGFloat = 16
        static let colonnaDifferenza: CGFloat = 92
        static let staccoMinimo: CGFloat = 10
        static let colonnaLinea: CGFloat = 22
        static let pallino: CGFloat = 9
        /// Il pallino si allinea alla prima riga della scheda (la data).
        static let altezzaPallino: CGFloat = 16
        static let linea: CGFloat = 1.5
        static let colonnaCifra: CGFloat = 150
        static let spazioCifre: CGFloat = 10
        /// Spazio tra l'etichetta e il valore di una cifra della scheda.
        static let spazioCifra: CGFloat = 3
        static let pallinoSemaforo: CGFloat = 7
        static let spazioPallini: CGFloat = 3
        /// Spazio tra i gruppi di pallini di colore diverso.
        static let spazioGruppiPallini: CGFloat = 6
        static let spazioSchede: CGFloat = 10
        /// Spazio tra la testata, le cifre e il piede della scheda di una fotografia.
        static let spazioScheda: CGFloat = 10
        static let spazioTestata: CGFloat = 8
        static let pillole: CGFloat = 4
        /// Colonna «Dal dossier» degli incontri: stacco sopra l'occhiello e spazio tra le righe (come «L'ULTIMA VOLTA»).
        static let staccoOcchielloIncontro: CGFloat = 6
        static let righeIncontro: CGFloat = 6
        /// Spaziatura dell'occhiello della colonna degli incontri (la stessa degli altri occhielli della colonna).
        static let trackingOcchielloIncontro: CGFloat = 0.8
        /// Spazio tra il testo e l'etichetta del canale nelle righe compatte.
        static let spazioCanale: CGFloat = 6
    }
}

extension Tema.Raggio {
    enum Memoria {
        static let pannello: CGFloat = Tema.Raggio.riga
        static let scheda: CGFloat = Tema.Raggio.riga
    }
}

extension Tema.Testo {
    enum Memoria {
        static let simbolo = Tema.Testo.sf(11, .semibold)
        /// La differenza («−230 €/mese»), cifre tabellari.
        static let differenza = Tema.Testo.sf(12, .semibold).monospacedDigit()
        /// Il valore di una cifra della scheda della fotografia.
        static let cifra = Tema.Testo.sf(13, .semibold).monospacedDigit()
        /// Il simbolo del cestino della scheda.
        static let elimina = Tema.Testo.sf(11.5)
        /// I collegamenti («Mostra tutte», «Cronologia ↗»).
        static let collegamento = Tema.Testo.sf(11.5, .medium)
    }
}
