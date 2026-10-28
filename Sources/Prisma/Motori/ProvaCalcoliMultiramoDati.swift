import Foundation

/// Prove delle multiramo a due parti sui dati di prova (dalla scheda alla proposta, `DatiDemo`): M10.
/// Chiamate da `ProvaCalcoliMultiramo.esegui`: gli errori si sommano. (Gruppo E.)
enum ProvaCalcoliMultiramoDati {
    static func esegui(_ verifica: VerificaCalcoli) {
        orizzonte(verifica)
        ramoI(verifica)
        marco(verifica)
    }

    // MARK: - M10. Dalla scheda alla proposta: Orizzonte Valore

    /// Orizzonte Valore ha le due parti solo nelle condizioni del contratto (30% Fondo Euro San Giorgio,
    /// 70% Allocazione Dinamica): la proposta le prende da lì e diventa una multiramo a due parti.
    private static func orizzonte(_ verifica: VerificaCalcoli) {
        let scheda = DatiDemo.orizzonteValore()
        let p = scheda.proposta(per: "prova")
        verifica.vero("M10 Orizzonte Valore: la proposta è una multiramo", p.multiramo)
        // È una proposta: la quota della scheda (ripartizione del premio) si copia
        verifica("M10 Orizzonte Valore: quota in gestione separata dalle condizioni (30 su 100)", p.quotaGestioneSeparata ?? -1, 30)
        verifica("M10 Orizzonte Valore: trattenuto della gestione separata", p.trattenuto ?? -1, 1.30)
        // Commissione del Fondo Interno 1,70 più costi dei fondi sottostanti 0,99
        verifica("M10 Orizzonte Valore: costi dei fondi 1,70 + 0,99", p.costoFondi ?? -1, 2.69)
        // Media dello storico della gestione (3,05; 2,84; 2,82; 3,02; 3,15; il 2024 manca) = 2,976 → al decimo
        verifica("M10 Orizzonte Valore: rendimento della gestione dallo storico, al decimo", p.rendimentoGestione ?? -1, 3.0, tolleranza: 0.0001)
        verifica("M10 Orizzonte Valore: titoli di Stato della gestione", p.titoliStatoGestione ?? -1, 30.5, tolleranza: 0.0001)
        verifica("M10 Orizzonte Valore: volatilità dei fondi dal Regolamento", p.volatilitaFondi ?? -1, 12, tolleranza: 0.0001)
        verifica("M10 Orizzonte Valore: quota azionaria dei fondi", p.quotaAzionariaFondi ?? -1, 75, tolleranza: 0.0001)
        verifica.vero("M10 Orizzonte Valore: senza consolidamento («la rivalutazione può essere anche negativa»)", p.consolidamento == false)
        verifica.vero("M10 Orizzonte Valore: nessun SRI dei fondi nelle condizioni", p.sriFondi == nil)
        verifica.vero("M10 Orizzonte Valore: calcolata a due parti", p.multiramoDivisa)
        verifica.vero("M10 Orizzonte Valore: quota indicata, non stimata", !p.quotaGestioneStimata)
        // Il rendimento dei fondi non c'è: si ricava dal complessivo della scheda, (4,7 − 0,3 × 3,0) / 0,7
        verifica("M10 Orizzonte Valore: rendimento dei fondi ricavato dal complessivo", p.lordoFondi(), 3.8 / 0.7, tolleranza: 0.0001)
        verifica("M10 Orizzonte Valore: rendimento lordo composto = complessivo della scheda", p.rendimentoLordoComposto, 4.7, tolleranza: 0.0001)
        verifica.vero("M10 Orizzonte Valore: rendimento di una parte stimato", p.rendimentiPartiStimati)
        // Senza consolidamento l'accreditato non ha pavimento: 3,0 − 1,3
        verifica("M10 Orizzonte Valore: accreditato della gestione", p.accreditatoGestione(), 1.7, tolleranza: 0.0001)
        let par = ParametriProiezione(posizione: p)
        verifica.vero("M10 Orizzonte Valore: la proiezione tiene le due parti, senza consolidamento",
                      par.gestione?.consolidamento == false && abs((par.gestione?.quota ?? -1) - 0.3) < 0.0001)
        verifica("M10 Orizzonte Valore: proiezione dei fondi al rendimento ricavato", par.rendimento, 3.8 / 0.7, tolleranza: 0.0001)
        // La riga dei documenti con le quote e i lordi
        let riga = MotoreMultiramo.rigaComposizione(p)
        verifica.vero("M10 Orizzonte Valore: riga di composizione «\(riga)»",
                      riga.hasPrefix("di cui gestione separata 30% al 3,00%") && riga.contains("fondi 70% al 5,43%"))

        // La stessa scheda su una posizione in essere: la quota della scheda (premio) non è quella del valore
        // di oggi, che si legge sull'estratto conto. Resta la stima del 50%, marcata «stimata».
        var inEssere = Posizione(clienteId: "prova", canale: .alleanza, stato: .inEssere, area: .investimento, nome: "Orizzonte in essere")
        inEssere.tipologia = scheda.tipologia
        inEssere.controvalore = 50_000
        MotoreMultiramo.applica(scheda, a: &inEssere)
        verifica.vero("M10 Orizzonte in essere: la quota della scheda non si copia", inEssere.quotaGestioneSeparata == nil)
        verifica.vero("M10 Orizzonte in essere: quota in gestione separata stimata", inEssere.quotaGestioneStimata)
        verifica("M10 Orizzonte in essere: stimata al 50%", inEssere.parteGestione, 0.5, tolleranza: 0.0001)
        verifica("M10 Orizzonte in essere: le altre condizioni si copiano (trattenuto)", inEssere.trattenuto ?? -1, 1.30)
        verifica("M10 Orizzonte in essere: le altre condizioni si copiano (costi dei fondi)", inEssere.costoFondi ?? -1, 2.69)
        verifica.vero("M10 Orizzonte in essere: calcolata a due parti", inEssere.multiramoDivisa)
        let rigaStimata = MotoreMultiramo.rigaComposizione(inEssere)
        verifica.vero("M10 Orizzonte in essere: la riga dice «quota stimata»", rigaStimata.hasSuffix("(quota stimata)"))

        // Ciò che la posizione indica già non si sovrascrive
        var giaIndicata = inEssere
        giaIndicata.quotaGestioneSeparata = 45
        giaIndicata.trattenuto = 1.1
        MotoreMultiramo.applica(scheda, a: &giaIndicata)
        verifica("M10 Orizzonte: la quota dell'estratto conto resta", giaIndicata.quotaGestioneSeparata ?? -1, 45)
        verifica("M10 Orizzonte: il trattenuto indicato resta", giaIndicata.trattenuto ?? -1, 1.1)

        // La combinazione del KID è fissa: la scheda ammette solo il 30% in gestione separata
        verifica("M10 Orizzonte Valore: quota minima ammessa", scheda.quotaGestioneMinima ?? -1, 30)
        verifica("M10 Orizzonte Valore: quota massima ammessa", scheda.quotaGestioneMassima ?? -1, 30)
        // Le condizioni del contratto (Valutazione) hanno i dati di rischio del Fondo Interno
        let fi = scheda.condizioni?.componenti.first { $0.tipo == .fondoInterno }
        verifica("M10 Orizzonte Valore: volatilità del Fondo Interno nelle condizioni", fi?.volatilita ?? -1, 12)
        verifica("M10 Orizzonte Valore: quota azionaria del Fondo Interno nelle condizioni", fi?.quotaAzionaria ?? -1, 75)
        let gs = scheda.condizioni?.componenti.first { $0.tipo == .gestioneSeparata }
        verifica.vero("M10 Orizzonte Valore: la gestione separata delle condizioni non consolida", gs?.consolidamento == false)
    }

