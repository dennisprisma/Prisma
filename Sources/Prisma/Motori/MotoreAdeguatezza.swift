import Foundation

// Scheda di adeguatezza della proposta (giro 4, specifica 1). Motore puro: solo Foundation, nessuno stato,
// nessun `Date()` per le regole (la data arriva da fuori), non legge StatoShell. Raccoglie in un posto i
// controlli che Prisma fa già nel dossier: rischio, orizzonte, esperienza, bisogno, liquidità,
// concentrazione e sostituzione. I testi stanno in `TestiAdeguatezza`.

// MARK: - Tipi

/// Tutto ciò che serve per la scheda di una proposta, già raccolto da StatoShell.
struct IngressoAdeguatezza {
    let proposta: Posizione
    let cliente: Cliente
    /// Tutte le posizioni del cliente (la proposta, se c'è, viene tolta dal motore).
    let posizioni: [Posizione]
    let prodotti: [Prodotto]
    /// Obiettivi del cliente.
    let obiettivi: [Obiettivo]
    /// Bisogni rilevati da `MotoreBisogni.rileva` (con l'Analisi 360 del cliente).
    let bisogni: [BisognoRilevato]
    /// Ipotesi di protezione dell'Analisi 360 (fabbisogno mensile e mesi di riserva).
    let protezione: IpotesiProtezione
    /// true se l'Analisi 360 è salvata e l'area protezione è confermata.
    let ipotesiConfermate: Bool
    let scheda: SchedaAdeguatezza?
    /// `impostazioni.consegna.voci`.
    let voci: [VoceDocumento]
    let oggi: Date
}

/// Un controllo della scheda.
struct ControlloAdeguatezza: Identifiable {
    enum Tipo: String, CaseIterable {
        case rischio, orizzonte, esperienza, bisogno, liquidita, concentrazione, sostituzione
    }

    let tipo: Tipo
    let semaforo: Semaforo
    /// Una frase: cosa risulta.
    let esito: String
    /// Righe in più (motivi, cifre, note).
    let dettagli: [String]
    /// Riferimento normativo breve e soglie (aiuto della riga e colonna del PDF).
    let fonte: String
    /// true se il controllo usa un dato stimato (SRI, periodo, ipotesi della riserva).
    let stimato: Bool
    /// Il valore misurato e la soglia, quando ci sono (per le prove e i KPI).
    let valore: Double?
    let soglia: Double?
    var id: String { tipo.rawValue }

    init(tipo: Tipo, semaforo: Semaforo, esito: String, dettagli: [String] = [], fonte: String,
         stimato: Bool = false, valore: Double? = nil, soglia: Double? = nil) {
        self.tipo = tipo
        self.semaforo = semaforo
        self.esito = esito
        self.dettagli = dettagli
        self.fonte = fonte
        self.stimato = stimato
        self.valore = valore
        self.soglia = soglia
    }
}

/// Un controllo che per questa proposta non serve, con il motivo (riga in fondo al pannello e al PDF).
struct ControlloEscluso: Identifiable {
    let tipo: ControlloAdeguatezza.Tipo
    let motivo: String
    var id: String { tipo.rawValue }
}

/// Un documento dell'elenco per questa proposta.
struct DocumentoDaConsegnare: Identifiable {
    let voce: VoceDocumento
    let consegnatoIl: Date?
    let nonPertinente: Bool
    var id: String { voce.id }
    var fatto: Bool { consegnatoIl != nil || nonPertinente }
}

/// Le cifre del confronto con la posizione sostituita (per il pannello e il PDF).
struct UscitaSostituzione {
    let sostituita: Posizione
    /// Penale + bollo maturato + costo d'ingresso del nuovo prodotto (le imposte anticipate a parte).
    let costi: Double
    let percentuale: Double
    let imposteAnticipate: Double
    let garanziePerse: [String]
    let pareggio: Int?
    let anni: Int
    let trasferimento: Bool
    let riscattoPrevidenza: Bool
}

struct EsitoAdeguatezza {
    let proposta: Posizione
    let tipoProdotto: TipoProdotto?
    /// Nell'ordine di `ControlloAdeguatezza.Tipo.allCases`, solo quelli pertinenti.
    let controlli: [ControlloAdeguatezza]
    let esclusi: [ControlloEscluso]
    let complessivo: Semaforo
    let documenti: [DocumentoDaConsegnare]
    /// Il collegamento usato (della scheda o suggerito) e se è solo un suggerimento.
    let collegamento: CollegamentoBisogno?
    let collegamentoSuggerito: Bool
    /// La posizione in essere che Prisma suggerisce come sostituita (nil se la scheda ne ha già una o non ce n'è).
    let sostituitaSuggerita: String?
    /// Da dove arriva il versamento iniziale: quella della scheda o la regola predefinita.
    let fonte: FonteCapitale?
    let uscita: UscitaSostituzione?
    /// Liquidità di oggi e quella che resta dopo il versamento (nil senza conti).
    let liquiditaOggi: Double?
    let liquiditaResta: Double?
    /// La posizione in essere che la proposta sostituisce (anche per le coperture, che non hanno `uscita`).
    var sostituita: Posizione? = nil

    var consegnati: Int { documenti.filter { $0.consegnatoIl != nil }.count }
    var daConsegnare: Int { documenti.filter { !$0.nonPertinente }.count }
    var documentiCompleti: Bool { documenti.allSatisfy(\.fatto) }
    /// Pronta per la firma: nessun rosso, nessun grigio, tutti i documenti spuntati o non pertinenti.
    var pronta: Bool { complessivo != .rosso && complessivo != .grigio && documentiCompleti }
    func controllo(_ t: ControlloAdeguatezza.Tipo) -> ControlloAdeguatezza? { controlli.first { $0.tipo == t } }
    /// Quanti controlli per colore (per la frase «4 coerenti, 1 da motivare»).
    func conta(_ s: Semaforo) -> Int { controlli.filter { $0.semaforo == s }.count }
}

