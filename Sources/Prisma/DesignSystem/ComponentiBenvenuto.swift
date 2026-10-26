import SwiftUI

// Schermata di benvenuto (#os-lock del template): lo sfondo della scrivania, la fascia con
// l'ora, il marchio Prisma e il cursore «scorri per entrare» di iOS 5.
// Riepilogo delle app aperte (.os-switcher-grid).

extension Colori {
    enum Benvenuto {
        static let velo = Color(r: 25, g: 60, b: 87, a: 0.12)
        static let fasciaAlto = Color(r: 39, g: 74, b: 102, a: 0.36)
        static let fasciaBasso = Color(r: 24, g: 62, b: 94, a: 0.3)
        static let fasciaLuce = Color(r: 214, g: 237, b: 245, a: 0.42)
        static let fasciaBordo = Color(r: 20, g: 52, b: 77, a: 0.4)
        static let testo = Color.white
        static let ombraTesto = Color(hex: "#25455e")
        static let binarioAlto = Color(r: 30, g: 61, b: 88, a: 0.35)
        static let binarioBasso = Color(r: 16, g: 45, b: 73, a: 0.47)
        static let binarioBordo = Color(hex: "#456681")
        static let binarioOmbra = Color(r: 19, g: 47, b: 77, a: 0.6)
        static let binarioLuce = Color(r: 224, g: 244, b: 255, a: 0.53)
        static let scritta = Color(hex: "#e3f1fa")
        static let cursoreAlto = Color(hex: "#f1f8fc")
        static let cursoreMezzoAlto = Color(hex: "#cfdee8")
        static let cursoreMezzoBasso = Color(hex: "#a5bdcf")
        static let cursoreBasso = Color(hex: "#d6e4ed")
        static let cursoreBordo = Color(hex: "#4b6b82")
        static let cursoreOmbra = Color(r: 8, g: 40, b: 69, a: 0.4)
        static let freccia = Color(hex: "#6f8aa0")
        static let collegamento = Color(hex: "#d7e8f3")
        static let nota = Color(r: 230, g: 242, b: 250, a: 0.75)
        // Riepilogo delle app aperte
        static let veloApp = Color(r: 19, g: 45, b: 67, a: 0.5)
        static let schedaAlto = Color(r: 255, g: 255, b: 255, a: 0.53)
        static let schedaBasso = Color(r: 208, g: 225, b: 237, a: 0.2)
        static let schedaBordo = Color(r: 186, g: 205, b: 216, a: 0.4)
        static let schedaTitolo = Color(hex: "#527288")
        static let schedaCliente = Color(hex: "#839caf")
        static let schedaStato = Color(hex: "#a1b4c1")
    }
}

extension Gradienti {
    static let fasciaBenvenuto = LinearGradient.verticale(Colori.Benvenuto.fasciaAlto, Colori.Benvenuto.fasciaBasso)
    static let binarioBenvenuto = LinearGradient.verticale(Colori.Benvenuto.binarioAlto, Colori.Benvenuto.binarioBasso)
    static let cursoreBenvenuto = LinearGradient.verticale([
        (Colori.Benvenuto.cursoreAlto, 0), (Colori.Benvenuto.cursoreMezzoAlto, 0.49),
        (Colori.Benvenuto.cursoreMezzoBasso, 0.5), (Colori.Benvenuto.cursoreBasso, 1),
    ])
    static let schedaAppAperta = LinearGradient.verticale(Colori.Benvenuto.schedaAlto, Colori.Benvenuto.schedaBasso)
}

extension Misure {
    enum Benvenuto {
        static let fascia: CGFloat = 15
        static let marchio: CGFloat = 85
        static let binario = CGSize(width: 310, height: 64)
        static let raggioBinario: CGFloat = 14
        static let cursore = CGSize(width: 75, height: 53)
        static let raggioCursore: CGFloat = 10
        static let margineCursore: CGFloat = 5
        static let scrittaSinistra: CGFloat = 87
        /// Oltre questa parte della corsa il cursore apre.
        static let soglia: CGFloat = 0.8
        static let alto: CGFloat = 0.07
        static let basso: CGFloat = 0.05
        // Riepilogo delle app aperte
        /// Larghezza fissa e altezza massima: sotto il massimo il riquadro è alto quanto le schede.
        static let riepilogo = CGSize(width: 620, height: 470)
        /// Titolo (44), piede (52) e margini (2 × 24) della cornice dei moduli, oltre al contenuto.
        static let corniceModulo: CGFloat = 144
        /// Il messaggio "La scrivania è tutta tua." quando non ci sono app aperte.
        static let vuotoAltezza: CGFloat = 140
        static let iconaApp: CGFloat = 57
        static let colonne = 3
    }
}

extension Tipo {
    static let benvenutoOra = Tipo.sistema(85, .ultraLight)
    static let benvenutoData = Tipo.sistema(17)
    static let benvenutoMarchio = Tipo.sistema(31, .medium)
    static let benvenutoMarchioLeggero = Tipo.sistema(31, .ultraLight)
    static let benvenutoMotto = Tipo.sistema(11)
    static let benvenutoScritta = Tipo.sistema(21, .light)
    static let benvenutoFreccia = Tipo.sistema(26, .bold)
    static let benvenutoCollegamento = Tipo.sistema(12)
    static let benvenutoNota = Tipo.sistema(9)
    static let appApertaTitolo = Tipo.sistema(12, .medium)
    static let appApertaCliente = Tipo.sistema(9)
    static let appApertaStato = Tipo.sistema(8)
}
