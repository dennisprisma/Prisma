import Foundation

// Scadenze di conformità per canale («In regola», specifica 3 del giro 4): motore puro. Dalle date registrate
// nella scheda del cliente (questionari di adeguatezza, adeguata verifica, documento d'identità, consensi) e
// dalle regole di Impostazioni calcola cosa è scaduto, cosa scade entro 30 o 60 giorni e cosa manca.
// È un promemoria del consulente: fanno fede i moduli firmati e i sistemi della compagnia.

/// Una voce di conformità del cliente con il suo stato a una data.
struct VoceConformita: Identifiable, Hashable {
    enum Tipo: String, CaseIterable {
        // L'ordine è quello della scheda: prima i due canali, poi le voci comuni
        case questionarioAlleanza, verificaAlleanza, questionarioIndipendente, verificaIndipendente
        case documento, privacy, commerciale

        /// Il canale della voce; nil per le voci comuni a tutti i canali.
        var canale: Canale? {
            switch self {
            case .questionarioAlleanza, .verificaAlleanza: return .alleanza
            case .questionarioIndipendente, .verificaIndipendente: return .indipendente
            default: return nil
            }
        }
        var questionario: Bool { self == .questionarioAlleanza || self == .questionarioIndipendente }
        var verifica: Bool { self == .verificaAlleanza || self == .verificaIndipendente }

        /// Il questionario di un canale.
        static func questionarioDi(_ c: Canale) -> Tipo { c == .alleanza ? .questionarioAlleanza : .questionarioIndipendente }
        /// L'adeguata verifica di un canale.
        static func verificaDi(_ c: Canale) -> Tipo { c == .alleanza ? .verificaAlleanza : .verificaIndipendente }
    }

    enum Stato: Int, Comparable, CaseIterable {
        case scaduta, mancante, entro30, entro60, inRegola, nonRichiesta
        static func < (a: Stato, b: Stato) -> Bool { a.rawValue < b.rawValue }
    }

    /// Perché una voce non è richiesta.
    enum Motivo: Hashable {
        case canaleNonSeguito, clienteNonSeguito, sceltaConsulente, impostazioni, consensoNonDato
    }

    let tipo: Tipo
    let stato: Stato
    /// Compilazione, verifica, rilascio o consenso (nil se non registrata).
    let data: Date?
    /// Fin quando vale (nil: non registrata o non scade).
    let scadenza: Date?
    /// Giorni da oggi alla scadenza (negativi se scaduta); nil senza scadenza.
    let giorni: Int?
    /// Mesi di validità usati (questionari, verifica, consenso commerciale).
    let mesi: Int?
    /// Adeguata verifica senza rischio indicato: si è usata la periodicità del rischio medio.
    let rischioStimato: Bool
    let motivo: Motivo?

    init(tipo: Tipo, stato: Stato, data: Date? = nil, scadenza: Date? = nil, giorni: Int? = nil, mesi: Int? = nil,
         rischioStimato: Bool = false, motivo: Motivo? = nil) {
        self.tipo = tipo
        self.stato = stato
        self.data = data
        self.scadenza = scadenza
        self.giorni = giorni
        self.mesi = mesi
        self.rischioStimato = rischioStimato
        self.motivo = motivo
    }

    var id: String { tipo.rawValue }
    var canale: Canale? { tipo.canale }
    /// Scaduta, mancante o in scadenza entro 60 giorni.
    var daSistemare: Bool { stato <= .entro60 }
}

/// Le voci di conformità di un cliente a una data.
struct EsitoConformita: Identifiable {
    let cliente: Cliente
    let oggi: Date
    /// Tutte le voci, nell'ordine di `VoceConformita.Tipo.allCases`.
    let voci: [VoceConformita]

