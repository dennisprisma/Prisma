import Foundation

/// Controlli dei promemoria del Mac (dentro `Prisma --prova-carico`): date e testi di
/// `MotoreNotifiche.promemoria` e andata e ritorno di `DestinazioneRicerca.testo`.
/// Calcolo puro: non tocca mai il Centro notifiche di macOS.
enum ProvaPromemoria {
    static func verifiche() -> [(Bool, String)] {
        var esiti: [(Bool, String)] = []
        func controlla(_ ok: Bool, _ descrizione: String) {
            esiti.append((ok, "Promemoria: " + descrizione))
        }
        let cal = Calendar.current
        func data(_ giorno: Int, _ ora: Int, _ minuto: Int = 0) -> Date? {
            cal.date(from: DateComponents(year: 2026, month: 3, day: giorno, hour: ora, minute: minuto))
        }
        // Martedì 10 marzo 2026 alle 10:00 (lontano dal cambio dell'ora legale)
        guard let adesso = data(10, 10), let mezzogiorno = data(10, 12), let alle8 = data(10, 8),
              let fraDieciMinuti = data(10, 10, 10), let alle14 = data(10, 14), let domani = data(11, 15),
              let giovedi = data(12, 0), let scadenza = data(20, 0),
              let attesaAppuntamento = data(10, 11, 30), let attesaSpostato = data(10, 13, 30), let attesaUnaOra = data(10, 11),
              let attesaAttivita = data(12, 9), let attesaSette = data(13, 9), let attesaGiorno = data(20, 9),
              let attesaCompleanno = data(15, 9),
              let nascita = cal.date(from: DateComponents(year: 1980, month: 3, day: 15)) else {
            controlla(false, "date della prova")
            return esiti
        }

        var dati = DatiPrisma.demo()
        guard dati.clienti.count >= 2, dati.posizioni.count >= 2 else {
            controlla(false, "dati di prova")
            return esiti
        }
        let cliente = dati.clienti[0]
        dati.appuntamenti = [
            Appuntamento(id: "pa-futuro", clienteId: cliente.id, titolo: "Revisione", inizio: mezzogiorno, durataMinuti: 45,
                         luogo: "In studio", note: "", stato: .pianificato),
            Appuntamento(id: "pa-passato", clienteId: cliente.id, titolo: "Già fatto", inizio: alle8, durataMinuti: 45,
                         luogo: "", note: "", stato: .pianificato),
            Appuntamento(id: "pa-concluso", clienteId: cliente.id, titolo: "Concluso", inizio: domani, durataMinuti: 45,
                         luogo: "", note: "", stato: .concluso),
            Appuntamento(id: "pa-vicino", clienteId: cliente.id, titolo: "Troppo vicino", inizio: fraDieciMinuti, durataMinuti: 45,
                         luogo: "", note: "", stato: .pianificato)
        ]
        dati.attivita = [
            Attivita(id: "pt-aperta", clienteId: cliente.id, titolo: "Chiamare per la firma", scadenza: giovedi,
                     priorita: .alta, completata: false),
            Attivita(id: "pt-fatta", clienteId: cliente.id, titolo: "Già fatta", scadenza: giovedi,
                     priorita: .normale, completata: true),
            Attivita(id: "pt-oggi", clienteId: cliente.id, titolo: "Di oggi", scadenza: cal.startOfDay(for: adesso),
                     priorita: .normale, completata: false)
        ]
        var inEssere = dati.posizioni[0]
        inEssere.stato = .inEssere
        inEssere.scadenza = scadenza
        var proposta = dati.posizioni[1]
        proposta.stato = .proposta
        proposta.scadenza = scadenza
        dati.posizioni = [inEssere, proposta]
        for i in dati.clienti.indices { dati.clienti[i].dataNascita = nil }
        dati.clienti[0].dataNascita = nascita

        let scelte = ImpostazioniPromemoria()
        let voci = MotoreNotifiche.promemoria(dati, impostazioni: scelte, adesso: adesso, cal: cal)
        let agenda = voci.filter { $0.gruppo == "agenda" }
        let attivita = voci.filter { $0.gruppo == "attivita" }
        let scadenze = voci.filter { $0.gruppo == "posizioni" }
        let compleanni = voci.filter { $0.gruppo == "clienti" }

        controlla(agenda.count == 1 && agenda.first?.data == attesaAppuntamento
                    && agenda.first?.id.hasPrefix("prisma-appuntamento-pa-futuro-") == true
                    && agenda.first?.destinazione == .appuntamento("pa-futuro"),
                  "appuntamento delle 12:00 alle 11:30; nessuno per quelli passati, conclusi o troppo vicini")
        controlla(agenda.first?.titolo == "Alle 12:00 · Revisione"
                    && agenda.first?.corpo == "Tra 30 minuti · \(cliente.nome) · In studio",
                  "testo dell'appuntamento: ora, titolo, cliente e luogo")
        controlla(attivita.count == 1 && attivita.first?.data == attesaAttivita
                    && attivita.first?.destinazione == .attivita("pt-aperta")
                    && attivita.first?.corpo == "\(cliente.nome) · da fare oggi · priorità alta",
                  "attività alle 9:00 del giorno di scadenza; nessuna per quelle completate o di stamattina")
        controlla(scadenze.map(\.data) == [attesaSette, attesaGiorno]
                    && scadenze.allSatisfy { $0.destinazione == .posizione(inEssere.id) }
                    && scadenze.first?.titolo.hasSuffix("scade tra 7 giorni") == true
                    && scadenze.last?.titolo.hasSuffix("scade oggi") == true
                    && scadenze.allSatisfy { $0.corpo.contains(inEssere.canale.nomeBreve) },
                  "posizione che scade tra 10 giorni: a 7 giorni e il giorno stesso, con il canale; niente per le proposte")
        controlla(compleanni.count == 1 && compleanni.first?.data == attesaCompleanno
                    && compleanni.first?.titolo == "Oggi \(cliente.nome) compie 46 anni"
                    && compleanni.first?.destinazione == .cliente(cliente.id),
                  "compleanno alle 9:00 del giorno")
        controlla(voci.allSatisfy { $0.data > adesso && $0.id.hasPrefix(MotoreNotifiche.prefissoPromemoria) }
                    && zip(voci, voci.dropFirst()).allSatisfy { $0.data <= $1.data }
                    && Set(voci.map(\.id)).count == voci.count,
                  "solo futuri, dal più vicino, identificativi «prisma-» unici")
        controlla(!voci.contains { ($0.titolo + " " + $0.corpo).contains("€") },
                  "nessuna cifra in euro nei testi")

        // L'appuntamento spostato cambia identificativo (l'aggiornamento toglie il vecchio)
        var spostato = dati
        spostato.appuntamenti[0].inizio = alle14
        let dopo = MotoreNotifiche.promemoria(spostato, impostazioni: scelte, adesso: adesso, cal: cal).first { $0.gruppo == "agenda" }
        controlla(dopo != nil && dopo?.id != agenda.first?.id && dopo?.data == attesaSpostato,
                  "appuntamento spostato: nuovo orario e nuovo identificativo")

        // Un'ora di anticipo
        var unOra = scelte
        unOra.anticipoMinuti = 60
        let presto = MotoreNotifiche.promemoria(dati, impostazioni: unOra, adesso: adesso, cal: cal).first { $0.gruppo == "agenda" }
        controlla(presto?.data == attesaUnaOra && presto?.corpo.hasPrefix("Tra 1 ora") == true,
                  "anticipo di un'ora")

        // Senza nomi dei clienti: stessi promemoria, nessun nome
        var anonimi = scelte
        anonimi.nomiClienti = false
        let senzaNomi = MotoreNotifiche.promemoria(dati, impostazioni: anonimi, adesso: adesso, cal: cal)
        controlla(senzaNomi.map(\.id) == voci.map(\.id)
                    && !senzaNomi.contains { ($0.titolo + " " + $0.corpo).contains(cliente.nome) },
                  "con «Nomi dei clienti» spento il nome non compare")

        // Solo i tipi scelti
        var soloCompleanni = scelte
        soloCompleanni.appuntamenti = false
        soloCompleanni.attivita = false
        soloCompleanni.scadenze = false
        soloCompleanni.occasioni = false
        let solo = MotoreNotifiche.promemoria(dati, impostazioni: soloCompleanni, adesso: adesso, cal: cal)
        controlla(solo.count == 1 && solo.first?.gruppo == "clienti", "solo i tipi di promemoria accesi")

        // Al massimo 50, i più vicini
        var molti = dati
        molti.appuntamenti = (0..<80).map { i in
            Appuntamento(id: "pm-\(i)", clienteId: cliente.id, titolo: "Incontro \(i)",
                         inizio: mezzogiorno.addingTimeInterval(TimeInterval(i) * 3600), durataMinuti: 30,
                         luogo: "", note: "", stato: .pianificato)
        }
        let tanti = MotoreNotifiche.promemoria(molti, impostazioni: scelte, adesso: adesso, cal: cal)
        controlla(tanti.count == MotoreNotifiche.massimoPromemoria && tanti.first?.data == attesaAppuntamento
                    && zip(tanti, tanti.dropFirst()).allSatisfy { $0.data <= $1.data },
                  "al massimo \(MotoreNotifiche.massimoPromemoria) promemoria, i più vicini")

        // Le impostazioni di un archivio di prima (senza promemoria) si leggono: spenti, 30 minuti
        let vecchie = try? JSONDecoder().decode(Impostazioni.self, from: Data(#"{"nomeUtente":"Denis"}"#.utf8))
        let strane = try? JSONDecoder().decode(ImpostazioniPromemoria.self, from: Data(#"{"attivi":true,"anticipoMinuti":7,"nomiClienti":"sì"}"#.utf8))
        controlla(vecchie?.promemoria == ImpostazioniPromemoria()
                    && strane?.attivi == true && strane?.anticipoMinuti == 30 && strane?.nomiClienti == true,
                  "impostazioni lette con tolleranza")

        // La destinazione del clic va e torna dal testo del promemoria
        let destinazioni: [DestinazioneRicerca] = [.app(.agenda), .cliente("c:1"), .posizione("p"), .documento("d"), .nota("n"),
                                                   .appuntamento("a"), .attivita("t"), .obiettivo("o"), .incontro("i"), .prodotto("x")]
        controlla(destinazioni.allSatisfy { DestinazioneRicerca(testo: $0.testo) == $0 }
                    && DestinazioneRicerca(testo: "boh") == nil && DestinazioneRicerca(testo: "app:inesistente") == nil,
                  "destinazione del clic in testo e ritorno")
        return esiti
    }
}
