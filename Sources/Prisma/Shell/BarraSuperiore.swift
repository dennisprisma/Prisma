#if os(macOS)
import AppKit
#endif
import SwiftUI

/// Barra superiore (tema «Liquid Glass»): niente fondo, solo un velo che sfuma sotto; a sinistra il marchio
/// e l'app in primo piano, al centro data e ora, a destra gli strumenti in una capsula di vetro.
/// Il marchio comincia dopo i pulsanti veri della finestra del Mac, alla loro altezza (`LettoreSemafori`).
struct BarraSuperiore: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) var modoIstantanea
    /// Dove sono i pulsanti veri della finestra del Mac (nil: non letti, o non ci sono).
    @State var semafori: PosizioneSemafori? = nil

    var body: some View {
        let m = Tema.Misura.Shell.self
        let y = spostamentoVerticale
        ZStack {
            HStack(spacing: m.barraSpazio) {
                marchio
                    .offset(y: y)
                appCorrente
                    .offset(y: y)
                Spacer(minLength: 20)
                // La capsula è quasi alta quanto la barra: segue i pulsanti finché resta un punto dal bordo
                strumenti
                    .offset(y: BarraSuperiore.limita(y, (Tema.Misura.barra - Tema.Misura.barraStrumenti) / 2 - Tema.Misura.filo * 2))
            }
            // Fuori dallo schermo intero a sinistra ci sono i pulsanti della finestra del Mac
            .padding(.leading, margineSinistro)
            .padding(.trailing, m.barraMargineDestro)

            orologio
                .offset(y: y)
        }
        .frame(height: Tema.Misura.barra)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                // Il velo scende oltre la barra e sfuma (--bar-shade)
                LinearGradient(colors: [Tema.Colore.veloBarra, Tema.Colore.veloBarra.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: Tema.Misura.barra + Tema.Misura.veloBarra)
                    .allowsHitTesting(false)
                #if os(macOS)
                if !modoIstantanea {
                    // Legge dove sono i pulsanti veri della finestra (invisibile, non prende il mouse)
                    LettoreSemafori { nuova in
                        if semafori != nuova { semafori = nuova }
                    }
                    .frame(height: Tema.Misura.barra)
                    .allowsHitTesting(false)
                    AreaTrascinamento().frame(height: Tema.Misura.barra)
                }
                #endif
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// Margine a sinistra: il logo sta a `spazioDopoSemafori` dal pulsante verde vero della finestra
    /// (letto da AppKit; se non si legge, dove sta di solito). A schermo intero i pulsanti non ci sono.
    private var margineSinistro: CGFloat {
        let m = Tema.Misura.Shell.self
        guard !stato.schermoIntero else { return m.barraMargineSinistro }
        let bordo = semafori?.bordoDestro ?? m.bordoSemaforiTipico
        // Il logo ha davanti il suo margine interno (la capsula al passaggio del mouse)
        return max(m.barraMargineSinistro, bordo + m.spazioDopoSemafori - m.marchioMargineSinistro)
    }

    /// Quanto spostare in verticale il contenuto della barra perché il suo centro stia su quello dei pulsanti
    /// veri della finestra; mai oltre lo spazio che il marchio ha nella barra.
    private var spostamentoVerticale: CGFloat {
        guard !stato.schermoIntero, let s = semafori else { return 0 }
        return BarraSuperiore.limita(s.centroVerticale - Tema.Misura.barra / 2,
                                     (Tema.Misura.barra - Tema.Misura.marchioBarra) / 2)
    }

    /// `valore` tenuto fra −`gioco` e +`gioco`.
    private static func limita(_ valore: CGFloat, _ gioco: CGFloat) -> CGFloat {
        min(max(valore, -gioco), gioco)
    }

    /// Il logo e «Prisma»: torna alla scrivania.
    private var marchio: some View {
        let m = Tema.Misura.Shell.self
        return PulsanteBarra(aiuto: "Prisma: torna alla scrivania", azione: { stato.mostraScrivania() }) {
            HStack(spacing: m.marchioSpazio) {
                LogoPrisma(colore: Tema.Colore.logo)
                    .frame(height: Tema.Misura.logoBarra)
                Text("Prisma")
                    .font(Tema.Testo.marchio)
                    .tracking(Tema.Testo.Shell.spaziaturaMarchio)
                    .foregroundColor(Tema.Colore.inchiostroSfondo)
            }
            .padding(.leading, m.marchioMargineSinistro)
            .padding(.trailing, m.marchioMargine)
            .frame(height: Tema.Misura.marchioBarra)
            .aloneSfondo()
        }
    }

    /// Il nome dell'app in primo piano («Scrivania» se non ce n'è): apre gli spazi di lavoro.
    private var appCorrente: some View {
        PulsanteBarra(aiuto: "Spazi di lavoro", azione: {
            if stato.pannelloNotifiche { stato.pannelloNotifiche = false }
            if !stato.inModoCliente { stato.pannelloSpazi.toggle() }
        }) {
            TitoloAppAttiva()
                .padding(.horizontal, Tema.Misura.Shell.marchioMargine)
                .frame(height: Tema.Misura.marchioBarra)
                .aloneSfondo()
        }
    }

    private var orologio: some View {
        TimelineView(.everyMinute) { contesto in
            HStack(spacing: Tema.Misura.Shell.orologioSpazio) {
                Text(Formati.barraData.string(from: contesto.date))
                Text(Formati.ora.string(from: contesto.date))
            }
            .font(Tema.Testo.Shell.orologio)
            .foregroundColor(Tema.Colore.inchiostroSfondo)
            .aloneSfondo()
        }
        .allowsHitTesting(false)
    }

    /// Gli strumenti a destra, nella capsula di vetro sottile.
    private var strumenti: some View {
        let m = Tema.Misura.Shell.self
        return HStack(spacing: m.strumentiSpazio) {
            if stato.inModoCliente {
                ContrassegnoModoCliente()
                    .padding(.horizontal, m.strumentiMargine)
            } else {
                PulsanteBarra(aiuto: "Cerca in Prisma (⌘K)", azione: { stato.alternaRicerca() }) {
                    HStack(spacing: m.pulsanteBarraSpazio) {
                        Image(systemName: "magnifyingglass").font(Tema.Testo.Shell.simboloBarra)
                        Text("Cerca").font(Tema.Testo.Shell.pulsanteBarra)
                        TastoBarra(testo: "⌘K")
                    }
                    .modifier(FormaPulsanteBarra())
                }

                PulsanteBarra(aiuto: "Centro notifiche", azione: { stato.alternaNotifiche() }) {
                    Image(systemName: "bell")
                        .font(Tema.Testo.Shell.simboloBarra)
                        .frame(width: Tema.Misura.iconaBarra, height: Tema.Misura.iconaBarra)
                        .overlay(alignment: .topTrailing) {
                            let n = stato.notificheNuove
                            if n > 0 {
                                Badge(numero: n, grande: false)
                                    .offset(x: m.badgeSpostamento.width, y: m.badgeSpostamento.height)
                            }
                        }
                        .modifier(FormaPulsanteBarra())
                }
            }

            // La guida di Prisma (anche in modalità cliente): come funziona, le app, le parole
            PulsanteBarra(aiuto: "Guida di Prisma: come funziona, le app, le parole (⌘?)",
                          azione: { stato.apriGuida(.app(stato.appAttiva ?? .clienti)) }) {
                Image(systemName: "questionmark.circle")
                    .font(Tema.Testo.Shell.simboloBarra)
                    .frame(width: Tema.Misura.iconaBarra, height: Tema.Misura.iconaBarra)
                    .modifier(FormaPulsanteBarra())
            }

            PulsanteBarra(aiuto: "Schermata di benvenuto", azione: { stato.blocca() }) {
                Image(systemName: "lock")
                    .font(Tema.Testo.Shell.simboloBarra)
                    .frame(width: Tema.Misura.iconaBarra, height: Tema.Misura.iconaBarra)
                    .modifier(FormaPulsanteBarra())
            }

            PulsanteBarra(aiuto: stato.inModoCliente ? "Esci dalla modalità cliente (⌥⌘M)"
                                                     : "Modalità cliente: mostra solo il cliente attivo, per girare lo schermo (⌥⌘M)",
                          azione: { if stato.inModoCliente { stato.esciModoCliente() } else { stato.entraModoCliente() } }) {
                Image(systemName: stato.inModoCliente ? "person.fill.checkmark" : "person.crop.rectangle")
                    .font(Tema.Testo.Shell.simboloBarra)
                    .frame(height: Tema.Misura.iconaBarra)
                    .modifier(FormaPulsanteBarra())
            }

            PulsanteBarra(aiuto: "Impostazioni", sfondoAlPassaggio: false, azione: { stato.apri(.impostazioni) }) {
                AvatarUtente(iniziali: stato.inizialiUtente)
                    .padding(.horizontal, m.strumentiMargine)
            }
        }
        .foregroundColor(Tema.Colore.inchiostro)
        .padding(m.strumentiMargine)
        .frame(height: Tema.Misura.barraStrumenti)
        .vetro(.leggero, forma: .capsula)
    }
}

/// Il nome dell'app in primo piano («Scrivania» se non ce n'è): osserva solo le finestre,
/// così il resto della barra non si ridisegna quando si cambia app.
private struct TitoloAppAttiva: View {
    @EnvironmentObject var sistema: StatoFinestre

    var body: some View {
        Text(sistema.appAttiva?.titolo ?? "Scrivania")
            .font(Tema.Testo.barra)
            .foregroundColor(Tema.Colore.inchiostroSfondo)
            .lineLimit(1)
    }
}

/// Pulsante della barra: capsula che si schiarisce al passaggio del mouse (--chip), senza altre decorazioni.
private struct PulsanteBarra<Etichetta: View>: View {
    let aiuto: String
    var sfondoAlPassaggio = true
    let azione: () -> Void
    @ViewBuilder let etichetta: () -> Etichetta
    @State var sopra = false

    var body: some View {
        Button(action: azione) {
            etichetta()
                .background {
                    if sfondoAlPassaggio && sopra {
                        Capsule(style: .continuous).fill(Tema.Colore.chip)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(StileSemplice())
        .onHover { s in withAnimation(Tema.Moto.passaggio) { sopra = s } }
        .help(aiuto)
    }
}

/// Misura dei pulsanti dentro la capsula degli strumenti (alti 26, larghi almeno 28, margini 8).
private struct FormaPulsanteBarra: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Tema.Misura.Shell.pulsanteBarraMargine)
            .frame(minWidth: Tema.Misura.Shell.pulsanteBarraMinimo, minHeight: Tema.Misura.pulsanteBarra)
    }
}

/// Tasto della scorciatoia (kbd): pozzetto arrotondato con il testo secondario.
struct TastoBarra: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(Tema.Testo.Shell.tastoBarra)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .padding(Tema.Misura.Shell.tastoMargine)
            .background(RoundedRectangle(cornerRadius: Tema.Raggio.tasto, style: .continuous).fill(Tema.Colore.pozzetto))
    }
}

