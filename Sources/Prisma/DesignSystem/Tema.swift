import AppKit
import SwiftUI

// MARK: - Colori che seguono l'aspetto

extension NSAppearance {
    /// true con l'aspetto scuro (anche nelle varianti ad alto contrasto).
    var prismaScuro: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

extension Color {
    /// Colore che cambia con l'aspetto della vista in cui si disegna (chiaro o scuro).
    /// Solo per le schermate: i PDF restano su carta bianca con colori fissi.
    static func dinamico(chiaro: Color, scuro: Color) -> Color {
        let c = NSColor(chiaro)
        let s = NSColor(scuro)
        return Color(nsColor: NSColor(name: nil) { aspetto in aspetto.prismaScuro ? s : c })
    }
}

extension AspettoInterfaccia {
    /// L'aspetto da dare all'app (nil = segue il Mac).
    @MainActor var aspettoMac: NSAppearance? {
        switch self {
        case .automatico: return nil
        case .chiaro: return NSAppearance(named: .aqua)
        case .scuro: return NSAppearance(named: .darkAqua)
        }
    }

    /// Lo schema SwiftUI corrispondente (nil = segue il Mac).
    var schema: ColorScheme? {
        switch self {
        case .automatico: return nil
        case .chiaro: return .light
        case .scuro: return .dark
        }
    }
}

// MARK: - Gettoni del tema Liquid Glass (tema.html)

/// Gettoni di base del tema «Liquid Glass»: colori (chiaro/scuro), raggi, misure, caratteri, ombre e movimenti.
/// I valori vengono da tema.html; le schermate usano solo questi nomi.
enum Tema {

    // MARK: Colori

    enum Colore {
        private static func d(_ chiaro: Color, _ scuro: Color) -> Color { .dinamico(chiaro: chiaro, scuro: scuro) }
        private static func bianco(_ a: Double) -> Color { Color(r: 255, g: 255, b: 255, a: a) }
        private static func nero(_ a: Double) -> Color { Color(r: 0, g: 0, b: 0, a: a) }

        // Stati: uguali in chiaro e scuro
        static let rosso = Color(hex: "#FF3B30")
        static let arancio = Color(hex: "#FF9500")
        static let verde = Color(hex: "#34C759")

        // Accento e collegamenti
        static let accento = d(Color(hex: "#007AFF"), Color(hex: "#0A84FF"))
        /// Pulsante primario al passaggio (accento 88% + bianco).
        static let accentoSopra = d(Color(hex: "#1F8AFF"), Color(hex: "#2793FF"))
        static let link = d(Color(hex: "#0064D6"), Color(hex: "#8CC4FF"))
        /// Selezione di voci laterali e popover (accento 17%).
        static let selezione: Color = accento.opacity(0.17)
        /// Riga di tabella selezionata (accento 15%).
        static let selezioneRiga: Color = accento.opacity(0.15)
        /// Risultato scelto nella ricerca (accento 18%).
        static let selezioneRicerca: Color = accento.opacity(0.18)

        // Canali
        static let canaleAlleanza = d(Color(hex: "#2563EB"), Color(hex: "#5B8CFF"))
        static let canaleIndipendente = d(Color(hex: "#B06E12"), Color(hex: "#BF8430"))
        /// Fondo della capsula Alleanza (canale 17% sul chip).
        static let fondoCanaleAlleanza = d(Color(r: 188, g: 207, b: 249, a: 0.552), Color(r: 145, g: 178, b: 255, a: 0.253))
        /// Fondo della capsula indipendente (canale 19% sul chip).
        static let fondoCanaleIndipendente = d(Color(r: 228, g: 206, b: 175, a: 0.563), Color(r: 210, g: 169, b: 110, a: 0.271))
        /// Colori fissi dei canali per i PDF (carta bianca, sempre chiari).
        static let canaleAlleanzaStampa = Color(hex: "#2563EB")
        static let canaleIndipendenteStampa = Color(hex: "#B06E12")

        static func canale(_ canale: Canale) -> Color {
            canale == .alleanza ? canaleAlleanza : canaleIndipendente
        }

        static func fondoCanale(_ canale: Canale) -> Color {
            canale == .alleanza ? fondoCanaleAlleanza : fondoCanaleIndipendente
        }

