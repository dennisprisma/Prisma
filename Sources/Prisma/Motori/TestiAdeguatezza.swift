import Foundation

/// I testi della scheda di adeguatezza (giro 4, specifica 1): nomi dei controlli e dei colori, frasi dei
/// controlli, fonti normative, avvertenze, dichiarazioni e metodo. Prudenti: la scheda è uno strumento di
/// lavoro del consulente, non un parere legale. Le cifre con `CifreDoc`.
enum TestiAdeguatezza {
    static let titolo = "Scheda di adeguatezza"
    /// Per `DocumentoStampabile`, il nome del file e i Documenti.
    static let genere = "Scheda di adeguatezza"
    static let occhiello = "Scheda di adeguatezza della proposta"

    // MARK: - Nomi

    static func titolo(_ t: ControlloAdeguatezza.Tipo) -> String {
        switch t {
        case .rischio: return "Rischio (SRI) e profilo"
        case .orizzonte: return "Periodo raccomandato e orizzonte"
        case .esperienza: return "Conoscenza ed esperienza"
        case .bisogno: return "Bisogno a cui risponde"
        case .liquidita: return "Liquidità e vincoli"
        case .concentrazione: return "Concentrazione dopo la firma"
        case .sostituzione: return "Sostituzione di un contratto"
        }
    }

    static func etichetta(_ s: Semaforo) -> String {
        switch s {
        case .verde: return "Coerente"
        case .giallo: return "Da motivare"
        case .rosso: return "Da rivedere"
        case .grigio: return "Da completare"
        }
    }

    static func complessivo(_ s: Semaforo) -> String {
        switch s {
        case .verde: return "Coerente con i dati raccolti"
        case .giallo: return "Coerente, con punti da motivare"
        case .rosso: return "Da rivedere prima di presentarla"
        case .grigio: return "Dati da completare"
        }
    }

    /// «4 coerenti · 1 da motivare · 1 da completare» (le parti a zero non si scrivono; ordine verde, giallo, grigio, rosso).
    static func conteggio(_ e: EsitoAdeguatezza) -> String {
        conteggio(verdi: e.conta(.verde), gialli: e.conta(.giallo), grigi: e.conta(.grigio), rossi: e.conta(.rosso))
    }

    static func conteggio(verdi: Int, gialli: Int, grigi: Int, rossi: Int) -> String {
        var parti: [String] = []
        if verdi > 0 { parti.append("\(verdi) \(verdi == 1 ? "coerente" : "coerenti")") }
        if gialli > 0 { parti.append("\(gialli) da motivare") }
        if grigi > 0 { parti.append("\(grigi) da completare") }
        if rossi > 0 { parti.append("\(rossi) da rivedere") }
        return parti.isEmpty ? "Nessun controllo" : parti.joined(separator: " · ")
    }

    /// «Denis Vicenzoni · Consulente Alleanza Assicurazioni» o «Denis Vicenzoni · Consulenza finanziaria».
    static func consulente(_ c: Canale) -> String {
        switch c {
        case .alleanza: return "Denis Vicenzoni · Consulente Alleanza Assicurazioni"
        case .indipendente: return "Denis Vicenzoni · Consulenza finanziaria"
        }
    }

    /// Un collegamento in parole, per i menu e i suggerimenti.
    static func descrizione(_ c: CollegamentoBisogno, bisogni: [BisognoRilevato], obiettivi: [Obiettivo]) -> String {
        switch c {
        case .rilevato(let id): return bisogni.first { $0.id == id }?.titolo ?? "Bisogno non più rilevato"
        case .area(let a): return "Area \(a.nome)"
        case .obiettivo(let id): return obiettivi.first { $0.id == id }?.titolo ?? "Obiettivo non più presente"
        }
    }

    // MARK: - Controlli non pertinenti

    static let esclusoRischio = "Le coperture non hanno un indicatore di rischio d'investimento."
    static let esclusoOrizzonte = "Una copertura dura quanto il contratto: conta che il premio sia sostenibile."
    static let esclusoEsperienza = "Tipo di prodotto non classificato."
    static let esclusoConcentrazione = "Le coperture non entrano nel patrimonio finanziario."
    static let esclusoSostituzione = "La proposta non sostituisce una posizione in essere."

