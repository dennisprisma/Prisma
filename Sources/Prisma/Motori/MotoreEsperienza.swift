import Foundation

// Esperienza per tipo di prodotto e capacità di sostenere perdite (dalla versione 21 dell'archivio).
// Motore puro: solo Foundation, nessuno stato, nessun `Date()`, non legge StatoShell.
// I testi lunghi (cosa spiegare, fonti, metodo, frasi delle incoerenze) stanno in `TestiEsperienza`.

/// Come il cliente conosce un tipo di prodotto.
enum LivelloEsperienza: CaseIterable {
    case daChiedere, nonConosce, daSpiegare, conosce, esperto

    var nome: String {
        switch self {
        case .daChiedere: return "Da chiedere"
        case .nonConosce: return "Non lo conosce"
        case .daSpiegare: return "Da spiegare"
        case .conosce: return "Lo conosce"
        case .esperto: return "Ne ha esperienza"
        }
    }

    /// 0 non conosce, 1 da spiegare, 2 conosce, 3 esperienza; nil da chiedere. È il `valore` dell'incoerenza.
    var punteggio: Int? {
        switch self {
        case .daChiedere: return nil
        case .nonConosce: return 0
        case .daSpiegare: return 1
        case .conosce: return 2
        case .esperto: return 3
        }
    }

    /// Un problema da segnalare se il tipo è in proposta.
    var problema: Bool { self == .nonConosce || self == .daSpiegare }
}

/// Le regole di riferimento di un tipo di prodotto.
enum AmbitoNormativo {
    /// Prodotti d'investimento assicurativi (IBIP): Ramo I, Ramo III, multiramo.
    case ibip
    /// Strumenti finanziari (MiFID II): fondi, ETF, azioni, obbligazioni.
    case mifid
    /// Previdenza complementare (D.Lgs. 252/2005, COVIP).
    case previdenza
    /// Assicurazioni di protezione, non d'investimento (coerenza con richieste ed esigenze).
    case protezione
}

extension TipoProdotto {
    /// `.ramoI`, `.ramoIII`, `.multiramo` → `.ibip`; `.fondiETF`, `.titoli` → `.mifid`; `.previdenza` e
    /// `.protezione` → l'ambito con lo stesso nome. API pubblica: la usa anche la scheda di adeguatezza.
    var ambito: AmbitoNormativo {
        switch self {
        case .ramoI, .ramoIII, .multiramo: return .ibip
        case .fondiETF, .titoli: return .mifid
        case .previdenza: return .previdenza
        case .protezione: return .protezione
        }
    }

    /// Prodotti d'investimento (IBIP e MiFID): solo per questi si stima la perdita nelle crisi.
    var investimento: Bool { ambito == .ibip || ambito == .mifid }
}

/// Il tipo di una posizione per la griglia dell'esperienza.
struct ClassificazioneProdotto: Equatable {
    let tipo: TipoProdotto
    /// true se il tipo è dedotto (tipologia generica): il dettaglio dell'incoerenza lo dice.
    let stimata: Bool
}

/// Perdita della proposta nella crisi peggiore del passato, contata come se fosse in essere
/// (`MotoreCoerenza.comeInEssere`: versamento iniziale più un anno di premi).
struct PerditaStimata: Equatable {
    /// Perdita in % del capitale (≥ 0; 0 = nessuna perdita in nessuna crisi).
    let percento: Double
    /// L'anno della crisi peggiore (nil se nessuna perde).
    let anno: Int?
    let titoloCrisi: String?
    /// Euro persi e capitale contato.
    let euro: Double
    let capitale: Double
}

/// La verifica di una proposta aperta.
struct VerificaEsperienza: Identifiable {
    let posizione: Posizione
    let classificazione: ClassificazioneProdotto
    let livello: LivelloEsperienza
    /// Solo per i tipi d'investimento (IBIP e MiFID); nil per previdenza e protezione.
    let perdita: PerditaStimata?
    /// true/false se la capacità è indicata e il tipo si controlla; nil altrimenti.
    let oltreCapacita: Bool?
    /// Le incoerenze della proposta (esperienza, poi perdite); vuote se la griglia non è compilata.
    let incoerenze: [Incoerenza]
    var id: String { posizione.id }
}

