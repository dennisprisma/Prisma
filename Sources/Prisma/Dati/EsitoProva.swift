import Foundation

/// L'esito delle prove automatiche (`--prova-*`) dove il codice d'uscita non arriva al workflow.
/// - Sul Mac non fa nulla: lì vale il codice d'uscita dell'app, come sempre.
/// - Su iPhone e iPad (simulatore) `xcrun simctl launch` non restituisce il codice d'uscita dell'app: ogni prova
///   scrive `Documents/esito-<prova>.txt` con «OK» oppure «ERRORE …» sulla prima riga, prima di uscire. Lo legge
///   `Supporto/iOS/prove.sh`; un file mancante conta come prova fallita.
enum EsitoProva {
    /// Scrive l'esito della prova `prova` (il nome dell'argomento senza «--», per esempio «prova-backup»).
    /// `dettaglio` si aggiunge sulla prima riga dopo «OK» o «ERRORE».
    static func scrivi(_ prova: String, ok: Bool, dettaglio: String = "") {
        #if os(macOS)
        // Sul Mac l'esito è il codice d'uscita: nessun file
        #elseif os(iOS)
        guard let file = self.file(prova) else { return }
        var riga = ok ? "OK" : "ERRORE"
        let pulito = dettaglio.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        if !pulito.isEmpty { riga += " " + pulito }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data((riga + "\n").utf8).write(to: file, options: .atomic)
        #endif
    }

    /// Scrive l'esito dal codice d'uscita della prova (0 = OK) ed esce con quel codice.
    /// Sul Mac equivale a `exit(codice)`.
    static func esci(_ prova: String, codice: Int32) -> Never {
        scrivi(prova, ok: codice == 0, dettaglio: codice == 0 ? "" : "codice \(codice)")
        exit(codice)
    }

    #if os(macOS)
    // Sul Mac nessun file di esito
    #elseif os(iOS)
    /// `Documents/esito-<prova>.txt` del contenitore dell'app (nel simulatore è una cartella del runner).
    static func file(_ prova: String) -> URL? {
        let nome = prova.hasPrefix("--") ? String(prova.dropFirst(2)) : prova
        guard !nome.isEmpty, !nome.contains("/") else { return nil }
        guard let documenti = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documenti.appendingPathComponent("esito-\(nome).txt")
    }
    #endif
}