/// Una scheda incompleta, per il centro notifiche.
struct SchedaDaCompletare {
    enum Motivo: Equatable { case firma, documenti(mancano: Int) }
    let posizione: Posizione
    let motivo: Motivo
}

// MARK: - Motore

enum MotoreAdeguatezza {
    // Soglie di Prisma (non della norma), dichiarate nel metodo e nelle fonti
    /// Sotto la metà della riserva di emergenza la liquidità è rossa.
    static let sogliaRiservaMinima = 0.5
    /// Gli obiettivi che contano per la liquidità: quelli entro 24 mesi.
    static let mesiObiettiviVicini = 24
    /// Versamenti periodici della proposta sul reddito netto annuo: oltre il 20% giallo, oltre il 35% rosso.
    static let premioAttenzione = 20.0
    static let premioEccessivo = 35.0
    /// Oltre il 75% presso un emittente, se la proposta aggiunge almeno 5 punti, è rosso (oltre il 50% giallo:
    /// `MotoreCoerenza.sogliaEmittente`).
    static let sogliaEmittenteAlta = 75.0
    static let aumentoRilevante = 5.0
    /// Costi dell'uscita (penale, bollo maturato, ingresso nel nuovo) sul valore di oggi: oltre l'1% giallo,
    /// oltre il 3% rosso.
    static let uscitaAttenzione = 1.0
    static let uscitaEccessiva = 3.0
    /// Anni di partecipazione minimi alla prestazione pensionistica complementare (D.Lgs. 252/2005, art. 11, c. 2).
    static let anniMinimiPrevidenza = 5
    /// Imposte anticipate sotto questa cifra non si scrivono (arrotondamenti).
    static let impostaMinima = 0.5
    /// Penali di riscatto lette dal 2° all'11° anno di contratto.
    static let anniPenali = 2...11

    private static let calendario = Calendar(identifier: .gregorian)

    /// I dati comuni ai sette controlli, raccolti una volta sola.
    struct Contesto {
        let i: IngressoAdeguatezza
        let p: Posizione
        /// Le posizioni del cliente senza la proposta, e quelle in essere.
        let altre: [Posizione]
        let inEssere: [Posizione]
        let prodotto: Prodotto?
        let tipo: TipoProdotto?
        /// Una copertura: niente rischio d'investimento, orizzonte né concentrazione.
        let protezione: Bool
        let previdenza: Bool
        let sostituita: Posizione?
        /// La fonte effettiva del versamento iniziale.
        let fonte: FonteCapitale
        /// true se la scheda dice «sostituzione» ma la sostituita manca: si conta dalla liquidità.
        let fonteRipiegata: Bool
        /// Età del cliente alla data `oggi` (anni interi).
        let eta: Int?
    }

    static func contesto(_ i: IngressoAdeguatezza) -> Contesto {
        let p = i.proposta
        let altre = i.posizioni.filter { $0.id != p.id }
        let inEssere = altre.filter { $0.stato == .inEssere }
        let prodotto = p.prodottoId.flatMap { id in i.prodotti.first { $0.id == id } }
        let tipo = MotoreEsperienza.classifica(p, prodotti: i.prodotti)?.tipo
        let sostituita = i.scheda?.posizioneSostituitaId.flatMap { id in inEssere.first { $0.id == id } }
        var fonte: FonteCapitale = i.scheda?.fonte ?? (sostituita != nil ? .sostituzione : .liquidita)
        var ripiegata = false
        if fonte == .sostituzione && sostituita == nil {
            fonte = .liquidita
            ripiegata = true
        }
        let eta = i.cliente.dataNascita.flatMap { calendario.dateComponents([.year], from: $0, to: i.oggi).year }
        return Contesto(i: i, p: p, altre: altre, inEssere: inEssere, prodotto: prodotto, tipo: tipo,
                        protezione: tipo == .protezione || p.area == .protezione,
                        previdenza: tipo == .previdenza || p.area == .previdenza,
                        sostituita: sostituita, fonte: fonte, fonteRipiegata: ripiegata, eta: eta)
    }

    /// true se la posizione può avere una scheda: proposta non rifiutata, una posizione accettata con la sua
    /// scheda (la firma da segnare) o una scheda firmata; mai liquidità, immobili e debiti.
    static func pertinente(_ p: Posizione, scheda: SchedaAdeguatezza?) -> Bool {
        guard p.area != .liquidita, p.area != .immobili, p.area != .debiti else { return false }
        if scheda?.firmata == true { return true }
        switch p.stato {
        case .proposta: return p.esito != .rifiutata
        case .inEssere: return scheda != nil
        case .chiusa: return false
        }
    }

    // MARK: - Calcolo

