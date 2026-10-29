import AppKit
import SwiftUI

// Il pannello ⌘K come Spotlight del Mac: in alto al centro, sopra tutto, non una finestra. Campo grande con la
// lente; risultati raggruppati (Clienti, Posizioni, Appuntamenti, Documenti, Note, Azioni…) a sinistra e la
// colonna di anteprima a destra con le cifre principali e le azioni rapide. ↑ ↓ scelgono, Invio apre, Tab completa
// un filtro, Esc o un clic fuori chiudono, ⌘K apre e chiude. Lo apre `StatoShell.cercaOvunque()`; l'aperto/chiuso
// sta in `StatoFinestre.pannelloRicerca`, così la shell non si ridisegna mentre si scrive.

// MARK: - Stato del pannello

/// Testo, risultati e scelta del pannello. Vive finché il pannello è aperto: scrivere ridisegna solo il pannello.
final class StatoSpotlight: ObservableObject {
    @Published var testo = ""
    @Published private(set) var esito = EsitoRicerca.vuoto
    @Published private(set) var suggerimenti: [SuggerimentoFiltro] = []
    @Published var selezione = 0
    /// Il nome della ricerca da salvare, mentre lo si scrive (nil = non si sta salvando).
    @Published var nomeDaSalvare: String?
    /// I risultati in fila (l'ordine delle frecce) e il posto di ognuno.
    private(set) var elenco: [RisultatoRicerca] = []
    private(set) var indici: [ChiaveRisultato: Int] = [:]

    var scelto: RisultatoRicerca? { elenco.indices.contains(selezione) ? elenco[selezione] : nil }
    var vuoto: Bool { testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func aggiorna(_ stato: StatoShell) {
        let e = MotoreRicerca.cercaCompleta(testo, in: stato)
        elenco = e.elenco
        var posti: [ChiaveRisultato: Int] = [:]
        for (i, r) in elenco.enumerated() { posti[r.id] = i }
        indici = posti
        esito = e
        suggerimenti = FiltriRicerca.suggerimenti(per: testo)
        selezione = 0
    }

    func sposta(_ passo: Int) {
        guard !elenco.isEmpty else { return }
        selezione = min(max(selezione + passo, 0), elenco.count - 1)
    }

    func completa(con s: SuggerimentoFiltro) {
        testo = FiltriRicerca.completa(testo, con: s)
    }

    /// Il nome proposto per salvare la ricerca: i filtri e le parole («Scade nel 2027 · Alleanza · polizza»).
    var nomeProposto: String {
        let r = FiltriRicerca.interpreta(testo)
        let pezzi = r.filtri.map(\.descrizione) + (r.parole.isEmpty ? [] : [r.testoLibero])
        return pezzi.isEmpty ? testo.trimmingCharacters(in: .whitespacesAndNewlines) : pezzi.joined(separator: " · ")
    }
}

/// I tasti del pannello: il monitor di AppKit decide subito quali tenere per sé, la vista li esegue
/// sul thread principale (come `FrecceRicerca`).
final class TastiSpotlight: @unchecked Sendable {
    enum Tasto { case su, giu, invio, esc, tab }

    /// Il pannello è davanti (nessun modulo aperto sopra di lui).
    var attivo = false
    var conRisultati = false
    var conSuggerimenti = false
    /// Si scrive il nome della ricerca da salvare: Invio e frecce vanno a quel campo, Esc annulla.
    var inNome = false
    var esegui: (@MainActor (Tasto) -> Void)?

    func gestisci(_ evento: NSEvent) -> Bool {
        // Con un modulo aperto sopra il pannello (`attivo` falso) i tasti restano al modulo
        guard attivo else { return false }
        // Le scorciatoie con ⌘, ⌃ o ⌥ restano ai menu (⌘K chiude dal menu Vai)
        guard evento.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        let tasto: Tasto?
        switch evento.keyCode {
        case 53: tasto = .esc
        case 125: tasto = inNome || !conRisultati ? nil : .giu
        case 126: tasto = inNome || !conRisultati ? nil : .su
        case 36, 76: tasto = inNome || !conRisultati ? nil : .invio
        case 48: tasto = inNome || !conSuggerimenti ? nil : .tab
        default: tasto = nil
        }
        guard let tasto else { return false }
        let esegui = esegui
        Task { @MainActor in esegui?(tasto) }
        return true
    }
}

// MARK: - Pannello

struct RicercaSpotlight: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var sistema: StatoFinestre
    @Environment(\.modoIstantanea) private var modoIstantanea
    @StateObject private var motore = StatoSpotlight()
    @FocusState private var fuoco: Bool
    @FocusState private var fuocoNome: Bool
    @State private var tasti = TastiSpotlight()
    @State private var monitor: Any?
    @State private var moduloAppuntamento: Appuntamento?
    @State private var moduloAttivita: Attivita?
    /// Salvato il modulo, il pannello si chiude (annullato, resta aperto).
    @State private var chiudiDopoModulo = false

