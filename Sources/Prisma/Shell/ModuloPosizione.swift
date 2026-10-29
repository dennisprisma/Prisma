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
                        // Unit linked pura: rendimento, costo e SRI stanno nella colonna dei fondi della composizione
                        if !bozza.unitLinked {
                            CampoModulo(etichetta: bozza.multiramo ? "Rendimento complessivo" : "Rendimento atteso") {
                                campoPercento($bozza.rendimentoAtteso, bozza.multiramo ? "% annuo lordo, delle due parti insieme" : "% annuo")
                            }
                        }
                        CampoModulo(etichetta: "Costo d'ingresso") { campoPercento($bozza.costoIngresso, "% dei versamenti") }
                        if !bozza.unitLinked {
                            // Multiramo: le commissioni del contratto senza il trattenuto, ripiego dei costi dei fondi
                            CampoModulo(etichetta: "Costo annuo") {
                                campoPercento($bozza.costoAnnuo, bozza.multiramo ? "% all'anno: commissioni, senza il trattenuto" : "% all'anno")
                            }
                        }
                        if mostraTrattenuto {
                            CampoModulo(etichetta: "Trattenuto") { campoPercento($bozza.trattenuto, "punti l'anno sul rendimento (gestione separata)") }
                        }
                        CampoModulo(etichetta: "Aliquota") { campoPercento($bozza.aliquotaFiscale, "% sul guadagno (proiezioni)") }
                        if !bozza.unitLinked {
                            CampoModulo(etichetta: "Rischio (SRI)") {
                                HStack(spacing: Tema.Misura.Inserimento.spazioRiga) {
                                    MenuTendina(selezione: $bozza.sri,
                                                opzioni: [(Int?.none, "Non indicato")] + (1...7).map { (Optional($0), "\($0)") },
                                                larghezza: Tema.Misura.Multiramo.tendinaSRI)
                                    if bozza.multiramo {
                                        Text("della combinazione scelta, dal KID")
                                            .font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                                    }
                                }
                            }
                        }
                    }
                }
                if bozza.area.proiettabile && (bozza.multiramo || bozza.unitLinked) {
                    sezione(bozza.multiramo ? "Composizione: gestione separata e fondi" : "Composizione: i fondi (Ramo III)") {
                        composizione
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
                        // Unit linked pura: i titoli di Stato sono nella colonna dei fondi (un campo solo);
                        // multiramo: la quota in gestione separata è nella composizione
                        if (bozza.regime == .polizza || bozza.regime == .fondo) && !bozza.unitLinked {
                            CampoModulo(etichetta: "Titoli di Stato") {
                                campoPercento($bozza.quotaTitoliStato,
                                              bozza.multiramo ? "% del contratto, se non indichi quelli delle parti (12,5%)"
                                                              : "% dell'investimento, tassata al 12,5%")
                            }
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
                if bozza.area != .liquidita && bozza.area != .immobili {
                    SezioneRipiegabile("Dati per l'analisi", nota: DatiPerAnalisi.nota(datiAnalisi)) {
                        contenutoAnalisi
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
                .buttonStyle(StileVetro())
                .keyboardShortcut(.cancelAction)
            Button(nuova ? "Aggiungi" : "Salva") {
                var p = bozza
                p.nome = p.nome.trimmingCharacters(in: .whitespacesAndNewlines)
                if p.stato != .proposta { p.esito = p.esito == .accettata ? .accettata : nil }
                // Movimenti: senza importo non contano; dal più vecchio, come li vogliono i motori
                if let elenco = p.movimenti {
                    let validi = elenco.filter { $0.importo != 0 }.sorted { $0.data < $1.data }
                    p.movimenti = validi.isEmpty ? nil : validi
                }
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
        bozza.incidenzaCostiKID = s.incidenzaCostiKID
        bozza.periodoRaccomandato = s.periodoConsigliato
        if !s.garanzie.isEmpty { bozza.garanzie = s.garanzie }
        if s.area == .protezione, bozza.rischio == nil { bozza.rischio = ImportaPosizioni.rischio(s.nome + " " + s.tipologia) }
        if s.area != .protezione { bozza.rischio = nil }
        // Gestione separata e due parti della multiramo: si sceglie un altro prodotto, quindi prima si tolgono
        // quelli della scheda di prima. La quota di una posizione in essere resta: è un dato dell'estratto
        // conto (il valore di oggi), non della scheda. Poi la scheda riempie ciò che manca (tipologia già scelta).
        bozza.trattenuto = nil
        bozza.retrocessione = nil
        bozza.minimoGarantito = nil
        bozza.consolidamento = nil
        if bozza.stato != .inEssere { bozza.quotaGestioneSeparata = nil }
        bozza.rendimentoGestione = nil
        bozza.rendimentoFondi = nil
        bozza.costoFondi = nil
        bozza.sriFondi = nil
        bozza.volatilitaFondi = nil
        bozza.quotaAzionariaFondi = nil
        bozza.titoliStatoGestione = nil
        bozza.titoliStatoFondi = nil
        bozza.ribilanciamento = nil
        var completata = bozza
        MotoreMultiramo.applica(s, a: &completata)
        bozza = completata
    }

    // MARK: - Composizione: gestione separata e fondi

    /// La composizione della multiramo (le due parti) o, per la unit linked pura, la sola colonna dei fondi
    /// legata ai campi di sempre della posizione.
    @ViewBuilder private var composizione: some View {
        let m = Tema.Misura.Inserimento.self
        if bozza.multiramo {
            VStack(alignment: .leading, spacing: m.spazioCampi) {
                if !bozza.multiramoDivisa {
                    Text("Oggi Prisma calcola questa polizza come un comparto unico: indica i rendimenti della gestione separata e dei fondi per calcoli separati.")
                        .font(Tema.Testo.Multiramo.nota)
                        .foregroundColor(Tema.Colore.Multiramo.avviso)
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
                    limiti: limitiQuota,
                    valoreTotale: valoreComposizione,
                    accreditato: MotoreGestioneSeparata.calcolaParte(bozza).map(testoAccreditato),
                    notaQuota: bozza.stato == .inEssere && bozza.quotaGestioneSeparata == nil
                        ? "Per una polizza in essere indica la quota del valore di oggi, dall'estratto conto." : nil)
            }
        } else {
            SezioneComposizione(
                quotaGestione: .constant(nil),
                rendimentoGestione: .constant(nil),
                trattenuto: .constant(nil),
                retrocessione: .constant(nil),
                minimoGarantito: .constant(nil),
                consolidamento: .constant(nil),
                titoliStatoGestione: .constant(nil),
                rendimentoFondi: $bozza.rendimentoAtteso,
                costoFondi: $bozza.costoAnnuo,
                sriFondi: $bozza.sri,
                volatilitaFondi: $bozza.volatilita,
                quotaAzionariaFondi: $bozza.quotaAzionaria,
                titoliStatoFondi: $bozza.quotaTitoliStato,
                ribilanciamento: .constant(nil),
                conGestione: false)
        }
    }

    /// La quota in gestione separata ammessa dalla scheda collegata (0–100), se la scheda la indica.
    private var limitiQuota: ClosedRange<Double>? {
        guard let s = prodotto, s.quotaGestioneMinima != nil || s.quotaGestioneMassima != nil else { return nil }
        let minima = min(max(s.quotaGestioneMinima ?? 0, 0), 100)
        let massima = min(max(s.quotaGestioneMassima ?? 100, 0), 100)
        return minima <= massima ? minima...massima : nil
    }

    /// Il valore da dividere tra le due parti: quello di oggi in essere, il versamento iniziale per una proposta.
    private var valoreComposizione: Double? {
        if bozza.stato == .inEssere { return bozza.controvalore }
        return bozza.versamentoIniziale > 0 ? bozza.versamentoIniziale : nil
    }

    // MARK: - Dati per l'analisi

    /// La scheda prodotto collegata, per i ripieghi (penali e blocco del riscatto).
    private var prodotto: Prodotto? {
        guard let id = bozza.prodottoId else { return nil }
        return stato.dati.prodotti.first { $0.id == id }
    }

    /// Quanti dati per l'analisi sono indicati (per la nota nella testa della sezione).
    private var datiAnalisi: Int {
        let p = bozza
        let rendimenti = DatiPerAnalisi.conta([
            p.movimenti?.isEmpty == false, p.penali != nil, p.mesiBloccoRiscatto != nil, p.costoUscita != nil,
            p.incidenzaCostiKID != nil, p.periodoRaccomandato != nil, p.minimoGarantito != nil, p.consolidamento != nil,
            p.retrocessione != nil,
        ])
        let rischioEFamiglia = DatiPerAnalisi.conta([
            p.volatilita != nil, p.quotaAzionaria != nil, p.assicuratoId != nil, p.capitaleDecrescente != nil,
            p.contributoDatore != nil, p.tfrConferito != nil, p.tassoDebito != nil, p.quotaDebito != nil,
        ])
        // Multiramo: contano anche i dati delle due parti indicati nella composizione
        let parti = !p.multiramo ? 0 : DatiPerAnalisi.conta([
            p.rendimentoGestione != nil, p.rendimentoFondi != nil, p.costoFondi != nil, p.sriFondi != nil,
            p.volatilitaFondi != nil, p.quotaAzionariaFondi != nil, p.titoliStatoGestione != nil,
            p.titoliStatoFondi != nil, p.ribilanciamento == true,
        ])
        return rendimenti + rischioEFamiglia + parti
    }

    /// Il trattenuto in «Ipotesi e costi»: per il Ramo I e la previdenza (per una multiramo è nella colonna
    /// della gestione separata). Se è già indicato su un'altra posizione resta visibile, perché conta nei calcoli.
    private var mostraTrattenuto: Bool {
        bozza.gestioneSeparata || (!bozza.multiramo && (bozza.regime == .previdenza || bozza.trattenuto != nil))
    }

    /// Riscatto anno per anno: solo polizze e fondi (la previdenza ha regole sue).
    private var conRiscatto: Bool {
        bozza.area.proiettabile && (bozza.regime == .polizza || bozza.regime == .fondo)
    }

    /// La persona assicurata serve alle coperture e alle polizze vita.
    private var conAssicurato: Bool {
        bozza.area == .protezione || (bozza.area.proiettabile && bozza.regime == .polizza)
    }

    @ViewBuilder private var contenutoAnalisi: some View {
        Text("Facoltativi: rendono più precise le analisi di rendimento, riscatto, costi, rischio e protezione. Un campo vuoto vale «non indicato»: Prisma usa le sue stime e lo dichiara.")
            .font(Tema.Testo.Inserimento.nota).foregroundColor(Tema.Colore.Inserimento.nota)
            .fixedSize(horizontal: false, vertical: true)
        if bozza.area.proiettabile && bozza.stato == .inEssere { gruppoMovimenti }
        if conRiscatto { gruppoRiscatto }
        if bozza.area.proiettabile { gruppoKID }
        // Solo il Ramo I puro: per la multiramo i dati della gestione separata sono nella composizione
        if bozza.area.proiettabile && bozza.gestioneSeparata { gruppoGestioneSeparata }
        // Unit linked e multiramo a due parti: il rischio è quello dei fondi, nella composizione. Una multiramo
        // non ancora divisa lo tiene qui: i motori usano ancora quota azionaria e volatilità del contratto.
        if bozza.area.proiettabile && !bozza.unitLinked && !bozza.multiramoDivisa { gruppoRischio }
        if bozza.area == .previdenza { gruppoPrevidenza }
        if conAssicurato { gruppoAssicurato }
        if bozza.area == .debiti { gruppoDebito }
    }

    // MARK: Movimenti datati

    private var gruppoMovimenti: some View {
        let m = Tema.Misura.Inserimento.self
        let elenco = bozza.movimenti ?? []
        return VStack(alignment: .leading, spacing: m.spazioCampi) {
            GruppoCampi(titolo: "Versamenti e riscatti con la data",
                        spiegazione: "Con le date vere il rendimento dei versamenti del cliente è esatto. Se ne inserisci uno, inserisci tutti i versamenti, anche il primo: Prisma userà solo questi. Con i soli riscatti parziali, i versamenti si ricostruiscono da decorrenza e premi.")
            ForEach(elenco.indices, id: \.self) { i in rigaMovimento(i) }
            HStack(spacing: m.spazioRiga) {
                Button { aggiungiMovimento() } label: { Label("Movimento", systemImage: "plus") }
                    .buttonStyle(StileCollegamento())
                Spacer(minLength: m.spazioRiga)
                if !elenco.isEmpty {
                    Text(riepilogoMovimenti(elenco))
                        .font(Tema.Testo.Inserimento.nota)
                        .foregroundColor(Tema.Colore.Inserimento.nota)
                }
            }
        }
    }

    /// Una riga dell'elenco: tipo, data, importo, nota.
    private func rigaMovimento(_ i: Int) -> some View {
        let m = Tema.Misura.Inserimento.self
        let movimento = movimentoBinding(i)
        // Il tipo è il segno dell'importo: + versamento, − riscatto (anche −0 finché l'importo manca)
        let incasso = Binding<Bool>(
            get: { movimento.wrappedValue.importo.sign == .minus },
            set: { scelto in
                let v = abs(movimento.wrappedValue.importo)
                movimento.wrappedValue.importo = scelto ? -v : v
            }
        )
        let importo = Binding<Double?>(
            get: { movimento.wrappedValue.importo == 0 ? nil : abs(movimento.wrappedValue.importo) },
            set: { nuovo in
                let v = abs(nuovo ?? 0)
                movimento.wrappedValue.importo = movimento.wrappedValue.importo.sign == .minus ? -v : v
            }
        )
        return HStack(spacing: m.spazioRiga) {
            MenuTendina(selezione: incasso,
                        opzioni: [(false, "Versamento"), (true, "Riscatto parziale")],
                        larghezza: m.tipoMovimento)
            DatePicker("", selection: movimento.data, displayedComponents: .date)
                .labelsHidden()
                .stileDataCampo()
                .environment(\.locale, Formati.italiano)
                .fixedSize()
            CampoCifraFacoltativa(valore: importo, unita: "€", larghezza: m.campoEuro)
            TextField("Nota", text: movimento.nota)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: m.notaMovimento)
            Button("Togli") { togliMovimento(i) }
                .buttonStyle(StileSemplice())
                .font(Tema.Testo.Inserimento.azione)
                .foregroundColor(Tema.Colore.Inserimento.togli)
        }
    }

    private func movimentoBinding(_ i: Int) -> Binding<Movimento> {
        Binding(
            get: {
                guard let elenco = bozza.movimenti, elenco.indices.contains(i) else {
                    return Movimento(data: Date(), importo: 0)
                }
                return elenco[i]
            },
            set: { nuovo in
                guard var elenco = bozza.movimenti, elenco.indices.contains(i) else { return }
                elenco[i] = nuovo
                bozza.movimenti = elenco
            }
        )
    }

    private func aggiungiMovimento() {
        let giorno = Calendar.current.startOfDay(for: bozza.movimenti?.last?.data ?? bozza.decorrenza ?? Date())
        var elenco = bozza.movimenti ?? []
        elenco.append(Movimento(data: giorno, importo: 0))
        bozza.movimenti = elenco
    }

    private func togliMovimento(_ i: Int) {
        guard var elenco = bozza.movimenti, elenco.indices.contains(i) else { return }
        elenco.remove(at: i)
        bozza.movimenti = elenco.isEmpty ? nil : elenco
    }

    private func riepilogoMovimenti(_ elenco: [Movimento]) -> String {
        let versati = elenco.filter { $0.importo > 0 }.reduce(0.0) { $0 + $1.importo }
        let incassati = elenco.filter { $0.importo < 0 }.reduce(0.0) { $0 - $1.importo }
        return "Versati \(Formati.euro(versati)) · incassati \(Formati.euro(incassati))"
    }

    // MARK: Riscatto

    private var gruppoRiscatto: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioCampi) {
            GruppoCampi(titolo: "Riscatto",
                        spiegazione: "Per il riscatto anno per anno: quanto incassa il cliente se esce prima. Se mancano, valgono i dati della scheda prodotto.")
            CampoModulo(etichetta: "Penali di riscatto") { campoPenali }
            CampoModulo(etichetta: "Riscatto bloccato") {
                CampoInteroFacoltativo(valore: $bozza.mesiBloccoRiscatto, unita: notaBlocco)
            }
            CampoModulo(etichetta: "Costo d'uscita") {
                CampoCifraFacoltativa(valore: $bozza.costoUscita, unita: "% del valore riscattato, oltre alle penali")
            }
        }
    }

    private var notaBlocco: String {
        if bozza.mesiBloccoRiscatto == nil, let mesi = prodotto?.condizioni?.mesiBloccoRiscatto {
            return "mesi dalla decorrenza · se vuoto, \(mesi) dalla scheda prodotto"
        }
        return "mesi dalla decorrenza · 0 = riscattabile subito"
    }

    private var campoPenali: some View {
        let m = Tema.Misura.Inserimento.self
        return VStack(alignment: .leading, spacing: m.spazioUnita) {
            Toggle("Indico le penali di questa posizione",
                   isOn: Binding(get: { bozza.penali != nil }, set: { penaliProprie($0) }))
                .stileCasella()
            if let penali = bozza.penali {
                ForEach(penali.indices, id: \.self) { i in
                    HStack(spacing: m.spazioUnita) {
                        Text("\(i + 2)° anno")
                            .font(Tipo.campoEtichetta)
                            .foregroundColor(Tema.Colore.inchiostroSecondario)
                            .frame(width: m.annoPenale, alignment: .leading)
                        CampoCifraFacoltativa(valore: penale(i), unita: "% del valore")
                        if i == penali.count - 1 {
                            Button("Togli") { togliUltimaPenale() }
                                .buttonStyle(StileSemplice())
                                .font(Tema.Testo.Inserimento.azione)
                                .foregroundColor(Tema.Colore.Inserimento.togli)
                        }
                    }
                }
                Button { aggiungiPenale() } label: { Label("Anno con penale", systemImage: "plus") }
                    .buttonStyle(StileCollegamento())
                Text(penali.isEmpty ? "Nessuna penale." : "Dal \(penali.count + 2)° anno nessuna penale.")
                    .font(Tema.Testo.Inserimento.nota)
                    .foregroundColor(Tema.Colore.Inserimento.nota)
            } else {
                Text(notaPenaliScheda)
                    .font(Tema.Testo.Inserimento.nota)
                    .foregroundColor(Tema.Colore.Inserimento.nota)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Con la casella accesa le penali sono della posizione: si parte da quelle della scheda, se ci sono.
    private func penaliProprie(_ si: Bool) {
        if !si {
            bozza.penali = nil
            return
        }
        if bozza.penali == nil {
            let scheda: [Double] = prodotto?.condizioni?.penali ?? []
            bozza.penali = scheda
        }
    }

    private func penale(_ i: Int) -> Binding<Double?> {
        Binding(
            get: {
                guard let elenco = bozza.penali, elenco.indices.contains(i) else { return nil }
                return elenco[i]
            },
            set: { nuovo in
                guard var elenco = bozza.penali, elenco.indices.contains(i) else { return }
                elenco[i] = max(0, nuovo ?? 0)
                bozza.penali = elenco
            }
        )
    }

    private func aggiungiPenale() {
        var elenco = bozza.penali ?? []
        elenco.append(elenco.last.map { max(0, $0 - 1) } ?? 2)
        bozza.penali = elenco
    }

    /// Togliere l'ultimo anno lascia l'elenco anche vuoto: «nessuna penale» detto dal consulente.
    private func togliUltimaPenale() {
        guard var elenco = bozza.penali, !elenco.isEmpty else { return }
        elenco.removeLast()
        bozza.penali = elenco
    }

    private var notaPenaliScheda: String {
        guard let c = prodotto?.condizioni else { return "Non indicate: Prisma calcola il riscatto senza penali." }
        if c.penali.isEmpty { return "Valgono quelle della scheda prodotto: nessuna penale." }
        return "Valgono quelle della scheda prodotto: " + c.penali.map { CifreDoc.penale($0) }.joined(separator: " · ") + "."
    }

    // MARK: KID, gestione separata, rischio, previdenza

    private var gruppoKID: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioCampi) {
            GruppoCampi(titolo: "Dal KID",
                        spiegazione: "Prisma calcola da sé l'incidenza annua dei costi (RIY) e la confronta con quella dichiarata nel KID.")
            CampoModulo(etichetta: "Costi nel KID (RIY)") {
                CampoCifraFacoltativa(valore: $bozza.incidenzaCostiKID, unita: "% l'anno al periodo raccomandato")
            }
            CampoModulo(etichetta: "Periodo raccomandato") {
                CampoInteroFacoltativo(valore: $bozza.periodoRaccomandato, unita: "anni")
            }
        }
    }

    private var gruppoGestioneSeparata: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioCampi) {
            GruppoCampi(titolo: "Gestione separata",
                        spiegazione: "Per le polizze rivalutabili di Ramo I. Al cliente va il rendimento lordo meno il trattenuto (oppure la quota retrocessa), mai sotto il minimo garantito se il consolidamento è annuo.")
            CampoModulo(etichetta: "Minimo garantito") {
                CampoCifraFacoltativa(valore: $bozza.minimoGarantito, unita: "% l'anno · 0 = garantito solo il capitale")
            }
            CampoModulo(etichetta: "Consolidamento") {
                MenuTendina(selezione: $bozza.consolidamento,
                            opzioni: [(Bool?.none, "Non indicato · si considera annuo"),
                                      (Optional(true), "Annuo: l'accreditato non si perde"),
                                      (Optional(false), "Solo a scadenza o al decesso")],
                            larghezza: Tema.Misura.Inserimento.tendinaConsolidamento)
            }
            CampoModulo(etichetta: "Retrocessione") {
                CampoCifraFacoltativa(valore: $bozza.retrocessione, unita: "% del rendimento lordo · al posto del trattenuto")
            }
            if let esito = MotoreGestioneSeparata.calcola(bozza) {
                CampoModulo(etichetta: "Accreditato stimato") {
                    Text(testoAccreditato(esito))
                        .font(Tema.Testo.Inserimento.nota)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func testoAccreditato(_ e: EsitoGestioneSeparata) -> String {
        "\(Formati.percentuale(e.accreditato)) l'anno su un lordo ipotizzato del \(Formati.percentuale(e.lordo))"
            + (e.minimoDecisivo ? " · decide il minimo garantito" : "") + " (stima, prima delle imposte)"
    }

    private var gruppoRischio: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioCampi) {
            GruppoCampi(titolo: bozza.multiramo ? "Rischio del contratto" : "Rischio",
                        spiegazione: "Per le crisi del passato e gli scenari con le probabilità. Se mancano, Prisma li stima da tipologia e SRI e lo dichiara.")
            CampoModulo(etichetta: "Quota azionaria") {
                CampoCifraFacoltativa(valore: $bozza.quotaAzionaria, unita: "% investita in azioni")
            }
            CampoModulo(etichetta: "Volatilità") {
                CampoCifraFacoltativa(valore: $bozza.volatilita, unita: "% l'anno (deviazione standard)")
            }
        }
    }

    private var gruppoPrevidenza: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioCampi) {
            GruppoCampi(titolo: "Previdenza complementare",
                        spiegazione: "Il contributo del datore di lavoro conta nel limite di deducibilità del cliente; il TFR conferito no.")
            CampoModulo(etichetta: "Contributo del datore") {
                CampoCifraFacoltativa(valore: $bozza.contributoDatore, unita: "€ l'anno", larghezza: Tema.Misura.Inserimento.campoEuro)
            }
            CampoModulo(etichetta: "TFR conferito") {
                CampoCifraFacoltativa(valore: $bozza.tfrConferito, unita: "€ l'anno", larghezza: Tema.Misura.Inserimento.campoEuro)
            }
        }
    }

    // MARK: Persona assicurata e debito

    private var gruppoAssicurato: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioCampi) {
            GruppoCampi(titolo: "Persona assicurata",
                        spiegazione: "Per la protezione di ogni persona della famiglia: su chi è la copertura. Se non la scegli, Prisma la riconosce dal nome scritto in «Assicurato».")
            CampoModulo(etichetta: "Persona") {
                MenuTendina(selezione: assicuratoScelto, opzioni: opzioniPersone,
                            larghezza: Tema.Misura.Inserimento.tendinaPersona)
            }
            if bozza.area == .protezione {
                CampoModulo(etichetta: "Capitale decrescente") {
                    Toggle("Il capitale caso morte scende nel tempo (per esempio legato al mutuo)",
                           isOn: Binding(get: { bozza.capitaleDecrescente == true }, set: { capitaleDecrescente($0) }))
                        .stileCasella()
                }
            }
        }
    }

    /// Spenta la casella: «no» se il dato era indicato, altrimenti resta «non indicato».
    private func capitaleDecrescente(_ si: Bool) {
        if si {
            bozza.capitaleDecrescente = true
        } else if bozza.capitaleDecrescente != nil {
            bozza.capitaleDecrescente = false
        }
    }

    /// Il cliente e i suoi familiari; in fondo una persona tolta dalla famiglia, se era scelta.
    private var opzioniPersone: [(String?, String)] {
        var voci: [(String?, String)] = [(nil, "Dal nome scritto in «Assicurato»")]
        if let c = stato.cliente(bozza.clienteId) {
            voci.append((Optional(c.id), "\(c.nome) · cliente"))
            for f in c.famiglia {
                voci.append((Optional(f.id), "\(f.nome) · \(f.relazione.nome.lowercased())"))
            }
        }
        if let id = bozza.assicuratoId, !voci.contains(where: { $0.0 == id }) {
            voci.append((Optional(id), "Persona non più in famiglia"))
        }
        return voci
    }

    /// Scegliere la persona scrive anche il nome in «Assicurato», se è vuoto (serve al prospetto).
    private var assicuratoScelto: Binding<String?> {
        Binding(
            get: { bozza.assicuratoId },
            set: { id in
                bozza.assicuratoId = id
                if bozza.assicurato.trimmingCharacters(in: .whitespaces).isEmpty, let nome = nomePersona(id) {
                    bozza.assicurato = nome
                }
            }
        )
    }

    private func nomePersona(_ id: String?) -> String? {
        guard let id, let c = stato.cliente(bozza.clienteId) else { return nil }
        if c.id == id { return c.nome }
        return c.famiglia.first { $0.id == id }?.nome
    }

    private var gruppoDebito: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioCampi) {
            GruppoCampi(titolo: "Finanziamento",
                        spiegazione: "Per la rata, il debito residuo anno per anno e la protezione del mutuo. Senza la quota, il debito è tutto del cliente.")
            CampoModulo(etichetta: "Tasso annuo") {
                CampoCifraFacoltativa(valore: $bozza.tassoDebito, unita: "% nominale")
            }
            CampoModulo(etichetta: "Quota del cliente") {
                CampoCifraFacoltativa(valore: $bozza.quotaDebito, unita: "% a suo carico, se il debito è cointestato")
            }
            if let rata = rataStimata {
                CampoModulo(etichetta: "Rata stimata") {
                    Text(rata)
                        .font(Tema.Testo.Inserimento.nota)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// La rata del piano alla francese sul debito residuo e i mesi che restano alla scadenza.
    private var rataStimata: String? {
        guard let mesi = bozza.mesiResidui(), mesi > 0, bozza.valore > 0 else { return nil }
        let rata = MotoreProtezioneFamiglia.rataDebito(capitale: bozza.valore, tasso: bozza.tassoDebito, mesi: mesi)
        return "circa \(Formati.euro(rata)) al mese per i \(mesi) mesi che restano (stima con il piano alla francese)"
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
