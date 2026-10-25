import AVFoundation
import Foundation
import Speech

/// Eve ti ascolta, solo sul Mac: l'audio non viene mai mandato fuori dal computer.
/// Su macOS 26 e successivi usa il riconoscimento vocale nuovo di Apple (SpeechAnalyzer, sul dispositivo);
/// sui sistemi precedenti, o se quello non c'è, la dettatura classica in italiano sul dispositivo.
/// La frase finisce da sola dopo una breve pausa.
final class AscoltoEve: ObservableObject {
    enum Stato: Equatable {
        case fermo
        case ascolta
        case nonDisponibile(String)
    }

    @Published private(set) var stato = Stato.fermo
    /// Quello che Eve ha capito finora (si aggiorna mentre parli).
    @Published private(set) var trascritto = ""
    /// Cosa sta facendo Eve prima di sentirti (per esempio la prima preparazione dell'italiano).
    @Published private(set) var nota: String?
    /// Quanto suona il microfono (0…1), per l'onda: se resta fermo mentre parli, il microfono non sente.
    @Published private(set) var livello: Float = 0
    /// La frase finita: la riceve chi ha avviato l'ascolto.
    var concluso: ((String) -> Void)?
    /// Perché Eve non ha potuto ascoltare o capire: chi ha avviato l'ascolto lo fa vedere bene.
    var problema: ((String) -> Void)?

    /// Pausa dopo cui la frase si considera finita.
    static let pausa: TimeInterval = 1.6
    /// Se non dici niente entro questo tempo, Eve smette di ascoltare.
    static let attesaMassima: TimeInterval = 8
    /// Una frase non dura più di così.
    static let durataMassima: TimeInterval = 50

    private let motoreAudio = AVAudioEngine()
    private var timerPausa: Timer?
    private var timerLimite: Timer?
    private var sessione = 0
    /// Il suono più forte sentito in questa frase: distingue «microfono muto» da «non ho capito le parole».
    private var piccoMassimo: Float = 0
    /// L'ultimo errore del riconoscimento, per spiegarlo se non è arrivata nessuna parola.
    private var ultimoErrore: String?
    /// Come chiudere il riconoscimento in corso (classico o nuovo).
    private var chiudiRiconoscimento: (() -> Void)?
    /// Nel riconoscimento nuovo le frasi già confermate; quella in corso si aggiunge in coda.
    private var confermato = ""

    var ascolta: Bool { stato == .ascolta }

    /// Inizia ad ascoltare, chiedendo prima i permessi (microfono e riconoscimento vocale) se serve.
    func avvia() {
        guard stato != .ascolta else { return }
        Self.permessi { [weak self] motivo in
            guard let self else { return }
            if let motivo {
                self.segnala(motivo)
            } else {
                self.inizia()
            }
        }
    }

    /// Smette di ascoltare; con `invia` passa la frase capita finora.
    func ferma(invia: Bool) {
        guard stato == .ascolta else { return }
        sessione += 1
        timerPausa?.invalidate()
        timerLimite?.invalidate()
        if motoreAudio.isRunning { motoreAudio.stop() }
        motoreAudio.inputNode.removeTap(onBus: 0)
        chiudiRiconoscimento?()
        chiudiRiconoscimento = nil
        stato = .fermo
        livello = 0
        nota = nil
        let frase = trascritto.trimmingCharacters(in: .whitespacesAndNewlines)
        trascritto = ""
        confermato = ""
        guard invia else { return }
        if !frase.isEmpty {
            concluso?(frase)
        } else if let e = ultimoErrore {
            segnala("Non sono riuscita a capirti: \(e). Se capita sempre, controlla che la dettatura in italiano sia attiva in Impostazioni di Sistema › Tastiera › Dettatura.")
        } else if piccoMassimo < 0.01 {
            segnala("Non arriva nessun suono dal microfono. Controlla in Impostazioni di Sistema › Suono › Ingresso quale microfono è scelto, e in Privacy e sicurezza › Microfono che Prisma sia attivo.")
        } else {
            segnala("Ho sentito la tua voce ma il riconoscimento non mi ha restituito parole. Riprova; se succede ancora, scrivimi cosa vedi.")
        }
    }

