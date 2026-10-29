import SwiftUI

private typealias M = Tema.Misura.Adeguatezza
private typealias K = Tema.Colore.Adeguatezza

/// La scheda di adeguatezza nel dettaglio di una proposta (giro 4, specifica 1): semaforo complessivo, sette
/// controlli a semaforo, le scelte del consulente (bisogno, sostituita, fonte del capitale, motivazione), i
/// documenti da consegnare con le spunte, i pulsanti del PDF e la firma. Calcolata a richiesta a ogni corpo:
/// una proposta sola, niente cache.
struct PannelloAdeguatezza: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) var modoIstantanea
    let posizione: Posizione
    @State private var mostraMetodo = false
    @State private var daSalvare: PDFDaSalvare?
    @State private var archiviato: String?
    @State private var confermaFirma = false

    var body: some View {
        if let ingresso = stato.ingressoAdeguatezza(posizione) {
            contenuto(ingresso, MotoreAdeguatezza.calcola(ingresso))
        }
    }

    private func contenuto(_ i: IngressoAdeguatezza, _ esito: EsitoAdeguatezza) -> some View {
        let scheda = i.scheda
        let firmata = scheda?.firmata == true
        return PannelloAnalisi(titolo: TestiAdeguatezza.genere,
                               nota: "I controlli del dossier raccolti per questa proposta. Non è un parere legale.") {
            HStack(spacing: M.spazioPulsanti) {
                Pillola(testo: TestiAdeguatezza.complessivo(esito.complessivo), tono: .semaforo(esito.complessivo))
                EtichettaCanale(canale: posizione.canale, compatta: true)
                Button(mostraMetodo ? "Nascondi il metodo" : "Come si giudica?") { mostraMetodo.toggle() }
                    .buttonStyle(StileVetro(margine: M.marginePulsante))
                    .fixedSize()
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: M.spazioSezioni) {
                fascia(esito, scheda: scheda)
                HStack(alignment: .top, spacing: M.spazioColonne) {
                    controlli(esito)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    scelte(i, esito, firmata: firmata)
                        .frame(width: M.colonnaScelte, alignment: .leading)
                }
                Text(TestiAdeguatezza.avvertenzaBreve)
                    .font(Tipo.kpiNota)
                    .foregroundColor(K.nota)
                    .fixedSize(horizontal: false, vertical: true)
                if mostraMetodo {
                    NotaMetodo(testo: TestiAdeguatezza.metodo.joined(separator: "\n"), titolo: "Come si giudica")
                }
            }
        }
        .sheet(item: $daSalvare) { pdf in
            ModuloSalvaPDF(pdf: pdf, impostazioni: stato.dati.impostazioni.pdf)
                .environmentObject(stato)
        }
        .alert("La scheda non è completa", isPresented: $confermaFirma) {
            Button("Annulla", role: .cancel) {}
            Button("Segna firmata") { stato.firmaScheda(posizione) }
        } message: {
            Text("Ci sono controlli da rivedere o da completare, oppure documenti non spuntati. La segni lo stesso come firmata? I colori di adesso restano registrati.")
        }
    }

    // MARK: - Indicatori

    private func fascia(_ esito: EsitoAdeguatezza, scheda: SchedaAdeguatezza?) -> some View {
        FasciaKPI {
            KPI(titolo: "Esito", valore: TestiAdeguatezza.complessivo(esito.complessivo)) {
                Text(TestiAdeguatezza.conteggio(esito))
            }
            KPI(titolo: "Documenti", valore: "\(esito.consegnati) di \(esito.daConsegnare)") {
                Text(esito.documentiCompleti && !esito.documenti.isEmpty ? "tutti consegnati" : "consegnati")
            }
            KPI(titolo: "Firma", valore: scheda?.firmataIl.map { Formati.dataBreve.string(from: $0) } ?? "Da firmare", ultimo: true) {
                Text(TestiAdeguatezza.consulente(posizione.canale))
            }
        }
    }

    // MARK: - Controlli

    private func controlli(_ esito: EsitoAdeguatezza) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(esito.controlli) { c in
                rigaControllo(c)
            }
            if !esito.esclusi.isEmpty {
                Text(nonPertinenti(esito.esclusi))
                    .font(Tipo.kpiNota)
                    .foregroundColor(K.nota)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, M.spazioRighe)
            }
        }
    }

    private func rigaControllo(_ c: ControlloAdeguatezza) -> some View {
        VStack(alignment: .leading, spacing: M.spazioCampo) {
            HStack(spacing: M.spazioPallino) {
                Circle()
                    .fill(K.semaforo(c.semaforo))
                    .frame(width: M.pallino, height: M.pallino)
                Text(TestiAdeguatezza.titolo(c.tipo))
                    .font(Tipo.tabellaCellaForte)
                    .foregroundColor(K.testo)
                Spacer(minLength: M.spazioRighe)
                if c.stimato { Pillola(testo: "stimato", tono: .neutro) }
                Pillola(testo: TestiAdeguatezza.etichetta(c.semaforo), tono: .semaforo(c.semaforo))
            }
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                Text(c.esito)
                    .font(Tipo.kpiNota)
                    .foregroundColor(K.testo)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(c.dettagli.enumerated()), id: \.offset) { _, d in
                    Text("• \(d)")
                        .font(Tipo.kpiNota)
                        .foregroundColor(K.nota)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, M.pallino + M.spazioPallino)
        }
        .padding(M.margineRiga)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bordoBasso(K.riga)
        .help(c.fonte)
    }

    private func nonPertinenti(_ esclusi: [ControlloEscluso]) -> String {
        "Non pertinenti: " + esclusi.map { "\(TestiAdeguatezza.titolo($0.tipo)): \($0.motivo)" }.joined(separator: " ")
    }

    // MARK: - Le tue scelte

    private func scelte(_ i: IngressoAdeguatezza, _ esito: EsitoAdeguatezza, firmata: Bool) -> some View {
        let scheda = i.scheda
        return VStack(alignment: .leading, spacing: M.spazioSezioni) {
            VStack(alignment: .leading, spacing: M.spazioSezioni) {
                Text("Le tue scelte")
                    .font(Tipo.tabellaCellaForte)
                    .foregroundColor(K.testo)
                bisogno(i, esito)
                sostituita(i, esito)
                if posizione.versamentoIniziale > 0 {
                    campo("Capitale iniziale da") {
                        MenuTendina(selezione: Binding<FonteCapitale>(
                                        get: { esito.fonte ?? .liquidita },
                                        set: { nuova in stato.modificaScheda(posizione) { $0.fonte = nuova } }),
                                    opzioni: FonteCapitale.allCases.map { ($0, $0.nome) }, larghezza: M.colonnaScelte)
                    }
                }
                campo("Motivazione") { motivazione(scheda) }
                documenti(esito)
            }
            .disabled(firmata)
            if firmata {
                Text("Per modificarla togli la firma.")
                    .font(Tipo.kpiNota)
                    .foregroundColor(K.nota)
            }
            pulsantiPDF
            firma(esito, scheda: scheda)
        }
    }

    private func campo<Contenuto: View>(_ titolo: String, @ViewBuilder _ contenuto: () -> Contenuto) -> some View {
        VStack(alignment: .leading, spacing: M.spazioCampo) {
            Text(titolo)
                .font(Tipo.chip)
                .foregroundColor(K.nota)
            contenuto()
        }
    }

    // Risponde a

    private func bisogno(_ i: IngressoAdeguatezza, _ esito: EsitoAdeguatezza) -> some View {
        let opzioni = opzioniBisogno(i)
        let selezione = Binding<CollegamentoBisogno?>(
            get: { i.scheda?.collegamento },
            set: { nuovo in stato.modificaScheda(posizione) { $0.collegamento = nuovo } })
        return campo("Risponde a") {
            MenuTendina(selezione: selezione, opzioni: opzioni, larghezza: M.colonnaScelte)
            if esito.collegamentoSuggerito, let c = esito.collegamento {
                HStack(alignment: .firstTextBaseline, spacing: M.spazioPulsanti) {
                    Text("Prisma suggerisce: \(TestiAdeguatezza.descrizione(c, bisogni: i.bisogni, obiettivi: i.obiettivi))")
                        .font(Tipo.kpiNota)
                        .foregroundColor(K.nota)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Conferma") { stato.modificaScheda(posizione) { $0.collegamento = c } }
                        .buttonStyle(StileCollegamento())
                }
            }
        }
    }

    /// Le voci del menu «Risponde a»: i bisogni rilevati (prima i confermati, gli scartati no), le sei aree,
    /// gli obiettivi del cliente. Il collegamento della scheda c'è sempre, anche se non è più tra questi.
    private func opzioniBisogno(_ i: IngressoAdeguatezza) -> [(CollegamentoBisogno?, String)] {
        let esiti = i.cliente.bisogni.esiti
        var opzioni: [(CollegamentoBisogno?, String)] = [(nil, "Non indicato")]
        for b in i.bisogni where esiti[b.id] == true {
            opzioni.append((CollegamentoBisogno.rilevato(b.id), "Bisogno: \(b.titolo)"))
        }
        for b in i.bisogni where esiti[b.id] == nil {
            opzioni.append((CollegamentoBisogno.rilevato(b.id), "Bisogno: \(b.titolo) (da confermare)"))
        }
        for a in AreaBisogno.allCases {
            let importanza = i.cliente.bisogni.valutazione(a).importanza
            opzioni.append((CollegamentoBisogno.area(a), "Area: \(a.nome) · \(importanza.nome.lowercased())"))
        }
        for o in i.obiettivi {
            opzioni.append((CollegamentoBisogno.obiettivo(o.id), "Obiettivo: \(o.titolo)"))
        }
        if let attuale = i.scheda?.collegamento, !opzioni.contains(where: { $0.0 == attuale }) {
            opzioni.append((attuale, TestiAdeguatezza.descrizione(attuale, bisogni: i.bisogni, obiettivi: i.obiettivi)))
        }
        return opzioni
    }

    // Sostituisce

    private func sostituita(_ i: IngressoAdeguatezza, _ esito: EsitoAdeguatezza) -> some View {
        let aree: Set<AreaPosizione> = [.investimento, .risparmio, .previdenza, .protezione]
        let propostaId = posizione.id
        let candidate = i.posizioni.filter { p in
            guard p.id != propostaId, p.stato == .inEssere else { return false }
            return aree.contains(p.area)
        }
        let opzioni = opzioniSostituita(candidate, attuale: i.scheda?.posizioneSostituitaId)
        let selezione = Binding<String?>(
            get: { i.scheda?.posizioneSostituitaId },
            set: { nuova in stato.modificaScheda(posizione) { $0.posizioneSostituitaId = nuova } })
        let suggerita = esito.sostituitaSuggerita.flatMap { id in candidate.first { $0.id == id } }
        return campo("Sostituisce") {
            HStack(spacing: M.spazioPulsanti) {
                MenuTendina(selezione: selezione, opzioni: opzioni,
                            larghezza: esito.sostituita == nil ? M.colonnaScelte : nil)
                if let s = esito.sostituita {
                    EtichettaCanale(canale: s.canale, compatta: true)
                }
            }
            if let s = suggerita {
                HStack(alignment: .firstTextBaseline, spacing: M.spazioPulsanti) {
                    Text("Forse sostituisce \(s.nome)")
                        .font(Tipo.kpiNota)
                        .foregroundColor(K.nota)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Usa") { stato.modificaScheda(posizione) { $0.posizioneSostituitaId = s.id } }
                        .buttonStyle(StileCollegamento())
                }
            }
        }
    }

    private func opzioniSostituita(_ candidate: [Posizione], attuale: String?) -> [(String?, String)] {
        var opzioni: [(String?, String)] = [(nil, "Nessuna: nuovo investimento")]
        for p in candidate {
            opzioni.append((p.id, "\(p.nome) · \(p.canale.nomeBreve)"))
        }
        if let attuale, !candidate.contains(where: { $0.id == attuale }) {
            opzioni.append((attuale, "Posizione non più in essere"))
        }
        return opzioni
    }

    // Motivazione

    private func motivazione(_ scheda: SchedaAdeguatezza?) -> some View {
        let testo = Binding<String>(
            get: { scheda?.motivazione ?? "" },
            set: { nuovo in stato.modificaScheda(posizione) { $0.motivazione = nuovo } })
        // Il campo cresce con il testo (fino all'altezza massima, poi scorre): la motivazione si legge intera,
        // senza la barra di scorrimento. L'altezza la dà il testo invisibile sotto il campo, a capo come il campo.
        let margini = M.margineMotivazione.top + M.margineMotivazione.bottom
        return TestoRinviato(testo: testo, salvaOra: { stato.salvaOra() }) { bozza in
            Text(verbatim: bozza.wrappedValue + "\n")
                .font(Tipo.strumentoTesto)
                .padding(.horizontal, M.rientroMotivazione)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .hidden()
                .frame(minHeight: M.altezzaMotivazione - margini, maxHeight: M.altezzaMotivazioneMassima - margini, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: bozza)
                            .font(Tipo.strumentoTesto)
                            .foregroundColor(K.testo)
                            .scrollContentBackground(.hidden)
                        if bozza.wrappedValue.isEmpty {
                            Text("Perché questa proposta è adatta al cliente: entra nel PDF.")
                                .font(Tipo.strumentoTesto)
                                .foregroundColor(K.segnaposto)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(M.margineMotivazione)
                .background { RoundedRectangle(cornerRadius: M.raggioMotivazione, style: .continuous).fill(K.campo) }
        }
        .id(posizione.id)
    }

    // Documenti

    private func documenti(_ esito: EsitoAdeguatezza) -> some View {
        VStack(alignment: .leading, spacing: M.spazioCampo) {
            HStack(spacing: M.spazioPulsanti) {
                // Il canale lo dice già l'etichetta accanto
                Text("Documenti da consegnare")
                    .font(Tipo.chip)
                    .foregroundColor(K.nota)
                EtichettaCanale(canale: posizione.canale, compatta: true)
            }
            if esito.documenti.isEmpty {
                Text("Nessun documento per questo canale e questo tipo di prodotto: aggiungili in Impostazioni › Proposte.")
                    .font(Tipo.kpiNota)
                    .foregroundColor(K.nota)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(esito.documenti) { d in
                voceDocumento(d)
            }
            Button {
                stato.schedaImpostazioni = .proposte
                stato.apri(.impostazioni)
            } label: {
                HStack(spacing: Tema.Misura.Componenti.spazioSimboloPulsante) {
                    Text("Modifica l'elenco in Impostazioni")
                    Image(systemName: "arrow.up.right")
                }
            }
            .buttonStyle(StileCollegamento())
        }
    }

    private func voceDocumento(_ d: DocumentoDaConsegnare) -> some View {
        let consegnato = d.consegnatoIl != nil
        return Button {
            stato.segnaConsegna(posizione, voce: d.id, consegnato: !consegnato)
        } label: {
            HStack(alignment: .top, spacing: M.spazioSpunta) {
                Image(systemName: consegnato ? "checkmark.square.fill" : "square")
                    .font(Tema.Testo.Strumenti.spunta)
                    .foregroundColor(consegnato ? K.spunta : K.spuntaVuota)
                VStack(alignment: .leading, spacing: M.spazioTesto) {
                    Text(d.voce.titolo)
                        .font(Tipo.strumentoTesto)
                        .foregroundColor(K.testo)
                        .strikethrough(d.nonPertinente)
                        .fixedSize(horizontal: false, vertical: true)
                    if !d.voce.dettaglio.isEmpty {
                        Text(d.voce.dettaglio)
                            .font(Tipo.chip)
                            .foregroundColor(K.nota)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let data = d.consegnatoIl {
                        Text("consegnato il \(Formati.dataBreve.string(from: data))")
                            .font(Tipo.chip)
                            .foregroundColor(K.verde)
                    } else if d.nonPertinente {
                        Text("Non serve per questa proposta")
                            .font(Tipo.chip)
                            .foregroundColor(K.nota)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(M.margineDocumento)
            .opacity(d.nonPertinente ? M.opacitaNonPertinente : 1)
        }
        .buttonStyle(StileSemplice())
        .contextMenu {
            Button(d.nonPertinente ? "Serve per questa proposta" : "Non serve per questa proposta") {
                stato.segnaDocumentoNonPertinente(posizione, voce: d.id, nonPertinente: !d.nonPertinente)
            }
        }
    }

    // MARK: - PDF e firma

    private var pulsantiPDF: some View {
        VStack(alignment: .leading, spacing: M.spazioPulsanti) {
            HStack(spacing: M.spazioPulsanti) {
                Button {
                    if let d = stato.documentoAdeguatezza(posizione) { stato.presenta(d) }
                } label: {
                    Label("Presenta", systemImage: "play.fill")
                }
                .buttonStyle(StileVetro(margine: M.marginePulsante))
                .fixedSize()
                .help("Mostra la scheda a tutto schermo, una pagina alla volta, in modalità cliente")
                Button {
                    if let d = stato.documentoAdeguatezza(posizione), let dati = pdf(d) {
                        daSalvare = PDFDaSalvare(dati: dati, nome: StampaCarta.nomeFile(d), cliente: stato.cliente(posizione.clienteId))
                    }
                } label: {
                    Label("Salva PDF…", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(StileVetro(margine: M.marginePulsante))
                .fixedSize()
                Button {
                    if let d = stato.documentoAdeguatezza(posizione), let dati = pdf(d) {
                        StampaCarta.stampa(dati, formato: d.formato)
                    }
                } label: {
                    Label("Stampa…", systemImage: "printer")
                }
                .buttonStyle(StileVetro(margine: M.marginePulsante))
                .fixedSize()
            }
            // I Documenti sono quelli del cliente attivo: si archivia solo la sua scheda
            if posizione.clienteId == stato.clienteAttivoId {
                HStack(spacing: M.spazioPulsanti) {
                    Button {
                        if let d = stato.documentoAdeguatezza(posizione), let dati = pdf(d) {
                            archiviato = stato.archiviaProspetto(dati, documento: d)
                        }
                    } label: {
                        Label("Archivia nei Documenti", systemImage: "archivebox")
                    }
                    .buttonStyle(StileVetro(margine: M.marginePulsante))
                    .fixedSize()
                    if let id = archiviato {
                        Button {
                            stato.documentoSelezionato = id
                            stato.apri(.documenti)
                        } label: {
                            HStack(spacing: Tema.Misura.Componenti.spazioSimboloPulsante) {
                                Text("Archiviata in Documenti")
                                Image(systemName: "arrow.up.right")
                            }
                        }
                        .buttonStyle(StileCollegamento())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func firma(_ esito: EsitoAdeguatezza, scheda: SchedaAdeguatezza?) -> some View {
        if let data = scheda?.firmataIl {
            HStack(spacing: M.spazioPulsanti) {
                Text("Firmata il \(Formati.dataEstesa.string(from: data))")
                    .font(Tipo.kpiNota)
                    .foregroundColor(K.testo)
                Spacer(minLength: 0)
                Button("Togli la firma") { stato.togliFirmaScheda(posizione) }
                    .buttonStyle(StileCollegamento())
            }
        } else {
            // Il blu della finestra è nella barra della posizione: qui il vetro d'accento
            Button {
                if esito.pronta {
                    stato.firmaScheda(posizione)
                } else {
                    confermaFirma = true
                }
            } label: {
                Label("Segna come firmata…", systemImage: "signature")
            }
            .buttonStyle(StileVetro(accento: true))
            .fixedSize()
            .help("Registra in Prisma che il cliente ha firmato la scheda: i colori di adesso restano registrati")
        }
    }

    private func pdf(_ d: DocumentoStampabile) -> Data? {
        guard !modoIstantanea else { return nil }
        let dati = StampaCarta.pdf(d)
        if dati == nil { stato.mostraAvviso("Non sono riuscito a creare il PDF.") }
        return dati
    }
}
