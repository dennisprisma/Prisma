import Foundation

// Completezza dei dati per l'analisi (giro 3, specifica 7): per ogni cliente quali analisi girano su dati
// mancanti, stimati o vecchi. Motore puro: nessuno stato, nessun `Date()` nascosto (`oggi` è un parametro).
// Misura solo i dati che entrano nei calcoli di Prisma: codice fiscale, esperienza e consensi restano fuori.

/// Le analisi di Prisma che un dato alimenta (per dire «quali analisi girano su ipotesi»).
enum AnalisiCompletezza: String, CaseIterable, Identifiable {
    case previdenza, protezione, investimenti, costi, successione, fisco, resoconto

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .previdenza: return "Previdenza"
        case .protezione: return "Protezione"
        case .investimenti: return "Rischio e investimenti"
        case .costi: return "Costi"
        case .successione: return "Passaggio generazionale"
        case .fisco: return "Fisco"
        case .resoconto: return "Resoconto"
        }
    }

    /// L'area dell'Analisi 360 che la mostra (nil: non ha un'area).
    var areaAnalisi: AreaAnalisi? {
        switch self {
        case .previdenza: return .previdenza
        case .protezione: return .protezione
        case .investimenti: return .investimenti
        case .costi, .successione, .fisco, .resoconto: return nil
        }
    }
}

/// Com'è un dato. L'ordine è quello di urgenza: prima i mancanti.
enum StatoDato: Int, Comparable {
    case mancante = 0, daAggiornare, stimato, completo

    var nome: String {
        switch self {
        case .mancante: return "Manca"
        case .daAggiornare: return "Da aggiornare"
        case .stimato: return "Stimato"
        case .completo: return "Completo"
        }
    }

    /// Quanto conta nel punteggio: 0, metà, metà, tutto.
    var credito: Double {
        switch self {
        case .mancante: return 0
        case .daAggiornare, .stimato: return 0.5
        case .completo: return 1
        }
    }

    static func < (a: StatoDato, b: StatoDato) -> Bool { a.rawValue < b.rawValue }
}

/// Un campo del modulo del cliente. `etichetta` è IDENTICA all'etichetta di `CampoModulo` in ModuloCliente
/// (serve ad aprire il modulo sul campo); `sezione` è il titolo della `SezioneRipiegabile` che lo contiene.
enum CampoCliente: String, Hashable {
    case dataNascita, statoCivile, propensione, orizzonte, redditoLordo, redditoNetto, tipoLavoratore, montanteContributivo

    var etichetta: String {
        switch self {
        case .dataNascita: return "Data di nascita"
        case .statoCivile: return "Stato civile"
        case .propensione: return "Propensione al rischio"
        case .orizzonte: return "Orizzonte (anni)"
        case .redditoLordo: return "Reddito lordo annuo"
        case .redditoNetto: return "Reddito netto in famiglia"
        case .tipoLavoratore: return "Tipo di lavoratore"
        case .montanteContributivo: return "Montante contributivo"
        }
    }

    /// La sezione ripiegabile che contiene il campo (nil: il campo è sempre in vista).
    var sezione: String? {
        switch self {
        case .redditoNetto, .tipoLavoratore, .montanteContributivo: return CampoCliente.sezioneAnalisi
        case .dataNascita, .statoCivile, .propensione, .orizzonte, .redditoLordo: return nil
        }
    }

    /// Il titolo della sezione «Dati per l'analisi» del modulo del cliente (ModuloCliente).
    static let sezioneAnalisi = "Dati per l'analisi · reddito, lavoro e pensione"
}

/// Dove si completa un dato.
enum DestinazioneCompletezza: Hashable {
    /// Modulo del cliente, sul campo.
    case cliente(CampoCliente)
    /// Modulo del familiare (id), sulla data di nascita.
    case familiare(String)
    /// Area dell'Analisi 360, sul campo (etichetta di `CampoIpotesi`, identica a quella di AppAnalisi360).
    case analisi360(AreaAnalisi, campo: String)
    /// Modulo della posizione (id), sul campo (etichetta di `CampoModulo` in ModuloPosizione).
    case posizione(String, campo: String)
    /// Dettaglio della posizione (id) con un'ancora di DettaglioPosizione (giro 2: "dettaglio-composizione").
    case dettaglioPosizione(String, ancora: String)
}

