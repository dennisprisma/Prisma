import Foundation

/// Ipotesi generali dei calcoli (modificabili in futuro dalle Impostazioni).
enum IpotesiCalcolo {
    /// Inflazione annua usata per riportare i valori in euro di oggi.
    static let inflazione = 2.0
    /// Orizzonte proposto quando la posizione non ha scadenza e il cliente non ha un orizzonte.
    static let orizzontePredefinito = 10
    /// Rendimento proposto quando la posizione non indica un rendimento atteso.
    static let rendimentoPredefinito = 3.0
    /// Aliquota sulle plusvalenze quando non è indicata (redditi di natura finanziaria).
    static let aliquotaPredefinita = 26.0
    /// Ampiezza degli scenari prudente e favorevole attorno al rendimento atteso.
    static let ampiezzaScenari = 2.0
    /// Ampiezza degli scenari per la gestione separata di una multiramo: si muove molto meno dei mercati.
    static let ampiezzaScenariGestione = 1.0
}

/// La parte in gestione separata di una multiramo a due parti (dalla versione 20). La proiezione tiene due
/// saldi: questa parte e i fondi, che usano `rendimento` e `costoAnnuo` della proiezione.
struct ParteGestioneProiezione: Equatable {
    /// Quota (0–1) del capitale iniziale e dei versamenti netti che va in gestione separata; quota del ribilanciamento.
    var quota: Double
    /// Rendimento lordo della gestione (% annuo).
    var lordo: Double
    var trattenuto: Double?
    var retrocessione: Double?
    var minimoGarantito: Double?
    /// true: l'accreditato non scende mai sotto il minimo (o sotto zero); false: garanzia solo a `mesiGaranzia`.
    var consolidamento: Bool
    var mesiGaranzia: Int?
    /// Aliquota sul guadagno della parte (%): l'imposta finale usa la media pesata sui valori finali.
    var aliquota: Double
    /// Ribilanciamento a ogni anno della proiezione verso `quota`.
    var ribilanciamento = false

    /// Rendimento accreditato ogni anno (%), con il pavimento al minimo garantito se consolidato.
    var accreditato: Double {
        MotoreGestioneSeparata.accreditato(lordo: lordo, trattenuto: trattenuto, retrocessione: retrocessione,
                                           minimo: minimoGarantito, consolidamento: consolidamento)
    }
}

/// Dati di ingresso di una proiezione. Le percentuali sono annue (3 = 3%).
struct ParametriProiezione: Equatable {
    var capitaleIniziale: Double
    var versamento: Double
    var frequenza: Frequenza
    var anni: Int
    var rendimento: Double
    var costoIngresso: Double = 0
    var costoAnnuo: Double = 0
    var aliquotaFiscale: Double = IpotesiCalcolo.aliquotaPredefinita
    var inflazione: Double = IpotesiCalcolo.inflazione

