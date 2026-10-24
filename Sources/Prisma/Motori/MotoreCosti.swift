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
        senza.costoIngresso = 0
        senza.costoAnnuo = max(0, con.costoAnnuo - (p.costoComplessivo ?? 0))
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
    static func alternativa(_ p: Posizione, prodotti: [Prodotto], cliente: String) -> CostiPosizione.Alternativa? {
        let annuo = p.costoComplessivo ?? 0
        let sri = p.sri ?? MotoreResistenza.sriProbabile(p.area)
        let anniConfronto = anni(p, orizzonti.0)
        let candidati = prodotti.filter { x in
            x.id != p.prodottoId && x.nome != p.nome && x.area == p.area && (x.sri ?? MotoreResistenza.sriProbabile(x.area)) == sri
                && (x.costoAnnuo ?? 0) <= annuo - scartoMinimo
                // Una gestione separata si confronta solo con un'altra: il capitale garantito non si baratta
                && p.gestioneSeparata == x.proposta(per: cliente).gestioneSeparata
        }
        return candidati.compactMap { x -> CostiPosizione.Alternativa? in
            var b = x.proposta(per: cliente)
            b.rendimentoAtteso = p.rendimentoAtteso
            let e = MotoreSostituzione.calcola(attuale: p, alternativa: b, prodotti: prodotti, anni: anniConfronto)
            guard let fine = e.finale, fine.differenza >= guadagnoMinimo else { return nil }
            return .init(prodotto: x, anni: anniConfronto, guadagno: fine.differenza, costoUscita: e.costoUscita, costoAnnuo: x.costoAnnuo ?? 0)
        }.max { $0.guadagno < $1.guadagno }
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
