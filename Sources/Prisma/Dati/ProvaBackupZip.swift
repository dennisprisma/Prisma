import CoreGraphics
import Foundation
import ImageIO

// Lettore e scrittore zip dentro `Prisma --prova-backup` (Mac e iPhone/iPad), più le due prove del simulatore:
// - `--prepara-campione-backup`: l'app scrive in Documents/campione/Prisma un archivio di prova completo;
// - `--prova-backup-ditto <zip>`: lo zip di quella cartella, fatto da ditto sul runner del Mac, si cifra, si decifra,
//   si estrae con LettoreZip, si ripristina e si confronta file per file con il campione.
// Sul Mac la stessa sequenza gira dentro `--prova-backup` con ditto vero (confronto LettoreZip contro ditto).

extension ProvaBackup {
    // MARK: - Prova del lettore e dello scrittore zip

    /// LettoreZip e ScrittoreZip: andata e ritorno, contro ditto sul Mac, percorsi non sicuri, voci da saltare,
    /// CRC alterato, zip troncato. Restituisce il motivo dell'errore (nil = tutto bene).
    static func provaZip(radice: URL) throws -> String? {
        let fm = FileManager.default
        let cartella = radice.appendingPathComponent("Zip", isDirectory: true)
        let campione = cartella.appendingPathComponent("Campione/Prisma", isDirectory: true)
        try preparaCampione(in: campione)

        // ScrittoreZip → LettoreZip: le stesse cartelle e gli stessi byte
        let scritto = cartella.appendingPathComponent("scritto.zip")
        try ScrittoreZip.crea(da: campione, a: scritto)
        let nomi = try LettoreZip.nomi(scritto)
        guard nomi.first == "Prisma/", nomi.allSatisfy({ $0.hasPrefix("Prisma/") }), nomi.contains("Prisma/archivio.json") else {
            return "zip di ScrittoreZip: voci inattese (\(nomi.prefix(5)))"
        }
        let daScritto = cartella.appendingPathComponent("DaScritto", isDirectory: true)
        try LettoreZip.estrai(scritto, in: daScritto)
        if let e = confrontaCartelle(daScritto.appendingPathComponent("Prisma"), campione) { return "ScrittoreZip → LettoreZip: \(e)" }
        guard try LettoreZip.dati(scritto, voce: "Prisma/archivio.json") == Data(contentsOf: campione.appendingPathComponent("archivio.json")),
              try LettoreZip.dati(scritto, voce: "Prisma/manca.json") == nil else {
            return "LettoreZip.dati: una voce sola non torna uguale"
        }
        // Il percorso del ripristino con lo zip di ScrittoreZip (sul Mac lo estrae ditto: lo zip si apre anche lì)
        if let e = try provaDitto(zip: scritto, campione: campione) { return "zip di ScrittoreZip: \(e)" }

        #if os(macOS)
        // Contro ditto, con gli stessi argomenti dei backup: descrittori di dati, deflate, __MACOSX/
        let zipDitto = cartella.appendingPathComponent("ditto.zip")
        try GestoreBackup.ditto(["-c", "-k", "--sequesterRsrc", "--keepParent", campione.path, zipDitto.path])
        let daDitto = cartella.appendingPathComponent("DaDitto", isDirectory: true)
        try LettoreZip.estrai(zipDitto, in: daDitto)
        if let e = confrontaCartelle(daDitto.appendingPathComponent("Prisma"), campione) { return "zip di ditto → LettoreZip: \(e)" }
        let dittoDaDitto = cartella.appendingPathComponent("DittoDaDitto", isDirectory: true)
        try GestoreBackup.ditto(["-x", "-k", zipDitto.path, dittoDaDitto.path])
        // Si confronta la cartella Prisma: se ditto lasciasse da parte __MACOSX/ (invece di rimettere gli attributi
        // sui file) non sarebbe un errore del lettore; che LettoreZip non la estragga lo controlla provaDitto
        if let e = confrontaCartelle(daDitto.appendingPathComponent("Prisma"), dittoDaDitto.appendingPathComponent("Prisma")) {
            return "LettoreZip e ditto estraggono cose diverse: \(e)"
        }
        // ditto apre gli zip di ScrittoreZip (i backup di sicurezza fatti su iPhone e iPad)
        let dittoDaScritto = cartella.appendingPathComponent("DittoDaScritto", isDirectory: true)
        try GestoreBackup.ditto(["-x", "-k", scritto.path, dittoDaScritto.path])
        if let e = confrontaCartelle(dittoDaScritto.appendingPathComponent("Prisma"), campione) { return "zip di ScrittoreZip → ditto: \(e)" }
        // La sequenza del simulatore, con il vero zip di ditto
        if let e = try provaDitto(zip: zipDitto, campione: campione) { return "zip di ditto: \(e)" }
        #elseif os(iOS)
        // Lo zip di ditto lo prepara il runner: `--prepara-campione-backup` e `--prova-backup-ditto`
        #endif

        // Percorsi non sicuri: rifiutati prima di scrivere qualunque file
        for (i, nome) in ["../fuori.txt", "/assoluto.txt", "Prisma/../../fuori.txt"].enumerated() {
            let zip = cartella.appendingPathComponent("non-sicuro-\(i).zip")
            try ScrittoreZip.crea(voci: [.init(nome: "Prisma/", contenuto: .cartella),
                                         .init(nome: "Prisma/buono.txt", contenuto: .dati(Data("buono".utf8))),
                                         .init(nome: nome, contenuto: .dati(Data("fuori".utf8)))], a: zip)
            let base = cartella.appendingPathComponent("NonSicuro\(i)", isDirectory: true)
            let dentro = base.appendingPathComponent("dentro", isDirectory: true)
            do {
                try LettoreZip.estrai(zip, in: dentro)
                return "LettoreZip ha accettato il percorso «\(nome)»"
            } catch ErroreZip.percorsoNonSicuro {}
            guard !fm.fileExists(atPath: base.appendingPathComponent("fuori.txt").path),
                  !fm.fileExists(atPath: dentro.appendingPathComponent("Prisma/buono.txt").path) else {
                return "LettoreZip ha scritto dei file da uno zip con il percorso «\(nome)»"
            }
        }

        // __MACOSX/ e ._* si saltano
        let conRisorse = cartella.appendingPathComponent("risorse.zip")
        try ScrittoreZip.crea(voci: [.init(nome: "Prisma/", contenuto: .cartella),
                                     .init(nome: "Prisma/a.txt", contenuto: .dati(Data("a".utf8))),
                                     .init(nome: "Prisma/._a.txt", contenuto: .dati(Data("risorsa".utf8))),
                                     .init(nome: "__MACOSX/", contenuto: .cartella),
                                     .init(nome: "__MACOSX/Prisma/._a.txt", contenuto: .dati(Data("risorsa".utf8)))], a: conRisorse)
        let senzaRisorse = cartella.appendingPathComponent("SenzaRisorse", isDirectory: true)
        try LettoreZip.estrai(conRisorse, in: senzaRisorse)
        let estratti = (try? fm.subpathsOfDirectory(atPath: senzaRisorse.path))?.sorted() ?? []
        guard estratti == ["Prisma", "Prisma/a.txt"] else { return "LettoreZip non salta __MACOSX/ e ._* (\(estratti))" }

        // Un byte alterato: il CRC32 lo scopre e il file a metà non resta
        let segno = Data("contenuto da alterare 0123456789".utf8)
        let alterato = cartella.appendingPathComponent("alterato.zip")
        try ScrittoreZip.crea(voci: [.init(nome: "Prisma/", contenuto: .cartella),
                                     .init(nome: "Prisma/a.txt", contenuto: .dati(segno))], a: alterato)
        var byte = try Data(contentsOf: alterato)
        guard let dove = byte.range(of: segno) else { return "zip memorizzato: contenuto non trovato" }
        byte[dove.lowerBound + 3] ^= 0x20
        try byte.write(to: alterato)
        let daAlterato = cartella.appendingPathComponent("DaAlterato", isDirectory: true)
        do {
            try LettoreZip.estrai(alterato, in: daAlterato)
            return "LettoreZip ha accettato una voce con il CRC sbagliato"
        } catch ErroreZip.controlloFallito {}
        guard !fm.fileExists(atPath: daAlterato.appendingPathComponent("Prisma/a.txt").path) else {
            return "LettoreZip ha lasciato il file di una voce danneggiata"
        }

        // Troncato e non zip: errore, mai un'estrazione vuota
        let troncato = cartella.appendingPathComponent("troncato.zip")
        try Data(contentsOf: scritto).dropLast(30).write(to: troncato)
        let estraneo = cartella.appendingPathComponent("estraneo.zip")
        try Data("non sono uno zip".utf8).write(to: estraneo)
        for (i, rotto) in [troncato, estraneo].enumerated() {
            do {
                try LettoreZip.estrai(rotto, in: cartella.appendingPathComponent("Rotto\(i)", isDirectory: true))
                return "LettoreZip ha aperto uno zip rotto (\(rotto.lastPathComponent))"
            } catch is ErroreZip {}
        }
        // Il CRC32 di riferimento («123456789» → CBF43926)
        guard CRC32.di(Data("123456789".utf8)) == 0xCBF4_3926 else { return "CRC32 sbagliato" }
        return nil
    }

