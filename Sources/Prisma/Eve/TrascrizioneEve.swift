import AVFoundation
import Foundation
import Speech

/// Chi trasforma l'audio in parole, sul Mac. Riceve l'audio a pezzi (dal microfono o, nella prova, dalla voce
/// di Eve) e racconta cosa ha capito: testo finora, se ha finito, l'eventuale errore.
protocol TrascrizioneEve: AnyObject {
    var nome: String { get }
    /// Testo capito finora (nil se invariato), fine del riconoscimento, errore. Arriva da un thread qualsiasi.
    var aggiornamento: ((String?, Bool, String?) -> Void)? { get set }
    func aggiungi(_ buffer: AVAudioPCMBuffer)
    /// L'audio è finito: il riconoscimento consegna il testo definitivo e poi chiude.
    func finisci()
    /// Lascia perdere subito.
    func annulla()
}

/// Quale riconoscimento usare (dalle impostazioni di Eve).
enum SceltaRiconoscimento: String, Codable, CaseIterable, Identifiable {
    case automatico, nuovo, classico
    /// La dettatura di macOS (quella del tasto microfono / fn): scrive nel campo di Eve, che manda la frase alla pausa.
    case dettatura

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .automatico: return "Automatico"
        case .nuovo: return "Nuovo (macOS 26+)"
        case .classico: return "Dettatura classica"
        case .dettatura: return "Dettatura di macOS"
        }
    }
}

enum Trascrizioni {
    /// Prepara il riconoscimento scelto (sul Mac). `avviso` racconta i passaggi lunghi (il primo scaricamento dell'italiano).
    /// Restituisce il riconoscimento oppure il motivo per cui non c'è.
    static func prepara(_ scelta: SceltaRiconoscimento, avviso: @escaping (String) -> Void) async -> Result<TrascrizioneEve, ErroreEve> {
        var motivoNuovo: String?
        #if canImport(FoundationModels)
        if scelta == .automatico || scelta == .nuovo, #available(macOS 26.0, *) {
            do {
                if let t = try await TrascrizioneNuova.prepara(avviso: avviso) { return .success(t) }
                motivoNuovo = "l'italiano non è tra le lingue del riconoscimento nuovo"
            } catch {
                motivoNuovo = DiagnosticaVoce.descrivi(error)
            }
            DiagnosticaVoce.annota("Riconoscimento nuovo non disponibile: \(motivoNuovo ?? "")")
            if scelta == .nuovo { return .failure(ErroreEve(messaggio: "Il riconoscimento nuovo non è partito: \(motivoNuovo ?? "motivo sconosciuto").")) }
        }
        #endif
        if scelta == .dettatura {
            return .failure(ErroreEve(messaggio: "La dettatura di macOS scrive nel campo di Eve: non si prova qui."))
        }
        if scelta == .nuovo, motivoNuovo == nil {
            return .failure(ErroreEve(messaggio: "Il riconoscimento nuovo richiede macOS 26 o successivo."))
        }
        return TrascrizioneClassica.crea()
    }
}

// MARK: - Dettatura classica (SFSpeechRecognizer, sul dispositivo)

final class TrascrizioneClassica: TrascrizioneEve {
    let nome = "dettatura classica"
    var aggiornamento: ((String?, Bool, String?) -> Void)?

    /// Il riconoscitore va tenuto in vita finché lavora: se si libera, il riconoscimento si ferma senza dire niente.
    private let riconoscitore: SFSpeechRecognizer
    private let richiesta = SFSpeechAudioBufferRecognitionRequest()
    private var compito: SFSpeechRecognitionTask?

