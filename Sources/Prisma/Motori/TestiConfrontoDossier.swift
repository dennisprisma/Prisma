import Foundation

/// I testi del confronto «Nel documento / In Prisma» (specifica 9 del giro 5, §6), con i formati delle celle, i testi
/// dell'impatto di un nuovo KID, dello storico e degli avvisi, e le fonti normative.
enum TestiConfrontoDossier {
    /// Una cella vuota.
    static let vuoto = "—"

    // MARK: - Scheda e testata

    /// Il titolo della scheda nel dettaglio di Documenti: «Confronto» oppure «Confronto · N».
    static func scheda(differenze: Int) -> String {
        differenze > 0 ? "Confronto · \(differenze)" : "Confronto"
    }

    static let occhiello = "DOCUMENTO CONTRO DOSSIER"
    /// Occhiello di `TitoloStrumento` nella testata del confronto.
    static let occhielloTitolo = "Documento contro dossier"
    static func titoloPosizione(_ nome: String) -> String { "Confronto con la posizione «\(nome)»" }
    static func titoloProdotto(_ nome: String) -> String { "Confronto con la scheda prodotto «\(nome)»" }
    static func titoloAppendice(_ nome: String) -> String { "L'appendice rispetto alla posizione «\(nome)»" }
    static let sottotitolo = "Solo i dati confermati del documento. Scegli quelli da portare in Prisma: i valori di prima restano nello storico e si possono ripristinare."

    // MARK: - Tabella

    static let colonnaDato = "Dato"
    static let colonnaDocumento = "Nel documento"
    static let colonnaPrisma = "In Prisma"
    static let colonnaEsito = "Esito"

    static let esitoUguale = "Uguale"
    static let esitoDiverso = "Diverso"
    static let esitoSale = "Sale"
    static let esitoScende = "Scende"
    static let esitoNuovo = "Nuovo dato"
    static let esitoTenuto = "Lasciato in Prisma"
    static let esitoDaConfermare = "Da confermare"
    static let esitoIlleggibile = "Non leggibile"

    /// Il testo della pillola «Esito» di una riga.
    static func esito(_ r: RigaDossier) -> String {
        switch r.esito {
        case .uguale: return esitoUguale
        case .diverso:
            guard let d = r.differenza, abs(d) > 0.000_5 else { return esitoDiverso }
            return d > 0 ? esitoSale : esitoScende
        case .nuovo: return esitoNuovo
        case .tenuto: return esitoTenuto
        case .daConfermare: return esitoDaConfermare
        case .illeggibile: return esitoIlleggibile
        }
    }

    /// La pillola della testata: «1 differenza», «N differenze».
    static func pillola(differenze n: Int) -> String { n == 1 ? "1 differenza" : "\(n) differenze" }
    static let tuttoAllineato = "Tutto allineato"
    static let nessunDatoConfermato = "Nessun dato confermato"

    /// «Il documento non riporta: premio, scadenza e rischio (SRI).»
    static func nonRiporta(_ voci: [VoceDossier]) -> String {
        "Il documento non riporta: \(elenco(voci.map { nomeMinuscolo($0) }))."
    }

    static let nessunDato = "Nessun dato da confrontare: conferma i dati nella scheda «Dati»."

    // MARK: - Pulsanti e azioni

    static func aggiornaScelti(_ n: Int) -> String { n == 1 ? "Aggiorna 1 dato scelto" : "Aggiorna \(n) dati scelti" }
    static let lasciaComeInPrisma = "Lascia come in Prisma"
    static let riportaTraLeDifferenze = "Riporta tra le differenze"
    static let scegliTutte = "Scegli tutte le differenze"
    static let apri = "Apri ↗"
    static let scollega = "Scollega"
    static let collegaEConfronta = "Collega e confronta"
    static let collega = "Collega"
    static let ripristina = "Ripristina"
    static func mostraTutti(_ n: Int) -> String { "Mostra tutti (\(n))" }
    static let creaAttivita = "Crea un'attività per ciascun cliente"
    static let vediConfronto = "Vedi il confronto ↗"
    /// Le due viste del bersaglio quando il documento è collegato a scheda e posizione.
    static let segmentoProdotto = "Scheda prodotto"
    static let segmentoPosizione = "Posizione"

