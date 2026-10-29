import Foundation

/// Canale con cui il consulente lavora una posizione o una proposta.
enum Canale: String, Codable, CaseIterable, Identifiable {
    case alleanza
    case indipendente

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .alleanza: return "Alleanza Assicurazioni"
        case .indipendente: return "Denis Vicenzoni · Consulenza finanziaria"
        }
    }

    var nomeBreve: String {
        switch self {
        case .alleanza: return "Alleanza"
        case .indipendente: return "Indipendente"
        }
    }
}

/// Tinta dell'avatar del cliente (come le classi .os-avatar del template).
enum TintaAvatar: String, Codable {
    case blu, rosa, verde, viola, oro
}

struct Cliente: Identifiable, Codable, Hashable {
    let id: String
    var nome: String
    var iniziali: String
    var tinta: TintaAvatar
    var tema: String
    var email: String
    var telefono: String
    var preferito: Bool
    var nota: String
    var creatoIl: Date

    // Anagrafica (dalla versione 2 dell'archivio)
    var dataNascita: Date?
    var codiceFiscale = ""
    var professione = ""
    var statoCivile: StatoCivile?
    var indirizzo = ""
    /// Canali con cui il cliente è seguito.
    var canali: [Canale] = []
    var famiglia: [Familiare] = []
    var profilo = ProfiloInvestitore()
    var consensi = Consensi()
    /// Profilo dei bisogni (dalla versione 7 dell'archivio).
    var bisogni = ProfiloBisogni()
    /// Dati segnati dal consulente come «non pertinenti» per la completezza dell'analisi (dalla versione 21
    /// dell'archivio). Chiave: `VoceCompletezza.id` (per esempio "lavoro", "costi:pos-…"); valore: quando è
    /// stato segnato. nil = nessuno. Le chiavi che non corrispondono più a una voce si ignorano.
    var datiNonPertinenti: [String: Date]?

    init(id: String, nome: String, iniziali: String, tinta: TintaAvatar, tema: String, email: String,
         telefono: String, preferito: Bool, nota: String, creatoIl: Date) {
        self.id = id
        self.nome = nome
        self.iniziali = iniziali
        self.tinta = tinta
        self.tema = tema
        self.email = email
        self.telefono = telefono
        self.preferito = preferito
        self.nota = nota
        self.creatoIl = creatoIl
    }

    /// Nuovo cliente vuoto.
    static func nuovo(tinta: TintaAvatar) -> Cliente {
        Cliente(id: UUID().uuidString, nome: "", iniziali: "", tinta: tinta, tema: "", email: "", telefono: "",
                preferito: false, nota: "", creatoIl: Date())
    }

    var eta: Int? {
        dataNascita.flatMap { Calendar.current.dateComponents([.year], from: $0, to: Date()).year }
    }

    /// Iniziali ricavate dal nome ("Giulia Rossi" → "GR").
    static func iniziali(di nome: String) -> String {
        let parole = nome.split(separator: " ").filter { !$0.isEmpty }
        let lettere = parole.prefix(2).compactMap { $0.first.map(String.init) }
        return lettere.joined().uppercased()
    }

    private enum CodingKeys: String, CodingKey {
        case id, nome, iniziali, tinta, tema, email, telefono, preferito, nota, creatoIl
        case dataNascita, codiceFiscale, professione, statoCivile, indirizzo, canali, famiglia, profilo, consensi, bisogni
        case datiNonPertinenti
    }

