#if os(iOS)
import SwiftUI

/// Il guscio dell'iPad: barra laterale con le app di Prisma nell'ordine del dock del Mac (Clienti e Posizioni,
/// il fulcro, in cima) e, nella colonna di dettaglio, le stesse viste `App*` del Mac con lo stesso StatoShell.
/// Nel giro 1 sono pronte Clienti, Posizioni e Agenda; le altre voci dicono «In arrivo su iPad».
struct GuscioiPad: View {
    @EnvironmentObject var mobile: StatoMobile
    @EnvironmentObject var stato: StatoShell
    @State private var colonne: NavigationSplitViewVisibility = .all

    /// Le app già portate sull'iPad (le altre arrivano nel giro 2).
    static let appPronte: Set<AppPrisma> = [.clienti, .posizioni, .agenda]

    private typealias M = Tema.Misura.Mobile

    var body: some View {
        NavigationSplitView(columnVisibility: $colonne) {
            BarraLateraleiPad()
                .navigationSplitViewColumnWidth(min: M.lateraleMinima, ideal: M.lateraleIdeale, max: M.lateraleMassima)
        } detail: {
            DettaglioiPad(app: mobile.appiPad)
                .toolbar { strumenti }
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationSplitViewStyle(.balanced)
    }

    /// Barra degli strumenti al posto della barra superiore del Mac: il cliente attivo e l'apertura del backup.
    @ToolbarContentBuilder private var strumenti: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            SceltaClienteMobile()
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                mobile.apriBackup()
            } label: {
                Label("Apri un backup", systemImage: "lock.doc")
            }
        }
    }
}

/// La barra laterale: logo di Prisma e le app con le loro icone in vetro.
private struct BarraLateraleiPad: View {
    @EnvironmentObject var mobile: StatoMobile

    private typealias M = Tema.Misura.Mobile

    var body: some View {
        List(selection: Binding<AppPrisma?>(get: { mobile.appiPad }, set: { if let app = $0 { mobile.appiPad = app } })) {
            Section {
                ForEach(AppPrisma.allCases) { app in
                    VoceLateraleiPad(app: app, pronta: GuscioiPad.appPronte.contains(app))
                        .tag(app)
                }
            } header: {
                LogoPrismaConNome(altezza: M.logoLaterale)
                    .padding(.vertical, M.spazioRiga)
                    .textCase(nil)
            }
        }
        .listStyle(.sidebar)
        // Il nome è già nel logo in cima: la barra della colonna resta senza titolo
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct VoceLateraleiPad: View {
    let app: AppPrisma
    let pronta: Bool

    private typealias M = Tema.Misura.Mobile

    var body: some View {
        HStack(spacing: M.spazioRiga) {
            IconaApp(app: app, lato: M.iconaLaterale)
            Text(app.nomeDock)
                .font(Tipo.Mobile.voceLaterale)
                .foregroundColor(pronta ? Tema.Colore.inchiostro : Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
        }
        .padding(.vertical, M.spazioTesto)
        .accessibilityElement(children: .combine)
        .accessibilityHint(pronta ? "" : "In arrivo su iPad")
    }
}

/// La colonna di dettaglio: l'app del Mac, o il segnaposto delle app che arrivano nei prossimi giri.
private struct DettaglioiPad: View {
    let app: AppPrisma

    var body: some View {
        if GuscioiPad.appPronte.contains(app) {
            ContenutoApp(app: app)
                .id(app)
        } else if app == .eve {
            InArrivoMobile(app: app, titolo: "Eve non è ancora disponibile qui", testo: MotoreLocale.nonSuiOS)
        } else {
            InArrivoMobile(app: app, titolo: "In arrivo su iPad",
                           testo: "\(app.titolo) arriva nei prossimi aggiornamenti di Prisma per iPad. Intanto la trovi in Prisma sul Mac.")
        }
    }
}

/// Segnaposto in vetro per le app non ancora portate (iPad) o non disponibili (Eve).
struct InArrivoMobile: View {
    let app: AppPrisma
    let titolo: String
    let testo: String
    @Environment(\.colorScheme) private var schema

    private typealias M = Tema.Misura.Mobile

    var body: some View {
        ZStack {
            SfondoAcquaFermo(scuro: schema == .dark)
                .ignoresSafeArea()
            VStack(spacing: M.spazioApertura) {
                IconaApp(app: app, lato: M.iconaInArrivo)
                Text(titolo)
                    .font(Tipo.Mobile.titolo)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .multilineTextAlignment(.center)
                Text(testo)
                    .font(Tipo.Mobile.corpo)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: M.testoInArrivoMassimo)
            .padding(M.margineApertura)
            .vetro(.pannello, forma: .arrotondata(Tema.Raggio.Mobile.apertura))
            .padding(M.margine)
        }
    }
}

/// Il cliente attivo (lo stesso del Mac: Clienti, Posizioni e Agenda lo seguono), scelto da un menu.
struct SceltaClienteMobile: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        Menu {
            Picker("Cliente", selection: Binding(get: { stato.clienteAttivoId }, set: { stato.clienteAttivoId = $0 })) {
                ForEach(stato.clienti) { cliente in
                    Text(cliente.nome).tag(cliente.id)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(stato.clienteAttivo?.nome ?? "Cliente", systemImage: "person.crop.circle")
                .labelStyle(.titleAndIcon)
        }
        .disabled(stato.clienti.isEmpty)
    }
}
#endif