    // MARK: - Campione e sequenza del simulatore

    /// Documents dell'app (su iPhone e iPad, nel simulatore, una cartella del runner).
    static var cartellaDocumentiApp: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Il campione di `--prepara-campione-backup`: Documents/campione/Prisma.
    static var campioneApp: URL {
        cartellaDocumentiApp.appendingPathComponent("campione/Prisma", isDirectory: true)
    }

    /// `--prepara-campione-backup`: scrive il campione in Documents/campione/Prisma (0 = riuscito).
    static func preparaCampione() -> Int32 {
        do {
            try preparaCampione(in: campioneApp)
            print("OK: campione del backup in \(campioneApp.path)")
            return 0
        } catch {
            print("ERRORE: campione del backup non scritto: \(error.localizedDescription)")
            return 1
        }
    }

    /// `--prova-backup-ditto <zip>`: lo zip del campione fatto da ditto si cifra, si decifra, si estrae, si
    /// ripristina e si confronta con Documents/campione/Prisma (0 = riuscito).
    static func provaDitto(zip: URL) -> Int32 {
        do {
            if let e = try provaDitto(zip: zip, campione: campioneApp) {
                print("ERRORE: \(e)")
                return 1
            }
            print("OK: backup di ditto cifrato, decifrato, estratto e ripristinato identico al campione")
            return 0
        } catch {
            print("ERRORE: \(error.localizedDescription)")
            return 1
        }
    }

