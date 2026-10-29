#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
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
    /// `ipotesi`: i dati da completare del cliente (completezza dei dati), dichiarati in una pagina del prospetto
    /// e in una slide del report; `percentuale`: la completezza dei dati, scritta nella pagina del prospetto.
    init(_ t: TestiCheckUp, report: Bool, commento: String? = nil, ipotesi: [VoceCompletezza] = [], percentuale: Int? = nil) {
        titolo = TestiCheckUp.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportCheckUp.pagine(t, commento: commento, ipotesi: ipotesi)
            : ProspettoCheckUp.pagine(t, ipotesi: ipotesi, percentuale: percentuale)
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
    /// `prodotti`: le schede del catalogo, per periodo raccomandato, penali e RIY dichiarato dell'incidenza come nel KID.
    init(_ t: TestiCosti, report: Bool, commento: String? = nil, prodotti: [Prodotto] = []) {
        titolo = TestiCosti.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportCosti.pagine(t, commento: commento, prodotti: prodotti) : ProspettoCosti.pagine(t, prodotti: prodotti)
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
    /// `ipotesi` e `percentuale`: la completezza dei dati, come nel check-up.
    init(_ t: TestiProtezione, report: Bool, commento: String? = nil, ipotesi: [VoceCompletezza] = [], percentuale: Int? = nil) {
        titolo = TestiProtezione.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportProtezione.pagine(t, commento: commento, ipotesi: ipotesi)
            : ProspettoProtezione.pagine(t, ipotesi: ipotesi, percentuale: percentuale)
        tipo = report ? .report : .prospetto
    }

    /// Il prospetto (A4 verticale) o il report (A4 orizzontale) del piano previdenziale.
    /// `ipotesi` e `percentuale`: la completezza dei dati, come nel check-up.
    init(_ t: TestiPrevidenza, report: Bool, commento: String? = nil, ipotesi: [VoceCompletezza] = [], percentuale: Int? = nil) {
        titolo = TestiPrevidenza.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportPrevidenza.pagine(t, commento: commento, ipotesi: ipotesi)
            : ProspettoPrevidenza.pagine(t, ipotesi: ipotesi, percentuale: percentuale)
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
/// e ricercabile). Tutto sul Mac. Sempre in chiaro, anche con l'app in scuro: carta bianca, colori fissi.
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
            // Un pool per pagina: il grafo e le risorse temporanee di ogni pagina si liberano subito,
            // non alla fine dell'evento (un fascicolo ha decine di pagine e il Mac 8 GB)
            autoreleasepool {
                // Sempre chiaro, con le etichette dei canali da stampa: la carta non va mai in scuro
                let renderer = ImageRenderer(content: pagina.frame(width: d.formato.width, height: d.formato.height)
                    .environment(\.etichetteStampa, true)
                    .environment(\.colorScheme, .light))
                renderer.proposedSize = ProposedViewSize(d.formato)
                contesto.beginPDFPage(nil)
                #if os(macOS)
                // Anche i colori di AppKit si risolvono in chiaro, qualunque sia l'aspetto dell'app
                if let chiaro = NSAppearance(named: .aqua) {
                    chiaro.performAsCurrentDrawingAppearance { renderer.render { _, disegna in disegna(contesto) } }
                } else {
                    renderer.render { _, disegna in disegna(contesto) }
                }
                #elseif os(iOS)
                // Anche i colori di UIKit si risolvono in chiaro, qualunque sia l'aspetto dell'app
                UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                    renderer.render { _, disegna in disegna(contesto) }
                }
                #endif
                contesto.endPDFPage()
            }
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
        #if os(macOS)
        let pannello = NSSavePanel()
        pannello.allowedContentTypes = [.pdf]
        pannello.nameFieldStringValue = nome
        pannello.canCreateDirectories = true
        pannello.message = "Il PDF resta dove lo salvi: Prisma non lo invia a nessuno."
        if pannello.runModal() == .OK, let url = pannello.url {
            try? dati.write(to: url)
        }
        #elseif os(iOS)
        // Su iPhone e iPad: il foglio di condivisione (Salva su File, AirDrop…), da una copia temporanea.
        // Il salvataggio con `.fileExporter` nella vista arriva nel giro 2.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nome)
        guard (try? dati.write(to: url, options: [.atomic, .completeFileProtection])) != nil else { return }
        presenta(UIActivityViewController(activityItems: [url], applicationActivities: nil))
        #endif
    }

    #if os(iOS)
    /// Mostra un controller di UIKit sopra quello in primo piano della scena attiva (su iPad come fumetto al centro).
    @MainActor
    private static func presenta(_ controller: UIViewController) {
        let scena = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let finestra = scena?.windows.first(where: \.isKeyWindow) ?? scena?.windows.first,
              var sopra = finestra.rootViewController else { return }
        while let presentato = sopra.presentedViewController { sopra = presentato }
        if let fumetto = controller.popoverPresentationController {
            fumetto.sourceView = finestra
            fumetto.sourceRect = CGRect(x: finestra.bounds.midX, y: finestra.bounds.midY, width: 1, height: 1)
            fumetto.permittedArrowDirections = []
        }
        sopra.present(controller, animated: true)
    }
    #endif

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
        #if os(macOS)
        guard let documento = PDFDocument(data: dati) else { return }
        let info = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        info.paperSize = formato.width > formato.height ? CGSize(width: formato.height, height: formato.width) : formato
        info.orientation = formato.width > formato.height ? .landscape : .portrait
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        documento.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: true)?.run()
        #elseif os(iOS)
        // Su iPhone e iPad: la stampa di sistema (AirPrint); il PDF ha già il formato giusto
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.orientation = formato.width > formato.height ? .landscape : .portrait
        let stampante = UIPrintInteractionController.shared
        stampante.printInfo = info
        stampante.printingItem = dati
        stampante.present(animated: true, completionHandler: nil)
        #endif
    }

    /// Testo delle pagine di un PDF (per Eve e per la scheda Testo dei Documenti).
    static func testo(_ dati: Data) -> [String] {
        guard let d = PDFDocument(data: dati) else { return [] }
        return (0..<d.pageCount).map { d.page(at: $0)?.string ?? "" }
    }
}
