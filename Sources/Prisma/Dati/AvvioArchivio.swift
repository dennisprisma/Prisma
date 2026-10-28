import Foundation

// Proprietario: G2 (ciclo di vita).

/// Lettura dell'archivio all'avvio: parte in `PrismaApp.init` (`avvia`) su una coda di fondo, mentre AppKit e
/// SwiftUI preparano la finestra e i menu; `StatoShell.init` ne prende l'esito (di solito è già pronto).
/// `Archivio.carica` usa solo FileManager e i decodificatori: niente stato del thread principale.
enum AvvioArchivio {
    typealias Esito = (dati: DatiPrisma, avviso: String?, solaLettura: Bool, bloccaRipristino: Bool)

    private static let gruppo = DispatchGroup()
    /// Si toccano solo dal thread principale.
    private static var avviata = false
    private static var consegnata = false
    /// Scritti dalla coda di fondo prima di `gruppo.leave()`, letti dopo `gruppo.wait()`.
    private static var letto: Esito?
    private static var copie = 0

    /// Fa partire la lettura (una volta sola).
    static func avvia() {
        guard !avviata else { return }
        avviata = true
        gruppo.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            letto = Archivio.carica()
            copie = Archivio.copieNonLeggibili.count
            gruppo.leave()
        }
    }

    /// L'archivio letto e il numero di copie non leggibili da sistemare. Aspetta la lettura avviata in
    /// `PrismaApp.init`; senza (o la seconda volta) legge sul momento.
    static func attendi() -> (esito: Esito, copieNonLeggibili: Int) {
        if avviata && !consegnata {
            gruppo.wait()
            consegnata = true
            if let e = letto {
                letto = nil
                return (e, copie)
            }
        }
        let e = Archivio.carica()
        return (e, Archivio.copieNonLeggibili.count)
    }

    static func esito() -> Esito {
        attendi().esito
    }
}
