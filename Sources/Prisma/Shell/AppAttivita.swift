import SwiftUI

/// App Attività (.os-app-tasks): testata, riepilogo, registro delle attività e dettaglio, su schede del tema.
struct AppAttivita: View {
    @EnvironmentObject var stato: StatoShell
    @State var modulo: Attivita?

    private var cal: Calendar { CalendarioAgenda.cal }

    /// Attività del cliente scelto (o di tutti).
    private var delCliente: [Attivita] {
        stato.attivita.filter { stato.filtroClienteAttivita == nil || $0.clienteId == stato.filtroClienteAttivita }
    }

    /// L'elenco filtrato e ordinato: si calcola una volta per disegno (vedi `registro`).
    private var elenco: [Attivita] {
        let giorno = Dictionary(stato.attivita.map { ($0.id, cal.startOfDay(for: $0.scadenza)) }, uniquingKeysWith: { a, _ in a })
        return delCliente
            .filter {
                switch stato.filtroStatoAttivita {
                case .aperte: return !$0.completata
                case .completate: return $0.completata
                case .tutte: return true
                }
            }
            .filter { stato.filtroPrioritaAttivita == nil || $0.priorita == stato.filtroPrioritaAttivita }
            .sorted {
                if $0.completata != $1.completata { return !$0.completata }
                if giorno[$0.id] != giorno[$1.id] { return $0.scadenza < $1.scadenza }
                return $0.priorita.ordine < $1.priorita.ordine
            }
    }

    private func selezionata(_ e: [Attivita]) -> Attivita? {
        e.first { $0.id == stato.attivitaSelezionata } ?? e.first
    }

    var body: some View {
        VStack(spacing: 8) {
            testata
            riepilogo
            registro
        }
        .sheet(item: $modulo) { t in
            ModuloAttivita(bozza: t, nuova: !stato.attivita.contains { $0.id == t.id },
                           salva: { stato.salvaAttivita($0) }, elimina: { stato.eliminaAttivita(t.id) })
                .environmentObject(stato)
        }
        .onAppear { controllaRichiesta(stato.richiestaNuovaAttivita) }
        .onChange(of: stato.richiestaNuovaAttivita) { controllaRichiesta($0) }
    }

    private func controllaRichiesta(_ richiesta: Bool) {
        guard richiesta else { return }
        stato.richiestaNuovaAttivita = false
        nuova()
    }

    private func nuova() {
        modulo = Attivita.nuova(clienteId: stato.filtroClienteAttivita ?? stato.clienteAttivoId)
    }

    // MARK: - Testata e riepilogo

