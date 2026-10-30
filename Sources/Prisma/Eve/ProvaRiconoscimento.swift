import AVFoundation
import Foundation

/// La prova del riconoscimento senza microfono: la voce di Eve pronuncia una frase, l'audio va al
/// riconoscimento e si vede cosa ne esce. Finisce sempre con un esito, qualunque fase si inceppi.
final class ProvaRiconoscimento: NSObject {
    static let frase = "Ciao Eve, che appuntamenti ho domani?"
    /// La frase dura ~3 s: se la voce non chiude entro questo tempo si va avanti con l'audio raccolto.
    static let attesaVoce: TimeInterval = 15
    /// Qualunque fase si inceppi (voce, preparazione, riconoscimento), la prova finisce.
    static let attesaTotale: TimeInterval = 45

    private let sintetizzatore = AVSpeechSynthesizer()
    /// I pezzi arrivano dal thread della sintesi: si toccano solo dentro `coda`.
    private let coda = DispatchQueue(label: "prisma.prova.voce")
    private var audio: [AVAudioPCMBuffer] = []
    private var trascrizione: TrascrizioneEve?
    private var esito: ((String) -> Void)?
    private var scelta = SceltaRiconoscimento.automatico
    private var passato = false
    private var fase = "voce di Eve"
    private var capito = ""
    private var errore: String?
    private var finito = false

    override init() {
        super.init()
        sintetizzatore.delegate = self
    }

    /// Esegue la prova con il riconoscimento scelto; `esito` riceve il risultato, sul thread principale.
    func esegui(_ scelta: SceltaRiconoscimento, esito: @escaping (String) -> Void) {
        self.esito = esito
        self.scelta = scelta
        passato = false
        fase = "voce di Eve"
        coda.sync { audio = [] }
        DiagnosticaVoce.annota("Prova del riconoscimento: inizio (scelta \(scelta.rawValue))")
        let frase = AVSpeechUtterance(string: Self.frase)
        frase.voice = VoceEve.voce(nil)
        sintetizzatore.write(frase) { [weak self] pezzo in
            guard let self, let pcm = pezzo as? AVAudioPCMBuffer else { return }
            if pcm.frameLength > 0 {
                self.coda.sync { self.audio.append(pcm) }
            } else {
                // Fine della voce (il pezzo vuoto può anche non arrivare: per questo c'è la scadenza)
                DispatchQueue.main.async { self.riconosci() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.attesaVoce) { [weak self] in
            guard let self, self.esito != nil, !self.passato else { return }
            self.sintetizzatore.stopSpeaking(at: .immediate)
            let raccolti = self.coda.sync { self.audio.count }
            DiagnosticaVoce.annota("Prova: la voce non ha chiuso in \(Int(Self.attesaVoce)) s, \(raccolti) pezzi raccolti")
            self.riconosci()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.attesaTotale) { [weak self] in
            guard let self, self.esito != nil else { return }
            self.sintetizzatore.stopSpeaking(at: .immediate)
            self.trascrizione?.annulla()
            self.chiudi("La prova non è finita in \(Int(Self.attesaTotale)) secondi: ferma a «\(self.fase)». Premi «Copia» e mandami la diagnostica.")
        }
    }

    private func riconosci() {
        guard esito != nil, !passato else { return }
        passato = true
        let pezzi = coda.sync { audio }
        if let primo = pezzi.first {
            DiagnosticaVoce.annota("Prova: \(pezzi.count) pezzi di voce, \(DiagnosticaVoce.descrivi(primo.format))")
        }
        // Anche senza audio si prepara il riconoscimento: se non può partire, quel motivo conta più della voce muta
        // (la sintesi a volte non dà audio, per esempio sul simulatore iOS)
        fase = "preparazione del riconoscimento"
        let scelta = self.scelta
        Task {
            let preparato = await Trascrizioni.prepara(scelta) { avviso in DiagnosticaVoce.annota("Prova: \(avviso)") }
            DispatchQueue.main.async {
                switch preparato {
                case .failure(let e):
                    self.chiudi("Con «\(scelta.nome)» il riconoscimento non è partito: \(e.messaggio)")
                case .success(let t):
                    guard self.esito != nil, !pezzi.isEmpty else {   // la prova è già scaduta, o non c'è audio
                        t.annulla()
                        self.chiudi("La voce di Eve non ha prodotto audio da provare: in «Voce di Eve» premi «Ascolta» e, se non si sente, scegli un'altra voce.")
                        return
                    }
                    self.fase = "riconoscimento"
                    self.ascolta(t, pezzi)
                }
            }
        }
    }

    private func ascolta(_ t: TrascrizioneEve, _ pezzi: [AVAudioPCMBuffer]) {
        trascrizione = t
        capito = ""
        errore = nil
        finito = false
        t.aggiornamento = { [weak self] testo, fine, e in
            DispatchQueue.main.async { self?.aggiorna(t.nome, testo, fine, e) }
        }
        for p in pezzi { t.aggiungi(p) }
        t.finisci()
        // Se il riconoscimento non chiude da solo, si guarda cosa ha capito fin qui
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, !self.finito else { return }
            t.annulla()
            self.aggiorna(t.nome, nil, true, self.errore ?? "nessuna risposta definitiva in 15 secondi")
        }
    }

    private func aggiorna(_ nome: String, _ testo: String?, _ fine: Bool, _ e: String?) {
        guard !finito else { return }
        if let testo, !testo.isEmpty { capito = testo }
        if let e { errore = e }
        if fine {
            finito = true
            chiudi(Self.racconta(nome, capito: capito, errore: errore))
        }
    }

    static func racconta(_ nome: String, capito: String, errore: String?) -> String {
        if !capito.isEmpty {
            return "Con \(nome) Eve ha capito: «\(capito)» (detto: «\(frase)»). Il riconoscimento funziona: se dal vivo non ti sente, guarda la prova del microfono."
        }
        return "Con \(nome) Eve non ha capito nessuna parola\(errore.map { ": \($0)" } ?? ""). Il problema è nel riconoscimento, non nel microfono."
    }

    /// Una sola chiusura, qualunque strada l'abbia raggiunta.
    private func chiudi(_ risultato: String) {
        guard let esito else { return }
        self.esito = nil
        DiagnosticaVoce.annota("Prova: \(risultato)")
        trascrizione?.aggiornamento = nil   // spezza il ciclo t → aggiornamento → t (il blocco usa t.nome)
        trascrizione = nil
        esito(risultato)
    }
}

extension ProvaRiconoscimento: AVSpeechSynthesizerDelegate {
    /// La sintesi si è fermata (errore o nostro stop): non arriverà altro audio, si va avanti subito.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.riconosci() }
    }
}