    /// Un archivio di prova completo in `cartella` (sostituita): i dati di prova, un PDF, un PNG, un testo lungo
    /// (più pezzi deflate), byte casuali, un file vuoto, un nome con gli accenti e un attributo esteso (che ditto
    /// mette in `__MACOSX/`).
    static func preparaCampione(in cartella: URL) throws {
        let fm = FileManager.default
        try? fm.removeItem(at: cartella)
        let documenti = cartella.appendingPathComponent("Documenti", isDirectory: true)
        let eve = cartella.appendingPathComponent("Eve", isDirectory: true)
        try fm.createDirectory(at: documenti, withIntermediateDirectories: true)
        try fm.createDirectory(at: eve, withIntermediateDirectories: true)
        try Archivio.codificatore.encode(DatiPrisma.demo()).write(to: cartella.appendingPathComponent("archivio.json"))
        try Data(#"{"prova":true}"#.utf8).write(to: eve.appendingPathComponent("memoria.json"))
        try Data("Nota di prova con gli accenti: è, à, ü.".utf8).write(to: documenti.appendingPathComponent("Nota città è ü.txt"))
        try Data().write(to: documenti.appendingPathComponent("vuoto.txt"))
        let riga = "Posizione di prova · Alleanza e indipendente · 12.345,67 €\n"
        try Data(String(repeating: riga, count: 7_000).utf8).write(to: documenti.appendingPathComponent("testo-lungo.txt"))
        var casuali = [UInt8](repeating: 0, count: 300_000)
        var x: UInt64 = 0x2545_F491_4F6C_DD1D
        for i in casuali.indices {
            x ^= x << 13
            x ^= x >> 7
            x ^= x << 17
            casuali[i] = UInt8(truncatingIfNeeded: x)
        }
        try Data(casuali).write(to: documenti.appendingPathComponent("casuale.bin"))
        let pdf = documenti.appendingPathComponent("prova.pdf")
        try scriviPDF(pdf)
        try scriviPNG(documenti.appendingPathComponent("prova.png"))
        // Un attributo esteso: ditto con --sequesterRsrc lo scrive in __MACOSX/Prisma/Documenti/._prova.pdf
        let valore = Data("prova".utf8)
        _ = valore.withUnsafeBytes { setxattr(pdf.path, "local.prisma.prova", $0.baseAddress, $0.count, 0, 0) }
    }

    /// La sequenza del simulatore su uno zip della cartella `campione` (fatto con `--keepParent`): LettoreZip
    /// diretto, poi cifratura, `GestoreBackup.estrai` con la password e `sostituisci`, ogni volta confrontati con il
    /// campione. Restituisce il motivo dell'errore (nil = tutto bene).
    static func provaDitto(zip: URL, campione: URL) throws -> String? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: zip.path) else { return "lo zip \(zip.path) non c'è" }
        guard fm.fileExists(atPath: campione.appendingPathComponent("archivio.json").path) else { return "il campione \(campione.path) non c'è" }
        let radice = fm.temporaryDirectory.appendingPathComponent("Prisma-prova-ditto-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: radice) }
        try fm.createDirectory(at: radice, withIntermediateDirectories: true)

        // LettoreZip diretto: le stesse cartelle e gli stessi byte, niente __MACOSX/ né ._*
        let diretta = radice.appendingPathComponent("Diretta", isDirectory: true)
        try LettoreZip.estrai(zip, in: diretta)
        if let e = confrontaCartelle(diretta.appendingPathComponent("Prisma"), campione) { return "estrazione diretta: \(e)" }
        guard !fm.fileExists(atPath: diretta.appendingPathComponent("__MACOSX").path) else { return "estratta la cartella __MACOSX" }

        // Cifrato come un backup protetto (poche iterazioni: è una prova), poi aperto come dal dispositivo
        let password = "prova-ditto-àè"
        let cifrato = radice.appendingPathComponent(GestoreBackup.prefisso + "prova.zip." + GestoreBackup.estensioneCifrata)
        try CifraturaBackup.cifra(zip, in: cifrato, password: password, iterazioni: 1_000)
        do {
            _ = try GestoreBackup.estrai(cifrato, password: "sbagliata")
            return "il backup si è aperto con la password sbagliata"
        } catch ErroreBackup.passwordErrata {}
        let estratto = try GestoreBackup.estrai(cifrato, password: password)
        defer { GestoreBackup.pulisciEstrazione(estratto.cartella) }
        let attesi = try Archivio.decodifica(Data(contentsOf: campione.appendingPathComponent("archivio.json")))
        guard estratto.dati == attesi else { return "i dati estratti non coincidono con il campione" }
        if let e = confrontaCartelle(estratto.cartella, campione) { return "backup estratto: \(e)" }

        // Ripristino al posto di un archivio esistente
        let ripristino = radice.appendingPathComponent("Ripristino/Prisma", isDirectory: true)
        try fm.createDirectory(at: ripristino, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: ripristino.appendingPathComponent("archivio.json"))
        try GestoreBackup.sostituisci(cartellaDati: ripristino, con: estratto.cartella)
        if let e = confrontaCartelle(ripristino, campione) { return "archivio ripristinato: \(e)" }
        return nil
    }

