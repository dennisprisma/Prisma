import Foundation

// Il nucleo di Eve parla con un modello attraverso un «fornitore»: Ollama, oppure un server compatibile con
// le API di OpenAI (MLX, llama.cpp, LM Studio). Il resto di Eve non sa quale: costruisce i messaggi,
// riceve i pezzi della risposta mentre arrivano e li mostra. Per ora i fornitori accettano solo indirizzi
// del Mac stesso (IndirizzoLocale): nessun dato dei clienti esce dal computer. iPhone e iPad usano il modello
// del Mac attraverso il ponte cifrato in rete locale (PonteEve), mai un servizio esterno.

/// Un messaggio per il modello.
struct MessaggioModello: Equatable {
    enum Ruolo: String { case sistema = "system", utente = "user", assistente = "assistant" }

    var ruolo: Ruolo
    var testo: String
}

/// Uno strumento che il modello può chiedere di usare (fase c: apri_sezione, cerca_clienti…).
/// `parametri` è lo schema JSON degli argomenti, come lo vogliono Ollama e le API di OpenAI.
struct StrumentoModello {
    var nome: String
    var descrizione: String
    var parametri: [String: Any]

    /// La forma comune ai due fornitori: {"type":"function","function":{…}}.
    var json: [String: Any] {
        ["type": "function", "function": ["name": nome, "description": descrizione, "parameters": parametri]]
    }
}

/// Come rispondere: fantasia, ragionamento, finestra e quanto resta il modello in memoria.
struct OpzioniModello {
    var temperatura = 0.3
    /// Il ragionamento del modello prima di rispondere (Qwen: «think»).
    var pensa = false
    /// La finestra del modello in token (Ollama: num_ctx).
    var contesto = 8_192
    /// Quanto Ollama tiene il modello in memoria dopo la risposta («10m»; «0» lo libera subito).
    var restaInMemoria: String?
    var massimoToken: Int?
    var strumenti: [StrumentoModello] = []
}

/// Una chiamata a uno strumento chiesta dal modello.
struct ChiamataStrumento {
    var nome: String
    var argomenti: [String: Any]
}

/// I numeri di una risposta, quando il fornitore li dà (servono al confronto tra modelli).
struct StatisticheModello: Equatable {
    var tokenDomanda: Int?
    var tokenRisposta: Int?
    /// Secondi spesi a scrivere la risposta (senza caricamento e lettura della domanda).
    var secondiRisposta: Double?

    var tokenAlSecondo: Double? {
        guard let t = tokenRisposta, let s = secondiRisposta, s > 0 else { return nil }
        return Double(t) / s
    }
}

/// Un pezzo della risposta in arrivo.
enum PezzoModello {
    case testo(String)
    case ragionamento(String)
    case strumento(ChiamataStrumento)
    case fine(StatisticheModello)
}

/// Legge lo streaming di un fornitore una riga alla volta (NDJSON per Ollama, SSE per OpenAI).
protocol LettoreFlusso {
    mutating func leggi(_ riga: String) throws -> [PezzoModello]
    /// Quello che resta a flusso chiuso (per esempio uno strumento ancora da consegnare).
    mutating func fine() -> [PezzoModello]
}

protocol FornitoreModello {
    /// «Ollama», «Server compatibile OpenAI».
    var nome: String { get }
    var modello: String { get }
    var indirizzo: String { get }
    var sessione: URLSession { get }

    /// La richiesta HTTP di una risposta in streaming (lancia un errore se l'indirizzo non è locale).
    func richiesta(_ messaggi: [MessaggioModello], opzioni: OpzioniModello) throws -> URLRequest
    func lettore() -> LettoreFlusso
    /// Pronto se il server risponde e ha il modello scelto.
    func verifica() async -> DisponibilitaEve
    /// I modelli installati.
    func modelli() async throws -> [String]
    /// Il server risponde (anche senza il modello)?
    func raggiungibile() async -> Bool
    /// Carica il modello in memoria prima della prima domanda; true se ci è riuscito.
    func precarica(restaInMemoria: String) async -> Bool
    /// Libera la memoria del modello (dove il fornitore lo permette).
    func libera() async
}

