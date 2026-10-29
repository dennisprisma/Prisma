import Foundation

/// I testi delle scadenze di conformità («In regola», specifica 3): nomi, pillole, dettagli, avvisi, fonti
/// normative. Solo funzioni pure, in italiano. Le fonti sono un promemoria da verificare sul testo vigente:
/// fanno fede i moduli firmati e i sistemi della compagnia o dell'intermediario.
enum TestiConformita {
    typealias Tipo = VoceConformita.Tipo

    // MARK: - Nomi

    /// «Questionario di adeguatezza», «Adeguata verifica antiriciclaggio»… (i due canali hanno lo stesso nome:
    /// il canale lo dice l'etichetta).
    static func nome(_ t: Tipo) -> String {
        switch t {
        case .questionarioAlleanza, .questionarioIndipendente: return "Questionario di adeguatezza"
        case .verificaAlleanza, .verificaIndipendente: return "Adeguata verifica antiriciclaggio"
        case .documento: return "Documento d'identità"
        case .privacy: return "Informativa privacy"
        case .commerciale: return "Consenso commerciale"
        }
    }

    /// «questionario Alleanza», «adeguata verifica indipendente», «documento d'identità»…
    static func nomeBreve(_ t: Tipo) -> String {
        switch t {
        case .questionarioAlleanza: return "questionario Alleanza"
        case .verificaAlleanza: return "adeguata verifica Alleanza"
        case .questionarioIndipendente: return "questionario indipendente"
        case .verificaIndipendente: return "adeguata verifica indipendente"
        case .documento: return "documento d'identità"
        case .privacy: return "informativa privacy"
        case .commerciale: return "consenso commerciale"
        }
    }

    /// Il nome breve con la prima lettera maiuscola («Questionario Alleanza»).
    static func nomeBreveMaiuscolo(_ v: VoceConformita) -> String { maiuscola(nomeBreve(v.tipo)) }

    /// Vero per le verifiche e l'informativa (per «scaduto/scaduta»).
    static func femminile(_ t: Tipo) -> Bool { t.verifica || t == .privacy }

