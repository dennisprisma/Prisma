import SwiftUI

/// Dettaglio di una posizione: dati del contratto, costi e rischio, proiezione con scenari
/// o, per le coperture, il quadro della protezione. Si apre dentro la finestra, come su iOS 5.
struct DettaglioPosizione: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) private var modoIstantanea
    let posizione: Posizione
    let modifica: () -> Void
    @State var confermaEliminazione = false
    @State var mostraMetodo = false
    @State var moduloRilevazione = false

    private var orizzonteCliente: Int? { stato.cliente(posizione.clienteId)?.profilo.orizzonteAnni }

    /// SRI massimo del profilo del cliente (nil senza propensione), per la riga sull'SRI dei fondi di una multiramo.
    private var sriMassimoProfilo: Int? {
        stato.cliente(posizione.clienteId)?.profilo.propensione.map(MotoreCoerenza.sriMassimo)
    }

    var body: some View {
        let p = posizione
        let prodotto = stato.prodotto(p.prodottoId)
        let finanziariaInEssere = p.area.proiettabile && p.stato == .inEssere
        // Calcoli del dettaglio: andamento, rendimento dei versamenti, gestione separata, riscatto
        let andamentoPosizione: AndamentoPosizione? = finanziariaInEssere ? MotoreAndamento.calcola(p) : nil
        let voce: VoceResoconto? = finanziariaInEssere ? MotoreResoconto.voce(p, prodotto: prodotto) : nil
        // Il Ramo I o, per una multiramo a due parti, la sola parte in gestione separata
        let gestione: EsitoGestioneSeparata? = p.area.proiettabile ? (MotoreGestioneSeparata.calcola(p) ?? MotoreGestioneSeparata.calcolaParte(p)) : nil
        let riscatto: EsitoRiscatto? = MotoreRiscatto.calcola(p, prodotto: prodotto)
        VStack(spacing: 0) {
            barraNavigazione
            ScrollViewReader { lettore in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        intestazione
                        HStack(alignment: .top, spacing: 28) {
                            VStack(alignment: .leading, spacing: 22) {
                                contratto
                                if p.multiramo && p.area.proiettabile {
                                    PannelloComposizione(posizione: p, sriMassimo: sriMassimoProfilo, completa: modifica)
                                        .id("dettaglio-composizione")
                                }
                                if let g = gestione {
                                    if p.multiramoDivisa {
                                        PannelloGestioneSeparata(
                                            esito: g, posizione: p,
                                            titolo: "La parte in gestione separata · \(Formati.percentuale(p.parteGestione * 100))",
                                            notaQuota: "sul valore della parte, \(Formati.euro(p.valore * p.parteGestione))")
                                            .id("dettaglio-gestione")
                                    } else {
                                        PannelloGestioneSeparata(esito: g, posizione: p).id("dettaglio-gestione")
                                    }
                                }
                            }
                            // Con la colonna destra il contratto non va oltre la sua misura: la destra prende il resto
                            .frame(maxWidth: p.area.proiettabile ? Tema.Misura.Dossier.dettaglioSinistraMassima : .infinity,
                                   alignment: .leading)
                            if p.area.proiettabile {
                                VStack(alignment: .leading, spacing: 22) {
                                    costiERischio(prodotto)
                                    if p.stato == .inEssere {
                                        // Il rendimento dei versamenti va qui solo se manca il pannello dell'andamento
                                        fiscalita(prodotto, voce: andamentoPosizione == nil ? voce : nil)
                                        storico(voce)
                                    }
                                }
                                .frame(minWidth: Tema.Misura.Dossier.dettaglioDestraMinima, maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        // La scheda di adeguatezza della proposta (giro 4): controlli, documenti, PDF da firmare
                        if MotoreAdeguatezza.pertinente(p, scheda: stato.schedaAdeguatezza(p.id)) {
                            PannelloAdeguatezza(posizione: p).id("dettaglio-adeguatezza")
                        }
                        if let a = andamentoPosizione {
                            andamento(a, voce: voce).id("dettaglio-andamento")
                            PannelloRiferimento(posizione: p, andamento: a, voce: voce).id("dettaglio-riferimento")
                        }
                        if let r = riscatto, !r.righe.isEmpty {
                            PannelloRiscatto(esito: r).id("dettaglio-riscatto")
                        }
                        if p.area.proiettabile {
                            proiezione
                        } else if p.area == .protezione {
                            protezione
                        }
                        HStack {
                            Spacer()
                            Button {
                                confermaEliminazione = true
                            } label: {
                                Text("Elimina la posizione…").foregroundColor(Colori.Analisi.erroreTesto)
                            }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
                        }
                    }
                    .padding(EdgeInsets(top: 14, leading: 16, bottom: 18, trailing: 16))
                }
                // Il contenuto che scorre sfuma sotto la barra invece di finire tagliato sul filo
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: Tema.Misura.Dossier.sfumaturaBarra)
                        Color.black
                    }
                }
                .onAppear { scorri(lettore) }
                .onChange(of: stato.ancoraPosizioni) { _ in scorri(lettore) }
            }
        }
        .alert("Eliminare \(posizione.nome)?", isPresented: $confermaEliminazione) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                stato.posizioneInDettaglio = nil
                stato.eliminaPosizione(posizione.id)
            }
        } message: {
            Text("La posizione verrà tolta dal dossier del cliente. Se serve, potrai recuperarla da un backup.")
        }
        .sheet(isPresented: $moduloRilevazione) {
            ModuloRilevazione(posizione: posizione) { stato.aggiungiRilevazione($0, a: posizione.id) }
        }
    }

    /// Porta in vista la parte del dettaglio chiesta (da un'istantanea o da un'altra schermata): solo le
    /// ancore «dettaglio-…», le altre sono del dossier.
    private func scorri(_ lettore: ScrollViewProxy) {
        guard let ancora = stato.ancoraPosizioni, ancora.hasPrefix("dettaglio-") else { return }
        let istantanea = modoIstantanea
        DispatchQueue.main.async {
            // Nell'istantanea si scorre di colpo: con il movimento la foto arriverebbe a metà strada
            if istantanea {
                lettore.scrollTo(ancora, anchor: .top)
            } else {
                withAnimation(Animazioni.apertura) { lettore.scrollTo(ancora, anchor: .top) }
            }
            stato.ancoraPosizioni = nil
        }
    }

    // MARK: - Barra

    private var barraNavigazione: some View {
        HStack(spacing: 10) {
            Button { stato.posizioneInDettaglio = nil } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                    Text("Posizioni")
                }
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 10)))
            Spacer()
            if posizione.area.proiettabile {
                Button("Simula") { stato.simula(posizione) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    .help("Porta le ipotesi di questa posizione nel simulatore")
                Button("Confronta") { stato.confronta(posizione) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    .help(posizione.stato == .proposta ? "Confronta la proposta con la posizione in essere" : "Confronta con una proposta o un'altra posizione")
            }
            if posizione.stato == .proposta {
                // L'esito della proposta passa dal modulo: decorrenza, primo valore e versato veri (seguito delle proposte)
                Button("Segna come in essere") { stato.apriEsito(posizione, passo: .accettata, origine: .posizioni) }
                    .buttonStyle(StileBlu())
                    .help("Chiede decorrenza, primo valore e versato prima di passarla in essere")
                Button("Esito…") { stato.apriEsito(posizione, passo: .scelta, origine: .posizioni) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    .help("Rifiutata, rimandata o ancora in attesa")
            }
            if posizione.stato == .proposta, stato.prodotto(posizione.prodottoId)?.condizioni != nil {
                Button("Valutazione") { stato.valutaPosizione(posizione) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    .help("Prospetto e report di riscatto: incassi netti anno per anno in tre scenari")
            }
            if MotoreAdeguatezza.pertinente(posizione, scheda: stato.schedaAdeguatezza(posizione.id)) {
                Button("Adeguatezza") { stato.ancoraPosizioni = "dettaglio-adeguatezza" }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    .help("La scheda di adeguatezza: controlli a semaforo, documenti da consegnare, PDF da firmare")
            }
            Button("Prospetto") { stato.apriProspetto(.posizione(posizione.id)) }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                .help("Il prospetto di dettaglio in PDF: contratto, costi, proiezione anno per anno, fonti")
            Button("Modifica", action: modifica)
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .bordoBasso(Colori.Analisi.tabellaRiga)
    }

    /// Dove vanno l'etichetta del canale e la pillola dello stato nella testata.
    private enum PostoEtichetta { case completa, compatta, sotto }

    /// Il canale accanto al nome se c'è posto, poi compatto, poi sotto il titolo: in una finestra
    /// stretta il nome non si stringe mai fino a una lettera per riga.
    private var intestazione: some View {
        ViewThatFits(in: .horizontal) {
            rigaIntestazione(.completa)
            rigaIntestazione(.compatta)
            rigaIntestazione(.sotto)
        }
    }

    private func rigaIntestazione(_ etichetta: PostoEtichetta) -> some View {
        HStack(alignment: .center, spacing: 14) {
            FormaVetro.capsula
                .fill(Colori.Analisi.area(posizione.area))
                .frame(width: 8, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(posizione.nome.isEmpty ? "Senza nome" : posizione.nome)
                    .font(Tipo.profiloNome)
                    .tracking(-0.4)
                    .foregroundColor(Colori.Analisi.kpiValore)
                    .lineLimit(etichetta == .sotto ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: etichetta == .sotto)
                Text([posizione.area.nome, posizione.tipologia, posizione.emittente].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .lineLimit(etichetta == .sotto ? 2 : 1)
                if etichetta == .sotto {
                    HStack(spacing: 8) {
                        EtichettaCanale(canale: posizione.canale, compatta: true)
                        PillolaStato(posizione: posizione)
                    }
                }
            }
            .layoutPriority(1)
            if etichetta != .sotto {
                Spacer(minLength: 8)
                EtichettaCanale(canale: posizione.canale, compatta: etichetta == .compatta)
                PillolaStato(posizione: posizione)
            }
        }
    }

    // MARK: - Contratto

    private var contratto: some View {
        let p = posizione
        return PannelloAnalisi(titolo: "Dati del contratto") { EmptyView() } contenuto: {
            VStack(spacing: 0) {
                RigaDato("Numero", p.numeroContratto)
                RigaDato("Contraente", p.contraente)
                RigaDato("Assicurato", p.assicurato)
                RigaDato("Beneficiari", p.beneficiari)
                RigaDato("Decorrenza", p.decorrenza.map { Formati.dataEstesa.string(from: $0) } ?? "")
                RigaDato("Scadenza", p.scadenza.map { Formati.dataEstesa.string(from: $0) } ?? "")
                if p.versamentoIniziale > 0 {
                    RigaDato(p.area == .protezione ? "Premio unico" : "Versamento iniziale", Formati.euro(p.versamentoIniziale))
                }
                if p.frequenza != .unica {
                    RigaDato(p.area == .debiti ? "Rata" : "Premio / versamento",
                             "\(Formati.euro(p.premio)) · \(p.frequenza.nome.lowercased()) (\(Formati.euro(p.premioAnnuo)) all'anno)")
                }
                if let v = p.totaleVersato { RigaDato("Totale versato", Formati.euro(v)) }
                if let v = p.controvalore, p.area != .protezione {
                    RigaDato(p.area == .debiti ? "Debito residuo" : "Controvalore",
                             Formati.euro(v) + (p.dataValore.map { " al \(Formati.dataBreve.string(from: $0))" } ?? ""))
                }
                if let c = p.capitaleAssicurato {
                    RigaDato("Capitale assicurato", Formati.euro(c) + (p.rischio.map { " · \($0.nome)" } ?? ""))
                }
                if p.stato == .proposta || p.esito == .accettata {
                    RigaDato("Esito della proposta", TestiSeguito.esito(p, adesso: Date()))
                }
                if let n = p.seguito?.nota, !n.isEmpty { RigaDato("Nota sull'esito", n) }
                RigaDato("Garanzie", p.garanzie)
                RigaDato("Note", p.note)
            }
        }
    }

    private func costiERischio(_ prodotto: Prodotto?) -> some View {
        let p = posizione
        let l = Tema.Misura.MotoriPosizioni.etichettaRiga
        // Il RIY come nel KID: calcolato da Prisma e, se c'è, quello dichiarato (solo nelle schermate)
        let incidenza: IncidenzaCostiKID? = p.stato == .chiusa ? nil : MotoreCosti.incidenzaKID(p, prodotto: prodotto)
        let composizione: ComposizionePosizione? = p.area.proiettabile ? MotoreResistenza.composizione(p) : nil
        let incoerenze = incoerenzeProposta
        return PannelloAnalisi(titolo: "Costi, ipotesi e rischio") { EmptyView() } contenuto: {
            VStack(spacing: 0) {
                if p.multiramoDivisa {
                    // Multiramo a due parti: complessivi pesati sulle quote, con le due parti tra parentesi
                    RigaDato("Rendimento", Self.rendimentoComposto(p), larghezza: l)
                    RigaDato("Costo d'ingresso", p.costoIngresso.map { Formati.percentuale($0) + " dei versamenti" } ?? "", larghezza: l)
                    RigaDato("Costo annuo", Self.costoComposto(p), larghezza: l)
                } else {
                    RigaDato("Rendimento atteso", p.rendimentoAtteso.map { Formati.percentuale($0) + " annuo" } ?? "", larghezza: 118)
                    RigaDato("Costo d'ingresso", p.costoIngresso.map { Formati.percentuale($0) + " dei versamenti" } ?? "", larghezza: 118)
                    RigaDato("Costo annuo", p.costoAnnuo.map { Formati.percentuale($0) + " all'anno" } ?? "", larghezza: 118)
                }
                if let u = p.costoUscita, u > 0 {
                    RigaDato("Costo d'uscita", "\(CifreDoc.percento(u, decimali: 2)) del riscattato", larghezza: l)
                }
                if let k = incidenza, let c = k.calcolato {
                    RigaDato("Costi come nel KID",
                             "\(CifreDoc.percento(c, decimali: 2)) l'anno a \(k.periodoRaccomandato) \(k.periodoRaccomandato == 1 ? "anno" : "anni") (stima)",
                             larghezza: l)
                        .help(IncidenzaCostiKID.metodo)
                    if let d = k.dichiarato {
                        RigaDato("RIY del KID",
                                 CifreDoc.percento(d, decimali: 2) + (k.scarto.map { " · Prisma \(Self.punti($0))" } ?? ""),
                                 larghezza: l,
                                 pillola: (k.scarto ?? 0) > MotoreCosti.scartoMinimo ? Pillola(testo: "più del KID", tono: .attenzione) : nil)
                            .help("Il RIY dichiarato nel KID resta quello del documento: Prisma lo confronta con il suo calcolo, sugli stessi anni.")
                    }
                }
                RigaDato("Fiscalità", p.aliquotaFiscale.map { Formati.percentuale($0) + " sul rendimento" } ?? "", larghezza: 118)
                if let c = composizione {
                    RigaDato("Quota azionaria",
                             CifreDoc.percento(c.azioni * 100, decimali: 0) + (c.stimata ? " (stimata dal tipo e dall'SRI)" : ""),
                             larghezza: l)
                        .help("La parte in azioni usata nella prova di resistenza e nelle crisi del passato.")
                }
                HStack(alignment: .center, spacing: 12) {
                    Text("Rischio (SRI)")
                        .font(Tipo.campoEtichetta)
                        .foregroundColor(Colori.Analisi.kpiNota)
                        .frame(width: 118, alignment: .leading)
                    ScalaRischio(valore: p.sri)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bordoBasso(Colori.Analisi.tabellaRiga)
                if p.multiramoDivisa {
                    // L'SRI resta quello del KID della combinazione; i soli fondi rischiano di più
                    RigaDato("SRI delle parti",
                             "fondi \(p.sriParteFondi)\(p.sriFondi == nil ? " (stimato)" : "") · combinazione \(p.sriComposto)\(p.sri == nil ? " (stimato)" : "")",
                             larghezza: l)
                        .help("Per il profilo conta l'SRI della combinazione scelta, quello del KID; senza, la stima dalla volatilità combinata (solo rischio di mercato).")
                }
                // Le proposte oltre il profilo, l'orizzonte, l'esperienza o la capacità di perdita del cliente
                ForEach(incoerenze) { i in
                    HStack(alignment: .firstTextBaseline, spacing: Tema.Misura.MotoriPosizioni.spazioPillola) {
                        Pillola(testo: i.tipo.pillola, tono: .attenzione)
                        Text(i.dettaglio)
                            .font(Tipo.kpiNota)
                            .foregroundColor(Colori.Analisi.tabellaTesto)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 7)
                    .bordoBasso(Colori.Analisi.tabellaRiga)
                }
            }
        }
    }

    /// Le incoerenze con il profilo del cliente che nascono da questa proposta (SRI o periodo raccomandato).
    private var incoerenzeProposta: [Incoerenza] {
        guard posizione.stato == .proposta, let c = stato.cliente(posizione.clienteId) else { return [] }
        let esito = stato.coerenzaCliente(c)
        return esito.incoerenze.filter { $0.posizione?.id == posizione.id }
    }

    /// «4,50% annuo complessivo (GS 3,00% · fondi 5,50%)»: lordi ipotizzati, pesati sulle quote di oggi.
    static func rendimentoComposto(_ p: Posizione) -> String {
        "\(CifreDoc.percento(p.rendimentoLordoComposto, decimali: 2)) annuo complessivo (GS \(CifreDoc.percento(p.lordoGestione(), decimali: 2)) · fondi \(CifreDoc.percento(p.lordoFondi(), decimali: 2)))"
    }

    /// «1,90% complessivo (GS 1,30 punti sul 40% · fondi 2,30% sul 60%)»; vuoto senza costi indicati.
    static func costoComposto(_ p: Posizione) -> String {
        guard let c = p.costoComplessivo else { return "" }
        let punti = String(CifreDoc.percento(p.trattenutoGestione, decimali: 2).dropLast())
        return "\(CifreDoc.percento(c, decimali: 2)) complessivo (GS \(punti) punti sul \(Formati.percentuale(p.parteGestione * 100))"
            + " · fondi \(CifreDoc.percento(p.costoParteFondi, decimali: 2)) sul \(Formati.percentuale(p.parteFondi * 100)))"
    }

    /// "2", "1": l'ampiezza di uno scenario in punti, senza il segno %.
    static func puntiScenario(_ v: Double) -> String { String(Formati.percentuale(v).dropLast()) }

    /// Una differenza in punti percentuali, con il segno: "+0,45 punti".
    static func punti(_ v: Double) -> String {
        "\(String(CifreDoc.variazione(v, decimali: 2).dropLast())) punti"
    }

    /// Imposte e netto se si chiudesse oggi; per la previdenza l'aliquota per causa.
    private func fiscalita(_ prodotto: Prodotto?, voce: VoceResoconto?) -> some View {
        let f = MotoreFiscale.calcola(posizione, prodotto: prodotto)
        return PannelloAnalisi(titolo: "Se si chiudesse oggi") { EmptyView() } contenuto: {
            VStack(alignment: .leading, spacing: 0) {
                RigaDato("Regime", f.regime.nome, larghezza: 118)
                if f.regime == .previdenza {
                    RigaDato("Partecipazione", "\(f.anniPartecipazione ?? 0) anni", larghezza: 118)
                    ForEach(f.uscite.filter(\.possibile)) { u in
                        RigaDato(u.causa.nomeBreve, "\(Formati.euroDecimali(u.netto)) netti · \(CifreDoc.percento(u.aliquota, decimali: 2))", larghezza: 118)
                    }
                    if let g = f.gradini.first {
                        RigaDato("Prossimo calo", "dal \(Formati.dataBreve.string(from: g.dal)) al \(CifreDoc.percento(g.aliquota, decimali: 2))", larghezza: 118)
                    }
                } else {
                    if f.penale + f.bolloMaturato > 0.005 {
                        RigaDato("Penale e bollo", Formati.euroDecimali(f.penale + f.bolloMaturato), larghezza: 118)
                    }
                    RigaDato("Imposta", f.imposta > 0.005 ? "\(Formati.euroDecimali(f.imposta)) (\(CifreDoc.percento(f.aliquota, decimali: 2)))" : "nessuna", larghezza: 118)
                    RigaDato("Netto", Formati.euroDecimali(f.netto), larghezza: 118)
                }
                if f.costoTotale > 0.005 {
                    RigaDato("Costi in un anno", Formati.euroDecimali(f.costoTotale), larghezza: 118)
                }
                if let v = voce, let x = v.rendimentoAnnuo {
                    RigaDato("Rendimento dei versamenti",
                             "\(CifreDoc.variazione(x)) l'anno" + (v.rendimentoNettoAnnuo.map { " · netto \(CifreDoc.variazione($0))" } ?? ""),
                             larghezza: 118)
                        .help(Self.notaVersamenti(v))
                }
            }
        }
    }

    /// Come leggere il rendimento dei versamenti (XIRR) accanto al rendimento del prodotto.
    static func notaVersamenti(_ v: VoceResoconto) -> String {
        "Rendimento dei tuoi versamenti: il tasso annuo che lega quanto e quando hai versato al valore di oggi (XIRR); "
            + "il netto usa quanto incasseresti chiudendo oggi. Misura l'esperienza del cliente, non solo il prodotto"
            + (v.flussiDatati?.reali == false ? ". Date ricostruite da premi e storico." : ".")
    }

    /// I valori rilevati nel tempo: si arricchisce da solo a ogni aggiornamento del controvalore.
    private func storico(_ voceCalcolata: VoceResoconto?) -> some View {
        let punti = Array(posizione.storicoValori.reversed())
        let voce = voceCalcolata ?? MotoreResoconto.voce(posizione)
        // In cima c'è il valore attuale: si cambia con «Modifica», non si toglie da qui
        // Il valore attuale è nello storico solo se ha una data (del valore, della decorrenza o di oggi)
        let attuale = posizione.controvalore != nil && (posizione.dataValore ?? posizione.decorrenza) != nil || (posizione.controvalore != nil && !(posizione.rilevazioni ?? []).isEmpty)
        return PannelloAnalisi(titolo: "Storico dei valori") {
            Button("＋ Valore passato") { moduloRilevazione = true }
                .buttonStyle(StileSemplice())
                .font(Tipo.colonnaCollegamento)
                .foregroundColor(Colori.Colonna.collegamento)
                .disabled(stato.solaLettura)
        } contenuto: {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(punti.prefix(8).enumerated()), id: \.offset) { i, r in
                    HStack(spacing: 4) {
                        RigaDato(Formati.dataBreve.string(from: r.data),
                                 Formati.euro(r.controvalore) + (r.versato.map { " · versato \(Formati.euro($0))" } ?? ""), larghezza: 118)
                        if !(i == 0 && attuale) && !stato.solaLettura {
                            Button("✕") { stato.eliminaRilevazione(r.data, da: posizione.id) }
                                .buttonStyle(StileSemplice())
                                .font(Tipo.kpiNota)
                                .foregroundColor(Colori.Analisi.kpiNota)
                                .help("Togli questo valore dallo storico")
                        }
                    }
                }
                if let v = voce.variazione12, let q = voce.variazione12Percento {
                    RigaDato("Ultimi 12 mesi", "\(v.rounded() > 0 ? "+" : "")\(Formati.euro(v)) (\(CifreDoc.variazione(q))), tolti i versamenti", larghezza: 118)
                }
                Text(punti.count < 2 ? "Quando aggiorni il controvalore, il valore precedente resta qui: serve al resoconto per gli ultimi 12 mesi."
                                     : "Il valore precedente resta qui a ogni aggiornamento del controvalore.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Andamento

    /// Com'è andata davvero: il valore rilevato, il versato e dove sarebbe all'atteso netto.
    private func andamento(_ a: AndamentoPosizione, voce: VoceResoconto?) -> some View {
        let annuo = a.rendimentoAnnuo != nil
        // Il rendimento dei versamenti (XIRR) accanto a quello del prodotto, se la posizione ha un anno
        let versamenti: (lordo: Double, netto: Double?)? = voce.flatMap { v in v.rendimentoAnnuo.map { (lordo: $0, netto: v.rendimentoNettoAnnuo) } }
        return PannelloAnalisi(
            titolo: "Andamento dal \(Formati.dataBreve.string(from: a.dal))",
            nota: "Rendimento al netto dei costi, tolti i versamenti: i periodi tra un valore e l'altro pesano allo stesso modo."
        ) {
            if let g = a.giudizio {
                Pillola(testo: g.etichetta, tono: g == .sopra ? .ok : g == .sotto ? .errore : .neutro)
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: 14) {
                GraficoAndamento(punti: a.punti)
                HStack(spacing: 16) {
                    legenda(Colori.Analisi.linea, "Valore rilevato")
                    if a.attesoAnnuo != nil { legenda(Colori.Analisi.lineaAtteso, "All'atteso netto", tratteggio: true) }
                    if a.punti.contains(where: { $0.versato != nil }) { legenda(Colori.Analisi.lineaTratteggiata, "Versato", tratteggio: true) }
                    if versamenti != nil {
                        Spacer(minLength: 0)
                        Text("\(a.punti.count) valori rilevati in \(String(format: "%.1f", a.anni).replacingOccurrences(of: ".", with: ",")) anni")
                            .font(Tipo.kpiNota)
                            .foregroundColor(Colori.Analisi.kpiNota)
                    }
                }
                FasciaKPI {
                    KPI(titolo: annuo ? "Rendimento annuo" : "Rendimento nel periodo",
                        valore: CifreDoc.variazione(a.rendimentoAnnuo ?? a.rendimentoPeriodo)) {
                        Text(annuo ? "\(CifreDoc.variazione(a.rendimentoPeriodo)) in tutto" : "meno di un anno di storico")
                    }
                    KPI(titolo: "Atteso netto", valore: a.attesoConfrontabile.map { CifreDoc.percento($0) } ?? "—") {
                        if let s = a.scarto { Text(MotoreAndamento.punti(s)) } else { Text("manca il rendimento atteso") }
                    }
                    KPI(titolo: a.guadagno >= 0 ? "Guadagno" : "Perdita", valore: CifreDoc.euro(abs(a.guadagno))) {
                        Text("tolti \(Formati.euro(a.versamenti)) di versamenti")
                    }
                    if let x = versamenti {
                        KPI(titolo: "Rendimento dei tuoi versamenti", valore: CifreDoc.variazione(x.lordo), ultimo: true) {
                            Text(x.netto.map { "netto se chiudi oggi \(CifreDoc.variazione($0))" } ?? "l'anno, alle date dei versamenti")
                        }
                        .help(voce.map(Self.notaVersamenti) ?? "")
                    } else {
                        KPI(titolo: "Valori rilevati", valore: "\(a.punti.count)", ultimo: true) {
                            Text(String(format: "%.1f anni", a.anni).replacingOccurrences(of: ".", with: ","))
                        }
                    }
                }
                if versamenti != nil {
                    Text("«Rendimento annuo» giudica il prodotto: ogni periodo tra due valori pesa allo stesso modo. «Rendimento dei tuoi versamenti» racconta l'esperienza del cliente: conta quanto e quando ha versato"
                         + (voce?.flussiDatati?.reali == false ? " (date ricostruite da premi e storico)." : "."))
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.Analisi.kpiNota)
                        .fixedSize(horizontal: false, vertical: true)
                }
                periodiTabella(a)
                Text(MotoreAndamento.sintesi(a, nome: posizione.nome))
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func periodiTabella(_ a: AndamentoPosizione) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                testa("Periodo", nil)
                testa("Valore iniziale", 110)
                testa("Versamenti", 100)
                testa("Valore finale", 110)
                testa("Guadagno", 100)
                testa("Rendimento", 90)
            }
            .background(Colori.Analisi.tabellaTestaAlto)
            .bordoBasso(Colori.Analisi.tabellaTestaBordo)
            // Dal più recente, al massimo otto periodi
            ForEach(Array(a.periodi.reversed().prefix(8).enumerated()), id: \.offset) { i, q in
                HStack(spacing: 0) {
                    Text("\(Formati.dataBreve.string(from: q.dal)) – \(Formati.dataBreve.string(from: q.al))")
                        .font(Tipo.tabellaCellaForte)
                        .foregroundColor(Colori.Analisi.tabellaTesto)
                        .padding(Misure.Analisi.cellaMargine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    cellaNumero(Formati.euro(q.valoreIniziale), 110)
                    cellaNumero((q.stimati ? "≈ " : "") + CifreVista.euroSegno(q.versamenti), 100)
                    cellaNumero(Formati.euro(q.valoreFinale), 110)
                    cellaNumero(CifreVista.euroSegno(q.guadagno), 100,
                                colore: q.guadagno < 0 ? Colori.Analisi.erroreTesto : Colori.Analisi.tabellaTesto)
                    cellaNumero(q.rendimento.map { CifreDoc.variazione($0) } ?? "—", 90,
                                colore: (q.rendimento ?? 0) < 0 ? Colori.Analisi.erroreTesto : Colori.Analisi.tabellaTesto)
                }
                .background(i % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
        }
        .contornoTabella()
    }

    // MARK: - Proiezione

    private var proiezione: some View {
        let parametri = ParametriProiezione(posizione: posizione, orizzonteCliente: orizzonteCliente)
        let scenari = MotoreProiezione.scenari(parametri)
        let atteso = scenari[1].esito
        let impatto = MotoreProiezione.impattoCosti(parametri)
        // Multiramo a due parti: la gestione separata nel tempo, sotto la linea dell'atteso
        let gestione = parametri.gestione
        let nota = gestione.map {
            "Ipotesi dimostrativa: gestione separata al \(CifreDoc.percento($0.lordo, decimali: 2)) lordo, fondi al \(CifreDoc.percento(parametri.rendimento, decimali: 2)) lordo. Non è una previsione."
        } ?? "Ipotesi dimostrativa al \(Formati.percentuale(parametri.rendimento)) annuo lordo. Non è una previsione."
        let principali: [GraficoProiezione.Serie] = [
            .init(id: "prudente", punti: scenari[0].esito.punti, colore: Colori.Analisi.prudente),
            .init(id: "favorevole", punti: scenari[2].esito.punti, colore: Colori.Analisi.favorevole),
            .init(id: "atteso", punti: atteso.punti, colore: Colori.Analisi.linea, principale: true),
        ]
        let puntiGestione: [PuntoProiezione] = atteso.punti.map {
            PuntoProiezione(anno: $0.anno, versato: $0.versato, valore: $0.valoreGestione ?? 0)
        }
        let serie: [GraficoProiezione.Serie] = gestione == nil ? principali
            : principali + [GraficoProiezione.Serie(id: "gestione", punti: puntiGestione, colore: Tema.Colore.Multiramo.gestione)]
        return PannelloAnalisi(
            titolo: "Proiezione a \(parametri.anni) \(parametri.anni == 1 ? "anno" : "anni")",
            nota: nota
        ) {
            Button(mostraMetodo ? "Nascondi il metodo" : "Come viene calcolato?") { mostraMetodo.toggle() }
                .buttonStyle(StileSemplice())
                .font(Tipo.colonnaCollegamento)
                .foregroundColor(Colori.Colonna.collegamento)
        } contenuto: {
            VStack(alignment: .leading, spacing: 14) {
                GraficoProiezione(serie: serie)
                HStack(spacing: 16) {
                    legenda(Colori.Analisi.linea, "Atteso \(Formati.percentuale(scenari[1].rendimento))")
                    legenda(Colori.Analisi.prudente, "Prudente \(Formati.percentuale(scenari[0].rendimento))")
                    legenda(Colori.Analisi.favorevole, "Favorevole \(Formati.percentuale(scenari[2].rendimento))")
                    if gestione != nil {
                        legenda(Tema.Colore.Multiramo.gestione, "di cui gestione separata")
                    }
                    legenda(Colori.Analisi.lineaTratteggiata, "Versato cumulato", tratteggio: true)
                }
                FasciaKPI {
                    KPI(titolo: "Versato", valore: Formati.euro(atteso.versato)) {
                        Text(parametri.versamento > 0 ? "\(Formati.euro(parametri.versamento)) \(parametri.frequenza.nome.lowercased())" : "solo capitale iniziale")
                    }
                    KPI(titolo: "Valore finale netto", valore: Formati.euro(atteso.netto)) {
                        Chip(testo: "lordo \(Formati.euroBreve(atteso.lordo))")
                        Chip(testo: "imposte \(Formati.euroBreve(atteso.imposte))")
                    }
                    KPI(titolo: "In euro di oggi", valore: Formati.euro(atteso.reale)) {
                        Text("inflazione \(Formati.percentuale(parametri.inflazione))")
                    }
                    KPI(titolo: "Costi nel periodo", valore: Formati.euro(atteso.costi), ultimo: true) {
                        Text("tolgono \(Formati.euro(impatto)) al netto")
                    }
                }
                scenariTabella(scenari)
                if mostraMetodo { metodo(parametri) }
            }
        }
    }

    private func scenariTabella(_ scenari: [(nome: String, rendimento: Double, esito: EsitoProiezione)]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                testa("Scenario", nil)
                testa("Rendimento", 110)
                testa("Valore netto", 130)
                testa("Guadagno netto", 130)
                testa("In euro di oggi", 130)
            }
            .background(Colori.Analisi.tabellaTestaAlto)
            .bordoBasso(Colori.Analisi.tabellaTestaBordo)
            ForEach(Array(scenari.enumerated()), id: \.offset) { i, s in
                HStack(spacing: 0) {
                    Text(s.nome).font(Tipo.tabellaCellaForte).padding(Misure.Analisi.cellaMargine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    cellaNumero(Formati.percentuale(s.rendimento), 110)
                    cellaNumero(Formati.euro(s.esito.netto), 130)
                    cellaNumero(Formati.euro(s.esito.guadagnoNetto), 130,
                                colore: s.esito.guadagnoNetto < 0 ? Colori.Analisi.erroreTesto : Colori.Analisi.tabellaTesto)
                    cellaNumero(Formati.euro(s.esito.reale), 130)
                }
                .foregroundColor(Colori.Analisi.tabellaTesto)
                .background(i % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
        }
        .contornoTabella()
    }

    private func metodo(_ p: ParametriProiezione) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Come viene calcolato").font(Tipo.pannelloAnalisi).foregroundColor(Colori.Analisi.pannelloTitolo)
            Group {
                Text("• Si parte da \(Formati.euro(p.capitaleIniziale))\(posizione.stato == .inEssere ? " (valore attuale)" : " (versamento iniziale)")\(p.ingressoSulCapitale && p.costoIngresso > 0 ? ", tolto il costo d'ingresso del \(Formati.percentuale(p.costoIngresso))" : "").")
                if p.versamento > 0 {
                    Text("• Ogni versamento di \(Formati.euro(p.versamento)) (\(p.frequenza.nome.lowercased())) entra al netto del costo d'ingresso.")
                }
                if let g = p.gestione {
                    // Multiramo a due parti: rendimento, costo e aliquota della proiezione sono quelli dei soli fondi
                    Text("• \(MotoreMultiramo.metodo)")
                    Text("• Qui: \(Formati.percentuale(g.quota * 100)) in gestione separata al \(Formati.percentuale(g.lordo)) lordo (accreditato \(Formati.percentuale(g.accreditato))), \(Formati.percentuale((1 - g.quota) * 100)) nei fondi al \(Formati.percentuale(p.rendimento)) lordo con costi e bollo del \(Formati.percentuale(p.costoAnnuo)) l'anno.")
                    Text("• Alla fine, sulla parte che supera il versato si applicano le imposte al \(Formati.percentuale(p.aliquotaEquivalente)) (aliquota pesata sulle due parti).")
                } else {
                    Text("• Ogni mese il capitale cresce del rendimento mensile equivalente al \(Formati.percentuale(p.rendimento)) annuo e paga la quota mensile del costo annuo (\(Formati.percentuale(p.costoAnnuo))).")
                    Text("• Alla fine, sulla parte che supera il versato si applicano le imposte al \(Formati.percentuale(p.aliquotaFiscale)).")
                }
                Text("• Il valore in euro di oggi divide il netto per l'inflazione cumulata al \(Formati.percentuale(p.inflazione)) annuo.")
                if p.gestione != nil {
                    Text("• Gli scenari spostano il rendimento dei fondi di \(Self.puntiScenario(IpotesiCalcolo.ampiezzaScenari)) punti in meno e in più, quello della gestione separata di \(Self.puntiScenario(IpotesiCalcolo.ampiezzaScenariGestione)): si muove molto meno dei mercati. Rendimenti e costi sono quelli indicati nella posizione: verificali sul KID o sul prospetto.")
                } else {
                    Text("• Gli scenari spostano il rendimento di \(Formati.percentuale(IpotesiCalcolo.ampiezzaScenari)) punti in meno e in più. Rendimenti e costi sono quelli indicati nella posizione: verificali sul KID o sul prospetto.")
                }
            }
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Analisi.tabellaTesto)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.kpi), riempimento: Colori.Analisi.kpiAlto)
    }

    // MARK: - Protezione

    private var protezione: some View {
        let p = posizione
        let capitale = p.capitaleAssicurato ?? 0
        let premioAnnuo = p.premioAnnuo > 0 ? p.premioAnnuo : p.versamentoIniziale
        return PannelloAnalisi(titolo: "La copertura", nota: p.rischio?.nome) { EmptyView() } contenuto: {
            FasciaKPI {
                KPI(titolo: "Capitale assicurato", valore: Formati.euro(capitale)) { Text(p.rischio?.nome ?? "Rischio non indicato") }
                KPI(titolo: "Premio annuo", valore: Formati.euro(premioAnnuo)) { Text(p.frequenza.nome.lowercased()) }
                KPI(titolo: "Costo per 1.000 € assicurati", valore: capitale > 0 ? Formati.euroDecimali(premioAnnuo / capitale * 1000) : "—", ultimo: true) {
                    Text("all'anno")
                }
            }
        }
    }

    // MARK: - Piccoli elementi

    private func legenda(_ colore: Color, _ testo: String, tratteggio: Bool = false) -> some View {
        HStack(spacing: 6) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 4))
                p.addLine(to: CGPoint(x: 18, y: 4))
            }
            .stroke(colore, style: StrokeStyle(lineWidth: 2, dash: tratteggio ? [4, 3] : []))
            .frame(width: 18, height: 8)
            Text(testo).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
        }
    }

    private func testa(_ t: String, _ larghezza: CGFloat?) -> some View {
        Text(t)
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
            .padding(Misure.Analisi.testaMargine)
            .frame(maxWidth: larghezza ?? .infinity, alignment: larghezza == nil ? .leading : .trailing)
            .frame(width: larghezza)
    }

    private func cellaNumero(_ t: String, _ larghezza: CGFloat, colore: Color = Colori.Analisi.tabellaTesto) -> some View {
        Text(t)
            .font(Tipo.numeroTabella)
            .foregroundColor(colore)
            .padding(Misure.Analisi.cellaMargine)
            .frame(width: larghezza, alignment: .trailing)
    }
}

/// Riga etichetta/valore nei pannelli dell'analisi.
struct RigaDato: View {
    let etichetta: String
    let valore: String
    var larghezza: CGFloat = 150
    /// Colore del valore (per esempio rosso se negativo); nil = quello solito.
    var colore: Color? = nil
    /// Pillola accanto al valore (per esempio «decide il minimo»).
    var pillola: Pillola? = nil

    init(_ etichetta: String, _ valore: String, larghezza: CGFloat = 150, colore: Color? = nil, pillola: Pillola? = nil) {
        self.etichetta = etichetta
        self.valore = valore
        self.larghezza = larghezza
        self.colore = colore
        self.pillola = pillola
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(etichetta)
                .font(Tipo.campoEtichetta)
                .foregroundColor(Colori.Analisi.kpiNota)
                .frame(width: larghezza, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: Tema.Misura.MotoriPosizioni.spazioPillola) {
                Text(valore.isEmpty ? "—" : valore)
                    .font(Tipo.tabellaCella)
                    .foregroundColor(valore.isEmpty ? Colori.Analisi.kpiNota : (colore ?? Colori.Analisi.tabellaTesto))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let pillola { pillola }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
        .bordoBasso(Colori.Analisi.tabellaRiga)
    }
}

/// Scala di rischio SRI da 1 a 7, come nel KID.
struct ScalaRischio: View {
    let valore: Int?

    var body: some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.Dossier.casellaRischio)
        // «non indicato» sotto la scala: nelle colonne strette non va a capo lettera per lettera
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                ForEach(1...7, id: \.self) { i in
                    Text("\(i)")
                        .font(Tipo.chip)
                        .foregroundColor(i == valore ? Tema.Colore.Componenti.testoSuColore : Colori.Analisi.chipTesto)
                        .frame(width: 19, height: 18)
                        .background { forma.fill(i == valore ? Colori.Analisi.navAlto : Colori.Analisi.chip) }
                        .overlay {
                            forma.strokeBorder(i == valore ? Colori.Analisi.navBordoBasso : Colori.Analisi.chipBordo, lineWidth: Tema.Misura.filo)
                                .allowsHitTesting(false)
                        }
                }
            }
            if valore == nil {
                Text("non indicato").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                    .lineLimit(1).fixedSize()
            }
        }
    }
}