    // MARK: - 1 · Rischio

    static let rischioSenzaProfilo = "Propensione al rischio non indicata nel profilo del cliente."

    static func rischio(_ s: Int, massimo: Int, propensione pr: ProfiloInvestitore.Propensione, entro: Bool) -> String {
        "SRI \(s) su 7, \(entro ? "entro" : "oltre") il \(massimo) di un profilo \(pr.nome.lowercased())."
    }

    static func rischioStimato(_ s: Int) -> String {
        "SRI stimato \(s) su 7: non è indicato, riportalo dal KID."
    }

    static func rischioMultiramo(_ sriFondi: Int) -> String {
        "Multiramo: conta l'SRI della combinazione scelta; i soli fondi hanno SRI \(sriFondi)."
    }

    // MARK: - 2 · Orizzonte

    static let orizzonteSenzaProfilo = "Orizzonte temporale non indicato nel profilo del cliente."
    static let orizzonteSenzaPeriodo = "Periodo raccomandato del KID non indicato."
    static let previdenzaSenzaEta = "Età del cliente non indicata: non si sa quanti anni mancano alla pensione."

    static func orizzonte(_ n: Int, h: Int, entro: Bool) -> String {
        entro ? "Periodo raccomandato di \(anni(n)), entro l'orizzonte di \(anni(h)) del cliente."
              : "Periodo raccomandato di \(anni(n)), più lungo dell'orizzonte di \(anni(h)) del cliente."
    }

    static func orizzonteDurata(_ d: Int, h: Int) -> String {
        "Periodo raccomandato non indicato: la durata del contratto è di \(anni(d)), \(d <= h ? "entro" : "oltre") l'orizzonte di \(anni(h))."
    }

    static func previdenza(anniPensione a: Int, partecipazione pt: Int, ok: Bool) -> String {
        if ok {
            return "Alla pensione mancano \(anni(a)): \(anni(pt)) di partecipazione contando le forme già aperte, oltre i \(MotoreAdeguatezza.anniMinimiPrevidenza) richiesti."
        }
        return "Alla pensione mancano \(anni(a)): con meno di \(MotoreAdeguatezza.anniMinimiPrevidenza) anni di partecipazione la prestazione pensionistica complementare potrebbe non spettare subito (si può continuare a versare)."
    }

    /// «1 anno», «12 anni».
    static func anni(_ n: Int) -> String { n == 1 ? "1 anno" : "\(n) anni" }

    // MARK: - 3 · Esperienza

    static let esperienzaNonRilevata = "Esperienza con questo tipo di prodotto non rilevata."
    static let capacitaNonIndicata = "Capacità di sostenere perdite non indicata."
    static let tipoStimato = "Il tipo è ricavato dai dati della posizione: indica la tipologia per esserne certo."

    static func perdita(_ s: PerditaStimata) -> String {
        guard let anno = s.anno else { return "Nelle crisi del passato considerate non avrebbe perso valore." }
        return "Nella crisi del \(anno) avrebbe perso circa il \(CifreDoc.percento(s.percento, decimali: 0)) (\(CifreDoc.euro(s.euro)) su \(CifreDoc.euro(s.capitale)))."
    }

    // MARK: - 4 · Bisogno

    static let bisognoAssente = "Indica a quale bisogno o obiettivo del cliente risponde la proposta."
    static let obiettivoSparito = "L'obiettivo scelto non c'è più: scegline un altro."

    static func bisognoSuggerito(_ descrizione: String) -> String {
        "Prisma suggerisce «\(descrizione)»: confermalo nella scheda."
    }

    static func bisognoScartato(_ titolo: String?) -> String {
        guard let titolo else { return "Il bisogno scelto è stato scartato con il cliente." }
        return "Il bisogno «\(titolo)» è stato scartato con il cliente."
    }

    static func bisognoDaConfermare(_ titolo: String?) -> String {
        guard let titolo else { return "Il bisogno scelto non è più tra quelli rilevati: scegline un altro." }
        return "Il bisogno «\(titolo)» è stato rilevato da Prisma ma non è ancora confermato con il cliente."
    }

    static func bisognoNonTipico(_ area: AreaPosizione, _ bisogno: AreaBisogno) -> String {
        "\(area.nome) non è tra le soluzioni tipiche dell'area «\(bisogno.nome)»: motiva il collegamento."
    }

