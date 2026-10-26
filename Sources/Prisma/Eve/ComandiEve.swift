import Foundation

/// Le cose che Eve fa da sola quando glielo chiedi, a voce o per scritto: aprire un'app o un dossier,
/// preparare un documento, fissare un appuntamento, ricordarti qualcosa, prendere nota, dirti l'agenda.
/// Il riconoscimento è fatto dall'app (regole sulle parole), così funziona con ogni motore e anche senza modello.
enum ComandoEve: Equatable {
    case apri(AppPrisma)
    case scrivania
    case cliente(String)
    case documento(SceltaProspetto, cliente: String?)
    case appuntamento(Appuntamento.Bozza)
    case attivita(cliente: String?, titolo: String, scadenza: Date)
    case nota(cliente: String?, testo: String)
    case agenda(Date)
    /// Eve ha capito cosa fare ma le manca qualcosa: la domanda da fare.
    case chiedi(String)
}

extension Appuntamento {
    /// Un appuntamento chiesto a Eve, magari ancora senza giorno o senza ora.
    struct Bozza: Equatable {
        var cliente: String?
        var giorno: Date?
        var ora: Int?
        var minuti = 0
        var tipo = TipoAppuntamento.altro
        var titolo: String

        var completa: Bool { cliente != nil && giorno != nil && ora != nil }

        func inizio(_ cal: Calendar = .current) -> Date? {
            guard let giorno, let ora else { return nil }
            return cal.date(bySettingHour: ora, minute: minuti, second: 0, of: giorno)
        }
    }
}

/// Un cliente come Eve lo riconosce nella frase.
struct ClienteNoto {
    let id: String
    let nome: String
}

enum InterpreteComandi {
    /// Il comando contenuto nella frase (nil se è una domanda da passare a Eve).
    /// `attivo` è il cliente aperto: vale quando la frase non ne nomina un altro.
    static func interpreta(_ frase: String, clienti: [ClienteNoto], attivo: String?, oggi: Date = Date()) -> ComandoEve? {
        let t = pulisci(frase)
        guard !t.isEmpty else { return nil }
        let nominati = clientiNominati(t, clienti)
        if nominati.count > 1 {
            // Più clienti nella frase: per una domanda va bene (risponde Eve), per un'azione no
            guard comincia(t, verbiAzione) else { return nil }
            return .chiedi("Ho sentito più clienti: \(nominati.map(\.nome).joined(separator: ", ")). Di quale parliamo?")
        }
        let nominato = nominati.first?.id
        let cliente = nominato ?? attivo

        // Promemoria e note prima degli appuntamenti: «ricordami di fissare un incontro» è un promemoria
        if let c = documento(t, cliente: nominato) { return c }
        if let c = attivita(t, frase: frase, cliente: cliente, oggi: oggi) { return c }
        if let c = nota(t, frase: frase, cliente: cliente) { return c }
        if let c = appuntamento(t, cliente: cliente, oggi: oggi) { return c }
        if let c = agenda(t, oggi: oggi) { return c }
        if let c = apri(t, nominato: nominato) { return c }
        return nil
    }

    // MARK: - Le regole

    private static let verbiAzione = ["prepar", "fa", "fammi", "crea", "genera", "apri", "mostra", "fissa", "metti", "prenota", "organizza",
                                      "programma", "segna", "ricorda", "aggiungi", "annota", "prendi", "scrivi", "passa", "vai", "porta"]

