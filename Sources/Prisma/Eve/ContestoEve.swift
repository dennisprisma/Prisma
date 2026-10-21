import Foundation

/// Scheda compatta del cliente che l'app passa a Eve insieme alla domanda.
///
/// Il modello Apple ha una finestra di circa 4.000 token (istruzioni, scheda, storia e risposta
/// insieme): la scheda resta sotto `limite` caratteri, con i numeri già calcolati dai motori di
/// Prisma. Eve non deve rifare i conti: legge e spiega.
enum ContestoEve {
    static let limite = 4_200

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
        return parti.joined(separator: ", ")
    }
}
