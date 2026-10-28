import AppKit
import CoreVideo
import Foundation
import QuartzCore
import SwiftUI

extension Misure {
    /// Prova guidata della fluidità sul Mac (menu Aiuto › «Prova la fluidità…», Shell/ProvaGuidata.swift).
    enum Fluidita {
        /// Un battito del thread principale più lungo di così è un blocco (s).
        static let sogliaBlocco: Double = 0.05
        /// Pause più lunghe di così non sono blocchi ma riposo del Mac o schermo spento (s).
        static let limiteBlocco: Double = 5
        /// Osservazione di ogni azione: animazione e assestamento compresi (s).
        static let tratto: Double = 1.0
        /// La misura iniziale, senza azioni (s).
        static let riposo: Double = 1.5
        /// Il passaggio del puntatore sul dock, fatto dall'utente (s).
        static let dock: Double = 6
        /// L'istruzione del dock resta a schermo prima della misura (s).
        static let preavviso: Double = 2
        /// Dopo l'avviso iniziale, prima della prima azione: l'avviso esce e la finestra torna davanti (s).
        static let attesaIniziale: Double = 0.8

        // Giudizio di un'azione
        /// «Fluida»: fotogrammi persi fino a questa quota e passo peggiore fino a due fotogrammi a 60 Hz (s).
        static let fluidaQuota: Double = 0.05
        static let fluidaPeggiore: Double = 0.034
        /// «Qualche scatto» fino a questi valori; oltre, «lenta».
        static let scattiQuota: Double = 0.2
        static let scattiPeggiore: Double = 0.1
        /// L'acqua in moto sotto queste quote del suo ritmo a riposo dà «qualche scatto» o «lenta».
        static let acquaScatti: Double = 0.85
        static let acquaLenta: Double = 0.5

        /// Il tasto Esc (codice del tasto).
        static let tastoEsc: UInt16 = 53

        // Riquadri della prova (punti)
        static let larghezzaRisultati: CGFloat = 720
        static let altezzaRisultati: CGFloat = 740
        static let larghezzaAvanzamento: CGFloat = 340
        static let staccoAvanzamento: CGFloat = 24
        static let margine: CGFloat = 20
        static let spaziatura: CGFloat = 10
        static let spaziaturaColonne: CGFloat = 14
        static let spaziaturaRighe: CGFloat = 5
        static let spaziaturaContesto: CGFloat = 3
    }
}

extension Tipo {
    // Riquadri della prova della fluidità
    static let provaTitolo = sistema(17, .bold)
    static let provaTesto = sistema(12)
    static let provaPiccolo = sistema(11)
    static let provaTesta = sistema(11, .semibold)
    static let provaTabella = sistema(11.5).monospacedDigit()
    static let provaGiudizio = sistema(11.5, .semibold)
}

/// Il cronometro della prova guidata (Shell/ProvaGuidata.swift), senza Xcode né Instruments.
/// Un CVDisplayLink batte a ogni fotogramma dello schermo e ogni battito passa dal thread principale (mai due
/// in coda): dove un battito arriva tardi, il thread principale era occupato e i fotogrammi che il passo copre
/// sono persi. Per ogni tratto (un'azione della prova) conta i fotogrammi, quelli persi, il passo peggiore,
/// i blocchi oltre 50 ms e i fotogrammi disegnati dall'acqua. Scrive in ~/Library/Logs/Prisma/fluidita.log,
/// senza dati dei clienti.
final class MisuratoreFluidita {
    static let condiviso = MisuratoreFluidita()

    /// Le misure di un tratto.
    struct Tratto {
        var durata: Double = 0
        /// Battiti serviti dal thread principale.
        var fotogrammi = 0
        var persi = 0
        /// Il passo più lungo tra due battiti serviti (s).
        var peggiore: Double = 0
        var blocchi = 0
        /// Fotogrammi disegnati dall'acqua nel tratto.
        var acqua = 0

        var attesi: Int { fotogrammi + persi }
        var quotaPersi: Double { attesi > 0 ? Double(persi) / Double(attesi) : 0 }
        var acquaAlSecondo: Double { durata > 0 ? Double(acqua) / durata : 0 }
    }

    // MARK: Fotogrammi dell'acqua (da qualsiasi thread)

    private static let serraturaAcqua = NSLock()
    private nonisolated(unsafe) static var contoAcqua = 0

    /// La chiama l'acqua (RendererAcqua) a ogni fotogramma in moto presentato, dal suo thread.
    static func segnaFotogrammaAcqua() {
        serraturaAcqua.lock()
        contoAcqua &+= 1
        serraturaAcqua.unlock()
    }

    /// Fotogrammi d'acqua disegnati dall'avvio.
    static var fotogrammiAcqua: Int {
        serraturaAcqua.lock()
        defer { serraturaAcqua.unlock() }
        return contoAcqua
    }

    // MARK: Stato

