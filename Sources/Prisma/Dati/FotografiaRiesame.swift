import Foundation

/// La fotografia datata delle cifre chiave di un cliente, salvata a ogni riesame (dalla versione 24 dell'archivio).
/// Contiene solo cifre e nomi già presenti nel dossier: nessun testo libero. Gli enum si salvano come stringhe,
/// così un valore di una versione futura si conserva e si mostra com'è.
struct FotografiaRiesame: Identifiable, Codable, Equatable {
    /// Che cosa ha fatto salvare la fotografia.
    enum Origine: String, CaseIterable {
        case prospetto, incontro, appuntamento, manuale
    }

    struct FamiliareFoto: Codable, Equatable {
        var id = ""
        var nome = ""
        /// `Familiare.Relazione.rawValue`.
        var relazione = ""
        var aCarico = false
    }

    struct SemaforoFoto: Codable, Equatable {
        /// `IndicatoreCheckUp.id` («riserva», «morte», «invalidita», «previdenza», «investimenti», «debiti», «obiettivi»).
        var id = ""
        var titolo = ""
        /// `Semaforo.rawValue`.
        var colore = ""
        /// La cifra che lo riassume («6 mesi su 12», «45% coperto»).
        var valore = ""
    }

    struct ObiettivoFoto: Codable, Equatable {
        var id = ""
        var titolo = ""
        var importo: Double = 0
        var scadenza: Date?
        /// Quota raggiunta, 0–1.
        var quota: Double = 0
    }

    struct VoceConformitaFoto: Codable, Equatable {
        /// `VoceConformita.Tipo.rawValue` (giro 4).
        var tipo = ""
        /// `TestiConformita.nome(tipo)`: «Questionario di adeguatezza».
        var titolo = ""
        var canale: Canale?
        /// «scaduta», «mancante», «entro30», «entro60», «inRegola» (le voci non richieste non si salvano).
        var stato = ""
    }

    var id = "foto-\(UUID().uuidString.prefix(8).lowercased())"
    var clienteId: String
    /// Il giorno della fotografia (inizio del giorno).
    var data: Date
    /// `Origine.rawValue`, senza doppioni, nell'ordine in cui sono arrivate.
    var origini: [String] = []
    /// Versione del contenuto della fotografia (questa specifica: 1).
    var schema = 1

    // Profilo
    var propensione: String?            // ProfiloInvestitore.Propensione.rawValue
    var orizzonteAnni: Int?
    var esperienza: String?             // ProfiloInvestitore.Esperienza.rawValue
    var profiloAggiornatoIl: Date?
    // Famiglia
    var statoCivile: String?            // StatoCivile.rawValue
    var famiglia: [FamiliareFoto] = []
    // Semafori del check-up, nell'ordine di MotoreCheckUp
    var semafori: [SemaforoFoto] = []
    // Pensione (€/mese, in euro di oggi)
    var redditoDesiderato: Double?
    var pensionePubblica: Double?
    var renditaPiani: Double?
    /// Divario ancora scoperto dai piani in essere: `EsitoPianoPrevidenziale.divarioResiduo`.
    var divarioPensione: Double?
    // Protezione
    var fabbisognoCasoMorte: Double?
    var capitaleCasoMorte: Double?
    var scopertoCasoMorte: Double?
    /// €/mese che mancherebbero in caso di invalidità o malattia lunga.
    var ammancoInvalidita: Double?
    // Obiettivi
    var obiettivi: [ObiettivoFoto] = []
    // Patrimonio in essere (debiti esclusi dal per canale, come RiepilogoPosizioni)
    var patrimonioAlleanza: Double = 0
    var patrimonioIndipendente: Double = 0
    var debiti: Double = 0
    var proposteAperte = 0
    // Completezza dei dati (giro 3)
    var completezza: Int?
    var livelloCompletezza: String?
    // Conformità (giro 4): nil = non rilevata
    var conformita: [VoceConformitaFoto]?

    init(clienteId: String, data: Date) {
        self.clienteId = clienteId
        self.data = data
    }

    private enum CodingKeys: String, CodingKey {
        case id, clienteId, data, origini, schema
        case propensione, orizzonteAnni, esperienza, profiloAggiornatoIl
        case statoCivile, famiglia
        case semafori
        case redditoDesiderato, pensionePubblica, renditaPiani, divarioPensione
        case fabbisognoCasoMorte, capitaleCasoMorte, scopertoCasoMorte, ammancoInvalidita
        case obiettivi
        case patrimonioAlleanza, patrimonioIndipendente, debiti, proposteAperte
        case completezza, livelloCompletezza
        case conformita
    }

    /// Lettura tollerante: senza `id`, `clienteId` o `data` la fotografia si scarta (`ElencoTollerante`);
    /// ogni altro campo illeggibile prende il suo predefinito. Le chiavi sconosciute si ignorano.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        clienteId = try c.decode(String.self, forKey: .clienteId)
        data = try c.decode(Date.self, forKey: .data)
        origini = (try? c.decodeIfPresent([String].self, forKey: .origini)) ?? []
        schema = (try? c.decodeIfPresent(Int.self, forKey: .schema)) ?? 1

        propensione = try? c.decodeIfPresent(String.self, forKey: .propensione)
        orizzonteAnni = try? c.decodeIfPresent(Int.self, forKey: .orizzonteAnni)
        esperienza = try? c.decodeIfPresent(String.self, forKey: .esperienza)
        profiloAggiornatoIl = try? c.decodeIfPresent(Date.self, forKey: .profiloAggiornatoIl)

