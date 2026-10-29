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

        // MARK: Impaginazione adattiva dell'iPad (le viste App* del Mac dentro la colonna di dettaglio)
        // La colonna di dettaglio dell'iPad va da circa 470 pt (11" verticale con la barra laterale) a circa
        // 1.100 pt (13" orizzontale): sotto queste soglie le colonne del Mac si chiudono o vanno una sotto l'altra.

        /// Area di tocco minima dei controlli principali (Human Interface Guidelines).
        static let areaTocco: CGFloat = 44
        /// Sotto questa larghezza del contenuto dell'app l'elenco laterale (Posizioni, cornice degli strumenti,
        /// rubrica di Clienti) si chiude in una striscia con un pulsante e si apre sopra il contenuto.
        static let sogliaLaterale: CGFloat = 760
        /// La striscia dell'elenco laterale chiuso e il suo pulsante.
        static let strisciaLaterale: CGFloat = 52
        static let margineStriscia: CGFloat = 4
        /// L'elenco laterale aperto sopra il contenuto: raggio e velo sul contenuto (si tocca per chiudere).
        static let raggioLateraleAperto: CGFloat = Tema.Raggio.scheda
        static let opacitaVelo: Double = 0.18
        /// Due colonne di una cornice (`ColonneAffiancate`): sotto questa larghezza della colonna che prende il
        /// resto, le due colonne vanno una sotto l'altra; la colonna fissa si stringe fino a `colonnaMinima`.
        static let flessibileMinima: CGFloat = 360
        static let colonnaMinima: CGFloat = 240
        /// Colonna fissa impilata sopra l'altra: quota massima dell'altezza (il resto va ai risultati).
        static let quotaColonnaImpilata: CGFloat = 0.42
        /// Pannelli affiancati dentro una scheda (Posizioni, dettaglio della posizione, pannelli dell'analisi):
        /// sotto queste larghezze del contenuto vanno uno sotto l'altro.
        static let sogliaAffiancatiPosizioni: CGFloat = 760
        static let sogliaAffiancatiDettaglio: CGFloat = 700
        static let sogliaAffiancatiPannello: CGFloat = 640
        /// Spazio verticale fra due blocchi impilati.
        static let spazioImpilati: CGFloat = 18
        /// Rubrica di Clienti: larghezza sull'iPad e altezza minima della testata del dossier su due righe.
        static let rubrica: CGFloat = 240
        static let testataDossierDueRighe: CGFloat = 8
        /// La finestra di vetro dell'app nella colonna di dettaglio dell'iPad: margine dall'acqua ai lati e in basso.
        static let margineFinestra: CGFloat = 12
        /// Impostazioni: sotto questa larghezza dell'app la colonna delle informazioni a destra non c'è.
        static let sogliaInformazioniImpostazioni: CGFloat = 820
    }
}

extension Tema.Raggio {
    enum Mobile {
        static let scheda: CGFloat = Tema.Raggio.scheda
        static let riga: CGFloat = Tema.Raggio.riga
        static let apertura: CGFloat = Tema.Raggio.pannello
        /// La finestra dell'app nella colonna di dettaglio dell'iPad (come una finestra ingrandita del Mac).
        static let finestra: CGFloat = Tema.Raggio.finestraIngrandita
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
        /// Velo sul contenuto sotto l'elenco laterale aperto sopra (iPad stretto).
        static let velo = Color.black.opacity(Tema.Misura.Mobile.opacitaVelo)
        /// Fondo dell'elenco laterale aperto sopra il contenuto e della sua striscia chiusa.
        static let fondoLaterale = Colori.Analisi.railAlto
        static let filoLaterale = Colori.ColonneStrumento.divisore
    }
}
#endif