    static func ancheProposte(_ n: Int) -> String {
        n == 1 ? "Aggiorna anche 1 proposta aperta di questo prodotto" : "Aggiorna anche \(n) proposte aperte di questo prodotto"
    }

    static let notaAggiorna = "Cambiano solo i dati scelti. Quelli lasciati come in Prisma non contano più tra le differenze di questo documento, finché uno dei due valori non cambia."

    // MARK: - Note delle righe

    static let notaBeneficiari = "Prisma registra i beneficiari scritti nel documento; la designazione vale solo se comunicata alla compagnia (artt. 1920 e 1921 c.c.)."

    static func notaLordo(_ f: MotoreConfrontoDossier.FonteLordo) -> String {
        switch f {
        case .stima:
            return "Stima di Prisma: il rendimento lordo che, con i costi del KID, rifà lo scenario moderato. Lo scenario è al netto dei costi e non è una previsione (Reg. delegato UE 2017/653)."
        case .kid:
            return "Dal KID: rendimento medio annuo prima dei costi nello scenario moderato. Non è una previsione."
        }
    }

    static let notaMultiramo = "Multiramo a due parti: i costi correnti del KID sono della combinazione; in Prisma il costo annuo vale per la parte in fondi."
    static let notaRateDiverse = "Stessa cifra all'anno, rate diverse."

    static func notaFrequenzaDedotta(_ f: Frequenza) -> String {
        "La frequenza non è scritta accanto al premio: considerata \(f.nome.lowercased())."
    }

    // MARK: - Collegamento

    static let occhielloCollega = "Dal documento al dossier"
    static let titoloCollega = "Collega il documento"
    static let introCollega = "Collega il documento alla posizione o alla scheda prodotto che hai già: Prisma confronta i dati e aggiorna solo quelli che scegli."

    static func sembra(_ nome: String) -> String { "Sembra «\(nome)»" }

    static func motivo(_ m: MotoreConfrontoDossier.MotivoCollegamento) -> String {
        switch m {
        case .collegamento: return "già collegato"
        case .numeroContratto: return "dal numero di polizza"
        case .nome: return "dal nome del prodotto"
        case .nomeEdEmittente: return "dal nome e dalla compagnia"
        }
    }

    /// L'etichetta di una candidata nel menu: «nome · Alleanza».
    static func etichettaCandidata(nome: String, canale: Canale) -> String { "\(nome) · \(canale.nomeBreve)" }

    static func nessunaCandidata(kid: Bool) -> String {
        kid ? "Nessuna scheda prodotto da confrontare: creala con «Crea… › Scheda prodotto» in alto."
            : "Il cliente non ha posizioni da confrontare: creala con «Crea… › Posizione in essere» in alto."
    }

    // MARK: - Impatto del nuovo KID

    static let occhielloImpatto = "IMPATTO DEL NUOVO KID"

    /// «Il nuovo KID alza il rischio da 4 a 5 su 7 e i costi correnti da 0,2% a 0,25%.»
    static func fraseAumenti(_ a: [AumentoKID]) -> String {
        frammentiAumenti(a).map { $0.testo }.joined()
    }

    /// La stessa frase a pezzi: `cifra` segna i valori nuovi, da colorare dentro la frase (`Text` concatenati).
    static func frammentiAumenti(_ a: [AumentoKID]) -> [(testo: String, cifra: Bool)] {
        var pezzi: [(testo: String, cifra: Bool)] = [(testo: "Il nuovo KID alza ", cifra: false)]
        pezzi += frammentiElenco(a)
        pezzi.append((testo: ".", cifra: false))
        return pezzi
    }