    private(set) var attivo = false
    private var link: CVDisplayLink?
    // Sotto `serratura` (thread dello schermo e principale)
    private let serratura = NSLock()
    private var battitoInCoda = false
    private var periodoSchermo: Double = 0
    // Solo dal thread principale
    private var ultimoBattito: CFTimeInterval = 0
    private var periodo: Double = 1.0 / 60
    private var aperto: Tratto?
    private var inizioTratto: CFTimeInterval = 0
    private var acquaInizio = 0

    private let scrittura = DispatchQueue(label: "prisma.fluidita", qos: .utility)

    private static var fileRegistro: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/Prisma/fluidita.log")
    }

    /// La frequenza dello schermo letta dal CVDisplayLink (Hz).
    var hertz: Int { Int((1 / max(periodo, 0.001)).rounded()) }

    // MARK: Avvio e arresto (thread principale)

    /// Accende l'orologio dello schermo (`schermo`: quello della finestra di Prisma). False se il Mac non lo dà.
    func avvia(schermo: CGDirectDisplayID?) -> Bool {
        guard !attivo else { return true }
        var nuovo: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&nuovo) == kCVReturnSuccess, let l = nuovo else { return false }
        if let schermo { _ = CVDisplayLinkSetCurrentCGDisplay(l, schermo) }
        // Il battito arriva su un thread dello schermo: passa al thread principale
        _ = CVDisplayLinkSetOutputHandler(l) { _, ora, _, _, _ in
            let t = ora.pointee
            let p = t.videoTimeScale > 0 ? Double(t.videoRefreshPeriod) / Double(t.videoTimeScale) : 0
            MisuratoreFluidita.condiviso.dalloSchermo(periodo: p)
            return kCVReturnSuccess
        }
        serratura.lock()
        battitoInCoda = false
        periodoSchermo = 0
        serratura.unlock()
        ultimoBattito = 0
        aperto = nil
        link = l
        attivo = true
        _ = CVDisplayLinkStart(l)
        return true
    }

    func ferma() {
        if let l = link { _ = CVDisplayLinkStop(l) }
        link = nil
        aperto = nil
        attivo = false
        serratura.lock()
        battitoInCoda = false
        serratura.unlock()
    }

    // MARK: Tratti (thread principale)

    /// Apre un tratto: va chiamata subito prima dell'azione, così il suo lavoro cade nel primo passo.
    func iniziaTratto() {
        guard attivo else { return }
        aperto = Tratto()
        inizioTratto = CACurrentMediaTime()
        acquaInizio = Self.fotogrammiAcqua
    }

    /// Chiude il tratto aperto e ne dà le misure.
    func chiudiTratto() -> Tratto {
        var t = aperto ?? Tratto()
        aperto = nil
        t.durata = max(0, CACurrentMediaTime() - inizioTratto)
        t.acqua = max(0, Self.fotogrammiAcqua - acquaInizio)
        return t
    }

    // MARK: Battiti

    /// Dal thread dello schermo: un battito alla volta verso il thread principale.
    private func dalloSchermo(periodo p: Double) {
        serratura.lock()
        let manda = !battitoInCoda
        battitoInCoda = true
        if p > 0 { periodoSchermo = p }
        serratura.unlock()
        guard manda else { return }
        DispatchQueue.main.async { MisuratoreFluidita.condiviso.battito() }
    }

    /// Thread principale: un passo lungo vale tutti i fotogrammi che copre.
    private func battito() {
        serratura.lock()
        battitoInCoda = false
        let p = periodoSchermo
        serratura.unlock()
        guard attivo else { return }
        let ora = CACurrentMediaTime()
        if p > 0 { periodo = p }
        let prima = ultimoBattito
        ultimoBattito = ora
        guard prima > 0, var t = aperto else { return }
        let passo = ora - prima
        guard passo < Misure.Fluidita.limiteBlocco else { return }
        t.fotogrammi += 1
        t.persi += max(0, Int((passo / periodo).rounded()) - 1)
        t.peggiore = max(t.peggiore, passo)
        if passo > Misure.Fluidita.sogliaBlocco { t.blocchi += 1 }
        aperto = t
    }

    // MARK: Registro e Mac

    /// Aggiunge il resoconto al registro (fuori dal thread principale).
    func registra(_ testo: String) {
        guard let file = Self.fileRegistro, let dati = (testo + "\n\n").data(using: .utf8) else { return }
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

    /// Un valore di sysctl in testo (per esempio "hw.model", "machdep.cpu.brand_string", "kern.osversion").
    static func valoreDiSistema(_ nome: String) -> String? {
        var lunghezza = 0
        guard sysctlbyname(nome, nil, &lunghezza, nil, 0) == 0, lunghezza > 0 else { return nil }
        var byte = [UInt8](repeating: 0, count: lunghezza)
        guard sysctlbyname(nome, &byte, &lunghezza, nil, 0) == 0 else { return nil }
        let testo = String(decoding: byte.prefix(while: { $0 != 0 }), as: UTF8.self)
        return testo.isEmpty ? nil : testo
    }

    /// L'impronta in memoria di Prisma in MB (la cifra di Monitoraggio Attività).
    static func improntaMB() -> Double {
        var info = task_vm_info_data_t()
        var conta = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let esito = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(conta)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &conta)
            }
        }
        return esito == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }
}
