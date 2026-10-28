import Foundation

/// Compone i prospetti di dettaglio per il consulente. Tutti i numeri vengono dai motori di Prisma
/// (MotoreProiezione, RiepilogoPosizioni, AvanzamentoObiettivo): qui si scelgono e si ordinano.
/// Ogni ipotesi predefinita usata al posto di un dato mancante viene dichiarata nel prospetto.
enum CompositoreProspetti {

    static let avvertenza = """
    Prospetto illustrativo, preparato sulla base dei dati raccolti e di ipotesi di rendimento che non sono garantite \
    e non sono previsioni. Non è una proposta contrattuale: fanno fede il KID e la documentazione precontrattuale \
    e contrattuale del prodotto. Importi arrotondati all'euro.
    """

    static let metodoProiezione = """
    Metodo: proiezione mese per mese. Ogni versamento entra al netto del costo d'ingresso, il capitale cresce del \
    rendimento mensile equivalente e paga il costo annuo pro quota. A fine periodo le imposte si applicano alla \
    plusvalenza (valore meno versato, se positiva); il valore in euro di oggi sconta l'inflazione ipotizzata. \
    Scenari prudente e favorevole: rendimento atteso meno e più \(numero(IpotesiCalcolo.ampiezzaScenari)) punti.
    """

    static func componi(_ scelta: SceltaProspetto, dati: DatiPrisma, cliente: String, orizzonteConfronto: Int? = nil) -> ContenutoProspetto? {
        switch scelta {
        case .posizione(let id):
            return dati.posizioni.first { $0.id == id }.map { posizione($0, dati: dati) }
        case .confronto(let va, let vb):
            let voci = ElementoConfronto.elenco(dati, cliente: cliente)
            guard let a = voci.first(where: { $0.voce == va }), let b = voci.first(where: { $0.voce == vb }) else { return nil }
            return confronto(a, b, orizzonte: orizzonteConfronto, dati: dati, cliente: cliente)
        case .portafoglio:
            return portafoglio(dati)
        case .riesame:
            // Il riesame vuole la fonte completa del cliente (Analisi 360, incontri…): lo compone StatoShell
            return nil
        case .valutazione, .resoconto, .sostituzione, .previdenza, .protezione, .obiettivo, .liquidita, .checkUp, .resistenza, .costi, .successione, .patrimonio, .fascicolo:
            // Valutazioni e resoconto hanno pagine proprie (ProspettoValutazione, ReportResoconto…)
            return nil
        }
    }

    // MARK: - Una posizione

