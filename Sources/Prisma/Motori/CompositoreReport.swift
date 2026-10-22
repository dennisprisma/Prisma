import Foundation

/// Compone i report da consegnare al cliente: poche cifre, scritte grandi, in parole semplici.
/// I capitoli riprendono le slide del template (Presentazioni): prima la persona, poi i numeri.
/// Le cifre vengono dagli stessi motori dei prospetti di dettaglio.
enum CompositoreReport {

    static let avvertenza = """
    Questo documento illustra la tua situazione e le ipotesi di cui abbiamo parlato. I rendimenti non sono garantiti \
    e le cifre future sono stime, non promesse. Prima di qualsiasi decisione leggi il KID e la documentazione del \
    prodotto, che fanno fede. Importi arrotondati all'euro.
    """

    /// Il nome del consulente, dall'etichetta del canale indipendente ("Denis Vicenzoni · Consulenza finanziaria").
    static var consulente: String {
        Canale.indipendente.nome.components(separatedBy: " · ").first ?? Canale.indipendente.nome
    }

    static func componi(_ scelta: SceltaProspetto, dati: DatiPrisma, cliente: String) -> ContenutoProspetto? {
        switch scelta {
        case .reportQuadro: return quadro(dati: dati, cliente: cliente)
        case .reportProposta(let id): return dati.posizioni.first { $0.id == id }.map { proposta($0, dati: dati) }
        default: return nil
        }
    }

    // MARK: - Il quadro del cliente

