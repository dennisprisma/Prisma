import SwiftUI

// Gettoni del pannello «Aggiorna i valori» in Posizioni (giro 5, specifica 8): elenco della compagnia e griglia
// dei valori fermi. Nessun colore nuovo: solo alias dei colori del tema (dinamici chiari e scuri).

extension Tema.Colore {
    enum AggiornaValori {
        /// Riga da controllare: il fondo delle proposte (arancio leggero), come le pillole «attenzione».
        static let rigaInsolita = Colori.Analisi.attenzioneFondo
        /// Riga della griglia con il fuoco.
        static let rigaAttiva = Tema.Colore.rigaSopra
        /// Testo «fermo da N mesi».
        static let fermo = Colori.Analisi.attenzioneTesto
        /// Righe non applicabili (opacità) e segno della variazione.
        static let opacitaSpenta: Double = 0.55
        static let positivo = Tema.Colore.MotoriPosizioni.positivo
        static let negativo = Tema.Colore.MotoriPosizioni.negativo
        /// La casella spuntata (come il modulo dell'importazione) e quella vuota.
        static let spunta = Colori.Analisi.navBasso
        static let spuntaVuota = Colori.Analisi.kpiNota
        /// Il simbolo della griglia vuota: tutti i valori sono recenti.
        static let tuttoAggiornato = Tema.Colore.MotoriPosizioni.positivo

        /// Il colore di una variazione: verde se sale, rosso se scende, inchiostro a zero.
        static func segno(_ v: Double?) -> Color {
            guard let v, abs(v) >= 0.5 else { return Tema.Colore.inchiostro }
            return v > 0 ? positivo : negativo
        }
    }
}

extension Tema.Misura {
    enum AggiornaValori {
        static let margine = EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16)
        static let spazioSezioni: CGFloat = 14
        static let spazioCanali: CGFloat = 4
        static let segmenti: CGFloat = 380
        static let riquadroVuoto = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        static let campoData: CGFloat = 130
        static let tendinaScelta: CGFloat = 300
        static let rigaVerticale: CGFloat = 6
        // Elenco
        static let colonnaSpunta: CGFloat = 26
        static let colonnaRiga: CGFloat = 34
        static let colonnaPosizioneMinima: CGFloat = 200
        static let colonnaImporto: CGFloat = 120
        static let colonnaVariazione: CGFloat = 130
        static let colonnaEsito: CGFloat = 140
        // Griglia
        static let colonnaCliente: CGFloat = 130
        static let colonnaAttuale: CGFloat = 140
        static let campoValore: CGFloat = 104
        static let campoDataGriglia: CGFloat = 96
        static let campoVersato: CGFloat = 96
        static let colonnaVariazioneGriglia: CGFloat = 120
        /// Posizioni elencate nel riepilogo prima di «e altre N».
        static let riepilogoMassimo = 12
        /// Spazi piccoli: tra le parti di una cella, tra i comandi di una riga, tra le righe di testo.
        static let spazioCella: CGFloat = 6
        static let spazioComandi: CGFloat = 10
        static let spazioTesto: CGFloat = 2
        /// Tra titolo, valore e nota della tessera della variazione (come `KPI`).
        static let spazioTessera: CGFloat = 4
        /// Margine orizzontale delle celle con più righe (come `CellaTabella`).
        static let margineCella: CGFloat = 8
        /// Il filtro dell'ambito e dei canali nella griglia.
        static let segmentiAmbito: CGFloat = 300
        static let segmentiCanale: CGFloat = 260
        /// Il pulsante «Aggiorna i loro valori» nel modulo dell'importazione e i pulsanti di vetro del pannello.
        static let marginePulsante = EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
        static let margineRiquadro = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        /// Il pulsante «Aggiorna valori» nell'intestazione di Posizioni (come «Importa…» accanto).
        static let margineIngresso = EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        /// Il simbolo della griglia vuota.
        static let simboloVuoto: CGFloat = 22
    }
}

extension Tema.Testo {
    enum AggiornaValori {
        /// Il simbolo della griglia vuota.
        static let simboloVuoto = Tema.Testo.sf(22, .regular)
        /// Il segno nella spunta delle righe (come il modulo dell'importazione).
        static let spunta = Tema.Testo.sf(14)
        /// Il cliente e il prodotto del file di una riga non trovata.
        static let nonTrovata = Tema.Testo.corpo.italic()
    }
}