    /// «il rischio da 4 a 5 su 7, i costi correnti da 0,2% a 0,25% e l'incidenza dei costi da 0,2% a 0,25%»
    static func elencoAumenti(_ a: [AumentoKID]) -> String {
        frammentiElenco(a).map { $0.testo }.joined()
    }

    private static func frammentiElenco(_ a: [AumentoKID]) -> [(testo: String, cifra: Bool)] {
        var pezzi: [(testo: String, cifra: Bool)] = []
        for (i, x) in a.enumerated() {
            if i > 0 { pezzi.append((testo: i == a.count - 1 ? " e " : ", ", cifra: false)) }
            let prima: String
            let dopo: String
            let apertura: String
            var chiusura = ""
            switch x.voce {
            case .sri:
                apertura = "il rischio da "
                prima = "\(Int(x.prima.rounded()))"
                dopo = "\(Int(x.dopo.rounded()))"
                chiusura = " su 7"
            case .costoIngresso:
                apertura = "il costo d'ingresso da "
                prima = Formati.percentuale(x.prima)
                dopo = Formati.percentuale(x.dopo)
            case .costoGestione:
                apertura = "i costi correnti da "
                prima = Formati.percentuale(x.prima)
                dopo = Formati.percentuale(x.dopo)
            case .incidenzaCosti:
                apertura = "l'incidenza dei costi da "
                prima = Formati.percentuale(x.prima)
                dopo = Formati.percentuale(x.dopo)
            default:
                apertura = "\(nomeMinuscolo(x.voce)) da "
                prima = valore(ValoreVoce(numero: x.prima), x.voce)
                dopo = valore(ValoreVoce(numero: x.dopo), x.voce)
            }
            pezzi.append((testo: apertura + prima + " a ", cifra: false))
            pezzi.append((testo: dopo, cifra: true))
            if !chiusura.isEmpty { pezzi.append((testo: chiusura, cifra: false)) }
        }
        return pezzi
    }

    /// «2 clienti · 3 posizioni e proposte · circa 194 € l'anno di costi in più se il nuovo costo valesse per tutti».
    static func riepilogoImpatto(_ e: EsitoImpatto) -> String {
        let clienti = e.clienti.count == 1 ? "1 cliente" : "\(e.clienti.count) clienti"
        let posizioni = e.posizioni == 1 ? "1 posizione o proposta" : "\(e.posizioni) posizioni e proposte"
        var testo = "\(clienti) · \(posizioni)"
        if e.costoAnnuoInPiu >= 0.5 {
            testo += " · circa \(Formati.euro(e.costoAnnuoInPiu)) l'anno di costi in più se il nuovo costo valesse per tutti"
        }
        return testo
    }

    static func costoInPiu(_ euro: Double) -> String { "+\(importo(euro)) l'anno" }
    static func ingressoInPiu(_ euro: Double) -> String { "+\(importo(euro)) d'ingresso" }
    static func oltreProfilo(max: Int) -> String { "Oltre il profilo (max \(max))" }
    static let perNome = "per nome"
    static let inEssere = "In essere"

    /// La chip di una posizione toccata: «Proposta · presentata» o «In essere».
    static func chip(_ p: PosizioneToccata) -> String {
        guard p.stato == .proposta else { return inEssere }
        guard let esito = p.esito else { return "Proposta" }
        return "Proposta · \(esito.nome.lowercased())"
    }

    static let nessunClienteToccato = "Nessun cliente ha posizioni o proposte di questo prodotto."

    static let notaImpatto = "Le proposte aperte vanno presentate con il KID in vigore, consegnato prima della firma (Reg. UE 1286/2014, art. 13). Per i contratti in essere i costi cambiano solo se lo prevedono le condizioni o il regolamento: verifica con la compagnia o la SGR. L'ideatore riesamina il KID almeno ogni 12 mesi (Reg. UE 1286/2014, art. 10; Reg. delegato UE 2017/653, artt. 15 e 16); il distributore ne tiene conto nel monitoraggio dei prodotti (IDD art. 25, Reg. IVASS 45/2020; MiFID II art. 24, Regolamento Intermediari Consob)."
    static let titoloNotaImpatto = "Da sapere"

