import Foundation

/// Il motore dell'app Documenti: categoria dal testo, stato di ogni documento, elenco a gruppi con la ricerca,
/// scheda leggibile a sezioni e confronto dei documenti del cliente (identità e questionari) con il dossier.
/// Motore puro: niente stato dell'app né viste; le date arrivano come parametro. Il confronto di KID e polizze con
/// posizioni e schede è quello di `MotoreConfrontoDossier` (specifica 9): qui non si ripete.
enum MotoreDocumenti {

    // MARK: - Normalizzazione dei testi

    /// Minuscole, senza accenti né punteggiatura, spazi singoli; via le forme societarie («S.p.A.», «SpA», «S.r.l.»).
    static func normale(_ s: String) -> String {
        let piegato = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
        let soloLettere = String(piegato.map { $0.isLetter || $0.isNumber ? $0 : " " })
        var parole = soloLettere.split(separator: " ").map(String.init)
        // La forma societaria in coda (non «sgr», che fa parte del nome), solo se resta almeno una parola
        for forma in formeSocietarie where parole.count > forma.count && Array(parole.suffix(forma.count)) == forma {
            parole.removeLast(forma.count)
            break
        }
        return parole.joined(separator: " ")
    }

    private static let formeSocietarie: [[String]] = [["s", "p", "a"], ["spa"], ["s", "r", "l"], ["srl"]]

