import AppKit
import SwiftUI

// Stile dei documenti per i clienti (report A4 orizzontale e prospetto A4 verticale).
// È lo stile scelto da Denis con i suoi esempi (Orizzonte Valore, ottobre 2026): pulito e moderno,
// diverso dall'interfaccia iOS 5 dell'app. Titoli in Avenir Next, testo in Helvetica Neue,
// verde, blu e rosso per i tre scenari, ardesia e ocra per Gestione separata e Fondo Interno.

/// I colori di un documento per i clienti. Due tavolozze: "moderna" per il prospetto (lo stile degli
/// esempi di Denis) e "Prisma" per il report, con i materiali dell'app (carta avorio, cuoio, Georgia).
/// I componenti comuni la leggono dall'ambiente.
struct PaletteDocumento {
    // Foglio (sfumatura radiale dall'alto a sinistra)
    var foglio: Color
    var foglioFine: Color
    // Copertina
    var copertina: Color
    var copertinaRiquadro: Color
    var copertinaEtichetta: Color
    var copertinaTesto: Color
    var cucitura: Color
    var ombraCartellino: Color
    // Testo
    var titolo: Color
    var testo: Color
    var tenue: Color
    var occhiello: Color
    var marchio: Color
    // Riquadri e filetti
    var riquadro: Color
    var riquadroBordo: Color
    var riquadroLuce: Color
    var filetto: Color
    var filettoForte: Color
    var evidenza: Color
    var evidenzaTitolo: Color
    var barraLaterale: Color
    var bloccato: Color
    var griglia: Color
    var premio: Color
    // Scenari e parti
    var favorevole: Color
    var intermedio: Color
    var sfavorevole: Color
    var favorevoleFondo: Color
    var intermedioFondo: Color
    var sfavorevoleFondo: Color
    var gestioneSeparata: Color
    var fondoInterno: Color
    var negativo: Color
    var positivo: Color
    var penaleForte: Color
    var penaleMedia: Color
    var penaleLieve: Color
    var cascataTotale: Color
    var cascataPiu: Color
    var cascataMeno: Color
    /// Aree delle posizioni, nell'ordine di AreaPosizione.ordine (previdenza … debiti).
    var aree: [Color]
    /// Canali nei grafici: blu Alleanza e cuoio dell'indipendente, come le etichette.
    var alleanza: Color
    var indipendente: Color

    func area(_ a: AreaPosizione) -> Color { aree[a.ordine % aree.count] }

    func canale(_ c: Canale) -> Color { c == .alleanza ? alleanza : indipendente }

    func scenario(_ t: TipoScenario) -> Color {
        switch t {
        case .favorevole: return favorevole
        case .intermedio: return intermedio
        case .sfavorevole: return sfavorevole
        }
    }

    func scenarioFondo(_ t: TipoScenario) -> Color {
        switch t {
        case .favorevole: return favorevoleFondo
        case .intermedio: return intermedioFondo
        case .sfavorevole: return sfavorevoleFondo
        }
    }

    func parte(_ t: ComponenteContratto.Tipo) -> Color {
        t == .gestioneSeparata ? gestioneSeparata : fondoInterno
    }
}

