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

    var eta: Int? {
        dataNascita.flatMap { Calendar.current.dateComponents([.year], from: $0, to: Date()).year }
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
            inizio = max(inizio, alMinuto(prossima))
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
