import Foundation

/// Il peso dei costi di una posizione: quanto costa quest'anno e quanto toglie al netto finale
/// in 10 e 20 anni (o fino alla scadenza), più l'eventuale alternativa più economica a parità di rischio.
struct CostiPosizione: Identifiable {
    enum Livello {
        case basso, medio, alto

        var nome: String {
            switch self {
            case .basso: return "Contenuto"
            case .medio: return "Nella media"
            case .alto: return "Alto"
            }
        }
    }

    /// L'alternativa del catalogo che, con lo stesso rischio e lo stesso rendimento lordo, lascia di più
    /// dopo penali, imposte d'uscita e costo d'ingresso.
    struct Alternativa {
        let prodotto: Prodotto
        let anni: Int
        /// Netto in più a fine periodo, uscita compresa.
        let guadagno: Double
        /// Penale, bollo, imposte anticipate e ingresso pagati oggi per cambiare.
        let costoUscita: Double
        let costoAnnuo: Double
    }

    let posizione: Posizione
    /// Costo d'ingresso sui versamenti futuri e costo annuo complessivo (gestione + trattenuto), in %.
    let ingresso: Double
    let annuo: Double
    /// I costi dei prossimi 12 mesi, in euro: annuo sul valore e ingresso sui versamenti dell'anno.
    let euroAnno: Double
    let anni10: Int
    let perso10: Double
    let anni20: Int
    let perso20: Double
    let alternativa: Alternativa?

    var id: String { posizione.id }

    var livello: Livello {
        if annuo < MotoreCosti.sogliaBasso { return .basso }
        return annuo <= MotoreCosti.sogliaAlto ? .medio : .alto
    }
}

struct AnalisiCosti {
    /// Dalle posizioni che costano di più in 20 anni a quelle che costano meno.
    let voci: [CostiPosizione]
    /// Posizioni finanziarie in essere senza costi indicati: da completare con il KID.
    let senzaDati: [Posizione]

    var valore: Double { voci.reduce(0) { $0 + $1.posizione.valore } }
    var euroAnno: Double { voci.reduce(0) { $0 + $1.euroAnno } }
    var perso10: Double { voci.reduce(0) { $0 + $1.perso10 } }
    var perso20: Double { voci.reduce(0) { $0 + $1.perso20 } }
    /// Costo annuo medio, pesato sul valore.
    var costoMedio: Double? {
        valore > 0 ? voci.reduce(0) { $0 + $1.annuo * $1.posizione.valore } / valore : nil
    }
    var conAlternativa: [CostiPosizione] {
        voci.filter { $0.alternativa != nil }.sorted { ($0.alternativa?.guadagno ?? 0) > ($1.alternativa?.guadagno ?? 0) }
    }
    var risparmioPossibile: Double { conAlternativa.reduce(0) { $0 + ($1.alternativa?.guadagno ?? 0) } }

    func perCanale(_ c: Canale) -> (euroAnno: Double, perso20: Double, numero: Int) {
        let mie = voci.filter { $0.posizione.canale == c }
        return (mie.reduce(0) { $0 + $1.euroAnno }, mie.reduce(0) { $0 + $1.perso20 }, mie.count)
    }

    var vuota: Bool { voci.isEmpty && senzaDati.isEmpty }
}

/// L'incidenza annua dei costi come nel KID (RIY, «reduction in yield»): di quanto i costi del prodotto
/// abbassano il rendimento medio annuo, per uscite dopo 1 anno, a metà e alla fine del periodo raccomandato.
/// Il RIY calcolato da Prisma resta separato da quello dichiarato nel KID, per confrontarli.
struct IncidenzaCostiKID {
    struct Periodo: Hashable {
        /// Anni dell'uscita.
        let anni: Int
        /// Rendimento medio annuo senza costi e con i costi, prima delle imposte (%).
        let senzaCosti: Double
        let conCosti: Double
        /// Euro tolti dai costi all'uscita: valore senza costi − valore con i costi (penale compresa).
        let costi: Double
        /// Incidenza annua dei costi (punti percentuali l'anno).
        var riy: Double { senzaCosti - conCosti }
    }

