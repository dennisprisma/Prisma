#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

// Movimenti dell'interfaccia (fluidità in stile macOS): token, aiuti e modificatori.
// Durante un'animazione si animano solo trasformazioni e opacità, mai cornici, layout, sfocature od ombre.
// Il nome dell'enum è `Movimenti` perché `Movimento` è già il movimento di capitale di una posizione (Dati/Posizione.swift).

extension Notification.Name {
    /// Comincia una transizione dell'interfaccia; userInfo["durata"]: Double (secondi).
    /// Oggi non la ascolta nessuno (l'acqua non si ferma e la prova guidata misura per tratti): resta come aggancio.
    static let prismaTransizione = Notification.Name("prisma.transizione")
}

/// Aiuti comuni a tutti i movimenti di Prisma.
enum Movimenti {
    /// «Riduci movimento» del Mac (o di iPhone e iPad): niente scale né spostamenti, solo dissolvenze brevi.
    static var calmo: Bool {
        #if os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #elseif os(iOS)
        return UIAccessibility.isReduceMotionEnabled
        #endif
    }

    /// La curva data, o la dissolvenza calma con «Riduci movimento».
    static func curva(_ a: Animation) -> Animation { calmo ? Tema.Moto.dissolvenzaCalma : a }

    /// Cambia lo stato animandolo (o di colpo, con `animato == false`) e avvisa chi disegna per fotogramma.
    /// L'avviso parte dopo il cambiamento: chi lo ascolta non deve finire prima, in una transazione senza animazione.
    static func anima(_ curva: Animation, durata: Double, animato: Bool = true, _ cambia: () -> Void) {
        guard animato else {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t, cambia)
            return
        }
        withAnimation(Movimenti.curva(curva), cambia)
        annuncia(durata: durata)
    }

    /// Fa partire l'animazione al giro successivo del run loop. Il costo del primo disegno (corpo
    /// dell'app, impaginazione) cade così prima del primo fotogramma animato e la molla parte pulita.
    static func alGiroDopo(_ curva: Animation, durata: Double, _ cambia: @escaping () -> Void) {
        DispatchQueue.main.async { Movimenti.anima(curva, durata: durata, cambia) }
    }

    /// Esegue dopo `durata` senza animazione (macOS 13 non ha la completion di withAnimation).
    static func dopo(_ durata: Double, _ fai: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + durata) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t, fai)
        }
    }

    static func annuncia(durata: Double) {
        NotificationCenter.default.post(name: .prismaTransizione, object: nil, userInfo: ["durata": durata])
    }

    /// Resistenza elastica oltre i limiti, come gli scorrimenti di macOS e iOS: dentro [minimo, massimo]
    /// segue il dito 1:1, fuori rallenta e non va oltre `portata`.
    static func elastico(_ x: CGFloat, minimo: CGFloat = 0, massimo: CGFloat,
                         portata: CGFloat = Tema.Moto.Sblocco.portataElastica) -> CGFloat {
        let c = Tema.Moto.Sblocco.coefficienteElastico
        func gomma(_ d: CGFloat) -> CGFloat { (1 - 1 / (d * c / portata + 1)) * portata }
        if x < minimo { return minimo - gomma(minimo - x) }
        if x > massimo { return massimo + gomma(x - massimo) }
        return x
    }

    /// Velocità iniziale di una molla, in «percorsi al secondo», ricavata dalla previsione del gesto
    /// (DragGesture.Value.velocity esiste solo da macOS 14).
    static func velocita(traslazione: CGFloat, prevista: CGFloat, distanza: CGFloat) -> Double {
        guard abs(distanza) > 1 else { return 0 }
        let v = (prevista - traslazione) / Tema.Moto.Sblocco.orizzontePrevisione
        let limite = Tema.Moto.Sblocco.velocitaMassima
        return Double(min(max(v / distanza, -limite), limite))
    }
}