extension FornitoreModello {
    func url(_ percorso: String) throws -> URL {
        guard let base = IndirizzoLocale.url(indirizzo) else { throw IndirizzoLocale.errore(indirizzo) }
        return base.appendingPathComponent(percorso)
    }

    /// La risposta pezzo per pezzo, mentre il modello la scrive. Interrompere il ciclo chiude la connessione.
    func flusso(_ messaggi: [MessaggioModello], opzioni: OpzioniModello) -> AsyncThrowingStream<PezzoModello, Error> {
        let io = self
        return AsyncThrowingStream { uscita in
            let compito = Task {
                do {
                    let r = try io.richiesta(messaggi, opzioni: opzioni)
                    let (byte, risposta) = try await io.sessione.bytes(for: r)
                    let codice = (risposta as? HTTPURLResponse)?.statusCode ?? 0
                    guard codice == 200 else {
                        var corpo = ""
                        for try await riga in byte.lines {
                            corpo += riga
                            if corpo.count > 300 { break }
                        }
                        throw ErroreEve(messaggio: "\(io.nome) ha rifiutato la richiesta (modello \(io.modello), codice \(codice)): \(Self.messaggioServer(corpo))")
                    }
                    var l = io.lettore()
                    for try await riga in byte.lines {
                        try Task.checkCancellation()
                        for p in try l.leggi(riga) { uscita.yield(p) }
                    }
                    for p in l.fine() { uscita.yield(p) }
                    uscita.finish()
                } catch is CancellationError {
                    uscita.finish(throwing: CancellationError())
                } catch let e as ErroreEve {
                    uscita.finish(throwing: e)
                } catch {
                    if (error as? URLError)?.code == .cancelled {
                        uscita.finish(throwing: CancellationError())
                    } else {
                        uscita.finish(throwing: ErroreEve(messaggio: "\(io.nome) non ha risposto all'indirizzo \(io.indirizzo): controlla che sia aperto sul Mac."))
                    }
                }
            }
            uscita.onTermination = { _ in compito.cancel() }
        }
    }

    /// Il messaggio d'errore del server ({"error":"…"} o {"error":{"message":"…"}}), altrimenti il corpo.
    static func messaggioServer(_ corpo: String) -> String {
        if let d = corpo.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            if let e = j["error"] as? String { return e }
            if let e = (j["error"] as? [String: Any])?["message"] as? String { return e }
        }
        return String(corpo.prefix(200))
    }

    /// Una GET con risposta 200, entro pochi secondi.
    func leggiJSON(_ percorso: String, attesa: TimeInterval = 3) async -> Any? {
        guard let u = try? url(percorso) else { return nil }
        var r = URLRequest(url: u, timeoutInterval: attesa)
        r.httpMethod = "GET"
        guard case let (dati, risposta)? = try? await sessione.data(for: r),
              (risposta as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONSerialization.jsonObject(with: dati)
    }

    /// Una POST JSON; true con risposta 200.
    func manda(_ percorso: String, _ corpo: [String: Any], attesa: TimeInterval) async -> Bool {
        guard let u = try? url(percorso), let dati = try? JSONSerialization.data(withJSONObject: corpo) else { return false }
        var r = URLRequest(url: u, timeoutInterval: attesa)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = dati
        guard case let (_, risposta)? = try? await sessione.data(for: r) else { return false }
        return (risposta as? HTTPURLResponse)?.statusCode == 200
    }

    /// Pronto se il server risponde e ha il modello scelto (con il messaggio giusto se no).
    func verificaModello(comeScaricarlo: String) async -> DisponibilitaEve {
        guard IndirizzoLocale.url(indirizzo) != nil else {
            return .nonDisponibile("L'indirizzo di \(nome) deve essere sul Mac (127.0.0.1): un altro computer riceverebbe i dati dei clienti.")
        }
        guard let elenco = try? await modelli() else {
            return .nonDisponibile("\(nome) non è aperto (\(indirizzo)): avvialo sul Mac e scegli il modello \(modello).")
        }
        let voluto = modello.trimmingCharacters(in: .whitespaces).lowercased()
        guard !voluto.isEmpty else { return .nonDisponibile("Scegli il modello da usare in Impostazioni › Eve.") }
        guard elenco.contains(where: { FornitoreOllama.stessoModello($0, voluto) }) else {
            return .nonDisponibile("\(nome) è aperto ma manca il modello \(voluto): \(comeScaricarlo)")
        }
        return .pronto
    }
}

