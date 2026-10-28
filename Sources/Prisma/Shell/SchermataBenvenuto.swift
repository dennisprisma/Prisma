import SwiftUI
import AppKit

/// Schermata di benvenuto (il lucchetto in alto): sullo sfondo d'acqua restano la data, l'ora grande,
/// il logo e il cursore «scorri per entrare», per esempio quando ci si allontana dalla scrivania con un
/// cliente in studio. Lo sfondo è quello della scrivania (ShellView nasconde il resto sotto).
/// Si entra facendo scorrere il cursore, con un clic o con Invio. È una schermata di cortesia:
/// non protegge i dati (per quello c'è il blocco del Mac).
/// Non osserva lo stato: a ogni cambiamento si ridisegnano solo il cursore e il pulsante (sottoviste).
struct SchermataBenvenuto: View {
    /// Entrata e uscita della schermata sopra la scrivania (la usa ShellView). Entra appena più grande e
    /// dissolvendosi, con la curva del blocco (quella della transazione, nessuna nelle istantanee); esce
    /// salendo e svanendo con la sua molla. Con «Riduci movimento» solo la dissolvenza.
    static var transizione: AnyTransition {
        guard !Movimenti.calmo else { return .opacity }
        let ferma = EffettoFinestra(scala: 1, ancora: .center, y: 0, opacita: 1)
        return .asymmetric(
            insertion: AnyTransition.modifier(
                active: EffettoFinestra(scala: Tema.Moto.Blocco.scalaBenvenuto, ancora: .center, y: 0, opacita: 0),
                identity: ferma),
            removal: AnyTransition.modifier(
                active: EffettoFinestra(scala: 1, ancora: .center, y: Tema.Moto.Sblocco.uscitaSpostamento, opacita: 0),
                identity: ferma)
                .animation(Tema.Moto.Sblocco.uscitaBenvenuto))
    }

