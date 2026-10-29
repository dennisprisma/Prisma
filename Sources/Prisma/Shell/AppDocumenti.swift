import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// App Documenti (.os-app-documents), rifatta nel giro 5 come un Finder con l'Anteprima: a sinistra le raccolte, i tipi
/// e i canali; al centro l'elenco a gruppi con lo stato di ogni documento; a destra il foglio accanto a una scheda
/// leggibile, con le azioni in alto e il confronto «Nel documento / In Prisma». Tutto si legge sul Mac (PDFKit, Vision).
struct AppDocumenti: View {
    @EnvironmentObject var stato: StatoShell
    /// La ricerca è della vista: scrivere non ridisegna le altre finestre.
    @State private var ricerca = ""
    @State private var sopra = false
    @State private var daEliminare: Documento?
    @State private var confermaEliminazione = false

    private var cliente: String { stato.clienteAttivoId }

    private var filtro: MotoreDocumenti.Filtro {
        var f = MotoreDocumenti.Filtro()
        f.raccolta = stato.vistaDocumenti.raccolta
        f.categoria = stato.vistaDocumenti.categoria
        f.canale = stato.vistaDocumenti.canale
        f.testo = ricerca
        return f
    }

    private var filtroAttivo: Bool {
        let v = stato.vistaDocumenti
        let conFiltri: Bool = v.raccolta != .tutti || v.categoria != nil || v.canale != nil
        let conRicerca: Bool = !ricerca.trimmingCharacters(in: .whitespaces).isEmpty
        return conFiltri || conRicerca
    }

    /// I gruppi dell'elenco. Il testo dei documenti si legge dal disco senza tenerlo in memoria, e solo se serve.
    private func raggruppa(_ voci: [MotoreDocumenti.Voce]) -> [MotoreDocumenti.Gruppo] {
        MotoreDocumenti.elenco(voci, filtro: filtro, pagine: { stato.testoDocumento($0, memorizza: false) })
    }

