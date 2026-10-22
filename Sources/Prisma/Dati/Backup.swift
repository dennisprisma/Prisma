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
    case cartellaNonRaggiungibile(String)
    case versionePiuRecente

    var errorDescription: String? {
        switch self {
        case .comando(let m): return "Compressione non riuscita: \(m)"
        case .archivioMancante: return "Il file scelto non è un backup di Prisma."
        case .archivioNonValido(let m): return "Il backup non è leggibile: \(m)"
        case .cartellaNonRaggiungibile(let p): return "La cartella dei backup non è raggiungibile (\(p)): collega il disco o scegline un'altra."
        case .versionePiuRecente: return "Il backup è stato creato da una versione più recente di Prisma: aprilo con l'ultima versione."
        }
    }
}

/// Backup dell'intera cartella dell'archivio in file .zip, con rotazione.
/// Usa /usr/bin/ditto, presente su ogni Mac: nessuna dipendenza esterna.
enum GestoreBackup {
    static let prefisso = "Prisma backup "
    /// Rotazione: si tengono le ultime 8 copie automatiche (8 settimane) e, a parte, le ultime 8
    /// copie fatte a mano o di sicurezza: un ripristino non consuma la storia settimanale.
    static let massimo = 8
    static let notaAutomatico = "automatico"

    /// Crea un backup di `sorgente` dentro `destinazione` e applica la rotazione.
    /// - creaCartella: false per la cartella scelta dall'utente: se non c'è (disco scollegato) è un
    ///   errore, non si ricrea il percorso sul disco del Mac.
    /// - proteggi: un backup da non eliminare con la rotazione (quello che si sta ripristinando).
    @discardableResult
    static func crea(sorgente: URL, destinazione: URL, nota: String? = nil, creaCartella: Bool = true, proteggi: URL? = nil) throws -> URL {
        let fm = FileManager.default
        if creaCartella {
            try fm.createDirectory(at: destinazione, withIntermediateDirectories: true)
        } else {
            var cartella: ObjCBool = false
            guard fm.fileExists(atPath: destinazione.path, isDirectory: &cartella), cartella.boolValue else {
                throw ErroreBackup.cartellaNonRaggiungibile(destinazione.path)
            }
        }
        // Copie parziali rimaste da un backup interrotto: contengono dati dei clienti
        for vecchia in (try? fm.contentsOfDirectory(at: destinazione, includingPropertiesForKeys: nil)) ?? []
        where vecchia.lastPathComponent.hasPrefix(prefisso) && vecchia.lastPathComponent.hasSuffix(".zip.parziale") {
            try? fm.removeItem(at: vecchia)
        }
        var nome = prefisso + Formati.nomeFile.string(from: Date())
        if let nota { nome += " (\(nota))" }
        let finale = destinazione.appendingPathComponent(nome + ".zip")
        let parziale = destinazione.appendingPathComponent(nome + ".zip.parziale")
        do {
            try ditto(["-c", "-k", "--sequesterRsrc", "--keepParent", sorgente.path, parziale.path])
            try? fm.removeItem(at: finale)
            try fm.moveItem(at: parziale, to: finale)
        } catch {
            try? fm.removeItem(at: parziale)
            throw error
        }
        ruota(destinazione, proteggi: proteggi)
        return finale
    }

    static func automatico(_ v: VoceBackup) -> Bool { v.nome.hasSuffix("(\(notaAutomatico))") }

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

    /// Elimina i backup più vecchi oltre le ultime `massimo` copie, contando a parte quelle automatiche.
    static func ruota(_ cartella: URL, proteggi: URL? = nil) {
        let tutti = elenca(cartella)
        let troppi = Array(tutti.filter(automatico).dropFirst(massimo)) + Array(tutti.filter { !automatico($0) }.dropFirst(massimo))
        for vecchio in troppi where vecchio.url.standardizedFileURL != proteggi?.standardizedFileURL {
            try? FileManager.default.removeItem(at: vecchio.url)
        }
    }