/// Un tipo per cui il cliente ha già posizioni in Prisma, ma «ha avuto» non è sì.
struct SuggerimentoEsperienza: Identifiable, Equatable {
    let tipo: TipoProdotto
    /// Le posizioni in essere o chiuse di quel tipo (il canale si mostra accanto).
    let posizioni: [Posizione]
    var id: TipoProdotto { tipo }
}

/// L'esito per un cliente: il campo `esperienza` di `EsitoCoerenza`.
struct EsitoEsperienza {
    let compilata: Bool
    let capacita: CapacitaPerdite?
    /// Le proposte aperte che si classificano, nell'ordine in cui arrivano.
    let verifiche: [VerificaEsperienza]
    /// Le incoerenze nuove, già pronte per `MotoreCoerenza` (tipi `.esperienza` e `.perdite`).
    let incoerenze: [Incoerenza]

    /// Proposte di un tipo per cui l'esperienza non è indicata.
    var daChiedere: [VerificaEsperienza] { verifiche.filter { $0.livello == .daChiedere } }
    /// Ci sono proposte d'investimento ma la capacità di sostenere perdite manca.
    var capacitaDaChiedere: Bool { capacita == nil && verifiche.contains { $0.perdita != nil } }
}

/// Una riga della griglia per la scheda di adeguatezza.
struct RigaEsperienza: Identifiable {
    let tipo: TipoProdotto
    let voce: VoceEsperienza
    let livello: LivelloEsperienza
    var id: TipoProdotto { tipo }
}

enum MotoreEsperienza {
    /// Con capacità «nessuna» non si segnalano gli spiccioli di arrotondamento (in punti percentuali).
    static let sogliaNessuna = 0.5
    /// L'esperienza finanziaria si suggerisce solo con almeno questi tipi indicati.
    static let minimoTipiSuggerimento = 4

    // MARK: - Classificazione

    /// Il tipo di prodotto di una posizione (nil per liquidità, immobili, debiti, conti e coperture esenti
    /// non di protezione). Una posizione senza tipologia nata da una scheda prodotto si classifica con la scheda.
    static func classifica(_ p: Posizione, prodotti: [Prodotto] = []) -> ClassificazioneProdotto? {
        if p.tipologia.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let id = p.prodottoId,
           let scheda = prodotti.first(where: { $0.id == id }) {
            return classifica(prodotto: scheda)
        }
        return regole(p)
    }

    /// Il tipo di una scheda prodotto: quello della proposta che ne nasce.
    static func classifica(prodotto: Prodotto) -> ClassificazioneProdotto? {
        regole(prodotto.proposta(per: ""))
    }

    /// Le regole in ordine: vince la prima che vale.
    private static func regole(_ p: Posizione) -> ClassificazioneProdotto? {
        switch p.area {
        case .liquidita, .immobili, .debiti: return nil
        case .protezione: return ClassificazioneProdotto(tipo: .protezione, stimata: false)
        case .previdenza: return ClassificazioneProdotto(tipo: .previdenza, stimata: false)
        case .investimento, .risparmio: break
        }
        switch p.regime {
        case .previdenza:
            return ClassificazioneProdotto(tipo: .previdenza, stimata: false)
        case .deposito, .esente:
            return nil
        case .polizza:
            if p.multiramo { return ClassificazioneProdotto(tipo: .multiramo, stimata: false) }
            if p.unitLinked { return ClassificazioneProdotto(tipo: .ramoIII, stimata: false) }
            if p.gestioneSeparata || p.contrattoCapitalizzazione { return ClassificazioneProdotto(tipo: .ramoI, stimata: false) }
            // Polizza generica: come la prova di resistenza, senza rischio di mercato è una gestione separata
            return ClassificazioneProdotto(tipo: MotoreResistenza.quotaARischio(p) == 0 ? .ramoI : .ramoIII, stimata: true)
        case .fondo:
            let t = (p.tipologia + " " + p.nome).lowercased()
            // Prima i fondi: «Fondo comune azionario» ed «ETF azionario» sono fondi, non azioni
            if ["fond", "comparto", "gestione patrimoniale"].contains(where: { t.contains($0) })
                || t.range(of: #"\b(etf|etc|sicav|oicr|oicvm|gpm|gpf)\b"#, options: .regularExpression) != nil {
                return ClassificazioneProdotto(tipo: .fondiETF, stimata: false)
            }
            if ["azion", "obbligazion", "titol", "certificat"].contains(where: { t.contains($0) })
                || t.range(of: #"\b(btp|bot|cct|ctz|bond)\b"#, options: .regularExpression) != nil {
                return ClassificazioneProdotto(tipo: .titoli, stimata: false)
            }
            return ClassificazioneProdotto(tipo: .fondiETF, stimata: true)
        }
    }

