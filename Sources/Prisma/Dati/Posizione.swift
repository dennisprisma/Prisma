import Foundation

/// Area di una posizione del cliente.
enum AreaPosizione: String, Codable, CaseIterable, Identifiable {
    case investimento, risparmio, previdenza, protezione, liquidita, immobili, debiti

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .investimento: return "Investimento"
        case .risparmio: return "Risparmio"
        case .previdenza: return "Previdenza"
        case .protezione: return "Protezione"
        case .liquidita: return "Liquidità"
        case .immobili: return "Immobili"
        case .debiti: return "Debiti"
        }
    }

    /// Le aree che hanno senso proiettare nel tempo.
    var proiettabile: Bool { [.investimento, .risparmio, .previdenza].contains(self) }

    /// I debiti si sottraggono al patrimonio.
    var passivo: Bool { self == .debiti }
}

/// In essere, in proposta (non in essere) o chiusa.
enum StatoPosizione: String, Codable, CaseIterable, Identifiable {
    case inEssere, proposta, chiusa

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .inEssere: return "In essere"
        case .proposta: return "Proposta"
        case .chiusa: return "Chiusa"
        }
    }
}

/// Avanzamento di una proposta.
enum EsitoProposta: String, Codable, CaseIterable, Identifiable {
    case bozza, presentata, accettata, rifiutata, rimandata   // rimandata: dalla versione 21 dell'archivio

    var id: String { rawValue }
    var nome: String { rawValue.capitalized }
}

/// Frequenza dei premi o dei versamenti.
enum Frequenza: String, Codable, CaseIterable, Identifiable {
    case unica, mensile, trimestrale, semestrale, annuale

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .unica: return "Nessun versamento periodico"
        case .mensile: return "Mensile"
        case .trimestrale: return "Trimestrale"
        case .semestrale: return "Semestrale"
        case .annuale: return "Annuale"
        }
    }

    var volteAllAnno: Int {
        switch self {
        case .unica: return 0
        case .mensile: return 12
        case .trimestrale: return 4
        case .semestrale: return 2
        case .annuale: return 1
        }
    }
}

/// Rischio coperto da una posizione di protezione.
enum RischioCoperto: String, Codable, CaseIterable, Identifiable {
    case vita, invalidita, salute, ltc, infortuni, casa, rc, altro

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .vita: return "Caso morte"
        case .invalidita: return "Invalidità"
        case .salute: return "Salute"
        case .ltc: return "Non autosufficienza (LTC)"
        case .infortuni: return "Infortuni"
        case .casa: return "Casa"
        case .rc: return "Responsabilità civile"
        case .altro: return "Altro"
        }
    }
}

/// Come si tassa il guadagno di una posizione (dalla versione 13 dell'archivio).
enum RegimeFiscale: String, Codable, CaseIterable, Identifiable {
    /// Polizze vita (Ramo I, Ramo III, multiramo, capitalizzazione): 26% sul guadagno al riscatto,
    /// 12,5% sulla parte in titoli di Stato.
    case polizza
    /// Fondi, ETF, titoli: 26% sulla plusvalenza, 12,5% sulla parte in titoli di Stato.
    case fondo
    /// Previdenza complementare (fondi pensione, PIP): rendimenti già tassati nel fondo, prestazione
    /// tassata secondo la causa e gli anni di partecipazione.
    case previdenza
    /// Conti e depositi: 26% sugli interessi.
    case deposito
    /// Nessuna imposta sul guadagno (coperture, immobili, debiti).
    case esente

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .polizza: return "Polizza vita"
        case .fondo: return "Fondo, ETF o titoli"
        case .previdenza: return "Previdenza complementare"
        case .deposito: return "Conto o deposito"
        case .esente: return "Nessuna imposta sul guadagno"
        }
    }
}

/// Un valore della posizione registrato in una data: lo storico serve al resoconto per mostrare
/// come è andata negli ultimi mesi (dalla versione 12 dell'archivio).
struct Rilevazione: Codable, Hashable {
    var data: Date
    var controvalore: Double
    /// Totale versato a quella data, se noto.
    var versato: Double?
}

