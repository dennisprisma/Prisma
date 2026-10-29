import Foundation

/// Aggiornamento dei valori in blocco: dagli elenchi ed estratti della compagnia (Excel, CSV, appunti) o
/// dalla griglia dei valori fermi, con le stesse regole del singolo estratto conto (`ValoriDaDocumento`).
/// Tutto in locale. Motore puro: niente stato, niente Shell; `oggi` arriva sempre come parametro.
enum AggiornaValori {
    /// Mesi oltre i quali il valore di una posizione è fermo: lo stesso anno del riesame.
    static var mesiValoreFermo: Int { MotoreRiesame.mesiRiesame }
    /// Variazione (%, sul valore di prima, al netto dei versamenti se noti) oltre la quale la riga va controllata.
    static let sogliaInsolita = 25.0
}

// MARK: - Tipi di lavoro (non salvati)

extension AggiornaValori {
    /// Le due schede del pannello.
    enum Scheda: String, CaseIterable { case elenco, griglia }

    /// Una riga da registrare: dal file (id = numero della riga sotto l'intestazione, da 1) o dalla griglia
    /// (id = posto nella griglia, da 1, con la posizione già nota).
    struct Riga: Identifiable, Equatable {
        let id: Int
        var cliente = ""
        var codiceFiscale = ""
        var numeroContratto = ""
        var prodotto = ""
        var emittente = ""
        /// Il valore letto; nil se la cella è vuota o non è un numero.
        var valore: Double?
        /// La data del valore; nil se la cella è vuota (vale la data comune).
        var data: Date?
        /// La cella della data c'è ma non si legge.
        var dataIllegibile = false
        var versato: Double?
        /// Parte del valore in gestione separata (€), per le multiramo.
        var valoreGestione: Double?
        /// Nella griglia la posizione è già nota.
        var posizioneId: String?
    }

    /// Come la riga è stata abbinata alla posizione.
    enum Abbinamento: String { case numero, nome, scelta, griglia }

    /// Che cosa succede alla riga.
    enum Stato: String, CaseIterable {
        case aggiorna        // diventa il valore attuale (quello di prima va nello storico)
        case storico         // più vecchia del valore attuale: tra i valori passati
        case giaRegistrato   // lo storico ha già questo valore in quel giorno
        case daScegliere     // più posizioni possibili, o il numero è di un altro cliente
        case nonTrovata
        case nonInEssere     // chiusa o proposta
        case copertura       // protezione o debito: niente valore da qui
        case senzaValore     // valore mancante o data illeggibile
        case dataFutura      // proiezione, non valore rilevato
        case ripetuta        // stessa posizione e stesso giorno di una riga sopra
        var applicabile: Bool { self == .aggiorna || self == .storico }
    }

    struct Esito: Identifiable, Equatable {
        var id: Int { riga.id }
        let riga: Riga
        var stato: Stato
        var posizioneId: String?
        /// Le posizioni tra cui scegliere (stato .daScegliere), in ordine di nome.
        var candidate: [String] = []
        var abbinamento: Abbinamento?
        /// La data effettiva (della riga o comune), a mezzogiorno.
        var data: Date?
        /// Il valore attuale della posizione prima di questa riga e la sua data di riferimento.
        var precedente: Double?
        var dataPrecedente: Date?
        var versatoPrima: Double?
        /// Il versato dopo la riga: quello del file o quello stimato da `ValoriDaDocumento.applica`.
        var versatoDopo: Double?
        var versatoStimato = false
        /// Stesso giorno del valore attuale, importo diverso: lo corregge.
        var correzione = false
        /// Nuova quota in gestione separata (0–100), solo multiramo con la colonna.
        var quotaGestione: Double?
        // Calcolate (§3.4), valorizzate solo per .aggiorna
        var variazione: Double?
        var variazionePct: Double?
        var versamenti: Double?
        var risultato: Double?
        var risultatoPct: Double?
        var mesi: Int?
        var insolita = false
    }

