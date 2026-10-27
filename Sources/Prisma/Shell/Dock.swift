import SwiftUI

/// Dock delle applicazioni (tema «Liquid Glass»): capsula di vetro sottile con la Scrivania, il divisore
/// e le app. Le icone (50 pt) si ingrandiscono dal basso attorno al puntatore, fino a 1,55 volte.
struct Dock: View {
    @EnvironmentObject var stato: StatoShell
    /// Ingrandimento di ogni icona, Scrivania compresa, nell'ordine del dock (vuoto = tutte normali).
    @State var ingrandimenti: [CGFloat] = []

    var body: some View {
        let elenco = AppPrisma.allCases.filter { stato.appConsentita($0) }
        let numero = elenco.count + 1
        let lato = Tema.Misura.dockIcona
        HStack(alignment: .bottom, spacing: Dock.spazio) {
            ElementoDock(titolo: "Scrivania", etichetta: "Scrivania", ingrandimento: ingrandimento(0, di: numero),
                         attivo: stato.appAttiva == nil, inEsecuzione: false) {
                stato.mostraScrivania()
            } icona: {
                ImmagineNitida(percorso: "Icone/Prisma.png", lato: lato, riservaIngrandimento: Tema.Misura.dockIngrandimento)
            }
            DivisoreDock()
            ForEach(Array(elenco.enumerated()), id: \.element) { indice, app in
                ElementoDock(
                    titolo: app.titolo,
                    etichetta: app.nomeDock,
                    scorciatoia: Dock.scorciatoia(app),
                    ingrandimento: ingrandimento(indice + 1, di: numero),
                    attivo: stato.appAttiva == app,
                    inEsecuzione: stato.aperta(app)
                ) {
                    stato.apri(app)
                } icona: {
                    IconaApp(app: app, lato: lato, riservaIngrandimento: Tema.Misura.dockIngrandimento)
                }
            }
        }
        .padding(.vertical, Dock.margine)
        .padding(.horizontal, Dock.margineLato)
        .vetro(.leggero, forma: .arrotondata(Tema.Raggio.dock))
        .onContinuousHover(coordinateSpace: CoordinateSpace.local) { fase in
            switch fase {
            case .active(let punto):
                aggiorna(punto.x, numero: numero)
            case .ended:
                withAnimation(Tema.Moto.Shell.ritornoDock) { ingrandimenti = [] }
            }
        }
    }

    private func ingrandimento(_ i: Int, di numero: Int) -> CGFloat {
        ingrandimenti.count == numero ? ingrandimenti[i] : 1
    }

    /// Ricalcola gli ingrandimenti con il puntatore in `x` (coordinate del dock come è disegnato ora).
    /// Il dock cresce attorno al suo centro: qualche passaggio fa coincidere l'icona ingrandita con il puntatore.
    private func aggiorna(_ x: CGFloat, numero: Int) {
        let attuali = ingrandimenti.count == numero ? ingrandimenti : Array(repeating: 1, count: numero)
        let puntatore = x - Dock.disposizione(attuali).larghezza / 2
        var nuovi = attuali
        for _ in 0..<Tema.Misura.Shell.passiIngrandimento {
            nuovi = Dock.disposizione(nuovi).centri.map { Dock.ingrandimento(distanza: abs(puntatore - $0)) }
        }
        ingrandimenti = nuovi
    }

    // MARK: Misure del dock

    /// Spazio fra le icone e margini (in frazioni del lato dell'icona, come nel tema).
    static var spazio: CGFloat { Tema.Misura.dockIcona * Tema.Misura.dockSpazioQuota }
    static var margine: CGFloat { Tema.Misura.dockIcona * Tema.Misura.dockMargineQuota }
    static var margineLato: CGFloat { margine + Tema.Misura.Shell.margineDockLato }
    /// Il divisore: un filo con il suo margine (oltre lo spazio fra gli elementi).
    static var rientroDivisore: CGFloat { max(0, Tema.Misura.Shell.divisoreMargine - spazio) }
    static var larghezzaDivisore: CGFloat { Tema.Misura.filo * 2 + 2 * rientroDivisore }

    /// Ingrandimento di un'icona a una certa distanza dal puntatore: 1 + (max − 1) · cos²(d / portata · π/2).
    static func ingrandimento(distanza: CGFloat) -> CGFloat {
        let portata = Tema.Misura.dockPortata * Tema.Misura.dockIcona
        guard distanza < portata else { return 1 }
        let c = cos(distanza / portata * .pi / 2)
        return 1 + (Tema.Misura.dockIngrandimento - 1) * c * c
    }

