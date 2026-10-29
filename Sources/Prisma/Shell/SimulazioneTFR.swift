import SwiftUI

/// Simulazioni › TFR (giro 6, specifica 11 §7.5): «TFR in azienda o nel fondo pensione» per un lavoratore
/// dipendente. Stessa console a cristalli liquidi del simulatore a sinistra, risultati a destra; prospetto e
/// report in PDF dalla testata dei risultati.
///
/// Le ipotesi sul tavolo sono una bozza locale: i cursori scrivono la bozza e l'archivio si aggiorna solo dopo
/// una pausa (e quando la vista sparisce o cambia il cliente). Scrivere `dati` a ogni passo del cursore
/// ridisegnerebbe tutte le finestre aperte: sull'M1 da 8 GB si sente.
struct SchedaTFR: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) private var modoIstantanea
    @State private var report = false
    @State private var daSalvare: PDFDaSalvare?
    @State private var archiviato: String?
    @State private var mostraMetodo = false
    /// La bozza delle ipotesi e il cliente a cui appartiene (nil = si leggono quelle dell'archivio).
    @State private var bozza: IpotesiTFR?
    @State private var clienteBozza: String?

    private typealias M = Tema.Misura.TFR
    private typealias K = Tema.Colore.TFR
    private typealias F = Tema.Testo.TFR

    /// Intervalli e passi dei comandi della console (la lettura dell'archivio ha limiti più larghi: `IpotesiTFR.Limiti`).
    private enum Console {
        static let retribuzione: ClosedRange<Double> = IpotesiTFR.Limiti.retribuzione
        static let passoRetribuzione = 500.0
        static let fineRetribuzione = 150_000.0
        static let crescita: ClosedRange<Double> = IpotesiTFR.Limiti.crescitaReale
        static let anni: ClosedRange<Double> = 1...50
        static let inflazione: ClosedRange<Double> = 0...10
        static let rendimento: ClosedRange<Double> = -10...15
        static let costo: ClosedRange<Double> = 0...3
        static let contributo: ClosedRange<Double> = 0...10
        static let partecipazione: ClosedRange<Double> = 0...50
        static let aliquota: ClosedRange<Double> = IpotesiTFR.Limiti.aliquotaTFR
        static let passo = 0.1
        static let passoCosto = 0.05
    }

    private var cliente: String { stato.clienteAttivoId }

    /// Le ipotesi sul tavolo: la bozza del cliente attivo o quelle dell'archivio (salvate o dai dati del cliente).
    private var ipotesi: IpotesiTFR {
        if let b = bozza, clienteBozza == cliente { return b }
        return stato.ipotesiTFR(cliente)
    }

    private var legame: Binding<IpotesiTFR> {
        Binding(get: { ipotesi }, set: { nuove in
            if clienteBozza != cliente { clienteBozza = cliente }
            bozza = nuove
        })
    }

    var body: some View {
        let i = ipotesi
        let e = MotoreTFR.calcola(i)
        ColonneAffiancate(larghezza: Misure.ColonneStrumento.comandi) {
            console(i)
        } flessibile: {
            risultati(i, e)
        }
        .sheet(item: $daSalvare) { pdf in
            ModuloSalvaPDF(pdf: pdf, impostazioni: stato.dati.impostazioni.pdf)
                .environmentObject(stato)
        }
        .onChange(of: stato.clienteAttivoId) { _ in
            // La bozza del cliente di prima si salva prima di passare al nuovo
            salvaBozza()
            bozza = nil
            clienteBozza = nil
            archiviato = nil
        }
        .task(id: bozza) {
            guard bozza != nil else { return }
            try? await Task.sleep(nanoseconds: M.pausaSalvataggio)
            if !Task.isCancelled { salvaBozza() }
        }
        .onDisappear { salvaBozza() }
    }

    /// Scrive la bozza nell'archivio (se è cambiata: `salvaIpotesiTFR` non riscrive ipotesi uguali).
    private func salvaBozza() {
        guard let b = bozza, let c = clienteBozza else { return }
        stato.salvaIpotesiTFR(c, b)
    }

    // MARK: - Console

    private func console(_ i: IpotesiTFR) -> some View {
        let b = legame
        return ScrollView {
            VStack(alignment: .leading, spacing: M.spazioConsole) {
                // Gruppi: un ViewBuilder accetta al massimo dieci viste per blocco
                Group {
                    ComandoSimulatore(etichetta: "Retribuzione lorda annua", valore: b.retribuzione, unita: "€",
                                      intervallo: Console.retribuzione, passo: Console.passoRetribuzione,
                                      fineCursore: Console.fineRetribuzione)
                    ComandoSimulatore(etichetta: "Crescita oltre l'inflazione", valore: b.crescitaReale, unita: "%",
                                      intervallo: Console.crescita, passo: Console.passo, decimali: 1)
                    ComandoSimulatore(etichetta: "Anni alla pensione", valore: intero(b.anni, Console.anni), unita: "anni",
                                      intervallo: Console.anni, passo: 1)
                    ComandoSimulatore(etichetta: "Inflazione ipotizzata", valore: b.inflazione, unita: "%",
                                      intervallo: Console.inflazione, passo: Console.passo, decimali: 1)
                }
                Rectangle().fill(K.filo).frame(height: Tema.Misura.filo)
                Group {
                    ComandoSimulatore(etichetta: "Rendimento lordo del fondo", valore: b.rendimentoFondo, unita: "%",
                                      intervallo: Console.rendimento, passo: Console.passo, decimali: 1)
                    ComandoSimulatore(etichetta: "Costi del fondo (ISC)", valore: b.costoFondo, unita: "%",
                                      intervallo: Console.costo, passo: Console.passoCosto, decimali: 2)
                    ComandoSimulatore(etichetta: "Il tuo contributo", valore: b.contributoLavoratore, unita: "%",
                                      intervallo: Console.contributo, passo: Console.passo, decimali: 1)
                    ComandoSimulatore(etichetta: "Contributo del datore", valore: b.contributoDatore, unita: "%",
                                      intervallo: Console.contributo, passo: Console.passo, decimali: 1)
                    ComandoSimulatore(etichetta: "Anni già nella previdenza", valore: intero(b.anniPartecipazione, Console.partecipazione),
                                      unita: "anni", intervallo: Console.partecipazione, passo: 1)
                }
                scelta("Canale della consulenza") {
                    SegmentiAnalisi(opzioni: [(Canale.alleanza, "Alleanza"), (.indipendente, "Indip.")], selezione: b.canale)
                }
                scelta("Aliquota del TFR") {
                    SegmentiAnalisi(opzioni: [(false, "Calcolata"), (true, "La indico io")], selezione: aliquotaAMano(b))
                }
                if i.aliquotaTFR != nil {
                    ComandoSimulatore(etichetta: "Aliquota della tassazione separata",
                                      valore: Binding(get: { b.wrappedValue.aliquotaTFR ?? 0 },
                                                      set: { b.wrappedValue.aliquotaTFR = min(max($0, Console.aliquota.lowerBound), Console.aliquota.upperBound) }),
                                      unita: "%", intervallo: Console.aliquota, passo: Console.passo, decimali: 1)
                }
                Button {
                    bozza = nil
                    clienteBozza = nil
                    stato.ripartiTFR(cliente)
                } label: {
                    Label("Riparti dai dati del cliente", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(StileCollegamento())
                .help("Toglie le ipotesi salvate: retribuzione, anni alla pensione e anni nella previdenza ripartono dal dossier")
            }
            .padding(M.margineConsole)
        }
    }

    /// Un campo intero letto e scritto dal cursore, nell'intervallo dei comandi.
    private func intero(_ b: Binding<Int>, _ r: ClosedRange<Double>) -> Binding<Double> {
        Binding(get: { Double(b.wrappedValue) },
                set: { b.wrappedValue = Int(min(max($0, r.lowerBound), r.upperBound).rounded()) })
    }

    /// «Calcolata» o «La indico io»: passando a mano si parte dall'aliquota che Prisma calcola.
    private func aliquotaAMano(_ b: Binding<IpotesiTFR>) -> Binding<Bool> {
        Binding(get: { b.wrappedValue.aliquotaTFR != nil },
                set: { aMano in
                    var i = b.wrappedValue
                    if aMano {
                        guard i.aliquotaTFR == nil else { return }
                        i.aliquotaTFR = nil
                        let calcolata = MotoreTFR.calcola(i)?.azienda.aliquota ?? 0
                        i.aliquotaTFR = (calcolata * 10).rounded() / 10
                    } else {
                        i.aliquotaTFR = nil
                    }
                    b.wrappedValue = i
                })
    }

    private func scelta<C: View>(_ etichetta: String, @ViewBuilder _ contenuto: () -> C) -> some View {
        VStack(alignment: .leading, spacing: M.spazioScelta) {
            Text(etichetta)
                .font(F.etichettaConsole)
                .foregroundColor(K.etichetta)
            contenuto()
        }
    }

    // MARK: - Risultati

    private func risultati(_ i: IpotesiTFR, _ e: EsitoTFR?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: M.spazioRisultati) {
                testata(i, disponibile: e != nil)
                if let e {
                    let testi = TestiTFR(e, cliente: stato.clienteAttivo)
                    cifre(e)
                    TitoloStrumento(occhiello: "Le due strade", titolo: testi.titoloConfronto, testo: testi.sottotitoloConfronto)
                    indicatori(e)
                    grafico(e)
                    Text(testi.testoPareggio)
                        .font(F.testo)
                        .foregroundColor(K.cifra)
                        .fixedSize(horizontal: false, vertical: true)
                    if let c = testi.testoContributi {
                        Text(c)
                            .font(F.testo)
                            .foregroundColor(K.cifra)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    tabella(e, eta: testi.eta)
                    if let p = stato.fondoConTFR(cliente), let tfr = p.tfrConferito {
                        Text("Il TFR va già in «\(p.nome)»: \(Formati.euro(tfr)) l'anno. Il confronto mostra cosa è cambiato rispetto a lasciarlo in azienda.")
                            .font(F.nota)
                            .foregroundColor(K.notaKPI)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    piede
                } else {
                    Text("Indica la retribuzione lorda annua per confrontare le due strade.")
                        .font(F.testo)
                        .foregroundColor(K.notaKPI)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(M.margineRisultati)
        }
    }

    // MARK: Testata: canale, fondo, prospetto o report, uscite del PDF

    private func testata(_ i: IpotesiTFR, disponibile: Bool) -> some View {
        let nome = i.nomeFondo.trimmingCharacters(in: .whitespacesAndNewlines)
        let identita = HStack(spacing: M.spazioTestata) {
            EtichettaCanale(canale: i.canale, compatta: false)
            Text(nome.isEmpty ? "Fondo pensione" : nome)
                .font(F.fondo)
                .foregroundColor(K.notaKPI)
                .lineLimit(1)
        }
        let documenti = SegmentiAnalisi(opzioni: [(false, "Prospetto"), (true, "Report")], selezione: $report).fixedSize()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: M.spazioTestata) {
                identita
                Spacer(minLength: M.spazioTestata)
                documenti
                pulsanti(disponibile)
            }
            VStack(alignment: .leading, spacing: M.spazioTestata) {
                HStack(spacing: M.spazioTestata) {
                    identita
                    Spacer(minLength: M.spazioTestata)
                    documenti
                }
                HStack(spacing: M.spazioTestata) {
                    Spacer(minLength: 0)
                    pulsanti(disponibile)
                }
            }
        }
    }

    private func pulsanti(_ disponibile: Bool) -> some View {
        HStack(spacing: M.spazioTestata) {
            if let id = archiviato {
                Button {
                    stato.documentoSelezionato = id
                    stato.apri(.documenti)
                } label: {
                    HStack(spacing: Tema.Misura.Componenti.spazioSimboloPulsante) {
                        Text("Archiviato in Documenti")
                        Image(systemName: "arrow.up.right")
                    }
                }
                .buttonStyle(StileCollegamento())
                .fixedSize()
            }
            Button {
                if let d = documento() { stato.presenta(d) }
            } label: {
                Label("Presenta", systemImage: "play.fill")
            }
            .buttonStyle(StileVetro(margine: M.marginePulsante))
            .fixedSize()
            .help("Mostra il documento a tutto schermo, una pagina alla volta, in modalità cliente")
            Button {
                if let d = documento(), let dati = pdf(d) {
                    daSalvare = PDFDaSalvare(dati: dati, nome: StampaCarta.nomeFile(d), cliente: stato.clienteAttivo)
                }
            } label: {
                Label("Salva PDF…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(StileVetro(margine: M.marginePulsante))
            .fixedSize()
            Button {
                if let d = documento(), let dati = pdf(d) { archiviato = stato.archiviaProspetto(dati, documento: d) }
            } label: {
                Label("Archivia nei Documenti", systemImage: "archivebox")
            }
            .buttonStyle(StileVetro(margine: M.marginePulsante))
            .fixedSize()
        }
        .disabled(!disponibile)
    }

    /// Il documento delle ipotesi sul tavolo: prima si salva la bozza, perché il documento legge l'archivio.
    private func documento() -> DocumentoStampabile? {
        salvaBozza()
        guard let d = stato.documentoTFR(report: report) else {
            stato.mostraAvviso("Indica la retribuzione lorda annua per preparare il documento.")
            return nil
        }
        return d
    }

    private func pdf(_ d: DocumentoStampabile) -> Data? {
        guard !modoIstantanea else { return nil }
        let dati = StampaCarta.pdf(d)
        if dati == nil { stato.mostraAvviso("Non sono riuscito a creare il PDF.") }
        return dati
    }

    // MARK: Le cifre grandi

    private func cifre(_ e: EsitoTFR) -> some View {
        let n = e.ipotesi.anni
        return VStack(spacing: M.spazioCifra) {
            Text("NETTO ALLA PENSIONE, TRA \(n) \(n == 1 ? "ANNO" : "ANNI")")
                .font(F.occhielloTFR)
                .tracking(F.tracciatoOcchiello)
                .foregroundColor(K.nota)
            HStack(alignment: .top, spacing: M.spazioCifre) {
                cifra("TFR in azienda", e.azienda, colore: K.azienda)
                cifra("Nel fondo pensione", e.fondo, colore: K.fondo)
                if let c = e.fondoContributi { cifra("Con i contributi", c, colore: K.fondoContributi) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cifra(_ etichetta: String, _ s: StradaTFR, colore: Color) -> some View {
        VStack(spacing: M.spazioCifra) {
            Text(etichetta)
                .font(F.etichettaCifra)
                .foregroundColor(K.notaKPI)
                .lineLimit(1)
            Text(Formati.euro(s.netto))
                .font(F.cifraTFR)
                .foregroundColor(K.cifra)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: M.spazioPallino) {
                Circle().fill(colore).frame(width: M.pallino, height: M.pallino)
                Text("\(Formati.euro(s.reale)) in euro di oggi")
                    .font(F.notaCifra)
                    .foregroundColor(K.nota)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Indicatori

    private func indicatori(_ e: EsitoTFR) -> some View {
        FasciaKPI {
            KPI(titolo: "Differenza, solo TFR", valore: CifreDoc.euroSegno(e.differenza)) {
                Text("\(CifreDoc.euroSegno(e.fondo.reale - e.azienda.reale)) in euro di oggi")
            }
            KPI(titolo: "Rendimento di pareggio", valore: valorePareggio(e.pareggio)) {
                Text(notaPareggio(e))
            }
            KPI(titolo: "Imposta all'uscita",
                valore: "\(CifreDoc.percento(e.azienda.aliquota, decimali: 1)) · \(CifreDoc.percento(e.fondo.aliquota, decimali: 1))",
                ultimo: e.differenzaContributi == nil) {
                Text("TFR in azienda · fondo dopo \(e.anniPartecipazioneFinali) anni")
            }
            if let d = e.differenzaContributi {
                KPI(titolo: "Con i contributi", valore: CifreDoc.euroSegno(d), ultimo: true) {
                    Text("tolti \(CifreDoc.euro(e.costoContributi)) che ti costano, IRPEF risparmiata compresa")
                }
                .help(TestiTFR(e, cliente: stato.clienteAttivo).pareggioContributiBreve ?? "")
            }
        }
    }

    private func valorePareggio(_ p: PareggioTFR) -> String {
        switch p {
        case .a(let lordo, _): return "\(CifreDoc.percento(lordo, decimali: 2)) lordo"
        case .sempre: return "sempre"
        case .mai: return "mai"
        }
    }

    private func notaPareggio(_ e: EsitoTFR) -> String {
        switch e.pareggio {
        case .a(_, let netto):
            return "\(CifreDoc.percento(netto, decimali: 2)) netto · il TFR \(CifreDoc.percento(e.rivalutazioneNetta, decimali: 2))"
        case .sempre:
            return "anche al \(CifreDoc.percento(RegoleTFR.pareggioMinimo, decimali: 0)) l'anno"
        case .mai:
            return "nemmeno al \(CifreDoc.percento(RegoleTFR.pareggioMassimo, decimali: 0)) l'anno"
        }
    }

    // MARK: Grafico

    private func grafico(_ e: EsitoTFR) -> some View {
        var serie: [GraficoProiezione.Serie] = [
            .init(id: "azienda", punti: e.puntiAzienda, colore: K.azienda),
            .init(id: "fondo", punti: e.puntiFondo, colore: K.fondo, principale: true),
        ]
        if let c = e.puntiFondoContributi { serie.append(.init(id: "contributi", punti: c, colore: K.fondoContributi)) }
        return VStack(alignment: .leading, spacing: M.spazioScelta) {
            GraficoProiezione(serie: serie)
            HStack(spacing: M.spazioLegenda) {
                LegendaLinea(colore: K.azienda, testo: "TFR in azienda")
                LegendaLinea(colore: K.fondo, testo: "Nel fondo, solo TFR")
                if e.puntiFondoContributi != nil { LegendaLinea(colore: K.fondoContributi, testo: "Nel fondo con i contributi") }
                LegendaLinea(colore: K.quote, testo: "Quote di TFR", tratteggio: true)
            }
            Text("Montanti prima delle imposte all'uscita")
                .font(F.nota)
                .foregroundColor(K.notaKPI)
        }
    }

    // MARK: Tabella anno per anno

    /// Gli anni della tabella: tutti fino a 15, altrimenti il primo, uno ogni 5 e l'ultimo.
    static func anniTabella(_ n: Int) -> [Int] {
        guard n > M.anniTabellaCompleta else { return Array(1...max(1, n)) }
        var anni = [1]
        anni += stride(from: M.passoTabella, through: n, by: M.passoTabella).filter { $0 > 1 }
        if anni.last != n { anni.append(n) }
        return anni
    }

    private func tabella(_ e: EsitoTFR, eta: Int?) -> some View {
        let righe = Self.anniTabella(e.anni.count).compactMap { a in e.anni.first { $0.anno == a } }
        let contributi = e.conContributi
        let l = M.colonnaTabella
        return VStack(alignment: .leading, spacing: M.spazioScelta) {
            Text("Anno per anno")
                .font(F.etichettaConsole)
                .foregroundColor(K.etichetta)
            TabellaStrumento {
                CellaTesta(testo: "Anno", larghezza: M.colonnaAnnoTabella)
                CellaTesta(testo: "Retribuzione", destra: true)
                CellaTesta(testo: "Quota TFR", larghezza: l, destra: true)
                CellaTesta(testo: "In azienda", larghezza: l, destra: true)
                CellaTesta(testo: "Nel fondo", larghezza: l, destra: true)
                if contributi { CellaTesta(testo: "Con i contributi", larghezza: l, destra: true) }
            } righe: {
                ForEach(Array(righe.enumerated()), id: \.element.id) { indice, a in
                    RigaStrumento(indice: indice) {
                        CellaTabella(testo: eta.map { "\(a.anno) · \($0 + a.anno) anni" } ?? "\(a.anno)", larghezza: M.colonnaAnnoTabella)
                        CellaTabella(testo: Formati.euro(a.retribuzione), destra: true)
                        CellaTabella(testo: Formati.euro(a.quota), larghezza: l, destra: true)
                        CellaTabella(testo: Formati.euro(a.azienda), larghezza: l, destra: true)
                        CellaTabella(testo: Formati.euro(a.fondo), larghezza: l, destra: true, forte: true)
                        if contributi { CellaTabella(testo: Formati.euro(a.fondoContributi), larghezza: l, destra: true) }
                    }
                }
            }
        }
    }

    // MARK: Da sapere e metodo

    private var piede: some View {
        VStack(alignment: .leading, spacing: M.spazioRisultati) {
            Text(TestiTFR.daSapere[0])
                .font(F.nota)
                .foregroundColor(K.avviso)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button { mostraMetodo.toggle() } label: {
                    Label(mostraMetodo ? "Nascondi il metodo" : "Come si calcola?",
                          systemImage: mostraMetodo ? "chevron.up" : "questionmark.circle")
                }
                .buttonStyle(StileCollegamento())
            }
            if mostraMetodo {
                NotaMetodo(testo: (TestiTFR.metodo + TestiTFR.semplificazioni).joined(separator: "\n"),
                           titolo: "Le regole del confronto")
            }
            NotaMetodo(testo: TestiTFR.avvertenza)
        }
    }
}
