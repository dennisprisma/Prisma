import AppKit
import CoreVideo
import Foundation
import QuartzCore

extension Misure {
    /// Misura della fluidità sul Mac (menu Aiuto › «Misura la fluidità»).
    enum Fluidita {
        /// Dopo ogni transizione si osserva almeno questo tempo (s).
        static let osservazione: Double = 0.5
        /// Un battito del thread principale più lungo di così è un blocco (s).
        static let sogliaBlocco: Double = 0.05
        /// Pause più lunghe di così non sono blocchi ma riposo del Mac o schermo spento (s).
        static let limiteBlocco: Double = 5
        /// Righe tenute per «Copia i risultati».
        static let righeTenute = 200
    }
}

/// Misura la fluidità sul Mac dell'utente, senza Xcode né Instruments: si accende e si spegne dal menu
/// Aiuto › «Misura la fluidità». Un CVDisplayLink batte a ogni fotogramma dello schermo e ogni battito passa
/// dal thread principale: dove i battiti arrivano in ritardo, il thread principale era occupato e quei
/// fotogrammi sono persi. Conta i fotogrammi persi nelle transizioni (`.prismaTransizione`) e i blocchi
/// oltre 50 ms. Scrive in ~/Library/Logs/Prisma/fluidita.log, senza dati dei clienti.
final class MisuratoreFluidita {
    static let condiviso = MisuratoreFluidita()

    /// Una transizione osservata.
    private struct Osservazione {
        let durata: Double
        var fine: CFTimeInterval
        var fotogrammi = 0
        var persi = 0
        var peggiore: Double = 0
    }

    private(set) var attivo = false
    private var link: CVDisplayLink?
    private var osservatore: NSObjectProtocol?

    // Solo dal thread principale
    private var ultimoBattito: CFTimeInterval = 0
    private var periodo: Double = 1.0 / 60
    private var osservazione: Osservazione?
    private var transizioni = 0
    private var fotogrammi = 0
    private var persi = 0
    private var blocchi = 0
    private var bloccoPeggiore: Double = 0
    private var righe: [String] = []

