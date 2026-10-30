import Foundation

/// Confronto tra modelli: le stesse domande di prova a 2–3 modelli installati, con risposte e tempi affiancati.
/// Usa i dati di prova di Prisma (clienti fittizi), mai quelli veri. Un modello alla volta, e dopo ogni modello
/// la memoria si libera: sul Mac da 8 GB due modelli insieme non stanno.
/// Da Impostazioni › Eve («Confronta») oppure dal Terminale: `Prisma --confronta-modelli qwen3.5:4b,qwen3:8b`.
enum ConfrontoModelli {
    static let predefiniti = "qwen3.5:4b, qwen3:8b, gemma4:e4b"
    /// Il cliente di prova delle domande di lavoro.
    static let clienteProva = "giulia"

    struct Domanda {
        var titolo: String
        var testo: String
        var spunto: SpuntoEve?
    }

    struct Esito {
        var modello: String
        var domanda: String
        var testo = ""
        var errore: String?
        var modalita: ModalitaEve = .conversazione
        var pensa = false
        /// Secondi fino alla prima parola visibile e fino alla fine.
        var primaParola: Double?
        var totale: Double = 0
        var tokenAlSecondo: Double?
    }

    struct Rapporto {
        var data = Date()
        var modelli: [String] = []
        var domande: [Domanda] = []
        var esiti: [Esito] = []
        /// Secondi per caricare ogni modello in memoria.
        var caricamento: [String: Double] = [:]
    }

    /// I nomi scritti nelle impostazioni («a, b; c») in ordine, senza doppioni.
    static func elenco(_ testo: String) -> [String] {
        var visti = Set<String>()
        return testo.split { $0 == "," || $0 == ";" || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && visti.insert($0.lowercased()).inserted }
    }

    static func domande(cliente: String) -> [Domanda] {
        [
            Domanda(titolo: "Conversazione", testo: "Spiegami in parole semplici cos'è l'inflazione e perché erode i risparmi."),
            Domanda(titolo: "Scrittura", testo: "Scrivimi una breve mail cordiale per ricordare a un cliente l'appuntamento di giovedì alle 15."),
            Domanda(titolo: "Ragionamento", testo: "Pensaci bene: meglio estinguere prima un mutuo al 3% o investire in un fondo che rende il 4% lordo? Pro e contro."),
            Domanda(titolo: "Lavoro · spunto", testo: SpuntoEve.riepilogo.domanda, spunto: .riepilogo),
            Domanda(titolo: "Lavoro · domanda libera", testo: "Quanto manca a \(cliente) per la pensione e cosa potremmo proporle?"),
        ]
    }

    /// Pone le domande a ogni modello, uno dopo l'altro. `avanzamento` dice a che punto è.
    static func esegui(modelli: [String], eve: ImpostazioniEve, fonte: FonteEve, sessione: URLSession = .shared,
                       avanzamento: @escaping (String) -> Void = { _ in }) async -> Rapporto {
        var rapporto = Rapporto(modelli: modelli, domande: domande(cliente: fonte.cliente.nome))
        for nome in modelli {
            var impostazioni = eve
            impostazioni.modello = nome
            let motore = MotoreLocale(impostazioni, disponibilita: .pronto, sessione: sessione)
            avanzamento("Carico \(nome)…")
            let disponibile = await motore.fornitore.verifica()
            if let motivo = disponibile.motivo {
                for d in rapporto.domande { rapporto.esiti.append(Esito(modello: nome, domanda: d.titolo, errore: motivo)) }
                continue
            }
            let inizioCarico = Date()
            _ = await motore.fornitore.precarica(restaInMemoria: impostazioni.restaInMemoria)
            rapporto.caricamento[nome] = Date().timeIntervalSince(inizioCarico)
            for (i, d) in rapporto.domande.enumerated() {
                avanzamento("\(nome): domanda \(i + 1) di \(rapporto.domande.count)")
                let richiesta = RichiestaEve(domanda: d.testo, spunto: d.spunto, fonte: fonte, storia: [])
                let piano = NucleoEve.piano(richiesta, impostazioni: impostazioni, ambiente: AmbienteEve(appAperte: ["Eve"], cliente: fonte.cliente.nome))
                var esito = Esito(modello: nome, domanda: d.titolo, modalita: piano.scelta.modalita, pensa: piano.scelta.pensa)
                let inizio = Date()
                var prima: Double?
                do {
                    let r = try await motore.scrivi(piano) { p in
                        if prima == nil, !p.testo.isEmpty { prima = Date().timeIntervalSince(inizio) }
                    }
                    esito.testo = r.testo
                    esito.tokenAlSecondo = r.statistiche?.tokenAlSecondo
                } catch {
                    esito.errore = error.localizedDescription
                }
                esito.primaParola = prima
                esito.totale = Date().timeIntervalSince(inizio)
                rapporto.esiti.append(esito)
            }
            // La memoria torna libera prima del modello successivo
            await motore.fornitore.libera()
        }
        avanzamento("Confronto finito")
        return rapporto
    }

    // MARK: - Il rapporto

    private static func secondi(_ s: Double?) -> String {
        s.map { String(format: "%.1f s", $0).replacingOccurrences(of: ".", with: ",") } ?? "—"
    }

    private static func esito(_ r: Rapporto, _ modello: String, _ domanda: String) -> Esito? {
        r.esiti.first { $0.modello == modello && $0.domanda == domanda }
    }

