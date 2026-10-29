import Foundation

/// I testi del confronto «TFR in azienda o nel fondo», ricavati dai numeri (giro 6, specifica 11 §6.2–6.3).
/// Il report si rivolge al cliente con il tu. Nessun numero normativo scritto qui: aliquote, limiti e quote
/// si leggono da `RegoleTFR` e `RegoleFiscali`, così una norma nuova cambia anche i testi.
struct TestiTFR {
    let e: EsitoTFR
    let cliente: String
    let data: Date
    /// Età del cliente oggi, se nota (per la tabella anno per anno: «1 · 48 anni»).
    let eta: Int?

    init(_ e: EsitoTFR, cliente: Cliente?, data: Date = Date()) {
        self.e = e
        self.cliente = cliente?.nome ?? "Cliente"
        self.data = data
        self.eta = cliente?.dataNascita.flatMap { Calendar.current.dateComponents([.year], from: $0, to: data).year }
    }

    static let titolo = "TFR in azienda o nel fondo pensione"
    var piede: String { "\(Self.titolo) · \(cliente) · \(CifreDoc.data(data)) · \(TestiValutazione.consulente)" }
    static let avvertenza = "Stime con rendimenti e inflazione costanti e con le regole fiscali di oggi: non sono una previsione né un consiglio."

    var ruoloConsulente: String {
        switch e.ipotesi.canale {
        case .alleanza: return "Consulente Alleanza Assicurazioni"
        case .indipendente: return "Consulenza finanziaria"
        }
    }

    var canali: [Canale] { [e.ipotesi.canale] }

    var nomeFondo: String {
        let n = e.ipotesi.nomeFondo.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Fondo pensione" : n
    }

    /// Anni alla pensione: «1 anno», «20 anni».
    var anniAllaPensione: String { e.ipotesi.anni == 1 ? "1 anno" : "\(e.ipotesi.anni) anni" }

    /// Sotto questa differenza (in euro) le due strade si equivalgono.
    static let sogliaEquivalenza = 0.5

    // MARK: - Il confronto

    var titoloConfronto: String {
        let d = e.differenza
        if d > Self.sogliaEquivalenza { return "Nel fondo pensione ti resterebbero circa \(CifreDoc.euro(d)) in più" }
        if d < -Self.sogliaEquivalenza { return "Lasciato in azienda, il TFR ti lascerebbe circa \(CifreDoc.euro(-d)) in più" }
        return "Le due strade si equivalgono"
    }

    var sottotitoloConfronto: String {
        "Netto alla pensione tra \(anniAllaPensione): \(CifreDoc.euro(e.azienda.netto)) in azienda, \(CifreDoc.euro(e.fondo.netto)) nel fondo, con le regole fiscali di oggi."
    }

    /// La rivalutazione netta del TFR in azienda e l'inflazione: «del 2,49% netto con un'inflazione del 2%».
    private var rivalutazioneInParole: String {
        "\(Self.del(CifreDoc.percento(e.rivalutazioneNetta, decimali: 2))) netto con un'inflazione \(Self.del(Formati.percentuale(e.ipotesi.inflazione)))"
    }

    /// Le aliquote all'uscita: «il 13,5% invece del 28,4%».
    private var aliquoteInParole: (fondo: String, azienda: String) {
        (CifreDoc.percento(e.fondo.aliquota, decimali: 1), CifreDoc.percento(e.azienda.aliquota, decimali: 1))
    }

