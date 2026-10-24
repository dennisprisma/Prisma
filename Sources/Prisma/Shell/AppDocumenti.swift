import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// App Documenti (.os-app-documents): i documenti del cliente, letti sul Mac.
/// Trascini o importi un KID, una polizza, un estratto conto: Prisma legge il testo
/// (PDFKit, Vision per le scansioni), trova i dati con la pagina di riferimento,
/// tu li confermi e diventano una scheda prodotto o una posizione del cliente.
struct AppDocumenti: View {
    enum Scheda: Hashable { case dati, testo }

    @EnvironmentObject var stato: StatoShell
    @State var scheda: Scheda = .dati
    @State var pagina = 1
    @State var sopra = false
    @State var canale: Canale = .alleanza
    @State var area: AreaPosizione = .investimento
    @State var confermaEliminazione = false
    /// La posizione scelta a mano per il valore di un estratto conto (nil = quella riconosciuta).
    @State var posizioneValore: String?

    private var cliente: String { stato.clienteAttivoId }
    private var elenco: [Documento] { stato.documentiCliente(cliente) }
    private var scelto: Documento? { elenco.first { $0.id == stato.documentoSelezionato } ?? elenco.first }

    var body: some View {
        CorniceStrumento(
            notaStato: "Lettura sul Mac: PDFKit per il testo, Vision per le scansioni · nessun file lascia il computer",
            notaDestra: "\(elenco.count) \(elenco.count == 1 ? "documento" : "documenti") del cliente"
        ) {
            rail
        } contenuto: {
            HStack(spacing: 0) {
                colonnaElenco
                    .frame(width: Misure.Strumenti.ipotesi)
                    .bordoDestro(Colori.Strumenti.ipotesiBordo)
                if let d = scelto {
                    dettaglio(d)
                } else {
                    zonaRilascio
                }
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $sopra) { fornitori in
            for f in fornitori {
                _ = f.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { stato.importaDocumenti([url]) } }
                }
            }
            return true
        }
        .overlay {
            if sopra {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Colori.Analisi.navBasso, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    .background(Colori.Analisi.navBasso.opacity(0.06))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: stato.documentoSelezionato) { _ in pagina = 1 }
        .alert("Eliminare il documento?", isPresented: $confermaEliminazione) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) { if let d = scelto { stato.eliminaDocumento(d.id) } }
        } message: {
            Text("Il file viene tolto dall'archivio di Prisma. Schede e posizioni già create restano. Se serve, lo recuperi da un backup.")
        }
    }

    private func importa() {
        let pannello = NSOpenPanel()
        pannello.allowedContentTypes = [.pdf, .png, .jpeg, .tiff, .heic]
        pannello.allowsMultipleSelection = true
        pannello.prompt = "Importa"
        pannello.message = "Scegli KID, polizze, estratti conto o proposte: verranno copiati nell'archivio di Prisma."
        if pannello.runModal() == .OK { stato.importaDocumenti(pannello.urls) }
    }

    // MARK: - Elenco laterale

    @ViewBuilder private var rail: some View {
        DossierRail()
        EtichettaRail(testo: "Aggiungi")
        Button("Importa documenti…") { importa() }
            .buttonStyle(StileBlu())
        Text("Oppure trascina qui i file: PDF, foto o scansioni. Vengono copiati nell'archivio del cliente e inclusi nei backup.")
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Analisi.kpiNota)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3)
        EtichettaRail(testo: "Come funziona")
        VStack(alignment: .leading, spacing: 4) {
            Text("1. Prisma legge il testo, anche delle scansioni.")
            Text("2. Trova i dati e scrive la pagina da cui vengono.")
            Text("3. Tu li confermi o li correggi.")
            Text("4. Diventano una scheda prodotto o una posizione.")
        }
        .font(Tipo.kpiNota)
        .foregroundColor(Colori.Analisi.railTesto)
        .padding(.horizontal, 3)
        CollegatiRail(app: [.prodotti, .posizioni, .eve])
    }

    // MARK: - Elenco dei documenti

    private var colonnaElenco: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DOCUMENTI DI \((stato.clienteAttivo?.nome ?? "").uppercased())").font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
                Spacer()
            }
            .padding(10)
            .background(Gradienti.testaIpotesi)
            .bordoBasso(Colori.Strumenti.ipotesiBordo)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(elenco) { d in
                        Button { stato.documentoSelezionato = d.id } label: { riga(d, attiva: d.id == scelto?.id) }
                            .buttonStyle(StileSemplice())
                    }
                    if elenco.isEmpty {
                        Text("Nessun documento per questo cliente.")
                            .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).padding(12)
                    }
                }
            }
        }
        .background(Gradienti.railAnalisi)
    }

    private func riga(_ d: Documento, attiva: Bool) -> some View {
        let confermati = d.campi.filter(\.confermato).count
        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: d.tipo == .kid ? "doc.text.magnifyingglass" : d.tipo == .polizza ? "doc.richtext" : "doc.text")
                .font(.system(size: 16))
                .foregroundColor(attiva ? .white : Colori.Analisi.navBasso)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.titolo).font(Tipo.tabellaCellaForte).foregroundColor(attiva ? .white : Colori.Analisi.tabellaTesto).lineLimit(1)
                Text("\(d.tipo.breve) · \(d.pagine) \(d.pagine == 1 ? "pagina" : "pagine") · \(Formati.dataBreve.string(from: d.importatoIl))")
                    .font(Tipo.chip)
                    .foregroundColor(attiva ? Color.white.opacity(0.85) : Colori.Analisi.kpiNota)
                HStack(spacing: 5) {
                    if stato.documentiInLettura.contains(d.id) {
                        ProgressView().controlSize(.mini)
                        Text("In lettura…")
                    } else if d.lettura == .illeggibile {
                        Text("Testo non leggibile")
                    } else {
                        Text("\(d.campi.count) dati trovati · \(confermati) confermati")
                    }
                }
                .font(Tipo.chip)
                .foregroundColor(attiva ? Color.white.opacity(0.85) : (d.lettura == .illeggibile ? Colori.Analisi.erroreTesto : Colori.Analisi.kpiNota))
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(attiva ? AnyShapeStyle(Gradienti.navAnalisi) : AnyShapeStyle(Color.clear))
        .bordoBasso(Colori.Strumenti.ipotesiRiga)
    }

    private var zonaRilascio: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down").font(.system(size: 40, weight: .light)).foregroundColor(Colori.Analisi.lineaTratteggiata)
            Text("Trascina qui KID, polizze ed estratti conto").font(Tipo.strumentoTitolo).foregroundColor(Colori.Strumenti.titolo)
            Text("Prisma legge il testo sul Mac, trova i dati e ti chiede di confermarli prima di metterli nel dossier.")
                .font(Tipo.strumentoTesto).foregroundColor(Colori.Analisi.kpiNota)
                .multilineTextAlignment(.center).frame(maxWidth: 440)
            Button("Importa documenti…") { importa() }.buttonStyle(StileBlu())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Dettaglio

    private func dettaglio(_ d: Documento) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    TextField("Titolo", text: Binding(get: { d.titolo }, set: { stato.rinominaDocumento(d.id, titolo: $0, tipo: d.tipo) }))
                        .textFieldStyle(.plain)
                        .font(Tipo.profiloNome)
                        .foregroundColor(Colori.Analisi.kpiValore)
                    Text(meta(d)).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                }
                Spacer()
                Picker("", selection: Binding(get: { d.tipo }, set: { stato.rinominaDocumento(d.id, titolo: d.titolo, tipo: $0) })) {
                    ForEach(Documento.Tipo.allCases) { Text($0.nome).tag($0) }
                }
                .labelsHidden()
                .frame(width: 210)
                if !d.tipo.creatoDaPrisma {
                    Button("✦ Chiedi a Eve") { stato.spiegaDocumentoConEve(d.id) }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                        .disabled(stato.eveInCorso || stato.documentiInLettura.contains(d.id))
                        .help("Eve spiega il documento con le pagine e lo confronta con il dossier")
                }
                if let url = stato.urlDocumento(d) {
                    Button("Apri") { NSWorkspace.shared.open(url) }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                    if !d.tipo.creatoDaPrisma {
                        Button("Rileggi") { stato.leggiDocumento(d.id) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
                            .disabled(stato.documentiInLettura.contains(d.id))
                    }
                }
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16))
            .background(Gradienti.kpi)
            .bordoBasso(Colori.Analisi.kpiBordo)
            SchedeRisultati(opzioni: [(Scheda.dati, "Dati trovati"), (.testo, "Testo letto")], selezione: $scheda) {
                Button("Elimina…") { confermaEliminazione = true }
                    .buttonStyle(StileSemplice())
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.erroreTesto)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if scheda == .dati { dati(d) } else { testo(d) }
                }
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 18, trailing: 16))
            }
        }
    }

    private func meta(_ d: Documento) -> String {
        var parti = [d.tipo.nome, "\(d.pagine) \(d.pagine == 1 ? "pagina" : "pagine")"]
        if d.pagineOCR > 0 { parti.append("\(d.pagineOCR) lette dalla scansione") }
        if d.dimensione > 0 { parti.append(Formati.dimensione(d.dimensione)) }
        parti.append("importato il \(Formati.dataEstesa.string(from: d.importatoIl))")
        if d.file == nil { parti.append("documento di prova") }
        return parti.joined(separator: " · ")
    }

    // MARK: - Dati trovati

    @ViewBuilder private func dati(_ d: Documento) -> some View {
        if d.tipo.creatoDaPrisma {
            NotaMetodo(testo: "Impaginato da Prisma con i dati del dossier: è un documento da consultare, stampare o consegnare, non ci sono dati da estrarre. Con «Apri» lo vedi in Anteprima; il testo è nella scheda accanto.",
                       titolo: d.tipo.nome)
        } else {
            datiEstratti(d)
        }
    }

    @ViewBuilder private func datiEstratti(_ d: Documento) -> some View {
        if stato.documentiInLettura.contains(d.id) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Prisma sta leggendo il documento…").font(Tipo.strumentoTesto).foregroundColor(Colori.Analisi.kpiNota)
            }
        }
        if d.campi.isEmpty && !stato.documentiInLettura.contains(d.id) {
            NotaMetodo(testo: d.lettura == .illeggibile
                       ? "Non sono riuscito a leggere il testo: prova con una scansione più nitida o un PDF originale."
                       : "Non ho trovato dati riconoscibili. Puoi leggere il testo nella scheda accanto e inserire i dati a mano in Prodotti o Posizioni.")
        } else {
            HStack {
                TitoloStrumento(occhiello: "Dal documento al dossier", titolo: "Conferma i dati",
                                testo: "Solo i dati confermati entrano nelle schede e nelle posizioni. Puoi correggere un valore: diventa confermato.")
                Spacer()
                Button("Conferma tutti") { for c in d.campi { stato.confermaCampo(d.id, c.chiave, true) } }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
            }
            TabellaStrumento {
                CellaTesta(testo: "", larghezza: 34)
                CellaTesta(testo: "Dato", larghezza: 220)
                CellaTesta(testo: "Valore")
                CellaTesta(testo: "Pagina", larghezza: 70, destra: true)
            } righe: {
                ForEach(Array(d.campi.enumerated()), id: \.element.id) { i, c in
                    RigaStrumento(indice: i) {
                        Button { stato.confermaCampo(d.id, c.chiave, !c.confermato) } label: {
                            Image(systemName: c.confermato ? "checkmark.square.fill" : "square")
                                .foregroundColor(c.confermato ? Colori.Analisi.navBasso : Colori.Analisi.kpiNota)
                                .frame(width: 34)
                        }
                        .buttonStyle(StileSemplice())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.chiave.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                            Text(c.origine).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                        }
                        .padding(Misure.Analisi.cellaMargine)
                        .frame(width: 220, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                TextField("", text: Binding(get: { c.valore }, set: { stato.modificaCampo(d.id, c.chiave, valore: $0) }))
                                    .textFieldStyle(.roundedBorder)
                                    .font(Tipo.tabellaCella)
                                if !c.chiave.unita.isEmpty {
                                    Text(c.chiave.unita).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                                }
                            }
                            if !c.estratto.isEmpty {
                                Text("«\(c.estratto)»").font(Tipo.chip).italic().foregroundColor(Colori.Incontri.citazione).lineLimit(2)
                            }
                        }
                        .padding(Misure.Analisi.cellaMargine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button("p. \(c.pagina)") {
                            pagina = c.pagina
                            scheda = .testo
                        }
                        .buttonStyle(StileSemplice())
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.Colonna.collegamento)
                        .frame(width: 70, alignment: .trailing)
                        .padding(.trailing, 9)
                    }
                }
            }
            usa(d)
            if ValoriDaDocumento.pertinente(d) { storicoPosizione(d) }
        }
    }

    /// Estratti conto: il valore letto entra nello storico della posizione, con un clic.
    private func storicoPosizione(_ d: Documento) -> some View {
        let candidate = ValoriDaDocumento.candidate(d, tra: stato.posizioni)
        let probabile = ValoriDaDocumento.posizioneProbabile(d, tra: stato.posizioni)
        let scelta = candidate.first { $0.id == posizioneValore } ?? probabile ?? candidate.first
        let valore = ValoriDaDocumento.valore(d)
        let fatto = valore.flatMap { v in scelta.map { ValoriDaDocumento.registrato(v, in: $0) } } ?? false
        return VStack(alignment: .leading, spacing: 8) {
            Text("NELLO STORICO DELLA POSIZIONE").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Strumenti.occhiello)
            if candidate.isEmpty {
                Text("Il cliente non ha posizioni in essere a cui aggiungere il valore: creala con «Crea la posizione in essere».")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
            } else {
                HStack(spacing: 10) {
                    Picker("", selection: Binding(get: { scelta?.id ?? "" }, set: { posizioneValore = $0 })) {
                        ForEach(candidate) { p in Text("\(p.nome) · \(p.canale.nomeBreve)").tag(p.id) }
                    }
                    .labelsHidden()
                    .frame(width: 280)
                    if let v = valore {
                        Text("\(Formati.euro(v.valore)) al \(Formati.dataEstesa.string(from: v.data))" + (v.versato.map { " · versato \(Formati.euro($0))" } ?? ""))
                            .font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                    }
                    Spacer(minLength: 0)
                    if fatto, let p = scelta {
                        Button("✓ Nello storico di «\(p.nome)» ↗") { stato.apriPosizione(p) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
                    } else {
                        Button("Registra il valore") { if let p = scelta { stato.registraValore(daDocumento: d.id, posizione: p.id) } }
                            .buttonStyle(StileBlu())
                            .disabled(valore == nil || scelta == nil || stato.solaLettura)
                            .opacity(valore == nil ? 0.5 : 1)
                    }
                }
                Text(valore == nil
                     ? "Conferma il controvalore e la data del valore (e, se c'è, il totale versato): poi il valore entra nello storico e nell'andamento della posizione."
                     : probabile?.id == scelta?.id && probabile != nil
                        ? "Posizione riconosciuta \(d.posizioneId != nil ? "dal collegamento" : "dal numero di contratto o dal nome"). Un valore più recente di quello attuale lo sostituisce; uno più vecchio va tra i valori passati."
                        : "Scegli la posizione. Un valore più recente di quello attuale lo sostituisce; uno più vecchio va tra i valori passati.")
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).fill(Gradienti.kpi))
        .overlay(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).strokeBorder(Colori.Analisi.kpiBordo, lineWidth: 1))
        .onChange(of: d.id) { _ in posizioneValore = nil }
    }

    private func usa(_ d: Documento) -> some View {
        let confermati = d.campi.filter(\.confermato).count
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CANALE E AREA").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Strumenti.occhiello)
                SegmentiAnalisi(opzioni: [(Canale.alleanza, "Alleanza"), (.indipendente, "Indipendente")], selezione: $canale)
                Picker("", selection: $area) {
                    ForEach(AreaPosizione.allCases.filter { $0 != .immobili && $0 != .debiti }) { Text($0.nome).tag($0) }
                }
                .labelsHidden()
            }
            .frame(width: 240)
            .onAppear { proponiCanaleEArea(d) }
            .onChange(of: d.id) { _ in proponiCanaleEArea(d) }
            VStack(alignment: .leading, spacing: 8) {
                Text("USA I \(confermati) DATI CONFERMATI").font(Tipo.incontroOcchiello).tracking(0.8).foregroundColor(Colori.Strumenti.occhiello)
                HStack(spacing: 8) {
                    if let pid = d.prodottoId, let p = stato.prodotto(pid) {
                        Button("Scheda «\(p.nome)» ↗") {
                            stato.prodottoSelezionato = pid
                            stato.apri(.prodotti)
                        }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
                    } else {
                        Button("Crea la scheda prodotto") { stato.creaProdotto(da: d.id, canale: canale, area: area) }
                            .buttonStyle(StileBlu())
                            .disabled(confermati == 0)
                    }
                    if let pos = d.posizioneId, let p = stato.posizioni.first(where: { $0.id == pos }) {
                        Button("Posizione «\(p.nome)» ↗") { stato.apriPosizione(p) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
                    } else {
                        Button("Crea la posizione in essere") { stato.creaPosizione(da: d.id, canale: canale, area: area) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
                            .disabled(confermati == 0)
                    }
                }
                Text("Il KID diventa di solito una scheda prodotto; una polizza o un estratto conto una posizione del cliente. I dati restano da completare dove il documento non li riporta.")
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).fill(Gradienti.kpi))
        .overlay(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).strokeBorder(Colori.Analisi.kpiBordo, lineWidth: 1))
    }

    private func proponiCanaleEArea(_ d: Documento) {
        let testo = (d.campi.map(\.valore) + [d.titolo]).joined(separator: " ").lowercased()
        canale = testo.contains("alleanza") ? .alleanza : .indipendente
        if testo.contains("pension") || testo.contains("previdenz") { area = .previdenza }
        else if d.campo(.capitaleAssicurato) != nil || testo.contains("infortun") || testo.contains("caso morte") { area = .protezione }
        else if testo.contains("rivalutabil") || testo.contains("risparmio") { area = .risparmio }
        else { area = .investimento }
    }

    // MARK: - Testo letto

    @ViewBuilder private func testo(_ d: Documento) -> some View {
        let pagine = stato.testoDocumento(d)
        if pagine.isEmpty {
            Text("Il testo non è ancora disponibile.").font(Tipo.strumentoTesto).foregroundColor(Colori.Analisi.kpiNota)
        } else {
            let n = min(max(pagina, 1), pagine.count)
            HStack {
                Stepper(value: $pagina, in: 1...pagine.count) {
                    Text("Pagina \(n) di \(pagine.count)").font(Tipo.pannelloAnalisi).foregroundColor(Colori.Analisi.pannelloTitolo)
                }
                Spacer()
                let qui = d.campi.filter { $0.pagina == n }.map(\.chiave.nome)
                if !qui.isEmpty {
                    Text("Su questa pagina: \(qui.joined(separator: ", "))").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
                }
            }
            Text(pagine[n - 1].isEmpty ? "(pagina vuota)" : pagine[n - 1])
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Colori.Analisi.tabellaTesto)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .overlay(Rectangle().strokeBorder(Colori.Analisi.kpiBordo, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
    }
}
