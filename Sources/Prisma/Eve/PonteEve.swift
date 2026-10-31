import CryptoKit
import Foundation
import Network

// Il ponte di Eve: iPhone e iPad usano Qwen sul Mac attraverso la rete di casa o dello studio.
// Il Mac (ServerPonteEve) ascolta in rete locale e si annuncia con Bonjour (_prisma-eve._tcp); il telefono lo trova,
// gli manda la richiesta per il modello e riceve la risposta riga per riga, mentre Qwen la scrive.
// Tutto viaggia cifrato (ChaChaPoly) con una chiave ricavata dal codice di abbinamento: chi è sulla stessa rete
// senza il codice non legge nulla e non può usare il modello. Niente cloud: solo il Mac e i tuoi dispositivi.
// I calcoli restano sul telefono (le cifre di Prisma); al Mac va solo la richiesta per Qwen, come in locale.

/// Il codice di abbinamento e la chiave che ne deriva.
enum PonteEve {
    /// Il servizio Bonjour del Mac (anche in Info.plist: NSBonjourServices).
    static let servizio = "_prisma-eve._tcp"
    static let porta: UInt16 = 47_620
    /// Il percorso unico del ponte: ogni richiesta è una busta cifrata.
    static let percorso = "ponte"
    /// Una busta più vecchia (o più nuova) di così non vale: nessuno può rimandare una richiesta registrata.
    static let tolleranzaOrologio: TimeInterval = 120
    /// La busta più grande che il Mac accetta (una scheda del cliente con la storia sta ben sotto).
    static let massimoBusta = 4 * 1_024 * 1_024
    /// I percorsi del modello che il telefono può chiedere: solo le risposte, mai la gestione dei modelli.
    static let percorsiAmmessi: Set<String> = ["api/chat", "v1/chat/completions"]

    /// 12 lettere e cifre senza quelle che si confondono (0/O, 1/I/L): circa 60 bit, in tre gruppi da 4.
    static let alfabeto = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    static func nuovoCodice() -> String {
        var g = SystemRandomNumberGenerator()
        let lettere = (0..<12).map { _ in alfabeto[Int(g.next(upperBound: UInt32(alfabeto.count)))] }
        return stride(from: 0, to: 12, by: 4).map { String(lettere[$0..<$0 + 4]) }.joined(separator: "-")
    }

    /// Il codice come lo scrive la persona: maiuscole, senza spazi né trattini; nil se non è un codice valido.
    static func normalizza(_ testo: String) -> String? {
        let pulito = testo.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard pulito.count == 12, pulito.allSatisfy({ alfabeto.contains($0) }) else { return nil }
        return pulito
    }

    /// Lo stesso codice dà la stessa chiave sul Mac e sul telefono (HKDF-SHA256).
    static func chiave(_ codice: String) -> SymmetricKey? {
        guard let c = normalizza(codice) else { return nil }
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(c.utf8)),
                                      salt: Data("Prisma · Eve · ponte · 1".utf8), outputByteCount: 32)
    }

    static func sigilla(_ dati: Data, _ k: SymmetricKey) throws -> Data {
        try ChaChaPoly.seal(dati, using: k).combined
    }

    static func apri(_ dati: Data, _ k: SymmetricKey) -> Data? {
        guard let scatola = try? ChaChaPoly.SealedBox(combined: dati) else { return nil }
        return try? ChaChaPoly.open(scatola, using: k)
    }

    /// Una riga della risposta: il JSON del modello cifrato, in base64 (una riga per pezzo, come arriva da Ollama).
    static func sigillaRiga(_ riga: String, _ k: SymmetricKey) throws -> String {
        try sigilla(Data(riga.utf8), k).base64EncodedString()
    }

    static func apriRiga(_ riga: String, _ k: SymmetricKey) -> String? {
        let r = riga.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty, let d = Data(base64Encoded: r), let aperta = apri(d, k) else { return nil }
        return String(data: aperta, encoding: .utf8)
    }
}

