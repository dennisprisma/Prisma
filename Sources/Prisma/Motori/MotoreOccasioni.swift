import Foundation

/// Le soglie del calendario delle occasioni, tutte in un punto. Le fonti sono in TestiOccasioni.fonte.
enum RegoleOccasioni {
    /// Maggiore età (c.c., art. 2).
    static let etaMaggiore = 18
    /// Anni di partecipazione per le anticipazioni per la casa e per ulteriori esigenze (D.Lgs. 252/2005, art. 11, c. 7).
    static var anniAnticipazioni: Int { RegoleFiscali.anniPerAnticipazione }   // 8
    /// Il primo anno intero oltre il 15°: l'aliquota passa da 15% a 14,70% (art. 11, c. 6; come `EsitoFiscale.gradini`).
    static let anniPrimaRiduzione = 16
    /// Da qui l'aliquota resta al minimo del 9% (15 − 0,30 × 20).
    static let anniAliquotaMinima = 35
    /// Anni prima della pensione di vecchiaia in cui si apre la RITA (art. 11, c. 4).
    static let anniPrimaPensione = 5
    /// Età limite predefinita per sottoscrivere una TCM o una LTC: è la più comune nelle condizioni di polizza.
    static let etaLimitePredefinita = 70
    /// Il confronto tra caso morte e debito guarda al massimo 40 anni avanti, mese per mese.
    static let mesiMassimiScansione = 480
    /// Sotto mezzo euro di differenza il capitale non è «sotto» il debito (come l'avviso della protezione per persona).
    static let tolleranzaDebito = 0.5
    /// I promemoria del Mac guardano un anno avanti (poi ne tiene 50 il limite di macOS).
    static let giorniPromemoria = 366
    /// Riesame: l'orizzonte e la soglia «vicina» (come `MotoreRiesame.mesiRiesame` e `mesiScadenzaVicina`).
    static var mesiRiesame: Int { MotoreRiesame.mesiRiesame }                   // 12
    static var mesiVicini: Int { MotoreRiesame.mesiScadenzaVicina }             // 6
    /// Le penali si cercano fino a questo anno di contratto (come `MotoreRiscatto`).
    static let anniMassimiPenali = 60
    /// Le bozze nate da un'occasione: l'appuntamento due settimane prima, l'attività una settimana prima.
    static let giorniPrimaAppuntamento = 14
    static let giorniPrimaAttivita = 7
    /// Le domande del riesame che nascono dalle occasioni, al massimo.
    static let domandeMassime = 2
    /// La vista «Occasioni» dell'Agenda guarda 12 mesi dal primo del mese mostrato.
    static let mesiElenco = 12
    /// Le occasioni tenute da parte per intervallo (settimana, mese, 12 mesi, notifiche, riesame): oltre si riparte.
    static let intervalliInMemoria = 6
}

/// Il calendario delle occasioni: le date in cui cambia qualcosa nelle posizioni in essere e nella famiglia
/// di un cliente (riscatto possibile, penali finite, periodo del KID, ricorrenze, previdenza, maggiore età,
/// fine del carico, caso morte sotto il debito, limiti d'età, pensione vicina, scadenze fiscali).
/// Motore puro: niente `StatoShell` né `Date()` nascosti (riceve `oggi` e `cal`), niente proiezioni, il
/// catalogo dei prodotti si apre una volta sola. Le occasioni non si salvano: si ricalcolano dai dati.
enum MotoreOccasioni {
    // MARK: - Calcolo

    /// Le occasioni di un cliente con il giorno in [inizio di `da`, inizio di `a`), senza i tipi spenti in `regole`.
    /// Le posizioni possono essere di tutti i clienti: si tengono quelle del cliente, in essere.
    /// `oggi` è il punto di partenza di ciò che dipende dai valori di oggi (caso morte contro debito, fisco).
    /// Ordine: per giorno, poi importanza, poi titolo.
    static func calcola(cliente: Cliente, posizioni: [Posizione], prodotti: [Prodotto], da: Date, a: Date,
                        regole: ImpostazioniOccasioni = ImpostazioniOccasioni(), oggi: Date = Date(),
                        cal: Calendar = .current) -> [Occasione] {
        let schede = schedePerId(prodotti)
        let mie = posizioni.filter { $0.clienteId == cliente.id && $0.stato == .inEssere }
        let elenco = occasioni(cliente: cliente, mie: mie, schede: schede, da: da, a: a, regole: regole, oggi: oggi, cal: cal)
        return ordinate(elenco, nomi: [:], cal: cal)
    }

