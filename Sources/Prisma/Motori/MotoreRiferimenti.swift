import Foundation

// Rendimento contro un riferimento (giro 6, specifica 11, §4.1): lo stesso periodo dell'andamento di una posizione
// misurato con un metro esterno (inflazione, rivalutazione netta del TFR, gestioni separate, un indice del
// consulente). Motore puro: nessuna cache, pochi anni per volta.

/// Da dove viene un valore annuo.
enum OrigineValore { case prisma, consulente, stimato }

struct ValoreAnnuo: Equatable {
    let valore: Double
    let origine: OrigineValore
}

/// Le serie di riferimento con i loro valori: quelle di Prisma corrette dal consulente, il TFR ricavato
/// dall'inflazione, gli indici del consulente. Struttura pura, costruita dalle impostazioni.
struct TabellaRiferimenti {
    /// Inflazione, TFR, gestioni separate e gli indici (in quest'ordine).
    var serie: [SerieRiferimento] { elenco }
    private let elenco: [SerieRiferimento]
    /// I valori del consulente per serie e anno (un doppione: vale l'ultimo).
    private let consulente: [String: [Int: Double]]

    init(_ r: RiferimentiRendimento) {
        var tutte = [TabellaRiferimenti.serieInflazione, TabellaRiferimenti.serieTFR, TabellaRiferimenti.serieGestioniSeparate]
        for i in r.indici where !i.id.isEmpty && !tutte.contains(where: { $0.id == i.id }) {
            let nome = i.nome.trimmingCharacters(in: .whitespacesAndNewlines)
            let fonte = i.fonte.trimmingCharacters(in: .whitespacesAndNewlines)
            let mostrato = nome.isEmpty ? TestiRiferimenti.indiceSenzaNome : nome
            tutte.append(SerieRiferimento(id: i.id, tipo: .indice, nome: mostrato, nomeFrase: mostrato,
                                          fonte: fonte.isEmpty ? TestiRiferimenti.fonteIndice : fonte))
        }
        elenco = tutte
        var valori: [String: [Int: Double]] = [:]
        // Un valore che azzererebbe il fattore (−100% o meno) non è un rendimento annuo: si ignora
        for v in r.valori where v.leggibile && v.valore > -100 {
            valori[v.serie, default: [:]][v.anno] = v.valore
        }
        consulente = valori
    }

    /// La serie con questo id (nil se non c'è più, per esempio un indice eliminato).
    func serie(_ id: String) -> SerieRiferimento? {
        elenco.first { $0.id == id }
    }

    /// Il valore di un anno: quello del consulente se c'è, altrimenti quello di Prisma; nil se nessuno.
    /// Per il TFR: `RegoleTFR.rivalutazioneNetta(inflazione:)` del valore d'inflazione dello stesso anno,
    /// con la stessa origine.
    func valore(_ serie: String, anno: Int) -> ValoreAnnuo? {
        if serie == SerieRiferimento.idTFR {
            guard let i = valore(SerieRiferimento.idInflazione, anno: anno) else { return nil }
            return ValoreAnnuo(valore: RegoleTFR.rivalutazioneNetta(inflazione: i.valore), origine: i.origine)
        }
        guard elenco.contains(where: { $0.id == serie }) else { return nil }
        if let v = consulente[serie]?[anno] { return ValoreAnnuo(valore: v, origine: .consulente) }
        if let v = Self.prisma(serie)[anno] { return ValoreAnnuo(valore: v, origine: .prisma) }
        return nil
    }

    /// L'ultimo anno con un valore (per il TFR quello dell'inflazione); nil se la serie è vuota.
    func ultimoAnno(_ serie: String) -> Int? {
        if serie == SerieRiferimento.idTFR { return ultimoAnno(SerieRiferimento.idInflazione) }
        guard elenco.contains(where: { $0.id == serie }) else { return nil }
        let anni = Array((consulente[serie] ?? [:]).keys) + Array(Self.prisma(serie).keys)
        return anni.max()
    }

    /// Il valore di Prisma di una serie e un anno (nil se Prisma non ne porta): il consulente non lo deve riscrivere.
    static func valorePrisma(_ serie: String, anno: Int) -> Double? {
        prisma(serie)[anno]
    }

    /// I valori che Prisma porta con sé per una serie (solo inflazione e gestioni separate).
    private static func prisma(_ serie: String) -> [Int: Double] {
        switch serie {
        case SerieRiferimento.idInflazione: return RiferimentiStorici.inflazione
        case SerieRiferimento.idGestioniSeparate: return RiferimentiStorici.gestioniSeparate
        default: return [:]
        }
    }