extension Colori {
    enum Documento {
        /// Prospetto: pulito e moderno, come gli esempi di Denis (Orizzonte Valore, ottobre 2026).
        static let moderna = PaletteDocumento(
            foglio: .white, foglioFine: .white,
            copertina: Color(hex: "#1b2a41"), copertinaRiquadro: Color(hex: "#2d3c55"),
            copertinaEtichetta: Color(hex: "#8fa1bd"), copertinaTesto: Color(hex: "#e9eef5"), cucitura: .clear, ombraCartellino: Color(hex: "#00000033"),
            titolo: Color(hex: "#1d2737"), testo: Color(hex: "#2b3342"), tenue: Color(hex: "#5f6b7a"),
            occhiello: Color(hex: "#5f6b7a"), marchio: Color(hex: "#1d2737"),
            riquadro: Color(hex: "#f2f4f7"), riquadroBordo: .clear, riquadroLuce: .clear,
            filetto: Color(hex: "#e3e6ea"), filettoForte: Color(hex: "#1d2737"),
            evidenza: Color(hex: "#e7ecf4"), evidenzaTitolo: Color(hex: "#2f5ea8"), barraLaterale: Color(hex: "#1f3a5f"),
            bloccato: Color(hex: "#eef0f3"), griglia: Color(hex: "#e6e8ec"), premio: Color(hex: "#7d8796"),
            favorevole: Color(hex: "#2e7d5b"), intermedio: Color(hex: "#2f5ea8"), sfavorevole: Color(hex: "#c0553a"),
            favorevoleFondo: Color(hex: "#e6efe9"), intermedioFondo: Color(hex: "#e5ebf3"), sfavorevoleFondo: Color(hex: "#f6e7e4"),
            gestioneSeparata: Color(hex: "#6f86a6"), fondoInterno: Color(hex: "#c4913f"),
            negativo: Color(hex: "#c0553a"), positivo: Color(hex: "#2e7d5b"),
            penaleForte: Color(hex: "#b5513a"), penaleMedia: Color(hex: "#c9806f"), penaleLieve: Color(hex: "#e0b5ab"),
            cascataTotale: Color(hex: "#8e98a8"), cascataPiu: Color(hex: "#7fb093"), cascataMeno: Color(hex: "#d3897a"),
            aree: [Color(hex: "#2f5ea8"), Color(hex: "#2e7d5b"), Color(hex: "#6f86a6"), Color(hex: "#8a6fb0"),
                   Color(hex: "#c4913f"), Color(hex: "#9aa3ad"), Color(hex: "#c0553a")],
            alleanza: Color(hex: "#2a5fa8"), indipendente: Color(hex: "#9a6a3e")
        )

        /// Report: l'identità di Prisma (template, app Presentazioni: .slides-stage). Carta avorio con la
        /// sfumatura delle slide, inchiostro blu ardesia, Georgia, copertina in cuoio come il dossier del
        /// cliente; scenari nei toni dell'app (salvia, blu Prisma, terracotta), Gestione separata e Fondo
        /// Interno in ardesia e cuoio.
        static let prisma = PaletteDocumento(
            foglio: Color(hex: "#fffef8"), foglioFine: Color(hex: "#f1eee4"),
            copertina: Color(hex: "#7c4d2b"), copertinaRiquadro: Color(hex: "#fbf6ea"),
            copertinaEtichetta: Color(hex: "#8a6a48"), copertinaTesto: Color(hex: "#f6e6cc"), cucitura: Color(hex: "#e9c79a"), ombraCartellino: Color(hex: "#00000073"),
            titolo: Color(hex: "#253f4b"), testo: Color(hex: "#4f605d"), tenue: Color(hex: "#748a8a"),
            occhiello: Color(hex: "#7e9996"), marchio: Color(hex: "#3d626a"),
            riquadro: Color(hex: "#fbf9f1"), riquadroBordo: Color(hex: "#d8d6ca"), riquadroLuce: .white,
            filetto: Color(hex: "#d6dcd5"), filettoForte: Color(hex: "#3d626a"),
            evidenza: Color(hex: "#eef2ec"), evidenzaTitolo: Color(hex: "#3d626a"), barraLaterale: Color(hex: "#3d626a"),
            bloccato: Color(hex: "#ece9df"), griglia: Color(hex: "#e2e0d6"), premio: Color(hex: "#8d9a93"),
            favorevole: Color(hex: "#4d7f5b"), intermedio: Color(hex: "#2f6e9b"), sfavorevole: Color(hex: "#a65a3c"),
            favorevoleFondo: Color(hex: "#eaf0e6"), intermedioFondo: Color(hex: "#e6eef2"), sfavorevoleFondo: Color(hex: "#f5e9e1"),
            gestioneSeparata: Color(hex: "#6d8a96"), fondoInterno: Color(hex: "#b98a4e"),
            negativo: Color(hex: "#a65a3c"), positivo: Color(hex: "#4d7f5b"),
            penaleForte: Color(hex: "#a65a3c"), penaleMedia: Color(hex: "#c28b6c"), penaleLieve: Color(hex: "#dfc0a8"),
            cascataTotale: Color(hex: "#9aa6a2"), cascataPiu: Color(hex: "#8fb194"), cascataMeno: Color(hex: "#cf9c84"),
            aree: [Color(hex: "#2f6e9b"), Color(hex: "#4d7f5b"), Color(hex: "#6d8a96"), Color(hex: "#8b6f93"),
                   Color(hex: "#b98a4e"), Color(hex: "#a89f8c"), Color(hex: "#a65a3c")],
            alleanza: Color(hex: "#2f6ea5"), indipendente: Color(hex: "#8a5a33")
        )
    }
}