extension Tema.Moto {
    /// Molla alla Apple, definita da risposta (s) e smorzamento (1 = nessun rimbalzo), con la velocità del gesto.
    /// Su macOS 13 si usa interpolatingSpring, perché spring(duration:bounce:) esiste solo da macOS 14.
    static func conMolla(risposta: Double, smorzamento: Double, velocita: Double = 0) -> Animation {
        let rigidezza = pow(2 * Double.pi / risposta, 2)
        let attrito = 4 * Double.pi * smorzamento / risposta
        return .interpolatingSpring(mass: 1, stiffness: rigidezza, damping: attrito, initialVelocity: velocita)
    }
    /// Con «Riduci movimento».
    static let dissolvenzaCalma = Animation.easeInOut(duration: 0.15)

    // Tutte le curve senza rimbalzo (molle a smorzamento critico) e brevi come in macOS:
    // l'unico movimento elastico resta lo sblocco col dito (Sblocco.ritorno, Sblocco.pressione).

    enum Finestre {
        // Curve come punti di controllo: valgono per SwiftUI (Animation.timingCurve), per Core Animation
        // (CAMediaTimingFunction) e per CurveGenio (fotogrammi chiave precalcolati, Shell/MotoreGenio.swift).
        static let controlliGenio: (Double, Double, Double, Double) = (0.25, 0.1, 0.55, 1)
        static let controlliRipristino: (Double, Double, Double, Double) = (0.42, 0, 0.58, 1)
        // Riduzione nel dock: «effetto genio» di macOS (circa 8 fotogrammi a 24 al secondo, come il video del Mac
        // dell'utente). La curva è appena morbida ai capi: le fasi qui sotto hanno già le loro accelerazioni, e così
        // la finestra risponde subito al clic. Il genio vero lo fa Core Animation su un'istantanea della finestra;
        // la curva SwiftUI resta per il ripiego.
        static let genio = Animation.timingCurve(0.25, 0.1, 0.55, 1, duration: 0.4)
        static let durataGenio: Double = 0.4
        // Il ripristino finisce piano: i lati tornano dritti senza scatto
        static let ripristino = Animation.timingCurve(0.42, 0, 0.58, 1, duration: 0.4)
        static let durataRipristino: Double = 0.4
        /// Passando avanti e indietro sui semafori non si cattura l'istantanea più spesso di così (secondi).
        static let genioIntervalloPreparazione: Double = 0.3
        /// Con Maiusc premuto (come il rallentatore di macOS) le durate del genio si moltiplicano per questo.
        static let fattoreRallentato: Double = 2
        /// Prima fase del genio (fino a qui): il bordo in basso si stringe e scende fino all'icona, la cima resta ferma.
        static let genioFineFondo: CGFloat = 0.45
        /// Fino a qui si forma l'imbuto: i lati si piegano a S verso l'icona (subito, mentre il fondo comincia a scendere).
        static let genioFinePiega: CGFloat = 0.35
        /// Seconda fase (da qui): la cima scende lungo l'imbuto e la finestra scivola dentro l'icona.
        static let genioInizioCima: CGFloat = 0.3
        /// Da qui la finestra, ormai nell'icona, svanisce: il contenuto resta visibile fin quasi alla fine.
        static let genioInizioDissolvenza: CGFloat = 0.88
        /// Strisce orizzontali dell'istantanea: ognuna segue un trapezio esatto dell'imbuto (i lati diventano curvi).
        static let genioStrisce = 40
        /// Fotogrammi chiave al secondo precalcolati (sopra i 60 Hz del Mac: fra due vicini l'interpolazione non si vede).
        static let genioFotogrammiAlSecondo: Double = 120
        /// Le strisce si sovrappongono di tanto (pt) verso il basso: niente fili di sfondo tra una e l'altra.
        static let genioSovrapposizione: CGFloat = 1
        /// L'ombra della finestra svanisce all'inizio del genio (e ricompare alla fine del ripristino) in tanto.
        static let genioDurataOmbra: Double = 0.12
        /// Oltre questo tempo una cattura sincrona dell'istantanea è «lenta»: la volta dopo, senza istantanea pronta,
        /// si usa il ripiego (e l'istantanea si prepara al giro dopo).
        static let genioAttesaMassimaIstantanea: Double = 0.12
        /// Un'istantanea preparata (puntatore sui semafori) vale per tanto (secondi).
        static let genioValiditaIstantanea: Double = 1.5
        /// Istantanee tenute per le finestre ridotte (servono al ripristino); oltre si rifanno al ripristino.
        static let genioIstantaneeTenute = 4
        /// A effetto finito l'istantanea resta sopra la finestra vera ancora tanto: nessun fotogramma vuoto.
        static let genioRitardoRimozione: Double = 0.034
        /// Ripiego senza istantanea: la finestra viva rimpicciolisce verso l'icona e svanisce (solo scala, affine).
        static let ripiegoGenio = Animation.easeIn(duration: 0.28)
        static let durataRipiegoGenio: Double = 0.28
        static let scalaRipiegoGenio: CGFloat = 0.12
        // Apertura come macOS dal dock: la finestra viva cresce dall'icona (scala affine, il vetro resta vero),
        // molla senza rimbalzo
        static let apertura = Tema.Moto.conMolla(risposta: 0.3, smorzamento: 1)
        static let durataApertura: Double = 0.3
        /// Da dove parte la finestra che si apre da un punto (icona del dock, della scrivania, widget).
        static let scalaApertura: CGFloat = 0.2
        /// Senza punto d'origine (menu, spazi, comandi) l'apertura resta quella lieve al suo posto.
        static let scalaAperturaSulPosto: CGFloat = 0.94
        /// L'opacità arriva piena quasi subito: niente vetro mezzo trasparente (niente fantasma).
        static let aperturaOpacita = Animation.easeOut(duration: 0.06)
        // Chiusura: l'istantanea svanisce con un lieve rimpicciolimento, in accelerazione (easeIn)
        static let controlliChiusura: (Double, Double, Double, Double) = (0.42, 0, 1, 1)
        static let durataChiusura: Double = 0.2
        static let scalaChiusura: CGFloat = 0.96
        /// Solo con «Riduci movimento» e nelle prove: la finestra viva svanisce.
        static let chiusura = Animation.easeIn(duration: 0.2)
        // Ingrandisci / ripristina dimensione / affianca / spazi (FLIP): fluido, senza rimbalzo
        static let ingrandimento = Animation.timingCurve(0.3, 0, 0.2, 1, duration: 0.25)
        static let durataIngrandimento: Double = 0.25
        /// A curva finita: il passaggio FLIP si toglie senza scatti.
        static let fineIngrandimento: Double = 0.32
        // Mostra la scrivania: una finestra ogni 50 ms (tema showDesk :1738-1742)
        static let sfalsamento: Double = 0.05
        // Primo piano e cambio app: istantanei come su macOS (nessun token di curva)
    }