    // MARK: - M10. Un Ramo I creato da una scheda porta le garanzie della gestione separata

    private static func ramoI(_ verifica: VerificaCalcoli) {
        var scheda = Prodotto(nome: "Rivalutabile di prova", canale: .alleanza, area: .risparmio)
        scheda.tipologia = "Polizza rivalutabile Ramo I"
        scheda.rendimentoAtteso = 2.8
        scheda.trattenuto = 1.2
        scheda.minimoGarantito = 0
        scheda.consolidamento = true
        // Un campo della multiramo sulla scheda: per un Ramo I non si copia
        scheda.rendimentoFondi = 5
        let p = scheda.proposta(per: "prova")
        verifica.vero("M10 Ramo I dalla scheda: è una gestione separata, non una multiramo", p.gestioneSeparata && !p.multiramo)
        verifica("M10 Ramo I dalla scheda: trattenuto", p.trattenuto ?? -1, 1.2)
        verifica("M10 Ramo I dalla scheda: minimo garantito", p.minimoGarantito ?? -1, 0)
        verifica.vero("M10 Ramo I dalla scheda: consolidamento annuo", p.consolidamento == true)
        verifica.vero("M10 Ramo I dalla scheda: niente campi delle due parti", p.rendimentoFondi == nil && !p.multiramoDivisa)
        // Il Ramo I resta calcolato come prima, con la garanzia sul contratto
        let par = ParametriProiezione(posizione: p)
        verifica.vero("M10 Ramo I dalla scheda: proiezione a comparto unico", par.gestione == nil && par.capitaleGarantito)
        if let g = MotoreGestioneSeparata.calcola(p) {
            verifica("M10 Ramo I dalla scheda: accreditato 2,8 − 1,2", g.accreditato, 1.6, tolleranza: 0.0001)
        } else {
            verifica.vero("M10 Ramo I dalla scheda: pannello della gestione separata", false)
        }
    }

    // MARK: - M10. I dati di prova di Marco e la scheda «Polizza multiramo»

