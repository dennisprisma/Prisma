import SwiftUI

extension Color {
    /// Colore da esadecimale come nel template CSS: "#rgb", "#rgba", "#rrggbb" o "#rrggbbaa".
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 || s.count == 4 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((v >> 24) & 0xff) / 255
            g = Double((v >> 16) & 0xff) / 255
            b = Double((v >> 8) & 0xff) / 255
            a = Double(v & 0xff) / 255
        } else {
            r = Double((v >> 16) & 0xff) / 255
            g = Double((v >> 8) & 0xff) / 255
            b = Double(v & 0xff) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Colore da componenti 0–255 come `rgba()` nel CSS.
    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.init(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
}

/// Palette ricavata da Design/template.html (valori effettivi del browser).
enum Colori {
    static let bianco = Color.white
    static let nero = Color.black

    enum Sfondo {
        /// Colore di riserva del body.
        static let base = Color(hex: "#637f8f")
        static let veloInizio = Color(hex: "#17344c22")
        static let veloFine = Color(hex: "#294b6433")
        static let vignettatura = Color(hex: "#1933486b")
    }

    enum Barra {
        static let sfondoAlto = Color(r: 249, g: 249, b: 249, a: 0.96)
        static let sfondoBasso = Color(r: 225, g: 225, b: 225, a: 0.95)
        static let bordo = Color(hex: "#888")
        static let ombra = Color(hex: "#0004")
        static let testo = Color(hex: "#202020")
        static let testoSecondario = Color(hex: "#333")
        static let incisione = Color(r: 255, g: 255, b: 255, a: 0.6)
        static let logo = Color(hex: "#343434")
        static let logoOmbra = Color(r: 0, g: 0, b: 0, a: 0.4)
        static let os = Color(hex: "#4d4d4d")
        static let appCorrente = Color(hex: "#2e2e2e")
        static let separatore = Color(r: 153, g: 153, b: 153, a: 0.4)
        static let tasto = Color(hex: "#555")
        static let avatarBordo = Color(hex: "#82888c")
    }

    enum Scrivania {
        static let kicker = Color(hex: "#e0edf4")
        static let titolo = Color.white
        static let sottotitolo = Color(hex: "#f0f0f0")
        static let ombraTesto = Color(r: 0, g: 0, b: 0, a: 0.6)
        static let intestazione = Color(hex: "#edf5fa")
        static let intestazioneOmbra = Color(r: 26, g: 54, b: 75, a: 0.79)
        static let piede = Color(r: 227, g: 239, b: 245, a: 0.72)
        static let piedeOmbra = Color(hex: "#183c59")
        static let iconaOmbra1 = Color(hex: "#0009")
        static let iconaOmbra2 = Color(hex: "#071b2859")
        static let etichettaOmbra = Color(hex: "#000c")
        static let sottotitoloOmbra = Color(hex: "#000b")
    }

    enum Colonna {
        static let sfondo = Color(hex: "#f6f4ef")
        static let bordo = Color(hex: "#777")
        static let ombra = Color(hex: "#0004")
        static let pelleBordo = Color(hex: "#3c291b")
        static let pelleLuce = Color(hex: "#d5b38e")
        static let pelleOmbra = Color(r: 67, g: 44, b: 36, a: 0.4)
        static let pelleEtichetta = Color(hex: "#eedbc4")
        static let pelleNome = Color(hex: "#fff5e6")
        static let pelleTema = Color(hex: "#ead5bc")
        static let schedeAlto = Color(hex: "#e7e7e7")
        static let schedeBasso = Color(hex: "#d7d7d7")
        static let schedeBordo = Color(hex: "#b6b6b6")
        static let intestazione = Color(hex: "#777")
        static let collegamento = Color(hex: "#345f8a")
        static let rigaBordo = Color(hex: "#d7d3c9")
        static let rigaLuce = Color(r: 255, g: 255, b: 255, a: 0.467)
        static let rigaSecondario = Color(hex: "#777")
        static let rigaNome = Color(hex: "#333")
        static let freccia = Color(hex: "#a4b7c5")
        static let dataAlto = Color(hex: "#fffefb")
        static let dataBasso = Color(hex: "#e9e4d8")
        static let dataBordo = Color(hex: "#aaa497")
        static let dataOmbra = Color(r: 79, g: 68, b: 51, a: 0.2)
        static let dataGiorno = Color(hex: "#3d3d37")
        static let dataMeseTesto = Color(hex: "#fff3e9")
        static let dataMeseAlto = Color(hex: "#c96153")
        static let dataMeseBasso = Color(hex: "#a83629")
        static let dataMeseBordo = Color(hex: "#9b3629")
        static let eveBordo = Color(hex: "#222a32")
        static let eveTitolo = Color(hex: "#f1edf8")
        static let eveTesto = Color(hex: "#c0c1ce")
    }

    /// Widget della scrivania.
    enum Widget {
        static let bordo = Color(hex: "#777")
        static let ombra = Color(hex: "#0004")
        static let carta = Color(hex: "#f6f4ef")
        static let cartaBianca = Color(hex: "#fffdf7")
        /// Rosso del calendario iOS 5 (agenda-red dell'icona Agenda).
        static let calendario = [Color(hex: "#ff7767"), Color(hex: "#ef352d"), Color(hex: "#cc171d"), Color(hex: "#a50c12")]
        static let calendarioBordo = Color(hex: "#7c1317")
        static let calendarioLuce = Color(hex: "#ffb7a2")
        static let calendarioTesto = Color(hex: "#fffaf0")
        static let calendarioSecondario = Color(hex: "#ffd9cf")
        static let titolo = Color(hex: "#303030")
        static let secondario = Color(hex: "#666")
        static let numero = Color(hex: "#203f67")
    }

    enum Lino {
        static let alto = Color(hex: "#4b4e51")
        static let basso = Color(hex: "#35383b")
    }

    enum Dock {
        static let ripianoBordo = Color(r: 216, g: 223, b: 230, a: 0.65)
        static let ripianoFondo = Color(hex: "#7e8993")
        static let ripianoOmbra = Color(hex: "#0006")
        static let filo = Color(r: 255, g: 255, b: 255, a: 0.6)
        static let filoOmbra = Color(hex: "#354e69")
        static let divisoreMezzo = Color(r: 116, g: 125, b: 133, a: 0.667)
        static let divisoreBasso = Color(r: 255, g: 255, b: 255, a: 0.5)
        static let iconaOmbra = Color(hex: "#0008")
        static let puntino = Color(hex: "#effaff")
        static let puntinoAlone = Color(hex: "#b9e8fb80")
        static let suggerimento = Color(hex: "#292929f2")
    }

    enum Finestra {
        static let sfondo = Color(hex: "#e6e6e6")
        static let contenuto = Color(hex: "#e8e8e8")
        static let bordoAttiva = Color(hex: "#626262")
        static let bordoInattiva = Color(hex: "#777")
        static let ombraAttiva1 = Color(hex: "#0006")
        static let ombraAttiva2 = Color(hex: "#0003")
        static let ombraInattiva = Color(hex: "#0004")
        static let titoloAttivaAlto = Color(hex: "#e8e8e8")
        static let titoloAttivaBasso = Color(hex: "#d6d6d6")
        static let titoloInattivaAlto = Color(hex: "#f0f0f0")
        static let titoloInattivaBasso = Color(hex: "#e6e6e6")
        static let titoloBordoAttiva = Color(hex: "#b4b4b4")
        static let titoloBordoInattiva = Color(hex: "#c5c5c5")
        static let titoloLuce = Color(r: 255, g: 255, b: 255, a: 0.7)
        static let titoloTesto = Color(hex: "#303030")
        static let titoloTestoInattivo = Color(hex: "#929292")
        static let titoloIncisione = Color(r: 255, g: 255, b: 255, a: 0.65)
        static let contesto = Color(hex: "#666")
        static let affiancaAlto = Color(hex: "#eee")
        static let affiancaBasso = Color(hex: "#d4d4d4")
        static let affiancaBordo = Color(hex: "#aaa")
        static let affiancaSimbolo = Color(hex: "#606060")
    }

    enum Semafori {
        static let chiudi = [Color(hex: "#ffc2b3"), Color(hex: "#ef655a"), Color(hex: "#cb2e27")]
        static let chiudiBordo = Color(hex: "#a3423b")
        static let riduci = [Color(hex: "#fff0ad"), Color(hex: "#f2ba3d"), Color(hex: "#d29721")]
        static let riduciBordo = Color(hex: "#a7832b")
        static let ingrandisci = [Color(hex: "#d4ffab"), Color(hex: "#8bc64d"), Color(hex: "#4d9b2a")]
        static let ingrandisciBordo = Color(hex: "#598137")
        static let inattivoAlto = Color(hex: "#ddd")
        static let inattivoBasso = Color(hex: "#c8c8c8")
        static let inattivoBordo = Color(hex: "#aaa")
        static let simbolo = Color(hex: "#573f38")
    }

    enum IntestazioneApp {
        static let alto = Color(hex: "#d6d6d6")
        static let mezzo = Color(hex: "#d0d0d0")
        static let basso = Color(hex: "#c6c6c6")
        static let bordo = Color(hex: "#a7a7a7")
        static let luce = Color(r: 255, g: 255, b: 255, a: 0.32)
        static let titolo = Color(hex: "#303030")
        static let occhiello = Color(hex: "#666")
        static let incisione = Color(r: 255, g: 255, b: 255, a: 0.533)
        static let corpo = Color(hex: "#ececec")
    }

    enum Pannello {
        static let sfondo = Color.white
        static let bordo = Color(hex: "#b5bcc3")
        static let testo = Color(hex: "#30343a")
        static let testoSecondario = Color(hex: "#666")
        static let titolo = Color(hex: "#3a434e")
    }

    enum Pulsante {
        static let vetroBordo = Color(hex: "#888")
        static let vetroOmbra = Color(hex: "#0003")
        static let testo = Color(hex: "#333")
        static let segmentoBordo = Color(hex: "#a0a0a0")
        static let segmentoAttivoAlto = Color(hex: "#808080")
        static let segmentoAttivoBasso = Color(hex: "#a0a0a0")
        static let segmentoAttivoBordo = Color(hex: "#777")
        static let segmentoAttivoOmbra = Color(hex: "#0004")
        /// Pulsante principale blu iOS 5 (--ios5-button-bg).
        static let blu = [Color(hex: "#7e9cc5"), Color(hex: "#587cad"), Color(hex: "#315e96"), Color(hex: "#537eae")]
        static let bluBordo = Color(hex: "#33547b")
        static let bluIncisione = Color(hex: "#1c3c68")
        static let bluLuce = Color(r: 255, g: 255, b: 255, a: 0.333)
        static let bluRiflesso = Color(r: 197, g: 219, b: 239, a: 0.314)
        /// Pulsante cuoio chiaro (--apple-2011-tan-button).
        static let cuoio = [Color(hex: "#dbcbb4"), Color(hex: "#c4af90"), Color(hex: "#bba282"), Color(hex: "#cfb99a")]
        static let cuoioBordo = Color(hex: "#816d53")
        static let cuoioIncisione = Color(hex: "#6f5b42")
    }

    enum Badge {
        static let grande = [Color(hex: "#ffaaa0"), Color(hex: "#e65143"), Color(hex: "#bb140b"), Color(hex: "#e23e30")]
        static let grandeLuce = Color(hex: "#ffd8d3")
        static let grandeIncisione = Color(hex: "#8d1d15")
        static let piccolo = [Color(hex: "#f58e87"), Color(hex: "#d43429"), Color(hex: "#b91812"), Color(hex: "#df4a3d")]
        static let piccoloIncisione = Color(hex: "#8c211c")
        static let ombra = Color(r: 0, g: 0, b: 0, a: 0.5)
    }

    enum Avvisi {
        static let alto = Color(hex: "#4d5662f5")
        static let basso = Color(hex: "#262d37f5")
        static let bordo = Color(hex: "#151c26")
        static let testo = Color(hex: "#eff7fc")
        static let ombra = Color(hex: "#0006")
        static let luce = Color(hex: "#fff3")
    }

    /// Colori degli avatar dei clienti (gradiente, bordo, testo).
    enum Avatar {
        struct Tinta {
            let alto: Color
            let basso: Color
            let bordo: Color
            let testo: Color
        }

        static let blu = Tinta(alto: Color(hex: "#e0eaf3"), basso: Color(hex: "#b7cbdb"), bordo: Color(hex: "#a2b8c9"), testo: Color(hex: "#5f7c91"))
        static let rosa = Tinta(alto: Color(hex: "#f4e5e2"), basso: Color(hex: "#d9bfb9"), bordo: Color(hex: "#caaea6"), testo: Color(hex: "#a07264"))
        static let verde = Tinta(alto: Color(hex: "#dceee4"), basso: Color(hex: "#b5d1bf"), bordo: Color(hex: "#a5c1b1"), testo: Color(hex: "#648976"))
        static let viola = Tinta(alto: Color(hex: "#ebe5f2"), basso: Color(hex: "#cbc0df"), bordo: Color(hex: "#b5a7ca"), testo: Color(hex: "#8874a0"))
        static let oro = Tinta(alto: Color(hex: "#f4ebd7"), basso: Color(hex: "#dfcba6"), bordo: Color(hex: "#cabb9a"), testo: Color(hex: "#9c8657"))
        static let luce = Color(hex: "#f6fcff")
        static let ombra = Color(r: 39, g: 65, b: 81, a: 0.08)
    }

    /// App Impostazioni (gruppi iOS 5 su fondo a righe).
    enum Impostazioni {
        static let gruppoBordo = Color(hex: "#a5aebc")
        static let gruppoRiflesso = Color(hex: "#f7faff")
        static let rigaBordo = Color(hex: "#c5cbd3")
        static let rigaTitolo = Color(hex: "#242a31")
        static let rigaSottotitolo = Color(hex: "#7c8490")
        static let rigaValore = Color(hex: "#4d6a92")
        static let avvertenza = Color(hex: "#974f45")
        static let nota = Color(hex: "#5f718b")
        static let notaIncisione = Color(hex: "#edf3fc")
        static let intestazioneGruppo = Color(hex: "#4c5c72")
        static let schedeBordo = Color(hex: "#b6b6b6")
        static let segmentoBordo = Color(hex: "#9a9a9a")
        static let segmentoTesto = Color(hex: "#373737")
        static let segmentoAttivoAlto = Color(hex: "#7b7b7b")
        static let segmentoAttivoBasso = Color(hex: "#999")
        static let segmentoAttivoBordo = Color(hex: "#6f6f6f")
        static let segmentoAttivoIncisione = Color(hex: "#5b5b5b")
        static let informazioniFilo = Color(hex: "#e9eff8")
        static let informazioniTesto = Color(hex: "#657f92")
        static let informazioniOcchiello = Color(hex: "#879da9")
        static let informazioniTitolo = Color(hex: "#4c5c72")
        static let numero = Color(hex: "#657f92")
        static let numeroEtichetta = Color(hex: "#8a9eae")
        static let interruttoreSpento = [Color(hex: "#aaa"), Color(hex: "#f7f7f7"), Color(hex: "#eee")]
        static let interruttoreSpentoBordo = Color(hex: "#8a8a8a")
        static let interruttoreAcceso = [Color(hex: "#0b58a8"), Color(hex: "#247bcf"), Color(hex: "#58a0e3"), Color(hex: "#7bb7ec")]
        static let interruttoreAccesoBordo = Color(hex: "#366492")
        static let interruttoreOmbra = Color(r: 0, g: 0, b: 0, a: 0.333)
        static let interruttoreAccesoOmbra = Color(r: 11, g: 53, b: 107, a: 0.5)
        static let interruttoreTestoSpento = Color(hex: "#6d6d6d")
    }

    enum Agenda {
        /// Inchiostro della data sull'icona Agenda (agenda-dateInk).
        static let inchiostroAlto = Color(hex: "#151515")
        static let inchiostroBasso = Color(hex: "#252321")
        static let mese = Color(hex: "#fffaf0")
        static let meseOmbra = Color(hex: "#97151a")
    }
}
