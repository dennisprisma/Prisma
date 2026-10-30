import Foundation

/// Ollama sul Mac (http://127.0.0.1:11434): /api/chat in streaming, una riga JSON per pezzo.
/// Con «think» il ragionamento arriva a parte (message.thinking) e non entra nella risposta.
struct FornitoreOllama: FornitoreModello {
    static let indirizzoPredefinito = "http://127.0.0.1:11434"

    let indirizzo: String
    let modello: String
    var sessione: URLSession = .shared

    var nome: String { "Ollama" }

    func richiesta(_ messaggi: [MessaggioModello], opzioni: OpzioniModello) throws -> URLRequest {
        var r = URLRequest(url: try url("api/chat"), timeoutInterval: MotoreLocale.attesaMassima)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: Self.corpo(modello: modello, messaggi: messaggi, opzioni: opzioni))
        return r
    }

    /// Il corpo di /api/chat: streaming, ragionamento solo se chiesto, la finestra e la memoria scelte.
    static func corpo(modello: String, messaggi: [MessaggioModello], opzioni: OpzioniModello) -> [String: Any] {
        var opzioniOllama: [String: Any] = ["temperature": opzioni.temperatura, "num_ctx": opzioni.contesto]
        if let n = opzioni.massimoToken { opzioniOllama["num_predict"] = n }
        var c: [String: Any] = [
            "model": modello,
            "messages": messaggi.map { ["role": $0.ruolo.rawValue, "content": $0.testo] },
            "stream": true,
            "think": opzioni.pensa,
            "options": opzioniOllama,
        ]
        if let k = opzioni.restaInMemoria { c["keep_alive"] = k }
        if !opzioni.strumenti.isEmpty { c["tools"] = opzioni.strumenti.map(\.json) }
        return c
    }

    func lettore() -> LettoreFlusso { Lettore() }

    /// Una riga: {"message":{"content":"…","thinking":"…","tool_calls":[…]},"done":false}; l'ultima ha done e i conteggi.
    struct Lettore: LettoreFlusso {
        mutating func leggi(_ riga: String) throws -> [PezzoModello] {
            let pulita = riga.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pulita.isEmpty, let d = pulita.data(using: .utf8),
                  let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [] }
            if let e = j["error"] as? String { throw ErroreEve(messaggio: "Ollama: \(e)") }
            var pezzi: [PezzoModello] = []
            if let m = j["message"] as? [String: Any] {
                if let t = m["thinking"] as? String, !t.isEmpty { pezzi.append(.ragionamento(t)) }
                if let t = m["content"] as? String, !t.isEmpty { pezzi.append(.testo(t)) }
                for chiamata in (m["tool_calls"] as? [[String: Any]]) ?? [] {
                    guard let f = chiamata["function"] as? [String: Any], let n = f["name"] as? String else { continue }
                    pezzi.append(.strumento(ChiamataStrumento(nome: n, argomenti: f["arguments"] as? [String: Any] ?? [:])))
                }
            }
            if (j["done"] as? Bool) == true {
                let durata = (j["eval_duration"] as? NSNumber).map { $0.doubleValue / 1_000_000_000 }
                pezzi.append(.fine(StatisticheModello(tokenDomanda: (j["prompt_eval_count"] as? NSNumber)?.intValue,
                                                      tokenRisposta: (j["eval_count"] as? NSNumber)?.intValue,
                                                      secondiRisposta: durata)))
            }
            return pezzi
        }

        mutating func fine() -> [PezzoModello] { [] }
    }

    func verifica() async -> DisponibilitaEve {
        await verificaModello(comeScaricarlo: "scaricalo con «ollama pull \(modello)» nel Terminale (o dall'app Ollama).")
    }

    func modelli() async throws -> [String] {
        guard let j = await leggiJSON("api/tags") else { throw ErroreEve(messaggio: "Ollama non risponde.") }
        return Self.modelli(j)
    }

    func raggiungibile() async -> Bool {
        await leggiJSON("api/version", attesa: 2) != nil
    }

    /// Con l'elenco dei messaggi vuoto Ollama carica soltanto il modello in memoria.
    func precarica(restaInMemoria: String) async -> Bool {
        await manda("api/chat", ["model": modello, "messages": [[String: String]](), "keep_alive": restaInMemoria], attesa: 120)
    }

    func libera() async {
        _ = await manda("api/chat", ["model": modello, "messages": [[String: String]](), "keep_alive": 0], attesa: 20)
    }

    /// I nomi dei modelli nella risposta di /api/tags.
    static func modelli(_ j: Any) -> [String] {
        (((j as? [String: Any])?["models"] as? [[String: Any]]) ?? []).compactMap { ($0["name"] as? String)?.lowercased() }
    }

    static func modelli(_ dati: Data) -> [String] {
        (try? JSONSerialization.jsonObject(with: dati)).map { modelli($0 as Any) } ?? []
    }

    /// «qwen3» vale come «qwen3:latest».
    static func stessoModello(_ a: String, _ b: String) -> Bool {
        func pieno(_ s: String) -> String { s.contains(":") ? s.lowercased() : s.lowercased() + ":latest" }
        return pieno(a) == pieno(b)
    }
}