    var id: String { cliente.id }
    var dovute: [VoceConformita] { voci.filter { $0.stato != .nonRichiesta } }
    var scadute: [VoceConformita] { voci.filter { $0.stato == .scaduta } }
    var entro30: [VoceConformita] { voci.filter { $0.stato == .entro30 } }
    var entro60: [VoceConformita] { voci.filter { $0.stato == .entro60 } }
    /// In scadenza entro 60 giorni (30 compresi).
    var inScadenza: [VoceConformita] { voci.filter { $0.stato == .entro30 || $0.stato == .entro60 } }
    var mancanti: [VoceConformita] { voci.filter { $0.stato == .mancante } }
    /// Da sistemare, dalla più urgente: per stato, poi per scadenza.
    var daSistemare: [VoceConformita] {
        voci.filter(\.daSistemare).sorted { ($0.stato, $0.scadenza ?? .distantFuture) < ($1.stato, $1.scadenza ?? .distantFuture) }
    }
    var inRegola: Bool { !voci.contains(where: \.daSistemare) }
    var peggiore: VoceConformita.Stato? { voci.map(\.stato).min() }
    func voce(_ t: VoceConformita.Tipo) -> VoceConformita? { voci.first { $0.tipo == t } }
    /// Le voci di un canale (le sue due) più quelle comuni.
    func voci(canale: Canale) -> [VoceConformita] { voci.filter { $0.canale == nil || $0.canale == canale } }
}

/// I filtri della ricerca ⌘K sulla conformità.
enum FiltroConformita: String, Hashable, CaseIterable {
    case scaduta, entro30, inScadenza, mancante, daSistemare

    /// La voce rispetta il filtro.
    func comprende(_ v: VoceConformita) -> Bool {
        switch self {
        case .scaduta: return v.stato == .scaduta
        case .entro30: return v.stato == .entro30
        case .inScadenza: return v.stato == .entro30 || v.stato == .entro60
        case .mancante: return v.stato == .mancante
        case .daSistemare: return v.daSistemare
        }
    }
}

/// Un avviso per il Centro notifiche (Shell/Notifiche lo trasforma in `Notifica`).
struct AvvisoConformita: Hashable {
    enum Urgenza { case scaduta, entro30, entro60 }
    /// Comincia con "conformita-".
    let id: String
    let urgenza: Urgenza
    let titolo: String
    let dettaglio: String
    /// La scadenza più vecchia (scadute) o più vicina (in scadenza).
    let data: Date
    let canale: Canale?
    /// Un cliente solo: apre la sua scheda «In regola».
    let clienteId: String?
    /// Più clienti: apre la ricerca con questo testo.
    let testoRicerca: String?
    /// Giorni alla scadenza più vicina (0 = oggi), per scegliere il gruppo «Oggi» o «Nei prossimi giorni».
    let giorni: Int
}

/// Le voci di un canale per la scheda di adeguatezza della proposta 1.
struct ConformitaPerScheda {
    let canale: Canale
    /// Questionario e adeguata verifica del canale, documento, privacy (il consenso commerciale no).
    let voci: [VoceConformita]
    /// Le voci che impediscono di firmare: questionario del canale o documento scaduti o mancanti.
    let bloccanti: [VoceConformita]
    /// Frasi per il documento («Il questionario Alleanza scade il … prima della firma prevista»).
    let avvisi: [String]
    var pronta: Bool { bloccanti.isEmpty }
}

enum MotoreConformita {
    /// Le due soglie degli avvisi: entro 30 giorni (urgente) ed entro 60 giorni (da preparare).
    static let giorniVicini = 30
    static let giorniAvviso = 60
    /// Fino a quanti clienti il Centro notifiche mostra una voce per cliente; oltre, una voce sola che apre la ricerca.
    static let massimoClientiSingoli = 3

    // MARK: - Calcolo

    /// Le voci di conformità di un cliente a una data. `posizioni` sono quelle del cliente.
    static func calcola(cliente: Cliente, posizioni: [Posizione], regole: RegoleConformita,
                        oggi: Date = Date(), calendario: Calendar = .current) -> EsitoConformita {
        let voci = VoceConformita.Tipo.allCases.map {
            voce($0, cliente: cliente, posizioni: posizioni, regole: regole, oggi: oggi, calendario: calendario)
        }
        return EsitoConformita(cliente: cliente, oggi: oggi, voci: voci)
    }

