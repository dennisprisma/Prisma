import SwiftUI

/// Posizioni · Portafoglio: tutti i clienti insieme. Quanto segui e su quale canale, chi pesa di più,
/// cosa scade mese per mese, quanto dipendi da un emittente e come vanno le proposte.
extension AppPosizioni {
    func portafoglio(_ posizioni: [Posizione]) -> some View {
        let p = MotorePortafoglio.calcola(posizioni, clienti: stato.clienti)
        let r = p.riepilogo
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FasciaKPI {
                    KPI(titolo: "Patrimonio seguito", valore: Formati.euro(r.attivita)) {
                        Chip(testo: "\(p.clienti.count) \(p.clienti.count == 1 ? "cliente" : "clienti")")
                        Chip(testo: "Debiti \(Formati.euroBreve(r.debiti))")
                    }
                    KPI(titolo: "Premi e versamenti", valore: Formati.euro(r.premiAnnui)) {
                        Text("all'anno")
                        Chip(testo: "\(r.contrattiConPremi) \(r.contrattiConPremi == 1 ? "contratto" : "contratti")")
                    }
                    KPI(titolo: "Capitale assicurato", valore: Formati.euro(r.capitaleAssicurato)) {
                        Chip(testo: "\(r.coperture) \(r.coperture == 1 ? "copertura" : "coperture")")
                    }
                    KPI(titolo: "Proposte aperte", valore: "\(r.proposteAperte)", ultimo: true) {
                        Text("per \(Formati.euro(r.valoreProposte))")
                        if let t = p.tassoAccettazione { Chip(testo: "accettate \(Formati.percentuale((t * 100).rounded()))") }
                    }
                }

                HStack(alignment: .top, spacing: 24) {
                    PannelloAnalisi(titolo: "Ripartizione per area", nota: "Tutti i clienti, posizioni in essere") { EmptyView() } contenuto: {
                        ripartizione(r)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PannelloAnalisi(titolo: "Per canale", nota: "Attività in essere") { EmptyView() } contenuto: {
                        canali(r)
                    }
                    .frame(width: 330, alignment: .leading)
                }

                PannelloAnalisi(titolo: "Per cliente", nota: "Dal più seguito · tocca una riga per aprire le sue posizioni") { EmptyView() } contenuto: {
                    tabellaClienti(p.clienti)
                }

                HStack(alignment: .top, spacing: 24) {
                    PannelloAnalisi(titolo: "Scadenze dei prossimi \(Portafoglio.mesiScadenze) mesi",
                                    nota: "Capitali da reinvestire e coperture da rinnovare") { EmptyView() } contenuto: {
                        scadenze(p.scadenze)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 18) {
                        PannelloAnalisi(titolo: "Concentrazione per emittente", nota: "Quota delle attività in essere") { EmptyView() } contenuto: {
                            emittenti(p.emittenti)
                        }
                        PannelloAnalisi(titolo: "Proposte", nota: "Per esito") { EmptyView() } contenuto: {
                            esiti(p)
                        }
                    }
                    .frame(width: Misure.Portafoglio.emittenti, alignment: .leading)
                }
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 16, trailing: 12))
        }
    }

    // MARK: - Per cliente

    private func tabellaClienti(_ voci: [Portafoglio.VoceCliente]) -> some View {
        VStack(spacing: 0) {
            rigaPortafoglio(testa: true) {
                testa("Cliente", larghezza: nil)
                testa("Attività", larghezza: Misure.Portafoglio.colonnaImporto, destra: true)
                testa("Premi annui", larghezza: Misure.Portafoglio.colonnaImporto, destra: true)
                testa("Capitale assicurato", larghezza: Misure.Portafoglio.colonnaImporto + 20, destra: true)
                testa("Proposte", larghezza: Misure.Portafoglio.colonnaProposte, destra: true)
                testa("Quota", larghezza: Misure.Portafoglio.colonnaQuota)
            }
            if voci.isEmpty {
                Text("Nessuna posizione con questi filtri.")
                    .font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.kpiNota)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Misure.Analisi.cellaMargine)
            }
            ForEach(Array(voci.enumerated()), id: \.element.id) { i, v in
                Button {
                    stato.clienteAttivoId = v.cliente.id
                    stato.portafoglio = false
                } label: {
                    rigaPortafoglio(testa: false, alternata: i % 2 == 1) {
                        HStack(spacing: 8) {
                            AvatarCliente(iniziali: v.cliente.iniziali, tinta: v.cliente.tinta.colori, lato: Misure.Portafoglio.avatar)
                            Text(v.cliente.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                            ForEach(v.canali) { EtichettaCanale(canale: $0, compatta: true) }
                        }
                        .padding(Misure.Analisi.cellaMargine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        numero(Formati.euro(v.attivita), Misure.Portafoglio.colonnaImporto)
                        numero(v.premiAnnui > 0 ? Formati.euro(v.premiAnnui) : "—", Misure.Portafoglio.colonnaImporto)
                        numero(v.capitaleAssicurato > 0 ? Formati.euro(v.capitaleAssicurato) : "—", Misure.Portafoglio.colonnaImporto + 20)
                        numero(v.proposteAperte > 0 ? "\(v.proposteAperte) · \(Formati.euroBreve(v.valoreProposte))" : "—", Misure.Portafoglio.colonnaProposte)
                        HStack(spacing: 6) {
                            BarraQuotaPortafoglio(quota: v.quota, colore: Colori.Analisi.canale(v.canali.count == 1 ? v.canali.first : nil))
                            Text(Formati.percentuale((v.quota * 100).rounded()))
                                .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).frame(width: 34, alignment: .trailing)
                        }
                        .padding(Misure.Analisi.cellaMargine)
                        .frame(width: Misure.Portafoglio.colonnaQuota)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(StileSemplice())
            }
        }
        .overlay(Rectangle().strokeBorder(Colori.Analisi.tabellaBordo, lineWidth: 1))
    }

    // MARK: - Scadenze

    private func scadenze(_ mesi: [Portafoglio.Mese]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if mesi.isEmpty {
                Text("Nessuna posizione in essere scade nei prossimi \(Portafoglio.mesiScadenze) mesi.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
            }
            ForEach(mesi) { m in
                HStack(alignment: .firstTextBaseline) {
                    Text(Formati.meseAnno.string(from: m.inizio).capitalized)
                        .font(Tipo.tabellaCellaForte).foregroundColor(Colori.Portafoglio.mese)
                    Spacer()
                    Text([m.capitale > 0 ? "\(Formati.euro(m.capitale)) da reinvestire" : nil,
                          m.coperture > 0 ? "\(m.coperture) \(m.coperture == 1 ? "copertura" : "coperture")" : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                }
                .padding(.top, 10)
                .padding(.bottom, 4)
                .bordoBasso(Colori.Analisi.tabellaRiga)
                ForEach(m.posizioni) { pos in
                    Button { stato.apriPosizione(pos) } label: {
                        HStack(spacing: 8) {
                            Text(Formati.giornoMeseBreve.string(from: pos.scadenza ?? m.inizio))
                                .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                                .frame(width: 52, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(pos.nome).font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto)
                                Text(stato.cliente(pos.clienteId)?.nome ?? "").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                            }
                            .lineLimit(1)
                            Spacer()
                            EtichettaCanale(canale: pos.canale, compatta: true)
                            Text(pos.area == .protezione ? "copertura" : Formati.euro(pos.valore))
                                .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                                .frame(width: Misure.Portafoglio.colonnaImporto, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(StileSemplice())
                    .bordoBasso(Colori.Analisi.tabellaRiga)
                }
            }
        }
    }

    // MARK: - Emittenti e proposte

    private func emittenti(_ elenco: [Portafoglio.Emittente]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if elenco.isEmpty {
                Text("Nessuna attività in essere.").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
            }
            ForEach(elenco) { e in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(e.nome).font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                        if let c = e.canale { EtichettaCanale(canale: c, compatta: true) }
                        Spacer()
                        Text(Formati.euro(e.valore)).font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                        Text(Formati.percentuale((e.quota * 100).rounded()))
                            .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).frame(width: 34, alignment: .trailing)
                    }
                    BarraQuotaPortafoglio(quota: e.quota, colore: Colori.Analisi.canale(e.canale))
                }
            }
        }
    }

    private func esiti(_ p: Portafoglio) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(EsitoProposta.allCases) { e in
                    Pillola(testo: "\(e.nome) \(p.esiti[e] ?? 0)",
                            tono: e == .accettata ? .ok : e == .rifiutata ? .errore : e == .presentata ? .attenzione : .neutro)
                }
            }
            Text(p.tassoAccettazione.map { "Accettate \(Formati.percentuale(($0 * 100).rounded())) delle proposte decise." }
                 ?? "Nessuna proposta ancora decisa.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
        }
    }

    // MARK: - Celle

    private func rigaPortafoglio<C: View>(testa: Bool, alternata: Bool = false, @ViewBuilder _ contenuto: () -> C) -> some View {
        HStack(spacing: 0) { contenuto() }
            .frame(maxWidth: .infinity)
            .background(testa ? AnyShapeStyle(Gradienti.testaTabella)
                        : AnyShapeStyle(alternata ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale))
            .overlay(alignment: .top) { if testa { Rectangle().fill(Color.white).frame(height: 1) } }
            .bordoBasso(testa ? Colori.Analisi.tabellaTestaBordo : Colori.Analisi.tabellaRiga)
    }

    private func testa(_ t: String, larghezza: CGFloat?, destra: Bool = false) -> some View {
        Text(t)
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
            .incisione(.white)
            .lineLimit(1)
            .padding(Misure.Analisi.testaMargine)
            .frame(maxWidth: larghezza ?? .infinity, alignment: destra ? .trailing : .leading)
            .frame(width: larghezza)
    }

    private func numero(_ t: String, _ larghezza: CGFloat) -> some View {
        Text(t)
            .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
            .lineLimit(1)
            .padding(Misure.Analisi.cellaMargine)
            .frame(width: larghezza, alignment: .trailing)
    }
}
