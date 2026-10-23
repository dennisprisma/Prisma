import AppKit
import SwiftUI

/// App Eve (.os-app-eve): a sinistra la giornata su carta, a destra la conversazione.
/// Eve risponde con il modello Apple sul Mac oppure, se non c'è, con la sintesi dai dati.
/// I numeri li calcola sempre Prisma: Eve li legge e li spiega.
struct AppEve: View {
    @EnvironmentObject var stato: StatoShell

    private var cliente: Cliente? { stato.clienteAttivo }
    private var messaggi: [MessaggioEve] { stato.conversazione(stato.evePortafoglio ? EvePortafoglio.chiave : stato.clienteAttivoId) }

    private func invia(_ testo: String) {
        if stato.evePortafoglio { stato.chiediEvePortafoglio(testo) } else { stato.chiediEve(testo) }
    }

    var body: some View {
        VStack(spacing: 8) {
            testata
            avviso
            HStack(alignment: .top, spacing: 10) {
                giornata
                    .frame(width: Misure.Eve.giornata)
                conversazione
            }
        }
    }

    // MARK: - Testata

    private var testata: some View {
        HStack(spacing: 12) {
            SferaEve(lato: Misure.Eve.sfera, pensa: stato.eveInCorso)
            VStack(alignment: .leading, spacing: 1) {
                Text("UNO SGUARDO D'INSIEME").font(Tipo.eveOcchiello).tracking(1).foregroundColor(Colori.Eve.testataTesto)
                Text("Ciao, sono Eve.").font(Tipo.eveSaluto).foregroundColor(Colori.Eve.testataTitolo)
                Text("Mettiamo in ordine le idee.").font(Tipo.eveSottotitolo).foregroundColor(Colori.Eve.testataTesto)
            }
            .incisione(Colori.Eve.testataIncisione, y: -1)
            Spacer()
            SegmentiAnalisi(opzioni: [(false, "Cliente"), (true, "Portafoglio")], selezione: $stato.evePortafoglio)
                .frame(width: 170)
                .help("Eve parla di un cliente o di tutto il tuo portafoglio")
            if stato.evePortafoglio {
                Text("Tutti i clienti").font(Tipo.eveAvviso).foregroundColor(Colori.Eve.testataTitolo)
                    .frame(width: 200, alignment: .leading)
            } else {
                Picker("", selection: $stato.clienteAttivoId) {
                    ForEach(stato.clienti) { c in Text(c.nome).tag(c.id) }
                }
                .labelsHidden()
                .frame(width: 200)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .background(
            ZStack {
                Gradienti.testataEve
                Materiale.Trama(nome: "Grana")
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
        )
        .luceInterna(Colori.Eve.testataLuce, raggio: 3)
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Eve.testataBordo, lineWidth: 1))
    }

    /// Striscia con il motore in uso: è sempre chiaro chi risponde e dove lavora.
    private var avviso: some View {
        let motore = stato.motoreEve
        let apple = !(motore is MotoreSintesi)
        let motivo = MotoriEve.motivoAppleNonDisponibile
        return HStack(spacing: 8) {
            Circle().fill(apple ? Colori.Eve.spiaPronta : Colori.Eve.spiaSintesi).frame(width: 8, height: 8)
                .shadow(color: (apple ? Colori.Eve.spiaPronta : Colori.Eve.spiaSintesi).opacity(0.8), radius: 3)
            Text("\(motore.nome) · elaborazione locale").font(Tipo.eveAvviso)
            Text(apple || stato.dati.impostazioni.eve.motore == .sintesi ? motore.descrizione : (motivo ?? motore.descrizione))
                .font(Tipo.eveAvvisoNota)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Picker("", selection: $stato.dati.impostazioni.eve.motore) {
                ForEach(ImpostazioniEve.Motore.allCases) { m in Text(m.nome).tag(m) }
            }
            .labelsHidden()
            .frame(width: 160)
            .help("Chi risponde: il modello Apple sul Mac, se disponibile, oppure la sintesi dai dati del dossier")
        }
        .foregroundColor(Colori.Eve.avvisoTesto)
        .incisione(Color.white.opacity(0.6))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(RoundedRectangle(cornerRadius: 3).fill(Gradienti.avvisoEve))
        .luceInterna(.white, raggio: 3)
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Eve.avvisoBordo, lineWidth: 1))
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
        return VStack(alignment: .leading, spacing: 0) {
            CuoioAgenda {
                HStack {
                    Text("La giornata").font(Tipo.eveOcchiello).tracking(1)
                    Spacer()
                    Text(Formati.dataLunga.string(from: Date()).capitalized).font(Tipo.eveGiornataData)
                }
                .foregroundColor(Colori.Eve.cuoioTesto)
                .incisione(Colori.Agenda.cuoioIncisione)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(incontri.first.map { Calendar.current.isDateInToday($0.inizio) ? "OGGI IN AGENDA" : "PROSSIMI INCONTRI" } ?? "AGENDA LIBERA")
                        .font(Tipo.eveOcchiello)
                        .tracking(1)
                        .foregroundColor(Colori.Agenda.paginaOcchiello)
                    if incontri.isEmpty {
                        Text("Nessun incontro futuro salvato.").font(Tipo.eveTappaNota).foregroundColor(Colori.Eve.tappaNota)
                    }
                    ForEach(Array(incontri)) { e in
                        let attivo = e.clienteId == stato.clienteAttivoId
                        Button { stato.mostraInAgenda(e) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(Formati.ora.string(from: e.inizio)) · \(Formati.giornoRelativo(e.inizio)) · \(e.durataMinuti) min")
                                    .font(Tipo.eveTappaNota)
                                    .foregroundColor(Colori.Eve.tappaNota)
                                Text(e.titolo).font(Tipo.eveTappa).foregroundColor(Colori.Eve.tappaTesto).lineLimit(1)
                                Text(stato.cliente(e.clienteId)?.nome ?? "").font(Tipo.eveTappaNota).foregroundColor(Colori.Eve.tappaNota)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 3).fill(attivo ? Colori.Eve.tappaAttiva : Colori.Eve.tappa))
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(attivo ? Colori.Eve.tappaAttivaBordo : Colori.Eve.tappaBordo, lineWidth: 1))
                        }
                        .buttonStyle(StileSemplice())
                    }
                    if let t = urgente {
                        Button { stato.apri(.attivita) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DA NON DIMENTICARE").font(Tipo.eveOcchiello).tracking(1)
                                Text(t.titolo).font(Tipo.evePostit).fixedSize(horizontal: false, vertical: true)
                                Text("\(stato.cliente(t.clienteId)?.nome ?? "") · \(Formati.giornoMese.string(from: t.scadenza))").font(Tipo.eveTappaNota)
                            }
                            .foregroundColor(Colori.Eve.postitTesto)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                ZStack {
                                    Gradienti.postit
                                    Materiale.Trama(nome: "Grana")
                                }
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                            .rotationEffect(.degrees(-1))
                        }
                        .buttonStyle(StileSemplice())
                        .padding(.vertical, 4)
                    }
                    if let c = cliente { quadro(c) }
                }
                .padding(12)
            }
        }
        .background(
            ZStack {
                Gradienti.cartaAgenda
                Materiale.Trama(nome: "Grana")
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Colori.Eve.cartaBordo, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
    }

    private func quadro(_ c: Cliente) -> some View {
        let posizioni = stato.posizioniCliente(c.id)
        let voci: [(Int, String, AppPrisma)] = [
            (posizioni.filter { $0.stato == .inEssere }.count, "posizioni", .posizioni),
            (posizioni.filter { $0.stato == .proposta }.count, "proposte", .posizioni),
            (stato.attivitaCliente(c.id).filter { !$0.completata }.count, "attività aperte", .attivita),
            (stato.simulazioniCliente(c.id).count, "simulazioni", .simulazioni),
        ]
        return VStack(alignment: .leading, spacing: 6) {
            Text("IL QUADRO DI \(c.nome.uppercased())").font(Tipo.eveOcchiello).tracking(1).foregroundColor(Colori.Agenda.paginaOcchiello)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)], spacing: 1) {
                ForEach(Array(voci.enumerated()), id: \.offset) { _, v in
                    Button { stato.apri(v.2) } label: {
                        VStack(spacing: 1) {
                            Text("\(v.0)").font(Tipo.eveQuadroNumero)
                            Text(v.1).font(Tipo.eveTappaNota)
                        }
                        .foregroundColor(Colori.Eve.quadroTesto)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Gradienti.quadroEve)
                    }
                    .buttonStyle(StileSemplice())
                }
            }
            .background(Colori.Eve.quadroBordo)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Eve.quadroBordo, lineWidth: 1))
        }
        .padding(.top, 6)
    }

    // MARK: - Conversazione

    private var conversazione: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(Colori.Eve.spiaPronta).frame(width: 6, height: 6)
                Text("Conversazione con Eve").font(Tipo.eveIntestazione)
                Spacer()
                Button("Nuova conversazione") { stato.nuovaConversazione() }
                    .buttonStyle(StileSemplice())
                    .font(Tipo.eveAzione)
                    .disabled(messaggi.isEmpty)
                    .opacity(messaggi.isEmpty ? 0.5 : 1)
            }
            .foregroundColor(Colori.Eve.barraTesto)
            .incisione(Color.white.opacity(0.7))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Gradienti.barraEve)
            .luceInterna(.white)
            .bordoBasso(Colori.Eve.barraBordo)

            display
            messaggiVista
            compositore
        }
        .background(Gradienti.conversazioneEve)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Colori.Eve.conversazioneBordo, lineWidth: 1))
    }

    /// Display scuro con l'onda: Eve pronta o al lavoro.
    private var display: some View {
        HStack(spacing: 10) {
            OndaEve(attiva: stato.eveInCorso)
                .frame(height: 26)
            Text(stato.eveInCorso ? "EVE · STA PENSANDO" : "EVE · PRONTA")
                .font(Tipo.eveDisplay)
                .tracking(1.2)
                .foregroundColor(Colori.Eve.displayTesto)
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .frame(height: Misure.Eve.display)
        .background(RoundedRectangle(cornerRadius: 3).fill(Gradienti.displayEve))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Eve.displayBordo, lineWidth: 1))
        .shadow(color: .white.opacity(0.5), radius: 0, x: 0, y: 1)
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 4, trailing: 10))
    }

    private var messaggiVista: some View {
        ScrollViewReader { lettore in
            ScrollView {
                VStack(spacing: 12) {
                    if messaggi.isEmpty { benvenuto }
                    ForEach(messaggi) { m in
                        NuvolaEve(messaggio: m, nomeUtente: stato.nomeUtente, azioniCliente: !stato.evePortafoglio,
                                  creaAttivita: { stato.attivitaDaEve(m) }, aggiungiNota: { stato.notaDaEve(m) },
                                  attivitaProposta: { stato.attivitaDaProposta($0, messaggio: m.id) },
                                  posizioneProposta: { stato.posizioneDaProposta($0, messaggio: m.id) })
                            .id(m.id)
                    }
                    if stato.eveInCorso {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Eve sta leggendo il dossier…").font(Tipo.eveAzione).foregroundColor(Colori.Eve.autore)
                            Spacer()
                        }
                        .id("pensa")
                    }
                }
                .padding(12)
            }
            .onChange(of: messaggi.count) { _ in
                if let ultimo = messaggi.last?.id {
                    withAnimation { lettore.scrollTo(ultimo, anchor: .bottom) }
                }
            }
            .onChange(of: stato.eveInCorso) { pensa in
                if pensa { withAnimation { lettore.scrollTo("pensa", anchor: .bottom) } }
            }
        }
    }

    private var benvenuto: some View {
        VStack(spacing: 8) {
            SferaEve(lato: 34, pensa: false)
            Text("Le informazioni ci sono.\nTroviamo il filo.")
                .font(Tipo.eveBenvenuto)
                .foregroundColor(Colori.Strumenti.titolo)
                .multilineTextAlignment(.center)
            Text(stato.evePortafoglio
                 ? "Parliamo di tutti i tuoi clienti: chi ricontattare, cosa scade, la settimana, gli emittenti, le proposte. Leggo gli stessi calcoli del Portafoglio: i dati restano sul Mac."
                 : "Posso riassumere il percorso di \(cliente?.nome ?? "un cliente"), fare il check-up, spiegare pensione, protezione, liquidità e obiettivi, preparare un incontro. Leggo il dossier e gli stessi calcoli dei prospetti: i dati restano sul Mac.")
                .font(Tipo.eveMessaggio)
                .foregroundColor(Colori.Eve.nuvolaEveTesto)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Text("Scegli uno spunto qui sotto oppure scrivi una richiesta.")
                .font(Tipo.eveAzione)
                .foregroundColor(Colori.Eve.autore)
        }
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
    }

    private var compositore: some View {
        VStack(alignment: .leading, spacing: 7) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if stato.evePortafoglio {
                        ForEach(SpuntoPortafoglio.allCases) { s in
                            Button { stato.chiediEvePortafoglio(s.domanda, spunto: s) } label: { spunto(s.simbolo, s.domanda) }
                                .buttonStyle(StileSemplice())
                                .disabled(stato.eveInCorso)
                        }
                    } else {
                    ForEach(SpuntoEve.allCases) { s in
                        Button { stato.chiediEve(s.domanda, spunto: s) } label: {
                            HStack(spacing: 5) {
                                Text(s.simbolo).foregroundColor(Colori.Analisi.navBasso)
                                Text(s.domanda)
                            }
                            .font(Tipo.eveSpunto)
                            .foregroundColor(Colori.Eve.azioneTesto)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Gradienti.azioneEve))
                            .overlay(Capsule().strokeBorder(Colori.Eve.azioneBordo, lineWidth: 1))
                        }
                        .buttonStyle(StileSemplice())
                        .disabled(stato.eveInCorso)
                    }
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Chiedi una sintesi, un incontro, i prossimi passi…", text: $stato.domandaEve, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Tipo.eveCampo)
                    .lineLimit(1...4)
                    .onSubmit { invia(stato.domandaEve) }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Colori.Eve.campo))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Colori.Eve.campoBordo, lineWidth: 1))
                Button { invia(stato.domandaEve) } label: {
                    Text("↑").font(Tipo.eveTitoloRisposta).frame(width: 18)
                }
                .buttonStyle(StileBlu())
                .disabled(stato.eveInCorso || stato.domandaEve.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Invia (⌘↩)")
            }
            Text(stato.dati.impostazioni.eve.conservaConversazioni
                 ? (stato.evePortafoglio ? "Invio per mandare · la conversazione del portafoglio resta sul Mac"
                                         : "Invio per mandare · la conversazione resta nel dossier del cliente, sul Mac")
                 : "Invio per mandare · conversazione non conservata")
                .font(Tipo.eveTappaNota)
                .foregroundColor(Colori.Eve.autore)
        }
        .padding(10)
        .background(Gradienti.barraEve)
        .luceInterna(.white)
        .bordoAlto(Colori.Eve.barraBordo)
    }
}

