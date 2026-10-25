import AVFoundation
import Foundation
import Speech

/// Eve ti ascolta, solo sul Mac: l'audio non viene mai mandato fuori dal computer.
/// Il microfono passa l'audio al riconoscimento scelto (`TrascrizioneEve`): su macOS 26 e successivi quello nuovo
/// di Apple, altrimenti la dettatura classica sul dispositivo. La frase finisce quando smetti di parlare:
/// Eve chiede al riconoscimento il testo definitivo e lo manda.
final class AscoltoEve: ObservableObject {
    enum Stato: Equatable {
        case fermo
        case ascolta
        /// Hai smesso di parlare: Eve aspetta il testo definitivo.
        case capisce
        case nonDisponibile(String)
    }

    @Published private(set) var stato = Stato.fermo
    /// Quello che Eve ha capito finora (si aggiorna mentre parli).
    @Published private(set) var trascritto = ""
    /// Cosa sta facendo Eve quando non ti sta sentendo («Mi preparo…», «Un attimo…»).
    @Published private(set) var nota: String?
    /// Quanto suona il microfono (0…1), per l'onda: se resta fermo mentre parli, il microfono non sente.
    @Published private(set) var livello: Float = 0
    /// La frase finita: la riceve chi ha avviato l'ascolto.
    var concluso: ((String) -> Void)?
    /// Perché Eve non ha potuto ascoltare o capire: chi ha avviato l'ascolto lo fa vedere bene.
    var problema: ((String) -> Void)?
    /// L'ultimo problema: il microfono ti ha sentito ma il riconoscimento non ha dato parole (allora conviene la dettatura di macOS).
    private(set) var senzaParole = false

    /// Silenzio dopo cui la frase si considera finita.
    static let pausa: TimeInterval = 1.5
    /// Se non dici niente entro questo tempo, Eve smette di ascoltare.
    static let attesaMassima: TimeInterval = 8
    /// Una frase non dura più di così.
    static let durataMassima: TimeInterval = 50
    /// Quanto aspettare il testo definitivo dopo che hai smesso di parlare.
    static let attesaFinale: TimeInterval = 4
    /// Sopra questo picco il microfono sente una voce (sotto è silenzio o rumore di fondo).
    static let sogliaVoce: Float = 0.03

    private let motoreAudio = AVAudioEngine()
    private var timerPausa: Timer?
    private var timerLimite: Timer?
    private var timerFinale: Timer?
    private var sessione = 0
    private var trascrizione: TrascrizioneEve?
    /// Il suono più forte sentito in questa frase: distingue «microfono muto» da «non ho capito le parole».
    private var piccoMassimo: Float = 0
    /// Quando il microfono ha sentito la voce l'ultima volta (nil = non ancora).
    private var ultimaVoce: Date?
    /// L'ultimo errore del riconoscimento, per spiegarlo se non è arrivata nessuna parola.
    private var ultimoErrore: String?
    private var risposte = 0

    var ascolta: Bool { stato == .ascolta || stato == .capisce }

    /// Inizia ad ascoltare con il riconoscimento scelto, chiedendo prima i permessi se serve.
    func avvia(_ scelta: SceltaRiconoscimento = .automatico) {
        guard !ascolta else { return }
        Self.permessi { [weak self] motivo in
            guard let self else { return }
            if let motivo {
                self.segnala(motivo)
            } else {
                self.inizia(scelta)
            }
        }
    }

    /// Smette di ascoltare. Con `invia` chiede al riconoscimento il testo definitivo e poi manda la frase;
    /// senza, lascia perdere tutto.
    func ferma(invia: Bool) {
        switch stato {
        case .ascolta:
            spegniMicrofono()
            guard invia, let t = trascrizione else {
                if invia { concludi() } else { lasciaPerdere() }
                return
            }
            stato = .capisce
            nota = "Un attimo…"
            DiagnosticaVoce.annota("Fine della frase: chiedo il testo definitivo (\(risposte) risposte finora)")
            t.finisci()
            timerFinale?.invalidate()
            timerFinale = Timer.scheduledTimer(withTimeInterval: Self.attesaFinale, repeats: false) { [weak self] _ in
                DiagnosticaVoce.annota("Il testo definitivo non è arrivato in tempo")
                self?.concludi()
            }
        case .capisce:
            if invia { concludi() } else { lasciaPerdere() }
        default:
            break
        }
    }

