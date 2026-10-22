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
        case .quadro:
            return quadro(dati: dati, cliente: cliente)
        case .posizione(let id):
            return dati.posizioni.first { $0.id == id }.map { posizione($0, dati: dati) }
        case .confronto(let va, let vb):
            let voci = ElementoConfronto.elenco(dati, cliente: cliente)
            guard let a = voci.first(where: { $0.voce == va }), let b = voci.first(where: { $0.voce == vb }) else { return nil }
            return confronto(a, b, orizzonte: orizzonteConfronto, dati: dati, cliente: cliente)
        case .valutazione:
            // Prospetto e report delle valutazioni hanno pagine proprie (ProspettoValutazione, ReportValutazione)
            return nil
        }
    }

    // MARK: - Quadro delle posizioni

    static func quadro(dati: DatiPrisma, cliente id: String) -> ContenutoProspetto? {
        guard let cliente = dati.clienti.first(where: { $0.id == id }) else { return nil }
        let tutte = dati.posizioni.filter { $0.clienteId == id && $0.stato != .chiusa }
        let inEssere = tutte.filter { $0.stato == .inEssere }
            .sorted { ($0.area.ordine, -$0.valore) < ($1.area.ordine, -$1.valore) }
        let proposte = tutte.filter { $0.stato == .proposta }
        let r = RiepilogoPosizioni(tutte)
        var b: [BloccoProspetto] = []

        b.append(.indicatori([
            IndicatoreProspetto(etichetta: "Attività in essere", valore: euro(r.attivita),
                                nota: "\(inEssere.filter { !$0.area.passivo }.count) posizioni"),
            IndicatoreProspetto(etichetta: "Debiti residui", valore: euro(r.debiti)),
            IndicatoreProspetto(etichetta: "Patrimonio netto", valore: euro(r.patrimonioNetto)),
            IndicatoreProspetto(etichetta: "Premi e versamenti", valore: euro(r.premiAnnui),
                                nota: "all'anno · \(r.contrattiConPremi) contratti"),
        ]))

        // 01 Canali
        b.append(.sezione(numero: "01", titolo: "Ripartizione per canale"))
        let attive = inEssere.filter { !$0.area.passivo }
        b.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Canale", peso: 2.2), ColonnaProspetto(titolo: "Posizioni", peso: 0.8, destra: true),
                      ColonnaProspetto(titolo: "Valore in essere", destra: true), ColonnaProspetto(titolo: "Quota", peso: 0.7, destra: true),
                      ColonnaProspetto(titolo: "Premi annui", destra: true), ColonnaProspetto(titolo: "Proposte aperte", peso: 0.9, destra: true)],
            righe: Canale.allCases.map { canale -> [CellaProspetto] in
                let del = attive.filter { $0.canale == canale }
                return [.c(canale), .t("\(del.count)"), .t(euro(r.perCanale[canale] ?? 0)), .t(quota(r.quota(canale))),
                        .t(euro(del.reduce(0) { $0 + $1.premioAnnuo })),
                        .t("\(proposte.filter { $0.canale == canale && $0.esito != .accettata && $0.esito != .rifiutata }.count)")]
            },
            totale: [.f("Totale"), .f("\(attive.count)"), .f(euro(r.attivita)), .f("100%"), .f(euro(r.premiAnnui)), .f("\(r.proposteAperte)")]
        )))

        // 02 Aree
        b.append(.sezione(numero: "02", titolo: "Ripartizione per area"))
        let aree = AreaPosizione.allCases.filter { a in inEssere.contains { $0.area == a } }
        b.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Area", peso: 2), ColonnaProspetto(titolo: "Posizioni", peso: 0.8, destra: true),
                      ColonnaProspetto(titolo: "Valore", destra: true), ColonnaProspetto(titolo: "Sulle attività", peso: 0.9, destra: true),
                      ColonnaProspetto(titolo: "Alleanza", destra: true), ColonnaProspetto(titolo: "Indipendente", destra: true)],
            righe: aree.map { a -> [CellaProspetto] in
                let del = inEssere.filter { $0.area == a }
                let valore = r.perArea[a] ?? 0
                let somma: (Canale) -> Double = { c in del.filter { $0.canale == c }.reduce(0) { $0 + $1.valore } }
                let senzaValore = a == .protezione && valore == 0
                return [a.passivo ? .t("\(a.nome) (da sottrarre)") : .t(a.nome), .t("\(del.count)"),
                        senzaValore ? .n("capitali a parte") : .t(euro(valore)),
                        a.passivo || r.attivita <= 0 || senzaValore ? .n("—") : .t(quota(valore / r.attivita)),
                        .t(euro(somma(.alleanza))), .t(euro(somma(.indipendente)))]
            }
        )))

        // 03 Posizioni in essere
        b.append(.sezione(numero: "03", titolo: "Le posizioni in essere"))
        if inEssere.isEmpty {
            b.append(.testo("Nessuna posizione in essere registrata."))
        } else {
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Posizione", peso: 2.6), ColonnaProspetto(titolo: "Canale", peso: 1.1),
                          ColonnaProspetto(titolo: "Area", peso: 1), ColonnaProspetto(titolo: "Valore", peso: 1.05, destra: true),
                          ColonnaProspetto(titolo: "Premi annui", peso: 1, destra: true), ColonnaProspetto(titolo: "Costo annuo", peso: 0.85, destra: true),
                          ColonnaProspetto(titolo: "SRI", peso: 0.45, destra: true), ColonnaProspetto(titolo: "Scadenza", peso: 0.95, destra: true)],
                righe: inEssere.map { p -> [CellaProspetto] in
                    [.f(p.nome), .c(p.canale), .t(p.area.nome),
                     p.area == .protezione && p.valore == 0 ? .n("—") : .t(euro(p.valore)),
                     p.premioAnnuo <= 0 ? .n("—") : p.area.passivo ? .n("rata \(euro(p.premioAnnuo))") : .t(euro(p.premioAnnuo)),
                     p.costoAnnuo.map { CellaProspetto.t(percentuale($0)) } ?? .n("—"),
                     p.sri.map { CellaProspetto.t("\($0)/7") } ?? .n("—"),
                     p.scadenza.map { CellaProspetto.t(Formati.dataBreve.string(from: $0)) } ?? .n("—")]
                }
            )))
        }

        // 04 Coperture
        let coperture = inEssere.filter { $0.area == .protezione }
        if !coperture.isEmpty {
            b.append(.sezione(numero: "04", titolo: "Coperture assicurative"))
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Rischio", peso: 1.4), ColonnaProspetto(titolo: "Posizione", peso: 2),
                          ColonnaProspetto(titolo: "Canale", peso: 1.1), ColonnaProspetto(titolo: "Capitale", destra: true),
                          ColonnaProspetto(titolo: "Premio annuo", peso: 0.95, destra: true),
                          ColonnaProspetto(titolo: "Per 1.000 €", peso: 0.85, destra: true), ColonnaProspetto(titolo: "Scadenza", peso: 0.95, destra: true)],
                righe: coperture.map { p -> [CellaProspetto] in
                    [.t((p.rischio ?? .altro).nome), .f(p.nome), .c(p.canale), .t(euro(p.capitaleAssicurato ?? 0)),
                     .t(euro(p.premioAnnuo)), costoPerMille(p).map { CellaProspetto.t(Formati.euroDecimali($0)) } ?? .n("—"),
                     p.scadenza.map { CellaProspetto.t(Formati.dataBreve.string(from: $0)) } ?? .n("—")]
                },
                totale: [.f("Totale"), .t(""), .t(""), .f(euro(r.capitaleAssicurato)),
                         .f(euro(coperture.reduce(0) { $0 + $1.premioAnnuo })), .t(""), .t("")]
            )))
        }

        // 05 Proposte
        if !proposte.isEmpty {
            b.append(.sezione(numero: coperture.isEmpty ? "04" : "05", titolo: "Proposte"))
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Proposta", peso: 2.4), ColonnaProspetto(titolo: "Canale", peso: 1.1),
                          ColonnaProspetto(titolo: "Area", peso: 1), ColonnaProspetto(titolo: "Iniziale", destra: true),
                          ColonnaProspetto(titolo: "Versamenti annui", peso: 1.1, destra: true),
                          ColonnaProspetto(titolo: "Costo annuo", peso: 0.85, destra: true), ColonnaProspetto(titolo: "Esito", peso: 0.9, destra: true)],
                righe: proposte.map { p -> [CellaProspetto] in
                    [.f(p.nome), .c(p.canale), .t(p.area.nome), .t(euro(p.versamentoIniziale)),
                     p.premioAnnuo > 0 ? .t(euro(p.premioAnnuo)) : .n("—"),
                     p.costoAnnuo.map { CellaProspetto.t(percentuale($0)) } ?? .n("—"), .t((p.esito ?? .bozza).nome)]
                }
            )))
        }

        // Scadenze e obiettivi
        var numero = 4 + (coperture.isEmpty ? 0 : 1) + (proposte.isEmpty ? 0 : 1)
        if !r.inScadenza.isEmpty {
            b.append(.sezione(numero: String(format: "%02d", numero), titolo: "Scadenze entro \(RiepilogoPosizioni.giorniScadenza) giorni"))
            numero += 1
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Posizione", peso: 2.4), ColonnaProspetto(titolo: "Canale", peso: 1.1),
                          ColonnaProspetto(titolo: "Scadenza", destra: true), ColonnaProspetto(titolo: "Giorni", peso: 0.6, destra: true),
                          ColonnaProspetto(titolo: "Valore o capitale", peso: 1.2, destra: true)],
                righe: r.inScadenza.map { p -> [CellaProspetto] in
                    let giorni = p.scadenza.map { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: $0).day ?? 0 } ?? 0
                    return [.f(p.nome), .c(p.canale), .t(p.scadenza.map { Formati.dataBreve.string(from: $0) } ?? "—"),
                            .t(giorni < 0 ? "scaduta" : "\(giorni)"), .t(euro(p.area == .protezione ? (p.capitaleAssicurato ?? 0) : p.valore))]
                }
            )))
        }
        let obiettivi = dati.obiettivi.filter { $0.clienteId == id }.sorted { $0.scadenza < $1.scadenza }
        if !obiettivi.isEmpty {
            b.append(.sezione(numero: String(format: "%02d", numero), titolo: "Obiettivi"))
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Obiettivo", peso: 2.2), ColonnaProspetto(titolo: "Importo", destra: true),
                          ColonnaProspetto(titolo: "Entro il", peso: 0.95, destra: true), ColonnaProspetto(titolo: "Accantonato", destra: true),
                          ColonnaProspetto(titolo: "Raggiunto", peso: 0.8, destra: true), ColonnaProspetto(titolo: "Serve al mese", peso: 1.05, destra: true)],
                righe: obiettivi.map { o -> [CellaProspetto] in
                    let av = AvanzamentoObiettivo(o, posizioni: dati.posizioni)
                    return [.f(o.titolo), .t(euro(o.importo)), .t(Formati.dataBreve.string(from: o.scadenza)), .t(euro(av.accantonato)),
                            .t(quota(av.quota)),
                            av.mancante <= 0 ? .t("raggiunto") : av.versamentoNecessario.map { CellaProspetto.t(euro($0)) } ?? .n("scaduto")]
                }
            )))
        }

        b.append(.nota("Valore delle posizioni: controvalore dichiarato o, se manca, il totale versato. Quote per canale e per area calcolate sulle attività in essere, debiti esclusi. Costo per 1.000 €: premio annuo diviso per il capitale assicurato, per mille. Obiettivi: le posizioni collegate contano come accantonato; il versamento mensile usa il rendimento ipotizzato nell'obiettivo.\n\n" + avvertenza))

        return ContenutoProspetto(occhiello: "Prospetto di dettaglio · quadro delle posizioni",
                                  titolo: "Il quadro delle posizioni",
                                  sottotitolo: "\(inEssere.count) in essere · \(proposte.count) in proposta · Alleanza e indipendente distinti",
                                  cliente: cliente.nome, blocchi: b)
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
        aggiungi("Indicatore di rischio (SRI)", p.sri.map { "\($0) su 7" })
        b.append(.voci(voci))

        // Costi
        if p.area.proiettabile || p.costoAnnuo != nil || p.costoIngresso != nil {
            sezione("Costi e fiscalità")
            let impatto = MotoreProiezione.impattoCosti(par)
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Voce", peso: 2.2), ColonnaProspetto(titolo: "Condizione", peso: 1, destra: true),
                          ColonnaProspetto(titolo: "Si applica a", peso: 2.2), ColonnaProspetto(titolo: "In \(par.anni) anni", peso: 1.1, destra: true)],
                righe: [
                    [.t("Costo d'ingresso"), percentualeOpzionale(p.costoIngresso), .n(p.stato == .inEssere ? "versamenti futuri" : "capitale iniziale e versamenti"),
                     .t(euro(costoIngressoNelPeriodo(par)))],
                    [.t("Costo annuo di gestione"), percentualeOpzionale(p.costoAnnuo), .n("capitale investito, ogni anno, pro quota mensile"),
                     .t(euro(max(0, atteso.costi - costoIngressoNelPeriodo(par))))],
                    [.t("Imposta sulle plusvalenze"), .t(percentuale(par.aliquotaFiscale)), .n("guadagno a fine periodo"), .t(euro(atteso.imposte))],
                ],
                totale: [.f("Costi e imposte, scenario atteso"), .t(""), .t(""), .f(euro(atteso.costi + atteso.imposte))]
            )))
            b.append(.voci([
                CampoVoce(etichetta: "Effetto dei costi sul netto finale", valore: euro(impatto)),
                CampoVoce(etichetta: "Rendimento ipotizzato al netto del costo annuo", valore: percentuale(par.rendimento - par.costoAnnuo)),
                CampoVoce(etichetta: "Costi sul versato totale", valore: atteso.versato > 0 ? percentuale((atteso.costi / atteso.versato * 1000).rounded() / 10) : "—"),
                CampoVoce(etichetta: "Costo del primo anno", valore: euro(primoAnno(par))),
            ]))
        }

        // Proiezione
        if p.area.proiettabile {
            sezione("Proiezione nei tre scenari")
            b.append(.voci([
                CampoVoce(etichetta: "Rendimento annuo atteso", valore: percentuale(par.rendimento)),
                CampoVoce(etichetta: "Prudente e favorevole", valore: "\(percentuale(scenari[0].rendimento)) · \(percentuale(scenari[2].rendimento))"),
                CampoVoce(etichetta: "Inflazione ipotizzata", valore: percentuale(par.inflazione)),
                CampoVoce(etichetta: "Si parte da", valore: euro(par.capitaleIniziale)),
            ]))
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

        b.append(.nota((p.area.proiettabile ? metodoProiezione + "\n\n" : "") + avvertenza))

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
                [.t("Rendimento atteso"), .t(percentuale(pa.rendimento)), .t(percentuale(pb.rendimento))],
                [.t("Costo d'ingresso"), .t(percentuale(pa.costoIngresso)), .t(percentuale(pb.costoIngresso))],
                [.t("Costo annuo"), .t(percentuale(pa.costoAnnuo)), .t(percentuale(pb.costoAnnuo))],
                [.t("Imposta sulle plusvalenze"), .t(percentuale(pa.aliquotaFiscale)), .t(percentuale(pb.aliquotaFiscale))],
            ]
        )))

        bl.append(.sezione(numero: "02", titolo: "Esiti nello scenario atteso"))
        func riga(_ nome: String, _ x: Double, _ y: Double, forte: Bool = false) -> [CellaProspetto] {
            forte ? [.f(nome), .f(euro(x)), .f(euro(y)), .f(segno(y - x))] : [.t(nome), .t(euro(x)), .t(euro(y)), .t(segno(y - x))]
        }
        bl.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Voce", peso: 1.8), ColonnaProspetto(titolo: "A · \(a.titolo)", peso: 1.2, destra: true),
                      ColonnaProspetto(titolo: "B · \(b.titolo)", peso: 1.2, destra: true), ColonnaProspetto(titolo: "Differenza B − A", peso: 1.2, destra: true)],
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

    /// Costi del primo anno: la proiezione su un anno, senza imposte.
    static func primoAnno(_ p: ParametriProiezione) -> Double {
        var q = p
        q.anni = 1
        return MotoreProiezione.calcola(q).costi
    }

    private static func origineOrizzonte(_ p: Posizione, _ orizzonteCliente: Int?) -> String {
        if p.anniAllaScadenza != nil { return "fino alla scadenza" }
        if orizzonteCliente != nil { return "orizzonte del cliente" }
        return "ipotesi predefinita"
    }

    static func ipotesiMancanti(_ p: Posizione, orizzonteCliente: Int?) -> [String] {
        guard p.area.proiettabile else { return [] }
        var m: [String] = []
        if p.rendimentoAtteso == nil { m.append("rendimento atteso \(percentuale(IpotesiCalcolo.rendimentoPredefinito))") }
        if p.aliquotaFiscale == nil { m.append("imposta \(percentuale(IpotesiCalcolo.aliquotaPredefinita))") }
        if p.costoAnnuo == nil { m.append("costo annuo non indicato, calcolato a zero") }
        if p.anniAllaScadenza == nil && orizzonteCliente == nil { m.append("orizzonte di \(IpotesiCalcolo.orizzontePredefinito) anni") }
        return m
    }

    private static func euro(_ v: Double) -> String { Formati.euro(v) }
    private static func percentuale(_ v: Double) -> String { Formati.percentuale(v) }
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