    // MARK: Le serie di Prisma

    static let serieInflazione = SerieRiferimento(
        id: SerieRiferimento.idInflazione, tipo: .inflazione, nome: TestiRiferimenti.nomeInflazione,
        nomeFrase: TestiRiferimenti.fraseInflazione, fonte: RiferimentiStorici.fonteInflazione)
    static let serieTFR = SerieRiferimento(
        id: SerieRiferimento.idTFR, tipo: .tfr, nome: TestiRiferimenti.nomeTFR,
        nomeFrase: TestiRiferimenti.fraseTFR, fonte: RiferimentiStorici.fonteTFR)
    static let serieGestioniSeparate = SerieRiferimento(
        id: SerieRiferimento.idGestioniSeparate, tipo: .gestioniSeparate, nome: TestiRiferimenti.nomeGestioniSeparate,
        nomeFrase: TestiRiferimenti.fraseGestioniSeparate, fonte: RiferimentiStorici.fonteGestioniSeparate)
}

/// Un anno del periodo, per la tabella del pannello.
struct AnnoRiferimento: Identifiable {
    let anno: Int
    /// nil se manca.
    let valore: Double?
    /// `.stimato` se preso dall'ultimo anno noto.
    let origine: OrigineValore?
    /// Giorni dell'anno dentro il periodo.
    let giorni: Int
    /// 365 o 366.
    let giorniAnno: Int
    var id: Int { anno }
}

struct FattoreRiferimento {
    /// Π (1 + v/100)^(giorni/giorniAnno); nil se mancano anni o i valori sono troppo vecchi.
    let fattore: Double?
    let anni: [AnnoRiferimento]
    /// Anni del periodo senza valore che non si possono stimare (prima o uguali all'ultimo anno noto).
    let mancanti: [Int]
    /// Anni dopo l'ultimo noto, presi con il valore dell'ultimo anno noto.
    let stimati: [Int]
    let ultimoAnno: Int?
    /// true se la fine del periodo è oltre `ultimoAnno + anniStimabili` (o la serie è vuota).
    let daAggiornare: Bool
}

struct VersamentiAlRiferimento {
    /// Valore che avrebbero oggi i versamenti (e gli incassi) se fossero cresciuti come il riferimento.
    let valoreRiferimento: Double
    /// Valore vero della posizione alla stessa data.
    let valoreEffettivo: Double
    var differenza: Double { valoreEffettivo - valoreRiferimento }
    /// Rendimento annuo (XIRR) degli stessi flussi con i due valori finali.
    let tassoRiferimento: Double?
    let tassoEffettivo: Double?
    /// Data del primo flusso.
    let dal: Date
    let stimati: [Int]
}

struct ConfrontoRiferimento {
    enum Giudizio { case sopra, inLinea, sotto }

    let serie: SerieRiferimento
    /// true se la serie è quella scelta per la posizione o per il suo tipo; false se Prisma è ripiegato
    /// sull'inflazione perché il metro predefinito non ha valori (§4.1, regola 6).
    let sceltaRispettata: Bool
    let dal: Date
    let al: Date
    /// = andamento.anni
    let anni: Double
    /// = andamento.rendimentoAnnuo != nil
    let annuo: Bool
    /// Annuo o del periodo, come l'andamento.
    let effettivo: Double
    let fattore: FattoreRiferimento
    /// Stesso orizzonte di `effettivo`.
    let riferimento: Double?
    var scarto: Double? { riferimento.map { effettivo - $0 } }
    /// Solo con l'inflazione: (1 + effettivo) / (1 + riferimento) − 1, in %.
    let reale: Double?
    let giudizio: Giudizio?
    /// Il valore rilevato con, in `atteso`, il percorso al ritmo del riferimento (per `GraficoAndamento`).
    let punti: [AndamentoPosizione.Punto]
    let versamenti: VersamentiAlRiferimento?
    /// Primo anno dei flussi per cui mancano valori (il confronto dei versamenti non si fa).
    let versamentiMancantiDal: Int?
}

enum MotoreRiferimenti {
    /// Anni dopo l'ultimo valore noto che si possono stimare con quel valore: l'anno in corso e quello appena
    /// chiuso, che l'ISTAT pubblica a metà gennaio.
    static let anniStimabili = 2
    /// Punti percentuali all'anno entro cui la posizione è «in linea» con il riferimento.
    static let tolleranza = 0.5
    /// Sui periodi sotto l'anno la tolleranza è in proporzione agli anni, ma almeno questa.
    static let tolleranzaMinima = 0.25
    /// I valori annui che il consulente può scrivere (%): sotto il −100% il fattore non ha senso.
    static let valoreMinimo = -99.0
    static let valoreMassimo = 1_000.0

