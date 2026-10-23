import SwiftUI

/// App Posizioni, il cuore di Prisma: le posizioni del cliente in essere e in proposta,
/// sempre divise per canale, con riepilogo, ripartizioni e dettaglio con proiezione.
struct AppPosizioni: View {
    enum FiltroStato: Hashable { case inEssere, proposte, tutte }

    @EnvironmentObject var stato: StatoShell
    @State var filtroStato: FiltroStato = .inEssere
    @State var filtroCanale: Canale?
    @State var area: AreaPosizione?
    @State var sceltaCliente = false
    @State var modulo: Posizione?

    static let opzioniCanale: [(Canale?, String)] = [(nil, "Tutti"), (.alleanza, "Alleanza"), (.indipendente, "Indip.")]

    /// Le posizioni del cliente attivo, o di tutti i clienti nella vista Portafoglio.
    private var delCliente: [Posizione] {
        (stato.portafoglio ? stato.posizioni : stato.posizioniCliente(stato.clienteAttivoId))
            .filter { filtroCanale == nil || $0.canale == filtroCanale }
    }

    private var perStato: [Posizione] {
        delCliente.filter {
            switch filtroStato {
            case .inEssere: return $0.stato == .inEssere
            case .proposte: return $0.stato == .proposta
            case .tutte: return true
            }
        }
    }

    private var elenco: [Posizione] {
        let ordine = AreaPosizione.allCases
        return perStato
            .filter { area == nil || $0.area == area }
            .sorted {
                let a = ordine.firstIndex(of: $0.area) ?? 0
                let b = ordine.firstIndex(of: $1.area) ?? 0
                return a != b ? a < b : $0.valore > $1.valore
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                rail
                    .frame(width: Misure.Analisi.rail)
                    .bordoDestro(Colori.Analisi.kpiBordo)
                Group {
                    if let id = stato.posizioneInDettaglio, let p = stato.posizioni.first(where: { $0.id == id }) {
                        DettaglioPosizione(posizione: p, modifica: { modulo = p })
                    } else if stato.portafoglio {
                        // Come nel dossier: gli indicatori contano in essere e proposte, lo stato filtra solo l'elenco
                        portafoglio(delCliente.filter { area == nil || $0.area == area })
                    } else {
                        principale
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Colori.Analisi.principale)
            }
            barraStato
        }
        .overlay(Rectangle().strokeBorder(Colori.Analisi.kpiBordo, lineWidth: 1))
        .sheet(item: $modulo) { p in
            ModuloPosizione(bozza: p, nuova: !stato.posizioni.contains { $0.id == p.id }) { stato.salvaPosizione($0) }
        }
        .onAppear { controllaRichiesta(stato.richiestaNuovaPosizione) }
        .onChange(of: stato.richiestaNuovaPosizione) { controllaRichiesta($0) }
        .onChange(of: stato.clienteAttivoId) { _ in stato.posizioneInDettaglio = nil }
        .onChange(of: stato.portafoglio) { _ in stato.posizioneInDettaglio = nil }
    }

    private func controllaRichiesta(_ richiesta: StatoPosizione?) {
        guard let richiesta else { return }
        stato.richiestaNuovaPosizione = nil
        // Una posizione nuova è sempre di un cliente: si torna al suo dossier
        stato.portafoglio = false
        let canale = filtroCanale ?? stato.clienteAttivo?.canali.first ?? .alleanza
        var p = Posizione(clienteId: stato.clienteAttivoId, canale: canale, stato: richiesta, area: area ?? .investimento, nome: "")
        if richiesta == .proposta { p.esito = .bozza }
        modulo = p
    }

    // MARK: - Elenco laterale