    /// Lettura tollerante: i campi aggiunti nelle versioni successive possono mancare.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nome = try c.decode(String.self, forKey: .nome)
        iniziali = try c.decodeIfPresent(String.self, forKey: .iniziali) ?? Cliente.iniziali(di: nome)
        tinta = try c.decodeIfPresent(TintaAvatar.self, forKey: .tinta) ?? .blu
        tema = try c.decodeIfPresent(String.self, forKey: .tema) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        telefono = try c.decodeIfPresent(String.self, forKey: .telefono) ?? ""
        preferito = try c.decodeIfPresent(Bool.self, forKey: .preferito) ?? false
        nota = try c.decodeIfPresent(String.self, forKey: .nota) ?? ""
        creatoIl = try c.decodeIfPresent(Date.self, forKey: .creatoIl) ?? Date()
        dataNascita = try c.decodeIfPresent(Date.self, forKey: .dataNascita)
        codiceFiscale = try c.decodeIfPresent(String.self, forKey: .codiceFiscale) ?? ""
        professione = try c.decodeIfPresent(String.self, forKey: .professione) ?? ""
        statoCivile = try c.decodeIfPresent(StatoCivile.self, forKey: .statoCivile)
        indirizzo = try c.decodeIfPresent(String.self, forKey: .indirizzo) ?? ""
        canali = try c.decodeIfPresent([Canale].self, forKey: .canali) ?? []
        famiglia = try c.decodeIfPresent([Familiare].self, forKey: .famiglia) ?? []
        profilo = try c.decodeIfPresent(ProfiloInvestitore.self, forKey: .profilo) ?? ProfiloInvestitore()
        consensi = try c.decodeIfPresent(Consensi.self, forKey: .consensi) ?? Consensi()
        bisogni = (try? c.decodeIfPresent(ProfiloBisogni.self, forKey: .bisogni)) ?? ProfiloBisogni()
        // Dati non pertinenti (dalla versione 21): un valore malformato diventa nil e non fa scartare il cliente
        datiNonPertinenti = try? c.decodeIfPresent([String: Date].self, forKey: .datiNonPertinenti)
    }
}

enum StatoCivile: String, Codable, CaseIterable, Identifiable {
    case celibeNubile, coniugato, convivente, separato, divorziato, vedovo
    var id: String { rawValue }
    var nome: String {
        switch self {
        case .celibeNubile: return "Celibe / nubile"
        case .coniugato: return "Coniugato/a"
        case .convivente: return "Convivente"
        case .separato: return "Separato/a"
        case .divorziato: return "Divorziato/a"
        case .vedovo: return "Vedovo/a"
        }
    }
}

struct Familiare: Identifiable, Codable, Hashable {
    enum Relazione: String, Codable, CaseIterable, Identifiable {
        case coniuge, convivente, figlio, figlia, genitore, fratelloSorella, altro
        var id: String { rawValue }
        var nome: String {
            switch self {
            case .coniuge: return "Coniuge"
            case .convivente: return "Convivente"
            case .figlio: return "Figlio"
            case .figlia: return "Figlia"
            case .genitore: return "Genitore"
            case .fratelloSorella: return "Fratello / sorella"
            case .altro: return "Altro"
            }
        }
    }

    var id = UUID().uuidString
    var nome: String
    var relazione: Relazione
    var dataNascita: Date?
    var aCarico = false
    var nota = ""

    // Dati per la protezione per persona e la pensione (facoltativi: Codable sintetizzato, solo Optional)
    /// Reddito netto annuo che questa persona porta in famiglia (€); nil = nessun reddito o non indicato.
    var redditoNettoAnnuo: Double?
    /// Non autosufficiente o con disabilità: il sostegno serve per tutta la vita, non fino a un'età.
    var nonAutosufficiente: Bool?
    /// Età fino a cui resta a carico (per i figli di solito 25); nil = regola predefinita del motore.
    var etaFineCarico: Int?
    /// Lavoro e contributi, per la pensione pubblica stimata con il contributivo.
    var lavoro: DatiLavoro?

    var eta: Int? {
        dataNascita.flatMap { Calendar.current.dateComponents([.year], from: $0, to: Date()).year }
    }

    /// Reddito lordo annuo da lavoro, se indicato.
    var redditoDaLavoro: Double? { lavoro?.redditoLavoro }
}

