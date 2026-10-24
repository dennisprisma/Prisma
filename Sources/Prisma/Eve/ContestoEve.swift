import Foundation

/// Scheda compatta del cliente che l'app passa a Eve insieme alla domanda.
///
/// Il modello Apple ha una finestra di circa 4.000 token (istruzioni, scheda, storia e risposta
/// insieme): la scheda resta sotto `limite` caratteri, con i numeri già calcolati dai motori di
/// Prisma. Eve non deve rifare i conti: legge e spiega.
enum ContestoEve {
    static let limite = 4_200
    /// Spazio per le cifre di uno spunto (bozza o calcoli pertinenti) passate al modello con la domanda.
    static let limiteCalcoli = 1_800

    static func scheda(_ f: FonteEve) -> String {
        var righe: [String] = []
        let c = f.cliente
        righe.append("OGGI: \(Formati.dataLunga.string(from: f.oggi)) \(Formati.formato("yyyy").string(from: f.oggi)). Consulente: \(f.nomeUtente).")

        // Anagrafica
        var anagrafica = "CLIENTE: \(c.nome)"
        if let eta = c.eta { anagrafica += ", \(eta) anni" }
        if !c.professione.isEmpty { anagrafica += ", \(c.professione)" }
        if let s = c.statoCivile { anagrafica += ", \(s.nome.lowercased())" }
        righe.append(anagrafica + ".")
        if !c.tema.isEmpty { righe.append("Progetto principale: \(c.tema)") }
        if !c.famiglia.isEmpty {
            let membri = c.famiglia.map { m in
                "\(m.relazione.nome.lowercased()) \(m.nome)\(m.eta.map { " (\($0) anni)" } ?? "")\(m.aCarico ? ", a carico" : "")"
            }
            righe.append("Famiglia: \(membri.joined(separator: "; ")).")
        }
        var profilo: [String] = []
        if let p = c.profilo.propensione { profilo.append("propensione \(p.nome.lowercased())") }
        if let o = c.profilo.orizzonteAnni { profilo.append("orizzonte \(o) anni") }
        if let e = c.profilo.esperienza { profilo.append("esperienza \(e.nome.lowercased())") }
        if !c.profilo.obiettivi.isEmpty { profilo.append("obiettivi: \(c.profilo.obiettivi)") }
        if !profilo.isEmpty { righe.append("Profilo: \(profilo.joined(separator: ", ")).") }
        if !c.canali.isEmpty { righe.append("Seguito sul canale: \(c.canali.map(\.nomeBreve).joined(separator: " e ")).") }
        if !c.nota.isEmpty { righe.append("Da ricordare: \(c.nota)") }

        // Profilo dei bisogni (ruota calcolata dall'app)
        let rilevati = MotoreBisogni.rileva(cliente: c, posizioni: f.posizioni, analisi: f.analisi, oggi: f.oggi)
        let ruota = MotoreBisogni.ruota(rilevati, profilo: c.bisogni)
        let priorita = MotoreBisogni.priorita(rilevati, profilo: c.bisogni)
        if !priorita.isEmpty {
            righe.append("BISOGNI IN ORDINE DI PRIORITÀ: " + priorita.prefix(4).map { a in
                let o = c.bisogni.valutazione(a).orizzonte.map { ", \($0.nome.lowercased())" } ?? ""
                return "\(a.nome.lowercased()) (\((ruota[a] ?? .nessuna).nome.lowercased())\(o))"
            }.joined(separator: "; ") + ".")
        }
        if !c.bisogni.eventi.isEmpty {
            righe.append("Eventi di vita: " + c.bisogni.eventi.sorted { $0.anno < $1.anno }.map { "\($0.tipo.nome.lowercased()) nel \($0.anno)\($0.nota.isEmpty ? "" : " (\($0.nota))")" }.joined(separator: "; ") + ".")
        }
        let confermati = MotoreBisogni.confermati(rilevati, profilo: c.bisogni)
        if !confermati.isEmpty {
            righe.append("Bisogni confermati con il cliente: " + confermati.map(\.titolo).joined(separator: "; ") + ".")
        }

        // Quadro delle posizioni (calcolato dall'app)
        let r = RiepilogoPosizioni(f.posizioni)
        righe.append("QUADRO (calcolato da Prisma): patrimonio netto \(Formati.euro(r.patrimonioNetto)) (attività \(Formati.euro(r.attivita)), debiti \(Formati.euro(r.debiti))); premi e versamenti \(Formati.euro(r.premiAnnui)) all'anno; capitale assicurato \(Formati.euro(r.capitaleAssicurato)); quota Alleanza \(Int((r.quota(.alleanza) * 100).rounded()))%, indipendente \(Int((r.quota(.indipendente) * 100).rounded()))%.")

        let inEssere = f.posizioni.filter { $0.stato == .inEssere }
        if !inEssere.isEmpty {
            righe.append("POSIZIONI IN ESSERE:")
            righe.append(contentsOf: inEssere.prefix(12).map { "- " + riga($0) })
        }
        let successione = MotoreSuccessione.calcola(cliente: c, posizioni: f.posizioni, oggi: f.oggi)
        if !successione.vuota {
            let eredi = successione.eredi.isEmpty ? "nessun erede registrato" : successione.eredi.map { "\($0.nome) \(MotoreSuccessione.frazione($0.quota))" }.joined(separator: ", ")
            righe.append("SUCCESSIONE (stima di Prisma, senza testamento): ai beneficiari \(Formati.euro(successione.fuoriAsse)), agli eredi \(Formati.euro(successione.asseNetto)) (\(eredi)); imposte \(Formati.euro(successione.imposte)); da sistemare: \(successione.daSistemare.count + (successione.conviventeEscluso == nil ? 0 : 1)).")
        }
        let costi = MotoreCosti.calcola(f.posizioni, prodotti: f.prodotti, cliente: c.id)
        if let m = costi.costoMedio {
            let alternativa = costi.conAlternativa.first.flatMap { v in v.alternativa.map { "; alternativa a parità di rischio per \(v.posizione.nome): \($0.prodotto.nome), +\(Formati.euro($0.guadagno)) in \($0.anni) anni" } } ?? ""
            righe.append("COSTI (calcolati da Prisma): \(Formati.euro(costi.euroAnno)) quest'anno, media \(CifreDoc.percento(m, decimali: 2)) l'anno; tolgono \(Formati.euro(costi.perso10)) in 10 anni e \(Formati.euro(costi.perso20)) in 20\(alternativa).")
        }
        let prova = MotoreResistenza.calcola(f.posizioni, profilo: c.profilo)
        if !prova.vuota {
            // Una riga sola: la scheda ha un limite di spazio
            let scenari = prova.scenari.filter { !$0.voci.isEmpty }.map { "\($0.tipo.titolo.lowercased()) −\(Formati.euro($0.perdita)) (\(CifreDoc.percento($0.quota * 100, decimali: 0)))" }
            let giudizio = prova.giudizio.map { "; \($0.etichetta.lowercased()), che sopporta fino al \(CifreDoc.condizione(prova.sopportabile ?? 0))" } ?? ""
            righe.append("PROVA DI RESISTENZA (stime prudenti di Prisma, non previsioni): " + scenari.joined(separator: ", ") + giudizio + ".")
        }
        let proposte = f.posizioni.filter { $0.stato == .proposta }
        if !proposte.isEmpty {
            righe.append("PROPOSTE:")
            righe.append(contentsOf: proposte.prefix(6).map { "- " + riga($0) + " · esito: \(($0.esito ?? .bozza).nome.lowercased())" })
        }

        // Analisi 360 (calcolata dall'app)
        let a = f.analisi
        let prev = MotoreAnalisi.previdenza(a.previdenza)
        let prot = MotoreAnalisi.protezione(a.protezione, posizioni: f.posizioni)
        let inv = MotoreAnalisi.investimenti(a.investimenti)
        let ris = MotoreAnalisi.risparmio(a.risparmio)
        righe.append("ANALISI 360 (\(f.analisiSalvata ? "ipotesi riviste con il consulente" : "prima stesura dalle posizioni, da verificare")):")
        righe.append("- Previdenza: divario \(Formati.euro(prev.divario))/mese, i piani ne coprono \(Formati.euro(prev.integrazione))/mese, restano \(Formati.euro(prev.divarioResiduo))/mese; versamento teorico \(prev.versamentoTeorico.map { Formati.euro($0) + "/mese" } ?? "n.d.").")
        righe.append("- Protezione: fabbisogno caso morte \(Formati.euro(prot.fabbisogno)), coperture \(Formati.euro(prot.capitaleVita)), divario \(Formati.euro(prot.divario)) (con le proposte \(Formati.euro(prot.divarioConProposte))); rischi coperti: \(prot.rischiCoperti.isEmpty ? "nessuno" : prot.rischiCoperti.map(\.nome).sorted().joined(separator: ", ")); riserva mancante \(Formati.euro(prot.riservaMancante)).")
        righe.append("- Investimenti: \(Formati.euro(a.investimenti.capitale)) per \(a.investimenti.anni) anni → netto \(Formati.euro(inv.esito.netto)), costi che tolgono \(Formati.euro(inv.impattoCosti)).")
        righe.append("- Risparmio: obiettivo \(Formati.euro(a.risparmio.obiettivo)) in \(a.risparmio.anni) anni, coperto al \(Int(ris.copertura.rounded()))%, versamento teorico \(ris.versamentoTeorico.map { Formati.euro($0) + "/mese" } ?? "n.d.").")

        // Obiettivi (avanzamento calcolato dall'app)
        if !f.obiettivi.isEmpty {
            righe.append("OBIETTIVI:")
            righe.append(contentsOf: f.obiettivi.prefix(4).map { o in
                let a = AvanzamentoObiettivo(o, posizioni: f.posizioni)
                return "- \(o.titolo): \(Formati.euro(o.importo)) entro \(Formati.meseAnno.string(from: o.scadenza)), raggiunto il \(Int((a.quota * 100).rounded()))%, versamento necessario \(a.versamentoNecessario.map { Formati.euro($0) + "/mese" } ?? "n.d."), priorità \(o.priorita.nome.lowercased())."
            })
        }

        // Note del taccuino (scritte dal consulente)
        if !f.note.isEmpty {
            righe.append("NOTE DEL TACCUINO:")
            righe.append(contentsOf: f.note.prefix(3).map { n in
                "- \(n.titoloMostrato) (\(Formati.giornoMese.string(from: n.aggiornataIl))): \(n.estratto(Nota.limiteEve))"
            })
        }

        // Ultimo incontro concluso
        if let u = f.incontri.filter({ $0.stato == .concluso }).max(by: { $0.data < $1.data }) {
            var r = "ULTIMO INCONTRO (\(Formati.dataEstesa.string(from: u.data))): \(u.titolo)."
            if !u.preoccupazioni.isEmpty { r += " Preoccupazioni: \(u.preoccupazioni.prefix(200))" }
            if !u.progetti.isEmpty { r += " Progetti: \(u.progetti.prefix(200))" }
            if !u.decisioni.isEmpty { r += " Decisioni: \(u.decisioni.prefix(240))" }
            righe.append(r)
        }

        // Agenda e attività
        let futuri = f.appuntamenti.filter { $0.inizio >= Calendar.current.startOfDay(for: f.oggi) && $0.stato == .pianificato }
            .sorted { $0.inizio < $1.inizio }
        if !futuri.isEmpty {
            righe.append("PROSSIMI INCONTRI:")
            righe.append(contentsOf: futuri.prefix(3).map {
                "- \(Formati.dataLunga.string(from: $0.inizio)) ore \(Formati.ora.string(from: $0.inizio)): \($0.titolo) (\($0.tipo.nome.lowercased()), \($0.luogo))\($0.note.isEmpty ? "" : ". Note: \($0.note)")"
            })
        }
        let aperte = f.attivita.filter { !$0.completata }.sorted { $0.scadenza < $1.scadenza }
        if !aperte.isEmpty {
            righe.append("ATTIVITÀ APERTE:")
            righe.append(contentsOf: aperte.prefix(5).map { "- \($0.titolo) (entro \(Formati.giornoMese.string(from: $0.scadenza)), priorità \($0.priorita.nome.lowercased()))" })
        }

        var testo = righe.joined(separator: "\n")
        if testo.count > limite {
            testo = String(testo.prefix(limite)) + "…"
        }
        return testo
    }