    /// Titolo dell'attività creata per un cliente.
    static func titoloAttivita(prodotto: String, cliente: String) -> String {
        "Nuovo KID di «\(prodotto)»: verificare con \(cliente)"
    }

    /// Note dell'attività: «Il KID importato il 29/10/2026 alza … Posizioni: ….»
    static func noteAttivita(il: Date, aumenti: [AumentoKID], posizioni: [PosizioneToccata]) -> String {
        let elencoPosizioni = posizioni.map { "\($0.nome) (\(chip($0).lowercased()))" }.joined(separator: ", ")
        return "Il KID importato il \(Formati.dataBreve.string(from: il)) alza \(elencoAumenti(aumenti)). Posizioni: \(elencoPosizioni)."
    }

    // MARK: - Storico

    static let occhielloStorico = "STORICO DEGLI AGGIORNAMENTI"
    static let titoloRipristino = "Ripristino del valore di prima"
    static let nessunaVariazione = "Nessun dato aggiornato dai documenti finora."

    /// «Capitale assicurato: 200.000 € → 150.000 €»
    static func rigaVariazione(_ v: VariazioneDossier) -> String {
        "\(nome(voce: v.voce)): \(v.prima) → \(v.dopo)"
    }

    /// «29 ottobre 2026 · da «Polizza Infortuni famiglia»», oppure il ripristino.
    static func dettaglioVariazione(_ v: VariazioneDossier) -> String {
        let data = Formati.dataEstesa.string(from: v.il)
        if v.ripristinoDi != nil || v.documentoId == nil { return "\(data) · \(titoloRipristino)" }
        return "\(data) · da «\(v.titoloDocumento)»"
    }

    // MARK: - Avvisi

    /// «Dato aggiornato in «X»: capitale assicurato», «3 dati aggiornati in «X»», poi « · anche N proposte aperte».
    static func avvisoAggiornati(_ n: Int, nome: String, proposte: Int, voce: VoceDossier? = nil) -> String {
        var testo: String
        if n == 1, let voce {
            testo = "Dato aggiornato in «\(nome)»: \(nomeMinuscolo(voce))"
        } else {
            testo = n == 1 ? "1 dato aggiornato in «\(nome)»" : "\(n) dati aggiornati in «\(nome)»"
        }
        if proposte > 0 { testo += proposte == 1 ? " · anche 1 proposta aperta" : " · anche \(proposte) proposte aperte" }
        return testo
    }

    /// Lo stesso avviso dalle variazioni registrate (con una sola, il nome della voce).
    static func avvisoAggiornati(_ variazioni: [VariazioneDossier], nome: String, proposte: Int) -> String {
        let voce = variazioni.count == 1 ? variazioni.first.flatMap { VoceDossier(rawValue: $0.voce) } : nil
        return avvisoAggiornati(variazioni.count, nome: nome, proposte: proposte, voce: voce)
    }

    /// «Ripristinato: capitale assicurato di «X»»
    static func avvisoRipristinato(voce: String, nome: String) -> String {
        let n = VoceDossier(rawValue: voce).map { nomeMinuscolo($0) } ?? voce
        return "Ripristinato: \(n) di «\(nome)»"
    }

    static func avvisoRipristinato(_ v: VariazioneDossier, nome: String) -> String {
        avvisoRipristinato(voce: v.voce, nome: nome)
    }

    static func avvisoCollegato(_ nome: String) -> String { "Documento collegato a «\(nome)»" }

    static func avvisoAttivita(_ n: Int) -> String {
        switch n {
        case 0: return "Le attività ci sono già"
        case 1: return "1 attività creata"
        default: return "\(n) attività create"
        }
    }