    static func calcola(_ i: IngressoAdeguatezza) -> EsitoAdeguatezza {
        let k = contesto(i)
        var controlli: [ControlloAdeguatezza] = []
        var esclusi: [ControlloEscluso] = []

        if let c = controlloRischio(k) { controlli.append(c) } else {
            esclusi.append(ControlloEscluso(tipo: .rischio, motivo: TestiAdeguatezza.esclusoRischio))
        }
        if let c = controlloOrizzonte(k) { controlli.append(c) } else {
            esclusi.append(ControlloEscluso(tipo: .orizzonte, motivo: TestiAdeguatezza.esclusoOrizzonte))
        }
        if let c = controlloEsperienza(k) { controlli.append(c) } else {
            esclusi.append(ControlloEscluso(tipo: .esperienza, motivo: TestiAdeguatezza.esclusoEsperienza))
        }
        let b = controlloBisogno(k)
        controlli.append(b.controllo)
        let l = controlloLiquidita(k)
        controlli.append(l.controllo)
        if let c = controlloConcentrazione(k) { controlli.append(c) } else {
            esclusi.append(ControlloEscluso(tipo: .concentrazione, motivo: TestiAdeguatezza.esclusoConcentrazione))
        }
        var uscita: UscitaSostituzione?
        if let s = controlloSostituzione(k) {
            controlli.append(s.controllo)
            uscita = s.uscita
        } else {
            esclusi.append(ControlloEscluso(tipo: .sostituzione, motivo: TestiAdeguatezza.esclusoSostituzione))
        }

        let voci = documenti(k.p, voci: i.voci, tipo: k.tipo, sostituzione: k.sostituita != nil)
        let elenco = voci.map { v in
            DocumentoDaConsegnare(voce: v, consegnatoIl: i.scheda?.consegnato(v.id),
                                  nonPertinente: i.scheda?.nonPertinenti.contains(v.id) ?? false)
        }
        let suggerita: String? = i.scheda?.posizioneSostituitaId != nil ? nil
            : sostituitaSuggerita(k.p, posizioni: k.altre, oggi: i.oggi)

        var esito = EsitoAdeguatezza(proposta: k.p, tipoProdotto: k.tipo, controlli: controlli, esclusi: esclusi,
                                     complessivo: complessivo(controlli.map(\.semaforo)), documenti: elenco,
                                     collegamento: b.collegamento, collegamentoSuggerito: b.suggerito,
                                     sostituitaSuggerita: suggerita, fonte: k.fonte, uscita: uscita,
                                     liquiditaOggi: l.oggi, liquiditaResta: l.resta)
        esito.sostituita = k.sostituita
        return esito
    }

    // Un controllo per funzione: nil = non pertinente (il motivo va in `esclusi`)

    static func rischio(_ i: IngressoAdeguatezza) -> ControlloAdeguatezza? { controlloRischio(contesto(i)) }
    static func orizzonte(_ i: IngressoAdeguatezza) -> ControlloAdeguatezza? { controlloOrizzonte(contesto(i)) }
    static func esperienza(_ i: IngressoAdeguatezza) -> ControlloAdeguatezza? { controlloEsperienza(contesto(i)) }
    static func bisogno(_ i: IngressoAdeguatezza) -> (controllo: ControlloAdeguatezza, collegamento: CollegamentoBisogno?, suggerito: Bool) {
        controlloBisogno(contesto(i))
    }
    static func liquidita(_ i: IngressoAdeguatezza) -> ControlloAdeguatezza { controlloLiquidita(contesto(i)).controllo }
    static func concentrazione(_ i: IngressoAdeguatezza) -> ControlloAdeguatezza? { controlloConcentrazione(contesto(i)) }
    static func sostituzione(_ i: IngressoAdeguatezza) -> (ControlloAdeguatezza, UscitaSostituzione?)? {
        controlloSostituzione(contesto(i)).map { ($0.controllo, $0.uscita) }
    }

    // MARK: - 1 · Rischio (SRI) e profilo

    private static func controlloRischio(_ k: Contesto) -> ControlloAdeguatezza? {
        guard !k.protezione else { return nil }
        let p = k.p
        let fonte = TestiAdeguatezza.fonte(.rischio, ambito: k.tipo?.ambito)
        guard let pr = k.i.cliente.profilo.propensione else {
            // R1
            return ControlloAdeguatezza(tipo: .rischio, semaforo: .grigio, esito: TestiAdeguatezza.rischioSenzaProfilo, fonte: fonte)
        }
        let massimo = MotoreCoerenza.sriMassimo(pr)
        var dettagli: [String] = []
        if p.multiramoDivisa { dettagli.append(TestiAdeguatezza.rischioMultiramo(p.sriParteFondi)) }
        let indicato: Int? = p.multiramoDivisa ? p.sriComposto : (p.sri ?? k.prodotto?.sri)
        if let grezzo = indicato {
            // R2 e R3: la stessa regola di MotoreCoerenza.calcola
            let s = min(max(grezzo, 1), 7)
            let entro = s <= massimo
            return ControlloAdeguatezza(tipo: .rischio, semaforo: entro ? .verde : .rosso,
                                        esito: TestiAdeguatezza.rischio(s, massimo: massimo, propensione: pr, entro: entro),
                                        dettagli: dettagli, fonte: fonte, valore: Double(s), soglia: Double(massimo))
        }
        // R4: SRI non indicato, stimato dall'area e dalla composizione
        let s = MotoreCoerenza.sriStimato(p)
        return ControlloAdeguatezza(tipo: .rischio, semaforo: .giallo, esito: TestiAdeguatezza.rischioStimato(s),
                                    dettagli: dettagli, fonte: fonte, stimato: true, valore: Double(s), soglia: Double(massimo))
    }

    // MARK: - 2 · Periodo raccomandato e orizzonte

