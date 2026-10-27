import AppKit
import SwiftUI

// MARK: - Gettoni della shell (barra, scrivania, widget, dock, finestre, benvenuto, app aperte)
// Valori di tema.html: quelli comuni stanno in Tema.swift, qui solo quelli propri della shell.

extension Tema.Colore {
    /// Colori della shell che non stanno tra i gettoni comuni.
    enum Shell {
        /// Avatar del consulente nella barra (.me): radiale da chiaro a scuro, filo chiaro in alto.
        static let avatarAlto = Color(hex: "#8FB3CF")
        static let avatarBasso = Color(hex: "#36607F")
        static let avatarLuce = Color(r: 255, g: 255, b: 255, a: 0.5)
        static let avatarTesto = Color.white
        /// Velo bianco del pulsante di vetro al passaggio (--g-tint .14).
        static let passaggioVetro = Color(r: 255, g: 255, b: 255, a: 0.14)
        /// Puntino dell'app aperta nel dock (--wall-ink all'80%).
        static let puntinoDock: Color = Tema.Colore.inchiostroSfondo.opacity(0.8)
        /// Velo della scrivania coperta dal benvenuto o dalle app aperte.
        static let veloPannello = Tema.Colore.velo
        /// Ora del benvenuto: riempimento dall'inchiostro pieno (96%) a metà (52%).
        static let oraAlto: Color = Tema.Colore.inchiostroBenvenuto.opacity(0.96)
        static let oraBasso: Color = Tema.Colore.inchiostroBenvenuto.opacity(0.52)
        /// Simbolo nella manopola del benvenuto.
        static let frecciaManopola = Tema.Colore.inchiostro
        /// Riquadro tratteggiato quando si trascina un file su Prisma.
        static let rilascio = Tema.Colore.accento
        static let rilascioFondo: Color = Tema.Colore.accento.opacity(0.06)

        /// Fondo della finestra del Mac sotto lo sfondo d'acqua (il colore medio del cielo, chiaro o scuro).
        static var fondoFinestraMac: NSColor {
            let chiaro = NSColor(Tema.Colore.cieloChiaro[1])
            let scuro = NSColor(Tema.Colore.cieloScuro[1])
            return NSColor(name: nil) { aspetto in aspetto.prismaScuro ? scuro : chiaro }
        }
    }
}

extension Tema.Misura {
    /// Misure della shell.
    enum Shell {
        // Barra superiore
        static let barraMargineSinistro: CGFloat = 10
        static let barraMargineDestro: CGFloat = 8
        static let barraSpazio: CGFloat = 4
        static let marchioMargine: CGFloat = 10
        static let marchioMargineSinistro: CGFloat = 6
        static let marchioSpazio: CGFloat = 7
        static let orologioSpazio: CGFloat = 9
        static let strumentiMargine: CGFloat = 2
        static let strumentiSpazio: CGFloat = 1
        static let pulsanteBarraMinimo: CGFloat = 28
        static let pulsanteBarraMargine: CGFloat = 8
        static let pulsanteBarraSpazio: CGFloat = 6
        static let tastoMargine = EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)
        static let badgeSpostamento = CGSize(width: 7, height: -6)
        static let filoAvatar: CGFloat = 1

        // Scrivania
        static let scrivaniaAlto: CGFloat = 8
        static let scrivaniaBasso: CGFloat = 4
        static let salutoSpazio: CGFloat = 5
        static let pulsantiSpazio: CGFloat = 8
        static let pulsantiAlto: CGFloat = 26
        static let pulsanteVetroMargine: CGFloat = 15
        static let pulsanteVetroPiccoloMargine: CGFloat = 13
        static let pulsanteVetroSpazio: CGFloat = 7
        /// Pulsante disattivato: più tenue.
        static let opacitaDisabilitato: Double = 0.55
        static let sezioneAlto: CGFloat = 20
        static let sezioneBasso: CGFloat = 10
        static let sezioneLato: CGFloat = 2
        static let piedeAlto: CGFloat = 10
        static let guidaAlto: CGFloat = 12