    // MARK: - Prodotti

    static let titoloAvvisoKID = "Nuovo KID: rischio o costi più alti"

    /// «Aggiornata il 29 ottobre 2026 da «KID …»: il rischio da 4 a 5 su 7 ….»
    static func avvisoKID(il: Date, titolo: String, aumenti: [AumentoKID]) -> String {
        "Aggiornata il \(Formati.dataEstesa.string(from: il)) da «\(titolo)»: \(elencoAumenti(aumenti))."
    }

    /// «e altri N» sotto i primi clienti dell'avviso.
    static func altriClienti(_ n: Int) -> String { "e altri \(n)" }

    static let titoloStoricoProdotto = "Aggiornamenti dai documenti"
    static func notaStoricoProdotto(_ n: Int) -> String { n == 1 ? "1 dato cambiato" : "\(n) dati cambiati" }

    // MARK: - Nomi e formati delle celle

    static func nome(_ v: VoceDossier) -> String {
        switch v {
        case .beneficiari: return "Beneficiari"
        case .premio: return "Premio"
        case .capitaleAssicurato: return "Capitale assicurato"
        case .scadenza: return "Scadenza"
        case .sri: return "Rischio (SRI)"
        case .periodoRaccomandato: return "Periodo raccomandato"
        case .costoIngresso: return "Costo d'ingresso"
        case .costoGestione: return "Costi correnti"
        case .incidenzaCosti: return "Incidenza annuale dei costi"
        case .rendimentoLordo: return "Rendimento lordo"
        }
    }

    /// Il nome di una voce salvata come stringa (una voce sconosciuta si mostra com'è).
    static func nome(voce raw: String) -> String {
        VoceDossier(rawValue: raw).map { nome($0) } ?? raw
    }

    /// Il nome dentro una frase.
    static func nomeMinuscolo(_ v: VoceDossier) -> String {
        switch v {
        case .sri: return "rischio (SRI)"
        default: return nome(v).lowercased()
        }
    }

    /// Il testo di una cella: «380 € l'anno», «premio unico 50.000 €», «150.000 €», «1 dicembre 2026», «4 su 7»,
    /// «7 anni», «0,95%», «4,34% lordo · stima»; vuoto «—».
    static func valore(_ x: ValoreVoce?, _ v: VoceDossier) -> String {
        guard let x else { return vuoto }
        switch v {
        case .beneficiari:
            guard let t = x.testo, !t.isEmpty else { return vuoto }
            return t
        case .scadenza:
            guard let d = x.data else { return vuoto }
            return Formati.dataEstesa.string(from: d)
        default:
            break
        }
        guard let n = x.numero else { return vuoto }
        switch v {
        case .premio:
            let f = x.frequenza.flatMap { Frequenza(rawValue: $0) } ?? .annuale
            if f == .unica { return "premio unico \(importo(n))" }
            return "\(importo(n)) \(suffisso(f))"
        case .capitaleAssicurato:
            return importo(n)
        case .sri:
            return "\(Int(n.rounded())) su 7"
        case .periodoRaccomandato:
            let a = Int(n.rounded())
            return a == 1 ? "1 anno" : "\(a) anni"
        case .costoIngresso, .costoGestione, .incidenzaCosti:
            return Formati.percentuale(n)
        case .rendimentoLordo:
            switch x.testo ?? "" {
            case MotoreConfrontoDossier.fonteKID: return "\(Formati.percentuale(n)) lordo · dal KID"
            case MotoreConfrontoDossier.fonteStima: return "\(Formati.percentuale(n)) lordo · stima"
            default: return "\(Formati.percentuale(n)) lordo"
            }
        case .beneficiari, .scadenza:
            return vuoto
        }
    }

