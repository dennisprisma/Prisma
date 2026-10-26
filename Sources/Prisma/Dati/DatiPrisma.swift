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
    /// Note del taccuino, legate ai clienti.
    var note: [Nota] = []
    /// Spazi di lavoro salvati dal consulente (quelli pronti di Prisma non si salvano).
    var spazi: [SpazioLavoro] = []
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
    /// 16: quota in gestione separata delle polizze multiramo; impostazioni di backup con l'ultimo errore.
    /// 17: spazi di lavoro salvati.
    /// 18: note del taccuino.
    /// 19: data del valore e totale versato tra i dati letti dai documenti (estratti conto).
    static let versioneAttuale = 19

    init(clienti: [Cliente], appuntamenti: [Appuntamento], attivita: [Attivita], posizioni: [Posizione],
         simulazioni: [Simulazione] = [], analisi: [String: Analisi360] = [:], incontri: [Incontro] = [],
         prodotti: [Prodotto] = [], obiettivi: [Obiettivo] = [], documenti: [Documento] = [],
         valutazioni: [ValutazioneInvestimento] = [], note: [Nota] = [], clienteAttivoId: String, impostazioni: Impostazioni) {
        self.note = note
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
            note: DatiDemo.note(),
            clienteAttivoId: "giulia",
            impostazioni: Impostazioni()
        )
    }

    private enum CodingKeys: String, CodingKey {
        case versione, clienti, appuntamenti, attivita, posizioni, simulazioni, analisi, incontri, prodotti, obiettivi, documenti, valutazioni, conversazioni, commenti, note, spazi, clienteAttivoId, impostazioni
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
        spazi = (try? c.decodeIfPresent([SpazioLavoro].self, forKey: .spazi)) ?? []
        note = (try? c.decodeIfPresent([Nota].self, forKey: .note)) ?? []
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
    /// PDF da consegnare ai clienti (letto con tolleranza: gli archivi di prima non l'hanno).
    var pdf = ImpostazioniPDF()
    /// La guida «Comincia con i tuoi dati» nascosta dalla scrivania.
    var guidaNascosta = false
    /// Dimensione dei testi dell'interfaccia (si applica all'avvio).
    var dimensioneTesto = DimensioneTesto.normale

    init() {}

    private enum CodingKeys: String, CodingKey { case nomeUtente, inizialiUtente, backup, eve, pdf, guidaNascosta, dimensioneTesto }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nomeUtente = try c.decodeIfPresent(String.self, forKey: .nomeUtente) ?? "Denis"
        // Correzione del nome predefinito delle prime versioni ("Dennis")
        if nomeUtente == "Dennis" { nomeUtente = "Denis" }
        inizialiUtente = try c.decodeIfPresent(String.self, forKey: .inizialiUtente) ?? "DV"
        backup = try c.decodeIfPresent(ImpostazioniBackup.self, forKey: .backup) ?? ImpostazioniBackup()
        eve = (try? c.decodeIfPresent(ImpostazioniEve.self, forKey: .eve)) ?? ImpostazioniEve()
        pdf = (try? c.decodeIfPresent(ImpostazioniPDF.self, forKey: .pdf)) ?? ImpostazioniPDF()
        guidaNascosta = (try? c.decodeIfPresent(Bool.self, forKey: .guidaNascosta)) ?? false
        dimensioneTesto = (try? c.decodeIfPresent(DimensioneTesto.self, forKey: .dimensioneTesto)) ?? .normale
    }
}

/// Quanto si ingrandiscono i testi dell'interfaccia.
enum DimensioneTesto: String, Codable, CaseIterable, Identifiable {
    case normale, grande, moltoGrande

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .normale: return "Normale"
        case .grande: return "Grande"
        case .moltoGrande: return "Molto grande"
        }
    }

    var fattore: CGFloat {
        switch self {
        case .normale: return 1
        case .grande: return 1.1
        case .moltoGrande: return 1.2
        }
    }
}

/// I PDF salvati per i clienti: protezione con password proposta e come si forma la password.
/// Prisma non conserva nessuna password: la ricava dai dati del cliente o la scrivi ogni volta.
struct ImpostazioniPDF: Codable, Equatable {
    enum Regola: String, Codable, CaseIterable, Identifiable {
        case dataNascita, codiceFiscale, aMano

        var id: String { rawValue }

