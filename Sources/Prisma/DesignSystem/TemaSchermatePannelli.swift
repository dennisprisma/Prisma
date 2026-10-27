import SwiftUI

// MARK: - Gettoni dei pannelli e dei pezzi di shell rimasti (tema Liquid Glass)
// Centro notifiche, spazi di lavoro, guida «Comincia con i tuoi dati», righe della scrivania,
// contrassegno della modalità cliente, cornice dei moduli, presentazione e dock.

extension Tema.Colore {
    /// Colori dei pannelli della shell.
    enum PannelliShell {
        /// Riempimento coprente dei pannelli che galleggiano sopra la scrivania o le finestre (notifiche,
        /// spazi di lavoro): il contenuto dietro non si legge attraverso, nemmeno senza sfocatura.
        static let coprente = Color.dinamico(chiaro: Color(r: 247, g: 247, b: 251, a: 0.95),
                                             scuro: Color(r: 18, g: 29, b: 38, a: 0.96))
        /// Presentazione: la sala resta scura (il cielo scuro dello sfondo d'acqua), anche con l'app in chiaro.
        static let salaAlto = Color(hex: "#123648")
        static let salaBasso = Color(hex: "#081A25")
        /// Barra della presentazione: capsula di vetro scuro con colori fissi (sta sempre sulla sala scura).
        static let barraPresentazione = Color(r: 255, g: 255, b: 255, a: 0.08)
        static let bordoBarraPresentazione = Color(r: 255, g: 255, b: 255, a: 0.14)
        static let luceBarraPresentazione = Color(r: 255, g: 255, b: 255, a: 0.22)
        static let testoPresentazione = Color(r: 255, g: 255, b: 255, a: 0.86)
        static let ombraPaginaPresentazione = Color(r: 0, g: 0, b: 0, a: 0.5)
    }
}

extension Tema.Misura {
    /// Misure dei pannelli della shell.
    enum PannelliShell {
        /// Dock: margine laterale in più, perché i nomi lunghi sotto la prima e l'ultima icona
        /// («Impostazioni») restino dentro la capsula di vetro.
        static let etichetteDockLato: CGFloat = 10
        /// Guida sulla scrivania: margini della capsula.
        static let guida = EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 6)
        static let guidaSpazio: CGFloat = 12
        /// Modalità cliente: capsula nella barra.
        static let modoClienteMargine: CGFloat = 11
        static let modoClienteSpazio: CGFloat = 6
        /// Righe della scrivania e scelta del cliente.
        static let elencoClienti: CGFloat = 270
        static let avatarElenco: CGFloat = 28
        /// Cornice dei moduli: testa e piede (le stesse altezze di `Misure.Benvenuto.corniceModulo`), margini.
        static let testaModulo: CGFloat = 44
        static let piedeModulo: CGFloat = 52
        static let margineModulo: CGFloat = 24
        static let marginePiedeModulo: CGFloat = 20
        static let spazioPiedeModulo: CGFloat = 9
        static let etichettaModulo: CGFloat = 150
        static let spazioCampoModulo: CGFloat = 14
        /// Presentazione: margini interni della barra e sfocatura dell'ombra della pagina.
        static let barraPresentazioneMargine: CGFloat = 18
        static let barraPresentazioneAltezza: CGFloat = 34
        static let barraPresentazioneSpazio: CGFloat = 16
        static let ombraPaginaRaggio: CGFloat = 24
        static let ombraPaginaY: CGFloat = 8
    }
}

extension Tema.Testo {
    /// Caratteri dei pannelli della shell.
    enum PannelliShell {
        static let simboloGuida = Tema.Testo.sf(14, .bold)
        static let titoloGuida = Tema.Testo.occhiello
        static let testoGuida = Tema.Testo.didascalia
        static let chiudiGuida = Tema.Testo.sf(11, .medium)
        static let occhielloModoCliente = Tema.Testo.sf(10.5, .bold)
        static let nomeModoCliente = Tema.Testo.sf(12.5, .semibold)
        static let tastoModoCliente = Tema.Testo.sf(10.5, .medium)
        static let spaziaturaModoCliente: CGFloat = 0.6
        /// Il segno di spunta nella casella delle attività.
        static let spunta = Font.system(size: 8, weight: .bold)
        static let titoloModulo = Tema.Testo.sf(15, .semibold)
        static let presentazione = Tema.Testo.sf(13, .medium).monospacedDigit()
    }
}
