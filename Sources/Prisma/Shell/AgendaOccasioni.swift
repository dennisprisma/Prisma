import SwiftUI

// Il calendario delle occasioni in Agenda: le righe, il dettaglio, la vista «Occasioni» e lo stato
// (occasioni per intervallo tenute da parte in DerivatiDati, bozze, apertura dalle notifiche, riesame).

/// La chiave delle occasioni tenute da parte in `DerivatiDati.occasioni`. La chiave generale (versione dei
/// calcoli, giorno, modalità cliente) svuota già tutto quando cambia; qui c'è ciò che cambia l'elenco in più.
struct ChiaveOccasioni: Hashable {
    /// Inizio dei giorni.
    let da: Date, a: Date
    let spenti: [TipoOccasione]
    let etaTCM: Int, etaLTC: Int
    /// nil: tutti i clienti visibili; un id: solo quel cliente (il riesame del cliente attivo).
    var cliente: String? = nil
}

extension StatoShell {
    // MARK: - Occasioni per intervallo

    /// Le occasioni dei clienti visibili (in modalità cliente solo il suo) tra due giorni, senza i tipi spenti.
    func occasioni(da: Date, a: Date) -> [Occasione] {
        let k = chiaveOccasioni(da: da, a: a)
        let regole = dati.impostazioni.occasioni
        return occasioniInMemoria(k) {
            MotoreOccasioni.calcola(clienti: clienti, posizioni: posizioni, prodotti: dati.prodotti,
                                    da: k.da, a: k.a, regole: regole, oggi: Date())
        }
    }

