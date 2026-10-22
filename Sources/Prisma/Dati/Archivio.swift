import Foundation

/// Archivio locale in ~/Library/Application Support/Prisma.
///
/// Contenuto della cartella:
/// - archivio.json: clienti, agenda, posizioni, impostazioni
/// - Documenti/: documenti dei clienti
/// - Eve/: impostazioni e memoria di Eve
enum Archivio {
    static var supportoApplicazioni: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    static var cartella: URL { supportoApplicazioni.appendingPathComponent("Prisma", isDirectory: true) }
    static var file: URL { cartella.appendingPathComponent("archivio.json") }
    static var cartellaDocumenti: URL { cartella.appendingPathComponent("Documenti", isDirectory: true) }
    static var cartellaEve: URL { cartella.appendingPathComponent("Eve", isDirectory: true) }

    /// Cartella dei backup finché l'utente non ne sceglie una (stesso Mac: va cambiata).
    static var cartellaBackupPredefinita: URL {
        supportoApplicazioni.appendingPathComponent("Prisma Backup", isDirectory: true)
    }

    static func preparaCartelle() throws {
        let fm = FileManager.default
        for c in [cartella, cartellaDocumenti, cartellaEve] {
            try fm.createDirectory(at: c, withIntermediateDirectories: true)
        }
    }

    static let codificatore: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decodificatore: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func decodifica(_ data: Data) throws -> DatiPrisma {
        try decodificatore.decode(DatiPrisma.self, from: data)
    }

    /// Copia dell'archivio fatta a ogni avvio: si torna all'inizio della giornata di lavoro.
    static var copiaAvvio: URL { cartella.appendingPathComponent("archivio-all-avvio.json") }

    /// Carica l'archivio. Al primo avvio crea l'archivio con i dati di prova.
    /// Se il file non è leggibile ne conserva una copia e riparte dai dati di prova.
    /// Se l'ha scritto una versione più recente di Prisma lo apre in sola lettura: salvarlo con
    /// questa versione cancellerebbe i dati che non conosce.
    static func carica() -> (dati: DatiPrisma, avviso: String?, solaLettura: Bool) {
        try? preparaCartelle()
        let fm = FileManager.default
        guard fm.fileExists(atPath: file.path) else {
            let d = DatiPrisma.demo()
            try? salva(d)
            return (d, nil, false)
        }
        do {
            let grezzo = try Data(contentsOf: file)
            var dati = try decodifica(grezzo)
            if diVersionePiuRecente(dati) {
                return (dati, "Questo archivio è stato salvato da una versione più recente di Prisma: lo apro in sola lettura e non salvo nulla, per non perdere dati. Apri l'ultima versione di Prisma.", true)
            }
            try? grezzo.write(to: copiaAvvio, options: .atomic)
            dati.versione = DatiPrisma.versioneAttuale
            return (dati, nil, false)
        } catch {
            let copia = cartella.appendingPathComponent("archivio-non-leggibile \(Formati.nomeFile.string(from: Date())).json")
            try? fm.moveItem(at: file, to: copia)
            let d = DatiPrisma.demo()
            try? salva(d)
            return (d, "L'archivio non era leggibile: ne ho conservato una copia nella cartella di Prisma e caricato i dati di prova. Puoi ripristinare un backup da Impostazioni.", false)
        }
    }

    /// true se l'archivio l'ha scritto una versione di Prisma più recente di questa.
    static func diVersionePiuRecente(_ dati: DatiPrisma) -> Bool {
        dati.versione > DatiPrisma.versioneAttuale
    }

    static func salva(_ dati: DatiPrisma) throws {
        try preparaCartelle()
        let data = try codificatore.encode(dati)
        try data.write(to: file, options: .atomic)
    }

    /// Percorso leggibile, con ~ al posto della cartella Inizio.
    static func percorsoBreve(_ url: URL) -> String {
        let casa = FileManager.default.homeDirectoryForCurrentUser.path
        let p = url.path
        return p.hasPrefix(casa) ? "~" + p.dropFirst(casa.count) : p
    }
}
