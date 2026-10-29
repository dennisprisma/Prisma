#if os(macOS)
// Solo iPhone e iPad: sul Mac questi gettoni non esistono (il guscio del Mac usa Tema.Misura.Shell).
#elseif os(iOS)
import SwiftUI

// MARK: - Gettoni del guscio di iPhone e iPad (Sources/Prisma/iOS/)
// Stesso tema Liquid Glass del Mac: i colori e il vetro vengono da Tema e Vetro; qui solo le misure e i
// caratteri propri delle schermate touch (barra laterale dell'iPad, schede dell'iPhone, apertura del backup).

extension Tema.Misura {
    enum Mobile {
        /// Barra laterale dell'iPad (NavigationSplitView).
        static let lateraleMinima: CGFloat = 240
        static let lateraleIdeale: CGFloat = 272
        static let lateraleMassima: CGFloat = 320
        /// Icona in vetro delle app nella barra laterale e nell'elenco «Altro».
        static let iconaLaterale: CGFloat = 30
        /// Logo di Prisma in cima alla barra laterale e sull'apertura del backup.
        static let logoLaterale: CGFloat = 26
        static let logoApertura: CGFloat = 64
        /// Margini delle schermate e spazio fra le schede di vetro.
        static let margine: CGFloat = 16
        static let spazioSchede: CGFloat = 10
        static let spazioRiga: CGFloat = 12
        static let spazioTesto: CGFloat = 3
        /// Riga di un elenco (cliente, posizione, appuntamento): altezza minima per il tocco.
        static let rigaMinima: CGFloat = 56
        static let margineRiga = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        /// Avatar del cliente negli elenchi e nella scheda.
        static let avatarElenco: CGFloat = 38
        static let avatarScheda: CGFloat = 64
        /// Scheda dell'apertura del backup: larghezza massima (iPad) e margini interni.
        static let aperturaMassima: CGFloat = 520
        static let margineApertura: CGFloat = 22
        static let spazioApertura: CGFloat = 16
        /// Campo della password e pulsanti grandi (almeno 44 pt per il dito).
        static let altezzaControllo: CGFloat = 46
        /// Segnaposto «In arrivo su iPad».
        static let iconaInArrivo: CGFloat = 72
        static let testoInArrivoMassimo: CGFloat = 460
    }
}

extension Tema.Raggio {
    enum Mobile {
        static let scheda: CGFloat = Tema.Raggio.scheda
        static let riga: CGFloat = Tema.Raggio.riga
        static let apertura: CGFloat = Tema.Raggio.pannello
        static let controllo: CGFloat = 12
    }
}

extension Tipo {
    enum Mobile {
        static let titoloGrande = Tipo.sistema(28, .bold)
        static let titolo = Tipo.sistema(20, .bold)
        static let sottotitolo = Tipo.sistema(15)
        static let sezione = Tipo.sistema(13, .semibold)
        static let rigaNome = Tipo.sistema(16, .semibold)
        static let rigaDettaglio = Tipo.sistema(13)
        static let rigaValore = Tipo.arrotondato(16, .semibold)
        static let cifraGrande = Tipo.arrotondato(26, .semibold)
        static let etichetta = Tipo.sistema(12, .medium)
        static let corpo = Tipo.sistema(15)
        static let pulsante = Tipo.sistema(16, .semibold)
        static let voceLaterale = Tipo.sistema(15, .medium)
        static let marchio = Tipo.sistema(17, .bold)
        static let stato = Tipo.sistema(11.5, .semibold)
    }
}

extension Tema.Colore {
    enum Mobile {
        /// Testo degli errori dell'apertura del backup (lo stesso rosso delle scadenze).
        static let errore = Tema.Colore.scadenzaOra
        /// Conferma dell'apertura riuscita.
        static let riuscita = Tema.Colore.testoInEssere
        /// Voce scelta nella barra laterale dell'iPad.
        static let selezione = Tema.Colore.selezioneRiga
    }
}
#endif