    private typealias M = Misure.Spotlight

    var body: some View {
        GeometryReader { geo in
            let larghezza = max(0, min(M.larghezza, geo.size.width - 2 * M.margineLato))
            let alto = max(M.distanzaAltoMinima, geo.size.height * M.distanzaAltoQuota)
            // Quanto possono crescere i risultati: il pannello resta entro il 70% della shell
            let disponibile = max(M.nessunRisultato, geo.size.height * M.altezzaQuota - M.campoAltezza - 2 * M.cornice - M.riservaStrisciaPie)
            ZStack(alignment: .top) {
                Colori.Spotlight.velo
                    .contentShape(Rectangle())
                    .onTapGesture { chiudi() }
                pannello(disponibile: disponibile)
                    .frame(width: larghezza)
                    .entrataScheda(Tema.Moto.Spotlight.entrata, scala: Tema.Moto.Spotlight.scala, ancora: .top,
                                   y: Tema.Moto.Spotlight.spostamento)
                    .padding(.top, alto)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .onAppear {
            if motore.testo != stato.testoRicerca { motore.testo = stato.testoRicerca }
            motore.aggiorna(stato)
            installaTasti()
            aggiornaTasti()
            fuoco = true
            // Su macOS 13 il primo fuoco può arrivare prima che il campo sia nella finestra
            DispatchQueue.main.async { fuoco = true }
        }
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            tasti.attivo = false
            tasti.esegui = nil
            if stato.testoRicerca != motore.testo { stato.testoRicerca = motore.testo }
        }
        .onChange(of: motore.testo) { _ in
            motore.aggiorna(stato)
            aggiornaTasti()
        }
        .onChange(of: motore.nomeDaSalvare != nil) { inNome in
            aggiornaTasti()
            if inNome { fuocoNome = true } else { fuoco = true }
        }
        .onChange(of: moduloAppuntamento != nil) { _ in aggiornaTasti() }
        .onChange(of: moduloAttivita != nil) { _ in aggiornaTasti() }
        .onChange(of: stato.richiestaFuocoRicerca) { _ in fuoco = true }
        // Blocco, modalità cliente e presentazione chiudono il pannello
        .onChange(of: sistema.bloccato) { if $0 { chiudi() } }
        .onChange(of: stato.inModoCliente) { if $0 { chiudi() } }
        .onChange(of: stato.presentazione != nil) { if $0 { chiudi() } }
        // Un pannello alla volta: aprendone un altro (dal menu) questo si chiude
        .onChange(of: sistema.pannelloSpazi) { if $0 { chiudi() } }
        .onChange(of: sistema.pannelloAppAperte) { if $0 { chiudi() } }
        .onChange(of: sistema.pannelloNotifiche) { if $0 { chiudi() } }
        .sheet(item: $moduloAppuntamento, onDismiss: chiudiSeSalvato) { a in
            ModuloAppuntamento(bozza: a, nuovo: true, salva: { nuovo in
                stato.salvaAppuntamento(nuovo)
                stato.mostraAvviso("Appuntamento fissato con \(stato.cliente(nuovo.clienteId)?.nome ?? "il cliente"): \(Formati.dataOra.string(from: nuovo.inizio)).")
                chiudiDopoModulo = true
            }, elimina: {})
            .environmentObject(stato)
        }
        .sheet(item: $moduloAttivita, onDismiss: chiudiSeSalvato) { t in
            ModuloAttivita(bozza: t, nuova: true, salva: { nuova in
                stato.salvaAttivita(nuova)
                stato.mostraAvviso("Attività segnata: «\(nuova.titolo)».")
                chiudiDopoModulo = true
            }, elimina: {})
            .environmentObject(stato)
        }
    }

    // MARK: Struttura

    private func pannello(disponibile: CGFloat) -> some View {
        VStack(spacing: 0) {
            campo
            striscia
            corpo(disponibile: disponibile)
            pie
                .bordoAlto(Colori.Spotlight.separatore)
        }
        .padding(M.cornice)
        .vetro(.pannello, forma: .arrotondata(M.raggio), riempimento: Colori.Spotlight.fondo)
    }

    /// Il campo grande con la lente (.spot-in).
    private var campo: some View {
        HStack(spacing: M.campoSpazio) {
            Image(systemName: "magnifyingglass")
                .font(Tipo.spotlightLente)
                .foregroundColor(Colori.Spotlight.lente)
            TextField("Clienti, posizioni, app… o un filtro come scade:2027", text: $motore.testo)
                .textFieldStyle(.plain)
                .font(Tipo.spotlightCampo)
                .foregroundColor(Colori.Spotlight.testo)
                .focused($fuoco)
                // Senza il monitor dei tasti (istantanee) Invio apre lo stesso
                .onSubmit { apriScelto() }
            if !motore.testo.isEmpty {
                Button { motore.testo = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Colori.Spotlight.cancella)
                }
                .buttonStyle(StileSemplice())
                .help("Cancella la ricerca")
            }
        }
        .padding(.horizontal, M.campoMargine)
        .frame(height: M.campoAltezza)
    }

