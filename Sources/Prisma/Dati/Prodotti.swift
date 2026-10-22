import Foundation

/// Scheda di un prodotto: condizioni, costi e fonte verificabile (KID, set informativo).
/// Il canale distingue i prodotti Alleanza da quelli della consulenza indipendente.
struct Prodotto: Identifiable, Codable, Hashable {
    var id = "prodotto-\(UUID().uuidString.prefix(8).lowercased())"
    var nome: String
    var canale: Canale
    var area: AreaPosizione
    var emittente = ""
    var tipologia = ""
    /// Ipotesi per i calcoli, dal KID o dal prospetto (percentuali annue).
    var rendimentoAtteso: Double?
    var costoIngresso: Double?
    var costoAnnuo: Double?
    var aliquotaFiscale: Double?
    var sri: Int?
    var garanzie = ""
    var liquidabilita = ""
    /// Documento, versione o indirizzo da cui vengono i dati.
    var fonte = ""
    var verificatoIl: Date?
    var note = ""
    /// Condizioni dettagliate del contratto (parti, penali, bollo, KID), per le valutazioni di riscatto.
    var condizioni: CondizioniContratto?

    init(nome: String, canale: Canale, area: AreaPosizione) {
        self.nome = nome
        self.canale = canale
        self.area = area
    }

    /// Mesi dall'ultima verifica (nil se mai verificato).
    var mesiDallaVerifica: Int? {
        verificatoIl.flatMap { Calendar.current.dateComponents([.month], from: $0, to: Date()).month }
    }

    /// Una scheda più vecchia di un anno va riletta sul KID aggiornato.
    var daVerificare: Bool { (mesiDallaVerifica ?? 99) >= 12 }

    /// Ipotesi di prova per mostrare il peso dei costi: 10.000 € per 10 anni.
    var parametriEsempio: ParametriProiezione {
        ParametriProiezione(capitaleIniziale: 10_000, versamento: 0, frequenza: .unica, anni: 10,
                            rendimento: rendimentoAtteso ?? IpotesiCalcolo.rendimentoPredefinito,
                            costoIngresso: costoIngresso ?? 0, costoAnnuo: costoAnnuo ?? 0,
                            aliquotaFiscale: aliquotaFiscale ?? IpotesiCalcolo.aliquotaPredefinita)
    }

    /// La proposta per un cliente, con le condizioni della scheda.
    func proposta(per cliente: String) -> Posizione {
        var p = Posizione(clienteId: cliente, canale: canale, stato: .proposta, area: area, nome: nome)
        p.esito = .bozza
        p.tipologia = tipologia
        p.emittente = emittente
        p.rendimentoAtteso = rendimentoAtteso
        p.costoIngresso = costoIngresso
        p.costoAnnuo = costoAnnuo
        p.aliquotaFiscale = aliquotaFiscale
        p.sri = sri
        p.garanzie = garanzie
        p.prodottoId = id
        p.note = fonte.isEmpty ? "" : "Dati dalla scheda prodotto: \(fonte)"
        return p
    }

    private enum CodingKeys: String, CodingKey {
        case id, nome, canale, area, emittente, tipologia, rendimentoAtteso, costoIngresso, costoAnnuo, aliquotaFiscale, sri
        case garanzie, liquidabilita, fonte, verificatoIl, note, condizioni
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nome = try c.decodeIfPresent(String.self, forKey: .nome) ?? "Prodotto"
        canale = try c.decodeIfPresent(Canale.self, forKey: .canale) ?? .indipendente
        area = try c.decodeIfPresent(AreaPosizione.self, forKey: .area) ?? .investimento
        emittente = try c.decodeIfPresent(String.self, forKey: .emittente) ?? ""
        tipologia = try c.decodeIfPresent(String.self, forKey: .tipologia) ?? ""
        rendimentoAtteso = try c.decodeIfPresent(Double.self, forKey: .rendimentoAtteso)
        costoIngresso = try c.decodeIfPresent(Double.self, forKey: .costoIngresso)
        costoAnnuo = try c.decodeIfPresent(Double.self, forKey: .costoAnnuo)
        aliquotaFiscale = try c.decodeIfPresent(Double.self, forKey: .aliquotaFiscale)
        sri = try c.decodeIfPresent(Int.self, forKey: .sri)
        garanzie = try c.decodeIfPresent(String.self, forKey: .garanzie) ?? ""
        liquidabilita = try c.decodeIfPresent(String.self, forKey: .liquidabilita) ?? ""
        fonte = try c.decodeIfPresent(String.self, forKey: .fonte) ?? ""
        verificatoIl = try c.decodeIfPresent(Date.self, forKey: .verificatoIl)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        condizioni = try? c.decodeIfPresent(CondizioniContratto.self, forKey: .condizioni)
    }
}

