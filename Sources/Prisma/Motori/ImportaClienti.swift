import Foundation

/// Un cliente letto da un file di contatti, prima dell'importazione.
struct ClienteImportato: Identifiable, Equatable {
    let id = UUID()
    var nome: String
    var email = ""
    var telefono = ""
    var indirizzo = ""
    var dataNascita: Date?
    var codiceFiscale = ""
    var professione = ""
    var nota = ""
    /// Il cliente già in rubrica che sembra lo stesso (nome, codice fiscale o email).
    var doppione: String?

    func cliente(tinta: TintaAvatar) -> Cliente {
        var c = Cliente(id: UUID().uuidString, nome: nome, iniziali: Cliente.iniziali(di: nome), tinta: tinta, tema: "",
                        email: email, telefono: telefono, preferito: false, nota: nota, creatoIl: Date())
        c.dataNascita = dataNascita
        c.codiceFiscale = codiceFiscale.uppercased()
        c.professione = professione
        c.indirizzo = indirizzo
        return c
    }
}

/// Un file di contatti letto, per l'anteprima prima dell'importazione.
struct ImportazioneClienti: Identifiable {
    let id = UUID()
    let file: String
    /// Colonne riconosciute (solo per i CSV).
    let colonne: [ImportaClienti.Colonna]
    var clienti: [ClienteImportato]
}

/// Legge i contatti da importare: vCard (app Contatti del Mac, Outlook, Google) e CSV (Excel, Numbers).
/// Tutto in locale: il file non lascia il Mac.
enum ImportaClienti {
    /// Le colonne di un CSV che Prisma sa riconoscere.
    enum Colonna: String, CaseIterable {
        case nome, cognome, nominativo, email, telefono, indirizzo, citta, cap, nascita, codiceFiscale, professione, note

        var nome: String {
            switch self {
            case .nome: return "Nome"
            case .cognome: return "Cognome"
            case .nominativo: return "Nome e cognome"
            case .email: return "Email"
            case .telefono: return "Telefono"
            case .indirizzo: return "Indirizzo"
            case .citta: return "Città"
            case .cap: return "CAP"
            case .nascita: return "Data di nascita"
            case .codiceFiscale: return "Codice fiscale"
            case .professione: return "Professione"
            case .note: return "Note"
            }
        }

        /// Riconosce l'intestazione di una colonna (prima le più specifiche).
        static func da(_ intestazione: String) -> Colonna? {
            let t = intestazione.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let regole: [(Colonna, [String])] = [
                (.codiceFiscale, ["codice fiscale", "cod. fiscale", "cod fiscale", "c.f.", "cf", "fiscal code"]),
                (.nascita, ["data di nascita", "nascita", "nato il", "data nascita", "birthday", "compleanno"]),
                (.nominativo, ["nome e cognome", "cognome e nome", "nominativo", "nome completo", "full name", "cliente"]),
                (.cognome, ["cognome", "last name", "surname"]),
                (.nome, ["nome", "first name", "name"]),
                (.email, ["e-mail", "email", "mail", "posta"]),
                (.telefono, ["cellulare", "telefono", "tel", "mobile", "phone", "cell"]),
                (.cap, ["cap", "c.a.p.", "zip", "codice postale"]),
                (.citta, ["citta", "comune", "localita", "city"]),
                (.indirizzo, ["indirizzo", "via", "residenza", "address"]),
                (.professione, ["professione", "lavoro", "occupazione", "job", "title"]),
                (.note, ["note", "nota", "annotazioni", "notes"]),
            ]
            // Prima l'intestazione uguale, poi quella che comincia con la parola
            for (c, parole) in regole where parole.contains(t) { return c }
            for (c, parole) in regole where parole.contains(where: { $0.count > 3 && t.hasPrefix($0) }) { return c }
            return nil
        }
    }

    // MARK: - Testo del file

