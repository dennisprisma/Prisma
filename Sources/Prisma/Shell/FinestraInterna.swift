import SwiftUI

/// Finestra interna di un'app (.os-window): barra del titolo con semafori, contenuto, ridimensionamento.
struct FinestraInterna: View {
    @EnvironmentObject var stato: StatoShell
    let finestra: StatoShell.Finestra
    let attiva: Bool

    @State var origineTrascinamento: CGPoint?
    @State var dimensioneIniziale: CGSize?

    var body: some View {
        VStack(spacing: 0) {
            barraTitolo
            // In una finestra più piccola del suo contenuto l'app parte dall'alto e si taglia in basso:
            // la barra del titolo resta sempre al suo posto
            ContenutoApp(app: finestra.app)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
                .background(Colori.Finestra.contenuto)
        }
        .background(Colori.Finestra.sfondo)
        .clipShape(RoundedRectangle(cornerRadius: Misure.Finestra.raggio))
        .overlay(
            RoundedRectangle(cornerRadius: Misure.Finestra.raggio)
                .strokeBorder(attiva ? Colori.Finestra.bordoAttiva : Colori.Finestra.bordoInattiva, lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if !finestra.ingrandita { maniglia }
        }
        .ombraCSS(attiva ? Colori.Finestra.ombraAttiva1 : Colori.Finestra.ombraInattiva,
                  y: attiva ? 16 : 5, sfocatura: attiva ? 35 : 16)
        .ombraCSS(attiva ? Colori.Finestra.ombraAttiva2 : .clear, y: 3, sfocatura: 8)
        .simultaneousGesture(TapGesture().onEnded { stato.primoPiano(finestra.app) })
    }

    private var barraTitolo: some View {
        ZStack {
            HStack(spacing: 0) {
                Semafori(
                    attiva: attiva,
                    chiudi: { stato.chiudi(finestra.app) },
                    riduci: { stato.riduci(finestra.app) },
                    ingrandisci: { stato.alternaIngrandimento(finestra.app) }
                )
                Spacer()
                HStack(spacing: 13) {
                    Button {
                        stato.affianca(finestra.app)
                    } label: {
                        Text("◫")
                            .font(Tipo.finestraAffianca)
                            .foregroundColor(Colori.Finestra.affiancaSimbolo)
                            .incisione(.white)
                            .frame(width: Misure.Finestra.affianca.width, height: Misure.Finestra.affianca.height)
                            .background(RoundedRectangle(cornerRadius: Misure.Finestra.raggioAffianca).fill(Gradienti.affianca))
                            .luceInterna(Color.white.opacity(0.47), raggio: Misure.Finestra.raggioAffianca)
                            .overlay(RoundedRectangle(cornerRadius: Misure.Finestra.raggioAffianca).strokeBorder(Colori.Finestra.affiancaBordo, lineWidth: 1))
                    }
                    .buttonStyle(StileSemplice())
                    .help("Affianca questa app, a sinistra, a quella sotto")
                    if let c = stato.clienteAttivo {
                        Text(c.nome)
                            .font(Tipo.finestraContesto)
                            .foregroundColor(Colori.Finestra.contesto)
                            .incisione(Colori.Barra.incisione)
                    }
                }
            }
            .padding(.horizontal, Misure.Finestra.margineTitolo)

            HStack(spacing: 6) {
                IconaApp(app: finestra.app, lato: Misure.Finestra.iconaTitolo)
                Text(finestra.app.titolo)
                    .font(Tipo.finestraTitolo)
                    .foregroundColor(attiva ? Colori.Finestra.titoloTesto : Colori.Finestra.titoloTestoInattivo)
                    .incisione(Colori.Finestra.titoloIncisione)
            }
            .allowsHitTesting(false)
        }
        .frame(height: Misure.Finestra.barraTitolo)
        .frame(maxWidth: .infinity)
        .background(Gradienti.barraTitolo(attiva: attiva))
        .luceInterna(Colori.Finestra.titoloLuce, raggio: Misure.Finestra.raggio)
        .bordoBasso(attiva ? Colori.Finestra.titoloBordoAttiva : Colori.Finestra.titoloBordoInattiva)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { stato.alternaIngrandimento(finestra.app) }
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named(ShellView.spazioFinestre))
                .onChanged { g in
                    guard !finestra.ingrandita else { return }
                    let inizio = origineTrascinamento ?? stato.cornice(di: finestra).origin
                    if origineTrascinamento == nil {
                        origineTrascinamento = inizio
                        stato.primoPiano(finestra.app)
                    }
                    stato.sposta(finestra.app, origine: CGPoint(x: inizio.x + g.translation.width, y: inizio.y + g.translation.height))
                }
                .onEnded { _ in origineTrascinamento = nil }
        )
    }

    /// Maniglia di ridimensionamento in basso a destra (solo con finestra non ingrandita).
    private var maniglia: some View {
        Path { p in
            for i in 0..<3 {
                let d = CGFloat(i) * 4 + 3
                p.move(to: CGPoint(x: 13, y: d))
                p.addLine(to: CGPoint(x: d, y: 13))
            }
        }
        .stroke(Colori.Finestra.affiancaBordo, lineWidth: 1)
        .frame(width: 16, height: 16)
        .contentShape(Rectangle())
        .padding(3)
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named(ShellView.spazioFinestre))
                .onChanged { g in
                    let inizio = dimensioneIniziale ?? stato.cornice(di: finestra).size
                    if dimensioneIniziale == nil { dimensioneIniziale = inizio }
                    stato.ridimensiona(finestra.app, dimensione: CGSize(width: inizio.width + g.translation.width,
                                                                        height: inizio.height + g.translation.height))
                }
                .onEnded { _ in dimensioneIniziale = nil }
        )
        .help("Ridimensiona")
    }
}
