import SwiftUI

/// Dock delle applicazioni (tema «Liquid Glass»): capsula di vetro sottile con la Scrivania, il divisore
/// e le app. Le icone (50 pt) si ingrandiscono dal basso attorno al puntatore, fino a 1,55 volte.
/// Il Dock legge lo stato condiviso (app consentite, attiva, aperte); l'ingrandimento vive in `FilaDock`,
/// in uno stato locale: passare sul dock non fa ricalcolare nient'altro dell'app.
struct Dock: View {
    @EnvironmentObject var stato: StatoShell
    /// Quale app è davanti e quali sono aperte.
    @EnvironmentObject var sistema: StatoFinestre

    var body: some View {
        let attiva = sistema.appAttiva
        let voci = AppPrisma.allCases.filter { stato.appConsentita($0) }.map { app in
            VoceDock(app: app, attiva: attiva == app, aperta: sistema.aperta(app))
        }
        let shell = stato
        FilaDock(voci: voci, scrivaniaAttiva: attiva == nil,
                 apri: { app in shell.apriApp(app) },
                 mostraScrivania: { shell.mostraScrivania() })
            // Si ridisegna solo se cambiano le icone o i puntini, non a ogni cambiamento dello stato
            .equatable()
    }

    /// ⌥1…⌥9 per le prime nove app.
    static func scorciatoia(_ app: AppPrisma) -> String? {
        guard let i = AppPrisma.allCases.firstIndex(of: app), i < 9 else { return nil }
        return "⌥\(i + 1)"
    }
}

/// Un'app nel dock con i suoi segni: davanti, aperta.
struct VoceDock: Equatable {
    let app: AppPrisma
    let attiva: Bool
    let aperta: Bool
}

/// La fila del dock con l'ingrandimento al passaggio del puntatore, come il Dock del Mac: segue il puntatore
/// senza ritardo. Lo stato è tutto qui (`@State`): nessun oggetto condiviso cambia, nessuna transizione si annuncia.
/// Le icone crescono con una scala e la fila le distanzia con `DisposizioneFilaDock`: nessun figlio cambia misura.
private struct FilaDock: View, Equatable {
    let voci: [VoceDock]
    let scrivaniaAttiva: Bool
    let apri: (AppPrisma) -> Void
    let mostraScrivania: () -> Void
    /// Ingrandimento di ogni icona, Scrivania compresa, nell'ordine del dock (vuoto = tutte normali).
    @State var ingrandimenti: [CGFloat] = []
    /// L'icona sotto il puntatore (0 = Scrivania), con il suggerimento sopra.
    @State var sopra: Int? = nil

    /// Le azioni chiamano sempre la stessa shell: contano solo le icone e i loro segni.
    nonisolated static func == (a: FilaDock, b: FilaDock) -> Bool {
        a.voci == b.voci && a.scrivaniaAttiva == b.scrivaniaAttiva
    }

    var body: some View {
        let lato = Tema.Misura.dockIcona
        let numero = voci.count + 1
        DisposizioneFilaDock(ingrandimenti: ingrandimenti.count == numero ? ingrandimenti : [],
                             spazio: DisposizioneDock.spazio) {
            ElementoDock(titolo: "Scrivania", etichetta: "Scrivania", ingrandimento: ingrandimento(0, di: numero),
                         suggerimento: sopra == 0, attivo: scrivaniaAttiva, inEsecuzione: false) {
                mostraScrivania()
            } icona: {
                ImmagineNitida(percorso: "Icone/Prisma.png", lato: lato, riservaIngrandimento: Tema.Misura.dockIngrandimento)
            }
            .layoutValue(key: PostoDock.self, value: 0)
            DivisoreDock()
            ForEach(Array(voci.enumerated()), id: \.element.app) { indice, voce in
                ElementoDock(
                    titolo: voce.app.titolo,
                    etichetta: voce.app.nomeDock,
                    scorciatoia: Dock.scorciatoia(voce.app),
                    ingrandimento: ingrandimento(indice + 1, di: numero),
                    suggerimento: sopra == indice + 1,
                    attivo: voce.attiva,
                    inEsecuzione: voce.aperta
                ) {
                    apri(voce.app)
                } icona: {
                    IconaApp(app: voce.app, lato: lato, riservaIngrandimento: Tema.Misura.dockIngrandimento)
                }
                .layoutValue(key: PostoDock.self, value: indice + 1)
            }
        }
        .padding(.vertical, DisposizioneDock.margine)
        .padding(.horizontal, DisposizioneDock.margineLato)
        .vetro(.leggero, forma: .arrotondata(Tema.Raggio.dock))
        // Il dock e i suggerimenti sopra le icone: un solo gruppo di vetro (macOS 26)
        .gruppoVetro()
        // Mentre le icone sono ingrandite, anche la parte che sporge sopra il dock tiene il puntatore
        .padding(.top, ingrandimenti.isEmpty ? 0 : DisposizioneDock.sporgenzaIngrandimento)
        .onContinuousHover(coordinateSpace: CoordinateSpace.local) { fase in
            switch fase {
            case .active(let punto):
                segui(punto.x, numero: numero)
            case .ended:
                withAnimation(Tema.Moto.Shell.ritornoDock) { ingrandimenti = [] }
                if sopra != nil {
                    withAnimation(Tema.Moto.passaggio) { sopra = nil }
                }
            }
        }
    }

