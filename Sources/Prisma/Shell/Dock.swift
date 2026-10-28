import SwiftUI

/// Dock delle applicazioni (tema «Liquid Glass»): capsula di vetro sottile con la Scrivania, il divisore
/// e le app. Le icone (50 pt) si ingrandiscono dal basso attorno al puntatore, fino a 1,55 volte.
struct Dock: View {
    @EnvironmentObject var stato: StatoShell
    /// Quale app è davanti e quali sono aperte.
    @EnvironmentObject var sistema: StatoFinestre
    /// Ingrandimento di ogni icona, Scrivania compresa, nell'ordine del dock (vuoto = tutte normali).
    @State var ingrandimenti: [CGFloat] = []

    var body: some View {
        let elenco = AppPrisma.allCases.filter { stato.appConsentita($0) }
        let numero = elenco.count + 1
        let lato = Tema.Misura.dockIcona
        HStack(alignment: .bottom, spacing: DisposizioneDock.spazio) {
            ElementoDock(titolo: "Scrivania", etichetta: "Scrivania", ingrandimento: ingrandimento(0, di: numero),
                         attivo: sistema.appAttiva == nil, inEsecuzione: false) {
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
                    attivo: sistema.appAttiva == app,
                    inEsecuzione: sistema.aperta(app)
                ) {
                    stato.apri(app)
                } icona: {
                    IconaApp(app: app, lato: lato, riservaIngrandimento: Tema.Misura.dockIngrandimento)
                }
            }
        }
        .padding(.vertical, DisposizioneDock.margine)
        .padding(.horizontal, DisposizioneDock.margineLato)
        .vetro(.leggero, forma: .arrotondata(Tema.Raggio.dock))
        // Il dock e i suggerimenti sopra le icone: un solo gruppo di vetro (macOS 26)
        .gruppoVetro()
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
        let puntatore = x - DisposizioneDock.disposizione(attuali).larghezza / 2
        var nuovi = attuali
        for _ in 0..<Tema.Misura.Shell.passiIngrandimento {
            nuovi = DisposizioneDock.disposizione(nuovi).centri.map { DisposizioneDock.ingrandimento(distanza: abs(puntatore - $0)) }
        }
        ingrandimenti = nuovi
    }

    /// ⌥1…⌥9 per le prime nove app.
    static func scorciatoia(_ app: AppPrisma) -> String? {
        guard let i = AppPrisma.allCases.firstIndex(of: app), i < 9 else { return nil }
        return "⌥\(i + 1)"
    }
}

/// Misure e disposizione del dock, fuori dalla vista: le usa anche lo stato delle finestre (da dove si apre
/// un'app, dove va a ridursi), che non sta sul thread delle viste.
enum DisposizioneDock {
    /// Spazio fra le icone e margini (in frazioni del lato dell'icona, come nel tema).
    static var spazio: CGFloat { Tema.Misura.dockIcona * Tema.Misura.dockSpazioQuota }
    static var margine: CGFloat { Tema.Misura.dockIcona * Tema.Misura.dockMargineQuota }
    /// Il margine laterale tiene dentro la capsula anche i nomi lunghi sotto la prima e l'ultima icona
    /// («Impostazioni» è più largo dell'icona): l'ingrandimento lo conta in `disposizione`, come prima.
    static var margineLato: CGFloat {
        margine + Tema.Misura.Shell.margineDockLato + Tema.Misura.PannelliShell.etichetteDockLato * Tipo.fattore
    }
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

    /// Altezza sotto l'icona: nome e puntino dell'app aperta.
    static var altezzaSotto: CGFloat {
        let m = Tema.Misura.Shell.self
        return m.etichettaSpazio + m.etichettaDock + m.puntinoSpazio + Tema.Misura.puntinoDock
    }

    /// Centro dell'icona dell'app nel dock a riposo, nelle coordinate della shell (`ShellView.spazioShell`) grande
    /// `misura`. `elenco`: le app del dock (quelle consentite). Con il dock nascosto l'icona è sul bordo in basso.
    static func centroIcona(_ app: AppPrisma, tra elenco: [AppPrisma], in misura: CGSize, nascosto: Bool) -> CGPoint? {
        guard let i = elenco.firstIndex(of: app), misura.width > 0, misura.height > 0 else { return nil }
        // La Scrivania è la prima icona
        let centri = disposizione(Array(repeating: 1, count: elenco.count + 1)).centri
        guard i + 1 < centri.count else { return nil }
        let lato = Tema.Misura.dockIcona
        let y = misura.height - Tema.Misura.dockDalBasso - margine - altezzaSotto - lato / 2
        return CGPoint(x: misura.width / 2 + centri[i + 1],
                       y: nascosto ? min(y + Misure.Dock.corsaNascosto, misura.height) : y)
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
            .padding(.horizontal, DisposizioneDock.rientroDivisore)
            .padding(.bottom, DisposizioneDock.altezzaSotto)
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
                    // Mai rimpicciolito: un nome lungo («Impostazioni») sborda appena dalla cella dell'icona,
                    // ma resta dentro la capsula grazie al margine laterale del dock (`DisposizioneDock.margineLato`)
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
                    .transition(.opacity.combined(with: .scale(scale: Tema.Moto.Dock.scalaSuggerimento, anchor: .bottom)))
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