    static func quadro(dati: DatiPrisma, cliente id: String, oggi: Date = Date()) -> ContenutoProspetto? {
        guard let c = dati.clienti.first(where: { $0.id == id }) else { return nil }
        let posizioni = dati.posizioni.filter { $0.clienteId == id && $0.stato != .chiusa }
        let inEssere = posizioni.filter { $0.stato == .inEssere }
        let r = RiepilogoPosizioni(posizioni)
        let nome = primoNome(c)
        var b: [BloccoProspetto] = []

        // 01 La persona
        b.append(.capitolo(numero: "01", titolo: "Prima dei numeri, ci sei tu."))
        b.append(.paragrafo(c.tema.isEmpty
            ? "\(nome), in queste pagine trovi la tua situazione in poche cifre, i tuoi progetti e i prossimi passi che abbiamo concordato."
            : "\(c.tema) \(nome), in queste pagine trovi la tua situazione in poche cifre, i tuoi progetti e i prossimi passi che abbiamo concordato."))
        let analisi = dati.analisi[id] ?? Analisi360(cliente: c, posizioni: posizioni)
        let priorita = MotoreBisogni.priorita(MotoreBisogni.rileva(cliente: c, posizioni: posizioni, analisi: analisi), profilo: c.bisogni)
        if !priorita.isEmpty {
            b.append(.punti(priorita.prefix(3).map { "\($0.nome): \(fraseBisogno($0))" }))
        }

        // 02 Il punto di partenza
        b.append(.capitolo(numero: "02", titolo: "Il punto da cui partiamo."))
        let risparmi = inEssere.filter { [.investimento, .risparmio, .previdenza, .liquidita].contains($0.area) }.reduce(0) { $0 + $1.valore }
        var cifre = [
            IndicatoreProspetto(etichetta: "Il tuo patrimonio netto", valore: euro(r.patrimonioNetto), nota: r.debiti > 0 ? "debiti già sottratti" : ""),
            IndicatoreProspetto(etichetta: "Risparmi e investimenti", valore: euro(risparmi), nota: "liquidità compresa"),
        ]
        if r.capitaleAssicurato > 0 {
            cifre.append(IndicatoreProspetto(etichetta: "Tutele in essere", valore: euro(r.capitaleAssicurato), nota: "capitali assicurati"))
        }
        if r.premiAnnui > 0 {
            cifre.append(IndicatoreProspetto(etichetta: "Versi ogni anno", valore: euro(r.premiAnnui), nota: "premi e piani di accumulo"))
        }
        b.append(.cifre(cifre))
        let aree = AreaPosizione.allCases.filter { !$0.passivo && ($0 != .protezione) }
            .compactMap { a -> BarraProspetto? in
                let v = r.perArea[a] ?? 0
                guard v > 0, r.attivita > 0 else { return nil }
                return BarraProspetto(etichetta: a.nome, valore: "\(euro(v)) · \(percentuale(v / r.attivita))", quota: v / r.attivita)
            }
            .sorted { $0.quota > $1.quota }
        if !aree.isEmpty {
            b.append(.paragrafo("Come sono distribuiti i tuoi beni:"))
            b.append(.barre(aree))
        }
        let tutele = r.perRischio.filter { $0.value > 0 }.sorted { $0.value > $1.value }
            .map { "\($0.key.nome): \(euro($0.value))" }
        if !tutele.isEmpty {
            b.append(.paragrafo("Le tue tutele oggi:"))
            b.append(.punti(tutele))
        }

        // 03 I progetti
        let obiettivi = dati.obiettivi.filter { $0.clienteId == id }.sorted { $0.scadenza < $1.scadenza }
        var n = 2
        if !obiettivi.isEmpty {
            n += 1
            b.append(.capitolo(numero: String(format: "%02d", n), titolo: "Un nome ai tuoi progetti."))
            b.append(.barre(obiettivi.map { o in
                let av = AvanzamentoObiettivo(o, posizioni: dati.posizioni)
                let manca = av.mancante <= 0 ? "obiettivo raggiunto"
                    : av.versamentoNecessario.map { "per arrivarci servono circa \(euro($0)) al mese" } ?? "la data è passata: rivediamola"
                return BarraProspetto(etichetta: o.titolo, valore: "\(euro(av.accantonato)) su \(euro(o.importo))", quota: av.quota,
                                      nota: "entro \(Formati.meseAnno.string(from: o.scadenza)) · \(manca)")
            }))
        }

        // 04 L'incontro e i prossimi passi
        let prossimo = dati.appuntamenti.filter { $0.clienteId == id && $0.stato == .pianificato && $0.inizio >= oggi }
            .min { $0.inizio < $1.inizio }
        if let a = prossimo {
            n += 1
            b.append(.capitolo(numero: String(format: "%02d", n), titolo: "Il tempo per incontrarsi."))
            b.append(.paragrafo("Ci vediamo \(Formati.dataLunga.string(from: a.inizio)) alle \(Formati.ora.string(from: a.inizio))"
                                + (a.luogo.isEmpty ? "" : ", \(a.luogo.lowercased())") + ": \(a.titolo.lowercased())."))
        }
        var passi = dati.attivita.filter { $0.clienteId == id && !$0.completata }.sorted { $0.scadenza < $1.scadenza }
            .prefix(4).map { $0.titolo }
        passi += posizioni.filter { $0.stato == .proposta && $0.esito != .rifiutata && $0.esito != .accettata }
            .map { "Valutare insieme la proposta «\($0.nome)»" }
        if !passi.isEmpty {
            n += 1
            b.append(.capitolo(numero: String(format: "%02d", n), titolo: "Il prossimo passo, insieme."))
            b.append(.punti(Array(passi.prefix(6))))
        }

        b.append(.firma(nome: consulente, canali: canali(inEssere + posizioni)))
        b.append(.nota(avvertenza))

        return ContenutoProspetto(occhiello: "Il tuo quadro", titolo: "Il percorso di \(nome)",
                                  sottotitolo: "Persone, priorità, prospettive",
                                  cliente: c.nome, perCliente: true, blocchi: b)
    }

    // MARK: - Una proposta

