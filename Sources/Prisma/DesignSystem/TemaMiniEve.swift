import SwiftUI

// MARK: - Gettoni della mini finestra di Eve (Design/eve-mini.html: .eve, .pill, .c-head, .tl, .rows, .composer, .orb)
// Una sola superficie di vetro (.glass.panel) che cambia forma: capsula mentre ascolta e pensa, scheda quando risponde.

extension Tema.Colore {
    /// Colori della mini finestra di Eve: dai gettoni comuni del tema, più la sfera d'acqua del template.
    enum MiniEve {
        /// Il vetro della superficie (.glass.panel: bianco al 70% sfocato di 30 px). La mini finestra è un pannello a sé,
        /// sopra le altre finestre e app: la sfocatura di ciò che sta dietro non è garantita, quindi il velo è più
        /// coprente e il testo della finestra sotto non si legge attraverso (come nel template).
        static let fondo = Color.dinamico(chiaro: Color(r: 247, g: 247, b: 251, a: 0.92), scuro: Color(r: 18, g: 29, b: 38, a: 0.93))
        static let testo = Tema.Colore.inchiostro
        static let testoSecondario = Tema.Colore.inchiostroSecondario
        static let testoTerziario = Tema.Colore.inchiostroTerziario
        static let separatore = Tema.Colore.separatore
        static let accento = Tema.Colore.accento
        static let link = Tema.Colore.link
        /// Cursore che lampeggia mentre parli (.caret).
        static let cursore = Tema.Colore.accento
        /// Pulsanti tondi (.ico) e pozzetti (.sugg, .recent al passaggio, .kb, .prog).
        static let pozzetto = Tema.Colore.pozzetto
        static let pozzettoSopra = Tema.Colore.pozzettoScuro
        /// Schede interne (.tl, .rows, .composer).
        static let scheda = Tema.Colore.scheda
        static let bordoScheda = Tema.Colore.bordoScheda
        /// Pulsanti di vetro (.btn) e gettone del contesto (.ctx-chip).
        static let chip = Tema.Colore.chip
        static let chipSopra = Tema.Colore.chipSopra
        static let bordoChip = Tema.Colore.bordoChip
        static let lucePulsante = Color.dinamico(chiaro: Color(r: 255, g: 255, b: 255, a: 0.95), scuro: Color(r: 255, g: 255, b: 255, a: 0.42))
        static let testoSuAccento = Color.white
        /// Barra di avanzamento di «Mi sto svegliando…» e spia «In locale sul Mac».
        static let avanzamento = Tema.Colore.arancio
        static let inLocale = Tema.Colore.verde
        /// Onda della voce: dall'accento all'azzurro (#5CC2E0).
        static let ondaFine = Color(hex: "#5CC2E0")
        /// Contorno dei puntini sulla linea del tempo (stroke #fff).
        static let bordoPunto = Color.white
        /// La sfera nella barra con la mini finestra aperta (.screen[data-open] .bar-eve).
        static let sferaBarraAperta = Tema.Colore.chip

        /// La sfera di Eve: acqua viva (fondo e tre correnti di luce).
        enum Sfera {
            static let fondoCentro = Color(hex: "#12486E")
            static let fondoBordo = Color(hex: "#0A2A42")
            static let corrente1 = Color(hex: "#3FA3D6")
            static let corrente2 = Color(hex: "#A9E2F5")
            static let corrente3 = Color(hex: "#8E96E6")
            static let opacita2: Double = 0.85
            static let opacita3: Double = 0.7
            static let riflesso = Color(r: 255, g: 255, b: 255, a: 0.95)
            static let ombraBasso = Color(r: 0, g: 25, b: 45, a: 0.5)
            static let filo = Color(r: 255, g: 255, b: 255, a: 0.55)
            /// Alone: rgba(60,160,215, .45 + livello × .35).
            static let alone = Color(r: 60, g: 160, b: 215, a: 1)
            static let aloneBase: Double = 0.45
            static let aloneVoce: Double = 0.35
            /// Spenta (Qwen non è pronto): quasi grigia.
            static let saturazioneSpenta: Double = 0.15
            static let luceSpenta: Double = 0.05
        }
    }
}

extension Tema.Raggio {
    enum MiniEve {
        /// La scheda (.eve.card: 28 px); la capsula è una capsula vera.
        static let scheda: CGFloat = 28
        static let lineaTempo: CGFloat = 18
        static let righe: CGFloat = 16
        static let recente: CGFloat = 10
        static let tasto: CGFloat = 5
    }
}

