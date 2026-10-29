import AppKit
import SwiftUI

// Stile dei documenti per i clienti (report A4 orizzontale e prospetto A4 verticale).
// È lo stile scelto da Denis con i suoi esempi (Orizzonte Valore, ottobre 2026): pulito e moderno.
// Testi in SF del sistema, verde, blu e rosso per i tre scenari, ardesia e viola per Gestione separata
// e Fondo Interno. I documenti restano su carta chiara con colori fissi e opachi, anche con l'app in scuro.

/// I colori di un documento per i clienti. Due tavolozze: "moderna" per il prospetto (lo stile degli
/// esempi di Denis) e "Prisma" per il report (carta avorio, copertina blu notte con il logo bianco).
/// I componenti comuni la leggono dall'ambiente.
struct PaletteDocumento {
    // Foglio (sfumatura radiale dall'alto a sinistra)
    var foglio: Color
    var foglioFine: Color
    // Copertina (sfumatura da copertina a copertinaFine)
    var copertina: Color
    var copertinaFine: Color
    var copertinaRiquadro: Color
    var copertinaEtichetta: Color
    var copertinaTesto: Color
    var copertinaFilo: Color
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
    /// Ocra: il semaforo giallo e i dati da aggiornare (non più il Fondo Interno, che sembrava il cuoio dell'indipendente).
    var fondoInterno: Color
    /// Il Fondo Interno e i fondi nei grafici: viola, come nell'app, lontano dal blu e dal cuoio dei canali.
    var fondi: Color
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
    /// Canali nei grafici: blu Alleanza e ambra/cuoio dell'indipendente, come le etichette da stampa.
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
        t == .gestioneSeparata ? gestioneSeparata : fondi
    }
}

extension Colori {
    enum Documento {
        /// Prospetto: pulito e moderno, come gli esempi di Denis (Orizzonte Valore, ottobre 2026).
        static let moderna = PaletteDocumento(
            foglio: .white, foglioFine: .white,
            copertina: Color(hex: "#0F2433"), copertinaFine: Color(hex: "#1E3A4F"), copertinaRiquadro: .white,
            copertinaEtichetta: Color(hex: "#5f6b7a"), copertinaTesto: Color(hex: "#c9d6e1"), copertinaFilo: Color(hex: "#ffffff29"),
            ombraCartellino: Color(hex: "#00000040"),
            titolo: Color(hex: "#1d2737"), testo: Color(hex: "#2b3342"), tenue: Color(hex: "#5f6b7a"),
            occhiello: Color(hex: "#5f6b7a"), marchio: Color(hex: "#1d2737"),
            riquadro: Color(hex: "#f2f4f7"), riquadroBordo: .clear, riquadroLuce: .clear,
            filetto: Color(hex: "#e3e6ea"), filettoForte: Color(hex: "#1d2737"),
            evidenza: Color(hex: "#e7ecf4"), evidenzaTitolo: Color(hex: "#2f5ea8"), barraLaterale: Color(hex: "#1f3a5f"),
            bloccato: Color(hex: "#eef0f3"), griglia: Color(hex: "#e6e8ec"), premio: Color(hex: "#7d8796"),
            favorevole: Color(hex: "#2e7d5b"), intermedio: Color(hex: "#2f5ea8"), sfavorevole: Color(hex: "#c0553a"),
            favorevoleFondo: Color(hex: "#e6efe9"), intermedioFondo: Color(hex: "#e5ebf3"), sfavorevoleFondo: Color(hex: "#f6e7e4"),
            gestioneSeparata: Color(hex: "#6f86a6"), fondoInterno: Color(hex: "#c4913f"), fondi: Color(hex: "#7a6fb0"),
            negativo: Color(hex: "#c0553a"), positivo: Color(hex: "#2e7d5b"),
            penaleForte: Color(hex: "#b5513a"), penaleMedia: Color(hex: "#c9806f"), penaleLieve: Color(hex: "#e0b5ab"),
            cascataTotale: Color(hex: "#8e98a8"), cascataPiu: Color(hex: "#7fb093"), cascataMeno: Color(hex: "#d3897a"),
            // Liquidità in verde acqua: l'ocra di prima sembrava il cuoio dell'indipendente
            aree: [Color(hex: "#2f5ea8"), Color(hex: "#2e7d5b"), Color(hex: "#6f86a6"), Color(hex: "#8a6fb0"),
                   Color(hex: "#3a9e9a"), Color(hex: "#9aa3ad"), Color(hex: "#c0553a")],
            alleanza: Tema.Colore.canaleAlleanzaStampa, indipendente: Tema.Colore.canaleIndipendenteStampa
        )