    /// Centri delle icone rispetto al centro del dock e larghezza del dock, con gli ingrandimenti dati.
    static func disposizione(_ ingrandimenti: [CGFloat]) -> (centri: [CGFloat], larghezza: CGFloat) {
        var x = margineLato
        var centri: [CGFloat] = []
        for (i, k) in ingrandimenti.enumerated() {
            let w = Tema.Misura.dockIcona * k
            centri.append(x + w / 2)
            x += w + spazio
            // Dopo la Scrivania c'è il divisore
            if i == 0 { x += larghezzaDivisore + spazio }
        }
        let larghezza = x - spazio + margineLato
        return (centri.map { $0 - larghezza / 2 }, larghezza)
    }

    /// ⌥1…⌥9 per le prime nove app.
    static func scorciatoia(_ app: AppPrisma) -> String? {
        guard let i = AppPrisma.allCases.firstIndex(of: app), i < 9 else { return nil }
        return "⌥\(i + 1)"
    }

    /// Altezza sotto l'icona: nome e puntino dell'app aperta.
    static var altezzaSotto: CGFloat {
        let m = Tema.Misura.Shell.self
        return m.etichettaSpazio + m.etichettaDock + m.puntinoSpazio + Tema.Misura.puntinoDock
    }
}

/// Il divisore fra la Scrivania e le app: un filo verticale che sfuma in alto e in basso.
struct DivisoreDock: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Tema.Colore.pozzettoScuro.opacity(0), Tema.Colore.pozzettoScuro,
                                          Tema.Colore.pozzettoScuro.opacity(0)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: Tema.Misura.filo * 2, height: Tema.Misura.dockIcona)
            .padding(.horizontal, Dock.rientroDivisore)
            .padding(.bottom, Dock.altezzaSotto)
    }
}

/// Elemento del dock: l'icona che si ingrandisce dal basso, il nome sotto, il puntino se l'app è aperta,
/// il suggerimento con la scorciatoia al passaggio del mouse.
struct ElementoDock<Icona: View>: View {
    let titolo: String
    /// Il nome breve sotto l'icona.
    let etichetta: String
    var scorciatoia: String? = nil
    var ingrandimento: CGFloat = 1
    let attivo: Bool
    let inEsecuzione: Bool
    let azione: () -> Void
    @ViewBuilder let icona: () -> Icona
    @State var sopra = false

    var body: some View {
        let lato = Tema.Misura.dockIcona
        let m = Tema.Misura.Shell.self
        Button(action: azione) {
            VStack(spacing: 0) {
                // L'icona si disegna sempre a 50 pt e si ingrandisce con una scala: la bitmap resta quella
                icona()
                    .frame(width: lato, height: lato)
                    .scaleEffect(ingrandimento, anchor: .bottom)
                    .frame(width: lato * ingrandimento, height: lato, alignment: .bottom)
                Text(etichetta)
                    .font(Tema.Testo.Shell.etichettaDock)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                    // Mai rimpicciolito: un nome lungo («Impostazioni») sborda appena dalla cella dell'icona
                    .fixedSize()
                    .frame(width: lato * ingrandimento, height: m.etichettaDock)
                    .padding(.top, m.etichettaSpazio)
                Circle()
                    .fill(Tema.Colore.Shell.puntinoDock)
                    .frame(width: Tema.Misura.puntinoDock, height: Tema.Misura.puntinoDock)
                    .opacity(inEsecuzione || attivo ? 1 : 0)
                    .padding(.top, m.puntinoSpazio)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StileIconaDock())
        .onHover { s in withAnimation(Tema.Moto.passaggio) { sopra = s } }
        .overlay(alignment: .top) {
            if sopra {
                SuggerimentoDock(testo: titolo, scorciatoia: scorciatoia)
                    .fixedSize()
                    // Il fondo del suggerimento sta sopra l'icona ingrandita
                    .alignmentGuide(VerticalAlignment.top) { d in
                        d[VerticalAlignment.bottom] + lato * (ingrandimento - 1) + m.suggerimentoDistanza
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(sopra ? 1 : 0)
    }
}

/// Icona premuta: più scura (brightness .82 del tema).
private struct StileIconaDock: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? Tema.Misura.Shell.premutoDock : 0)
    }
}

/// Suggerimento sopra l'icona: capsula di vetro sottile con il nome e la scorciatoia.
struct SuggerimentoDock: View {
    let testo: String
    let scorciatoia: String?

    var body: some View {
        HStack(spacing: Tema.Misura.Shell.pulsanteBarraSpazio) {
            Text(testo)
                .font(Tema.Testo.Shell.suggerimentoDock)
                .foregroundColor(Tema.Colore.inchiostro)
            if let s = scorciatoia {
                TastoBarra(testo: s)
            }
        }
        .padding(Tema.Misura.Shell.suggerimentoMargine)
        .vetro(.leggero, forma: .capsula)
    }
}