    private var testata: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PRISMA · PROMEMORIA")
                    .font(Tipo.agendaOcchiello)
                    .tracking(0.8)
                    .foregroundColor(Colori.Attivita.testataTesto)
                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    Text("Le cose da fare.")
                        .font(Tipo.agendaTitolo)
                        .foregroundColor(Colori.Attivita.testataTitolo)
                    Text("Un posto per ogni prossimo passo.")
                        .font(Tipo.agendaPeriodo)
                        .foregroundColor(Colori.Attivita.testataTesto)
                }
            }
            Spacer(minLength: 0)
            Button("＋ Nuova attività") { nuova() }
                .buttonStyle(StileBlu())
        }
        .padding(Tema.Misura.Dossier.testataAttivita)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.scheda))
    }

    private var riepilogo: some View {
        let aperte = delCliente.filter { !$0.completata }
        let fatte = delCliente.filter(\.completata)
        let limite = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: Date())) ?? Date()
        // Oggi e i sei giorni dopo (le scadenze sono a mezzanotte)
        let urgenti = aperte.filter { $0.scadenza < limite }
        let quota = delCliente.isEmpty ? 0 : Double(fatte.count) / Double(delCliente.count)
        return HStack(spacing: 12) {
            numero(aperte.count, "Da svolgere")
            separatore
            numero(urgenti.count, "Entro 7 giorni o scadute")
            separatore
            numero(fatte.count, "Completate")
            separatore
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Int((quota * 100).rounded()))% completato")
                    .font(Tipo.attivitaNumeroEtichetta)
                    .foregroundColor(Colori.Attivita.numero)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        FormaVetro.capsula.fill(Colori.Attivita.progressoFondo)
                        FormaVetro.capsula.fill(Colori.Attivita.progressoAlto)
                            .frame(width: geo.size.width * quota)
                    }
                }
                .frame(height: Misure.Attivita.progresso)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
    }

    private func numero(_ n: Int, _ etichetta: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(n)").font(Tipo.attivitaNumero)
            Text(etichetta).font(Tipo.attivitaNumeroEtichetta).lineLimit(1)
        }
        .foregroundColor(Colori.Attivita.numero)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var separatore: some View {
        Rectangle().fill(Colori.Attivita.separatore)
            .frame(width: Tema.Misura.filo, height: Tema.Misura.Dossier.separatoreRiepilogo)
    }

    // MARK: - Registro

    private var registro: some View {
        let voci = elenco
        let scelta = selezionata(voci)
        return VStack(spacing: 0) {
            filtri
            GeometryReader { geo in
                let dettaglio = min(max(Misure.Attivita.dettaglioMinimo, geo.size.width * (1 - Misure.Attivita.quotaElenco)),
                                    geo.size.width * 0.5)
                HStack(spacing: 0) {
                    carta(voci, scelta)
                        .frame(width: max(0, geo.size.width - dettaglio))
                    pannelloDettaglio(scelta)
                        .frame(width: dettaglio)
                }
            }
        }
        // Una scheda del tema: il contenuto si taglia alla forma prima del vetro
        .clipShape(FormaVetro.arrotondata(Tema.Raggio.scheda))
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.scheda))
    }

    private var filtri: some View {
        HStack(spacing: 9) {
            Segmentato(opzioni: [(FiltroAttivita.aperte, "Aperte"), (FiltroAttivita.completate, "Completate"), (FiltroAttivita.tutte, "Tutte")],
                       selezione: $stato.filtroStatoAttivita)
                .frame(width: 260)
            Spacer(minLength: 0)
            MenuTendina(selezione: $stato.filtroClienteAttivita,
                        opzioni: [(String?.none, "Tutti i clienti")] + stato.clienti.map { (Optional($0.id), $0.nome) },
                        larghezza: 180)
            MenuTendina(selezione: $stato.filtroPrioritaAttivita,
                        opzioni: [(Attivita.Priorita?.none, "Tutte le priorità")] + Attivita.Priorita.allCases.map { (Optional($0), $0.nome) },
                        larghezza: 150)
        }
        .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10))
        .background(Colori.Attivita.metalloAlto)
        .bordoBasso(Colori.Attivita.metalloBordo)
    }

    private func carta(_ voci: [Attivita], _ scelta: Attivita?) -> some View {
        let nomi = Dictionary(stato.clienti.map { ($0.id, $0.nome) }, uniquingKeysWith: { a, _ in a })
        return VStack(spacing: 0) {
            HStack {
                Text("ELENCO ATTIVITÀ")
                    .font(Tipo.elencoTitolo)
                    .tracking(0.3)
                Spacer()
                Text("\(voci.count) \(voci.count == 1 ? "voce" : "voci") · per scadenza")
                    .font(Tipo.elencoTitolo)
            }
            .foregroundColor(Colori.Attivita.titoloElenco)
            .padding(.leading, Misure.Attivita.margineRiga + 14)
            .padding(.trailing, 16)
            .frame(height: 32)
            .background(Colori.Attivita.titoloElencoFondo)
            .bordoBasso(Colori.Attivita.titoloElencoBordo)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(voci) { t in
                        RigaRegistroAttivita(
                            attivita: t,
                            cliente: nomi[t.clienteId] ?? "Cliente",
                            daAppuntamento: t.appuntamentoId != nil,
                            selezionata: t.id == scelta?.id,
                            spunta: { stato.alternaCompletata(t.id) },
                            seleziona: { stato.attivitaSelezionata = t.id }
                        )
                    }
                    if voci.isEmpty { vuoto }
                }
            }
        }
    }

    private var vuoto: some View {
        VStack(spacing: 10) {
            Text("✓").font(Tipo.simboloQuieto).foregroundColor(Colori.Attivita.vuoto)
            Text(stato.filtroStatoAttivita == .completate ? "Le cose fatte, tutte qui."
                 : stato.filtroStatoAttivita == .aperte ? "Hai spazio per il prossimo passo." : "Il tuo elenco comincia qui.")
                .font(Tipo.vuotoTitolo)
                .foregroundColor(Colori.Attivita.vuotoTitolo)
            Text(stato.filtroStatoAttivita == .completate ? "Le attività che completi rimangono disponibili in questa sezione."
                 : "Nessuna attività con questi filtri. Aggiungine una e collegala a un cliente.")
                .font(Tipo.vuotoTesto)
                .foregroundColor(Colori.Attivita.vuotoTesto)
                .multilineTextAlignment(.center)
            Button("＋ Nuova attività") { nuova() }
                .buttonStyle(StileBlu())
        }
        .padding(EdgeInsets(top: 36, leading: Misure.Attivita.margineRiga + 10, bottom: 30, trailing: 24))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Dettaglio

    private func pannelloDettaglio(_ selezionata: Attivita?) -> some View {
        Group {
            if let t = selezionata {
                DettaglioAttivita(attivita: t) { modulo = t }
            } else {
                VStack(spacing: 10) {
                    Text("✎").font(Tipo.simboloQuieto).foregroundColor(Colori.Attivita.vuoto)
                    Text("Un passo alla volta.")
                        .font(Tipo.quietoTitolo)
                        .foregroundColor(Colori.Attivita.dettaglioTitolo)
                    Text("Appunta ciò che serve, assegna una priorità e ritrova subito il cliente a cui dedicarti.")
                        .font(Tipo.quietoTesto)
                        .foregroundColor(Colori.Attivita.vuotoTesto)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Apri Agenda") { stato.apri(.agenda) }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                }
                .padding(.top, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 9, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Colori.Attivita.dettaglioFondo)
        .overlay(alignment: .leading) {
            Rectangle().fill(Colori.Attivita.dettaglioBordo).frame(width: Tema.Misura.filo)
        }
    }
}

// MARK: - Riga del registro

struct RigaRegistroAttivita: View {
    let attivita: Attivita
    let cliente: String
    let daAppuntamento: Bool
    let selezionata: Bool
    let spunta: () -> Void
    let seleziona: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            SpuntaAttivita(fatta: attivita.completata, azione: spunta)
                .frame(width: Misure.Attivita.margineRiga - 20)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 2)
            Button(action: seleziona) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(attivita.titolo)
                            .font(Tipo.attivitaTitolo)
                            .foregroundColor(attivita.completata ? Colori.Attivita.rigaTitoloFatto : Colori.Attivita.rigaTitolo)
                            .strikethrough(attivita.completata, color: Colori.Attivita.rigaTitoloFatto)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(cliente + (daAppuntamento ? " · Da un appuntamento" : ""))
                            .font(Tipo.attivitaSotto)
                            .foregroundColor(Colori.Attivita.rigaSotto)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 6) {
                        ScadenzaAttivita(attivita: attivita)
                        PrioritaAttivita(priorita: attivita.priorita)
                    }
                    .frame(width: Misure.Attivita.colonnaScadenza, alignment: .trailing)
                }
            }
            .buttonStyle(StileSemplice())
        }
        .padding(EdgeInsets(top: 9, leading: 10, bottom: 9, trailing: 16))
        .frame(minHeight: Misure.Attivita.rigaMinima)
        .background(selezionata ? Colori.Attivita.rigaSelezione : Color.clear)
        .bordoBasso(Colori.Attivita.rigaBordo)
    }
}