    private static func controlloOrizzonte(_ k: Contesto) -> ControlloAdeguatezza? {
        guard !k.protezione else { return nil }
        let p = k.p
        let profilo = k.i.cliente.profilo
        if k.previdenza {
            let fonte = TestiAdeguatezza.fonte(.orizzonte, ambito: .previdenza)
            guard let eta = k.eta else {
                return ControlloAdeguatezza(tipo: .orizzonte, semaforo: .grigio, esito: TestiAdeguatezza.previdenzaSenzaEta, fonte: fonte)
            }
            let pensione = profilo.lavoro?.etaPensione ?? IpotesiPrevidenza().etaPensione
            let anniPensione = max(0, pensione - eta)
            // Gli anni già maturati nelle forme aperte contano per i cinque anni di partecipazione
            let maturati = k.inEssere
                .filter { $0.area == .previdenza || $0.regime == .previdenza }
                .map { MotoreFiscale.anniPartecipazione($0, data: k.i.oggi) }
                .max() ?? 0
            let partecipazione = maturati + anniPensione
            let ok = partecipazione >= anniMinimiPrevidenza
            return ControlloAdeguatezza(tipo: .orizzonte, semaforo: ok ? .verde : .giallo,
                                        esito: TestiAdeguatezza.previdenza(anniPensione: anniPensione, partecipazione: partecipazione, ok: ok),
                                        fonte: fonte, valore: Double(partecipazione), soglia: Double(anniMinimiPrevidenza))
        }
        let fonte = TestiAdeguatezza.fonte(.orizzonte, ambito: k.tipo?.ambito)
        let periodo = p.periodoRaccomandato ?? k.prodotto?.periodoConsigliato
        guard let h = profilo.orizzonteAnni, h > 0 else {
            // O1
            return ControlloAdeguatezza(tipo: .orizzonte, semaforo: .grigio, esito: TestiAdeguatezza.orizzonteSenzaProfilo,
                                        fonte: fonte, valore: periodo.map { Double($0) })
        }
        if let n = periodo {
            // O2 e O3: come MotoreCoerenza
            let entro = n <= h
            return ControlloAdeguatezza(tipo: .orizzonte, semaforo: entro ? .verde : .rosso,
                                        esito: TestiAdeguatezza.orizzonte(n, h: h, entro: entro),
                                        fonte: fonte, valore: Double(n), soglia: Double(h))
        }
        if let d = anniAllaScadenza(p, oggi: k.i.oggi) {
            // O4: la durata del contratto al posto del periodo raccomandato
            return ControlloAdeguatezza(tipo: .orizzonte, semaforo: .giallo, esito: TestiAdeguatezza.orizzonteDurata(d, h: h),
                                        fonte: fonte, stimato: true, valore: Double(d), soglia: Double(h))
        }
        // O5
        return ControlloAdeguatezza(tipo: .orizzonte, semaforo: .grigio, esito: TestiAdeguatezza.orizzonteSenzaPeriodo,
                                    fonte: fonte, soglia: Double(h))
    }

    /// Anni dalla data `oggi` alla scadenza (almeno 1), arrotondati all'anno più vicino (come
    /// `Posizione.anniAllaScadenza`, ma con la data che arriva da fuori).
    static func anniAllaScadenza(_ p: Posizione, oggi: Date) -> Int? {
        guard let s = p.scadenza else { return nil }
        let mesi = calendario.dateComponents([.month], from: oggi, to: s).month ?? 0
        return max(1, Int((Double(mesi) / 12).rounded()))
    }

    // MARK: - 3 · Conoscenza ed esperienza

    private static func controlloEsperienza(_ k: Contesto) -> ControlloAdeguatezza? {
        let griglia = k.i.cliente.profilo.esperienzaProdotti
        guard let v = MotoreEsperienza.verifica(k.p, esperienza: griglia, prodotti: k.i.prodotti) else { return nil }
        let fonte = TestiAdeguatezza.fonte(.esperienza, ambito: v.classificazione.tipo.ambito)
        var dettagli: [String] = []
        var valore: Double?
        var soglia: Double?
        if let s = v.perdita {
            valore = s.percento
            soglia = griglia?.capacitaPerdite?.limite
            dettagli.append(TestiAdeguatezza.perdita(s))
        }
        if v.classificazione.stimata { dettagli.append(TestiAdeguatezza.tipoStimato) }

        let semaforo: Semaforo
        let esito: String
        if griglia?.compilata != true || v.livello == .daChiedere {
            semaforo = .grigio                                  // E1
            esito = TestiAdeguatezza.esperienzaNonRilevata
        } else if v.livello == .nonConosce {
            semaforo = .rosso                                   // E2
            esito = TestiEsperienza.esitoScheda(v)
        } else if v.oltreCapacita == true {
            semaforo = .rosso                                   // E3
            esito = TestiEsperienza.esitoScheda(v)
        } else if v.livello == .daSpiegare {
            semaforo = .giallo                                  // E4
            esito = TestiEsperienza.esitoScheda(v)
        } else if griglia?.capacitaPerdite == nil && v.perdita != nil {
            semaforo = .grigio                                  // E5
            esito = TestiAdeguatezza.capacitaNonIndicata
        } else {
            semaforo = .verde                                   // E6
            esito = TestiEsperienza.esitoScheda(v)
        }
        return ControlloAdeguatezza(tipo: .esperienza, semaforo: semaforo, esito: esito, dettagli: dettagli, fonte: fonte,
                                    stimato: v.classificazione.stimata, valore: valore, soglia: soglia)
    }

    // MARK: - 4 · Bisogno a cui risponde

