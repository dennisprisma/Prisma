import SwiftUI

/// App Prospetti e report (nello spazio Presentazioni del dock).
/// - Valutazione di un investimento: prospetto A4 verticale per il consulente e report A4 orizzontale
///   da lasciare al cliente, sul modello dei documenti di Denis.
/// - Prospetti di dettaglio: il quadro delle posizioni, una posizione o una proposta, un confronto.
/// Le pagine a schermo sono le stesse del PDF.
struct AppProspetti: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) var modoIstantanea
    @State var archiviato: String?

    private var cliente: String { stato.clienteAttivoId }
    private var scelta: SceltaProspetto { stato.sceltaProspetto }

    var body: some View {
        let documento = stato.documentoProspetto(scelta)
        let pagine = documento?.pagine.count ?? 0
        let formato = documento.map { $0.formato.width > $0.formato.height ? "A4 orizzontale" : "A4 verticale" } ?? ""
        return CorniceStrumento(
            notaStato: "Impaginati sul Mac · stessi calcoli dell'app · il PDF resta dove lo salvi",
            notaDestra: pagine == 0 ? "" : "\(formato) · \(pagine) \(pagine == 1 ? "pagina" : "pagine")"
        ) {
            rail
        } contenuto: {
            HStack(spacing: 0) {
                colonnaScelta
                    .frame(width: Misure.Strumenti.ipotesi)
                    .bordoDestro(Colori.Strumenti.ipotesiBordo)
                VStack(spacing: 0) {
                    if let documento {
                        barra(documento)
                        GeometryReader { geo in
                            ScrollView {
                                TavoloDocumento(documento: documento,
                                                scala: min(1, (geo.size.width - 40) / documento.formato.width))
                            }
                        }
                        .background(LinearGradient(colors: [Colori.Carta.tavoloAlto, Colori.Carta.tavoloBasso], startPoint: .top, endPoint: .bottom))
                    } else {
                        vuoto
                    }
                }
            }
        }
        .onChange(of: stato.clienteAttivoId) { _ in archiviato = nil }
        .sheet(item: $stato.valutazioneInModifica) { v in
            ModuloValutazione(bozza: v, nuova: stato.valutazione(v.id) == nil)
                .environmentObject(stato)
        }
    }

    private var vuoto: some View {
        VStack(spacing: 10) {
            Text(scelta.tipo == .valutazione ? "Nessuna valutazione per questo cliente" : "Non c'è ancora niente da impaginare per questo cliente.")
                .font(Tipo.strumentoTitolo).foregroundColor(Colori.Strumenti.titolo)
            if scelta.tipo == .valutazione { pulsanteNuova }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Elenco laterale

    @ViewBuilder private var rail: some View {
        DossierRail()
        EtichettaRail(testo: "Prospetto e report")
        VoceNavigazione(titolo: TipoProspetto.valutazione.nome, attiva: scelta.tipo == .valutazione) { scegli(.valutazione) }
        EtichettaRail(testo: "Prospetti di dettaglio")
        ForEach(TipoProspetto.allCases.filter { $0 != .valutazione }) { t in
            VoceNavigazione(titolo: t.nome, attiva: scelta.tipo == t) { scegli(t) }
        }
        Text(scelta.tipo.descrizione)
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Analisi.kpiNota)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3)
        CollegatiRail(app: [.posizioni, .prodotti, .documenti])
    }

    private func scegli(_ t: TipoProspetto) {
        archiviato = nil
        switch t {
        case .valutazione:
            stato.prospetto = stato.valutazioniCliente(cliente).first.map { .valutazione($0.id, report: false) } ?? .valutazione("", report: false)
        case .quadro:
            stato.prospetto = .quadro
        case .posizione:
            let elenco = posizioniOrdinate
            if let p = elenco.first(where: { $0.stato == .proposta }) ?? elenco.first { stato.prospetto = .posizione(p.id) }
        case .confronto:
            stato.prospetto = stato.confrontoPredefinito()
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
                    case .valutazione(let id, let report): sceltaValutazione(id, report: report)
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
        case .valutazione: return "VALUTAZIONI DEL CLIENTE"
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

    private func sceltaValutazione(_ id: String, report: Bool) -> some View {
        let elenco = stato.valutazioniCliente(cliente)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(elenco) { v in
                Button {
                    archiviato = nil
                    stato.prospetto = .valutazione(v.id, report: report)
                } label: { rigaValutazione(v, attiva: v.id == id) }
                .buttonStyle(StileSemplice())
            }
            VStack(alignment: .leading, spacing: 10) {
                if elenco.contains(where: { $0.id == id }) {
                    SegmentiAnalisi(opzioni: [(false, "Prospetto"), (true, "Report")],
                                    selezione: Binding(get: { report }, set: { stato.prospetto = .valutazione(id, report: $0); archiviato = nil }))
                    Text(report ? "Report per il cliente: A4 orizzontale, una pagina per messaggio, da lasciare al cliente."
                                : "Prospetto per te: A4 verticale, quattro pagine con ogni cifra, da mostrare al cliente.")
                        .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Modifica ipotesi e testi…") { stato.valutazioneInModifica = stato.valutazione(id) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    }
                }
                pulsanteNuova
                if stato.prodottiValutabili.isEmpty {
                    Text("Serve una scheda prodotto con le condizioni del contratto (parti, penali, costi, KID).")
                        .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
    }

    private var pulsanteNuova: some View {
        Button("＋ Nuova valutazione") { stato.valutazioneInModifica = stato.nuovaValutazione() }
            .buttonStyle(StileBlu())
            .disabled(stato.prodottiValutabili.isEmpty)
    }

    private func rigaValutazione(_ v: ValutazioneInvestimento, attiva: Bool) -> some View {
        let p = stato.prodotto(v.prodottoId)
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(p?.nome ?? "Prodotto non trovato").font(Tipo.tabellaCellaForte)
                    .foregroundColor(attiva ? .white : Colori.Analisi.tabellaTesto).lineLimit(1)
                Text("\(Formati.euro(v.premio)) · \(v.intestatari) · \(Formati.dataBreve.string(from: v.data))")
                    .font(Tipo.chip).foregroundColor(attiva ? Color.white.opacity(0.85) : Colori.Analisi.kpiNota).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let p { EtichettaCanale(canale: p.canale, compatta: true) }
        }
        .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(attiva ? AnyShapeStyle(Gradienti.navAnalisi) : AnyShapeStyle(Color.clear))
        .bordoBasso(Colori.Strumenti.ipotesiRiga)
        .contentShape(Rectangle())
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

    private func barra(_ d: DocumentoStampabile) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(d.titolo).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.kpiValore).lineLimit(1)
                Text("\(d.genere) · \(d.cliente)").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
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
            Button("Stampa…") { if let dati = pdf(d) { StampaCarta.stampa(dati, formato: d.formato) } }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
            Button("Archivia nei Documenti") {
                if let dati = pdf(d) { archiviato = stato.archiviaProspetto(dati, documento: d) }
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
            Button("Salva PDF…") { if let dati = pdf(d) { StampaCarta.salva(dati, nome: StampaCarta.nomeFile(d)) } }
                .buttonStyle(StileBlu())
        }
        .padding(EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14))
        .background(Gradienti.kpi)
        .bordoBasso(Colori.Analisi.kpiBordo)
    }

    private func pdf(_ d: DocumentoStampabile) -> Data? {
        guard !modoIstantanea else { return nil }
        let dati = StampaCarta.pdf(d)
        if dati == nil { stato.mostraAvviso("Non sono riuscito a creare il PDF.") }
        return dati
    }
}

/// Le pagine di un documento su un tavolo di lino chiaro, come la sala di lettura dei Documenti del template.
private struct TavoloDocumento: View {
    let documento: DocumentoStampabile
    let scala: CGFloat

    var body: some View {
        VStack(spacing: 22) {
            ForEach(Array(documento.pagine.enumerated()), id: \.offset) { _, pagina in
                pagina
                    .frame(width: documento.formato.width, height: documento.formato.height)
                    .scaleEffect(scala, anchor: .top)
                    .frame(width: documento.formato.width * scala, height: documento.formato.height * scala, alignment: .top)
                    .shadow(color: Colori.Carta.ombraFoglio, radius: 5, x: 0, y: 3)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}
