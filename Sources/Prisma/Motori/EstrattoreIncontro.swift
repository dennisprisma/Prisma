import Foundation

/// Una proposta nata dagli appunti dell'incontro, da confermare prima di entrare nel dossier.
struct PropostaIncontro: Identifiable, Hashable {
    enum Tipo: Hashable {
        case bisogno(AreaBisogno, Importanza)
        case evento(EventoVita.Tipo, Int)
        case attivita(String)
    }

    let tipo: Tipo
    /// La frase degli appunti da cui nasce.
    let fonte: String
    /// Chi l'ha proposta: "Regole di Prisma" o "Modello Apple".
    var origine = "Regole di Prisma"

    var id: String {
        switch tipo {
        case .bisogno(let a, _): return "bisogno-\(a.rawValue)"
        case .evento(let t, let anno): return "evento-\(t.rawValue)-\(anno)"
        case .attivita(let t): return "attivita-\(t.lowercased())"
        }
    }

    var titolo: String {
        switch tipo {
        case .bisogno(let a, let i): return "\(a.nome): importanza \(i.nome.lowercased())"
        case .evento(let t, let anno): return "\(t.nome) nel \(anno)"
        case .attivita(let t): return t
        }
    }
}

/// Legge gli appunti dell'incontro e propone bisogni, eventi di vita e attività.
///
/// Le regole sono parole chiave dichiarate, frase per frase: funzionano sempre, sul Mac,
/// senza intelligenza artificiale. Il modello Apple, se disponibile, si aggiunge alle regole
/// rispondendo in un formato a righe che l'app controlla prima di usarlo.
enum EstrattoreIncontro {

    // MARK: - Regole

    static let paroleArea: [AreaBisogno: [String]] = [
        .casa: ["casa", "mutuo", "appartamento", "ristruttur", "trasloc", "affitto", "immobile"],
        .famiglia: ["figli", "figlio", "figlia", "moglie", "marito", "compagn", "famiglia", "bambin", "nascita", "incinta", "nipot", "genitori"],
        .lavoro: ["lavoro", "stipendio", "reddito", "licenzi", "azienda", "partita iva", "libera profession", "promozione", "cassa integrazione", "in proprio"],
        .pensione: ["pensione", "pensionamento", "inps", "tfr", "contributi", "smettere di lavorare", "vecchiaia"],
        .salute: ["salute", "malatt", "infortun", "invalid", "ospedal", "cure", "imprevist", "autosufficien", "badante", "medic"],
        .patrimonio: ["eredità", "ereditat", "successione", "donazione", "investiment", "risparmi", "liquidità", "patrimonio", "rendita", "borsa", "azioni", "obbligazion"],
    ]

    static let paroleUrgenza = ["preoccup", "paura", "ansia", "priorità", "urgente", "subito", "importante", "assolutamente", "non dormo", "tranquill"]

    static let paroleEvento: [(EventoVita.Tipo, [String])] = [
        (.figlioInArrivo, ["figlio in arrivo", "aspettiamo un", "aspetta un bambino", "incinta", "in dolce attesa"]),
        (.acquistoCasa, ["comprare casa", "acquistare casa", "acquisto della casa", "acquisto casa", "comprare un appartamento", "prima casa"]),
        (.matrimonio, ["sposar", "matrimonio", "andare a convivere", "convivenza"]),
        (.studiFigli, ["università", "studi d", "studiare fuori", "master"]),
        (.cambioLavoro, ["cambiare lavoro", "nuovo lavoro", "cambio lavoro", "cambio di lavoro"]),
        (.avvioAttivita, ["aprire un'attività", "aprire un’attività", "mettermi in proprio", "mettersi in proprio", "aprire la partita iva", "avviare un'attività", "avviare un’attività"]),
        (.separazione, ["separa", "divorz"]),
        (.eredita, ["eredità", "ereditato", "donazione"]),
        (.pensione, ["andare in pensione", "pensionamento", "smettere di lavorare"]),
    ]

    static let verbiAttivita = ["inviare", "mandare", "preparare", "verificare", "recuperare", "fissare", "chiamare", "richiedere",
                                "valutare", "confrontare", "aggiornare", "portare", "controllare", "rivedere", "presentare", "firmare"]

