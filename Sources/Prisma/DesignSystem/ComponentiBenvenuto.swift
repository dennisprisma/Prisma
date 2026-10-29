import SwiftUI

// Schermata di benvenuto nel tema Liquid Glass (.lock): lo sfondo d'acqua, l'ora grande arrotondata,
// il marchio Prisma e il cursore «scorri per entrare» in una capsula di vetro leggero.
// Riepilogo delle app aperte (.switcher): schede chiare sul vetro del pannello.

extension Colori {
    enum Benvenuto {
        static let velo = Color.clear
        static let fasciaAlto = Color.clear
        static let fasciaBasso = Color.clear
        static let fasciaLuce = Color.clear
        static let fasciaBordo = Color.clear
        static let testo = Tema.Colore.inchiostroBenvenuto
        /// Ombra morbida dell'ora (0 2px 18px rgba(30,20,90,.22)).
        static let ombraTesto = Color(r: 30, g: 20, b: 90, a: 0.16)
        // Capsula di vetro del cursore
        static let binarioAlto = Tema.Colore.riempimentoLeggeroColorato
        static let binarioBasso = Tema.Colore.riempimentoLeggeroColorato
        static let binarioBordo = Tema.Colore.bordoVetro
        static let binarioOmbra = Color(r: 8, g: 40, b: 60, a: 0.14)
        static let binarioLuce = Color.clear
        static let scritta = Tema.Colore.inchiostro
        // Manopola (--thumb)
        static let cursoreAlto = Tema.Colore.cursore
        static let cursoreMezzoAlto = Tema.Colore.cursore
        static let cursoreMezzoBasso = Tema.Colore.cursore
        static let cursoreBasso = Tema.Colore.cursore
        static let cursoreBordo = Tema.Colore.bordoChip
        static let cursoreOmbra = Color(r: 0, g: 0, b: 0, a: 0.3)
        static let freccia = Tema.Colore.inchiostro
        // Riepilogo delle app aperte
        static let veloApp = Tema.Colore.velo
        static let schedaAlto = Tema.Colore.chip
        static let schedaBasso = Tema.Colore.chip
        static let schedaBordo = Tema.Colore.bordoChip
        static let schedaTitolo = Tema.Colore.inchiostro
        static let schedaCliente = Tema.Colore.inchiostroSecondario
        static let schedaStato = Tema.Colore.inchiostroTerziario
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
        /// Il marchio Prisma (icona della scrivania del tema).
        static let marchio: CGFloat = Tema.Misura.iconaBenvenuto
        /// Capsula del cursore 340 × 60 e manopola 50 × 50 (.lk-slide).
        static let binario = CGSize(width: 340, height: 60)
        static let raggioBinario: CGFloat = 30
        static let cursore = CGSize(width: 50, height: 50)
        static let raggioCursore: CGFloat = 25
        static let margineCursore: CGFloat = 5
        static let scrittaSinistra: CGFloat = 82
        /// Oltre questa parte della corsa il cursore apre.
        static let soglia: CGFloat = 0.8
        static let alto: CGFloat = 0.08
        static let basso: CGFloat = 0.05
        // Riepilogo delle app aperte
        /// Larghezza fissa e altezza massima: sotto il massimo il riquadro è alto quanto le schede.
        static let riepilogo = CGSize(width: 620, height: 470)
        /// Titolo (44), piede (52) e margini (2 × 24) della cornice dei moduli, oltre al contenuto.
        static let corniceModulo: CGFloat = 144
        /// Il messaggio "La scrivania è tutta tua." quando non ci sono app aperte.
        static let vuotoAltezza: CGFloat = 140
        static let iconaApp: CGFloat = Tema.Misura.iconaAppAperte
        static let colonne = 3
    }
}

extension Tipo {
    static let benvenutoOra = Tema.Testo.sf(104, .bold, arrotondato: true).monospacedDigit()
    static let benvenutoData = Tema.Testo.sf(22, .semibold)
    static let benvenutoMarchio = Tema.Testo.sf(20, .bold)
    static let benvenutoMarchioLeggero = Tema.Testo.sf(20)
    static let benvenutoScritta = Tema.Testo.sf(15, .medium)
    static let benvenutoFreccia = Tema.Testo.sf(16, .semibold)
    static let appApertaTitolo = Tema.Testo.sf(13, .semibold)
    static let appApertaCliente = Tema.Testo.didascalia
    static let appApertaStato = Tema.Testo.didascalia
}
