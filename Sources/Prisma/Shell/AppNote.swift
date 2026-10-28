import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// App Note: il taccuino personale. A sinistra l'indice con ricerca e filtro per cliente,
/// a destra la pagina a righe appena accennate. Ogni nota appartiene a un cliente e si salva da sola.
struct AppNote: View {
    @EnvironmentObject var stato: StatoShell
    @State private var modulo: Attivita?
    @State private var confermaEliminazione = false
    /// Quanto è scorso il testo della nota: le righe della pagina lo seguono.
    @State private var scorrimentoTesto: CGFloat = 0
    /// La scrittura di titolo e testo in attesa dell'ultimo tasto (si fa subito prima di esportare o creare un'attività).
    @State private var scritturaNota = Rinvio()

    /// Quanto aspettare dopo l'ultimo tasto prima di passare il testo allo stato condiviso (ricerca e nota).
    static let attesaRicerca = 0.15
    static let attesaNota = 0.3

    var body: some View {
        let elenco = stato.noteFiltrate
        // La nota scelta resta aperta anche se la ricerca la nasconde dall'elenco: non se ne apre un'altra sotto le dita
        let scelta = stato.nota(stato.notaSelezionata) ?? elenco.first
        HStack(spacing: 0) {
            indice(elenco, scelta: scelta?.id)
                .frame(width: Misure.Note.indice)
            Group {
                if let n = scelta {
                    pagina(n)
                        .id(n.id)
                        // La prima nota mostrata diventa la scelta: la ricerca non la cambia più sotto le dita
                        .onAppear { if stato.notaSelezionata == nil { stato.notaSelezionata = n.id } }
                } else { vuoto }
            }
            .frame(minWidth: Misure.Note.minimaPagina, maxWidth: .infinity, maxHeight: .infinity)
            .background(Colori.Note.paginaCentro)
        }
        // La scheda del tema: angoli tondi e filo da 0,5 pt (il contenuto si taglia prima del contorno)
        .clipShape(FormaVetro.arrotondata(Misure.Note.raggio))
        .overlay {
            FormaVetro.arrotondata(Misure.Note.raggio)
                .strokeBorder(Colori.Note.taccuinoBordo, lineWidth: Tema.Misura.filo)
                .allowsHitTesting(false)
        }
        .sheet(item: $modulo) { a in
            ModuloAttivita(bozza: a, nuova: true, salva: { stato.salvaAttivita($0) }, elimina: {})
                .environmentObject(stato)
        }
        .confirmationDialog("Eliminare questa nota?", isPresented: $confermaEliminazione) {
            Button("Elimina la nota", role: .destructive) {
                if let n = stato.nota(stato.notaSelezionata) ?? stato.noteFiltrate.first { stato.eliminaNota(n.id) }
            }
        } message: {
            Text("La nota sparisce dal taccuino. Resta solo nei backup fatti prima di oggi.")
        }
        // Cambiato il filtro dei clienti, si riparte dalla prima nota dell'elenco
        .onChange(of: stato.filtroClienteNote) { filtro in
            if let n = stato.nota(stato.notaSelezionata), filtro != nil, n.clienteId != filtro { stato.scegliNota(nil) }
        }
    }

    // MARK: - Indice