    /// Quelle del giorno per l'Agenda, filtrate sul cliente dell'agenda; vuoto con lo strato spento.
    /// Passa dalla settimana del giorno: è lo stesso intervallo della settimana in Agenda, già in memoria.
    func occasioniDelGiorno(_ g: Date) -> [Occasione] {
        guard dati.impostazioni.occasioni.inAgenda else { return [] }
        let cal = Calendar.current
        let giorni = CalendarioAgenda.giorni(settimanaDi: g)
        guard let primo = giorni.first, let ultimo = giorni.last,
              let fine = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: ultimo)) else { return [] }
        let filtro = filtroClienteAgenda
        return occasioni(da: cal.startOfDay(for: primo), a: fine)
            .filter { cal.isDate($0.data, inSameDayAs: g) && (filtro == nil || $0.clienteId == filtro) }
    }

    /// Le occasioni della vista «Occasioni»: 12 mesi dal primo del mese di `giornoAgenda`, filtro cliente e gruppo.
    /// Non dipende dallo strato del calendario (`inAgenda`), ma rispetta i tipi spenti.
    var elencoOccasioniAgenda: [Occasione] {
        let cal = Calendar.current
        let inizio = cal.dateInterval(of: .month, for: giornoAgenda)?.start ?? cal.startOfDay(for: giornoAgenda)
        let fine = cal.date(byAdding: .month, value: RegoleOccasioni.mesiElenco, to: inizio) ?? inizio
        let filtro = filtroClienteAgenda
        let gruppo = gruppoOccasioniAgenda
        return occasioni(da: inizio, a: fine)
            .filter { (filtro == nil || $0.clienteId == filtro) && (gruppo == nil || $0.tipo.gruppo == gruppo) }
    }

    /// Dalle notifiche: vista «Occasioni» su oggi, l'occasione selezionata, nessun filtro cliente.
    /// Cerca nello stesso intervallo delle notifiche (da oggi a oggi + anticipo); se non la trova apre comunque la vista.
    func mostraOccasione(_ id: String) {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: Date())
        let fine = cal.date(byAdding: .day, value: dati.impostazioni.occasioni.anticipoGiorni + 1, to: oggi) ?? oggi
        let trovata = occasioni(da: oggi, a: fine).first { $0.id == id }
        filtroClienteAgenda = nil
        vistaAgenda = .occasioni
        gruppoOccasioniAgenda = nil
        giornoAgenda = oggi
        occasioneSelezionata = trovata
        apri(.agenda)
    }

    /// Le occasioni dei prossimi 12 mesi di un cliente, per il riesame (ordine del giorno, domande, prospetto).
    /// Restano in memoria solo per il cliente attivo: gli altri riesami sono già tenuti da parte per un'ora.
    func occasioniRiesame(_ id: String) -> [Occasione] {
        guard let c = cliente(id) else { return [] }
        let cal = Calendar.current
        let oggi = Date()
        let inizio = cal.startOfDay(for: oggi)
        let fine = cal.date(byAdding: .month, value: RegoleOccasioni.mesiRiesame, to: inizio) ?? inizio
        let regole = dati.impostazioni.occasioni
        let suoi = posizioniCliente(id)
        let prodotti = dati.prodotti
        let calcola = {
            MotoreOccasioni.calcola(cliente: c, posizioni: suoi, prodotti: prodotti, da: inizio, a: fine, regole: regole, oggi: oggi)
        }
        guard id == clienteAttivoId else { return calcola() }
        return occasioniInMemoria(chiaveOccasioni(da: inizio, a: fine, cliente: id), calcola: calcola)
    }

    // MARK: - Bozze dalle occasioni (si aprono nei moduli e si salvano solo con «Salva»)

    /// Un incontro due settimane prima (non prima di oggi), con l'occasione e la fonte nelle note.
    func appuntamentoDaOccasione(_ o: Occasione) -> Appuntamento {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: Date())
        let prima = cal.date(byAdding: .day, value: -RegoleOccasioni.giorniPrimaAppuntamento, to: cal.startOfDay(for: o.data)) ?? oggi
        var a = Appuntamento.nuovo(clienteId: o.clienteId, giorno: max(oggi, prima))
        a.titolo = o.titolo
        a.tipo = o.tipo.gruppo == .contratti ? .analisi : .revisione
        a.canale = o.canale
        a.posizioneId = o.posizioneId
        a.note = "\(o.dettaglio)\n\nFonte: \(o.fonte)"
        return a
    }

    /// Un'attività una settimana prima (non prima di oggi), alta se l'occasione è importante.
    func attivitaDaOccasione(_ o: Occasione) -> Attivita {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: Date())
        let prima = cal.date(byAdding: .day, value: -RegoleOccasioni.giorniPrimaAttivita, to: cal.startOfDay(for: o.data)) ?? oggi
        var t = Attivita.nuova(clienteId: o.clienteId, scadenza: max(oggi, prima))
        t.titolo = "Preparare: \(o.titolo)"
        t.note = o.dettaglio
        t.priorita = o.importanza == .alta ? .alta : .normale
        return t
    }

    // MARK: - Memoria

    private func chiaveOccasioni(da: Date, a: Date, cliente: String? = nil) -> ChiaveOccasioni {
        let cal = Calendar.current
        let r = dati.impostazioni.occasioni
        return ChiaveOccasioni(da: cal.startOfDay(for: da), a: cal.startOfDay(for: a), spenti: r.tipiSpenti,
                               etaTCM: r.etaLimiteTCM, etaLTC: r.etaLimiteLTC, cliente: cliente)
    }

    /// Un intervallo si calcola una volta sola e resta da parte finché i dati non cambiano; oltre
    /// `RegoleOccasioni.intervalliInMemoria` intervalli si svuota e si riparte (memoria leggera).
    private func occasioniInMemoria(_ k: ChiaveOccasioni, calcola: () -> [Occasione]) -> [Occasione] {
        let d = derivatiValidi()
        if let elenco = d.occasioni[k] { return elenco }
        let elenco = calcola()
        if d.occasioni.count >= RegoleOccasioni.intervalliInMemoria { d.occasioni = [:] }
        d.occasioni[k] = elenco
        return elenco
    }
}

// MARK: - Riga dell'occasione

