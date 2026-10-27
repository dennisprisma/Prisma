import Foundation

/// Regole fiscali aggiunte per il fisco delle polizze e della previdenza (le altre sono in `RegoleFiscali`,
/// `Motori/MotoreFiscale.swift`): stesse fonti, un solo punto da aggiornare.
extension RegoleFiscali {
    /// Detrazione del 19% piena fino a 120.000 € di reddito complessivo, poi in proporzione fino a zero
    /// a 240.000 € (art. 15, c. 3-bis, TUIR, dalla L. 160/2019).
    static let redditoDetrazionePiena = 120_000.0
    static let redditoSenzaDetrazione = 240_000.0
    /// Premi caso morte a tutela di persone con disabilità grave: limite di 750 € (art. 15, c. 1, lett. f, TUIR).
    /// Prisma non sa quali polizze hanno questo scopo: il limite è solo ricordato nelle note.
    static let limitePremiDisabili = 750.0

    /// Premi detraibili da caso morte, invalidità e infortuni (`vita`) e non autosufficienza (`ltc`) di un
    /// contribuente: i primi fino a 530 €, insieme agli altri fino a 1.291,14 € (art. 15, c. 1, lett. f, TUIR).
    static func detraibili(vita: Double, ltc: Double) -> Double {
        min(min(max(0, vita), limitePremiVita) + max(0, ltc), limitePremiLTC)
    }

    /// Parte della detrazione del 19% che spetta con un reddito (0–1); senza reddito indicato tutta.
    static func quotaDetrazione(reddito: Double?) -> Double {
        guard let r = reddito, r > redditoDetrazionePiena else { return 1 }
        guard r < redditoSenzaDetrazione else { return 0 }
        return (redditoSenzaDetrazione - r) / (redditoSenzaDetrazione - redditoDetrazionePiena)
    }

    /// Aliquota sui rendimenti di un fondo pensione: 20%, con la parte in titoli di Stato ed equiparati al
    /// 12,5% (art. 17 D.Lgs. 252/2005 come modificato dalla L. 190/2014: i proventi dei titoli di Stato
    /// concorrono alla base per il 62,5%). Senza quota indicata il 20% su tutto.
    static func aliquotaRendimentiPrevidenza(quotaTitoliStato: Double?) -> Double {
        let q = min(max(quotaTitoliStato ?? 0, 0), 100) / 100
        return previdenzaRendimenti * (1 - q) + titoliStato * q
    }

    /// Rendimento netto annuo di un fondo pensione con la parte in titoli di Stato tassata al 12,5%:
    /// prima i costi, poi l'imposta sul risultato positivo. Con `quotaTitoliStato` nil è identico a
    /// `rendimentoNettoPrevidenza(lordo:costo:)`.
    static func rendimentoNettoPrevidenza(lordo: Double, costo: Double, quotaTitoliStato: Double?) -> Double {
        let dopoCosti = ((1 + lordo / 100) * (1 - min(max(costo, 0), 99) / 100) - 1) * 100
        return dopoCosti > 0 ? dopoCosti * (1 - aliquotaRendimentiPrevidenza(quotaTitoliStato: quotaTitoliStato) / 100) : dopoCosti
    }
}

/// La deducibilità dei contributi alla previdenza complementare di un anno (art. 10, c. 1, lett. e-bis,
/// TUIR e art. 8, c. 4, D.Lgs. 252/2005): i contributi del lavoratore e del datore di lavoro insieme fino
/// al limite (`RegoleFiscali.limiteDeducibilita`); il TFR conferito non conta nel limite.
struct DeducibilitaPrevidenza: Equatable {
    /// Contributi annui del cliente (premi dei piani).
    var lavoratore: Double
    /// Contributi annui del datore di lavoro.
    var datore: Double
    /// TFR conferito ogni anno (non si deduce e non conta nel limite).
    var tfr: Double

    var limite: Double { RegoleFiscali.limiteDeducibilita }
    /// Parte del limite che resta al cliente dopo i contributi del datore.
    var limiteLavoratore: Double { max(0, limite - datore) }
    /// Contributi del cliente che deduce dal suo reddito.
    var deducibili: Double { min(max(0, lavoratore), limiteLavoratore) }
    /// Contributi (del cliente e del datore) oltre il limite: non si deducono e non si tassano alla prestazione.
    var eccedenza: Double { max(0, lavoratore + datore - limite) }
    /// Quanto si può ancora versare e dedurre quest'anno.
    var spazio: Double { max(0, limite - lavoratore - datore) }