    var body: some View {
        GeometryReader { geo in
            let m = Tema.Misura.Shell.self
            // L'ora segue la larghezza della finestra (clamp(96px, 16vw, 188px) del tema)
            let corpoOra = min(max(geo.size.width * m.oraQuota, m.oraMinima), m.oraMassima)
            VStack(spacing: 0) {
                orologio(corpoOra)
                Spacer(minLength: 0)
                marchio
                sblocco
                    .padding(.top, m.marchioSblocco)
            }
            .foregroundColor(Tema.Colore.inchiostroBenvenuto)
            .padding(.top, geo.size.height * m.benvenutoAlto)
            .padding(.bottom, geo.size.height * m.benvenutoBasso)
            .padding(.horizontal, m.benvenutoLato)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .contentShape(Rectangle())
        // Il cursore lascia il campo sotto la schermata: niente si scrive nelle finestre coperte
        .onAppear { NSApp.keyWindow?.makeFirstResponder(nil) }
    }

    private func orologio(_ corpo: CGFloat) -> some View {
        TimelineView(.everyMinute) { contesto in
            VStack(spacing: 0) {
                Text(SchermataBenvenuto.data(contesto.date))
                    .font(Tema.Testo.Shell.dataBenvenuto)
                    .ombraTema(Tema.Ombra.Shell.dataBenvenuto)
                Text(Formati.ora.string(from: contesto.date))
                    .font(Tema.Testo.Shell.oraBenvenuto(corpo))
                    .tracking(Tema.Testo.Shell.spaziaturaOra(corpo))
                    .foregroundStyle(LinearGradient(colors: [Tema.Colore.Shell.oraAlto, Tema.Colore.Shell.oraBasso],
                                                    startPoint: .top, endPoint: .bottom))
                    .ombraTema(Tema.Ombra.Shell.oraBenvenuto)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    /// «Martedì 27 ottobre»: solo la prima lettera maiuscola.
    private static func data(_ giorno: Date) -> String {
        let testo = Formati.dataLunga.string(from: giorno)
        return testo.prefix(1).uppercased() + testo.dropFirst()
    }

    /// Il logo di Prisma con il nome e il motto.
    private var marchio: some View {
        let m = Tema.Misura.Shell.self
        return VStack(spacing: m.marchioBenvenutoSpazio) {
            LogoPrisma(colore: Tema.Colore.logo)
                .frame(height: m.logoBenvenuto)
            VStack(spacing: m.rigaTestoSpazio) {
                Text("Prisma")
                    .font(Tema.Testo.Shell.nomeBenvenuto)
                Text("Il tuo mondo. Al tuo ritmo.")
                    .font(Tema.Testo.Shell.mottoBenvenuto)
                    .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
            }
        }
    }

    private var sblocco: some View {
        let m = Tema.Misura.Shell.self
        return VStack(spacing: m.sbloccoSpazio) {
            CursoreSblocco()
            EntraConUnClic()
            Text("Schermata di cortesia: non protegge i dati.")
                .font(Tema.Testo.Shell.notaBenvenuto)
                .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
        }
    }
}

/// Il cursore «scorri per entrare». La manopola segue il dito (oltre i bordi con una resistenza elastica);
/// al rilascio oltre la soglia, o con un colpo rapido, finisce la corsa e si entra, altrimenti torna indietro.
/// Le molle partono con la velocità del gesto. Sta in una vista sua: a ogni movimento del mouse si
/// ridisegna solo lei, e lo stato di Prisma non si tocca finché non si entra.
private struct CursoreSblocco: View {
    @EnvironmentObject var stato: StatoShell
    /// La manopola è premuta. Torna da sola a false anche se il gesto si interrompe (⌘Tab a metà).
    @GestureState private var premuto = false
    @State private var corsa: CGFloat = 0
    /// Un trascinamento cominciato e non ancora rilasciato.
    @State private var inCorso = false
    /// Si entra: la manopola resta in fondo mentre la schermata se ne va (niente scatto indietro).
    @State private var entrata = false

    /// La corsa con la manopola allargata: anche in fondo resta dentro la capsula.
    private var corsaMassima: CGFloat {
        let m = Tema.Misura.Shell.self
        return max(1, m.cursoreBenvenuto.width - 2 * m.cursoreMargine - m.manopolaTrascinata)
    }

    var body: some View {
        let m = Tema.Misura.Shell.self
        let spenta = Tema.Moto.Sblocco.spegnimentoScritta * Double(corsa / corsaMassima)
        ZStack(alignment: .leading) {
            ScrittaScorri()
                .padding(.leading, m.manopola)
                .frame(maxWidth: .infinity)
                .opacity(min(1, max(0, 1 - spenta)))
            manopola
                .offset(x: corsa)
                .gesture(trascinamento)
                .allowsHitTesting(!entrata)
        }
        .padding(m.cursoreMargine)
        .frame(width: m.cursoreBenvenuto.width, height: m.cursoreBenvenuto.height)
        .vetro(.leggero, forma: .capsula)
        .onChange(of: premuto) { ancora in
            // Gesto interrotto senza rilascio: la manopola torna al suo posto
            guard !ancora, inCorso else { return }
            inCorso = false
            withAnimation(Movimenti.curva(Tema.Moto.Sblocco.ritorno())) { corsa = 0 }
        }
    }

    private var trascinamento: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($premuto) { _, attivo, _ in attivo = true }
            .onChanged { g in
                inCorso = true
                corsa = Movimenti.elastico(g.translation.width, massimo: corsaMassima)
            }
            .onEnded { g in rilascia(g) }
    }

    /// Il rilascio decide dal gesto (non dalla posizione disegnata): oltre la soglia, oppure se la previsione
    /// arriva in fondo dopo un pezzo di strada, si entra.
    private func rilascia(_ g: DragGesture.Value) {
        inCorso = false
        let s = Tema.Moto.Sblocco.self
        let traslazione = g.translation.width
        let prevista = g.predictedEndTranslation.width
        let partenza = Movimenti.elastico(traslazione, massimo: corsaMassima)
        let colpoRapido = prevista >= corsaMassima && traslazione >= corsaMassima * s.quotaColpoRapido
        guard traslazione >= corsaMassima * s.quotaSoglia || colpoRapido else {
            let v = Movimenti.velocita(traslazione: traslazione, prevista: prevista, distanza: -partenza)
            withAnimation(Movimenti.curva(s.ritorno(velocita: v))) { corsa = 0 }
            return
        }
        let v = Movimenti.velocita(traslazione: traslazione, prevista: prevista, distanza: corsaMassima - partenza)
        entrata = true
        withAnimation(Movimenti.curva(s.completa(velocita: v))) { corsa = corsaMassima }
        let st = stato
        DispatchQueue.main.asyncAfter(deadline: .now() + s.attesaPrimaDiEntrare) { st.sblocca(velocita: v) }
    }

    /// La manopola: capsula chiara con la freccia. Premuta si allarga verso destra con una scala (niente
    /// impaginazione); la freccia resta al centro senza deformarsi.
    private var manopola: some View {
        let m = Tema.Misura.Shell.self
        return Image(systemName: "chevron.right")
            .font(Tema.Testo.Shell.frecciaManopola)
            .foregroundColor(Tema.Colore.Shell.frecciaManopola)
            .offset(x: premuto ? (m.manopolaTrascinata - m.manopola) / 2 : 0)
            .frame(width: m.manopola, height: m.manopola)
            .background {
                Capsule(style: .continuous)
                    .fill(Tema.Colore.cursore)
                    .ombraTema(Tema.Ombra.manopola)
                    .scaleEffect(x: premuto ? m.manopolaTrascinata / m.manopola : 1, y: 1, anchor: .leading)
            }
            .contentShape(Capsule(style: .continuous))
            .animation(Movimenti.curva(Tema.Moto.Sblocco.pressione), value: premuto)
    }
}

/// «scorri per entrare» con il luccichio che passa. La fase si ricava dall'ora in una TimelineView
/// (al massimo 30 fotogrammi al secondo), invece di un'animazione infinita. Fermo con «Riduci movimento»
/// e nelle istantanee, dove il luccichio sta appena prima della scritta e non si vede.
private struct ScrittaScorri: View {
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var istantanea

    var body: some View {
        let testo = Text("scorri per entrare").font(Tema.Testo.Shell.scorriBenvenuto)
        let fermo = movimentoRidotto || istantanea
        return testo
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .overlay {
                TimelineView(.animation(minimumInterval: Tema.Moto.Sblocco.intervalloLuccichio, paused: fermo)) { contesto in
                    GeometryReader { g in
                        let w = g.size.width
                        let fase = fermo ? 0 : ScrittaScorri.fase(contesto.date)
                        LinearGradient(colors: [Tema.Colore.inchiostro.opacity(0), Tema.Colore.inchiostro, Tema.Colore.inchiostro.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: w / 3)
                            .offset(x: -w / 3 + CGFloat(fase) * (w + w / 3))
                    }
                }
                .mask { testo }
                .opacity(movimentoRidotto ? 0 : 1)
                .allowsHitTesting(false)
            }
    }

    /// A che punto è la passata: 0 appena prima della scritta, 1 appena dopo.
    static func fase(_ data: Date) -> Double {
        let periodo = Tema.Moto.Sblocco.periodoLuccichio
        return data.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: periodo) / periodo
    }
}

/// «Oppure entra con un clic» (anche con Invio).
private struct EntraConUnClic: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        Button { stato.sblocca() } label: {
            Text("Oppure entra con un clic").underline()
        }
        .buttonStyle(StileSemplice())
        .font(Tema.Testo.Shell.entraBenvenuto)
        .keyboardShortcut(.defaultAction)
    }
}

/// «Le tue app aperte»: le finestre aperte, in primo piano o ridotte, ognuna con il suo cliente
/// (o il suo contesto), con un clic per tornarci. Pannello di vetro del tema (switcher).
struct PannelloAppAperte: View {
    @EnvironmentObject var stato: StatoShell
    /// Le finestre aperte e quella in primo piano.
    @EnvironmentObject var sistema: StatoFinestre

