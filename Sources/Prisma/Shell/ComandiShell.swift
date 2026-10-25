import Foundation

/// Eve fa le cose: esegue i comandi riconosciuti nella frase e risponde come un'assistente
/// («Va bene, te lo preparo»). Quello che crea (appuntamenti, promemoria, note) si apre o si annulla
/// dalla risposta. In modalità cliente non esce dal dossier del cliente davanti a te.
extension StatoShell {
    /// Se la frase è un comando, Eve lo esegue e risponde nella conversazione; true se l'ha gestita.
    func eseguiComandoEve(_ testo: String, oggi: Date = Date()) -> Bool {
        // Anche in modalità cliente Eve riconosce tutti i nomi, per non scambiare un altro cliente con quello davanti a te
        let noti = dati.clienti.map { ClienteNoto(id: $0.id, nome: $0.nome) }
        var comando: ComandoEve?
        if var b = appuntamentoInSospeso {
            appuntamentoInSospeso = nil
            if DateItaliane.cerca(#"^(?:no|niente|lascia (?:stare|perdere)|annulla|non importa|lascia)\b"#, InterpreteComandi.pulisci(testo)) != nil {
                rispondiComando(testo, "Va bene, lascio stare.", chiave: chiaveConversazione)
                return true
            }
            let q = DateItaliane.trova(testo, oggi: oggi)
            let primaCliente = b.cliente
            if b.giorno == nil, let g = q.giorno { b.giorno = g }
            if b.ora == nil, let o = q.ora { b.ora = o.ore; b.minuti = o.minuti }
            if b.cliente == nil, let c = InterpreteComandi.clientiNominati(testo.lowercased(), noti).first { b.cliente = c.id }
            if q.giorno != nil || q.ora != nil || b.cliente != primaCliente {
                comando = .appuntamento(b)
            }
        }
        if comando == nil {
            comando = InterpreteComandi.interpreta(testo, clienti: noti, attivo: evePortafoglio ? nil : clienteAttivoId, oggi: oggi)
        }
        guard var comando else { return false }
        if inModoCliente {
            let nome = clienteAttivo?.nome ?? "questo cliente"
            if let altro = Self.clienteDel(comando), altro != clienteAttivoId {
                comando = .chiedi("In modalità cliente resto sul dossier di \(nome).")
            } else if case .chiedi(let d) = comando, d.hasPrefix("Ho sentito più clienti") || d.hasPrefix("Ci sono più clienti") {
                comando = .chiedi("In modalità cliente parlo solo di \(nome).")
            }
        }
        // Passando a un altro cliente, la conversazione continua nel suo dossier
        var chiave = chiaveConversazione
        if case .cliente(let id) = comando, !inModoCliente { chiave = id }
        let (risposta, azione) = esegui(comando, oggi: oggi)
        rispondiComando(testo, risposta, chiave: chiave, azione: azione)
        return true
    }

    /// Il cliente a cui si riferisce un comando (nil se non riguarda un cliente preciso).
    static func clienteDel(_ c: ComandoEve) -> String? {
        switch c {
        case .cliente(let id): return id
        case .documento(_, let id): return id
        case .appuntamento(let b): return b.cliente
        case .attivita(let id, _, _), .nota(let id, _): return id
        case .apri, .scrivania, .agenda, .chiedi: return nil
        }
    }

    var chiaveConversazione: String { evePortafoglio ? EvePortafoglio.chiave : clienteAttivoId }

    private func rispondiComando(_ domanda: String, _ risposta: String, chiave: String, azione: AzioneEve? = nil) {
        aggiungiMessaggio(MessaggioEve(autore: .utente, testo: domanda), cliente: chiave)
        domandaEve = ""
        var m = MessaggioEve(autore: .eve, testo: risposta, motore: "Eve")
        m.azione = azione
        aggiungiMessaggio(m, cliente: chiave)
    }