        statoCivile = try? c.decodeIfPresent(String.self, forKey: .statoCivile)
        famiglia = (try? c.decodeIfPresent(ElencoTollerante<FamiliareFoto>.self, forKey: .famiglia))?.elementi ?? []
        semafori = (try? c.decodeIfPresent(ElencoTollerante<SemaforoFoto>.self, forKey: .semafori))?.elementi ?? []

        redditoDesiderato = try? c.decodeIfPresent(Double.self, forKey: .redditoDesiderato)
        pensionePubblica = try? c.decodeIfPresent(Double.self, forKey: .pensionePubblica)
        renditaPiani = try? c.decodeIfPresent(Double.self, forKey: .renditaPiani)
        divarioPensione = try? c.decodeIfPresent(Double.self, forKey: .divarioPensione)

        fabbisognoCasoMorte = try? c.decodeIfPresent(Double.self, forKey: .fabbisognoCasoMorte)
        capitaleCasoMorte = try? c.decodeIfPresent(Double.self, forKey: .capitaleCasoMorte)
        scopertoCasoMorte = try? c.decodeIfPresent(Double.self, forKey: .scopertoCasoMorte)
        ammancoInvalidita = try? c.decodeIfPresent(Double.self, forKey: .ammancoInvalidita)

        obiettivi = (try? c.decodeIfPresent(ElencoTollerante<ObiettivoFoto>.self, forKey: .obiettivi))?.elementi ?? []

        patrimonioAlleanza = (try? c.decodeIfPresent(Double.self, forKey: .patrimonioAlleanza)) ?? 0
        patrimonioIndipendente = (try? c.decodeIfPresent(Double.self, forKey: .patrimonioIndipendente)) ?? 0
        debiti = (try? c.decodeIfPresent(Double.self, forKey: .debiti)) ?? 0
        proposteAperte = (try? c.decodeIfPresent(Int.self, forKey: .proposteAperte)) ?? 0

        completezza = try? c.decodeIfPresent(Int.self, forKey: .completezza)
        livelloCompletezza = try? c.decodeIfPresent(String.self, forKey: .livelloCompletezza)

        // Assente → nil (non rilevata); presente e vuota → []
        conformita = (try? c.decodeIfPresent(ElencoTollerante<VoceConformitaFoto>.self, forKey: .conformita))?.elementi
    }

    /// Le origini riconosciute (quelle di una versione futura restano in `origini` ma qui non compaiono).
    var origineNote: [Origine] { origini.compactMap(Origine.init(rawValue:)) }
    func patrimonio(_ c: Canale) -> Double { c == .alleanza ? patrimonioAlleanza : patrimonioIndipendente }
    var patrimonioNetto: Double { patrimonioAlleanza + patrimonioIndipendente - debiti }
    var aCarico: Int { famiglia.filter(\.aCarico).count }
    func semaforo(_ id: String) -> SemaforoFoto? { semafori.first { $0.id == id } }
    /// Quanti semafori di un colore (`Semaforo.rawValue`).
    func conta(_ colore: Semaforo) -> Int { semafori.filter { $0.colore == colore.rawValue }.count }
    /// Voci di conformità da sistemare (tutto tranne «inRegola»).
    var conformitaDaSistemare: Int? { conformita.map { $0.filter { $0.stato != "inRegola" }.count } }
}

// Letture tolleranti dei tipi interni: nessun campo obbligatorio, ognuno con il suo predefinito.
// Stanno in estensioni per conservare gli init per membri (li usa il motore della memoria).

extension FotografiaRiesame.FamiliareFoto {
    private enum ChiaviLettura: String, CodingKey { case id, nome, relazione, aCarico }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ChiaviLettura.self)
        self.init(id: (try? c.decodeIfPresent(String.self, forKey: .id)) ?? "",
                  nome: (try? c.decodeIfPresent(String.self, forKey: .nome)) ?? "",
                  relazione: (try? c.decodeIfPresent(String.self, forKey: .relazione)) ?? "",
                  aCarico: (try? c.decodeIfPresent(Bool.self, forKey: .aCarico)) ?? false)
    }
}

extension FotografiaRiesame.SemaforoFoto {
    private enum ChiaviLettura: String, CodingKey { case id, titolo, colore, valore }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ChiaviLettura.self)
        self.init(id: (try? c.decodeIfPresent(String.self, forKey: .id)) ?? "",
                  titolo: (try? c.decodeIfPresent(String.self, forKey: .titolo)) ?? "",
                  colore: (try? c.decodeIfPresent(String.self, forKey: .colore)) ?? "",
                  valore: (try? c.decodeIfPresent(String.self, forKey: .valore)) ?? "")
    }
}

extension FotografiaRiesame.ObiettivoFoto {
    private enum ChiaviLettura: String, CodingKey { case id, titolo, importo, scadenza, quota }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ChiaviLettura.self)
        self.init(id: (try? c.decodeIfPresent(String.self, forKey: .id)) ?? "",
                  titolo: (try? c.decodeIfPresent(String.self, forKey: .titolo)) ?? "",
                  importo: (try? c.decodeIfPresent(Double.self, forKey: .importo)) ?? 0,
                  scadenza: try? c.decodeIfPresent(Date.self, forKey: .scadenza),
                  quota: (try? c.decodeIfPresent(Double.self, forKey: .quota)) ?? 0)
    }
}

extension FotografiaRiesame.VoceConformitaFoto {
    private enum ChiaviLettura: String, CodingKey { case tipo, titolo, canale, stato }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ChiaviLettura.self)
        self.init(tipo: (try? c.decodeIfPresent(String.self, forKey: .tipo)) ?? "",
                  titolo: (try? c.decodeIfPresent(String.self, forKey: .titolo)) ?? "",
                  canale: try? c.decodeIfPresent(Canale.self, forKey: .canale),
                  stato: (try? c.decodeIfPresent(String.self, forKey: .stato)) ?? "")
    }
}
