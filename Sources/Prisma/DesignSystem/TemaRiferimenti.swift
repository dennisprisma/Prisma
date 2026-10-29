import SwiftUI

// Gettoni del rendimento contro un riferimento (giro 6, specifica 11, §7.1): pannello «Contro un riferimento» nel
// dettaglio della posizione e scheda Impostazioni › Riferimenti. Le parti del TFR stanno in `TemaTFR.swift`.

extension Tema.Colore {
    enum Riferimenti {
        /// Linea «al ritmo del riferimento» nel grafico dell'andamento (il verde-acqua degli scenari favorevoli).
        static let linea = Color.dinamico(chiaro: Color(hex: "#5E928E"), scuro: Color(hex: "#8FC4BF"))
        /// Valore inserito dal consulente nella griglia delle Impostazioni (pallino e cifra).
        static let inseritoDaTe = Tema.Colore.accento
        /// Valore stimato o calcolato (TFR): cifra in grigio.
        static let calcolato = Tema.Colore.inchiostroTerziario
        /// Avviso «da aggiornare» e «ripiego».
        static let avviso = Tema.Colore.arancio
        /// Fondo del riquadro d'avviso quando il confronto non si può fare (come le pillole «attenzione»).
        static let fondoAvviso = Colori.Analisi.attenzioneFondo
        /// Valore di Prisma nella griglia.
        static let valorePrisma = Tema.Colore.inchiostro
        /// Pozzetto delle celle modificabili (come `CampoIpotesi`) e il suo bordo.
        static let pozzetto = Tema.Colore.pozzetto
        static let bordoPozzetto = Tema.Colore.separatore
        /// Testata della griglia, righe alterne e filetti.
        static let testa = Tema.Colore.inchiostroSecondario
        static let rigaAlterna = Tema.Colore.rigaSopra
        static let filetto = Tema.Colore.separatore
        /// Collegamenti «Apri i riferimenti ↗» e «TFR in azienda o nel fondo? ↗».
        static let collegamento = Colori.Colonna.collegamento
        /// Note e sintesi del pannello.
        static let nota = Colori.Analisi.kpiNota
        /// «Elimina l'indice».
        static let elimina = Colori.Analisi.erroreTesto
        /// Il valore rilevato e il versato nella legenda (come il grafico dell'andamento).
        static let valore = Colori.Analisi.linea
        static let versato = Colori.Analisi.lineaTratteggiata
    }
}

extension Tema.Misura {
    enum Riferimenti {
        /// Tendina del metro nella testata del pannello.
        static let tendinaMetro: CGFloat = 230
        /// Tendina del metro per tipo di posizione nelle Impostazioni.
        static let tendinaImpostazioni: CGFloat = 210
        /// Spazio tra i gettoni degli anni e quanti gettoni stanno su una riga.
        static let spazioAnni: CGFloat = 6
        static let gettoniPerRiga = 6
        /// Griglia delle Impostazioni: colonna dell'anno, colonne dei valori, altezza di una riga, pallino.
        static let colonnaAnno: CGFloat = 56
        static let colonnaValore: CGFloat = 96
        /// Le colonne dei valori si stringono fin qui se la finestra è stretta (sei colonne con tre indici).
        static let colonnaValoreMinima: CGFloat = 64
        static let rigaGriglia: CGFloat = 26
        static let pallino: CGFloat = 6
        /// Altezza del pozzetto di una cella e margini dentro e attorno.
        static let pozzettoCella: CGFloat = 20
        static let margineCella: CGFloat = 6
        static let margineCellaEsterno: CGFloat = 3
        static let spazioPallino: CGFloat = 4
        /// Margini della griglia dentro il gruppo e della nota sotto.
        static let margineGriglia = EdgeInsets(top: 6, leading: 10, bottom: 8, trailing: 10)
        static let spazioNotaGriglia: CGFloat = 4
        /// Pannello del dettaglio: spazio tra i blocchi, tra le voci della legenda, tra gli elementi della testata.
        static let spazioPannello: CGFloat = 14
        static let spazioLegenda: CGFloat = 16
        static let spazioTestata: CGFloat = 8
        static let spazioTesti: CGFloat = 6
        /// Riquadro d'avviso quando il confronto non si può fare.
        static let margineAvviso = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        static let spazioAvviso: CGFloat = 8
        /// Pulsanti di vetro del pannello e delle Impostazioni.
        static let marginePulsante = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        /// Popover di un indice.
        static let larghezzaPopover: CGFloat = 320
        static let marginePopover: CGFloat = 14
        static let spazioPopover: CGFloat = 10
        static let spazioCampo: CGFloat = 4
        static let spazioPulsanti: CGFloat = 6
    }
}

extension Tema.Raggio {
    enum Riferimenti {
        /// Pozzetto delle celle (come `CampoIpotesi`) e riquadro d'avviso.
        static let cella = Tema.Raggio.miniatura
        static let avviso = Tema.Raggio.tessera
    }
}

extension Tema.Testo {
    enum Riferimenti {
        static let cellaGriglia = Tema.Testo.Componenti.numero
        static let cellaGrigliaInserita = Tema.Testo.sf(12, .semibold).monospacedDigit()
        static let testaGriglia = Tema.Testo.didascalia
        /// Anno della griglia.
        static let annoGriglia = Tema.Testo.sf(12, .medium).monospacedDigit()
        /// Avvisi, note e sintesi del pannello (come le note dell'andamento).
        static let nota = Tipo.kpiNota
        static let collegamento = Tipo.colonnaCollegamento
        /// Etichetta dei campi del popover di un indice.
        static let campo = Tipo.chip
    }
}
