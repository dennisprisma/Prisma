import Foundation

/// Motore senza intelligenza artificiale: compone le risposte agli spunti a partire dai dati
/// del dossier e dai motori di calcolo. È sempre disponibile, è istantaneo e non sbaglia i numeri;
/// non capisce però le domande libere. Fa da riserva quando il modello Apple non c'è.
struct MotoreSintesi: MotoreEve {
    let nome = "Sintesi dai dati"
    let descrizione = "Risposte composte dai dati del dossier, sul Mac. Nessun modello di intelligenza artificiale."
    let disponibilita = DisponibilitaEve.pronto

    func rispondi(_ r: RichiestaEve) async throws -> RispostaEve {
        componi(r)
    }

    /// Versione immediata (usata anche dalle istantanee e dalle prove).
    func componi(_ r: RichiestaEve) -> RispostaEve {
        let f = r.fonte
        switch r.spunto ?? SpuntoEve.da(r.domanda) {
        case .riepilogo: return riepilogo(f)
        case .incontro: return incontro(f)
        case .prossimiPassi: return prossimiPassi(f)
        case .protezione: return protezioneFamiglia(f)
        case .scadenze: return scadenze(f)
        case .checkUp: return checkUp(f)
        case .resoconto: return resoconto(f)
        case .pensione: return pensione(f)
        case .liquidita: return liquidita(f)
        case .obiettivi: return obiettivi(f)
        case .cambiare: return cambiare(f)
        case nil:
            // Una domanda libera su un argomento noto: rispondo con lo spunto più vicino
            if let s = SpuntoEve.argomento(r.domanda) {
                let risposta = componi(RichiestaEve(domanda: s.domanda, spunto: s, fonte: f, storia: []))
                return RispostaEve(titolo: risposta.titolo, testo: risposta.testo
                    + "\n\nHo letto la domanda come «\(s.domanda)». Per le domande libere serve il modello Apple sul Mac (Apple Intelligence).")
            }
            var risposta = riepilogo(f)
            risposta.titolo = "Ecco cosa trovo nel dossier"
            return RispostaEve(titolo: risposta.titolo, testo: risposta.testo
                + "\n\nPer capire domande libere serve il modello Apple sul Mac (Apple Intelligence). Intanto puoi usare gli spunti qui sotto.")
        }
    }

    // MARK: - Spunti

    private func riepilogo(_ f: FonteEve) -> RispostaEve {
        let c = f.cliente
        let r = RiepilogoPosizioni(f.posizioni)
        var parti: [String] = []
        var chi = c.nome
        if let eta = c.eta { chi += ", \(eta) anni" }
        if !c.professione.isEmpty { chi += ", \(c.professione.lowercased())" }
        parti.append(chi + (c.tema.isEmpty ? "." : ". Il suo progetto: «\(c.tema)»"))
        parti.append("Patrimonio netto \(Formati.euro(r.patrimonioNetto)): \(Formati.euro(r.attivita)) di attività e \(Formati.euro(r.debiti)) di debiti. "
            + "Sul canale Alleanza c'è il \(percento(r.quota(.alleanza))) delle attività, sull'indipendente il \(percento(r.quota(.indipendente))).")
        let inEssere = f.posizioni.filter { $0.stato == .inEssere && !$0.area.passivo }
        if !inEssere.isEmpty {
            let aree = Dictionary(grouping: inEssere, by: \.area)
                .sorted { $0.value.reduce(0) { $0 + $1.valore } > $1.value.reduce(0) { $0 + $1.valore } }
                .map { "\($0.key.nome.lowercased()) \(Formati.euro($0.value.reduce(0) { $0 + $1.valore }))" }
            parti.append("In essere: \(aree.joined(separator: ", ")). Premi e versamenti: \(Formati.euro(r.premiAnnui)) all'anno.")
        }
        if r.proposteAperte > 0 {
            let nomi = f.posizioni.filter { $0.stato == .proposta && $0.esito != .accettata && $0.esito != .rifiutata }.map(\.nome)
            parti.append("Proposte aperte: \(nomi.joined(separator: ", ")).")
        }
        let prot = MotoreAnalisi.protezione(f.analisi.protezione, posizioni: f.posizioni)
        if prot.divario > 0 {
            parti.append("Protezione: al fabbisogno caso morte mancano \(Formati.euro(prot.divario)).")
        }
        if let prossimo = prossimoIncontro(f) {
            parti.append("Prossimo incontro: \(Formati.dataLunga.string(from: prossimo.inizio)) alle \(Formati.ora.string(from: prossimo.inizio)), «\(prossimo.titolo)».")
        }
        return RispostaEve(titolo: "Il quadro di \(c.nome)", testo: parti.joined(separator: "\n\n"))
    }