    var testoPareggio: String {
        let (fondo, azienda) = aliquoteInParole
        switch e.pareggio {
        case .a(let lordo, let netto):
            let soglia = "Il fondo conviene se rende in media più \(Self.del(CifreDoc.percento(lordo, decimali: 2))) lordo l'anno (\(CifreDoc.percento(netto, decimali: 2)) al netto di costi e imposta)."
            let tfr = " Il TFR in azienda si rivaluta \(rivalutazioneInParole): "
            let perche: String
            if netto < e.rivalutazioneNetta - 0.005 {
                perche = "il fondo può rendere meno perché all'uscita paga \(Self.il(fondo)) invece \(Self.del(azienda))."
            } else if netto > e.rivalutazioneNetta + 0.005 {
                perche = "il fondo deve rendere di più perché all'uscita paga \(Self.il(fondo)) contro \(Self.il(azienda)) del TFR in azienda."
            } else {
                perche = "all'uscita le due strade pagano più o meno la stessa imposta."
            }
            return soglia + tfr + perche
        case .sempre:
            return "Il fondo resta avanti anche se perde \(Self.il(Formati.percentuale(abs(RegoleTFR.pareggioMinimo)))) lordo l'anno: all'uscita paga \(Self.il(fondo)) invece \(Self.del(azienda)) del TFR in azienda."
        case .mai:
            return "Neanche con un rendimento lordo \(Self.del(Formati.percentuale(RegoleTFR.pareggioMassimo))) l'anno il fondo raggiunge il TFR in azienda: controlla le ipotesi."
        }
    }

    /// Il titolo della slide del pareggio nel report.
    var titoloPareggio: String {
        switch e.pareggio {
        case .a(let lordo, _): return "Il fondo conviene se rende più \(Self.del(CifreDoc.percento(lordo, decimali: 2))) lordo l'anno"
        case .sempre: return "Il fondo resta avanti anche nei casi peggiori"
        case .mai: return "Il fondo non raggiunge il TFR in azienda"
        }
    }

    /// Il pareggio in breve, per la sintesi.
    var pareggioBreve: String {
        switch e.pareggio {
        case .a(let lordo, let netto):
            return "Più \(Self.del(CifreDoc.percento(lordo, decimali: 2))) lordo l'anno (\(CifreDoc.percento(netto, decimali: 2)) netto), contro \(Self.il(CifreDoc.percento(e.rivalutazioneNetta, decimali: 2))) netto del TFR in azienda."
        case .sempre:
            return "Il fondo resta avanti anche se perde \(Self.il(Formati.percentuale(abs(RegoleTFR.pareggioMinimo)))) lordo l'anno."
        case .mai:
            return "Nemmeno con un rendimento lordo \(Self.del(Formati.percentuale(RegoleTFR.pareggioMassimo))) l'anno il fondo raggiunge il TFR in azienda."
        }
    }

    /// Il pareggio con i contributi, per la nota del KPI e del report.
    var pareggioContributiBreve: String? {
        guard let p = e.pareggioContributi else { return nil }
        switch p {
        case .a(let lordo, _):
            return "Con i contributi, contando quanto ti costano, il fondo conviene sopra \(Self.il(CifreDoc.percento(lordo, decimali: 2))) lordo l'anno."
        case .sempre:
            return "Con il contributo del datore e la deduzione dei tuoi versamenti il fondo resta avanti anche se perde \(Self.il(Formati.percentuale(abs(RegoleTFR.pareggioMinimo)))) l'anno."
        case .mai:
            return "Con i contributi, contando quanto ti costano, il fondo non raggiunge il TFR in azienda nemmeno con un rendimento lordo \(Self.del(Formati.percentuale(RegoleTFR.pareggioMassimo))) l'anno."
        }
    }

    /// «l'1,2% tuo e l'1,6% del datore»; nil senza contributi.
    var contributiInParole: String? {
        let i = e.ipotesi
        var parti: [String] = []
        if i.contributoLavoratore > 0 { parti.append("\(Self.il(Formati.percentuale(i.contributoLavoratore))) tuo") }
        if i.contributoDatore > 0 { parti.append("\(Self.il(Formati.percentuale(i.contributoDatore))) del datore") }
        return parti.isEmpty ? nil : parti.joined(separator: " e ")
    }

