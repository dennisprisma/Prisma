import SwiftUI

extension LinearGradient {
    /// Gradiente verticale con fermate esplicite (come `linear-gradient(...)` del CSS).
    static func verticale(_ fermate: [(Color, CGFloat)]) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: fermate.map { Gradient.Stop(color: $0.0, location: $0.1) }),
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Gradiente verticale a due colori.
    static func verticale(_ alto: Color, _ basso: Color) -> LinearGradient {
        LinearGradient(colors: [alto, basso], startPoint: .top, endPoint: .bottom)
    }

    /// Gradiente "lucido" a quattro fermate con il salto netto a metà (pulsanti e badge 2011).
    static func lucido(_ colori: [Color], salto: (CGFloat, CGFloat)) -> LinearGradient {
        verticale([(colori[0], 0), (colori[1], salto.0), (colori[2], salto.1), (colori[3], 1)])
    }
}

/// Gradienti ricorrenti del template.
enum Gradienti {
    /// --apple-bezel: pulsanti di vetro e segmenti non premuti.
    static let vetro = LinearGradient.verticale([
        (Color(hex: "#fdfdfd"), 0), (Color(hex: "#fafafa"), 0.42),
        (Color(hex: "#efefef"), 0.60), (Color(hex: "#e5e5e5"), 1),
    ])

    static let barra = LinearGradient.verticale(Colori.Barra.sfondoAlto, Colori.Barra.sfondoBasso)

    static let avatarUtente = LinearGradient.verticale(Color(hex: "#f7f7f7"), Color(hex: "#c0c4c8"))

    /// Velo sopra lo sfondo della scrivania: linear-gradient(110deg, …).
    static let veloSfondo = LinearGradient(
        colors: [Colori.Sfondo.veloInizio, Colori.Sfondo.veloFine],
        startPoint: UnitPoint(x: 0.03, y: 0.33), endPoint: UnitPoint(x: 0.97, y: 0.67)
    )

    static let schedeColonna = LinearGradient.verticale(Colori.Colonna.schedeAlto, Colori.Colonna.schedeBasso)
    static let segmentoAttivo = LinearGradient.verticale(Colori.Pulsante.segmentoAttivoAlto, Colori.Pulsante.segmentoAttivoBasso)
    static let data = LinearGradient.verticale(Colori.Colonna.dataAlto, Colori.Colonna.dataBasso)
    static let dataMese = LinearGradient.verticale(Colori.Colonna.dataMeseAlto, Colori.Colonna.dataMeseBasso)
    static let lino = LinearGradient.verticale(Colori.Lino.alto, Colori.Lino.basso)

    /// Ripiano del dock.
    static let ripiano = LinearGradient.verticale([
        (Color(r: 232, g: 237, b: 241, a: 0.62), 0), (Color(r: 190, g: 198, b: 205, a: 0.52), 0.45),
        (Color(r: 139, g: 152, b: 163, a: 0.65), 0.85), (Color(r: 239, g: 242, b: 245, a: 0.85), 1),
    ])

    static let divisoreDock = LinearGradient.verticale([
        (Color.clear, 0), (Colori.Dock.divisoreMezzo, 0.5), (Colori.Dock.divisoreBasso, 1),
    ])

    static func barraTitolo(attiva: Bool) -> LinearGradient {
        attiva
            ? .verticale(Colori.Finestra.titoloAttivaAlto, Colori.Finestra.titoloAttivaBasso)
            : .verticale(Colori.Finestra.titoloInattivaAlto, Colori.Finestra.titoloInattivaBasso)
    }

    static let affianca = LinearGradient.verticale(Colori.Finestra.affiancaAlto, Colori.Finestra.affiancaBasso)

    static let intestazioneApp = LinearGradient.verticale([
        (Colori.IntestazioneApp.alto, 0), (Colori.IntestazioneApp.mezzo, 0.65), (Colori.IntestazioneApp.basso, 1),
    ])

    static let pulsanteBlu = LinearGradient.lucido(Colori.Pulsante.blu, salto: (0.49, 0.50))
    static let pulsanteCuoio = LinearGradient.lucido(Colori.Pulsante.cuoio, salto: (0.48, 0.49))
    static let badgeGrande = LinearGradient.lucido(Colori.Badge.grande, salto: (0.48, 0.50))
    static let badgePiccolo = LinearGradient.lucido(Colori.Badge.piccolo, salto: (0.49, 0.51))
    static let avviso = LinearGradient.verticale(Colori.Avvisi.alto, Colori.Avvisi.basso)

    static func avatar(_ t: Colori.Avatar.Tinta) -> LinearGradient {
        .verticale(t.alto, t.basso)
    }

    /// Pulsanti dei semafori: radial-gradient(at 50% 88%, …).
    static func semaforo(_ colori: [Color], fermate: (CGFloat, CGFloat, CGFloat), lato: CGFloat) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: colori[0], location: fermate.0),
                .init(color: colori[1], location: fermate.1),
                .init(color: colori[2], location: fermate.2),
            ]),
            center: UnitPoint(x: 0.5, y: 0.88), startRadius: 0, endRadius: lato * 1.01
        )
    }

    static let agendaInchiostro = LinearGradient.verticale(Colori.Agenda.inchiostroAlto, Colori.Agenda.inchiostroBasso)
}
