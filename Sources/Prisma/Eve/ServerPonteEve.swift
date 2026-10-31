#if os(macOS)
import CryptoKit
import Foundation
import Network

/// Il Mac nel ponte di Eve (PonteEve.swift): ascolta in rete locale sulla porta 47620, si annuncia con Bonjour
/// e passa a Qwen, sul Mac stesso, le buste cifrate di iPhone e iPad. Le righe della risposta tornano cifrate,
/// una per pezzo, mentre Qwen scrive. Senza il codice di abbinamento non si apre nessuna busta.
/// Acceso solo con «iPhone e iPad» attivo in Impostazioni › Eve; leggero: nessun lavoro quando nessuno chiede.
final class ServerPonteEve: @unchecked Sendable {
    static let condiviso = ServerPonteEve()

    private let coda = DispatchQueue(label: "prisma.ponte.server")
    private let blocco = NSLock()
    private var ascolto: NWListener?
    private var eve = ImpostazioniEve()
    private var chiave: SymmetricKey?
    /// La sessione verso il modello sul Mac (le prove ne passano una finta).
    private var sessione: URLSession = .shared
    private var annuncia = true

    /// La porta su cui ascolta davvero (nelle prove una porta libera qualsiasi).
    private(set) var porta: UInt16?
    /// Nome del Mac per il telefono: «MacBook Pro di Denis».
    let nomeMac = Host.current().localizedName ?? "Mac"

    /// Accende, aggiorna o spegne il ponte secondo le impostazioni di Eve.
    func aggiorna(_ e: ImpostazioniEve, sessione s: URLSession = .shared, porta p: UInt16 = PonteEve.porta, annuncia a: Bool = true) {
        blocco.lock()
        eve = e
        chiave = e.ponte.condividi ? PonteEve.chiave(e.ponte.codice) : nil
        sessione = s
        annuncia = a
        let acceso = chiave != nil
        let gia = ascolto != nil
        blocco.unlock()
        if acceso, !gia { avvia(p) } else if !acceso, gia { ferma() }
    }

    func ferma() {
        blocco.lock()
        let a = ascolto
        ascolto = nil
        porta = nil
        blocco.unlock()
        a?.cancel()
    }

    var acceso: Bool {
        blocco.lock(); defer { blocco.unlock() }
        return ascolto != nil
    }

    private func avvia(_ p: UInt16) {
        let parametri = NWParameters.tcp
        parametri.includePeerToPeer = false
        guard let a = try? NWListener(using: parametri, on: p == 0 ? .any : (NWEndpoint.Port(rawValue: p) ?? .any)) else {
            DiagnosticaVoce.annota("Ponte di Eve: la porta \(p) non è libera")
            return
        }
        blocco.lock()
        if annuncia { a.service = NWListener.Service(name: nomeMac, type: PonteEve.servizio) }
        ascolto = a
        blocco.unlock()
        a.stateUpdateHandler = { [weak self, weak a] s in
            guard let self, let a else { return }
            switch s {
            case .ready:
                self.blocco.lock()
                self.porta = a.port?.rawValue
                self.blocco.unlock()
            case .failed(let e):
                DiagnosticaVoce.annota("Ponte di Eve: \(e.localizedDescription)")
                self.ferma()
            default: break
            }
        }
        a.newConnectionHandler = { [weak self] c in self?.accogli(c) }
        a.start(queue: coda)
    }

    // MARK: - Una richiesta

    private func accogli(_ c: NWConnection) {
        c.start(queue: coda)
        Task { await self.servi(c) }
    }

    private func impostazioni() -> (ImpostazioniEve, SymmetricKey?, URLSession) {
        blocco.lock(); defer { blocco.unlock() }
        return (eve, chiave, sessione)
    }

    private func servi(_ c: NWConnection) async {
        defer { c.cancel() }
        guard let richiesta = await leggiRichiesta(c) else { return await rispondi(c, 400, "richiesta non valida") }
        let (testa, corpo) = richiesta
        guard testa.hasPrefix("POST /\(PonteEve.percorso) ") else { return await rispondi(c, 404, "percorso sconosciuto") }
        let (e, k, s) = impostazioni()
        guard let k, let busta = BustaPonte.apri(corpo, k) else { return await rispondi(c, 403, "codice di abbinamento diverso") }
        let fornitore = FornitoriEve.crea(e, sessione: s)
        switch busta.percorso {
        case BustaPonte.stato:
            let d: DisponibilitaEve = await fornitore.verifica()
            let st = StatoPonte(pronto: d.pronto, motivo: d.motivo, fornitore: e.fornitore, modello: e.modello, mac: nomeMac)
            guard let dati = try? PonteEve.sigilla(JSONEncoder().encode(st), k) else { return await rispondi(c, 500, "errore") }
            await scrivi(c, Self.testata(200) + dati)
        case BustaPonte.precarica:
            let memoria = busta.corpo.flatMap { String(data: $0, encoding: .utf8) } ?? e.restaInMemoria
            let ok = await fornitore.precarica(restaInMemoria: memoria.isEmpty ? e.restaInMemoria : memoria)
            await rispondi(c, ok ? 200 : 503, ok ? "pronto" : "non caricato")
        case let p where PonteEve.percorsiAmmessi.contains(p):
            await inoltra(c, p, busta.corpo, fornitore: fornitore, modello: e.modello, sessione: s, chiave: k)
        default:
            await rispondi(c, 404, "percorso sconosciuto")
        }
    }