/// Un'occasione nella giornata (sotto «OCCASIONI») e nella vista «Occasioni» (con il giorno a sinistra).
/// Come la riga dell'evento; scelta, il segno a capsula prende il colore del canale.
struct RigaOccasioneAgenda: View {
    let occasione: Occasione
    let cliente: String
    /// Nella vista «Occasioni» la colonna di sinistra mostra giorno e mese al posto del simbolo.
    var conData = false
    let selezionata: Bool
    let azione: () -> Void

    var body: some View {
        let m = Misure.Occasioni.self
        let o = occasione
        Button(action: azione) {
            HStack(alignment: .center, spacing: m.spazioRiga) {
                colonnaSinistra
                    .frame(width: Misure.Agenda.colonnaOra, alignment: .leading)
                VStack(alignment: .leading, spacing: m.spazioTesti) {
                    HStack(spacing: m.spazioTitolo) {
                        if conData {
                            SimboloOccasione(tipo: o.tipo, canale: o.canale)
                        }
                        Text(o.titolo)
                            .font(Tipo.eventoTitolo)
                            .foregroundColor(Colori.Agenda.evento)
                            .lineLimit(1)
                        if let c = o.canale {
                            EtichettaCanale(canale: c, compatta: true)
                        }
                    }
                    Text(cliente)
                        .font(Tipo.eventoCliente)
                        .foregroundColor(Colori.Agenda.eventoCliente)
                        .lineLimit(1)
                    Text(riepilogo)
                        .font(Tipo.eventoDettagli)
                        .foregroundColor(Colori.Agenda.eventoDettagli)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("›")
                    .font(Tipo.eventoFreccia)
                    .foregroundColor(Colori.Agenda.freccia)
            }
            .padding(m.riga)
            .background(selezionata ? Colori.Agenda.rigaSelezione : Color.clear)
            .overlay(alignment: .leading) {
                if selezionata {
                    FormaVetro.capsula.fill(Colori.Agenda.occasione(o.canale))
                        .frame(width: Misure.Agenda.segno)
                        .padding(.vertical, m.margineSegno)
                }
            }
            .bordoBasso(Colori.Agenda.rigaBordo)
        }
        .buttonStyle(StileSemplice())
        .help("Cosa cambia e cosa fare")
    }

    /// Tipo, cifra e dettaglio, senza le parti vuote (tipizzato a parte: alleggerisce il controllo dei tipi del corpo).
    private var riepilogo: String {
        let parti: [String?] = [TestiOccasioni.etichetta(occasione.tipo), TestiOccasioni.valore(occasione), occasione.dettaglio]
        return parti.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    @ViewBuilder private var colonnaSinistra: some View {
        if conData {
            VStack(alignment: .leading, spacing: Misure.Occasioni.spazioData) {
                Text(Formati.giorno.string(from: occasione.data))
                    .font(Tipo.eventoOra)
                    .foregroundColor(Colori.Agenda.ora)
                Text(Formati.meseBreve.string(from: occasione.data))
                    .font(Tipo.eventoFine)
                    .foregroundColor(Colori.Agenda.oraFine)
            }
        } else {
            SimboloOccasione(tipo: occasione.tipo, canale: occasione.canale)
        }
    }
}

// MARK: - Dettaglio dell'occasione

/// Il dettaglio di un'occasione nella colonna destra dell'Agenda: cosa cambia, quando, il canale, la cifra,
/// la posizione o la persona di cui si parla, la fonte e le azioni (appuntamento, attività, analisi).
struct DettaglioOccasione: View {
    @EnvironmentObject var stato: StatoShell
    let occasione: Occasione
    /// AppAgenda: modulo = $0
    let nuovoAppuntamento: (Appuntamento) -> Void
    /// AppAgenda: moduloAttivita = $0
    let nuovaAttivita: (Attivita) -> Void

    var body: some View {
        let m = Misure.Occasioni.self
        let o = occasione
        let cliente = stato.cliente(o.clienteId)
        let posizione: Posizione? = o.posizioneId.flatMap { id in stato.posizioni.first { $0.id == id } }
        let familiare: Familiare? = o.familiareId.flatMap { id in cliente?.famiglia.first { $0.id == id } }
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("UN'OCCASIONE · \(o.tipo.gruppo.nome.uppercased())")
                        .font(Tipo.dettaglioOcchiello)
                        .tracking(m.tracciaOcchiello)
                        .foregroundColor(Colori.Agenda.dettaglioOcchiello)
                    HStack(alignment: .center, spacing: m.spazioIntestazione) {
                        SimboloOccasione(tipo: o.tipo, canale: o.canale, grande: true)
                        Text(o.titolo)
                            .font(Tipo.dettaglioTitolo)
                            .foregroundColor(Colori.Agenda.dettaglioTitolo)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, m.intornoTitolo)
                    HStack(alignment: .firstTextBaseline, spacing: Misure.AgendaImpaginazione.spazioCliente) {
                        Text(cliente?.nome ?? "Cliente")
                            .font(Tipo.dettaglioCliente)
                            .foregroundColor(Colori.Agenda.dettaglioCliente)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Button("Scheda cliente ↗") { stato.apriCliente(o.clienteId) }
                            .buttonStyle(StileSemplice())
                            .font(Tipo.dettaglioCliente)
                            .foregroundColor(Colori.Colonna.collegamento)
                            .fixedSize()
                            .help("Apri la scheda del cliente")
                    }
                    .padding(.bottom, m.sottoCliente)

                    VoceDettaglio(etichetta: "Quando") {
                        valore("\(Formati.giornoSettimana.string(from: o.data)) \(Formati.dataEstesa.string(from: o.data))\n\(quanto(o.data))")
                    }
                    VoceDettaglio(etichetta: "Canale") {
                        if let c = o.canale {
                            EtichettaCanale(canale: c, compatta: true)
                        } else {
                            valore("Non legata a un canale")
                        }
                    }
                    if let cifra = TestiOccasioni.valore(o) {
                        VoceDettaglio(etichetta: "Cifra") { valore(cifra) }
                    }

                    riquadroTesto("COSA CAMBIA", o.dettaglio)

                    if let p = posizione {
                        riquadroPosizione(p)
                    }
                    if let f = familiare {
                        riquadroPersona(f, clienteId: o.clienteId)
                    }

                    VStack(alignment: .leading, spacing: m.spazioNota) {
                        Text("FONTE")
                            .font(Tipo.voceEtichetta)
                            .tracking(m.tracciaEtichetta)
                            .foregroundColor(Colori.Agenda.notaEtichetta)
                        Text(o.fonte)
                            .font(Tipo.quietoSuggerimento)
                            .foregroundColor(Colori.Agenda.voceEtichetta)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(TestiOccasioni.avvertenza)
                            .font(Tipo.quietoSuggerimento)
                            .foregroundColor(Colori.Agenda.occasioneFonte)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, m.intornoNota)
                }
                .padding(.trailing, m.margineScorrimento)
            }

            // Le azioni come nel dettaglio dell'appuntamento: in una fila se c'è posto, altrimenti su due livelli
            let spazio = Misure.AgendaImpaginazione.spazioAzioni
            ViewThatFits(in: .horizontal) {
                HStack(spacing: spazio) {
                    azioneAppuntamento
                    azioneAttivita
                    azioneTerza(posizione)
                }
                VStack(spacing: spazio) {
                    HStack(spacing: spazio) {
                        azioneAppuntamento
                        azioneAttivita
                    }
                    azioneTerza(posizione)
                }
                VStack(spacing: spazio) {
                    azioneAppuntamento
                    azioneAttivita
                    azioneTerza(posizione)
                }
            }
            .padding(.top, m.sopraAzioni)
            .bordoAlto(Colori.Agenda.azioniBordo)
        }
    }

    // MARK: - Azioni

    private var azioneAppuntamento: some View {
        PulsanteAzione(titolo: "＋ Appuntamento", principale: true) {
            nuovoAppuntamento(stato.appuntamentoDaOccasione(occasione))
        }
        .help("Un incontro due settimane prima, con l'occasione e la fonte nelle note")
    }

    private var azioneAttivita: some View {
        PulsanteAzione(titolo: "＋ Attività") {
            nuovaAttivita(stato.attivitaDaOccasione(occasione))
        }
        .help("Un'attività per prepararsi una settimana prima")
    }

    @ViewBuilder private func azioneTerza(_ posizione: Posizione?) -> some View {
        if let p = posizione {
            PulsanteAzione(titolo: "Analizza", simbolo: "chart.bar") { stato.apriPosizione(p) }
                .help("Apri la posizione in Posizioni")
        } else {
            PulsanteAzione(titolo: "Scheda cliente") { stato.apriCliente(occasione.clienteId) }
                .help("Apri la scheda del cliente")
        }
    }

    // MARK: - Parti

    private func valore(_ testo: String) -> some View {
        Text(testo)
            .font(Tipo.voceValore)
            .foregroundColor(Colori.Agenda.voceValore)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// «oggi», «tra 12 giorni», «3 giorni fa».
    private func quanto(_ d: Date) -> String {
        let cal = Calendar.current
        let giorni = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? 0
        if giorni == 0 { return "oggi" }
        if giorni > 0 { return "tra \(giorni) \(giorni == 1 ? "giorno" : "giorni")" }
        return "\(-giorni) \(giorni == -1 ? "giorno" : "giorni") fa"
    }

    /// Il riquadro di testo con lo stesso vetro delle note dell'appuntamento.
    private func riquadroTesto(_ titolo: String, _ testo: String) -> some View {
        let m = Misure.Occasioni.self
        return VStack(alignment: .leading, spacing: m.spazioNota) {
            Text(titolo)
                .font(Tipo.voceEtichetta)
                .tracking(m.tracciaEtichetta)
                .foregroundColor(Colori.Agenda.notaEtichetta)
            Text(testo)
                .font(Tipo.voceValore)
                .foregroundColor(Colori.Agenda.notaTesto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(m.nota)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.chip, forma: .arrotondata(Tema.Raggio.Dossier.riquadro), riempimento: Colori.Agenda.notaFondo)
        .padding(.vertical, m.intornoNota)
    }

    /// La posizione da cui nasce l'occasione (come il riquadro del dettaglio dell'appuntamento).
    private func riquadroPosizione(_ p: Posizione) -> some View {
        let m = Misure.Occasioni.self
        let scadenza: String = p.scadenza.map { "scadenza \(Formati.dataEstesa.string(from: $0))" } ?? ""
        let sottotitolo = [p.area.nome, p.stato.nome, scadenza].filter { !$0.isEmpty }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: m.spazioRiquadro) {
            Text("POSIZIONE DI CUI SI PARLA")
                .font(Tipo.voceEtichetta)
                .tracking(m.tracciaEtichetta)
                .foregroundColor(Colori.Agenda.notaEtichetta)
            HStack(spacing: m.spazioTitolo) {
                Text(p.nome)
                    .font(Tipo.voceValore.weight(.semibold))
                    .foregroundColor(Colori.Agenda.dettaglioTitolo)
                    .lineLimit(1)
                EtichettaCanale(canale: p.canale, compatta: true)
            }
            Text(sottotitolo)
                .font(Tipo.voceEtichetta)
                .foregroundColor(Colori.Agenda.voceEtichetta)
            Button("Analizza in Posizioni ›") { stato.apriPosizione(p) }
                .buttonStyle(StileVetro(margine: m.pulsanteRiquadro))
                .padding(.top, m.sopraPulsante)
        }
        .padding(m.riquadro)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Dossier.riquadro))
        .padding(.bottom, m.sottoRiquadro)
    }

    /// Il familiare di cui si parla: nome, relazione, età e la famiglia del cliente a portata di clic.
    private func riquadroPersona(_ f: Familiare, clienteId: String) -> some View {
        let m = Misure.Occasioni.self
        let eta: String = f.eta.map { "\($0) anni" } ?? ""
        let sottotitolo = [f.relazione.nome, eta].filter { !$0.isEmpty }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: m.spazioRiquadro) {
            Text("PERSONA")
                .font(Tipo.voceEtichetta)
                .tracking(m.tracciaEtichetta)
                .foregroundColor(Colori.Agenda.notaEtichetta)
            Text(f.nome)
                .font(Tipo.voceValore.weight(.semibold))
                .foregroundColor(Colori.Agenda.dettaglioTitolo)
                .lineLimit(1)
            Text(sottotitolo)
                .font(Tipo.voceEtichetta)
                .foregroundColor(Colori.Agenda.voceEtichetta)
            Button("Apri la famiglia ›") {
                stato.clienteAttivoId = clienteId
                stato.schedaCliente = .famiglia
                stato.apri(.clienti)
            }
            .buttonStyle(StileVetro(margine: m.pulsanteRiquadro))
            .padding(.top, m.sopraPulsante)
        }
        .padding(m.riquadro)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Dossier.riquadro))
        .padding(.bottom, m.sottoRiquadro)
    }
}

