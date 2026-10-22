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

        // Il commento dei report: bozza per ogni documento di analisi e cliente, nei limiti, con le cifre del report
        controlla(IstruzioniEve.testo("commento") != nil, "Istruzioni del commento nel pacchetto (\(IstruzioniEve.cartella)/commento.md)")
        for c in stato.clienti {
            stato.clienteAttivoId = c.id
            for scelta in [SceltaProspetto.checkUp(report: true), .resoconto(report: true), .previdenza(report: true),
                           .protezione(report: true), .liquidita(report: true)] {
                guard let b = stato.bozzaCommento(scelta) else {
                    controlla(false, "Bozza del commento «\(scelta.tipo.nome)» per \(c.nome)")
                    continue
                }
                if !b.hasPrefix("Gentile ") || b.count > CommentoEve.limite {
                    controlla(false, "Bozza del commento «\(scelta.tipo.nome)» per \(c.nome): \(b.count) caratteri")
                }
            }
        }
        stato.clienteAttivoId = "giulia"
        if let b = stato.bozzaCommento(.previdenza(report: true)) {
            let t = stato.testiPrevidenza("giulia")
            controlla(t.sintesi.prefix(4).allSatisfy { b.contains(String($0.1.dropFirst())) }, "Commento della previdenza di Giulia: stesse frasi e cifre del report")
            controlla(CommentoEve.numeriConservati(bozza: b, testo: b), "Commento: la bozza conserva le sue cifre")
            controlla(!CommentoEve.numeriConservati(bozza: b, testo: b + " Potresti guadagnare € 99.999 e il 12,5%."),
                      "Commento: una cifra inventata dal modello viene scartata")
        }
        if let coppia = MotoreSostituzione.coppia(stato.posizioniCliente("giulia")) {
            controlla(stato.bozzaCommento(.sostituzione(coppia.0, coppia.1, report: true)) != nil, "Bozza del commento per restare o cambiare")
        }
        stato.salvaCommento(.checkUp(report: true), testo: "  Gentile Giulia, prova.  ")
        controlla(stato.commento(.checkUp(report: true))?.testo == "Gentile Giulia, prova." && stato.commento(.checkUp(report: false))?.testo == "Gentile Giulia, prova.",
                  "Commento salvato per cliente e documento (lo stesso per prospetto e report)")
        stato.salvaCommento(.checkUp(report: true), testo: "")
        controlla(stato.commento(.checkUp(report: true)) == nil, "Commento tolto")

        // Eve spiega i documenti: dati con la pagina, confronto con il dossier
        if let f = stato.fonteEve("giulia"), let kid = f.documenti.first(where: { $0.tipo == .kid }) {
            let r = MotoriEve.sintesi.documento(kid, fonte: f)
            let sri = kid.campo(.sri)?.valore ?? "?"
            controlla(r.testo.contains("Rischio \(sri) su 7") && r.testo.contains("(pag. "), "KID di Giulia: rischio \(sri) su 7 con la pagina")
            controlla(kid.campi.allSatisfy(\.confermato) || r.testo.contains("Da confermare"), "KID di Giulia: segnala i dati da confermare")
        } else {
            controlla(false, "Giulia ha un KID di prova")
        }
        if let f = stato.fonteEve("marco"), var polizza = f.documenti.first(where: { $0.tipo == .polizza }) {
            let r = MotoriEve.sintesi.documento(polizza, fonte: f)
            controlla(r.testo.contains("(pag. ") && r.testo.contains("condizioni di polizza"), "Polizza di Marco: dati con la pagina e verifiche")
            if let i = polizza.campi.firstIndex(where: { $0.chiave == .capitaleAssicurato }) {
                polizza.campi[i].valore = "1.234.567,00"
                let diff = MotoriEve.sintesi.confronta(polizza, fonte: f)
                controlla(diff.contains { $0.contains("capitale assicurato € 1.234.567") }, "Polizza di Marco: un capitale diverso dalla posizione viene segnalato")
            }
            stato.dati.impostazioni.eve.motore = .sintesi
            let prima = stato.conversazione("marco").count
            stato.spiegaDocumentoConEve(polizza.id)
            controlla(stato.conversazione("marco").count == prima + 2 && stato.clienteAttivoId == "marco", "«Chiedi a Eve» da Documenti: domanda e spiegazione salvate")
        } else {
            controlla(false, "Marco ha una polizza di prova")
        }
        controlla(SpuntoEve.argomento("Cosa c'è scritto nel KID?") == .documenti, "Argomento: domanda su un KID → documenti")

        // Le proposte di Eve: dalle analisi alle attività e alle bozze di proposta
        stato.dati.impostazioni.eve.motore = .sintesi
        stato.clienteAttivoId = "giulia"
        if let f = stato.fonteEve("giulia") {
            let elenco = MotoreSintesi.calcolaProposte(f)
            let prot = MotoreProtezioneFamiglia.calcola(f.posizioni, cliente: f.cliente, analisi: f.analisi.protezione, data: f.oggi)
            controlla(prot.divarioConProposte < 1_000 || elenco.contains { $0.id == "protezione-vita" },
                      "Proposte di Giulia: la copertura caso morte (divario \(CifreDoc.euro(prot.divarioConProposte)))")
            let aperta = f.posizioni.contains { $0.stato == .proposta && $0.area == .previdenza && $0.esito != .rifiutata && $0.esito != .accettata }
            controlla(!aperta || !elenco.contains { $0.id == "previdenza" }, "Proposte di Giulia: niente doppione della previdenza già in proposta")
            controlla(elenco.count <= MotoreSintesi.massimoProposte && elenco.allSatisfy { !$0.perche.isEmpty }, "Proposte di Giulia: al massimo \(MotoreSintesi.massimoProposte), ognuna con il perché")
            stato.chiediEve(SpuntoEve.proposte.domanda, spunto: .proposte)
            if let m = stato.conversazione("giulia").last, let p = m.proposte?.first(where: { $0.area != nil }) {
                let attivita = stato.dati.attivita.count
                stato.attivitaDaProposta(p, messaggio: m.id)
                controlla(stato.dati.attivita.count == attivita + 1 && stato.conversazione("giulia").last?.proposte?.first { $0.id == p.id }?.attivitaId != nil,
                          "Proposta «\(p.titolo)» → attività, segnata nel messaggio")
                let posizioni = stato.posizioni.count
                stato.posizioneDaProposta(p, messaggio: m.id)
                stato.posizioneDaProposta(stato.conversazione("giulia").last?.proposte?.first { $0.id == p.id } ?? p, messaggio: m.id)
                let nuova = stato.posizioni.last
                controlla(stato.posizioni.count == posizioni + 1 && nuova?.stato == .proposta && nuova?.esito == .bozza && nuova?.area == p.area
                          && nuova?.capitaleAssicurato == p.capitale,
                          "Proposta «\(p.titolo)» → una sola bozza in Posizioni, con area e cifre")
                if let fd = stato.fonteEve("giulia") {
                    controlla(!MotoreSintesi.calcolaProposte(fd).contains { $0.id == p.id }, "Dopo la bozza, Eve non ripropone «\(p.titolo)»")
                }
            } else {
                controlla(false, "Il messaggio delle proposte di Giulia ha le azioni")
            }
        }

        // La chat in modalità sintesi aggiunge domanda e risposta
        stato.dati.impostazioni.eve.motore = .sintesi
        stato.clienteAttivoId = "marco"
        let primaChat = stato.conversazione("marco").count
        stato.chiediEve(SpuntoEve.prossimiPassi.domanda, spunto: .prossimiPassi)
        controlla(stato.conversazione("marco").count == primaChat + 2, "Conversazione: domanda e risposta salvate")

        print("INFO Modello Apple su questo Mac: \(MotoriEve.motivoAppleNonDisponibile ?? "disponibile")")
        if errori == 0 {
            print("OK: Eve verificata")
            return 0
        }
        print("ERRORE: \(errori) verifiche di Eve non riuscite")
        return 1
    }
}
