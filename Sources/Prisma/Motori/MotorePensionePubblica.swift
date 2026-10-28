import Foundation

/// Le regole della pensione pubblica con il metodo contributivo (L. 335/1995), tutte in un punto:
/// se cambia la norma o escono i nuovi coefficienti si cambia qui.
enum RegolePensione {
    /// Coefficienti di trasformazione del montante in pensione annua lorda (%), per età all'uscita.
    /// Fonte: D.M. Lavoro-Economia del 20 novembre 2024 (tabella A della L. 335/1995 aggiornata),
    /// in vigore per le pensioni con decorrenza dal 1° gennaio 2025 al 31 dicembre 2026.
    /// ATTENZIONE: si aggiornano ogni due anni con la speranza di vita (il prossimo aggiornamento vale
    /// dal 2027): quando esce il nuovo decreto vanno cambiati questa tabella e `validitaCoefficienti`.
    static let coefficienti: [Int: Double] = [
        57: 4.204, 58: 4.308, 59: 4.419, 60: 4.536, 61: 4.661, 62: 4.795, 63: 4.936, 64: 5.088,
        65: 5.250, 66: 5.423, 67: 5.608, 68: 5.808, 69: 6.024, 70: 6.257, 71: 6.510,
    ]
    /// Anni di validità dei coefficienti in tabella.
    static let validitaCoefficienti = "2025–2026"
    static let etaMinimaTabella = 57
    static let etaMassimaTabella = 71
    /// Mensilità della pensione (la tredicesima a dicembre).
    static let mensilita = 13.0

    /// Tasso annuo di capitalizzazione del montante: per legge la media quinquennale del PIL nominale
    /// (art. 1, c. 9, L. 335/1995). Ipotesi prudente, modificabile in `IpotesiPensione`.
    static let tassoCapitalizzazione = 1.5
    /// Addizionali regionale e comunale all'IRPEF stimate (% del reddito): regionale 1,73% e comunale
    /// 0,80% (ipotesi media; le aliquote vere dipendono da regione e comune). Si pagano solo se c'è IRPEF dovuta.
    static let addizionaliStimate = 2.53

    // Requisiti di accesso (D.L. 201/2011, art. 24), da aggiornare con la speranza di vita
    /// Pensione di vecchiaia: 67 anni con almeno 20 anni di contributi.
    static let etaVecchiaia = 67
    static let anniMinimiVecchiaia = 20.0
    /// Contributivi puri: a 71 anni bastano 5 anni di contributi effettivi.
    static let etaVecchiaiaContributiva = 71
    static let anniMinimiContributiva = 5.0
    /// Contributivi puri: pensione anticipata a 64 anni con 20 anni di contributi e un importo minimo
    /// (multiplo dell'assegno sociale, non verificato da Prisma).
    static let etaAnticipataContributiva = 64
    /// Pensione anticipata a qualsiasi età: 41 anni e 10 mesi di contributi (donne), 42 e 10 mesi (uomini).
    /// Prisma non conosce il sesso del cliente: per prudenza vale per tutti la soglia più alta.
    static let anniAnticipata = 42.0 + 10.0 / 12

    // Detrazione IRPEF per i redditi da pensione (art. 13, commi 3 e 3.1, TUIR, come riscritto dalla L. 234/2021)
    static let detrazioneFascia1 = 1_955.0
    static let sogliaFascia1 = 8_500.0
    static let detrazioneBase = 700.0
    static let detrazioneVariabile = 1_255.0
    static let sogliaFascia2 = 28_000.0
    static let sogliaFascia3 = 50_000.0
    /// Maggiorazione di 50 € per i redditi tra 25.000 e 29.000 €.
    static let maggiorazione = 50.0
    static let maggiorazioneDa = 25_000.0
    static let maggiorazioneFino = 29_000.0

    /// Coefficiente di trasformazione (%) per un'età all'uscita; fuori tabella vale l'età più vicina.
    static func coefficiente(eta: Int) -> Double {
        coefficienti[min(max(eta, etaMinimaTabella), etaMassimaTabella)] ?? 0
    }

