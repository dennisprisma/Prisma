#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

// MARK: - Gettoni dei componenti di base (tema Liquid Glass)

extension Tema.Colore {
    /// Colori dei componenti di base che non stanno tra i gettoni comuni del tema.
    enum Componenti {
        /// Testo e simboli sui fondi pieni (accento, rosso) e iniziali degli avatar.
        static let testoSuColore = Color.white
        /// Filo di luce in alto sui pulsanti pieni (inset 0 1px 0 rgba(255,255,255,.35)).
        static let luceSuColore = Color(r: 255, g: 255, b: 255, a: 0.35)
        /// Avatar: filo chiaro in alto e ombra interna in basso.
        static let luceAvatar = Color(r: 255, g: 255, b: 255, a: 0.5)
        static let ombraBassoAvatar = Color(r: 0, g: 0, b: 0, a: 0.15)
        /// Tinte degli avatar del tema (radiale dal chiaro allo scuro).
        static let avatarBluAlto = Color(hex: "#A3BEDF")
        static let avatarBluBasso = Color(hex: "#4C72A8")
        static let avatarRosaAlto = Color(hex: "#E4AEB9")
        static let avatarRosaBasso = Color(hex: "#B0687A")
        static let avatarVerdeAlto = Color(hex: "#A5CDB5")
        static let avatarVerdeBasso = Color(hex: "#4B8566")
        static let avatarViolaAlto = Color(hex: "#BCB0D8")
        static let avatarViolaBasso = Color(hex: "#6E62A0")
        static let avatarOroAlto = Color(hex: "#E2CC98")
        static let avatarOroBasso = Color(hex: "#A9853C")
        /// Contorno del badge (0 0 0 1.5px rgba(255,255,255,.75)).
        static let bordoBadge = Color(r: 255, g: 255, b: 255, a: 0.75)
        /// Contorno del pomello dell'interruttore (0 0 0 .5px rgba(0,0,0,.05)).
        static let bordoPomello = Color(r: 0, g: 0, b: 0, a: 0.05)
        /// Fondo delle pillole d'errore (rosso 15%).
        static let fondoErrore: Color = Tema.Colore.rosso.opacity(0.15)
        /// Punto finale dei grafici: bianco in chiaro, colore della finestra in scuro.
        static let puntoGrafico = Color.dinamico(chiaro: .white, scuro: Color(r: 18, g: 29, b: 38, a: 1))
        /// Icona Agenda: la piastrella è sempre bianca, mese rosso e giorno quasi nero.
        static let meseIconaAgenda = Color(hex: "#E0443A")
        static let giornoIconaAgenda = Color(hex: "#1C1C1E")
        static let ombraIconaAgenda = Color(r: 0, g: 0, b: 0, a: 0.22)
        /// Etichette dei canali sui documenti (PDF e anteprime su carta): colori opachi e fissi.
        static let fondoCanaleAlleanzaStampa = Color(hex: "#E1E9FC")
        static let fondoCanaleIndipendenteStampa = Color(hex: "#F2E8D9")
        static let bordoCanaleAlleanzaStampa = Color(hex: "#9DB9F6")
        static let bordoCanaleIndipendenteStampa = Color(hex: "#DCBE94")
        static let testoCanaleStampa = Color(hex: "#1C2733")
    }
}

