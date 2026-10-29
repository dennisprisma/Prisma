import Foundation

/// Testi del seguito delle proposte (giro 3, specifica 5): righe del dettaglio, del Portafoglio, delle notifiche
/// e del modulo dell'esito.
enum TestiSeguito {
    // MARK: - Modulo dell'esito

    static let occhiello = "ESITO DELLA PROPOSTA"
    static func titolo(_ p: Posizione) -> String { "Com'è andata con «\(p.nome)»?" }
    static let sceltaAccettata = "✓ Accettata"
    static let sceltaRimandata = "Rimandata"
    static let sceltaRifiutata = "Rifiutata"
    static let sceltaInAttesa = "Ci deve pensare"
    static let passaInEssere = "Passa in essere"
    static let indietro = "Indietro"
    static let nonFirmato = "Non si è firmato"
    static let segnaRifiutata = "Segna rifiutata"
    static let rimanda = "Rimanda"
    static let motivoNonIndicato = "Motivo non indicato"
    static let nota = "Con le sue parole (facoltativo)"
    static let notaRifiuto = "Resta nel dossier come rifiutata e conta nel tasso di accettazione del Portafoglio."
    static let notaPrimaAdesione = "Conta per gli anni di partecipazione (D.Lgs. 252/2005)"
    static let antiriciclaggio = "Ricorda: adeguata verifica antiriciclaggio (D.Lgs. 231/2007) e questionario firmati prima della decorrenza."

    /// Sotto le quattro scelte.
    static func notaInAttesa(giorni: Int) -> String {
        "Se ci deve pensare la proposta resta aperta: dopo \(giorni) giorni senza un appuntamento torna tra le cose da recuperare."
    }

    /// Sotto la scadenza spostata.
    static func notaScadenza(anni: Int?) -> String {
        guard let anni else { return "spostata come la decorrenza: la durata resta la stessa" }
        return "spostata come la decorrenza: la durata resta di \(anni) \(anni == 1 ? "anno" : "anni")"
    }

    /// «1 mese», «3 mesi», «1 anno».
    static func mesiRipresa(_ mesi: Int) -> String {
        if mesi == 12 { return "1 anno" }
        if mesi % 12 == 0 { return "\(mesi / 12) anni" }
        return mesi == 1 ? "1 mese" : "\(mesi) mesi"
    }

    static func daRiprendere(_ data: Date) -> String { "Da riprendere il \(Formati.dataEstesa.string(from: data))" }

    static func creaAttivita(_ p: Posizione) -> String {
        "Prisma crea l'attività «\(titoloRipresa(p))» per quel giorno."
    }

    /// Titolo dell'attività creata con il rinvio.
    static func titoloRipresa(_ p: Posizione) -> String { "Riprendere la proposta «\(p.nome)»" }

    /// Note dell'attività creata con il rinvio.
    static func noteRipresa(adesso: Date, motivo: MotivoEsito?, nota: String) -> String {
        "Rimandata il \(Formati.dataEstesa.string(from: adesso))"
            + (motivo.map { " · \($0.nome.lowercased())" } ?? "")
            + (nota.isEmpty ? "" : " · \(nota)")
    }

    // MARK: - Avvisi dell'accettazione

    static let avvisoDecorrenzaFutura = "La decorrenza è oltre un mese da oggi: segna l'esito quando il contratto sta per partire."
    static let avvisoNegativi = "Il primo valore e il versato non possono essere negativi."
    static let avvisoScadenza = "La scadenza deve venire dopo la decorrenza."
    static let avvisoPrimaAdesione = "La prima adesione non può venire dopo la decorrenza."
    static let avvisoDecorrenzaVecchia = "Decorrenza di più di un anno fa: aggiungi i valori intermedi con «Valore passato» per un andamento corretto."
    static let avvisoScarto = "Il primo valore si discosta di oltre il 20% dal versato: controlla la lettera di conferma o il primo estratto conto."
    static let avvisoSenzaValori = "Senza primo valore né versato, rendimento e andamento partono vuoti."

    // MARK: - Righe

    /// «da 1 giorno», «da 22 giorni».
    static func giorni(_ n: Int) -> String { n == 1 ? "da 1 giorno" : "da \(n) giorni" }

    /// La riga «Esito della proposta» del dettaglio.
    static func esito(_ p: Posizione, adesso: Date) -> String {
        let s = p.seguito
        func data(_ d: Date) -> String { Formati.dataEstesa.string(from: d) }
        let motivo = s?.motivo.map { " · \($0.nome.lowercased())" } ?? ""
        switch p.esito ?? .bozza {
        case .bozza:
            return EsitoProposta.bozza.nome
        case .presentata:
            guard let d = s?.presentataIl else { return "Presentata · in attesa" }
            let g = MotoreSeguitoProposte.giorni(da: d, a: adesso)
            return "Presentata il \(data(d)) · " + (g > 0 ? "in attesa \(giorni(g))" : "in attesa")
        case .accettata:
            return s?.esitoIl.map { "Accettata il \(data($0))" } ?? "Accettata"
        case .rifiutata:
            return (s?.esitoIl.map { "Rifiutata il \(data($0))" } ?? "Rifiutata") + motivo
        case .rimandata:
            return "Rimandata" + (s?.riprendereIl.map { " · da riprendere il \(data($0))" } ?? "") + motivo
        }
    }

    /// Il sottotitolo di una proposta ferma (Portafoglio, notifiche).
    static func riga(_ s: PropostaInSospeso) -> String {
        let giorno = Formati.giornoMese.string(from: s.dal)
        switch s.motivo {
        case .senzaRisposta:
            let quando: String
            switch s.fonte {
            case .ultimoContatto: quando = "ultimo contatto il \(giorno)"
            case .creazione: quando = "inserita il \(giorno)"
            case .presentazione, .esito, .ripresa: quando = "presentata il \(giorno)"
            }
            return "\(quando) · nessun appuntamento in agenda"
        case .daRiprendere:
            return "da riprendere dal \(giorno)" + (s.posizione.seguito?.motivo.map { " · \($0.nome.lowercased())" } ?? "")
        }
    }

