import SwiftUI

/// Misure, spaziature e raggi del template (in punti, a 1440×900).
enum Misure {
    enum Barra {
        static let altezza: CGFloat = 32
        static let margine: CGFloat = 18
        /// Spazio a sinistra per i pulsanti nativi della finestra macOS.
        static let spazioSemaforiNativi: CGFloat = 70
        static let spazioMarchio: CGFloat = 7
        static let spazioApp: CGFloat = 17
        static let spazioOra: CGFloat = 11
        static let spazioDestra: CGFloat = 17
        static let spazioCerca: CGFloat = 14
        static let icona: CGFloat = 17
        static let avatar: CGFloat = 23
        static let badge: CGFloat = 13
        static let raggioTasto: CGFloat = 3
    }

    enum Scrivania {
        static let margineAlto: CGFloat = 18
        static let margineLato: CGFloat = 30
        static let margineBasso: CGFloat = 10
        static let colonne = 4
        static let spazioColonne: CGFloat = 12
        static let spazioRighe: CGFloat = 6
        static let icona: CGFloat = 64
        static let lanciatoreSpazio: CGFloat = 6
        static let lanciatoreRaggio: CGFloat = 7
        static let badge: CGFloat = 21
        static let colonnaLarghezza: CGFloat = 300
        static let colonnaSpazio: CGFloat = 26
        static let spazioPulsanti: CGFloat = 10
        static let altezzaSezione: CGFloat = 28
    }

    enum Colonna {
        static let raggio: CGFloat = 6
        static let avatar: CGFloat = 39
        static let schedeAltezza: CGFloat = 28
        static let schedeRaggio: CGFloat = 5
        static let data = CGSize(width: 36, height: 48)
        static let dataRaggio: CGFloat = 4
        static let dataMese: CGFloat = 17
        static let iconaEve: CGFloat = 37
    }

    enum Dock {
        static let elemento: CGFloat = 46
        static let icona: CGFloat = 40
        static let spazio: CGFloat = 10
        static let margineOrizzontale: CGFloat = 14
        static let margineAlto: CGFloat = 5
        static let margineBasso: CGFloat = 6
        static let ripianoAltezza: CGFloat = 32
        static let ripianoAlto: CGFloat = 21
        static let ripianoSporgenza: CGFloat = 9
        static let ripianoRientro: CGFloat = 12
        static let ingrandimento: CGFloat = 1.13
        /// Area riservata al dock sotto le finestre (--os-bottom).
        static let riservato: CGFloat = 76
    }

    enum Finestra {
        static let raggio: CGFloat = 8
        static let barraTitolo: CGFloat = 30
        static let margineTitolo: CGFloat = 11
        static let margineLato: CGFloat = 8
        static let margineAlto: CGFloat = 5
        static let margineBasso: CGFloat = 5
        static let semaforo: CGFloat = 13
        static let spazioSemafori: CGFloat = 7
        static let iconaTitolo: CGFloat = 19
        static let affianca = CGSize(width: 27, height: 22)
        static let minima = CGSize(width: 560, height: 360)
        static let raggioAffianca: CGFloat = 3
    }

    enum IntestazioneApp {
        static let margineVerticale: CGFloat = 8
        static let margineOrizzontale: CGFloat = 12
        static let spazio: CGFloat = 10
    }

    enum Pulsante {
        static let raggio: CGFloat = 4
        static let raggioBlu: CGFloat = 5
        static let vetroMargine = EdgeInsets(top: 9, leading: 13, bottom: 9, trailing: 13)
        static let bluMargine = EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
    }

    enum Avvisi {
        static let raggio: CGFloat = 7
        static let distanzaBasso: CGFloat = 100
        static let margine = EdgeInsets(top: 13, leading: 19, bottom: 13, trailing: 19)
    }

    enum Pannello {
        static let raggio: CGFloat = 4
    }
}

/// Durate e curve delle animazioni del template.
enum Animazioni {
    /// Apertura finestra: 0,18 s, cubic-bezier(.2,.8,.3,1).
    static let apertura = Animation.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.18)
    /// Avviso: 0,24 s.
    static let avviso = Animation.easeOut(duration: 0.24)
    /// Icone al passaggio del mouse: 0,22 s.
    static let passaggio = Animation.easeOut(duration: 0.22)
    static let durataAvviso: TimeInterval = 3.4
}