    /// Tutti i clienti: le posizioni si raggruppano una volta sola (come MotoreAttenzioni).
    static func calcola(clienti: [Cliente], posizioni: [Posizione], regole: RegoleConformita,
                        oggi: Date = Date(), calendario: Calendar = .current) -> [EsitoConformita] {
        let gruppi = Dictionary(grouping: posizioni, by: \.clienteId)
        return clienti.map {
            calcola(cliente: $0, posizioni: gruppi[$0.id] ?? [], regole: regole, oggi: oggi, calendario: calendario)
        }
    }

    /// Il cliente è seguito con questo canale: lo dice la sua scheda (`canali`) o ha posizioni non chiuse
    /// del canale nelle aree investimento, risparmio o previdenza (`area.proiettabile`).
    static func seguito(_ c: Canale, cliente: Cliente, posizioni: [Posizione]) -> Bool {
        cliente.canali.contains(c) || posizioni.contains { $0.canale == c && $0.stato != .chiusa && $0.area.proiettabile }
    }

    /// Il cliente è seguito con almeno un canale, oppure ha almeno una posizione non chiusa.
    static func seguito(cliente: Cliente, posizioni: [Posizione]) -> Bool {
        !cliente.canali.isEmpty || posizioni.contains { $0.stato != .chiusa }
    }

    /// Giorni dall'inizio di oggi all'inizio del giorno della data (negativi se passata).
    static func giorni(da oggi: Date, a data: Date, calendario: Calendar) -> Int {
        calendario.dateComponents([.day], from: calendario.startOfDay(for: oggi), to: calendario.startOfDay(for: data)).day ?? 0
    }

    /// Stato e giorni di una scadenza a una data (nil: mancante). Il giorno della scadenza il documento vale ancora.
    static func stato(scadenza: Date?, oggi: Date, calendario: Calendar) -> (stato: VoceConformita.Stato, giorni: Int?) {
        guard let s = scadenza else { return (.mancante, nil) }
        let g = giorni(da: oggi, a: s, calendario: calendario)
        if g < 0 { return (.scaduta, g) }
        if g <= giorniVicini { return (.entro30, g) }
        if g <= giorniAvviso { return (.entro60, g) }
        return (.inRegola, g)
    }

    /// Data + mesi con il calendario (31 agosto + 6 mesi = 28/29 febbraio).
    static func aggiungiMesi(_ mesi: Int, a data: Date, calendario: Calendar) -> Date {
        calendario.date(byAdding: .month, value: mesi, to: data) ?? data
    }

    /// Mesi riportati tra 1 e 120.
    static func mesi(_ m: Int) -> Int { min(120, max(1, m)) }

