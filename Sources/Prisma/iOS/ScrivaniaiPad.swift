#if os(iOS)
import SwiftUI

/// La scrivania dell'iPad: quella del Mac (Design/tema-liquid-glass.html) fra la barra e il dock. Il saluto a 34 punti
/// con i pulsanti di vetro, la striscia della guida, «La tua giornata» e la bacheca dei sei widget del Mac: quella del
/// Mac (`BachecaWidget`) da 1100 punti in su, sotto le due colonne del tema (@media 1100: righe 300 / 64 / 300 / 270),
/// poi il piede. Se l'altezza non basta (bacheca sotto i 520 punti del tema) la scrivania scorre.
struct ScrivaniaiPad: View {
    /// Dove comincia la scrivania (sotto la barra) e quanto lasciare in basso (il dock).
    let alto: CGFloat
    let basso: CGFloat

    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile

    private typealias S = Tema.Misura.Mobile.Scrivania

    var body: some View {
        GeometryReader { geo in
            // Margine laterale del tema: 3 % della larghezza, tra 16 e 44 punti; contenuto al massimo 1480
            let margine = min(max(geo.size.width * Tema.Misura.margineScrivaniaQuota, Tema.Misura.margineScrivaniaMinimo),
                              Tema.Misura.margineScrivaniaMassimo)
            let larga = geo.size.width >= S.sogliaDueColonne
            Group {
                if larga {
                    // La bacheca del Mac riempie l'altezza che resta; se è meno del minimo del tema, scorre
                    ViewThatFits(in: .vertical) {
                        contenuto(bachecaPiena: true)
                        ScrollView(.vertical, showsIndicators: false) { contenuto(bachecaPiena: false) }
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) { contenuto(bachecaPiena: false, dueColonne: true) }
                }
            }
            .frame(maxWidth: Tema.Misura.scrivaniaMassima)
            .padding(.horizontal, margine)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .padding(.top, alto)
        .padding(.bottom, basso)
    }

    /// Saluto, guida, intestazione, bacheca e piede. `bachecaPiena`: la bacheca prende tutta l'altezza che resta.
    private func contenuto(bachecaPiena: Bool, dueColonne: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            introduzione
            if stato.guidaVisibile && !stato.inModoCliente {
                StrisciaGuida()
                    .padding(.top, Tema.Misura.Shell.guidaAlto)
            }
            intestazioneBacheca
            if dueColonne {
                BachecaiPadVerticale()
            } else if bachecaPiena {
                BachecaWidget()
                    .frame(minHeight: S.bachecaMinima, maxHeight: .infinity)
            } else {
                BachecaWidget()
                    .frame(height: S.bachecaMinima)
            }
            piede
        }
        .padding(.top, Tema.Misura.Shell.scrivaniaAlto)
        .padding(.bottom, Tema.Misura.Shell.scrivaniaBasso)
    }

    /// .hero: il saluto a sinistra e i pulsanti a destra; se non ci stanno, i pulsanti vanno sotto (flex-wrap).
    private var introduzione: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                saluto
                Spacer(minLength: S.salutoPulsanti)
                pulsantiRapidi
                    .padding(.top, Tema.Misura.Shell.pulsantiAlto)
            }
            VStack(alignment: .leading, spacing: S.salutoPulsanti) {
                saluto
                pulsantiRapidi
            }
        }
    }

    private var saluto: some View {
        SalutoScrivaniaMobile(carattere: Tema.Testo.saluto, spaziatura: Tema.Testo.spaziaturaSaluto)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var pulsantiRapidi: some View {
        HStack(spacing: Tema.Misura.Shell.pulsantiSpazio) {
            Button {
                stato.cercaOvunque()
            } label: {
                HStack(spacing: Tema.Misura.Shell.pulsanteVetroSpazio) {
                    Image(systemName: "magnifyingglass")
                    Text("Cerca ovunque")
                    TastoBarra(testo: "⌘K")
                }
            }
            Button {
                stato.apriGuida(.introduzione(0))
            } label: {
                Label("Come funziona", systemImage: "questionmark.circle")
            }
        }
        .buttonStyle(StilePulsanteVetro())
        .labelStyle(EtichettaPulsante())
        .gruppoVetro()
        .fixedSize()
    }

    private var intestazioneBacheca: some View {
        HStack {
            Text("La tua giornata")
                .font(Tema.Testo.sezione)
                .tracking(Tema.Testo.spaziaturaSezione)
                .foregroundColor(Tema.Colore.inchiostroSfondo)
                .aloneSfondo()
            Spacer()
            Button {
                mobile.pannello = .appAperte
            } label: {
                HStack(spacing: Tema.Misura.Shell.pulsanteVetroSpazio) {
                    TestoAppAperteMobile()
                    Image(systemName: "square.grid.2x2.fill")
                }
            }
            .buttonStyle(StilePulsanteVetro(piccolo: true))
        }
        .padding(.top, Tema.Misura.Shell.sezioneAlto)
        .padding(.bottom, Tema.Misura.Shell.sezioneBasso)
        .padding(.horizontal, Tema.Misura.Shell.sezioneLato)
    }

    private var piede: some View {
        HStack {
            Button {
                stato.apriGuida(.introduzione(0))
            } label: {
                Text("Nuovo in Prisma? Apri la guida").underline()
            }
            .buttonStyle(StileSemplice())
            Spacer(minLength: Tema.Misura.Shell.pulsantiSpazio)
            Text(PiedeScrivaniaMobile.backup(stato))
        }
        .font(Tema.Testo.Shell.piede)
        .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
        .lineLimit(1)
        .aloneSfondo()
        .padding(.horizontal, Tema.Misura.Shell.sezioneLato)
        .padding(.top, Tema.Misura.Shell.piedeAlto)
    }
}

/// La bacheca a due colonne del tema sotto i 1100 punti (iPad in verticale):
///
///   ┌─ Agenda ─┐┌─ Cliente ─┐   300
///   │          │├─── Eve ───┤    64
///   └──────────┘└───────────┘
///   ┌─ Da fare ┐┌ Scadenze ─┐   300
///   ┌──── Portafoglio ──────┐   270
struct BachecaiPadVerticale: View {
    private typealias S = Tema.Misura.Mobile.Scrivania

    var body: some View {
        let s = Tema.Misura.grigliaSpazio
        VStack(spacing: s) {
            HStack(alignment: .top, spacing: s) {
                WidgetAgenda()
                    .frame(height: S.filaAlta + s + Tema.Misura.widgetEve)
                VStack(spacing: s) {
                    WidgetCliente().frame(height: S.filaAlta)
                    WidgetEve().frame(height: Tema.Misura.widgetEve)
                }
            }
            HStack(spacing: s) {
                WidgetAttivita()
                WidgetScadenze()
            }
            .frame(height: S.filaAlta)
            WidgetPortafoglio()
                .frame(height: S.filaPortafoglio)
        }
        // I sei vetri si campionano insieme, come nella bacheca del Mac
        .gruppoVetro()
    }
}
#endif
