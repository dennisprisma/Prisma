import Foundation

/// Cifre nello stile dei documenti per i clienti: "€ 50.000", "− € 200", "+4,5%", "3,10%".
enum CifreDoc {
    static let meno = "−"

    static func euro(_ v: Double) -> String {
        let n = Formati.numeroFormatter.string(from: NSNumber(value: abs(v).rounded())) ?? "\(Int(abs(v)))"
        return (v.rounded() < 0 ? "\(meno) " : "") + "€ \(n)"
    }

    /// Al centesimo: "€ 4.212,35".
    static func euroCentesimi(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Formati.localeImporti
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        let n = f.string(from: NSNumber(value: abs(v))) ?? "\(abs(v))"
        return ((v * 100).rounded() < 0 ? "\(meno) " : "") + "€ \(n)"
    }

    /// Con il segno esplicito: "+ € 3.521", "− € 1.160".
    static func euroSegno(_ v: Double) -> String {
        v.rounded() < 0 ? euro(v) : "+ \(euro(v))"
    }

    /// Una sottrazione: "− € 200" anche se l'importo è positivo.
    static func togli(_ v: Double) -> String { "\(meno) \(euro(abs(v)))" }

    /// Percentuale con il numero di decimali voluto: "3,10%", "2,5%".
    /// Un formattatore per numero di decimali (0–4), creato una volta sola.
    private static let formattatori: [NumberFormatter] = (0...4).map { d in
        let f = NumberFormatter()
        f.locale = Formati.localeImporti
        f.numberStyle = .decimal
        f.minimumFractionDigits = d
        f.maximumFractionDigits = d
        return f
    }

    static func percento(_ v: Double, decimali: Int = 1) -> String {
        let f = formattatori[min(max(decimali, 0), formattatori.count - 1)]
        let s = f.string(from: NSNumber(value: abs(v))) ?? "\(abs(v))"
        return (v < 0 && (v * pow(10, Double(decimali))).rounded() != 0 ? meno : "") + s + "%"
    }

    /// Con il segno: "+4,5%", "−5,7%".
    static func variazione(_ v: Double, decimali: Int = 1) -> String {
        // Il segno sul numero scritto: −0,03 diventa "+0,0%", non "0,0%"
        let s = percento(v, decimali: decimali)
        return s.hasPrefix(meno) ? s : "+" + s
    }

    /// Percentuale senza decimali superflui: "1%", "1,5%".
    static func condizione(_ v: Double) -> String { Formati.percentuale(v) }

    /// Penale di riscatto con un decimale ("3,5%", "1,0%"), "0%" se non c'è.
    static func penale(_ v: Double) -> String { v == 0 ? "0%" : percento(v) }

    static func data(_ d: Date) -> String { Formati.dataEstesa.string(from: d) }
    static func dataBreve(_ d: Date) -> String { Formati.dataBreve.string(from: d) }
}

/// I testi di una valutazione, ricavati dai numeri. Il consulente scrive solo i giudizi
/// (perché degli scenari, nota sullo scenario centrale, consiglio); il resto lo compone Prisma.
struct TestiValutazione {
    let v: ValutazioneInvestimento
    let prodotto: Prodotto
    let c: CondizioniContratto
    let e: EsitoValutazione

    init(_ v: ValutazioneInvestimento, prodotto: Prodotto, condizioni: CondizioniContratto) {
        self.v = v
        self.prodotto = prodotto
        self.c = condizioni
        self.e = MotoreValutazione.calcola(v, condizioni: condizioni)
    }

    // MARK: - Voi o tu

    /// Sceglie la forma giusta: voi per più intestatari, tu per uno solo.
    func f(_ voi: String, _ tu: String) -> String { v.plurale ? voi : tu }

    static let consulente = "Denis Vicenzoni"

    var ruoloConsulente: String {
        prodotto.canale == .alleanza ? "Consulente Alleanza Assicurazioni" : "Consulenza finanziaria"
    }

    // MARK: - Riferimenti

    var intermedio: EsitoScenarioValutazione? { e.scenario(.intermedio) }
    var primoAnno: Int { (c.mesiBloccoRiscatto + 11) / 12 + 1 }
    var meseIniziale: Int { (primoAnno - 1) * 12 + 1 }
    var anni: [Int] { e.anniRiscatto }
    var ultimoAnno: Int { anni.last ?? primoAnno }
    var fondo: ComponenteContratto? { c.componenti.first { $0.tipo == .fondoInterno } }
    var gestione: ComponenteContratto? { c.componenti.first { $0.tipo == .gestioneSeparata } }