    /// Una voce del cliente.
    private static func voce(_ t: VoceConformita.Tipo, cliente: Cliente, posizioni: [Posizione], regole: RegoleConformita,
                             oggi: Date, calendario cal: Calendar) -> VoceConformita {
        let conf = cliente.conformita ?? ConformitaCliente()
        // La scelta del consulente vale per tutte le voci tranne la privacy
        if t != .privacy, conf.nonRichiesta(t.rawValue) {
            return VoceConformita(tipo: t, stato: .nonRichiesta, data: dataRegistrata(t, cliente: cliente), motivo: .sceltaConsulente)
        }
        switch t {
        case .questionarioAlleanza, .questionarioIndipendente:
            let canale: Canale = t == .questionarioAlleanza ? .alleanza : .indipendente
            let q = conf.questionario(canale)
            guard seguito(canale, cliente: cliente, posizioni: posizioni) else {
                return VoceConformita(tipo: t, stato: .nonRichiesta, data: q?.compilatoIl, motivo: .canaleNonSeguito)
            }
            let m = mesi(q?.validitaMesi ?? regole.mesiQuestionario(canale))
            return conScadenza(t, data: q?.compilatoIl, mesi: m, oggi: oggi, calendario: cal)
        case .verificaAlleanza, .verificaIndipendente:
            let canale: Canale = t == .verificaAlleanza ? .alleanza : .indipendente
            let v = conf.verifica(canale)
            guard seguito(canale, cliente: cliente, posizioni: posizioni) else {
                return VoceConformita(tipo: t, stato: .nonRichiesta, data: v?.eseguitaIl, motivo: .canaleNonSeguito)
            }
            if canale == .indipendente, !regole.verificaIndipendente {
                return VoceConformita(tipo: t, stato: .nonRichiesta, data: v?.eseguitaIl, motivo: .impostazioni)
            }
            let m = mesi(regole.mesiVerifica(v?.rischio ?? .medio))
            let stimato = v?.rischio == nil && v?.eseguitaIl != nil
            return conScadenza(t, data: v?.eseguitaIl, mesi: m, rischioStimato: stimato, oggi: oggi, calendario: cal)
        case .documento:
            let d = conf.documento
            guard seguito(cliente: cliente, posizioni: posizioni) else {
                return VoceConformita(tipo: t, stato: .nonRichiesta, data: d?.rilasciatoIl, motivo: .clienteNonSeguito)
            }
            // Vale solo la scadenza scritta: il motore non la stima
            let s = stato(scadenza: d?.scadenza, oggi: oggi, calendario: cal)
            return VoceConformita(tipo: t, stato: s.stato, data: d?.rilasciatoIl, scadenza: d?.scadenza, giorni: s.giorni)
        case .privacy:
            let k = cliente.consensi
            guard k.privacy else { return VoceConformita(tipo: t, stato: .mancante, data: k.dataPrivacy) }
            // Informativa cambiata dopo l'ultima firma: va consegnata di nuovo
            if let aggiornata = regole.informativaAggiornataIl,
               k.dataPrivacy.map({ cal.startOfDay(for: $0) < cal.startOfDay(for: aggiornata) }) ?? true {
                let g = giorni(da: oggi, a: aggiornata, calendario: cal)
                return VoceConformita(tipo: t, stato: g < 0 ? .scaduta : .entro30, data: k.dataPrivacy, scadenza: aggiornata, giorni: g)
            }
            // Il consenso al trattamento non scade
            return VoceConformita(tipo: t, stato: .inRegola, data: k.dataPrivacy)
        case .commerciale:
            let k = cliente.consensi
            guard k.marketing else { return VoceConformita(tipo: t, stato: .nonRichiesta, data: k.dataMarketing, motivo: .consensoNonDato) }
            if regole.mesiCommerciale <= 0 {
                // «Non scade»: basta che sia stato dato con una data
                guard let data = k.dataMarketing else { return VoceConformita(tipo: t, stato: .mancante) }
                return VoceConformita(tipo: t, stato: .inRegola, data: data)
            }
            return conScadenza(t, data: k.dataMarketing, mesi: mesi(regole.mesiCommerciale), oggi: oggi, calendario: cal)
        }
    }

    /// Una voce che vale `mesi` dalla data registrata (mancante senza data).
    private static func conScadenza(_ t: VoceConformita.Tipo, data: Date?, mesi m: Int, rischioStimato: Bool = false,
                                    oggi: Date, calendario: Calendar) -> VoceConformita {
        guard let data else { return VoceConformita(tipo: t, stato: .mancante, mesi: m) }
        let scadenza = aggiungiMesi(m, a: data, calendario: calendario)
        let s = stato(scadenza: scadenza, oggi: oggi, calendario: calendario)
        return VoceConformita(tipo: t, stato: s.stato, data: data, scadenza: scadenza, giorni: s.giorni, mesi: m,
                              rischioStimato: rischioStimato)
    }

