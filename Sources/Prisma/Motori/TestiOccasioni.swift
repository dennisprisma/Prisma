import Foundation

/// I testi del calendario delle occasioni: titoli (mai con cifre in euro, vanno anche nei promemoria del Mac),
/// dettagli con le cifre, fonti normative o contrattuali, etichette e simboli dei tipi.
/// Le fonti sono riferimenti da verificare sul testo vigente: in app compaiono con la nota `avvertenza`.
enum TestiOccasioni {
    /// La nota da mettere sotto le tabelle dei documenti.
    static let avvertenza = "Date ricavate dai dati registrati in Prisma (decorrenze, condizioni, famiglia): fanno fede le condizioni di contratto e i documenti del fondo."

    // MARK: - Fonti

    static func fonte(_ t: TipoOccasione) -> String {
        switch t {
        case .fineBloccoRiscatto, .senzaPenali:
            return "Condizioni di contratto (riscatto e penali per annualità) e DIP aggiuntivo IBIP (Regolamento IVASS 41/2018); riscatto delle polizze vita: c.c., art. 1925."
        case .periodoRaccomandato:
            return "KID: Regolamento (UE) 1286/2014 (PRIIPs) e Regolamento delegato (UE) 2017/653, periodo di detenzione raccomandato."
        case .ricorrenzaGestione:
            return "Regolamento ISVAP 38/2011 (gestioni separate); rivalutazione e consolidamento secondo le condizioni di contratto."
        case .anticipazioniPrevidenza:
            return "D.Lgs. 252/2005, art. 11, c. 7 (anticipazioni) e c. 8 (anzianità con tutti i periodi di partecipazione)."
        case .aliquotaPrevidenza:
            return "D.Lgs. 252/2005, art. 11, c. 6: 15% ridotto di 0,30 punti per ogni anno oltre il 15° di partecipazione, fino a 6 punti."
        case .pensioneVicina:
            return "D.Lgs. 252/2005, art. 11, c. 4 (RITA) e c. 3 (prestazione in capitale fino al 50%)."
        case .maggiorenne:
            return "Codice civile, art. 2 (maggiore età) e art. 320 (amministrazione dei beni dei figli minori)."
        case .fineCarico:
            return "Ipotesi della protezione di Prisma: età di fine carico del familiare (di regola 25 anni), da rivedere con il cliente."
        case .capitaleSottoDebito:
            return "Stima di Prisma: capitale decrescente in linea retta (il piano vero è nelle condizioni di polizza) e debito con l'ammortamento alla francese."
        case .limiteEtaTCM, .limiteEtaLTC:
            return "Limite d'età più comune nelle condizioni di polizza (si imposta in Impostazioni › Occasioni): verificare quello del prodotto."
        case .scadenzaFiscale:
            return fonteFiscale(.deduzione)
        }
    }

    static func fonteFiscale(_ t: ScadenzaFiscale.Tipo) -> String {
        switch t {
        case .deduzione:
            return "TUIR, art. 10, c. 1, lett. e-bis, e D.Lgs. 252/2005, art. 8, c. 4: contributi deducibili fino a 5.300 € l'anno (dal 2026)."
        case .nonDedotti:
            return "D.Lgs. 252/2005, art. 8, c. 4: i contributi non dedotti si comunicano al fondo entro il 31 dicembre dell'anno dopo."
        case .detrazione:
            return "TUIR, art. 15, c. 1, lett. f: detrazione del 19% dei premi caso morte, invalidità e non autosufficienza."
        case .bollo:
            return "D.P.R. 642/1972, tariffa, art. 13, c. 2-ter: bollo dello 0,20% sui prodotti finanziari."
        }
    }

    // MARK: - Titoli anonimi, etichette, simboli, cifre

    /// Il titolo senza nomi né cifre, per i promemoria con «Nomi dei clienti» spento.
    static func titoloAnonimo(_ t: TipoOccasione) -> String {
        switch t {
        case .fineBloccoRiscatto: return "Una polizza si può riscattare"
        case .senzaPenali: return "Un contratto senza più penali"
        case .periodoRaccomandato: return "Un investimento ha raggiunto il periodo del KID"
        case .ricorrenzaGestione: return "Ricorrenza annua di una polizza"
        case .anticipazioniPrevidenza: return "Una previdenza compie 8 anni"
        case .aliquotaPrevidenza: return "Una previdenza oltre il 15° anno"
        case .pensioneVicina: return "5 anni alla pensione di un cliente"
        case .maggiorenne: return "Un figlio di un cliente diventa maggiorenne"
        case .fineCarico: return "Un familiare non è più a carico"
        case .capitaleSottoDebito: return "Un capitale caso morte sotto il debito"
        case .limiteEtaTCM: return "Ultimo anno per una copertura caso morte"
        case .limiteEtaLTC: return "Ultimo anno per una LTC"
        case .scadenzaFiscale: return "Versamenti deducibili entro il 31 dicembre"
        }
    }