    /// Sotto il campo: i suggerimenti mentre si scrive un filtro, oppure i filtri riconosciuti e i totali per canale.
    @ViewBuilder private var striscia: some View {
        let e = motore.esito
        if !motore.suggerimenti.isEmpty {
            DisposizioneAcapoRicerca(spazio: M.pillolaSpazio) {
                ForEach(motore.suggerimenti) { s in
                    Button {
                        motore.completa(con: s)
                        fuoco = true
                    } label: {
                        PillolaSpotlight(testo: s.testo, nota: s.descrizione)
                    }
                    .buttonStyle(StileSemplice())
                    .help("Tab per completare")
                }
            }
            .padding(M.strisciaMargine)
        } else if e.interpretata.conFiltri || !e.interpretata.incompleti.isEmpty {
            HStack(alignment: .top, spacing: M.pillolaSpazio) {
                DisposizioneAcapoRicerca(spazio: M.pillolaSpazio) {
                    ForEach(e.interpretata.filtri, id: \.self) { f in
                        PillolaSpotlight(testo: f.descrizione, tono: .filtro)
                    }
                    ForEach(e.interpretata.incompleti, id: \.self) { x in
                        PillolaSpotlight(testo: x, nota: "da completare", tono: .incompleto)
                    }
                }
                ForEach(e.totali) { t in TotaleCanaleSpotlight(totale: t) }
            }
            .padding(M.strisciaMargine)
        }
    }

    @ViewBuilder private func corpo(disponibile: CGFloat) -> some View {
        if motore.vuoto {
            vuoto
                .bordoAlto(Colori.Spotlight.separatore)
        } else if !motore.elenco.isEmpty {
            HStack(spacing: 0) {
                elencoRisultati
                    .frame(width: M.colonnaElenco)
                Rectangle()
                    .fill(Colori.Spotlight.separatore)
                    .frame(width: Tema.Misura.filo)
                anteprima
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: altezzaRisultati(disponibile: disponibile))
            .bordoAlto(Colori.Spotlight.separatore)
        } else if motore.suggerimenti.isEmpty {
            Text(motore.esito.interpretata.incompleti.isEmpty
                 ? "Nessun risultato. Prova con meno parole o con una parte del nome."
                 : "Completa il filtro: per esempio scade:2027, sri>4, canale:alleanza, stato:proposta.")
                .font(Tipo.spotlightMessaggio)
                .foregroundColor(Colori.Spotlight.messaggio)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(M.messaggioMargine)
                .bordoAlto(Colori.Spotlight.separatore)
        }
    }

    /// Cresce con i risultati: gruppi e righe stimati, tra il minimo (per l'anteprima) e lo spazio disponibile.
    private func altezzaRisultati(disponibile: CGFloat) -> CGFloat {
        // Somma esplicita: le reduce annidate con il ternario rallentano (o bloccano) il controllo dei tipi
        var stima: CGFloat = 2 * M.margineElenco
        for s in motore.esito.sezioni {
            stima += M.stimaGruppo
            for r in s.risultati {
                stima += M.stimaRiga
                if r.estratto != nil { stima += M.stimaEstratto }
            }
        }
        let massima = min(M.risultatiMassima, disponibile)
        return min(max(stima, min(M.risultatiMinima, massima)), massima)
    }

    // MARK: Pannello vuoto