    /// La data registrata di una voce, qualunque sia il suo stato (per le voci non richieste).
    private static func dataRegistrata(_ t: VoceConformita.Tipo, cliente: Cliente) -> Date? {
        let conf = cliente.conformita
        switch t {
        case .questionarioAlleanza: return conf?.questionarioAlleanza?.compilatoIl
        case .questionarioIndipendente: return conf?.questionarioIndipendente?.compilatoIl
        case .verificaAlleanza: return conf?.verificaAlleanza?.eseguitaIl
        case .verificaIndipendente: return conf?.verificaIndipendente?.eseguitaIl
        case .documento: return conf?.documento?.rilasciatoIl
        case .privacy: return cliente.consensi.dataPrivacy
        case .commerciale: return cliente.consensi.dataMarketing
        }
    }

    // MARK: - Documento d'identità

    /// La scadenza proposta dal modulo a partire dalla data di rilascio (nil se non si può stimare).
    /// Carta d'identità: 3, 5 o 10 anni secondo l'età al rilascio, fino al compleanno successivo (D.L. 5/2012,
    /// art. 7, c. 2). Passaporto: gli stessi anni, senza compleanno. Patente e altro: si scrive a mano.
    static func scadenzaProposta(tipo: TipoDocumentoIdentita, rilascio: Date, nascita: Date?,
                                 calendario: Calendar = .current) -> Date? {
        func anni(_ eta: Int) -> Int { eta < 3 ? 3 : (eta < 18 ? 5 : 10) }
        func eta(_ n: Date) -> Int? { calendario.dateComponents([.year], from: n, to: rilascio).year }
        switch tipo {
        case .cartaIdentita:
            guard let n = nascita, let e = eta(n),
                  let base = calendario.date(byAdding: .year, value: anni(e), to: rilascio) else { return nil }
            return MotoreNotifiche.prossimoCompleanno(n, da: calendario.startOfDay(for: base), cal: calendario)
        case .passaporto:
            let e = nascita.flatMap(eta) ?? 18
            return calendario.date(byAdding: .year, value: anni(e), to: rilascio)
        case .patente, .altro:
            return nil
        }
    }

    // MARK: - Centro notifiche

    /// Gli avvisi per il Centro notifiche (solo scadute ed entro 60 giorni: le mancanti no). In ordine:
    /// scadute, entro 30 giorni, tra 31 e 60 giorni.
    static func avvisi(_ esiti: [EsitoConformita], oggi: Date, calendario: Calendar = .current) -> [AvvisoConformita] {
        var elenco = avvisiPerCliente(esiti, urgenza: .scaduta, oggi: oggi, calendario: calendario)
        elenco += avvisiPerCliente(esiti, urgenza: .entro30, oggi: oggi, calendario: calendario)
        if let a = avvisoEntro60(esiti, oggi: oggi, calendario: calendario) { elenco.append(a) }
        return elenco
    }

    /// Le voci di un cliente per un avviso, con la data dell'avviso.
    private struct GruppoAvviso {
        let esito: EsitoConformita
        let voci: [VoceConformita]
        let data: Date
        var cliente: Cliente { esito.cliente }
    }

    /// I clienti con voci in questo stato, ordinati per data: la scadenza più vecchia (scadute) o la più vicina
    /// (in scadenza), che per le voci future è la stessa cosa.
    private static func gruppi(_ esiti: [EsitoConformita], _ stati: Set<VoceConformita.Stato>) -> [GruppoAvviso] {
        var elenco: [GruppoAvviso] = []
        for e in esiti {
            let voci = e.voci.filter { stati.contains($0.stato) }
            guard let data = voci.compactMap(\.scadenza).min() else { continue }
            elenco.append(GruppoAvviso(esito: e, voci: voci, data: data))
        }
        return elenco.sorted { $0.data < $1.data }
    }

