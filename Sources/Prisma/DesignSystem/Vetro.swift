import AppKit
import SwiftUI

// MARK: - Vetro del tema Liquid Glass

/// Le superfici di vetro del tema (le classi di tema.html tra parentesi).
enum VarianteVetro: Equatable {
    /// Vetro pieno (`.glass`): widget della scrivania.
    case spesso
    /// Vetro leggero (`.glass.thin`): dock, strumenti della barra, pulsanti di vetro, suggerimenti, avvisi.
    case leggero
    /// Vetro dei pannelli (`.glass.panel`): ricerca, notifiche, centro di controllo, popover, app aperte.
    case pannello
    /// Finestra interna (`.win`), attiva o in secondo piano.
    case finestra(attiva: Bool)
    /// Barra laterale staccata dentro le finestre (`.side`): senza sfocatura.
    case laterale
    /// Schede, tessere e pannelli interni (`.card`): riempimento e contorno, senza sfocatura.
    case sottile
    /// Chip e pulsanti in capsula (`.chip`, `.btn`): riempimento, contorno e filo di luce, senza sfocatura.
    case chip
}

/// Forma di una superficie di vetro: rettangolo dagli angoli continui oppure capsula.
/// Il raggio si anima (ingrandisci ↔ ripristina dimensione): la capsula resta capsula.
struct FormaVetro: InsettableShape {
    /// nil = capsula.
    var raggio: CGFloat?
    var rientro: CGFloat = 0

    var animatableData: CGFloat {
        get { raggio ?? 0 }
        set { if raggio != nil { raggio = newValue } }
    }

    static func arrotondata(_ raggio: CGFloat) -> FormaVetro { FormaVetro(raggio: raggio) }
    static let capsula = FormaVetro(raggio: nil)

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: rientro, dy: rientro)
        guard !r.isNull, r.width > 0, r.height > 0 else { return Path() }
        if let raggio {
            return RoundedRectangle(cornerRadius: max(0, raggio - rientro), style: .continuous).path(in: r)
        }
        return Capsule(style: .continuous).path(in: r)
    }

    func inset(by amount: CGFloat) -> FormaVetro {
        var copia = self
        copia.rientro += amount
        return copia
    }
}

/// Interruttori globali del vetro.
enum Vetro {
    /// true = niente materiali di sistema né vetro nativo, riempimento più coprente: per le istantanee
    /// e ImageRenderer, che non catturano le sfocature di sistema. Va impostato prima di disegnare.
    nonisolated(unsafe) static var semplificato = false
    /// false = anche su macOS 26 si usa il vetro disegnato da Prisma al posto di quello di Apple.
    nonisolated(unsafe) static var nativo = true
    /// Spazio attorno alla superficie in cui si disegnano le ombre.
    static let margineOmbre: CGFloat = 160
}

private struct ChiaveVetroSemplificato: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Come `Vetro.semplificato`, ma solo per una parte della vista.
    var vetroSemplificato: Bool {
        get { self[ChiaveVetroSemplificato.self] }
        set { self[ChiaveVetroSemplificato.self] = newValue }
    }
}

extension View {
    /// Superficie di vetro del tema dietro questa vista (che resta sopra, leggibile).
    /// - variante: vedi `VarianteVetro`.
    /// - forma: `.arrotondata(raggio)` o `.capsula`.
    /// - tinta: colore steso sopra il riempimento (passalo già attenuato, es. `.opacity(0.18)`); su macOS 26 tinge il vetro.
    /// - riempimento: sostituisce il riempimento della variante (es. il fondo dei chip dei canali).
    /// - interattivo: su macOS 26 il vetro reagisce al tocco (pulsanti).
    /// - ombra: false = senza ombra esterna.
    func vetro(_ variante: VarianteVetro = .spesso,
               forma: FormaVetro = .arrotondata(Tema.Raggio.widget),
               tinta: Color? = nil,
               riempimento: Color? = nil,
               interattivo: Bool = false,
               ombra: Bool = true) -> some View {
        modifier(ModificatoreVetro(variante: variante, forma: forma, tinta: tinta, riempimento: riempimento,
                                   interattivo: interattivo, ombra: ombra))
    }