    /// Detrazione IRPEF annua per redditi da pensione (reddito complessivo lordo annuo):
    /// fino a 8.500 € 1.955 €; fino a 28.000 € 700 + 1.255 × (28.000 − reddito) / 19.500;
    /// fino a 50.000 € 700 × (50.000 − reddito) / 22.000; oltre nulla; +50 € tra 25.000 e 29.000 €.
    static func detrazionePensione(reddito: Double) -> Double {
        let r = max(0, reddito)
        var d: Double
        if r <= sogliaFascia1 {
            d = detrazioneFascia1
        } else if r <= sogliaFascia2 {
            d = detrazioneBase + detrazioneVariabile * (sogliaFascia2 - r) / (sogliaFascia2 - sogliaFascia1)
        } else if r <= sogliaFascia3 {
            d = detrazioneBase * (sogliaFascia3 - r) / (sogliaFascia3 - sogliaFascia2)
        } else {
            d = 0
        }
        if r > maggiorazioneDa && r <= maggiorazioneFino { d += maggiorazione }
        return d
    }

    /// Dalla pensione lorda annua alla netta: IRPEF per scaglioni (`RegoleFiscali.irpef`) meno la detrazione
    /// da pensione, poi le addizionali stimate se c'è IRPEF dovuta.
    static func nettoAnnuo(lordo: Double, addizionali: Double = addizionaliStimate) -> (irpef: Double, addizionali: Double, netto: Double) {
        let l = max(0, lordo)
        let irpef = max(0, RegoleFiscali.irpef(l) - detrazionePensione(reddito: l))
        let add = irpef > 0 ? l * max(0, addizionali) / 100 : 0
        return (irpef, add, l - irpef - add)
    }
}

/// Le ipotesi della stima: si possono cambiare per persona o per prova.
struct IpotesiPensione: Equatable {
    /// Capitalizzazione annua nominale del montante (%), come il PIL nominale.
    var tassoCapitalizzazione = RegolePensione.tassoCapitalizzazione
    /// Inflazione annua (%), per riportare tutto in euro di oggi.
    var inflazione = IpotesiCalcolo.inflazione
    /// Addizionali IRPEF regionale e comunale stimate (%).
    var addizionali = RegolePensione.addizionaliStimate
}

/// La pensione pubblica stimata con il metodo contributivo, in euro di oggi.
struct StimaPensione {
    let eta: Int
    let etaPensione: Int
    var anniAllaPensione: Int { max(0, etaPensione - eta) }
    /// Aliquota di computo usata (% del reddito lordo).
    let aliquota: Double
    let redditoOggi: Double
    /// Reddito lordo dell'ultimo anno di lavoro, in euro di oggi.
    let redditoFinale: Double
    /// Montante di oggi: dall'estratto conto INPS o stimato dagli anni di contributi.
    let montanteOggi: Double
    let montanteStimato: Bool
    /// Montante alla pensione, in euro di oggi.
    let montante: Double
    /// Anni di contributi all'uscita (già versati più quelli futuri).
    let anniContributi: Double
    /// Coefficiente di trasformazione (%) all'età di uscita.
    let coefficiente: Double
    let lordaAnnua: Double
    var lordaMensile: Double { lordaAnnua / RegolePensione.mensilita }
    let irpef: Double
    let addizionali: Double
    let nettaAnnua: Double
    /// Rata netta mensile su 13 mensilità: è la cifra da confrontare con la pensione pubblica dell'Analisi 360.
    var nettaMensile: Double { nettaAnnua / RegolePensione.mensilita }
    /// Pensione lorda in percentuale dell'ultimo reddito lordo.
    var tassoSostituzione: Double? { redditoFinale > 0 ? lordaAnnua / redditoFinale * 100 : nil }
    /// Capitalizzazione reale usata (%): nominale tolta l'inflazione.
    let capitalizzazioneReale: Double
    let sistemaMisto: Bool
    /// true se all'età di uscita ci sono gli anni di contributi richiesti.
    let requisitoRaggiunto: Bool
    /// Montante a fine anno, da oggi (indice 0) alla pensione.
    let punti: [Double]
    let avvisi: [String]
    let metodo: [String]

    /// Quanto manca ogni mese al reddito desiderato (netto mensile in euro di oggi).
    func divario(obiettivo: Double) -> Double { max(0, obiettivo - nettaMensile) }
}