    enum Pannelli {
        static let veloEntrata = Animation.easeOut(duration: 0.18)
        static let veloUscita = Animation.easeIn(duration: 0.12)
        // Centro notifiche: entra da destra
        static let notifiche = Tema.Moto.conMolla(risposta: 0.3, smorzamento: 1)
        static let notificheSpostamento: CGFloat = 24
        /// La scheda delle notifiche non si scala: entra solo da destra.
        static let notificheScala: CGFloat = 1
        static let notificheUscita = Animation.easeIn(duration: 0.14)
        // Spazi di lavoro: dall'alto, come Mission Control
        static let spazi = Tema.Moto.conMolla(risposta: 0.28, smorzamento: 1)
        static let spaziScala: CGFloat = 0.96
        static let spaziUscita = Animation.easeIn(duration: 0.12)
        // «Le tue app aperte»: dal centro, come ⌘Tab
        static let appAperte = Tema.Moto.conMolla(risposta: 0.24, smorzamento: 1)
        static let appAperteScala: CGFloat = 0.94
        static let appAperteUscita = Animation.easeIn(duration: 0.1)
        // Avviso (toast, tema :898)
        static let avviso = Tema.Moto.conMolla(risposta: 0.3, smorzamento: 1)
        static let avvisoUscita = Animation.easeIn(duration: 0.18)
        static let avvisoSpostamento: CGFloat = 8
        static let avvisoScala: CGFloat = 0.97
        // Presentazione
        static let presentazione = Animation.easeOut(duration: 0.22)
        static let durataPresentazione: Double = 0.22
        static let paginaPresentazione = Animation.easeInOut(duration: 0.16)
        // I fogli (.sheet), i popover, i menu e le tendine (NSMenu) restano quelli del Mac: nessun token
    }

