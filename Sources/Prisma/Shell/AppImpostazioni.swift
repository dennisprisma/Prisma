import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// App Impostazioni: Esperienza, Archivio (backup e ripristino), Scorciatoie.
struct AppImpostazioni: View {
    @EnvironmentObject var stato: StatoShell
    @State var daRipristinare: VoceBackup?
    @State var fileDaRipristinare: URL?
    @State var confermaDatiProva = false
    @State var confermaTogliProva = false
    @State var modificaNome = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SchedeApp(opzioni: [(SchedaImpostazioni.esperienza, "Esperienza"), (SchedaImpostazioni.archivio, "Archivio"),
                                (SchedaImpostazioni.scorciatoie, "Scorciatoie")],
                      selezione: $stato.schedaImpostazioni)
                .padding(.bottom, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bordoBasso(Colori.Impostazioni.schedeBordo)
                .padding(.bottom, 8)
            GeometryReader { geo in
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        Group {
                            switch stato.schedaImpostazioni {
                            case .esperienza: esperienza
                            case .archivio: archivio
                            case .scorciatoie: scorciatoie
                            }
                        }
                        .padding(EdgeInsets(top: 2, leading: 2, bottom: 12, trailing: 2))
                    }
                    .frame(width: geo.size.width * (1 - Misure.Impostazioni.informazioniLarghezza))
                    informazioni
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, 30)
                }
            }
        }
        .padding(.top, 4)
        .alert("Ripristinare questo backup?", isPresented: Binding(get: { daRipristinare != nil || fileDaRipristinare != nil },
                                                                   set: { if !$0 { daRipristinare = nil; fileDaRipristinare = nil } })) {
            Button("Annulla", role: .cancel) {}
            Button("Ripristina", role: .destructive) {
                if let url = daRipristinare?.url ?? fileDaRipristinare { stato.ripristina(url) }
            }
        } message: {
            Text("I dati attuali verranno sostituiti da quelli del backup \"\(daRipristinare?.nome ?? fileDaRipristinare?.lastPathComponent ?? "")\". Prima del ripristino Prisma salva una copia di sicurezza dello stato attuale.")
        }
        .alert("Togliere i clienti di prova?", isPresented: $confermaTogliProva) {
            Button("Annulla", role: .cancel) {}
            Button("Togli i clienti di prova", role: .destructive) { stato.togliDatiDiProva() }
        } message: {
            Text("Giulia, Marco, Laura, Andrea e Sofia vengono tolti con posizioni, agenda, documenti e conversazioni. I tuoi clienti restano. Prima Prisma salva un backup dello stato attuale.")
        }
        .alert("Tornare ai dati di prova?", isPresented: $confermaDatiProva) {
            Button("Annulla", role: .cancel) {}
            Button("Ripristina i dati di prova", role: .destructive) { stato.ripristinaDatiDiProva() }
        } message: {
            Text("Clienti, agenda e attività tornano ai 5 clienti di prova. Prima Prisma salva un backup dello stato attuale.")
        }
    }

    // MARK: Esperienza

    private var esperienza: some View {
        VStack(alignment: .leading, spacing: Misure.Impostazioni.spazioGruppi) {
            gruppoProfilo
            gruppoEve
            gruppoVoce
            gruppoPDF
        }
    }

    private var gruppoEve: some View {
        let motivo = MotoriEve.motivoAppleNonDisponibile
        return GruppoImpostazioni(titolo: "Eve") {
            RigaImpostazione(titolo: "Chi risponde", sottotitolo: "Il modello Apple e Qwen lavorano sul Mac; la sintesi compone le risposte dai dati del dossier. Automatico: Apple, poi Qwen, poi la sintesi") {
                Picker("", selection: $stato.dati.impostazioni.eve.motore) {
                    ForEach(ImpostazioniEve.Motore.allCases) { m in Text(m.nome).tag(m) }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            RigaImpostazione(titolo: "Modello Apple", sottotitolo: motivo ?? "Pronto: Apple Intelligence è attiva su questo Mac",
                             avvertenza: motivo == nil ? nil : "Senza il modello Apple, Eve risponde agli spunti con la sintesi dai dati") {
                Text(motivo == nil ? "Disponibile" : "Non disponibile")
                    .font(Tipo.rigaValore)
                    .foregroundColor(Colori.Impostazioni.rigaTitolo)
            }
            RigaImpostazione(titolo: "Qwen sul Mac",
                             sottotitolo: stato.disponibilitaLocale.motivo ?? "Pronto: \(stato.dati.impostazioni.eve.modelloLocale) con Ollama, solo su questo Mac",
                             avvertenza: stato.disponibilitaLocale.pronto ? nil : "Facoltativo: serve l'app gratuita Ollama con il modello qwen3:4b (circa 2,5 GB di memoria mentre risponde)") {
                HStack(spacing: 8) {
                    TextField("qwen3:4b", text: $stato.dati.impostazioni.eve.modelloLocale)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                        .onSubmit { stato.verificaMotoreLocale() }
                    Button("Verifica") { stato.verificaMotoreLocale() }
                }
            }
            RigaImpostazione(titolo: "Conserva le conversazioni", sottotitolo: "Nel dossier del cliente, sul Mac e nei backup", ultima: true) {
                Toggle("", isOn: $stato.dati.impostazioni.eve.conservaConversazioni)
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
        }
    }

    /// La voce di Eve e la conversazione a voce: tutto sul Mac (sintesi e dettatura di macOS).
    private var gruppoVoce: some View {
        let voci = VoceEve.vociItaliane()
        let scelta: String = VoceEve.voce(stato.dati.impostazioni.eve.voce).map { " (ora " + VoceEve.nome($0) + ")" } ?? ""
        return GruppoImpostazioni(titolo: "Parlare con Eve") {
            RigaImpostazione(titolo: "Voce di Eve",
                             sottotitolo: "Automatica: la migliore voce femminile italiana installata" + scelta,
                             avvertenza: VoceEve.soloVociStandard
                                ? "Per una voce più naturale scarica «Federica (Premium)» in Impostazioni di Sistema › Accessibilità › Contenuti letti ad alta voce › Voce di sistema › Gestisci voci › Italiano"
                                : nil) {
                HStack(spacing: 8) {
                    Picker("", selection: $stato.dati.impostazioni.eve.voce) {
                        Text("Automatica").tag(String?.none)
                        ForEach(voci, id: \.identifier) { v in Text(VoceEve.nome(v)).tag(String?.some(v.identifier)) }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                    Button("Ascolta") { stato.provaVoce() }
                }
            }
            RigaImpostazione(titolo: "Velocità della voce", sottotitolo: "Al centro il ritmo naturale") {
                Slider(value: $stato.dati.impostazioni.eve.velocitaVoce, in: 0.7...1.4)
                    .frame(width: 170)
            }
            RigaImpostazione(titolo: "Risposte a voce", sottotitolo: "Il testo resta comunque scritto nella conversazione") {
                Picker("", selection: $stato.dati.impostazioni.eve.risposteAVoce) {
                    ForEach(ImpostazioniEve.RisposteAVoce.allCases) { r in Text(r.nome).tag(r) }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            RigaImpostazione(titolo: "Leggi tutta la risposta", sottotitolo: "Altrimenti Eve dice l'inizio e il resto lo trovi scritto") {
                Toggle("", isOn: $stato.dati.impostazioni.eve.leggiTutto)
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
            RigaImpostazione(titolo: "Riconoscimento della voce",
                             sottotitolo: "Sempre sul Mac. Automatico: quello nuovo di Apple su macOS 26 e successivi, altrimenti la dettatura classica") {
                Picker("", selection: $stato.dati.impostazioni.eve.riconoscimento) {
                    ForEach(SceltaRiconoscimento.allCases) { r in Text(r.nome).tag(r) }
                }
                .labelsHidden()
                .frame(width: 190)
            }
            RigaImpostazione(titolo: "Prova il riconoscimento",
                             sottotitolo: stato.esitoProvaRiconoscimento ?? "Senza microfono: Eve dice una frase e si vede se il riconoscimento la capisce. Poi «Copia» e mandami il risultato") {
                HStack(spacing: 8) {
                    Button("Prova") { stato.provaRiconoscimento() }
                        .disabled(stato.esitoProvaRiconoscimento == "In prova…")
                    Button("Copia") { stato.copiaDiagnosticaVoce() }
                }
            }
            RigaImpostazione(titolo: "Conversazione continua",
                             sottotitolo: "Dopo aver risposto Eve torna ad ascoltarti, finché non le dici «basta così» · ⌥⌘E per parlarle",
                             ultima: true) {
                Toggle("", isOn: $stato.dati.impostazioni.eve.conversazioneContinua)
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
        }
    }

    private var gruppoPDF: some View {
        GruppoImpostazioni(titolo: "PDF per i clienti") {
            RigaImpostazione(titolo: "Proponi la password", sottotitolo: "Salvando un prospetto o un report, la protezione è già attiva") {
                Toggle("", isOn: $stato.dati.impostazioni.pdf.proteggi)
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
            RigaImpostazione(titolo: "Password proposta", sottotitolo: "Dai dati del cliente; Prisma non conserva nessuna password", ultima: true) {
                Picker("", selection: $stato.dati.impostazioni.pdf.regola) {
                    ForEach(ImpostazioniPDF.Regola.allCases) { r in Text(r.nome).tag(r) }
                }
                .labelsHidden()
                .frame(width: 210)
            }
        }
    }

    private var gruppoProfilo: some View {
        GruppoImpostazioni {
            RigaImpostazione(titolo: "Il tuo nome", sottotitolo: "Come ti accoglie la scrivania") {
                ValoreRiga(testo: stato.nomeUtente) { modificaNome = true }
                    .popover(isPresented: $modificaNome, arrowEdge: .leading) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Il tuo nome").font(Tipo.rigaTitolo)
                            TextField("Nome", text: $stato.dati.impostazioni.nomeUtente)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                                .onSubmit { modificaNome = false }
                        }
                        .padding(14)
                    }
            }
            RigaImpostazione(titolo: "Dimensione del testo",
                             sottotitolo: "Testi e cifre di tutte le app; prospetti e report restano come sulla carta",
                             avvertenza: stato.dati.impostazioni.dimensioneTesto.fattore == Tipo.fattore ? nil : "Si applica riaprendo Prisma") {
                HStack(spacing: 8) {
                    Picker("", selection: $stato.dati.impostazioni.dimensioneTesto) {
                        ForEach(DimensioneTesto.allCases) { d in Text(d.nome).tag(d) }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    if stato.dati.impostazioni.dimensioneTesto.fattore != Tipo.fattore {
                        Button("Riapri ora") { stato.riapri() }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                    }
                }
            }
            RigaImpostazione(titolo: "Guida per cominciare", sottotitolo: "Sulla scrivania, finché i passi non sono fatti") {
                Toggle("", isOn: Binding(get: { !stato.dati.impostazioni.guidaNascosta }, set: { stato.dati.impostazioni.guidaNascosta = !$0 }))
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
            RigaImpostazione(titolo: "Schermo intero", sottotitolo: "Dedica tutto lo schermo a Prisma", ultima: true) {
                ValoreRiga(testo: stato.schermoIntero ? "Attivo" : "Attiva") { stato.alternaSchermoIntero() }
            }
        }
    }

    // MARK: Archivio

    private var archivio: some View {
        VStack(alignment: .leading, spacing: Misure.Impostazioni.spazioGruppi) {
            GruppoImpostazioni {
                RigaImpostazione(titolo: "Crea backup",
                                 sottotitolo: "Copia completa di clienti, agenda, posizioni, documenti e impostazioni di Eve") {
                    if stato.backupInCorso {
                        ProgressView().controlSize(.small)
                    }
                    Button("Crea backup") { stato.creaBackup() }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
                        .disabled(stato.backupInCorso)
                }
                RigaImpostazione(titolo: "Backup automatico settimanale", sottotitolo: testoAutomatico, avvertenza: avvertenzaBackup) {
                    Toggle("", isOn: $stato.dati.impostazioni.backup.automatico)
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
                RigaImpostazione(
                    titolo: "Cartella dei backup",
                    sottotitolo: Archivio.percorsoBreve(stato.cartellaBackup),
                    avvertenza: stato.cartellaBackupPredefinita
                        ? "I backup sono sullo stesso Mac: scegli una cartella di iCloud Drive o un disco esterno." : nil
                ) {
                    ValoreRiga(testo: "Scegli") { scegliCartella() }
                }
                RigaImpostazione(titolo: "Archivio di Prisma", sottotitolo: Archivio.percorsoBreve(Archivio.cartella), ultima: true) {
                    ValoreRiga(testo: "Mostra nel Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([Archivio.file])
                    }
                }
            }

            GruppoImpostazioni(titolo: "Backup disponibili · ultime \(GestoreBackup.massimo) copie") {
                if stato.elencoBackup.isEmpty {
                    RigaImpostazione(titolo: "Nessun backup ancora", sottotitolo: "Crea il primo con \"Crea backup\".") { EmptyView() }
                }
                ForEach(stato.elencoBackup) { voce in
                    RigaImpostazione(titolo: Formati.dataOra.string(from: voce.data),
                                     sottotitolo: "\(voce.nome) · \(Formati.dimensione(voce.dimensione))") {
                        ValoreRiga(testo: "Ripristina") { daRipristinare = voce }
                    }
                }
                RigaImpostazione(titolo: "Ripristina da un file…", sottotitolo: "Un backup di Prisma salvato altrove (.zip)", ultima: true) {
                    ValoreRiga(testo: "Scegli il file") { scegliFile() }
                }
            }

            Text("I dati restano su questo Mac. Non c'è nessuna sincronizzazione cloud: i backup vanno solo nella cartella che scegli tu.")
                .font(Tipo.informazioniTesto)
                .foregroundColor(Colori.Impostazioni.nota)
                .incisione(Colori.Impostazioni.notaIncisione)
                .padding(.horizontal, 4)

            HStack(spacing: 28) {
                numero(stato.clienti.count, "clienti")
                numero(stato.appuntamenti.count, "appuntamenti")
                numero(stato.attivita.count, "attività")
            }
            .padding(.horizontal, 4)

            if stato.copieNonLeggibili > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("All'avvio l'archivio non era leggibile: la copia è nella cartella di Prisma e i backup automatici sono fermi, per non sostituire i backup buoni. Ripristina un backup qui sotto oppure, se i dati di oggi vanno bene, riprendi i backup.")
                        .font(Tipo.informazioniTesto)
                        .foregroundColor(Colori.Analisi.erroreTesto)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Riprendi i backup automatici") { stato.riprendiBackupAutomatici() }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                }
                .padding(.horizontal, 4)
            }

            if stato.solaLettura {
                Text("Archivio in sola lettura: è stato salvato da una versione più recente di Prisma. Le modifiche non vengono salvate: apri l'ultima versione dell'app.")
                    .font(Tipo.informazioniTesto)
                    .foregroundColor(Colori.Analisi.erroreTesto)
                    .padding(.horizontal, 4)
            }

            GruppoImpostazioni(titolo: "Dati di prova") {
                if stato.haDatiDiProva {
                    RigaImpostazione(titolo: "Togli i 5 clienti di prova",
                                     sottotitolo: "Per lavorare solo con i tuoi clienti: restano i clienti che hai inserito tu. Prima viene salvato un backup.") {
                        ValoreRiga(testo: "Togli") { confermaTogliProva = true }
                    }
                }
                RigaImpostazione(titolo: "Ripristina i 5 clienti di prova",
                                 sottotitolo: "Utile per provare i motori di calcolo. Prima viene salvato un backup.", ultima: true) {
                    ValoreRiga(testo: "Ripristina") { confermaDatiProva = true }
                }
            }
        }
    }

    /// Backup non riusciti o fermi da più di 8 giorni: resta scritto finché il problema c'è.
    private var avvertenzaBackup: String? {
        let b = stato.dati.impostazioni.backup
        if let e = b.ultimoErrore {
            let quando = b.ultimoTentativo.map { " (\(Formati.dataOra.string(from: $0)))" } ?? ""
            return "Ultimo backup non riuscito\(quando): \(e)"
        }
        if b.inRitardo { return "Nessun backup riuscito negli ultimi 8 giorni: crea un backup a mano." }
        return nil
    }

    private var testoAutomatico: String {
        let b = stato.dati.impostazioni.backup
        guard b.automatico else { return "Disattivato: ricordati di creare i backup a mano." }
        let ultimo = b.ultimo.map { "Ultimo: \(Formati.dataOra.string(from: $0))" } ?? "Nessun backup ancora"
        let prossimo = b.prossimo.map { $0 <= Date() ? "il prossimo tra poco" : "prossimo: \(Formati.dataOra.string(from: $0))" } ?? ""
        return "\(ultimo) · \(prossimo)"
    }

    private func numero(_ n: Int, _ etichetta: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(n)").font(Tipo.numero).foregroundColor(Colori.Impostazioni.numero)
            Text(etichetta).font(Tipo.numeroEtichetta).foregroundColor(Colori.Impostazioni.numeroEtichetta)
        }
        .incisione(.white)
    }

    private func scegliCartella() {
        let pannello = NSOpenPanel()
        pannello.canChooseDirectories = true
        pannello.canChooseFiles = false
        pannello.canCreateDirectories = true
        pannello.allowsMultipleSelection = false
        pannello.prompt = "Usa questa cartella"
        pannello.message = "Scegli dove salvare i backup di Prisma (per esempio iCloud Drive o un disco esterno)."
        if pannello.runModal() == .OK, let url = pannello.url {
            stato.scegliCartellaBackup(url)
        }
    }

    private func scegliFile() {
        let pannello = NSOpenPanel()
        pannello.canChooseDirectories = false
        pannello.canChooseFiles = true
        pannello.allowsMultipleSelection = false
        pannello.allowedContentTypes = [.zip]
        pannello.prompt = "Ripristina"
        pannello.message = "Scegli un backup di Prisma."
        if pannello.runModal() == .OK, let url = pannello.url {
            fileDaRipristinare = url
        }
    }

    // MARK: Scorciatoie

    private var scorciatoie: some View {
        GruppoImpostazioni {
            RigaImpostazione(titolo: "Scrivania", sottotitolo: "Riduce tutte le finestre") { tasto("⌥ 0") }
            RigaImpostazione(titolo: "Parla con Eve", sottotitolo: "Eve ti ascolta; di nuovo per mandare subito la frase") { tasto("⌥ ⌘ E") }
            ForEach(Array(AppPrisma.allCases.prefix(9).enumerated()), id: \.element) { i, app in
                RigaImpostazione(titolo: app.titolo, sottotitolo: app.sottotitolo, ultima: i == 8) { tasto("⌥ \(i + 1)") }
            }
        }
    }

    private func tasto(_ t: String) -> some View {
        Text(t).font(Tipo.rigaValore).foregroundColor(Colori.Impostazioni.rigaValore)
    }

    // MARK: Informazioni

    private var informazioni: some View {
        VStack(alignment: .leading, spacing: 0) {
            ImmagineRisorsa(percorso: "Icone/Prisma.png")
                .frame(width: Misure.Impostazioni.iconaInformazioni, height: Misure.Impostazioni.iconaInformazioni)
                .padding(.bottom, 20)
            Text("CLASSIC EDITION")
                .font(Tipo.informazioniOcchiello)
                .tracking(1.8)
                .foregroundColor(Colori.Impostazioni.informazioniOcchiello)
                .padding(.bottom, 8)
            Text("Il tuo spazio.\nTutto a portata di mano.")
                .font(Tipo.informazioniTitolo)
                .foregroundColor(Colori.Impostazioni.informazioniTitolo)
                .padding(.bottom, 12)
            Text("Sedici app, un archivio locale e una scrivania che rimane sempre al suo posto.")
                .font(Tipo.informazioniTesto)
                .foregroundColor(Colori.Impostazioni.nota)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300, alignment: .leading)
                .padding(.bottom, 14)
            Text("Archivio locale · solo su questo Mac\nVersione \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")")
                .font(Tipo.informazioniPiccolo)
                .foregroundColor(Colori.Impostazioni.nota)
                .lineSpacing(3)
        }
        .incisione(.white)
        .padding(Misure.Impostazioni.informazioniMargine)
        .overlay(alignment: .leading) {
            Rectangle().fill(Colori.Impostazioni.informazioniFilo).frame(width: 1)
        }
    }
}

extension StatoShell {
    /// Salva e riapre Prisma (per la dimensione del testo, che si fissa all'avvio).
    @MainActor
    func riapri() {
        salvaOra()
        let configurazione = NSWorkspace.OpenConfiguration()
        configurazione.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configurazione) { _, errore in
            DispatchQueue.main.async {
                if errore == nil {
                    NSApp.terminate(nil)
                } else {
                    self.mostraAvviso("Non sono riuscito a riaprire Prisma: chiudilo e riaprilo tu.")
                }
            }
        }
    }
}
