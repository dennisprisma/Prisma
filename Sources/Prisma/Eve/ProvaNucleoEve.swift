import Foundation

/// Prove del nucleo di Eve dentro `--prova-eve`: corpi delle richieste, lettura dello streaming dei due
/// fornitori, scelta della modalità, contesto a strati e storia, indirizzi solo locali, impostazioni di prima,
/// confronto tra modelli. Le risposte vere arrivano da un server Ollama finto dentro il processo (ServerFinto):
/// niente rete, niente modello.
enum ProvaNucleoEve {
    static func esegui(_ controlla: (Bool, String) -> Void) {
        indirizzi(controlla)
        corpi(controlla)
        letture(controlla)
        modalita(controlla)
        contesto(controlla)
        impostazioni(controlla)
        serverFinto(controlla)
        ponte(controlla)
    }

    /// Aspetta un lavoro asincrono dal thread delle prove.
    private static func aspetta<T>(_ lavoro: @escaping () async -> T) -> T {
        let scatola = ScatolaProva<T>()
        let fatto = DispatchSemaphore(value: 0)
        Task.detached {
            scatola.valore = await lavoro()
            fatto.signal()
        }
        fatto.wait()
        return scatola.valore!
    }

    // MARK: - Indirizzi

    private static func indirizzi(_ controlla: (Bool, String) -> Void) {
        let locali: [Bool] = ["http://127.0.0.1:11434", "http://localhost:11434", "http://[::1]:8080", "http://192.168.1.20:11434",
                              "https://ollama.example.com", "ftp://127.0.0.1:11434", "http://127.0.0.1.example.com"]
            .map { IndirizzoLocale.url($0) != nil }
        controlla(locali == [true, true, true, false, false, false, false], "Eve: solo indirizzi del Mac stesso (127.0.0.1, localhost, ::1)")
        let messaggi = [MessaggioModello(ruolo: .utente, testo: "ciao")]
        let ollamaFuori = (try? FornitoreOllama(indirizzo: "http://10.0.0.5:11434", modello: "qwen3.5:4b").richiesta(messaggi, opzioni: OpzioniModello())) == nil
        let openAIFuori = (try? FornitoreCompatibileOpenAI(indirizzo: "https://api.example.com", modello: "x").richiesta(messaggi, opzioni: OpzioniModello())) == nil
        controlla(ollamaFuori && openAIFuori, "Eve: nessuna richiesta verso un altro computer, con entrambi i fornitori")
        var lontano = ImpostazioniEve()
        lontano.indirizzoLocale = "http://10.0.0.5:11434"
        var lontanoOpenAI = ImpostazioniEve()
        lontanoOpenAI.fornitore = .compatibileOpenAI
        lontanoOpenAI.indirizzoCompatibile = "http://192.168.0.9:1234"
        let (fuori1, fuori2) = (lontano, lontanoOpenAI)
        let (d1, d2) = aspetta { (await MotoreLocale.verifica(fuori1), await MotoreLocale.verifica(fuori2)) }
        controlla(!d1.pronto && (d1.motivo ?? "").contains("127.0.0.1") && !d2.pronto && (d2.motivo ?? "").contains("127.0.0.1"),
                  "Eve: un indirizzo di un altro computer è rifiutato senza collegarsi")
        let qui = aspetta { await MotoreLocale.verifica(ImpostazioniEve()) }
        print("INFO Modello sul Mac (Ollama) su questo server: \(qui.motivo ?? "pronto")")
    }

    // MARK: - Corpi delle richieste

