import SwiftUI

/// App Obiettivi (.os-app-goals): i progetti del cliente con un importo e una data.
/// L'accantonato conta anche il valore delle posizioni collegate; l'app calcola quanto
/// manca e il versamento mensile per arrivare in tempo. Gli eventi di vita suggeriscono gli obiettivi.
struct AppObiettivi: View {
    @EnvironmentObject var stato: StatoShell
    @State var modulo: Obiettivo?
    @State var confermaEliminazione = false

    private var cliente: String { stato.clienteAttivoId }
    private var elenco: [Obiettivo] { stato.obiettiviCliente(cliente) }
    private var scelto: Obiettivo? { elenco.first { $0.id == stato.obiettivoSelezionato } ?? elenco.first }

    var body: some View {
        CorniceStrumento(
            notaStato: "Calcoli eseguiti in locale · piano a rendimento costante, probabilità da scenari simulati · nessuna garanzia di risultato",
            notaDestra: "\(elenco.count) \(elenco.count == 1 ? "obiettivo" : "obiettivi")"
        ) {
            rail
        } contenuto: {
            if elenco.isEmpty {
                vuoto
            } else {
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            TitoloStrumento(occhiello: "Il quaderno dei progetti", titolo: "Un nome al futuro.",
                                            testo: "Ogni obiettivo ha un importo e una data: Prisma calcola quanto manca e quanto mettere da parte ogni mese.")
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(elenco) { o in scheda(o) }
                            }
                            suggerimenti
                        }
                        .padding(EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18))
                    }
                    if let o = scelto {
                        dettaglio(o)
                            .frame(width: 340)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(Colori.Strumenti.ipotesiBordo).frame(width: Tema.Misura.filo)
                            }
                    }
                }
            }
        }
        .sheet(item: $modulo) { o in
            ModuloObiettivo(bozza: o, nuovo: !stato.dati.obiettivi.contains { $0.id == o.id }) { stato.salvaObiettivo($0) }
        }
        .alert("Eliminare l'obiettivo?", isPresented: $confermaEliminazione) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) { if let o = scelto { stato.eliminaObiettivo(o.id) } }
        } message: {
            Text("Le posizioni collegate restano in Posizioni.")
        }
    }

    private func nuovo(_ titolo: String = "", area: AreaBisogno = .patrimonio, anno: Int? = nil) {
        let cal = Calendar.current
        let scadenza = anno.flatMap { cal.date(from: DateComponents(year: $0, month: 6, day: 30)) }
            ?? cal.date(byAdding: .year, value: 5, to: Date()) ?? Date()
        modulo = Obiettivo(clienteId: cliente, titolo: titolo, area: area, importo: 20_000, scadenza: cal.startOfDay(for: scadenza))
    }

    // MARK: - Elenco laterale

    @ViewBuilder private var rail: some View {
        DossierRail()
        EtichettaRail(testo: "Obiettivi")
        VStack(spacing: 0) {
            ForEach(elenco) { o in
                VoceNavigazione(titolo: o.titolo, colore: Colori.Bisogni.area(o.area), attiva: o.id == scelto?.id) {
                    stato.obiettivoSelezionato = o.id
                }
            }
        }
        Button("＋ Nuovo obiettivo") { nuovo() }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
            .padding(.top, 4)
        CollegatiRail(app: [.simulazioni, .analisi360, .posizioni])
    }

    private var vuoto: some View {
        VStack(spacing: 10) {
            Text("◎").font(Tipo.risultatoGrande).foregroundColor(Colori.Analisi.lineaTratteggiata)
            Text("Nessun obiettivo, per ora").font(Tipo.strumentoTitolo).foregroundColor(Colori.Strumenti.titolo)
            Text("Dai un nome e una data ai progetti del cliente: la casa, gli studi dei figli, la pensione, un margine di serenità.")
                .font(Tipo.strumentoTesto).foregroundColor(Colori.Analisi.kpiNota)
                .multilineTextAlignment(.center).frame(maxWidth: 460)
            Button("＋ Nuovo obiettivo") { nuovo() }.buttonStyle(StileBlu())
            suggerimenti.frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Schede

    private func scheda(_ o: Obiettivo) -> some View {
        let a = AvanzamentoObiettivo(o, posizioni: stato.posizioniCliente(cliente))
        let attiva = o.id == scelto?.id
        return Button { stato.obiettivoSelezionato = o.id } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(o.area.nome.uppercased()).font(Tipo.chip).tracking(0.5).foregroundColor(Colori.Bisogni.area(o.area))
                    Spacer()
                    Text(o.priorita.nome.uppercased())
                        .font(Tipo.bisognoArea).foregroundColor(Tema.Colore.Componenti.testoSuColore)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background {
                            FormaVetro.arrotondata(Tema.Raggio.Strumenti.priorita).fill(Colori.Bisogni.importanza(o.priorita))
                        }
                }
                Text(o.titolo).font(Tipo.schedaAreaTitolo).foregroundColor(Colori.Strumenti.schedaTitolo).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int((a.quota * 100).rounded()))%").font(Tipo.schedaAreaValore).foregroundColor(Colori.Strumenti.schedaValore)
                    Text("\(Formati.euro(a.accantonato)) di \(Formati.euro(o.importo))").font(Tipo.schedaAreaNota).foregroundColor(Colori.Strumenti.schedaNota)
                }
                BarraAvanzamento(quota: a.quota, colore: Colori.Bisogni.area(o.area))
                HStack {
                    Text("entro \(Formati.meseAnno.string(from: o.scadenza))").font(Tipo.chip).foregroundColor(Colori.Strumenti.schedaNota)
                    Spacer()
                    Text(a.mancante <= 0 ? "Raggiunto ✓" : a.versamentoNecessario.map { "servono \(Formati.euro($0))/mese" } ?? "scadenza passata")
                        .font(Tipo.chip)
                        .foregroundColor(a.mancante <= 0 ? Colori.Bisogni.confermato
                                         : (a.versamentoNecessario ?? 0) > a.versamentiAttivi ? Colori.Analisi.attenzioneTesto : Colori.Strumenti.schedaNota)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 17, bottom: 12, trailing: 15))
            .frame(maxWidth: .infinity, alignment: .leading)
            .schedaColorata(Colori.Bisogni.area(o.area), scelta: attiva)
        }
        .buttonStyle(StileSemplice())
    }

    /// Obiettivi suggeriti dagli eventi di vita che non ne hanno ancora uno.
    @ViewBuilder private var suggerimenti: some View {
        let eventi = stato.cliente(cliente)?.bisogni.eventi ?? []
        let proposte = eventi.compactMap { e -> (String, AreaBisogno, Int)? in
            guard let t = Self.titoloPerEvento(e.tipo) else { return nil }
            let gia = elenco.contains { $0.area == t.1 && Calendar.current.component(.year, from: $0.scadenza) == e.anno }
            return gia ? nil : (t.0, t.1, e.anno)
        }
        if !proposte.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("SUGGERITI DAGLI EVENTI DI VITA").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Strumenti.occhiello)
                ForEach(proposte, id: \.0) { p in
                    HStack {
                        Text("\(p.0) · \(String(p.2))").font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto)
                        Spacer()
                        Button("Crea l'obiettivo") { nuovo(p.0, area: p.1, anno: p.2) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                    }
                    .padding(.vertical, 4)
                    .bordoBasso(Colori.Analisi.tabellaRiga)
                }
            }
        }
    }

    static func titoloPerEvento(_ t: EventoVita.Tipo) -> (String, AreaBisogno)? {
        switch t {
        case .acquistoCasa: return ("Anticipo per la casa", .casa)
        case .studiFigli: return ("Studi dei figli", .famiglia)
        case .figlioInArrivo: return ("L'arrivo di un figlio", .famiglia)
        case .avvioAttivita: return ("Avvio dell'attività", .lavoro)
        case .pensione: return ("Capitale per la pensione", .pensione)
        case .matrimonio: return ("Progetti di coppia", .famiglia)
        case .cambioLavoro, .separazione, .eredita, .altro: return nil
        }
    }

    // MARK: - Dettaglio

    private func dettaglio(_ o: Obiettivo) -> some View {
        let posizioni = stato.posizioniCliente(cliente).filter { $0.stato == .inEssere && !$0.area.passivo && $0.area != .protezione && $0.area != .immobili }
        let a = AvanzamentoObiettivo(o, posizioni: posizioni)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(o.area.nome.uppercased()).font(Tipo.chip).tracking(0.5).foregroundColor(Colori.Bisogni.area(o.area))
                Text(o.titolo).font(Tipo.dettaglioTitolo).foregroundColor(Colori.Strumenti.titolo)
                    .fixedSize(horizontal: false, vertical: true)
                if !o.note.isEmpty {
                    Text(o.note).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 0) {
                    RigaDato("Obiettivo", Formati.euro(o.importo), larghezza: 130)
                    RigaDato("Entro", "\(Formati.dataEstesa.string(from: o.scadenza)) (\(o.mesiMancanti) mesi)", larghezza: 130)
                    RigaDato("Già da parte", Formati.euro(a.accantonato), larghezza: 130)
                    RigaDato("Mancano", Formati.euro(a.mancante), larghezza: 130)
                    RigaDato("Versamento necessario", a.mancante <= 0 ? "Obiettivo raggiunto"
                             : a.versamentoNecessario.map { "\(Formati.euro($0)) al mese al \(Formati.percentuale(o.rendimento))" } ?? "Scadenza passata",
                             larghezza: 130)
                    RigaDato("Versamenti già attivi", "\(Formati.euro(a.versamentiAttivi)) al mese", larghezza: 130)
                }
                if a.mancante > 0, let v = a.versamentoNecessario, v > a.versamentiAttivi {
                    NotaMetodo(testo: "Con i versamenti attivi mancano \(Formati.euro(v - a.versamentiAttivi)) al mese: si può allungare la data, ridurre l'importo o aggiungere un piano. Il simulatore parte già da questi numeri.")
                }
                // Scenari con le probabilità: calcolati una volta all'apertura e ricordati (non a ogni ridisegno)
                if o.scadenza > Date() {
                    SezioneProbabilitaObiettivo(esito: CacheMotoriAnalisi.scenari(o, posizioni: posizioni), importo: o.importo)
                        .padding(.vertical, Tema.Misura.MotoriAnalisi.spazioElenco)
                }
                Text("POSIZIONI CHE LAVORANO PER L'OBIETTIVO").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Strumenti.occhiello)
                if posizioni.isEmpty {
                    Text("Nessuna posizione adatta in essere.").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                }
                ForEach(posizioni) { p in
                    let collegata = o.posizioniCollegate.contains(p.id)
                    Toggle(isOn: Binding(get: { collegata }, set: { si in
                        var x = o
                        x.posizioniCollegate.removeAll { $0 == p.id }
                        if si { x.posizioniCollegate.append(p.id) }
                        stato.salvaObiettivo(x)
                    })) {
                        HStack(spacing: 6) {
                            Text(p.nome).font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                            EtichettaCanale(canale: p.canale, compatta: true)
                            Spacer(minLength: 4)
                            Text(Formati.euro(p.valore)).font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.kpiNota)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                VStack(spacing: 6) {
                    PulsanteAzione(titolo: "Simula il piano", principale: true) { stato.simula(o) }
                    HStack(spacing: 6) {
                        PulsanteAzione(titolo: "Modifica") { modulo = o }
                        PulsanteAzione(titolo: "＋ Attività") {
                            var t = Attivita.nuova(clienteId: o.clienteId, scadenza: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date())
                            t.titolo = "Verificare il piano per: \(o.titolo)"
                            stato.salvaAttivita(t)
                            stato.mostraAvviso("Attività aggiunta: \(t.titolo)")
                        }
                    }
                    PulsanteAzione(titolo: "Prospetto e report") { stato.apriProspetto(.obiettivo(o.id, report: false)) }
                    Button("Elimina l'obiettivo…") { confermaEliminazione = true }
                        .buttonStyle(StileSemplice())
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.Analisi.erroreTesto)
                        .padding(.top, 2)
                }
                .padding(.top, 6)
            }
            .padding(14)
        }
        .background(Colori.Strumenti.risultati)
    }
}