    /// Il testo di un file: UTF-8 (anche con BOM) o, per i CSV di Excel su Windows, Latin-1.
    static func testo(_ dati: Data) -> String? {
        if let s = String(data: dati, encoding: .utf8) { return s.hasPrefix("\u{FEFF}") ? String(s.dropFirst()) : s }
        return String(data: dati, encoding: .windowsCP1252) ?? String(data: dati, encoding: .isoLatin1)
    }

    // MARK: - vCard

    static func daVCard(_ testo: String) -> [ClienteImportato] {
        // Le righe lunghe proseguono su quelle che cominciano con uno spazio
        let righe = testo.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n ", with: "").replacingOccurrences(of: "\n\t", with: "")
            .components(separatedBy: "\n")
        var elenco: [ClienteImportato] = []
        var corrente: [(String, String)]?
        for riga in righe {
            let r = riga.trimmingCharacters(in: .whitespaces)
            if r.uppercased() == "BEGIN:VCARD" { corrente = []; continue }
            if r.uppercased() == "END:VCARD" {
                if let campi = corrente, let c = daCampiVCard(campi) { elenco.append(c) }
                corrente = nil
                continue
            }
            guard corrente != nil, let due = r.firstIndex(of: ":") else { continue }
            // "item1.TEL;TYPE=CELL" → "TEL"
            let chiave = r[..<due].split(separator: ";").first.map { String($0.split(separator: ".").last ?? $0).uppercased() } ?? ""
            corrente?.append((chiave, String(r[r.index(after: due)...])))
        }
        return elenco
    }

    private static func daCampiVCard(_ campi: [(String, String)]) -> ClienteImportato? {
        func primo(_ k: String) -> String? { campi.first { $0.0 == k }.map { pulisciVCard($0.1) }.flatMap { $0.isEmpty ? nil : $0 } }
        var nome = primo("FN") ?? ""
        if nome.isEmpty, let n = campi.first(where: { $0.0 == "N" })?.1 {
            // N: Cognome;Nome;Altri;Titolo;Suffisso
            let parti = n.components(separatedBy: ";").map(pulisciVCard)
            nome = [parti.count > 1 ? parti[1] : "", parti.first ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
        }
        guard !nome.isEmpty else { return nil }
        var c = ClienteImportato(nome: nome)
        c.email = primo("EMAIL") ?? ""
        c.telefono = primo("TEL") ?? ""
        if let adr = campi.first(where: { $0.0 == "ADR" })?.1 {
            // ADR: casella;esteso;via;città;provincia;CAP;paese
            let p = adr.components(separatedBy: ";").map(pulisciVCard)
            let via = p.count > 2 ? p[2] : ""
            let luogo = [p.count > 5 ? p[5] : "", p.count > 3 ? p[3] : "", p.count > 4 && !p[4].isEmpty ? "(\(p[4]))" : ""].filter { !$0.isEmpty }.joined(separator: " ")
            c.indirizzo = [via, luogo].filter { !$0.isEmpty }.joined(separator: ", ")
        }
        if let b = primo("BDAY") { c.dataNascita = data(b) }
        c.professione = primo("TITLE") ?? primo("ROLE") ?? ""
        c.nota = primo("NOTE") ?? ""
        return c
    }

    private static func pulisciVCard(_ s: String) -> String {
        s.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",").replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Date dei contatti: "1985-03-15", "19850315", "15/03/1985"; senza anno ("--0315") non è una data di nascita utile.
    static func data(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespaces)
        // Numero di serie di Excel (giorni dal 30/12/1899), come esce da un .xlsx: "45123" o "45123,5"
        if let serie = Int(t.split(whereSeparator: { $0 == "," || $0 == "." }).first ?? ""), t.first?.isNumber == true,
           t.allSatisfy({ $0.isNumber || $0 == "," || $0 == "." }), (10_000...80_000).contains(serie),
           let base = Calendar.current.date(from: DateComponents(year: 1899, month: 12, day: 30, hour: 12)) {
            return Calendar.current.date(byAdding: .day, value: serie, to: base)
        }
        if t.count == 8, t.allSatisfy(\.isNumber) {
            return EstrattoreDocumento.data("\(t.prefix(4))-\(t.dropFirst(4).prefix(2))-\(t.suffix(2))").map(mezzogiorno)
        }
        // "1985-03-15T00:00:00Z" → la parte della data
        let soloData = t.split(separator: "T").first.map(String.init) ?? t
        return EstrattoreDocumento.data(soloData).map(mezzogiorno)
    }

