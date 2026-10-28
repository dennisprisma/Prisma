import Foundation

// Ricerca per criterio (⌘K): nel campo si scrivono filtri, anche insieme alle parole.
//   scade:2027 · scade:2027-03       posizioni che scadono in quell'anno (o mese)
//   sri>4 · sri>=5 · sri<3           rischio del KID (della posizione o della sua scheda prodotto)
//   canale:alleanza · canale:indip…  il canale della posizione
//   costo>2% · costi>=1,5            costi annui: RIY del KID se c'è, altrimenti gestione + trattenuto
//   beneficiari:vuoti                polizze (vita, protezione, previdenza) senza beneficiari scritti
//   senza:previdenza · con:protez…   clienti senza (o con) posizioni in essere di quell'area
//   riesame:dovuto                   clienti con il riesame annuale da fare (MotoreRiesame)
//   stato:proposta · stato:inessere  stato della posizione (senza filtro di stato le chiuse non compaiono)
//   area:investimento …              area della posizione
// Tutto puro: niente StatoShell, si prova con `FiltriRicerca.verifica()`.

/// Il confronto di un filtro numerico.
enum ConfrontoFiltro: String, Hashable {
    case maggioreUguale = ">="
    case minoreUguale = "<="
    case maggiore = ">"
    case minore = "<"
    case uguale = "="

    func vale<T: Comparable>(_ a: T, _ b: T) -> Bool {
        switch self {
        case .maggiore: return a > b
        case .maggioreUguale: return a >= b
        case .minore: return a < b
        case .minoreUguale: return a <= b
        case .uguale: return a == b
        }
    }

    /// Il simbolo tipografico (≥, ≤).
    var simbolo: String {
        switch self {
        case .maggiore: return ">"
        case .maggioreUguale: return "≥"
        case .minore: return "<"
        case .minoreUguale: return "≤"
        case .uguale: return "="
        }
    }
}

/// Un filtro riconosciuto nel testo della ricerca.
enum FiltroRicerca: Hashable {
    case scade(anno: Int, mese: Int?)
    case sri(ConfrontoFiltro, Int)
    case canale(Canale)
    case costo(ConfrontoFiltro, Double)
    case beneficiariVuoti
    case senza(AreaPosizione)
    case con(AreaPosizione)
    case riesameDovuto
    case stato(StatoPosizione)
    case area(AreaPosizione)

    /// I filtri che scelgono clienti (gli altri scelgono posizioni).
    var suiClienti: Bool {
        switch self {
        case .senza, .con, .riesameDovuto: return true
        default: return false
        }
    }

    /// Come si legge nel pannello: «Scade nel 2027», «SRI ≥ 5», «Senza previdenza».
    var descrizione: String {
        switch self {
        case .scade(let anno, let mese):
            if let mese, let data = Calendar.current.date(from: DateComponents(year: anno, month: mese, day: 1)) {
                return "Scade a \(Formati.meseAnno.string(from: data))"
            }
            return "Scade nel \(anno)"
        case .sri(let c, let n): return "SRI \(c.simbolo) \(n)"
        case .canale(let c): return c.nomeBreve
        case .costo(let c, let x): return "Costi \(c.simbolo) \(Formati.percentuale(x))"
        case .beneficiariVuoti: return "Beneficiari da indicare"
        case .senza(let a): return "Senza \(a.nome.lowercased())"
        case .con(let a): return "Con \(a.nome.lowercased())"
        case .riesameDovuto: return "Riesame da fare"
        case .stato(let s): return s.nome
        case .area(let a): return a.nome
        }
    }
}

/// Il testo della ricerca diviso in filtri e parole.
struct RicercaInterpretata: Equatable {
    var filtri: [FiltroRicerca] = []
    /// Le parole da cercare come sempre (titoli, campi, testo dei documenti).
    var parole: [String] = []
    /// Filtri scritti a metà o con un valore che non si capisce («scade:», «sri>otto»): non diventano
    /// parole da cercare, altrimenti mentre si scrive non si troverebbe più niente.
    var incompleti: [String] = []