/// Le impostazioni del ponte (dentro le impostazioni di Eve, quindi anche nel backup: aprendo il backup del Mac
/// sul telefono il codice arriva da solo).
struct ImpostazioniPonte: Codable, Equatable {
    /// Sul Mac: iPhone e iPad possono usare Qwen di questo Mac.
    var condividi = false
    /// Il codice di abbinamento (vuoto = nessun abbinamento).
    var codice = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        condividi = (try? c.decodeIfPresent(Bool.self, forKey: .condividi)) ?? false
        codice = (try? c.decodeIfPresent(String.self, forKey: .codice)) ?? ""
    }

    var abbinato: Bool { PonteEve.normalizza(codice) != nil }
}

/// Cosa c'è dentro una busta: quando è partita, il percorso e il corpo per il modello.
struct BustaPonte: Codable, Equatable {
    /// Secondi dal 1970: la busta vale solo per poco.
    var quando: Double
    /// «api/chat», «v1/chat/completions» oppure i comandi del ponte («prisma/stato», «prisma/precarica»).
    var percorso: String
    /// Il corpo JSON da passare al modello (nil per i comandi del ponte).
    var corpo: Data?

    static let stato = "prisma/stato"
    static let precarica = "prisma/precarica"

    func sigillata(_ k: SymmetricKey) throws -> Data {
        try PonteEve.sigilla(JSONEncoder().encode(self), k)
    }

    /// La busta se si apre con la chiave e non è scaduta.
    static func apri(_ dati: Data, _ k: SymmetricKey, adesso: Date = Date()) -> BustaPonte? {
        guard let d = PonteEve.apri(dati, k), let b = try? JSONDecoder().decode(BustaPonte.self, from: d),
              abs(adesso.timeIntervalSince1970 - b.quando) <= PonteEve.tolleranzaOrologio else { return nil }
        return b
    }
}

/// Come sta Qwen sul Mac: la risposta a «prisma/stato».
struct StatoPonte: Codable, Equatable {
    var pronto: Bool
    var motivo: String?
    var fornitore: TipoFornitore
    var modello: String
    /// Il nome del Mac («MacBook Pro di Denis»), per dire al telefono a chi è collegato.
    var mac: String
}

// MARK: - Il fornitore del telefono

/// Su iPhone e iPad: il modello del Mac, attraverso il ponte. I corpi delle richieste sono quelli del fornitore
/// scelto sul Mac (Ollama o compatibile OpenAI), cifrati in una busta; le righe della risposta tornano cifrate.
struct FornitorePonte: FornitoreModello {
    /// http://indirizzo-del-mac:47620
    let indirizzo: String
    let codice: String
    /// Fornitore e modello del Mac (dall'ultimo «prisma/stato»).
    var tipo: TipoFornitore
    let modello: String
    var sessione: URLSession = .shared
    var mac = "Mac"

    var nome: String { "Qwen sul \(mac)" }

    /// Il fornitore del Mac, usato solo per comporre i corpi e leggere le righe (l'indirizzo non conta).
    private var interno: FornitoreModello {
        switch tipo {
        case .ollama: return FornitoreOllama(indirizzo: FornitoreOllama.indirizzoPredefinito, modello: modello, sessione: sessione)
        case .compatibileOpenAI:
            return FornitoreCompatibileOpenAI(indirizzo: FornitoreCompatibileOpenAI.indirizzoPredefinito, modello: modello, sessione: sessione)
        }
    }

    private var chiave: SymmetricKey? { PonteEve.chiave(codice) }

    private var urlPonte: URL? {
        guard let base = URL(string: indirizzo), base.scheme == "http", base.host != nil else { return nil }
        return base.appendingPathComponent(PonteEve.percorso)
    }

    /// La richiesta del ponte: la busta cifrata con il percorso e il corpo del fornitore del Mac.
    func busta(_ percorso: String, corpo: Data?, attesa: TimeInterval) throws -> URLRequest {
        guard let k = chiave else { throw ErroreEve(messaggio: "Il codice del Mac non è valido: ricopialo da Impostazioni › Eve sul Mac.") }
        guard let u = urlPonte else { throw ErroreEve(messaggio: "Non trovo il Mac in rete: Mac e telefono devono essere sulla stessa rete Wi‑Fi.") }
        var r = URLRequest(url: u, timeoutInterval: attesa)
        r.httpMethod = "POST"
        r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        r.httpBody = try BustaPonte(quando: Date().timeIntervalSince1970, percorso: percorso, corpo: corpo).sigillata(k)
        return r
    }

