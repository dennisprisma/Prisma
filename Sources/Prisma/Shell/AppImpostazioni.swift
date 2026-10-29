import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// App Impostazioni: Esperienza, Proposte (documenti da consegnare), Archivio (backup e ripristino), Riferimenti
/// (metri di confronto dei rendimenti), Scorciatoie.
struct AppImpostazioni: View {
    @EnvironmentObject var stato: StatoShell
    @State var daRipristinare: VoceBackup?
    @State var fileDaRipristinare: URL?
    @State var confermaDatiProva = false
    @State var confermaClientiCompleti = false
    @State var confermaTogliProva = false
    @State var modificaNome = false
    // Password dei backup
    @State var passwordRipristino = ""
    @State var nuovaPassword = ""
    @State var confermaPassword = ""
    @State var erroreNuovaPassword: String?
    @State var confermaTogliPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SchedeApp(opzioni: [(SchedaImpostazioni.esperienza, "Esperienza"), (SchedaImpostazioni.proposte, "Proposte"),
                                (SchedaImpostazioni.archivio, "Archivio"), (SchedaImpostazioni.riferimenti, "Riferimenti"),
                                (SchedaImpostazioni.scorciatoie, "Scorciatoie")],
                      selezione: $stato.schedaImpostazioni)
                .padding(.bottom, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bordoBasso(Colori.Impostazioni.schedeBordo)
                .padding(.bottom, 8)
            GeometryReader { geo in
                HStack(alignment: .top, spacing: 0) {
                    ScrollViewReader { lettore in
                        ScrollView {
                            Group {
                                switch stato.schedaImpostazioni {
                                case .esperienza: esperienza
                                case .proposte: ImpostazioniProposte()
                                case .archivio: archivio
                                case .riferimenti: ImpostazioniRiferimenti()
                                case .scorciatoie: scorciatoie
                                }
                            }
                            .padding(EdgeInsets(top: 2, leading: 2, bottom: 12, trailing: 2))
                        }
                        // Senza barra di scorrimento: i gruppi restano larghi uguali in tutte le schede
                        .scrollIndicators(.hidden)
                        .onAppear { scorri(lettore) }
                        .onChange(of: stato.ancoraImpostazioni) { _ in scorri(lettore) }
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
            Text("I clienti di prova (Giulia, Marco, Laura, Andrea, Sofia e quelli inventati) vengono tolti con posizioni, agenda, documenti e conversazioni. I tuoi clienti restano. Prima Prisma salva un backup dello stato attuale.")
        }
        .alert("Caricare i 35 clienti di prova?", isPresented: $confermaClientiCompleti) {
            Button("Annulla", role: .cancel) {}
            Button("Carica i clienti di prova", role: .destructive) { stato.ripristinaDatiDiProva(completi: true) }
        } message: {
            Text("Clienti, posizioni, agenda e attività vengono sostituiti da 35 clienti inventati. Prima Prisma salva un backup dello stato attuale: i tuoi dati si recuperano da lì.")
        }
        .alert("Tornare ai dati di prova?", isPresented: $confermaDatiProva) {
            Button("Annulla", role: .cancel) {}
            Button("Ripristina i dati di prova", role: .destructive) { stato.ripristinaDatiDiProva() }
        } message: {
            Text("Clienti, agenda e attività tornano ai 5 clienti di prova. Prima Prisma salva un backup dello stato attuale.")
        }
        // Backup protetto da ripristinare: la richiesta si chiude solo dai pulsanti, che leggono il file prima di chiuderla
        .alert("Backup protetto da password", isPresented: Binding(get: { stato.ripristinoDaSbloccare != nil }, set: { _ in })) {
            SecureField("Password", text: $passwordRipristino)
            Button("Annulla", role: .cancel) {
                passwordRipristino = ""
                stato.ripristinoDaSbloccare = nil
            }
            Button("Ripristina") {
                let password = passwordRipristino
                let url = stato.ripristinoDaSbloccare?.url
                passwordRipristino = ""
                stato.ripristinoDaSbloccare = nil
                if let url, !password.isEmpty { stato.ripristina(url, password: password) }
            }
        } message: {
            Text(stato.ripristinoDaSbloccare?.messaggio ?? "")
        }
        .alert("Togliere la password dai backup?", isPresented: $confermaTogliPassword) {
            Button("Annulla", role: .cancel) {}
            Button("Togli la password", role: .destructive) { stato.togliPasswordBackup() }
        } message: {
            Text("I prossimi backup non saranno protetti. Quelli già protetti restano protetti e si aprono solo con la loro password.")
        }
    }

    /// Porta in vista il gruppo chiesto (`"impostazioni-conformita"`, `"impostazioni-occasioni"`: dalle istantanee
    /// o da un rimando), poi dimentica l'ancora. Come `ancoraPosizioni` in Posizioni.
    private func scorri(_ lettore: ScrollViewProxy) {
        guard let ancora = stato.ancoraImpostazioni else { return }
        DispatchQueue.main.async {
            withAnimation(Animazioni.apertura) { lettore.scrollTo(ancora, anchor: .top) }
            stato.ancoraImpostazioni = nil
        }
    }

    /// I pulsanti di vetro nelle righe (come «Crea backup»).
    private var margineVetro: EdgeInsets { EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10) }

    // MARK: Esperienza

    private var esperienza: some View {
        VStack(alignment: .leading, spacing: Misure.Impostazioni.spazioGruppi) {
            gruppoAspetto
            gruppoProfilo
            gruppoOrari
            gruppoSeguito
            gruppoConformita
                .id("impostazioni-conformita")
            GruppoOccasioniImpostazioni()
                .id("impostazioni-occasioni")
            gruppoPromemoria
            gruppoEve
            gruppoVoce
            gruppoPDF
        }
    }

    /// Aspetto chiaro, scuro o come il Mac; lo sfondo d'acqua animato o fermo e quanta pioggia cade.
    /// Si salvano con le altre impostazioni e valgono subito.
    private var gruppoAspetto: some View {
        GruppoImpostazioni(titolo: "Aspetto") {
            RigaImpostazione(titolo: "Aspetto", sottotitolo: "Automatico segue il Mac, di giorno e di sera") {
                ControlloSegmenti(opzioni: AspettoInterfaccia.allCases.map { ($0, $0.nome) },
                                  selezione: $stato.dati.impostazioni.aspetto)
                    .fixedSize()
            }
            RigaImpostazione(titolo: "Sfondo", sottotitolo: "L'acqua della scrivania con le gocce al rallentatore; si ferma da sola quando non si vede") {
                ControlloSegmenti(opzioni: [(true, "Animato"), (false, "Fermo")],
                                  selezione: $stato.dati.impostazioni.sfondoAnimato)
                    .fixedSize()
            }
            RigaImpostazione(titolo: "Pioggia", sottotitolo: stato.dati.impostazioni.sfondoAnimato
                                ? "Quante gocce cadono sull'acqua"
                                : "Con lo sfondo fermo non piove", ultima: true) {
                ControlloSegmenti(opzioni: IntensitaPioggia.allCases.map { ($0, $0.nome) },
                                  selezione: $stato.dati.impostazioni.pioggia)
                    .fixedSize()
                    .disabled(!stato.dati.impostazioni.sfondoAnimato)
                    .opacity(stato.dati.impostazioni.sfondoAnimato ? 1 : Tema.Misura.Shell.opacitaDisabilitato)
            }
        }
    }

    /// Gli orari di lavoro: dove «Pianifica» (Agenda, Portafoglio, Prospetti) cerca lo spazio libero.
    private var gruppoOrari: some View {
        let orari = stato.dati.impostazioni.orari
        return GruppoImpostazioni(titolo: "Orari di lavoro") {
            RigaImpostazione(titolo: "Giorni di lavoro", sottotitolo: "«Pianifica» cerca lo spazio solo in questi giorni") {
                SceltaGiorniLavoro(giorni: $stato.dati.impostazioni.orari.giorni)
            }
            RigaImpostazione(titolo: "Mattina", sottotitolo: "Inizio e fine della prima fascia (anche orario continuato)") {
                sceltaFascia($stato.dati.impostazioni.orari.mattina)
            }
            RigaImpostazione(titolo: "Pomeriggio",
                             sottotitolo: orari.pomeriggioAttivo ? "Dopo la pausa pranzo" : "Spento: si lavora solo nella fascia del mattino") {
                HStack(spacing: Misure.RiesamiAgenda.spazioTesta) {
                    sceltaFascia($stato.dati.impostazioni.orari.pomeriggio)
                        .disabled(!orari.pomeriggioAttivo)
                        .opacity(orari.pomeriggioAttivo ? 1 : Tema.Misura.Shell.opacitaDisabilitato)
                    Toggle("", isOn: $stato.dati.impostazioni.orari.pomeriggioAttivo)
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
            }
            RigaImpostazione(titolo: "Margine tra gli appuntamenti", sottotitolo: "Tempo libero lasciato prima e dopo ogni appuntamento") {
                ControlloSegmenti(opzioni: AppImpostazioni.opzioniMargini,
                                  selezione: $stato.dati.impostazioni.orari.margineMinuti)
                    .fixedSize()
            }
            RigaImpostazione(titolo: "Riesami al giorno", sottotitolo: "Oltre, il riesame va al giorno dopo: ognuno chiede la sua preparazione") {
                ControlloSegmenti(opzioni: AppImpostazioni.opzioniRiesami,
                                  selezione: $stato.dati.impostazioni.orari.riesamiAlGiorno)
                    .fixedSize()
            }
            RigaImpostazione(titolo: "Festività nazionali",
                             sottotitolo: "Capodanno, Epifania, Pasqua e Pasquetta, 25 aprile, 1° maggio, 2 giugno, Ferragosto, 4 ottobre, Ognissanti, Immacolata, Natale e Santo Stefano",
                             ultima: true) {
                Toggle("", isOn: $stato.dati.impostazioni.orari.festivi)
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
        }
    }

    /// Inizio e fine di una fascia oraria (ogni mezz'ora dalle 7:00 alle 21:00). Se l'inizio va oltre la fine,
    /// la fine diventa inizio + 60 minuti, tagliata alle 21:00; la fine propone solo le ore dopo l'inizio.
    private func sceltaFascia(_ fascia: Binding<FasciaOraria>) -> some View {
        let ore = OrariLavoro.orariScelta
        let ultima = ore.last ?? 21 * 60
        let inizio = Binding<Int>(
            get: { fascia.wrappedValue.inizio },
            set: { nuovo in
                var f = fascia.wrappedValue
                f.inizio = nuovo
                if f.fine <= nuovo { f.fine = min(nuovo + 60, ultima) }
                fascia.wrappedValue = f
            }
        )
        // L'ultima ora resta solo come fine: una fascia ha sempre almeno mezz'ora
        let inizi = AppImpostazioni.opzioniOre(Array(ore.dropLast()), con: fascia.wrappedValue.inizio)
        let fini = AppImpostazioni.opzioniOre(ore.filter { $0 > fascia.wrappedValue.inizio }, con: fascia.wrappedValue.fine)
        return HStack(spacing: Misure.RiesamiAgenda.spazioOre) {
            MenuTendina(selezione: inizio, opzioni: inizi, larghezza: Misure.RiesamiAgenda.menuOra)
            Text("–")
                .font(Tema.Testo.corpo)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
            MenuTendina(selezione: fascia.fine, opzioni: fini, larghezza: Misure.RiesamiAgenda.menuOra)
        }
    }

    /// Le scelte del margine tra gli appuntamenti: «Nessuno», «10 min»…
    private static var opzioniMargini: [(Int, String)] {
        OrariLavoro.margini.map { m -> (Int, String) in
            let testo: String = m == 0 ? "Nessuno" : "\(m) min"
            return (m, testo)
        }
    }

    /// Le scelte dei riesami al giorno: «1», «2», «3», «Senza limite».
    private static var opzioniRiesami: [(Int, String)] {
        OrariLavoro.limitiRiesami.map { n -> (Int, String) in
            let testo: String = n == 0 ? "Senza limite" : String(n)
            return (n, testo)
        }
    }

    /// Le scelte dei giorni del seguito: «14 giorni», «21 giorni»…
    private static var opzioniGiorniSeguito: [(Int, String)] {
        Impostazioni.sceltaGiorniSeguito.map { g -> (Int, String) in (g, "\(g) giorni") }
    }

    /// Le ore del menu, con quella salvata anche se non è tra le scelte (un archivio scritto a mano): il menu
    /// mostra sempre il valore vero.
    private static func opzioniOre(_ ore: [Int], con attuale: Int) -> [(Int, String)] {
        let tutte = ore.contains(attuale) ? ore : (ore + [attuale]).sorted()
        return tutte.map { o -> (Int, String) in (o, OrariLavoro.testoOra(o)) }
    }

    /// Il seguito delle proposte: dopo quanti giorni una proposta presentata senza appuntamento torna da recuperare.
    private var gruppoSeguito: some View {
        GruppoImpostazioni(titolo: "Seguito delle proposte") {
            RigaImpostazione(titolo: "Proposte senza risposta",
                             sottotitolo: "Dopo quanti giorni una proposta presentata, senza appuntamento in agenda, torna tra le cose da recuperare (notifiche, scrivania, Portafoglio). Non è una regola di legge: è il tuo ritmo",
                             ultima: true) {
                MenuTendina(selezione: $stato.dati.impostazioni.giorniSeguitoProposte,
                            opzioni: AppImpostazioni.opzioniGiorniSeguito)
            }
        }
    }

    /// Le scadenze di conformità («In regola»): validità dei questionari di adeguatezza per canale, rinnovo
    /// dell'adeguata verifica per rischio, consenso commerciale, data dell'ultima informativa privacy.
    /// Sono valori di buona prassi: il consulente li allinea alle regole della compagnia e alle sue.
    private var gruppoConformita: some View {
        let regole = stato.dati.impostazioni.conformita
        return VStack(alignment: .leading, spacing: Tema.Misura.Conformita.spazioIntestazione) {
            GruppoImpostazioni(titolo: "Scadenze di conformità") {
                RigaImpostazione(titolo: "Questionario Alleanza", sottotitolo: "Validità del questionario di adeguatezza") {
                    MenuTendina(selezione: $stato.dati.impostazioni.conformita.mesiQuestionarioAlleanza,
                                opzioni: AppImpostazioni.opzioniMesi(AppImpostazioni.mesiQuestionario, con: regole.mesiQuestionarioAlleanza))
                }
                RigaImpostazione(titolo: "Questionario indipendente", sottotitolo: "Ogni quanto si aggiorna il profilo") {
                    MenuTendina(selezione: $stato.dati.impostazioni.conformita.mesiQuestionarioIndipendente,
                                opzioni: AppImpostazioni.opzioniMesi(AppImpostazioni.mesiQuestionario, con: regole.mesiQuestionarioIndipendente))
                }
                RigaImpostazione(titolo: "Adeguata verifica", sottotitolo: "Rinnovo per rischio: alto, medio, basso") {
                    HStack(spacing: Tema.Misura.Componenti.spazioTendina) {
                        etichettaRischio(RischioRiciclaggio.alto)
                        MenuTendina(selezione: $stato.dati.impostazioni.conformita.mesiVerificaAlto,
                                    opzioni: AppImpostazioni.opzioniMesi(AppImpostazioni.mesiVerificaAlto, con: regole.mesiVerificaAlto))
                        etichettaRischio(RischioRiciclaggio.medio)
                        MenuTendina(selezione: $stato.dati.impostazioni.conformita.mesiVerificaMedio,
                                    opzioni: AppImpostazioni.opzioniMesi(AppImpostazioni.mesiVerificaMedio, con: regole.mesiVerificaMedio))
                        etichettaRischio(RischioRiciclaggio.basso)
                        MenuTendina(selezione: $stato.dati.impostazioni.conformita.mesiVerificaBasso,
                                    opzioni: AppImpostazioni.opzioniMesi(AppImpostazioni.mesiVerificaBasso, con: regole.mesiVerificaBasso))
                    }
                }
                RigaImpostazione(titolo: "Anche sul canale indipendente", sottotitolo: "Se come consulente sei tenuto all'antiriciclaggio") {
                    Toggle("", isOn: $stato.dati.impostazioni.conformita.verificaIndipendente)
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
                RigaImpostazione(titolo: "Consenso commerciale", sottotitolo: "Ogni quanto riconfermarlo") {
                    MenuTendina(selezione: $stato.dati.impostazioni.conformita.mesiCommerciale,
                                opzioni: AppImpostazioni.opzioniMesi(AppImpostazioni.mesiCommerciale, con: regole.mesiCommerciale))
                }
                RigaImpostazione(titolo: "Informativa privacy aggiornata il", sottotitolo: "Chi l'ha firmata prima la riceve di nuovo", ultima: true) {
                    CampoDataFacoltativa(data: $stato.dati.impostazioni.conformita.informativaAggiornataIl,
                                         predefinita: Calendar.current.startOfDay(for: Date()))
                }
            }
            Text("Valori predefiniti di Prisma (buona prassi): allineali alle regole della compagnia e alle tue. Le scadenze compaiono in Clienti → «In regola», nelle notifiche, nel riesame e nella ricerca (conformita:scaduta).")
                .font(Tipo.informazioniTesto)
                .foregroundColor(Colori.Impostazioni.nota)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tema.Misura.Componenti.rientroTitoloGruppo)
        }
    }

    /// «Alto», «Medio», «Basso» davanti ai menu dell'adeguata verifica.
    private func etichettaRischio(_ r: RischioRiciclaggio) -> some View {
        Text(r.nome)
            .font(Tema.Testo.secondario)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
    }

    /// Le validità proposte, in mesi (0 = «Non scade», solo per il consenso commerciale).
    private static let mesiQuestionario = [12, 24, 36, 48, 60]
    private static let mesiVerificaAlto = [6, 12, 18]
    private static let mesiVerificaMedio = [12, 18, 24, 36]
    private static let mesiVerificaBasso = [24, 36, 48, 60]
    private static let mesiCommerciale = [0, 12, 24, 36]

    /// Le scelte di una validità («6 mesi», «1 anno», «Non scade»), con quella salvata anche se non è tra le
    /// scelte (un archivio scritto a mano): il menu mostra sempre il valore vero.
    private static func opzioniMesi(_ scelte: [Int], con attuale: Int) -> [(Int, String)] {
        let tutte = scelte.contains(attuale) ? scelte : (scelte + [attuale]).sorted()
        return tutte.map { m -> (Int, String) in
            let testo: String = m == 0 ? "Non scade" : TestiConformita.durata(m)
            return (m, testo)
        }
    }

    /// Promemoria nel Centro notifiche del Mac: spenti di partenza, il permesso di macOS si chiede
    /// solo accendendoli. Nei testi niente cifre: il nome del cliente (se scelto) e cosa fare.
    private var gruppoPromemoria: some View {
        let scelte = stato.dati.impostazioni.promemoria
        let negati = stato.permessoPromemoria == .negati
        let ora = "alle \(MotoreNotifiche.oraPromemoria):00"
        return GruppoImpostazioni(titolo: "Promemoria del Mac") {
            RigaImpostazione(titolo: "Promemoria nel Centro notifiche",
                             sottotitolo: scelte.attivi
                                ? "Attivi: arrivano anche a Prisma chiusa. Nei testi niente cifre dei clienti"
                                : "Appuntamenti, attività, scadenze delle polizze, occasioni e compleanni, anche a Prisma chiusa",
                             avvertenza: negati
                                ? "Non consentiti da macOS: attivali in Impostazioni di Sistema › Notifiche › Prisma" : nil) {
                HStack(spacing: 8) {
                    if negati {
                        Button("Apri Impostazioni di Sistema") { PromemoriaMac.apriImpostazioniDiSistema() }
                            .buttonStyle(StileVetro(margine: margineVetro))
                    }
                    Toggle("", isOn: Binding(get: { stato.dati.impostazioni.promemoria.attivi },
                                             set: { stato.attivaPromemoria($0) }))
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
            }
            Group {
                RigaImpostazione(titolo: "Appuntamenti", sottotitolo: "Prima dell'inizio, con il luogo") {
                    HStack(spacing: 8) {
                        MenuTendina(selezione: $stato.dati.impostazioni.promemoria.anticipoMinuti,
                                    opzioni: ImpostazioniPromemoria.anticipi.map { ($0, ImpostazioniPromemoria.nomeAnticipo($0) + " prima") },
                                    larghezza: 150)
                        Toggle("", isOn: $stato.dati.impostazioni.promemoria.appuntamenti)
                            .toggleStyle(StileInterruttore())
                            .labelsHidden()
                    }
                }
                RigaImpostazione(titolo: "Attività", sottotitolo: "La mattina del giorno di scadenza, \(ora)") {
                    Toggle("", isOn: $stato.dati.impostazioni.promemoria.attivita)
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
                RigaImpostazione(titolo: "Scadenze delle polizze", sottotitolo: "Posizioni in essere: 30 e 7 giorni prima e il giorno stesso, \(ora)") {
                    Toggle("", isOn: $stato.dati.impostazioni.promemoria.scadenze)
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
                RigaImpostazione(titolo: "Compleanni dei clienti", sottotitolo: "Il giorno stesso, \(ora)") {
                    Toggle("", isOn: $stato.dati.impostazioni.promemoria.compleanni)
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
                RigaImpostazione(titolo: "Occasioni",
                                 sottotitolo: "\(stato.dati.impostazioni.occasioni.anticipoGiorni) giorni prima e il giorno stesso, \(ora): penali finite, previdenza, famiglia, coperture") {
                    Toggle("", isOn: $stato.dati.impostazioni.promemoria.occasioni)
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
                RigaImpostazione(titolo: "Nomi dei clienti", sottotitolo: "Spento: il promemoria dice solo l'ora e cosa fare. In modalità cliente i banner non compaiono") {
                    Toggle("", isOn: $stato.dati.impostazioni.promemoria.nomiClienti)
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
                RigaImpostazione(titolo: "Prova", sottotitolo: "Manda subito un promemoria per vedere come arriva", ultima: true) {
                    Button("Prova") { stato.provaPromemoria() }
                        .buttonStyle(StileVetro(margine: margineVetro))
                        .disabled(negati)
                }
            }
            .disabled(!scelte.attivi)
            .opacity(scelte.attivi ? 1 : Tema.Misura.Shell.opacitaDisabilitato)
        }
    }

    private var gruppoEve: some View {
        GruppoImpostazioni(titolo: "Eve") {
            RigaImpostazione(titolo: "Qwen sul Mac",
                             sottotitolo: stato.disponibilitaLocale.motivo ?? "Pronto: \(stato.dati.impostazioni.eve.modelloLocale) con Ollama, solo su questo Mac",
                             avvertenza: stato.disponibilitaLocale.pronto ? nil : "Eve risponde solo con Qwen: serve l'app gratuita Ollama aperta, con il modello qwen3:4b (circa 2,5 GB di memoria mentre risponde)") {
                HStack(spacing: 8) {
                    TextField("qwen3:4b", text: $stato.dati.impostazioni.eve.modelloLocale)
                        .campoTesto()
                        .frame(width: 110)
                        .onSubmit { stato.verificaMotoreLocale() }
                    Button("Verifica") { stato.verificaMotoreLocale() }
                        .buttonStyle(StileVetro(margine: margineVetro))
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
                    MenuTendina(selezione: $stato.dati.impostazioni.eve.voce,
                                opzioni: [(String?.none, "Automatica")] + voci.map { (String?.some($0.identifier), VoceEve.nome($0)) },
                                larghezza: 190)
                    Button("Ascolta") { stato.provaVoce() }
                        .buttonStyle(StileVetro(margine: margineVetro))
                }
            }
            RigaImpostazione(titolo: "Velocità della voce", sottotitolo: "Al centro il ritmo naturale") {
                Slider(value: $stato.dati.impostazioni.eve.velocitaVoce, in: 0.7...1.4)
                    .frame(width: 170)
            }
            RigaImpostazione(titolo: "Risposte a voce", sottotitolo: "Il testo resta comunque scritto nella conversazione") {
                MenuTendina(selezione: $stato.dati.impostazioni.eve.risposteAVoce,
                            opzioni: ImpostazioniEve.RisposteAVoce.allCases.map { ($0, $0.nome) }, larghezza: 170)
            }
            RigaImpostazione(titolo: "Leggi tutta la risposta", sottotitolo: "Altrimenti Eve dice l'inizio e il resto lo trovi scritto") {
                Toggle("", isOn: $stato.dati.impostazioni.eve.leggiTutto)
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
            RigaImpostazione(titolo: "Riconoscimento della voce",
                             sottotitolo: "Sempre sul Mac. Automatico: quello nuovo di Apple su macOS 26 e successivi, altrimenti la dettatura classica") {
                MenuTendina(selezione: $stato.dati.impostazioni.eve.riconoscimento,
                            opzioni: SceltaRiconoscimento.allCases.map { ($0, $0.nome) }, larghezza: 190)
                .onChange(of: stato.dati.impostazioni.eve.riconoscimento) { _ in stato.azzeraRipieghiAscolto() }
            }
            RigaImpostazione(titolo: "Prova il microfono",
                             sottotitolo: stato.esitoProvaMicrofono ?? "Tre secondi di ascolto senza riconoscimento: dice se il microfono sente") {
                Button("Prova") { stato.provaMicrofono() }
                    .buttonStyle(StileVetro(margine: margineVetro))
                    .disabled(stato.esitoProvaMicrofono == "In prova… parla per tre secondi")
            }
            RigaImpostazione(titolo: "Prova il riconoscimento",
                             sottotitolo: stato.esitoProvaRiconoscimento ?? "Senza microfono: Eve dice una frase e la fa capire a ogni riconoscimento (nuovo, dettatura di sistema, classico). Poi «Copia» e mandami il risultato") {
                HStack(spacing: 8) {
                    Button("Prova") { stato.provaRiconoscimento() }
                        .buttonStyle(StileVetro(margine: margineVetro))
                        .disabled(stato.esitoProvaRiconoscimento == "In prova…")
                    Button("Copia") { stato.copiaDiagnosticaVoce() }
                        .buttonStyle(StileVetro(margine: margineVetro))
                }
            }
            RigaImpostazione(titolo: "Mostra i passaggi dell'ascolto",
                             sottotitolo: "Sotto il campo di Eve compare l'ultimo passaggio (preparazione, microfono, risultati, voce, dettatura): si vede dove si ferma") {
                Toggle("", isOn: $stato.dati.impostazioni.eve.mostraPassaggiVoce)
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
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
                MenuTendina(selezione: $stato.dati.impostazioni.pdf.regola,
                            opzioni: ImpostazioniPDF.Regola.allCases.map { ($0, $0.nome) }, larghezza: 210)
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
                            // Il nome entra nei documenti: passa all'archivio poco dopo l'ultimo tasto
                            TestoRinviato(testo: $stato.dati.impostazioni.nomeUtente, salvaOra: { stato.salvaOra() }) { bozza in
                                TextField("Nome", text: bozza)
                                    .campoTesto()
                                    .frame(width: 200)
                                    .onSubmit { modificaNome = false }
                            }
                        }
                        .padding(14)
                    }
            }
            RigaImpostazione(titolo: "Dimensione del testo",
                             sottotitolo: "Testi e cifre di tutte le app; prospetti e report restano come sulla carta",
                             avvertenza: stato.dati.impostazioni.dimensioneTesto.fattore == Tipo.fattore ? nil : "Si applica riaprendo Prisma") {
                HStack(spacing: 8) {
                    MenuTendina(selezione: $stato.dati.impostazioni.dimensioneTesto,
                                opzioni: DimensioneTesto.allCases.map { ($0, $0.nome) }, larghezza: 140)
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
                RigaImpostazione(titolo: "Proteggi i backup con una password",
                                 sottotitolo: testoProtezione,
                                 avvertenza: "Se dimentichi la password, i backup protetti non si possono più aprire") {
                    HStack(spacing: Tema.Misura.Componenti.spazioTendina) {
                        if stato.dati.impostazioni.backup.cifrato {
                            ValoreRiga(testo: "Cambia") { stato.chiediPasswordBackup = true }
                        }
                        Toggle("", isOn: Binding(get: { stato.dati.impostazioni.backup.cifrato },
                                                 set: { acceso in
                                                     if acceso { stato.chiediPasswordBackup = true } else { confermaTogliPassword = true }
                                                 }))
                            .toggleStyle(StileInterruttore())
                            .labelsHidden()
                    }
                    .popover(isPresented: $stato.chiediPasswordBackup, arrowEdge: .leading) { moduloPassword }
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
                                     sottotitolo: descrizione(voce)) {
                        ValoreRiga(testo: "Ripristina") { daRipristinare = voce }
                    }
                }
                RigaImpostazione(titolo: "Ripristina da un file…", sottotitolo: "Un backup di Prisma salvato altrove (.zip o, se protetto, .zip.cifrato)", ultima: true) {
                    ValoreRiga(testo: "Scegli il file") { scegliFile() }
                }
            }

            Text("I dati restano su questo Mac. Non c'è nessuna sincronizzazione cloud: i backup vanno solo nella cartella che scegli tu.")
                .font(Tipo.informazioniTesto)
                .foregroundColor(Colori.Impostazioni.nota)
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
                    RigaImpostazione(titolo: "Togli i clienti di prova",
                                     sottotitolo: "Per lavorare solo con i tuoi clienti: restano i clienti che hai inserito tu. Prima viene salvato un backup.") {
                        ValoreRiga(testo: "Togli") { confermaTogliProva = true }
                    }
                }
                RigaImpostazione(titolo: "Ripristina i 5 clienti di prova",
                                 sottotitolo: "Utile per provare i motori di calcolo. Prima viene salvato un backup.") {
                    ValoreRiga(testo: "Ripristina") { confermaDatiProva = true }
                }
                RigaImpostazione(titolo: "Carica 35 clienti di prova completi",
                                 sottotitolo: "I 5 del template più 30 clienti inventati, con polizze Alleanza, investimenti, famiglia, agenda e note: per vedere Prisma piena e fare domande a Eve. Prima viene salvato un backup.",
                                 ultima: true) {
                    ValoreRiga(testo: "Carica") { confermaClientiCompleti = true }
                }
            }
        }
    }

    private var testoProtezione: String {
        stato.dati.impostazioni.backup.cifrato
            ? "Attiva: i nuovi backup si aprono solo con la password (cifratura AES-256); la password è nel Portachiavi del Mac"
            : "Facoltativa: i file dei backup si aprono solo con la password, anche su iCloud Drive o su un disco esterno"
    }

    /// Nome e dimensione di un backup dell'elenco, con «protetto» se ha la password.
    private func descrizione(_ voce: VoceBackup) -> String {
        let base = "\(voce.nome) · \(Formati.dimensione(voce.dimensione))"
        return voce.cifrato ? base + " · protetto" : base
    }

    /// Imposta o cambia la password dei backup: due campi, la conferma e l'avvertenza.
    private var moduloPassword: some View {
        let protetti = stato.dati.impostazioni.backup.cifrato
        return VStack(alignment: .leading, spacing: Tema.Misura.Componenti.spazioTendina) {
            Text(protetti ? "Nuova password dei backup" : "Password dei backup")
                .font(Tema.Testo.titolo)
                .foregroundColor(Tema.Colore.inchiostro)
            SecureField("Password (almeno \(ImpostazioniBackup.lunghezzaMinimaPassword) caratteri)", text: $nuovaPassword)
                .campoTesto()
            SecureField("Ripeti la password", text: $confermaPassword)
                .campoTesto()
                .onSubmit { salvaPassword() }
            Text(erroreNuovaPassword ?? "Se dimentichi la password, i backup protetti non si possono più aprire: conservala in un posto sicuro. Vale dai prossimi backup; quelli già fatti si aprono con la password di allora.")
                .font(Tema.Testo.secondario)
                .foregroundColor(erroreNuovaPassword == nil ? Tema.Colore.inchiostroSecondario : Tema.Colore.scadenzaOra)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tema.Misura.Componenti.spazioTendina) {
                Spacer(minLength: 0)
                Button("Annulla") { stato.chiediPasswordBackup = false }
                    .buttonStyle(StileVetro(margine: margineVetro))
                Button("Salva") { salvaPassword() }
                    .buttonStyle(StileBlu())
            }
        }
        .padding(Tema.Misura.Componenti.margineRiga)
        .frame(width: Tema.Misura.popoverLarghezza)
        .onDisappear {
            nuovaPassword = ""
            confermaPassword = ""
            erroreNuovaPassword = nil
        }
    }

    private func salvaPassword() {
        let minimo = ImpostazioniBackup.lunghezzaMinimaPassword
        guard nuovaPassword.count >= minimo else {
            erroreNuovaPassword = "Servono almeno \(minimo) caratteri."
            return
        }
        guard nuovaPassword == confermaPassword else {
            erroreNuovaPassword = "Le due password non coincidono."
            return
        }
        if stato.impostaPasswordBackup(nuovaPassword) {
            stato.chiediPasswordBackup = false
        } else {
            erroreNuovaPassword = "Il Portachiavi del Mac non ha salvato la password: riprova."
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
        // Anche i backup protetti («… .zip.cifrato»): il ripristino li riconosce dal contenuto
        var tipi: [UTType] = [.zip]
        if let protetto = UTType(filenameExtension: GestoreBackup.estensioneCifrata) { tipi.append(protetto) }
        pannello.allowedContentTypes = tipi
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
            LogoPrismaConNome(colore: Tema.Colore.logo, altezza: Tema.Misura.Shell.logoImpostazioni)
                .padding(.bottom, 20)
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
        .padding(Misure.Impostazioni.informazioniMargine)
        .overlay(alignment: .leading) {
            Rectangle().fill(Colori.Impostazioni.informazioniFilo).frame(width: Tema.Misura.filo)
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