    /// IRPEF risparmiata oggi e quella in più usando tutto lo spazio (con il reddito lordo del cliente).
    func risparmio(reddito: Double) -> Double { RegoleFiscali.risparmioDeduzione(reddito: reddito, deduzione: deducibili) }
    func risparmioPossibile(reddito: Double) -> Double {
        RegoleFiscali.risparmioDeduzione(reddito: reddito, deduzione: limiteLavoratore) - risparmio(reddito: reddito)
    }

    /// I piani di previdenza in essere di un anno.
    init(piani: [Posizione]) {
        let previdenza = piani.filter { $0.regime == .previdenza && $0.stato == .inEssere }
        lavoratore = previdenza.reduce(0) { $0 + $1.premioAnnuo }
        datore = previdenza.reduce(0) { $0 + max(0, $1.contributoDatore ?? 0) }
        tfr = previdenza.reduce(0) { $0 + max(0, $1.tfrConferito ?? 0) }
    }

    init(lavoratore: Double, datore: Double = 0, tfr: Double = 0) {
        self.lavoratore = lavoratore
        self.datore = datore
        self.tfr = tfr
    }
}

/// Che cosa succede, fiscalmente, a una polizza o a un piano previdenziale se l'assicurato muore oggi.
struct EsitoDecesso {
    /// Somma pagata ai beneficiari prima delle imposte (valore più l'eventuale maggiorazione caso morte).
    let capitale: Double
    /// Parte a copertura del rischio demografico: esente IRPEF (art. 34, c. 5, D.P.R. 601/1973).
    let parteEsente: Double
    let imponibile: Double
    let aliquota: Double
    let imposta: Double
    /// Bollo maturato trattenuto alla liquidazione (polizze soggette).
    let bolloMaturato: Double
    var netto: Double { capitale - imposta - bolloMaturato }
    /// true se va ai beneficiari fuori dalla successione, senza imposta di successione
    /// (art. 12, c. 1, lett. c, D.Lgs. 346/1990); false per i contratti di capitalizzazione.
    let fuoriSuccessione: Bool
    let note: [String]
}

/// Detrazione dei premi di una persona (chi paga: il cliente per sé e per i familiari a carico,
/// ogni altro familiare per sé).
struct DetrazionePersona: Identifiable {
    let id: String
    let nome: String
    /// Premi annui caso morte, invalidità e infortuni.
    let premiVita: Double
    /// Premi annui non autosufficienza.
    let premiLTC: Double
    /// Reddito complessivo lordo, per la riduzione oltre 120.000 €.
    let reddito: Double?
    var detraibili: Double { RegoleFiscali.detraibili(vita: premiVita, ltc: premiLTC) }
    var quota: Double { RegoleFiscali.quotaDetrazione(reddito: reddito) }
    var detrazione: Double { MotoreFiscale.centesimi(detraibili * RegoleFiscali.detrazionePremi / 100 * quota) }
}

/// Una posizione con il suo esito al decesso.
struct VoceDecesso: Identifiable {
    let posizione: Posizione
    let esito: EsitoDecesso
    var id: String { posizione.id }
}

/// Il fisco delle polizze di un cliente: detrazioni per persona, esito al decesso, bollo, deducibilità.
struct FiscoPolizzeCliente {
    let detrazioni: [DetrazionePersona]
    var detrazioneTotale: Double { detrazioni.reduce(0) { $0 + $1.detrazione } }
    let decessi: [VoceDecesso]
    /// Capitali caso morte (rischio demografico) esenti IRPEF.
    var capitaleEsenteIRPEF: Double { decessi.reduce(0) { $0 + $1.esito.parteEsente } }
    /// Somme che vanno ai beneficiari fuori dalla successione.
    var fuoriSuccessione: Double { decessi.filter { $0.esito.fuoriSuccessione }.reduce(0) { $0 + $1.esito.capitale } }
    var impostaAlDecesso: Double { decessi.reduce(0) { $0 + $1.esito.imposta } }
    /// Bollo dell'anno su tutte le posizioni in essere e la parte delle polizze (si paga al riscatto).
    let bolloAnnuo: Double
    let bolloPolizze: Double
    let previdenza: DeducibilitaPrevidenza
    let note: [String]
}