/// Tipo di lavoratore ai fini della pensione pubblica: decide l'aliquota di computo dei contributi.
/// Le aliquote predefinite sono quelle di legge più comuni; il consulente può sempre indicare la sua
/// (`DatiLavoro.aliquotaContributiva`).
enum TipoLavoratore: String, Codable, CaseIterable, Identifiable {
    /// Lavoratore dipendente (FPLD INPS): aliquota di computo 33%.
    case dipendente
    /// Artigiano o commerciante (gestioni speciali INPS): circa 24%.
    case autonomo
    /// Professionista senza cassa iscritto alla Gestione separata INPS: 25% (quota pensionistica IVS).
    case gestioneSeparata
    /// Collaboratore (parasubordinato) nella Gestione separata INPS: 33%.
    case collaboratore
    /// Professionista con una cassa propria (Inarcassa, Cassa Forense…): regole diverse, nessuna stima.
    case cassaProfessionale

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .dipendente: return "Lavoratore dipendente"
        case .autonomo: return "Artigiano o commerciante"
        case .gestioneSeparata: return "Professionista in Gestione separata"
        case .collaboratore: return "Collaboratore in Gestione separata"
        case .cassaProfessionale: return "Professionista con cassa propria"
        }
    }

    /// Aliquota di computo predefinita (% del reddito lordo); nil se Prisma non la stima.
    var aliquotaPredefinita: Double? {
        switch self {
        case .dipendente, .collaboratore: return 33
        case .autonomo: return 24
        case .gestioneSeparata: return 25
        case .cassaProfessionale: return nil
        }
    }
}

/// Lavoro e contributi di una persona (cliente o familiare), per la pensione pubblica con il metodo
/// contributivo. Tutti i campi sono facoltativi: chi calcola usa i ripieghi dichiarati.
struct DatiLavoro: Codable, Hashable {
    var tipo: TipoLavoratore?
    /// Aliquota di computo indicata dal consulente (%); se manca vale `tipo.aliquotaPredefinita`.
    var aliquotaContributiva: Double?
    /// Reddito lordo annuo da lavoro di oggi (€). Per il cliente, se manca, `ProfiloInvestitore.redditoLordoAnnuo`.
    var redditoLavoro: Double?
    /// Crescita reale attesa del reddito da lavoro (% all'anno, oltre l'inflazione).
    var crescitaReddito: Double?
    /// Anni di contributi già versati.
    var anniContributi: Double?
    /// Anno del primo contributo: prima del 1996 il sistema è misto e la stima contributiva è solo indicativa.
    var annoPrimoContributo: Int?
    /// Montante contributivo già maturato (€), dall'estratto conto INPS: se c'è prevale sulla stima dagli anni.
    var montanteContributivo: Double?
    /// Età prevista di pensionamento; per il cliente, se manca, `IpotesiPrevidenza.etaPensione`.
    var etaPensione: Int?

    init(tipo: TipoLavoratore? = nil, aliquotaContributiva: Double? = nil, redditoLavoro: Double? = nil,
         crescitaReddito: Double? = nil, anniContributi: Double? = nil, annoPrimoContributo: Int? = nil,
         montanteContributivo: Double? = nil, etaPensione: Int? = nil) {
        self.tipo = tipo
        self.aliquotaContributiva = aliquotaContributiva
        self.redditoLavoro = redditoLavoro
        self.crescitaReddito = crescitaReddito
        self.anniContributi = anniContributi
        self.annoPrimoContributo = annoPrimoContributo
        self.montanteContributivo = montanteContributivo
        self.etaPensione = etaPensione
    }

    /// Aliquota di computo da usare (%): quella indicata o quella del tipo di lavoratore.
    var aliquota: Double? { aliquotaContributiva ?? tipo?.aliquotaPredefinita }

    /// Contributi versati anche prima del 1996: sistema misto, la stima contributiva pura è indicativa.
    var sistemaMisto: Bool { (annoPrimoContributo ?? 9_999) < 1996 }

    private enum CodingKeys: String, CodingKey {
        case tipo, aliquotaContributiva, redditoLavoro, crescitaReddito, anniContributi, annoPrimoContributo
        case montanteContributivo, etaPensione
    }

    /// Lettura tollerante: un valore illeggibile (per esempio un tipo sconosciuto) diventa nil.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        tipo = try? c.decodeIfPresent(TipoLavoratore.self, forKey: .tipo)
        aliquotaContributiva = try? c.decodeIfPresent(Double.self, forKey: .aliquotaContributiva)
        redditoLavoro = try? c.decodeIfPresent(Double.self, forKey: .redditoLavoro)
        crescitaReddito = try? c.decodeIfPresent(Double.self, forKey: .crescitaReddito)
        anniContributi = try? c.decodeIfPresent(Double.self, forKey: .anniContributi)
        annoPrimoContributo = try? c.decodeIfPresent(Int.self, forKey: .annoPrimoContributo)
        montanteContributivo = try? c.decodeIfPresent(Double.self, forKey: .montanteContributivo)
        etaPensione = try? c.decodeIfPresent(Int.self, forKey: .etaPensione)
    }
}

