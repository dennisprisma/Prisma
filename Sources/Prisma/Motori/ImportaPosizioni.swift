import Foundation

/// Una posizione letta da un CSV, prima dell'importazione: già abbinata a un cliente della rubrica.
struct PosizioneImportata: Identifiable {
    let id = UUID()
    var posizione: Posizione
    /// Il nome del cliente come scritto nel file.
    var clienteNelFile: String
    /// Il cliente della rubrica abbinato (nil se non trovato: va importato prima).
    var cliente: Cliente?
    /// Canale e area ricavati dal file (se no, scelti da Prisma: si possono correggere dopo).
    var canaleDalFile: Bool
    var areaDalFile: Bool
    /// Perché non si importa così com'è: cliente non trovato, posizione già presente, riga ripetuta.
    var problema: String?
}

/// Un file di posizioni letto, per l'anteprima.
struct ImportazionePosizioni: Identifiable {
    let id = UUID()
    let file: String
    let colonne: [ImportaPosizioni.Colonna]
    var posizioni: [PosizioneImportata]
}

/// Legge le posizioni da un CSV (elenchi di polizze, portafogli esportati da Excel): le abbina ai clienti
/// della rubrica per codice fiscale o nome e propone canale, area e stato. Tutto in locale.
enum ImportaPosizioni {
    enum Colonna: String, CaseIterable {
        case cliente, nome, cognome, codiceFiscale, prodotto, numeroContratto, emittente, tipologia, decorrenza, scadenza
        case premio, frequenza, controvalore, dataValore, versato, capitale, canale, area, stato

        var nome: String {
            switch self {
            case .cliente: return "Cliente"
            case .nome: return "Nome"
            case .cognome: return "Cognome"
            case .codiceFiscale: return "Codice fiscale"
            case .prodotto: return "Prodotto"
            case .numeroContratto: return "Numero di contratto"
            case .emittente: return "Compagnia"
            case .tipologia: return "Tipologia"
            case .decorrenza: return "Decorrenza"
            case .scadenza: return "Scadenza"
            case .premio: return "Premio"
            case .frequenza: return "Frequenza"
            case .controvalore: return "Controvalore"
            case .dataValore: return "Data del valore"
            case .versato: return "Versato"
            case .capitale: return "Capitale assicurato"
            case .canale: return "Canale"
            case .area: return "Area"
            case .stato: return "Stato"
            }
        }

        static func da(_ intestazione: String) -> Colonna? {
            let t = intestazione.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Prima le più specifiche: "data valore" prima di "valore", "premi versati" prima di "premio"
            let regole: [(Colonna, [String])] = [
                (.codiceFiscale, ["codice fiscale", "cod. fiscale", "cod fiscale", "c.f.", "cf", "cf contraente", "codice fiscale contraente"]),
                (.dataValore, ["data valore", "data del valore", "valore al", "data di riferimento", "data riferimento", "aggiornato al", "data valorizzazione"]),
                (.versato, ["versato", "totale versato", "premi versati", "cumulo premi", "totale premi", "capitale versato", "importo versato"]),
                (.capitale, ["capitale assicurato", "somma assicurata", "capitale caso morte", "massimale"]),
                (.controvalore, ["controvalore", "valore", "valore attuale", "valore di riscatto", "riserva", "riserva matematica", "saldo", "valore di mercato"]),
                (.numeroContratto, ["numero polizza", "n. polizza", "n polizza", "polizza", "numero contratto", "n. contratto", "contratto", "codice contratto", "numero"]),
                (.cliente, ["cliente", "contraente", "nominativo", "nome e cognome", "cognome e nome", "intestatario", "titolare"]),
                (.cognome, ["cognome"]),
                (.nome, ["nome"]),
                (.prodotto, ["prodotto", "nome prodotto", "descrizione", "tariffa", "denominazione", "linea", "fondo"]),
                (.emittente, ["compagnia", "emittente", "societa", "gestore", "banca", "impresa"]),
                (.tipologia, ["tipologia", "tipo", "ramo", "tipo prodotto", "categoria"]),
                (.decorrenza, ["decorrenza", "data decorrenza", "data effetto", "effetto", "data emissione", "data sottoscrizione", "inizio", "data inizio", "apertura"]),
                (.scadenza, ["scadenza", "data scadenza", "fine", "data fine"]),
                (.frequenza, ["frazionamento", "frequenza", "periodicita", "rateazione"]),
                (.premio, ["premio", "rata", "premio rata", "importo premio", "premio annuo", "versamento periodico", "versamento", "contributo"]),
                (.canale, ["canale"]),
                (.area, ["area", "bisogno"]),
                (.stato, ["stato", "situazione"]),
            ]
            for (c, parole) in regole where parole.contains(t) { return c }
            for (c, parole) in regole where parole.contains(where: { $0.count > 3 && t.hasPrefix($0) }) { return c }
            return nil
        }
    }

