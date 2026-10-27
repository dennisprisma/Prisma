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
                  letto.clienti.first?.bisogni == ProfiloBisogni(), letto.incontri.isEmpty, letto.prodotti.isEmpty, letto.obiettivi.isEmpty, letto.documenti.isEmpty, letto.valutazioni.isEmpty, letto.commenti.isEmpty, letto.spazi.isEmpty, letto.note.isEmpty,
                  letto.impostazioni.eve == ImpostazioniEve(), letto.impostazioni.nomeUtente == "Denis",
                  letto.impostazioni.aspetto == .automatico, letto.impostazioni.sfondoAnimato,
                  letto.impostazioni.pioggia == .leggera else {
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

            // Backup protetti da password (la prova non usa mai il Portachiavi: la password si passa qui)
            if let errore = try provaProtetti(radice: radice, dati: dati, originale: originale) {
                print("ERRORE: \(errore)")
                return 1
            }
            print("OK: backup, rotazione (\(elenco.count) copie), ripristino e backup protetti da password verificati")
            return 0
        } catch {
            print("ERRORE: \(error.localizedDescription)")
            return 1
        }
    }

    /// Backup protetti: cifrati (niente in chiaro, nemmeno i nomi dei file), chiusi senza la password
    /// giusta, rifiutati se alterati, troncati o riordinati, a più segmenti; rotazione insieme ai .zip
    /// in chiaro, che si ripristinano come prima. Restituisce il motivo dell'errore (nil = tutto bene).
    private static func provaProtetti(radice: URL, dati: URL, originale: DatiPrisma) throws -> String? {
        let fm = FileManager.default
        let password = "prova-segreta-àè"
        // Un documento più grande di due segmenti (byte pseudocasuali: lo zip non li comprime)
        var grande = [UInt8](repeating: 0, count: CifraturaBackup.dimensioneSegmento * 5 / 2)
        var x: UInt64 = 0x9E37_79B9_7F4A_7C15
        for i in grande.indices {
            x ^= x << 13
            x ^= x >> 7
            x ^= x << 17
            grande[i] = UInt8(truncatingIfNeeded: x)
        }
        let fileGrande = dati.appendingPathComponent("Documenti/grande.bin")
        try Data(grande).write(to: fileGrande)
        defer { try? fm.removeItem(at: fileGrande) }

        // Con le iterazioni dell'app: cifrato, nessun file in chiaro lasciato in giro
        let protetti = radice.appendingPathComponent("BackupProtetti", isDirectory: true)
        try fm.createDirectory(at: protetti, withIntermediateDirectories: true)
        // Una copia parziale rimasta da un backup protetto interrotto si cancella
        try Data("resto".utf8).write(to: protetti.appendingPathComponent(GestoreBackup.prefisso + "interrotto.zip.cifrato.parziale"))
        let primaTemporanei = temporaneiInChiaro()
        let cifrato = try GestoreBackup.crea(sorgente: dati, destinazione: protetti, password: password)
        let contenuto = try Data(contentsOf: cifrato)
        let nomi = (try? fm.contentsOfDirectory(atPath: protetti.path)) ?? []
        guard cifrato.lastPathComponent.hasSuffix(".zip." + GestoreBackup.estensioneCifrata), CifraturaBackup.cifrato(cifrato),
              CifraturaBackup.iterazioni(in: cifrato) == CifraturaBackup.iterazioniPredefinite,
              contenuto.range(of: Data("archivio.json".utf8)) == nil, contenuto.range(of: Data("prova.txt".utf8)) == nil,
              nomi == [cifrato.lastPathComponent], temporaneiInChiaro() == primaTemporanei else {
            return "il backup protetto non è cifrato o ha lasciato file in chiaro (\(nomi))"
        }
        let voci = GestoreBackup.elenca(protetti)
        guard voci.count == 1, voci[0].cifrato, !voci[0].nome.hasSuffix(".zip"), !voci[0].nome.hasSuffix(".cifrato") else {
            return "elenco dei backup protetti (\(voci.map(\.nome)))"
        }
        // Senza password e con la password sbagliata non si apre
        do {
            _ = try GestoreBackup.estrai(cifrato)
            return "un backup protetto si è aperto senza password"
        } catch ErroreBackup.serveLaPassword {}
        do {
            _ = try GestoreBackup.estrai(cifrato, password: "sbagliata")
            return "un backup protetto si è aperto con la password sbagliata"
        } catch ErroreBackup.passwordErrata {}
        // Con la password giusta torna identico, documenti compresi
        let aperto = try GestoreBackup.estrai(cifrato, password: password)
        defer { GestoreBackup.pulisciEstrazione(aperto.cartella) }
        let grandeRiletto = try Data(contentsOf: aperto.cartella.appendingPathComponent("Documenti/grande.bin"))
        let documento = try String(contentsOf: aperto.cartella.appendingPathComponent("Documenti/prova.txt"), encoding: .utf8)
        guard aperto.dati == originale, grandeRiletto == Data(grande), documento == "documento di prova",
              temporaneiInChiaro() == primaTemporanei else {
            return "il backup protetto non torna identico o lascia lo zip decifrato nella cartella temporanea"
        }
        // Riconosciuto dal contenuto, non dall'estensione: rinominato in .zip chiede ancora la password
        let rinominato = radice.appendingPathComponent("rinominato.zip")
        try fm.copyItem(at: cifrato, to: rinominato)
        do {
            _ = try GestoreBackup.estrai(rinominato)
            return "un backup protetto rinominato in .zip si è aperto senza password"
        } catch ErroreBackup.serveLaPassword {}
        // Una password vuota non protegge niente: niente backup
        do {
            try GestoreBackup.crea(sorgente: dati, destinazione: radice.appendingPathComponent("PasswordVuota"), password: "")
            return "backup creato con una password vuota"
        } catch ErroreBackup.passwordNonDisponibile {}

        // Le prove sui file rovinati con poche iterazioni (solo qui, per la durata)
        let veloci = radice.appendingPathComponent("BackupProtettiVeloci", isDirectory: true)
        let veloce = try GestoreBackup.crea(sorgente: dati, destinazione: veloci, password: password, iterazioni: 1_000)
        // La stessa password scritta con gli accenti scomposti apre lo stesso backup
        let scomposta = try GestoreBackup.estrai(veloce, password: password.decomposedStringWithCanonicalMapping)
        GestoreBackup.pulisciEstrazione(scomposta.cartella)
        let intero = try [UInt8](Data(contentsOf: veloce))
        let pezzi = segmenti(intero)
        guard pezzi.count >= 3, pezzi.last?.upperBound == intero.count else {
            return "attesi almeno 3 segmenti, trovati \(pezzi.count)"
        }
        let rovinati = radice.appendingPathComponent("Rovinati", isDirectory: true)
        try fm.createDirectory(at: rovinati, withIntermediateDirectories: true)
        let intestazione = Array(intero[0..<CifraturaBackup.lunghezzaIntestazione])
        var alterato = intero
        alterato[pezzi[1].lowerBound + 100] ^= 0xFF
        let troncatoAlConfine = Array(intero[0..<pezzi[pezzi.count - 1].lowerBound])
        let troncato = Array(intero.dropLast(100))
        var riordinato = intestazione
        riordinato.append(contentsOf: intero[pezzi[1]])
        riordinato.append(contentsOf: intero[pezzi[0]])
        riordinato.append(contentsOf: intero[pezzi[1].upperBound...])
        var allungato = intero
        allungato.append(contentsOf: intero[pezzi[pezzi.count - 1]])
        let casi: [(String, [UInt8])] = [("un byte alterato", alterato), ("troncato tra due segmenti", troncatoAlConfine),
                                         ("troncato a metà", troncato), ("con i segmenti riordinati", riordinato),
                                         ("con un segmento in più", allungato)]
        for (i, caso) in casi.enumerated() {
            guard rifiutato(Data(caso.1), rovinati.appendingPathComponent("rovinato \(i).zip.cifrato"), password: password,
                            atteso: { errore in
                                if case .backupDanneggiato = errore { return true }
                                return false
                            }) else {
                return "accettato un backup protetto \(caso.0)"
            }
        }
        // Un'intestazione toccata (il sale) non apre più niente
        var saleToccato = intero
        saleToccato[20] ^= 0x01
        guard rifiutato(Data(saleToccato), rovinati.appendingPathComponent("sale.zip.cifrato"), password: password, atteso: { _ in true }) else {
            return "accettato un backup protetto con l'intestazione alterata"
        }
        guard temporaneiInChiaro() == primaTemporanei else { return "i backup rovinati lasciano zip decifrati nella cartella temporanea" }

        // Rotazione: .zip e .zip.cifrato si contano insieme; l'automatico protetto si riconosce
        let misti = radice.appendingPathComponent("BackupMisti", isDirectory: true)
        for i in 0..<10 {
            try GestoreBackup.crea(sorgente: dati, destinazione: misti, nota: "misto \(i)",
                                   password: i.isMultiple(of: 2) ? password : nil, iterazioni: 1_000)
        }
        try GestoreBackup.crea(sorgente: dati, destinazione: misti, nota: GestoreBackup.notaAutomatico, password: password, iterazioni: 1_000)
        let elencoMisto = GestoreBackup.elenca(misti)
        let automatici = elencoMisto.filter(GestoreBackup.automatico)
        let fileMisti = (try? fm.contentsOfDirectory(atPath: misti.path)) ?? []
        let vecchi = elencoMisto.filter { $0.nome.hasSuffix("(misto 0)") || $0.nome.hasSuffix("(misto 1)") }
        guard elencoMisto.count == GestoreBackup.massimo + 1, fileMisti.count == elencoMisto.count,
              automatici.count == 1, automatici.first?.cifrato == true,
              elencoMisto.contains(where: { $0.cifrato }), elencoMisto.contains(where: { !$0.cifrato }), vecchi.isEmpty else {
            return "rotazione mista di backup in chiaro e protetti (\(fileMisti.sorted()))"
        }
        // Un vecchio .zip in chiaro si ripristina come prima, anche se c'è una password
        guard let inChiaro = elencoMisto.first(where: { !$0.cifrato }) else { return "manca il backup in chiaro" }
        let daChiaro = try GestoreBackup.estrai(inChiaro.url, password: password)
        GestoreBackup.pulisciEstrazione(daChiaro.cartella)
        guard daChiaro.dati == originale else { return "un backup in chiaro non torna identico" }

        // L'impostazione «protetto» si legge con tolleranza: gli archivi di prima non l'hanno
        let senzaCampo = try Archivio.decodificatore.decode(ImpostazioniBackup.self, from: Data(#"{"automatico":true}"#.utf8))
        let conCampo = try Archivio.decodificatore.decode(ImpostazioniBackup.self, from: Data(#"{"automatico":true,"protetto":true}"#.utf8))
        let riletta = try Archivio.decodificatore.decode(ImpostazioniBackup.self, from: Archivio.codificatore.encode(conCampo))
        guard !senzaCampo.cifrato, conCampo.cifrato, riletta == conCampo else {
            return "impostazione della protezione dei backup non letta o non salvata"
        }
        return nil
    }

    /// I file dello zip in chiaro o decifrato che Prisma crea nella cartella temporanea.
    private static func temporaneiInChiaro() -> Set<String> {
        let fm = FileManager.default
        let nomi = (try? fm.contentsOfDirectory(atPath: fm.temporaryDirectory.path)) ?? []
        return Set(nomi.filter { $0.hasPrefix("Prisma-chiaro-") || $0.hasPrefix("Prisma-decifrato-") })
    }

    /// Dove stanno i segmenti (lunghezza compresa) di un backup protetto.
    private static func segmenti(_ file: [UInt8]) -> [Range<Int>] {
        var inizio = CifraturaBackup.lunghezzaIntestazione
        var pezzi: [Range<Int>] = []
        while inizio + 4 <= file.count {
            let lunghezza = Int(CifraturaBackup.numero(file[inizio..<inizio + 4]))
            let fine = inizio + 4 + lunghezza
            guard fine <= file.count else { break }
            pezzi.append(inizio..<fine)
            inizio = fine
        }
        return pezzi
    }

    /// true se il backup protetto `contenuto` viene rifiutato con l'errore atteso.
    private static func rifiutato(_ contenuto: Data, _ url: URL, password: String, atteso: (ErroreBackup) -> Bool) -> Bool {
        do {
            try contenuto.write(to: url)
            let aperto = try GestoreBackup.estrai(url, password: password)
            GestoreBackup.pulisciEstrazione(aperto.cartella)
            return false
        } catch let errore as ErroreBackup {
            return atteso(errore)
        } catch {
            return false
        }
    }
}