    private static func controlloBisogno(_ k: Contesto) -> (controllo: ControlloAdeguatezza, collegamento: CollegamentoBisogno?, suggerito: Bool) {
        let p = k.p
        let esiti = k.i.cliente.bisogni.esiti
        let fonte = TestiAdeguatezza.fonte(.bisogno, ambito: k.tipo?.ambito)

        // Il collegamento: quello della scheda, un obiettivo già collegato in Obiettivi, oppure un suggerimento
        var collegamento: CollegamentoBisogno?
        var suggerito = false
        if let c = k.i.scheda?.collegamento {
            collegamento = c
        } else if let o = k.i.obiettivi.first(where: { $0.posizioniCollegate.contains(p.id) }) {
            collegamento = .obiettivo(o.id)
        } else if let r = k.i.bisogni.first(where: { esiti[$0.id] == true && compatibile($0.area, p.area) }) {
            collegamento = .rilevato(r.id)
            suggerito = true
        } else if let a = areaSuggerita(k.i.cliente.bisogni, area: p.area) {
            collegamento = .area(a)
            suggerito = true
        }

        func controllo(_ s: Semaforo, _ esito: String) -> ControlloAdeguatezza {
            ControlloAdeguatezza(tipo: .bisogno, semaforo: s, esito: esito, fonte: fonte)
        }
        guard let c = collegamento else {
            return (controllo(.grigio, TestiAdeguatezza.bisognoAssente), nil, false)      // B1
        }
        if suggerito {
            let descrizione = TestiAdeguatezza.descrizione(c, bisogni: k.i.bisogni, obiettivi: k.i.obiettivi)
            return (controllo(.giallo, TestiAdeguatezza.bisognoSuggerito(descrizione)), c, true)   // B2
        }
        // L'area del collegamento, per la compatibilità (nil = non si controlla)
        var areaCollegamento: AreaBisogno?
        switch c {
        case .rilevato(let id):
            let rilevato = k.i.bisogni.first { $0.id == id }
            let esitoBisogno: Bool? = esiti[id]
            if esitoBisogno == false {
                return (controllo(.rosso, TestiAdeguatezza.bisognoScartato(rilevato?.titolo)), c, false)       // B3
            }
            if esitoBisogno == nil {
                return (controllo(.giallo, TestiAdeguatezza.bisognoDaConfermare(rilevato?.titolo)), c, false)  // B4
            }
            areaCollegamento = rilevato?.area
        case .obiettivo(let id):
            guard let o = k.i.obiettivi.first(where: { $0.id == id }) else {
                return (controllo(.grigio, TestiAdeguatezza.obiettivoSparito), c, false)                      // B5
            }
            areaCollegamento = o.area
        case .area(let a):
            areaCollegamento = a
        }
        if let a = areaCollegamento, !compatibile(a, p.area) {
            return (controllo(.giallo, TestiAdeguatezza.bisognoNonTipico(p.area, a)), c, false)                // B6
        }
        switch c {
        case .area(let a):
            let importanza = k.i.cliente.bisogni.valutazione(a).importanza
            if importanza < .media {
                return (controllo(.giallo, TestiAdeguatezza.areaPocoImportante(a, importanza)), c, false)      // B7
            }
            return (controllo(.verde, TestiAdeguatezza.rispondeArea(a, importanza)), c, false)                 // B8
        case .rilevato(let id):
            let titolo = k.i.bisogni.first { $0.id == id }?.titolo
            return (controllo(.verde, TestiAdeguatezza.rispondeBisogno(titolo)), c, false)                     // B8
        case .obiettivo(let id):
            let o = k.i.obiettivi.first { $0.id == id }
            return (controllo(.verde, TestiAdeguatezza.rispondeObiettivo(o)), c, false)                        // B8
        }
    }

    /// L'area valutata con l'importanza più alta (almeno media) compatibile con l'area della posizione; a parità
    /// vince l'ordine delle aree.
    private static func areaSuggerita(_ b: ProfiloBisogni, area: AreaPosizione) -> AreaBisogno? {
        var scelta: (area: AreaBisogno, importanza: Importanza)?
        for a in AreaBisogno.allCases where compatibile(a, area) {
            let imp = b.valutazione(a).importanza
            guard imp >= .media else { continue }
            if scelta == nil || imp > scelta!.importanza { scelta = (a, imp) }
        }
        return scelta?.area
    }

    /// L'area della mappa compatibile con l'area della posizione.
    static func compatibile(_ b: AreaBisogno, _ a: AreaPosizione) -> Bool {
        switch b {
        case .casa: return [.risparmio, .investimento, .protezione].contains(a)
        case .famiglia: return [.protezione, .risparmio, .investimento].contains(a)
        case .lavoro: return [.protezione, .risparmio].contains(a)
        case .pensione: return [.previdenza, .risparmio, .investimento].contains(a)
        case .salute: return a == .protezione
        case .patrimonio: return [.investimento, .risparmio, .previdenza, .protezione].contains(a)
        }
    }

    // MARK: - 5 · Liquidità e vincoli