        var nome: String {
            switch self {
            case .dataNascita: return "Data di nascita (ggmmaaaa)"
            case .codiceFiscale: return "Codice fiscale"
            case .aMano: return "La scrivo ogni volta"
            }
        }
    }

    var proteggi = false
    var regola = Regola.dataNascita

    init() {}

    private enum CodingKeys: String, CodingKey { case proteggi, regola }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        proteggi = (try? c.decodeIfPresent(Bool.self, forKey: .proteggi)) ?? false
        regola = (try? c.decodeIfPresent(Regola.self, forKey: .regola)) ?? .dataNascita
    }

    /// La password proposta per un cliente ("" se il dato manca o si scrive a mano).
    func password(per cliente: Cliente?) -> String {
        guard let cliente else { return "" }
        switch regola {
        case .dataNascita: return cliente.dataNascita.map { Formati.formato("ddMMyyyy").string(from: $0) } ?? ""
        case .codiceFiscale: return cliente.codiceFiscale.uppercased().filter { $0.isLetter || $0.isNumber }
        case .aMano: return ""
        }
    }

    static let lunghezzaMinima = 6
}

/// Impostazioni di Eve (comprese nel backup).
struct ImpostazioniEve: Codable, Equatable {
    /// Quando Eve risponde anche a voce.
    enum RisposteAVoce: String, Codable, CaseIterable, Identifiable {
        /// Solo quando le parli tu.
        case quandoParli
        case sempre
        case mai

        var id: String { rawValue }

        var nome: String {
            switch self {
            case .quandoParli: return "Quando le parli"
            case .sempre: return "Sempre"
            case .mai: return "Mai"
            }
        }
    }

    /// Le conversazioni restano nel dossier del cliente (sul Mac, nel backup).
    var conservaConversazioni = true
    /// La voce di sistema scelta (identificatore); nil = la migliore voce femminile italiana installata.
    var voce: String?
    /// Velocità della voce: 1 è quella naturale.
    var velocitaVoce = 1.0
    var risposteAVoce = RisposteAVoce.quandoParli
    /// A voce legge tutta la risposta, non solo l'inizio.
    var leggiTutto = false
    /// Dopo aver risposto a voce, Eve torna ad ascoltare finché non le dici «basta».
    var conversazioneContinua = true
    /// Quale riconoscimento vocale usare per ascoltarti (sempre sul Mac).
    var riconoscimento = SceltaRiconoscimento.automatico
    /// Modalità diagnostica: sotto il campo di Eve compare l'ultimo passaggio dell'ascolto.
    var mostraPassaggiVoce = false
    /// Il modello aperto sul Mac (Ollama): solo indirizzi locali, il nome del modello da usare.
    var indirizzoLocale = MotoreLocale.indirizzoPredefinito
    var modelloLocale = MotoreLocale.modelloPredefinito

    init() {}

    private enum CodingKeys: String, CodingKey {
        case conservaConversazioni, voce, velocitaVoce, risposteAVoce, leggiTutto, conversazioneContinua, indirizzoLocale, modelloLocale, riconoscimento, mostraPassaggiVoce
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conservaConversazioni = (try? c.decodeIfPresent(Bool.self, forKey: .conservaConversazioni)) ?? true
        voce = try? c.decodeIfPresent(String.self, forKey: .voce)
        velocitaVoce = min(1.4, max(0.7, (try? c.decodeIfPresent(Double.self, forKey: .velocitaVoce)) ?? 1))
        risposteAVoce = (try? c.decodeIfPresent(RisposteAVoce.self, forKey: .risposteAVoce)) ?? .quandoParli
        leggiTutto = (try? c.decodeIfPresent(Bool.self, forKey: .leggiTutto)) ?? false
        conversazioneContinua = (try? c.decodeIfPresent(Bool.self, forKey: .conversazioneContinua)) ?? true
        indirizzoLocale = (try? c.decodeIfPresent(String.self, forKey: .indirizzoLocale)) ?? MotoreLocale.indirizzoPredefinito
        modelloLocale = (try? c.decodeIfPresent(String.self, forKey: .modelloLocale)) ?? MotoreLocale.modelloPredefinito
        riconoscimento = (try? c.decodeIfPresent(SceltaRiconoscimento.self, forKey: .riconoscimento)) ?? .automatico
        mostraPassaggiVoce = (try? c.decodeIfPresent(Bool.self, forKey: .mostraPassaggiVoce)) ?? false
    }
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
