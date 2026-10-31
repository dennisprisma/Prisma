#if os(iOS)
import SwiftUI

/// Il dock del tema in vetro (.dock) su iPhone e iPad: capsula di vetro sottile con raggio `Tema.Raggio.dock`, la
/// Scrivania, il divisore e le app. Il lato delle icone viene da `fitDock` del tema (DisposizioneDockMobile): tutte
/// le icone restano in vista, senza scorrere. Sul telefono niente nomi sotto le icone (Design/iphone.html: dock
/// compatto e centrato); sull'iPad i nomi solo dove ci stanno (passo ≥ 56 punti).
/// - telefono: Scrivania | Clienti, Posizioni, Agenda, Attività | «Tutte le app»;
/// - iPad: Scrivania | tutte le app consentite, come il Dock del Mac (⌥0…⌥9 con la tastiera).
struct DockMobile: View {
    typealias Stile = StileDockMobile

    let stile: Stile
    /// Larghezza dello schermo: il lato delle icone si adatta (fitDock).
    let larghezza: CGFloat

    @EnvironmentObject var mobile: StatoMobile
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var sistema: StatoFinestre

    private typealias D = Tema.Misura.Mobile.Dock

    var body: some View {
        let voci = DisposizioneDockMobile.app(stile, consentita: { stato.appConsentita($0) })
        // Scrivania + app (+ «Tutte le app» sul telefono)
        let elementi = voci.count + (stile == .telefono ? 2 : 1)
        let massimo = stile == .telefono ? D.massimoTelefono : D.massimoiPad
        let lato = DisposizioneDockMobile.lato(elementi: elementi, larghezza: larghezza, massimo: massimo)
        let nomi = DisposizioneDockMobile.conNomi(lato: lato, stile: stile)
        let spazio = lato * D.quotaSpazio
        let margine = lato * D.quotaMargine
        HStack(alignment: .top, spacing: spazio) {
            CellaDockMobile(titolo: "Scrivania", etichetta: "Scrivania",
                            descrizione: "Torna alla scrivania: la tua giornata e i widget",
                            lato: lato, nomi: nomi, puntino: false, scorciatoia: stile == .iPad ? "0" : nil) { _ in
                mobile.mostraHome()
            } icona: {
                ImmagineNitida(percorso: "Icone/Prisma.png", lato: lato)
            }
            DivisoreDockMobile(lato: lato)
            ForEach(Array(voci.enumerated()), id: \.element) { indice, app in
                CellaDockMobile(titolo: app.titolo, etichetta: app.nomeDock, descrizione: app.sottotitolo,
                                lato: lato, nomi: nomi, puntino: sistema.aperta(app) || mobile.appAperta == app,
                                scorciatoia: stile == .iPad && indice < 9 ? "\(indice + 1)" : nil) { origine in
                    mobile.apri(app, da: origine)
                } icona: {
                    IconaApp(app: app, lato: lato)
                }
            }
            if stile == .telefono {
                CellaDockMobile(titolo: "Tutte le app", etichetta: "Tutte le app",
                                descrizione: "Le app di Prisma in una griglia",
                                lato: lato, nomi: nomi, puntino: false, scorciatoia: nil) { _ in
                    mobile.pannello = mobile.pannello == .tutteLeApp ? nil : .tutteLeApp
                } icona: {
                    CartellaApp(lato: lato, app: AppPrisma.allCases.filter { stato.appConsentita($0) && !voci.contains($0) })
                }
            }
        }
        .padding(.vertical, margine)
        .padding(.horizontal, margine + D.margineFisso)
        .vetro(.leggero, forma: .arrotondata(Tema.Raggio.dock))
        .gruppoVetro()
    }
}

/// Un'icona del dock: l'icona, il nome sotto (se ci sta), il puntino dell'app aperta nel margine in basso. La cella
/// intera è l'area di tocco (alta almeno 44 punti); la pressione scurisce l'icona come nel tema (brightness .82).
/// `azione` riceve il centro dell'icona nello spazio della shell: l'app si apre da lì.
private struct CellaDockMobile<Icona: View>: View {
    let titolo: String
    let etichetta: String
    let descrizione: String
    let lato: CGFloat
    let nomi: Bool
    let puntino: Bool
    let scorciatoia: String?
    let azione: (CGPoint?) -> Void
    @ViewBuilder let icona: () -> Icona
    @State var origine = OrigineApertura()

    private typealias D = Tema.Misura.Mobile.Dock

    var body: some View {
        let m = Tema.Misura.Shell.self
        let pulsante = Button { azione(origine.punto) } label: {
            VStack(spacing: 0) {
                icona()
                    .frame(width: lato, height: lato)
                    .misuraOrigine(origine)
                if nomi {
                    Text(etichetta)
                        .font(Tema.Testo.Shell.etichettaDock)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: lato, height: m.etichettaDock)
                        .padding(.top, m.etichettaSpazio)
                }
            }
            // Il puntino (.dock-dot) sta nel margine sotto l'icona, senza alzare il dock
            .overlay(alignment: .bottom) {
                Circle()
                    .fill(Tema.Colore.Shell.puntinoDock)
                    .frame(width: Tema.Misura.puntinoDock, height: Tema.Misura.puntinoDock)
                    .offset(y: lato * D.quotaMargine / 2 + Tema.Misura.puntinoDock / 2)
                    .opacity(puntino ? 1 : 0)
            }
            .frame(minHeight: D.tocco, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileIconaDockMobile())
        .accessibilityLabel(Text(titolo))
        .accessibilityHint(Text(descrizione))
        if let scorciatoia, let tasto = scorciatoia.first {
            // ⌥0…⌥9 con la tastiera dell'iPad, come Dock.scorciatoia sul Mac
            pulsante.keyboardShortcut(KeyEquivalent(tasto), modifiers: .option)
        } else {
            pulsante
        }
    }
}