    private func esegui(_ comando: ComandoEve, oggi: Date) -> (String, AzioneEve?) {
        switch comando {
        case .chiedi(let domanda):
            return (domanda, nil)

        case .scrivania:
            mostraScrivania()
            return ("Ecco la scrivania.", nil)

        case .apri(let app):
            guard appConsentita(app) else { return ("In modalità cliente non apro \(app.titolo): mostrerebbe i dati di altri clienti.", nil) }
            apri(app)
            return ("Ecco \(app.titolo).", nil)

        case .cliente(let id):
            guard let c = cliente(id) else { return ("Non trovo questo cliente.", nil) }
            if inModoCliente, id != clienteAttivoId {
                return ("In modalità cliente resto sul dossier di \(clienteAttivo?.nome ?? "questo cliente").", nil)
            }
            clienteAttivoId = id
            evePortafoglio = false
            return ("Ok, parliamo di \(c.nome). Cosa ti preparo?", nil)

        case .documento(let scelta, let clienteId):
            if let clienteId, clienteId != clienteAttivoId {
                guard !inModoCliente else { return ("In modalità cliente preparo solo i documenti di \(clienteAttivo?.nome ?? "questo cliente").", nil) }
                clienteAttivoId = clienteId
            }
            if scelta == .portafoglio {
                guard !inModoCliente else { return ("Il tuo portafoglio non si apre in modalità cliente: riguarda tutti i clienti.", nil) }
                apriProspetto(.portafoglio)
                return ("Va bene, ti preparo il prospetto del tuo portafoglio. Lo trovi aperto in Prospetti e report.", nil)
            }
            guard let c = clienteAttivo else { return ("Per quale cliente lo preparo?", nil) }
            if scelta == .fascicolo,
               let a = appuntamenti.filter({ $0.clienteId == c.id && $0.stato == .pianificato && $0.inizio >= Calendar.current.startOfDay(for: oggi) })
                .min(by: { $0.inizio < $1.inizio }) {
                preparaFascicolo(per: a)
                return ("Va bene, ti preparo il fascicolo per l'incontro di \(DateItaliane.descrivi(a.inizio, conOra: true, oggi: oggi)) con \(c.nome), con i report adatti già scelti. Lo trovi in Prospetti e report.", nil)
            }
            guard documentoProspetto(scelta) != nil || scelta == .fascicolo else {
                return ("Per \(c.nome) non ho ancora i dati per \(Self.nomeDocumento(scelta)): completa prima il dossier.", nil)
            }
            apriProspetto(scelta)
            return ("Va bene, ti preparo \(Self.nomeDocumento(scelta)) di \(c.nome). Lo trovi aperto in Prospetti e report: da lì lo presenti o lo salvi in PDF.", nil)

        case .appuntamento(let b):
            guard let id = b.cliente, let c = cliente(id) else { return ("Con quale cliente fisso l'appuntamento?", nil) }
            guard b.giorno != nil else {
                appuntamentoInSospeso = b
                return ("Per quando lo fisso con \(c.nome)? Dimmi per esempio «giovedì alle 15».", nil)
            }
            guard let inizio = b.inizio() else {
                appuntamentoInSospeso = b
                return ("A che ora, \(DateItaliane.descrivi(b.giorno!, conOra: false, oggi: oggi))?", nil)
            }
            var a = Appuntamento.nuovo(clienteId: id, giorno: inizio)
            a.inizio = inizio
            a.tipo = b.tipo
            a.titolo = Self.titoloAppuntamento(b.tipo, cliente: c.nome)
            a.durataMinuti = b.tipo == .telefonata ? 20 : 60
            if b.tipo == .telefonata { a.luogo = "Telefonata" }
            a.note = "Fissato con Eve."
            let fine = inizio.addingTimeInterval(TimeInterval(a.durataMinuti * 60))
            let sovrapposto = dati.appuntamenti.first {
                $0.stato == .pianificato && $0.inizio < fine && $0.inizio.addingTimeInterval(TimeInterval($0.durataMinuti * 60)) > inizio
            }
            dati.appuntamenti.append(a)
            var risposta = "Fatto: \(a.titolo.prefix(1).lowercased() + a.titolo.dropFirst()) \(DateItaliane.descrivi(inizio, conOra: true, oggi: oggi)), in agenda."
            if inizio < oggi { risposta += " Attenzione: è un orario già passato." }
            if let s = sovrapposto {
                risposta += " Attenzione: a quell'ora c'è già «\(s.titolo)»\(cliente(s.clienteId).map { " con \($0.nome)" } ?? "")."
            }
            return (risposta, AzioneEve(tipo: .appuntamento, id: a.id))

        case .attivita(let id, let titolo, let scadenza):
            guard let id, let c = cliente(id) else { return ("Per quale cliente lo segno?", nil) }
            var t = Attivita.nuova(clienteId: id, scadenza: scadenza)
            t.titolo = titolo
            t.note = "Chiesta a Eve."
            dati.attivita.append(t)
            return ("Va bene, te lo ricordo \(DateItaliane.descrivi(scadenza, conOra: false, oggi: oggi)): «\(titolo)», tra le attività di \(c.nome).",
                    AzioneEve(tipo: .attivita, id: t.id))

        case .nota(let id, let testo):
            guard let id, let c = cliente(id) else { return ("Per quale cliente prendo nota?", nil) }
            let titolo = String(testo.split(separator: " ").prefix(8).joined(separator: " ").prefix(Nota.limiteTitolo))
            let n = Nota(clienteId: id, titolo: titolo, testo: testo)
            dati.note.append(n)
            return ("Annotato nelle note di \(c.nome).", AzioneEve(tipo: .nota, id: n.id))

        case .agenda(let giorno):
            return (riepilogoAgenda(giorno, oggi: oggi), nil)
        }
    }

