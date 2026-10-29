import SwiftUI

/// Finestra interna di un'app (.win del tema): vetro chiaro o scuro con raggio 24 (18 se ingrandita),
/// semafori piatti, titolo con l'icona, contesto della finestra e ridimensionamento.
/// Trascinare e ridimensionare non toccano lo stato finché non si rilascia: si muove (o si reimpagina)
/// solo questa finestra, come sul Mac, e lo stato si scrive una volta sola.
struct FinestraInterna: View {
    @EnvironmentObject var stato: StatoShell
    let finestra: StatoShell.Finestra
    let attiva: Bool
    /// L'area delle finestre (coordinate `ShellView.spazioFinestre`): spostamento e misura restano dentro.
    let area: CGRect

    /// Il trascinamento in corso (si azzera da solo anche se il gesto viene interrotto).
    @GestureState private var spostamento: CGSize = .zero
    /// Il ridimensionamento in corso.
    @GestureState private var allungamento: CGSize = .zero

    var body: some View {
        let forma = FormaVetro.arrotondata(finestra.ingrandita ? Tema.Raggio.finestraIngrandita : Tema.Raggio.finestra)
        let dimensione = allungamento == .zero ? cornice.size : misuraAllungata(allungamento)
        VStack(spacing: 0) {
            barraTitolo
            // In una finestra più piccola del suo contenuto l'app parte dall'angolo in alto a sinistra
            // e si taglia in basso e a destra:
            // la barra del titolo resta sempre al suo posto
            ContenutoApp(app: finestra.app)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        // La finestra si dà da sola la misura: ridimensionando si rifà l'impaginazione solo di lei
        .frame(width: dimensione.width, height: dimensione.height, alignment: .topLeading)
        // Il contenuto si taglia prima del vetro: dopo taglierebbe anche le ombre
        .clipShape(forma)
        .vetro(.finestra(attiva: attiva), forma: forma)
        .overlay(alignment: .bottomTrailing) {
            if !finestra.ingrandita { maniglia }
        }
        // Una trasformazione, non un cambio di stato: niente si ricalcola mentre si trascina
        .offset(spostamento == .zero ? .zero : limitato(spostamento))
        // Davanti appena si preme, come sul Mac (non al rilascio): insieme ai gesti dell'app, mai al loro posto
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !attiva { stato.primoPiano(finestra.app) }
                }
        )
    }

    /// La cornice nello stato, nell'area in cui ShellView disegna la finestra.
    private var cornice: CGRect { stato.cornice(di: finestra, in: area) }

    /// Lo spostamento dentro l'area (come `limita` dello stato): la barra del titolo resta raggiungibile.
    private func limitato(_ t: CGSize) -> CGSize {
        let c = cornice
        let x = min(max(c.minX + t.width, 0), max(0, area.width - c.width))
        let y = min(max(c.minY + t.height, 0), max(0, area.height - c.height))
        return CGSize(width: x - c.minX, height: y - c.minY)
    }

    /// La misura allungata: non sotto la minima e non oltre il bordo dell'area.
    private func misuraAllungata(_ t: CGSize) -> CGSize {
        let c = cornice
        let minima = Misure.Finestra.minima
        return CGSize(width: min(max(minima.width, c.width + t.width), max(minima.width, area.width - c.minX)),
                      height: min(max(minima.height, c.height + t.height), max(minima.height, area.height - c.minY)))
    }

    /// Scrive lo stato una volta sola, al rilascio, senza animazione.
    private func alRilascio(_ cambia: () -> Void) {
        withTransaction(Transaction(animation: nil), cambia)
    }

    private var barraTitolo: some View {
        let m = Tema.Misura.Shell.self
        return ZStack(alignment: .leading) {
            SemaforiFinestra(
                attiva: attiva,
                chiudi: { stato.chiudi(finestra.app) },
                riduci: { stato.riduci(finestra.app) },
                ingrandisci: { stato.alternaIngrandimento(finestra.app) },
                // Chiudi e riduci sono sotto il puntatore: l'istantanea del genio si prepara adesso
                prepara: { stato.preparaEffetto(finestra.app) }
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
                .updating($spostamento) { g, s, _ in
                    if !finestra.ingrandita { s = g.translation }
                }
                // Davanti al primo movimento (poi primoPiano non cambia più niente)
                .onChanged { _ in
                    if !finestra.ingrandita { stato.primoPiano(finestra.app) }
                }
                .onEnded { g in
                    guard !finestra.ingrandita else { return }
                    let c = cornice
                    let d = limitato(g.translation)
                    alRilascio { stato.sposta(finestra.app, origine: CGPoint(x: c.minX + d.width, y: c.minY + d.height)) }
                }
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
                .updating($allungamento) { g, s, _ in s = g.translation }
                .onChanged { _ in stato.primoPiano(finestra.app) }
                .onEnded { g in
                    let m = misuraAllungata(g.translation)
                    alRilascio { stato.ridimensiona(finestra.app, dimensione: m) }
                }
        )
        .help("Ridimensiona")
    }
}