        // Widget
        /// La fila bassa della bacheca è alta 1,04 volte quella alta (righe 1fr / 64 / 1.04fr del tema).
        static let quotaFilaBassa: CGFloat = 1.04
        /// Gli elenchi sfumano negli ultimi 16 pt.
        static let sfumaturaElenco: CGFloat = 16
        static let barrettaEvento: CGFloat = 4
        static let rigaSpazio: CGFloat = 11
        static let rigaTestoSpazio: CGFloat = 2
        static let testaSpazio: CGFloat = 8
        static let iconaWidget: CGFloat = 20
        static let collegamentoMargine: CGFloat = 11
        static let rigaMargine: CGFloat = 8
        static let colonnaGiorno: CGFloat = 148
        static let colonnaGiornoMargine = EdgeInsets(top: 4, leading: 4, bottom: 6, trailing: 12)
        static let avatarCliente: CGFloat = 46
        static let veloCliente: CGFloat = 120
        static let kpiMargine = EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14)
        static let kpiSpazioRighe: CGFloat = 10
        static let kpiSpazioColonne: CGFloat = 12
        static let clienteSpazio: CGFloat = 10
        static let canaliSpazio: CGFloat = 5
        static let iconaEve: CGFloat = 38
        static let barraCanali: CGFloat = 10
        static let barraCanaliSpazio: CGFloat = 2
        static let quadratinoCanale: CGFloat = 10
        static let colonnaQuota: CGFloat = 38
        static let portafoglioSpazio: CGFloat = 10

        // Dock
        static let divisoreMargine: CGFloat = 6
        static let margineDockLato: CGFloat = 2
        static let etichettaDock: CGFloat = 13
        static let etichettaSpazio: CGFloat = 2
        static let puntinoSpazio: CGFloat = 3
        static let suggerimentoMargine = EdgeInsets(top: 5, leading: 11, bottom: 5, trailing: 11)
        static let suggerimentoDistanza: CGFloat = 10
        /// Luminosità dell'icona premuta (brightness .82).
        static let premutoDock: Double = -0.18
        /// Passaggi per far coincidere l'icona ingrandita con il puntatore.
        static let passiIngrandimento = 3

        // Finestre interne
        static let titoloFinestraSinistra: CGFloat = 96
        static let titoloFinestraDestra: CGFloat = 14
        static let titoloFinestraSpazio: CGFloat = 8
        static let strumentiFinestraSpazio: CGFloat = 6
        static let maniglia: CGFloat = 16
        static let manigliaMargine: CGFloat = 4
        /// La barra del titolo è piena fino a qui, poi sfuma nel contenuto.
        static let titoloPieno: CGFloat = 0.58

        // Le tue app aperte
        static let appAperteLarghezza: CGFloat = 760
        static let appAperteAltezza: CGFloat = 560
        static let appAperteBordo: CGFloat = 16
        static let appAperteMargine: CGFloat = 20
        static let appAperteSpazio: CGFloat = 12
        static let schedaAppMinima: CGFloat = 150
        static let schedaAppMargine = EdgeInsets(top: 18, leading: 10, bottom: 14, trailing: 10)
        static let schedaAppSpazio: CGFloat = 4

        // Benvenuto
        static let benvenutoAlto: CGFloat = 0.08
        static let benvenutoBasso: CGFloat = 0.05
        static let benvenutoLato: CGFloat = 24
        static let oraMinima: CGFloat = 96
        static let oraMassima: CGFloat = 188
        static let oraQuota: CGFloat = 0.16
        static let logoBenvenuto: CGFloat = 52
        static let marchioBenvenutoSpazio: CGFloat = 8
        static let cursoreBenvenuto = CGSize(width: 340, height: 60)
        static let cursoreMargine: CGFloat = 5
        static let manopola: CGFloat = 50
        static let manopolaTrascinata: CGFloat = 58
        static let frecciaManopola: CGFloat = 16
        static let sbloccoSpazio: CGFloat = 12
        static let marchioSblocco: CGFloat = 28
        /// Oltre questa parte della corsa il cursore apre.
        static let sogliaBenvenuto: CGFloat = 0.8

        // Impostazioni: il logo con il nome nel riquadro delle informazioni
        static let logoImpostazioni: CGFloat = 30

        // Trascinamento dei file
        static let rilascioTratto: CGFloat = 3
        static let rilascioTrattino: [CGFloat] = [8, 5]
    }
}