    /// Le ricerche salvate e i filtri da toccare.
    private var vuoto: some View {
        let salvate = stato.ricercheSalvate
        return VStack(alignment: .leading, spacing: 0) {
            if !salvate.isEmpty {
                intestazioneGruppo("Ricerche salvate")
                if salvate.count > M.salvateSenzaScorrere {
                    ScrollView { righeSalvate(salvate) }
                        .frame(height: M.salvateAltezza)
                } else {
                    righeSalvate(salvate)
                }
            }
            intestazioneGruppo("Cerca per criterio")
            DisposizioneAcapoRicerca(spazio: M.pillolaSpazio) {
                ForEach(FiltriRicerca.chiavi) { s in
                    Button {
                        motore.testo = FiltriRicerca.aggiungi(s, a: motore.testo)
                        fuoco = true
                    } label: {
                        PillolaSpotlight(testo: s.testo, nota: s.descrizione)
                    }
                    .buttonStyle(StileSemplice())
                }
            }
            .padding(M.gruppoMargine)
        }
        .padding(M.vuotoMargine)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func righeSalvate(_ salvate: [RicercaSalvata]) -> some View {
        VStack(spacing: 0) {
            ForEach(salvate) { r in
                HStack(spacing: M.rigaSpazio) {
                    Button {
                        motore.testo = r.testo
                        fuoco = true
                    } label: {
                        HStack(spacing: M.rigaSpazio) {
                            TesseraAzioneRicerca(simbolo: "magnifyingglass", lato: M.icona)
                            VStack(alignment: .leading, spacing: M.rigaTestoSpazio) {
                                Text(r.nome).font(Tipo.spotlightTitolo).foregroundColor(Colori.Spotlight.titolo)
                                Text(r.testo).font(Tipo.spotlightDettaglio).foregroundColor(Colori.Spotlight.dettaglio)
                            }
                            .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(StileSemplice())
                    if !stato.solaLettura {
                        Button { stato.eliminaRicerca(r.id) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Colori.Spotlight.cancella)
                        }
                        .buttonStyle(StileSemplice())
                        .help("Togli dalle ricerche salvate")
                    }
                }
                .padding(M.rigaMargine)
                .fondoPassaggio(.arrotondata(Tema.Raggio.voceRicerca), sopra: Colori.Spotlight.sopra)
            }
        }
    }

    private func intestazioneGruppo(_ titolo: String) -> some View {
        Text(titolo)
            .font(Tipo.spotlightGruppo)
            .foregroundColor(Colori.Spotlight.gruppo)
            .padding(M.gruppoMargine)
    }

    // MARK: Risultati

    private var elencoRisultati: some View {
        ScrollViewReader { scorri in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(motore.esito.sezioni) { s in
                        HStack {
                            Text(s.gruppo.titolo)
                            Spacer(minLength: 0)
                            if s.totale > s.risultati.count { Text("\(s.risultati.count) di \(s.totale)") }
                        }
                        .font(Tipo.spotlightGruppo)
                        .foregroundColor(Colori.Spotlight.gruppo)
                        .padding(M.gruppoMargine)
                        ForEach(s.risultati) { r in
                            let i = motore.indici[r.id] ?? 0
                            RigaSpotlight(risultato: r, selezionata: i == motore.selezione, cliente: cliente(di: r))
                                .id(r.id)
                                .onTapGesture {
                                    motore.selezione = i
                                    fuoco = true
                                }
                                // Doppio clic: apre, come in Spotlight
                                .simultaneousGesture(TapGesture(count: 2).onEnded { apri(r) })
                        }
                    }
                }
                .padding(M.margineElenco)
            }
            .onChange(of: motore.selezione) { i in
                if motore.elenco.indices.contains(i) { scorri.scrollTo(motore.elenco[i].id) }
            }
        }
    }

    private func cliente(di r: RisultatoRicerca) -> Cliente? {
        if case .cliente(let id) = r.destinazione { return stato.cliente(id) }
        return nil
    }

    @ViewBuilder private var anteprima: some View {
        if let r = motore.scelto {
            AnteprimaRicerca(scheda: SchedeRicerca.scheda(r, stato: stato), sola: stato.solaLettura) { fai($0, r) }
                .id(r.id)
        }
    }

    // MARK: Piede

    @ViewBuilder private var pie: some View {
        if motore.nomeDaSalvare != nil {
            HStack(spacing: M.azioniSpazio) {
                Text("Salva come").font(Tipo.spotlightPie).foregroundColor(Colori.Spotlight.pie)
                TextField("Nome della ricerca", text: Binding(get: { motore.nomeDaSalvare ?? "" }, set: { motore.nomeDaSalvare = $0 }))
                    .campoTesto()
                    .frame(width: M.nomeRicercaLarghezza)
                    .focused($fuocoNome)
                    .onSubmit { salvaRicerca() }
                Spacer(minLength: 0)
                Button("Annulla") { motore.nomeDaSalvare = nil }
                    .buttonStyle(StileVetro())
                Button("Salva") { salvaRicerca() }
                    .buttonStyle(StileBlu())
            }
            .padding(M.pieMargine)
        } else {
            HStack(spacing: M.pieSpazio) {
                Text("↑ ↓ per scegliere")
                Text("Invio per aprire")
                if !motore.suggerimenti.isEmpty { Text("Tab per completare") }
                Text("Esc per chiudere")
                Spacer(minLength: 0)
                if !motore.vuoto && !stato.solaLettura {
                    Button {
                        motore.nomeDaSalvare = motore.nomeProposto
                    } label: {
                        Label("Salva ricerca", systemImage: "bookmark")
                    }
                    .buttonStyle(StileSemplice())
                    .foregroundColor(Colori.Spotlight.collegamento)
                    .help("Salva questa ricerca: la ritrovi qui, a pannello vuoto")
                }
            }
            .font(Tipo.spotlightPie)
            .foregroundColor(Colori.Spotlight.pie)
            .lineLimit(1)
            .padding(M.pieMargine)
        }
    }

    private func salvaRicerca() {
        guard let nome = motore.nomeDaSalvare else { return }
        stato.salvaRicerca(motore.testo, nome: nome)
        motore.nomeDaSalvare = nil
    }

