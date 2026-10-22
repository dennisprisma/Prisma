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
    var incontri: [Incontro] = []
    /// Catalogo delle schede prodotto (di tutti i clienti).
    var prodotti: [Prodotto] = []
    var obiettivi: [Obiettivo] = []
    var documenti: [Documento] = []
    /// Valutazioni d'investimento (prospetto e report di riscatto).
    var valutazioni: [ValutazioneInvestimento] = []
    /// Conversazioni con Eve, per cliente.
    var conversazioni: [String: [MessaggioEve]] = [:]
    /// Commenti del consulente nei report per i clienti.
    var commenti: [CommentoReport] = []
    var clienteAttivoId: String
    var impostazioni: Impostazioni

    /// 2: anagrafica completa, nucleo familiare, profilo e consensi dei clienti.
    /// 3: posizioni in essere e in proposta.
    /// 4: tipo, canale e posizione degli appuntamenti; note e appuntamento collegato delle attività.
    /// 5: scenari del simulatore e Analisi 360 dei clienti.
    /// 6: conversazioni e impostazioni di Eve.
    /// 7: profilo dei bisogni dei clienti (mappa, eventi di vita, bisogni rilevati confermati).
    /// 8: incontri (preparazione, ascolto, appunti, decisioni, prossimi passi).
    /// 9: schede prodotto e obiettivi dei clienti.
    /// 10: documenti dei clienti con i dati estratti.
    /// 11: condizioni dei contratti nelle schede prodotto e valutazioni d'investimento.
    /// 12: rilevazioni dei valori delle posizioni (storico per il resoconto).
    /// 13: trattenuto sul rendimento e dati fiscali delle posizioni (regime, titoli di Stato, bollo, previdenza).
    /// 14: reddito lordo annuo nel profilo del cliente (previdenza e deducibilità).
    /// 15: commenti del consulente nei report (scritti con Eve).
    static let versioneAttuale = 15

    init(clienti: [Cliente], appuntamenti: [Appuntamento], attivita: [Attivita], posizioni: [Posizione],
         simulazioni: [Simulazione] = [], analisi: [String: Analisi360] = [:], incontri: [Incontro] = [],
         prodotti: [Prodotto] = [], obiettivi: [Obiettivo] = [], documenti: [Documento] = [],
         valutazioni: [ValutazioneInvestimento] = [], clienteAttivoId: String, impostazioni: Impostazioni) {
        self.incontri = incontri
        self.prodotti = prodotti
        self.obiettivi = obiettivi
        self.documenti = documenti
        self.valutazioni = valutazioni
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
            incontri: DatiDemo.incontri(),
            prodotti: DatiDemo.prodotti() + [DatiDemo.orizzonteValore()],
            obiettivi: DatiDemo.obiettivi(),
            documenti: DatiDemo.documenti(),
            valutazioni: DatiDemo.valutazioni(),
            clienteAttivoId: "giulia",
            impostazioni: Impostazioni()
        )
    }

    private enum CodingKeys: String, CodingKey {
        case versione, clienti, appuntamenti, attivita, posizioni, simulazioni, analisi, incontri, prodotti, obiettivi, documenti, valutazioni, conversazioni, commenti, clienteAttivoId, impostazioni
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
        incontri = (try? c.decodeIfPresent([Incontro].self, forKey: .incontri)) ?? []
        prodotti = (try? c.decodeIfPresent([Prodotto].self, forKey: .prodotti)) ?? []
        obiettivi = (try? c.decodeIfPresent([Obiettivo].self, forKey: .obiettivi)) ?? []
        documenti = (try? c.decodeIfPresent([Documento].self, forKey: .documenti)) ?? []
        valutazioni = (try? c.decodeIfPresent([ValutazioneInvestimento].self, forKey: .valutazioni)) ?? []
        conversazioni = (try? c.decodeIfPresent([String: [MessaggioEve]].self, forKey: .conversazioni)) ?? [:]
        commenti = (try? c.decodeIfPresent([CommentoReport].self, forKey: .commenti)) ?? []
        clienteAttivoId = try c.decodeIfPresent(String.self, forKey: .clienteAttivoId) ?? (clienti.first?.id ?? "")
        impostazioni = try c.decodeIfPresent(Impostazioni.self, forKey: .impostazioni) ?? Impostazioni()
    }
}

struct Impostazioni: Codable, Equatable {
    var nomeUtente = "Denis"
    var inizialiUtente = "DV"
    var backup = ImpostazioniBackup()
    /// Dalla versione 6 dell'archivio.
    var eve = ImpostazioniEve()

    init() {}

    private enum CodingKeys: String, CodingKey { case nomeUtente, inizialiUtente, backup, eve }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nomeUtente = try c.decodeIfPresent(String.self, forKey: .nomeUtente) ?? "Denis"
        // Correzione del nome predefinito delle prime versioni ("Dennis")
        if nomeUtente == "Dennis" { nomeUtente = "Denis" }
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
    /// L'ultimo tentativo e l'errore dell'ultimo backup non riuscito (disco scollegato, cartella piena…).
    var ultimoTentativo: Date?
    var ultimoErrore: String?

    /// true se l'ultimo backup riuscito ha più di 8 giorni (o non c'è): va segnalato.
    var inRitardo: Bool {
        guard automatico else { return false }
        guard let ultimo else { return ultimoTentativo != nil }
        return Date().timeIntervalSince(ultimo) > 8 * 24 * 60 * 60
    }

    static let intervalloAutomatico: TimeInterval = 7 * 24 * 60 * 60

    var prossimo: Date? {
        guard automatico else { return nil }
        return ultimo.map { $0.addingTimeInterval(Self.intervalloAutomatico) } ?? Date()
    }
}