    /// Estrae un backup in una cartella temporanea e ne verifica l'archivio.
    /// Restituisce i dati e la cartella "Prisma" estratta.
    static func estrai(_ zip: URL) throws -> (dati: DatiPrisma, cartella: URL) {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("Prisma-ripristino-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        do {
            try ditto(["-x", "-k", zip.path, tmp.path])
            let candidati = [tmp.appendingPathComponent("Prisma", isDirectory: true), tmp]
            guard let radice = candidati.first(where: { fm.fileExists(atPath: $0.appendingPathComponent("archivio.json").path) }) else {
                throw ErroreBackup.archivioMancante
            }
            let dati: DatiPrisma
            do {
                dati = try Archivio.decodifica(Data(contentsOf: radice.appendingPathComponent("archivio.json")))
            } catch {
                throw ErroreBackup.archivioNonValido(error.localizedDescription)
            }
            // Un backup di una versione più recente perderebbe i dati che questa non conosce
            guard !Archivio.diVersionePiuRecente(dati) else { throw ErroreBackup.versionePiuRecente }
            return (dati, radice)
        } catch {
            // Niente copie dei dati dei clienti lasciate nella cartella temporanea
            try? fm.removeItem(at: tmp)
            throw error
        }
    }

    /// Elimina la cartella temporanea di un'estrazione (anche se il ripristino non va a buon fine).
    static func pulisciEstrazione(_ estratta: URL) {
        let temporanea = [estratta, estratta.deletingLastPathComponent()]
            .first { $0.lastPathComponent.hasPrefix("Prisma-ripristino-") }
        if let temporanea { try? FileManager.default.removeItem(at: temporanea) }
    }

    /// Sostituisce la cartella dell'archivio con quella estratta, senza mai lasciarla a metà:
    /// prepara la nuova cartella accanto («Prisma.ripristino»), sposta quella attuale in
    /// «Prisma.precedente» e mette la nuova al suo posto (spostamenti sullo stesso disco, istantanei).
    /// Se qualcosa va storto torna la cartella di prima; un'interruzione la recupera `recuperaRipristino`.
    static func sostituisci(cartellaDati: URL, con estratta: URL) throws {
        let fm = FileManager.default
        defer { pulisciEstrazione(estratta) }
        let (nuova, precedente) = cartelleRipristino(cartellaDati)
        try? fm.removeItem(at: nuova)
        try? fm.removeItem(at: precedente)
        try fm.createDirectory(at: cartellaDati.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: estratta, to: nuova)
        // Le copie degli archivi non leggibili restano: possono contenere gli unici dati veri
        for voce in (try? fm.contentsOfDirectory(at: cartellaDati, includingPropertiesForKeys: nil)) ?? []
        where voce.lastPathComponent.hasPrefix(Archivio.prefissoNonLeggibile) {
            try? fm.copyItem(at: voce, to: nuova.appendingPathComponent(voce.lastPathComponent))
        }
        let cera = fm.fileExists(atPath: cartellaDati.path)
        if cera { try fm.moveItem(at: cartellaDati, to: precedente) }
        do {
            try fm.moveItem(at: nuova, to: cartellaDati)
        } catch {
            if cera { try? fm.moveItem(at: precedente, to: cartellaDati) }
            try? fm.removeItem(at: nuova)
            throw error
        }
        try? fm.removeItem(at: precedente)
    }

    static func cartelleRipristino(_ cartellaDati: URL) -> (nuova: URL, precedente: URL) {
        let genitore = cartellaDati.deletingLastPathComponent()
        let nome = cartellaDati.lastPathComponent
        return (genitore.appendingPathComponent(nome + ".ripristino", isDirectory: true),
                genitore.appendingPathComponent(nome + ".precedente", isDirectory: true))
    }

    /// Dopo un ripristino interrotto (Mac spento a metà): se l'archivio manca ma c'è la cartella di
    /// prima, la rimette al suo posto. Restituisce true se ha recuperato qualcosa.
    @discardableResult
    static func recuperaRipristino(_ cartellaDati: URL) -> Bool {
        let fm = FileManager.default
        let (nuova, precedente) = cartelleRipristino(cartellaDati)
        guard !fm.fileExists(atPath: cartellaDati.appendingPathComponent("archivio.json").path) else {
            try? fm.removeItem(at: nuova)
            return false
        }
        for candidata in [precedente, nuova] where fm.fileExists(atPath: candidata.appendingPathComponent("archivio.json").path) {
            if fm.fileExists(atPath: cartellaDati.path) {
                let messa = cartellaDati.deletingLastPathComponent().appendingPathComponent(cartellaDati.lastPathComponent + ".incompleta \(UUID().uuidString.prefix(6))")
                try? fm.moveItem(at: cartellaDati, to: messa)
            }
            if (try? fm.moveItem(at: candidata, to: cartellaDati)) != nil { return true }
        }
        return false
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
