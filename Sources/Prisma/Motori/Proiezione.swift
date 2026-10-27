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

    /// La stessa proiezione con una durata in mesi.
    func perMesi(_ mesi: Int) -> ParametriProiezione {
        var q = self
        q.mesiEsatti = max(0, mesi)
        q.anni = max(1, Int((Double(mesi) / 12).rounded(.up)))
        return q
    }
}

struct PuntoProiezione: Equatable {
    let anno: Int
    let versato: Double
    let valore: Double
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

    /// Tre scenari: prudente (−2 punti), atteso, favorevole (+2 punti).
    static func scenari(_ p: ParametriProiezione) -> [(nome: String, rendimento: Double, esito: EsitoProiezione)] {
        let a = IpotesiCalcolo.ampiezzaScenari
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
        return calcola(senza).netto - calcola(p).netto
    }
}
