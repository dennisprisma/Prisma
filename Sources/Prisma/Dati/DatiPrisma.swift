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
    /// Fotografie delle cifre chiave salvate a ogni riesame, di tutti i clienti (dalla versione 24).
    var fotografie: [FotografiaRiesame] = []
    /// Schede di adeguatezza delle proposte (dalla versione 22 dell'archivio).
    var schedeAdeguatezza: [SchedaAdeguatezza] = []
    /// Ipotesi del confronto «TFR in azienda o nel fondo», per cliente (dalla versione 24).
    var confrontiTFR: [String: IpotesiTFR] = [:]
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
    /// 20: multiramo a due parti (rendimento, costi e rischio della gestione separata e dei fondi, ribilanciamento) nelle posizioni e nelle schede prodotto; dati di rischio delle parti nelle condizioni.
    /// 21: seguito delle proposte (esito «rimandata», giorni del seguito); dati non pertinenti per la completezza; orari di lavoro dell'agenda; esperienza per tipo di prodotto e capacità di sostenere perdite.
    /// 22: schede di adeguatezza delle proposte e documenti da consegnare per canale; scadenze di conformità dei clienti e regole di validità; impostazioni del calendario delle occasioni e promemoria delle occasioni.
    /// 23: categoria dei documenti e dati letti nuovi (ISIN, data del documento, rendimento prima dei costi, documenti
    ///     d'identità e questionari); confronto dei documenti con il dossier: voci lasciate come in Prisma e storico dei
    ///     dati aggiornati nelle posizioni e nelle schede prodotto.
    /// 24: metri di confronto dei rendimenti (valori annui, indici e scelte nelle impostazioni; metro scelto nella posizione) e confronto «TFR in azienda o nel fondo» per cliente; fotografie dei riesami (cifre chiave datate per cliente).
    static let versioneAttuale = 24

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
        case schedeAdeguatezza
        case confrontiTFR, fotografie
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
        // Fotografie dei riesami (dalla versione 24): una fotografia illeggibile si scarta, le altre restano
        fotografie = (try? c.decodeIfPresent(ElencoTollerante<FotografiaRiesame>.self, forKey: .fotografie))?.elementi ?? []
        // Schede di adeguatezza (dalla versione 22): una scheda illeggibile si scarta, le altre restano
        schedeAdeguatezza = (try? c.decodeIfPresent(ElencoTollerante<SchedaAdeguatezza>.self, forKey: .schedeAdeguatezza))?.elementi ?? []
        // Confronti del TFR (dalla versione 24): gli archivi di prima non li hanno
        confrontiTFR = (try? c.decodeIfPresent([String: IpotesiTFR].self, forKey: .confrontiTFR)) ?? [:]
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
    /// L'introduzione «Come funziona Prisma» è stata vista (dopo il primo sblocco parte da sola finché non lo è).
    var introduzioneVista = false
    /// Dimensione dei testi dell'interfaccia (si applica all'avvio).
    var dimensioneTesto = DimensioneTesto.normale
    /// Aspetto dell'interfaccia: segue il Mac, sempre chiaro o sempre scuro (i PDF restano chiari).
    var aspetto = AspettoInterfaccia.automatico
    /// Lo sfondo d'acqua della scrivania si muove (no = «Sfondo fermo»).
    var sfondoAnimato = true
    /// Quanta pioggia cade sull'acqua della scrivania.
    var pioggia = IntensitaPioggia.leggera
    /// Promemoria nel Centro notifiche del Mac (spenti finché non li accendi).
    var promemoria = ImpostazioniPromemoria()
    /// Le ricerche salvate dal pannello ⌘K (le più recenti prima).
    var ricercheSalvate: [RicercaSalvata] = []
    /// Dopo quanti giorni una proposta presentata, senza appuntamento in agenda, torna tra le cose da recuperare
    /// (dalla versione 21; si sceglie tra `Impostazioni.sceltaGiorniSeguito`).
    var giorniSeguitoProposte = Impostazioni.giorniSeguitoPredefiniti
    /// Orari di lavoro dell'agenda: dove «Pianifica» cerca lo spazio libero (dalla versione 21).
    var orari = OrariLavoro()
    /// Documenti da consegnare prima della firma, per canale (Impostazioni › Proposte). Dalla versione 22.
    var consegna = ImpostazioniConsegna()
    /// Validità delle scadenze di conformità (Impostazioni › Esperienza). Dalla versione 22.
    var conformita = RegoleConformita()
    /// Il calendario delle occasioni (dalla versione 22 dell'archivio).
    var occasioni = ImpostazioniOccasioni()
    /// I metri di confronto dei rendimenti: valori annui e indici del consulente, metro di ogni tipo di posizione
    /// (Impostazioni › Riferimenti). Dalla versione 24.
    var riferimenti = RiferimentiRendimento()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case nomeUtente, inizialiUtente, backup, eve, pdf, guidaNascosta, introduzioneVista, dimensioneTesto, aspetto, sfondoAnimato, pioggia
        case promemoria, ricercheSalvate, giorniSeguitoProposte, orari
        case consegna, conformita, occasioni
        case riferimenti
    }

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
        // L'introduzione: gli archivi di prima non la hanno (Denis la vede una volta, poi dal menu Aiuto)
        introduzioneVista = (try? c.decodeIfPresent(Bool.self, forKey: .introduzioneVista)) ?? false
        dimensioneTesto = (try? c.decodeIfPresent(DimensioneTesto.self, forKey: .dimensioneTesto)) ?? .normale
        // Impostazioni del tema: gli archivi di prima non le hanno
        aspetto = (try? c.decodeIfPresent(AspettoInterfaccia.self, forKey: .aspetto)) ?? .automatico
        sfondoAnimato = (try? c.decodeIfPresent(Bool.self, forKey: .sfondoAnimato)) ?? true
        pioggia = (try? c.decodeIfPresent(IntensitaPioggia.self, forKey: .pioggia)) ?? .leggera
        // Promemoria del Mac: gli archivi di prima non li hanno
        promemoria = (try? c.decodeIfPresent(ImpostazioniPromemoria.self, forKey: .promemoria)) ?? ImpostazioniPromemoria()
        // Ricerche salvate: gli archivi di prima non le hanno
        ricercheSalvate = (try? c.decodeIfPresent([RicercaSalvata].self, forKey: .ricercheSalvate)) ?? []
        // Giorni del seguito delle proposte: gli archivi di prima non li hanno, un valore fuori scelta torna al predefinito
        let giorni = (try? c.decodeIfPresent(Int.self, forKey: .giorniSeguitoProposte)) ?? Impostazioni.giorniSeguitoPredefiniti
        giorniSeguitoProposte = Impostazioni.sceltaGiorniSeguito.contains(giorni) ? giorni : Impostazioni.giorniSeguitoPredefiniti
        // Orari di lavoro: gli archivi di prima non li hanno
        orari = (try? c.decodeIfPresent(OrariLavoro.self, forKey: .orari)) ?? OrariLavoro()
        // Giro 4 (versione 22): gli archivi di prima non hanno documenti da consegnare, regole di conformità e occasioni
        consegna = (try? c.decodeIfPresent(ImpostazioniConsegna.self, forKey: .consegna)) ?? ImpostazioniConsegna()
        conformita = (try? c.decodeIfPresent(RegoleConformita.self, forKey: .conformita)) ?? RegoleConformita()
        occasioni = (try? c.decodeIfPresent(ImpostazioniOccasioni.self, forKey: .occasioni)) ?? ImpostazioniOccasioni()
        // Giro 6 (versione 24): gli archivi di prima non hanno i metri di confronto dei rendimenti
        riferimenti = (try? c.decodeIfPresent(RiferimentiRendimento.self, forKey: .riferimenti)) ?? RiferimentiRendimento()
    }
}