    static func areaPocoImportante(_ a: AreaBisogno, _ importanza: Importanza) -> String {
        let imp = importanza == .nessuna ? "non indicata" : "bassa"
        return "Area «\(a.nome)» di importanza \(imp) per il cliente: motiva perché proporla adesso."
    }

    static func rispondeArea(_ a: AreaBisogno, _ importanza: Importanza) -> String {
        "Risponde all'area «\(a.nome)», di importanza \(importanza.nome.lowercased()) per il cliente."
    }

    static func rispondeBisogno(_ titolo: String?) -> String {
        guard let titolo else { return "Risponde a un bisogno confermato con il cliente." }
        return "Risponde al bisogno confermato «\(titolo)»."
    }

    static func rispondeObiettivo(_ o: Obiettivo?) -> String {
        guard let o else { return "Lavora per un obiettivo del cliente." }
        return "Lavora per l'obiettivo «\(o.titolo)»: \(CifreDoc.euro(o.importo)) entro il \(CifreDoc.dataBreve(o.scadenza))."
    }

    // MARK: - 5 · Liquidità

    static let liquiditaAssente = "Liquidità del cliente non indicata nelle Posizioni."
    static let riservaAssente = "Fabbisogno mensile non indicato nell'Analisi 360: la riserva non si può misurare."
    static let fonteRipiegata = "Indica la posizione sostituita: intanto il versamento si conta dalla liquidità."
    static let vincoloPrevidenza = "Previdenza: i versamenti restano vincolati fino alla pensione, salvo anticipazioni e riscatti previsti dalla legge (D.Lgs. 252/2005, artt. 11 e 14)."

    static func liquiditaNonBasta(oggi: Double, uso: Double) -> String {
        "La liquidità di oggi (\(CifreDoc.euro(oggi))) non basta per il versamento di \(CifreDoc.euro(uso))."
    }

    static func restaMenoMeta(_ resta: Double, riserva: Double) -> String {
        "Dopo il versamento restano \(CifreDoc.euro(resta)): meno di metà della riserva di emergenza di \(CifreDoc.euro(riserva))."
    }

    static func restaMenoRiserva(_ resta: Double, riserva: Double, mesi: Int) -> String {
        "Dopo il versamento restano \(CifreDoc.euro(resta)), meno della riserva di emergenza di \(CifreDoc.euro(riserva)) (\(mesi) \(mesi == 1 ? "mese" : "mesi") di spese)."
    }

    static func restaSenzaObiettivi(_ resta: Double, riserva: Double, vicini: Double) -> String {
        "Restano \(CifreDoc.euro(resta)): la riserva di \(CifreDoc.euro(riserva)) c'è, non tutti gli obiettivi dei prossimi \(MotoreAdeguatezza.mesiObiettiviVicini) mesi (\(CifreDoc.euro(vicini)))."
    }

    static func restaBasta(_ resta: Double, riserva: Double, vicini: Double) -> String {
        let obiettivi = vicini > 0 ? " e gli obiettivi vicini (\(CifreDoc.euro(vicini)))" : ""
        return "Dopo il versamento restano \(CifreDoc.euro(resta)): coprono la riserva di \(CifreDoc.euro(riserva))\(obiettivi)."
    }

    /// L8: `mesi` nil = previdenza (vincolo fino alla pensione).
    static func vincolato(mesi: Int?) -> String {
        guard let mesi else {
            return "Il versamento resta vincolato fino alla pensione e la liquidità che resta non basta."
        }
        return "Il versamento iniziale resta vincolato per \(mesi) \(mesi == 1 ? "mese" : "mesi") (riscatto non consentito) e la liquidità che resta non basta."
    }

    static func versamenti(_ premioAnnuo: Double, quota: Double, soglia: Double) -> String {
        "Versamenti di \(CifreDoc.euro(premioAnnuo)) l'anno: il \(CifreDoc.percento(quota, decimali: 0)) del reddito netto (oltre il \(CifreDoc.percento(soglia, decimali: 0)))."
    }

    static func capitaleDa(_ f: FonteCapitale) -> String {
        "Capitale iniziale da: \(f.nome.lowercased())."
    }

