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
        // Parole che contengono una chiave ma parlano d'altro
        for (domanda, atteso) in [("Qual è il patrimonio netto?", SpuntoEve.riepilogo), ("Ci sono passività?", nil), ("Il conto è in sospensione?", nil),
                                  ("Controlla le impostazioni", nil), ("Cosa gli propongo?", .proposte)] as [(String, SpuntoEve?)] {
            controlla(SpuntoEve.argomento(domanda) == atteso, "Argomento di «\(domanda)» → \(atteso?.rawValue ?? "nessuno")")
        }
        controlla(CommentoEve.numeriConservati(bozza: "Mancano € 50.000 e il −4,5%.", testo: "Mancano 50.000 euro e il -4,5%."), "Commento: «50.000 euro» è la stessa cifra di «€ 50.000»")
        controlla(!CommentoEve.numeriConservati(bozza: "Rende il −4,5%.", testo: "Rende il 4,5%."), "Commento: il segno cambiato viene scartato")
        controlla(!CommentoEve.numeriConservati(bozza: "Mancano € 55.000.", testo: "Mancano circa 60 mila euro."), "Commento: le cifre in parole vengono scartate")
        // Le proposte restano anche per le domande scritte a mano
        if let f = stato.fonteEve("giulia") {
            let r = MotoriEve.sintesi.componi(RichiestaEve(domanda: "cosa gli propongo?", spunto: nil, fonte: f, storia: []))
            controlla(r.proposte?.isEmpty == false, "Domanda scritta a mano sulle proposte: le azioni ci sono")
        }

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

        // «Cerca ovunque»: maiuscole e accenti non contano, ogni parola deve esserci
        let ricerca = StatoShell(persistente: false)
        func primi(_ testo: String, _ g: GruppoRicerca) -> [RisultatoRicerca] {
            MotoreRicerca.cerca(testo, in: ricerca).first { $0.gruppo == g }?.risultati ?? []
        }
        controlla(MotoreRicerca.cerca("   ", in: ricerca).isEmpty, "Ricerca vuota: nessun risultato")
        controlla(primi("GIULIA rossi", .clienti).first?.destinazione == .cliente("giulia"), "Ricerca: «GIULIA rossi» trova Giulia Rossi")
        controlla(primi("marco", .posizioni).allSatisfy { $0.estratto == nil }, "Ricerca: il nome del cliente non si ripete sotto le sue posizioni")
        controlla(!primi("riscatto", .prodotti).isEmpty, "Ricerca: «riscatto» trova i prodotti dalla liquidabilità")
        controlla(primi("giulia bianchi", .clienti).isEmpty, "Ricerca: tutte le parole devono esserci")
        controlla(primi("attivita", .app).contains { $0.destinazione == .app(.attivita) }, "Ricerca: «attivita» trova l'app Attività (senza accento)")
        if let p = ricerca.dati.posizioni.first(where: { !$0.numeroContratto.isEmpty }) {
            let r = primi(p.numeroContratto, .posizioni).first { $0.destinazione == .posizione(p.id) }
            controlla(r != nil && r?.canale == p.canale, "Ricerca: il numero di contratto trova «\(p.nome)», con il canale")
        }
        if let d = ricerca.documento("doc-marco-polizza"), let parola = ricerca.testoDocumento(d).first?
            .split(whereSeparator: { !$0.isLetter }).map(String.init)
            .first(where: { parola in parola.count >= 8 && !MotoreRicerca.contiene(d.titolo, parola) && !d.campi.contains { MotoreRicerca.contiene($0.valore, parola) } }) {
            let r = primi(parola, .documenti).first { $0.destinazione == .documento(d.id) }
            controlla(r?.estratto?.hasPrefix("pag.") == true, "Ricerca nel testo della polizza di Marco («\(parola)»), con la riga trovata")
            ricerca.clienteAttivoId = "giulia"
            ricerca.vai(a: .documento(d.id))
            controlla(ricerca.clienteAttivoId == d.clienteId && ricerca.documentoSelezionato == d.id && ricerca.appAttiva == .documenti,
                      "Ricerca: il documento si apre in Documenti, sul suo cliente")
        } else {
            controlla(false, "La polizza di prova di Marco ha del testo")
        }
        if let a = ricerca.attivita.first(where: { $0.completata }) {
            ricerca.filtroStatoAttivita = .aperte
            ricerca.vai(a: .attivita(a.id))
            controlla(ricerca.attivitaSelezionata == a.id && ricerca.filtroStatoAttivita != .aperte, "Ricerca: un'attività completata resta visibile quando si apre")
        }
        ricerca.cercaOvunque()
        controlla(ricerca.appAttiva == .ricerca && ricerca.richiestaFuocoRicerca == 1, "⌘K apre la Ricerca con il cursore nel campo")

        // Spazi di lavoro: le app al loro posto, affiancate senza sovrapporsi, salvate nell'archivio
        let spazi = StatoShell(persistente: false)
        // Come una finestra di Prisma da 1440×900: dalla scrivania (dock visibile) le finestre aperte
        // nascondono il dock e l'area cresce, come fa la vista
        let conDock = CGRect(x: 8, y: 33, width: 1424, height: 786)
        let senzaDock = CGRect(x: 8, y: 33, width: 1424, height: 858)
        func apriSpazio(_ s: SpazioLavoro) {
            spazi.area = spazi.finestreVisibili.isEmpty ? conDock : senzaDock
            spazi.apriSpazio(s)
            spazi.area = senzaDock
        }
        func sovrapposte(_ s: StatoShell) -> Bool {
            let c = s.finestreVisibili.map { s.cornice(di: $0) }
            return c.indices.contains { i in c.indices.contains { j in i < j && c[i].insetBy(dx: 1, dy: 1).intersects(c[j]) } }
        }
        func dentro(_ s: StatoShell) -> Bool {
            s.finestreVisibili.allSatisfy { CGRect(origin: .zero, size: s.area.size).contains(s.cornice(di: $0)) }
        }
        if let incontro = SpazioLavoro.predefiniti.first {
            apriSpazio(incontro)
            controlla(spazi.finestreVisibili.map(\.app) == [.eve, .clienti], "Spazio «\(incontro.nome)»: Eve e Clienti in primo piano")
            controlla(!sovrapposte(spazi) && dentro(spazi), "Spazio «\(incontro.nome)»: finestre affiancate, dentro lo schermo")
            controlla(spazi.finestreVisibili.allSatisfy { spazi.cornice(di: $0).width >= Misure.Finestra.minima.width && spazi.cornice(di: $0).height >= Misure.Finestra.minima.height },
                      "Spazio «\(incontro.nome)»: nessuna finestra sotto la misura minima")
        }
        for p in SpazioLavoro.predefiniti {
            apriSpazio(p)
            if sovrapposte(spazi) || !dentro(spazi) { controlla(false, "Spazio pronto «\(p.nome)» disposto bene") }
        }
        let prima = spazi.finestreVisibili.map { spazi.cornice(di: $0) }
        let salvato = spazi.salvaSpazio(nome: "  Revisione annuale ")
        controlla(salvato?.nome == "Revisione annuale" && spazi.dati.spazi.count == 1, "Spazio salvato con il suo nome")
        controlla(spazi.salvaSpazio(nome: "   ") == nil, "Uno spazio senza nome non si salva")
        if let salvato {
            spazi.mostraScrivania()
            apriSpazio(salvato)
            let dopo = spazi.finestreVisibili.map { spazi.cornice(di: $0) }
            controlla(dopo.count == prima.count && zip(prima, dopo).allSatisfy { abs($0.minX - $1.minX) < 1 && abs($0.width - $1.width) < 1 && abs($0.height - $1.height) < 1 },
                      "Lo spazio salvato si riapre com'era")
            let riletto = try? Archivio.decodifica(Archivio.codificatore.encode(spazi.dati))
            controlla(riletto?.spazi == spazi.dati.spazi && riletto?.spazi.first?.predefinito == false, "Gli spazi salvati restano nell'archivio")
            spazi.eliminaSpazio(salvato.id)
            controlla(spazi.dati.spazi.isEmpty, "Spazio eliminato")
        }
        spazi.mostraScrivania()
        spazi.apri(.agenda)
        spazi.apri(.eve)
        spazi.affianca(.eve)
        if let eve = spazi.finestreVisibili.first(where: { $0.app == .eve }), let agenda = spazi.finestreVisibili.first(where: { $0.app == .agenda }) {
            controlla(spazi.cornice(di: eve).maxX <= spazi.cornice(di: agenda).minX + 1 && spazi.appAttiva == .eve && !sovrapposte(spazi),
                      "◫ affianca Eve (a sinistra) e Agenda (a destra)")
        }

        // Note: il taccuino legato ai clienti
        let taccuino = StatoShell(persistente: false)
        controlla(taccuino.noteFiltrate.count == 3 && taccuino.noteFiltrate.prefix(2).allSatisfy(\.fissata), "Note di prova: tre, le fissate in cima")
        taccuino.ricercaNote = "ANNA aspettative"
        controlla(taccuino.noteFiltrate.map(\.id) == ["nota-marco"], "Ricerca nelle note: ogni parola, senza badare alle maiuscole")
        taccuino.ricercaNote = ""
        taccuino.filtroClienteNote = "laura"
        controlla(taccuino.noteFiltrate.map(\.id) == ["nota-laura"], "Note filtrate per cliente")
        let pagina = taccuino.nuovaNota()
        controlla(pagina?.clienteId == "laura" && taccuino.notaSelezionata == pagina?.id, "Nuova nota per il cliente del filtro, già aperta")
        taccuino.scegliNota("nota-laura")
        controlla(!taccuino.dati.note.contains { $0.id == pagina?.id }, "Una pagina nuova lasciata vuota non resta nel taccuino")
        let primaModifica = taccuino.nota("nota-laura")?.aggiornataIl
        taccuino.modificaNota("nota-laura") { $0.fissata = true }
        controlla(taccuino.nota("nota-laura")?.aggiornataIl == primaModifica && taccuino.nota("nota-laura")?.fissata == true, "Fissare una nota non cambia la data di aggiornamento")
        taccuino.modificaNota("nota-laura") { $0.testo += "\nRichiamare a novembre." }
        controlla((taccuino.nota("nota-laura")?.aggiornataIl ?? .distantPast) > (primaModifica ?? .distantFuture), "Scrivere aggiorna la data della nota")
        if let bozza = taccuino.bozzaAttivitaDaNota("nota-laura") {
            let attivitaPrima = taccuino.attivita.count
            taccuino.salvaAttivita(bozza)
            controlla(taccuino.attivita.count == attivitaPrima + 1 && bozza.clienteId == "laura" && bozza.titolo == "Più libertà nel proprio lavoro",
                      "Dalla nota all'attività, per lo stesso cliente")
        } else {
            controlla(false, "Bozza di attività dalla nota")
        }
        controlla(MotoreRicerca.cerca("novembre", in: taccuino).first { $0.gruppo == .note }?.risultati.first?.destinazione == .nota("nota-laura"),
                  "Cerca ovunque trova le note anche nel testo")
        taccuino.filtroClienteNote = "giulia"
        taccuino.vai(a: .nota("nota-laura"))
        controlla(taccuino.appAttiva == .note && taccuino.notaSelezionata == "nota-laura" && taccuino.noteFiltrate.contains { $0.id == "nota-laura" },
                  "Il risultato della ricerca apre la nota in Note, anche con un altro filtro")
        let rilette = try? Archivio.decodifica(Archivio.codificatore.encode(taccuino.dati))
        controlla(rilette?.note == taccuino.dati.note, "Le note restano nell'archivio")
        taccuino.eliminaCliente("laura")
        controlla(!taccuino.dati.note.contains { $0.clienteId == "laura" }, "Eliminando un cliente spariscono anche le sue note")

        // Centro notifiche: ricavato dai dati, ogni notifica porta dove si risolve
        let avvisi = StatoShell(persistente: false)
        let cal = Calendar.current
        let mattina = cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        let giorno = cal.startOfDay(for: mattina)
        if let i = avvisi.dati.posizioni.firstIndex(where: { $0.stato == .inEssere }) {
            avvisi.dati.posizioni[i].scadenza = cal.date(byAdding: .day, value: 10, to: giorno)
        }
        if let i = avvisi.dati.clienti.firstIndex(where: { $0.id == "sofia" }) {
            avvisi.dati.clienti[i].dataNascita = cal.date(byAdding: .year, value: -40, to: giorno)
        }
        var vecchia = Attivita.nuova(clienteId: "giulia", scadenza: cal.date(byAdding: .day, value: -3, to: giorno) ?? giorno)
        vecchia.titolo = "Richiamare per il preventivo"
        avvisi.dati.attivita.append(vecchia)
        avvisi.dati.impostazioni.backup.ultimoErrore = "Disco esterno non collegato"
        let notifiche = MotoreNotifiche.calcola(avvisi, oggi: mattina)
        let diOggi = avvisi.dati.appuntamenti.filter { $0.stato == .pianificato && cal.isDate($0.inizio, inSameDayAs: giorno) }
        controlla(notifiche.filter { $0.id.hasPrefix("appuntamento-") }.count == diOggi.count, "Notifiche: gli appuntamenti di oggi (\(diOggi.count))")
        controlla(notifiche.contains { $0.id == "attivita-\(vecchia.id)" && $0.gruppo == .daFare }, "Notifiche: l'attività scaduta è da recuperare")
        controlla(notifiche.contains { $0.id.hasPrefix("scadenza-") && $0.titolo.contains("scade tra 10 giorni") && $0.canale != nil }, "Notifiche: la posizione in scadenza, con il canale")
        controlla(notifiche.contains { $0.titolo == "Oggi Sofia Romano compie 40 anni" }, "Notifiche: il compleanno del cliente")
        controlla(notifiche.contains { $0.id == "backup-errore" && $0.gruppo == .daFare }, "Notifiche: il backup non riuscito")
        controlla(zip(notifiche, notifiche.dropFirst()).allSatisfy { $0.gruppo.rawValue <= $1.gruppo.rawValue }, "Notifiche in ordine: da recuperare, oggi, prossimi giorni, da sistemare")
        let sera = cal.date(bySettingHour: 23, minute: 0, second: 0, of: giorno) ?? giorno
        controlla(diOggi.allSatisfy { a in MotoreNotifiche.calcola(avvisi, oggi: sera).contains { $0.id == "esito-\(a.id)" } },
                  "Notifiche: gli appuntamenti di oggi già finiti chiedono l'esito")
        controlla(avvisi.notificheNuove > 0, "La campanella conta le notifiche nuove")
        avvisi.alternaNotifiche()
        controlla(avvisi.pannelloNotifiche && avvisi.notificheNuove == 0, "Aperto il centro notifiche, la campanella si azzera")
        if let n = notifiche.first(where: { $0.id == "attivita-\(vecchia.id)" }) {
            avvisi.apriNotifica(n)
            controlla(!avvisi.pannelloNotifiche && avvisi.appAttiva == .attivita && avvisi.attivitaSelezionata == vecchia.id, "La notifica apre l'attività")
        }
        let bisestile = cal.date(from: DateComponents(year: 1980, month: 2, day: 29)) ?? giorno
        let dal = cal.date(from: DateComponents(year: 2027, month: 1, day: 10)) ?? giorno
        controlla(MotoreNotifiche.prossimoCompleanno(bisestile, da: dal, cal: cal).map { [cal.component(.month, from: $0), cal.component(.day, from: $0)] } == [2, 28],
                  "Compleanno del 29 febbraio: il 28 negli anni non bisestili")

        // Schermata di benvenuto: copre tutto e chiude i pannelli
        avvisi.pannelloSpazi = true
        avvisi.blocca()
        controlla(avvisi.bloccato && !avvisi.pannelloSpazi && !avvisi.pannelloNotifiche, "Il lucchetto mostra la schermata di benvenuto e chiude i pannelli")

        // Eve legge il taccuino: le note del cliente nella scheda e nella traccia dell'incontro
        let conNote = StatoShell(persistente: false)
        if let f = conNote.fonteEve("giulia") {
            controlla(ContestoEve.scheda(f).contains("La casa è un nuovo inizio"), "Scheda di Eve: le note del taccuino")
            let traccia = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .incontro, fonte: f, storia: []))
            controlla(traccia.testo.contains("Dal tuo taccuino") && traccia.testo.contains("La casa è un nuovo inizio"), "Traccia dell'incontro: le note del taccuino")
        }

        print("INFO Modello Apple su questo Mac: \(MotoriEve.motivoAppleNonDisponibile ?? "disponibile")")
        if errori == 0 {
            print("OK: Eve verificata")
            return 0
        }
        print("ERRORE: \(errori) verifiche di Eve non riuscite")
        return 1
    }
}
