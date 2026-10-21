import AppKit
import SwiftUI

/// Barra superiore di Prisma OS (#os-topbar).
struct BarraSuperiore: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) var modoIstantanea

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                marchio
                appCorrente
                Spacer(minLength: 20)
                comandiDestra
            }
            .padding(.leading, stato.schermoIntero ? Misure.Barra.margine : Misure.Barra.spazioSemaforiNativi)
            .padding(.trailing, Misure.Barra.margine)

            orologio
        }
        .frame(height: Misure.Barra.altezza)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Gradienti.barra
                if !modoIstantanea { AreaTrascinamento() }
            }
        )
        .bordoBasso(Colori.Barra.bordo)
        .ombraCSS(Colori.Barra.ombra, y: 1, sfocatura: 3)
    }

    private var marchio: some View {
        Button {
            stato.mostraScrivania()
        } label: {
            HStack(spacing: Misure.Barra.spazioMarchio) {
                Text("◈")
                    .font(Tipo.barraLogo)
                    .foregroundColor(Colori.Barra.logo)
                    .incisione(.white)
                    .shadow(color: Colori.Barra.logoOmbra, radius: 0, x: 0, y: -1)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("PRISMA").font(Tipo.barraMarchio).foregroundColor(Colori.Barra.testo)
                    Text("OS").font(Tipo.barraOS).foregroundColor(Colori.Barra.os)
                }
                .incisione(Colori.Barra.incisione)
            }
        }
        .buttonStyle(StileSemplice())
        .help("Prisma OS, torna alla scrivania")
    }

    private var appCorrente: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Colori.Barra.separatore).frame(width: 1, height: 14)
                .padding(.leading, Misure.Barra.spazioApp)
            Button {
                stato.mostraAvviso("Gli spazi di lavoro arrivano nella prossima fase.")
            } label: {
                Text(stato.appAttiva?.titolo ?? "Scrivania")
                    .font(Tipo.barraApp)
                    .foregroundColor(Colori.Barra.appCorrente)
                    .incisione(Colori.Barra.incisione)
                    .padding(.leading, Misure.Barra.spazioApp)
            }
            .buttonStyle(StileSemplice())
            .help("Spazi di lavoro")
        }
    }

    private var orologio: some View {
        TimelineView(.everyMinute) { contesto in
            HStack(spacing: Misure.Barra.spazioOra) {
                Text(Formati.barraData.string(from: contesto.date))
                Text(Formati.ora.string(from: contesto.date))
            }
            .font(Tipo.barraOra)
            .foregroundColor(Colori.Barra.testoSecondario)
            .incisione(Colori.Barra.incisione)
        }
        .allowsHitTesting(false)
    }

    private var comandiDestra: some View {
        HStack(spacing: Misure.Barra.spazioDestra) {
            Button {
                stato.mostraAvviso("La ricerca in tutto Prisma arriva nella prossima fase.")
            } label: {
                HStack(spacing: Misure.Barra.spazioCerca) {
                    Text("Cerca").font(Tipo.barraOra).foregroundColor(Colori.Barra.testoSecondario)
                    Text("⌘ K").font(Tipo.barraTasto).foregroundColor(Colori.Barra.tasto)
                }
                .incisione(Colori.Barra.incisione)
            }
            .buttonStyle(StileSemplice())
            .help("Cerca in Prisma")

            Button {
                stato.mostraAvviso("Il centro notifiche arriva nella prossima fase.")
            } label: {
                SimboloCampanella()
                    .stroke(Colori.Barra.testo, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    .frame(width: Misure.Barra.icona, height: Misure.Barra.icona)
                    .incisione(Colori.Barra.incisione)
                    .overlay(alignment: .topTrailing) {
                        let n = stato.attivitaAperte.count
                        if n > 0 { Badge(numero: n, grande: false).offset(x: 6, y: -5) }
                    }
            }
            .buttonStyle(StileSemplice())
            .help("Centro notifiche")

            Button {
                stato.mostraAvviso("La schermata di benvenuto arriva nella prossima fase.")
            } label: {
                SimboloLucchetto()
                    .stroke(Colori.Barra.testo, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    .frame(width: Misure.Barra.icona, height: Misure.Barra.icona)
                    .incisione(Colori.Barra.incisione)
            }
            .buttonStyle(StileSemplice())
            .help("Schermata di benvenuto")

            Button {
                stato.apri(.impostazioni)
            } label: {
                Text(stato.inizialiUtente)
                    .font(Tipo.barraAvatar)
                    .foregroundColor(Colori.Barra.testo)
                    .incisione(.white)
                    .frame(width: Misure.Barra.avatar, height: Misure.Barra.avatar)
                    .background(Circle().fill(Gradienti.avatarUtente))
                    .overlay(alignment: .top) {
                        Circle().trim(from: 0.62, to: 0.88).stroke(Color.white, lineWidth: 1).padding(1.5)
                    }
                    .overlay(Circle().strokeBorder(Colori.Barra.avatarBordo, lineWidth: 1))
                    .shadow(color: Colori.Barra.incisione, radius: 0, x: 0, y: 1)
            }
            .buttonStyle(StileSemplice())
            .help("Impostazioni")
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
