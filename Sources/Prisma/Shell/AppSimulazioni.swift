import SwiftUI

/// App Simulazioni (.os-app-simulations): il laboratorio delle ipotesi.
/// Console con i display a cristalli liquidi a sinistra, foglio dei risultati a destra;
/// gli scenari si salvano nel dossier del cliente e si confrontano fino a tre alla volta.
struct AppSimulazioni: View {
    @EnvironmentObject var stato: StatoShell
    @State var salvataggio: Simulazione?
    @State var mostraMetodo = false

    private var cliente: String { stato.clienteAttivoId }
    private var salvate: [Simulazione] { stato.simulazioniCliente(cliente) }

    /// Ipotesi sul tavolo: quella in lavorazione per il cliente o una nuova.
    private var bozza: Binding<Simulazione> {
        Binding(
            get: {
                if let b = stato.bozzaSimulazione, b.clienteId == cliente { return b }
                return Self.nuova(per: cliente, stato: stato)
            },
            set: { stato.bozzaSimulazione = $0 }
        )
    }

    /// Nuova ipotesi: parte dalla liquidità del cliente, come nel template.
    static func nuova(per cliente: String, stato: StatoShell) -> Simulazione {
        var s = Simulazione(clienteId: cliente, titolo: "Nuova ipotesi")
        let liquidita = stato.posizioniCliente(cliente)
            .filter { $0.stato == .inEssere && $0.area == .liquidita }
            .reduce(0) { $0 + $1.valore }
        s.capitale = min((liquidita / 1_000).rounded() * 1_000, 10_000_000)
        s.versamentoMensile = 0
        s.anni = 10
        s.rendimento = 3
        return s
    }

    var body: some View {
        CorniceStrumento(
            notaStato: "Calcoli eseguiti in locale · rendimento costante, nessuna previsione o raccomandazione",
            notaDestra: "\(salvate.count) \(salvate.count == 1 ? "scenario" : "scenari") nel dossier"
        ) {
            rail
        } contenuto: {
            VStack(spacing: 0) {
                barra
                if stato.schedaSimulazioni == .simulatore {
                    simulatore
                } else {
                    scenari
                }
            }
        }
        .sheet(item: $salvataggio) { s in
            ModuloScenario(bozza: s) { salvato in
                stato.salvaSimulazione(salvato)
                stato.bozzaSimulazione = salvato
                stato.scenariConfrontati.insert(salvato.id)
            }
        }
    }

    // MARK: - Elenco laterale

