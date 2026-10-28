import Foundation

/// Una posizione in essere nel resoconto: quanto è stato versato, quanto vale, come è andata.
struct VoceResoconto: Identifiable {
    let posizione: Posizione
    var id: String { posizione.id }
    /// Totale versato (solo per investimento, risparmio e previdenza).
    let versato: Double?
    let valore: Double
    /// Valore meno versato, in euro e in percentuale del versato.
    let risultato: Double?
    let risultatoPercento: Double?
    /// Rendimento medio annuo dei versamenti (tasso interno sui flussi alle loro date, XIRR), se la posizione
    /// ha almeno un anno.
    let rendimentoAnnuo: Double?
    /// Variazione degli ultimi 12 mesi al netto dei versamenti, in euro e in percentuale.
    let variazione12: Double?
    let variazione12Percento: Double?
    /// Costi stimati di un anno: gestione, trattenuto sul rendimento e bollo (dettaglio in `fisco`).
    let costoAnnuo: Double?
    /// Anni dalla decorrenza alla data del valore.
    let anni: Double?
    /// Imposte, penale e netto incassabile se si chiudesse oggi; costi divisi per voce.
    let fisco: EsitoFiscale
    /// Rendimento medio annuo dei versamenti calcolato sul netto incassabile oggi.
    let rendimentoNettoAnnuo: Double?
    /// I flussi alle loro date su cui si calcola il rendimento (nil se la posizione ha meno di un anno o mancano i dati).
    var flussiDatati: MotoreResoconto.FlussiDatati? = nil

    var finanziaria: Bool { posizione.area.proiettabile }
}

struct TotaleCanaleResoconto: Identifiable {
    let canale: Canale
    var id: Canale { canale }
    let posizioni: Int
    /// Attività in essere del canale (debiti esclusi).
    let valore: Double
    /// Solo le posizioni finanziarie del canale.
    let versato: Double
    let valoreFinanziario: Double
    var risultato: Double { valoreFinanziario - versato }
    let premiAnnui: Double
    let costoAnnuo: Double
}

struct TotaleAreaResoconto: Identifiable {
    let area: AreaPosizione
    var id: AreaPosizione { area }
    let posizioni: Int
    let valore: Double
    /// Quota (0–1) sulle attività; per i debiti sul totale dei debiti.
    let quota: Double
}

/// Una scadenza dei prossimi 12 mesi (o già passata) di una posizione in essere.
struct ScadenzaResoconto: Identifiable {
    let posizione: Posizione
    var id: String { posizione.id }
    let data: Date
    let scaduta: Bool
    /// Cosa succede: "scadenza del contratto", "rinnovo", "fine del finanziamento".
    let cosa: String
}

/// Il resoconto delle posizioni in essere di un cliente, già calcolato.
struct EsitoResoconto {
    let cliente: String
    let data: Date
    /// Tutte le posizioni in essere, per area e per nome.
    let voci: [VoceResoconto]
    let riepilogo: RiepilogoPosizioni
    let canali: [TotaleCanaleResoconto]
    let aree: [TotaleAreaResoconto]
    let scadenze: [ScadenzaResoconto]
    /// Proposte ancora aperte (bozza o presentata).
    let proposte: [Posizione]

    // Le posizioni finanziarie (investimento, risparmio, previdenza)
    let versato: Double
    let valoreFinanziario: Double
    var risultato: Double { valoreFinanziario - versato }
    var risultatoPercento: Double { versato > 0 ? risultato / versato * 100 : 0 }
    let rendimentoAnnuo: Double?
    let variazione12: Double?
    let variazione12Percento: Double?
    let costoAnnuo: Double
    /// Costi di un anno sul valore delle posizioni con il costo indicato, in percentuale.
    let incidenzaCosti: Double?
    /// Rendimento medio annuo complessivo sul netto incassabile oggi.
    let rendimentoNettoAnnuo: Double?

    /// Netto incassabile oggi dalle posizioni finanziarie: valore − penali − bollo maturato − imposte.
    var nettoFinanziario: Double { finanziarie.reduce(0) { $0 + $1.fisco.netto } }
    var imposteFinanziarie: Double { finanziarie.reduce(0) { $0 + $1.fisco.imposta } }
    var penaliFinanziarie: Double { finanziarie.reduce(0) { $0 + $1.fisco.penale + $1.fisco.bolloMaturato } }
    var costoGestione: Double { voci.reduce(0) { $0 + $1.fisco.costoGestione } }
    var costoTrattenuto: Double { voci.reduce(0) { $0 + $1.fisco.costoTrattenuto } }
    var costoBollo: Double { voci.reduce(0) { $0 + $1.fisco.costoBollo } }
    var previdenze: [VoceResoconto] { finanziarie.filter { $0.fisco.regime == .previdenza } }