    private static func controlloLiquidita(_ k: Contesto) -> (controllo: ControlloAdeguatezza, oggi: Double?, resta: Double?) {
        let p = k.p
        let i = k.i
        let fonte = TestiAdeguatezza.fonte(.liquidita, ambito: k.previdenza ? .previdenza : k.tipo?.ambito)
        let conti = k.inEssere.filter { $0.area == .liquidita }
        let liquiditaOggi = conti.reduce(0) { $0 + $1.valore }
        let uso = k.fonte == .liquidita ? p.versamentoIniziale : 0
        let resta = liquiditaOggi - uso
        let riserva = i.protezione.fabbisognoMensile * Double(i.protezione.mesiRiserva)
        let limite = calendario.date(byAdding: .month, value: mesiObiettiviVicini, to: i.oggi) ?? i.oggi
        let vicini = i.obiettivi
            .filter { $0.scadenza >= i.oggi && $0.scadenza <= limite && !$0.posizioniCollegate.contains(p.id) }
            .reduce(0) { $0 + AvanzamentoObiettivo($1, posizioni: k.altre).mancante }
        let necessario = riserva + vicini
        let blocco = p.bloccoRiscatto(prodotto: k.prodotto)
        let senzaRiserva = i.protezione.fabbisognoMensile <= 0 || i.protezione.mesiRiserva <= 0

        // Il colore di base: vince la prima regola
        var semaforo: Semaforo
        let esito: String
        if conti.isEmpty {
            semaforo = .grigio                                   // L1
            esito = TestiAdeguatezza.liquiditaAssente
        } else if senzaRiserva {
            semaforo = .grigio                                   // L2
            esito = TestiAdeguatezza.riservaAssente
        } else if resta < 0 {
            semaforo = .rosso                                    // L3
            esito = TestiAdeguatezza.liquiditaNonBasta(oggi: liquiditaOggi, uso: uso)
        } else if resta < riserva * sogliaRiservaMinima {
            semaforo = .rosso                                    // L4
            esito = TestiAdeguatezza.restaMenoMeta(resta, riserva: riserva)
        } else if resta < riserva {
            semaforo = .giallo                                   // L5
            esito = TestiAdeguatezza.restaMenoRiserva(resta, riserva: riserva, mesi: i.protezione.mesiRiserva)
        } else if resta < necessario {
            semaforo = .giallo                                   // L6
            esito = TestiAdeguatezza.restaSenzaObiettivi(resta, riserva: riserva, vicini: vicini)
        } else {
            semaforo = .verde                                    // L7
            esito = TestiAdeguatezza.restaBasta(resta, riserva: riserva, vicini: vicini)
        }

        var dettagli: [String] = []
        if k.fonteRipiegata { dettagli.append(TestiAdeguatezza.fonteRipiegata) }
        // L8: il versamento resta vincolato e la liquidità non basta (solo con i conti indicati)
        let vincolato = (blocco ?? 0) > 0 || k.previdenza
        if !conti.isEmpty, p.versamentoIniziale > 0, k.fonte == .liquidita, vincolato, resta < necessario {
            semaforo = peggiore(semaforo, .rosso)
            dettagli.append(TestiAdeguatezza.vincolato(mesi: k.previdenza ? nil : blocco))
        }
        // L9: i versamenti periodici sul reddito netto
        if p.premioAnnuo > 0, let r = i.cliente.profilo.redditoNettoAnnuo, r > 0 {
            let q = p.premioAnnuo / r * 100
            if q > premioEccessivo {
                semaforo = peggiore(semaforo, .rosso)
                dettagli.append(TestiAdeguatezza.versamenti(p.premioAnnuo, quota: q, soglia: premioEccessivo))
            } else if q > premioAttenzione {
                semaforo = peggiore(semaforo, .giallo)
                dettagli.append(TestiAdeguatezza.versamenti(p.premioAnnuo, quota: q, soglia: premioAttenzione))
            }
        }
        // Note che non cambiano il colore
        if p.versamentoIniziale > 0 { dettagli.append(TestiAdeguatezza.capitaleDa(k.fonte)) }
        let stimato = !i.ipotesiConfermate && !senzaRiserva
        if stimato {
            dettagli.append(TestiAdeguatezza.ipotesiDaConfermare(fabbisogno: i.protezione.fabbisognoMensile, mesi: i.protezione.mesiRiserva))
        }
        var penali: [(anno: Int, penale: Double)] = []
        for anno in anniPenali {
            let v = p.penale(anno: anno, prodotto: k.prodotto)
            if v > 0 { penali.append((anno: anno, penale: v)) }
        }
        if !penali.isEmpty { dettagli.append(TestiAdeguatezza.penali(penali)) }
        if k.previdenza {
            dettagli.append(TestiAdeguatezza.vincoloPrevidenza)
            let piani = k.inEssere.filter { $0.regime == .previdenza }
            // Somme passo per passo: un'espressione sola con tre `reduce` e i `??` appesantisce il controllo dei tipi
            var lavoratore: Double = p.premioAnnuo
            var datore: Double = max(0, p.contributoDatore ?? 0)
            var tfr: Double = max(0, p.tfrConferito ?? 0)
            for x in piani {
                lavoratore += x.premioAnnuo
                datore += max(0, x.contributoDatore ?? 0)
                tfr += max(0, x.tfrConferito ?? 0)
            }
            let deducibilita = DeducibilitaPrevidenza(lavoratore: lavoratore, datore: datore, tfr: tfr)
            if deducibilita.eccedenza > 0 {
                dettagli.append(TestiAdeguatezza.deducibilita(eccedenza: deducibilita.eccedenza, limite: deducibilita.limite))
            }
        }
        let controllo = ControlloAdeguatezza(tipo: .liquidita, semaforo: semaforo, esito: esito, dettagli: dettagli, fonte: fonte,
                                             stimato: stimato, valore: conti.isEmpty ? nil : resta, soglia: necessario)
        return (controllo, conti.isEmpty ? nil : liquiditaOggi, conti.isEmpty ? nil : resta)
    }

    // MARK: - 6 · Concentrazione dopo la firma

    private static func controlloConcentrazione(_ k: Contesto) -> ControlloAdeguatezza? {
        guard !k.protezione else { return nil }
        let p = k.p
        let fonte = TestiAdeguatezza.fonte(.concentrazione, ambito: k.tipo?.ambito)
        let nome = MotoreCoerenza.nomeEmittente(p)
        guard !nome.isEmpty else {
            // C1: indipendente senza emittente
            return ControlloAdeguatezza(tipo: .concentrazione, semaforo: .grigio, esito: TestiAdeguatezza.emittenteAssente, fonte: fonte)
        }
        let prima = MotoreCoerenza.misure(k.inEssere, profilo: nil)
        var dopoBase = k.inEssere.filter { $0.id != k.sostituita?.id }
        if k.fonte == .liquidita, p.versamentoIniziale > 0 {
            dopoBase = togliDaiConti(dopoBase, importo: p.versamentoIniziale)
        }
        let dopo = MotoreCoerenza.misure(dopoBase + [MotoreCoerenza.comeInEssere(p)], profilo: nil)
        let chiave = MotoreCoerenza.chiaveEmittente(nome)
        func misura(_ m: MisureCoerenza) -> (quota: Double, valore: Double) {
            guard let e = m.emittenti.first(where: { MotoreCoerenza.chiaveEmittente($0.nome) == chiave }) else { return (0, 0) }
            return (e.quota * 100, e.valore)
        }
        let q0 = misura(prima).quota
        let (q, v) = misura(dopo)
        let alleanza = (dopo.perCanale[.alleanza] ?? 0) * 100

        var semaforo: Semaforo
        let esito: String
        if v < MotoreCoerenza.minimoConcentrazione {
            semaforo = .verde                                    // C2
            esito = TestiAdeguatezza.importiPiccoli
        } else if q > sogliaEmittenteAlta && q - q0 >= aumentoRilevante {
            semaforo = .rosso                                    // C3
            esito = TestiAdeguatezza.emittenteAlto(nome, quota: q, aumento: q - q0)
        } else if q > MotoreCoerenza.sogliaEmittente {
            semaforo = .giallo                                   // C4
            esito = TestiAdeguatezza.emittenteOltre(nome, quota: q)
        } else {
            semaforo = .verde                                    // C5
            esito = TestiAdeguatezza.emittentePeso(nome, quota: q)
        }
        var dettagli = [TestiAdeguatezza.primaDopo(q0, q)]
        // C6: quasi tutto nel canale Alleanza
        if p.canale == .alleanza, alleanza > MotoreCoerenza.sogliaCanale, dopo.investimenti >= MotoreCoerenza.minimoConcentrazione {
            semaforo = peggiore(semaforo, .giallo)
            dettagli.append(TestiAdeguatezza.canaleAlleanza(alleanza))
        }
        return ControlloAdeguatezza(tipo: .concentrazione, semaforo: semaforo, esito: esito, dettagli: dettagli, fonte: fonte,
                                    valore: q, soglia: MotoreCoerenza.sogliaEmittente)
    }

