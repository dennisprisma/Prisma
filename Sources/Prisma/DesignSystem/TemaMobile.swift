#if os(macOS)
// Solo iPhone e iPad: sul Mac questi gettoni non esistono (il guscio del Mac usa Tema.Misura.Shell).
#elseif os(iOS)
import SwiftUI

// MARK: - Gettoni del guscio di iPhone e iPad (Sources/Prisma/iOS/)
// Stesso tema Liquid Glass del Mac (Design/tema-liquid-glass.html, con la sua impaginazione da telefono
// `@media (max-width: 760px)`): i colori e il vetro vengono da Tema e Vetro; qui solo le misure e i caratteri
// propri delle schermate touch (scrivania, barra, dock e finestre di iPhone e iPad, apertura del backup).

extension Tema.Misura {
    enum Mobile {
        /// Icona in vetro delle app negli elenchi (passi dell'apertura del backup, righe delle app).
        static let iconaLaterale: CGFloat = 30
        /// Logo di Prisma sull'apertura del backup.
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
        /// L'avviso temporaneo (.toast) sopra il dock: dal bordo della safe area in basso.
        static let avvisoBasso: CGFloat = 72
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
        /// Impostazioni: sotto questa larghezza dell'app la colonna delle informazioni a destra non c'è.
        static let sogliaInformazioniImpostazioni: CGFloat = 820
    }
}

extension Tema.Raggio {
    enum Mobile {
        static let scheda: CGFloat = Tema.Raggio.scheda
        static let riga: CGFloat = Tema.Raggio.riga
        static let apertura: CGFloat = Tema.Raggio.pannello
        /// La finestra dell'app sull'iPhone (--r-win del tema) e sull'iPad (come una finestra ingrandita del Mac).
        static let finestraTelefono: CGFloat = Tema.Raggio.finestra
        static let finestraiPad: CGFloat = Tema.Raggio.finestraIngrandita
        /// Le tessere del centro di controllo (.cc-tile) e le schede delle app aperte (.sw-card).
        static let tessera: CGFloat = 20
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
        /// Il saluto della scrivania sul telefono (.hero h1 a 28 sotto i 760 punti).
        static let salutoTelefono = Tipo.sistema(28, .bold)
        static let spaziaturaSaluto = Tema.Testo.spaziatura(-0.024, 28)
        /// Barra superiore: «Prisma» (.bar-brand) e il nome dell'app in primo piano (.bar-app).
        static let barraMarchio = Tipo.sistema(14, .bold)
        static let barraApp = Tipo.sistema(14, .medium)
        static let simboloBarra = Tipo.sistema(16, .medium)
        static let avatarBarra = Tipo.arrotondato(11, .bold)
        /// Titolo della finestra di un'app sull'iPad (.win-title).
        static let titoloFinestra = Tipo.sistema(15, .semibold)
        /// Nome sotto le icone della griglia «Tutte le app» e delle app aperte.
        static let etichettaIcona = Tipo.sistema(11.5, .medium)
        static let nomeAppAperta = Tipo.sistema(13, .semibold)
        /// Centro di controllo (.cc-tile h3, .cc-round b / small).
        static let titoloTessera = Tipo.sistema(12, .semibold)
        static let nomeTessera = Tipo.sistema(12.5, .semibold)
        static let statoTessera = Tipo.sistema(11)
        static let simboloTessera = Tipo.sistema(17, .medium)
        /// Titolo dei pannelli «Tutte le app» e «App aperte» (.sw-h).
        static let titoloPannello = Tipo.sistema(19, .bold)
        /// La ✕ della finestra.
        static let simboloChiudi = Tipo.sistema(12, .bold)
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
        /// Velo sul contenuto sotto l'elenco laterale aperto sopra (iPad stretto).
        static let velo = Color.black.opacity(Tema.Misura.Mobile.opacitaVelo)
        /// Fondo dell'elenco laterale aperto sopra il contenuto e della sua striscia chiusa.
        static let fondoLaterale = Colori.Analisi.railAlto
        static let filoLaterale = Colori.ColonneStrumento.divisore
    }
}

// MARK: - Scrivania, barra, dock, finestre e pannelli (giro 3: la scrivania del template su iPhone e iPad)

