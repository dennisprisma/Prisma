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
    /// Incidenza annua dei costi dichiarata nel KID (RIY, % annuo al periodo raccomandato).
    var incidenzaCostiKID: Double?
    /// Periodo di detenzione raccomandato dal KID, in anni (se mancano le condizioni dettagliate).
    var periodoRaccomandato: Int?

    // Gestione separata (anche per il Ramo I) e multiramo a due parti (dalla versione 20 dell'archivio):
    // stesso significato dei campi di `Posizione`; la proposta li eredita (`MotoreMultiramo.applica`).
    /// Trattenuto sul rendimento della gestione separata (punti l'anno).
    var trattenuto: Double?
    /// Quota del rendimento lordo retrocessa (0–100), alternativa al trattenuto fisso.
    var retrocessione: Double?
    /// Rendimento minimo garantito annuo della gestione separata (%).
    var minimoGarantito: Double?
    /// true se il rendimento della gestione separata si consolida ogni anno.
    var consolidamento: Bool?
    /// Multiramo: quota del premio in gestione separata (0–100).
    var quotaGestioneSeparata: Double?
    /// Multiramo: quota minima e massima ammessa in gestione separata (0–100), dalle condizioni
    /// (es. 30 e 70). Solo per avvisare nel modulo, i calcoli non le usano.
    var quotaGestioneMinima: Double?
    var quotaGestioneMassima: Double?
    /// Multiramo: rendimento lordo della gestione separata (%), prima del trattenuto.
    var rendimentoGestione: Double?
    /// Multiramo: rendimento lordo dei fondi (%), prima di commissioni e costi dei fondi.
    var rendimentoFondi: Double?
    /// Multiramo: costi annui della parte in fondi (%), commissione della compagnia più costi degli OICR.
    var costoFondi: Double?
    /// Multiramo: SRI (1–7), volatilità annua (%) e quota azionaria (0–100) della parte in fondi.
    var sriFondi: Int?
    var volatilitaFondi: Double?
    var quotaAzionariaFondi: Double?
    /// Multiramo: quota in titoli di Stato della gestione separata e dei fondi (0–100).
    var titoliStatoGestione: Double?
    var titoliStatoFondi: Double?
    /// Multiramo: true se il contratto riporta ogni anno la gestione separata alla quota scelta.
    var ribilanciamento: Bool?

    init(nome: String, canale: Canale, area: AreaPosizione) {
        self.nome = nome
        self.canale = canale
        self.area = area
    }

    /// Mesi dall'ultima verifica (nil se mai verificato).
    var mesiDallaVerifica: Int? {
        verificatoIl.flatMap { Calendar.current.dateComponents([.month], from: $0, to: Date()).month }
    }

    /// Periodo raccomandato: quello della scheda o, se manca, quello delle condizioni del contratto.
    var periodoConsigliato: Int? { periodoRaccomandato ?? condizioni?.periodoRaccomandato }

    /// Una scheda più vecchia di un anno va riletta sul KID aggiornato.
    var daVerificare: Bool { (mesiDallaVerifica ?? 99) >= 12 }

    /// Ipotesi di prova per mostrare il peso dei costi: 10.000 € per 10 anni. Per una multiramo a due parti
    /// la proiezione tiene le due parti, senza il bollo (come i KPI delle altre schede).
    var parametriEsempio: ParametriProiezione {
        var q = proposta(per: "esempio")
        q.versamentoIniziale = 10_000; q.premio = 0; q.frequenza = .unica; q.scadenza = nil
        if q.multiramoDivisa {
            var par = ParametriProiezione(posizione: q, orizzonteCliente: 10)
            par.anni = 10
            par.costoAnnuo = q.costoParteFondi
            return par
        }
        return ParametriProiezione(capitaleIniziale: 10_000, versamento: 0, frequenza: .unica, anni: 10,
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
        p.incidenzaCostiKID = incidenzaCostiKID
        p.periodoRaccomandato = periodoConsigliato
        p.prodottoId = id
        p.note = fonte.isEmpty ? "" : "Dati dalla scheda prodotto: \(fonte)"
        // Garanzie della gestione separata e due parti della multiramo, dai campi o dalle condizioni
        MotoreMultiramo.applica(self, a: &p)
        return p
    }

    private enum CodingKeys: String, CodingKey {
        case id, nome, canale, area, emittente, tipologia, rendimentoAtteso, costoIngresso, costoAnnuo, aliquotaFiscale, sri
        case garanzie, liquidabilita, fonte, verificatoIl, note, condizioni
        case incidenzaCostiKID, periodoRaccomandato
        case trattenuto, retrocessione, minimoGarantito, consolidamento
        case quotaGestioneSeparata, quotaGestioneMinima, quotaGestioneMassima, rendimentoGestione, rendimentoFondi
        case costoFondi, sriFondi, volatilitaFondi, quotaAzionariaFondi, titoliStatoGestione, titoliStatoFondi, ribilanciamento
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
        incidenzaCostiKID = try? c.decodeIfPresent(Double.self, forKey: .incidenzaCostiKID)
        periodoRaccomandato = try? c.decodeIfPresent(Int.self, forKey: .periodoRaccomandato)
        trattenuto = try? c.decodeIfPresent(Double.self, forKey: .trattenuto)
        retrocessione = try? c.decodeIfPresent(Double.self, forKey: .retrocessione)
        minimoGarantito = try? c.decodeIfPresent(Double.self, forKey: .minimoGarantito)
        consolidamento = try? c.decodeIfPresent(Bool.self, forKey: .consolidamento)
        quotaGestioneSeparata = try? c.decodeIfPresent(Double.self, forKey: .quotaGestioneSeparata)
        quotaGestioneMinima = try? c.decodeIfPresent(Double.self, forKey: .quotaGestioneMinima)
        quotaGestioneMassima = try? c.decodeIfPresent(Double.self, forKey: .quotaGestioneMassima)
        rendimentoGestione = try? c.decodeIfPresent(Double.self, forKey: .rendimentoGestione)
        rendimentoFondi = try? c.decodeIfPresent(Double.self, forKey: .rendimentoFondi)
        costoFondi = try? c.decodeIfPresent(Double.self, forKey: .costoFondi)
        sriFondi = try? c.decodeIfPresent(Int.self, forKey: .sriFondi)
        volatilitaFondi = try? c.decodeIfPresent(Double.self, forKey: .volatilitaFondi)
        quotaAzionariaFondi = try? c.decodeIfPresent(Double.self, forKey: .quotaAzionariaFondi)
        titoliStatoGestione = try? c.decodeIfPresent(Double.self, forKey: .titoliStatoGestione)
        titoliStatoFondi = try? c.decodeIfPresent(Double.self, forKey: .titoliStatoFondi)
        ribilanciamento = try? c.decodeIfPresent(Bool.self, forKey: .ribilanciamento)
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