    private static func mezzogiorno(_ d: Date) -> Date {
        let cal = Calendar.current
        let g = cal.dateComponents([.year, .month, .day], from: d)
        return cal.date(from: DateComponents(year: g.year, month: g.month, day: g.day, hour: 12)) ?? d
    }

    // MARK: - CSV

    /// Le righe di un CSV: separatore riconosciuto (punto e virgola di Excel italiano, virgola, tabulazione),
    /// virgolette con separatori e a capo dentro.
    static func righeCSV(_ testo: String) -> [[String]] {
        let pulito = testo.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let prima = pulito.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let separatore: Character = [";", "\t", ","].max { a, b in prima.filter { $0 == a }.count < prima.filter { $0 == b }.count } ?? ";"
        var righe: [[String]] = []
        var riga: [String] = []
        var campo = ""
        var tra = false
        var indice = pulito.startIndex
        while indice < pulito.endIndex {
            let ch = pulito[indice]
            if tra {
                if ch == "\"" {
                    let dopo = pulito.index(after: indice)
                    if dopo < pulito.endIndex, pulito[dopo] == "\"" { campo.append("\""); indice = dopo } else { tra = false }
                } else {
                    campo.append(ch)
                }
            } else if ch == "\"" {
                tra = true
            } else if ch == separatore {
                riga.append(campo); campo = ""
            } else if ch == "\n" {
                riga.append(campo); campo = ""
                if riga.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { righe.append(riga) }
                riga = []
            } else {
                campo.append(ch)
            }
            indice = pulito.index(after: indice)
        }
        riga.append(campo)
        if riga.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { righe.append(riga) }
        return righe
    }

    /// Le righe di un file tabellare: Excel (.xlsx) letto direttamente, altrimenti CSV o testo a tabulazioni.
    static func righe(_ url: URL) -> [[String]]? {
        if url.pathExtension.lowercased() == "xlsx" { return FoglioExcel.righe(url) }
        guard let dati = try? Data(contentsOf: url), let t = testo(dati) else { return nil }
        return righeCSV(t)
    }

    /// I clienti di un CSV con intestazione; anche le colonne riconosciute, da mostrare nell'anteprima.
    static func daCSV(_ testo: String) -> (colonne: [Colonna], clienti: [ClienteImportato]) {
        daRighe(righeCSV(testo))
    }