    var conFiltri: Bool { !filtri.isEmpty }
    var testoLibero: String { parole.joined(separator: " ") }
    var filtriPosizioni: [FiltroRicerca] { filtri.filter { !$0.suiClienti } }
    var filtriClienti: [FiltroRicerca] { filtri.filter { $0.suiClienti } }
}

/// Una pillola suggerita mentre si scrive: si tocca (o Tab) e completa il filtro.
struct SuggerimentoFiltro: Identifiable, Hashable {
    /// Il testo che entra nel campo.
    let testo: String
    /// Cosa fa, in poche parole.
    let descrizione: String
    /// Vero se il filtro è completo: dopo si aggiunge uno spazio per continuare a scrivere.
    var completo = true

    var id: String { testo }
}

/// Totale delle posizioni trovate per un canale (Alleanza / indipendente).
struct TotaleCanaleRicerca: Identifiable, Hashable {
    let canale: Canale
    let numero: Int
    /// Somma dei valori (senza i debiti).
    let valore: Double

    var id: Canale { canale }
}

/// Le posizioni e i clienti che rispettano i filtri, con i totali per canale.
struct EsitoFiltri {
    var posizioni: [Posizione] = []
    var clienti: [Cliente] = []
    var totali: [TotaleCanaleRicerca] = []
    /// I totali sono delle posizioni in essere dei clienti trovati (non di posizioni filtrate).
    var totaliDeiClienti = false
}

enum FiltriRicerca {
    // MARK: Chiavi

    private enum Chiave: CaseIterable {
        case scade, sri, canale, costo, beneficiari, senza, con, riesame, stato, area

        /// I nomi con cui si può scrivere la chiave.
        var nomi: [String] {
            switch self {
            case .scade: return ["scade", "scadenza"]
            case .sri: return ["sri", "rischio"]
            case .canale: return ["canale"]
            case .costo: return ["costo", "costi", "riy"]
            case .beneficiari: return ["beneficiari", "beneficiario"]
            case .senza: return ["senza"]
            case .con: return ["con"]
            case .riesame: return ["riesame"]
            case .stato: return ["stato"]
            case .area: return ["area"]
            }
        }

        static func da(_ nome: String) -> Chiave? { allCases.first { $0.nomi.contains(nome) } }
    }

    /// Le pillole dei filtri, nell'ordine in cui si propongono (pannello vuoto e completamento delle chiavi).
    static let chiavi: [SuggerimentoFiltro] = [
        SuggerimentoFiltro(testo: "scade:", descrizione: "scadenza in un anno o un mese", completo: false),
        SuggerimentoFiltro(testo: "sri>", descrizione: "rischio del KID, da 1 a 7", completo: false),
        SuggerimentoFiltro(testo: "canale:", descrizione: "Alleanza o indipendente", completo: false),
        SuggerimentoFiltro(testo: "costo>", descrizione: "costi annui o RIY, in %", completo: false),
        SuggerimentoFiltro(testo: "beneficiari:vuoti", descrizione: "polizze senza beneficiari"),
        SuggerimentoFiltro(testo: "senza:", descrizione: "clienti senza un'area in essere", completo: false),
        SuggerimentoFiltro(testo: "riesame:dovuto", descrizione: "clienti da rivedere"),
        SuggerimentoFiltro(testo: "stato:", descrizione: "in essere o proposta", completo: false),
        SuggerimentoFiltro(testo: "area:", descrizione: "investimento, previdenza…", completo: false),
    ]

    private static let operatori = ["<=", ">=", "<", ">", "=", ":"]
    private static let localeConfronto = Locale(identifier: "it_IT")

