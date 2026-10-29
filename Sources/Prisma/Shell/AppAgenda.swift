import SwiftUI

/// App Agenda (.os-app-agenda): la fascia in testa, la scheda con la settimana (o il mese),
/// la pagina della giornata e il dettaglio dell'appuntamento. Nella giornata compaiono anche
/// le posizioni in scadenza: ogni scadenza è l'occasione per rivedere la posizione del cliente.
/// Sopra il calendario c'è lo strato delle occasioni (le date in cui cambia qualcosa nelle posizioni e nella
/// famiglia) e la vista «Occasioni» le mostra tutte, mese per mese, per 12 mesi (AgendaOccasioni.swift).
struct AppAgenda: View {
    @EnvironmentObject var stato: StatoShell
    @State var modulo: Appuntamento?
    @State var moduloAttivita: Attivita?
    /// La striscia «Riesami del mese» ridotta a una riga (dura quanto la sessione, non va nell'archivio).
    @State var riesamiRidotti = false
    /// La riga in testa al modulo dopo «Pianifica» (nil per le altre aperture del modulo).
    @State var spiegazioneModulo: String?

    private var cal: Calendar { CalendarioAgenda.cal }
    private var giorno: Date { stato.giornoAgenda }

    var body: some View {
        GeometryReader { geo in
            // I riesami del mese mostrato: in un mese passato la striscia non compare, e nemmeno nella vista
            // «Occasioni», che guarda 12 mesi mentre la striscia ne guarda uno
            let riesami: RiesamiDelMese? = stato.vistaAgenda == .occasioni ? nil : stato.riesamiDelMese(giorno)
            let mesePassato = giorno < (cal.dateInterval(of: .month, for: Date())?.start ?? giorno)
            VStack(spacing: 0) {
                fascia
                if let riesami, !riesami.vuota && !mesePassato {
                    striscia(riesami, compatta: geo.size.height < Misure.RiesamiAgenda.sogliaAltezzaPiena)
                        .padding(.top, Tema.Misura.Dossier.spazioAgenda)
                }
                libro
                    .padding(.top, Tema.Misura.Dossier.spazioAgenda)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .sheet(item: $modulo) { a in
            ModuloAppuntamento(
                bozza: a,
                nuovo: !stato.appuntamenti.contains { $0.id == a.id },
                salva: { stato.salvaAppuntamento($0) },
                elimina: { stato.eliminaAppuntamento(a.id) },
                spiegazione: spiegazioneModulo
            )
            .environmentObject(stato)
        }
        .sheet(item: $moduloAttivita) { t in
            ModuloAttivita(bozza: t, nuova: !stato.attivita.contains { $0.id == t.id },
                           salva: { stato.salvaAttivita($0) }, elimina: { stato.eliminaAttivita(t.id) })
                .environmentObject(stato)
        }
    }

    private func nuovoAppuntamento() {
        spiegazioneModulo = nil
        modulo = Appuntamento.nuovo(clienteId: stato.filtroClienteAgenda ?? stato.clienteAttivoId, giorno: giorno)
    }

    // MARK: - Riesami del mese

    private func striscia(_ r: RiesamiDelMese, compatta: Bool) -> some View {
        let oggi = Date()
        let massimo = Misure.RiesamiAgenda.massimoSchede
        // Le schede si calcolano solo per i clienti mostrati (il riesame di ognuno è in memoria per un'ora)
        let voci = r.daFissare.prefix(massimo).map { voceRiesame($0, oggi: oggi) }
        return StrisciaRiesami(
            titoloMese: Formati.meseAnno.string(from: giorno).capitalized,
            voci: voci,
            altri: max(0, r.daFissare.count - massimo),
            fissati: r.fissati.count,
            compatta: compatta,
            solaLettura: stato.solaLettura,
            ridotta: $riesamiRidotti,
            prepara: { id in
                stato.clienteAttivoId = id
                stato.apriProspetto(.riesame)
            },
            pianifica: { id in pianifica(id) },
            apriPortafoglio: {
                stato.portafoglio = true
                stato.apri(.posizioni)
            }
        )
    }

    /// La scheda di un riesame da fissare: stato, punti dell'ordine del giorno e canali delle posizioni.
    private func voceRiesame(_ d: RiesameDovuto, oggi: Date) -> VoceRiesameAgenda {
        let testo: String
        if let dal = d.dovutoDal {
            // L'anno solo se non è quello di oggi
            let stessoAnno = cal.component(.year, from: dal) == cal.component(.year, from: oggi)
            let data = stessoAnno ? Formati.giornoMese.string(from: dal) : Formati.dataEstesa.string(from: dal)
            testo = d.scaduto(oggi) ? "Scaduto dal \(data)" : "Dovuto dal \(data)"
        } else {
            testo = "Mai incontrato in Prisma"
        }
        let r = stato.riesameCliente(d.id)
        return VoceRiesameAgenda(
            id: d.id,
            nome: d.cliente.nome,
            iniziali: d.cliente.iniziali,
            tinta: d.cliente.tinta.colori,
            stato: testo,
            scaduto: d.scaduto(oggi),
            punti: r?.punti.count,
            alta: r?.punti.filter { $0.priorita == .alta }.count ?? 0,
            canali: MotorePianificazione.canali(stato.posizioniCliente(d.id))
        )
    }

    /// Il riesame nel primo spazio libero negli orari di lavoro, da completare nel modulo.
    private func pianifica(_ id: String) {
        guard let p = stato.pianificaRiesame(id, mese: giorno) else { return }
        spiegazioneModulo = p.spiegazione(orari: stato.dati.impostazioni.orari)
        modulo = p.appuntamento
    }

    // MARK: - Cuoio

    private var periodo: String {
        switch stato.vistaAgenda {
        case .mese:
            return Formati.meseAnno.string(from: giorno).capitalized
        case .occasioni:
            // I 12 mesi della vista: dal primo del mese mostrato all'undicesimo mese dopo
            let inizio = cal.dateInterval(of: .month, for: giorno)?.start ?? giorno
            let fine = cal.date(byAdding: .month, value: RegoleOccasioni.mesiElenco - 1, to: inizio) ?? inizio
            return "\(Formati.meseAnno.string(from: inizio)) — \(Formati.meseAnno.string(from: fine))".capitalized
        case .settimana:
            let giorni = CalendarioAgenda.giorni(settimanaDi: giorno)
            guard let primo = giorni.first, let ultimo = giorni.last else { return "" }
            return "\(Formati.giornoMese.string(from: primo)) — \(Formati.dataEstesa.string(from: ultimo))"
        }
    }

    /// La fascia in testa: sempre una riga sola. Nome dell'app e occhiello stanno già nella barra della finestra,
    /// qui restano il motto e il periodo mostrato, e il calendario guadagna spazio.
    private var fascia: some View {
        HStack(alignment: .firstTextBaseline, spacing: Misure.AgendaImpaginazione.spazioFascia) {
            Text("Il tuo tempo, con cura.")
                .font(Tipo.agendaTitolo)
                .foregroundColor(Colori.Agenda.cuoioTitolo)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(periodo)
                .font(Tipo.agendaPeriodo)
                .foregroundColor(Colori.Agenda.cuoioTesto)
                .lineLimit(1)
        }
        .padding(Misure.AgendaImpaginazione.fasciaCompatta)
        .frame(maxWidth: .infinity)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.scheda))
    }

