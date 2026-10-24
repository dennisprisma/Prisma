import Foundation

/// Il passaggio generazionale: cosa andrebbe agli eredi se mancasse oggi il cliente, con quali tempi,
/// cosa resta fuori dalla successione (polizze vita, capitali caso morte, previdenza: ai beneficiari)
/// e una stima delle imposte. Successione senza testamento (codice civile), regole semplificate:
/// una base per parlarne, non un parere legale o notarile.
struct Successione {
    enum Destino {
        /// Nell'asse ereditario: agli eredi, dopo la dichiarazione di successione.
        case asse
        /// Fuori dall'asse: ai beneficiari designati, senza imposta di successione.
        case beneficiari
    }

    struct Voce: Identifiable {
        let posizione: Posizione
        /// Quanto passa: il valore (per i debiti è negativo), il capitale assicurato per le coperture caso morte.
        let importo: Double
        let destino: Destino
        let motivo: String
        /// Cosa controllare su questa posizione (beneficiari mancanti, convivente escluso…).
        let avviso: String?
        var id: String { posizione.id }
    }

    struct Erede: Identifiable {
        let nome: String
        let relazione: Familiare.Relazione
        let quota: Double
        let importo: Double
        let franchigia: Double
        let aliquota: Double
        let imposta: Double
        let minorenne: Bool
        /// Posizione nell'elenco: due figli senza nome restano due righe distinte.
        var indice = 0
        var id: String { "\(indice)·\(nome)·\(relazione.rawValue)" }
    }

    let voci: [Voce]
    let eredi: [Erede]
    /// Nell'asse: attività (fondi, conti, immobili) e debiti.
    let attivoAsse: Double
    let debiti: Double
    var asseNetto: Double { max(0, attivoAsse - debiti) }
    let fuoriAsse: Double
    let immobili: Double
    /// Imposte ipotecaria e catastale sugli immobili (fisse se si può chiedere l'agevolazione prima casa).
    let ipocatastali: Double
    let primaCasa: Bool
    /// Il convivente non eredita senza testamento.
    let conviventeEscluso: String?
    let avvisi: [String]

    var impostaSuccessione: Double { eredi.reduce(0) { $0 + $1.imposta } }
    var imposte: Double { impostaSuccessione + ipocatastali }
    var totale: Double { asseNetto + fuoriAsse }
    var quotaFuori: Double { totale > 0 ? fuoriAsse / totale : 0 }
    var vuota: Bool { voci.isEmpty }
    var daSistemare: [Voce] { voci.filter { $0.avviso != nil } }
}

enum MotoreSuccessione {
    /// Franchigie e aliquote dell'imposta di successione (D.Lgs. 346/1990, aggiornato dal D.Lgs. 139/2024).
    static let franchigiaLineaRetta = 1_000_000.0
    static let aliquotaLineaRetta = 4.0
    static let franchigiaFratelli = 100_000.0
    static let aliquotaFratelli = 6.0
    static let aliquotaAltri = 8.0
    /// Ipotecaria 2% e catastale 1% sugli immobili; 200 € ciascuna con l'agevolazione prima casa.
    static let ipocatastale = 3.0
    static let ipocatastaleFissa = 400.0