    /// Tutti i clienti. Raggruppa posizioni e prodotti una volta sola. Ordine: per giorno, importanza, nome del cliente, titolo.
    static func calcola(clienti: [Cliente], posizioni: [Posizione], prodotti: [Prodotto], da: Date, a: Date,
                        regole: ImpostazioniOccasioni = ImpostazioniOccasioni(), oggi: Date = Date(),
                        cal: Calendar = .current) -> [Occasione] {
        let schede = schedePerId(prodotti)
        let perCliente = Dictionary(grouping: posizioni.filter { $0.stato == .inEssere }, by: \.clienteId)
        var nomi: [String: String] = [:]
        var elenco: [Occasione] = []
        var visti = Set<String>()
        for c in clienti {
            if nomi[c.id] == nil { nomi[c.id] = c.nome }
            // Due clienti con lo stesso id: le occasioni uguali si tengono una volta sola (la prima)
            for o in occasioni(cliente: c, mie: perCliente[c.id] ?? [], schede: schede, da: da, a: a,
                               regole: regole, oggi: oggi, cal: cal) where visti.insert(o.id).inserted {
                elenco.append(o)
            }
        }
        return ordinate(elenco, nomi: nomi, cal: cal)
    }

    // MARK: - Regole singole (pubbliche per le prove)

    /// Decorrenza + mesi di blocco (della posizione o della scheda prodotto); nil senza decorrenza o blocco 0.
    static func fineBlocco(_ p: Posizione, prodotto: Prodotto?, cal: Calendar = .current) -> Date? {
        guard let inizio = p.decorrenza, let mesi = p.bloccoRiscatto(prodotto: prodotto), mesi > 0 else { return nil }
        return cal.date(byAdding: .month, value: mesi, to: inizio)
    }

    /// Inizio del primo anno di contratto senza penali, con l'anno; nil se non ci sono penali.
    static func senzaPenali(_ p: Posizione, prodotto: Prodotto?, cal: Calendar = .current) -> (data: Date, anno: Int)? {
        guard let inizio = p.decorrenza else { return nil }
        var ultimo = 0
        for anno in 1...RegoleOccasioni.anniMassimiPenali where p.penale(anno: anno, prodotto: prodotto) > 0 { ultimo = anno }
        guard ultimo >= 1, let data = cal.date(byAdding: .year, value: ultimo, to: inizio) else { return nil }
        return (data, ultimo + 1)
    }

    /// Inizio della previdenza: prima adesione o, se manca, decorrenza.
    static func inizioPrevidenza(_ p: Posizione) -> Date? {
        p.primaAdesione ?? p.decorrenza
    }