extension Colori.Documento {
    /// Toni della carta delle pagine del report (.slide-tone-0…3 del template): avorio, crema, salvia, cielo.
    static let toniReport: [(Color, Color)] = [
        (Color(hex: "#fffef8"), Color(hex: "#f1eee4")),
        (Color(hex: "#fffefa"), Color(hex: "#f1ede0")),
        (Color(hex: "#fdfefb"), Color(hex: "#eaf0e9")),
        (Color(hex: "#fdfcf6"), Color(hex: "#e9eef0")),
    ]
}

private struct ChiavePaletteDocumento: EnvironmentKey {
    static let defaultValue = Colori.Documento.moderna
}

extension EnvironmentValues {
    /// Tavolozza dei documenti per i clienti (moderna per il prospetto, Prisma per il report).
    var paletteDocumento: PaletteDocumento {
        get { self[ChiavePaletteDocumento.self] }
        set { self[ChiavePaletteDocumento.self] = newValue }
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

        // Comuni (valori predefiniti dei componenti)
        static let occhiello = helvetica(7.5, grassetto: true)
        static let corpo = helvetica(10.5)
        static let corpoForte = helvetica(10.5, grassetto: true)
        static let piccolo = helvetica(8.5)
        static let minimo = helvetica(7)

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

    /// Caratteri del report per il cliente, nell'identità di Prisma: Georgia per titoli e cifre
    /// (.slides-stage h2), Helvetica Neue per le note, occhielli spaziati (.slides-chapter).
    enum Report {
        static func georgia(_ dimensione: CGFloat, grassetto: Bool = false) -> Font {
            Font.custom("Georgia", fixedSize: dimensione).weight(grassetto ? .bold : .regular)
        }

        static let marchio = georgia(11)
        static let testata = Documento.helvetica(6.5)
        static let capitolo = Documento.helvetica(7, grassetto: true)
        static let piede = Documento.helvetica(5.8)
        static let copertinaMarchio = georgia(15)
        static let copertinaOcchiello = Documento.helvetica(7.5, grassetto: true)
        static let copertinaTitolo = georgia(32)
        static let copertinaSottotitolo = georgia(13)
        static let copertinaNomi = georgia(15)
        static let copertinaConsulente = Documento.helvetica(10.5, grassetto: true)
        static let copertinaRuolo = Documento.helvetica(9)
        static let copertinaEtichetta = Documento.helvetica(7.5, grassetto: true)
        static let copertinaValore = georgia(14)
        static let occhiello = Documento.helvetica(7, grassetto: true)
        static let titoloSlide = georgia(23)
        static let sottotitoloSlide = Documento.helvetica(10)
        static let corpo = georgia(10.5)
        static let corpoForte = georgia(10.5, grassetto: true)
        static let piccolo = Documento.helvetica(8)
        static let minimo = Documento.helvetica(6.8)
        static let numeroGrande = georgia(22)
        static let numeroMedio = georgia(17)
        static let numeroPiccolo = georgia(13)
        static let titoloRiquadro = georgia(12.5, grassetto: true)
        static let scenarioTitolo = georgia(13, grassetto: true)
        static let scenarioRendimento = georgia(25)
        static let sintesiNumero = georgia(30)
        static let filigrana = georgia(150)
        /// La lettera del consulente dopo la copertina.
        static let lettera = georgia(11.5)
        static let letteraFirma = Font.custom("Georgia-Italic", fixedSize: 19)
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