// MARK: - Vista «Occasioni»

/// Le occasioni di 12 mesi, mese per mese, a tutta altezza nella colonna sinistra dell'Agenda.
/// Rispetta i tipi spenti, il filtro cliente dell'agenda e il gruppo scelto (non lo strato del calendario).
struct ElencoOccasioniAgenda: View {
    @EnvironmentObject var stato: StatoShell
    /// `stato.elencoOccasioniAgenda`, calcolato una volta da AppAgenda.
    let elenco: [Occasione]

    /// Le occasioni di un mese, per l'occhiello.
    private struct Mese: Identifiable {
        let inizio: Date
        var voci: [Occasione]
        var id: Date { inizio }
    }

    private var mesi: [Mese] {
        let cal = Calendar.current
        var gruppi: [Mese] = []
        for o in elenco {
            let inizio = cal.dateInterval(of: .month, for: o.data)?.start ?? cal.startOfDay(for: o.data)
            if let ultimo = gruppi.last, ultimo.inizio == inizio {
                gruppi[gruppi.count - 1].voci.append(o)
            } else {
                gruppi.append(Mese(inizio: inizio, voci: [o]))
            }
        }
        return gruppi
    }

    var body: some View {
        let m = Misure.Occasioni.self
        VStack(spacing: 0) {
            testata
            ScrollView {
                // Pigro: con molti clienti 12 mesi hanno centinaia di occasioni
                LazyVStack(spacing: 0) {
                    if elenco.isEmpty {
                        vuoto
                    } else {
                        ForEach(mesi) { mese in
                            Text(Formati.meseAnno.string(from: mese.inizio).uppercased())
                                .font(Tipo.paginaOcchiello)
                                .tracking(m.tracciaOcchiello)
                                .foregroundColor(Colori.Agenda.occasioneOcchiello)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(m.occhiello)
                            ForEach(mese.voci) { o in
                                RigaOccasioneAgenda(occasione: o, cliente: stato.cliente(o.clienteId)?.nome ?? "Cliente",
                                                    conData: true, selezionata: stato.occasioneSelezionata?.id == o.id) {
                                    stato.occasioneSelezionata = o
                                    stato.appuntamentoSelezionato = nil
                                }
                            }
                        }
                    }
                }
            }
            .bordoAlto(Colori.Agenda.rigaBordo)
        }
    }

