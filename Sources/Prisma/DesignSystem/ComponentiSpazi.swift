import SwiftUI

// Spazi di lavoro: pannello a fumetto scuro di iOS 5 (cornice blu notte lucida, interno chiaro)
// con le schede degli spazi e la miniatura della disposizione.

extension Colori {
    enum Spazi {
        static let velo = Color(r: 0, g: 0, b: 0, a: 0.35)
        static let corniceAlto = Color(hex: "#56657c")
        static let corniceBasso = Color(hex: "#1d2738")
        static let corniceBordo = Color(hex: "#0d131d")
        static let corniceLuce = Color(r: 255, g: 255, b: 255, a: 0.35)
        static let titolo = Color.white
        static let titoloIncisione = Color(r: 0, g: 0, b: 0, a: 0.55)
        static let sottotitolo = Color(hex: "#c9d3e2")
        static let interno = Color(hex: "#eceef1")
        static let internoBordo = Color(hex: "#0d131d")
        static let scheda = Color.white
        static let schedaBordo = Color(hex: "#b5bcc3")
        static let schedaOmbra = Color(r: 0, g: 0, b: 0, a: 0.18)
        static let nome = Color(hex: "#2b3138")
        static let app = Color(hex: "#6d7480")
        static let pronto = Color(hex: "#7d8794")
        static let schermoAlto = Color(hex: "#4f7aa8")
        static let schermoBasso = Color(hex: "#2b4c74")
        static let schermoBordo = Color(hex: "#23384f")
        static let finestraAlto = Color(hex: "#f3f3f3")
        static let finestraBasso = Color(hex: "#d4d7db")
        static let finestraBordo = Color(hex: "#7f8790")
        static let sezione = Color(hex: "#4c566c")
        static let sezioneIncisione = Color(r: 255, g: 255, b: 255, a: 0.8)
        static let elimina = Color(hex: "#9aa1aa")
        static let piede = Color(hex: "#dfe2e6")
        static let piedeBordo = Color(hex: "#c3c8ce")
        static let piedeTesto = Color(hex: "#5b636e")
    }
}

extension Gradienti {
    static let corniceSpazi = LinearGradient.verticale(Colori.Spazi.corniceAlto, Colori.Spazi.corniceBasso)
    static let schermoSpazi = LinearGradient.verticale(Colori.Spazi.schermoAlto, Colori.Spazi.schermoBasso)
    static let finestraSpazi = LinearGradient.verticale(Colori.Spazi.finestraAlto, Colori.Spazi.finestraBasso)
}

extension Misure {
    enum Spazi {
        /// Stacco tra due finestre affiancate.
        static let stacco: CGFloat = 6
        static let nomeMassimo = 40
        static let pannello = CGSize(width: 780, height: 560)
        static let raggio: CGFloat = 12
        static let cornice: CGFloat = 6
        static let raggioInterno: CGFloat = 7
        static let colonna: CGFloat = 220
        static let spazioSchede: CGFloat = 14
        static let raggioScheda: CGFloat = 8
        static let miniatura = CGSize(width: 196, height: 112)
        static let raggioMiniatura: CGFloat = 4
        static let staccoMiniatura: CGFloat = 2
        static let iconaMiniatura: CGFloat = 26
        static let margine: CGFloat = 16
        static let campoNome: CGFloat = 260
    }
}

extension Tipo {
    static let spaziTitolo = Tipo.sistema(15, .bold)
    static let spaziSottotitolo = Tipo.sistema(11)
    static let spaziSezione = Tipo.sistema(12, .bold)
    static let spaziNome = Tipo.sistema(12, .semibold)
    static let spaziApp = Tipo.sistema(10)
}

/// La disposizione dello spazio in piccolo: lo schermo blu e le finestre con l'icona dell'app.
struct MiniaturaSpazio: View {
    let spazio: SpazioLavoro

    var body: some View {
        let m = Misure.Spazi.miniatura
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Misure.Spazi.raggioMiniatura).fill(Gradienti.schermoSpazi)
            ForEach(Array(spazio.finestre.enumerated()), id: \.offset) { _, f in
                let r = f.frazione
                let c = CGRect(x: r.minX * m.width, y: r.minY * m.height, width: r.width * m.width, height: r.height * m.height)
                    .insetBy(dx: Misure.Spazi.staccoMiniatura, dy: Misure.Spazi.staccoMiniatura)
                ZStack {
                    RoundedRectangle(cornerRadius: 2).fill(Gradienti.finestraSpazi)
                    RoundedRectangle(cornerRadius: 2).strokeBorder(Colori.Spazi.finestraBordo, lineWidth: 0.5)
                    IconaApp(app: f.app, lato: min(Misure.Spazi.iconaMiniatura, c.height - 6))
                }
                .frame(width: c.width, height: c.height)
                .offset(x: c.minX, y: c.minY)
            }
        }
        .frame(width: m.width, height: m.height)
        .overlay(RoundedRectangle(cornerRadius: Misure.Spazi.raggioMiniatura).strokeBorder(Colori.Spazi.schermoBordo, lineWidth: 1))
    }
}
