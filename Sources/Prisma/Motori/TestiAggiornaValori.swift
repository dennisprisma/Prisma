import Foundation

/// I testi del pannello «Aggiorna i valori» (Posizioni): funzioni pure, senza viste. Le prove li controllano
/// senza gli importi in euro (`Formati.euro` usa lo spazio non separabile).
enum TestiAggiornaValori {
    static let titolo = "Aggiorna i valori"
    static let occhiello = "POSIZIONI IN ESSERE"

    static func nomeScheda(_ s: AggiornaValori.Scheda) -> String {
        switch s {
        case .elenco: return "Da un elenco della compagnia"
        case .griglia: return "Valori fermi da 12 mesi"
        }
    }

    // MARK: - Formati con segno

    /// "+1.500 €", "−500 €", "0 €" (il «+» solo oltre mezzo euro).
    static func euroSegno(_ v: Double) -> String {
        if abs(v) < 0.5 { return Formati.euro(0) }
        return (v > 0.5 ? "+" : "") + Formati.euro(v)
    }

    private static let formatoPercentuale: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Formati.localeImporti
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        f.minusSign = Formati.meno
        return f
    }()

    /// Un decimale, con il segno: "+15,0%", "−2,5%", "0,0%".
    static func percentualeSegno(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        if r == 0 { return "\(formatoPercentuale.string(from: NSNumber(value: 0.0)) ?? "0,0")%" }
        let n = formatoPercentuale.string(from: NSNumber(value: r)) ?? "\(r)"
        return (r > 0 ? "+" : "") + n + "%"
    }

    /// Una percentuale senza segno, un decimale: "40,9%".
    static func percentuale(_ v: Double) -> String {
        "\(formatoPercentuale.string(from: NSNumber(value: (v * 10).rounded() / 10)) ?? "\(v)")%"
    }

    private static func data(_ d: Date) -> String { Formati.dataBreve.string(from: d) }

    // MARK: - Scheda «Da un elenco»

    static let vuota = "Porta in Prisma i valori di tutte le posizioni in una volta: un foglio Excel o un CSV della compagnia, con una riga per posizione, il numero di polizza (o il cliente e il prodotto) e il valore. Prisma abbina ogni riga alla sua posizione, ti mostra la variazione e mette il valore di prima nello storico."
    static let scegliFile = "Scegli il file…"
    static let incolla = "Incolla da Excel"

    static func intestazione(file: String, righe: Int, colonne: [ImportaPosizioni.Colonna]) -> String {
        "Da «\(file)»: \(righe) \(righe == 1 ? "riga" : "righe"). Colonne riconosciute: \(colonne.map(\.nome).joined(separator: ", "))."
    }

    static let proposta = "Quasi tutte le righe sono di posizioni già in Prisma: ti propongo di aggiornarne i valori. Per aggiungerle come posizioni nuove usa «Importa come posizioni nuove»."
    static let etichettaData = "Valori senza data al"
    static let filtroTutte = "Tutte"
    static func filtroDaControllare(_ n: Int) -> String { "Da controllare (\(n))" }

    static func pulsanteNonTrovate(_ n: Int) -> String {
        n == 1 ? "Importa come nuove la riga non trovata" : "Importa come nuove le \(n) righe non trovate"
    }

    static let importaComeNuove = "Importa come posizioni nuove"

    // MARK: - Indicatori

    static let kpiDaAggiornare = "Da aggiornare"
    static func notaDaAggiornare(posizioni p: Int) -> String { p == 1 ? "su 1 posizione" : "su \(p) posizioni" }
    static let kpiStorico = "Nello storico"
    static let notaStorico = "più vecchi del valore attuale"
    static let kpiVariazione = "Variazione"
    static func notaVariazione(_ t: AggiornaValori.Totale) -> String {
        "\(t.variazionePct.map(percentualeSegno) ?? "—") · al netto dei versamenti \(euroSegno(t.risultato))"
    }
    static let kpiDaControllare = "Da controllare"
    static let notaDaControllare = "da scegliere, insolite o non trovate"

    /// Riga per canale: «+2.900 € (+4,1%) su 2 posizioni · al netto dei versamenti +1.700 €».
    static func perCanale(_ t: AggiornaValori.Totale) -> String {
        let pct = t.variazionePct.map { " (\(percentualeSegno($0)))" } ?? ""
        let posizioni = t.posizioni == 1 ? "1 posizione" : "\(t.posizioni) posizioni"
        return "\(euroSegno(t.variazione))\(pct) su \(posizioni) · al netto dei versamenti \(euroSegno(t.risultato))"
    }

    // MARK: - Pillole e spiegazioni

    static func pillola(_ e: AggiornaValori.Esito) -> (testo: String, tono: Pillola.Tono) {
        switch e.stato {
        case .aggiorna:
            if e.insolita { return ("Da controllare", .attenzione) }
            if e.correzione { return ("Corregge", .neutro) }
            return ("Aggiorna", .ok)
        case .storico: return ("Nello storico", .neutro)
        case .giaRegistrato: return ("Già registrato", .neutro)
        case .daScegliere: return ("Scegli la posizione", .attenzione)
        case .nonTrovata: return ("Non trovata", .errore)
        case .nonInEssere: return ("Non in essere", .neutro)
        case .copertura: return ("Copertura o debito", .neutro)
        case .senzaValore: return ("Senza valore", .errore)
        case .dataFutura: return ("Data futura", .errore)
        case .ripetuta: return ("Ripetuta", .neutro)
        }
    }

    static func abbinamento(_ a: AggiornaValori.Abbinamento?) -> String? {
        switch a {
        case .numero?: return "dal numero di polizza"
        case .nome?: return "dal cliente e dal prodotto"
        case .scelta?: return "scelta da te"
        case .griglia?, nil: return nil
        }
    }

    /// La spiegazione sotto la riga. `posizioni` per id, `clienti` da id a nome.
    static func spiegazione(_ e: AggiornaValori.Esito, posizioni: [String: Posizione], clienti: [String: String]) -> String {
        switch e.stato {
        case .aggiorna:
            if e.insolita {
                if e.riga.valore == 0 && (e.precedente ?? 0) > 0 {
                    return "valore zero: se la polizza è stata riscattata o è scaduta, chiudila dalla sua scheda"
                }
                let pct = (e.risultatoPct ?? e.variazionePct).map(percentualeSegno) ?? "—"
                return "variazione del \(pct)\(e.mesi.map { " in \(mesi($0))" } ?? ""): controlla che il valore sia in euro e della polizza giusta"
            }
            var parti: [String] = []
            if let a = abbinamento(e.abbinamento) { parti.append(a) }
            if e.correzione {
                parti.append("corregge il valore dello stesso giorno")
            } else if let m = e.mesi {
                parti.append("in \(mesi(m))")
            }
            if e.versatoStimato { parti.append("versato stimato con i premi del periodo") }
            return parti.joined(separator: " · ")
        case .storico:
            let quando = e.dataPrecedente.map { " del \(data($0))" } ?? ""
            return "più vecchio del valore attuale\(quando): va tra i valori passati"
        case .giaRegistrato:
            return "lo storico ha già questo valore in quel giorno"
        case .daScegliere:
            if e.candidate.count == 1, let p = posizioni[e.candidate[0]] {
                return "il numero è di una posizione di \(clienti[p.clienteId] ?? "un altro cliente"): sceglila se è giusta"
            }
            return "più posizioni possibili: scegli quella giusta"
        case .nonTrovata:
            return "nessuna posizione con questo numero o questo nome"
        case .nonInEssere:
            let stato = e.posizioneId.flatMap { posizioni[$0] }?.stato.nome.lowercased() ?? "chiusa"
            return "la posizione è \(stato): il valore non si registra"
        case .copertura:
            return "coperture e debiti non hanno un valore da aggiornare qui"
        case .senzaValore:
            return "manca il valore o la data non si legge"
        case .dataFutura:
            return "data futura: è una proiezione, non un valore rilevato"
        case .ripetuta:
            return "stessa posizione e stesso giorno di una riga sopra"
        }
    }

    private static func mesi(_ n: Int) -> String { n == 1 ? "1 mese" : "\(n) mesi" }

    // MARK: - Griglia

    static func conteggioFermi(_ n: Int) -> String {
        n == 1 ? "Una posizione in essere ha il valore fermo da più di 12 mesi o senza data."
               : "\(n) posizioni in essere hanno il valore fermo da più di 12 mesi o senza data."
    }

    static let grigliaVuota = "Tutti i valori delle posizioni in essere hanno meno di 12 mesi."
    static let aiutoTastiera = "Scrivi il nuovo valore e premi Invio per passare alla riga sotto; Tab passa a data e versato. Data vuota: vale la data comune. ⌘↩ registra."
    static let colonnaCliente = "Cliente"
    static let colonnaPosizione = "Posizione"
    static let colonnaAttuale = "Valore attuale"
    static let colonnaNuovo = "Nuovo valore"
    static let colonnaData = "Data"
    static let colonnaVersato = "Versato"
    static let colonnaVariazione = "Variazione"
    // Colonne dell'elenco
    static let colonnaRiga = "Riga"
    static let colonnaNuovoElenco = "Nuovo"
    static let colonnaEsito = "Esito"

    static func fermo(mesi: Int?) -> String {
        guard let mesi else { return "senza data" }
        return mesi == 1 ? "fermo da 1 mese" : "fermo da \(mesi) mesi"
    }

    static let segnapostoData = "gg/mm/aaaa"
    static let segnapostoVersato = "facoltativo"
    static let tuttiIClienti = "Tutti i clienti"
    static let canaleTutti = "Tutti"
    static let dataComune = "Data comune"
    static let senzaData = "senza data"
    static func al(_ d: Date) -> String { "al \(data(d))" }
    static func numeroContratto(_ n: String) -> String { "n. \(n)" }
    static func gestioneSeparata(_ q: Double) -> String { "GS \(percentuale(q))" }
    static func netta(_ v: Double) -> String { "netta \(euroSegno(v))" }
    static let scegli = "Scegli…"

    // MARK: - Piede e riepilogo

    static func registra(_ n: Int) -> String { n == 1 ? "Registra 1 valore" : "Registra \(n) valori" }
    static let chiudi = "Chiudi"
    static let continua = "Continua"
    static let apri = "Apri ↗"
    static let notaBackup = "Prima di registrare Prisma salva un backup."
    static let titoloNota = "Come si aggiornano"
    static let notaMetodo = "Un valore più recente di quello attuale lo sostituisce e quello di prima resta nello storico; uno più vecchio va tra i valori passati; lo stesso giorno corregge il valore. Se manca il versato, al versato di prima si aggiungono i premi del periodo. La variazione al netto dei versamenti toglie i premi pagati nel frattempo: è quella che dice come è andata la posizione. Gli estratti periodici li prevedono le regole di ogni canale: per le polizze vita il Regolamento IVASS n. 41/2018, per gli strumenti finanziari il Reg. delegato (UE) 2017/565 (art. 63, rendiconto almeno trimestrale), per la previdenza complementare la comunicazione periodica annuale COVIP. I 12 mesi sono la soglia del riesame di Prisma."
    static let titoloRiepilogo = "Valori registrati"

    static func testoRiepilogo(_ r: AggiornaValori.Riepilogo) -> String {
        let attuali = r.attuali == 1 ? "1 valore attuale aggiornato" : "\(r.attuali) valori attuali aggiornati"
        let storico = r.storico == 1 ? "1 valore passato" : "\(r.storico) valori passati"
        let posizioni = r.posizioni.count == 1 ? "1 posizione" : "\(r.posizioni.count) posizioni"
        return "\(attuali) e \(storico) nello storico, su \(posizioni). Il valore di prima di ogni posizione resta nello storico e nell'andamento."
    }

    static let kpiAggiornati = "Aggiornati"
    static let kpiPrima = "Prima"
    static let kpiDopo = "Dopo"
    static func notaDopo(_ t: AggiornaValori.Totale) -> String {
        "\(euroSegno(t.variazione)) · \(t.variazionePct.map(percentualeSegno) ?? "—")"
    }
    static func altre(_ n: Int) -> String { n == 1 ? "e un'altra" : "e altre \(n)" }

    /// L'avviso dopo la registrazione.
    static func avviso(_ r: AggiornaValori.Riepilogo, backup: Bool) -> String {
        let n = r.attuali + r.storico
        let valori = n == 1 ? "1 valore registrato" : "\(n) valori registrati"
        let posizioni = r.posizioni.count == 1 ? "1 posizione" : "\(r.posizioni.count) posizioni"
        return "\(valori) su \(posizioni)." + (backup ? " Lo stato precedente è salvato in un backup." : "")
    }

    /// Il backup prima dell'aggiornamento non è riuscito (lo usa anche `StatoShell.dopoUnBackup`).
    static func annullato(_ descrizione: String) -> String {
        "Aggiornamento annullato, backup non riuscito: \(descrizione)"
    }

    // MARK: - Ingresso

    static let pulsante = "Aggiorna valori"
    static let aiutoPulsante = "Aggiorna in blocco i valori delle posizioni in essere: da un elenco della compagnia (Excel o CSV) oppure a mano, in fila, quelli fermi da più di 12 mesi."
    static func bannerImportazione(_ n: Int) -> String {
        n == 1 ? "1 riga è di una posizione già in Prisma." : "\(n) righe sono di posizioni già in Prisma."
    }
    static let aggiornaLoroValori = "Aggiorna i loro valori"
    static let fileSenzaValori = "Nel file non ho trovato valori: servono il numero di polizza (o cliente e prodotto) e una colonna del valore (Controvalore, Valore di riscatto, Riserva…), con i nomi delle colonne nella prima riga."
    static let messaggioApertura = "Un foglio Excel o un CSV della compagnia con una posizione per riga: numero di polizza (o cliente e prodotto) e valore, con i nomi delle colonne nella prima."
    /// Le righe scelte per l'importazione normale non hanno né prodotto né numero di contratto.
    static let nessunaPosizione = "Nel file non ho trovato posizioni: servono almeno il prodotto o il numero di contratto, con i nomi delle colonne nella prima riga."
    /// Le righe copiate non hanno l'intestazione o non sono una tabella.
    static let appuntiVuoti = "Negli appunti non ci sono righe di tabella. In Excel seleziona le righe con l'intestazione, ⌘C, poi «Incolla da Excel»."
}