    /// Dopo un errore si può riprovare: la spia torna normale.
    func azzera() {
        if case .nonDisponibile = stato { stato = .fermo }
    }

    /// Mette Eve in stato di problema e lo fa sapere a chi ha avviato l'ascolto.
    private func segnala(_ motivo: String) {
        stato = .nonDisponibile(motivo)
        problema?(motivo)
    }

    private func inizia() {
        sessione += 1
        piccoMassimo = 0
        ultimoErrore = nil
        trascritto = ""
        confermato = ""
        #if canImport(FoundationModels)
        // L'SDK di macOS 26 porta anche il riconoscimento vocale nuovo
        if #available(macOS 26.0, *) {
            iniziaNuovo(sessione)
            return
        }
        #endif
        iniziaClassico()
    }

    // MARK: - Microfono

    /// Accende il microfono e passa ogni pezzo di audio a `consegna` (sul thread dell'audio).
    /// Avvia i tempi: pausa, silenzio, durata massima.
    private func accendiMicrofono(_ consegna: @escaping (AVAudioPCMBuffer) -> Void) -> Bool {
        let ingresso = motoreAudio.inputNode
        let formato = ingresso.outputFormat(forBus: 0)
        guard formato.sampleRate > 0, formato.channelCount > 0 else {
            segnala("Non trovo nessun microfono: controlla Impostazioni di Sistema › Suono › Ingresso.")
            return false
        }
        let questa = sessione
        Self.collega(ingresso, formato: formato, consegna: consegna) { [weak self] picco in
            DispatchQueue.main.async {
                guard let self, self.sessione == questa, self.stato == .ascolta else { return }
                self.piccoMassimo = max(self.piccoMassimo, picco)
                // Solo cambi visibili: niente ridisegni inutili
                let nuovo = min(1, picco * 4)
                if abs(nuovo - self.livello) > 0.04 { self.livello = nuovo }
            }
        }
        motoreAudio.prepare()
        do {
            try motoreAudio.start()
        } catch {
            ingresso.removeTap(onBus: 0)
            segnala("Il microfono non si è avviato: \(error.localizedDescription)")
            return false
        }
        stato = .ascolta
        nota = nil
        // Se non arriva nessuna parola, Eve smette di ascoltare da sola
        timerPausa?.invalidate()
        timerPausa = Timer.scheduledTimer(withTimeInterval: Self.attesaMassima, repeats: false) { [weak self] _ in
            self?.ferma(invia: true)
        }
        timerLimite?.invalidate()
        timerLimite = Timer.scheduledTimer(withTimeInterval: Self.durataMassima, repeats: false) { [weak self] _ in
            self?.ferma(invia: true)
        }
        return true
    }

    /// Il microfono passa l'audio a chi riconosce (il blocco gira sul thread dell'audio).
    private static func collega(_ ingresso: AVAudioInputNode, formato: AVAudioFormat, consegna: @escaping (AVAudioPCMBuffer) -> Void,
                                livello: @escaping (Float) -> Void) {
        ingresso.removeTap(onBus: 0)
        var contatore = 0
        ingresso.installTap(onBus: 0, bufferSize: 1024, format: formato) { buffer, _ in
            consegna(buffer)
            // Il picco del suono, circa dieci volte al secondo
            contatore += 1
            guard contatore % 4 == 0, let canale = buffer.floatChannelData?[0] else { return }
            var picco: Float = 0
            for i in 0..<Int(buffer.frameLength) { picco = max(picco, abs(canale[i])) }
            livello(picco)
        }
    }

    /// Un pezzo di testo riconosciuto: aggiorna la frase e fa ripartire l'attesa della pausa.
    private func ricevi(_ testo: String?, finale: Bool, errore: String?, sessione questa: Int) {
        guard questa == sessione, stato == .ascolta else { return }
        if let errore { ultimoErrore = errore }
        if let testo, !testo.trimmingCharacters(in: .whitespaces).isEmpty {
            trascritto = testo
            timerPausa?.invalidate()
            timerPausa = Timer.scheduledTimer(withTimeInterval: Self.pausa, repeats: false) { [weak self] _ in
                self?.ferma(invia: true)
            }
        }
        if finale || errore != nil { ferma(invia: true) }
    }

    // MARK: - Riconoscimento classico (macOS 13–15)

    private func iniziaClassico() {
        guard let riconoscitore = SFSpeechRecognizer(locale: Locale(identifier: "it-IT")), riconoscitore.isAvailable else {
            segnala("Il riconoscimento vocale in italiano non è disponibile adesso. Controlla che la dettatura sia attiva in Impostazioni di Sistema › Tastiera › Dettatura e riprova.")
            return
        }
        guard riconoscitore.supportsOnDeviceRecognition else {
            segnala("Per ascoltarti senza mandare l'audio fuori dal Mac serve la dettatura in italiano sul dispositivo: attivala in Impostazioni di Sistema › Tastiera › Dettatura, lingua Italiano, e aspetta che finisca di scaricarsi.")
            return
        }
        let r = SFSpeechAudioBufferRecognitionRequest()
        r.requiresOnDeviceRecognition = true
        r.shouldReportPartialResults = true
        r.taskHint = .dictation
        r.addsPunctuation = true
        guard accendiMicrofono({ r.append($0) }) else { return }
        let questa = sessione
        let compito = Self.riconosci(riconoscitore, r) { [weak self] testo, finale, errore in
            DispatchQueue.main.async { self?.ricevi(testo, finale: finale, errore: errore, sessione: questa) }
        }
        chiudiRiconoscimento = {
            r.endAudio()
            compito.cancel()
        }
    }

    private static func riconosci(_ riconoscitore: SFSpeechRecognizer, _ r: SFSpeechAudioBufferRecognitionRequest,
                                  _ ricevi: @escaping (String?, Bool, String?) -> Void) -> SFSpeechRecognitionTask {
        riconoscitore.recognitionTask(with: r) { risultato, errore in
            ricevi(risultato?.bestTranscription.formattedString, risultato?.isFinal ?? false, errore?.localizedDescription)
        }
    }

    // MARK: - Riconoscimento nuovo (macOS 26 e successivi)

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func iniziaNuovo(_ questa: Int) {
        stato = .ascolta
        nota = "Mi preparo ad ascoltarti…"
        Task {
            do {
                let italiano = Locale(identifier: "it-IT")
                let supportate = await SpeechTranscriber.supportedLocales
                guard let lingua = supportate.first(where: { $0.identifier(.bcp47) == italiano.identifier(.bcp47) })
                        ?? supportate.first(where: { $0.language.languageCode == italiano.language.languageCode }) else {
                    // L'italiano qui non c'è: si torna alla dettatura classica
                    DispatchQueue.main.async { self.ripiegaSuClassico(questa) }
                    return
                }
                let trascrittore = SpeechTranscriber(locale: lingua, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
                if let scarica = try await AssetInventory.assetInstallationRequest(supporting: [trascrittore]) {
                    DispatchQueue.main.async { if self.sessione == questa { self.nota = "Preparo l'italiano sul Mac (solo la prima volta, un minuto)…" } }
                    try await scarica.downloadAndInstall()
                }
                let analizzatore = SpeechAnalyzer(modules: [trascrittore])
                guard let formato = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [trascrittore]) else {
                    throw ErroreEve(messaggio: "formato audio non disponibile")
                }
                let (flusso, ingresso) = AsyncStream<AnalyzerInput>.makeStream()
                try await analizzatore.start(inputSequence: flusso)
                let partito: Bool = await withCheckedContinuation { c in
                    DispatchQueue.main.async {
                        guard self.sessione == questa, self.stato == .ascolta else {
                            c.resume(returning: false)
                            return
                        }
                        var convertitore: AVAudioConverter?
                        let ok = self.accendiMicrofono { buffer in
                            if convertitore == nil || convertitore?.inputFormat != buffer.format {
                                convertitore = AVAudioConverter(from: buffer.format, to: formato)
                            }
                            if let convertitore, let pronto = Self.converti(buffer, con: convertitore, in: formato) {
                                ingresso.yield(AnalyzerInput(buffer: pronto))
                            }
                        }
                        if ok {
                            self.chiudiRiconoscimento = {
                                ingresso.finish()
                                Task { await analizzatore.cancelAndFinishNow() }
                            }
                        }
                        c.resume(returning: ok)
                    }
                }
                guard partito else {
                    ingresso.finish()
                    await analizzatore.cancelAndFinishNow()
                    return
                }
                for try await risultato in trascrittore.results {
                    let testo = String(risultato.text.characters)
                    let finale = risultato.isFinal
                    DispatchQueue.main.async {
                        guard self.sessione == questa else { return }
                        // Le frasi confermate restano; quella provvisoria si sostituisce a ogni aggiornamento
                        let tutto = (self.confermato + " " + testo).trimmingCharacters(in: .whitespaces)
                        if finale { self.confermato = tutto }
                        self.ricevi(tutto, finale: false, errore: nil, sessione: questa)
                    }
                }
            } catch {
                let motivo = error.localizedDescription
                DispatchQueue.main.async {
                    guard self.sessione == questa else { return }
                    if self.stato == .ascolta, self.motoreAudio.isRunning {
                        self.ultimoErrore = motivo
                        self.ferma(invia: true)
                    } else {
                        // Il riconoscimento nuovo non è partito: si prova con la dettatura classica
                        self.ripiegaSuClassico(questa)
                    }
                }
            }
        }
    }

    /// Converte l'audio del microfono nel formato che vuole il riconoscimento nuovo.
    private static func converti(_ buffer: AVAudioPCMBuffer, con convertitore: AVAudioConverter, in formato: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rapporto = formato.sampleRate / buffer.format.sampleRate
        let capacita = AVAudioFrameCount(Double(buffer.frameLength) * rapporto) + 32
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
    #endif

    private func ripiegaSuClassico(_ questa: Int) {
        guard sessione == questa else { return }
        stato = .fermo
        nota = nil
        iniziaClassico()
    }

    // MARK: - Permessi

    /// Passa nil se Eve può ascoltare, altrimenti il motivo con dove sistemarlo (sempre sul thread principale).
    static func permessi(_ esito: @escaping (String?) -> Void) {
        let microfono = "Eve non ha il permesso di usare il microfono: concedilo in Impostazioni di Sistema › Privacy e sicurezza › Microfono."
        SFSpeechRecognizer.requestAuthorization { parlato in
            guard parlato == .authorized else {
                DispatchQueue.main.async {
                    esito("Eve non ha il permesso di riconoscere la voce: concedilo in Impostazioni di Sistema › Privacy e sicurezza › Riconoscimento vocale.")
                }
                return
            }
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                DispatchQueue.main.async { esito(nil) }
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { ok in
                    DispatchQueue.main.async { esito(ok ? nil : microfono) }
                }
            default:
                DispatchQueue.main.async { esito(microfono) }
            }
        }
    }
}

/// Le frasi con cui chiudi la conversazione a voce: Eve smette di ascoltare.
enum CongedoEve {
    static func e(_ frase: String) -> Bool {
        let t = frase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let congedi = ["basta", "basta così", "fine", "stop", "grazie eve", "grazie è tutto", "è tutto", "va bene così",
                       "a dopo", "ciao eve", "puoi smettere", "smetti di ascoltare", "ok grazie", "okay grazie", "grazie basta così"]
        return congedi.contains(t) || t.hasPrefix("basta così") || t.hasSuffix("è tutto")
    }
}
