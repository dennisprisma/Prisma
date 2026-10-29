import AppKit
import PDFKit
import SwiftUI

/// L'anteprima di un documento nell'app Documenti: il foglio sul tavolo e, sotto, la barra delle pagine.
/// Tre casi: il PDF vero (`VistaPDF`, un solo `PDFDocument` aperto alla volta), l'immagine ridotta con ImageIO, oppure
/// (senza file o nelle istantanee) la pagina ricostruita dal testo letto. Il foglio è carta: bianco anche in scuro.
struct AnteprimaDocumento: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) private var modoIstantanea
    let documento: Documento

    private enum Foglio { case pdf(URL), immagine(URL), testo }

    /// Il file del documento, se c'è sul Mac.
    private var file: URL? {
        guard let url = stato.urlDocumento(documento), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    var body: some View {
        let m = Tema.Misura.Documenti.self
        let url = file
        let foglio: Foglio = {
            guard !modoIstantanea, let url else { return .testo }
            return url.pathExtension.lowercased() == "pdf" ? .pdf(url) : .immagine(url)
        }()
        let pagine = stato.testoDocumento(documento)
        let totale: Int = {
            switch foglio {
            case .pdf: return max(documento.pagine, pagine.count, 1)
            case .immagine: return 1
            case .testo: return max(pagine.count, 1)
            }
        }()
        let pagina = min(max(stato.vistaDocumenti.pagina, 1), totale)
        VStack(spacing: 0) {
            switch foglio {
            case .pdf(let u):
                VistaPDF(url: u,
                         pagina: Binding(get: { stato.vistaDocumenti.pagina }, set: { stato.vistaDocumenti.pagina = $0 }),
                         evidenzia: estrattoEvidenziato(pagina: nil))
            case .immagine(let u):
                ScrollView {
                    ImmagineDocumento(url: u)
                        .padding(m.margineTavolo)
                }
            case .testo:
                GeometryReader { geo in
                    ScrollView {
                        PaginaTestoDocumento(testo: pagina <= pagine.count ? pagine[pagina - 1] : "",
                                             estratto: estrattoEvidenziato(pagina: pagina),
                                             nota: notaFoglio(vuoto: pagine.isEmpty),
                                             larghezza: max(min(geo.size.width - 2 * m.margineTavolo, m.foglioMassimo), m.margineTavolo))
                            .padding(m.margineTavolo)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            barraPagine(pagina: pagina, totale: totale, url: url)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Tema.Colore.Strumenti.tavoloAlto, Tema.Colore.Strumenti.tavoloBasso],
                                   startPoint: .top, endPoint: .bottom))
    }

    /// La riga del documento da cui viene il dato da evidenziare (sulla pagina mostrata, per il foglio ricostruito).
    private func estrattoEvidenziato(pagina: Int?) -> String? {
        guard let chiave = stato.vistaDocumenti.evidenzia, let c = documento.campo(chiave), !c.estratto.isEmpty else { return nil }
        if let pagina, c.pagina != pagina { return nil }
        return c.estratto
    }

    private func notaFoglio(vuoto: Bool) -> String {
        if stato.documentiInLettura.contains(documento.id) { return "Prisma sta leggendo il testo sul Mac…" }
        if vuoto { return "Il testo di questo documento non è ancora disponibile." }
        return documento.file == nil ? "Documento di prova: pagina ricostruita dal testo" : "Pagina ricostruita dal testo letto"
    }

    private func barraPagine(pagina: Int, totale: Int, url: URL?) -> some View {
        let m = Tema.Misura.Documenti.self
        return HStack(spacing: m.spazioPagine) {
            Button { stato.vistaDocumenti.pagina = pagina - 1 } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(pagina <= 1 ? Tema.Colore.inchiostroTerziario : Tema.Colore.inchiostro)
            }
            .buttonStyle(StileSemplice())
            .disabled(pagina <= 1)
            .help("Pagina precedente")
            Text("Pagina \(pagina) di \(totale)")
                .font(Tema.Testo.didascalia)
                .monospacedDigit()
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
            Button { stato.vistaDocumenti.pagina = pagina + 1 } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(pagina >= totale ? Tema.Colore.inchiostroTerziario : Tema.Colore.inchiostro)
            }
            .buttonStyle(StileSemplice())
            .disabled(pagina >= totale)
            .help("Pagina successiva")
            if let url {
                Button("Apri in Anteprima") { NSWorkspace.shared.open(url) }
                    .buttonStyle(StileSemplice())
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Colori.Colonna.collegamento)
                    .help("Apre il file nell'app Anteprima del Mac")
            }
        }
        .padding(.horizontal, m.marginePagine)
        .frame(height: m.barraPagine)
        .vetro(.chip, forma: .capsula)
        .padding(.vertical, m.spazioPagine)
        .frame(maxWidth: .infinity)
    }
}

/// Un'immagine (foto o scansione) ridotta con ImageIO, letta una volta per file.
private struct ImmagineDocumento: View {
    let url: URL
    @State private var immagine: NSImage?

    var body: some View {
        Group {
            if let immagine {
                Image(nsImage: immagine)
                    .resizable()
                    .scaledToFit()
                    .ombraTema(Tema.Ombra.Strumenti.foglio)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: url) { immagine = LetturaDocumenti.anteprima(url) }
    }
}

/// La pagina ricostruita dal testo letto: foglio bianco in proporzione A4, il testo riga per riga e la riga da cui
/// viene il dato scelto evidenziata. Colori fissi: è carta anche in aspetto scuro.
struct PaginaTestoDocumento: View {
    let testo: String
    /// La riga del documento da evidenziare (`CampoEstratto.estratto`).
    let estratto: String?
    let nota: String
    let larghezza: CGFloat