    // MARK: - Libro

    private var libro: some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.scheda)
        let vista = stato.vistaAgenda
        // Appuntamenti, scadenze e occasioni dei giorni visibili, raggruppati una volta sola (solo settimana e mese)
        let settimane = vista == .mese ? CalendarioAgenda.settimane(meseDi: giorno) : []
        let indice: GiorniAgenda
        switch vista {
        case .settimana: indice = stato.giorniAgenda(CalendarioAgenda.giorni(settimanaDi: giorno))
        case .mese: indice = stato.giorniAgenda(settimane.flatMap { $0 })
        case .occasioni: indice = GiorniAgenda()
        }
        // Le occasioni di 12 mesi solo nella vista «Occasioni»
        let elenco = vista == .occasioni ? stato.elencoOccasioniAgenda : []
        return VStack(spacing: 0) {
            barraStrumenti
            // A sinistra il calendario e la giornata (o l'elenco delle occasioni), a destra il dettaglio a tutta
            // altezza (come l'ispettore del Calendario): con il mese aperto il dettaglio non si schiaccia più
            GeometryReader { geo in
                let larghezza = Misure.AgendaImpaginazione.dettaglio(geo.size.width)
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        switch vista {
                        case .settimana:
                            settimana(indice)
                            paginaGiorno(indice)
                        case .mese:
                            mese(settimane, indice)
                            paginaGiorno(indice)
                        case .occasioni:
                            ElencoOccasioniAgenda(elenco: elenco)
                        }
                    }
                    .frame(width: max(0, geo.size.width - larghezza))
                    dettaglio(indice, elenco: elenco)
                        .frame(width: larghezza)
                }
            }
        }
        // Una scheda del tema, come la fascia: il contenuto si taglia alla forma prima del vetro
        .clipShape(forma)
        .vetro(.sottile, forma: forma)
    }

    /// La barra sopra il calendario: tutta intera se c'è posto; nelle finestre strette il menu dei clienti
    /// si stringe e «Appuntamento» diventa la sola icona «+» (con il suggerimento). Il selettore della vista
    /// è sempre largo quanto le sue voci: nessuna parola tagliata, nessun pulsante a capo.
    private var barraStrumenti: some View {
        ViewThatFits(in: .horizontal) {
            rigaStrumenti(compatta: false)
            rigaStrumenti(compatta: true)
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 7, trailing: 12))
        .bordoBasso(Colori.Agenda.settimanaBordo)
    }

    private func rigaStrumenti(compatta: Bool) -> some View {
        let m = Misure.AgendaImpaginazione.self
        let viste: [(VistaAgenda, String)] = [(.settimana, "Settimana"), (.mese, "Mese"), (.occasioni, "Occasioni")]
        let clienti: [(String?, String)] = [(String?.none, "Tutti i clienti")] + stato.clienti.map { (Optional($0.id), $0.nome) }
        let mese = stato.vistaAgenda != .settimana
        return HStack(spacing: 8) {
            HStack(spacing: 4) {
                PulsanteIcona(simbolo: "chevron.left", aiuto: mese ? "Mese precedente" : "Settimana precedente") {
                    sposta(-1)
                }
                .fixedSize()
                Button("Oggi") {
                    stato.giornoAgenda = cal.startOfDay(for: Date())
                    stato.appuntamentoSelezionato = nil
                    stato.occasioneSelezionata = nil
                }
                .buttonStyle(StileVetro())
                .fixedSize()
                .help("Torna alla data di oggi")
                PulsanteIcona(simbolo: "chevron.right", aiuto: mese ? "Mese successivo" : "Settimana successiva") {
                    sposta(1)
                }
                .fixedSize()
            }
            ControlloSegmenti(opzioni: viste, selezione: $stato.vistaAgenda)
                .fixedSize()
            Spacer(minLength: 0)
            MenuTendina(selezione: $stato.filtroClienteAgenda, opzioni: clienti,
                        larghezza: compatta ? m.menuClientiCompatto : m.menuClienti)
            // Il blu della finestra: l'azione che porta avanti il lavoro dell'Agenda
            if compatta {
                Button { nuovoAppuntamento() } label: { Image(systemName: "plus") }
                    .buttonStyle(StileBlu())
                    .fixedSize()
                    .help("Nuovo appuntamento")
                    .accessibilityLabel("Nuovo appuntamento")
            } else {
                Button { nuovoAppuntamento() } label: { Label("Appuntamento", systemImage: "plus") }
                    .buttonStyle(StileBlu())
                    .fixedSize()
                    .help("Nuovo appuntamento")
            }
        }
    }

    private func sposta(_ verso: Int) {
        // Il mese anche per la vista «Occasioni»
        let componente: Calendar.Component = stato.vistaAgenda == .settimana ? .weekOfYear : .month
        stato.giornoAgenda = cal.date(byAdding: componente, value: verso, to: giorno) ?? giorno
        stato.appuntamentoSelezionato = nil
        stato.occasioneSelezionata = nil
    }

    // MARK: - Settimana e mese

    private func seleziona(_ g: Date) {
        stato.giornoAgenda = cal.startOfDay(for: g)
        stato.appuntamentoSelezionato = nil
        stato.occasioneSelezionata = nil
    }

    /// Lo strato delle occasioni nella settimana e nel mese (Impostazioni › Occasioni).
    private var strato: Bool { stato.dati.impostazioni.occasioni.inAgenda }

    /// I colori delle occasioni di un giorno (vuoto con lo strato spento).
    private func segni(_ indice: GiorniAgenda, _ g: Date) -> SegniOccasioni {
        strato ? SegniOccasioni(indice.occasioni(g)) : SegniOccasioni()
    }

    private func settimana(_ indice: GiorniAgenda) -> some View {
        HStack(spacing: 4) {
            ForEach(CalendarioAgenda.giorni(settimanaDi: giorno), id: \.self) { g in
                let colonna = (cal.component(.weekday, from: g) + 5) % 7
                GiornoSettimanaAgenda(
                    nome: CalendarioAgenda.nomiGiorni[colonna], giorno: g,
                    incontri: indice.appuntamenti(g).count,
                    scadenze: indice.scadenze(g).count,
                    selezionato: cal.isDate(g, inSameDayAs: giorno),
                    oggi: cal.isDateInToday(g),
                    occasioni: segni(indice, g)
                ) { seleziona(g) }
            }
        }
        .padding(Misure.AgendaImpaginazione.calendario)
        .bordoBasso(Colori.Agenda.settimanaBordo)
    }

    private func mese(_ settimane: [[Date]], _ indice: GiorniAgenda) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                ForEach(CalendarioAgenda.nomiGiorni, id: \.self) { n in
                    Text(n.uppercased())
                        .font(Tipo.giornoNota)
                        .tracking(0.4)
                        .foregroundColor(Colori.Agenda.giorno)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(settimane, id: \.self) { s in
                HStack(spacing: 2) {
                    ForEach(s, id: \.self) { g in
                        CellaMeseAgenda(
                            giorno: g,
                            nelMese: cal.isDate(g, equalTo: giorno, toGranularity: .month),
                            incontri: indice.appuntamenti(g).count,
                            scadenze: indice.scadenze(g).count,
                            selezionato: cal.isDate(g, inSameDayAs: giorno),
                            oggi: cal.isDateInToday(g),
                            occasioni: segni(indice, g)
                        ) { seleziona(g) }
                    }
                }
            }
        }
        .padding(Misure.AgendaImpaginazione.calendario)
        .bordoBasso(Colori.Agenda.settimanaBordo)
    }

    // MARK: - Pagina della giornata

    private func paginaGiorno(_ indice: GiorniAgenda) -> some View {
        let eventi = indice.appuntamenti(giorno)
        let scadenze = indice.scadenze(giorno)
        let occasioni = strato ? indice.occasioni(giorno) : []
        let selezionato = eventoSelezionato(eventi)
        let occasioneScelta = stato.occasioneSelezionata?.id
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Formati.giornoSettimana.string(from: giorno).uppercased())
                    .font(Tipo.paginaOcchiello)
                    .tracking(0.8)
                    .foregroundColor(Colori.Agenda.paginaOcchiello)
                Text(Formati.giornoMese.string(from: giorno))
                    .font(Tipo.paginaTitolo)
                    .foregroundColor(Colori.Agenda.paginaTitolo)
                Spacer(minLength: 0)
                Text("\(eventi.count) \(eventi.count == 1 ? "appuntamento" : "appuntamenti")")
                    .font(Tipo.paginaNota)
                    .foregroundColor(Colori.Agenda.paginaNota)
            }
            .padding(EdgeInsets(top: 10, leading: 16, bottom: 9, trailing: 16))

            ScrollView {
                // Pigro: con molti clienti una giornata ha decine di appuntamenti e scadenze
                LazyVStack(spacing: 0) {
                    ForEach(eventi) { e in
                        RigaEventoAgenda(
                            evento: e, cliente: stato.cliente(e.clienteId)?.nome ?? "Cliente",
                            canale: stato.canaleAppuntamento(e),
                            selezionato: e.id == selezionato?.id && occasioneScelta == nil
                        ) {
                            stato.appuntamentoSelezionato = e.id
                            stato.occasioneSelezionata = nil
                        }
                    }
                    if !scadenze.isEmpty {
                        Text("IN SCADENZA")
                            .font(Tipo.paginaOcchiello)
                            .tracking(1.2)
                            .foregroundColor(Colori.Agenda.scadenzaTesto)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                        ForEach(scadenze) { p in
                            RigaScadenzaAgenda(posizione: p, cliente: stato.cliente(p.clienteId)?.nome ?? "Cliente") {
                                stato.apriPosizione(p)
                            }
                        }
                    }
                    if !occasioni.isEmpty {
                        Text("OCCASIONI")
                            .font(Tipo.paginaOcchiello)
                            .tracking(Misure.Occasioni.tracciaOcchiello)
                            .foregroundColor(Colori.Agenda.occasioneOcchiello)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Misure.Occasioni.occhiello)
                        ForEach(occasioni) { o in
                            RigaOccasioneAgenda(occasione: o, cliente: stato.cliente(o.clienteId)?.nome ?? "Cliente",
                                                selezionata: o.id == occasioneScelta) {
                                stato.occasioneSelezionata = o
                                stato.appuntamentoSelezionato = nil
                            }
                        }
                    }
                    if eventi.isEmpty && scadenze.isEmpty && occasioni.isEmpty {
                        vuoto
                    }
                }
            }
            .bordoAlto(Colori.Agenda.rigaBordo)

            notaSettimana(indice)
        }
    }

    private func eventoSelezionato(_ eventi: [Appuntamento]) -> Appuntamento? {
        eventi.first { $0.id == stato.appuntamentoSelezionato } ?? eventi.first
    }

    private var vuoto: some View {
        VStack(spacing: 6) {
            Text(Formati.giorno.string(from: giorno))
                .font(Tipo.vuotoData)
                .foregroundColor(Colori.Agenda.vuotoData)
            Text("Una pagina ancora libera.")
                .font(Tipo.vuotoTitolo)
                .foregroundColor(Colori.Agenda.vuotoTitolo)
            Text("Nessun appuntamento \(stato.filtroClienteAgenda == nil ? "" : "per questo cliente ")in questa giornata.")
                .font(Tipo.vuotoTesto)
                .foregroundColor(Colori.Agenda.vuotoTesto)
                .multilineTextAlignment(.center)
            // Il blu resta «Appuntamento» nella barra: qui l'azione consigliata in vetro dell'accento
            Button { nuovoAppuntamento() } label: { Label("Aggiungi un incontro", systemImage: "plus") }
                .buttonStyle(StileVetro(accento: true))
                .fixedSize()
                .padding(.top, 6)
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        .frame(maxWidth: .infinity)
    }

    private func notaSettimana(_ indice: GiorniAgenda) -> some View {
        let giorni = CalendarioAgenda.giorni(settimanaDi: giorno)
        let eventi = giorni.flatMap { indice.appuntamenti($0) }
        let daSvolgere = eventi.filter { $0.stato != .concluso }
        let minuti = daSvolgere.reduce(0) { $0 + $1.durataMinuti }
        let scadenze = giorni.reduce(0) { $0 + indice.scadenze($1).count }
        let occasioni = strato ? giorni.reduce(0, { $0 + indice.occasioni($1).count }) : 0
        // Il periodo dei conteggi: la settimana del giorno scelto, anche nella vista del mese
        let corrente = giorni.contains { cal.isDateInToday($0) }
        let periodo = corrente ? "QUESTA SETTIMANA"
            : "SETTIMANA DEL \(giorni.first.map { Formati.giornoMeseBreve.string(from: $0) } ?? "")".uppercased()
        // Se la riga non ci sta, prima si toglie il tempo riservato: il periodo resta sempre intero
        return ViewThatFits(in: .horizontal) {
            rigaSettimana(periodo, daSvolgere: daSvolgere.count, riservati: CalendarioAgenda.durata(minuti),
                          scadenze: scadenze, occasioni: occasioni)
            rigaSettimana(periodo, daSvolgere: daSvolgere.count, riservati: nil, scadenze: scadenze, occasioni: occasioni)
        }
        .font(Tipo.notaSettimana)
        .foregroundColor(Colori.Agenda.notaSettimana)
        .lineLimit(1)
        .padding(EdgeInsets(top: 7, leading: 15, bottom: 7, trailing: 15))
        .bordoAlto(Colori.Agenda.notaSettimanaBordo)
    }

    private func rigaSettimana(_ periodo: String, daSvolgere: Int, riservati: String?, scadenze: Int, occasioni: Int) -> some View {
        HStack(spacing: 6) {
            Text(periodo)
                .font(Tipo.paginaOcchiello)
                .tracking(1.2)
                .fixedSize()
                .layoutPriority(1)
                .padding(.trailing, 5)
            Text("\(daSvolgere) da svolgere").font(Tipo.notaSettimanaForte)
            if let riservati {
                Text("·")
                Text("\(riservati) riservati").font(Tipo.notaSettimanaForte)
            }
            if scadenze > 0 {
                Text("·")
                Text("\(scadenze) \(scadenze == 1 ? "scadenza" : "scadenze")").font(Tipo.notaSettimanaForte)
            }
            if occasioni > 0 {
                Text("·")
                Text("\(occasioni) \(occasioni == 1 ? "occasione" : "occasioni")").font(Tipo.notaSettimanaForte)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Dettaglio

    private func dettaglio(_ indice: GiorniAgenda, elenco: [Occasione]) -> some View {
        Group {
            if let o = occasioneMostrata(indice, elenco: elenco) {
                DettaglioOccasione(
                    occasione: o,
                    nuovoAppuntamento: {
                        spiegazioneModulo = nil
                        modulo = $0
                    },
                    nuovaAttivita: { moduloAttivita = $0 }
                )
            } else if stato.vistaAgenda == .occasioni {
                QuietoOccasioni()
            } else if let e = eventoSelezionato(indice.appuntamenti(giorno)) {
                DettaglioAppuntamento(
                    evento: e,
                    modifica: {
                        spiegazioneModulo = nil
                        modulo = e
                    },
                    nuovaAttivita: {
                        var t = Attivita.nuova(clienteId: e.clienteId, scadenza: e.inizio)
                        t.titolo = "Preparare: \(e.titolo)"
                        t.appuntamentoId = e.id
                        moduloAttivita = t
                    }
                )
            } else {
                quieto
            }
        }
        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Colori.Agenda.dettaglioFondo)
        .overlay(alignment: .leading) {
            Rectangle().fill(Colori.Agenda.dettaglioBordo).frame(width: Tema.Misura.filo)
        }
    }

    /// L'occasione scelta, ritrovata per id tra quelle mostrate (il giorno o i 12 mesi): se i dati sono cambiati
    /// e non c'è più, il dettaglio torna quieto.
    private func occasioneMostrata(_ indice: GiorniAgenda, elenco: [Occasione]) -> Occasione? {
        guard let scelta = stato.occasioneSelezionata else { return nil }
        let mostrate = stato.vistaAgenda == .occasioni ? elenco : (strato ? indice.occasioni(giorno) : [])
        return mostrate.first { $0.id == scelta.id }
    }

    private var quieto: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "calendar")
                .font(Tipo.simboloQuieto)
                .foregroundColor(Colori.Agenda.quieto)
            Text("Il tempo per ciò che conta.")
                .font(Tipo.quietoTitolo)
                .foregroundColor(Colori.Agenda.dettaglioTitolo)
            Text("Seleziona un appuntamento per ritrovare cliente, note e azioni in un solo posto.")
                .font(Tipo.quietoTesto)
                .foregroundColor(Colori.Agenda.quietoTesto)
                .fixedSize(horizontal: false, vertical: true)
            Text("Ogni incontro è collegato alla scheda cliente e, se serve, a una posizione da analizzare. Le scadenze delle posizioni in essere e le occasioni (penali finite, previdenza, famiglia, coperture, fisco) compaiono da sole nella giornata.")
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .bordoAlto(Colori.Agenda.azioniBordo)
        }
    }
}