    /// La differenza sotto la pillola: «+0,15 punti», «+1 classe», «−50.000 €», «+360 € l'anno», «+2 anni».
    /// nil per testi e date, per le righe uguali o senza differenza.
    static func differenza(_ r: RigaDossier) -> String? {
        guard r.esito != .uguale, let d = r.differenza, abs(d) > 0.000_5 else { return nil }
        let segno = d > 0 ? "+" : Formati.meno
        let a = abs(d)
        switch r.voce {
        case .beneficiari, .scadenza:
            return nil
        case .premio:
            if r.documento?.frequenza == Frequenza.unica.rawValue { return segno + importo(a) }
            return "\(segno)\(importo(a)) l'anno"
        case .capitaleAssicurato:
            return segno + importo(a)
        case .sri:
            let n = Int(a.rounded())
            return "\(segno)\(n) \(n == 1 ? "classe" : "classi")"
        case .periodoRaccomandato:
            let n = Int(a.rounded())
            return "\(segno)\(n) \(n == 1 ? "anno" : "anni")"
        case .costoIngresso, .costoGestione, .incidenzaCosti, .rendimentoLordo:
            let testo = Formati.numeroFormatter.string(from: NSNumber(value: a)) ?? "\(a)"
            return "\(segno)\(testo) \(testo == "1" ? "punto" : "punti")"
        }
    }

    /// Accanto all'importo del premio: «al mese», «a trimestre», «a semestre», «l'anno»; niente per il premio unico.
    static func suffisso(_ f: Frequenza) -> String {
        switch f {
        case .unica: return ""
        case .mensile: return "al mese"
        case .trimestrale: return "a trimestre"
        case .semestrale: return "a semestre"
        case .annuale: return "l'anno"
        }
    }

    /// Gli importi interi senza decimali, quelli con i centesimi con due decimali.
    static func importo(_ x: Double) -> String {
        abs(x - x.rounded()) > 0.004 ? Formati.euroDecimali(x) : Formati.euro(x)
    }

    /// «a, b e c»
    static func elenco(_ parti: [String]) -> String {
        guard parti.count > 1, let ultima = parti.last else { return parti.first ?? "" }
        return parti.dropLast().joined(separator: ", ") + " e " + ultima
    }

    // MARK: - Fonti

    /// Fonti normative e limiti dichiarati (specifica 9, §3.4).
    static let fonti = """
    KID PRIIPs: Reg. UE 1286/2014, art. 8 (contenuto), art. 10 (riesame e revisione da parte dell'ideatore), art. 13 \
    (consegna prima della sottoscrizione); Reg. delegato UE 2017/653, artt. 15 e 16 (riesame almeno ogni 12 mesi e \
    revisione), allegati II e III (SRI), IV e V (scenari, al netto dei costi), VI e VII (costi e incidenza annuale dei \
    costi), come modificato dal Reg. delegato UE 2021/2268, in vigore dal 1° gennaio 2023.
    Monitoraggio dei prodotti da parte del distributore: IDD, Dir. UE 2016/97 art. 25; Reg. delegato UE 2017/2358; \
    Codice delle assicurazioni private, art. 30-decies; Regolamento IVASS n. 45/2020. Per OICR ed ETF: MiFID II, \
    Dir. 2014/65/UE art. 16, par. 3, e art. 24, par. 2; Regolamento Intermediari Consob n. 20307/2018.
    Beneficiari: Codice civile, artt. 1920 e 1921: la designazione si fa e si revoca con dichiarazione alla compagnia o \
    per testamento. Prisma registra soltanto.
    Limiti: un nuovo KID vale per le nuove sottoscrizioni; per i contratti in essere i costi cambiano solo se lo prevedono \
    le condizioni o il regolamento del fondo, e il costo in più è una stima «se valesse anche per loro». Lo scenario \
    moderato è un rendimento netto (al netto di tutti i costi, prima delle imposte personali) e non una previsione: \
    Prisma lo confronta con il suo rendimento lordo solo dopo averlo riportato al lordo (stima) o usando il rendimento \
    «prima dei costi» che il KID scrive dal 2023 (Reg. delegato UE 2021/2268).
    """
}