/// Il fisco delle polizze e della previdenza: regole verificate una per una in `ProvaCalcoliFamiglia`.
enum FiscoPolizze {
    /// Esito fiscale al decesso dell'assicurato, alla data. nil per le posizioni che non sono polizze vita,
    /// coperture caso morte o previdenza (fondi, conti, immobili, debiti: entrano nell'asse ereditario).
    static func alDecesso(_ p: Posizione, data: Date = Date()) -> EsitoDecesso? {
        let testo = (p.nome + " " + p.tipologia).lowercased()
        switch p.regime {
        case .esente:
            // Coperture caso morte: il capitale è tutto rischio demografico
            guard p.area == .protezione else { return nil }
            let casoMorte = p.rischio == .vita || (p.rischio == nil && (testo.contains("caso morte") || testo.contains("tcm") || testo.contains("temporanea")))
            guard casoMorte, (p.capitaleAssicurato ?? 0) > 0 else { return nil }
            if let s = p.scadenza, s < Calendar.current.startOfDay(for: data) { return nil }
            let capitale = MotoreProtezioneFamiglia.capitaleAttuale(p, al: data)
            return EsitoDecesso(capitale: capitale, parteEsente: capitale, imponibile: 0, aliquota: 0, imposta: 0, bolloMaturato: 0,
                                fuoriSuccessione: true,
                                note: ["Capitale caso morte esente IRPEF (art. 34 D.P.R. 601/1973) e fuori dalla successione: ai beneficiari designati."])

        case .polizza:
            let valore = max(0, p.valore)
            let versato = p.totaleVersato ?? p.versamentoIniziale
            let aliquota = MotoreFiscale.aliquotaGuadagno(p)
            let imponibile = MotoreFiscale.centesimi(max(0, valore - versato))
            let imposta = MotoreFiscale.centesimi(imponibile * aliquota / 100)
            let bollo = MotoreFiscale.calcola(p, data: data).bolloMaturato
            // Il contratto di capitalizzazione non assicura una vita: nessuna parte esente, nell'asse
            if p.contrattoCapitalizzazione {
                return EsitoDecesso(capitale: valore, parteEsente: 0, imponibile: imponibile, aliquota: aliquota, imposta: imposta,
                                    bolloMaturato: bollo, fuoriSuccessione: false,
                                    note: ["Contratto di capitalizzazione: non è una polizza vita, il valore entra nell'asse ereditario e il guadagno si tassa."])
            }
            // Polizza vita: il rendimento finanziario si tassa, la maggiorazione caso morte (capitale oltre il valore) no
            let capitale = max(valore, p.capitaleAssicurato ?? 0)
            var note = ["Polizza vita: ai beneficiari fuori dalla successione (art. 12 D.Lgs. 346/1990); il guadagno finanziario (valore − premi) si tassa al \(CifreDoc.percento(aliquota, decimali: 2))."]
            if capitale > valore { note.append("Maggiorazione caso morte di \(CifreDoc.euro(capitale - valore)): rischio demografico, esente IRPEF.") }
            return EsitoDecesso(capitale: capitale, parteEsente: capitale - valore, imponibile: imponibile, aliquota: aliquota, imposta: imposta,
                                bolloMaturato: bollo, fuoriSuccessione: true, note: note)

        case .previdenza:
            // Riscatto per decesso: aliquota agevolata (15% → 9%) sui contributi dedotti
            let f = MotoreFiscale.calcola(p, data: data)
            guard let u = f.uscite.first(where: { $0.causa == .riscattoAgevolato }) else { return nil }
            return EsitoDecesso(capitale: u.importo, parteEsente: 0, imponibile: u.imponibile, aliquota: u.aliquota, imposta: u.imposta,
                                bolloMaturato: 0, fuoriSuccessione: true,
                                note: ["Previdenza complementare: riscatto per decesso ai beneficiari o agli eredi, fuori dalla successione, al \(CifreDoc.percento(u.aliquota, decimali: 2)) sui contributi dedotti."])

        case .fondo, .deposito:
            return nil
        }
    }

