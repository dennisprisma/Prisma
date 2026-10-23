import SwiftUI

/// App Prospetti e report (nello spazio Presentazioni del dock).
/// - Valutazione di un investimento: prospetto A4 verticale per il consulente e report A4 orizzontale
///   da lasciare al cliente, sul modello dei documenti di Denis.
/// - Resoconto delle posizioni in essere: prospetto per il consulente e report per il cliente.
/// - Prospetti di dettaglio: una posizione o una proposta, un confronto.
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
            Text(scelta.tipo == .valutazione ? "Nessuna valutazione per questo cliente"
                 : scelta.tipo == .obiettivo ? "Nessun obiettivo per questo cliente: si creano nell'app Obiettivi."
                 : scelta.tipo == .sostituzione ? "Servono due posizioni da confrontare: una in essere e un'alternativa, o due proposte."
                 : "Non c'è ancora niente da impaginare per questo cliente.")
                .font(Tipo.strumentoTitolo).foregroundColor(Colori.Strumenti.titolo)
            if scelta.tipo == .valutazione { pulsanteNuova }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Elenco laterale

    @ViewBuilder private var rail: some View {
        DossierRail()
        EtichettaRail(testo: "Prospetto e report")
        ForEach([TipoProspetto.checkUp, .valutazione, .resoconto, .sostituzione, .previdenza, .protezione, .obiettivo, .liquidita]) { t in
            VoceNavigazione(titolo: t.nome, attiva: scelta.tipo == t) { scegli(t) }
        }
        EtichettaRail(testo: "Prospetti di dettaglio")
        ForEach([TipoProspetto.posizione, .confronto]) { t in
            VoceNavigazione(titolo: t.nome, attiva: scelta.tipo == t) { scegli(t) }
        }
        EtichettaRail(testo: "Per te")
        VoceNavigazione(titolo: TipoProspetto.portafoglio.nome, attiva: scelta.tipo == .portafoglio) { scegli(.portafoglio) }
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
        case .resoconto:
            stato.prospetto = .resoconto(report: false)
        case .sostituzione:
            stato.prospetto = .sostituzione("", "", report: false)
        case .previdenza:
            stato.prospetto = .previdenza(report: false)
        case .protezione:
            stato.prospetto = .protezione(report: false)
        case .obiettivo:
            stato.prospetto = .obiettivo("", report: false)
        case .liquidita:
            stato.prospetto = .liquidita(report: false)
        case .checkUp:
            stato.prospetto = .checkUp(report: false)
        case .posizione:
            let elenco = posizioniOrdinate
            if let p = elenco.first(where: { $0.stato == .proposta }) ?? elenco.first { stato.prospetto = .posizione(p.id) }
        case .confronto:
            stato.prospetto = stato.confrontoPredefinito()
        case .portafoglio:
            stato.prospetto = .portafoglio
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
                    case .resoconto(let report): sceltaResoconto(report: report)
                    case .sostituzione(let a, let b, let report): sceltaSostituzione(a, b, report: report)
                    case .previdenza(let report): sceltaPrevidenza(report: report)
                    case .protezione(let report): sceltaProtezione(report: report)
                    case .obiettivo(let id, let report): sceltaObiettivo(id, report: report)
                    case .liquidita(let report): sceltaLiquidita(report: report)
                    case .checkUp(let report): sceltaCheckUp(report: report)
                    case .posizione(let id): sceltaPosizione(id)
                    case .confronto(let a, let b): sceltaConfronto(a, b)
                    case .valutazione(let id, let report): sceltaValutazione(id, report: report)
                    case .portafoglio: sceltaPortafoglio
                    }
                    if scelta.conCommento, let chiave = scelta.chiaveCommento(cliente: cliente) {
                        PannelloCommento(scelta: scelta).id(chiave)
                    }
                }
            }
        }
        .background(Gradienti.railAnalisi)
    }

    private var intestazioneColonna: String {
        switch scelta {
        case .resoconto: return "RESOCONTO DEL CLIENTE"
        case .sostituzione: return "LE DUE STRADE"
        case .previdenza: return "PREVIDENZA DEL CLIENTE"
        case .protezione: return "PROTEZIONE DELLA FAMIGLIA"
        case .obiettivo: return "OBIETTIVI DEL CLIENTE"
        case .liquidita: return "LIQUIDITÀ DEL CLIENTE"
        case .checkUp: return "PRIMO INCONTRO"
        case .posizione: return "SCEGLI LA POSIZIONE"
        case .confronto: return "LE DUE VOCI"
        case .valutazione: return "VALUTAZIONI DEL CLIENTE"
        case .portafoglio: return "TUTTI I CLIENTI"
        }
    }

    private func sceltaResoconto(report: Bool) -> some View {
        let voci = report
            ? ["Copertina in cuoio con il patrimonio netto", "Il quadro: aree e canali in una pagina",
               "Come sta andando: versato, valore, risultato", "Quanto incasseresti oggi, dopo le imposte",
               "Posizione per posizione, in schede",
               "Le tutele, i prossimi 12 mesi, i costi", "In sintesi e prossimi passi"]
            : ["Cifre chiave: patrimonio, versato, risultato, rendimento", "Ogni posizione finanziaria, divisa per canale",
               "Ripartizione per area e per canale", "Tutele, liquidità e debiti, impegni dell'anno",
               "Imposte e netto incassabile al centesimo, costi voce per voce", "Previdenza: netto e aliquota per ogni causa",
               "Scadenze dei prossimi 12 mesi e proposte aperte", "Storico dei valori, metodo e firme"]
        return VStack(alignment: .leading, spacing: 10) {
            SegmentiAnalisi(opzioni: [(false, "Prospetto"), (true, "Report")],
                            selezione: Binding(get: { report }, set: { stato.prospetto = .resoconto(report: $0); archiviato = nil }))
            Text(report ? "Report per il cliente: A4 orizzontale, una pagina per messaggio, da lasciare al cliente."
                        : "Prospetto per te: A4 verticale, ogni cifra posizione per posizione, da mostrare al cliente.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(voci, id: \.self) { voce in
                    HStack(alignment: .top, spacing: 7) {
                        Text("•").foregroundColor(Colori.Analisi.navBasso)
                        Text(voce).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(Tipo.strumentoTesto)
                    .foregroundColor(Colori.Analisi.tabellaTesto)
                }
            }
            Text("Tutte le cifre vengono dalle Posizioni del cliente: aggiornale lì e il resoconto si ricompone. Ogni volta che cambi un controvalore, il valore precedente resta nello storico.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
    }

    private var sceltaPortafoglio: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prospetto per te: A4 verticale, con le cifre della vista Portafoglio di Posizioni. Da usare per la revisione periodica del tuo lavoro, non da consegnare ai clienti.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
            Text("Non si archivia nei Documenti di un cliente: salvalo in PDF dove preferisci.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
            Button("Apri il Portafoglio in Posizioni ↗") {
                stato.portafoglio = true
                stato.apri(.posizioni)
            }
            .buttonStyle(StileSemplice())
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Colonna.collegamento)
        }
        .padding(12)
    }

    private func sceltaCheckUp(report: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SegmentiAnalisi(opzioni: [(false, "Prospetto"), (true, "Report")],
                            selezione: Binding(get: { report }, set: { stato.prospetto = .checkUp(report: $0); archiviato = nil }))
            Text(report ? "Report per il cliente: chi sei, la fotografia, il semaforo, da dove partire, la sintesi."
                        : "Prospetto per te: anagrafica e profilo, fotografia per area e canale, semaforo di sette aree, bisogni rilevati, prossimi passi e firme.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
            Text("Dopo il primo incontro: anagrafica e famiglia dal dossier, patrimonio dalle Posizioni, ipotesi dall'Analisi 360, bisogni dal profilo dei bisogni. Più dati si raccolgono, meno semafori restano grigi.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
    }

    private func sceltaLiquidita(report: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SegmentiAnalisi(opzioni: [(false, "Prospetto"), (true, "Report")],
                            selezione: Binding(get: { report }, set: { stato.prospetto = .liquidita(report: $0); archiviato = nil }))
            Text(report ? "Report per il cliente: cosa arriva, i quattro salvadanai, il costo dell'attesa, la sintesi."
                        : "Prospetto per te: capitali in scadenza al centesimo, conti, salvadanai, confronto fermo o destinato, metodo e firme.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
            Text("Capitali in scadenza e conti dalle Posizioni; fabbisogno mensile e mesi di riserva dall'Analisi 360 (area Protezione); i salvadanai seguono gli Obiettivi del cliente.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
    }

    private func sceltaObiettivo(_ id: String, report: Bool) -> some View {
        let elenco = stato.obiettiviCliente(cliente)
        let mie = stato.posizioniCliente(cliente)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(elenco) { o in
                let a = AvanzamentoObiettivo(o, posizioni: mie)
                Button {
                    archiviato = nil
                    stato.prospetto = .obiettivo(o.id, report: report)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(o.titolo).font(Tipo.tabellaCellaForte).foregroundColor(o.id == id ? .white : Colori.Analisi.tabellaTesto).lineLimit(1)
                        Text("\(Formati.euro(o.importo)) · \(Formati.dataBreve.string(from: o.scadenza)) · \(Int((a.quota * 100).rounded()))%")
                            .font(Tipo.chip).foregroundColor(o.id == id ? Color.white.opacity(0.85) : Colori.Analisi.kpiNota)
                    }
                    .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(o.id == id ? AnyShapeStyle(Gradienti.navAnalisi) : AnyShapeStyle(Color.clear))
                    .bordoBasso(Colori.Strumenti.ipotesiRiga)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StileSemplice())
            }
            VStack(alignment: .leading, spacing: 10) {
                if elenco.contains(where: { $0.id == id }) {
                    SegmentiAnalisi(opzioni: [(false, "Prospetto"), (true, "Report")],
                                    selezione: Binding(get: { report }, set: { stato.prospetto = .obiettivo(id, report: $0); archiviato = nil }))
                }
                Text("Importo, scadenza, rendimento e posizioni collegate si modificano nell'app Obiettivi.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
                Button("Apri Obiettivi") {
                    stato.obiettivoSelezionato = id.isEmpty ? nil : id
                    stato.apri(.obiettivi)
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
            }
            .padding(12)
        }
    }

    private func sceltaProtezione(report: Bool) -> some View {
        let voci = report
            ? ["Copertina in cuoio: famiglia, fabbisogno, tutele", "La tua famiglia e ciò che le serve", "Se ti succedesse qualcosa",
               "Se non potessi lavorare", "La mappa delle tutele", "Quanto costa proteggersi, in sintesi"]
            : ["Famiglia, fabbisogno caso morte e divario", "Invalidità, malattia e riserva", "Mappa dei rischi coperti e scoperti",
               "Coperture per canale, costo per 1.000 €", "Scadenze da verificare", "Premi, detrazione del 19%, metodo e firme"]
        return VStack(alignment: .leading, spacing: 10) {
            SegmentiAnalisi(opzioni: [(false, "Prospetto"), (true, "Report")],
                            selezione: Binding(get: { report }, set: { stato.prospetto = .protezione(report: $0); archiviato = nil }))
            VStack(alignment: .leading, spacing: 7) {
                ForEach(voci, id: \.self) { voce in
                    HStack(alignment: .top, spacing: 7) {
                        Text("•").foregroundColor(Colori.Analisi.navBasso)
                        Text(voce).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(Tipo.strumentoTesto)
                    .foregroundColor(Colori.Analisi.tabellaTesto)
                }
            }
            Text("Fabbisogno, anni di sostegno, entrate sostitutive e riserva vengono dall'Analisi 360 (area Protezione); la famiglia dal dossier del cliente; le coperture dalle Posizioni.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
            Button("Apri l'Analisi 360") {
                stato.areaAnalisi = .protezione
                stato.apri(.analisi360)
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
        }
        .padding(12)
    }

    private func sceltaPrevidenza(report: Bool) -> some View {
        let voci = report
            ? ["Copertina in cuoio: pensione, divario, piani", "Quanto ti servirà: il divario", "Cosa hai già: la rendita dei piani",
               "Come colmare il resto, con la proposta", "Il vantaggio fiscale dei versamenti", "Le tasse sulla pensione, in sintesi"]
            : ["Divario, rendita dei piani e versamento che manca", "Ogni piano alla pensione con l'aliquota di allora",
               "Deducibilità e risparmio IRPEF", "Aliquota della prestazione nel tempo", "Uscite di oggi per causa, al centesimo",
               "Montante anno per anno, scenari, metodo e firme"]
        return VStack(alignment: .leading, spacing: 10) {
            SegmentiAnalisi(opzioni: [(false, "Prospetto"), (true, "Report")],
                            selezione: Binding(get: { report }, set: { stato.prospetto = .previdenza(report: $0); archiviato = nil }))
            VStack(alignment: .leading, spacing: 7) {
                ForEach(voci, id: \.self) { voce in
                    HStack(alignment: .top, spacing: 7) {
                        Text("•").foregroundColor(Colori.Analisi.navBasso)
                        Text(voce).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(Tipo.strumentoTesto)
                    .foregroundColor(Colori.Analisi.tabellaTesto)
                }
            }
            Text("Età di pensione, reddito desiderato, pensione pubblica e anni di integrazione vengono dall'Analisi 360 (area Previdenza); il reddito lordo annuo dal profilo del cliente; i piani dalle Posizioni.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
            Button("Apri l'Analisi 360") {
                stato.areaAnalisi = .previdenza
                stato.apri(.analisi360)
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
        }
        .padding(12)
    }

    private func sceltaSostituzione(_ a: String, _ b: String, report: Bool) -> some View {
        let elenco = posizioniOrdinate.filter { $0.area.proiettabile }
        let attuale = elenco.first { $0.id == a }
        return VStack(alignment: .leading, spacing: 10) {
            SegmentiAnalisi(opzioni: [(false, "Prospetto"), (true, "Report")],
                            selezione: Binding(get: { report }, set: { stato.prospetto = .sostituzione(a, b, report: $0); archiviato = nil }))
            Text(report ? "Report per il cliente: A4 orizzontale, restare o cambiare spiegato una pagina alla volta."
                        : "Prospetto per te: A4 verticale, uscita di oggi, netto anno per anno, scenari, costi e caratteristiche.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
            sceltaPosizioneSostituzione(attuale?.stato == .proposta ? "PRIMA PROPOSTA" : "OGGI · DA SOSTITUIRE", elenco: elenco,
                                        selezione: Binding(get: { a }, set: { stato.prospetto = .sostituzione($0, b == $0 ? a : b, report: report); archiviato = nil }))
            sceltaPosizioneSostituzione(attuale?.stato == .proposta ? "SECONDA PROPOSTA" : "ALTERNATIVA", elenco: elenco.filter { $0.stato == .proposta || $0.id == b },
                                        selezione: Binding(get: { b }, set: { stato.prospetto = .sostituzione(a == $0 ? b : a, $0, report: report); archiviato = nil }))
            Toggle("Orizzonte della proposta", isOn: Binding(
                get: { stato.orizzonteSostituzione == nil },
                set: { stato.orizzonteSostituzione = $0 ? nil : (stato.testiSostituzione(a, b)?.e.anni ?? IpotesiCalcolo.orizzontePredefinito) }))
                .font(Tipo.strumentoTesto)
            if let anni = stato.orizzonteSostituzione {
                Stepper(value: Binding(get: { anni }, set: { stato.orizzonteSostituzione = min(max($0, 1), 50) }), in: 1...50) {
                    Text("\(anni) \(anni == 1 ? "anno" : "anni")").font(Tipo.strumentoTesto)
                }
            }
            Text("Se la prima voce è in essere, cambiare vuol dire chiuderla oggi (penale, bollo, imposte) e reinvestire il netto. Le due strade ricevono gli stessi versamenti futuri. Tra due fondi pensione è un trasferimento senza imposte.")
                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
    }

    private func sceltaPosizioneSostituzione(_ titolo: String, elenco: [Posizione], selezione: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titolo).font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
            Picker("", selection: selezione) {
                ForEach(elenco) { p in Text("\(p.nome) · \(p.stato == .proposta ? "proposta" : "in essere") · \(p.canale.nomeBreve)").tag(p.id) }
            }
            .labelsHidden()
        }
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
            if scelta.spuntoEve != nil {
                Button("✦ Chiedi a Eve") { stato.chiediEveDelDocumento(scelta) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    .fixedSize()
                    .disabled(stato.eveInCorso)
                    .help("Eve spiega le cifre di questo documento, per te")
            }
            // I pulsanti non vanno a capo: in una finestra stretta si accorcia il titolo
            Button("Stampa…") { if let dati = pdf(d) { StampaCarta.stampa(dati, formato: d.formato) } }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                .fixedSize()
            // Il portafoglio riguarda tutti i clienti: non va nei documenti di uno di loro
            if scelta.tipo != .portafoglio {
                Button("Archivia nei Documenti") {
                    if let dati = pdf(d) { archiviato = stato.archiviaProspetto(dati, documento: d) }
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                .fixedSize()
            }
            Button("Salva PDF…") { if let dati = pdf(d) { StampaCarta.salva(dati, nome: StampaCarta.nomeFile(d)) } }
                .buttonStyle(StileBlu())
                .fixedSize()
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

/// Il commento del consulente nel report: Eve scrive la bozza dalle cifre del documento, il consulente
/// la rilegge, la modifica e la salva. Compare nella pagina «Due parole per te», dopo la copertina.
private struct PannelloCommento: View {
    @EnvironmentObject var stato: StatoShell
    let scelta: SceltaProspetto
    @State private var testo = ""
    @State private var caricato = false
    @State private var confermaRiscrivi = false

    static func nota(_ c: CommentoReport) -> String {
        let data = "salvato il \(Formati.dataEstesa.string(from: c.aggiornatoIl))"
        guard let chi = c.bozzaDi else { return "Scritto da te, " + data }
        return "Prima stesura: \(chi), " + data
    }

    var body: some View {
        let salvato = stato.commento(scelta)
        VStack(alignment: .leading, spacing: 8) {
            Text("IL COMMENTO DEL CONSULENTE").font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
            if salvato == nil && testo.isEmpty {
                Text("Una lettera breve al cliente, nella pagina dopo la copertina. Eve la scrive con le cifre del report; tu la rileggi e la cambi come vuoi.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
            } else {
                TextEditor(text: $testo)
                    .font(Tipo.kpiNota)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .frame(height: 210)
                    .background(RoundedRectangle(cornerRadius: Misure.Strumenti.raggio).fill(Colori.Strumenti.carta))
                    .overlay(RoundedRectangle(cornerRadius: Misure.Strumenti.raggio).strokeBorder(Colori.Strumenti.schedaBordo, lineWidth: 1))
                    // Mentre Eve scrive non si modifica: il suo testo sostituirebbe quello digitato
                    .disabled(stato.eveInCorso)
                HStack {
                    if let s = salvato {
                        Text(PannelloCommento.nota(s)).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    }
                    Spacer()
                    Text("\(testo.count) / \(CommentoEve.limite)")
                        .font(Tipo.kpiNota)
                        .foregroundColor(testo.count > CommentoEve.limite ? Colori.Analisi.erroreTesto : Colori.Analisi.kpiNota)
                }
                if testo.count > CommentoEve.limite {
                    Text("Il testo è troppo lungo per la pagina: accorcialo per salvarlo.")
                        .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.erroreTesto)
                }
            }
            HStack(spacing: 6) {
                Button(stato.eveInCorso ? "Eve scrive…" : (salvato == nil ? "✦ Scrivi con Eve" : "✦ Riscrivi")) {
                    // Il commento salvato o le modifiche in corso non si perdono senza chiedere
                    if salvato != nil || !testo.isEmpty { confermaRiscrivi = true } else { stato.scriviCommentoConEve(scelta) }
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 9, bottom: 4, trailing: 9)))
                .disabled(stato.eveInCorso)
                if !testo.isEmpty && testo != salvato?.testo {
                    Button("Salva") { stato.salvaCommento(scelta, testo: testo, bozzaDi: salvato?.bozzaDi) }
                        .buttonStyle(StileBlu())
                        .disabled(testo.count > CommentoEve.limite)
                }
                if salvato != nil {
                    Button("Togli") { stato.salvaCommento(scelta, testo: ""); testo = "" }
                        .buttonStyle(StileSemplice())
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.Colonna.collegamento)
                }
            }
        }
        .padding(12)
        .confirmationDialog("Eve riscrive il commento", isPresented: $confermaRiscrivi) {
            Button("Riscrivi con Eve", role: .destructive) { stato.scriviCommentoConEve(scelta) }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Il testo attuale del commento viene sostituito dalla nuova stesura di Eve.")
        }
        .onAppear { if !caricato { testo = salvato?.testo ?? ""; caricato = true } }
        .onChange(of: salvato?.aggiornatoIl) { _ in testo = stato.commento(scelta)?.testo ?? "" }
        .onChange(of: salvato?.testo) { nuovo in testo = nuovo ?? "" }
    }
}