        // Testo direttamente sullo sfondo (saluto, barra, piede)
        static let inchiostroSfondo = d(Color(r: 8, g: 26, b: 38, a: 0.88), .white)
        static let inchiostroSfondoSecondario = d(Color(r: 8, g: 26, b: 38, a: 0.6), bianco(0.68))
        /// Alone del testo sullo sfondo (vedi `.aloneSfondo()`).
        static let aloneSfondo = d(bianco(0.5), nero(0.35))
        /// Velo che scende sotto la barra superiore (dall'alto al trasparente).
        static let veloBarra = d(bianco(0.3), nero(0.3))

        // Inchiostri
        static let inchiostro = d(nero(0.86), bianco(0.94))
        static let inchiostroSecondario = d(nero(0.56), bianco(0.64))
        static let inchiostroTerziario = d(nero(0.36), bianco(0.42))
        /// Separatori da 0,5 pt.
        static let separatore = d(nero(0.09), bianco(0.1))

        // Riempimenti del vetro (trasparente)
        static let riempimentoVetro = d(bianco(0.32), Color(r: 12, g: 26, b: 36, a: 0.42))
        static let riempimentoLeggero = d(bianco(0.22), Color(r: 16, g: 32, b: 44, a: 0.3))
        static let riempimentoPannello = d(bianco(0.64), Color(r: 14, g: 28, b: 38, a: 0.7))
        // Vetro «Colorato» del tema: più coprente (istantanee e ripiego senza materiali)
        static let riempimentoVetroColorato = d(bianco(0.7), Color(r: 14, g: 26, b: 34, a: 0.76))
        static let riempimentoLeggeroColorato = d(bianco(0.58), Color(r: 16, g: 30, b: 40, a: 0.64))
        static let riempimentoPannelloColorato = d(bianco(0.84), Color(r: 14, g: 28, b: 36, a: 0.88))
        static let finestraColorata = d(Color(r: 247, g: 247, b: 251, a: 0.94), Color(r: 18, g: 28, b: 36, a: 0.95))
        static let lateraleColorata = d(bianco(0.66), bianco(0.06))
        static let chipColorato = d(bianco(0.62), bianco(0.08))
        // «Riduci trasparenza» del Mac: vetro quasi opaco
        static let riempimentoVetroRidotto = d(Color(r: 246, g: 246, b: 250, a: 0.95), Color(r: 28, g: 29, b: 40, a: 0.96))
        static let riempimentoLeggeroRidotto = d(Color(r: 246, g: 246, b: 250, a: 0.92), Color(r: 28, g: 29, b: 40, a: 0.94))
        static let riempimentoPannelloRidotto = d(Color(r: 246, g: 246, b: 250, a: 0.97), Color(r: 28, g: 29, b: 40, a: 0.98))
        static let finestraRidotta = d(Color(r: 246, g: 246, b: 250, a: 0.99), Color(r: 28, g: 29, b: 40, a: 0.99))
        /// Velo sotto il contenuto del vetro nativo di macOS 26 (finestre e pannelli restano leggibili).
        static let veloNativoFinestra = d(Color(r: 247, g: 247, b: 251, a: 0.55), Color(r: 18, g: 29, b: 38, a: 0.6))
        static let veloNativoPannello = d(bianco(0.3), Color(r: 14, g: 28, b: 38, a: 0.35))

        // Bordi e riflessi del vetro
        /// Filo di luce interno in alto (inset 0 1px).
        static let riflessoAlto = d(bianco(0.95), bianco(0.42))
        /// Filo interno in basso (inset 0 -1px).
        static let riflessoBasso = d(bianco(0.4), bianco(0.1))
        /// Contorno interno da 0,5 pt.
        static let bordoVetro = d(bianco(0.55), bianco(0.18))
        /// Bagliore interno (inset 0 0 24px).
        static let bagliore = d(bianco(0.22), bianco(0.05))
        /// Riflesso radiale in alto a sinistra.
        static let lucentezza = d(bianco(0.5), bianco(0.13))
        /// Anello luminoso: angolo in alto a sinistra, tratti intermedi, angolo in basso a destra.
        static let luceBordoA = d(.white, bianco(0.72))
        static let luceBordoMezzo1 = bianco(0.2)
        static let luceBordoMezzo2 = bianco(0.16)
        static let luceBordoB = d(bianco(0.6), bianco(0.3))
        /// Luce che rientra dal bordo inferiore.
        static let luceRientro = d(bianco(0.6), Color(r: 150, g: 205, b: 230, a: 0.32))
        /// Contorno esterno delle finestre (attiva / inattiva).
        static let contornoFinestra = nero(0.2)
        static let contornoFinestraInattiva = nero(0.16)
        /// Contorno del pallino del canale.
        static let bordoPallino = bianco(0.4)