    private static func corpi(_ controlla: (Bool, String) -> Void) {
        let messaggi = [MessaggioModello(ruolo: .sistema, testo: "istruzioni"), MessaggioModello(ruolo: .utente, testo: "domanda")]
        var o = OpzioniModello()
        o.restaInMemoria = "10m"
        let c = FornitoreOllama.corpo(modello: "qwen3.5:4b", messaggi: messaggi, opzioni: o)
        let ruoli = (c["messages"] as? [[String: String]])?.map { $0["role"] ?? "" } ?? []
        let opzioni = c["options"] as? [String: Any] ?? [:]
        controlla((c["stream"] as? Bool) == true && (c["think"] as? Bool) == false && (c["keep_alive"] as? String) == "10m"
                  && ruoli == ["system", "user"] && (opzioni["num_ctx"] as? Int) == 8_192 && c["tools"] == nil,
                  "Ollama: /api/chat in streaming, senza ragionamento, keep_alive e finestra")
        o.pensa = true
        o.strumenti = [StrumentoModello(nome: "apri_sezione", descrizione: "Apre una sezione di Prisma",
                                        parametri: ["type": "object", "properties": ["sezione": ["type": "string"]]])]
        let c2 = FornitoreOllama.corpo(modello: "qwen3.5:4b", messaggi: messaggi, opzioni: o)
        let strumento = ((c2["tools"] as? [[String: Any]])?.first?["function"] as? [String: Any])?["name"] as? String
        controlla((c2["think"] as? Bool) == true && strumento == "apri_sezione", "Ollama: ragionamento attivabile e strumenti (tools)")
        let c3 = FornitoreCompatibileOpenAI.corpo(modello: "qwen3.5-4b", messaggi: messaggi, opzioni: o)
        let pensa = (c3["chat_template_kwargs"] as? [String: Any])?["enable_thinking"] as? Bool
        controlla((c3["stream"] as? Bool) == true && pensa == true && (c3["stream_options"] as? [String: Any])?["include_usage"] as? Bool == true
                  && (c3["tools"] as? [[String: Any]])?.count == 1,
                  "OpenAI compatibile: /v1/chat/completions in streaming, ragionamento e strumenti")
        let r = try? FornitoreCompatibileOpenAI(indirizzo: "http://127.0.0.1:8080", modello: "m").richiesta(messaggi, opzioni: o)
        controlla(r?.url?.absoluteString == "http://127.0.0.1:8080/v1/chat/completions" && r?.httpMethod == "POST",
                  "OpenAI compatibile: indirizzo della richiesta")
    }

    // MARK: - Lettura dello streaming

