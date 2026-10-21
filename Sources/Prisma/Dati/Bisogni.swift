import Foundation

/// Le sei aree di vita della mappa dei bisogni.
enum AreaBisogno: String, Codable, CaseIterable, Identifiable {
    case casa, famiglia, lavoro, pensione, salute, patrimonio

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .casa: return "Casa"
        case .famiglia: return "Famiglia e figli"
        case .lavoro: return "Lavoro e reddito"
        case .pensione: return "Pensione"
        case .salute: return "Salute e imprevisti"
        case .patrimonio: return "Patrimonio e successione"
        }
    }

    /// La domanda da fare al cliente, in una riga.
    var domanda: String {
        switch self {
        case .casa: return "Una casa da comprare, cambiare o ristrutturare?"
        case .famiglia: return "Chi dipende da te, e cosa vuoi garantirgli?"
        case .lavoro: return "Il reddito è stabile? Ci sono cambiamenti in vista?"
        case .pensione: return "A che età e con quale tenore di vita?"
        case .salute: return "Se ti fermassi per un po', come andrebbe avanti?"
        case .patrimonio: return "Cosa vuoi far crescere, proteggere o lasciare?"
        }
    }

    var simbolo: String {
        switch self {
        case .casa: return "house.fill"
        case .famiglia: return "figure.2.and.child.holdinghands"
        case .lavoro: return "briefcase.fill"
        case .pensione: return "sun.horizon.fill"
        case .salute: return "cross.case.fill"
        case .patrimonio: return "building.columns.fill"
        }
    }

    /// L'area dell'Analisi 360 che risponde a questo bisogno.
    var areaAnalisi: AreaAnalisi {
        switch self {
        case .casa: return .risparmio
        case .famiglia, .salute: return .protezione
        case .lavoro: return .risparmio
        case .pensione: return .previdenza
        case .patrimonio: return .investimenti
        }
    }
}

/// Quanto conta un'area per il cliente.
enum Importanza: Int, Codable, CaseIterable, Identifiable, Comparable {
    case nessuna = 0, bassa, media, alta

    var id: Int { rawValue }

    var nome: String {
        switch self {
        case .nessuna: return "Non ora"
        case .bassa: return "Bassa"
        case .media: return "Media"
        case .alta: return "Alta"
        }
    }

    static func < (a: Importanza, b: Importanza) -> Bool { a.rawValue < b.rawValue }
}

/// Entro quando il cliente vuole occuparsene.
enum OrizzonteBisogno: String, Codable, CaseIterable, Identifiable {
    case presto, medio, lungo

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .presto: return "Entro 2 anni"
        case .medio: return "2–10 anni"
        case .lungo: return "Oltre 10"
        }
    }
}

/// La valutazione di un'area fatta con il cliente.
struct ValutazioneBisogno: Codable, Hashable {
    var area: AreaBisogno
    var importanza: Importanza = .nessuna
    var orizzonte: OrizzonteBisogno?
}

/// Un evento della vita del cliente, passato o in arrivo.
struct EventoVita: Identifiable, Codable, Hashable {
    enum Tipo: String, Codable, CaseIterable, Identifiable {
        case figlioInArrivo, matrimonio, acquistoCasa, studiFigli, cambioLavoro, avvioAttivita
        case separazione, eredita, pensione, altro

        var id: String { rawValue }

        var nome: String {
            switch self {
            case .figlioInArrivo: return "Figlio in arrivo"
            case .matrimonio: return "Matrimonio o convivenza"
            case .acquistoCasa: return "Acquisto casa"
            case .studiFigli: return "Studi dei figli"
            case .cambioLavoro: return "Cambio di lavoro"
            case .avvioAttivita: return "Avvio di un'attività"
            case .separazione: return "Separazione"
            case .eredita: return "Eredità o donazione"
            case .pensione: return "Pensione"
            case .altro: return "Altro"
            }
        }

        /// Le aree di vita che l'evento tocca.
        var aree: [AreaBisogno] {
            switch self {
            case .figlioInArrivo: return [.famiglia, .salute]
            case .matrimonio: return [.famiglia, .casa]
            case .acquistoCasa: return [.casa, .famiglia]
            case .studiFigli: return [.famiglia]
            case .cambioLavoro: return [.lavoro, .pensione]
            case .avvioAttivita: return [.lavoro, .salute]
            case .separazione: return [.famiglia, .patrimonio]
            case .eredita: return [.patrimonio]
            case .pensione: return [.pensione, .patrimonio]
            case .altro: return []
            }
        }
    }

    var id = "evento-\(UUID().uuidString.prefix(8).lowercased())"
    var tipo: Tipo
    var anno: Int
    var nota = ""
}

/// Il profilo dei bisogni del cliente: mappa delle aree, eventi di vita e bisogni rilevati confermati.
struct ProfiloBisogni: Codable, Hashable {
    var valutazioni: [ValutazioneBisogno] = []
    var eventi: [EventoVita] = []
    /// Bisogni rilevati dai dati: identificativo → confermato (true) o scartato (false).
    var esiti: [String: Bool] = [:]
    var aggiornatoIl: Date?

    init() {}

    func valutazione(_ a: AreaBisogno) -> ValutazioneBisogno {
        valutazioni.first { $0.area == a } ?? ValutazioneBisogno(area: a)
    }

    mutating func imposta(_ v: ValutazioneBisogno) {
        valutazioni.removeAll { $0.area == v.area }
        valutazioni.append(v)
    }

    var compilato: Bool { valutazioni.contains { $0.importanza != .nessuna } || !eventi.isEmpty || !esiti.isEmpty }

    private enum CodingKeys: String, CodingKey { case valutazioni, eventi, esiti, aggiornatoIl }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        valutazioni = (try? c.decodeIfPresent([ValutazioneBisogno].self, forKey: .valutazioni)) ?? []
        eventi = (try? c.decodeIfPresent([EventoVita].self, forKey: .eventi)) ?? []
        esiti = (try? c.decodeIfPresent([String: Bool].self, forKey: .esiti)) ?? [:]
        aggiornatoIl = try? c.decodeIfPresent(Date.self, forKey: .aggiornatoIl)
    }
}
