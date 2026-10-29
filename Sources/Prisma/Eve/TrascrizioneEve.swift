import AVFoundation
import Foundation
import Speech

/// Chi trasforma l'audio in parole, sul Mac. Riceve l'audio a pezzi (dal microfono o, nella prova, dalla voce
/// di Eve) e racconta cosa ha capito: testo finora, se ha finito, l'eventuale errore.
protocol TrascrizioneEve: AnyObject {
    var nome: String { get }
    /// Quale riconoscimento è (per i ripieghi dell'automatico).
    var scelta: SceltaRiconoscimento { get }
    /// Testo capito finora (nil se invariato), fine del riconoscimento, errore. Arriva da un thread qualsiasi.
    var aggiornamento: ((String?, Bool, String?) -> Void)? { get set }
    func aggiungi(_ buffer: AVAudioPCMBuffer)
    /// L'audio è finito: il riconoscimento consegna il testo definitivo e poi chiude.
    func finisci()
    /// Lascia perdere subito.
    func annulla()
}

/// Quale riconoscimento vocale usare per ascoltarti (sempre sul Mac).
enum SceltaRiconoscimento: String, Codable, CaseIterable, Identifiable {
    case automatico, nuovo
    /// I modelli della dettatura di sistema di macOS, dentro Prisma (DictationTranscriber, macOS 26+).
    case dettaturaSistema
    case classico
    /// La dettatura di macOS (quella del tasto microfono / fn): scrive nel campo di Eve, che manda la frase alla pausa.
    case dettatura

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .automatico: return "Automatico"
        case .nuovo: return "Nuovo (macOS 26+)"
        case .dettaturaSistema: return "Dettatura di sistema (macOS 26+)"
        case .classico: return "Dettatura classica"
        case .dettatura: return "Dettatura di macOS"
        }
    }

    /// I riconoscimenti dentro Prisma che l'automatico prova in ordine su questo Mac (poi la dettatura di macOS).
    static var catenaAutomatica: [SceltaRiconoscimento] {
        if #available(macOS 26.0, iOS 26.0, *) { return [.nuovo, .dettaturaSistema, .classico] }
        return [.classico]
    }
}

enum Trascrizioni {
    /// Prepara il riconoscimento scelto (sul Mac). `avviso` racconta i passaggi lunghi (il primo scaricamento dell'italiano).
    /// Restituisce il riconoscimento oppure il motivo per cui non c'è.
    static func prepara(_ scelta: SceltaRiconoscimento, avviso: @escaping (String) -> Void) async -> Result<TrascrizioneEve, ErroreEve> {
        switch scelta {
        case .dettatura:
            return .failure(ErroreEve(messaggio: "La dettatura di macOS scrive nel campo di Eve: non si prova qui."))
        case .automatico:
            // Il primo anello della catena; i successivi li decide chi ascolta (VoceShell.problemaAscolto)
            let primo = await prepara(SceltaRiconoscimento.catenaAutomatica.first ?? .classico, avviso: avviso)
            if case .success = primo { return primo }
            if case .failure(let e) = primo { DiagnosticaVoce.annota("Automatico: \(e.messaggio) Uso la dettatura classica.") }
            return TrascrizioneClassica.crea()
        case .nuovo, .dettaturaSistema:
            #if canImport(FoundationModels)
            if #available(macOS 26.0, iOS 26.0, *) {
                do {
                    if let t = try await TrascrizioneNuova.prepara(dettatura: scelta == .dettaturaSistema, avviso: avviso) { return .success(t) }
                    return .failure(ErroreEve(messaggio: "L'italiano non è tra le lingue di «\(scelta.nome)»."))
                } catch {
                    return .failure(ErroreEve(messaggio: "«\(scelta.nome)» non è partito: \(DiagnosticaVoce.descrivi(error))."))
                }
            }
            #endif
            return .failure(ErroreEve(messaggio: "«\(scelta.nome)» richiede macOS 26 o successivo."))
        case .classico:
            return TrascrizioneClassica.crea()
        }
    }
}