    /// Parametri ricavati da una posizione, con le ipotesi predefinite dove mancano dati.
    init(posizione p: Posizione, orizzonteCliente: Int? = nil) {
        // Per una posizione in essere si parte dal valore attuale, per una proposta dal versamento iniziale.
        let inEssere = p.stato == .inEssere
        capitaleIniziale = inEssere ? p.valore : p.versamentoIniziale
        // Il guadagno già maturato si tassa anche lui: il versato parte da quanto versato davvero
        versatoIniziale = inEssere ? (p.totaleVersato ?? p.valore) : nil
        versamento = p.premio
        frequenza = p.frequenza
        anni = p.anniAllaScadenza ?? orizzonteCliente ?? IpotesiCalcolo.orizzontePredefinito
        rendimento = p.rendimentoAtteso ?? IpotesiCalcolo.rendimentoPredefinito
        // Il costo d'ingresso si applica solo ai versamenti futuri di una posizione in essere.
        costoIngresso = p.costoIngresso ?? 0
        // Il trattenuto sul rendimento pesa come un costo annuo (con la retrocessione: la parte non retrocessa)
        costoAnnuo = (p.costoAnnuo ?? 0) + MotoreGestioneSeparata.trattenuto(p)
        ingressoSulCapitale = !inEssere
        // Le imposte secondo il regime, come nel resto di Prisma (MotoreFiscale)
        switch p.regime {
        case .polizza, .fondo:
            aliquotaFiscale = MotoreFiscale.aliquotaGuadagno(p)
            // Il bollo dello 0,20% l'anno pesa sul valore come un costo
            costoAnnuo += RegoleFiscali.bollo * p.quotaBollo
        case .deposito:
            // Gli interessi si tassano quando vengono accreditati
            aliquotaFiscale = 0
            tassazioneAnnua = p.aliquotaFiscale ?? RegoleFiscali.ordinaria
        case .previdenza:
            // Rendimenti tassati ogni anno nel fondo; alla prestazione si tassano i contributi dedotti
            aliquotaFiscale = 0
            // (12,5% sulla parte in titoli di Stato, se indicata: come nel piano previdenziale)
            tassazioneAnnua = RegoleFiscali.aliquotaRendimentiPrevidenza(quotaTitoliStato: p.quotaTitoliStato)
            aliquotaSulVersato = RegoleFiscali.aliquotaPrevidenza(anni: (inEssere ? MotoreFiscale.anniPartecipazione(p) : 0) + anni)
            nonDedotti = p.contributiNonDedotti ?? 0
        case .esente:
            aliquotaFiscale = 0
        }
        capitaleGarantito = p.gestioneSeparata
        if p.gestioneSeparata {
            // Gestione separata: minimo garantito e consolidamento dei rendimenti (senza dati: come prima,
            // il capitale non scende mai); senza consolidamento la garanzia vale solo alla scadenza
            minimoGarantito = p.minimoGarantito
            consolidamento = p.consolidamento ?? true
            if !consolidamento { mesiGaranzia = p.anniAllaScadenza.map { $0 * 12 } }
        }
        if p.multiramoDivisa {
            // Multiramo a due parti: i campi di sempre descrivono i fondi, la gestione separata va in `gestione`
            rendimento = p.lordoFondi()
            costoAnnuo = p.costoParteFondi + p.bolloFondi          // bollo solo sui fondi
            aliquotaFiscale = p.aliquotaFondi
            capitaleGarantito = false; minimoGarantito = nil; consolidamento = true; mesiGaranzia = nil
            let consolidato = p.consolidamento ?? true
            gestione = ParteGestioneProiezione(
                quota: p.parteGestione, lordo: p.lordoGestione(), trattenuto: p.trattenuto,
                retrocessione: p.retrocessione, minimoGarantito: p.minimoGarantito, consolidamento: consolidato,
                mesiGaranzia: consolidato ? nil : p.anniAllaScadenza.map { $0 * 12 },
                aliquota: p.aliquotaGestione, ribilanciamento: p.ribilanciamento == true)
        }
    }

    init(capitaleIniziale: Double, versamento: Double, frequenza: Frequenza, anni: Int, rendimento: Double,
         costoIngresso: Double = 0, costoAnnuo: Double = 0, aliquotaFiscale: Double = IpotesiCalcolo.aliquotaPredefinita,
         inflazione: Double = IpotesiCalcolo.inflazione, ingressoSulCapitale: Bool = true) {
        self.capitaleIniziale = capitaleIniziale
        self.versamento = versamento
        self.frequenza = frequenza
        self.anni = anni
        self.rendimento = rendimento
        self.costoIngresso = costoIngresso
        self.costoAnnuo = costoAnnuo
        self.aliquotaFiscale = aliquotaFiscale
        self.inflazione = inflazione
        self.ingressoSulCapitale = ingressoSulCapitale
    }

    /// Se il costo d'ingresso si applica anche al capitale iniziale (sì per le proposte).
    var ingressoSulCapitale = true
    /// Quanto è stato versato finora, se diverso dal capitale di partenza (posizioni in essere).
    var versatoIniziale: Double? = nil
    /// Aliquota sui rendimenti tassati man mano (depositi, fondi pensione), invece che alla fine.
    var tassazioneAnnua: Double = 0
    /// Previdenza: aliquota della prestazione sui contributi dedotti, e i contributi non dedotti.
    var aliquotaSulVersato: Double = 0
    var nonDedotti: Double = 0
    /// Ramo I: la gestione separata non accredita rendimenti negativi, il capitale non scende.
    var capitaleGarantito = false
    /// Gestione separata: rendimento minimo garantito annuo (%) accreditato anche quando il rendimento netto
    /// è più basso; nil = solo il capitale (come prima).
    var minimoGarantito: Double? = nil
    /// Gestione separata: true = rendimenti consolidati, il valore non scende mai (più il minimo garantito);
    /// false = garanzia solo alla scadenza (`mesiGaranzia`), il valore può scendere prima.
    var consolidamento = true
    /// Mesi dall'inizio della proiezione alla scadenza, dove vale la garanzia senza consolidamento.
    var mesiGaranzia: Int? = nil
    /// Durata esatta in mesi, quando non è un numero intero di anni (obiettivi): prevale su `anni`.
    var mesiEsatti: Int? = nil
    /// Multiramo a due parti: la parte in gestione separata (i campi qui sopra descrivono i fondi).
    /// nil = un comparto solo, come prima.
    var gestione: ParteGestioneProiezione? = nil