    /// Il primo mese da `oggi` in cui le coperture caso morte di una persona scendono sotto il debito a suo carico.
    /// Nil se la persona non ha coperture o debiti, se il capitale è già sotto oggi (lo dice già l'avviso della
    /// protezione per persona) o se non scende mai sotto nei mesi guardati.
    static func sottoDebito(persona: String, cliente: Cliente, posizioni: [Posizione], oggi: Date,
                            cal: Calendar = .current) -> (data: Date, capitale: Double, debito: Double, posizioneId: String)? {
        let mie = posizioni.filter { $0.clienteId == cliente.id && $0.stato == .inEssere }
        // 1. Le coperture caso morte in essere di cui la persona è l'assicurato
        let coperture = mie.filter { p in
            p.area == .protezione && p.rischio == .vita && (p.scadenza.map { $0 > oggi } ?? true)
                && MotoreProtezioneFamiglia.assicurato(p, cliente: cliente) == persona
        }
        guard !coperture.isEmpty else { return nil }
        // 2. I debiti a suo carico, con la stessa quota della protezione per persona
        let delCliente = persona == cliente.id
        var debiti: [(capitale: Double, tasso: Double?, mesi: Int)] = []
        for d in mie where d.area == .debiti {
            let parteCliente = min(max(d.quotaDebito ?? 100, 0), 100) / 100
            let parte = delCliente ? parteCliente : (d.quotaDebito != nil ? 1 - parteCliente : 0)
            let capitale = max(0, d.valore) * parte
            guard capitale > 0, let mesi = d.mesiResidui(al: oggi), mesi > 0 else { continue }
            debiti.append((capitale, d.tassoDebito, mesi))
        }
        guard let piuLungo = debiti.map(\.mesi).max() else { return nil }
        // 3. Fin dove guardare
        let mMax = min(RegoleOccasioni.mesiMassimiScansione, piuLungo)
        let tolleranza = RegoleOccasioni.tolleranzaDebito
        // Una copertura che scade quel giorno non conta più
        func contributo(_ c: Posizione, _ t: Date) -> Double {
            (c.scadenza.map { $0 > t } ?? true) ? MotoreProtezioneFamiglia.capitaleAttuale(c, al: t) : 0
        }
        func debito(_ m: Int) -> Double {
            debiti.reduce(0) { $0 + MotoreProtezioneFamiglia.debitoResiduo(capitale: $1.capitale, tasso: $1.tasso, mesi: $1.mesi, dopo: m) }
        }
        // 5. Già sotto oggi: non è un'occasione
        var precedenti = coperture.map { contributo($0, oggi) }
        if precedenti.reduce(0, +) + tolleranza < debito(0) { return nil }
        guard mMax >= 1 else { return nil }
        // 6. Il primo mese sotto
        for m in 1...mMax {
            guard let t = cal.date(byAdding: .month, value: m, to: oggi) else { break }
            let attuali = coperture.map { contributo($0, t) }
            let capitale = attuali.reduce(0, +)
            let deb = debito(m)
            if capitale + tolleranza < deb {
                // La copertura il cui contributo cala di più; a parità la prima per scadenza, poi per id
                let scelta = coperture.indices.min { i, j in
                    let calo = (precedenti[i] - attuali[i], precedenti[j] - attuali[j])
                    if calo.0 != calo.1 { return calo.0 > calo.1 }
                    let scadenze = (coperture[i].scadenza ?? .distantFuture, coperture[j].scadenza ?? .distantFuture)
                    if scadenze.0 != scadenze.1 { return scadenze.0 < scadenze.1 }
                    return coperture[i].id < coperture[j].id
                } ?? coperture.startIndex
                return (t, capitale, deb, coperture[scelta].id)
            }
            precedenti = attuali
        }
        return nil
    }

    // MARK: - Chi le usa

    /// Notifiche di Prisma: importanza alta o media, niente fisco (ha già la sua notifica «Fine anno»),
    /// con il giorno tra oggi e oggi + anticipo (estremi compresi). In ordine di giorno, poi importanza.
    static func daNotificare(_ elenco: [Occasione], oggi: Date, anticipoGiorni: Int, cal: Calendar = .current) -> [Occasione] {
        let inizio = cal.startOfDay(for: oggi)
        var scelte: [(giorni: Int, indice: Int, occasione: Occasione)] = []
        for (i, o) in elenco.enumerated() {
            guard o.importanza <= .media, o.tipo != .scadenzaFiscale else { continue }
            guard let giorni = cal.dateComponents([.day], from: inizio, to: cal.startOfDay(for: o.data)).day,
                  giorni >= 0, giorni <= anticipoGiorni else { continue }
            scelte.append((giorni, i, o))
        }
        return scelte.sorted { x, y in
            if x.giorni != y.giorni { return x.giorni < y.giorni }
            if x.occasione.importanza != y.occasione.importanza { return x.occasione.importanza < y.occasione.importanza }
            return x.indice < y.indice
        }.map { $0.occasione }
    }