    private var rail: some View {
        VStack(alignment: .leading, spacing: 6) {
            SegmentiAnalisi(opzioni: [(false, "Cliente"), (true, "Portafoglio")], selezione: $stato.portafoglio)
                .padding(.top, 2)
            if stato.portafoglio {
                VStack(alignment: .leading, spacing: 2) {
                    Text("IL TUO PORTAFOGLIO").font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
                    Text("Tutti i clienti").font(Tipo.railTitolo).foregroundColor(Colori.Analisi.railTesto)
                    Text("\(stato.clienti.count) \(stato.clienti.count == 1 ? "cliente" : "clienti") in rubrica").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                }
                .incisione(.white)
                .padding(EdgeInsets(top: 9, leading: 2, bottom: 9, trailing: 2))
                .frame(maxWidth: .infinity, alignment: .leading)
                .bordoBasso(Colori.Analisi.railFilo)
            } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("DOSSIER DI").font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
                Button {
                    sceltaCliente = true
                } label: {
                    HStack(spacing: 5) {
                        Text(stato.clienteAttivo?.nome ?? "Nessun cliente").font(Tipo.railTitolo)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Colori.Analisi.railTesto)
                }
                .buttonStyle(StileSemplice())
                .popover(isPresented: $sceltaCliente, arrowEdge: .trailing) { ElencoClienti(aperto: $sceltaCliente) }
                Text(stato.clienteAttivo?.tema ?? "").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
            }
            .incisione(.white)
            .padding(EdgeInsets(top: 9, leading: 2, bottom: 9, trailing: 2))
            .frame(maxWidth: .infinity, alignment: .leading)
            .bordoBasso(Colori.Analisi.railFilo)
            }