    enum Dock {
        static let mostra = Tema.Moto.uscita(0.2)
        static let nascondi = Animation.easeIn(duration: 0.16)
        static let ritardoNascondi: Double = 0.35
        /// Il fumetto con il nome sopra l'icona: compare e scompare subito, con una dissolvenza brevissima.
        static let suggerimento = Animation.easeOut(duration: 0.08)
    }

    enum Controlli {
        static let segmenti = Tema.Moto.conMolla(risposta: 0.25, smorzamento: 1)
        static let interruttore = Tema.Moto.conMolla(risposta: 0.22, smorzamento: 1)
    }

    enum Sblocco {
        static let pressione = Tema.Moto.conMolla(risposta: 0.25, smorzamento: 0.8)
        static func ritorno(velocita: Double = 0) -> Animation { Tema.Moto.conMolla(risposta: 0.4, smorzamento: 0.8, velocita: velocita) }
        static func completa(velocita: Double = 0) -> Animation { Tema.Moto.conMolla(risposta: 0.28, smorzamento: 1, velocita: velocita) }
        /// Un colpo rapido sblocca anche se non arriva alla soglia: previsione ≥ 100 % e almeno il 30 % percorso.
        static let quotaColpoRapido: CGFloat = 0.3
        /// Oltre questa quota della corsa il rilascio sblocca.
        static let quotaSoglia: CGFloat = 0.8
        static let attesaPrimaDiEntrare: Double = 0.06
        static let portataElastica: CGFloat = 24
        static let coefficienteElastico: CGFloat = 0.55
        /// predictedEndTranslation proietta circa questo tempo: da tarare sul Mac.
        static let orizzontePrevisione: CGFloat = 0.25
        /// Velocità massima della molla, in percorsi al secondo: niente molle impazzite.
        static let velocitaMassima: CGFloat = 8
        // Uscita della schermata: ora, logo e cursore salgono e svaniscono
        static let uscitaBenvenuto = Tema.Moto.conMolla(risposta: 0.32, smorzamento: 1)
        static let uscitaSpostamento: CGFloat = -24
        // Entrata della scrivania: leggero zoom e dissolvenza
        static let entrataScrivania = entrata()
        /// L'entrata della scrivania con una parte della velocità del gesto di sblocco (percorsi al secondo).
        static func entrata(velocita: Double = 0) -> Animation {
            let v = min(max(velocita, 0), Double(velocitaMassima)) * quotaVelocitaEntrata
            return Tema.Moto.conMolla(risposta: 0.45, smorzamento: 1, velocita: v)
        }
        /// Quanta della velocità del gesto passa alla scrivania (la manopola corre, la scrivania segue più calma).
        static let quotaVelocitaEntrata: Double = 0.3
        static let durataEntrata: Double = 0.5
        static let scalaScrivania: CGFloat = 1.03
        static let widget = Tema.Moto.uscita(0.36)        // tema :2097-2101
        static let sfalsamentoWidget: Double = 0.04
        static let widgetSpostamento: CGFloat = 10
        static let widgetScala: CGFloat = 0.985
    }

    enum Blocco {
        static let scrivania = Animation.easeInOut(duration: 0.26)
        static let scalaScrivania: CGFloat = 0.98
        static let benvenuto = Tema.Moto.uscita(0.32)
        static let scalaBenvenuto: CGFloat = 1.03
        static let durata: Double = 0.34
        /// Stand-by (stop del Mac o schermo spento): nessuna animazione; l'acqua riparte dopo il risveglio.
        static let ripresaAcquaDopoRisveglio: Double = 1.2
    }

    enum Avvio {
        /// Widget all'apertura di Prisma (tema :2345): 560 ms, ritardo 60 + 45 ms per widget.
        static let widget = Tema.Moto.uscita(0.56)
        static let ritardo: Double = 0.06
        static let sfalsamento: Double = 0.045
        static let spostamento: CGFloat = 14
        static let scala: CGFloat = 0.985
    }
}

