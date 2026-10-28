import SwiftUI

/// App Agenda (.os-app-agenda): la fascia in testa, la scheda con la settimana (o il mese),
/// la pagina della giornata e il dettaglio dell'appuntamento. Nella giornata compaiono anche
/// le posizioni in scadenza: ogni scadenza è l'occasione per rivedere la posizione del cliente.
struct AppAgenda: View {
    @EnvironmentObject var stato: StatoShell
    @State var modulo: Appuntamento?
    @State var moduloAttivita: Attivita?

    private var cal: Calendar { CalendarioAgenda.cal }
    private var giorno: Date { stato.giornoAgenda }

    var body: some View {
        VStack(spacing: 0) {
            fasciaCuoio
            libro
                .padding(.top, Tema.Misura.Dossier.spazioAgenda)
        }
        .sheet(item: $modulo) { a in
            ModuloAppuntamento(
                bozza: a,
                nuovo: !stato.appuntamenti.contains { $0.id == a.id },
                salva: { stato.salvaAppuntamento($0) },
                elimina: { stato.eliminaAppuntamento(a.id) }
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
        modulo = Appuntamento.nuovo(clienteId: stato.filtroClienteAgenda ?? stato.clienteAttivoId, giorno: giorno)
    }

    // MARK: - Cuoio

    private var periodo: String {
        if stato.vistaAgenda == .mese { return Formati.meseAnno.string(from: giorno).capitalized }
        let giorni = CalendarioAgenda.giorni(settimanaDi: giorno)
        guard let primo = giorni.first, let ultimo = giorni.last else { return "" }
        return "\(Formati.giornoMese.string(from: primo)) — \(Formati.dataEstesa.string(from: ultimo))"
    }

    private var fasciaCuoio: some View {
        CuoioAgenda {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PRISMA · AGENDA PERSONALE")
                        .font(Tipo.agendaOcchiello)
                        .tracking(0.8)
                        .foregroundColor(Colori.Agenda.cuoioTesto)
                    HStack(alignment: .firstTextBaseline, spacing: 25) {
                        Text("Il tuo tempo, con cura.")
                            .font(Tipo.agendaTitolo)
                            .foregroundColor(Colori.Agenda.cuoioTitolo)
                        Spacer(minLength: 0)
                        Text(periodo)
                            .font(Tipo.agendaPeriodo)
                            .foregroundColor(Colori.Agenda.cuoioTesto)
                    }
                }
                TarghettaData(giorno: giorno)
            }
        }
    }

    // MARK: - Libro

