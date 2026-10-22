import AppKit
import SwiftUI

// Stile dei documenti per i clienti (report A4 orizzontale e prospetto A4 verticale).
// È lo stile scelto da Denis con i suoi esempi (Orizzonte Valore, ottobre 2026): pulito e moderno,
// diverso dall'interfaccia iOS 5 dell'app. Titoli in Avenir Next, testo in Helvetica Neue,
// verde, blu e rosso per i tre scenari, ardesia e ocra per Gestione separata e Fondo Interno.

extension Colori {
    enum Documento {
        static let foglio = Color.white
        static let notte = Color(hex: "#1b2a41")
        static let notteRiquadro = Color(hex: "#2d3c55")
        static let notteEtichetta = Color(hex: "#8fa1bd")
        static let notteTesto = Color(hex: "#e9eef5")
        static let titolo = Color(hex: "#1d2737")
        static let testo = Color(hex: "#2b3342")
        static let tenue = Color(hex: "#5f6b7a")
        static let occhiello = Color(hex: "#5f6b7a")
        static let riquadro = Color(hex: "#f2f4f7")
        static let filetto = Color(hex: "#e3e6ea")
        static let filettoForte = Color(hex: "#1d2737")
        static let favorevole = Color(hex: "#2e7d5b")
        static let intermedio = Color(hex: "#2f5ea8")
        static let sfavorevole = Color(hex: "#c0553a")
        static let favorevoleFondo = Color(hex: "#e6efe9")
        static let intermedioFondo = Color(hex: "#e5ebf3")
        static let sfavorevoleFondo = Color(hex: "#f6e7e4")
        static let gestioneSeparata = Color(hex: "#6f86a6")
        static let fondoInterno = Color(hex: "#c4913f")
        static let negativo = Color(hex: "#c0553a")
        static let positivo = Color(hex: "#2e7d5b")
        static let evidenza = Color(hex: "#e7ecf4")
        static let evidenzaTitolo = Color(hex: "#2f5ea8")
        static let barraLaterale = Color(hex: "#1f3a5f")
        static let bloccato = Color(hex: "#eef0f3")
        static let penaleForte = Color(hex: "#b5513a")
        static let penaleMedia = Color(hex: "#c9806f")
        static let penaleLieve = Color(hex: "#e0b5ab")
        static let griglia = Color(hex: "#e6e8ec")
        static let premio = Color(hex: "#7d8796")

        static func scenario(_ t: TipoScenario) -> Color {
            switch t {
            case .favorevole: return favorevole
            case .intermedio: return intermedio
            case .sfavorevole: return sfavorevole
            }
        }

        static func scenarioFondo(_ t: TipoScenario) -> Color {
            switch t {
            case .favorevole: return favorevoleFondo
            case .intermedio: return intermedioFondo
            case .sfavorevole: return sfavorevoleFondo
            }
        }

        static func parte(_ t: ComponenteContratto.Tipo) -> Color {
            t == .gestioneSeparata ? gestioneSeparata : fondoInterno
        }
    }
}

extension Tipo {
    enum Documento {
        static let titoli = "Avenir Next"
        static let testo = "Helvetica Neue"

        /// Avenir Next ha pesi per nome; Helvetica Neue si appesantisce con `.weight`.
        static func avenir(_ dimensione: CGFloat, _ peso: String = "Regular") -> Font {
            Font.custom("AvenirNext-\(peso)", fixedSize: dimensione)
        }

        static func helvetica(_ dimensione: CGFloat, grassetto: Bool = false) -> Font {
            Font.custom(testo, fixedSize: dimensione).weight(grassetto ? .bold : .regular)
        }

        static func nsHelvetica(_ dimensione: CGFloat) -> NSFont {
            NSFont(name: testo, size: dimensione) ?? NSFont.systemFont(ofSize: dimensione)
        }

        // Report (A4 orizzontale)
        static let copertinaOcchiello = helvetica(8.5, grassetto: true)
        static let copertinaTitolo = avenir(34)
        static let copertinaSottotitolo = avenir(13)
        static let copertinaNomi = helvetica(13, grassetto: true)
        static let copertinaConsulente = helvetica(11, grassetto: true)
        static let copertinaRuolo = helvetica(9.5)
        static let copertinaEtichetta = helvetica(10, grassetto: true)
        static let copertinaValore = avenir(13)
        static let occhiello = helvetica(7.5, grassetto: true)
        static let titoloSlide = avenir(23)
        static let sottotitoloSlide = helvetica(10.5)
        static let corpo = helvetica(10.5)
        static let corpoForte = helvetica(10.5, grassetto: true)
        static let piccolo = helvetica(8.5)
        static let minimo = helvetica(7)
        static let numeroGrande = avenir(22, "Bold")
        static let numeroMedio = avenir(17, "Bold")
        static let numeroPiccolo = avenir(13, "DemiBold")
        static let titoloRiquadro = helvetica(12, grassetto: true)
        static let scenarioTitolo = helvetica(12, grassetto: true)
        static let scenarioRendimento = avenir(26, "Bold")
        static let numeroPagina = helvetica(7)
        static let sintesiNumero = avenir(30, "Bold")

        // Prospetto (A4 verticale)
        static let pOcchiello = helvetica(6.5, grassetto: true)
        static let pTitolo = avenir(20, "Medium")
        static let pSottotitolo = helvetica(8.5)
        static let pSezione = avenir(12.5, "Medium")
        static let pSottosezione = avenir(10, "Medium")
        static let pCorpo = helvetica(7.8)
        static let pCorpoForte = helvetica(7.8, grassetto: true)
        static let pTabella = helvetica(7.2)
        static let pTabellaForte = helvetica(7.2, grassetto: true)
        static let pTabellaTesta = helvetica(6.5, grassetto: true)
        static let pTabellaNota = helvetica(5.8)
        static let pKpiEtichetta = helvetica(6.6)
        static let pKpiValore = avenir(15, "Medium")
        static let pKpiNota = helvetica(6)
        static let pValoreScenario = avenir(11.5, "Medium")
        static let pPiede = helvetica(6)
        static let pAssi = helvetica(6)

        static let nsCorpo = nsHelvetica(10.5)
        static let nsPCorpo = nsHelvetica(7.8)
    }
}

extension Misure {
    enum Documento {
        /// A4 orizzontale (report) e verticale (prospetto), in punti.
        static let report = CGSize(width: 842, height: 595)
        static let prospetto = CGSize(width: 595, height: 842)
        static let margineReport: CGFloat = 44
        static let margineProspetto: CGFloat = 40
        static let raggio: CGFloat = 5
        static let raggioPiccolo: CGFloat = 3
        static let spazio: CGFloat = 12
        static let rigaTabellaReport: CGFloat = 22
        static let rigaTabellaProspetto: CGFloat = 13.5
        static let tracciatoOcchiello: CGFloat = 1.6
    }
}
