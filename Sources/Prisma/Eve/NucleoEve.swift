import Foundation

// Il nucleo della nuova Eve: sceglie la modalità dalla domanda, prepara il contesto a strati e la storia
// entro un budget di token, poi passa i messaggi al fornitore (che non conosce).
//
// Strati, dal più stabile al più variabile: le istruzioni fisse (sempre uguali: Ollama le tiene in cache),
// la storia della conversazione, poi l'ultimo messaggio con una riga di contesto (data, app aperte,
// cliente attivo), la scheda del cliente solo se la domanda lo riguarda, le cifre di Prisma e la domanda.

/// Lavoro: numeri solo dai motori di Prisma e dalla scheda. Conversazione: uso generale.
enum ModalitaEve: String, Codable {
    case lavoro
    case conversazione
}

/// Cosa ha deciso Eve per una domanda.
struct SceltaEve: Equatable {
    var modalita: ModalitaEve
    var pensa: Bool

    var conScheda: Bool { modalita == .lavoro }
}

/// Dove si trova il consulente quando fa la domanda.
struct AmbienteEve {
    var oggi = Date()
    var appAperte: [String] = []
    var cliente: String?
    /// La domanda arriva dalla mini finestra: risposta breve (Eve/Istruzioni/mini.md), le cifre le mostra la scheda.
    var breve = false
}

/// Tutto quello che va al fornitore per una risposta.
struct PianoEve {
    var scelta: SceltaEve
    var messaggi: [MessaggioModello]
    var opzioni: OpzioniModello
}

enum NucleoEve {
    /// Finestra del modello: 8.192 token stanno bene nella memoria del Mac da 8 GB.
    static let finestra = 8_192
    /// Spazio lasciato alla risposta (al ragionamento serve di più).
    static let riservaRisposta = 1_600
    static let riservaRagionamento = 1_800
    /// Al massimo tante battute di storia, ognuna al massimo così lunga.
    static let massimoBattute = 40
    static let massimoCaratteriBattuta = 6_000

    // MARK: - Modalità e ragionamento

    /// La modalità e il ragionamento per questa domanda.
    static func scegli(_ r: RichiestaEve, ragionamento: SceltaRagionamento) -> SceltaEve {
        let modalita = modalita(domanda: r.domanda, spunto: r.spunto, cliente: r.fonte.cliente, storia: r.storia)
        let pensa: Bool
        switch ragionamento {
        case .sempre: pensa = true
        case .mai: pensa = false
        case .automatico: pensa = vuolePensare(r.domanda)
        }
        return SceltaEve(modalita: modalita, pensa: pensa)
    }

    /// Lavoro se la domanda riguarda il cliente o i temi di Prisma; conversazione per tutto il resto.
    static func modalita(domanda: String, spunto: SpuntoEve?, cliente: Cliente?, storia: [MessaggioEve]) -> ModalitaEve {
        if spunto != nil { return .lavoro }
        let t = semplice(domanda)
        let parlaDelCliente = cliente.map { nomina($0, t) } ?? false
            || contiene(t, ["cliente", "dossier", "scheda", "il suo", "la sua", "i suoi", "le sue", "taccuino", "suo marito", "sua moglie", "suoi figli"])
        if parlaDelCliente { return .lavoro }
        // Domande di cultura generale, scrittura, riassunti: conversazione anche se toccano la finanza
        if contiene(t, generale) { return .conversazione }
        if contiene(t, temiPrisma) || SpuntoEve.da(domanda) != nil { return .lavoro }
        // Una domanda breve di seguito («e per i figli?») resta nella modalità di prima
        if t.split(separator: " ").count <= 7,
           let ultima = storia.last(where: { $0.autore == .eve && $0.modalita != nil }), ultima.modalita == .lavoro {
            return .lavoro
        }
        return .conversazione
    }

    /// Le parole che chiedono un ragionamento, o una domanda lunga e articolata.
    static func vuolePensare(_ domanda: String) -> Bool {
        let t = semplice(domanda)
        if contiene(t, ["pensaci", "ragionaci", "ragiona", "rifletti", "con calma", "approfondisci", "passo passo", "passo dopo passo",
                        "pro e contro", "vantaggi e svantaggi", "strategia", "pianifica", "dimostra", "analizza a fondo", "nel dettaglio"]) {
            return true
        }
        return domanda.count > 320 || domanda.filter { $0 == "?" }.count >= 3
    }

    static let generale = ["in generale", "in astratto", "cos'e", "cosa e ", "che cos", "cosa significa", "cosa vuol dire", "che significa",
                           "come funziona", "come funzionano", "che differenza", "differenza tra", "spiegami cos", "scrivimi", "scrivi una",
                           "scrivi un", "riassumi", "riassunto", "traduci", "correggi", "riformula", "aiutami a scrivere", "una mail",
                           "un'email", "una lettera", "idee per", "consigliami", "raccontami", "chi era", "chi e ", "storia di"]

    static let temiPrisma = ["posizion", "polizz", "portafogli", "propost", "alleanza", "pension", "previdenz", "tfr", "protezion",
                             "copertur", "liquidit", "obiettiv", "scadenz", "scade", "rendiment", "andament", "costi", "commission",
                             "patrimon", "eredi", "succession", "check-up", "check up", "riepilog", "incontr", "appuntament", "kid",
                             "document", "premi", "capitale", "prova di resistenza", "semaforo", "prossimi passi", "rischio"]

    /// Il nome o il cognome del cliente nella domanda, come parola intera.
    static func nomina(_ c: Cliente, _ t: String) -> Bool {
        let parole = Set(t.split { !$0.isLetter }.map(String.init))
        return semplice(c.nome).split(separator: " ").contains { $0.count >= 3 && parole.contains(String($0)) }
    }

