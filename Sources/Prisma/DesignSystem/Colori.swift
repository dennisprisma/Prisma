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

    /// App di analisi (Posizioni): elenco laterale blu di Lion, pannello bianco, KPI, tabelle (.fx-*).
    enum Analisi {
        static let railAlto = Color(hex: "#e5ebf3")
        static let railBasso = Color(hex: "#d6dde7")
        static let railTesto = Color(hex: "#303b4a")
        static let railFilo = Color(hex: "#b8c2cf")
        static let railRiflesso = Color(hex: "#f5f8fc")
        static let railEtichetta = Color(hex: "#69788b")
        static let segBordo = Color(hex: "#8f9ba9")
        static let segTesto = Color(hex: "#384554")
        static let segAttivoAlto = Color(hex: "#8896a8")
        static let segAttivoBasso = Color(hex: "#687b92")
        static let segAttivoIncisione = Color(hex: "#4a5b6f")
        static let segAttivoOmbra = Color(r: 38, g: 55, b: 77, a: 0.333)
        static let navAlto = Color(hex: "#7da9dc")
        static let navBasso = Color(hex: "#4279bd")
        static let navBordoAlto = Color(hex: "#5d8dbd")
        static let navBordoBasso = Color(hex: "#34699f")
        static let navLuce = Color(hex: "#a7c8eb")
        static let navIncisione = Color(hex: "#2f5a8e")
        static let navTesto = Color(hex: "#303d4e")
        static let navIncisioneSpento = Color(hex: "#f6f8fb")
        static let navConteggio = Color(hex: "#c3ccd8")
        static let navConteggioTesto = Color(hex: "#55657a")
        static let principale = Color.white
        static let testo = Color(hex: "#30343a")
        static let kpiAlto = Color(hex: "#f8fafc")
        static let kpiBasso = Color(hex: "#e8edf3")
        static let kpiBordo = Color(hex: "#b5bec9")
        static let kpiTitolo = Color(hex: "#617186")
        static let kpiValore = Color(hex: "#203f67")
        static let kpiNota = Color(hex: "#6a7686")
        static let chip = Color(hex: "#edf1f6")
        static let chipBordo = Color(hex: "#b9c3ce")
        static let chipTesto = Color(hex: "#5d6a7d")
        static let pannelloTitolo = Color(hex: "#3a434e")
        static let pannelloNota = Color(hex: "#6a7686")
        static let tabellaTestaAlto = Color(hex: "#fafafa")
        static let tabellaTestaBasso = Color(hex: "#e1e4e8")
        static let tabellaTestaBordo = Color(hex: "#aeb4bc")
        static let tabellaTesta = Color(hex: "#404951")
        static let tabellaRiga = Color(hex: "#e0e5eb")
        static let tabellaAlternata = Color(hex: "#edf3fa")
        static let tabellaSelezione = Color(hex: "#d4e3f5")
        static let tabellaTesto = Color(hex: "#404c59")
        static let tabellaBordo = Color(hex: "#b5becd")
        // Stati
        static let okFondo = Color(hex: "#eaf0e5")
        static let okBordo = Color(hex: "#bac8af")
        static let okTesto = Color(hex: "#567047")
        static let attenzioneFondo = Color(hex: "#f5edd9")
        static let attenzioneBordo = Color(hex: "#d3c294")
        static let attenzioneTesto = Color(hex: "#8a712e")
        static let erroreFondo = Color(hex: "#f4e4e1")
        static let erroreBordo = Color(hex: "#d5b4ae")
        static let erroreTesto = Color(hex: "#974f45")
        static let neutroFondo = Color(hex: "#e2ebef")
        static let neutroBordo = Color(hex: "#c9d7de")
        static let neutroTesto = Color(hex: "#6e899c")
        // Grafici
        static let linea = Color(hex: "#2f6eb0")
        static let lineaTratteggiata = Color(hex: "#a5b3bd")
        static let barre = Color(hex: "#9cb6cc")
        static let griglia = Color(hex: "#d5dde2")
        static let assi = Color(hex: "#7f909b")
        static let tracciaAnello = Color(hex: "#e5e4df")
        static let prudente = Color(hex: "#c5ab7e")
        static let favorevole = Color(hex: "#6e9f9b")
        /// Andamento: dove sarebbe la posizione all'atteso netto.
        static let lineaAtteso = Color(hex: "#c5ab7e")
        static let canaleAlleanza = Color(hex: "#587cad")
        static let canaleIndipendente = Color(hex: "#bba282")
        // Barra di stato in basso
        static let statoAlto = Color(hex: "#f2f2f2")
        static let statoBasso = Color(hex: "#dcdcdc")
        static let statoBordo = Color(hex: "#a7a7a7")
        static let statoLuce = Color(hex: "#5fbf4a")

        /// Colore di ogni area (le prime quattro dal template, le altre nella stessa gamma).
        static func area(_ a: AreaPosizione) -> Color {
            switch a {
            case .investimento: return Color(hex: "#6386a5")
            case .risparmio: return Color(hex: "#94b4a1")
            case .previdenza: return Color(hex: "#c5ab7e")
            case .protezione: return Color(hex: "#6e9f9b")
            case .liquidita: return Color(hex: "#8fa7bf")
            case .immobili: return Color(hex: "#a99382")
            case .debiti: return Color(hex: "#b07a6e")
            }
        }
    }

    /// Moduli e finestre di dialogo (.os-dialog).
    enum Modulo {
        static let titoloAlto = Color(hex: "#e9e9e9")
        static let titoloBasso = Color(hex: "#d0d0d0")
        static let titoloBordo = Color(hex: "#aaa")
        static let piedeAlto = Color(hex: "#e7e7e7")
        static let piedeBasso = Color(hex: "#dcdcdc")
        static let piedeBordo = Color(hex: "#b4b4b4")
    }

    /// App Clienti: rubrica in carta e cuoio (.clients-book).
    enum Rubrica {
        static let fondoApp = Color(hex: "#d9d6cf")
        static let carta = Color(hex: "#fbfaf6")
        static let libroBordo = Color(hex: "#887358")
        static let libroRiflesso = Color(hex: "#ece4d3")
        static let libroOmbra = Color(r: 53, g: 43, b: 31, a: 0.19)
        static let indiceTitolo = Color(hex: "#645b4d")
        static let contatoreAlto = Color(hex: "#e3ddcf")
        static let contatoreBasso = Color(hex: "#d0c7b6")
        static let contatoreBordo = Color(hex: "#b1a58f")
        static let contatoreTesto = Color(hex: "#655846")
        static let rigaNome = Color(hex: "#2f2e2b")
        static let rigaTema = Color(hex: "#787266")
        static let rigaFreccia = Color(hex: "#776d5e")
        static let rigaLuce = Color(r: 255, g: 255, b: 255, a: 0.467)
        static let rigaBordo = Color(r: 199, g: 191, b: 176, a: 0.5)
        static let selezioneAlto = Color(hex: "#82a7d2")
        static let selezioneBasso = Color(hex: "#557fb5")
        static let selezioneBordoAlto = Color(hex: "#a9c0dd")
        static let selezioneBordoBasso = Color(hex: "#496e9c")
        static let selezioneIncisione = Color(hex: "#44688b")
        static let selezioneTema = Color(hex: "#edf3fa")
        static let stella = Color(hex: "#b79557")
        static let stellaSelezione = Color(hex: "#ffe1a4")
        static let stellaGrande = Color(hex: "#ffda7b")
        static let stellaVuota = Color(hex: "#8a7556")
        static let piede = Color(hex: "#6e5e46")
        static let piedeBordo = Color(hex: "#b6a486")
        static let cerca = Color(hex: "#9b998f")
        static let divisoreOmbra = Color(r: 110, g: 98, b: 76, a: 0.533)
        // Intestazione del dossier in cuoio chiaro
        static let selleriaAlto = Color(hex: "#bca27e")
        static let selleriaMezzo = Color(hex: "#b19773")
        static let selleriaBasso = Color(hex: "#a78a64")
        static let selleriaBordo = Color(hex: "#82694a")
        static let selleriaLuce = Color(hex: "#dfc9a8")
        static let selleriaLuceBasso = Color(hex: "#d8c3a2")
        static let profiloOcchiello = Color(hex: "#584a37")
        static let profiloOcchielloIncisione = Color(hex: "#d8c3a3")
        static let profiloNome = Color(hex: "#3a3023")
        static let profiloNomeIncisione = Color(hex: "#e1cfb5")
        static let avatarCornice = Color(hex: "#f0e7d8")
        static let avatarOmbra = Color(r: 95, g: 75, b: 53, a: 0.3)
        static let pulsanteTesto = Color(hex: "#493b29")
        static let pulsanteIncisione = Color(hex: "#ead7b7")
        static let pulsanteBordo = Color(hex: "#887255")
        static let pulsanteLuce = Color(hex: "#e8d9bf")
        // Schede del dossier
        static let schedeAlto = Color(hex: "#e7e1d4")
        static let schedeBasso = Color(hex: "#d5cdbc")
        static let schedeBordo = Color(hex: "#b5a98f")
        static let schedeLuce = Color(hex: "#f6f0e4")
        static let schedaAttivaAlto = Color(hex: "#a9987c")
        static let schedaAttivaBasso = Color(hex: "#c1af91")
        static let schedaAttivaBordo = Color(hex: "#958367")
        static let schedaAttivaTesto = Color(hex: "#3f3322")
        static let schedaAttivaIncisione = Color(hex: "#dccbad")
        static let schedaAttivaOmbra = Color(r: 91, g: 71, b: 38, a: 0.314)
        static let schedaAlto = Color(hex: "#f4eee2")
        static let schedaBasso = Color(hex: "#d9cfbc")
        static let schedaBordo = Color(hex: "#b6a78c")
        static let schedaTesto = Color(hex: "#635640")
        // Contenuto
        static let testo = Color(hex: "#3c382f")
        static let secondario = Color(hex: "#7c7364")
        static let occhiello = Color(hex: "#725737")
        static let sottile = Color(hex: "#8899a3")
        static let filo = Color(hex: "#cfc3ac")
        static let metricaEtichetta = Color(hex: "#787062")
        static let metricaValore = Color(hex: "#33322e")
        static let metricaNota = Color(hex: "#756448")
        static let schedaAppAlto = Color(hex: "#fcfbf6")
        static let schedaAppBasso = Color(hex: "#efebe1")
        static let schedaAppBordo = Color(hex: "#c8c0b0")
        static let conteggio = Color(hex: "#e5e0d5")
        static let conteggioTesto = Color(hex: "#7c7364")
        // Pulsante principale "Nuovo cliente" (aqua del template)
        static let aqua = [Color(hex: "#b8d4ef"), Color(hex: "#87b2df"), Color(hex: "#6da0d2"), Color(hex: "#a5caea")]
        static let aquaBordo = Color(hex: "#6185aa")
        static let aquaTesto = Color(hex: "#243e58")
        static let aquaIncisione = Color(hex: "#d7e8f7")
        static let aquaLuce = Color(hex: "#e6f3ff")
        static let pericolo = Color(hex: "#974f45")
    }

    /// Widget della scrivania, nello stile dei widget della Dashboard di Mac OS X (2011).
    enum Widget {
        static let bordo = Color(hex: "#777")
        static let ombra = Color(hex: "#0004")
        static let ombraVicina = Color(hex: "#0003")
        static let ombraLontana = Color(hex: "#0005")
        static let carta = Color(hex: "#f6f4ef")
        static let cartaBianca = Color(hex: "#fffdf7")
        static let titolo = Color(hex: "#303030")
        static let secondario = Color(hex: "#666")
        static let numero = Color(hex: "#203f67")
        // Calendario da scrivania
        static let calendario = [Color(hex: "#ff7767"), Color(hex: "#ef352d"), Color(hex: "#cc171d"), Color(hex: "#a50c12")]
        static let calendarioBordo = Color(hex: "#7c1317")
        static let calendarioLuce = Color(hex: "#ffb7a2")
        static let calendarioTesto = Color(hex: "#fffaf0")
        static let calendarioSecondario = Color(hex: "#ffd9cf")
        static let calendarioGiorno = Color(hex: "#a8342a")
        static let calendarioPagina = Color(hex: "#fffefa")
        static let calendarioPaginaBasso = Color(hex: "#f0eee8")
        static let calendarioRighe = Color(hex: "#e8dfcf")
        static let calendarioMargine = Color(hex: "#e7a59b")
        static let calendarioOra = Color(hex: "#a8342a")
        static let anelloAlto = Color(hex: "#f4f4f4")
        static let anelloBasso = Color(hex: "#8d8d8d")
        static let anelloBordo = Color(hex: "#5c5c5c")
        // Cartella in pelle del cliente
        static let cucitura = Color(hex: "#e9c89c")
        static let cartoncino = Color(hex: "#f7f0e2")
        static let cartoncinoBasso = Color(hex: "#ebe1cd")
        static let cartoncinoBordo = Color(hex: "#9c7a52")
        static let cartoncinoOmbra = Color(hex: "#3b230f66")
        static let cartoncinoTesto = Color(hex: "#3c3226")
        static let cartoncinoEtichetta = Color(hex: "#8a7557")
        static let cartoncinoValore = Color(hex: "#5a3a1c")
        // Portafoglio (pannello nero lucido come l'app Borsa)
        static let borsaAlto = Color(hex: "#4b4b4f")
        static let borsaMezzo = Color(hex: "#1f1f22")
        static let borsaBasso = Color(hex: "#0e0e10")
        static let borsaBordo = Color(hex: "#000")
        static let borsaRiflesso = Color(r: 255, g: 255, b: 255, a: 0.16)
        static let borsaTitolo = Color(hex: "#9a9aa2")
        static let borsaTesto = Color(hex: "#f2f2f2")
        static let borsaSecondario = Color(hex: "#a7a7ae")
        static let borsaFilo = Color(r: 255, g: 255, b: 255, a: 0.1)
        static let borsaVerde = [Color(hex: "#8fe07a"), Color(hex: "#4fae3a"), Color(hex: "#3a9a27"), Color(hex: "#58b544")]
        static let borsaVerdeBordo = Color(hex: "#2a6e1d")
        static let borsaAlleanza = Color(hex: "#6f9be0")
        static let borsaIndipendente = Color(hex: "#d8bf94")
        // Foglietto giallo delle scadenze
        static let foglietto = Color(hex: "#fbefc0")
        static let fogliettoBasso = Color(hex: "#f5e3a1")
        static let fogliettoRighe = Color(r: 154, g: 171, b: 159, a: 0.4)
        static let fogliettoMargine = Color(hex: "#e0a19a")
        static let fogliettoTesto = Color(hex: "#3d3426")
        static let fogliettoSecondario = Color(hex: "#7c6a48")
        static let rilegaturaAlto = Color(hex: "#6e5944")
        static let rilegaturaMezzo = Color(hex: "#5a4533")
        static let rilegaturaBasso = Color(hex: "#4b3828")
        static let rilegaturaLuce = Color(hex: "#927c61")
        static let rilegaturaOmbra = Color(hex: "#392a1d")
        // Promemoria a righe
        static let promemoriaRighe = Color(hex: "#d9e2ec")
        static let promemoriaTitolo = Color(hex: "#2c4a6e")
        static let promemoriaCerchio = Color(hex: "#9fb1c4")
        static let promemoriaSpunta = Color(hex: "#3a7fae")
        // Eve
        static let onda = [Color(hex: "#b9a6ff"), Color(hex: "#6f5bd6")]
        static let eveAlone = Color(hex: "#8a73ff")
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

        // App Agenda (.os-app-agenda, passata "2011": cuoio chiaro, anelli cromati, pagine color avorio)
        static let fondoApp = Color(hex: "#d3cfc5")
        static let cuoioAlto = Color(hex: "#bca27e")
        static let cuoioMezzo = Color(hex: "#b19773")
        static let cuoioBasso = Color(hex: "#a78a64")
        static let cuoioBordo = Color(hex: "#846c4b")
        static let cuoioLuce = Color(hex: "#ddc9a9")
        static let cuoioLuceBasso = Color(hex: "#8b704f")
        static let cuoioCucitura = Color(hex: "#e3cfac")
        static let cuoioCucituraOmbra = Color(r: 121, g: 96, b: 69, a: 0.53)
        static let cuoioTitolo = Color(hex: "#3e3020")
        static let cuoioTesto = Color(hex: "#5f4b31")
        static let cuoioIncisione = Color(hex: "#ddc9a9")
        static let targhettaCarta = Color(hex: "#f7f4e9")
        static let targhettaBordo = Color(hex: "#8d7150")
        static let targhettaOmbra1 = Color(hex: "#d0bd9c")
        static let targhettaOmbra2 = Color(hex: "#715c40")
        static let targhettaOmbra3 = Color(r: 75, g: 57, b: 38, a: 0.21)
        static let targhettaRossoAlto = Color(hex: "#c15a4d")
        static let targhettaRossoBasso = Color(hex: "#a64134")
        static let targhettaRossoBordo = Color(hex: "#87372b")
        static let targhettaRossoLuce = Color(hex: "#e19280")
        static let targhettaRossoIncisione = Color(hex: "#7c2e26")
        static let targhettaTesto = Color(hex: "#373430")
        static let cartaBordo = Color(hex: "#eeeadd")
        static let carta = Color(hex: "#faf8ef")
        static let libroBordo = Color(hex: "#b6a88e")
        static let libroOmbra1 = Color(hex: "#eee8d8")
        static let libroOmbra2 = Color(hex: "#b3a58b")
        static let libroOmbra3 = Color(r: 89, g: 73, b: 46, a: 0.19)
        static let anello = [Color(hex: "#36312b"), Color(hex: "#9f9a92"), Color(hex: "#fff9ed"), Color(hex: "#fefdfb"),
                             Color(hex: "#8f8e8a"), Color(hex: "#c7c7c2"), Color(hex: "#5c554c"), Color(hex: "#2f2821")]
        static let anelloBordo = Color(hex: "#696056")
        static let anelloOmbra = Color(r: 48, g: 35, b: 28, a: 0.4)
        static let barraStrumenti = Color(hex: "#f3efe3")
        static let settimanaAlto = Color(hex: "#faf7ee")
        static let settimanaBasso = Color(hex: "#eee7d8")
        static let settimanaBordo = Color(hex: "#c8bda7")
        static let giorno = Color(hex: "#6c6250")
        static let giornoNumero = Color(hex: "#494137")
        static let giornoPassaggio = Color(hex: "#e9e3d6")
        static let giornoOggiBordo = Color(hex: "#c7a69f")
        static let giornoOggiNumero = Color(hex: "#ae3930")
        static let selezioneAlto = Color(hex: "#d46e5c")
        static let selezioneBasso = Color(hex: "#b84d3c")
        static let selezioneBordo = Color(hex: "#9c4234")
        static let selezioneLuce = Color(hex: "#edab97")
        static let selezioneIncisione = Color(hex: "#8d382b")
        static let selezioneTesto = Color(hex: "#fff8ef")
        static let puntino = Color(hex: "#ae4740")
        static let puntinoSelezione = Color(hex: "#ffe6d1")
        static let paginaOcchiello = Color(hex: "#a34b40")
        static let paginaTitolo = Color(hex: "#40382e")
        static let paginaNota = Color(hex: "#938777")
        static let paginaBordo = Color(hex: "#c4b38d")
        static let rigatura = Color(r: 156, g: 174, b: 184, a: 0.3)
        static let rigaBordo = Color(hex: "#c9bfa7")
        static let rigaSelezione = Color(hex: "#ece6d5")
        static let rigaSegno = Color(hex: "#b44e43")
        static let ora = Color(hex: "#61574a")
        static let oraFine = Color(hex: "#a49888")
        static let evento = Color(hex: "#2d2a24")
        static let eventoConcluso = Color(hex: "#888174")
        static let eventoCliente = Color(hex: "#8b6950")
        static let eventoDettagli = Color(hex: "#76684e")
        static let freccia = Color(hex: "#88785b")
        static let conclusoTesto = Color(hex: "#6b8261")
        static let conclusoFondo = Color(hex: "#e0e6d6")
        static let scadenzaTesto = Color(hex: "#9a6a2e")
        static let scadenzaFondo = Color(hex: "#f3e2bd")
        static let notaSettimana = Color(hex: "#988c79")
        static let notaSettimanaBordo = Color(r: 213, g: 204, b: 183, a: 0.5)
        static let dettaglioAlto = Color(hex: "#e5decb")
        static let dettaglioFondo = Color(hex: "#f1ecde")
        static let dettaglioBordo = Color(hex: "#c2b59b")
        static let dettaglioOcchiello = Color(hex: "#a18868")
        static let dettaglioTitolo = Color(hex: "#433a2b")
        static let dettaglioCliente = Color(hex: "#90704d")
        static let voceEtichetta = Color(hex: "#998971")
        static let voceValore = Color(hex: "#655745")
        static let voceBordo = Color(r: 194, g: 180, b: 153, a: 0.28)
        static let notaFondo = Color(hex: "#eee6ce")
        static let notaBordo = Color(hex: "#d1c3a1")
        static let notaLuce = Color(hex: "#f9f3df")
        static let notaEtichetta = Color(hex: "#9a7c4f")
        static let notaTesto = Color(hex: "#65563b")
        static let azioniBordo = Color(r: 198, g: 185, b: 159, a: 0.44)
        static let quieto = Color(hex: "#bca481")
        static let quietoTesto = Color(hex: "#958267")
        static let quietoSuggerimento = Color(hex: "#a38e70")
        static let vuotoData = Color(hex: "#c1b39c")
        static let vuotoTitolo = Color(hex: "#8e7c60")
        static let vuotoTesto = Color(hex: "#9c907e")
    }

    /// App Incontri (.os-app-meetings, passata "2011": quaderno di lavoro su carta).
    enum Incontri {
        static let fondoAlto = Color(hex: "#e4e1d7")
        static let fondoBasso = Color(hex: "#d9d8cd")
        static let testo = Color(hex: "#4f574c")
        static let secondario = Color(hex: "#7a7f72")
        static let cartaBordo = Color(hex: "#b7b6a7")
        static let cartaLato = Color(hex: "#f1ede0")
        static let carta = Color(hex: "#fffdf3")
        static let rigatura = Color(r: 135, g: 156, b: 156, a: 0.22)
        static let margine = Color(r: 198, g: 140, b: 140, a: 0.35)
        static let filo = Color(hex: "#cfcbbd")
        static let citazione = Color(hex: "#8a7f62")
        static let citazioneFondo = Color(hex: "#f4efdf")
        static let concluso = Color(hex: "#5f7f4f")
        static let piede = Color(hex: "#ebe8de")
    }

    /// Profilo dei bisogni (scheda del cliente).
    enum Bisogni {
        static func area(_ a: AreaBisogno) -> Color {
            switch a {
            case .casa: return Color(hex: "#94b4a1")
            case .famiglia: return Color(hex: "#6e9f9b")
            case .lavoro: return Color(hex: "#8fa7bf")
            case .pensione: return Color(hex: "#c5ab7e")
            case .salute: return Color(hex: "#b07a6e")
            case .patrimonio: return Color(hex: "#6386a5")
            }
        }
        static func importanza(_ i: Importanza) -> Color {
            switch i {
            case .nessuna: return Color(hex: "#a9a49a")
            case .bassa: return Color(hex: "#7f9a76")
            case .media: return Color(hex: "#c08a3e")
            case .alta: return Color(hex: "#b5523f")
            }
        }
        static let ruotaFondo = Color(hex: "#ebe6da")
        static let ruotaBordo = Color(hex: "#c9bfa9")
        static let cartaFondo = Color(hex: "#fffdf6")
        static let cartaBordo = Color(hex: "#cfc5b0")
        static let cartaOmbra = Color(r: 89, g: 73, b: 46, a: 0.15)
        static let confermato = Color(hex: "#5f7f4f")
        static let confermatoFondo = Color(hex: "#eef3e6")
        static let scartato = Color(hex: "#a39d92")
        static let chipFondo = Color(hex: "#f4efe3")
        static let chipBordo = Color(hex: "#c8bea8")
        static let chipTesto = Color(hex: "#6b5d45")
    }

    /// App Eve (.os-app-eve, passata "2011": lino grafite, conversazione azzurrina, nuvolette lucide).
    enum Eve {
        static let linoAlto = Color(hex: "#5c5e60")
        static let linoBasso = Color(hex: "#505254")
        static let testataAlto = Color(hex: "#64686f")
        static let testataBasso = Color(hex: "#464b53")
        static let testataBordo = Color(hex: "#2e333b")
        static let testataLuce = Color(hex: "#858a92")
        static let testataTesto = Color(hex: "#e3e5e9")
        static let testataTitolo = Color(hex: "#f3f3f4")
        static let testataIncisione = Color(hex: "#272d35")
        static let avvisoAlto = Color(hex: "#dedfe1")
        static let avvisoBasso = Color(hex: "#c6c9cd")
        static let avvisoBordo = Color(hex: "#737a83")
        static let avvisoTesto = Color(hex: "#4c5664")
        static let spiaPronta = Color(hex: "#6fbf4a")
        static let spiaSintesi = Color(hex: "#e0a33a")
        static let conversazioneAlto = Color(hex: "#e1e7ed")
        static let conversazioneBasso = Color(hex: "#d0d9e3")
        static let conversazioneBordo = Color(hex: "#788390")
        static let barraAlto = Color(hex: "#e5e6e8")
        static let barraBasso = Color(hex: "#c8cdd3")
        static let barraBordo = Color(hex: "#98a1ac")
        static let barraTesto = Color(hex: "#52606e")
        static let displayAlto = Color(hex: "#252b34")
        static let displayBasso = Color(hex: "#323a47")
        static let displayBordo = Color(hex: "#525c6b")
        static let displayTesto = Color(hex: "#aab4c4")
        static let nuvolaEveAlto = Color.white
        static let nuvolaEveBasso = Color(hex: "#efefef")
        static let nuvolaEveBordo = Color(hex: "#abb4bc")
        static let nuvolaEveTesto = Color(hex: "#414c58")
        static let nuvolaTuoi = [Color(hex: "#e3f0ba"), Color(hex: "#c4df8d"), Color(hex: "#b8d77f"), Color(hex: "#d1e7a4")]
        static let nuvolaTuaBordo = Color(hex: "#92a76d")
        static let nuvolaTuaTesto = Color(hex: "#3b4d30")
        static let autore = Color(hex: "#7c8996")
        static let azioneAlto = Color(hex: "#fcfcfc")
        static let azioneBasso = Color(hex: "#e4e7e9")
        static let azioneBordo = Color(hex: "#aeb7bf")
        static let azioneTesto = Color(hex: "#536a7e")
        static let campo = Color(hex: "#fbfcfd")
        static let campoBordo = Color(hex: "#9aa8b6")
        static let cartaBordo = Color(hex: "#9c8d74")
        static let cuoioTesto = Color(hex: "#4a3b26")
        static let tappa = Color(hex: "#faf7ee")
        static let tappaBordo = Color(hex: "#c9c1b0")
        static let tappaAttiva = Color(hex: "#e8edf3")
        static let tappaAttivaBordo = Color(hex: "#b2bfcd")
        static let tappaTesto = Color(hex: "#403c32")
        static let tappaNota = Color(hex: "#7b7467")
        static let postitAlto = Color(hex: "#fff2a1")
        static let postitBasso = Color(hex: "#f2df85")
        static let postitTesto = Color(hex: "#5c4c21")
        static let quadroBordo = Color(hex: "#c4bca9")
        static let quadroAlto = Color(hex: "#fcf9ef")
        static let quadroBasso = Color(hex: "#e9e3d2")
        static let quadroTesto = Color(hex: "#716248")
    }

    /// Strumenti di analisi: Simulazioni, Confronti, Analisi 360 (passata "2011", stile Lion).
    enum Strumenti {
        // Console del simulatore con i display a cristalli liquidi (.fin-console, .fin-value-control)
        static let consoleAlto = Color(hex: "#e9e9e6")
        static let consoleBasso = Color(hex: "#d9dcda")
        static let consoleBordo = Color(hex: "#a7aeaf")
        static let consoleTitolo = Color(hex: "#5a625e")
        static let consoleEtichetta = Color(hex: "#535d58")
        static let lcdAlto = Color(hex: "#b9c3a3")
        static let lcdBasso = Color(hex: "#d8dfbd")
        static let lcdBordo = Color(hex: "#747e68")
        static let lcdOmbra = Color(r: 52, g: 67, b: 37, a: 0.33)
        static let lcdTesto = Color(hex: "#2b3824")
        static let lcdLuce = Color(r: 244, g: 247, b: 217, a: 0.47)
        static let spia = Color(hex: "#6fbf4a")
        static let simulatoreBordo = Color(hex: "#9faaa9")
        static let carta = Color(hex: "#fffef7")
        static let cartaRiga = Color(r: 156, g: 175, b: 181, a: 0.07)
        static let risultato = Color(hex: "#3c5147")
        static let risultatoNota = Color(hex: "#576d5d")
        static let risultatoBordo = Color(hex: "#d4d9d2")
        static let negativo = Color(hex: "#a3483c")
        static let positivo = Color(hex: "#4f7a45")
        // Schede delle aree (.plan-area-card)
        static let schedaBordoLato = Color(hex: "#eae6d9")
        static let schedaFondo = Color(hex: "#fffef7")
        static let schedaBordo = Color(hex: "#a9a699")
        static let schedaBordoSopra = Color(hex: "#7c8d9f")
        static let schedaOmbra1 = Color(hex: "#faf7ed")
        static let schedaOmbra2 = Color(hex: "#bfb9a9")
        static let schedaTitolo = Color(hex: "#4b5867")
        static let schedaValore = Color(hex: "#3c4650")
        static let schedaNota = Color(hex: "#747b7d")
        static let schedaNumero = Color(hex: "#81878c")
        static let schedaFilo = Color(hex: "#d8d5c9")
        static let titolo = Color(hex: "#35414d")
        static let occhiello = Color(hex: "#7a838c")
        // Pannello delle ipotesi e dei risultati (.plan-parameters, .plan-results)
        static let ipotesiTestaAlto = Color(hex: "#edf0f4")
        static let ipotesiTestaBasso = Color(hex: "#dce2e9")
        static let ipotesiBordo = Color(hex: "#b6bfcb")
        static let ipotesiTesto = Color(hex: "#4a5665")
        static let ipotesiRiga = Color(hex: "#c3ccd7")
        static let ipotesiNota = Color(hex: "#626e7d")
        static let layoutBordo = Color(hex: "#9ea8b3")
        static let risultati = Color(hex: "#fdfdfa")
        static let schedeAlto = Color(hex: "#f8f8f8")
        static let schedeBasso = Color(hex: "#e8e8e8")
        static let schedeBordo = Color(hex: "#b8bec4")
        static let schedaAttivaAlto = Color(hex: "#cad1da")
        static let schedaAttivaBasso = Color(hex: "#e3e7ed")
        static let schedaAttivaBordo = Color(hex: "#b5bdc7")
        static let schedaAttivaTesto = Color(hex: "#3f526a")
        static let schedaTesto = Color(hex: "#626d7a")
        static let piede = Color(hex: "#efefed")
        static let piedeBordo = Color(hex: "#c9cdcf")
        static let piedeTesto = Color(hex: "#74808b")
        static let metodoFondo = Color(hex: "#f8f6eb")
        static let metodoBordo = Color(hex: "#d3cfbc")
        static let metodoTesto = Color(hex: "#81795c")
        static let rischioPresenteFondo = Color(hex: "#eaf0e7")
        static let rischioPresenteBordo = Color(hex: "#b9c7b0")
        static let rischioPresenteTesto = Color(hex: "#647c55")
        static let rischioAssenteFondo = Color(hex: "#f2f3f3")
        static let rischioAssenteBordo = Color(hex: "#d0d5d5")
        static let rischioAssenteTesto = Color(hex: "#7c8686")
        // Serie dei confronti: A, B, C
        static let serie = [Color(hex: "#2f6eb0"), Color(hex: "#c08a3e"), Color(hex: "#6e9f9b")]
    }

    /// App Attività (.os-app-tasks, passata "2011": lino grafite, registro a righe).
    enum Attivita {
        static let linoAlto = Color(hex: "#5c5e60")
        static let linoBasso = Color(hex: "#505254")
        static let testataAlto = Color(hex: "#66676a")
        static let testataBasso = Color(hex: "#4b4d50")
        static let testataBordo = Color(hex: "#343638")
        static let testataLuce = Color(hex: "#888a8c")
        static let testataTitolo = Color(hex: "#f4f4f4")
        static let testataTesto = Color(hex: "#d3d4d5")
        static let testataIncisione = Color(hex: "#292b2d")
        static let numero = Color(hex: "#e5e6e7")
        static let numeroIncisione = Color(hex: "#353638")
        static let separatore = Color(hex: "#393c3e")
        static let separatoreLuce = Color(hex: "#727477")
        static let progressoFondo = Color(hex: "#bdc7c9")
        static let progressoBordo = Color(hex: "#a9b5b9")
        static let progressoAlto = Color(hex: "#96ad94")
        static let progressoBasso = Color(hex: "#698b67")
        static let registroBordo = Color(hex: "#606467")
        static let registroFondo = Color(hex: "#fcfcf8")
        static let registroOmbra1 = Color(hex: "#8b8d8d")
        static let registroOmbra2 = Color(hex: "#363a3b")
        static let metalloAlto = Color(hex: "#ededed")
        static let metalloBasso = Color(hex: "#d6d6d6")
        static let metalloBordo = Color(hex: "#a1a6a9")
        static let carta = Color(hex: "#fafbf7")
        static let rigatura = Color(r: 188, g: 203, b: 214, a: 0.33)
        static let margine = Color(r: 198, g: 140, b: 140, a: 0.33)
        static let titoloElenco = Color(hex: "#83969e")
        static let titoloElencoFondo = Color(r: 237, g: 240, b: 237, a: 0.67)
        static let titoloElencoBordo = Color(hex: "#b7c3ca")
        static let rigaBordo = Color(r: 185, g: 200, b: 209, a: 0.4)
        static let rigaSelezione = Color(r: 223, g: 231, b: 237, a: 0.53)
        static let rigaTitolo = Color(hex: "#262a2e")
        static let rigaTitoloFatto = Color(hex: "#96a29f")
        static let rigaSotto = Color(hex: "#697686")
        static let scadenza = Color(hex: "#8a9a9f")
        static let scadenzaOggi = Color(hex: "#b68539")
        static let scadenzaPassata = Color(hex: "#b36758")
        static let scadenzaFatta = Color(hex: "#81997d")
        static let prioritaAlta = Color(hex: "#b47162")
        static let prioritaBassa = Color(hex: "#7c9678")
        static let spuntaAlto = Color(hex: "#e6e9e7")
        static let spuntaBordo = Color(hex: "#9da7aa")
        static let spuntaFattaAlto = Color(hex: "#a8b99e")
        static let spuntaFattaBasso = Color(hex: "#849c78")
        static let spuntaFattaBordo = Color(hex: "#718368")
        static let dettaglioAlto = Color(hex: "#e3e5de")
        static let dettaglioFondo = Color(hex: "#f3f4ed")
        static let dettaglioBordo = Color(hex: "#b5bdbb")
        static let dettaglioOcchiello = Color(hex: "#8e9c97")
        static let dettaglioTitolo = Color(hex: "#353b3d")
        static let dettaglioCliente = Color(hex: "#637284")
        static let voceEtichetta = Color(hex: "#91a197")
        static let voceValore = Color(hex: "#64776b")
        static let voceBordo = Color(r: 189, g: 203, b: 193, a: 0.35)
        static let collegamentoFondo = Color(hex: "#edf0e7")
        static let collegamentoBordo = Color(hex: "#c9d0c1")
        static let collegamentoEtichetta = Color(hex: "#7b9681")
        static let collegamentoTitolo = Color(hex: "#687f6c")
        static let collegamentoTesto = Color(hex: "#93a597")
        static let nota = Color(hex: "#a0aaa5")
        static let vuoto = Color(hex: "#b4c2b7")
        static let vuotoTitolo = Color(hex: "#85988b")
        static let vuotoTesto = Color(hex: "#97a69f")
    }
}
