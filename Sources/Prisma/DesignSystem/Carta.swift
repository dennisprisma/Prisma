import AppKit
import SwiftUI

// Carta stampata dei prospetti e dei report (.docs-paper del template: carta avorio,
// intestazione in Georgia blu ardesia con filetto doppio, corpo in Helvetica Neue).
// Su carta i colori sono più asciutti che a schermo: niente trame, poco inchiostro.

extension Colori {
    enum Carta {
        static let foglio = Color(hex: "#fffefa")
        static let intestazione = Color(hex: "#395269")
        static let filettoForte = Color(hex: "#314e63")
        static let filetto = Color(hex: "#ddd8ca")
        static let filettoRiga = Color(hex: "#e8e4d8")
        static let titolo = Color(hex: "#293c4c")
        static let testo = Color(hex: "#3f413b")
        static let testoTenue = Color(hex: "#81847d")
        static let piede = Color(hex: "#909088")
        static let numeroSezione = Color(hex: "#9f7645")
        static let zebra = Color(hex: "#f7f5ee")
        static let evidenza = Color(hex: "#e7eef3")
        static let riquadro = Color(hex: "#fbfaf5")
        static let riquadroBordo = Color(hex: "#d9d5c9")
        static let avvisoFondo = Color(hex: "#fbf3df")
        static let avvisoBordo = Color(hex: "#e2c98f")
        static let avvisoTesto = Color(hex: "#6b5426")
        static let griglia = Color(hex: "#e4e0d4")
        static let versato = Color(hex: "#9a9a90")
        static let atteso = Color(hex: "#2f6690")
        static let prudente = Color(hex: "#b07b4f")
        static let favorevole = Color(hex: "#5b8a3c")
        /// Fondo dell'anteprima a schermo (.docs-reading-room).
        static let tavoloAlto = Color(hex: "#d8dcda")
        static let tavoloBasso = Color(hex: "#e7e6df")
        static let ombraFoglio = Color(hex: "#2634352e")
    }
}

extension Tipo {
    /// Caratteri della carta: Georgia per titoli e cifre in evidenza, Helvetica Neue per il resto.
    /// Ogni carattere ha il suo gemello AppKit, usato dall'impaginazione per misurare i testi.
    enum Carta {
        static let serif = "Georgia"
        static let sans = "Helvetica Neue"

        static func font(_ nome: String, _ dimensione: CGFloat, grassetto: Bool = false) -> Font {
            Font.custom(nome, fixedSize: dimensione).weight(grassetto ? .bold : .regular)
        }

        static func nsFont(_ nome: String, _ dimensione: CGFloat, grassetto: Bool = false) -> NSFont {
            let base = NSFont(name: nome, size: dimensione) ?? NSFont.systemFont(ofSize: dimensione)
            return grassetto ? NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask) : base
        }

        static let marchio = font(serif, 20)
        static let testata = font(serif, 12)
        static let testataPiccola = font(sans, 5.8)
        static let data = font(sans, 8)
        static let occhiello = font(sans, 7, grassetto: true)
        static let titolo = font(serif, 23)
        static let sottotitolo = font(sans, 9.5)
        static let firma = font(sans, 8.5)
        static let corrente = font(serif, 9)
        static let numeroSezione = font(serif, 11)
        static let sezione = font(serif, 14)
        static let indicatoreEtichetta = font(sans, 6.5, grassetto: true)
        static let indicatoreValore = font(serif, 16)
        static let indicatoreNota = font(sans, 7)
        static let voceEtichetta = font(sans, 6.5, grassetto: true)
        static let voceValore = font(sans, 9)
        static let tabellaTesta = font(sans, 6.5, grassetto: true)
        static let tabella = font(sans, 8)
        static let tabellaForte = font(sans, 8, grassetto: true)
        static let testo = font(sans, 9)
        static let nota = font(sans, 7)
        static let assi = font(sans, 6.5)
        static let piede = font(sans, 6.5)

        // Gemelli per le misure
        static let nsVoceValore = nsFont(sans, 9)
        static let nsTesto = nsFont(sans, 9)
        static let nsNota = nsFont(sans, 7)
    }
}

extension Misure {
    enum Carta {
        /// A4 verticale in punti tipografici.
        static let pagina = CGSize(width: 595, height: 842)
        static let margineLato: CGFloat = 42
        static let margineAlto: CGFloat = 34
        static let margineBasso: CGFloat = 28
        static var larghezzaUtile: CGFloat { pagina.width - margineLato * 2 }

        /// Intestazione della prima pagina (carta intestata, titolo, cliente e canale).
        static let testataPrima: CGFloat = 156
        /// Intestazione corrente delle pagine successive.
        static let testataCorrente: CGFloat = 30
        static let piede: CGFloat = 24
        static let spazioBlocchi: CGFloat = 8

        static let sezione: CGFloat = 34
        static let indicatori: CGFloat = 60
        static let testaTabella: CGFloat = 20
        static let rigaTabella: CGFloat = 15.5
        static let rigaTotale: CGFloat = 18
        static let grafico: CGFloat = 176
        static let legenda: CGFloat = 16
        static let voceEtichetta: CGFloat = 10
        static let voceMargine: CGFloat = 7
        static let interlinea: CGFloat = 2.5
        static let riquadroMargine: CGFloat = 8
        static let raggio: CGFloat = 3
        static let colonnaVoci: CGFloat = 14
        /// Righe minime di una tabella prima di andare a capo pagina.
        static let righeMinime = 3
        /// Scala dell'etichetta del canale dentro le tabelle.
        static let scalaEtichetta: CGFloat = 0.82
    }
}