    private func indice(_ elenco: [Nota], scelta: String?) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("NOTE").font(Tipo.noteEtichetta).tracking(2)
                Spacer()
                Text("\(stato.dati.note.filter { !$0.vuota }.count)")
                    .font(Tipo.noteContatore)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(FormaVetro.capsula.fill(Colori.Note.contatore))
            }
            .foregroundColor(Colori.Note.cuoioTesto)
            .padding(Misure.Note.etichetta)
            .background(CuoioNote())

            VStack(spacing: 8) {
                CampoCercaNote()
                    .padding(.horizontal, 10)
                    .frame(height: Misure.Note.campoAltezza)
                    .background(FormaVetro.capsula.fill(Colori.Note.campo))
                    .overlay(FormaVetro.capsula.strokeBorder(Colori.Note.campoBordo, lineWidth: Tema.Misura.filo).allowsHitTesting(false))
                MenuTendina(selezione: $stato.filtroClienteNote,
                            opzioni: [(String?.none, "Tutti i clienti")] + stato.clienti.map { (Optional($0.id), $0.nome) },
                            stile: .carta)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 12))

            if elenco.isEmpty {
                VStack(spacing: 8) {
                    Text("Nessuna nota qui.").font(Tipo.noteVoceTitolo)
                    Text(stato.ricercaNote.isEmpty ? "Comincia da un pensiero." : "Prova un'altra ricerca.").font(Tipo.noteVoceTesto)
                    Button("Scrivi una nota") { stato.nuovaNota() }
                        .buttonStyle(StileCuoioNote())
                }
                .foregroundColor(Colori.Note.voceSecondario)
                .multilineTextAlignment(.center)
                .padding(.vertical, 30)
                .padding(.horizontal, 17)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: Tema.Misura.Dossier.spazioVoci) {
                        ForEach(elenco) { n in voce(n, selezionata: n.id == scelta) }
                    }
                    .padding(.horizontal, Tema.Misura.Dossier.margineElenco)
                }
            }

            Text("\(elenco.count) \(elenco.count == 1 ? "nota" : "note") · il tuo taccuino")
                .font(Tipo.notePiede)
                .foregroundColor(Colori.Note.piedeIndice)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .bordoAlto(Colori.Note.piedeIndiceBordo)
        }
        .background(Colori.Note.indiceCentro)
        .overlay(alignment: .trailing) { Rectangle().fill(Colori.Note.indiceBordo).frame(width: Tema.Misura.filo) }
    }

    private func voce(_ n: Nota, selezionata: Bool) -> some View {
        Button { stato.scegliNota(n.id) } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    if n.fissata {
                        Text("◆").font(Tipo.noteVoceData).foregroundColor(Colori.Note.fissata)
                    }
                    Text(n.titoloMostrato).font(Tipo.noteVoceTitolo).lineLimit(1)
                }
                Text(n.anteprima)
                    .font(Tipo.noteVoceTesto)
                    .lineLimit(2)
                    .foregroundColor(selezionata ? Colori.Note.selezioneTesto : Colori.Note.voceSecondario)
                Text("\(stato.cliente(n.clienteId)?.nome ?? "Cliente") · \(n.vuota ? "Bozza" : Formati.giornoMeseBreve.string(from: n.aggiornataIl))")
                    .font(Tipo.noteVoceData)
                    .foregroundColor(selezionata ? Colori.Note.selezioneTesto : Colori.Note.voceSecondario)
            }
            .foregroundColor(selezionata ? Colori.Note.selezioneTesto : Colori.Note.voceTesto)
            .multilineTextAlignment(.leading)
            .padding(Misure.Note.voce)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Voce scelta come nelle barre laterali del tema: accento appena accennato, angoli tondi
            .fondoPassaggio(.arrotondata(Tema.Raggio.voceLaterale), sopra: Tema.Colore.rigaSopra,
                            selezionata: selezionata, selezione: Colori.Note.selezioneAlto)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }

    // MARK: - Pagina

    private func pagina(_ n: Nota) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(n.fissata ? "◆ In evidenza" : "◇ Fissa nota") {
                    stato.modificaNota(n.id) { $0.fissata.toggle() }
                }
                .buttonStyle(StileCuoioNote(evidenziato: n.fissata))
                .help(n.fissata ? "Togli dalla cima dell'elenco" : "Tieni la nota in cima all'elenco")
                Spacer()
                Text("Si salva da sola · \(Formati.ora.string(from: n.aggiornataIl))")
                    .font(Tipo.noteStato)
                    .foregroundColor(Colori.Note.stato)
                Button("Elimina") { confermaEliminazione = true }
                    .buttonStyle(StileCuoioNote())
            }
            .padding(Misure.Note.barra)
            .background(CuoioNote())

            ZStack(alignment: .topLeading) {
                MargineNote().padding(.leading, Misure.Note.margine)
                VStack(alignment: .leading, spacing: 0) {
                    rigaCliente(n)
                    CampiNota(nota: n, scorrimento: $scorrimentoTesto, scrittura: scritturaNota)
                }
                .padding(Misure.Note.carta)
            }
            .frame(maxHeight: .infinity)

            azioni(n)
        }
    }

    private func rigaCliente(_ n: Nota) -> some View {
        HStack(spacing: 9) {
            Text("PER").font(Tipo.notePer).tracking(1.5).foregroundColor(Colori.Note.etichetta)
            MenuTendina(selezione: Binding(get: { n.clienteId }, set: { v in stato.modificaNota(n.id) { $0.clienteId = v } }),
                        opzioni: stato.clienti.map { ($0.id, $0.nome) }, stile: .carta)
                .frame(maxWidth: 220, alignment: .leading)
            Spacer()
            Button("Apri dossier ↗") { stato.apriCliente(n.clienteId) }
                .buttonStyle(StileSemplice())
                .font(Tipo.noteCollegamento)
                .foregroundColor(Colori.Note.collegamento)
                .help("Apri la scheda del cliente")
        }
        .padding(.bottom, 10)
        .bordoBasso(Colori.Note.lineaCliente)
    }

    private func azioni(_ n: Nota) -> some View {
        HStack(spacing: 8) {
            if let c = stato.cliente(n.clienteId) {
                AvatarCliente(iniziali: c.iniziali, tinta: c.tinta.colori, lato: Misure.Note.avatar)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Nel percorso di").foregroundColor(Colori.Note.etichetta)
                    Text(c.nome).fontWeight(.semibold).foregroundColor(Colori.Note.collegamento)
                }
                .font(Tipo.noteDidascalia)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            // Prima si scrive l'ultimo testo digitato, poi si usa la nota
            Button("＋ Crea attività") {
                scritturaNota.subito()
                modulo = stato.bozzaAttivitaDaNota(n.id)
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)))
            .fixedSize()
            .help("Dall'appunto alla prossima azione, per lo stesso cliente")
            Button("Esporta .txt") {
                scritturaNota.subito()
                esporta(stato.nota(n.id) ?? n)
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)))
            .fixedSize()
            .help("Salva una copia di testo dove scegli tu")
        }
        .padding(Misure.Note.azioni)
        .bordoAlto(Colori.Note.azioniBordo)
    }

    private var vuoto: some View {
        VStack(spacing: 12) {
            Text("✎").font(Tipo.noteVuotoIcona).foregroundColor(Colori.Note.vuotoIcona)
            Text("Le cose importanti\niniziano con un appunto.")
                .font(Tipo.noteVuotoTitolo)
                .foregroundColor(Colori.Note.vuotoTitolo)
                .multilineTextAlignment(.center)
            Text("Scegli una nota o apri una pagina nuova.")
                .font(Tipo.noteVuotoTesto)
                .foregroundColor(Colori.Note.vuotoTesto)
            Button("Nuova nota") { stato.nuovaNota() }
                .buttonStyle(StileBlu())
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func esporta(_ n: Nota) {
        let pannello = NSSavePanel()
        pannello.allowedContentTypes = [.plainText]
        pannello.nameFieldStringValue = "\(n.titoloMostrato.replacingOccurrences(of: "/", with: "-")).txt"
        pannello.canCreateDirectories = true
        pannello.message = "La copia resta dove la salvi: Prisma non la invia a nessuno."
        if pannello.runModal() == .OK, let url = pannello.url {
            try? Data(stato.testoEsportato(n).utf8).write(to: url)
        }
    }
}

/// Il campo di ricerca del taccuino: il testo resta qui e passa allo stato poco dopo l'ultimo tasto,
/// così ogni lettera ridisegna solo il campo (l'elenco si filtra un attimo dopo).
private struct CampoCercaNote: View {
    @EnvironmentObject var stato: StatoShell
    @State private var testo = ""
    @State private var invio = Rinvio()

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundColor(Colori.Note.etichetta)
            TextField("Cerca nelle note", text: $testo)
                .textFieldStyle(.plain)
                .font(Tipo.noteVoceTesto)
            if !testo.isEmpty {
                Button { testo = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Colori.Note.etichetta)
                }
                .buttonStyle(StileSemplice())
            }
        }
        .onAppear { if testo != stato.ricercaNote { testo = stato.ricercaNote } }
        .onChange(of: testo) { _ in
            invio.dopo(AppNote.attesaRicerca) { if stato.ricercaNote != testo { stato.ricercaNote = testo } }
        }
        // Cambiata da fuori (nuova nota, ricerca da Eve): vale quella dello stato
        .onChange(of: stato.ricercaNote) { nuova in if nuova != testo { testo = nuova } }
        .onDisappear { invio.subito() }
    }
}