/// Casella tonda da spuntare (.tk-checkbox).
struct SpuntaAttivita: View {
    let fatta: Bool
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            ZStack {
                Circle().fill(fatta ? Colori.Attivita.spuntaFattaAlto : Colori.Attivita.spuntaAlto)
                Circle().strokeBorder(fatta ? Colori.Attivita.spuntaFattaBordo : Colori.Attivita.spuntaBordo, lineWidth: 1)
                if fatta {
                    Text("✓").font(Tipo.spunta).foregroundColor(Tema.Colore.Componenti.testoSuColore)
                }
            }
            .frame(width: Misure.Attivita.spunta, height: Misure.Attivita.spunta)
        }
        .buttonStyle(StileSemplice())
        .help(fatta ? "Riapri" : "Segna completata")
    }
}

struct ScadenzaAttivita: View {
    let attivita: Attivita

    private var aspetto: (testo: String, colore: Color) {
        let cal = CalendarioAgenda.cal
        if attivita.completata { return ("Completata", Colori.Attivita.scadenzaFatta) }
        if attivita.scadenza < cal.startOfDay(for: Date()) {
            return ("Scaduta · \(Formati.giornoMese.string(from: attivita.scadenza))", Colori.Attivita.scadenzaPassata)
        }
        if cal.isDateInToday(attivita.scadenza) { return ("Oggi", Colori.Attivita.scadenzaOggi) }
        if cal.isDateInTomorrow(attivita.scadenza) { return ("Domani", Colori.Attivita.scadenza) }
        return (Formati.giornoMese.string(from: attivita.scadenza), Colori.Attivita.scadenza)
    }

