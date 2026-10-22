import Foundation

/// Le regole fiscali usate da Prisma, tutte in un punto: se cambia la norma si cambia qui.
/// Fonti: TUIR e D.L. 138/2011 (26% sui redditi di natura finanziaria, 12,5% sui titoli di Stato
/// ed equiparati); D.Lgs. 252/2005, art. 11 e 14 (previdenza complementare); D.P.R. 642/1972,
/// art. 13 (imposta di bollo dello 0,20% sulle comunicazioni relative ai prodotti finanziari).
enum RegoleFiscali {
    /// Aliquota ordinaria sui redditi finanziari.
    static let ordinaria = 26.0
    /// Aliquota sui titoli di Stato ed equiparati.
    static let titoliStato = 12.5
    /// Imposta di bollo annua sul valore dei prodotti finanziari.
    static let bollo = 0.20
    /// Conti correnti: bollo fisso annuo delle persone fisiche, dovuto se la giacenza media supera la soglia.
    static let bolloContoCorrente = 34.20
    static let sogliaContoCorrente = 5_000.0

    // Previdenza complementare
    /// Aliquota sulle prestazioni e sui riscatti agevolati fino al 15° anno di partecipazione.
    static let previdenzaBase = 15.0
    /// Riduzione per ogni anno di partecipazione oltre il 15°.
    static let previdenzaRiduzione = 0.30
    static let previdenzaMinima = 9.0
    /// Anticipazioni per la casa e per ulteriori esigenze, riscatti per cause diverse.
    static let previdenzaOrdinaria = 23.0
    /// Anni di iscrizione richiesti per le anticipazioni per la casa e per ulteriori esigenze.
    static let anniPerAnticipazione = 8

    /// Aliquota agevolata della previdenza dopo `anni` interi di partecipazione: 15% fino al 15° anno,
    /// poi 0,30 punti in meno per ogni anno, fino al 9% dal 35° anno.
    static func aliquotaPrevidenza(anni: Int) -> Double {
        max(previdenzaMinima, previdenzaBase - previdenzaRiduzione * Double(max(0, anni - 15)))
    }

    /// Aliquota effettiva sul guadagno con una quota in titoli di Stato (0–100).
    static func aliquotaEffettiva(quotaTitoliStato: Double) -> Double {
        let q = min(max(quotaTitoliStato, 0), 100) / 100
        return ordinaria * (1 - q) + titoliStato * q
    }
}