    /// Capsula di vetro del colore del canale (blu Alleanza, cuoio indipendente). Solo schermate, non PDF.
    func vetroCanale(_ canale: Canale) -> some View {
        vetro(.chip, forma: .capsula, riempimento: Tema.Colore.fondoCanale(canale))
    }

    /// Alone del testo che sta direttamente sullo sfondo (saluto, barra, piede): netto in chiaro, morbido in scuro.
    func aloneSfondo() -> some View {
        modifier(AloneSfondo())
    }

    /// Ombra leggera del testo nei widget (solo in scuro, come nel tema).
    func ombraTestoWidget() -> some View {
        shadow(color: Tema.Colore.ombraTestoWidget, radius: 1, x: 0, y: 1)
    }
}

/// Il vetro: su macOS 26 quello di Apple, altrimenti materiale di sistema + riempimento, bordi e riflessi del tema.
/// Nelle istantanee (e con `Vetro.semplificato`) niente materiali: riempimento più coprente che rende bene in PNG.
struct ModificatoreVetro: ViewModifier {
    let variante: VarianteVetro
    let forma: FormaVetro
    let tinta: Color?
    let riempimentoScelto: Color?
    let interattivo: Bool
    let ombra: Bool

    @Environment(\.modoIstantanea) private var modoIstantanea
    @Environment(\.vetroSemplificato) private var semplificatoQui
    @Environment(\.accessibilityReduceTransparency) private var trasparenzaRidotta
    @Environment(\.colorScheme) private var schema

    init(variante: VarianteVetro, forma: FormaVetro, tinta: Color? = nil, riempimento: Color? = nil,
         interattivo: Bool = false, ombra: Bool = true) {
        self.variante = variante
        self.forma = forma
        self.tinta = tinta
        self.riempimentoScelto = riempimento
        self.interattivo = interattivo
        self.ombra = ombra
    }

    @ViewBuilder func body(content: Content) -> some View {
        if usaVetroNativo {
            vetroNativo(content)
        } else {
            vetroDisegnato(content)
        }
    }

    // MARK: Scelte

    /// Senza materiali di sistema (istantanee, ImageRenderer).
    private var semplice: Bool { modoIstantanea || semplificatoQui || Vetro.semplificato }

    /// Le varianti che sfocano lo sfondo; le altre stanno dentro un vetro e non sfocano.
    private var conSfocatura: Bool {
        switch variante {
        case .spesso, .leggero, .pannello, .finestra: return true
        case .laterale, .sottile, .chip: return false
        }
    }

    /// Le varianti `.glass` del tema, con riflesso, bagliore e anello luminoso.
    private var vetroPieno: Bool {
        switch variante {
        case .spesso, .leggero, .pannello: return true
        default: return false
        }
    }

    private var usaVetroNativo: Bool {
        guard conSfocatura, !semplice, !trasparenzaRidotta, Vetro.nativo else { return false }
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { return true }
        #endif
        return false
    }

    private var strati: [StratoOmbra] {
        switch variante {
        case .spesso, .leggero, .pannello: return Tema.Ombra.vetro(scuro: schema == .dark)
        case .finestra(let attiva): return Tema.Ombra.finestra(attiva: attiva)
        case .laterale: return Tema.Ombra.laterale
        case .sottile, .chip: return []
        }
    }

    private var materiale: Material {
        switch variante {
        case .pannello, .finestra: return .thinMaterial
        default: return .ultraThinMaterial
        }
    }

    private var riempimento: Color {
        if let riempimentoScelto { return riempimentoScelto }
        typealias C = Tema.Colore
        // Nelle istantanee il vetro «Colorato» del tema, più coprente; con «Riduci trasparenza» quasi opaco
        let colorato = semplice
        switch variante {
        case .spesso:
            return trasparenzaRidotta ? C.riempimentoVetroRidotto : (colorato ? C.riempimentoVetroColorato : C.riempimentoVetro)
        case .leggero:
            return trasparenzaRidotta ? C.riempimentoLeggeroRidotto : (colorato ? C.riempimentoLeggeroColorato : C.riempimentoLeggero)
        case .pannello:
            return trasparenzaRidotta ? C.riempimentoPannelloRidotto : (colorato ? C.riempimentoPannelloColorato : C.riempimentoPannello)
        case .finestra:
            return trasparenzaRidotta ? C.finestraRidotta : (colorato ? C.finestraColorata : C.finestra)
        case .laterale:
            return colorato ? C.lateraleColorata : C.laterale
        case .sottile:
            return C.scheda
        case .chip:
            return colorato ? C.chipColorato : C.chip
        }
    }

