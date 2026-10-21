import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Istruzioni di Eve, lette da Eve/Istruzioni nel pacchetto dell'app (le copia il workflow).
enum IstruzioniEve {
    static let cartella = "Eve/Istruzioni"

    static func testo(_ nome: String) -> String? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("\(cartella)/\(nome).md"),
              let t = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Istruzioni della chat; in sviluppo (`swift run`) ripiega su una versione minima.
    static var chat: String {
        testo("chat") ?? "Sei Eve, l'assistente di un consulente finanziario italiano (canali Alleanza Assicurazioni e indipendente). Rispondi in italiano, in breve, usando solo i dati della scheda del cliente; non inventare numeri e distingui sempre il canale."
    }
}

/// Fabbrica dei motori: chi è disponibile su questo Mac.
enum MotoriEve {
    /// Il modello Apple, se l'app è stata compilata con l'SDK di macOS 26 e il sistema è macOS 26 o successivo.
    static var apple: MotoreEve? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) { return MotoreApple() }
        #endif
        return nil
    }

    static let sintesi = MotoreSintesi()

    /// Testo libero dal modello Apple (per l'estrazione dagli appunti); nil se il modello non c'è.
    static func generaConApple(istruzioni: String, richiesta: String) async throws -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let m = MotoreApple()
            guard m.disponibilita.pronto else { return nil }
            return try await m.genera(istruzioni: istruzioni, richiesta: richiesta)
        }
        #endif
        return nil
    }

    /// Motivo per cui il modello Apple non si può usare (nil se è pronto).
    static var motivoAppleNonDisponibile: String? {
        guard let a = apple else {
            return "Il modello Apple richiede macOS 26 o successivo con Apple Intelligence."
        }
        return a.disponibilita.motivo
    }

    /// Il motore da usare secondo le impostazioni.
    static func scelto(_ preferenza: ImpostazioniEve.Motore) -> MotoreEve {
        switch preferenza {
        case .sintesi:
            return sintesi
        case .apple, .automatico:
            if let a = apple, a.disponibilita.pronto { return a }
            return sintesi
        }
    }
}

#if canImport(FoundationModels)
/// Primo motore di Eve: il modello Apple integrato, sul dispositivo (framework FoundationModels).
/// Nessun dato esce dal Mac.
@available(macOS 26.0, *)
struct MotoreApple: MotoreEve {
    let nome = "Modello Apple"
    let descrizione = "Apple Intelligence sul Mac: il modello gira sul dispositivo e nessun dato esce dal computer."

    var disponibilita: DisponibilitaEve {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .pronto
        case .unavailable(let motivo):
            switch motivo {
            case .deviceNotEligible:
                return .nonDisponibile("Questo Mac non supporta Apple Intelligence.")
            case .appleIntelligenceNotEnabled:
                return .nonDisponibile("Apple Intelligence è spenta: attivala in Impostazioni di Sistema › Apple Intelligence e Siri.")
            case .modelNotReady:
                return .nonDisponibile("Il modello Apple si sta ancora scaricando o preparando: riprova tra qualche minuto.")
            @unknown default:
                return .nonDisponibile("Il modello Apple non è disponibile su questo Mac.")
            }
        }
    }

    func genera(istruzioni: String, richiesta: String) async throws -> String {
        let session = LanguageModelSession(instructions: istruzioni)
        return try await session.respond(to: richiesta).content
    }

    func rispondi(_ r: RichiestaEve) async throws -> RispostaEve {
        let istruzioni = IstruzioniEve.chat + "\n\nSCHEDA DEL CLIENTE\n" + ContestoEve.scheda(r.fonte)
        let session = LanguageModelSession(instructions: istruzioni)
        // Le ultime battute, per le domande di seguito (brevi: la finestra del modello è piccola).
        let storia = r.storia.suffix(4).map { m in
            "\(m.autore == .utente ? "Consulente" : "Eve"): \(String(m.testo.prefix(500)))"
        }
        var prompt = (storia.isEmpty ? "" : "CONVERSAZIONE FIN QUI\n" + storia.joined(separator: "\n") + "\n\n")
            + "DOMANDA DEL CONSULENTE\n" + r.domanda
        if r.spunto != nil {
            // Per gli spunti Prisma prepara già la bozza con i numeri esatti: il modello la rende discorsiva.
            prompt += "\n\nBOZZA PREPARATA DA PRISMA (numeri esatti: non cambiarli e non aggiungerne)\n"
                + MotoriEve.sintesi.componi(r).testo
                + "\n\nRiscrivi la bozza in modo naturale e ordinato e aggiungi al massimo due domande utili da fare al cliente."
        }
        do {
            let risposta = try await session.respond(to: prompt)
            let testo = risposta.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !testo.isEmpty else { throw ErroreEve(messaggio: "Il modello non ha prodotto una risposta. Riprova con una domanda più precisa.") }
            return RispostaEve(titolo: nil, testo: testo)
        } catch let e as LanguageModelSession.GenerationError {
            switch e {
            case .exceededContextWindowSize:
                throw ErroreEve(messaggio: "La conversazione è diventata troppo lunga per il modello: avvia una nuova conversazione.")
            case .guardrailViolation:
                throw ErroreEve(messaggio: "Il modello Apple ha preferito non rispondere a questa richiesta. Prova a riformularla.")
            default:
                throw ErroreEve(messaggio: "Il modello Apple non ha risposto: \(e.localizedDescription)")
            }
        }
    }
}
#endif