    // MARK: Azioni

    private func chiudi() {
        stato.chiudiRicerca()
    }

    private func chiudiSeSalvato() {
        if chiudiDopoModulo {
            chiudiDopoModulo = false
            chiudi()
        }
        aggiornaTasti()
    }

    private func apriScelto() {
        if let r = motore.scelto { apri(r) }
    }

    /// Invio o doppio clic: il risultato si apre nella sua app (l'azione si esegue) e il pannello si chiude.
    private func apri(_ r: RisultatoRicerca) {
        if let a = r.azione {
            esegui(a)
            return
        }
        chiudi()
        stato.vai(a: r.destinazione)
    }

    private func esegui(_ a: AzioneRicerca) {
        let cliente = stato.clienti.first { $0.id == stato.clienteAttivoId }?.id ?? stato.clienti.first?.id
        switch a {
        case .nuovoAppuntamento:
            guard let c = cliente, !stato.solaLettura else { return }
            moduloAppuntamento = Appuntamento.nuovo(clienteId: c, giorno: Date())
        case .nuovaAttivita:
            guard let c = cliente, !stato.solaLettura else { return }
            moduloAttivita = Attivita.nuova(clienteId: c)
        default:
            chiudi()
            stato.eseguiAzione(a)
        }
    }

    /// Le azioni dell'anteprima.
    private func fai(_ azione: AzioneAnteprima, _ r: RisultatoRicerca) {
        switch azione {
        case .apri:
            apri(r)
        case .prospetto(let scelta, let cliente):
            chiudi()
            stato.clienteAttivoId = cliente
            stato.apriProspetto(scelta)
        case .appuntamento(let cliente, let posizione):
            var a = Appuntamento.nuovo(clienteId: cliente, giorno: Date())
            a.posizioneId = posizione
            if let id = posizione, let p = stato.dati.posizioni.first(where: { $0.id == id }) {
                a.canale = p.canale
                a.titolo = p.stato == .proposta ? "Proposta: \(p.nome)" : "Revisione di \(p.nome)"
            }
            moduloAppuntamento = a
        case .attivita(let cliente, let appuntamento):
            var t = Attivita.nuova(clienteId: cliente)
            t.appuntamentoId = appuntamento
            moduloAttivita = t
        case .attivitaDaNota(let id):
            if let t = stato.bozzaAttivitaDaNota(id) { moduloAttivita = t }
        case .alternaCompletata(let id):
            stato.alternaCompletata(id)
            motore.aggiorna(stato)
            if let i = motore.indici[r.id] { motore.selezione = i }
        case .cliente(let id):
            chiudi()
            stato.apriCliente(id)
        case .eseguiAzione(let a):
            esegui(a)
        }
    }

    // MARK: Tasti