    /// Solo lettere e cifre, maiuscole («AL-2022/104851» → «AL2022104851»).
    static func compatto(_ s: String) -> String {
        s.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Le parole di un nome come insieme (per «Rossi Giulia» = «Giulia Rossi»).
    static func parole(_ s: String) -> Set<String> {
        Set(normale(s).split(separator: " ").map(String.init))
    }

    // MARK: - Categoria dal testo

    private static let segniIdentita = ["carta d'identità", "carta di identità", "carta d'identita", "carta di identita",
                                        "passaporto", "patente di guida", "permesso di soggiorno", "documento di riconoscimento"]
    private static let segniQuestionario = ["questionario", "profilazione", "profilatura", "mifid", "conoscenza ed esperienza",
                                            "valutazione di adeguatezza", "esigenze e bisogni assicurativi"]

    /// La categoria più probabile: il tipo trovato da `EstrattoreDocumento.tipoProbabile`, poi i segni dei documenti
    /// d'identità e dei questionari (che prevalgono su «polizza» o «contraente», non sul KID).
    static func categoriaProbabile(_ pagine: [String], tipo: Documento.Tipo) -> CategoriaDocumento {
        if tipo.creatoDaPrisma { return .prisma }
        let base = CategoriaDocumento.da(EstrattoreDocumento.tipoProbabile(pagine))
        if base == .kid { return .kid }
        let t = pagine.prefix(2).joined(separator: " ").lowercased().replacingOccurrences(of: "’", with: "'")
        if segniIdentita.contains(where: { t.contains($0) }) { return .identita }
        if segniQuestionario.contains(where: { t.contains($0) }) { return .questionario }
        return base
    }

    // MARK: - Stato e indicatori

    enum Stato: Equatable {
        case inLettura, illeggibile, conDifferenze(Int), daLeggere, collegato, letto
    }

    struct Indicatori: Equatable {
        let stato: Stato
        /// Dati letti non ancora confermati dal consulente.
        let daControllare: Int
        /// Righe del confronto da portare in Prisma (diverse o nuove, non lasciate come in Prisma): per KID e polizze
        /// `ConfrontoDossier.differenze` della specifica 9, per identità e questionari le `RigaCliente` aggiornabili
        /// non uguali (§5). Lo passa lo stato: il motore non conosce il confronto.
        let differenze: Int
        let collegato: Bool
        /// La categoria del documento (`genere`) e se non è ancora stato letto: servono ai testi dello stato.
        var categoria: CategoriaDocumento = .altro
        var nonLetto = false
    }

    static func indicatori(_ d: Documento, inLettura: Bool, collegato: Bool, differenze: Int) -> Indicatori {
        let daControllare = d.genere == .prisma ? 0 : d.campi.filter { !$0.confermato }.count
        let stato: Stato
        if inLettura {
            stato = .inLettura
        } else if d.lettura == .illeggibile {
            stato = .illeggibile
        } else if differenze > 0 {
            stato = .conDifferenze(differenze)
        } else if d.lettura == .daLeggere || daControllare > 0 {
            // Il confronto usa solo i dati confermati: con dati da confermare il documento resta «da leggere»
            stato = .daLeggere
        } else if collegato {
            stato = .collegato
        } else {
            stato = .letto
        }
        return Indicatori(stato: stato, daControllare: daControllare, differenze: max(0, differenze), collegato: collegato,
                          categoria: d.genere, nonLetto: d.lettura == .daLeggere)
    }

    // MARK: - Collegamento

    /// Identità e questionari sono del cliente per natura: non si collegano a posizioni o schede.
    static func delCliente(_ d: Documento) -> Bool { d.genere == .identita || d.genere == .questionario }

    // MARK: - Canale e area proposti

    /// Canale e area per creare una scheda, una posizione o una proposta da un documento. `posizione` e `prodotto` sono
    /// il bersaglio collegato o, se non c'è, quello suggerito dalla specifica 9 (li passa lo stato).
    static func canaleEArea(_ d: Documento, posizione: Posizione?, prodotto: Prodotto?) -> (canale: Canale, area: AreaPosizione) {
        // Il selettore delle aree non ha gli immobili né i debiti: con quelle aree si prosegue
        func utile(_ a: AreaPosizione) -> Bool { a != .immobili && !a.passivo }
        if let p = posizione, utile(p.area) { return (p.canale, p.area) }
        if let s = prodotto, utile(s.area) { return (s.canale, s.area) }
        let testo = (d.campi.map(\.valore) + [d.titolo]).joined(separator: " ").lowercased()
        let dalTesto: Canale = testo.contains("alleanza") ? .alleanza : .indipendente
        let canale: Canale = posizione?.canale ?? prodotto?.canale ?? dalTesto
        let area: AreaPosizione
        if testo.contains("pension") || testo.contains("previdenz") {
            area = .previdenza
        } else if d.campo(.capitaleAssicurato) != nil || testo.contains("infortun") || testo.contains("caso morte") {
            area = .protezione
        } else if testo.contains("rivalutabil") || testo.contains("risparmio") {
            area = .risparmio
        } else {
            area = .investimento
        }
        return (canale, area)
    }

    // MARK: - Elenco, raccolte e ricerca

    // `RaccoltaDocumenti` sta in Shell/VistaDocumenti.swift (la usa anche `VistaDocumenti`).

    struct Voce: Identifiable, Equatable {
        let documento: Documento
        let indicatori: Indicatori
        /// Canale e nome del bersaglio predefinito (`StatoShell.nomeBersaglio`); nil per i documenti del cliente o non collegati.
        let canale: Canale?
        let nomeCollegato: String?
        var id: String { documento.id }
    }

    struct Filtro: Equatable {
        var raccolta = RaccoltaDocumenti.tutti
        var categoria: CategoriaDocumento?
        var canale: Canale?
        var testo = ""
    }

    struct Gruppo: Identifiable, Equatable {
        let categoria: CategoriaDocumento
        let voci: [VoceTrovata]
        var id: String { categoria.rawValue }
    }

    struct VoceTrovata: Identifiable, Equatable {
        let voce: Voce
        /// «p. 3 · …dell'importo pagato al momento…» se la parola è solo nel testo del documento.
        let nelTesto: String?
        var id: String { voce.id }
    }

    /// Le voci che passano il filtro, a gruppi nell'ordine delle categorie, le più recenti prima.
    /// `pagine` dà il testo di un documento (letto dal disco senza tenerlo in memoria): si chiama solo se il testo
    /// cercato ha almeno 3 caratteri e non è nei titoli o nei dati.
    static func elenco(_ voci: [Voce], filtro: Filtro, pagine: (Documento) -> [String]) -> [Gruppo] {
        let cercate = normale(filtro.testo).split(separator: " ").map(String.init)
        let ancheNelTesto = filtro.testo.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
        var trovate: [VoceTrovata] = []
        for v in voci {
            // Raccolta, categoria e canale (in AND con la ricerca): prima i filtri leggeri, così il testo dal disco
            // si legge solo per le voci che possono passare
            guard appartiene(v, a: filtro.raccolta) else { continue }
            if let c = filtro.categoria, v.documento.genere != c { continue }
            if let c = filtro.canale, v.canale != c { continue }
            if cercate.isEmpty {
                trovate.append(VoceTrovata(voce: v, nelTesto: nil))
                continue
            }
            var parti: [String] = [v.documento.titolo]
            parti.append(contentsOf: v.documento.campi.map(\.valore))
            parti.append(v.documento.genere.breve)
            if let n = v.nomeCollegato { parti.append(n) }
            let fonte = normale(parti.joined(separator: " "))
            if cercate.allSatisfy({ fonte.contains($0) }) {
                trovate.append(VoceTrovata(voce: v, nelTesto: nil))
            } else if ancheNelTesto, let trovato = passo(cercate, in: pagine(v.documento)) {
                trovate.append(VoceTrovata(voce: v, nelTesto: trovato))
            }
        }
        return CategoriaDocumento.ordine.compactMap { c in
            let delGruppo = trovate.filter { $0.voce.documento.genere == c }.sorted {
                $0.voce.documento.importatoIl != $1.voce.documento.importatoIl
                    ? $0.voce.documento.importatoIl > $1.voce.documento.importatoIl
                    : $0.voce.documento.titolo < $1.voce.documento.titolo
            }
            return delGruppo.isEmpty ? nil : Gruppo(categoria: c, voci: delGruppo)
        }
    }

    /// La prima pagina che contiene tutte le parole: «p. N · …contesto…» (30 caratteri prima e 50 dopo la prima
    /// parola, dal testo originale con gli spazi compressi).
    private static func passo(_ cercate: [String], in pagine: [String]) -> String? {
        for (i, pagina) in pagine.enumerated() {
            let n = normale(pagina)
            guard cercate.allSatisfy({ n.contains($0) }) else { continue }
            let compresso = pagina.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            guard let prima = cercate.first,
                  let r = compresso.range(of: prima, options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano) else {
                return "p. \(i + 1)"
            }
            let inizio = compresso.index(r.lowerBound, offsetBy: -30, limitedBy: compresso.startIndex) ?? compresso.startIndex
            let fine = compresso.index(r.upperBound, offsetBy: 50, limitedBy: compresso.endIndex) ?? compresso.endIndex
            return "p. \(i + 1) · …\(compresso[inizio..<fine])…"
        }
        return nil
    }

    /// Quante voci ha ogni raccolta, categoria e canale (la barra laterale).
    static func conteggi(_ voci: [Voce]) -> (raccolte: [RaccoltaDocumenti: Int], categorie: [CategoriaDocumento: Int], canali: [Canale: Int]) {
        var raccolte: [RaccoltaDocumenti: Int] = [:]
        for r in RaccoltaDocumenti.allCases { raccolte[r] = voci.filter { appartiene($0, a: r) }.count }
        var categorie: [CategoriaDocumento: Int] = [:]
        var canali: [Canale: Int] = [:]
        for v in voci {
            categorie[v.documento.genere, default: 0] += 1
            if let c = v.canale { canali[c, default: 0] += 1 }
        }
        return (raccolte, categorie, canali)
    }

    static func appartiene(_ v: Voce, a r: RaccoltaDocumenti) -> Bool {
        let i = v.indicatori
        let genere = v.documento.genere
        switch r {
        case .tutti:
            return true
        case .daLeggere:
            return i.daControllare > 0 || v.documento.lettura == .daLeggere || i.stato == .inLettura
        case .conDifferenze:
            return i.differenze > 0
        case .daCollegare:
            return !i.collegato && [.kid, .contratto, .estratto, .altro].contains(genere)
        case .collegati:
            // Identità e questionari sono del cliente per natura: non contano tra i collegati
            return i.collegato && genere != .identita && genere != .questionario
        }
    }

    // MARK: - La scheda leggibile

    struct RigaScheda: Identifiable, Equatable {
        let campo: CampoEstratto
        /// Il valore da leggere («150.000 €», «0,85%», «3 su 7», «1 dicembre 2025»).
        let testo: String
        /// Una lettura in più sotto il valore (facoltativa).
        let nota: String?
        var id: String { campo.chiave.rawValue }
    }

    struct SezioneScheda: Identifiable, Equatable {
        let sezione: SezioneDocumento
        let righe: [RigaScheda]
        /// Letture della sezione nel suo insieme (rischio contro il profilo, costi nel tempo…).
        let note: [String]
        var id: String { sezione.rawValue }
    }

    static func scheda(_ d: Documento, cliente: Cliente?, oggi: Date) -> [SezioneScheda] {
        guard d.genere != .prisma else { return [] }
        return SezioneDocumento.allCases.compactMap { s in
            let campi = CampoDocumento.allCases.filter { $0.sezione == s }.compactMap { d.campo($0) }
            guard !campi.isEmpty else { return nil }
            let righe = campi.map { RigaScheda(campo: $0, testo: testo($0), nota: notaRiga($0, documento: d, oggi: oggi)) }
            return SezioneScheda(sezione: s, righe: righe, note: noteSezione(s, documento: d, cliente: cliente, oggi: oggi))
        }
    }

    /// I dati che un documento di questa categoria di solito riporta.
    static func attesi(_ c: CategoriaDocumento) -> [CampoDocumento] {
        switch c {
        case .kid:
            return [.nomeProdotto, .emittente, .sri, .periodoDetenzione, .costoIngresso, .costoUscita, .costoAnnuo,
                    .incidenzaCosti, .rendimentoModerato]
        case .contratto:
            return [.nomeProdotto, .numeroContratto, .contraente, .assicurato, .beneficiari, .decorrenza, .scadenza,
                    .premio, .capitaleAssicurato]
        case .estratto:
            return [.numeroContratto, .controvalore, .dataValore, .totaleVersato]
        case .identita:
            return [.numeroDocumento, .intestatario, .dataRilascio, .scadenza]
        case .questionario:
            return [.dataDocumento, .profiloRischio, .orizzonte]
        case .altro, .prisma:
            return []
        }
    }

    /// Gli attesi che il documento non ha (per «Aggiungi a mano»).
    static func mancanti(_ d: Documento) -> [CampoDocumento] {
        attesi(d.genere).filter { d.campo($0) == nil }
    }

    /// Il valore di un campo da leggere.
    static func testo(_ c: CampoEstratto) -> String {
        let v = c.valore.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.chiave.data {
            return EstrattoreDocumento.data(v).map { Formati.dataEstesa.string(from: $0) } ?? v
        }
        switch c.chiave.unita {
        case "€":
            guard let n = EstrattoreDocumento.numero(v) else { return v }
            let importo = n == n.rounded() ? Formati.euro(n) : Formati.euroDecimali(n)
            if c.chiave == .premio, let f = MotoreConfrontoDossier.frequenzaPremio(c.estratto) {
                return importo + dopoIlPremio(f)
            }
            return importo
        case "%":
            return "\(v)%"
        case "su 7":
            return "\(v) su 7"
        case "anni":
            return v == "1" ? "1 anno" : "\(v) anni"
        default:
            break
        }
        if c.chiave == .profiloRischio { return maiuscolaIniziale(v) }
        return v
    }

    private static func dopoIlPremio(_ f: Frequenza) -> String {
        switch f {
        case .annuale: return " l'anno"
        case .mensile: return " al mese"
        case .trimestrale: return " al trimestre"
        case .semestrale: return " al semestre"
        case .unica: return " · premio unico"
        }
    }

    private static func maiuscolaIniziale(_ s: String) -> String {
        s.prefix(1).uppercased() + s.dropFirst()
    }

    /// Classi dell'indicatore sintetico di rischio del KID (Reg. delegato (UE) 2017/653, allegato III).
    private static func letturaSRI(_ n: Int) -> String? {
        switch n {
        case 1: return "la più bassa"
        case 2: return "bassa"
        case 3: return "medio-bassa"
        case 4: return "media"
        case 5: return "medio-alta"
        case 6: return "la seconda più alta"
        case 7: return "la più alta"
        default: return nil
        }
    }

    private static func notaRiga(_ c: CampoEstratto, documento d: Documento, oggi: Date) -> String? {
        switch c.chiave {
        case .sri:
            guard let n = Int(c.valore.trimmingCharacters(in: .whitespaces)), let l = letturaSRI(n) else { return nil }
            return "Classe \(n) su 7: \(l)."
        case .rendimentoModerato:
            return "È una stima del KID al netto dei costi, non una promessa."
        case .scadenza:
            guard let s = EstrattoreDocumento.data(c.valore) else { return nil }
            return quandoScade(s, oggi: oggi)
        default:
            return nil
        }
    }

    /// «Tra 12 giorni.», «Tra 1 anno e 2 mesi.», «Scaduta da 5 giorni.»
    static func quandoScade(_ scadenza: Date, oggi: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let da = cal.startOfDay(for: oggi)
        let a = cal.startOfDay(for: scadenza)
        let giorni = cal.dateComponents([.day], from: da, to: a).day ?? 0
        if giorni == 0 { return "Scade oggi." }
        if giorni < 0 { return -giorni == 1 ? "Scaduta da 1 giorno." : "Scaduta da \(-giorni) giorni." }
        if giorni <= 60 { return giorni == 1 ? "Tra 1 giorno." : "Tra \(giorni) giorni." }
        let parti = cal.dateComponents([.year, .month], from: da, to: a)
        let anni = parti.year ?? 0
        let mesi = parti.month ?? 0
        var pezzi: [String] = []
        if anni > 0 { pezzi.append(anni == 1 ? "1 anno" : "\(anni) anni") }
        if mesi > 0 { pezzi.append(mesi == 1 ? "1 mese" : "\(mesi) mesi") }
        if pezzi.isEmpty { return "Tra \(giorni) giorni." }
        return "Tra \(pezzi.joined(separator: " e "))."
    }

    /// Giorni da oggi alla data (negativi se passata).
    private static func giorniDa(_ oggi: Date, a data: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        return cal.dateComponents([.day], from: cal.startOfDay(for: oggi), to: cal.startOfDay(for: data)).day ?? 0
    }

    /// Un numero con due decimali e la virgola («4,08»).
    private static func dueDecimali(_ x: Double) -> String {
        String(format: "%.2f", x).replacingOccurrences(of: ".", with: ",")
    }

    private static func noteSezione(_ s: SezioneDocumento, documento d: Documento, cliente: Cliente?, oggi: Date) -> [String] {
        var note: [String] = []
        let nomeCliente = cliente?.nome.trimmingCharacters(in: .whitespaces) ?? ""
        let nome = nomeCliente.isEmpty ? "il cliente" : nomeCliente
        switch s {
        case .rischio:
            if let n = d.campo(.sri).flatMap({ Int($0.valore.trimmingCharacters(in: .whitespaces)) }),
               let p = cliente?.profilo.propensione {
                let m = MotoreCoerenza.sriMassimo(p)
                note.append(n <= m
                            ? "Adatto a una propensione \(p.nome.lowercased()) (fino a \(m))."
                            : "Sopra il rischio adatto a una propensione \(p.nome.lowercased()) (fino a \(m)).")
            }
            if let a = d.campo(.periodoDetenzione).flatMap({ MotoreConfrontoDossier.anni($0.valore) }),
               let o = cliente?.profilo.orizzonteAnni {
                note.append(a > o
                            ? "Più lungo dell'orizzonte di \(nome) (\(o) anni): uscire prima può costare."
                            : "Dentro l'orizzonte di \(nome) (\(o) anni).")
            }
            if let profilo = d.campo(.profiloRischio), let cliente {
                if let p = cliente.profilo.propensione {
                    note.append(propensione(profilo.valore) == p ? "Coincide con il profilo nel dossier." : "Nel dossier: \(p.nome.lowercased()).")
                } else {
                    note.append("Nel dossier il profilo non c'è.")
                }
            }
        case .costi:
            if let incidenza = d.campo(.incidenzaCosti)?.valore.trimmingCharacters(in: .whitespaces),
               let a = d.campo(.periodoDetenzione).flatMap({ MotoreConfrontoDossier.anni($0.valore) }) {
                note.append("Su \(a) anni i costi tolgono circa \(incidenza) punti di rendimento ogni anno.")
            }
            // La scheda mostra ciò che il documento dice: anche i dati da confermare
            if let lordo = MotoreConfrontoDossier.rendimentoLordo(d, soloConfermati: false) {
                switch lordo.fonte {
                case .kid:
                    note.append("Prima dei costi il KID indica il \(dueDecimali(lordo.valore))% l'anno.")
                case .stima:
                    note.append("Prima dei costi rende circa il \(dueDecimali(lordo.valore))% l'anno (stima di Prisma dallo scenario moderato, che è al netto dei costi).")
                }
            }
        case .scadenze:
            if d.genere == .identita, let s = d.campo(.scadenza).flatMap({ EstrattoreDocumento.data($0.valore) }),
               giorniDa(oggi, a: s) <= 90 {
                note.append("Per l'adeguata verifica serve un documento in corso di validità (D.Lgs. 231/2007, art. 19).")
            }
        case .chi, .cosa, .cifre:
            break
        }
        return note
    }

    // MARK: - Profilo del questionario

    /// La propensione di Prisma da una parola del questionario (nil se non si riconosce). È una corrispondenza di
    /// lavoro tra le parole dei questionari e le quattro propensioni di Prisma: non cambia il profilo da sola.
    static func propensione(_ parola: String) -> ProfiloInvestitore.Propensione? {
        switch normale(parola) {
        case "prudente", "conservativo", "conservativa", "basso", "bassa":
            return .prudente
        case "moderato", "moderata", "medio basso", "medio bassa", "medio", "media", "bilanciato", "bilanciata",
             "equilibrato", "equilibrata":
            return .moderata
        case "dinamico", "dinamica", "medio alto", "medio alta":
            return .dinamica
        case "aggressivo", "aggressiva", "alto", "alta":
            return .aggressiva
        default:
            return nil
        }
    }
}

// MARK: - Testi dello stato

extension MotoreDocumenti.Stato {
    /// La pillola dello stato.
    var etichetta: String {
        switch self {
        case .inLettura: return "In lettura…"
        case .illeggibile: return "Testo non leggibile"
        case .conDifferenze(let n): return n == 1 ? "1 differenza" : "\(n) differenze"
        case .daLeggere: return "Da leggere"
        case .collegato: return "Collegato"
        case .letto: return "Letto"
        }
    }

