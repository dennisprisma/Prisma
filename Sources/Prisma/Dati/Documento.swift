import Foundation

/// Un documento del cliente (KID, polizza, estratto conto, proposta…), conservato nella
/// cartella Documenti dell'archivio. Il testo letto sta accanto al file (`<id>.txt`, una
/// pagina per blocco), così l'archivio JSON resta leggero.
struct Documento: Identifiable, Codable, Hashable {
    enum Tipo: String, Codable, CaseIterable, Identifiable {
        case kid, polizza, estrattoConto, proposta, prospetto, report, altro

        var id: String { rawValue }

        var nome: String {
            switch self {
            case .kid: return "KID / documento informativo"
            case .polizza: return "Polizza o contratto"
            case .estrattoConto: return "Estratto conto"
            case .proposta: return "Proposta"
            case .prospetto: return "Prospetto di Prisma"
            case .report: return "Report per il cliente"
            case .altro: return "Altro"
            }
        }

        /// Prospetti e report li scrive Prisma: non c'è niente da estrarre.
        var creatoDaPrisma: Bool { self == .prospetto || self == .report }

        var breve: String {
            switch self {
            case .kid: return "KID"
            case .polizza: return "Polizza"
            case .estrattoConto: return "Estratto"
            case .proposta: return "Proposta"
            case .prospetto: return "Prospetto"
            case .report: return "Report"
            case .altro: return "Altro"
            }
        }
    }

    enum Lettura: String, Codable {
        case daLeggere, letto, illeggibile
    }

    var id = "doc-\(UUID().uuidString.prefix(8).lowercased())"
    var clienteId: String
    var titolo: String
    var tipo: Tipo
    /// Percorso del file dentro la cartella Documenti (nil per i documenti di prova).
    var file: String?
    var pagine = 0
    var dimensione: Int64 = 0
    var importatoIl = Date()
    var lettura = Lettura.daLeggere
    /// Pagine lette con il riconoscimento del testo (scansioni).
    var pagineOCR = 0
    var campi: [CampoEstratto] = []
    /// Scheda prodotto o posizione create da questo documento.
    var prodottoId: String?
    var posizioneId: String?

    init(clienteId: String, titolo: String, tipo: Tipo) {
        self.clienteId = clienteId
        self.titolo = titolo
        self.tipo = tipo
    }

    private enum CodingKeys: String, CodingKey {
        case id, clienteId, titolo, tipo, file, pagine, dimensione, importatoIl, lettura, pagineOCR, campi, prodottoId, posizioneId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        clienteId = try c.decode(String.self, forKey: .clienteId)
        titolo = try c.decodeIfPresent(String.self, forKey: .titolo) ?? "Documento"
        tipo = try c.decodeIfPresent(Tipo.self, forKey: .tipo) ?? .altro
        file = try c.decodeIfPresent(String.self, forKey: .file)
        pagine = try c.decodeIfPresent(Int.self, forKey: .pagine) ?? 0
        dimensione = try c.decodeIfPresent(Int64.self, forKey: .dimensione) ?? 0
        importatoIl = try c.decodeIfPresent(Date.self, forKey: .importatoIl) ?? Date()
        lettura = try c.decodeIfPresent(Lettura.self, forKey: .lettura) ?? .daLeggere
        pagineOCR = try c.decodeIfPresent(Int.self, forKey: .pagineOCR) ?? 0
        campi = (try? c.decodeIfPresent([CampoEstratto].self, forKey: .campi)) ?? []
        prodottoId = try c.decodeIfPresent(String.self, forKey: .prodottoId)
        posizioneId = try c.decodeIfPresent(String.self, forKey: .posizioneId)
    }

    func campo(_ chiave: CampoDocumento) -> CampoEstratto? {
        campi.first { $0.chiave == chiave }
    }

    /// Valore confermato di un campo (i dati non confermati non entrano nel dossier).
    func confermato(_ chiave: CampoDocumento) -> String? {
        campi.first { $0.chiave == chiave && $0.confermato && !$0.valore.trimmingCharacters(in: .whitespaces).isEmpty }?.valore
    }
}