extension AppEve {
    /// Una capsula degli spunti.
    func spunto(_ simbolo: String, _ domanda: String) -> some View {
        HStack(spacing: 5) {
            Text(simbolo).foregroundColor(Colori.Analisi.navBasso)
            Text(domanda)
        }
        .font(Tipo.eveSpunto)
        .foregroundColor(Colori.Eve.azioneTesto)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Gradienti.azioneEve))
        .overlay(Capsule().strokeBorder(Colori.Eve.azioneBordo, lineWidth: 1))
    }
}

// MARK: - Nuvola di un messaggio

struct NuvolaEve: View {
    let messaggio: MessaggioEve
    let nomeUtente: String
    /// «Crea attività» e «Nota del cliente» solo nelle conversazioni di un cliente.
    var azioniCliente = true
    let creaAttivita: () -> Void
    let aggiungiNota: () -> Void
    var attivitaProposta: (PropostaEve) -> Void = { _ in }
    var posizioneProposta: (PropostaEve) -> Void = { _ in }

    var body: some View {
        let mio = messaggio.autore == .utente
        HStack {
            if mio { Spacer(minLength: 60) }
            VStack(alignment: .leading, spacing: 5) {
                Text(mio ? nomeUtente.uppercased() : "✦ EVE · \((messaggio.motore ?? "").uppercased())")
                    .font(Tipo.eveAutore)
                    .tracking(0.6)
                    .foregroundColor(mio ? Colori.Eve.nuvolaTuaTesto.opacity(0.7) : Colori.Eve.autore)
                if let t = messaggio.titolo, !mio {
                    Text(t).font(Tipo.eveTitoloRisposta).foregroundColor(Colori.Strumenti.titolo)
                }
                Text(messaggio.testo)
                    .font(Tipo.eveMessaggio)
                    .foregroundColor(mio ? Colori.Eve.nuvolaTuaTesto : Colori.Eve.nuvolaEveTesto)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let proposte = messaggio.proposte, !proposte.isEmpty, !mio {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(proposte.enumerated()), id: \.element.id) { i, p in
                            HStack(spacing: 6) {
                                Text("\(i + 1). \(p.titolo)")
                                    .font(Tipo.eveAzione)
                                    .foregroundColor(Colori.Strumenti.titolo)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                if p.attivitaId != nil {
                                    Text("✓ in Attività").font(Tipo.eveAzione).foregroundColor(Colori.Eve.autore)
                                } else {
                                    azione("✓ Attività") { attivitaProposta(p) }
                                }
                                if p.area != nil {
                                    azione(p.posizioneId == nil ? "＋ Prepara la proposta" : "Apri la proposta ↗") { posizioneProposta(p) }
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                if !mio {
                    HStack(spacing: 6) {
                        if azioniCliente {
                            azione("✓ Crea attività", creaAttivita)
                            azione("＋ Nota del cliente", aggiungiNota)
                        }
                        azione("Copia") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString((messaggio.titolo.map { $0 + "\n\n" } ?? "") + messaggio.testo, forType: .string)
                        }
                    }
                    .padding(.top, 3)
                }
            }
            .padding(EdgeInsets(top: 9, leading: 12, bottom: 10, trailing: 12))
            .background(
                RoundedRectangle(cornerRadius: Misure.Eve.raggioNuvola)
                    .fill(mio ? AnyShapeStyle(Gradienti.nuvolaTua) : AnyShapeStyle(Gradienti.nuvolaEve))
            )
            .luceInterna(Color.white.opacity(0.6), raggio: Misure.Eve.raggioNuvola)
            .overlay(RoundedRectangle(cornerRadius: Misure.Eve.raggioNuvola)
                .strokeBorder(mio ? Colori.Eve.nuvolaTuaBordo : Colori.Eve.nuvolaEveBordo, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 1)
            if !mio { Spacer(minLength: 60) }
        }
    }

    private func azione(_ titolo: String, _ fai: @escaping () -> Void) -> some View {
        Button(action: fai) {
            Text(titolo)
                .font(Tipo.eveAzione)
                .foregroundColor(Colori.Eve.azioneTesto)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 3).fill(Gradienti.azioneEve))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Eve.azioneBordo, lineWidth: 1))
        }
        .buttonStyle(StileSemplice())
    }
}

// MARK: - Sfera e onda

/// La sfera di Eve: viola luminoso, con l'icona dell'app.
struct SferaEve: View {
    let lato: CGFloat
    let pensa: Bool

    var body: some View {
        IconaApp(app: .eve, lato: lato)
            .shadow(color: Colori.Widget.eveAlone.opacity(pensa ? 0.9 : 0.55), radius: pensa ? 10 : 6)
    }
}

/// Onda sonora fissa (nessuna animazione continua: niente consumi inutili sul Mac).
struct OndaEve: View {
    let attiva: Bool
    private static let altezze: [CGFloat] = [4, 7, 12, 18, 10, 22, 14, 24, 16, 20, 9, 13, 6, 10, 4, 8, 14, 19, 11, 6, 9, 15, 7, 4]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(Self.altezze.enumerated()), id: \.offset) { i, h in
                Capsule()
                    .fill(Gradienti.onda)
                    .frame(width: 3, height: attiva ? h : max(3, h * 0.35))
                    .opacity(attiva ? 1 : 0.6 + Double(i % 3) * 0.1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