    func netto(_ t: TipoScenario, _ anno: Int) -> Double { e.scenario(t)?.riscatto(anno: anno)?.netto ?? 0 }

    static func ordinale(_ n: Int) -> String { "\(n)°" }

    func etichettaMese(_ anno: Int) -> String { "\((anno - 1) * 12 + 1)° mese" }

    // MARK: - Copertina e proposta

    var sottotitoloCopertina: String { "Incassi, anno per anno, in tre scenari di mercato" }

    var riscattoPossibile: String { "Possibile dal \(meseIniziale)° mese" }

    var titoloProposta: String {
        switch (gestione != nil, fondo != nil) {
        case (true, true): return "Un investimento diviso tra stabilità e crescita"
        case (false, true): return "Un investimento orientato alla crescita"
        default: return "Un investimento orientato alla stabilità"
        }
    }

    var sottotitoloProposta: String {
        let esigenza = v.esigenza.isEmpty ? f("Volete far crescere \(CifreDoc.euro(v.premio)).", "Vuoi far crescere \(CifreDoc.euro(v.premio)).") : v.esigenza
        return esigenza + " " + f("Per questo vi mostriamo quanto incassereste davvero, anno per anno, al netto di costi, penali e imposte.",
                                  "Per questo ti mostro quanto incasseresti davvero, anno per anno, al netto di costi, penali e imposte.")
    }

    var etichettaIngresso: String {
        "Costo di ingresso (\(CifreDoc.condizione(c.costoIngresso))" + (c.costoIngressoMassimo.map { ", max \(CifreDoc.euro($0))" } ?? "") + ")"
    }

    // MARK: - Numeri di partenza

    /// Rendimento del fondo dal primo all'ultimo valore della quota (%).
    var fondoDalLancio: Double? {
        guard let s = fondo?.storico.compactMap(\.valore), let a = s.first, let b = s.last, s.count >= 2, a > 0 else { return nil }
        return (b / a - 1) * 100
    }

    /// Rendimento del fondo dall'ultima fine anno (%).
    var fondoDaInizioAnno: Double? {
        guard let s = fondo?.storico.compactMap(\.valore), s.count >= 2, s[s.count - 2] > 0 else { return nil }
        return (s[s.count - 1] / s[s.count - 2] - 1) * 100
    }

    var fondoUltimaQuota: PuntoStorico? { fondo?.storico.last { $0.valore != nil } }

    var mediaGestione: Double? {
        let s = gestione?.storico.compactMap(\.valore) ?? []
        return s.isEmpty ? nil : s.reduce(0, +) / Double(s.count)
    }

    var sottotitoloPartenza: String {
        var parti: [String] = []
        if let f = fondo { parti.append(f.storico.count <= 3 ? "Il fondo ha una storia breve" : "Il fondo ha una storia di più anni") }
        if gestione != nil { parti.append("la Gestione separata ha un andamento regolare da anni") }
        return parti.isEmpty ? "" : parti.joined(separator: "; ") + "."
    }

    var titoloNotaCentrale: String {
        guard let f = fondo else { return "Perché queste ipotesi" }
        return "Perché nello scenario centrale usiamo il \(CifreDoc.condizione(v.scenario(.intermedio).rendimento(f)))"
    }

    // MARK: - Scenari

    func rendimentoTitolo(_ t: TipoScenario) -> String {
        let s = v.scenario(t)
        if let f = fondo { return "\(CifreDoc.variazione(s.rendimento(f), decimali: 0)) l'anno" }
        if let g = gestione { return "\(CifreDoc.percento(s.rendimento(g) - g.trattenuto, decimali: 2)) l'anno" }
        return ""
    }

    func gestioneScenario(_ t: TipoScenario) -> String? {
        guard let g = gestione else { return nil }
        let r = v.scenario(t).rendimento(g)
        return "\(CifreDoc.percento(r, decimali: 2)) lordo · \(CifreDoc.percento(r - g.trattenuto, decimali: 2)) netto"
    }

    // MARK: - Quanto si incassa