        /// Report: l'identità di Prisma. Carta avorio con la sfumatura delle slide, inchiostro blu ardesia,
        /// copertina blu notte del tema (#0F2433 → #1E3A4F) con il logo bianco e i cartellini bianchi;
        /// scenari nei toni dell'app (salvia, blu Prisma, terracotta), Gestione separata e Fondo
        /// Interno in ardesia e viola.
        static let prisma = PaletteDocumento(
            foglio: Color(hex: "#fffef8"), foglioFine: Color(hex: "#f1eee4"),
            copertina: Color(hex: "#0F2433"), copertinaFine: Color(hex: "#1E3A4F"), copertinaRiquadro: .white,
            copertinaEtichetta: Color(hex: "#6a7f8c"), copertinaTesto: Color(hex: "#c9d6e1"), copertinaFilo: Color(hex: "#ffffff29"),
            ombraCartellino: Color(hex: "#00000040"),
            titolo: Color(hex: "#253f4b"), testo: Color(hex: "#4f605d"), tenue: Color(hex: "#748a8a"),
            occhiello: Color(hex: "#7e9996"), marchio: Color(hex: "#3d626a"),
            riquadro: Color(hex: "#fbf9f1"), riquadroBordo: Color(hex: "#d8d6ca"), riquadroLuce: .white,
            filetto: Color(hex: "#d6dcd5"), filettoForte: Color(hex: "#3d626a"),
            evidenza: Color(hex: "#eef2ec"), evidenzaTitolo: Color(hex: "#3d626a"), barraLaterale: Color(hex: "#3d626a"),
            bloccato: Color(hex: "#ece9df"), griglia: Color(hex: "#e2e0d6"), premio: Color(hex: "#8d9a93"),
            favorevole: Color(hex: "#4d7f5b"), intermedio: Color(hex: "#2f6e9b"), sfavorevole: Color(hex: "#a65a3c"),
            favorevoleFondo: Color(hex: "#eaf0e6"), intermedioFondo: Color(hex: "#e6eef2"), sfavorevoleFondo: Color(hex: "#f5e9e1"),
            gestioneSeparata: Color(hex: "#6d8a96"), fondoInterno: Color(hex: "#b98a4e"), fondi: Color(hex: "#7a6fb0"),
            negativo: Color(hex: "#a65a3c"), positivo: Color(hex: "#4d7f5b"),
            penaleForte: Color(hex: "#a65a3c"), penaleMedia: Color(hex: "#c28b6c"), penaleLieve: Color(hex: "#dfc0a8"),
            cascataTotale: Color(hex: "#9aa6a2"), cascataPiu: Color(hex: "#8fb194"), cascataMeno: Color(hex: "#cf9c84"),
            aree: [Color(hex: "#2f6e9b"), Color(hex: "#4d7f5b"), Color(hex: "#6d8a96"), Color(hex: "#8b6f93"),
                   Color(hex: "#4a9590"), Color(hex: "#a89f8c"), Color(hex: "#a65a3c")],
            alleanza: Tema.Colore.canaleAlleanzaStampa, indipendente: Tema.Colore.canaleIndipendenteStampa
        )
    }
}

extension Colori.Documento {
    /// Il logo di Prisma su carta (sempre scuro) e sulla copertina blu notte (bianco). Colori fissi.
    static let logo = Tema.Colore.logoStampa
    static let logoCopertina = Color.white
    /// Trasparenza del logo in filigrana nelle pagine del report e sulla copertina.
    static let filigrana: Double = 0.06
    static let filigranaCopertina: Double = 0.05

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
    /// Caratteri dei prospetti: SF del sistema a dimensioni fisse (non seguono la Dimensione del testo).
    enum Documento {
        static func sf(_ dimensione: CGFloat, _ peso: Font.Weight = .regular) -> Font {
            Font.system(size: dimensione, weight: peso)
        }

        static func sf(_ dimensione: CGFloat, grassetto: Bool) -> Font {
            sf(dimensione, grassetto ? .bold : .regular)
        }

        static func nsSF(_ dimensione: CGFloat) -> NSFont {
            NSFont.systemFont(ofSize: dimensione)
        }

        // Comuni (valori predefiniti dei componenti)
        static let occhiello = sf(7.5, grassetto: true)
        static let corpo = sf(10.5)
        static let corpoForte = sf(10.5, grassetto: true)
        static let piccolo = sf(8.5)
        static let minimo = sf(7)