// MARK: - Semafori

/// I tre pallini della finestra interna, come quelli del Mac: cerchi da 12 pt a 20 pt l'uno dall'altro, grigi
/// se la finestra non è in primo piano; i segni ✕ − + (vettoriali, centrati nel cerchio) compaiono solo con
/// il puntatore sopra il gruppo, tutti e tre insieme.
private struct SemaforiFinestra: View {
    let attiva: Bool
    let chiudi: () -> Void
    let riduci: () -> Void
    let ingrandisci: () -> Void
    /// Il puntatore è arrivato sui semafori (prepara l'istantanea per il genio e la chiusura).
    let prepara: () -> Void
    @State private var sopra = false

    var body: some View {
        let m = Tema.Misura.Shell.self
        HStack(spacing: m.semaforoPasso - m.semaforoLato) {
            pallino(Tema.Colore.semaforoChiudi, .chiudi, chiudi)
            pallino(Tema.Colore.semaforoRiduci, .riduci, riduci)
            pallino(Tema.Colore.semaforoIngrandisci, .ingrandisci, ingrandisci)
        }
        .contentShape(Rectangle())
        .onHover { dentro in
            sopra = dentro
            if dentro { prepara() }
        }
    }

    private func pallino(_ colore: Color, _ segno: SegnoSemaforo.Tipo, _ azione: @escaping () -> Void) -> some View {
        let m = Tema.Misura.Shell.self
        return Button(action: azione) {
            ZStack {
                Circle().fill(attiva || sopra ? colore : Tema.Colore.Shell.semaforoSpento)
                Circle().strokeBorder(Tema.Colore.bordoSemaforo, lineWidth: Tema.Misura.filo)
                if sopra {
                    SegnoSemaforo(tipo: segno)
                        .stroke(Tema.Colore.Shell.segnoSemaforo,
                                style: StrokeStyle(lineWidth: m.semaforoTratto, lineCap: .round))
                }
            }
            .frame(width: m.semaforoLato, height: m.semaforoLato)
            .contentShape(Circle())
        }
        .buttonStyle(StileSemplice())
        .help(SemaforiFinestra.aiuto(segno))
    }

    /// Il suggerimento al passaggio del mouse: a chi non conosce il Mac dice che cosa fa ogni pallino.
    private static func aiuto(_ segno: SegnoSemaforo.Tipo) -> String {
        switch segno {
        case .chiudi: return "Chiudi"
        case .riduci: return "Riduci nel dock"
        case .ingrandisci: return "Ingrandisci (o doppio clic sulla barra)"
        }
    }
}

/// ✕, − e + disegnati attorno al centro esatto del riquadro (il testo e i simboli SF non si centrano).
private struct SegnoSemaforo: Shape {
    enum Tipo { case chiudi, riduci, ingrandisci }
    let tipo: Tipo

    func path(in rect: CGRect) -> Path {
        let m = Tema.Misura.Shell.self
        let x = rect.midX
        let y = rect.midY
        var p = Path()
        switch tipo {
        case .chiudi:
            let d = m.semaforoCroce
            p.move(to: CGPoint(x: x - d, y: y - d))
            p.addLine(to: CGPoint(x: x + d, y: y + d))
            p.move(to: CGPoint(x: x + d, y: y - d))
            p.addLine(to: CGPoint(x: x - d, y: y + d))
        case .riduci:
            let d = m.semaforoLinea
            p.move(to: CGPoint(x: x - d, y: y))
            p.addLine(to: CGPoint(x: x + d, y: y))
        case .ingrandisci:
            let d = m.semaforoLinea
            p.move(to: CGPoint(x: x - d, y: y))
            p.addLine(to: CGPoint(x: x + d, y: y))
            p.move(to: CGPoint(x: x, y: y - d))
            p.addLine(to: CGPoint(x: x, y: y + d))
        }
        return p
    }
}