    // MARK: - Livello

    /// Le regole in ordine: chi non lo conosce non lo conosce anche se l'ha avuto; chi non l'ha capito va
    /// aiutato; l'ha avuto e capito = esperienza; almeno un sì = lo conosce; tutto vuoto = da chiedere.
    static func livello(_ v: VoceEsperienza) -> LivelloEsperienza {
        if v.conosce == false { return .nonConosce }
        if v.haCapito == false { return .daSpiegare }
        if v.haAvuto == true && v.haCapito == true { return .esperto }
        if v.conosce == true || v.haAvuto == true || v.haCapito == true { return .conosce }
        return .daChiedere
    }

    static func livello(_ e: EsperienzaProdotti?, _ t: TipoProdotto) -> LivelloEsperienza {
        guard let e else { return .daChiedere }
        return livello(e.voce(t))
    }

    // MARK: - Perdita stimata

    /// La perdita della proposta nella crisi peggiore del passato (2008, 2020, 2022), con la composizione
    /// della prova di resistenza; la proposta conta per il versamento iniziale più un anno di premi.
    static func perdita(_ proposta: Posizione) -> PerditaStimata {
        let q = MotoreCoerenza.comeInEssere(proposta)
        let capitale = q.valore
        guard let c = MotoreResistenza.composizione(q) else {
            return PerditaStimata(percento: 0, anno: nil, titoloCrisi: nil, euro: 0, capitale: capitale)
        }
        var peggiore: (percento: Double, crisi: CrisiStorica)?
        for k in MotoreResistenza.crisiDelPassato {
            let persa = -c.variazione(k)
            // Le differenze di arrotondamento non fanno una crisi
            if persa > 1e-9, persa > (peggiore?.percento ?? 0) { peggiore = (percento: persa, crisi: k) }
        }
        guard let w = peggiore else {
            return PerditaStimata(percento: 0, anno: nil, titoloCrisi: nil, euro: 0, capitale: capitale)
        }
        return PerditaStimata(percento: w.percento, anno: w.crisi.anno, titoloCrisi: w.crisi.titolo,
                              euro: capitale * w.percento / 100, capitale: capitale)
    }

    /// true se una perdita (in % del capitale) supera la capacità del cliente; «oltre il 25%» non ha limite.
    static func oltre(_ percento: Double, _ capacita: CapacitaPerdite) -> Bool {
        guard let limite = capacita.limite else { return false }
        return percento > limite + (limite == 0 ? sogliaNessuna : 0)
    }

    // MARK: - Controlli sulle proposte aperte

