import SwiftUI

/// Contenuto di una finestra. In questa fase ogni app mostra l'intestazione e un riquadro "in arrivo".
struct ContenutoApp: View {
    let app: AppPrisma

    var body: some View {
        VStack(spacing: 0) {
            IntestazioneApp(app: app) { azioni }
            Group {
                switch app {
                case .clienti: AppClienti()
                case .impostazioni: AppImpostazioni()
                default: AppSegnaposto(app: app)
                }
            }
            .padding(.horizontal, Misure.IntestazioneApp.margineOrizzontale)
            .padding(.vertical, Misure.IntestazioneApp.margineVerticale)
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
        default: Colori.IntestazioneApp.corpo
        }
    }

    /// Pulsanti a destra nell'intestazione dell'app.
    @ViewBuilder var azioni: some View {
        if app == .clienti {
            AzioneNuovoCliente()
        }
    }
}

struct AzioneNuovoCliente: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        Button("＋ Nuovo cliente") { stato.richiestaNuovoCliente = true }
            .buttonStyle(StileAqua())
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