/// Barra di avanzamento (.os-progress): capsula nel pozzetto scuro, riempita del colore dell'area.
struct BarraAvanzamento: View {
    let quota: Double
    let colore: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(Colori.Attivita.progressoFondo)
                Capsule(style: .continuous).fill(colore)
                    .frame(width: max(0, geo.size.width * CGFloat(min(max(quota, 0), 1))))
            }
        }
        .frame(height: Misure.Attivita.progresso)
    }
}

/// Modulo dell'obiettivo.
struct ModuloObiettivo: View {
    @Environment(\.dismiss) var chiudi
    @State var bozza: Obiettivo
    let nuovo: Bool
    let salva: (Obiettivo) -> Void

    private static let numero = FloatingPointFormatStyle<Double>.number.locale(Formati.localeImporti)

    var body: some View {
        CorniceModulo(titolo: nuovo ? "Nuovo obiettivo" : "Modifica l'obiettivo") {
            VStack(alignment: .leading, spacing: 14) {
                CampoModulo(etichetta: "Il progetto") {
                    TextField("Per esempio Anticipo per la casa", text: $bozza.titolo).textFieldStyle(.roundedBorder)
                }
                CampoModulo(etichetta: "Area di vita") {
                    Picker("", selection: $bozza.area) {
                        ForEach(AreaBisogno.allCases) { Text($0.nome).tag($0) }
                    }
                    .labelsHidden().frame(width: 220)
                }
                CampoModulo(etichetta: "Importo, in euro di oggi") { euro($bozza.importo) }
                CampoModulo(etichetta: "Entro") {
                    DatePicker("", selection: $bozza.scadenza, displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.field).environment(\.locale, Formati.italiano)
                }
                CampoModulo(etichetta: "Priorità") {
                    Picker("", selection: $bozza.priorita) {
                        ForEach([Importanza.bassa, .media, .alta]) { Text($0.nome).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 220)
                }
                CampoModulo(etichetta: "Già da parte (oltre alle posizioni)") { euro($bozza.accantonato) }
                CampoModulo(etichetta: "Rendimento ipotizzato") {
                    HStack(spacing: 6) {
                        TextField("", value: $bozza.rendimento, format: Self.numero)
                            .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 70)
                        Text("% annuo, per il versamento necessario").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                    }
                }
                CampoModulo(etichetta: "Note") { TextField("", text: $bozza.note).textFieldStyle(.roundedBorder) }
            }
        } piede: {
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button(nuovo ? "Aggiungi" : "Salva") {
                var o = bozza
                o.titolo = o.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
                o.creatoIl = Appuntamento.alMinuto(o.creatoIl)
                salva(o)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(bozza.titolo.trimmingCharacters(in: .whitespaces).isEmpty || bozza.importo <= 0)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 560, height: 480)
    }

    private func euro(_ valore: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            TextField("0", value: valore, format: Self.numero)
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 120)
            Text("€").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
        }
    }
}
