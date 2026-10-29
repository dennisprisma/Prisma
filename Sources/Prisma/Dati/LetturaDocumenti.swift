import AppKit
import Foundation
import ImageIO
import PDFKit
import Vision

/// Legge il testo dei documenti, tutto sul Mac:
/// - PDF con testo: PDFKit, pagina per pagina;
/// - PDF scansionati e immagini: riconoscimento del testo di Vision (italiano e inglese).
/// Una pagina alla volta, per non pesare sulla memoria del Mac.
enum LetturaDocumenti {
    static let estensioniAccettate = ["pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic"]
    /// Sotto questa soglia di caratteri una pagina PDF si considera scansionata.
    static let sogliaTesto = 40
    /// Separatore tra le pagine nel file di testo accanto al documento.
    static let separatorePagine = "\u{0C}"

    struct Esito {
        let pagine: [String]
        let pagineOCR: Int
    }

    static func leggi(_ url: URL) -> Esito? {
        if url.pathExtension.lowercased() == "pdf" {
            guard let pdf = PDFDocument(url: url) else { return nil }
            var pagine: [String] = []
            var ocr = 0
            for i in 0..<pdf.pageCount {
                autoreleasepool {
                    guard let pagina = pdf.page(at: i) else { pagine.append(""); return }
                    let testo = pagina.string ?? ""
                    if testo.trimmingCharacters(in: .whitespacesAndNewlines).count >= sogliaTesto {
                        pagine.append(testo)
                    } else {
                        let lato = pagina.bounds(for: .mediaBox).size
                        let immagine = pagina.thumbnail(of: NSSize(width: lato.width * 2, height: lato.height * 2), for: .mediaBox)
                        let riconosciuto = riconosci(immagine) ?? testo
                        if !riconosciuto.isEmpty { ocr += 1 }
                        pagine.append(riconosciuto)
                    }
                }
            }
            return Esito(pagine: pagine, pagineOCR: ocr)
        }
        guard let immagine = NSImage(contentsOf: url) else { return nil }
        return Esito(pagine: [riconosci(immagine) ?? ""], pagineOCR: 1)
    }

    /// Riconoscimento del testo di Vision, sul dispositivo.
    static func riconosci(_ immagine: NSImage) -> String? {
        guard let cg = immagine.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let richiesta = VNRecognizeTextRequest()
        richiesta.recognitionLevel = .accurate
        richiesta.usesLanguageCorrection = true
        richiesta.recognitionLanguages = ["it-IT", "en-US"]
        let gestore = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try gestore.perform([richiesta])
        } catch {
            return nil
        }
        let righe = (richiesta.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return righe.joined(separator: "\n")
    }

    static func numeroPagine(_ url: URL) -> Int {
        url.pathExtension.lowercased() == "pdf" ? (PDFDocument(url: url)?.pageCount ?? 0) : 1
    }

    /// Immagine ridotta per l'anteprima (lato massimo in pixel), letta con ImageIO senza decodificare l'originale.
    static func anteprima(_ url: URL, lato: Int = 2400) -> NSImage? {
        guard let sorgente = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opzioni: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: lato]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(sorgente, 0, opzioni as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}