    /// Divide il testo in frasi (punto, punto e virgola, a capo, elenchi).
    static func frasi(_ testo: String) -> [String] {
        // Si spezza a fine frase (". ", "; "…) e non dentro i numeri come 30.000.
        testo.replacingOccurrences(of: "•", with: "\n")
            .replacingOccurrences(of: #"[.;!?](\s+|$)"#, with: "\n", options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-–*."))) }
            .filter { $0.count >= 4 }
    }

    /// Anno citato nella frase: "nel 2028", "tra 3 anni", "l'anno prossimo"; altrimenti nil.
    static func anno(in frase: String, oggi: Date) -> Int? {
        let annoCorrente = Calendar(identifier: .gregorian).component(.year, from: oggi)
        let f = frase.lowercased()
        if let r = f.range(of: #"\b20[2-9][0-9]\b"#, options: .regularExpression), let a = Int(f[r]) { return a }
        if let r = f.range(of: #"tra (\d{1,2}) ann"#, options: .regularExpression) {
            let numero = f[r].filter(\.isNumber)
            if let n = Int(numero) { return annoCorrente + n }
        }
        if f.contains("anno prossimo") || f.contains("prossimo anno") { return annoCorrente + 1 }
        if f.contains("quest'anno") || f.contains("quest’anno") { return annoCorrente }
        return nil
    }

    static func conRegole(_ testo: String, oggi: Date = Date()) -> [PropostaIncontro] {
        var proposte: [PropostaIncontro] = []
        var aree: [AreaBisogno: (Importanza, String)] = [:]
        for frase in frasi(testo) {
            let f = frase.lowercased()
            let urgente = paroleUrgenza.contains { f.contains($0) }
            for (area, parole) in paroleArea where parole.contains(where: { f.contains($0) }) {
                let importanza: Importanza = urgente ? .alta : .media
                if let gia = aree[area], gia.0 >= importanza { continue }
                aree[area] = (importanza, frase)
            }
            for (tipo, parole) in paroleEvento where parole.contains(where: { f.contains($0) }) {
                let a = anno(in: frase, oggi: oggi) ?? Calendar(identifier: .gregorian).component(.year, from: oggi) + 1
                let p = PropostaIncontro(tipo: .evento(tipo, a), fonte: frase)
                if !proposte.contains(where: { $0.id == p.id }) { proposte.append(p) }
            }
            if let primo = f.split(separator: " ").first.map(String.init), verbiAttivita.contains(where: { primo.hasPrefix($0) }) {
                proposte.append(PropostaIncontro(tipo: .attivita(frase.prefix(1).uppercased() + String(frase.dropFirst())), fonte: frase))
            }
        }
        for area in AreaBisogno.allCases {
            if let v = aree[area] { proposte.append(PropostaIncontro(tipo: .bisogno(area, v.0), fonte: v.1)) }
        }
        return ordina(proposte)
    }

    // MARK: - Risposta del modello

    /// Istruzioni per il modello: righe "BISOGNO|area|importanza|frase", "EVENTO|tipo|anno|frase", "ATTIVITA|titolo".
    static var istruzioniModello: String {
        IstruzioniEve.testo("estrazione") ?? """
        Leggi gli appunti di un incontro tra un consulente finanziario e il suo cliente e rispondi solo con righe in questo formato:
        BISOGNO|area|importanza|frase degli appunti
        EVENTO|tipo|anno|frase degli appunti
        ATTIVITA|cosa fare, in breve
        Aree: \(AreaBisogno.allCases.map(\.rawValue).joined(separator: ", ")). Importanza: alta, media, bassa.
        Tipi di evento: \(EventoVita.Tipo.allCases.map(\.rawValue).joined(separator: ", ")).
        Usa solo ciò che è scritto negli appunti, non inventare.
        """
    }

    /// Converte le righe del modello in proposte, scartando quelle non valide.
    static func daRisposta(_ testo: String, oggi: Date = Date()) -> [PropostaIncontro] {
        let annoCorrente = Calendar(identifier: .gregorian).component(.year, from: oggi)
        var proposte: [PropostaIncontro] = []
        for riga in testo.components(separatedBy: .newlines) {
            let parti = riga.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard let tipo = parti.first?.uppercased() else { continue }
            switch tipo {
            case "BISOGNO" where parti.count >= 3:
                guard let area = AreaBisogno(rawValue: parti[1].lowercased()) else { continue }
                let livelli: [String: Importanza] = ["alta": .alta, "media": .media, "bassa": .bassa]
                let importanza = livelli[parti[2].lowercased()] ?? .media
                proposte.append(PropostaIncontro(tipo: .bisogno(area, importanza), fonte: parti.count > 3 ? parti[3] : "", origine: "Modello Apple"))
            case "EVENTO" where parti.count >= 3:
                guard let t = EventoVita.Tipo(rawValue: parti[1]), let a = Int(parti[2].filter(\.isNumber)),
                      a >= annoCorrente - 50, a <= annoCorrente + 60 else { continue }
                proposte.append(PropostaIncontro(tipo: .evento(t, a), fonte: parti.count > 3 ? parti[3] : "", origine: "Modello Apple"))
            case "ATTIVITA", "ATTIVITÀ":
                guard parti.count >= 2, !parti[1].isEmpty else { continue }
                proposte.append(PropostaIncontro(tipo: .attivita(String(parti[1].prefix(120))), fonte: "", origine: "Modello Apple"))
            default:
                continue
            }
        }
        return proposte
    }

    /// Unisce regole e modello: per ogni bisogno tiene l'importanza più alta, senza doppioni.
    static func unisci(_ a: [PropostaIncontro], _ b: [PropostaIncontro]) -> [PropostaIncontro] {
        var perId: [String: PropostaIncontro] = [:]
        for p in a + b {
            if let gia = perId[p.id] {
                if case .bisogno(_, let i1) = gia.tipo, case .bisogno(_, let i2) = p.tipo, i2 > i1 { perId[p.id] = p }
            } else {
                perId[p.id] = p
            }
        }
        return ordina(Array(perId.values))
    }

    private static func ordina(_ elenco: [PropostaIncontro]) -> [PropostaIncontro] {
        func peso(_ p: PropostaIncontro) -> Int {
            switch p.tipo {
            case .bisogno: return 0
            case .evento: return 1
            case .attivita: return 2
            }
        }
        return elenco.sorted { peso($0) != peso($1) ? peso($0) < peso($1) : $0.titolo < $1.titolo }
    }
}
