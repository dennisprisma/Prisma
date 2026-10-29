import Foundation

/// Che cosa misura una serie di riferimento (dalla versione 24 dell'archivio).
enum TipoSerieRiferimento: String, Codable {
    /// Inflazione: variazione di dicembre su dicembre dell'indice FOI senza tabacchi (ISTAT).
    case inflazione
    /// Rivalutazione netta del TFR: calcolata dall'inflazione (art. 2120 c.c.), non si inserisce.
    case tfr
    /// Rendimento medio annuo delle gestioni separate.
    case gestioniSeparate
    /// Un indice scelto dal consulente (rendimento totale annuo, %).
    case indice
}

/// Una serie di valori annui in percentuale con cui confrontare i rendimenti. Non si salva: la costruisce
/// `TabellaRiferimenti` dalle serie di Prisma e dagli indici del consulente.
struct SerieRiferimento: Identifiable, Hashable {
    static let idInflazione = "inflazione-foi"
    static let idTFR = "tfr-netto"
    static let idGestioniSeparate = "gestioni-separate"

    let id: String
    let tipo: TipoSerieRiferimento
    /// «Inflazione (FOI)», «Rivalutazione del TFR», «Gestioni separate», nome dell'indice.
    let nome: String
    /// Nelle frasi e nelle pillole: «l'inflazione», «il TFR», «le gestioni separate», nome dell'indice.
    let nomeFrase: String
    let fonte: String
    /// true per il TFR: i valori si ricavano dall'inflazione e non si scrivono.
    var calcolata: Bool { tipo == .tfr }
}

/// La famiglia di una posizione, che decide il metro predefinito.
enum FamigliaRiferimento: String, CaseIterable, Identifiable {
    case previdenza, gestioneSeparata, mercato
    var id: String { rawValue }

    var nome: String {
        switch self {
        case .previdenza: return "Previdenza complementare"
        case .gestioneSeparata: return "Polizze rivalutabili di Ramo I"
        case .mercato: return "Fondi, ETF, titoli, multiramo e altre"
        }
    }

    /// Il metro di Prisma per la famiglia.
    var seriePredefinita: String {
        switch self {
        case .previdenza: return SerieRiferimento.idTFR
        case .gestioneSeparata: return SerieRiferimento.idGestioniSeparate
        case .mercato: return SerieRiferimento.idInflazione
        }
    }

    /// Regime previdenza → previdenza; Ramo I (non multiramo) → gestione separata; il resto → mercato.
    static func di(_ p: Posizione) -> FamigliaRiferimento {
        if p.regime == .previdenza { return .previdenza }
        if p.gestioneSeparata { return .gestioneSeparata }
        return .mercato
    }
}

/// Un valore annuo inserito o corretto dal consulente: prevale su quello di Prisma della stessa serie e anno.
struct ValoreRiferimento: Codable, Hashable {
    var serie: String
    var anno: Int
    /// Percentuale dell'anno (per esempio 1,5 = +1,5%).
    var valore: Double

    /// Un valore da tenere: serie indicata, cifra finita, anno plausibile.
    var leggibile: Bool { !serie.isEmpty && valore.isFinite && anno >= 1900 && anno <= 2200 }
}

extension ValoreRiferimento {
    private enum ChiaviLettura: String, CodingKey { case serie, anno, valore }

    /// Lettura tollerante (come `Movimento`): con dati illeggibili `serie` resta vuota e il valore si scarta dopo.
    /// Sta in un'estensione per conservare l'init per membri.
    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: ChiaviLettura.self) else {
            self.init(serie: "", anno: 0, valore: 0)
            return
        }
        let serie = (try? c.decode(String.self, forKey: .serie)) ?? ""
        let anno = try? c.decode(Int.self, forKey: .anno)
        let valore = try? c.decode(Double.self, forKey: .valore)
        if let anno, let valore {
            self.init(serie: serie, anno: anno, valore: valore)
        } else {
            self.init(serie: "", anno: 0, valore: 0)
        }
    }
}

/// Un indice aggiunto dal consulente (Impostazioni › Riferimenti).
struct IndiceRiferimento: Codable, Hashable, Identifiable {
    var id = "indice-\(UUID().uuidString.prefix(8).lowercased())"
    var nome: String
    /// Da dove vengono i valori (scritto dal consulente).
    var fonte = ""
}

extension IndiceRiferimento {
    private enum ChiaviLettura: String, CodingKey { case id, nome, fonte }