/// I dati che Prisma sa cercare nei documenti.
enum CampoDocumento: String, Codable, CaseIterable, Identifiable {
    case nomeProdotto, emittente, tipologia, sri, periodoDetenzione, costoIngresso, costoUscita, costoAnnuo
    case incidenzaCosti, rendimentoModerato, numeroContratto, contraente, assicurato, beneficiari
    case decorrenza, scadenza, premio, capitaleAssicurato, controvalore
    // Dalla versione 19 dell'archivio: la data del valore e il versato degli estratti conto
    case dataValore, totaleVersato

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .nomeProdotto: return "Nome del prodotto"
        case .emittente: return "Compagnia o ideatore"
        case .tipologia: return "Tipologia"
        case .sri: return "Indicatore di rischio (SRI)"
        case .periodoDetenzione: return "Periodo di detenzione raccomandato"
        case .costoIngresso: return "Costo d'ingresso"
        case .costoUscita: return "Costo d'uscita"
        case .costoAnnuo: return "Costi correnti annui"
        case .incidenzaCosti: return "Incidenza annuale dei costi"
        case .rendimentoModerato: return "Rendimento, scenario moderato"
        case .numeroContratto: return "Numero di polizza o contratto"
        case .contraente: return "Contraente"
        case .assicurato: return "Assicurato"
        case .beneficiari: return "Beneficiari"
        case .decorrenza: return "Decorrenza"
        case .scadenza: return "Scadenza"
        case .premio: return "Premio"
        case .capitaleAssicurato: return "Capitale assicurato"
        case .controvalore: return "Controvalore"
        case .dataValore: return "Data del valore"
        case .totaleVersato: return "Totale versato"
        }
    }

    /// Unità mostrata accanto al valore.
    var unita: String {
        switch self {
        case .costoIngresso, .costoUscita, .costoAnnuo, .incidenzaCosti, .rendimentoModerato: return "%"
        case .periodoDetenzione: return "anni"
        case .premio, .capitaleAssicurato, .controvalore, .totaleVersato: return "€"
        case .sri: return "su 7"
        default: return ""
        }
    }
}

/// Un dato trovato in un documento, con la pagina da cui viene.
struct CampoEstratto: Identifiable, Codable, Hashable {
    var chiave: CampoDocumento
    var valore: String
    /// Pagina (da 1) in cui si trova il dato.
    var pagina: Int
    /// La riga del documento da cui viene il valore.
    var estratto = ""
    var origine = "Regole di Prisma"
    var confermato = false

    var id: String { chiave.rawValue }
}

/// I testi dei documenti tenuti in memoria, con un tetto di caratteri: oltre il tetto si
/// dimenticano i meno recenti (si rileggono dal disco quando servono di nuovo).
struct MemoriaTesti {
    /// Circa 8–16 MB di testo: abbastanza per i documenti aperti, poco per un Mac da 8 GB.
    static let limiteCaratteri = 4_000_000

    private var testi: [String: [String]] = [:]
    /// Dal meno recente al più recente.
    private var ordine: [String] = []
    private(set) var caratteri = 0
    var limite = MemoriaTesti.limiteCaratteri

    var conta: Int { testi.count }

    subscript(id: String) -> [String]? {
        get { testi[id] }
        set {
            if let vecchio = testi.removeValue(forKey: id) {
                caratteri -= MemoriaTesti.misura(vecchio)
                ordine.removeAll { $0 == id }
            }
            guard let nuovo = newValue else { return }
            testi[id] = nuovo
            ordine.append(id)
            caratteri += MemoriaTesti.misura(nuovo)
            // Il più recente resta sempre, anche se da solo supera il tetto
            while caratteri > limite, ordine.count > 1 {
                let via = ordine.removeFirst()
                caratteri -= testi.removeValue(forKey: via).map(MemoriaTesti.misura) ?? 0
            }
        }
    }

    private static func misura(_ pagine: [String]) -> Int { pagine.reduce(0) { $0 + $1.utf16.count } }
}