    static func ipotesiDaConfermare(fabbisogno: Double, mesi: Int) -> String {
        "Riserva calcolata con le ipotesi dell'Analisi 360 non ancora confermate (\(CifreDoc.euro(fabbisogno)) al mese per \(mesi) \(mesi == 1 ? "mese" : "mesi"))."
    }

    /// «Penali di riscatto: 2,5% nel 2° anno, 2% nel 3°, 1,5% nel 4°.»
    static func penali(_ elenco: [(anno: Int, penale: Double)]) -> String {
        let parti = elenco.enumerated().map { i, x in
            "\(CifreDoc.condizione(x.penale)) nel \(x.anno)°\(i == 0 ? " anno" : "")"
        }
        return "Penali di riscatto: \(parti.joined(separator: ", "))."
    }

    static func deducibilita(eccedenza: Double, limite: Double) -> String {
        "\(CifreDoc.euro(eccedenza)) l'anno oltre il limite deducibile di \(CifreDoc.euro(limite)) (TUIR art. 10, c. 1, lett. e-bis; D.Lgs. 252/2005, art. 8, c. 4): la parte in più non si deduce."
    }

    // MARK: - 6 · Concentrazione

    static let emittenteAssente = "Indica l'emittente della proposta."

    static var importiPiccoli: String {
        "Importi sotto \(CifreDoc.euro(MotoreCoerenza.minimoConcentrazione)): la concentrazione non si misura."
    }

    static func emittenteAlto(_ nome: String, quota: Double, aumento: Double) -> String {
        "Dopo la firma \(nome) pesa il \(CifreDoc.percento(quota, decimali: 0)) del patrimonio finanziario: oltre il \(CifreDoc.percento(MotoreAdeguatezza.sogliaEmittenteAlta, decimali: 0)), e la proposta aggiunge \(CifreDoc.percento(aumento, decimali: 0).replacingOccurrences(of: "%", with: "")) punti."
    }

    static func emittenteOltre(_ nome: String, quota: Double) -> String {
        "Dopo la firma \(nome) pesa il \(CifreDoc.percento(quota, decimali: 0)) del patrimonio finanziario: oltre il \(CifreDoc.percento(MotoreCoerenza.sogliaEmittente, decimali: 0)), valuta se diversificare."
    }

    static func emittentePeso(_ nome: String, quota: Double) -> String {
        "Dopo la firma \(nome) pesa il \(CifreDoc.percento(quota, decimali: 0)) del patrimonio finanziario."
    }

    static func primaDopo(_ prima: Double, _ dopo: Double) -> String {
        "Prima \(CifreDoc.percento(prima, decimali: 0)), dopo \(CifreDoc.percento(dopo, decimali: 0))."
    }

    static func canaleAlleanza(_ quota: Double) -> String {
        "Nel canale Alleanza il \(CifreDoc.percento(quota, decimali: 0)) del patrimonio finanziario, oltre l'\(CifreDoc.percento(MotoreCoerenza.sogliaCanale, decimali: 0)): Alleanza colloca i prodotti di una sola compagnia."
    }

    // MARK: - 7 · Sostituzione

    static let riscattoPrevidenza = "Dalla previdenza si esce verso un prodotto non previdenziale solo con un riscatto nei casi dell'art. 14 del D.Lgs. 252/2005 (per esempio la perdita dei requisiti di partecipazione); per cause diverse da invalidità, inoccupazione, mobilità o cassa integrazione la parte imponibile è tassata al 23%, e si perdono gli anni di partecipazione e la deducibilità futura."
    static let trasferimento = "Trasferimento tra forme di previdenza complementare: nessuna imposta, gli anni di partecipazione restano."
    static let coperturaNuova = "Una copertura nuova può avere carenze, esclusioni e un premio legato all'età di oggi: tieni quella in essere finché la nuova non è attiva."

    static func uscitaCara(_ costi: Double, percentuale: Double) -> String {
        "Uscire oggi costa \(CifreDoc.euro(costi)), il \(CifreDoc.percento(percentuale, decimali: 1)) del valore: oltre il \(CifreDoc.condizione(MotoreAdeguatezza.uscitaEccessiva))."
    }

    static func nonRecupera(anni n: Int) -> String {
        "Nei \(anni(n)) del confronto il cambio non recupera i costi dell'uscita."
    }

