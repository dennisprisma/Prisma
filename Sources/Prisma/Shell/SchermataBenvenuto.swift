import SwiftUI
import AppKit

/// Schermata di benvenuto (il lucchetto in alto): sullo sfondo d'acqua restano la data, l'ora grande,
/// il logo e il cursore «scorri per entrare», per esempio quando ci si allontana dalla scrivania con un
/// cliente in studio. Lo sfondo è quello della scrivania (ShellView nasconde il resto sotto).
/// Si entra facendo scorrere il cursore, con un clic o con Invio. È una schermata di cortesia:
/// non protegge i dati (per quello c'è il blocco del Mac).
struct SchermataBenvenuto: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.accessibilityReduceMotion) var movimentoRidotto
    @State var corsa: CGFloat = 0
    @State var trascina = false
    @State var luccichio = false

    private var corsaMassima: CGFloat {
        let m = Tema.Misura.Shell.self
        return max(1, m.cursoreBenvenuto.width - 2 * m.cursoreMargine - m.manopola)
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
            ZStack(alignment: .leading) {
                scritta
                    .padding(.leading, m.manopola)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - Double(corsa / corsaMassima))
                manopola
                    .offset(x: corsa)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                if !trascina { withAnimation(Tema.Moto.molla) { trascina = true } }
                                corsa = min(max(0, g.translation.width), corsaMassima)
                            }
                            .onEnded { _ in
                                withAnimation(Tema.Moto.molla) { trascina = false }
                                if corsa >= corsaMassima * m.sogliaBenvenuto {
                                    entra()
                                } else {
                                    withAnimation(Tema.Moto.Shell.ritornoManopola) { corsa = 0 }
                                }
                            }
                    )
            }
            .padding(m.cursoreMargine)
            .frame(width: m.cursoreBenvenuto.width, height: m.cursoreBenvenuto.height)
            .vetro(.leggero, forma: .capsula)

            Button { entra() } label: {
                Text("Oppure entra con un clic").underline()
            }
            .buttonStyle(StileSemplice())
            .font(Tema.Testo.Shell.entraBenvenuto)
            .keyboardShortcut(.defaultAction)
            Text("Schermata di cortesia: non protegge i dati.")
                .font(Tema.Testo.Shell.notaBenvenuto)
                .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
        }
    }

    /// «scorri per entrare» con il luccichio che passa (fermo con «Riduci movimento»).
    private var scritta: some View {
        let testo = Text("scorri per entrare").font(Tema.Testo.Shell.scorriBenvenuto)
        return testo
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .overlay {
                GeometryReader { g in
                    let w = g.size.width
                    LinearGradient(colors: [Tema.Colore.inchiostro.opacity(0), Tema.Colore.inchiostro, Tema.Colore.inchiostro.opacity(0)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: w / 3)
                        .offset(x: luccichio ? w : -w / 3)
                }
                .mask { testo }
                .opacity(movimentoRidotto ? 0 : 1)
                .allowsHitTesting(false)
            }
            .onAppear {
                guard !movimentoRidotto else { return }
                withAnimation(Tema.Moto.Shell.luccichio) { luccichio = true }
            }
    }

    /// La manopola: capsula chiara con la freccia, si allarga mentre la trascini.
    private var manopola: some View {
        let m = Tema.Misura.Shell.self
        return Image(systemName: "chevron.right")
            .font(Tema.Testo.Shell.frecciaManopola)
            .foregroundColor(Tema.Colore.Shell.frecciaManopola)
            .frame(width: trascina ? m.manopolaTrascinata : m.manopola, height: m.manopola)
            .background {
                Capsule(style: .continuous)
                    .fill(Tema.Colore.cursore)
                    .ombraTema(Tema.Ombra.manopola)
            }
            .contentShape(Capsule(style: .continuous))
    }

    private func entra() {
        withAnimation(Animazioni.apertura) { stato.bloccato = false }
        corsa = 0
    }
}

/// «Le tue app aperte»: le finestre aperte, in primo piano o ridotte, ognuna con il suo cliente
/// (o il suo contesto), con un clic per tornarci. Pannello di vetro del tema (switcher).
struct PannelloAppAperte: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        GeometryReader { geo in
            let m = Tema.Misura.Shell.self
            ZStack {
                Tema.Colore.Shell.veloPannello
                    .contentShape(Rectangle())
                    .onTapGesture { stato.pannelloAppAperte = false }
                pannello
                    .frame(width: max(0, min(m.appAperteLarghezza, geo.size.width - 2 * m.appAperteBordo)))
                    .frame(maxHeight: max(0, min(m.appAperteAltezza, geo.size.height - 2 * m.appAperteBordo)))
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
                    stato.pannelloAppAperte = false
                    stato.mostraScrivania()
                }
                .buttonStyle(StileVetro())
                Button("Chiudi") { stato.pannelloAppAperte = false }
                    .buttonStyle(StileBlu())
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(m.appAperteMargine)
        .vetro(.pannello, forma: .arrotondata(Tema.Raggio.appAperte))
    }

    @ViewBuilder private var griglia: some View {
        let m = Tema.Misura.Shell.self
        let aperte = Array(stato.finestre.reversed())
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
                    SchedaAppAperta(finestra: f, inPrimoPiano: f.app == stato.appAttiva)
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
            stato.pannelloAppAperte = false
            stato.apri(finestra.app)
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