extension Tema.Misura {
    /// Misure dei componenti di base.
    enum Componenti {
        /// Le tre taglie dei pulsanti in capsula (l'altezza la decide la taglia, non i margini):
        /// compatta 28 (.btn.sm, dentro le righe), normale 32 (.btn), grande 36 (stati vuoti e guide).
        static let pulsanteMinimo: CGFloat = 28
        static let pulsanteNormale: CGFloat = 32
        static let pulsanteGrande: CGFloat = 36
        /// Margine laterale minimo del testo dentro una capsula, per taglia (`margineCapsula` = compatta).
        static let margineCapsula: CGFloat = 12
        static let margineLatoCompatto: CGFloat = 12
        static let margineLatoNormale: CGFloat = 14
        static let margineLatoGrande: CGFloat = 18
        /// Spazio fra l'icona e la scritta di un pulsante (gap 7 del .btn del tema).
        static let spazioSimboloPulsante: CGFloat = 7
        /// Il bersaglio più piccolo ammesso (anche croci e «i»), e il lato dei pulsanti solo icona.
        #if os(iOS)
        /// Sull'iPad e sull'iPhone il bersaglio più piccolo è l'area di tocco (44 pt).
        static let areaClicMinima: CGFloat = Tema.Misura.Mobile.areaTocco
        #elseif os(macOS)
        static let areaClicMinima: CGFloat = 28
        #endif
        static let pulsanteIcona: CGFloat = 32
        /// Quanto si allarga l'area di clic di un'icona da 22 pt dentro una riga densa (22 + 2 × 3 = 28),
        /// senza alzare la riga: `.contentShape(Rectangle().inset(by: -allargamentoClic))`.
        static let allargamentoClic: CGFloat = 3
        /// Controllo a segmenti (.segc): altezza, margine delle voci (normale e compatto) e del cursore.
        static let segmenti: CGFloat = 32
        static let margineSegmento: CGFloat = 14
        static let margineSegmentoCompatto: CGFloat = 9
        static let margineCursore: CGFloat = 2
        /// Badge sulle icone (quello della barra è `Tema.Misura.badge`).
        static let badgeGrande: CGFloat = 18
        static let bordoBadge: CGFloat = 1.5
        static let margineBadge: CGFloat = 4
        /// Tessera della data (.dt).
        static let tesseraData = CGSize(width: 40, height: 44)
        /// Avviso temporaneo (.toast).
        static let avviso = EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
        /// La sfera di Eve nel suo commiato (.toast .orb.sm: 17 px) e lo spazio prima del testo.
        static let sferaAvviso: CGFloat = 17
        static let spazioSferaAvviso: CGFloat = 9
        /// Campo di testo (.field): margine laterale, altezza minima e margine verticale.
        static let margineCampo: CGFloat = 12
        static let campoPiccolo: CGFloat = 32
        static let margineCampoVerticale: CGFloat = 7
        /// Icona Agenda, in 256esimi del lato: centro del mese e del giorno.
        static let meseIconaAgenda = CGPoint(x: 128, y: 68.9)
        static let giornoIconaAgenda = CGPoint(x: 128, y: 151.6)
        /// Icona Agenda, in frazioni del lato: spaziatura del mese e del giorno, ombra del giorno.
        static let spaziaturaMeseIconaAgenda: CGFloat = 0.0123
        static let spaziaturaGiornoIconaAgenda: CGFloat = -0.0146
        static let ombraIconaAgendaRaggio: CGFloat = 0.0094
        static let ombraIconaAgendaY: CGFloat = 0.0141
        /// Etichetta del canale sui documenti: margini, simbolo Alleanza e pallino.
        static let etichettaStampa = EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 9)
        static let etichettaStampaCompatta = EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 7)
        static let simboloStampa: CGFloat = 11
        static let simboloStampaCompatto: CGFloat = 9
        static let pallinoStampa: CGFloat = 6
        static let spazioStampa: CGFloat = 5
        static let bordoStampa: CGFloat = 0.75
    }
}

extension Tema.Testo {
    /// Caratteri dei componenti di base.
    enum Componenti {
        static let segmento = Tema.Testo.sf(13, .medium)
        static let segmentoAttivo = Tema.Testo.sf(13, .semibold)
        static let segmentoCompatto = Tema.Testo.sf(12.5, .medium)
        static let segmentoCompattoAttivo = Tema.Testo.sf(12.5, .semibold)
        /// Numero dentro il badge da 18 pt: resta fuori dalla scala leggibile.
        static let badgeGrande = Tema.Testo.sfFisso(11, .bold)
        /// Icona SF dei pulsanti (davanti alla scritta, o da sola).
        static let simboloPulsante = Font.system(size: 13 * Tipo.fattore, weight: .semibold)
        static let avviso = Tema.Testo.sf(13, .medium)
        /// Mese e giorno sull'icona Agenda, in proporzione al lato.
        static func meseIconaAgenda(_ lato: CGFloat) -> Font { .system(size: lato * 0.1538, weight: .bold) }
        static func giornoIconaAgenda(_ lato: CGFloat) -> Font { .system(size: lato * 0.4395, weight: .light) }
    }
}

extension Tema.Ombra {
    /// Ombre dei componenti di base.
    enum Componenti {
        /// Pulsante pieno (accento o rosso): 0 3px 10px -3px, l'espansione negativa resa con meno sfocatura.
        static let pulsantePieno = StratoOmbra(colore: Tema.Colore.accento.opacity(0.45), y: 3, sfocatura: 8)
        static let pulsanteRosso = StratoOmbra(colore: Tema.Colore.rosso.opacity(0.45), y: 3, sfocatura: 8)
    }
}

// MARK: - Pezzi comuni

/// Filo interno di 1 pt lungo il bordo alto (spostamento 1) o basso (-1) di una forma, come `inset 0 ±1px 0`:
/// si riempie con lo stile pari-dispari e si taglia alla forma.
struct FiloInterno: Shape {
    let forma: FormaVetro
    var spostamento: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        var p = forma.path(in: rect)
        p.addPath(forma.path(in: rect.offsetBy(dx: 0, dy: spostamento)))
        return p
    }
}

/// Fondo che compare al passaggio del mouse (righe, voci laterali, schede), oppure quello della selezione.
struct FondoPassaggio: ViewModifier {
    let forma: FormaVetro
    let sopra: Color
    let selezionata: Bool
    let selezione: Color
    @State private var passaggio = false

