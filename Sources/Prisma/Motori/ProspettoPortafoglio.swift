import Foundation

/// Il prospetto del portafoglio del consulente (per te, non per i clienti): tutti i clienti
/// insieme, con le stesse cifre della vista Portafoglio di Posizioni.
extension CompositoreProspetti {
    static let titoloPortafoglio = "Il tuo portafoglio"

    static func portafoglio(_ dati: DatiPrisma, data: Date = Date()) -> ContenutoProspetto {
        let p = MotorePortafoglio.calcola(dati.posizioni, clienti: dati.clienti, oggi: data)
        let r = p.riepilogo
        func euro(_ v: Double) -> String { Formati.euro(v) }
        func quota(_ q: Double) -> String { Formati.percentuale((q * 100).rounded()) }
        var b: [BloccoProspetto] = []
        var n = 0
        func sezione(_ titolo: String) {
            n += 1
            b.append(.sezione(numero: String(format: "%02d", n), titolo: titolo))
        }

        b.append(.indicatori([
            IndicatoreProspetto(etichetta: "Patrimonio seguito", valore: euro(r.attivita), nota: "\(p.clienti.count) clienti · debiti \(euro(r.debiti))"),
            IndicatoreProspetto(etichetta: "Premi e versamenti", valore: euro(r.premiAnnui), nota: "all'anno · \(r.contrattiConPremi) contratti"),
            IndicatoreProspetto(etichetta: "Capitale assicurato", valore: euro(r.capitaleAssicurato), nota: "\(r.coperture) coperture"),
            IndicatoreProspetto(etichetta: "Proposte aperte", valore: "\(r.proposteAperte)",
                                nota: "per \(euro(r.valoreProposte))" + (p.tassoAccettazione.map { " · accettate \(quota($0))" } ?? "")),
        ]))

        sezione("Per canale")
        b.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Canale", peso: 2), ColonnaProspetto(titolo: "Attività in essere", peso: 1.4, destra: true),
                      ColonnaProspetto(titolo: "Quota", peso: 0.8, destra: true)],
            righe: Canale.allCases.map { c in [.c(c), .t(euro(r.perCanale[c] ?? 0)), .t(quota(r.quota(c)))] },
            totale: [.f("Totale"), .f(euro(r.attivita)), .f("100%")])))

        sezione("Per area")
        let aree = AreaPosizione.allCases.filter { (r.perArea[$0] ?? 0) > 0 }
        b.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Area", peso: 2), ColonnaProspetto(titolo: "Valore in essere", peso: 1.4, destra: true),
                      ColonnaProspetto(titolo: "Quota delle attività", peso: 1, destra: true)],
            righe: aree.map { a in
                let v = r.perArea[a] ?? 0
                return [.t(a.nome), .t(a.passivo ? "−\(euro(v))" : euro(v)), .n(a.passivo ? "—" : quota(r.attivita > 0 ? v / r.attivita : 0))]
            })))

        sezione("Per cliente")
        b.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Cliente", peso: 2), ColonnaProspetto(titolo: "Canali", peso: 1.5),
                      ColonnaProspetto(titolo: "Attività", peso: 1.2, destra: true), ColonnaProspetto(titolo: "Premi annui", peso: 1.1, destra: true),
                      ColonnaProspetto(titolo: "Capitale assicurato", peso: 1.3, destra: true), ColonnaProspetto(titolo: "Proposte", peso: 0.9, destra: true),
                      ColonnaProspetto(titolo: "Quota", peso: 0.7, destra: true)],
            righe: p.clienti.map { v in
                [.f(v.cliente.nome), .t(v.canali.map(\.nomeBreve).joined(separator: " · ")), .t(euro(v.attivita)),
                 .t(v.premiAnnui > 0 ? euro(v.premiAnnui) : "—"), .t(v.capitaleAssicurato > 0 ? euro(v.capitaleAssicurato) : "—"),
                 .t(v.proposteAperte > 0 ? "\(v.proposteAperte)" : "—"), .t(quota(v.quota))]
            })))

        sezione("Scadenze dei prossimi \(Portafoglio.mesiScadenze) mesi")
        let scadenze = p.scadenze.flatMap { m in m.posizioni.map { (m, $0) } }
        if scadenze.isEmpty {
            b.append(.testo("Nessuna posizione in essere scade nei prossimi \(Portafoglio.mesiScadenze) mesi."))
        } else {
            b.append(.tabella(TabellaProspetto(
                colonne: [ColonnaProspetto(titolo: "Scadenza", peso: 1), ColonnaProspetto(titolo: "Posizione", peso: 2.2),
                          ColonnaProspetto(titolo: "Cliente", peso: 1.6), ColonnaProspetto(titolo: "Canale", peso: 1.1),
                          ColonnaProspetto(titolo: "Valore", peso: 1.1, destra: true)],
                righe: scadenze.map { _, pos in
                    [.t(pos.scadenza.map { Formati.dataBreve.string(from: $0) } ?? "—"), .f(pos.nome),
                     .t(dati.clienti.first { $0.id == pos.clienteId }?.nome ?? ""), .c(pos.canale),
                     pos.area == .protezione ? .n("copertura") : .t(euro(pos.valore))]
                },
                totale: [.f("Da reinvestire"), .t(""), .t(""), .t(""), .f(euro(p.scadenze.reduce(0) { $0 + $1.capitale }))])))
        }

        sezione("Concentrazione per emittente")
        b.append(.testo("Quota delle attività finanziarie in essere (immobili e debiti esclusi): \(euro(p.attivitaFinanziarie)) in tutto."))
        b.append(.tabella(TabellaProspetto(
            colonne: [ColonnaProspetto(titolo: "Emittente", peso: 2.2), ColonnaProspetto(titolo: "Canale", peso: 1.1),
                      ColonnaProspetto(titolo: "Posizioni", peso: 0.8, destra: true), ColonnaProspetto(titolo: "Valore", peso: 1.2, destra: true),
                      ColonnaProspetto(titolo: "Quota", peso: 0.8, destra: true)],
            righe: p.emittenti.map { e in
                [.f(e.nome), e.canale.map { CellaProspetto.c($0) } ?? .n("entrambi"), .t("\(e.posizioni)"), .t(euro(e.valore)), .t(quota(e.quota))]
            })))

        sezione("Proposte per esito")
        b.append(.voci(EsitoProposta.allCases.map { CampoVoce(etichetta: $0.nome, valore: "\(p.esiti[$0] ?? 0)") }
                       + [CampoVoce(etichetta: "Tasso di accettazione", valore: p.tassoAccettazione.map { "\(quota($0)) delle proposte decise" } ?? "nessuna proposta decisa")]))

        b.append(.nota("Metodo: valori delle posizioni in essere come registrati in Posizioni (controvalore o, se manca, versato). Le quote per canale e per cliente sono sulle attività in essere, debiti esclusi; la concentrazione per emittente esclude anche gli immobili. Le scadenze comprendono le posizioni in essere che scadono entro \(Portafoglio.mesiScadenze) mesi: il valore è quello di oggi, prima delle imposte. Il tasso di accettazione conta solo le proposte già decise (accettate o rifiutate). Documento ad uso del consulente, non da consegnare ai clienti."))

        return ContenutoProspetto(occhiello: "Prospetto di dettaglio · Portafoglio del consulente", titolo: titoloPortafoglio,
                                  sottotitolo: "Tutti i clienti · \(dati.impostazioni.nomeUtente) · situazione al \(Formati.dataEstesa.string(from: data))",
                                  cliente: "Tutti i clienti", data: data, blocchi: b)
    }
}