    /// Velo sotto il contenuto quando il vetro è quello di Apple (finestre e pannelli più leggibili).
    private var veloNativo: Color {
        switch variante {
        case .finestra: return Tema.Colore.veloNativoFinestra
        case .pannello: return Tema.Colore.veloNativoPannello
        default: return .clear
        }
    }

    /// Con il vetro di Apple l'ombra è già sua: Prisma aggiunge solo quella, più ampia, delle finestre.
    private var ombraNativa: Bool {
        if case .finestra(_) = variante { return ombra }
        return false
    }

    /// Le finestre hanno l'ombra già pronta (OmbraPrecalcolata): il raggio della forma, o nil per le ombre disegnate.
    private var raggioOmbraPronta: CGFloat? {
        guard case .finestra(_) = variante, forma.rientro == 0 else { return nil }
        return forma.raggio
    }

    /// Ombre esterne. Cambiano di colpo, come sul Mac: mai interpolate da un'animazione (finestra attiva ↔ inattiva).
    /// Le finestre, che si aprono, si spostano e si scalano, usano la bitmap a 9 fette: niente sfocature in movimento.
    @ViewBuilder private var ombre: some View {
        if let raggio = raggioOmbraPronta {
            OmbraVetroPronta(raggio: raggio, strati: strati)
                .animation(nil, value: variante)
        } else {
            OmbreVetro(forma: forma, strati: strati)
                .animation(nil, value: variante)
        }
    }

    // MARK: Vetro di Apple (macOS 26)