    /// Dopo un errore si può riprovare: la spia torna normale.
    func azzera() {
        if case .nonDisponibile = stato { stato = .fermo }
    }

    private func spegniMicrofono() {
        timerPausa?.invalidate()
        timerLimite?.invalidate()
        if motoreAudio.isRunning { motoreAudio.stop() }
        motoreAudio.inputNode.removeTap(onBus: 0)
        livello = 0
    }

    private func lasciaPerdere() {
        sessione += 1
        timerFinale?.invalidate()
        trascrizione?.aggiornamento = nil
        trascrizione?.annulla()
        trascrizione = nil
        stato = .fermo
        nota = nil
        trascritto = ""
    }

    /// La frase è finita: la manda, oppure spiega perché non c'è.
    private func concludi() {
        guard ascolta else { return }
        if stato == .ascolta { spegniMicrofono() }
        let frase = trascritto.trimmingCharacters(in: .whitespacesAndNewlines)
        let dettaglio = "(\(trascrizione?.nome ?? "nessun riconoscimento"), \(risposte) \(risposte == 1 ? "risposta" : "risposte"), voce \(String(format: "%.2f", piccoMassimo)))"
        DiagnosticaVoce.annota("Frase conclusa: \(frase.count) caratteri \(dettaglio)")
        lasciaPerdere()
        senzaParole = frase.isEmpty && piccoMassimo >= 0.01
        if !frase.isEmpty {
            concluso?(frase)
        } else if let e = ultimoErrore {
            segnala("Non sono riuscita a capirti: \(e). \(dettaglio)")
        } else if piccoMassimo < 0.01 {
            segnala("Non arriva nessun suono dal microfono. Controlla in Impostazioni di Sistema › Suono › Ingresso quale microfono è scelto, e in Privacy e sicurezza › Microfono che Prisma sia attivo. \(dettaglio)")
        } else {
            segnala("Ti ho sentito ma il riconoscimento non mi ha restituito parole. Prova «Prova il riconoscimento» in Impostazioni › Parlare con Eve e mandami il risultato. \(dettaglio)")
        }
    }

    /// Mette Eve in stato di problema e lo fa sapere a chi ha avviato l'ascolto.
    private func segnala(_ motivo: String) {
        stato = .nonDisponibile(motivo)
        problema?(motivo)
    }

    private func inizia(_ scelta: SceltaRiconoscimento) {
        sessione += 1
        let questa = sessione
        piccoMassimo = 0
        ultimaVoce = nil
        ultimoErrore = nil
        risposte = 0
        trascritto = ""
        stato = .ascolta
        nota = "Mi preparo ad ascoltarti…"
        DiagnosticaVoce.annota("Ascolto: inizio (scelta \(scelta.rawValue))")
        Task {
            let esito = await Trascrizioni.prepara(scelta) { avviso in
                DispatchQueue.main.async { if self.sessione == questa { self.nota = avviso } }
            }
            DispatchQueue.main.async {
                guard self.sessione == questa, self.stato == .ascolta else {
                    if case .success(let t) = esito { t.annulla() }
                    return
                }
                switch esito {
                case .failure(let e):
                    self.stato = .fermo
                    self.nota = nil
                    self.segnala(e.messaggio)
                case .success(let t):
                    self.avviaCon(t, sessione: questa)
                }
            }
        }
    }

    private func avviaCon(_ t: TrascrizioneEve, sessione questa: Int) {
        trascrizione = t
        t.aggiornamento = { [weak self] testo, fine, errore in
            DispatchQueue.main.async { self?.ricevi(testo, fine: fine, errore: errore, sessione: questa) }
        }
        DiagnosticaVoce.annota("Ascolto con \(t.nome)")
        guard accendiMicrofono({ t.aggiungi($0) }) else {
            lasciaPerdere()
            return
        }
    }