    var body: some View {
        GeometryReader { geo in
            let m = Tema.Misura.Shell.self
            ZStack {
                Tema.Colore.Shell.veloPannello
                    .contentShape(Rectangle())
                    .onTapGesture { stato.pannelloAppAperte = false }
                // Il velo fa solo la dissolvenza; la scheda entra dal centro, come ⌘Tab
                pannello
                    .frame(width: max(0, min(m.appAperteLarghezza, geo.size.width - 2 * m.appAperteBordo)))
                    .frame(maxHeight: max(0, min(m.appAperteAltezza, geo.size.height - 2 * m.appAperteBordo)))
                    .entrataScheda(Tema.Moto.Pannelli.appAperte, scala: Tema.Moto.Pannelli.appAperteScala, ancora: .center)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var pannello: some View {
        let m = Tema.Misura.Shell.self
        return VStack(alignment: .leading, spacing: m.appAperteSpazio) {
            Text("Le tue app aperte")
                .font(Tema.Testo.sezione)
                .tracking(Tema.Testo.spaziaturaSezione)
                .foregroundColor(Tema.Colore.inchiostro)
            // Alto quanto le schede; oltre l'altezza massima le schede scorrono
            ViewThatFits(in: .vertical) {
                griglia
                ScrollView { griglia }
            }
            HStack(spacing: m.pulsantiSpazio) {
                Spacer()
                Button("Mostra la scrivania") {
                    stato.mostraScrivania()
                    stato.pannelloAppAperte = false
                }
                .buttonStyle(StileVetro())
                Button("Chiudi") { stato.pannelloAppAperte = false }
                    .buttonStyle(StileBlu())
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(m.appAperteMargine)
        .vetro(.pannello, forma: .arrotondata(Tema.Raggio.appAperte), riempimento: Tema.Colore.PannelliShell.coprente)
    }

    @ViewBuilder private var griglia: some View {
        let m = Tema.Misura.Shell.self
        let aperte = Array(sistema.elenco.reversed())
        if aperte.isEmpty {
            VStack(spacing: m.rigaTestoSpazio) {
                Text("La scrivania è tutta tua.")
                    .font(Tema.Testo.titolo)
                    .foregroundColor(Tema.Colore.inchiostro)
                Text("Apri un'app dal dock per iniziare.")
                    .font(Tema.Testo.secondario)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, m.appAperteMargine * 2)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: m.schedaAppMinima), spacing: m.appAperteSpazio)],
                      spacing: m.appAperteSpazio) {
                ForEach(aperte) { f in
                    SchedaAppAperta(finestra: f, inPrimoPiano: f.app == sistema.appAttiva)
                }
            }
        }
    }
}

/// Una scheda di «Le tue app aperte»: icona, nome, cliente o contesto della finestra, stato.
private struct SchedaAppAperta: View {
    @EnvironmentObject var stato: StatoShell
    let finestra: StatoShell.Finestra
    let inPrimoPiano: Bool
    @State var sopra = false

