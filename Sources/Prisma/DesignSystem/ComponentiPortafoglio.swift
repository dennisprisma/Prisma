import SwiftUI

// Portafoglio del consulente (in Posizioni): tabelle e barre nello stile delle app di analisi.

extension Colori {
    enum Portafoglio {
        static let barraFondo = Tema.Colore.pozzetto
        static let barraBordo = Color.clear
        static let misto = Tema.Colore.inchiostroTerziario
        static let mese = Tema.Colore.inchiostroSecondario
    }
}

extension Misure {
    enum Portafoglio {
        static let colonnaImporto: CGFloat = 112
        static let colonnaProposte: CGFloat = 92
        static let colonnaQuota: CGFloat = 130
        static let colonnaData: CGFloat = 86
        static let colonnaCanale: CGFloat = 112
        static let barra: CGFloat = 8
        static let avatar: CGFloat = 24
        static let emittenti: CGFloat = 380
        /// Da sistemare nei dossier: la colonna del tipo e quella del cliente.
        static let colonnaTipo: CGFloat = 104
        static let colonnaCliente: CGFloat = 170
    }
}

/// Barra orizzontale della quota (0…1), del colore del canale, su un pozzetto arrotondato.
struct BarraQuotaPortafoglio: View {
    let quota: Double
    let colore: Color

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: Tema.Raggio.barraCanali, style: .continuous)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                forma.fill(Colori.Portafoglio.barraFondo)
                forma.fill(colore).frame(width: geo.size.width * CGFloat(min(max(quota, 0), 1)))
            }
        }
        .frame(height: Misure.Portafoglio.barra)
    }
}

extension Colori.Analisi {
    /// Il colore di un canale nelle barre: blu Alleanza e cuoio indipendente del tema (grigio se misto).
    static func canale(_ c: Canale?) -> Color {
        switch c {
        case .alleanza: return Tema.Colore.canaleAlleanza
        case .indipendente: return Tema.Colore.canaleIndipendente
        case nil: return Colori.Portafoglio.misto
        }
    }
}

// MARK: - Presentazione all'incontro

extension Colori {
    enum Presentazione {
        /// Il velo dietro la pagina: scuro come la sala di Keynote, perché la carta risalti.
        static let sfondo = Color(hex: "#16191d")
        static let ombra = Color(r: 0, g: 0, b: 0, a: 0.6)
        static let testo = Color(r: 255, g: 255, b: 255, a: 0.62)
    }
}

extension Misure {
    enum Presentazione {
        static let margine: CGFloat = 28
        static let barra: CGFloat = 40
    }
}
