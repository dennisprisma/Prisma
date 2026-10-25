import AVFoundation
import Foundation
import Speech

/// Eve ti ascolta: il riconoscimento vocale di macOS in italiano, solo sul dispositivo. Se il Mac non sa
/// riconoscere l'italiano senza internet, Eve non ascolta (l'audio non viene mai mandato ai server di Apple).
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
    /// La frase finita: la riceve chi ha avviato l'ascolto.
    var concluso: ((String) -> Void)?

    /// Pausa dopo cui la frase si considera finita.
    static let pausa: TimeInterval = 1.6
    /// Se non dici niente entro questo tempo, Eve smette di ascoltare.
    static let attesaMassima: TimeInterval = 8
    /// Una frase non dura più di così (il riconoscimento di Apple regge circa un minuto).
    static let durataMassima: TimeInterval = 50

    private let riconoscitore = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
    private let motoreAudio = AVAudioEngine()
    private var richiesta: SFSpeechAudioBufferRecognitionRequest?
    private var compito: SFSpeechRecognitionTask?
    private var timerPausa: Timer?
    private var timerLimite: Timer?
    private var sessione = 0

    var ascolta: Bool { stato == .ascolta }

    /// Inizia ad ascoltare, chiedendo prima i permessi (microfono e riconoscimento vocale) se serve.
    func avvia() {
        guard stato != .ascolta else { return }
        Self.permessi { [weak self] motivo in
            guard let self else { return }
            if let motivo {
                self.stato = .nonDisponibile(motivo)
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
        richiesta?.endAudio()
        compito?.cancel()
        richiesta = nil
        compito = nil
        stato = .fermo
        let frase = trascritto.trimmingCharacters(in: .whitespacesAndNewlines)
        trascritto = ""
        if invia, !frase.isEmpty { concluso?(frase) }
    }

    /// Dopo un errore si può riprovare: la spia torna normale.
    func azzera() {
        if case .nonDisponibile = stato { stato = .fermo }
    }

    private func inizia() {
        guard let riconoscitore, riconoscitore.isAvailable else {
            stato = .nonDisponibile("Il riconoscimento vocale in italiano non è disponibile su questo Mac.")
            return
        }
        guard riconoscitore.supportsOnDeviceRecognition else {
            stato = .nonDisponibile("Per ascoltarti senza mandare l'audio fuori dal Mac serve la dettatura in italiano sul dispositivo: attivala in Impostazioni di Sistema › Tastiera › Dettatura, lingua Italiano.")
            return
        }
        let r = SFSpeechAudioBufferRecognitionRequest()
        r.requiresOnDeviceRecognition = true
        r.shouldReportPartialResults = true
        r.taskHint = .dictation
        r.addsPunctuation = true

        let ingresso = motoreAudio.inputNode
        let formato = ingresso.outputFormat(forBus: 0)
        guard formato.sampleRate > 0, formato.channelCount > 0 else {
            stato = .nonDisponibile("Nessun microfono disponibile.")
            return
        }
        Self.collega(ingresso, formato: formato, a: r)
        motoreAudio.prepare()
        do {
            try motoreAudio.start()
        } catch {
            ingresso.removeTap(onBus: 0)
            stato = .nonDisponibile("Il microfono non si è avviato: \(error.localizedDescription)")
            return
        }
        sessione += 1
        let questa = sessione
        richiesta = r
        trascritto = ""
        stato = .ascolta
        compito = Self.riconosci(riconoscitore, r) { [weak self] testo, finale, fallito in
            DispatchQueue.main.async { self?.ricevi(testo, finale: finale, errore: fallito, sessione: questa) }
        }
        // Se non arriva nessuna parola, Eve smette di ascoltare da sola
        timerPausa = Timer.scheduledTimer(withTimeInterval: Self.attesaMassima, repeats: false) { [weak self] _ in
            self?.ferma(invia: true)
        }
        timerLimite = Timer.scheduledTimer(withTimeInterval: Self.durataMassima, repeats: false) { [weak self] _ in
            self?.ferma(invia: true)
        }
    }

    /// Il microfono passa l'audio alla richiesta (il blocco gira sul thread dell'audio).
    private static func collega(_ ingresso: AVAudioInputNode, formato: AVAudioFormat, a r: SFSpeechAudioBufferRecognitionRequest) {
        ingresso.removeTap(onBus: 0)
        ingresso.installTap(onBus: 0, bufferSize: 1024, format: formato) { buffer, _ in
            r.append(buffer)
        }
    }

    private static func riconosci(_ riconoscitore: SFSpeechRecognizer, _ r: SFSpeechAudioBufferRecognitionRequest,
                                              _ ricevi: @escaping (String?, Bool, Bool) -> Void) -> SFSpeechRecognitionTask {
        riconoscitore.recognitionTask(with: r) { risultato, errore in
            ricevi(risultato?.bestTranscription.formattedString, risultato?.isFinal ?? false, errore != nil)
        }
    }

    private func ricevi(_ testo: String?, finale: Bool, errore: Bool, sessione questa: Int) {
        guard questa == sessione, stato == .ascolta else { return }
        if let testo, !testo.isEmpty {
            trascritto = testo
            timerPausa?.invalidate()
            timerPausa = Timer.scheduledTimer(withTimeInterval: Self.pausa, repeats: false) { [weak self] _ in
                self?.ferma(invia: true)
            }
        }
        if finale || errore { ferma(invia: true) }
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
