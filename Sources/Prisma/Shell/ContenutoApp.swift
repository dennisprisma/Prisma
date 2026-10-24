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
            .padding(.vertical, app == .ricerca ? 0 : Misure.IntestazioneApp.margineVerticale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(sfondo)
        }
    }
}

extension ContenutoApp {
    @ViewBuilder var sfondo: some View {
        switch app {
        case .impostazioni: FondoRighe()
        case .clienti: Colori.Rubrica.fondoApp
        case .note:
            ZStack {
                Gradienti.fondoNote
                Materiale.Trama(nome: "Grana")
            }
        case .agenda: Colori.Agenda.fondoApp
        case .incontri:
            ZStack {
                Gradienti.fondoIncontri
                Materiale.Trama(nome: "Grana")
            }
        case .eve:
            ZStack {
                Gradienti.linoEve
                Materiale.Trama(nome: "Lino_trama")
            }
        case .attivita:
            ZStack {
                Gradienti.linoAttivita
                Materiale.Trama(nome: "Lino_trama")
            }
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
        HStack(spacing: 8) {
            Button("Importa…") { importa() }
                .buttonStyle(StileAqua())
                .disabled(stato.solaLettura)
                .help("Importa clienti da un file vCard (app Contatti) o CSV (Excel, Numbers)")
            Button("＋ Nuovo cliente") { stato.richiestaNuovoCliente = true }
                .buttonStyle(StileAqua())
        }
    }

    private func importa() {
        let pannello = NSOpenPanel()
        pannello.allowedContentTypes = [.vCard, .commaSeparatedText, .tabSeparatedText, .plainText]
        pannello.allowsMultipleSelection = false
        pannello.message = "Un file vCard (dall'app Contatti: seleziona i contatti e trascinali sulla scrivania) o un CSV esportato da Excel o Numbers. Il file resta sul Mac."
        guard pannello.runModal() == .OK, let url = pannello.url else { return }
        if let lettura = ImportaClienti.leggi(url, rubrica: stato.clienti) {
            stato.apri(.clienti)
            stato.importazione = lettura
        } else {
            stato.mostraAvviso("Nel file non ho trovato contatti con un nome. Per Excel salva come CSV, con i nomi delle colonne nella prima riga.")
        }
    }
}

/// Intestazione dentro la finestra (.os-app-header): titolo, occhiello e azioni a destra.
struct IntestazioneApp<Azioni: View>: View {
    let app: AppPrisma
    @ViewBuilder let azioni: () -> Azioni

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Misure.IntestazioneApp.spazio) {
            Text(app.titoloIntestazione)
                .font(Tipo.appTitolo)
                .foregroundColor(Colori.IntestazioneApp.titolo)
            Text(app.occhiello.uppercased())
                .font(Tipo.appOcchiello)
                .foregroundColor(Colori.IntestazioneApp.occhiello)
            Spacer()
            azioni()
        }
        .incisione(Colori.IntestazioneApp.incisione)
        .padding(.horizontal, Misure.IntestazioneApp.margineOrizzontale)
        .padding(.vertical, Misure.IntestazioneApp.margineVerticale)
        .frame(minHeight: 46)
        .background(Gradienti.intestazioneApp)
        .luceInterna(Colori.IntestazioneApp.luce)
        .bordoBasso(Colori.IntestazioneApp.bordo)
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
                .ombraCSS(Colori.Scrivania.iconaOmbra1, y: 2, sfocatura: 1)
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
        .background(RoundedRectangle(cornerRadius: Misure.Pannello.raggio).fill(Colori.Pannello.sfondo))
        .overlay(RoundedRectangle(cornerRadius: Misure.Pannello.raggio).strokeBorder(Colori.Pannello.bordo, lineWidth: 1))
    }
}

struct AzioniPosizioni: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        HStack(spacing: 8) {
            Button("Importa…") { importa() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
                .disabled(stato.solaLettura)
                .help("Importa posizioni da un CSV (elenco delle polizze, portafoglio esportato da Excel)")
            Button("＋ Proposta") { stato.richiestaNuovaPosizione = .proposta }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
            Button("＋ Posizione") { stato.richiestaNuovaPosizione = .inEssere }
                .buttonStyle(StileBlu())
        }
    }

    private func importa() {
        let pannello = NSOpenPanel()
        pannello.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .plainText]
        pannello.allowsMultipleSelection = false
        pannello.message = "Un CSV con una posizione per riga e i nomi delle colonne nella prima (da Excel o Numbers: «Salva come» CSV). I clienti devono essere già in rubrica."
        guard pannello.runModal() == .OK, let url = pannello.url else { return }
        if let lettura = ImportaPosizioni.leggi(url, clienti: stato.clienti, posizioni: stato.posizioni) {
            stato.importazionePosizioni = lettura
        } else {
            stato.mostraAvviso("Nel file non ho trovato posizioni: servono almeno il prodotto o il numero di contratto, con i nomi delle colonne nella prima riga.")
        }
    }
}