extension Tema.Testo {
    /// Caratteri della shell.
    enum Shell {
        static let tastoBarra = Tema.Testo.sf(10.5, .medium)
        static let pulsanteBarra = Tema.Testo.sf(12.5, .medium)
        static let simboloBarra = Tema.Testo.sf(14, .medium)
        static let avatarBarra = Tema.Testo.sf(10, .bold, arrotondato: true)
        static let orologio = Tema.Testo.sf(13, .medium).monospacedDigit()
        static let spaziaturaMarchio = Tema.Testo.spaziatura(-0.01, 13)
        static let simboloPulsante = Tema.Testo.sf(13, .medium)
        static let piede = Tema.Testo.sf(12)
        // Widget
        static let collegamento = Tema.Testo.sf(12, .semibold)
        static let giornoSettimana = Tema.Testo.sf(14, .semibold)
        static let meseAgenda = Tema.Testo.sf(14)
        static let riepilogoAgenda = Tema.Testo.sf(12)
        static let riepilogoAgendaForte = Tema.Testo.sf(13, .semibold)
        static let occhielloCliente = Tema.Testo.sf(11.5, .medium)
        static let temaCliente = Tema.Testo.sf(12.5)
        static let spaziaturaNomeCliente = Tema.Testo.spaziatura(-0.015, 18)
        static let etichettaKpi = Tema.Testo.sf(11.5)
        static let spaziaturaKpi = Tema.Testo.spaziatura(-0.01, 16)
        static let notaCliente = Tema.Testo.sf(12.5)
        static let titoloEve = Tema.Testo.sf(14, .semibold)
        static let testoEve = Tema.Testo.sf(12)
        static let chevron = Tema.Testo.sf(12, .semibold)
        static let nomeRiga = Tema.Testo.sf(13, .semibold)
        static let secondarioRiga = Tema.Testo.sf(12)
        // Dock
        static let etichettaDock = Tema.Testo.sf(10, .medium)
        static let suggerimentoDock = Tema.Testo.sf(12, .semibold)
        // Finestre
        static let contestoFinestra = Tema.Testo.sf(12, .medium)
        // App aperte
        static let nomeAppAperta = Tema.Testo.sf(13, .semibold)
        static let contestoAppAperta = Tema.Testo.sf(12)
        static let statoAppAperta = Tema.Testo.sf(11.5)
        // Benvenuto
        static let dataBenvenuto = Tema.Testo.sf(22, .semibold)
        static let nomeBenvenuto = Tema.Testo.sf(20, .bold)
        static let mottoBenvenuto = Tema.Testo.sf(13)
        static let scorriBenvenuto = Tema.Testo.sf(15, .medium)
        static let entraBenvenuto = Tema.Testo.sf(13)
        static let notaBenvenuto = Tema.Testo.sf(11.5)
        static let frecciaManopola = Font.system(size: Tema.Misura.Shell.frecciaManopola, weight: .semibold)
        /// L'ora grande del benvenuto: segue la larghezza della finestra (clamp del tema), arrotondata.
        static func oraBenvenuto(_ corpo: CGFloat) -> Font {
            Font.system(size: corpo, weight: .bold, design: .rounded).monospacedDigit()
        }
        static func spaziaturaOra(_ corpo: CGFloat) -> CGFloat { -0.035 * corpo }
    }
}

extension Tema.Ombra {
    /// Ombre della shell.
    enum Shell {
        static let avatarBarra = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.25), y: 1, sfocatura: 3)
        static let dataBenvenuto = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.18), y: 1, sfocatura: 14)
        static let oraBenvenuto = StratoOmbra(colore: Color(r: 30, g: 20, b: 90, a: 0.22), y: 2, sfocatura: 18)
        static let appAperte = StratoOmbra(colore: Color(r: 0, g: 0, b: 0, a: 0.28), y: 20, sfocatura: 50)
    }
}

extension Tema.Moto {
    /// Animazioni della shell.
    enum Shell {
        /// Il dock torna alla misura normale quando il puntatore se ne va (.2 s --out).
        static let ritornoDock = Tema.Moto.uscita(0.2)
        /// Luccichio della scritta «scorri per entrare».
        static let luccichio = Animation.linear(duration: 3.2).repeatForever(autoreverses: false)
        /// La manopola del benvenuto torna indietro.
        static let ritornoManopola = Tema.Moto.molla
    }
}