/// Stima della pensione pubblica con il metodo contributivo e divario rispetto all'obiettivo di reddito.
/// Calcolo leggero (un passo per anno): si può chiamare a ogni scheda.
enum MotorePensionePubblica {
    /// La stima per chi ha i dati del lavoro. nil se manca l'aliquota (cassa professionale senza aliquota
    /// indicata) o se non ci sono né reddito né montante.
    /// - `reddito`: ripiego per il reddito lordo da lavoro se `lavoro.redditoLavoro` manca.
    static func stima(lavoro: DatiLavoro, eta: Int, etaPensione: Int, reddito: Double?,
                      ipotesi: IpotesiPensione = IpotesiPensione()) -> StimaPensione? {
        guard let aliquota = lavoro.aliquota, aliquota > 0 else { return nil }
        let redditoOggi = max(0, lavoro.redditoLavoro ?? reddito ?? 0)
        guard redditoOggi > 0 || (lavoro.montanteContributivo ?? 0) > 0 else { return nil }
        let uscita = max(eta, etaPensione)
        let n = max(0, uscita - eta)
        let crescita = (lavoro.crescitaReddito ?? 0) / 100
        // Tutto in euro di oggi: il montante si rivaluta al tasso nominale tolta l'inflazione
        let reale = (1 + ipotesi.tassoCapitalizzazione / 100) / (1 + ipotesi.inflazione / 100) - 1
        let gia = max(0, lavoro.anniContributi ?? 0)
        let stimato = lavoro.montanteContributivo == nil
        let montanteOggi = lavoro.montanteContributivo.map { max(0, $0) } ?? gia * redditoOggi * aliquota / 100

        // Ogni anno: il montante dell'anno prima si rivaluta e si aggiungono i contributi dell'anno
        // (quelli dell'ultimo anno non si rivalutano, come nel calcolo INPS)
        var montante = montanteOggi
        var punti = [montanteOggi]
        var redditoAnno = redditoOggi
        var redditoFinale = redditoOggi
        for anno in 0..<n {
            if anno > 0 { redditoAnno *= 1 + crescita }
            montante = montante * (1 + reale) + redditoAnno * aliquota / 100
            redditoFinale = redditoAnno
            punti.append(montante)
        }

        let coefficiente = RegolePensione.coefficiente(eta: uscita)
        let lorda = montante * coefficiente / 100
        let netto = RegolePensione.nettoAnnuo(lordo: lorda, addizionali: ipotesi.addizionali)
        let anniTotali = gia + Double(n)

        // Requisiti di accesso
        let requisito: Bool
        var avvisi: [String] = []
        if uscita >= RegolePensione.etaVecchiaiaContributiva {
            requisito = anniTotali >= RegolePensione.anniMinimiContributiva
        } else if uscita >= RegolePensione.etaAnticipataContributiva {
            requisito = anniTotali >= RegolePensione.anniMinimiVecchiaia
            if uscita < RegolePensione.etaVecchiaia {
                avvisi.append("Uscita a \(uscita) anni: la pensione anticipata contributiva chiede 20 anni di contributi e un importo minimo, multiplo dell'assegno sociale, da verificare.")
            }
        } else {
            requisito = anniTotali >= RegolePensione.anniAnticipata
            avvisi.append("Prima dei \(RegolePensione.etaAnticipataContributiva) anni serve la pensione anticipata: 41 anni e 10 mesi di contributi per le donne, 42 e 10 mesi per gli uomini.")
        }
        if !requisito {
            avvisi.append("Con \(formatoAnni(anniTotali)) anni di contributi a \(uscita) anni i requisiti non sono raggiunti: a 67 anni ne servono 20, a 71 anni ne bastano 5.")
        }
        if lavoro.sistemaMisto, let primo = lavoro.annoPrimoContributo {
            avvisi.append("Contributi dal \(primo): sistema misto, la parte fino al 1995 (o fino al 2011 con 18 anni di contributi al 1995) si calcola con il retributivo. La stima contributiva è solo indicativa.")
        }
        if stimato {
            avvisi.append(gia > 0
                ? "Montante di oggi stimato da \(formatoAnni(gia)) anni di contributi sul reddito di oggi, senza rivalutazione: meglio indicare quello dell'estratto conto INPS."
                : "Anni di contributi e montante non indicati: contano solo i contributi futuri.")
        }
        if uscita < RegolePensione.etaMinimaTabella || uscita > RegolePensione.etaMassimaTabella {
            avvisi.append("Età di uscita fuori dalla tabella dei coefficienti: usato quello dei \(min(max(uscita, RegolePensione.etaMinimaTabella), RegolePensione.etaMassimaTabella)) anni.")
        }

        let metodo = [
            "Metodo contributivo (L. 335/1995): ogni anno si accantona il \(CifreDoc.condizione(aliquota)) del reddito lordo da lavoro; il montante si rivaluta al \(CifreDoc.condizione(ipotesi.tassoCapitalizzazione)) annuo (media quinquennale del PIL nominale, ipotesi prudente) e si riporta in euro di oggi con un'inflazione del \(CifreDoc.condizione(ipotesi.inflazione)).",
            "Pensione annua lorda = montante × coefficiente di trasformazione all'età di uscita (\(CifreDoc.percento(coefficiente, decimali: 3)) a \(uscita) anni, D.M. 20 novembre 2024, valido per il \(RegolePensione.validitaCoefficienti): i coefficienti si aggiornano ogni due anni).",
            "Netto su 13 mensilità: IRPEF per scaglioni meno la detrazione per redditi da pensione (art. 13 TUIR), addizionali regionale e comunale stimate al \(CifreDoc.condizione(ipotesi.addizionali)). Scaglioni di oggi applicati agli euro di oggi.",
            "Requisiti: 67 anni con 20 di contributi (per chi ha iniziato dal 1996 anche un importo almeno pari all'assegno sociale, non verificato), 71 anni con 5, oppure la pensione anticipata; da aggiornare con la speranza di vita.",
            "È una stima: non sostituisce l'estratto conto e la simulazione dell'INPS, non considera riscatti, ricongiunzioni, periodi figurativi né le regole del sistema misto.",
        ]

        return StimaPensione(
            eta: eta, etaPensione: uscita, aliquota: aliquota, redditoOggi: redditoOggi, redditoFinale: redditoFinale,
            montanteOggi: montanteOggi, montanteStimato: stimato, montante: montante, anniContributi: anniTotali,
            coefficiente: coefficiente, lordaAnnua: lorda, irpef: netto.irpef, addizionali: netto.addizionali,
            nettaAnnua: netto.netto, capitalizzazioneReale: reale * 100, sistemaMisto: lavoro.sistemaMisto,
            requisitoRaggiunto: requisito, punti: punti, avvisi: avvisi, metodo: metodo)
    }

