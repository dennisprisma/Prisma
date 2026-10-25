import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Un documento pronto per la stampa: le pagine (viste di dimensione fissa) e il loro formato.
/// Le stesse viste servono per l'anteprima a schermo e per il PDF.
struct DocumentoStampabile {
    let titolo: String
    let cliente: String
    /// "Prospetto" o "Report": compare nel nome del file e in Documenti.
    let genere: String
    let formato: CGSize
    let pagine: [AnyView]
    var tipo: Documento.Tipo = .prospetto

    /// Un prospetto di dettaglio impaginato su carta (posizione, confronto).
    init(_ contenuto: ContenutoProspetto) {
        let impaginate = ImpaginatoreProspetto.pagine(contenuto)
        titolo = contenuto.titolo
        cliente = contenuto.cliente
        genere = "Prospetto"
        formato = Misure.Carta.pagina
        pagine = impaginate.enumerated().map { i, blocchi in
            AnyView(PaginaCarta(contenuto: contenuto, blocchi: blocchi, numero: i + 1, totale: impaginate.count))
        }
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) di una valutazione.
    init(_ t: TestiValutazione, report: Bool) {
        titolo = t.prodotto.nome
        cliente = t.v.intestatari
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportValutazione.pagine(t) : ProspettoValutazione.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) del check-up del primo incontro.
    init(_ t: TestiCheckUp, report: Bool, commento: String? = nil) {
        titolo = TestiCheckUp.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportCheckUp.pagine(t, commento: commento) : ProspettoCheckUp.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) del patrimonio nel tempo.
    init(_ t: TestiPatrimonio, report: Bool, commento: String? = nil) {
        titolo = TestiPatrimonio.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportPatrimonio.pagine(t, commento: commento) : ProspettoPatrimonio.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) del passaggio generazionale.
    init(_ t: TestiSuccessione, report: Bool, commento: String? = nil) {
        titolo = TestiSuccessione.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportSuccessione.pagine(t, commento: commento) : ProspettoSuccessione.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) del costo degli investimenti.
    init(_ t: TestiCosti, report: Bool, commento: String? = nil) {
        titolo = TestiCosti.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportCosti.pagine(t, commento: commento) : ProspettoCosti.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) della prova di resistenza.
    init(_ t: TestiResistenza, report: Bool, commento: String? = nil) {
        titolo = TestiResistenza.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportResistenza.pagine(t, commento: commento) : ProspettoResistenza.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) del capitale in scadenza e della liquidità.
    init(_ t: TestiLiquidita, report: Bool, commento: String? = nil) {
        titolo = TestiLiquidita.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportLiquidita.pagine(t, commento: commento) : ProspettoLiquidita.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) del piano per un obiettivo.
    init(_ t: TestiObiettivo, report: Bool, commento: String? = nil) {
        titolo = t.o.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportObiettivo.pagine(t, commento: commento) : ProspettoObiettivo.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) della protezione della famiglia.
    init(_ t: TestiProtezione, report: Bool, commento: String? = nil) {
        titolo = TestiProtezione.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportProtezione.pagine(t, commento: commento) : ProspettoProtezione.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) del piano previdenziale.
    init(_ t: TestiPrevidenza, report: Bool, commento: String? = nil) {
        titolo = TestiPrevidenza.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportPrevidenza.pagine(t, commento: commento) : ProspettoPrevidenza.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) di una sostituzione o di un confronto.
    init(_ t: TestiSostituzione, report: Bool, commento: String? = nil) {
        titolo = t.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportSostituzione.pagine(t, commento: commento) : ProspettoSostituzione.pagine(t)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) del resoconto delle posizioni in essere.
    init(_ t: TestiResoconto, report: Bool, commento: String? = nil) {
        titolo = TestiResoconto.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportResoconto.pagine(t, commento: commento) : ProspettoResoconto.pagine(t)
        tipo = report ? .report : .prospetto
    }
}

/// Dalle viste al PDF: ogni pagina è disegnata in un contesto PDF (testo vettoriale, selezionabile
/// e ricercabile). Tutto sul Mac.
enum StampaCarta {
    @MainActor
    static func pdf(_ d: DocumentoStampabile) -> Data? {
        let dati = NSMutableData()
        guard let consumatore = CGDataConsumer(data: dati as CFMutableData) else { return nil }
        var riquadro = CGRect(origin: .zero, size: d.formato)
        let info: [String: Any] = [
            kCGPDFContextTitle as String: "\(d.titolo) · \(d.cliente)",
            kCGPDFContextCreator as String: "Prisma",
            kCGPDFContextAuthor as String: TestiValutazione.consulente,
            kCGPDFContextSubject as String: d.genere,
        ]
        guard let contesto = CGContext(consumer: consumatore, mediaBox: &riquadro, info as CFDictionary) else { return nil }
        for pagina in d.pagine {
            let renderer = ImageRenderer(content: pagina.frame(width: d.formato.width, height: d.formato.height))
            renderer.proposedSize = ProposedViewSize(d.formato)
            contesto.beginPDFPage(nil)
            renderer.render { _, disegna in disegna(contesto) }
            contesto.endPDFPage()
        }
        contesto.closePDF()
        return dati.length > 0 ? dati as Data : nil
    }

    @MainActor
    static func pdf(_ contenuto: ContenutoProspetto) -> Data? { pdf(DocumentoStampabile(contenuto)) }

    /// "Prospetto · Marco ed Elena Bianchi · Orizzonte Valore di Alleanza · 2026-10-22.pdf"
    static func nomeFile(_ d: DocumentoStampabile) -> String {
        let data = Formati.formato("yyyy-MM-dd").string(from: Date())
        let pulito = "\(d.genere) · \(d.cliente) · \(d.titolo) · \(data)"
            .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return pulito + ".pdf"
    }

    @MainActor
    static func salva(_ dati: Data, nome: String) {
        let pannello = NSSavePanel()
        pannello.allowedContentTypes = [.pdf]
        pannello.nameFieldStringValue = nome
        pannello.canCreateDirectories = true
        pannello.message = "Il PDF resta dove lo salvi: Prisma non lo invia a nessuno."
        if pannello.runModal() == .OK, let url = pannello.url {
            try? dati.write(to: url)
        }
    }

    /// Il PDF cifrato: per aprirlo serve la password. Quella del proprietario (che permette di togliere la
    /// protezione) è casuale e non si conserva: nessuno può modificare il documento.
    static func protetto(_ dati: Data, password: String) -> Data? {
        guard !password.isEmpty, let documento = PDFDocument(data: dati) else { return nil }
        return documento.dataRepresentation(options: [
            PDFDocumentWriteOption.userPasswordOption: password,
            PDFDocumentWriteOption.ownerPasswordOption: UUID().uuidString,
        ])
    }

    @MainActor
    static func stampa(_ dati: Data, formato: CGSize) {
        guard let documento = PDFDocument(data: dati) else { return }
        let info = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        info.paperSize = formato.width > formato.height ? CGSize(width: formato.height, height: formato.width) : formato
        info.orientation = formato.width > formato.height ? .landscape : .portrait
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        documento.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true)?.run()
    }

    /// Testo delle pagine di un PDF (per Eve e per la scheda Testo dei Documenti).
    static func testo(_ dati: Data) -> [String] {
        guard let d = PDFDocument(data: dati) else { return [] }
        return (0..<d.pageCount).map { d.page(at: $0)?.string ?? "" }
    }
}