/// Profilo dell'investitore (propensione, orizzonte, esperienza, obiettivi).
struct ProfiloInvestitore: Codable, Hashable {
    enum Propensione: String, Codable, CaseIterable, Identifiable {
        case prudente, moderata, dinamica, aggressiva
        var id: String { rawValue }
        var nome: String { rawValue.capitalized }
    }

    enum Esperienza: String, Codable, CaseIterable, Identifiable {
        case nessuna, base, media, elevata
        var id: String { rawValue }
        var nome: String { rawValue.capitalized }
    }

    var propensione: Propensione?
    var orizzonteAnni: Int?
    var esperienza: Esperienza?
    var obiettivi = ""
    var aggiornatoIl: Date?
    /// Reddito complessivo lordo annuo, per l'aliquota IRPEF marginale (deducibilità della previdenza).
    var redditoLordoAnnuo: Double?
    // Dati per la pensione e la protezione per persona (facoltativi: Codable sintetizzato, solo Optional)
    /// Reddito netto annuo che il cliente porta in famiglia (€); se manca si stima dal lordo.
    var redditoNettoAnnuo: Double?
    /// Lavoro e contributi del cliente, per la pensione pubblica stimata con il contributivo.
    var lavoro: DatiLavoro?
    /// Esperienza per tipo di prodotto e capacità di sostenere perdite (dalla versione 21 dell'archivio).
    /// nil = mai compilata: nessun controllo sulle proposte (le prove di prima restano uguali).
    var esperienzaProdotti: EsperienzaProdotti?

    /// Reddito lordo annuo da lavoro: quello del lavoro se indicato, altrimenti il reddito complessivo.
    var redditoDaLavoro: Double? { lavoro?.redditoLavoro ?? redditoLordoAnnuo }
}

struct Consensi: Codable, Hashable {
    var privacy = false
    var dataPrivacy: Date?
    var marketing = false
}

/// Tipo di appuntamento: aiuta a capire a che punto è la relazione con il cliente.
enum TipoAppuntamento: String, Codable, CaseIterable, Identifiable {
    case primoIncontro, analisi, proposta, firma, revisione, telefonata, altro

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .primoIncontro: return "Primo incontro"
        case .analisi: return "Analisi delle posizioni"
        case .proposta: return "Presentazione di una proposta"
        case .firma: return "Firma"
        case .revisione: return "Revisione periodica"
        case .telefonata: return "Telefonata"
        case .altro: return "Altro"
        }
    }
}

struct Appuntamento: Identifiable, Codable, Hashable {
    enum Stato: String, Codable { case pianificato, concluso }

    let id: String
    var clienteId: String
    var titolo: String
    var inizio: Date
    var durataMinuti: Int
    var luogo: String
    var note: String
    var stato: Stato
    // Dalla versione 4 dell'archivio
    var tipo: TipoAppuntamento = .altro
    /// Canale su cui verte l'incontro (nil = entrambi o non indicato).
    var canale: Canale?
    /// Posizione di cui si parla (per esempio una polizza in scadenza o una proposta).
    var posizioneId: String?

    init(id: String, clienteId: String, titolo: String, inizio: Date, durataMinuti: Int, luogo: String,
         note: String, stato: Stato, tipo: TipoAppuntamento = .altro, canale: Canale? = nil, posizioneId: String? = nil) {
        self.id = id
        self.clienteId = clienteId
        self.titolo = titolo
        self.inizio = inizio
        self.durataMinuti = durataMinuti
        self.luogo = luogo
        self.note = note
        self.stato = stato
        self.tipo = tipo
        self.canale = canale
        self.posizioneId = posizioneId
    }

    var fine: Date { inizio.addingTimeInterval(TimeInterval(durataMinuti * 60)) }

