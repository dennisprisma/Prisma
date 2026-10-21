import Foundation

/// Tutto ciò che Prisma salva nell'archivio locale (archivio.json).
struct DatiPrisma: Codable, Equatable {
    /// Versione del formato, per le migrazioni future.
    var versione = DatiPrisma.versioneAttuale
    var clienti: [Cliente]
    var appuntamenti: [Appuntamento]
    var attivita: [Attivita]
    var posizioni: [Posizione] = []
    var simulazioni: [Simulazione] = []
    /// Analisi 360 salvate, per cliente (chi non ce l'ha la vede ricavata dalle posizioni).
    var analisi: [String: Analisi360] = [:]
    /// Conversazioni con Eve, per cliente.
    var conversazioni: [String: [MessaggioEve]] = [:]
    var clienteAttivoId: String
    var impostazioni: Impostazioni

    /// 2: anagrafica completa, nucleo familiare, profilo e consensi dei clienti.
    /// 3: posizioni in essere e in proposta.
    /// 4: tipo, canale e posizione degli appuntamenti; note e appuntamento collegato delle attività.
    /// 5: scenari del simulatore e Analisi 360 dei clienti.
    /// 6: conversazioni e impostazioni di Eve.
    static let versioneAttuale = 6

    init(clienti: [Cliente], appuntamenti: [Appuntamento], attivita: [Attivita], posizioni: [Posizione],
         simulazioni: [Simulazione] = [], analisi: [String: Analisi360] = [:],
         clienteAttivoId: String, impostazioni: Impostazioni) {
        self.simulazioni = simulazioni
        self.analisi = analisi
        self.clienti = clienti
        self.appuntamenti = appuntamenti
        self.attivita = attivita
        self.posizioni = posizioni
        self.clienteAttivoId = clienteAttivoId
        self.impostazioni = impostazioni
    }

    static func demo() -> DatiPrisma {
        DatiPrisma(
            clienti: DatiDemo.clienti(),
            appuntamenti: DatiDemo.appuntamenti(),
            attivita: DatiDemo.attivita(),
            posizioni: DatiDemo.posizioni(),
            simulazioni: DatiDemo.simulazioni(),
            clienteAttivoId: "giulia",
            impostazioni: Impostazioni()
        )
    }

    private enum CodingKeys: String, CodingKey {
        case versione, clienti, appuntamenti, attivita, posizioni, simulazioni, analisi, conversazioni, clienteAttivoId, impostazioni
    }

    /// Lettura tollerante: gli archivi delle versioni precedenti non hanno tutte le sezioni.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        versione = try c.decodeIfPresent(Int.self, forKey: .versione) ?? 1
        clienti = try c.decode([Cliente].self, forKey: .clienti)
        appuntamenti = try c.decodeIfPresent([Appuntamento].self, forKey: .appuntamenti) ?? []
        attivita = try c.decodeIfPresent([Attivita].self, forKey: .attivita) ?? []
        posizioni = try c.decodeIfPresent([Posizione].self, forKey: .posizioni) ?? []
        simulazioni = try c.decodeIfPresent([Simulazione].self, forKey: .simulazioni) ?? []
        analisi = try c.decodeIfPresent([String: Analisi360].self, forKey: .analisi) ?? [:]
        conversazioni = (try? c.decodeIfPresent([String: [MessaggioEve]].self, forKey: .conversazioni)) ?? [:]
        clienteAttivoId = try c.decodeIfPresent(String.self, forKey: .clienteAttivoId) ?? (clienti.first?.id ?? "")
        impostazioni = try c.decodeIfPresent(Impostazioni.self, forKey: .impostazioni) ?? Impostazioni()
    }
}

struct Impostazioni: Codable, Equatable {
    var nomeUtente = "Dennis"
    var inizialiUtente = "DV"
    var backup = ImpostazioniBackup()
    /// Dalla versione 6 dell'archivio.
    var eve = ImpostazioniEve()

    init() {}

    private enum CodingKeys: String, CodingKey { case nomeUtente, inizialiUtente, backup, eve }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nomeUtente = try c.decodeIfPresent(String.self, forKey: .nomeUtente) ?? "Dennis"
        inizialiUtente = try c.decodeIfPresent(String.self, forKey: .inizialiUtente) ?? "DV"
        backup = try c.decodeIfPresent(ImpostazioniBackup.self, forKey: .backup) ?? ImpostazioniBackup()
        eve = (try? c.decodeIfPresent(ImpostazioniEve.self, forKey: .eve)) ?? ImpostazioniEve()
    }
}

/// Impostazioni di Eve (comprese nel backup).
struct ImpostazioniEve: Codable, Equatable {
    enum Motore: String, Codable, CaseIterable, Identifiable {
        /// Il modello Apple se disponibile, altrimenti la sintesi locale.
        case automatico
        case apple
        case sintesi

        var id: String { rawValue }

        var nome: String {
            switch self {
            case .automatico: return "Automatico"
            case .apple: return "Modello Apple"
            case .sintesi: return "Sintesi dai dati"
            }
        }
    }

    var motore = Motore.automatico
    /// Le conversazioni restano nel dossier del cliente (sul Mac, nel backup).
    var conservaConversazioni = true
}

struct ImpostazioniBackup: Codable, Equatable {
    /// Cartella scelta dall'utente (nil = cartella predefinita sul Mac).
    var cartella: String?
    var automatico = true
    var ultimo: Date?

    static let intervalloAutomatico: TimeInterval = 7 * 24 * 60 * 60

    var prossimo: Date? {
        guard automatico else { return nil }
        return ultimo.map { $0.addingTimeInterval(Self.intervalloAutomatico) } ?? Date()
    }
}
