#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

// Carta stampata dei prospetti di dettaglio: carta avorio, testata con il logo di Prisma e
// filetto blu ardesia, testi in SF. Su carta i colori sono più asciutti che a schermo: niente trame,
// poco inchiostro. Colori sempre fissi e opachi (mai i colori dinamici del tema): la carta resta chiara.

extension Colori {
    enum Carta {
        static let foglio = Color(hex: "#fffefa")
        /// Il logo di Prisma nella testata: sempre scuro su carta.
        static let logo = Tema.Colore.logoStampa
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
    /// Caratteri della carta: SF del sistema, alle dimensioni fisse della pagina (non seguono la Dimensione
    /// del testo). Ogni carattere ha il suo gemello AppKit, usato dall'impaginazione per misurare i testi.
    enum Carta {
        static func font(_ dimensione: CGFloat, grassetto: Bool = false) -> Font {
            Font.system(size: dimensione, weight: grassetto ? .bold : .regular)
        }

        static func nsFont(_ dimensione: CGFloat, grassetto: Bool = false) -> FontPiattaforma {
            FontPiattaforma.systemFont(ofSize: dimensione, weight: grassetto ? .bold : .regular)
        }

        static let testataPiccola = font(5.8)
        static let data = font(8)
        static let occhiello = font(7, grassetto: true)
        static let titolo = font(23)
        static let sottotitolo = font(9.5)
        static let firma = font(8.5)
        static let corrente = font(9)
        static let numeroSezione = font(11)
        static let sezione = font(14)
        static let indicatoreEtichetta = font(6.5, grassetto: true)
        static let indicatoreValore = font(16)
        static let indicatoreNota = font(7)
        static let voceEtichetta = font(6.5, grassetto: true)
        static let voceValore = font(9)
        static let tabellaTesta = font(6.5, grassetto: true)
        static let tabella = font(8)
        static let tabellaForte = font(8, grassetto: true)
        static let testo = font(9)
        static let nota = font(7)
        static let assi = font(6.5)
        static let piede = font(6.5)

        // Gemelli per le misure
        static let nsVoceValore = nsFont(9)
        static let nsTesto = nsFont(9)
        static let nsNota = nsFont(7)
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
        /// Altezza del simbolo del logo nella testata della prima pagina e in quella corrente.
        static let logoTestata: CGFloat = 14
        static let logoCorrente: CGFloat = 8.5
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