    private var testata: some View {
        let m = Misure.Occasioni.self
        return VStack(alignment: .leading, spacing: m.spazioRiepilogo) {
            HStack(alignment: .center, spacing: m.spazioTestata) {
                Text("LE OCCASIONI DI 12 MESI")
                    .font(Tipo.paginaOcchiello)
                    .tracking(m.tracciaOcchiello)
                    .foregroundColor(Colori.Agenda.paginaOcchiello)
                    .lineLimit(1)
                Spacer(minLength: 0)
                MenuTendina(selezione: $stato.gruppoOccasioniAgenda, opzioni: opzioniGruppo, larghezza: m.menuGruppo)
            }
            riepilogo
        }
        .padding(m.testata)
    }

    /// «Tutti i tipi» e i cinque gruppi (tipizzato a parte: alleggerisce il controllo dei tipi della testata).
    private var opzioniGruppo: [(GruppoOccasione?, String)] {
        var opzioni: [(GruppoOccasione?, String)] = [(nil, "Tutti i tipi")]
        for g in GruppoOccasione.allCases { opzioni.append((g, g.nome)) }
        return opzioni
    }

    /// «23 occasioni · 9 Alleanza · 11 indipendente», senza le parti a zero.
    private var riepilogo: some View {
        let n = elenco.count
        let alleanza = elenco.filter { $0.canale == .alleanza }.count
        let indipendente = elenco.filter { $0.canale == .indipendente }.count
        var testo = Text("\(n)").font(Tipo.notaSettimanaForte) + Text(n == 1 ? " occasione" : " occasioni")
        if alleanza > 0 {
            testo = testo + Text(" · ") + Text("\(alleanza)").font(Tipo.notaSettimanaForte) + Text(" Alleanza")
        }
        if indipendente > 0 {
            testo = testo + Text(" · ") + Text("\(indipendente)").font(Tipo.notaSettimanaForte) + Text(" indipendente")
        }
        return testo
            .font(Tipo.notaSettimana)
            .foregroundColor(Colori.Agenda.notaSettimana)
            .lineLimit(1)
    }