// MARK: - Dettatura classica (SFSpeechRecognizer, sul dispositivo)

final class TrascrizioneClassica: TrascrizioneEve {
    let nome = "dettatura classica"
    let scelta = SceltaRiconoscimento.classico
    var aggiornamento: ((String?, Bool, String?) -> Void)?

    /// Il riconoscitore va tenuto in vita finché lavora: se si libera, il riconoscimento si ferma senza dire niente.
    private let riconoscitore: SFSpeechRecognizer
    private let richiesta = SFSpeechAudioBufferRecognitionRequest()
    private var compito: SFSpeechRecognitionTask?
    private var primoRisultato = false

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
            if let r = risultato, self?.primoRisultato == false {
                self?.primoRisultato = true
                DiagnosticaVoce.annota("Dettatura classica: primo risultato (\(r.bestTranscription.formattedString.count) caratteri)")
            }
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
@available(macOS 26.0, iOS 26.0, *)
final class TrascrizioneNuova: TrascrizioneEve {
    /// Il modulo di Apple che trascrive: il riconoscimento nuovo o i modelli della dettatura di sistema.
    private enum Modulo {
        case trascrittore(SpeechTranscriber)
        case dettatura(DictationTranscriber)

        var qualsiasi: any SpeechModule {
            switch self {
            case .trascrittore(let t): return t
            case .dettatura(let d): return d
            }
        }
    }

    let nome: String
    let scelta: SceltaRiconoscimento
    var aggiornamento: ((String?, Bool, String?) -> Void)?

    private let analizzatore: SpeechAnalyzer
    private let modulo: Modulo
    private let formato: AVAudioFormat
    private let ingresso: AsyncStream<AnalyzerInput>.Continuation
    /// Usati solo dal thread che consegna l'audio.
    private var convertitore: AVAudioConverter?
    private var pezzi = 0
    private var scartati = 0
    private var confermato = ""