/// Perché si chiedono i soldi a un fondo pensione: decide quanto si può avere e l'aliquota.
enum CausaPrevidenza: String, CaseIterable, Identifiable {
    case pensione, riscattoAgevolato, anticipazioneSanitaria, anticipazioneCasa, anticipazioneUlteriori, riscattoAltreCause

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .pensione: return "Prestazione al pensionamento"
        case .riscattoAgevolato: return "Riscatto per invalidità, inoccupazione oltre 48 mesi o decesso"
        case .anticipazioneSanitaria: return "Anticipazione per spese sanitarie"
        case .anticipazioneCasa: return "Anticipazione per la prima casa"
        case .anticipazioneUlteriori: return "Anticipazione per ulteriori esigenze"
        case .riscattoAltreCause: return "Riscatto per altre cause (per esempio dimissioni)"
        }
    }

    var nomeBreve: String {
        switch self {
        case .pensione: return "Pensionamento"
        case .riscattoAgevolato: return "Riscatto agevolato"
        case .anticipazioneSanitaria: return "Spese sanitarie"
        case .anticipazioneCasa: return "Prima casa"
        case .anticipazioneUlteriori: return "Ulteriori esigenze"
        case .riscattoAltreCause: return "Riscatto altre cause"
        }
    }

    /// Quota massima della posizione che si può chiedere.
    var quotaMassima: Double {
        switch self {
        case .anticipazioneSanitaria, .anticipazioneCasa: return 0.75
        case .anticipazioneUlteriori: return 0.30
        case .pensione, .riscattoAgevolato, .riscattoAltreCause: return 1
        }
    }

    /// true se si applica l'aliquota agevolata (15% → 9%), false se il 23%.
    var agevolata: Bool {
        switch self {
        case .pensione, .riscattoAgevolato, .anticipazioneSanitaria: return true
        case .anticipazioneCasa, .anticipazioneUlteriori, .riscattoAltreCause: return false
        }
    }

    /// Anni di iscrizione richiesti, se ce ne sono.
    var anniRichiesti: Int? {
        switch self {
        case .anticipazioneCasa, .anticipazioneUlteriori: return RegoleFiscali.anniPerAnticipazione
        default: return nil
        }
    }

    /// Requisito da ricordare (oltre agli anni).
    var requisito: String {
        switch self {
        case .pensione: return "requisiti per la pensione obbligatoria e almeno 5 anni di partecipazione"
        case .riscattoAgevolato: return "invalidità permanente oltre un terzo, inoccupazione oltre 48 mesi o decesso"
        case .anticipazioneSanitaria: return "spese sanitarie straordinarie, in qualsiasi momento"
        case .anticipazioneCasa: return "acquisto o ristrutturazione della prima casa, dopo 8 anni"
        case .anticipazioneUlteriori: return "qualsiasi esigenza, dopo 8 anni"
        case .riscattoAltreCause: return "perdita dei requisiti di partecipazione (per esempio dimissioni)"
        }
    }

    func aliquota(anni: Int) -> Double {
        agevolata ? RegoleFiscali.aliquotaPrevidenza(anni: anni) : RegoleFiscali.previdenzaOrdinaria
    }
}

/// Una richiesta di denaro a un fondo pensione, già tassata.
struct UscitaPrevidenza: Identifiable {
    let causa: CausaPrevidenza
    var id: CausaPrevidenza { causa }
    /// false se mancano gli anni di iscrizione richiesti.
    let possibile: Bool
    let importo: Double
    /// Parte tassabile dell'importo: i contributi dedotti (i rendimenti sono già tassati nel fondo).
    let imponibile: Double
    let aliquota: Double
    var imposta: Double { (imponibile * aliquota / 100 * 100).rounded() / 100 }
    var netto: Double { importo - imposta }
}

/// Un cambio di aliquota della prestazione nei prossimi anni.
struct GradinoAliquota: Identifiable {
    let anni: Int
    let dal: Date
    let aliquota: Double
    var id: Int { anni }
}

/// Le imposte e i costi di una posizione se la si chiudesse oggi.
struct EsitoFiscale {
    let regime: RegimeFiscale
    let valore: Double
    let versato: Double
    /// Penale di riscatto (dalle condizioni del prodotto collegato), se c'è.
    let penale: Double
    /// Bollo maturato non ancora pagato (polizze: si paga al riscatto).
    let bolloMaturato: Double
    let imponibile: Double
    /// Aliquota applicata (effettiva, con i titoli di Stato; per la previdenza quella della prestazione oggi).
    let aliquota: Double
    let imposta: Double
    var netto: Double { valore - penale - bolloMaturato - imposta }
    var guadagnoLordo: Double { valore - versato }
    var guadagnoNetto: Double { netto - versato }
    /// Note su come si è arrivati alla cifra (ipotesi dichiarate).
    let note: [String]

    // Previdenza
    let anniPartecipazione: Int?
    let uscite: [UscitaPrevidenza]
    let gradini: [GradinoAliquota]

    // Costi di un anno, divisi
    let costoGestione: Double
    let costoTrattenuto: Double
    let costoBollo: Double
    var costoTotale: Double { costoGestione + costoTrattenuto + costoBollo }
}

/// Imposte, netto incassabile oggi e costi divisi per voce. Tutto al centesimo.
enum MotoreFiscale {
    static func centesimi(_ v: Double) -> Double { (v * 100).rounded() / 100 }