            EtichettaRail(testo: "Stato")
            SegmentiAnalisi(opzioni: [(FiltroStato.inEssere, "In essere"), (.proposte, "Proposte"), (.tutte, "Tutte")],
                            selezione: $filtroStato)
            EtichettaRail(testo: "Canale")
            SegmentiAnalisi(opzioni: Self.opzioniCanale, selezione: $filtroCanale)
            EtichettaRail(testo: "Aree")
            VStack(spacing: 0) {
                VoceNavigazione(titolo: "Tutte le aree", conteggio: perStato.count, attiva: area == nil) { area = nil }
                ForEach(AreaPosizione.allCases) { a in
                    VoceNavigazione(titolo: a.nome, colore: Colori.Analisi.area(a),
                                    conteggio: perStato.filter { $0.area == a }.count, attiva: area == a) {
                        area = a
                        stato.posizioneInDettaglio = nil
                    }
                }
            }
            EtichettaRail(testo: "Collegati")
            VStack(spacing: 0) {
                ForEach([AppPrisma.analisi360, .simulazioni, .confronti, .prodotti]) { app in
                    VoceNavigazione(titolo: app.titolo, attiva: false) { stato.apri(app) }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                SimboloLucchetto()
                    .stroke(Colori.Analisi.railEtichetta, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 15, height: 15)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ARCHIVIO LOCALE").font(Tipo.chip).foregroundColor(Colori.Analisi.railEtichetta)
                    Text("Solo su questo Mac").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.railTesto)
                }
            }
            .incisione(.white)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bordoAlto(Colori.Analisi.railFilo)
        }
        .padding(Misure.Analisi.margineRail)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Gradienti.railAnalisi)
    }

    // MARK: - Pannello principale

    private var principale: some View {
        let r = RiepilogoPosizioni(delCliente)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FasciaKPI {
                    KPI(titolo: "Patrimonio netto", valore: Formati.euro(r.patrimonioNetto)) {
                        Chip(testo: "Attività \(Formati.euroBreve(r.attivita))")
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
                    }
                }

                HStack(alignment: .top, spacing: 24) {
                    PannelloAnalisi(titolo: "Ripartizione per area", nota: "Posizioni in essere, debiti a parte") { EmptyView() } contenuto: {
                        ripartizione(r)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PannelloAnalisi(titolo: "Per canale", nota: "Attività in essere") { EmptyView() } contenuto: {
                        canali(r)
                    }
                    .frame(width: 330, alignment: .leading)
                }

                PannelloAnalisi(titolo: titoloTabella, nota: "Tocca una riga per il dettaglio e la proiezione") {
                    if let area { Chip(testo: area.nome) }
                } contenuto: {
                    TabellaPosizioni(posizioni: elenco) { stato.posizioneInDettaglio = $0.id }
                }
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 16, trailing: 12))
        }
    }

    private var titoloTabella: String {
        switch filtroStato {
        case .inEssere: return "Posizioni in essere"
        case .proposte: return "Proposte"
        case .tutte: return "Tutte le posizioni"
        }
    }

    func ripartizione(_ r: RiepilogoPosizioni) -> some View {
        let aree = AreaPosizione.allCases.filter { !$0.passivo && (r.perArea[$0] ?? 0) > 0 }
        return HStack(alignment: .center, spacing: 22) {
            GraficoAnello(
                fette: aree.map { .init(id: $0.rawValue, valore: r.perArea[$0] ?? 0, colore: Colori.Analisi.area($0)) },
                etichettaCentro: "Attività",
                valoreCentro: Formati.euroBreve(r.attivita)
            )
            VStack(spacing: 0) {
                if aree.isEmpty {
                    Text("Nessuna posizione in essere.").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                }
                ForEach(aree) { a in
                    let v = r.perArea[a] ?? 0
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(Colori.Analisi.area(a)).frame(width: 10, height: 10)
                        Text(a.nome).font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto)
                        Spacer()
                        Text(Formati.euro(v)).font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                        Text(Formati.percentuale(r.attivita > 0 ? (v / r.attivita * 100).rounded() : 0))
                            .font(Tipo.chip)
                            .foregroundColor(Colori.Analisi.kpiNota)
                            .frame(width: 34, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    .bordoBasso(Colori.Analisi.tabellaRiga)
                }
                if r.debiti > 0 {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(Colori.Analisi.area(.debiti)).frame(width: 10, height: 10)
                        Text("Debiti").font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto)
                        Spacer()
                        Text("−\(Formati.euro(r.debiti))").font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.erroreTesto)
                        Spacer().frame(width: 34)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    func canali(_ r: RiepilogoPosizioni) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BarraCanali(quotaAlleanza: r.quota(.alleanza))
            ForEach(Canale.allCases) { c in
                HStack {
                    EtichettaCanale(canale: c, compatta: true)
                    Spacer()
                    Text(Formati.euro(r.perCanale[c] ?? 0)).font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                    Text(Formati.percentuale((r.quota(c) * 100).rounded()))
                        .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).frame(width: 34, alignment: .trailing)
                }
            }
            if !r.inScadenza.isEmpty {
                Text("IN SCADENZA ENTRO \(RiepilogoPosizioni.giorniScadenza) GIORNI")
                    .font(Tipo.railEtichetta)
                    .foregroundColor(Colori.Analisi.attenzioneTesto)
                    .padding(.top, 6)
                ForEach(r.inScadenza) { p in
                    Button { stato.posizioneInDettaglio = p.id } label: {
                        HStack {
                            Text(p.nome).font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                            Spacer()
                            PillolaStato(posizione: p)
                        }
                    }
                    .buttonStyle(StileSemplice())
                }
            }
        }
    }

    // MARK: - Barra di stato

    private var barraStato: some View {
        HStack(spacing: 10) {
            Circle().fill(Colori.Analisi.statoLuce).frame(width: 8, height: 8)
            Text("Calcoli eseguiti in locale · ipotesi: inflazione \(Formati.percentuale(IpotesiCalcolo.inflazione)), rendimenti dichiarati per ogni posizione")
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.kpiNota)
            Spacer()
            Text("\(stato.posizioniCliente(stato.clienteAttivoId).count) posizioni del cliente")
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.kpiNota)
        }
        .incisione(.white)
        .padding(.horizontal, 12)
        .frame(height: Misure.Analisi.barraStato)
        .background(Gradienti.barraStato)
        .bordoAlto(Colori.Analisi.statoBordo)
    }
}

// MARK: - Tabella

struct TabellaPosizioni: View {
    let posizioni: [Posizione]
    let apri: (Posizione) -> Void