extension Tema.Misura.Mobile {
    /// La scrivania: sull'iPhone la colonna unica del tema (@media 760), sull'iPad quella del Mac.
    enum Scrivania {
        /// --gut: clamp(16px, 3vw, 44px) → 16 sul telefono.
        static let margineTelefono: CGFloat = 16
        /// Altezze dei widget a una colonna (@media 760: rows 330 310 64 300 280 250; Eve: Tema.Misura.widgetEve).
        static let agenda: CGFloat = 330
        static let cliente: CGFloat = 310
        static let attivita: CGFloat = 300
        static let scadenze: CGFloat = 280
        static let portafoglio: CGFloat = 250
        /// @media 1100: sotto questa larghezza dell'iPad la bacheca va su due colonne (rows 300 64 300 270).
        static let sogliaDueColonne: CGFloat = 1100
        static let filaAlta: CGFloat = 300
        static let filaPortafoglio: CGFloat = 270
        /// .board { min-height: 520px }: sotto, la scrivania dell'iPad scorre.
        static let bachecaMinima: CGFloat = 520
        /// .desk { padding-top: 8px } e .hero { padding-top: 14px }.
        static let alto: CGFloat = 8
        static let salutoAlto: CGFloat = 14
        /// .hero: spazio fra il saluto e i pulsanti quando vanno a capo (gap 16).
        static let salutoPulsanti: CGFloat = 16
        /// Spazio fra l'ultimo contenuto della scrivania e il dock (oltre al dock stesso).
        static let sopraDock: CGFloat = 12
    }

    /// La barra superiore (.bar) sotto la barra di stato di iOS, alta per il dito.
    enum Barra {
        /// --bar-h 34/38 → 44 per il dito (Human Interface Guidelines).
        static let altezza: CGFloat = 44
        /// .bar { padding: 0 8px 0 10px }.
        static let margineSinistro: CGFloat = 10
        static let margineDestro: CGFloat = 8
        static let spazio: CGFloat = 4
        /// .bar-brand / .bar-app: capsula alta 26 → 36, margini 10 (6 a sinistra del logo), spazio 7.
        static let marchio: CGFloat = 36
        static let marchioMargine: CGFloat = 10
        static let marchioMargineSinistro: CGFloat = 6
        static let marchioSpazio: CGFloat = 7
        /// .bar-tools: capsula di vetro sottile alta 30 → 36, pulsanti alti 26 → 32 e larghi almeno 28 → 40.
        static let strumenti: CGFloat = 36
        static let strumentiMargine: CGFloat = 2
        static let strumentiSpazio: CGFloat = 1
        static let pulsante: CGFloat = 40
        static let pulsanteAltezza: CGFloat = 32
        static let pulsanteMargine: CGFloat = 8
        static let pulsanteSpazio: CGFloat = 6
        /// .me: 24 → 28.
        static let avatar: CGFloat = 28
        /// .bar-brand svg.
        static let logo: CGFloat = 19
        /// Il badge della campanella, spostato in alto a destra (.badge top 0 right 0).
        static let spostamentoBadge = CGSize(width: 8, height: -7)
        /// Area di tocco minima dei pulsanti della barra.
        static let tocco: CGFloat = 44
    }

