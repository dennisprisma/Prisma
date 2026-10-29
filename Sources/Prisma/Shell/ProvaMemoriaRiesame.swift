import Foundation

/// Controlli del riesame con memoria che hanno bisogno di `StatoShell` (dentro `Prisma --prova-carico`, specifica 12
/// §8.3, SM1–SM13): fotografia salvata a mano, variazioni dopo un cambio di profilo, ordine del giorno, prospetto,
/// fotografie dalla chiusura di un incontro e da un appuntamento di revisione, eliminazione, cache e tempi. Tutto
/// relativo a `Date()`: riproducibile a qualunque ora del server. Il prefisso «Memoria del riesame: » è già dentro.
@MainActor
enum ProvaMemoriaRiesame {
    /// Tempo massimo della memoria di un cliente con i clienti fittizi caricati (sopra si stampa solo un INFO).
    static let limiteMemoria = 0.2

    static func verifiche() -> [(Bool, String)] {
        var esiti: [(Bool, String)] = []
        func controlla(_ ok: Bool, _ descrizione: String) {
            esiti.append((ok, "Memoria del riesame: " + descrizione))
        }
        let cal = Calendar.current
        let oggi = Date()
        let fa200 = cal.date(byAdding: .day, value: -200, to: oggi) ?? oggi
        func di(_ s: StatoShell, _ id: String) -> [FotografiaRiesame] { s.fotografieCliente(id) }

        let s = StatoShell(persistente: false)

        // SM1 I dati di prova non hanno fotografie: primo riesame
        controlla(s.dati.fotografie.isEmpty, "SM1 nessuna fotografia nei dati di prova")
        controlla(s.memoriaRiesame("giulia")?.primoRiesame == true, "SM1 Giulia al primo riesame")

        // SM2 Una fotografia di 200 giorni fa, con le cifre di adesso
        let prima = s.fotografaRiesame("giulia", origine: .manuale, oggi: fa200, avviso: false)
        controlla(di(s, "giulia").count == 1 && prima != nil, "SM2 una fotografia di Giulia")
        let alleanza = RiepilogoPosizioni(s.posizioniCliente("giulia")).perCanale[.alleanza] ?? 0
        controlla(prima?.patrimonioAlleanza == alleanza, "SM2 patrimonio Alleanza come nel riepilogo delle posizioni")
        controlla(prima?.propensione == s.cliente("giulia")?.profilo.propensione?.rawValue, "SM2 propensione del profilo")
        controlla(prima.map { cal.isDate($0.data, inSameDayAs: fa200) } == true, "SM2 fotografia datata 200 giorni fa")

        // SM3 Cambia la propensione: la memoria la confronta con la fotografia di 200 giorni fa
        if var c = s.cliente("giulia") {
            c.profilo.propensione = c.profilo.propensione == .moderata ? .prudente : .moderata
            s.salvaCliente(c)
        }
        let m3 = s.memoriaRiesame("giulia")
        controlla(m3?.precedente?.id == prima?.id && prima != nil, "SM3 la precedente è la fotografia di 200 giorni fa")
        controlla(m3?.variazioni.contains { $0.chiave == "profilo.propensione" } == true, "SM3 tra le variazioni c'è la propensione")

        // SM4 L'ordine del giorno del riesame si apre con le variazioni
        if let a = s.bozzaRiesame("giulia") {
            controlla(a.note.hasPrefix("Ordine del giorno:\nCosa è cambiato dal riesame del ") && a.note.contains("• Propensione da "),
                      "SM4 le note del riesame si aprono con le variazioni")
            controlla(a.tipo == TipoAppuntamento.revisione && a.durataMinuti == 60, "SM4 revisione periodica di 60 minuti")
        } else {
            controlla(false, "SM4 nessuna bozza del riesame di Giulia")
        }

        // SM5 Il prospetto del riesame: variazioni in testa e cronologia
        s.clienteAttivoId = "giulia"
        let contenuto = s.contenutoProspetto(.riesame)
        let blocchi = contenuto?.blocchi ?? []
        let conTesto = blocchi.contains { b in
            if case .testo(let t) = b { return t.hasPrefix("Cosa è cambiato dal riesame del") }
            return false
        }
        let conCronologia = blocchi.contains { b in
            if case .sezione(_, let t) = b { return t == TestiMemoria.titoloCronologia }
            return false
        }
        controlla(conTesto, "SM5 il prospetto comincia l'ordine del giorno con «Cosa è cambiato dal riesame del…»")
        controlla(conCronologia, "SM5 il prospetto ha la sezione «Cronologia dei riesami»")
        controlla(contenuto?.titolo.hasPrefix("Riesame annuale di") == true, "SM5 il titolo del prospetto non cambia")

        // SM6 Due uscite del prospetto oggi: una sola fotografia di oggi
        s.fotografaRiesame("giulia", origine: .prospetto)
        s.fotografaRiesame("giulia", origine: .prospetto)
        let giulia = di(s, "giulia")
        controlla(giulia.count == 2, "SM6 Giulia ha 2 fotografie (\(giulia.count))")
        controlla(giulia.first?.origini == ["prospetto"] && giulia.first.map { cal.isDateInToday($0.data) } == true,
                  "SM6 la fotografia di oggi viene dal prospetto")

        // SM7 Un incontro di revisione concluso fotografa
        var revisione = Appuntamento.nuovo(clienteId: "marco", giorno: oggi)
        revisione.inizio = oggi.addingTimeInterval(-3_600)
        revisione.titolo = "Revisione delle posizioni"
        revisione.tipo = .revisione
        s.salvaAppuntamento(revisione)
        let incontro = Incontro(clienteId: "marco", titolo: "Incontro di oggi", data: revisione.inizio, appuntamentoId: revisione.id)
        s.salvaIncontro(incontro)
        s.chiudiIncontro(incontro.id)
        let marco = di(s, "marco")
        controlla(marco.count == 1 && marco.first?.origini == ["incontro"], "SM7 l'incontro concluso fotografa Marco")

        // SM8 Un appuntamento di revisione passato segnato concluso fotografa; una telefonata o un riesame futuro no
        var ieri = Appuntamento.nuovo(clienteId: "sofia", giorno: oggi)
        ieri.inizio = cal.date(byAdding: .day, value: -1, to: oggi) ?? oggi
        ieri.titolo = "Revisione periodica"
        ieri.tipo = .revisione
        s.salvaAppuntamento(ieri)
        s.alternaConcluso(ieri.id)
        let sofia = di(s, "sofia")
        controlla(sofia.count == 1 && sofia.first?.origini == ["appuntamento"], "SM8 l'appuntamento di revisione concluso fotografa Sofia")
        var telefonata = Appuntamento.nuovo(clienteId: "laura", giorno: oggi)
        telefonata.inizio = cal.date(byAdding: .day, value: -1, to: oggi) ?? oggi
        telefonata.tipo = .telefonata
        s.salvaAppuntamento(telefonata)
        s.alternaConcluso(telefonata.id)
        var futuro = Appuntamento.nuovo(clienteId: "laura", giorno: oggi)
        futuro.inizio = cal.date(byAdding: .day, value: 3, to: oggi) ?? oggi
        futuro.tipo = .revisione
        s.salvaAppuntamento(futuro)
        s.alternaConcluso(futuro.id)
        controlla(di(s, "laura").isEmpty, "SM8 né una telefonata né un riesame futuro fotografano Laura")

        // SM9 Che cosa è un incontro di riesame
        controlla(s.incontroDiRiesame(Incontro(clienteId: "laura", titolo: "Riesame annuale", data: oggi)),
                  "SM9 «Riesame annuale» è un incontro di riesame")
        controlla(!s.incontroDiRiesame(Incontro(clienteId: "laura", titolo: "Primo incontro", data: oggi)),
                  "SM9 «Primo incontro» non lo è")

        // SM10 Le fotografie se ne vanno con il cliente
        s.eliminaCliente("marco")
        controlla(di(s, "marco").isEmpty, "SM10 eliminato Marco, nessuna sua fotografia")

        // SM11 «Togli i dati di prova» toglie anche le fotografie (i clienti con fotografie sono tutti di prova)
        s.rimuoviDatiDiProva()
        controlla(s.dati.fotografie.isEmpty, "SM11 tolti i dati di prova, nessuna fotografia")

        // SM12 La memoria in cache si rifà dopo una fotografia nuova
        do {
            let t = StatoShell(persistente: false)
            let primaVolta = t.memoriaRiesame("giulia")?.cronologia.count
            t.fotografaRiesame("giulia", origine: .manuale, avviso: false)
            let dopo = t.memoriaRiesame("giulia")?.cronologia.count
            controlla(primaVolta == 0 && dopo == 1, "SM12 dopo una fotografia la memoria in cache ha la cronologia nuova")
        }

        // SM13 Tempi con i clienti fittizi caricati
        do {
            let t = StatoShell(persistente: false)
            t.dati = ClientiFittizi.completi()
            if let id = t.clienti.first?.id {
                let inizio = Date()
                let memoria = t.memoriaRiesame(id)
                let secondi = Date().timeIntervalSince(inizio)
                let testo = String(format: "%.3f s", secondi)
                print("INFO Memoria del riesame: \(t.dati.clienti.count) clienti, memoria del primo in \(testo)")
                if secondi >= limiteMemoria {
                    print("INFO Memoria del riesame: sopra il limite di \(String(format: "%.1f s", limiteMemoria))")
                }
                controlla(memoria != nil, "SM13 memoria del primo cliente fittizio calcolata")
            } else {
                controlla(false, "SM13 clienti fittizi caricati")
            }
        }
        return esiti
    }
}