    /// La stima del cliente: età alla data, uscita dal lavoro o dall'Analisi 360, reddito dal lavoro o dal profilo.
    static func stima(cliente: Cliente, previdenza: IpotesiPrevidenza, data: Date = Date(),
                      ipotesi: IpotesiPensione = IpotesiPensione()) -> StimaPensione? {
        guard let lavoro = cliente.profilo.lavoro else { return nil }
        let eta = etaAl(cliente.dataNascita, data) ?? previdenza.eta
        let uscita = lavoro.etaPensione ?? previdenza.etaPensione
        return stima(lavoro: lavoro, eta: eta, etaPensione: uscita, reddito: cliente.profilo.redditoLordoAnnuo, ipotesi: ipotesi)
    }

    /// La stima di un familiare con i dati del lavoro e la data di nascita (uscita predefinita a 67 anni).
    static func stima(familiare: Familiare, data: Date = Date(), ipotesi: IpotesiPensione = IpotesiPensione()) -> StimaPensione? {
        guard let lavoro = familiare.lavoro, let eta = etaAl(familiare.dataNascita, data) else { return nil }
        return stima(lavoro: lavoro, eta: eta, etaPensione: lavoro.etaPensione ?? RegolePensione.etaVecchiaia,
                     reddito: nil, ipotesi: ipotesi)
    }

    /// Perché la stima non si può fare (nil se si può).
    static func motivoAssente(_ lavoro: DatiLavoro?, reddito: Double?) -> String? {
        guard let lavoro else { return "Mancano i dati del lavoro e dei contributi." }
        if lavoro.aliquota == nil {
            return lavoro.tipo == .cassaProfessionale
                ? "Professionista con cassa propria: le regole della cassa sono diverse, indica l'aliquota per una stima."
                : "Manca il tipo di lavoratore o l'aliquota contributiva."
        }
        if (lavoro.redditoLavoro ?? reddito ?? 0) <= 0 && (lavoro.montanteContributivo ?? 0) <= 0 {
            return "Mancano il reddito da lavoro e il montante contributivo."
        }
        return nil
    }

    /// La pensione pubblica netta mensile da usare nel divario: quella inserita a mano nell'Analisi 360
    /// vince sempre; la stima prende il suo posto solo se l'analisi non è stata compilata.
    static func pensioneDaUsare(_ previdenza: IpotesiPrevidenza, stima: StimaPensione?, inseritaAMano: Bool) -> Double {
        if inseritaAMano { return previdenza.pensionePubblica }
        return stima.map { MotoreFiscale.centesimi($0.nettaMensile) } ?? previdenza.pensionePubblica
    }

    /// Età in anni interi a una data.
    static func etaAl(_ nascita: Date?, _ data: Date) -> Int? {
        guard let nascita else { return nil }
        return Calendar.current.dateComponents([.year], from: nascita, to: data).year
    }

    private static func formatoAnni(_ anni: Double) -> String {
        anni == anni.rounded() ? String(Int(anni)) : String(format: "%.1f", anni).replacingOccurrences(of: ".", with: ",")
    }
}