    /// La stessa proiezione con una durata in mesi.
    func perMesi(_ mesi: Int) -> ParametriProiezione {
        var q = self
        q.mesiEsatti = max(0, mesi)
        q.anni = max(1, Int((Double(mesi) / 12).rounded(.up)))
        return q
    }

    /// Lo scenario con uno scarto di `s` punti sul rendimento: tutto sui fondi, e sulla gestione separata di
    /// una multiramo lo scarto ridotto (`ampiezzaScenariGestione` su `ampiezzaScenari`, oggi la metà).
    func conScarto(_ s: Double) -> ParametriProiezione {
        var q = self
        q.rendimento += s
        q.gestione?.lordo += s * IpotesiCalcolo.ampiezzaScenariGestione / IpotesiCalcolo.ampiezzaScenari
        return q
    }

    /// Rendimento lordo e costo annuo equivalenti di un comparto unico (pesati sulle quote): per testi,
    /// simulatore e Analisi 360. Senza gestione sono `rendimento` e `costoAnnuo`.
    var rendimentoEquivalente: Double { gestione.map { $0.quota * $0.lordo + (1 - $0.quota) * rendimento } ?? rendimento }
    var costoAnnuoEquivalente: Double {
        gestione.map { $0.quota * max(0, $0.lordo - $0.accreditato) + (1 - $0.quota) * costoAnnuo } ?? costoAnnuo
    }
    /// Aliquota equivalente sulle quote iniziali: per le etichette («Imposta sulle plusvalenze», confronti).
    /// Nel modo a due parti `aliquotaFiscale` è quella dei soli fondi e non va mostrata.
    var aliquotaEquivalente: Double {
        gestione.map { $0.quota * $0.aliquota + (1 - $0.quota) * aliquotaFiscale } ?? aliquotaFiscale
    }
}

struct PuntoProiezione: Equatable {
    let anno: Int
    let versato: Double
    let valore: Double
    /// Multiramo a due parti: di cui in gestione separata. nil = un comparto solo.
    var valoreGestione: Double? = nil
}

/// Risultato di una proiezione: tutti gli importi in euro, arrotondati solo in visualizzazione.
struct EsitoProiezione: Equatable {
    let punti: [PuntoProiezione]
    /// Capitale iniziale più tutti i versamenti.
    let versato: Double
    /// Costi d'ingresso più costi annui sottratti nel periodo.
    let costi: Double
    /// Valore finale prima delle imposte.
    let lordo: Double
    let imposte: Double
    let netto: Double
    /// Valore netto in euro di oggi (al netto dell'inflazione).
    let reale: Double

    var guadagnoNetto: Double { netto - versato }
}