    /// Minuscole, senza accenti, apostrofi dritti: «Cos’è» → «cos'e».
    static func semplice(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
            .replacingOccurrences(of: "’", with: "'")
    }

    private static func contiene(_ t: String, _ chiavi: [String]) -> Bool {
        chiavi.contains { t.contains($0) }
    }

    // MARK: - Contesto a strati

    static func piano(_ r: RichiestaEve, impostazioni eve: ImpostazioniEve, ambiente: AmbienteEve) -> PianoEve {
        let scelta = scegli(r, ragionamento: eve.ragionamento)
        let sistema = MessaggioModello(ruolo: .sistema, testo: scelta.modalita == .lavoro ? IstruzioniEve.chat : IstruzioniEve.conversazione)
        let ultimo = MessaggioModello(ruolo: .utente, testo: ultimoMessaggio(r, scelta: scelta, ambiente: ambiente))
        // 4 token di cornice per messaggio, come nella storia
        let budget = finestra - token(sistema.testo) - token(ultimo.testo) - 8 - (scelta.pensa ? riservaRisposta + riservaRagionamento : riservaRisposta)
        var opzioni = OpzioniModello()
        opzioni.temperatura = scelta.modalita == .lavoro ? 0.3 : 0.7
        // Con il ragionamento Qwen consiglia un po' più di fantasia
        if scelta.pensa { opzioni.temperatura = max(opzioni.temperatura, 0.6) }
        opzioni.pensa = scelta.pensa
        opzioni.contesto = finestra
        opzioni.restaInMemoria = eve.restaInMemoria
        return PianoEve(scelta: scelta, messaggi: [sistema] + storia(r.storia, budget: budget) + [ultimo], opzioni: opzioni)
    }

    /// La riga di contesto: data, app aperte, cliente attivo.
    static func rigaContesto(_ a: AmbienteEve) -> String {
        var parti = ["Oggi è \(Formati.dataLunga.string(from: a.oggi)) \(Formati.formato("yyyy").string(from: a.oggi)), ore \(Formati.ora.string(from: a.oggi))"]
        if !a.appAperte.isEmpty { parti.append("app aperte in Prisma: \(a.appAperte.joined(separator: ", "))") }
        if let c = a.cliente { parti.append("cliente attivo: \(c)") }
        return "CONTESTO: " + parti.joined(separator: "; ") + "."
    }

    /// L'ultimo messaggio: contesto, scheda e cifre di Prisma (in lavoro), la domanda.
    static func ultimoMessaggio(_ r: RichiestaEve, scelta: SceltaEve, ambiente: AmbienteEve) -> String {
        var parti = [rigaContesto(ambiente)]
        if scelta.conScheda {
            parti.append("SCHEDA DEL CLIENTE (calcolata da Prisma)\n" + ContestoEve.scheda(r.fonte))
            if r.spunto != nil {
                // Per gli spunti Prisma prepara già la bozza con i numeri esatti: il modello la rende discorsiva.
                parti.append("BOZZA PREPARATA DA PRISMA (numeri esatti: non cambiarli e non aggiungerne)\n"
                             + String(MotoriEve.sintesi.componi(r).testo.prefix(ContestoEve.limiteCalcoli))
                             + "\n\nRiscrivi la bozza in modo naturale e ordinato e aggiungi al massimo due domande utili da fare al cliente.")
            } else if let s = SpuntoEve.argomento(r.domanda) {
                // Domanda libera su un argomento che Prisma ha già calcolato: le cifre pertinenti.
                let calcoli = MotoriEve.sintesi.componi(RichiestaEve(domanda: s.domanda, spunto: s, fonte: r.fonte, storia: [])).testo
                parti.append("CALCOLI DI PRISMA PERTINENTI (numeri esatti: usali solo se servono alla domanda, senza cambiarli)\n"
                             + String(calcoli.prefix(ContestoEve.limiteCalcoli)))
            }
        }
        if ambiente.breve { parti.append("COME RISPONDERE\n" + IstruzioniEve.mini) }
        parti.append("DOMANDA DEL CONSULENTE\n" + r.domanda)
        return parti.joined(separator: "\n\n")
    }

    /// Le battute più recenti che stanno nel budget, in ordine. Restano fuori gli avvisi di Prisma
    /// («Qwen non è pronto») e le battute che non entrano più.
    static func storia(_ messaggi: [MessaggioEve], budget: Int) -> [MessaggioModello] {
        var scelti: [MessaggioModello] = []
        var resto = budget
        for m in messaggi.reversed() {
            guard scelti.count < massimoBattute else { break }
            if m.autore == .eve && (m.motore == "Prisma" || m.titolo == "Eve non ha potuto rispondere") { continue }
            var testo = m.testo
            if m.autore == .eve, let t = m.titolo, !t.isEmpty { testo = t + "\n" + testo }
            if testo.count > massimoCaratteriBattuta { testo = String(testo.prefix(massimoCaratteriBattuta)) + "…" }
            let costo = token(testo) + 4
            guard costo <= resto else { break }
            resto -= costo
            scelti.append(MessaggioModello(ruolo: m.autore == .utente ? .utente : .assistente, testo: testo))
        }
        // La storia comincia con una domanda del consulente
        while scelti.last?.ruolo == .assistente { scelti.removeLast() }
        return scelti.reversed()
    }

    /// Stima dei token: in italiano circa un token ogni 3,5 caratteri (per eccesso).
    static func token(_ testo: String) -> Int {
        Int((Double(testo.count) / 3.5).rounded(.up))
    }

    /// Il testo finale da mostrare: senza grassetti markdown e spazi in eccesso.
    static func pulisci(_ testo: String) -> String {
        testo.replacingOccurrences(of: #"(?s)<think>.*?</think>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