// MARK: - Giorno della settimana

struct GiornoSettimanaAgenda: View {
    let nome: String
    let giorno: Date
    let incontri: Int
    let scadenze: Int
    let selezionato: Bool
    let oggi: Bool
    /// Le occasioni del giorno (vuoto con lo strato spento).
    var occasioni = SegniOccasioni()
    let azione: () -> Void
    @State var sopra = false

    private var nota: String {
        if incontri > 0 { return "\(incontri) \(incontri == 1 ? "incontro" : "incontri")" }
        if scadenze > 0 { return "\(scadenze) \(scadenze == 1 ? "scadenza" : "scadenze")" }
        if occasioni.numero > 0 { return "\(occasioni.numero) \(occasioni.numero == 1 ? "occasione" : "occasioni")" }
        return "Libero"
    }

    var body: some View {
        Button(action: azione) {
            VStack(spacing: 1) {
                Text(nome.uppercased())
                    .font(Tipo.giornoSettimana)
                    .tracking(0.4)
                Text(Formati.giorno.string(from: giorno))
                    .font(Tipo.giornoNumero)
                    .foregroundColor(selezionato ? Colori.Agenda.selezioneTesto : (oggi ? Colori.Agenda.giornoOggiNumero : Colori.Agenda.giornoNumero))
                Text(nota)
                    .font(Tipo.giornoNota)
                    .lineLimit(1)
                    .minimumScaleFactor(Misure.AgendaImpaginazione.scalaNotaGiorno)
                    .opacity(0.85)
                PuntiniGiorno(incontri: incontri, scadenze: scadenze, selezionato: selezionato, occasioni: occasioni)
                    .padding(.top, 2)
            }
            .foregroundColor(selezionato ? Colori.Agenda.selezioneTesto : Colori.Agenda.giorno)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(sfondo)
        }
        .buttonStyle(StileSemplice())
        .onHover { sopra = $0 }
    }

