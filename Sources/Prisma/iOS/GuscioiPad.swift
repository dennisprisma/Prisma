#if os(iOS)
import SwiftUI
// UTType (contentType del backup) senza contare sulle importazioni di passaggio
import UniformTypeIdentifiers

/// Il guscio dell'iPad: barra laterale con le app di Prisma nell'ordine del dock del Mac (Clienti e Posizioni,
/// il fulcro, in cima) e, nella colonna di dettaglio, le stesse viste `App*` del Mac con lo stesso StatoShell.
/// Dal giro 2 ci sono tutte le app tranne Eve (giro 4). Ciò che sul Mac apre la shell sopra le finestre (Ricerca
/// come Spotlight, guida, presentazione) qui si apre sopra il guscio; i pannelli di apertura del Mac diventano
/// `.fileImporter` e `.fileExporter`; i moduli (nuovo cliente, posizione, appuntamento…) sono i fogli delle app.
struct GuscioiPad: View {
    @EnvironmentObject var mobile: StatoMobile
    @EnvironmentObject var stato: StatoShell
    @State private var colonne: NavigationSplitViewVisibility = .all

    /// Le app portate sull'iPad: tutte tranne Eve, che arriva con Qwen in rete locale (giro 4).
    static let appPronte: Set<AppPrisma> = Set(AppPrisma.allCases).subtracting([.eve])

    private typealias M = Tema.Misura.Mobile

    var body: some View {
        NavigationSplitView(columnVisibility: $colonne) {
            BarraLateraleiPad()
                // Trasparente: sotto c'è il vetro della barra laterale di iPadOS, non un fondo pieno
                .scrollContentBackground(.hidden)
                .navigationSplitViewColumnWidth(min: M.lateraleMinima, ideal: M.lateraleIdeale, max: M.lateraleMassima)
        } detail: {
            DettaglioiPad(app: mobile.appiPad)
                // L'acqua della scrivania dietro le app, come sul Mac: animata sull'iPad (SfondoAcquaMobile),
                // ferma nelle istantanee; si ferma sotto la sala della presentazione, che la copre tutta
                .background {
                    Materiale.SfondoScrivania(animato: stato.dati.impostazioni.sfondoAnimato && stato.presentazione == nil,
                                              intensita: stato.dati.impostazioni.pioggia.forza)
                }
                .toolbar { strumenti }
                .navigationBarTitleDisplayMode(.inline)
                .modifier(EsportaBackupiPad())
        }
        .navigationSplitViewStyle(.balanced)
        .modifier(SceltaFileiPad())
        // Sopra tutto, come nella shell del Mac: Ricerca, guida e presentazione
        .overlay { PannelliiPad(sistema: stato.sistema) }
    }

    /// Barra degli strumenti al posto della barra superiore del Mac: la ricerca, il cliente attivo e
    /// l'apertura del backup.
    @ToolbarContentBuilder private var strumenti: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                stato.cercaOvunque()
            } label: {
                Label("Cerca", systemImage: "magnifyingglass")
            }
            // ⌘K come sul Mac, con la tastiera dell'iPad
            .keyboardShortcut("k", modifiers: .command)
        }
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
        List(selection: Binding<AppPrisma?>(get: { mobile.appiPad }, set: { if let app = $0 { mobile.mostra(app) } })) {
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

/// La colonna di dettaglio: l'app del Mac in una finestra di vetro sopra l'acqua (come le finestre interne
/// del Mac, ma sempre ingrandita), o il segnaposto di Eve (giro 4).
private struct DettaglioiPad: View {
    let app: AppPrisma

    private typealias M = Tema.Misura.Mobile

    var body: some View {
        if GuscioiPad.appPronte.contains(app) {
            let forma = FormaVetro.arrotondata(Tema.Raggio.Mobile.finestra)
            ContenutoApp(app: app)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                // Il contenuto si taglia prima del vetro: dopo taglierebbe anche le ombre
                .clipShape(forma)
                .vetro(.finestra(attiva: true), forma: forma)
                .padding(.horizontal, M.margineFinestra)
                .padding(.bottom, M.margineFinestra)
                .id(app)
        } else {
            InArrivoMobile(app: app, titolo: "Eve non è ancora disponibile qui", testo: MotoreLocale.nonSuiOS)
        }
    }
}

/// Ricerca (⌘K, il pannello come Spotlight), guida di Prisma e presentazione all'incontro sopra il guscio,
/// come i livelli di CorpoShell sul Mac. Osserva solo StatoFinestre e la presentazione.
private struct PannelliiPad: View {
    @EnvironmentObject var stato: StatoShell
    @ObservedObject var sistema: StatoFinestre

    var body: some View {
        ZStack {
            if sistema.pannelloRicerca {
                RicercaSpotlight()
                    .transition(.opacity)
            }
            if sistema.guida != nil {
                PannelloGuida()
                    .transition(.opacity)
            }
            if let p = stato.presentazione {
                VistaPresentazione(p: p)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(Movimenti.curva(Tema.Moto.Spotlight.entrata), value: sistema.pannelloRicerca)
        .animation(Movimenti.curva(Tema.Moto.Guida.entrata), value: sistema.guida != nil)
    }
}

/// I pannelli di apertura del Mac (`importaClientiDaFile`, `importaPosizioniDaFile`, `scegliFileValori`) su
/// iPad: `StatoShell.sceltaFileMobile` apre il selettore dei file, StatoMobile legge la copia del file scelto.
private struct SceltaFileiPad: ViewModifier {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile
    /// L'ultima scelta: il selettore toglie la richiesta prima di dare il file.
    @State private var ultima: SceltaFileMobile = .clienti

    func body(content: Content) -> some View {
        content
            .onChange(of: stato.sceltaFileMobile) { nuova in
                if let nuova { ultima = nuova }
            }
            .fileImporter(isPresented: Binding(get: { stato.sceltaFileMobile != nil },
                                               set: { if !$0 { stato.sceltaFileMobile = nil } }),
                          allowedContentTypes: (stato.sceltaFileMobile ?? ultima).tipi) { esito in
                let scelta = stato.sceltaFileMobile ?? ultima
                stato.sceltaFileMobile = nil
                mobile.importa(esito, per: scelta)
            }
    }
}

/// Il backup da rimandare al Mac (Impostazioni › Archivio, ArchivioMobile): pronto in tmp/, si salva in File o
/// iCloud Drive con `.fileExporter`; salvato o annullato, la copia si cancella.
private struct EsportaBackupiPad: ViewModifier {
    @EnvironmentObject var mobile: StatoMobile

    func body(content: Content) -> some View {
        content
            .fileExporter(isPresented: Binding(get: { mobile.backupDaInviare != nil },
                                               set: { aperto in
                                                   // Annullato: la copia si cancella appena il selettore è chiuso
                                                   if !aperto { DispatchQueue.main.async { mobile.scartaBackupDaInviare() } }
                                               }),
                          document: mobile.backupDaInviare,
                          contentType: .backupPrisma,
                          defaultFilename: mobile.backupDaInviare?.url.lastPathComponent) { esito in
                mobile.backupInviato(esito)
            }
    }
}

/// Segnaposto in vetro per le app non ancora portate (iPad) o non disponibili (Eve). Sta sopra l'acqua della
/// colonna di dettaglio (GuscioiPad): non ne disegna una sua.
struct InArrivoMobile: View {
    let app: AppPrisma
    let titolo: String
    let testo: String

    private typealias M = Tema.Misura.Mobile

    var body: some View {
        ZStack {
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
