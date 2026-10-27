import SwiftUI

extension LinearGradient {
    /// Gradiente verticale con fermate esplicite (come `linear-gradient(...)` del CSS).
    static func verticale(_ fermate: [(Color, CGFloat)]) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: fermate.map { Gradient.Stop(color: $0.0, location: $0.1) }),
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Gradiente verticale a due colori.
    static func verticale(_ alto: Color, _ basso: Color) -> LinearGradient {
        LinearGradient(colors: [alto, basso], startPoint: .top, endPoint: .bottom)
    }

    /// Gradiente a quattro fermate con un salto a metà (nel tema i colori sono quasi uguali: niente lucido 2011).
    static func lucido(_ colori: [Color], salto: (CGFloat, CGFloat)) -> LinearGradient {
        verticale([(colori[0], 0), (colori[1], salto.0), (colori[2], salto.1), (colori[3], 1)])
    }
}

/// Gradienti ricorrenti. Nel tema «Liquid Glass» quasi tutti diventano tinte piatte o sfumature morbide
/// (i colori vengono da `Colori`, che seguono l'aspetto chiaro o scuro): i nomi restano quelli di prima.
enum Gradienti {
    /// Pulsanti di vetro e segmenti non premuti: il chip del tema, appena più chiaro in alto.
    static let vetro = LinearGradient.verticale(Tema.Colore.chipSopra, Tema.Colore.chip)

    static let barra = LinearGradient.verticale(Colori.Barra.sfondoAlto, Colori.Barra.sfondoBasso)

    /// Avatar del consulente nella barra (.me del tema).
    static let avatarUtente = LinearGradient.verticale(Color(hex: "#8FB3CF"), Color(hex: "#36607F"))

    /// Ex velo sopra la foto della scrivania: ora trasparente (lo sfondo è l'acqua).
    static let veloSfondo = LinearGradient(
        colors: [Colori.Sfondo.veloInizio, Colori.Sfondo.veloFine],
        startPoint: UnitPoint(x: 0.03, y: 0.33), endPoint: UnitPoint(x: 0.97, y: 0.67)
    )

    static let schedeColonna = LinearGradient.verticale(Colori.Colonna.schedeAlto, Colori.Colonna.schedeBasso)
    static let segmentoAttivo = LinearGradient.verticale(Colori.Pulsante.segmentoAttivoAlto, Colori.Pulsante.segmentoAttivoBasso)
    static let data = LinearGradient.verticale(Colori.Colonna.dataAlto, Colori.Colonna.dataBasso)
    static let dataMese = LinearGradient.verticale(Colori.Colonna.dataMeseAlto, Colori.Colonna.dataMeseBasso)
    static let lino = LinearGradient.verticale(Colori.Lino.alto, Colori.Lino.basso)
    /// Ex pelle: nel tema è trasparente (vedi Materiale.Pelle).
    static let pelle = LinearGradient.verticale([
        (Colori.Colonna.pelleAlto, 0), (Colori.Colonna.pelleMezzo, 0.46), (Colori.Colonna.pelleBasso, 1),
    ])
    static let pelleRiflesso = RadialGradient(colors: [Colori.Colonna.pelleRiflesso, .clear],
                                              center: UnitPoint(x: 0.2, y: 0.05), startRadius: 0, endRadius: 320)
    static let pannelloWidget = LinearGradient.verticale(Colori.Widget.pannelloAlto, Colori.Widget.pannelloBasso)
    static let casella = LinearGradient.verticale(Colori.Colonna.casellaAlto, Colori.Colonna.casellaBasso)

    /// Ex ripiano del dock: il vetro sottile del tema (riempimento senza materiali).
    static let ripiano = LinearGradient.verticale(Colori.Dock.ripianoFondo, Colori.Dock.ripianoFondo)

    static let divisoreDock = LinearGradient.verticale([
        (Color.clear, 0), (Colori.Dock.divisoreMezzo, 0.5), (Colori.Dock.divisoreBasso, 1),
    ])

    static func barraTitolo(attiva: Bool) -> LinearGradient {
        attiva
            ? .verticale(Colori.Finestra.titoloAttivaAlto, Colori.Finestra.titoloAttivaBasso)
            : .verticale(Colori.Finestra.titoloInattivaAlto, Colori.Finestra.titoloInattivaBasso)
    }

