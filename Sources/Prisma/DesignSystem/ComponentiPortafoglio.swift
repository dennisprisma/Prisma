import SwiftUI

// Portafoglio del consulente (in Posizioni): tabelle e barre nello stile delle app di analisi.

extension Colori {
    enum Portafoglio {
        static let barraFondo = Color(hex: "#e3e7ea")
        static let barraBordo = Color(r: 0, g: 0, b: 0, a: 0.12)
        static let misto = Color(hex: "#8a97a3")
        static let mese = Color(hex: "#5e6f7e")
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

/// Barra orizzontale della quota (0…1), del colore del canale.
struct BarraQuotaPortafoglio: View {
    let quota: Double
    let colore: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Colori.Portafoglio.barraFondo)
                Rectangle().fill(colore).frame(width: geo.size.width * CGFloat(min(max(quota, 0), 1)))
            }
        }
        .frame(height: Misure.Portafoglio.barra)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Colori.Portafoglio.barraBordo, lineWidth: 1))
    }
}

extension Colori.Analisi {
    /// Il colore di un canale nelle barre (grigio se misto).
    static func canale(_ c: Canale?) -> Color {
        switch c {
        case .alleanza: return canaleAlleanza
        case .indipendente: return canaleIndipendente
        case nil: return Colori.Portafoglio.misto
        }
    }
}