    /// La riga accanto alla pillola. `nome` è il nome del collegato (posizione o scheda), nil se non c'è.
    func nota(_ i: MotoreDocumenti.Indicatori, nome: String?) -> String {
        let delCliente = i.categoria == .identita || i.categoria == .questionario
        switch self {
        case .inLettura:
            return "Prisma sta leggendo il testo sul Mac"
        case .illeggibile:
            return "Serve una scansione più nitida o il PDF originale"
        case .conDifferenze:
            if delCliente { return "con il dossier" }
            return nome.map { "con «\($0)»" } ?? ""
        case .daLeggere:
            if i.daControllare > 0 {
                return i.daControllare == 1 ? "1 dato da controllare" : "\(i.daControllare) dati da controllare"
            }
            return "Non ancora letto"
        case .collegato:
            if delCliente { return "al dossier del cliente" }
            return nome.map { "a «\($0)»" } ?? ""
        case .letto:
            return [.kid, .contratto, .estratto].contains(i.categoria) ? "Da collegare a una posizione o a una scheda" : ""
        }
    }
}

// MARK: - Identità e questionari contro il dossier e «In regola»

extension MotoreDocumenti {
    /// Una riga «Nel documento / Nel dossier» di un documento del cliente.
    struct RigaCliente: Identifiable, Equatable {
        enum Esito: Equatable { case uguale, diverso, nuovo, indicativo, daConfermare }
        let campo: CampoDocumento
        let etichetta: String
        let nelDocumento: String
        /// «—» se nel dossier manca.
        let nelDossier: String
        let esito: Esito
        let pagina: Int
        /// Si porta nel dossier con un clic: confermato, diverso o nuovo, e (per i questionari) con il canale scelto.
        let aggiornabile: Bool
        let nota: String?
        var id: String { campo.rawValue }
    }