    let posizione: Posizione
    let periodoRaccomandato: Int
    /// Le uscite del KID (1 anno, metà se il periodo è di almeno 10 anni, fine).
    let periodi: [Periodo]
    /// Anno per anno, da 1 al periodo raccomandato.
    let annoPerAnno: [Periodo]
    /// RIY dichiarato nel KID (della posizione o della scheda prodotto).
    let dichiarato: Double?

    /// RIY calcolato al periodo raccomandato.
    var calcolato: Double? { periodi.last?.riy }
    /// Calcolato meno dichiarato (punti): positivo se i costi pesano più di quanto dice il KID.
    var scarto: Double? {
        guard let c = calcolato, let d = dichiarato else { return nil }
        return c - d
    }

    /// Nota di metodo per prospetti e schede.
    static let metodo = "Incidenza annua dei costi come nel KID (RIY): rendimento medio annuo senza costi meno quello con i costi del prodotto (ingresso, gestione, trattenuto della gestione separata, penale e costo d'uscita), sui versamenti alle loro date, prima delle imposte e senza il bollo. Uscite dopo 1 anno, a metà del periodo raccomandato (da 10 anni in su) e alla fine. Il RIY del KID resta quello dichiarato: Prisma lo confronta con il suo calcolo. Nelle multiramo i costi valgono per parte: trattenuto sulla gestione separata, commissioni e costi dei fondi sulla parte in fondi."
}

enum MotoreCosti {
    /// Sotto l'1% l'anno è contenuto, oltre il 2% è alto.
    static let sogliaBasso = 1.0
    static let sogliaAlto = 2.0
    static let orizzonti = (10, 20)
    /// Un'alternativa vale la pena se costa almeno tanti punti in meno l'anno e lascia almeno tanto di più.
    static let scartoMinimo = 0.3
    static let guadagnoMinimo = 500.0

    static func calcola(_ posizioni: [Posizione], prodotti: [Prodotto] = [], cliente: String = "") -> AnalisiCosti {
        let finanziarie = posizioni.filter { $0.stato == .inEssere && $0.area.proiettabile && $0.valore > 0 }
        let conDati = finanziarie.filter { $0.costoComplessivo != nil || $0.costoIngresso != nil }
        let voci = conDati.map { voce($0, prodotti: prodotti, cliente: cliente) }.sorted { $0.perso20 > $1.perso20 }
        return AnalisiCosti(voci: voci, senzaDati: finanziarie.filter { p in !conDati.contains { $0.id == p.id } })
    }

    /// Gli anni della proiezione: l'orizzonte, ma non oltre la scadenza.
    static func anni(_ p: Posizione, _ orizzonte: Int) -> Int {
        min(orizzonte, p.anniAllaScadenza ?? orizzonte)
    }

    /// Quanto netto in meno lasciano i costi del prodotto (non le imposte né il bollo) in tanti anni.
    static func perso(_ p: Posizione, anni: Int) -> Double {
        var con = ParametriProiezione(posizione: p)
        con.anni = anni
        var senza = con
        if p.multiramoDivisa {
            // Due parti: via il trattenuto della gestione separata e i costi dei fondi, resta il bollo
            senza = MotoreMultiramo.senzaCostiProdotto(con, p)
        } else {
            senza.costoIngresso = 0
            senza.costoAnnuo = max(0, con.costoAnnuo - (p.costoComplessivo ?? 0))
        }
        return max(0, MotoreProiezione.calcola(senza).netto - MotoreProiezione.calcola(con).netto)
    }

    static func voce(_ p: Posizione, prodotti: [Prodotto], cliente: String) -> CostiPosizione {
        let ingresso = p.costoIngresso ?? 0
        let annuo = p.costoComplessivo ?? 0
        let a10 = anni(p, orizzonti.0), a20 = anni(p, orizzonti.1)
        return CostiPosizione(posizione: p, ingresso: ingresso, annuo: annuo,
                              euroAnno: p.valore * annuo / 100 + p.premioAnnuo * ingresso / 100,
                              anni10: a10, perso10: perso(p, anni: a10), anni20: a20, perso20: perso(p, anni: a20),
                              alternativa: alternativa(p, prodotti: prodotti, cliente: cliente))
    }

