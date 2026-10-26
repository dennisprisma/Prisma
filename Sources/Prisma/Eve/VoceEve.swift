import AVFoundation
import Foundation

/// La voce di Eve: la sintesi vocale di macOS, che lavora sul Mac (nessun testo esce dal computer).
/// Sceglie la voce femminile italiana migliore installata: le voci «Premium» e «Avanzate» sono le più
/// naturali e si scaricano da Impostazioni di Sistema › Accessibilità › Contenuti letti ad alta voce.
final class VoceEve: NSObject, ObservableObject {
    @Published private(set) var parla = false
    /// Chiamata quando Eve finisce di parlare da sola (non quando la si interrompe).
    var finito: (() -> Void)?
    /// Nelle prove: non parla davvero (sul server non c'è audio), lo stato si comporta uguale.
    let muta: Bool

    private let sintetizzatore = AVSpeechSynthesizer()
    /// La frase che Eve sta dicendo: i messaggi del sintetizzatore su frasi vecchie (interrotte) si ignorano,
    /// perché il didCancel arriva dopo che è già partita la frase nuova.
    private(set) var corrente: AVSpeechUtterance?
    private var inizioFrase = Date()
    /// Se il sintetizzatore non dice mai di aver finito, Eve non resta bloccata: la frase si considera finita.
    private var sorveglianza: Timer?

    init(muta: Bool = false) {
        self.muta = muta
        super.init()
        sintetizzatore.delegate = self
    }

    /// Fa dire un testo a Eve; interrompe quello che stava dicendo.
    func di(_ testo: String, voce id: String?, velocita: Double) {
        let t = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            // Niente da dire: chi aspetta la fine va avvisato comunque (la conversazione non si blocca)
            DispatchQueue.main.async { [weak self] in self?.finito?() }
            return
        }
        corrente = nil   // il didCancel (o didFinish) della frase vecchia non riguarda più nessuno
        if sintetizzatore.isSpeaking { sintetizzatore.stopSpeaking(at: .immediate) }
        let frase = AVSpeechUtterance(string: t)
        let voce = Self.voce(id)
        frase.voice = voce
        frase.rate = Self.velocita(velocita)
        frase.pitchMultiplier = 1
        frase.postUtteranceDelay = 0.05
        corrente = frase
        inizioFrase = Date()
        parla = true
        DiagnosticaVoce.annota("Voce: dico \(t.count) caratteri con \(voce.map(Self.nome) ?? "la voce di sistema")")
        // Rete di sicurezza: il doppio del tempo stimato (10 caratteri al secondo alla velocità minima), almeno 4 s
        armaSorveglianza(frase, secondi: max(4, Double(t.count) / 10 * 2 + 2))
        if !muta { sintetizzatore.speak(frase) }
    }

    func zitta() {
        guard corrente != nil || sintetizzatore.isSpeaking else { return }
        DiagnosticaVoce.annota("Voce: interrotta")
        corrente = nil
        sorveglianza?.invalidate()
        if sintetizzatore.isSpeaking { sintetizzatore.stopSpeaking(at: .word) }
        parla = false
    }

    private func armaSorveglianza(_ frase: AVSpeechUtterance, secondi: TimeInterval) {
        sorveglianza?.invalidate()
        sorveglianza = Timer.scheduledTimer(withTimeInterval: secondi, repeats: false) { [weak self] _ in
            guard let self, frase === self.corrente else { return }
            DiagnosticaVoce.annota("Voce: il sintetizzatore non ha segnalato la fine in \(Int(secondi)) s, vado avanti")
            if self.sintetizzatore.isSpeaking { self.sintetizzatore.stopSpeaking(at: .immediate) }
            self.concluso(frase, daSola: true)
        }
    }

    /// Il sintetizzatore ha finito o annullato una frase: conta solo se è quella corrente.
    fileprivate func concluso(_ frase: AVSpeechUtterance, daSola: Bool) {
        guard frase === corrente else { return }
        corrente = nil
        sorveglianza?.invalidate()
        parla = false
        DiagnosticaVoce.annota("Voce: \(daSola ? "finita" : "annullata") dopo \(String(format: "%.1f", Date().timeIntervalSince(inizioFrase))) s")
        if daSola { finito?() }
    }

    // MARK: - Le voci

    /// La velocità per il sintetizzatore: 1 è quella naturale; restano dentro limiti ascoltabili.
    static func velocita(_ fattore: Double) -> Float {
        let base = AVSpeechUtteranceDefaultSpeechRate
        let r = base * Float(min(1.4, max(0.7, fattore)))
        return min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, r))
    }

    /// Le voci italiane installate, dalla migliore: prima le femminili, poi Premium, Avanzate, standard.
    static func vociItaliane() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("it") }
            .sorted { a, b in
                let pa = punteggio(a), pb = punteggio(b)
                return pa != pb ? pa > pb : a.name < b.name
            }
    }

    private static func punteggio(_ v: AVSpeechSynthesisVoice) -> Int {
        var p = v.gender == .female ? 100 : 0
        switch v.quality {
        case .premium: p += 20
        case .enhanced: p += 10
        default: break
        }
        // Le voci «novità» di macOS (Eddy, Flo, Grandma…) sono caricature: in fondo
        if v.identifier.contains("eloquence") || v.identifier.contains("speech.synthesis.voice") { p -= 50 }
        return p
    }

    /// La voce scelta, se è ancora installata; altrimenti la migliore italiana.
    static func voce(_ id: String?) -> AVSpeechSynthesisVoice? {
        if let id, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        return vociItaliane().first ?? AVSpeechSynthesisVoice(language: "it-IT")
    }

    /// Il nome di una voce come lo mostra Prisma: «Federica (Premium)».
    static func nome(_ v: AVSpeechSynthesisVoice) -> String {
        switch v.quality {
        case .premium: return "\(v.name) (Premium)"
        case .enhanced: return "\(v.name) (Avanzata)"
        default: return v.name
        }
    }

    /// true se tra le voci italiane installate non c'è né una Premium né una Avanzata: va suggerito di scaricarla.
    static var soloVociStandard: Bool {
        !vociItaliane().contains { $0.quality == .premium || $0.quality == .enhanced }
    }
}