    @ViewBuilder private var sfondo: some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.Dossier.giornoSettimana)
        if selezionato {
            forma.fill(Colori.Agenda.selezioneAlto)
        } else if oggi {
            forma.strokeBorder(Colori.Agenda.giornoOggiBordo, lineWidth: 1)
        } else if sopra {
            forma.fill(Colori.Agenda.giornoPassaggio)
        }
    }
}

/// Puntini sotto il giorno: rosso per gli incontri, ambra per le scadenze; poi un anello vuoto per ogni
/// colore di occasione (Alleanza, indipendente, neutro): il pieno è di incontri e scadenze, l'anello delle
/// occasioni, così si distinguono anche con lo stesso colore.
struct PuntiniGiorno: View {
    let incontri: Int
    let scadenze: Int
    let selezionato: Bool
    var occasioni = SegniOccasioni()

    var body: some View {
        HStack(spacing: 3) {
            if incontri > 0 {
                Circle().fill(selezionato ? Colori.Agenda.puntinoSelezione : Colori.Agenda.puntino)
                    .frame(width: Misure.Agenda.puntino, height: Misure.Agenda.puntino)
            }
            if scadenze > 0 {
                Circle().fill(selezionato ? Colori.Agenda.puntinoSelezione : Colori.Agenda.scadenzaTesto)
                    .frame(width: Misure.Agenda.puntino, height: Misure.Agenda.puntino)
            }
            if !occasioni.vuoto {
                AnelliOccasioni(segni: occasioni, selezionato: selezionato)
            }
        }
        .frame(height: max(Misure.Agenda.puntino, Misure.Occasioni.anello))
    }
}