/// Gli indirizzi ammessi: solo il Mac stesso.
enum IndirizzoLocale {
    static let host: Set<String> = ["127.0.0.1", "localhost", "::1", "[::1]"]

    /// L'indirizzo se è sul Mac stesso (http o https); nil per qualsiasi altro computer.
    static func url(_ testo: String) -> URL? {
        guard let url = URL(string: testo.trimmingCharacters(in: .whitespaces)), url.scheme == "http" || url.scheme == "https",
              let h = url.host?.lowercased(), host.contains(h) else { return nil }
        return url
    }

    static func errore(_ indirizzo: String) -> ErroreEve {
        ErroreEve(messaggio: "Prisma parla solo con un modello sul Mac (127.0.0.1): l'indirizzo «\(indirizzo)» non è locale.")
    }
}

/// Quale fornitore usa Eve (Impostazioni › Eve).
enum TipoFornitore: String, Codable, CaseIterable, Identifiable {
    case ollama
    /// MLX, llama.cpp, LM Studio: /v1/chat/completions.
    case compatibileOpenAI

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .ollama: return "Ollama"
        case .compatibileOpenAI: return "Compatibile OpenAI"
        }
    }
}

/// Quando Eve ragiona prima di rispondere.
enum SceltaRagionamento: String, Codable, CaseIterable, Identifiable {
    /// Per le domande difficili o se le dici «pensaci bene».
    case automatico
    case sempre
    case mai

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .automatico: return "Automatico"
        case .sempre: return "Sempre"
        case .mai: return "Mai"
        }
    }
}

/// Il fornitore scelto nelle impostazioni.
enum FornitoriEve {
    static func crea(_ eve: ImpostazioniEve, sessione: URLSession = .shared) -> FornitoreModello {
        #if os(iOS)
        // Su iPhone e iPad il modello è quello del Mac, attraverso il ponte cifrato in rete locale
        return PonteEve.fornitore(eve, sessione: sessione)
        #else
        switch eve.fornitore {
        case .ollama:
            return FornitoreOllama(indirizzo: eve.indirizzoLocale, modello: eve.modelloLocale.trimmingCharacters(in: .whitespaces), sessione: sessione)
        case .compatibileOpenAI:
            return FornitoreCompatibileOpenAI(indirizzo: eve.indirizzoCompatibile, modello: eve.modelloCompatibile.trimmingCharacters(in: .whitespaces), sessione: sessione)
        }
        #endif
    }
}

/// Toglie dal testo visibile il ragionamento scritto tra <think> e </think>, anche se i segni arrivano spezzati
/// tra due pezzi dello streaming.
struct FiltroPensiero {
    private var dentro = false
    private var sospeso = ""

    /// A flusso finito: il testo tenuto da parte (un «<» in fondo alla risposta non era un segno).
    mutating func svuota() -> String {
        defer { sospeso = "" }
        return dentro ? "" : sospeso
    }

    /// Il testo visibile e il ragionamento di questo pezzo.
    mutating func filtra(_ pezzo: String) -> (testo: String, ragionamento: String) {
        var resto = sospeso + pezzo
        sospeso = ""
        var testo = "", pensiero = ""
        while !resto.isEmpty {
            let segno = dentro ? "</think>" : "<think>"
            if let r = resto.range(of: segno) {
                if dentro { pensiero += resto[..<r.lowerBound] } else { testo += resto[..<r.lowerBound] }
                resto = String(resto[r.upperBound...])
                dentro.toggle()
                continue
            }
            // Un segno forse spezzato in fondo: lo tengo per il pezzo dopo
            var tieni = 0
            for n in stride(from: min(segno.count - 1, resto.count), through: 1, by: -1) where segno.hasPrefix(String(resto.suffix(n))) {
                tieni = n
                break
            }
            let fino = resto.index(resto.endIndex, offsetBy: -tieni)
            if dentro { pensiero += resto[..<fino] } else { testo += resto[..<fino] }
            sospeso = String(resto[fino...])
            resto = ""
        }
        return (testo, pensiero)
    }
}