    var body: some View {
        let m = Tema.Misura.Shell.self
        let forma = RoundedRectangle(cornerRadius: Tema.Raggio.schedaApp, style: .continuous)
        Button {
            // Prima la modifica animata (il ripristino dal dock), poi la chiusura del pannello
            stato.apri(finestra.app)
            stato.pannelloAppAperte = false
        } label: {
            VStack(spacing: m.schedaAppSpazio) {
                IconaApp(app: finestra.app, lato: Tema.Misura.iconaAppAperte)
                    .padding(.bottom, m.schedaAppSpazio)
                Text(finestra.app.titolo)
                    .font(Tema.Testo.Shell.nomeAppAperta)
                    .foregroundColor(Tema.Colore.inchiostro)
                // Il cliente (o il contesto) di questa finestra; una riga vuota tiene le schede alte uguali
                Text(stato.contesto(di: finestra.app) ?? " ")
                    .font(Tema.Testo.Shell.contestoAppAperta)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                Text(finestra.ridotta ? "Ridotta nel dock" : inPrimoPiano ? "In primo piano" : "Aperta")
                    .font(Tema.Testo.Shell.statoAppAperta)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
            .padding(m.schedaAppMargine)
            .background(forma.fill(sopra ? Tema.Colore.chipSopra : Tema.Colore.chip))
            .overlay(forma.strokeBorder(Tema.Colore.bordoChip, lineWidth: Tema.Misura.filo))
            .contentShape(forma)
        }
        .buttonStyle(StileSemplice())
        .onHover { s in withAnimation(Tema.Moto.passaggio) { sopra = s } }
    }
}