    // MARK: - Microfono

    /// Accende il microfono e passa ogni pezzo di audio a `consegna` (sul thread dell'audio).
    /// La frase finisce quando, dopo aver sentito la voce, il microfono resta in silenzio per un po'.
    private func accendiMicrofono(_ consegna: @escaping (AVAudioPCMBuffer) -> Void) -> Bool {
        let ingresso = motoreAudio.inputNode
        let formato = ingresso.outputFormat(forBus: 0)
        DiagnosticaVoce.annota("Microfono: \(DiagnosticaVoce.descrivi(formato))")
        guard formato.sampleRate > 0, formato.channelCount > 0 else {
            segnala("Non trovo nessun microfono: controlla Impostazioni di Sistema › Suono › Ingresso.")
            return false
        }
        let questa = sessione
        Self.collega(ingresso, formato: formato, consegna: consegna) { [weak self] picco in
            DispatchQueue.main.async { self?.suono(picco, sessione: questa) }
        }
        motoreAudio.prepare()
        do {
            try motoreAudio.start()
        } catch {
            ingresso.removeTap(onBus: 0)
            DiagnosticaVoce.annota("Microfono non avviato: \(DiagnosticaVoce.descrivi(error))")
            segnala("Il microfono non si è avviato: \(error.localizedDescription)")
            return false
        }
        stato = .ascolta
        nota = nil
        // Se non dici niente, Eve smette di ascoltare da sola
        timerPausa?.invalidate()
        timerPausa = Timer.scheduledTimer(withTimeInterval: Self.attesaMassima, repeats: false) { [weak self] _ in
            guard let self, self.ultimaVoce == nil else { return }
            self.ferma(invia: true)
        }
        timerLimite?.invalidate()
        timerLimite = Timer.scheduledTimer(withTimeInterval: Self.durataMassima, repeats: false) { [weak self] _ in
            self?.ferma(invia: true)
        }
        return true
    }

    /// Il suono del microfono, circa dieci volte al secondo: l'onda, e la fine della frase quando torna il silenzio.
    private func suono(_ picco: Float, sessione questa: Int) {
        guard sessione == questa, stato == .ascolta else { return }
        piccoMassimo = max(piccoMassimo, picco)
        let nuovo = min(1, picco * 4)
        if abs(nuovo - livello) > 0.04 { livello = nuovo }
        let adesso = Date()
        if picco > Self.sogliaVoce {
            ultimaVoce = adesso
        } else if let v = ultimaVoce, adesso.timeIntervalSince(v) > Self.pausa {
            ferma(invia: true)
        }
    }

    /// Il microfono passa l'audio a chi riconosce (il blocco gira sul thread dell'audio).
    private static func collega(_ ingresso: AVAudioInputNode, formato: AVAudioFormat, consegna: @escaping (AVAudioPCMBuffer) -> Void,
                                livello: @escaping (Float) -> Void) {
        ingresso.removeTap(onBus: 0)
        var contatore = 0
        ingresso.installTap(onBus: 0, bufferSize: 1024, format: formato) { buffer, _ in
            consegna(buffer)
            contatore += 1
            guard contatore % 4 == 0, let canale = buffer.floatChannelData?[0] else { return }
            var picco: Float = 0
            for i in 0..<Int(buffer.frameLength) { picco = max(picco, abs(canale[i])) }
            livello(picco)
        }
    }

    /// Un aggiornamento del riconoscimento: il testo finora, la fine, l'errore.
    private func ricevi(_ testo: String?, fine: Bool, errore: String?, sessione questa: Int) {
        guard questa == sessione, ascolta else { return }
        if testo != nil { risposte += 1 }
        if let errore { ultimoErrore = errore }
        if let testo, !testo.trimmingCharacters(in: .whitespaces).isEmpty {
            trascritto = testo
            if stato == .ascolta { ultimaVoce = Date() }
        }
        if fine { concludi() }
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