    static let affianca = LinearGradient.verticale(Colori.Finestra.affiancaAlto, Colori.Finestra.affiancaBasso)

    static let intestazioneApp = LinearGradient.verticale([
        (Colori.IntestazioneApp.alto, 0), (Colori.IntestazioneApp.mezzo, 0.65), (Colori.IntestazioneApp.basso, 1),
    ])

    static let pulsanteBlu = LinearGradient.lucido(Colori.Pulsante.blu, salto: (0.49, 0.50))
    static let pulsanteCuoio = LinearGradient.lucido(Colori.Pulsante.cuoio, salto: (0.48, 0.49))
    static let badgeGrande = LinearGradient.lucido(Colori.Badge.grande, salto: (0.48, 0.50))
    static let badgePiccolo = LinearGradient.lucido(Colori.Badge.piccolo, salto: (0.49, 0.51))
    static let avviso = LinearGradient.verticale(Colori.Avvisi.alto, Colori.Avvisi.basso)

    static func avatar(_ t: Colori.Avatar.Tinta) -> LinearGradient {
        .verticale(t.alto, t.basso)
    }

    /// Pulsanti dei semafori: radial-gradient(at 50% 88%, …) (nel tema i tre colori sono uguali: tinta piatta).
    static func semaforo(_ colori: [Color], fermate: (CGFloat, CGFloat, CGFloat), lato: CGFloat) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: colori[0], location: fermate.0),
                .init(color: colori[1], location: fermate.1),
                .init(color: colori[2], location: fermate.2),
            ]),
            center: UnitPoint(x: 0.5, y: 0.88), startRadius: 0, endRadius: lato * 1.01
        )
    }

    static let interruttoreSpento = LinearGradient.verticale([
        (Colori.Impostazioni.interruttoreSpento[0], 0), (Colori.Impostazioni.interruttoreSpento[1], 0.48),
        (Colori.Impostazioni.interruttoreSpento[2], 1),
    ])
    static let interruttoreAcceso = LinearGradient.lucido(Colori.Impostazioni.interruttoreAcceso, salto: (0.49, 0.50))
    static let segmentoImpostazioni = LinearGradient.verticale(Colori.Impostazioni.segmentoAttivoAlto, Colori.Impostazioni.segmentoAttivoBasso)

    static let calendario = LinearGradient.verticale([
        (Colori.Widget.calendario[0], 0), (Colori.Widget.calendario[1], 0.17),
        (Colori.Widget.calendario[2], 0.68), (Colori.Widget.calendario[3], 1),
    ])

    static let selezioneRubrica = LinearGradient.verticale(Colori.Rubrica.selezioneAlto, Colori.Rubrica.selezioneBasso)
    static let contatoreRubrica = LinearGradient.verticale(Colori.Rubrica.contatoreAlto, Colori.Rubrica.contatoreBasso)
    static let selleria = LinearGradient.verticale([
        (Colori.Rubrica.selleriaAlto, 0), (Colori.Rubrica.selleriaMezzo, 0.48), (Colori.Rubrica.selleriaBasso, 1),
    ])
    static let schedeRubrica = LinearGradient.verticale(Colori.Rubrica.schedeAlto, Colori.Rubrica.schedeBasso)
    static let schedaRubricaAttiva = LinearGradient.verticale(Colori.Rubrica.schedaAttivaAlto, Colori.Rubrica.schedaAttivaBasso)
    static let schedaRubrica = LinearGradient.verticale(Colori.Rubrica.schedaAlto, Colori.Rubrica.schedaBasso)
    static let schedaApp = LinearGradient.verticale(Colori.Rubrica.schedaAppAlto, Colori.Rubrica.schedaAppBasso)
    static let aqua = LinearGradient.lucido(Colori.Rubrica.aqua, salto: (0.48, 0.49))

    static let railAnalisi = LinearGradient.verticale(Colori.Analisi.railAlto, Colori.Analisi.railBasso)
    /// Fondo dei segmenti delle analisi: il pozzetto del tema.
    static let controlloLion = LinearGradient.verticale(Tema.Colore.pozzetto, Tema.Colore.pozzetto)
    static let segAnalisiAttivo = LinearGradient.verticale(Colori.Analisi.segAttivoAlto, Colori.Analisi.segAttivoBasso)
    static let navAnalisi = LinearGradient.verticale(Colori.Analisi.navAlto, Colori.Analisi.navBasso)
    static let kpi = LinearGradient.verticale(Colori.Analisi.kpiAlto, Colori.Analisi.kpiBasso)
    static let testaTabella = LinearGradient.verticale(Colori.Analisi.tabellaTestaAlto, Colori.Analisi.tabellaTestaBasso)
    static let barraStato = LinearGradient.verticale(Colori.Analisi.statoAlto, Colori.Analisi.statoBasso)

    // Widget
    static let paginaCalendario = LinearGradient.verticale(Colori.Widget.calendarioPagina, Colori.Widget.calendarioPaginaBasso)
    static let anello = LinearGradient(colors: [Colori.Widget.anelloAlto, Colori.Widget.anelloBasso],
                                       startPoint: .leading, endPoint: .trailing)
    static let cartoncino = LinearGradient.verticale(Colori.Widget.cartoncino, Colori.Widget.cartoncinoBasso)
    static let borsa = LinearGradient.verticale([
        (Colori.Widget.borsaAlto, 0), (Colori.Widget.borsaMezzo, 0.45), (Colori.Widget.borsaBasso, 1),
    ])
    static let borsaRiflesso = LinearGradient(colors: [Colori.Widget.borsaRiflesso, .clear], startPoint: .top, endPoint: .center)
    static let borsaVerde = LinearGradient.lucido(Colori.Widget.borsaVerde, salto: (0.49, 0.51))
    static let foglietto = LinearGradient.verticale(Colori.Widget.foglietto, Colori.Widget.fogliettoBasso)
    static let rilegatura = LinearGradient.verticale([
        (Colori.Widget.rilegaturaAlto, 0), (Colori.Widget.rilegaturaMezzo, 0.6), (Colori.Widget.rilegaturaBasso, 1),
    ])
    static let onda = LinearGradient(colors: Colori.Widget.onda, startPoint: .top, endPoint: .bottom)

    static let agendaInchiostro = LinearGradient.verticale(Colori.Agenda.inchiostroAlto, Colori.Agenda.inchiostroBasso)

    // Agenda
    static let cuoioAgenda = LinearGradient.verticale([
        (Colori.Agenda.cuoioAlto, 0), (Colori.Agenda.cuoioMezzo, 0.48), (Colori.Agenda.cuoioBasso, 1),
    ])
    static let targhettaRossa = LinearGradient.verticale(Colori.Agenda.targhettaRossoAlto, Colori.Agenda.targhettaRossoBasso)
    /// Ex carta dell'Agenda: la scheda del tema.
    static let cartaAgenda = LinearGradient(stops: [
        .init(color: Colori.Agenda.cartaBordo, location: 0), .init(color: Colori.Agenda.carta, location: 0.03),
        .init(color: Colori.Agenda.carta, location: 0.98), .init(color: Colori.Agenda.cartaBordo, location: 1),
    ], startPoint: .leading, endPoint: .trailing)
    static let anelloAgenda = LinearGradient(stops: zip(Colori.Agenda.anello, [0, 0.13, 0.28, 0.35, 0.55, 0.70, 0.88, 1])
        .map { Gradient.Stop(color: $0.0, location: $0.1) }, startPoint: .leading, endPoint: .trailing)
    static let settimanaAgenda = LinearGradient.verticale(Colori.Agenda.settimanaAlto, Colori.Agenda.settimanaBasso)
    static let giornoSelezionato = LinearGradient.verticale(Colori.Agenda.selezioneAlto, Colori.Agenda.selezioneBasso)
    static let dettaglioAgenda = LinearGradient(stops: [
        .init(color: Colori.Agenda.dettaglioAlto, location: 0), .init(color: Colori.Agenda.dettaglioFondo, location: 0.05),
    ], startPoint: .leading, endPoint: .trailing)

    // Incontri
    static let fondoIncontri = LinearGradient.verticale(Colori.Incontri.fondoAlto, Colori.Incontri.fondoBasso)
    static let cartaIncontri = LinearGradient(stops: [
        .init(color: Colori.Incontri.cartaLato, location: 0), .init(color: Colori.Incontri.carta, location: 0.02),
    ], startPoint: .leading, endPoint: .trailing)

    // Eve
    static let linoEve = LinearGradient.verticale(Colori.Eve.linoAlto, Colori.Eve.linoBasso)
    static let testataEve = LinearGradient.verticale(Colori.Eve.testataAlto, Colori.Eve.testataBasso)
    static let avvisoEve = LinearGradient.verticale(Colori.Eve.avvisoAlto, Colori.Eve.avvisoBasso)
    static let conversazioneEve = LinearGradient.verticale(Colori.Eve.conversazioneAlto, Colori.Eve.conversazioneBasso)
    static let barraEve = LinearGradient.verticale(Colori.Eve.barraAlto, Colori.Eve.barraBasso)
    static let displayEve = LinearGradient.verticale(Colori.Eve.displayAlto, Colori.Eve.displayBasso)
    static let microfonoAcceso = LinearGradient.lucido(Colori.Eve.microfonoAcceso, salto: (0.49, 0.50))
    static let nuvolaEve = LinearGradient.verticale(Colori.Eve.nuvolaEveAlto, Colori.Eve.nuvolaEveBasso)
    static let nuvolaTua = LinearGradient.lucido(Colori.Eve.nuvolaTuoi, salto: (0.48, 0.49))
    static let azioneEve = LinearGradient.verticale(Colori.Eve.azioneAlto, Colori.Eve.azioneBasso)
    static let postit = LinearGradient.verticale(Colori.Eve.postitAlto, Colori.Eve.postitBasso)
    static let quadroEve = LinearGradient.verticale(Colori.Eve.quadroAlto, Colori.Eve.quadroBasso)

    // Strumenti di analisi
    static let console = LinearGradient.verticale(Colori.Strumenti.consoleAlto, Colori.Strumenti.consoleBasso)
    static let lcd = LinearGradient.verticale(Colori.Strumenti.lcdAlto, Colori.Strumenti.lcdBasso)
    static let schedaArea = LinearGradient(stops: [
        .init(color: Colori.Strumenti.schedaBordoLato, location: 0), .init(color: Colori.Strumenti.schedaFondo, location: 0.02),
        .init(color: Colori.Strumenti.schedaFondo, location: 0.98), .init(color: Colori.Strumenti.schedaBordoLato, location: 1),
    ], startPoint: .leading, endPoint: .trailing)
    static let testaIpotesi = LinearGradient.verticale(Colori.Strumenti.ipotesiTestaAlto, Colori.Strumenti.ipotesiTestaBasso)
    static let schedeRisultati = LinearGradient.verticale(Colori.Strumenti.schedeAlto, Colori.Strumenti.schedeBasso)
    static let schedaRisultatiAttiva = LinearGradient.verticale(Colori.Strumenti.schedaAttivaAlto, Colori.Strumenti.schedaAttivaBasso)

    // Attività
    static let linoAttivita = LinearGradient.verticale(Colori.Attivita.linoAlto, Colori.Attivita.linoBasso)
    static let testataAttivita = LinearGradient.verticale(Colori.Attivita.testataAlto, Colori.Attivita.testataBasso)
    static let progressoAttivita = LinearGradient.verticale(Colori.Attivita.progressoAlto, Colori.Attivita.progressoBasso)
    static let metalloAttivita = LinearGradient.verticale(Colori.Attivita.metalloAlto, Colori.Attivita.metalloBasso)
    static let spunta = LinearGradient.verticale(Colori.Attivita.spuntaAlto, Colori.Attivita.spuntaAlto)
    static let spuntaFatta = LinearGradient.verticale(Colori.Attivita.spuntaFattaAlto, Colori.Attivita.spuntaFattaBasso)
    static let dettaglioAttivita = LinearGradient(stops: [
        .init(color: Colori.Attivita.dettaglioAlto, location: 0), .init(color: Colori.Attivita.dettaglioFondo, location: 0.05),
    ], startPoint: .leading, endPoint: .trailing)
}
