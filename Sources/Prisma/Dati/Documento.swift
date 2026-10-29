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
    /// Scheda prodotto o posizione create da questo documento o collegate (confronto con il dossier, storico dei valori).
    var prodottoId: String?
    var posizioneId: String?
    // Dalla versione 23 dell'archivio
    /// Il gruppo scelto da Prisma alla lettura o dal consulente; nil = dal tipo (archivi di prima).
    var categoria: CategoriaDocumento?
    /// Le righe del confronto con il dossier che il consulente ha deciso di lasciare come sono in Prisma
    /// (`RigaDossier.chiave`: voce e i due valori). nil = nessuna. Una chiave vale finché i due valori restano quelli.
    var vociTenute: [String]?

    /// La categoria che conta: prospetti e report sono sempre «di Prisma».
    var genere: CategoriaDocumento {
        tipo.creatoDaPrisma ? .prisma : (categoria ?? .da(tipo))
    }
    /// Appendice di polizza: una `.polizza` con «appendice» nel titolo o nel nome letto.
    var appendice: Bool {
        guard tipo == .polizza else { return false }
        if titolo.localizedCaseInsensitiveContains("appendice") { return true }
        return campo(.nomeProdotto)?.valore.localizedCaseInsensitiveContains("appendice") ?? false
    }

    init(clienteId: String, titolo: String, tipo: Tipo) {
        self.clienteId = clienteId
        self.titolo = titolo
        self.tipo = tipo
    }

    private enum CodingKeys: String, CodingKey {
        case id, clienteId, titolo, tipo, file, pagine, dimensione, importatoIl, lettura, pagineOCR, campi, prodottoId, posizioneId
        case categoria, vociTenute
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        clienteId = try c.decode(String.self, forKey: .clienteId)
        titolo = try c.decodeIfPresent(String.self, forKey: .titolo) ?? "Documento"
        // Un tipo sconosciuto (archivio di una versione più nuova) non fa perdere il documento
        tipo = (try? c.decodeIfPresent(Tipo.self, forKey: .tipo)) ?? .altro
        file = try c.decodeIfPresent(String.self, forKey: .file)
        pagine = try c.decodeIfPresent(Int.self, forKey: .pagine) ?? 0
        dimensione = try c.decodeIfPresent(Int64.self, forKey: .dimensione) ?? 0
        importatoIl = try c.decodeIfPresent(Date.self, forKey: .importatoIl) ?? Date()
        lettura = try c.decodeIfPresent(Lettura.self, forKey: .lettura) ?? .daLeggere
        pagineOCR = try c.decodeIfPresent(Int.self, forKey: .pagineOCR) ?? 0
        // Un dato con una chiave sconosciuta si salta, gli altri restano
        campi = (try? c.decodeIfPresent(ElencoTollerante<CampoEstratto>.self, forKey: .campi))?.elementi ?? []
        prodottoId = try c.decodeIfPresent(String.self, forKey: .prodottoId)
        posizioneId = try c.decodeIfPresent(String.self, forKey: .posizioneId)
        categoria = try? c.decodeIfPresent(CategoriaDocumento.self, forKey: .categoria)
        vociTenute = try? c.decodeIfPresent([String].self, forKey: .vociTenute)
    }

    func campo(_ chiave: CampoDocumento) -> CampoEstratto? {
        campi.first { $0.chiave == chiave }
    }

    /// Valore confermato di un campo (i dati non confermati non entrano nel dossier).
    func confermato(_ chiave: CampoDocumento) -> String? {
        campi.first { $0.chiave == chiave && $0.confermato && !$0.valore.trimmingCharacters(in: .whitespaces).isEmpty }?.valore
    }
}

/// I gruppi dell'elenco dei Documenti (dalla versione 23 dell'archivio). `Documento.Tipo` resta com'è perché lo
/// usano Eve e i prospetti; la categoria lo affina: per Eve i documenti d'identità e i questionari sono `.altro`.
enum CategoriaDocumento: String, Codable, CaseIterable, Identifiable {
    case kid, contratto, estratto, identita, questionario, altro, prisma

    var id: String { rawValue }

    /// Titolo del gruppo nell'elenco e nella barra laterale.
    var nome: String {
        switch self {
        case .kid: return "KID e documenti informativi"
        case .contratto: return "Polizze e contratti"
        case .estratto: return "Estratti conto"
        case .identita: return "Documenti d'identità"
        case .questionario: return "Questionari"
        case .altro: return "Altri documenti"
        case .prisma: return "Prospetti e report di Prisma"
        }
    }

    /// Nell'elenco, nei menu e nella barra laterale.
    var breve: String {
        switch self {
        case .kid: return "KID"
        case .contratto: return "Polizza o contratto"
        case .estratto: return "Estratto conto"
        case .identita: return "Identità"
        case .questionario: return "Questionario"
        case .altro: return "Altro"
        case .prisma: return "Di Prisma"
        }
    }

