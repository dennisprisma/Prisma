import AVFoundation
import Foundation
import Speech

/// Chi prepara il riconoscimento: di norma `Trascrizioni.prepara`, nelle prove uno finto.
typealias PreparaRiconoscimento = (SceltaRiconoscimento, @escaping (String) -> Void) async -> Result<TrascrizioneEve, ErroreEve>

/// Il microfono visto da Eve: di norma AVAudioEngine, nelle prove uno finto.
protocol MicrofonoEve: AnyObject {
    /// Accende il microfono: nil se è acceso, altrimenti il motivo. `consegna` riceve ogni pezzo di audio,
    /// `livello` il picco di ogni pezzo (entrambi da un thread qualsiasi).
    func accendi(consegna: @escaping (AVAudioPCMBuffer) -> Void, livello: @escaping (Float) -> Void) -> String?
    func spegni()
}

/// Eve ti ascolta, solo sul Mac. Il microfono passa l'audio al riconoscimento scelto (`TrascrizioneEve`);
/// la frase finisce quando smetti di parlare: Eve chiede il testo definitivo e lo manda.
final class AscoltoEve: ObservableObject {
    enum Stato: Equatable {
        case fermo
        /// Eve prepara il riconoscimento: il microfono non è ancora acceso.
        case prepara
        case ascolta
        /// Hai smesso di parlare: Eve aspetta il testo definitivo.
        case capisce
        case nonDisponibile(String)
    }

    /// Perché l'ultimo ascolto non ha dato una frase (chi ascolta decide se riprovare con un altro riconoscimento).
    enum Fallimento: Equatable {
        /// Il riconoscimento non è partito (lingua assente, errore di preparazione).
        case nonPartito
        /// Il riconoscimento non è stato pronto in tempo: il microfono non si è mai acceso.
        case nonPronto
        case microfono
        /// Il microfono non ha sentito niente.
        case senzaSuono
        /// Il microfono ti ha sentito ma il riconoscimento non ha dato parole.
        case senzaParole
        case errore
    }

    /// I tempi dell'ascolto (le prove li accorciano).
    struct Tempi {
        /// Silenzio dopo cui la frase si considera finita, se il riconoscimento ha già risposto; altrimenti il triplo.
        var pausa: TimeInterval = 1.5
        /// Se non dici niente entro questo tempo, Eve smette di ascoltare.
        var attesaMassima: TimeInterval = 8
        /// Una frase non dura più di così.
        var durataMassima: TimeInterval = 50
        /// Quanto aspettare il testo definitivo dopo che hai smesso di parlare (la finalizzazione può superare i 4 s).
        var attesaFinale: TimeInterval = 12
        /// Quanto aspettare che il riconoscimento sia pronto; di più se sta scaricando l'italiano.
        var attesaPreparazione: TimeInterval = 25
        var attesaScaricamento: TimeInterval = 240
    }

    @Published private(set) var stato = Stato.fermo
    /// Quello che Eve ha capito finora (si aggiorna mentre parli).
    @Published private(set) var trascritto = ""
    /// Cosa sta facendo Eve quando non ti sta sentendo («Mi preparo…», «Un attimo…»).
    @Published private(set) var nota: String?
    /// Quanto suona il microfono (0…1), per l'onda.
    @Published private(set) var livello: Float = 0
    /// La frase finita: la riceve chi ha avviato l'ascolto.
    var concluso: ((String) -> Void)?
    /// Perché Eve non ha potuto ascoltare o capire.
    var problema: ((String) -> Void)?
    private(set) var fallimento: Fallimento?
    var tempi = Tempi()
    /// Sopra questo picco il microfono sente una voce (sotto è silenzio o rumore di fondo).
    static let sogliaVoce: Float = 0.03

    private let prepara: PreparaRiconoscimento
    private let microfono: MicrofonoEve
    private let chiediPermessi: (@escaping (String?) -> Void) -> Void
    private var timerPausa: Timer?
    private var timerLimite: Timer?
    private var timerFinale: Timer?
    private var timerPreparazione: Timer?
    private var sessione = 0
    private var trascrizione: TrascrizioneEve?
    private var piccoMassimo: Float = 0
    private var ultimaVoce: Date?
    private var ultimoErrore: String?
    private var risposte = 0
    private var microfonoAcceso: Date?

    init(prepara: @escaping PreparaRiconoscimento = { await Trascrizioni.prepara($0, avviso: $1) },
         microfono: MicrofonoEve = MicrofonoReale(),
         permessi: @escaping (@escaping (String?) -> Void) -> Void = AscoltoEve.permessi) {
        self.prepara = prepara
        self.microfono = microfono
        chiediPermessi = permessi
    }