    private func incontro(_ f: FonteEve) -> RispostaEve {
        guard let e = prossimoIncontro(f) else {
            return RispostaEve(titolo: "Nessun incontro in agenda",
                               testo: "Non trovo incontri futuri con \(f.cliente.nome). Puoi fissarne uno dall'Agenda: ti preparo la traccia appena c'è.")
        }
        var parti = ["\(Formati.dataLunga.string(from: e.inizio).capitalized), ore \(Formati.ora.string(from: e.inizio)) · \(e.luogo.isEmpty ? "luogo da definire" : e.luogo) · \(e.durataMinuti) minuti · \(e.tipo.nome.lowercased())."]
        if !e.note.isEmpty { parti.append("Le tue note: \(e.note)") }
        var punti: [String] = []
        let rilevati = MotoreBisogni.rileva(cliente: f.cliente, posizioni: f.posizioni, analisi: f.analisi, oggi: f.oggi)
        let priorita = MotoreBisogni.priorita(rilevati, profilo: f.cliente.bisogni)
        if !priorita.isEmpty {
            punti.append("partire dalle sue priorità: \(priorita.prefix(3).map { $0.nome.lowercased() }.joined(separator: ", "))")
        } else {
            punti.append("costruire la ruota dei bisogni (scheda Bisogni del cliente): due tocchi per area")
        }
        if let id = e.posizioneId, let p = f.posizioni.first(where: { $0.id == id }) {
            punti.append("si parla di \(p.nome) (\(p.canale.nomeBreve), \(p.stato == .proposta ? "proposta" : "in essere")): porta il KID o il set informativo")
        }
        for p in f.posizioni where p.scadeEntro(RiepilogoPosizioni.giorniScadenza) {
            punti.append("\(p.nome) scade il \(Formati.dataEstesa.string(from: p.scadenza ?? f.oggi)): decidere rinnovo o alternativa")
        }
        let prot = MotoreAnalisi.protezione(f.analisi.protezione, posizioni: f.posizioni)
        if prot.divario > 0 { punti.append("protezione: mancano \(Formati.euro(prot.divario)) di capitale caso morte") }
        let prev = MotoreAnalisi.previdenza(f.analisi.previdenza)
        if prev.divarioResiduo > 0 { punti.append("previdenza: restano scoperti \(Formati.euro(prev.divarioResiduo)) al mese alla pensione") }
        for t in f.attivita.filter({ !$0.completata && $0.appuntamentoId == e.id }) { punti.append("da preparare: \(t.titolo.lowercased())") }
        if !f.analisiSalvata { punti.append("verificare con il cliente le ipotesi dell'Analisi 360 (ora sono ricavate dalle posizioni)") }
        if !punti.isEmpty {
            parti.append("Punti da toccare:\n" + punti.map { "• " + $0.prefix(1).uppercased() + String($0.dropFirst()) }.joined(separator: "\n"))
        }
        if !f.cliente.nota.isEmpty { parti.append("Da ricordare: \(f.cliente.nota)") }
        return RispostaEve(titolo: "Traccia per «\(e.titolo)»", testo: parti.joined(separator: "\n\n"))
    }

    private func prossimiPassi(_ f: FonteEve) -> RispostaEve {
        var passi: [String] = []
        let aperte = f.attivita.filter { !$0.completata }.sorted { $0.scadenza < $1.scadenza }
        for t in aperte.prefix(5) {
            passi.append("\(t.titolo) — entro \(Formati.giornoMese.string(from: t.scadenza))\(t.priorita == .alta ? ", priorità alta" : "")")
        }
        for p in f.posizioni where p.scadeEntro(RiepilogoPosizioni.giorniScadenza) || p.scaduta {
            passi.append("Rivedere \(p.nome) (\(p.canale.nomeBreve)) prima della scadenza del \(Formati.dataEstesa.string(from: p.scadenza ?? f.oggi))")
        }
        for p in f.posizioni where p.stato == .proposta && (p.esito ?? .bozza) == .bozza {
            passi.append("Completare e presentare la proposta \(p.nome) (\(p.canale.nomeBreve))")
        }
        let prot = MotoreAnalisi.protezione(f.analisi.protezione, posizioni: f.posizioni)
        if prot.divario > 0 { passi.append("Ragionare sulla copertura caso morte: mancano \(Formati.euro(prot.divario))") }
        if prossimoIncontro(f) == nil { passi.append("Fissare il prossimo incontro in Agenda") }
        if passi.isEmpty { passi.append("Nessun passo in sospeso: il dossier è in ordine.") }
        return RispostaEve(titolo: "I prossimi passi con \(f.cliente.nome)",
                           testo: passi.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
    }

    private func scadenze(_ f: FonteEve) -> RispostaEve {
        let limite = Calendar.current.date(byAdding: .month, value: 12, to: f.oggi) ?? f.oggi
        let elenco = f.posizioni
            .filter { $0.stato == .inEssere && ($0.scadenza.map { $0 <= limite } ?? false) }
            .sorted { ($0.scadenza ?? f.oggi) < ($1.scadenza ?? f.oggi) }
        guard !elenco.isEmpty else {
            return RispostaEve(titolo: "Nessuna scadenza nei prossimi 12 mesi",
                               testo: "Le posizioni in essere di \(f.cliente.nome) non scadono nel prossimo anno.")
        }
        let righe = elenco.map { p -> String in
            let giorni = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: f.oggi), to: p.scadenza ?? f.oggi).day ?? 0
            let quando = giorni < 0 ? "scaduta da \(-giorni) giorni" : giorni == 0 ? "scade oggi" : "scade tra \(giorni) giorni"
            return "• \(p.nome) (\(p.canale.nomeBreve), \(p.area.nome.lowercased())): \(quando), il \(Formati.dataEstesa.string(from: p.scadenza ?? f.oggi))."
        }
        return RispostaEve(titolo: "Le scadenze di \(f.cliente.nome)",
                           testo: righe.joined(separator: "\n") + "\n\nOgni scadenza è l'occasione per rivedere la posizione: la trovi anche nella giornata dell'Agenda.")
    }

    // MARK: - Aiuti

    private func prossimoIncontro(_ f: FonteEve) -> Appuntamento? {
        f.appuntamenti
            .filter { $0.stato == .pianificato && $0.inizio >= Calendar.current.startOfDay(for: f.oggi) }
            .min { $0.inizio < $1.inizio }
    }

    private func percento(_ quota: Double) -> String {
        "\(Int((quota * 100).rounded()))%"
    }
}