    static func uscita(_ costi: Double, percentuale: Double, pareggio: Int) -> String {
        if costi < 0.5 {
            return "Uscire oggi non costa penali né ingresso; il cambio recupera dal \(pareggio)° anno."
        }
        return "Uscire oggi costa \(CifreDoc.euro(costi)) (\(CifreDoc.percento(percentuale, decimali: 1)) del valore); il cambio recupera dal \(pareggio)° anno."
    }

    static func sostituzioneCopertura(_ a: Posizione) -> String {
        "Sostituisce «\(a.nome)»: confronta garanzie, esclusioni e premio prima di disdire la copertura in essere."
    }

    static func vociCosti(penale: Double, bollo: Double, ingresso: Double) -> String {
        var parti: [String] = []
        if penale >= 0.5 { parti.append("penale \(CifreDoc.euro(penale))") }
        if bollo >= 0.5 { parti.append("bollo maturato \(CifreDoc.euro(bollo))") }
        if ingresso >= 0.5 { parti.append("ingresso nel nuovo prodotto \(CifreDoc.euro(ingresso))") }
        return "Costi dell'uscita: \(parti.joined(separator: ", "))."
    }

    static func imposteAnticipate(_ imposta: Double) -> String {
        "Imposte pagate oggi invece che alla fine: \(CifreDoc.euro(imposta))."
    }

    static func garanzie(_ perse: [String]) -> String {
        "Si perdono: \(perse.joined(separator: "; "))."
    }

    static func pareggioTardo(_ pareggio: Int, anni n: Int) -> String {
        "Il cambio recupera solo dal \(pareggio)° anno, oltre metà del periodo di \(anni(n))."
    }

    static func scadePresto(_ nome: String, scadenza: Date) -> String {
        "\(nome) scade il \(CifreDoc.dataBreve(scadenza)): alla scadenza non ci sono penali, valuta se attendere."
    }

    static func cambioCanale(_ sostituita: Posizione, _ p: Posizione) -> String {
        "Cambio di canale: «\(sostituita.nome)» è \(sostituita.canale.nomeBreve), la proposta è \(p.canale.nomeBreve). Motiva per iscritto perché il cambio conviene al cliente: lo stesso consulente opera nei due canali (conflitto d'interessi: MiFID II art. 23, IDD art. 28)."
    }

    // Garanzie perse
    static let persoCapitaleGarantito = "il capitale garantito della gestione separata"
    static let persoConsolidamento = "il consolidamento annuo dei rendimenti"

    static func persoMinimo(_ m: Double) -> String {
        "il rendimento minimo garantito \(del(CifreDoc.condizione(m))) l'anno"
    }

    static func persaCopertura(_ r: RischioCoperto, capitale: Double) -> String {
        "la copertura \(r.nome.lowercased()) di \(CifreDoc.euro(capitale))"
    }

    static func persiAnniPrevidenza(_ n: Int) -> String {
        "gli anni di partecipazione alla previdenza (\(n))"
    }

    /// «del 2%», ma «dell'1%», «dell'8%», «dell'11%» (come si legge il numero).
    static func del(_ numero: String) -> String {
        let elisione = numero.hasPrefix("8") || numero.hasPrefix("11")
            || (numero.hasPrefix("1") && !(numero.dropFirst().first?.isNumber ?? false))
        return elisione ? "dell'\(numero)" : "del \(numero)"
    }

    // MARK: - Fonti

    static let premessaRiferimenti = "Riferimenti da verificare sul testo vigente."

