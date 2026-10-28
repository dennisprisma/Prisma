import SwiftUI

/// Posizioni · Portafoglio: tutti i clienti insieme. Quanto segui e su quale canale, chi pesa di più,
/// cosa scade mese per mese, quanto dipendi da un emittente e come vanno le proposte.
///
/// Non osserva StatoShell: si ridisegna solo quando cambia la chiave (dati dei calcoli, giorno, ora, modalità
/// cliente, filtri, confronto aperto), non a ogni tasto, avviso o cambio di finestra. I numeri vengono dalle
/// cache di DerivatiDati; `stato` serve per leggerle e per le azioni dei pulsanti. Lo scorrimento alle ancore
/// resta in AppPosizioni, che osserva lo stato. Gli elenchi lunghi mostrano le prime righe e «…e altri N»:
/// con centinaia di clienti la pagina resta leggera da costruire e impaginare.
struct CorpoPortafoglio: View, Equatable {
    /// Tutto ciò da cui dipende ciò che il portafoglio mostra.
    struct Chiave: Equatable {
        let vista: ChiaveVista
        let canale: Canale?
        let area: AreaPosizione?
        /// Archivio di una versione più recente: «Fissa» del riesame resta spento.
        let solaLettura: Bool
        /// Il riesame dipende anche dal confronto aperto e dall'orizzonte (DerivatiDati.ChiaveRiesame).
        let prospetto: SceltaProspetto?
        let orizzonte: Int?
    }

    /// Non osservato: dati in cache e azioni.
    let stato: StatoShell
    let chiave: Chiave
    /// L'appuntamento da fissare per un cliente da ricontattare o da riesaminare.
    @Binding var moduloAppuntamento: Appuntamento?
    /// «Mostra tutti» nella tabella dei clienti, oltre `massimoClienti`.
    @State private var tuttiIClienti = false

    nonisolated static func == (a: CorpoPortafoglio, b: CorpoPortafoglio) -> Bool { a.chiave == b.chiave }

    /// Righe al massimo nella tabella «Per cliente» prima di «mostra tutti» (le istantanee ne hanno al più 35).
    static let massimoClienti = 40
    /// Righe al massimo in «Da ricontattare».
    static let massimoRicontatti = 12
    /// Posizioni al massimo, in tutto, nelle scadenze dei 12 mesi (i totali dei mesi restano interi).
    static let massimoScadenze = 24
    /// Posizioni al massimo in «In scadenza» del pannello dei canali (i clienti fittizi ne hanno meno di 10).
    static let massimoInScadenza = 24
    /// Righe al massimo nel calendario dei riesami (il conteggio dei punti legge il dossier di ogni cliente).
    static let massimoRiesami = 10
    /// Righe al massimo in «Da sistemare nei dossier».
    static let massimoAttenzioni = 12