        // Chip, pozzetti, schede
        static let chip = d(bianco(0.46), bianco(0.1))
        static let chipSopra = d(bianco(0.74), bianco(0.18))
        static let bordoChip = d(bianco(0.75), bianco(0.14))
        /// Pozzetto: campi, segmented, tasti.
        static let pozzetto = d(nero(0.055), bianco(0.07))
        /// Pozzetto scuro: interruttore spento, barre di scorrimento, cerchio della spunta, semafori inattivi.
        static let pozzettoScuro = d(nero(0.13), bianco(0.18))
        static let scheda = d(bianco(0.74), bianco(0.06))
        static let bordoScheda = d(nero(0.06), bianco(0.08))
        /// Riga di tabella al passaggio.
        static let rigaSopra = d(nero(0.035), bianco(0.05))

        // Finestre
        static let finestra = d(Color(r: 247, g: 247, b: 251, a: 0.84), Color(r: 18, g: 29, b: 38, a: 0.88))
        /// Barra del titolo e composer.
        static let finestraPiena = d(Color(r: 247, g: 247, b: 251, a: 0.96), Color(r: 18, g: 29, b: 38, a: 0.97))
        /// Barra laterale staccata dentro la finestra.
        static let laterale = d(bianco(0.55), bianco(0.07))
        static let semaforoChiudi = Color(hex: "#FF5F57")
        static let semaforoRiduci = Color(hex: "#FEBC2E")
        static let semaforoIngrandisci = Color(hex: "#28C840")
        static let bordoSemaforo = nero(0.2)
        static let simboloSemaforo = nero(0.6)

        // Controlli e pannelli
        /// Cursore dei segmented e manopola del benvenuto.
        static let cursore = d(bianco(0.97), bianco(0.26))
        /// Pomello dell'interruttore.
        static let pomello = Color.white
        /// Tessera della data (mese e giorno).
        static let tesseraData = d(bianco(0.82), bianco(0.12))
        /// Velo dietro ricerca e app aperte.
        static let velo = d(Color(r: 8, g: 30, b: 45, a: 0.12), Color(r: 0, g: 10, b: 18, a: 0.34))
        /// Suggerimento sui grafici.
        static let suggerimento = d(bianco(0.78), Color(r: 22, g: 38, b: 50, a: 0.76))
        /// Testo della schermata di benvenuto.
        static let inchiostroBenvenuto = d(Color(r: 10, g: 34, b: 52, a: 0.88), .white)
        /// Ombra del testo nei widget: solo in scuro.
        static let ombraTestoWidget = d(.clear, nero(0.28))

        // Pillole di stato e scadenze
        static let testoInEssere = d(Color(r: 34, g: 130, b: 58, a: 0.947), Color(r: 126, g: 219, b: 150, a: 0.977))
        static let fondoInEssere: Color = verde.opacity(0.18)
        static let testoProposta = d(Color(r: 162, g: 95, b: 0, a: 0.944), Color(r: 255, g: 190, b: 98, a: 0.976))
        static let fondoProposta: Color = arancio.opacity(0.2)
        /// Scade tra 31 e 90 giorni.
        static let scadenzaVicina = d(Color(r: 191, g: 112, b: 0, a: 0.961), Color(r: 255, g: 177, b: 68, a: 0.983))
        /// Scade entro 30 giorni o è scaduta.
        static let scadenzaOra = d(Color(r: 210, g: 49, b: 40, a: 0.972), Color(r: 255, g: 96, b: 87, a: 0.988))

        // Logo e sfondo d'acqua (prototipo approvato)
        /// Colore del logo: #0F2433 sugli sfondi chiari, bianco sugli scuri.
        static let logo = d(Color(hex: "#0F2433"), .white)
        /// Logo nei PDF: sempre scuro su carta bianca.
        static let logoStampa = Color(hex: "#0F2433")
        static let cielo1 = d(Color(hex: "#F3F5F6"), Color(hex: "#123648"))
        static let cielo2 = d(Color(hex: "#DDE4E8"), Color(hex: "#0E2533"))
        static let cielo3 = d(Color(hex: "#B7C5CD"), Color(hex: "#081A25"))
        /// Gli stessi colori, fissi, per chi deve passarli a uno shader.
        static let cieloChiaro = [Color(hex: "#F3F5F6"), Color(hex: "#DDE4E8"), Color(hex: "#B7C5CD")]
        static let cieloScuro = [Color(hex: "#123648"), Color(hex: "#0E2533"), Color(hex: "#081A25")]
    }