    /// Il riferimento normativo breve e le soglie di un controllo (aiuto della riga e pagina 1 del PDF).
    static func fonte(_ t: ControlloAdeguatezza.Tipo, ambito: AmbitoNormativo?) -> String {
        switch t {
        case .rischio:
            return TestiEsperienza.fonte(ambito ?? .mifid) + " Soglie di Prisma: prudente fino a 2, moderata 3, dinamica 5."
        case .orizzonte:
            if ambito == .previdenza {
                return TestiEsperienza.fonte(.previdenza) + " D.Lgs. 252/2005, art. 11, c. 2 (cinque anni di partecipazione)."
            }
            return TestiEsperienza.fonte(ambito ?? .mifid) + " Periodo di detenzione raccomandato: Reg. UE 1286/2014 (PRIIPs) e Reg. delegato UE 2017/653."
        case .esperienza:
            return TestiEsperienza.fonte(ambito ?? .mifid)
        case .bisogno:
            return "Richieste ed esigenze: IDD (Dir. UE 2016/97) art. 20; Codice delle assicurazioni private art. 119-ter. Obiettivi d'investimento: Reg. delegato UE 2017/565, art. 54, par. 2."
        case .liquidita:
            let base = "Situazione finanziaria: Reg. delegato UE 2017/565, art. 54, par. 4; Reg. delegato UE 2017/2359, art. 9. Soglie di Prisma: metà della riserva, versamenti oltre il 20% e il 35% del reddito netto."
            return ambito == .previdenza ? base + " D.Lgs. 252/2005, artt. 8, 11 e 14; TUIR art. 10, c. 1, lett. e-bis." : base
        case .concentrazione:
            return "Portafoglio nel suo insieme: Orientamenti ESMA sull'adeguatezza (2022). Soglie di Prisma: 50% e 75% per emittente, 80% nel canale Alleanza."
        case .sostituzione:
            return "Cambio di investimento: Reg. delegato UE 2017/565, art. 54, par. 11 (benefici superiori ai costi). Polizze: Regolamento IVASS n. 40/2018. Cambio di canale: conflitti d'interessi, MiFID II art. 23 e IDD art. 28. Soglie di Prisma: 1% e 3% del valore."
        }
    }

    // MARK: - Avvertenze, dichiarazioni e metodo

    static let avvertenzaBreve = "Scheda di lavoro del consulente: non è un parere legale né la valutazione di adeguatezza ufficiale."

    static let avvertenza = "Scheda di lavoro del consulente, preparata da Prisma con i dati raccolti nel dossier. Riassume i controlli di coerenza della proposta con il profilo, i bisogni e la situazione del cliente. Non è un parere legale e non sostituisce il questionario e la valutazione di adeguatezza dell'intermediario o della compagnia, né la documentazione precontrattuale e contrattuale del prodotto. Le soglie sono di Prisma; i riferimenti normativi vanno verificati sul testo vigente."

    static let dichiarazioni = [
        "Il cliente dichiara di aver ricevuto, prima della firma, i documenti spuntati in questa scheda.",
        "Il cliente conferma che le informazioni sul profilo, sui bisogni e sulla situazione finanziaria usate qui sono aggiornate e complete.",
    ]

    static var metodo: [String] {
        [
            "Rischio: l'SRI del KID (per le multiramo a due parti quello della combinazione) entro il massimo del profilo: prudente 2, moderata 3, dinamica 5, aggressiva 7. Senza SRI Prisma lo stima e il controllo resta da motivare.",
            "Orizzonte: il periodo di detenzione raccomandato entro l'orizzonte del cliente; senza periodo conta la durata del contratto (da motivare). Previdenza: almeno \(MotoreAdeguatezza.anniMinimiPrevidenza) anni di partecipazione alla pensione, contando le forme già aperte.",
            "Esperienza: la griglia per tipo di prodotto (non conosce = da rivedere, da spiegare = da motivare) e la perdita nella crisi peggiore del passato contro la capacità di sostenere perdite.",
            "Bisogno: il bisogno confermato, l'area della mappa o l'obiettivo a cui risponde, compatibile con l'area della proposta; un suggerimento di Prisma resta da confermare, un bisogno scartato con il cliente è da rivedere.",
            "Liquidità: dopo il versamento dalla liquidità devono restare la riserva di emergenza (fabbisogno mensile per i mesi di riserva) e gli obiettivi dei prossimi \(MotoreAdeguatezza.mesiObiettiviVicini) mesi; sotto metà della riserva è da rivedere, anche con il riscatto bloccato. Versamenti oltre il \(CifreDoc.percento(MotoreAdeguatezza.premioAttenzione, decimali: 0)) del reddito netto da motivare, oltre il \(CifreDoc.percento(MotoreAdeguatezza.premioEccessivo, decimali: 0)) da rivedere.",
            "Concentrazione: il peso dell'emittente sul patrimonio finanziario dopo la firma, oltre il \(CifreDoc.percento(MotoreCoerenza.sogliaEmittente, decimali: 0)) da motivare, oltre il \(CifreDoc.percento(MotoreAdeguatezza.sogliaEmittenteAlta, decimali: 0)) con almeno \(Int(MotoreAdeguatezza.aumentoRilevante)) punti in più da rivedere (da \(CifreDoc.euro(MotoreCoerenza.minimoConcentrazione)) in su); oltre l'\(CifreDoc.percento(MotoreCoerenza.sogliaCanale, decimali: 0)) nel canale Alleanza da motivare.",
            "Sostituzione: costi dell'uscita (penale, bollo maturato, ingresso) oltre l'1% del valore da motivare, oltre il 3% da rivedere; da rivedere anche se il cambio non recupera i costi nel periodo o se si riscatta la previdenza; garanzie perse, recupero oltre metà del periodo e cambio di canale da motivare.",
            "Complessivo: rosso se un controllo è da rivedere; poi da completare; poi da motivare; altrimenti coerente. La scheda è pronta per la firma senza rossi né grigi e con tutti i documenti spuntati o non pertinenti.",
        ]
    }
}