extension Tema.Misura {
    /// Misure della mini finestra di Eve (dal template).
    enum MiniEve {
        // La superficie
        static let larghezzaCapsula: CGFloat = 440
        static let larghezzaScheda: CGFloat = 460
        static let altezzaCapsula: CGFloat = 72
        /// Sotto la barra superiore e dal bordo destro (--eve-top, --eve-right).
        static let distanzaBarra: CGFloat = 12
        static let distanzaDestra: CGFloat = 16
        /// Spazio trasparente attorno alla superficie nel pannello, per l'ombra del vetro (0 22px 44px -24px).
        static let margineOmbraLati: CGFloat = 28
        static let margineOmbraSopra: CGFloat = 12
        static let margineOmbraSotto: CGFloat = 48
        /// La scheda non supera l'altezza dello schermo sotto la barra (meno `margineSchermo`); questa è quella
        /// delle istantanee e il minimo. Oltre, la risposta scorre.
        static let altezzaMassima: CGFloat = 640
        static let margineSchermo: CGFloat = 24
        static let altezzaMinima: CGFloat = 320
        /// Testa, campo e piede della scheda: il resto dell'altezza è del corpo della risposta.
        static let cornice: CGFloat = 170
        /// Entrata e uscita (.screen[data-open="0"] .eve): su di 14 e al 90%.
        static let salitaUscita: CGFloat = -14
        static let scalaUscita: CGFloat = 0.9

        // Capsula (.pill)
        static let margineCapsula = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 14)
        static let spazioCapsula: CGFloat = 14
        static let spazioSotto: CGFloat = 2
        static let cursore = CGSize(width: 2, height: 17)
        static let barreOnda = 15
        static let barraOnda: CGFloat = 3
        static let spazioOnda: CGFloat = 2.5
        static let altezzaOnda: CGFloat = 32
        static let barraOndaMinima: CGFloat = 4
        static let barraOndaVoce: CGFloat = 26
        static let barraAvanzamento: CGFloat = 3
        static let spazioAvanzamento: CGFloat = 7
        static let quotaAvanzamento: CGFloat = 0.35

        // La sfera (.orb)
        static let sferaCapsula: CGFloat = 40
        static let sferaScheda: CGFloat = 30
        static let sferaBarra: CGFloat = 17
        static let sferaPulsanteBarra: CGFloat = 24

        // Pulsanti tondi (.ico), pulsanti (.btn), microfono (.mic)
        static let ico: CGFloat = 26
        static let simboloIco: CGFloat = 12
        static let pulsante: CGFloat = 28
        static let marginePulsante: CGFloat = 12
        static let spazioPulsante: CGFloat = 6
        static let simboloPulsante: CGFloat = 12
        static let microfono: CGFloat = 30
        static let simboloMicrofono: CGFloat = 14

        // Scheda (.c-head, .c-body)
        static let margineTesta = EdgeInsets(top: 14, leading: 16, bottom: 0, trailing: 12)
        static let spazioTesta: CGFloat = 10
        static let spazioDomanda: CGFloat = 1
        static let margineCorpo = EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16)
        static let interlinea: CGFloat = 7
        static let spazioBlocchi: CGFloat = 12
        static let spazioRighe: CGFloat = 8
        static let barreParla = 3
        static let barraParla: CGFloat = 2
        static let altezzaParla: CGFloat = 10

        // Linea del tempo (.tl)
        static let margineLineaTempo = EdgeInsets(top: 12, leading: 12, bottom: 10, trailing: 12)
        static let altezzaLineaTempo: CGFloat = 86
        static let asseLineaTempo: CGFloat = 66
        static let tacca: CGFloat = 3
        static let puntoOggi: CGFloat = 3.5
        static let puntoScadenza: CGFloat = 5
        static let astaMinima: CGFloat = 14
        static let astaVariabile: CGFloat = 22
        static let mesiLineaTempo = 12

        // Righe (.rows .row)
        static let margineRiga = EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
        static let spazioRiga: CGFloat = 10

        // Fonte, spunti, recenti
        static let spazioFonte: CGFloat = 6
        static let simboloFonte: CGFloat = 11
        static let margineEtichetta = EdgeInsets(top: 12, leading: 0, bottom: 7, trailing: 0)
        static let spunto: CGFloat = 28
        static let margineSpunto: CGFloat = 11
        static let spazioSpunti: CGFloat = 6
        static let margineRecente = EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)
        static let spazioRecente: CGFloat = 9

        // Gettone del contesto (.ctx-chip)
        static let gettone: CGFloat = 22
        static let margineGettone: CGFloat = 4
        static let spazioGettone: CGFloat = 6
        static let avatarGettone: CGFloat = 16
        static let togliGettone: CGFloat = 16
        static let simboloTogli: CGFloat = 8

        // Scrittura (.composer) e piede (.foot)
        static let margineScrittura = EdgeInsets(top: 12, leading: 10, bottom: 0, trailing: 10)
        static let margineCampo = EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 5)
        static let spazioCampo: CGFloat = 8
        static let altezzaCampo: CGFloat = 28
        static let anelloCampo: CGFloat = 3
        static let marginePiede = EdgeInsets(top: 9, leading: 16, bottom: 11, trailing: 16)
        static let spiaLocale: CGFloat = 6
        static let aloneSpia: CGFloat = 3
        static let margineTasto = EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5)

        /// Pulsante «Riprova» (.btn.sm).
        static let pulsantePiccolo: CGFloat = 28
    }
}

