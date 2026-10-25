import Foundation

/// Giorni e orari detti a voce o scritti in italiano: «domani alle 15», «giovedì prossimo alle tre e mezza»,
/// «il 3 novembre», «tra due settimane». Restituisce anche dove stanno nella frase, per toglierli dal titolo.
enum DateItaliane {
    struct Trovato {
        var giorno: Date?
        var ora: (ore: Int, minuti: Int)?
        /// Le parti della frase che indicano il quando (nel testo in minuscolo).
        var parti: [NSRange] = []

        /// Il giorno con l'ora (nil se manca il giorno).
        func data(_ cal: Calendar = .current) -> Date? {
            guard let giorno else { return nil }
            guard let ora else { return cal.startOfDay(for: giorno) }
            return cal.date(bySettingHour: ora.ore, minute: ora.minuti, second: 0, of: giorno)
        }
    }

    static let mesi = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"]
    /// Numeri in lettere, come li scrive la dettatura quando non usa le cifre.
    static let numeri: [String: Int] = [
        "un": 1, "una": 1, "uno": 1, "due": 2, "tre": 3, "quattro": 4, "cinque": 5, "sei": 6, "sette": 7, "otto": 8, "nove": 9,
        "dieci": 10, "undici": 11, "dodici": 12, "tredici": 13, "quattordici": 14, "quindici": 15, "sedici": 16,
        "diciassette": 17, "diciotto": 18, "diciannove": 19, "venti": 20, "ventuno": 21, "ventidue": 22, "ventitré": 23, "ventitre": 23,
        "trenta": 30, "quaranta": 40, "quarantacinque": 45, "cinquanta": 50,
    ]
    private static let numeroSemplice = "\\d{1,2}|" + numeri.keys.sorted { $0.count > $1.count }.joined(separator: "|")
    private static let parolaNumero = "(" + numeroSemplice + ")"

    static func numero(_ s: String) -> Int? { Int(s) ?? numeri[s] }

    static func trova(_ frase: String, oggi: Date = Date(), cal: Calendar = .current) -> Trovato {
        let t = frase.lowercased()
        var r = Trovato()
        let base = cal.startOfDay(for: oggi)
        func giorni(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: base) ?? base }

