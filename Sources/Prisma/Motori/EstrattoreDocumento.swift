import Foundation

/// Cerca i dati nel testo dei documenti: KID (PRIIPs), polizze, estratti conto.
///
/// Le regole riconoscono le formule standard dei documenti italiani ("classe di rischio 3 su 7",
/// "periodo di detenzione raccomandato: 10 anni", "costi correnti 1,20%"…) e riportano sempre
/// la pagina e la riga da cui viene il valore. Il modello Apple, se c'è, completa i campi mancanti.
/// Nessun dato entra nel dossier senza la conferma del consulente.
enum EstrattoreDocumento {

    // MARK: - Regole

    /// Un modello: il primo gruppo catturato è il valore.
    private struct Regola {
        let campo: CampoDocumento
        let schema: String
    }

    private static let schemaNumero = #"(-?\d{1,3}(?:\.\d{3})*(?:,\d+)?|-?\d+(?:,\d+)?)"#
    private static let schemaImporto = #"(\d{1,3}(?:\.\d{3})+(?:,\d{2})?|\d+(?:,\d{2})?)"#
    private static let schemaData = #"(\d{1,2}[/.-]\d{1,2}[/.-]\d{4})"#

    private static let regole: [Regola] = [
        Regola(campo: .nomeProdotto, schema: #"(?:nome del prodotto|prodotto)\s*[:\-–]\s*([^\n]{3,90})"#),
        Regola(campo: .emittente, schema: #"(?:ideatore del priip|nome dell'ideatore|ideatore|compagnia|impresa di assicurazione|emittente|società di gestione)\s*[:\-–]\s*([^\n]{3,80})"#),
        Regola(campo: .tipologia, schema: #"(?:tipo(?: di prodotto)?|tipologia)\s*[:\-–]\s*([^\n]{3,90})"#),
        Regola(campo: .sri, schema: #"(?:classe(?: di rischio)?|indicatore[^\n]{0,40}rischio[^\n]{0,60}?)\D{0,20}([1-7])\s*su\s*(?:una scala (?:da 1 a )?)?7"#),
        Regola(campo: .sri, schema: #"([1-7])\s*su\s*7[^\n]{0,40}(?:classe|rischio)"#),
        Regola(campo: .periodoDetenzione, schema: #"periodo di detenzione raccomandato[^\d\n]{0,40}(\d{1,2})\s*anni"#),
        Regola(campo: .costoIngresso, schema: #"costi di (?:ingresso|sottoscrizione)[^\n%]{0,80}?\#(schemaNumero)\s*%"#),
        Regola(campo: .costoUscita, schema: #"costi di (?:uscita|rimborso)[^\n%]{0,80}?\#(schemaNumero)\s*%"#),
        Regola(campo: .costoAnnuo, schema: #"(?:costi correnti|commissioni di gestione e altri costi amministrativi o di esercizio|costi ricorrenti)[^\n%]{0,90}?\#(schemaNumero)\s*%"#),
        Regola(campo: .incidenzaCosti, schema: #"incidenza (?:annuale )?dei costi[^\n%]{0,80}?\#(schemaNumero)\s*%"#),
        Regola(campo: .rendimentoModerato, schema: #"scenario moderato[\s\S]{0,260}?rendimento medio[^\n%]{0,60}?\#(schemaNumero)\s*%"#),
        Regola(campo: .numeroContratto, schema: #"(?:polizza|contratto)\s*(?:n\.?|numero|nr\.?)\s*[:°]?\s*([A-Z0-9][A-Z0-9/\-]{3,24})"#),
        Regola(campo: .contraente, schema: #"contraente\s*[:\-–]\s*([^\n]{3,60})"#),
        Regola(campo: .assicurato, schema: #"assicurato\s*[:\-–]\s*([^\n]{3,60})"#),
        Regola(campo: .beneficiari, schema: #"beneficiari?\s*[:\-–]\s*([^\n]{3,90})"#),
        Regola(campo: .decorrenza, schema: #"(?:decorrenza|data di effetto|data di sottoscrizione)\s*[:\-–]?\s*\#(schemaData)"#),
        Regola(campo: .scadenza, schema: #"(?:scadenza|data di scadenza)\s*[:\-–]?\s*\#(schemaData)"#),
        Regola(campo: .premio, schema: #"premio(?: annuo| mensile| unico| ricorrente| lordo)?\s*[:\-–]?\s*(?:€|eur(?:o)?)?\s*\#(schemaImporto)"#),
        Regola(campo: .capitaleAssicurato, schema: #"(?:capitale assicurato|somma assicurata|capitale caso morte)\s*[:\-–]?\s*(?:€|eur(?:o)?)?\s*\#(schemaImporto)"#),
        Regola(campo: .controvalore, schema: #"(?:controvalore|valore di riscatto|valore della posizione)(?: al \S+)?\s*[:\-–]?\s*(?:€|eur(?:o)?)?\s*\#(schemaImporto)"#),
    ]

    /// Applica le regole pagina per pagina; per ogni campo tiene la prima occorrenza.
    static func conRegole(_ pagine: [String]) -> [CampoEstratto] {
        var trovati: [CampoDocumento: CampoEstratto] = [:]
        for (n, testo) in pagine.enumerated() {
            for r in regole where trovati[r.campo] == nil {
                guard let regex = try? NSRegularExpression(pattern: r.schema, options: [.caseInsensitive]) else { continue }
                let intervallo = NSRange(testo.startIndex..., in: testo)
                guard let m = regex.firstMatch(in: testo, range: intervallo), m.numberOfRanges > 1,
                      let rv = Range(m.range(at: 1), in: testo), let rt = Range(m.range, in: testo) else { continue }
                let valore = pulisci(String(testo[rv]), campo: r.campo)
                guard !valore.isEmpty else { continue }
                let riga = String(testo[rt]).replacingOccurrences(of: "\n", with: " ")
                trovati[r.campo] = CampoEstratto(chiave: r.campo, valore: valore, pagina: n + 1, estratto: String(riga.prefix(160)))
            }
        }
        return CampoDocumento.allCases.compactMap { trovati[$0] }
    }

    private static func pulisci(_ s: String, campo: CampoDocumento) -> String {
        var v = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;:")))
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
            if campo == .sri, !(1...7).contains(Int(parti[1].prefix(1)) ?? 0) { return nil }
            return CampoEstratto(chiave: campo, valore: parti[1], pagina: pagina, estratto: "", origine: "Modello Apple")
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
        let pulito = s.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(pulito)
    }

    static func data(_ s: String?) -> Date? {
        guard let s else { return nil }
        let parti = s.split(whereSeparator: { "/.-".contains($0) }).compactMap { Int($0) }
        guard parti.count == 3 else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: parti[2], month: parti[1], day: parti[0]))
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