    static func crea() -> Result<TrascrizioneEve, ErroreEve> {
        guard let r = SFSpeechRecognizer(locale: Locale(identifier: "it-IT")) else {
            return .failure(ErroreEve(messaggio: "La dettatura classica non conosce l'italiano su questo Mac."))
        }
        DiagnosticaVoce.annota("Dettatura classica: disponibile \(r.isAvailable), sul dispositivo \(r.supportsOnDeviceRecognition), permesso \(SFSpeechRecognizer.authorizationStatus().rawValue)")
        guard r.isAvailable else {
            return .failure(ErroreEve(messaggio: "Il riconoscimento vocale in italiano non è disponibile adesso. Controlla che la dettatura sia attiva in Impostazioni di Sistema › Tastiera › Dettatura e riprova."))
        }
        guard r.supportsOnDeviceRecognition else {
            return .failure(ErroreEve(messaggio: "Per ascoltarti senza mandare l'audio fuori dal Mac serve la dettatura in italiano sul dispositivo: attivala in Impostazioni di Sistema › Tastiera › Dettatura, lingua Italiano, e aspetta che finisca di scaricarsi."))
        }
        return .success(TrascrizioneClassica(r))
    }

    private init(_ r: SFSpeechRecognizer) {
        riconoscitore = r
        richiesta.requiresOnDeviceRecognition = true
        richiesta.shouldReportPartialResults = true
        richiesta.taskHint = .dictation
        richiesta.addsPunctuation = true
        compito = riconoscitore.recognitionTask(with: richiesta) { [weak self] risultato, errore in
            let testo = risultato?.bestTranscription.formattedString
            let fine = (risultato?.isFinal ?? false) || errore != nil
            if let errore { DiagnosticaVoce.annota("Dettatura classica, errore: \(DiagnosticaVoce.descrivi(errore))") }
            self?.aggiornamento?(testo, fine, errore.map(DiagnosticaVoce.descrivi))
        }
    }

    func aggiungi(_ buffer: AVAudioPCMBuffer) { richiesta.append(buffer) }
    func finisci() { richiesta.endAudio() }

    func annulla() {
        richiesta.endAudio()
        compito?.cancel()
    }
}

// MARK: - Riconoscimento nuovo (SpeechAnalyzer, macOS 26 e successivi)

#if canImport(FoundationModels)
@available(macOS 26.0, *)
final class TrascrizioneNuova: TrascrizioneEve {
    let nome = "riconoscimento nuovo"
    var aggiornamento: ((String?, Bool, String?) -> Void)?

    private let analizzatore: SpeechAnalyzer
    private let trascrittore: SpeechTranscriber
    private let formato: AVAudioFormat
    private let ingresso: AsyncStream<AnalyzerInput>.Continuation
    /// Usato solo dal thread che consegna l'audio.
    private var convertitore: AVAudioConverter?
    private var confermato = ""
    private var pezzi = 0

    /// nil se l'italiano non c'è; un errore se la preparazione non riesce.
    static func prepara(avviso: @escaping (String) -> Void) async throws -> TrascrizioneNuova? {
        let italiano = Locale(identifier: "it-IT")
        let supportate = await SpeechTranscriber.supportedLocales
        guard let lingua = supportate.first(where: { $0.identifier(.bcp47) == italiano.identifier(.bcp47) })
                ?? supportate.first(where: { $0.language.languageCode == italiano.language.languageCode }) else {
            DiagnosticaVoce.annota("Riconoscimento nuovo: lingue \(supportate.prefix(12).map { $0.identifier(.bcp47) }.joined(separator: ", "))…")
            return nil
        }
        let trascrittore = SpeechTranscriber(locale: lingua, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
        if let scarica = try await AssetInventory.assetInstallationRequest(supporting: [trascrittore]) {
            avviso("Preparo l'italiano sul Mac (solo la prima volta, un minuto)…")
            DiagnosticaVoce.annota("Riconoscimento nuovo: scarico l'italiano")
            try await scarica.downloadAndInstall()
        }
        let analizzatore = SpeechAnalyzer(modules: [trascrittore])
        guard let formato = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [trascrittore]) else {
            throw ErroreEve(messaggio: "nessun formato audio adatto")
        }
        let (flusso, ingresso) = AsyncStream<AnalyzerInput>.makeStream()
        try await analizzatore.start(inputSequence: flusso)
        DiagnosticaVoce.annota("Riconoscimento nuovo: lingua \(lingua.identifier(.bcp47)), formato \(DiagnosticaVoce.descrivi(formato))")
        return TrascrizioneNuova(analizzatore, trascrittore, formato, ingresso)
    }

