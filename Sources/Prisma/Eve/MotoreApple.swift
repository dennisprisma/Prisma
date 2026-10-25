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

/// Un motore che scrive testo libero (il modello Apple o Qwen sul Mac): lo usano chat, commenti ed estrazioni.
protocol MotoreGenerativo {
    var nome: String { get }
    func genera(istruzioni: String, richiesta: String) async throws -> String
}

/// Le istruzioni e la richiesta per una domanda in chat, uguali per ogni modello.
enum PromptEve {
    static func chat(_ r: RichiestaEve) -> (istruzioni: String, prompt: String) {
        let istruzioni = IstruzioniEve.chat + "\n\nSCHEDA DEL CLIENTE\n" + ContestoEve.scheda(r.fonte)
        // Le ultime battute, per le domande di seguito (brevi: la finestra del modello è piccola).
        let storia = r.storia.suffix(4).map { m in
            "\(m.autore == .utente ? "Consulente" : "Eve"): \(String(m.testo.prefix(500)))"
        }
        var prompt = (storia.isEmpty ? "" : "CONVERSAZIONE FIN QUI\n" + storia.joined(separator: "\n") + "\n\n")
            + "DOMANDA DEL CONSULENTE\n" + r.domanda
        if r.spunto != nil {
            // Per gli spunti Prisma prepara già la bozza con i numeri esatti: il modello la rende discorsiva.
            prompt += "\n\nBOZZA PREPARATA DA PRISMA (numeri esatti: non cambiarli e non aggiungerne)\n"
                + String(MotoriEve.sintesi.componi(r).testo.prefix(ContestoEve.limiteCalcoli))
                + "\n\nRiscrivi la bozza in modo naturale e ordinato e aggiungi al massimo due domande utili da fare al cliente."
        } else if let s = SpuntoEve.argomento(r.domanda) {
            // Domanda libera su un argomento che Prisma ha già calcolato: le passo le cifre pertinenti.
            let calcoli = MotoriEve.sintesi.componi(RichiestaEve(domanda: s.domanda, spunto: s, fonte: r.fonte, storia: [])).testo
            prompt += "\n\nCALCOLI DI PRISMA PERTINENTI (numeri esatti: usali solo se servono alla domanda, senza cambiarli)\n"
                + String(calcoli.prefix(ContestoEve.limiteCalcoli))
        }
        return (istruzioni, prompt)
    }
}

/// Fabbrica dei motori: chi è disponibile su questo Mac.
enum MotoriEve {
    /// Il modello Apple, se l'app è stata compilata con l'SDK di macOS 26 e il sistema è macOS 26 o successivo.
    static var apple: (MotoreEve & MotoreGenerativo)? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) { return MotoreApple() }
        #endif
        return nil
    }

    static let sintesi = MotoreSintesi()

    /// Motivo per cui il modello Apple non si può usare (nil se è pronto).
    static var motivoAppleNonDisponibile: String? {
        guard let a = apple else {
            return "Il modello Apple richiede macOS 26 o successivo con Apple Intelligence."
        }
        return a.disponibilita.motivo
    }

    /// Il modello che scrive, secondo le impostazioni e la disponibilità (nil = solo la sintesi dai dati).
    /// Automatico: il modello Apple se è pronto, altrimenti Qwen sul Mac se è pronto.
    static func generativo(_ eve: ImpostazioniEve, locale: DisponibilitaEve) -> (MotoreEve & MotoreGenerativo)? {
        let qwen = MotoreLocale(eve, disponibilita: locale)
        switch eve.motore {
        case .sintesi:
            return nil
        case .apple:
            if let a = apple, a.disponibilita.pronto { return a }
            return nil
        case .locale:
            return qwen.disponibilita.pronto ? qwen : nil
        case .automatico:
            if let a = apple, a.disponibilita.pronto { return a }
            return qwen.disponibilita.pronto ? qwen : nil
        }
    }

    /// Il motore da usare secondo le impostazioni.
    static func scelto(_ eve: ImpostazioniEve, locale: DisponibilitaEve) -> MotoreEve {
        generativo(eve, locale: locale) ?? sintesi
    }

    /// Perché il motore scelto non risponde (nil se risponde o se si è scelta la sintesi).
    static func motivo(_ eve: ImpostazioniEve, locale: DisponibilitaEve) -> String? {
        switch eve.motore {
        case .sintesi: return nil
        case .apple: return motivoAppleNonDisponibile
        case .locale: return locale.motivo
        case .automatico:
            guard generativo(eve, locale: locale) == nil else { return nil }
            return motivoAppleNonDisponibile
        }
    }
}

#if canImport(FoundationModels)
/// Primo motore di Eve: il modello Apple integrato, sul dispositivo (framework FoundationModels).
/// Nessun dato esce dal Mac.
@available(macOS 26.0, *)
struct MotoreApple: MotoreEve, MotoreGenerativo {
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
        let (istruzioni, prompt) = PromptEve.chat(r)
        let session = LanguageModelSession(instructions: istruzioni)
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