    /// Scadute o entro 30 giorni: un avviso per cliente fino a tre clienti, oltre un avviso solo che apre la ricerca.
    private static func avvisiPerCliente(_ esiti: [EsitoConformita], urgenza: AvvisoConformita.Urgenza,
                                         oggi: Date, calendario: Calendar) -> [AvvisoConformita] {
        let scaduta = urgenza == .scaduta
        let stato: VoceConformita.Stato = scaduta ? .scaduta : .entro30
        let elenco = gruppi(esiti, [stato])
        guard !elenco.isEmpty else { return [] }
        let prefisso = scaduta ? "conformita-scaduta-" : "conformita-entro30-"

        if elenco.count <= massimoClientiSingoli {
            return elenco.map { g in
                let nome = g.cliente.nome
                let titolo: String
                if g.voci.count == 1, let v = g.voci.first {
                    titolo = "\(nome): " + (scaduta ? TestiConformita.scaduta(v) : TestiConformita.inScadenza(v))
                } else {
                    titolo = "\(nome): \(g.voci.count) scadenze di conformità " + (scaduta ? "superate" : "entro 30 giorni")
                }
                let tipi = g.voci.map { $0.tipo.rawValue }.joined(separator: ",")
                let dettaglio = g.voci.map { TestiConformita.nomeBreveMaiuscolo($0) }.joined(separator: " · ") + " · apri «In regola»"
                return AvvisoConformita(
                    id: "\(prefisso)\(g.cliente.id)-\(tipi)-\(Int(g.data.timeIntervalSince1970))",
                    urgenza: urgenza, titolo: titolo, dettaglio: dettaglio,
                    data: g.data, canale: canaleComune(g.voci), clienteId: g.cliente.id, testoRicerca: nil,
                    giorni: giorni(da: oggi, a: g.data, calendario: calendario))
            }
        }

        let data = elenco.map { $0.data }.min() ?? oggi
        let n = elenco.count
        return [AvvisoConformita(
            id: prefisso + elenco.map { $0.cliente.id }.joined(separator: ","),
            urgenza: urgenza,
            titolo: "\(n) clienti con scadenze di conformità " + (scaduta ? "superate" : "entro 30 giorni"),
            dettaglio: elencoNomi(elenco.map { $0.cliente.nome }),
            data: data, canale: canaleComune(elenco.flatMap { $0.voci }), clienteId: nil,
            testoRicerca: scaduta ? "conformita:scaduta" : "conformita:30",
            giorni: giorni(da: oggi, a: data, calendario: calendario))]
    }

    /// Tra 31 e 60 giorni: sempre un avviso solo, se c'è almeno una voce.
    private static func avvisoEntro60(_ esiti: [EsitoConformita], oggi: Date, calendario: Calendar) -> AvvisoConformita? {
        let elenco = gruppi(esiti, [.entro60])
        guard let primo = elenco.first else { return nil }
        let tutte = elenco.flatMap { $0.voci }
        let numeroVoci = tutte.count
        let titolo: String
        if numeroVoci == 1, let v = tutte.first {
            titolo = "\(primo.cliente.nome): \(TestiConformita.inScadenza(v))"
        } else {
            titolo = "\(numeroVoci) scadenze di conformità nei prossimi 60 giorni"
        }
        let unCliente = elenco.count == 1
        return AvvisoConformita(
            id: "conformita-entro60-\(elenco.map { $0.cliente.id }.joined(separator: ","))-\(numeroVoci)",
            urgenza: .entro60, titolo: titolo,
            dettaglio: elencoNomi(elenco.map { $0.cliente.nome }) + " · da preparare per tempo",
            data: primo.data, canale: canaleComune(tutte),
            clienteId: unCliente ? primo.cliente.id : nil,
            testoRicerca: unCliente ? nil : "conformita:inscadenza",
            giorni: giorni(da: oggi, a: primo.data, calendario: calendario))
    }