    /// Il calendario dei conti: gregoriano, nel fuso del Mac (i giorni come li vede il consulente).
    private static var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    /// Il fattore del riferimento tra due date, anno per anno sui giorni del periodo (§4.1, regole 1–3).
    static func fattore(_ serie: String, dal: Date, al: Date, tabella: TabellaRiferimenti) -> FattoreRiferimento {
        let cal = calendario
        let inizio = cal.startOfDay(for: dal)
        let fine = cal.startOfDay(for: al)
        let ultimo = tabella.ultimoAnno(serie)
        guard fine > inizio else {
            return FattoreRiferimento(fattore: 1, anni: [], mancanti: [], stimati: [], ultimoAnno: ultimo, daAggiornare: false)
        }
        let primoAnno = cal.component(.year, from: inizio)
        let ultimoDelPeriodo = cal.component(.year, from: fine)
        var f = 1.0
        var anni: [AnnoRiferimento] = []
        var mancanti: [Int] = []
        var stimati: [Int] = []
        for y in primoAnno...max(primoAnno, ultimoDelPeriodo) {
            guard let capodanno = cal.date(from: DateComponents(year: y, month: 1, day: 1)),
                  let seguente = cal.date(from: DateComponents(year: y + 1, month: 1, day: 1)) else { continue }
            let a = max(inizio, capodanno)
            let b = min(fine, seguente)
            let giorni = cal.dateComponents([.day], from: a, to: b).day ?? 0
            guard giorni > 0 else { continue }
            let giorniAnno = cal.range(of: .day, in: .year, for: capodanno)?.count ?? 365
            var valore: Double?
            var origine: OrigineValore?
            if let v = tabella.valore(serie, anno: y) {
                valore = v.valore
                origine = v.origine
            } else if let u = ultimo, y > u, let v = tabella.valore(serie, anno: u) {
                valore = v.valore
                origine = .stimato
                stimati.append(y)
            } else {
                mancanti.append(y)
            }
            if let v = valore {
                f *= pow(1 + v / 100, Double(giorni) / Double(giorniAnno))
            }
            anni.append(AnnoRiferimento(anno: y, valore: valore, origine: origine, giorni: giorni, giorniAnno: giorniAnno))
        }
        let daAggiornare = ultimo.map { ultimoDelPeriodo - $0 > anniStimabili } ?? true
        let valido = mancanti.isEmpty && !daAggiornare && f.isFinite && f > 0
        return FattoreRiferimento(fattore: valido ? f : nil, anni: anni, mancanti: mancanti, stimati: stimati,
                                  ultimoAnno: ultimo, daAggiornare: daAggiornare)
    }

    /// Il metro della posizione (§4.1, regola 6): quello scelto per la posizione, poi quello del suo tipo nelle
    /// impostazioni, poi quello di Prisma per il tipo. Se il metro di Prisma non ha valori (le gestioni separate
    /// vuote) si ripiega sull'inflazione con `rispettata = false`; una scelta esplicita senza valori non ripiega.
    static func serieDi(_ p: Posizione, impostazioni: RiferimentiRendimento, tabella: TabellaRiferimenti)
        -> (serie: SerieRiferimento, rispettata: Bool) {
        if let id = p.riferimento, let s = tabella.serie(id) { return (s, true) }
        let famiglia = FamigliaRiferimento.di(p)
        if let id = impostazioni.scelta(per: famiglia), let s = tabella.serie(id) { return (s, true) }
        let inflazione = tabella.serie(SerieRiferimento.idInflazione) ?? TabellaRiferimenti.serieInflazione
        guard let predefinita = tabella.serie(famiglia.seriePredefinita) else { return (inflazione, false) }
        if tabella.ultimoAnno(predefinita.id) != nil { return (predefinita, true) }
        return (inflazione, predefinita.id == inflazione.id)
    }

