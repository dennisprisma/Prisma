import SwiftUI

/// Contenuto di una finestra. In questa fase ogni app mostra l'intestazione e un riquadro "in arrivo".
struct ContenutoApp: View {
    let app: AppPrisma

    var body: some View {
        VStack(spacing: 0) {
            IntestazioneApp(app: app)
            Group {
                switch app {
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
        if app == .impostazioni {
            FondoRighe()
        } else {
            Colori.IntestazioneApp.corpo
        }
    }
}

/// Intestazione dentro la finestra (.os-app-header): titolo e occhiello.
struct IntestazioneApp: View {
    let app: AppPrisma

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Misure.IntestazioneApp.spazio) {
            Text(app.titoloIntestazione)
                .font(Tipo.appTitolo)
                .foregroundColor(Colori.IntestazioneApp.titolo)
            Text(app.occhiello.uppercased())
                .font(Tipo.appOcchiello)
                .foregroundColor(Colori.IntestazioneApp.occhiello)
            Spacer()
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
