import SwiftUI

/// Dock delle applicazioni (#os-dock): Scrivania, divisore e le 16 app sul ripiano di vetro.
struct Dock: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        HStack(alignment: .bottom, spacing: Misure.Dock.spazio) {
            ElementoDock(titolo: "Scrivania", etichetta: "Scrivania", attivo: stato.appAttiva == nil, inEsecuzione: false) {
                stato.mostraScrivania()
            } icona: {
                ImmagineRisorsa(percorso: "Icone/Prisma.png")
            }
            DivisoreDock()
            ForEach(Array(AppPrisma.allCases.enumerated()), id: \.element) { indice, app in
                ElementoDock(
                    titolo: app.titolo,
                    etichetta: app.nomeDock,
                    scorciatoia: indice < 9 ? "⌥ \(indice + 1)" : nil,
                    attivo: stato.appAttiva == app,
                    inEsecuzione: stato.aperta(app)
                ) {
                    stato.apri(app)
                } icona: {
                    IconaApp(app: app, lato: Misure.Dock.icona)
                }
            }
        }
        .padding(EdgeInsets(top: Misure.Dock.margineAlto, leading: Misure.Dock.margineOrizzontale,
                            bottom: Misure.Dock.margineBasso, trailing: Misure.Dock.margineOrizzontale))
        .background(alignment: .bottom) { RipianoDock() }
    }
}

/// Ripiano in prospettiva (`#os-dock::before` con rotateX) e filo di luce frontale (`::after`).
struct RipianoDock: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Trapezio(rientro: Misure.Dock.ripianoRientro)
                    .fill(Gradienti.ripiano)
                Trapezio(rientro: Misure.Dock.ripianoRientro)
                    .stroke(Colori.Dock.ripianoBordo, lineWidth: 1)
                Trapezio(rientro: Misure.Dock.ripianoRientro)
                    .stroke(Color.white, lineWidth: 1)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.12)))
            }
            .frame(height: Misure.Dock.ripianoAltezza)
            Rectangle()
                .fill(Colori.Dock.ripianoFondo)
                .frame(height: 4)
                .overlay(alignment: .top) {
                    Rectangle().fill(Colori.Dock.filo).frame(height: 1)
                        .shadow(color: Colori.Dock.filoOmbra, radius: 0, x: 0, y: 1)
                }
        }
        .padding(.horizontal, -Misure.Dock.ripianoSporgenza)
        .ombraCSS(Colori.Dock.ripianoOmbra, y: 6, sfocatura: 9)
        .allowsHitTesting(false)
    }
}

struct Trapezio: Shape {
    let rientro: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + rientro, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - rientro, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct DivisoreDock: View {
    var body: some View {
        Rectangle()
            .fill(Gradienti.divisoreDock)
            .frame(width: 1, height: Misure.Dock.icona)
            .shadow(color: Color.white.opacity(0.4), radius: 0, x: 1, y: 0)
            .padding(.horizontal, 1)
            .padding(.bottom, 8)
    }
}

/// Elemento del dock con ingrandimento al passaggio, suggerimento e puntino di esecuzione.
struct ElementoDock<Icona: View>: View {
    let titolo: String
    /// Il nome breve sotto l'icona.
    let etichetta: String
    var scorciatoia: String? = nil
    let attivo: Bool
    let inEsecuzione: Bool
    let azione: () -> Void
    @ViewBuilder let icona: () -> Icona
    @State var sopra = false

    var body: some View {
        Button(action: azione) {
            VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                icona()
                    .frame(width: Misure.Dock.icona, height: Misure.Dock.icona)
                    .ombraCSS(Colori.Dock.iconaOmbra, y: 2, sfocatura: 2)
                    .scaleEffect(sopra ? Misure.Dock.ingrandimento : 1, anchor: .bottom)
                    .padding(.bottom, 4)
                    .frame(width: Misure.Dock.elemento, height: Misure.Dock.elemento)
                if inEsecuzione || attivo {
                    Ellipse()
                        .fill(Colori.Dock.puntino)
                        .frame(width: 5, height: 3)
                        .shadow(color: Colori.Dock.puntinoAlone, radius: 2)
                }
            }
            Text(etichetta)
                .font(Tipo.dockEtichetta)
                .foregroundColor(Colori.Dock.etichetta)
                .shadow(color: Colori.Dock.etichettaOmbra, radius: 1, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Larga quanto l'icona: con 17 app il dock deve stare anche in uno schermo da 1280 punti
                .frame(width: Misure.Dock.elemento, height: Misure.Dock.etichetta)
            }
        }
        .buttonStyle(StileSemplice())
        .onHover { s in withAnimation(Animazioni.passaggio) { sopra = s } }
        .overlay(alignment: .top) {
            if sopra {
                SuggerimentoDock(testo: titolo, scorciatoia: scorciatoia)
                    .fixedSize()
                    .offset(y: -32)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(sopra ? 1 : 0)
    }
}

struct SuggerimentoDock: View {
    let testo: String
    let scorciatoia: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(testo)
                if let s = scorciatoia {
                    Text(s).font(Tipo.sistema(9)).opacity(0.7)
                }
            }
            .font(Tipo.dockSuggerimento)
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(Colori.Dock.suggerimento))
            Triangolo()
                .fill(Colori.Dock.suggerimento)
                .frame(width: 10, height: 5)
        }
    }
}

struct Triangolo: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