struct CellaMeseAgenda: View {
    let giorno: Date
    let nelMese: Bool
    let incontri: Int
    let scadenze: Int
    let selezionato: Bool
    let oggi: Bool
    /// Le occasioni del giorno (vuoto con lo strato spento).
    var occasioni = SegniOccasioni()
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            VStack(spacing: 2) {
                Text(Formati.giorno.string(from: giorno))
                    .font(Tipo.cellaMese)
                    .foregroundColor(selezionato ? Colori.Agenda.selezioneTesto : (oggi ? Colori.Agenda.giornoOggiNumero : Colori.Agenda.giornoNumero))
                PuntiniGiorno(incontri: incontri, scadenze: scadenze, selezionato: selezionato, occasioni: occasioni)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Misure.Agenda.cellaMese)
            .background {
                if selezionato {
                    FormaVetro.arrotondata(Tema.Raggio.Dossier.giornoMese).fill(Colori.Agenda.selezioneAlto)
                } else if oggi {
                    FormaVetro.arrotondata(Tema.Raggio.Dossier.giornoMese).strokeBorder(Colori.Agenda.giornoOggiBordo, lineWidth: 1)
                }
            }
            .opacity(nelMese ? 1 : 0.4)
        }
        .buttonStyle(StileSemplice())
    }
}

