import Foundation

/// Un bisogno che Prisma deduce dai dati del cliente, sempre con il motivo.
struct BisognoRilevato: Identifiable, Hashable {
    /// Identificativo stabile: serve a ricordare se il consulente l'ha confermato o scartato.
    let id: String
    let area: AreaBisogno
    let titolo: String
    let motivo: String
    let importanza: Importanza
}

/// Motore del profilo dei bisogni: rileva i bisogni dai dati e calcola la ruota.
/// Le regole sono semplici e dichiarate: ogni bisogno porta con sé il dato da cui nasce.
enum MotoreBisogni {

    static func rileva(cliente c: Cliente, posizioni: [Posizione], analisi: Analisi360, oggi: Date = Date()) -> [BisognoRilevato] {
        var elenco: [BisognoRilevato] = []
        let inEssere = posizioni.filter { $0.stato == .inEssere }
        func somma(_ a: AreaPosizione) -> Double { inEssere.filter { $0.area == a }.reduce(0) { $0 + $1.valore } }
        let debiti = somma(.debiti)
        let liquidita = somma(.liquidita)
        let investito = somma(.investimento) + somma(.risparmio)
        let immobili = somma(.immobili)
        let aCarico = c.famiglia.filter(\.aCarico)
        let minori = c.famiglia.filter { ($0.relazione == .figlio || $0.relazione == .figlia) && ($0.eta ?? 99) < 18 }
        let partner = c.famiglia.contains { $0.relazione == .coniuge || $0.relazione == .convivente }
        let eta = c.eta
        let annoCorrente = Calendar(identifier: .gregorian).component(.year, from: oggi)

        // Protezione della famiglia
        let prot = MotoreAnalisi.protezione(analisi.protezione, posizioni: posizioni)
        if prot.divario > 0 && (debiti > 0 || !aCarico.isEmpty || partner) {
            var chi: [String] = []
            if debiti > 0 { chi.append("debiti per \(Formati.euro(debiti))") }
            if !aCarico.isEmpty { chi.append("\(aCarico.count) \(aCarico.count == 1 ? "persona" : "persone") a carico") }
            if partner && aCarico.isEmpty { chi.append("un partner") }
            elenco.append(.init(id: "protezione-famiglia", area: .famiglia, titolo: "Proteggere la famiglia",
                                motivo: "Ci sono \(chi.joined(separator: " e ")); alle coperture caso morte mancano \(Formati.euro(prot.divario)).",
                                importanza: prot.divario > 100_000 ? .alta : .media))
        }
        // Riserva per gli imprevisti
        let spese = analisi.protezione.fabbisognoMensile
        if spese > 0 && liquidita < spese * 3 {
            elenco.append(.init(id: "riserva-imprevisti", area: .salute, titolo: "Una riserva per gli imprevisti",
                                motivo: "La liquidità (\(Formati.euro(liquidita))) copre \(String(format: "%.1f", liquidita / spese).replacingOccurrences(of: ".", with: ",")) mesi di spese: il riferimento è almeno 3-6 mesi.",
                                importanza: liquidita < spese ? .alta : .media))
        }
        // Rischi della persona scoperti
        let scoperti = [RischioCoperto.invalidita, .ltc, .salute].filter { !prot.rischiCoperti.contains($0) }
        if scoperti.count >= 2 && (eta ?? 0) >= 30 {
            elenco.append(.init(id: "rischi-persona", area: .salute, titolo: "Coprire i rischi della persona",
                                motivo: "Nessuna copertura per \(scoperti.map { $0.nome.lowercased() }.joined(separator: ", ")).",
                                importanza: (eta ?? 0) >= 45 || !aCarico.isEmpty ? .media : .bassa))
        }
        // Previdenza
        let prev = MotoreAnalisi.previdenza(analisi.previdenza)
        let piani = inEssere.filter { $0.area == .previdenza }
        if (eta ?? 0) < 65 {
            if piani.isEmpty {
                elenco.append(.init(id: "previdenza-assente", area: .pensione, titolo: "Avviare la previdenza integrativa",
                                    motivo: "Nessun piano previdenziale in essere; con le ipotesi attuali il divario alla pensione è di \(Formati.euro(prev.divario)) al mese.",
                                    importanza: (eta ?? 40) >= 35 ? .alta : .media))
            } else if prev.divarioResiduo > 200 {
                elenco.append(.init(id: "previdenza-divario", area: .pensione, titolo: "Rafforzare la previdenza",
                                    motivo: "I piani in essere coprono \(Formati.euro(prev.integrazione)) al mese: ne restano scoperti \(Formati.euro(prev.divarioResiduo)).",
                                    importanza: .media))
            }
        }
        // Studi dei figli
        if !minori.isEmpty && !inEssere.contains(where: { $0.area == .risparmio }) {
            elenco.append(.init(id: "studi-figli", area: .famiglia, titolo: "Accantonare per gli studi dei figli",
                                motivo: "\(minori.count == 1 ? "Un figlio minorenne" : "\(minori.count) figli minorenni") e nessun piano di risparmio dedicato.",
                                importanza: .media))
        }
        // Liquidità ferma
        if spese > 0 && liquidita > spese * 12 {
            elenco.append(.init(id: "liquidita-ferma", area: .patrimonio, titolo: "Far lavorare la liquidità in eccesso",
                                motivo: "La liquidità (\(Formati.euro(liquidita))) supera un anno di spese: la parte oltre la riserva perde valore con l'inflazione.",
                                importanza: .media))
        }
        // Successione
        if (eta ?? 0) >= 55 && immobili + investito > 200_000 {
            elenco.append(.init(id: "successione", area: .patrimonio, titolo: "Pianificare il passaggio del patrimonio",
                                motivo: "Patrimonio di \(Formati.euro(immobili + investito)) e \(eta ?? 0) anni: beneficiari, eredi e strumenti vanno messi in ordine.",
                                importanza: .media))
        }
        // Mutuo
        if let mutuo = inEssere.first(where: { $0.area == .debiti && $0.nome.lowercased().contains("mutuo") }), prot.divario > 0 {
            elenco.append(.init(id: "tutela-mutuo", area: .casa, titolo: "Mettere al sicuro la casa",
                                motivo: "\(mutuo.nome) con \(Formati.euro(mutuo.valore)) di debito residuo: se mancasse il reddito, la rata resterebbe alla famiglia.",
                                importanza: .media))
        }
        // Dagli eventi di vita
        for e in c.bisogni.eventi where e.anno >= annoCorrente - 1 {
            let quando = e.anno <= annoCorrente ? "quest'anno" : "nel \(e.anno)"
            switch e.tipo {
            case .acquistoCasa:
                elenco.append(.init(id: "evento-\(e.id)", area: .casa, titolo: "Preparare l'acquisto della casa",
                                    motivo: "Acquisto previsto \(quando): anticipo, spese notarili e mutuo da pianificare per tempo.", importanza: .alta))
            case .figlioInArrivo:
                elenco.append(.init(id: "evento-\(e.id)", area: .famiglia, titolo: "Accogliere un figlio",
                                    motivo: "Un figlio in arrivo \(quando): protezione del reddito e un primo accantonamento.", importanza: .alta))
            case .studiFigli:
                elenco.append(.init(id: "evento-\(e.id)", area: .famiglia, titolo: "Finanziare gli studi",
                                    motivo: "Studi in partenza \(quando): servono un obiettivo e un piano di versamenti.", importanza: .media))
            case .cambioLavoro, .avvioAttivita:
                elenco.append(.init(id: "evento-\(e.id)", area: .lavoro, titolo: e.tipo == .avvioAttivita ? "Proteggere la nuova attività" : "Rivedere reddito e coperture",
                                    motivo: "\(e.tipo.nome) \(quando): cambiano reddito, contributi e tutele.", importanza: .alta))
            case .pensione:
                elenco.append(.init(id: "evento-\(e.id)", area: .pensione, titolo: "Prepararsi alla pensione",
                                    motivo: "Uscita dal lavoro prevista \(quando): rendita, TFR e capitali da organizzare.", importanza: .alta))
            case .eredita:
                elenco.append(.init(id: "evento-\(e.id)", area: .patrimonio, titolo: "Collocare l'eredità",
                                    motivo: "Eredità o donazione \(quando): capire obiettivi e tempi prima di investire.", importanza: .media))
            case .separazione:
                elenco.append(.init(id: "evento-\(e.id)", area: .famiglia, titolo: "Rivedere beneficiari e coperture",
                                    motivo: "Separazione \(quando): beneficiari delle polizze e intestazioni da aggiornare.", importanza: .alta))
            case .matrimonio:
                elenco.append(.init(id: "evento-\(e.id)", area: .famiglia, titolo: "Progetti di coppia",
                                    motivo: "Matrimonio o convivenza \(quando): protezione reciproca e progetti comuni.", importanza: .media))
            case .altro:
                break
            }
        }
        return elenco
    }