    /// La riga del recesso nel passo «Accettata».
    static func recesso(_ fine: Date) -> String {
        "Polizza vita: il cliente può recedere entro \(MotoreSeguitoProposte.giorniRecessoVita) giorni da quando sa che il contratto è concluso (art. 177 D.Lgs. 209/2005), indicativamente fino al \(Formati.dataEstesa.string(from: fine))."
    }

    /// L'avviso dopo la conferma dell'esito.
    static func avviso(_ e: EsitoScelto, posizione p: Posizione, giorni soglia: Int = Impostazioni.giorniSeguitoPredefiniti) -> String {
        switch e {
        case .accettata(let d):
            return "«\(p.nome)» è in essere dal \(Formati.dataEstesa.string(from: d.decorrenza))"
        case .rifiutata:
            return "«\(p.nome)» segnata come rifiutata"
        case .rimandata(let al, _, _):
            return "«\(p.nome)» rimandata: la riprendi il \(Formati.dataEstesa.string(from: al)) (attività creata)"
        case .inAttesa:
            return "«\(p.nome)» resta aperta: se tra \(soglia) giorni non c'è un appuntamento te la ricordo"
        }
    }

    // MARK: - Notifiche, widget, Portafoglio

    /// Titolo della notifica di una proposta ferma.
    static func titoloNotifica(_ s: PropostaInSospeso) -> String {
        s.motivo == .daRiprendere ? "«\(s.posizione.nome)» è da riprendere"
                                  : "«\(s.posizione.nome)» aspetta una risposta \(giorni(s.giorni))"
    }

    /// «1 proposta aspetta una risposta», «3 proposte aspettano una risposta».
    static func aspettano(_ n: Int) -> String {
        n == 1 ? "1 proposta aspetta una risposta" : "\(n) proposte aspettano una risposta"
    }

    /// Dettaglio della notifica con più proposte ferme.
    static func piuFerma(_ s: PropostaInSospeso) -> String {
        "La più ferma: «\(s.posizione.nome)» di \(s.cliente.nome), \(giorni(s.giorni))"
    }

    /// Dettaglio della notifica `esito-` per un appuntamento di proposta o di firma.
    static func esitoAppuntamento(cliente: String, giorno: Date, proposta: Posizione) -> String {
        "\(cliente) · \(Formati.giornoMese.string(from: giorno)): com'è finita la proposta «\(proposta.nome)»? Segna l'esito in agenda"
    }

    static let titoloPannello = "Proposte da riprendere"
    static func notaPannello(giorni: Int) -> String {
        "Presentate da più di \(giorni) giorni senza un appuntamento in agenda, o rimandate e ora da riprendere · i giorni si cambiano in Impostazioni"
    }
    static func pannelloVuoto(giorni: Int) -> String {
        "Nessuna proposta ferma: ogni proposta presentata da più di \(giorni) giorni ha un appuntamento in agenda o un esito."
    }
    static func altre(_ n: Int) -> String { "…e altre \(n)" }
    static func ferme(_ n: Int) -> String { "\(n) \(n == 1 ? "ferma" : "ferme")" }

    /// Le righe sotto il tasso di accettazione (vuote senza dati).
    static func statistiche(_ s: StatisticheEsiti) -> [String] {
        func elenco(_ m: [(motivo: MotivoEsito, volte: Int)]) -> String {
            m.map { "\($0.motivo.nome.lowercased()) (\($0.volte))" }.joined(separator: ", ")
        }
        var righe: [String] = []
        if !s.motiviRifiuto.isEmpty { righe.append("Rifiutate soprattutto per: \(elenco(s.motiviRifiuto)).") }
        if !s.motiviRinvio.isEmpty { righe.append("Rimandate per: \(elenco(s.motiviRinvio)).") }
        if let g = s.giorniMediDecisione {
            let n = Int(g.rounded())
            righe.append("Per decidere servono in media \(n) \(n == 1 ? "giorno" : "giorni") (\(s.decise) \(s.decise == 1 ? "proposta" : "proposte")).")
        }
        return righe
    }

    // MARK: - Bozza della telefonata di seguito

    static func titoloSeguito(_ p: Posizione) -> String { "Seguito della proposta «\(p.nome)»" }
    static func noteSeguito(_ s: PropostaInSospeso) -> String {
        let quando: String
        switch s.fonte {
        case .presentazione: quando = "Presentata il"
        case .ultimoContatto: quando = "Ultimo contatto il"
        case .esito: quando = "Rimandata il"
        case .ripresa: quando = "Da riprendere dal"
        case .creazione: quando = "Inserita il"
        }
        return "\(quando) \(Formati.dataEstesa.string(from: s.dal)): com'è andata la riflessione? Dubbi su costi, tempi, alternative."
    }
    static let luogoSeguito = "Telefonata"
    static let solaLettura = "Archivio in sola lettura: aggiorna Prisma per segnare l'esito delle proposte."

    // MARK: - Prospetto del Portafoglio

    static func prospettoVuoto(giorni: Int) -> String { "Nessuna proposta ferma da più di \(giorni) giorni." }
    static func metodo(giorni: Int) -> String {
        "Proposte da riprendere: presentate da più di \(giorni) giorni senza un appuntamento in agenda (dalla presentazione, dall'ultimo appuntamento collegato o, se mancano, dall'inserimento), o rimandate e arrivate alla data di ripresa."
    }
}