    static func leggi(_ url: URL, clienti: [Cliente], posizioni: [Posizione], canale: Canale = .alleanza) -> ImportazionePosizioni? {
        guard let dati = try? Data(contentsOf: url), let t = ImportaClienti.testo(dati) else { return nil }
        let letto = daCSV(t, clienti: clienti, posizioni: posizioni, canale: canale)
        guard !letto.posizioni.isEmpty else { return nil }
        return ImportazionePosizioni(file: url.lastPathComponent, colonne: letto.colonne, posizioni: letto.posizioni)
    }

    static func daCSV(_ testo: String, clienti: [Cliente], posizioni esistenti: [Posizione], canale predefinito: Canale = .alleanza,
                      oggi: Date = Date()) -> (colonne: [Colonna], posizioni: [PosizioneImportata]) {
        let righe = ImportaClienti.righeCSV(testo)
        guard let testa = righe.first else { return ([], []) }
        var usate: [Colonna: Int] = [:]
        for (i, h) in testa.enumerated() { if let c = Colonna.da(h), usate[c] == nil { usate[c] = i } }

        var viste = Set<String>()
        let elenco = righe.dropFirst().compactMap { r -> PosizioneImportata? in
            func v(_ c: Colonna) -> String {
                guard let i = usate[c], i < r.count else { return "" }
                return r[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let nomeCliente = v(.cliente).isEmpty ? [v(.nome), v(.cognome)].filter { !$0.isEmpty }.joined(separator: " ") : v(.cliente)
            let prodotto = v(.prodotto).isEmpty ? v(.tipologia) : v(.prodotto)
            guard !prodotto.isEmpty || !v(.numeroContratto).isEmpty else { return nil }
            let cf = v(.codiceFiscale).uppercased().filter { $0.isLetter || $0.isNumber }
            let cliente = abbina(nome: nomeCliente, codiceFiscale: cf, clienti: clienti)

            let testoProdotto = [prodotto, v(.tipologia), v(.emittente)].joined(separator: " ")
            let canaleLetto = canale(v(.canale)) ?? (v(.emittente).lowercased().contains("alleanza") ? .alleanza : nil)
            let areaLetta = area(v(.area))
            var p = Posizione(clienteId: cliente?.id ?? "", canale: canaleLetto ?? predefinito, stato: stato(v(.stato)),
                              area: areaLetta ?? areaDal(testoProdotto), nome: prodotto.isEmpty ? "Contratto \(v(.numeroContratto))" : prodotto)
            p.numeroContratto = v(.numeroContratto)
            p.emittente = v(.emittente).isEmpty && p.canale == .alleanza ? "Alleanza Assicurazioni" : v(.emittente)
            p.tipologia = v(.tipologia)
            p.decorrenza = ImportaClienti.data(v(.decorrenza))
            p.scadenza = ImportaClienti.data(v(.scadenza))
            if let premio = EstrattoreDocumento.numero(v(.premio)), premio > 0 {
                p.premio = premio
                p.frequenza = frequenza(v(.frequenza)) ?? .annuale
                // Un premio unico è il versamento iniziale, non un premio periodico
                if p.frequenza == .unica {
                    p.versamentoIniziale = premio
                    p.premio = 0
                }
            }
            p.controvalore = EstrattoreDocumento.numero(v(.controvalore))
            if p.controvalore != nil {
                p.dataValore = ImportaClienti.data(v(.dataValore)) ?? ValoriDaDocumento.mezzogiorno(oggi)
            }
            p.totaleVersato = EstrattoreDocumento.numero(v(.versato))
            p.capitaleAssicurato = EstrattoreDocumento.numero(v(.capitale))
            if p.area == .protezione { p.rischio = rischio(testoProdotto) }
            if p.versamentoIniziale == 0, p.premio == 0, let versato = p.totaleVersato { p.versamentoIniziale = versato }
            p.note = "Importata da file il \(Formati.dataEstesa.string(from: oggi))."

            var x = PosizioneImportata(posizione: p, clienteNelFile: nomeCliente.isEmpty ? cf : nomeCliente, cliente: cliente,
                                       canaleDalFile: canaleLetto != nil, areaDalFile: areaLetta != nil)
            let chiave = "\(cliente?.id ?? nomeCliente)|\(p.numeroContratto.isEmpty ? p.nome.lowercased() : compatto(p.numeroContratto))"
            if cliente == nil {
                x.problema = nomeCliente.isEmpty && cf.isEmpty ? "manca il cliente" : "cliente non in rubrica: importalo prima"
            } else if let c = cliente, esistenti.contains(where: { e in
                e.clienteId == c.id && (p.numeroContratto.isEmpty ? e.nome.lowercased() == p.nome.lowercased()
                                                                  : compatto(e.numeroContratto) == compatto(p.numeroContratto))
            }) {
                x.problema = "già in Posizioni"
            } else if viste.contains(chiave) {
                x.problema = "ripetuta nel file"
            }
            viste.insert(chiave)
            return x
        }
        let colonne = usate.keys.sorted { (usate[$0] ?? 0) < (usate[$1] ?? 0) }
        return (colonne, elenco)
    }

    /// Il cliente della rubrica: prima il codice fiscale, poi il nome (anche con cognome e nome invertiti).
    static func abbina(nome: String, codiceFiscale: String, clienti: [Cliente]) -> Cliente? {
        if !codiceFiscale.isEmpty, let c = clienti.first(where: { $0.codiceFiscale.uppercased() == codiceFiscale }) { return c }
        let chiave = piega(nome)
        guard !chiave.isEmpty else { return nil }
        let trovati = clienti.filter { piega($0.nome) == chiave }
        return trovati.count == 1 ? trovati.first : nil
    }

    private static func piega(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
            .split { !$0.isLetter }.sorted().joined(separator: " ")
    }

    private static func compatto(_ s: String) -> String { s.uppercased().filter { $0.isLetter || $0.isNumber } }

    static func canale(_ s: String) -> Canale? {
        let t = s.lowercased()
        if t.contains("alleanza") { return .alleanza }
        if t.contains("indip") || t.contains("altro") || t.contains("terzi") { return .indipendente }
        return nil
    }

    static func stato(_ s: String) -> StatoPosizione {
        let t = s.lowercased()
        if t.contains("propost") { return .proposta }
        if ["chius", "estint", "riscatt", "scadut", "annullat", "stornat"].contains(where: { t.contains($0) }) { return .chiusa }
        return .inEssere
    }

    static func area(_ s: String) -> AreaPosizione? {
        let t = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
        guard !t.isEmpty else { return nil }
        return AreaPosizione.allCases.first { t.contains($0.nome.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)) }
    }

    /// L'area dal nome e dalla tipologia del prodotto.
    static func areaDal(_ testo: String) -> AreaPosizione {
        let t = testo.lowercased()
        let regole: [(AreaPosizione, [String])] = [
            (.previdenza, ["pension", "previden", "pip", "tfr"]),
            (.protezione, ["caso morte", "tcm", "temporanea", "infortun", "ltc", "non autosufficien", "malattia", "invalidit", "salute", "rc ", "responsabilit", "casa", "danni"]),
            (.debiti, ["mutuo", "prestito", "finanziamento", "leasing", "cessione del quinto"]),
            (.liquidita, ["conto corrente", "conto deposito", "deposito", "libretto", "liquidit"]),
            (.risparmio, ["rivalutabil", "ramo i ", "ramo i)", "gestione separata", "risparmio", "capitalizzazione", "pac"]),
            (.investimento, ["ramo iii", "unit", "multiramo", "fondo", "etf", "sicav", "gestione", "azion", "obbligaz", "titol", "btp"]),
            (.immobili, ["immobil", "appartamento", "casa di proprieta"]),
        ]
        return regole.first { r in r.1.contains { t.contains($0) } }?.0 ?? .investimento
    }

    static func rischio(_ testo: String) -> RischioCoperto {
        let t = testo.lowercased()
        if t.contains("infortun") { return .infortuni }
        if t.contains("ltc") || t.contains("non autosufficien") { return .ltc }
        if t.contains("invalidit") { return .invalidita }
        if t.contains("malattia") || t.contains("salute") { return .salute }
        if t.contains("casa") || t.contains("danni") { return .casa }
        if t.contains("rc ") || t.contains("responsabilit") { return .rc }
        return .vita
    }

    static func frequenza(_ s: String) -> Frequenza? {
        let t = s.lowercased().trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        if t.contains("mens") || t == "12" { return .mensile }
        if t.contains("trim") || t == "4" { return .trimestrale }
        if t.contains("sem") || t == "2" { return .semestrale }
        if t.contains("ann") || t == "1" { return .annuale }
        if t.contains("unic") || t == "0" { return .unica }
        return nil
    }
}
