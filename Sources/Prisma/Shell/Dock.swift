import SwiftUI

/// Dock delle applicazioni (tema «Liquid Glass»): capsula di vetro sottile con la Scrivania, il divisore
/// e le app. Le icone (50 pt) non si ingrandiscono: al passaggio del puntatore compare sopra l'icona
/// un piccolo fumetto scuro con il nome dell'app, come nel Dock del Mac.
/// Il Dock legge lo stato condiviso (app consentite, attiva, aperte); il passaggio vive in `FilaDock`,
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

/// La fila del dock: le icone restano sempre a 50 pt, come nel Dock del Mac con l'ingrandimento spento.
/// Lo stato è tutto qui (`@State`): quale icona ha il puntatore sopra, con il nome nel fumetto.
/// Nessun oggetto condiviso cambia: passare sul dock non fa ricalcolare nient'altro dell'app.
private struct FilaDock: View, Equatable {
    let voci: [VoceDock]
    let scrivaniaAttiva: Bool
    let apri: (AppPrisma) -> Void
    let mostraScrivania: () -> Void
    /// L'icona sotto il puntatore (0 = Scrivania), con il nome sopra.
    @State var sopra: Int? = nil

    /// Le azioni chiamano sempre la stessa shell: contano solo le icone e i loro segni.
    nonisolated static func == (a: FilaDock, b: FilaDock) -> Bool {
        a.voci == b.voci && a.scrivaniaAttiva == b.scrivaniaAttiva
    }

    var body: some View {
        let lato = Tema.Misura.dockIcona
        HStack(alignment: .bottom, spacing: DisposizioneDock.spazio) {
            ElementoDock(titolo: "Scrivania", etichetta: "Scrivania",
                         descrizione: "Torna alla scrivania: la tua giornata e i widget",
                         suggerimento: sopra == 0, attivo: scrivaniaAttiva, inEsecuzione: false) {
                mostraScrivania()
            } icona: {
                ImmagineNitida(percorso: "Icone/Prisma.png", lato: lato)
            }
            .onHover { passa(0, $0) }
            DivisoreDock()
            ForEach(Array(voci.enumerated()), id: \.element.app) { indice, voce in
                ElementoDock(
                    titolo: voce.app.titolo,
                    etichetta: voce.app.nomeDock,
                    scorciatoia: Dock.scorciatoia(voce.app),
                    // Che cosa fa l'app, in una riga: la legge VoiceOver (il fumetto mostra solo il nome)
                    descrizione: voce.app.aiuto.inBreve,
                    suggerimento: sopra == indice + 1,
                    attivo: voce.attiva,
                    inEsecuzione: voce.aperta
                ) {
                    apri(voce.app)
                } icona: {
                    IconaApp(app: voce.app, lato: lato)
                }
                .onHover { passa(indice + 1, $0) }
            }
        }
        .padding(.vertical, DisposizioneDock.margine)
        .padding(.horizontal, DisposizioneDock.margineLato)
        .vetro(.leggero, forma: .arrotondata(Tema.Raggio.dock))
    }