    var body: some View {
        let m = Tema.Misura.Documenti.self
        let righe = testo.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: m.spazioRigheFoglio) {
            Text(nota)
                .font(Tema.Testo.Documenti.notaFoglio)
                .foregroundColor(Tema.Colore.Documenti.notaFoglio)
                .padding(.bottom, m.spazioNotaFoglio)
            ForEach(Array(righe.enumerated()), id: \.offset) { _, riga in
                Text(riga.isEmpty ? " " : riga)
                    .font(Tema.Testo.Documenti.testoFoglio)
                    .foregroundColor(Tema.Colore.Documenti.testoFoglio)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, m.margineRigaFoglio)
                    .background {
                        if Self.evidenziata(riga, estratto: estratto) {
                            FormaVetro.arrotondata(Tema.Raggio.Documenti.evidenza).fill(Tema.Colore.Documenti.evidenziaFoglio)
                        }
                    }
            }
        }
        .padding(m.margineFoglio)
        .frame(width: larghezza, alignment: .topLeading)
        .frame(minHeight: larghezza / m.rapportoA4, alignment: .top)
        .background { FormaVetro.arrotondata(Tema.Raggio.Documenti.foglio).fill(Tema.Colore.Documenti.foglio) }
        .ombraTema(Tema.Ombra.Strumenti.foglio)
        .environment(\.colorScheme, .light)
    }

    /// Una riga viene dall'estratto se, tolti gli spazi ai lati, ha almeno 6 caratteri ed è contenuta nell'estratto,
    /// oppure se contiene i primi 30 caratteri dell'estratto.
    static func evidenziata(_ riga: String, estratto: String?) -> Bool {
        guard let estratto else { return false }
        let e = estratto.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = riga.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty, !r.isEmpty else { return false }
        if r.count >= 6, e.contains(r) { return true }
        return r.contains(String(e.prefix(30)))
    }
}

/// Il PDF vero, in PDFKit: pagine una sotto l'altra sul tavolo, salto alla pagina scelta e la riga del dato
/// evidenziata (se il testo si trova: le pagine da scansione non hanno testo da cercare, e allora basta la pagina).
struct VistaPDF: NSViewRepresentable {
    let url: URL
    @Binding var pagina: Int
    /// La riga del documento da evidenziare (`CampoEstratto.estratto`).
    let evidenzia: String?

    final class Coordinatore: NSObject {
        var url: URL?
        var pagina: Binding<Int>
        var ultimaPagina = 0
        var ultimaEvidenza: String?
        /// Mentre Prisma sposta la vista, i cambi di pagina non tornano allo stato.
        var muove = false
        weak var vista: PDFView?

        init(pagina: Binding<Int>) {
            self.pagina = pagina
        }

        @objc func paginaCambiata(_ notifica: Notification) {
            guard !muove, let v = vista, let p = v.currentPage, let doc = v.document else { return }
            let n = doc.index(for: p) + 1
            guard n != ultimaPagina else { return }
            ultimaPagina = n
            let legame = pagina
            // Fuori dall'aggiornamento della vista
            DispatchQueue.main.async {
                if legame.wrappedValue != n { legame.wrappedValue = n }
            }
        }

        func mostra(_ pagina: Int, evidenzia: String?, in v: PDFView) {
            guard let doc = v.document, doc.pageCount > 0 else { return }
            let indice = min(max(pagina - 1, 0), doc.pageCount - 1)
            guard let pg = doc.page(at: indice) else { return }
            muove = true
            v.highlightedSelections = nil
            var trovata: PDFSelection?
            if let e = evidenzia?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
                trovata = doc.findString(String(e.prefix(40)), withOptions: .caseInsensitive).first { $0.pages.contains(pg) }
            }
            if let s = trovata {
                s.color = NSColor(Tema.Colore.Documenti.evidenziaPDF)
                v.highlightedSelections = [s]
                v.go(to: s)
            } else {
                v.go(to: pg)
            }
            DispatchQueue.main.async { self.muove = false }
        }
    }

    func makeCoordinator() -> Coordinatore { Coordinatore(pagina: $pagina) }

    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displaysPageBreaks = true
        // Si vede il tavolo dell'app attorno ai fogli
        v.backgroundColor = .clear
        context.coordinator.vista = v
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinatore.paginaCambiata(_:)),
                                               name: .PDFViewPageChanged, object: v)
        return v
    }

    func updateNSView(_ v: PDFView, context: Context) {
        let c = context.coordinator
        c.pagina = $pagina
        // Il documento si apre solo quando cambia il file: uno alla volta
        if c.url != url {
            c.url = url
            c.muove = true
            v.document = PDFDocument(url: url)
            c.ultimaPagina = 0
            c.ultimaEvidenza = nil
        }
        if c.ultimaPagina != pagina || c.ultimaEvidenza != evidenzia {
            c.ultimaPagina = pagina
            c.ultimaEvidenza = evidenzia
            c.mostra(pagina, evidenzia: evidenzia, in: v)
        } else if c.muove {
            DispatchQueue.main.async { c.muove = false }
        }
    }

    static func dismantleNSView(_ v: PDFView, coordinator: Coordinatore) {
        NotificationCenter.default.removeObserver(coordinator)
        v.document = nil
    }
}