    /// Bollo di un anno: 0,20% del valore; per i conti correnti 34,20 € fissi.
    static func bolloAnnuo(_ p: Posizione, valore: Double) -> Double {
        guard p.soggettaBollo else { return 0 }
        let testo = (p.nome + " " + p.tipologia).lowercased()
        if p.regime == .deposito && testo.contains("corrente") && !testo.contains("deposito") {
            return valore > RegoleFiscali.sogliaContoCorrente ? RegoleFiscali.bolloContoCorrente : 0
        }
        return centesimi(RegoleFiscali.bollo / 100 * valore)
    }

    static func calcola(_ p: Posizione, prodotto: Prodotto? = nil, data: Date = Date()) -> EsitoFiscale {
        let regime = p.regime
        let valore = p.area == .protezione ? 0 : p.valore
        let versato = p.totaleVersato ?? p.versamentoIniziale
        var note: [String] = []

        // Costi di un anno: gestione, trattenuto sul rendimento, bollo
        let gestione = centesimi((p.costoAnnuo ?? 0) / 100 * valore)
        let trattenuto = centesimi((p.trattenuto ?? 0) / 100 * valore)
        let bolloAnno = bolloAnnuo(p, valore: valore)

        // Penale dalle condizioni del contratto, se il prodotto le ha
        var penale = 0.0
        if let c = prodotto?.condizioni, let inizio = p.decorrenza, regime == .polizza {
            let anno = (Calendar.current.dateComponents([.year], from: inizio, to: data).year ?? 0) + 1
            let percento = c.penale(anno: anno)
            if percento > 0 {
                penale = centesimi(valore * percento / 100)
                note.append("Penale di riscatto del \(CifreDoc.penale(percento)) nel \(anno)° anno, dalle condizioni del contratto.")
            }
        }

        switch regime {
        case .esente:
            return EsitoFiscale(regime: regime, valore: valore, versato: versato, penale: 0, bolloMaturato: 0, imponibile: 0, aliquota: 0,
                                imposta: 0, note: [], anniPartecipazione: nil, uscite: [], gradini: [],
                                costoGestione: gestione, costoTrattenuto: trattenuto, costoBollo: bolloAnno)

        case .previdenza:
            let inizio = p.primaAdesione ?? p.decorrenza
            // Anni interi compiuti, contati a giorni (l'ora della giornata non conta)
            let cal = Calendar.current
            let anni = inizio.map { cal.dateComponents([.year], from: cal.startOfDay(for: $0), to: cal.startOfDay(for: data)).year ?? 0 } ?? 0
            if p.primaAdesione == nil { note.append("Anni di partecipazione contati dalla decorrenza: se il cliente aveva già aderito a un'altra forma, indica la data della prima adesione.") }
            // Si tassano solo i contributi dedotti: i rendimenti sono già tassati ogni anno nel fondo
            let nonDedotti = p.contributiNonDedotti ?? 0
            let dedotti = max(0, min(valore, versato) - nonDedotti)
            if p.contributiNonDedotti == nil { note.append("Contributi considerati tutti dedotti: se una parte non è stata dedotta, indicala per non tassarla due volte.") }
            let quotaImponibile = valore > 0 ? dedotti / valore : 0
            let uscite = CausaPrevidenza.allCases.map { c -> UscitaPrevidenza in
                let possibile = c.anniRichiesti.map { anni >= $0 } ?? true
                let importo = centesimi(valore * c.quotaMassima)
                return UscitaPrevidenza(causa: c, possibile: possibile, importo: importo,
                                        imponibile: centesimi(importo * quotaImponibile), aliquota: c.aliquota(anni: anni))
            }
            var gradini: [GradinoAliquota] = []
            if let inizio {
                // Dal 16° anno l'aliquota scende di 0,30 punti l'anno, fino al 9% dal 35°
                for n in max(anni + 1, 16)..<max(max(anni + 1, 16), 36) {
                    guard let dal = Calendar.current.date(byAdding: .year, value: n, to: inizio) else { continue }
                    gradini.append(GradinoAliquota(anni: n, dal: dal, aliquota: RegoleFiscali.aliquotaPrevidenza(anni: n)))
                }
            }
            let pensione = uscite.first { $0.causa == .pensione }
            note.append("Aliquota oggi: \(CifreDoc.percento(RegoleFiscali.aliquotaPrevidenza(anni: anni), decimali: 2)) su pensionamento, riscatti agevolati e spese sanitarie; \(CifreDoc.percento(RegoleFiscali.previdenzaOrdinaria, decimali: 0)) su anticipazioni per la casa o per ulteriori esigenze e sui riscatti per altre cause.")
            return EsitoFiscale(regime: regime, valore: valore, versato: versato, penale: 0, bolloMaturato: 0,
                                imponibile: pensione?.imponibile ?? 0, aliquota: pensione?.aliquota ?? 0, imposta: pensione?.imposta ?? 0,
                                note: note, anniPartecipazione: anni, uscite: uscite, gradini: gradini,
                                costoGestione: gestione, costoTrattenuto: trattenuto, costoBollo: 0)

        case .polizza, .fondo, .deposito:
            let aliquota: Double
            if let q = p.quotaTitoliStato {
                aliquota = RegoleFiscali.aliquotaEffettiva(quotaTitoliStato: q)
                note.append("Aliquota effettiva \(CifreDoc.percento(aliquota, decimali: 2)): \(CifreDoc.condizione(q)) in titoli di Stato al 12,5%, il resto al 26%.")
            } else if regime == .deposito {
                aliquota = RegoleFiscali.ordinaria
            } else {
                aliquota = p.aliquotaFiscale ?? RegoleFiscali.ordinaria
                note.append(p.aliquotaFiscale == nil ? "Aliquota del 26%: indica la quota in titoli di Stato per l'aliquota effettiva."
                                                     : "Aliquota indicata nella posizione: \(CifreDoc.percento(aliquota, decimali: 2)).")
            }
            // Polizze: il bollo maturato si paga al riscatto (stima: bollo annuo per gli anni trascorsi)
            var bolloMaturato = 0.0
            if regime == .polizza, p.soggettaBollo, let inizio = p.decorrenza {
                let anni = max(0, data.timeIntervalSince(inizio) / (365.25 * 86_400))
                bolloMaturato = centesimi(RegoleFiscali.bollo / 100 * valore * anni)
                note.append("Bollo maturato stimato sul valore di oggi per \(String(format: "%.1f", anni).replacingOccurrences(of: ".", with: ",")) anni: nelle polizze si paga al riscatto.")
            }
            // Conti e depositi: gli interessi sono già tassati all'accredito
            if regime == .deposito {
                note.append("Interessi già tassati al 26% quando vengono accreditati: il saldo è netto.")
                return EsitoFiscale(regime: regime, valore: valore, versato: versato, penale: 0, bolloMaturato: 0, imponibile: 0,
                                    aliquota: aliquota, imposta: 0, note: note, anniPartecipazione: nil, uscite: [], gradini: [],
                                    costoGestione: gestione, costoTrattenuto: trattenuto, costoBollo: bolloAnno)
            }
            // Il guadagno tassabile è al netto della penale (valore − penale − premi versati)
            let imponibile = centesimi(max(0, valore - penale - versato))
            let imposta = centesimi(imponibile * aliquota / 100)
            return EsitoFiscale(regime: regime, valore: valore, versato: versato, penale: penale, bolloMaturato: bolloMaturato,
                                imponibile: imponibile, aliquota: aliquota, imposta: imposta, note: note,
                                anniPartecipazione: nil, uscite: [], gradini: [],
                                costoGestione: gestione, costoTrattenuto: trattenuto, costoBollo: bolloAnno)
        }
    }
}