    private static func documento(_ t: String, cliente: String?) -> ComandoEve? {
        guard let _ = DateItaliane.cerca(#"^(?:mi )?(?:prepar\w*|fa(?:mmi|i)|crea(?:mi)?|genera(?:mi)?|apri(?:mi)?|mostra(?:mi)?|stampa(?:mi)?|tira(?:mi)? fuori|fammi vedere)\b"#, t),
              DateItaliane.cerca(#"\b(report|prospett[oi]|document[oi]|fascicol[oi]|presentazione|relazione)\b"#, t) != nil else { return nil }
        let dettaglio = DateItaliane.cerca(#"\bprospett[oi]\b|\bdettagli"#, t) != nil
        let report = !dettaglio
        let tipi: [(String, SceltaProspetto)] = [
            (#"fascicol"#, .fascicolo),
            (#"riesame|revisione annuale"#, .riesame),
            (#"resistenz|stress|croll|crisi"#, .resistenza(report: report)),
            (#"\bcost|commission"#, .costi(report: report)),
            (#"succession|\beredi|passaggio generazional|testament"#, .successione(report: report)),
            (#"pension|previdenz"#, .previdenza(report: report)),
            (#"protezion|copertur|assicurativ"#, .protezione(report: report)),
            (#"liquidit|in scadenza|scadenz"#, .liquidita(report: report)),
            (#"check"#, .checkUp(report: report)),
            (#"patrimonio"#, .patrimonio(report: report)),
            (#"resoconto|andament|posizioni in essere|rendiment"#, .resoconto(report: report)),
            (#"portafoglio"#, .portafoglio),
        ]
        guard let scelta = tipi.first(where: { DateItaliane.cerca($0.0, t) != nil })?.1 else {
            return .chiedi("Quale documento ti preparo? Per esempio il patrimonio nel tempo, la prova di resistenza, i costi, il passaggio generazionale, il piano pensione o il fascicolo dell'incontro.")
        }
        return .documento(scelta, cliente: cliente)
    }

    private static func appuntamento(_ t: String, cliente: String?, oggi: Date) -> ComandoEve? {
        guard DateItaliane.cerca(#"^(?:mi )?(?:fiss\w*|mett\w*|prenot\w*|organizz\w*|programm\w*|segn\w*|aggiung\w*|crea\w*|pianific\w*)\b"#, t) != nil,
              case let (_, g)? = DateItaliane.cerca(#"\b(appuntament[oi]|incontr[oi]|riunione|telefonat[ae]|chiamat[ae]|call|videochiamat[ae]|revisione|riesame|firma)\b"#, t)
        else { return nil }
        let quando = DateItaliane.trova(t, oggi: oggi)
        var b = Appuntamento.Bozza(cliente: cliente, giorno: quando.giorno, ora: quando.ora?.ore, minuti: quando.ora?.minuti ?? 0, titolo: "")
        switch g[1] {
        case let p where p.hasPrefix("telefonat") || p.hasPrefix("chiamat") || p == "call": b.tipo = .telefonata
        case let p where p.hasPrefix("videochiamat"): b.tipo = .telefonata
        case "revisione", "riesame": b.tipo = .revisione
        case "firma": b.tipo = .firma
        default: b.tipo = DateItaliane.cerca(#"\bpropost"#, t) != nil ? .proposta : .altro
        }
        if cliente == nil { return .chiedi("Con quale cliente fisso l'appuntamento?") }
        return .appuntamento(b)
    }

    private static func attivita(_ t: String, frase: String, cliente: String?, oggi: Date) -> ComandoEve? {
        guard case let (m, _)? = DateItaliane.cerca(#"^(?:ricordami|ricorda(?:ti)?|promemoria|segna(?:mi|ti)? (?:di|che)|aggiungi (?:un'|una )?attivit[aà]|crea (?:un'|una )?attivit[aà]|metti tra le cose da fare|da fare)\b(?:\s*(?:di|che|:))?"#, t)
        else { return nil }
        let resto = String((t as NSString).substring(from: m.location + m.length))
        let quando = DateItaliane.trova(resto, oggi: oggi)
        var titolo = DateItaliane.togli(quando, da: resto)
        titolo = titolo.replacingOccurrences(of: #"^(?:di|che|:)\s+"#, with: "", options: .regularExpression)
        guard !titolo.isEmpty else { return .chiedi("Cosa ti devo ricordare?") }
        titolo = maiuscola(conNomi(titolo, frase: frase))
        let scadenza = quando.giorno ?? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: oggi)) ?? oggi
        guard let cliente else { return .chiedi("Per quale cliente lo segno?") }
        return .attivita(cliente: cliente, titolo: titolo, scadenza: scadenza)
    }

    private static func nota(_ t: String, frase: String, cliente: String?) -> ComandoEve? {
        guard case let (m, _)? = DateItaliane.cerca(#"^(?:prendi nota|annota(?:ti)?|scrivi (?:una |in )?nota|aggiungi (?:una |alla )?nota|metti (?:in|una) nota|segna(?:ti)? (?:nelle|tra le) note)\b(?:\s*(?:che|di|:|,))?"#, t)
        else { return nil }
        var testo = String((t as NSString).substring(from: m.location + m.length)).trimmingCharacters(in: .whitespaces)
        testo = testo.replacingOccurrences(of: #"^(?:che|:|,)\s*"#, with: "", options: .regularExpression)
        guard !testo.isEmpty else { return .chiedi("Cosa scrivo nella nota?") }
        guard let cliente else { return .chiedi("Per quale cliente prendo nota?") }
        return .nota(cliente: cliente, testo: maiuscola(conNomi(testo, frase: frase)))
    }

    private static func agenda(_ t: String, oggi: Date) -> ComandoEve? {
        guard DateItaliane.cerca(#"\b(?:cosa|che cosa|che) (?:ho|c'è|c'e|abbiamo)\b|\b(?:appuntamenti|impegni|incontri) (?:di|per|ho)\b|\bcom'è (?:la )?(?:giornata|agenda)\b|\bleggimi (?:l')?agenda\b|\bla mia (?:giornata|agenda)\b"#, t) != nil,
              DateItaliane.cerca(#"\b(?:oggi|domani|dopodomani|agenda|giornata|luned[iì]|marted[iì]|mercoled[iì]|gioved[iì]|venerd[iì]|sabato|domenica)\b"#, t) != nil
        else { return nil }
        let giorno = DateItaliane.trova(t, oggi: oggi).giorno ?? Calendar.current.startOfDay(for: oggi)
        return .agenda(giorno)
    }

    private static func apri(_ t: String, nominato: String?) -> ComandoEve? {
        guard case let (m, _)? = DateItaliane.cerca(#"^(?:apri(?:mi)?|mostra(?:mi)?|fammi vedere|vai|andiamo|portami|passa|passiamo|torna|torniamo|seleziona|parliamo)\b(?:\s+(?:alla|alle|allo|agli|al|ai|a|in|sulla|sul|su|nella|nelle|negli|nel|della|del|di)\b)?\s*(?:l'|la |il |le |i |gli |lo )?"#, t)
        else { return nil }
        let resto = String((t as NSString).substring(from: m.location + m.length))
        if DateItaliane.cerca(#"^scrivania\b"#, resto) != nil { return .scrivania }
        let app: [(String, AppPrisma)] = [
            (#"^client[ei]\b(?! \w)"#, .clienti), (#"^posizion"#, .posizioni), (#"^analisi"#, .analisi360), (#"^incontr"#, .incontri),
            (#"^obiettiv"#, .obiettivi), (#"^confront"#, .confronti), (#"^prodott"#, .prodotti), (#"^simula"#, .simulazioni),
            (#"^(?:agenda|calendario)"#, .agenda), (#"^(?:attivit|cose da fare)"#, .attivita), (#"^(?:note|taccuino)\b"#, .note),
            (#"^document"#, .documenti), (#"^(?:prospett|report|presentazion)"#, .presentazioni), (#"^ricerca"#, .ricerca),
            (#"^impostazion"#, .impostazioni), (#"^eve\b"#, .eve),
        ]
        if let a = app.first(where: { DateItaliane.cerca($0.0, resto) != nil })?.1, nominato == nil { return .apri(a) }
        // «Apri Marco Bianchi», «passa a Giulia», «apri il dossier di Laura»
        if let nominato { return .cliente(nominato) }
        return nil
    }

    // MARK: - Aiuti

    /// La frase in minuscolo, senza saluti e cortesie: «Ok Eve, per favore mi prepari…» → «mi prepari…».
    static func pulisci(_ frase: String) -> String {
        var t = frase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!?")))
        t = t.replacingOccurrences(of: "’", with: "'")
        var prima = ""
        while prima != t {
            prima = t
            t = t.replacingOccurrences(of: #"^(?:ok|okay|ehi|ehy|eve|senti|allora|bene|va bene|dai|ciao|per favore|perfavore|per cortesia|ti prego|adesso|ora|poi|e poi|anche|grazie)\b[,\s]*"#,
                                       with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"^(?:puoi|potresti|riesci a|vorrei che|ti chiedo di|ho bisogno che|me lo|me la|me li|ce l'hai)\s+"#,
                                       with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"^(?:mi )?(?:(?:prepari|prepareresti)\b)"#, with: "preparami", options: .regularExpression)
            t = t.replacingOccurrences(of: #"^(?:mi )?(?:(?:apri|apriresti)\b)"#, with: "apri", options: .regularExpression)
            t = t.replacingOccurrences(of: #"[,\s]*(?:per favore|grazie|per cortesia)$"#, with: "", options: .regularExpression)
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    private static func comincia(_ t: String, _ verbi: [String]) -> Bool {
        verbi.contains { t.hasPrefix($0) || t.hasPrefix("mi " + $0) }
    }

    /// I clienti nominati nella frase: per nome e cognome, per cognome o per nome (quando è unico).
    static func clientiNominati(_ t: String, _ clienti: [ClienteNoto]) -> [ClienteNoto] {
        let piega = { (s: String) in s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT")) }
        let frase = piega(t)
        func presente(_ parola: String) -> Bool {
            let p = piega(parola)
            guard p.count >= 3 else { return false }
            return DateItaliane.cerca("\\b" + NSRegularExpression.escapedPattern(for: p) + "\\b", frase) != nil
        }
        let completi = clienti.filter { c in
            let parole = c.nome.split(separator: " ").map(String.init)
            return parole.count > 1 && parole.allSatisfy(presente)
        }
        if !completi.isEmpty { return completi }
        // Il solo cognome vale dopo «con», «per», «di»…: «i conti correnti» non è Andrea Conti
        func cognome(_ parola: String) -> Bool {
            let p = piega(parola)
            guard p.count >= 3 else { return false }
            return DateItaliane.cerca(#"\b(?:con|per|a|di|da|signor|signora|sig|dottor|dottore|dott|dottoressa|cliente|famiglia) "#
                                      + NSRegularExpression.escapedPattern(for: p) + "\\b", frase) != nil
        }
        let cognomi = clienti.filter { c in
            let parole = c.nome.split(separator: " ").map(String.init)
            return parole.count > 1 && parole.dropFirst().contains(where: cognome)
        }
        if !cognomi.isEmpty { return cognomi }
        return clienti.filter { c in c.nome.split(separator: " ").first.map { presente(String($0)) } ?? false }
    }

    /// Rimette le maiuscole dei nomi propri come nella frase originale: «chiamare laura» → «chiamare Laura».
    private static func conNomi(_ testo: String, frase: String) -> String {
        var r = testo
        for parola in frase.split(whereSeparator: { !$0.isLetter && $0 != "'" }) where parola.first?.isUppercase == true {
            let minuscola = parola.lowercased()
            r = r.replacingOccurrences(of: "\\b" + NSRegularExpression.escapedPattern(for: minuscola) + "\\b", with: String(parola), options: .regularExpression)
        }
        return r
    }

    static func maiuscola(_ s: String) -> String {
        guard let p = s.first else { return s }
        return p.uppercased() + s.dropFirst()
    }
}
