import SwiftUI

// Centro notifiche nel tema Liquid Glass: pannello di vetro a destra, sotto la barra superiore,
// con le notifiche in schede chiare (.nc e .nt del tema).

extension Colori {
    enum Notifiche {
        /// Vetro del pannello con riempimento coprente: il contenuto dietro non si legge attraverso.
        static let fondo = Tema.Colore.PannelliShell.coprente
        static let occhiello = Tema.Colore.inchiostroSecondario
        static let chiudi = Tema.Colore.inchiostroTerziario
        static let separatore = Tema.Colore.separatore
        static let titolo = Tema.Colore.inchiostro
        static let sottotitolo = Tema.Colore.inchiostroSecondario
        static let gruppo = Tema.Colore.inchiostroSecondario
        /// Le notifiche sono schede del tema (.nt): più chiare al passaggio del mouse.
        static let voceSopra = Tema.Colore.rigaSopra
        static let voceTitolo = Tema.Colore.inchiostro
        static let voceDettaglio = Tema.Colore.inchiostroSecondario
        static let freccia = Tema.Colore.inchiostroTerziario
        static let urgente = Tema.Colore.scadenzaOra
        static let piede = Tema.Colore.inchiostroTerziario
        static let vuoto = Tema.Colore.inchiostroSecondario
    }
}

extension Misure {
    enum Notifiche {
        static let larghezza: CGFloat = Tema.Misura.notificheLarghezza
        static let destra: CGFloat = 12
        static let alto: CGFloat = 46
        /// Sopra il dock.
        static let basso: CGFloat = 98
        static let raggio: CGFloat = Tema.Raggio.notifiche
        static let raggioVoce: CGFloat = Tema.Raggio.schedaNotifica
        static let margine: CGFloat = 14
        static let voce = EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 12)
        static let marginiVoce = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        static let icona: CGFloat = Tema.Misura.iconaNotifica
    }
}

extension Tipo {
    static let notificheOcchiello = Tema.Testo.sfFisso(11.5, .semibold)
    static let notificheChiudi = Tema.Testo.sfFisso(17)
    static let notificheTitolo = Tema.Testo.sfFisso(17, .bold)
    static let notificheSottotitolo = Tema.Testo.sfFisso(12)
    static let notificheGruppo = Tema.Testo.sfFisso(11.5, .semibold)
    static let notificaTitolo = Tema.Testo.sfFisso(13, .semibold)
    static let notificaDettaglio = Tema.Testo.sfFisso(12.5)
    static let notificaFreccia = Tema.Testo.sfFisso(15)
    static let notifichePiede = Tema.Testo.sfFisso(11.5)
}