    /// Note di sezione della tabella (sotto le righe).
    static let notaIdentita = "Per l'adeguata verifica serve un documento d'identità in corso di validità (D.Lgs. 231/2007, art. 19, c. 1, lett. a)."
    static let notaQuestionario = "Ogni canale ha il suo questionario: Alleanza per i prodotti d'investimento assicurativi (art. 121-septies del Codice delle assicurazioni private), la consulenza indipendente per gli strumenti finanziari (art. 25, par. 2, Dir. 2014/65/UE; art. 54 Reg. delegato (UE) 2017/565). La validità la decidono le regole di «In regola»."
    static let notaScegliCanale = "Scegli il canale del questionario."
    static let notaIntestatario = "Il nome nel documento è diverso da quello del dossier: verifica."
    static let notaScaduto = "Documento scaduto: chiedine uno valido al cliente."
    static let notaDataIllegibile = "La data non si legge: correggila nella scheda «Dati»."
    static let notaProfiloSconosciuto = "Parola non riconosciuta: si aggiorna solo l'esito del questionario, non la propensione."

    /// Le note di sezione della tabella di un documento del cliente ([] per gli altri documenti).
    static func noteCliente(_ d: Documento) -> [String] {
        switch d.genere {
        case .identita: return [notaIdentita]
        case .questionario: return [notaQuestionario]
        default: return []
        }
    }