    var finanziarie: [VoceResoconto] { voci.filter(\.finanziaria) }
    var coperture: [VoceResoconto] { voci.filter { $0.posizione.area == .protezione } }
    var debiti: [VoceResoconto] { voci.filter { $0.posizione.area.passivo } }
    var liquidita: Double { riepilogo.perArea[.liquidita] ?? 0 }
    var immobili: Double { riepilogo.perArea[.immobili] ?? 0 }
    /// Rate dei finanziamenti in un anno.
    var rateAnnue: Double { debiti.reduce(0) { $0 + $1.posizione.premioAnnuo } }
    /// Premi delle coperture in un anno.
    var premiCoperture: Double { coperture.reduce(0) { $0 + $1.posizione.premioAnnuo } }
    /// Versamenti periodici delle posizioni finanziarie in un anno.
    var versamentiAnnui: Double { finanziarie.reduce(0) { $0 + $1.posizione.premioAnnuo } }
    var canaliPresenti: [Canale] { canali.filter { $0.posizioni > 0 }.map(\.canale) }
    /// Le posizioni finanziarie che hanno lo storico di 12 mesi.
    var conStorico: [VoceResoconto] { finanziarie.filter { $0.variazione12 != nil } }
}

/// Calcoli del resoconto: tutto dai dati delle Posizioni, nessuna ipotesi sul futuro.
enum MotoreResoconto {
    static let mesiScadenze = 12

    static func calcola(_ posizioni: [Posizione], cliente: String, prodotti: [Prodotto] = [], data: Date = Date()) -> EsitoResoconto {
        let inEssere = posizioni.filter { $0.stato == .inEssere }
            .sorted { ($0.area.ordine, $0.canale.rawValue, $0.nome) < ($1.area.ordine, $1.canale.rawValue, $1.nome) }
        let voci = inEssere.map { p in voce(p, prodotto: p.prodottoId.flatMap { id in prodotti.first { $0.id == id } }, data: data) }
        let finanziarie = voci.filter(\.finanziaria)
        let riepilogo = RiepilogoPosizioni(posizioni.filter { $0.stato != .chiusa })

        let canali = Canale.allCases.map { c -> TotaleCanaleResoconto in
            let mie = voci.filter { $0.posizione.canale == c }
            let fin = mie.filter(\.finanziaria)
            return TotaleCanaleResoconto(canale: c, posizioni: mie.count,
                                         valore: mie.filter { !$0.posizione.area.passivo }.reduce(0) { $0 + $1.valore },
                                         versato: fin.reduce(0) { $0 + ($1.versato ?? 0) },
                                         valoreFinanziario: fin.reduce(0) { $0 + $1.valore },
                                         premiAnnui: mie.filter { !$0.posizione.area.passivo }.reduce(0) { $0 + $1.posizione.premioAnnuo },
                                         costoAnnuo: mie.reduce(0) { $0 + ($1.costoAnnuo ?? 0) })
        }
        let debiti = riepilogo.debiti
        let aree = AreaPosizione.allCases.sorted { $0.ordine < $1.ordine }.compactMap { a -> TotaleAreaResoconto? in
            let mie = voci.filter { $0.posizione.area == a }
            guard !mie.isEmpty else { return nil }
            let valore = mie.reduce(0) { $0 + $1.valore }
            let base = a.passivo ? debiti : riepilogo.attivita
            return TotaleAreaResoconto(area: a, posizioni: mie.count, valore: valore, quota: base > 0 ? valore / base : 0)
        }

        let limite = Calendar.current.date(byAdding: .month, value: mesiScadenze, to: data) ?? data
        let scadenze = inEssere.compactMap { p -> ScadenzaResoconto? in
            guard let s = p.scadenza, s <= limite else { return nil }
            let cosa: String
            switch p.area {
            case .debiti: cosa = "ultima rata del finanziamento"
            case .protezione: cosa = p.frequenza == .annuale ? "rinnovo della copertura" : "fine della copertura"
            default: cosa = "scadenza del contratto"
            }
            return ScadenzaResoconto(posizione: p, data: s, scaduta: s < Calendar.current.startOfDay(for: data), cosa: cosa)
        }
        .sorted { $0.data < $1.data }

        let proposte = posizioni.filter { $0.stato == .proposta && $0.esito != .accettata && $0.esito != .rifiutata }

        // Variazione dei 12 mesi complessiva (metodo di Dietz su tutte le posizioni con lo storico)
        var delta = 0.0, base = 0.0, conDelta = false
        for v in finanziarie {
            guard let d = variazione(v.posizione) else { continue }
            delta += d.delta
            base += d.base
            conDelta = true
        }
        let conCosto = voci.filter { $0.costoAnnuo != nil }
        let valoreConCosto = conCosto.reduce(0) { $0 + $1.valore }
        let costo = voci.reduce(0) { $0 + ($1.costoAnnuo ?? 0) }

        return EsitoResoconto(
            cliente: cliente, data: data, voci: voci, riepilogo: riepilogo, canali: canali, aree: aree,
            scadenze: scadenze, proposte: proposte,
            versato: finanziarie.reduce(0) { $0 + ($1.versato ?? 0) },
            valoreFinanziario: finanziarie.reduce(0) { $0 + $1.valore },
            rendimentoAnnuo: rendimento(finanziarie.compactMap(\.flussiDatati)),
            variazione12: conDelta ? delta : nil,
            variazione12Percento: conDelta && base > 0 ? delta / base * 100 : nil,
            costoAnnuo: costo,
            incidenzaCosti: valoreConCosto > 0 ? costo / valoreConCosto * 100 : nil,
            rendimentoNettoAnnuo: rendimento(finanziarie.compactMap { v in v.flussiDatati.map { $0.conValore(v.fisco.netto) } }))
    }