    private static func letture(_ controlla: (Bool, String) -> Void) {
        var l = FornitoreOllama.Lettore()
        var testo = "", pensiero = ""
        var statistiche: StatisticheModello?
        var strumenti: [String] = []
        let righe = [
            #"{"message":{"role":"assistant","content":"","thinking":"Vediamo"},"done":false}"#,
            #"{"message":{"role":"assistant","content":"Ciao "},"done":false}"#,
            "",
            #"{"message":{"role":"assistant","content":"Denis.","tool_calls":[{"function":{"name":"cerca_clienti","arguments":{"nome":"Giulia"}}}]},"done":false}"#,
            #"{"message":{"role":"assistant","content":""},"done":true,"prompt_eval_count":120,"eval_count":40,"eval_duration":2000000000}"#,
        ]
        for riga in righe {
            for p in (try? l.leggi(riga)) ?? [] {
                switch p {
                case .testo(let t): testo += t
                case .ragionamento(let t): pensiero += t
                case .strumento(let s): strumenti.append(s.nome + ":" + ((s.argomenti["nome"] as? String) ?? ""))
                case .fine(let s): statistiche = s
                }
            }
        }
        controlla(testo == "Ciao Denis." && pensiero == "Vediamo" && strumenti == ["cerca_clienti:Giulia"]
                  && statistiche?.tokenRisposta == 40 && statistiche?.tokenAlSecondo == 20,
                  "Ollama: streaming letto (testo, ragionamento a parte, strumenti, conteggi)")
        var erroreLetto = false
        do { _ = try l.leggi(#"{"error":"model 'x' not found"}"#) } catch { erroreLetto = error.localizedDescription.contains("not found") }
        controlla(erroreLetto, "Ollama: un errore a metà flusso diventa un messaggio")

        var o = FornitoreCompatibileOpenAI.Lettore()
        testo = ""; pensiero = ""; strumenti = []; statistiche = nil
        let sse = [
            #"data: {"choices":[{"delta":{"role":"assistant","reasoning_content":"Penso"}}]}"#,
            "",
            #"data: {"choices":[{"delta":{"content":"Buon"}}]}"#,
            ": commento del server",
            #"data: {"choices":[{"delta":{"content":"giorno"}}]}"#,
            #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"crea_appuntamento","arguments":"{\"ora\":"}}]}}]}"#,
            #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"15:00\"}"}}]}}]}"#,
            #"data: {"choices":[],"usage":{"prompt_tokens":50,"completion_tokens":7}}"#,
            "data: [DONE]",
        ]
        var pezzi: [PezzoModello] = []
        for riga in sse { pezzi += (try? o.leggi(riga)) ?? [] }
        pezzi += o.fine()
        for p in pezzi {
            switch p {
            case .testo(let t): testo += t
            case .ragionamento(let t): pensiero += t
            case .strumento(let s): strumenti.append(s.nome + ":" + ((s.argomenti["ora"] as? String) ?? ""))
            case .fine(let s): statistiche = s
            }
        }
        controlla(testo == "Buongiorno" && pensiero == "Penso" && strumenti == ["crea_appuntamento:15:00"] && statistiche?.tokenRisposta == 7,
                  "OpenAI compatibile: SSE letto (testo, ragionamento, strumento a pezzi, conteggi, [DONE] una volta sola)")

        // Il ragionamento tra <think> e </think> nel testo, anche con i segni spezzati tra due pezzi
        var f = FiltroPensiero()
        var visibile = "", nascosto = ""
        for pezzo in ["<thi", "nk>ragiono", " a lungo</th", "ink>\nEcco", " la risposta <", "b>"] {
            let r = f.filtra(pezzo)
            visibile += r.testo
            nascosto += r.ragionamento
        }
        visibile += f.filtra("").testo
        controlla(visibile == "\nEcco la risposta <b>" && nascosto == "ragiono a lungo", "Eve: il ragionamento non entra nel testo visibile")
        controlla(NucleoEve.pulisci("<think>x</think>\n**Ciao**, tutto bene.") == "Ciao, tutto bene.", "Eve: risposta senza ragionamento e senza grassetti")
    }

    // MARK: - Modalità

    private static func modalita(_ controlla: (Bool, String) -> Void) {
        let stato = StatoShell(persistente: false)
        guard let f = stato.fonteEve("giulia") else { return controlla(false, "Eve: fonte di Giulia") }
        let nome = f.cliente.nome.split(separator: " ").first.map(String.init) ?? f.cliente.nome
        func m(_ domanda: String, spunto: SpuntoEve? = nil, storia: [MessaggioEve] = []) -> ModalitaEve {
            NucleoEve.modalita(domanda: domanda, spunto: spunto, cliente: f.cliente, storia: storia)
        }
        let casi: [(String, ModalitaEve)] = [
            ("Quanto pesano i costi?", .lavoro),
            ("Come sta andando il portafoglio di \(nome)?", .lavoro),
            ("Le sue posizioni sono coerenti con il profilo?", .lavoro),
            ("Cosa proporre per la pensione?", .lavoro),
            ("Cos'è l'inflazione, in parole semplici?", .conversazione),
            ("Come funziona in generale un fondo pensione?", .conversazione),
            ("Scrivimi una mail per augurare buon Natale ai clienti", .conversazione),
            ("Che tempo fa di solito a Lisbona in novembre?", .conversazione),
            ("Riassumi questo testo: la riunione è spostata a lunedì.", .conversazione),
            ("Scrivi una mail a \(nome) per ricordarle l'incontro", .lavoro),
        ]
        let sbagliati = casi.filter { m($0.0) != $0.1 }.map { $0.0 }
        controlla(sbagliati.isEmpty, "Eve: modalità scelta dalla domanda (\(casi.count) casi\(sbagliati.isEmpty ? "" : ", sbagliati: " + sbagliati.joined(separator: " | ")))")
        controlla(m("Ciao!", spunto: .riepilogo) == .lavoro, "Eve: uno spunto è sempre lavoro")
        var risposta = MessaggioEve(autore: .eve, testo: "La protezione è scoperta.")
        risposta.modalita = .lavoro
        controlla(m("E per i figli?", storia: [MessaggioEve(autore: .utente, testo: "Dove è scoperta la protezione?"), risposta]) == .lavoro
                  && m("E per i figli?") == .conversazione, "Eve: una domanda breve di seguito resta nella modalità di prima")
        controlla(NucleoEve.vuolePensare("Pensaci bene: conviene riscattare?") && NucleoEve.vuolePensare("Quali sono i pro e contro del TFR in azienda?")
                  && !NucleoEve.vuolePensare("Quanto pesano i costi?") && !NucleoEve.vuolePensare("Ciao Eve"),
                  "Eve: ragiona sulle domande difficili o se le dici «pensaci bene»")
        let r = RichiestaEve(domanda: "Quanto pesano i costi?", spunto: nil, fonte: f, storia: [])
        controlla(NucleoEve.scegli(r, ragionamento: .sempre).pensa && !NucleoEve.scegli(RichiestaEve(domanda: "pensaci bene", spunto: nil, fonte: f, storia: []), ragionamento: .mai).pensa,
                  "Eve: il ragionamento si può forzare dalle impostazioni")
    }

    // MARK: - Contesto a strati e storia

    private static func contesto(_ controlla: (Bool, String) -> Void) {
        let stato = StatoShell(persistente: false)
        guard let f = stato.fonteEve("giulia") else { return controlla(false, "Eve: fonte di Giulia") }
        let ambiente = AmbienteEve(oggi: Date(), appAperte: ["Clienti", "Eve"], cliente: f.cliente.nome)
        let eve = ImpostazioniEve()
        let lavoro = NucleoEve.piano(RichiestaEve(domanda: "Quanto pesano i costi?", spunto: nil, fonte: f, storia: []), impostazioni: eve, ambiente: ambiente)
        let chiacchiera = NucleoEve.piano(RichiestaEve(domanda: "Cos'è l'inflazione?", spunto: nil, fonte: f, storia: []), impostazioni: eve, ambiente: ambiente)
        let ultimoLavoro = lavoro.messaggi.last?.testo ?? ""
        let ultimoChiacchiera = chiacchiera.messaggi.last?.testo ?? ""
        controlla(lavoro.messaggi.first?.ruolo == .sistema && lavoro.messaggi.first?.testo == IstruzioniEve.chat
                  && chiacchiera.messaggi.first?.testo == IstruzioniEve.conversazione,
                  "Eve: istruzioni fisse in testa, per modalità (Ollama le tiene in cache)")
        controlla(ultimoLavoro.hasPrefix("CONTESTO: ") && ultimoLavoro.contains("cliente attivo: \(f.cliente.nome)") && ultimoLavoro.contains("app aperte in Prisma: Clienti, Eve")
                  && ultimoLavoro.contains("SCHEDA DEL CLIENTE") && ultimoLavoro.contains("CALCOLI DI PRISMA PERTINENTI"),
                  "Eve: in lavoro la riga di contesto, la scheda e i calcoli di Prisma")
        controlla(ultimoChiacchiera.hasPrefix("CONTESTO: ") && !ultimoChiacchiera.contains("SCHEDA DEL CLIENTE") && ultimoChiacchiera.hasSuffix("Cos'è l'inflazione?"),
                  "Eve: in conversazione niente scheda del cliente")
        controlla(lavoro.opzioni.temperatura == 0.3 && chiacchiera.opzioni.temperatura == 0.7 && !chiacchiera.opzioni.pensa
                  && chiacchiera.opzioni.restaInMemoria == MotoreLocale.restaInMemoria,
                  "Eve: temperatura 0,3 in lavoro e 0,7 in conversazione")
        let spunto = NucleoEve.piano(RichiestaEve(domanda: SpuntoEve.riepilogo.domanda, spunto: .riepilogo, fonte: f, storia: []), impostazioni: eve, ambiente: ambiente)
        controlla((spunto.messaggi.last?.testo ?? "").contains("BOZZA PREPARATA DA PRISMA"), "Eve: gli spunti portano la bozza di Prisma")

        // Storia: molte battute brevi entrano tutte (oggi più di 4), quelle lunghe si fermano al budget
        var brevi: [MessaggioEve] = []
        for i in 0..<12 {
            brevi.append(MessaggioEve(autore: .utente, testo: "Domanda \(i)"))
            brevi.append(MessaggioEve(autore: .eve, testo: "Risposta \(i) " + String(repeating: "parola ", count: 80)))
        }
        let s1 = NucleoEve.storia(brevi, budget: 6_000)
        controlla(s1.count == 24 && s1.first?.ruolo == .utente && s1.last?.testo.hasPrefix("Risposta 11") == true,
                  "Eve: la storia tiene molte battute, in ordine (\(s1.count))")
        var lunghe: [MessaggioEve] = []
        for i in 0..<40 {
            lunghe.append(MessaggioEve(autore: i % 2 == 0 ? .utente : .eve, testo: "Battuta \(i) " + String(repeating: "x", count: 3_000)))
        }
        let budget = 3_000
        let s2 = NucleoEve.storia(lunghe, budget: budget)
        let usati = s2.reduce(0) { $0 + NucleoEve.token($1.testo) + 4 }
        controlla(!s2.isEmpty && usati <= budget && s2.first?.ruolo == .utente && s2.last?.testo.hasPrefix("Battuta 39") == true,
                  "Eve: la storia resta nel budget di token (\(usati) su \(budget)) e comincia con una domanda")
        var avviso = MessaggioEve(autore: .eve, testo: "Ollama non è aperto.", titolo: "Qwen non è pronto", motore: "Prisma")
        avviso.modalita = nil
        let s3 = NucleoEve.storia([MessaggioEve(autore: .utente, testo: "Ciao"), avviso], budget: 1_000)
        controlla(s3.count == 1, "Eve: gli avvisi di Prisma restano fuori dalla storia")
        let pieno = NucleoEve.piano(RichiestaEve(domanda: "E quindi?", spunto: nil, fonte: f, storia: lunghe), impostazioni: eve, ambiente: ambiente)
        let totale = pieno.messaggi.reduce(0) { $0 + NucleoEve.token($1.testo) + 4 }
        controlla(totale <= NucleoEve.finestra - NucleoEve.riservaRisposta, "Eve: istruzioni, storia e domanda stanno nella finestra (\(totale) token su \(NucleoEve.finestra))")
    }

    // MARK: - Impostazioni

    private static func impostazioni(_ controlla: (Bool, String) -> Void) {
        let vecchie = (try? JSONDecoder().decode(ImpostazioniEve.self, from: Data(#"{"motore":"apple","modelloLocale":"qwen3:4b"}"#.utf8))) ?? ImpostazioniEve()
        controlla(vecchie.modelloLocale == MotoreLocale.modelloPredefinito && vecchie.indirizzoLocale == "http://127.0.0.1:11434"
                  && vecchie.fornitore == .ollama && vecchie.ragionamento == .automatico && vecchie.prontaAllAvvio
                  && vecchie.restaInMemoria == MotoreLocale.restaInMemoria,
                  "Eve: impostazioni di prima lette con i valori nuovi (qwen3:4b → \(MotoreLocale.modelloPredefinito))")
        let scelto = (try? JSONDecoder().decode(ImpostazioniEve.self, from: Data(#"{"modelloLocale":"gemma4:e4b","fornitore":"sconosciuto","ragionamento":9}"#.utf8))) ?? ImpostazioniEve()
        controlla(scelto.modelloLocale == "gemma4:e4b" && scelto.fornitore == .ollama && scelto.ragionamento == .automatico,
                  "Eve: un modello scelto a mano resta; valori sconosciuti tornano ai predefiniti")
        var nuove = ImpostazioniEve()
        nuove.fornitore = .compatibileOpenAI
        nuove.modello = "qwen3.5-4b-mlx"
        nuove.indirizzo = "http://127.0.0.1:1234"
        nuove.ragionamento = .sempre
        let riletti = (try? JSONEncoder().encode(nuove)).flatMap { try? JSONDecoder().decode(ImpostazioniEve.self, from: $0) }
        controlla(riletti == nuove && riletti?.modelloCompatibile == "qwen3.5-4b-mlx" && riletti?.modelloLocale == MotoreLocale.modelloPredefinito,
                  "Eve: fornitore, indirizzo, modello e ragionamento salvati e riletti")
        controlla(MotoreLocale.nome("qwen3.5:4b") == "Qwen sul Mac" && MotoreLocale.nome("gemma4:e4b") == "Gemma sul Mac", "Eve: il nome del motore dal modello")
        controlla(ConfrontoModelli.elenco(" qwen3.5:4b, qwen3:8b;gemma4:e4b, QWEN3:8B ,") == ["qwen3.5:4b", "qwen3:8b", "gemma4:e4b"],
                  "Confronto: i modelli scritti nelle impostazioni")
        let sceltoPronto = MotoriEve.generativo(ImpostazioniEve(), locale: .pronto)?.nome ?? ""
        controlla(sceltoPronto == "Qwen sul Mac" && MotoriEve.generativo(ImpostazioniEve(), locale: .nonDisponibile("no")) == nil,
                  "Eve: il modello sul Mac è l'unico motore, se è pronto")
        // Senza il modello Eve non risponde con i calcoli: dice che non è pronto
        let spento = StatoShell(persistente: false)
        spento.disponibilitaLocale = .nonDisponibile("Ollama non è aperto.")
        spento.qwenNonPronto(cliente: spento.clienteAttivoId)
        let avviso = spento.conversazione(spento.clienteAttivoId).last
        controlla(avviso?.titolo == "Qwen non è pronto" && (avviso?.testo ?? "").hasPrefix("Ollama non è aperto."), "Eve: modello spento, Eve lo dice con il motivo")
        // Un messaggio con la modalità si salva e si rilegge; uno di prima si legge senza
        var m = MessaggioEve(autore: .eve, testo: "ok")
        m.modalita = .conversazione
        let mRiletto = (try? JSONEncoder().encode(m)).flatMap { try? JSONDecoder().decode(MessaggioEve.self, from: $0) }
        let mVecchio = try? JSONDecoder().decode(MessaggioEve.self, from: Data(#"{"id":"msg-1","autore":"eve","testo":"ciao"}"#.utf8))
        controlla(mRiletto?.modalita == .conversazione && mVecchio != nil && mVecchio?.modalita == nil, "Eve: la modalità dei messaggi nell'archivio")
    }

    // MARK: - Server finto

    private static func serverFinto(_ controlla: (Bool, String) -> Void) {
        let configurazione = URLSessionConfiguration.ephemeral
        configurazione.protocolClasses = [ServerFinto.self]
        let sessione = URLSession(configuration: configurazione)
        ServerFinto.azzera()
        let eve = ImpostazioniEve()
        let ollama = FornitoreOllama(indirizzo: eve.indirizzoLocale, modello: "qwen3.5:4b", sessione: sessione)
        let (pronto, manca, modelli) = aspetta {
            (await ollama.verifica(),
             await FornitoreOllama(indirizzo: eve.indirizzoLocale, modello: "qwen3:8b", sessione: sessione).verifica(),
             (try? await ollama.modelli()) ?? [])
        }
        controlla(pronto.pronto && modelli == ["qwen3.5:4b", "gemma4:e4b"], "Server finto: Ollama pronto con il modello scelto")
        controlla(!manca.pronto && (manca.motivo ?? "").contains("ollama pull qwen3:8b"), "Server finto: manca il modello, Eve dice come scaricarlo")

        // Una risposta vera in streaming, a pezzi spezzati a metà riga
        let stato = StatoShell(persistente: false)
        guard let f = stato.fonteEve("giulia") else { return controlla(false, "Server finto: fonte di Giulia") }
        let motore = MotoreLocale(eve, disponibilita: .pronto, sessione: sessione)
        let piano = NucleoEve.piano(RichiestaEve(domanda: "Pensaci bene: cos'è l'inflazione?", spunto: nil, fonte: f, storia: []),
                                    impostazioni: eve, ambiente: AmbienteEve(appAperte: ["Eve"], cliente: f.cliente.nome))
        final class Parziali: @unchecked Sendable { var elenco: [ParzialeEve] = [] }
        let parziali = Parziali()
        let risposta: (testo: String?, errore: String?) = aspetta {
            do {
                let r = try await motore.scrivi(piano) { parziali.elenco.append($0) }
                return (r.testo, nil)
            } catch {
                return (nil, error.localizedDescription)
            }
        }
        controlla(risposta.testo == ServerFinto.risposta, "Server finto: risposta in streaming ricomposta («\(risposta.testo ?? risposta.errore ?? "")»)")
        controlla(parziali.elenco.contains { $0.pensa && $0.testo.isEmpty } && parziali.elenco.count >= 2
                  && !(parziali.elenco.last?.testo ?? "").contains("ragiono"),
                  "Server finto: il testo arriva a pezzi mentre Eve lo scrive, senza il ragionamento (\(parziali.elenco.count) aggiornamenti)")
        let ricevuto = ServerFinto.ricevuto("/api/chat")
        let messaggiRicevuti = ricevuto?["messages"] as? [[String: String]] ?? []
        controlla((ricevuto?["stream"] as? Bool) == true && (ricevuto?["think"] as? Bool) == true && ricevuto?["model"] as? String == "qwen3.5:4b"
                  && messaggiRicevuti.first?["role"] == "system" && (messaggiRicevuti.last?["content"] ?? "").hasPrefix("CONTESTO:"),
                  "Server finto: la richiesta arrivata a Ollama (streaming, think, modello, istruzioni e contesto)")

        // Modello che non c'è: l'errore di Ollama diventa un messaggio chiaro
        var sbagliatoScelto = eve
        sbagliatoScelto.modelloLocale = "inesistente:1b"
        let sbagliato = sbagliatoScelto
        let errore: String = aspetta {
            do {
                _ = try await MotoreLocale(sbagliato, disponibilita: .pronto, sessione: sessione).genera(istruzioni: "a", richiesta: "b")
                return ""
            } catch {
                return error.localizedDescription
            }
        }
        controlla(errore.contains("not found") && errore.contains("404"), "Server finto: l'errore di Ollama arriva in chiaro (\(errore.prefix(90)))")

        // Il fornitore compatibile OpenAI sullo stesso server finto
        var sceltaOpenAI = ImpostazioniEve()
        sceltaOpenAI.fornitore = .compatibileOpenAI
        sceltaOpenAI.modelloCompatibile = "qwen3.5-4b"
        let openAI = sceltaOpenAI
        let compatibile: String = aspetta {
            (try? await MotoreLocale(openAI, disponibilita: .pronto, sessione: sessione).genera(istruzioni: "a", richiesta: "b")) ?? ""
        }
        let prontoOpenAI = aspetta { await FornitoriEve.crea(openAI, sessione: sessione).verifica() }
        controlla(compatibile == "Buongiorno dal server compatibile." && prontoOpenAI.pronto, "Server finto: streaming SSE del fornitore compatibile OpenAI")

        // Precarica e libera: Ollama riceve l'elenco vuoto con keep_alive
        let (caricato, _) = aspetta { (await ollama.precarica(restaInMemoria: "10m"), await ollama.libera()) }
        controlla(caricato && ServerFinto.caricamenti == ["10m", "0"], "Server finto: precarica e libera la memoria del modello (\(ServerFinto.caricamenti))")

        // Confronto tra due modelli: uno risponde, l'altro manca
        let rapporto = aspetta { await ConfrontoModelli.esegui(modelli: ["qwen3.5:4b", "qwen3:8b"], eve: eve, fonte: f, sessione: sessione) }
        let buoni = rapporto.esiti.filter { $0.modello == "qwen3.5:4b" && $0.errore == nil }.count
        let mancanti = rapporto.esiti.filter { $0.modello == "qwen3:8b" && $0.errore != nil }.count
        let pagina = ConfrontoModelli.html(rapporto)
        controlla(buoni == rapporto.domande.count && mancanti == rapporto.domande.count && pagina.contains("<h3>qwen3.5:4b</h3>") && pagina.contains("<h3>qwen3:8b</h3>")
                  && ConfrontoModelli.testo(rapporto).contains("| Domanda | qwen3.5:4b | qwen3:8b |"),
                  "Confronto: stesse domande ai due modelli, risposte e tempi affiancati")
    }
}

/// Il risultato di un lavoro asincrono, letto dal thread delle prove.
extension ProvaNucleoEve {
    /// Il ponte di Eve per iPhone e iPad: codice, buste cifrate e, sul Mac, il server vero in rete (su 127.0.0.1)
    /// davanti al server Ollama finto. Il telefono lo fa FornitorePonte, lo stesso codice che gira sull'iPhone.
    fileprivate static func ponte(_ controlla: (Bool, String) -> Void) {
        let codice = PonteEve.nuovoCodice()
        controlla(PonteEve.normalizza(codice) != nil && codice.count == 14, "Ponte: codice di abbinamento in tre gruppi (\(codice))")
        controlla(PonteEve.normalizza(codice.lowercased().replacingOccurrences(of: "-", with: " ")) == PonteEve.normalizza(codice),
                  "Ponte: il codice vale anche scritto in minuscolo e con gli spazi")
        controlla(PonteEve.normalizza("ABCD-EFGH-IJK0") == nil, "Ponte: un codice con lettere che si confondono non vale")
        guard let k = PonteEve.chiave(codice), let altra = PonteEve.chiave(PonteEve.nuovoCodice()) else {
            return controlla(false, "Ponte: chiave dal codice")
        }
        let b = BustaPonte(quando: Date().timeIntervalSince1970, percorso: "api/chat", corpo: Data("{}".utf8))
        let sigillata = (try? b.sigillata(k)) ?? Data()
        controlla(BustaPonte.apri(sigillata, k) == b, "Ponte: la busta si apre con lo stesso codice")
        controlla(BustaPonte.apri(sigillata, altra) == nil, "Ponte: con un altro codice la busta non si apre")
        controlla(BustaPonte.apri(sigillata, k, adesso: Date().addingTimeInterval(600)) == nil, "Ponte: una busta vecchia non vale (niente richieste rimandate)")
        controlla(!String(decoding: sigillata, as: UTF8.self).contains("api/chat"), "Ponte: il contenuto della busta non si legge in chiaro")
        #if os(macOS)
        let configurazione = URLSessionConfiguration.ephemeral
        configurazione.protocolClasses = [ServerFinto.self]
        let finta = URLSession(configuration: configurazione)
        var eve = ImpostazioniEve()
        eve.ponte.condividi = true
        eve.ponte.codice = codice
        let server = ServerPonteEve()
        server.aggiorna(eve, sessione: finta, porta: 0, annuncia: false)
        let scadenza = Date().addingTimeInterval(5)
        while server.porta == nil && Date() < scadenza { Thread.sleep(forTimeInterval: 0.05) }
        guard let porta = server.porta else { return controlla(false, "Ponte: il server del Mac ascolta") }
        defer { server.ferma() }
        let rete = URLSession(configuration: .ephemeral)
        let telefono = FornitorePonte(indirizzo: "http://127.0.0.1:\(porta)", codice: codice, tipo: .ollama, modello: "qwen3.5:4b", sessione: rete)
        let sbagliato = FornitorePonte(indirizzo: "http://127.0.0.1:\(porta)", codice: PonteEve.nuovoCodice(), tipo: .ollama, modello: "qwen3.5:4b", sessione: rete)
        let (pronto, rifiutato) = aspetta { (await telefono.verifica(), await sbagliato.verifica()) }
        controlla(pronto.pronto && PonteEve.ultimo?.modello == "qwen3.5:4b", "Ponte: il telefono vede Qwen pronto sul Mac (\(pronto.motivo ?? "pronto"))")
        controlla(!rifiutato.pronto, "Ponte: con il codice sbagliato il Mac non risponde")
        let risposta: String = aspetta {
            var testo = ""
            do {
                for try await p in telefono.flusso([MessaggioModello(ruolo: .utente, testo: "Ciao")], opzioni: OpzioniModello()) {
                    if case .testo(let t) = p { testo += t }
                }
            } catch { testo = "errore: \(error.localizedDescription)" }
            return testo
        }
        controlla(risposta == ServerFinto.risposta, "Ponte: la risposta di Qwen arriva al telefono a pezzi, cifrata («\(risposta)»)")
        controlla((ServerFinto.ricevuto("/api/chat")?["model"] as? String) == eve.modello, "Ponte: il Mac usa sempre il suo modello")
        #endif
    }
}

private final class ScatolaProva<T>: @unchecked Sendable {
    var valore: T?
}

/// Un server Ollama (e compatibile OpenAI) finto dentro il processo: risponde alle richieste della sessione
/// delle prove con righe spezzate in pezzi piccoli, come arrivano dalla rete.
final class ServerFinto: URLProtocol {
    static let risposta = "Ciao Denis, ecco la risposta."
    private static let blocco = NSLock()
    private static var ricevuti: [String: [String: Any]] = [:]
    private static var _caricamenti: [String] = []
    static let installati = ["qwen3.5:4b", "gemma4:e4b"]

    static func azzera() {
        blocco.lock(); defer { blocco.unlock() }
        ricevuti = [:]
        _caricamenti = []
    }

    static func ricevuto(_ percorso: String) -> [String: Any]? {
        blocco.lock(); defer { blocco.unlock() }
        return ricevuti[percorso]
    }

    static var caricamenti: [String] {
        blocco.lock(); defer { blocco.unlock() }
        return _caricamenti
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// Il corpo della richiesta (URLProtocol lo riceve spesso come flusso).
    private static func corpo(_ r: URLRequest) -> [String: Any] {
        var dati = r.httpBody ?? Data()
        if dati.isEmpty, let s = r.httpBodyStream {
            s.open()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while s.hasBytesAvailable {
                let n = s.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }
                dati.append(buffer, count: n)
            }
            s.close()
        }
        return (try? JSONSerialization.jsonObject(with: dati) as? [String: Any]) ?? [:]
    }

    private static func json(_ o: [String: Any]) -> String {
        String(data: (try? JSONSerialization.data(withJSONObject: o)) ?? Data(), encoding: .utf8) ?? ""
    }

    override func startLoading() {
        let percorso = request.url?.path ?? ""
        let c = Self.corpo(request)
        let modello = c["model"] as? String ?? ""
        let messaggi = c["messages"] as? [[String: Any]] ?? []
        if !c.isEmpty, !(percorso == "/api/chat" && messaggi.isEmpty) {
            Self.blocco.lock()
            Self.ricevuti[percorso] = c
            Self.blocco.unlock()
        }
        var codice = 200
        var testo = ""
        switch percorso {
        case "/api/version":
            testo = #"{"version":"0.12.0"}"#
        case "/api/tags":
            testo = Self.json(["models": Self.installati.map { ["name": $0, "size": 1] as [String: Any] }])
        case "/api/chat" where !Self.installati.contains(modello):
            codice = 404
            testo = #"{"error":"model '"# + modello + #"' not found"}"#
        case "/api/chat" where messaggi.isEmpty:
            Self.blocco.lock()
            Self._caricamenti.append((c["keep_alive"] as? String) ?? (c["keep_alive"] as? NSNumber)?.stringValue ?? "")
            Self.blocco.unlock()
            testo = Self.json(["model": modello, "done": true, "done_reason": "load"]) + "\n"
        case "/api/chat":
            var righe: [String] = []
            if (c["think"] as? Bool) == true {
                righe.append(Self.json(["message": ["role": "assistant", "content": "", "thinking": "ragiono un attimo"], "done": false]))
            }
            for parola in Self.risposta.split(separator: " ", omittingEmptySubsequences: false).enumerated().map({ $0.offset == 0 ? String($0.element) : " " + String($0.element) }) {
                righe.append(Self.json(["message": ["role": "assistant", "content": parola], "done": false]))
            }
            righe.append(Self.json(["message": ["role": "assistant", "content": ""], "done": true, "eval_count": 6, "eval_duration": 300_000_000, "prompt_eval_count": 900]))
            testo = righe.joined(separator: "\n") + "\n"
        case "/v1/models":
            testo = Self.json(["data": [["id": "qwen3.5-4b"]]])
        case "/v1/chat/completions":
            let pezzi = ["Buongiorno", " dal server", " compatibile."].map { "data: " + Self.json(["choices": [["delta": ["content": $0]]]]) }
            testo = (pezzi + ["data: [DONE]"]).joined(separator: "\n\n") + "\n\n"
        default:
            codice = 404
            testo = #"{"error":"percorso sconosciuto"}"#
        }
        let r = HTTPURLResponse(url: request.url!, statusCode: codice, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: r, cacheStoragePolicy: .notAllowed)
        // Pezzi di 7 byte: le righe arrivano spezzate, come dalla rete
        let dati = Data(testo.utf8)
        var i = 0
        while i < dati.count {
            client?.urlProtocol(self, didLoad: dati.subdata(in: i..<min(i + 7, dati.count)))
            i += 7
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