    /// ↑ ↓ Invio Tab Esc anche mentre il cursore è nel campo (non nelle istantanee).
    private func installaTasti() {
        guard monitor == nil, !modoIstantanea, !ProcessInfo.processInfo.arguments.contains("--istantanee") else { return }
        let ponte = tasti
        let motore = motore
        ponte.esegui = { tasto in
            switch tasto {
            case .su: motore.sposta(-1)
            case .giu: motore.sposta(1)
            case .invio: if let r = motore.scelto { apri(r) }
            case .tab: if let s = motore.suggerimenti.first { motore.completa(con: s) }
            case .esc:
                // Esc annulla il nome della ricerca da salvare; altrimenti chiude, come Spotlight
                if motore.nomeDaSalvare != nil { motore.nomeDaSalvare = nil } else { chiudi() }
            }
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { evento in
            ponte.gestisci(evento) ? nil : evento
        }
    }

    private func aggiornaTasti() {
        tasti.attivo = moduloAppuntamento == nil && moduloAttivita == nil
        tasti.conRisultati = !motore.elenco.isEmpty
        tasti.conSuggerimenti = !motore.suggerimenti.isEmpty
        tasti.inNome = motore.nomeDaSalvare != nil
    }
}

// MARK: - Anteprima

/// Una cifra dell'anteprima.
struct CifraRicerca: Identifiable {
    let etichetta: String
    let valore: String
    var id: String { etichetta }
}

/// Le azioni rapide dell'anteprima.
enum AzioneAnteprima: Hashable {
    case apri
    case prospetto(SceltaProspetto, cliente: String)
    case appuntamento(cliente: String, posizione: String?)
    case attivita(cliente: String, appuntamento: String?)
    case attivitaDaNota(String)
    case alternaCompletata(String)
    case cliente(String)
    case eseguiAzione(AzioneRicerca)
}

/// Il contenuto della colonna di anteprima per il risultato scelto.
struct SchedaAnteprima {
    let risultato: RisultatoRicerca
    var titolo: String
    var sottotitolo: String
    var canale: Canale?
    var cliente: Cliente?
    var cifre: [CifraRicerca] = []
    var testo: String?
    /// La prima è l'azione principale (Invio).
    var azioni: [(titolo: String, simbolo: String, azione: AzioneAnteprima)] = []
    /// Azioni che cambiano i dati: spente in sola lettura.
    var modificano: Set<Int> = []
}

/// Le schede dell'anteprima: le cifre principali dell'elemento e le azioni che servono.
enum SchedeRicerca {
    static func scheda(_ r: RisultatoRicerca, stato: StatoShell) -> SchedaAnteprima {
        let dati = stato.dati
        var s = SchedaAnteprima(risultato: r, titolo: r.titolo, sottotitolo: r.dettaglio, canale: r.canale)
        func nome(_ id: String) -> String { stato.cliente(id)?.nome ?? "Senza cliente" }
        func aggiungi(_ etichetta: String, _ valore: String?) {
            if let valore, !valore.isEmpty { s.cifre.append(CifraRicerca(etichetta: etichetta, valore: valore)) }
        }
        func azione(_ titolo: String, _ simbolo: String, _ a: AzioneAnteprima, modifica: Bool = false) {
            if modifica { s.modificano.insert(s.azioni.count) }
            s.azioni.append((titolo: titolo, simbolo: simbolo, azione: a))
        }
        let oggi = Date()

        switch r.destinazione {
        case .cliente(let id):
            guard let c = stato.cliente(id) else { break }
            s.cliente = c
            s.sottotitolo = [c.tema, c.professione].filter { !$0.isEmpty }.joined(separator: " · ")
            let suePosizioni = dati.posizioni.filter { $0.clienteId == id }
            let inEssere = suePosizioni.filter { $0.stato == .inEssere }
            let attive = inEssere.filter { !$0.area.passivo }
            aggiungi("In essere", inEssere.isEmpty ? "Nessuna posizione" : Formati.euro(attive.reduce(0) { $0 + $1.valore }))
            for t in FiltriRicerca.totali(inEssere) where t.valore > 0 {
                aggiungi(t.canale.nomeBreve, "\(Formati.euro(t.valore)) · \(t.numero) \(t.numero == 1 ? "posizione" : "posizioni")")
            }
            let debiti = inEssere.filter { $0.area.passivo }.reduce(0) { $0 + $1.valore }
            if debiti > 0 { aggiungi("Debiti", Formati.euro(debiti)) }
            let proposte = suePosizioni.filter { $0.stato == .proposta && $0.esito != .rifiutata }.count
            if proposte > 0 { aggiungi("Proposte aperte", "\(proposte)") }
            if let a = dati.appuntamenti.filter({ $0.clienteId == id && $0.stato == .pianificato && $0.inizio >= oggi }).min(by: { $0.inizio < $1.inizio }) {
                aggiungi("Prossimo incontro", Formati.dataOra.string(from: a.inizio))
            }
            let daFare = dati.attivita.filter { $0.clienteId == id && !$0.completata }.count
            if daFare > 0 { aggiungi("Attività aperte", "\(daFare)") }
            azione("Apri il dossier", "person.crop.circle", .apri)
            if !inEssere.isEmpty { azione("Resoconto", "doc.richtext", .prospetto(.resoconto(report: false), cliente: id)) }
            azione("Fissa un appuntamento", "calendar.badge.plus", .appuntamento(cliente: id, posizione: nil), modifica: true)
            azione("Crea un'attività", "checklist", .attivita(cliente: id, appuntamento: nil), modifica: true)

        case .posizione(let id):
            guard let p = dati.posizioni.first(where: { $0.id == id }) else { break }
            let prodotto = p.prodottoId.flatMap { stato.prodotto($0) }
            s.sottotitolo = "\(nome(p.clienteId)) · \(p.stato.nome) · \(p.area.nome)"
            aggiungi(p.area.passivo ? "Debito residuo" : "Valore", Formati.euro(p.valore))
            if let v = p.totaleVersato, v > 0 { aggiungi("Versato", Formati.euro(v)) }
            if p.premio > 0 && p.frequenza != .unica { aggiungi("Premio", "\(Formati.euro(p.premio)) \(p.frequenza.nome.lowercased())") }
            if let c = p.capitaleAssicurato, c > 0 { aggiungi("Capitale assicurato", Formati.euro(c)) }
            if let d = p.scadenza { aggiungi("Scadenza", Formati.dataEstesa.string(from: d)) }
            if let n = FiltriRicerca.sri(p, prodotto: prodotto) { aggiungi("SRI", "\(n) su 7") }
            if let x = FiltriRicerca.costo(p, prodotto: prodotto) { aggiungi("Costi annui", Formati.percentuale(x)) }
            if let x = p.rendimentoAtteso { aggiungi("Rendimento atteso", Formati.percentuale(x)) }
            if FiltriRicerca.chiedeBeneficiari(p) {
                let b = p.beneficiari.trimmingCharacters(in: .whitespacesAndNewlines)
                aggiungi("Beneficiari", b.isEmpty ? "da indicare" : b)
            }
            if !p.emittente.isEmpty { aggiungi("Emittente", p.emittente) }
            azione("Apri la posizione", "chart.bar.doc.horizontal", .apri)
            azione("Prospetto", "doc.richtext", .prospetto(.posizione(p.id), cliente: p.clienteId))
            azione("Fissa un appuntamento", "calendar.badge.plus", .appuntamento(cliente: p.clienteId, posizione: p.id), modifica: true)
            azione("Crea un'attività", "checklist", .attivita(cliente: p.clienteId, appuntamento: nil), modifica: true)

        case .appuntamento(let id):
            guard let a = stato.appuntamento(id) else { break }
            s.sottotitolo = nome(a.clienteId)
            aggiungi("Quando", Formati.dataOra.string(from: a.inizio))
            aggiungi("Durata", "\(a.durataMinuti) minuti")
            aggiungi("Dove", a.luogo)
            aggiungi("Tipo", a.tipo.nome)
            aggiungi("Stato", a.stato == .concluso ? "Concluso" : "In programma")
            if let pid = a.posizioneId, let p = dati.posizioni.first(where: { $0.id == pid }) { aggiungi("Posizione", p.nome) }
            s.testo = a.note.isEmpty ? nil : a.note
            azione("Apri in agenda", "calendar", .apri)
            azione("Apri il cliente", "person.crop.circle", .cliente(a.clienteId))
            azione("Crea un'attività", "checklist", .attivita(cliente: a.clienteId, appuntamento: a.id), modifica: true)

        case .documento(let id):
            guard let d = stato.documento(id) else { break }
            s.sottotitolo = nome(d.clienteId)
            aggiungi("Tipo", d.tipo.nome)
            if d.pagine > 0 { aggiungi("Pagine", "\(d.pagine)") }
            aggiungi("Importato il", Formati.dataEstesa.string(from: d.importatoIl))
            if !d.campi.isEmpty { aggiungi("Dati letti", "\(d.campi.count)") }
            s.testo = r.estratto
            azione("Apri il documento", "doc.text", .apri)
            azione("Apri il cliente", "person.crop.circle", .cliente(d.clienteId))

        case .nota(let id):
            guard let n = stato.nota(id) else { break }
            s.sottotitolo = nome(n.clienteId)
            aggiungi("Aggiornata il", Formati.dataEstesa.string(from: n.aggiornataIl))
            s.testo = n.testo.isEmpty ? nil : String(n.testo.prefix(Nota.limiteEve))
            azione("Apri la nota", "note.text", .apri)
            azione("Crea un'attività", "checklist", .attivitaDaNota(n.id), modifica: true)
            azione("Apri il cliente", "person.crop.circle", .cliente(n.clienteId))

        case .attivita(let id):
            guard let t = dati.attivita.first(where: { $0.id == id }) else { break }
            s.sottotitolo = nome(t.clienteId)
            aggiungi("Entro il", Formati.dataEstesa.string(from: t.scadenza))
            aggiungi("Priorità", t.priorita.nome)
            aggiungi("Stato", t.completata ? "Completata" : "Da fare")
            s.testo = t.note.isEmpty ? nil : t.note
            azione("Apri l'attività", "checklist", .apri)
            azione(t.completata ? "Riapri" : "Segna come fatta", t.completata ? "arrow.uturn.backward" : "checkmark.circle",
                   .alternaCompletata(t.id), modifica: true)
            azione("Apri il cliente", "person.crop.circle", .cliente(t.clienteId))

        case .obiettivo(let id):
            guard let o = dati.obiettivi.first(where: { $0.id == id }) else { break }
            s.sottotitolo = nome(o.clienteId)
            aggiungi("Importo", Formati.euro(o.importo))
            aggiungi("Entro il", Formati.dataEstesa.string(from: o.scadenza))
            if o.accantonato > 0 { aggiungi("Già da parte", Formati.euro(o.accantonato)) }
            azione("Apri l'obiettivo", "target", .apri)
            azione("Apri il cliente", "person.crop.circle", .cliente(o.clienteId))

        case .incontro(let id):
            guard let i = stato.incontro(id) else { break }
            s.sottotitolo = nome(i.clienteId)
            aggiungi("Data", Formati.dataEstesa.string(from: i.data))
            s.testo = i.decisioni.isEmpty ? (i.appunti.isEmpty ? nil : i.appunti) : i.decisioni
            azione("Apri l'incontro", "person.2", .apri)
            azione("Apri il cliente", "person.crop.circle", .cliente(i.clienteId))

        case .prodotto(let id):
            guard let p = stato.prodotto(id) else { break }
            aggiungi("Emittente", p.emittente)
            aggiungi("Tipologia", p.tipologia)
            aggiungi("Area", p.area.nome)
            if let n = p.sri { aggiungi("SRI", "\(n) su 7") }
            if let x = p.incidenzaCostiKID ?? p.costoAnnuo { aggiungi("Costi annui", Formati.percentuale(x)) }
            if let x = p.rendimentoAtteso { aggiungi("Rendimento atteso", Formati.percentuale(x)) }
            let usata = stato.posizioniDelProdotto(p.id).count
            if usata > 0 { aggiungi("Usata in", "\(usata) \(usata == 1 ? "posizione" : "posizioni")") }
            azione("Apri la scheda", "shippingbox", .apri)

        case .app(let app):
            if let a = r.azione {
                s.sottotitolo = "Azione rapida"
                s.testo = a.dettaglio
                azione("Esegui", a.simbolo, .eseguiAzione(a), modifica: a.conModulo)
            } else {
                s.sottotitolo = app.sottotitolo
                s.testo = app.inArrivo
                azione("Apri \(app.titolo)", "arrow.up.forward.app", .apri)
            }
        }
        return s
    }
}

/// La colonna di anteprima: icona grande, titolo, canale, cifre, testo e azioni rapide.
struct AnteprimaRicerca: View {
    let scheda: SchedaAnteprima
    /// Sola lettura: le azioni che cambiano i dati sono spente.
    let sola: Bool
    let fai: (AzioneAnteprima) -> Void