    /// Il dock (.dock) con il lato delle icone di `fitDock` del tema.
    enum Dock {
        /// Lato massimo delle icone: quello del Mac (Tema.Misura.dockIcona).
        static let massimoTelefono: CGFloat = Tema.Misura.dockIcona
        static let massimoiPad: CGFloat = Tema.Misura.dockIcona
        /// Sotto, l'iPad mini in verticale non ci starebbe: è la misura più piccola ammessa.
        static let minimo: CGFloat = 36
        /// fitDock: spazio fra le icone, margine della capsula, margine del divisore (quote del lato).
        static let quotaSpazio: CGFloat = 0.12
        static let quotaMargine: CGFloat = 0.14
        static let quotaDivisore: CGFloat = 0.06
        /// fitDock: il margine orizzontale della capsula ha 2 punti in più, quello del divisore almeno 2.
        static let margineFisso: CGFloat = 2
        static let divisoreMinimo: CGFloat = 2
        /// Lo spazio libero ai lati del dock (max-width: calc(100vw - 12px)).
        static let bordo: CGFloat = 12
        /// Passo dei lati provati da fitDock (0,5 px).
        static let passo: CGFloat = 0.5
        /// I nomi sotto le icone solo con un passo (lato · 1,12) almeno così: quello del dock del Mac, dove
        /// «Impostazioni» ci sta.
        static let passoPerNomi: CGFloat = 56
        /// Dal bordo fisico dello schermo: sopra l'indicatore di iOS sull'iPhone, .dock bottom 10 sull'iPad.
        static let dalBassoTelefono: CGFloat = 14
        static let dalBassoiPad: CGFloat = 10
        /// Area di tocco minima di un'icona.
        static let tocco: CGFloat = 44
        /// La cartella «Tutte le app»: le quattro icone in miniatura (2 × 2) e il loro spazio.
        static let quotaMiniatura: CGFloat = 0.36
        static let quotaSpazioMiniature: CGFloat = 0.06
        /// .ic { border-radius: 23.5% }.
        static let quotaRaggioIcona: CGFloat = 0.235
    }

    /// La finestra di vetro di un'app (deskRect del tema: x 8, y bar + 6, larghezza w − 16, fino al dock).
    enum Finestra {
        static let margine: CGFloat = 8
        static let sopra: CGFloat = 6
        static let sopraDock: CGFloat = 10
        /// La barra del titolo sull'iPad: .tbar 52 (36 sul Mac) → 44 per il dito.
        static let barraTitolo: CGFloat = 44
        /// La ✕ (il semaforo rosso del tema, grande per il dito) e la sua area di tocco.
        static let chiudi: CGFloat = 26
        static let toccoChiudi: CGFloat = 44
        /// Dove sta la ✕: dal bordo sinistro della finestra (.lights left 21, meno il margine dell'area di tocco).
        static let margineChiudi: CGFloat = 10
        static let spazioTitolo: CGFloat = 8
        static let margineDestroTitolo: CGFloat = 14
    }

    /// I pannelli sopra la scrivania (.nc, .cc, .switcher) e la griglia «Tutte le app».
    enum Pannelli {
        /// .nc / .cc: right 10, max-width 100vw − 20, top bar + 6.
        static let margine: CGFloat = 10
        static let sottoBarra: CGFloat = 6
        /// .cc: larghezza, margine interno e spazio fra le tessere.
        static let controllo: CGFloat = 340
        static let margineControllo: CGFloat = 12
        static let spazioTessere: CGFloat = 10
        /// .cc-tile: padding 11px 12px 12px, gap 8.
        static let margineTessera = EdgeInsets(top: 11, leading: 12, bottom: 12, trailing: 12)
        static let spazioTessera: CGFloat = 8
        /// .cc-round i: il cerchio del simbolo, e lo spazio fra cerchio e testo.
        static let cerchioTessera: CGFloat = 36
        static let spazioCerchio: CGFloat = 10
        /// .switcher: larghezza massima, margine dai bordi (100vw − 32), margine interno 20, spazio 14 e 12.
        static let appAperte: CGFloat = 760
        static let bordoAppAperte: CGFloat = 16
        static let margineAppAperte: CGFloat = 20
        static let spazioAppAperte: CGFloat = 12
        static let sottoTitolo: CGFloat = 14
        /// .sw-card: larghezza minima, margini (18 10 14) e spazio 8; l'icona.
        static let schedaApp: CGFloat = 150
        static let margineSchedaApp = EdgeInsets(top: 18, leading: 10, bottom: 14, trailing: 10)
        static let spazioSchedaApp: CGFloat = 8
        static let iconaSchedaApp: CGFloat = 50
        /// «Tutte le app»: 4 colonne su 361 punti, icone 56 con il nome sotto.
        static let cellaApp: CGFloat = 76
        static let iconaGriglia: CGFloat = 56
        static let spazioGriglia: CGFloat = 14
        static let spazioNome: CGFloat = 6
        /// Altezza massima dei pannelli in quota dello schermo (il resto lo vede l'acqua).
        static let quotaAltezza: CGFloat = 0.8
    }
}
#endif