// MARK: - Righe della giornata

struct RigaEventoAgenda: View {
    let evento: Appuntamento
    let cliente: String
    /// Il canale dell'appuntamento o, se manca, quello della posizione collegata (`canaleAppuntamento`).
    let canale: Canale?
    let selezionato: Bool
    let azione: () -> Void

    var body: some View {
        let concluso = evento.stato == .concluso
        Button(action: azione) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    // Le ore non vanno mai a capo («09:3 / 0» con il testo molto grande)
                    Text(Formati.ora.string(from: evento.inizio))
                        .font(Tipo.eventoOra)
                        .foregroundColor(Colori.Agenda.ora)
                        .lineLimit(1)
                        .fixedSize()
                    Text(Formati.ora.string(from: evento.fine))
                        .font(Tipo.eventoFine)
                        .foregroundColor(Colori.Agenda.oraFine)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: Misure.Agenda.colonnaOra, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .top)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(evento.titolo)
                            .font(Tipo.eventoTitolo)
                            .foregroundColor(concluso ? Colori.Agenda.eventoConcluso : Colori.Agenda.evento)
                            .lineLimit(1)
                        if concluso {
                            EtichettaStato(testo: "✓ Concluso", colore: Colori.Agenda.conclusoTesto, fondo: Colori.Agenda.conclusoFondo)
                        }
                        if let c = canale {
                            EtichettaCanale(canale: c, compatta: true)
                        }
                    }
                    Text(cliente)
                        .font(Tipo.eventoCliente)
                        .foregroundColor(Colori.Agenda.eventoCliente)
                    Text("\(evento.luogo.isEmpty ? "Luogo da definire" : evento.luogo) · \(evento.durataMinuti) min · \(evento.tipo.nome)")
                        .font(Tipo.eventoDettagli)
                        .foregroundColor(Colori.Agenda.eventoDettagli)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("›")
                    .font(Tipo.eventoFreccia)
                    .foregroundColor(Colori.Agenda.freccia)
            }
            .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 15))
            .background(selezionato ? Colori.Agenda.rigaSelezione : Color.clear)
            .overlay(alignment: .leading) {
                if selezionato {
                    FormaVetro.capsula.fill(Colori.Agenda.rigaSegno)
                        .frame(width: Misure.Agenda.segno)
                        .padding(.vertical, 10)
                }
            }
            .bordoBasso(Colori.Agenda.rigaBordo)
        }
        .buttonStyle(StileSemplice())
    }
}

struct RigaScadenzaAgenda: View {
    let posizione: Posizione
    let cliente: String
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            // «Scade» e «Analizza ›» sulla riga del nome, come l'ora nelle righe degli appuntamenti
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                EtichettaStato(testo: "Scade", colore: Colori.Agenda.scadenzaTesto, fondo: Colori.Agenda.scadenzaFondo)
                    .frame(width: Misure.Agenda.colonnaOra, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(posizione.nome)
                            .font(Tipo.eventoTitolo)
                            .foregroundColor(Colori.Agenda.evento)
                            .lineLimit(1)
                        EtichettaCanale(canale: posizione.canale, compatta: true)
                    }
                    Text(cliente)
                        .font(Tipo.eventoCliente)
                        .foregroundColor(Colori.Agenda.eventoCliente)
                    Text([posizione.area.nome, posizione.tipologia, posizione.emittente].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(Tipo.eventoDettagli)
                        .foregroundColor(Colori.Agenda.eventoDettagli)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("Analizza ›")
                    .font(Tipo.eventoDettagli)
                    .foregroundColor(Colori.Colonna.collegamento)
            }
            .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 15))
            .bordoBasso(Colori.Agenda.rigaBordo)
        }
        .buttonStyle(StileSemplice())
        .help("Apri la posizione in Posizioni")
    }
}