    static func calcola(cliente c: Cliente, posizioni: [Posizione], oggi: Date = Date()) -> Successione {
        let inEssere = posizioni.filter { $0.stato == .inEssere && $0.clienteId == c.id }
        let nomiFamiglia = c.famiglia.map { $0.nome.lowercased() }
        let convivente = c.famiglia.first { $0.relazione == .convivente }
        let eredi = legittimi(c, oggi: oggi)
        var avvisi: [String] = []

        var voci: [Successione.Voce] = []
        for p in inEssere {
            let (importo, destino, motivo) = classifica(p, oggi: oggi)
            guard abs(importo) > 0.5 else { continue }
            var avviso: String?
            if destino == .beneficiari {
                let b = p.beneficiari.trimmingCharacters(in: .whitespacesAndNewlines)
                let minuscolo = b.lowercased()
                // Indicazioni generiche («i figli», «il coniuge») non sono nomi da confrontare con la famiglia
                let generico = ["eredi", "figli", "coniuge", "genitori", "fratelli"].contains { minuscolo.contains($0) }
                if b.isEmpty {
                    avviso = "Beneficiari non indicati: senza, il capitale va agli eredi legittimi."
                } else if minuscolo.contains("eredi"), let cv = convivente {
                    avviso = "«\(b)»: \(cv.nome), convivente, ne resterebbe escluso."
                } else if [StatoCivile.separato, .divorziato].contains(c.statoCivile ?? .celibeNubile),
                          !nomiFamiglia.contains(where: { minuscolo.contains($0) }), !generico {
                    avviso = "Beneficiario «\(b)» non tra i familiari registrati: verificare dopo la separazione."
                }
            }
            voci.append(.init(posizione: p, importo: importo, destino: destino, motivo: motivo, avviso: avviso))
        }

        let attivo = voci.filter { $0.destino == .asse && $0.importo > 0 }.reduce(0) { $0 + $1.importo }
        let debiti = -voci.filter { $0.destino == .asse && $0.importo < 0 }.reduce(0) { $0 + $1.importo }
        let fuori = voci.filter { $0.destino == .beneficiari }.reduce(0) { $0 + $1.importo }
        let immobiliVoci = voci.filter { $0.posizione.area == .immobili }
        let immobili = immobiliVoci.reduce(0) { $0 + $1.importo }
        // L'agevolazione prima casa vale per una sola abitazione: la più preziosa
        let abitazione = immobiliVoci.filter { v in
            let n = (v.posizione.nome + " " + v.posizione.tipologia).lowercased()
            return n.contains("abitazione") || n.contains("prima casa")
        }.max { $0.importo < $1.importo }
        let primaCasa = abitazione != nil && !eredi.isEmpty
        let ipocatastali = (primaCasa ? ipocatastaleFissa : 0)
            + immobiliVoci.filter { !(primaCasa && $0.id == abitazione?.id) }.reduce(0) { $0 + max(400, $1.importo * ipocatastale / 100) }

        let netto = max(0, attivo - debiti)
        let calcolati = eredi.enumerated().map { i, e -> Successione.Erede in
            let importo = netto * e.quota
            let (franchigia, aliquota) = regola(e.relazione)
            return .init(nome: e.nome, relazione: e.relazione, quota: e.quota, importo: importo, franchigia: franchigia, aliquota: aliquota,
                         imposta: max(0, importo - franchigia) * aliquota / 100, minorenne: e.minorenne, indice: i)
        }

        if eredi.isEmpty, netto > 0 {
            avvisi.append("Nessun erede tra i familiari registrati: senza testamento l'asse andrebbe ai parenti più vicini fino al sesto grado, o allo Stato.")
        }
        if let cv = convivente, c.statoCivile != .coniugato {
            avvisi.append("\(cv.nome), convivente, non eredita senza testamento: per tutelarlo servono un testamento (nei limiti della legittima) o polizze con beneficiario designato.")
        }
        if calcolati.contains(where: \.minorenne), netto > 0 {
            avvisi.append("Tra gli eredi ci sono minorenni: per accettare l'eredità serve l'autorizzazione del giudice tutelare, e i tempi si allungano.")
        }
        if fuori > 0, netto > 0 {
            avvisi.append("I conti cointestati e individuali si bloccano fino alla dichiarazione di successione (di solito alcuni mesi); polizze e previdenza si liquidano ai beneficiari in poche settimane.")
        }
        return Successione(voci: voci.sorted { ($0.destino == .beneficiari ? 0 : 1, -abs($0.importo)) < ($1.destino == .beneficiari ? 0 : 1, -abs($1.importo)) },
                           eredi: calcolati, attivoAsse: attivo, debiti: debiti, fuoriAsse: fuori, immobili: immobili,
                           ipocatastali: ipocatastali, primaCasa: primaCasa,
                           conviventeEscluso: c.statoCivile == .coniugato ? nil : convivente?.nome, avvisi: avvisi)
    }

