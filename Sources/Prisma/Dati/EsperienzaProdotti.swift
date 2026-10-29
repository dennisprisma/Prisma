import Foundation

/// I tipi di prodotto della griglia dell'esperienza (dalla versione 21 dell'archivio). L'ordine è quello
/// delle righe nella griglia e nella scheda di adeguatezza. I nuovi tipi vanno in fondo.
enum TipoProdotto: String, Codable, CaseIterable, Identifiable {
    case ramoI, ramoIII, multiramo, fondiETF, titoli, previdenza, protezione

    var id: String { rawValue }

    /// Nella griglia e nelle pillole.
    var nome: String {
        switch self {
        case .ramoI: return "Ramo I · gestione separata"
        case .ramoIII: return "Ramo III · unit linked"
        case .multiramo: return "Multiramo"
        case .fondiETF: return "Fondi ed ETF"
        case .titoli: return "Azioni e obbligazioni"
        case .previdenza: return "Previdenza complementare"
        case .protezione: return "Protezione"
        }
    }

    /// Dentro una frase («il cliente ha detto di non conoscere …»).
    var descrizione: String {
        switch self {
        case .ramoI: return "le polizze di Ramo I (gestione separata)"
        case .ramoIII: return "le unit linked (Ramo III)"
        case .multiramo: return "le polizze multiramo"
        case .fondiETF: return "i fondi comuni e gli ETF"
        case .titoli: return "le azioni e le obbligazioni"
        case .previdenza: return "la previdenza complementare (fondi pensione e PIP)"
        case .protezione: return "le polizze di protezione"
        }
    }

    /// Esempi, per l'aiuto al passaggio del mouse sul nome della riga.
    var esempi: String {
        switch self {
        case .ramoI: return "Rivalutabili a premio unico o ricorrente, contratti di capitalizzazione."
        case .ramoIII: return "Polizze collegate a fondi interni o OICR, senza garanzia sul capitale."
        case .multiramo: return "Una parte in gestione separata e una in fondi, nello stesso contratto."
        case .fondiETF: return "Fondi comuni, SICAV, ETF, gestioni patrimoniali, piani di accumulo."
        case .titoli: return "Azioni, BTP e titoli di Stato, obbligazioni societarie, certificati."
        case .previdenza: return "Fondi pensione aperti e negoziali, PIP."
        case .protezione: return "Caso morte, infortuni, invalidità, salute, non autosufficienza (LTC)."
        }
    }
}

/// Le tre domande della griglia.
enum DomandaEsperienza: String, CaseIterable, Identifiable {
    case conosce, haAvuto, haCapito
    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .conosce: return "Conosce"
        case .haAvuto: return "Ha avuto"
        case .haCapito: return "Ha capito"
        }
    }

    /// La domanda come si fa al cliente (aiuto della casella).
    var domanda: String {
        switch self {
        case .conosce: return "Sa che cos'è e come funziona in generale?"
        case .haAvuto: return "Ne ha avuto uno, oggi o in passato (anche con altri intermediari)?"
        case .haCapito: return "Ha capito rischi, costi e vincoli di questo tipo di prodotto?"
        }
    }
}

/// Le risposte del cliente per un tipo di prodotto. nil = non indicato.
struct VoceEsperienza: Codable, Hashable {
    var tipo: TipoProdotto
    var conosce: Bool?
    var haAvuto: Bool?
    var haCapito: Bool?

    init(tipo: TipoProdotto, conosce: Bool? = nil, haAvuto: Bool? = nil, haCapito: Bool? = nil) {
        self.tipo = tipo
        self.conosce = conosce
        self.haAvuto = haAvuto
        self.haCapito = haCapito
    }

    var vuota: Bool { conosce == nil && haAvuto == nil && haCapito == nil }

    subscript(domanda: DomandaEsperienza) -> Bool? {
        get {
            switch domanda {
            case .conosce: return conosce
            case .haAvuto: return haAvuto
            case .haCapito: return haCapito
            }
        }
        set {
            switch domanda {
            case .conosce: conosce = newValue
            case .haAvuto: haAvuto = newValue
            case .haCapito: haCapito = newValue
            }
        }
    }
}