// MARK: - Dettaglio dell'appuntamento

struct DettaglioAppuntamento: View {
    @EnvironmentObject var stato: StatoShell
    let evento: Appuntamento
    let modifica: () -> Void
    let nuovaAttivita: () -> Void

    var body: some View {
        let concluso = evento.stato == .concluso
        let cliente = stato.cliente(evento.clienteId)
        let posizione = evento.posizioneId.flatMap { id in stato.posizioni.first { $0.id == id } }
        let collegate = stato.attivitaCollegate(evento.id)
        let canale = stato.canaleAppuntamento(evento)
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(concluso ? "INCONTRO CONCLUSO" : "IL TUO APPUNTAMENTO")
                        .font(Tipo.dettaglioOcchiello)
                        .tracking(1.2)
                        .foregroundColor(Colori.Agenda.dettaglioOcchiello)
                    Text(evento.titolo)
                        .font(Tipo.dettaglioTitolo)
                        .foregroundColor(Colori.Agenda.dettaglioTitolo)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 5)
                    HStack(alignment: .firstTextBaseline, spacing: Misure.AgendaImpaginazione.spazioCliente) {
                        Text(cliente?.nome ?? "Cliente")
                            .font(Tipo.dettaglioCliente)
                            .foregroundColor(Colori.Agenda.dettaglioCliente)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        // La scheda del cliente a portata di clic, come «Apri dossier» nelle Note
                        Button { stato.apriCliente(evento.clienteId) } label: {
                            HStack(spacing: Tema.Misura.Componenti.spazioSimboloPulsante) {
                                Text("Scheda cliente")
                                Image(systemName: "arrow.up.right")
                            }
                        }
                        .buttonStyle(StileCollegamento())
                        .fixedSize()
                        .help("Apri la scheda del cliente")
                    }
                    .padding(.bottom, 7)

                    // Appuntamento concluso con una proposta da chiudere: l'esito si chiede subito, qui
                    if let p = stato.propostaDaChiudere(evento) {
                        RiquadroEsitoProposta(appuntamento: evento, posizione: p,
                                              passoIniziale: MotoreSeguitoProposte.passoIniziale(evento))
                            .padding(.bottom, Misure.RiesamiAgenda.sottoEsito)
                    }

