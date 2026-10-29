import Foundation

/// Testi della completezza dei dati per l'analisi (specifica 7): titoli, didascalie, ipotesi voce per voce
/// (per il consulente e, con il tu, per il cliente) e il perché di ogni dato con la sua norma.
/// Solo costanti e funzioni pure. Le norme spiegano perché il dato conta, non promettono conformità.
enum TestiCompletezza {
    // MARK: - Titoli e didascalie

    static let occhiello = "Dati per l'analisi"

    /// "Completi al 77% · 7 da completare"; senza voci da completare "Completi al 100%".
    static func nota(_ c: CompletezzaCliente) -> String {
        let n = c.daCompletare.count
        return n == 0 ? "Completi al 100%" : "Completi al \(c.percentuale)% · \(n) da completare"
    }

    /// "2 mancano · 4 stimati · 1 da aggiornare": le parti a zero non si scrivono.
    static func riepilogo(_ c: CompletezzaCliente) -> String {
        var parti: [String] = []
        if c.mancanti > 0 { parti.append(c.mancanti == 1 ? "1 manca" : "\(c.mancanti) mancano") }
        if c.stimati > 0 { parti.append(c.stimati == 1 ? "1 stimato" : "\(c.stimati) stimati") }
        if c.daAggiornare > 0 { parti.append("\(c.daAggiornare) da aggiornare") }
        return parti.joined(separator: " · ")
    }

    /// "Girano su ipotesi: Previdenza, Protezione, Costi" (vuoto se nessuna analisi gira su ipotesi).
    static func toccate(_ c: CompletezzaCliente) -> String {
        let nomi = c.analisiToccate.map(\.nome)
        return nomi.isEmpty ? "" : "Girano su ipotesi: " + nomi.joined(separator: ", ")
    }

    static let tuttoCompleto = "Ci sono tutti i dati che servono alle analisi."
    static let completa = "Completa"
    static let nonPertinente = "Non pertinente"
    static let aiutoNonPertinente = "Non serve per questo cliente: non conta più nel punteggio"
    static let aiutoCompleta = "Apri il modulo sul dato da completare"
    static func mostraTutte(_ n: Int) -> String { "Mostra tutte (\(n))" }
    static let mostraMeno = "Mostra meno"
    static func escluse(_ n: Int) -> String { "\(n) \(n == 1 ? "voce segnata" : "voci segnate") come non pertinenti" }
    static let ripristina = "Ripristina"
    static let aiutoRipristina = "Le voci segnate come non pertinenti tornano a contare nel punteggio"
    /// L'avviso dopo l'esclusione di una voce.
    static func avvisoEsclusa(_ titolo: String, nome: String) -> String { "«\(titolo)» non conta più per \(nome)." }

    static let metodo = "Il punteggio pesa ogni dato da 1 a 3 secondo quanto sposta le cifre: conta per intero se c'è, per metà se è stimato o vecchio (valori oltre 12 mesi, profilo oltre 24 mesi), zero se manca. Misura solo i dati che entrano nei calcoli di Prisma: non sostituisce i questionari di adeguatezza né l'adeguata verifica antiriciclaggio (D.Lgs. 231/2007)."

    // MARK: - Analisi 360

    /// La riga sotto il titolo della panoramica: "Dati per l'analisi completi al 77% · 7 ipotesi stimate".
    static func rigaAnalisi(_ c: CompletezzaCliente) -> String {
        let n = c.daCompletare.count
        return "Dati per l'analisi completi al \(c.percentuale)%" + (n > 0 ? " · \(n) \(n == 1 ? "ipotesi stimata" : "ipotesi stimate")" : "")
    }

    static let completaNellaScheda = "Completa nella scheda del cliente"

    /// L'etichetta di una scheda d'area non confermata con voci da completare.
    static func ipotesiArea(_ n: Int) -> String { "\(n) \(n == 1 ? "ipotesi stimata" : "ipotesi stimate")" }

    /// La pillola accanto a un'ipotesi stimata dell'Analisi 360.
    static let stimato = "stimato"