    func richiesta(_ messaggi: [MessaggioModello], opzioni: OpzioniModello) throws -> URLRequest {
        let r = try interno.richiesta(messaggi, opzioni: opzioni)
        let percorso = String((r.url?.path ?? "").drop { $0 == "/" })
        return try busta(percorso, corpo: r.httpBody, attesa: MotoreLocale.attesaMassima)
    }

    func lettore() -> LettoreFlusso {
        LettorePonte(interno: interno.lettore(), chiave: chiave)
    }

    /// Ogni riga è cifrata: si apre e passa al lettore del fornitore del Mac.
    struct LettorePonte: LettoreFlusso {
        var interno: LettoreFlusso
        let chiave: SymmetricKey?

        mutating func leggi(_ riga: String) throws -> [PezzoModello] {
            guard !riga.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
            guard let k = chiave, let chiara = PonteEve.apriRiga(riga, k) else {
                throw ErroreEve(messaggio: "La risposta del Mac non si legge: il codice del telefono è diverso da quello del Mac.")
            }
            return try interno.leggi(chiara)
        }

        mutating func fine() -> [PezzoModello] { interno.fine() }
    }

    /// «prisma/stato»: come sta Qwen sul Mac (nil se il Mac non risponde o il codice è sbagliato).
    func stato(attesa: TimeInterval = 4) async -> StatoPonte? {
        guard let r = try? busta(BustaPonte.stato, corpo: nil, attesa: attesa),
              case let (dati, risposta)? = try? await sessione.data(for: r),
              (risposta as? HTTPURLResponse)?.statusCode == 200, let k = chiave,
              let chiaro = PonteEve.apri(dati, k) else { return nil }
        return try? JSONDecoder().decode(StatoPonte.self, from: chiaro)
    }

    func verifica() async -> DisponibilitaEve {
        guard chiave != nil else { return .nonDisponibile("Il codice del Mac non è valido: ricopialo da Impostazioni › Eve sul Mac.") }
        guard urlPonte != nil else { return .nonDisponibile(PonteEve.macNonTrovato) }
        guard let s = await stato() else {
            return .nonDisponibile("Il Mac non risponde: Prisma deve essere aperto sul Mac, con «iPhone e iPad» attivo in Impostazioni › Eve, e il codice deve essere lo stesso.")
        }
        PonteEve.ricorda(s)
        return s.pronto ? .pronto : .nonDisponibile("Sul \(s.mac): " + (s.motivo ?? "Qwen non è pronto."))
    }

    func modelli() async throws -> [String] {
        guard let s = await stato() else { throw ErroreEve(messaggio: PonteEve.macNonTrovato) }
        return [s.modello]
    }

    func raggiungibile() async -> Bool { await stato(attesa: 2) != nil }

    func precarica(restaInMemoria: String) async -> Bool {
        guard let r = try? busta(BustaPonte.precarica, corpo: Data(restaInMemoria.utf8), attesa: 120),
              case let (_, risposta)? = try? await sessione.data(for: r) else { return false }
        return (risposta as? HTTPURLResponse)?.statusCode == 200
    }

    /// La memoria del modello la gestisce il Mac.
    func libera() async {}
}

// MARK: - Il Mac in rete

extension PonteEve {
    static let macNonTrovato = "Non trovo il Mac in rete: Prisma deve essere aperto sul Mac e Mac e telefono sulla stessa rete Wi‑Fi."

    private static let blocco = NSLock()
    private static var _ultimo: StatoPonte?
    private static var _indirizzo: String?

    /// L'ultimo stato del Mac: fornitore e modello per comporre le richieste.
    static var ultimo: StatoPonte? {
        blocco.lock(); defer { blocco.unlock() }
        return _ultimo
    }

    static func ricorda(_ s: StatoPonte) {
        blocco.lock(); defer { blocco.unlock() }
        _ultimo = s
    }

    /// L'indirizzo del Mac trovato in rete (http://192.168.1.20:47620); resta da una ricerca all'altra.
    static var indirizzo: String? {
        get {
            blocco.lock(); defer { blocco.unlock() }
            return _indirizzo ?? UserDefaults.standard.string(forKey: chiaveIndirizzo)
        }
        set {
            blocco.lock()
            _indirizzo = newValue
            blocco.unlock()
            UserDefaults.standard.set(newValue, forKey: chiaveIndirizzo)
        }
    }