    private typealias M = Misure.Spotlight

    var body: some View {
        // Le cifre scorrono; le azioni stanno in un piede fisso, sempre intere dentro il pannello
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: M.anteprimaSpazio) {
                    HStack(spacing: M.intestazioneSpazio) {
                        IconaRisultatoRicerca(risultato: scheda.risultato, cliente: scheda.cliente, lato: M.iconaAnteprima)
                        VStack(alignment: .leading, spacing: M.rigaTestoSpazio) {
                            Text(scheda.titolo)
                                .font(Tipo.spotlightAnteprimaTitolo)
                                .tracking(Tema.Testo.spaziaturaSezione)
                                .foregroundColor(Colori.Spotlight.titolo)
                                .lineLimit(2)
                            if !scheda.sottotitolo.isEmpty {
                                Text(scheda.sottotitolo)
                                    .font(Tipo.spotlightAnteprimaSottotitolo)
                                    .foregroundColor(Colori.Spotlight.dettaglio)
                                    .lineLimit(2)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    if let c = scheda.canale { EtichettaCanale(canale: c) }
                    if !scheda.cifre.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(scheda.cifre.enumerated()), id: \.element.id) { i, c in
                                CifraAnteprimaRicerca(etichetta: c.etichetta, valore: c.valore, ultima: i == scheda.cifre.count - 1)
                            }
                        }
                    }
                    if let t = scheda.testo, !t.isEmpty {
                        Text(t)
                            .font(Tipo.spotlightTesto)
                            .foregroundColor(Colori.Spotlight.testoAnteprima)
                            .lineLimit(M.testoAnteprimaRighe)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(M.anteprimaMargine)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .sfumaturaBordiScorrimento(sotto: scheda.azioni.isEmpty ? 0 : M.sfumaturaAnteprima)
            if !scheda.azioni.isEmpty {
                azioni
                    .padding(M.azioniMargine)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var azioni: some View {
        DisposizioneAcapoRicerca(spazio: M.azioniSpazio) {
            ForEach(Array(scheda.azioni.enumerated()), id: \.offset) { i, a in
                if i == 0 {
                    Button { fai(a.azione) } label: { Label(a.titolo, systemImage: a.simbolo) }
                        .buttonStyle(StileBlu())
                        .disabled(sola && scheda.modificano.contains(i))
                } else {
                    Button { fai(a.azione) } label: { Label(a.titolo, systemImage: a.simbolo) }
                        .buttonStyle(StileVetro())
                        .disabled(sola && scheda.modificano.contains(i))
                }
            }
        }
    }
}

// MARK: - Disposizione a capo

/// Pillole e pulsanti in fila che vanno a capo quando la riga è piena (macOS 13: niente FlowLayout di sistema).
struct DisposizioneAcapoRicerca: Layout {
    var spazio: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limite = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var riga: CGFloat = 0
        var larghezza: CGFloat = 0
        for s in subviews {
            let d = s.sizeThatFits(.unspecified)
            if x > 0 && x + d.width > limite {
                y += riga + spazio
                x = 0
                riga = 0
            }
            x += d.width
            larghezza = max(larghezza, x)
            x += spazio
            riga = max(riga, d.height)
        }
        let w = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? larghezza
        return CGSize(width: w, height: y + riga)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var riga: CGFloat = 0
        for s in subviews {
            let d = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + d.width > bounds.maxX {
                y += riga + spazio
                x = bounds.minX
                riga = 0
            }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(d))
            x += d.width + spazio
            riga = max(riga, d.height)
        }
    }
}
