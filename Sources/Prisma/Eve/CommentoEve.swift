import Foundation

/// Il commento del consulente nei report: una lettera breve al cliente che accompagna il documento.
/// La bozza la compone Prisma con le stesse frasi e cifre del report; il modello Apple, se c'è,
/// la rende più discorsiva senza toccare i numeri. Il consulente la rilegge sempre prima di stampare.
enum CommentoEve {
    /// Limite del testo nella pagina del report.
    static let limite = 1_400

    /// La bozza composta dai testi del documento (sempre disponibile, numeri esatti).
    static func bozza(nome: String, apertura: String, punti: [(String, String)], passo: String?) -> String {
        var parti = ["Gentile \(primoNome(nome)),", apertura]
        let elenco = punti.prefix(4).map { "• \($0.0): \(dopoDuePunti(minuscola($0.1)))" }
        if !elenco.isEmpty { parti.append(elenco.joined(separator: "\n")) }
        // Il primo passo, se non è già detto nell'elenco
        if let passo, !passo.isEmpty {
            let frase = dopoDuePunti(minuscola(passo))
            if !elenco.contains(where: { $0.contains(frase) }) {
                parti.append("Il primo passo che ti propongo: \(frase)")
            }
        }
        parti.append("Ne parliamo con calma al prossimo incontro: per ogni domanda sono a disposizione.")
        return String(parti.joined(separator: "\n\n").prefix(limite))
    }

    static var istruzioni: String {
        IstruzioniEve.testo("commento") ?? "Riscrivi in italiano la lettera del consulente al cliente: tono cordiale, dai del tu, al massimo 140 parole, testo semplice. Non cambiare né aggiungere numeri, prodotti o promesse."
    }

    /// Scrive il commento con il motore scelto: il modello Apple riscrive la bozza, altrimenti resta la bozza.
    /// Restituisce il testo e il nome di chi l'ha scritto.
    static func scrivi(bozza: String, preferenza: ImpostazioniEve.Motore) async -> (testo: String, motore: String) {
        guard preferenza != .sintesi else { return (bozza, MotoriEve.sintesi.nome) }
        let richiesta = "BOZZA PREPARATA DA PRISMA (numeri esatti: non cambiarli e non aggiungerne)\n" + bozza
            + "\n\nRiscrivi la lettera in modo naturale e personale, con le stesse cifre. Inizia con «Gentile» e il nome."
        if let testo = try? await MotoriEve.generaConApple(istruzioni: istruzioni, richiesta: richiesta) {
            let pulito = testo.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !pulito.isEmpty, numeriConservati(bozza: bozza, testo: pulito) {
                return (String(pulito.prefix(limite)), "Modello Apple")
            }
        }
        return (bozza, MotoriEve.sintesi.nome)
    }

    /// Ogni cifra in euro o in percentuale del testo riscritto deve stare anche nella bozza:
    /// se il modello ne inventa una, si tiene la bozza.
    static func numeriConservati(bozza: String, testo: String) -> Bool {
        cifre(testo).isSubset(of: cifre(bozza))
    }

    static func cifre(_ s: String) -> Set<String> {
        guard let re = try? NSRegularExpression(pattern: "(€\\s?[0-9][0-9.,]*|[0-9][0-9.,]*\\s?%)") else { return [] }
        let r = NSRange(s.startIndex..., in: s)
        return Set(re.matches(in: s, range: r).compactMap { m in
            Range(m.range, in: s).map { s[$0].replacingOccurrences(of: " ", with: "").trimmingCharacters(in: CharacterSet(charactersIn: ".,")) }
        })
    }

    private static func primoNome(_ nome: String) -> String {
        // "Marco ed Elena Bianchi" → "Marco ed Elena"; "Giulia Rossi" → "Giulia"
        let parole = nome.split(separator: " ").map(String.init)
        if let i = parole.firstIndex(where: { $0 == "e" || $0 == "ed" }), i + 1 < parole.count {
            return parole[0...(i + 1)].joined(separator: " ")
        }
        return parole.first ?? nome
    }

    /// "protezione della famiglia: Valutare un capitale" → "…: valutare un capitale" (le sigle restano).
    private static func dopoDuePunti(_ s: String) -> String {
        guard let r = s.range(of: ": ") else { return s }
        return String(s[..<r.upperBound]) + minuscola(String(s[r.upperBound...]))
    }

    private static func minuscola(_ s: String) -> String {
        guard let primo = s.first else { return s }
        // Lascia la maiuscola ai nomi propri e alle sigle ("INPS", "Fondo …")
        let seconda = s.dropFirst().first
        if seconda.map({ $0.isUppercase }) == true { return s }
        return primo.lowercased() + s.dropFirst()
    }
}