    var body: some View {
        Text(aspetto.testo)
            .font(Tipo.attivitaSotto)
            .foregroundColor(aspetto.colore)
            .multilineTextAlignment(.trailing)
    }
}

struct PrioritaAttivita: View {
    let priorita: Attivita.Priorita

    var body: some View {
        Text("\(priorita == .alta ? "●" : "○") \(priorita.nome)")
            .font(Tipo.attivitaSotto)
            .foregroundColor(priorita == .alta ? Colori.Attivita.prioritaAlta
                             : priorita == .bassa ? Colori.Attivita.prioritaBassa : Colori.Attivita.scadenza)
    }
}

// MARK: - Dettaglio dell'attività

struct DettaglioAttivita: View {
    @EnvironmentObject var stato: StatoShell
    let attivita: Attivita
    let modifica: () -> Void

    var body: some View {
        let evento = stato.appuntamento(attivita.appuntamentoId)
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(attivita.completata ? "ATTIVITÀ COMPLETATA" : "IL PROSSIMO PASSO")
                        .font(Tipo.dettaglioOcchiello)
                        .tracking(1.2)
                        .foregroundColor(Colori.Attivita.dettaglioOcchiello)
                    Text(attivita.titolo)
                        .font(Tipo.dettaglioTitolo)
                        .foregroundColor(Colori.Attivita.dettaglioTitolo)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 5)
                    Text(stato.cliente(attivita.clienteId)?.nome ?? "Cliente")
                        .font(Tipo.dettaglioCliente)
                        .foregroundColor(Colori.Attivita.dettaglioCliente)
                        .padding(.bottom, 8)
                    voce("Scadenza") {
                        Text(Formati.dataEstesa.string(from: attivita.scadenza))
                            .font(Tipo.voceValore).foregroundColor(Colori.Attivita.voceValore)
                    }
                    voce("Priorità") { PrioritaAttivita(priorita: attivita.priorita) }
                    voce("Stato") {
                        Text(attivita.completata ? "✓ Completata" : "Da svolgere")
                            .font(Tipo.voceValore).foregroundColor(Colori.Attivita.voceValore)
                    }
                    if !attivita.note.isEmpty {
                        Text(attivita.note)
                            .font(Tipo.voceValore)
                            .foregroundColor(Colori.Attivita.voceValore)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 10)
                    }
                    if let e = evento {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("APPUNTAMENTO COLLEGATO")
                                .font(Tipo.voceEtichetta)
                                .tracking(0.3)
                                .foregroundColor(Colori.Attivita.collegamentoEtichetta)
                            Text(e.titolo)
                                .font(Tipo.voceValore)
                                .foregroundColor(Colori.Attivita.collegamentoTitolo)
                            Text("\(Formati.giornoMese.string(from: e.inizio)) · \(Formati.ora.string(from: e.inizio))")
                                .font(Tipo.voceEtichetta)
                                .foregroundColor(Colori.Attivita.collegamentoTesto)
                            Button("Apri in Agenda") { stato.mostraInAgenda(e) }
                                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 9, bottom: 4, trailing: 9)))
                                .padding(.top, 2)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .vetro(.chip, forma: .arrotondata(Tema.Raggio.Dossier.riquadro), riempimento: Colori.Attivita.collegamentoFondo)
                        .padding(.vertical, 10)
                    }
                }
            }
            VStack(spacing: 6) {
                PulsanteAzione(titolo: attivita.completata ? "Riapri attività" : "✓ Segna completata", principale: true) {
                    stato.alternaCompletata(attivita.id)
                }
                PulsanteAzione(titolo: "Modifica attività", azione: modifica)
                HStack(spacing: 6) {
                    PulsanteAzione(titolo: "✦ Chiedi a Eve") {
                        stato.clienteAttivoId = attivita.clienteId
                        stato.apri(.eve)
                    }
                    PulsanteAzione(titolo: "Scheda cliente") { stato.apriCliente(attivita.clienteId) }
                }
                Text("Puoi sempre riaprire un'attività completata.")
                    .font(Tipo.quietoSuggerimento)
                    .foregroundColor(Colori.Attivita.nota)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.top, 8)
        }
    }

    private func voce<V: View>(_ etichetta: String, @ViewBuilder _ valore: () -> V) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(etichetta).font(Tipo.voceEtichetta).foregroundColor(Colori.Attivita.voceEtichetta)
            Spacer()
            valore()
        }
        .padding(.vertical, 6)
        .bordoBasso(Colori.Attivita.voceBordo)
    }
}