    static func voce(_ p: Posizione, prodotto: Prodotto? = nil, data: Date = Date()) -> VoceResoconto {
        let finanziaria = p.area.proiettabile
        let versato = finanziaria ? (p.totaleVersato ?? (p.versamentoIniziale > 0 ? p.versamentoIniziale : nil)) : nil
        let valore = p.area == .protezione ? (p.controvalore ?? 0) : p.valore
        let risultato = versato.map { valore - $0 }
        let v = finanziaria ? variazione(p) : nil
        let anni = p.decorrenza.map { max(0, (p.dataValore ?? data).timeIntervalSince($0) / (365.25 * 86_400)) }
        let fisco = MotoreFiscale.calcola(p, prodotto: prodotto, data: data)
        let datati = finanziaria ? flussiDatati(p, data: data) : nil
        let flussiNetti = datati.map { $0.conValore(fisco.netto) }
        return VoceResoconto(
            posizione: p, versato: versato, valore: valore, risultato: risultato,
            risultatoPercento: versato.flatMap { $0 > 0 ? (risultato ?? 0) / $0 * 100 : nil },
            rendimentoAnnuo: datati.flatMap { rendimento([$0]) },
            variazione12: v?.delta,
            variazione12Percento: v.flatMap { $0.base > 0 ? $0.delta / $0.base * 100 : nil },
            costoAnnuo: fisco.costoTotale > 0 ? fisco.costoTotale : nil,
            anni: anni, fisco: fisco,
            rendimentoNettoAnnuo: flussiNetti.flatMap { rendimento([$0]) },
            flussiDatati: datati)
    }

    // MARK: - Ultimi 12 mesi

    /// La rilevazione più vicina a 12 mesi prima del valore attuale (tra 9 e 15 mesi).
    static func rilevazione12(_ p: Posizione) -> Rilevazione? {
        guard let oggi = p.dataValore else { return nil }
        let giorno = 86_400.0
        return (p.rilevazioni ?? [])
            .filter { let d = oggi.timeIntervalSince($0.data) / giorno; return d >= 270 && d <= 460 }
            .min { abs(oggi.timeIntervalSince($0.data) / giorno - 365) < abs(oggi.timeIntervalSince($1.data) / giorno - 365) }
    }

    /// Guadagno degli ultimi 12 mesi al netto dei versamenti, e la base su cui misurarlo
    /// (valore di partenza più metà dei versamenti, come nel metodo di Dietz).
    static func variazione(_ p: Posizione) -> (delta: Double, base: Double)? {
        guard let prima = rilevazione12(p), let valore = p.controvalore else { return nil }
        let versatoOra = p.totaleVersato ?? prima.versato ?? 0
        let versamenti: Double
        if let versatoPrima = prima.versato {
            versamenti = max(0, versatoOra - versatoPrima)
        } else {
            // Senza il versato della rilevazione: i versamenti periodici del periodo trascorso,
            // perché non vengano contati come guadagno
            let giorni = (p.dataValore ?? Date()).timeIntervalSince(prima.data) / 86_400
            versamenti = p.premioAnnuo * max(0, giorni) / 365
        }
        return (valore - prima.controvalore - versamenti, prima.controvalore + versamenti / 2)
    }

