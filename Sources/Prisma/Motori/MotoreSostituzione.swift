import Foundation

/// Un anno del confronto: valore e netto incassabile delle due strade.
struct AnnoSostituzione: Identifiable {
    let anno: Int
    let lordoResto: Double
    let nettoResto: Double
    let lordoCambio: Double
    let nettoCambio: Double
    var id: Int { anno }
    var differenza: Double { nettoCambio - nettoResto }
}

/// Le due strade a fine periodo con rendimenti più bassi, attesi o più alti.
struct ScenarioSostituzione: Identifiable {
    let nome: String
    /// Punti aggiunti al rendimento ipotizzato di entrambe le strade.
    let scarto: Double
    let nettoResto: Double
    let nettoCambio: Double
    var id: String { nome }
    var differenza: Double { nettoCambio - nettoResto }
}

/// Una delle due strade: la posizione, le ipotesi di calcolo e i costi.
struct LatoSostituzione {
    let posizione: Posizione
    let prodotto: Prodotto?
    let rendimento: Double
    let costoIngresso: Double
    /// Costo annuo complessivo usato nel calcolo: gestione + trattenuto + bollo.
    let costoAnnuo: Double
    let bollo: Bool
    let aliquota: Double
    /// Costi pagati nel periodo (ingresso e costi annui), in euro.
    let costiPeriodo: Double
    /// Costi del primo anno, in euro.
    let costiPrimoAnno: Double
}

/// Il confronto tra tenere una posizione e passare a un'alternativa (o tra due proposte).
struct EsitoSostituzione {
    let resto: LatoSostituzione
    let cambio: LatoSostituzione
    let anni: Int
    /// true se la prima voce è in essere: si confronta il restare con l'uscire oggi.
    let sostituzione: Bool
    /// Trasferimento tra due forme di previdenza complementare: niente imposte, anni conservati.
    let trasferimento: Bool
    /// L'uscita dalla posizione in essere (se è una sostituzione).
    let uscita: EsitoFiscale?
    /// Previdenza verso un prodotto non previdenziale: riscatto per altre cause (23%).
    let riscattoPrevidenza: UscitaPrevidenza?
    /// Valore di partenza: il valore di oggi della posizione (o il capitale della proposta).
    let valoreOggi: Double
    let penaleUscita: Double
    let bolloUscita: Double
    let impostaUscita: Double
    /// Quanto si reinveste nell'alternativa, prima del suo costo d'ingresso.
    let reinvestito: Double
    let ingressoCambio: Double
    var investitoCambio: Double { reinvestito - ingressoCambio }
    /// Costo dell'uscita oggi: penale, bollo, imposte anticipate e ingresso nel nuovo prodotto.
    var costoUscita: Double { penaleUscita + bolloUscita + impostaUscita + ingressoCambio }
    /// Versamenti futuri uguali per le due strade.
    let versamento: Double
    let frequenza: Frequenza
    let serie: [AnnoSostituzione]
    let scenari: [ScenarioSostituzione]
    /// Primo anno in cui la strada del cambio dà un netto almeno pari (nil se non accade nel periodo).
    let pareggio: Int?
    let note: [String]

    var finale: AnnoSostituzione? { serie.last }
    var versamentoAnnuo: Double { versamento * Double(frequenza.volteAllAnno) }
    var versatoFuturo: Double { versamentoAnnuo * Double(anni) }
}

