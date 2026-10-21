import Foundation

/// Prova automatica di backup, rotazione e ripristino (`Prisma --prova-backup`).
/// La esegue il workflow di build in cartelle temporanee: l'archivio vero non viene toccato.
enum ProvaBackup {
    static func esegui() -> Int32 {
        let fm = FileManager.default
        let radice = fm.temporaryDirectory.appendingPathComponent("Prisma-prova-\(UUID().uuidString)", isDirectory: true)
        let dati = radice.appendingPathComponent("Prisma", isDirectory: true)
        let backup = radice.appendingPathComponent("Backup", isDirectory: true)
        let destinazione = radice.appendingPathComponent("Ripristino", isDirectory: true)
        defer { try? fm.removeItem(at: radice) }
        do {
            try fm.createDirectory(at: dati.appendingPathComponent("Documenti"), withIntermediateDirectories: true)
            let originale = DatiPrisma.demo()
            try Archivio.codificatore.encode(originale).write(to: dati.appendingPathComponent("archivio.json"))
            try Data("documento di prova".utf8).write(to: dati.appendingPathComponent("Documenti/prova.txt"))

            // Rotazione: dopo 10 backup ne restano 8
            for i in 0..<10 {
                try GestoreBackup.crea(sorgente: dati, destinazione: backup, nota: "prova \(i)")
            }
            let elenco = GestoreBackup.elenca(backup)
            guard elenco.count == GestoreBackup.massimo else {
                print("ERRORE: rotazione, attesi \(GestoreBackup.massimo) backup, trovati \(elenco.count)")
                return 1
            }

            // Ripristino: i dati e i documenti tornano identici
            let estratto = try GestoreBackup.estrai(elenco[0].url)
            guard estratto.dati == originale else {
                print("ERRORE: i dati estratti non coincidono con l'originale")
                return 1
            }
            try GestoreBackup.sostituisci(cartellaDati: destinazione, con: estratto.cartella)
            let documento = try String(contentsOf: destinazione.appendingPathComponent("Documenti/prova.txt"), encoding: .utf8)
            guard documento == "documento di prova",
                  fm.fileExists(atPath: destinazione.appendingPathComponent("archivio.json").path) else {
                print("ERRORE: dopo il ripristino mancano dei file")
                return 1
            }

            // Un archivio della versione 1 (senza anagrafica estesa, con appuntamenti e attività
            // senza i campi della versione 4) si legge ancora
            let vecchio = """
            {"versione":1,"clienteAttivoId":"a",
             "appuntamenti":[{"id":"e","clienteId":"a","titolo":"Incontro","inizio":"2026-01-02T09:00:00Z",
                              "durataMinuti":45,"luogo":"In studio","note":"","stato":"pianificato"}],
             "attivita":[{"id":"t","clienteId":"a","titolo":"Telefonare","scadenza":"2026-01-03T00:00:00Z",
                          "priorita":"alta","completata":false}],
             "impostazioni":{"nomeUtente":"Dennis","inizialiUtente":"DV","backup":{"automatico":true}},
             "clienti":[{"id":"a","nome":"Cliente Vecchio","iniziali":"CV","tinta":"blu","tema":"","email":"",
                         "telefono":"","preferito":false,"nota":"","creatoIl":"2026-01-01T00:00:00Z"}]}
            """
            let letto = try Archivio.decodifica(Data(vecchio.utf8))
            guard letto.clienti.first?.famiglia.isEmpty == true, letto.clienti.first?.canali.isEmpty == true,
                  letto.appuntamenti.first?.tipo == .altro, letto.appuntamenti.first?.canale == nil,
                  letto.attivita.first?.note == "", letto.attivita.first?.appuntamentoId == nil else {
                print("ERRORE: archivio della versione 1 non letto correttamente")
                return 1
            }

            // Un file che non è un backup di Prisma viene rifiutato
            let estraneo = radice.appendingPathComponent("estraneo.zip")
            try Data("non sono uno zip".utf8).write(to: estraneo)
            if (try? GestoreBackup.estrai(estraneo)) != nil {
                print("ERRORE: un file non valido è stato accettato come backup")
                return 1
            }
            print("OK: backup, rotazione (\(elenco.count) copie) e ripristino verificati")
            return 0
        } catch {
            print("ERRORE: \(error.localizedDescription)")
            return 1
        }
    }
}