    // MARK: Raggi

    enum Raggio {
        static let widget: CGFloat = 26
        static let widgetEve: CGFloat = 22
        static let finestra: CGFloat = 24
        static let finestraIngrandita: CGFloat = 18
        /// Barra laterale e schede dentro le finestre.
        static let pannello: CGFloat = 18
        static let laterale: CGFloat = 18
        static let scheda: CGFloat = 18
        static let dock: CGFloat = 26
        static let ricerca: CGFloat = 26
        static let notifiche: CGFloat = 26
        static let schedaNotifica: CGFloat = 18
        static let centroControllo: CGFloat = 28
        static let tesseraControllo: CGFloat = 20
        static let popover: CGFloat = 22
        static let appAperte: CGFloat = 28
        static let schedaApp: CGFloat = 20
        static let tessera: CGFloat = 16
        static let kpi: CGFloat = 16
        static let gruppo: CGFloat = 16
        static let riga: CGFloat = 14
        static let vocePopover: CGFloat = 14
        static let voceRicerca: CGFloat = 12
        static let voceLaterale: CGFloat = 11
        static let tesseraData: CGFloat = 11
        static let miniatura: CGFloat = 10
        static let suggerimento: CGFloat = 10
        static let documento: CGFloat = 7
        static let tasto: CGFloat = 6
        static let bolla: CGFloat = 20
        static let bollaAngolo: CGFloat = 6
        static let barraCanali: CGFloat = 4
        static let quadratinoCanale: CGFloat = 3
        /// Raggio delle icone delle app (23,5% del lato).
        static func iconaApp(_ lato: CGFloat) -> CGFloat { lato * 0.235 }
    }

    // MARK: Misure

    enum Misura {
        /// Fili e contorni da 0,5 pt.
        static let filo: CGFloat = 0.5

        // Barra superiore
        static let barra: CGFloat = 34
        static let barraStrumenti: CGFloat = 30
        static let pulsanteBarra: CGFloat = 26
        static let marchioBarra: CGFloat = 26
        static let logoBarra: CGFloat = 19
        static let iconaBarra: CGFloat = 16
        static let avatarBarra: CGFloat = 24
        static let badge: CGFloat = 15
        /// Il velo sotto la barra scende di 12 pt.
        static let veloBarra: CGFloat = 12

        // Scrivania
        static let margineScrivaniaMinimo: CGFloat = 16
        static let margineScrivaniaMassimo: CGFloat = 44
        /// Margine laterale = 3% della larghezza, tra minimo e massimo.
        static let margineScrivaniaQuota: CGFloat = 0.03
        static let scrivaniaMassima: CGFloat = 1480
        static let widgetMargine: CGFloat = 14
        static let grigliaSpazio: CGFloat = 12
        static let testaWidget: CGFloat = 26
        static let widgetEve: CGFloat = 64

        // Dock
        static let dockIcona: CGFloat = 50
        static let dockRiservato: CGFloat = 96
        static let dockRiservatoConNomi: CGFloat = 112
        static let dockDalBasso: CGFloat = 10
        /// Margine interno e spazio tra le icone, in frazione del lato dell'icona.
        static let dockMargineQuota: CGFloat = 0.14
        static let dockSpazioQuota: CGFloat = 0.12
        static let dockIngrandimento: CGFloat = 1.55
        /// Raggio d'azione dell'ingrandimento, in lati d'icona.
        static let dockPortata: CGFloat = 2.7
        static let puntinoDock: CGFloat = 4