    static func riga(_ p: Posizione) -> String {
        var parti = ["[\(p.canale.nomeBreve)] \(p.nome) (\(p.area.nome.lowercased()))"]
        if p.area == .protezione {
            if let c = p.capitaleAssicurato { parti.append("capitale \(Formati.euro(c))\(p.rischio.map { " \($0.nome.lowercased())" } ?? "")") }
        } else if p.stato == .proposta {
            if p.versamentoIniziale > 0 { parti.append("versamento iniziale \(Formati.euro(p.versamentoIniziale))") }
        } else {
            parti.append("valore \(Formati.euro(p.valore))")
        }
        if p.premioAnnuo > 0 { parti.append("\(p.area == .debiti ? "rata" : "premio") \(Formati.euro(p.premio)) \(p.frequenza.nome.lowercased())") }
        if let r = p.rendimentoAtteso { parti.append("rendimento atteso \(Formati.percentuale(r))") }
        if let k = p.costoAnnuo { parti.append("costo annuo \(Formati.percentuale(k))") }
        if let s = p.scadenza { parti.append("scadenza \(Formati.dataEstesa.string(from: s))") }
        // Com'è andata davvero, dallo storico dei valori (calcolato da Prisma)
        if p.stato == .inEssere, let a = MotoreAndamento.calcola(p) {
            var andamento = "andamento dal \(Formati.dataBreve.string(from: a.dal)): "
                + (a.rendimentoAnnuo.map { "\(CifreDoc.variazione($0)) l'anno" } ?? "\(CifreDoc.variazione(a.rendimentoPeriodo)) nel periodo")
            if let g = a.giudizio { andamento += ", \(g.nome)" }
            parti.append(andamento)
        }
        return parti.joined(separator: ", ")
    }
}