/// Quanto il cliente può perdere del capitale investito in un prodotto senza compromettere i suoi
/// impegni e il suo tenore di vita: la «capacità di sostenere perdite» delle regole di adeguatezza
/// (Reg. delegato UE 2017/565 art. 54, par. 2, lett. b; Reg. delegato UE 2017/2359 art. 9).
/// È diversa dalla propensione al rischio: si può accettare il rischio senza poterselo permettere.
/// Le fasce sono di Prisma, non della norma.
enum CapacitaPerdite: String, Codable, CaseIterable, Identifiable {
    case nessuna, limitata, media, elevata
    var id: String { rawValue }

    var nome: String {
        switch self {
        case .nessuna: return "Nessuna"
        case .limitata: return "Limitata"
        case .media: return "Media"
        case .elevata: return "Elevata"
        }
    }

    /// Testo breve del controllo a segmenti.
    var etichetta: String {
        switch self {
        case .nessuna: return "Nessuna"
        case .limitata: return "Fino al 10%"
        case .media: return "Fino al 25%"
        case .elevata: return "Oltre il 25%"
        }
    }

    /// Perdita massima sostenibile in % del capitale investito nel prodotto; nil = nessun limite.
    var limite: Double? {
        switch self {
        case .nessuna: return 0
        case .limitata: return 10
        case .media: return 25
        case .elevata: return nil
        }
    }

    /// Dopo «il cliente …», nelle incoerenze e sotto i segmenti.
    var frase: String {
        switch self {
        case .nessuna: return "non può perdere nulla del capitale investito"
        case .limitata: return "può sostenere perdite fino al 10% del capitale investito"
        case .media: return "può sostenere perdite fino al 25% del capitale investito"
        case .elevata: return "può sostenere anche perdite ampie, oltre il 25% del capitale investito"
        }
    }
}

/// Esperienza del cliente per tipo di prodotto e capacità di sostenere perdite (dalla versione 21 dell'archivio).
struct EsperienzaProdotti: Codable, Hashable {
    /// Una voce per tipo al massimo, nell'ordine di `TipoProdotto.allCases`. Le voci vuote non si salvano.
    var voci: [VoceEsperienza] = []
    var capacitaPerdite: CapacitaPerdite?
    var aggiornataIl: Date?

    init() {}

    func voce(_ t: TipoProdotto) -> VoceEsperienza {
        voci.first { $0.tipo == t } ?? VoceEsperienza(tipo: t)
    }

    /// Sostituisce la voce del tipo. Le voci vuote si tolgono e l'ordine resta quello dei tipi.
    mutating func imposta(_ v: VoceEsperienza) {
        voci.removeAll { $0.tipo == v.tipo }
        if !v.vuota { voci.append(v) }
        voci.sort { a, b in
            (TipoProdotto.allCases.firstIndex(of: a.tipo) ?? 0) < (TipoProdotto.allCases.firstIndex(of: b.tipo) ?? 0)
        }
    }

    /// Almeno un tipo indicato o la capacità di sostenere perdite.
    var compilata: Bool { voci.contains { !$0.vuota } || capacitaPerdite != nil }

    /// Quanti tipi hanno almeno una risposta.
    var tipiIndicati: Int { Set(voci.filter { !$0.vuota }.map(\.tipo)).count }

    private enum CodingKeys: String, CodingKey { case voci, capacitaPerdite, aggiornataIl }

    /// Lettura tollerante, che non lancia mai:
    /// - una voce illeggibile (un tipo di una versione futura, un valore non booleano) si scarta, le altre restano;
    /// - se lo stesso tipo compare due volte, vale l'ultima voce;
    /// - un valore che non è un oggetto dà una griglia vuota.
    /// Così `ProfiloInvestitore` (Codable sintetizzato) e quindi `Cliente` non si perdono mai per questo campo.
    init(from decoder: Decoder) throws {
        self.init()
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        let lette = (try? c.decodeIfPresent(ElencoTollerante<VoceEsperienza>.self, forKey: .voci))?.elementi ?? []
        for v in lette { imposta(v) }
        capacitaPerdite = try? c.decodeIfPresent(CapacitaPerdite.self, forKey: .capacitaPerdite)
        aggiornataIl = try? c.decodeIfPresent(Date.self, forKey: .aggiornataIl)
    }
}