    /// Una casella della griglia, com'è scritta (testo): si legge solo al calcolo.
    struct Bozza: Equatable {
        var valore = ""
        var data = ""
        var versato = ""
        var vuota: Bool { valore.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Totale di un gruppo di posizioni aggiornate (un canale o tutte).
    struct Totale: Equatable {
        var posizioni = 0
        var prima = 0.0
        var dopo = 0.0
        /// Somma dei versamenti del periodo dove il versato è noto prima e dopo.
        var versamenti = 0.0
        var variazione: Double { dopo - prima }
        var variazionePct: Double? { prima > 0 ? variazione / prima * 100 : nil }
        var risultato: Double { variazione - versamenti }
        var risultatoPct: Double? { prima > 0 ? risultato / prima * 100 : nil }
    }

    /// Che cosa è stato registrato.
    struct Riepilogo: Equatable {
        var attuali = 0
        var storico = 0
        /// Le posizioni toccate, nell'ordine della prima riga registrata.
        var posizioni: [String] = []
        var totale = Totale()
        var perCanale: [Canale: Totale] = [:]
    }

    /// Lo stato del pannello in Posizioni (in `StatoShell.aggiornaValori`).
    struct Sessione: Identifiable {
        let id = UUID()
        var scheda: Scheda
        /// Scheda «Da un elenco»: nome del file, colonne riconosciute, righe lette e tabella originale.
        var file = ""
        var colonne: [ImportaPosizioni.Colonna] = []
        var righe: [Riga] = []
        var tabella: [[String]] = []
        /// true se ci si arriva dall'importazione (Prisma ha proposto l'aggiornamento).
        var proposta = false
        /// La data dei valori senza data (elenco) e delle caselle senza data (griglia).
        var dataComune = ValoriDaDocumento.mezzogiorno(Date())
        /// Griglia: caselle già scritte all'apertura (solo per le istantanee), filtro iniziale.
        var bozze: [String: Bozza] = [:]
        var soloCliente: String?
        /// Dopo «Registra»: il riepilogo, al posto della tabella.
        var riepilogo: Riepilogo?
        /// Le scelte fatte nel pannello, conservate quando il dettaglio di una posizione lo copre («Apri ↗»):
        /// posizioni scelte a mano, righe escluse (nil = quelle iniziali) e canale della griglia.
        var scelte: [Int: String] = [:]
        var esclusi: Set<Int>?
        var canale: Canale?
    }
}

// MARK: - Lettura del file (§3.1)

extension AggiornaValori {
    /// Le righe con un valore o un numero di contratto: intestazione nella prima, colonne come l'importazione.
    static func righe(_ tabella: [[String]]) -> (colonne: [ImportaPosizioni.Colonna], righe: [Riga]) {
        guard let testa = tabella.first else { return ([], []) }
        // Ogni colonna vale alla sua prima occorrenza, come in `ImportaPosizioni.daRighe`
        var usate: [ImportaPosizioni.Colonna: Int] = [:]
        for (i, h) in testa.enumerated() {
            if let c = ImportaPosizioni.Colonna.da(h), usate[c] == nil { usate[c] = i }
        }
        let colonne = usate.keys.sorted { (usate[$0] ?? 0) < (usate[$1] ?? 0) }
        var elenco: [Riga] = []
        for i in tabella.indices.dropFirst() {
            let r = tabella[i]
            func v(_ c: ImportaPosizioni.Colonna) -> String {
                guard let j = usate[c], j < r.count else { return "" }
                return r[j].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let numero = v(.numeroContratto)
            let prodotto = v(.prodotto).isEmpty ? v(.tipologia) : v(.prodotto)
            let cellaValore = v(.controvalore)
            // Righe di totale e righe vuote
            if numero.isEmpty && prodotto.isEmpty && cellaValore.isEmpty { continue }
            var x = Riga(id: i)
            x.cliente = v(.cliente).isEmpty ? [v(.nome), v(.cognome)].filter { !$0.isEmpty }.joined(separator: " ") : v(.cliente)
            x.codiceFiscale = compatto(v(.codiceFiscale))
            x.numeroContratto = numero
            x.prodotto = prodotto
            x.emittente = v(.emittente)
            x.valore = cellaValore.isEmpty ? nil : EstrattoreDocumento.numero(cellaValore)
            let cellaData = v(.dataValore)
            if !cellaData.isEmpty {
                if let d = ImportaClienti.data(cellaData) {
                    x.data = ValoriDaDocumento.mezzogiorno(d)
                } else {
                    x.dataIllegibile = true
                }
            }
            let cellaVersato = v(.versato)
            x.versato = cellaVersato.isEmpty ? nil : EstrattoreDocumento.numero(cellaVersato)
            let cellaGestione = v(.valoreGestione)
            x.valoreGestione = cellaGestione.isEmpty ? nil : EstrattoreDocumento.numero(cellaGestione)
            elenco.append(x)
        }
        return (colonne, elenco)
    }

    /// Una sessione «Da un elenco», nil se nel file non c'è nessuna riga utile o manca la colonna del valore.
    static func sessione(tabella: [[String]], file: String, dataComune: Date, proposta: Bool = false) -> Sessione? {
        let letto = righe(tabella)
        guard letto.colonne.contains(.controvalore), !letto.righe.isEmpty else { return nil }
        var s = Sessione(scheda: .elenco)
        s.file = file
        s.colonne = letto.colonne
        s.righe = letto.righe
        s.tabella = tabella
        s.proposta = proposta
        s.dataComune = ValoriDaDocumento.mezzogiorno(dataComune)
        return s
    }
}

// MARK: - Abbinamento (§3.2)

extension AggiornaValori {
    /// Una posizione può ricevere un valore: in essere, né copertura né debito (come `ValoriDaDocumento.candidate`).
    static func candidabile(_ p: Posizione) -> Bool { p.stato == .inEssere && p.area != .protezione && !p.area.passivo }