    private static let chiaveIndirizzo = "PonteEve.indirizzo"

    /// Il fornitore del ponte con l'ultimo indirizzo e l'ultimo stato noti.
    static func fornitore(_ eve: ImpostazioniEve, sessione: URLSession = .shared) -> FornitorePonte {
        let s = ultimo
        return FornitorePonte(indirizzo: indirizzo ?? "", codice: eve.ponte.codice, tipo: s?.fornitore ?? eve.fornitore,
                              modello: s?.modello ?? eve.modello, sessione: sessione, mac: s?.mac ?? "Mac")
    }

    /// Cerca il Mac: prima l'ultimo indirizzo, poi Bonjour. Restituisce la disponibilità (con il motivo se no).
    static func collega(_ eve: ImpostazioniEve) async -> DisponibilitaEve {
        guard eve.ponte.abbinato else {
            return .nonDisponibile("Collega il telefono al Mac: sul Mac, in Impostazioni › Eve, attiva «iPhone e iPad» e scrivi qui il codice che compare.")
        }
        // L'ultimo indirizzo risponde ancora: niente ricerca
        if indirizzo != nil, await fornitore(eve).stato(attesa: 2) != nil { return await fornitore(eve).verifica() }
        guard let trovato = await RicercaMac.trova() else { return .nonDisponibile(macNonTrovato) }
        indirizzo = trovato
        return await fornitore(eve).verifica()
    }
}

/// Cerca il Mac con Bonjour e ne ricava l'indirizzo IPv4 (http://host:porta).
enum RicercaMac {
    static let attesa: TimeInterval = 5

    static func trova() async -> String? {
        await withCheckedContinuation { (fine: CheckedContinuation<String?, Never>) in
            let ricerca = Ricerca(fine)
            ricerca.avvia()
        }
    }

    /// Una ricerca: il primo Mac che risponde, oppure nil dopo `attesa` secondi.
    private final class Ricerca: @unchecked Sendable {
        private var fine: CheckedContinuation<String?, Never>?
        private var browser: NWBrowser?
        private var connessioni: [NWConnection] = []
        private let coda = DispatchQueue(label: "prisma.ponte.ricerca")

        init(_ fine: CheckedContinuation<String?, Never>) { self.fine = fine }

        func avvia() {
            let parametri = NWParameters.tcp
            parametri.includePeerToPeer = false
            let b = NWBrowser(for: .bonjour(type: PonteEve.servizio, domain: nil), using: parametri)
            browser = b
            b.browseResultsChangedHandler = { [weak self] risultati, _ in
                guard let self else { return }
                for r in risultati { self.risolvi(r.endpoint) }
            }
            b.stateUpdateHandler = { [weak self] s in
                if case .failed = s { self?.chiudi(nil) }
            }
            b.start(queue: coda)
            coda.asyncAfter(deadline: .now() + RicercaMac.attesa) { [weak self] in self?.chiudi(nil) }
        }

        /// Collegarsi al servizio dice l'indirizzo vero del Mac (solo IPv4: niente indirizzi IPv6 con interfaccia).
        private func risolvi(_ e: NWEndpoint) {
            let p = NWParameters.tcp
            if let ip = p.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options { ip.version = .v4 }
            let c = NWConnection(to: e, using: p)
            connessioni.append(c)
            c.stateUpdateHandler = { [weak self, weak c] s in
                guard let self, let c else { return }
                if case .ready = s, case let .hostPort(host, porta)? = c.currentPath?.remoteEndpoint {
                    var h = "\(host)"
                    if let i = h.firstIndex(of: "%") { h = String(h[..<i]) }
                    self.chiudi("http://\(h):\(porta.rawValue)")
                }
            }
            c.start(queue: coda)
        }

        private func chiudi(_ indirizzo: String?) {
            guard let f = fine else { return }
            fine = nil
            browser?.cancel()
            connessioni.forEach { $0.cancel() }
            connessioni = []
            f.resume(returning: indirizzo)
        }
    }
}