        // Controlli
        static let pulsante: CGFloat = 32
        static let pulsantePiccolo: CGFloat = 28
        static let pulsanteVetro: CGFloat = 34
        static let pulsanteVetroPiccolo: CGFloat = 30
        static let chip: CGFloat = 22
        static let chipPiccolo: CGFloat = 20
        static let pallinoCanale: CGFloat = 7
        static let simboloAlleanza: CGFloat = 12
        static let spazioChip: CGFloat = 6
        /// Margini laterali del chip (sinistro, destro) e del chip piccolo.
        static let chipMargini: (sinistro: CGFloat, destro: CGFloat) = (8, 9)
        static let chipPiccoloMargini: (sinistro: CGFloat, destro: CGFloat) = (7, 8)
        static let pill: CGFloat = 20
        static let campo: CGFloat = 32
        static let campoGrande: CGFloat = 44
        static let interruttore = CGSize(width: 44, height: 26)
        static let pomello: CGFloat = 22
        static let spunta: CGFloat = 22

        // Finestre
        static let laterale: CGFloat = 232
        static let lateraleCima: CGFloat = 40
        static let semaforo: CGFloat = 13
        static let spazioSemafori: CGFloat = 8
        static let origineSemafori = CGPoint(x: 21, y: 19)
        static let barraTitolo: CGFloat = 52
        static let finestraMinima = CGSize(width: 380, height: 260)
        static let iconaFinestra: CGFloat = 20
        static let iconaLaterale: CGFloat = 24

        // Pannelli
        static let ricercaLarghezza: CGFloat = 660
        static let notificheLarghezza: CGFloat = 356
        static let centroControlloLarghezza: CGFloat = 340
        static let popoverLarghezza: CGFloat = 300
        static let iconaNotifica: CGFloat = 30
        static let iconaAppAperte: CGFloat = 52
        static let iconaBenvenuto: CGFloat = 64
    }

    // MARK: Caratteri (SF)

    enum Testo {
        /// SF alla dimensione del tema, moltiplicata per Impostazioni → Dimensione del testo.
        static func sf(_ dimensione: CGFloat, _ peso: Font.Weight = .regular, arrotondato: Bool = false) -> Font {
            let disegno: Font.Design = arrotondato ? .rounded : .default
            return Font.system(size: dimensione * Tipo.fattore, weight: peso, design: disegno)
        }

        /// letter-spacing in em → tracking in punti.
        static func spaziatura(_ em: CGFloat, _ dimensione: CGFloat) -> CGFloat { em * dimensione * Tipo.fattore }

        static let corpo = sf(13)
        static let titolo = sf(13, .semibold)
        static let secondario = sf(12)
        static let secondarioGrande = sf(12.5)
        static let occhiello = sf(11.5, .semibold)
        static let didascalia = sf(11.5)
        static let saluto = sf(34, .bold)
        static let spaziaturaSaluto = spaziatura(-0.024, 34)
        static let sottotitoloSaluto = sf(15)
        static let sezione = sf(19, .bold)
        static let spaziaturaSezione = spaziatura(-0.012, 19)
        static let titoloApp = sf(26, .bold)
        static let spaziaturaTitoloApp = spaziatura(-0.02, 26)
        static let titoloImpostazioni = sf(22, .bold)
        static let titoloNota = sf(24, .bold)
        static let spaziaturaTitoloMedio = spaziatura(-0.015, 22)
        static let totale = sf(30, .bold)
        static let spaziaturaTotale = spaziatura(-0.025, 30)
        static let giornoAgenda = sf(70, .light)
        static let spaziaturaGiornoAgenda = spaziatura(-0.045, 70)
        static let nomeCliente = sf(18, .bold)
        static let valoreKpi = sf(16, .semibold)
        static let valoreTessera = sf(18, .semibold)
        static let pulsante = sf(13, .medium)
        static let pulsantePiccolo = sf(12.5, .medium)
        static let chip = sf(11.5, .semibold)
        static let chipPiccolo = sf(11, .semibold)
        static let pill = sf(11, .semibold)
        static let badge = sf(9.5, .bold)
        static let marchio = sf(13, .bold)
        static let barra = sf(13, .medium)
        static let tasto = sf(11, .medium)
        static let ricerca = sf(21)
        static let meseTessera = sf(9.5, .bold)
        static let giornoTessera = sf(17, .semibold, arrotondato: true)
        static let importo = sf(13, .semibold).monospacedDigit()
        /// Iniziali degli avatar: 37% del lato, arrotondate.
        static func avatar(_ lato: CGFloat) -> Font {
            let disegno: Font.Design = .rounded
            return Font.system(size: lato * 0.37, weight: .semibold, design: disegno)
        }
    }

    // MARK: Ombre

