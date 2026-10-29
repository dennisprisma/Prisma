#if os(iOS)
import SwiftUI

/// Le app aperte sull'iPad (lo switcher del tema, .switcher: largo al massimo 760, schede .sw-card di almeno 150
/// punti): dalla barra (il nome dell'app) e da «N app aperte» sulla scrivania. Un tocco porta l'app nella finestra
/// con il suo stato; «Scrivania» torna ai widget; «Chiudi tutte» chiude le app (lo stato dei dati resta).
struct AppAperteiPad: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile
    @EnvironmentObject var sistema: StatoFinestre

    private typealias P = Tema.Misura.Mobile.Pannelli

    var body: some View {
        let aperte = Array(sistema.elenco.reversed())
        VStack(alignment: .leading, spacing: P.sottoTitolo) {
            Text("App aperte")
                .font(Tipo.Mobile.titoloPannello)
                .foregroundColor(Tema.Colore.inchiostro)
            if aperte.isEmpty {
                Text("Nessuna app aperta: aprine una dal dock.")
                    .font(Tema.Testo.secondario)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: P.schedaApp), spacing: P.spazioAppAperte)],
                              spacing: P.spazioAppAperte) {
                        ForEach(aperte) { f in
                            SchedaAppApertaMobile(finestra: f, davanti: f.app == mobile.appAperta) {
                                mobile.passaA(f.app)
                            }
                        }
                    }
                }
            }
            HStack(spacing: Tema.Misura.Shell.pulsantiSpazio) {
                Button("Scrivania") { mobile.mostraHome() }
                    .buttonStyle(StileVetro())
                if !aperte.isEmpty {
                    Button("Chiudi tutte") { chiudiTutte(aperte) }
                        .buttonStyle(StileVetro())
                }
                Spacer(minLength: 0)
                Button("Fatto") { mobile.pannello = nil }
                    .buttonStyle(StileBlu())
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(P.margineAppAperte)
        .vetro(.pannello, forma: .arrotondata(Tema.Raggio.appAperte), riempimento: Tema.Colore.PannelliShell.coprente)
    }

    /// Chiude tutte le app aperte (StatoShell le toglie come sul Mac) e torna alla scrivania.
    private func chiudiTutte(_ aperte: [StatoShell.Finestra]) {
        mobile.mostraHome()
        for f in aperte { stato.chiudi(f.app) }
    }
}

/// Una scheda dello switcher (.sw-card): l'icona, il nome, di chi parla e se è nella finestra.
private struct SchedaAppApertaMobile: View {
    @EnvironmentObject var stato: StatoShell
    let finestra: StatoShell.Finestra
    let davanti: Bool
    let azione: () -> Void

    private typealias P = Tema.Misura.Mobile.Pannelli

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: Tema.Raggio.Mobile.tessera, style: .continuous)
        Button(action: azione) {
            VStack(spacing: P.spazioSchedaApp) {
                IconaApp(app: finestra.app, lato: P.iconaSchedaApp)
                Text(finestra.app.titolo)
                    .font(Tipo.Mobile.nomeAppAperta)
                    .foregroundColor(Tema.Colore.inchiostro)
                // Il cliente (o il contesto) di questa app; una riga vuota tiene le schede alte uguali
                Text(stato.contesto(di: finestra.app) ?? " ")
                    .font(Tema.Testo.Shell.contestoAppAperta)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                Text(davanti ? "Nella finestra" : "Aperta")
                    .font(Tema.Testo.Shell.statoAppAperta)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
            .padding(P.margineSchedaApp)
            .background(forma.fill(Tema.Colore.pozzetto))
            .overlay(forma.strokeBorder(davanti ? Tema.Colore.accento : Tema.Colore.separatore,
                                        lineWidth: davanti ? Tema.Misura.filo * 4 : Tema.Misura.filo))
            .contentShape(forma)
        }
        .buttonStyle(StileSemplice())
        .accessibilityElement(children: .combine)
    }
}
#endif