    // MARK: - Rendimento annuo dei versamenti

    /// I flussi di una posizione: versamenti (mesi prima della data del valore, importo) e valore finale.
    struct Flussi {
        var versamenti: [(mesi: Double, importo: Double)]
        var valore: Double
    }

    /// I flussi datati di una posizione fino alla data del valore: versamenti (+) e incassi (−) del cliente,
    /// il valore finale e la sua data.
    struct FlussiDatati {
        var flussi: [(data: Date, importo: Double)]
        var valore: Double
        var fine: Date
        /// true se vengono dai movimenti reali indicati nella posizione, false se ricostruiti.
        var reali: Bool

        /// Gli stessi flussi con un altro valore finale (per esempio il netto incassabile oggi).
        func conValore(_ v: Double) -> FlussiDatati {
            var x = self
            x.valore = max(0, v)
            return x
        }
    }

    /// I flussi alle loro date. Con i movimenti reali (se c'è almeno un versamento sono l'elenco completo)
    /// si usano quelli. Altrimenti si ricostruiscono: il versamento iniziale alla decorrenza, i premi alle date
    /// della frequenza a partire dalla decorrenza, il versato in più rispetto ai premi alla decorrenza (o a metà
    /// del periodo tra due rilevazioni), il versato che scende tra due rilevazioni come riscatto parziale (stimato
    /// sul valore della rilevazione precedente, come nell'andamento); i soli incassi indicati nei movimenti si
    /// aggiungono. Nessun flusso se la posizione ha meno di un anno o mancano i dati.
    static func flussiDatati(_ p: Posizione, data: Date = Date()) -> FlussiDatati? {
        guard p.area.proiettabile, let valore = p.controvalore, valore > 0 else { return nil }
        let fine = p.dataValore ?? data
        let movimenti = (p.movimenti ?? []).filter { $0.importo.isFinite && $0.importo != 0 && $0.data <= fine }
            .sorted { $0.data < $1.data }
        guard let inizio = p.decorrenza ?? movimenti.first?.data else { return nil }
        let mesi = Calendar.current.dateComponents([.month], from: inizio, to: fine).month ?? 0
        guard mesi >= 12 else { return nil }
        if movimenti.contains(where: { $0.importo > 0 }) {
            return FlussiDatati(flussi: movimenti.map { (data: $0.data, importo: $0.importo) }, valore: valore, fine: fine, reali: true)
        }
        var elenco = versamentiRicostruiti(p, inizio: inizio, fine: fine, conRiscatti: movimenti.isEmpty)
        elenco += movimenti.map { (data: $0.data, importo: $0.importo) }
        guard elenco.contains(where: { $0.importo > 0 }) else { return nil }
        return FlussiDatati(flussi: elenco.sorted { $0.data < $1.data }, valore: valore, fine: fine, reali: false)
    }