/// Un dato che serve alle analisi, con il suo stato.
struct VoceCompletezza: Identifiable, Hashable {
    /// Stabile: "nascita", "fabbisogno", "familiare:<id>", "costi:<idPosizione>"… È la chiave di `datiNonPertinenti`.
    let id: String
    let titolo: String
    let stato: StatoDato
    /// 1–3: quanto il dato sposta le cifre.
    let peso: Int
    let analisi: Set<AnalisiCompletezza>
    /// Per il consulente: cosa usa l'analisi al posto del dato (vuoto se completo).
    let ipotesi: String
    /// Per il cliente (report, con il tu): la stessa cosa in parole semplici (vuoto se completo).
    let ipotesiCliente: String
    /// A cosa serve il dato, con la norma quando c'è (aiuto al passaggio del mouse).
    let perche: String
    let destinazione: DestinazioneCompletezza
    /// Per le voci di una posizione: la posizione e il SUO canale (sempre indicato).
    var posizioneId: String? = nil
    var canale: Canale? = nil
    /// Da aggiornare: la data dell'ultimo aggiornamento (nil = senza data).
    var dal: Date? = nil

    /// Le analisi toccate, nell'ordine di `AnalisiCompletezza.allCases`.
    var analisiOrdinate: [AnalisiCompletezza] { AnalisiCompletezza.allCases.filter { analisi.contains($0) } }
}

enum LivelloCompletezza {
    case completo, parziale, scarso

    var nome: String {
        switch self {
        case .completo: return "Dati completi"
        case .parziale: return "Quasi completi"
        case .scarso: return "Da completare"
        }
    }
}

/// La completezza dei dati di un cliente.
struct CompletezzaCliente {
    let clienteId: String
    let oggi: Date
    /// Le voci pertinenti, anche quelle complete, tolte quelle segnate «non pertinenti».
    let voci: [VoceCompletezza]
    /// Le voci segnate «non pertinenti», con la data in cui sono state segnate.
    let escluse: [(voce: VoceCompletezza, il: Date)]

    /// Da completare, nell'ordine di `MotoreCompletezza.ordine`.
    let daCompletare: [VoceCompletezza]
    /// Σ(peso × credito) / Σ peso; 1 se non c'è nessuna voce.
    let quota: Double
    let livello: LivelloCompletezza
    /// Conteggi delle voci da completare per stato.
    let mancanti: Int
    let daAggiornare: Int
    let stimati: Int

    var percentuale: Int { Int((quota * 100).rounded()) }

    init(clienteId: String, oggi: Date, voci: [VoceCompletezza], escluse: [(voce: VoceCompletezza, il: Date)]) {
        self.clienteId = clienteId
        self.oggi = oggi
        self.voci = voci
        self.escluse = escluse
        daCompletare = voci.filter { $0.stato != .completo }.sorted(by: MotoreCompletezza.ordine)
        let pesi = voci.reduce(0) { $0 + $1.peso }
        let crediti = voci.reduce(0.0) { $0 + Double($1.peso) * $1.stato.credito }
        let q = pesi > 0 ? crediti / Double(pesi) : 1
        quota = q
        let manca3 = voci.contains { $0.peso == 3 && $0.stato == .mancante }
        if q >= MotoreCompletezza.sogliaCompleto && !manca3 {
            livello = .completo
        } else if q >= MotoreCompletezza.sogliaParziale {
            livello = .parziale
        } else {
            livello = .scarso
        }
        mancanti = voci.filter { $0.stato == .mancante }.count
        daAggiornare = voci.filter { $0.stato == .daAggiornare }.count
        stimati = voci.filter { $0.stato == .stimato }.count
    }

    /// Le voci da completare che toccano un'analisi.
    func voci(per a: AnalisiCompletezza) -> [VoceCompletezza] {
        daCompletare.filter { $0.analisi.contains(a) }
    }