    var sottotitoloIncassi: String {
        guard let i = intermedio else { return "" }
        var frase: String
        if let recupero = i.riscatti.first(where: { $0.netto >= v.premio }) {
            frase = f("Nello scenario intermedio recuperate il capitale già al \(recupero.anno)° anno",
                      "Nello scenario intermedio recuperi il capitale già al \(recupero.anno)° anno")
            let dopo = i.riscatti.filter { $0.anno > recupero.anno }
            let salti = zip([recupero] + dopo, dopo).map { $1.netto - $0.netto }
            if let minimo = salti.min(), let massimo = salti.max(), minimo > 0 {
                let a = (minimo / 100).rounded() * 100, b = (massimo / 100).rounded() * 100
                let intervallo = a == b ? CifreDoc.euro(a) : "\(CifreDoc.euro(a))–\(Formati.numeroFormatter.string(from: NSNumber(value: b)) ?? "")"
                frase += f(", poi guadagnate circa \(intervallo) l'anno", ", poi guadagni circa \(intervallo) l'anno")
            }
            frase += "."
        } else {
            frase = "Nello scenario intermedio il premio versato non si recupera entro il \(ultimoAnno)° anno."
        }
        return frase + " Importi netti con riscatto totale all'inizio di ciascun anno: già tolti costi, penali, imposta sostitutiva e bollo."
    }

    func forbice(_ anno: Int) -> String {
        let fav = netto(.favorevole, anno), sfav = netto(.sfavorevole, anno), int = netto(.intermedio, anno)
        return "tra \(CifreDoc.euro(min(fav, sfav))) e \(CifreDoc.euro(max(fav, sfav))); scenario intermedio \(CifreDoc.euro(int))"
    }

    var fraseSenzaPenali: String {
        "nessuna penale di riscatto: restano solo l'imposta sostitutiva e il bollo"
    }

    // MARK: - Andamento

    var titoloAndamento: String {
        let sfav = e.scenario(.sfavorevole)?.riscatti ?? []
        if !sfav.isEmpty && sfav.allSatisfy({ $0.netto < v.premio }) {
            return "Nello scenario sfavorevole si resta sotto i \(CifreDoc.euro(v.premio))"
        }
        if TipoScenario.allCases.allSatisfy({ (e.scenario($0)?.riscatti.last?.netto ?? 0) >= v.premio }) {
            return "In tutti gli scenari si torna sopra i \(CifreDoc.euro(v.premio))"
        }
        return "Tre strade diverse a partire da \(CifreDoc.euro(v.premio))"
    }

    func raccontoAndamento(_ t: TipoScenario) -> String {
        guard let r = e.scenario(t)?.riscatti, let a = r.first, let b = r.last else { return "" }
        // Gli anni si contano dal versamento, come nel report di Denis ("in cinque anni" fino al 61° mese)
        let n = b.anniTrascorsi
        let anni = n == 1 ? "un anno" : "\(n) anni"
        switch t {
        case .favorevole:
            return "Da \(CifreDoc.euro(a.netto)) al \(a.mese)° mese a \(CifreDoc.euro(b.netto)) al \(b.mese)° mese: \(CifreDoc.variazione(b.variazione, decimali: 0)) sul versato."
        case .intermedio:
            return "Si parte da \(CifreDoc.euro(a.netto)) e si arriva a \(CifreDoc.euro(b.netto)): circa \(CifreDoc.variazione(b.variazione, decimali: 0)) in \(anni)."
        case .sfavorevole:
            let valori = r.map(\.netto)
            if valori.allSatisfy({ $0 < v.premio }), let lo = valori.min(), let hi = valori.max() {
                return "Si resta tra \(CifreDoc.euro(lo)) e \(CifreDoc.euro(hi)): una perdita contenuta ma costante, senza recupero entro \(anni == "un anno" ? "l'anno" : "i \(anni)")."
            }
            return "Da \(CifreDoc.euro(a.netto)) a \(CifreDoc.euro(b.netto)): \(CifreDoc.variazione(b.variazione, decimali: 0)) sul versato."
        }
    }

    // MARK: - Primo riscatto

    var titoloPrimoRiscatto: String {
        guard let r = intermedio?.riscatti.first else { return "" }
        return r.penalePercento > 0 ? "Riscatto al \(r.mese)° mese: la penale pesa sulla crescita" : "Riscatto al \(r.mese)° mese"
    }

