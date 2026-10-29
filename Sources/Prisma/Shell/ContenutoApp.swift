import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Contenuto di una finestra: l'intestazione dell'app e la sua vista.
struct ContenutoApp: View {
    let app: AppPrisma

    var body: some View {
        VStack(spacing: 0) {
            IntestazioneApp(app: app) { azioni }
            Group {
                switch app {
                case .clienti: AppClienti()
                case .posizioni: AppPosizioni()
                case .impostazioni: AppImpostazioni()
                case .agenda: AppAgenda()
                case .attivita: AppAttivita()
                case .simulazioni: AppSimulazioni()
                case .confronti: AppConfronti()
                case .analisi360: AppAnalisi360()
                case .eve: AppEve()
                case .incontri: AppIncontri()
                case .prodotti: AppProdotti()
                case .obiettivi: AppObiettivi()
                case .documenti: AppDocumenti()
                case .presentazioni: AppProspetti()
                case .ricerca: AppRicerca()
                case .note: AppNote()
                default: AppSegnaposto(app: app)
                }
            }
            // La Ricerca va da bordo a bordo, come una tabella di iOS
            .padding(.horizontal, app == .ricerca ? 0 : Misure.IntestazioneApp.margineOrizzontale)
            .padding(.vertical, app == .ricerca ? 0 : Misure.IntestazioneApp.margineContenuto)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Un contenuto più grande della finestra non si allarga né si centra fuori dai bordi:
            // l'intestazione resta al suo posto e l'eccesso finisce in basso e a destra, dove la finestra
            // lo taglia (ogni app scorre dentro i suoi pannelli: vedi l'elenco laterale di Posizioni)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .background(sfondo)
        }
    }
}

extension ContenutoApp {
    @ViewBuilder var sfondo: some View {
        switch app {
        case .impostazioni: FondoRighe()
        case .clienti: Colori.Rubrica.fondoApp
        case .note: Gradienti.fondoNote
        case .agenda: Colori.Agenda.fondoApp
        case .incontri: Gradienti.fondoIncontri
        case .eve: Gradienti.linoEve
        case .attivita: Gradienti.linoAttivita
        default: Colori.IntestazioneApp.corpo
        }
    }

    /// Pulsanti a destra nell'intestazione dell'app.
    @ViewBuilder var azioni: some View {
        switch app {
        case .clienti: AzioneNuovoCliente()
        case .posizioni: AzioniPosizioni()
        case .note: AzioneNuovaNota()
        default: EmptyView()
        }
    }
}

