import Foundation

/// Canale con cui il consulente lavora una posizione o una proposta.
enum Canale: String, Codable, CaseIterable, Identifiable {
    case alleanza
    case indipendente

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .alleanza: return "Alleanza Assicurazioni"
        case .indipendente: return "Dennis Vincenzoni · Consulenza finanziaria"
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
        case dataNascita, codiceFiscale, professione, statoCivile, indirizzo, canali, famiglia, profilo, consensi
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
}

struct Attivita: Identifiable, Codable, Hashable {
    enum Priorita: String, Codable { case alta, normale, bassa }

    let id: String
    var clienteId: String
    var titolo: String
    var scadenza: Date
    var priorita: Priorita
    var completata: Bool
}