/// Titolo e testo della nota aperta: si scrivono qui e passano all'archivio poco dopo l'ultimo tasto,
/// così ogni lettera ridisegna solo la pagina e non tutta Prisma. La prima lettera di una pagina nuova
/// va subito nell'archivio: cambiando nota, una pagina ancora vuota sparirebbe con quello che c'è scritto.
private struct CampiNota: View {
    @EnvironmentObject var stato: StatoShell
    let nota: Nota
    @Binding var scorrimento: CGFloat
    let scrittura: Rinvio
    @State private var titolo: String
    @State private var testo: String

    init(nota: Nota, scorrimento: Binding<CGFloat>, scrittura: Rinvio) {
        self.nota = nota
        _scorrimento = scorrimento
        self.scrittura = scrittura
        _titolo = State(initialValue: nota.titolo)
        _testo = State(initialValue: nota.testo)
    }

    var body: some View {
        TextField("Dai un titolo alla tua idea…", text: $titolo)
            .textFieldStyle(.plain)
            .font(Tipo.noteTitolo)
            .foregroundColor(Colori.Note.titolo)
            .padding(.leading, 5)
            .padding(.top, 14)
            .padding(.bottom, 10)
        ZStack(alignment: .topLeading) {
            RigheNote(scorrimento: scorrimento).fill(Colori.Note.righe)
            TextEditor(text: $testo)
                .font(Tipo.noteTesto)
                .lineSpacing(Misure.Note.interlinea)
                .foregroundColor(Colori.Note.testo)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .background(ScorrimentoEditor(scorrimento: $scorrimento).allowsHitTesting(false))
            if testo.isEmpty {
                Text("Prendi un appunto. C'è spazio per tutto quello che conta.")
                    .font(Tipo.noteTesto)
                    .foregroundColor(Colori.Note.segnaposto)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: titolo) { _ in rimanda() }
        .onChange(of: testo) { _ in rimanda() }
        // Cambiati da fuori (Eve, un ripristino): vale l'archivio
        .onChange(of: nota.titolo) { nuovo in if nuovo != titolo { titolo = nuovo } }
        .onChange(of: nota.testo) { nuovo in if nuovo != testo { testo = nuovo } }
        .onDisappear { scrittura.subito() }
        // Chiudendo Prisma entro l'attesa: si scrive e si salva di nuovo (niente, se non è cambiato nulla)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            guard scrittura.inAttesa else { return }
            scrittura.subito()
            stato.salvaOra()
        }
        HStack {
            Text("AGGIORNATA IL \(Formati.dataEstesa.string(from: nota.aggiornataIl).uppercased())").tracking(1)
            Spacer()
            Text("\(testo.count) caratteri")
        }
        .font(Tipo.notePiedePagina)
        .foregroundColor(Colori.Note.etichetta)
        .padding(.top, 11)
    }