    /// Promemoria del Mac: importanza alta o media; del fisco solo deduzione e contributi non dedotti.
    static func perPromemoria(_ o: Occasione) -> Bool {
        o.importanza <= .media && (o.tipo != .scadenzaFiscale || o.fiscale == .deduzione || o.fiscale == .nonDedotti)
    }

    /// Punti dell'ordine del giorno del riesame: occasioni dei prossimi 12 mesi, senza ricorrenze e senza fisco.
    static func puntiRiesame(_ elenco: [Occasione], oggi: Date, cal: Calendar = .current) -> [Riesame.Punto] {
        let inizio = cal.startOfDay(for: oggi)
        let vicina = cal.date(byAdding: .month, value: RegoleOccasioni.mesiVicini, to: inizio) ?? inizio
        return delRiesame(elenco, oggi: oggi, cal: cal).map { o -> Riesame.Punto in
            let priorita: Riesame.Priorita
            switch o.importanza {
            case .alta: priorita = .alta
            case .media: priorita = cal.startOfDay(for: o.data) < vicina ? .media : .bassa
            case .bassa: priorita = .bassa
            }
            return Riesame.Punto(tema: .occasioni, titolo: o.titolo,
                                 dettaglio: "\(Formati.dataEstesa.string(from: o.data)): \(o.dettaglio)",
                                 priorita: priorita, canale: o.canale)
        }
    }

    /// Domande del riesame (al massimo 2), dalle occasioni dei prossimi 12 mesi.
    static func domandeRiesame(_ elenco: [Occasione], oggi: Date, cal: Calendar = .current) -> [String] {
        let occasioni = delRiesame(elenco, oggi: oggi, cal: cal)
        var domande: [String] = []
        if let o = occasioni.first(where: { $0.tipo == .maggiorenne || $0.tipo == .fineCarico }) {
            domande.append(TestiOccasioni.domandaFamiglia(o))
        }
        if let o = occasioni.first(where: { $0.tipo == .limiteEtaTCM || $0.tipo == .limiteEtaLTC }) {
            domande.append(TestiOccasioni.domandaLimite(o))
        }
        if occasioni.contains(where: { $0.tipo == .pensioneVicina }) {
            domande.append(TestiOccasioni.domandaPensione)
        }
        return Array(domande.prefix(RegoleOccasioni.domandeMassime))
    }

    // MARK: - Interno

    /// Le occasioni dei prossimi 12 mesi che contano per il riesame, nell'ordine dell'elenco.
    private static func delRiesame(_ elenco: [Occasione], oggi: Date, cal: Calendar) -> [Occasione] {
        let inizio = cal.startOfDay(for: oggi)
        let fine = cal.date(byAdding: .month, value: RegoleOccasioni.mesiRiesame, to: inizio) ?? inizio
        return elenco.filter { o in
            let g = cal.startOfDay(for: o.data)
            return g >= inizio && g < fine && o.tipo != .ricorrenzaGestione && o.tipo != .scadenzaFiscale
        }
    }

    private static func schedePerId(_ prodotti: [Prodotto]) -> [String: Prodotto] {
        Dictionary(prodotti.map { ($0.id, $0) }, uniquingKeysWith: { primo, _ in primo })
    }

    /// Per giorno, importanza, nome del cliente (se c'è), titolo; a parità resta l'ordine di calcolo.
    private static func ordinate(_ elenco: [Occasione], nomi: [String: String], cal: Calendar) -> [Occasione] {
        var chiavi: [(giorno: Date, nome: String, indice: Int, o: Occasione)] = []
        chiavi.reserveCapacity(elenco.count)
        for (i, o) in elenco.enumerated() {
            chiavi.append((cal.startOfDay(for: o.data), nomi[o.clienteId] ?? "", i, o))
        }
        return chiavi.sorted { x, y in
            if x.giorno != y.giorno { return x.giorno < y.giorno }
            if x.o.importanza != y.o.importanza { return x.o.importanza < y.o.importanza }
            if x.nome != y.nome { return x.nome.localizedCompare(y.nome) == .orderedAscending }
            if x.o.titolo != y.o.titolo { return x.o.titolo.localizedCompare(y.o.titolo) == .orderedAscending }
            return x.indice < y.indice
        }.map { $0.o }
    }