extension VoceEve: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { if utterance === self.corrente { DiagnosticaVoce.annota("Voce: il sintetizzatore ha iniziato") } }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.concluso(utterance, daSola: true) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.concluso(utterance, daSola: false) }
    }
}

/// Il testo che Eve dice a voce: senza simboli che la sintesi leggerebbe male e, se non si chiede
/// tutto, solo l'inizio della risposta (il resto è scritto nella conversazione).
enum TestoParlato {
    /// Lunghezza massima della parte letta quando non si legge tutto.
    static let limite = 420

    static func da(titolo: String?, testo: String, completo: Bool) -> String {
        var righe: [String] = []
        for r in testo.components(separatedBy: .newlines) {
            let pulita = pulisci(r)
            if !pulita.isEmpty { righe.append(pulita) }
        }
        var corpo = righe.map { r in
            // Ogni riga diventa una frase, così la voce fa la pausa giusta
            let fine = r.last.map { ".!?:;".contains($0) } ?? true
            return fine ? r : r + "."
        }.joined(separator: " ")
        if !completo { corpo = taglia(corpo, a: limite) }
        let t = titolo.map(pulisci).flatMap { $0.isEmpty ? nil : $0 }
        guard let t else { return corpo }
        // Il titolo si dice solo se non è già l'inizio del testo
        if corpo.lowercased().hasPrefix(t.lowercased()) { return corpo }
        let chiuso: Bool = t.last.map { ".!?:".contains($0) } ?? false
        let testa: String = chiuso ? t : t + "."
        return testa + " " + corpo
    }

    /// Toglie simboli, elenchi e markdown: «• **Oggi**: € 1.200 → …» diventa «Oggi: € 1.200 …».
    static func pulisci(_ riga: String) -> String {
        var r = riga
        for s in ["**", "__", "##", "#", "`", "→", "↗", "↘", "✦", "✓", "✚", "▤", "◎", "◈", "☂", "≡", "●", "◷", "⚭", "⇄", "▸", "▶", "–", "—"] {
            r = r.replacingOccurrences(of: s, with: s == "–" || s == "—" ? "," : " ")
        }
        r = r.replacingOccurrences(of: "·", with: ",")
        // Punti elenco e numerazioni a inizio riga
        r = r.replacingOccurrences(of: #"^\s*([•\-\*]|\d+[\.\)])\s+"#, with: "", options: .regularExpression)
        r = r.replacingOccurrences(of: #"\s+([,:;\.!\?])"#, with: "$1", options: .regularExpression)
        r = r.replacingOccurrences(of: #",\s*,"#, with: ",", options: .regularExpression)
        r = r.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        r = r.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",")))
        return r
    }

    /// Taglia alla fine di una frase entro il limite (o alla prima frase, se è più lunga).
    static func taglia(_ testo: String, a limite: Int) -> String {
        guard testo.count > limite, let fineFrase = try? NSRegularExpression(pattern: #"[\.!\?](?=\s|$)"#) else { return testo }
        let ns = testo as NSString
        let fini = fineFrase.matches(in: testo, range: NSRange(location: 0, length: ns.length)).map { $0.range.location + 1 }
        let massimo = (String(testo.prefix(limite)) as NSString).length
        let taglio = fini.last { $0 <= massimo && $0 > massimo / 4 } ?? fini.first
        guard let taglio else { return String(testo.prefix(limite)) + "…" }
        return ns.substring(to: taglio).trimmingCharacters(in: .whitespaces)
    }
}