    /// Il confronto dello stesso periodo dell'andamento con il riferimento (§4.1, regole 4–9).
    static func confronto(_ p: Posizione, andamento a: AndamentoPosizione, flussi: MotoreResoconto.FlussiDatati?,
                          serie: SerieRiferimento, rispettata: Bool, tabella: TabellaRiferimenti) -> ConfrontoRiferimento {
        let f = fattore(serie.id, dal: a.dal, al: a.al, tabella: tabella)
        let annuo = a.rendimentoAnnuo != nil
        let effettivo = a.rendimentoAnnuo ?? a.rendimentoPeriodo
        // Stesso orizzonte dell'andamento: annualizzato con gli stessi anni (giorni / 365,25)
        var riferimento: Double?
        if let F = f.fattore {
            if !annuo {
                riferimento = (F - 1) * 100
            } else if a.anni > 0 {
                riferimento = (pow(F, 1 / a.anni) - 1) * 100
            }
        }
        let reale: Double? = serie.tipo == .inflazione
            ? riferimento.map { r in ((1 + effettivo / 100) / (1 + r / 100) - 1) * 100 }
            : nil

        var giudizio: ConfrontoRiferimento.Giudizio?
        if let r = riferimento, a.anni >= MotoreAndamento.anniGiudizio {
            let s = effettivo - r
            let t = annuo ? tolleranza : max(tolleranzaMinima, tolleranza * a.anni)
            if s > t {
                giudizio = .sopra
            } else if s < -t {
                giudizio = .sotto
            } else {
                giudizio = .inLinea
            }
        }

        let pme = flussi.map { MotoreRiferimenti.versamenti($0, serie: serie.id, tabella: tabella) }
        return ConfrontoRiferimento(serie: serie, sceltaRispettata: rispettata, dal: a.dal, al: a.al, anni: a.anni,
                                    annuo: annuo, effettivo: effettivo, fattore: f, riferimento: riferimento,
                                    reale: reale, giudizio: giudizio, punti: linea(a, serie: serie.id, tabella: tabella),
                                    versamenti: pme?.esito, versamentiMancantiDal: pme?.mancantiDal)
    }

    /// La linea «al ritmo del riferimento» (§4.1, regola 8): dal primo valore, con gli stessi versamenti a metà
    /// periodo, come la linea dell'atteso di `MotoreAndamento`. Senza un fattore per ogni periodo, nessuna linea.
    private static func linea(_ a: AndamentoPosizione, serie: String, tabella: TabellaRiferimenti) -> [AndamentoPosizione.Punto] {
        let senza = a.punti.map { AndamentoPosizione.Punto(data: $0.data, valore: $0.valore, versato: $0.versato, atteso: nil) }
        guard let primo = a.punti.first else { return senza }
        var attesi: [Double] = [primo.valore]
        var corrente = primo.valore
        for q in a.periodi {
            guard let F = fattore(serie, dal: q.dal, al: q.al, tabella: tabella).fattore else { return senza }
            corrente = corrente * F + q.versamenti * F.squareRoot()
            attesi.append(corrente)
        }
        return a.punti.enumerated().map { i, pt in
            AndamentoPosizione.Punto(data: pt.data, valore: pt.valore, versato: pt.versato,
                                     atteso: i < attesi.count ? attesi[i] : nil)
        }
    }

    /// I versamenti al ritmo del riferimento (metodo «public market equivalent», §4.1, regola 9): ogni flusso,
    /// alla sua data, cresce come il riferimento fino alla data del valore; gli incassi tolgono il loro valore cresciuto.
    static func versamenti(_ f: MotoreResoconto.FlussiDatati, serie: String, tabella: TabellaRiferimenti)
        -> (esito: VersamentiAlRiferimento?, mancantiDal: Int?) {
        // I flussi dopo la data del valore non contano (come in `Rendimenti.xirr`)
        let flussi = f.flussi.filter { $0.importo.isFinite && $0.data <= f.fine }
        guard let primo = flussi.map({ $0.data }).min() else { return (nil, nil) }
        var totale = 0.0
        var stimati = Set<Int>()
        var mancanti: [Int] = []
        var incompleto = false
        for fl in flussi {
            let fr = fattore(serie, dal: fl.data, al: f.fine, tabella: tabella)
            if let F = fr.fattore {
                totale += fl.importo * F
                stimati.formUnion(fr.stimati)
            } else {
                incompleto = true
                mancanti += fr.mancanti
            }
        }
        if incompleto {
            let primoAnno = calendario.component(.year, from: primo)
            return (nil, mancanti.min() ?? primoAnno)
        }
        guard totale > 0, totale.isFinite else { return (nil, nil) }
        let esito = VersamentiAlRiferimento(
            valoreRiferimento: totale, valoreEffettivo: f.valore,
            tassoRiferimento: Rendimenti.xirr(flussi, valoreFinale: totale, al: f.fine),
            tassoEffettivo: Rendimenti.xirr(flussi, valoreFinale: f.valore, al: f.fine),
            dal: primo, stimati: stimati.sorted())
        return (esito, nil)
    }
}
