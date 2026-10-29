#if os(iOS)
import SwiftUI

/// La barra superiore del tema (.bar) per il tocco: sta sotto la barra di stato di iOS, che ha già ora e data (niente
/// .bar-clock). Niente fondo: solo il velo che sfuma sotto (--bar-shade). A sinistra il marchio (torna alla
/// scrivania) e, sull'iPad, l'app in primo piano; a destra gli strumenti nella capsula di vetro sottile (.bar-tools).
/// `compatta` (iPhone, @media 760 del tema): senza il nome dell'app e senza la scritta «Cerca ⌘K».
/// Niente lucchetto: su iPhone e iPad non c'è la schermata di benvenuto.
struct BarraMobile: View {
    let compatta: Bool
    /// L'altezza della barra di stato di iOS sopra la barra (la safe area in alto).
    let alto: CGFloat

    @EnvironmentObject var mobile: StatoMobile
    @EnvironmentObject var stato: StatoShell

    private typealias B = Tema.Misura.Mobile.Barra

    var body: some View {
        HStack(spacing: B.spazio) {
            marchio
            if !compatta { appCorrente }
            Spacer(minLength: B.spazio)
            strumenti
        }
        .padding(.leading, B.margineSinistro)
        .padding(.trailing, B.margineDestro)
        .frame(height: B.altezza)
        .padding(.top, alto)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // Il velo scende oltre la barra e sfuma (.bar::before)
            LinearGradient(colors: [Tema.Colore.veloBarra, Tema.Colore.veloBarra.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: alto + B.altezza + Tema.Misura.veloBarra)
                .allowsHitTesting(false)
        }
    }

    /// Il logo e «Prisma» (.bar-brand): torna alla scrivania.
    private var marchio: some View {
        Button { mobile.mostraHome() } label: {
            HStack(spacing: B.marchioSpazio) {
                LogoPrisma(colore: Tema.Colore.logo)
                    .frame(height: B.logo)
                Text("Prisma")
                    .font(Tipo.Mobile.barraMarchio)
                    .tracking(Tema.Testo.Shell.spaziaturaMarchio)
                    .foregroundColor(Tema.Colore.inchiostroSfondo)
            }
            .padding(.leading, B.marchioMargineSinistro)
            .padding(.trailing, B.marchioMargine)
            .frame(height: B.marchio)
            .aloneSfondo()
            .frame(minHeight: B.tocco)
        }
        .buttonStyle(StilePulsanteBarraMobile(altezza: B.marchio))
        .accessibilityLabel(Text("Prisma"))
        .accessibilityHint(Text("Torna alla scrivania"))
        // ⌘H come «Mostra la scrivania», con la tastiera dell'iPad
        .keyboardShortcut("h", modifiers: .command)
    }

    /// Solo iPad: il nome dell'app nella finestra («Scrivania» se non c'è) con il chevron (.bar-app): apre le app aperte.
    private var appCorrente: some View {
        Button {
            if stato.pannelloNotifiche { stato.pannelloNotifiche = false }
            mobile.pannello = mobile.pannello == .appAperte ? nil : .appAperte
        } label: {
            HStack(spacing: B.pulsanteSpazio) {
                Text(mobile.appAperta?.titolo ?? "Scrivania")
                    .font(Tipo.Mobile.barraApp)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(Tema.Testo.Shell.chevron)
            }
            .foregroundColor(Tema.Colore.inchiostroSfondo)
            .padding(.horizontal, B.marchioMargine)
            .frame(height: B.marchio)
            .aloneSfondo()
            .frame(minHeight: B.tocco)
        }
        .buttonStyle(StilePulsanteBarraMobile(altezza: B.marchio))
        .accessibilityLabel(Text("App aperte"))
        .accessibilityValue(Text(mobile.appAperta?.titolo ?? "Scrivania"))
    }

