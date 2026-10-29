import SwiftUI

/// App Incontri (.os-app-meetings): il quaderno di lavoro della relazione.
/// 01 Preparazione: i temi (dalle priorità del cliente) e cosa c'è nel dossier.
/// 02 Ascolto: le tre domande aperte, gli appunti e le decisioni.
/// 03 Prossimi passi: dagli appunti nascono bisogni, eventi di vita e attività da confermare;
///    la chiusura aggiorna il profilo dei bisogni, le attività e l'agenda.
struct AppIncontri: View {
    @EnvironmentObject var stato: StatoShell
    @State var confermaEliminazione = false

    private var cliente: String { stato.clienteAttivoId }
    private var elenco: [Incontro] { stato.incontriCliente(cliente) }

    /// L'incontro aperto: quello scelto, altrimenti il primo da preparare, altrimenti il più recente.
    private var corrente: Incontro? {
        if let i = stato.incontro(stato.incontroAperto), i.clienteId == cliente { return i }
        return elenco.first { $0.stato == .preparazione } ?? elenco.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            barra
            if let i = corrente {
                SegmentiAnalisi(opzioni: [(SchedaIncontro.preparazione, "01 · Preparazione"), (.ascolto, "02 · Ascolto"),
                                          (.passi, "03 · Prossimi passi")],
                                selezione: $stato.schedaIncontro)
                    .frame(width: Misure.IncontriImpaginazione.fasi)
                // Ogni fase si impagina sullo spazio che resta: le schede riempiono la larghezza
                // e la barra in basso resta sempre dentro la finestra
                GeometryReader { geo in
                    fase(i, area: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                piede(i)
            } else {
                vuoto
            }
        }
        .alert("Eliminare questo incontro?", isPresented: $confermaEliminazione) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                // Prima gli appunti in attesa: scritti dopo, rimetterebbero l'incontro nell'archivio
                TestiRinviati.scriviOra()
                if let i = corrente { stato.eliminaIncontro(i.id) }
            }
        } message: {
            Text("Appunti e decisioni verranno tolti dal dossier. Attività e appuntamenti già creati restano. Se serve, potrai recuperarlo da un backup.")
        }
        // L'esito della proposta dopo «Archivia l'incontro»: solo le richieste di Incontri, così Posizioni aperto
        // insieme non lo presenta una seconda volta
        .sheet(item: richiestaEsitoIncontri) { r in
            ModuloEsitoProposta(richiesta: r)
                .environmentObject(stato)
        }
    }

    /// La richiesta dell'esito solo se viene da Incontri (le altre le presenta Posizioni).
    private var richiestaEsitoIncontri: Binding<RichiestaEsito?> {
        Binding<RichiestaEsito?>(
            get: {
                guard let r = stato.richiestaEsito, r.origine == .incontri else { return nil }
                return r
            },
            set: { stato.richiestaEsito = $0 }
        )
    }

    @ViewBuilder private func fase(_ i: Incontro, area: CGSize) -> some View {
        switch stato.schedaIncontro {
        case .preparazione: preparazione(i, area: area)
        case .ascolto: ascolto(i, area: area)
        case .passi:
            if i.stato == .concluso { concluso(i) } else { passi(i, area: area) }
        }
    }

    private func legame(_ i: Incontro) -> Binding<Incontro> {
        Binding(get: { stato.incontro(i.id) ?? i }, set: { stato.salvaIncontro($0) })
    }

    // MARK: - Barra

    private var barra: some View {
        HStack(spacing: 10) {
            MenuTendina(selezione: $stato.clienteAttivoId,
                        opzioni: stato.clienti.map { ($0.id, $0.nome) },
                        larghezza: 190)
            if !elenco.isEmpty {
                MenuTendina(selezione: Binding(get: { corrente?.id ?? "" }, set: { stato.incontroAperto = $0 }),
                            opzioni: elenco.map { i in
                                (i.id, "\(Formati.dataBreve.string(from: i.data)) · \(i.titolo)\(i.stato == .concluso ? " ✓" : "")")
                            },
                            larghezza: 330)
            }
            if let i = corrente {
                Text(i.stato == .concluso ? "Concluso" : "In preparazione · \(Formati.dataOra.string(from: i.data))")
                    .font(Tipo.incontroNota)
                    .foregroundColor(i.stato == .concluso ? Colori.Incontri.concluso : Colori.Incontri.secondario)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            Button("＋ Nuovo incontro") { stato.nuovoIncontro(cliente: cliente) }
                .buttonStyle(StileBlu())
        }
    }

    private var vuoto: some View {
        VStack(spacing: 10) {
            Text("◷").font(Tipo.risultatoGrande).foregroundColor(Colori.Incontri.citazione)
            Text("Un incontro, tutto al suo posto.").font(Tipo.eveBenvenuto).foregroundColor(Colori.Incontri.testo)
            Text("Prepara i temi, ascolta il cliente e trasforma le decisioni in prossimi passi: il profilo dei bisogni si aggiorna da solo.")
                .font(Tipo.incontroTesto)
                .foregroundColor(Colori.Incontri.secondario)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Button("Prepara il primo incontro") { stato.nuovoIncontro(cliente: cliente) }
                .buttonStyle(StileBlu())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 01 Preparazione

    private static let temi: [(AreaAnalisi, String, String)] = [
        (.previdenza, "Quale reddito mantenere dopo il lavoro?", "Pensione stimata, età di uscita, contributi e piani già attivi."),
        (.protezione, "Chi dipende da questo reddito?", "Debiti, sostegno della famiglia, riserve e condizioni delle polizze."),
        (.investimenti, "Qual è lo scopo del capitale?", "Orizzonte, costi, liquidità necessaria e capacità di reggere le perdite."),
        (.risparmio, "Quanto dedicare ogni mese al progetto?", "Importo, scadenza e impegni già presenti."),
    ]

    private func preparazione(_ i: Incontro, area: CGSize) -> some View {
        let m = Misure.IncontriImpaginazione.self
        // Stretta, la colonna delle priorità va sotto le schede; larga, è proporzionata alla finestra
        let sotto = area.width < m.sogliaColonnaSotto
        let colonna = m.colonna(area.width)
        let colonne = m.colonneTemi(sotto ? area.width : area.width - colonna - m.spazio)
        let confermate = stato.analisi360(i.clienteId).confermate
        return ScrollView {
            if sotto {
                VStack(alignment: .leading, spacing: m.spazio) {
                    grigliaTemi(i, colonne: colonne, confermate: confermate)
                    colonnaDossier(i)
                }
            } else {
                // Schede e colonna alte uguali: le schede si allungano fino in fondo alla colonna (o il contrario)
                HStack(alignment: .top, spacing: m.spazio) {
                    grigliaTemi(i, colonne: colonne, confermate: confermate)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    colonnaDossier(i)
                        .frame(width: colonna)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Le quattro schede dei temi in file da 4, 2 o 1: riempiono la larghezza e, nella stessa fila, sono alte uguali.
    private func grigliaTemi(_ i: Incontro, colonne: Int, confermate: [AreaAnalisi]) -> some View {
        let m = Misure.IncontriImpaginazione.self
        let passo = max(1, colonne)
        let file = stride(from: 0, to: Self.temi.count, by: passo).map { Array(Self.temi[$0..<min($0 + passo, Self.temi.count)]) }
        return VStack(alignment: .leading, spacing: m.spazio) {
            ForEach(file.indices, id: \.self) { r in
                HStack(alignment: .top, spacing: m.spazio) {
                    ForEach(file[r], id: \.0) { tema in
                        schedaTema(i, tema, confermata: confermate.contains(tema.0))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func schedaTema(_ i: Incontro, _ tema: (AreaAnalisi, String, String), confermata: Bool) -> some View {
        let b = legame(i)
        let scelto = i.temi.contains(tema.0)
        return VStack(alignment: .leading, spacing: 6) {
            Toggle(tema.0.nome, isOn: Binding(get: { scelto }, set: { si in
                var x = b.wrappedValue
                x.temi.removeAll { $0 == tema.0 }
                if si { x.temi.append(tema.0) }
                b.wrappedValue = x
            }))
            .toggleStyle(.checkbox)
            .font(Tipo.incontroOcchiello)
            .disabled(i.stato == .concluso)
            Text(tema.1).font(Tipo.incontroDomanda).foregroundColor(Colori.Incontri.testo)
                .fixedSize(horizontal: false, vertical: true)
            Text(tema.2).font(Tipo.incontroNota).foregroundColor(Colori.Incontri.secondario)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            HStack {
                Text(confermata ? "Dati confermati" : "Da verificare")
                    .font(Tipo.incontroNota)
                    .foregroundColor(confermata ? Colori.Incontri.concluso : Colori.Incontri.secondario)
                    .lineLimit(1)
                Spacer(minLength: Misure.IncontriImpaginazione.staccoNota)
                Button("Apri l'analisi ↗") {
                    stato.areaAnalisi = tema.0
                    stato.apri(.analisi360)
                }
                .buttonStyle(StileSemplice())
                .font(Tipo.incontroNota)
                .foregroundColor(Colori.Colonna.collegamento)
                .fixedSize()
            }
            .padding(.top, 5)
            .bordoAlto(Colori.Incontri.filo)
        }
        .padding(Misure.IncontriImpaginazione.margine)
        .frame(maxWidth: .infinity, minHeight: Misure.IncontriImpaginazione.temaAltezzaMinima,
               maxHeight: .infinity, alignment: .topLeading)
        .modifier(CartaIncontro())
        .opacity(scelto ? 1 : 0.6)
    }

    private func colonnaDossier(_ i: Incontro) -> some View {
        let rilevati = stato.bisogniRilevati(i.clienteId)
        let profilo = stato.cliente(i.clienteId)?.bisogni ?? ProfiloBisogni()
        let ruota = MotoreBisogni.ruota(rilevati, profilo: profilo)
        let priorita = MotoreBisogni.priorita(rilevati, profilo: profilo)
        let posizioni = stato.posizioniCliente(i.clienteId)
        let scadenze = posizioni.filter { $0.scadeEntro(RiepilogoPosizioni.giorniScadenza) }
        let proposte = posizioni.filter { $0.stato == .proposta && $0.esito != .accettata && $0.esito != .rifiutata }
        let precedente = stato.incontriCliente(i.clienteId).first { $0.stato == .concluso && $0.id != i.id }
        // Niente scorrimento proprio: la colonna è alta quanto il suo contenuto (scorre la pagina intera)
        // e, accanto alle schede, i pulsanti si allineano al fondo della griglia
        return VStack(alignment: .leading, spacing: 10) {
            Text("LE PRIORITÀ DEL CLIENTE").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Incontri.citazione)
            if priorita.isEmpty {
                Text("Ruota dei bisogni ancora vuota: l'ascolto di oggi la costruisce.")
                    .font(Tipo.incontroNota).foregroundColor(Colori.Incontri.secondario)
            }
            ForEach(Array(priorita.prefix(3).enumerated()), id: \.element) { n, a in
                HStack(spacing: 8) {
                    Text("\(n + 1)").font(Tipo.prioritaNumero).foregroundColor(Colori.Bisogni.area(a)).frame(width: 18)
                    Text(a.nome).font(Tipo.incontroTitolo).foregroundColor(Colori.Incontri.testo)
                    Spacer()
                    Text((ruota[a] ?? .nessuna).nome).font(Tipo.incontroNota).foregroundColor(Colori.Bisogni.importanza(ruota[a] ?? .nessuna))
                }
            }
            Text("DAL DOSSIER").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Incontri.citazione).padding(.top, 6)
            ForEach(scadenze) { p in
                Text("• \(p.nome) scade il \(Formati.dataEstesa.string(from: p.scadenza ?? Date()))")
                    .font(Tipo.incontroNota).foregroundColor(Colori.Incontri.testo)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(proposte) { p in
                Text("• Proposta aperta: \(p.nome) (\(p.canale.nomeBreve))").font(Tipo.incontroNota).foregroundColor(Colori.Incontri.testo)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Raggruppati: la colonna resta entro i dieci elementi del ViewBuilder (macOS 13)
            Group {
                if scadenze.isEmpty && proposte.isEmpty {
                    Text("Nessuna scadenza vicina e nessuna proposta aperta.").font(Tipo.incontroNota).foregroundColor(Colori.Incontri.secondario)
                }
                CambiatoDalRiesame(clienteId: i.clienteId)
            }
            if let p = precedente {
                Text("L'ULTIMA VOLTA").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Incontri.citazione).padding(.top, 6)
                Text("\(Formati.dataEstesa.string(from: p.data)) · \(p.titolo)").font(Tipo.incontroNota).foregroundColor(Colori.Incontri.secondario)
                Text(p.decisioni.isEmpty ? "Nessuna decisione registrata." : p.decisioni)
                    .font(Tipo.incontroScrittura)
                    .foregroundColor(Colori.Incontri.testo)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Misure.IncontriImpaginazione.staccoPulsanti)
            VStack(spacing: 6) {
                PulsanteAzione(titolo: "✦ Prepara con Eve") {
                    stato.apri(.eve)
                    stato.chiediEve(SpuntoEve.incontro.domanda, spunto: .incontro)
                }
                PulsanteAzione(titolo: "Inizia l'ascolto →", principale: true) { stato.schedaIncontro = .ascolto }
            }
        }
        .padding(Misure.IncontriImpaginazione.margine)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(CartaIncontro())
    }

    // MARK: - 02 Ascolto

    private func ascolto(_ i: Incontro, area: CGSize) -> some View {
        let m = Misure.IncontriImpaginazione.self
        let b = legame(i)
        let solaLettura = i.stato == .concluso
        // Le tre domande in fila se c'è posto, altrimenti una sotto l'altra; così appunti e decisioni
        let inFila = area.width >= m.domandaMinima * 3 + m.spazio * 2
        let affiancati = area.width >= m.appuntiMinimi * 2 + m.spazio
        let domande = inFila ? AnyLayout(HStackLayout(alignment: .top, spacing: m.spazio))
                             : AnyLayout(VStackLayout(alignment: .leading, spacing: m.spazio))
        let appunti = affiancati ? AnyLayout(HStackLayout(alignment: .top, spacing: m.spazio))
                                 : AnyLayout(VStackLayout(alignment: .leading, spacing: m.spazio))
        // I campi crescono con la finestra: le domande con una quota dell'altezza, appunti e decisioni con il resto
        let altezzaDomanda = m.limita(area.height * m.quotaDomanda, m.domandaAltezza)
        let altezzaAppunti = m.limita(area.height - altezzaDomanda - m.riservaAscolto, m.appuntiAltezza)
        return ScrollView {
            VStack(alignment: .leading, spacing: m.spazio) {
                domande {
                    ForEach(DomandaAscolto.allCases) { d in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(d.domanda).font(Tipo.incontroDomanda).foregroundColor(Colori.Incontri.testo)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(d.suggerimento).font(Tipo.incontroNota).foregroundColor(Colori.Incontri.secondario)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            // Un campo per incontro e domanda: cambiando incontro la bozza riparte da quello nuovo
                            FoglioRighe(testo: campo(b, d), solaLettura: solaLettura, salvaOra: { stato.salvaOra() })
                                .id("\(i.id)-\(d.id)")
                                .frame(height: altezzaDomanda)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .modifier(CartaIncontro())
                    }
                }
                // Nella stessa fila le schede sono alte uguali (i suggerimenti possono andare a capo)
                .fixedSize(horizontal: false, vertical: true)
                appunti {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("APPUNTI DELL'INCONTRO").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Incontri.citazione)
                        FoglioRighe(testo: b.appunti, solaLettura: solaLettura, salvaOra: { stato.salvaOra() })
                            .id("\(i.id)-appunti")
                            .frame(height: altezzaAppunti)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .modifier(CartaIncontro())
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DECISIONI CONDIVISE").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Incontri.citazione)
                        FoglioRighe(testo: b.decisioni, solaLettura: solaLettura, salvaOra: { stato.salvaOra() })
                            .id("\(i.id)-decisioni")
                            .frame(height: altezzaAppunti)
                        Text("Una decisione per riga, con il verbo all'inizio («Preparare…», «Inviare…»): diventeranno attività.")
                            .font(Tipo.incontroNota).foregroundColor(Colori.Incontri.secondario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .modifier(CartaIncontro())
                }
                .fixedSize(horizontal: false, vertical: true)
                if !solaLettura {
                    HStack {
                        Spacer()
                        Button("Ai prossimi passi →") {
                            // Gli appunti appena scritti entrano nell'archivio prima di ricavarne le proposte
                            TestiRinviati.scriviOra()
                            stato.schedaIncontro = .passi
                            if let x = stato.incontro(i.id) { stato.estraiProposte(x) }
                        }
                        .buttonStyle(StileBlu())
                    }
                }
            }
        }
    }

    private func campo(_ b: Binding<Incontro>, _ d: DomandaAscolto) -> Binding<String> {
        switch d {
        case .preoccupazioni: return b.preoccupazioni
        case .progetti: return b.progetti
        case .esperienza: return b.esperienza
        }
    }

    // MARK: - 03 Prossimi passi

    @ViewBuilder private func passi(_ i: Incontro, area: CGSize) -> some View {
        let m = Misure.IncontriImpaginazione.self
        if area.width < m.sogliaColonnaSotto {
            // Stretta: le proposte e, sotto, il prossimo passo scorrono insieme
            ScrollView {
                VStack(alignment: .leading, spacing: m.spazio) {
                    contenutoProposte(i)
                        .padding(m.margine)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .modifier(CartaIncontro())
                    pannelloPasso(i)
                }
            }
        } else {
            HStack(alignment: .top, spacing: m.spazio) {
                // Poche proposte: la scheda è alta quanto il contenuto; tante: scorre dentro la finestra
                ViewThatFits(in: .vertical) {
                    contenutoProposte(i)
                        .padding(m.margine)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .modifier(CartaIncontro())
                    ScrollView {
                        contenutoProposte(i)
                            .padding(m.margine)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .modifier(CartaIncontro())
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                // Su uno schermo molto basso anche il prossimo passo scorre, invece di finire sotto il bordo
                ViewThatFits(in: .vertical) {
                    pannelloPasso(i)
                    ScrollView(.vertical, showsIndicators: false) { pannelloPasso(i) }
                }
                .frame(width: m.colonna(area.width))
            }
        }
    }

    private func contenutoProposte(_ i: Incontro) -> some View {
        let proposte = stato.proposteIncontro[i.id]
        return VStack(alignment: .leading, spacing: 10) {
            TitoloStrumento(occhiello: "Dalle parole al dossier", titolo: "Cosa ho capito dall'incontro",
                            testo: "Proposte ricavate dalle risposte e dagli appunti. Spunta quelle giuste: alla chiusura entrano nel profilo dei bisogni e nelle attività.")
            HStack(spacing: 8) {
                Button(proposte == nil ? "Leggi gli appunti" : "Rileggi gli appunti") { stato.estraiProposte(i) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    .disabled(i.vuoto || stato.estrazioneInCorso)
                if stato.estrazioneInCorso {
                    ProgressView().controlSize(.small)
                    Text("Anche Qwen sta leggendo…").font(Tipo.incontroNota).foregroundColor(Colori.Incontri.secondario)
                }
            }
            if i.vuoto {
                Text("Gli appunti sono ancora vuoti: scrivili nella scheda Ascolto.")
                    .font(Tipo.incontroTesto).foregroundColor(Colori.Incontri.secondario)
            } else if let proposte {
                if proposte.isEmpty {
                    Text("Nessuna proposta: gli appunti non citano bisogni, eventi o decisioni riconoscibili.")
                        .font(Tipo.incontroTesto).foregroundColor(Colori.Incontri.secondario)
                }
                ForEach(proposte) { p in rigaProposta(p) }
            }
        }
    }

    /// Il prossimo passo e la chiusura: alta quanto il suo contenuto, il pulsante subito sotto le scelte.
    private func pannelloPasso(_ i: Incontro) -> some View {
        let b = legame(i)
        return VStack(alignment: .leading, spacing: 10) {
            Text("IL PROSSIMO PASSO").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Incontri.citazione)
            TextField("Attività concordata (facoltativa)", text: b.prossimaAttivita).textFieldStyle(.roundedBorder)
            CampoDataFacoltativa(data: b.scadenzaAttivita,
                                 predefinita: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                                 etichetta: "Entro una data", font: Tipo.incontroNota)
            Text("PROSSIMO INCONTRO").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Incontri.citazione).padding(.top, 6)
            HStack(spacing: 8) {
                Toggle("Da fissare", isOn: Binding(get: { i.prossimoIncontro != nil }, set: { si in
                    var x = b.wrappedValue
                    x.prossimoIncontro = si ? (x.prossimoIncontro ?? Self.trentaGiorni) : nil
                    b.wrappedValue = x
                }))
                .toggleStyle(.checkbox)
                .font(Tipo.incontroNota)
                if i.prossimoIncontro != nil {
                    DatePicker("", selection: Binding(get: { i.prossimoIncontro ?? Self.trentaGiorni },
                                                      set: { b.wrappedValue.prossimoIncontro = $0 }),
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .environment(\.locale, Formati.italiano)
                }
            }
            Text("Alla chiusura: le proposte spuntate entrano nel profilo dei bisogni, l'attività in Attività, il seguito in Agenda; l'appuntamento di oggi risulta concluso. Nessun messaggio viene inviato.")
                .font(Tipo.incontroNota)
                .foregroundColor(Colori.Incontri.secondario)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Misure.IncontriImpaginazione.staccoNota)
                .bordoAlto(Colori.Incontri.filo)
            PulsanteAzione(titolo: "Chiudi e archivia l'incontro", principale: true) { stato.chiudiIncontro(i.id) }
        }
        .padding(Misure.IncontriImpaginazione.margine)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(CartaIncontro())
    }

    private static var trentaGiorni: Date {
        let giorno = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: giorno) ?? giorno
    }

    private func rigaProposta(_ p: PropostaIncontro) -> some View {
        let scelta = stato.proposteScelte.contains(p.id)
        return Button {
            if scelta { stato.proposteScelte.remove(p.id) } else { stato.proposteScelte.insert(p.id) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: scelta ? "checkmark.square.fill" : "square")
                    .foregroundColor(scelta ? Colori.Analisi.navBasso : Colori.Incontri.secondario)
                    .font(Tema.Testo.Strumenti.spunta)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(etichetta(p)).font(Tipo.bisognoArea).foregroundColor(colore(p))
                        Text(p.titolo).font(Tipo.incontroTitolo).foregroundColor(Colori.Incontri.testo)
                    }
                    if !p.fonte.isEmpty {
                        Text("«\(p.fonte)»")
                            .font(Tipo.incontroNota)
                            .italic()
                            .foregroundColor(Colori.Incontri.citazione)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(p.origine).font(Tipo.chip).foregroundColor(Colori.Incontri.secondario)
                }
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 9, leading: 11, bottom: 9, trailing: 11))
            .background {
                FormaVetro.arrotondata(Tema.Raggio.Strumenti.proposta)
                    .fill(scelta ? Colori.Incontri.citazioneFondo : Color.clear)
            }
            .overlay {
                FormaVetro.arrotondata(Tema.Raggio.Strumenti.proposta)
                    .strokeBorder(Colori.Incontri.filo, lineWidth: Tema.Misura.filo)
            }
        }
        .buttonStyle(StileSemplice())
    }

    private func etichetta(_ p: PropostaIncontro) -> String {
        switch p.tipo {
        case .bisogno: return "BISOGNO"
        case .evento: return "EVENTO DI VITA"
        case .attivita: return "ATTIVITÀ"
        }
    }

    private func colore(_ p: PropostaIncontro) -> Color {
        switch p.tipo {
        case .bisogno(let a, _): return Colori.Bisogni.area(a)
        case .evento: return Colori.Bisogni.importanza(.media)
        case .attivita: return Colori.Analisi.navBasso
        }
    }

    // MARK: - Incontro concluso

    private func concluso(_ i: Incontro) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("✓").font(Tipo.risultatoGrande).foregroundColor(Colori.Incontri.concluso)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Il percorso continua.").font(Tipo.eveBenvenuto).foregroundColor(Colori.Incontri.testo)
                        Text("Incontro concluso il \(Formati.dataEstesa.string(from: i.data)). Appunti e decisioni restano nel dossier.")
                            .font(Tipo.incontroTesto).foregroundColor(Colori.Incontri.secondario)
                    }
                }
                HStack(spacing: 8) {
                    // La proposta presentata all'incontro aspetta ancora l'esito
                    if let a = stato.appuntamento(i.appuntamentoId), let p = stato.propostaDaChiudere(a) {
                        Button("Esito della proposta «\(p.nome)»") {
                            stato.apriEsito(p, passo: MotoreSeguitoProposte.passoIniziale(a), origine: .incontri, appuntamentoId: a.id)
                        }
                        .buttonStyle(StileBlu())
                        .lineLimit(1)
                    }
                    if let t = i.attivitaCreataId, stato.attivita.contains(where: { $0.id == t }) {
                        Button("Attività concordata ↗") {
                            stato.attivitaSelezionata = t
                            stato.apri(.attivita)
                        }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    }
                    if let a = stato.appuntamento(i.appuntamentoCreatoId) {
                        Button("Prossimo incontro ↗") { stato.mostraInAgenda(a) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    }
                    Button("Profilo dei bisogni ↗") {
                        stato.schedaCliente = .bisogni
                        stato.apri(.clienti)
                    }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                }
                ForEach([("Cosa la preoccupa", i.preoccupazioni), ("I suoi progetti", i.progetti), ("La sua esperienza", i.esperienza),
                         ("Appunti", i.appunti), ("Decisioni condivise", i.decisioni)].filter { !$0.1.isEmpty }, id: \.0) { voce in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(voce.0.uppercased()).font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Incontri.citazione)
                        Text(voce.1).font(Tipo.incontroScrittura).foregroundColor(Colori.Incontri.testo)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(CartaIncontro())
                }
            }
        }
    }

    // MARK: - Piede

    private func piede(_ i: Incontro) -> some View {
        HStack {
            Text(i.stato == .concluso ? "Incontro archiviato · in sola lettura" : "Bozza di lavoro · si salva da sola")
                .font(Tipo.incontroNota)
                .foregroundColor(Colori.Incontri.secondario)
            Spacer()
            Button("Elimina l'incontro…") { confermaEliminazione = true }
                .buttonStyle(StileSemplice())
                .font(Tipo.incontroNota)
                .foregroundColor(Colori.Analisi.erroreTesto)
        }
    }
}

/// Scheda del quaderno degli incontri (.meeting-topic-grid > article): il vetro sottile del tema.
/// Il contenuto (anche quello che scorre) si taglia alla forma prima del vetro, come vuole il tema.
struct CartaIncontro: ViewModifier {
    func body(content: Content) -> some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.Strumenti.scheda)
        return content
            .clipShape(forma)
            .vetro(.sottile, forma: forma)
    }
}

/// Il campo in cui si scrivono domande, appunti e decisioni: pozzetto arrotondato del tema. Il testo passa
/// all'incontro poco dopo l'ultimo tasto (TestoRinviato): chi lo usa gli dà un `.id` per incontro e campo.
struct FoglioRighe: View {
    @Binding var testo: String
    var solaLettura = false
    /// Chiamata alla chiusura di Prisma dopo aver scritto il testo in attesa (di solito `stato.salvaOra`).
    var salvaOra: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topLeading) {
            if solaLettura {
                ScrollView {
                    Text(testo.isEmpty ? "—" : testo)
                        .font(Tipo.incontroScrittura)
                        .foregroundColor(Colori.Incontri.testo)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            } else {
                TestoRinviato(testo: $testo, salvaOra: salvaOra) { bozza in
                    TextEditor(text: bozza)
                        .font(Tipo.incontroScrittura)
                        .foregroundColor(Colori.Incontri.testo)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
            }
        }
        .padding(4)
        .pozzettoTestoLungo()
    }
}
