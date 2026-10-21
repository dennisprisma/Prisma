import SwiftUI

/// App Prospetti e report (nello spazio Presentazioni del dock).
/// Prospetti: per il consulente, verticali e dettagliati, un tema alla volta (il quadro delle
/// posizioni, una posizione o una proposta, un confronto), da mostrare poi al cliente.
/// Report: per il cliente, essenziali e leggibili (fase successiva).
/// Le pagine a schermo sono le stesse del PDF.
struct AppProspetti: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) var modoIstantanea
    @State var archiviato: String?

    private var cliente: String { stato.clienteAttivoId }
    private var scelta: SceltaProspetto { stato.sceltaProspetto }
    private var contenuto: ContenutoProspetto? { stato.contenutoProspetto(scelta) }

    var body: some View {
        let c = contenuto
        let pagine = c.map { ImpaginatoreProspetto.pagine($0).count } ?? 0
        return CorniceStrumento(
            notaStato: "Impaginati sul Mac · A4 verticale · stessi calcoli di Posizioni e Confronti · il PDF resta dove lo salvi",
            notaDestra: pagine == 0 ? "" : "\(pagine) \(pagine == 1 ? "pagina" : "pagine")"
        ) {
            rail
        } contenuto: {
            HStack(spacing: 0) {
                colonnaScelta
                    .frame(width: Misure.Strumenti.ipotesi)
                    .bordoDestro(Colori.Strumenti.ipotesiBordo)
                VStack(spacing: 0) {
                    if let c {
                        barra(c)
                        ScrollView {
                            TavoloCarta(contenuto: c)
                        }
                        .background(LinearGradient(colors: [Colori.Carta.tavoloAlto, Colori.Carta.tavoloBasso], startPoint: .top, endPoint: .bottom))
                    } else {
                        Text("Non c'è ancora niente da impaginare per questo cliente.")
                            .font(Tipo.strumentoTesto).foregroundColor(Colori.Analisi.kpiNota)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onChange(of: stato.clienteAttivoId) { _ in archiviato = nil }
    }

    // MARK: - Elenco laterale

    @ViewBuilder private var rail: some View {
        DossierRail()
        EtichettaRail(testo: "Prospetti · per te")
        ForEach(TipoProspetto.allCases.filter { !$0.perCliente }) { t in
            VoceNavigazione(titolo: t.nome, attiva: scelta.tipo == t) { scegli(t) }
        }
        if !scelta.tipo.perCliente { descrizione }
        EtichettaRail(testo: "Report · per il cliente")
        ForEach(TipoProspetto.allCases.filter(\.perCliente)) { t in
            VoceNavigazione(titolo: t.nome, attiva: scelta.tipo == t) { scegli(t) }
                .disabled(t == .reportProposta && proposte.isEmpty)
        }
        if scelta.tipo.perCliente { descrizione }
        CollegatiRail(app: [.posizioni, .confronti, .documenti])
    }

    private var descrizione: some View {
        Text(scelta.tipo.descrizione)
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Analisi.kpiNota)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3)
    }

    private var proposte: [Posizione] { posizioniOrdinate.filter { $0.stato == .proposta } }

    private func scegli(_ t: TipoProspetto) {
        archiviato = nil
        switch t {
        case .quadro:
            stato.prospetto = .quadro
        case .posizione:
            let elenco = posizioniOrdinate
            if let p = elenco.first(where: { $0.stato == .proposta }) ?? elenco.first { stato.prospetto = .posizione(p.id) }
        case .confronto:
            stato.prospetto = stato.confrontoPredefinito()
        case .reportQuadro:
            stato.prospetto = .reportQuadro
        case .reportProposta:
            if let p = proposte.first { stato.prospetto = .reportProposta(p.id) }
        }
    }

    private var posizioniOrdinate: [Posizione] {
        stato.posizioniCliente(cliente).filter { $0.stato != .chiusa }
            .sorted { ($0.stato == .proposta ? 0 : 1, $0.area.ordine, $0.nome) < ($1.stato == .proposta ? 0 : 1, $1.area.ordine, $1.nome) }
    }

    // MARK: - Colonna della scelta

    @ViewBuilder private var colonnaScelta: some View {
        VStack(spacing: 0) {
            HStack {
                Text(intestazioneColonna).font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
                Spacer()
            }
            .padding(10)
            .background(Gradienti.testaIpotesi)
            .bordoBasso(Colori.Strumenti.ipotesiBordo)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch scelta {
                    case .quadro: sceltaQuadro
                    case .posizione(let id): sceltaPosizione(id)
                    case .confronto(let a, let b): sceltaConfronto(a, b)
                    case .reportQuadro: sceltaReportQuadro
                    case .reportProposta(let id): sceltaReportProposta(id)
                    }
                }
            }
        }
        .background(Gradienti.railAnalisi)
    }

    private var intestazioneColonna: String {
        switch scelta {
        case .quadro: return "CHE COSA CONTIENE"
        case .posizione: return "SCEGLI LA POSIZIONE"
        case .confronto: return "LE DUE VOCI"
        case .reportQuadro: return "PER IL CLIENTE"
        case .reportProposta: return "SCEGLI LA PROPOSTA"
        }
    }

    private var sceltaQuadro: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(["Patrimonio netto, debiti, premi annui", "Ripartizione per canale: Alleanza e indipendente",
                     "Ripartizione per area", "Ogni posizione in essere, con costi, SRI e scadenza",
                     "Coperture: capitali, premi, costo per 1.000 €", "Proposte aperte e loro esito",
                     "Scadenze dei prossimi 90 giorni", "Obiettivi e versamento che serve"], id: \.self) { voce in
                HStack(alignment: .top, spacing: 7) {
                    Text("•").foregroundColor(Colori.Analisi.navBasso)
                    Text(voce).fixedSize(horizontal: false, vertical: true)
                }
                .font(Tipo.strumentoTesto)
                .foregroundColor(Colori.Analisi.tabellaTesto)
            }
            Text("Tutte le cifre vengono dalle Posizioni del cliente: aggiornale lì e il prospetto si ricompone.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .padding(12)
    }

    private var sceltaReportQuadro: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(["Prima dei numeri, ci sei tu: le sue priorità", "Il punto da cui partiamo: patrimonio, risparmi, tutele",
                     "Un nome ai suoi progetti: gli obiettivi con la barra di avanzamento", "Il prossimo incontro",
                     "Il prossimo passo, insieme: attività e proposte aperte"], id: \.self) { voce in
                HStack(alignment: .top, spacing: 7) {
                    Text("•").foregroundColor(Colori.Analisi.navBasso)
                    Text(voce).fixedSize(horizontal: false, vertical: true)
                }
                .font(Tipo.strumentoTesto)
                .foregroundColor(Colori.Analisi.tabellaTesto)
            }
            Text("Niente tabelle fitte: poche cifre grandi e frasi semplici, da lasciare al cliente. Il dettaglio resta nei prospetti.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .padding(12)
    }

    private func sceltaReportProposta(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(proposte) { p in
                Button {
                    archiviato = nil
                    stato.prospetto = .reportProposta(p.id)
                } label: { rigaPosizione(p, attiva: p.id == id) }
                .buttonStyle(StileSemplice())
            }
            Text("Per il dettaglio di costi e anno per anno, usa il prospetto della stessa proposta.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
        }
    }

    private func sceltaPosizione(_ id: String) -> some View {
        let elenco = posizioniOrdinate
        let gruppi: [(String, [Posizione])] = [("IN PROPOSTA", elenco.filter { $0.stato == .proposta }),
                                               ("IN ESSERE", elenco.filter { $0.stato == .inEssere })]
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(gruppi.enumerated()), id: \.offset) { _, gruppo in
                if !gruppo.1.isEmpty {
                    Text(gruppo.0).font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
                        .padding(EdgeInsets(top: 10, leading: 10, bottom: 4, trailing: 10))
                    ForEach(gruppo.1) { p in
                        Button {
                            archiviato = nil
                            stato.prospetto = .posizione(p.id)
                        } label: { rigaPosizione(p, attiva: p.id == id) }
                        .buttonStyle(StileSemplice())
                    }
                }
            }
        }
    }

    private func rigaPosizione(_ p: Posizione, attiva: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.nome).font(Tipo.tabellaCellaForte).foregroundColor(attiva ? .white : Colori.Analisi.tabellaTesto).lineLimit(1)
                Text("\(p.area.nome) · \(Formati.euro(p.stato == .inEssere ? p.valore : p.versamentoIniziale + p.premioAnnuo))")
                    .font(Tipo.chip).foregroundColor(attiva ? Color.white.opacity(0.85) : Colori.Analisi.kpiNota)
            }
            Spacer(minLength: 4)
            EtichettaCanale(canale: p.canale, compatta: true)
        }
        .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(attiva ? AnyShapeStyle(Gradienti.navAnalisi) : AnyShapeStyle(Color.clear))
        .bordoBasso(Colori.Strumenti.ipotesiRiga)
        .contentShape(Rectangle())
    }

    private func sceltaConfronto(_ a: VoceConfronto, _ b: VoceConfronto) -> some View {
        let voci = ElementoConfronto.elenco(stato.dati, cliente: cliente)
        return VStack(alignment: .leading, spacing: 10) {
            sceltaVoce("A", voci: voci, selezione: Binding(get: { a }, set: { stato.prospetto = .confronto($0, b) }))
            sceltaVoce("B", voci: voci, selezione: Binding(get: { b }, set: { stato.prospetto = .confronto(a, $0) }))
            Toggle("Stesso orizzonte per entrambe", isOn: Binding(
                get: { stato.orizzonteConfronto != nil },
                set: { attivo in
                    let anni = voci.filter { $0.voce == a || $0.voce == b }.map(\.parametri.anni).max() ?? IpotesiCalcolo.orizzontePredefinito
                    stato.orizzonteConfronto = attivo ? anni : nil
                }))
                .font(Tipo.strumentoTesto)
            if let anni = stato.orizzonteConfronto {
                Stepper(value: Binding(get: { anni }, set: { stato.orizzonteConfronto = min(max($0, 1), 50) }), in: 1...50) {
                    Text("\(anni) \(anni == 1 ? "anno" : "anni")").font(Tipo.strumentoTesto)
                }
            }
            Text("Le stesse scelte valgono in Confronti: il prospetto riporta ciò che vedi lì, con il dettaglio anno per anno.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
    }

    private func sceltaVoce(_ lettera: String, voci: [ElementoConfronto], selezione: Binding<VoceConfronto>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VOCE \(lettera)").font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
            Picker("", selection: selezione) {
                ForEach(voci) { v in Text("\(v.titolo) · \(v.sottotitolo)").tag(v.voce) }
            }
            .labelsHidden()
        }
    }

    // MARK: - Barra delle azioni

    private func barra(_ c: ContenutoProspetto) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(c.titolo).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.kpiValore).lineLimit(1)
                Text(c.occhiello).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
            }
            Spacer()
            if let id = archiviato {
                Button("Archiviato in Documenti ↗") {
                    stato.documentoSelezionato = id
                    stato.apri(.documenti)
                }
                .buttonStyle(StileSemplice())
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Colonna.collegamento)
            }
            Button("Stampa…") { if let d = pdf(c) { StampaCarta.stampa(d) } }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
            Button("Archivia nei Documenti") {
                if let d = pdf(c) { archiviato = stato.archiviaProspetto(d, contenuto: c, tipo: c.perCliente ? .report : .prospetto) }
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
            Button("Salva PDF…") { if let d = pdf(c) { StampaCarta.salva(d, nome: StampaCarta.nomeFile(c)) } }
                .buttonStyle(StileBlu())
        }
        .padding(EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14))
        .background(Gradienti.kpi)
        .bordoBasso(Colori.Analisi.kpiBordo)
    }

    private func pdf(_ c: ContenutoProspetto) -> Data? {
        guard !modoIstantanea else { return nil }
        let d = StampaCarta.pdf(c)
        if d == nil { stato.mostraAvviso("Non sono riuscito a creare il PDF.") }
        return d
    }
}