    var ascolta: Bool { stato == .prepara || stato == .ascolta || stato == .capisce }
    var siPrepara: Bool { stato == .prepara }
    var senzaParole: Bool { fallimento == .senzaParole }

    /// Inizia ad ascoltare con il riconoscimento scelto, chiedendo prima i permessi se serve.
    func avvia(_ scelta: SceltaRiconoscimento = .automatico) {
        guard !ascolta else { return }
        // Da subito «mi preparo»: così un secondo clic annulla invece di riavviare
        stato = .prepara
        nota = "Mi preparo ad ascoltarti…"
        chiediPermessi { [weak self] motivo in
            guard let self, self.stato == .prepara else { return }
            if let motivo {
                self.stato = .fermo
                self.nota = nil
                self.fallimento = .microfono
                self.segnala(motivo)
            } else {
                self.inizia(scelta)
            }
        }
    }

    /// Smette di ascoltare. Con `invia` chiede il testo definitivo e manda la frase; senza, lascia perdere.
    func ferma(invia: Bool) {
        switch stato {
        case .prepara:
            // Il microfono non è mai stato acceso: niente da mandare, nessun messaggio sul microfono
            DiagnosticaVoce.annota("Ascolto annullato durante la preparazione")
            lasciaPerdere()
        case .ascolta:
            spegniMicrofono()
            guard invia else { lasciaPerdere(); return }
            guard let t = trascrizione else { concludi(); return }
            stato = .capisce
            nota = "Un attimo…"
            DiagnosticaVoce.annota("Fine della frase: chiedo il testo definitivo (\(risposte) risposte, \(trascritto.count) caratteri finora)")
            t.finisci()
            timerFinale?.invalidate()
            timerFinale = Timer.scheduledTimer(withTimeInterval: tempi.attesaFinale, repeats: false) { [weak self] _ in
                guard let self else { return }
                DiagnosticaVoce.annota("Il testo definitivo non è arrivato in \(Int(self.tempi.attesaFinale)) s (\(self.risposte) risposte)")
                self.concludi()
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
        microfono.spegni()
        livello = 0
    }

    private func lasciaPerdere() {
        sessione += 1
        timerFinale?.invalidate()
        timerPreparazione?.invalidate()
        trascrizione?.aggiornamento = nil
        trascrizione?.annulla()
        trascrizione = nil
        stato = .fermo
        nota = nil
        trascritto = ""
    }

    /// La frase è finita: la manda, oppure spiega perché non c'è.
    private func concludi() {
        guard stato == .ascolta || stato == .capisce else { return }
        if stato == .ascolta { spegniMicrofono() }
        let frase = trascritto.trimmingCharacters(in: .whitespacesAndNewlines)
        let dettaglio = "(\(trascrizione?.nome ?? "nessun riconoscimento"), \(risposte) \(risposte == 1 ? "risposta" : "risposte"), voce \(String(format: "%.2f", piccoMassimo)))"
        DiagnosticaVoce.annota("Frase conclusa: \(frase.count) caratteri \(dettaglio)")
        let errore = ultimoErrore
        lasciaPerdere()
        if !frase.isEmpty {
            concluso?(frase)
        } else if let e = errore {
            fallimento = .errore
            segnala("Non sono riuscita a capirti: \(e). \(dettaglio)")
        } else if piccoMassimo < 0.01 {
            fallimento = .senzaSuono
            segnala("Non arriva nessun suono dal microfono. Controlla in Impostazioni di Sistema › Suono › Ingresso quale microfono è scelto, e in Privacy e sicurezza › Microfono che Prisma sia attivo. \(dettaglio)")
        } else {
            fallimento = .senzaParole
            segnala("Ti ho sentito ma il riconoscimento non mi ha restituito parole. \(dettaglio)")
        }
    }

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
        fallimento = nil
        microfonoAcceso = nil
        stato = .prepara
        nota = "Mi preparo ad ascoltarti…"
        DiagnosticaVoce.inizia("Ascolto: inizio (scelta \(scelta.rawValue))")
        armaAttesaPreparazione(tempi.attesaPreparazione, sessione: questa)
        let partenza = Date()
        Task {
            let esito = await prepara(scelta) { avviso in
                DispatchQueue.main.async {
                    guard self.sessione == questa else { return }
                    self.nota = avviso
                    // Sta scaricando l'italiano: si aspetta di più
                    self.armaAttesaPreparazione(self.tempi.attesaScaricamento, sessione: questa)
                }
            }
            DispatchQueue.main.async {
                guard self.sessione == questa, self.stato == .prepara else {
                    if case .success(let t) = esito { t.annulla() }
                    return
                }
                self.timerPreparazione?.invalidate()
                DiagnosticaVoce.annota("Preparazione finita in \(String(format: "%.1f", Date().timeIntervalSince(partenza))) s")
                switch esito {
                case .failure(let e):
                    self.stato = .fermo
                    self.nota = nil
                    self.fallimento = .nonPartito
                    self.segnala(e.messaggio)
                case .success(let t):
                    self.avviaCon(t, sessione: questa)
                }
            }
        }
    }

    /// Se il riconoscimento non è pronto in tempo, si lascia perdere e lo si dice (in automatico si passa a un altro).
    private func armaAttesaPreparazione(_ secondi: TimeInterval, sessione questa: Int) {
        timerPreparazione?.invalidate()
        timerPreparazione = Timer.scheduledTimer(withTimeInterval: secondi, repeats: false) { [weak self] _ in
            guard let self, self.sessione == questa, self.stato == .prepara else { return }
            DiagnosticaVoce.annota("Il riconoscimento non è pronto dopo \(Int(secondi)) s")
            self.lasciaPerdere()
            self.fallimento = .nonPronto
            self.segnala("Il riconoscimento non è pronto: ho aspettato \(Int(secondi)) secondi. Riprova tra poco; se succede ancora, scegli un altro riconoscimento in Impostazioni › Parlare con Eve.")
        }
    }

    private func avviaCon(_ t: TrascrizioneEve, sessione questa: Int) {
        trascrizione = t
        t.aggiornamento = { [weak self] testo, fine, errore in
            DispatchQueue.main.async { self?.ricevi(testo, fine: fine, errore: errore, sessione: questa) }
        }
        DiagnosticaVoce.annota("Ascolto con \(t.nome)")
        let motivo = microfono.accendi(consegna: { t.aggiungi($0) }) { [weak self] picco in
            DispatchQueue.main.async { self?.suono(picco, sessione: questa) }
        }
        if let motivo {
            // Prima si pulisce, poi si segnala: così la riga rossa sotto il campo resta
            DiagnosticaVoce.annota("Microfono non acceso: \(motivo)")
            lasciaPerdere()
            fallimento = .microfono
            segnala(motivo)
            return
        }
        microfonoAcceso = Date()
        stato = .ascolta
        nota = nil
        DiagnosticaVoce.annota("Microfono acceso")
        // Se non dici niente, Eve smette di ascoltare da sola
        timerPausa?.invalidate()
        timerPausa = Timer.scheduledTimer(withTimeInterval: tempi.attesaMassima, repeats: false) { [weak self] _ in
            guard let self, self.ultimaVoce == nil, self.stato == .ascolta else { return }
            DiagnosticaVoce.annota("Nessuna voce in \(Int(self.tempi.attesaMassima)) s (picco \(String(format: "%.2f", self.piccoMassimo))): chiudo")
            self.ferma(invia: true)
        }
        timerLimite?.invalidate()
        timerLimite = Timer.scheduledTimer(withTimeInterval: tempi.durataMassima, repeats: false) { [weak self] _ in
            DiagnosticaVoce.annota("Frase troppo lunga: chiudo")
            self?.ferma(invia: true)
        }
    }

    /// Il suono del microfono, circa dieci volte al secondo: l'onda, e la fine della frase quando torna il silenzio.
    private func suono(_ picco: Float, sessione questa: Int) {
        guard sessione == questa, stato == .ascolta else { return }
        if piccoMassimo < 0.01, picco >= 0.01 { DiagnosticaVoce.annota("Primo suono dal microfono (picco \(String(format: "%.2f", picco)))") }
        piccoMassimo = max(piccoMassimo, picco)
        let nuovo = min(1, picco * 4)
        if abs(nuovo - livello) > 0.04 { livello = nuovo }
        let adesso = Date()
        if picco > Self.sogliaVoce {
            if ultimaVoce == nil { DiagnosticaVoce.annota("Voce sentita") }
            ultimaVoce = adesso
        } else if let v = ultimaVoce {
            let silenzio = adesso.timeIntervalSince(v)
            // Alla pausa si chiude solo se il riconoscimento ha già risposto; altrimenti gli si lascia più tempo
            if (risposte > 0 && silenzio > tempi.pausa) || silenzio > tempi.pausa * 3 {
                DiagnosticaVoce.annota("Pausa di \(String(format: "%.1f", silenzio)) s: fine della frase")
                ferma(invia: true)
            }
        }
    }

    /// Un aggiornamento del riconoscimento: il testo finora, la fine, l'errore.
    private func ricevi(_ testo: String?, fine: Bool, errore: String?, sessione questa: Int) {
        guard questa == sessione, stato == .ascolta || stato == .capisce else { return }
        if let testo {
            risposte += 1
            if risposte == 1, let acceso = microfonoAcceso {
                DiagnosticaVoce.annota("Primo risultato dopo \(String(format: "%.1f", Date().timeIntervalSince(acceso))) s dal microfono (\(testo.count) caratteri)")
            }
        }
        if let errore { ultimoErrore = errore }
        if let testo, !testo.trimmingCharacters(in: .whitespaces).isEmpty {
            trascritto = testo
            if stato == .ascolta { ultimaVoce = Date() }
        }
        if fine { concludi() }
    }

    // MARK: - Prova del microfono

    /// Contatori condivisi con il thread dell'audio durante la prova.
    private final class ContoMicrofono {
        var pezzi = 0
        var picco: Float = 0
    }

    /// Tre secondi di microfono senza riconoscimento: pezzi di audio e picco. Separa il microfono dal riconoscimento.
    func provaMicrofono(_ esito: @escaping (String) -> Void) {
        guard !ascolta else { esito("Eve sta già ascoltando: riprova tra un attimo."); return }
        chiediPermessi { [weak self] motivo in
            guard let self else { return }
            if let motivo { esito(motivo); return }
            let coda = DispatchQueue(label: "prisma.prova.microfono")
            let conto = ContoMicrofono()
            if let guasto = self.microfono.accendi(consegna: { _ in coda.async { conto.pezzi += 1 } },
                                                   livello: { p in coda.async { conto.picco = max(conto.picco, p) } }) {
                esito(guasto)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.microfono.spegni()
                let (n, p) = coda.sync { (conto.pezzi, conto.picco) }
                let giudizio = p < 0.01 ? "muto: controlla Impostazioni di Sistema › Suono › Ingresso"
                    : (p < Self.sogliaVoce ? "molto basso: parla più vicino o alza il volume d'ingresso" : "sente bene")
                let r = "Microfono: \(n) pezzi di audio in 3 s, picco \(String(format: "%.2f", p)) (\(giudizio))"
                DiagnosticaVoce.annota("Prova del microfono: \(r)")
                esito(r)
            }
        }
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

/// Il microfono vero: AVAudioEngine con un tap sull'ingresso.
final class MicrofonoReale: MicrofonoEve {
    private let motore = AVAudioEngine()

    func accendi(consegna: @escaping (AVAudioPCMBuffer) -> Void, livello: @escaping (Float) -> Void) -> String? {
        let ingresso = motore.inputNode
        let formato = ingresso.outputFormat(forBus: 0)
        DiagnosticaVoce.annota("Microfono: \(DiagnosticaVoce.descrivi(formato))")
        guard formato.sampleRate > 0, formato.channelCount > 0 else {
            return "Non trovo nessun microfono: controlla Impostazioni di Sistema › Suono › Ingresso."
        }
        ingresso.removeTap(onBus: 0)
        // Il picco si misura su ogni pezzo (macOS consegna pezzi da ~100 ms, qualunque misura si chieda)
        ingresso.installTap(onBus: 0, bufferSize: 1024, format: formato) { buffer, _ in
            consegna(buffer)
            if let p = Self.picco(buffer) { livello(p) }
        }
        motore.prepare()
        do {
            try motore.start()
        } catch {
            ingresso.removeTap(onBus: 0)
            DiagnosticaVoce.annota("Microfono non avviato: \(DiagnosticaVoce.descrivi(error))")
            return "Il microfono non si è avviato: \(error.localizedDescription)"
        }
        return nil
    }

    func spegni() {
        if motore.isRunning { motore.stop() }
        motore.inputNode.removeTap(onBus: 0)
    }

    /// Il campione più forte del pezzo (un campione su quattro basta), 0…1.
    private static func picco(_ buffer: AVAudioPCMBuffer) -> Float? {
        let n = Int(buffer.frameLength)
        var p: Float = 0
        if let c = buffer.floatChannelData?[0] {
            var i = 0
            while i < n { p = max(p, abs(c[i])); i += 4 }
        } else if let c = buffer.int16ChannelData?[0] {
            var i = 0
            while i < n { p = max(p, abs(Float(c[i])) / 32768); i += 4 }
        } else {
            return nil
        }
        return p
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
