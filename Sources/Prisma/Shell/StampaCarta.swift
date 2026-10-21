import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Dalla carta al PDF: ogni pagina è la stessa vista dell'anteprima, disegnata in un contesto PDF
/// (testo vettoriale, selezionabile e ricercabile). Tutto sul Mac.
enum StampaCarta {
    @MainActor
    static func pdf(_ contenuto: ContenutoProspetto) -> Data? {
        let pagine = ImpaginatoreProspetto.pagine(contenuto)
        let dati = NSMutableData()
        guard let consumatore = CGDataConsumer(data: dati as CFMutableData) else { return nil }
        var riquadro = CGRect(origin: .zero, size: Misure.Carta.pagina)
        let info: [String: Any] = [
            kCGPDFContextTitle as String: "\(contenuto.titolo) · \(contenuto.cliente)",
            kCGPDFContextCreator as String: "Prisma",
            kCGPDFContextSubject as String: contenuto.genere,
        ]
        guard let contesto = CGContext(consumer: consumatore, mediaBox: &riquadro, info as CFDictionary) else { return nil }
        for (i, blocchi) in pagine.enumerated() {
            let renderer = ImageRenderer(content: PaginaCarta(contenuto: contenuto, blocchi: blocchi, numero: i + 1,
                                                              totale: pagine.count))
            renderer.proposedSize = ProposedViewSize(Misure.Carta.pagina)
            contesto.beginPDFPage(nil)
            renderer.render { _, disegna in disegna(contesto) }
            contesto.endPDFPage()
        }
        contesto.closePDF()
        return dati.length > 0 ? dati as Data : nil
    }

    /// "Prospetto · Giulia Rossi · Piano previdenziale integrativo · 2026-10-21.pdf"
    static func nomeFile(_ c: ContenutoProspetto) -> String {
        let data = Formati.formato("yyyy-MM-dd").string(from: c.data)
        let pulito = "\(c.perCliente ? "Report" : "Prospetto") · \(c.cliente) · \(c.titolo) · \(data)"
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

    @MainActor
    static func stampa(_ dati: Data) {
        guard let documento = PDFDocument(data: dati) else { return }
        let info = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        info.paperSize = Misure.Carta.pagina
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        info.orientation = .portrait
        documento.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: false)?.run()
    }

    /// Testo delle pagine di un PDF (per Eve e per la scheda Testo dei Documenti).
    static func testo(_ dati: Data) -> [String] {
        guard let d = PDFDocument(data: dati) else { return [] }
        return (0..<d.pageCount).map { d.page(at: $0)?.string ?? "" }
    }
}