    /// Come si confronta un dato con il dossier, prima di guardare la conferma.
    private enum Paragone { case vuoto, uguale, diverso, indicativo }

    private static func riga(_ x: CampoEstratto, dossier: String?, paragone: Paragone, aggiornabileSe: Bool,
                             indicativoAggiornabile: Bool = false, nota: String? = nil) -> RigaCliente {
        let nelDossier = dossier.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? "—"
        let esito: RigaCliente.Esito
        if !x.confermato {
            esito = .daConfermare
        } else {
            switch paragone {
            case .vuoto: esito = .nuovo
            case .uguale: esito = .uguale
            case .diverso: esito = .diverso
            case .indicativo: esito = .indicativo
            }
        }
        let aggiornabile = aggiornabileSe && (esito == .diverso || esito == .nuovo || (esito == .indicativo && indicativoAggiornabile))
        return RigaCliente(campo: x.chiave, etichetta: x.chiave.nome, nelDocumento: testo(x), nelDossier: nelDossier,
                           esito: esito, pagina: x.pagina, aggiornabile: aggiornabile, nota: nota)
    }

    private static func dataTesto(_ d: Date?) -> String? { d.map { Formati.dataEstesa.string(from: $0) } }

    /// Il confronto di una data letta con una del dossier (stesso giorno = uguale).
    private static func paragonaData(_ letta: Date?, _ nelDossier: Date?) -> Paragone {
        guard let letta else { return .indicativo }
        guard let nelDossier else { return .vuoto }
        return Calendar.current.isDate(letta, inSameDayAs: nelDossier) ? .uguale : .diverso
    }