    init(forma: FormaVetro, sopra: Color, selezionata: Bool, selezione: Color) {
        self.forma = forma
        self.sopra = sopra
        self.selezionata = selezionata
        self.selezione = selezione
    }

    func body(content: Content) -> some View {
        content
            .background {
                forma.fill(selezionata ? selezione : (passaggio ? sopra : Color.clear))
                    .allowsHitTesting(false)
            }
            .onHover { passaggio = $0 }
    }
}

extension View {
    /// Fondo al passaggio del mouse (`--chip` del tema) o della selezione (accento 17%).
    func fondoPassaggio(_ forma: FormaVetro,
                        sopra: Color = Tema.Colore.chip,
                        selezionata: Bool = false,
                        selezione: Color = Tema.Colore.selezione) -> some View {
        modifier(FondoPassaggio(forma: forma, sopra: sopra, selezionata: selezionata, selezione: selezione))
    }
}

// MARK: - Pulsanti

/// Le tre misure dei pulsanti in capsula: l'altezza la decide la taglia, non i margini.
enum TagliaPulsante {
    /// 36 pt: l'azione unica di uno stato vuoto o di una guida («Scegli i file…», «Comincia»).
    case grande
    /// 32 pt (.btn del tema): intestazioni, barre, dettagli.
    case normale
    /// 28 pt (.btn.sm): dentro le righe di elenchi e tabelle («Completa», «Fissa»).
    case compatta

    var altezza: CGFloat {
        switch self {
        case .grande: return Tema.Misura.Componenti.pulsanteGrande
        case .normale: return Tema.Misura.Componenti.pulsanteNormale
        case .compatta: return Tema.Misura.Componenti.pulsanteMinimo
        }
    }

    var margineLato: CGFloat {
        switch self {
        case .grande: return Tema.Misura.Componenti.margineLatoGrande
        case .normale: return Tema.Misura.Componenti.margineLatoNormale
        case .compatta: return Tema.Misura.Componenti.margineLatoCompatto
        }
    }

    /// Il carattere della scritta: il primario (blu o rosso) in semibold.
    func carattere(primario: Bool) -> Font {
        switch self {
        case .grande: return Tema.Testo.pulsanteGrande
        case .normale: return primario ? Tema.Testo.pulsantePrimario : Tema.Testo.pulsante
        case .compatta: return primario ? Tema.Testo.pulsantePrimarioPiccolo : Tema.Testo.pulsantePiccolo
        }
    }
}

/// Aspetto dei pulsanti in capsula del tema.
enum AspettoPulsante {
    /// `.btn`: capsula di vetro chiaro, testo inchiostro.
    case vetro
    /// Vetro con testo e icona del colore dei collegamenti: l'azione consigliata di un pannello, senza un secondo blu.
    case vetroAccento
    /// `.btn.primary`: capsula piena dell'accento, testo bianco. Uno solo per finestra.
    case principale
    /// Capsula piena rossa (il microfono di Eve mentre ascolta).
    case rosso
}

private struct ChiavePulsantiSoloIcona: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Nelle barre strette i pulsanti di vetro mostrano solo l'icona delle loro `Label` (il blu tiene sempre
    /// la scritta). Chi mette una `Label` in una barra che si può stringere aggiunge `.help("…")`.
    var pulsantiSoloIcona: Bool {
        get { self[ChiavePulsantiSoloIcona.self] }
        set { self[ChiavePulsantiSoloIcona.self] = newValue }
    }
}

/// Icona SF e scritta dei pulsanti (gap 7 del tema). Una `Label` dentro un pulsante di Prisma prende questo stile.
///
///     Button { nuova() } label: { Label("Nuova attività", systemImage: "plus") }.buttonStyle(StileBlu())
struct EtichettaPulsante: LabelStyle {
    var soloIcona = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Tema.Misura.Componenti.spazioSimboloPulsante) {
            configuration.icon
                .font(Tema.Testo.Componenti.simboloPulsante)
                .imageScale(.medium)
            if !soloIcona {
                configuration.title
            }
        }
    }
}

/// Il corpo comune dei pulsanti in capsula: riempimento, passaggio del mouse e pressione a molla.
/// L'altezza è quella della taglia (o `altezza`, se più alta); i margini verticali non contano più.
struct CorpoPulsante<Etichetta: View>: View {
    let etichetta: Etichetta
    let aspetto: AspettoPulsante
    let premuto: Bool
    let margine: EdgeInsets
    let taglia: TagliaPulsante
    /// Altezza minima in più rispetto alla taglia (nil: quella della taglia).
    let altezza: CGFloat?
    @State private var sopra = false
    @Environment(\.isEnabled) private var abilitato
    @Environment(\.chipDelTema) private var chipDelTema
    @Environment(\.pulsantiSoloIcona) private var soloIcona