    private func rimanda() {
        if nota.vuota {
            scrittura.subito()
            scrivi()
        } else {
            scrittura.dopo(AppNote.attesaNota) { scrivi() }
        }
    }

    /// Scrive titolo e testo di adesso (modificaNota non tocca nulla se sono già quelli dell'archivio).
    private func scrivi() {
        let nuovoTitolo = titolo, nuovoTesto = testo
        stato.modificaNota(nota.id) {
            $0.titolo = nuovoTitolo
            $0.testo = nuovoTesto
        }
    }
}

/// Rimanda un lavoro sul thread principale: una nuova richiesta prende il posto di quella in attesa, così
/// si fa solo l'ultima. Serve ai campi di testo che scrivono nello stato condiviso dopo l'ultimo tasto.
final class Rinvio {
    private var lavoro: DispatchWorkItem?
    private var azione: (() -> Void)?

    /// C'è un lavoro in attesa.
    var inAttesa: Bool { azione != nil }

    func dopo(_ secondi: Double, _ fai: @escaping () -> Void) {
        lavoro?.cancel()
        azione = fai
        let nuovo = DispatchWorkItem { [weak self] in self?.esegui() }
        lavoro = nuovo
        DispatchQueue.main.asyncAfter(deadline: .now() + secondi, execute: nuovo)
    }

    /// Fa adesso il lavoro in attesa, se c'è.
    func subito() {
        lavoro?.cancel()
        esegui()
    }

    private func esegui() {
        lavoro = nil
        let a = azione
        azione = nil
        a?()
    }
}

struct AzioneNuovaNota: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        Button("＋ Nuova nota") { stato.nuovaNota() }
            .buttonStyle(StileAqua())
    }
}