// MARK: - Modificatori (solo trasformazioni e opacità)

/// Apertura e chiusura di una finestra: scala attorno all'ancora, spostamento verticale, opacità.
struct EffettoFinestra: ViewModifier {
    let scala: CGFloat
    let ancora: UnitPoint
    let y: CGFloat
    let opacita: Double

    func body(content: Content) -> some View {
        content.scaleEffect(scala, anchor: ancora).offset(y: y).opacity(opacita)
    }
}

/// Ripiego del genio senza istantanea (Core Animation assente, istantanea lenta): la finestra viva rimpicciolisce
/// verso l'icona del dock, solo con una scala (affine: il vetro di Apple si disegna bene). Con progresso 0 è com'è.
/// Il genio vero, a strisce curve, lo fa MotoreGenio su un'istantanea (una prospettiva sulla finestra viva, col
/// vetro nativo, non si disegna: è il difetto del video del 29 ottobre).
struct RiduzioneSemplice: GeometryEffect {
    var progresso: CGFloat
    /// Il centro dell'icona nelle coordinate della finestra.
    let ancora: CGPoint
    let calmo: Bool

    var animatableData: CGFloat {
        get { progresso }
        set { progresso = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard !calmo, progresso > 0 else { return ProjectionTransform(CGAffineTransform.identity) }
        let s = 1 - (1 - Tema.Moto.Finestre.scalaRipiegoGenio) * min(progresso, 1)
        let t = CGAffineTransform(translationX: ancora.x, y: ancora.y)
            .scaledBy(x: s, y: s)
            .translatedBy(x: -ancora.x, y: -ancora.y)
        return ProjectionTransform(t)
    }
}

/// L'opacità dell'apertura con la sua curva breve (piena in 0,06 s), separata dalla scala che segue la molla.
/// Va messa prima (dentro) di EffettoFinestra: la sua `.animation` tocca solo ciò che sta sotto.
struct OpacitaApertura: ViewModifier {
    let visibile: Bool
    @Environment(\.modoIstantanea) private var istantanea

    func body(content: Content) -> some View {
        content
            .opacity(visibile ? 1 : 0)
            .animation(istantanea ? nil : Movimenti.curva(Tema.Moto.Finestre.aperturaOpacita), value: visibile)
    }
}

/// La dissolvenza del genio: piena finché la finestra entra nell'icona, poi svanisce (a 1 è invisibile).
/// Con «Riduci movimento» è tutta la riduzione: una dissolvenza breve.
struct OpacitaGenio: ViewModifier, Animatable {
    var progresso: CGFloat
    let calmo: Bool

    var animatableData: CGFloat {
        get { progresso }
        set { progresso = newValue }
    }

    func body(content: Content) -> some View {
        content.opacity(opacita)
    }

    private var opacita: Double {
        if progresso <= 0 { return 1 }
        if progresso >= 1 { return 0 }
        if calmo { return Double(1 - progresso) }
        let inizio = Tema.Moto.Finestre.genioInizioDissolvenza
        guard progresso > inizio else { return 1 }
        let t = (progresso - inizio) / (1 - inizio)
        return Double(1 - t * t * (3 - 2 * t))
    }
}

/// FLIP per ingrandisci, affianca e spazi: la vista ha già la cornice finale `a`; con progresso 0
/// una trasformazione la riporta sulla cornice di partenza `da`. Niente impaginazione a ogni fotogramma.
struct EffettoCornice: GeometryEffect {
    var progresso: CGFloat
    let da: CGRect
    let a: CGRect