    init(etichetta: Etichetta, aspetto: AspettoPulsante, premuto: Bool, margine: EdgeInsets,
         taglia: TagliaPulsante = .compatta, altezza: CGFloat? = nil) {
        self.etichetta = etichetta
        self.aspetto = aspetto
        self.premuto = premuto
        self.margine = margine
        self.taglia = taglia
        self.altezza = altezza
    }

    private var primario: Bool { aspetto == .principale || aspetto == .rosso }

    private var coloreTesto: Color {
        switch aspetto {
        case .vetro: return Tema.Colore.inchiostro
        case .vetroAccento: return Tema.Colore.link
        case .principale, .rosso: return Tema.Colore.Componenti.testoSuColore
        }
    }

    var body: some View {
        // Una riga sola e mai più stretta del testo: nessun pulsante va a capo lettera per lettera.
        // Chi riempie la sua cella (`.frame(maxWidth: .infinity)` nell'etichetta) continua a riempirla.
        let base = LarghezzaAlmenoIdeale().callAsFunction { etichetta.lineLimit(1) }
            .labelStyle(EtichettaPulsante(soloIcona: soloIcona && !primario))
            .font(taglia.carattere(primario: primario))
            .foregroundColor(coloreTesto)
            .padding(.leading, max(margine.leading, taglia.margineLato))
            .padding(.trailing, max(margine.trailing, taglia.margineLato))
            // Con «Molto grande» il testo cresce e il pulsante con lui: minHeight, mai un'altezza fissa
            .frame(minHeight: max(taglia.altezza, altezza ?? 0))
        let alPassaggio: Color = chipDelTema ? Tema.Colore.chipSopra : Tema.Colore.chipControlloSopra
        Group {
            switch aspetto {
            case .vetro, .vetroAccento:
                base.vetro(.chip, forma: .capsula, riempimento: sopra ? alPassaggio : nil, interattivo: true)
            case .principale, .rosso:
                base.background { pieno }
            }
        }
        #if os(iOS)
        // Al tocco il bersaglio è alto almeno 44 pt, anche se la capsula disegnata resta della sua taglia
        .contentShape(RettangoloTocco(altezza: max(taglia.altezza, altezza ?? 0), ancheLati: true))
        #elseif os(macOS)
        .contentShape(FormaVetro.capsula)
        #endif
        .scaleEffect(premuto ? Tema.Moto.scalaPressione : 1)
        .animation(Tema.Moto.molla, value: premuto)
        .opacity(abilitato ? 1 : 0.55)
        .onHover { sopra = $0 }
    }

    /// Capsula piena con il filo di luce in alto e l'ombra colorata (solo sotto la forma piena, non sul testo).
    private var pieno: some View {
        let rosso = aspetto == .rosso
        let colore: Color = rosso ? Tema.Colore.rosso : (sopra ? Tema.Colore.accentoSopra : Tema.Colore.accento)
        let ombra = rosso ? Tema.Ombra.Componenti.pulsanteRosso : Tema.Ombra.Componenti.pulsantePieno
        return FormaVetro.capsula
            .fill(colore)
            .overlay {
                FiloInterno(forma: .capsula)
                    .fill(Tema.Colore.Componenti.luceSuColore, style: FillStyle(eoFill: true))
                    .clipShape(FormaVetro.capsula)
            }
            .ombraTema(ombra)
    }
}