    /// I clienti di una tabella con intestazione (CSV, Excel o righe incollate).
    static func daRighe(_ righe: [[String]]) -> (colonne: [Colonna], clienti: [ClienteImportato]) {
        guard let testa = righe.first else { return ([], []) }
        let colonne = testa.map(Colonna.da)
        var usate = Set<Colonna>()
        // Una colonna conta una volta sola (la prima)
        let mappa: [Int: Colonna] = Dictionary(uniqueKeysWithValues: colonne.enumerated().compactMap { i, c in
            guard let c, !usate.contains(c) else { return nil }
            usate.insert(c)
            return (i, c)
        })
        let clienti = righe.dropFirst().compactMap { r -> ClienteImportato? in
            func v(_ c: Colonna) -> String {
                guard let i = mappa.first(where: { $0.value == c })?.key, i < r.count else { return "" }
                return r[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let nome = v(.nominativo).isEmpty ? [v(.nome), v(.cognome)].filter { !$0.isEmpty }.joined(separator: " ") : v(.nominativo)
            guard !nome.isEmpty else { return nil }
            var c = ClienteImportato(nome: nome)
            c.email = v(.email)
            c.telefono = v(.telefono)
            let luogo = [v(.cap), v(.citta)].filter { !$0.isEmpty }.joined(separator: " ")
            c.indirizzo = [v(.indirizzo), luogo].filter { !$0.isEmpty }.joined(separator: ", ")
            c.dataNascita = v(.nascita).isEmpty ? nil : data(v(.nascita))
            c.codiceFiscale = v(.codiceFiscale).uppercased().filter { $0.isLetter || $0.isNumber }
            c.professione = v(.professione)
            c.nota = v(.note)
            return c
        }
        return (Array(usate).sorted { $0.rawValue < $1.rawValue }, clienti)
    }

    /// Legge un file (vCard o CSV) e segna i doppioni rispetto alla rubrica; nil se non c'è nessun contatto.
    static func leggi(_ url: URL, rubrica: [Cliente]) -> ImportazioneClienti? {
        if url.pathExtension.lowercased() == "xlsx" {
            guard let righe = FoglioExcel.righe(url) else { return nil }
            return importazione(daRighe(righe), file: url.lastPathComponent, rubrica: rubrica)
        }
        guard let dati = try? Data(contentsOf: url), let t = testo(dati) else { return nil }
        let vcard = url.pathExtension.lowercased() == "vcf" || t.uppercased().contains("BEGIN:VCARD")
        let colonne: [Colonna]
        let clienti: [ClienteImportato]
        if vcard {
            colonne = []
            clienti = daVCard(t)
        } else {
            let csv = daCSV(t)
            colonne = csv.colonne
            clienti = csv.clienti
        }
        return importazione((colonne, clienti), file: url.lastPathComponent, rubrica: rubrica)
    }

    /// Righe copiate da Excel o Numbers (testo a tabulazioni negli appunti), con l'intestazione nella prima.
    static func incollati(_ testo: String, rubrica: [Cliente]) -> ImportazioneClienti? {
        if testo.uppercased().contains("BEGIN:VCARD") {
            return importazione(([], daVCard(testo)), file: "appunti", rubrica: rubrica)
        }
        return importazione(daCSV(testo), file: "appunti", rubrica: rubrica)
    }

    private static func importazione(_ letto: (colonne: [Colonna], clienti: [ClienteImportato]), file: String,
                                     rubrica: [Cliente]) -> ImportazioneClienti? {
        guard !letto.clienti.isEmpty else { return nil }
        return ImportazioneClienti(file: file, colonne: letto.colonne, clienti: segnaDoppioni(letto.clienti, rubrica: rubrica))
    }

    // MARK: - Doppioni

    /// Segna chi è già in rubrica (stesso nome, codice fiscale o email) e chi compare due volte nel file.
    static func segnaDoppioni(_ elenco: [ClienteImportato], rubrica: [Cliente]) -> [ClienteImportato] {
        func piega(_ s: String) -> String {
            s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
                .split { !$0.isLetter }.sorted().joined(separator: " ")
        }
        var visti: [String: String] = [:]
        return elenco.map { x in
            var c = x
            let cf = c.codiceFiscale.uppercased()
            let mail = c.email.lowercased()
            if let r = rubrica.first(where: { piega($0.nome) == piega(c.nome)
                || (!cf.isEmpty && $0.codiceFiscale.uppercased() == cf)
                || (!mail.isEmpty && $0.email.lowercased() == mail) }) {
                c.doppione = "già in rubrica: \(r.nome)"
            } else if let gia = visti[piega(c.nome)] {
                c.doppione = "ripetuto nel file: \(gia)"
            }
            visti[piega(c.nome)] = c.nome
            return c
        }
    }
}
