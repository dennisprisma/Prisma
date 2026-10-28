import SwiftUI

/// App Analisi 360 (.os-app-planning): il centro della consulenza.
/// Quattro aree (previdenza, protezione, investimenti, risparmio) lette insieme per lo stesso
/// cliente. Le ipotesi partono dalle posizioni in essere e si correggono con il cliente;
/// le coperture e i piani sono sempre quelli registrati in Posizioni, sui due canali.
struct AppAnalisi360: View {
    enum Scheda: Hashable { case sintesi, dettaglio, metodo }

    @EnvironmentObject var stato: StatoShell
    @State var scheda: Scheda = .sintesi
    @State var confermaRicalcolo = false

    private var cliente: String { stato.clienteAttivoId }
    private var posizioni: [Posizione] { stato.posizioniCliente(cliente) }

    /// L'analisi del cliente; ogni modifica viene salvata nel dossier.
    private var analisi: Binding<Analisi360> {
        Binding(get: { stato.analisi360(cliente) }, set: { stato.salvaAnalisi(cliente, $0) })
    }

    var body: some View {
        CorniceStrumento(
            notaStato: "Calcoli eseguiti in locale · conteggi semplificati, da verificare con il cliente e sui contratti",
            notaDestra: stato.analisiSalvata(cliente)
                ? "Analisi aggiornata \(analisi.wrappedValue.aggiornataIl.map { Formati.dataOra.string(from: $0) } ?? "")"
                : "Prima stesura dalle posizioni"
        ) {
            rail
        } contenuto: {
            if let area = stato.areaAnalisi {
                vistaArea(area)
            } else {
                panoramica
            }
        }
        .onChange(of: stato.areaAnalisi) { _ in scheda = .sintesi }
        .alert("Ripartire dalle posizioni?", isPresented: $confermaRicalcolo) {
            Button("Annulla", role: .cancel) {}
            Button("Riparti") { stato.ricalcolaAnalisi(cliente) }
        } message: {
            Text("Le ipotesi modificate a mano per questo cliente verranno sostituite dai dati delle posizioni in essere.")
        }
    }

    // MARK: - Elenco laterale