/// Contenitore di una sola vista che non la lascia mai più stretta della sua larghezza ideale (come
/// `fixedSize` in orizzontale), ma la lascia allargare quando lo spazio c'è e lei lo chiede.
struct LarghezzaAlmenoIdeale: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let vista = subviews.first else { return .zero }
        let ideale = vista.sizeThatFits(.unspecified).width
        let larghezza = max(ideale, proposal.width ?? ideale)
        return vista.sizeThatFits(ProposedViewSize(width: larghezza, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let vista = subviews.first else { return }
        vista.place(at: bounds.origin, anchor: .topLeading,
                    proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

/// Pulsante di vetro (.btn del tema): capsula chiara traslucida, più chiara al passaggio, molla alla pressione.
/// `accento`: testo e icona del colore dei collegamenti, per l'azione consigliata di un pannello (mai un secondo blu).
struct StileVetro: ButtonStyle {
    var margine: EdgeInsets
    var taglia: TagliaPulsante
    var accento: Bool

    /// Pulsante di vetro normale (32 pt).
    init(taglia: TagliaPulsante = .normale, accento: Bool = false) {
        self.margine = Misure.Pulsante.vetroMargine
        self.taglia = taglia
        self.accento = accento
    }

    /// Con margini propri: compatto (28 pt) se non si dice altro. Dei margini contano solo quelli laterali.
    init(margine: EdgeInsets, taglia: TagliaPulsante = .compatta, accento: Bool = false) {
        self.margine = margine
        self.taglia = taglia
        self.accento = accento
    }

    func makeBody(configuration: Configuration) -> some View {
        CorpoPulsante(etichetta: configuration.label, aspetto: accento ? .vetroAccento : .vetro,
                      premuto: configuration.isPressed, margine: margine, taglia: taglia)
    }
}

/// Pulsante principale (.btn.primary): capsula piena del colore d'accento, testo bianco semibold.
/// Uno solo per finestra: «il blu è la cosa da fare qui».
struct StileBlu: ButtonStyle {
    var taglia: TagliaPulsante = .normale

    func makeBody(configuration: Configuration) -> some View {
        CorpoPulsante(etichetta: configuration.label, aspetto: .principale, premuto: configuration.isPressed,
                      margine: Misure.Pulsante.bluMargine, taglia: taglia)
    }
}

/// Il pulsante del microfono di Eve: accento come gli altri, rosso mentre Eve ascolta.
struct StileMicrofono: ButtonStyle {
    let acceso: Bool

    func makeBody(configuration: Configuration) -> some View {
        CorpoPulsante(etichetta: configuration.label, aspetto: acceso ? .rosso : .principale,
                      premuto: configuration.isPressed, margine: Misure.Pulsante.bluMargine, taglia: .normale)
    }
}

/// Azione terziaria: testo del colore dei collegamenti, semibold, con la freccia; area di clic di almeno 28 pt.
/// Per la freccia in coda: `HStack { Text("Nel Portafoglio"); Image(systemName: "chevron.right") }`.
struct StileCollegamento: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(EtichettaPulsante())
            .font(Tema.Testo.collegamento)
            .foregroundColor(Tema.Colore.link)
            .lineLimit(1)
            .frame(minHeight: Tema.Misura.Componenti.areaClicMinima)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Pulsante con la sola icona (croci, frecce, «＋» delle colonne, «⋯»): capsula di vetro tonda, o soltanto
/// l'icona con un cerchio al passaggio (`vetro: false`). L'area di clic è sempre di 28 (compatta) o 32 pt;
/// l'aiuto fa da suggerimento e da etichetta per VoiceOver.
struct PulsanteIcona: View {
    let simbolo: String
    let aiuto: String
    var taglia: TagliaPulsante = .normale
    /// false: niente vetro, solo l'icona (croci nelle righe); l'area di clic resta piena.
    var vetro = true
    let azione: () -> Void

    var body: some View {
        let m = Tema.Misura.Componenti.self
        let lato: CGFloat = taglia == .compatta ? m.areaClicMinima : m.pulsanteIcona
        Button(action: azione) {
            Image(systemName: simbolo)
                .font(Tema.Testo.Componenti.simboloPulsante)
                .imageScale(.medium)
                .foregroundColor(vetro ? Tema.Colore.inchiostro : Tema.Colore.inchiostroSecondario)
                .frame(width: lato, height: lato)
                .contentShape(Circle())
        }
        .buttonStyle(StileIconaTonda(vetro: vetro))
        .help(aiuto)
        .accessibilityLabel(aiuto)
    }
}

/// Lo stile di `PulsanteIcona`: vetro tondo (come i pulsanti di vetro) oppure trasparente con un cerchio
/// al passaggio; molla alla pressione come `CorpoPulsante`.
struct StileIconaTonda: ButtonStyle {
    let vetro: Bool

    func makeBody(configuration: Configuration) -> some View {
        CorpoIconaTonda(etichetta: configuration.label, vetro: vetro, premuto: configuration.isPressed)
    }
}

struct CorpoIconaTonda<Etichetta: View>: View {
    let etichetta: Etichetta
    let vetro: Bool
    let premuto: Bool
    @State private var sopra = false
    @Environment(\.isEnabled) private var abilitato
    @Environment(\.chipDelTema) private var chipDelTema

    init(etichetta: Etichetta, vetro: Bool, premuto: Bool) {
        self.etichetta = etichetta
        self.vetro = vetro
        self.premuto = premuto
    }

    var body: some View {
        let alPassaggio: Color = chipDelTema ? Tema.Colore.chipSopra : Tema.Colore.chipControlloSopra
        Group {
            if vetro {
                etichetta.vetro(.chip, forma: .capsula, riempimento: sopra ? alPassaggio : nil, interattivo: true)
            } else {
                etichetta.background {
                    Circle().fill(sopra ? Tema.Colore.chip : Color.clear).allowsHitTesting(false)
                }
            }
        }
        .contentShape(Circle())
        .scaleEffect(premuto ? Tema.Moto.scalaPressione : 1)
        .animation(Tema.Moto.molla, value: premuto)
        .opacity(abilitato ? 1 : 0.55)
        .onHover { sopra = $0 }
    }
}

/// Pulsante senza decorazioni che si scurisce appena alla pressione.
struct StileSemplice: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Campo di testo

/// Campo di testo del tema (.field): pozzetto arrotondato con un filo sottile, testo inchiostro.
///
///     TextField("Nome", text: $nome).campoTesto()
struct CampoTesto: ViewModifier {
    func body(content: Content) -> some View {
        let m = Tema.Misura.Componenti.self
        let forma = FormaVetro.arrotondata(m.campoPiccolo / 2)
        return content
            .textFieldStyle(.plain)
            .font(Tema.Testo.corpo)
            .foregroundColor(Tema.Colore.inchiostro)
            .padding(.horizontal, m.margineCampo)
            .padding(.vertical, m.margineCampoVerticale)
            .frame(minHeight: m.campoPiccolo)
            .background { forma.fill(Tema.Colore.pozzetto) }
            .overlay { forma.strokeBorder(Tema.Colore.separatore, lineWidth: Tema.Misura.filo).allowsHitTesting(false) }
    }
}

extension View {
    /// Il campo di testo di Prisma (.field del tema).
    func campoTesto() -> some View { modifier(CampoTesto()) }
}

// MARK: - Controllo a segmenti

/// Controllo a segmenti del tema (.segc): pozzetto in capsula e cursore chiaro che scorre a molla
/// sotto la voce scelta. Base di Segmentato, SegmentiAnalisi, SchedeApp, SchedeRisultati e SchedeRubrica.
/// Si anima solo il controllo: il contenuto che cambia con la scelta compare di colpo, come sul Mac.
struct ControlloSegmenti<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore
    /// true: voci di larghezza uguale che riempiono lo spazio; false: larghe quanto il testo.
    let riempi: Bool
    /// Voci più strette e testo più piccolo (finestre strette).
    let compatto: Bool
    let altezza: CGFloat
    @Namespace private var spazio

    init(opzioni: [(Valore, String)], selezione: Binding<Valore>, riempi: Bool = false, compatto: Bool = false,
         altezza: CGFloat = Tema.Misura.Componenti.segmenti) {
        self.opzioni = opzioni
        self._selezione = selezione
        self.riempi = riempi
        self.compatto = compatto
        self.altezza = altezza
    }

    var body: some View {
        let m = Tema.Misura.Componenti.self
        HStack(spacing: 0) {
            ForEach(Array(opzioni.enumerated()), id: \.offset) { _, opzione in
                voce(opzione)
            }
        }
        .animation(Movimenti.curva(Tema.Moto.Controlli.segmenti), value: selezione)
        .padding(m.margineCursore)
        .frame(height: altezza)
        .background { FormaVetro.capsula.fill(Tema.Colore.pozzetto) }
        .overlay {
            FormaVetro.capsula.strokeBorder(Tema.Colore.separatore, lineWidth: Tema.Misura.filo).allowsHitTesting(false)
        }
    }

    private func voce(_ opzione: (Valore, String)) -> some View {
        let attiva = opzione.0 == selezione
        let t = Tema.Testo.Componenti.self
        let carattere: Font = compatto ? (attiva ? t.segmentoCompattoAttivo : t.segmentoCompatto)
                                       : (attiva ? t.segmentoAttivo : t.segmento)
        return Button {
            selezione = opzione.0
        } label: {
            Text(opzione.1)
                .font(carattere)
                .foregroundColor(attiva ? Tema.Colore.inchiostro : Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
                .padding(.horizontal, compatto ? Tema.Misura.Componenti.margineSegmentoCompatto : Tema.Misura.Componenti.margineSegmento)
                .frame(maxWidth: riempi ? .infinity : nil, maxHeight: .infinity)
                .background {
                    if attiva {
                        FormaVetro.capsula
                            .fill(Tema.Colore.cursore)
                            .overlay { FormaVetro.capsula.strokeBorder(Tema.Colore.bordoChip, lineWidth: Tema.Misura.filo) }
                            .ombraTema(Tema.Ombra.cursore)
                            .matchedGeometryEffect(id: "cursore", in: spazio)
                    }
                }
                #if os(iOS)
                // Al tocco la voce è alta almeno 44 pt (in verticale: le voci vicine non si rubano il tocco)
                .contentShape(RettangoloTocco(altezza: altezza, ancheLati: false))
                #elseif os(macOS)
                .contentShape(Rectangle())
                #endif
        }
        .buttonStyle(StileSemplice())
    }
}

/// Controllo a segmenti a larghezza piena (filtri delle app).
struct Segmentato<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore

    var body: some View {
        ControlloSegmenti(opzioni: opzioni, selezione: $selezione, riempi: true)
    }
}

// MARK: - Badge

/// Badge rosso del tema con il numero (app e notifiche), con il contorno chiaro.
struct Badge: View {
    let numero: Int
    var grande = true

    var body: some View {
        let lato = grande ? Tema.Misura.Componenti.badgeGrande : Tema.Misura.badge
        let bordo = Tema.Misura.Componenti.bordoBadge
        Text("\(numero)")
            .font(grande ? Tema.Testo.Componenti.badgeGrande : Tema.Testo.badge)
            .foregroundColor(Tema.Colore.Componenti.testoSuColore)
            .padding(.horizontal, numero > 9 ? Tema.Misura.Componenti.margineBadge : 0)
            .frame(minWidth: lato, minHeight: lato)
            .background { FormaVetro.capsula.fill(Tema.Colore.rosso) }
            .overlay {
                FormaVetro.capsula.inset(by: -bordo / 2)
                    .stroke(Tema.Colore.Componenti.bordoBadge, lineWidth: bordo)
            }
            .fixedSize()
    }
}

// MARK: - Avatar

extension Colori.Avatar.Tinta {
    /// I colori del tema per questa tinta (radiale dal chiaro allo scuro): `Colori.Avatar` ha già le tinte
    /// del tema. (Il confronto sul colore delle iniziali, ora bianche per tutte, le faceva diventare tutte blu.)
    var coloriTema: (alto: Color, basso: Color) {
        (alto, basso)
    }
}

/// Avatar del cliente (.av): cerchio con radiale a 30% 18%, iniziali bianche arrotondate, fili di luce.
struct AvatarCliente: View {
    let iniziali: String
    let tinta: Colori.Avatar.Tinta
    var lato: CGFloat = Misure.Colonna.avatar

    var body: some View {
        let colori = tinta.coloriTema
        Text(iniziali)
            .font(Tema.Testo.avatar(lato))
            .foregroundColor(Tema.Colore.Componenti.testoSuColore)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: lato, height: lato)
            .background {
                Circle()
                    .fill(RadialGradient(colors: [colori.alto, colori.basso], center: UnitPoint(x: 0.3, y: 0.18),
                                         startRadius: 0, endRadius: lato * 1.2))
                    .ombraTema(Tema.Ombra.avatar)
            }
            .overlay {
                ZStack {
                    FiloInterno(forma: .capsula, spostamento: 1)
                        .fill(Tema.Colore.Componenti.luceAvatar, style: FillStyle(eoFill: true))
                    FiloInterno(forma: .capsula, spostamento: -1)
                        .fill(Tema.Colore.Componenti.ombraBassoAvatar, style: FillStyle(eoFill: true))
                }
                .clipShape(Circle())
                .allowsHitTesting(false)
            }
    }
}

// MARK: - Tessera della data

/// Tessera della data (.dt): mese rosso in maiuscolo, giorno arrotondato.
struct PiastrellaData: View {
    let data: Date

    var body: some View {
        let misura = Tema.Misura.Componenti.tesseraData
        let forma = FormaVetro.arrotondata(Tema.Raggio.tesseraData)
        VStack(spacing: 0) {
            Text(Formati.meseBreve.string(from: data).uppercased())
                .font(Tema.Testo.meseTessera)
                .tracking(Tema.Testo.spaziatura(0.04, 9.5))
                .foregroundColor(Tema.Colore.rosso)
            Text(Formati.giorno.string(from: data))
                .font(Tema.Testo.giornoTessera)
                .foregroundColor(Tema.Colore.inchiostro)
        }
        .frame(width: misura.width, height: misura.height)
        .background { forma.fill(Tema.Colore.tesseraData).ombraTema(Tema.Ombra.tesseraData) }
        .overlay { forma.strokeBorder(Tema.Colore.bordoChip, lineWidth: Tema.Misura.filo).allowsHitTesting(false) }
    }
}

// MARK: - Etichetta del canale

private struct ChiaveEtichetteStampa: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// true sui documenti (PDF e anteprime su carta): `EtichettaCanale` diventa l'etichetta opaca da stampa.
    ///
    ///     paginaDelDocumento.environment(\.etichetteStampa, true)
    var etichetteStampa: Bool {
        get { self[ChiaveEtichetteStampa.self] }
        set { self[ChiaveEtichetteStampa.self] = newValue }
    }
}