    private func ingrandimento(_ i: Int, di numero: Int) -> CGFloat {
        ingrandimenti.count == numero ? ingrandimenti[i] : 1
    }

    /// Ricalcola gli ingrandimenti con il puntatore in `x` (coordinate del dock come è disegnato ora).
    /// Il dock cresce attorno al suo centro: qualche passaggio fa coincidere l'icona ingrandita con il puntatore.
    /// Senza animazione, come il Dock del Mac; solo il suggerimento compare e scompare in dissolvenza.
    private func segui(_ x: CGFloat, numero: Int) {
        let attuali = ingrandimenti.count == numero ? ingrandimenti : Array(repeating: 1, count: numero)
        let puntatore = x - DisposizioneDock.disposizione(attuali).larghezza / 2
        var nuovi = attuali
        for _ in 0..<Tema.Misura.Shell.passiIngrandimento {
            nuovi = DisposizioneDock.disposizione(nuovi).centri.map { DisposizioneDock.ingrandimento(distanza: abs(puntatore - $0)) }
        }
        if nuovi != ingrandimenti { ingrandimenti = nuovi }
        let indice = DisposizioneDock.indice(sotto: puntatore, ingrandimenti: nuovi)
        if indice != sopra {
            withAnimation(Tema.Moto.passaggio) { sopra = indice }
        }
    }
}

/// Il posto di un elemento nella fila (0 = Scrivania, poi le app); il divisore non ne ha.
private struct PostoDock: LayoutValueKey {
    static let defaultValue: Int? = nil
}

/// La fila del dock: gli elementi in basso, ognuno al centro del suo posto, largo quanto la sua icona ingrandita.
/// Le icone crescono con una scala dentro l'elemento: qui si spostano soltanto, e le misure dei figli non cambiano.
private struct DisposizioneFilaDock: Layout {
    /// Ingrandimento di ogni icona (per posto); vuoto = tutte normali.
    var ingrandimenti: [CGFloat]
    var spazio: CGFloat

    /// Le misure dei figli, prese una volta.
    func makeCache(subviews: Subviews) -> [CGSize] {
        subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) -> CGSize {
        let posti = larghezze(subviews, misure: cache)
        let larghezza = posti.reduce(0, +) + spazio * CGFloat(max(0, subviews.count - 1))
        let altezza = cache.map(\.height).max() ?? 0
        return CGSize(width: larghezza, height: altezza)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) {
        let posti = larghezze(subviews, misure: cache)
        var x = bounds.minX
        for j in subviews.indices {
            subviews[j].place(at: CGPoint(x: x + posti[j] / 2, y: bounds.maxY), anchor: .bottom,
                              proposal: ProposedViewSize(cache[j]))
            x += posti[j] + spazio
        }
    }