    @ViewBuilder private var rail: some View {
        DossierRail()
        EtichettaRail(testo: "Il percorso")
        VStack(spacing: 0) {
            VoceNavigazione(titolo: "Panoramica", attiva: stato.areaAnalisi == nil) { stato.areaAnalisi = nil }
            ForEach(AreaAnalisi.allCases) { a in
                VoceNavigazione(titolo: a.nome, colore: Colori.Analisi.area(a.areaPosizioni),
                                conteggio: contratti(a).count, attiva: stato.areaAnalisi == a) { stato.areaAnalisi = a }
            }
        }
        EtichettaRail(testo: "Le ipotesi")
        Text(stato.analisiSalvata(cliente)
             ? "Corrette per questo cliente. Le coperture si leggono sempre dalle posizioni."
             : "Ricavate dalle posizioni in essere e dall'anagrafica: rivedile con il cliente.")
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Analisi.kpiNota)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3)
        if stato.analisiSalvata(cliente) {
            Button("Riparti dalle posizioni") { confermaRicalcolo = true }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                .padding(.top, 2)
        }
        CollegatiRail(app: [.posizioni, .simulazioni, .confronti])
    }

    /// Posizioni in essere e proposte aperte dell'area.
    private func contratti(_ a: AreaAnalisi) -> [Posizione] {
        posizioni.filter { $0.area == a.areaPosizioni && ($0.stato == .inEssere || propostaAperta($0)) }
    }

    private func propostaAperta(_ p: Posizione) -> Bool {
        p.stato == .proposta && p.esito != .accettata && p.esito != .rifiutata
    }

    // MARK: - Panoramica

    private var panoramica: some View {
        let a = analisi.wrappedValue
        let prev = MotoreAnalisi.previdenza(a.previdenza)
        let prot = MotoreAnalisi.protezione(a.protezione, posizioni: posizioni)
        let inv = MotoreAnalisi.investimenti(a.investimenti)
        let ris = MotoreAnalisi.risparmio(a.risparmio)
        let nome = stato.clienteAttivo?.nome.split(separator: " ").first.map(String.init) ?? "cliente"
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TitoloStrumento(occhiello: "Quattro prospettive. Una persona.", titolo: "Il percorso di \(nome).",
                                testo: "Apri un'area, rivedi le ipotesi e costruisci la traccia dell'incontro.")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    schedaArea(.previdenza, valore: "\(Formati.euro(prev.divarioResiduo))/mese",
                               nota: prev.divario > 0 ? "divario dopo l'integrazione dei piani" : "nessun divario con le ipotesi inserite")
                    schedaArea(.protezione, valore: Formati.euro(prot.divario),
                               nota: prot.divario > 0 ? "capitale caso morte che manca" : "fabbisogno coperto dalle polizze in essere")
                    schedaArea(.investimenti, valore: Formati.euro(inv.esito.netto),
                               nota: "finale netto in \(a.investimenti.anni) anni con le ipotesi inserite")
                    schedaArea(.risparmio, valore: "\(Formati.euro(ris.versamentoTeorico ?? 0))/mese",
                               nota: "versamento teorico per l'obiettivo di \(Formati.euro(a.risparmio.obiettivo))")
                }
                HStack(alignment: .center, spacing: 18) {
                    Text("Le quattro aree leggono ipotesi dedicate allo stesso cliente. Capitale e versamenti possono sovrapporsi: verifica le allocazioni prima di sommare i piani.")
                        .font(Tipo.schedaAreaNota)
                        .foregroundColor(Colori.Strumenti.schedaNota)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Prepara incontro →") {
                        stato.filtroClienteAgenda = cliente
                        stato.apri(.agenda)
                    }
                    .buttonStyle(StileBlu())
                }
            }
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18))
        }
    }

    private func schedaArea(_ area: AreaAnalisi, valore: String, nota: String) -> some View {
        let elenco = contratti(area)
        let inEssere = elenco.filter { $0.stato == .inEssere }
        let proposte = elenco.count - inEssere.count
        let canali = Set(inEssere.map(\.canale))
        let confermata = analisi.wrappedValue.confermate.contains(area)
        let prioritarie = stato.cliente(cliente).map { c in
            MotoreBisogni.priorita(stato.bisogniRilevati(c.id), profilo: c.bisogni).prefix(3).map(\.areaAnalisi)
        } ?? []
        return Button { stato.areaAnalisi = area } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(area.numero).font(Tipo.schedaAreaNumero).foregroundColor(Colori.Strumenti.schedaNumero)
                    if prioritarie.contains(area) {
                        Text("★ PRIORITÀ DEL CLIENTE")
                            .font(Tipo.chip)
                            .foregroundColor(Colori.Bisogni.importanza(.alta))
                            .help("Dalla ruota dei bisogni nella scheda del cliente")
                    }
                    Spacer()
                    Text(confermata ? "Dati confermati" : "Ipotesi da verificare")
                        .font(Tipo.chip)
                        .foregroundColor(confermata ? Colori.Strumenti.rischioPresenteTesto : Colori.Strumenti.schedaNumero)
                }
                Text(area.nome).font(Tipo.schedaAreaTitolo).foregroundColor(Colori.Strumenti.schedaTitolo)
                Text(valore).font(Tipo.schedaAreaValore).foregroundColor(Colori.Strumenti.schedaValore)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(nota).font(Tipo.schedaAreaNota).foregroundColor(Colori.Strumenti.schedaNota).lineLimit(2)
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    Text((inEssere.isEmpty ? "Nessuna in essere" : "\(inEssere.count) in essere")
                         + (proposte > 0 ? " · \(proposte) \(proposte == 1 ? "proposta aperta" : "proposte aperte")" : ""))
                    ForEach(Canale.allCases.filter { canali.contains($0) }) { c in EtichettaCanale(canale: c, compatta: true) }
                    Spacer()
                    Text("↗").font(Tipo.ipotesiTitolo)
                }
                .font(Tipo.chip)
                .foregroundColor(Colori.Strumenti.schedaNota)
                .padding(.top, 6)
                .bordoAlto(Colori.Strumenti.schedaFilo)
            }
            .padding(EdgeInsets(top: 12, leading: 17, bottom: 10, trailing: 17))
            .frame(maxWidth: .infinity, minHeight: Misure.Strumenti.schedaArea, alignment: .topLeading)
            .schedaColorata(Colori.Analisi.area(area.areaPosizioni))
        }
        .buttonStyle(StileSemplice())
    }

    // MARK: - Un'area

    private func vistaArea(_ area: AreaAnalisi) -> some View {
        // Ipotesi e risultati nello stesso contenitore dell'elenco laterale: testate e piedi alla stessa altezza
        ColonneAffiancate(larghezza: Misure.ColonneStrumento.elenco) {
            pannelloIpotesi(area)
        } flessibile: {
            VStack(spacing: 0) {
                SchedeRisultati(opzioni: schede(area), selezione: $scheda) {
                    if area == .investimenti || area == .risparmio {
                        Button("Apri nel simulatore") { simula(area) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                    }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        switch scheda {
                        case .metodo:
                            NotaMetodo(testo: MotoreAnalisi.metodo(area), titolo: "Il metodo · \(area.nome)")
                        case .dettaglio:
                            dettaglio(area)
                        case .sintesi:
                            sintesi(area)
                        }
                    }
                    .padding(EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18))
                }
                HStack {
                    Text(analisi.wrappedValue.confermate.contains(area)
                         ? "Dati confermati con il cliente" : "Ipotesi da verificare con il cliente")
                    Spacer()
                }
                .font(Tipo.chip)
                .foregroundColor(Colori.ColonneStrumento.piedeTesto)
                .piedeColonna()
            }
        }
    }

    private func schede(_ area: AreaAnalisi) -> [(Scheda, String)] {
        switch area {
        case .protezione: return [(.sintesi, "Sintesi"), (.dettaglio, "Coperture"), (.metodo, "Metodo")]
        case .investimenti: return [(.sintesi, "Sintesi"), (.dettaglio, "Scenari"), (.metodo, "Metodo")]
        case .previdenza, .risparmio: return [(.sintesi, "Sintesi"), (.dettaglio, "Piani"), (.metodo, "Metodo")]
        }
    }

    private func simula(_ area: AreaAnalisi) {
        var s = Simulazione(clienteId: cliente, titolo: area == .investimenti ? "Ipotesi di investimento" : "Piano di risparmio")
        if area == .investimenti {
            let i = analisi.wrappedValue.investimenti
            s.capitale = i.capitale; s.versamentoMensile = i.versamentoMensile; s.anni = i.anni; s.rendimento = i.rendimento
            s.costoIngresso = i.costoIngresso; s.costoAnnuo = i.costoAnnuo; s.aliquota = i.aliquota; s.inflazione = i.inflazione
        } else {
            let r = analisi.wrappedValue.risparmio
            s.capitale = r.capitale; s.versamentoMensile = r.versamentoMensile; s.anni = r.anni; s.rendimento = r.rendimento
            s.costoIngresso = r.costoIngresso; s.costoAnnuo = r.costoAnnuo; s.aliquota = r.aliquota; s.inflazione = r.inflazione
        }
        stato.bozzaSimulazione = s
        stato.schedaSimulazioni = .simulatore
        stato.apri(.simulazioni)
    }

    // MARK: - Ipotesi

    private func pannelloIpotesi(_ area: AreaAnalisi) -> some View {
        let a = analisi
        return VStack(spacing: 0) {
            HStack {
                Text("Dati e ipotesi").font(Tipo.ipotesiTitolo)
                Spacer()
                Text(stato.analisiSalvata(cliente) ? "Salvate nel dossier" : "Dalle posizioni").font(Tipo.chip)
            }
            .foregroundColor(Colori.ColonneStrumento.testata)
            .testataColonna()
            ScrollView {
                VStack(spacing: 0) {
                    switch area {
                    case .previdenza:
                        CampoIpotesiIntero(etichetta: "Età attuale", valore: a.previdenza.eta, intervallo: 18...85)
                        CampoIpotesiIntero(etichetta: "Età di pensione", valore: a.previdenza.etaPensione, intervallo: 50...75)
                        CampoIpotesi(etichetta: "Reddito desiderato", valore: a.previdenza.redditoDesiderato, unita: "€/mese",
                                     nota: "netto, in euro di oggi")
                        CampoIpotesi(etichetta: "Pensione pubblica", valore: a.previdenza.pensionePubblica, unita: "€/mese",
                                     nota: "netta: dall'estratto INPS o dalla stima contributiva")
                        CampoIpotesi(etichetta: "Montante dei piani", valore: a.previdenza.capitale, nota: "valore attuale")
                        CampoIpotesi(etichetta: "Versamento", valore: a.previdenza.versamentoMensile, unita: "€/mese")
                        CampoIpotesi(etichetta: "Rendimento netto reale", valore: a.previdenza.rendimentoReale, unita: "%",
                                     nota: "già al netto di costi e inflazione", intervallo: -20...20)
                        CampoIpotesiIntero(etichetta: "Anni di integrazione", valore: a.previdenza.anniIntegrazione, intervallo: 1...50)
                    case .protezione:
                        CampoIpotesi(etichetta: "Fabbisogno della famiglia", valore: a.protezione.fabbisognoMensile, unita: "€/mese")
                        CampoIpotesiIntero(etichetta: "Anni di sostegno", valore: a.protezione.anniSostegno, intervallo: 0...50)
                        CampoIpotesi(etichetta: "Debiti da estinguere", valore: a.protezione.debiti, nota: "dalle posizioni: mutui e prestiti")
                        CampoIpotesi(etichetta: "Spese immediate", valore: a.protezione.speseImmediate)
                        CampoIpotesi(etichetta: "Capitale ai superstiti", valore: a.protezione.capitaleDisponibile,
                                     nota: "liquidità già destinata")
                        CampoIpotesi(etichetta: "Entrate sostitutive", valore: a.protezione.entrateSostitutive, unita: "€/mese",
                                     nota: "in caso di invalidità o malattia")
                        CampoIpotesiIntero(etichetta: "Mesi di riserva", valore: a.protezione.mesiRiserva, unita: "mesi", intervallo: 1...120)
                        CampoIpotesi(etichetta: "Riserva disponibile", valore: a.protezione.riserva)
                    case .investimenti:
                        CampoIpotesi(etichetta: "Capitale", valore: a.investimenti.capitale, nota: "dalle posizioni di investimento")
                        CampoIpotesi(etichetta: "Versamento", valore: a.investimenti.versamentoMensile, unita: "€/mese")
                        CampoIpotesiIntero(etichetta: "Orizzonte", valore: a.investimenti.anni, intervallo: 1...50)
                        CampoIpotesi(etichetta: "Rendimento lordo", valore: a.investimenti.rendimento, unita: "%", intervallo: -30...30)
                        CampoIpotesi(etichetta: "Costo d'ingresso", valore: a.investimenti.costoIngresso, unita: "%", intervallo: 0...50)
                        CampoIpotesi(etichetta: "Costo annuo", valore: a.investimenti.costoAnnuo, unita: "%", intervallo: 0...20)
                        CampoIpotesi(etichetta: "Imposte sul guadagno", valore: a.investimenti.aliquota, unita: "%", intervallo: 0...60)
                        CampoIpotesi(etichetta: "Inflazione", valore: a.investimenti.inflazione, unita: "%", intervallo: 0...20)
                        CampoIpotesi(etichetta: "Calo da mettere alla prova", valore: a.investimenti.calo, unita: "%", intervallo: 0...100)
                    case .risparmio:
                        CampoIpotesi(etichetta: "Obiettivo", valore: a.risparmio.obiettivo, nota: "in euro di oggi")
                        CampoIpotesi(etichetta: "Capitale già da parte", valore: a.risparmio.capitale)
                        CampoIpotesi(etichetta: "Versamento", valore: a.risparmio.versamentoMensile, unita: "€/mese")
                        CampoIpotesiIntero(etichetta: "Anni", valore: a.risparmio.anni, intervallo: 1...50)
                        CampoIpotesi(etichetta: "Rendimento lordo", valore: a.risparmio.rendimento, unita: "%", intervallo: -30...30)
                        CampoIpotesi(etichetta: "Costo d'ingresso", valore: a.risparmio.costoIngresso, unita: "%", intervallo: 0...50)
                        CampoIpotesi(etichetta: "Costo annuo", valore: a.risparmio.costoAnnuo, unita: "%", intervallo: 0...20)
                        CampoIpotesi(etichetta: "Imposte sul guadagno", valore: a.risparmio.aliquota, unita: "%", intervallo: 0...60)
                        CampoIpotesi(etichetta: "Inflazione", valore: a.risparmio.inflazione, unita: "%", intervallo: 0...20)
                    }
                }
                .padding(.horizontal, 12)
            }
            HStack {
                Toggle("Confermati con il cliente", isOn: Binding(
                    get: { a.wrappedValue.confermate.contains(area) },
                    set: { attiva in
                        var x = a.wrappedValue
                        x.confermate.removeAll { $0 == area }
                        if attiva { x.confermate.append(area) }
                        a.wrappedValue = x
                    }
                ))
                .toggleStyle(.checkbox)
                .font(Tipo.ipotesiNota)
                Spacer()
            }
            .foregroundColor(Colori.ColonneStrumento.testata)
            .piedeColonna()
        }
    }

    // MARK: - Sintesi

    @ViewBuilder private func sintesi(_ area: AreaAnalisi) -> some View {
        let a = analisi.wrappedValue
        switch area {
        case .previdenza: sintesiPrevidenza(a.previdenza)
        case .protezione: sintesiProtezione(a.protezione)
        case .investimenti: sintesiInvestimenti(a.investimenti)
        case .risparmio: sintesiRisparmio(a.risparmio)
        }
    }

    /// Versamenti e capitali delle proposte aperte dell'area (per vedere quanto cambierebbe il quadro).
    private func proposte(_ area: AreaPosizione) -> (capitale: Double, mensile: Double, conteggio: Int) {
        let elenco = posizioni.filter { $0.area == area && propostaAperta($0) }
        return (elenco.reduce(0) { $0 + $1.versamentoIniziale }, elenco.reduce(0) { $0 + $1.premioAnnuo } / 12, elenco.count)
    }

    private func sintesiPrevidenza(_ i: IpotesiPrevidenza) -> some View {
        let e = MotoreAnalisi.previdenza(i)
        let pr = proposte(.previdenza)
        var conProposte = i
        conProposte.capitale += pr.capitale
        conProposte.versamentoMensile += pr.mensile
        let ec = MotoreAnalisi.previdenza(conProposte)
        return VStack(alignment: .leading, spacing: 14) {
            TitoloStrumento(occhiello: "Dal lavoro alla pensione", titolo: e.divario > 0 ? "Il divario da colmare." : "Il reddito è coperto.",
                            testo: "Tra \(e.anniAccumulo) \(e.anniAccumulo == 1 ? "anno" : "anni"), a \(i.etaPensione) anni · integrazione per \(i.anniIntegrazione) anni")
            FasciaKPI {
                KPI(titolo: "Divario mensile", valore: Formati.euro(e.divario)) { Text("desiderato − pensione pubblica") }
                KPI(titolo: "Dai piani in essere", valore: "\(Formati.euro(e.integrazione))/mese") { Text("montante \(Formati.euroBreve(e.montante))") }
                KPI(titolo: "Divario residuo", valore: "\(Formati.euro(e.divarioResiduo))/mese") { Text("da colmare") }
                KPI(titolo: "Versamento teorico", valore: e.versamentoTeorico.map { "\(Formati.euro($0))/mese" } ?? "—", ultimo: true) {
                    Text(e.versamentoTeorico == nil ? "nessun anno di accumulo" : "per tutto il divario")
                }
            }
            pensioneStimata(i)
            GraficoProiezione(serie: [.init(id: "montante", punti: e.punti, colore: Colori.Analisi.area(.previdenza), principale: true)])
            VStack(spacing: 0) {
                RigaDato("Capitale obiettivo", Formati.euro(e.capitaleObiettivo), larghezza: 230)
                RigaDato("Montante alla pensione", Formati.euro(e.montante), larghezza: 230)
                RigaDato("Versamento impostato", "\(Formati.euro(i.versamentoMensile))/mese", larghezza: 230)
                if pr.conteggio > 0 {
                    RigaDato("Con le proposte aperte (\(pr.conteggio))", "integrazione \(Formati.euro(ec.integrazione))/mese · divario residuo \(Formati.euro(ec.divarioResiduo))/mese", larghezza: 230)
                }
            }
            PannelloFiscoPrevidenza(deducibilita: DeducibilitaPrevidenza(piani: posizioni),
                                    reddito: stato.cliente(cliente)?.profilo.redditoLordoAnnuo)
            NotaMetodo(testo: "Il divario usa la pensione pubblica inserita nelle ipotesi; la stima contributiva è un aiuto da verificare sull'estratto conto INPS. Contributi del datore e TFR conferito non entrano in questa proiezione semplificata: li considera il prospetto della previdenza.")
        }
    }

    /// La pensione pubblica stimata con il contributivo, accanto a quella inserita nelle ipotesi.
    private func pensioneStimata(_ i: IpotesiPrevidenza) -> some View {
        let c = stato.cliente(cliente)
        let stima = c.flatMap { MotorePensionePubblica.stima(cliente: $0, previdenza: i) }
        let motivo = c.flatMap { MotorePensionePubblica.motivoAssente($0.profilo.lavoro, reddito: $0.profilo.redditoLordoAnnuo) }
        return PannelloPensioneStimata(stima: stima, motivo: motivo, ipotesi: i) { netta in
            var x = analisi.wrappedValue
            x.previdenza.pensionePubblica = netta
            analisi.wrappedValue = x
            stato.mostraAvviso("Pensione pubblica dell'analisi: \(Formati.euro(netta)) al mese, dalla stima contributiva")
        }
    }

    private func sintesiProtezione(_ i: IpotesiProtezione) -> some View {
        let e = MotoreAnalisi.protezione(i, posizioni: posizioni)
        let rischi = RischioCoperto.allCases.filter { $0 != .altro }
        return VStack(alignment: .leading, spacing: 14) {
            TitoloStrumento(occhiello: "Se succede qualcosa",
                            titolo: e.divario <= 0 ? "La famiglia è protetta."
                                : e.capitaleVita <= 0 ? "La famiglia non è protetta."
                                : "Protetta al \(Int((e.capitaleVita / max(e.fabbisogno, 1) * 100).rounded(.down)))%.",
                            testo: "Due scenari distinti, da non sommare: la perdita del reddito per sempre e la sua interruzione per un periodo.")
            FasciaKPI {
                KPI(titolo: "Fabbisogno caso morte", valore: Formati.euro(e.fabbisogno)) { Text("debiti, spese e sostegno") }
                KPI(titolo: "Coperture in essere", valore: Formati.euro(e.capitaleVita)) { Text("capitali caso morte") }
                KPI(titolo: "Divario", valore: Formati.euro(e.divario)) {
                    if e.divarioConProposte < e.divario {
                        Chip(testo: "con le proposte \(Formati.euroBreve(e.divarioConProposte))")
                    } else {
                        Text("capitale che manca")
                    }
                }
                KPI(titolo: "Riserva mancante", valore: Formati.euro(e.riservaMancante), ultimo: true) {
                    Text("\(Formati.euro(e.ammanco))/mese × \(i.mesiRiserva) mesi")
                }
            }
            PannelloAnalisi(titolo: "I rischi del nucleo", nota: "Verde: coperto da almeno una polizza in essere") { EmptyView() } contenuto: {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(rischi) { r in
                        let coperto = e.rischiCoperti.contains(r)
                        Text((coperto ? "✓ " : "") + r.nome)
                            .font(Tipo.chip)
                            .foregroundColor(coperto ? Colori.Strumenti.rischioPresenteTesto : Colori.Strumenti.rischioAssenteTesto)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                FormaVetro.arrotondata(Tema.Raggio.Strumenti.casellaRischio)
                                    .fill(coperto ? Colori.Strumenti.rischioPresenteFondo : Colori.Strumenti.rischioAssenteFondo)
                            }
                            .overlay {
                                FormaVetro.arrotondata(Tema.Raggio.Strumenti.casellaRischio)
                                    .strokeBorder(coperto ? Colori.Strumenti.rischioPresenteBordo : Colori.Strumenti.rischioAssenteBordo,
                                                  lineWidth: Tema.Misura.filo)
                            }
                    }
                }
            }
            if let c = stato.cliente(cliente) {
                PannelloProtezionePersone(persone: MotoreProtezioneFamiglia.perPersona(posizioni, cliente: c, analisi: i)) { p in
                    stato.apriPosizione(p)
                }
            }
            VStack(spacing: 0) {
                RigaDato("Debiti + spese immediate", Formati.euro(i.debiti + i.speseImmediate), larghezza: 230)
                RigaDato("Sostegno alla famiglia", "\(Formati.euro(i.fabbisognoMensile))/mese × \(i.anniSostegno) anni", larghezza: 230)
                RigaDato("Meno il capitale ai superstiti", "−\(Formati.euro(i.capitaleDisponibile))", larghezza: 230)
                RigaDato("Premi annui delle coperture", Formati.euro(e.premiAnnui), larghezza: 230)
                RigaDato("Riserva necessaria", "\(Formati.euro(e.riservaNecessaria)) (ne hai \(Formati.euro(i.riserva)))", larghezza: 230)
            }
            if let c = stato.cliente(cliente) {
                PannelloFiscoCoperture(fisco: CacheMotoriAnalisi.fisco(cliente: c, posizioni: posizioni))
            }
            NotaMetodo(testo: "Le coperture registrate non sono una verifica di operatività: esclusioni, carenze, franchigie, massimali e beneficiari vanno letti nelle condizioni di polizza.")
        }
    }

    private func sintesiInvestimenti(_ i: IpotesiInvestimento) -> some View {
        let e = MotoreAnalisi.investimenti(i)
        return VStack(alignment: .leading, spacing: 14) {
            TitoloStrumento(occhiello: "Il capitale al lavoro", titolo: "Dove può arrivare.",
                            testo: "\(Formati.euro(i.capitale)) iniziali e \(Formati.euro(i.versamentoMensile)) al mese per \(i.anni) anni · rendimento netto dei costi \(Formati.percentuale((e.rendimentoNetto * 100).rounded() / 100))")
            FasciaKPI {
                KPI(titolo: "Versato", valore: Formati.euro(e.esito.versato)) { Text("capitale e versamenti") }
                KPI(titolo: "Finale netto", valore: Formati.euro(e.esito.netto)) { Chip(testo: "imposte \(Formati.euroBreve(e.esito.imposte))") }
                KPI(titolo: "In euro di oggi", valore: Formati.euro(e.esito.reale)) { Text("inflazione \(Formati.percentuale(i.inflazione))") }
                KPI(titolo: "Quanto tolgono i costi", valore: Formati.euro(e.impattoCosti), ultimo: true) { Text("rendimenti non maturati inclusi") }
            }
            GraficoProiezione(serie: [
                .init(id: "prudente", punti: e.scenari[0].esito.punti, colore: Colori.Analisi.prudente),
                .init(id: "favorevole", punti: e.scenari[2].esito.punti, colore: Colori.Analisi.favorevole),
                .init(id: "atteso", punti: e.esito.punti, colore: Colori.Analisi.linea, principale: true),
            ])
            HStack(spacing: 16) {
                LegendaLinea(colore: Colori.Analisi.linea, testo: "Atteso \(Formati.percentuale(i.rendimento))")
                LegendaLinea(colore: Colori.Analisi.prudente, testo: "Prudente")
                LegendaLinea(colore: Colori.Analisi.favorevole, testo: "Favorevole")
                LegendaLinea(colore: Colori.Analisi.lineaTratteggiata, testo: "Versato", tratteggio: true)
            }
            NotaMetodo(testo: "Se domani i mercati scendessero del \(Formati.percentuale(i.calo)), il capitale passerebbe subito da \(Formati.euro(i.capitale)) a \(Formati.euro(e.dopoCalo)) (−\(Formati.euro(e.perditaCalo))). È una prova di tenuta, separata dalla proiezione: serve a capire se il cliente reggerebbe la discesa.",
                       titolo: "Prova di tenuta")
        }
    }

    private func sintesiRisparmio(_ i: IpotesiRisparmio) -> some View {
        let e = MotoreAnalisi.risparmio(i)
        return VStack(alignment: .leading, spacing: 14) {
            TitoloStrumento(occhiello: "Da un desiderio a un piano", titolo: "Un passo, ogni mese.",
                            testo: "Obiettivo di \(Formati.euro(i.obiettivo)) in euro di oggi · \(i.anni) anni")
            FasciaKPI {
                KPI(titolo: "Obiettivo a scadenza", valore: Formati.euro(e.obiettivoNominale)) { Text("con l'inflazione ipotizzata") }
                KPI(titolo: "Piano ipotetico", valore: Formati.euro(e.esito.netto)) {
                    Chip(testo: "\(Formati.percentuale((e.copertura).rounded())) dell'obiettivo")
                }
                KPI(titolo: "Versamento teorico", valore: e.versamentoTeorico.map { "\(Formati.euro($0))/mese" } ?? "—") {
                    Text("costante, in euro nominali")
                }
                KPI(titolo: "Mancante a scadenza", valore: Formati.euro(e.mancante), ultimo: true) { Text("con il piano attuale") }
            }
            GraficoProiezione(serie: [.init(id: "piano", punti: e.esito.punti, colore: Colori.Analisi.area(.risparmio), principale: true)])
            VStack(spacing: 0) {
                RigaDato("Versamento impostato", "\(Formati.euro(i.versamentoMensile))/mese", larghezza: 230)
                RigaDato("Differenza dal versamento teorico", "\(Formati.euro(max(0, (e.versamentoTeorico ?? 0) - i.versamentoMensile)))/mese", larghezza: 230)
                RigaDato("Piani di risparmio in essere", Formati.euro(contratti(.risparmio).filter { $0.stato == .inEssere }.reduce(0) { $0 + $1.valore }), larghezza: 230)
            }
        }
    }

    // MARK: - Dettaglio (coperture, scenari, piani)

    /// Il nome della persona assicurata da una copertura (il cliente o un familiare).
    private func nomeAssicurato(_ p: Posizione) -> String {
        guard let c = stato.cliente(cliente) else { return p.assicurato.isEmpty ? "—" : p.assicurato }
        let id = MotoreProtezioneFamiglia.assicurato(p, cliente: c)
        if id == c.id { return c.nome }
        return c.famiglia.first { $0.id == id }?.nome ?? c.nome
    }

    @ViewBuilder private func dettaglio(_ area: AreaAnalisi) -> some View {
        if area == .investimenti {
            let e = MotoreAnalisi.investimenti(analisi.wrappedValue.investimenti)
            TitoloStrumento(occhiello: "Tre strade", titolo: "Gli scenari", testo: "Il rendimento spostato di due punti in meno e in più.")
            TabellaStrumento {
                CellaTesta(testo: "Scenario")
                CellaTesta(testo: "Rendimento", larghezza: 100, destra: true)
                CellaTesta(testo: "Netto", larghezza: 120, destra: true)
                CellaTesta(testo: "Guadagno netto", larghezza: 120, destra: true)
                CellaTesta(testo: "In euro di oggi", larghezza: 120, destra: true)
            } righe: {
                ForEach(Array(e.scenari.enumerated()), id: \.offset) { i, s in
                    RigaStrumento(indice: i) {
                        CellaTabella(testo: s.nome, forte: true)
                        CellaTabella(testo: Formati.percentuale(s.rendimento), larghezza: 100, destra: true)
                        CellaTabella(testo: Formati.euro(s.esito.netto), larghezza: 120, destra: true)
                        CellaTabella(testo: Formati.euro(s.esito.guadagnoNetto), larghezza: 120, destra: true,
                                     colore: s.esito.guadagnoNetto < 0 ? Colori.Strumenti.negativo : Colori.Analisi.tabellaTesto)
                        CellaTabella(testo: Formati.euro(s.esito.reale), larghezza: 120, destra: true)
                    }
                }
            }
        }
        let elenco = contratti(area)
        TitoloStrumento(occhiello: "Dalle posizioni", titolo: area == .protezione ? "Le coperture del nucleo" : "I contratti dell'area",
                        testo: "In essere e proposte aperte, sui due canali. Un clic apre la posizione.")
        if elenco.isEmpty {
            Text("Nessuna posizione in quest'area. Aggiungila in Posizioni per vederla qui.")
                .font(Tipo.strumentoTesto)
                .foregroundColor(Colori.Analisi.kpiNota)
        } else {
            TabellaStrumento {
                CellaTesta(testo: "Posizione")
                CellaTesta(testo: "Canale", larghezza: 110)
                CellaTesta(testo: "Stato", larghezza: 90)
                CellaTesta(testo: area == .protezione ? "Capitale" : "Valore", larghezza: 110, destra: true)
                CellaTesta(testo: "Premi annui", larghezza: 100, destra: true)
                CellaTesta(testo: "Scadenza", larghezza: 96, destra: true)
            } righe: {
                ForEach(Array(elenco.enumerated()), id: \.element.id) { i, p in
                    Button { stato.apriPosizione(p) } label: {
                        RigaStrumento(indice: i) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                                Text(area == .protezione ? "\(p.rischio?.nome ?? "Rischio non indicato") · assicurato: \(nomeAssicurato(p))" : p.tipologia)
                                    .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                            }
                            .lineLimit(1)
                            .padding(Misure.Analisi.cellaMargine)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            EtichettaCanale(canale: p.canale, compatta: true).frame(width: 110, alignment: .leading)
                            CellaTabella(testo: p.stato == .proposta ? "Proposta" : "In essere", larghezza: 90)
                            CellaTabella(testo: Formati.euro(area == .protezione ? (p.capitaleAssicurato ?? 0) : (p.stato == .proposta ? p.versamentoIniziale : p.valore)),
                                         larghezza: 110, destra: true)
                            CellaTabella(testo: Formati.euro(p.premioAnnuo), larghezza: 100, destra: true)
                            CellaTabella(testo: p.scadenza.map { Formati.dataBreve.string(from: $0) } ?? "—", larghezza: 96, destra: true,
                                         colore: p.scadeEntro(RiepilogoPosizioni.giorniScadenza) ? Colori.Analisi.attenzioneTesto : Colori.Analisi.tabellaTesto)
                        }
                    }
                    .buttonStyle(StileSemplice())
                }
            }
        }
    }
}