    /// Nuovo appuntamento proposto dal modulo: prossima mezz'ora libera del giorno scelto.
    static func nuovo(clienteId: String, giorno: Date) -> Appuntamento {
        let cal = Calendar.current
        var inizio = cal.date(bySettingHour: 9, minute: 30, second: 0, of: giorno) ?? giorno
        if cal.isDateInToday(giorno) {
            let adesso = Date()
            let minuti = cal.component(.minute, from: adesso)
            let prossima = cal.date(byAdding: .minute, value: minuti < 30 ? 30 - minuti : 60 - minuti, to: adesso) ?? adesso
            // Dopo le 23:30 non si scivola al giorno dopo
            let ultimo = cal.date(bySettingHour: 23, minute: 30, second: 0, of: giorno) ?? giorno
            inizio = min(max(inizio, alMinuto(prossima)), ultimo)
        }
        return Appuntamento(id: "event-\(UUID().uuidString.prefix(8).lowercased())", clienteId: clienteId, titolo: "",
                            inizio: inizio, durataMinuti: 45, luogo: "In studio", note: "", stato: .pianificato)
    }

    /// Toglie secondi e frazioni (l'archivio JSON conserva solo i secondi interi).
    static func alMinuto(_ d: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (d.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        clienteId = try c.decode(String.self, forKey: .clienteId)
        titolo = try c.decodeIfPresent(String.self, forKey: .titolo) ?? ""
        inizio = try c.decode(Date.self, forKey: .inizio)
        durataMinuti = try c.decodeIfPresent(Int.self, forKey: .durataMinuti) ?? 45
        luogo = try c.decodeIfPresent(String.self, forKey: .luogo) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        stato = try c.decodeIfPresent(Stato.self, forKey: .stato) ?? .pianificato
        tipo = try c.decodeIfPresent(TipoAppuntamento.self, forKey: .tipo) ?? .altro
        canale = try c.decodeIfPresent(Canale.self, forKey: .canale)
        posizioneId = try c.decodeIfPresent(String.self, forKey: .posizioneId)
    }
}

struct Attivita: Identifiable, Codable, Hashable {
    enum Priorita: String, Codable, CaseIterable, Identifiable {
        case alta, normale, bassa

        var id: String { rawValue }
        var nome: String {
            switch self {
            case .alta: return "Alta"
            case .normale: return "Normale"
            case .bassa: return "Bassa"
            }
        }
        var ordine: Int {
            switch self {
            case .alta: return 0
            case .normale: return 1
            case .bassa: return 2
            }
        }
    }

    let id: String
    var clienteId: String
    var titolo: String
    var scadenza: Date
    var priorita: Priorita
    var completata: Bool
    // Dalla versione 4 dell'archivio
    var note = ""
    /// Appuntamento da cui è nata l'attività.
    var appuntamentoId: String?

    init(id: String, clienteId: String, titolo: String, scadenza: Date, priorita: Priorita, completata: Bool,
         note: String = "", appuntamentoId: String? = nil) {
        self.id = id
        self.clienteId = clienteId
        self.titolo = titolo
        self.scadenza = scadenza
        self.priorita = priorita
        self.completata = completata
        self.note = note
        self.appuntamentoId = appuntamentoId
    }

    static func nuova(clienteId: String, scadenza: Date = Date()) -> Attivita {
        Attivita(id: "task-\(UUID().uuidString.prefix(8).lowercased())", clienteId: clienteId, titolo: "",
                 scadenza: Calendar.current.startOfDay(for: scadenza), priorita: .normale, completata: false)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        clienteId = try c.decode(String.self, forKey: .clienteId)
        titolo = try c.decodeIfPresent(String.self, forKey: .titolo) ?? ""
        scadenza = try c.decode(Date.self, forKey: .scadenza)
        priorita = try c.decodeIfPresent(Priorita.self, forKey: .priorita) ?? .normale
        completata = try c.decodeIfPresent(Bool.self, forKey: .completata) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        appuntamentoId = try c.decodeIfPresent(String.self, forKey: .appuntamentoId)
    }
}

/// Appuntamenti e scadenze di un intervallo dell'agenda, per giorno (vedi `StatoShell.giorniAgenda`).
struct GiorniAgenda {
    var perGiorno: [Date: [Appuntamento]] = [:]
    var scadenzePerGiorno: [Date: [Posizione]] = [:]

    func appuntamenti(_ giorno: Date) -> [Appuntamento] { perGiorno[Calendar.current.startOfDay(for: giorno)] ?? [] }
    func scadenze(_ giorno: Date) -> [Posizione] { scadenzePerGiorno[Calendar.current.startOfDay(for: giorno)] ?? [] }
}