    static func proposta(_ p: Posizione, dati: DatiPrisma) -> ContenutoProspetto {
        let c = dati.clienti.first { $0.id == p.clienteId }
        let nome = c.map(primoNome) ?? ""
        let par = ParametriProiezione(posizione: p, orizzonteCliente: c?.profilo.orizzonteAnni)
        var b: [BloccoProspetto] = []
        var n = 0
        func capitolo(_ t: String) {
            n += 1
            b.append(.capitolo(numero: String(format: "%02d", n), titolo: t))
        }

        // Che cos'è e a che cosa serve
        capitolo("Che cos'è e a che cosa serve.")
        let cosa = [p.tipologia.isEmpty ? nil : p.tipologia, p.emittente.isEmpty ? nil : "di \(p.emittente)"]
            .compactMap { $0 }.joined(separator: " ")
        b.append(.paragrafo("\(nome.isEmpty ? "Ti" : "\(nome), ti") propongo «\(p.nome)»" + (cosa.isEmpty ? "." : ": \(cosa).")
                            + " " + fraseArea(p.area)))
        let obiettivi = dati.obiettivi.filter { $0.posizioniCollegate.contains(p.id) }.map(\.titolo)
        if !obiettivi.isEmpty {
            b.append(.punti(obiettivi.map { "Lavora per il tuo progetto: \($0)" }))
        }

        if p.area.proiettabile {
            let s = MotoreProiezione.scenari(par)
            capitolo("Quanto versi.")
            var versi: [IndicatoreProspetto] = []
            if p.versamentoIniziale > 0 { versi.append(IndicatoreProspetto(etichetta: "Per iniziare", valore: euro(p.versamentoIniziale))) }
            if p.premio > 0 && p.frequenza != .unica {
                versi.append(IndicatoreProspetto(etichetta: "Ogni \(periodo(p.frequenza))", valore: euro(p.premio), nota: "\(euro(p.premioAnnuo)) all'anno"))
            }
            versi.append(IndicatoreProspetto(etichetta: "Per", valore: "\(par.anni) \(par.anni == 1 ? "anno" : "anni")",
                                             nota: p.scadenza.map { "fino al \(Formati.meseAnno.string(from: $0))" } ?? ""))
            versi.append(IndicatoreProspetto(etichetta: "In tutto", valore: euro(s[1].esito.versato)))
            b.append(.cifre(versi))

            capitolo("Che cosa può diventare.")
            b.append(.paragrafo("Nessuno conosce il futuro: per questo guardiamo tre strade. Le cifre sono al netto di costi e imposte."))
            b.append(.cifre([
                IndicatoreProspetto(etichetta: "Se va peggio del previsto", valore: euro(s[0].esito.netto), nota: "rendimento \(percentuale(s[0].rendimento / 100)) l'anno"),
                IndicatoreProspetto(etichetta: "Se va come previsto", valore: euro(s[1].esito.netto), nota: "rendimento \(percentuale(s[1].rendimento / 100)) l'anno"),
                IndicatoreProspetto(etichetta: "Se va meglio del previsto", valore: euro(s[2].esito.netto), nota: "rendimento \(percentuale(s[2].rendimento / 100)) l'anno"),
            ]))
            b.append(.grafico([
                SerieGraficoProspetto(nome: "Peggio", tono: .prudente, punti: s[0].esito.punti),
                SerieGraficoProspetto(nome: "Come previsto", tono: .atteso, punti: s[1].esito.punti),
                SerieGraficoProspetto(nome: "Meglio", tono: .favorevole, punti: s[2].esito.punti),
            ]))
            b.append(.paragrafo("Con l'inflazione al \(percentuale(par.inflazione / 100)), i \(euro(s[1].esito.netto)) dello scenario previsto valgono come \(euro(s[1].esito.reale)) di oggi."))

            capitolo("Quanto costa.")
            var costi: [String] = []
            if let i = p.costoIngresso, i > 0 { costi.append("Su ogni versamento si paga il \(percentuale(i / 100)) all'ingresso.") }
            if let a = p.costoAnnuo, a > 0 { costi.append("Ogni anno la gestione costa il \(percentuale(a / 100)) di quanto hai accumulato.") }
            costi.append("In \(par.anni) anni, nello scenario previsto, i costi sommano circa \(euro(s[1].esito.costi)).")
            if s[1].esito.imposte > 0 { costi.append("Le imposte sul guadagno, alla fine, sono circa \(euro(s[1].esito.imposte)).") }
            b.append(.punti(costi))
        } else if p.area == .protezione {
            capitolo("Che cosa ti protegge.")
            var cifre = [IndicatoreProspetto(etichetta: "Capitale assicurato", valore: euro(p.capitaleAssicurato ?? 0), nota: (p.rischio ?? .altro).nome)]
            cifre.append(IndicatoreProspetto(etichetta: "Premio all'anno", valore: euro(p.premioAnnuo)))
            if let m = CompositoreProspetti.costoPerMille(p) {
                cifre.append(IndicatoreProspetto(etichetta: "Ogni 1.000 € assicurati", valore: Formati.euroDecimali(m), nota: "all'anno"))
            }
            b.append(.cifre(cifre))
        }

        if let sri = p.sri {
            capitolo("Quanto rischio.")
            b.append(.rischio(sri))
            b.append(.paragrafo(fraseRischio(sri)))
        }
        if !p.garanzie.isEmpty {
            b.append(.paragrafo("Garanzie: \(p.garanzie)"))
        }

        capitolo("Il prossimo passo, insieme.")
        var passi = ["Leggiamo insieme il KID e la documentazione del prodotto: lì trovi tutte le condizioni."]
        if let a = dati.appuntamenti.filter({ $0.clienteId == p.clienteId && $0.stato == .pianificato && $0.inizio >= Date() }).min(by: { $0.inizio < $1.inizio }) {
            passi.append("Ne parliamo \(Formati.dataLunga.string(from: a.inizio)) alle \(Formati.ora.string(from: a.inizio)).")
        }
        passi.append("Decidi con calma: puoi cambiare importi e durata prima di firmare.")
        b.append(.punti(passi))

        b.append(.firma(nome: consulente, canali: [p.canale]))
        b.append(.nota(avvertenza))

        return ContenutoProspetto(occhiello: "La proposta", titolo: p.nome,
                                  sottotitolo: [p.area.nome, p.tipologia].filter { !$0.isEmpty }.joined(separator: " · "),
                                  cliente: c?.nome ?? "", canale: p.canale, perCliente: true, blocchi: b)
    }