    /// Gli strumenti a destra, nella capsula di vetro sottile alta 36 (i pulsanti sono alti 44: l'area del dito).
    private var strumenti: some View {
        HStack(spacing: B.strumentiSpazio) {
            if stato.inModoCliente {
                ContrassegnoModoCliente()
                    .padding(.horizontal, B.strumentiMargine)
            } else {
                PulsanteBarraMobile(aiuto: "Cerca in Prisma", azione: { stato.alternaRicerca() }) {
                    HStack(spacing: B.pulsanteSpazio) {
                        Image(systemName: "magnifyingglass").font(Tipo.Mobile.simboloBarra)
                        if !compatta {
                            Text("Cerca").font(Tema.Testo.Shell.pulsanteBarra)
                            TastoBarra(testo: "⌘K")
                        }
                    }
                }
                .keyboardShortcut("k", modifiers: .command)

                PulsanteBarraMobile(aiuto: "Centro di controllo", azione: alternaControllo) {
                    Image(systemName: "switch.2").font(Tipo.Mobile.simboloBarra)
                }

                PulsanteBarraMobile(aiuto: "Centro notifiche", azione: alternaNotifiche) {
                    Image(systemName: "bell")
                        .font(Tipo.Mobile.simboloBarra)
                        .overlay(alignment: .topTrailing) {
                            let n = stato.notificheNuove
                            if n > 0 {
                                Badge(numero: n, grande: false)
                                    .offset(x: B.spostamentoBadge.width, y: B.spostamentoBadge.height)
                            }
                        }
                }
            }

            if !compatta {
                SceltaClienteMobile()
                    .font(Tema.Testo.Shell.pulsanteBarra)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .padding(.horizontal, B.pulsanteMargine)
                    .frame(minHeight: B.tocco)
            }

            if stato.appConsentita(.impostazioni) {
                PulsanteBarraMobile(aiuto: "Impostazioni", azione: { mobile.apri(.impostazioni) }) {
                    AvatarUtenteMobile(iniziali: stato.inizialiUtente)
                }
            }
        }
        .foregroundColor(Tema.Colore.inchiostro)
        .padding(.horizontal, B.strumentiMargine)
        .background {
            Color.clear
                .frame(height: B.strumenti)
                .vetro(.leggero, forma: .capsula)
        }
    }

    private func alternaControllo() {
        if stato.pannelloNotifiche { stato.pannelloNotifiche = false }
        mobile.pannello = mobile.pannello == .controllo ? nil : .controllo
    }

    private func alternaNotifiche() {
        mobile.pannello = nil
        stato.alternaNotifiche()
    }
}

/// Un pulsante della capsula degli strumenti: largo almeno 40, alto 44 (il dito), il chip chiaro alla pressione.
private struct PulsanteBarraMobile<Etichetta: View>: View {
    let aiuto: String
    let azione: () -> Void
    @ViewBuilder let etichetta: () -> Etichetta

    private typealias B = Tema.Misura.Mobile.Barra

    var body: some View {
        Button(action: azione) {
            etichetta()
                .padding(.horizontal, B.pulsanteMargine)
                .frame(minWidth: B.pulsante, minHeight: B.tocco)
                .contentShape(Rectangle())
        }
        .buttonStyle(StilePulsanteBarraMobile(altezza: B.pulsanteAltezza))
        .accessibilityLabel(Text(aiuto))
    }
}

/// La pressione su un pulsante della barra: la capsula --chip sotto il pulsante (al posto del passaggio del mouse).
private struct StilePulsanteBarraMobile: ButtonStyle {
    let altezza: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    Capsule(style: .continuous)
                        .fill(Tema.Colore.chip)
                        .frame(height: altezza)
                }
            }
    }
}

/// L'avatar del consulente (.me): cerchio azzurro con le iniziali, filo chiaro in alto e ombra leggera.
private struct AvatarUtenteMobile: View {
    let iniziali: String

    var body: some View {
        let lato = Tema.Misura.Mobile.Barra.avatar
        Text(iniziali)
            .font(Tipo.Mobile.avatarBarra)
            .foregroundColor(Tema.Colore.Shell.avatarTesto)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: lato, height: lato)
            .background {
                Circle()
                    .fill(RadialGradient(colors: [Tema.Colore.Shell.avatarAlto, Tema.Colore.Shell.avatarBasso],
                                         center: UnitPoint(x: 0.3, y: 0.25), startRadius: 0, endRadius: lato))
                    .ombraTema(Tema.Ombra.Shell.avatarBarra)
            }
            .overlay(alignment: .top) {
                Circle()
                    .trim(from: 0.6, to: 0.9)
                    .stroke(Tema.Colore.Shell.avatarLuce, lineWidth: Tema.Misura.Shell.filoAvatar)
                    .padding(Tema.Misura.Shell.filoAvatar / 2)
                    .allowsHitTesting(false)
            }
    }
}
#endif
