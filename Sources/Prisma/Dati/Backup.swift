import Foundation

/// Un backup presente nella cartella dei backup.
struct VoceBackup: Identifiable, Equatable {
    let url: URL
    let data: Date
    let dimensione: Int64
    var id: URL { url }
    var nome: String { url.deletingPathExtension().lastPathComponent }
}

enum ErroreBackup: LocalizedError {
    case comando(String)
    case archivioMancante
    case archivioNonValido(String)

    var errorDescription: String? {
        switch self {
        case .comando(let m): return "Compressione non riuscita: \(m)"
        case .archivioMancante: return "Il file scelto non è un backup di Prisma."
        case .archivioNonValido(let m): return "Il backup non è leggibile: \(m)"
        }
    }
}

/// Backup dell'intera cartella dell'archivio in file .zip, con rotazione.
/// Usa /usr/bin/ditto, presente su ogni Mac: nessuna dipendenza esterna.
enum GestoreBackup {
    static let prefisso = "Prisma backup "
    /// Rotazione: si tengono solo le ultime 8 copie.
    static let massimo = 8

    /// Crea un backup di `sorgente` dentro `destinazione` e applica la rotazione.
    @discardableResult
    static func crea(sorgente: URL, destinazione: URL, nota: String? = nil) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: destinazione, withIntermediateDirectories: true)
        var nome = prefisso + Formati.nomeFile.string(from: Date())
        if let nota { nome += " (\(nota))" }
        let finale = destinazione.appendingPathComponent(nome + ".zip")
        let parziale = destinazione.appendingPathComponent(nome + ".zip.parziale")
        try? fm.removeItem(at: parziale)
        try ditto(["-c", "-k", "--sequesterRsrc", "--keepParent", sorgente.path, parziale.path])
        try? fm.removeItem(at: finale)
        try fm.moveItem(at: parziale, to: finale)
        ruota(destinazione)
        return finale
    }

    /// Backup presenti, dal più recente.
    static func elenca(_ cartella: URL) -> [VoceBackup] {
        let chiavi: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        let file = (try? FileManager.default.contentsOfDirectory(at: cartella, includingPropertiesForKeys: chiavi)) ?? []
        return file
            .filter { $0.pathExtension == "zip" && $0.lastPathComponent.hasPrefix(prefisso) }
            .map { url in
                let v = try? url.resourceValues(forKeys: Set(chiavi))
                return VoceBackup(url: url, data: v?.contentModificationDate ?? .distantPast, dimensione: Int64(v?.fileSize ?? 0))
            }
            .sorted { $0.data > $1.data }
    }

    /// Elimina i backup più vecchi oltre le ultime `massimo` copie.
    static func ruota(_ cartella: URL) {
        for vecchio in elenca(cartella).dropFirst(massimo) {
            try? FileManager.default.removeItem(at: vecchio.url)
        }
    }

    /// Estrae un backup in una cartella temporanea e ne verifica l'archivio.
    /// Restituisce i dati e la cartella "Prisma" estratta.
    static func estrai(_ zip: URL) throws -> (dati: DatiPrisma, cartella: URL) {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("Prisma-ripristino-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        try ditto(["-x", "-k", zip.path, tmp.path])
        let candidati = [tmp.appendingPathComponent("Prisma", isDirectory: true), tmp]
        guard let radice = candidati.first(where: { fm.fileExists(atPath: $0.appendingPathComponent("archivio.json").path) }) else {
            throw ErroreBackup.archivioMancante
        }
        do {
            let dati = try Archivio.decodifica(Data(contentsOf: radice.appendingPathComponent("archivio.json")))
            return (dati, radice)
        } catch {
            throw ErroreBackup.archivioNonValido(error.localizedDescription)
        }
    }

    /// Sostituisce il contenuto della cartella dell'archivio con quello estratto.
    static func sostituisci(cartellaDati: URL, con estratta: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: cartellaDati, withIntermediateDirectories: true)
        for voce in try fm.contentsOfDirectory(at: cartellaDati, includingPropertiesForKeys: nil) {
            try fm.removeItem(at: voce)
        }
        for voce in try fm.contentsOfDirectory(at: estratta, includingPropertiesForKeys: nil) {
            try fm.copyItem(at: voce, to: cartellaDati.appendingPathComponent(voce.lastPathComponent))
        }
        // Pulizia della cartella temporanea dell'estrazione.
        let temporanea = [estratta, estratta.deletingLastPathComponent()]
            .first { $0.lastPathComponent.hasPrefix("Prisma-ripristino-") }
        if let temporanea { try? fm.removeItem(at: temporanea) }
    }

    private static func ditto(_ argomenti: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = argomenti
        let errore = Pipe()
        p.standardError = errore
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let testo = String(data: errore.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ErroreBackup.comando(testo.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
