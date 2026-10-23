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
            var originale = DatiPrisma.demo()
            // Anche un'Analisi 360 salvata deve tornare identica
            var analisi = Analisi360(cliente: originale.clienti.first, posizioni: originale.posizioni)
            analisi.confermate = [.protezione]
            analisi.aggiornataIl = Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down))
            originale.analisi[originale.clienti.first?.id ?? ""] = analisi
            // E una conversazione con Eve, con le sue impostazioni
            originale.conversazioni[originale.clienti.first?.id ?? ""] = [
                MessaggioEve(autore: .utente, testo: "Fammi un riepilogo del cliente"),
                MessaggioEve(autore: .eve, testo: "Il quadro…", titolo: "Il quadro", motore: "Sintesi dai dati"),
            ]
            originale.impostazioni.eve.motore = .sintesi
            // E il commento del consulente in un report
            originale.commenti = [CommentoReport(id: "checkUp·giulia", clienteId: "giulia", testo: "Gentile Giulia, …", bozzaDi: "Sintesi dai dati",
                                                 aggiornatoIl: Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down)))]
            // E uno spazio di lavoro salvato
            originale.spazi = [SpazioLavoro(nome: "Revisione annuale", finestre: [.sinistra(.posizioni), .destra(.eve)])]
            guard !originale.simulazioni.isEmpty, !originale.incontri.isEmpty, !originale.prodotti.isEmpty, !originale.obiettivi.isEmpty, !originale.documenti.isEmpty, !originale.valutazioni.isEmpty, originale.clienti.contains(where: { !$0.bisogni.eventi.isEmpty }) else {
                print("ERRORE: i dati di prova non hanno scenari del simulatore")
                return 1
            }
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

            // Le copie automatiche hanno la loro rotazione: non le consumano i backup fatti a mano
            // (una sola copia: due backup nello stesso secondo hanno lo stesso nome)
            try GestoreBackup.crea(sorgente: dati, destinazione: backup, nota: GestoreBackup.notaAutomatico)
            let conAutomatici = GestoreBackup.elenca(backup)
            guard conAutomatici.filter(GestoreBackup.automatico).count == 1, conAutomatici.count == GestoreBackup.massimo + 1 else {
                print("ERRORE: rotazione separata dei backup automatici (\(conAutomatici.count) copie)")
                return 1
            }
            // Una cartella scelta dall'utente che non c'è (disco scollegato) non si ricrea sul Mac
            let scollegata = radice.appendingPathComponent("DiscoEsterno/Backup", isDirectory: true)
            do {
                try GestoreBackup.crea(sorgente: dati, destinazione: scollegata, creaCartella: false)
                print("ERRORE: backup creato in una cartella che non esisteva")
                return 1
            } catch ErroreBackup.cartellaNonRaggiungibile {
                guard !fm.fileExists(atPath: scollegata.path) else {
                    print("ERRORE: la cartella scollegata è stata ricreata")
                    return 1
                }
            }
            // Un numero non finito non blocca il salvataggio
            var conNaN = originale
            if !conNaN.posizioni.isEmpty { conNaN.posizioni[0].costoAnnuo = .nan }
            guard (try? Archivio.decodifica(Archivio.codificatore.encode(conNaN))) != nil else {
                print("ERRORE: un numero non finito blocca il salvataggio")
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
                  letto.attivita.first?.note == "", letto.attivita.first?.appuntamentoId == nil,
                  letto.simulazioni.isEmpty, letto.analisi.isEmpty, letto.conversazioni.isEmpty,
                  letto.clienti.first?.bisogni == ProfiloBisogni(), letto.incontri.isEmpty, letto.prodotti.isEmpty, letto.obiettivi.isEmpty, letto.documenti.isEmpty, letto.valutazioni.isEmpty, letto.commenti.isEmpty, letto.spazi.isEmpty,
                  letto.impostazioni.eve == ImpostazioniEve(), letto.impostazioni.nomeUtente == "Denis" else {
                print("ERRORE: archivio della versione 1 non letto correttamente")
                return 1
            }

            // Un ripristino interrotto (Mac spento tra i due spostamenti) si recupera all'avvio
            let interrotto = radice.appendingPathComponent("Interrotto/Prisma", isDirectory: true)
            let (_, precedente) = GestoreBackup.cartelleRipristino(interrotto)
            try fm.createDirectory(at: precedente, withIntermediateDirectories: true)
            try Archivio.codificatore.encode(originale).write(to: precedente.appendingPathComponent("archivio.json"))
            guard GestoreBackup.recuperaRipristino(interrotto),
                  fm.fileExists(atPath: interrotto.appendingPathComponent("archivio.json").path),
                  !fm.fileExists(atPath: precedente.path) else {
                print("ERRORE: ripristino interrotto non recuperato")
                return 1
            }
            // Un backup di una versione più recente non si ripristina
            let recente = radice.appendingPathComponent("Recente/Prisma", isDirectory: true)
            try fm.createDirectory(at: recente, withIntermediateDirectories: true)
            var datiRecenti = originale
            datiRecenti.versione = DatiPrisma.versioneAttuale + 1
            try Archivio.codificatore.encode(datiRecenti).write(to: recente.appendingPathComponent("archivio.json"))
            let zipRecente = try GestoreBackup.crea(sorgente: recente, destinazione: radice.appendingPathComponent("BackupRecenti"))
            do {
                _ = try GestoreBackup.estrai(zipRecente)
                print("ERRORE: ripristinato un backup di una versione più recente")
                return 1
            } catch ErroreBackup.versionePiuRecente {}

            // Un archivio di una versione più recente si apre in sola lettura (salvarlo perderebbe dati)
            var futuro = originale
            futuro.versione = DatiPrisma.versioneAttuale + 1
            let rilettoFuturo = try Archivio.decodifica(Archivio.codificatore.encode(futuro))
            guard Archivio.diVersionePiuRecente(rilettoFuturo), !Archivio.diVersionePiuRecente(originale) else {
                print("ERRORE: archivio di una versione più recente non riconosciuto")
                return 1
            }

            // Togliere i clienti di prova lascia i clienti veri con i loro dati
            let stato = StatoShell(persistente: false)
            var vero = Cliente.nuovo(tinta: .blu)
            vero.nome = "Cliente Vero"
            stato.dati.clienti.append(vero)
            stato.dati.posizioni.append(Posizione(clienteId: vero.id, canale: .indipendente, stato: .inEssere, area: .liquidita, nome: "Conto"))
            stato.salvaCommento(.checkUp(report: true), testo: "Gentile Giulia, prova.")
            stato.rimuoviDatiDiProva()
            guard stato.dati.clienti.map(\.id) == [vero.id], stato.dati.posizioni.allSatisfy({ $0.clienteId == vero.id }), stato.dati.posizioni.count == 1,
                  stato.dati.commenti.isEmpty, stato.dati.conversazioni.isEmpty, stato.dati.documenti.isEmpty, stato.dati.obiettivi.isEmpty,
                  stato.dati.prodotti.isEmpty, stato.dati.clienteAttivoId == vero.id, !stato.haDatiDiProva else {
                print("ERRORE: togliendo i clienti di prova sono rimasti dati di prova o è sparito il cliente vero")
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