    /// Il prodotto del catalogo con lo stesso rischio (stessa area e stesso SRI) e costi annui più bassi
    /// che lascia di più in 10 anni, uscita compresa. Lo stesso rendimento lordo per tutti: pesano solo i costi.
    /// Una multiramo si confronta solo con un'altra multiramo con la stessa quota in gestione separata (la
    /// garanzia della gestione separata non si baratta in silenzio); le schede senza quota si scartano.
    static func alternativa(_ p: Posizione, prodotti: [Prodotto], cliente: String) -> CostiPosizione.Alternativa? {
        let annuo = p.costoComplessivo ?? 0
        let sri = p.sri ?? MotoreResistenza.sriProbabile(p.area)
        let anniConfronto = anni(p, orizzonti.0)
        // Solo schede complete: senza costi o rischio dichiarati il confronto sarebbe inventato
        let candidati = prodotti.compactMap { x -> (Prodotto, Posizione, Double)? in
            guard x.id != p.prodottoId, x.nome != p.nome, x.area == p.area, x.sri == sri else { return nil }
            var b = x.proposta(per: cliente)
            // Una gestione separata si confronta solo con un'altra: il capitale garantito non si baratta
            guard p.gestioneSeparata == b.gestioneSeparata else { return nil }
            if p.multiramo {
                guard b.multiramo, let quota = quotaConfrontabile(p, scheda: x, proposta: b) else { return nil }
                b.quotaGestioneSeparata = quota
            }
            // Lo stesso rendimento lordo: con le due parti i numeri di `p` (anche se li ricava dal complessivo)
            b.rendimentoAtteso = p.rendimentoAtteso
            if p.multiramoDivisa {
                b.rendimentoGestione = p.lordoGestione()
                b.rendimentoFondi = p.lordoFondi()
            } else if b.multiramo {
                b.rendimentoGestione = nil
                b.rendimentoFondi = nil
            }
            // Il costo dopo la costruzione: con le due parti quello composto sulla stessa quota
            guard let costo = b.costoComplessivo ?? x.costoAnnuo, costo <= annuo - scartoMinimo else { return nil }
            return (x, b, costo)
        }
        return candidati.compactMap { x, b, costo -> CostiPosizione.Alternativa? in
            let e = MotoreSostituzione.calcola(attuale: p, alternativa: b, prodotti: prodotti, anni: anniConfronto)
            guard let fine = e.finale, fine.differenza >= guadagnoMinimo else { return nil }
            return .init(prodotto: x, anni: anniConfronto, guadagno: fine.differenza, costoUscita: e.costoUscita, costoAnnuo: costo)
        }.max { $0.guadagno < $1.guadagno }
    }

    /// La quota in gestione separata (0–100) da dare all'alternativa multiramo: quella di `p` se la scheda
    /// la ammette (quota minima e massima), oppure quella della scheda se non dista più di 10 punti. nil se
    /// la scheda non dice nulla della quota: la stima del 50% deciderebbe a caso.
    private static func quotaConfrontabile(_ p: Posizione, scheda x: Prodotto, proposta b: Posizione) -> Double? {
        let quota = p.parteGestione * 100
        if let minima = x.quotaGestioneMinima, let massima = x.quotaGestioneMassima, minima <= massima,
           (minima...massima).contains(quota) {
            return quota
        }
        guard let indicata = b.quotaGestioneSeparata, abs(b.parteGestione - p.parteGestione) <= 0.10 + 1e-9 else { return nil }
        return indicata
    }