    /// Le etichette dei campi dell'Analisi 360 su cui si apre il completamento (identiche a quelle di AppAnalisi360).
    static let campoEta = "Età attuale"
    static let campoFabbisogno = "Fabbisogno della famiglia"
    static let campoRedditoDesiderato = "Reddito desiderato"
    static let campoPensionePubblica = "Pensione pubblica"

    // MARK: - Ipotesi, voce per voce (consulente e cliente)

    private static func euro(_ v: Double) -> String { Formati.euro(v) }
    private static func data(_ d: Date) -> String { Formati.dataEstesa.string(from: d) }

    static func nascita(eta: Int) -> String {
        "Età presa dall'Analisi 360 (\(eta) anni): anni alla pensione e di sostegno sono ipotesi."
    }
    static func nascitaCliente(eta: Int) -> String {
        "Non abbiamo ancora la tua data di nascita: abbiamo ipotizzato \(eta) anni."
    }

    static let statoCivile = "Eredi ricavati solo dai familiari indicati."
    static let statoCivileCliente = "Ci manca il tuo stato civile: gli eredi sono quelli che ci hai indicato."

    static let redditoLordo = "Senza reddito lordo non si calcolano l'aliquota IRPEF marginale né il risparmio della deduzione."
    static let redditoLordoCliente = "Senza il tuo reddito lordo non possiamo calcolare il risparmio d'imposta dei versamenti."

    static func redditoNetto(annuo: Double) -> String {
        "Reddito netto ipotizzato pari al fabbisogno della famiglia (\(euro(annuo)) l'anno)."
    }
    static func redditoNettoCliente(annuo: Double) -> String {
        "Il tuo reddito netto è stimato in \(euro(annuo)) l'anno."
    }

    static func fabbisogno(mensile: Double) -> String {
        "Fabbisogno di \(euro(mensile)) al mese, non confermato con il cliente."
    }
    static func fabbisognoCliente(mensile: Double) -> String {
        "Abbiamo ipotizzato che alla famiglia servano \(euro(mensile)) al mese: lo confermiamo insieme."
    }

    static func redditoDesiderato(mensile: Double) -> String {
        "Reddito desiderato di \(euro(mensile)) al mese, ipotesi predefinita."
    }
    static func redditoDesideratoCliente(mensile: Double) -> String {
        "Il reddito che vorresti in pensione è un'ipotesi di \(euro(mensile)) al mese."
    }

    /// Con una stima contributiva si dice quanto vale, da copiare nelle ipotesi.
    static func pensionePubblica(mensile: Double, stimaNetta: Double?) -> String {
        "Pensione pubblica di \(euro(mensile)) al mese, ipotesi predefinita"
            + (stimaNetta.map { "; la stima contributiva dice \(euro($0)): copiala nelle ipotesi" } ?? "") + "."
    }
    static func pensionePubblicaCliente(mensile: Double) -> String {
        "La pensione pubblica è un'ipotesi di \(euro(mensile)) al mese: la verifichiamo sull'estratto conto INPS."
    }

    static let lavoroMancante = "Senza i dati del lavoro non si stima la pensione pubblica."
    static let lavoroSenzaMontante = "Pensione stimata dagli anni di contributi, senza il montante dell'estratto conto INPS."
    static let lavoroMisto = "Contributi prima del 1996 (sistema misto): la stima contributiva è solo indicativa."
    static let lavoroCliente = "La tua pensione pubblica è stimata: con l'estratto conto INPS diventa più precisa."

    static func profilo(mancante: Bool, aggiornatoIl: Date?) -> String {
        if mancante { return "Rischio delle posizioni non confrontato con il profilo." }
        guard let d = aggiornatoIl else { return "Profilo senza data di aggiornamento: va rivisto." }
        return "Profilo aggiornato il \(data(d)), più di 24 mesi fa."
    }
    static func profiloCliente(mancante: Bool) -> String {
        "Il tuo profilo di rischio va \(mancante ? "definito" : "aggiornato") insieme."
    }