    private let scrittura = DispatchQueue(label: "prisma.fluidita", qos: .utility)
    private let orario: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static var fileRegistro: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/Prisma/fluidita.log")
    }

    /// Accende la misura (con un avviso) o la spegne e mostra i risultati, con «Copia i risultati».
    @MainActor func alterna() {
        if attivo {
            ferma()
            mostraRisultati()
        } else if avvia() {
            let avviso = NSAlert()
            avviso.messageText = "Misura della fluidità accesa"
            avviso.informativeText = "Usa Prisma come sempre: apri e chiudi le app, passa dall'una all'altra, blocca e sblocca. "
                + "Per vedere i risultati scegli di nuovo Aiuto › Misura la fluidità.\n\n"
                + "Nei risultati non ci sono dati dei clienti; restano anche in ~/Library/Logs/Prisma/fluidita.log."
            _ = avviso.runModal()
        } else {
            let avviso = NSAlert()
            avviso.messageText = "La misura della fluidità non è disponibile"
            avviso.informativeText = "Il Mac non ha dato l'orologio dello schermo (CVDisplayLink)."
            _ = avviso.runModal()
        }
    }

    // MARK: Avvio e arresto

    private func avvia() -> Bool {
        var nuovo: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&nuovo) == kCVReturnSuccess, let l = nuovo else { return false }
        // Il battito arriva su un thread dello schermo: si passa al thread principale
        CVDisplayLinkSetOutputHandler(l) { _, ora, _, _, _ in
            let t = ora.pointee
            let p = t.videoTimeScale > 0 ? Double(t.videoRefreshPeriod) / Double(t.videoTimeScale) : 0
            DispatchQueue.main.async { MisuratoreFluidita.condiviso.battito(periodo: p) }
            return kCVReturnSuccess
        }
        ultimoBattito = 0
        osservazione = nil
        transizioni = 0
        fotogrammi = 0
        persi = 0
        blocchi = 0
        bloccoPeggiore = 0
        righe = []
        osservatore = NotificationCenter.default.addObserver(forName: .prismaTransizione, object: nil, queue: .main) { [weak self] nota in
            self?.transizione(durata: (nota.userInfo?["durata"] as? Double) ?? 0)
        }
        link = l
        attivo = true
        annota("misura accesa · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        CVDisplayLinkStart(l)
        return true
    }

    private func ferma() {
        if let l = link { CVDisplayLinkStop(l) }
        link = nil
        if let o = osservatore { NotificationCenter.default.removeObserver(o) }
        osservatore = nil
        if let o = osservazione { chiudi(o) }
        osservazione = nil
        attivo = false
        annota("misura spenta · \(riepilogo.replacingOccurrences(of: "\n", with: " · "))")
    }

    // MARK: Battiti e transizioni (thread principale)

    private func battito(periodo p: Double) {
        guard attivo else { return }
        let ora = CACurrentMediaTime()
        if p > 0 { periodo = p }
        defer { ultimoBattito = ora }
        guard ultimoBattito > 0 else { return }
        let passo = ora - ultimoBattito
        if passo > Misure.Fluidita.sogliaBlocco && passo < Misure.Fluidita.limiteBlocco {
            blocchi += 1
            bloccoPeggiore = max(bloccoPeggiore, passo)
            annota("thread principale fermo per \(ms(passo)) ms")
        }
        guard var o = osservazione else { return }
        o.fotogrammi += 1
        // I battiti arretrati arrivano tutti insieme: un passo lungo vale tutti i fotogrammi che copre
        o.persi += max(0, Int((passo / periodo).rounded()) - 1)
        o.peggiore = max(o.peggiore, passo)
        if ora >= o.fine {
            chiudi(o)
            osservazione = nil
        } else {
            osservazione = o
        }
    }

    private func transizione(durata: Double) {
        guard attivo else { return }
        let fine = CACurrentMediaTime() + max(durata, Misure.Fluidita.osservazione)
        if var o = osservazione {
            o.fine = max(o.fine, fine)   // transizioni sovrapposte: un'osservazione sola
            osservazione = o
        } else {
            osservazione = Osservazione(durata: durata, fine: fine)
        }
    }

    private func chiudi(_ o: Osservazione) {
        transizioni += 1
        fotogrammi += o.fotogrammi
        persi += o.persi
        annota("transizione di \(ms(o.durata)) ms: \(o.persi) fotogrammi persi su \(o.fotogrammi + o.persi), "
            + "passo peggiore \(ms(o.peggiore)) ms")
    }

    private func ms(_ secondi: Double) -> Int { Int((secondi * 1000).rounded()) }

    // MARK: Registro e risultati

    private var riepilogo: String {
        let totale = fotogrammi + persi
        let quota = totale > 0 ? Int((Double(persi) / Double(totale) * 100).rounded()) : 0
        let hertz = Int((1 / max(periodo, 0.001)).rounded())
        var testo = "Transizioni osservate: \(transizioni)\n"
        testo += "Fotogrammi persi nelle transizioni: \(persi) su \(totale) (\(quota) %)\n"
        testo += "Blocchi del thread principale oltre \(ms(Misure.Fluidita.sogliaBlocco)) ms: \(blocchi)"
        if blocchi > 0 { testo += " (il più lungo \(ms(bloccoPeggiore)) ms)" }
        testo += "\nSchermo a \(hertz) Hz"
        return testo
    }

    private func annota(_ testo: String) {
        let riga = "\(orario.string(from: Date()))  \(testo)"
        righe.append(riga)
        if righe.count > Misure.Fluidita.righeTenute { righe.removeFirst(righe.count - Misure.Fluidita.righeTenute) }
        guard let file = Self.fileRegistro, let dati = (riga + "\n").data(using: .utf8) else { return }
        scrittura.async {
            let fm = FileManager.default
            try? fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fm.fileExists(atPath: file.path) { fm.createFile(atPath: file.path, contents: nil) }
            guard let h = try? FileHandle(forWritingTo: file) else { return }
            defer { _ = try? h.close() }
            _ = try? h.seekToEnd()
            _ = try? h.write(contentsOf: dati)
        }
    }

    @MainActor private func mostraRisultati() {
        let testo = riepilogo + "\n\n" + righe.joined(separator: "\n")
        let avviso = NSAlert()
        avviso.messageText = "Fluidità di Prisma"
        avviso.informativeText = riepilogo + "\n\nIl registro completo è in ~/Library/Logs/Prisma/fluidita.log."
        avviso.addButton(withTitle: "Copia i risultati")
        avviso.addButton(withTitle: "Chiudi")
        if avviso.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(testo, forType: .string)
        }
    }
}