    /// Versamenti ricostruiti periodo per periodo tra i valori noti del versato: la decorrenza (versamento
    /// iniziale), le rilevazioni con il versato e la data del valore (totale versato o, se manca, il
    /// versamento iniziale più i premi del calendario).
    static func versamentiRicostruiti(_ p: Posizione, inizio: Date, fine: Date, conRiscatti: Bool = true) -> [(data: Date, importo: Double)] {
        let cal = Calendar.current
        let iniziale = max(0, p.versamentoIniziale)
        // Calendario dei premi: dalla decorrenza, ogni 12 / volte all'anno mesi, prima della data del valore
        var calendario: [Date] = []
        let volte = p.frequenza.volteAllAnno
        if volte > 0, p.premio > 0 {
            let passo = 12 / volte
            var k = 0
            // Un premio che cade proprio alla data del valore non è ancora nel valore
            while k < 1_200, let d = cal.date(byAdding: .month, value: k * passo, to: inizio), d < fine {
                calendario.append(d)
                k += 1
            }
        }
        // Senza premi periodici il versato in più si distribuisce mese per mese (date sconosciute):
        // il calendario mensile si prepara solo se serve
        var mensile: [Date]? = nil
        func dateVersamenti() -> [Date] {
            if !calendario.isEmpty { return calendario }
            if let pronto = mensile { return pronto }
            var elenco: [Date] = []
            var k = 0
            while k < 1_200, let d = cal.date(byAdding: .month, value: k, to: inizio), d < fine {
                elenco.append(d)
                k += 1
            }
            mensile = elenco
            return elenco
        }
        let premio = calendario.isEmpty ? 0 : p.premio
        let versatoFinale = p.totaleVersato ?? (iniziale + Double(calendario.count) * p.premio)

        // I valori noti del versato: (data, versato, valore a quella data)
        var punti: [(data: Date, versato: Double, valore: Double)] = [(data: inizio, versato: iniziale, valore: iniziale)]
        for r in (p.rilevazioni ?? []).sorted(by: { $0.data < $1.data }) {
            guard let v = r.versato, r.data > inizio, r.data < fine, let ultimo = punti.last, r.data > ultimo.data else { continue }
            punti.append((data: r.data, versato: v, valore: r.controvalore))
        }
        punti.append((data: fine, versato: versatoFinale, valore: p.controvalore ?? versatoFinale))

        var elenco: [(data: Date, importo: Double)] = []
        if iniziale > 0 { elenco.append((data: inizio, importo: iniziale)) }
        for j in 1..<punti.count {
            let da = punti[j - 1], a = punti[j]
            let delta = a.versato - da.versato
            let centro = da.data.addingTimeInterval(a.data.timeIntervalSince(da.data) / 2)
            if delta > 0.5 {
                // Le date dei premi nel periodo: il primo periodo comprende la decorrenza
                let nel = dateVersamenti().filter { (j == 1 ? $0 >= da.data : $0 > da.data) && $0 <= a.data }
                if nel.isEmpty {
                    elenco.append((data: centro, importo: delta))
                } else if premio > 0 && delta >= Double(nel.count) * premio - 0.5 {
                    // Premi pieni; il versato in più (per esempio un trasferimento) alla decorrenza o a metà periodo
                    for d in nel { elenco.append((data: d, importo: premio)) }
                    let eccesso = delta - Double(nel.count) * premio
                    if eccesso > 0.5 { elenco.append((data: j == 1 ? inizio : centro, importo: eccesso)) }
                } else {
                    // Versato più basso dei premi del calendario: ripartito in parti uguali sulle date dei premi
                    for d in nel { elenco.append((data: d, importo: delta / Double(nel.count))) }
                }
            } else if delta < -0.5 && conRiscatti && da.versato > 0 {
                // Il versato scende: riscatto parziale della stessa quota del valore
                let uscita = -delta / da.versato * da.valore
                elenco.append((data: centro, importo: -uscita))
            }
        }
        return elenco
    }

    /// I flussi in mesi prima della data del valore (per `tir`), ricavati dai flussi datati.
    static func flussi(_ p: Posizione, data: Date = Date()) -> Flussi? {
        guard let f = flussiDatati(p, data: data) else { return nil }
        let elenco = f.flussi.map { x -> (mesi: Double, importo: Double) in
            (mesi: max(0, Rendimenti.giorni(da: x.data, a: f.fine)) / Rendimenti.giorniAnno * 12, importo: x.importo)
        }
        return Flussi(versamenti: elenco, valore: f.valore)
    }

    /// Il rendimento annuo (%) di una o più posizioni insieme sui flussi alle loro date (XIRR): i valori finali
    /// contano come incassi alla data di ciascun valore. Più posizioni danno il rendimento del patrimonio
    /// finanziario nel suo complesso.
    static func rendimento(_ elenco: [FlussiDatati]) -> Double? {
        guard let fine = elenco.map(\.fine).max() else { return nil }
        if elenco.count == 1, let x = elenco.first {
            return Rendimenti.xirr(x.flussi, valoreFinale: x.valore, al: x.fine)
        }
        var tutti: [(data: Date, importo: Double)] = elenco.flatMap { $0.flussi }
        for x in elenco where x.valore > 0 { tutti.append((data: x.fine, importo: -x.valore)) }
        return Rendimenti.xirr(tutti, valoreFinale: 0, al: fine)
    }

    /// Il tasso annuo che porta i versamenti al valore finale (bisezione). Più posizioni insieme danno
    /// il rendimento del patrimonio finanziario nel suo complesso.
    static func tir(_ elenco: [Flussi]) -> Double? {
        let finale = elenco.reduce(0) { $0 + $1.valore }
        let tutti = elenco.flatMap(\.versamenti)
        guard finale > 0, !tutti.isEmpty else { return nil }
        func eccesso(_ r: Double) -> Double {
            tutti.reduce(0) { $0 + $1.importo * pow(1 + r, $1.mesi / 12) } - finale
        }
        var basso = -0.9, alto = 1.0
        guard eccesso(basso) < 0, eccesso(alto) > 0 else { return nil }
        for _ in 0..<80 {
            let medio = (basso + alto) / 2
            if eccesso(medio) > 0 { alto = medio } else { basso = medio }
        }
        return (basso + alto) / 2 * 100
    }
}
