import Foundation

/// Le ipotesi del confronto «TFR in azienda o nel fondo» di un cliente (dalla versione 24 dell'archivio).
/// Percentuali annue; importi in euro. Lettura tollerante con i limiti dei comandi della console del TFR.
/// Le ipotesi di partenza dai dati del cliente (`IpotesiTFR.dalCliente`) stanno nel motore (Motori/MotoreTFR.swift):
/// questo file resta solo dati.
struct IpotesiTFR: Codable, Equatable {
    /// Retribuzione lorda annua di oggi (RAL, €): la base del TFR.
    var retribuzione: Double = 30_000
    /// Crescita della retribuzione oltre l'inflazione (% l'anno).
    var crescitaReale: Double = 1
    /// Anni di lavoro da qui alla pensione: gli anni in cui il TFR matura (1–50).
    var anni: Int = 25
    /// Inflazione ipotizzata (% l'anno): rivaluta il TFR in azienda e la retribuzione.
    var inflazione: Double = IpotesiCalcolo.inflazione
    /// Rendimento lordo annuo del fondo (%), prima dei costi e dell'imposta del 20%.
    var rendimentoFondo: Double = RegoleTFR.rendimentoFondoPredefinito
    /// Costi annui del fondo (ISC, %).
    var costoFondo: Double = RegoleTFR.costoFondoPredefinito
    /// Quota del fondo in titoli di Stato (0–100), per il 12,5%; nil = 20% su tutto.
    var titoliStatoFondo: Double?
    /// Contributo del lavoratore e del datore di lavoro, in % della retribuzione (0 = nessuno).
    var contributoLavoratore: Double = 0
    var contributoDatore: Double = 0
    /// Anni già maturati nella previdenza complementare (per l'aliquota 15% → 9%).
    var anniPartecipazione: Int = 0
    /// Aliquota della tassazione separata del TFR indicata a mano (%); nil = calcolata da Prisma.
    var aliquotaTFR: Double?
    /// Quota della retribuzione accantonata ogni anno (%); nil = 100/13,5 − 0,5 (`RegoleTFR.quotaAnnua`).
    var quotaTFR: Double?
    /// Canale della consulenza (etichetta sullo schermo e sul PDF) e nome del fondo, se c'è.
    var canale: Canale = .indipendente
    var nomeFondo = ""

    /// Limiti dei comandi: un valore letto fuori limite si riporta al limite più vicino.
    enum Limiti {
        static let retribuzione: ClosedRange<Double> = 0...1_000_000
        static let crescitaReale: ClosedRange<Double> = -5...10
        static let anni: ClosedRange<Int> = 1...50
        static let inflazione: ClosedRange<Double> = -5...20
        static let rendimentoFondo: ClosedRange<Double> = -10...30
        static let costoFondo: ClosedRange<Double> = 0...5
        static let titoliStatoFondo: ClosedRange<Double> = 0...100
        static let contributo: ClosedRange<Double> = 0...50
        static let anniPartecipazione: ClosedRange<Int> = 0...60
        static let aliquotaTFR: ClosedRange<Double> = 0...50
        static let quotaTFR: ClosedRange<Double> = 0...10
    }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case retribuzione, crescitaReale, anni, inflazione, rendimentoFondo, costoFondo, titoliStatoFondo
        case contributoLavoratore, contributoDatore, anniPartecipazione, aliquotaTFR, quotaTFR, canale, nomeFondo
    }

    /// Lettura tollerante: un campo illeggibile prende il predefinito, uno fuori limite il limite più vicino.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let p = IpotesiTFR()
        retribuzione = Self.limita(try? c.decodeIfPresent(Double.self, forKey: .retribuzione),
                                   Limiti.retribuzione, altrimenti: p.retribuzione)
        crescitaReale = Self.limita(try? c.decodeIfPresent(Double.self, forKey: .crescitaReale),
                                    Limiti.crescitaReale, altrimenti: p.crescitaReale)
        let anniLetti = try? c.decodeIfPresent(Int.self, forKey: .anni)
        anni = anniLetti.map { min(max($0, Limiti.anni.lowerBound), Limiti.anni.upperBound) } ?? p.anni
        inflazione = Self.limita(try? c.decodeIfPresent(Double.self, forKey: .inflazione),
                                 Limiti.inflazione, altrimenti: p.inflazione)
        rendimentoFondo = Self.limita(try? c.decodeIfPresent(Double.self, forKey: .rendimentoFondo),
                                      Limiti.rendimentoFondo, altrimenti: p.rendimentoFondo)
        costoFondo = Self.limita(try? c.decodeIfPresent(Double.self, forKey: .costoFondo),
                                 Limiti.costoFondo, altrimenti: p.costoFondo)
        titoliStatoFondo = Self.limitaFacoltativo(try? c.decodeIfPresent(Double.self, forKey: .titoliStatoFondo),
                                                  Limiti.titoliStatoFondo)
        contributoLavoratore = Self.limita(try? c.decodeIfPresent(Double.self, forKey: .contributoLavoratore),
                                           Limiti.contributo, altrimenti: p.contributoLavoratore)
        contributoDatore = Self.limita(try? c.decodeIfPresent(Double.self, forKey: .contributoDatore),
                                       Limiti.contributo, altrimenti: p.contributoDatore)
        let partecipazione = try? c.decodeIfPresent(Int.self, forKey: .anniPartecipazione)
        anniPartecipazione = partecipazione.map {
            min(max($0, Limiti.anniPartecipazione.lowerBound), Limiti.anniPartecipazione.upperBound)
        } ?? p.anniPartecipazione
        aliquotaTFR = Self.limitaFacoltativo(try? c.decodeIfPresent(Double.self, forKey: .aliquotaTFR),
                                             Limiti.aliquotaTFR)
        quotaTFR = Self.limitaFacoltativo(try? c.decodeIfPresent(Double.self, forKey: .quotaTFR),
                                          Limiti.quotaTFR)
        canale = (try? c.decodeIfPresent(Canale.self, forKey: .canale)) ?? p.canale
        nomeFondo = (try? c.decodeIfPresent(String.self, forKey: .nomeFondo)) ?? p.nomeFondo
    }

    /// Il valore letto riportato nei limiti; il predefinito se manca o non è un numero finito.
    private static func limita(_ v: Double?, _ r: ClosedRange<Double>, altrimenti predefinito: Double) -> Double {
        guard let v, v.isFinite else { return predefinito }
        return min(max(v, r.lowerBound), r.upperBound)
    }

    /// Come `limita`, per un campo facoltativo: nil se manca o non è un numero finito.
    private static func limitaFacoltativo(_ v: Double?, _ r: ClosedRange<Double>) -> Double? {
        guard let v, v.isFinite else { return nil }
        return min(max(v, r.lowerBound), r.upperBound)
    }
}
