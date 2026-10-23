import Foundation
import PDFKit

/// Prova di carico (`Prisma --prova-carico`), eseguita dal workflow: Prisma con molti clienti
/// (i clienti di prova copiati più volte) deve restare veloce e leggero, pensando al MacBook Pro M1
/// da 8 GB. Misura il salvataggio e la lettura dell'archivio, Eve e i motori su ogni cliente, i PDF
/// e la memoria occupata.
@MainActor
enum ProvaCarico {
    /// Copie dei clienti di prova: 40 copie dei 5 clienti = 200 clienti.
    static let copie = 40
    // Limiti oltre i quali la prova fallisce (larghi: il server di build è più lento del Mac)
    static let limiteArchivio = 3.0
    /// Tempo medio per cliente, e tetto per il cliente più lento (il server ha picchi isolati).
    static let limitePerCliente = 0.1
    static let limiteClientePiuLento = 2.0
    static let limitePDF = 8.0
    static let limiteRicerca = 1.0
    static let limiteNotifiche = 0.1
    static let limiteMemoriaMB = 1_200.0

    static func esegui() -> Int32 {
        var errori = 0
        func controlla(_ ok: Bool, _ descrizione: String) {
            print("\(ok ? "OK   " : "ERRORE") \(descrizione)")
            if !ok { errori += 1 }
        }
        func tempo(_ blocco: () throws -> Void) rethrows -> Double {
            let inizio = Date()
            try blocco()
            return Date().timeIntervalSince(inizio)
        }

        let base = DatiPrisma.demo()
        guard let dati = try? moltiplica(base, copie: copie) else {
            controlla(false, "Archivio con \(copie) copie dei clienti di prova")
            return 1
        }
        print("INFO \(dati.clienti.count) clienti, \(dati.posizioni.count) posizioni, \(dati.appuntamenti.count) appuntamenti, \(dati.attivita.count) attività, \(dati.documenti.count) documenti")

        // Archivio: salvataggio e lettura
        var json = Data()
        let scrittura = (try? tempo { json = try Archivio.codificatore.encode(dati) }) ?? .infinity
        var letto: DatiPrisma?
        let lettura = (try? tempo { letto = try Archivio.decodifica(json) }) ?? .infinity
        print("INFO Archivio: \(json.count / 1024) KB, scrittura \(secondi(scrittura)), lettura \(secondi(lettura))")
        controlla(letto?.clienti.count == dati.clienti.count && letto?.posizioni.count == dati.posizioni.count, "Archivio riletto completo")
        controlla(scrittura + lettura < limiteArchivio, "Archivio salvato e riletto in \(secondi(scrittura + lettura)) (limite \(secondi(limiteArchivio)))")

        // Eve e motori su ogni cliente
        let stato = StatoShell(persistente: false)
        stato.dati = dati
        stato.dati.impostazioni.eve.motore = .sintesi
        let spunti: [SpuntoEve] = [.riepilogo, .checkUp, .proposte, .pensione, .resoconto]
        var peggiore = (nome: "", tempo: 0.0)
        // Un giro di riscaldamento: formattatori ed espressioni regolari si preparano la prima volta
        if let primo = stato.clienti.first, let f = stato.fonteEve(primo.id) {
            for s in spunti { _ = MotoriEve.sintesi.componi(RichiestaEve(domanda: s.domanda, spunto: s, fonte: f, storia: [])) }
        }
        let totale = tempo {
            for c in stato.clienti {
                let t = tempo {
                    guard let f = stato.fonteEve(c.id) else { return }
                    _ = ContestoEve.scheda(f)
                    for s in spunti { _ = MotoriEve.sintesi.componi(RichiestaEve(domanda: s.domanda, spunto: s, fonte: f, storia: [])) }
                }
                if t > peggiore.tempo { peggiore = (c.nome, t) }
            }
        }
        let medio = totale / Double(max(1, stato.clienti.count))
        print("INFO Eve e motori: \(secondi(totale)) per \(stato.clienti.count) clienti, \(secondi(medio)) in media, il più lento \(peggiore.nome) (\(secondi(peggiore.tempo)))")
        controlla(medio < limitePerCliente, "In media sotto \(secondi(limitePerCliente)) per cliente (scheda e \(spunti.count) spunti di Eve)")
        controlla(peggiore.tempo < limiteClientePiuLento, "Nessun cliente oltre \(secondi(limiteClientePiuLento))")

        // «Cerca ovunque» su tutto l'archivio, anche nel testo dei documenti
        var trovati = 0
        _ = MotoreRicerca.cerca("rossi", in: stato)
        let cerca = tempo {
            for q in ["rossi", "polizza", "pensione integrativa", "zzz introvabile"] {
                trovati += MotoreRicerca.cerca(q, in: stato).reduce(0) { $0 + $1.totale }
            }
        }
        print("INFO Ricerca: 4 ricerche, \(trovati) risultati, in \(secondi(cerca))")
        controlla(trovati > 0 && cerca < limiteRicerca, "Ricerca su tutto l'archivio in \(secondi(cerca)) (limite \(secondi(limiteRicerca)))")

        // Centro notifiche su tutto l'archivio (si ricalcola a ogni disegno della barra)
        var quante = 0
        let avvisi = tempo { quante = MotoreNotifiche.calcola(stato).count }
        print("INFO Notifiche: \(quante) in \(secondi(avvisi))")
        controlla(avvisi < limiteNotifiche, "Notifiche calcolate in \(secondi(avvisi)) (limite \(secondi(limiteNotifiche)))")

        // PDF di un report con tutto l'archivio caricato
        stato.clienteAttivoId = stato.clienti.first?.id ?? ""
        var pagine = 0
        let pdf = tempo {
            for scelta in [SceltaProspetto.resoconto(report: true), .checkUp(report: true), .previdenza(report: false)] {
                if let d = stato.documentoProspetto(scelta), let file = StampaCarta.pdf(d) { pagine += PDFDocument(data: file)?.pageCount ?? 0 }
            }
        }
        print("INFO Tre documenti, \(pagine) pagine, in \(secondi(pdf))")
        controlla(pagine > 0 && pdf < limitePDF, "PDF impaginati in \(secondi(pdf)) (limite \(secondi(limitePDF)))")

        // Agenda: il mese raggruppato in un passaggio dà gli stessi giorni del calcolo giorno per giorno
        let giorniMese = CalendarioAgenda.settimane(meseDi: stato.appuntamenti.first?.inizio ?? Date()).flatMap { $0 }
        var indice = GiorniAgenda()
        let agenda = tempo { indice = stato.giorniAgenda(giorniMese) }
        let uguali = giorniMese.allSatisfy { g in
            indice.appuntamenti(g).map(\.id) == stato.appuntamentiDelGiorno(g).map(\.id)
                && Set(indice.scadenze(g).map(\.id)) == Set(stato.scadenzeDelGiorno(g).map(\.id))
        }
        print("INFO Agenda: mese raggruppato in \(secondi(agenda))")
        controlla(uguali, "Agenda: mese raggruppato uguale al calcolo giorno per giorno")

        // Memoria
        let mb = memoriaMB()
        print("INFO Memoria occupata: \(Int(mb)) MB")
        controlla(mb < limiteMemoriaMB, "Memoria sotto \(Int(limiteMemoriaMB)) MB")

        if errori == 0 {
            print("OK: carico verificato")
            return 0
        }
        print("ERRORE: \(errori) verifiche di carico non riuscite")
        return 1
    }

