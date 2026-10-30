#if os(macOS)
import AppKit
#endif
import Foundation

/// All'avvio di Prisma (solo sul Mac): se Ollama non risponde lo apre, poi carica il modello in memoria,
/// così la prima domanda a Eve non aspetta il caricamento. Si fa in background, qualche secondo dopo l'avvio.
enum AvvioModello {
    /// Dove cercare il programma `ollama` se l'app non c'è (installazione da Homebrew o dal sito).
    static let programmi = ["/usr/local/bin/ollama", "/opt/homebrew/bin/ollama", "/Applications/Ollama.app/Contents/Resources/ollama"]
    /// Quanto aspettare che Ollama, appena aperto, risponda.
    static let attesaApertura: TimeInterval = 20

    #if os(macOS)
    /// `ollama serve` avviato da Prisma (se l'app Ollama non c'è): resta acceso finché serve.
    private static var servizio: Process?

    /// Prepara il modello e dice com'è andata.
    static func prepara(_ eve: ImpostazioniEve, passaggio: @escaping (String) -> Void = { _ in }) async -> DisponibilitaEve {
        let f = FornitoriEve.crea(eve)
        guard IndirizzoLocale.url(f.indirizzo) != nil else { return await MotoreLocale.verifica(eve) }
        if eve.fornitore == .ollama, !(await f.raggiungibile()) {
            passaggio("Apro Ollama…")
            guard avviaOllama(indirizzo: f.indirizzo) else { return await MotoreLocale.verifica(eve) }
            let fine = Date().addingTimeInterval(attesaApertura)
            while Date() < fine {
                if await f.raggiungibile() { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        let d = await f.verifica()
        guard d.pronto else { return d }
        passaggio("Carico \(f.modello)…")
        _ = await f.precarica(restaInMemoria: eve.restaInMemoria)
        return d
    }

    /// Prima l'app Ollama (`open -a Ollama`, in background), poi il programma `ollama serve`.
    static func avviaOllama(indirizzo: String) -> Bool {
        if esegui("/usr/bin/open", ["-g", "-j", "-a", "Ollama"]) { return true }
        guard servizio?.isRunning != true,
              let programma = programmi.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return servizio?.isRunning == true }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: programma)
        p.arguments = ["serve"]
        var ambiente = ProcessInfo.processInfo.environment
        // Lo stesso indirizzo scelto in Prisma (di solito 127.0.0.1:11434): mai in ascolto sulla rete
        if let u = IndirizzoLocale.url(indirizzo), let h = u.host {
            ambiente["OLLAMA_HOST"] = "\(h.contains(":") ? "[\(h)]" : h):\(u.port ?? 11434)"
        }
        p.environment = ambiente
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            servizio = p
            return true
        } catch {
            return false
        }
    }

    /// Un comando breve: true se finisce bene.
    private static func esegui(_ percorso: String, _ argomenti: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: percorso)
        p.arguments = argomenti
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }
    #endif
}
