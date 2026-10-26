import SwiftUI

// Centro notifiche (.os-notification-panel del template): pannello in lino grafite a destra,
// sotto la barra superiore, con le notifiche in riquadri chiari.

extension Colori {
    enum Notifiche {
        static let bordo = Color(hex: "#183246")
        static let ombra = Color(r: 12, g: 34, b: 53, a: 0.6)
        static let luce = Color(r: 209, g: 227, b: 237, a: 0.23)
        static let occhiello = Color(hex: "#a6becd")
        static let chiudi = Color(hex: "#a4bccb")
        static let separatore = Color(r: 228, g: 242, b: 250, a: 0.11)
        static let titolo = Color(hex: "#edf5fa")
        static let sottotitolo = Color(hex: "#9cb4c4")
        static let gruppo = Color(hex: "#7f9bab")
        static let voceAlto = Color(r: 255, g: 255, b: 255, a: 0.045)
        static let voceBasso = Color(r: 255, g: 255, b: 255, a: 0.02)
        static let voceBordo = Color(r: 154, g: 181, b: 197, a: 0.11)
        static let voceLuce = Color(r: 255, g: 255, b: 255, a: 0.05)
        static let voceTitolo = Color(hex: "#d9e6ef")
        static let voceDettaglio = Color(hex: "#829fac")
        static let freccia = Color(hex: "#7893a4")
        static let urgente = Color(hex: "#e0796d")
        static let piede = Color(hex: "#698694")
        static let vuoto = Color(hex: "#9cb4c4")
    }
}

extension Gradienti {
    static let voceNotifica = LinearGradient.verticale(Colori.Notifiche.voceAlto, Colori.Notifiche.voceBasso)
}

extension Misure {
    enum Notifiche {
        static let larghezza: CGFloat = 360
        static let destra: CGFloat = 12
        static let alto: CGFloat = 46
        /// Sopra il dock (.os-notification-panel{bottom:98px}).
        static let basso: CGFloat = 98
        static let raggio: CGFloat = 9
        static let raggioVoce: CGFloat = 6
        static let margine: CGFloat = 20
        static let voce = EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 12)
        static let marginiVoce = EdgeInsets(top: 4, leading: 13, bottom: 4, trailing: 13)
        static let icona: CGFloat = 32
    }
}

extension Tipo {
    static let notificheOcchiello = Tipo.sistema(9, .medium)
    static let notificheChiudi = Tipo.sistema(20, .light)
    static let notificheTitolo = Tipo.sistema(22, .light)
    static let notificheSottotitolo = Tipo.sistema(10)
    static let notificheGruppo = Tipo.sistema(9, .semibold)
    static let notificaTitolo = Tipo.sistema(11, .medium)
    static let notificaDettaglio = Tipo.sistema(9)
    static let notificaFreccia = Tipo.sistema(18, .light)
    static let notifichePiede = Tipo.sistema(8)
}
