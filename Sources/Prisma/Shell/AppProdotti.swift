import SwiftUI

/// App Prodotti (.os-app-products): l'archivio delle schede prodotto, Alleanza e indipendenti,
/// con condizioni, costi e fonte verificabile. Da una scheda nasce la proposta per il cliente.
struct AppProdotti: View {
    @EnvironmentObject var stato: StatoShell
    @State var modulo: Prodotto?
    @State var moduloCondizioni: Prodotto?
    @State var confermaEliminazione = false
    @State var ricerca = ""

    private var elenco: [Prodotto] {
        let testo = ricerca.trimmingCharacters(in: .whitespaces).lowercased()
        return stato.prodotti
            .filter { stato.filtroCanaleProdotti == nil || $0.canale == stato.filtroCanaleProdotti }
            .filter { stato.filtroAreaProdotti == nil || $0.area == stato.filtroAreaProdotti }
            .filter { testo.isEmpty || $0.nome.lowercased().contains(testo) || $0.emittente.lowercased().contains(testo) }
    }

    private var scelto: Prodotto? {
        elenco.first { $0.id == stato.prodottoSelezionato } ?? elenco.first
    }

    var body: some View {
        CorniceStrumento(
            notaStato: "Schede compilate dal consulente · verifica sempre condizioni e costi sul KID in vigore",
            notaDestra: "\(stato.prodotti.count) schede · \(stato.prodotti.filter(\.daVerificare).count) da verificare"
        ) {
            rail
        } contenuto: {
            // Elenco e scheda nello stesso contenitore dell'elenco laterale, divisi da un filo
            ColonneAffiancate(larghezza: Misure.ColonneStrumento.elenco) {
                colonnaElenco
            } flessibile: {
                if let p = scelto {
                    dettaglio(p)
                } else {
                    VStack(spacing: 8) {
                        Text("Nessuna scheda con questi filtri.").font(Tipo.strumentoTitolo).foregroundColor(Colori.Strumenti.titolo)
                        Button("＋ Nuova scheda") { nuova() }.buttonStyle(StileBlu())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(item: $modulo) { p in
            ModuloProdotto(bozza: p, nuovo: stato.prodotto(p.id) == nil) { stato.salvaProdotto($0) }
        }
        .sheet(item: $moduloCondizioni) { p in
            ModuloCondizioni(bozza: p.condizioni ?? CondizioniContratto(), prodotto: p.nome) { nuove in
                var x = p
                x.condizioni = nuove
                stato.salvaProdotto(x)
            }
        }
        .alert("Eliminare la scheda?", isPresented: $confermaEliminazione) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) { if let p = scelto { stato.eliminaProdotto(p.id) } }
        } message: {
            Text("Le proposte già create restano nelle Posizioni, senza collegamento alla scheda.")
        }
    }

    /// Le condizioni dettagliate del contratto, per le valutazioni di riscatto (prospetto e report).
    private func condizioni(_ p: Prodotto) -> some View {
        PannelloAnalisi(titolo: "Condizioni del contratto",
                        nota: p.condizioni == nil ? "Servono per prospetto e report di una valutazione d'investimento" : "Per le valutazioni di riscatto") {
            EmptyView()
        } contenuto: {
            VStack(alignment: .leading, spacing: 0) {
                if let c = p.condizioni {
                    RigaDato("Parti", c.composizione)
                    RigaDato("Costo d'ingresso", "\(Formati.percentuale(c.costoIngresso))" + (c.costoIngressoMassimo.map { ", massimo \(Formati.euro($0))" } ?? ""))
                    RigaDato("Riscatto", (c.mesiBloccoRiscatto > 0 ? "bloccato per \(c.mesiBloccoRiscatto) mesi; " : "")
                             + (c.penali.isEmpty ? "senza penali" : "penali " + c.penali.map { CifreDoc.penale($0) }.joined(separator: " · ") + ", dal \(c.annoSenzaPenali)° anno nessuna"))
                    RigaDato("Imposte", "bollo \(CifreDoc.percento(c.bollo, decimali: 2)) · sostitutiva \(Formati.percentuale(c.aliquota)), titoli di Stato \(Formati.percentuale(c.aliquotaTitoliStato))")
                    RigaDato("KID", c.scenariKID.isEmpty ? "scenari non inseriti" : "\(c.scenariKID.count) scenari" + (c.dataDocumenti.map { " · \(Formati.dataBreve.string(from: $0))" } ?? ""))
                    RigaDato("Storico", c.componenti.map { "\($0.tipo.nome): \($0.storico.count) dati" }.joined(separator: " · "))
                } else {
                    Text("Parti del contratto (Gestione separata, Fondi Interni), penali di riscatto, bollo, scenari del KID e storico: con questi dati Prisma calcola quanto si incassa anno per anno.")
                        .font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                }
                HStack(spacing: 8) {
                    Button(p.condizioni == nil ? "Aggiungi le condizioni…" : "Modifica le condizioni…") { moduloCondizioni = p }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    if p.condizioni != nil {
                        Button("Valuta per \(stato.clienteAttivo?.nome ?? "il cliente")…") { stato.valutaProdotto(p.id) }
                            .buttonStyle(StileBlu())
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    /// I costi come nel KID: l'incidenza annua (RIY) dichiarata, quella che calcola Prisma su un esempio di
    /// 10.000 € in un'unica soluzione (stima, prima delle imposte) e il periodo raccomandato.
    private func testoKID(_ p: Prodotto) -> String {
        var parti: [String] = []
        if let dichiarato = p.incidenzaCostiKID {
            parti.append("RIY dichiarato \(Formati.percentuale(dichiarato)) l'anno")
        }
        var esempio = p.proposta(per: "")
        esempio.versamentoIniziale = 10_000
        if let incidenza = MotoreCosti.incidenzaKID(esempio, prodotto: p), let calcolato = incidenza.calcolato {
            parti.append("calcolato da Prisma \(Formati.percentuale(calcolato)) a \(incidenza.periodoRaccomandato) anni (stima su 10.000 € in un'unica soluzione)")
        }
        if let anni = p.periodoConsigliato {
            parti.append("periodo raccomandato \(anni) anni")
        }
        return parti.joined(separator: " · ")
    }

    private func nuova() {
        var p = Prodotto(nome: "", canale: stato.filtroCanaleProdotti ?? .alleanza, area: stato.filtroAreaProdotti ?? .investimento)
        p.verificatoIl = Calendar.current.startOfDay(for: Date())
        modulo = p
    }

    // MARK: - Elenco laterale

    @ViewBuilder private var rail: some View {
        DossierRail()
        EtichettaRail(testo: "Canale")
        SegmentiAnalisi(opzioni: [(Canale?.none, "Tutti"), (.alleanza, "Alleanza"), (.indipendente, "Indip.")],
                        selezione: $stato.filtroCanaleProdotti)
        EtichettaRail(testo: "Aree")
        VStack(spacing: 0) {
            VoceNavigazione(titolo: "Tutte le aree", conteggio: stato.prodotti.count, attiva: stato.filtroAreaProdotti == nil) {
                stato.filtroAreaProdotti = nil
            }
            ForEach([AreaPosizione.investimento, .risparmio, .previdenza, .protezione]) { a in
                VoceNavigazione(titolo: a.nome, colore: Colori.Analisi.area(a),
                                conteggio: stato.prodotti.filter { $0.area == a }.count, attiva: stato.filtroAreaProdotti == a) {
                    stato.filtroAreaProdotti = a
                }
            }
        }
        CollegatiRail(app: [.posizioni, .confronti, .simulazioni])
    }

    // MARK: - Elenco

    private var colonnaElenco: some View {
        VStack(spacing: 0) {
            HStack(spacing: Misure.ColonneStrumento.spazioTestata) {
                CampoRicerca(testo: $ricerca, segnaposto: "Cerca prodotto o compagnia")
                Button("＋") { nuova() }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                    .help("Nuova scheda prodotto")
            }
            .testataColonna()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(elenco) { p in
                        Button { stato.prodottoSelezionato = p.id } label: { rigaElenco(p, attiva: p.id == scelto?.id) }
                            .buttonStyle(StileSemplice())
                    }
                }
                .padding(.vertical, Tema.Misura.Strumenti.margineElenco)
            }
        }
    }

    private func rigaElenco(_ p: Prodotto, attiva: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: Tema.Raggio.quadratinoCanale, style: .continuous)
                    .fill(Colori.Analisi.area(p.area)).frame(width: 8, height: 8)
                Text(p.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                Spacer(minLength: 4)
                EtichettaCanale(canale: p.canale, compatta: true)
            }
            HStack(spacing: 6) {
                Text(Self.riassunto(p))
                    .font(Tipo.chip)
                    .foregroundColor(Colori.Analisi.kpiNota)
                if p.daVerificare {
                    Text("DA VERIFICARE").font(Tipo.chip).foregroundColor(Colori.Analisi.attenzioneTesto)
                }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .voceElencoStrumento(attiva: attiva)
    }

    /// La riga sotto il nome nell'elenco: area, costo e SRI; per una multiramo con le due parti
    /// «GS 30% · trattenuto 1,30 — fondi 70% · costi 2,69 · SRI 3».
    static func riassunto(_ p: Prodotto) -> String {
        let q = p.proposta(per: "")
        guard q.multiramoDivisa else {
            return [p.area.nome, p.costoAnnuo.map { "costo \(Formati.percentuale($0))" } ?? "", p.sri.map { "SRI \($0)" } ?? ""]
                .filter { !$0.isEmpty }.joined(separator: " · ")
        }
        let punti: (Double) -> String = { String(CifreDoc.percento($0, decimali: 2).dropLast()) }
        let gestione = "GS \(Formati.percentuale(q.parteGestione * 100)) · trattenuto \(punti(q.trattenutoGestione))"
        let fondi = "fondi \(Formati.percentuale(q.parteFondi * 100)) · costi \(punti(q.costoParteFondi))"
        return "\(gestione) — \(fondi)" + (p.sri.map { " · SRI \($0)" } ?? "")
    }

    // MARK: - Condizioni e fonte

    private func pannelloCondizioni(_ p: Prodotto) -> some View {
        PannelloAnalisi(titolo: "Condizioni") { EmptyView() } contenuto: {
            VStack(spacing: 0) {
                RigaDato("Garanzie", p.garanzie)
                RigaDato("Riscatto e liquidabilità", p.liquidabilita)
                RigaDato("Fiscalità", p.aliquotaFiscale.map { Formati.percentuale($0) + " sul rendimento" } ?? "")
                if p.area.proiettabile {
                    RigaDato("Costi come nel KID", testoKID(p))
                }
                HStack(alignment: .center, spacing: 12) {
                    Text("Rischio (SRI)").font(Tipo.campoEtichetta).foregroundColor(Colori.Analisi.kpiNota)
                        .frame(width: 150, alignment: .leading)
                    ScalaRischio(valore: p.sri)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bordoBasso(Colori.Analisi.tabellaRiga)
                RigaDato("Note", p.note)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pannelloFonte(_ p: Prodotto) -> some View {
        PannelloAnalisi(titolo: "Fonte", nota: "Da dove vengono i dati") { EmptyView() } contenuto: {
            VStack(alignment: .leading, spacing: 8) {
                Text(p.fonte.isEmpty ? "Fonte non indicata" : p.fonte)
                    .font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(p.verificatoIl.map { "Verificata il \(Formati.dataEstesa.string(from: $0))" } ?? "Mai verificata")
                        .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    if p.daVerificare { Pillola(testo: "Da rileggere sul KID", tono: .attenzione) }
                }
                Button("Segna verificata oggi") {
                    var x = p
                    x.verificatoIl = Calendar.current.startOfDay(for: Date())
                    stato.salvaProdotto(x)
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
            }
        }
        .frame(minWidth: Misure.SchedaProdotto.fonteMinima, idealWidth: Misure.SchedaProdotto.fonte,
               maxWidth: Misure.SchedaProdotto.fonte, alignment: .leading)
    }

    // MARK: - Dettaglio

    private func dettaglio(_ p: Prodotto) -> some View {
        let parametri = p.parametriEsempio
        let esito = MotoreProiezione.calcola(parametri)
        let impatto = MotoreProiezione.impattoCosti(parametri)
        // Multiramo a due parti: costo e rendimento pesati sulle due parti (dalla proiezione d'esempio)
        let dueParti = parametri.gestione != nil
        let composizione = MotoreMultiramo.rigaComposizione(p.proposta(per: ""))
        let usi = stato.posizioniDelProdotto(p.id)
        let cliente = stato.clienteAttivo?.nome ?? "il cliente"
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Capsule(style: .continuous).fill(Colori.Analisi.area(p.area)).frame(width: 8, height: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.nome).font(Tipo.profiloNome).tracking(-0.4).foregroundColor(Colori.Analisi.kpiValore)
                        Text([p.area.nome, p.tipologia, p.emittente].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    }
                    Spacer()
                    EtichettaCanale(canale: p.canale)
                }
                if p.area.proiettabile {
                    FasciaKPI {
                        KPI(titolo: "Costo annuo",
                            valore: dueParti ? CifreDoc.percento(parametri.costoAnnuoEquivalente, decimali: 2) : (p.costoAnnuo.map { Formati.percentuale($0) } ?? "—")) {
                            Text(dueParti ? "pesato sulle due parti, senza bollo" : "all'anno sul capitale")
                        }
                        KPI(titolo: "Costo d'ingresso", valore: p.costoIngresso.map { Formati.percentuale($0) } ?? "—") { Text("sui versamenti") }
                        KPI(titolo: "Rendimento ipotizzato",
                            valore: dueParti ? CifreDoc.percento(parametri.rendimentoEquivalente, decimali: 2) : (p.rendimentoAtteso.map { Formati.percentuale($0) } ?? "—")) {
                            Text(composizione.isEmpty ? "dal KID, non garantito" : composizione)
                        }
                        KPI(titolo: "Su 10.000 € in 10 anni", valore: Formati.euro(esito.netto), ultimo: true) {
                            Text("i costi tolgono \(Formati.euro(impatto))")
                        }
                    }
                }
                AvvisoNuovoKID(prodotto: p)
                // Condizioni e fonte affiancate se c'è posto, altrimenti una sotto l'altra (finestra non ingrandita)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Misure.SchedaProdotto.spazioAffiancate) {
                        pannelloCondizioni(p)
                        pannelloFonte(p)
                    }
                    .frame(idealWidth: Misure.SchedaProdotto.affiancate, maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: Misure.SchedaProdotto.spazioImpilate) {
                        pannelloCondizioni(p)
                        pannelloFonte(p)
                    }
                }
                condizioni(p)
                StoricoAggiornamentiProdotto(prodotto: p)
                PannelloAnalisi(titolo: "Dove è usata", nota: usi.isEmpty ? "Nessuna posizione o proposta collegata" : nil) { EmptyView() } contenuto: {
                    VStack(spacing: 0) {
                        ForEach(usi) { u in
                            Button { stato.apriPosizione(u) } label: {
                                HStack {
                                    Text(stato.cliente(u.clienteId)?.nome ?? "Cliente").font(Tipo.tabellaCellaForte)
                                    Text(u.stato == .proposta ? "Proposta · \((u.esito ?? .bozza).nome.lowercased())" : "In essere")
                                        .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                                    Spacer()
                                    Text("Apri ›").font(Tipo.kpiNota).foregroundColor(Colori.Colonna.collegamento)
                                }
                                .foregroundColor(Colori.Analisi.tabellaTesto)
                                .padding(.vertical, 7)
                                .bordoBasso(Colori.Analisi.tabellaRiga)
                            }
                            .buttonStyle(StileSemplice())
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button("Crea una proposta per \(cliente)") { stato.proponi(p) }
                        .buttonStyle(StileBlu())
                    if p.area.proiettabile {
                        Button("Simula") { stato.simula(p) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                    }
                    Button("Modifica") { modulo = p }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                    Spacer()
                    Button { confermaEliminazione = true } label: {
                        Text("Elimina la scheda…").foregroundColor(Colori.Analisi.erroreTesto)
                    }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
                }
                NotaMetodo(testo: "I costi della scheda entrano nelle proposte, nelle simulazioni e nei confronti così come sono scritti: tienili allineati al KID in vigore. L'ISC di una forma pensionistica non è una commissione di gestione: inserisci i costi che il modello applica davvero.")
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 18, trailing: 16))
        }
    }
}

/// Modulo della scheda prodotto.
struct ModuloProdotto: View {
    @Environment(\.dismiss) var chiudi
    @State var bozza: Prodotto
    let nuovo: Bool
    let salva: (Prodotto) -> Void

    private static let numero = FloatingPointFormatStyle<Double>.number.locale(Formati.italiano)

    var body: some View {
        CorniceModulo(titolo: nuovo ? "Nuova scheda prodotto" : "Modifica la scheda") {
            VStack(alignment: .leading, spacing: 14) {
                CampoModulo(etichetta: "Nome del prodotto") { TextField("", text: $bozza.nome).textFieldStyle(.roundedBorder) }
                CampoModulo(etichetta: "Canale") {
                    Picker("", selection: $bozza.canale) {
                        ForEach(Canale.allCases) { Text($0.nomeBreve).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 240)
                }
                CampoModulo(etichetta: "Area") {
                    MenuTendina(selezione: $bozza.area,
                                opzioni: [AreaPosizione.investimento, .risparmio, .previdenza, .protezione].map { ($0, $0.nome) },
                                larghezza: 200)
                }
                CampoModulo(etichetta: "Compagnia o emittente") { TextField("", text: $bozza.emittente).textFieldStyle(.roundedBorder) }
                CampoModulo(etichetta: "Tipologia") { TextField("", text: $bozza.tipologia).textFieldStyle(.roundedBorder) }
                CampoModulo(etichetta: multiramo ? "Rendimento complessivo" : "Rendimento ipotizzato") {
                    percento($bozza.rendimentoAtteso, multiramo ? "% annuo lordo, delle due parti insieme" : "% annuo")
                }
                CampoModulo(etichetta: "Costo d'ingresso") { percento($bozza.costoIngresso, "% dei versamenti") }
                CampoModulo(etichetta: "Costo annuo") {
                    percento($bozza.costoAnnuo, multiramo ? "% all'anno: commissioni, senza il trattenuto" : "% all'anno")
                }
                CampoModulo(etichetta: "Costi nel KID (RIY)") {
                    percento($bozza.incidenzaCostiKID, "% l'anno al periodo raccomandato · Prisma lo confronta con il suo calcolo")
                }
                CampoModulo(etichetta: "Periodo raccomandato") {
                    CampoInteroFacoltativo(valore: $bozza.periodoRaccomandato, unita: notaPeriodo)
                }
                CampoModulo(etichetta: "Fiscalità") { percento($bozza.aliquotaFiscale, "% sul rendimento") }
                CampoModulo(etichetta: "Rischio (SRI)") {
                    HStack(spacing: Tema.Misura.Inserimento.spazioRiga) {
                        MenuTendina(selezione: $bozza.sri,
                                    opzioni: [(Int?.none, "Non indicato")] + (1...7).map { (Optional($0), "\($0)") },
                                    larghezza: Tema.Misura.Multiramo.tendinaSRI)
                        if multiramo {
                            Text("della combinazione, dal KID")
                                .font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                        }
                    }
                }
                if multiramo {
                    composizione
                } else if gestioneSeparata {
                    garanziaGestione
                }
                CampoModulo(etichetta: "Garanzie") { TextField("", text: $bozza.garanzie).textFieldStyle(.roundedBorder) }
                CampoModulo(etichetta: "Riscatto e liquidabilità") { TextField("", text: $bozza.liquidabilita).textFieldStyle(.roundedBorder) }
                CampoModulo(etichetta: "Fonte (KID, versione)") {
                    TextField("Per esempio KID del 1/2026, pagina 2", text: $bozza.fonte).textFieldStyle(.roundedBorder)
                }
                CampoModulo(etichetta: "Verificata il") {
                    CampoDataFacoltativa(data: $bozza.verificatoIl, predefinita: Date())
                }
                CampoModulo(etichetta: "Note") { TextField("", text: $bozza.note).textFieldStyle(.roundedBorder) }
            }
        } piede: {
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button(nuovo ? "Aggiungi" : "Salva") {
                var p = bozza
                p.nome = p.nome.trimmingCharacters(in: .whitespacesAndNewlines)
                salva(p)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(bozza.nome.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Analisi.modulo.width, height: Misure.Analisi.modulo.height)
    }

    // MARK: - Multiramo e gestione separata

    /// La scheda descrive una multiramo: solo Investimento e Risparmio, perché una scheda di previdenza dà
    /// posizioni con il regime della previdenza, mai multiramo.
    private var multiramo: Bool {
        Posizione.multiramo(tipologia: bozza.tipologia) && (bozza.area == .investimento || bozza.area == .risparmio)
    }

    /// La scheda descrive un Ramo I puro (come lo vedrà la proposta).
    private var gestioneSeparata: Bool { !multiramo && bozza.proposta(per: "").gestioneSeparata }

    /// Le due parti della multiramo, con gli stessi campi del modulo della posizione e i limiti della quota.
    private var composizione: some View {
        let m = Tema.Misura.Multiramo.self
        let limiti: ClosedRange<Double>? = {
            guard bozza.quotaGestioneMinima != nil || bozza.quotaGestioneMassima != nil else { return nil }
            let minima = min(max(bozza.quotaGestioneMinima ?? 0, 0), 100)
            let massima = min(max(bozza.quotaGestioneMassima ?? 100, 0), 100)
            return minima <= massima ? minima...massima : nil
        }()
        // L'accreditato della parte in gestione separata, come lo vedrà la proposta (con le condizioni)
        let accreditato = MotoreGestioneSeparata.calcolaParte(bozza.proposta(per: "")).map {
            "\(Formati.percentuale($0.accreditato)) l'anno su un lordo ipotizzato del \(Formati.percentuale($0.lordo)) (stima, prima delle imposte)"
        }
        return VStack(alignment: .leading, spacing: m.spazioRighe) {
            OcchielloSezione(titolo: "Composizione: gestione separata e fondi")
            if let c = bozza.condizioni, !c.componenti.isEmpty {
                Text("Le condizioni del contratto hanno già le parti (\(c.composizioneBreve)): i campi vuoti si prendono da lì.")
                    .font(Tema.Testo.Multiramo.nota)
                    .foregroundColor(Tema.Colore.Multiramo.nota)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SezioneComposizione(
                quotaGestione: $bozza.quotaGestioneSeparata,
                rendimentoGestione: $bozza.rendimentoGestione,
                trattenuto: $bozza.trattenuto,
                retrocessione: $bozza.retrocessione,
                minimoGarantito: $bozza.minimoGarantito,
                consolidamento: $bozza.consolidamento,
                titoliStatoGestione: $bozza.titoliStatoGestione,
                rendimentoFondi: $bozza.rendimentoFondi,
                costoFondi: $bozza.costoFondi,
                sriFondi: $bozza.sriFondi,
                volatilitaFondi: $bozza.volatilitaFondi,
                quotaAzionariaFondi: $bozza.quotaAzionariaFondi,
                titoliStatoFondi: $bozza.titoliStatoFondi,
                ribilanciamento: $bozza.ribilanciamento,
                conGestione: true,
                limiti: limiti,
                accreditato: accreditato)
            CampoModulo(etichetta: "Quota GS ammessa") {
                HStack(spacing: Tema.Misura.Inserimento.spazioRiga) {
                    Text("da").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                    CampoCifraFacoltativa(valore: $bozza.quotaGestioneMinima, unita: "%")
                    Text("a").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                    CampoCifraFacoltativa(valore: $bozza.quotaGestioneMassima, unita: "% · dalle condizioni, solo per avvisare")
                }
            }
        }
    }

    /// Ramo I puro: le condizioni della gestione separata che la proposta eredita.
    private var garanziaGestione: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioCampi) {
            OcchielloSezione(titolo: "Gestione separata")
            CampoModulo(etichetta: "Trattenuto") { percento($bozza.trattenuto, "punti l'anno sul rendimento") }
            CampoModulo(etichetta: "Retrocessione") { percento($bozza.retrocessione, "% del rendimento lordo · al posto del trattenuto") }
            CampoModulo(etichetta: "Minimo garantito") { percento($bozza.minimoGarantito, "% l'anno · 0 = garantito solo il capitale") }
            CampoModulo(etichetta: "Consolidamento") {
                MenuTendina(selezione: $bozza.consolidamento,
                            opzioni: [(Bool?.none, "Non indicato · si considera annuo"),
                                      (Optional(true), "Annuo: l'accreditato non si perde"),
                                      (Optional(false), "Solo a scadenza o al decesso")],
                            larghezza: Tema.Misura.Inserimento.tendinaConsolidamento)
            }
        }
    }

    private func percento(_ valore: Binding<Double?>, _ unita: String) -> some View {
        HStack(spacing: 6) {
            TextField("—", value: valore, format: Self.numero)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text(unita).font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Il periodo raccomandato della scheda prevale su quello delle condizioni del contratto.
    private var notaPeriodo: String {
        if bozza.periodoRaccomandato == nil, let anni = bozza.condizioni?.periodoRaccomandato {
            return "anni, dal KID · se vuoto, \(anni) dalle condizioni del contratto"
        }
        return "anni, dal KID"
    }
}