    @ViewBuilder private var rail: some View {
        DossierRail()
        EtichettaRail(testo: "Vista")
        SegmentiAnalisi(opzioni: [(SchedaSimulazioni.simulatore, "Simulatore"), (.scenari, "Scenari")],
                        selezione: $stato.schedaSimulazioni)
        EtichettaRail(testo: "Parti da una posizione")
        let posizioni = stato.posizioniCliente(cliente).filter { $0.area.proiettabile && $0.stato != .chiusa }
        if posizioni.isEmpty {
            Text("Nessun investimento, piano di risparmio o di previdenza nel dossier.")
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.kpiNota)
                .padding(.horizontal, 3)
        }
        VStack(spacing: 0) {
            ForEach(posizioni) { p in
                VoceNavigazione(titolo: (p.stato == .proposta ? "Proposta · " : "") + p.nome, colore: Colori.Analisi.area(p.area),
                                attiva: bozza.wrappedValue.posizioneId == p.id && stato.schedaSimulazioni == .simulatore) {
                    stato.simula(p)
                }
            }
        }
        CollegatiRail(app: [.posizioni, .confronti, .analisi360])
    }

    // MARK: - Barra degli strumenti

    private var barra: some View {
        let b = bozza.wrappedValue
        let caricato = salvate.first { $0.id == b.id }
        return HStack(spacing: 8) {
            Circle().fill(Colori.Strumenti.spia).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(stato.schedaSimulazioni == .scenari ? "Scenari nel dossier"
                     : caricato.map { "Scenario · \($0.titolo)" } ?? (b.posizioneId != nil ? "Dalla posizione · \(b.titolo)" : "Nuova ipotesi"))
                    .font(Tipo.consoleTitolo)
                    .foregroundColor(Colori.Strumenti.consoleTitolo)
                if let c = caricato, !c.stesseIpotesi(b), stato.schedaSimulazioni == .simulatore {
                    Text("Ipotesi modificate: salvale come nuovo scenario").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                }
            }
            .incisione(.white)
            Spacer()
            if stato.schedaSimulazioni == .simulatore {
                Button("Nuova ipotesi") {
                    stato.bozzaSimulazione = Self.nuova(per: cliente, stato: stato)
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                if let c = caricato, c.stesseIpotesi(b) {
                    Button("Confronta") {
                        stato.confrontoA = .simulazione(c.id)
                        if stato.confrontoB == stato.confrontoA { stato.confrontoB = nil }
                        stato.apri(.confronti)
                    }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                }
                Button("Salva scenario") {
                    var s = b
                    s.id = "sim-\(UUID().uuidString.prefix(8).lowercased())"
                    s.creataIl = Appuntamento.alMinuto(Date())
                    if caricato != nil || s.titolo == "Nuova ipotesi" {
                        s.titolo = "Piano \(s.anni) \(s.anni == 1 ? "anno" : "anni") · \(Formati.percentuale(s.rendimento))"
                    }
                    salvataggio = s
                }
                .buttonStyle(StileBlu())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Gradienti.kpi)
        .bordoBasso(Colori.Analisi.kpiBordo)
    }

    // MARK: - Simulatore

    private var simulatore: some View {
        let b = bozza
        let esito = MotoreProiezione.calcola(b.wrappedValue.parametri)
        let impatto = MotoreProiezione.impattoCosti(b.wrappedValue.parametri)
        return HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ComandoSimulatore(etichetta: "Capitale iniziale", valore: b.capitale, unita: "€", intervallo: 0...10_000_000, passo: 1_000,
                                      fineCursore: 500_000)
                    ComandoSimulatore(etichetta: "Versamento mensile", valore: b.versamentoMensile, unita: "€", intervallo: 0...100_000, passo: 50,
                                      fineCursore: 3_000)
                    ComandoSimulatore(etichetta: "Orizzonte",
                                      valore: Binding(get: { Double(b.wrappedValue.anni) }, set: { b.wrappedValue.anni = max(1, Int($0.rounded())) }),
                                      unita: "anni", intervallo: 1...40, passo: 1)
                    ComandoSimulatore(etichetta: "Rendimento annuo", valore: b.rendimento, unita: "%", intervallo: -10...20, passo: 0.1, decimali: 1)
                    Rectangle().fill(Colori.Strumenti.consoleBordo).frame(height: 1).shadow(color: .white, radius: 0, x: 0, y: 1)
                    ComandoSimulatore(etichetta: "Costo d'ingresso", valore: b.costoIngresso, unita: "%", intervallo: 0...10, passo: 0.5, decimali: 1)
                    ComandoSimulatore(etichetta: "Costo annuo", valore: b.costoAnnuo, unita: "%", intervallo: 0...5, passo: 0.05, decimali: 2)
                    ComandoSimulatore(etichetta: "Imposte sul guadagno", valore: b.aliquota, unita: "%", intervallo: 0...43, passo: 0.5, decimali: 1)
                    ComandoSimulatore(etichetta: "Inflazione", valore: b.inflazione, unita: "%", intervallo: 0...10, passo: 0.1, decimali: 1)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Canale dell'ipotesi")
                            .font(Tipo.consoleEtichetta)
                            .foregroundColor(Colori.Strumenti.consoleEtichetta)
                            .incisione(.white)
                        SegmentiAnalisi(opzioni: [(Canale?.none, "Nessuno"), (.alleanza, "Alleanza"), (.indipendente, "Indip.")],
                                        selezione: b.canale)
                    }
                }
                .padding(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
            }
            .frame(width: Misure.Strumenti.console)
            .background(Gradienti.console)
            .luceInterna(.white)
            .bordoDestro(Colori.Strumenti.consoleBordo)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    risultato(b.wrappedValue, esito, impatto)
                    GraficoProiezione(serie: [.init(id: "valore", punti: esito.punti, colore: Colori.Analisi.linea, principale: true)])
                    HStack(spacing: 16) {
                        LegendaLinea(colore: Colori.Analisi.linea, testo: "Capitale ipotetico (prima delle imposte)")
                        LegendaLinea(colore: Colori.Analisi.lineaTratteggiata, testo: "Totale versato", tratteggio: true)
                        Spacer()
                        Button(mostraMetodo ? "Nascondi il metodo" : "Come viene calcolato?") { mostraMetodo.toggle() }
                            .buttonStyle(StileSemplice())
                            .font(Tipo.colonnaCollegamento)
                            .foregroundColor(Colori.Colonna.collegamento)
                    }
                    if mostraMetodo {
                        NotaMetodo(testo: "Il rendimento è annuo effettivo e diventa mensile equivalente: (1 + r)^(1/12) − 1. I versamenti entrano a inizio mese al netto del costo d'ingresso, che si applica anche al capitale iniziale; ogni mese si paga la quota del costo annuo. Alla fine le imposte si applicano alla sola parte che supera il versato, e il valore in euro di oggi divide il netto per l'inflazione cumulata. Rendimento costante: niente volatilità né probabilità. È lo stesso motore delle Posizioni.",
                                   titolo: "La formula, senza scorciatoie")
                    }
                    scenariRendimento(b.wrappedValue)
                    NotaMetodo(testo: "Le ipotesi non sono previsioni. Per i prodotti reali usa costi e rendimenti del KID o del prospetto, e verifica la fiscalità specifica.")
                }
                .padding(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
            }
            .background(
                ZStack {
                    Colori.Strumenti.carta
                    Rigatura(passo: Misure.Strumenti.rigaCarta).fill(Colori.Strumenti.cartaRiga)
                }
            )
        }
    }

    private func risultato(_ s: Simulazione, _ e: EsitoProiezione, _ impatto: Double) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("CAPITALE FINALE IPOTETICO, AL NETTO")
                    .font(Tipo.risultatoOcchiello)
                    .tracking(1.2)
                    .foregroundColor(Colori.Strumenti.risultatoNota)
                Text(Formati.euro(e.netto))
                    .font(Tipo.risultatoGrande)
                    .foregroundColor(Colori.Strumenti.risultato)
                    .incisione(.white)
                HStack(spacing: 6) {
                    Text("Al termine di \(s.anni) \(s.anni == 1 ? "anno" : "anni")")
                    if let c = s.canale { EtichettaCanale(canale: c, compatta: true) }
                }
                .font(Tipo.risultatoNota)
                .foregroundColor(Colori.Strumenti.risultatoNota)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 0) {
                dettaglio("Totale versato", Formati.euro(e.versato))
                dettaglio(e.guadagnoNetto < 0 ? "Variazione netta" : "Crescita netta",
                          (e.guadagnoNetto > 0 ? "+" : "") + Formati.euro(e.guadagnoNetto),
                          colore: e.guadagnoNetto < 0 ? Colori.Strumenti.negativo : Colori.Strumenti.positivo)
                dettaglio("In euro di oggi", Formati.euro(e.reale))
                dettaglio("Costi e imposte", Formati.euro(e.costi + e.imposte), nota: "i costi tolgono \(Formati.euro(impatto))")
            }
            .overlay(Rectangle().strokeBorder(Colori.Strumenti.risultatoBordo, lineWidth: 1))
        }
    }

    private func dettaglio(_ etichetta: String, _ valore: String, colore: Color = Colori.Strumenti.risultatoNota, nota: String? = nil) -> some View {
        VStack(spacing: 3) {
            Text(etichetta).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
            Text(valore).font(Tipo.risultatoDettaglio).foregroundColor(colore).lineLimit(1).minimumScaleFactor(0.7)
            if let nota { Text(nota).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1) }
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) { Rectangle().fill(Colori.Strumenti.risultatoBordo).frame(width: 1) }
    }

    private func scenariRendimento(_ s: Simulazione) -> some View {
        let scenari = MotoreProiezione.scenari(s.parametri)
        return TabellaStrumento {
            CellaTesta(testo: "Se il rendimento fosse")
            CellaTesta(testo: "Rendimento", larghezza: 100, destra: true)
            CellaTesta(testo: "Netto", larghezza: 120, destra: true)
            CellaTesta(testo: "Guadagno netto", larghezza: 120, destra: true)
            CellaTesta(testo: "In euro di oggi", larghezza: 120, destra: true)
        } righe: {
            ForEach(Array(scenari.enumerated()), id: \.offset) { i, sc in
                RigaStrumento(indice: i) {
                    CellaTabella(testo: sc.nome, forte: true)
                    CellaTabella(testo: Formati.percentuale(sc.rendimento), larghezza: 100, destra: true)
                    CellaTabella(testo: Formati.euro(sc.esito.netto), larghezza: 120, destra: true)
                    CellaTabella(testo: Formati.euro(sc.esito.guadagnoNetto), larghezza: 120, destra: true,
                                 colore: sc.esito.guadagnoNetto < 0 ? Colori.Strumenti.negativo : Colori.Analisi.tabellaTesto)
                    CellaTabella(testo: Formati.euro(sc.esito.reale), larghezza: 120, destra: true)
                }
            }
        }
    }

    // MARK: - Scenari salvati

    private var scelti: [Simulazione] {
        let ids = stato.scenariConfrontati.isEmpty ? Set(salvate.prefix(3).map(\.id)) : stato.scenariConfrontati
        return salvate.filter { ids.contains($0.id) }.prefix(3).map { $0 }
    }

    @ViewBuilder private var scenari: some View {
        if salvate.isEmpty {
            VStack(spacing: 10) {
                Text("∿").font(Tipo.risultatoGrande).foregroundColor(Colori.Analisi.lineaTratteggiata)
                Text("Il primo scenario è ancora da scrivere").font(Tipo.strumentoTitolo).foregroundColor(Colori.Strumenti.titolo)
                Text("Imposta capitale, versamenti e tempo nel simulatore, poi salva la tua ipotesi.")
                    .font(Tipo.strumentoTesto).foregroundColor(Colori.Analisi.kpiNota)
                Button("Apri il simulatore") { stato.schedaSimulazioni = .simulatore }
                    .buttonStyle(StileBlu())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let confrontati = scelti
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TitoloStrumento(occhiello: "Scenari nel dossier", titolo: "Le ipotesi messe da parte",
                                    testo: "Seleziona fino a tre scenari per confrontarli. Un clic su Carica li riporta nel simulatore.")
                    TabellaStrumento {
                        CellaTesta(testo: "", larghezza: 34)
                        CellaTesta(testo: "Scenario")
                        CellaTesta(testo: "Canale", larghezza: 110)
                        CellaTesta(testo: "Ipotesi", larghezza: 210)
                        CellaTesta(testo: "", larghezza: 150)
                    } righe: {
                        ForEach(Array(salvate.enumerated()), id: \.element.id) { i, s in
                            RigaStrumento(indice: i) {
                                let scelto = confrontati.contains { $0.id == s.id }
                                Button { alternaScelta(s.id, scelto: scelto) } label: {
                                    Image(systemName: scelto ? "checkmark.square.fill" : "square")
                                        .foregroundColor(scelto ? Colori.Analisi.navBasso : Colori.Analisi.kpiNota)
                                        .frame(width: 34)
                                }
                                .buttonStyle(StileSemplice())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(s.titolo).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                                    Text("Salvato il \(Formati.dataEstesa.string(from: s.creataIl))").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                                }
                                .lineLimit(1)
                                .padding(Misure.Analisi.cellaMargine)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Group {
                                    if let c = s.canale { EtichettaCanale(canale: c, compatta: true) } else { Text("—").foregroundColor(Colori.Analisi.kpiNota) }
                                }
                                .frame(width: 110, alignment: .leading)
                                CellaTabella(testo: "\(Formati.euro(s.capitale)) + \(Formati.euro(s.versamentoMensile))/mese · \(s.anni) a · \(Formati.percentuale(s.rendimento))",
                                             larghezza: 210)
                                HStack(spacing: 6) {
                                    Button("Carica") {
                                        stato.bozzaSimulazione = s
                                        stato.schedaSimulazioni = .simulatore
                                    }
                                    Button("Elimina") { stato.eliminaSimulazione(s.id) }
                                }
                                .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)))
                                .frame(width: 150)
                            }
                        }
                    }
                    if !confrontati.isEmpty {
                        PannelloAnalisi(titolo: "Confronto delle ipotesi selezionate",
                                        nota: "Durate e versamenti possono differire: i finali non sono direttamente equivalenti.") {
                            EmptyView()
                        } contenuto: {
                            VStack(alignment: .leading, spacing: 12) {
                                GraficoProiezione(serie: confrontati.enumerated().map { i, s in
                                    .init(id: s.id, punti: MotoreProiezione.calcola(s.parametri).punti,
                                          colore: Colori.Strumenti.serie[i % Colori.Strumenti.serie.count], principale: i == 0)
                                })
                                HStack(spacing: 16) {
                                    ForEach(Array(confrontati.enumerated()), id: \.element.id) { i, s in
                                        LegendaLinea(colore: Colori.Strumenti.serie[i % Colori.Strumenti.serie.count], testo: s.titolo)
                                    }
                                }
                                tabellaConfronto(confrontati)
                            }
                        }
                    }
                }
                .padding(EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18))
            }
        }
    }

    private func alternaScelta(_ id: String, scelto: Bool) {
        var ids = Set(scelti.map(\.id))
        if scelto {
            ids.remove(id)
        } else if ids.count < 3 {
            ids.insert(id)
        } else {
            stato.mostraAvviso("Puoi confrontare fino a tre scenari: deselezionane uno.")
            return
        }
        stato.scenariConfrontati = ids
    }

    private func tabellaConfronto(_ elenco: [Simulazione]) -> some View {
        TabellaStrumento {
            CellaTesta(testo: "Scenario")
            CellaTesta(testo: "Versato", larghezza: 110, destra: true)
            CellaTesta(testo: "Costi", larghezza: 100, destra: true)
            CellaTesta(testo: "Netto", larghezza: 120, destra: true)
            CellaTesta(testo: "Variazione", larghezza: 110, destra: true)
            CellaTesta(testo: "In euro di oggi", larghezza: 120, destra: true)
        } righe: {
            ForEach(Array(elenco.enumerated()), id: \.element.id) { i, s in
                let e = MotoreProiezione.calcola(s.parametri)
                RigaStrumento(indice: i) {
                    HStack(spacing: 7) {
                        Circle().fill(Colori.Strumenti.serie[i % Colori.Strumenti.serie.count]).frame(width: 8, height: 8)
                        Text(s.titolo).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                    }
                    .padding(Misure.Analisi.cellaMargine)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    CellaTabella(testo: Formati.euro(e.versato), larghezza: 110, destra: true)
                    CellaTabella(testo: Formati.euro(e.costi), larghezza: 100, destra: true)
                    CellaTabella(testo: Formati.euro(e.netto), larghezza: 120, destra: true, forte: true)
                    CellaTabella(testo: (e.guadagnoNetto > 0 ? "+" : "") + Formati.euro(e.guadagnoNetto), larghezza: 110, destra: true,
                                 colore: e.guadagnoNetto < 0 ? Colori.Strumenti.negativo : Colori.Strumenti.positivo)
                    CellaTabella(testo: Formati.euro(e.reale), larghezza: 120, destra: true)
                }
            }
        }
    }
}

/// Modulo per dare un nome allo scenario prima di salvarlo.
struct ModuloScenario: View {
    @Environment(\.dismiss) var chiudi
    @State var bozza: Simulazione
    let salva: (Simulazione) -> Void

    var body: some View {
        CorniceModulo(titolo: "Salva nel dossier") {
            VStack(alignment: .leading, spacing: 14) {
                CampoModulo(etichetta: "Nome dello scenario") {
                    TextField("Per esempio Piano 10 anni", text: $bozza.titolo).textFieldStyle(.roundedBorder)
                }
                CampoModulo(etichetta: "Ipotesi") {
                    Text("\(Formati.euro(bozza.capitale)) iniziali · \(Formati.euro(bozza.versamentoMensile))/mese · \(bozza.anni) anni · \(Formati.percentuale(bozza.rendimento)) annuo · costi \(Formati.percentuale(bozza.costoAnnuo)) all'anno")
                        .font(Tipo.campoValore)
                        .foregroundColor(Colori.Rubrica.secondario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } piede: {
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button("Salva scenario") {
                var s = bozza
                s.titolo = s.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
                salva(s)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(bozza.titolo.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 520, height: 260)
    }
}
