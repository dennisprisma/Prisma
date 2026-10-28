import SwiftUI

/// Modulo delle condizioni di un contratto d'investimento (scheda prodotto): le parti con i loro costi
/// e lo storico, costo d'ingresso, blocco e penali di riscatto, bollo e imposte, scenari del KID,
/// garanzie e fonti. Sono i dati che il motore delle valutazioni usa per prospetto e report.
struct ModuloCondizioni: View {
    @Environment(\.dismiss) var chiudi
    @State var bozza: CondizioniContratto
    let prodotto: String
    let salva: (CondizioniContratto?) -> Void

    private static let numero = FloatingPointFormatStyle<Double>.number.locale(Formati.italiano)

    private var sommaQuote: Double { bozza.componenti.reduce(0) { $0 + $1.quota } }

    var body: some View {
        CorniceModulo(titolo: "Condizioni del contratto · \(prodotto)") {
            VStack(alignment: .leading, spacing: 18) {
                Text("Copia i dati dal KID, dal DIP aggiuntivo IBIP e dalle Condizioni di assicurazione: Prisma li usa così come sono scritti.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
                sezione("Il contratto")
                CampoModulo(etichetta: "Versione") {
                    TextField("Per esempio: versione Base, senza copertura infortuni", text: $bozza.versione).textFieldStyle(.roundedBorder)
                }
                sezione("Le parti del contratto")
                ForEach($bozza.componenti) { $c in parte($c) }
                HStack(spacing: 8) {
                    Button("＋ Gestione separata") { aggiungi(.gestioneSeparata) }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    Button("＋ Fondo Interno") { aggiungi(.fondoInterno) }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    Spacer()
                    if !bozza.componenti.isEmpty && abs(sommaQuote - 100) > 0.01 {
                        Text("Le quote sommano \(Formati.percentuale(sommaQuote)): devono fare 100%")
                            .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.erroreTesto)
                    }
                }
                sezione("Costi e riscatto")
                CampoModulo(etichetta: "Costo d'ingresso") {
                    HStack(spacing: 6) {
                        numero($bozza.costoIngresso, "% del premio, massimo")
                        TextField("—", value: $bozza.costoIngressoMassimo, format: Self.numero).textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing).frame(width: 70)
                        Text("€").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                    }
                }
                CampoModulo(etichetta: "Riscatto bloccato") {
                    Stepper(value: $bozza.mesiBloccoRiscatto, in: 0...60, step: 12) {
                        Text(bozza.mesiBloccoRiscatto == 0 ? "mai" : "per i primi \(bozza.mesiBloccoRiscatto) mesi").font(Tipo.campoValore)
                    }
                }
                CampoModulo(etichetta: "Penali di riscatto") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(bozza.penali.indices, id: \.self) { i in
                            HStack(spacing: 6) {
                                Text("\(i + 2)° anno").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario).frame(width: 52, alignment: .leading)
                                numero(Binding(get: { bozza.penali[i] }, set: { bozza.penali[i] = $0 }), "% del valore")
                                if i == bozza.penali.count - 1 {
                                    Button("Togli") { bozza.penali.removeLast() }.buttonStyle(StileSemplice())
                                        .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.erroreTesto)
                                }
                            }
                        }
                        Button("＋ Anno con penale") { bozza.penali.append(bozza.penali.last.map { max(0, $0 - 1) } ?? 2) }
                            .buttonStyle(StileSemplice()).font(Tipo.kpiNota).foregroundColor(Colori.Colonna.collegamento)
                        Text(bozza.penali.isEmpty ? "Nessuna penale." : "Dal \(bozza.annoSenzaPenali)° anno nessuna penale.")
                            .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    }
                }
                CampoModulo(etichetta: "Imposta di bollo") { numero($bozza.bollo, "% l'anno sulle parti indicate") }
                CampoModulo(etichetta: "Imposta sostitutiva") {
                    HStack(spacing: 6) {
                        numero($bozza.aliquota, "%, titoli di Stato")
                        numero($bozza.aliquotaTitoliStato, "%")
                    }
                }
                sezione("Il KID")
                CampoModulo(etichetta: "Data dei documenti") {
                    CampoDataFacoltativa(data: $bozza.dataDocumenti, predefinita: Date())
                }
                CampoModulo(etichetta: "Periodo raccomandato") {
                    HStack(spacing: 6) {
                        TextField("—", value: $bozza.periodoRaccomandato, format: .number).textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing).frame(width: 50)
                        Text("anni").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                    }
                }
                CampoModulo(etichetta: "Scenari del KID") {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text("Rendimento medio annuo, uscita dopo 1 anno e dopo").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                            Stepper(value: $bozza.anniKID, in: 2...30) { Text("\(bozza.anniKID) anni").font(Tipo.kpiNota) }
                        }
                        ForEach(bozza.scenariKID.indices, id: \.self) { i in
                            HStack(spacing: 6) {
                                Text(bozza.scenariKID[i].nome).font(Tipo.campoEtichetta).frame(width: 84, alignment: .leading)
                                opzionale(Binding(get: { bozza.scenariKID[i].unAnno }, set: { bozza.scenariKID[i].unAnno = $0 }), "% · 1 anno")
                                opzionale(Binding(get: { bozza.scenariKID[i].periodo }, set: { bozza.scenariKID[i].periodo = $0 }), "% · \(bozza.anniKID) anni")
                            }
                        }
                        TextField("Esempio del KID (per esempio: € 10.000 con costo di ingresso dell'1%)", text: $bozza.esempioKID)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                sezione("Garanzie e flessibilità")
                CampoModulo(etichetta: "Cosa è garantito") { righe($bozza.garantito) }
                CampoModulo(etichetta: "Cosa non è garantito") { righe($bozza.nonGarantito) }
                CampoModulo(etichetta: "Riscatto parziale") { CampoTestoLungo(testo: $bozza.riscattoParziale) }
                CampoModulo(etichetta: "Recesso") { CampoTestoLungo(testo: $bozza.recesso) }
                CampoModulo(etichetta: "Fonti") { CampoTestoLungo(testo: $bozza.fonti) }
            }
        } piede: {
            Button("Togli le condizioni") {
                salva(nil)
                chiudi()
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button("Salva") {
                salva(bozza)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(bozza.componenti.isEmpty || abs(sommaQuote - 100) > 0.01)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Analisi.modulo.width + 80, height: Misure.Analisi.modulo.height + 60)
        .onAppear {
            if bozza.scenariKID.isEmpty {
                bozza.scenariKID = ["Stress", "Sfavorevole", "Moderato", "Favorevole"].map { ScenarioKID(nome: $0) }
            }
        }
    }

    // MARK: - Parti

    private func parte(_ c: Binding<ComponenteContratto>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(c.wrappedValue.tipo.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                TextField("Nome (per esempio Fondo Euro San Giorgio)", text: c.nome).textFieldStyle(.roundedBorder)
                numero(c.quota, "%")
                Button("Togli") { bozza.componenti.removeAll { $0.id == c.wrappedValue.id } }
                    .buttonStyle(StileSemplice()).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.erroreTesto)
            }
            if c.wrappedValue.tipo == .gestioneSeparata {
                HStack(spacing: 14) {
                    etichetta("Trattenuto"); numero(c.trattenuto, "% l'anno")
                    etichetta("Titoli di Stato"); numero(c.titoliStato, "% (imposta al 12,5%)")
                }
                garanziaGestione(c)
            } else {
                HStack(spacing: 14) {
                    etichetta("Commissione"); numero(c.commissione, "% l'anno")
                    etichetta("Fondi sottostanti"); numero(c.costiSottostanti, "% (stima)")
                    Toggle("Bollo", isOn: c.bollo).font(Tipo.campoEtichetta)
                }
            }
            TextField("Che cosa fa, in una frase per il cliente", text: c.descrizione, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(2...4)
            TextField("Caratteristiche per il prospetto (composizione, volatilità…)", text: c.caratteristiche, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...3)
            VStack(alignment: .leading, spacing: 4) {
                Text(c.wrappedValue.tipo == .gestioneSeparata ? "Rendimenti lordi annui" : "Valori della quota")
                    .font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                ForEach(c.wrappedValue.storico.indices, id: \.self) { i in
                    HStack(spacing: 6) {
                        TextField(c.wrappedValue.tipo == .gestioneSeparata ? "Anno" : "Data", text: c.storico[i].etichetta)
                            .textFieldStyle(.roundedBorder).frame(width: 130)
                        opzionale(c.storico[i].valore, c.wrappedValue.tipo == .gestioneSeparata ? "%" : "€")
                        TextField("Nota", text: c.storico[i].nota).textFieldStyle(.roundedBorder)
                        if i == c.wrappedValue.storico.count - 1 {
                            Button("Togli") { c.wrappedValue.storico.removeLast() }.buttonStyle(StileSemplice())
                                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.erroreTesto)
                        }
                    }
                }
                Button("＋ Dato storico") { c.wrappedValue.storico.append(PuntoStorico(etichetta: "", valore: nil)) }
                    .buttonStyle(StileSemplice()).font(Tipo.kpiNota).foregroundColor(Colori.Colonna.collegamento)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).fill(Colori.Documento.prisma.parte(c.wrappedValue.tipo).opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).strokeBorder(Colori.Analisi.kpiBordo, lineWidth: Tema.Misura.filo))
    }

    /// Gestione separata: minimo garantito, consolidamento e retrocessione (facoltativi, vuoto = non indicato).
    /// Senza consolidamento annuo indicato, la valutazione non mette il pavimento del minimo.
    private func garanziaGestione(_ c: Binding<ComponenteContratto>) -> some View {
        let m = Tema.Misura.Inserimento.self
        let indicati = DatiPerAnalisi.conta([c.wrappedValue.minimoGarantito != nil, c.wrappedValue.consolidamento != nil,
                                            c.wrappedValue.retrocessione != nil])
        return SezioneRipiegabile("Garanzia e retrocessione", nota: DatiPerAnalisi.nota(indicati)) {
            Text("Dalle Condizioni di assicurazione. Il minimo fa da pavimento solo se il consolidamento è annuo; la retrocessione sostituisce il trattenuto.")
                .font(Tema.Testo.Inserimento.nota).foregroundColor(Tema.Colore.Inserimento.nota)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: m.spazioRiga) {
                etichetta("Minimo garantito")
                opzionale(c.minimoGarantito, "% l'anno")
                etichetta("Retrocessione")
                opzionale(c.retrocessione, "% del lordo")
            }
            HStack(spacing: m.spazioRiga) {
                etichetta("Consolidamento")
                MenuTendina(selezione: c.consolidamento,
                            opzioni: [(Bool?.none, "Non indicato · nessun pavimento"),
                                      (Optional(true), "Annuo: l'accreditato non si perde"),
                                      (Optional(false), "Solo a scadenza o al decesso")],
                            larghezza: m.tendinaConsolidamento)
            }
        }
    }

    private func aggiungi(_ tipo: ComponenteContratto.Tipo) {
        var c = ComponenteContratto(tipo: tipo, nome: "", quota: max(0, 100 - sommaQuote))
        if tipo == .fondoInterno { c.bollo = true }
        bozza.componenti.append(c)
    }

    // MARK: - Campi

    private func sezione(_ titolo: String) -> some View {
        Text(titolo.uppercased()).font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bordoBasso(Colori.Analisi.tabellaRiga)
    }

    private func etichetta(_ testo: String) -> some View {
        Text(testo).font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
    }

    private func numero(_ valore: Binding<Double>, _ unita: String) -> some View {
        HStack(spacing: 4) {
            TextField("", value: valore, format: Self.numero).textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing).frame(width: 64)
            Text(unita).font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario).fixedSize()
        }
    }

    private func opzionale(_ valore: Binding<Double?>, _ unita: String) -> some View {
        HStack(spacing: 4) {
            TextField("—", value: valore, format: Self.numero).textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing).frame(width: 70)
            Text(unita).font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario).fixedSize()
        }
    }

    /// Un elenco di frasi, una per riga.
    private func righe(_ elenco: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            CampoTestoLungo(testo: Binding(get: { elenco.wrappedValue.joined(separator: "\n") },
                                           set: { elenco.wrappedValue = $0.components(separatedBy: "\n") }))
            Text("Una frase per riga.").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
        }
    }
}
