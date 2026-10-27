import Foundation

/// Una posizione che lavora per l'obiettivo, portata alla scadenza.
struct ContributoObiettivo: Identifiable {
    let posizione: Posizione
    var id: String { posizione.id }
    let valoreOggi: Double
    let versamentoMensile: Double
    let rendimento: Double
    let costoAnnuo: Double
    /// Valore alla scadenza al netto delle imposte sul guadagno.
    let nettoScadenza: Double
    let punti: [PuntoProiezione]
}

/// Una strada per arrivare all'obiettivo.
struct StradaObiettivo: Identifiable {
    enum Tipo: String { case mensile, unaTantum, rinvio, riduzione }
    let tipo: Tipo
    var id: String { tipo.rawValue }
    let titolo: String
    let valore: String
    let spiegazione: String
}

/// Il piano per un obiettivo: dove si è, dove si arriva, cosa serve.
struct EsitoObiettivo {
    let obiettivo: Obiettivo
    let mesi: Int
    var anni: Double { Double(mesi) / 12 }
    /// Importo in euro di oggi e quanto varrà alla scadenza con l'inflazione.
    var importoOggi: Double { obiettivo.importo }
    let importoScadenza: Double
    /// Già da parte oggi (accantonato e posizioni collegate).
    let disponibileOggi: Double
    let contributi: [ContributoObiettivo]
    /// L'accantonato non investito, fatto crescere al rendimento dell'obiettivo.
    let accantonatoScadenza: Double
    var proiezione: Double { contributi.reduce(0) { $0 + $1.nettoScadenza } + accantonatoScadenza }
    var copertura: Double { importoScadenza > 0 ? min(1, proiezione / importoScadenza) : 1 }
    var mancante: Double { max(0, importoScadenza - proiezione) }
    var versamentiAttivi: Double { contributi.reduce(0) { $0 + $1.versamentoMensile } }
    /// Versamento mensile in più che colma il mancante (nil se non c'è tempo).
    let versamentoNecessario: Double?
    /// Versamento unico oggi che colma il mancante.
    let unaTantum: Double?
    /// Anni di rinvio con cui basterebbe ciò che c'è (nil se oltre 30).
    let rinvio: Int?
    let strade: [StradaObiettivo]
    /// Proiezione con rendimenti più bassi, attesi o più alti.
    let scenari: [(nome: String, scarto: Double, proiezione: Double)]
    /// Anno per anno: con ciò che c'è, con il versamento suggerito, obiettivo rivalutato.
    let serieAttuale: [Double]
    let serieConVersamento: [Double]
    let serieObiettivo: [Double]
    let note: [String]
}