    /// Confronta due cartelle: stessi percorsi (cartelle e file) e stessi byte. nil = uguali.
    static func confrontaCartelle(_ a: URL, _ b: URL) -> String? {
        let fm = FileManager.default
        guard let elencoA = try? fm.subpathsOfDirectory(atPath: a.path) else { return "manca \(a.lastPathComponent)" }
        guard let elencoB = try? fm.subpathsOfDirectory(atPath: b.path) else { return "manca \(b.lastPathComponent)" }
        let insiemeA = Set(elencoA), insiemeB = Set(elencoB)
        guard insiemeA == insiemeB else {
            let soloA = insiemeA.subtracting(insiemeB).sorted().prefix(5)
            let soloB = insiemeB.subtracting(insiemeA).sorted().prefix(5)
            return "file diversi (in più: \(Array(soloA)), mancanti: \(Array(soloB)))"
        }
        for percorso in insiemeA.sorted() {
            let pa = a.appendingPathComponent(percorso).path, pb = b.appendingPathComponent(percorso).path
            var cartellaA: ObjCBool = false, cartellaB: ObjCBool = false
            guard fm.fileExists(atPath: pa, isDirectory: &cartellaA), fm.fileExists(atPath: pb, isDirectory: &cartellaB),
                  cartellaA.boolValue == cartellaB.boolValue else {
                return "«\(percorso)» è una cartella da una parte e un file dall'altra"
            }
            if cartellaA.boolValue { continue }
            guard fm.contentsEqual(atPath: pa, andPath: pb) else { return "«\(percorso)» ha un contenuto diverso" }
        }
        return nil
    }

    /// Un PDF di una pagina A4 con un rettangolo (CoreGraphics, uguale su Mac e iOS).
    private static func scriviPDF(_ url: URL) throws {
        var pagina = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let c = CGContext(url as CFURL, mediaBox: &pagina, nil) else { throw ErroreZip.nonValido("PDF di prova non creato") }
        c.beginPDFPage(nil)
        c.setFillColor(red: 0.06, green: 0.14, blue: 0.2, alpha: 1)
        c.fill(CGRect(x: 60, y: 600, width: 200, height: 120))
        c.endPDFPage()
        c.closePDF()
    }

    /// Un PNG 64 × 64 a tinta unita (ImageIO).
    private static func scriviPNG(_ url: URL) throws {
        guard let c = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ErroreZip.nonValido("PNG di prova non creato")
        }
        c.setFillColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1)
        c.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        guard let immagine = c.makeImage(),
              let destinazione = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw ErroreZip.nonValido("PNG di prova non creato")
        }
        CGImageDestinationAddImage(destinazione, immagine, nil)
        guard CGImageDestinationFinalize(destinazione) else { throw ErroreZip.nonValido("PNG di prova non scritto") }
    }
}
