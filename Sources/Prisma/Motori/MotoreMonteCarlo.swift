import Foundation

/// Generatore pseudo-casuale con seme fisso (SplitMix64): a parità di seme dà sempre gli stessi numeri,
/// quindi lo stesso obiettivo dà la stessa probabilità a ogni apertura e le prove sono ripetibili.
struct GeneratoreSeme: RandomNumberGenerator {
    private(set) var stato: UInt64
    /// Il secondo numero normale di Box-Muller, tenuto per la chiamata successiva.
    private var riserva: Double?

    init(seme: UInt64) {
        stato = seme
        riserva = nil
    }

    mutating func next() -> UInt64 {
        stato = stato &+ 0x9E37_79B9_7F4A_7C15
        var z = stato
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniforme in (0, 1), estremi esclusi (53 bit, a metà dell'intervallo).
    mutating func uniforme() -> Double {
        (Double(next() >> 11) + 0.5) * 0x1.0p-53
    }

    /// Normale standard (media 0, deviazione 1) con il metodo di Box-Muller.
    mutating func normale() -> Double {
        if let r = riserva {
            riserva = nil
            return r
        }
        let u1 = uniforme()
        let u2 = uniforme()
        let raggio = (-2 * log(u1)).squareRoot()
        let angolo = 2 * Double.pi * u2
        riserva = raggio * sin(angolo)
        return raggio * cos(angolo)
    }
}

/// Una voce da simulare: una posizione collegata all'obiettivo o l'accantonato. Le percentuali sono annue.
struct LineaMonteCarlo {
    /// L'imposta alla fine, come in `MotoreObiettivo` per ogni regime.
    enum Imposta: Equatable {
        case nessuna
        /// Sul guadagno oltre `base` (polizze, fondi e depositi).
        case guadagno(aliquota: Double, base: Double)
        /// Previdenza: sui contributi dedotti (il minore tra valore e versato, meno i non dedotti).
        case versato(aliquota: Double, base: Double, nonDedotti: Double)

        func netto(_ lordo: Double) -> Double {
            switch self {
            case .nessuna:
                return lordo
            case let .guadagno(aliquota, base):
                return lordo - max(0, lordo - max(base, 0)) * aliquota / 100
            case let .versato(aliquota, base, nonDedotti):
                return lordo - max(0, min(lordo, base) - nonDedotti) * aliquota / 100
            }
        }
    }

    var nome: String
    var capitale: Double
    var versamento: Double = 0
    var frequenza: Frequenza = .unica
    var costoIngresso: Double = 0
    /// Rendimento medio annuo atteso (media aritmetica), prima dei costi.
    var rendimento: Double
    var costoAnnuo: Double = 0
    /// Volatilità annua (deviazione standard dei rendimenti), in %.
    var volatilita: Double = 0
    /// Ramo I: il rendimento accreditato non è mai negativo.
    var capitaleGarantito = false
    /// Imposta sui risultati positivi man mano (fondi pensione), in %.
    var tassazioneAnnua: Double = 0
    var imposta: Imposta = .nessuna

    /// Multiramo a due parti: la gestione separata (non oscilla) accanto ai fondi della linea. nil = come prima.
    /// `quota` (0–1) è la parte del capitale e delle rate che va in gestione separata; `accreditato` il suo
    /// rendimento annuo (%, già al netto del trattenuto e con il pavimento se consolidato); con
    /// `ribilanciamento` a ogni anno intero le due parti tornano alla quota.
    struct Gestione {
        var quota: Double
        var accreditato: Double
        var ribilanciamento: Bool
    }
    var gestione: Gestione? = nil

    init(nome: String, capitale: Double, rendimento: Double) {
        self.nome = nome
        self.capitale = capitale
        self.rendimento = rendimento
    }
}

/// Il risultato degli scenari con le probabilità.
struct EsitoMonteCarlo {
    /// I percentili del valore (lordo delle imposte finali) a fine anno, per il grafico a ventaglio.
    struct Anno: Identifiable {
        let anno: Int
        let p10: Double
        let p50: Double
        let p90: Double
        var id: Int { anno }
    }

    let traiettorie: Int
    let seme: UInt64
    let mesi: Int
    /// L'importo da raggiungere alla scadenza, in euro di allora.
    let traguardo: Double
    /// Quota degli scenari (0–1) in cui il capitale finale netto raggiunge il traguardo.
    let probabilita: Double
    /// Capitale finale al netto delle imposte: scenario sfavorevole (1 su 10 va peggio), mediano, favorevole.
    let p10: Double
    let p50: Double
    let p90: Double
    /// Media dei capitali finali netti.
    let media: Double
    /// Dall'anno 0 (oggi) alla scadenza (l'ultimo può essere un anno incompleto).
    let anni: [Anno]

    /// «7 su 10»: la probabilità arrotondata a decimi.
    var suDieci: Int { Int((probabilita * 10).rounded()) }
}

/// Scenari con le probabilità (Monte Carlo leggero e deterministico): migliaia di percorsi possibili dei
/// mercati, anno per anno, con rendimenti lognormali di media e volatilità date. Un unico fattore di mercato
/// comune a tutte le posizioni (correlazione piena: prudente, nessun beneficio di diversificazione).
/// È pesante rispetto ai calcoli delle schede: NON va chiamato dentro `MotoreObiettivo.calcola` né negli
/// spunti di Eve, ma solo quando si apre l'obiettivo o si prepara il prospetto (con una cache).
enum MotoreMonteCarlo {
    static let traiettoriePredefinite = 1_000
    static let massimoTraiettorie = 2_000
    /// Volatilità annua per indicatore di rischio SRI (1–7). Le classi di volatilità del rischio di mercato
    /// dei KID (Regolamento delegato UE 2017/653, allegato II) sono: 1 sotto 0,5%; 2 0,5–5%; 3 5–12%;
    /// 4 12–20%; 5 20–30%; 6 30–80%; 7 oltre 80%. Si usano valori centrali per le classi 2–5, l'estremo alto
    /// per la 1 e valori bassi della classe per 6 e 7 (classi molto ampie, i fondi reali stanno in basso).
    static let volatilitaPerSRI: [Int: Double] = [1: 0.5, 2: 3, 3: 8.5, 4: 16, 5: 25, 6: 35, 7: 50]
    /// Volatilità annua per classe, quando la posizione indica la quota azionaria ma non l'SRI: azioni
    /// mondiali in euro circa 15–16% (MSCI World EUR, lungo periodo), obbligazioni in euro circa 4–6%.
    static let volatilitaAzioni = 16.0
    static let volatilitaObbligazioni = 5.0

    /// La volatilità di una posizione: quella indicata, altrimenti dall'SRI, altrimenti dalla composizione,
    /// altrimenti dall'SRI probabile dell'area; sempre solo sulla parte esposta ai mercati (gestioni separate
    /// e conti: zero). Multiramo a due parti: la volatilità della combinazione (quota fondi × volatilità dei
    /// fondi), solo per le schede: la linea del Monte Carlo usa quella dei fondi.
    static func volatilita(_ p: Posizione) -> Double {
        if p.multiramoDivisa { return p.volatilitaComposta }
        if let v = p.volatilita { return max(0, v) }
        let esposta = MotoreResistenza.quotaARischio(p)
        guard esposta > 0 else { return 0 }
        if let sri = p.sri { return (volatilitaPerSRI[min(max(sri, 1), 7)] ?? 0) * esposta }
        if p.quotaAzionaria != nil, let c = MotoreResistenza.composizione(p) {
            return c.azioni * volatilitaAzioni + (c.governativi + c.societarie) * volatilitaObbligazioni
        }
        return (volatilitaPerSRI[MotoreResistenza.sriProbabile(p.area)] ?? 0) * esposta
    }

    /// Quanti versamenti cadono in `mesi` mesi (il primo subito), come in `MotoreProiezione`.
    static func numeroVersamenti(frequenza: Frequenza, mesi: Int) -> Int {
        guard frequenza.volteAllAnno > 0, mesi > 0 else { return 0 }
        let ogni = 12 / frequenza.volteAllAnno
        return (mesi + ogni - 1) / ogni
    }

    /// Una posizione collegata, con le stesse ipotesi di `MotoreObiettivo.calcola`: rendimento atteso
    /// (o quello dell'obiettivo), costi con il bollo, garanzia del Ramo I, imposte per regime.
    /// Multiramo a due parti: la linea sono i fondi (rendimento, costi e bollo, volatilità dei fondi) con
    /// accanto la gestione separata al suo accreditato; un'imposta sola sul contratto, con l'aliquota pesata.
    static func linea(_ p: Posizione, rendimentoPredefinito: Double, mesi: Int, data: Date) -> LineaMonteCarlo {
        var l = LineaMonteCarlo(nome: p.nome, capitale: p.valore, rendimento: p.rendimentoAtteso ?? rendimentoPredefinito)
        l.versamento = p.premio
        l.frequenza = p.frequenza
        l.costoIngresso = p.costoIngresso ?? 0
        l.costoAnnuo = (p.costoComplessivo ?? 0) + (p.regime != .deposito ? RegoleFiscali.bollo * p.quotaBollo : 0)
        l.capitaleGarantito = p.gestioneSeparata
        l.volatilita = volatilita(p)
        if p.multiramoDivisa {
            l.rendimento = p.lordoFondi(predefinito: rendimentoPredefinito)
            l.costoAnnuo = p.costoParteFondi + p.bolloFondi
            l.volatilita = p.volatilitaParteFondi
            l.capitaleGarantito = false
            // Senza consolidamento l'accreditato non ha pavimento; la garanzia a scadenza non entra (prudente)
            l.gestione = LineaMonteCarlo.Gestione(
                quota: p.parteGestione,
                accreditato: p.accreditatoGestione(lordo: p.lordoGestione(predefinito: rendimentoPredefinito)),
                ribilanciamento: p.ribilanciamento == true)
        }
        let versamenti = p.premio > 0 ? p.premio * Double(numeroVersamenti(frequenza: p.frequenza, mesi: mesi)) : 0
        let base = (p.totaleVersato ?? p.versamentoIniziale) + versamenti
        switch p.regime {
        case .polizza, .fondo:
            l.imposta = .guadagno(aliquota: MotoreFiscale.aliquotaGuadagno(p), base: base)
        case .deposito:
            l.imposta = .guadagno(aliquota: RegoleFiscali.ordinaria, base: p.valore + versamenti)
        case .previdenza:
            l.tassazioneAnnua = RegoleFiscali.aliquotaRendimentiPrevidenza(quotaTitoliStato: p.quotaTitoliStato)
            let anni = MotoreFiscale.anniPartecipazione(p, data: data) + mesi / 12
            l.imposta = .versato(aliquota: RegoleFiscali.aliquotaPrevidenza(anni: anni), base: base, nonDedotti: p.contributiNonDedotti ?? 0)
        case .esente:
            l.imposta = .nessuna
        }
        return l
    }

    /// Un seme stabile ricavato da un testo (FNV-1a a 64 bit): `Hasher` cambia a ogni avvio, questo no.
    static func seme(_ testo: String) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for b in testo.utf8 {
            h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01B3
        }
        return h
    }

    /// La probabilità di raggiungere un obiettivo con le posizioni collegate e l'accantonato, con le stesse
    /// ipotesi del piano (`MotoreObiettivo.calcola`): con volatilità zero il capitale mediano coincide con
    /// la sua proiezione. L'accantonato non investito non oscilla.
    static func obiettivo(_ o: Obiettivo, posizioni: [Posizione], data: Date = Date(),
                          traiettorie: Int = traiettoriePredefinite, seme: UInt64? = nil) -> EsitoMonteCarlo {
        let mesi = max(0, Calendar.current.dateComponents([.month], from: data, to: o.scadenza).month ?? 0)
        let traguardo = o.importo * pow(1 + IpotesiCalcolo.inflazione / 100, Double(mesi) / 12)
        let collegate = posizioni.filter { o.posizioniCollegate.contains($0.id) && $0.stato == .inEssere }
        var linee = collegate.map { linea($0, rendimentoPredefinito: o.rendimento, mesi: mesi, data: data) }
        if o.accantonato != 0 {
            linee.append(LineaMonteCarlo(nome: "Accantonato", capitale: o.accantonato, rendimento: o.rendimento))
        }
        return simula(linee, mesi: mesi, traguardo: traguardo, traiettorie: traiettorie, seme: seme ?? self.seme(o.id))
    }

    /// Il cuore: `traiettorie` percorsi a passi annuali (l'ultimo può durare meno di 12 mesi). In ogni anno
    /// un'estrazione normale z comune a tutte le linee; per ogni linea il fattore del periodo è
    /// exp(μ·f + σ·√f·z), con μ = ln(1 + r) − σ²/2 (così il rendimento MEDIO è r e la mediana è più bassa)
    /// e f la frazione d'anno. Dentro l'anno si va mese per mese con il fattore mensile costante, i costi,
    /// la garanzia e l'imposta annua esattamente come `MotoreProiezione`; alla fine l'imposta per regime.
    /// Le linee con la gestione separata (multiramo a due parti) tengono due saldi: la gestione separata cresce
    /// del suo accreditato senza oscillare, i fondi seguono il mercato; a fine passo di 12 mesi, con il
    /// ribilanciamento, tornano alla quota; l'imposta finale è una sola, sulla somma.
    static func simula(_ linee: [LineaMonteCarlo], mesi: Int, traguardo: Double,
                       traiettorie: Int = traiettoriePredefinite, seme: UInt64) -> EsitoMonteCarlo {
        let n = min(max(traiettorie, 1), massimoTraiettorie)
        let mesiTotali = max(0, mesi)
        let passi = (mesiTotali + 11) / 12
        let k = linee.count

        // Parametri fissi di ogni linea, calcolati una volta
        var mu = [Double](repeating: 0, count: k)
        var sigma = [Double](repeating: 0, count: k)
        var costoMensile = [Double](repeating: 0, count: k)
        var rata = [Double](repeating: 0, count: k)
        var ogniMesi = [Int](repeating: 0, count: k)
        // Gestione separata delle multiramo a due parti: quota (0 = nessuna) e fattore mensile
        var quotaG = [Double](repeating: 0, count: k)
        var fattoreG = [Double](repeating: 1, count: k)
        for i in 0..<k {
            let l = linee[i]
            if let g = l.gestione {
                quotaG[i] = min(max(g.quota, 0), 1)
                fattoreG[i] = pow(max(1 + g.accreditato / 100, 0.01), 1.0 / 12)
            }
            let s = max(0, l.volatilita) / 100
            sigma[i] = s
            mu[i] = log(max(1 + l.rendimento / 100, 0.01)) - s * s / 2
            costoMensile[i] = log(1 - min(max(l.costoAnnuo, 0), 99) / 100) / 12
            rata[i] = l.versamento * (1 - min(max(l.costoIngresso, 0), 99) / 100)
            ogniMesi[i] = l.frequenza.volteAllAnno > 0 && l.versamento > 0 ? 12 / l.frequenza.volteAllAnno : 0
        }

        // serie[passo * n + t]: valore lordo complessivo a fine passo, per ogni traiettoria
        var serie = [Double](repeating: 0, count: (passi + 1) * n)
        var finali = [Double](repeating: 0, count: n)
        var valori = [Double](repeating: 0, count: k)
        var valoriG = [Double](repeating: 0, count: k)
        var generatore = GeneratoreSeme(seme: seme)
        let partenza = linee.reduce(0) { $0 + $1.capitale }

        for t in 0..<n {
            for i in 0..<k {
                if quotaG[i] > 0 {
                    valoriG[i] = linee[i].capitale * quotaG[i]
                    valori[i] = linee[i].capitale * (1 - quotaG[i])
                } else {
                    valoriG[i] = 0
                    valori[i] = linee[i].capitale
                }
            }
            serie[t] = partenza
            for passo in 0..<passi {
                let mesiPasso = min(12, mesiTotali - passo * 12)
                let frazione = Double(mesiPasso) / 12
                let radice = frazione.squareRoot()
                let z = generatore.normale()
                var totale = 0.0
                for i in 0..<k {
                    let periodo = mu[i] * frazione + sigma[i] * radice * z
                    var m = exp(periodo / Double(mesiPasso) + costoMensile[i])
                    // Ramo I: il rendimento accreditato non è mai negativo
                    if linee[i].capitaleGarantito, m < 1 { m = 1 }
                    // Fondi pensione: imposta sul risultato positivo, man mano
                    let tassa = linee[i].tassazioneAnnua
                    if tassa > 0, m > 1 { m = 1 + (m - 1) * (1 - tassa / 100) }
                    var v = valori[i]
                    let ogni = ogniMesi[i]
                    let q = quotaG[i]
                    if q > 0 {
                        // Multiramo a due parti: la gestione separata non oscilla, i fondi sì
                        var vG = valoriG[i]
                        let mG = fattoreG[i]
                        for mese in 0..<mesiPasso {
                            if ogni > 0, mese % ogni == 0 {
                                vG += rata[i] * q
                                v += rata[i] * (1 - q)
                            }
                            vG *= mG
                            v *= m
                        }
                        // Ribilanciamento solo a fine anno intero (non nell'ultimo passo incompleto)
                        if mesiPasso == 12, linee[i].gestione?.ribilanciamento == true {
                            let somma = vG + v
                            vG = q * somma
                            v = (1 - q) * somma
                        }
                        valoriG[i] = vG
                        valori[i] = v
                        totale += vG + v
                    } else {
                        for mese in 0..<mesiPasso {
                            if ogni > 0, mese % ogni == 0 { v += rata[i] }
                            v *= m
                        }
                        valori[i] = v
                        totale += v
                    }
                }
                serie[(passo + 1) * n + t] = totale
            }
            var netto = 0.0
            // Un'imposta sola per linea, sulla somma delle due parti delle multiramo
            for i in 0..<k { netto += linee[i].imposta.netto(valori[i] + valoriG[i]) }
            finali[t] = netto
        }

        var anni: [EsitoMonteCarlo.Anno] = []
        anni.reserveCapacity(passi + 1)
        for passo in 0...passi {
            let ordinati = serie[(passo * n)..<((passo + 1) * n)].sorted()
            anni.append(EsitoMonteCarlo.Anno(anno: passo, p10: percentile(ordinati, 0.1), p50: percentile(ordinati, 0.5),
                                             p90: percentile(ordinati, 0.9)))
        }
        let ordinati = finali.sorted()
        let riusciti = finali.filter { $0 >= traguardo }.count
        return EsitoMonteCarlo(traiettorie: n, seme: seme, mesi: mesiTotali, traguardo: traguardo,
                               probabilita: Double(riusciti) / Double(n),
                               p10: percentile(ordinati, 0.1), p50: percentile(ordinati, 0.5), p90: percentile(ordinati, 0.9),
                               media: finali.reduce(0, +) / Double(n), anni: anni)
    }

    /// Percentile `q` (0–1) di valori già ordinati, con interpolazione lineare tra i due vicini.
    static func percentile(_ ordinati: [Double], _ q: Double) -> Double {
        guard let primo = ordinati.first else { return 0 }
        guard ordinati.count > 1 else { return primo }
        let x = min(max(q, 0), 1) * Double(ordinati.count - 1)
        let i = Int(x.rounded(.down))
        let j = min(i + 1, ordinati.count - 1)
        return ordinati[i] + (ordinati[j] - ordinati[i]) * (x - Double(i))
    }

    /// Il metodo, per il prospetto dell'obiettivo e le schermate.
    static var metodo: [String] {
        let sri = volatilitaPerSRI.sorted { $0.key < $1.key }.map { "SRI \($0.key) \(CifreDoc.percento($0.value))" }.joined(separator: ", ")
        return [
            "Scenari con le probabilità: \(traiettoriePredefinite) percorsi possibili dei mercati, anno per anno, con rendimenti lognormali. La media dei rendimenti è il rendimento atteso di ogni posizione (o quello dell'obiettivo); la volatilità è quella indicata o si ricava dall'SRI del KID (\(sri)), dalla quota azionaria (azioni \(CifreDoc.percento(volatilitaAzioni, decimali: 0)), obbligazioni \(CifreDoc.percento(volatilitaObbligazioni, decimali: 0))) o dall'area; gestioni separate, conti e accantonato non oscillano. Multiramo: la parte in gestione separata non oscilla, i fondi sì, con la loro volatilità; un'imposta sola sul contratto, con l'aliquota pesata sulle quote di oggi; la garanzia a scadenza della gestione separata non entra (stima prudente).",
            "Un unico andamento dei mercati vale per tutte le posizioni (nessun beneficio dalla diversificazione: stima prudente). Versamenti, costi, imposte e inflazione come nel piano dell'obiettivo; seme fisso, quindi lo stesso risultato a ogni apertura.",
            "È una stima statistica su ipotesi, non una previsione: dice in quanti casi su dieci l'obiettivo si raggiunge se i mercati si comportano come in passato.",
        ]
    }
}