    /// La larghezza del posto di ogni figlio: la sua, più quanto cresce la sua icona.
    private func larghezze(_ subviews: Subviews, misure: [CGSize]) -> [CGFloat] {
        let lato = Tema.Misura.dockIcona
        return subviews.indices.map { (j: Int) -> CGFloat in
            let base = j < misure.count ? misure[j].width : 0
            guard let posto = subviews[j][PostoDock.self], posto >= 0, posto < ingrandimenti.count else { return base }
            return base + lato * (ingrandimenti[posto] - 1)
        }
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

    /// L'icona sotto il puntatore (`puntatore` dal centro del dock): quella il cui posto, con metà dello spazio
    /// accanto, lo contiene. Nil sul divisore e sui margini.
    static func indice(sotto puntatore: CGFloat, ingrandimenti: [CGFloat]) -> Int? {
        let centri = disposizione(ingrandimenti).centri
        for (i, c) in centri.enumerated() where i < ingrandimenti.count {
            let meta = (Tema.Misura.dockIcona * ingrandimenti[i] + spazio) / 2
            if abs(puntatore - c) <= meta { return i }
        }
        return nil
    }

    /// Quanto l'icona più ingrandita sporge sopra il dock.
    static var sporgenzaIngrandimento: CGFloat { Tema.Misura.dockIcona * (Tema.Misura.dockIngrandimento - 1) }

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
/// il suggerimento con la scorciatoia quando il puntatore è sopra (lo decide la fila).
struct ElementoDock<Icona: View>: View {
    let titolo: String
    /// Il nome breve sotto l'icona.
    let etichetta: String
    var scorciatoia: String? = nil
    var ingrandimento: CGFloat = 1
    /// Il puntatore è sopra: compare il suggerimento.
    var suggerimento = false
    let attivo: Bool
    let inEsecuzione: Bool
    let azione: () -> Void
    @ViewBuilder let icona: () -> Icona

    var body: some View {
        let lato = Tema.Misura.dockIcona
        let m = Tema.Misura.Shell.self
        let crescita = lato * (ingrandimento - 1)
        Button(action: azione) {
            VStack(spacing: 0) {
                // L'icona si disegna sempre a 50 pt e si ingrandisce con una scala: la bitmap resta quella,
                // la cella resta larga 50 (la fila le fa posto) e niente si reimpagina
                icona()
                    .frame(width: lato, height: lato)
                    .scaleEffect(ingrandimento, anchor: .bottom)
                Text(etichetta)
                    .font(Tema.Testo.Shell.etichettaDock)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                    // Mai rimpicciolito: un nome lungo («Impostazioni») sborda appena dalla cella dell'icona,
                    // ma resta dentro la capsula grazie al margine laterale del dock (`DisposizioneDock.margineLato`)
                    .fixedSize()
                    .frame(width: lato, height: m.etichettaDock)
                    .padding(.top, m.etichettaSpazio)
                Circle()
                    .fill(Tema.Colore.Shell.puntinoDock)
                    .frame(width: Tema.Misura.puntinoDock, height: Tema.Misura.puntinoDock)
                    .opacity(inEsecuzione || attivo ? 1 : 0)
                    .padding(.top, m.puntinoSpazio)
            }
            // Si clicca anche l'icona ingrandita, che esce dalla cella in alto e ai lati
            .contentShape(FormaToccoDock(allargamento: crescita / 2, alzata: crescita))
        }
        .buttonStyle(StileIconaDock())
        .overlay(alignment: .top) {
            if suggerimento {
                SuggerimentoDock(testo: titolo, scorciatoia: scorciatoia)
                    .fixedSize()
                    // Il fondo del suggerimento sta sopra l'icona ingrandita
                    .alignmentGuide(VerticalAlignment.top) { d in
                        d[VerticalAlignment.bottom] + crescita + m.suggerimentoDistanza
                    }
                    .transition(.opacity.combined(with: .scale(scale: Tema.Moto.Dock.scalaSuggerimento, anchor: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .zIndex(suggerimento ? 1 : 0)
    }
}

/// Dove si clicca un elemento del dock: la cella, allargata ai lati e in alto quanto l'icona ingrandita.
private struct FormaToccoDock: Shape {
    var allargamento: CGFloat
    var alzata: CGFloat

    func path(in r: CGRect) -> Path {
        Path(CGRect(x: r.minX - allargamento, y: r.minY - alzata,
                    width: r.width + 2 * allargamento, height: r.height + alzata))
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
