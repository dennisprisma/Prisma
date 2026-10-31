#if os(macOS)
import SwiftUI

/// «Dentro Prisma, non sopra» (Design/eve-mini.html): mentre la mini finestra pensa, la finestra in primo piano
/// viene «letta» (un filo d'accento attorno e una luce che la percorre dall'alto in basso); quando la risposta è
/// pronta si illumina un momento (anello d'accento e alone), poi torna com'era. Non tocca i clic.
struct LetturaEveFinestra: View {
    @ObservedObject var mini: StatoMiniEve
    let forma: FormaVetro

    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea
    /// La risposta è appena arrivata: l'anello resta acceso per un attimo.
    @State private var illuminata = false

    private typealias M = Tema.Misura.LetturaEve
    private typealias C = Tema.Colore.LetturaEve

    var body: some View {
        let legge = mini.visibile && mini.fase == .pensa
        let risposta = mini.visibile && mini.fase == .risponde && !mini.inArrivo
        ZStack {
            if legge {
                forma.strokeBorder(C.filo, lineWidth: M.filo)
                if !movimentoRidotto && !modoIstantanea { luce }
            }
            if illuminata || (risposta && (movimentoRidotto || modoIstantanea)) {
                forma.strokeBorder(C.anello, lineWidth: M.anello)
                    .shadow(color: C.alone, radius: M.alone)
                    .transition(.opacity)
            }
        }
        .clipShape(forma)
        .allowsHitTesting(false)
        .animation(Tema.Moto.LetturaEve.cambio, value: legge)
        .onChange(of: risposta) { pronta in
            guard pronta, !movimentoRidotto, !modoIstantanea else { return }
            withAnimation(Tema.Moto.LetturaEve.cambio) { illuminata = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + Tema.Moto.LetturaEve.durataLuce) {
                withAnimation(Tema.Moto.LetturaEve.spegni) { illuminata = false }
            }
        }
    }

    /// La luce che scorre: una fascia d'accento morbida, dall'alto in basso, un passaggio ogni 1,4 secondi (scan).
    private var luce: some View {
        TimelineView(.animation(minimumInterval: 1 / Tema.Moto.MiniEve.fotogrammi)) { t in
            GeometryReader { g in
                let periodo = Tema.Moto.LetturaEve.passaggio
                let p = CGFloat(t.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: periodo) / periodo)
                LinearGradient(colors: [.clear, C.luce, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: M.fascia)
                    .offset(y: -M.fascia + p * (g.size.height + M.fascia))
            }
        }
    }
}

#endif
