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
            let sopraDock = D.dalBassoTelefono + DisposizioneDockMobile.altezza(lato: lato)
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
            }
            Spacer(minLength: 0)
            ForEach(Canale.allCases.filter { c in posizioni.contains { $0.canale == c } }) { canale in
                EtichettaCanale(canale: canale, compatta: true)
            }
            Image(systemName: "chevron.right")
                .font(Tipo.Mobile.etichetta)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
        }
        .schedaTelefono()
    }
}

/// La scheda del cliente in sola lettura: recapiti, patrimonio, posizioni per canale, nota.
private struct SchedaClienteTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let clienteId: String

    var body: some View {
        let cliente = stato.clienti.first { $0.id == clienteId }
        let posizioni = stato.posizioni.filter { $0.clienteId == clienteId && $0.stato != .chiusa }
        let inEssere = posizioni.filter { $0.stato == .inEssere }
        let proposte = posizioni.filter { $0.stato == .proposta }
        FondoTelefono {
            if let cliente {
                HStack(spacing: M.spazioApertura) {
                    AvatarCliente(iniziali: cliente.iniziali, tinta: cliente.tinta.colori, lato: M.avatarScheda)
                    VStack(alignment: .leading, spacing: M.spazioTesto) {
                        Text(cliente.nome)
                            .font(Tipo.Mobile.titolo)
                            .foregroundColor(Tema.Colore.inchiostro)
                        if !cliente.tema.isEmpty {
                            Text(cliente.tema)
                                .font(Tipo.Mobile.rigaDettaglio)
                                .foregroundColor(Tema.Colore.inchiostroSecondario)
                        }
                        if let eta = cliente.eta {
                            Text(cliente.professione.isEmpty ? "\(eta) anni" : "\(eta) anni · \(cliente.professione)")
                                .font(Tipo.Mobile.rigaDettaglio)
                                .foregroundColor(Tema.Colore.inchiostroSecondario)
                        }
                    }
                }
                .schedaTelefono()

                VStack(alignment: .leading, spacing: M.spazioRiga) {
                    Text("Patrimonio in essere")
                        .font(Tipo.Mobile.etichetta)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                    Text(Formati.euro(inEssere.reduce(0) { $0 + $1.valore }))
                        .font(Tipo.Mobile.cifraGrande)
                        .foregroundColor(Tema.Colore.inchiostro)
                    ForEach(Canale.allCases) { canale in
                        let delCanale = inEssere.filter { $0.canale == canale }
                        if !delCanale.isEmpty {
                            HStack {
                                EtichettaCanale(canale: canale, compatta: true)
                                Spacer(minLength: M.spazioRiga)
                                Text(Formati.euro(delCanale.reduce(0) { $0 + $1.valore }))
                                    .font(Tipo.Mobile.rigaValore)
                                    .foregroundColor(Tema.Colore.inchiostro)
                            }
                        }
                    }
                    if !proposte.isEmpty {
                        DatoTelefono("In proposta", "\(proposte.count) · \(Formati.euro(proposte.reduce(0) { $0 + $1.valore }))")
                    }
                }
                .schedaTelefono()

                if !cliente.telefono.isEmpty || !cliente.email.isEmpty || !cliente.indirizzo.isEmpty {
                    VStack(alignment: .leading, spacing: M.spazioRiga) {
                        if !cliente.telefono.isEmpty { DatoTelefono("Telefono", cliente.telefono) }
                        if !cliente.email.isEmpty { DatoTelefono("Email", cliente.email) }
                        if !cliente.indirizzo.isEmpty { DatoTelefono("Indirizzo", cliente.indirizzo) }
                    }
                    .schedaTelefono()
                }

                SezioneTelefono(titolo: "Posizioni")
                if posizioni.isEmpty {
                    VuotoTelefono(testo: "Nessuna posizione in essere o in proposta.")
                }
                ForEach(posizioni) { posizione in
                    NavigationLink(value: DestinazioneTelefono.posizione(posizione.id)) {
                        RigaPosizioneTelefono(posizione: posizione, conCliente: false)
                    }
                    .buttonStyle(.plain)
                }

                if !cliente.nota.isEmpty {
                    SezioneTelefono(titolo: "Nota")
                    Text(cliente.nota)
                        .font(Tipo.Mobile.corpo)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .schedaTelefono()
                }
            } else {
                VuotoTelefono(testo: "Questo cliente non c'è più nell'archivio.")
            }
        }
        .navigationTitle(cliente?.nome ?? "Cliente")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Posizioni

private struct PosizioniTelefono: View {
    @EnvironmentObject var stato: StatoShell
    @State private var proposte = false

    var body: some View {
        let scelte = stato.posizioni.filter { $0.stato == (proposte ? .proposta : .inEssere) }
        FondoTelefono {
            Picker("Posizioni", selection: $proposte) {
                Text("In essere").tag(false)
                Text("In proposta").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, M.spazioTesto)
            if scelte.isEmpty {
                VuotoTelefono(testo: proposte ? "Nessuna proposta aperta." : "Nessuna posizione in essere.")
            }
            ForEach(Canale.allCases) { canale in
                let delCanale = scelte.filter { $0.canale == canale }.sorted { $0.valore > $1.valore }
                if !delCanale.isEmpty {
                    HStack {
                        EtichettaCanale(canale: canale)
                        Spacer(minLength: M.spazioRiga)
                        Text(Formati.euro(delCanale.reduce(0) { $0 + $1.valore }))
                            .font(Tipo.Mobile.rigaValore)
                            .foregroundColor(Tema.Colore.inchiostro)
                    }
                    .padding(.top, M.spazioRiga)
                    ForEach(delCanale) { posizione in
                        NavigationLink(value: DestinazioneTelefono.posizione(posizione.id)) {
                            RigaPosizioneTelefono(posizione: posizione, conCliente: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Posizioni")
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

private struct AgendaTelefono: View {
    @EnvironmentObject var stato: StatoShell

    /// Quanti giorni avanti mostra l'agenda dell'iPhone (oggi e le due settimane dopo).
    private static let giorniAvanti = 14

    var body: some View {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: Date())
        let limite = cal.date(byAdding: .day, value: Self.giorniAvanti, to: oggi) ?? oggi
        let prossimi = stato.appuntamenti
            .filter { $0.fine > oggi && $0.inizio < limite }
            .sorted { $0.inizio < $1.inizio }
        let giorni = Dictionary(grouping: prossimi) { cal.startOfDay(for: $0.inizio) }
        FondoTelefono {
            if prossimi.isEmpty {
                VuotoTelefono(testo: "Nessun appuntamento nelle prossime due settimane.")
            }
            ForEach(giorni.keys.sorted(), id: \.self) { giorno in
                SezioneTelefono(titolo: Formati.giornoRelativo(giorno))
                ForEach(giorni[giorno] ?? []) { appuntamento in
                    NavigationLink(value: DestinazioneTelefono.appuntamento(appuntamento.id)) {
                        RigaAppuntamentoTelefono(appuntamento: appuntamento)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Agenda")
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
            }
            Spacer(minLength: 0)
            if let canale = appuntamento.canale {
                EtichettaCanale(canale: canale, compatta: true)
            }
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
