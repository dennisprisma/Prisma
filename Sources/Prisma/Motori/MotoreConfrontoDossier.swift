import Foundation

// MARK: - Tipi del confronto «Nel documento / In Prisma» (specifica 9, giro 5)

/// L'esito di una riga del confronto.
enum EsitoRiga: Equatable {
    /// Stesso valore (entro la tolleranza).
    case uguale
    /// Valori diversi.
    case diverso
    /// In Prisma manca, il documento lo riporta.
    case nuovo
    /// Diverso o nuovo, ma il consulente ha lasciato il dato di Prisma (la `chiave` è in `vociTenute`).
    case tenuto
    /// Il documento lo riporta, ma il dato non è confermato.
    case daConfermare
    /// Confermato, ma il valore non si legge come numero, data o classe valida.
    case illeggibile
}

/// Una riga della tabella (non `RigaConfronto`: il nome c'è già in AppConfronti).
struct RigaDossier: Identifiable, Equatable {
    let voce: VoceDossier
    var id: String { voce.rawValue }
    /// Valore del documento (nil se da confermare o illeggibile).
    let documento: ValoreVoce?
    /// Il testo del dato com'è nel documento (per le righe da confermare o illeggibili).
    let testoDocumento: String
    /// Valore di Prisma usato nel confronto (nil = vuoto).
    let prisma: ValoreVoce?
    let esito: EsitoRiga
    let pagina: Int
    let estratto: String
    /// Documento − Prisma: punti percentuali, classi, anni; per il premio euro all'anno; nil per testi e date
    /// o se uno dei due manca.
    let differenza: Double?
    /// Rischio o costi che salgono, o capitale assicurato che scende.
    let peggiora: Bool
    let preselezionata: Bool
    /// Avvertenza della riga (beneficiari, rendimento lordo, multiramo, frequenza del premio).
    let nota: String?
    /// «voce|documento|prisma» con i due valori normalizzati (testi senza maiuscole, accenti e punteggiatura, numeri
    /// con due decimali e il punto, date «aaaa-mm-gg», premio «numero frequenza», vuoto «-»): è ciò che «Lascia come
    /// in Prisma» ricorda.
    let chiave: String

    var aggiornabile: Bool { esito == .diverso || esito == .nuovo }
}

/// Il confronto di un documento con una posizione o una scheda prodotto.
struct ConfrontoDossier: Equatable {
    let bersaglio: BersaglioConfronto
    let righe: [RigaDossier]
    /// Voci che il documento non riporta (tra quelle che il bersaglio può avere).
    let mancanti: [VoceDossier]

    var differenze: Int { righe.filter(\.aggiornabile).count }
    var allineato: Bool { !righe.isEmpty && righe.allSatisfy { $0.esito == .uguale || $0.esito == .tenuto } }
    var preselezione: Set<VoceDossier> { Set(righe.filter(\.preselezionata).map(\.voce)) }
    func riga(_ v: VoceDossier) -> RigaDossier? { righe.first { $0.voce == v } }
}

/// Un aumento di rischio o di costo tra la scheda e il nuovo KID.
struct AumentoKID: Equatable {
    let voce: VoceDossier
    let prima: Double
    let dopo: Double
}

/// Una posizione o una proposta toccata dal nuovo KID.
struct PosizioneToccata: Identifiable, Equatable {
    let id: String
    let nome: String
    let canale: Canale
    let stato: StatoPosizione
    let esito: EsitoProposta?
    /// Collegata per nome (stesso nome e canale, senza `prodottoId`), non dalla scheda.
    let perNome: Bool
    /// In essere il valore; per una proposta il versamento iniziale più i premi di un anno.
    let base: Double
    let costoAnnuoInPiu: Double
    let ingressoInPiu: Double
}

/// Un cliente con posizioni o proposte del prodotto.
struct ImpattoCliente: Identifiable, Equatable {
    let clienteId: String
    var id: String { clienteId }
    let nome: String
    /// Prima le proposte aperte, poi le in essere; per nome.
    let posizioni: [PosizioneToccata]
    /// SRI massimo del profilo (nil se la propensione non c'è).
    let sriMassimo: Int?
    /// Il nuovo SRI supera il massimo del profilo.
    let oltreProfilo: Bool
    var costoAnnuoInPiu: Double { posizioni.reduce(0) { $0 + $1.costoAnnuoInPiu } }
    var ingressoInPiu: Double { posizioni.reduce(0) { $0 + $1.ingressoInPiu } }
    var proposteAperte: Int { posizioni.filter { $0.stato == .proposta }.count }
}

/// L'impatto di un nuovo KID sui clienti.
struct EsitoImpatto: Equatable {
    let aumenti: [AumentoKID]
    /// Per costo annuo in più decrescente, poi per nome.
    let clienti: [ImpattoCliente]
    var posizioni: Int { clienti.reduce(0) { $0 + $1.posizioni.count } }
    var costoAnnuoInPiu: Double { clienti.reduce(0) { $0 + $1.costoAnnuoInPiu } }
    var ingressoInPiu: Double { clienti.reduce(0) { $0 + $1.ingressoInPiu } }
}

// MARK: - Motore

/// Documento contro dossier: confronta i dati confermati di un KID, di una polizza o di un'appendice con la posizione
/// o la scheda prodotto collegata, porta in Prisma le voci scelte (con lo storico e il ripristino) e misura l'impatto
/// di un nuovo KID sui clienti. Solo funzioni pure: niente stato, niente interfaccia, le date arrivano come parametro.
enum MotoreConfrontoDossier {
    /// Punti: "0,80" e "0,804" sono uguali.
    static let tolleranzaPercento = 0.005
    /// Punti: il rendimento lordo è una stima, sotto questo scarto è «uguale».
    static let tolleranzaLordo = 0.25
    static let tolleranzaEuro = 0.5
    /// L'avviso in Prodotti resta per 90 giorni dall'aggiornamento.
    static let giorniAvvisoKID = 90
    /// Scadenza delle attività create dall'impatto.
    static let giorniAttivita = 7
    /// Parole che non distinguono due emittenti.
    static let paroleGeneriche: Set<String> = ["spa", "sgr", "sicav", "sa", "ag", "plc", "ltd", "srl", "assicurazioni",
        "assicurazione", "compagnia", "gruppo", "group", "asset", "management", "italia", "del", "della", "di"]

