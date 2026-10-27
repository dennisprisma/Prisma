import SwiftUI

extension Color {
    /// Colore da esadecimale come nel template CSS: "#rgb", "#rgba", "#rrggbb" o "#rrggbbaa".
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 || s.count == 4 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((v >> 24) & 0xff) / 255
            g = Double((v >> 16) & 0xff) / 255
            b = Double((v >> 8) & 0xff) / 255
            a = Double(v & 0xff) / 255
        } else {
            r = Double((v >> 16) & 0xff) / 255
            g = Double((v >> 8) & 0xff) / 255
            b = Double(v & 0xff) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Colore da componenti 0–255 come `rgba()` nel CSS.
    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.init(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
}

// Abbreviazioni di questo file: i gettoni di base del tema e i colori che cambiano con l'aspetto.
private typealias TC = Tema.Colore
private func adatto(_ chiaro: Color, _ scuro: Color) -> Color { Color.dinamico(chiaro: chiaro, scuro: scuro) }
private func neroAlfa(_ a: Double) -> Color { Color(r: 0, g: 0, b: 0, a: a) }
private func biancoAlfa(_ a: Double) -> Color { Color(r: 255, g: 255, b: 255, a: a) }

/// Palette delle schermate nel tema «Liquid Glass» (tema.html): gli stessi nomi del tema iOS 5,
/// con valori ricavati dai gettoni di base (`Tema.Colore`), chiari o scuri secondo l'aspetto.
/// Le superfici diventano vetro, schede e pozzetti; i testi inchiostri; rilievi e incisioni spariscono.
/// I documenti (PDF) hanno i loro colori fissi in `Colori.Carta` e `Colori.Documento`.
enum Colori {
    static let bianco = Color.white
    static let nero = Color.black

    /// Sfondo della scrivania: ora è l'acqua (SfondoAcqua); qui resta il colore di riserva.
    enum Sfondo {
        static let base = TC.cielo2
        static let veloInizio = Color.clear
        static let veloFine = Color.clear
        static let vignettatura = Color.clear
    }

    /// Barra superiore: niente fondo, solo il velo che scende e il testo sullo sfondo.
    enum Barra {
        static let sfondoAlto = TC.veloBarra
        static let sfondoBasso = Color.clear
        static let bordo = Color.clear
        static let ombra = Color.clear
        static let testo = TC.inchiostroSfondo
        static let testoSecondario = TC.inchiostroSfondoSecondario
        static let incisione = Color.clear
        static let logo = TC.logo
        static let logoOmbra = Color.clear
        static let os = TC.inchiostroSfondoSecondario
        static let appCorrente = TC.inchiostroSfondo
        static let separatore = TC.separatore
        static let tasto = TC.inchiostroSecondario
        static let avatarBordo = biancoAlfa(0.5)
        /// La capsula «Modalità cliente»: l'accento del tema
        static let modoCliente = TC.accento
        static let modoClienteBordo = TC.accento
    }

    /// Testi direttamente sullo sfondo d'acqua (saluto, sezioni, piede) con l'alone del tema.
    enum Scrivania {
        static let kicker = TC.inchiostroSfondoSecondario
        static let titolo = TC.inchiostroSfondo
        static let sottotitolo = TC.inchiostroSfondoSecondario
        static let ombraTesto = TC.aloneSfondo
        static let intestazione = TC.inchiostroSfondo
        static let intestazioneOmbra = TC.aloneSfondo
        static let piede = TC.inchiostroSfondoSecondario
        static let piedeOmbra = TC.aloneSfondo
        static let iconaOmbra1 = neroAlfa(0.25)
        static let iconaOmbra2 = neroAlfa(0.14)
        static let etichettaOmbra = TC.aloneSfondo
        static let sottotitoloOmbra = TC.aloneSfondo
    }

    /// Widget del cliente e righe della scrivania: tutto sul vetro del widget.
    enum Colonna {
        static let sfondo = TC.chip
        static let bordo = TC.bordoChip
        static let ombra = Color.clear
        static let pelleBordo = TC.separatore
        static let pelleLuce = Color.clear
        static let pelleOmbra = Color.clear
        static let pelleEtichetta = TC.inchiostroSecondario
        static let pelleNome = TC.inchiostro
        static let pelleTema = TC.inchiostroSecondario
        static let schedeAlto = TC.pozzetto
        static let schedeBasso = TC.pozzetto
        static let schedeBordo = TC.separatore
        static let intestazione = TC.inchiostroSecondario
        static let collegamento = TC.link
        static let rigaBordo = TC.separatore
        static let rigaLuce = Color.clear
        static let rigaSecondario = TC.inchiostroSecondario
        static let rigaNome = TC.inchiostro
        static let freccia = TC.inchiostroTerziario
        // Tessera della data: mese rosso sulla tessera, niente fascia
        static let dataAlto = TC.tesseraData
        static let dataBasso = TC.tesseraData
        static let dataBordo = TC.bordoChip
        static let dataOmbra = neroAlfa(0.08)
        static let dataGiorno = TC.inchiostro
        static let dataMeseTesto = TC.rosso
        static let dataMeseAlto = Color.clear
        static let dataMeseBasso = Color.clear
        static let dataMeseBordo = Color.clear
        static let eveBordo = TC.bordoChip
        static let eveTitolo = TC.inchiostro
        static let eveTesto = TC.inchiostroSecondario
        static let eveFreccia = TC.inchiostroTerziario
        static let eveIncisione = Color.clear
        static let eveIconaOmbra = neroAlfa(0.2)
        // Ex pelle e cucitura: nel tema non si disegnano più
        static let pelleAlto = Color.clear
        static let pelleMezzo = Color.clear
        static let pelleBasso = Color.clear
        static let pelleRiflesso = Color.clear
        static let cucitura = Color.clear
        static let cucituraOmbra = Color.clear
        // Casella delle attività (la spunta del tema)
        static let casellaBordo = TC.pozzettoScuro
        static let casellaAlto = TC.chip
        static let casellaBasso = TC.chip
        static let casellaOmbra = Color.clear
        // Righe metriche del dossier
        static let metricaEtichetta = TC.inchiostroSecondario
        static let metricaValore = TC.inchiostro
    }

    /// App di analisi (Posizioni): laterale di vetro, schede, KPI, tabelle.
    enum Analisi {
        static let railAlto = TC.laterale
        static let railBasso = TC.laterale
        static let railTesto = TC.inchiostro
        static let railFilo = TC.separatore
        static let railRiflesso = Color.clear
        static let railEtichetta = TC.inchiostroTerziario
        static let segBordo = TC.separatore
        static let segTesto = TC.inchiostro
        // Il segmento scelto porta il testo bianco: pieno d'accento
        static let segAttivoAlto = TC.accento
        static let segAttivoBasso = TC.accento
        static let segAttivoIncisione = Color.clear
        static let segAttivoOmbra = neroAlfa(0.1)
        // Voce scelta del laterale: accento pieno con il testo bianco
        static let navAlto = TC.accento
        static let navBasso = TC.accento
        static let navBordoAlto = TC.accento
        static let navBordoBasso = TC.accento
        static let navLuce = Color.clear
        /// Anche il numero sulla capsula bianca della voce scelta.
        static let navIncisione = TC.accento
        static let navTesto = TC.inchiostro
        static let navIncisioneSpento = Color.clear
        static let navConteggio = TC.pozzetto
        static let navConteggioTesto = TC.inchiostroSecondario
        static let principale = TC.scheda
        static let testo = TC.inchiostro
        static let kpiAlto = TC.chip
        static let kpiBasso = TC.chip
        static let kpiBordo = TC.bordoScheda
        static let kpiTitolo = TC.inchiostroSecondario
        static let kpiValore = TC.inchiostro
        static let kpiNota = TC.inchiostroSecondario
        static let chip = TC.chip
        static let chipBordo = TC.bordoChip
        static let chipTesto = TC.inchiostroSecondario
        static let pannelloTitolo = TC.inchiostro
        static let pannelloNota = TC.inchiostroSecondario
        static let tabellaTestaAlto = TC.rigaSopra
        static let tabellaTestaBasso = TC.rigaSopra
        static let tabellaTestaBordo = TC.separatore
        static let tabellaTesta = TC.inchiostroSecondario
        static let tabellaRiga = TC.separatore
        static let tabellaAlternata = TC.rigaSopra
        static let tabellaSelezione = TC.selezioneRiga
        static let tabellaTesto = TC.inchiostro
        static let tabellaBordo = TC.bordoScheda
        // Stati (le pillole del tema)
        static let okFondo = TC.fondoInEssere
        static let okBordo = TC.verde.opacity(0.35)
        static let okTesto = TC.testoInEssere
        static let attenzioneFondo = TC.fondoProposta
        static let attenzioneBordo = TC.arancio.opacity(0.4)
        static let attenzioneTesto = TC.testoProposta
        static let erroreFondo = TC.rosso.opacity(0.14)
        static let erroreBordo = TC.rosso.opacity(0.35)
        static let erroreTesto = TC.scadenzaOra
        static let neutroFondo = TC.pozzetto
        static let neutroBordo = TC.separatore
        static let neutroTesto = TC.inchiostroSecondario
        // Grafici
        static let linea = adatto(Color(hex: "#2F6EB0"), Color(hex: "#6AA6F0"))
        static let lineaTratteggiata = TC.inchiostroTerziario
        static let barre = adatto(Color(hex: "#9CB6CC"), Color(hex: "#4F7393"))
        static let griglia = TC.separatore
        static let assi = TC.inchiostroTerziario
        static let tracciaAnello = TC.pozzetto
        static let prudente = Color(hex: "#c5ab7e")
        static let favorevole = Color(hex: "#6e9f9b")
        /// Andamento: dove sarebbe la posizione all'atteso netto.
        static let lineaAtteso = Color(hex: "#c5ab7e")
        static let canaleAlleanza = TC.canaleAlleanza
        static let canaleIndipendente = TC.canaleIndipendente
        // Barra di stato in basso: trasparente, con la spia verde
        static let statoAlto = Color.clear
        static let statoBasso = Color.clear
        static let statoBordo = TC.separatore
        static let statoLuce = TC.verde

        /// Colore di ogni area (toni medi: si leggono in chiaro e in scuro).
        static func area(_ a: AreaPosizione) -> Color {
            switch a {
            case .investimento: return Color(hex: "#6386a5")
            case .risparmio: return Color(hex: "#94b4a1")
            case .previdenza: return Color(hex: "#c5ab7e")
            case .protezione: return Color(hex: "#6e9f9b")
            case .liquidita: return Color(hex: "#8fa7bf")
            case .immobili: return Color(hex: "#a99382")
            case .debiti: return Color(hex: "#b07a6e")
            }
        }
    }

    /// Moduli e finestre di dialogo: testata e piede pieni come la barra del titolo.
    enum Modulo {
        static let titoloAlto = TC.finestraPiena
        static let titoloBasso = TC.finestraPiena
        static let titoloBordo = TC.separatore
        static let piedeAlto = TC.finestraPiena
        static let piedeBasso = TC.finestraPiena
        static let piedeBordo = TC.separatore
    }

    /// App Clienti: elenco e dossier su schede di vetro.
    enum Rubrica {
        static let fondoApp = Color.clear
        static let carta = TC.scheda
        static let libroBordo = TC.bordoScheda
        static let libroRiflesso = Color.clear
        static let libroOmbra = neroAlfa(0.06)
        static let indiceTitolo = TC.inchiostroSecondario
        static let contatoreAlto = TC.pozzetto
        static let contatoreBasso = TC.pozzetto
        static let contatoreBordo = Color.clear
        static let contatoreTesto = TC.inchiostroSecondario
        static let rigaNome = TC.inchiostro
        static let rigaTema = TC.inchiostroSecondario
        static let rigaFreccia = TC.inchiostroTerziario
        static let rigaLuce = Color.clear
        static let rigaBordo = TC.separatore
        // Riga scelta: accento pieno con il testo bianco
        static let selezioneAlto = TC.accento
        static let selezioneBasso = TC.accento
        static let selezioneBordoAlto = TC.accento
        static let selezioneBordoBasso = TC.accento
        static let selezioneIncisione = Color.clear
        static let selezioneTema = biancoAlfa(0.85)
        static let stella = adatto(Color(hex: "#B98A2E"), Color(hex: "#E3B866"))
        static let stellaSelezione = Color(hex: "#FFE1A4")
        static let stellaGrande = adatto(Color(hex: "#E6A817"), Color(hex: "#FFC845"))
        static let stellaVuota = TC.inchiostroTerziario
        static let piede = TC.inchiostroSecondario
        static let piedeBordo = TC.separatore
        static let cerca = TC.inchiostroTerziario
        static let divisoreOmbra = TC.separatore
        // Intestazione del dossier (ex cuoio chiaro): sul vetro della finestra
        static let selleriaAlto = Color.clear
        static let selleriaMezzo = Color.clear
        static let selleriaBasso = Color.clear
        static let selleriaBordo = TC.separatore
        static let selleriaLuce = Color.clear
        static let selleriaLuceBasso = Color.clear
        static let profiloOcchiello = TC.inchiostroSecondario
        static let profiloOcchielloIncisione = Color.clear
        static let profiloNome = TC.inchiostro
        static let profiloNomeIncisione = Color.clear
        static let avatarCornice = TC.bordoChip
        static let avatarOmbra = neroAlfa(0.2)
        static let pulsanteTesto = TC.inchiostro
        static let pulsanteIncisione = Color.clear
        static let pulsanteBordo = TC.bordoChip
        static let pulsanteLuce = Color.clear
        // Schede del dossier: pozzetto con il cursore chiaro (segmented del tema)
        static let schedeAlto = TC.pozzetto
        static let schedeBasso = TC.pozzetto
        static let schedeBordo = TC.separatore
        static let schedeLuce = Color.clear
        static let schedaAttivaAlto = TC.cursore
        static let schedaAttivaBasso = TC.cursore
        static let schedaAttivaBordo = TC.bordoChip
        static let schedaAttivaTesto = TC.inchiostro
        static let schedaAttivaIncisione = Color.clear
        static let schedaAttivaOmbra = neroAlfa(0.08)
        static let schedaAlto = Color.clear
        static let schedaBasso = Color.clear
        static let schedaBordo = Color.clear
        static let schedaTesto = TC.inchiostroSecondario
        // Contenuto
        static let testo = TC.inchiostro
        static let secondario = TC.inchiostroSecondario
        static let occhiello = TC.inchiostroSecondario
        static let sottile = TC.inchiostroTerziario
        static let filo = TC.separatore
        static let metricaEtichetta = TC.inchiostroSecondario
        static let metricaValore = TC.inchiostro
        static let metricaNota = TC.inchiostroSecondario
        static let schedaAppAlto = TC.chip
        static let schedaAppBasso = TC.chip
        static let schedaAppBordo = TC.bordoChip
        static let conteggio = TC.pozzetto
        static let conteggioTesto = TC.inchiostroSecondario
        // Pulsante principale "Nuovo cliente": primario del tema (accento, testo bianco)
        static let aqua: [Color] = [TC.accento, TC.accento, TC.accento, TC.accento]
        static let aquaBordo = Color.clear
        static let aquaTesto = Color.white
        static let aquaIncisione = Color.clear
        static let aquaLuce = Color.clear
        static let pericolo = TC.scadenzaOra
    }

    /// Widget della scrivania: vetro con chip e inchiostri del tema (molti gettoni restano per compatibilità).
    enum Widget {
        static let guidaSimbolo = TC.accento
        static let bordo = TC.bordoVetro
        static let ombra = neroAlfa(0.15)
        // Pannello dentro i widget e i suoi numeri
        static let pannelloBordo = TC.bordoChip
        static let pannelloAlto = TC.chip
        static let pannelloBasso = TC.chip
        static let pannelloOmbra = Color.clear
        static let kpiEtichetta = TC.inchiostroSecondario
        static let kpiValore = TC.inchiostro
        // Barra del portafoglio
        static let progressoFondo = TC.pozzettoScuro
        static let progressoBordo = Color.clear
        static let progressoOmbra = Color.clear
        static let progressoLuce = Color.clear
        static let carta = TC.scheda
        static let cartaBianca = TC.scheda
        static let titolo = TC.inchiostro
        static let secondario = TC.inchiostroSecondario
        static let numero = TC.inchiostro
        // Calendario da scrivania: rosso del tema, testo bianco
        static let calendario: [Color] = [TC.rosso, TC.rosso, TC.rosso, TC.rosso]
        static let calendarioBordo = Color.clear
        static let calendarioLuce = Color.clear
        static let calendarioTesto = Color.white
        static let calendarioSecondario = biancoAlfa(0.8)
        static let calendarioGiorno = TC.rosso
        static let calendarioPagina = TC.scheda
        static let calendarioPaginaBasso = TC.scheda
        static let calendarioRighe = TC.separatore
        static let calendarioMargine = Color.clear
        static let calendarioOra = TC.rosso
        static let anelloAlto = TC.pozzettoScuro
        static let anelloBasso = TC.pozzettoScuro
        static let anelloBordo = Color.clear
        // Ex cartella in pelle del cliente
        static let cucitura = Color.clear
        static let cartoncino = TC.chip
        static let cartoncinoBasso = TC.chip
        static let cartoncinoBordo = TC.bordoChip
        static let cartoncinoOmbra = Color.clear
        static let cartoncinoTesto = TC.inchiostro
        static let cartoncinoEtichetta = TC.inchiostroSecondario
        static let cartoncinoValore = TC.inchiostro
        // Ex pannello nero «Borsa» del portafoglio
        static let borsaAlto = TC.chip
        static let borsaMezzo = TC.chip
        static let borsaBasso = TC.chip
        static let borsaBordo = TC.bordoChip
        static let borsaRiflesso = Color.clear
        static let borsaTitolo = TC.inchiostroSecondario
        static let borsaTesto = TC.inchiostro
        static let borsaSecondario = TC.inchiostroSecondario
        static let borsaFilo = TC.separatore
        static let borsaVerde: [Color] = [TC.verde, TC.verde, TC.verde, TC.verde]
        static let borsaVerdeBordo = Color.clear
        static let borsaAlleanza = TC.canaleAlleanza
        static let borsaIndipendente = TC.canaleIndipendente
        // Ex foglietto giallo delle scadenze e rilegatura
        static let foglietto = TC.chip
        static let fogliettoBasso = TC.chip
        static let fogliettoRighe = TC.separatore
        static let fogliettoMargine = Color.clear
        static let fogliettoTesto = TC.inchiostro
        static let fogliettoSecondario = TC.inchiostroSecondario
        static let rilegaturaAlto = TC.chip
        static let rilegaturaMezzo = TC.chip
        static let rilegaturaBasso = TC.chip
        static let rilegaturaLuce = Color.clear
        static let rilegaturaOmbra = Color.clear
        // Promemoria
        static let promemoriaRighe = TC.separatore
        static let promemoriaTitolo = TC.inchiostro
        static let promemoriaCerchio = TC.pozzettoScuro
        static let promemoriaSpunta = TC.accento
        // Eve
        static let onda = [Color(hex: "#b9a6ff"), Color(hex: "#6f5bd6")]
        static let eveAlone = Color(hex: "#8a73ff")
    }

    /// Ex lino grafite: ora il riempimento dei pannelli di vetro.
    enum Lino {
        static let alto = TC.riempimentoPannelloColorato
        static let basso = TC.riempimentoPannelloColorato
    }

    /// Dock: capsula di vetro sottile, puntino piatto, nomi sullo sfondo.
    enum Dock {
        static let ripianoBordo = TC.bordoVetro
        static let ripianoFondo = TC.riempimentoLeggeroColorato
        static let ripianoOmbra = neroAlfa(0.2)
        static let filo = TC.riflessoAlto
        static let filoOmbra = Color.clear
        static let divisoreMezzo = TC.pozzettoScuro
        static let divisoreBasso = Color.clear
        static let iconaOmbra = neroAlfa(0.32)
        static let puntino = TC.inchiostroSfondo
        static let puntinoAlone = Color.clear
        /// Il suggerimento porta il testo bianco: resta scuro in tutti e due gli aspetti.
        static let suggerimento = Color(r: 22, g: 38, b: 50, a: 0.86)
        /// Il nome sotto l'icona, sullo sfondo d'acqua.
        static let etichetta = TC.inchiostroSfondo
        static let etichettaOmbra = TC.aloneSfondo
    }

    /// Finestre interne: vetro chiaro o scuro, barra del titolo che sfuma nel contenuto.
    enum Finestra {
        static let sfondo = TC.finestra
        static let contenuto = Color.clear
        static let bordoAttiva = TC.contornoFinestra
        static let bordoInattiva = TC.contornoFinestraInattiva
        static let ombraAttiva1 = neroAlfa(0.35)
        static let ombraAttiva2 = neroAlfa(0.18)
        static let ombraInattiva = neroAlfa(0.25)
        static let titoloAttivaAlto = TC.finestraPiena
        static let titoloAttivaBasso = TC.finestraPiena.opacity(0)
        static let titoloInattivaAlto = TC.finestraPiena
        static let titoloInattivaBasso = TC.finestraPiena.opacity(0)
        static let titoloBordoAttiva = Color.clear
        static let titoloBordoInattiva = Color.clear
        static let titoloLuce = Color.clear
        static let titoloTesto = TC.inchiostro
        static let titoloTestoInattivo = TC.inchiostroTerziario
        static let titoloIncisione = Color.clear
        static let contesto = TC.inchiostroSecondario
        static let affiancaAlto = TC.chip
        static let affiancaBasso = TC.chip
        static let affiancaBordo = TC.bordoChip
        static let affiancaSimbolo = TC.inchiostroSecondario
    }

    /// Semafori piatti del tema (gli array restano di tre colori per il gradiente radiale).
    enum Semafori {
        static let chiudi: [Color] = [TC.semaforoChiudi, TC.semaforoChiudi, TC.semaforoChiudi]
        static let chiudiBordo = TC.bordoSemaforo
        static let riduci: [Color] = [TC.semaforoRiduci, TC.semaforoRiduci, TC.semaforoRiduci]
        static let riduciBordo = TC.bordoSemaforo
        static let ingrandisci: [Color] = [TC.semaforoIngrandisci, TC.semaforoIngrandisci, TC.semaforoIngrandisci]
        static let ingrandisciBordo = TC.bordoSemaforo
        static let inattivoAlto = TC.pozzettoScuro
        static let inattivoBasso = TC.pozzettoScuro
        static let inattivoBordo = Color.clear
        static let simbolo = TC.simboloSemaforo
    }

    /// Intestazione delle app: trasparente, con un filo sotto.
    enum IntestazioneApp {
        static let alto = Color.clear
        static let mezzo = Color.clear
        static let basso = Color.clear
        static let bordo = TC.separatore
        static let luce = Color.clear
        static let titolo = TC.inchiostro
        static let occhiello = TC.inchiostroSecondario
        static let incisione = Color.clear
        /// Fondo predefinito delle app: si vede il vetro della finestra.
        static let corpo = Color.clear
    }

    enum Pannello {
        static let sfondo = TC.scheda
        static let bordo = TC.bordoScheda
        static let testo = TC.inchiostro
        static let testoSecondario = TC.inchiostroSecondario
        static let titolo = TC.inchiostro
    }

    enum Pulsante {
        // Pulsante di vetro: chip del tema
        static let vetroBordo = TC.bordoChip
        static let vetroOmbra = neroAlfa(0.08)
        static let testo = TC.inchiostro
        static let segmentoBordo = TC.separatore
        // Segmento scelto: porta il testo bianco
        static let segmentoAttivoAlto = TC.accento
        static let segmentoAttivoBasso = TC.accento
        static let segmentoAttivoBordo = TC.accento
        static let segmentoAttivoOmbra = Color.clear
        /// Pulsante principale ed etichetta Alleanza: il blu del canale, fisso e opaco
        /// (l'etichetta del canale va anche nei PDF, su carta bianca).
        static let blu: [Color] = [Color(hex: "#3B78F0"), Color(hex: "#2E6CEC"), Color(hex: "#2766EB"), Color(hex: "#2563EB")]
        static let bluBordo = Color(hex: "#1D52C4")
        static let bluIncisione = Color.clear
        static let bluLuce = biancoAlfa(0.25)
        static let bluRiflesso = Color.clear
        /// Etichetta del canale indipendente: cuoio/ambra del tema, fisso e opaco (anche nei PDF).
        static let cuoio: [Color] = [Color(hex: "#BE7E22"), Color(hex: "#B47417"), Color(hex: "#B06E12"), Color(hex: "#AC6B10")]
        static let cuoioBordo = Color(hex: "#8E570B")
        static let cuoioIncisione = Color.clear
    }

    /// Badge rosso piatto del tema.
    enum Badge {
        static let grande: [Color] = [TC.rosso, TC.rosso, TC.rosso, TC.rosso]
        static let grandeLuce = Color.clear
        static let grandeIncisione = Color.clear
        static let piccolo: [Color] = [TC.rosso, TC.rosso, TC.rosso, TC.rosso]
        static let piccoloIncisione = Color.clear
        static let ombra = neroAlfa(0.2)
    }

    /// Avviso temporaneo: capsula di vetro (riempimento coprente, si legge su qualunque fondo).
    enum Avvisi {
        static let alto = TC.riempimentoPannelloColorato
        static let basso = TC.riempimentoPannelloColorato
        static let bordo = TC.bordoVetro
        static let testo = TC.inchiostro
        static let ombra = neroAlfa(0.22)
        static let luce = Color.clear
    }

    /// Colori degli avatar dei clienti (tinte del tema, iniziali bianche).
    enum Avatar {
        struct Tinta {
            let alto: Color
            let basso: Color
            let bordo: Color
            let testo: Color
        }

        static let blu = Tinta(alto: Color(hex: "#A3BEDF"), basso: Color(hex: "#4C72A8"), bordo: biancoAlfa(0.35), testo: .white)
        static let rosa = Tinta(alto: Color(hex: "#E4AEB9"), basso: Color(hex: "#B0687A"), bordo: biancoAlfa(0.35), testo: .white)
        static let verde = Tinta(alto: Color(hex: "#A5CDB5"), basso: Color(hex: "#4B8566"), bordo: biancoAlfa(0.35), testo: .white)
        static let viola = Tinta(alto: Color(hex: "#BCB0D8"), basso: Color(hex: "#6E62A0"), bordo: biancoAlfa(0.35), testo: .white)
        static let oro = Tinta(alto: Color(hex: "#E2CC98"), basso: Color(hex: "#A9853C"), bordo: biancoAlfa(0.35), testo: .white)
        static let luce = biancoAlfa(0.5)
        static let ombra = neroAlfa(0.2)
    }

    /// App Impostazioni: gruppi su schede di vetro, interruttore verde.
    enum Impostazioni {
        static let gruppoBordo = TC.bordoScheda
        static let gruppoRiflesso = Color.clear
        static let rigaBordo = TC.separatore
        static let rigaTitolo = TC.inchiostro
        static let rigaSottotitolo = TC.inchiostroSecondario
        static let rigaValore = TC.inchiostroSecondario
        static let avvertenza = TC.scadenzaOra
        static let nota = TC.inchiostroSecondario
        static let notaIncisione = Color.clear
        static let intestazioneGruppo = TC.inchiostroSecondario
        static let schedeBordo = TC.separatore
        static let segmentoBordo = TC.separatore
        static let segmentoTesto = TC.inchiostro
        // Segmento scelto: porta il testo bianco
        static let segmentoAttivoAlto = TC.accento
        static let segmentoAttivoBasso = TC.accento
        static let segmentoAttivoBordo = TC.accento
        static let segmentoAttivoIncisione = Color.clear
        static let informazioniFilo = TC.separatore
        static let informazioniTesto = TC.inchiostroSecondario
        static let informazioniOcchiello = TC.inchiostroTerziario
        static let informazioniTitolo = TC.inchiostro
        static let numero = TC.inchiostro
        static let numeroEtichetta = TC.inchiostroSecondario
        static let interruttoreSpento: [Color] = [TC.pozzettoScuro, TC.pozzettoScuro, TC.pozzettoScuro]
        static let interruttoreSpentoBordo = Color.clear
        static let interruttoreAcceso: [Color] = [TC.verde, TC.verde, TC.verde, TC.verde]
        static let interruttoreAccesoBordo = Color.clear
        static let interruttoreOmbra = Color.clear
        static let interruttoreAccesoOmbra = Color.clear
        static let interruttoreTestoSpento = TC.inchiostroSecondario
    }

    enum Agenda {
        /// Icona Agenda (sempre su piastrella bianca): giorno #1C1C1E, mese rosso del tema, niente ombra.
        static let inchiostroAlto = Color(hex: "#1C1C1E")
        static let inchiostroBasso = Color(hex: "#1C1C1E")
        static let mese = Color(hex: "#E0443A")
        static let meseOmbra = Color.clear
        static let giornoIcona = Color(hex: "#1C1C1E")

        // App Agenda: niente cuoio né anelli, schede di vetro, giorno scelto in rosso
        static let fondoApp = Color.clear
        static let cuoioAlto = Color.clear
        static let cuoioMezzo = Color.clear
        static let cuoioBasso = Color.clear
        static let cuoioBordo = TC.separatore
        static let cuoioLuce = Color.clear
        static let cuoioLuceBasso = Color.clear
        static let cuoioCucitura = Color.clear
        static let cuoioCucituraOmbra = Color.clear
        static let cuoioTitolo = TC.inchiostro
        static let cuoioTesto = TC.inchiostroSecondario
        static let cuoioIncisione = Color.clear
        static let targhettaCarta = TC.tesseraData
        static let targhettaBordo = TC.bordoChip
        static let targhettaOmbra1 = Color.clear
        static let targhettaOmbra2 = Color.clear
        static let targhettaOmbra3 = neroAlfa(0.08)
        static let targhettaRossoAlto = TC.rosso
        static let targhettaRossoBasso = TC.rosso
        static let targhettaRossoBordo = Color.clear
        static let targhettaRossoLuce = Color.clear
        static let targhettaRossoIncisione = Color.clear
        static let targhettaTesto = TC.inchiostro
        static let cartaBordo = TC.scheda
        static let carta = TC.scheda
        static let libroBordo = TC.bordoScheda
        static let libroOmbra1 = Color.clear
        static let libroOmbra2 = Color.clear
        static let libroOmbra3 = neroAlfa(0.06)
        static let anello: [Color] = Array(repeating: Color.clear, count: 8)
        static let anelloBordo = Color.clear
        static let anelloOmbra = Color.clear
        static let barraStrumenti = Color.clear
        static let settimanaAlto = TC.rigaSopra
        static let settimanaBasso = TC.rigaSopra
        static let settimanaBordo = TC.separatore
        static let giorno = TC.inchiostroSecondario
        static let giornoNumero = TC.inchiostro
        static let giornoPassaggio = TC.rigaSopra
        static let giornoOggiBordo = TC.rosso
        static let giornoOggiNumero = TC.rosso
        static let selezioneAlto = TC.rosso
        static let selezioneBasso = TC.rosso
        static let selezioneBordo = Color.clear
        static let selezioneLuce = Color.clear
        static let selezioneIncisione = Color.clear
        static let selezioneTesto = Color.white
        static let puntino = TC.inchiostroTerziario
        static let puntinoSelezione = biancoAlfa(0.9)
        static let paginaOcchiello = TC.scadenzaOra
        static let paginaTitolo = TC.inchiostro
        static let paginaNota = TC.inchiostroSecondario
        static let paginaBordo = TC.separatore
        static let rigatura = Color.clear
        static let rigaBordo = TC.separatore
        static let rigaSelezione = TC.selezioneRiga
        static let rigaSegno = TC.rosso
        static let ora = TC.inchiostro
        static let oraFine = TC.inchiostroSecondario
        static let evento = TC.inchiostro
        static let eventoConcluso = TC.inchiostroTerziario
        static let eventoCliente = TC.inchiostroSecondario
        static let eventoDettagli = TC.inchiostroSecondario
        static let freccia = TC.inchiostroTerziario
        static let conclusoTesto = TC.testoInEssere
        static let conclusoFondo = TC.fondoInEssere
        static let scadenzaTesto = TC.testoProposta
        static let scadenzaFondo = TC.fondoProposta
        static let notaSettimana = TC.inchiostroSecondario
        static let notaSettimanaBordo = TC.separatore
        static let dettaglioAlto = TC.laterale
        static let dettaglioFondo = TC.laterale
        static let dettaglioBordo = TC.separatore
        static let dettaglioOcchiello = TC.inchiostroSecondario
        static let dettaglioTitolo = TC.inchiostro
        static let dettaglioCliente = TC.inchiostroSecondario
        static let voceEtichetta = TC.inchiostroSecondario
        static let voceValore = TC.inchiostro
        static let voceBordo = TC.separatore
        static let notaFondo = TC.chip
        static let notaBordo = TC.bordoChip
        static let notaLuce = Color.clear
        static let notaEtichetta = TC.inchiostroSecondario
        static let notaTesto = TC.inchiostro
        static let azioniBordo = TC.separatore
        static let quieto = TC.inchiostroTerziario
        static let quietoTesto = TC.inchiostroSecondario
        static let quietoSuggerimento = TC.inchiostroTerziario
        static let vuotoData = TC.inchiostroTerziario
        static let vuotoTitolo = TC.inchiostroSecondario
        static let vuotoTesto = TC.inchiostroTerziario
    }

    /// App Incontri: schede di vetro, niente carta a righe.
    enum Incontri {
        static let fondoAlto = Color.clear
        static let fondoBasso = Color.clear
        static let testo = TC.inchiostro
        static let secondario = TC.inchiostroSecondario
        static let cartaBordo = TC.bordoScheda
        static let cartaLato = TC.scheda
        static let carta = TC.scheda
        static let rigatura = Color.clear
        static let margine = Color.clear
        static let filo = TC.separatore
        static let citazione = TC.inchiostroSecondario
        static let citazioneFondo = TC.pozzetto
        static let concluso = TC.testoInEssere
        static let piede = TC.rigaSopra
    }

    /// Profilo dei bisogni (scheda del cliente).
    enum Bisogni {
        static func area(_ a: AreaBisogno) -> Color {
            switch a {
            case .casa: return Color(hex: "#94b4a1")
            case .famiglia: return Color(hex: "#6e9f9b")
            case .lavoro: return Color(hex: "#8fa7bf")
            case .pensione: return Color(hex: "#c5ab7e")
            case .salute: return Color(hex: "#b07a6e")
            case .patrimonio: return Color(hex: "#6386a5")
            }
        }
        static func importanza(_ i: Importanza) -> Color {
            switch i {
            case .nessuna: return Color(hex: "#a9a49a")
            case .bassa: return Color(hex: "#7f9a76")
            case .media: return Color(hex: "#c08a3e")
            case .alta: return Color(hex: "#b5523f")
            }
        }
        static let ruotaFondo = TC.pozzetto
        static let ruotaBordo = TC.separatore
        static let cartaFondo = TC.scheda
        static let cartaBordo = TC.bordoScheda
        static let cartaOmbra = neroAlfa(0.06)
        static let confermato = TC.testoInEssere
        static let confermatoFondo = TC.fondoInEssere
        static let scartato = TC.inchiostroTerziario
        static let chipFondo = TC.chip
        static let chipBordo = TC.bordoChip
        static let chipTesto = TC.inchiostroSecondario
    }

    /// App Eve: schede e bolle di vetro, le tue in accento (si cambia qui, non in AppEve.swift).
    enum Eve {
        static let linoAlto = Color.clear
        static let linoBasso = Color.clear
        static let testataAlto = TC.laterale
        static let testataBasso = TC.laterale
        static let testataBordo = TC.separatore
        static let testataLuce = Color.clear
        static let testataTesto = TC.inchiostroSecondario
        static let testataTitolo = TC.inchiostro
        static let testataIncisione = Color.clear
        static let avvisoAlto = TC.chip
        static let avvisoBasso = TC.chip
        static let avvisoBordo = TC.bordoChip
        static let avvisoTesto = TC.inchiostroSecondario
        static let spiaPronta = TC.verde
        static let spiaSintesi = TC.arancio
        static let conversazioneAlto = Color.clear
        static let conversazioneBasso = Color.clear
        static let conversazioneBordo = TC.separatore
        static let barraAlto = TC.finestraPiena
        static let barraBasso = TC.finestraPiena
        static let barraBordo = TC.separatore
        static let barraTesto = TC.inchiostroSecondario
        // Display: pozzetto del tema con l'onda viola
        static let displayAlto = TC.pozzetto
        static let displayBasso = TC.pozzetto
        static let displayBordo = TC.separatore
        static let displayTesto = TC.inchiostroSecondario
        static let nuvolaEveAlto = TC.scheda
        static let nuvolaEveBasso = TC.scheda
        static let nuvolaEveBordo = TC.bordoScheda
        static let nuvolaEveTesto = TC.inchiostro
        static let nuvolaTuoi: [Color] = [TC.accento, TC.accento, TC.accento, TC.accento]
        static let nuvolaTuaBordo = Color.clear
        static let nuvolaTuaTesto = Color.white
        static let autore = TC.inchiostroTerziario
        static let azioneAlto = TC.chip
        static let azioneBasso = TC.chip
        static let azioneBordo = TC.bordoChip
        static let azioneTesto = TC.inchiostro
        static let campo = TC.pozzetto
        static let campoBordo = TC.separatore
        static let cartaBordo = TC.bordoScheda
        static let cuoioTesto = TC.inchiostro
        static let tappa = TC.chip
        static let tappaBordo = TC.bordoChip
        static let tappaAttiva = TC.selezione
        static let tappaAttivaBordo = TC.accento.opacity(0.35)
        static let tappaTesto = TC.inchiostro
        static let tappaNota = TC.inchiostroSecondario
        static let postitAlto = adatto(Color(hex: "#FFF4B0"), Color(r: 255, g: 214, b: 10, a: 0.16))
        static let postitBasso = adatto(Color(hex: "#FBEA92"), Color(r: 255, g: 214, b: 10, a: 0.12))
        static let postitTesto = adatto(Color(hex: "#5C4C21"), Color(hex: "#F3E2A0"))
        static let quadroBordo = TC.separatore
        static let quadroAlto = TC.scheda
        static let quadroBasso = TC.scheda
        static let quadroTesto = TC.inchiostroSecondario
        // Voce: il microfono acceso è rosso pieno, la spia rossa dice che Eve ascolta
        static let microfonoAcceso: [Color] = [TC.rosso, TC.rosso, TC.rosso, TC.rosso]
        static let microfonoBordo = Color(hex: "#D70015")
        static let microfonoIncisione = Color.clear
        static let spiaAscolto = TC.rosso
        static let spiaVoce = TC.accento
        static let displayAttivo = TC.inchiostro
        static let ascoltoTesto = TC.inchiostroSecondario
    }

    /// Strumenti di analisi: Simulazioni, Confronti, Analisi 360.
    enum Strumenti {
        // Console del simulatore: laterale di vetro, display nel pozzetto
        static let consoleAlto = TC.laterale
        static let consoleBasso = TC.laterale
        static let consoleBordo = TC.separatore
        static let consoleTitolo = TC.inchiostroSecondario
        static let consoleEtichetta = TC.inchiostro
        static let lcdAlto = TC.pozzetto
        static let lcdBasso = TC.pozzetto
        static let lcdBordo = TC.separatore
        static let lcdOmbra = Color.clear
        static let lcdTesto = TC.inchiostro
        static let lcdLuce = Color.clear
        static let spia = TC.verde
        static let simulatoreBordo = TC.separatore
        static let carta = TC.scheda
        static let cartaRiga = Color.clear
        static let risultato = TC.inchiostro
        static let risultatoNota = TC.inchiostroSecondario
        static let risultatoBordo = TC.separatore
        static let negativo = TC.scadenzaOra
        static let positivo = TC.testoInEssere
        // Schede delle aree
        static let schedaBordoLato = TC.scheda
        static let schedaFondo = TC.scheda
        static let schedaBordo = TC.bordoScheda
        static let schedaBordoSopra = TC.separatore
        static let schedaOmbra1 = Color.clear
        static let schedaOmbra2 = Color.clear
        static let schedaTitolo = TC.inchiostro
        static let schedaValore = TC.inchiostro
        static let schedaNota = TC.inchiostroSecondario
        static let schedaNumero = TC.inchiostroTerziario
        static let schedaFilo = TC.separatore
        static let titolo = TC.inchiostro
        static let occhiello = TC.inchiostroSecondario
        // Pannello delle ipotesi e dei risultati
        static let ipotesiTestaAlto = TC.rigaSopra
        static let ipotesiTestaBasso = TC.rigaSopra
        static let ipotesiBordo = TC.bordoScheda
        static let ipotesiTesto = TC.inchiostro
        static let ipotesiRiga = TC.separatore
        static let ipotesiNota = TC.inchiostroSecondario
        static let layoutBordo = TC.separatore
        static let risultati = TC.scheda
        // Schede dei risultati: pozzetto con il cursore chiaro
        static let schedeAlto = TC.pozzetto
        static let schedeBasso = TC.pozzetto
        static let schedeBordo = TC.separatore
        static let schedaAttivaAlto = TC.cursore
        static let schedaAttivaBasso = TC.cursore
        static let schedaAttivaBordo = TC.bordoChip
        static let schedaAttivaTesto = TC.inchiostro
        static let schedaTesto = TC.inchiostroSecondario
        static let piede = TC.rigaSopra
        static let piedeBordo = TC.separatore
        static let piedeTesto = TC.inchiostroSecondario
        static let metodoFondo = TC.pozzetto
        static let metodoBordo = TC.separatore
        static let metodoTesto = TC.inchiostroSecondario
        static let rischioPresenteFondo = TC.fondoInEssere
        static let rischioPresenteBordo = TC.verde.opacity(0.35)
        static let rischioPresenteTesto = TC.testoInEssere
        static let rischioAssenteFondo = TC.pozzetto
        static let rischioAssenteBordo = TC.separatore
        static let rischioAssenteTesto = TC.inchiostroSecondario
        // Serie dei confronti: A, B, C
        static let serie = [adatto(Color(hex: "#2F6EB0"), Color(hex: "#6AA6F0")), Color(hex: "#c08a3e"), Color(hex: "#6e9f9b")]
    }

    /// App Attività: elenco su scheda di vetro, spunte verdi del tema.
    enum Attivita {
        static let linoAlto = Color.clear
        static let linoBasso = Color.clear
        static let testataAlto = Color.clear
        static let testataBasso = Color.clear
        static let testataBordo = TC.separatore
        static let testataLuce = Color.clear
        static let testataTitolo = TC.inchiostro
        static let testataTesto = TC.inchiostroSecondario
        static let testataIncisione = Color.clear
        static let numero = TC.inchiostro
        static let numeroIncisione = Color.clear
        static let separatore = TC.separatore
        static let separatoreLuce = Color.clear
        static let progressoFondo = TC.pozzettoScuro
        static let progressoBordo = Color.clear
        static let progressoAlto = TC.verde
        static let progressoBasso = TC.verde
        static let registroBordo = TC.bordoScheda
        static let registroFondo = TC.scheda
        static let registroOmbra1 = Color.clear
        static let registroOmbra2 = Color.clear
        static let metalloAlto = TC.rigaSopra
        static let metalloBasso = TC.rigaSopra
        static let metalloBordo = TC.separatore
        static let carta = TC.scheda
        static let rigatura = Color.clear
        static let margine = Color.clear
        static let titoloElenco = TC.inchiostroSecondario
        static let titoloElencoFondo = TC.rigaSopra
        static let titoloElencoBordo = TC.separatore
        static let rigaBordo = TC.separatore
        static let rigaSelezione = TC.selezioneRiga
        static let rigaTitolo = TC.inchiostro
        static let rigaTitoloFatto = TC.inchiostroTerziario
        static let rigaSotto = TC.inchiostroSecondario
        static let scadenza = TC.inchiostroSecondario
        static let scadenzaOggi = TC.scadenzaVicina
        static let scadenzaPassata = TC.scadenzaOra
        static let scadenzaFatta = TC.testoInEssere
        static let prioritaAlta = TC.arancio
        static let prioritaBassa = TC.inchiostroTerziario
        static let spuntaAlto = TC.chip
        static let spuntaBordo = TC.pozzettoScuro
        static let spuntaFattaAlto = TC.verde
        static let spuntaFattaBasso = TC.verde
        static let spuntaFattaBordo = Color.clear
        static let dettaglioAlto = TC.laterale
        static let dettaglioFondo = TC.laterale
        static let dettaglioBordo = TC.separatore
        static let dettaglioOcchiello = TC.inchiostroSecondario
        static let dettaglioTitolo = TC.inchiostro
        static let dettaglioCliente = TC.inchiostroSecondario
        static let voceEtichetta = TC.inchiostroSecondario
        static let voceValore = TC.inchiostro
        static let voceBordo = TC.separatore
        static let collegamentoFondo = TC.chip
        static let collegamentoBordo = TC.bordoChip
        static let collegamentoEtichetta = TC.inchiostroSecondario
        static let collegamentoTitolo = TC.inchiostro
        static let collegamentoTesto = TC.inchiostroSecondario
        static let nota = TC.inchiostroSecondario
        static let vuoto = TC.inchiostroTerziario
        static let vuotoTitolo = TC.inchiostroSecondario
        static let vuotoTesto = TC.inchiostroTerziario
    }

    /// I menu a tendina: chip del tema in tutte le varianti (le testate scure non ci sono più).
    enum Tendina {
        static let freccia = TC.inchiostroSecondario
        static let cartaFondo = TC.chip
        static let cartaBordo = TC.bordoChip
        static let cartaTesto = TC.inchiostro
        static let scuroFondo = TC.chip
        static let scuroBordo = TC.bordoChip
        static let scuroTesto = TC.inchiostro
        static let scuroFreccia = TC.inchiostroSecondario
    }

    /// Campi di testo: pozzetto del tema.
    enum Campo {
        static let testo = TC.inchiostro
        static let fondo = TC.pozzetto
        static let bordo = TC.separatore
        static let ombraInterna = Color.clear
        static let riflesso = Color.clear
    }
}
