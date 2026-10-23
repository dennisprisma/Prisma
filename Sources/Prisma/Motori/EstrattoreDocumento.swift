import Foundation

/// Cerca i dati nel testo dei documenti: KID (PRIIPs), polizze, estratti conto.
///
/// Le regole riconoscono le formule standard dei documenti italiani ("classe di rischio 3 su 7",
/// "periodo di detenzione raccomandato: 10 anni", "costi correnti 1,20%"…) e riportano sempre
/// la pagina e la riga da cui viene il valore. Il modello Apple, se c'è, completa i campi mancanti.
/// Nessun dato entra nel dossier senza la conferma del consulente.
enum EstrattoreDocumento {

    // MARK: - Regole

    /// Un modello: il primo gruppo catturato è il valore. Con `ultimoPercento` il gruppo è un tratto
    /// di tabella e vale l'ultima percentuale (la colonna del periodo raccomandato, nei KID).
    private struct Regola {
        let campo: CampoDocumento
        let schema: String
        var ultimoPercento = false
    }

    private static let schemaNumero = #"(-?\d+\.\d{1,2}(?=\s*%)|-?\d{1,3}(?:\.\d{3})*(?:,\d+)?|-?\d+(?:,\d+)?)"#
    private static let schemaImporto = #"(\d{1,3}(?:\.\d{3})+(?:,\d{2})?|\d+(?:,\d{2})?)(?![/\d]|[.,]\d|\s*%)"#
    /// Un importo con i separatori delle migliaia ("25.430,12"): non si confonde con anni o percentuali.
    private static let schemaImportoMigliaia = #"(\d{1,3}(?:\.\d{3})+(?:,\d{2})?)(?![/\d]|[.,]\d|\s*%)"#
    private static let mesi = "gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre"
    private static let schemaData = #"(\d{1,2}[/.-]\d{1,2}[/.-]\d{4}|\d{1,2}°?\s+(?:"# + mesi + #")\s+\d{4})"#
    /// Testo tra un'etichetta e il suo valore, date comprese ("Controvalore al 30/09/2026: € …").
    private static let fraEtichettaEValore = #"(?:[^\d\n]|\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{1,2}\s*ann[oi]){0,60}?"#
    /// Qualificazioni del premio: "Premio annuo lordo", "Premio unico di perfezionamento"…
    private static let qualificaPremio = #"(?:\s+(?:annuo|annuale|mensile|trimestrale|semestrale|unico|ricorrente|lordo|netto|complessivo|di perfezionamento|rateo|alla firma))*"#