    /// La posizione di una riga del file: per numero di contratto, poi per cliente e nome del prodotto.
    static func abbina(_ r: Riga, posizioni: [Posizione], clienti: [Cliente])
        -> (stato: Stato?, posizione: Posizione?, candidate: [Posizione], abbinamento: Abbinamento?) {
        let t = trova(r, posizioni: posizioni, clienti: clienti, indici: Indici(posizioni))
        return (stato: t.stato, posizione: t.posizione, candidate: t.candidate, abbinamento: t.abbinamento)
    }

    /// Gli indici costruiti una volta: per id, per numero di contratto compatto e per cliente.
    private struct Indici {
        var perId: [String: Int] = [:]
        var perNumero: [String: [Int]] = [:]
        var perCliente: [String: [Int]] = [:]

        init(_ posizioni: [Posizione]) {
            for (i, p) in posizioni.enumerated() {
                if perId[p.id] == nil { perId[p.id] = i }
                let n = AggiornaValori.compatto(p.numeroContratto)
                if !n.isEmpty { perNumero[n, default: []].append(i) }
                perCliente[p.clienteId, default: []].append(i)
            }
        }
    }

    /// L'esito dell'abbinamento: stato nil = abbinata a `posizione`.
    private struct Trovata {
        var stato: Stato?
        var posizione: Posizione?
        var candidate: [Posizione] = []
        var abbinamento: Abbinamento?
    }