/// Canale di una posizione o di una proposta: sempre riconoscibile a colpo d'occhio.
/// Nelle schermate è la capsula in vetro del tema (blu con il simbolo Alleanza, cuoio con la scritta
/// «Denis Vicenzoni · Consulenza finanziaria»; compatta: pallino e una parola). Sui documenti, con
/// `\.etichetteStampa` a true, è `EtichettaCanaleStampa`.
struct EtichettaCanale: View {
    let canale: Canale
    var compatta = false
    @Environment(\.etichetteStampa) private var stampa

    var body: some View {
        if stampa {
            EtichettaCanaleStampa(canale: canale, compatta: compatta)
        } else {
            CapsulaCanale(canale: canale, compatta: compatta, completa: !compatta)
        }
    }
}

/// Etichetta del canale per i documenti su carta bianca (PDF e anteprime): capsula opaca dai colori fissi,
/// simbolo Alleanza blu o pallino cuoio, scritta completa (compatta: una parola). Sempre chiara.
struct EtichettaCanaleStampa: View {
    let canale: Canale
    var compatta = false

    var body: some View {
        let c = Tema.Colore.Componenti.self
        let m = Tema.Misura.Componenti.self
        let alleanza = canale == .alleanza
        let colore = alleanza ? Tema.Colore.canaleAlleanzaStampa : Tema.Colore.canaleIndipendenteStampa
        let forma = Capsule(style: .continuous)
        HStack(spacing: m.spazioStampa) {
            if alleanza, let simbolo = Risorse.immagine("Loghi/Alleanza_simbolo.png") {
                Image(piattaforma: simbolo)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: compatta ? m.simboloStampaCompatto : m.simboloStampa)
                    .foregroundColor(colore)
            } else {
                Circle()
                    .fill(colore)
                    .frame(width: m.pallinoStampa, height: m.pallinoStampa)
            }
            Text(compatta ? canale.nomeBreve : canale.nome)
                .font(compatta ? Tipo.etichettaCanalePiccola : Tipo.etichettaCanale)
                .foregroundColor(c.testoCanaleStampa)
                .lineLimit(1)
        }
        .padding(compatta ? m.etichettaStampaCompatta : m.etichettaStampa)
        .background { forma.fill(alleanza ? c.fondoCanaleAlleanzaStampa : c.fondoCanaleIndipendenteStampa) }
        .overlay {
            forma.strokeBorder(alleanza ? c.bordoCanaleAlleanzaStampa : c.bordoCanaleIndipendenteStampa, lineWidth: m.bordoStampa)
        }
        .fixedSize()
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Icone delle app

/// Icona di un'app. L'Agenda mostra la data del giorno.
struct IconaApp: View {
    let app: AppPrisma
    let lato: CGFloat