    /// nil se l'italiano non c'è; un errore se la preparazione non riesce.
    static func prepara(dettatura: Bool, avviso: @escaping (String) -> Void) async throws -> TrascrizioneNuova? {
        let nome = dettatura ? "dettatura di sistema" : "riconoscimento nuovo"
        let italiano = Locale(identifier: "it-IT")
        let supportate = dettatura ? await DictationTranscriber.supportedLocales : await SpeechTranscriber.supportedLocales
        let elenco = supportate.prefix(12).map { $0.identifier(.bcp47) }.joined(separator: ", ")
        if !dettatura { DiagnosticaVoce.lingueNuovo = elenco }
        guard let lingua = supportate.first(where: { $0.identifier(.bcp47) == italiano.identifier(.bcp47) })
                ?? supportate.first(where: { $0.language.languageCode == italiano.language.languageCode }) else {
            DiagnosticaVoce.annota("\(nome): italiano assente, lingue \(elenco)…")
            return nil
        }
        let modulo: Modulo = dettatura
            // Il preset di Apple per la dettatura dal vivo di frasi brevi
            ? .dettatura(DictationTranscriber(locale: lingua, preset: .progressiveShortDictation))
            // Risultati provvisori frequenti (.fastResults): le parole compaiono mentre parli
            : .trascrittore(SpeechTranscriber(locale: lingua, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: []))
        var t = Date()
        if let scarica = try await AssetInventory.assetInstallationRequest(supporting: [modulo.qualsiasi]) {
            avviso("Preparo l'italiano sul Mac (solo la prima volta, qualche minuto)…")
            DiagnosticaVoce.annota("\(nome): scarico l'italiano")
            try await scarica.downloadAndInstall()
            DiagnosticaVoce.annota("\(nome): italiano scaricato in \(secondi(t))")
        }
        // Il modello resta un po' in memoria dopo la frase: la successiva non lo ricarica (non per tutta la vita del processo: il Mac ha 8 GB)
        let analizzatore = SpeechAnalyzer(modules: [modulo.qualsiasi],
                                          options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering))
        guard let formato = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [modulo.qualsiasi]) else {
            throw ErroreEve(messaggio: "nessun formato audio adatto")
        }
        // Il modello si carica adesso, a microfono spento: altrimenti i primi secondi di voce lo aspettano
        t = Date()
        do {
            try await analizzatore.prepareToAnalyze(in: formato)
            DiagnosticaVoce.annota("\(nome): modello pronto in \(secondi(t))")
        } catch {
            DiagnosticaVoce.annota("\(nome): preriscaldamento non riuscito (\(DiagnosticaVoce.descrivi(error))), parto lo stesso")
        }
        let (flusso, ingresso) = AsyncStream<AnalyzerInput>.makeStream()
        try await analizzatore.start(inputSequence: flusso)
        DiagnosticaVoce.annota("\(nome): lingua \(lingua.identifier(.bcp47)), formato \(DiagnosticaVoce.descrivi(formato))")
        return TrascrizioneNuova(analizzatore, modulo, formato, ingresso, nome: nome, scelta: dettatura ? .dettaturaSistema : .nuovo)
    }

    private init(_ a: SpeechAnalyzer, _ m: Modulo, _ f: AVAudioFormat, _ i: AsyncStream<AnalyzerInput>.Continuation, nome: String, scelta: SceltaRiconoscimento) {
        analizzatore = a
        modulo = m
        formato = f
        ingresso = i
        self.nome = nome
        self.scelta = scelta
        Task { [weak self] in await self?.leggi() }
    }

    private static func secondi(_ da: Date) -> String { String(format: "%.1f s", Date().timeIntervalSince(da)) }

    private func leggi() async {
        var risposte = 0
        do {
            switch modulo {
            case .trascrittore(let t):
                for try await r in t.results {
                    risposte += 1
                    consegna(String(r.text.characters), finale: r.isFinal)
                }
            case .dettatura(let d):
                for try await r in d.results {
                    risposte += 1
                    consegna(String(r.text.characters), finale: r.isFinal)
                }
            }
            let muto = risposte == 0 && pezzi > 0 ? " (audio arrivato, nessuna parola)" : ""
            DiagnosticaVoce.annota("\(nome): finito, \(risposte) risposte, \(pezzi) pezzi di audio\(muto)")
            aggiornamento?(nil, true, nil)
        } catch {
            DiagnosticaVoce.annota("\(nome), errore: \(DiagnosticaVoce.descrivi(error)) dopo \(risposte) risposte, \(pezzi) pezzi")
            aggiornamento?(nil, true, DiagnosticaVoce.descrivi(error))
        }
    }

    /// Le frasi confermate restano; quella provvisoria si sostituisce a ogni aggiornamento.
    private func consegna(_ testo: String, finale: Bool) {
        let tutto = (confermato + " " + testo).trimmingCharacters(in: .whitespaces)
        if finale { confermato = tutto }
        aggiornamento?(tutto, false, nil)
    }

    func aggiungi(_ buffer: AVAudioPCMBuffer) {
        if convertitore == nil || convertitore?.inputFormat != buffer.format {
            convertitore = AVAudioConverter(from: buffer.format, to: formato)
            // Come nell'esempio Apple: niente campioni trattenuti dal convertitore
            convertitore?.primeMethod = .none
            DiagnosticaVoce.annota("\(nome): audio in ingresso \(DiagnosticaVoce.descrivi(buffer.format))\(convertitore == nil ? ", CONVERTITORE NON CREATO" : "")")
        }
        guard let convertitore, let pronto = Self.converti(buffer, con: convertitore, in: formato) else {
            scartati += 1
            if scartati == 1 { DiagnosticaVoce.annota("\(nome): un pezzo di audio non si è convertito") }
            return
        }
        pezzi += 1
        if pezzi == 1 { DiagnosticaVoce.annota("\(nome): primo pezzo di audio all'analizzatore") }
        ingresso.yield(AnalyzerInput(buffer: pronto))
    }

    func finisci() {
        ingresso.finish()
        let a = analizzatore, n = nome, t = Date()
        Task {
            do {
                try await a.finalizeAndFinishThroughEndOfInput()
                DiagnosticaVoce.annota("\(n): finalizzazione in \(Self.secondi(t))")
            } catch {
                DiagnosticaVoce.annota("\(n): finalizzazione interrotta (\(DiagnosticaVoce.descrivi(error)))")
            }
        }
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

/// Gli ultimi passaggi dell'ascolto e della voce, con i secondi dall'inizio dell'ascolto: si copiano dalle
/// impostazioni e, in modalità diagnostica, l'ultimo si legge sotto il campo di Eve. Niente audio, niente testi detti.
enum DiagnosticaVoce {
    private static let coda = DispatchQueue(label: "prisma.diagnostica.voce")
    private static var righe: [String] = []
    private static var inizio = Date()
    private static let orologio = Formati.formato("HH:mm:ss")
    /// Le lingue del riconoscimento nuovo viste all'ultima preparazione (per il riepilogo).
    static var lingueNuovo: String?
    /// Chi vuole l'ultima riga appena scritta (la vista di Eve), chiamato sul thread principale.
    static var osservatore: ((String) -> Void)?

    /// Da chiamare all'inizio di un ascolto: le righe seguenti riportano i secondi da qui.
    static func inizia(_ riga: String) {
        coda.sync { inizio = Date() }
        annota(riga)
    }

    static func annota(_ riga: String) {
        let adesso = Date()
        let completa: String = coda.sync {
            let r = "\(orologio.string(from: adesso)) \(String(format: "+%5.2fs", adesso.timeIntervalSince(inizio))) \(riga)"
            righe.append(r)
            if righe.count > 80 { righe.removeFirst(righe.count - 80) }
            return r
        }
        if let osservatore { DispatchQueue.main.async { osservatore(completa) } }
    }

    /// Le righe, con l'intestazione (senza impostazioni: per le prove).
    static var testo: String {
        let r = coda.sync { righe }
        return (["Prisma · diagnostica dell'ascolto · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"] + r).joined(separator: "\n")
    }

    /// Ambiente, permessi e impostazioni: la prima cosa da leggere in una diagnostica.
    static func riepilogo(_ eve: ImpostazioniEve) -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let versione = "\(info["CFBundleShortVersionString"] as? String ?? "–") (\(info["PrismaCommit"] as? String ?? "commit sconosciuto"))"
        #if arch(arm64)
        let chip = "Apple Silicon"
        #else
        let chip = "Intel"
        #endif
        let classico = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
        let statoClassico = classico.map { "disponibile \($0.isAvailable), sul dispositivo \($0.supportsOnDeviceRecognition)" } ?? "assente"
        return """
        Prisma \(versione) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · \(chip)
        Permessi: riconoscimento vocale \(SFSpeechRecognizer.authorizationStatus().rawValue) (3 = concesso), microfono \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue) (3 = concesso)
        Impostazioni: riconoscimento \(eve.riconoscimento.rawValue), risposte a voce \(eve.risposteAVoce.rawValue), conversazione continua \(eve.conversazioneContinua), voce \(eve.voce ?? "automatica")
        Dettatura classica (it-IT): \(statoClassico)
        Riconoscimento nuovo: lingue \(lingueNuovo ?? "non ancora interrogato")
        Voci italiane: \(VoceEve.vociItaliane().map(VoceEve.nome).joined(separator: ", "))
        """
    }

    static func descrivi(_ e: Error) -> String {
        let ns = e as NSError
        return "\(e.localizedDescription) [\(ns.domain) \(ns.code)]"
    }

    static func descrivi(_ f: AVAudioFormat) -> String {
        "\(Int(f.sampleRate)) Hz, \(f.channelCount) canali, formato \(f.commonFormat.rawValue)\(f.isInterleaved ? ", interlacciato" : "")"
    }
}