    /// Il puntatore entra o esce da un'icona: il fumetto compare subito, senza attesa, come nel Dock del Mac.
    /// Uscendo si spegne solo se è ancora quello dell'icona lasciata (l'ingresso nella vicina può arrivare prima).
    private func passa(_ indice: Int, _ dentro: Bool) {
        if dentro {
            if sopra != indice { withAnimation(Tema.Moto.Dock.suggerimento) { sopra = indice } }
        } else if sopra == indice {
            withAnimation(Tema.Moto.Dock.suggerimento) { sopra = nil }
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
    /// («Impostazioni» è più largo dell'icona); `disposizione` lo conta.
    static var margineLato: CGFloat {
        margine + Tema.Misura.Shell.margineDockLato + Tema.Misura.PannelliShell.etichetteDockLato * Tipo.fattore
    }
    /// Il divisore: un filo con il suo margine (oltre lo spazio fra gli elementi).
    static var rientroDivisore: CGFloat { max(0, Tema.Misura.Shell.divisoreMargine - spazio) }
    static var larghezzaDivisore: CGFloat { Tema.Misura.filo * 2 + 2 * rientroDivisore }

    /// Centri delle icone (Scrivania compresa) rispetto al centro del dock e larghezza del dock.
    static func disposizione(icone numero: Int) -> (centri: [CGFloat], larghezza: CGFloat) {
        let lato = Tema.Misura.dockIcona
        var x = margineLato
        var centri: [CGFloat] = []
        for i in 0..<max(0, numero) {
            centri.append(x + lato / 2)
            x += lato + spazio
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
        let centri = disposizione(icone: elenco.count + 1).centri
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

/// Elemento del dock: l'icona, il nome sotto, il puntino se l'app è aperta e, con il puntatore sopra
/// (lo decide la fila), il fumetto scuro con il nome dell'app, come nel Dock del Mac.
struct ElementoDock<Icona: View>: View {
    let titolo: String
    /// Il nome breve sotto l'icona.
    let etichetta: String
    var scorciatoia: String? = nil
    /// A che cosa serve l'app: solo per VoiceOver, non compare sullo schermo.
    var descrizione: String? = nil
    /// Il puntatore è sopra: compare il fumetto con il nome.
    var suggerimento = false
    let attivo: Bool
    let inEsecuzione: Bool
    let azione: () -> Void
    @ViewBuilder let icona: () -> Icona

    var body: some View {
        let lato = Tema.Misura.dockIcona
        let m = Tema.Misura.Shell.self
        Button(action: azione) {
            VStack(spacing: 0) {
                icona()
                    .frame(width: lato, height: lato)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(StileIconaDock())
        .accessibilityLabel(Text(titolo))
        .accessibilityHint(Text(aiutoVoiceOver))
        // Il fumetto sta sopra il dock (in un overlay: non sposta niente) e non prende il puntatore
        .overlay(alignment: .top) {
            if suggerimento {
                SuggerimentoDock(testo: titolo)
                    .fixedSize()
                    // La punta del fumetto sta `suggerimentoDistanza` sopra l'icona, fuori dalla capsula del dock
                    .alignmentGuide(VerticalAlignment.top) { d in
                        d[VerticalAlignment.bottom] + m.suggerimentoDistanza
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .zIndex(suggerimento ? 1 : 0)
    }

    /// Per VoiceOver: che cosa fa l'app e la scorciatoia.
    private var aiutoVoiceOver: String {
        [descrizione, scorciatoia.map { "Scorciatoia \($0)" }].compactMap { $0 }.joined(separator: ". ")
    }
}

/// Icona premuta: più scura (brightness .82 del tema).
private struct StileIconaDock: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? Tema.Misura.Shell.premutoDock : 0)
    }
}

/// Fumetto sopra l'icona, come nel Dock del Mac: rettangolo arrotondato scuro con la punta in basso al centro
/// e il solo nome dell'app in bianco. Uguale in chiaro e in scuro (in scuro con un filo chiaro attorno).
struct SuggerimentoDock: View {
    let testo: String

    var body: some View {
        let m = Tema.Misura.Shell.self
        let forma = FormaFumettoDock(raggio: Tema.Raggio.Shell.fumettoDock,
                                     larghezzaPunta: m.fumettoPuntaLarghezza, altezzaPunta: m.fumettoPuntaAltezza)
        Text(testo)
            .font(Tema.Testo.Shell.suggerimentoDock)
            .foregroundColor(Tema.Colore.Shell.testoFumettoDock)
            .lineLimit(1)
            .padding(m.suggerimentoMargine)
            // Lo spazio della punta, sotto il testo
            .padding(.bottom, m.fumettoPuntaAltezza)
            .background(forma.fill(Tema.Colore.Shell.fondoFumettoDock))
            .overlay(forma.stroke(Tema.Colore.Shell.filoFumettoDock, lineWidth: Tema.Misura.filo * 2))
            .ombraTema(Tema.Ombra.Shell.fumettoDock)
    }
}

/// Il contorno del fumetto: un rettangolo arrotondato e, sotto al centro, la punta che indica l'icona.
/// Un solo tracciato, così il filo attorno non passa fra il corpo e la punta.
private struct FormaFumettoDock: Shape {
    var raggio: CGFloat
    var larghezzaPunta: CGFloat
    var altezzaPunta: CGFloat

    func path(in r: CGRect) -> Path {
        let corpo = CGRect(x: r.minX, y: r.minY, width: r.width, height: max(0, r.height - altezzaPunta))
        let k = min(raggio, corpo.height / 2, corpo.width / 2)
        let meta = min(larghezzaPunta / 2, max(0, corpo.width / 2 - k))
        var p = Path()
        p.move(to: CGPoint(x: corpo.minX + k, y: corpo.minY))
        p.addArc(tangent1End: CGPoint(x: corpo.maxX, y: corpo.minY), tangent2End: CGPoint(x: corpo.maxX, y: corpo.maxY), radius: k)
        p.addArc(tangent1End: CGPoint(x: corpo.maxX, y: corpo.maxY), tangent2End: CGPoint(x: corpo.minX, y: corpo.maxY), radius: k)
        p.addLine(to: CGPoint(x: corpo.midX + meta, y: corpo.maxY))
        p.addLine(to: CGPoint(x: corpo.midX, y: corpo.maxY + altezzaPunta))
        p.addLine(to: CGPoint(x: corpo.midX - meta, y: corpo.maxY))
        p.addArc(tangent1End: CGPoint(x: corpo.minX, y: corpo.maxY), tangent2End: CGPoint(x: corpo.minX, y: corpo.minY), radius: k)
        p.addArc(tangent1End: CGPoint(x: corpo.minX, y: corpo.minY), tangent2End: CGPoint(x: corpo.maxX, y: corpo.minY), radius: k)
        p.closeSubpath()
        return p
    }
}