    /// Il valore complessivo anno per anno, con e senza i costi dei prodotti (prima delle imposte finali),
    /// per il grafico dei documenti. Una posizione che scade resta ferma al valore della scadenza.
    static func serie(_ a: AnalisiCosti, durata: Int = orizzonti.1) -> (con: [Double], senza: [Double]) {
        var con = [Double](repeating: 0, count: durata + 1)
        var senza = con
        for v in a.voci {
            var par = ParametriProiezione(posizione: v.posizione)
            par.anni = anni(v.posizione, durata)
            var libero = par
            if v.posizione.multiramoDivisa {
                libero = MotoreMultiramo.senzaCostiProdotto(par, v.posizione)
            } else {
                libero.costoIngresso = 0
                libero.costoAnnuo = max(0, par.costoAnnuo - v.annuo)
            }
            let pc = MotoreProiezione.calcola(par).punti.map(\.valore)
            let ps = MotoreProiezione.calcola(libero).punti.map(\.valore)
            for i in 0...durata {
                con[i] += pc[min(i, pc.count - 1)]
                senza[i] += ps[min(i, ps.count - 1)]
            }
        }
        return (con, senza)
    }

    // MARK: - Incidenza annua dei costi come nel KID (RIY)

    /// Le uscite del KID: dopo 1 anno, a metà del periodo raccomandato (arrotondata per eccesso, solo da 10 anni
    /// in su, come nel Regolamento delegato UE 2021/2268) e alla fine del periodo raccomandato.
    static func periodiKID(_ raccomandato: Int) -> [Int] {
        let n = max(1, raccomandato)
        var periodi = [1]
        if n >= 10 { periodi.append(Int((Double(n) / 2).rounded(.up))) }
        if n > 1 { periodi.append(n) }
        return periodi
    }

    /// L'incidenza annua dei costi di una posizione come nel KID: la proiezione con i costi del prodotto (ingresso,
    /// gestione, trattenuto o retrocessione della gestione separata, penale dell'anno e costo d'uscita) e senza,
    /// prima delle imposte e senza il bollo (sono imposte, non costi); RIY = rendimento medio annuo senza costi −
    /// rendimento con i costi, sui flussi alle loro date (versamento iniziale e premi periodici). Una posizione in
    /// essere parte dal valore di oggi, con l'ingresso solo sui versamenti futuri; una proposta dal versamento iniziale.
    /// Periodo raccomandato: della posizione, della scheda, la scadenza o 10 anni. nil senza versamenti.
    static func incidenzaKID(_ p: Posizione, prodotto: Prodotto? = nil, anni: Int? = nil, data: Date = Date()) -> IncidenzaCostiKID? {
        guard p.area.proiettabile, p.stato != .chiusa else { return nil }
        let indicato: Int? = anni ?? p.periodoRaccomandato ?? prodotto?.periodoConsigliato
        let orizzonte: Int = indicato ?? p.anniAllaScadenza ?? IpotesiCalcolo.orizzontePredefinito
        let raccomandato = min(max(1, orizzonte), 40)
        var con = ParametriProiezione(posizione: p)
        con.anni = raccomandato
        con.mesiEsatti = nil
        con.aliquotaFiscale = 0
        con.gestione?.aliquota = 0
        con.tassazioneAnnua = 0
        con.aliquotaSulVersato = 0
        con.nonDedotti = 0
        con.inflazione = 0
        // Solo i costi del prodotto: il bollo che `ParametriProiezione` aggiunge al costo annuo è un'imposta.
        // Multiramo a due parti: i costi dei fondi sulla loro parte, il trattenuto resta nella gestione separata
        con.costoAnnuo = p.multiramoDivisa ? p.costoParteFondi : max(0, p.costoAnnuo ?? 0) + MotoreGestioneSeparata.trattenuto(p)
        guard con.capitaleIniziale > 0 || (con.versamento > 0 && con.frequenza.volteAllAnno > 0) else { return nil }
        var senza = con
        senza.costoIngresso = 0
        senza.costoAnnuo = 0
        // Senza costi la gestione separata rende il lordo (con il pavimento, se consolidata)
        senza.gestione?.trattenuto = nil
        senza.gestione?.retrocessione = nil
        let puntiCon = MotoreProiezione.calcola(con).punti
        let puntiSenza = MotoreProiezione.calcola(senza).punti

        // Anno di contratto del riscatto dopo k anni: per le penali (in essere: dagli anni già trascorsi)
        let cal = Calendar.current
        let trascorsi: Int? = p.stato == .inEssere
            ? p.decorrenza.map { cal.dateComponents([.year], from: $0, to: data).year ?? 0 }
            : 0
        let uscita = max(0, p.costoUscita ?? 0)
        let ogniMesi = con.frequenza.volteAllAnno > 0 ? 12 / con.frequenza.volteAllAnno : 0

        var annoPerAnno: [IncidenzaCostiKID.Periodo] = []
        for k in 1...raccomandato {
            guard k < puntiCon.count, k < puntiSenza.count else { break }
            // Flussi del cliente: il capitale all'inizio e i premi ai loro mesi (anni prima dell'uscita)
            let mesiTotali = 12 * k
            var flussi: [(anni: Double, importo: Double)] = [(anni: Double(k), importo: con.capitaleIniziale)]
            if ogniMesi > 0, con.versamento > 0 {
                for mese in stride(from: 0, to: mesiTotali, by: ogniMesi) {
                    flussi.append((anni: Double(mesiTotali - mese) / 12, importo: con.versamento))
                }
            }
            let penale = (trascorsi.map { p.penale(anno: $0 + k + 1, prodotto: prodotto) } ?? 0) + uscita
            let finaleCon = puntiCon[k].valore * (1 - min(penale, 100) / 100)
            let finaleSenza = puntiSenza[k].valore
            guard let rSenza = Rendimenti.tasso(flussi, valoreFinale: finaleSenza),
                  let rCon = Rendimenti.tasso(flussi, valoreFinale: finaleCon) else { continue }
            annoPerAnno.append(.init(anni: k, senzaCosti: rSenza, conCosti: rCon, costi: max(0, finaleSenza - finaleCon)))
        }
        guard !annoPerAnno.isEmpty else { return nil }
        let periodi = periodiKID(raccomandato).compactMap { n in annoPerAnno.first { $0.anni == n } }
        return IncidenzaCostiKID(posizione: p, periodoRaccomandato: raccomandato, periodi: periodi, annoPerAnno: annoPerAnno,
                                 dichiarato: p.incidenzaCostiKID ?? prodotto?.incidenzaCostiKID)
    }