    static func posizione(_ p: Posizione, dati: DatiPrisma) -> ContenutoProspetto {
        let cliente = dati.clienti.first { $0.id == p.clienteId }
        let orizzonteCliente = cliente?.profilo.orizzonteAnni
        let par = ParametriProiezione(posizione: p, orizzonteCliente: orizzonteCliente)
        let prodotto = p.prodottoId.flatMap { id in dati.prodotti.first { $0.id == id } }
        var b: [BloccoProspetto] = []
        var n = 0
        func sezione(_ titolo: String) {
            n += 1
            b.append(.sezione(numero: String(format: "%02d", n), titolo: titolo))
        }

        // Sintesi
        let scenari = MotoreProiezione.scenari(par)
        let atteso = scenari[1].esito
        if p.area.proiettabile {
            b.append(.indicatori([
                p.stato == .inEssere
                    ? IndicatoreProspetto(etichetta: "Valore attuale", valore: euro(p.valore),
                                          nota: p.dataValore.map { "al \(Formati.dataBreve.string(from: $0))" } ?? (p.controvalore == nil ? "versato" : ""))
                    : IndicatoreProspetto(etichetta: "Versamento iniziale", valore: euro(p.versamentoIniziale)),
                IndicatoreProspetto(etichetta: "Versamenti", valore: p.premioAnnuo > 0 ? euro(p.premioAnnuo) : "—",
                                    nota: p.premioAnnuo > 0 ? "all'anno · \(euro(p.premio)) \(p.frequenza.nome.lowercased())" : "nessun versamento periodico"),
                IndicatoreProspetto(etichetta: "Orizzonte", valore: "\(par.anni) \(par.anni == 1 ? "anno" : "anni")", nota: origineOrizzonte(p, orizzonteCliente)),
                IndicatoreProspetto(etichetta: "Netto atteso", valore: euro(atteso.netto), nota: "\(euro(atteso.reale)) in euro di oggi"),
            ]))
        } else if p.area == .protezione {
            b.append(.indicatori([
                IndicatoreProspetto(etichetta: "Capitale assicurato", valore: euro(p.capitaleAssicurato ?? 0), nota: (p.rischio ?? .altro).nome),
                IndicatoreProspetto(etichetta: "Premio annuo", valore: euro(p.premioAnnuo), nota: p.frequenza == .unica ? "" : "\(euro(p.premio)) \(p.frequenza.nome.lowercased())"),
                IndicatoreProspetto(etichetta: "Per 1.000 € assicurati", valore: costoPerMille(p).map { Formati.euroDecimali($0) } ?? "—", nota: "all'anno"),
                IndicatoreProspetto(etichetta: "Scadenza", valore: p.scadenza.map { Formati.dataBreve.string(from: $0) } ?? "—",
                                    nota: p.scaduta ? "scaduta" : p.anniAllaScadenza.map { "tra \($0) \($0 == 1 ? "anno" : "anni")" } ?? ""),
            ]))
        } else {
            b.append(.indicatori([
                IndicatoreProspetto(etichetta: p.area == .debiti ? "Debito residuo" : "Valore", valore: euro(p.valore),
                                    nota: p.dataValore.map { "al \(Formati.dataBreve.string(from: $0))" } ?? ""),
                IndicatoreProspetto(etichetta: p.area == .debiti ? "Rata annua" : "Versamenti annui", valore: p.premioAnnuo > 0 ? euro(p.premioAnnuo) : "—"),
                IndicatoreProspetto(etichetta: "Scadenza", valore: p.scadenza.map { Formati.dataBreve.string(from: $0) } ?? "—"),
            ]))
        }
        let mancanti = ipotesiMancanti(p, orizzonteCliente: orizzonteCliente)
        if !mancanti.isEmpty {
            b.append(.avviso("Dati mancanti sostituiti da ipotesi predefinite: " + mancanti.joined(separator: "; ") + ". Completa la posizione per un prospetto più preciso."))
        }
        // Per le proposte: cosa cambierebbe rispetto al profilo del cliente (rischio, orizzonte, concentrazione)
        if p.stato == .proposta, let cliente {
            let coerenza = MotoreCoerenza.calcola(cliente: cliente, posizioni: dati.posizioni.filter { $0.clienteId == cliente.id },
                                                  prodotti: dati.prodotti)
            let rilievi = coerenza.incoerenze.filter { i in
                i.dopoLeProposte && (i.posizione?.id == p.id || i.posizione == nil)
            }
            if !rilievi.isEmpty {
                let frasi: [String] = rilievi.prefix(3).map { i in i.dettaglio }
                b.append(.avviso("Con le proposte, rispetto al profilo del cliente. " + frasi.joined(separator: " ")))
            }
        }

        // Dati del contratto
        sezione("Dati del contratto")
        var voci: [CampoVoce] = [
            CampoVoce(etichetta: "Canale", valore: p.canale.nome, canale: p.canale),
            CampoVoce(etichetta: "Stato", valore: p.stato.nome + (p.stato == .proposta ? " · \((p.esito ?? .bozza).nome.lowercased())" : "")),
            CampoVoce(etichetta: "Area", valore: p.area.nome),
        ]
        func aggiungi(_ etichetta: String, _ valore: String?) {
            if let valore, !valore.isEmpty { voci.append(CampoVoce(etichetta: etichetta, valore: valore)) }
        }
        aggiungi("Tipologia", p.tipologia)
        aggiungi("Compagnia o emittente", p.emittente)
        aggiungi("Numero di contratto", p.numeroContratto)
        aggiungi("Contraente", p.contraente)
        aggiungi("Assicurato", p.assicurato)
        aggiungi("Beneficiari", p.beneficiari)
        aggiungi("Decorrenza", p.decorrenza.map { Formati.dataBreve.string(from: $0) })
        aggiungi("Scadenza", p.scadenza.map { Formati.dataBreve.string(from: $0) })
        if p.versamentoIniziale > 0 { aggiungi(p.stato == .inEssere ? "Versamento iniziale" : "Versamento iniziale proposto", euro(p.versamentoIniziale)) }
        if p.premio > 0 { aggiungi("Premio o versamento", "\(euro(p.premio)) · \(p.frequenza.nome.lowercased())") }
        aggiungi("Totale versato", p.totaleVersato.map(euro))
        if p.stato == .inEssere, let v = p.controvalore, !(p.area == .protezione && v == 0) {
            aggiungi(p.area == .debiti ? "Debito residuo" : "Controvalore", euro(v) + (p.dataValore.map { " al \(Formati.dataBreve.string(from: $0))" } ?? ""))
        }
        aggiungi("Capitale assicurato", p.capitaleAssicurato.map(euro))
        aggiungi("Rischio coperto", p.rischio?.nome)
        // Multiramo: l'SRI del KID è quello della combinazione; sotto, le due parti e il rischio dei soli fondi
        aggiungi(p.multiramo ? "SRI della combinazione (KID)" : "Indicatore di rischio (SRI)", p.sri.map { "\($0) su 7" })
        if p.multiramo {
            aggiungi("Composizione", MotoreMultiramo.rigaComposizione(p))
            aggiungi("SRI dei fondi", p.sriFondi.map { "\($0) su 7" })
        }
        b.append(.voci(voci))

        // Costi
        if p.area.proiettabile || p.costoAnnuo != nil || p.trattenuto != nil || p.costoIngresso != nil {
            sezione("Costi e fiscalità")
            let impatto = MotoreProiezione.impattoCosti(par)
            let ingressoPeriodo = costoIngressoNelPeriodo(par)
            var righeCosti: [[CellaProspetto]] = [
                [.t("Costo d'ingresso"), percentualeOpzionale(p.costoIngresso), .n(p.stato == .inEssere ? "versamenti futuri" : "capitale iniziale e versamenti"),
                 .t(euro(ingressoPeriodo))],
            ]
            // Multiramo a due parti: il trattenuto vale sulla sola gestione separata, commissioni, costi dei fondi
            // e bollo sulla sola parte in fondi (ognuno sul suo capitale)
            let ribilanciata = par.gestione?.ribilanciamento == true
            if p.multiramoDivisa, par.gestione != nil {
                let annui = max(0, atteso.costi - ingressoPeriodo)
                // Senza ribilanciamento le due parti sono indipendenti: gli euro del trattenuto si separano esatti
                let trattenutoPeriodo: Double? = ribilanciata ? nil : min(annui, trattenutoGestioneNelPeriodo(par))
                let suiFondi = "parte in fondi (\(quota(p.parteFondi)))" + (p.bolloFondi > 0 ? ", più bollo \(percentuale2(p.bolloFondi))" : "")
                righeCosti.append([.t("Gestione separata: trattenuto sul rendimento"), .t("\(TestiMultiramo.punti(p.trattenutoGestione)) punti"),
                                   .n("parte in gestione separata (\(quota(p.parteGestione)))"),
                                   trattenutoPeriodo.map { CellaProspetto.t(euro($0)) } ?? .n("—")])
                righeCosti.append([.t("Fondi: commissioni e costi dei fondi"), .t(percentuale2(p.costoParteFondi)), .n(suiFondi),
                                   .t(euro(annui - (trattenutoPeriodo ?? 0)))])
            } else {
                righeCosti.append([.t(p.trattenuto == nil ? "Costo annuo di gestione" : "Costo annuo e trattenuto sul rendimento"),
                                   condizioneCostoAnnuo(p),
                                   .n("capitale investito, ogni anno, pro quota mensile"),
                                   .t(euro(max(0, atteso.costi - ingressoPeriodo)))])
            }
            // Nel modo a due parti l'aliquota della proiezione è quella dei soli fondi: qui quella equivalente
            righeCosti.append([.t("Imposta sulle plusvalenze"), .t(percentuale(par.aliquotaEquivalente)), .n("guadagno a fine periodo"), .t(euro(atteso.imposte))])
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Voce", peso: 2.2), ColonnaProspetto(titolo: "Condizione", peso: 1, destra: true),
                          ColonnaProspetto(titolo: "Si applica a", peso: 2.2), ColonnaProspetto(titolo: "In \(par.anni) anni", peso: 1.1, destra: true)],
                righe: righeCosti,
                totale: [.f("Costi e imposte, scenario atteso"), .t(""), .t(""), .f(euro(atteso.costi + atteso.imposte))]
            )))
            if p.multiramoDivisa && ribilanciata {
                b.append(.nota("Con il ribilanciamento annuo le due parti si scambiano capitale ogni anno: i costi in euro del periodo sono un totale unico, nella riga dei fondi."))
            }
            b.append(.voci([
                CampoVoce(etichetta: "Effetto dei costi sul netto finale", valore: euro(impatto)),
                // Multiramo a due parti: rendimento e costo equivalenti di un comparto unico (pesati sulle quote)
                CampoVoce(etichetta: "Rendimento ipotizzato al netto del costo annuo",
                          valore: percentuale(par.rendimentoEquivalente - par.costoAnnuoEquivalente)),
                CampoVoce(etichetta: "Costi sul versato totale", valore: atteso.versato > 0 ? percentuale((atteso.costi / atteso.versato * 1000).rounded() / 10) : "—"),
                CampoVoce(etichetta: "Costo del primo anno", valore: euro(primoAnno(par))),
            ]))
            // Gestione separata: quanto trattiene la compagnia, minimo garantito, consolidamento, rendimento reale
            // Multiramo a due parti: lo stesso pannello sulla sola parte in gestione separata
            if let g = MotoreGestioneSeparata.calcola(p) ?? MotoreGestioneSeparata.calcolaParte(p) {
                let parte = p.multiramo
                var gs: [CampoVoce] = [
                    // Etichetta corta: su carta le etichette stanno su una riga sola (maiuscole, si troncano)
                    CampoVoce(etichetta: parte ? "Gestione separata, \(quota(p.parteGestione)) del contratto" : "Rendimento della gestione separata",
                              valore: "lordo \(percentuale2(g.lordo)) · trattenuto \(percentuale2(g.trattenuto)) · accreditato \(percentuale2(g.accreditato))"),
                    CampoVoce(etichetta: "Minimo garantito", valore: minimoGarantito(g)),
                    CampoVoce(etichetta: "Consolidamento dei rendimenti", valore: consolidamento(g.consolidamento)),
                    CampoVoce(etichetta: "Rendimento reale (inflazione \(percentuale(g.inflazione)))", valore: percentuale2(g.reale)),
                    CampoVoce(etichetta: parte ? "Trattenuto in un anno, sulla parte" : "Trattenuto in un anno, sul valore di oggi", valore: euro(g.trattenutoEuro)),
                ]
                if let s = g.garantitoAScadenza {
                    gs.append(CampoVoce(etichetta: parte ? "Garantito a scadenza, sulla parte" : "Garantito alla scadenza, prima delle imposte", valore: euro(s)))
                }
                b.append(.voci(gs))
                if g.reale < 0 {
                    let soggetto = parte ? "La parte in gestione separata" : "La gestione separata"
                    b.append(.avviso("\(soggetto) accredita meno dell'inflazione ipotizzata: il capitale non scende, ma perde potere d'acquisto (\(percentuale2(g.reale)) l'anno in termini reali)."))
                }
                // Come si legge: le ipotesi della stima a portata di mano
                b.append(.nota(MotoreGestioneSeparata.metodo + " Rendimento lordo ipotizzato, non garantito."))
            }
            // Incidenza annua dei costi come nel KID (RIY): il calcolo di Prisma accanto al dato dichiarato nel KID
            if let kid = MotoreCosti.incidenzaKID(p, prodotto: prodotto), !kid.periodi.isEmpty {
                b.append(.tabella(TabellaProspetto(
                    // Intestazioni brevi e pesi misurati: su carta le intestazioni sono in maiuscolo su una riga sola
                    colonne: [ColonnaProspetto(titolo: "Uscita, come nel KID", peso: 1.6),
                              ColonnaProspetto(titolo: "Rend. senza costi", peso: 1.15, destra: true), ColonnaProspetto(titolo: "Rend. con i costi", peso: 1.15, destra: true),
                              ColonnaProspetto(titolo: "RIY l'anno", peso: 0.8, destra: true), ColonnaProspetto(titolo: "Costi in euro", destra: true)],
                    righe: kid.periodi.map { q -> [CellaProspetto] in
                        [.t(q.anni == 1 ? "Uscita dopo 1 anno" : "Uscita dopo \(q.anni) anni"), .t(percentuale2(q.senzaCosti)),
                         .t(percentuale2(q.conCosti)), .f(percentuale2(q.riy)), .t(euro(q.costi))]
                    }
                )))
                var riy: [CampoVoce] = [
                    CampoVoce(etichetta: "RIY calcolato da Prisma a \(kid.periodoRaccomandato) \(kid.periodoRaccomandato == 1 ? "anno" : "anni")",
                              valore: kid.calcolato.map { percentuale2($0) } ?? "—"),
                    CampoVoce(etichetta: "RIY dichiarato nel KID", valore: kid.dichiarato.map { percentuale2($0) } ?? "non indicato"),
                ]
                if let s = kid.scarto {
                    riy.append(CampoVoce(etichetta: "Calcolo meno KID", valore: CifreDoc.variazione(s, decimali: 2)
                                         + (s > sogliaScartoKID ? " · i costi pesano più di quanto dice il KID" : "")))
                }
                b.append(.voci(riy))
                b.append(.nota(IncidenzaCostiKID.metodo))
            }
        }

        // Proiezione
        if p.area.proiettabile {
            sezione("Proiezione nei tre scenari")
            // Multiramo a due parti: il rendimento del contratto (equivalente, pesato sulle quote); la tupla degli
            // scenari porta già il rendimento equivalente
            b.append(.voci([
                CampoVoce(etichetta: "Rendimento annuo atteso", valore: percentuale(par.rendimentoEquivalente)),
                CampoVoce(etichetta: "Prudente e favorevole", valore: "\(percentuale(scenari[0].rendimento)) · \(percentuale(scenari[2].rendimento))"),
                CampoVoce(etichetta: "Inflazione ipotizzata", valore: percentuale(par.inflazione)),
                CampoVoce(etichetta: "Si parte da", valore: euro(par.capitaleIniziale)),
            ]))
            if p.multiramoDivisa {
                b.append(.testo("Rendimento del contratto, \(MotoreMultiramo.rigaComposizione(p)). \(scenariMultiramo)"))
            }
            b.append(.grafico([
                SerieGraficoProspetto(nome: "Prudente", tono: .prudente, punti: scenari[0].esito.punti),
                SerieGraficoProspetto(nome: "Atteso", tono: .atteso, punti: scenari[1].esito.punti),
                SerieGraficoProspetto(nome: "Favorevole", tono: .favorevole, punti: scenari[2].esito.punti),
            ]))
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Voce", peso: 1.8), ColonnaProspetto(titolo: "Prudente", destra: true),
                          ColonnaProspetto(titolo: "Atteso", destra: true), ColonnaProspetto(titolo: "Favorevole", destra: true)],
                righe: [
                    [CellaProspetto.t("Rendimento ipotizzato")] + scenari.map { CellaProspetto.t(percentuale($0.rendimento)) },
                    [CellaProspetto.t("Totale versato")] + scenari.map { CellaProspetto.t(euro($0.esito.versato)) },
                    [CellaProspetto.t("Costi nel periodo")] + scenari.map { CellaProspetto.t(euro($0.esito.costi)) },
                    [CellaProspetto.t("Valore lordo")] + scenari.map { CellaProspetto.t(euro($0.esito.lordo)) },
                    [CellaProspetto.t("Imposte")] + scenari.map { CellaProspetto.t(euro($0.esito.imposte)) },
                    [CellaProspetto.f("Valore netto")] + scenari.map { CellaProspetto.f(euro($0.esito.netto)) },
                    [CellaProspetto.t("Netto in euro di oggi")] + scenari.map { CellaProspetto.t(euro($0.esito.reale)) },
                    [CellaProspetto.t("Guadagno netto")] + scenari.map { CellaProspetto.t(euro($0.esito.guadagnoNetto)) },
                ]
            )))

            sezione("Anno per anno")
            let annoOggi = Calendar.current.component(.year, from: Date())
            let deflatore: (Int) -> Double = { pow(1 + par.inflazione / 100, Double($0)) }
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Anno", peso: 0.55), ColonnaProspetto(titolo: "", peso: 0.6),
                          ColonnaProspetto(titolo: "Versato", destra: true), ColonnaProspetto(titolo: "Prudente", destra: true),
                          ColonnaProspetto(titolo: "Atteso", destra: true), ColonnaProspetto(titolo: "Favorevole", destra: true),
                          ColonnaProspetto(titolo: "Atteso, euro di oggi", peso: 1.2, destra: true)],
                righe: atteso.punti.indices.map { i -> [CellaProspetto] in
                    let pt = atteso.punti[i]
                    return [.t(pt.anno == 0 ? "Oggi" : "\(pt.anno)"), .n(String(annoOggi + pt.anno)), .t(euro(pt.versato)),
                            .t(euro(scenari[0].esito.punti[i].valore)), .f(euro(pt.valore)), .t(euro(scenari[2].esito.punti[i].valore)),
                            .t(euro(pt.valore / deflatore(pt.anno)))]
                },
                evidenzia: [atteso.punti.count - 1]
            )))
            b.append(.nota("Valori di fine anno al netto dei costi e prima delle imposte, che si applicano al riscatto o alla scadenza."))
        }

        // Riscatto anno per anno (polizze, fondi ed ETF): blocco, penali, costo d'uscita, imposte
        if let r = MotoreRiscatto.calcola(p, prodotto: prodotto), !r.righe.isEmpty {
            sezione("Riscatto anno per anno")
            b.append(.testo(fraseRiscatto(r)))
            var primo = Set<Int>()
            if let k = r.righe.firstIndex(where: { $0.recuperaVersato }) { primo.insert(k) }
            let inEssere = p.stato == .inEssere
            b.append(.tabella(TabellaProspetto(
                // Pesi misurati sulle cifre e su «non riscattabile»: su carta le celle si troncano, non vanno a capo
                colonne: [ColonnaProspetto(titolo: "Riscatto al", peso: 1.1), ColonnaProspetto(titolo: "Anno", peso: 0.55, destra: true),
                          ColonnaProspetto(titolo: "Versato", peso: 0.85, destra: true), ColonnaProspetto(titolo: "Valore", peso: 0.85, destra: true),
                          ColonnaProspetto(titolo: "Penale", peso: 0.7, destra: true), ColonnaProspetto(titolo: "Imposte e bollo", peso: 1.3, destra: true),
                          ColonnaProspetto(titolo: "Netto", peso: 1.15, destra: true), ColonnaProspetto(titolo: "Netto − versato", peso: 1.3, destra: true)],
                righe: r.righe.map { x -> [CellaProspetto] in
                    let quando: CellaProspetto = .t(x.anni == 0 ? (inEssere ? "Oggi" : "Sottoscrizione") : Formati.dataBreve.string(from: x.data))
                    guard x.possibile else {
                        return [quando, .n("\(x.annoContratto)°"), .n(euro(x.versato)), .n(euro(x.valore)), .n("—"), .n("—"),
                                .n("non riscattabile"), .n("—")]
                    }
                    let penale: CellaProspetto = x.penalePercento > 0 ? .t(percentuale(x.penalePercento)) : .n("nessuna")
                    return [quando, .t("\(x.annoContratto)°"), .t(euro(x.versato)), .t(euro(x.valore)), penale,
                            .t(euro(x.imposta + x.bollo)), .f(euro(x.netto)), .t(segno(x.guadagno))]
                },
                evidenzia: primo
            )))
            b.append(.nota(EsitoRiscatto.criterio + " " + EsitoRiscatto.metodo))
        }

        // Copertura
        if p.area == .protezione {
            sezione("La copertura")
            var cop: [CampoVoce] = [
                CampoVoce(etichetta: "Rischio coperto", valore: (p.rischio ?? .altro).nome),
                CampoVoce(etichetta: "Capitale assicurato", valore: euro(p.capitaleAssicurato ?? 0)),
                CampoVoce(etichetta: "Premio annuo", valore: euro(p.premioAnnuo)),
                CampoVoce(etichetta: "Costo per 1.000 € assicurati", valore: costoPerMille(p).map { Formati.euroDecimali($0) } ?? "—"),
            ]
            if let anni = p.anniAllaScadenza, p.premioAnnuo > 0, !p.scaduta {
                cop.append(CampoVoce(etichetta: "Premi fino alla scadenza", valore: "\(euro(p.premioAnnuo * Double(anni))) in \(anni) \(anni == 1 ? "anno" : "anni")"))
            }
            if let c = p.capitaleAssicurato, p.premioAnnuo > 0 {
                cop.append(CampoVoce(etichetta: "Leva del premio", valore: "1 € di premio copre \(euro(c / p.premioAnnuo))"))
            }
            b.append(.voci(cop))
        }

        // Garanzie e note
        let testi = [p.garanzie.isEmpty ? nil : "Garanzie: \(p.garanzie)",
                     prodotto.flatMap { $0.liquidabilita.isEmpty ? nil : "Liquidabilità: \($0.liquidabilita)" },
                     p.note.isEmpty ? nil : "Note: \(p.note)"].compactMap { $0 }
        if !testi.isEmpty {
            sezione("Garanzie e note")
            for t in testi { b.append(.testo(t)) }
        }

        // Fonti
        let documenti = dati.documenti.filter { d in d.posizioneId == p.id || (p.prodottoId != nil && d.prodottoId == p.prodottoId) }
        let campi = documenti.flatMap { d in d.campi.filter(\.confermato).map { (d, $0) } }
        if prodotto != nil || !campi.isEmpty {
            sezione("Fonti dei dati")
            if let prodotto {
                var f = [CampoVoce(etichetta: "Scheda prodotto", valore: prodotto.nome, canale: prodotto.canale)]
                if !prodotto.fonte.isEmpty { f.append(CampoVoce(etichetta: "Fonte della scheda", valore: prodotto.fonte)) }
                f.append(CampoVoce(etichetta: "Verificata il", valore: prodotto.verificatoIl.map { Formati.dataBreve.string(from: $0) + (prodotto.daVerificare ? " · da riverificare" : "") } ?? "mai verificata"))
                b.append(.voci(f))
            }
            if !campi.isEmpty {
                b.append(.tabella(TabellaProspetto(
                    colonne: [ColonnaProspetto(titolo: "Dato confermato", peso: 1.8), ColonnaProspetto(titolo: "Valore", peso: 1.6),
                              ColonnaProspetto(titolo: "Documento", peso: 2), ColonnaProspetto(titolo: "Pagina", peso: 0.6, destra: true)],
                    righe: campi.map { coppia -> [CellaProspetto] in
                        let (d, c) = coppia
                        return [.t(c.chiave.nome), .f(c.valore + (c.chiave.unita.isEmpty || c.chiave.unita == "su 7" ? "" : " \(c.chiave.unita)")), .n(d.titolo), .t("p. \(c.pagina)")]
                    }
                )))
            }
        }

        // Multiramo a due parti: come si calcolano le due parti (garanzia, bollo, imposta unica)
        let metodoParti = p.area.proiettabile && p.multiramoDivisa ? MotoreMultiramo.metodo + " " + scenariMultiramo + "\n\n" : ""
        b.append(.nota((p.area.proiettabile ? metodoProiezione + "\n\n" : "") + metodoParti + avvertenza))

        let titoloStato = p.stato == .proposta ? "proposta" : p.stato == .inEssere ? "posizione in essere" : "posizione chiusa"
        return ContenutoProspetto(occhiello: "Prospetto di dettaglio · \(titoloStato)",
                                  titolo: p.nome,
                                  sottotitolo: [p.tipologia, p.emittente, p.area.nome].filter { !$0.isEmpty }.joined(separator: " · "),
                                  cliente: cliente?.nome ?? "", canale: p.canale, blocchi: b)
    }

    // MARK: - Confronto

    static func confronto(_ a: ElementoConfronto, _ b: ElementoConfronto, orizzonte: Int?, dati: DatiPrisma, cliente: String) -> ContenutoProspetto {
        var pa = a.parametri
        var pb = b.parametri
        if let orizzonte {
            pa.anni = orizzonte
            pb.anni = orizzonte
        }
        let ea = MotoreProiezione.calcola(pa)
        let eb = MotoreProiezione.calcola(pb)
        let sa = MotoreProiezione.scenari(pa)
        let sb = MotoreProiezione.scenari(pb)
        let ia = MotoreProiezione.impattoCosti(pa)
        let ib = MotoreProiezione.impattoCosti(pb)
        var bl: [BloccoProspetto] = []

        bl.append(.indicatori([
            IndicatoreProspetto(etichetta: "A · netto atteso", valore: euro(ea.netto), nota: "in \(pa.anni) anni"),
            IndicatoreProspetto(etichetta: "B · netto atteso", valore: euro(eb.netto), nota: "in \(pb.anni) anni"),
            IndicatoreProspetto(etichetta: "Differenza B − A", valore: segno(eb.netto - ea.netto), nota: pa.anni == pb.anni ? "stesso orizzonte" : "orizzonti diversi"),
            IndicatoreProspetto(etichetta: "Costi A · B", valore: "\(euro(ea.costi)) · \(euro(eb.costi))", nota: "nel periodo"),
        ]))
        if pa.anni != pb.anni {
            bl.append(.avviso("Le due voci hanno orizzonti diversi (\(pa.anni) e \(pb.anni) anni): per un confronto equo scegli l'orizzonte comune in Confronti."))
        }

        let colonneAB = [ColonnaProspetto(titolo: "Voce", peso: 1.8), ColonnaProspetto(titolo: "A · \(a.titolo)", peso: 1.6, destra: true),
                         ColonnaProspetto(titolo: "B · \(b.titolo)", peso: 1.6, destra: true)]
        bl.append(.sezione(numero: "01", titolo: "Le due voci"))
        func versamento(_ p: ParametriProiezione) -> CellaProspetto {
            p.versamento > 0 && p.frequenza != .unica ? .t("\(euro(p.versamento)) \(p.frequenza.nome.lowercased())") : .n("—")
        }
        bl.append(.tabella(TabellaProspetto(
            colonne: colonneAB,
            righe: [
                [.t("Canale"), a.canale.map { CellaProspetto.c($0) } ?? .n("—"), b.canale.map { CellaProspetto.c($0) } ?? .n("—")],
                [.t("Che cos'è"), .n(a.sottotitolo), .n(b.sottotitolo)],
                [.t("Capitale di partenza"), .t(euro(pa.capitaleIniziale)), .t(euro(pb.capitaleIniziale))],
                [.t("Versamento periodico"), versamento(pa), versamento(pb)],
                [.t("Orizzonte"), .t("\(pa.anni) anni"), .t("\(pb.anni) anni")],
                // Equivalenti di un comparto unico: per una multiramo a due parti pesati sulle quote, altrimenti
                // rendimento, costo annuo e aliquota della proiezione
                [.t("Rendimento atteso"), .t(percentuale(pa.rendimentoEquivalente)), .t(percentuale(pb.rendimentoEquivalente))],
                [.t("Costo d'ingresso"), .t(percentuale(pa.costoIngresso)), .t(percentuale(pb.costoIngresso))],
                [.t("Costo annuo"), .t(percentuale(pa.costoAnnuoEquivalente)), .t(percentuale(pb.costoAnnuoEquivalente))],
                [.t("Imposta sulle plusvalenze"), .t(percentuale(pa.aliquotaEquivalente)), .t(percentuale(pb.aliquotaEquivalente))],
            ]
        )))

        bl.append(.sezione(numero: "02", titolo: "Esiti nello scenario atteso"))
        func riga(_ nome: String, _ x: Double, _ y: Double, forte: Bool = false) -> [CellaProspetto] {
            forte ? [.f(nome), .f(euro(x)), .f(euro(y)), .f(segno(y - x))] : [.t(nome), .t(euro(x)), .t(euro(y)), .t(segno(y - x))]
        }
        bl.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Voce", peso: 1.8), ColonnaProspetto(titolo: "A", peso: 1.2, destra: true),
                      ColonnaProspetto(titolo: "B", peso: 1.2, destra: true), ColonnaProspetto(titolo: "Differenza B − A", peso: 1.2, destra: true)],
            righe: [
                riga("Totale versato", ea.versato, eb.versato),
                riga("Costi nel periodo", ea.costi, eb.costi),
                riga("Valore lordo", ea.lordo, eb.lordo),
                riga("Imposte", ea.imposte, eb.imposte),
                riga("Valore netto", ea.netto, eb.netto, forte: true),
                riga("Netto in euro di oggi", ea.reale, eb.reale),
                riga("Guadagno netto", ea.guadagnoNetto, eb.guadagnoNetto),
                riga("Effetto dei costi sul netto", ia, ib),
            ]
        )))

        bl.append(.sezione(numero: "03", titolo: "Andamento nel tempo"))
        bl.append(.grafico([
            SerieGraficoProspetto(nome: "A · \(a.titolo)", tono: .primo, punti: ea.punti),
            SerieGraficoProspetto(nome: "B · \(b.titolo)", tono: .secondo, punti: eb.punti),
        ]))

        bl.append(.sezione(numero: "04", titolo: "Anno per anno"))
        let anni = max(ea.punti.count, eb.punti.count)
        let annoOggi = Calendar.current.component(.year, from: Date())
        bl.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Anno", peso: 0.55), ColonnaProspetto(titolo: "", peso: 0.6),
                      ColonnaProspetto(titolo: "Versato A", destra: true), ColonnaProspetto(titolo: "Valore A", destra: true),
                      ColonnaProspetto(titolo: "Versato B", destra: true), ColonnaProspetto(titolo: "Valore B", destra: true),
                      ColonnaProspetto(titolo: "B − A", destra: true)],
            righe: (0..<anni).map { i -> [CellaProspetto] in
                let x = i < ea.punti.count ? ea.punti[i] : nil
                let y = i < eb.punti.count ? eb.punti[i] : nil
                return [.t(i == 0 ? "Oggi" : "\(i)"), .n(String(annoOggi + i)),
                        x.map { CellaProspetto.t(euro($0.versato)) } ?? .n("—"), x.map { CellaProspetto.f(euro($0.valore)) } ?? .n("—"),
                        y.map { CellaProspetto.t(euro($0.versato)) } ?? .n("—"), y.map { CellaProspetto.f(euro($0.valore)) } ?? .n("—"),
                        x.flatMap { xv in y.map { CellaProspetto.t(segno($0.valore - xv.valore)) } } ?? .n("—")]
            },
            evidenzia: [anni - 1]
        )))

        bl.append(.sezione(numero: "05", titolo: "I tre scenari"))
        bl.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Scenario", peso: 1.1), ColonnaProspetto(titolo: "Rendimento A", peso: 0.9, destra: true),
                      ColonnaProspetto(titolo: "Netto A", destra: true), ColonnaProspetto(titolo: "Rendimento B", peso: 0.9, destra: true),
                      ColonnaProspetto(titolo: "Netto B", destra: true), ColonnaProspetto(titolo: "B − A", destra: true)],
            righe: (0..<3).map { i -> [CellaProspetto] in
                [.f(sa[i].nome), .t(percentuale(sa[i].rendimento)), .t(euro(sa[i].esito.netto)),
                 .t(percentuale(sb[i].rendimento)), .t(euro(sb[i].esito.netto)), .t(segno(sb[i].esito.netto - sa[i].esito.netto))]
            }
        )))

        bl.append(.nota("Le due voci sono calcolate con lo stesso motore e le stesse regole; per le posizioni in essere si parte dal valore attuale, per le proposte dal versamento iniziale.\n\n" + metodoProiezione + "\n\n" + avvertenza))

        let canali = [a.canale, b.canale].compactMap { $0 }
        return ContenutoProspetto(occhiello: "Prospetto di dettaglio · confronto",
                                  titolo: "\(a.titolo) e \(b.titolo)",
                                  sottotitolo: "A: \(a.sottotitolo)   —   B: \(b.sottotitolo)",
                                  cliente: dati.clienti.first { $0.id == cliente }?.nome ?? "",
                                  canale: canali.first, canaleSecondo: canali.count == 2 && canali[0] != canali[1] ? canali[1] : nil,
                                  blocchi: bl)
    }

    // MARK: - Aiuti

    static func costoPerMille(_ p: Posizione) -> Double? {
        guard let c = p.capitaleAssicurato, c > 0, p.premioAnnuo > 0 else { return nil }
        return p.premioAnnuo / c * 1000
    }

    /// Costi d'ingresso pagati nel periodo, sul capitale (se si applica) e sui versamenti.
    static func costoIngressoNelPeriodo(_ p: ParametriProiezione) -> Double {
        let quota = min(max(p.costoIngresso, 0), 99) / 100
        let versamenti = p.frequenza.volteAllAnno > 0 && p.versamento > 0 ? p.versamento * Double(p.frequenza.volteAllAnno * max(0, p.anni)) : 0
        return ((p.ingressoSulCapitale ? p.capitaleIniziale : 0) + versamenti) * quota
    }

    /// Multiramo a due parti: gli euro trattenuti dalla gestione separata nel periodo. Senza costi dei fondi la
    /// proiezione costa ingresso più trattenuto; senza anche il trattenuto, solo l'ingresso: la differenza è il
    /// trattenuto. Esatto senza ribilanciamento (le due parti non si scambiano capitale).
    static func trattenutoGestioneNelPeriodo(_ p: ParametriProiezione) -> Double {
        guard p.gestione != nil else { return 0 }
        var soloGestione = p
        soloGestione.costoAnnuo = 0
        var libera = soloGestione
        libera.gestione?.trattenuto = nil
        libera.gestione?.retrocessione = nil
        return max(0, MotoreProiezione.calcola(soloGestione).costi - MotoreProiezione.calcola(libera).costi)
    }

    /// Gli scenari delle multiramo a due parti: i fondi si spostano più della gestione separata.
    static var scenariMultiramo: String {
        "Scenari prudente e favorevole: fondi \(numero(IpotesiCalcolo.ampiezzaScenari)) punti in meno e in più, gestione separata \(numero(IpotesiCalcolo.ampiezzaScenariGestione))."
    }

    /// Costi del primo anno: la proiezione su un anno, senza imposte.
    static func primoAnno(_ p: ParametriProiezione) -> Double {
        var q = p
        q.anni = 1
        return MotoreProiezione.calcola(q).costi
    }

    /// Oltre questo scarto (punti l'anno) il RIY calcolato si segnala come più alto di quello del KID.
    static let sogliaScartoKID = 0.3

    /// Il riscatto in parole: quando si può chiedere, quando restituisce il versato, quando finiscono le penali.
    static func fraseRiscatto(_ r: EsitoRiscatto) -> String {
        var frasi: [String] = []
        if let d = r.riscattabileDal {
            frasi.append("Il riscatto si può chiedere dal \(Formati.dataBreve.string(from: d)).")
        }
        if let x = r.primoRecupero {
            frasi.append(x.anni == 0 ? "Già oggi il riscatto restituisce almeno quanto versato."
                         : "Dal \(Formati.dataBreve.string(from: x.data)) il riscatto restituisce almeno quanto versato (\(euro(x.netto)) netti su \(euro(x.versato))).")
        } else {
            frasi.append("Negli anni mostrati il riscatto non restituisce quanto versato, al rendimento atteso.")
        }
        if r.annoSenzaPenali > 1, let d = r.senzaPenaliDal {
            frasi.append("Penali fino al \(r.annoSenzaPenali - 1)° anno di contratto: senza penali dal \(Formati.dataBreve.string(from: d))"
                         + (r.costoUscita > 0 ? ", resta il costo d'uscita del \(percentuale(r.costoUscita))." : "."))
        } else if r.costoUscita > 0 {
            frasi.append("Nessuna penale; costo d'uscita del \(percentuale(r.costoUscita)) sul valore.")
        } else {
            frasi.append("Nessuna penale di riscatto.")
        }
        // La legenda della tabella, solo per quello che c'è davvero
        if r.righe.contains(where: { !$0.possibile }) {
            frasi.append("Righe «non riscattabile»: mesi in cui il contratto non permette ancora il riscatto.")
        }
        if r.primoRecupero != nil {
            frasi.append("Riga evidenziata: primo anno conveniente.")
        }
        frasi.append("«Anno» è l'anno di contratto. Cifre stimate al rendimento atteso, non garantite.")
        return frasi.joined(separator: " ")
    }

    /// "1,00% l'anno · decide il minimo", "solo il capitale", "non indicato".
    private static func minimoGarantito(_ g: EsitoGestioneSeparata) -> String {
        guard let m = g.minimoGarantito else {
            return g.minimoDecisivo ? "non indicato · conta il capitale garantito" : "non indicato"
        }
        let base = m > 0 ? percentuale2(m) + " l'anno" : "solo il capitale"
        return base + (g.minimoDecisivo ? " · decide il minimo" : "")
    }

    private static func consolidamento(_ c: Bool?) -> String {
        switch c {
        case .some(true): return "annuo: i rendimenti accreditati restano acquisiti"
        case .some(false): return "solo a scadenza o al decesso: prima il valore può scendere"
        case .none: return "non indicato (si considera annuo)"
        }
    }

    private static func origineOrizzonte(_ p: Posizione, _ orizzonteCliente: Int?) -> String {
        if p.anniAllaScadenza != nil { return "fino alla scadenza" }
        if orizzonteCliente != nil { return "orizzonte del cliente" }
        return "ipotesi predefinita"
    }

    /// "1,5%", oppure "1,5% + 1,3%" con il trattenuto sul rendimento; per una multiramo a due parti
    /// "GS 1,30 punti · fondi 2,30%" (ognuno sulla sua parte).
    private static func condizioneCostoAnnuo(_ p: Posizione) -> CellaProspetto {
        if p.multiramoDivisa { return .t(TestiMultiramo.costiPerParte(p)) }
        guard let trattenuto = p.trattenuto else { return percentualeOpzionale(p.costoAnnuo) }
        let gestione = p.costoAnnuo.map { percentuale($0) + " + " } ?? ""
        return .t(gestione + percentuale(trattenuto))
    }

    static func ipotesiMancanti(_ p: Posizione, orizzonteCliente: Int?) -> [String] {
        guard p.area.proiettabile else { return [] }
        var m: [String] = []
        if p.multiramoDivisa {
            // Due parti: un rendimento mancante si ricava dal complessivo, o è l'ipotesi predefinita
            if !p.rendimentoIndicato {
                m.append("rendimento atteso \(percentuale(IpotesiCalcolo.rendimentoPredefinito))")
            } else {
                if p.rendimentoGestione == nil { m.append("rendimento della gestione separata \(origineRendimento(p, gestione: true))") }
                if p.rendimentoFondi == nil { m.append("rendimento dei fondi \(origineRendimento(p, gestione: false))") }
            }
            if p.consolidamento == nil { m.append("consolidamento della gestione separata ipotizzato annuo") }
            let titoli = p.quotaTitoliStato != nil || p.titoliStatoGestione != nil || p.titoliStatoFondi != nil
            if p.aliquotaFiscale == nil && !titoli { m.append("imposta \(percentuale(IpotesiCalcolo.aliquotaPredefinita))") }
            if !p.costiIndicati { m.append("costo annuo non indicato, calcolato a zero") }
        } else {
            if p.rendimentoAtteso == nil { m.append("rendimento atteso \(percentuale(IpotesiCalcolo.rendimentoPredefinito))") }
            if p.multiramo { m.append("multiramo calcolata come comparto unico") }
            if p.aliquotaFiscale == nil { m.append("imposta \(percentuale(IpotesiCalcolo.aliquotaPredefinita))") }
            if p.costoAnnuo == nil && p.trattenuto == nil { m.append("costo annuo non indicato, calcolato a zero") }
        }
        if p.quotaGestioneStimata { m.append("quota in gestione separata \(percentuale(Posizione.quotaGestionePredefinita))") }
        if p.anniAllaScadenza == nil && orizzonteCliente == nil { m.append("orizzonte di \(IpotesiCalcolo.orizzontePredefinito) anni") }
        return m
    }

    /// Da dove viene il rendimento di una parte non indicato (lo stesso ordine di `lordoGestione` e
    /// `lordoFondi`): ricavato dal complessivo e dall'altra parte, pari al complessivo, o l'ipotesi predefinita.
    private static func origineRendimento(_ p: Posizione, gestione: Bool) -> String {
        guard p.rendimentoAtteso != nil else { return percentuale(IpotesiCalcolo.rendimentoPredefinito) }
        let altra = gestione ? p.rendimentoFondi : p.rendimentoGestione
        let parte = gestione ? p.parteGestione : p.parteFondi
        return altra != nil && parte >= 0.1 ? "ricavato dal complessivo" : "pari al complessivo"
    }

    private static func euro(_ v: Double) -> String { Formati.euro(v) }
    private static func percentuale(_ v: Double) -> String { Formati.percentuale(v) }
    /// Percentuale con due decimali ("1,25%", "−0,40%"), per rendimenti e incidenze dei costi.
    private static func percentuale2(_ v: Double) -> String { CifreDoc.percento(v, decimali: 2) }
    private static func numero(_ v: Double) -> String { Formati.numeroFormatter.string(from: NSNumber(value: v)) ?? "\(v)" }
    private static func percentualeOpzionale(_ v: Double?) -> CellaProspetto { v.map { CellaProspetto.t(percentuale($0)) } ?? .n("non indicato") }
    /// Quota 0–1 come percentuale con al più un decimale ("13,2%").
    private static func quota(_ q: Double) -> String { percentuale((q * 1000).rounded() / 10) }
    private static func segno(_ v: Double) -> String { (v > 0.5 ? "+" : "") + euro(v) }
}

extension AreaPosizione {
    /// Ordine di lettura nei prospetti: prima ciò che lavora, poi liquidità, immobili e debiti.
    var ordine: Int {
        switch self {
        case .previdenza: return 0
        case .investimento: return 1
        case .risparmio: return 2
        case .protezione: return 3
        case .liquidita: return 4
        case .immobili: return 5
        case .debiti: return 6
        }
    }
}
