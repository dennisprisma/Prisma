import AVFoundation
import Foundation

/// La prova del riconoscimento vocale, senza microfono: la voce di Eve pronuncia una frase, l'audio va al
/// riconoscimento e si vede cosa ne esce. Separa i problemi del microfono da quelli del riconoscimento.
/// Tutto sul Mac.
final class ProvaRiconoscimento {
    static let frase = "Ciao Eve, che appuntamenti ho domani?"

    private let sintetizzatore = AVSpeechSynthesizer()
    private var audio: [AVAudioPCMBuffer] = []
    private var trascrizione: TrascrizioneEve?
    private var esito: ((String) -> Void)?

    /// Esegue la prova con il riconoscimento scelto; `esito` riceve il risultato, sul thread principale.
    func esegui(_ scelta: SceltaRiconoscimento, esito: @escaping (String) -> Void) {
        self.esito = esito
        audio = []
        DiagnosticaVoce.annota("Prova del riconoscimento: inizio (scelta \(scelta.rawValue))")
        let frase = AVSpeechUtterance(string: Self.frase)
        frase.voice = VoceEve.voce(nil)
        sintetizzatore.write(frase) { [weak self] pezzo in
            guard let self, let pcm = pezzo as? AVAudioPCMBuffer else { return }
            if pcm.frameLength > 0 {
                self.audio.append(pcm)
            } else {
                // Fine della voce: si passa al riconoscimento
                DispatchQueue.main.async { self.riconosci(scelta) }
            }
        }
    }

    private func riconosci(_ scelta: SceltaRiconoscimento) {
        let pezzi = audio
        guard let primo = pezzi.first else {
            chiudi("La voce di Eve non ha prodotto audio da provare.")
            return
        }
        DiagnosticaVoce.annota("Prova: \(pezzi.count) pezzi di voce, \(DiagnosticaVoce.descrivi(primo.format))")
        Task {
            let preparato = await Trascrizioni.prepara(scelta) { _ in }
            switch preparato {
            case .failure(let e):
                DispatchQueue.main.async { self.chiudi("Il riconoscimento non è partito: \(e.messaggio)") }
            case .success(let t):
                DispatchQueue.main.async { self.ascolta(t, pezzi) }
            }
        }
    }

    private var capito = ""
    private var errore: String?
    private var finito = false

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
            return "Con \(nome) Eve ha capito: «\(capito)» (detto: «\(frase)»). Il riconoscimento funziona: se dal vivo non ti sente, il problema è il microfono."
        }
        return "Con \(nome) Eve non ha capito nessuna parola\(errore.map { ": \($0)" } ?? ""). Il problema è il riconoscimento, non il microfono."
    }

    private func chiudi(_ risultato: String) {
        DiagnosticaVoce.annota("Prova: \(risultato)")
        trascrizione?.aggiornamento = nil
        trascrizione = nil
        esito?(risultato)
        esito = nil
    }
}
