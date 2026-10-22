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
    /// Rendimento medio annuo dei versamenti (tasso interno), se la posizione ha almeno un anno.
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
            rendimentoAnnuo: tir(finanziarie.compactMap { flussi($0.posizione, data: data) }),
            variazione12: conDelta ? delta : nil,
            variazione12Percento: conDelta && base > 0 ? delta / base * 100 : nil,
            costoAnnuo: costo,
            incidenzaCosti: valoreConCosto > 0 ? costo / valoreConCosto * 100 : nil,
            rendimentoNettoAnnuo: tir(finanziarie.compactMap { v in flussi(v.posizione, data: data).map { Flussi(versamenti: $0.versamenti, valore: v.fisco.netto) } }))
    }

    static func voce(_ p: Posizione, prodotto: Prodotto? = nil, data: Date = Date()) -> VoceResoconto {
        let finanziaria = p.area.proiettabile
        let versato = finanziaria ? (p.totaleVersato ?? (p.versamentoIniziale > 0 ? p.versamentoIniziale : nil)) : nil
        let valore = p.area == .protezione ? (p.controvalore ?? 0) : p.valore
        let risultato = versato.map { valore - $0 }
        let v = finanziaria ? variazione(p) : nil
        let anni = p.decorrenza.map { max(0, (p.dataValore ?? data).timeIntervalSince($0) / (365.25 * 86_400)) }
        let fisco = MotoreFiscale.calcola(p, prodotto: prodotto, data: data)
        let flussiNetti = finanziaria ? flussi(p, data: data).map { Flussi(versamenti: $0.versamenti, valore: fisco.netto) } : nil
        return VoceResoconto(
            posizione: p, versato: versato, valore: valore, risultato: risultato,
            risultatoPercento: versato.flatMap { $0 > 0 ? (risultato ?? 0) / $0 * 100 : nil },
            rendimentoAnnuo: finanziaria ? flussi(p, data: data).flatMap { tir([$0]) } : nil,
            variazione12: v?.delta,
            variazione12Percento: v.flatMap { $0.base > 0 ? $0.delta / $0.base * 100 : nil },
            costoAnnuo: fisco.costoTotale > 0 ? fisco.costoTotale : nil,
            anni: anni, fisco: fisco,
            rendimentoNettoAnnuo: flussiNetti.flatMap { tir([$0]) })
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
        let versamenti = max(0, versatoOra - (prima.versato ?? versatoOra))
        return (valore - prima.controvalore - versamenti, prima.controvalore + versamenti / 2)
    }

    // MARK: - Rendimento annuo dei versamenti

    /// I flussi di una posizione: versamenti (mesi prima della data del valore, importo) e valore finale.
    struct Flussi {
        var versamenti: [(mesi: Double, importo: Double)]
        var valore: Double
    }

    /// Il versamento iniziale alla decorrenza e il resto del versato distribuito mese per mese fino alla
    /// data del valore. Nessun flusso se la posizione ha meno di un anno o mancano i dati.
    static func flussi(_ p: Posizione, data: Date = Date()) -> Flussi? {
        guard p.area.proiettabile, let inizio = p.decorrenza, let valore = p.controvalore, valore > 0 else { return nil }
        let fine = p.dataValore ?? data
        let mesi = Double(Calendar.current.dateComponents([.month], from: inizio, to: fine).month ?? 0)
        guard mesi >= 12 else { return nil }
        let versato = p.totaleVersato ?? p.versamentoIniziale
        guard versato > 0 else { return nil }
        var elenco: [(mesi: Double, importo: Double)] = []
        let iniziale = min(p.versamentoIniziale, versato)
        if iniziale > 0 { elenco.append((mesi, iniziale)) }
        let resto = versato - iniziale
        if resto > 0.5 {
            let n = Int(mesi)
            for i in 0..<n { elenco.append((mesi - Double(i), resto / Double(n))) }
        }
        return Flussi(versamenti: elenco, valore: valore)
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
