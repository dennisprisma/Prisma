#if os(macOS)
import AppKit
#endif
import SwiftUI

/// App Eve (.os-app-eve del tema): un solo contenitore in vetro, a sinistra il contesto (Eve, il cliente,
/// lo stato di Qwen, la giornata), a destra la conversazione con bolle, spunti e campo di scrittura a capsula.
/// Eve risponde con Qwen sul Mac (Ollama); i calcoli e le cifre li prepara Prisma.
/// I numeri li calcola sempre Prisma: Eve li legge e li spiega.
struct AppEve: View {
    @EnvironmentObject var stato: StatoShell
    /// Il campo della domanda in primo piano: serve alla dettatura di macOS, che scrive dove c'è il cursore.
    @FocusState private var campoAttivo: Bool

    private var cliente: Cliente? { stato.clienteAttivo }
    private var messaggi: [MessaggioEve] { stato.conversazione(stato.evePortafoglio ? EvePortafoglio.chiave : stato.clienteAttivoId) }

    private func invia(_ testo: String) {
        if stato.evePortafoglio { stato.chiediEvePortafoglio(testo) } else { stato.chiediEve(testo) }
    }

    var body: some View {
        let raggio = Tema.Raggio.EveChat.contenitore
        GeometryReader { geo in
            // Eve a metà schermo: il contesto si stringe e la conversazione resta sempre dentro la finestra
            let m = Tema.Misura.EveChat.self
            let larghezzaContesto = geo.size.width < m.sogliaContestoStretto ? m.contestoStretto : m.contesto
            HStack(spacing: 0) {
                contesto(larghezza: larghezzaContesto)
                    .frame(width: larghezzaContesto)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Tema.Colore.EveChat.fondoContesto)
                Rectangle()
                    .fill(Tema.Colore.EveChat.divisore)
                    .frame(width: Tema.Misura.filo)
                    .frame(maxHeight: .infinity)
                    .allowsHitTesting(false)
                conversazione
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                    .clipped()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipShape(FormaVetro.arrotondata(raggio))
        .vetro(.sottile, forma: .arrotondata(raggio))
        // Parte sia alla nascita della vista (Eve era chiusa o ridotta) sia a ogni nuova richiesta
        .task(id: stato.richiestaDettatura) { await accendiDettatura() }
        // Il FocusState resta in pari con makeFirstResponder(nil), altrimenti il prossimo «true» non cambia niente
        .onChange(of: stato.dettaturaAttiva) { attiva in if !attiva { campoAttivo = false } }
    }

    /// La dettatura di macOS scrive dove c'è il cursore: prima il campo (riaffermato, con qualche tentativo),
    /// poi «Avvia dettatura». `sendAction` risponde sempre true (lo gestisce NSApplication): l'esito si legge
    /// dal contesto di testo in primo piano.
    private func accendiDettatura() async {
        guard stato.richiestaDettatura > 0, stato.dettaturaAttiva else { return }
        #if os(macOS)
        campoAttivo = false
        for tentativo in 1...4 {
            try? await Task.sleep(nanoseconds: tentativo == 1 ? 100_000_000 : 300_000_000)
            guard !Task.isCancelled, stato.dettaturaAttiva else { return }
            campoAttivo = true
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled, stato.dettaturaAttiva else { return }
            if NSTextInputContext.current != nil {
                DiagnosticaVoce.annota("Dettatura di macOS: campo pronto al tentativo \(tentativo), mando «Avvia dettatura»")
                NSApp.sendAction(Selector(("startDictation:")), to: nil, from: nil)
                return
            }
            let primo = NSApp.keyWindow?.firstResponder.map { String(describing: type(of: $0)) } ?? "nessuno"
            DiagnosticaVoce.annota("Dettatura di macOS: il campo non ha il cursore (tentativo \(tentativo), primo risponditore \(primo))")
        }
        stato.dettaturaNonPartita()
        #elseif os(iOS)
        // Su iPhone e iPad la dettatura è il tasto microfono della tastiera: basta il cursore nel campo
        campoAttivo = true
        DiagnosticaVoce.annota("iPhone e iPad: cursore nel campo, la dettatura è il microfono della tastiera")
        #endif
    }

    // MARK: - Contesto (colonna a sinistra)

    private func contesto(larghezza: CGFloat) -> some View {
        let m = Tema.Misura.EveChat.self
        // Senza barra di scorrimento (sembrava un secondo divisore); le tessere in fondo sfumano invece di
        // finire tagliate a metà
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: m.spazioContesto) {
                saluto
                ambito(larghezza: larghezza)
                motore
                giornata
                if let c = cliente, !stato.evePortafoglio { quadro(c) }
            }
            .padding(m.margineContesto)
            .padding(.bottom, m.sfumaturaContesto / 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sfumaturaBordiScorrimento(sotto: m.sfumaturaContesto)
    }

    /// Eve si presenta (.eve-ctx del tema): la sfera, il nome e una riga.
    private var saluto: some View {
        let m = Tema.Misura.EveChat.self
        let c = Tema.Colore.EveChat.self
        return VStack(spacing: m.spazioSaluto) {
            SferaEve(lato: m.sferaContesto, pensa: stato.eveInCorso)
            Text("Ciao, sono Eve.")
                .font(Tema.Testo.EveChat.nome)
                .foregroundColor(c.testo)
            Text("Mettiamo in ordine le idee.")
                .font(Tema.Testo.EveChat.ruolo)
                .foregroundColor(c.testoSecondario)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, m.spazioSaluto)
    }

    /// Di chi si parla: un cliente (scelto dal menu) o tutto il portafoglio.
    private func ambito(larghezza colonna: CGFloat) -> some View {
        let m = Tema.Misura.EveChat.self
        let larghezza = colonna - 2 * m.margineContesto
        return VStack(alignment: .leading, spacing: m.spazioSezione) {
            if !stato.inModoCliente {
                SegmentiAnalisi(opzioni: [(false, "Cliente"), (true, "Portafoglio")], selezione: $stato.evePortafoglio)
                    .frame(maxWidth: .infinity)
                    .help("Eve parla di un cliente o di tutto il tuo portafoglio")
            }
            if stato.evePortafoglio {
                HStack(spacing: m.spazioSezione) {
                    Image(systemName: "person.3")
                        .foregroundColor(Tema.Colore.EveChat.testoSecondario)
                    Text("Tutti i clienti")
                        .foregroundColor(Tema.Colore.EveChat.testo)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(Tema.Testo.EveChat.ambito)
                .padding(.horizontal, Tema.Misura.Componenti.margineCapsula)
                .frame(height: m.altezzaAmbito)
                .background { FormaVetro.capsula.fill(Tema.Colore.pozzetto) }
            } else {
                MenuTendina(selezione: $stato.clienteAttivoId, opzioni: stato.clienti.map { ($0.id, $0.nome) },
                            stile: .vetro, larghezza: larghezza)
            }
        }
    }

    /// Lo stato di Qwen (.engine del tema): chi risponde, dove lavora e cosa fare se non c'è. Chiaro ma discreto.
    private var motore: some View {
        let q = stato.qwen
        let pronto = q.disponibilita.pronto
        let m = Tema.Misura.EveChat.self
        let c = Tema.Colore.EveChat.self
        return HStack(alignment: .top, spacing: m.spazioSezione) {
            Circle()
                .fill(pronto ? c.pronto : c.nonPronto)
                .frame(width: m.spia, height: m.spia)
                .padding(.top, m.spiaAlto)
            VStack(alignment: .leading, spacing: Tema.Misura.EveChat.righe) {
                Text("\(q.nome) · \(pronto ? "pronto" : "non pronto")")
                    .font(Tema.Testo.EveChat.motore)
                    .foregroundColor(c.testo)
                    .lineLimit(1)
                Text(pronto ? q.descrizione : (q.disponibilita.motivo ?? q.descrizione))
                    .font(Tema.Testo.EveChat.motoreNota)
                    .foregroundColor(c.testoSecondario)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if !pronto {
                    Button { stato.verificaMotoreLocale() } label: { Label("Verifica", systemImage: "arrow.clockwise") }
                        .buttonStyle(StileVetro(margine: m.margineVerifica))
                        .fixedSize()
                        .help("Chiede di nuovo a Ollama se Qwen è pronto")
                        .padding(.top, m.spazioSaluto)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(m.margineMotore)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.EveChat.motore))
    }

    // MARK: - La giornata

    private var giornata: some View {
        let oggi = Calendar.current.startOfDay(for: Date())
        let incontri = stato.appuntamenti
            .filter { $0.stato == .pianificato && $0.inizio >= oggi }
            .sorted { $0.inizio < $1.inizio }
            .prefix(4)
        let urgente = stato.attivitaAperte.sorted {
            $0.priorita.ordine != $1.priorita.ordine ? $0.priorita.ordine < $1.priorita.ordine : $0.scadenza < $1.scadenza
        }.first
        let m = Tema.Misura.EveChat.self
        let c = Tema.Colore.EveChat.self
        let etichetta = incontri.first.map { Calendar.current.isDateInToday($0.inizio) ? "Oggi in agenda" : "Prossimi incontri" } ?? "Agenda libera"
        return VStack(alignment: .leading, spacing: m.spazioSezione) {
            SezioneContestoEve(titolo: "La giornata",
                               dettaglio: InterpreteComandi.maiuscola(Formati.dataLunga.string(from: Date())))
            Text(etichetta)
                .font(Tema.Testo.EveChat.incontroNota)
                .foregroundColor(c.testoSecondario)
            if incontri.isEmpty {
                Text("Nessun incontro futuro salvato.")
                    .font(Tema.Testo.EveChat.incontroNota)
                    .foregroundColor(c.testoTerziario)
            }
            VStack(spacing: m.spazioIncontri) {
                ForEach(Array(incontri)) { e in
                    let attivo = e.clienteId == stato.clienteAttivoId
                    Button { stato.mostraInAgenda(e) } label: {
                        VStack(alignment: .leading, spacing: Tema.Misura.EveChat.righe) {
                            Text("\(Formati.ora.string(from: e.inizio)) · \(Formati.giornoRelativo(e.inizio)) · \(e.durataMinuti) min")
                                .font(Tema.Testo.EveChat.incontroOra)
                                .foregroundColor(c.testoSecondario)
                            Text(e.titolo)
                                .font(Tema.Testo.EveChat.incontroTitolo)
                                .foregroundColor(c.testo)
                                .lineLimit(1)
                            Text(stato.cliente(e.clienteId)?.nome ?? "")
                                .font(Tema.Testo.EveChat.incontroNota)
                                .foregroundColor(c.testoSecondario)
                                .lineLimit(1)
                        }
                        .padding(m.margineIncontro)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // La barretta a sinistra: accento per il cliente di cui si parla
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(attivo ? c.barraIncontroScelto : c.barraIncontro)
                                .frame(width: m.barraIncontro)
                                .padding(.vertical, m.barraIncontroRientro)
                                .padding(.leading, m.barraIncontroRientro)
                                .allowsHitTesting(false)
                        }
                        .fondoPassaggio(.arrotondata(Tema.Raggio.EveChat.incontro), sopra: c.incontroSopra,
                                        selezionata: attivo, selezione: c.incontroScelto)
                        .contentShape(FormaVetro.arrotondata(Tema.Raggio.EveChat.incontro))
                    }
                    .buttonStyle(StileSemplice())
                }
            }
            if let t = urgente {
                Button { stato.apri(.attivita) } label: {
                    VStack(alignment: .leading, spacing: Tema.Misura.EveChat.righePromemoria) {
                        Text("Da non dimenticare")
                            .font(Tema.Testo.EveChat.sezione)
                            .foregroundColor(c.occhielloPromemoria)
                        Text(t.titolo)
                            .font(Tema.Testo.EveChat.promemoria)
                            .foregroundColor(c.testo)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(stato.cliente(t.clienteId)?.nome ?? "") · \(Formati.giornoMese.string(from: t.scadenza))")
                            .font(Tema.Testo.EveChat.incontroNota)
                            .foregroundColor(c.testoSecondario)
                    }
                    .padding(m.marginePromemoria)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background { FormaVetro.arrotondata(Tema.Raggio.EveChat.tessera).fill(c.promemoria) }
                    .overlay {
                        FormaVetro.arrotondata(Tema.Raggio.EveChat.tessera)
                            .strokeBorder(c.bordoPromemoria, lineWidth: Tema.Misura.filo)
                            .allowsHitTesting(false)
                    }
                    .contentShape(FormaVetro.arrotondata(Tema.Raggio.EveChat.tessera))
                }
                .buttonStyle(StileSemplice())
                .padding(.top, m.spazioIncontri)
            }
        }
    }

    private func quadro(_ c: Cliente) -> some View {
        let posizioni = stato.posizioniCliente(c.id)
        let voci: [(Int, String, AppPrisma)] = [
            (posizioni.filter { $0.stato == .inEssere }.count, "posizioni", .posizioni),
            (posizioni.filter { $0.stato == .proposta }.count, "proposte", .posizioni),
            (stato.attivitaCliente(c.id).filter { !$0.completata }.count, "attività aperte", .attivita),
            (stato.simulazioniCliente(c.id).count, "simulazioni", .simulazioni),
        ]
        let m = Tema.Misura.EveChat.self
        let forma = FormaVetro.arrotondata(Tema.Raggio.EveChat.tessera)
        return VStack(alignment: .leading, spacing: m.spazioSezione) {
            SezioneContestoEve(titolo: "Il quadro di \(c.nome)")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: m.spazioTessere), GridItem(.flexible(), spacing: m.spazioTessere)],
                      spacing: m.spazioTessere) {
                ForEach(Array(voci.enumerated()), id: \.offset) { _, v in
                    Button { stato.apri(v.2) } label: {
                        VStack(alignment: .leading, spacing: Tema.Misura.EveChat.righeStrette) {
                            Text("\(v.0)")
                                .font(Tema.Testo.EveChat.quadroNumero)
                                .foregroundColor(Tema.Colore.EveChat.testo)
                            Text(v.1)
                                .font(Tema.Testo.EveChat.quadroVoce)
                                .foregroundColor(Tema.Colore.EveChat.testoSecondario)
                                .lineLimit(1)
                        }
                        .padding(m.margineTessera)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fondoPassaggio(forma, sopra: Tema.Colore.EveChat.tesseraSopra)
                        .vetro(.sottile, forma: forma)
                        .contentShape(forma)
                    }
                    .buttonStyle(StileSemplice())
                }
            }
        }
    }

    // MARK: - Conversazione (colonna a destra)

    private var conversazione: some View {
        VStack(spacing: 0) {
            barra
            messaggiVista
                .frame(maxHeight: .infinity)
            compositore
        }
    }

    /// La barra in alto: di chi si parla, lo stato della voce di Eve, Nuova conversazione. Se non c'è posto lo stato
    /// della voce resta la sola onda e «Nuova conversazione» la sola icona (con il testo nell'aiuto).
    private var barra: some View {
        let m = Tema.Misura.EveChat.self
        let c = Tema.Colore.EveChat.self
        return ViewThatFits(in: .horizontal) {
            rigaBarra(compatta: false)
            rigaBarra(compatta: true)
        }
        .padding(.horizontal, m.margineBarra)
        .frame(height: m.barra)
        .bordoBasso(c.divisore)
    }

    private func rigaBarra(compatta: Bool) -> some View {
        let m = Tema.Misura.EveChat.self
        let c = Tema.Colore.EveChat.self
        return HStack(spacing: m.spazioSezione) {
            VStack(alignment: .leading, spacing: Tema.Misura.EveChat.righeStrette) {
                Text("Conversazione con Eve")
                    .font(Tema.Testo.EveChat.titoloBarra)
                    .foregroundColor(c.testo)
                    .lineLimit(1)
                Text(stato.evePortafoglio ? "Tutti i clienti" : (cliente?.nome ?? ""))
                    .font(Tema.Testo.EveChat.sottotitoloBarra)
                    .foregroundColor(c.testoSecondario)
                    .lineLimit(1)
            }
            Spacer(minLength: m.spazioSezione)
            statoVoce(compatta: compatta)
            if compatta {
                PulsanteIcona(simbolo: "square.and.pencil", aiuto: "Nuova conversazione") { stato.nuovaConversazione() }
                    .disabled(messaggi.isEmpty)
                    .fixedSize()
            } else {
                Button { stato.nuovaConversazione() } label: {
                    Label("Nuova conversazione", systemImage: "square.and.pencil")
                }
                .buttonStyle(StileVetro())
                .disabled(messaggi.isEmpty)
                .fixedSize()
                .help("Comincia da capo: la conversazione di adesso si chiude")
            }
        }
    }

    /// Cosa fa Eve adesso. A riposo segue il motore: se Qwen non è pronto Eve non risponde, e la capsula lo dice.
    private func scrittaVoce(_ v: StatoVoce, ascolta: Bool, pronta: Bool) -> String {
        if v.prepara { return "EVE · SI PREPARA" }
        if ascolta { return "EVE · TI ASCOLTA" }
        if stato.eveInCorso { return "EVE · STA PENSANDO" }
        if v.parla { return "EVE · TI RISPONDE" }
        return pronta ? "EVE · PRONTA" : "EVE · NON PRONTA"
    }

    /// Eve pronta, al lavoro, in ascolto o mentre parla: capsula discreta con l'onda, e i comandi della voce.
    /// Compatta: la sola onda, con lo stato nell'aiuto.
    private func statoVoce(compatta: Bool) -> some View {
        conVoce { v in
            let ascolta = v.ascolta || stato.dettaturaAttiva
            let attiva = stato.eveInCorso || ascolta || v.parla
            let pronta = stato.qwen.disponibilita.pronto
            // A riposo con il motore non pronto l'onda si spegne
            let spenta = !attiva && !v.prepara && !pronta
            let scritta = scrittaVoce(v, ascolta: ascolta, pronta: pronta)
            let m = Tema.Misura.EveChat.self
            let c = Tema.Colore.EveChat.self
            HStack(spacing: m.spazioSezione) {
                HStack(spacing: m.spazioSezione) {
                    if ascolta || v.parla {
                        Circle()
                            .fill(ascolta ? c.ascolto : c.voce)
                            .frame(width: m.spiaVoce, height: m.spiaVoce)
                    }
                    OndaEve(attiva: attiva, livello: v.ascolta ? v.livello : nil, scala: m.scalaOnda, barre: m.barreOnda)
                        .opacity(spenta ? m.opacitaOndaSpenta : 1)
                    if !compatta {
                        Text(scritta)
                            .font(Tema.Testo.EveChat.statoVoce)
                            .tracking(Tema.Testo.EveChat.spaziaturaStatoVoce)
                            .foregroundColor(attiva ? c.testo : c.testoSecondario)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, m.margineStatoVoce)
                .frame(height: m.statoVoce)
                .background { FormaVetro.capsula.fill(c.statoVoce) }
                .help(scritta)
                if v.parla {
                    Button { stato.voceEve.zitta() } label: { Label("Interrompi", systemImage: "speaker.slash") }
                        .buttonStyle(StileVetro())
                        .fixedSize()
                        .help("Eve smette di parlare")
                }
                if stato.conversazioneAVoce {
                    Button { stato.fermaVoce() } label: {
                        if compatta {
                            Image(systemName: "stop.fill")
                        } else {
                            Label("Chiudi la conversazione a voce", systemImage: "stop.fill")
                        }
                    }
                    .buttonStyle(StileVetro())
                    .fixedSize()
                    .help(compatta ? "Chiudi la conversazione a voce · oppure di' a Eve «basta così»" : "Oppure di' a Eve «basta così»")
                }
            }
        }
    }

    /// Il contenuto che segue la voce e l'ascolto di Eve (nelle istantanee, lo stato di prova).
    @ViewBuilder
    private func conVoce<C: View>(@ViewBuilder _ contenuto: @escaping (StatoVoce) -> C) -> some View {
        if stato.persistente {
            OsservaVoce(ascolto: stato.ascoltoEve, voce: stato.voceEve, contenuto: contenuto)
        } else {
            contenuto(stato.voceIstantanea ?? StatoVoce())
        }
    }

    private var messaggiVista: some View {
        let m = Tema.Misura.EveChat.self
        return ScrollViewReader { lettore in
            ScrollView {
                VStack(spacing: m.spazioMessaggi) {
                    if messaggi.isEmpty { benvenuto }
                    ForEach(messaggi) { msg in
                        NuvolaEve(messaggio: msg, nomeUtente: stato.nomeUtente, azioniCliente: !stato.evePortafoglio,
                                  creaAttivita: { stato.attivitaDaEve(msg) }, aggiungiNota: { stato.notaDaEve(msg) },
                                  attivitaProposta: { stato.attivitaDaProposta($0, messaggio: msg.id) },
                                  posizioneProposta: { stato.posizioneDaProposta($0, messaggio: msg.id) },
                                  apriAzione: { stato.apriAzioneEve($0) },
                                  annullaAzione: { stato.annullaAzioneEve($0, messaggio: msg.id) })
                            .id(msg.id)
                    }
                    if stato.eveInCorso {
                        // Eve sta scrivendo: la sua sfera e una piccola bolla, come nelle chat del Mac
                        HStack(alignment: .bottom, spacing: m.spazioSfera) {
                            SferaEve(lato: m.sferaMessaggio, pensa: true, alone: false)
                            HStack(spacing: m.spazioSezione) {
                                ProgressView().controlSize(.small)
                                Text("Eve sta leggendo il dossier…")
                                    .font(Tema.Testo.EveChat.azione)
                                    .foregroundColor(Tema.Colore.EveChat.testoSecondario)
                            }
                            .padding(m.margineBolla)
                            .bollaEve(mia: false)
                            Spacer(minLength: 0)
                        }
                        .id("pensa")
                    }
                }
                .padding(.horizontal, m.margineChat)
                .padding(.vertical, m.margineChatVerticale)
                .frame(maxWidth: m.colonnaChat)
                .frame(maxWidth: .infinity)
            }
            // L'ultima risposta sfuma sopra gli spunti invece di scorrerci sotto senza stacco
            .sfumaturaBordiScorrimento(sotto: m.sfumaturaMessaggi)
            .onChange(of: messaggi.count) { _ in
                if let ultimo = messaggi.last {
                    // Una risposta di Eve si legge dall'inizio: se è più alta della vista ne resta in vista la cima
                    // (se è corta lo scorrimento si ferma comunque in fondo)
                    let ancora: UnitPoint = ultimo.autore == .utente ? .bottom : .top
                    withAnimation { lettore.scrollTo(ultimo.id, anchor: ancora) }
                }
            }
            .onChange(of: stato.eveInCorso) { pensa in
                if pensa { withAnimation { lettore.scrollTo("pensa", anchor: .bottom) } }
            }
        }
    }

    private var benvenuto: some View {
        let m = Tema.Misura.EveChat.self
        let c = Tema.Colore.EveChat.self
        return VStack(spacing: m.spazioSezione) {
            SferaEve(lato: m.sferaBenvenuto, pensa: false)
                .padding(.bottom, m.spazioSaluto)
            Text("Le informazioni ci sono.\nTroviamo il filo.")
                .font(Tema.Testo.EveChat.benvenuto)
                .tracking(Tema.Testo.EveChat.spaziaturaBenvenuto)
                .foregroundColor(c.testo)
            Text(stato.evePortafoglio
                 ? "Parliamo di tutti i tuoi clienti: chi ricontattare, cosa scade, la settimana, gli emittenti, le proposte. Leggo gli stessi calcoli del Portafoglio: i dati restano sul Mac."
                 : "Posso riassumere il percorso di \(cliente?.nome ?? "un cliente"), fare il check-up, spiegare pensione, protezione, liquidità e obiettivi, preparare un incontro. Leggo il dossier e gli stessi calcoli dei prospetti: i dati restano sul Mac.")
                .font(Tema.Testo.EveChat.benvenutoTesto)
                .foregroundColor(c.testoSecondario)
                .lineSpacing(m.interlinea)
                .frame(maxWidth: m.testoBenvenuto)
            Text("Scegli uno spunto qui sotto oppure scrivi una richiesta.")
                .font(Tema.Testo.EveChat.benvenutoNota)
                .foregroundColor(c.testoTerziario)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, m.margineBenvenuto)
        .frame(maxWidth: .infinity)
    }

    private var compositore: some View {
        let m = Tema.Misura.EveChat.self
        return VStack(spacing: m.spazioScrittura) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: m.spazioSpunti) {
                    if stato.evePortafoglio {
                        ForEach(SpuntoPortafoglio.allCases) { s in
                            Button { stato.chiediEvePortafoglio(s.domanda, spunto: s) } label: { spunto(s.simbolo, s.domanda) }
                                .buttonStyle(StileSemplice())
                                .disabled(stato.eveInCorso)
                        }
                    } else {
                        ForEach(SpuntoEve.allCases) { s in
                            Button { stato.chiediEve(s.domanda, spunto: s) } label: { spunto(s.simbolo, s.domanda) }
                                .buttonStyle(StileSemplice())
                                .disabled(stato.eveInCorso)
                        }
                    }
                }
                .padding(.trailing, m.sfumaturaSpunti)
            }
            // Gli spunti che non stanno nella riga sfumano sul bordo destro: si capisce che continuano
            .mask {
                HStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: m.sfumaturaSpunti)
                }
            }
            conVoce { v in campoScrittura(v) }
            conVoce { v in
                let suggerimento = stato.dati.impostazioni.eve.conservaConversazioni
                    ? (stato.evePortafoglio ? "Invio per mandare, ⌥⌘E per parlare · la conversazione del portafoglio resta sul Mac"
                                            : "Invio per mandare, ⌥⌘E per parlare · la conversazione resta nel dossier del cliente, sul Mac")
                    : "Invio per mandare, ⌥⌘E per parlare · conversazione non conservata"
                // In modalità diagnostica: l'ultimo passaggio dell'ascolto, per vedere dove si ferma
                let passaggio = stato.dati.impostazioni.eve.mostraPassaggiVoce ? stato.passaggioVoce : nil
                Text(v.errore ?? passaggio ?? suggerimento)
                    .font(Tema.Testo.EveChat.suggerimento)
                    .foregroundColor(v.errore == nil ? Tema.Colore.EveChat.testoTerziario : Tema.Colore.EveChat.ascolto)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(m.margineScrittura)
        .frame(maxWidth: m.colonnaChat)
        .frame(maxWidth: .infinity)
    }

    /// Il campo di scrittura a capsula (.composer): testo (o quello che Eve sta capendo), microfono e invio.
    private func campoScrittura(_ v: StatoVoce) -> some View {
        let m = Tema.Misura.EveChat.self
        let c = Tema.Colore.EveChat.self
        let forma = FormaVetro.arrotondata(Tema.Raggio.EveChat.composer)
        let acceso = v.ascolta || stato.dettaturaAttiva
        return HStack(alignment: .bottom, spacing: m.spazioScrittura) {
            Group {
                if v.ascolta {
                    // Mentre parli, al posto del campo c'è quello che Eve sta capendo
                    Text(v.trascritto.isEmpty ? (v.nota ?? "Ti ascolto…") : v.trascritto)
                        .font(Tema.Testo.EveChat.campo)
                        .italic(v.trascritto.isEmpty)
                        .foregroundColor(v.trascritto.isEmpty ? c.ascolto : c.testo)
                        .lineLimit(4)
                } else {
                    TextField("Chiedi una sintesi, un incontro, i prossimi passi…", text: $stato.domandaEve, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(Tema.Testo.EveChat.campo)
                        .foregroundColor(c.testo)
                        .lineLimit(1...4)
                        .focused($campoAttivo)
                        .onSubmit { invia(stato.domandaEve) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: m.tasto, alignment: .leading)
            Button { stato.alternaAscolto() } label: {
                Image(systemName: acceso ? "waveform" : "mic.fill")
            }
            .buttonStyle(StileTastoEve(aspetto: acceso ? .ascolto : .neutro))
            .disabled(stato.eveInCorso && !acceso)
            .help(v.prepara ? "Annulla" : (acceso ? "Ho finito di parlare" : "Parla con Eve (⌥⌘E)"))
            Button { invia(stato.domandaEve) } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(StileTastoEve(aspetto: .invio))
            .disabled(stato.eveInCorso || stato.domandaEve.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Invia (⌘↩)")
        }
        .padding(m.margineComposer)
        .background {
            forma.fill(c.composer)
                .ombraTema(Tema.Ombra.EveChat.composer)
        }
        .overlay {
            forma.strokeBorder(acceso ? c.ascolto : c.bordoComposer, lineWidth: acceso ? m.filoAscolto : Tema.Misura.filo)
                .allowsHitTesting(false)
        }
    }
}

extension AppEve {
    /// Una pillola degli spunti.
    func spunto(_ simbolo: String, _ domanda: String) -> some View {
        PillolaSpuntoEve(simbolo: simbolo, testo: domanda)
    }
}

// MARK: - Voce

/// Lo stato della voce di Eve in un momento: ascolta, parla, cosa ha capito, perché non può ascoltare.
struct StatoVoce {
    var ascolta = false
    /// Eve prepara il riconoscimento (il microfono non è ancora acceso).
    var prepara = false
    var parla = false
    var trascritto = ""
    var errore: String?
    /// Quanto suona il microfono (0…1) mentre Eve ascolta.
    var livello: Float = 0
    /// Cosa fa Eve prima di sentirti («Mi preparo ad ascoltarti…»).
    var nota: String?
}

/// Segue l'ascolto e la voce di Eve e ridisegna solo il pezzo che ne dipende.
private struct OsservaVoce<C: View>: View {
    @ObservedObject var ascolto: AscoltoEve
    @ObservedObject var voce: VoceEve
    let contenuto: (StatoVoce) -> C

    var body: some View {
        var errore: String?
        if case .nonDisponibile(let m) = ascolto.stato { errore = m }
        return contenuto(StatoVoce(ascolta: ascolto.ascolta, prepara: ascolto.siPrepara, parla: voce.parla, trascritto: ascolto.trascritto, errore: errore, livello: ascolto.livello, nota: ascolto.nota))
    }
}

// MARK: - Bolla di un messaggio

struct NuvolaEve: View {
    let messaggio: MessaggioEve
    /// Il tuo nome (le tue bolle, come nelle chat del Mac, non lo ripetono: sono a destra, nell'accento).
    let nomeUtente: String
    /// «Crea attività» e «Nota del cliente» solo nelle conversazioni di un cliente.
    var azioniCliente = true
    let creaAttivita: () -> Void
    let aggiungiNota: () -> Void
    var attivitaProposta: (PropostaEve) -> Void = { _ in }
    var posizioneProposta: (PropostaEve) -> Void = { _ in }
    var apriAzione: (AzioneEve) -> Void = { _ in }
    var annullaAzione: (AzioneEve) -> Void = { _ in }

    var body: some View {
        let mio = messaggio.autore == .utente
        let m = Tema.Misura.EveChat.self
        HStack(alignment: .bottom, spacing: m.spazioSfera) {
            if mio {
                Spacer(minLength: m.respiroBollaTua)
            } else {
                SferaEve(lato: m.sferaMessaggio, pensa: false, alone: false)
            }
            contenuto(mio)
                .padding(m.margineBolla)
                .bollaEve(mia: mio)
            if !mio { Spacer(minLength: m.respiroBollaEve) }
        }
    }

    private func contenuto(_ mio: Bool) -> some View {
        let m = Tema.Misura.EveChat.self
        let c = Tema.Colore.EveChat.self
        return VStack(alignment: .leading, spacing: m.spazioBolla) {
            if !mio {
                Text(messaggio.motore.map { "Eve · \($0)" } ?? "Eve")
                    .font(Tema.Testo.EveChat.autore)
                    .foregroundColor(c.testoTerziario)
                    .lineLimit(1)
            }
            if let t = messaggio.titolo, !mio {
                Text(t)
                    .font(Tema.Testo.EveChat.titoloRisposta)
                    .foregroundColor(c.testo)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(messaggio.testo)
                .font(Tema.Testo.EveChat.messaggio)
                .foregroundColor(mio ? c.testoTuo : c.testo)
                .lineSpacing(m.interlinea)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let proposte = messaggio.proposte, !proposte.isEmpty, !mio {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(proposte.enumerated()), id: \.element.id) { i, p in
                        HStack(spacing: m.spazioAzioni) {
                            Text("\(i + 1). \(p.titolo)")
                                .font(Tema.Testo.EveChat.proposta)
                                .foregroundColor(c.testo)
                                .lineLimit(1)
                            Spacer(minLength: m.spazioSezione)
                            if p.attivitaId != nil {
                                Text("✓ in Attività")
                                    .font(Tema.Testo.EveChat.azione)
                                    .foregroundColor(c.testoTerziario)
                            } else {
                                azione("✓ Attività") { attivitaProposta(p) }
                            }
                            if p.area != nil {
                                azione(p.posizioneId == nil ? "＋ Prepara la proposta" : "Apri la proposta ↗") { posizioneProposta(p) }
                            }
                        }
                        .padding(m.margineProposta)
                        .bordoAlto(i == 0 ? Color.clear : c.divisore)
                    }
                }
                .background { FormaVetro.arrotondata(Tema.Raggio.EveChat.gruppoProposte).fill(c.gruppoProposte) }
                .overlay {
                    FormaVetro.arrotondata(Tema.Raggio.EveChat.gruppoProposte)
                        .strokeBorder(c.bordoGruppoProposte, lineWidth: Tema.Misura.filo)
                        .allowsHitTesting(false)
                }
                .padding(.top, m.spazioBolla / 2)
            }
            if let a = messaggio.azione, !mio {
                HStack(spacing: m.spazioAzioni) {
                    if a.annullata {
                        Text("Annullato")
                            .font(Tema.Testo.EveChat.azione)
                            .foregroundColor(c.testoTerziario)
                    } else {
                        azione(Self.apri(a)) { apriAzione(a) }
                        azione("Annulla") { annullaAzione(a) }
                    }
                }
                .padding(.top, m.spazioBolla / 2)
            } else if !mio {
                HStack(spacing: m.spazioAzioni) {
                    if azioniCliente && messaggio.motore != StatoShell.motoreAzioni {
                        azione("✓ Crea attività", creaAttivita)
                        azione("＋ Nota del cliente", aggiungiNota)
                    }
                    azione("Copia") {
                        Appunti.copia((messaggio.titolo.map { $0 + "\n\n" } ?? "") + messaggio.testo)
                    }
                }
                .padding(.top, m.spazioBolla / 2)
            }
        }
    }

    private static func apri(_ a: AzioneEve) -> String {
        switch a.tipo {
        case .appuntamento: return "Apri in Agenda ↗"
        case .attivita: return "Apri in Attività ↗"
        case .nota: return "Apri la nota ↗"
        }
    }

    private func azione(_ titolo: String, _ fai: @escaping () -> Void) -> some View {
        Button(action: fai) {
            ChipAzioneEve(titolo: titolo)
        }
        .buttonStyle(StileSemplice())
    }
}

// MARK: - Sfera e onda

/// La sfera di Eve: viola luminoso, con l'icona dell'app.
struct SferaEve: View {
    let lato: CGFloat
    let pensa: Bool
    /// false = senza alone (la sfera piccola accanto alle bolle).
    var alone = true

    var body: some View {
        IconaApp(app: .eve, lato: lato)
            .shadow(color: alone || pensa ? Colori.Widget.eveAlone.opacity(pensa ? 0.9 : 0.55) : .clear,
                    radius: pensa ? 10 : 6)
    }
}

/// Onda sonora fissa (nessuna animazione continua: niente consumi inutili sul Mac).
struct OndaEve: View {
    let attiva: Bool
    /// Mentre Eve ascolta, l'onda segue il microfono: ferma vuol dire che il microfono non sente.
    var livello: Float? = nil
    /// Altezza delle barre rispetto all'onda piena (la capsula della barra la vuole più bassa).
    var scala: CGFloat = 1
    /// Quante barre disegnare (al massimo tutte).
    var barre = Int.max
    private static let altezze: [CGFloat] = [4, 7, 12, 18, 10, 22, 14, 24, 16, 20, 9, 13, 6, 10, 4, 8, 14, 19, 11, 6, 9, 15, 7, 4]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(Self.altezze.prefix(barre).enumerated()), id: \.offset) { i, h in
                Capsule()
                    .fill(Gradienti.onda)
                    .frame(width: 3, height: altezza(h) * scala)
                    .opacity(attiva ? 1 : 0.6 + Double(i % 3) * 0.1)
            }
        }
        .frame(height: (Self.altezze.max() ?? 0) * scala)
        .fixedSize()
    }

    private func altezza(_ h: CGFloat) -> CGFloat {
        if let livello { return max(3, h * (0.15 + 0.85 * CGFloat(livello))) }
        return attiva ? h : max(3, h * 0.35)
    }
}