    private func vetroNativo(_ content: Content) -> AnyView {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            return AnyView(
                content
                    // Un riempimento scelto (pannelli che galleggiano sopra altro contenuto) resta anche sul vetro di Apple
                    .background { forma.fill(riempimentoScelto ?? veloNativo) }
                    .glassEffect(vetroDiSistema, in: forma)
                    .background {
                        if ombraNativa { ombre }
                    }
            )
        }
        #endif
        return AnyView(vetroDisegnato(content))
    }

    // MARK: Vetro disegnato (macOS 13-25, istantanee)

    private func vetroDisegnato(_ content: Content) -> some View {
        content
            .background { fondo }
            .overlay { bordi.allowsHitTesting(false) }
            .background {
                if ombra && !strati.isEmpty { ombre }
            }
    }

    @ViewBuilder private var fondo: some View {
        ZStack {
            if conSfocatura && !semplice && !trasparenzaRidotta {
                forma.fill(materiale)
            }
            if vetroPieno && !semplice {
                // inset 0 0 24px: bagliore interno
                forma.fill(riempimento.shadow(.inner(color: Tema.Colore.bagliore, radius: 12)))
            } else {
                forma.fill(riempimento)
            }
            if let tinta {
                forma.fill(tinta)
            }
            if vetroPieno {
                Lucentezza().clipShape(forma)
            }
        }
    }

    @ViewBuilder private var bordi: some View {
        switch variante {
        case .spesso, .leggero, .pannello:
            ZStack {
                forma.strokeBorder(Tema.Colore.bordoVetro, lineWidth: Tema.Misura.filo)
                filo(Tema.Colore.riflessoAlto, spostamento: 1)
                filo(Tema.Colore.riflessoBasso, spostamento: -1)
                forma.strokeBorder(anello, lineWidth: 1)
                forma.strokeBorder(luceRientro, lineWidth: 1)
            }
        case .finestra(let attiva):
            ZStack {
                forma.strokeBorder(Tema.Colore.bordoVetro, lineWidth: Tema.Misura.filo)
                if attiva {
                    filo(Tema.Colore.riflessoAlto, spostamento: 1)
                }
                // 0 0 0 .5px: contorno appena fuori dal bordo
                forma.inset(by: -Tema.Misura.filo / 2)
                    .stroke(attiva ? Tema.Colore.contornoFinestra : Tema.Colore.contornoFinestraInattiva, lineWidth: Tema.Misura.filo)
            }
        case .laterale, .chip:
            ZStack {
                forma.strokeBorder(Tema.Colore.bordoChip, lineWidth: Tema.Misura.filo)
                filo(Tema.Colore.riflessoAlto, spostamento: 1)
            }
        case .sottile:
            forma.strokeBorder(Tema.Colore.bordoScheda, lineWidth: Tema.Misura.filo)
        }
    }

    /// Filo interno di 1 pt in alto (spostamento 1) o in basso (-1), come `inset 0 ±1px 0`.
    private func filo(_ colore: Color, spostamento: CGFloat) -> some View {
        FiloVetro(forma: forma, spostamento: spostamento)
            .fill(colore, style: FillStyle(eoFill: true))
            .clipShape(forma)
    }

    /// Anello luminoso a 135° (::before del tema).
    private var anello: LinearGradient {
        LinearGradient(stops: [
            .init(color: Tema.Colore.luceBordoA, location: 0),
            .init(color: Tema.Colore.luceBordoMezzo1, location: 0.22),
            .init(color: Color.white.opacity(0), location: 0.45),
            .init(color: Color.white.opacity(0), location: 0.62),
            .init(color: Tema.Colore.luceBordoMezzo2, location: 0.8),
            .init(color: Tema.Colore.luceBordoB, location: 1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Luce che rientra dal bordo inferiore (::after del tema).
    private var luceRientro: LinearGradient {
        LinearGradient(stops: [
            .init(color: Tema.Colore.luceRientro.opacity(0), location: 0),
            .init(color: Tema.Colore.luceRientro.opacity(0), location: 0.58),
            .init(color: Tema.Colore.luceRientro, location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
extension ModificatoreVetro {
    /// Il vetro di Apple con tinta e interattività.
    fileprivate var vetroDiSistema: SwiftUI.Glass {
        var vetro = SwiftUI.Glass.regular
        if let tinta { vetro = vetro.tint(tinta) }
        if interattivo { vetro = vetro.interactive() }
        return vetro
    }
}
#endif

// MARK: - Pezzi del vetro disegnato

/// Riflesso radiale del tema: ellisse 130% × 90% centrata a (25%, -20%), sfuma al 52%.
private struct Lucentezza: View {
    var body: some View {
        GeometryReader { g in
            let w = max(g.size.width, 1)
            let h = max(g.size.height, 1)
            let rx = 0.52 * 1.3 * w
            let ry = 0.52 * 0.9 * h
            Circle()
                .fill(RadialGradient(colors: [Tema.Colore.lucentezza, Tema.Colore.lucentezza.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: rx))
                .frame(width: rx * 2, height: rx * 2)
                .scaleEffect(x: 1, y: ry / rx)
                .position(x: 0.25 * w, y: -0.2 * h)
        }
        .allowsHitTesting(false)
    }
}

/// La forma e la stessa forma spostata in verticale: col riempimento pari-dispari resta un filo sul bordo.
private struct FiloVetro: Shape {
    let forma: FormaVetro
    let spostamento: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = forma.path(in: rect)
        p.addPath(forma.path(in: rect.offsetBy(dx: 0, dy: spostamento)))
        return p
    }
}

/// Tutto tranne la forma (riempimento pari-dispari): le ombre si vedono solo fuori dal vetro, come in CSS.
private struct FuoriForma: Shape {
    let forma: FormaVetro
    let margine: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path(rect)
        p.addPath(forma.path(in: rect.insetBy(dx: margine, dy: margine)))
        return p
    }
}

/// Ombre esterne a più strati con espansione negativa (box-shadow del tema), mai sotto il vetro.
private struct OmbreVetro: View {
    let forma: FormaVetro
    let strati: [StratoOmbra]

    var body: some View {
        let m = Vetro.margineOmbre
        ZStack {
            ForEach(0..<strati.count, id: \.self) { i in
                forma.inset(by: max(0, -strati[i].espansione))
                    .fill(Color.black)
                    .shadow(color: strati[i].colore, radius: strati[i].sfocatura / 2, x: 0, y: strati[i].y)
            }
        }
        .padding(m)
        .mask {
            FuoriForma(forma: forma, margine: m).fill(style: FillStyle(eoFill: true))
        }
        .padding(-m)
        .allowsHitTesting(false)
    }
}

private struct AloneSfondo: ViewModifier {
    @Environment(\.colorScheme) private var schema

    init() {}

    func body(content: Content) -> some View {
        // chiaro: 0 1px 0 bianco .5 · scuro: 0 1px 12px nero .35
        content.shadow(color: Tema.Colore.aloneSfondo, radius: schema == .dark ? 6 : 0, x: 0, y: 1)
    }
}

// MARK: - Etichetta del canale

/// Capsula del canale in vetro: Alleanza blu con il simbolo Alleanza, indipendente color cuoio.
/// `compatta`: pallino e una parola. `completa`: «Alleanza Assicurazioni» / «Denis Vicenzoni · Consulenza finanziaria».
/// Solo per le schermate: nei PDF si usano i colori fissi (`Tema.Colore.canale…Stampa`).
struct CapsulaCanale: View {
    let canale: Canale
    var compatta = false
    var completa = false

    var body: some View {
        let margini = compatta ? Tema.Misura.chipPiccoloMargini : Tema.Misura.chipMargini
        HStack(spacing: Tema.Misura.spazioChip) {
            if canale == .alleanza, !compatta, let simbolo = Risorse.immagine("Loghi/Alleanza_simbolo.png") {
                Image(nsImage: simbolo)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: Tema.Misura.simboloAlleanza)
                    .foregroundColor(Tema.Colore.canaleAlleanza)
            } else {
                Circle()
                    .fill(Tema.Colore.canale(canale))
                    .frame(width: Tema.Misura.pallinoCanale, height: Tema.Misura.pallinoCanale)
                    .overlay {
                        Circle().inset(by: -Tema.Misura.filo / 2).stroke(Tema.Colore.bordoPallino, lineWidth: Tema.Misura.filo)
                    }
            }
            Text(completa && !compatta ? canale.nome : canale.nomeBreve)
                .font(compatta ? Tema.Testo.chipPiccolo : Tema.Testo.chip)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
        }
        .padding(.leading, margini.sinistro)
        .padding(.trailing, margini.destro)
        .frame(height: compatta ? Tema.Misura.chipPiccolo : Tema.Misura.chip)
        .vetroCanale(canale)
        .fixedSize()
        .help(canale.nome)
    }
}

extension View {
    /// Raggruppa i vetri vicini (GlassEffectContainer su macOS 26): un solo campionamento dello sfondo per tutto
    /// il gruppo. `spazio`: la distanza entro cui si fondono (0 = restano separati). Con il vetro disegnato
    /// (macOS 13-25, istantanee, «Riduci trasparenza») non cambia nulla.
    func gruppoVetro(spazio: CGFloat = 0) -> some View {
        modifier(GruppoVetro(spazio: spazio))
    }
}

private struct GruppoVetro: ViewModifier {
    let spazio: CGFloat

    @Environment(\.modoIstantanea) private var modoIstantanea
    @Environment(\.vetroSemplificato) private var semplificatoQui
    @Environment(\.accessibilityReduceTransparency) private var trasparenzaRidotta

    /// Le stesse condizioni del vetro di Apple in ModificatoreVetro.
    private var nativo: Bool {
        !modoIstantanea && !semplificatoQui && !Vetro.semplificato && !trasparenzaRidotta && Vetro.nativo
    }

    // Come ModificatoreVetro: la scelta nel body, il vetro di Apple in una funzione che restituisce AnyView
    @ViewBuilder func body(content: Content) -> some View {
        if nativo {
            contenitore(content)
        } else {
            content
        }
    }

    private func contenitore(_ content: Content) -> AnyView {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            return AnyView(GlassEffectContainer(spacing: spazio) { content })
        }
        #endif
        return AnyView(content)
    }
}