    /// La verifica di una proposta (nil se il tipo non si classifica). Le incoerenze nascono solo con la
    /// griglia compilata: prima quella di esperienza (E1, E2), poi quella di perdita (P1 o P3).
    static func verifica(_ proposta: Posizione, esperienza: EsperienzaProdotti?, prodotti: [Prodotto]) -> VerificaEsperienza? {
        guard let classe = classifica(proposta, prodotti: prodotti) else { return nil }
        let liv = livello(esperienza, classe.tipo)
        let stima: PerditaStimata? = classe.tipo.investimento ? perdita(proposta) : nil
        let capacita = esperienza?.capacitaPerdite
        var supera: Bool?
        if let capacita, let stima { supera = oltre(stima.percento, capacita) }

        var incoerenze: [Incoerenza] = []
        if esperienza?.compilata == true {
            switch liv {
            case .nonConosce:
                incoerenze.append(Incoerenza(tipo: .esperienza, titolo: TestiEsperienza.titoloNonConosce,
                                             dettaglio: TestiEsperienza.dettaglioEsperienza(proposta, classe, liv),
                                             posizione: proposta, valore: 0, soglia: 2, dopoLeProposte: true))
            case .daSpiegare:
                incoerenze.append(Incoerenza(tipo: .esperienza, titolo: TestiEsperienza.titoloDaSpiegare,
                                             dettaglio: TestiEsperienza.dettaglioEsperienza(proposta, classe, liv),
                                             posizione: proposta, valore: 1, soglia: 2, dopoLeProposte: true))
            case .daChiedere, .conosce, .esperto:
                break
            }
            if let capacita, let stima, supera == true, let limite = capacita.limite {
                // P1: nella crisi peggiore perderebbe più di quanto può sostenere
                incoerenze.append(Incoerenza(tipo: .perdite, titolo: TestiEsperienza.titoloPerdita,
                                             dettaglio: TestiEsperienza.dettaglioPerdita(proposta, stima, capacita),
                                             posizione: proposta, valore: stima.percento, soglia: limite, dopoLeProposte: true))
            } else if capacita == .nessuna, classe.tipo == .ramoI || classe.tipo == .multiramo, proposta.consolidamento == false {
                // P3: gestione separata senza consolidamento annuo, garantita solo a scadenza
                incoerenze.append(Incoerenza(tipo: .perdite, titolo: TestiEsperienza.titoloSoloScadenza,
                                             dettaglio: TestiEsperienza.dettaglioSoloScadenza(proposta),
                                             posizione: proposta, valore: 0, soglia: 0, dopoLeProposte: true))
            }
        }
        return VerificaEsperienza(posizione: proposta, classificazione: classe, livello: liv, perdita: stima,
                                  oltreCapacita: supera, incoerenze: incoerenze)
    }

    /// I controlli sulle proposte aperte di un cliente (`proposte` = `MotoreCoerenza.proposteAperte`).
    static func calcola(cliente c: Cliente, proposte: [Posizione], prodotti: [Prodotto]) -> EsitoEsperienza {
        let e = c.profilo.esperienzaProdotti
        let compilata = e?.compilata == true
        let verifiche = proposte.compactMap { verifica($0, esperienza: e, prodotti: prodotti) }
        return EsitoEsperienza(compilata: compilata, capacita: e?.capacitaPerdite, verifiche: verifiche,
                               incoerenze: compilata ? verifiche.flatMap(\.incoerenze) : [])
    }

    // MARK: - Suggerimenti e sintesi della griglia

    /// Tipi con posizioni in essere o chiuse del cliente per cui «ha avuto» non è sì: Prisma suggerisce di segnarlo.
    static func suggerimenti(_ e: EsperienzaProdotti?, posizioni: [Posizione], prodotti: [Prodotto] = []) -> [SuggerimentoEsperienza] {
        var perTipo: [TipoProdotto: [Posizione]] = [:]
        for p in posizioni where p.stato == .inEssere || p.stato == .chiusa {
            if let classe = classifica(p, prodotti: prodotti) { perTipo[classe.tipo, default: []].append(p) }
        }
        return TipoProdotto.allCases.compactMap { t -> SuggerimentoEsperienza? in
            guard let elenco = perTipo[t], !elenco.isEmpty, e?.voce(t).haAvuto != true else { return nil }
            return SuggerimentoEsperienza(tipo: t, posizioni: elenco)
        }
    }