extension Tema.Testo {
    enum MiniEve {
        /// La frase mentre parli (.say: 500 16px display).
        static let frase = Tema.Testo.sf(16, .medium)
        static let fraseSveglia = Tema.Testo.sf(14.5, .medium)
        static let pensa = Tema.Testo.sf(15, .medium)
        static let sotto = Tema.Testo.sf(11.5)
        // Scheda
        static let autore = Tema.Testo.sf(11, .medium)
        static let domanda = Tema.Testo.sf(14, .semibold)
        static let risposta = Tema.Testo.sf(14)
        static let rispostaForte = Tema.Testo.sf(14, .semibold)
        // Linea del tempo
        static let occhiello = Tema.Testo.sf(11, .semibold)
        static let spaziaturaOcchiello = Tema.Testo.spaziatura(0.04, 11)
        static let totale = Tema.Testo.sf(18, .semibold, arrotondato: true).monospacedDigit()
        static let mese = Tema.Testo.sfFisso(9.5, .medium)
        static let oggi = Tema.Testo.sfFisso(9.5, .semibold)
        static let importoPunto = Tema.Testo.sfFisso(10.5, .semibold)
        static let dataPunto = Tema.Testo.sfFisso(9.5, .medium)
        // Righe
        static let rigaTitolo = Tema.Testo.sf(12.5, .semibold)
        static let rigaSotto = Tema.Testo.sf(11.5)
        static let rigaValore = Tema.Testo.sf(13, .semibold, arrotondato: true).monospacedDigit()
        static let rigaData = Tema.Testo.sf(10.5, .medium)
        // Fonte, pulsanti, spunti
        static let fonte = Tema.Testo.sf(11)
        static let pulsante = Tema.Testo.sf(12.5, .medium)
        static let etichetta = Tema.Testo.sf(10.5, .semibold)
        static let spaziaturaEtichetta = Tema.Testo.spaziatura(0.05, 10.5)
        static let spunto = Tema.Testo.sf(12)
        static let recente = Tema.Testo.sf(12.5)
        static let quando = Tema.Testo.sf(11)
        // Gettone del contesto
        static let gettone = Tema.Testo.sf(11.5, .semibold)
        static let gettoneApp = Tema.Testo.sf(11.5, .medium)
        static let avatarGettone = Tema.Testo.sfFisso(7, .semibold, arrotondato: true)
        // Scrittura e piede
        static let campo = Tema.Testo.sf(13.5)
        static let piede = Tema.Testo.sf(10.5)
        static let tasto = Tema.Testo.sfFisso(10, .medium)
    }
}

extension Tema.Moto {
    /// Movimenti della mini finestra (--out .55 s per la forma, --spring per l'entrata).
    enum MiniEve {
        /// Il cambio di forma tra capsula e scheda: una molla morbida di 0,55 s.
        static let forma = Animation.spring(response: 0.55, dampingFraction: 0.86)
        static let durataForma: Double = 0.55
        static let entrata = Animation.spring(response: 0.5, dampingFraction: 0.72)
        static let uscita = Animation.easeOut(duration: 0.3)
        static let durataUscita: Double = 0.3
        /// Con «Riduci movimento»: solo una dissolvenza breve.
        static let ridotto = Animation.easeInOut(duration: 0.15)
        /// Il contenuto che compare (.reveal: rise .5 s).
        static let comparsa = Tema.Moto.uscita(0.5)
        /// I passi di «pensa» (uno ogni 0,85 s) e il lampeggio del cursore.
        static let passoPensiero: Double = 0.85
        static let lampeggio: Double = 1
        /// Il luccichio del testo che pensa (1,8 s) e la barra di avanzamento (1,6 s).
        static let luccichio: Double = 1.8
        static let avanzamento: Double = 1.6
        /// La sfera: correnti di 5, 4 e 6 secondi, avanti e indietro; più veloce mentre ascolta (2,2) e pensa (3,5).
        static let periodiSfera: [Double] = [5, 4, 6]
        static let velocitaAscolto: Double = 2.2
        static let velocitaPensiero: Double = 3.5
        static let velocitaSpenta: Double = 0.3
        /// Fotogrammi al secondo della sfera e dell'onda: bastano 30 (Mac da 8 GB).
        static let fotogrammi: Double = 30
        /// ⌥ Spazio tenuto premuto oltre questa soglia = parla.
        static let sogliaTenuto: Double = 0.3
    }
}
