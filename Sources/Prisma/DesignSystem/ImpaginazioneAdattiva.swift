import SwiftUI

// MARK: - Impaginazione adattiva (iPad)
// Le viste App* del Mac sono pensate per finestre grandi: elenchi laterali, colonne fisse e pannelli affiancati.
// Sull'iPad la colonna di dettaglio va da circa 470 pt (11" verticale, barra laterale aperta) a circa 1.100 pt
// (13" orizzontale): qui ci sono gli strumenti per adattarle senza toccare il Mac.
// - `larghezzaApp`: la larghezza misurata del contenuto, messa nell'ambiente su iOS (ContenutoApp, le cornici
//   con l'elenco laterale). Sul Mac resta nil e ogni strumento qui sotto fa esattamente ciò che faceva prima.
// - `Affiancati`: un HStack sul Mac; su iOS, sotto una soglia, un VStack (e `impilato` vale true dentro).
// - `.larghezzaAffiancata` / `.limitiAffiancati`: le cornici fisse dei blocchi affiancati, a tutta larghezza
//   quando sono impilati.
// - `.scorreSeStretto()`: una tabella dalle colonne fisse che su iOS, se non ci sta, scorre in orizzontale.
// - `ColonnaLateraleAdattiva` (solo iOS): l'elenco laterale che sotto `sogliaLaterale` si chiude in una
//   striscia con un pulsante e si apre sopra il contenuto.

private struct ChiaveLarghezzaApp: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

private struct ChiaveImpilato: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// La larghezza del contenuto dell'app misurata su iPhone e iPad; nil sul Mac (impaginazione del Mac).
    var larghezzaApp: CGFloat? {
        get { self[ChiaveLarghezzaApp.self] }
        set { self[ChiaveLarghezzaApp.self] = newValue }
    }

    /// true dentro `Affiancati` quando i blocchi sono uno sotto l'altro (mai sul Mac).
    var impilato: Bool {
        get { self[ChiaveImpilato.self] }
        set { self[ChiaveImpilato.self] = newValue }
    }
}

/// Le soglie di `Affiancati` (larghezza del contenuto dell'app sotto cui i blocchi vanno uno sotto l'altro).
/// Contano solo su iOS: sul Mac `Affiancati` affianca sempre e queste valgono 0.
enum SoglieAffiancati {
    #if os(iOS)
    static let posizioni = Tema.Misura.Mobile.sogliaAffiancatiPosizioni
    static let dettaglio = Tema.Misura.Mobile.sogliaAffiancatiDettaglio
    static let pannello = Tema.Misura.Mobile.sogliaAffiancatiPannello
    #elseif os(macOS)
    static let posizioni: CGFloat = 0
    static let dettaglio: CGFloat = 0
    static let pannello: CGFloat = 0
    #endif
}

/// Blocchi affiancati (HStack). Sul Mac sempre affiancati, come prima. Su iOS, se la larghezza misurata del
/// contenuto (`larghezzaApp`) è sotto `soglia`, vanno uno sotto l'altro a tutta larghezza.
struct Affiancati<Contenuto: View>: View {
    var soglia: CGFloat
    var allineamento: VerticalAlignment = .top
    var spazio: CGFloat? = nil
    @ViewBuilder let contenuto: () -> Contenuto
    #if os(iOS)
    @Environment(\.larghezzaApp) private var larghezza
    #endif

    var body: some View {
        #if os(iOS)
        if let larghezza, larghezza < soglia {
            VStack(alignment: .leading, spacing: Tema.Misura.Mobile.spazioImpilati) { contenuto() }
                .environment(\.impilato, true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: allineamento, spacing: spazio) { contenuto() }
        }
        #elseif os(macOS)
        HStack(alignment: allineamento, spacing: spazio) { contenuto() }
        #endif
    }
}

#if os(iOS)
private struct LarghezzaAffiancata: ViewModifier {
    let larghezza: CGFloat
    let allineamento: Alignment
    @Environment(\.impilato) private var impilato

    func body(content: Content) -> some View {
        if impilato {
            content.frame(maxWidth: .infinity, alignment: allineamento)
        } else {
            content.frame(width: larghezza, alignment: allineamento)
        }
    }
}

private struct LimitiAffiancati: ViewModifier {
    let minima: CGFloat?
    let massima: CGFloat?
    let allineamento: Alignment
    @Environment(\.impilato) private var impilato

    func body(content: Content) -> some View {
        if impilato {
            content.frame(maxWidth: .infinity, alignment: allineamento)
        } else {
            content.frame(minWidth: minima, maxWidth: massima, alignment: allineamento)
        }
    }
}