    /// Il titolo anonimo di un'occasione: per il fisco dipende dalla scadenza.
    static func titoloAnonimo(_ o: Occasione) -> String {
        if o.tipo == .scadenzaFiscale && o.fiscale == .nonDedotti { return "Contributi non dedotti da comunicare" }
        return titoloAnonimo(o.tipo)
    }

    /// L'etichetta breve del simbolo e del riquadro: «Riscatto», «Penali», «KID», «Ricorrenza», «Previdenza», …
    static func etichetta(_ t: TipoOccasione) -> String {
        switch t {
        case .fineBloccoRiscatto: return "Riscatto"
        case .senzaPenali: return "Penali"
        case .periodoRaccomandato: return "KID"
        case .ricorrenzaGestione: return "Ricorrenza"
        case .anticipazioniPrevidenza: return "Previdenza"
        case .aliquotaPrevidenza: return "Aliquota"
        case .pensioneVicina: return "Pensione"
        case .maggiorenne, .fineCarico: return "Famiglia"
        case .capitaleSottoDebito: return "Caso morte"
        case .limiteEtaTCM, .limiteEtaLTC: return "Età"
        case .scadenzaFiscale: return "Fisco"
        }
    }

    /// SF Symbol del tipo (disponibili da macOS 13).
    static func simbolo(_ t: TipoOccasione) -> String {
        switch t {
        case .fineBloccoRiscatto: return "lock.open"
        case .senzaPenali: return "checkmark.seal"
        case .periodoRaccomandato: return "doc.text.magnifyingglass"
        case .ricorrenzaGestione: return "arrow.triangle.2.circlepath"
        case .anticipazioniPrevidenza: return "house"
        case .aliquotaPrevidenza: return "percent"
        case .pensioneVicina: return "calendar.badge.clock"
        case .maggiorenne: return "person.crop.circle.badge.checkmark"
        case .fineCarico: return "person.2"
        case .capitaleSottoDebito: return "shield.lefthalf.filled"
        case .limiteEtaTCM, .limiteEtaLTC: return "hourglass"
        case .scadenzaFiscale: return "eurosign.circle"
        }
    }

    /// La cifra chiave in parole per il dettaglio («12 mesi», «dal 6° anno», «10 anni», «14,70%», «70 anni», «64.268 €»).
    static func valore(_ o: Occasione) -> String? {
        guard let v = o.valore else { return nil }
        let n = Int(v.rounded())
        switch o.tipo {
        case .fineBloccoRiscatto: return "\(n) mesi"
        case .senzaPenali: return "dal \(n)° anno"
        case .ricorrenzaGestione: return "\(n)ª ricorrenza"
        case .aliquotaPrevidenza: return CifreDoc.percento(v, decimali: 2)
        case .periodoRaccomandato, .anticipazioniPrevidenza, .pensioneVicina, .maggiorenne, .fineCarico,
             .limiteEtaTCM, .limiteEtaLTC:
            return "\(n) anni"
        case .capitaleSottoDebito, .scadenzaFiscale: return Formati.euro(v)
        }
    }

    // MARK: - Titoli e dettagli per tipo (li compone MotoreOccasioni)

    static func titoloFineBlocco(_ nome: String) -> String { "«\(nome)» si può riscattare" }

    static func dettaglioFineBlocco(mesi: Int, penale: Double, anno: Int) -> String {
        "Finiscono i \(mesi) mesi di blocco dalla decorrenza: da qui il riscatto si può chiedere"
            + (penale > 0 ? ", con la penale del \(CifreDoc.penale(penale)) nel \(anno)° anno" : "")
            + ". È il momento di confrontare la posizione con un'alternativa."
    }

    static func titoloSenzaPenali(_ nome: String) -> String { "«\(nome)» senza più penali di riscatto" }

    static func dettaglioSenzaPenali(anno: Int, costoUscita: Double) -> String {
        "Dal \(anno)° anno di contratto il riscatto non ha penali"
            + (costoUscita > 0 ? " (resta il costo d'uscita del \(CifreDoc.penale(costoUscita)))" : "")
            + ": il capitale si può spostare senza perdite per penali, se serve."
    }

    static func titoloPeriodo(_ nome: String) -> String { "«\(nome)»: periodo raccomandato raggiunto" }

    static func dettaglioPeriodo(anni: Int) -> String {
        "Sono passati i \(anni) anni di detenzione raccomandati dal KID: il momento di verificare risultato, costi e rischio rispetto agli obiettivi."
    }

    static func titoloRicorrenza(_ nome: String) -> String { "Ricorrenza annua di «\(nome)»" }