/// Icona premuta: più scura (brightness .82 del tema), come nel dock del Mac.
private struct StileIconaDockMobile: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? Tema.Misura.Shell.premutoDock : 0)
    }
}

/// Il divisore fra la Scrivania e le app (.dock-sep): un filo che sfuma in alto e in basso, margine 6 % del lato.
private struct DivisoreDockMobile: View {
    let lato: CGFloat

    private typealias D = Tema.Misura.Mobile.Dock

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Tema.Colore.pozzettoScuro.opacity(0), Tema.Colore.pozzettoScuro,
                                          Tema.Colore.pozzettoScuro.opacity(0)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: Tema.Misura.filo * 2, height: lato)
            .padding(.horizontal, DisposizioneDockMobile.margineDivisore(lato: lato))
            .accessibilityHidden(true)
    }
}

/// «Tutte le app» nel dock dell'iPhone: una tessera di vetro con le prime quattro app in miniatura, come una
/// cartella di iOS (niente PNG nuovo).
private struct CartellaApp: View {
    let lato: CGFloat
    let app: [AppPrisma]

    private typealias D = Tema.Misura.Mobile.Dock

    var body: some View {
        let mini = lato * D.quotaMiniatura
        let spazio = lato * D.quotaSpazioMiniature
        let quattro = Array(app.prefix(4))
        let righe = [Array(quattro.prefix(2)), Array(quattro.dropFirst(2))]
        VStack(spacing: spazio) {
            ForEach(0..<2, id: \.self) { r in
                HStack(spacing: spazio) {
                    ForEach(righe[r]) { a in
                        IconaApp(app: a, lato: mini)
                    }
                }
                .frame(width: mini * 2 + spazio, height: mini, alignment: .leading)
            }
        }
        .frame(width: lato, height: lato)
        .vetro(.chip, forma: .arrotondata(lato * D.quotaRaggioIcona), ombra: false)
    }
}

/// Il dock del telefono (quattro app e «Tutte le app») o dell'iPad (tutte le app).
enum StileDockMobile { case telefono, iPad }

/// Misure e app del dock, fuori dalla vista (le prova `ProvaDockMobile`): la formula `fitDock` del tema.
enum DisposizioneDockMobile {
    private typealias D = Tema.Misura.Mobile.Dock

    /// Le app del dock dell'iPhone (Eve sta sulla sua striscia della scrivania e in «Tutte le app»).
    static let appTelefono: [AppPrisma] = [.clienti, .posizioni, .agenda, .attivita]

    /// Le app nel dock per questo stile, solo quelle consentite (in modo cliente le riservate non ci sono).
    static func app(_ stile: StileDockMobile, consentita: (AppPrisma) -> Bool) -> [AppPrisma] {
        switch stile {
        case .telefono: return appTelefono.filter(consentita)
        case .iPad: return AppPrisma.allCases.filter(consentita)
        }
    }

    /// Il margine del divisore: 6 % del lato, almeno 2 punti (.dock-sep, --dock-sepm).
    static func margineDivisore(lato s: CGFloat) -> CGFloat { max(D.divisoreMinimo, s * D.quotaDivisore) }

    /// La larghezza del dock con `n` elementi (Scrivania compresa) e lato `s`: le icone, gli spazi fra loro e
    /// attorno al divisore, il divisore con i suoi margini e i margini della capsula (14 % del lato + 2).
    static func larghezza(elementi n: Int, lato s: CGFloat) -> CGFloat {
        let icone = CGFloat(max(0, n))
        let spazi = icone * s * D.quotaSpazio
        let divisore = Tema.Misura.filo * 2 + 2 * margineDivisore(lato: s)
        let capsula = 2 * (s * D.quotaMargine + D.margineFisso)
        return icone * s + spazi + divisore + capsula
    }

    /// fitDock del tema: il lato più grande (a passi di mezzo punto, fino a `massimo`) per cui il dock sta nella
    /// larghezza meno 12 punti; mai sotto `minimo` (l'area di tocco resta la cella intera).
    static func lato(elementi n: Int, larghezza w: CGFloat, massimo: CGFloat) -> CGFloat {
        let disponibile = w - D.bordo
        var s = massimo
        while s > D.minimo && larghezza(elementi: n, lato: s) > disponibile { s -= D.passo }
        return max(D.minimo, (s / D.passo).rounded(.down) * D.passo)
    }

    /// I nomi sotto le icone: mai sul telefono; sull'iPad solo se il passo (lato + spazio) è almeno quello del dock del Mac.
    static func conNomi(lato s: CGFloat, stile: StileDockMobile = .iPad) -> Bool {
        stile == .iPad && s * (1 + D.quotaSpazio) >= D.passoPerNomi - 0.001
    }

    /// L'altezza del dock con il lato `s` (margini, icona e, se ci stanno, i nomi).
    static func altezza(lato s: CGFloat, stile: StileDockMobile = .iPad) -> CGFloat {
        let m = Tema.Misura.Shell.self
        let nomi = conNomi(lato: s, stile: stile) ? m.etichettaSpazio + m.etichettaDock : 0
        return max(D.tocco, s + nomi) + 2 * s * D.quotaMargine
    }
}
#endif