/// Aspetto dell'interfaccia (Impostazioni → Aspetto).
enum AspettoInterfaccia: String, Codable, CaseIterable, Identifiable {
    case automatico, chiaro, scuro

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .automatico: return "Automatico"
        case .chiaro: return "Chiaro"
        case .scuro: return "Scuro"
        }
    }
}

/// Quanta pioggia cade sull'acqua della scrivania.
enum IntensitaPioggia: String, Codable, CaseIterable, Identifiable {
    case leggera, media, forte

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .leggera: return "Leggera"
        case .media: return "Media"
        case .forte: return "Forte"
        }
    }

    /// Forza della pioggia per lo sfondo animato (come FORZE nel prototipo approvato).
    var forza: Double {
        switch self {
        case .leggera: return 0.14
        case .media: return 0.3
        case .forte: return 0.55
        }
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

/// Promemoria nel Centro notifiche del Mac: appuntamenti, attività, scadenze delle posizioni e compleanni.
/// Spenti di partenza: il permesso di macOS si chiede solo quando li accendi. Letti con tolleranza
/// (gli archivi di prima non li hanno); il permesso di macOS non sta nell'archivio.
struct ImpostazioniPromemoria: Codable, Equatable {
    var attivi = false
    var appuntamenti = true
    var attivita = true
    var scadenze = true
    var compleanni = true
    /// Le occasioni dei clienti (riscatto, penali, età…) nel Centro notifiche del Mac (dalla versione 22).
    var occasioni = true
    /// Quanti minuti prima dell'inizio arriva il promemoria di un appuntamento.
    var anticipoMinuti = 30
    /// Il nome del cliente nel promemoria (spento: solo l'ora e cosa fare).
    var nomiClienti = true

    /// Gli anticipi che si possono scegliere.
    static let anticipi = [15, 30, 60]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case attivi, appuntamenti, attivita, scadenze, compleanni, anticipoMinuti, nomiClienti
        case occasioni
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attivi = (try? c.decodeIfPresent(Bool.self, forKey: .attivi)) ?? false
        appuntamenti = (try? c.decodeIfPresent(Bool.self, forKey: .appuntamenti)) ?? true
        attivita = (try? c.decodeIfPresent(Bool.self, forKey: .attivita)) ?? true
        scadenze = (try? c.decodeIfPresent(Bool.self, forKey: .scadenze)) ?? true
        compleanni = (try? c.decodeIfPresent(Bool.self, forKey: .compleanni)) ?? true
        let anticipo = (try? c.decodeIfPresent(Int.self, forKey: .anticipoMinuti)) ?? 30
        anticipoMinuti = ImpostazioniPromemoria.anticipi.contains(anticipo) ? anticipo : 30
        nomiClienti = (try? c.decodeIfPresent(Bool.self, forKey: .nomiClienti)) ?? true
        occasioni = (try? c.decodeIfPresent(Bool.self, forKey: .occasioni)) ?? true
    }

    /// «15 minuti», «30 minuti», «1 ora».
    static func nomeAnticipo(_ minuti: Int) -> String {
        if minuti >= 60, minuti % 60 == 0 {
            let ore = minuti / 60
            return ore == 1 ? "1 ora" : "\(ore) ore"
        }
        return "\(minuti) minuti"
    }
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
    /// I backup si proteggono con una password (che sta nel Portachiavi del Mac, mai qui).
    /// Opzionale: gli archivi di prima non hanno il campo e si leggono lo stesso.
    var protetto: Bool?

    /// true se i nuovi backup vanno protetti con la password.
    var cifrato: Bool { protetto == true }
    static let lunghezzaMinimaPassword = 8

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