    static func dettaglioRicorrenza(multiramo: Bool, consolidamento: Bool?, minimoGarantito: Double?) -> String {
        let parte: String = multiramo ? "parte in gestione separata" : "gestione separata"
        var testo = "La \(parte) si rivaluta"
        if consolidamento == true { testo += " e il rendimento si consolida" }
        let minimo: Double = minimoGarantito ?? 0
        if minimo > 0 { testo += " (minimo garantito \(CifreDoc.condizione(minimo)))" }
        return testo + ": arriva l'estratto conto annuale, da registrare nello storico della posizione."
    }

    static func titoloAnticipazioni(_ nome: String) -> String { "«\(nome)»: 8 anni, anticipazioni possibili" }

    static let dettaglioAnticipazioni = "Con 8 anni di partecipazione (contati dalla prima adesione) si può chiedere l'anticipazione fino al 75% per la prima casa e fino al 30% per ulteriori esigenze, tassate al 23%. Per le spese sanitarie l'anticipazione si può chiedere in ogni momento."

    static func titoloAliquota(_ nome: String, minima: Bool) -> String {
        minima ? "«\(nome)»: aliquota al minimo del 9%" : "«\(nome)»: oltre il 15° anno l'aliquota scende"
    }

    static func dettaglioAliquota(minima: Bool) -> String {
        minima
            ? "Con 35 anni di partecipazione l'aliquota sulla prestazione arriva al minimo del 9%."
            : "Da qui l'aliquota sulla prestazione scende dal 15% al 14,70% e poi di 0,30 punti per ogni anno in più, fino al 9% dal 35° anno: un motivo in più per non riscattare e continuare a versare."
    }

    static func titoloPensione(_ persona: String) -> String { "5 anni alla pensione di \(persona)" }

    static func dettaglioPensione(eta: Int) -> String {
        "A \(eta - RegoleOccasioni.anniPrimaPensione) anni ne mancano 5 alla pensione prevista (\(eta) anni): cessato il lavoro, con 20 anni di contributi e 5 di partecipazione, la previdenza complementare può pagare la rendita anticipata (RITA). È l'ultimo tratto per decidere tra capitale e rendita e completare i versamenti deducibili."
    }

    static func titoloMaggiorenne(_ persona: String) -> String { "\(persona) diventa maggiorenne" }

    static let dettaglioMaggiorenne = "Compie 18 anni: può firmare contratti a suo nome (un piano di accumulo, una previdenza complementare) e i beni intestati a lui o a lei escono dall'amministrazione dei genitori. Da rivedere beneficiari e obiettivi legati agli studi."

    static func titoloFineCarico(_ persona: String) -> String { "\(persona) non è più a carico" }

    static func dettaglioFineCarico(eta: Int) -> String {
        "Finisce il sostegno previsto fino a \(eta) anni: meno anni da coprire nel caso morte. Si può ridurre il capitale o spostare risorse sulla previdenza."
    }

    static func titoloSottoDebito(_ persona: String) -> String { "Caso morte di \(persona) sotto il debito residuo" }

    static func dettaglioSottoDebito(_ persona: String, data: Date, capitale: Double, debito: Double) -> String {
        "Dal \(Formati.dataEstesa.string(from: data)) il capitale caso morte di \(persona) (circa \(CifreDoc.euro(capitale))) scende sotto il debito residuo a suo carico (circa \(CifreDoc.euro(debito))): conviene adeguare capitale o durata prima di allora."
    }

    static func titoloLimiteTCM(_ persona: String) -> String { "Ultimo anno per una copertura caso morte di \(persona)" }

    static func dettaglioLimiteTCM(_ persona: String, limite: Int, debiti: Bool) -> String {
        "\(persona) compie \(limite - 1) anni: dai \(limite) di solito una temporanea caso morte non si sottoscrive più. Oggi non ha una copertura caso morte"
            + (debiti ? " e ci sono debiti da proteggere" : " e ci sono familiari da proteggere") + "."
    }

    static func titoloLimiteLTC(_ persona: String) -> String { "Ultimo anno per una LTC di \(persona)" }

    static func dettaglioLimiteLTC(_ persona: String, limite: Int) -> String {
        "\(persona) compie \(limite - 1) anni: dai \(limite) di solito una copertura per la non autosufficienza (LTC) non si sottoscrive più. Oggi non ne ha una."
    }

    // MARK: - Domande del riesame

    static func domandaFamiglia(_ o: Occasione) -> String {
        "\(o.titolo) il \(Formati.dataBreve.string(from: o.data)): ci sono progetti da preparare per tempo (studi, casa, un piano a suo nome)?"
    }

    static func domandaLimite(_ o: Occasione) -> String {
        "\(o.titolo): vuole valutarla adesso, finché si può sottoscrivere?"
    }

    static let domandaPensione = "Mancano 5 anni alla pensione: preferirebbe un capitale, una rendita o una rendita anticipata (RITA)?"
}