    static var orizzonte: String {
        "Posizioni senza scadenza proiettate a \(IpotesiCalcolo.orizzontePredefinito) anni."
    }
    static var orizzonteCliente: String {
        "Le proiezioni senza scadenza usano \(IpotesiCalcolo.orizzontePredefinito) anni."
    }

    static func familiare(nome: String) -> String { "Anni a carico di \(nome) non calcolabili." }
    static func familiareCliente(nome: String) -> String { "Ci manca la data di nascita di \(nome)." }

    static func valore(nome: String, dal: Date?) -> String {
        dal.map { "\(nome): valore al \(data($0)), più di 12 mesi fa." } ?? "\(nome): valore senza data."
    }
    static func valoreCliente(nome: String, dal: Date?) -> String {
        dal.map { "Il valore di «\(nome)» è del \(data($0)): lo aggiorniamo con l'ultimo estratto conto." }
            ?? "Il valore di «\(nome)» non ha una data: lo aggiorniamo con l'ultimo estratto conto."
    }

    static func costi(nome: String) -> String {
        "\(nome): costi non indicati, le proiezioni sono senza costi (risultato più alto del reale)."
    }
    static func costiCliente(nome: String) -> String {
        "Per «\(nome)» non abbiamo ancora i costi del KID: le cifre sono senza costi."
    }

    static func sri(nome: String) -> String { "\(nome): rischio stimato dalla tipologia, manca l'SRI del KID." }
    static func sriCliente(nome: String) -> String { "Il rischio di «\(nome)» è stimato." }

    static func rendimento(nome: String) -> String {
        "\(nome): rendimento ipotizzato del \(Formati.percentuale(IpotesiCalcolo.rendimentoPredefinito)) (predefinito di Prisma)."
    }
    static func rendimentoCliente(nome: String) -> String {
        "Per «\(nome)» abbiamo ipotizzato un rendimento del \(Formati.percentuale(IpotesiCalcolo.rendimentoPredefinito)) l'anno, non garantito."
    }

    static func quotaGestione(nome: String) -> String { "\(nome): quota in gestione separata ipotizzata al 50%." }
    static func quotaGestioneCliente(nome: String) -> String {
        "La divisione tra gestione separata e fondi di «\(nome)» è stimata a metà."
    }

    static func beneficiari(nome: String) -> String {
        "\(nome): beneficiari non indicati, il capitale è considerato degli eredi."
    }
    static func beneficiariCliente(nome: String) -> String {
        "Per «\(nome)» non risultano beneficiari: il capitale andrebbe agli eredi."
    }

    static func capitale(nome: String) -> String { "\(nome): capitale non indicato, non conta tra le coperture." }
    static func capitaleCliente(nome: String) -> String { "Ci manca il capitale assicurato di «\(nome)»." }

    /// Il rischio coperto ricavato dal nome non va nel report del cliente (`ipotesiCliente` vuota).
    static func rischioCoperto(nome: String) -> String { "\(nome): rischio coperto ricavato dal nome." }

    static func adesione(nome: String, conDecorrenza: Bool) -> String {
        conDecorrenza ? "\(nome): anni di partecipazione contati dalla decorrenza."
            : "\(nome): anni di partecipazione non noti, aliquota del 15%."
    }
    static func adesioneCliente(nome: String) -> String { "Gli anni di partecipazione di «\(nome)» sono stimati." }

    // MARK: - Perché il dato conta (aiuto al passaggio del mouse, con la norma)

