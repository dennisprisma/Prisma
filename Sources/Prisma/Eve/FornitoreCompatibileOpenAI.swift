import Foundation

/// Un server sul Mac con le API di OpenAI: mlx_lm.server (MLX), llama-server (llama.cpp), LM Studio.
/// /v1/chat/completions in streaming (righe «data: {…}», poi «data: [DONE]»). Per ora solo indirizzi locali.
struct FornitoreCompatibileOpenAI: FornitoreModello {
    /// llama-server e mlx_lm.server partono sulla 8080 (LM Studio sulla 1234).
    static let indirizzoPredefinito = "http://127.0.0.1:8080"

    let indirizzo: String
    let modello: String
    var sessione: URLSession = .shared

    var nome: String { "Server compatibile OpenAI" }

    func richiesta(_ messaggi: [MessaggioModello], opzioni: OpzioniModello) throws -> URLRequest {
        var r = URLRequest(url: try url("v1/chat/completions"), timeoutInterval: MotoreLocale.attesaMassima)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        r.httpBody = try JSONSerialization.data(withJSONObject: Self.corpo(modello: modello, messaggi: messaggi, opzioni: opzioni))
        return r
    }

    /// Il corpo di /v1/chat/completions. Il ragionamento dei modelli Qwen si accende o spegne con
    /// chat_template_kwargs (llama.cpp, vLLM; gli altri server ignorano il campo).
    static func corpo(modello: String, messaggi: [MessaggioModello], opzioni: OpzioniModello) -> [String: Any] {
        var c: [String: Any] = [
            "model": modello,
            "messages": messaggi.map { ["role": $0.ruolo.rawValue, "content": $0.testo] },
            "stream": true,
            "stream_options": ["include_usage": true],
            "temperature": opzioni.temperatura,
            "chat_template_kwargs": ["enable_thinking": opzioni.pensa],
        ]
        if let n = opzioni.massimoToken { c["max_tokens"] = n }
        if !opzioni.strumenti.isEmpty { c["tools"] = opzioni.strumenti.map(\.json) }
        return c
    }

    func lettore() -> LettoreFlusso { Lettore() }

    /// Le righe SSE. Gli argomenti degli strumenti arrivano a pezzi: si consegnano interi alla fine.
    struct Lettore: LettoreFlusso {
        private var strumenti: [Int: (nome: String, argomenti: String)] = [:]
        private var statistiche = StatisticheModello()
        private var inizio: Date?
        private var finito = false

        mutating func leggi(_ riga: String) throws -> [PezzoModello] {
            let pulita = riga.trimmingCharacters(in: .whitespacesAndNewlines)
            guard pulita.hasPrefix("data:") else { return [] }
            let dati = pulita.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if dati == "[DONE]" { return fine() }
            guard let d = dati.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [] }
            if let e = j["error"] {
                let m = (e as? [String: Any])?["message"] as? String ?? (e as? String) ?? "errore del server"
                throw ErroreEve(messaggio: "Server compatibile OpenAI: \(m)")
            }
            if let u = j["usage"] as? [String: Any] {
                statistiche.tokenDomanda = (u["prompt_tokens"] as? NSNumber)?.intValue
                statistiche.tokenRisposta = (u["completion_tokens"] as? NSNumber)?.intValue
            }
            var pezzi: [PezzoModello] = []
            for scelta in (j["choices"] as? [[String: Any]]) ?? [] {
                guard let delta = scelta["delta"] as? [String: Any] else { continue }
                // Il ragionamento separato: reasoning_content (llama.cpp, vLLM) o reasoning
                if let t = (delta["reasoning_content"] ?? delta["reasoning"]) as? String, !t.isEmpty {
                    pezzi.append(.ragionamento(t))
                }
                if let t = delta["content"] as? String, !t.isEmpty {
                    if inizio == nil { inizio = Date() }
                    pezzi.append(.testo(t))
                }
                for s in (delta["tool_calls"] as? [[String: Any]]) ?? [] {
                    let i = (s["index"] as? NSNumber)?.intValue ?? 0
                    let f = s["function"] as? [String: Any] ?? [:]
                    var voce = strumenti[i] ?? ("", "")
                    if let n = f["name"] as? String { voce.nome += n }
                    if let a = f["arguments"] as? String { voce.argomenti += a }
                    strumenti[i] = voce
                }
            }
            return pezzi
        }

        mutating func fine() -> [PezzoModello] {
            guard !finito else { return [] }
            finito = true
            var pezzi: [PezzoModello] = strumenti.sorted { $0.key < $1.key }.map { voce in
                let s = voce.value
                let argomenti = s.argomenti.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
                return .strumento(ChiamataStrumento(nome: s.nome, argomenti: argomenti))
            }
            if let i = inizio { statistiche.secondiRisposta = Date().timeIntervalSince(i) }
            pezzi.append(.fine(statistiche))
            return pezzi
        }
    }

    func verifica() async -> DisponibilitaEve {
        await verificaModello(comeScaricarlo: "caricalo nel server (LM Studio, llama-server o mlx_lm.server) con questo nome.")
    }

    /// /v1/models: {"data":[{"id":"…"}]}.
    func modelli() async throws -> [String] {
        guard let j = await leggiJSON("v1/models") else { throw ErroreEve(messaggio: "Il server non risponde.") }
        return Self.modelli(j)
    }

    static func modelli(_ j: Any) -> [String] {
        (((j as? [String: Any])?["data"] as? [[String: Any]]) ?? []).compactMap { ($0["id"] as? String)?.lowercased() }
    }

    func raggiungibile() async -> Bool {
        await leggiJSON("v1/models", attesa: 2) != nil
    }

    /// Questi server caricano il modello all'avvio: basta che rispondano.
    func precarica(restaInMemoria: String) async -> Bool {
        await raggiungibile()
    }

    func libera() async {}
}