    var animatableData: CGFloat {
        get { progresso }
        set { progresso = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard progresso < 1, a.width > 0, a.height > 0 else { return ProjectionTransform(CGAffineTransform.identity) }
        let p = progresso
        let w = da.width + (a.width - da.width) * p
        let h = da.height + (a.height - da.height) * p
        let x = da.minX + (a.minX - da.minX) * p
        let y = da.minY + (a.minY - da.minY) * p
        return ProjectionTransform(CGAffineTransform(translationX: x - a.minX, y: y - a.minY)
            .scaledBy(x: w / a.width, y: h / a.height))
    }
}

/// Entrata sfalsata (widget allo sblocco e all'avvio): animazione implicita limitata alla sola vista.
struct EntrataSfalsata: ViewModifier {
    let indice: Int
    let nascosto: Bool
    var curva: Animation = Tema.Moto.Sblocco.widget
    var sfalsamento: Double = Tema.Moto.Sblocco.sfalsamentoWidget
    var spostamento: CGFloat = Tema.Moto.Sblocco.widgetSpostamento
    var scala: CGFloat = Tema.Moto.Sblocco.widgetScala

    func body(content: Content) -> some View {
        let calmo = Movimenti.calmo
        content
            .opacity(nascosto ? 0 : 1)
            .offset(y: nascosto && !calmo ? spostamento : 0)
            .scaleEffect(nascosto && !calmo ? scala : 1)
            .animation(nascosto ? Tema.Moto.Blocco.scrivania
                                : Movimenti.curva(curva).delay(Double(indice) * sfalsamento), value: nascosto)
    }
}

/// La scheda di un pannello entra con scala e spostamento (il velo e il contenitore fanno solo l'opacità).
struct EntrataScheda: ViewModifier {
    let curva: Animation
    let scala: CGFloat
    let ancora: UnitPoint
    var x: CGFloat = 0
    var y: CGFloat = 0
    @Environment(\.modoIstantanea) private var istantanea
    @State private var dentro = false

    func body(content: Content) -> some View {
        // Nelle istantanee la scheda è già al suo posto
        let fermo = dentro || istantanea || Movimenti.calmo
        content
            .scaleEffect(fermo ? 1 : scala, anchor: ancora)
            .offset(x: fermo ? 0 : x, y: fermo ? 0 : y)
            .onAppear { if !istantanea { withAnimation(Movimenti.curva(curva)) { dentro = true } } }
    }
}

extension View {
    func entrataSfalsata(indice: Int, nascosto: Bool,
                         curva: Animation = Tema.Moto.Sblocco.widget,
                         sfalsamento: Double = Tema.Moto.Sblocco.sfalsamentoWidget,
                         spostamento: CGFloat = Tema.Moto.Sblocco.widgetSpostamento,
                         scala: CGFloat = Tema.Moto.Sblocco.widgetScala) -> some View {
        modifier(EntrataSfalsata(indice: indice, nascosto: nascosto, curva: curva, sfalsamento: sfalsamento,
                                 spostamento: spostamento, scala: scala))
    }

    func entrataScheda(_ curva: Animation, scala: CGFloat, ancora: UnitPoint, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        modifier(EntrataScheda(curva: curva, scala: scala, ancora: ancora, x: x, y: y))
    }
}

extension AnyTransition {
    /// Rimozione di una finestra chiusa: curva di chiusura propria, qualunque sia la transazione.
    /// Con «Riduci movimento» solo la dissolvenza.
    static func chiusuraFinestra(ancora: UnitPoint) -> AnyTransition {
        let scala: CGFloat = Movimenti.calmo ? 1 : Tema.Moto.Finestre.scalaChiusura
        return .asymmetric(
            // L'entrata la fa EffettoFinestra guidato dallo stato (apertura al giro dopo)
            insertion: .identity,
            removal: AnyTransition.modifier(
                active: EffettoFinestra(scala: scala, ancora: ancora, y: 0, opacita: 0),
                identity: EffettoFinestra(scala: 1, ancora: ancora, y: 0, opacita: 1))
                .animation(Movimenti.curva(Tema.Moto.Finestre.chiusura)))
    }

    /// Velo dei pannelli: solo opacità, entrata e uscita con curve diverse.
    static var velo: AnyTransition {
        .asymmetric(insertion: AnyTransition.opacity.animation(Tema.Moto.Pannelli.veloEntrata),
                    removal: AnyTransition.opacity.animation(Tema.Moto.Pannelli.veloUscita))
    }
}