    /// I primi tre nomi, con «…» se ce ne sono altri.
    private static func elencoNomi(_ nomi: [String]) -> String {
        nomi.prefix(massimoClientiSingoli).joined(separator: ", ") + (nomi.count > massimoClientiSingoli ? "…" : "")
    }

    /// Il canale comune a tutte le voci (nil se sono di canali diversi o comuni).
    static func canaleComune(_ voci: [VoceConformita]) -> Canale? {
        guard let primo = voci.first?.canale, voci.allSatisfy({ $0.canale == primo }) else { return nil }
        return primo
    }

    // MARK: - Ricerca

    /// Il cliente rispetta il filtro della ricerca; con un canale contano solo le voci di quel canale e quelle comuni.
    static func rispetta(_ e: EsitoConformita, _ f: FiltroConformita, canale: Canale? = nil) -> Bool {
        let voci = canale.map { e.voci(canale: $0) } ?? e.voci
        return voci.contains { f.comprende($0) }
    }

    /// Le voci che rispettano il filtro, dalla più urgente (per l'estratto della ricerca e il suo canale).
    static func vociFiltro(_ e: EsitoConformita, _ f: FiltroConformita, canale: Canale? = nil) -> [VoceConformita] {
        e.daSistemare.filter { f.comprende($0) && (canale == nil || $0.canale == nil || $0.canale == canale) }
    }

    // MARK: - Scheda di adeguatezza

    /// Per la scheda di adeguatezza (proposta 1): le voci del canale della proposta, cosa blocca la firma, gli avvisi.
    static func perScheda(_ e: EsitoConformita, canale: Canale, firmaIl: Date? = nil,
                          calendario: Calendar = .current) -> ConformitaPerScheda {
        let tipi: [VoceConformita.Tipo] = [.questionarioDi(canale), .verificaDi(canale), .documento, .privacy]
        let voci = tipi.compactMap { e.voce($0) }.filter { $0.stato != .nonRichiesta }
        let bloccanti = voci.filter { v in
            switch v.tipo {
            case .privacy: return v.stato == .mancante
            case .documento: return v.stato == .scaduta || v.stato == .mancante
            default: return v.tipo.questionario && (v.stato == .scaduta || v.stato == .mancante)
            }
        }
        var avvisi = bloccanti.map { TestiConformita.bloccante($0) }
        let bloccate = Set(bloccanti.map(\.tipo))
        for v in voci where !bloccate.contains(v.tipo) {
            guard let s = v.scadenza else { continue }
            if let firma = firmaIl {
                if calendario.startOfDay(for: s) < calendario.startOfDay(for: firma) {
                    avvisi.append(TestiConformita.primaDellaFirma(v))
                }
            } else if v.stato == .entro30 {
                avvisi.append(TestiConformita.rinnovoAllaFirma(v))
            }
        }
        return ConformitaPerScheda(canale: canale, voci: voci, bloccanti: bloccanti, avvisi: avvisi)
    }

    // MARK: - Scrittura

    /// La conformità da salvare: i record vuoti tornano nil, e una conformità tutta vuota diventa nil
    /// (così un cliente senza date resta come negli archivi di prima).
    static func normalizzata(_ c: ConformitaCliente) -> ConformitaCliente? {
        var n = c
        if n.questionarioAlleanza == QuestionarioAdeguatezza() { n.questionarioAlleanza = nil }
        if n.questionarioIndipendente == QuestionarioAdeguatezza() { n.questionarioIndipendente = nil }
        if n.verificaAlleanza == AdeguataVerifica() { n.verificaAlleanza = nil }
        if n.verificaIndipendente == AdeguataVerifica() { n.verificaIndipendente = nil }
        if var d = n.documento {
            if d.numero?.trimmingCharacters(in: .whitespaces).isEmpty == true { d.numero = nil }
            n.documento = d == DocumentoIdentita() ? nil : d
        }
        if n.nonRichieste?.isEmpty == true { n.nonRichieste = nil }
        return n == ConformitaCliente() ? nil : n
    }
}
