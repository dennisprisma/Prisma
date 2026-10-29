import SwiftUI

/// Il campo della griglia con il fuoco: valore, data o versato di una posizione.
enum CampoGrigliaValori: Hashable {
    case valore(String), data(String), versato(String)
}

/// Il pannello «Aggiorna i valori» in Posizioni (specifica 8): l'elenco della compagnia o la griglia dei valori
/// fermi, poi il riepilogo. È una vista dentro la finestra (non un foglio), così le istantanee la fotografano.
/// Lo stato locale sta qui: le battute nelle caselle non pubblicano StatoShell.
struct PannelloAggiornaValori: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) private var modoIstantanea
    let sessione: AggiornaValori.Sessione

    @State private var scheda: AggiornaValori.Scheda
    @State private var dataComune: Date
    @State private var avviato = false
    // Elenco della compagnia
    @State private var scelte: [Int: String] = [:]
    @State private var esclusi: Set<Int> = []
    @State private var soloDaControllare = false
    @State private var esitiElenco: [AggiornaValori.Esito] = []
    @State private var anteprimaElenco = AggiornaValori.Riepilogo()
    @State private var perId: [String: Posizione] = [:]
    // Griglia dei valori fermi
    @State private var bozze: [String: AggiornaValori.Bozza]
    @State private var ambito: String?
    @State private var canale: Canale?
    @State private var elencoGriglia: [Posizione] = []
    @State private var esitiGriglia: [AggiornaValori.Esito] = []
    @FocusState private var fuoco: CampoGrigliaValori?

    init(sessione: AggiornaValori.Sessione) {
        self.sessione = sessione
        _scheda = State(initialValue: sessione.scheda)
        _dataComune = State(initialValue: sessione.dataComune)
        _bozze = State(initialValue: sessione.bozze)
        _ambito = State(initialValue: sessione.soloCliente)
        _canale = State(initialValue: sessione.canale)
        _scelte = State(initialValue: sessione.scelte)
    }

    private var m: Tema.Misura.AggiornaValori.Type { Tema.Misura.AggiornaValori.self }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            testata
                .padding(m.margine)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: m.spazioSezioni) {
                        if let r = sessione.riepilogo {
                            riepilogo(r)
                        } else if scheda == .elenco {
                            corpoElenco
                        } else {
                            corpoGriglia(proxy)
                        }
                    }
                    .padding(m.margine)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            piede
                .padding(m.margine)
                .overlay(alignment: .top) {
                    Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
                }
        }
        .onAppear(perform: avvia)
        .onDisappear(perform: conserva)
        .onChange(of: sessione.scheda) { scheda = $0 }
        .onChange(of: scheda) { nuova in
            if stato.aggiornaValori?.id == sessione.id, stato.aggiornaValori?.scheda != nuova {
                stato.aggiornaValori?.scheda = nuova
            }
        }
        .onChange(of: scelte) { _ in ricalcolaElenco() }
        .onChange(of: esclusi) { _ in ricalcolaElenco() }
        .onChange(of: dataComune) { _ in
            ricalcolaElenco()
            ricalcolaGriglia()
        }
        .onChange(of: bozze) { _ in ricalcolaGriglia() }
        .onChange(of: ambito) { _ in aggiornaElencoGriglia() }
        .onChange(of: canale) { _ in aggiornaElencoGriglia() }
    }

    // MARK: - Calcoli (solo quando cambia qualcosa)

    private func avvia() {
        guard !avviato else { return }
        avviato = true
        let iniziali = AggiornaValori.esiti(sessione.righe, posizioni: stato.posizioni, clienti: stato.clienti,
                                            dataComune: dataComune, oggi: Date(), scelte: scelte)
        esclusi = sessione.esclusi ?? AggiornaValori.esclusiIniziali(iniziali)
        ricalcolaElenco()
        aggiornaElencoGriglia()
        if !modoIstantanea, scheda == .griglia, sessione.riepilogo == nil, let primo = elencoGriglia.first {
            DispatchQueue.main.async { fuoco = .valore(primo.id) }
        }
    }

    /// Le scelte restano nella sessione quando il dettaglio di una posizione copre il pannello.
    private func conserva() {
        // Tutto letto adesso, mentre la vista c'è ancora; scritto dopo, fuori dall'aggiornamento della vista
        let s = stato
        let id = sessione.id
        let fatte = self.scelte, fuori = self.esclusi, caselle = self.bozze, cliente = self.ambito, scelto = self.canale
        let data = self.dataComune
        DispatchQueue.main.async {
            guard s.aggiornaValori?.id == id else { return }
            s.aggiornaValori?.scelte = fatte
            s.aggiornaValori?.esclusi = fuori
            s.aggiornaValori?.bozze = caselle
            s.aggiornaValori?.soloCliente = cliente
            s.aggiornaValori?.canale = scelto
            s.aggiornaValori?.dataComune = data
        }
    }

    private func ricalcolaElenco() {
        guard !sessione.righe.isEmpty else {
            esitiElenco = []
            anteprimaElenco = AggiornaValori.Riepilogo()
            return
        }
        let posizioni = stato.posizioni
        let esiti = AggiornaValori.esiti(sessione.righe, posizioni: posizioni, clienti: stato.clienti, dataComune: dataComune,
                                         oggi: Date(), scelte: scelte, esclusi: esclusi)
        esitiElenco = esiti
        anteprimaElenco = AggiornaValori.anteprima(esiti, esclusi: esclusi, posizioni: posizioni)
        let abbinate: [String] = esiti.compactMap { $0.posizioneId }
        let candidate: [String] = esiti.flatMap { $0.candidate }
        let servono = Set(abbinate + candidate)
        var indice: [String: Posizione] = [:]
        for p in posizioni where servono.contains(p.id) && indice[p.id] == nil { indice[p.id] = p }
        perId = indice
    }

    /// L'elenco della griglia è stabile: si calcola all'apertura, ai filtri e dopo «Continua», non a ogni battuta.
    private func aggiornaElencoGriglia() {
        elencoGriglia = AggiornaValori.valoriFermi(posizioni: stato.posizioni, clienti: stato.clienti, oggi: Date(),
                                                   clienteId: ambito, canale: canale)
        ricalcolaGriglia()
    }

    private func ricalcolaGriglia() {
        let righe = AggiornaValori.righe(bozze: bozze, elenco: elencoGriglia)
        esitiGriglia = righe.isEmpty ? [] : AggiornaValori.esiti(righe, posizioni: stato.posizioni, clienti: stato.clienti,
                                                                 dataComune: dataComune, oggi: Date())
    }

    /// Nella griglia un valore a zero non si registra mai da qui: si chiude dalla scheda della posizione.
    private var esclusiGriglia: Set<Int> { AggiornaValori.esclusiIniziali(esitiGriglia) }

    private var nomiClienti: [String: String] {
        var nomi: [String: String] = [:]
        for c in stato.clienti where nomi[c.id] == nil { nomi[c.id] = c.nome }
        return nomi
    }

    private var daRegistrare: Int {
        scheda == .elenco ? AggiornaValori.daRegistrare(esitiElenco, esclusi: esclusi)
                          : AggiornaValori.daRegistrare(esitiGriglia, esclusi: esclusiGriglia)
    }

    private func registra() {
        guard daRegistrare > 0, !stato.solaLettura else { return }
        if scheda == .elenco {
            stato.registraValoriInBlocco(esitiElenco, esclusi: esclusi)
        } else {
            stato.registraValoriInBlocco(esitiGriglia, esclusi: esclusiGriglia)
        }
    }

    /// Dopo il riepilogo: di nuovo la scheda, con i conti rifatti sulle posizioni aggiornate.
    private func continua() {
        stato.aggiornaValori?.riepilogo = nil
        bozze = [:]
        aggiornaElencoGriglia()
        ricalcolaElenco()
    }

    // MARK: - Testata e piede

    private var testata: some View {
        HStack(alignment: .center, spacing: m.spazioComandi) {
            TitoloStrumento(occhiello: TestiAggiornaValori.occhiello, titolo: TestiAggiornaValori.titolo)
            Spacer(minLength: m.spazioComandi)
            if sessione.riepilogo == nil {
                SegmentiAnalisi(opzioni: AggiornaValori.Scheda.allCases.map { ($0, TestiAggiornaValori.nomeScheda($0)) },
                                selezione: $scheda)
                    .frame(width: m.segmenti)
            }
            Button(TestiAggiornaValori.chiudi) { stato.aggiornaValori = nil }
                .buttonStyle(StileVetro(margine: m.marginePulsante))
                .keyboardShortcut(.cancelAction)
        }
    }

    private var piede: some View {
        HStack(spacing: m.spazioComandi) {
            if sessione.riepilogo != nil {
                Spacer()
                Button(TestiAggiornaValori.continua, action: continua)
                    .buttonStyle(StileBlu())
                    .keyboardShortcut(.defaultAction)
            } else {
                Text(TestiAggiornaValori.notaBackup)
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                Spacer(minLength: m.spazioComandi)
                if scheda == .elenco {
                    let nonTrovate = esitiElenco.filter { $0.stato == .nonTrovata }.map(\.id)
                    if !nonTrovate.isEmpty && !sessione.tabella.isEmpty {
                        Button(TestiAggiornaValori.pulsanteNonTrovate(nonTrovate.count)) {
                            stato.importaComeNuove(soloRighe: Set(nonTrovate))
                        }
                        .buttonStyle(StileVetro(margine: m.marginePulsante))
                        .disabled(stato.solaLettura)
                    }
                }
                let n = daRegistrare
                Button(TestiAggiornaValori.registra(n), action: registra)
                    .buttonStyle(StileBlu())
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(n == 0 || stato.solaLettura)
            }
        }
    }

    // MARK: - Scheda «Da un elenco della compagnia»

    @ViewBuilder private var corpoElenco: some View {
        if sessione.righe.isEmpty {
            elencoVuoto
        } else {
            elencoConFile
        }
    }

    private var elencoVuoto: some View {
        VStack(alignment: .leading, spacing: m.spazioSezioni) {
            VStack(alignment: .leading, spacing: m.spazioSezioni) {
                Text(TestiAggiornaValori.vuota)
                    .font(Tema.Testo.corpo)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: m.spazioComandi) {
                    Button(TestiAggiornaValori.scegliFile) { stato.scegliFileValori() }
                        .buttonStyle(StileBlu())
                    Button(TestiAggiornaValori.incolla) { stato.incollaValoriDaExcel() }
                        .buttonStyle(StileVetro(margine: m.marginePulsante))
                }
            }
            .padding(m.riquadroVuoto)
            .frame(maxWidth: .infinity, alignment: .leading)
            .vetro(.sottile, forma: .arrotondata(Tema.Raggio.scheda))
            NotaMetodo(testo: TestiAggiornaValori.notaMetodo, titolo: TestiAggiornaValori.titoloNota)
        }
    }

    private var elencoConFile: some View {
        let esiti = esitiElenco
        let daControllare: [AggiornaValori.Esito] = esiti.filter { e in
            e.stato == .daScegliere || e.stato == .nonTrovata || e.insolita
        }
        let visibili = soloDaControllare ? daControllare : esiti
        let nomi = nomiClienti
        return VStack(alignment: .leading, spacing: m.spazioSezioni) {
            VStack(alignment: .leading, spacing: m.spazioCella) {
                Text(TestiAggiornaValori.intestazione(file: sessione.file, righe: sessione.righe.count, colonne: sessione.colonne))
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .fixedSize(horizontal: false, vertical: true)
                if sessione.proposta {
                    HStack(alignment: .center, spacing: m.spazioComandi) {
                        Text(TestiAggiornaValori.proposta)
                            .font(Tema.Testo.corpo)
                            .foregroundColor(Tema.Colore.inchiostro)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: m.spazioComandi)
                        Button(TestiAggiornaValori.importaComeNuove) { stato.importaComeNuove() }
                            .buttonStyle(StileVetro(margine: m.marginePulsante))
                            .disabled(stato.solaLettura)
                            .fixedSize()
                    }
                    .padding(m.margineRiquadro)
                    .riquadroStrumento()
                }
            }
            HStack(spacing: m.spazioComandi) {
                if sessione.righe.contains(where: { $0.data == nil }) {
                    Text(TestiAggiornaValori.etichettaData)
                        .font(Tema.Testo.corpo)
                        .foregroundColor(Tema.Colore.inchiostro)
                    DatePicker("", selection: $dataComune, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .frame(width: m.campoData)
                }
                Spacer(minLength: m.spazioComandi)
                SegmentiAnalisi(opzioni: [(false, TestiAggiornaValori.filtroTutte),
                                          (true, TestiAggiornaValori.filtroDaControllare(daControllare.count))],
                                selezione: $soloDaControllare)
                    .frame(width: m.segmentiCanale)
            }
            indicatori(esiti, daControllare: daControllare.count)
            righeCanali(anteprimaElenco)
            TabellaStrumento {
                Color.clear.frame(width: m.colonnaSpunta, height: Tema.Misura.filo)
                CellaTesta(testo: TestiAggiornaValori.colonnaRiga, larghezza: m.colonnaRiga, destra: true)
                CellaTesta(testo: TestiAggiornaValori.colonnaPosizione)
                    .frame(minWidth: m.colonnaPosizioneMinima)
                CellaTesta(testo: TestiAggiornaValori.colonnaAttuale, larghezza: m.colonnaImporto, destra: true)
                CellaTesta(testo: TestiAggiornaValori.colonnaNuovoElenco, larghezza: m.colonnaImporto, destra: true)
                CellaTesta(testo: TestiAggiornaValori.colonnaVariazione, larghezza: m.colonnaVariazione, destra: true)
                CellaTesta(testo: TestiAggiornaValori.colonnaEsito, larghezza: m.colonnaEsito)
            } righe: {
                LazyVStack(spacing: 0) {
                    ForEach(Array(visibili.enumerated()), id: \.element.id) { i, e in
                        rigaElenco(e, indice: i, nomi: nomi)
                    }
                }
            }
            NotaMetodo(testo: TestiAggiornaValori.notaMetodo, titolo: TestiAggiornaValori.titoloNota)
        }
    }

    private func indicatori(_ esiti: [AggiornaValori.Esito], daControllare: Int) -> some View {
        let attive = esiti.filter { !esclusi.contains($0.id) }
        let aggiorna = attive.filter { $0.stato == .aggiorna }
        let posizioni = Set(aggiorna.compactMap(\.posizioneId)).count
        let storico = attive.filter { $0.stato == .storico }.count
        let totale = anteprimaElenco.totale
        return FasciaKPI {
            KPI(titolo: TestiAggiornaValori.kpiDaAggiornare, valore: "\(aggiorna.count)") {
                Text(TestiAggiornaValori.notaDaAggiornare(posizioni: posizioni))
            }
            KPI(titolo: TestiAggiornaValori.kpiStorico, valore: "\(storico)") {
                Text(TestiAggiornaValori.notaStorico)
            }
            TesseraVariazioneValori(titolo: TestiAggiornaValori.kpiVariazione,
                            valore: TestiAggiornaValori.euroSegno(totale.variazione),
                            colore: Tema.Colore.AggiornaValori.segno(totale.variazione),
                            nota: TestiAggiornaValori.notaVariazione(totale))
            KPI(titolo: TestiAggiornaValori.kpiDaControllare, valore: "\(daControllare)") {
                Text(TestiAggiornaValori.notaDaControllare)
            }
        }
    }

    /// Una riga per canale con almeno una posizione aggiornata: prima Alleanza, poi indipendente.
    @ViewBuilder private func righeCanali(_ r: AggiornaValori.Riepilogo) -> some View {
        let canali = Canale.allCases.filter { (r.perCanale[$0]?.posizioni ?? 0) > 0 }
        if !canali.isEmpty {
            VStack(alignment: .leading, spacing: m.spazioCanali) {
                ForEach(canali) { c in
                    HStack(spacing: m.spazioCella) {
                        EtichettaCanale(canale: c, compatta: true)
                        Text(TestiAggiornaValori.perCanale(r.perCanale[c] ?? AggiornaValori.Totale()))
                            .font(Tema.Testo.didascalia)
                            .foregroundColor(Tema.Colore.inchiostroSecondario)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func rigaElenco(_ e: AggiornaValori.Esito, indice: Int, nomi: [String: String]) -> some View {
        let c = Tema.Colore.AggiornaValori.self
        let incluso = e.stato.applicabile && !esclusi.contains(e.id)
        let pillola = TestiAggiornaValori.pillola(e)
        return RigaStrumento(indice: indice) {
            Button {
                if esclusi.contains(e.id) { esclusi.remove(e.id) } else { esclusi.insert(e.id) }
            } label: {
                Image(systemName: incluso ? "checkmark.square.fill" : "square")
                    .font(Tema.Testo.AggiornaValori.spunta)
                    .foregroundColor(incluso ? c.spunta : c.spuntaVuota)
            }
            .buttonStyle(StileSemplice())
            .disabled(!e.stato.applicabile)
            .frame(width: m.colonnaSpunta)
            CellaTabella(testo: "\(e.id)", larghezza: m.colonnaRiga, destra: true, colore: Tema.Colore.inchiostroSecondario)
            cellaPosizione(e, nomi: nomi)
                .frame(minWidth: m.colonnaPosizioneMinima, maxWidth: .infinity, alignment: .leading)
            CellaImportoValori(alto: e.precedente.map(Formati.euro) ?? "—",
                        basso: e.dataPrecedente.map(TestiAggiornaValori.al),
                        larghezza: m.colonnaImporto)
            CellaImportoValori(alto: e.riga.valore.map(Formati.euro) ?? "—",
                        basso: e.data.map(TestiAggiornaValori.al),
                        terzo: e.quotaGestione.map(TestiAggiornaValori.gestioneSeparata),
                        larghezza: m.colonnaImporto)
            cellaVariazione(e)
            Pillola(testo: pillola.testo, tono: pillola.tono)
                .padding(.horizontal, m.margineCella)
                .frame(width: m.colonnaEsito, alignment: .leading)
        }
        .padding(.vertical, m.rigaVerticale)
        .background(e.insolita ? c.rigaInsolita : Color.clear)
        .opacity(e.stato.applicabile || e.stato == .daScegliere ? 1 : c.opacitaSpenta)
    }

    @ViewBuilder private func cellaPosizione(_ e: AggiornaValori.Esito, nomi: [String: String]) -> some View {
        let p = e.posizioneId.flatMap { perId[$0] }
        let candidate: [(String, String)] = e.candidate.compactMap { id -> (String, String)? in
            guard let q = perId[id] else { return nil }
            return (id, "\(q.nome) · \(nomi[q.clienteId] ?? "") · \(q.canale.nomeBreve)")
        }
        let opzioni: [(String, String)] = [("", TestiAggiornaValori.scegli)] + candidate
        VStack(alignment: .leading, spacing: m.spazioTesto) {
            if e.stato == .daScegliere || e.abbinamento == .scelta {
                MenuTendina(selezione: Binding(get: { scelte[e.id] ?? "" },
                                               set: { scelte[e.id] = $0.isEmpty ? nil : $0 }),
                            opzioni: opzioni,
                            stile: .carta, larghezza: m.tendinaScelta)
            } else if let p {
                HStack(spacing: m.spazioCella) {
                    Text(p.nome)
                        .font(Tema.Testo.titolo)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .lineLimit(1)
                    EtichettaCanale(canale: p.canale, compatta: true)
                    Button("↗") { stato.apriPosizione(p) }
                        .buttonStyle(StileSemplice())
                        .foregroundColor(Tema.Colore.accento)
                        .help(TestiAggiornaValori.apri)
                }
            } else {
                Text([e.riga.cliente, e.riga.prodotto].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Tema.Testo.AggiornaValori.nonTrovata)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
            }
            Text(dettaglio(e, p, nomi: nomi))
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, m.margineCella)
    }

    /// Cliente · numero · spiegazione, in didascalia.
    private func dettaglio(_ e: AggiornaValori.Esito, _ p: Posizione?, nomi: [String: String]) -> String {
        let cliente = p.flatMap { nomi[$0.clienteId] } ?? (p == nil ? "" : e.riga.cliente)
        let numero = p?.numeroContratto ?? e.riga.numeroContratto
        let parti = [cliente,
                     numero.isEmpty ? "" : TestiAggiornaValori.numeroContratto(numero),
                     TestiAggiornaValori.spiegazione(e, posizioni: perId, clienti: nomi)]
        return parti.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    @ViewBuilder private func cellaVariazione(_ e: AggiornaValori.Esito) -> some View {
        if e.stato == .aggiorna, let v = e.variazione {
            let netta = e.risultato.flatMap { abs($0 - v) >= 0.5 ? TestiAggiornaValori.netta($0) : nil }
            CellaImportoValori(alto: TestiAggiornaValori.euroSegno(v),
                        basso: e.variazionePct.map(TestiAggiornaValori.percentualeSegno),
                        terzo: netta,
                        colore: Tema.Colore.AggiornaValori.segno(v),
                        larghezza: m.colonnaVariazione)
        } else {
            CellaImportoValori(alto: "", basso: nil, larghezza: m.colonnaVariazione)
        }
    }

    // MARK: - Scheda «Valori fermi da 12 mesi»

    private func corpoGriglia(_ proxy: ScrollViewProxy) -> some View {
        let nomi = nomiClienti
        var indiceEsiti: [String: AggiornaValori.Esito] = [:]
        for e in esitiGriglia {
            if let id = e.posizioneId, indiceEsiti[id] == nil { indiceEsiti[id] = e }
        }
        let esitiPerPosizione = indiceEsiti
        let oggi = Date()
        return VStack(alignment: .leading, spacing: m.spazioSezioni) {
            HStack(spacing: m.spazioComandi) {
                if let attivo = stato.clienteAttivo {
                    let opzioni: [(String?, String)] = [(nil, TestiAggiornaValori.tuttiIClienti), (attivo.id, attivo.nome)]
                    SegmentiAnalisi(opzioni: opzioni, selezione: $ambito)
                        .frame(width: m.segmentiAmbito)
                }
                let canali: [(Canale?, String)] = [(nil, TestiAggiornaValori.canaleTutti),
                                                   (.alleanza, Canale.alleanza.nomeBreve),
                                                   (.indipendente, Canale.indipendente.nomeBreve)]
                SegmentiAnalisi(opzioni: canali, selezione: $canale)
                    .frame(width: m.segmentiCanale)
                Spacer(minLength: m.spazioComandi)
                Text(TestiAggiornaValori.dataComune)
                    .font(Tema.Testo.corpo)
                    .foregroundColor(Tema.Colore.inchiostro)
                DatePicker("", selection: $dataComune, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .frame(width: m.campoData)
            }
            if elencoGriglia.isEmpty {
                HStack(spacing: m.spazioComandi) {
                    Image(systemName: "checkmark.circle")
                        .font(Tema.Testo.AggiornaValori.simboloVuoto)
                        .foregroundColor(Tema.Colore.AggiornaValori.tuttoAggiornato)
                    Text(TestiAggiornaValori.grigliaVuota)
                        .font(Tema.Testo.corpo)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(m.riquadroVuoto)
                .frame(maxWidth: .infinity, alignment: .leading)
                .riquadroStrumento()
            } else {
                VStack(alignment: .leading, spacing: m.spazioTesto) {
                    Text(TestiAggiornaValori.conteggioFermi(elencoGriglia.count))
                        .font(Tema.Testo.corpo)
                        .foregroundColor(Tema.Colore.inchiostro)
                    Text(TestiAggiornaValori.aiutoTastiera)
                        .font(Tema.Testo.didascalia)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                TabellaStrumento {
                    CellaTesta(testo: TestiAggiornaValori.colonnaCliente, larghezza: m.colonnaCliente)
                    CellaTesta(testo: TestiAggiornaValori.colonnaPosizione)
                        .frame(minWidth: m.colonnaPosizioneMinima)
                    CellaTesta(testo: TestiAggiornaValori.colonnaAttuale, larghezza: m.colonnaAttuale, destra: true)
                    CellaTesta(testo: TestiAggiornaValori.colonnaNuovo, larghezza: m.campoValore + 2 * m.margineCella, destra: true)
                    CellaTesta(testo: TestiAggiornaValori.colonnaData, larghezza: m.campoDataGriglia + 2 * m.margineCella)
                    CellaTesta(testo: TestiAggiornaValori.colonnaVersato, larghezza: m.campoVersato + 2 * m.margineCella)
                    CellaTesta(testo: TestiAggiornaValori.colonnaVariazione, larghezza: m.colonnaVariazioneGriglia, destra: true)
                } righe: {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(elencoGriglia.enumerated()), id: \.element.id) { i, p in
                            RigaGriglia(posizione: p,
                                        cliente: nomi[p.clienteId] ?? "",
                                        fermo: AggiornaValori.fermoDa(p, oggi: oggi),
                                        bozza: bozze[p.id] ?? AggiornaValori.Bozza(),
                                        esito: esitiPerPosizione[p.id],
                                        attiva: fuocoSu(p.id),
                                        fuoco: $fuoco,
                                        scrivi: { b in bozze[p.id] = b },
                                        invio: { avanza(dopo: i, proxy: proxy) })
                                .equatable()
                                .id(p.id)
                        }
                    }
                }
            }
        }
    }

    private func fuocoSu(_ id: String) -> Bool {
        switch fuoco {
        case .valore(let x)?, .data(let x)?, .versato(let x)?: return x == id
        case nil: return false
        }
    }

    /// Invio: la riga sotto, valore nuovo. La riga pigra prima deve esistere, quindi il fuoco arriva un attimo dopo.
    private func avanza(dopo i: Int, proxy: ScrollViewProxy) {
        let prossima = i + 1
        guard prossima < elencoGriglia.count else {
            fuoco = nil
            return
        }
        let id = elencoGriglia[prossima].id
        proxy.scrollTo(id, anchor: .center)
        DispatchQueue.main.async { fuoco = .valore(id) }
    }

    // MARK: - Riepilogo

    private func riepilogo(_ r: AggiornaValori.Riepilogo) -> some View {
        let nomi = nomiClienti
        var indice: [String: Posizione] = [:]
        let toccate = Set(r.posizioni)
        for p in stato.posizioni where toccate.contains(p.id) && indice[p.id] == nil { indice[p.id] = p }
        let elenco = r.posizioni.compactMap { indice[$0] }
        let mostrate = Array(elenco.prefix(m.riepilogoMassimo))
        return VStack(alignment: .leading, spacing: m.spazioSezioni) {
            TitoloStrumento(occhiello: TestiAggiornaValori.occhiello, titolo: TestiAggiornaValori.titoloRiepilogo,
                            testo: TestiAggiornaValori.testoRiepilogo(r))
            FasciaKPI {
                KPI(titolo: TestiAggiornaValori.kpiAggiornati, valore: "\(r.attuali)") { EmptyView() }
                KPI(titolo: TestiAggiornaValori.kpiStorico, valore: "\(r.storico)") { EmptyView() }
                KPI(titolo: TestiAggiornaValori.kpiPrima, valore: Formati.euro(r.totale.prima)) { EmptyView() }
                KPI(titolo: TestiAggiornaValori.kpiDopo, valore: Formati.euro(r.totale.dopo)) {
                    Text(TestiAggiornaValori.notaDopo(r.totale))
                        .foregroundColor(Tema.Colore.AggiornaValori.segno(r.totale.variazione))
                }
            }
            righeCanali(r)
            if !mostrate.isEmpty {
                TabellaStrumento {
                    CellaTesta(testo: TestiAggiornaValori.colonnaPosizione)
                    CellaTesta(testo: TestiAggiornaValori.colonnaCliente, larghezza: m.colonnaCliente)
                    CellaTesta(testo: TestiAggiornaValori.colonnaAttuale, larghezza: m.colonnaAttuale, destra: true)
                    Color.clear.frame(width: m.colonnaImporto, height: Tema.Misura.filo)
                } righe: {
                    VStack(spacing: 0) {
                        ForEach(Array(mostrate.enumerated()), id: \.element.id) { i, p in
                            RigaStrumento(indice: i) {
                                HStack(spacing: m.spazioCella) {
                                    Text(p.nome)
                                        .font(Tema.Testo.titolo)
                                        .foregroundColor(Tema.Colore.inchiostro)
                                        .lineLimit(1)
                                    EtichettaCanale(canale: p.canale, compatta: true)
                                }
                                .padding(.horizontal, m.margineCella)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                CellaTabella(testo: nomi[p.clienteId] ?? "", larghezza: m.colonnaCliente,
                                             colore: Tema.Colore.inchiostroSecondario)
                                CellaImportoValori(alto: p.controvalore.map(Formati.euro) ?? "—",
                                            basso: p.dataValore.map(TestiAggiornaValori.al),
                                            larghezza: m.colonnaAttuale)
                                Button(TestiAggiornaValori.apri) { stato.apriPosizione(p) }
                                    .buttonStyle(StileVetro(margine: m.marginePulsante))
                                    .frame(width: m.colonnaImporto, alignment: .trailing)
                            }
                            .padding(.vertical, m.rigaVerticale)
                        }
                    }
                }
                if elenco.count > mostrate.count {
                    Text(TestiAggiornaValori.altre(elenco.count - mostrate.count))
                        .font(Tema.Testo.didascalia)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
            }
        }
    }
}

// MARK: - Una riga della griglia

/// Una riga della griglia dei valori fermi: si ridisegna solo quando cambiano i suoi dati (Equatable),
/// non a ogni battuta nelle altre righe.
struct RigaGriglia: View, Equatable {
    let posizione: Posizione
    let cliente: String
    let fermo: Int?
    let bozza: AggiornaValori.Bozza
    let esito: AggiornaValori.Esito?
    let attiva: Bool
    let fuoco: FocusState<CampoGrigliaValori?>.Binding
    let scrivi: (AggiornaValori.Bozza) -> Void
    let invio: () -> Void

    nonisolated static func == (a: RigaGriglia, b: RigaGriglia) -> Bool {
        // In due passi: una catena lunga di confronti tra opzionali rallenta il controllo dei tipi
        guard a.posizione == b.posizione, a.cliente == b.cliente, a.fermo == b.fermo else { return false }
        return a.bozza == b.bozza && a.esito == b.esito && a.attiva == b.attiva
    }

    private var m: Tema.Misura.AggiornaValori.Type { Tema.Misura.AggiornaValori.self }

    var body: some View {
        let id = posizione.id
        HStack(spacing: 0) {
            Text(cliente)
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
                .padding(.horizontal, m.margineCella)
                .frame(width: m.colonnaCliente, alignment: .leading)
            VStack(alignment: .leading, spacing: m.spazioTesto) {
                HStack(spacing: m.spazioCella) {
                    Text(posizione.nome)
                        .font(Tema.Testo.titolo)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .lineLimit(1)
                    EtichettaCanale(canale: posizione.canale, compatta: true)
                }
                Text(TestiAggiornaValori.fermo(mesi: fermo))
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.AggiornaValori.fermo)
                    .lineLimit(1)
            }
            .padding(.horizontal, m.margineCella)
            .frame(minWidth: m.colonnaPosizioneMinima, maxWidth: .infinity, alignment: .leading)
            CellaImportoValori(alto: Formati.euro(posizione.controvalore ?? posizione.valore),
                        basso: posizione.dataValore.map(TestiAggiornaValori.al) ?? TestiAggiornaValori.senzaData,
                        larghezza: m.colonnaAttuale)
            campo(Formati.euro(posizione.valore), testo: bozza.valore, larghezza: m.campoValore, destra: true,
                  fuoco: .valore(id)) { var b = bozza; b.valore = $0; scrivi(b) }
            campo(TestiAggiornaValori.segnapostoData, testo: bozza.data, larghezza: m.campoDataGriglia, destra: false,
                  fuoco: .data(id)) { var b = bozza; b.data = $0; scrivi(b) }
            campo(TestiAggiornaValori.segnapostoVersato, testo: bozza.versato, larghezza: m.campoVersato, destra: true,
                  fuoco: .versato(id)) { var b = bozza; b.versato = $0; scrivi(b) }
            variazione
                .frame(width: m.colonnaVariazioneGriglia, alignment: .trailing)
        }
        .padding(.vertical, m.rigaVerticale)
        .background(attiva ? Tema.Colore.AggiornaValori.rigaAttiva : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
        }
    }

    private func campo(_ segnaposto: String, testo: String, larghezza: CGFloat, destra: Bool,
                       fuoco valore: CampoGrigliaValori, scrivi: @escaping (String) -> Void) -> some View {
        TextField(segnaposto, text: Binding(get: { testo }, set: scrivi))
            .font(destra ? Tema.Testo.Componenti.numero : Tema.Testo.corpo)
            .multilineTextAlignment(destra ? .trailing : .leading)
            .focused(fuoco, equals: valore)
            .onSubmit(invio)
            .campoTesto()
            .frame(width: larghezza)
            .padding(.horizontal, m.margineCella)
    }

    @ViewBuilder private var variazione: some View {
        if let e = esito {
            if e.stato == .aggiorna && !e.insolita, let v = e.variazione {
                CellaImportoValori(alto: TestiAggiornaValori.euroSegno(v),
                            basso: e.variazionePct.map(TestiAggiornaValori.percentualeSegno),
                            colore: Tema.Colore.AggiornaValori.segno(v),
                            larghezza: m.colonnaVariazioneGriglia)
            } else if e.stato == .aggiorna && e.variazione == nil {
                CellaImportoValori(alto: "", basso: nil, larghezza: m.colonnaVariazioneGriglia)
            } else {
                let p = TestiAggiornaValori.pillola(e)
                Pillola(testo: p.testo, tono: p.tono)
                    .padding(.horizontal, m.margineCella)
            }
        }
    }
}

// MARK: - Celle e tessere

/// Una cella con un importo e una o due righe sotto, in didascalia (a destra come i numeri).
struct CellaImportoValori: View {
    let alto: String
    let basso: String?
    var terzo: String? = nil
    var colore: Color = Tema.Colore.inchiostro
    let larghezza: CGFloat

    var body: some View {
        let m = Tema.Misura.AggiornaValori.self
        VStack(alignment: .trailing, spacing: m.spazioTesto) {
            Text(alto)
                .font(Tema.Testo.Componenti.numero)
                .foregroundColor(colore)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let basso {
                Text(basso)
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
            }
            if let terzo {
                Text(terzo)
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, m.margineCella)
        .frame(width: larghezza, alignment: .trailing)
    }
}

/// Una tessera come `KPI` con il valore colorato (la variazione: verde se sale, rosso se scende).
private struct TesseraVariazioneValori: View {
    let titolo: String
    let valore: String
    let colore: Color
    let nota: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.AggiornaValori.spazioTessera) {
            Text(titolo)
                .font(Tema.Testo.secondario)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(valore)
                .font(Tema.Testo.valoreTessera)
                .tracking(Tema.Testo.Componenti.spaziaturaValore)
                .foregroundColor(colore)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(nota)
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
        }
        .padding(Tema.Misura.Componenti.tessera)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.tessera))
    }
}