    /// Passa la richiesta al modello sul Mac (sempre il modello scelto qui) e rimanda le righe cifrate.
    private func inoltra(_ c: NWConnection, _ percorso: String, _ corpo: Data?, fornitore: FornitoreModello,
                         modello: String, sessione: URLSession, chiave k: SymmetricKey) async {
        guard let corpo, var j = (try? JSONSerialization.jsonObject(with: corpo)) as? [String: Any],
              let u = try? fornitore.url(percorso) else { return await rispondi(c, 400, "corpo non valido") }
        j["model"] = modello
        var r = URLRequest(url: u, timeoutInterval: MotoreLocale.attesaMassima)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: j)
        do {
            let (byte, risposta) = try await sessione.bytes(for: r)
            let codice = (risposta as? HTTPURLResponse)?.statusCode ?? 502
            guard codice == 200 else {
                // L'errore del modello (modello mancante, memoria): breve e in chiaro, come lo darebbe Ollama
                var testo = ""
                for try await riga in byte.lines {
                    testo += riga
                    if testo.count > 300 { break }
                }
                return await rispondi(c, codice, testo)
            }
            guard await scrivi(c, Self.testata(200)) else { return }
            for try await riga in byte.lines {
                guard !riga.trimmingCharacters(in: .whitespaces).isEmpty, let s = try? PonteEve.sigillaRiga(riga, k) else { continue }
                // Il telefono ha chiuso: si smette di leggere e la connessione con il modello si chiude
                guard await scrivi(c, Data((s + "\n").utf8)) else { return }
            }
        } catch {
            await rispondi(c, 502, "\(fornitore.nome) non ha risposto sul Mac")
        }
    }

    // MARK: - HTTP essenziale

    private static func testata(_ codice: Int) -> Data {
        Data("HTTP/1.1 \(codice) \(codice == 200 ? "OK" : "Errore")\r\nContent-Type: application/octet-stream\r\nConnection: close\r\n\r\n".utf8)
    }

    private func rispondi(_ c: NWConnection, _ codice: Int, _ testo: String) async {
        await scrivi(c, Self.testata(codice) + Data(testo.utf8))
    }

    @discardableResult
    private func scrivi(_ c: NWConnection, _ dati: Data) async -> Bool {
        await withCheckedContinuation { (fine: CheckedContinuation<Bool, Never>) in
            c.send(content: dati, completion: .contentProcessed { e in fine.resume(returning: e == nil) })
        }
    }

    private func ricevi(_ c: NWConnection) async -> Data? {
        await withCheckedContinuation { (fine: CheckedContinuation<Data?, Never>) in
            c.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { dati, _, finito, errore in
                if let dati, !dati.isEmpty { return fine.resume(returning: dati) }
                fine.resume(returning: (finito || errore != nil) ? nil : Data())
            }
        }
    }

    /// La prima riga della richiesta e il corpo (Content-Length), entro i limiti del ponte.
    private func leggiRichiesta(_ c: NWConnection) async -> (String, Data)? {
        var dati = Data()
        let separatore = Data("\r\n\r\n".utf8)
        var fineTesta: Range<Data.Index>?
        while fineTesta == nil {
            guard dati.count < 16_384, let pezzo = await ricevi(c) else { return nil }
            dati.append(pezzo)
            fineTesta = dati.range(of: separatore)
        }
        guard let f = fineTesta, let testa = String(data: dati[..<f.lowerBound], encoding: .utf8) else { return nil }
        let righe = testa.components(separatedBy: "\r\n")
        let lunghezza = righe.dropFirst().compactMap { r -> Int? in
            let parti = r.split(separator: ":", maxSplits: 1)
            guard parti.count == 2, parti[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" else { return nil }
            return Int(parti[1].trimmingCharacters(in: .whitespaces))
        }.first ?? 0
        guard lunghezza > 0, lunghezza <= PonteEve.massimoBusta else { return nil }
        var corpo = Data(dati[f.upperBound...])
        while corpo.count < lunghezza {
            guard let pezzo = await ricevi(c) else { return nil }
            corpo.append(pezzo)
        }
        return (righe.first ?? "", corpo.prefix(lunghezza))
    }
}
#endif