    private static func trova(_ r: Riga, posizioni: [Posizione], clienti: [Cliente], indici: Indici) -> Trovata {
        let cliente = ImportaPosizioni.abbina(nome: r.cliente, codiceFiscale: r.codiceFiscale, clienti: clienti)
        let numero = compatto(r.numeroContratto)

        // 1. Il numero di contratto, di qualunque stato e cliente
        if !numero.isEmpty {
            var stessi = (indici.perNumero[numero] ?? []).map { posizioni[$0] }
            if let c = cliente, !stessi.isEmpty {
                let suoi = stessi.filter { $0.clienteId == c.id }
                if suoi.isEmpty {
                    // Il numero è di un altro cliente: si sceglie a mano
                    let candidate = ordinate(stessi.filter(candidabile))
                    return candidate.isEmpty ? Trovata(stato: .nonTrovata) : Trovata(stato: .daScegliere, candidate: candidate)
                }
                stessi = suoi
            }
            if stessi.count > 1 {
                let compagnia = parole(r.emittente)
                if !compagnia.isEmpty {
                    let stesse = stessi.filter { parole($0.emittente).contains(compagnia) }
                    if !stesse.isEmpty { stessi = stesse }
                }
            }
            if stessi.count > 1 {
                let inEssere = stessi.filter { $0.stato == .inEssere }
                if inEssere.count == 1 { stessi = inEssere }
            }
            if stessi.count == 1, let p = stessi.first {
                if p.stato != .inEssere { return Trovata(stato: .nonInEssere, posizione: p, abbinamento: .numero) }
                if p.area == .protezione || p.area.passivo { return Trovata(stato: .copertura, posizione: p, abbinamento: .numero) }
                return Trovata(posizione: p, abbinamento: .numero)
            }
            if stessi.count > 1 {
                let candidate = ordinate(stessi.filter(candidabile))
                if !candidate.isEmpty { return Trovata(stato: .daScegliere, candidate: candidate) }
                // Nessuna può ricevere un valore: chiuse o coperture con lo stesso numero
                let p = stessi[0]
                let stato: Stato = p.stato != .inEssere ? .nonInEssere : .copertura
                return Trovata(stato: stato, posizione: p, abbinamento: .numero)
            }
        }

        // 2. Cliente e nome del prodotto; mai una posizione con un altro numero di contratto
        guard let c = cliente else { return Trovata(stato: .nonTrovata) }
        let elenco = (indici.perCliente[c.id] ?? []).map { posizioni[$0] }
            .filter { candidabile($0) && (numero.isEmpty || compatto($0.numeroContratto).isEmpty) }
        let n = parole(r.prodotto)
        guard !n.isEmpty else { return Trovata(stato: .nonTrovata) }
        let uguali = elenco.filter { parole($0.nome) == n }
        if uguali.count == 1 { return Trovata(posizione: uguali[0], abbinamento: .nome) }
        if uguali.count > 1 { return Trovata(stato: .daScegliere, candidate: ordinate(uguali)) }
        // A parole intere, in un senso o nell'altro: vince il nome più lungo, mai a caso tra due uguali
        let contenute = elenco.filter { p in
            let suo = parole(p.nome)
            return !suo.isEmpty && (" \(n) ".contains(" \(suo) ") || " \(suo) ".contains(" \(n) "))
        }
        guard let massimo = contenute.map({ parole($0.nome).count }).max() else { return Trovata(stato: .nonTrovata) }
        let migliori = contenute.filter { parole($0.nome).count == massimo }
        if migliori.count == 1 { return Trovata(posizione: migliori[0], abbinamento: .nome) }
        return Trovata(stato: .daScegliere, candidate: ordinate(migliori))
    }

    /// Le candidate per nome, poi per id.
    private static func ordinate(_ elenco: [Posizione]) -> [Posizione] {
        elenco.sorted { a, b in
            let c = a.nome.localizedStandardCompare(b.nome)
            return c != .orderedSame ? c == .orderedAscending : a.id < b.id
        }
    }

    /// Maiuscolo, solo lettere e cifre (numeri di contratto, codici fiscali).
    static func compatto(_ s: String) -> String { s.uppercased().filter { $0.isLetter || $0.isNumber } }