    /// Le posizioni in essere del cliente per tipo (per la colonna «In Prisma»), proposte escluse.
    static func inEssere(_ posizioni: [Posizione], prodotti: [Prodotto] = []) -> [TipoProdotto: [Posizione]] {
        var perTipo: [TipoProdotto: [Posizione]] = [:]
        for p in posizioni where p.stato == .inEssere {
            if let classe = classifica(p, prodotti: prodotti) { perTipo[classe.tipo, default: []].append(p) }
        }
        return perTipo
    }

    /// L'esperienza finanziaria che la griglia fa pensare. Solo con almeno `minimoTipiSuggerimento` tipi indicati.
    static func esperienzaSuggerita(_ e: EsperienzaProdotti?) -> ProfiloInvestitore.Esperienza? {
        guard let e, e.tipiIndicati >= minimoTipiSuggerimento else { return nil }
        let livelli = TipoProdotto.allCases.map { livello(e, $0) }
        let esperti = livelli.filter { $0 == .esperto }.count
        let noti = livelli.filter { $0 == .conosce || $0 == .esperto }.count
        if noti == 0 { return .nessuna }
        if esperti <= 1 { return .base }
        if esperti <= 3 { return .media }
        return .elevata
    }

    /// «7 tipi su 7 · 2 che non conosce · 1 da spiegare» (le parti a zero non si scrivono).
    static func sintesi(_ e: EsperienzaProdotti?) -> String {
        guard let e, e.tipiIndicati > 0 else { return "Da compilare con il cliente" }
        let totale = TipoProdotto.allCases.count
        let livelli = TipoProdotto.allCases.map { livello(e, $0) }
        let ignoti = livelli.filter { $0 == .nonConosce }.count
        let daSpiegare = livelli.filter { $0 == .daSpiegare }.count
        var parti = ["\(e.tipiIndicati) \(e.tipiIndicati == 1 ? "tipo" : "tipi") su \(totale)"]
        if ignoti > 0 { parti.append("\(ignoti) che non conosce") }
        if daSpiegare > 0 { parti.append("\(daSpiegare) da spiegare") }
        return parti.joined(separator: " · ")
    }

    /// Le 7 righe della griglia, sempre, nell'ordine dei tipi (per la scheda di adeguatezza).
    static func righe(_ e: EsperienzaProdotti?) -> [RigaEsperienza] {
        TipoProdotto.allCases.map { t in
            let v = e?.voce(t) ?? VoceEsperienza(tipo: t)
            return RigaEsperienza(tipo: t, voce: v, livello: livello(v))
        }
    }

    // MARK: - Centro notifiche

    /// Clienti con almeno una proposta aperta di un tipo che dicono di non conoscere (E1), in ordine di nome.
    /// Calcolo leggero, senza crisi: solo classificazione e livello.
    static func daSegnalare(clienti: [Cliente], posizioni: [Posizione], prodotti: [Prodotto]) -> [(cliente: Cliente, proposte: [Posizione])] {
        let conGriglia = clienti.filter { $0.profilo.esperienzaProdotti?.compilata == true }
        guard !conGriglia.isEmpty else { return [] }
        let ids = Set(conGriglia.map(\.id))
        var aperte: [String: [Posizione]] = [:]
        for p in MotoreCoerenza.proposteAperte(posizioni) where ids.contains(p.clienteId) {
            aperte[p.clienteId, default: []].append(p)
        }
        var elenco: [(cliente: Cliente, proposte: [Posizione])] = []
        for c in conGriglia {
            guard let sue = aperte[c.id], !sue.isEmpty else { continue }
            let e = c.profilo.esperienzaProdotti
            let ignote = sue.filter { p in
                guard let classe = classifica(p, prodotti: prodotti) else { return false }
                return livello(e, classe.tipo) == .nonConosce
            }
            if !ignote.isEmpty { elenco.append((cliente: c, proposte: ignote)) }
        }
        return elenco.sorted { $0.cliente.nome.localizedCaseInsensitiveCompare($1.cliente.nome) == .orderedAscending }
    }
}
