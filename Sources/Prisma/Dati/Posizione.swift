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
    case bozza, presentata, accettata, rifiutata

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
    var rendimentoAtteso: Double?
    var costoIngresso: Double?
    var costoAnnuo: Double?
    var aliquotaFiscale: Double?
    /// Indicatore sintetico di rischio del KID (1–7).
    var sri: Int?

    var garanzie = ""
    var note = ""
    var esito: EsitoProposta?
    /// Scheda prodotto da cui nasce (dalla versione 9 dell'archivio).
    var prodottoId: String?
    var creataIl = Date()
    /// Valori precedenti a quello attuale, dal più vecchio (dalla versione 12 dell'archivio).
    var rilevazioni: [Rilevazione]?

    // Costi e fiscalità (dalla versione 13 dell'archivio)
    /// Trattenuto sul rendimento della gestione separata, in punti percentuali all'anno.
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
    /// Multiramo: quota del valore in gestione separata (Ramo I, 0–100), esente da bollo.
    var quotaGestioneSeparata: Double?

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

    /// Costo annuo complessivo in percentuale: gestione più trattenuto sul rendimento.
    var costoComplessivo: Double? {
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

    /// Polizza multiramo (Ramo I e Ramo III insieme).
    var multiramo: Bool {
        guard regime == .polizza else { return false }
        let t = tipologia.lowercased()
        return t.contains("multiramo") || (Self.ramoI(t) && t.contains("ramo iii"))
    }

    /// Polizza rivalutabile di Ramo I (gestione separata): capitale garantito, niente bollo.
    var gestioneSeparata: Bool {
        guard regime == .polizza, !multiramo else { return false }
        let t = tipologia.lowercased()
        return Self.ramoI(t) || t.contains("rivalutabil") || t.contains("gestione separata")
    }

    /// "Ramo I" come parola intera: non «Ramo III» né «Ramo IV».
    private static func ramoI(_ t: String) -> Bool {
        t.range(of: #"\bramo i\b"#, options: .regularExpression) != nil
    }

    /// Parte del valore su cui si paga il bollo dello 0,20% (0–1): tutto per fondi e depositi, niente
    /// per il Ramo I, la parte fuori dalla gestione separata per le multiramo.
    var quotaBollo: Double {
        let fuoriGestione = 1 - min(max(quotaGestioneSeparata ?? 0, 0), 100) / 100
        if let conBollo { return conBollo ? (multiramo ? fuoriGestione : 1) : 0 }
        switch regime {
        case .fondo, .deposito: return 1
        case .polizza: return gestioneSeparata ? 0 : (multiramo ? fuoriGestione : 1)
        case .previdenza, .esente: return 0
        }
    }

    /// Bollo dello 0,20%: quello indicato o, se manca, per regime (le rivalutabili di Ramo I ne sono esenti).
    var soggettaBollo: Bool { quotaBollo > 0 }

    /// Lo storico completo: le rilevazioni passate e, in fondo, il valore attuale.
    var storicoValori: [Rilevazione] {
        var elenco = (rilevazioni ?? []).sorted { $0.data < $1.data }
        if let controvalore, let d = dataValore ?? decorrenza {
            elenco.removeAll { Calendar.current.isDate($0.data, inSameDayAs: d) }
            elenco.append(Rilevazione(data: d, controvalore: controvalore, versato: totaleVersato))
        }
        return elenco
    }

    /// Conserva il valore attuale tra le rilevazioni se quello nuovo è cambiato.
    mutating func registraValorePrecedente(_ prima: Posizione) {
        guard prima.stato == .inEssere, let valore = prima.controvalore, valore > 0,
              prima.controvalore != controvalore || prima.dataValore != dataValore else { return }
        let d = prima.dataValore ?? prima.creataIl
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
}
