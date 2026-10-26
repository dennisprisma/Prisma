import Foundation

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

/// Un motore che scrive testo libero (Qwen sul Mac): lo usano chat, commenti e spiegazioni dei documenti.
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

/// I motori di Eve. L'intelligenza artificiale è una sola: Qwen, sul Mac, con Ollama.
/// I calcoli di Prisma (`sintesi`) preparano le cifre esatte che Qwen racconta, ma non rispondono da soli.
enum MotoriEve {
    static let sintesi = MotoreSintesi()

    /// Qwen sul Mac, con lo stato verificato dall'ultima chiamata a Ollama.
    static func qwen(_ eve: ImpostazioniEve, locale: DisponibilitaEve) -> MotoreLocale {
        MotoreLocale(eve, disponibilita: locale)
    }

    /// Qwen, se è pronto; nil se Ollama è spento o manca il modello.
    static func generativo(_ eve: ImpostazioniEve, locale: DisponibilitaEve) -> (MotoreEve & MotoreGenerativo)? {
        let q = qwen(eve, locale: locale)
        return q.disponibilita.pronto ? q : nil
    }

    /// Perché Qwen non risponde (nil se è pronto).
    static func motivo(_ eve: ImpostazioniEve, locale: DisponibilitaEve) -> String? {
        locale.motivo
    }
}