    static func righeCliente(_ d: Documento, cliente c: Cliente, canale: Canale?, oggi: Date = Date()) -> [RigaCliente] {
        switch d.genere {
        case .identita: return righeIdentita(d, cliente: c, oggi: oggi)
        case .questionario: return righeQuestionario(d, cliente: c, canale: canale)
        default: return []
        }
    }

    private static func righeIdentita(_ d: Documento, cliente c: Cliente, oggi: Date) -> [RigaCliente] {
        let doc = c.conformita?.documento
        var righe: [RigaCliente] = []
        for chiave in CampoDocumento.allCases {
            guard let x = d.campo(chiave) else { continue }
            let v = x.valore.trimmingCharacters(in: .whitespaces)
            switch chiave {
            case .numeroDocumento:
                let n = doc?.numero ?? ""
                let p: Paragone = compatto(n).isEmpty ? .vuoto : (compatto(n) == compatto(v) ? .uguale : .diverso)
                righe.append(riga(x, dossier: n, paragone: p, aggiornabileSe: !compatto(v).isEmpty))
            case .dataRilascio:
                let letta = EstrattoreDocumento.data(v)
                let p = paragonaData(letta, doc?.rilasciatoIl)
                righe.append(riga(x, dossier: dataTesto(doc?.rilasciatoIl), paragone: p, aggiornabileSe: letta != nil,
                                  nota: letta == nil ? notaDataIllegibile : nil))
            case .scadenza:
                let letta = EstrattoreDocumento.data(v)
                let p = paragonaData(letta, doc?.scadenza)
                let nota: String?
                if letta == nil { nota = notaDataIllegibile } else if let s = letta, giorniDa(oggi, a: s) < 0 { nota = notaScaduto } else { nota = nil }
                righe.append(riga(x, dossier: dataTesto(doc?.scadenza), paragone: p, aggiornabileSe: letta != nil, nota: nota))
            case .codiceFiscale:
                let nelDossier = c.codiceFiscale.trimmingCharacters(in: .whitespaces)
                let p: Paragone = nelDossier.isEmpty ? .vuoto : (nelDossier.uppercased() == v.uppercased() ? .uguale : .diverso)
                righe.append(riga(x, dossier: nelDossier, paragone: p, aggiornabileSe: EstrattoreDocumento.formaCodiceFiscaleValida(v)))
            case .intestatario:
                // Il nome non si porta nel dossier: se è diverso si segnala soltanto
                let nome = c.nome.trimmingCharacters(in: .whitespaces)
                let p: Paragone = nome.isEmpty ? .vuoto : (parole(nome) == parole(v) ? .uguale : .indicativo)
                righe.append(riga(x, dossier: nome, paragone: p, aggiornabileSe: false,
                                  nota: p == .indicativo && x.confermato ? notaIntestatario : nil))
            default:
                continue
            }
        }
        return righe
    }