/// Un obiettivo del cliente: un progetto con un importo e una data.
struct Obiettivo: Identifiable, Codable, Hashable {
    var id = "obiettivo-\(UUID().uuidString.prefix(8).lowercased())"
    var clienteId: String
    var titolo: String
    var area: AreaBisogno
    /// Importo da raggiungere, in euro di oggi.
    var importo: Double
    var scadenza: Date
    var priorita = Importanza.media
    /// Già da parte, oltre alle posizioni collegate.
    var accantonato: Double = 0
    /// Posizioni che lavorano per l'obiettivo: il loro valore conta come accantonato.
    var posizioniCollegate: [String] = []
    /// Rendimento annuo ipotizzato per calcolare il versamento necessario.
    var rendimento = 2.0
    var note = ""
    var creatoIl = Date()

    init(clienteId: String, titolo: String, area: AreaBisogno, importo: Double, scadenza: Date) {
        self.clienteId = clienteId
        self.titolo = titolo
        self.area = area
        self.importo = importo
        self.scadenza = scadenza
    }

    var anniMancanti: Int {
        max(0, Calendar.current.dateComponents([.month], from: Date(), to: scadenza).month ?? 0) / 12
    }

    var mesiMancanti: Int {
        max(0, Calendar.current.dateComponents([.month], from: Date(), to: scadenza).month ?? 0)
    }

    private enum CodingKeys: String, CodingKey {
        case id, clienteId, titolo, area, importo, scadenza, priorita, accantonato, posizioniCollegate, rendimento, note, creatoIl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        clienteId = try c.decode(String.self, forKey: .clienteId)
        titolo = try c.decodeIfPresent(String.self, forKey: .titolo) ?? "Obiettivo"
        area = try c.decodeIfPresent(AreaBisogno.self, forKey: .area) ?? .patrimonio
        importo = try c.decodeIfPresent(Double.self, forKey: .importo) ?? 0
        scadenza = try c.decodeIfPresent(Date.self, forKey: .scadenza) ?? Date()
        priorita = try c.decodeIfPresent(Importanza.self, forKey: .priorita) ?? .media
        accantonato = try c.decodeIfPresent(Double.self, forKey: .accantonato) ?? 0
        posizioniCollegate = try c.decodeIfPresent([String].self, forKey: .posizioniCollegate) ?? []
        rendimento = try c.decodeIfPresent(Double.self, forKey: .rendimento) ?? 2
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        creatoIl = try c.decodeIfPresent(Date.self, forKey: .creatoIl) ?? Date()
    }
}

/// Stato di un obiettivo calcolato dall'app.
struct AvanzamentoObiettivo {
    let accantonato: Double
    /// Quota raggiunta (0–1).
    let quota: Double
    let mancante: Double
    /// Versamento mensile per arrivare in tempo, con il rendimento ipotizzato (nil se la data è passata).
    let versamentoNecessario: Double?
    /// Versamenti mensili già attivi sulle posizioni collegate.
    let versamentiAttivi: Double

    init(_ o: Obiettivo, posizioni: [Posizione]) {
        let collegate = posizioni.filter { o.posizioniCollegate.contains($0.id) && $0.stato == .inEssere }
        accantonato = o.accantonato + collegate.reduce(0) { $0 + $1.valore }
        quota = o.importo > 0 ? min(1, accantonato / o.importo) : 1
        mancante = max(0, o.importo - accantonato)
        versamentiAttivi = collegate.reduce(0) { $0 + $1.premioAnnuo } / 12
        let anni = max(1, Int((Double(o.mesiMancanti) / 12).rounded(.up)))
        let p = ParametriProiezione(capitaleIniziale: accantonato, versamento: 0, frequenza: .mensile, anni: anni,
                                    rendimento: o.rendimento, aliquotaFiscale: 0, inflazione: 0)
        versamentoNecessario = o.mesiMancanti > 0 ? MotoreAnalisi.versamentoNecessario(p, obiettivo: o.importo) : nil
    }
}