/// Motore di proiezione mese per mese.
///
/// Per ogni mese: si aggiunge l'eventuale versamento (al netto del costo d'ingresso),
/// il capitale cresce del rendimento mensile equivalente e paga il costo annuo pro quota.
/// A fine periodo: imposte sulla plusvalenza (valore − versato, se positiva), poi
/// attualizzazione all'inflazione. È lo stesso schema del template (advice-math).
enum MotoreProiezione {
    static func calcola(_ p: ParametriProiezione) -> EsitoProiezione {
        if let g = p.gestione { return calcolaDueParti(p, g) }
        let mesi = p.mesiEsatti ?? max(0, p.anni) * 12
        let crescita = pow(1 + p.rendimento / 100, 1.0 / 12)
        let mantenimento = pow(1 - min(max(p.costoAnnuo, 0), 99) / 100, 1.0 / 12)
        let ingresso = min(max(p.costoIngresso, 0), 99) / 100
        let ogniMesi = p.frequenza.volteAllAnno > 0 ? 12 / p.frequenza.volteAllAnno : 0

        var costi = p.ingressoSulCapitale ? p.capitaleIniziale * ingresso : 0
        var saldo = p.capitaleIniziale - costi
        var versato = p.versatoIniziale ?? p.capitaleIniziale
        var imposteMaturate = 0.0
        // Gestione separata: crescita mensile del minimo garantito e capitale garantito alla scadenza
        // (versamenti al netto dell'ingresso, rivalutati al minimo), per la garanzia senza consolidamento
        let minimoMensile = pow(1 + max(0, p.minimoGarantito ?? 0) / 100, 1.0 / 12)
        var garantito = (p.versatoIniziale ?? p.capitaleIniziale) * (1 - ingresso)
        var punti = [PuntoProiezione(anno: 0, versato: versato, valore: saldo)]

        for mese in 0..<mesi {
            if ogniMesi > 0, p.versamento > 0, mese % ogniMesi == 0 {
                versato += p.versamento
                costi += p.versamento * ingresso
                saldo += p.versamento * (1 - ingresso)
                garantito += p.versamento * (1 - ingresso)
            }
            let prima = saldo
            saldo *= crescita
            var dopoCosti = saldo * mantenimento
            garantito *= minimoMensile
            if p.capitaleGarantito {
                if p.consolidamento {
                    // Ramo I: il rendimento accreditato non è mai negativo (né sotto il minimo garantito)
                    dopoCosti = max(dopoCosti, prima * minimoMensile)
                } else if let g = p.mesiGaranzia, mese + 1 == g {
                    // Senza consolidamento: alla scadenza almeno i versamenti netti rivalutati al minimo
                    dopoCosti = max(dopoCosti, garantito)
                }
            }
            costi += max(0, saldo - dopoCosti)
            saldo = dopoCosti
            // Depositi e fondi pensione: imposta sul risultato del periodo, al netto dei costi
            if p.tassazioneAnnua > 0, saldo > prima {
                let imposta = (saldo - prima) * p.tassazioneAnnua / 100
                imposteMaturate += imposta
                saldo -= imposta
            }
            if (mese + 1) % 12 == 0 {
                punti.append(PuntoProiezione(anno: (mese + 1) / 12, versato: versato, valore: saldo))
            } else if mese == mesi - 1 {
                // Ultimo anno incompleto: il punto finale c'è comunque
                punti.append(PuntoProiezione(anno: mesi / 12 + 1, versato: versato, valore: saldo))
            }
        }

        // Alla fine: imposta sul guadagno (polizze, fondi) o sui contributi dedotti (previdenza)
        let impostaFinale = max(0, saldo - versato) * max(0, p.aliquotaFiscale) / 100
            + max(0, min(saldo, versato - p.nonDedotti)) * max(0, p.aliquotaSulVersato) / 100
        let imposte = imposteMaturate + impostaFinale
        let netto = saldo - impostaFinale
        let reale = netto / pow(1 + p.inflazione / 100, p.mesiEsatti.map { Double($0) / 12 } ?? Double(max(0, p.anni)))
        return EsitoProiezione(punti: punti, versato: versato, costi: costi, lordo: saldo,
                               imposte: imposte, netto: netto, reale: reale)
    }

