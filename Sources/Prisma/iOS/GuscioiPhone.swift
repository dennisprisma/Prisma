#if os(iOS)
import SwiftUI

/// Il guscio dell'iPhone: la scrivania del tema a una colonna (`@media (max-width: 760px)` di
/// Design/tema-liquid-glass.html) con la barra in alto e il dock in basso; un'app alla volta in una finestra di
/// vetro fra la barra e il dock (deskRect del tema), che entra ed esce con il movimento del Mac. Sotto tutto l'acqua
/// animata di RadiceMobile. Si torna alla scrivania con l'icona Scrivania del dock, con il marchio o con la ✕.
struct GuscioiPhone: View {
    @EnvironmentObject var mobile: StatoMobile
    @EnvironmentObject var stato: StatoShell
    /// Sotto una finestra, a movimento d'apertura finito, la scrivania esce dalla gerarchia (memoria, vetri).
    @State private var scrivaniaTolta = false
    @State private var giroMovimento = 0

    private typealias D = Tema.Misura.Mobile.Dock

    var body: some View {
        // La safe area si legge da fuori: dentro una vista che la ignora i margini valgono zero
        GeometryReader { esterno in
        let sicuro = esterno.safeAreaInsets
        GeometryReader { geo in
            let misura = geo.size
            let sottoBarra = sicuro.top + Tema.Misura.Mobile.Barra.altezza
            let voci = DisposizioneDockMobile.app(.telefono, consentita: { stato.appConsentita($0) }).count + 2
            let lato = DisposizioneDockMobile.lato(elementi: voci, larghezza: misura.width, massimo: D.massimoTelefono)
            let sopraDock = D.dalBassoTelefono + DisposizioneDockMobile.altezza(lato: lato, stile: .telefono)
            ZStack(alignment: .topLeading) {
                // Sotto una finestra, a movimento finito, la scrivania esce dalla gerarchia: niente vetri da ricampionare.
                // Nelle istantanee (niente movimento) non c'è già più
                if mobile.appAperta == nil || (mobile.persistente && !scrivaniaTolta) {
                    ScrivaniaTelefono(alto: sottoBarra, basso: sopraDock + Tema.Misura.Mobile.Scrivania.sopraDock,
                                      inFondo: mobile.scrivaniaInFondo)
                        .frame(width: misura.width, height: misura.height)
                        .allowsHitTesting(mobile.appAperta == nil)
                        .accessibilityHidden(mobile.appAperta != nil)
                }

                if let app = mobile.appAperta {
                    FinestraMobile(app: app,
                                   cornice: Self.cornice(misura: misura, sottoBarra: sottoBarra, sopraDock: sopraDock),
                                   spazio: misura, raggio: Tema.Raggio.Mobile.finestraTelefono,
                                   origine: mobile.origineApertura, animata: mobile.persistente) {
                        AppTelefono(app: app)
                    }
                    .id(app)
                }

                BarraMobile(compatta: true, alto: sicuro.top)

                DockMobile(stile: .telefono, larghezza: misura.width)
                    .padding(.bottom, D.dalBassoTelefono)
                    .frame(width: misura.width, height: misura.height, alignment: .bottom)

                PannelliMobile(sistema: stato.sistema, sottoBarra: sottoBarra, misura: misura)
            }
            .frame(width: misura.width, height: misura.height, alignment: .topLeading)
            // Una volta, qui, sulla vista che ignora la safe area: le origini dei widget e del dock sono nel suo spazio
            .coordinateSpace(name: ShellView.spazioShell)
        }
        .ignoresSafeArea(.container)
        }
        .onChange(of: mobile.appAperta) { nuova in aggiornaScrivania(nuova) }
        .modifier(SceltaFileiPad())
        .modifier(EsportaBackupiPad())
    }

    /// La finestra fra la barra e il dock (deskRect del tema: x 8, y barra + 6, larghezza w − 16).
    static func cornice(misura: CGSize, sottoBarra: CGFloat, sopraDock: CGFloat) -> CGRect {
        let y = sottoBarra + Tema.Misura.Mobile.Finestra.sopra
        let basso = misura.height - sopraDock - Tema.Misura.Mobile.Finestra.sopraDock
        return CGRect(x: Tema.Misura.Mobile.Finestra.margine, y: y,
                      width: max(0, misura.width - 2 * Tema.Misura.Mobile.Finestra.margine),
                      height: max(0, basso - y))
    }

    /// La scrivania resta sotto la finestra che entra per la durata del movimento, poi si toglie; torna subito con
    /// la scrivania (la finestra esce sopra di lei). Passando da un'app all'altra resta tolta.
    private func aggiornaScrivania(_ app: AppPrisma?) {
        giroMovimento &+= 1
        guard app != nil else {
            scrivaniaTolta = false
            return
        }
        guard !scrivaniaTolta else { return }
        let giro = giroMovimento
        DispatchQueue.main.asyncAfter(deadline: .now() + Tema.Moto.Finestre.durataApertura) {
            if giroMovimento == giro && mobile.appAperta != nil { scrivaniaTolta = true }
        }
    }
}

/// L'app dell'iPhone dentro la finestra: la sua NavigationStack (Clienti, Posizioni e Agenda con i percorsi del giro 1;
/// Attività, Note, Documenti e Impostazioni in sola lettura), le altre col segnaposto. Sulla radice la ✕ della
/// finestra a sinistra, come i semafori del tema; il titolo piccolo (la finestra è bassa).
struct AppTelefono: View {
    @EnvironmentObject var mobile: StatoMobile
    let app: AppPrisma