    private static let regole: [Regola] = [
        Regola(campo: .nomeProdotto, schema: #"(?:nome del prodotto|denominazione(?: del prodotto)?|prodotto)\s*[:\-–]\s*([^\n]{3,90})"#),
        Regola(campo: .emittente, schema: #"(?:ideatore del priip|nome dell'ideatore(?: del priip)?|ideatore|compagnia|impresa di assicurazione|emittente|società di gestione)\s*[:\-–]\s*([^\n]{3,80})"#),
        Regola(campo: .tipologia, schema: #"(?:tipo(?: di prodotto)?|tipologia)\s*[:\-–]\s*([^\n]{3,90})"#),
        Regola(campo: .sri, schema: #"(?:classe(?: di rischio)?|livello|categoria(?: di rischio)?|indicatore[^\n]{0,40}rischio[^\n]{0,60}?)\D{0,20}([1-7])\s*(?:su|di)\s*(?:una scala (?:da 1 a )?)?7"#),
        Regola(campo: .sri, schema: #"([1-7])\s*su\s*7[^\n]{0,40}(?:classe|rischio)"#),
        Regola(campo: .periodoDetenzione, schema: #"periodo di detenzione raccomandato[^\d\n]{0,50}(\d{1,2})\s*ann[oi]"#),
        Regola(campo: .periodoDetenzione, schema: #"periodo di detenzione raccomandato[\s\S]{0,40}?\n[^\d\n]{0,20}(\d{1,2})\s*ann[oi]"#),
        Regola(campo: .costoIngresso, schema: #"costi di (?:ingresso|sottoscrizione)[^\n%]{0,80}?\#(schemaNumero)\s*%"#),
        Regola(campo: .costoIngresso, schema: #"costi di (?:ingresso|sottoscrizione)[^\n]{0,60}?(non (?:addebitiamo|applichiamo|sono previst|è previst|vengono applicat))"#),
        Regola(campo: .costoUscita, schema: #"costi di (?:uscita|rimborso)[^\n%]{0,80}?\#(schemaNumero)\s*%"#),
        Regola(campo: .costoUscita, schema: #"costi di (?:uscita|rimborso)[^\n]{0,60}?(non (?:addebitiamo|applichiamo|sono previst|è previst|vengono applicat))"#),
        Regola(campo: .costoAnnuo, schema: #"(?:costi correnti|commissioni di gestione e altri costi amministrativi o di esercizio|costi ricorrenti)[^\n%]{0,90}?\#(schemaNumero)\s*%"#),
        // Nei KID la riga ha due o tre colonne (uscita dopo 1 anno … periodo raccomandato): vale l'ultima
        Regola(campo: .incidenzaCosti, schema: #"incidenza annuale dei costi(?:\s*\(\*+\))?([^\n]{0,120})"#, ultimoPercento: true),
        Regola(campo: .incidenzaCosti, schema: #"incidenza (?:annuale )?dei costi[^\n%]{0,80}?\#(schemaNumero)\s*%"#),
        Regola(campo: .rendimentoModerato, schema: #"scenario moderato[\s\S]{0,260}?rendimento medio[^\n]{0,40}?(?:annuo|per ciascun anno|annuale)?([^\n]{0,80})"#, ultimoPercento: true),
        Regola(campo: .numeroContratto, schema: #"(?:numero (?:di |della )?(?:polizza|contratto)|polizza|contratto)\s*(?:n\.?|numero|nr\.?)?\s*[:°]?\s*((?=[A-Z0-9/\-]*\d)[A-Z0-9][A-Z0-9/\-]{3,24})"#),
        Regola(campo: .contraente, schema: #"contraente\s*[:\-–]\s*([^\n]{3,60})"#),
        Regola(campo: .assicurato, schema: #"assicurato\s*[:\-–]\s*([^\n]{3,60})"#),
        Regola(campo: .beneficiari, schema: #"beneficiari?(?: caso morte| designati)?\s*[:\-–]\s*([^\n]{3,90})"#),
        Regola(campo: .decorrenza, schema: #"(?:decorrenza|data di effetto|data di sottoscrizione|in vigore dal)(?:[^\d\n]|\bore\s*\d{1,2}\b){0,30}?\#(schemaData)"#),
        Regola(campo: .scadenza, schema: #"(?:scadenza|data di scadenza)(?:[^\d\n]|\bore\s*\d{1,2}\b){0,30}?\#(schemaData)"#),
        Regola(campo: .premio, schema: #"premio\#(qualificaPremio)\s*[:\-–]?\s*(?:€|eur(?:o)?)?\s*\#(schemaImporto)"#),
        Regola(campo: .capitaleAssicurato, schema: #"(?:capitale assicurato|somma assicurata|capitale caso morte)[^\d\n€]{0,30}?(?:€|eur(?:o)?)?\s*\#(schemaImporto)"#),
        // Il controvalore vuole il simbolo della valuta o le migliaia: "pari al 95% del capitale" non è un importo
        Regola(campo: .controvalore, schema: #"(?:controvalore|valore di riscatto|valore della posizione|valore complessivo|totale (?:del )?portafoglio)\#(fraEtichettaEValore)(?:€|eur(?:o)?)\s*\#(schemaImporto)"#),
        Regola(campo: .controvalore, schema: #"(?:controvalore|valore di riscatto|valore della posizione|valore complessivo|totale (?:del )?portafoglio)\#(fraEtichettaEValore)\#(schemaImportoMigliaia)"#),
    ]

    /// Applica le regole pagina per pagina; per ogni campo tiene la prima occorrenza.
    static func conRegole(_ pagine: [String]) -> [CampoEstratto] {
        var trovati: [CampoDocumento: CampoEstratto] = [:]
        for (n, pagina) in pagine.enumerated() {
            // Il segno meno tipografico (−) dei PDF diventa il trattino: "−3,2%" resta negativo
            let testo = pagina.replacingOccurrences(of: "\u{2212}", with: "-")
            for r in regole where trovati[r.campo] == nil {
                guard let regex = try? NSRegularExpression(pattern: r.schema, options: [.caseInsensitive]) else { continue }
                let intervallo = NSRange(testo.startIndex..., in: testo)
                guard let m = regex.firstMatch(in: testo, range: intervallo), m.numberOfRanges > 1,
                      let rv = Range(m.range(at: 1), in: testo), let rt = Range(m.range, in: testo) else { continue }
                let grezzo = r.ultimoPercento ? (ultimaPercentuale(String(testo[rv])) ?? "") : String(testo[rv])
                let valore = pulisci(grezzo, campo: r.campo)
                guard !valore.isEmpty else { continue }
                let riga = String(testo[rt]).replacingOccurrences(of: "\n", with: " ")
                trovati[r.campo] = CampoEstratto(chiave: r.campo, valore: valore, pagina: n + 1, estratto: String(riga.prefix(160)))
            }
        }
        return CampoDocumento.allCases.compactMap { trovati[$0] }
    }

    /// L'ultima percentuale di un tratto di testo ("5,2% | 2,1%" → "2,1"), prima di eventuali note.
    private static func ultimaPercentuale(_ s: String) -> String? {
        var tratto = s
        for fine in ["(*)", "Dimostra", "dimostra", "Composizione", "Ciò significa"] {
            if let r = tratto.range(of: fine) { tratto = String(tratto[..<r.lowerBound]) }
        }
        guard let re = try? NSRegularExpression(pattern: schemaNumero + #"\s*%"#) else { return nil }
        let trovate = re.matches(in: tratto, range: NSRange(tratto.startIndex..., in: tratto))
        guard let ultima = trovate.last, let r = Range(ultima.range(at: 1), in: tratto) else { return nil }
        return String(tratto[r])
    }

    private static func pulisci(_ s: String, campo: CampoDocumento) -> String {
        // "Non addebitiamo una commissione di uscita" → 0
        if campo.unita == "%", s.lowercased().hasPrefix("non ") { return "0" }
        let testuale = [.nomeProdotto, .emittente, .tipologia, .contraente, .assicurato, .beneficiari].contains(campo)
        // Nei nomi il punto finale fa parte del testo ("S.p.A.")
        var v = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: testuale ? ",;:" : ".,;:")))
        if campo == .nomeProdotto || campo == .emittente || campo == .contraente || campo == .assicurato {
            // Si ferma prima di eventuali altre etichette sulla stessa riga
            for separatore in ["  ", " - ", " – ", "Sito", "www", "Per ulteriori", "ISIN"] {
                if let r = v.range(of: separatore) { v = String(v[..<r.lowerBound]) }
            }
        }
        return v.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Modello Apple

    static var istruzioniModello: String {
        IstruzioniEve.testo("documenti") ?? """
        Leggi il testo di una pagina di un documento finanziario o assicurativo italiano e rispondi solo con righe nel formato:
        CAMPO|valore
        Campi possibili: \(CampoDocumento.allCases.map(\.rawValue).joined(separator: ", ")).
        Percentuali e importi solo come numeri con la virgola decimale (per esempio 1,25). Date nel formato gg/mm/aaaa.
        Usa solo ciò che è scritto nella pagina, non inventare.
        """
    }

    /// Converte la risposta del modello per una pagina, scartando le righe non valide.
    static func daRisposta(_ testo: String, pagina: Int) -> [CampoEstratto] {
        testo.components(separatedBy: .newlines).compactMap { riga in
            let parti = riga.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parti.count == 2, let campo = CampoDocumento(rawValue: parti[0]), !parti[1].isEmpty, parti[1].count < 120 else { return nil }
            var valore = parti[1]
            switch campo {
            case .sri:
                // "3/7", "3 su 7" → "3"
                guard let n = Int(valore.prefix(1)), (1...7).contains(n) else { return nil }
                valore = "\(n)"
            case .periodoDetenzione:
                // "5 anni" → "5"
                let cifre = valore.prefix { $0.isNumber }
                guard !cifre.isEmpty else { return nil }
                valore = String(cifre)
            case .costoIngresso, .costoUscita, .costoAnnuo, .incidenzaCosti, .rendimentoModerato, .premio, .capitaleAssicurato, .controvalore:
                valore = valore.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "€", with: "")
                    .replacingOccurrences(of: "EUR", with: "").trimmingCharacters(in: .whitespaces)
                guard numero(valore) != nil else { return nil }
            case .decorrenza, .scadenza:
                // Una data che non esiste non entra nella tabella (e poi nel dossier)
                guard data(valore) != nil else { return nil }
            default:
                break
            }
            return CampoEstratto(chiave: campo, valore: valore, pagina: pagina, estratto: "", origine: "Modello Apple")
        }
    }

    /// Le regole hanno la precedenza; il modello completa i campi che mancano.
    static func unisci(_ regole: [CampoEstratto], _ modello: [CampoEstratto]) -> [CampoEstratto] {
        var perCampo: [CampoDocumento: CampoEstratto] = [:]
        for c in modello where perCampo[c.chiave] == nil { perCampo[c.chiave] = c }
        for c in regole { perCampo[c.chiave] = c }
        return CampoDocumento.allCases.compactMap { perCampo[$0] }
    }

    // MARK: - Dai campi ai dati di Prisma

    /// "1,25" → 1.25; "1.250,50" → 1250.5
    static func numero(_ s: String?) -> Double? {
        guard let s else { return nil }
        // "1200.50" o "1.20" (punto decimale, senza virgola): non sono migliaia
        let compatto = s.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: "%", with: "").replacingOccurrences(of: " ", with: "")
        if !compatto.contains(","), let r = compatto.range(of: #"^-?\d+\.\d{1,2}$"#, options: .regularExpression), r == compatto.startIndex..<compatto.endIndex {
            return Double(compatto).flatMap { $0.isFinite ? $0 : nil }
        }
        // Con punto e virgola insieme, l'ultimo dei due separa i decimali: "1.250,50" ma anche "1,250.50"
        if let p = compatto.lastIndex(of: "."), let v = compatto.lastIndex(of: ","), p > v {
            return Double(compatto.replacingOccurrences(of: ",", with: "")).flatMap { $0.isFinite ? $0 : nil }
        }
        let pulito = s.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        // "nan", "inf", "1e999" non sono cifre di un documento
        return Double(pulito).flatMap { $0.isFinite ? $0 : nil }
    }

    static func data(_ s: String?) -> Date? {
        guard let s else { return nil }
        // "1° dicembre 2025"
        let parole = s.lowercased().replacingOccurrences(of: "°", with: "").split(separator: " ").map(String.init)
        if parole.count == 3, let g = Int(parole[0]), let a = Int(parole[2]),
           let m = mesi.components(separatedBy: "|").firstIndex(of: parole[1]) {
            return dataValida(anno: a, mese: m + 1, giorno: g)
        }
        let parti = s.split(whereSeparator: { "/.-".contains($0) }).compactMap { Int($0) }
        guard parti.count == 3 else { return nil }
        // "2025-12-01" (anno prima) oppure "01/12/2025"
        if parti[0] > 31 { return dataValida(anno: parti[0], mese: parti[1], giorno: parti[2]) }
        return dataValida(anno: parti[2], mese: parti[1], giorno: parti[0])
    }

    /// Solo date vere: "31/06" non diventa il primo luglio, l'anno resta in un intervallo sensato.
    private static func dataValida(anno: Int, mese: Int, giorno: Int) -> Date? {
        guard (1900...2200).contains(anno), (1...12).contains(mese), (1...31).contains(giorno) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        guard let d = cal.date(from: DateComponents(year: anno, month: mese, day: giorno)),
              cal.component(.day, from: d) == giorno, cal.component(.month, from: d) == mese else { return nil }
        return d
    }

    /// Tipo di documento suggerito dal testo.
    static func tipoProbabile(_ pagine: [String]) -> Documento.Tipo {
        let t = pagine.prefix(2).joined(separator: " ").lowercased()
        if t.contains("documento contenente le informazioni chiave") || t.contains("key information document") || t.contains("priip") { return .kid }
        if t.contains("estratto conto") || t.contains("rendiconto") { return .estrattoConto }
        if t.contains("proposta") && t.contains("assicurazione") { return .proposta }
        if t.contains("polizza") || t.contains("contraente") { return .polizza }
        return .altro
    }
}