    /// Multiramo a due parti: due saldi mese per mese. La gestione separata si rivaluta dell'accreditato
    /// (lordo meno trattenuto, con il pavimento se consolidato; senza consolidamento la garanzia vale solo a
    /// `mesiGaranzia`); i fondi crescono del rendimento e pagano costi e bollo come la proiezione di sempre,
    /// senza garanzia. Con il ribilanciamento a ogni fine anno si torna alla quota. Un'imposta sola sul
    /// guadagno del contratto, con l'aliquota pesata sui valori finali delle due parti.
    private static func calcolaDueParti(_ p: ParametriProiezione, _ g: ParteGestioneProiezione) -> EsitoProiezione {
        let mesi = p.mesiEsatti ?? max(0, p.anni) * 12
        let crescitaG = pow(1 + g.accreditato / 100, 1.0 / 12)
        let lordoG = pow(1 + g.lordo / 100, 1.0 / 12)
        let crescitaF = pow(1 + p.rendimento / 100, 1.0 / 12)
        let mantenimentoF = pow(1 - min(max(p.costoAnnuo, 0), 99) / 100, 1.0 / 12)
        let minimoMensile = pow(1 + max(0, g.minimoGarantito ?? 0) / 100, 1.0 / 12)
        let ingresso = min(max(p.costoIngresso, 0), 99) / 100
        let q = min(max(g.quota, 0), 1)
        let ogniMesi = p.frequenza.volteAllAnno > 0 ? 12 / p.frequenza.volteAllAnno : 0

        var costi = p.ingressoSulCapitale ? p.capitaleIniziale * ingresso : 0
        let netto0 = p.capitaleIniziale - costi
        var saldoG = q * netto0
        var saldoF = (1 - q) * netto0
        var versato = p.versatoIniziale ?? p.capitaleIniziale
        // Come il garantito del Ramo I, sulla sola parte: per una posizione in essere è una stima (q è la quota
        // del valore di oggi, non quella dei premi entrati in gestione separata)
        var garantitoG = q * (p.versatoIniziale ?? p.capitaleIniziale) * (1 - ingresso)
        var punti = [PuntoProiezione(anno: 0, versato: versato, valore: saldoG + saldoF, valoreGestione: saldoG)]

        for mese in 0..<mesi {
            if ogniMesi > 0, p.versamento > 0, mese % ogniMesi == 0 {
                versato += p.versamento
                costi += p.versamento * ingresso
                saldoG += q * p.versamento * (1 - ingresso)
                saldoF += (1 - q) * p.versamento * (1 - ingresso)
                garantitoG += q * p.versamento * (1 - ingresso)
            }
            // Gestione separata: il trattenuto in euro è la differenza dal lordo della gestione
            let primaG = saldoG
            saldoG *= crescitaG
            costi += max(0, primaG * lordoG - saldoG)
            garantitoG *= minimoMensile
            if !g.consolidamento, let m = g.mesiGaranzia, mese + 1 == m { saldoG = max(saldoG, garantitoG) }
            // Fondi: come la proiezione di sempre, senza garanzia
            let cresciuto = saldoF * crescitaF
            let dopoCosti = cresciuto * mantenimentoF
            costi += max(0, cresciuto - dopoCosti)
            saldoF = dopoCosti
            if (mese + 1) % 12 == 0 {
                if g.ribilanciamento {
                    // Ciò che esce dalla gestione separata porta via la sua garanzia
                    let totale = saldoG + saldoF
                    if saldoG > 0 { garantitoG *= q * totale / saldoG }
                    saldoG = q * totale
                    saldoF = (1 - q) * totale
                }
                punti.append(PuntoProiezione(anno: (mese + 1) / 12, versato: versato, valore: saldoG + saldoF, valoreGestione: saldoG))
            } else if mese == mesi - 1 {
                // Ultimo anno incompleto: il punto finale c'è comunque
                punti.append(PuntoProiezione(anno: mesi / 12 + 1, versato: versato, valore: saldoG + saldoF, valoreGestione: saldoG))
            }
        }

        // Un'imposta sola sul contratto: GS e fondi si compensano, aliquota pesata sui valori finali
        let saldo = saldoG + saldoF
        let aliquota = saldo > 0 ? (saldoG * g.aliquota + saldoF * p.aliquotaFiscale) / saldo : p.aliquotaFiscale
        let impostaFinale = max(0, saldo - versato) * max(0, aliquota) / 100
        let netto = saldo - impostaFinale
        let reale = netto / pow(1 + p.inflazione / 100, p.mesiEsatti.map { Double($0) / 12 } ?? Double(max(0, p.anni)))
        return EsitoProiezione(punti: punti, versato: versato, costi: costi, lordo: saldo,
                               imposte: impostaFinale, netto: netto, reale: reale)
    }

    /// Tre scenari: prudente (−2 punti), atteso, favorevole (+2 punti). Per una multiramo a due parti la
    /// gestione separata si sposta di 1 punto e il rendimento della tupla è quello equivalente del contratto.
    static func scenari(_ p: ParametriProiezione) -> [(nome: String, rendimento: Double, esito: EsitoProiezione)] {
        let a = IpotesiCalcolo.ampiezzaScenari
        if p.gestione != nil {
            return [("Prudente", -a), ("Atteso", 0.0), ("Favorevole", a)].map { nome, s in
                let q = p.conScarto(s)
                return (nome, q.rendimentoEquivalente, calcola(q))
            }
        }
        return [("Prudente", p.rendimento - a), ("Atteso", p.rendimento), ("Favorevole", p.rendimento + a)].map { nome, r in
            var q = p
            q.rendimento = r
            return (nome, r, calcola(q))
        }
    }

    /// Quanto costano i costi: differenza tra il valore senza costi e quello con i costi.
    static func impattoCosti(_ p: ParametriProiezione) -> Double {
        var senza = p
        senza.costoIngresso = 0
        senza.costoAnnuo = 0
        // Multiramo a due parti: senza trattenuto la gestione separata rende il lordo
        senza.gestione?.trattenuto = nil
        senza.gestione?.retrocessione = nil
        return calcola(senza).netto - calcola(p).netto
    }
}