    var body: some View {
        switch app {
        case .clienti:
            NavigationStack(path: $mobile.percorsoClienti) {
                ClientiTelefono().radiceFinestra(app).destinazioniTelefono()
            }
            .fondoNavigazioneTrasparente()
        case .posizioni:
            NavigationStack(path: $mobile.percorsoPosizioni) {
                PosizioniTelefono().radiceFinestra(app).destinazioniTelefono()
            }
            .fondoNavigazioneTrasparente()
        case .agenda:
            NavigationStack(path: $mobile.percorsoAgenda) {
                AgendaTelefono().radiceFinestra(app).destinazioniTelefono()
            }
            .fondoNavigazioneTrasparente()
        default:
            NavigationStack {
                contenuto.radiceFinestra(app)
            }
            .fondoNavigazioneTrasparente()
        }
    }

    @ViewBuilder private var contenuto: some View {
        switch app {
        case .attivita: AttivitaTelefono()
        case .note: NoteTelefono()
        case .documenti: DocumentiTelefono()
        case .impostazioni: ImpostazioniTelefono()
        case .eve: EveTelefono().navigationTitle(app.titolo)
        default:
            InArrivoMobile(app: app, titolo: "\(app.titolo) è sul Mac", testo: StatoShell.soloSulMacPerOra)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(app.titolo)
        }
    }
}

extension View {
    /// La radice di un'app nella finestra dell'iPhone: la ✕ a sinistra, il titolo piccolo, la barra senza fondo.
    func radiceFinestra(_ app: AppPrisma) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PulsanteChiudiFinestra(app: app)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// La NavigationStack dentro la finestra di vetro: senza fondo proprio (si vede il vetro della finestra).
    func fondoNavigazioneTrasparente() -> some View {
        modifier(FondoNavigazioneTrasparente())
    }
}

private struct FondoNavigazioneTrasparente: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.containerBackground(Color.clear, for: .navigation)
        } else {
            content
        }
    }
}

// MARK: - Mattoni comuni

private typealias M = Tema.Misura.Mobile

extension View {
    /// Le destinazioni dei tocchi negli elenchi dell'iPhone.
    func destinazioniTelefono() -> some View {
        navigationDestination(for: DestinazioneTelefono.self) { destinazione in
            switch destinazione {
            case .cliente(let id): SchedaClienteTelefono(clienteId: id)
            case .posizione(let id): DettaglioPosizioneTelefono(posizioneId: id)
            case .appuntamento(let id): DettaglioAppuntamentoTelefono(appuntamentoId: id)
            case .area(let a, let filtro):
                ElencoAreaTelefono(area: AreaPosizione(rawValue: a) ?? .investimento, filtro: FiltroPosizioniTelefono(chiave: filtro))
            }
        }
    }

    /// Una riga o una scheda in vetro sottile sopra l'acqua.
    func schedaTelefono() -> some View {
        padding(M.margineRiga)
            .frame(maxWidth: .infinity, minHeight: M.rigaMinima, alignment: .leading)
            .contentShape(Rectangle())
            .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Mobile.riga), ombra: false)
    }
}

/// Un elenco che scorre dentro la finestra di vetro (il vetro e l'acqua sotto li disegnano la finestra e RadiceMobile).
struct FondoTelefono<Contenuto: View>: View {
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: M.spazioSchede) {
                contenuto()
            }
            .padding(M.margine)
        }
    }
}

/// Titolo di una sezione degli elenchi (in maiuscolo, come le sezioni del Mac), sul vetro della finestra.
struct SezioneTelefono: View {
    let titolo: String

    var body: some View {
        Text(titolo.uppercased())
            .font(Tipo.Mobile.sezione)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .padding(.top, M.spazioRiga)
            .padding(.horizontal, M.spazioTesto)
    }
}

/// Elenco vuoto: una frase, nient'altro.
struct VuotoTelefono: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(Tipo.Mobile.corpo)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .schedaTelefono()
    }
}

/// «In essere» verde o «Proposta» arancio, come le pastiglie del Mac.
struct StatoPosizioneTelefono: View {
    let stato: StatoPosizione

    var body: some View {
        let proposta = stato == .proposta
        Text(stato.nome)
            .font(Tipo.Mobile.stato)
            .foregroundColor(proposta ? Tema.Colore.testoProposta : Tema.Colore.testoInEssere)
            .padding(.horizontal, M.spazioRiga * 0.6)
            .padding(.vertical, M.spazioTesto)
            .background(Capsule().fill(proposta ? Tema.Colore.fondoProposta : Tema.Colore.fondoInEssere))
            .fixedSize()
    }
}

/// Una riga etichetta–valore delle schede in sola lettura.
struct DatoTelefono: View {
    let etichetta: String
    let valore: String

