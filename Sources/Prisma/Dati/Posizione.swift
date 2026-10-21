import Foundation

/// Area di una posizione del cliente.
enum AreaPosizione: String, Codable, CaseIterable, Identifiable {
    case investimento, risparmio, previdenza, protezione, liquidita, immobili, debiti

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .investimento: return "Investimento"
        case .risparmio: return "Risparmio"
        case .previdenza: return "Previdenza"
        case .protezione: return "Protezione"
        case .liquidita: return "Liquidità"
        case .immobili: return "Immobili"
        case .debiti: return "Debiti"
        }
    }

    /// Le aree che hanno senso proiettare nel tempo.
    var proiettabile: Bool { [.investimento, .risparmio, .previdenza].contains(self) }

    /// I debiti si sottraggono al patrimonio.
    var passivo: Bool { self == .debiti }
}

/// In essere, in proposta (non in essere) o chiusa.
enum StatoPosizione: String, Codable, CaseIterable, Identifiable {
    case inEssere, proposta, chiusa

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .inEssere: return "In essere"
        case .proposta: return "Proposta"
        case .chiusa: return "Chiusa"
        }
    }
}

/// Avanzamento di una proposta.
enum EsitoProposta: String, Codable, CaseIterable, Identifiable {
    case bozza, presentata, accettata, rifiutata

    var id: String { rawValue }
    var nome: String { rawValue.capitalized }
}

/// Frequenza dei premi o dei versamenti.
enum Frequenza: String, Codable, CaseIterable, Identifiable {
    case unica, mensile, trimestrale, semestrale, annuale

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .unica: return "Nessun versamento periodico"
        case .mensile: return "Mensile"
        case .trimestrale: return "Trimestrale"
        case .semestrale: return "Semestrale"
        case .annuale: return "Annuale"
        }
    }

    var volteAllAnno: Int {
        switch self {
        case .unica: return 0
        case .mensile: return 12
        case .trimestrale: return 4
        case .semestrale: return 2
        case .annuale: return 1
        }
    }
}

/// Rischio coperto da una posizione di protezione.
enum RischioCoperto: String, Codable, CaseIterable, Identifiable {
    case vita, invalidita, salute, ltc, infortuni, casa, rc, altro

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .vita: return "Caso morte"
        case .invalidita: return "Invalidità"
        case .salute: return "Salute"
        case .ltc: return "Non autosufficienza (LTC)"
        case .infortuni: return "Infortuni"
        case .casa: return "Casa"
        case .rc: return "Responsabilità civile"
        case .altro: return "Altro"
        }
    }
}

/// Una posizione del cliente: un prodotto in essere o una proposta, sempre con il suo canale.
struct Posizione: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var clienteId: String
    var canale: Canale
    var stato: StatoPosizione
    var area: AreaPosizione

    // Prodotto
    var nome: String
    var tipologia = ""
    var emittente = ""
    var numeroContratto = ""
    var contraente = ""
    var assicurato = ""
    var beneficiari = ""
    var decorrenza: Date?
    var scadenza: Date?

    // Flussi
    /// Capitale iniziale o premio unico.
    var versamentoIniziale: Double = 0
    /// Importo del premio o del versamento periodico.
    var premio: Double = 0
    var frequenza: Frequenza = .unica

    // Valori
    /// Valore attuale (controvalore o, per i debiti, debito residuo).
    var controvalore: Double?
    var dataValore: Date?
    var totaleVersato: Double?
    var capitaleAssicurato: Double?
    var rischio: RischioCoperto?

    // Ipotesi e costi (percentuali annue)
    var rendimentoAtteso: Double?
    var costoIngresso: Double?
    var costoAnnuo: Double?
    var aliquotaFiscale: Double?
    /// Indicatore sintetico di rischio del KID (1–7).
    var sri: Int?

    var garanzie = ""
    var note = ""
    var esito: EsitoProposta?
    var creataIl = Date()

    /// Premi o versamenti dell'anno.
    var premioAnnuo: Double { premio * Double(frequenza.volteAllAnno) }

    /// Valore da usare nei riepiloghi: il controvalore se c'è, altrimenti il versato.
    var valore: Double {
        controvalore ?? totaleVersato ?? versamentoIniziale
    }

    /// Anni da oggi alla scadenza (almeno 1), se la scadenza è indicata.
    var anniAllaScadenza: Int? {
        guard let scadenza else { return nil }
        let anni = Calendar.current.dateComponents([.year], from: Date(), to: scadenza).year ?? 0
        return max(1, anni)
    }

    /// true se la scadenza cade entro `giorni` da oggi.
    func scadeEntro(_ giorni: Int) -> Bool {
        guard let scadenza, stato == .inEssere else { return false }
        let limite = Calendar.current.date(byAdding: .day, value: giorni, to: Date()) ?? Date()
        return scadenza >= Calendar.current.startOfDay(for: Date()) && scadenza <= limite
    }

    var scaduta: Bool {
        guard let scadenza, stato == .inEssere else { return false }
        return scadenza < Calendar.current.startOfDay(for: Date())
    }
}