                    VoceDettaglio(etichetta: "Quando") {
                        Text("\(Formati.dataLunga.string(from: evento.inizio))\n\(Formati.ora.string(from: evento.inizio)) – \(Formati.ora.string(from: evento.fine))")
                            .font(Tipo.voceValore)
                            .foregroundColor(Colori.Agenda.voceValore)
                    }
                    VoceDettaglio(etichetta: "Dove") { valore(evento.luogo.isEmpty ? "Luogo da definire" : evento.luogo) }
                    VoceDettaglio(etichetta: "Durata") { valore("\(evento.durataMinuti) minuti") }
                    VoceDettaglio(etichetta: "Tipo") { valore(evento.tipo.nome) }
                    VoceDettaglio(etichetta: "Canale") {
                        if let c = canale {
                            EtichettaCanale(canale: c, compatta: true)
                        } else {
                            Pillola(testo: "Da indicare", tono: .neutro)
                                .help("Indica il canale con «Modifica» o collega una posizione all'appuntamento")
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTE PER L'INCONTRO")
                            .font(Tipo.voceEtichetta)
                            .tracking(0.3)
                            .foregroundColor(Colori.Agenda.notaEtichetta)
                        Text(evento.note.isEmpty ? "Aggiungi i punti da affrontare e i documenti utili per arrivare preparato." : evento.note)
                            .font(Tipo.voceValore)
                            .foregroundColor(Colori.Agenda.notaTesto)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .vetro(.chip, forma: .arrotondata(Tema.Raggio.Dossier.riquadro), riempimento: Colori.Agenda.notaFondo)
                    .padding(.vertical, 8)

                    if let p = posizione {
                        riquadroPosizione(p)
                    }
                    if !collegate.isEmpty {
                        Text("ATTIVITÀ COLLEGATE")
                            .font(Tipo.voceEtichetta)
                            .tracking(0.3)
                            .foregroundColor(Colori.Agenda.notaEtichetta)
                            .padding(.top, 4)
                        ForEach(collegate) { t in
                            Button { stato.alternaCompletata(t.id) } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 7) {
                                    Image(systemName: t.completata ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(t.completata ? Colori.Attivita.spuntaFattaBasso : Colori.Agenda.voceEtichetta)
                                    Text(t.titolo)
                                        .font(Tipo.voceValore)
                                        .foregroundColor(t.completata ? Colori.Agenda.eventoConcluso : Colori.Agenda.voceValore)
                                        .strikethrough(t.completata)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(StileSemplice())
                            .help(t.completata ? "Segna come da fare" : "Segna come fatta")
                        }
                    }
                }
                .padding(.trailing, 4)
                .padding(.bottom, Misure.AgendaImpaginazione.sfumaturaDettaglio / 2)
            }
            // L'ultima riga sfuma sopra le azioni invece di finire tagliata a metà
            .sfumaturaBordiScorrimento(sotto: Misure.AgendaImpaginazione.sfumaturaDettaglio)

            // Le azioni in due gruppi: le principali in alto, le altre in una fila sola se c'è posto,
            // altrimenti due per riga (o una sotto l'altra): i titoli non si troncano mai
            // Nessun blu nel dettaglio (il blu è «Appuntamento» nella barra): per prima l'azione consigliata,
            // «Prepara l'incontro», in vetro dell'accento; l'analisi viene prima di Eve.
            let spazio = Misure.AgendaImpaginazione.spazioAzioni
            VStack(spacing: spazio) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: spazio) {
                        azioneIncontro
                        azioneEve
                    }
                    VStack(spacing: spazio) {
                        azioneIncontro
                        azioneEve
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: spazio) {
                        azioneConcluso(concluso)
                        azioneModifica
                        azioneAttivita
                        azioneFascicolo
                    }
                    VStack(spacing: spazio) {
                        HStack(spacing: spazio) {
                            azioneConcluso(concluso)
                            azioneModifica
                        }
                        HStack(spacing: spazio) {
                            azioneAttivita
                            azioneFascicolo
                        }
                    }
                    VStack(spacing: spazio) {
                        azioneConcluso(concluso)
                        azioneModifica
                        azioneAttivita
                        azioneFascicolo
                    }
                }
            }
            .padding(.top, 7)
            .bordoAlto(Colori.Agenda.azioniBordo)
        }
    }

    // MARK: - Azioni del dettaglio

    private var azioneEve: some View {
        PulsanteAzione(titolo: "Prepara con Eve", simbolo: "sparkles") {
            stato.clienteAttivoId = evento.clienteId
            stato.apri(.eve)
        }
    }

    private var azioneModifica: some View {
        PulsanteAzione(titolo: "Modifica", simbolo: "pencil", azione: modifica)
    }

    private func azioneConcluso(_ concluso: Bool) -> some View {
        PulsanteAzione(titolo: concluso ? "Riapri incontro" : "Segna concluso",
                       simbolo: concluso ? "arrow.uturn.backward" : "checkmark") { stato.alternaConcluso(evento.id) }
    }

    private var azioneAttivita: some View {
        PulsanteAzione(titolo: "Attività collegata", simbolo: "checklist", azione: nuovaAttivita)
    }

    private var azioneFascicolo: some View {
        let archiviato = stato.fascicoloArchiviato(per: evento)
        return PulsanteAzione(titolo: archiviato == nil ? "Prepara il fascicolo" : "Apri il fascicolo",
                              simbolo: "doc.text") {
            if let d = stato.fascicoloArchiviato(per: evento) {
                stato.clienteAttivoId = evento.clienteId
                stato.documentoSelezionato = d.id
                stato.apri(.documenti)
            } else {
                stato.preparaFascicolo(per: evento)
            }
        }
        .help(archiviato == nil ? "Unisci in un PDF i report da consegnare al cliente"
                                : "Il fascicolo consegnato è in Documenti: aprilo")
    }

    private var azioneIncontro: some View {
        let aperto = stato.dati.incontri.contains { $0.appuntamentoId == evento.id }
        return PulsanteAzione(titolo: aperto ? "Apri l'incontro" : "Prepara l'incontro", principale: true,
                              simbolo: "list.bullet.rectangle") {
            stato.apriIncontro(per: evento)
        }
        .help(aperto ? "Apri l'incontro: appunti e decisioni" : "Prepara l'incontro: temi, ascolto, prossimi passi")
    }

    private func valore(_ testo: String) -> some View {
        Text(testo).font(Tipo.voceValore).foregroundColor(Colori.Agenda.voceValore)
    }

    private func riquadroPosizione(_ p: Posizione) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(p.stato == .proposta ? "PROPOSTA DI CUI SI PARLA" : "POSIZIONE DI CUI SI PARLA")
                .font(Tipo.voceEtichetta)
                .tracking(0.3)
                .foregroundColor(Colori.Agenda.notaEtichetta)
            HStack(spacing: 6) {
                Text(p.nome)
                    .font(Tipo.voceValore.weight(.semibold))
                    .foregroundColor(Colori.Agenda.dettaglioTitolo)
                    .lineLimit(1)
                EtichettaCanale(canale: p.canale, compatta: true)
            }
            Text([p.area.nome, p.stato.nome, p.scadenza.map { "scadenza \(Formati.dataEstesa.string(from: $0))" } ?? ""]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(Tipo.voceEtichetta)
                .foregroundColor(Colori.Agenda.voceEtichetta)
            // La proposta ha già un esito: presentata, accettata, rifiutata o rimandata
            if let e = p.esito, e != .bozza {
                Text(TestiSeguito.esito(p, adesso: Date()))
                    .font(Tipo.voceEtichetta)
                    .foregroundColor(Colori.Agenda.voceEtichetta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button { stato.apriPosizione(p) } label: { Label("Analizza in Posizioni", systemImage: "chart.pie") }
                .buttonStyle(StileVetro(taglia: .compatta))
                .fixedSize()
                .padding(.top, 2)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Dossier.riquadro))
        .padding(.bottom, 8)
    }
}

extension StatoShell {
    /// Il canale da mostrare per un appuntamento: il suo o, se non è indicato, quello della posizione collegata.
    func canaleAppuntamento(_ e: Appuntamento) -> Canale? {
        if let c = e.canale { return c }
        return e.posizioneId.flatMap { id in posizioni.first { $0.id == id } }?.canale
    }
}