    var testoContributi: String? {
        guard let c = e.fondoContributi, let parole = contributiInParole, let d = e.differenzaContributi else { return nil }
        var testo = "Aggiungendo \(parole): \(CifreDoc.euro(c.netto)) netti."
        if e.versatoLavoratore > 0.5 {
            testo += " I tuoi contributi ti costano \(CifreDoc.euro(e.versatoLavoratore)), meno \(CifreDoc.euro(e.risparmioIrpef)) di IRPEF risparmiata."
        }
        if d > Self.sogliaEquivalenza {
            testo += " Tolto quanto ti costano, ti restano \(CifreDoc.euro(d)) in più che con il TFR in azienda."
        } else if d < -Self.sogliaEquivalenza {
            testo += " Tolto quanto ti costano, ti restano \(CifreDoc.euro(-d)) in meno che con il TFR in azienda."
        } else {
            testo += " Tolto quanto ti costano, le due strade si equivalgono."
        }
        return testo
    }

    /// I punti della sintesi (titolo, testo).
    var sintesi: [(String, String)] {
        var s: [(String, String)] = [("Le due strade", titoloConfronto + "."), ("Quanto deve rendere il fondo", pareggioBreve)]
        if let c = e.fondoContributi, let d = e.differenzaContributi {
            s.append(("Con i contributi", "\(CifreDoc.euro(c.netto)) netti; tolto quanto ti costano, \(CifreDoc.euroSegno(d)) rispetto al TFR in azienda."))
        }
        s.append(("In euro di oggi", "In azienda \(CifreDoc.euro(e.azienda.reale)), nel fondo \(CifreDoc.euro(e.fondo.reale))."))
        s.append(("Da sapere", "La scelta di versare il TFR al fondo non si può revocare."))
        return s
    }

    // MARK: - Metodo, semplificazioni, avvertenze

    /// "13,5", "0,30": un numero senza il segno di percentuale.
    private static func numero(_ v: Double, decimali: Int) -> String {
        String(CifreDoc.percento(v, decimali: decimali).dropLast())
    }

    /// L'anno di partecipazione dopo cui l'aliquota della prestazione comincia a scendere (15) e quello in cui
    /// arriva al minimo (35), ricavati da `RegoleFiscali.aliquotaPrevidenza`.
    private static var annoRiduzione: Int {
        (0...100).first { RegoleFiscali.aliquotaPrevidenza(anni: $0 + 1) < RegoleFiscali.previdenzaBase } ?? 0
    }

    static var metodo: [String] {
        let f = RegoleFiscali.self
        let r = RegoleTFR.self
        return [
            "Quota di TFR: retribuzione lorda / \(numero(r.divisore, decimali: 1)), meno lo \(CifreDoc.percento(r.contributoIVS, decimali: 2)) di contributo IVS (art. 2120 c.c.; art. 3 L. 297/1982): \(il(CifreDoc.percento(r.quotaAnnua, decimali: 2))) della retribuzione.",
            "In azienda (o al Fondo di Tesoreria INPS nelle aziende con almeno \(r.dipendentiTesoreria) dipendenti): rivalutazione al 31 dicembre \(del(Formati.percentuale(r.rivalutazioneFissa))) più \(il(Formati.percentuale(r.quotaInflazione * 100))) dell'inflazione FOI, esclusa la quota dell'anno, con l'imposta sostitutiva \(del(Formati.percentuale(r.impostaRivalutazione))) trattenuta ogni anno (art. 11, c. 3, D.Lgs. 47/2000).",
            "Alla fine del rapporto il TFR, tolte le rivalutazioni già tassate, va in tassazione separata con l'aliquota media IRPEF del reddito di riferimento: TFR × 12 / anni di servizio (art. 17 e 19 TUIR). L'imposta trattenuta dal datore è provvisoria: l'Agenzia delle Entrate la riliquida con l'aliquota media IRPEF dei cinque anni precedenti e chiede o restituisce la differenza.",
            "Nel fondo pensione: rendimento al netto dei costi (ISC) e dell'imposta \(del(Formati.percentuale(f.previdenzaRendimenti))) sui risultati positivi, \(Formati.percentuale(f.titoliStato)) sulla parte in titoli di Stato (art. 17 D.Lgs. 252/2005). Alla prestazione si tassano TFR e contributi dedotti con \(il(Formati.percentuale(f.previdenzaBase))), che scende di \(numero(f.previdenzaRiduzione, decimali: 2)) punti per ogni anno di partecipazione oltre il \(annoRiduzione)° fino al \(Formati.percentuale(f.previdenzaMinima)) (art. 11, c. 6).",
            "Contributi del lavoratore e del datore deducibili insieme fino a \(CifreDoc.euro(f.limiteDeducibilita)) l'anno (art. 8, c. 4, D.Lgs. 252/2005; dal 2026); il contributo del datore spetta di norma solo se aderisci al fondo di categoria e versi il minimo del contratto collettivo.",
            "Rendimento di pareggio: il rendimento lordo costante del fondo a cui il netto alla pensione è uguale a quello del TFR in azienda.",
        ]
    }