    var sottotitoloPrimoRiscatto: String {
        guard let r = intermedio?.riscatti.first else { return "" }
        let quasi = abs(r.netto - v.premio) / v.premio < 0.01
        return "Nello scenario intermedio, dopo un anno il contratto vale \(CifreDoc.euro(r.valore)); tolti penale, imposte e bollo "
            + f("vi restano", "ti restano") + " \(CifreDoc.euro(r.netto))" + (quasi ? ": in pratica il capitale versato." : ".")
    }

    /// Il consiglio del consulente, o una frase ricavata dai numeri.
    var consiglio: String {
        if !v.consiglio.isEmpty { return v.consiglio }
        guard let i = intermedio, let r = i.riscatti.first, r.penale > 0 else { return "" }
        let crescita = r.valore - e.capitale
        guard crescita > 0 else { return "La penale si somma a un primo anno senza crescita: meglio non riscattare subito." }
        let quota = r.penale / crescita
        let parole = quota > 0.9 ? "quasi tutta" : quota > 0.6 ? "circa tre quarti" : quota > 0.4 ? "circa la metà" : "una parte"
        return "La penale del \(CifreDoc.condizione(r.penalePercento)) assorbe \(parole) della crescita del primo anno."
    }

    // MARK: - Penali

    var sottotitoloPenali: String {
        c.penali.isEmpty ? "Il riscatto non prevede penali." : "Ogni anno in più riduce la penale, e dal \(c.annoSenzaPenali)° anno non c'è più."
    }

    var aspettareConviene: String {
        guard let i = intermedio, let a = i.riscatti.first, let b = i.riscatto(anno: a.anno + 1) else { return "" }
        return "Nello scenario intermedio, passando dal \(a.mese)° al \(b.mese)° mese la penale scende da \(CifreDoc.euro(a.penale)) a \(CifreDoc.euro(b.penale)) e l'importo netto sale da \(CifreDoc.euro(a.netto)) a \(CifreDoc.euro(b.netto))."
    }

    var elencoPenali: String {
        c.penali.map { CifreDoc.penale($0) }.joined(separator: " · ")
    }

    var anniPenali: String {
        let anni = c.penali.indices.map { "\($0 + 2)°" }
        guard anni.count > 1 else { return anni.first.map { "nel \($0) anno" } ?? "" }
        return "nel " + anni.dropLast().joined(separator: ", ") + " e \(anni.last!) anno"
    }

    // MARK: - Costi

    /// Incidenza media dei costi dal 2° anno (%), per il titolo.
    var incidenzaMedia: Double {
        let costi = intermedio?.costi.dropFirst() ?? []
        guard !costi.isEmpty else { return intermedio?.costi.first?.incidenza ?? 0 }
        return costi.reduce(0) { $0 + $1.incidenza } / Double(costi.count)
    }

    var titoloCosti: String { "Costi e trattenute: circa il \(CifreDoc.percento((incidenzaMedia * 10).rounded() / 10)) l'anno" }

    var notaCosti: String {
        var s = c.penali.isEmpty ? "In caso di riscatto si aggiunge l'imposta sostitutiva sul guadagno."
            : "In caso di riscatto si aggiungono la penale (\(elencoPenali) \(anniPenali)) e l'imposta sostitutiva sul guadagno."
        if let kid = prodotto.costoAnnuo { s += " Costi correnti indicati nel KID: \(CifreDoc.percento(kid, decimali: 2)) l'anno, senza il bollo." }
        return s
    }

    // MARK: - Imposte

    var aliquotaMedia: Double { MotoreValutazione.aliquotaMedia(c) }

    var testoImposta: String {
        "sul guadagno (incassato meno versato): \(CifreDoc.condizione(c.aliquota)), ridotto per la parte di titoli di Stato (\(CifreDoc.condizione(c.aliquotaTitoliStato))). Senza guadagno non si paga."
    }

    var testoBollo: String {
        "all'anno sulle sole quote del Fondo Interno: calcolata ogni anno, trattenuta al pagamento."
    }

    // MARK: - KID