        // Prospetto (A4 verticale)
        static let pOcchiello = sf(6.5, grassetto: true)
        static let pTitolo = sf(20, .medium)
        static let pSottotitolo = sf(8.5)
        static let pSezione = sf(12.5, .medium)
        static let pSottosezione = sf(10, .medium)
        static let pCorpo = sf(7.8)
        static let pCorpoForte = sf(7.8, grassetto: true)
        static let pTabella = sf(7.2)
        static let pTabellaForte = sf(7.2, grassetto: true)
        static let pTabellaTesta = sf(6.5, grassetto: true)
        static let pTabellaNota = sf(5.8)
        static let pKpiEtichetta = sf(6.6)
        static let pKpiValore = sf(15, .medium)
        static let pKpiNota = sf(6)
        static let pValoreScenario = sf(11.5, .medium)
        static let pPiede = sf(6)
        static let pAssi = sf(6)

        static let nsCorpo = nsSF(10.5)
        static let nsPCorpo = nsSF(7.8)
    }

    /// Caratteri del report per il cliente: SF del sistema, titoli e cifre più grandi (.slides-stage h2),
    /// note piccole, occhielli spaziati (.slides-chapter).
    enum Report {
        static func sf(_ dimensione: CGFloat, grassetto: Bool = false) -> Font {
            Documento.sf(dimensione, grassetto: grassetto)
        }

        static let testata = Documento.sf(6.5)
        static let capitolo = Documento.sf(7, grassetto: true)
        static let piede = Documento.sf(5.8)
        static let copertinaOcchiello = Documento.sf(7.5, grassetto: true)
        static let copertinaTitolo = sf(32)
        static let copertinaSottotitolo = sf(13)
        static let copertinaNomi = sf(15)
        static let copertinaConsulente = Documento.sf(10.5, grassetto: true)
        static let copertinaRuolo = Documento.sf(9)
        static let copertinaEtichetta = Documento.sf(7.5, grassetto: true)
        static let copertinaValore = sf(14)
        static let occhiello = Documento.sf(7, grassetto: true)
        static let titoloSlide = sf(23)
        static let sottotitoloSlide = Documento.sf(10)
        static let corpo = sf(10.5)
        static let corpoForte = sf(10.5, grassetto: true)
        static let piccolo = Documento.sf(8)
        static let minimo = Documento.sf(6.8)
        static let numeroGrande = sf(22)
        static let numeroMedio = sf(17)
        static let numeroPiccolo = sf(13)
        static let titoloRiquadro = sf(12.5, grassetto: true)
        static let scenarioTitolo = sf(13, grassetto: true)
        static let scenarioRendimento = sf(25)
        static let sintesiNumero = sf(30)
        /// La lettera del consulente dopo la copertina.
        static let lettera = sf(11.5)
        static let letteraFirma = Font.system(size: 19, weight: .light).italic()
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
        /// Il logo (altezza del simbolo): testata dei prospetti, testata e filigrana del report, copertina.
        static let logoProspetto: CGFloat = 9
        static let logoProspettoAlto: CGFloat = 13
        static let logoReport: CGFloat = 11
        static let logoFiligrana: CGFloat = 110
        static let logoCopertina: CGFloat = 22
        static let logoCopertinaFiligrana: CGFloat = 330
        /// Cornice sottile della copertina (rientro dal bordo e raggio).
        static let copertinaCornice: CGFloat = 18
        static let copertinaRaggio: CGFloat = 12
        /// I cartellini bianchi della copertina e la loro ombra.
        static let cartellinoRaggio: CGFloat = 6
        static let cartellinoOmbra: CGFloat = 6
        static let cartellinoOmbraY: CGFloat = 3
        static let spazio: CGFloat = 12
        static let rigaTabellaReport: CGFloat = 22
        static let rigaTabellaProspetto: CGFloat = 13.5
        /// Testata di tabella con titolo e sottotitolo: l'altezza minima per le due righe.
        static let altezzaTestaDoppia: CGFloat = 20
        static let tracciatoOcchiello: CGFloat = 1.6
        /// Prova di resistenza: la barra della perdita sui mercati nel prospetto e nel report.
        static let barraResistenza: CGFloat = 12
        static let barraResistenzaReport: CGFloat = 22
        /// Il grafico con e senza costi nel prospetto e nel report.
        static let graficoCosti: CGFloat = 190
        static let graficoCostiReport: CGFloat = 270
        /// Il percorso del patrimonio nel report: il grafico occupa quasi tutta l'altezza della pagina.
        static let graficoPatrimonioReport: CGFloat = 360
        /// Righe al massimo nelle tabelle dei documenti a pagina fissa (oltre: «…e altre N», l'elenco intero è in Posizioni).
        static let righeTabellaFissa = 9
        static let schedeReport = 4
        static let puntiReport = 5
    }
}