    /// Dove va una posizione: importo, destino e perché.
    static func classifica(_ p: Posizione, oggi: Date = Date()) -> (Double, Successione.Destino, String) {
        switch p.area {
        case .protezione:
            // Caso morte anche senza il rischio indicato, se il nome lo dice; una copertura scaduta non paga più
            let testo = (p.nome + " " + p.tipologia).lowercased()
            let casoMorte = p.rischio == .vita || (p.rischio == nil && (testo.contains("caso morte") || testo.contains("tcm") || testo.contains("temporanea")))
            guard casoMorte, let capitale = p.capitaleAssicurato, p.scadenza.map({ $0 >= oggi }) ?? true else { return (0, .beneficiari, "") }
            return (capitale, .beneficiari, "Capitale caso morte: ai beneficiari, esente da imposta di successione.")
        case .previdenza:
            return (p.valore, .beneficiari, "Previdenza complementare: ai beneficiari o agli eredi, fuori dall'asse; tassazione agevolata.")
        case .debiti:
            return (-p.valore, .asse, "Debito: si sottrae dall'asse, passa agli eredi che accettano.")
        case .immobili:
            return (p.valore, .asse, "Immobile: nell'asse; imposte ipotecaria e catastale.")
        case .liquidita:
            return (p.valore, .asse, "Conto: nell'asse, bloccato fino alla dichiarazione di successione.")
        case .investimento, .risparmio:
            // Il contratto di capitalizzazione non assicura una vita: entra nell'asse e paga l'imposta
            if (p.nome + " " + p.tipologia).lowercased().contains("capitalizzazione") {
                return (p.valore, .asse, "Contratto di capitalizzazione: nell'asse ereditario, non è una polizza vita.")
            }
            if p.regime == .polizza {
                return (p.valore, .beneficiari, "Polizza vita: ai beneficiari, fuori dall'asse ed esente da imposta di successione.")
            }
            return (p.valore, .asse, "Fondi e titoli: nell'asse ereditario.")
        }
    }

    /// Franchigia e aliquota dell'imposta per grado di parentela.
    static func regola(_ r: Familiare.Relazione) -> (Double, Double) {
        switch r {
        case .coniuge, .figlio, .figlia, .genitore: return (franchigiaLineaRetta, aliquotaLineaRetta)
        case .fratelloSorella: return (franchigiaFratelli, aliquotaFratelli)
        case .convivente, .altro: return (0, aliquotaAltri)
        }
    }