    /// I clienti di prova copiati più volte, con tutti i loro dati: in ogni copia l'identificativo
    /// del cliente prende un suffisso ("giulia" → "giulia-7"), e con lui posizioni, agenda e documenti.
    static func moltiplica(_ base: DatiPrisma, copie: Int) throws -> DatiPrisma {
        var dati = base
        let testo = String(decoding: try Archivio.codificatore.encode(base), as: UTF8.self)
        for k in 1..<max(1, copie) {
            var copia = testo
            for c in base.clienti {
                let re = try NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: c.id))\\b")
                copia = re.stringByReplacingMatches(in: copia, range: NSRange(copia.startIndex..., in: copia), withTemplate: "\(c.id)-\(k)")
            }
            let d = try Archivio.decodifica(Data(copia.utf8))
            dati.clienti += d.clienti
            dati.posizioni += d.posizioni
            dati.appuntamenti += d.appuntamenti
            dati.attivita += d.attivita
            dati.incontri += d.incontri
            dati.obiettivi += d.obiettivi
            dati.documenti += d.documenti
            dati.simulazioni += d.simulazioni
        }
        return dati
    }

    private static func secondi(_ s: Double) -> String {
        s < 1 ? "\(Int((s * 1000).rounded())) ms" : String(format: "%.2f s", s)
    }

    /// Memoria residente del processo, in MB.
    private static func memoriaMB() -> Double {
        var info = mach_task_basic_info()
        var conta = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let esito = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(conta)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &conta)
            }
        }
        return esito == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0
    }
}