    var body: some View {
        Group {
            if app == .agenda {
                IconaAgenda(lato: lato)
            } else {
                ImmagineNitida(percorso: "Icone/\(app.icona).png", lato: lato)
            }
        }
        .frame(width: lato, height: lato)
    }
}

/// Icona Agenda: piastrella bianca senza data, mese (rosso, maiuscolo) e giorno scritti dall'app, riflesso sopra.
/// Posizioni e proporzioni dal tema (vedi Design/Icone/LEGGIMI.txt).
struct IconaAgenda: View {
    let lato: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { contesto in
            let oggi = contesto.date
            let u = lato / 256
            let m = Tema.Misura.Componenti.self
            ZStack {
                ImmagineNitida(percorso: "Icone/Agenda_base.png", lato: lato)
                Text(Formati.meseBreve.string(from: oggi).uppercased())
                    .font(Tema.Testo.Componenti.meseIconaAgenda(lato))
                    .tracking(lato * m.spaziaturaMeseIconaAgenda)
                    .foregroundColor(Tema.Colore.Componenti.meseIconaAgenda)
                    .fixedSize()
                    .position(x: m.meseIconaAgenda.x * u, y: m.meseIconaAgenda.y * u)
                Text(Formati.giorno.string(from: oggi))
                    .font(Tema.Testo.Componenti.giornoIconaAgenda(lato))
                    .tracking(lato * m.spaziaturaGiornoIconaAgenda)
                    .foregroundColor(Tema.Colore.Componenti.giornoIconaAgenda)
                    .shadow(color: Tema.Colore.Componenti.ombraIconaAgenda,
                            radius: lato * m.ombraIconaAgendaRaggio, x: 0, y: lato * m.ombraIconaAgendaY)
                    .fixedSize()
                    .position(x: m.giornoIconaAgenda.x * u, y: m.giornoIconaAgenda.y * u)
                ImmagineNitida(percorso: "Icone/Agenda_vetro.png", lato: lato)
            }
            .frame(width: lato, height: lato)
        }
    }
}

// MARK: - Avviso temporaneo (.toast)

/// Avviso che compare per qualche secondo sopra la barra di stato della finestra attiva (senza finestre,
/// sopra il dock): capsula di vetro dei pannelli con il riempimento coprente, che non lascia leggere sotto.
struct VistaAvviso: View {
    let testo: String
    /// Il commiato di Eve (.toast di Design/eve-mini.html): la sfera prima del testo.
    var sfera = false

    var body: some View {
        HStack(spacing: Tema.Misura.Componenti.spazioSferaAvviso) {
            if sfera {
                SferaAcquaEve(lato: Tema.Misura.Componenti.sferaAvviso, velocita: Tema.Moto.MiniEve.velocitaAscolto)
            }
            Text(testo)
                .font(Tema.Testo.Componenti.avviso)
                .foregroundColor(Tema.Colore.inchiostro)
                .multilineTextAlignment(.center)
        }
        .padding(Tema.Misura.Componenti.avviso)
        .vetro(.pannello, forma: .capsula, riempimento: Tema.Colore.PannelliShell.coprente)
    }
}