/// Una posizione del cliente: un prodotto in essere o una proposta, sempre con il suo canale.
struct Posizione: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var clienteId: String
    var canale: Canale
    var stato: StatoPosizione
    var area: AreaPosizione

    // Prodotto
    var nome: String
    var tipologia = ""
    var emittente = ""
    var numeroContratto = ""
    var contraente = ""
    var assicurato = ""
    var beneficiari = ""
    var decorrenza: Date?
    var scadenza: Date?

    // Flussi
    /// Capitale iniziale o premio unico.
    var versamentoIniziale: Double = 0
    /// Importo del premio o del versamento periodico.
    var premio: Double = 0
    var frequenza: Frequenza = .unica

    // Valori
    /// Valore attuale (controvalore o, per i debiti, debito residuo).
    var controvalore: Double?
    var dataValore: Date?
    var totaleVersato: Double?
    var capitaleAssicurato: Double?
    var rischio: RischioCoperto?

    // Ipotesi e costi (percentuali annue)
    /// Rendimento lordo annuo ipotizzato (%). Nelle multiramo è il rendimento lordo complessivo del contratto
    /// (media pesata delle due parti): con i dati separati i calcoli usano `rendimentoGestione` e
    /// `rendimentoFondi`; se ne manca uno lo ricavano da questo (`lordoGestione`, `lordoFondi`).
    var rendimentoAtteso: Double?
    var costoIngresso: Double?
    /// Costo annuo (%). Nelle multiramo: commissioni del contratto senza il trattenuto della gestione
    /// separata; con i dati separati vale per la parte in fondi se `costoFondi` manca.
    var costoAnnuo: Double?
    var aliquotaFiscale: Double?
    /// Indicatore sintetico di rischio del KID (1–7). Nelle multiramo è l'SRI del KID della combinazione scelta.
    var sri: Int?

    var garanzie = ""
    var note = ""
    var esito: EsitoProposta?
    /// Seguito della proposta: presentazione, esito con data e motivo, ripresa (dalla versione 21 dell'archivio).
    var seguito: SeguitoProposta?
    /// Scheda prodotto da cui nasce (dalla versione 9 dell'archivio).
    var prodottoId: String?
    var creataIl = Date()
    /// Valori precedenti a quello attuale, dal più vecchio (dalla versione 12 dell'archivio).
    var rilevazioni: [Rilevazione]?

    // Costi e fiscalità (dalla versione 13 dell'archivio)
    /// Trattenuto sul rendimento della gestione separata, in punti percentuali all'anno.
    /// Nelle multiramo vale per la sola parte in gestione separata.
    var trattenuto: Double?
    /// Regime fiscale scelto; se manca si ricava dall'area e dalla tipologia (`regime`).
    var regimeFiscale: RegimeFiscale?
    /// Quota investita in titoli di Stato ed equiparati (0–100), tassata al 12,5%.
    var quotaTitoliStato: Double?
    /// Soggetta all'imposta di bollo dello 0,20% annuo (Ramo III, multiramo, fondi, depositi).
    var conBollo: Bool?
    /// Previdenza: data della prima adesione a una forma pensionistica complementare (conta per gli anni
    /// di partecipazione, anche se la posizione è nata da un trasferimento).
    var primaAdesione: Date?
    /// Previdenza: contributi versati e non dedotti, che non si tassano alla prestazione.
    var contributiNonDedotti: Double?
    /// Multiramo: quota in gestione separata (0–100), esente da bollo: per una posizione in essere quella
    /// del valore di oggi (dall'estratto conto), per una proposta quella del premio. È anche la quota a cui
    /// si ribilancia.
    var quotaGestioneSeparata: Double?

    // Dati per i motori di analisi (rendimenti, riscatto, rischio, famiglia). Tutti facoltativi:
    // il Codable è sintetizzato, quindi ogni campo nuovo DEVE essere Optional (gli archivi di prima
    // non lo hanno). Senza questi dati i motori si comportano come prima.

    /// Movimenti reali con la loro data (versamenti, riscatti parziali, cedole), dal più vecchio.
    /// Se mancano, i flussi si ricostruiscono da decorrenza, premi e rilevazioni.
    var movimenti: [Movimento]?
    /// Penali di riscatto della posizione, sul valore, per annualità: [2° anno, 3° anno, …] in %,
    /// come `CondizioniContratto.penali`. Prevalgono su quelle della scheda prodotto (`penale(anno:prodotto:)`).
    var penali: [Double]?
    /// Mesi dalla decorrenza in cui il riscatto non è consentito (come `CondizioniContratto.mesiBloccoRiscatto`).
    var mesiBloccoRiscatto: Int?
    /// Costo d'uscita fisso in % del valore riscattato, oltre alle penali per anno (dal KID).
    var costoUscita: Double?
    /// Incidenza annua dei costi dichiarata nel KID (RIY, % annuo al periodo raccomandato), da confrontare con quella calcolata.
    var incidenzaCostiKID: Double?
    /// Periodo di detenzione raccomandato dal KID, in anni.
    var periodoRaccomandato: Int?
    /// Gestione separata: rendimento minimo garantito annuo (%); 0 = solo capitale garantito.
    /// Nelle multiramo vale per la sola parte in gestione separata.
    var minimoGarantito: Double?
    /// Gestione separata: true se il rendimento accreditato si consolida ogni anno (non si perde più);
    /// false se la garanzia vale solo a scadenza o in caso di decesso.
    /// Nelle multiramo vale per la sola parte in gestione separata.
    var consolidamento: Bool?
    /// Gestione separata: quota del rendimento lordo retrocessa al cliente (0–100), alternativa al
    /// trattenuto fisso (`trattenuto`). Il lordo della gestione è `rendimentoAtteso`.
    /// Nelle multiramo vale per la sola parte in gestione separata (il lordo è `rendimentoGestione`).
    var retrocessione: Double?
    /// Volatilità annua attesa (%, deviazione standard); se manca si ricava dall'SRI.
    var volatilita: Double?
    /// Quota investita in azioni (0–100), per le crisi storiche; se manca si ricava da tipologia e SRI.
    var quotaAzionaria: Double?
    /// Persona assicurata: id del cliente o di un suo `Familiare` (il testo `assicurato` resta per il prospetto).
    var assicuratoId: String?
    /// Protezione: capitale caso morte decrescente nel tempo (tipicamente legato al mutuo).
    var capitaleDecrescente: Bool?
    /// Previdenza: contributo annuo del datore di lavoro (€), conta nel limite di deducibilità.
    var contributoDatore: Double?
    /// Previdenza: TFR conferito ogni anno (€), non conta nel limite di deducibilità.
    var tfrConferito: Double?
    /// Debiti: tasso annuo nominale del finanziamento (%), per il piano di ammortamento alla francese.
    var tassoDebito: Double?
    /// Debiti: quota del debito a carico del cliente (0–100) se il finanziamento è cointestato; nil = tutto.
    var quotaDebito: Double?

    // Multiramo a due parti (dalla versione 20 dell'archivio): gestione separata e fondi con dati separati.
    // La parte in gestione separata usa `quotaGestioneSeparata` (quota), `trattenuto`, `retrocessione`,
    // `minimoGarantito` e `consolidamento`; i campi qui sotto descrivono il resto. Basta uno di questi campi
    // perché i motori calcolino le due parti separatamente (`multiramoDivisa`); senza, tutto come prima.

    /// Multiramo: rendimento lordo annuo ipotizzato della gestione separata (%), prima del trattenuto.
    var rendimentoGestione: Double?
    /// Multiramo: rendimento lordo annuo ipotizzato dei fondi (Ramo III, %), prima di commissioni e costi dei fondi.
    var rendimentoFondi: Double?
    /// Multiramo: costi annui della parte in fondi (%): commissione di gestione della compagnia più costi
    /// correnti degli OICR sottostanti, sul valore dei fondi.
    var costoFondi: Double?
    /// Multiramo: indicatore di rischio (1–7) della sola parte in fondi (KID specifico o documento dell'opzione).
    var sriFondi: Int?
    /// Multiramo: volatilità annua attesa della parte in fondi (%, deviazione standard).
    var volatilitaFondi: Double?
    /// Multiramo: quota in azioni della parte in fondi (0–100, della parte, non del contratto).
    var quotaAzionariaFondi: Double?
    /// Multiramo: quota in titoli di Stato della gestione separata (0–100), per l'aliquota al 12,5%.
    var titoliStatoGestione: Double?
    /// Multiramo: quota in titoli di Stato della parte in fondi (0–100).
    var titoliStatoFondi: Double?
    /// Multiramo: true se ogni anno il contratto riporta la gestione separata alla quota scelta
    /// (`quotaGestioneSeparata`); nil o false = nessun ribilanciamento, le parti si allontanano dalle quote.
    var ribilanciamento: Bool?
    /// Dati cambiati dal confronto con i documenti (polizze, appendici, KID), dal più vecchio (dalla versione 23).
    var variazioni: [VariazioneDossier]?
    // Dalla versione 24 dell'archivio
    /// Metro di confronto del rendimento scelto per questa posizione (id di `SerieRiferimento`); nil = quello del suo tipo.
    var riferimento: String?

    /// Premi o versamenti dell'anno.
    var premioAnnuo: Double { premio * Double(frequenza.volteAllAnno) }

    /// Valore da usare nei riepiloghi: il controvalore se c'è, altrimenti il versato.
    var valore: Double {
        controvalore ?? totaleVersato ?? versamentoIniziale
    }

    /// Anni da oggi alla scadenza (almeno 1), arrotondati all'anno più vicino: 10 anni e 11 mesi
    /// sono 11 anni, non 10.
    var anniAllaScadenza: Int? {
        guard let scadenza else { return nil }
        let mesi = Calendar.current.dateComponents([.month], from: Date(), to: scadenza).month ?? 0
        return max(1, Int((Double(mesi) / 12).rounded()))
    }

    /// true se la scadenza cade entro `giorni` da oggi.
    func scadeEntro(_ giorni: Int) -> Bool {
        guard let scadenza, stato == .inEssere else { return false }
        let limite = Calendar.current.date(byAdding: .day, value: giorni, to: Date()) ?? Date()
        return scadenza >= Calendar.current.startOfDay(for: Date()) && scadenza <= limite
    }

    /// Costo annuo complessivo in percentuale: gestione più trattenuto sul rendimento. Nelle multiramo a due
    /// parti: trattenuto sulla gestione separata e costi dei fondi, ognuno pesato sulla sua quota (nil se
    /// nessun costo è indicato, come prima).
    var costoComplessivo: Double? {
        if multiramoDivisa { return costiIndicati ? costoComposto : nil }
        guard costoAnnuo != nil || trattenuto != nil else { return nil }
        return (costoAnnuo ?? 0) + (trattenuto ?? 0)
    }

    /// Il regime fiscale: quello scelto o, se manca, quello dell'area e della tipologia.
    var regime: RegimeFiscale {
        if let regimeFiscale { return regimeFiscale }
        switch area {
        case .previdenza: return .previdenza
        case .liquidita: return .deposito
        case .protezione, .immobili, .debiti: return .esente
        case .investimento, .risparmio:
            let testo = (tipologia + " " + emittente).lowercased()
            let polizza = ["polizza", "ramo", "capitalizzazione", "multiramo", "unit", "assicuraz"].contains { testo.contains($0) }
            return polizza ? .polizza : .fondo
        }
    }

    /// Polizza multiramo (Ramo I e Ramo III insieme): la regola sul testo è `multiramo(tipologia:)`.
    var multiramo: Bool {
        regime == .polizza && Self.multiramo(tipologia: tipologia)
    }

    /// Polizza rivalutabile di Ramo I (gestione separata): capitale garantito, niente bollo.
    var gestioneSeparata: Bool {
        guard regime == .polizza, !multiramo else { return false }
        let t = tipologia.lowercased()
        return Self.ramoI(t) || t.contains("rivalutabil") || t.contains("gestione separata")
    }

    /// Contratto di capitalizzazione (Ramo V): non assicura una vita, paga il bollo ed entra nell'asse ereditario.
    var contrattoCapitalizzazione: Bool {
        guard regime == .polizza else { return false }
        let t = (nome + " " + tipologia).lowercased()
        return t.contains("capitalizzazione") || t.range(of: #"\bramo v\b"#, options: .regularExpression) != nil
    }

    /// "Ramo I" come parola intera: non «Ramo III» né «Ramo IV».
    static func ramoI(_ t: String) -> Bool {
        t.range(of: #"\bramo i\b"#, options: .regularExpression) != nil
    }

    /// Parte del valore su cui si paga il bollo dello 0,20% (0–1): tutto per fondi e depositi, niente
    /// per il Ramo I, la parte fuori dalla gestione separata per le multiramo. I contratti di
    /// capitalizzazione (Ramo V) lo pagano anche se rivalutabili: sono esenti solo i rami vita I e IV
    /// (D.P.R. 642/1972, tariffa art. 13, c. 2-ter, e D.M. 24 maggio 2012).
    var quotaBollo: Double {
        // Con i dati separati la quota mancante è la stima del 50% (come la resistenza); senza, bollo su tutto
        let fuoriGestione = 1 - min(max(quotaGestioneSeparata ?? (multiramoDivisa ? Self.quotaGestionePredefinita : 0), 0), 100) / 100
        if let conBollo { return conBollo ? (multiramo ? fuoriGestione : 1) : 0 }
        switch regime {
        case .fondo, .deposito: return 1
        case .polizza: return gestioneSeparata && !contrattoCapitalizzazione ? 0 : (multiramo ? fuoriGestione : 1)
        case .previdenza, .esente: return 0
        }
    }

    /// Bollo dello 0,20%: quello indicato o, se manca, per regime (le rivalutabili di Ramo I ne sono esenti).
    var soggettaBollo: Bool { quotaBollo > 0 }

    /// Lo storico completo: le rilevazioni passate e, in fondo, il valore attuale.
    var storicoValori: [Rilevazione] {
        var elenco = rilevazioni ?? []
        // Senza la data del valore: se ci sono valori passati, quello attuale è di oggi (non della decorrenza,
        // che lo metterebbe prima dei valori passati)
        let d = dataValore ?? (elenco.isEmpty ? decorrenza : Self.oggiArrotondato)
        if let controvalore, let d {
            elenco.removeAll { Calendar.current.isDate($0.data, inSameDayAs: d) }
            elenco.append(Rilevazione(data: d, controvalore: controvalore, versato: totaleVersato))
        }
        return elenco.sorted { $0.data < $1.data }
    }

    /// Oggi a secondi interi, come il resto dell'archivio.
    static var oggiArrotondato: Date { Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down)) }

    /// Conserva il valore attuale tra le rilevazioni se quello nuovo è cambiato.
    mutating func registraValorePrecedente(_ prima: Posizione) {
        // Un valore nuovo senza data è di oggi: senza, lo storico non saprebbe dove metterlo
        if dataValore == nil, controvalore != nil, prima.controvalore != controvalore { dataValore = Self.oggiArrotondato }
        guard prima.stato == .inEssere, let valore = prima.controvalore, valore > 0,
              prima.controvalore != controvalore || prima.dataValore != dataValore else { return }
        let d = prima.dataValore ?? prima.creataIl
        // Il valore di prima non può essere più recente di quello nuovo (posizioni senza data del valore)
        if let nuovo = dataValore, Calendar.current.startOfDay(for: d) >= Calendar.current.startOfDay(for: nuovo) { return }
        var elenco = rilevazioni ?? []
        elenco.removeAll { Calendar.current.isDate($0.data, inSameDayAs: d) }
        // Date a secondi interi, come il resto dell'archivio
        elenco.append(Rilevazione(data: Date(timeIntervalSinceReferenceDate: d.timeIntervalSinceReferenceDate.rounded(.down)),
                                  controvalore: valore, versato: prima.totaleVersato))
        rilevazioni = elenco.sorted { $0.data < $1.data }
    }

    var scaduta: Bool {
        guard let scadenza, stato == .inEssere else { return false }
        return scadenza < Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Letture dei dati per i motori (i nuovi campi con i loro ripieghi)

    /// Penale di riscatto (%) chiesto all'inizio dell'anno di contratto `anno` (2 = dal 13° mese):
    /// quella della posizione se indicata, altrimenti quella della scheda prodotto, altrimenti 0.
    func penale(anno: Int, prodotto: Prodotto?) -> Double {
        if let penali {
            let i = anno - 2
            return i >= 0 && i < penali.count ? penali[i] : 0
        }
        return prodotto?.condizioni?.penale(anno: anno) ?? 0
    }

    /// Mesi di blocco del riscatto: della posizione, della scheda prodotto o, se non si sa, nil.
    func bloccoRiscatto(prodotto: Prodotto?) -> Int? {
        mesiBloccoRiscatto ?? prodotto?.condizioni?.mesiBloccoRiscatto
    }

    /// Mesi interi che mancano alla scadenza (debiti: durata residua del finanziamento); nil senza scadenza,
    /// 0 se già scaduta.
    func mesiResidui(al data: Date = Date()) -> Int? {
        guard let scadenza else { return nil }
        let mesi = Calendar.current.dateComponents([.month], from: data, to: scadenza).month ?? 0
        return max(0, mesi)
    }
}

/// Un movimento reale di una posizione: versamento (importo positivo) o uscita (importo negativo:
/// riscatto parziale, cedola, prestazione).
struct Movimento: Codable, Hashable {
    var data: Date
    /// Euro: + versamento del cliente, − somma incassata dal cliente.
    var importo: Double
    var nota = ""
}

extension Movimento {
    private enum CodingKeys: String, CodingKey { case data, importo, nota }

    /// Lettura tollerante: un movimento malformato non deve far scartare l'archivio.
    init(from decoder: Decoder) throws {
        // Anche un elemento che non è un oggetto (un numero, un testo) diventa un movimento vuoto, ignorato dai calcoli
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.init(data: Date(timeIntervalSinceReferenceDate: 0), importo: 0, nota: "")
            return
        }
        self.init(data: (try? c.decode(Date.self, forKey: .data)) ?? Date(timeIntervalSinceReferenceDate: 0),
                  importo: (try? c.decode(Double.self, forKey: .importo)) ?? 0,
                  nota: (try? c.decode(String.self, forKey: .nota)) ?? "")
    }
}