    var body: some View {
        // Chi ricontattare, i riesami, la fine dell'anno e le attenzioni non dipendono dai filtri
        let p = stato.riepilogoPortafoglio(canale: chiave.canale, area: chiave.area)
        let comune = stato.portafoglioComune()
        let r = p.riepilogo
        return VStack(alignment: .leading, spacing: 18) {
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
                    AppPosizioni.ripartizione(r)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PannelloAnalisi(titolo: "Per canale", nota: "Attività in essere") { EmptyView() } contenuto: {
                    AppPosizioni.canali(r, massimo: Self.massimoInScadenza, apri: { stato.posizioneInDettaglio = $0.id })
                }
                .frame(width: 330, alignment: .leading)
            }

            PannelloAnalisi(titolo: "Per cliente", nota: "Dal più seguito · tocca una riga per aprire le sue posizioni") { EmptyView() } contenuto: {
                tabellaClienti(p.clienti)
            }

            // Il calendario delle revisioni: non dipende dai filtri di canale e area
            let dovuti = comune.dovuti
            let fine = comune.fine
            PannelloAnalisi(titolo: "Fine anno \(Calendar.current.component(.year, from: Date()))",
                            nota: "Spazio deducibile ancora libero sui piani di previdenza: i versamenti contano entro il 31 dicembre") { EmptyView() } contenuto: {
                fineAnno(fine)
            }
            let attenzioni = comune.attenzioni
            if !attenzioni.isEmpty {
                PannelloAnalisi(titolo: "Da sistemare nei dossier",
                                nota: "Dalle analisi delle posizioni: beneficiari, tutele, rischio e costi · tocca una riga per aprire il pannello") { EmptyView() } contenuto: {
                    daSistemare(attenzioni)
                }
                .id("attenzioni")
            }
            PannelloAnalisi(titolo: "Riesami annuali",
                            nota: "Scaduti o in arrivo nei prossimi \(MotoreRiesame.mesiAvanti) mesi, senza un incontro in agenda") { EmptyView() } contenuto: {
                riesami(dovuti)
            }

            HStack(alignment: .top, spacing: 24) {
                PannelloAnalisi(titolo: "Scadenze dei prossimi \(Portafoglio.mesiScadenze) mesi",
                                nota: "Capitali da reinvestire e coperture da rinnovare") { EmptyView() } contenuto: {
                    scadenze(p.scadenze)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 18) {
                    PannelloAnalisi(titolo: "Concentrazione per emittente", nota: "Quota delle attività finanziarie in essere (immobili esclusi)") { EmptyView() } contenuto: {
                        emittenti(p.emittenti)
                    }
                    PannelloAnalisi(titolo: "Da ricontattare",
                                    nota: "Nessun contatto da \(Portafoglio.mesiSenzaContatto) mesi e niente in agenda") { EmptyView() } contenuto: {
                        ricontattare(p.daRicontattare)
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

    // MARK: - Per cliente

    private func tabellaClienti(_ voci: [Portafoglio.VoceCliente]) -> some View {
        // Oltre le prime righe la tabella si apre a richiesta: centinaia di righe pesano anche fuori dalla vista
        let mostrate = tuttiIClienti || voci.count <= Self.massimoClienti ? voci : Array(voci.prefix(Self.massimoClienti))
        let nascosti = voci.count - mostrate.count
        return VStack(spacing: 0) {
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
            ForEach(Array(mostrate.enumerated()), id: \.element.id) { i, v in
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
            if nascosti > 0 {
                Button { tuttiIClienti = true } label: {
                    Text("…e altri \(nascosti) \(nascosti == 1 ? "cliente" : "clienti") · mostra tutti")
                        .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                        .padding(Misure.Analisi.cellaMargine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(StileSemplice())
            }
        }
        .contornoTabella()
    }

    // MARK: - Scadenze

    /// I mesi con al più `massimoScadenze` posizioni in tutto: i totali del mese (capitale, coperture) restano
    /// quelli interi. `nascoste`: le posizioni lasciate fuori.
    static func scadenzeMostrate(_ mesi: [Portafoglio.Mese]) -> (mesi: [Portafoglio.Mese], nascoste: Int) {
        var resto = massimoScadenze
        var mostrati: [Portafoglio.Mese] = []
        var nascoste = 0
        for m in mesi {
            let n = min(resto, m.posizioni.count)
            nascoste += m.posizioni.count - n
            if n > 0 {
                mostrati.append(n == m.posizioni.count ? m
                                : Portafoglio.Mese(inizio: m.inizio, posizioni: Array(m.posizioni.prefix(n)),
                                                   capitale: m.capitale, coperture: m.coperture))
            }
            resto -= n
        }
        return (mostrati, nascoste)
    }

    private func scadenze(_ tutti: [Portafoglio.Mese]) -> some View {
        let scelta = Self.scadenzeMostrate(tutti)
        return VStack(alignment: .leading, spacing: 0) {
            if tutti.isEmpty {
                Text("Nessuna posizione in essere scade nei prossimi \(Portafoglio.mesiScadenze) mesi.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
            }
            ForEach(scelta.mesi) { m in
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
                            Text(pos.area == .protezione ? (pos.capitaleAssicurato.map { Formati.euro($0) } ?? "—") : Formati.euro(pos.valore))
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
            if scelta.nascoste > 0 {
                Text("…e altre \(scelta.nascoste) \(scelta.nascoste == 1 ? "posizione" : "posizioni") in scadenza.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).padding(.top, 5)
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

    private func ricontattare(_ elenco: [Portafoglio.DaRicontattare]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if elenco.isEmpty {
                Text("Tutti i clienti hanno un contatto recente o un appuntamento in agenda.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
            }
            ForEach(elenco.prefix(Self.massimoRicontatti)) { r in
                Button { stato.apriCliente(r.cliente.id) } label: {
                    HStack(spacing: 8) {
                        AvatarCliente(iniziali: r.cliente.iniziali, tinta: r.cliente.tinta.colori, lato: Misure.Portafoglio.avatar)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.cliente.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                            Text(r.motivo ?? (r.ultimoContatto == nil ? "mai incontrato in Prisma"
                                              : "ultimo contatto \(r.mesi ?? 0) mesi fa" + (r.riesameScaduto ? " · riesame scaduto" : "")))
                                .font(Tipo.chip).foregroundColor(r.motivo != nil ? Colori.Analisi.attenzioneTesto : Colori.Analisi.kpiNota)
                        }
                        .lineLimit(1)
                        Spacer()
                        Text(r.ultimoContatto.map { Formati.dataBreve.string(from: $0) } ?? "—")
                            .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                        Button("Fissa") { moduloAppuntamento = stato.bozzaRicontatto(r) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)))
                            .fixedSize()
                            .help("Fissa una telefonata in agenda: il cliente esce dall'elenco")
                    }
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StileSemplice())
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
            if elenco.count > Self.massimoRicontatti {
                Text("…e altri \(elenco.count - Self.massimoRicontatti) clienti.").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).padding(.top, 5)
            }
        }
    }

    private func fineAnno(_ elenco: [FineAnno]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if elenco.isEmpty {
                Text("Nessun cliente con spazio deducibile da usare: chi ha un piano di previdenza versa già fino al limite di \(Formati.euro(RegoleFiscali.limiteDeducibilita)).")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
            }
            ForEach(elenco.prefix(Self.massimoRiesami)) { f in
                HStack(spacing: 8) {
                    AvatarCliente(iniziali: f.cliente.iniziali, tinta: f.cliente.tinta.colori, lato: Misure.Portafoglio.avatar)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(f.cliente.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                        Text("versa \(Formati.euro(f.contributi)) l'anno su \(Formati.euro(RegoleFiscali.limiteDeducibilita))"
                             + (f.aliquota.map { " · aliquota \(Formati.percentuale($0))" } ?? " · reddito non indicato"))
                            .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                    }
                    .lineLimit(1)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Formati.euro(f.spazio)) deducibili").font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                        Text(f.reddito == nil ? "risparmio da stimare" : "−\(Formati.euro(f.risparmioPossibile)) di IRPEF")
                            .font(Tipo.chip).foregroundColor(f.reddito == nil ? Colori.Analisi.kpiNota : Colori.Analisi.okTesto)
                    }
                    Button("Piano previdenziale") {
                        stato.clienteAttivoId = f.cliente.id
                        stato.apriProspetto(.previdenza(report: false))
                    }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)))
                    .fixedSize()
                    .help("Apri il piano previdenziale di \(f.cliente.nome): divario, deduzioni e versamento che manca")
                }
                .padding(.vertical, 5)
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
        }
    }

    private func riesami(_ elenco: [RiesameDovuto]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if elenco.isEmpty {
                Text("Nessun riesame da fare nei prossimi \(MotoreRiesame.mesiAvanti) mesi: tutti i clienti sono stati visti nell'ultimo anno o hanno un incontro in agenda.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
            }
            ForEach(elenco.prefix(Self.massimoRiesami)) { d in
                let r = stato.riesameCliente(d.cliente.id)
                let alta = r?.punti.filter { $0.priorita == .alta }.count ?? 0
                HStack(spacing: 8) {
                    AvatarCliente(iniziali: d.cliente.iniziali, tinta: d.cliente.tinta.colori, lato: Misure.Portafoglio.avatar)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.cliente.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                        Text(d.dovutoDal.map { d.scaduto() ? "scaduto dal \(Formati.dataEstesa.string(from: $0))" : "dovuto dal \(Formati.dataEstesa.string(from: $0))" }
                             ?? "mai incontrato in Prisma")
                            .font(Tipo.chip).foregroundColor(d.scaduto() ? Colori.Analisi.attenzioneTesto : Colori.Analisi.kpiNota)
                    }
                    .lineLimit(1)
                    Spacer()
                    if let r {
                        Text("\(r.punti.count) punti")
                            .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                        if alta > 0 { Pillola(testo: "\(alta) alta", tono: .errore) }
                    }
                    Button("Prepara") {
                        stato.clienteAttivoId = d.cliente.id
                        stato.apriProspetto(.riesame)
                    }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)))
                    .fixedSize()
                    .help("Apri il prospetto del riesame di \(d.cliente.nome)")
                    Button("Fissa") { moduloAppuntamento = stato.bozzaRiesame(d.cliente.id) }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)))
                        .fixedSize()
                        .disabled(chiave.solaLettura)
                        .help("Fissa l'incontro di riesame: un'ora, con l'ordine del giorno nelle note")
                }
                .padding(.vertical, 5)
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
            if elenco.count > Self.massimoRiesami {
                Text("…e altri \(elenco.count - Self.massimoRiesami) clienti.").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).padding(.top, 5)
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

    // MARK: - Da sistemare nei dossier

    /// Le cose da sistemare nei dossier, raggruppate per tipo: un clic apre il cliente sul pannello che le spiega.
    private func daSistemare(_ elenco: [Attenzione]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(elenco.prefix(Self.massimoAttenzioni).enumerated()), id: \.element.id) { i, a in
                Button {
                    stato.clienteAttivoId = a.cliente.id
                    stato.portafoglio = false
                    stato.ancoraPosizioni = AppPosizioni.ancora(a)
                } label: {
                    HStack(spacing: 10) {
                        Pillola(testo: a.tipo.nome, tono: a.tipo == .costi ? .neutro : .attenzione)
                            .frame(width: Misure.Portafoglio.colonnaTipo, alignment: .leading)
                        Text(a.cliente.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                            .frame(width: Misure.Portafoglio.colonnaCliente, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.titolo).font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                            Text(a.dettaglio).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Misure.Analisi.cellaMargine)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StileSemplice())
                .background(i % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
            if elenco.count > Self.massimoAttenzioni {
                Text("…e altre \(elenco.count - Self.massimoAttenzioni).").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contornoTabella()
    }

    // MARK: - Celle

    private func rigaPortafoglio<C: View>(testa: Bool, alternata: Bool = false, @ViewBuilder _ contenuto: () -> C) -> some View {
        HStack(spacing: 0) { contenuto() }
            .frame(maxWidth: .infinity)
            .background(testa ? Colori.Analisi.tabellaTestaAlto
                        : (alternata ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale))
            .bordoBasso(testa ? Colori.Analisi.tabellaTestaBordo : Colori.Analisi.tabellaRiga)
    }

    private func testa(_ t: String, larghezza: CGFloat?, destra: Bool = false) -> some View {
        Text(t)
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
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

extension AppPosizioni {
    /// Il pannello del dossier che spiega un'attenzione. Concentrazione e rischio rispetto al profilo
    /// (rischio medio, azioni, crisi del passato) li spiega il pannello «Coerenza con il profilo»; il rischio
    /// della prova sui mercati resta alla prova di resistenza.
    static func ancora(_ a: Attenzione) -> String {
        switch a.tipo {
        case .concentrazione:
            return "coerenza"
        case .rischio:
            let prova = a.titolo.hasPrefix("Rischio oltre il profilo") || a.titolo.hasPrefix("Rischio al limite del profilo")
            return prova ? a.tipo.ancora : "coerenza"
        default:
            return a.tipo.ancora
        }
    }
}