    private var libro: some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.scheda)
        // Appuntamenti e scadenze dei giorni visibili, raggruppati una volta sola
        let settimane = CalendarioAgenda.settimane(meseDi: giorno)
        let indice = stato.giorniAgenda(stato.vistaAgenda == .settimana ? CalendarioAgenda.giorni(settimanaDi: giorno) : settimane.flatMap { $0 })
        return VStack(spacing: 0) {
            barraStrumenti
            if stato.vistaAgenda == .settimana { settimana(indice) } else { mese(settimane, indice) }
            GeometryReader { geo in
                HStack(spacing: 0) {
                    paginaGiorno(indice)
                        .frame(width: max(0, geo.size.width - larghezzaDettaglio(geo.size.width)))
                    dettaglio(indice)
                        .frame(width: larghezzaDettaglio(geo.size.width))
                }
            }
        }
        // Una scheda del tema, come la fascia: il contenuto si taglia alla forma prima del vetro
        .clipShape(forma)
        .vetro(.sottile, forma: forma)
    }

    private func larghezzaDettaglio(_ totale: CGFloat) -> CGFloat {
        min(max(Misure.Agenda.dettaglioMinimo, totale * (1 - Misure.Agenda.quotaPagina)), totale * 0.5)
    }

    private var barraStrumenti: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Button("‹") { sposta(-1) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    .help(stato.vistaAgenda == .settimana ? "Settimana precedente" : "Mese precedente")
                Button("Oggi") {
                    stato.giornoAgenda = cal.startOfDay(for: Date())
                    stato.appuntamentoSelezionato = nil
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                Button("›") { sposta(1) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    .help(stato.vistaAgenda == .settimana ? "Settimana successiva" : "Mese successivo")
            }
            Segmentato(opzioni: [(VistaAgenda.settimana, "Settimana"), (VistaAgenda.mese, "Mese")], selezione: $stato.vistaAgenda)
                .frame(width: 170)
            Spacer(minLength: 0)
            MenuTendina(selezione: $stato.filtroClienteAgenda,
                        opzioni: [(String?.none, "Tutti i clienti")] + stato.clienti.map { (Optional($0.id), $0.nome) },
                        larghezza: 190)
            Button("＋ Appuntamento") { nuovoAppuntamento() }
                .buttonStyle(StileBlu())
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 7, trailing: 12))
    }

    private func sposta(_ verso: Int) {
        let componente: Calendar.Component = stato.vistaAgenda == .settimana ? .weekOfYear : .month
        stato.giornoAgenda = cal.date(byAdding: componente, value: verso, to: giorno) ?? giorno
        stato.appuntamentoSelezionato = nil
    }

    // MARK: - Settimana e mese

    private func seleziona(_ g: Date) {
        stato.giornoAgenda = cal.startOfDay(for: g)
        stato.appuntamentoSelezionato = nil
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
                    oggi: cal.isDateInToday(g)
                ) { seleziona(g) }
            }
        }
        .padding(EdgeInsets(top: 0, leading: 12, bottom: 6, trailing: 12))
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
                            oggi: cal.isDateInToday(g)
                        ) { seleziona(g) }
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 0, leading: 12, bottom: 6, trailing: 12))
        .bordoBasso(Colori.Agenda.settimanaBordo)
    }

    // MARK: - Pagina della giornata

    private func paginaGiorno(_ indice: GiorniAgenda) -> some View {
        let eventi = indice.appuntamenti(giorno)
        let scadenze = indice.scadenze(giorno)
        let selezionato = eventoSelezionato(eventi)
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
                            selezionato: e.id == selezionato?.id
                        ) { stato.appuntamentoSelezionato = e.id }
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
                    if eventi.isEmpty && scadenze.isEmpty {
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
            Button("Aggiungi un incontro") { nuovoAppuntamento() }
                .buttonStyle(StileBlu())
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
        // Il periodo dei conteggi: la settimana del giorno scelto, anche nella vista del mese
        let corrente = giorni.contains { cal.isDateInToday($0) }
        let periodo = corrente ? "QUESTA SETTIMANA"
            : "SETTIMANA DEL \(giorni.first.map { Formati.giornoMeseBreve.string(from: $0) } ?? "")".uppercased()
        return HStack(spacing: 6) {
            Text(periodo)
                .font(Tipo.paginaOcchiello)
                .tracking(1.2)
                .padding(.trailing, 5)
            Text("\(daSvolgere.count) da svolgere").font(Tipo.notaSettimanaForte)
            Text("·")
            Text("\(CalendarioAgenda.durata(minuti)) riservati").font(Tipo.notaSettimanaForte)
            if scadenze > 0 {
                Text("·")
                Text("\(scadenze) \(scadenze == 1 ? "scadenza" : "scadenze")").font(Tipo.notaSettimanaForte)
            }
            Spacer(minLength: 0)
        }
        .font(Tipo.notaSettimana)
        .foregroundColor(Colori.Agenda.notaSettimana)
        .lineLimit(1)
        .padding(EdgeInsets(top: 7, leading: 15, bottom: 7, trailing: 15))
        .bordoAlto(Colori.Agenda.notaSettimanaBordo)
    }

    // MARK: - Dettaglio

    private func dettaglio(_ indice: GiorniAgenda) -> some View {
        Group {
            if let e = eventoSelezionato(indice.appuntamenti(giorno)) {
                DettaglioAppuntamento(
                    evento: e,
                    modifica: { modulo = e },
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

    private var quieto: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✎")
                .font(Tipo.simboloQuieto)
                .foregroundColor(Colori.Agenda.quieto)
            Text("Il tempo per ciò che conta.")
                .font(Tipo.quietoTitolo)
                .foregroundColor(Colori.Agenda.dettaglioTitolo)
            Text("Seleziona un appuntamento per ritrovare cliente, note e azioni in un solo posto.")
                .font(Tipo.quietoTesto)
                .foregroundColor(Colori.Agenda.quietoTesto)
                .fixedSize(horizontal: false, vertical: true)
            Text("Ogni incontro è collegato alla scheda cliente e, se serve, a una posizione da analizzare. Le scadenze delle posizioni in essere compaiono da sole nella giornata.")
                .font(Tipo.quietoSuggerimento)
                .foregroundColor(Colori.Agenda.quietoSuggerimento)
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
    let azione: () -> Void
    @State var sopra = false

    private var nota: String {
        if incontri > 0 { return "\(incontri) \(incontri == 1 ? "incontro" : "incontri")" }
        if scadenze > 0 { return "\(scadenze) \(scadenze == 1 ? "scadenza" : "scadenze")" }
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
                    .opacity(0.85)
                PuntiniGiorno(incontri: incontri, scadenze: scadenze, selezionato: selezionato)
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

/// Puntini sotto il giorno: rosso per gli incontri, ambra per le scadenze.
struct PuntiniGiorno: View {
    let incontri: Int
    let scadenze: Int
    let selezionato: Bool

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
        }
        .frame(height: Misure.Agenda.puntino)
    }
}

struct CellaMeseAgenda: View {
    let giorno: Date
    let nelMese: Bool
    let incontri: Int
    let scadenze: Int
    let selezionato: Bool
    let oggi: Bool
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            VStack(spacing: 2) {
                Text(Formati.giorno.string(from: giorno))
                    .font(Tipo.cellaMese)
                    .foregroundColor(selezionato ? Colori.Agenda.selezioneTesto : (oggi ? Colori.Agenda.giornoOggiNumero : Colori.Agenda.giornoNumero))
                PuntiniGiorno(incontri: incontri, scadenze: scadenze, selezionato: selezionato)
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
    let selezionato: Bool
    let azione: () -> Void

    var body: some View {
        let concluso = evento.stato == .concluso
        Button(action: azione) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(Formati.ora.string(from: evento.inizio))
                        .font(Tipo.eventoOra)
                        .foregroundColor(Colori.Agenda.ora)
                    Text(Formati.ora.string(from: evento.fine))
                        .font(Tipo.eventoFine)
                        .foregroundColor(Colori.Agenda.oraFine)
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
                        if let c = evento.canale {
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
            HStack(alignment: .center, spacing: 12) {
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
                    .foregroundColor(Colori.Agenda.freccia)
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
                    Text(cliente?.nome ?? "Cliente")
                        .font(Tipo.dettaglioCliente)
                        .foregroundColor(Colori.Agenda.dettaglioCliente)
                        .padding(.bottom, 7)

                    VoceDettaglio(etichetta: "Quando") {
                        Text("\(Formati.dataLunga.string(from: evento.inizio))\n\(Formati.ora.string(from: evento.inizio)) – \(Formati.ora.string(from: evento.fine))")
                            .font(Tipo.voceValore)
                            .foregroundColor(Colori.Agenda.voceValore)
                    }
                    VoceDettaglio(etichetta: "Dove") { valore(evento.luogo.isEmpty ? "Luogo da definire" : evento.luogo) }
                    VoceDettaglio(etichetta: "Durata") { valore("\(evento.durataMinuti) minuti") }
                    VoceDettaglio(etichetta: "Tipo") { valore(evento.tipo.nome) }
                    VoceDettaglio(etichetta: "Canale") {
                        if let c = evento.canale {
                            EtichettaCanale(canale: c, compatta: true)
                        } else {
                            valore("Non indicato")
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
                        }
                    }
                }
                .padding(.trailing, 4)
            }

            // Nelle finestre strette le azioni passano da tre a due colonne, senza troncare i titoli.
            ViewThatFits(in: .horizontal) {
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        azioneEve.gridCellColumns(2)
                        azioneModifica
                    }
                    GridRow {
                        azioneConcluso(concluso)
                        azioneAttivita
                        azioneScheda
                    }
                    GridRow { azioneFascicolo.gridCellColumns(3) }
                    GridRow { azioneIncontro.gridCellColumns(3) }
                }
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        azioneEve
                        azioneModifica
                    }
                    GridRow {
                        azioneConcluso(concluso)
                        azioneAttivita
                    }
                    GridRow {
                        azioneScheda
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                    GridRow { azioneFascicolo.gridCellColumns(2) }
                    GridRow { azioneIncontro.gridCellColumns(2) }
                }
            }
            .padding(.top, 7)
            .bordoAlto(Colori.Agenda.azioniBordo)
        }
    }

    // MARK: - Azioni del dettaglio

    private var azioneEve: some View {
        PulsanteAzione(titolo: "✦ Prepara con Eve", principale: true) {
            stato.clienteAttivoId = evento.clienteId
            stato.apri(.eve)
        }
    }

    private var azioneModifica: some View {
        PulsanteAzione(titolo: "Modifica", azione: modifica)
    }

    private func azioneConcluso(_ concluso: Bool) -> some View {
        PulsanteAzione(titolo: concluso ? "Riapri incontro" : "✓ Segna concluso") { stato.alternaConcluso(evento.id) }
    }

    private var azioneAttivita: some View {
        PulsanteAzione(titolo: "＋ Attività collegata", azione: nuovaAttivita)
    }

    private var azioneScheda: some View {
        PulsanteAzione(titolo: "Scheda cliente") { stato.apriCliente(evento.clienteId) }
    }

    private var azioneFascicolo: some View {
        let archiviato = stato.fascicoloArchiviato(per: evento)
        return PulsanteAzione(titolo: archiviato == nil ? "Prepara il fascicolo da consegnare"
                                                        : "Fascicolo consegnato: aprilo in Documenti",
                              simbolo: "doc.text") {
            if let d = stato.fascicoloArchiviato(per: evento) {
                stato.clienteAttivoId = evento.clienteId
                stato.documentoSelezionato = d.id
                stato.apri(.documenti)
            } else {
                stato.preparaFascicolo(per: evento)
            }
        }
    }

    private var azioneIncontro: some View {
        PulsanteAzione(titolo: stato.dati.incontri.contains { $0.appuntamentoId == evento.id }
                       ? "Apri l'incontro: appunti e decisioni" : "Prepara l'incontro: temi, ascolto, prossimi passi",
                       simbolo: "clock") {
            stato.apriIncontro(per: evento)
        }
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
            Button("Analizza in Posizioni ›") { stato.apriPosizione(p) }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 9, bottom: 4, trailing: 9)))
                .padding(.top, 2)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Dossier.riquadro))
        .padding(.bottom, 8)
    }
}