/// La tabella non ci sta: scorre in orizzontale alla sua larghezza ideale (la prima che si prova è quella
/// del Mac, che si sceglie quando ci sta).
private struct ScorreSeStretto: ViewModifier {
    func body(content: Content) -> some View {
        ViewThatFits(in: .horizontal) {
            content
            ScrollView(.horizontal, showsIndicators: true) {
                content.fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}
#endif

extension View {
    /// Un blocco a larghezza fissa dentro `Affiancati`: sul Mac `.frame(width:alignment:)`, come prima;
    /// su iOS a tutta larghezza quando i blocchi sono impilati.
    @ViewBuilder
    func larghezzaAffiancata(_ larghezza: CGFloat, alignment: Alignment = .center) -> some View {
        #if os(iOS)
        modifier(LarghezzaAffiancata(larghezza: larghezza, allineamento: alignment))
        #elseif os(macOS)
        frame(width: larghezza, alignment: alignment)
        #endif
    }

    /// Un blocco con larghezza minima o massima dentro `Affiancati`: sul Mac `.frame(minWidth:maxWidth:alignment:)`,
    /// come prima; su iOS a tutta larghezza quando i blocchi sono impilati.
    @ViewBuilder
    func limitiAffiancati(minima: CGFloat? = nil, massima: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        #if os(iOS)
        modifier(LimitiAffiancati(minima: minima, massima: massima, allineamento: alignment))
        #elseif os(macOS)
        frame(minWidth: minima, maxWidth: massima, alignment: alignment)
        #endif
    }

    /// Una tabella dalle colonne fisse: sul Mac resta com'è; su iOS, se non ci sta, scorre in orizzontale.
    @ViewBuilder
    func scorreSeStretto() -> some View {
        #if os(iOS)
        modifier(ScorreSeStretto())
        #elseif os(macOS)
        self
        #endif
    }

    /// Su iOS mette nell'ambiente la larghezza di questa vista (che deve riempire lo spazio che ha, come le
    /// colonne con `.frame(maxWidth: .infinity, maxHeight: .infinity)`); sul Mac non fa niente.
    @ViewBuilder
    func misuraLarghezzaApp(_ allineamento: Alignment = .center) -> some View {
        #if os(iOS)
        GeometryReader { g in
            self
                .environment(\.larghezzaApp, g.size.width)
                .frame(width: g.size.width, height: g.size.height, alignment: allineamento)
        }
        #elseif os(macOS)
        self
        #endif
    }
}

#if os(iOS)
/// L'area di tocco di un controllo disegnato più basso di 44 pt: il rettangolo della vista allargato in alto e
/// in basso (e, con `ancheLati`, ai lati) quanto basta per arrivare all'area di tocco, senza cambiare il disegno.
struct RettangoloTocco: Shape {
    let altezza: CGFloat
    let ancheLati: Bool

    func path(in r: CGRect) -> Path {
        let d = max(0, (Tema.Misura.Mobile.areaTocco - altezza) / 2)
        return Path(r.insetBy(dx: ancheLati ? -d : 0, dy: -d))
    }
}

/// L'elenco laterale di un'app (Posizioni, cornice degli strumenti, rubrica di Clienti) sull'iPad.
/// Con spazio (`sogliaLaterale`) sta a sinistra alla sua larghezza, come sul Mac. Sotto la soglia si chiude in
/// una striscia con un pulsante: toccato, l'elenco si apre in vetro sopra il contenuto, con un velo che si tocca
/// per chiuderlo. Il contenuto riceve nell'ambiente la larghezza che gli resta.
/// `laterale` porta già margini, fondo e filo a destra; la larghezza comprende il filo.
struct ColonnaLateraleAdattiva<Laterale: View, Contenuto: View>: View {
    let larghezzaLaterale: CGFloat
    var soglia: CGFloat = Tema.Misura.Mobile.sogliaLaterale
    var titolo: String = "elenco laterale"
    /// Quando cambia (per esempio il cliente scelto nella rubrica), l'elenco aperto sopra il contenuto si chiude.
    var chiudiAlCambio: AnyHashable? = nil
    @ViewBuilder let laterale: () -> Laterale
    @ViewBuilder let contenuto: () -> Contenuto
    @State private var aperta = false

    private typealias M = Tema.Misura.Mobile

    var body: some View {
        GeometryReader { g in
            let stretta = g.size.width < soglia
            let resto = max(0, g.size.width - (stretta ? M.strisciaLaterale : larghezzaLaterale))
            HStack(spacing: 0) {
                if stretta {
                    striscia
                } else {
                    laterale()
                        .frame(width: larghezzaLaterale)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                contenuto()
                    .environment(\.larghezzaApp, resto)
                    .frame(width: resto)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
            .overlay(alignment: .topLeading) {
                if stretta && aperta {
                    ZStack(alignment: .topLeading) {
                        Tema.Colore.Mobile.velo
                            .contentShape(Rectangle())
                            .onTapGesture { aperta = false }
                            .accessibilityLabel("Chiudi \(titolo)")
                            .accessibilityAddTraits(.isButton)
                        laterale()
                            .frame(width: larghezzaLaterale)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .clipShape(FormaVetro.arrotondata(M.raggioLateraleAperto))
                            .vetro(.pannello, forma: .arrotondata(M.raggioLateraleAperto))
                    }
                    .transition(.opacity)
                }
            }
            .animation(Tema.Moto.molla, value: aperta)
            .onChange(of: stretta) { if !$0 { aperta = false } }
            .onChange(of: chiudiAlCambio) { _ in aperta = false }
        }
    }

    /// L'elenco chiuso: una striscia con il pulsante che lo apre.
    private var striscia: some View {
        VStack(spacing: 0) {
            Button {
                aperta.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .font(Tipo.Mobile.pulsante)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .frame(width: M.areaTocco, height: M.areaTocco)
                    .contentShape(Rectangle())
            }
            .buttonStyle(StileSemplice())
            .accessibilityLabel(aperta ? "Chiudi \(titolo)" : "Mostra \(titolo)")
            .padding(.top, M.margineStriscia)
            Spacer(minLength: 0)
        }
        .frame(width: M.strisciaLaterale)
        .frame(maxHeight: .infinity)
        .background(Tema.Colore.Mobile.fondoLaterale)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Tema.Colore.Mobile.filoLaterale).frame(width: Tema.Misura.filo).allowsHitTesting(false)
        }
    }
}
#endif
