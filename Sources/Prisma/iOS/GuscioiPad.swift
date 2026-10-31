#if os(iOS)
import SwiftUI
// UTType (contentType del backup) senza contare sulle importazioni di passaggio
import UniformTypeIdentifiers

/// Il guscio dell'iPad: la scrivania del Mac (Design/tema-liquid-glass.html) con la barra in alto, i sei widget, il dock
/// con tutte le app e un'app alla volta in una finestra di vetro fra la barra e il dock (come una finestra ingrandita
/// del Mac), che entra ed esce con il movimento del Mac. Dentro la finestra le stesse viste `App*` del Mac con lo stesso
/// StatoShell (tutte tranne Eve, giro 4). Ciò che sul Mac apre la shell sopra le finestre (Ricerca come Spotlight,
/// notifiche, guida, presentazione) qui si apre sopra tutto (PannelliMobile); i pannelli di apertura del Mac diventano
/// `.fileImporter` e `.fileExporter`; i moduli (nuovo cliente, posizione, appuntamento…) sono i fogli delle app.
/// Sotto tutto l'acqua animata di RadiceMobile.
struct GuscioiPad: View {
    @EnvironmentObject var mobile: StatoMobile
    @EnvironmentObject var stato: StatoShell

    /// Le app portate sull'iPad: tutte tranne Eve, che arriva con Qwen in rete locale (giro 4).
    /// Tutte le app del Mac, Eve compresa (Qwen del Mac in Wi‑Fi, PonteEve).
    static let appPronte: Set<AppPrisma> = Set(AppPrisma.allCases)

    private typealias D = Tema.Misura.Mobile.Dock

    var body: some View {
        // La safe area si legge da fuori: dentro una vista che la ignora i margini valgono zero
        GeometryReader { esterno in
        let sicuro = esterno.safeAreaInsets
        GeometryReader { geo in
            let misura = geo.size
            let sottoBarra = sicuro.top + Tema.Misura.Mobile.Barra.altezza
            let voci = DisposizioneDockMobile.app(.iPad, consentita: { stato.appConsentita($0) }).count + 1
            let lato = DisposizioneDockMobile.lato(elementi: voci, larghezza: misura.width, massimo: D.massimoiPad)
            let sopraDock = max(D.dalBassoiPad, sicuro.bottom) + DisposizioneDockMobile.altezza(lato: lato)
            let aperta = mobile.appAperta != nil
            ZStack(alignment: .topLeading) {
                // Sotto la finestra la scrivania resta costruita (i widget non si rifanno a ogni ritorno) ma non si
                // disegna, non prende i tocchi e VoiceOver non la legge
                ScrivaniaiPad(alto: sottoBarra, basso: sopraDock)
                    .frame(width: misura.width, height: misura.height)
                    .opacity(aperta ? 0 : 1)
                    .allowsHitTesting(!aperta)
                    .accessibilityHidden(aperta)

                if let app = mobile.appAperta {
                    FinestraMobile(app: app,
                                   cornice: GuscioiPhone.cornice(misura: misura, sottoBarra: sottoBarra, sopraDock: sopraDock),
                                   spazio: misura, raggio: Tema.Raggio.Mobile.finestraiPad,
                                   origine: mobile.origineApertura, animata: mobile.persistente, conBarra: true) {
                        ContenutoiPad(app: app)
                    }
                    .id(app)
                }

                BarraMobile(compatta: false, alto: sicuro.top)

                DockMobile(stile: .iPad, larghezza: misura.width)
                    .padding(.bottom, max(D.dalBassoiPad, sicuro.bottom))
                    .frame(width: misura.width, height: misura.height, alignment: .bottom)

                PannelliMobile(sistema: stato.sistema, sottoBarra: sottoBarra, misura: misura)
            }
            .frame(width: misura.width, height: misura.height, alignment: .topLeading)
            // Una volta, qui, sulla vista che ignora la safe area: le origini dei widget e del dock sono nel suo spazio
            .coordinateSpace(name: ShellView.spazioShell)
        }
        .ignoresSafeArea(.container)
        }
        .modifier(SceltaFileiPad())
        .modifier(EsportaBackupiPad())
    }
}

/// Il contenuto della finestra dell'iPad: l'app del Mac.
private struct ContenutoiPad: View {
    let app: AppPrisma

    var body: some View {
        ContenutoApp(app: app)
    }
}

/// I pannelli di apertura del Mac (`importaClientiDaFile`, `importaPosizioniDaFile`, `scegliFileValori`) su
/// iPhone e iPad: `StatoShell.sceltaFileMobile` apre il selettore dei file, StatoMobile legge la copia del file scelto.
struct SceltaFileiPad: ViewModifier {
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
/// iCloud Drive con `.fileExporter`; salvato o annullato, la copia si cancella (iPhone e iPad).
struct EsportaBackupiPad: ViewModifier {
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

/// Segnaposto in vetro per le app non ancora portate (iPhone) o non disponibili (Eve), dentro la finestra di vetro.
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