    /// La prima lettera maiuscola.
    static func maiuscola(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    /// «1 anno», «2 anni», «18 mesi», «6 mesi».
    static func durata(_ mesi: Int) -> String {
        guard mesi >= 12, mesi % 12 == 0 else { return mesi == 1 ? "1 mese" : "\(mesi) mesi" }
        let anni = mesi / 12
        return anni == 1 ? "1 anno" : "\(anni) anni"
    }

    // MARK: - Stato

    /// Il testo della pillola dello stato.
    static func etichetta(_ v: VoceConformita) -> String {
        switch v.stato {
        case .scaduta: return v.tipo == .privacy ? "Da riconsegnare" : "Da rinnovare"
        case .mancante: return "Da raccogliere"
        case .entro30:
            switch v.giorni ?? 0 {
            case ...0: return "Oggi"
            case 1: return "Domani"
            case let g: return "Tra \(g) giorni"
            }
        case .entro60: return "Tra \(v.giorni ?? 0) giorni"
        case .inRegola: return "In regola"
        case .nonRichiesta: return "Non richiesto"
        }
    }

    /// «questionario Alleanza scaduto il 18 settembre», «informativa privacy da riconsegnare (aggiornata il 1° giugno)».
    static func scaduta(_ v: VoceConformita) -> String {
        let quando = v.scadenza.map { giornoMese($0, giorni: v.giorni) } ?? "—"
        if v.tipo == .privacy { return "informativa privacy da riconsegnare (aggiornata il \(quando))" }
        return "\(nomeBreve(v.tipo)) \(femminile(v.tipo) ? "scaduta" : "scaduto") il \(quando)"
    }

    /// «documento d'identità scade tra 20 giorni», «… scade oggi», «… scade domani».
    static func inScadenza(_ v: VoceConformita) -> String {
        let nome = nomeBreve(v.tipo)
        if v.tipo == .privacy, v.stato == .entro30 {
            // L'informativa nuova vale da quel giorno: chi ha firmato la vecchia la riceve di nuovo
            let quando = v.scadenza.map { giornoMese($0, giorni: v.giorni) } ?? "—"
            return "informativa privacy da riconsegnare (nuova dal \(quando))"
        }
        switch v.giorni ?? 0 {
        case ...0: return "\(nome) scade oggi"
        case 1: return "\(nome) scade domani"
        case let g: return "\(nome) scade tra \(g) giorni"
        }
    }

    /// Una frase breve per lo stato della voce: scaduta, in scadenza o da raccogliere (minuscola, senza punto).
    static func breve(_ v: VoceConformita) -> String {
        switch v.stato {
        case .scaduta: return scaduta(v)
        case .entro30, .entro60: return inScadenza(v)
        case .mancante: return "\(nomeBreve(v.tipo)) da raccogliere"
        case .inRegola: return "\(nomeBreve(v.tipo)) in regola"
        case .nonRichiesta: return "\(nomeBreve(v.tipo)) non richiest\(femminile(v.tipo) ? "a" : "o")"
        }
    }

    // MARK: - Dettaglio della riga

    /// La riga sotto il nome della voce nella scheda «In regola».
    static func dettaglio(_ v: VoceConformita, cliente: Cliente) -> String {
        if v.motivo == .sceltaConsulente { return "Segnato come non richiesto per questo cliente." }
        switch v.tipo {
        case .questionarioAlleanza, .questionarioIndipendente:
            return dettaglioQuestionario(v, cliente: cliente)
        case .verificaAlleanza, .verificaIndipendente:
            return dettaglioVerifica(v, cliente: cliente)
        case .documento:
            return dettaglioDocumento(v, cliente: cliente)
        case .privacy:
            return dettaglioPrivacy(v)
        case .commerciale:
            return dettaglioCommerciale(v)
        }
    }

    private static func nonSeguito(_ c: Canale?) -> String {
        c == .alleanza ? "Il cliente non è seguito con Alleanza." : "Il cliente non è seguito con la consulenza indipendente."
    }

    private static func dettaglioQuestionario(_ v: VoceConformita, cliente: Cliente) -> String {
        if v.stato == .nonRichiesta { return nonSeguito(v.canale) }
        guard let compilato = v.data, let scadenza = v.scadenza else {
            return "Non registrato in Prisma: indica la data dell'ultimo questionario firmato."
        }
        let validita = v.mesi.map { "valido \(durata($0)), " } ?? ""
        let fine = v.stato == .scaduta ? "scaduto il \(data(scadenza))" : "fino al \(data(scadenza))"
        var testo = "Compilato il \(data(compilato)) · \(validita)\(fine)"
        if let c = v.canale, let esito = cliente.conformita?.questionario(c)?.esito?.trimmingCharacters(in: .whitespaces),
           !esito.isEmpty {
            testo += " · profilo «\(esito)»"
        }
        return testo
    }

    private static func dettaglioVerifica(_ v: VoceConformita, cliente: Cliente) -> String {
        switch v.motivo {
        case .impostazioni?: return "Non tenuta sul canale indipendente (Impostazioni)."
        case .canaleNonSeguito?: return nonSeguito(v.canale)
        default: break
        }
        guard let eseguita = v.data, let scadenza = v.scadenza else {
            return "Non registrata in Prisma: data e profilo di rischio dell'ultima verifica."
        }
        let mesi = v.mesi ?? 0
        let entro = v.stato == .scaduta ? "scaduta il \(data(scadenza))" : "entro il \(data(scadenza))"
        if v.rischioStimato {
            return "Eseguita il \(data(eseguita)) · rischio non indicato: periodicità del rischio medio (\(mesi) mesi), \(entro)"
        }
        let rischio = v.canale.flatMap { cliente.conformita?.verifica($0)?.rischio }
        let nomeRischio = rischio.map { $0.nome.lowercased() } ?? "medio"
        let rafforzata = rischio == .alto ? " (verifica rafforzata)" : ""
        return "Eseguita il \(data(eseguita)) · rischio \(nomeRischio), si rinnova ogni \(mesi) mesi\(rafforzata): \(entro)"
    }

    private static func dettaglioDocumento(_ v: VoceConformita, cliente: Cliente) -> String {
        if v.motivo == .clienteNonSeguito {
            return "Nessun canale e nessuna posizione aperta: l'identificazione servirà al primo contratto."
        }
        guard let d = cliente.conformita?.documento, d != DocumentoIdentita() else {
            return "Non registrato: serve per l'identificazione (antiriciclaggio)."
        }
        // Carta d'identità e patente al femminile, passaporto e documento al maschile
        let femminile = d.tipo == .cartaIdentita || d.tipo == .patente
        var parti: [String] = []
        let numero = d.numero?.trimmingCharacters(in: .whitespaces) ?? ""
        let nome = d.tipo?.nome ?? "Documento"
        parti.append(numero.isEmpty ? nome : "\(nome) n. \(numero)")
        if let r = d.rilasciatoIl { parti.append("\(femminile ? "rilasciata" : "rilasciato") il \(data(r))") }
        if let s = d.scadenza {
            parti.append(v.stato == .scaduta ? "\(femminile ? "scaduta" : "scaduto") il \(data(s))" : "scade il \(data(s))")
        } else {
            parti.append("scadenza non indicata")
        }
        return parti.joined(separator: " · ")
    }

    private static func dettaglioPrivacy(_ v: VoceConformita) -> String {
        switch v.stato {
        case .mancante:
            return "Informativa e consenso al trattamento da raccogliere."
        case .scaduta, .entro30:
            let ultima = v.data.map { "l'ultima firmata è del \(data($0))" } ?? "l'ultima firmata non ha una data"
            let aggiornata = v.scadenza.map { data($0) } ?? "—"
            return "Informativa aggiornata il \(aggiornata): da consegnare di nuovo (\(ultima))."
        default:
            return v.data.map { "Informativa e consenso dal \(data($0))" } ?? "Consenso raccolto, data non indicata"
        }
    }

    private static func dettaglioCommerciale(_ v: VoceConformita) -> String {
        if v.motivo == .consensoNonDato { return "Non dato: nessuna comunicazione commerciale." }
        guard let dato = v.data else { return "Dato, ma senza data: indica quando." }
        guard let scadenza = v.scadenza, let mesi = v.mesi else { return "Dato il \(data(dato))" }
        let entro = v.stato == .scaduta ? "scaduto il \(data(scadenza))" : "entro il \(data(scadenza))"
        return "Dato il \(data(dato)) · da riconfermare ogni \(mesi) mesi, \(entro)"
    }

    // MARK: - Scheda di adeguatezza

    /// Perché la voce blocca la firma della proposta.
    static func bloccante(_ v: VoceConformita) -> String {
        switch v.tipo {
        case .questionarioAlleanza, .questionarioIndipendente:
            let canale = v.canale == .alleanza ? "Alleanza" : "indipendente"
            let stato = v.stato == .scaduta ? "scaduto" : "da raccogliere"
            return "Questionario di adeguatezza \(canale) \(stato): va compilato prima di firmare."
        case .documento:
            let stato = v.stato == .scaduta ? "scaduto" : "non registrato"
            return "Documento d'identità \(stato): serve una copia valida per l'identificazione."
        case .privacy:
            return "Informativa privacy e consenso al trattamento da raccogliere."
        default:
            return "\(nomeBreveMaiuscolo(v)) da sistemare prima di firmare."
        }
    }

    /// «Questionario Alleanza scade il 15 novembre 2026, prima della firma prevista.»
    static func primaDellaFirma(_ v: VoceConformita) -> String {
        "\(nomeBreveMaiuscolo(v)) scade il \(v.scadenza.map(data) ?? "—"), prima della firma prevista."
    }

    /// «Questionario Alleanza scade il 15 novembre 2026: conviene rinnovarlo alla firma.»
    static func rinnovoAllaFirma(_ v: VoceConformita) -> String {
        "\(nomeBreveMaiuscolo(v)) scade il \(v.scadenza.map(data) ?? "—"): conviene rinnovarl\(femminile(v.tipo) ? "a" : "o") alla firma."
    }

    // MARK: - Ricerca

    /// Le prime due voci che rispettano il filtro, per l'estratto del cliente nella ricerca
    /// («Questionario Alleanza scaduto il 18 settembre · Adeguata verifica Alleanza scaduta il 2 settembre»).
    static func estrattoRicerca(_ e: EsitoConformita, filtro: FiltroConformita, canale: Canale?) -> String? {
        let voci = MotoreConformita.vociFiltro(e, filtro, canale: canale)
        guard !voci.isEmpty else { return nil }
        return voci.prefix(2).map { maiuscola(breve($0)) }.joined(separator: " · ")
    }

    // MARK: - Fonti e metodo

    /// La fonte normativa della voce (da verificare sul testo vigente prima di usarla in un documento ufficiale).
    static func fonte(_ t: Tipo) -> String {
        switch t {
        case .questionarioAlleanza:
            return "Prodotti d'investimento assicurativi (IBIP): Codice delle assicurazioni private (D.Lgs. 209/2005) art. 121-septies, introdotto dal D.Lgs. 68/2018 di recepimento della IDD (Dir. UE 2016/97, art. 30); richieste ed esigenze per ogni contratto: art. 119-ter; Reg. delegato UE 2017/2359 artt. 9–17; Regolamento IVASS n. 40/2018. La norma chiede informazioni aggiornate ma non fissa una durata: la validità è quella della compagnia, impostabile in Prisma."
        case .questionarioIndipendente:
            return "Consulenza finanziaria: TUF (D.Lgs. 58/1998) artt. 18-bis e 21; MiFID II (Dir. 2014/65/UE) art. 25, par. 2; Reg. delegato UE 2017/565 artt. 54–55; Regolamento Intermediari Consob n. 20307/2018; Orientamenti ESMA sull'adeguatezza (2022). La periodicità dell'aggiornamento la stabilisce il consulente."
        case .verificaAlleanza, .verificaIndipendente:
            return "Antiriciclaggio: D.Lgs. 231/2007 artt. 17–19 (approccio basato sul rischio; controllo costante, art. 18, c. 1, lett. d), art. 23 (verifica semplificata), artt. 24–25 (verifica rafforzata); per il ramo vita Regolamento IVASS n. 44/2019. La legge chiede un aggiornamento commisurato al rischio senza fissare i mesi: 12, 24 e 36 mesi per rischio alto, medio e basso sono la periodicità predefinita di Prisma, da allineare alla policy della compagnia o alla propria."
        case .documento:
            return "Identificazione del cliente con un documento d'identità in corso di validità: D.Lgs. 231/2007 artt. 18, c. 1, lett. a) e 19, c. 1, lett. a). Carta d'identità: 10 anni per i maggiorenni (5 dai 3 ai 18 anni, 3 sotto i 3 anni), fino al compleanno successivo (D.L. 5/2012, art. 7, c. 2). Passaporto: 10 anni per i maggiorenni."
        case .privacy:
            return "Regolamento UE 2016/679 (GDPR) artt. 6, 7 e 13; Codice privacy (D.Lgs. 196/2003). Il consenso al trattamento non scade; se l'informativa cambia va consegnata di nuovo (data dell'ultima versione in Impostazioni)."
        case .commerciale:
            return "GDPR artt. 6, 7 e 21 (diritto di opposizione al marketing); Codice privacy art. 130. Nessuna scadenza di legge: la riconferma ogni 24 mesi è buona prassi, sul modello dei tempi di conservazione per il marketing indicati dal Garante (provvedimento del 24 febbraio 2005); impostabile o «Non scade»."
        }
    }

    /// Le sei fonti della sezione «Come si calcola e fonti», con il loro titolo.
    static var fonti: [(titolo: String, testo: String)] {
        [
            ("Questionario Alleanza", fonte(.questionarioAlleanza)),
            ("Questionario indipendente", fonte(.questionarioIndipendente)),
            ("Adeguata verifica", fonte(.verificaAlleanza)),
            ("Documento d'identità", fonte(.documento)),
            ("Informativa privacy", fonte(.privacy)),
            ("Consenso commerciale", fonte(.commerciale)),
        ]
    }

    /// Il piede comune di ogni testo che cita le norme.
    static let avvertenza = "Le date sono quelle registrate in Prisma: fanno fede i moduli firmati e i sistemi della compagnia o dell'intermediario. Prisma non sostituisce le procedure di adeguatezza e antiriciclaggio. La previdenza complementare (D.Lgs. 252/2005, Questionario di autovalutazione COVIP) e il fisco (TUIR) non hanno scadenze in questa sezione."

    /// Come si calcola, in tre righe.
    static let metodo: [String] = [
        "Questionario e adeguata verifica valgono per canale: si chiedono se il cliente è seguito con quel canale (scheda) o ha posizioni d'investimento, risparmio o previdenza non chiuse del canale.",
        "La scadenza è la data registrata più la validità (Impostazioni o quella del questionario); per l'adeguata verifica dipende dal rischio: alto 12, medio 24, basso 36 mesi se non cambi i valori. Senza rischio indicato si usa il medio.",
        "In scadenza: entro 30 giorni (arancio) ed entro 60 giorni; scaduta il giorno dopo la scadenza. Il documento d'identità vale fino alla data stampata.",
    ]

    // MARK: - Date

    /// «15 novembre 2026», «1° giugno 2026».
    static func data(_ d: Date) -> String { primoDelMese(d, Formati.dataEstesa.string(from: d)) }

    /// «18 settembre», «1° giugno»; con l'anno se la data è lontana da oggi più di dieci mesi.
    static func giornoMese(_ d: Date, giorni: Int?) -> String {
        if abs(giorni ?? 0) > 300 { return data(d) }
        return primoDelMese(d, Formati.giornoMese.string(from: d))
    }

    /// Il primo del mese si scrive «1°».
    private static func primoDelMese(_ d: Date, _ testo: String) -> String {
        guard Calendar.current.component(.day, from: d) == 1, testo.hasPrefix("1 ") else { return testo }
        return "1°" + testo.dropFirst()
    }
}