    /// Senza maiuscole né accenti, parole unite da uno spazio.
    private static func parole(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
            .split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }
}

// MARK: - Esiti (§3.3, §3.4)

extension AggiornaValori {
    /// Gli esiti di tutte le righe, nell'ordine del file. `scelte`: riga → posizione scelta a mano (righe
    /// .daScegliere). Le righe in `esclusi` non spostano le altre (non entrano nella catena della posizione).
    static func esiti(_ righe: [Riga], posizioni: [Posizione], clienti: [Cliente], dataComune: Date, oggi: Date,
                      scelte: [Int: String] = [:], esclusi: Set<Int> = []) -> [Esito] {
        let cal = Calendar.current
        let indici = Indici(posizioni)
        let comune = ValoriDaDocumento.mezzogiorno(dataComune)
        let inizioOggi = cal.startOfDay(for: oggi)
        var esiti: [Esito] = []
        esiti.reserveCapacity(righe.count)
        // true finché la riga non ha uno stato (va nella catena della sua posizione)
        var aperti: [Bool] = []
        aperti.reserveCapacity(righe.count)

        // 1–2. Valore, data e posizione
        for r in righe {
            let data = r.data ?? comune
            var e = Esito(riga: r, stato: .senzaValore)
            e.data = data
            e.posizioneId = r.posizioneId
            var aperto = false
            if r.valore == nil || (r.valore ?? 0) < 0 || r.dataIllegibile {
                e.stato = .senzaValore
            } else if cal.startOfDay(for: data) > inizioOggi {
                e.stato = .dataFutura
            } else if let id = r.posizioneId {
                if indici.perId[id] != nil {
                    e.abbinamento = .griglia
                    aperto = true
                } else {
                    e.stato = .nonTrovata
                    e.posizioneId = nil
                }
            } else if let id = scelte[r.id], let i = indici.perId[id], candidabile(posizioni[i]) {
                e.posizioneId = id
                e.abbinamento = .scelta
                // Le candidate restano, per cambiare la scelta
                e.candidate = trova(r, posizioni: posizioni, clienti: clienti, indici: indici).candidate.map(\.id)
                aperto = true
            } else {
                let t = trova(r, posizioni: posizioni, clienti: clienti, indici: indici)
                e.abbinamento = t.abbinamento
                if let s = t.stato {
                    e.stato = s
                    e.candidate = t.candidate.map(\.id)
                    // Il nome della posizione si mostra anche se non riceve il valore
                    e.posizioneId = s == .nonInEssere || s == .copertura ? t.posizione?.id : nil
                } else if let p = t.posizione {
                    e.posizioneId = p.id
                    aperto = true
                } else {
                    e.stato = .nonTrovata
                }
            }
            esiti.append(e)
            aperti.append(aperto)
        }

        // 3. Ripetute: stessa posizione e stesso giorno di una riga sopra (vince la più in alto)
        var viste = Set<String>()
        for i in esiti.indices where aperti[i] {
            guard let id = esiti[i].posizioneId, let d = esiti[i].data else { continue }
            let chiave = "\(id)|\(cal.startOfDay(for: d).timeIntervalSinceReferenceDate)"
            if !viste.insert(chiave).inserted {
                esiti[i].stato = .ripetuta
                aperti[i] = false
            }
        }

        // 4. Catena per posizione, in ordine di data, su una copia della posizione
        var gruppi: [String: [Int]] = [:]
        var ordine: [String] = []
        for i in esiti.indices where aperti[i] {
            guard let id = esiti[i].posizioneId else { continue }
            if gruppi[id] == nil { ordine.append(id) }
            gruppi[id, default: []].append(i)
        }
        for id in ordine {
            guard let k = indici.perId[id] else { continue }
            var w = posizioni[k]
            let elenco = (gruppi[id] ?? []).sorted { a, b in
                let da = esiti[a].data ?? .distantPast
                let db = esiti[b].data ?? .distantPast
                return da != db ? da < db : esiti[a].riga.id < esiti[b].riga.id
            }
            for i in elenco {
                let r = esiti[i].riga
                guard let valore = r.valore, let data = esiti[i].data else { continue }
                let v = ValoriDaDocumento.Valore(data: data, valore: valore, versato: r.versato)
                if ValoriDaDocumento.registrato(v, in: w) {
                    esiti[i].stato = .giaRegistrato
                    continue
                }
                // Senza la data del valore, quello attuale vale dal giorno in cui la posizione è stata inserita
                let riferimento = w.dataValore ?? (w.controvalore == nil ? nil : w.creataIl)
                esiti[i].precedente = w.controvalore
                esiti[i].dataPrecedente = riferimento
                esiti[i].versatoPrima = w.totaleVersato
                var t = w
                switch ValoriDaDocumento.applica(v, a: &t) {
                case .attuale:
                    esiti[i].stato = .aggiorna
                    esiti[i].correzione = riferimento.map { cal.isDate($0, inSameDayAs: data) } ?? false
                    esiti[i].versatoDopo = t.totaleVersato
                    esiti[i].versatoStimato = r.versato == nil && t.totaleVersato != w.totaleVersato
                    if let g = r.valoreGestione, t.multiramo, let q = quotaGestione(valore: valore, gestione: g) {
                        esiti[i].quotaGestione = q
                        t.quotaGestioneSeparata = q
                    }
                    calcolaVariazione(&esiti[i], calendario: cal)
                case .passato:
                    esiti[i].stato = .storico
                }
                // Una riga esclusa non sposta le altre
                if !esclusi.contains(r.id) { w = t }
            }
        }
        return esiti
    }