    /// Le voci da completare da dichiarare in un documento (`MotoreCompletezza.analisi(per:)`).
    func ipotesi(per tipo: TipoProspetto) -> [VoceCompletezza] {
        let toccate = MotoreCompletezza.analisi(per: tipo)
        return daCompletare.filter { !$0.analisi.isDisjoint(with: toccate) }
    }

    /// Le analisi toccate dalle voci da completare, nell'ordine di `AnalisiCompletezza.allCases`.
    var analisiToccate: [AnalisiCompletezza] {
        let tutte = daCompletare.reduce(into: Set<AnalisiCompletezza>()) { $0.formUnion($1.analisi) }
        return AnalisiCompletezza.allCases.filter { tutte.contains($0) }
    }
}

enum MotoreCompletezza {
    /// Valore di una posizione fermo da più di 12 mesi: da aggiornare (lo stesso anno del riesame).
    static let mesiValore = MotoreRiesame.mesiRiesame
    /// Profilo dell'investitore più vecchio di 24 mesi: da aggiornare (la soglia del riesame: due anni).
    static let mesiProfilo = 24
    static let sogliaCompleto = 0.90
    static let sogliaParziale = 0.60
    /// Voci mostrate nella Panoramica prima di «Mostra tutte», e righe al massimo nella pagina del report.
    static let massimoPanoramica = 5
    static let massimoReport = 8
    static let massimoProspetto = 14
    /// L'ancora del dettaglio della posizione con la composizione (giro 2, DettaglioPosizione).
    static let ancoraComposizione = "dettaglio-composizione"

    /// Dalla fonte del cliente (riesame): l'analisi conta solo se salvata.
    static func calcola(_ f: FonteEve) -> CompletezzaCliente {
        calcola(cliente: f.cliente, posizioni: f.posizioni, analisi: f.analisiSalvata ? f.analisi : nil, oggi: f.oggi)
    }

    /// Le analisi di cui un documento dichiara le ipotesi stimate.
    static func analisi(per tipo: TipoProspetto) -> Set<AnalisiCompletezza> {
        switch tipo {
        case .previdenza: return [.previdenza, .fisco]
        case .protezione: return [.protezione]
        case .checkUp, .riesame: return Set(AnalisiCompletezza.allCases)
        case .costi: return [.costi]
        case .resistenza: return [.investimenti]
        case .successione: return [.successione]
        case .resoconto: return [.resoconto]
        case .valutazione, .sostituzione, .obiettivo, .liquidita, .patrimonio, .fascicolo, .posizione, .confronto, .portafoglio:
            return []
        }
    }

    /// L'analisi della completezza che corrisponde a un'area dell'Analisi 360 (risparmio → investimenti).
    static func analisi(perArea area: AreaAnalisi) -> AnalisiCompletezza {
        switch area {
        case .previdenza: return .previdenza
        case .protezione: return .protezione
        case .investimenti, .risparmio: return .investimenti
        }
    }

    /// Prima lo stato (mancante, da aggiornare, stimato), poi il peso più alto, poi il titolo
    /// (`localizedCaseInsensitiveCompare`).
    static func ordine(_ a: VoceCompletezza, _ b: VoceCompletezza) -> Bool {
        if a.stato != b.stato { return a.stato < b.stato }
        if a.peso != b.peso { return a.peso > b.peso }
        return a.titolo.localizedCaseInsensitiveCompare(b.titolo) == .orderedAscending
    }

    /// Costi indicati: la stessa regola di MotoreCosti (`costoComplessivo != nil || costoIngresso != nil`),
    /// copiata qui per non toccare MotoreCosti (file del giro 2).
    static func costiIndicati(_ p: Posizione) -> Bool {
        p.costoComplessivo != nil || p.costoIngresso != nil
    }

    // MARK: - Calcolo