    /// Bisogni rilevati ancora da valutare, confermati e scartati.
    static func daValutare(_ r: [BisognoRilevato], profilo: ProfiloBisogni) -> [BisognoRilevato] { r.filter { profilo.esiti[$0.id] == nil } }
    static func confermati(_ r: [BisognoRilevato], profilo: ProfiloBisogni) -> [BisognoRilevato] { r.filter { profilo.esiti[$0.id] == true } }

    /// Punteggio della ruota per area (0–3): il più alto tra l'importanza detta dal cliente
    /// e quella dei bisogni rilevati non scartati.
    static func ruota(_ r: [BisognoRilevato], profilo: ProfiloBisogni) -> [AreaBisogno: Importanza] {
        var esito: [AreaBisogno: Importanza] = [:]
        for a in AreaBisogno.allCases {
            let detta = profilo.valutazione(a).importanza
            let rilevata = r.filter { $0.area == a && profilo.esiti[$0.id] != false }.map(\.importanza).max() ?? .nessuna
            esito[a] = max(detta, rilevata)
        }
        return esito
    }

    /// Le aree in ordine di priorità (solo quelle che contano).
    static func priorita(_ r: [BisognoRilevato], profilo: ProfiloBisogni) -> [AreaBisogno] {
        let punteggi = ruota(r, profilo: profilo)
        return AreaBisogno.allCases
            .filter { (punteggi[$0] ?? .nessuna) > .nessuna }
            .sorted { (punteggi[$0] ?? .nessuna) > (punteggi[$1] ?? .nessuna) }
    }
}