    init(_ etichetta: String, _ valore: String) {
        self.etichetta = etichetta
        self.valore = valore
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: M.spazioRiga) {
            Text(etichetta)
                .font(Tipo.Mobile.rigaDettaglio)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
            Spacer(minLength: M.spazioRiga)
            Text(valore)
                .font(Tipo.Mobile.rigaDettaglio)
                .foregroundColor(Tema.Colore.inchiostro)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Clienti

private struct ClientiTelefono: View {
    @EnvironmentObject var stato: StatoShell
    @State private var cerca = ""

    var body: some View {
        let elenco = stato.clienti
            .filter { cerca.isEmpty || $0.nome.localizedCaseInsensitiveContains(cerca) }
            .sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending }
        FondoTelefono {
            if elenco.isEmpty {
                VuotoTelefono(testo: cerca.isEmpty ? "Nessun cliente: apri il backup del Mac dal centro di controllo." : "Nessun cliente con «\(cerca)».")
            }
            ForEach(elenco) { cliente in
                NavigationLink(value: DestinazioneTelefono.cliente(cliente.id)) {
                    RigaClienteTelefono(cliente: cliente)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Clienti")
        .searchable(text: $cerca, prompt: "Cerca un cliente")
    }
}

private struct RigaClienteTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let cliente: Cliente

    var body: some View {
        let posizioni = stato.posizioni.filter { $0.clienteId == cliente.id && $0.stato != .chiusa }
        let canali = Canale.allCases.filter { c in posizioni.contains { $0.canale == c } }
        // Il nome ha tutta la riga: i canali stanno sotto, mai al posto del nome (sul telefono c'è poco spazio)
        HStack(spacing: M.spazioRiga) {
            AvatarCliente(iniziali: cliente.iniziali, tinta: cliente.tinta.colori, lato: M.avatarElenco)
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                Text(cliente.nome)
                    .font(Tipo.Mobile.rigaNome)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineLimit(1)
                Text(cliente.tema.isEmpty ? "\(posizioni.count) posizioni" : cliente.tema)
                    .font(Tipo.Mobile.rigaDettaglio)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                if !canali.isEmpty {
                    HStack(spacing: M.spazioTesto * 2) {
                        ForEach(canali) { canale in EtichettaCanale(canale: canale, compatta: true) }
                    }
                    .padding(.top, M.spazioTesto)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(Tipo.Mobile.etichetta)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
        }
        .schedaTelefono()
    }
}

/// La scheda del cliente (Design/iphone.html, schermata 2): chi è e quanto vale in alto, quattro numeri, poi le
/// schede Sintesi, Posizioni, Agenda e Documenti (non una pagina infinita).
private struct SchedaClienteTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let clienteId: String
    @State private var scheda = Scheda.sintesi

    private enum Scheda: String, CaseIterable, Identifiable {
        case sintesi = "Sintesi", posizioni = "Posizioni", agenda = "Agenda", documenti = "Documenti"
        var id: String { rawValue }
    }

    var body: some View {
        let cliente = stato.clienti.first { $0.id == clienteId }
        FondoTelefono {
            if let cliente {
                testata(cliente)
                numeri(cliente)
                Picker("Sezione", selection: $scheda) {
                    ForEach(Scheda.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, M.spazioTesto)
                switch scheda {
                case .sintesi: sintesi(cliente)
                case .posizioni: posizioni
                case .agenda: agenda
                case .documenti: documenti
                }
            } else {
                VuotoTelefono(testo: "Questo cliente non c'è più nell'archivio.")
            }
        }
        .navigationTitle(cliente?.nome ?? "Cliente")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Avatar, nome, età e professione con il tema, i canali.
    private func testata(_ c: Cliente) -> some View {
        HStack(spacing: M.spazioApertura) {
            AvatarCliente(iniziali: c.iniziali, tinta: c.tinta.colori, lato: M.avatarScheda)
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                Text(c.nome)
                    .font(Tipo.Mobile.titoloGrande)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                let dettagli = [c.eta.map { "\($0) anni" }, c.professione.isEmpty ? nil : c.professione, c.tema.isEmpty ? nil : "«\(c.tema)»"]
                    .compactMap { $0 }
                if !dettagli.isEmpty {
                    Text(dettagli.joined(separator: " · "))
                        .font(Tipo.Mobile.rigaDettaglio)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: M.spazioTesto * 2) {
                    ForEach(c.canali) { EtichettaCanale(canale: $0, compatta: true) }
                }
                .padding(.top, M.spazioTesto)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, M.spazioTesto * 2)
    }

    /// Il patrimonio netto grande con la barra dei canali, poi quattro numeri su due colonne.
    private func numeri(_ c: Cliente) -> some View {
        let r = stato.riepilogoPosizioniCliente(c.id)
        let incontro = stato.prossimiAppuntamenti.first { $0.clienteId == c.id }
            .map { "\(Formati.giornoRelativo($0.inizio)) \(Formati.ora.string(from: $0.inizio))" } ?? "—"
        let aperte = stato.attivitaAperte.filter { $0.clienteId == c.id }.count
        return VStack(alignment: .leading, spacing: M.spazioRiga) {
            TotaleTelefono(titolo: "Patrimonio netto", totale: r.patrimonioNetto,
                           perCanale: Canale.allCases.compactMap { ch in r.perCanale[ch].map { (ch, $0) } })
            LazyVGrid(columns: [GridItem(.flexible(), spacing: M.spazioSchede), GridItem(.flexible())], spacing: M.spazioSchede) {
                numero("Prossimo incontro", incontro)
                numero("Da fare", "\(aperte) \(aperte == 1 ? "attività" : "attività")")
                numero("Premi all'anno", Formati.euro(r.premiAnnui), sotto: r.contrattiConPremi > 0 ? "\(r.contrattiConPremi) contratti" : nil)
                numero("Proposte aperte", r.proposteAperte == 0 ? "nessuna" : "\(r.proposteAperte)",
                       sotto: r.proposteAperte > 0 ? Formati.euro(r.valoreProposte) : nil)
            }
        }
    }

    private func numero(_ etichetta: String, _ valore: String, sotto: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: M.spazioTesto) {
            Text(etichetta).font(Tipo.Mobile.etichetta).foregroundColor(Tema.Colore.inchiostroSecondario)
            Text(valore).font(Tipo.Mobile.rigaValore).foregroundColor(Tema.Colore.inchiostro).lineLimit(1).minimumScaleFactor(0.8)
            if let sotto {
                Text(sotto).font(Tipo.Mobile.rigaDettaglio).foregroundColor(Tema.Colore.inchiostroSecondario).lineLimit(1)
            }
        }
        .schedaTelefono()
    }

    /// Sintesi: da fare (attività aperte e scadenze), obiettivi, recapiti, nota.
    @ViewBuilder private func sintesi(_ c: Cliente) -> some View {
        let attivita = stato.attivitaAperte.filter { $0.clienteId == c.id }.sorted { $0.scadenza < $1.scadenza }
        let scadenze = stato.riepilogoPosizioniCliente(c.id).inScadenza
        if !attivita.isEmpty || !scadenze.isEmpty {
            SezioneTelefono(titolo: "Da fare")
            ForEach(scadenze) { p in
                NavigationLink(value: DestinazioneTelefono.posizione(p.id)) {
                    HStack(spacing: M.spazioRiga) {
                        Image(systemName: "clock").foregroundColor(Tema.Colore.arancio)
                        VStack(alignment: .leading, spacing: M.spazioTesto) {
                            Text(p.nome).font(Tipo.Mobile.rigaNome).foregroundColor(Tema.Colore.inchiostro)
                            HStack(spacing: M.spazioTesto * 2) {
                                Text("Scade il \(Formati.dataBreve.string(from: p.scadenza ?? Date()))")
                                    .font(Tipo.Mobile.rigaDettaglio).foregroundColor(Tema.Colore.inchiostroSecondario)
                                EtichettaCanale(canale: p.canale, compatta: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .schedaTelefono()
                }
                .buttonStyle(.plain)
            }
            ForEach(attivita.prefix(5)) { a in
                HStack(spacing: M.spazioRiga) {
                    CasellaSpunta(spuntata: a.completata)
                    VStack(alignment: .leading, spacing: M.spazioTesto) {
                        Text(a.titolo).font(Tipo.Mobile.rigaNome).foregroundColor(Tema.Colore.inchiostro)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Formati.giornoRelativo(a.scadenza)).font(Tipo.Mobile.rigaDettaglio)
                            .foregroundColor(a.scadenza < Calendar.current.startOfDay(for: Date()) ? Tema.Colore.rosso : Tema.Colore.inchiostroSecondario)
                    }
                    Spacer(minLength: 0)
                }
                .schedaTelefono()
            }
        }
        let obiettivi = stato.obiettiviCliente(c.id)
        if !obiettivi.isEmpty {
            SezioneTelefono(titolo: "Obiettivi")
            ForEach(obiettivi) { o in
                HStack(spacing: M.spazioRiga) {
                    VStack(alignment: .leading, spacing: M.spazioTesto) {
                        Text(o.titolo).font(Tipo.Mobile.rigaNome).foregroundColor(Tema.Colore.inchiostro)
                        Text("\(Formati.dataBreve.string(from: o.scadenza)) · \(Formati.euro(o.importo))")
                            .font(Tipo.Mobile.rigaDettaglio).foregroundColor(Tema.Colore.inchiostroSecondario)
                    }
                    Spacer(minLength: M.spazioRiga)
                    if o.importo > 0 {
                        Text(Formati.percentuale((min(1, o.accantonato / o.importo) * 100).rounded()))
                            .font(Tipo.Mobile.rigaValore).foregroundColor(Tema.Colore.inchiostro)
                    }
                }
                .schedaTelefono()
            }
        }
        if !c.telefono.isEmpty || !c.email.isEmpty || !c.indirizzo.isEmpty {
            SezioneTelefono(titolo: "Recapiti")
            VStack(alignment: .leading, spacing: M.spazioRiga) {
                if !c.telefono.isEmpty { DatoTelefono("Telefono", c.telefono) }
                if !c.email.isEmpty { DatoTelefono("Email", c.email) }
                if !c.indirizzo.isEmpty { DatoTelefono("Indirizzo", c.indirizzo) }
            }
            .schedaTelefono()
        }
        if !c.nota.isEmpty {
            SezioneTelefono(titolo: "Nota")
            Text(c.nota).font(Tipo.Mobile.corpo).foregroundColor(Tema.Colore.inchiostro).schedaTelefono()
        }
    }

    @ViewBuilder private var posizioni: some View {
        let elenco = stato.posizioni.filter { $0.clienteId == clienteId && $0.stato != .chiusa }.sorted { $0.valore > $1.valore }
        if elenco.isEmpty { VuotoTelefono(testo: "Nessuna posizione in essere o in proposta.") }
        ForEach(elenco) { p in
            NavigationLink(value: DestinazioneTelefono.posizione(p.id)) { RigaPosizioneTelefono(posizione: p, conCliente: false) }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var agenda: some View {
        let elenco = stato.appuntamenti.filter { $0.clienteId == clienteId && $0.fine > Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.inizio < $1.inizio }
        if elenco.isEmpty { VuotoTelefono(testo: "Nessun appuntamento in programma.") }
        ForEach(elenco) { a in
            NavigationLink(value: DestinazioneTelefono.appuntamento(a.id)) { RigaAppuntamentoTelefono(appuntamento: a) }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var documenti: some View {
        let elenco = stato.documentiCliente(clienteId)
        if elenco.isEmpty { VuotoTelefono(testo: "Nessun documento.") }
        ForEach(elenco) { RigaDocumentoTelefono(documento: $0) }
    }
}

// MARK: - Posizioni

/// Posizioni sull'iPhone (Design/iphone.html, schermata 3): il filtro dei canali, il totale grande con la barra dei
/// canali, le aree con il loro importo, poi le posizioni più grandi. Il canale si sceglie con un tocco.
private struct PosizioniTelefono: View {
    @EnvironmentObject var stato: StatoShell
    @State private var filtro = FiltroPosizioniTelefono.tutte

    var body: some View {
        let scelte = filtro.applica(stato.posizioni)
        let totale = scelte.reduce(0) { $0 + $1.valore }
        FondoTelefono {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: M.spazioTesto * 3) {
                    ForEach(FiltroPosizioniTelefono.tutti(proposte: stato.posizioni.filter { $0.stato == .proposta }.count), id: \.0) { f, titolo in
                        Button { filtro = f } label: { GettoneFiltroTelefono(titolo: titolo, canale: f.canale, scelto: filtro == f) }
                            .buttonStyle(StileSemplice())
                    }
                }
            }
            TotaleTelefono(titolo: filtro == .proposte ? "In proposta" : "In essere", totale: totale,
                           perCanale: filtro.canale == nil ? Canale.allCases.map { c in (c, scelte.filter { $0.canale == c }.reduce(0) { $0 + $1.valore }) } : [])
            if scelte.isEmpty {
                VuotoTelefono(testo: filtro == .proposte ? "Nessuna proposta aperta." : "Nessuna posizione in essere.")
            } else {
                SezioneTelefono(titolo: "Per area")
                VStack(spacing: 0) {
                    let aree = AreaPosizione.allCases.compactMap { a -> (AreaPosizione, [Posizione])? in
                        let d = scelte.filter { $0.area == a }
                        return d.isEmpty ? nil : (a, d)
                    }.sorted { abs($0.1.reduce(0) { $0 + $1.valore }) > abs($1.1.reduce(0) { $0 + $1.valore }) }
                    ForEach(Array(aree.enumerated()), id: \.element.0) { i, voce in
                        NavigationLink(value: DestinazioneTelefono.area(voce.0.rawValue, filtro: filtro.chiave)) {
                            RigaAreaTelefono(area: voce.0, posizioni: voce.1)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo) }
                        }
                    }
                }
                .padding(.horizontal, M.margineRiga.leading)
                .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Mobile.riga), ombra: false)
                SezioneTelefono(titolo: "Le più grandi")
                ForEach(scelte.sorted { $0.valore > $1.valore }.prefix(5)) { posizione in
                    NavigationLink(value: DestinazioneTelefono.posizione(posizione.id)) {
                        RigaPosizioneTelefono(posizione: posizione, conCliente: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Posizioni")
    }
}

/// Il filtro delle posizioni: tutte in essere, un canale, oppure le proposte.
enum FiltroPosizioniTelefono: Hashable {
    case tutte, canale(Canale), proposte

    var canale: Canale? { if case .canale(let c) = self { return c } else { return nil } }

    func applica(_ elenco: [Posizione]) -> [Posizione] {
        switch self {
        case .tutte: return elenco.filter { $0.stato == .inEssere }
        case .canale(let c): return elenco.filter { $0.stato == .inEssere && $0.canale == c }
        case .proposte: return elenco.filter { $0.stato == .proposta }
        }
    }

    /// Per la destinazione di un'area: «tutte», «proposte» o il canale.
    var chiave: String {
        switch self {
        case .tutte: return "tutte"
        case .proposte: return "proposte"
        case .canale(let c): return c.rawValue
        }
    }

    init(chiave: String) {
        switch chiave {
        case "proposte": self = .proposte
        default: self = Canale(rawValue: chiave).map { .canale($0) } ?? .tutte
        }
    }

    static func tutti(proposte: Int) -> [(FiltroPosizioniTelefono, String)] {
        [(.tutte, "Tutte")] + Canale.allCases.map { (.canale($0), $0.nome) } + [(.proposte, "Proposte · \(proposte)")]
    }
}

/// Un gettone del filtro: pieno quando è scelto, con il puntino del canale.
private struct GettoneFiltroTelefono: View {
    let titolo: String
    let canale: Canale?
    let scelto: Bool

    var body: some View {
        HStack(spacing: M.spazioTesto * 2) {
            if let canale {
                Circle().fill(Tema.Colore.canale(canale)).frame(width: Tema.Misura.ScrivaniaTelefono.puntino, height: Tema.Misura.ScrivaniaTelefono.puntino)
            }
            Text(titolo)
        }
        .font(Tipo.Mobile.gettoneFiltro)
        .foregroundColor(scelto ? Tema.Colore.Componenti.testoSuColore : Tema.Colore.inchiostro)
        .padding(.horizontal, M.spazioRiga)
        .frame(height: Tema.Misura.Mobile.gettoneFiltro)
        .vetro(.chip, forma: .capsula, riempimento: scelto ? Tema.Colore.inchiostro : nil)
    }
}

/// Il numero principale: il totale grande, la barra dei canali e l'importo di ciascuno.
struct TotaleTelefono: View {
    let titolo: String
    let totale: Double
    /// Vuoto: niente barra (un solo canale scelto).
    let perCanale: [(Canale, Double)]

    var body: some View {
        let somma = max(perCanale.reduce(0) { $0 + max($1.1, 0) }, 1)
        VStack(alignment: .leading, spacing: M.spazioTesto * 2) {
            Text(titolo)
                .font(Tipo.Mobile.etichetta)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
            Text(Formati.euro(totale))
                .font(Tipo.Mobile.cifraPrincipale)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !perCanale.isEmpty {
                GeometryReader { g in
                    HStack(spacing: 0) {
                        ForEach(perCanale, id: \.0) { c, v in
                            Rectangle().fill(Tema.Colore.canale(c)).frame(width: g.size.width * CGFloat(max(v, 0) / somma))
                        }
                    }
                }
                .frame(height: Tema.Misura.Mobile.barraCanali)
                .clipShape(Capsule())
                .padding(.vertical, M.spazioTesto * 2)
                ForEach(perCanale, id: \.0) { c, v in
                    HStack {
                        EtichettaCanale(canale: c, compatta: true)
                        Spacer(minLength: M.spazioRiga)
                        Text(Formati.euro(v))
                            .font(Tipo.Mobile.rigaValore)
                            .foregroundColor(Tema.Colore.inchiostro)
                    }
                }
            }
        }
        .padding(M.margineRiga)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Mobile.scheda), ombra: false)
    }
}

/// Un'area: la striscia del suo colore, il nome, quante posizioni, l'importo.
private struct RigaAreaTelefono: View {
    let area: AreaPosizione
    let posizioni: [Posizione]

    var body: some View {
        HStack(spacing: M.spazioRiga) {
            Capsule().fill(Colori.Analisi.area(area)).frame(width: Tema.Misura.Mobile.striscia)
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                Text(area.nome).font(Tipo.Mobile.rigaNome).foregroundColor(Tema.Colore.inchiostro)
                Text("\(posizioni.count) \(posizioni.count == 1 ? "posizione" : "posizioni")")
                    .font(Tipo.Mobile.rigaDettaglio).foregroundColor(Tema.Colore.inchiostroSecondario)
            }
            Spacer(minLength: M.spazioRiga)
            Text(Formati.euro(posizioni.reduce(0) { $0 + $1.valore }))
                .font(Tipo.Mobile.rigaValore)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
                .fixedSize()
            Image(systemName: "chevron.right")
                .font(Tipo.Mobile.etichetta)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
        }
        .padding(.vertical, M.margineRiga.top)
        .frame(minHeight: M.rigaMinima)
        .contentShape(Rectangle())
    }
}

/// Le posizioni di un'area (dal riquadro «Per area»), con lo stesso filtro.
struct ElencoAreaTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let area: AreaPosizione
    let filtro: FiltroPosizioniTelefono

    var body: some View {
        let elenco = filtro.applica(stato.posizioni).filter { $0.area == area }.sorted { $0.valore > $1.valore }
        FondoTelefono {
            TotaleTelefono(titolo: area.nome, totale: elenco.reduce(0) { $0 + $1.valore },
                           perCanale: filtro.canale == nil ? Canale.allCases.map { c in (c, elenco.filter { $0.canale == c }.reduce(0) { $0 + $1.valore }) } : [])
            ForEach(elenco) { posizione in
                NavigationLink(value: DestinazioneTelefono.posizione(posizione.id)) {
                    RigaPosizioneTelefono(posizione: posizione, conCliente: true)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(area.nome)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RigaPosizioneTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let posizione: Posizione
    let conCliente: Bool

    var body: some View {
        HStack(spacing: M.spazioRiga) {
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                Text(posizione.nome)
                    .font(Tipo.Mobile.rigaNome)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineLimit(2)
                Text(dettaglio)
                    .font(Tipo.Mobile.rigaDettaglio)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                HStack(spacing: M.spazioTesto * 2) {
                    EtichettaCanale(canale: posizione.canale, compatta: true)
                    StatoPosizioneTelefono(stato: posizione.stato)
                }
            }
            Spacer(minLength: M.spazioRiga)
            Text(Formati.euro(posizione.valore))
                .font(Tipo.Mobile.rigaValore)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
                .fixedSize()
        }
        .schedaTelefono()
    }

    private var dettaglio: String {
        let cliente = conCliente ? stato.dati.clienti.first { $0.id == posizione.clienteId }?.nome : nil
        return [cliente, posizione.area.nome].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Il dettaglio della posizione: canale, prodotto, flussi, valori e costi (le cifre di Prisma, in sola lettura).
private struct DettaglioPosizioneTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let posizioneId: String

    var body: some View {
        let posizione = stato.posizioni.first { $0.id == posizioneId }
        FondoTelefono {
            if let p = posizione {
                VStack(alignment: .leading, spacing: M.spazioRiga) {
                    EtichettaCanale(canale: p.canale)
                    Text(p.nome)
                        .font(Tipo.Mobile.titolo)
                        .foregroundColor(Tema.Colore.inchiostro)
                    HStack(spacing: M.spazioTesto * 2) {
                        StatoPosizioneTelefono(stato: p.stato)
                        Text(p.area.nome)
                            .font(Tipo.Mobile.rigaDettaglio)
                            .foregroundColor(Tema.Colore.inchiostroSecondario)
                    }
                    Text(Formati.euro(p.valore))
                        .font(Tipo.Mobile.cifraGrande)
                        .foregroundColor(Tema.Colore.inchiostro)
                }
                .schedaTelefono()

                SezioneTelefono(titolo: "Prodotto")
                VStack(alignment: .leading, spacing: M.spazioRiga) {
                    if let cliente = stato.dati.clienti.first(where: { $0.id == p.clienteId }) {
                        DatoTelefono("Cliente", cliente.nome)
                    }
                    if !p.tipologia.isEmpty { DatoTelefono("Tipologia", p.tipologia) }
                    if !p.emittente.isEmpty { DatoTelefono("Emittente", p.emittente) }
                    if !p.numeroContratto.isEmpty { DatoTelefono("Contratto", p.numeroContratto) }
                    if let d = p.decorrenza { DatoTelefono("Decorrenza", Formati.dataBreve.string(from: d)) }
                    if let d = p.scadenza { DatoTelefono("Scadenza", Formati.dataBreve.string(from: d)) }
                }
                .schedaTelefono()

                SezioneTelefono(titolo: "Flussi e valori")
                VStack(alignment: .leading, spacing: M.spazioRiga) {
                    if p.versamentoIniziale > 0 { DatoTelefono("Versamento iniziale", Formati.euro(p.versamentoIniziale)) }
                    if p.premio > 0 { DatoTelefono("Premio (\(p.frequenza.nome.lowercased()))", Formati.euro(p.premio)) }
                    if let v = p.totaleVersato { DatoTelefono("Totale versato", Formati.euro(v)) }
                    if let v = p.controvalore { DatoTelefono("Controvalore", Formati.euro(v)) }
                    if let d = p.dataValore { DatoTelefono("Valore al", Formati.dataBreve.string(from: d)) }
                    if let v = p.capitaleAssicurato { DatoTelefono("Capitale assicurato", Formati.euro(v)) }
                    DatoTelefono("Valore nei riepiloghi", Formati.euro(p.valore))
                }
                .schedaTelefono()

                if p.rendimentoAtteso != nil || p.costoIngresso != nil || p.costoAnnuo != nil || p.sri != nil {
                    SezioneTelefono(titolo: "Ipotesi e costi")
                    VStack(alignment: .leading, spacing: M.spazioRiga) {
                        if let v = p.rendimentoAtteso { DatoTelefono("Rendimento lordo atteso", Formati.percentuale(v)) }
                        if let v = p.costoIngresso { DatoTelefono("Costo d'ingresso", Formati.percentuale(v)) }
                        if let v = p.costoAnnuo { DatoTelefono("Costo annuo", Formati.percentuale(v)) }
                        if let v = p.sri { DatoTelefono("Rischio (SRI)", "\(v) su 7") }
                    }
                    .schedaTelefono()
                }
            } else {
                VuotoTelefono(testo: "Questa posizione non c'è più nell'archivio.")
            }
        }
        .navigationTitle(posizione?.nome ?? "Posizione")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Agenda

/// L'agenda dell'iPhone (Design/iphone.html, schermata 4): il mese intero con un puntino blu per gli appuntamenti
/// e uno arancio per le cose da fare; sotto, il giorno scelto con i suoi appuntamenti e le sue attività.
private struct AgendaTelefono: View {
    @EnvironmentObject var stato: StatoShell
    @State private var mese = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var giorno = Calendar.current.startOfDay(for: Date())

    var body: some View {
        let cal = Calendar.current
        let delGiorno = stato.appuntamenti.filter { cal.isDate($0.inizio, inSameDayAs: giorno) }.sorted { $0.inizio < $1.inizio }
        let daFare = stato.attivitaAperte.filter { cal.isDate($0.scadenza, inSameDayAs: giorno) }
        FondoTelefono {
            MeseTelefono(mese: $mese, giorno: $giorno,
                         conAppuntamenti: Set(stato.appuntamenti.map { cal.startOfDay(for: $0.inizio) }),
                         conAttivita: Set(stato.attivitaAperte.map { cal.startOfDay(for: $0.scadenza) }))
            SezioneTelefono(titolo: Formati.dataLunga.string(from: giorno) + " · appuntamenti")
            if delGiorno.isEmpty {
                VuotoTelefono(testo: "Nessun appuntamento.")
            }
            ForEach(delGiorno) { appuntamento in
                NavigationLink(value: DestinazioneTelefono.appuntamento(appuntamento.id)) {
                    RigaAppuntamentoTelefono(appuntamento: appuntamento)
                }
                .buttonStyle(.plain)
            }
            if !daFare.isEmpty {
                SezioneTelefono(titolo: "Da fare")
                ForEach(daFare) { a in
                    HStack(spacing: M.spazioRiga) {
                        CasellaSpunta(spuntata: a.completata)
                        VStack(alignment: .leading, spacing: M.spazioTesto) {
                            Text(a.titolo)
                                .font(Tipo.Mobile.rigaNome)
                                .foregroundColor(Tema.Colore.inchiostro)
                                .fixedSize(horizontal: false, vertical: true)
                            if let c = stato.cliente(a.clienteId) {
                                Text(c.nome).font(Tipo.Mobile.rigaDettaglio).foregroundColor(Tema.Colore.inchiostroSecondario)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .schedaTelefono()
                }
            }
        }
        .navigationTitle("Agenda")
    }
}

/// Il mese: le frecce, i giorni della settimana, i giorni con i loro puntini; il giorno scelto pieno dell'accento,
/// oggi in rosso. Un tocco sceglie il giorno.
private struct MeseTelefono: View {
    @Binding var mese: Date
    @Binding var giorno: Date
    let conAppuntamenti: Set<Date>
    let conAttivita: Set<Date>

    private typealias A = Tema.Misura.AgendaTelefono

    var body: some View {
        let giorni = Self.griglia(mese)
        VStack(spacing: A.spazio) {
            HStack {
                Button { cambia(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(StileVetro())
                    .accessibilityLabel("Mese prima")
                Spacer()
                Text(Formati.meseAnno.string(from: mese).prefix(1).uppercased() + Formati.meseAnno.string(from: mese).dropFirst())
                    .font(Tipo.Mobile.titoloMese)
                    .foregroundColor(Tema.Colore.inchiostro)
                Spacer()
                Button { cambia(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(StileVetro())
                    .accessibilityLabel("Mese dopo")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: A.spazioRighe) {
                ForEach(Array(Self.iniziali.enumerated()), id: \.offset) { _, s in
                    Text(s).font(Tipo.Mobile.giornoSettimana).foregroundColor(Tema.Colore.inchiostroTerziario)
                }
                ForEach(giorni, id: \.self) { d in cella(d) }
            }
            HStack(spacing: A.spazio * 2) {
                HStack(spacing: A.spazioPuntini * 2) { punto(Tema.Colore.accento); Text("Appuntamenti") }
                HStack(spacing: A.spazioPuntini * 2) { punto(Tema.Colore.arancio); Text("Da fare") }
            }
            .font(Tipo.Mobile.rigaDettaglio)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
        }
        .padding(M.margineRiga)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Mobile.scheda), ombra: false)
    }

    private func punto(_ c: Color) -> some View {
        Circle().fill(c).frame(width: A.puntino, height: A.puntino)
    }

    /// Un giorno: il numero (rosso oggi, bianco su accento se scelto, chiaro fuori dal mese) e i suoi puntini.
    private func cella(_ d: Date) -> some View {
        let cal = Calendar.current
        let fuori = !cal.isDate(d, equalTo: mese, toGranularity: .month)
        let scelto = cal.isDate(d, inSameDayAs: giorno)
        let oggi = cal.isDateInToday(d)
        let suColore = Tema.Colore.Componenti.testoSuColore
        let coloreNumero: Color = scelto ? suColore : oggi ? Tema.Colore.rosso : fuori ? Tema.Colore.inchiostroTerziario : Tema.Colore.inchiostro
        return Button {
            giorno = d
            if fuori { mese = cal.dateInterval(of: .month, for: d)?.start ?? mese }
        } label: {
            VStack(spacing: A.spazioPuntini) {
                Text("\(cal.component(.day, from: d))")
                    .font(scelto || oggi ? Tipo.Mobile.giornoForte : Tipo.Mobile.giorno)
                    .foregroundColor(coloreNumero)
                HStack(spacing: A.spazioPuntini) {
                    if conAppuntamenti.contains(d) { punto(scelto ? suColore : Tema.Colore.accento) }
                    if conAttivita.contains(d) { punto(scelto ? suColore : Tema.Colore.arancio) }
                }
                .frame(height: A.puntino)
            }
            .frame(maxWidth: .infinity, minHeight: A.cella)
            .background {
                if scelto { RoundedRectangle(cornerRadius: A.raggio, style: .continuous).fill(Tema.Colore.accento) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }

    private func cambia(_ n: Int) {
        mese = Calendar.current.date(byAdding: .month, value: n, to: mese) ?? mese
    }

    /// L'iniziale dei giorni da lunedì.
    static let iniziali = ["L", "M", "M", "G", "V", "S", "D"]

    /// I giorni da mostrare: le settimane intere (da lunedì) che contengono il mese.
    static func griglia(_ mese: Date) -> [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        guard let intervallo = cal.dateInterval(of: .month, for: mese) else { return [] }
        let primo = intervallo.start
        let spostamento = (cal.component(.weekday, from: primo) - cal.firstWeekday + 7) % 7
        let inizio = cal.date(byAdding: .day, value: -spostamento, to: primo) ?? primo
        let giorniMese = cal.range(of: .day, in: .month, for: mese)?.count ?? 30
        let celle = Int(ceil(Double(spostamento + giorniMese) / 7)) * 7
        return (0..<celle).compactMap { cal.date(byAdding: .day, value: $0, to: inizio) }.map { cal.startOfDay(for: $0) }
    }
}

private struct RigaAppuntamentoTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let appuntamento: Appuntamento

    var body: some View {
        HStack(spacing: M.spazioRiga) {
            VStack(alignment: .trailing, spacing: M.spazioTesto) {
                Text(Formati.ora.string(from: appuntamento.inizio))
                    .font(Tipo.Mobile.rigaValore)
                    .foregroundColor(Tema.Colore.inchiostro)
                Text("\(appuntamento.durataMinuti) min")
                    .font(Tipo.Mobile.rigaDettaglio)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
            }
            .fixedSize()
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                Text(appuntamento.titolo)
                    .font(Tipo.Mobile.rigaNome)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineLimit(2)
                Text(dettaglio)
                    .font(Tipo.Mobile.rigaDettaglio)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                // Il canale sotto, non accanto: titolo e cliente restano interi
                if let canale = appuntamento.canale {
                    EtichettaCanale(canale: canale, compatta: true)
                        .padding(.top, M.spazioTesto)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .schedaTelefono()
        .opacity(appuntamento.stato == .concluso ? 0.6 : 1)
    }

    private var dettaglio: String {
        let cliente = stato.dati.clienti.first { $0.id == appuntamento.clienteId }?.nome
        return [cliente, appuntamento.luogo.isEmpty ? nil : appuntamento.luogo].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct DettaglioAppuntamentoTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let appuntamentoId: String

    var body: some View {
        let appuntamento = stato.appuntamenti.first { $0.id == appuntamentoId }
        FondoTelefono {
            if let a = appuntamento {
                VStack(alignment: .leading, spacing: M.spazioRiga) {
                    HStack(alignment: .top, spacing: M.spazioRiga) {
                        PiastrellaData(data: a.inizio)
                        VStack(alignment: .leading, spacing: M.spazioTesto) {
                            Text(a.titolo)
                                .font(Tipo.Mobile.titolo)
                                .foregroundColor(Tema.Colore.inchiostro)
                            Text("\(Formati.dataLunga.string(from: a.inizio)) · \(Formati.ora.string(from: a.inizio))–\(Formati.ora.string(from: a.fine))")
                                .font(Tipo.Mobile.rigaDettaglio)
                                .foregroundColor(Tema.Colore.inchiostroSecondario)
                        }
                    }
                    if let canale = a.canale { EtichettaCanale(canale: canale) }
                }
                .schedaTelefono()
                VStack(alignment: .leading, spacing: M.spazioRiga) {
                    if let cliente = stato.dati.clienti.first(where: { $0.id == a.clienteId }) {
                        DatoTelefono("Cliente", cliente.nome)
                    }
                    DatoTelefono("Tipo", a.tipo.nome)
                    if !a.luogo.isEmpty { DatoTelefono("Luogo", a.luogo) }
                    DatoTelefono("Stato", a.stato == .concluso ? "Concluso" : "Pianificato")
                    if let id = a.posizioneId, let p = stato.posizioni.first(where: { $0.id == id }) {
                        DatoTelefono("Posizione", p.nome)
                    }
                }
                .schedaTelefono()
                if !a.note.isEmpty {
                    SezioneTelefono(titolo: "Note")
                    Text(a.note)
                        .font(Tipo.Mobile.corpo)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .schedaTelefono()
                }
            } else {
                VuotoTelefono(testo: "Questo appuntamento non c'è più nell'archivio.")
            }
        }
        .navigationTitle("Appuntamento")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