    /// La multiramo di Marco e la sua scheda hanno le due parti: il rendimento complessivo (4,5%) è lo stesso
    /// numero delle parti pesate, e le cifre composte sono quelle della specifica (costo 1,90%, netto 2,60%).
    private static func marco(_ verifica: VerificaCalcoli) {
        let demo = DatiPrisma.demo()
        guard let m = demo.posizioni.first(where: { $0.id == "pos-marco-polizza-multiramo" }) else {
            verifica.vero("M10 Multiramo di Marco nei dati di prova", false)
            return
        }
        verifica.vero("M10 Marco: multiramo a due parti", m.multiramo && m.multiramoDivisa)
        verifica("M10 Marco: 40% in gestione separata", m.parteGestione, 0.4, tolleranza: 0.0001)
        verifica("M10 Marco: complessivo = 0,4 × 3,0 + 0,6 × 5,5", m.rendimentoLordoComposto, m.rendimentoAtteso ?? -1, tolleranza: 0.0001)
        verifica("M10 Marco: costo composto 0,4 × 1,3 + 0,6 × 2,3", m.costoComplessivo ?? -1, 1.90, tolleranza: 0.0001)
        verifica("M10 Marco: rendimento netto composto 0,4 × 1,7 + 0,6 × 3,2", m.rendimentoNettoComposto, 2.60, tolleranza: 0.0001)
        verifica("M10 Marco: bollo sulla sola parte in fondi", m.quotaBollo, 0.6, tolleranza: 0.0001)
        verifica("M10 Marco: SRI dei fondi", Double(m.sriParteFondi), 4)
        // L'SRI della combinazione è quello del KID (3); la stima dalla volatilità combinata 0,6 × 14 = 8,4 dà 3
        verifica("M10 Marco: SRI della combinazione (KID)", Double(m.sriComposto), 3)
        verifica("M10 Marco: SRI stimato dalla volatilità combinata 8,4%", Double(m.sriStimatoComposto), 3)
        // Nessun titolo di Stato per parte sulla posizione: l'aliquota resta il 24% su tutte e due
        verifica("M10 Marco: aliquota pesata invariata", m.aliquotaPesata(valore: 1, valoreGestione: m.parteGestione), 24, tolleranza: 0.0001)
        verifica.vero("M10 Marco: collegata alla scheda «Polizza multiramo»", m.prodottoId == "prodotto-multiramo")
        // In gestione separata 24.800 €: trattenuto in un anno 322,40 €
        if let g = MotoreGestioneSeparata.calcolaParte(m) {
            verifica("M10 Marco: accreditato della parte in gestione separata", g.accreditato, 1.70, tolleranza: 0.0001)
            verifica("M10 Marco: trattenuto in euro sulla parte (24.800 €)", g.trattenutoEuro, 322.40)
        } else {
            verifica.vero("M10 Marco: la parte in gestione separata si calcola", false)
        }

        guard let s = demo.prodotti.first(where: { $0.id == "prodotto-multiramo" }) else {
            verifica.vero("M10 Scheda «Polizza multiramo» nei dati di prova", false)
            return
        }
        verifica("M10 Scheda multiramo: complessivo coerente con le parti", s.rendimentoAtteso ?? -1, 0.4 * 3.0 + 0.6 * 5.5, tolleranza: 0.0001)
        let q = s.proposta(per: "prova")
        verifica.vero("M10 Scheda multiramo: la proposta è a due parti", q.multiramoDivisa)
        verifica("M10 Scheda multiramo: quota in gestione separata della proposta", q.quotaGestioneSeparata ?? -1, 40)
        verifica.vero("M10 Scheda multiramo: nessun ribilanciamento", q.ribilanciamento == false)
        // Titoli di Stato per parte: GS 26 − 0,6 × 13,5 = 17,9; fondi 26 − 0,1 × 13,5 = 24,65; pesata 21,95
        verifica("M10 Scheda multiramo: aliquota della gestione (60% titoli di Stato)", q.aliquotaGestione, 17.9, tolleranza: 0.0001)
        verifica("M10 Scheda multiramo: aliquota dei fondi (10% titoli di Stato)", q.aliquotaFondi, 24.65, tolleranza: 0.0001)
        verifica("M10 Scheda multiramo: aliquota pesata 0,4 × 17,9 + 0,6 × 24,65",
                 q.aliquotaPesata(valore: 1, valoreGestione: q.parteGestione), 21.95, tolleranza: 0.0001)
        // KPI della scheda: due parti, senza il bollo (come le altre schede)
        let esempio = s.parametriEsempio
        verifica.vero("M10 Scheda multiramo: l'esempio tiene la gestione separata", esempio.gestione != nil)
        verifica("M10 Scheda multiramo: esempio con i costi dei fondi senza bollo", esempio.costoAnnuo, 2.3, tolleranza: 0.0001)
        verifica("M10 Scheda multiramo: esempio su 10.000 € per 10 anni", esempio.capitaleIniziale + Double(esempio.anni), 10_010)
    }
}