    private static func righeQuestionario(_ d: Documento, cliente c: Cliente, canale: Canale?) -> [RigaCliente] {
        let q = canale.flatMap { c.conformita?.questionario($0) }
        var righe: [RigaCliente] = []
        for chiave in CampoDocumento.allCases {
            guard let x = d.campo(chiave) else { continue }
            let v = x.valore.trimmingCharacters(in: .whitespaces)
            switch chiave {
            case .dataDocumento:
                let letta = EstrattoreDocumento.data(v)
                let p = paragonaData(letta, q?.compilatoIl)
                let nota: String? = canale == nil ? notaScegliCanale : (letta == nil ? notaDataIllegibile : nil)
                righe.append(riga(x, dossier: dataTesto(q?.compilatoIl), paragone: p,
                                  aggiornabileSe: canale != nil && letta != nil, nota: nota))
            case .profiloRischio:
                let esito = q?.esito?.trimmingCharacters(in: .whitespaces) ?? ""
                var partiDossier: [String] = []
                if !esito.isEmpty { partiDossier.append(esito) }
                if let prop = c.profilo.propensione { partiDossier.append("propensione \(prop.nome.lowercased())") }
                let dossier = partiDossier.joined(separator: " · ")
                let riconosciuta = propensione(v)
                let stessoEsito = !esito.isEmpty && normale(esito) == normale(v)
                let p: Paragone
                if riconosciuta == nil {
                    p = stessoEsito ? .uguale : .indicativo
                } else if esito.isEmpty {
                    p = .vuoto
                } else {
                    p = stessoEsito && riconosciuta == c.profilo.propensione ? .uguale : .diverso
                }
                let nota: String? = canale == nil ? notaScegliCanale : (riconosciuta == nil && p == .indicativo ? notaProfiloSconosciuto : nil)
                righe.append(riga(x, dossier: dossier, paragone: p, aggiornabileSe: canale != nil && !v.isEmpty,
                                  indicativoAggiornabile: true, nota: nota))
            case .orizzonte:
                let letti = MotoreConfrontoDossier.anni(v)
                let nelDossier = c.profilo.orizzonteAnni
                let p: Paragone
                if letti == nil { p = .indicativo } else if let o = nelDossier { p = o == letti ? .uguale : .diverso } else { p = .vuoto }
                righe.append(riga(x, dossier: nelDossier.map { $0 == 1 ? "1 anno" : "\($0) anni" }, paragone: p,
                                  aggiornabileSe: letti != nil))
            default:
                continue
            }
        }
        return righe
    }