/// Tutto ciò che stampa il PDF, già pronto: righe dei controlli (dal vivo o registrate alla firma),
/// esperienza, documenti, consulente e date.
struct PaginaDatiAdeguatezza {
    struct Riga {
        let tipo: ControlloAdeguatezza.Tipo
        let titolo: String
        let semaforo: Semaforo
        let esito: String
        let dettagli: [String]
        let fonte: String
    }

    let esito: EsitoAdeguatezza
    let scheda: SchedaAdeguatezza?
    let cliente: String
    /// `MotoreEsperienza.righe(...)`: sempre sette righe.
    let esperienza: [RigaEsperienza]
    let capacita: CapacitaPerdite?
    /// true se la griglia dell'esperienza è compilata.
    let esperienzaRilevata: Bool
    /// La frase del bisogno (B8/B2…) o «Non indicato».
    let collegamento: String
    /// Il periodo di detenzione raccomandato (della posizione o della scheda prodotto), per le cifre del PDF.
    let periodo: Int?
    /// `firmataIl ?? oggi`.
    let data: Date

    var proposta: Posizione { esito.proposta }
    var piede: String { "\(TestiAdeguatezza.genere) · \(cliente) · \(proposta.nome)" }
    var firmata: Bool { scheda?.firmata == true }

    /// Firmata: semaforo ed esito registrati alla firma (tipo sconosciuto → saltato), dettagli e fonte dal vivo
    /// se il tipo c'è ancora. Non firmata: dal vivo.
    var righe: [Riga] {
        guard let scheda, scheda.firmata, let registrati = scheda.esitiAllaFirma else {
            return esito.controlli.map {
                Riga(tipo: $0.tipo, titolo: TestiAdeguatezza.titolo($0.tipo), semaforo: $0.semaforo, esito: $0.esito,
                     dettagli: $0.dettagli, fonte: $0.fonte)
            }
        }
        return registrati.compactMap { r -> Riga? in
            guard let t = ControlloAdeguatezza.Tipo(rawValue: r.controllo) else { return nil }
            let vivo = esito.controllo(t)
            return Riga(tipo: t, titolo: TestiAdeguatezza.titolo(t), semaforo: Semaforo(rawValue: r.semaforo) ?? .grigio,
                        esito: r.esito, dettagli: vivo?.dettagli ?? [],
                        fonte: vivo?.fonte ?? TestiAdeguatezza.fonte(t, ambito: esito.tipoProdotto?.ambito))
        }
    }

    var complessivo: Semaforo { MotoreAdeguatezza.complessivo(righe.map(\.semaforo)) }

    /// «4 coerenti · 1 da motivare», contato sulle righe stampate.
    var conteggio: String {
        let r = righe
        // Un conteggio per colore, fuori dalla chiamata (quattro chiusure insieme appesantiscono il controllo dei tipi)
        func conta(_ s: Semaforo) -> Int { r.filter { $0.semaforo == s }.count }
        return TestiAdeguatezza.conteggio(verdi: conta(.verde), gialli: conta(.giallo), grigi: conta(.grigio), rossi: conta(.rosso))
    }
}