    /// Variazione, versamenti del periodo, risultato al netto e riga insolita (§3.4).
    private static func calcolaVariazione(_ e: inout Esito, calendario cal: Calendar) {
        guard let v1 = e.riga.valore else { return }
        if let v0 = e.precedente {
            let delta = v1 - v0
            e.variazione = delta
            if v0 > 0 { e.variazionePct = delta / v0 * 100 }
            if let w0 = e.versatoPrima, let w1 = e.versatoDopo {
                let f = w1 - w0
                e.versamenti = f
                e.risultato = delta - f
                if v0 > 0 { e.risultatoPct = (delta - f) / v0 * 100 }
            }
        }
        if let d0 = e.dataPrecedente, let d1 = e.data {
            e.mesi = cal.dateComponents([.month], from: d0, to: d1).month
        }
        let zero = v1 == 0 && (e.precedente ?? 0) > 0
        let pct = e.risultatoPct ?? e.variazionePct
        e.insolita = zero || (pct.map { abs($0) > sogliaInsolita } ?? false)
    }

    /// Le righe che partono escluse: quelle con il valore a zero su una posizione che valeva qualcosa
    /// (riscattata o scaduta: si chiude dalla scheda, non si azzera da qui).
    static func esclusiIniziali(_ esiti: [Esito]) -> Set<Int> {
        Set(esiti.filter { $0.stato == .aggiorna && $0.riga.valore == 0 && ($0.precedente ?? 0) > 0 }.map(\.id))
    }

    /// Quota (0–100, un decimale) della parte in gestione separata sul valore di oggi; nil se non ha senso.
    static func quotaGestione(valore: Double, gestione: Double) -> Double? {
        guard valore > 0, gestione >= 0, gestione <= valore else { return nil }
        return (gestione / valore * 1000).rounded() / 10
    }

    /// Le righe da registrare adesso: applicabili, non escluse e non già nello storico (il numero del pulsante).
    static func daRegistrare(_ esiti: [Esito], esclusi: Set<Int>) -> Int {
        esiti.filter { $0.stato.applicabile && !esclusi.contains($0.id) }.count
    }
}

// MARK: - Registrazione (§3.5)

extension AggiornaValori {
    /// Registra nelle posizioni le righe applicabili non escluse, nell'ordine (data, riga) di ogni posizione,
    /// con `ValoriDaDocumento.applica` e la quota della gestione separata. Ricontrolla `registrato` sui dati veri
    /// (un secondo clic non duplica niente). Restituisce il riepilogo.
    @discardableResult
    static func applica(_ esiti: [Esito], esclusi: Set<Int>, a posizioni: inout [Posizione]) -> Riepilogo {
        var riepilogo = Riepilogo()
        var indice: [String: Int] = [:]
        for (i, p) in posizioni.enumerated() where indice[p.id] == nil { indice[p.id] = i }

        // Le righe per posizione (indici in `esiti`), nell'ordine in cui le posizioni compaiono
        var gruppi: [String: [Int]] = [:]
        var ordine: [String] = []
        for (j, e) in esiti.enumerated() where e.stato.applicabile && !esclusi.contains(e.id) {
            guard let id = e.posizioneId, e.riga.valore != nil, e.data != nil, indice[id] != nil else { continue }
            if gruppi[id] == nil { ordine.append(id) }
            gruppi[id, default: []].append(j)
        }

        var primaRiga: [String: Int] = [:]
        for id in ordine {
            guard let k = indice[id] else { continue }
            let originale = posizioni[k]
            var p = originale
            var attuale = false
            let righe = (gruppi[id] ?? []).sorted { a, b in
                let da = esiti[a].data ?? .distantPast
                let db = esiti[b].data ?? .distantPast
                return da != db ? da < db : esiti[a].riga.id < esiti[b].riga.id
            }
            for j in righe {
                let e = esiti[j]
                guard let valore = e.riga.valore, let data = e.data else { continue }
                let v = ValoriDaDocumento.Valore(data: data, valore: valore, versato: e.riga.versato)
                if ValoriDaDocumento.registrato(v, in: p) { continue }
                switch ValoriDaDocumento.applica(v, a: &p) {
                case .attuale:
                    riepilogo.attuali += 1
                    attuale = true
                    if let q = e.quotaGestione, p.multiramo { p.quotaGestioneSeparata = q }
                case .passato:
                    riepilogo.storico += 1
                }
                primaRiga[id] = min(primaRiga[id] ?? j, j)
            }
            if p != originale { posizioni[k] = p }
            // Totali: solo le posizioni con un valore attuale nuovo, prima di tutto e dopo tutto
            if attuale {
                aggiungi(&riepilogo.totale, prima: originale, dopo: p)
                var t = riepilogo.perCanale[originale.canale] ?? Totale()
                aggiungi(&t, prima: originale, dopo: p)
                riepilogo.perCanale[originale.canale] = t
            }
        }
        riepilogo.posizioni = primaRiga.keys.sorted { (primaRiga[$0] ?? 0) < (primaRiga[$1] ?? 0) }
        return riepilogo
    }