    /// Le posizioni possono essere di tutti i clienti: si tengono quelle del cliente (come MotoreFineAnno).
    /// `analisi` è quella SALVATA (nil = prima stesura ricavata dalle posizioni).
    static func calcola(cliente c: Cliente, posizioni: [Posizione], analisi: Analisi360?, oggi: Date = Date()) -> CompletezzaCliente {
        let cal = Calendar.current
        let sue = posizioni.filter { $0.clienteId == c.id }
        // Proposta aperta: la regola di MotoreCoerenza (una «rimandata» resta aperta)
        let aperte = Set(MotoreCoerenza.proposteAperte(sue).map(\.id))
        let attive = sue.filter { $0.stato == .inEssere || aperte.contains($0.id) }
        let finanziarie = attive.filter(\.area.proiettabile)
        let eta = MotorePensionePubblica.etaAl(c.dataNascita, oggi)
        let previdenzaPertinente = eta.map { $0 < RegolePensione.etaVecchiaia } ?? true

        let salvata = analisi != nil
        let confermate = analisi?.confermate ?? []
        let previdenza = analisi?.previdenza ?? IpotesiPrevidenza()
        let protezione = analisi?.protezione ?? IpotesiProtezione()
        let etaIpotesi = analisi?.previdenza.eta ?? IpotesiPrevidenza().eta
        let profilo = c.profilo
        let T = TestiCompletezza.self
        let P = TestiCompletezza.Perche.self

        var voci: [VoceCompletezza] = []

        // MARK: Voci del cliente

        let senzaNascita = c.dataNascita == nil
        voci.append(VoceCompletezza(
            id: "nascita", titolo: "Data di nascita", stato: senzaNascita ? .mancante : .completo, peso: 3,
            analisi: [.previdenza, .protezione],
            ipotesi: senzaNascita ? T.nascita(eta: etaIpotesi) : "",
            ipotesiCliente: senzaNascita ? T.nascitaCliente(eta: etaIpotesi) : "",
            perche: P.nascita, destinazione: .cliente(.dataNascita)))

        let senzaStatoCivile = c.statoCivile == nil
        voci.append(VoceCompletezza(
            id: "statoCivile", titolo: "Stato civile", stato: senzaStatoCivile ? .mancante : .completo, peso: 1,
            analisi: [.successione, .protezione],
            ipotesi: senzaStatoCivile ? T.statoCivile : "",
            ipotesiCliente: senzaStatoCivile ? T.statoCivileCliente : "",
            perche: P.statoCivile, destinazione: .cliente(.statoCivile)))

        let senzaLordo = (profilo.redditoLordoAnnuo ?? 0) <= 0
        voci.append(VoceCompletezza(
            id: "redditoLordo", titolo: "Reddito lordo annuo", stato: senzaLordo ? .mancante : .completo, peso: 3,
            analisi: [.previdenza, .fisco],
            ipotesi: senzaLordo ? T.redditoLordo : "",
            ipotesiCliente: senzaLordo ? T.redditoLordoCliente : "",
            perche: P.redditoLordo, destinazione: .cliente(.redditoLordo)))

        // Mai mancante: la protezione per persona usa il fabbisogno × 12
        let nettoStimato = profilo.redditoNettoAnnuo == nil
        let nettoIpotizzato = protezione.fabbisognoMensile * 12
        voci.append(VoceCompletezza(
            id: "redditoNetto", titolo: "Reddito netto del cliente", stato: nettoStimato ? .stimato : .completo, peso: 2,
            analisi: [.protezione],
            ipotesi: nettoStimato ? T.redditoNetto(annuo: nettoIpotizzato) : "",
            ipotesiCliente: nettoStimato ? T.redditoNettoCliente(annuo: nettoIpotizzato) : "",
            perche: P.redditoNetto, destinazione: .cliente(.redditoNetto)))

        let fabbisognoStimato = !salvata
            || (!confermate.contains(.protezione) && protezione.fabbisognoMensile == IpotesiProtezione().fabbisognoMensile)
        voci.append(VoceCompletezza(
            id: "fabbisogno", titolo: "Fabbisogno mensile della famiglia", stato: fabbisognoStimato ? .stimato : .completo, peso: 3,
            analisi: [.protezione],
            ipotesi: fabbisognoStimato ? T.fabbisogno(mensile: protezione.fabbisognoMensile) : "",
            ipotesiCliente: fabbisognoStimato ? T.fabbisognoCliente(mensile: protezione.fabbisognoMensile) : "",
            perche: P.fabbisogno,
            destinazione: .analisi360(.protezione, campo: TestiCompletezza.campoFabbisogno)))

        if previdenzaPertinente {
            let previdenzaConfermata = confermate.contains(.previdenza)
            let desideratoStimato = !salvata
                || (!previdenzaConfermata && previdenza.redditoDesiderato == IpotesiPrevidenza().redditoDesiderato)
            voci.append(VoceCompletezza(
                id: "redditoDesiderato", titolo: "Reddito desiderato in pensione", stato: desideratoStimato ? .stimato : .completo,
                peso: 2, analisi: [.previdenza],
                ipotesi: desideratoStimato ? T.redditoDesiderato(mensile: previdenza.redditoDesiderato) : "",
                ipotesiCliente: desideratoStimato ? T.redditoDesideratoCliente(mensile: previdenza.redditoDesiderato) : "",
                perche: P.redditoDesiderato,
                destinazione: .analisi360(.previdenza, campo: TestiCompletezza.campoRedditoDesiderato)))

            let pubblicaStimata = !salvata
                || (!previdenzaConfermata && previdenza.pensionePubblica == IpotesiPrevidenza().pensionePubblica)
            let stima = pubblicaStimata ? MotorePensionePubblica.stima(cliente: c, previdenza: previdenza, data: oggi) : nil
            voci.append(VoceCompletezza(
                id: "pensionePubblica", titolo: "Pensione pubblica attesa", stato: pubblicaStimata ? .stimato : .completo,
                peso: 2, analisi: [.previdenza],
                ipotesi: pubblicaStimata ? T.pensionePubblica(mensile: previdenza.pensionePubblica, stimaNetta: stima?.nettaMensile) : "",
                ipotesiCliente: pubblicaStimata ? T.pensionePubblicaCliente(mensile: previdenza.pensionePubblica) : "",
                perche: P.pensionePubblica,
                destinazione: .analisi360(.previdenza, campo: TestiCompletezza.campoPensionePubblica)))

            let lavoro = profilo.lavoro
            let statoLavoro: StatoDato
            let ipotesiLavoro: String
            if MotorePensionePubblica.motivoAssente(lavoro, reddito: profilo.redditoLordoAnnuo) != nil {
                statoLavoro = .mancante
                ipotesiLavoro = T.lavoroMancante
            } else if lavoro?.sistemaMisto == true {
                statoLavoro = .stimato
                ipotesiLavoro = T.lavoroMisto
            } else if lavoro?.montanteContributivo == nil {
                statoLavoro = .stimato
                ipotesiLavoro = T.lavoroSenzaMontante
            } else {
                statoLavoro = .completo
                ipotesiLavoro = ""
            }
            voci.append(VoceCompletezza(
                id: "lavoro", titolo: "Lavoro e contributi INPS", stato: statoLavoro, peso: 2, analisi: [.previdenza],
                ipotesi: ipotesiLavoro,
                ipotesiCliente: statoLavoro == .completo ? "" : T.lavoroCliente,
                perche: P.lavoro,
                destinazione: lavoro?.tipo == nil ? .cliente(.tipoLavoratore) : .cliente(.montanteContributivo)))
        }

        if !finanziarie.isEmpty {
            let limiteProfilo = cal.date(byAdding: .month, value: -mesiProfilo, to: oggi) ?? oggi
            let statoProfilo: StatoDato
            if profilo.propensione == nil {
                statoProfilo = .mancante
            } else if profilo.aggiornatoIl.map({ $0 < limiteProfilo }) ?? true {
                statoProfilo = .daAggiornare
            } else {
                statoProfilo = .completo
            }
            let canali = Set(finanziarie.map(\.canale))
            voci.append(VoceCompletezza(
                id: "profiloRischio", titolo: "Profilo di rischio", stato: statoProfilo, peso: 3, analisi: [.investimenti],
                ipotesi: statoProfilo == .completo ? "" : T.profilo(mancante: statoProfilo == .mancante, aggiornatoIl: profilo.aggiornatoIl),
                ipotesiCliente: statoProfilo == .completo ? "" : T.profiloCliente(mancante: statoProfilo == .mancante),
                perche: P.profilo(canali: canali), destinazione: .cliente(.propensione),
                dal: statoProfilo == .daAggiornare ? profilo.aggiornatoIl : nil))

            let senzaOrizzonte = profilo.orizzonteAnni == nil
            voci.append(VoceCompletezza(
                id: "orizzonte", titolo: "Orizzonte temporale", stato: senzaOrizzonte ? .mancante : .completo, peso: 1,
                analisi: [.investimenti],
                ipotesi: senzaOrizzonte ? T.orizzonte : "",
                ipotesiCliente: senzaOrizzonte ? T.orizzonteCliente : "",
                perche: P.profilo(canali: canali), destinazione: .cliente(.orizzonte)))
        }

        for f in c.famiglia where f.aCarico {
            let senzaData = f.dataNascita == nil
            voci.append(VoceCompletezza(
                id: "familiare:\(f.id)", titolo: "Data di nascita di \(f.nome)", stato: senzaData ? .mancante : .completo, peso: 1,
                analisi: [.protezione, .successione],
                ipotesi: senzaData ? T.familiare(nome: f.nome) : "",
                ipotesiCliente: senzaData ? T.familiareCliente(nome: f.nome) : "",
                perche: P.familiare, destinazione: .familiare(f.id)))
        }

        // MARK: Voci delle posizioni (le chiuse e le proposte non aperte non ne generano)

        let limiteValore = cal.date(byAdding: .month, value: -mesiValore, to: oggi) ?? oggi
        let inizioOggi = cal.startOfDay(for: oggi)
        for p in attive where p.stato != .chiusa {
            let inEssere = p.stato == .inEssere
            let finanziaria = p.area.proiettabile
            let suPrevidenza: Set<AnalisiCompletezza> = p.regime == .previdenza ? [.previdenza] : []
            let nome = p.nome
            func aggiungi(_ chiave: String, _ dato: String, _ stato: StatoDato, _ peso: Int, _ analisi: Set<AnalisiCompletezza>,
                          _ ipotesi: String, _ ipotesiCliente: String, _ perche: String, _ destinazione: DestinazioneCompletezza,
                          dal: Date? = nil) {
                voci.append(VoceCompletezza(
                    id: "\(chiave):\(p.id)", titolo: "\(dato) · \(nome)", stato: stato, peso: peso, analisi: analisi,
                    ipotesi: stato == .completo ? "" : ipotesi,
                    ipotesiCliente: stato == .completo ? "" : ipotesiCliente,
                    perche: perche, destinazione: destinazione, posizioneId: p.id, canale: p.canale, dal: dal))
            }
            let composizione = DestinazioneCompletezza.dettaglioPosizione(p.id, ancora: ancoraComposizione)

            // Valore aggiornato: la regola di MotoreRiesame.valoriDaAggiornare
            if inEssere, p.area != .protezione, !p.area.passivo, p.area != .immobili {
                let vecchio = p.dataValore.map { $0 < limiteValore } ?? true
                aggiungi("valore", "Valore aggiornato", vecchio ? .daAggiornare : .completo, 1,
                         Set<AnalisiCompletezza>([.resoconto, .investimenti]).union(suPrevidenza),
                         T.valore(nome: nome, dal: p.dataValore), T.valoreCliente(nome: nome, dal: p.dataValore),
                         P.valore, .posizione(p.id, campo: "Valore attuale"), dal: vecchio ? p.dataValore : nil)
            }

            if finanziaria {
                let senzaCosti = !costiIndicati(p)
                aggiungi("costi", "Costi del KID", senzaCosti ? .mancante : .completo, 2,
                         Set<AnalisiCompletezza>([.costi, .investimenti]).union(suPrevidenza),
                         T.costi(nome: nome), T.costiCliente(nome: nome), P.kid,
                         p.unitLinked ? composizione : .posizione(p.id, campo: "Costo annuo"))

                // La previdenza complementare non ha il KID PRIIPs
                if p.regime == .polizza || p.regime == .fondo {
                    var sriStimato = p.sri == nil && p.volatilita == nil
                    if p.multiramoDivisa { sriStimato = sriStimato && p.sriFondi == nil && p.volatilitaFondi == nil }
                    aggiungi("sri", "Indicatore di rischio (SRI)", sriStimato ? .stimato : .completo, 1, [.investimenti],
                             T.sri(nome: nome), T.sriCliente(nome: nome), P.kid,
                             p.unitLinked ? composizione : .posizione(p.id, campo: "Rischio (SRI)"))
                }

                let rendimentoStimato = p.multiramoDivisa ? !p.rendimentoIndicato : p.rendimentoAtteso == nil
                let campoRendimento = p.multiramo ? "Rendimento complessivo" : "Rendimento atteso"
                aggiungi("rendimento", "Rendimento atteso", rendimentoStimato ? .stimato : .completo, 1,
                         Set<AnalisiCompletezza>([.investimenti]).union(suPrevidenza),
                         T.rendimento(nome: nome), T.rendimentoCliente(nome: nome), P.rendimento,
                         p.unitLinked ? composizione : .posizione(p.id, campo: campoRendimento))
            }

            if p.multiramo {
                aggiungi("quotaGestione", "Quota in gestione separata", p.quotaGestioneStimata ? .stimato : .completo, 1,
                         [.investimenti, .costi], T.quotaGestione(nome: nome), T.quotaGestioneCliente(nome: nome),
                         P.quotaGestione, composizione)
            }

            // Beneficiari: la regola delle notifiche (capitale ai beneficiari)
            if inEssere {
                let k = MotoreSuccessione.classifica(p, oggi: oggi)
                if k.1 == .beneficiari && abs(k.0) > 0.5 {
                    aggiungi("beneficiari", "Beneficiari", p.senzaBeneficiari ? .mancante : .completo, 2, [.successione],
                             T.beneficiari(nome: nome), T.beneficiariCliente(nome: nome),
                             P.beneficiari(previdenza: p.regime == .previdenza), .posizione(p.id, campo: "Beneficiari"))
                }
            }

            if p.area == .protezione {
                let scaduta = p.scadenza.map { $0 < inizioOggi } ?? false
                let rischiConCapitale: [RischioCoperto] = [.vita, .invalidita, .ltc, .infortuni]
                if !(inEssere && scaduta), p.rischio.map({ rischiConCapitale.contains($0) }) ?? true {
                    let senzaCapitale = (p.capitaleAssicurato ?? 0) <= 0
                    aggiungi("capitale", "Capitale assicurato", senzaCapitale ? .mancante : .completo, 2, [.protezione],
                             T.capitale(nome: nome), T.capitaleCliente(nome: nome), P.capitale,
                             .posizione(p.id, campo: "Capitale assicurato"))
                }
                aggiungi("rischioCoperto", "Rischio coperto", p.rischio == nil ? .stimato : .completo, 1, [.protezione, .successione],
                         T.rischioCoperto(nome: nome), "", P.rischioCoperto, .posizione(p.id, campo: "Rischio coperto"))
            }

            if inEssere, p.regime == .previdenza {
                let statoAdesione: StatoDato = p.primaAdesione != nil ? .completo : (p.decorrenza != nil ? .stimato : .mancante)
                aggiungi("adesione", "Prima adesione", statoAdesione, 1, [.previdenza, .fisco],
                         T.adesione(nome: nome, conDecorrenza: p.decorrenza != nil), T.adesioneCliente(nome: nome),
                         P.adesione, .posizione(p.id, campo: "Prima adesione"))
            }
        }

        // Le voci segnate «non pertinenti» escono dal punteggio, sopra e sotto la riga
        let segnate = c.datiNonPertinenti ?? [:]
        var pertinenti: [VoceCompletezza] = []
        var escluse: [(voce: VoceCompletezza, il: Date)] = []
        for v in voci {
            if let il = segnate[v.id] { escluse.append((voce: v, il: il)) } else { pertinenti.append(v) }
        }
        return CompletezzaCliente(clienteId: c.id, oggi: oggi, voci: pertinenti, escluse: escluse)
    }
}