    var body: some View {
        let voci = stato.vociDocumenti(cliente)
        let gruppi = raggruppa(voci)
        let mostrate = gruppi.flatMap { $0.voci.map(\.voce) }
        // Il documento scelto se è tra quelli mostrati, altrimenti il primo: documentoSelezionato non si riscrive
        let scelta = mostrate.first { $0.id == stato.documentoSelezionato } ?? mostrate.first
        let nome = stato.clienteAttivo?.nome ?? "questo cliente"
        CorniceStrumento(
            notaStato: "Lettura sul Mac: PDFKit per il testo, Vision per le scansioni · nessun file lascia il computer",
            notaDestra: voci.count == 1 ? "1 documento di \(nome)" : "\(voci.count) documenti di \(nome)"
        ) {
            rail(voci)
        } contenuto: {
            if voci.isEmpty {
                VuotoDocumenti(nome: nome, importa: importa)
            } else {
                ColonneAffiancate(larghezza: Misure.ColonneStrumento.elenco) {
                    ElencoDocumenti(gruppi: gruppi, scelta: scelta?.id, totale: voci.count, ricerca: $ricerca,
                                    filtrato: filtroAttivo, importa: importa, mostraTutti: mostraTutti, elimina: chiedi)
                } flessibile: {
                    if let v = scelta {
                        DettaglioDocumento(voce: v, chiediEliminazione: chiedi)
                    } else {
                        Text("Nessun documento con questi filtri")
                            .font(Tema.Testo.corpo)
                            .foregroundColor(Tema.Colore.inchiostroSecondario)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $sopra) { fornitori in
            let raccolta = RaccoltaRilascio()
            let gruppo = DispatchGroup()
            for f in fornitori {
                gruppo.enter()
                _ = f.loadObject(ofClass: URL.self) { url, _ in
                    DispatchQueue.main.async {
                        if let url { raccolta.urls.append(url) }
                        gruppo.leave()
                    }
                }
            }
            gruppo.notify(queue: .main) {
                if !raccolta.urls.isEmpty { stato.aggiungiDocumenti(raccolta.urls) }
            }
            return true
        }
        .overlay {
            if sopra { RilascioDocumenti(nome: nome) }
        }
        .onAppear { allinea() }
        .onChange(of: stato.documentoSelezionato) { _ in
            stato.vistaDocumenti.pagina = 1
            stato.vistaDocumenti.evidenzia = nil
            allinea()
        }
        .alert("Eliminare il documento?", isPresented: $confermaEliminazione, presenting: daEliminare) { d in
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) { stato.eliminaDocumento(d.id) }
        } message: { _ in
            Text("Il file viene tolto dall'archivio di Prisma. Schede, posizioni e lo storico dei dati portati in Prisma restano. Se serve, lo recuperi da un backup.")
        }
    }

    /// Un documento scelto da fuori (⌘K, notifiche, Eve, Prodotti) che i filtri nasconderebbero: i filtri tornano a
    /// «Tutti» e la ricerca si svuota, così si vede nell'elenco.
    private func allinea() {
        guard let id = stato.documentoSelezionato, let d = stato.documento(id), d.clienteId == cliente else { return }
        let visibili = raggruppa(stato.vociDocumenti(cliente)).flatMap { $0.voci.map(\.id) }
        guard !visibili.contains(id) else { return }
        mostraTutti()
    }

    private func mostraTutti() {
        stato.vistaDocumenti.raccolta = .tutti
        stato.vistaDocumenti.categoria = nil
        stato.vistaDocumenti.canale = nil
        ricerca = ""
    }

    private func chiedi(_ d: Documento) {
        daEliminare = d
        confermaEliminazione = true
    }

    private func importa() {
        let pannello = NSOpenPanel()
        pannello.allowedContentTypes = [.pdf, .png, .jpeg, .tiff, .heic]
        pannello.allowsMultipleSelection = true
        pannello.prompt = "Importa"
        pannello.message = "Scegli KID, polizze, estratti conto, documenti d'identità o questionari: vengono copiati nell'archivio di Prisma."
        if pannello.runModal() == .OK { stato.aggiungiDocumenti(pannello.urls) }
    }

    // MARK: - Barra laterale

    @ViewBuilder private func rail(_ voci: [MotoreDocumenti.Voce]) -> some View {
        let conti = MotoreDocumenti.conteggi(voci)
        let vista = stato.vistaDocumenti
        DossierRail()
        EtichettaRail(testo: "Raccolte")
        ForEach(RaccoltaDocumenti.allCases) { r in
            VoceNavigazione(titolo: r.nome, conteggio: conti.raccolte[r], attiva: vista.raccolta == r) {
                stato.vistaDocumenti.raccolta = r
            }
        }
        EtichettaRail(testo: "Tipi")
        VoceNavigazione(titolo: "Tutti i tipi", attiva: vista.categoria == nil) {
            stato.vistaDocumenti.categoria = nil
        }
        ForEach(CategoriaDocumento.ordine.filter { (conti.categorie[$0] ?? 0) > 0 }) { c in
            VoceNavigazione(titolo: c.breve, conteggio: conti.categorie[c], attiva: vista.categoria == c) {
                stato.vistaDocumenti.categoria = c
            }
        }
        EtichettaRail(testo: "Canale")
        ForEach(Canale.allCases) { c in
            // Un secondo clic toglie il filtro
            VoceNavigazione(titolo: c.nomeBreve,
                            colore: c == .alleanza ? Tema.Colore.canaleAlleanza : Tema.Colore.canaleIndipendente,
                            conteggio: conti.canali[c], attiva: vista.canale == c) {
                stato.vistaDocumenti.canale = stato.vistaDocumenti.canale == c ? nil : c
            }
        }
        CollegatiRail(app: [.posizioni, .prodotti, .eve])
    }
}

/// Gli URL dei file rilasciati, raccolti sul thread principale prima di aggiungerli tutti insieme.
private final class RaccoltaRilascio {
    var urls: [URL] = []
}

// MARK: - Elenco

/// L'elenco dei documenti del cliente: ricerca e «+» in testata, gruppi per tipo, righe con stato e collegamento,
/// frecce ↑ ↓ e ⌫ da tastiera, piede con il conteggio.
struct ElencoDocumenti: View {
    @EnvironmentObject var stato: StatoShell
    let gruppi: [MotoreDocumenti.Gruppo]
    let scelta: String?
    let totale: Int
    @Binding var ricerca: String
    let filtrato: Bool
    let importa: () -> Void
    let mostraTutti: () -> Void
    let elimina: (Documento) -> Void

    var body: some View {
        let m = Tema.Misura.Documenti.self
        let mostrate = gruppi.flatMap(\.voci)
        VStack(spacing: 0) {
            HStack(spacing: Misure.ColonneStrumento.spazioTestata) {
                CampoRicerca(testo: $ricerca, segnaposto: "Cerca nei documenti")
                PulsanteIcona(simbolo: "plus", aiuto: "Aggiungi documenti (anche trascinandoli qui)", azione: importa)
            }
            .testataColonna()
            if mostrate.isEmpty {
                VStack(spacing: m.spazioNessuno) {
                    Text("Nessun documento con questi filtri")
                        .font(Tema.Testo.corpo)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .multilineTextAlignment(.center)
                    Button(action: mostraTutti) { Label("Mostra tutti", systemImage: "line.3.horizontal.decrease.circle") }
                        .buttonStyle(StileVetro())
                        .fixedSize()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(gruppi) { g in
                            TestataGruppoDocumenti(titolo: g.categoria.nome, conteggio: g.voci.count)
                            ForEach(g.voci) { t in riga(t) }
                        }
                    }
                    .padding(.vertical, Tema.Misura.Strumenti.margineElenco)
                }
                .focusable()
                .onMoveCommand { direzione in muovi(direzione, mostrate) }
                .onDeleteCommand {
                    if !stato.solaLettura, let v = mostrate.first(where: { $0.id == scelta }) { elimina(v.voce.documento) }
                }
            }
            Text(piede(mostrate.count))
                .font(Tema.Testo.didascalia)
                .foregroundColor(Colori.ColonneStrumento.piedeTesto)
                .lineLimit(1)
                .piedeColonna()
        }
    }

    private func piede(_ n: Int) -> String {
        if filtrato { return "\(n) di \(totale) \(totale == 1 ? "documento" : "documenti")" }
        return "\(n) \(n == 1 ? "documento" : "documenti") · trascina qui per aggiungerne"
    }

    private func riga(_ t: MotoreDocumenti.VoceTrovata) -> some View {
        let d = t.voce.documento
        let file = stato.urlDocumento(d).flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        return Button {
            stato.documentoSelezionato = d.id
        } label: {
            RigaDocumento(voce: t.voce, nelTesto: t.nelTesto, attiva: t.id == scelta,
                          daLeggere: MotoreDocumenti.appartiene(t.voce, a: .daLeggere))
        }
        .buttonStyle(StileSemplice())
        .contextMenu {
            Button("Apri in Anteprima") { if let file { NSWorkspace.shared.open(file) } }
                .disabled(file == nil)
            Button("Mostra nel Finder") { stato.mostraNelFinder(d) }
                .disabled(file == nil)
            Button("Rileggi") {
                TestiRinviati.scriviOra()
                stato.leggiDocumento(d.id)
            }
            .disabled(file == nil || d.tipo.creatoDaPrisma || stato.solaLettura || stato.documentiInLettura.contains(d.id))
            Button("Apri con Eve") {
                TestiRinviati.scriviOra()
                stato.spiegaDocumentoConEve(d.id)
            }
            .disabled(d.tipo.creatoDaPrisma || stato.eveInCorso || stato.documentiInLettura.contains(d.id))
            Divider()
            Button("Elimina…") { elimina(d) }
                .disabled(stato.solaLettura)
        }
        // Trascinato nel Finder o in Mail: il file del documento
        .onDrag { file.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider() }
    }

    private func muovi(_ direzione: MoveCommandDirection, _ elenco: [MotoreDocumenti.VoceTrovata]) {
        guard !elenco.isEmpty else { return }
        let i = elenco.firstIndex { $0.id == scelta } ?? 0
        switch direzione {
        case .up: stato.documentoSelezionato = elenco[max(i - 1, 0)].id
        case .down: stato.documentoSelezionato = elenco[min(i + 1, elenco.count - 1)].id
        default: break
        }
    }
}