    /// Da dove viene il rendimento lordo del documento.
    enum FonteLordo: Equatable { case kid, stima }

    /// Perché Prisma suggerisce un collegamento.
    enum MotivoCollegamento: Equatable { case collegamento, numeroContratto, nome, nomeEdEmittente }

    /// Il valore del documento per una voce, con la pagina e la riga da cui viene.
    typealias LetturaVoce = (valore: ValoreVoce?, testo: String, pagina: Int, estratto: String, esito: EsitoRiga?,
                             frequenzaDedotta: Bool)

    /// Il testo con cui `ValoreVoce.testo` segna la fonte del rendimento lordo del documento.
    static let fonteKID = "kid"
    static let fonteStima = "stima"

    // MARK: Letture

    /// Un documento confrontabile: KID e polizze (appendici comprese).
    static func confrontabile(_ d: Documento) -> Bool { d.tipo == .kid || d.tipo == .polizza }

    /// Frequenza scritta accanto al premio, dalla riga del documento (senza maiuscole e senza accenti, nell'ordine):
    /// «unico» o «unica soluzione» → premio unico; «mensil…»; «trimestral…»; «semestral…»; «annu…» o «annual…»;
    /// altrimenti nil.
    static func frequenzaPremio(_ estratto: String) -> Frequenza? {
        let t = estratto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
        func c(_ schema: String) -> Bool { t.range(of: schema, options: .regularExpression) != nil }
        if c(#"\bunico\b"#) || c(#"\bunica soluzione\b"#) { return .unica }
        if c(#"\bmensil"#) { return .mensile }
        if c(#"\btrimestral"#) { return .trimestrale }
        if c(#"\bsemestral"#) { return .semestrale }
        if c(#"\bannu"#) { return .annuale }
        return nil
    }

    /// Gli anni del periodo raccomandato da "15" o "15 anni", tra 1 e 60 (le stesse regole di
    /// `StatoShell.anniDaDocumento`, ripetute qui perché il motore non dipenda dalla Shell).
    static func anni(_ testo: String) -> Int? {
        let cifre = testo.trimmingCharacters(in: .whitespaces).prefix(while: { $0.isASCII && $0.isNumber })
        guard let n = Int(String(cifre)), (1...60).contains(n) else { return nil }
        return n
    }

    /// Rendimento lordo annuo (%) che, con i costi del KID, rifà lo scenario moderato sul periodo raccomandato, con la
    /// stessa crescita della proiezione di Prisma (ingresso tolto all'inizio, costi correnti ogni mese):
    /// (1 − e)·[(1 + g)(1 − c)]^T = (1 + m)^T  ⇒  g = (1 + m) / ((1 − e)^(1/T) · (1 − c)) − 1.
    /// Percentuali in punti; nil se T < 1, e ≥ 100 o c ≥ 100.
    static func lordoImplicito(moderato m: Double, ingresso e: Double, annuo c: Double, anni T: Int) -> Double? {
        guard T >= 1, e < 100, c < 100, m > -100 else { return nil }
        // In passi tipizzati: una sola espressione con pow e letterali rallenta il controllo dei tipi
        let netto: Double = 1 + m / 100
        let restoIngresso: Double = Foundation.pow(1 - e / 100, 1 / Double(T))
        let restoAnnuo: Double = 1 - c / 100
        let g: Double = netto / (restoIngresso * restoAnnuo) - 1
        return g.isFinite ? g * 100 : nil
    }

    /// Il rendimento lordo del documento: «prima dei costi» (`.rendimentoPrimaCosti`) se il KID lo scrive, altrimenti
    /// `lordoImplicito` da scenario moderato, costi correnti e periodo (ingresso mancante = 0). Con `soloConfermati` usa
    /// solo i dati confermati (confronto e `creaProdotto`); la scheda di Documenti passa false.
    static func rendimentoLordo(_ d: Documento, soloConfermati: Bool) -> (valore: Double, fonte: FonteLordo)? {
        func dato(_ c: CampoDocumento) -> String? {
            if soloConfermati { return d.confermato(c) }
            guard let v = d.campo(c)?.valore.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
            return v
        }
        if let x = EstrattoreDocumento.numero(dato(.rendimentoPrimaCosti)) { return (x, .kid) }
        guard let m = EstrattoreDocumento.numero(dato(.rendimentoModerato)),
              let c = EstrattoreDocumento.numero(dato(.costoAnnuo)),
              let t = dato(.periodoDetenzione).flatMap(anni) else { return nil }
        let e = EstrattoreDocumento.numero(dato(.costoIngresso)) ?? 0
        guard let g = lordoImplicito(moderato: m, ingresso: e, annuo: c, anni: t) else { return nil }
        return (g, .stima)
    }

    /// Il valore del documento per una voce. `frequenzaPrisma` serve solo al premio senza frequenza scritta.
    /// nil se il documento non ha il dato; esito `.daConfermare` se non è confermato; `.illeggibile` se è confermato
    /// ma non si legge; altrimenti esito nil e il valore.
    static func letturaDocumento(_ d: Documento, _ v: VoceDossier, frequenzaPrisma: Frequenza?) -> LetturaVoce? {
        if v == .rendimentoLordo { return letturaLordo(d) }
        guard let c = d.campo(v.campo) else { return nil }
        let testo = c.valore.trimmingCharacters(in: .whitespacesAndNewlines)
        func esito(_ e: EsitoRiga) -> LetturaVoce { (nil, testo, c.pagina, c.estratto, e, false) }
        func letto(_ x: ValoreVoce, dedotta: Bool = false) -> LetturaVoce { (x, testo, c.pagina, c.estratto, nil, dedotta) }
        guard c.confermato else { return esito(.daConfermare) }
        guard !testo.isEmpty else { return esito(.illeggibile) }
        switch v {
        case .beneficiari:
            return letto(ValoreVoce(testo: testo.split(whereSeparator: \.isWhitespace).joined(separator: " ")))
        case .premio:
            guard let x = EstrattoreDocumento.numero(testo), x > 0 else { return esito(.illeggibile) }
            if let f = frequenzaPremio(c.estratto) { return letto(ValoreVoce(numero: x, frequenza: f.rawValue)) }
            // Senza frequenza scritta: quella di Prisma (se non è un premio unico), altrimenti annuale
            var f = Frequenza.annuale
            if let fp = frequenzaPrisma, fp != .unica { f = fp }
            return letto(ValoreVoce(numero: x, frequenza: f.rawValue), dedotta: true)
        case .capitaleAssicurato:
            guard let x = EstrattoreDocumento.numero(testo), x > 0 else { return esito(.illeggibile) }
            return letto(ValoreVoce(numero: x))
        case .scadenza:
            guard let data = EstrattoreDocumento.data(testo) else { return esito(.illeggibile) }
            return letto(ValoreVoce(data: ValoriDaDocumento.mezzogiorno(data)))
        case .sri:
            guard let n = Int(String(testo.prefix(1))), (1...7).contains(n) else { return esito(.illeggibile) }
            return letto(ValoreVoce(numero: Double(n)))
        case .periodoRaccomandato:
            guard let n = anni(testo) else { return esito(.illeggibile) }
            return letto(ValoreVoce(numero: Double(n)))
        case .costoIngresso, .costoGestione, .incidenzaCosti:
            guard let x = EstrattoreDocumento.numero(testo), x >= 0 else { return esito(.illeggibile) }
            return letto(ValoreVoce(numero: x))
        case .rendimentoLordo:
            return nil
        }
    }

    /// Il rendimento lordo del documento: la pagina e la riga sono quelle del dato da cui viene.
    private static func letturaLordo(_ d: Documento) -> LetturaVoce? {
        let primaDeiCosti = d.campo(.rendimentoPrimaCosti)
        let moderato = d.campo(.rendimentoModerato)
        if let l = rendimentoLordo(d, soloConfermati: true) {
            let preferito: CampoEstratto? = l.fonte == .kid ? primaDeiCosti : moderato
            guard let c = preferito ?? primaDeiCosti ?? moderato else { return nil }
            let valore = ValoreVoce(testo: l.fonte == .kid ? fonteKID : fonteStima, numero: l.valore)
            return (valore, c.valore, c.pagina, c.estratto, nil, false)
        }
        guard let c = primaDeiCosti ?? moderato else { return nil }
        let testo = c.valore.trimmingCharacters(in: .whitespacesAndNewlines)
        if rendimentoLordo(d, soloConfermati: false) != nil { return (nil, testo, c.pagina, c.estratto, .daConfermare, false) }
        // Senza costi correnti o periodo il lordo non si stima (salvo il «prima dei costi» del KID)
        if primaDeiCosti == nil, d.campo(.costoAnnuo) == nil || d.campo(.periodoDetenzione) == nil { return nil }
        let servono: [CampoDocumento] = [.rendimentoPrimaCosti, .rendimentoModerato, .costoAnnuo, .periodoDetenzione, .costoIngresso]
        if servono.contains(where: { k in d.campo(k).map { !$0.confermato } ?? false }) {
            return (nil, testo, c.pagina, c.estratto, .daConfermare, false)
        }
        return (nil, testo, c.pagina, c.estratto, .illeggibile, false)
    }

    /// Il valore di Prisma usato nel confronto. Per il premio `frequenzaDocumento` dice quale campo leggere:
    /// premio unico → `versamentoIniziale`; altrimenti `premio` con `frequenza`.
    static func valore(_ v: VoceDossier, in p: Posizione, frequenzaDocumento: Frequenza?) -> ValoreVoce? {
        switch v {
        case .beneficiari:
            let t = p.beneficiari.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : ValoreVoce(testo: t)
        case .premio:
            if frequenzaDocumento == .unica {
                return p.versamentoIniziale > 0 ? ValoreVoce(numero: p.versamentoIniziale, frequenza: Frequenza.unica.rawValue) : nil
            }
            return p.premio > 0 && p.frequenza != .unica ? ValoreVoce(numero: p.premio, frequenza: p.frequenza.rawValue) : nil
        case .capitaleAssicurato: return p.capitaleAssicurato.map { ValoreVoce(numero: $0) }
        case .scadenza: return p.scadenza.map { ValoreVoce(data: $0) }
        case .sri: return p.sri.map { ValoreVoce(numero: Double($0)) }
        case .periodoRaccomandato: return p.periodoRaccomandato.map { ValoreVoce(numero: Double($0)) }
        case .costoIngresso: return p.costoIngresso.map { ValoreVoce(numero: $0) }
        case .costoGestione: return p.costoAnnuo.map { ValoreVoce(numero: $0) }
        case .incidenzaCosti: return p.incidenzaCostiKID.map { ValoreVoce(numero: $0) }
        case .rendimentoLordo: return p.rendimentoAtteso.map { ValoreVoce(numero: $0) }
        }
    }

    /// Il valore della scheda prodotto usato nel confronto (il periodo comprende le condizioni del contratto).
    static func valore(_ v: VoceDossier, in p: Prodotto) -> ValoreVoce? {
        if v == .periodoRaccomandato { return p.periodoConsigliato.map { ValoreVoce(numero: Double($0)) } }
        return valoreCampo(v, in: p)
    }

    /// Il valore del campo scritto (per lo storico e il ripristino). È uguale a `valore(...)`, tranne per il periodo
    /// della scheda prodotto: lì è il solo `periodoRaccomandato`, senza le condizioni.
    static func valoreCampo(_ v: VoceDossier, in p: Prodotto) -> ValoreVoce? {
        switch v {
        case .beneficiari, .premio, .capitaleAssicurato, .scadenza: return nil
        case .sri: return p.sri.map { ValoreVoce(numero: Double($0)) }
        case .periodoRaccomandato: return p.periodoRaccomandato.map { ValoreVoce(numero: Double($0)) }
        case .costoIngresso: return p.costoIngresso.map { ValoreVoce(numero: $0) }
        case .costoGestione: return p.costoAnnuo.map { ValoreVoce(numero: $0) }
        case .incidenzaCosti: return p.incidenzaCostiKID.map { ValoreVoce(numero: $0) }
        case .rendimentoLordo: return p.rendimentoAtteso.map { ValoreVoce(numero: $0) }
        }
    }

    /// Uguaglianza con le tolleranze: testi senza maiuscole, accenti e punteggiatura; euro ±0,5 € (il premio anche
    /// con la stessa frequenza); percentuali ±0,005 punti, il rendimento lordo sotto `tolleranzaLordo`; SRI e anni
    /// uguali; date nello stesso giorno del calendario gregoriano.
    static func uguali(_ v: VoceDossier, _ a: ValoreVoce, _ b: ValoreVoce) -> Bool {
        switch v {
        case .beneficiari:
            return normaleTesto(a.testo ?? "") == normaleTesto(b.testo ?? "")
        case .scadenza:
            guard let x = a.data, let y = b.data else { return a.data == nil && b.data == nil }
            return Calendar(identifier: .gregorian).isDate(x, inSameDayAs: y)
        case .premio:
            guard a.frequenza == b.frequenza, let x = a.numero, let y = b.numero else { return false }
            return abs(x - y) <= tolleranzaEuro
        case .capitaleAssicurato:
            guard let x = a.numero, let y = b.numero else { return false }
            return abs(x - y) <= tolleranzaEuro
        case .sri, .periodoRaccomandato:
            guard let x = a.numero, let y = b.numero else { return false }
            return Int(x.rounded()) == Int(y.rounded())
        case .costoIngresso, .costoGestione, .incidenzaCosti:
            guard let x = a.numero, let y = b.numero else { return false }
            return abs(x - y) <= tolleranzaPercento + 1e-9
        case .rendimentoLordo:
            guard let x = a.numero, let y = b.numero else { return false }
            return abs(x - y) < tolleranzaLordo
        }
    }

    // MARK: Confronto

    /// Il confronto con una posizione: tutte le voci.
    static func confronta(_ d: Documento, con p: Posizione) -> ConfrontoDossier {
        costruisci(d, voci: VoceDossier.allCases, bersaglio: .posizione(p.id), frequenzaPrisma: p.frequenza,
                   multiramo: p.multiramoDivisa) { v, f in valore(v, in: p, frequenzaDocumento: f) }
    }

    /// Il confronto con una scheda prodotto: le voci `diProdotto`.
    static func confronta(_ d: Documento, con p: Prodotto) -> ConfrontoDossier {
        costruisci(d, voci: VoceDossier.allCases.filter(\.diProdotto), bersaglio: .prodotto(p.id), frequenzaPrisma: nil,
                   multiramo: p.proposta(per: "").multiramoDivisa) { v, _ in valore(v, in: p) }
    }

    private static func costruisci(_ d: Documento, voci: [VoceDossier], bersaglio: BersaglioConfronto, frequenzaPrisma: Frequenza?,
                                   multiramo: Bool, prisma: (VoceDossier, Frequenza?) -> ValoreVoce?) -> ConfrontoDossier {
        var righe: [RigaDossier] = []
        var mancanti: [VoceDossier] = []
        let tenute = Set(d.vociTenute ?? [])
        for v in voci {
            guard let l = letturaDocumento(d, v, frequenzaPrisma: frequenzaPrisma) else {
                mancanti.append(v)
                continue
            }
            if let e = l.esito {
                let pv = prisma(v, nil)
                righe.append(RigaDossier(voce: v, documento: nil, testoDocumento: l.testo, prisma: pv, esito: e, pagina: l.pagina,
                                         estratto: l.estratto, differenza: nil, peggiora: false, preselezionata: false,
                                         nota: nil, chiave: chiave(v, nil, pv)))
                continue
            }
            guard let doc = l.valore else {
                mancanti.append(v)
                continue
            }
            let frequenzaDoc = doc.frequenza.flatMap { Frequenza(rawValue: $0) }
            let pv = prisma(v, frequenzaDoc)
            let base: EsitoRiga
            if let pv { base = uguali(v, doc, pv) ? .uguale : .diverso } else { base = .nuovo }
            let k = chiave(v, doc, pv)
            let differente = base == .diverso || base == .nuovo
            let esito: EsitoRiga = differente && tenute.contains(k) ? .tenuto : base
            let diff = differenza(v, doc, pv)
            var peggiora = false
            if base == .diverso, let diff {
                if v.rischioOCosto {
                    peggiora = diff > (v == .sri ? 0 : tolleranzaPercento)
                } else if v == .capitaleAssicurato {
                    peggiora = diff < -tolleranzaEuro
                }
            }
            let esclusa = v == .beneficiari || v == .rendimentoLordo || (v == .costoGestione && multiramo)
            let preselezionata = (esito == .diverso || esito == .nuovo) && !esclusa
            var nota: String?
            if v == .beneficiari, differente {
                nota = TestiConfrontoDossier.notaBeneficiari
            } else if v == .rendimentoLordo, differente {
                nota = TestiConfrontoDossier.notaLordo(doc.testo == fonteKID ? .kid : .stima)
            } else if v == .costoGestione, multiramo, base == .diverso {
                nota = TestiConfrontoDossier.notaMultiramo
            } else if v == .premio, base == .diverso, let diff, abs(diff) < tolleranzaEuro {
                nota = TestiConfrontoDossier.notaRateDiverse
            } else if l.frequenzaDedotta, let f = frequenzaDoc {
                nota = TestiConfrontoDossier.notaFrequenzaDedotta(f)
            }
            righe.append(RigaDossier(voce: v, documento: doc, testoDocumento: l.testo, prisma: pv, esito: esito, pagina: l.pagina,
                                     estratto: l.estratto, differenza: diff, peggiora: peggiora, preselezionata: preselezionata,
                                     nota: nota, chiave: k))
        }
        return ConfrontoDossier(bersaglio: bersaglio, righe: righe, mancanti: mancanti)
    }

    /// Documento − Prisma; per il premio la differenza all'anno (il premio unico così com'è; nil se solo uno dei due
    /// è un premio unico); nil per testi, date o un valore mancante.
    private static func differenza(_ v: VoceDossier, _ doc: ValoreVoce, _ prisma: ValoreVoce?) -> Double? {
        guard let prisma, let a = doc.numero, let b = prisma.numero else { return nil }
        switch v {
        case .beneficiari, .scadenza:
            return nil
        case .premio:
            let unicoA = doc.frequenza == Frequenza.unica.rawValue
            let unicoB = prisma.frequenza == Frequenza.unica.rawValue
            guard unicoA == unicoB else { return nil }
            if unicoA { return a - b }
            return annuo(a, doc.frequenza) - annuo(b, prisma.frequenza)
        default:
            return a - b
        }
    }

    private static func annuo(_ importo: Double, _ frequenza: String?) -> Double {
        importo * Double(frequenza.flatMap { Frequenza(rawValue: $0) }?.volteAllAnno ?? 1)
    }

    /// «voce|documento|prisma» con i valori normalizzati (vedi `RigaDossier.chiave`).
    static func chiave(_ v: VoceDossier, _ documento: ValoreVoce?, _ prisma: ValoreVoce?) -> String {
        "\(v.rawValue)|\(testoChiave(v, documento))|\(testoChiave(v, prisma))"
    }

    private static func testoChiave(_ v: VoceDossier, _ x: ValoreVoce?) -> String {
        guard let x else { return "-" }
        switch v {
        case .beneficiari:
            let t = normaleTesto(x.testo ?? "")
            return t.isEmpty ? "-" : t
        case .scadenza:
            return x.data.map { formatoChiave.string(from: $0) } ?? "-"
        case .premio:
            guard let n = x.numero else { return "-" }
            return "\(String(format: "%.2f", n)) \(x.frequenza ?? "")"
        default:
            return x.numero.map { String(format: "%.2f", $0) } ?? "-"
        }
    }

    private static let formatoChiave: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: Aggiornamento e storico

    /// Porta in `p` le voci scelte che sono aggiornabili (non da confermare né tenute) e restituisce le variazioni
    /// registrate (aggiunte anche in fondo a `p.variazioni`). Le chiavi delle voci applicate si tolgono da
    /// `d.vociTenute` nella Shell.
    static func applica(_ voci: Set<VoceDossier>, da c: ConfrontoDossier, documento d: Documento,
                        a p: inout Posizione, il: Date) -> [VariazioneDossier] {
        guard c.bersaglio == .posizione(p.id) else { return [] }
        let quando = secondiInteri(il)
        var nuove: [VariazioneDossier] = []
        for r in c.righe where voci.contains(r.voce) && r.aggiornabile {
            guard let dopo = scrivibile(r) else { continue }
            let unica = dopo.frequenza == Frequenza.unica.rawValue
            let prima = valore(r.voce, in: p, frequenzaDocumento: dopo.frequenza.flatMap { Frequenza(rawValue: $0) })
            scrivi(r.voce, dopo, unica: unica, in: &p)
            nuove.append(variazione(r, valorePrima: prima, valoreDopo: dopo, documento: d, il: quando))
        }
        if !nuove.isEmpty { p.variazioni = (p.variazioni ?? []) + nuove }
        return nuove
    }

    /// Le stesse regole per una scheda prodotto (solo le voci `diProdotto`); con almeno una voce applicata la scheda
    /// prende la fonte del documento e la data di verifica.
    static func applica(_ voci: Set<VoceDossier>, da c: ConfrontoDossier, documento d: Documento,
                        a p: inout Prodotto, il: Date) -> [VariazioneDossier] {
        guard c.bersaglio == .prodotto(p.id) else { return [] }
        let quando = secondiInteri(il)
        var nuove: [VariazioneDossier] = []
        for r in c.righe where voci.contains(r.voce) && r.voce.diProdotto && r.aggiornabile {
            guard let dopo = scrivibile(r) else { continue }
            let prima = valoreCampo(r.voce, in: p)
            guard scrivi(r.voce, dopo, in: &p) else { continue }
            nuove.append(variazione(r, valorePrima: prima, valoreDopo: dopo, documento: d, il: quando))
        }
        guard !nuove.isEmpty else { return [] }
        let fonteDiPrima = p.fonte
        for i in nuove.indices { nuove[i].fontePrecedente = fonteDiPrima }
        p.fonte = fonte(d)
        p.verificatoIl = Calendar.current.startOfDay(for: il)
        p.variazioni = (p.variazioni ?? []) + nuove
        return nuove
    }

    /// Le stesse voci, prese dal documento, nelle proposte aperte del prodotto (`prodottoId`, non quelle collegate
    /// solo per nome). Restituisce quante proposte cambiano.
    static func applicaAProposte(_ voci: Set<VoceDossier>, documento d: Documento, prodottoId: String,
                                 posizioni: inout [Posizione], il: Date) -> Int {
        let aperte = Set(MotoreCoerenza.proposteAperte(posizioni).filter { $0.prodottoId == prodottoId }.map(\.id))
        guard !aperte.isEmpty else { return 0 }
        let scelte = voci.filter(\.diProdotto)
        var cambiate = 0
        for i in posizioni.indices where aperte.contains(posizioni[i].id) {
            let c = confronta(d, con: posizioni[i])
            if !applica(scelte, da: c, documento: d, a: &posizioni[i], il: il).isEmpty { cambiate += 1 }
        }
        return cambiate
    }

    /// La fonte di una scheda aggiornata da un documento, come `StatoShell.creaProdotto`.
    static func fonte(_ d: Documento) -> String {
        "\(d.titolo) (\(d.tipo.breve), importato il \(Formati.dataBreve.string(from: d.importatoIl)))"
    }

    /// true se si può annullare: non è un ripristino, è l'ultima variazione di quella voce nel bersaglio e il campo
    /// vale ancora `valoreDopo`.
    static func ripristinabile(_ v: VariazioneDossier, in p: Posizione) -> Bool {
        guard v.ripristinoDi == nil, let voce = VoceDossier(rawValue: v.voce), let dopo = v.valoreDopo,
              ultima(v, in: p.variazioni) else { return false }
        let attuale = valore(voce, in: p, frequenzaDocumento: dopo.frequenza.flatMap { Frequenza(rawValue: $0) })
        return stesso(voce, attuale, dopo)
    }

    static func ripristinabile(_ v: VariazioneDossier, in p: Prodotto) -> Bool {
        guard v.ripristinoDi == nil, let voce = VoceDossier(rawValue: v.voce), voce.diProdotto, let dopo = v.valoreDopo,
              ultima(v, in: p.variazioni) else { return false }
        return stesso(voce, valoreCampo(voce, in: p), dopo)
    }

    /// Rimette `valorePrima` e registra una variazione di ripristino. Restituisce nil se non è ripristinabile.
    static func ripristina(_ v: VariazioneDossier, in p: inout Posizione, il: Date) -> VariazioneDossier? {
        guard ripristinabile(v, in: p), let voce = VoceDossier(rawValue: v.voce) else { return nil }
        scrivi(voce, v.valorePrima, unica: v.valoreDopo?.frequenza == Frequenza.unica.rawValue, in: &p)
        let r = ripristino(v, il: il)
        p.variazioni = (p.variazioni ?? []) + [r]
        return r
    }

    /// La `fonte` della scheda non si ripristina.
    static func ripristina(_ v: VariazioneDossier, in p: inout Prodotto, il: Date) -> VariazioneDossier? {
        guard ripristinabile(v, in: p), let voce = VoceDossier(rawValue: v.voce) else { return nil }
        scrivi(voce, v.valorePrima, in: &p)
        let r = ripristino(v, il: il)
        p.variazioni = (p.variazioni ?? []) + [r]
        return r
    }

    /// Il valore del documento da scrivere: il rendimento lordo al centesimo (come lo scrive la scheda).
    private static func scrivibile(_ r: RigaDossier) -> ValoreVoce? {
        guard var x = r.documento else { return nil }
        if r.voce == .rendimentoLordo, let n = x.numero { x.numero = (n * 100).rounded() / 100 }
        return x
    }

    private static func variazione(_ r: RigaDossier, valorePrima: ValoreVoce?, valoreDopo: ValoreVoce, documento d: Documento,
                                   il: Date) -> VariazioneDossier {
        VariazioneDossier(voce: r.voce.rawValue, prima: TestiConfrontoDossier.valore(r.prisma, r.voce),
                          dopo: TestiConfrontoDossier.valore(valoreDopo, r.voce), valorePrima: valorePrima, valoreDopo: valoreDopo,
                          documentoId: d.id, titoloDocumento: d.titolo, tipoDocumento: d.tipo.rawValue, il: il)
    }

    private static func ripristino(_ v: VariazioneDossier, il: Date) -> VariazioneDossier {
        VariazioneDossier(voce: v.voce, prima: v.dopo, dopo: v.prima, valorePrima: v.valoreDopo, valoreDopo: v.valorePrima,
                          documentoId: nil, titoloDocumento: TestiConfrontoDossier.titoloRipristino, tipoDocumento: "",
                          il: secondiInteri(il), ripristinoDi: v.id)
    }

    /// È l'ultima variazione di quella voce nello storico.
    private static func ultima(_ v: VariazioneDossier, in elenco: [VariazioneDossier]?) -> Bool {
        (elenco ?? []).last { $0.voce == v.voce }?.id == v.id
    }

    /// Il campo vale ancora quel valore (senza le tolleranze del confronto: è lo stesso dato scritto).
    private static func stesso(_ v: VoceDossier, _ a: ValoreVoce?, _ b: ValoreVoce?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        switch v {
        case .beneficiari:
            return normaleTesto(a.testo ?? "") == normaleTesto(b.testo ?? "")
        case .scadenza:
            guard let x = a.data, let y = b.data else { return a.data == nil && b.data == nil }
            return Calendar(identifier: .gregorian).isDate(x, inSameDayAs: y)
        case .premio:
            guard a.frequenza == b.frequenza, let x = a.numero, let y = b.numero else { return false }
            return abs(x - y) < 0.005
        default:
            guard let x = a.numero, let y = b.numero else { return a.numero == nil && b.numero == nil }
            return abs(x - y) < 0.000_5
        }
    }

    /// Scrive una voce nella posizione (nil = vuoto). Il premio unico va nel versamento iniziale.
    private static func scrivi(_ v: VoceDossier, _ x: ValoreVoce?, unica: Bool, in p: inout Posizione) {
        switch v {
        case .beneficiari: p.beneficiari = x?.testo ?? ""
        case .premio:
            if unica {
                p.versamentoIniziale = x?.numero ?? 0
            } else {
                p.premio = x?.numero ?? 0
                p.frequenza = Frequenza(rawValue: x?.frequenza ?? "") ?? .unica
            }
        case .capitaleAssicurato: p.capitaleAssicurato = x?.numero
        case .scadenza: p.scadenza = x?.data
        case .sri: p.sri = x?.numero.map { Int($0.rounded()) }
        case .periodoRaccomandato: p.periodoRaccomandato = x?.numero.map { Int($0.rounded()) }
        case .costoIngresso: p.costoIngresso = x?.numero
        case .costoGestione: p.costoAnnuo = x?.numero
        case .incidenzaCosti: p.incidenzaCostiKID = x?.numero
        case .rendimentoLordo: p.rendimentoAtteso = x?.numero
        }
    }

    /// Scrive una voce nella scheda prodotto (nil = vuoto); false per le voci dei soli contratti.
    @discardableResult
    private static func scrivi(_ v: VoceDossier, _ x: ValoreVoce?, in p: inout Prodotto) -> Bool {
        switch v {
        case .beneficiari, .premio, .capitaleAssicurato, .scadenza: return false
        case .sri: p.sri = x?.numero.map { Int($0.rounded()) }
        case .periodoRaccomandato: p.periodoRaccomandato = x?.numero.map { Int($0.rounded()) }
        case .costoIngresso: p.costoIngresso = x?.numero
        case .costoGestione: p.costoAnnuo = x?.numero
        case .incidenzaCosti: p.incidenzaCostiKID = x?.numero
        case .rendimentoLordo: p.rendimentoAtteso = x?.numero
        }
        return true
    }

    private static func secondiInteri(_ d: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: d.timeIntervalSinceReferenceDate.rounded(.down))
    }

    // MARK: Nuovo KID: aumenti e impatto sui clienti

    /// Aumenti di rischio o di costo nel confronto con una scheda prodotto: righe `.diverso` (o `.tenuto`, perché il
    /// KID li alza comunque), voce `rischioOCosto`, `peggiora`. Le righe da confermare no.
    static func aumenti(_ c: ConfrontoDossier) -> [AumentoKID] {
        c.righe.compactMap { r in
            guard r.esito == .diverso || r.esito == .tenuto, r.voce.rischioOCosto, r.peggiora,
                  let prima = r.prisma?.numero, let dopo = r.documento?.numero else { return nil }
            return AumentoKID(voce: r.voce, prima: prima, dopo: dopo)
        }
    }

    /// Gli aumenti dell'ultimo aggiornamento di una scheda: ultime variazioni con lo stesso `documentoId` e lo stesso
    /// giorno, voce `rischioOCosto`, valore salito (oltre la tolleranza). Le voci ripristinate dopo non contano.
    /// nil se non ci sono aumenti.
    static func aumenti(ultimo variazioni: [VariazioneDossier]) -> (aumenti: [AumentoKID], il: Date, documentoId: String)? {
        guard let ultima = variazioni.last(where: { $0.documentoId != nil && $0.ripristinoDi == nil }),
              let documentoId = ultima.documentoId else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let ripristinate = Set(variazioni.compactMap(\.ripristinoDi))
        var perVoce: [VoceDossier: AumentoKID] = [:]
        for v in variazioni {
            guard v.documentoId == documentoId, v.ripristinoDi == nil, !ripristinate.contains(v.id),
                  cal.isDate(v.il, inSameDayAs: ultima.il) else { continue }
            guard let voce = VoceDossier(rawValue: v.voce), voce.rischioOCosto,
                  let prima = v.valorePrima?.numero, let dopo = v.valoreDopo?.numero,
                  dopo > prima + (voce == .sri ? 0 : tolleranzaPercento) else { continue }
            perVoce[voce] = AumentoKID(voce: voce, prima: prima, dopo: dopo)
        }
        let elenco = VoceDossier.allCases.compactMap { perVoce[$0] }
        if elenco.isEmpty { return nil }
        return (aumenti: elenco, il: ultima.il, documentoId: documentoId)
    }

    /// Chi ha posizioni o proposte del prodotto, con il peso degli aumenti: in essere e proposte aperte, collegate
    /// alla scheda o (senza scheda) con lo stesso nome e canale; il costo annuo in più dal RIY (o dai costi correnti),
    /// l'ingresso in più sui versamenti di un anno; «oltre il profilo» se il nuovo SRI supera la propensione.
    static func impatto(_ aumenti: [AumentoKID], prodotto: Prodotto, posizioni: [Posizione], clienti: [Cliente]) -> EsitoImpatto {
        guard !aumenti.isEmpty else { return EsitoImpatto(aumenti: aumenti, clienti: []) }
        func delta(_ v: VoceDossier) -> Double? { aumenti.first { $0.voce == v }.map { $0.dopo - $0.prima } }
        // Il RIY è la misura complessiva annua dei costi del KID: ha la precedenza sui costi correnti
        let deltaAnnuo = delta(.incidenzaCosti) ?? delta(.costoGestione) ?? 0
        let deltaIngresso = delta(.costoIngresso) ?? 0
        let nuovoSRI = aumenti.first { $0.voce == .sri }.map { Int($0.dopo.rounded()) }
        let nomeScheda = normaleTesto(prodotto.nome)
        var perId: [String: Cliente] = [:]
        for c in clienti where perId[c.id] == nil { perId[c.id] = c }
        let aperte = Set(MotoreCoerenza.proposteAperte(posizioni).map(\.id))
        var perCliente: [String: [PosizioneToccata]] = [:]
        for p in posizioni {
            guard perId[p.clienteId] != nil, p.stato == .inEssere || aperte.contains(p.id) else { continue }
            let perNome: Bool
            if p.prodottoId == prodotto.id {
                perNome = false
            } else if p.prodottoId == nil, p.canale == prodotto.canale, !nomeScheda.isEmpty, normaleTesto(p.nome) == nomeScheda {
                perNome = true
            } else {
                continue
            }
            let proposta = p.stato == .proposta
            let base = proposta ? p.versamentoIniziale + p.premioAnnuo : p.valore
            let baseIngresso = proposta ? p.versamentoIniziale + p.premioAnnuo : p.premioAnnuo
            perCliente[p.clienteId, default: []].append(
                PosizioneToccata(id: p.id, nome: p.nome, canale: p.canale, stato: p.stato, esito: p.esito, perNome: perNome,
                                 base: base, costoAnnuoInPiu: base * deltaAnnuo / 100, ingressoInPiu: baseIngresso * deltaIngresso / 100))
        }
        let elenco: [ImpattoCliente] = perCliente.compactMap { id, toccate in
            guard let c = perId[id] else { return nil }
            let ordinate = toccate.sorted { a, b in
                if (a.stato == .proposta) != (b.stato == .proposta) { return a.stato == .proposta }
                return a.nome.localizedCaseInsensitiveCompare(b.nome) == .orderedAscending
            }
            let massimo = c.profilo.propensione.map { MotoreCoerenza.sriMassimo($0) }
            var oltre = false
            if let nuovoSRI, let massimo { oltre = nuovoSRI > massimo }
            return ImpattoCliente(clienteId: id, nome: c.nome, posizioni: ordinate, sriMassimo: massimo, oltreProfilo: oltre)
        }
        let ordinati = elenco.sorted { a, b in
            if abs(a.costoAnnuoInPiu - b.costoAnnuoInPiu) > 0.000_1 { return a.costoAnnuoInPiu > b.costoAnnuoInPiu }
            return a.nome.localizedCaseInsensitiveCompare(b.nome) == .orderedAscending
        }
        return EsitoImpatto(aumenti: aumenti, clienti: ordinati)
    }

    // MARK: Collegamento

    /// Le posizioni che una polizza può descrivere: del cliente del documento, non chiuse, non immobili, debiti o
    /// liquidità (le coperture di protezione sì, a differenza di `ValoriDaDocumento.candidate`).
    static func candidatePosizioni(_ d: Documento, tra posizioni: [Posizione]) -> [Posizione] {
        let escluse: Set<AreaPosizione> = [.immobili, .debiti, .liquidita]
        return posizioni.filter { p in
            guard p.clienteId == d.clienteId, p.stato != StatoPosizione.chiusa else { return false }
            return !escluse.contains(p.area)
        }
    }

    /// Quella più probabile, con le regole di `ValoriDaDocumento.posizioneProbabile` sulle candidate qui sopra: prima il
    /// collegamento, poi il numero di contratto (solo lettere e cifre, in maiuscolo), poi il nome del prodotto a parole
    /// intere. Mai a caso tra due candidate uguali.
    static func posizioneProbabile(_ d: Documento, tra posizioni: [Posizione]) -> (Posizione, MotivoCollegamento)? {
        let elenco = candidatePosizioni(d, tra: posizioni)
        if let id = d.posizioneId, let p = elenco.first(where: { $0.id == id }) { return (p, .collegamento) }
        let numero = compatto(d.campo(.numeroContratto)?.valore ?? "")
        if !numero.isEmpty {
            let stessoNumero = elenco.filter { !$0.numeroContratto.isEmpty && compatto($0.numeroContratto) == numero }
            if stessoNumero.count == 1, let p = stessoNumero.first { return (p, .numeroContratto) }
            let inEssere = stessoNumero.filter { $0.stato == .inEssere }
            if inEssere.count == 1, let p = inEssere.first { return (p, .numeroContratto) }
        }
        // Dal nome, a parole intere; mai una posizione con un altro numero di contratto, mai a caso tra due uguali
        let parole = " " + normaleTesto((d.campo(.nomeProdotto)?.valore ?? "") + " " + d.titolo) + " "
        let trovate = elenco.filter { p in
            let suo = normaleTesto(p.nome)
            guard !suo.isEmpty, parole.contains(" \(suo) ") else { return false }
            return numero.isEmpty || p.numeroContratto.isEmpty || compatto(p.numeroContratto) == numero
        }
        guard let lunghezza = trovate.map(\.nome.count).max() else { return nil }
        let migliori = trovate.filter { $0.nome.count == lunghezza }
        guard migliori.count == 1, let p = migliori.first else { return nil }
        return (p, .nome)
    }

    /// La scheda più probabile per un KID: il nome della scheda sta a parole intere nel nome letto più il titolo; se
    /// documento e scheda hanno tutti e due l'emittente, devono avere una parola in comune di 3 lettere o più fuori da
    /// `paroleGeneriche`; tra le schede rimaste vince il nome più lungo, e solo se è uno.
    static func prodottoProbabile(_ d: Documento, tra prodotti: [Prodotto]) -> (Prodotto, MotivoCollegamento)? {
        if let id = d.prodottoId, let p = prodotti.first(where: { $0.id == id }) { return (p, .collegamento) }
        let parole = " " + normaleTesto((d.campo(.nomeProdotto)?.valore ?? "") + " " + d.titolo) + " "
        let emittenteDocumento = d.campo(.emittente)?.valore.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let paroleDocumento = paroleEmittente(emittenteDocumento)
        var conEmittente: Set<String> = []
        let trovate = prodotti.filter { p in
            let suo = normaleTesto(p.nome)
            guard !suo.isEmpty, parole.contains(" \(suo) ") else { return false }
            let emittenteScheda = p.emittente.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !emittenteDocumento.isEmpty, !emittenteScheda.isEmpty else { return true }
            guard !paroleDocumento.isDisjoint(with: paroleEmittente(emittenteScheda)) else { return false }
            conEmittente.insert(p.id)
            return true
        }
        guard let lunghezza = trovate.map(\.nome.count).max() else { return nil }
        let migliori = trovate.filter { $0.nome.count == lunghezza }
        guard migliori.count == 1, let p = migliori.first else { return nil }
        return (p, conEmittente.contains(p.id) ? .nomeEdEmittente : .nome)
    }

    /// Il bersaglio predefinito tra quelli collegati: KID → scheda, se c'è; altrimenti → posizione, se c'è.
    static func bersaglioPredefinito(_ d: Documento, posizioneEsiste: Bool, prodottoEsiste: Bool) -> BersaglioConfronto? {
        if d.tipo == .kid, prodottoEsiste, let id = d.prodottoId { return .prodotto(id) }
        if posizioneEsiste, let id = d.posizioneId { return .posizione(id) }
        if prodottoEsiste, let id = d.prodottoId { return .prodotto(id) }
        return nil
    }

    // MARK: Testi normalizzati

    /// Minuscole, senza accenti né punteggiatura, spazi ridotti a uno.
    static func normaleTesto(_ s: String) -> String {
        piega(s).split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    /// Le parole di un emittente che lo distinguono (3 lettere o più, non generiche).
    private static func paroleEmittente(_ s: String) -> Set<String> {
        Set(normaleTesto(s).split(separator: " ").map(String.init).filter { $0.count >= 3 && !paroleGeneriche.contains($0) })
    }

    // Copie di `ValoriDaDocumento` (che non si tocca in questo giro)
    private static func compatto(_ s: String) -> String {
        s.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func piega(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
    }
}