    enum Ombra {
        /// Ombra del vetro (widget, dock, pannelli): due strati, diversi in chiaro e scuro.
        static func vetro(scuro: Bool) -> [StratoOmbra] {
            scuro
                ? [StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.7), y: 26, sfocatura: 52, espansione: -24),
                   StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.35), y: 4, sfocatura: 14, espansione: -4)]
                : [StratoOmbra(colore: Color(r: 8, g: 40, b: 60, a: 0.36), y: 22, sfocatura: 44, espansione: -24),
                   StratoOmbra(colore: Color(r: 8, g: 40, b: 60, a: 0.14), y: 3, sfocatura: 10, espansione: -4)]
        }

        /// Ombra delle finestre interne (il contorno da 0,5 pt lo disegna il vetro).
        static func finestra(attiva: Bool) -> [StratoOmbra] {
            attiva
                ? [StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.5), y: 34, sfocatura: 80, espansione: -24),
                   StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.25), y: 10, sfocatura: 30, espansione: -12)]
                : [StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.42), y: 22, sfocatura: 50, espansione: -24)]
        }

        static let laterale = [StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.35), y: 8, sfocatura: 24, espansione: -14)]
        static let pulsante = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.08), y: 1, sfocatura: 2)
        static let pulsantePrimario = StratoOmbra(colore: Colore.accento.opacity(0.7), y: 3, sfocatura: 10, espansione: -3)
        static let cursore = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.18), y: 1, sfocatura: 4)
        static let pomello = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.22), y: 2, sfocatura: 5)
        static let tesseraData = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.08), y: 1, sfocatura: 3)
        static let suggerimento = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.35), y: 6, sfocatura: 20, espansione: -8)
        static let composer = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.35), y: 10, sfocatura: 30, espansione: -12)
        static let avatar = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.35), y: 2, sfocatura: 6, espansione: -2)
        static let manopola = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.3), y: 4, sfocatura: 14, espansione: -2)
    }

    // MARK: Movimenti

    enum Moto {
        /// Rimbalzo del tema (--spring): pressioni, interruttori, segmented.
        static let molla = Animation.spring(response: 0.35, dampingFraction: 0.62)
        /// Uscita morbida (--out) di durata data.
        static func uscita(_ durata: Double) -> Animation { .timingCurve(0.22, 1, 0.36, 1, duration: durata) }
        static let passaggio = Animation.easeOut(duration: 0.15)
        static let aperturaFinestra = uscita(0.34)
        static let chiusuraFinestra = Animation.easeIn(duration: 0.17)
        static let pannello = uscita(0.24)
        static let segmented = Animation.spring(response: 0.38, dampingFraction: 0.62)
        /// Scala alla pressione di pulsanti e icone (la spunta 0,88).
        static let scalaPressione: CGFloat = 0.96
        static let scalaPressioneSpunta: CGFloat = 0.88
    }

    // MARK: Icone delle app

    enum Icona {
        /// Fondo a 165° delle icone a colori: da `alto` a `basso`.
        static let angoloGradiente: Double = 165
        /// Fondo delle icone «scure».
        static let scuraAlto = Color(hex: "#3B3C43")
        static let scuraBasso = Color(hex: "#141418")
        /// Fondo delle icone «trasparenti».
        static let trasparenteAlto = Color.dinamico(chiaro: Color(r: 255, g: 255, b: 255, a: 0.5), scuro: Color(r: 255, g: 255, b: 255, a: 0.26))
        static let trasparenteBasso = Color.dinamico(chiaro: Color(r: 255, g: 255, b: 255, a: 0.14), scuro: Color(r: 255, g: 255, b: 255, a: 0.06))
        static let inchiostroTrasparente = Color.dinamico(chiaro: Color(r: 20, g: 22, b: 48, a: 0.8), scuro: Color(r: 255, g: 255, b: 255, a: 0.95))
        static let lineaTrasparente = Color.dinamico(chiaro: Color(r: 255, g: 255, b: 255, a: 0.7), scuro: Color(r: 0, g: 0, b: 0, a: 0.3))
        /// Accento dei glifi quando l'app non ne ha uno suo.
        static let accentoPredefinito = Color(hex: "#FF3B30")

        /// Icona della Scrivania (home).
        static let scrivania = ColoriIconaApp(alto: Color(hex: "#2F4C63"), basso: Color(hex: "#0E1D29"), tinta: Color(hex: "#9CCBE6"))

        static func colori(_ app: AppPrisma) -> ColoriIconaApp {
            switch app {
            case .clienti: return ColoriIconaApp(alto: Color(hex: "#C9A584"), basso: Color(hex: "#8C6849"), tinta: Color(hex: "#D9B48E"))
            case .posizioni: return ColoriIconaApp(alto: Color(hex: "#5F8FC9"), basso: Color(hex: "#2C5389"), tinta: Color(hex: "#7FA8DC"))
            case .analisi360: return ColoriIconaApp(alto: Color(hex: "#4E6479"), basso: Color(hex: "#22323F"), tinta: Color(hex: "#93AFC6"))
            case .incontri: return ColoriIconaApp(alto: Color(hex: "#6FAE98"), basso: Color(hex: "#3A7563"), tinta: Color(hex: "#8CC6B0"))
            case .obiettivi: return ColoriIconaApp(alto: Color(hex: "#9C8269"), basso: Color(hex: "#5E4A39"), tinta: Color(hex: "#C4A688"), accento: Color(hex: "#C8473F"))
            case .confronti: return ColoriIconaApp(alto: Color(hex: "#8A86AE"), basso: Color(hex: "#4F4B73"), tinta: Color(hex: "#ABA7CF"))
            case .prodotti: return ColoriIconaApp(alto: Color(hex: "#D8C6A6"), basso: Color(hex: "#A38A62"), tinta: Color(hex: "#DCC59C"), accento: Color(hex: "#A64B46"))
            case .simulazioni: return ColoriIconaApp(alto: Color(hex: "#8D96A0"), basso: Color(hex: "#4A525C"), tinta: Color(hex: "#B9C2CC"), accento: Color(hex: "#C98A3A"))
            case .agenda: return ColoriIconaApp(alto: Color(hex: "#FFFFFF"), basso: Color(hex: "#E7EAF0"), tinta: Color(hex: "#FF453A"), accento: Color(hex: "#E0443A"))
            case .attivita: return ColoriIconaApp(alto: Color(hex: "#FFFFFF"), basso: Color(hex: "#E4E8EE"), tinta: Color(hex: "#34C759"), accento: Color(hex: "#3E9A68"))
            case .note: return ColoriIconaApp(alto: Color(hex: "#E8D69A"), basso: Color(hex: "#C2A456"), tinta: Color(hex: "#E3CB7E"), accento: Color(hex: "#B98A2E"))
            case .documenti: return ColoriIconaApp(alto: Color(hex: "#73A9CF"), basso: Color(hex: "#376E99"), tinta: Color(hex: "#8DC0E2"))
            case .presentazioni: return ColoriIconaApp(alto: Color(hex: "#C99282"), basso: Color(hex: "#91584A"), tinta: Color(hex: "#D9A595"), accento: Color(hex: "#A65A4A"))
            case .eve: return ColoriIconaApp(alto: Color(hex: "#B9A3F2"), basso: Color(hex: "#6862C9"), tinta: Color(hex: "#C7B5FF"))
            case .ricerca: return ColoriIconaApp(alto: Color(hex: "#6E879E"), basso: Color(hex: "#354B5F"), tinta: Color(hex: "#9DB5CB"))
            case .impostazioni: return ColoriIconaApp(alto: Color(hex: "#A3ABB4"), basso: Color(hex: "#5D6570"), tinta: Color(hex: "#C6CDD5"))
            }
        }
    }
}

/// Uno strato di `box-shadow` del tema: colore, spostamento verticale, sfocatura CSS (px)
/// ed espansione (spread: negativa = l'ombra rientra sotto la superficie).
struct StratoOmbra {
    var colore: Color
    var y: CGFloat
    var sfocatura: CGFloat
    var espansione: CGFloat = 0
}

/// Colori di un'icona d'app del tema: fondo a 165° da `alto` a `basso`, `tinta` dei glifi nello stile scuro,
/// `accento` dei dettagli colorati del glifo.
struct ColoriIconaApp {
    let alto: Color
    let basso: Color
    let tinta: Color
    var accento: Color = Tema.Icona.accentoPredefinito
}

extension View {
    /// Ombra semplice da un gettone del tema (senza espansione: per il vetro la disegna `.vetro`).
    func ombraTema(_ strato: StratoOmbra) -> some View {
        shadow(color: strato.colore, radius: strato.sfocatura / 2, x: 0, y: strato.y)
    }
}