    private static func aggiungi(_ t: inout Totale, prima: Posizione, dopo: Posizione) {
        t.posizioni += 1
        t.prima += prima.controvalore ?? 0
        t.dopo += dopo.controvalore ?? 0
        if let a = prima.totaleVersato, let b = dopo.totaleVersato { t.versamenti += b - a }
    }

    /// Il riepilogo che `applica` darebbe, calcolato su una copia: per gli indicatori prima di registrare.
    /// Si chiama solo quando cambiano scelte, esclusioni o data comune (non a ogni battuta della griglia).
    static func anteprima(_ esiti: [Esito], esclusi: Set<Int>, posizioni: [Posizione]) -> Riepilogo {
        var copia = posizioni
        return applica(esiti, esclusi: esclusi, a: &copia)
    }
}

// MARK: - Griglia dei valori fermi (§3.6)

extension AggiornaValori {
    /// Le posizioni in essere con il valore fermo: senza data o più vecchio di `mesiValoreFermo` mesi
    /// (la regola di `MotoreRiesame.valoriDaAggiornare`: niente coperture, debiti e immobili). Ordine: cliente
    /// (nome, `localizedStandardCompare`), poi data del valore (senza data prima), poi nome e id.
    static func valoriFermi(posizioni: [Posizione], clienti: [Cliente], oggi: Date,
                            clienteId: String? = nil, canale: Canale? = nil) -> [Posizione] {
        let cal = Calendar.current
        let soglia = cal.date(byAdding: .month, value: -mesiValoreFermo, to: cal.startOfDay(for: oggi)) ?? oggi
        var nomi: [String: String] = [:]
        for c in clienti where nomi[c.id] == nil { nomi[c.id] = c.nome }
        return posizioni.filter { p in
            guard p.stato == .inEssere, p.area != .protezione, !p.area.passivo, p.area != .immobili else { return false }
            if let clienteId, p.clienteId != clienteId { return false }
            if let canale, p.canale != canale { return false }
            return p.dataValore.map { $0 < soglia } ?? true
        }
        .sorted { a, b in
            let c = (nomi[a.clienteId] ?? "").localizedStandardCompare(nomi[b.clienteId] ?? "")
            if c != .orderedSame { return c == .orderedAscending }
            if a.clienteId != b.clienteId { return a.clienteId < b.clienteId }
            switch (a.dataValore, b.dataValore) {
            case (nil, .some): return true
            case (.some, nil): return false
            case let (x?, y?) where x != y: return x < y
            default: break
            }
            let n = a.nome.localizedStandardCompare(b.nome)
            return n != .orderedSame ? n == .orderedAscending : a.id < b.id
        }
    }

    /// Mesi interi da quando il valore è fermo; nil se non ha data.
    static func fermoDa(_ p: Posizione, oggi: Date) -> Int? {
        guard let d = p.dataValore else { return nil }
        return max(0, Calendar.current.dateComponents([.month], from: d, to: oggi).month ?? 0)
    }

    /// Le righe della griglia dalle caselle scritte: id = posto nell'elenco (da 1), solo le caselle con un valore.
    static func righe(bozze: [String: Bozza], elenco: [Posizione]) -> [Riga] {
        var righe: [Riga] = []
        for (i, p) in elenco.enumerated() {
            guard let b = bozze[p.id], !b.vuota else { continue }
            let testoData = b.data.trimmingCharacters(in: .whitespacesAndNewlines)
            let data = testoData.isEmpty ? nil : ImportaClienti.data(testoData).map(ValoriDaDocumento.mezzogiorno)
            let testoVersato = b.versato.trimmingCharacters(in: .whitespacesAndNewlines)
            righe.append(Riga(id: i + 1,
                              valore: EstrattoreDocumento.numero(b.valore.trimmingCharacters(in: .whitespacesAndNewlines)),
                              data: data,
                              dataIllegibile: !testoData.isEmpty && data == nil,
                              versato: testoVersato.isEmpty ? nil : EstrattoreDocumento.numero(testoVersato),
                              posizioneId: p.id))
        }
        return righe
    }
}