    /// «Oggi hai due appuntamenti: alle 9:30 Revisione con Marco Bianchi; …» (e le attività che scadono).
    func riepilogoAgenda(_ giorno: Date, oggi: Date = Date()) -> String {
        let cal = Calendar.current
        let quando = DateItaliane.descrivi(giorno, conOra: false, oggi: oggi)
        let Quando = quando.prefix(1).uppercased() + quando.dropFirst()
        let elenco = appuntamenti.filter { $0.stato == .pianificato && cal.isDate($0.inizio, inSameDayAs: giorno) }.sorted { $0.inizio < $1.inizio }
        let scadono = attivita.filter { !$0.completata && cal.isDate($0.scadenza, inSameDayAs: giorno) }
        var righe: [String] = []
        if elenco.isEmpty {
            righe.append("\(Quando) non hai appuntamenti.")
        } else {
            let numero = elenco.count == 1 ? "un appuntamento" : "\(elenco.count) appuntamenti"
            righe.append("\(Quando) hai \(numero):")
            for a in elenco {
                righe.append("• alle \(Formati.ora.string(from: a.inizio)) \(a.titolo)\(cliente(a.clienteId).map { " (\($0.nome))" } ?? "")")
            }
        }
        if !scadono.isEmpty {
            righe.append(scadono.count == 1 ? "C'è anche un'attività da fare: «\(scadono[0].titolo)»." : "Ci sono anche \(scadono.count) attività da fare.")
        }
        return righe.joined(separator: "\n")
    }

    // MARK: - Dalla risposta: apri o annulla

    func apriAzioneEve(_ a: AzioneEve) {
        switch a.tipo {
        case .appuntamento:
            if let x = appuntamento(a.id) { mostraInAgenda(x) }
        case .attivita:
            attivitaSelezionata = a.id
            apri(.attivita)
        case .nota:
            notaSelezionata = a.id
            apri(.note)
        }
    }

    func annullaAzioneEve(_ a: AzioneEve, messaggio: String) {
        switch a.tipo {
        case .appuntamento: eliminaAppuntamento(a.id)
        case .attivita: eliminaAttivita(a.id)
        case .nota: dati.note.removeAll { $0.id == a.id }
        }
        let chiave = chiaveConversazione
        func segna(_ elenco: inout [MessaggioEve]) {
            if let i = elenco.firstIndex(where: { $0.id == messaggio }) { elenco[i].azione?.annullata = true }
        }
        if dati.impostazioni.eve.conservaConversazioni {
            var elenco = dati.conversazioni[chiave] ?? []
            segna(&elenco)
            dati.conversazioni[chiave] = elenco
        } else {
            var elenco = conversazioniTemporanee[chiave] ?? []
            segna(&elenco)
            conversazioniTemporanee[chiave] = elenco
        }
        mostraAvviso("Annullato")
    }

    // MARK: - Nomi

    static func nomeDocumento(_ s: SceltaProspetto) -> String {
        switch s {
        case .fascicolo: return "il fascicolo dell'incontro"
        case .riesame: return "la preparazione del riesame annuale"
        default:
            let report: Bool
            switch s {
            case .resoconto(let r), .previdenza(let r), .protezione(let r), .liquidita(let r), .checkUp(let r),
                 .resistenza(let r), .costi(let r), .successione(let r), .patrimonio(let r): report = r
            default: report = false
            }
            return "\(report ? "il report" : "il prospetto") «\(s.tipo.nome)»"
        }
    }

    static func titoloAppuntamento(_ tipo: TipoAppuntamento, cliente: String) -> String {
        switch tipo {
        case .telefonata: return "Telefonata con \(cliente)"
        case .revisione: return "Revisione con \(cliente)"
        case .firma: return "Firma con \(cliente)"
        case .proposta: return "Presentazione della proposta a \(cliente)"
        default: return "Incontro con \(cliente)"
        }
    }
}
