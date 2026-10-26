import SwiftUI

/// Modulo per aggiungere o modificare una posizione (in essere o proposta).
struct ModuloPosizione: View {
    @Environment(\.dismiss) var chiudi
    @EnvironmentObject var stato: StatoShell
    @State var bozza: Posizione
    let nuova: Bool
    let salva: (Posizione) -> Void

    private var valida: Bool { !bozza.nome.trimmingCharacters(in: .whitespaces).isEmpty }
    private static let numero = FloatingPointFormatStyle<Double>.number.locale(Formati.italiano)

    var body: some View {
        CorniceModulo(titolo: titolo) {
            VStack(alignment: .leading, spacing: 20) {
                if !stato.dati.prodotti.isEmpty {
                    sezione("Dalla scheda prodotto") {
                        CampoModulo(etichetta: "Prodotto") {
                            MenuTendina(selezione: Binding(get: { bozza.prodottoId }, set: { scegli($0) }),
                                        opzioni: opzioniSchede, larghezza: 380)
                        }
                        Text("Nome, canale, area, compagnia, costi, rendimento e rischio vengono dalla scheda: restano da scrivere numero, date e importi.")
                            .font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                sezione("La posizione") {
                    CampoModulo(etichetta: "Stato") {
                        Picker("", selection: $bozza.stato) {
                            ForEach(StatoPosizione.allCases) { Text($0.nome).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }
                    if bozza.stato == .proposta {
                        CampoModulo(etichetta: "Esito della proposta") {
                            MenuTendina(selezione: Binding(get: { bozza.esito ?? .bozza }, set: { bozza.esito = $0 }),
                                        opzioni: EsitoProposta.allCases.map { ($0, $0.nome) }, larghezza: 220)
                        }
                    }
                    CampoModulo(etichetta: "Canale") {
                        HStack(spacing: 14) {
                            ForEach(Canale.allCases) { c in
                                Button { bozza.canale = c } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: bozza.canale == c ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(Colori.Analisi.navBasso)
                                        EtichettaCanale(canale: c, compatta: true)
                                    }
                                }
                                .buttonStyle(StileSemplice())
                            }
                        }
                    }
                    CampoModulo(etichetta: "Area") {
                        MenuTendina(selezione: $bozza.area,
                                    opzioni: AreaPosizione.allCases.map { ($0, $0.nome) }, larghezza: 220)
                    }
                    CampoModulo(etichetta: "Nome del prodotto") {
                        TextField("Per esempio Piano di risparmio rivalutabile", text: $bozza.nome).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Tipologia") {
                        TextField("Per esempio Polizza rivalutabile (Ramo I), ETF, PIP", text: $bozza.tipologia).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Compagnia o emittente") {
                        TextField("", text: $bozza.emittente).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Numero di contratto") {
                        TextField("", text: $bozza.numeroContratto).textFieldStyle(.roundedBorder)
                    }
                }
                if bozza.area != .liquidita && bozza.area != .immobili {
                    sezione("Persone e date") {
                        if bozza.area != .debiti {
                            CampoModulo(etichetta: "Contraente") { TextField("", text: $bozza.contraente).textFieldStyle(.roundedBorder) }
                            CampoModulo(etichetta: "Assicurato") { TextField("", text: $bozza.assicurato).textFieldStyle(.roundedBorder) }
                            CampoModulo(etichetta: "Beneficiari") { TextField("", text: $bozza.beneficiari).textFieldStyle(.roundedBorder) }
                        }
                        CampoModulo(etichetta: "Decorrenza") {
                            CampoDataFacoltativa(data: $bozza.decorrenza, predefinita: Date())
                        }
                        CampoModulo(etichetta: "Scadenza") {
                            CampoDataFacoltativa(data: $bozza.scadenza,
                                                 predefinita: Calendar.current.date(byAdding: .year, value: 10, to: Date()) ?? Date())
                        }
                    }
                }
                sezione("Importi") {
                    if bozza.area != .liquidita && bozza.area != .immobili {
                        CampoModulo(etichetta: bozza.area == .protezione ? "Premio unico" : "Versamento iniziale") {
                            campoEuro($bozza.versamentoIniziale)
                        }
                        CampoModulo(etichetta: bozza.area == .debiti ? "Rata" : "Premio periodico") {
                            HStack(spacing: 10) {
                                campoEuro($bozza.premio)
                                MenuTendina(selezione: $bozza.frequenza,
                                            opzioni: Frequenza.allCases.map { ($0, $0.nome) }, larghezza: 220)
                            }
                        }
                    }
                    if bozza.area != .protezione {
                        CampoModulo(etichetta: bozza.area == .debiti ? "Debito residuo" : "Valore attuale") {
                            HStack(spacing: 10) {
                                campoEuroFacoltativo($bozza.controvalore)
                                if bozza.controvalore != nil {
                                    Text("al").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                                    CampoDataFacoltativa(data: $bozza.dataValore, predefinita: Date())
                                }
                            }
                        }
                    }
                    if bozza.area.proiettabile || bozza.area == .protezione {
                        CampoModulo(etichetta: "Totale versato") { campoEuroFacoltativo($bozza.totaleVersato) }
                    }
                    if bozza.area == .protezione {
                        CampoModulo(etichetta: "Capitale assicurato") { campoEuroFacoltativo($bozza.capitaleAssicurato) }
                        CampoModulo(etichetta: "Rischio coperto") {
                            MenuTendina(selezione: $bozza.rischio,
                                        opzioni: [(RischioCoperto?.none, "Non indicato")] + RischioCoperto.allCases.map { (Optional($0), $0.nome) },
                                        larghezza: 240)
                        }
                    }
                }
                if bozza.area.proiettabile {
                    sezione("Ipotesi e costi (dal KID o dal prospetto)") {
                        CampoModulo(etichetta: "Rendimento atteso") { campoPercento($bozza.rendimentoAtteso, "% annuo") }
                        CampoModulo(etichetta: "Costo d'ingresso") { campoPercento($bozza.costoIngresso, "% dei versamenti") }
                        CampoModulo(etichetta: "Costo annuo") { campoPercento($bozza.costoAnnuo, "% all'anno") }
                        CampoModulo(etichetta: "Trattenuto") { campoPercento($bozza.trattenuto, "punti l'anno sul rendimento (gestione separata)") }
                        CampoModulo(etichetta: "Aliquota") { campoPercento($bozza.aliquotaFiscale, "% sul guadagno (proiezioni)") }
                        CampoModulo(etichetta: "Rischio (SRI)") {
                            MenuTendina(selezione: $bozza.sri,
                                        opzioni: [(Int?.none, "Non indicato")] + (1...7).map { (Optional($0), "\($0)") },
                                        larghezza: 140)
                        }
                    }
                }
                if bozza.area.proiettabile || bozza.area == .liquidita {
                    sezione("Fiscalità (per il netto incassabile)") {
                        CampoModulo(etichetta: "Regime") {
                            MenuTendina(selezione: $bozza.regimeFiscale,
                                        opzioni: [(RegimeFiscale?.none, "Automatico · \(bozza.regime.nome)")]
                                            + RegimeFiscale.allCases.map { (Optional($0), $0.nome) },
                                        larghezza: 280)
                        }
                        if bozza.regime == .polizza || bozza.regime == .fondo {
                            CampoModulo(etichetta: "Titoli di Stato") { campoPercento($bozza.quotaTitoliStato, "% dell'investimento, tassata al 12,5%") }
                        }
                        if bozza.multiramo {
                            CampoModulo(etichetta: "Gestione separata") { campoPercento($bozza.quotaGestioneSeparata, "% in Ramo I, senza bollo") }
                        }
                        if bozza.regime != .previdenza && bozza.regime != .esente {
                            CampoModulo(etichetta: "Bollo 0,20%") {
                                MenuTendina(selezione: $bozza.conBollo,
                                            opzioni: [(Bool?.none, "Automatico · \(bozza.soggettaBollo ? "sì" : "no")"),
                                                      (Optional(true), "Sì"), (Optional(false), "No (per esempio Ramo I)")],
                                            larghezza: 220)
                            }
                        }
                        if bozza.regime == .previdenza {
                            CampoModulo(etichetta: "Prima adesione") {
                                CampoDataFacoltativa(data: $bozza.primaAdesione, predefinita: bozza.decorrenza ?? Date())
                            }
                            CampoModulo(etichetta: "Non dedotti") { campoEuroFacoltativo($bozza.contributiNonDedotti) }
                            Text("Gli anni di partecipazione contano dalla prima adesione a una forma complementare, anche se poi trasferita. I contributi non dedotti non si tassano alla prestazione.")
                                .font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                sezione("Altro") {
                    CampoModulo(etichetta: "Garanzie") { TextField("", text: $bozza.garanzie).textFieldStyle(.roundedBorder) }
                    CampoModulo(etichetta: "Note") { TextField("", text: $bozza.note).textFieldStyle(.roundedBorder) }
                }
            }
        } piede: {
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button(nuova ? "Aggiungi" : "Salva") {
                var p = bozza
                p.nome = p.nome.trimmingCharacters(in: .whitespacesAndNewlines)
                if p.stato != .proposta { p.esito = p.esito == .accettata ? .accettata : nil }
                salva(p)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(!valida)
            .opacity(valida ? 1 : 0.5)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Analisi.modulo.width, height: Misure.Analisi.modulo.height)
    }

    /// Le schede prodotto, prima quelle Alleanza, in ordine di nome.
    private var schede: [Prodotto] {
        stato.dati.prodotti.sorted { a, b in
            a.canale == b.canale ? a.nome.localizedCaseInsensitiveCompare(b.nome) == .orderedAscending : a.canale == .alleanza
        }
    }

    /// Le voci della tendina "Dalla scheda prodotto": prima la compilazione a mano.
    private var opzioniSchede: [(String?, String)] {
        let voci: [(String?, String)] = schede.map { s in
            let fonte = s.canale == .alleanza ? "Alleanza" : (s.emittente.isEmpty ? "indipendente" : s.emittente)
            return (Optional(s.id), "\(s.nome) · \(fonte)")
        }
        return [(nil, "Nessuna scheda · compilo a mano")] + voci
    }

    /// Compila la posizione dalla scheda: quello che la scheda sa, il resto resta com'è.
    private func scegli(_ id: String?) {
        bozza.prodottoId = id
        guard let s = stato.dati.prodotti.first(where: { $0.id == id }) else { return }
        bozza.nome = s.nome
        bozza.canale = s.canale
        bozza.area = s.area
        bozza.tipologia = s.tipologia
        bozza.emittente = s.emittente.isEmpty && s.canale == .alleanza ? "Alleanza Assicurazioni" : s.emittente
        bozza.rendimentoAtteso = s.rendimentoAtteso
        bozza.costoIngresso = s.costoIngresso
        bozza.costoAnnuo = s.costoAnnuo
        bozza.aliquotaFiscale = s.aliquotaFiscale ?? bozza.aliquotaFiscale
        bozza.sri = s.sri
        if !s.garanzie.isEmpty { bozza.garanzie = s.garanzie }
        if s.area == .protezione, bozza.rischio == nil { bozza.rischio = ImportaPosizioni.rischio(s.nome + " " + s.tipologia) }
        if s.area != .protezione { bozza.rischio = nil }
    }

    private var titolo: String {
        if nuova { return bozza.stato == .proposta ? "Nuova proposta" : "Nuova posizione" }
        return bozza.stato == .proposta ? "Modifica la proposta" : "Modifica la posizione"
    }

    private func sezione<C: View>(_ titolo: String, @ViewBuilder _ contenuto: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OcchielloSezione(titolo: titolo)
            contenuto()
        }
    }

    private func campoEuro(_ valore: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            TextField("0", value: valore, format: Self.numero)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
            Text("€").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
        }
    }

    private func campoEuroFacoltativo(_ valore: Binding<Double?>) -> some View {
        HStack(spacing: 6) {
            TextField("—", value: valore, format: Self.numero)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
            Text("€").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
        }
    }

    private func campoPercento(_ valore: Binding<Double?>, _ unita: String) -> some View {
        HStack(spacing: 6) {
            TextField("—", value: valore, format: Self.numero)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text(unita).font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
        }
    }
}
