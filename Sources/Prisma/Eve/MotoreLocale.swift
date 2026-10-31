import Foundation

/// Il motore di Eve: il modello sul Mac, raggiunto con il fornitore scelto (Ollama o un server compatibile
/// OpenAI), sempre a un indirizzo del Mac stesso: nessun dato dei clienti esce dal computer.
/// Sul MacBook Pro M1 da 8 GB la taglia giusta è la 4B (circa 3,5 GB di memoria mentre lavora).
struct MotoreLocale: MotoreEve, MotoreGenerativo {
    static let indirizzoPredefinito = FornitoreOllama.indirizzoPredefinito
    /// Qwen 3.5 da 4 miliardi di parametri (ollama.com/library/qwen3.5).
    static let modelloPredefinito = "qwen3.5:4b"
    /// Il modello predefinito delle versioni di prima: chi non l'aveva cambiato passa al nuovo.
    static let modelloPrecedente = "qwen3:4b"
    /// Dopo l'ultima risposta il modello resta in memoria per un po', poi la RAM torna libera.
    static let restaInMemoria = "10m"
    /// Il ragionamento può tacere a lungo prima della prima parola.
    static let attesaMassima: TimeInterval = 180

    let fornitore: FornitoreModello
    let disponibilita: DisponibilitaEve
    let restaInMemoria: String

    init(_ eve: ImpostazioniEve, disponibilita: DisponibilitaEve, sessione: URLSession = .shared) {
        fornitore = FornitoriEve.crea(eve, sessione: sessione)
        self.disponibilita = disponibilita
        restaInMemoria = eve.restaInMemoria
    }

    var modello: String { fornitore.modello }

    /// «Qwen sul Mac», «Gemma sul Mac»…: il nome del modello, senza la taglia.
    var nome: String { Self.nome(modello) }

    static func nome(_ modello: String) -> String {
        let famiglia = modello.split(separator: ":").first.map(String.init) ?? modello
        let lettere = famiglia.prefix { $0.isLetter }
        return lettere.isEmpty ? "Modello sul Mac" : String(lettere.prefix(1)).uppercased() + String(lettere.dropFirst()) + " sul Mac"
    }

    #if os(iOS)
    var descrizione: String { "\(modello) sul Mac, in Wi‑Fi e cifrato: nessun dato esce dai tuoi dispositivi." }
    #else
    var descrizione: String { "\(modello) con \(fornitore.nome), sul Mac: nessun dato esce dal computer." }
    #endif

    // MARK: - Disponibilità

    /// Pronto se il fornitore risponde e ha il modello scelto.
    static func verifica(_ eve: ImpostazioniEve) async -> DisponibilitaEve {
        #if os(iOS)
        // Su iPhone e iPad: Qwen del Mac abbinato, in rete locale (PonteEve). Se il Mac non c'è, Eve lo dice e non risponde
        return await PonteEve.collega(eve)
        #else
        let f = FornitoriEve.crea(eve)
        guard IndirizzoLocale.url(f.indirizzo) != nil else {
            return .nonDisponibile("L'indirizzo di \(f.nome) deve essere sul Mac (127.0.0.1): un altro computer riceverebbe i dati dei clienti.")
        }
        return await f.verifica()
        #endif
    }

    // MARK: - Risposte

    /// Una risposta intera, per commenti e spiegazioni (modalità lavoro, senza ragionamento).
    func genera(istruzioni: String, richiesta: String) async throws -> String {
        var opzioni = OpzioniModello()
        opzioni.restaInMemoria = restaInMemoria
        return try await scrivi([MessaggioModello(ruolo: .sistema, testo: istruzioni), MessaggioModello(ruolo: .utente, testo: richiesta)],
                                opzioni: opzioni).testo
    }

    func rispondi(_ r: RichiestaEve) async throws -> RispostaEve {
        var eve = ImpostazioniEve()
        eve.restaInMemoria = restaInMemoria
        let testo = try await scrivi(NucleoEve.piano(r, impostazioni: eve, ambiente: AmbienteEve(cliente: r.fonte.cliente.nome))).testo
        return RispostaEve(titolo: nil, testo: testo)
    }

    func scrivi(_ piano: PianoEve, aggiorna: ((ParzialeEve) -> Void)? = nil) async throws -> (testo: String, statistiche: StatisticheModello?) {
        try await scrivi(piano.messaggi, opzioni: piano.opzioni, aggiorna: aggiorna)
    }

    /// La risposta mentre arriva: `aggiorna` riceve il testo visibile fin qui (senza ragionamento) al massimo
    /// una volta ogni `intervalloAggiornamenti`, così l'interfaccia non ridisegna a ogni parola.
    func scrivi(_ messaggi: [MessaggioModello], opzioni: OpzioniModello,
                aggiorna: ((ParzialeEve) -> Void)? = nil) async throws -> (testo: String, statistiche: StatisticheModello?) {
        var filtro = FiltroPensiero()
        var testo = "", pensiero = ""
        var statistiche: StatisticheModello?
        var ultimo = Date.distantPast
        var parlato = false
        for try await pezzo in fornitore.flusso(messaggi, opzioni: opzioni) {
            switch pezzo {
            case .testo(let t):
                let f = filtro.filtra(t)
                testo += f.testo
                pensiero += f.ragionamento
            case .ragionamento(let t):
                pensiero += t
            case .strumento:
                // Fase c: le azioni con tool calling. Per ora non si chiedono strumenti.
                break
            case .fine(let s):
                statistiche = s
            }
            // La prima parola si vede subito, poi al massimo un aggiornamento ogni `intervalloAggiornamenti`
            let prima = !testo.isEmpty && !parlato
            if let aggiorna, prima || Date().timeIntervalSince(ultimo) >= Self.intervalloAggiornamenti {
                ultimo = Date()
                parlato = !testo.isEmpty
                aggiorna(ParzialeEve(testo: NucleoEve.pulisci(testo), pensa: !pensiero.isEmpty))
            }
        }
        testo += filtro.svuota()
        let finale = NucleoEve.pulisci(testo)
        aggiorna?(ParzialeEve(testo: finale, pensa: !pensiero.isEmpty))
        guard !finale.isEmpty else {
            throw ErroreEve(messaggio: "Il modello non ha prodotto una risposta. Riprova con una domanda più precisa.")
        }
        return (finale, statistiche)
    }

    static let intervalloAggiornamenti: TimeInterval = 0.06
}

/// Il testo di una risposta mentre arriva.
struct ParzialeEve: Equatable {
    var testo: String
    /// Il modello sta ragionando (o ha ragionato) prima di rispondere.
    var pensa: Bool
}