    /// Il rapporto in testo (per il Terminale).
    static func testo(_ r: Rapporto) -> String {
        var righe = ["# Confronto tra modelli di Eve", "", "\(Formati.dataEstesa.string(from: r.data)) · domande sui dati di prova", ""]
        righe.append("| Domanda | " + r.modelli.joined(separator: " | ") + " |")
        righe.append("|---|" + r.modelli.map { _ in "---|" }.joined())
        righe.append("| Caricamento | " + r.modelli.map { secondi(r.caricamento[$0]) }.joined(separator: " | ") + " |")
        for d in r.domande {
            let celle = r.modelli.map { m -> String in
                guard let e = esito(r, m, d.titolo) else { return "—" }
                if e.errore != nil { return "errore" }
                let velocita = e.tokenAlSecondo.map { String(format: " · %.0f tok/s", $0) } ?? ""
                return "\(secondi(e.primaParola)) / \(secondi(e.totale))\(velocita)"
            }
            righe.append("| \(d.titolo) | " + celle.joined(separator: " | ") + " |")
        }
        righe.append("")
        righe.append("Tempi: prima parola / risposta completa.")
        for d in r.domande {
            righe.append("")
            righe.append("## \(d.titolo)")
            righe.append("> \(d.testo)")
            for m in r.modelli {
                guard let e = esito(r, m, d.titolo) else { continue }
                righe.append("")
                righe.append("### \(m) — \(e.modalita.rawValue)\(e.pensa ? ", con ragionamento" : "")")
                righe.append(e.errore.map { "Errore: \($0)" } ?? e.testo)
            }
        }
        return righe.joined(separator: "\n")
    }

    /// Il rapporto come pagina HTML: una colonna per modello, affiancate.
    static func html(_ r: Rapporto) -> String {
        func h(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        var p = ["<!doctype html><html lang=\"it\"><head><meta charset=\"utf-8\"><title>Confronto tra modelli di Eve</title><style>\(StileConfronto.css)</style></head><body>"]
        p.append("<h1>Confronto tra modelli di Eve</h1><div class=\"nota\">\(h(Formati.dataEstesa.string(from: r.data))) · domande sui dati di prova di Prisma · tempi: prima parola / risposta completa</div>")
        p.append("<table><tr><th>Domanda</th>" + r.modelli.map { "<th>\(h($0))</th>" }.joined() + "</tr>")
        p.append("<tr><td>Caricamento</td>" + r.modelli.map { "<td>\(secondi(r.caricamento[$0]))</td>" }.joined() + "</tr>")
        for d in r.domande {
            p.append("<tr><td>\(h(d.titolo))</td>" + r.modelli.map { m -> String in
                guard let e = esito(r, m, d.titolo) else { return "<td>—</td>" }
                if e.errore != nil { return "<td>errore</td>" }
                let velocita = e.tokenAlSecondo.map { String(format: " · %.0f tok/s", $0) } ?? ""
                return "<td>\(secondi(e.primaParola)) / \(secondi(e.totale))\(velocita)</td>"
            }.joined() + "</tr>")
        }
        p.append("</table>")
        for d in r.domande {
            p.append("<h2>\(h(d.titolo))</h2><p class=\"domanda\">«\(h(d.testo))»</p><div class=\"colonne\">")
            for m in r.modelli {
                guard let e = esito(r, m, d.titolo) else { continue }
                let corpo = e.errore.map { "<p class=\"errore\">\(h($0))</p>" } ?? "<p>\(h(e.testo))</p>"
                p.append("<div class=\"colonna\"><h3>\(h(m))</h3><div class=\"nota\">\(e.modalita.rawValue)\(e.pensa ? " · con ragionamento" : "") · \(secondi(e.primaParola)) / \(secondi(e.totale))</div>\(corpo)</div>")
            }
            p.append("</div>")
        }
        p.append("</body></html>")
        return p.joined(separator: "\n")
    }
}

extension ConfrontoModelli {
    /// `Prisma --confronta-modelli [modelli separati da virgole] [file.html]`: stampa la tabella e le risposte,
    /// e salva la pagina con le colonne affiancate (di solito in «Confronto modelli di Eve.html» nella cartella attuale).
    static func daRigaDiComando(_ argomenti: [String]) -> Int32 {
        let dopo = argomenti.firstIndex(of: "--confronta-modelli").map { Array(argomenti[($0 + 1)...]) } ?? []
        let liberi = dopo.prefix { !$0.hasPrefix("--") }
        let modelli = elenco(liberi.first(where: { !$0.lowercased().hasSuffix(".html") }) ?? predefiniti)
        let file = URL(fileURLWithPath: liberi.first(where: { $0.lowercased().hasSuffix(".html") }) ?? "Confronto modelli di Eve.html")
        guard let fonte = StatoShell(persistente: false).fonteEve(clienteProva) else {
            print("ERRORE dati di prova non trovati")
            return 1
        }
        print("Confronto tra \(modelli.joined(separator: ", ")) sui dati di prova (Ollama, \(FornitoreOllama.indirizzoPredefinito))")
        final class Scatola: @unchecked Sendable { var r = Rapporto() }
        let scatola = Scatola()
        let fatto = DispatchSemaphore(value: 0)
        Task.detached {
            scatola.r = await esegui(modelli: modelli, eve: ImpostazioniEve(), fonte: fonte) { print("… \($0)") }
            fatto.signal()
        }
        fatto.wait()
        print(testo(scatola.r))
        do {
            try html(scatola.r).write(to: file, atomically: true, encoding: .utf8)
            print("\nPagina con le risposte affiancate: \(file.path)")
        } catch {
            print("ERRORE pagina non salvata: \(error.localizedDescription)")
        }
        return scatola.r.esiti.contains { $0.errore == nil } ? 0 : 1
    }
}