    /// Porta nel cliente le righe scelte che sono aggiornabili (ricalcolate qui: una scelta vecchia non scrive valori
    /// sbagliati). Restituisce i campi applicati, nell'ordine di `CampoDocumento.allCases`.
    @discardableResult
    static func applicaCliente(_ campi: Set<CampoDocumento>, da d: Documento, a c: inout Cliente, canale: Canale?) -> [CampoDocumento] {
        let righe = righeCliente(d, cliente: c, canale: canale).filter { campi.contains($0.campo) && $0.aggiornabile }
        guard !righe.isEmpty else { return [] }
        var applicati: [CampoDocumento] = []
        var conformita = c.conformita ?? ConformitaCliente()
        var toccaConformita = false
        switch d.genere {
        case .identita:
            var doc = conformita.documento ?? DocumentoIdentita()
            var toccaDocumento = false
            for r in righe {
                guard let v = d.campo(r.campo)?.valore.trimmingCharacters(in: .whitespaces) else { continue }
                switch r.campo {
                case .numeroDocumento:
                    doc.numero = v.uppercased()
                    toccaDocumento = true
                case .dataRilascio:
                    guard let data = EstrattoreDocumento.data(v) else { continue }
                    doc.rilasciatoIl = ValoriDaDocumento.mezzogiorno(data)
                    toccaDocumento = true
                case .scadenza:
                    guard let data = EstrattoreDocumento.data(v) else { continue }
                    doc.scadenza = ValoriDaDocumento.mezzogiorno(data)
                    toccaDocumento = true
                case .codiceFiscale:
                    c.codiceFiscale = v.uppercased()
                default:
                    continue
                }
                applicati.append(r.campo)
            }
            if toccaDocumento {
                doc.tipo = tipoIdentita(d) ?? doc.tipo
                conformita.documento = doc
                toccaConformita = true
            }
        case .questionario:
            for r in righe {
                guard let v = d.campo(r.campo)?.valore.trimmingCharacters(in: .whitespaces) else { continue }
                switch r.campo {
                case .dataDocumento:
                    guard let canale, let data = EstrattoreDocumento.data(v) else { continue }
                    var q = conformita.questionario(canale) ?? QuestionarioAdeguatezza()
                    q.compilatoIl = ValoriDaDocumento.mezzogiorno(data)
                    conformita.impostaQuestionario(q, canale: canale)
                    toccaConformita = true
                case .profiloRischio:
                    guard let canale else { continue }
                    var q = conformita.questionario(canale) ?? QuestionarioAdeguatezza()
                    q.esito = maiuscolaIniziale(v.lowercased())
                    conformita.impostaQuestionario(q, canale: canale)
                    toccaConformita = true
                    // Una parola non riconosciuta aggiorna solo l'esito, non la propensione
                    if let p = propensione(v) { c.profilo.propensione = p }
                case .orizzonte:
                    guard let anni = MotoreConfrontoDossier.anni(v) else { continue }
                    c.profilo.orizzonteAnni = anni
                default:
                    continue
                }
                applicati.append(r.campo)
            }
        default:
            return []
        }
        if toccaConformita { c.conformita = conformita }
        return CampoDocumento.allCases.filter { applicati.contains($0) }
    }

    /// Il testo con cui si riconoscono tipo e canale: titolo, valori e righe dei dati letti.
    private static func testoDeiDati(_ d: Documento) -> String {
        ([d.titolo] + d.campi.flatMap { [$0.valore, $0.estratto] }).joined(separator: " ")
            .lowercased().replacingOccurrences(of: "’", with: "'")
    }

    /// Il tipo del documento d'identità dal titolo e dalle righe dei dati letti: «passaporto» → `.passaporto`,
    /// «patente» → `.patente`, «carta d'identità»/«carta di identità» → `.cartaIdentita`; altrimenti nil.
    static func tipoIdentita(_ d: Documento) -> TipoDocumentoIdentita? {
        let t = testoDeiDati(d)
        if t.contains("passaporto") { return .passaporto }
        if t.contains("patente") { return .patente }
        if ["carta d'identità", "carta di identità", "carta d'identita", "carta di identita"].contains(where: { t.contains($0) }) {
            return .cartaIdentita
        }
        return nil
    }

    /// Il canale di un questionario: «alleanza» nel titolo o nel testo dei dati → `.alleanza`; «mifid», «consulenza
    /// finanziaria», «consulente finanziario autonomo» → `.indipendente`; altrimenti nil (lo sceglie il consulente).
    static func canaleQuestionario(_ d: Documento) -> Canale? {
        let t = testoDeiDati(d)
        if t.contains("alleanza") { return .alleanza }
        if ["mifid", "consulenza finanziaria", "consulente finanziario autonomo"].contains(where: { t.contains($0) }) {
            return .indipendente
        }
        return nil
    }
}