    /// Rendimento lordo medio della simulazione per uno scenario KID, all'anno indicato.
    func simulazioneKID(_ nome: String, anno: Int) -> Double? {
        let t: TipoScenario?
        switch nome.lowercased() {
        case let n where n.hasPrefix("sfav"): t = .sfavorevole
        case let n where n.hasPrefix("moder") || n.hasPrefix("interm"): t = .intermedio
        case let n where n.hasPrefix("fav"): t = .favorevole
        default: t = nil
        }
        return t.flatMap { e.scenario($0)?.riscatto(anno: anno)?.rendimentoLordo }
    }

    var annoKID: Int { min(c.anniKID + 1, ultimoAnno) }

    var commentoKID: String {
        "La simulazione usa andamenti costanti, il KID scenari statistici: le differenze sono normali. Lo stress del KID mostra cosa può succedere in condizioni di mercato estreme."
    }

    var avvertenze: String {
        "Documento illustrativo predisposto dal consulente: non è un'offerta né una promessa di rendimento. Gli scenari sono ipotesi costruite su dati storici e possono non verificarsi; i rendimenti passati non sono indicativi di quelli futuri. Prima della sottoscrizione leggere KID, DIP aggiuntivo IBIP e Condizioni di assicurazione"
            + (c.dataDocumenti.map { " (\(CifreDoc.dataBreve($0)))" } ?? "") + ", che prevalgono su questo documento."
    }

    // MARK: - Sintesi

    var sintesi: [(String, String)] {
        var punti: [(String, String)] = []
        if let a = anni.first {
            let int = netto(.intermedio, a)
            let recupero = abs(int - v.premio) / v.premio < 0.01
            punti.append(("Al \(etichettaMese(a))", (recupero ? f(" recuperate circa il capitale nello scenario intermedio", " recuperi circa il capitale nello scenario intermedio") + " (\(CifreDoc.euro(int)))"
                                                    : " lo scenario intermedio vale \(CifreDoc.euro(int))")
                          + "; l'importo va da \(CifreDoc.euro(netto(.sfavorevole, a))) a \(CifreDoc.euro(netto(.favorevole, a))) a seconda dei mercati."))
        }
        if anni.count > 1 {
            let b = anni[1]
            punti.append(("Al \(etichettaMese(b))", " la forbice va da \(CifreDoc.euro(netto(.sfavorevole, b))) a \(CifreDoc.euro(netto(.favorevole, b))), con \(CifreDoc.euro(netto(.intermedio, b))) nello scenario intermedio."))
        }
        punti.append((c.penali.isEmpty ? "Nessuna penale" : "Ogni anno in più riduce la penale",
                      (c.penali.isEmpty ? "" : ": dal \(c.annoSenzaPenali)° anno non c'è più.") + " I costi correnti restano intorno al \(CifreDoc.percento((incidenzaMedia * 10).rounded() / 10)) l'anno."))
        if let rhp = c.periodoRaccomandato {
            punti.append(("\(prodotto.nome) è un investimento da tenere nel tempo", ": il periodo di detenzione raccomandato dal KID è di \(rhp) anni."))
        }
        return punti
    }

    // MARK: - Appendice e fonti

    var comeLeggere: String {
        var s = "Riscatto totale richiesto all'inizio di ciascun anno, rendimenti annui costanti; bollo sul valore delle quote a fine anno"
        let aliquote = c.componenti.map { "\(CifreDoc.percento(c.aliquotaParte($0))) sulla \($0.tipo == .gestioneSeparata ? "Gestione separata" : "parte nel Fondo Interno")" }
        if !aliquote.isEmpty { s += "; imposta sostitutiva stimata al " + aliquote.joined(separator: " e al ") }
        if let f = fondo, f.costiSottostanti > 0 { s += "; costi dei fondi sottostanti (circa \(CifreDoc.percento(f.costiSottostanti)) l'anno) stimati dai KID" }
        return s + ". Importi arrotondati all'euro."
    }

    var piede: String {
        "\(prodotto.nome) · Prospetto illustrativo · Premio \(CifreDoc.euro(v.premio))" + (c.componenti.isEmpty ? "" : " · \(c.composizioneBreve)")
            + (c.versione.isEmpty ? "" : " · \(c.versione.components(separatedBy: ",").first ?? c.versione)")
    }

    static let piedeAvvertenza = "Documento illustrativo: non sostituisce il KID, il DIP aggiuntivo IBIP e le Condizioni di assicurazione."
}
