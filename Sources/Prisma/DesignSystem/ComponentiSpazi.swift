import SwiftUI

// Spazi di lavoro nel tema Liquid Glass: pannello di vetro (.pop/.panel) con le schede degli spazi
// e la miniatura della disposizione sullo sfondo d'acqua.

extension Colori {
    enum Spazi {
        static let velo = Tema.Colore.velo
        /// Vetro del pannello con riempimento coprente.
        static let fondo = Tema.Colore.PannelliShell.coprente
        static let titolo = Tema.Colore.inchiostro
        static let sottotitolo = Tema.Colore.inchiostroSecondario
        /// Le schede degli spazi (.card del tema), evidenziate al passaggio del mouse.
        static let schedaSopra = Tema.Colore.rigaSopra
        static let nome = Tema.Colore.inchiostro
        static let app = Tema.Colore.inchiostroSecondario
        static let pronto = Tema.Colore.inchiostroTerziario
        // Miniatura: lo sfondo d'acqua e le finestre chiare
        static let schermoAlto = Tema.Colore.cielo1
        static let schermoBasso = Tema.Colore.cielo3
        static let schermoBordo = Tema.Colore.bordoScheda
        static let finestraAlto = Tema.Colore.finestraColorata
        static let finestraBasso = Tema.Colore.finestraColorata
        static let finestraBordo = Tema.Colore.bordoScheda
        static let sezione = Tema.Colore.inchiostroSecondario
        static let elimina = Tema.Colore.inchiostroTerziario
        static let piedeBordo = Tema.Colore.separatore
        static let piedeTesto = Tema.Colore.inchiostroSecondario
    }
}

extension Gradienti {
    static let schermoSpazi = LinearGradient(colors: [Colori.Spazi.schermoAlto, Colori.Spazi.schermoBasso],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let finestraSpazi = LinearGradient.verticale(Colori.Spazi.finestraAlto, Colori.Spazi.finestraBasso)
}

extension Misure {
    enum Spazi {
        /// Stacco tra due finestre affiancate.
        static let stacco: CGFloat = 8
        static let nomeMassimo = 40
        static let pannello = CGSize(width: 780, height: 560)
        static let raggio: CGFloat = Tema.Raggio.centroControllo
        static let cornice: CGFloat = 6
        static let raggioInterno: CGFloat = Tema.Raggio.popover
        static let colonna: CGFloat = 220
        static let spazioSchede: CGFloat = 12
        static let raggioScheda: CGFloat = Tema.Raggio.schedaApp
        static let margineScheda: CGFloat = 10
        static let miniatura = CGSize(width: 196, height: 112)
        static let raggioMiniatura: CGFloat = Tema.Raggio.miniatura
        static let staccoMiniatura: CGFloat = 2
        static let iconaMiniatura: CGFloat = 26
        static let margine: CGFloat = 16
        static let campoNome: CGFloat = 260
        /// Raggio delle finestre nella miniatura.
        static let raggioFinestraMiniatura: CGFloat = 4
    }
}

extension Tipo {
    static let spaziTitolo = Tema.Testo.sezione
    static let spaziSottotitolo = Tema.Testo.secondario
    static let spaziSezione = Tema.Testo.sf(12, .semibold)
    static let spaziNome = Tema.Testo.sf(13, .semibold)
    static let spaziApp = Tema.Testo.didascalia
}

/// La disposizione dello spazio in piccolo: lo sfondo e le finestre con l'icona dell'app.
struct MiniaturaSpazio: View {
    let spazio: SpazioLavoro

    var body: some View {
        let m = Misure.Spazi.miniatura
        let finestra = RoundedRectangle(cornerRadius: Misure.Spazi.raggioFinestraMiniatura, style: .continuous)
        let schermo = RoundedRectangle(cornerRadius: Misure.Spazi.raggioMiniatura, style: .continuous)
        ZStack(alignment: .topLeading) {
            schermo.fill(Gradienti.schermoSpazi)
            ForEach(Array(spazio.finestre.enumerated()), id: \.offset) { _, f in
                let r = f.frazione
                let c = CGRect(x: r.minX * m.width, y: r.minY * m.height, width: r.width * m.width, height: r.height * m.height)
                    .insetBy(dx: Misure.Spazi.staccoMiniatura, dy: Misure.Spazi.staccoMiniatura)
                ZStack {
                    finestra.fill(Gradienti.finestraSpazi)
                    finestra.strokeBorder(Colori.Spazi.finestraBordo, lineWidth: Tema.Misura.filo)
                    IconaApp(app: f.app, lato: min(Misure.Spazi.iconaMiniatura, c.height - 6))
                }
                .frame(width: c.width, height: c.height)
                .offset(x: c.minX, y: c.minY)
            }
        }
        .frame(width: m.width, height: m.height)
        .clipShape(schermo)
        .overlay { schermo.strokeBorder(Colori.Spazi.schermoBordo, lineWidth: Tema.Misura.filo) }
    }
}