    /// Premi detraibili per persona: ogni copertura in essere va a chi la paga (l'assicurato se è il cliente o un
    /// familiare non a carico; il cliente per i familiari a carico).
    static func detrazioniPerPersona(cliente: Cliente, posizioni: [Posizione], data: Date = Date()) -> [DetrazionePersona] {
        let oggi = Calendar.current.startOfDay(for: data)
        let coperture = posizioni.filter { $0.area == .protezione && $0.stato == .inEssere && ($0.scadenza.map { $0 >= oggi } ?? true) }
        var vita: [String: Double] = [:]
        var ltc: [String: Double] = [:]
        for c in coperture {
            let assicurato = MotoreProtezioneFamiglia.assicurato(c, cliente: cliente)
            let familiare = cliente.famiglia.first { $0.id == assicurato }
            let chiPaga = (familiare.map { !$0.aCarico } ?? false) ? assicurato : cliente.id
            switch c.rischio ?? .altro {
            case .vita, .invalidita, .infortuni: vita[chiPaga, default: 0] += c.premioAnnuo
            case .ltc: ltc[chiPaga, default: 0] += c.premioAnnuo
            case .salute, .casa, .rc, .altro: break
            }
        }
        var persone: [(String, String, Double?)] = [(cliente.id, cliente.nome, cliente.profilo.redditoLordoAnnuo)]
        persone += cliente.famiglia.map { f -> (String, String, Double?) in (f.id, f.nome, f.lavoro?.redditoLavoro) }
        return persone.compactMap { voce -> DetrazionePersona? in
            let (id, nome, reddito) = voce
            let v = vita[id] ?? 0
            let l = ltc[id] ?? 0
            guard v > 0 || l > 0 else { return nil }
            return DetrazionePersona(id: id, nome: nome, premiVita: v, premiLTC: l, reddito: reddito)
        }
    }

    /// Il riepilogo del fisco delle polizze di un cliente, alla data.
    static func riepilogo(cliente: Cliente, posizioni: [Posizione], data: Date = Date()) -> FiscoPolizzeCliente {
        let mie = posizioni.filter { $0.clienteId == cliente.id && $0.stato == .inEssere }
        let decessi = mie.compactMap { p in alDecesso(p, data: data).map { VoceDecesso(posizione: p, esito: $0) } }
        let bollo = mie.reduce(0) { $0 + MotoreFiscale.bolloAnnuo($1, valore: $1.valore) }
        let bolloPolizze = mie.filter { $0.regime == .polizza }.reduce(0) { $0 + MotoreFiscale.bolloAnnuo($1, valore: $1.valore) }
        var note = metodo
        if cliente.famiglia.contains(where: { $0.nonAutosufficiente == true }) {
            note.append("In famiglia c'è una persona non autosufficiente: i premi caso morte a tutela di una persona con disabilità grave sono detraibili fino a \(CifreDoc.euroCentesimi(RegoleFiscali.limitePremiDisabili)), non solo fino a \(CifreDoc.euroCentesimi(RegoleFiscali.limitePremiVita)).")
        }
        return FiscoPolizzeCliente(detrazioni: detrazioniPerPersona(cliente: cliente, posizioni: mie, data: data), decessi: decessi,
                                   bolloAnnuo: bollo, bolloPolizze: bolloPolizze, previdenza: DeducibilitaPrevidenza(piani: mie), note: note)
    }

    /// Le regole applicate, con le fonti (note di metodo dei prospetti).
    static let metodo = [
        "Detrazione IRPEF del 19% dei premi (art. 15 TUIR): caso morte, invalidità permanente oltre il 5% e infortuni fino a 530 € l'anno; con la non autosufficienza fino a 1.291,14 € in tutto; per contribuente, piena fino a 120.000 € di reddito e poi ridotta fino a zero a 240.000 €. Premi pagati con mezzi tracciabili.",
        "Chi detrae: il contraente, per sé e per i familiari fiscalmente a carico; Prisma considera contraente il cliente per sé e per chi è a carico, e ogni altro familiare assicurato per sé. Non applicato il tetto alle spese detraibili oltre 75.000 € di reddito (art. 16-ter TUIR).",
        "Capitali caso morte: esenti IRPEF per la parte di rischio demografico (art. 34 D.P.R. 601/1973) e fuori dalla successione (art. 12 D.Lgs. 346/1990); nelle polizze di investimento si tassa il guadagno finanziario. I contratti di capitalizzazione entrano nell'asse.",
        "Imposta di bollo dello 0,20% annuo sui prodotti finanziari (D.P.R. 642/1972, art. 13, c. 2-ter): esenti le polizze di Ramo I (e IV) e i fondi pensione; soggetti il Ramo III, il Ramo V (capitalizzazione) e la parte delle multiramo fuori dalla gestione separata; nelle polizze si paga al riscatto.",
        "Guadagni al 26%, con la parte in titoli di Stato ed equiparati al 12,5% (aliquota ponderata).",
        "Previdenza complementare: contributi del cliente e del datore deducibili insieme fino al limite annuo, il TFR non conta; rendimenti del fondo al 20% (12,5% sulla parte in titoli di Stato); prestazione al 15%, che scende di 0,30 punti per ogni anno oltre il 15° fino al 9%.",
    ]
}