/// Calcoli della sostituzione: le due strade ricevono gli stessi versamenti futuri e si confrontano
/// sul netto incassabile anno per anno (dopo penali, bollo e imposte).
enum MotoreSostituzione {
    static func calcola(attuale a: Posizione, alternativa b: Posizione, prodotti: [Prodotto] = [],
                        anni anniScelti: Int? = nil, orizzonteCliente: Int? = nil, data: Date = Date()) -> EsitoSostituzione {
        let prodottoA = a.prodottoId.flatMap { id in prodotti.first { $0.id == id } }
        let prodottoB = b.prodottoId.flatMap { id in prodotti.first { $0.id == id } }
        let anni = max(1, min(50, anniScelti ?? b.anniAllaScadenza ?? orizzonteCliente ?? IpotesiCalcolo.orizzontePredefinito))
        let sostituzione = a.stato == .inEssere
        var note: [String] = []

        // Versamenti futuri: quelli della proposta, uguali per le due strade
        let conVersamento = b.frequenza != .unica && b.premio > 0 ? b : a
        let versamento = conVersamento.frequenza != .unica ? conVersamento.premio : 0
        let frequenza = conVersamento.frequenza
        if versamento > 0 {
            note.append("Entrambe le strade ricevono gli stessi versamenti futuri: \(CifreDoc.euro(versamento)) \(frequenza.nome.lowercased()).")
        }

        // Uscita oggi dalla posizione in essere
        let trasferimento = sostituzione && a.regime == .previdenza && b.regime == .previdenza
        var uscita: EsitoFiscale?
        var riscatto: UscitaPrevidenza?
        let valoreOggi: Double
        var penale = 0.0, bollo = 0.0, imposta = 0.0
        if sostituzione {
            let f = MotoreFiscale.calcola(a, prodotto: prodottoA, data: data)
            uscita = f
            valoreOggi = f.valore
            if trasferimento {
                note.append("Trasferimento tra forme di previdenza complementare: nessuna imposta, gli anni di partecipazione restano.")
            } else if f.regime == .previdenza {
                riscatto = f.uscite.first { $0.causa == .riscattoAltreCause }
                imposta = riscatto?.imposta ?? 0
                note.append("Uscire da un fondo pensione verso un prodotto non previdenziale è un riscatto per altre cause: 23% sui contributi dedotti, possibile solo se si perdono i requisiti di partecipazione.")
            } else {
                penale = f.penale
                bollo = f.bolloMaturato
                imposta = f.imposta
            }
            if let s = a.scadenza, let fine = Calendar.current.date(byAdding: .year, value: anni, to: data), s < fine {
                note.append("\(a.nome) scade il \(CifreDoc.dataBreve(s)): restando si ipotizza che il capitale rimanga investito alle stesse condizioni fino alla fine del periodo.")
            }
        } else {
            valoreOggi = max(a.versamentoIniziale, b.versamentoIniziale)
            note.append("Confronto tra due proposte: entrambe partono dallo stesso capitale di \(CifreDoc.euro(valoreOggi)).")
        }
        let reinvestito = MotoreFiscale.centesimi(valoreOggi - penale - bollo - imposta)
        let ingressoB = MotoreFiscale.centesimi(reinvestito * (b.costoIngresso ?? 0) / 100)

        // Base imponibile di partenza: per chi resta il versato di sempre, per chi cambia il capitale reinvestito
        let baseResto = sostituzione ? (a.totaleVersato ?? a.versamentoIniziale) : valoreOggi
        let baseCambio = trasferimento ? baseResto : reinvestito
        let anniPrevidenza = trasferimento || a.regime == .previdenza ? MotoreFiscale.anniPartecipazione(a, data: data) : 0
        let anniContrattoA = sostituzione ? a.decorrenza.map { Calendar.current.dateComponents([.year], from: $0, to: data).year ?? 0 } ?? 0 : 0

        func lato(_ p: Posizione, prodotto: Prodotto?, capitale: Double, ingressoSulCapitale: Bool, scarto: Double)
            -> (punti: [PuntoProiezione], costi: Double, rendimento: Double, costoAnnuo: Double) {
            let bolloAnnuo = p.soggettaBollo && p.regime != .deposito ? RegoleFiscali.bollo : 0
            let costo = (p.costoComplessivo ?? 0) + bolloAnnuo
            let rendimento = (p.rendimentoAtteso ?? IpotesiCalcolo.rendimentoPredefinito) + scarto
            let par = ParametriProiezione(capitaleIniziale: capitale, versamento: versamento, frequenza: frequenza, anni: anni,
                                          rendimento: rendimento, costoIngresso: p.costoIngresso ?? 0, costoAnnuo: costo,
                                          aliquotaFiscale: 0, inflazione: 0, ingressoSulCapitale: ingressoSulCapitale)
            let e = MotoreProiezione.calcola(par)
            return (e.punti, e.costi, rendimento, costo)
        }

        /// Netto incassabile in un anno: valore − penale − imposta, secondo il regime della posizione.
        func netto(_ p: Posizione, prodotto: Prodotto?, lordo: Double, base: Double, annoContratto: Int, anniPartecipazione: Int) -> Double {
            let penale = (p.regime == .polizza ? prodotto?.condizioni?.penale(anno: annoContratto) ?? 0 : 0) / 100 * lordo
            switch p.regime {
            case .esente, .deposito:
                return lordo - penale
            case .previdenza:
                let dedotti = max(0, min(lordo, base) - (p.contributiNonDedotti ?? 0))
                return lordo - dedotti * RegoleFiscali.aliquotaPrevidenza(anni: anniPartecipazione) / 100
            case .polizza, .fondo:
                let imposta = max(0, lordo - penale - base) * MotoreFiscale.aliquotaGuadagno(p) / 100
                return lordo - penale - imposta
            }
        }

        func percorso(scarto: Double) -> [AnnoSostituzione] {
            let r = lato(a, prodotto: prodottoA, capitale: valoreOggi, ingressoSulCapitale: !sostituzione, scarto: scarto)
            let c = lato(b, prodotto: prodottoB, capitale: reinvestito, ingressoSulCapitale: true, scarto: scarto)
            return (0...anni).map { y in
                let pr = r.punti[min(y, r.punti.count - 1)], pc = c.punti[min(y, c.punti.count - 1)]
                let futuriResto = pr.versato - valoreOggi, futuriCambio = pc.versato - reinvestito
                // Il bollo già maturato nella polizza resta da pagare al riscatto anche restando
                let nettoResto = y == 0 && sostituzione ? reinvestito
                    : netto(a, prodotto: prodottoA, lordo: pr.valore, base: baseResto + futuriResto,
                            annoContratto: anniContrattoA + y + 1, anniPartecipazione: anniPrevidenza + y) - bollo
                let nettoCambio = netto(b, prodotto: prodottoB, lordo: pc.valore, base: baseCambio + futuriCambio,
                                        annoContratto: y + 1, anniPartecipazione: trasferimento ? anniPrevidenza + y : y)
                return AnnoSostituzione(anno: y, lordoResto: pr.valore, nettoResto: MotoreFiscale.centesimi(nettoResto),
                                        lordoCambio: pc.valore, nettoCambio: MotoreFiscale.centesimi(nettoCambio))
            }
        }

        let serie = percorso(scarto: 0)
        let ampiezza = IpotesiCalcolo.ampiezzaScenari
        let scenari = [("Prudente", -ampiezza), ("Atteso", 0.0), ("Favorevole", ampiezza)].map { voce -> ScenarioSostituzione in
            let (nome, scarto) = voce
            let ultimo = (scarto == 0 ? serie : percorso(scarto: scarto)).last
            return ScenarioSostituzione(nome: nome, scarto: scarto, nettoResto: ultimo?.nettoResto ?? 0, nettoCambio: ultimo?.nettoCambio ?? 0)
        }
        let pareggio = serie.first { $0.anno >= 1 && $0.differenza >= 0 }?.anno

        let r = lato(a, prodotto: prodottoA, capitale: valoreOggi, ingressoSulCapitale: !sostituzione, scarto: 0)
        let c = lato(b, prodotto: prodottoB, capitale: reinvestito, ingressoSulCapitale: true, scarto: 0)
        let primoResto = r.punti.count > 1 ? valoreOggi * r.costoAnnuo / 100 : 0
        let primoCambio = c.punti.count > 1 ? investitoCambio(reinvestito, ingressoB) * c.costoAnnuo / 100 + ingressoB : ingressoB
        if b.rendimentoAtteso == nil || a.rendimentoAtteso == nil {
            note.append("Dove manca il rendimento atteso si usa il \(CifreDoc.condizione(IpotesiCalcolo.rendimentoPredefinito)) annuo.")
        }
        note.append("Rendimenti ipotetici, non garantiti: scenari prudente e favorevole con \(CifreDoc.condizione(ampiezza)) punti in meno e in più per entrambe le strade.")

        return EsitoSostituzione(
            resto: LatoSostituzione(posizione: a, prodotto: prodottoA, rendimento: r.rendimento, costoIngresso: a.costoIngresso ?? 0,
                                    costoAnnuo: r.costoAnnuo, bollo: a.soggettaBollo, aliquota: aliquotaFinale(a),
                                    costiPeriodo: r.costi, costiPrimoAnno: primoResto),
            cambio: LatoSostituzione(posizione: b, prodotto: prodottoB, rendimento: c.rendimento, costoIngresso: b.costoIngresso ?? 0,
                                     costoAnnuo: c.costoAnnuo, bollo: b.soggettaBollo, aliquota: aliquotaFinale(b),
                                     costiPeriodo: c.costi, costiPrimoAnno: primoCambio),
            anni: anni, sostituzione: sostituzione, trasferimento: trasferimento, uscita: uscita, riscattoPrevidenza: riscatto,
            valoreOggi: valoreOggi, penaleUscita: penale, bolloUscita: bollo, impostaUscita: imposta,
            reinvestito: reinvestito, ingressoCambio: ingressoB, versamento: versamento, frequenza: frequenza,
            serie: serie, scenari: scenari, pareggio: pareggio, note: note)
    }

