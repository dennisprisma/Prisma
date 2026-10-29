#if os(iOS)
import SwiftUI

/// La finestra di vetro di un'app su iPhone e iPad (.win del tema): `.vetro(.finestra(attiva: true))` con il raggio
/// dato, contenuto tagliato alla forma, alla `cornice` data (spazio `ShellView.spazioShell`, grande `spazio`).
/// Entra ed esce con il movimento del Mac:
/// - entrata: scala dall'ancora del punto d'origine (icona del dock, widget) con `Tema.Moto.Finestre.apertura`,
///   `scalaApertura` 0,2 (senza origine `scalaAperturaSulPosto`), opacità piena in 0,06 s (`OpacitaApertura`);
/// - uscita: `.chiusuraFinestra` del Mac; con «Riduci movimento» la sola dissolvenza.
/// Solo trasformazioni affini sul contenitore grande quanto la shell: il vetro di iOS 26 si disegna bene.
/// Una sola finestra viva (memoria): l'app chiusa o cambiata si toglie a fine uscita (`.id(app)` in chi la mostra).
struct FinestraMobile<Contenuto: View>: View {
    let app: AppPrisma
    let cornice: CGRect
    /// La misura della shell: il movimento scala tutta la shell attorno all'origine, così l'ancora è quella vera.
    let spazio: CGSize
    let raggio: CGFloat
    let origine: CGPoint?
    /// false nelle istantanee: la finestra è già al suo posto.
    var animata = true
    /// iPad: la barra del titolo (la ✕, l'icona e il nome dell'app); sull'iPhone la ✕ sta nella barra di navigazione.
    var conBarra = false
    @ViewBuilder let contenuto: () -> Contenuto
    @State var aperta = false

    var body: some View {
        let forma = FormaVetro.arrotondata(raggio)
        let m = Tema.Moto.Finestre.self
        let calmo = Movimenti.calmo
        let partenza: CGFloat = calmo ? 1 : (origine != nil ? m.scalaApertura : m.scalaAperturaSulPosto)
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                if conBarra {
                    BarraTitoloMobile(app: app)
                }
                contenuto()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: max(0, cornice.width), height: max(0, cornice.height), alignment: .topLeading)
            // Il contenuto si taglia prima del vetro: dopo taglierebbe anche le ombre
            .clipShape(forma)
            .vetro(.finestra(attiva: true), forma: forma)
            .padding(.leading, cornice.minX)
            .padding(.top, cornice.minY)
        }
        .frame(width: spazio.width, height: spazio.height, alignment: .topLeading)
        .modifier(OpacitaApertura(visibile: aperta || !animata))
        .modifier(EffettoFinestra(scala: aperta || !animata ? 1 : partenza, ancora: ancoraApertura, y: 0, opacita: 1))
        .transition(.chiusuraFinestra(ancora: ancoraChiusura))
        .onAppear {
            guard animata, !aperta else { return }
            // Al giro dopo, come sul Mac: il primo disegno dell'app cade prima del primo fotogramma animato
            Movimenti.alGiroDopo(m.apertura, durata: m.durataApertura) { aperta = true }
        }
    }

    /// L'origine (o il centro della finestra) in frazioni della shell.
    private var ancoraApertura: UnitPoint {
        guard let o = origine else { return ancoraChiusura }
        return UnitPoint(x: o.x / max(1, spazio.width), y: o.y / max(1, spazio.height))
    }

    private var ancoraChiusura: UnitPoint {
        UnitPoint(x: cornice.midX / max(1, spazio.width), y: cornice.midY / max(1, spazio.height))
    }
}

/// La barra del titolo della finestra sull'iPad (.tbar e .win-title del tema): la ✕ al posto dei semafori, l'icona,
/// il nome dell'app e, a destra, di chi parla la finestra. Piena in alto, poi sfuma nel contenuto, come sul Mac.
private struct BarraTitoloMobile: View {
    @EnvironmentObject var stato: StatoShell
    let app: AppPrisma

    private typealias F = Tema.Misura.Mobile.Finestra

    var body: some View {
        HStack(spacing: F.spazioTitolo) {
            PulsanteChiudiFinestra(app: app)
            IconaApp(app: app, lato: Tema.Misura.iconaFinestra)
            Text(app.titolo)
                .font(Tipo.Mobile.titoloFinestra)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
            Spacer(minLength: F.spazioTitolo)
            if let contesto = stato.contesto(di: app) {
                Text(contesto)
                    .font(Tema.Testo.Shell.contestoFinestra)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.leading, F.margineChiudi)
        .padding(.trailing, F.margineDestroTitolo)
        .frame(height: F.barraTitolo)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(stops: [
                .init(color: Tema.Colore.finestraPiena, location: 0),
                .init(color: Tema.Colore.finestraPiena, location: Tema.Misura.Shell.titoloPieno),
                .init(color: Tema.Colore.finestraPiena.opacity(0), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
    }
}

/// La ✕ della finestra: il semaforo rosso del tema (.l-close, #FF5F57) grande per il dito, con il segno sempre in
/// vista (sul touch non c'è il passaggio del puntatore). Torna alla scrivania.
struct PulsanteChiudiFinestra: View {
    @EnvironmentObject var mobile: StatoMobile
    let app: AppPrisma

    private typealias F = Tema.Misura.Mobile.Finestra

    var body: some View {
        Button { mobile.mostraHome() } label: {
            Image(systemName: "xmark")
                .font(Tipo.Mobile.simboloChiudi)
                .foregroundColor(Tema.Colore.simboloSemaforo)
                .frame(width: F.chiudi, height: F.chiudi)
                .background(Circle().fill(Tema.Colore.semaforoChiudi))
                .overlay(Circle().strokeBorder(Tema.Colore.bordoSemaforo, lineWidth: Tema.Misura.filo))
                .frame(width: F.toccoChiudi, height: F.toccoChiudi)
                .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
        .accessibilityLabel(Text("Chiudi \(app.titolo)"))
        .accessibilityHint(Text("Torna alla scrivania"))
    }
}
#endif