    /// Simbolo SF (tutti disponibili da macOS 12).
    var simbolo: String {
        switch self {
        case .kid: return "doc.text.magnifyingglass"
        case .contratto: return "doc.richtext"
        case .estratto: return "list.bullet.rectangle"
        case .identita: return "person.text.rectangle"
        case .questionario: return "checklist"
        case .altro: return "doc"
        case .prisma: return "doc.plaintext"
        }
    }

    /// Si sceglie nel menu (prospetti e report li archivia Prisma).
    var selezionabile: Bool { self != .prisma }

    /// L'ordine dei gruppi nell'elenco.
    static let ordine: [CategoriaDocumento] = [.kid, .contratto, .estratto, .identita, .questionario, .altro, .prisma]

    /// La categoria di un documento senza categoria (archivi fino alla versione 22).
    static func da(_ tipo: Documento.Tipo) -> CategoriaDocumento {
        switch tipo {
        case .kid: return .kid
        case .polizza, .proposta: return .contratto
        case .estrattoConto: return .estratto
        case .prospetto, .report: return .prisma
        case .altro: return .altro
        }
    }

    /// Il tipo da dare al documento quando il consulente sceglie questa categoria.
    func tipo(da attuale: Documento.Tipo) -> Documento.Tipo {
        switch self {
        case .kid: return .kid
        case .contratto: return attuale == .proposta ? .proposta : .polizza
        case .estratto: return .estrattoConto
        case .identita, .questionario, .altro: return .altro
        case .prisma: return attuale.creatoDaPrisma ? attuale : .prospetto
        }
    }
}

/// I dati che Prisma sa cercare nei documenti.
enum CampoDocumento: String, Codable, CaseIterable, Identifiable {
    case nomeProdotto, emittente, tipologia, sri, periodoDetenzione, costoIngresso, costoUscita, costoAnnuo
    case incidenzaCosti, rendimentoModerato, numeroContratto, contraente, assicurato, beneficiari
    case decorrenza, scadenza, premio, capitaleAssicurato, controvalore
    // Dalla versione 19 dell'archivio: la data del valore e il versato degli estratti conto
    case dataValore, totaleVersato
    // Dalla versione 23 dell'archivio: KID più completi, documenti d'identità e questionari
    case isin, dataDocumento, rendimentoPrimaCosti
    case numeroDocumento, intestatario, codiceFiscale, dataRilascio
    case profiloRischio, orizzonte

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
        case .isin: return "Codice ISIN"
        case .dataDocumento: return "Data del documento"
        case .rendimentoPrimaCosti: return "Rendimento prima dei costi"
        case .numeroDocumento: return "Numero del documento"
        case .intestatario: return "Intestatario"
        case .codiceFiscale: return "Codice fiscale"
        case .dataRilascio: return "Data di rilascio"
        case .profiloRischio: return "Profilo di rischio"
        case .orizzonte: return "Orizzonte temporale"
        }
    }

    /// Unità mostrata accanto al valore.
    var unita: String {
        switch self {
        case .costoIngresso, .costoUscita, .costoAnnuo, .incidenzaCosti, .rendimentoModerato, .rendimentoPrimaCosti: return "%"
        case .periodoDetenzione, .orizzonte: return "anni"
        case .premio, .capitaleAssicurato, .controvalore, .totaleVersato: return "€"
        case .sri: return "su 7"
        default: return ""
        }
    }
}

/// Le sezioni della scheda di un documento, in quest'ordine.
enum SezioneDocumento: String, CaseIterable, Identifiable {
    case chi, cosa, cifre, costi, rischio, scadenze

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .chi: return "Chi"
        case .cosa: return "Che cosa"
        case .cifre: return "Cifre chiave"
        case .costi: return "Costi"
        case .rischio: return "Rischio"
        case .scadenze: return "Date e scadenze"
        }
    }
}

extension CampoDocumento {
    /// La sezione della scheda (e l'ordine della tabella di confronto).
    var sezione: SezioneDocumento {
        switch self {
        case .emittente, .contraente, .assicurato, .beneficiari, .intestatario, .codiceFiscale: return .chi
        case .nomeProdotto, .tipologia, .numeroContratto, .isin, .numeroDocumento: return .cosa
        case .premio, .capitaleAssicurato, .controvalore, .totaleVersato, .rendimentoModerato, .rendimentoPrimaCosti: return .cifre
        case .costoIngresso, .costoUscita, .costoAnnuo, .incidenzaCosti: return .costi
        case .sri, .periodoDetenzione, .profiloRischio, .orizzonte: return .rischio
        case .decorrenza, .scadenza, .dataValore, .dataDocumento, .dataRilascio: return .scadenze
        }
    }

    /// I dati che sono date (per la formattazione e i controlli).
    var data: Bool { [.decorrenza, .scadenza, .dataValore, .dataDocumento, .dataRilascio].contains(self) }
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