/// Avatar del consulente (.me): cerchio azzurro con le iniziali, filo chiaro in alto e ombra leggera.
private struct AvatarUtente: View {
    let iniziali: String

    var body: some View {
        let lato = Tema.Misura.avatarBarra
        Text(iniziali)
            .font(Tema.Testo.Shell.avatarBarra)
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
                // inset 0 1px 0 rgba(255,255,255,.5)
                Circle()
                    .trim(from: 0.6, to: 0.9)
                    .stroke(Tema.Colore.Shell.avatarLuce, lineWidth: Tema.Misura.Shell.filoAvatar)
                    .padding(Tema.Misura.Shell.filoAvatar / 2)
                    .allowsHitTesting(false)
            }
    }
}

/// Campanella della barra (tracciato SVG del template, viewBox 24).
struct SimboloCampanella: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        var p = Path()
        p.move(to: CGPoint(x: 6, y: 17))
        p.addLine(to: CGPoint(x: 18, y: 17))
        p.addLine(to: CGPoint(x: 16.5, y: 14))
        p.addLine(to: CGPoint(x: 16.5, y: 9))
        p.addArc(center: CGPoint(x: 12, y: 9), radius: 4.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addLine(to: CGPoint(x: 7.5, y: 14))
        p.closeSubpath()
        p.move(to: CGPoint(x: 10, y: 20))
        p.addLine(to: CGPoint(x: 14, y: 20))
        p.move(to: CGPoint(x: 12, y: 3))
        p.addLine(to: CGPoint(x: 12, y: 4))
        return p.applying(CGAffineTransform(scaleX: s, y: s).concatenating(CGAffineTransform(translationX: r.minX, y: r.minY)))
    }
}

/// Lucchetto della barra (tracciato SVG del template, viewBox 24).
struct SimboloLucchetto: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 6, y: 10, width: 12, height: 10), cornerSize: CGSize(width: 2, height: 2))
        p.move(to: CGPoint(x: 9, y: 10))
        p.addLine(to: CGPoint(x: 9, y: 6))
        p.addArc(center: CGPoint(x: 12, y: 6), radius: 3, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: 15, y: 10))
        return p.applying(CGAffineTransform(scaleX: s, y: s).concatenating(CGAffineTransform(translationX: r.minX, y: r.minY)))
    }
}

#if os(macOS)
/// Zona della barra che trascina la finestra macOS (doppio clic: ingrandisce, come la barra del titolo).
struct AreaTrascinamento: NSViewRepresentable {
    final class Vista: NSView {
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                window?.zoom(nil)
            } else {
                window?.performDrag(with: event)
            }
        }
    }

    func makeNSView(context: Context) -> Vista { Vista() }
    func updateNSView(_ nsView: Vista, context: Context) {}
}
#endif