    enum Perche {
        static let nascita = "L'età decide gli anni che mancano alla pensione, gli anni di sostegno della famiglia e i coefficienti di trasformazione della pensione pubblica."
        static let statoCivile = "Lo stato civile decide gli eredi e le loro quote nella successione legittima (artt. 536 e 565 e seguenti c.c.)."
        static var redditoLordo: String {
            "Il reddito lordo dà l'aliquota IRPEF marginale (scaglioni, art. 11 TUIR) e il risparmio della deduzione dei contributi alla previdenza complementare (art. 10, c. 1, lett. e-bis TUIR; art. 8, c. 4, D.Lgs. 252/2005), fino a \(Formati.euro(RegoleFiscali.limiteDeducibilita)) l'anno."
        }
        static let redditoNetto = "Il reddito netto è quello che verrebbe a mancare alla famiglia: misura la protezione di ogni persona."
        static let fabbisogno = "Il fabbisogno della famiglia è la base del capitale caso morte e della riserva: fa parte delle richieste ed esigenze del cliente (art. 119-ter del Codice delle assicurazioni private)."
        static let redditoDesiderato = "Il reddito che il cliente vuole in pensione: con la pensione pubblica dà il divario da colmare."
        static let pensionePubblica = "La pensione pubblica netta attesa si legge nell'estratto conto contributivo INPS o si stima con il metodo contributivo (L. 335/1995)."
        static let lavoro = "Tipo di lavoratore, reddito e contributi stimano la pensione pubblica con il metodo contributivo (L. 335/1995); con contributi prima del 1996 il sistema è misto. Il montante si legge nell'estratto conto contributivo INPS."
        static let alleanza = "Canale Alleanza: adeguatezza dei prodotti d'investimento assicurativi (Direttiva (UE) 2016/97, IDD, art. 30, recepito nell'art. 121-septies del Codice delle assicurazioni private, D.Lgs. 209/2005, introdotto dal D.Lgs. 68/2018) e richieste ed esigenze (IDD art. 20, recepito nell'art. 119-ter dello stesso Codice); Regolamento delegato (UE) 2017/2359, art. 9; Regolamento IVASS n. 40/2018."
        static let indipendente = "Canale indipendente: art. 21 TUF (D.Lgs. 58/1998) e artt. 54–55 del Regolamento delegato (UE) 2017/565 (MiFID II: obiettivi, orizzonte, capacità di sostenere perdite)."
        /// Profilo di rischio e orizzonte: le norme dei canali delle posizioni finanziarie del cliente.
        static func profilo(canali: Set<Canale>) -> String {
            let norme = Canale.allCases.filter { canali.isEmpty || canali.contains($0) }
                .map { $0 == .alleanza ? alleanza : indipendente }
            return (["Profilo di rischio e orizzonte servono a confrontare il rischio delle posizioni con quello che il cliente può e vuole correre."] + norme)
                .joined(separator: " ")
        }
        static let familiare = "La data di nascita dice per quanti anni la persona resta a carico: serve alla protezione e alla successione."
        static let valore = "Il valore si aggiorna con l'estratto conto o il rendiconto annuale della compagnia o dell'intermediario (per le polizze, Regolamento IVASS n. 41/2018)."
        static let kid = "Costi e indicatore di rischio si leggono nel KID: Regolamento (UE) 1286/2014 (PRIIPs) e Regolamento delegato (UE) 2017/653 (indicatore di rischio e costi, RIY)."
        static let rendimento = "Il rendimento atteso guida le proiezioni: senza, Prisma usa la sua ipotesi predefinita, che non è garantita."
        static let quotaGestione = "La divisione tra gestione separata e fondi cambia rischio, costi e bollo: si legge nell'estratto conto della polizza."
        static func beneficiari(previdenza: Bool) -> String {
            "Il beneficiario designato acquista un diritto proprio (art. 1920 c.c.); senza designazione la prestazione segue la successione."
                + (previdenza ? " Per la previdenza complementare: D.Lgs. 252/2005, art. 14, c. 3." : "")
        }
        static let capitale = "Il capitale assicurato è ciò che la copertura paga: senza, non conta tra le coperture della famiglia."
        static let rischioCoperto = "Il rischio coperto dice a quale bisogno risponde la polizza (caso morte, invalidità, non autosufficienza…)."
        static let adesione = "Gli anni di partecipazione abbassano l'imposta sulla prestazione: 15%, meno 0,30 punti per ogni anno oltre il 15°, fino al 9% (D.Lgs. 252/2005, art. 11, c. 6)."
    }
}
