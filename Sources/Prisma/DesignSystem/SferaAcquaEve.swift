import SwiftUI

/// La sfera di Eve della mini finestra (.orb di Design/eve-mini.html): acqua viva, un fondo blu profondo con tre
/// correnti di luce che si muovono piano, un riflesso in alto e un alone che cresce con la voce.
/// - livello: quanto suona la voce (0…1): la sfera si gonfia appena e l'alone si accende.
/// - velocita: 1 a riposo, più alta mentre ascolta e pensa.
/// - spenta: Qwen non è pronto (quasi grigia, lentissima).
/// - animata: false = ferma (barra superiore a riposo, istantanee, «Riduci movimento»).
struct SferaAcquaEve: View {
    let lato: CGFloat
    var livello: CGFloat = 0
    var velocita: Double = 1
    var spenta = false
    var animata = true

    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea

    var body: some View {
        let muove = animata && !movimentoRidotto && !modoIstantanea
        TimelineView(.animation(minimumInterval: 1 / Tema.Moto.MiniEve.fotogrammi, paused: !muove)) { contesto in
            sfera(tempo: muove ? contesto.date.timeIntervalSinceReferenceDate : 1.4)
        }
        .frame(width: lato, height: lato)
        .scaleEffect(1 + min(max(livello, 0), 1) * 0.1)
        .animation(.linear(duration: 0.12), value: livello)
    }

    private func sfera(tempo: TimeInterval) -> some View {
        let c = Tema.Colore.MiniEve.Sfera.self
        let periodi = Tema.Moto.MiniEve.periodiSfera
        let v = spenta ? Tema.Moto.MiniEve.velocitaSpenta : velocita
        let lvl = Double(min(max(livello, 0), 1))
        // Avanti e indietro con ease-in-out, come `animation: … ease-in-out infinite alternate`
        func fase(_ periodo: Double) -> CGFloat {
            let k = (tempo * v / periodo).truncatingRemainder(dividingBy: 2)
            let u = k < 1 ? k : 2 - k
            return CGFloat((1 - cos(.pi * u)) / 2)
        }
        let e1 = fase(periodi[0]), e2 = fase(periodi[1]), e3 = fase(periodi[2])
        let s = lato
        return ZStack(alignment: .topLeading) {
            RadialGradient(colors: [c.fondoCentro, c.fondoBordo], center: UnitPoint(x: 0.5, y: 0.62), startRadius: 0, endRadius: s * 0.7)
            corrente(c.corrente1, lato: 0.78, x: -0.08, y: 0.04, dx: 0.28 * e1, dy: 0.18 * e1, scala: 1 + 0.15 * e1, opacita: 1)
            corrente(c.corrente2, lato: 0.62, x: 0.44, y: 0.20, dx: -0.34 * e2, dy: 0.22 * e2, scala: 1 - 0.15 * e2, opacita: c.opacita2)
            corrente(c.corrente3, lato: 0.58, x: 0.22, y: 0.56, dx: -0.10 * e3, dy: -0.40 * e3, scala: 1 + 0.2 * e3, opacita: c.opacita3)
            // Il riflesso in alto a sinistra e l'ombra in basso
            RadialGradient(stops: [.init(color: c.riflesso, location: 0), .init(color: c.riflesso, location: 0.06),
                                   .init(color: c.riflesso.opacity(0), location: 0.3)],
                           center: UnitPoint(x: 0.33, y: 0.26), startRadius: 0, endRadius: s)
            RadialGradient(colors: [c.ombraBasso, c.ombraBasso.opacity(0)], center: UnitPoint(x: 0.5, y: 1.3), startRadius: 0, endRadius: s * 0.6)
        }
        .frame(width: s, height: s)
        .compositingGroup()
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(c.filo, lineWidth: Tema.Misura.filo))
        .saturation(spenta ? c.saturazioneSpenta : 1)
        .brightness(spenta ? c.luceSpenta : 0)
        .shadow(color: c.alone.opacity(spenta ? 0 : c.aloneBase + lvl * c.aloneVoce), radius: s * (0.4 + CGFloat(lvl) * 0.5) / 2)
    }

    /// Una corrente di luce: un cerchio sfocato che si somma alla luce del fondo (mix-blend-mode: screen).
    private func corrente(_ colore: Color, lato quota: CGFloat, x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat,
                          scala: CGFloat, opacita: Double) -> some View {
        let d = lato * quota
        return Circle()
            .fill(colore)
            .frame(width: d, height: d)
            .scaleEffect(scala)
            .offset(x: lato * x + d * dx, y: lato * y + d * dy)
            .blur(radius: lato * 0.09)
            .opacity(opacita)
            .blendMode(.screen)
    }
}