    /// Il canale comune di un gruppo di posizioni (nil se misto o vuoto).
    private static func canaleComune(_ posizioni: [Posizione]) -> Canale? {
        let canali = Set(posizioni.map(\.canale))
        return canali.count == 1 ? canali.first : nil
    }

    /// "aaaammgg" dai componenti del calendario.
    private static func giornoId(_ d: Date, cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Le occasioni di un cliente nella finestra, nell'ordine di calcolo, senza doppioni.
    private static func occasioni(cliente c: Cliente, mie: [Posizione], schede: [String: Prodotto], da: Date, a: Date,
                                  regole: ImpostazioniOccasioni, oggi: Date, cal: Calendar) -> [Occasione] {
        let inizio = cal.startOfDay(for: da)
        let fine = cal.startOfDay(for: a)
        guard inizio < fine else { return [] }
        var elenco: [Occasione] = []
        var visti = Set<String>()
        let comune: Canale? = c.canali.count == 1 ? c.canali.first : nil

        func dentro(_ d: Date) -> Bool {
            let g = cal.startOfDay(for: d)
            return g >= inizio && g < fine
        }
        // Il giorno va controllato con `dentro` prima di comporre i testi: qui si ricontrolla e si scartano i doppioni
        func aggiungi(_ tipo: TipoOccasione, _ data: Date, posizione: String? = nil, familiare: String? = nil, canale: Canale?,
                      titolo: String, dettaglio: String, valore: Double?, importanza: ImportanzaOccasione,
                      fiscale: ScadenzaFiscale.Tipo? = nil) {
            guard dentro(data) else { return }
            // Il soggetto dell'id: il fisco, la posizione, il familiare o il cliente (passo per passo, per il controllo dei tipi)
            var soggetto = c.id
            if let f = fiscale {
                soggetto = "\(f.rawValue)-\(c.id)"
            } else if let p = posizione {
                soggetto = p
            } else if let x = familiare {
                soggetto = x
            }
            let id = "\(tipo.rawValue)-\(soggetto)-\(giornoId(data, cal: cal))"
            guard visti.insert(id).inserted else { return }
            let fonte = fiscale.map { TestiOccasioni.fonteFiscale($0) } ?? TestiOccasioni.fonte(tipo)
            elenco.append(Occasione(tipo: tipo, data: data, clienteId: c.id, posizioneId: posizione, familiareId: familiare,
                                    canale: canale, titolo: titolo, dettaglio: dettaglio, fonte: fonte, valore: valore,
                                    importanza: importanza, fiscale: fiscale, id: id))
        }

        // Previdenza: anticipazioni dopo 8 anni, aliquota che scende dopo il 15° e al minimo dal 35°
        func previdenza(_ p: Posizione) {
            guard p.regime == .previdenza, let avvio = inizioPrevidenza(p) else { return }
            if regole.attivo(.anticipazioniPrevidenza),
               let d = cal.date(byAdding: .year, value: RegoleOccasioni.anniAnticipazioni, to: avvio), dentro(d) {
                aggiungi(.anticipazioniPrevidenza, d, posizione: p.id, canale: p.canale,
                         titolo: TestiOccasioni.titoloAnticipazioni(p.nome), dettaglio: TestiOccasioni.dettaglioAnticipazioni,
                         valore: Double(RegoleOccasioni.anniAnticipazioni), importanza: .media)
            }
            if regole.attivo(.aliquotaPrevidenza) {
                for anni in [RegoleOccasioni.anniPrimaRiduzione, RegoleOccasioni.anniAliquotaMinima] {
                    guard let d = cal.date(byAdding: .year, value: anni, to: avvio), dentro(d) else { continue }
                    let minima = anni >= RegoleOccasioni.anniAliquotaMinima
                    aggiungi(.aliquotaPrevidenza, d, posizione: p.id, canale: p.canale,
                             titolo: TestiOccasioni.titoloAliquota(p.nome, minima: minima),
                             dettaglio: TestiOccasioni.dettaglioAliquota(minima: minima),
                             valore: RegoleFiscali.aliquotaPrevidenza(anni: anni), importanza: .bassa)
                }
            }
        }

        // Contratti e previdenza: dalle posizioni in essere
        for p in mie {
            guard let decorrenza = p.decorrenza else {
                previdenza(p)
                continue
            }
            let prodotto = p.prodottoId.flatMap { schede[$0] }
            let riscattabile = p.area.proiettabile && (p.regime == .polizza || p.regime == .fondo)
            if riscattabile && regole.attivo(.fineBloccoRiscatto),
               let mesi = p.bloccoRiscatto(prodotto: prodotto), mesi > 0,
               let d = cal.date(byAdding: .month, value: mesi, to: decorrenza), dentro(d) {
                // L'anno di contratto in cui finisce il blocco e la penale di quell'anno
                let anno = mesi / 12 + 1
                aggiungi(.fineBloccoRiscatto, d, posizione: p.id, canale: p.canale,
                         titolo: TestiOccasioni.titoloFineBlocco(p.nome),
                         dettaglio: TestiOccasioni.dettaglioFineBlocco(mesi: mesi, penale: p.penale(anno: anno, prodotto: prodotto), anno: anno),
                         valore: Double(mesi), importanza: .media)
            }
            if riscattabile && regole.attivo(.senzaPenali),
               let s = senzaPenali(p, prodotto: prodotto, cal: cal), dentro(s.data) {
                aggiungi(.senzaPenali, s.data, posizione: p.id, canale: p.canale,
                         titolo: TestiOccasioni.titoloSenzaPenali(p.nome),
                         dettaglio: TestiOccasioni.dettaglioSenzaPenali(anno: s.anno, costoUscita: max(0, p.costoUscita ?? 0)),
                         valore: Double(s.anno), importanza: .media)
            }
            if riscattabile && regole.attivo(.periodoRaccomandato),
               let n = p.periodoRaccomandato ?? prodotto?.periodoConsigliato, n > 0,
               let d = cal.date(byAdding: .year, value: n, to: decorrenza), dentro(d) {
                aggiungi(.periodoRaccomandato, d, posizione: p.id, canale: p.canale,
                         titolo: TestiOccasioni.titoloPeriodo(p.nome), dettaglio: TestiOccasioni.dettaglioPeriodo(anni: n),
                         valore: Double(n), importanza: .media)
            }
            if regole.attivo(.ricorrenzaGestione) && (p.gestioneSeparata || p.multiramo) {
                // Ogni anniversario nella finestra e prima del giorno di scadenza; si parte dagli anni già passati
                let giaPassati = cal.dateComponents([.year], from: decorrenza, to: inizio).year ?? 0
                let scadenza = p.scadenza.map { cal.startOfDay(for: $0) }
                var k = max(1, giaPassati)
                while let d = cal.date(byAdding: .year, value: k, to: decorrenza) {
                    let g = cal.startOfDay(for: d)
                    if g >= fine { break }
                    if let scadenza, g >= scadenza { break }
                    if g >= inizio {
                        aggiungi(.ricorrenzaGestione, d, posizione: p.id, canale: p.canale,
                                 titolo: TestiOccasioni.titoloRicorrenza(p.nome),
                                 dettaglio: TestiOccasioni.dettaglioRicorrenza(multiramo: p.multiramo,
                                                                               consolidamento: p.consolidamento ?? prodotto?.consolidamento,
                                                                               minimoGarantito: p.minimoGarantito ?? prodotto?.minimoGarantito),
                                 valore: Double(k), importanza: .bassa)
                    }
                    k += 1
                }
            }
            previdenza(p)
        }

        // Pensione vicina: il cliente e i familiari con i dati del lavoro
        if regole.attivo(.pensioneVicina) {
            var persone: [(id: String?, nome: String, nascita: Date?, eta: Int)] = [
                (nil, c.nome, c.dataNascita, c.profilo.lavoro?.etaPensione ?? RegolePensione.etaVecchiaia)
            ]
            for f in c.famiglia where f.lavoro != nil {
                persone.append((f.id, f.nome, f.dataNascita, f.lavoro?.etaPensione ?? RegolePensione.etaVecchiaia))
            }
            for x in persone {
                guard let nascita = x.nascita,
                      let d = cal.date(byAdding: .year, value: x.eta - RegoleOccasioni.anniPrimaPensione, to: nascita),
                      dentro(d) else { continue }
                aggiungi(.pensioneVicina, d, familiare: x.id, canale: comune,
                         titolo: TestiOccasioni.titoloPensione(x.nome), dettaglio: TestiOccasioni.dettaglioPensione(eta: x.eta),
                         valore: Double(x.eta), importanza: .alta)
            }
        }

        // Famiglia: figli maggiorenni e fine del carico
        for f in c.famiglia {
            guard let nascita = f.dataNascita else { continue }
            let figlio = f.relazione == .figlio || f.relazione == .figlia
            if figlio && regole.attivo(.maggiorenne),
               let d = cal.date(byAdding: .year, value: RegoleOccasioni.etaMaggiore, to: nascita), dentro(d) {
                aggiungi(.maggiorenne, d, familiare: f.id, canale: comune,
                         titolo: TestiOccasioni.titoloMaggiorenne(f.nome), dettaglio: TestiOccasioni.dettaglioMaggiorenne,
                         valore: Double(RegoleOccasioni.etaMaggiore), importanza: .media)
            }
            if (f.aCarico || figlio) && f.nonAutosufficiente != true && regole.attivo(.fineCarico) {
                let eta = f.etaFineCarico ?? IpotesiPersona().etaFineCarico
                if let d = cal.date(byAdding: .year, value: eta, to: nascita), dentro(d) {
                    aggiungi(.fineCarico, d, familiare: f.id, canale: comune,
                             titolo: TestiOccasioni.titoloFineCarico(f.nome), dettaglio: TestiOccasioni.dettaglioFineCarico(eta: eta),
                             valore: Double(eta), importanza: .media)
                }
            }
        }

        // Protezione: il cliente e il partner
        let partner = c.famiglia.first { $0.relazione == .coniuge || $0.relazione == .convivente }
        var protette: [(id: String, familiare: String?, nome: String, nascita: Date?, reddito: Bool)] = [(c.id, nil, c.nome, c.dataNascita, true)]
        if let x = partner {
            protette.append((x.id, x.id, x.nome, x.dataNascita, (x.redditoNettoAnnuo ?? 0) > 0))
        }
        if regole.attivo(.capitaleSottoDebito) {
            for x in protette {
                guard let r = sottoDebito(persona: x.id, cliente: c, posizioni: mie, oggi: oggi, cal: cal), dentro(r.data) else { continue }
                let copertura = mie.first { $0.id == r.posizioneId }
                aggiungi(.capitaleSottoDebito, r.data, posizione: r.posizioneId, familiare: x.familiare, canale: copertura?.canale,
                         titolo: TestiOccasioni.titoloSottoDebito(x.nome),
                         dettaglio: TestiOccasioni.dettaglioSottoDebito(x.nome, data: r.data, capitale: r.capitale, debito: r.debito),
                         valore: r.debito, importanza: .alta)
            }
        }
        if regole.attivo(.limiteEtaTCM) || regole.attivo(.limiteEtaLTC) {
            // Le coperture in essere (senza scadenza o con la scadenza dopo oggi) e chi ne è l'assicurato
            let inEssere = mie.filter { $0.area == .protezione && ($0.scadenza.map { $0 > oggi } ?? true) }
            func coperto(_ persona: String, _ rischio: RischioCoperto) -> Bool {
                inEssere.contains { $0.rischio == rischio && MotoreProtezioneFamiglia.assicurato($0, cliente: c) == persona }
            }
            let debiti = mie.contains { $0.area == .debiti }
            let daProteggere = !c.famiglia.isEmpty || debiti
            for x in protette {
                guard let nascita = x.nascita else { continue }
                // TCM: il cliente sempre, il partner solo se porta reddito; serve qualcuno da proteggere
                if regole.attivo(.limiteEtaTCM) && x.reddito && daProteggere && !coperto(x.id, .vita) {
                    let limite = regole.etaLimiteTCM
                    if let d = cal.date(byAdding: .year, value: limite - 1, to: nascita), dentro(d) {
                        aggiungi(.limiteEtaTCM, d, familiare: x.familiare, canale: comune,
                                 titolo: TestiOccasioni.titoloLimiteTCM(x.nome),
                                 dettaglio: TestiOccasioni.dettaglioLimiteTCM(x.nome, limite: limite, debiti: debiti),
                                 valore: Double(limite), importanza: .alta)
                    }
                }
                if regole.attivo(.limiteEtaLTC) && !coperto(x.id, .ltc) {
                    let limite = regole.etaLimiteLTC
                    if let d = cal.date(byAdding: .year, value: limite - 1, to: nascita), dentro(d) {
                        aggiungi(.limiteEtaLTC, d, familiare: x.familiare, canale: comune,
                                 titolo: TestiOccasioni.titoloLimiteLTC(x.nome),
                                 dettaglio: TestiOccasioni.dettaglioLimiteLTC(x.nome, limite: limite),
                                 valore: Double(limite), importanza: .alta)
                    }
                }
            }
        }

        // Fisco: le scadenze di Fine anno degli anni della finestra (da quello di oggi: le cifre sono quelle di oggi)
        if regole.attivo(.scadenzaFiscale) && !mie.isEmpty {
            let annoOggi = cal.component(.year, from: oggi)
            let primo = max(cal.component(.year, from: inizio), annoOggi)
            let ultimo = cal.component(.year, from: cal.date(byAdding: .day, value: -1, to: fine) ?? fine)
            if primo <= ultimo {
                let coperture = mie.filter { $0.area == .protezione && ($0.scadenza.map { $0 > oggi } ?? true) }
                let conBollo = mie.filter(\.soggettaBollo)
                for anno in primo...ultimo {
                    // Le scadenze di Fine anno cadono il 31 dicembre e il 30 settembre dell'anno dopo, alle 12 (date
                    // costruite come in MotoreFineAnno): se nessuna delle due è nella finestra il calcolo si salta
                    // (notifiche e settimane dell'Agenda non pagano il fisco di tutti i clienti). Il risultato non cambia.
                    let calendarioFisco = Calendar.current
                    let fineAnnoFisco = calendarioFisco.date(from: DateComponents(year: anno, month: 12, day: 31, hour: 12))
                    let dichiarazioneFisco = calendarioFisco.date(from: DateComponents(year: anno + 1, month: 9, day: 30, hour: 12))
                    var cadeNellaFinestra = false
                    if let d = fineAnnoFisco, dentro(d) { cadeNellaFinestra = true }
                    if let d = dichiarazioneFisco, dentro(d) { cadeNellaFinestra = true }
                    if !cadeNellaFinestra { continue }
                    let quando = anno == annoOggi ? oggi
                        : (cal.date(from: DateComponents(year: anno, month: 1, day: 1, hour: 12)) ?? oggi)
                    let f = MotoreFineAnno.calcola(cliente: c, posizioni: mie, oggi: quando)
                    for s in f.scadenze where dentro(s.data) {
                        let canale: Canale?
                        var posizione: String? = nil
                        let importanza: ImportanzaOccasione
                        switch s.tipo {
                        case .deduzione, .nonDedotti:
                            canale = canaleComune(f.piani)
                            posizione = f.piani.first?.id
                            importanza = .media
                        case .detrazione:
                            canale = canaleComune(coperture)
                            importanza = .bassa
                        case .bollo:
                            canale = canaleComune(conBollo)
                            importanza = .bassa
                        }
                        aggiungi(.scadenzaFiscale, s.data, posizione: posizione, canale: canale,
                                 titolo: s.titolo, dettaglio: s.dettaglio, valore: s.importo,
                                 importanza: importanza, fiscale: s.tipo)
                    }
                }
            }
        }
        return elenco
    }
}
