import Foundation

/// Secondo motore di Eve: un modello aperto, Qwen 3, che gira sul Mac con Ollama (un'app gratuita che si
/// scarica a parte). Prisma gli parla solo a un indirizzo del Mac stesso (127.0.0.1): un indirizzo di un altro
/// computer viene rifiutato, così nessun dato dei clienti esce dal Mac.
/// Sul MacBook Pro M1 da 8 GB la taglia giusta è la 4B (circa 2,5 GB di memoria mentre lavora).
struct MotoreLocale: MotoreEve, MotoreGenerativo {
    static let indirizzoPredefinito = "http://127.0.0.1:11434"
    static let modelloPredefinito = "qwen3:4b"
    /// Ollama tiene il modello in memoria solo per poco dopo l'ultima risposta: sul Mac da 8 GB la RAM torna libera.
    static let restaInMemoria = "3m"
    static let attesaMassima: TimeInterval = 120

    let indirizzo: String
    let modello: String
    let disponibilita: DisponibilitaEve

    init(_ eve: ImpostazioniEve, disponibilita: DisponibilitaEve) {
        indirizzo = eve.indirizzoLocale
        modello = eve.modelloLocale.trimmingCharacters(in: .whitespaces)
        self.disponibilita = disponibilita
    }

    var nome: String { "Qwen sul Mac" }
    var descrizione: String { "\(modello) con Ollama, sul Mac: nessun dato esce dal computer." }

    // MARK: - Indirizzo, solo locale

    /// L'indirizzo di Ollama se è sul Mac stesso; nil per qualsiasi altro computer.
    static func indirizzoLocale(_ testo: String) -> URL? {
        guard let url = URL(string: testo.trimmingCharacters(in: .whitespaces)), url.scheme == "http" || url.scheme == "https",
              let host = url.host?.lowercased(), ["127.0.0.1", "localhost", "::1", "[::1]"].contains(host) else { return nil }
        return url
    }

    private func url(_ percorso: String) throws -> URL {
        #if os(iOS)
        throw ErroreEve(messaggio: Self.nonSuiOS)
        #elseif os(macOS)
        guard let base = Self.indirizzoLocale(indirizzo) else {
            throw ErroreEve(messaggio: "Prisma parla solo con un modello sul Mac (127.0.0.1): l'indirizzo «\(indirizzo)» non è locale.")
        }
        return base.appendingPathComponent(percorso)
        #endif
    }

    // MARK: - Disponibilità

    /// Chiede a Ollama quali modelli ha: pronto se c'è quello scelto.
    static func verifica(_ eve: ImpostazioniEve) async -> DisponibilitaEve {
        guard let base = indirizzoLocale(eve.indirizzoLocale) else {
            return .nonDisponibile("L'indirizzo di Ollama deve essere sul Mac (127.0.0.1): un altro computer riceverebbe i dati dei clienti.")
        }
        #if os(iOS)
        // Su iPhone e iPad Qwen non c'è ancora (arriverà dal Mac in rete locale): Eve lo dice e non risponde
        _ = base
        return .nonDisponibile(nonSuiOS)
        #elseif os(macOS)
        var r = URLRequest(url: base.appendingPathComponent("api/tags"), timeoutInterval: 3)
        r.httpMethod = "GET"
        guard case let (dati, risposta)? = try? await URLSession.shared.data(for: r),
              (risposta as? HTTPURLResponse)?.statusCode == 200 else {
            return .nonDisponibile("Ollama non è aperto: avvia l'app Ollama sul Mac (si scarica gratis da ollama.com) e scegli il modello \(eve.modelloLocale).")
        }
        let modelli = Self.modelli(dati)
        let voluto = eve.modelloLocale.trimmingCharacters(in: .whitespaces).lowercased()
        guard modelli.contains(where: { Self.stessoModello($0, voluto) }) else {
            return .nonDisponibile("Ollama è aperto ma manca il modello \(voluto): scaricalo dall'app Ollama (o con «ollama pull \(voluto)»).")
        }
        return .pronto
        #endif
    }

    #if os(iOS)
    /// Il motivo per cui Eve non risponde su iPhone e iPad (in questa versione).
    static let nonSuiOS = "Eve su iPhone e iPad non è ancora disponibile: Qwen lavora sul Mac. Usa Eve da Prisma sul Mac."
    #endif

    /// I nomi dei modelli nella risposta di /api/tags.
    static func modelli(_ dati: Data) -> [String] {
        struct Elenco: Decodable { struct Modello: Decodable { let name: String }; let models: [Modello] }
        return ((try? JSONDecoder().decode(Elenco.self, from: dati))?.models ?? []).map { $0.name.lowercased() }
    }

    /// «qwen3» vale come «qwen3:latest».
    static func stessoModello(_ a: String, _ b: String) -> Bool {
        func pieno(_ s: String) -> String { s.contains(":") ? s : s + ":latest" }
        return pieno(a) == pieno(b)
    }

    // MARK: - Risposte

    func genera(istruzioni: String, richiesta: String) async throws -> String {
        try await chiedi([("system", istruzioni), ("user", richiesta)])
    }

    func rispondi(_ r: RichiestaEve) async throws -> RispostaEve {
        let (istruzioni, prompt) = PromptEve.chat(r)
        let testo = try await chiedi([("system", istruzioni), ("user", prompt)])
        guard !testo.isEmpty else { throw ErroreEve(messaggio: "Il modello non ha prodotto una risposta. Riprova con una domanda più precisa.") }
        return RispostaEve(titolo: nil, testo: testo)
    }

    private func chiedi(_ messaggi: [(String, String)]) async throws -> String {
        var r = URLRequest(url: try url("api/chat"), timeoutInterval: Self.attesaMassima)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: Self.corpo(modello: modello, messaggi: messaggi))
        let dati: Data
        let risposta: URLResponse
        do {
            (dati, risposta) = try await URLSession.shared.data(for: r)
        } catch {
            throw ErroreEve(messaggio: "Qwen sul Mac non ha risposto: controlla che l'app Ollama sia aperta.")
        }
        guard (risposta as? HTTPURLResponse)?.statusCode == 200 else {
            throw ErroreEve(messaggio: "Ollama ha rifiutato la richiesta (modello \(modello)): \(String(data: dati, encoding: .utf8)?.prefix(200) ?? "")")
        }
        return Self.testo(dati)
    }

    /// La richiesta per /api/chat: niente «ragionamento» a voce alta (Qwen 3 lo farebbe), poca fantasia, una sola risposta.
    static func corpo(modello: String, messaggi: [(String, String)]) -> [String: Any] {
        [
            "model": modello,
            "messages": messaggi.map { ["role": $0.0, "content": $0.1] },
            "stream": false,
            "think": false,
            "keep_alive": restaInMemoria,
            "options": ["temperature": 0.3, "num_ctx": 8192],
        ]
    }

    /// Il testo della risposta di Ollama, senza l'eventuale ragionamento tra <think> e </think>.
    static func testo(_ dati: Data) -> String {
        struct Risposta: Decodable { struct Messaggio: Decodable { let content: String }; let message: Messaggio }
        let grezzo = (try? JSONDecoder().decode(Risposta.self, from: dati))?.message.content ?? ""
        return grezzo.replacingOccurrences(of: #"(?s)<think>.*?</think>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