struct AzioneNuovoCliente: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        HStack(spacing: Misure.IntestazioneApp.spazioAzioni) {
            Button { stato.importaClientiDaFile() } label: {
                Label("Importa…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(StileVetro())
            .disabled(stato.solaLettura)
            .help("Importa clienti da un file vCard (app Contatti), Excel o CSV. Puoi anche trascinare il file sulla finestra.")
            Button { stato.incollaDaExcel(posizioni: false) } label: {
                Label("Incolla da Excel", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(StileVetro())
            .disabled(stato.solaLettura)
            .help("Incolla da Excel: copia in Excel le righe dei clienti con l'intestazione (⌘C), poi premi qui")
            // Il blu dell'app: la cosa da fare qui
            Button { stato.richiestaNuovoCliente = true } label: {
                Label("Nuovo cliente", systemImage: "person.badge.plus")
            }
            .buttonStyle(StileAqua())
            .help("Nuovo cliente: apri la scheda vuota e scrivi nome, contatti e situazione")
        }
    }
}

/// Intestazione dentro la finestra (.os-app-header): titolo, occhiello, «Come si usa» e azioni a destra.
/// Se lo spazio non basta toglie prima l'occhiello, poi lascia ai pulsanti di vetro la sola icona (con il
/// suggerimento): mai una parola tagliata dentro un pulsante. Il blu tiene sempre la scritta.
struct IntestazioneApp<Azioni: View>: View {
    let app: AppPrisma
    @ViewBuilder let azioni: () -> Azioni

    var body: some View {
        ViewThatFits(in: .horizontal) {
            riga(occhiello: true, soloIcona: false)
            riga(occhiello: false, soloIcona: false)
            riga(occhiello: false, soloIcona: true)
        }
        .padding(.horizontal, Misure.IntestazioneApp.margineOrizzontale)
        .padding(.vertical, Misure.IntestazioneApp.margineVerticale)
        .frame(minHeight: Misure.IntestazioneApp.altezzaMinima)
        .background(Gradienti.intestazioneApp)
        .bordoBasso(Colori.IntestazioneApp.bordo)
    }

    /// Una delle tre versioni della riga. `azioni()` si costruisce tre volte: le azioni dell'intestazione non
    /// hanno stato proprio (né fogli né importazioni: li apre `stato`), quindi si può.
    private func riga(occhiello: Bool, soloIcona: Bool) -> some View {
        HStack(alignment: .center, spacing: Misure.IntestazioneApp.spazio) {
            Text(app.titoloIntestazione)
                .font(Tipo.appTitolo)
                .foregroundColor(Colori.IntestazioneApp.titolo)
                .lineLimit(1)
            if occhiello {
                Text(app.occhiello.uppercased())
                    .font(Tipo.appOcchiello)
                    .foregroundColor(Colori.IntestazioneApp.occhiello)
                    .lineLimit(1)
            }
            Spacer(minLength: Misure.IntestazioneApp.spazio)
            Group {
                PulsanteComeSiUsa(app: app)
                azioni()
            }
            .environment(\.pulsantiSoloIcona, soloIcona)
        }
    }
}

/// Riquadro delle app non ancora sviluppate.
struct AppSegnaposto: View {
    let app: AppPrisma

    private var mostraCanali: Bool {
        [.posizioni, .analisi360, .prodotti, .confronti, .simulazioni, .obiettivi].contains(app)
    }

    var body: some View {
        VStack(spacing: 12) {
            IconaApp(app: app, lato: Misure.Scrivania.icona)
            Text(app.titolo)
                .font(Tipo.pannelloTitolo)
                .foregroundColor(Colori.Pannello.titolo)
            Text(app.sottotitolo)
                .font(Tipo.pannelloTesto)
                .foregroundColor(Colori.Pannello.testoSecondario)
            Text(app.inArrivo)
                .font(Tipo.pannelloTesto)
                .foregroundColor(Colori.Pannello.testo)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 380)
            if mostraCanali {
                HStack(spacing: 10) {
                    EtichettaCanale(canale: .alleanza)
                    EtichettaCanale(canale: .indipendente)
                }
                .padding(.top, 6)
            }
        }
        .padding(28)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.scheda))
    }
}

struct AzioniPosizioni: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        HStack(spacing: Misure.IntestazioneApp.spazioAzioni) {
            // Un lavoro del consulente su più clienti: in modo cliente non c'è
            if !stato.inModoCliente {
                Button {
                    // Con un file aperto si torna al suo elenco, altrimenti alla griglia dei valori fermi
                    let conFile = stato.aggiornaValori.map { !$0.righe.isEmpty } ?? false
                    stato.apriAggiornaValori(scheda: conFile ? .elenco : .griglia)
                } label: {
                    Label(TestiAggiornaValori.pulsante, systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(StileVetro())
                .disabled(stato.solaLettura)
                .help(TestiAggiornaValori.aiutoPulsante)
            }
            Button { stato.importaPosizioniDaFile() } label: {
                Label("Importa…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(StileVetro())
            .disabled(stato.solaLettura)
            .help("Importa posizioni da Excel o CSV (elenco delle polizze, portafoglio). Puoi anche trascinare il file sulla finestra.")
            Button { stato.incollaDaExcel(posizioni: true) } label: {
                Label("Incolla da Excel", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(StileVetro())
            .disabled(stato.solaLettura)
            .help("Incolla da Excel: copia in Excel le righe delle polizze con l'intestazione (⌘C), poi premi qui")
            Button { stato.richiestaNuovaPosizione = .proposta } label: {
                Label("Proposta", systemImage: "plus")
            }
            .buttonStyle(StileVetro())
            .help("Nuova proposta: un prodotto che proponi al cliente e che non ha ancora sottoscritto")
            // Il blu dell'app: la cosa da fare qui
            Button { stato.richiestaNuovaPosizione = .inEssere } label: {
                Label("Posizione", systemImage: "plus")
            }
            .buttonStyle(StileBlu())
            .help("Nuova posizione: un prodotto che il cliente ha già (polizza, fondo, conto, piano pensione)")
        }
    }
}