/// Calcoli del piano obiettivo. L'importo è in euro di oggi: alla scadenza si confronta con il suo
/// valore rivalutato all'inflazione; le posizioni collegate crescono con le loro ipotesi, al netto
/// di costi e imposte sul guadagno.
enum MotoreObiettivo {
    static func calcola(_ o: Obiettivo, posizioni: [Posizione], data: Date = Date()) -> EsitoObiettivo {
        let mesi = max(0, Calendar.current.dateComponents([.month], from: data, to: o.scadenza).month ?? 0)
        let anni = Double(mesi) / 12
        let anniInteri = max(1, Int(anni.rounded(.up)))
        let inflazione = IpotesiCalcolo.inflazione
        let importoScadenza = o.importo * pow(1 + inflazione / 100, anni)
        var note: [String] = []
        let collegate = posizioni.filter { o.posizioniCollegate.contains($0.id) && $0.stato == .inEssere }

        func contributo(_ p: Posizione, scarto: Double, mesiProiezione: Int) -> ContributoObiettivo {
            let rendimento = (p.rendimentoAtteso ?? o.rendimento) + scarto
            let costo = (p.costoComplessivo ?? 0) + (p.regime != .deposito ? RegoleFiscali.bollo * p.quotaBollo : 0)
            var par = ParametriProiezione(capitaleIniziale: p.valore, versamento: p.premio, frequenza: p.frequenza, anni: 1,
                                          rendimento: rendimento, costoIngresso: p.costoIngresso ?? 0, costoAnnuo: costo,
                                          aliquotaFiscale: 0, inflazione: 0, ingressoSulCapitale: false).perMesi(mesiProiezione)
            par.capitaleGarantito = p.gestioneSeparata
            // Fondi pensione: imposta del 20% sui rendimenti dentro il fondo (12,5% sulla parte in titoli di Stato,
            // se indicata), come nel piano previdenziale
            if p.regime == .previdenza { par.tassazioneAnnua = RegoleFiscali.aliquotaRendimentiPrevidenza(quotaTitoliStato: p.quotaTitoliStato) }
            let anniProiezione = mesiProiezione / 12
            let e = MotoreProiezione.calcola(par)
            // Imposta sul guadagno alla scadenza, secondo il regime (i conti sono già netti)
            let base = (p.totaleVersato ?? p.versamentoIniziale) + (e.versato - p.valore)
            let imposta: Double
            switch p.regime {
            case .polizza, .fondo: imposta = max(0, e.lordo - max(base, 0)) * MotoreFiscale.aliquotaGuadagno(p) / 100
            case .deposito: imposta = max(0, e.lordo - e.versato) * RegoleFiscali.ordinaria / 100
            case .previdenza: imposta = max(0, min(e.lordo, base) - (p.contributiNonDedotti ?? 0)) * RegoleFiscali.aliquotaPrevidenza(anni: MotoreFiscale.anniPartecipazione(p, data: data) + anniProiezione) / 100
            case .esente: imposta = 0
            }
            return ContributoObiettivo(posizione: p, valoreOggi: p.valore, versamentoMensile: p.premioAnnuo / 12, rendimento: rendimento,
                                       costoAnnuo: costo, nettoScadenza: e.lordo - imposta, punti: e.punti)
        }

        func accantonato(_ anniProiezione: Double, scarto: Double) -> Double {
            o.accantonato * pow(1 + (o.rendimento + scarto) / 100, anniProiezione)
        }

        /// Ciò che c'è, portato a una certa durata in mesi.
        func proiezione(mesiProiezione: Int, scarto: Double) -> Double {
            collegate.reduce(0) { $0 + contributo($1, scarto: scarto, mesiProiezione: mesiProiezione).nettoScadenza }
                + accantonato(Double(mesiProiezione) / 12, scarto: scarto)
        }

        // Durata esatta in mesi: 13 mesi sono 13 versamenti, non 24
        let contributi = collegate.map { contributo($0, scarto: 0, mesiProiezione: mesi) }
        let accantonatoScadenza = accantonato(anni, scarto: 0)
        let proiezioneOggi = contributi.reduce(0) { $0 + $1.nettoScadenza } + accantonatoScadenza
        let mancante = max(0, importoScadenza - proiezioneOggi)
        let aliquota = IpotesiCalcolo.aliquotaPredefinita

        // Strada 1: un versamento mensile in più, investito al rendimento dell'obiettivo
        var versamento: Double?
        if mancante > 0.5 && mesi > 0 {
            let par = ParametriProiezione(capitaleIniziale: 0, versamento: 0, frequenza: .mensile, anni: anniInteri,
                                          rendimento: o.rendimento, aliquotaFiscale: aliquota, inflazione: 0).perMesi(mesi)
            versamento = MotoreAnalisi.versamentoNecessario(par, obiettivo: mancante)
        }
        // Strada 2: un versamento unico oggi (bisezione)
        var unaTantum: Double?
        if mancante > 0.5 {
            func netto(_ c: Double) -> Double {
                MotoreProiezione.calcola(ParametriProiezione(capitaleIniziale: c, versamento: 0, frequenza: .unica, anni: anniInteri,
                                                             rendimento: o.rendimento, aliquotaFiscale: aliquota, inflazione: 0).perMesi(mesi)).netto
            }
            var basso = 0.0, alto = mancante * 2
            for _ in 0..<60 {
                let medio = (basso + alto) / 2
                if netto(medio) >= mancante { alto = medio } else { basso = medio }
            }
            unaTantum = (alto / 10).rounded(.up) * 10
        }
        // Strada 3: rinviare la scadenza finché basta ciò che c'è
        var rinvio: Int?
        if mancante > 0.5 {
            for extra in 1...30 {
                if proiezione(mesiProiezione: mesi + extra * 12, scarto: 0) >= o.importo * pow(1 + inflazione / 100, anni + Double(extra)) {
                    rinvio = extra
                    break
                }
            }
        }

        var strade: [StradaObiettivo] = []
        if mancante > 0.5 {
            if let v = versamento {
                strade.append(StradaObiettivo(tipo: .mensile, titolo: "Versare ogni mese", valore: "\(CifreDoc.euro(v)) al mese",
                                              spiegazione: "da oggi alla scadenza, al \(CifreDoc.condizione(o.rendimento)) annuo, al netto delle imposte sul guadagno"))
            }
            if let u = unaTantum {
                strade.append(StradaObiettivo(tipo: .unaTantum, titolo: "Aggiungere oggi", valore: CifreDoc.euro(u),
                                              spiegazione: "un versamento unico investito al \(CifreDoc.condizione(o.rendimento)) annuo"))
            }
            strade.append(StradaObiettivo(tipo: .rinvio, titolo: "Spostare la data", valore: rinvio.map { "+ \($0) \($0 == 1 ? "anno" : "anni")" } ?? "oltre 30 anni",
                                          spiegazione: "senza versare di più, lasciando crescere ciò che c'è"))
            let raggiungibile = proiezioneOggi / pow(1 + inflazione / 100, anni)
            strade.append(StradaObiettivo(tipo: .riduzione, titolo: "Ridurre l'obiettivo", valore: CifreDoc.euro(raggiungibile),
                                          spiegazione: "in euro di oggi: quanto si raggiunge alla data con ciò che c'è"))
        }

        let ampiezza = IpotesiCalcolo.ampiezzaScenari
        let scenari = [("Prudente", -ampiezza), ("Atteso", 0.0), ("Favorevole", ampiezza)].map { voce -> (nome: String, scarto: Double, proiezione: Double) in
            let (nome, scarto) = voce
            return (nome, scarto, scarto == 0 ? proiezioneOggi : proiezione(mesiProiezione: mesi, scarto: scarto))
        }

        // Anno per anno, valori lordi (prima delle imposte finali)
        let suggerito = versamento ?? 0
        var attuale: [Double] = [], conVersamento: [Double] = [], obiettivo: [Double] = []
        let extra = MotoreProiezione.calcola(ParametriProiezione(capitaleIniziale: 0, versamento: suggerito, frequenza: .mensile, anni: anniInteri,
                                                                 rendimento: o.rendimento, aliquotaFiscale: 0, inflazione: 0).perMesi(mesi)).punti
        for y in 0...anniInteri {
            let v = contributi.reduce(0) { $0 + $1.punti[min(y, $1.punti.count - 1)].valore } + accantonato(Double(y), scarto: 0)
            attuale.append(v)
            conVersamento.append(v + extra[min(y, extra.count - 1)].valore)
            obiettivo.append(o.importo * pow(1 + inflazione / 100, min(Double(y), anni)))
        }

        if collegate.isEmpty && o.accantonato == 0 { note.append("Nessuna posizione collegata e nessun accantonamento: si parte da zero.") }
        note.append("Importo dell'obiettivo in euro di oggi, rivalutato all'inflazione del \(CifreDoc.condizione(inflazione)) annuo fino alla scadenza.")
        note.append("Posizioni collegate con il loro rendimento atteso (o quello dell'obiettivo, \(CifreDoc.condizione(o.rendimento))), i loro costi e l'imposta sul guadagno alla scadenza; nuovi versamenti al \(CifreDoc.condizione(o.rendimento)) con imposta del \(CifreDoc.condizione(aliquota)).")

        return EsitoObiettivo(obiettivo: o, mesi: mesi, importoScadenza: importoScadenza, disponibileOggi: o.accantonato + collegate.reduce(0) { $0 + $1.valore },
                              contributi: contributi, accantonatoScadenza: accantonatoScadenza,
                              versamentoNecessario: versamento, unaTantum: unaTantum, rinvio: rinvio, strade: strade, scenari: scenari,
                              serieAttuale: attuale, serieConVersamento: conVersamento, serieObiettivo: obiettivo, note: note + Semplificazioni.obiettivo + Semplificazioni.comuni)
    }
}