    // MARK: - Parole

    static func fraseArea(_ a: AreaPosizione) -> String {
        switch a {
        case .previdenza: return "Serve a costruire, un po' alla volta, una pensione che si aggiunga a quella pubblica."
        case .investimento: return "Serve a far lavorare i risparmi nel tempo, accettando alti e bassi lungo la strada."
        case .risparmio: return "Serve a mettere da parte con regolarità, proteggendo quanto accumuli."
        case .protezione: return "Serve a proteggere te e chi ti sta vicino dagli imprevisti."
        case .liquidita: return "Serve ad avere denaro disponibile quando serve."
        case .immobili, .debiti: return ""
        }
    }

    static func fraseBisogno(_ a: AreaBisogno) -> String {
        switch a {
        case .casa: return "la casa, oggi e domani."
        case .famiglia: return "le persone che dipendono da te e i loro progetti."
        case .lavoro: return "il tuo reddito e il tuo lavoro."
        case .pensione: return "il tenore di vita quando smetterai di lavorare."
        case .salute: return "gli imprevisti e la salute."
        case .patrimonio: return "ciò che hai costruito e come passarlo."
        }
    }

    static func fraseRischio(_ sri: Int) -> String {
        switch sri {
        case ...2: return "Classe \(sri) su 7: rischio basso. Il valore oscilla poco, e anche il rendimento atteso è contenuto."
        case 3...4: return "Classe \(sri) su 7: rischio medio. Nel tempo ci saranno momenti di calo: conta restare fino alla fine del periodo consigliato."
        default: return "Classe \(sri) su 7: rischio alto. Il valore può scendere molto nei momenti difficili: è adatto a chi ha tempo e non avrà bisogno di questi soldi a breve."
        }
    }

    private static func periodo(_ f: Frequenza) -> String {
        switch f {
        case .mensile: return "mese"
        case .trimestrale: return "trimestre"
        case .semestrale: return "semestre"
        case .annuale, .unica: return "anno"
        }
    }

    private static func primoNome(_ c: Cliente) -> String {
        c.nome.components(separatedBy: " ").first ?? c.nome
    }

    private static func canali(_ p: [Posizione]) -> [Canale] {
        Canale.allCases.filter { c in p.contains { $0.canale == c } }
    }

    private static func euro(_ v: Double) -> String { Formati.euro(v) }
    /// Quota 0–1 come percentuale arrotondata ("62%"), oppure con un decimale sotto il 10%.
    private static func percentuale(_ q: Double) -> String {
        let v = q * 100
        return Formati.percentuale(v < 10 ? (v * 10).rounded() / 10 : v.rounded())
    }
}
