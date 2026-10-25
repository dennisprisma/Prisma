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
    /// Una frase non dura più di così (il riconoscimento di Apple regge circa un minuto).
    static let durataMassima: TimeInterval = 50

    private let riconoscitore = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
    private let motoreAudio = AVAudioEngine()
    private var richiesta: SFSpeechAudioBufferRecognitionRequest?
    private var compito: SFSpeechRecognitionTask?
    private var timerPausa: Timer?
    private var timerLimite: Timer?
    private var sessione = 0
    /// Il suono più forte sentito in questa frase: distingue «microfono muto» da «non ho capito le parole».
    private var piccoMassimo: Float = 0
    /// L'ultimo errore del riconoscimento, per spiegarlo se non è arrivata nessuna parola.
    private var ultimoErrore: String?

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
        richiesta?.endAudio()
        compito?.cancel()
        richiesta = nil
        compito = nil
        stato = .fermo
        livello = 0
        let frase = trascritto.trimmingCharacters(in: .whitespacesAndNewlines)
        trascritto = ""
        guard invia else { return }
        if !frase.isEmpty {
            concluso?(frase)
        } else if let e = ultimoErrore {
            segnala("Non sono riuscita a capirti: \(e). Se capita sempre, controlla che la dettatura in italiano sia attiva in Impostazioni di Sistema › Tastiera › Dettatura.")
        } else if piccoMassimo < 0.01 {
            segnala("Non arriva nessun suono dal microfono. Controlla in Impostazioni di Sistema › Suono › Ingresso quale microfono è scelto, e in Privacy e sicurezza › Microfono che Prisma sia attivo.")
        } else {
            segnala("Ho sentito un suono ma nessuna parola. Riprova parlando un po' più vicino al Mac.")
        }
    }

    /// Mette Eve in stato di problema e lo fa sapere a chi ha avviato l'ascolto.
    private func segnala(_ motivo: String) {
        stato = .nonDisponibile(motivo)
        problema?(motivo)
    }

    /// Dopo un errore si può riprovare: la spia torna normale.
    func azzera() {
        if case .nonDisponibile = stato { stato = .fermo }
    }

    private func inizia() {
        guard let riconoscitore, riconoscitore.isAvailable else {
            segnala("Il riconoscimento vocale in italiano non è disponibile adesso. Controlla che Siri o la dettatura siano attive in Impostazioni di Sistema (Tastiera › Dettatura) e riprova.")
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

        let ingresso = motoreAudio.inputNode
        let formato = ingresso.outputFormat(forBus: 0)
        guard formato.sampleRate > 0, formato.channelCount > 0 else {
            segnala("Non trovo nessun microfono: controlla Impostazioni di Sistema › Suono › Ingresso.")
            return
        }
        piccoMassimo = 0
        ultimoErrore = nil
        Self.collega(ingresso, formato: formato, a: r) { [weak self] picco in
            DispatchQueue.main.async {
                guard let self, self.stato == .ascolta else { return }
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
            return
        }
        sessione += 1
        let questa = sessione
        richiesta = r
        trascritto = ""
        stato = .ascolta
        compito = Self.riconosci(riconoscitore, r) { [weak self] testo, finale, errore in
            DispatchQueue.main.async { self?.ricevi(testo, finale: finale, errore: errore, sessione: questa) }
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
    private static func collega(_ ingresso: AVAudioInputNode, formato: AVAudioFormat, a r: SFSpeechAudioBufferRecognitionRequest,
                                livello: @escaping (Float) -> Void) {
        ingresso.removeTap(onBus: 0)
        var contatore = 0
        ingresso.installTap(onBus: 0, bufferSize: 1024, format: formato) { buffer, _ in
            r.append(buffer)
            // Il picco del suono, circa dieci volte al secondo
            contatore += 1
            guard contatore % 4 == 0, let canale = buffer.floatChannelData?[0] else { return }
            var picco: Float = 0
            for i in 0..<Int(buffer.frameLength) { picco = max(picco, abs(canale[i])) }
            livello(picco)
        }
    }

    private static func riconosci(_ riconoscitore: SFSpeechRecognizer, _ r: SFSpeechAudioBufferRecognitionRequest,
                                              _ ricevi: @escaping (String?, Bool, String?) -> Void) -> SFSpeechRecognitionTask {
        riconoscitore.recognitionTask(with: r) { risultato, errore in
            ricevi(risultato?.bestTranscription.formattedString, risultato?.isFinal ?? false, errore?.localizedDescription)
        }
    }

    private func ricevi(_ testo: String?, finale: Bool, errore: String?, sessione questa: Int) {
        guard questa == sessione, stato == .ascolta else { return }
        if let errore { ultimoErrore = errore }
        if let testo, !testo.isEmpty {
            trascritto = testo
            timerPausa?.invalidate()
            timerPausa = Timer.scheduledTimer(withTimeInterval: Self.pausa, repeats: false) { [weak self] _ in
                self?.ferma(invia: true)
            }
        }
        if finale || errore != nil { ferma(invia: true) }
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
