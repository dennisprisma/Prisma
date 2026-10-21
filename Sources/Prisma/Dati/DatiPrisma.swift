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
    var clienteAttivoId: String
    var impostazioni: Impostazioni

    /// 2: anagrafica completa, nucleo familiare, profilo e consensi dei clienti.
    /// 3: posizioni in essere e in proposta.
    /// 4: tipo, canale e posizione degli appuntamenti; note e appuntamento collegato delle attività.
    /// 5: scenari del simulatore e Analisi 360 dei clienti.
    static let versioneAttuale = 5

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
        case versione, clienti, appuntamenti, attivita, posizioni, simulazioni, analisi, clienteAttivoId, impostazioni
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
        clienteAttivoId = try c.decodeIfPresent(String.self, forKey: .clienteAttivoId) ?? (clienti.first?.id ?? "")
        impostazioni = try c.decodeIfPresent(Impostazioni.self, forKey: .impostazioni) ?? Impostazioni()
    }
}

struct Impostazioni: Codable, Equatable {
    var nomeUtente = "Dennis"
    var inizialiUtente = "DV"
    var backup = ImpostazioniBackup()
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