    /// Le righe per Eve e per le schede.
    static func sintesi(_ a: AnalisiCosti) -> [String] {
        var righe: [String] = []
        if let m = a.costoMedio {
            righe.append("Costi di quest'anno: \(Formati.euro(a.euroAnno)), in media il \(CifreDoc.percento(m, decimali: 2)) l'anno sul valore di \(Formati.euro(a.valore)).")
            righe.append("Quanto tolgono al netto finale: \(Formati.euro(a.perso10)) in 10 anni, \(Formati.euro(a.perso20)) in 20 (o fino alla scadenza), rendimenti persi compresi.")
        }
        if let v = a.voci.first, a.voci.count > 1 {
            righe.append("La più costosa: \(v.posizione.nome) (\(v.posizione.canale.nomeBreve)), \(CifreDoc.percento(v.annuo, decimali: 2)) l'anno, \(Formati.euro(v.perso20)) in \(v.anni20) anni.")
        }
        for v in a.conAlternativa.prefix(2) {
            guard let x = v.alternativa else { continue }
            righe.append("Alternativa a parità di rischio per \(v.posizione.nome): \(x.prodotto.nome) (\(x.prodotto.canale.nomeBreve), \(CifreDoc.percento(x.costoAnnuo, decimali: 2)) l'anno): circa \(Formati.euro(x.guadagno)) netti in più in \(x.anni) anni, uscita compresa.")
        }
        if !a.senzaDati.isEmpty {
            righe.append("Senza costi indicati: \(a.senzaDati.map(\.nome).joined(separator: ", ")). Si completano dal KID.")
        }
        return righe
    }
}