    /// Minuscolo, senza accenti.
    static func piega(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: localeConfronto).lowercased()
    }

    /// Chiave, operatore e spazi attorno (preparata una volta sola: si usa a ogni tasto).
    private static let spaziFiltri: NSRegularExpression? = {
        let nomi = Chiave.allCases.flatMap(\.nomi).joined(separator: "|")
        return try? NSRegularExpression(pattern: "(?i)(^|\\s)(\(nomi))\\s*(>=|<=|>|<|=|:)\\s*")
    }()

    /// Unisce chiave, operatore e valore scritti con gli spazi: «sri > 4» → «sri>4», «canale: alleanza» → «canale:alleanza».
    static func normalizza(_ testo: String) -> String {
        guard let re = spaziFiltri else { return testo }
        let intero = NSRange(testo.startIndex..., in: testo)
        return re.stringByReplacingMatches(in: testo, range: intero, withTemplate: "$1$2$3")
    }

    /// Divide un pezzo in chiave, operatore e valore («sri>=5» → sri, >=, 5); nil se non ha la forma di un filtro.
    private static func dividi(_ pezzo: String) -> (chiave: Chiave, operatore: String, valore: String)? {
        let p = piega(pezzo)
        guard let primo = p.firstIndex(where: { "<>=:".contains($0) }) else { return nil }
        let nome = String(p[..<primo])
        guard let chiave = Chiave.da(nome) else { return nil }
        let resto = p[primo...]
        guard let op = operatori.first(where: { resto.hasPrefix($0) }) else { return nil }
        let valore = String(resto.dropFirst(op.count)).trimmingCharacters(in: .whitespaces)
        return (chiave, op, valore)
    }

    // MARK: Lettura del testo

    /// Divide il testo in filtri, parole e filtri incompleti.
    static func interpreta(_ testo: String) -> RicercaInterpretata {
        var r = RicercaInterpretata()
        let pezzi = normalizza(testo).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var i = 0
        while i < pezzi.count {
            let pezzo = pezzi[i]
            i += 1
            guard let diviso = dividi(pezzo) else {
                r.parole.append(pezzo)
                continue
            }
            let chiave = diviso.chiave
            let op = diviso.operatore
            var v = diviso.valore
            // «stato:in essere», con lo spazio
            if chiave == .stato, v == "in", i < pezzi.count, piega(pezzi[i]) == "essere" {
                v = "inessere"
                i += 1
            }
            if let f = filtro(chiave, op, v) {
                if !r.filtri.contains(f) { r.filtri.append(f) }
            } else {
                r.incompleti.append(pezzo)
            }
        }
        return r
    }

    private static func confronto(_ op: String, dueQuantiPunti: ConfrontoFiltro) -> ConfrontoFiltro? {
        op == ":" ? dueQuantiPunti : ConfrontoFiltro(rawValue: op)
    }

    private static func numero(_ s: String) -> Double? {
        let pulito = s.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: ".")
        guard !pulito.isEmpty else { return nil }
        return Double(pulito)
    }

    private static func filtro(_ chiave: Chiave, _ op: String, _ v: String) -> FiltroRicerca? {
        guard !v.isEmpty else { return nil }
        switch chiave {
        case .scade:
            guard op == ":" || op == "=" else { return nil }
            return scadenza(v)
        case .sri:
            guard let c = confronto(op, dueQuantiPunti: .uguale), let n = Int(v), (1...7).contains(n) else { return nil }
            return .sri(c, n)
        case .canale:
            guard op == ":" || op == "=" else { return nil }
            let trovati = Canale.allCases.filter { $0.rawValue.hasPrefix(v) }
            return trovati.count == 1 ? .canale(trovati[0]) : nil
        case .costo:
            // «costo:2%» vale «almeno 2%»
            guard let c = confronto(op, dueQuantiPunti: .maggioreUguale), let x = numero(v), x >= 0, x < 100 else { return nil }
            return .costo(c, x)
        case .beneficiari:
            guard op == ":" || op == "=", ["vuoti", "vuoto", "mancanti", "mancante", "no", "nessuno", "assenti"].contains(v) else { return nil }
            return .beneficiariVuoti
        case .senza:
            guard op == ":" || op == "=" else { return nil }
            return area(v).map { FiltroRicerca.senza($0) }
        case .con:
            guard op == ":" || op == "=" else { return nil }
            return area(v).map { FiltroRicerca.con($0) }
        case .riesame:
            guard op == ":" || op == "=", ["dovuto", "dovuti", "dafare", "scaduto", "scaduti", "si"].contains(v) else { return nil }
            return .riesameDovuto
        case .stato:
            guard op == ":" || op == "=" else { return nil }
            return statoPosizione(v).map { FiltroRicerca.stato($0) }
        case .area:
            guard op == ":" || op == "=" else { return nil }
            return area(v).map { FiltroRicerca.area($0) }
        }
    }

    /// «2027», «2027-03», «2027/3», «03-2027», «3/2027».
    private static func scadenza(_ v: String) -> FiltroRicerca? {
        let parti = v.split(whereSeparator: { $0 == "-" || $0 == "/" || $0 == "." }).map(String.init)
        func anno(_ s: String) -> Int? { s.count == 4 ? Int(s).flatMap { (1900...2200).contains($0) ? $0 : nil } : nil }
        func mese(_ s: String) -> Int? { (1...2).contains(s.count) ? Int(s).flatMap { (1...12).contains($0) ? $0 : nil } : nil }
        switch parti.count {
        case 1:
            return anno(parti[0]).map { FiltroRicerca.scade(anno: $0, mese: nil) }
        case 2:
            if let a = anno(parti[0]), let m = mese(parti[1]) { return FiltroRicerca.scade(anno: a, mese: m) }
            if let m = mese(parti[0]), let a = anno(parti[1]) { return FiltroRicerca.scade(anno: a, mese: m) }
            return nil
        default:
            return nil
        }
    }

    /// L'area dal suo nome, anche a metà («invest», «previdenz») o al plurale («investimenti», «immobili»).
    private static func area(_ v: String) -> AreaPosizione? {
        let sinonimi: [String: AreaPosizione] = ["pensione": .previdenza, "pensioni": .previdenza, "assicurazione": .protezione,
                                                 "tutela": .protezione, "conto": .liquidita, "conti": .liquidita,
                                                 "casa": .immobili, "mutuo": .debiti, "mutui": .debiti, "prestiti": .debiti]
        if let s = sinonimi[v] { return s }
        let trovate = AreaPosizione.allCases.filter { a in
            let nome = piega(a.rawValue)
            return nome.hasPrefix(v) || (v.count >= 4 && v.hasPrefix(String(nome.dropLast())))
        }
        return trovate.count == 1 ? trovate[0] : nil
    }

    private static func statoPosizione(_ v: String) -> StatoPosizione? {
        let s = v.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "")
        if ["inessere", "essere", "attiva", "attive", "attivo", "attivi", "ines"].contains(where: { $0 == s }) || "inessere".hasPrefix(s) && s.count >= 3 {
            return .inEssere
        }
        if "proposta".hasPrefix(s) || s == "proposte" { return .proposta }
        if "chiusa".hasPrefix(s) || s == "chiuse" || s == "chiusi" || s == "chiuso" { return .chiusa }
        return nil
    }

    // MARK: Suggerimenti

    /// L'ultimo pezzo del testo, se si sta ancora scrivendo (il testo non finisce con uno spazio).
    private static func ultimoPezzo(_ testo: String) -> String? {
        let n = normalizza(testo)
        guard let ultimo = n.last, !ultimo.isWhitespace else { return nil }
        return n.split(whereSeparator: { $0.isWhitespace }).last.map(String.init)
    }

    /// Le pillole da proporre mentre si scrive l'ultimo pezzo: le chiavi che cominciano così («sc» → «scade:»)
    /// o i valori della chiave scritta («canale:» → «canale:alleanza», «canale:indipendente»).
    static func suggerimenti(per testo: String, oggi: Date = Date()) -> [SuggerimentoFiltro] {
        guard let pezzo = ultimoPezzo(testo) else { return [] }
        let p = piega(pezzo)
        guard let op = p.firstIndex(where: { "<>=:".contains($0) }) else {
            // Solo una chiave a metà: almeno due lettere, per non riempire il pannello a ogni parola
            guard p.count >= 2 else { return [] }
            return chiavi.filter { s in
                let nome = String(s.testo.prefix { $0.isLetter })
                return nome.hasPrefix(p) && nome != p || piega(s.testo).hasPrefix(p) && piega(s.testo) != p
            }
        }
        guard let chiave = Chiave.da(String(p[..<op])) else { return [] }
        let nome = String(p[..<op])
        let anno = Calendar.current.component(.year, from: oggi)
        let valori: [SuggerimentoFiltro]
        switch chiave {
        case .scade:
            valori = (0...3).map { SuggerimentoFiltro(testo: "\(nome):\(anno + $0)", descrizione: "scadono nel \(anno + $0)") }
        case .sri:
            valori = [SuggerimentoFiltro(testo: "\(nome)>=5", descrizione: "rischio alto"),
                      SuggerimentoFiltro(testo: "\(nome)>3", descrizione: "rischio medio-alto"),
                      SuggerimentoFiltro(testo: "\(nome)<=2", descrizione: "rischio basso")]
        case .canale:
            valori = Canale.allCases.map { SuggerimentoFiltro(testo: "\(nome):\($0.rawValue)", descrizione: $0.nomeBreve) }
        case .costo:
            valori = [SuggerimentoFiltro(testo: "\(nome)>1%", descrizione: "più dell'1% l'anno"),
                      SuggerimentoFiltro(testo: "\(nome)>2%", descrizione: "più del 2% l'anno"),
                      SuggerimentoFiltro(testo: "\(nome)>3%", descrizione: "più del 3% l'anno")]
        case .beneficiari:
            valori = [SuggerimentoFiltro(testo: "\(nome):vuoti", descrizione: "polizze senza beneficiari")]
        case .senza, .con:
            let aree: [AreaPosizione] = [.previdenza, .protezione, .investimento, .risparmio, .liquidita]
            valori = aree.map { SuggerimentoFiltro(testo: "\(nome):\($0.rawValue)", descrizione: "\(chiave == .senza ? "senza" : "con") \($0.nome.lowercased())") }
        case .riesame:
            valori = [SuggerimentoFiltro(testo: "\(nome):dovuto", descrizione: "clienti da rivedere")]
        case .stato:
            valori = [SuggerimentoFiltro(testo: "\(nome):proposta", descrizione: "proposte"),
                      SuggerimentoFiltro(testo: "\(nome):inessere", descrizione: "in essere"),
                      SuggerimentoFiltro(testo: "\(nome):chiusa", descrizione: "chiuse")]
        case .area:
            valori = AreaPosizione.allCases.map { SuggerimentoFiltro(testo: "\(nome):\($0.rawValue)", descrizione: $0.nome) }
        }
        // Solo quelli che continuano ciò che è scritto (e non sono già scritti per intero)
        return valori.filter { piega($0.testo).hasPrefix(p) && piega($0.testo) != p }
    }

    /// Il testo con l'ultimo pezzo sostituito dal suggerimento (e uno spazio dopo, se il filtro è completo).
    static func completa(_ testo: String, con s: SuggerimentoFiltro) -> String {
        let n = normalizza(testo)
        var base = n
        if let ultimo = n.last, !ultimo.isWhitespace {
            if let spazio = n.lastIndex(where: { $0.isWhitespace }) {
                base = String(n[...spazio])
            } else {
                base = ""
            }
        }
        return base + s.testo + (s.completo ? " " : "")
    }

    /// Aggiunge un filtro in fondo al testo (dalle pillole del pannello vuoto).
    static func aggiungi(_ s: SuggerimentoFiltro, a testo: String) -> String {
        let t = testo.trimmingCharacters(in: .whitespaces)
        return (t.isEmpty ? "" : t + " ") + s.testo + (s.completo ? " " : "")
    }

    // MARK: Applicazione ai dati

    /// Il costo annuo della posizione per i filtri: RIY del KID (della posizione o della scheda prodotto),
    /// altrimenti gestione più trattenuto, altrimenti il costo annuo della scheda prodotto.
    static func costo(_ p: Posizione, prodotto: Prodotto?) -> Double? {
        p.incidenzaCostiKID ?? prodotto?.incidenzaCostiKID ?? p.costoComplessivo ?? prodotto?.costoAnnuo
    }

    /// L'SRI della posizione o della sua scheda prodotto.
    static func sri(_ p: Posizione, prodotto: Prodotto?) -> Int? { p.sri ?? prodotto?.sri }

    /// La posizione è una polizza con beneficiari da indicare (vita, protezione, previdenza).
    static func chiedeBeneficiari(_ p: Posizione) -> Bool {
        p.area == .protezione || p.area == .previdenza || p.regime == .polizza
    }

    static func rispetta(_ p: Posizione, _ f: FiltroRicerca, prodotto: Prodotto?, calendario: Calendar = .current) -> Bool {
        switch f {
        case .scade(let anno, let mese):
            guard let s = p.scadenza else { return false }
            let c = calendario.dateComponents([.year, .month], from: s)
            return c.year == anno && (mese == nil || c.month == mese)
        case .sri(let c, let n):
            return sri(p, prodotto: prodotto).map { c.vale($0, n) } ?? false
        case .canale(let c):
            return p.canale == c
        case .costo(let c, let x):
            return costo(p, prodotto: prodotto).map { c.vale($0, x) } ?? false
        case .beneficiariVuoti:
            return chiedeBeneficiari(p) && p.beneficiari.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .stato(let s):
            return p.stato == s
        case .area(let a):
            return p.area == a
        case .senza, .con, .riesameDovuto:
            return true
        }
    }

    /// Posizioni e clienti che rispettano tutti i filtri, con i totali per canale. Senza un filtro di stato
    /// le posizioni chiuse non compaiono. I filtri sui clienti valgono anche per le posizioni (di quei clienti),
    /// i filtri sulle posizioni anche per i clienti (che ne hanno almeno una).
    static func applica(_ r: RicercaInterpretata, dati: DatiPrisma, oggi: Date = Date()) -> EsitoFiltri {
        guard r.conFiltri else { return EsitoFiltri() }
        let suPosizioni = r.filtriPosizioni
        let suClienti = r.filtriClienti
        var prodotti: [String: Prodotto] = [:]
        for x in dati.prodotti { prodotti[x.id] = x }
        let conStato = suPosizioni.contains { if case .stato = $0 { return true } else { return false } }

        // Aree in essere per cliente e riesami dovuti (solo se servono)
        var aree: [String: Set<AreaPosizione>] = [:]
        for p in dati.posizioni where p.stato == .inEssere { aree[p.clienteId, default: []].insert(p.area) }
        let dovuti: Set<String> = suClienti.contains(.riesameDovuto)
            ? Set(MotoreRiesame.dovuti(clienti: dati.clienti, posizioni: dati.posizioni, appuntamenti: dati.appuntamenti,
                                       incontri: dati.incontri, oggi: oggi).map(\.cliente.id))
            : []
        func clienteOK(_ id: String) -> Bool {
            suClienti.allSatisfy { f in
                switch f {
                case .senza(let a): return !(aree[id]?.contains(a) ?? false)
                case .con(let a): return aree[id]?.contains(a) ?? false
                case .riesameDovuto: return dovuti.contains(id)
                default: return true
                }
            }
        }
        func posizioneOK(_ p: Posizione) -> Bool {
            (conStato || p.stato != .chiusa)
                && suPosizioni.allSatisfy { rispetta(p, $0, prodotto: p.prodottoId.flatMap { prodotti[$0] }) }
        }

        var esito = EsitoFiltri()
        if !suPosizioni.isEmpty {
            esito.posizioni = dati.posizioni.filter { posizioneOK($0) && (suClienti.isEmpty || clienteOK($0.clienteId)) }
        }
        if !suClienti.isEmpty {
            let conPosizioni = Set(esito.posizioni.map(\.clienteId))
            esito.clienti = dati.clienti.filter { clienteOK($0.id) && (suPosizioni.isEmpty || conPosizioni.contains($0.id)) }
        }
        if !esito.posizioni.isEmpty {
            esito.totali = totali(esito.posizioni)
        } else if !esito.clienti.isEmpty {
            let ids = Set(esito.clienti.map(\.id))
            esito.totali = totali(dati.posizioni.filter { $0.stato == .inEssere && ids.contains($0.clienteId) })
            esito.totaliDeiClienti = true
        }
        return esito
    }

    /// Numero e valore (senza i debiti) delle posizioni per canale; solo i canali presenti.
    static func totali(_ posizioni: [Posizione]) -> [TotaleCanaleRicerca] {
        Canale.allCases.compactMap { c in
            let suoi = posizioni.filter { $0.canale == c }
            guard !suoi.isEmpty else { return nil }
            let valore = suoi.filter { !$0.area.passivo }.reduce(0) { $0 + $1.valore }
            return TotaleCanaleRicerca(canale: c, numero: suoi.count, valore: valore)
        }
    }

    /// La riga con i dati che contano per i filtri scritti: «Scade il 3 marzo 2027 · SRI 4 · Costi 2,1%».
    static func dettaglio(_ p: Posizione, filtri: [FiltroRicerca], prodotto: Prodotto?) -> String? {
        var pezzi: [String] = []
        for f in filtri {
            switch f {
            case .scade:
                if let s = p.scadenza { pezzi.append("Scade il \(Formati.dataEstesa.string(from: s))") }
            case .sri:
                if let n = sri(p, prodotto: prodotto) { pezzi.append("SRI \(n)") }
            case .costo:
                if let x = costo(p, prodotto: prodotto) { pezzi.append("Costi \(Formati.percentuale(x)) l'anno") }
            case .beneficiariVuoti:
                pezzi.append("Beneficiari da indicare")
            default:
                break
            }
        }
        if pezzi.isEmpty { pezzi.append(Formati.euro(p.valore)) }
        return pezzi.joined(separator: " · ")
    }

    // MARK: Prova

    /// Prova del parser e dei filtri sui dati di prova: l'elenco degli errori (vuoto = tutto bene).
    /// Da chiamare nel percorso di prova (per esempio `--prova-carico`).
    static func verifica() -> [String] {
        var errori: [String] = []
        func atteso(_ testo: String, _ filtri: [FiltroRicerca], parole: [String] = [], incompleti: [String] = []) {
            let r = interpreta(testo)
            if r.filtri != filtri || r.parole != parole || r.incompleti != incompleti {
                errori.append("«\(testo)» letto come filtri \(r.filtri), parole \(r.parole), incompleti \(r.incompleti)")
            }
        }
        atteso("scade:2027", [.scade(anno: 2027, mese: nil)])
        atteso("Scade:2027-03 rossi", [.scade(anno: 2027, mese: 3)], parole: ["rossi"])
        atteso("scade:03/2027", [.scade(anno: 2027, mese: 3)])
        atteso("sri>4 sri>=5", [.sri(.maggiore, 4), .sri(.maggioreUguale, 5)])
        atteso("sri > 4", [.sri(.maggiore, 4)])
        atteso("canale:alleanza", [.canale(.alleanza)])
        atteso("canale: indip", [.canale(.indipendente)])
        atteso("costo>2%", [.costo(.maggiore, 2)])
        atteso("costi>=1,5", [.costo(.maggioreUguale, 1.5)])
        atteso("beneficiari:vuoti", [.beneficiariVuoti])
        atteso("senza:previdenza", [.senza(.previdenza)])
        atteso("senza:protezione marco", [.senza(.protezione)], parole: ["marco"])
        atteso("riesame:dovuto", [.riesameDovuto])
        atteso("stato:proposta", [.stato(.proposta)])
        atteso("stato:inessere", [.stato(.inEssere)])
        atteso("stato:in essere", [.stato(.inEssere)])
        atteso("area:investimento", [.area(.investimento)])
        atteso("area:investimenti", [.area(.investimento)])
        atteso("area:liquidità", [.area(.liquidita)])
        atteso("scade:", [], incompleti: ["scade:"])
        atteso("sri>otto", [], incompleti: ["sri>otto"])
        atteso("area:pr", [], incompleti: ["area:pr"])
        atteso("scade:2027 canale:alleanza polizza", [.scade(anno: 2027, mese: nil), .canale(.alleanza)], parole: ["polizza"])
        atteso("ore 10:30 marco", [], parole: ["ore", "10:30", "marco"])
        atteso("giulia rossi", [], parole: ["giulia", "rossi"])

        // Suggerimenti e completamento
        let oggi = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28)) ?? Date()
        if !suggerimenti(per: "sc", oggi: oggi).contains(where: { $0.testo == "scade:" }) { errori.append("«sc» non propone «scade:»") }
        if suggerimenti(per: "canale:", oggi: oggi).map(\.testo) != ["canale:alleanza", "canale:indipendente"] { errori.append("«canale:» non propone i due canali") }
        if !suggerimenti(per: "marco ", oggi: oggi).isEmpty { errori.append("Dopo uno spazio non si propone niente") }
        if !suggerimenti(per: "canale:alleanza", oggi: oggi).isEmpty { errori.append("Un filtro già completo non si ripropone") }
        if completa("marco sc", con: SuggerimentoFiltro(testo: "scade:", descrizione: "", completo: false)) != "marco scade:" {
            errori.append("Il completamento sostituisce l'ultimo pezzo")
        }
        if completa("marco canale:a", con: SuggerimentoFiltro(testo: "canale:alleanza", descrizione: "")) != "marco canale:alleanza " {
            errori.append("Il completamento di un filtro completo aggiunge lo spazio")
        }

        // Filtri sui dati di prova
        let dati = DatiPrisma.demo()
        let alleanza = applica(interpreta("canale:alleanza"), dati: dati, oggi: oggi)
        if alleanza.posizioni.isEmpty || !alleanza.posizioni.allSatisfy({ $0.canale == .alleanza && $0.stato != .chiusa }) {
            errori.append("canale:alleanza: solo posizioni Alleanza non chiuse")
        }
        if alleanza.totali.map(\.canale) != [.alleanza] || alleanza.totali.first?.numero != alleanza.posizioni.count {
            errori.append("canale:alleanza: totale solo per Alleanza")
        }
        let senza = applica(interpreta("senza:previdenza"), dati: dati, oggi: oggi)
        let conPrevidenza = Set(dati.posizioni.filter { $0.stato == .inEssere && $0.area == .previdenza }.map(\.clienteId))
        if senza.clienti.contains(where: { conPrevidenza.contains($0.id) })
            || senza.clienti.count != Set(dati.clienti.map(\.id)).subtracting(conPrevidenza).count {
            errori.append("senza:previdenza: i clienti senza previdenza in essere")
        }
        let proposte = applica(interpreta("stato:proposta"), dati: dati, oggi: oggi)
        if !proposte.posizioni.allSatisfy({ $0.stato == .proposta }) { errori.append("stato:proposta: solo proposte") }
        let sri = applica(interpreta("sri>=5"), dati: dati, oggi: oggi)
        if !sri.posizioni.allSatisfy({ pos in
            (FiltriRicerca.sri(pos, prodotto: dati.prodotti.first { prod in prod.id == pos.prodottoId }) ?? 0) >= 5
        }) {
            errori.append("sri>=5: solo posizioni con SRI da 5 in su")
        }
        if !applica(interpreta("marco"), dati: dati, oggi: oggi).posizioni.isEmpty { errori.append("Senza filtri nessuna posizione filtrata") }
        return errori
    }
}