    /// I conti dopo il versamento: l'importo si toglie in proporzione ai saldi, mai sotto zero.
    private static func togliDaiConti(_ posizioni: [Posizione], importo: Double) -> [Posizione] {
        let totale = posizioni.filter { $0.area == .liquidita }.reduce(0) { $0 + max(0, $1.valore) }
        guard totale > 0 else { return posizioni }
        return posizioni.map { x in
            guard x.area == .liquidita else { return x }
            var q = x
            let v = max(0, x.valore)
            q.controvalore = max(0, v - importo * v / totale)
            return q
        }
    }

    // MARK: - 7 · Sostituzione di un contratto

    private static func controlloSostituzione(_ k: Contesto) -> (controllo: ControlloAdeguatezza, uscita: UscitaSostituzione?)? {
        guard let a = k.sostituita else { return nil }
        let p = k.p
        let fonte = TestiAdeguatezza.fonte(.sostituzione, ambito: k.tipo?.ambito)
        var dettagli: [String] = []
        let cambioCanale = a.canale != p.canale

        guard a.area.proiettabile && p.area.proiettabile else {
            // Una delle due è una copertura (o non si proietta): niente confronto di valori, sempre almeno giallo
            let perse = garanziePerse(a, p, trasferimento: false, data: k.i.oggi)
            if a.area == .protezione || p.area == .protezione { dettagli.append(TestiAdeguatezza.coperturaNuova) }
            if !perse.isEmpty { dettagli.append(TestiAdeguatezza.garanzie(perse)) }
            if cambioCanale { dettagli.append(TestiAdeguatezza.cambioCanale(a, p)) }
            let controllo = ControlloAdeguatezza(tipo: .sostituzione, semaforo: .giallo,
                                                 esito: TestiAdeguatezza.sostituzioneCopertura(a), dettagli: dettagli, fonte: fonte)
            return (controllo, nil)
        }

        let e = MotoreSostituzione.calcola(attuale: a, alternativa: p, prodotti: k.i.prodotti,
                                           orizzonteCliente: k.i.cliente.profilo.orizzonteAnni, data: k.i.oggi)
        let costi = e.penaleUscita + e.bolloUscita + e.ingressoCambio
        let percentuale = e.valoreOggi > 0 ? costi / e.valoreOggi * 100 : 0
        let perse = garanziePerse(a, p, trasferimento: e.trasferimento, data: k.i.oggi)

        // Le regole valgono tutte: vince il colore peggiore
        var semaforo: Semaforo = .verde                                                   // S7
        if e.riscattoPrevidenza != nil { semaforo = peggiore(semaforo, .rosso) }          // S1
        if percentuale > uscitaEccessiva { semaforo = peggiore(semaforo, .rosso) }        // S2
        if e.pareggio == nil { semaforo = peggiore(semaforo, .rosso) }                    // S3
        if percentuale > uscitaAttenzione { semaforo = peggiore(semaforo, .giallo) }      // S4
        if !perse.isEmpty { semaforo = peggiore(semaforo, .giallo) }                      // S5
        if let g = e.pareggio, Double(g) > Double(e.anni) / 2 { semaforo = peggiore(semaforo, .giallo) }  // S6
        if cambioCanale { semaforo = peggiore(semaforo, .giallo) }                        // S8

        let esito: String
        if e.riscattoPrevidenza != nil {
            esito = TestiAdeguatezza.riscattoPrevidenza
        } else if percentuale > uscitaEccessiva {
            esito = TestiAdeguatezza.uscitaCara(costi, percentuale: percentuale)
        } else if let g = e.pareggio {
            esito = TestiAdeguatezza.uscita(costi, percentuale: percentuale, pareggio: g)
        } else {
            esito = TestiAdeguatezza.nonRecupera(anni: e.anni)
        }

        if costi >= impostaMinima {
            dettagli.append(TestiAdeguatezza.vociCosti(penale: e.penaleUscita, bollo: e.bolloUscita, ingresso: e.ingressoCambio))
        }
        if e.impostaUscita > impostaMinima { dettagli.append(TestiAdeguatezza.imposteAnticipate(e.impostaUscita)) }
        if !perse.isEmpty { dettagli.append(TestiAdeguatezza.garanzie(perse)) }
        if let g = e.pareggio, Double(g) > Double(e.anni) / 2 {
            dettagli.append(TestiAdeguatezza.pareggioTardo(g, anni: e.anni))
        }
        if let s = a.scadenza, scadeEntroUnAnno(s, oggi: k.i.oggi) {
            dettagli.append(TestiAdeguatezza.scadePresto(a.nome, scadenza: s))
        }
        if e.trasferimento { dettagli.append(TestiAdeguatezza.trasferimento) }
        if cambioCanale { dettagli.append(TestiAdeguatezza.cambioCanale(a, p)) }

        let uscita = UscitaSostituzione(sostituita: a, costi: costi, percentuale: percentuale, imposteAnticipate: e.impostaUscita,
                                        garanziePerse: perse, pareggio: e.pareggio, anni: e.anni, trasferimento: e.trasferimento,
                                        riscattoPrevidenza: e.riscattoPrevidenza != nil)
        let controllo = ControlloAdeguatezza(tipo: .sostituzione, semaforo: semaforo, esito: esito, dettagli: dettagli, fonte: fonte,
                                             valore: percentuale, soglia: uscitaAttenzione)
        return (controllo, uscita)
    }

