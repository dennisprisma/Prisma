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
        // Un numero non finito (NaN, infinito) non deve bloccare ogni salvataggio
        e.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return e
    }()

    static let decodificatore: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return d
    }()

    static func decodifica(_ data: Data) throws -> DatiPrisma {
        try decodificatore.decode(DatiPrisma.self, from: data)
    }

    /// Copia dell'archivio fatta a ogni avvio: si torna all'inizio della giornata di lavoro.
    static var copiaAvvio: URL { cartella.appendingPathComponent("archivio-all-avvio.json") }
    static let prefissoNonLeggibile = "archivio-non-leggibile"

    /// Solo il numero di versione: si legge anche quando il resto dell'archivio non si legge.
    private struct SoloVersione: Decodable { var versione: Int? }

    static let avvisoPiuRecente = "Questo archivio è stato salvato da una versione più recente di Prisma: lo apro in sola lettura e non salvo nulla, per non perdere dati. Apri l'ultima versione di Prisma."

    /// Copie di archivi non leggibili non ancora gestite: finché ci sono, i backup automatici si fermano
    /// (non devono sostituire, con la rotazione, i backup buoni con i dati di prova).
    static var copieNonLeggibili: [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: cartella, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(prefissoNonLeggibile) && !$0.lastPathComponent.contains("(gestito)") }
    }

    /// Segna come gestite le copie non leggibili (dopo un ripristino o per scelta del consulente).
    static func segnaCopieGestite() {
        for u in copieNonLeggibili {
            let nuovo = u.deletingPathExtension().lastPathComponent + " (gestito).json"
            try? FileManager.default.moveItem(at: u, to: u.deletingLastPathComponent().appendingPathComponent(nuovo))
        }
    }

    /// Carica l'archivio. Al primo avvio crea l'archivio con i dati di prova.
    /// - Ripristino interrotto: rimette a posto la cartella di prima.
    /// - Archivio mancante ma cartella già usata: riprende la copia dell'ultimo avvio, mai i dati di prova in silenzio.
    /// - Versione più recente: sola lettura, il file non si tocca (salvarlo perderebbe i dati che questa non conosce).
    /// - File non leggibile: ne conserva una copia e riparte dai dati di prova, con l'avviso.
    static func carica() -> (dati: DatiPrisma, avviso: String?, solaLettura: Bool, bloccaRipristino: Bool) {
        let recuperato = GestoreBackup.recuperaRipristino(cartella)
        try? preparaCartelle()
        let fm = FileManager.default
        guard fm.fileExists(atPath: file.path) else {
            if let grezzo = try? Data(contentsOf: copiaAvvio), let d = try? decodifica(grezzo), !diVersionePiuRecente(d) {
                try? salva(d)
                return (d, "L'archivio mancava: ho ripreso la copia fatta all'ultimo avvio di Prisma. Controlla gli ultimi inserimenti.", false, false)
            }
            let documenti = (try? fm.contentsOfDirectory(atPath: cartellaDocumenti.path)) ?? []
            if !documenti.isEmpty || !copieNonLeggibili.isEmpty {
                // La cartella è già stata usata: niente dati di prova scritti sopra
                return (DatiPrisma.demo(), "L'archivio di Prisma manca ma la cartella contiene documenti: non salvo nulla. Ripristina un backup da Impostazioni (o chiedi aiuto prima di continuare).", true, false)
            }
            let d = DatiPrisma.demo()
            try? salva(d)
            return (d, nil, false, false)
        }
        guard let grezzo = try? Data(contentsOf: file) else {
            return (DatiPrisma.demo(), "Non riesco ad aprire l'archivio di Prisma: non salvo nulla. Riavvia il Mac e riprova.", true, false)
        }
        // La versione prima di tutto: un archivio più recente può non essere leggibile da questa versione
        if let v = try? decodificatore.decode(SoloVersione.self, from: grezzo).versione, v > DatiPrisma.versioneAttuale {
            let dati = (try? decodifica(grezzo)) ?? DatiPrisma(clienti: [], appuntamenti: [], attivita: [], posizioni: [],
                                                               clienteAttivoId: "", impostazioni: Impostazioni())
            return (dati, avvisoPiuRecente, true, true)
        }
        do {
            var dati = try decodifica(grezzo)
            try? grezzo.write(to: copiaAvvio, options: .atomic)
            dati.versione = DatiPrisma.versioneAttuale
            return (dati, recuperato ? "Un ripristino era stato interrotto: ho rimesso l'archivio com'era prima." : nil, false, false)
        } catch {
            let copia = cartella.appendingPathComponent("\(prefissoNonLeggibile) \(Formati.nomeFile.string(from: Date())).json")
            try? fm.moveItem(at: file, to: copia)
            let d = DatiPrisma.demo()
            try? salva(d)
            return (d, "L'archivio non era leggibile: ne ho conservato una copia nella cartella di Prisma e caricato i dati di prova. I backup automatici sono fermi finché non ripristini un backup da Impostazioni.", false, false)
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
