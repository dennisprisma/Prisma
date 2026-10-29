import SwiftUI

// Proprietario: G7 (guida). Il pannello «Guida di Prisma» (Come funziona / Le app / Le parole), la scheda
// «Come si usa» di un'app e il pulsante «Come si usa» delle intestazioni. Testi in GuidaPrisma.swift e
// Glossario.swift, gettoni in TemaGuida.swift.

/// Il pannello della guida: velo più una scheda di vetro centrata, come «Le tue app aperte». Il contenuto
/// segue `sistema.guida`; cambiare scheda o pagina non anima il contenitore di ShellView.
struct PannelloGuida: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var sistema: StatoFinestre

    var body: some View {
        GeometryReader { geo in
            let m = Tema.Misura.Guida.self
            ZStack {
                Tema.Colore.Shell.veloPannello
                    .contentShape(Rectangle())
                    .onTapGesture { stato.chiudiGuida() }
                scheda
                    .frame(width: max(0, min(m.larghezza, geo.size.width - 2 * m.bordo)),
                           height: max(0, min(m.altezza, geo.size.height - 2 * m.bordo)))
                    .entrataScheda(Tema.Moto.Guida.entrata, scala: Tema.Moto.Guida.scala, ancora: .center)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var scheda: some View {
        let m = Tema.Misura.Guida.self
        return VStack(alignment: .leading, spacing: m.spazio) {
            testata
            Divider()
            contenuto
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(m.margine)
        .vetro(.pannello, forma: .arrotondata(Tema.Raggio.appAperte), riempimento: Tema.Colore.PannelliShell.coprente)
    }

    private var testata: some View {
        let m = Tema.Misura.Guida.self
        return HStack(spacing: m.spazioTestata) {
            LogoPrisma(colore: Tema.Colore.logo)
                .frame(height: m.logoPannello)
                .accessibilityHidden(true)
            Text("Guida di Prisma")
                .font(Tema.Testo.Guida.titoloPannello)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: m.spazio)
            ControlloSegmenti(opzioni: SchedaGuida.allCases.map { ($0, $0.nome) }, selezione: schedaScelta)
                .fixedSize()
            Spacer(minLength: m.spazio)
            // Un solo blu nel pannello: «Avanti / Comincia» (o «Apri…»); «Chiudi» è di vetro, con Esc
            Button { stato.chiudiGuida() } label: {
                Label("Chiudi", systemImage: "xmark")
            }
            .buttonStyle(StileVetro())
            .keyboardShortcut(.cancelAction)
        }
    }

    /// La scheda scelta nei segmenti, tradotta nella pagina della guida.
    private var schedaScelta: Binding<SchedaGuida> {
        let st = stato
        let si = sistema
        return Binding(
            get: { si.guida?.scheda ?? .comeFunziona },
            set: { nuova in
                guard nuova != si.guida?.scheda else { return }
                switch nuova {
                case .comeFunziona: st.guida = .introduzione(0)
                case .app: st.guida = .app(st.appAttiva ?? .clienti)
                case .parole: st.guida = .glossario(nil)
                }
            })
    }

    @ViewBuilder private var contenuto: some View {
        switch sistema.guida {
        case .some(.introduzione(let pagina)):
            IntroduzionePrisma(pagina: pagina)
        case .some(.app(let app)):
            GuidaApp(app: app)
        case .some(.glossario(let chiave)):
            GlossarioVista(chiave: chiave)
        case .none:
            Color.clear
        }
    }
}

// MARK: - Come funziona: l'introduzione in 5 pagine

struct IntroduzionePrisma: View {
    @EnvironmentObject var stato: StatoShell
    let pagina: Int

    private var pagine: [PaginaIntroduzione] { PaginaIntroduzione.pagine }
    private var indice: Int { min(max(0, pagina), pagine.count - 1) }
    private var ultima: Bool { indice == pagine.count - 1 }

    var body: some View {
        let m = Tema.Misura.Guida.self
        VStack(alignment: .leading, spacing: m.spazio) {
            ZStack(alignment: .topLeading) {
                // Dissolvenza breve fra le pagine, niente scorrimenti
                PaginaIntroduzioneVista(pagina: pagine[indice])
                    .id(indice)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            piede
        }
    }

    private var piede: some View {
        let m = Tema.Misura.Guida.self
        return ZStack {
            PuntiPagine(numero: pagine.count, attuale: indice)
            HStack(spacing: m.spazioPasso) {
                Button { stato.chiudiGuida() } label: {
                    Text("Salta l'introduzione").underline()
                }
                .buttonStyle(StileSemplice())
                .font(Tema.Testo.Guida.testoBlocco)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                Spacer(minLength: m.spazio)
                Button { vai(indice - 1) } label: {
                    Label("Indietro", systemImage: "chevron.left")
                }
                .buttonStyle(StileVetro(taglia: .grande))
                .disabled(indice == 0)
                Button { avanti() } label: {
                    if ultima {
                        Label("Comincia", systemImage: "checkmark")
                    } else {
                        Label("Avanti", systemImage: "chevron.right")
                    }
                }
                .buttonStyle(StileBlu(taglia: .grande))
                .keyboardShortcut(.defaultAction)
            }
        }
        // Le frecce ← → sfogliano le pagine: un pulsante tiene una sola scorciatoia, quindi due invisibili
        .background {
            Group {
                Button("") { vai(indice + 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("") { vai(indice - 1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    private func avanti() {
        guard ultima else { vai(indice + 1); return }
        // «Comincia»: la guida si chiude (introduzione vista) e si parte dai clienti
        let st = stato
        st.chiudiGuida()
        DispatchQueue.main.async { st.apriApp(.clienti) }
    }

    private func vai(_ nuova: Int) {
        guard nuova >= 0, nuova < pagine.count, nuova != indice else { return }
        withAnimation(Movimenti.curva(Tema.Moto.Guida.pagina)) { stato.guida = .introduzione(nuova) }
    }
}

/// Una pagina dell'introduzione: a sinistra le icone delle app di cui parla, a destra titolo, testo e punti.
private struct PaginaIntroduzioneVista: View {
    let pagina: PaginaIntroduzione

    var body: some View {
        let m = Tema.Misura.Guida.self
        HStack(alignment: .top, spacing: m.margine) {
            icone
                .frame(width: m.colonnaIcone)
            ScrollView {
                VStack(alignment: .leading, spacing: m.spazio) {
                    Text(pagina.titolo)
                        .font(Tema.Testo.Guida.titoloPagina)
                        .tracking(Tema.Testo.Guida.spaziaturaTitolo)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(LocalizedStringKey(pagina.testo))
                        .font(Tema.Testo.Guida.testoPagina)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .lineSpacing(Tema.Testo.Guida.interlinea)
                        .fixedSize(horizontal: false, vertical: true)
                    if pagina.conPercorso {
                        PercorsoTipico()
                            .padding(.vertical, m.spazioPunti)
                    }
                    VStack(alignment: .leading, spacing: m.spazioPunti) {
                        ForEach(Array(pagina.punti.enumerated()), id: \.offset) { _, punto in
                            HStack(alignment: .top, spacing: m.spazioPunti) {
                                Circle()
                                    .fill(Tema.Colore.Guida.pallinoPunto)
                                    .frame(width: m.pallinoPunto, height: m.pallinoPunto)
                                    .padding(.top, m.rientroPallino)
                                    .accessibilityHidden(true)
                                Text(punto)
                                    .font(Tema.Testo.Guida.puntoPagina)
                                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if pagina.conCanali {
                        HStack(spacing: m.canaliSpazio) {
                            EtichettaCanale(canale: .alleanza)
                            EtichettaCanale(canale: .indipendente)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Le icone due a due (il logo di Prisma se la pagina non parla di un'app).
    @ViewBuilder private var icone: some View {
        let m = Tema.Misura.Guida.self
        if pagina.app.isEmpty {
            LogoPrisma(colore: Tema.Colore.logo)
                .frame(height: m.logoIntro)
                .padding(.top, m.spazio)
                .accessibilityHidden(true)
        } else {
            let righe = stride(from: 0, to: pagina.app.count, by: 2).map { Array(pagina.app[$0..<min($0 + 2, pagina.app.count)]) }
            VStack(spacing: m.spazioIcone) {
                ForEach(Array(righe.enumerated()), id: \.offset) { _, riga in
                    HStack(spacing: m.spazioIcone) {
                        ForEach(riga) { app in
                            IconaApp(app: app, lato: m.iconaIntro)
                                .help(app.titolo)
                        }
                    }
                }
            }
            .padding(.top, m.spazioPunti)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Le app: «Come si usa» di ognuna

struct GuidaApp: View {
    @EnvironmentObject var stato: StatoShell
    let app: AppPrisma

    var body: some View {
        let m = Tema.Misura.Guida.self
        HStack(alignment: .top, spacing: m.spazio) {
            ScrollView {
                VStack(alignment: .leading, spacing: m.spazioElenco) {
                    ForEach(AppPrisma.allCases) { a in
                        riga(a)
                    }
                }
            }
            .frame(width: m.elencoApp)
            Divider()
            VStack(alignment: .leading, spacing: m.spazio) {
                ScrollView {
                    SchedaAiutoApp(app: app, nelPopover: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Spacer()
                    Button {
                        let st = stato
                        let scelta = app
                        st.chiudiGuida()
                        DispatchQueue.main.async { st.apriApp(scelta) }
                    } label: {
                        Label("Apri \(app.titolo)", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(StileBlu(taglia: .grande))
                    .disabled(!stato.appConsentita(app))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func riga(_ a: AppPrisma) -> some View {
        let m = Tema.Misura.Guida.self
        let scelta = a == app
        return Button { stato.guida = .app(a) } label: {
            HStack(spacing: m.spazioRigaElenco) {
                IconaApp(app: a, lato: m.iconaElencoApp)
                VStack(alignment: .leading, spacing: m.spazioTermine) {
                    Text(a.titolo)
                        .font(Tema.Testo.Guida.voceElenco)
                        .foregroundColor(Tema.Colore.inchiostro)
                    Text(a.aiuto.inBreve)
                        .font(Tema.Testo.Guida.breveElenco)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(m.rigaElenco)
            .background {
                RoundedRectangle(cornerRadius: Tema.Raggio.Guida.rigaElenco, style: .continuous)
                    .fill(scelta ? Tema.Colore.Guida.selezioneElenco : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
        .accessibilityAddTraits(scelta ? .isSelected : [])
    }
}

/// «A cosa serve / Come si usa in 3 passi / Le parole da sapere» di un'app: nel popover del pulsante
/// «Come si usa» e, più grande, nella scheda «Le app» della guida.
struct SchedaAiutoApp: View {
    @EnvironmentObject var stato: StatoShell
    let app: AppPrisma
    /// Nel popover: in fondo il collegamento «Tutta la guida di Prisma».
    let nelPopover: Bool
    /// Chiude il popover (nil fuori dal popover).
    var chiudi: (() -> Void)? = nil

    var body: some View {
        let m = Tema.Misura.Guida.self
        let aiuto = app.aiuto
        VStack(alignment: .leading, spacing: m.spazioBlocchi) {
            HStack(spacing: m.spazioRigaElenco) {
                IconaApp(app: app, lato: nelPopover ? m.iconaElencoApp : m.iconaPercorso)
                Text(app.titolo)
                    .font(nelPopover ? Tema.Testo.Guida.titoloApp : Tema.Testo.Guida.titoloPannello)
                    .foregroundColor(Tema.Colore.inchiostro)
            }
            blocco(1, "A cosa serve") {
                Text(aiuto.aCosaServe)
                    .font(Tema.Testo.Guida.aCosaServe)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineSpacing(Tema.Testo.Guida.interlinea / 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            blocco(2, "Come si usa in 3 passi") {
                VStack(alignment: .leading, spacing: m.spazioPasso) {
                    ForEach(Array(aiuto.passi.enumerated()), id: \.offset) { i, passo in
                        HStack(alignment: .top, spacing: m.spazioPasso) {
                            NumeroPasso(numero: i + 1)
                            Text(passo)
                                .font(Tema.Testo.Guida.testoBlocco)
                                .foregroundColor(Tema.Colore.inchiostro)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, m.spazioTermine)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Passo \(i + 1): \(passo)")
                    }
                }
            }
            if !aiuto.parole.isEmpty {
                blocco(3, "Le parole da sapere") {
                    ChipParole(chiavi: aiuto.parole) { chiave in
                        chiudi?()
                        stato.apriGuida(.glossario(chiave))
                    }
                }
            }
            if nelPopover {
                Button {
                    chiudi?()
                    stato.apriGuida(.app(app))
                } label: {
                    Label("Tutta la guida di Prisma", systemImage: "book")
                }
                .buttonStyle(StileCollegamento())
            }
        }
        .padding(nelPopover ? m.margineScheda : 0)
        .frame(width: nelPopover ? m.schedaApp : nil, alignment: .leading)
    }

    private func blocco<Contenuto: View>(_ numero: Int, _ titolo: String,
                                         @ViewBuilder _ contenuto: () -> Contenuto) -> some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Guida.spazioScheda) {
            Text(titolo.uppercased())
                .font(Tema.Testo.Guida.titoloBlocco)
                .tracking(Tema.Testo.Guida.spaziaturaBlocco)
                .foregroundColor(Tema.Colore.Guida.titoloBlocco)
                .accessibilityAddTraits(.isHeader)
            contenuto()
        }
    }
}

/// I chip delle parole del glossario: un clic apre la parola.
private struct ChipParole: View {
    let chiavi: [VoceGlossario.Chiave]
    let apri: (VoceGlossario.Chiave) -> Void

    var body: some View {
        let m = Tema.Misura.Guida.self
        // Al massimo 5 parole: due righe di chip bastano anche nel popover
        let righe = stride(from: 0, to: chiavi.count, by: 3).map { Array(chiavi[$0..<min($0 + 3, chiavi.count)]) }
        VStack(alignment: .leading, spacing: m.spazioChip) {
            ForEach(Array(righe.enumerated()), id: \.offset) { _, riga in
                HStack(spacing: m.spazioChip) {
                    ForEach(riga, id: \.self) { chiave in
                        if let v = Glossario.voce(chiave) {
                            Button { apri(chiave) } label: {
                                Text(v.termine)
                                    .font(Tema.Testo.Guida.chip)
                                    .foregroundColor(Tema.Colore.link)
                                    .lineLimit(1)
                                    .padding(m.chipMargine)
                                    .frame(minHeight: Tema.Misura.Componenti.areaClicMinima)
                                    .background { Capsule(style: .continuous).fill(Tema.Colore.Guida.fondoChip) }
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .strokeBorder(Tema.Colore.Guida.filoChip, lineWidth: Tema.Misura.filo)
                                    }
                                    .contentShape(Capsule(style: .continuous))
                            }
                            .buttonStyle(StileSemplice())
                            .help(v.breve)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Le parole: il glossario

struct GlossarioVista: View {
    @EnvironmentObject var stato: StatoShell
    /// La voce scelta (nil: la prima dell'elenco).
    let chiave: VoceGlossario.Chiave?
    @State private var testo = ""
    @State private var categoria: VoceGlossario.Categoria? = nil

    /// «Tutte» più le cinque categorie.
    private static let opzioni: [(VoceGlossario.Categoria?, String)] = {
        var elenco: [(VoceGlossario.Categoria?, String)] = [(nil, "Tutte")]
        for c in VoceGlossario.Categoria.allCases { elenco.append((c, c.nome)) }
        return elenco
    }()

    var body: some View {
        let m = Tema.Misura.Guida.self
        let trovate = Glossario.cerca(testo, categoria: categoria)
        // La voce chiesta, se la ricerca la tiene; altrimenti la prima trovata
        let scelta = trovate.first(where: { $0.chiave == chiave }) ?? trovate.first
        VStack(alignment: .leading, spacing: m.spazio) {
            TextField("Cerca una parola: SRI, riscatto, TFR…", text: $testo)
                .campoTesto()
            ViewThatFits(in: .horizontal) {
                ControlloSegmenti(opzioni: GlossarioVista.opzioni, selezione: $categoria)
                ControlloSegmenti(opzioni: GlossarioVista.opzioni, selezione: $categoria, compatto: true)
            }
            HStack(alignment: .top, spacing: m.spazio) {
                elenco(trovate, scelta: scelta?.chiave)
                    .frame(width: m.elencoParole)
                Divider()
                Group {
                    if let v = scelta {
                        ScrollView { dettaglio(v).frame(maxWidth: .infinity, alignment: .leading) }
                    } else {
                        Text("Nessuna parola trovata. Prova con una parte della parola, o chiedi a Eve.")
                            .font(Tema.Testo.Guida.testoBlocco)
                            .foregroundColor(Tema.Colore.inchiostroSecondario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func elenco(_ voci: [VoceGlossario], scelta: VoceGlossario.Chiave?) -> some View {
        let m = Tema.Misura.Guida.self
        return ScrollView {
            VStack(alignment: .leading, spacing: m.spazioElenco) {
                ForEach(voci) { v in
                    let attiva = v.chiave == scelta
                    Button { stato.guida = .glossario(v.chiave) } label: {
                        VStack(alignment: .leading, spacing: m.spazioTermine) {
                            Text(v.termine)
                                .font(Tema.Testo.Guida.voceElenco)
                                .foregroundColor(Tema.Colore.inchiostro)
                            Text(v.breve)
                                .font(Tema.Testo.Guida.breveElenco)
                                .foregroundColor(Tema.Colore.inchiostroSecondario)
                        }
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(m.rigaElenco)
                        .background {
                            RoundedRectangle(cornerRadius: Tema.Raggio.Guida.rigaElenco, style: .continuous)
                                .fill(attiva ? Tema.Colore.Guida.selezioneElenco : Color.clear)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(StileSemplice())
                    .accessibilityAddTraits(attiva ? .isSelected : [])
                }
            }
        }
    }

    private func dettaglio(_ v: VoceGlossario) -> some View {
        let m = Tema.Misura.Guida.self
        return VStack(alignment: .leading, spacing: m.spazioScheda) {
            VStack(alignment: .leading, spacing: m.spazioTermine) {
                Text(v.termine)
                    .font(Tema.Testo.Guida.termine)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .fixedSize(horizontal: false, vertical: true)
                if let esteso = v.perEsteso {
                    Text(esteso)
                        .font(Tema.Testo.Guida.perEsteso)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
            }
            Text(v.categoria.nome)
                .font(Tema.Testo.pill)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .padding(m.chipMargine)
                .background { Capsule(style: .continuous).fill(Tema.Colore.Guida.fondoChip) }
            Text(v.breve)
                .font(Tema.Testo.Guida.titoloApp)
                .foregroundColor(Tema.Colore.inchiostro)
                .fixedSize(horizontal: false, vertical: true)
            Text(v.spiegazione)
                .font(Tema.Testo.Guida.spiegazione)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineSpacing(Tema.Testo.Guida.interlinea)
                .fixedSize(horizontal: false, vertical: true)
            if let esempio = v.esempio {
                EsempioGuida(testo: esempio)
            }
            if !v.dove.isEmpty {
                Text("DOVE LO TROVI IN PRISMA")
                    .font(Tema.Testo.Guida.titoloBlocco)
                    .foregroundColor(Tema.Colore.Guida.titoloBlocco)
                    .padding(.top, m.spazioScheda)
                HStack(spacing: m.spazioChip) {
                    ForEach(v.dove) { a in
                        Button {
                            let st = stato
                            st.chiudiGuida()
                            DispatchQueue.main.async { st.apriApp(a) }
                        } label: {
                            Label(a.titolo, systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(StileVetro())
                        .disabled(!stato.appConsentita(a))
                        .help("Apri \(a.titolo)")
                    }
                }
            }
        }
    }
}

// MARK: - «Come si usa» nell'intestazione di ogni app

/// Il pulsante «Come si usa» dell'intestazione: apre la scheda dell'app in un popover. Nelle barre strette
/// (`\.pulsantiSoloIcona`) resta solo l'icona, con il suggerimento.
struct PulsanteComeSiUsa: View {
    @EnvironmentObject var stato: StatoShell
    let app: AppPrisma
    @State private var aperto = false

    var body: some View {
        Button { aperto.toggle() } label: {
            Label("Come si usa", systemImage: "questionmark.circle")
        }
        .buttonStyle(StileVetro())
        .help("A cosa serve \(app.titolo) e come si usa, in 3 passi")
        .accessibilityLabel("Come si usa \(app.titolo)")
        .popover(isPresented: $aperto, arrowEdge: .bottom) {
            SchedaAiutoApp(app: app, nelPopover: true, chiudi: { aperto = false })
                .environmentObject(stato)
        }
    }
}