        // Il giorno: la prima indicazione che si trova, nell'ordine dalla più precisa
        if case let (m, g)? = cerca(#"\b(?:il |l'|per il |entro il )?(\d{1,2})(?: |/|-)(\d{1,2}|"# + mesi.joined(separator: "|") + #")(?:(?: |/|-)(\d{4}))?\b"#, t),
           let giorno = Int(g[1]), (1...31).contains(giorno) {
            let mese = Int(g[2]) ?? ((mesi.firstIndex(of: g[2]) ?? -1) + 1)
            if (1...12).contains(mese) {
                var c = DateComponents(month: mese, day: giorno)
                if let anno = Int(g[3]) {
                    c.year = anno
                    r.giorno = cal.date(from: c)
                } else {
                    // Senza anno: la prossima volta che arriva quel giorno
                    r.giorno = cal.nextDate(after: giorni(-1), matching: c, matchingPolicy: .nextTime)
                }
                if r.giorno != nil { r.parti.append(m) }
            }
        }
        if r.giorno == nil, case let (m, _)? = cerca(#"\b(?:per |entro )?dopodomani\b"#, t) {
            r.giorno = giorni(2); r.parti.append(m)
        }
        if r.giorno == nil, case let (m, _)? = cerca(#"\b(?:per |entro )?domani(?: mattina| pomeriggio| sera)?\b"#, t) {
            r.giorno = giorni(1); r.parti.append(m)
        }
        if r.giorno == nil, case let (m, _)? = cerca(#"\b(?:per |entro )?(?:oggi|stamattina|stasera|stanotte|oggi pomeriggio)\b"#, t) {
            r.giorno = giorni(0); r.parti.append(m)
        }
        if r.giorno == nil, case let (m, g)? = cerca(#"\b(?:per |entro )?(?:(?:il |la )?prossim[oa] )?(luned[iì]|marted[iì]|mercoled[iì]|gioved[iì]|venerd[iì]|sabato|domenica)(?: prossim[oa])?\b"#, t) {
            let nomi = ["domenica", "luned", "marted", "mercoled", "gioved", "venerd", "sabato"]
            if let indice = nomi.firstIndex(where: { g[1].hasPrefix($0) }) {
                // Il prossimo giorno con quel nome (se è oggi, quello della settimana prossima)
                let oggiIndice = cal.component(.weekday, from: base) - 1
                var avanti = (indice - oggiIndice + 7) % 7
                if avanti == 0 { avanti = 7 }
                r.giorno = giorni(avanti); r.parti.append(m)
            }
        }
        if r.giorno == nil, case let (m, g)? = cerca(#"\b(?:tra|fra) "# + parolaNumero + #" (giorn[oi]|settiman[ae]|mes[ei])\b"#, t),
           let n = numero(g[1]) {
            let unita: Calendar.Component = g[2].hasPrefix("giorn") ? .day : (g[2].hasPrefix("settiman") ? .weekOfYear : .month)
            r.giorno = cal.date(byAdding: unita, value: n, to: base); r.parti.append(m)
        }
        if r.giorno == nil, case let (m, _)? = cerca(#"\b(?:tra|fra) (?:una|un) (settimana|mese)\b|\b(?:la )?(?:prossima settimana|settimana prossima)\b"#, t) {
            let s = (t as NSString).substring(with: m)
            r.giorno = s.contains("mese") ? cal.date(byAdding: .month, value: 1, to: base) : giorni(7)
            r.parti.append(m)
        }

        // L'ora
        if case let (m, _)? = cerca(#"\b(?:a |per |verso )?mezzogiorno\b"#, t) {
            r.ora = (12, 0); r.parti.append(m)
        } else if case let (m, g)? = cerca(#"\b(?:alle|all'|per le|verso le|dalle|ore) ?"# + parolaNumero
                                    + #"(?:(?:[:\.](\d{2}))|(?: e (mezza|mezzo|un quarto|tre quarti|"# + numeroSemplice + #")))?"#
                                    + #"(?: (?:del |di |nel )?(mattina|mattino|pomeriggio|sera))?\b"#, t),
                  var ore = numero(g[1]), (0...23).contains(ore) {
            var minuti = Int(g[2]) ?? 0
            switch g[3] {
            case "mezza", "mezzo": minuti = 30
            case "un quarto": minuti = 15
            case "tre quarti": minuti = 45
            case "": break
            default: minuti = numero(g[3]) ?? minuti
            }
            let momento = g.count > 4 ? g[4] : ""
            // «alle tre» per un appuntamento è il pomeriggio; «alle 9 di sera» è sera
            if ore < 12, momento == "pomeriggio" || momento == "sera" || (momento.isEmpty && ore >= 1 && ore <= 7) { ore += 12 }
            if (0...59).contains(minuti) {
                r.ora = (ore, minuti); r.parti.append(m)
            }
        }
        if let ora = r.ora, r.giorno == nil {
            // Solo l'ora: oggi, se è ancora da venire, altrimenti domani
            let oggiAllOra = cal.date(bySettingHour: ora.ore, minute: ora.minuti, second: 0, of: base) ?? base
            r.giorno = oggiAllOra > oggi ? giorni(0) : giorni(1)
        }
        return r
    }

    /// Toglie dalla frase le parti che indicano il quando: «chiamare Laura venerdì alle 10» → «chiamare Laura».
    static func togli(_ trovato: Trovato, da frase: String) -> String {
        let ns = NSMutableString(string: frase)
        for p in trovato.parti.sorted(by: { $0.location > $1.location }) where p.location + p.length <= ns.length {
            ns.replaceCharacters(in: p, with: " ")
        }
        return (ns as String).replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",.;:")))
    }

    /// La prima corrispondenza e i suoi gruppi ("" per un gruppo vuoto).
    static func cerca(_ schema: String, _ testo: String) -> (NSRange, [String])? {
        guard let re = try? NSRegularExpression(pattern: schema, options: [.caseInsensitive]),
              let m = re.firstMatch(in: testo, range: NSRange(location: 0, length: (testo as NSString).length)) else { return nil }
        let ns = testo as NSString
        let gruppi = (0..<m.numberOfRanges).map { i -> String in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
        return (m.range, gruppi)
    }

    /// «giovedì 30 ottobre alle 15:00», per le risposte di Eve.
    static func descrivi(_ d: Date, conOra: Bool, oggi: Date = Date(), cal: Calendar = .current) -> String {
        let giorno: String
        if cal.isDate(d, inSameDayAs: oggi) {
            giorno = "oggi"
        } else if let domani = cal.date(byAdding: .day, value: 1, to: oggi), cal.isDate(d, inSameDayAs: domani) {
            giorno = "domani"
        } else {
            giorno = Formati.dataLunga.string(from: d)
        }
        return conOra ? "\(giorno) alle \(Formati.ora.string(from: d))" : giorno
    }
}