    private var vuoto: some View {
        let m = Misure.Occasioni.self
        let cal = Calendar.current
        let mese = cal.dateInterval(of: .month, for: stato.giornoAgenda)?.start ?? stato.giornoAgenda
        return VStack(spacing: m.spazioVuoto) {
            Text(Formati.meseAnno.string(from: mese).capitalized)
                .font(Tipo.vuotoData)
                .foregroundColor(Colori.Agenda.vuotoData)
                .lineLimit(1)
                .minimumScaleFactor(m.scalaMeseVuoto)
            Text("Nessuna occasione in questi 12 mesi.")
                .font(Tipo.vuotoTitolo)
                .foregroundColor(Colori.Agenda.vuotoTitolo)
            Text("Le date nascono dalle posizioni in essere (decorrenza, penali, KID, gestione separata, previdenza), dalla famiglia del cliente e dal calendario fiscale. Più dati ci sono, più occasioni compaiono.")
                .font(Tipo.vuotoTesto)
                .foregroundColor(Colori.Agenda.vuotoTesto)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Apri Impostazioni › Occasioni") {
                stato.schedaImpostazioni = .esperienza
                stato.ancoraImpostazioni = "impostazioni-occasioni"
                stato.apri(.impostazioni)
            }
            .buttonStyle(StileBlu())
            .padding(.top, m.sopraPulsanteVuoto)
        }
        .padding(m.vuoto)
        .frame(maxWidth: .infinity)
    }
}

/// Il dettaglio «quieto» della vista «Occasioni», quando nessuna occasione è scelta.
struct QuietoOccasioni: View {
    var body: some View {
        let m = Misure.Occasioni.self
        VStack(alignment: .leading, spacing: m.spazioQuieto) {
            Text("◇")
                .font(Tipo.simboloQuieto)
                .foregroundColor(Colori.Agenda.quieto)
            Text("Le date che contano.")
                .font(Tipo.quietoTitolo)
                .foregroundColor(Colori.Agenda.dettaglioTitolo)
            Text("Seleziona un'occasione per vedere cosa cambia, la fonte e le azioni.")
                .font(Tipo.quietoTesto)
                .foregroundColor(Colori.Agenda.quietoTesto)
                .fixedSize(horizontal: false, vertical: true)
            Text("Quali tipi vedere e con quanto anticipo saperlo si sceglie in Impostazioni › Occasioni.")
                .font(Tipo.quietoSuggerimento)
                .foregroundColor(Colori.Agenda.quietoSuggerimento)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, m.sopraSuggerimento)
                .bordoAlto(Colori.Agenda.azioniBordo)
        }
    }
}
