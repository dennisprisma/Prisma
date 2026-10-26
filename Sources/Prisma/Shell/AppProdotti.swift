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
            HStack(spacing: 0) {
                colonnaElenco
                    .frame(width: Misure.Strumenti.ipotesi)
                    .bordoDestro(Colori.Strumenti.ipotesiBordo)
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
            HStack(spacing: 8) {
                CampoRicerca(testo: $ricerca, segnaposto: "Cerca prodotto o compagnia")
                Button("＋") { nuova() }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                    .help("Nuova scheda prodotto")
            }
            .padding(10)
            .background(Gradienti.testaIpotesi)
            .bordoBasso(Colori.Strumenti.ipotesiBordo)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(elenco) { p in
                        Button { stato.prodottoSelezionato = p.id } label: { rigaElenco(p, attiva: p.id == scelto?.id) }
                            .buttonStyle(StileSemplice())
                    }
                }
            }
        }
        .background(Gradienti.railAnalisi)
    }

    private func rigaElenco(_ p: Prodotto, attiva: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Colori.Analisi.area(p.area)).frame(width: 8, height: 8)
                Text(p.nome).font(Tipo.tabellaCellaForte).foregroundColor(attiva ? .white : Colori.Analisi.tabellaTesto).lineLimit(1)
                Spacer(minLength: 4)
                EtichettaCanale(canale: p.canale, compatta: true)
            }
            HStack(spacing: 6) {
                Text([p.area.nome, p.costoAnnuo.map { "costo \(Formati.percentuale($0))" } ?? "", p.sri.map { "SRI \($0)" } ?? ""]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Tipo.chip)
                    .foregroundColor(attiva ? Color.white.opacity(0.85) : Colori.Analisi.kpiNota)
                if p.daVerificare {
                    Text("DA VERIFICARE").font(Tipo.chip).foregroundColor(attiva ? .white : Colori.Analisi.attenzioneTesto)
                }
            }
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(attiva ? AnyShapeStyle(Gradienti.navAnalisi) : AnyShapeStyle(Color.clear))
        .bordoBasso(Colori.Strumenti.ipotesiRiga)
    }

    // MARK: - Dettaglio

    private func dettaglio(_ p: Prodotto) -> some View {
        let parametri = p.parametriEsempio
        let esito = MotoreProiezione.calcola(parametri)
        let impatto = MotoreProiezione.impattoCosti(parametri)
        let usi = stato.posizioniDelProdotto(p.id)
        let cliente = stato.clienteAttivo?.nome ?? "il cliente"
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    RoundedRectangle(cornerRadius: 6).fill(Colori.Analisi.area(p.area)).frame(width: 8, height: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.nome).font(Tipo.profiloNome).tracking(-0.4).foregroundColor(Colori.Analisi.kpiValore)
                        Text([p.area.nome, p.tipologia, p.emittente].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    }
                    .incisione(.white)
                    Spacer()
                    EtichettaCanale(canale: p.canale)
                }
                if p.area.proiettabile {
                    FasciaKPI {
                        KPI(titolo: "Costo annuo", valore: p.costoAnnuo.map { Formati.percentuale($0) } ?? "—") { Text("all'anno sul capitale") }
                        KPI(titolo: "Costo d'ingresso", valore: p.costoIngresso.map { Formati.percentuale($0) } ?? "—") { Text("sui versamenti") }
                        KPI(titolo: "Rendimento ipotizzato", valore: p.rendimentoAtteso.map { Formati.percentuale($0) } ?? "—") { Text("dal KID, non garantito") }
                        KPI(titolo: "Su 10.000 € in 10 anni", valore: Formati.euro(esito.netto), ultimo: true) {
                            Text("i costi tolgono \(Formati.euro(impatto))")
                        }
                    }
                }
                HStack(alignment: .top, spacing: 28) {
                    PannelloAnalisi(titolo: "Condizioni") { EmptyView() } contenuto: {
                        VStack(spacing: 0) {
                            RigaDato("Garanzie", p.garanzie)
                            RigaDato("Riscatto e liquidabilità", p.liquidabilita)
                            RigaDato("Fiscalità", p.aliquotaFiscale.map { Formati.percentuale($0) + " sul rendimento" } ?? "")
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
                condizioni(p)
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
                CampoModulo(etichetta: "Rendimento ipotizzato") { percento($bozza.rendimentoAtteso, "% annuo") }
                CampoModulo(etichetta: "Costo d'ingresso") { percento($bozza.costoIngresso, "% dei versamenti") }
                CampoModulo(etichetta: "Costo annuo") { percento($bozza.costoAnnuo, "% all'anno") }
                CampoModulo(etichetta: "Fiscalità") { percento($bozza.aliquotaFiscale, "% sul rendimento") }
                CampoModulo(etichetta: "Rischio (SRI)") {
                    MenuTendina(selezione: $bozza.sri,
                                opzioni: [(Int?.none, "Non indicato")] + (1...7).map { (Optional($0), "\($0)") },
                                larghezza: 140)
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

    private func percento(_ valore: Binding<Double?>, _ unita: String) -> some View {
        HStack(spacing: 6) {
            TextField("—", value: valore, format: Self.numero)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text(unita).font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
        }
    }
}
