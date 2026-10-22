import Foundation

/// Prova automatica di Eve (`Prisma --prova-eve`), eseguita dal workflow.
/// Controlla le istruzioni nel pacchetto, la scheda del cliente (entro la finestra del modello),
/// le risposte della sintesi dai dati e riporta la disponibilità del modello Apple sul server.
enum ProvaEve {
    static func esegui() -> Int32 {
        var errori = 0
        func controlla(_ ok: Bool, _ descrizione: String) {
            print("\(ok ? "OK   " : "ERRORE") \(descrizione)")
            if !ok { errori += 1 }
        }

        let istruzioni = IstruzioniEve.testo("chat")
        controlla(istruzioni != nil, "Istruzioni della chat nel pacchetto (\(IstruzioniEve.cartella)/chat.md)")
        controlla((istruzioni ?? "").contains("Alleanza"), "Le istruzioni distinguono i canali")

        let stato = StatoShell(persistente: false)
        for c in stato.clienti {
            guard let fonte = stato.fonteEve(c.id) else {
                controlla(false, "Fonte di \(c.nome)")
                continue
            }
            let scheda = ContestoEve.scheda(fonte)
            controlla(scheda.count <= ContestoEve.limite + 1, "Scheda di \(c.nome): \(scheda.count) caratteri (limite \(ContestoEve.limite))")
            controlla(scheda.contains(c.nome), "La scheda di \(c.nome) contiene il nome")
            for s in SpuntoEve.allCases {
                let r = MotoriEve.sintesi.componi(RichiestaEve(domanda: s.domanda, spunto: s, fonte: fonte, storia: []))
                if r.testo.isEmpty || r.titolo == nil {
                    controlla(false, "Sintesi «\(s.domanda)» per \(c.nome)")
                }
            }
        }
        // Una domanda scritta a mano uguale a uno spunto viene riconosciuta
        controlla(SpuntoEve.da("  fammi un riepilogo del cliente ") == .riepilogo, "Riconoscimento degli spunti scritti a mano")
        // La sintesi di Giulia riporta il patrimonio netto calcolato dal motore
        if let f = stato.fonteEve("giulia") {
            let r = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .riepilogo, fonte: f, storia: []))
            let netto = Formati.euro(RiepilogoPosizioni(f.posizioni).patrimonioNetto)
            controlla(r.testo.contains(netto), "Il riepilogo di Giulia riporta il patrimonio netto (\(netto))")
        }
        // Gli spunti di analisi riportano le stesse cifre dei motori dei documenti
        if let f = stato.fonteEve("marco") {
            let r = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .pensione, fonte: f, storia: []))
            if let pip = f.posizioni.first(where: { $0.stato == .inEssere && $0.regime == .previdenza }),
               let uscita = MotoreFiscale.calcola(pip, data: f.oggi).uscite.first(where: { $0.causa == .pensione }) {
                controlla(r.testo.contains(CifreDoc.euroCentesimi(uscita.netto)), "Pensione di Marco: netto al pensionamento al centesimo (\(CifreDoc.euroCentesimi(uscita.netto)))")
                controlla(r.testo.contains("Prima casa") && r.testo.contains("Riscatto altre cause"), "Pensione di Marco: aliquote causa per causa")
            } else {
                controlla(false, "Marco ha un piano previdenziale in essere")
            }
            let res = MotoreResoconto.calcola(f.posizioni, cliente: f.cliente.nome, prodotti: f.prodotti, data: f.oggi)
            let rr = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .resoconto, fonte: f, storia: []))
            controlla(res.finanziarie.isEmpty || rr.testo.contains(CifreDoc.euroCentesimi(res.nettoFinanziario)), "Resoconto di Marco: netto incassabile oggi uguale al documento")
            let cu = MotoreCheckUp.calcola(cliente: f.cliente, posizioni: f.posizioni, analisi: f.analisi, obiettivi: f.obiettivi)
            let rc = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .checkUp, fonte: f, storia: []))
            controlla(rc.testo.contains("\(cu.rossi.count) da affrontare") && cu.indicatori.allSatisfy { rc.testo.contains($0.titolo) },
                      "Check-up di Marco: semaforo e tutti gli indicatori")
        }
        // Le domande libere trovano l'argomento giusto (per la sintesi e per i calcoli passati al modello)
        let argomenti: [(String, SpuntoEve)] = [
            ("Quanto paga di tasse se chiede l'anticipazione del fondo pensione?", .pensione),
            ("Gli conviene cambiare polizza?", .cambiare),
            ("Come va il rendimento dei suoi investimenti?", .resoconto),
            ("Cosa facciamo con la liquidità sul conto?", .liquidita),
            ("È coperto in caso di invalidità?", .protezione)
        ]
        for (domanda, atteso) in argomenti {
            controlla(SpuntoEve.argomento(domanda) == atteso, "Argomento di «\(domanda)» → \(atteso.rawValue)")
        }
        // Ogni documento di analisi ha il suo spunto
        for scelta in [SceltaProspetto.resoconto(report: false), .previdenza(report: true), .protezione(report: false),
                       .liquidita(report: false), .checkUp(report: true), .obiettivo("", report: false), .sostituzione("", "", report: false)] {
            controlla(scelta.spuntoEve != nil, "Spunto di Eve per «\(scelta.tipo.nome)»")
        }
        // Le bozze passate al modello restano nello spazio previsto (avviso, non errore: si tagliano)
        for c in stato.clienti {
            guard let f = stato.fonteEve(c.id) else { continue }
            for s in SpuntoEve.allCases {
                let n = MotoriEve.sintesi.componi(RichiestaEve(domanda: s.domanda, spunto: s, fonte: f, storia: [])).testo.count
                if n > ContestoEve.limiteCalcoli { print("INFO Bozza «\(s.domanda)» per \(c.nome): \(n) caratteri, tagliata a \(ContestoEve.limiteCalcoli)") }
            }
        }
        // «Chiedi a Eve» da Prospetti e report apre Eve e risponde sul documento
        stato.dati.impostazioni.eve.motore = .sintesi
        stato.clienteAttivoId = "laura"
        stato.prospetto = .previdenza(report: false)
        stato.chiediEveDelDocumento(.previdenza(report: false))
        controlla(stato.conversazione("laura").last?.titolo == "La pensione di Laura Moretti",
                  "Chiedi a Eve dal piano previdenziale: risposta salvata")

        // La chat in modalità sintesi aggiunge domanda e risposta
        stato.dati.impostazioni.eve.motore = .sintesi
        stato.clienteAttivoId = "marco"
        stato.chiediEve(SpuntoEve.prossimiPassi.domanda, spunto: .prossimiPassi)
        controlla(stato.conversazione("marco").count == 2, "Conversazione: domanda e risposta salvate")

        print("INFO Modello Apple su questo Mac: \(MotoriEve.motivoAppleNonDisponibile ?? "disponibile")")
        if errori == 0 {
            print("OK: Eve verificata")
            return 0
        }
        print("ERRORE: \(errori) verifiche di Eve non riuscite")
        return 1
    }
}