    private static func scadeEntroUnAnno(_ s: Date, oggi: Date) -> Bool {
        let inizio = calendario.startOfDay(for: oggi)
        let limite = calendario.date(byAdding: .day, value: 365, to: inizio) ?? inizio
        return s >= inizio && s <= limite
    }

    /// Le garanzie che si perdono passando da `a` a `b` (testi per il dettaglio), in quest'ordine: capitale
    /// garantito, minimo garantito, consolidamento, copertura, anni di partecipazione alla previdenza.
    static func garanziePerse(_ a: Posizione, _ b: Posizione, trasferimento: Bool, data: Date = Date()) -> [String] {
        var elenco: [String] = []
        let gestioneA = a.gestioneSeparata || a.multiramo
        let gestioneB = b.gestioneSeparata || b.multiramo
        if gestioneA && !gestioneB {
            elenco.append(TestiAdeguatezza.persoCapitaleGarantito)
            if let m = a.minimoGarantito, m > 0 { elenco.append(TestiAdeguatezza.persoMinimo(m)) }
            if a.consolidamento == true { elenco.append(TestiAdeguatezza.persoConsolidamento) }
        }
        if let rischio = a.rischio, let capitale = a.capitaleAssicurato, capitale > 0,
           b.rischio != rischio || (b.capitaleAssicurato ?? 0) < capitale {
            elenco.append(TestiAdeguatezza.persaCopertura(rischio, capitale: capitale))
        }
        if a.regime == .previdenza && !trasferimento {
            elenco.append(TestiAdeguatezza.persiAnniPrevidenza(MotoreFiscale.anniPartecipazione(a, data: data)))
        }
        return elenco
    }

    /// La posizione da proporre come sostituita: tra quelle in essere d'investimento, risparmio o previdenza,
    /// prima quelle che scadono entro un anno (la più vicina), poi la più grande della stessa area. nil se nessuna.
    static func sostituitaSuggerita(_ p: Posizione, posizioni: [Posizione], oggi: Date) -> String? {
        let candidate = posizioni.filter {
            $0.id != p.id && $0.stato == .inEssere && [.investimento, .risparmio, .previdenza].contains($0.area)
        }
        let inScadenza = candidate
            .filter { x in x.scadenza.map { scadeEntroUnAnno($0, oggi: oggi) } ?? false }
            .min { ($0.scadenza ?? oggi) < ($1.scadenza ?? oggi) }
        if let x = inScadenza { return x.id }
        return candidate.filter { $0.area == p.area }.max { $0.valore < $1.valore }?.id
    }

    // MARK: - Complessivo

    /// L'ordine dei colori per il complessivo: rosso, poi grigio, poi giallo, poi verde.
    private static func gravita(_ s: Semaforo) -> Int {
        switch s {
        case .rosso: return 3
        case .grigio: return 2
        case .giallo: return 1
        case .verde: return 0
        }
    }

    /// Rosso se ce n'è uno; poi grigio; poi giallo; altrimenti verde. Elenco vuoto: grigio.
    static func complessivo(_ s: [Semaforo]) -> Semaforo {
        guard var peggio = s.first else { return .grigio }
        for x in s.dropFirst() { peggio = peggiore(peggio, x) }
        return peggio
    }

    /// Il peggiore di due colori nello stesso ordine di `complessivo`.
    static func peggiore(_ a: Semaforo, _ b: Semaforo) -> Semaforo {
        gravita(b) > gravita(a) ? b : a
    }

    // MARK: - Documenti

    /// I documenti del canale della proposta: attivi, del tipo giusto, quelli «solo sostituzione» se sostituisce.
    static func documenti(_ p: Posizione, voci: [VoceDocumento], tipo: TipoProdotto?, sostituzione: Bool) -> [VoceDocumento] {
        voci.filter { v in
            v.attiva && v.canale == p.canale
                && (v.perTipo.map { $0.comprende(tipo) } ?? true)
                && (!v.soloSostituzione || sostituzione)
        }
    }

    // MARK: - Centro notifiche

    /// Schede esistenti incomplete (centro notifiche): solo quelle di posizioni che ci sono ancora. Leggero:
    /// solo classificazione e documenti, niente crisi né sostituzione. Prima la scheda toccata da più tempo.
    static func daCompletare(schede: [SchedaAdeguatezza], posizioni: [Posizione], voci: [VoceDocumento],
                             prodotti: [Prodotto]) -> [SchedaDaCompletare] {
        let aperte = schede.filter { $0.firmataIl == nil }
        guard !aperte.isEmpty else { return [] }
        // Con due posizioni con lo stesso id vale la prima
        let perId = Dictionary(posizioni.map { ($0.id, $0) }, uniquingKeysWith: { primo, _ in primo })
        var elenco: [(data: Date, scheda: SchedaDaCompletare)] = []
        for s in aperte {
            guard let p = perId[s.posizioneId] else { continue }
            let data = s.aggiornataIl ?? s.creataIl
            if p.stato == .inEssere {
                elenco.append((data, SchedaDaCompletare(posizione: p, motivo: .firma)))
            } else if p.stato == .proposta && p.esito == .presentata {
                let sostituzione = s.posizioneSostituitaId.flatMap { perId[$0] }.map { $0.stato == .inEssere } ?? false
                let tipo = MotoreEsperienza.classifica(p, prodotti: prodotti)?.tipo
                let mancano = documenti(p, voci: voci, tipo: tipo, sostituzione: sostituzione)
                    .filter { s.consegnato($0.id) == nil && !s.nonPertinenti.contains($0.id) }
                    .count
                if mancano > 0 { elenco.append((data, SchedaDaCompletare(posizione: p, motivo: .documenti(mancano: mancano)))) }
            }
        }
        return elenco.sorted { $0.data < $1.data }.map { $0.scheda }
    }
}