    private init(_ a: SpeechAnalyzer, _ t: SpeechTranscriber, _ f: AVAudioFormat, _ i: AsyncStream<AnalyzerInput>.Continuation) {
        analizzatore = a
        trascrittore = t
        formato = f
        ingresso = i
        Task { [weak self] in await self?.leggi() }
    }

    private func leggi() async {
        var risposte = 0
        do {
            for try await risultato in trascrittore.results {
                risposte += 1
                let testo = String(risultato.text.characters)
                // Le frasi confermate restano; quella provvisoria si sostituisce a ogni aggiornamento
                let tutto = (confermato + " " + testo).trimmingCharacters(in: .whitespaces)
                if risultato.isFinal { confermato = tutto }
                aggiornamento?(tutto, false, nil)
            }
            DiagnosticaVoce.annota("Riconoscimento nuovo: finito, \(risposte) risposte, \(pezzi) pezzi di audio")
            aggiornamento?(nil, true, nil)
        } catch {
            DiagnosticaVoce.annota("Riconoscimento nuovo, errore: \(DiagnosticaVoce.descrivi(error)) dopo \(risposte) risposte")
            aggiornamento?(nil, true, DiagnosticaVoce.descrivi(error))
        }
    }

    func aggiungi(_ buffer: AVAudioPCMBuffer) {
        if convertitore == nil || convertitore?.inputFormat != buffer.format {
            convertitore = AVAudioConverter(from: buffer.format, to: formato)
            DiagnosticaVoce.annota("Riconoscimento nuovo: audio in ingresso \(DiagnosticaVoce.descrivi(buffer.format))")
        }
        guard let convertitore, let pronto = Self.converti(buffer, con: convertitore, in: formato) else { return }
        pezzi += 1
        ingresso.yield(AnalyzerInput(buffer: pronto))
    }

    func finisci() {
        ingresso.finish()
        let a = analizzatore
        Task { try? await a.finalizeAndFinishThroughEndOfInput() }
    }

    func annulla() {
        ingresso.finish()
        let a = analizzatore
        Task { await a.cancelAndFinishNow() }
    }

    /// Converte l'audio nel formato che vuole il riconoscimento.
    private static func converti(_ buffer: AVAudioPCMBuffer, con convertitore: AVAudioConverter, in formato: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rapporto = formato.sampleRate / buffer.format.sampleRate
        let capacita = AVAudioFrameCount(Double(buffer.frameLength) * rapporto) + 64
        guard let uscita = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: capacita) else { return nil }
        var consegnato = false
        var errore: NSError?
        convertitore.convert(to: uscita, error: &errore) { _, stato in
            if consegnato {
                stato.pointee = .noDataNow
                return nil
            }
            consegnato = true
            stato.pointee = .haveData
            return buffer
        }
        return errore == nil && uscita.frameLength > 0 ? uscita : nil
    }
}
#endif

// MARK: - Diagnostica

/// Gli ultimi passaggi dell'ascolto, per capire cosa non va (si copiano dalle impostazioni). Niente audio, niente testi detti.
enum DiagnosticaVoce {
    private static let coda = DispatchQueue(label: "prisma.diagnostica.voce")
    private static var righe: [String] = []

    static func annota(_ riga: String) {
        let ora = Formati.formato("HH:mm:ss").string(from: Date())
        coda.sync {
            righe.append("\(ora) \(riga)")
            if righe.count > 60 { righe.removeFirst(righe.count - 60) }
        }
    }

    static var testo: String {
        let r = coda.sync { righe }
        let sistema = ProcessInfo.processInfo.operatingSystemVersionString
        return (["Prisma · diagnostica dell'ascolto · macOS \(sistema)"] + r).joined(separator: "\n")
    }

    static func descrivi(_ e: Error) -> String {
        let ns = e as NSError
        return "\(e.localizedDescription) [\(ns.domain) \(ns.code)]"
    }

    static func descrivi(_ f: AVAudioFormat) -> String {
        "\(Int(f.sampleRate)) Hz, \(f.channelCount) canali, formato \(f.commonFormat.rawValue)\(f.isInterleaved ? ", interlacciato" : "")"
    }
}