    /// Lettura tollerante: un indice illeggibile ha `id` vuoto e si scarta dopo la lettura.
    /// Sta in un'estensione per conservare l'init per membri.
    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: ChiaviLettura.self) else {
            self.init(id: "", nome: "", fonte: "")
            return
        }
        self.init(id: (try? c.decode(String.self, forKey: .id)) ?? "",
                  nome: (try? c.decode(String.self, forKey: .nome)) ?? "",
                  fonte: (try? c.decode(String.self, forKey: .fonte)) ?? "")
    }
}

/// I metri di confronto dei rendimenti, nelle impostazioni (dalla versione 24 dell'archivio).
/// Prisma porta le sue serie nel codice (`RiferimentiStorici`); qui stanno solo i valori del consulente,
/// i suoi indici e le sue scelte. Lettura tollerante: un valore illeggibile si scarta, non l'archivio.
struct RiferimentiRendimento: Codable, Equatable {
    var valori: [ValoreRiferimento] = []
    var indici: [IndiceRiferimento] = []
    /// Il metro di ogni famiglia di posizioni (nil = quello di Prisma, `FamigliaRiferimento.seriePredefinita`).
    var perPrevidenza: String?
    var perGestioneSeparata: String?
    var perMercato: String?
    /// Quando il consulente ha rivisto i valori l'ultima volta (pulsante «Segna come rivisti oggi»).
    var rivistiIl: Date?

    /// Gli indici che l'interfaccia mostra e lascia aggiungere. Quelli in più si conservano (non si perde nulla).
    static let massimoIndici = 3

    init() {}

    private enum CodingKeys: String, CodingKey {
        case valori, indici, perPrevidenza, perGestioneSeparata, perMercato, rivistiIl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Un valore o un indice illeggibile si scarta, gli altri restano
        valori = ((try? c.decodeIfPresent(ElencoTollerante<ValoreRiferimento>.self, forKey: .valori))?.elementi ?? [])
            .filter(\.leggibile)
        indici = ((try? c.decodeIfPresent(ElencoTollerante<IndiceRiferimento>.self, forKey: .indici))?.elementi ?? [])
            .filter { !$0.id.isEmpty }
        perPrevidenza = try? c.decodeIfPresent(String.self, forKey: .perPrevidenza)
        perGestioneSeparata = try? c.decodeIfPresent(String.self, forKey: .perGestioneSeparata)
        perMercato = try? c.decodeIfPresent(String.self, forKey: .perMercato)
        rivistiIl = try? c.decodeIfPresent(Date.self, forKey: .rivistiIl)
    }

    /// Il metro scelto dal consulente per una famiglia (nil = quello di Prisma).
    func scelta(per f: FamigliaRiferimento) -> String? {
        switch f {
        case .previdenza: return perPrevidenza
        case .gestioneSeparata: return perGestioneSeparata
        case .mercato: return perMercato
        }
    }
}

/// Le serie che Prisma porta con sé. Solo valori pubblici certi, con una cifra decimale come nei comunicati;
/// gli anni che mancano li inserisce il consulente (Impostazioni › Riferimenti). Non aggiungere valori incerti.
enum RiferimentiStorici {
    static let fonteInflazione = "ISTAT, indice dei prezzi al consumo per le famiglie di operai e impiegati (FOI) senza tabacchi: variazione di dicembre su dicembre dell'anno prima (comunicati mensili «Prezzi al consumo»). È l'indice che l'art. 2120 del Codice civile usa per rivalutare il TFR."
    static let fonteTFR = "Calcolata da Prisma: 1,5% più il 75% dell'inflazione FOI di dicembre su dicembre (art. 2120 c.c.; con inflazione negativa resta l'1,5%), meno l'imposta sostitutiva del 17% (art. 11, c. 3, D.Lgs. 47/2000, aliquota del 17% dalla L. 190/2014). È la rivalutazione netta che la COVIP confronta ogni anno con i rendimenti dei fondi pensione."
    static let fonteGestioniSeparate = "Da inserire: rendimento medio annuo delle gestioni separate (per esempio le statistiche annuali di ANIA o IVASS, o la media delle gestioni che segui). Per confrontarlo con il valore di una polizza usa il rendimento riconosciuto agli assicurati, al netto del trattenuto."

    /// FOI senza tabacchi, dicembre su dicembre (%). Fino al 2020 e dal 2024 li inserisce il consulente.
    static let inflazione: [Int: Double] = [2021: 3.8, 2022: 11.3, 2023: 0.6]
    /// Rendimento medio delle gestioni separate (%): nessun valore precompilato.
    static let gestioniSeparate: [Int: Double] = [:]

    /// Il primo anno che la scheda Impostazioni › Riferimenti mostra (fino all'anno in corso).
    static let annoMinimo = 2010
}