    /// Gli eredi legittimi tra i familiari registrati, con la loro quota (successione senza testamento).
    static func legittimi(_ c: Cliente, oggi: Date = Date()) -> [(nome: String, relazione: Familiare.Relazione, quota: Double, minorenne: Bool)] {
        func minorenne(_ f: Familiare) -> Bool {
            guard let n = f.dataNascita else { return false }
            return (Calendar.current.dateComponents([.year], from: n, to: oggi).year ?? 18) < 18
        }
        // Stato civile non indicato: vale il coniuge registrato in famiglia
        let coniuge = c.statoCivile == nil || c.statoCivile == .coniugato || c.statoCivile == .separato ? c.famiglia.first { $0.relazione == .coniuge } : nil
        let figli = c.famiglia.filter { $0.relazione == .figlio || $0.relazione == .figlia }
        let genitori = c.famiglia.filter { $0.relazione == .genitore }
        let fratelli = c.famiglia.filter { $0.relazione == .fratelloSorella }
        var r: [(String, Familiare.Relazione, Double, Bool)] = []
        func dividi(_ persone: [Familiare], _ totale: Double) {
            for f in persone { r.append((f.nome, f.relazione, totale / Double(persone.count), minorenne(f))) }
        }
        if !figli.isEmpty {
            if let co = coniuge {
                let quotaConiuge = figli.count == 1 ? 0.5 : 1.0 / 3
                r.append((co.nome, .coniuge, quotaConiuge, minorenne(co)))
                dividi(figli, 1 - quotaConiuge)
            } else {
                dividi(figli, 1)
            }
        } else if let co = coniuge {
            let altri = genitori + fratelli
            r.append((co.nome, .coniuge, altri.isEmpty ? 1 : 2.0 / 3, minorenne(co)))
            if genitori.isEmpty || fratelli.isEmpty {
                if !altri.isEmpty { dividi(altri, 1.0 / 3) }
            } else {
                // Agli ascendenti almeno un quarto dell'eredità (art. 582 c.c.), il resto del terzo ai fratelli
                let aiGenitori = max(0.25, 1.0 / 3 * Double(genitori.count) / Double(altri.count))
                dividi(genitori, aiGenitori)
                dividi(fratelli, 1.0 / 3 - aiGenitori)
            }
        } else if !genitori.isEmpty || !fratelli.isEmpty {
            // Genitori e fratelli per capi, ai genitori almeno la metà (semplificato)
            if fratelli.isEmpty { dividi(genitori, 1) }
            else if genitori.isEmpty { dividi(fratelli, 1) }
            else {
                let aiGenitori = max(0.5, Double(genitori.count) / Double(genitori.count + fratelli.count))
                dividi(genitori, aiGenitori)
                dividi(fratelli, 1 - aiGenitori)
            }
        }
        return r.map { (nome: $0.0, relazione: $0.1, quota: $0.2, minorenne: $0.3) }
    }

    /// Le righe per Eve e per le schede.
    static func sintesi(_ s: Successione) -> [String] {
        var righe: [String] = []
        righe.append("Fuori dalla successione, ai beneficiari: \(Formati.euro(s.fuoriAsse)) (\(CifreDoc.percento(s.quotaFuori * 100, decimali: 0)) di quanto passerebbe), in poche settimane.")
        righe.append("Nell'asse ereditario: \(Formati.euro(s.attivoAsse)) di attività meno \(Formati.euro(s.debiti)) di debiti, \(Formati.euro(s.asseNetto)) netti agli eredi dopo la dichiarazione di successione.")
        if !s.eredi.isEmpty {
            righe.append("Eredi senza testamento: " + s.eredi.map { "\($0.nome) (\($0.relazione.nome.lowercased()), \(frazione($0.quota)), \(Formati.euro($0.importo)))" }.joined(separator: "; ") + ".")
        }
        righe.append(s.imposte > 0.5
            ? "Imposte stimate: \(Formati.euro(s.impostaSuccessione)) di successione e \(Formati.euro(s.ipocatastali)) ipotecaria e catastale."
            : "Imposta di successione: nessuna, entro le franchigie.")
        for v in s.daSistemare.prefix(3) { righe.append("Da sistemare, \(v.posizione.nome): \(v.avviso ?? "")") }
        return righe
    }

    /// Quote leggibili: ½, ⅓, ⅔, oppure la percentuale.
    static func frazione(_ q: Double) -> String {
        let note: [(Double, String)] = [(1, "tutto"), (0.5, "metà"), (1.0 / 3, "un terzo"), (2.0 / 3, "due terzi"), (0.25, "un quarto"), (1.0 / 6, "un sesto")]
        return note.first { abs($0.0 - q) < 0.001 }?.1 ?? CifreDoc.percento(q * 100, decimali: 0)
    }
}

extension Posizione {
    /// Beneficiari non indicati (campo vuoto o solo spazi).
    var senzaBeneficiari: Bool { beneficiari.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
