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
        capitaleIniziale = p.stato == .inEssere ? p.valore : p.versamentoIniziale
        versamento = p.premio
        frequenza = p.frequenza
        anni = p.anniAllaScadenza ?? orizzonteCliente ?? IpotesiCalcolo.orizzontePredefinito
        rendimento = p.rendimentoAtteso ?? IpotesiCalcolo.rendimentoPredefinito
        // Il costo d'ingresso si applica solo ai versamenti futuri di una posizione in essere.
        costoIngresso = p.costoIngresso ?? 0
        costoAnnuo = p.costoAnnuo ?? 0
        aliquotaFiscale = p.aliquotaFiscale ?? IpotesiCalcolo.aliquotaPredefinita
        ingressoSulCapitale = p.stato != .inEssere
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
        let mesi = max(0, p.anni) * 12
        let crescita = pow(1 + p.rendimento / 100, 1.0 / 12)
        let mantenimento = pow(1 - min(max(p.costoAnnuo, 0), 99) / 100, 1.0 / 12)
        let ingresso = min(max(p.costoIngresso, 0), 99) / 100
        let ogniMesi = p.frequenza.volteAllAnno > 0 ? 12 / p.frequenza.volteAllAnno : 0

        var costi = p.ingressoSulCapitale ? p.capitaleIniziale * ingresso : 0
        var saldo = p.capitaleIniziale - costi
        var versato = p.capitaleIniziale
        var punti = [PuntoProiezione(anno: 0, versato: versato, valore: saldo)]

        for mese in 0..<mesi {
            if ogniMesi > 0, p.versamento > 0, mese % ogniMesi == 0 {
                versato += p.versamento
                costi += p.versamento * ingresso
                saldo += p.versamento * (1 - ingresso)
            }
            saldo *= crescita
            let dopoCosti = saldo * mantenimento
            costi += saldo - dopoCosti
            saldo = dopoCosti
            if (mese + 1) % 12 == 0 {
                punti.append(PuntoProiezione(anno: (mese + 1) / 12, versato: versato, valore: saldo))
            }
        }

        let imposte = max(0, saldo - versato) * max(0, p.aliquotaFiscale) / 100
        let netto = saldo - imposte
        let reale = netto / pow(1 + p.inflazione / 100, Double(max(0, p.anni)))
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