    static var semplificazioni: [String] {
        [
            "Rendimenti, inflazione e crescita della retribuzione costanti; quote e contributi a fine anno (per il fondo è prudente: nella realtà entrano ogni mese o trimestre).",
            "Il TFR già maturato resta in azienda in tutti e due i casi e non entra nel confronto.",
            "Aliquota della tassazione separata con gli scaglioni IRPEF di oggi sugli importi nominali (l'aliquota si può anche indicare a mano); la riliquidazione dell'Agenzia delle Entrate sui cinque anni precedenti non si stima.",
            "Prestazione mostrata tutta in capitale: alla pensione di norma al massimo \(il(Formati.percentuale(RegoleTFR.quotaCapitaleMassima))) si ritira in capitale, il resto diventa rendita.",
            "Risparmio IRPEF sul reddito da lavoro meno \(il(Formati.percentuale(RegoleTFR.contributiDipendente))) di contributi INPS, senza detrazioni né addizionali; il costo dei tuoi contributi è portato alla pensione alla rivalutazione netta del TFR.",
            "Anticipazioni, riscatti, cambi di lavoro e garanzie dei comparti non considerati.",
        ]
    }

    static let daSapere: [String] = [
        "La scelta di versare il TFR futuro al fondo pensione non si può revocare (art. 8 D.Lgs. 252/2005).",
        "Nel fondo il valore oscilla con i mercati secondo il comparto; il TFR in azienda non scende mai.",
        "Le anticipazioni sono possibili in tutti e due i casi, con regole e imposte diverse.",
    ]

    // MARK: - Articoli davanti ai numeri

    /// true se il numero scritto si legge con una vocale: 1 («uno»), 8 («otto», «ottanta»), 11 («undici»).
    static func iniziaConVocale(_ numero: String) -> Bool {
        let c = Array(numero)
        guard let primo = c.first else { return false }
        if primo == "8" { return true }
        guard primo == "1" else { return false }
        // «1», «1,5%»: uno; «11», «11,3%»: undici; «1.500», «12», «150»: no
        let secondo: Character? = c.count > 1 ? c[1] : nil
        if secondo == nil || secondo == "," || secondo == "%" || secondo == " " { return true }
        if secondo == "1" {
            let terzo: Character? = c.count > 2 ? c[2] : nil
            return terzo == nil || terzo == "," || terzo == "%" || terzo == " "
        }
        return false
    }

    /// «del 2%», «dell'1,5%».
    static func del(_ numero: String) -> String { iniziaConVocale(numero) ? "dell'\(numero)" : "del \(numero)" }
    /// «il 2%», «l'8%».
    static func il(_ numero: String) -> String { iniziaConVocale(numero) ? "l'\(numero)" : "il \(numero)" }
}