    var body: some View {
        VStack(spacing: 0) {
            riga(testa: true) {
                cella("Posizione", larghezza: nil)
                cella("Canale", larghezza: 130)
                cella("Area", larghezza: 116)
                cella("Stato", larghezza: 130)
                cella("Valore", larghezza: 110, destra: true)
                cella("Premi / rate annui", larghezza: 120, destra: true)
                cella("Scadenza", larghezza: 96, destra: true)
            }
            if posizioni.isEmpty {
                Text("Nessuna posizione con questi filtri.")
                    .font(Tipo.tabellaCella)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Misure.Analisi.cellaMargine)
            }
            ForEach(Array(posizioni.enumerated()), id: \.element.id) { i, p in
                Button { apri(p) } label: {
                    riga(testa: false, alternata: i % 2 == 1) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.nome.isEmpty ? "Senza nome" : p.nome)
                                .font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                            Text([p.tipologia, p.emittente].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                        }
                        .lineLimit(1)
                        .padding(Misure.Analisi.cellaMargine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        EtichettaCanale(canale: p.canale, compatta: true)
                            .padding(Misure.Analisi.cellaMargine)
                            .frame(width: 130, alignment: .leading)
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(Colori.Analisi.area(p.area)).frame(width: 8, height: 8)
                            Text(p.area.nome).font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(Misure.Analisi.cellaMargine)
                        .frame(width: 116, alignment: .leading)
                        PillolaStato(posizione: p)
                            .padding(Misure.Analisi.cellaMargine)
                            .frame(width: 130, alignment: .leading)
                        valore(p)
                            .padding(Misure.Analisi.cellaMargine)
                            .frame(width: 110, alignment: .trailing)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(p.premioAnnuo > 0 ? Formati.euro(p.premioAnnuo) : "—")
                                .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                            if p.area.passivo, p.premioAnnuo > 0 {
                                Text("rate").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                            }
                        }
                        .padding(Misure.Analisi.cellaMargine)
                        .frame(width: 120, alignment: .trailing)
                        Text(p.scadenza.map { Formati.dataBreve.string(from: $0) } ?? "—")
                            .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                            .padding(Misure.Analisi.cellaMargine)
                            .frame(width: 96, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(StileSemplice())
            }
        }
        .overlay(Rectangle().strokeBorder(Colori.Analisi.tabellaBordo, lineWidth: 1))
    }

    @ViewBuilder private func valore(_ p: Posizione) -> some View {
        switch p.area {
        case .protezione:
            VStack(alignment: .trailing, spacing: 1) {
                Text(Formati.euro(p.capitaleAssicurato ?? 0)).font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                Text("capitale").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
            }
        case .debiti:
            Text("−\(Formati.euro(p.valore))").font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.erroreTesto)
        default:
            Text(p.stato == .proposta ? Formati.euro(p.versamentoIniziale) : Formati.euro(p.valore))
                .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
        }
    }

    private func riga<C: View>(testa: Bool, alternata: Bool = false, @ViewBuilder _ contenuto: () -> C) -> some View {
        HStack(spacing: 0) { contenuto() }
            .frame(maxWidth: .infinity)
            .background(testa ? AnyShapeStyle(Gradienti.testaTabella)
                        : AnyShapeStyle(alternata ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale))
            .overlay(alignment: .top) { if testa { Rectangle().fill(Color.white).frame(height: 1) } }
            .bordoBasso(testa ? Colori.Analisi.tabellaTestaBordo : Colori.Analisi.tabellaRiga)
    }

    private func cella(_ t: String, larghezza: CGFloat?, destra: Bool = false) -> some View {
        Text(t)
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
            .incisione(.white)
            .padding(Misure.Analisi.testaMargine)
            .frame(width: larghezza, alignment: destra ? .trailing : .leading)
            .frame(maxWidth: larghezza == nil ? .infinity : larghezza, alignment: destra ? .trailing : .leading)
    }
}

/// Pillola di stato di una posizione.
struct PillolaStato: View {
    let posizione: Posizione

    var body: some View {
        let p = posizione
        switch p.stato {
        case .proposta:
            Pillola(testo: "Proposta · \(p.esito?.nome ?? "Bozza")", tono: p.esito == .rifiutata ? .errore : .neutro)
        case .chiusa:
            Pillola(testo: "Chiusa", tono: .neutro)
        case .inEssere:
            if p.scaduta {
                Pillola(testo: "Scaduta", tono: .errore)
            } else if p.scadeEntro(RiepilogoPosizioni.giorniScadenza), let s = p.scadenza {
                let giorni = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: s).day ?? 0
                Pillola(testo: "Scade tra \(giorni) gg", tono: .attenzione)
            } else {
                Pillola(testo: "In essere", tono: .ok)
            }
        }
    }
}

extension View {
    /// Bordo destro di un solo lato.
    func bordoDestro(_ colore: Color, spessore: CGFloat = 1) -> some View {
        overlay(alignment: .trailing) {
            Rectangle().fill(colore).frame(width: spessore).allowsHitTesting(false)
        }
    }
}