    private static func investitoCambio(_ reinvestito: Double, _ ingresso: Double) -> Double { reinvestito - ingresso }

    /// Aliquota sul guadagno alla fine (per la previdenza quella della prestazione di oggi).
    static func aliquotaFinale(_ p: Posizione) -> Double {
        switch p.regime {
        case .polizza, .fondo: return MotoreFiscale.aliquotaGuadagno(p)
        case .previdenza: return RegoleFiscali.aliquotaPrevidenza(anni: MotoreFiscale.anniPartecipazione(p))
        case .deposito: return RegoleFiscali.ordinaria
        case .esente: return 0
        }
    }

    /// La coppia predefinita di un cliente: una proposta contro la posizione in essere da sostituire
    /// (prima quelle che scadono entro un anno, poi quelle della stessa area).
    static func coppia(_ posizioni: [Posizione]) -> (String, String)? {
        let proposte = posizioni.filter { $0.stato == .proposta && $0.area.proiettabile && $0.esito != .rifiutata }
        let inEssere = posizioni.filter { $0.stato == .inEssere && $0.area.proiettabile }
        guard let proposta = proposte.first else {
            return inEssere.count > 1 ? (inEssere[0].id, inEssere[1].id) : nil
        }
        let inScadenza = inEssere.filter { $0.scadeEntro(365) }.sorted { ($0.scadenza ?? .distantFuture) < ($1.scadenza ?? .distantFuture) }
        let attuale = inScadenza.first ?? inEssere.first(where: { $0.area == proposta.area }) ?? inEssere.first
        return attuale.map { ($0.id, proposta.id) } ?? (proposte.count > 1 ? (proposte[0].id, proposte[1].id) : nil)
    }
}
