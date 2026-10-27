import SwiftUI

/// Finestra interna di un'app (.win del tema): vetro chiaro o scuro con raggio 24 (18 se ingrandita),
/// semafori piatti, titolo con l'icona, contesto della finestra e ridimensionamento.
struct FinestraInterna: View {
    @EnvironmentObject var stato: StatoShell
    let finestra: StatoShell.Finestra
    let attiva: Bool

    @State var origineTrascinamento: CGPoint?
    @State var dimensioneIniziale: CGSize?

    var body: some View {
        let forma = FormaVetro.arrotondata(finestra.ingrandita ? Tema.Raggio.finestraIngrandita : Tema.Raggio.finestra)
        VStack(spacing: 0) {
            barraTitolo
            // In una finestra più piccola del suo contenuto l'app parte dall'angolo in alto a sinistra
            // e si taglia in basso e a destra:
            // la barra del titolo resta sempre al suo posto
            ContenutoApp(app: finestra.app)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        // Il contenuto si taglia prima del vetro: dopo taglierebbe anche le ombre
        .clipShape(forma)
        .vetro(.finestra(attiva: attiva), forma: forma)
        .overlay(alignment: .bottomTrailing) {
            if !finestra.ingrandita { maniglia }
        }
        .simultaneousGesture(TapGesture().onEnded { stato.primoPiano(finestra.app) })
    }

    private var barraTitolo: some View {
        let m = Tema.Misura.Shell.self
        return ZStack(alignment: .leading) {
            Semafori(
                attiva: attiva,
                chiudi: { stato.chiudi(finestra.app) },
                riduci: { stato.riduci(finestra.app) },
                ingrandisci: { stato.alternaIngrandimento(finestra.app) }
            )
            .padding(.leading, Tema.Misura.origineSemafori.x)

            HStack(spacing: m.titoloFinestraSpazio) {
                IconaApp(app: finestra.app, lato: Tema.Misura.iconaFinestra)
                Text(finestra.app.titolo)
                    .font(Tema.Testo.titolo)
                    .foregroundColor(attiva ? Tema.Colore.inchiostro : Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                Spacer(minLength: m.titoloFinestraSpazio)
                strumenti
            }
            .padding(.leading, m.titoloFinestraSinistra)
            .padding(.trailing, m.titoloFinestraDestra)
        }
        .frame(height: Misure.Finestra.barraTitolo)
        .frame(maxWidth: .infinity)
        .background(
            // Piena fino a poco oltre metà, poi sfuma nel contenuto
            LinearGradient(stops: [
                .init(color: Tema.Colore.finestraPiena, location: 0),
                .init(color: Tema.Colore.finestraPiena, location: m.titoloPieno),
                .init(color: Tema.Colore.finestraPiena.opacity(0), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
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

    /// A destra: di chi parla la finestra (il suo cliente o il suo contesto) e il pulsante per affiancarla.
    private var strumenti: some View {
        HStack(spacing: Tema.Misura.Shell.strumentiFinestraSpazio) {
            if let contesto = stato.contesto(di: finestra.app) {
                Text(contesto)
                    .font(Tema.Testo.Shell.contestoFinestra)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Button {
                stato.affianca(finestra.app)
            } label: {
                Image(systemName: "rectangle.split.2x1")
                    .font(Tema.Testo.Shell.simboloPulsante)
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
            .help("Affianca questa app, a sinistra, a quella sotto")
        }
    }

    /// Maniglia di ridimensionamento in basso a destra (solo con finestra non ingrandita).
    private var maniglia: some View {
        let lato = Tema.Misura.Shell.maniglia
        return Path { p in
            for i in 0..<3 {
                let d = CGFloat(i) * 4 + 3
                p.move(to: CGPoint(x: lato - 3, y: d))
                p.addLine(to: CGPoint(x: d, y: lato - 3))
            }
        }
        .stroke(Tema.Colore.inchiostroTerziario, lineWidth: 1)
        .frame(width: lato, height: lato)
        .contentShape(Rectangle())
        .padding(Tema.Misura.Shell.manigliaMargine)
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
