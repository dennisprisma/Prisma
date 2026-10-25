import AppKit
import SwiftUI

/// Modalità istantanea (`Prisma --istantanee <cartella>`): disegna le schermate principali
/// in PNG senza aprire finestre e senza toccare l'archivio. La usa il workflow di build
/// per pubblicare le anteprime a ogni modifica.
@MainActor
enum Istantanee {
    static let dimensione = CGSize(width: 1440, height: 900)
    /// Schermo più basso (MacBook con il dock di macOS e la barra dei menu): le scene che finiscono
    /// con "-schermo-basso" si disegnano a questa misura.
    static let dimensioneBassa = CGSize(width: 1280, height: 760)

    static let scene: [(nome: String, prepara: (StatoShell) -> Void)] = [
        ("1-scrivania", { _ in }),
        ("2-posizioni", { $0.apri(.posizioni) }),
        ("3-impostazioni-archivio", { s in
            s.apri(.impostazioni)
            s.schedaImpostazioni = .archivio
        }),
        ("4-finestra-non-ingrandita", { s in
            s.apri(.prodotti)
            s.alternaIngrandimento(.prodotti)
        }),
        ("5-clienti-panoramica", { $0.apri(.clienti) }),
        ("6-clienti-famiglia", { s in
            s.clienteAttivoId = "marco"
            s.schedaCliente = .famiglia
            s.apri(.clienti)
        }),
        ("7-clienti-profilo", { s in
            s.clienteAttivoId = "sofia"
            s.schedaCliente = .profilo
            s.apri(.clienti)
        }),
        ("8-posizioni-dettaglio", { s in
            s.posizioneInDettaglio = "pos-giulia-etf-azionario-globale"
            s.apri(.posizioni)
        }),
        ("9-posizioni-marco", { s in
            s.clienteAttivoId = "marco"
            s.apri(.posizioni)
        }),
        ("10-posizioni-copertura", { s in
            s.clienteAttivoId = "marco"
            s.posizioneInDettaglio = "pos-marco-infortuni-famiglia"
            s.apri(.posizioni)
        }),
        ("11-agenda", { s in
            s.appuntamentoSelezionato = "event-marco"
            s.apri(.agenda)
        }),
        ("12-agenda-mese-scadenza", { s in
            if let d = s.posizioni.first(where: { $0.id == "pos-marco-infortuni-famiglia" })?.scadenza {
                s.giornoAgenda = Calendar.current.startOfDay(for: d)
            }
            s.vistaAgenda = .mese
            s.apri(.agenda)
        }),
        ("13-attivita", { s in
            s.attivitaSelezionata = "task-casa"
            s.apri(.attivita)
        }),
        ("14-simulazioni", { s in
            if let p = s.posizioni.first(where: { $0.id == "pos-giulia-etf-azionario-globale" }) { s.simula(p) }
        }),
        ("15-simulazioni-scenari", { s in
            s.schedaSimulazioni = .scenari
            s.apri(.simulazioni)
        }),
        ("16-confronti", { s in
            s.clienteAttivoId = "marco"
            s.apri(.confronti)
        }),
        ("17-analisi360", { $0.apri(.analisi360) }),
        ("20-clienti-bisogni", { s in
            s.clienteAttivoId = "marco"
            s.schedaCliente = .bisogni
            s.apri(.clienti)
        }),
        ("21-incontri-ascolto", { s in
            s.clienteAttivoId = "giulia"
            s.incontroAperto = "incontro-giulia-analisi"
            s.schedaIncontro = .ascolto
            s.apri(.incontri)
        }),
        ("22-incontri-passi", { s in
            s.clienteAttivoId = "giulia"
            if var i = s.incontro("incontro-giulia-analisi") {
                // Si riapre l'incontro di prova per mostrare le proposte ricavate dagli appunti
                i.stato = .preparazione
                s.salvaIncontro(i)
                s.estraiProposte(i)
            }
            s.incontroAperto = "incontro-giulia-analisi"
            s.schedaIncontro = .passi
            s.apri(.incontri)
        }),
        ("23-prodotti", { s in
            s.prodottoSelezionato = "prodotto-previdenza-pip"
            s.apri(.prodotti)
        }),
        ("24-obiettivi", { s in
            s.clienteAttivoId = "giulia"
            s.obiettivoSelezionato = "obiettivo-giulia-casa"
            s.apri(.obiettivi)
        }),
        ("27-prospetto-proposta", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.posizione("pos-giulia-piano-previdenziale-integrativo"))
        }),
        ("28-resoconto-prospetto", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.resoconto(report: false))
        }),
        ("33-resoconto-report", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.resoconto(report: true))
        }),
        ("29-prospetto-confronto", { s in
            s.clienteAttivoId = "marco"
            if let c = s.confrontoPredefinito() { s.apriProspetto(c) }
        }),
        ("32-prodotti-condizioni", { s in
            s.prodottoSelezionato = "prodotto-orizzonte-valore"
            s.apri(.prodotti)
        }),
        ("30-valutazione-prospetto", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.valutazione("val-marco-orizzonte", report: false))
        }),
        ("31-valutazione-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.valutazione("val-marco-orizzonte", report: true))
        }),
        ("34-sostituzione-prospetto", { s in
            s.clienteAttivoId = "sofia"
            s.apriProspetto(.sostituzione("", "", report: false))
        }),
        ("35-sostituzione-report", { s in
            s.clienteAttivoId = "sofia"
            s.apriProspetto(.sostituzione("", "", report: true))
        }),
        ("36-previdenza-prospetto", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.previdenza(report: false))
        }),
        ("37-previdenza-report", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.previdenza(report: true))
        }),
        ("38-protezione-prospetto", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.protezione(report: false))
        }),
        ("39-protezione-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.protezione(report: true))
        }),
        ("40-obiettivo-prospetto", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.obiettivo("obiettivo-giulia-casa", report: false))
        }),
        ("41-obiettivo-report", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.obiettivo("obiettivo-giulia-casa", report: true))
        }),
        ("42-liquidita-prospetto", { s in
            s.clienteAttivoId = "sofia"
            s.apriProspetto(.liquidita(report: false))
        }),
        ("43-liquidita-report", { s in
            s.clienteAttivoId = "sofia"
            s.apriProspetto(.liquidita(report: true))
        }),
        ("44-checkup-prospetto", { s in
            s.clienteAttivoId = "andrea"
            s.apriProspetto(.checkUp(report: false))
        }),
        ("45-checkup-report", { s in
            s.clienteAttivoId = "andrea"
            s.apriProspetto(.checkUp(report: true))
        }),
        ("25-documenti-kid", { s in
            s.clienteAttivoId = "giulia"
            s.documentoSelezionato = "doc-giulia-kid"
            s.apri(.documenti)
        }),
        ("71-posizioni-resistenza", { s in
            // Marco, profilo moderato: la prova di resistenza sotto la ripartizione
            s.clienteAttivoId = "marco"
            s.apri(.posizioni)
        }),
        ("72-eve-resistenza", { s in
            s.clienteAttivoId = "marco"
            s.dati.impostazioni.eve.motore = .sintesi
            s.chiediEve(SpuntoEve.resistenza.domanda, spunto: .resistenza)
            s.apri(.eve)
        }),
        ("73-resistenza-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.resistenza(report: true))
        }),
        ("74-posizioni-costi", { s in
            // Giulia: il dossier scorre fino al pannello dei costi
            s.clienteAttivoId = "giulia"
            s.apri(.posizioni)
            s.ancoraPosizioni = "costi"
        }),
        ("75-costi-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.costi(report: true))
        }),
        ("76-posizioni-successione", { s in
            // Giulia: convivente senza tutele e polizza agli «eredi legittimi»
            s.clienteAttivoId = "giulia"
            s.apri(.posizioni)
            s.ancoraPosizioni = "successione"
        }),
        ("77-successione-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.successione(report: true))
        }),
        ("78-portafoglio-da-sistemare", { s in
            s.portafoglio = true
            s.apri(.posizioni)
            s.ancoraPosizioni = "attenzioni"
        }),
        ("79-posizioni-patrimonio", { s in
            // Marco: il patrimonio nel tempo, com'è oggi e con la proposta aperta
            s.clienteAttivoId = "marco"
            s.apri(.posizioni)
            s.ancoraPosizioni = "patrimonio"
        }),
        ("80-patrimonio-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.patrimonio(report: true))
        }),
        ("70-modo-cliente", { s in
            // Lo schermo girato verso Marco: solo il suo dossier, niente degli altri clienti
            s.clienteAttivoId = "marco"
            s.entraModoCliente()
            s.apri(.posizioni)
        }),
        ("69-riesame-prospetto", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.riesame)
        }),
        ("68-documenti-estratto", { s in
            // Estratto conto confermato: il valore pronto per lo storico del piano di risparmio
            s.clienteAttivoId = "giulia"
            s.documentoSelezionato = "doc-giulia-estratto"
            if let d = s.documento("doc-giulia-estratto") { for c in d.campi { s.confermaCampo(d.id, c.chiave, true) } }
            s.apri(.documenti)
        }),
        ("26-documenti-polizza", { s in
            s.clienteAttivoId = "marco"
            s.documentoSelezionato = "doc-marco-polizza"
            s.apri(.documenti)
        }),
        ("19-eve", { s in
            s.dati.impostazioni.eve.motore = .sintesi
            s.clienteAttivoId = "giulia"
            s.chiediEve(SpuntoEve.incontro.domanda, spunto: .incontro)
            s.apri(.eve)
        }),
        ("48-report-commento", { s in
            s.dati.impostazioni.eve.motore = .sintesi
            s.clienteAttivoId = "giulia"
            s.prospetto = .checkUp(report: true)
            s.scriviCommentoConEve(.checkUp(report: true))
            s.apri(.presentazioni)
        }),
        ("50-eve-proposte", { s in
            s.dati.impostazioni.eve.motore = .sintesi
            s.clienteAttivoId = "giulia"
            s.chiediEve(SpuntoEve.proposte.domanda, spunto: .proposte)
            s.apri(.eve)
        }),
        ("49-eve-documento", { s in
            s.dati.impostazioni.eve.motore = .sintesi
            s.spiegaDocumentoConEve("doc-marco-polizza")
        }),
        ("46-eve-pensione", { s in
            s.dati.impostazioni.eve.motore = .sintesi
            s.clienteAttivoId = "marco"
            s.prospetto = .previdenza(report: false)
            s.chiediEveDelDocumento(.previdenza(report: false))
        }),
        ("47-eve-checkup", { s in
            s.dati.impostazioni.eve.motore = .sintesi
            s.clienteAttivoId = "giulia"
            s.chiediEve(SpuntoEve.checkUp.domanda, spunto: .checkUp)
            s.apri(.eve)
        }),
        ("53-ricerca", { s in
            s.testoRicerca = "marco"
            s.cercaOvunque()
        }),
        ("54-ricerca-documento", { s in
            s.testoRicerca = "scopo investimento"
            s.cercaOvunque()
        }),
        ("55-spazio-incontro", { s in
            s.area = ShellView.area(per: dimensione, dockNascosto: false)
            s.clienteAttivoId = "marco"
            s.apriSpazio(SpazioLavoro.predefiniti[0])
        }),
        ("57-spazio-analisi", { s in
            s.area = ShellView.area(per: dimensione, dockNascosto: false)
            s.clienteAttivoId = "marco"
            s.apriSpazio(SpazioLavoro.predefiniti[1])
        }),
        ("58-spazio-giornata", { s in
            s.area = ShellView.area(per: dimensione, dockNascosto: false)
            s.apriSpazio(SpazioLavoro.predefiniti[2])
        }),
        ("56-spazi", { s in
            s.area = ShellView.area(per: dimensione, dockNascosto: false)
            s.dati.spazi = [SpazioLavoro(nome: "Revisione annuale", finestre: [.destra(.documenti), .sinistra(.posizioni)])]
            s.apri(.agenda)
            s.pannelloSpazi = true
        }),
        ("60-note", { s in
            s.scegliNota("nota-giulia")
            s.apri(.note)
        }),
        ("61-clienti-note", { s in
            s.clienteAttivoId = "marco"
            s.schedaCliente = .note
            s.apri(.clienti)
        }),
        ("62-notifiche", { s in
            if let i = s.dati.posizioni.firstIndex(where: { $0.stato == .inEssere && $0.canale == .alleanza }) {
                s.dati.posizioni[i].scadenza = Calendar.current.date(byAdding: .day, value: 12, to: Calendar.current.startOfDay(for: Date()))
            }
            s.alternaNotifiche()
        }),
        ("63-benvenuto", { s in
            s.apri(.clienti)
            s.blocca()
        }),
        ("64-app-aperte", { s in
            s.apri(.agenda)
            s.apri(.note)
            s.apri(.clienti)
            s.riduci(.agenda)
            s.pannelloAppAperte = true
        }),
        ("65-portafoglio", { s in
            s.portafoglio = true
            s.apri(.posizioni)
        }),
        ("66-prospetto-portafoglio", { s in
            s.apriProspetto(.portafoglio)
        }),
        ("67-eve-portafoglio", { s in
            s.dati.impostazioni.eve.motore = .sintesi
            s.evePortafoglio = true
            s.chiediEvePortafoglio(SpuntoPortafoglio.quadro.domanda, spunto: .quadro)
            s.chiediEvePortafoglio(SpuntoPortafoglio.settimana.domanda, spunto: .settimana)
            s.apri(.eve)
        }),
        ("51-scrivania-schermo-basso", { _ in }),
        ("52-eve-schermo-basso", { s in
            s.clienteAttivoId = "giulia"
            s.apri(.eve)
        }),
        ("18-analisi360-protezione", { s in
            s.clienteAttivoId = "marco"
            s.areaAnalisi = .protezione
            s.apri(.analisi360)
        }),
    ]

    /// Metodi di disegno, in ordine di preferenza sul server di build:
    /// - "finestra": NSHostingView in una finestra fuori schermo + cacheDisplay (senza Metal)
    /// - "livello": come sopra, ma con CALayer.render(in:)
    /// - "renderer": ImageRenderer di SwiftUI (richiede Metal)
    static func genera(in cartella: URL, metodo: String, solo: Set<String>? = nil) -> Int32 {
        _ = NSApplication.shared
        do {
            try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        } catch {
            print("ERRORE: cartella delle istantanee non creata: \(error.localizedDescription)")
            return 1
        }
        for scena in scene where solo?.contains(scena.nome) ?? true {
            let stato = StatoShell(persistente: false)
            let misura = scena.nome.hasSuffix("-schermo-basso") ? dimensioneBassa : dimensione
            scena.prepara(stato)
            stato.area = ShellView.area(per: misura, dockNascosto: !stato.finestreVisibili.isEmpty)
            let vista = ShellView()
                .environmentObject(stato)
                .environment(\.modoIstantanea, true)
                .frame(width: misura.width, height: misura.height)
            let png: Data?
            switch metodo {
            case "renderer": png = conRenderer(vista)
            case "livello": png = conFinestra(vista, livello: true, misura: misura)
            default: png = conFinestra(vista, livello: false, misura: misura)
            }
            guard let png else {
                print("ERRORE: istantanea \(scena.nome) non disegnata (metodo \(metodo))")
                return 1
            }
            do {
                try png.write(to: cartella.appendingPathComponent("\(scena.nome).png"))
                print("OK: \(scena.nome).png (metodo \(metodo))")
            } catch {
                print("ERRORE: \(scena.nome).png non salvata: \(error.localizedDescription)")
                return 1
            }
        }
        return 0
    }

    private static func conRenderer<V: View>(_ vista: V) -> Data? {
        let renderer = ImageRenderer(content: vista)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return nil }
        return pngVerificato(NSBitmapImageRep(cgImage: cg))
    }

    private static func conFinestra<V: View>(_ vista: V, livello: Bool, misura: CGSize) -> Data? {
        let host = NSHostingView(rootView: vista)
        host.frame = NSRect(origin: .zero, size: misura)
        let finestra = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        finestra.contentView = host
        finestra.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        finestra.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        defer { finestra.orderOut(nil) }

        if livello {
            let scala: CGFloat = 2
            guard let strato = host.layer,
                  let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                             pixelsWide: Int(misura.width * scala), pixelsHigh: Int(misura.height * scala),
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let contesto = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
            let cg = contesto.cgContext
            cg.scaleBy(x: scala, y: scala)
            if !host.isFlipped {
                strato.render(in: cg)
            } else {
                cg.translateBy(x: 0, y: misura.height)
                cg.scaleBy(x: 1, y: -1)
                strato.render(in: cg)
            }
            return pngVerificato(rep)
        }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        return pngVerificato(rep)
    }

    /// Scarta le immagini vuote (tutte dello stesso colore): vuol dire che il metodo non disegna.
    private static func pngVerificato(_ rep: NSBitmapImageRep) -> Data? {
        let campioni = [(0.1, 0.1), (0.5, 0.5), (0.9, 0.2), (0.3, 0.8), (0.7, 0.95), (0.5, 0.02)]
        let colori = campioni.compactMap { c in
            rep.colorAt(x: Int(Double(rep.pixelsWide) * c.0), y: Int(Double(rep.pixelsHigh) * c.1))?.usingColorSpace(.deviceRGB)
        }
        let diversi = Set(colori.map { "\(Int($0.redComponent * 255))-\(Int($0.greenComponent * 255))-\(Int($0.blueComponent * 255))" })
        guard diversi.count > 1 else {
            print("ATTENZIONE: immagine vuota")
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}

private struct ChiaveModoIstantanea: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// true quando la vista viene disegnata per un'istantanea (niente viste AppKit).
    var modoIstantanea: Bool {
        get { self[ChiaveModoIstantanea.self] }
        set { self[ChiaveModoIstantanea.self] = newValue }
    }
}
