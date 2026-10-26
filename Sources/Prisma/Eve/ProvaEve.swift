import AVFoundation
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
        // Una posizione nominata nella domanda: Eve risponde con il suo andamento
        if let f = stato.fonteEve("giulia"),
           let p = f.posizioni.first(where: { $0.stato == .inEssere && $0.area.proiettabile && MotoreAndamento.calcola($0) != nil }) {
            let r = MotoriEve.sintesi.componi(RichiestaEve(domanda: "Come sta andando \(p.nome.lowercased())?", spunto: nil, fonte: f, storia: []))
            controlla(r.titolo == "Andamento di \(p.nome)", "Domanda su «\(p.nome)»: risponde con l'andamento (\(r.titolo ?? "nessun titolo"))")
            controlla(ContestoEve.riga(p).contains("andamento dal"), "La scheda per il modello riporta l'andamento di \(p.nome)")
            let resoconto = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .resoconto, fonte: f, storia: []))
            controlla(resoconto.testo.contains("rispetto all'atteso"), "Il resoconto di Eve confronta l'andamento con l'atteso")
            // Un valore passato aggiunto a mano entra nello storico; toglierlo lo fa sparire
            let prima = p.storicoValori.count
            let quando = Calendar.current.date(byAdding: .month, value: -30, to: Date()) ?? Date()
            stato.aggiungiRilevazione(Rilevazione(data: quando, controvalore: 1_000, versato: 1_000), a: p.id)
            controlla(stato.posizioni.first { $0.id == p.id }?.storicoValori.count == prima + 1, "Valore passato aggiunto allo storico")
            stato.aggiungiRilevazione(Rilevazione(data: quando, controvalore: 1_100, versato: 1_000), a: p.id)
            controlla(stato.posizioni.first { $0.id == p.id }?.storicoValori.count == prima + 1, "Un valore dello stesso giorno sostituisce il precedente")
            stato.eliminaRilevazione(quando, da: p.id)
            controlla(stato.posizioni.first { $0.id == p.id }?.storicoValori.count == prima, "Valore passato tolto dallo storico")
        } else {
            controlla(false, "Giulia ha una posizione con l'andamento")
        }
        // Estratto conto di prova: confermato, compare tra le notifiche; registrato, entra nello storico e la notifica sparisce
        if let d = stato.documento("doc-giulia-estratto"), let piano = ValoriDaDocumento.posizioneProbabile(d, tra: stato.posizioni) {
            for c in d.campi { stato.confermaCampo(d.id, c.chiave, true) }
            let notificaValore = { MotoreNotifiche.calcola(stato).contains { $0.id.hasPrefix("valore-\(d.id)") } }
            controlla(notificaValore(), "Estratto confermato: notifica del valore da registrare")
            let prima = piano.storicoValori.count
            stato.registraValore(daDocumento: d.id, posizione: piano.id)
            controlla(stato.posizioni.first { $0.id == piano.id }?.storicoValori.count == prima + 1, "Estratto: valore registrato nello storico di \(piano.nome)")
            controlla(stato.documento(d.id)?.posizioneId == piano.id, "Estratto collegato alla posizione")
            controlla(!notificaValore(), "Estratto registrato: la notifica sparisce")
        } else {
            controlla(false, "Estratto conto di prova e posizione riconosciuta")
        }
        // Riesame annuale: ordine del giorno, domande, bozza dell'incontro con l'agenda nelle note
        for c in stato.clienti {
            guard let f = stato.fonteEve(c.id) else { continue }
            let r = MotoreRiesame.calcola(f)
            controlla(r.domande.count >= 2, "Riesame di \(c.nome): \(r.punti.count) punti, \(r.domande.count) domande")
            controlla(zip(r.punti, r.punti.dropFirst()).allSatisfy { $0.priorita <= $1.priorita }, "Riesame di \(c.nome): prima i punti con priorità alta")
        }
        // Il riesame raccoglie le analisi del dossier: beneficiari, convivente, costi
        if let f = stato.fonteEve("marco") {
            let r = MotoreRiesame.calcola(f)
            controlla(r.punti.contains { $0.tema == .famiglia && $0.titolo == "Indicare i beneficiari" && $0.priorita == .alta },
                      "Riesame di Marco: beneficiari da indicare, priorità alta")
            controlla(r.punti.contains { $0.tema == .costi && $0.titolo.contains("Piano individuale pensionistico") },
                      "Riesame di Marco: l'alternativa più economica al PIP")
            controlla(r.domande.contains { $0.contains("beneficiari") || $0.contains("ricevesse") }, "Riesame di Marco: la domanda sui beneficiari")
        }
        if let f = stato.fonteEve("giulia") {
            controlla(MotoreRiesame.calcola(f).punti.contains { $0.tema == .famiglia && $0.titolo == "Tutelare Luca Ferri" }, "Riesame di Giulia: tutelare il convivente")
        }
        let attenzioni = MotoreAttenzioni.calcola(clienti: stato.dati.clienti, posizioni: stato.dati.posizioni)
        controlla(attenzioni.contains { $0.cliente.id == "marco" && $0.tipo == .beneficiari } && attenzioni.contains { $0.cliente.id == "giulia" && $0.tipo == .convivente },
                  "Da sistemare nei dossier: i beneficiari di Marco e il convivente di Giulia")
        controlla(MotoreNotifiche.calcola(stato).contains { $0.id.hasPrefix("beneficiari-") && $0.id.contains("marco") }, "Notifiche: clienti con beneficiari da indicare")
        if let f = stato.fonteEve("giulia") {
            let r = MotoreRiesame.calcola(f)
            controlla(r.andamenti.count == MotoreResoconto.calcola(f.posizioni, cliente: "").finanziarie.compactMap { MotoreAndamento.calcola($0.posizione) }.count,
                      "Riesame di Giulia: lo stesso andamento del resoconto")
            if let a = stato.bozzaRiesame("giulia") {
                controlla(a.tipo == .revisione && a.durataMinuti == 60 && a.note.hasPrefix("Ordine del giorno"), "Bozza del riesame: revisione di un'ora con l'ordine del giorno")
                controlla(!Calendar.current.isDateInWeekend(a.inizio) && a.inizio > Date(), "Bozza del riesame: un giorno lavorativo futuro")
            } else {
                controlla(false, "Bozza del riesame di Giulia")
            }
            stato.clienteAttivoId = "giulia"
            let c = stato.contenutoProspetto(.riesame)
            controlla(c?.titolo == "Riesame annuale di \(f.cliente.nome)", "Prospetto del riesame composto")
        }
        // Importazione dei clienti: vCard dell'app Contatti e CSV di Excel, doppioni segnati
        let vcard = """
        BEGIN:VCARD\r
        VERSION:3.0\r
        N:Bianchi;Paolo;;;\r
        FN:Paolo Bianchi\r
        item1.TEL;type=CELL;type=pref:+39 333 123 4567\r
        EMAIL;type=INTERNET:paolo.bianchi@example.it\r
        ADR;type=HOME:;;Via Roma 10;Milano;MI;20121;Italia\r
        BDAY:1980-05-02\r
        NOTE:Conosciuto tramite\\, Giulia\r
        END:VCARD\r
        BEGIN:VCARD\r
        VERSION:3.0\r
        N:Rossi;Giulia;;;\r
        END:VCARD\r
        """
        let daContatti = ImportaClienti.segnaDoppioni(ImportaClienti.daVCard(vcard), rubrica: stato.clienti)
        controlla(daContatti.count == 2 && daContatti[0].nome == "Paolo Bianchi" && daContatti[0].telefono == "+39 333 123 4567"
                  && daContatti[0].email == "paolo.bianchi@example.it" && daContatti[0].indirizzo == "Via Roma 10, 20121 Milano (MI)"
                  && daContatti[0].nota == "Conosciuto tramite, Giulia" && daContatti[0].dataNascita != nil,
                  "Importa: vCard con telefono, email, indirizzo, nascita e nota (\(daContatti.first.map { "\($0.nome) · \($0.indirizzo)" } ?? "nessuno"))")
        controlla(daContatti.count == 2 && daContatti[1].nome == "Giulia Rossi" && daContatti[1].doppione != nil, "Importa: Giulia Rossi è già in rubrica (dal campo N)")
        let csv = "Cognome;Nome;Codice fiscale;Data di nascita;Cellulare;E-mail;Città\nVerdi;\"Anna Maria\";vrdnmr75a41f205x;03/01/1975;333 1;anna@example.it;Torino\n;;;;;;\nNeri;Luca;;;;;\"Roma; Lazio\"\n"
        let foglio = ImportaClienti.daCSV(csv)
        controlla(foglio.clienti.count == 2 && foglio.clienti[0].nome == "Anna Maria Verdi" && foglio.clienti[0].codiceFiscale == "VRDNMR75A41F205X"
                  && foglio.clienti[0].dataNascita.map { Calendar.current.component(.year, from: $0) } == 1975 && foglio.clienti[1].indirizzo == "Roma; Lazio",
                  "Importa: CSV con punto e virgola, virgolette, righe vuote saltate (\(foglio.clienti.map(\.nome)))")
        controlla(ImportaClienti.Colonna.da("Codice Fiscale") == .codiceFiscale && ImportaClienti.Colonna.da("Telefono casa") == .telefono
                  && ImportaClienti.Colonna.da("Nome e cognome") == .nominativo, "Importa: colonne riconosciute dall'intestazione")
        let clientiPrima = stato.clienti.count
        stato.aggiungiImportati(foglio.clienti)
        controlla(stato.clienti.count == clientiPrima + 2 && stato.clienteAttivo?.nome == "Anna Maria Verdi", "Importa: clienti aggiunti alla rubrica")
        // Importazione delle posizioni: abbinate ai clienti, canale e area proposti, doppioni e clienti mancanti esclusi
        let polizze = "Contraente;Codice fiscale;Prodotto;N. polizza;Compagnia;Decorrenza;Scadenza;Premio;Frazionamento;Valore al;Controvalore;Premi versati\n"
            + "Anna Maria Verdi;;Piano di accumulo rivalutabile;AL-1;Alleanza Assicurazioni;01/02/2020;01/02/2035;100,00;mensile;30/09/2026;8.150,00;7.900,00\n"
            + "Verdi Anna Maria;;Temporanea caso morte;AL-2;Alleanza;01/02/2021;01/02/2041;25;mensile;;;\n"
            + "Mario Assente;;Fondo azionario;X-9;Fineco;;;;;;10.000,00;\n"
            + "Anna Maria Verdi;;Piano di accumulo rivalutabile;AL-1;Alleanza Assicurazioni;;;;;;;\n"
            + "Luca Neri;;ETF azionario globale;;Banca X;15/03/2023;;1.000;unico;;1.200;\n"
        let lette = ImportaPosizioni.daCSV(polizze, clienti: stato.clienti, posizioni: stato.posizioni, canale: .indipendente).posizioni
        controlla(lette.count == 5, "Importa posizioni: 5 righe lette (\(lette.count))")
        if lette.count == 5 {
            let pac = lette[0].posizione
            controlla(lette[0].cliente?.nome == "Anna Maria Verdi" && pac.canale == .alleanza && pac.area == .risparmio && pac.premio == 100
                      && pac.frequenza == .mensile && pac.controvalore == 8_150 && pac.totaleVersato == 7_900 && pac.dataValore != nil && lette[0].problema == nil,
                      "Importa posizioni: piano Alleanza abbinato, area risparmio, premio mensile, valore e versato")
            controlla(lette[1].cliente?.nome == "Anna Maria Verdi" && lette[1].posizione.area == .protezione && lette[1].posizione.rischio == .vita,
                      "Importa posizioni: cognome e nome invertiti, TCM in protezione caso morte")
            controlla(lette[2].cliente == nil && lette[2].problema == nil && lette[2].nuovoCliente?.nome == "Mario Assente",
                      "Importa posizioni: cliente non in rubrica proposto come cliente nuovo")
            controlla(lette[3].problema == "ripetuta nel file", "Importa posizioni: la stessa polizza due volte")
            controlla(lette[4].posizione.canale == .indipendente && lette[4].posizione.area == .investimento && lette[4].posizione.versamentoIniziale == 1_000
                      && lette[4].posizione.premio == 0, "Importa posizioni: premio unico come versamento iniziale, canale scelto")
            let primaPosizioni = stato.posizioni.count
            stato.importaPosizioni(lette.filter { $0.problema == nil && $0.cliente != nil }.map(\.posizione))
            controlla(stato.posizioni.count == primaPosizioni + 3, "Importa posizioni: tre posizioni aggiunte")
            let ancora = ImportaPosizioni.daCSV(polizze, clienti: stato.clienti, posizioni: stato.posizioni).posizioni
            controlla(ancora.first?.problema == "già in Posizioni", "Importa posizioni: una seconda importazione le riconosce già presenti")
            let nuove = Set(stato.clienti.filter { ["Anna Maria Verdi", "Luca Neri"].contains($0.nome) }.map(\.id))
            stato.dati.posizioni.removeAll { nuove.contains($0.clienteId) }
        }
        for (ok, descrizione) in provaImportazioniRapide(stato) { controlla(ok, descrizione) }
        // Le prove che seguono riguardano i clienti di prova
        let importati = Set(foglio.clienti.map(\.nome))
        stato.dati.clienti.removeAll { importati.contains($0.nome) }
        stato.clienteAttivoId = "giulia"
        // La guida per cominciare: con i dati di prova è visibile, i passi si spuntano da soli
        let guida = StatoShell(persistente: false)
        controlla(guida.guidaVisibile && guida.passiGuida.count == 6 && guida.passiGuida.allSatisfy { !$0.fatto || $0.azione == .passwordPDF },
                  "Guida: visibile con i dati di prova, nessun passo fatto")
        guida.dati.impostazioni.pdf.proteggi = true
        guida.dati.clienti.append(Cliente(id: "vero", nome: "Cliente Vero", iniziali: "CV", tinta: .blu, tema: "", email: "", telefono: "",
                                          preferito: false, nota: "", creatoIl: Date()))
        controlla(guida.passiGuida.filter(\.fatto).count == 2, "Guida: password dei PDF e primo cliente vero spuntati da soli")
        guida.dati.impostazioni.guidaNascosta = true
        controlla(!guida.guidaVisibile, "Guida: nascosta dalla scrivania")
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
            ("È coperto in caso di invalidità?", .protezione),
            ("Cosa succede al suo patrimonio netto se i mercati crollano?", .resistenza),
            ("Quanto può perdere in una crisi?", .resistenza),
            ("Quali costi paga sulle sue polizze?", .costi),
            ("Quanto gli costano di commissioni?", .costi),
            ("Cosa succede ai figli se viene a mancare? Chi eredita?", .successione),
            ("Chi sono i beneficiari delle polizze?", .successione)
        ]
        for (domanda, atteso) in argomenti {
            controlla(SpuntoEve.argomento(domanda) == atteso, "Argomento di «\(domanda)» → \(atteso.rawValue)")
        }
        // Passaggio generazionale: le stesse cifre del pannello in Posizioni
        if let f = stato.fonteEve("marco") {
            let su = MotoreSuccessione.calcola(cliente: f.cliente, posizioni: f.posizioni, oggi: f.oggi)
            let r = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .successione, fonte: f, storia: []))
            controlla(r.titolo == "Il passaggio generazionale di Marco Bianchi" && MotoreSuccessione.sintesi(su).allSatisfy { r.testo.contains($0) },
                      "Passaggio generazionale di Marco: Eve riporta le cifre del motore")
            controlla(ContestoEve.scheda(f).contains("SUCCESSIONE (stima di Prisma"), "La scheda per il modello riporta la successione")
            controlla(ContestoEve.scheda(f).contains("PATRIMONIO NEL TEMPO"), "La scheda per il modello riporta il patrimonio nel tempo")
        }
        // Peso dei costi: le stesse cifre del pannello in Posizioni
        if let f = stato.fonteEve("marco") {
            let a = MotoreCosti.calcola(f.posizioni, prodotti: f.prodotti, cliente: f.cliente.id)
            let r = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .costi, fonte: f, storia: []))
            controlla(!a.voci.isEmpty && r.titolo == "I costi di Marco Bianchi" && MotoreCosti.sintesi(a).allSatisfy { r.testo.contains($0) },
                      "Costi di Marco: Eve riporta le cifre del motore")
            controlla(ContestoEve.scheda(f).contains("COSTI (calcolati da Prisma)"), "La scheda per il modello riporta i costi")
        }
        // Prova di resistenza: le stesse cifre del pannello in Posizioni
        if let f = stato.fonteEve("marco") {
            let prova = MotoreResistenza.calcola(f.posizioni, profilo: f.cliente.profilo)
            let r = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .resistenza, fonte: f, storia: []))
            controlla(!prova.vuota && r.titolo == "Prova di resistenza di Marco Bianchi" && MotoreResistenza.sintesi(prova).allSatisfy { r.testo.contains($0) },
                      "Prova di resistenza di Marco: Eve riporta le cifre del motore")
            controlla(ContestoEve.scheda(f).contains("PROVA DI RESISTENZA"), "La scheda per il modello riporta la prova di resistenza")
        }
        // Ogni documento di analisi ha il suo spunto
        for scelta in [SceltaProspetto.resoconto(report: false), .previdenza(report: true), .protezione(report: false),
                       .liquidita(report: false), .checkUp(report: true), .resistenza(report: true), .costi(report: true), .successione(report: true), .patrimonio(report: true), .obiettivo("", report: false), .sostituzione("", "", report: false)] {
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
                           .protezione(report: true), .liquidita(report: true), .resistenza(report: true), .costi(report: true), .successione(report: true), .patrimonio(report: true)] {
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
        let senzaDock = CGRect(x: 8, y: 33, width: 1424, height: 858)
        // Con il dock visibile l'area è più bassa di quanto il dock riserva (non un numero fisso: il dock cambia)
        let conDock = CGRect(x: 8, y: 33, width: 1424, height: 858 - (Misure.Dock.riservato - Misure.Dock.riservatoNascosto))
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
        // Un cliente senza contatti da un anno e niente in agenda: da ricontattare
        avvisi.dati.appuntamenti.removeAll { $0.clienteId == "laura" }
        avvisi.dati.incontri.removeAll { $0.clienteId == "laura" }
        controlla(MotoreNotifiche.calcola(avvisi, oggi: mattina).contains { $0.id.hasPrefix("ricontattare-") && $0.titolo.contains("Laura Moretti") },
                  "Notifiche: il cliente da ricontattare")
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

        // Modalità cliente: si vede solo il cliente davanti, le app di tutti non si aprono
        let schermo = StatoShell(persistente: false)
        schermo.clienteAttivoId = "marco"
        schermo.apri(.note)
        schermo.portafoglio = true
        schermo.evePortafoglio = true
        schermo.entraModoCliente()
        controlla(schermo.inModoCliente && schermo.clienti.map(\.id) == ["marco"], "Modalità cliente: in rubrica solo il cliente attivo")
        controlla(!schermo.posizioni.isEmpty && schermo.posizioni.allSatisfy { $0.clienteId == "marco" }
                  && schermo.appuntamenti.allSatisfy { $0.clienteId == "marco" } && schermo.attivita.allSatisfy { $0.clienteId == "marco" },
                  "Modalità cliente: posizioni, agenda e attività solo sue")
        controlla(!schermo.aperta(.note) && !schermo.portafoglio && !schermo.evePortafoglio, "Modalità cliente: chiusi Note e portafoglio")
        schermo.apri(.ricerca)
        schermo.apri(.impostazioni)
        schermo.portafoglio = true
        controlla(!schermo.aperta(.ricerca) && !schermo.aperta(.impostazioni) && !schermo.portafoglio, "Modalità cliente: Ricerca, Impostazioni e portafoglio non si aprono")
        schermo.apri(.posizioni)
        controlla(schermo.aperta(.posizioni), "Modalità cliente: il dossier del cliente si apre")
        schermo.clienteAttivoId = "giulia"
        controlla(schermo.clienteAttivoId == "marco", "Modalità cliente: il cliente attivo non cambia (nemmeno da Prodotti)")
        controlla(schermo.posizioniDelProdotto("prodotto-multiramo").allSatisfy { $0.clienteId == "marco" }, "Modalità cliente: «Dove è usata» solo per il cliente mostrato")
        schermo.apriSpazio(SpazioLavoro(nome: "Prova", finestre: [.sinistra(.note), .destra(.posizioni)]))
        controlla(!schermo.aperta(.note) && schermo.aperta(.posizioni), "Modalità cliente: uno spazio di lavoro non riapre Note")
        schermo.alternaModoCliente()
        controlla(!schermo.inModoCliente && schermo.clienti.count == schermo.dati.clienti.count, "Uscendo dalla modalità cliente tornano tutti")
        schermo.entraModoCliente()
        schermo.blocca()
        controlla(!schermo.inModoCliente, "La schermata di benvenuto chiude la modalità cliente")
        schermo.clienteAttivoId = "nessuno"
        schermo.entraModoCliente()
        controlla(!schermo.inModoCliente, "Senza un cliente attivo la modalità cliente non parte")
        // Presentazione all'incontro: a tutto schermo in modalità cliente, si sfoglia, all'uscita tutto com'era
        let sala = StatoShell(persistente: false)
        sala.clienteAttivoId = "marco"
        if let d = sala.documentoProspetto(.patrimonio(report: true)) {
            sala.presenta(d)
            controlla(sala.presentazione != nil && sala.inModoCliente, "Presentazione: parte in modalità cliente")
            sala.paginaPrecedente()
            controlla(sala.presentazione?.pagina == 0, "Presentazione: prima della prima pagina non si va")
            for _ in 0..<(d.pagine.count + 3) { sala.paginaSeguente() }
            controlla(sala.presentazione?.pagina == d.pagine.count - 1, "Presentazione: dopo l'ultima pagina non si va")
            sala.chiudiPresentazione()
            controlla(sala.presentazione == nil && !sala.inModoCliente, "Presentazione: all'uscita la modalità cliente si spegne")
            sala.entraModoCliente()
            sala.presenta(d)
            sala.chiudiPresentazione()
            controlla(sala.inModoCliente, "Presentazione: se la modalità cliente era già accesa, resta")
            sala.esciModoCliente()
        }
        // Annotazioni durante la presentazione: negli appunti dell'incontro, con la pagina; come attività
        let annota = StatoShell(persistente: false)
        if let a = annota.appuntamenti.first(where: { $0.clienteId == "marco" && $0.stato == .pianificato }) {
            annota.preparaFascicolo(per: a)
            if let d = annota.documentoProspetto(.fascicolo) {
                annota.presenta(d)
                annota.paginaSeguente()
                annota.annotaPresentazione("Vuole ridurre il rischio")
                let incontro = annota.dati.incontri.first { $0.appuntamentoId == a.id }
                controlla(incontro?.appunti.contains("pagina 2: Vuole ridurre il rischio") == true, "Annotazione: negli appunti dell'incontro dell'appuntamento, con la pagina")
                let prima = annota.dati.attivita.count
                annota.annotaPresentazione("Portare il KID del fondo pensione", comeAttivita: true)
                controlla(annota.dati.attivita.count == prima + 1 && annota.dati.attivita.contains { $0.titolo == "Portare il KID del fondo pensione" && $0.clienteId == "marco" },
                          "Annotazione come attività: tra le cose da fare del cliente")
                controlla(annota.presentazione?.annotazioni == 2 && annota.dati.incontri.filter { $0.appuntamentoId == a.id }.count == 1,
                          "Annotazioni: contate, sempre nello stesso incontro")
                annota.annotaPresentazione("   ")
                controlla(annota.presentazione?.annotazioni == 2, "Annotazione vuota: ignorata")
                controlla(annota.dati.attivita.contains { $0.titolo == "Portare il KID del fondo pensione" && $0.appuntamentoId == a.id },
                          "Annotazione come attività: collegata all'appuntamento")
                annota.chiudiPresentazione()
            }
        }
        // Un fascicolo preparato per Marco non porta le note di un altro cliente nel suo incontro
        let altro = StatoShell(persistente: false)
        if let a = altro.appuntamenti.first(where: { $0.clienteId == "marco" && $0.stato == .pianificato }) {
            altro.preparaFascicolo(per: a)
            altro.clienteAttivoId = "giulia"
            controlla(altro.fascicoloAppuntamento == nil, "Fascicolo: cambiando cliente si scorda l'appuntamento dell'altro")
            altro.fascicoloAppuntamento = a.id
            altro.prospetto = .fascicolo
            if let d = altro.documentoProspetto(.fascicolo) {
                altro.presenta(d)
                altro.annotaPresentazione("Nota di Giulia")
                controlla(!(altro.dati.incontri.first { $0.appuntamentoId == a.id }?.appunti.contains("Nota di Giulia") ?? false)
                          && altro.dati.incontri.contains { $0.clienteId == "giulia" && $0.appunti.contains("Nota di Giulia") },
                          "Annotazione: mai nell'incontro di un altro cliente")
                altro.chiudiPresentazione()
            }
        }
        let cache = StatoShell(persistente: false)
        let primo = cache.analisiDossier("marco")
        controlla(cache.analisiDossier("marco").costi.euroAnno == primo.costi.euroAnno && cache.cacheDossier != nil, "Analisi del dossier: riusate finché i dati non cambiano")
        if let i = cache.dati.posizioni.firstIndex(where: { $0.clienteId == "marco" && $0.area == .investimento }) {
            cache.dati.posizioni[i].costoAnnuo = 3
            controlla(cache.analisiDossier("marco").costi.euroAnno != primo.costi.euroAnno, "Analisi del dossier: ricalcolate quando cambia una posizione")
        }

        // Eve legge il taccuino: le note del cliente nella scheda e nella traccia dell'incontro
        let conNote = StatoShell(persistente: false)
        if let f = conNote.fonteEve("giulia") {
            controlla(ContestoEve.scheda(f).contains("La casa è un nuovo inizio"), "Scheda di Eve: le note del taccuino")
            let traccia = MotoriEve.sintesi.componi(RichiestaEve(domanda: "", spunto: .incontro, fonte: f, storia: []))
            controlla(traccia.testo.contains("Dal tuo taccuino") && traccia.testo.contains("La casa è un nuovo inizio"), "Traccia dell'incontro: le note del taccuino")
        }

        // Note: cambiare il cliente di una nota non apre un'altra nota; i clienti eliminati non lasciano filtri orfani
        let cambio = StatoShell(persistente: false)
        cambio.filtroClienteNote = "giulia"
        if let nuova = cambio.nuovaNota() {
            cambio.modificaNota(nuova.id) { $0.clienteId = "marco" }
            controlla(cambio.filtroClienteNote == "marco" && cambio.notaSelezionata == nuova.id && cambio.noteFiltrate.contains { $0.id == nuova.id },
                      "Note: cambiato il cliente, la nota resta aperta e il filtro la segue")
            cambio.modificaNota(nuova.id) { $0.testo = "Appunto" }
            cambio.modificaNota(nuova.id) { $0.testo = "" }
            cambio.scegliNota("nota-marco")
            controlla(cambio.nota(nuova.id) != nil, "Note: una nota svuotata per riscriverla non sparisce")
        }
        cambio.filtroClienteNote = "laura"
        cambio.eliminaCliente("laura")
        controlla(cambio.filtroClienteNote == nil, "Note: eliminato il cliente, il filtro torna a tutti")
        if let f = cambio.fonteEve("giulia") {
            controlla(ContestoEve.scheda(f).contains("Prossimo passo"), "Scheda di Eve: il testo delle note oltre la prima riga")
        }
        avvisi.dati.impostazioni.backup.ultimoErrore = "Disco esterno non collegato"
        for k in 0..<12 {
            var t = Attivita.nuova(clienteId: "giulia", scadenza: cal.date(byAdding: .day, value: -10 - k, to: giorno) ?? giorno)
            t.titolo = "Vecchia \(k)"
            avvisi.dati.attivita.append(t)
        }
        controlla(MotoreNotifiche.calcola(avvisi, oggi: mattina).first?.id == "backup-errore", "Notifiche: il backup non riuscito resta in cima anche con molte attività scadute")

        // Eve sul portafoglio: le stesse cifre del Portafoglio, una conversazione a parte
        let pf = StatoShell(persistente: false)
        pf.dati.impostazioni.eve.motore = .sintesi
        let quadro = EvePortafoglio.risposta(.quadro, domanda: "", dati: pf.dati)
        let calcolato = EvePortafoglio.portafoglio(pf.dati, oggi: Date())
        controlla(quadro.testo.contains(Formati.euro(calcolato.riepilogo.attivita)), "Eve · portafoglio: il patrimonio seguito come nel Portafoglio")
        controlla(SpuntoPortafoglio.da("chi devo chiamare questa settimana?") == .ricontattare && SpuntoPortafoglio.da("cosa scade a dicembre?") == .scadenze
                  && SpuntoPortafoglio.da("Come vanno le PROPOSTE") == .proposte && SpuntoPortafoglio.da("ciao") == .quadro,
                  "Eve · portafoglio: argomenti delle domande scritte a mano")
        if let primo = calcolato.scadenze.first {
            let m = Calendar.current.component(.month, from: primo.inizio)
            let r = EvePortafoglio.risposta(.scadenze, domanda: "cosa scade a \(EvePortafoglio.mesi[m - 1])?", dati: pf.dati)
            let altri = calcolato.scadenze.filter { Calendar.current.component(.month, from: $0.inizio) != m }.flatMap(\.posizioni)
            controlla(primo.posizioni.allSatisfy { r.testo.contains($0.nome) } && altri.allSatisfy { a in !primo.posizioni.contains { $0.nome == a.nome } ? !r.testo.contains(a.nome) : true },
                      "Eve · portafoglio: le scadenze del mese chiesto, solo quelle")
        }
        pf.dati.appuntamenti.removeAll { $0.clienteId == "laura" }
        pf.dati.incontri.removeAll { $0.clienteId == "laura" }
        controlla(EvePortafoglio.risposta(.ricontattare, domanda: "", dati: pf.dati).testo.contains("Laura Moretti"), "Eve · portafoglio: chi ricontattare")
        controlla(SpuntoPortafoglio.da("quali revisioni devo fare quest'anno?") == .riesami, "Eve · portafoglio: «revisioni» sono i riesami")
        controlla(SpuntoPortafoglio.da("chi può ancora dedurre qualcosa?") == .fineAnno, "Eve · portafoglio: «dedurre» è la fine dell'anno")
        let fine = EvePortafoglio.risposta(.fineAnno, domanda: "", dati: pf.dati)
        controlla(!(fine.titolo ?? "").isEmpty && !fine.testo.isEmpty, "Eve · portafoglio: spazio deducibile entro fine anno (\(fine.titolo ?? ""))")
        let riesami = EvePortafoglio.risposta(.riesami, domanda: "", dati: pf.dati)
        controlla((riesami.titolo ?? "").hasPrefix("Riesami annuali") || (riesami.titolo ?? "").hasPrefix("Nessun riesame"), "Eve · portafoglio: i riesami da fare (\(riesami.titolo ?? ""))")
        // Fissare l'appuntamento toglie il cliente dall'elenco
        if let laura = EvePortafoglio.portafoglio(pf.dati, oggi: Date()).daRicontattare.first(where: { $0.id == "laura" }) {
            let a = pf.bozzaRicontatto(laura)
            controlla(a.clienteId == "laura" && a.tipo == .telefonata && a.inizio > Date() && !Calendar.current.isDateInWeekend(a.inizio),
                      "Da ricontattare: la bozza è una telefonata in un giorno lavorativo")
            pf.salvaAppuntamento(a)
            controlla(!EvePortafoglio.portafoglio(pf.dati, oggi: Date()).daRicontattare.contains { $0.id == "laura" },
                      "Da ricontattare: fissato l'appuntamento, il cliente esce dall'elenco")
        }
        pf.clienteAttivoId = "giulia"
        let primaGiulia = pf.conversazione("giulia").count
        pf.chiediEvePortafoglio("Chi devo ricontattare?")
        controlla(pf.conversazione(EvePortafoglio.chiave).count == 2 && pf.conversazione("giulia").count == primaGiulia,
                  "Eve · portafoglio: domanda e risposta nella conversazione del portafoglio, non in quella del cliente")
        pf.evePortafoglio = true
        pf.nuovaConversazione()
        controlla(pf.conversazione(EvePortafoglio.chiave).isEmpty, "Eve · portafoglio: nuova conversazione")
        controlla(EvePortafoglio.scheda(pf.dati).count <= ContestoEve.limite, "Eve · portafoglio: scheda entro il limite del modello")

        // Voce: il testo parlato è pulito e breve, le impostazioni vecchie si leggono, «basta» chiude
        let parlato = TestoParlato.da(titolo: "Check-up di Marco", testo: "• **Oggi**: € 12.000 → in crescita\n1. Protezione · scoperta\n\nAltro", completo: true)
        controlla(parlato == "Check-up di Marco. Oggi: € 12.000 in crescita. Protezione, scoperta. Altro.", "Voce: testo parlato senza simboli («\(parlato)»)")
        let lungo = String(repeating: "Una frase di prova abbastanza lunga. ", count: 40)
        let breve = TestoParlato.da(titolo: nil, testo: lungo, completo: false)
        controlla(breve.count <= TestoParlato.limite && breve.hasSuffix("."), "Voce: senza «leggi tutto» dice solo l'inizio, a fine frase (\(breve.count) caratteri)")
        controlla(TestoParlato.da(titolo: nil, testo: lungo, completo: true).count > TestoParlato.limite, "Voce: con «leggi tutto» dice tutta la risposta")
        controlla(TestoParlato.da(titolo: "Riepilogo", testo: "Riepilogo del cliente: tutto bene", completo: false) == "Riepilogo del cliente: tutto bene.", "Voce: il titolo non si ripete")
        let congedi: [Bool] = ["Basta così, grazie", "grazie Eve", "Ok, è tutto.", "Basta con i costi alti: cosa propongo?"].map(CongedoEve.e)
        controlla(congedi == [true, true, true, false], "Voce: «basta così» chiude la conversazione, una domanda no")
        let vecchie = (try? JSONDecoder().decode(ImpostazioniEve.self, from: Data(#"{"motore":"sintesi","conservaConversazioni":false}"#.utf8))) ?? ImpostazioniEve()
        let vecchieOk: Bool = vecchie.motore == ImpostazioniEve.Motore.sintesi && !vecchie.conservaConversazioni
            && vecchie.risposteAVoce == ImpostazioniEve.RisposteAVoce.quandoParli && vecchie.voce == nil
            && vecchie.velocitaVoce == 1.0 && vecchie.conversazioneContinua
        controlla(vecchieOk, "Voce: le impostazioni di Eve di prima si leggono con i valori predefiniti della voce")
        let fuori = (try? JSONDecoder().decode(ImpostazioniEve.self, from: Data(#"{"velocitaVoce":9}"#.utf8))) ?? ImpostazioniEve()
        controlla(fuori.velocitaVoce == 1.4, "Voce: una velocità fuori misura torna nei limiti")
        let voci = VoceEve.vociItaliane()
        print("INFO Voci italiane su questo Mac: \(voci.map(VoceEve.nome).joined(separator: ", "))")
        // Una domanda arrivata a voce: la risposta si dice (nelle prove non c'è audio, ma lo stato si chiude bene)
        let v = StatoShell(persistente: false)
        v.dati.impostazioni.eve.motore = .sintesi
        v.fraseDetta("Fammi un riepilogo del cliente")
        let rispostaEve: Bool = v.conversazione(v.clienteAttivoId).last.map { $0.autore == MessaggioEve.Autore.eve } ?? false
        controlla(rispostaEve && !v.rispostaAVoce, "Voce: la frase detta diventa una domanda e la risposta arriva")
        v.fraseDetta("basta così")
        controlla(!v.conversazioneAVoce, "Voce: «basta così» chiude la conversazione a voce")

        // Comandi: Eve capisce cosa fare (martedì 27 ottobre 2026, ore 10)
        let martedi = cal.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 10)) ?? Date()
        func dataProva(_ d: Int, _ m: Int = 10, _ h: Int? = nil, _ min: Int = 0) -> Date? {
            cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: h ?? 0, minute: h == nil ? 0 : min))
        }
        let noti = stato.clienti.map { ClienteNoto(id: $0.id, nome: $0.nome) }
        func capisce(_ frase: String, attivo: String? = "giulia") -> ComandoEve? {
            InterpreteComandi.interpreta(frase, clienti: noti, attivo: attivo, oggi: martedi)
        }
        controlla(capisce("Ok Eve, preparami il report della prova di resistenza per Marco Bianchi") == .documento(.resistenza(report: true), cliente: "marco"),
                  "Comandi: «preparami il report della prova di resistenza per Marco Bianchi»")
        controlla(capisce("mi prepari il prospetto dei costi per favore") == .documento(.costi(report: false), cliente: nil), "Comandi: «mi prepari il prospetto dei costi» (cliente aperto)")
        controlla(capisce("Fammi il fascicolo per l'incontro con Laura") == .documento(.fascicolo, cliente: "laura"), "Comandi: il fascicolo per l'incontro con Laura")
        if case .chiedi? = capisce("preparami un report") {
            controlla(true, "Comandi: «preparami un report» senza dire quale: Eve chiede")
        } else {
            controlla(false, "Comandi: «preparami un report» senza dire quale: Eve chiede")
        }
        controlla(capisce("Fissa un appuntamento con Giulia giovedì alle 15")
                  == .appuntamento(.init(cliente: "giulia", giorno: dataProva(29), ora: 15, minuti: 0, tipo: .altro, titolo: "")),
                  "Comandi: «fissa un appuntamento con Giulia giovedì alle 15»")
        controlla(capisce("metti una telefonata con Laura domani alle tre e mezza")
                  == .appuntamento(.init(cliente: "laura", giorno: dataProva(28), ora: 15, minuti: 30, tipo: .telefonata, titolo: "")),
                  "Comandi: «una telefonata con Laura domani alle tre e mezza»")
        controlla(capisce("Ricordami di chiamare Laura venerdì") == .attivita(cliente: "laura", titolo: "Chiamare Laura", scadenza: dataProva(30)!),
                  "Comandi: «ricordami di chiamare Laura venerdì» (\(String(describing: capisce("Ricordami di chiamare Laura venerdì"))))")
        controlla(capisce("ricordami di mandare il KID il 3 novembre") == .attivita(cliente: "giulia", titolo: "Mandare il KID", scadenza: dataProva(3, 11)!),
                  "Comandi: «ricordami di mandare il KID il 3 novembre»")
        controlla(capisce("Prendi nota che Marco vuole cambiare casa nel 2028") == .nota(cliente: "marco", testo: "Marco vuole cambiare casa nel 2028"),
                  "Comandi: «prendi nota che Marco vuole cambiare casa nel 2028»")
        controlla(capisce("Apri l'agenda") == .apri(.agenda) && capisce("vai alle posizioni") == .apri(.posizioni), "Comandi: apri l'agenda, vai alle posizioni")
        controlla(capisce("passa a Sofia") == .cliente("sofia") && capisce("apri Marco Bianchi") == .cliente("marco"), "Comandi: passa a Sofia, apri Marco Bianchi")
        controlla(capisce("cosa ho domani?") == .agenda(dataProva(28)!), "Comandi: «cosa ho domani?»")
        controlla(capisce("preparami il report della liquidità sui conti correnti") == .documento(.liquidita(report: true), cliente: nil),
                  "Comandi: «i conti correnti» non è il cliente Andrea Conti")
        for domanda in ["Cosa proporre al cliente?", "Quanto pesano i costi?", "Fammi un riepilogo del cliente", "Prepara il prossimo incontro",
                        "Conviene restare o cambiare?", "Come stanno andando le posizioni di Marco?"] {
            controlla(capisce(domanda) == nil, "Comandi: «\(domanda)» resta una domanda per Eve")
        }
        let quando = DateItaliane.trova("il 3 novembre alle 10:30", oggi: martedi)
        controlla(quando.data() == dataProva(3, 11, 10, 30), "Date: «il 3 novembre alle 10:30»")
        controlla(DateItaliane.trova("tra due settimane", oggi: martedi).giorno == dataProva(10, 11), "Date: «tra due settimane»")
        controlla(DateItaliane.trova("martedì prossimo alle 9", oggi: martedi).data() == dataProva(3, 11, 9), "Date: «martedì prossimo» dal martedì è la settimana dopo")
        controlla(DateItaliane.trova("a mezzogiorno", oggi: martedi).data() == dataProva(27, 10, 12), "Date: «a mezzogiorno» di oggi")

        // Comandi eseguiti: l'appuntamento senza giorno si completa con la frase dopo, e si annulla
        let e = StatoShell(persistente: false)
        e.dati.impostazioni.eve.motore = .sintesi
        e.clienteAttivoId = "giulia"
        let appuntamentiPrima = e.dati.appuntamenti.count
        let chiesto = e.eseguiComandoEve("fissa un incontro con Marco Bianchi", oggi: martedi)
        let domandaQuando = e.conversazione("giulia").last?.testo ?? ""
        controlla(chiesto && e.appuntamentoInSospeso != nil && domandaQuando.hasPrefix("Per quando"), "Eseguiti: l'incontro senza giorno, Eve chiede per quando")
        let completato = e.eseguiComandoEve("giovedì alle 11", oggi: martedi)
        controlla(completato && e.dati.appuntamenti.count == appuntamentiPrima + 1, "Eseguiti: «giovedì alle 11» completa l'appuntamento")
        let fissato = e.dati.appuntamenti.last
        let fissatoOk: Bool = fissato.map { $0.clienteId == "marco" && $0.inizio == dataProva(29, 10, 11) && $0.titolo == "Incontro con Marco Bianchi" } ?? false
        controlla(fissatoOk, "Eseguiti: incontro con Marco Bianchi giovedì 29 alle 11 (\(fissato?.titolo ?? "-"))")
        if let m = e.conversazione("giulia").last, let a = m.azione {
            controlla(a.tipo == .appuntamento && m.testo.contains("giovedì 29 ottobre alle 11:00"), "Eseguiti: la risposta dice quando («\(m.testo)»)")
            e.annullaAzioneEve(a, messaggio: m.id)
            let annullata: Bool = e.conversazione("giulia").last?.azione?.annullata ?? false
            controlla(e.dati.appuntamenti.count == appuntamentiPrima && annullata, "Eseguiti: annullato, l'appuntamento sparisce")
        } else {
            controlla(false, "Eseguiti: la risposta porta l'appuntamento da aprire o annullare")
        }
        let attivitaPrima = e.dati.attivita.count
        let promemoria = e.eseguiComandoEve("ricordami di mandare il KID a Giulia domani", oggi: martedi)
        let nuova = e.dati.attivita.count == attivitaPrima + 1 ? e.dati.attivita.last : nil
        let promemoriaOk: Bool = promemoria && nuova.map { $0.titolo == "Mandare il KID a Giulia" && $0.scadenza == dataProva(28) } ?? false
        controlla(promemoriaOk, "Eseguiti: promemoria «Mandare il KID a Giulia» per domani")
        let notePrima = e.dati.note.count
        let annotato = e.eseguiComandoEve("prendi nota: vuole aumentare il versamento del PIP", oggi: martedi)
        let notaOk: Bool = annotato && e.dati.note.count == notePrima + 1 && (e.dati.note.last?.clienteId ?? "") == "giulia"
        controlla(notaOk, "Eseguiti: la nota va nel taccuino di Giulia")
        let preparato = e.eseguiComandoEve("Ok Eve, preparami il report del patrimonio di Marco", oggi: martedi)
        let reportOk: Bool = preparato && e.prospetto == SceltaProspetto.patrimonio(report: true) && e.clienteAttivoId == "marco"
        controlla(reportOk && e.aperta(.presentazioni), "Eseguiti: il report del patrimonio di Marco aperto in Prospetti e report")
        e.chiediEve("Apri l'agenda")
        controlla(e.aperta(.agenda), "Eseguiti: «apri l'agenda» dalla conversazione")
        controlla(!e.eseguiComandoEve("Quanto pesano i costi?", oggi: martedi), "Eseguiti: una domanda passa a Eve")
        e.entraModoCliente()
        _ = e.eseguiComandoEve("passa a Sofia", oggi: martedi)
        _ = e.eseguiComandoEve("preparami il report dei costi di Giulia Rossi", oggi: martedi)
        controlla(e.clienteAttivoId == "marco", "Eseguiti: in modalità cliente Eve resta sul cliente davanti a te")

        // Qwen sul Mac: solo indirizzi locali, risposte di Ollama lette bene, scelta del motore
        let locali: [Bool] = ["http://127.0.0.1:11434", "http://localhost:11434", "http://192.168.1.20:11434", "https://ollama.example.com"]
            .map { MotoreLocale.indirizzoLocale($0) != nil }
        controlla(locali == [true, true, false, false], "Qwen: Prisma parla solo con il Mac stesso (127.0.0.1), mai con un altro computer")
        let elenco: [String] = MotoreLocale.modelli(Data(#"{"models":[{"name":"qwen3:4b","size":1},{"name":"llama3"}]}"#.utf8))
        controlla(elenco == ["qwen3:4b", "llama3"] && MotoreLocale.stessoModello("qwen3", "qwen3:latest") && !MotoreLocale.stessoModello("qwen3:4b", "qwen3:8b"),
                  "Qwen: elenco dei modelli di Ollama")
        controlla(MotoreLocale.testo(Data(#"{"message":{"role":"assistant","content":"<think>ragiono</think>\n**Ciao**, tutto bene."},"done":true}"#.utf8)) == "Ciao, tutto bene.",
                  "Qwen: la risposta senza il ragionamento e senza markdown")
        let corpo = MotoreLocale.corpo(modello: "qwen3:4b", messaggi: [("system", "a"), ("user", "b")])
        let pensa: Bool = (corpo["think"] as? Bool) ?? true
        let flusso: Bool = (corpo["stream"] as? Bool) ?? true
        let quanti: Int = (corpo["messages"] as? [[String: String]])?.count ?? 0
        controlla(!pensa && !flusso && quanti == 2, "Qwen: richiesta senza ragionamento e senza flusso")
        var qwen = ImpostazioniEve()
        qwen.motore = .locale
        let sceltoPronto: String = MotoriEve.generativo(qwen, locale: .pronto)?.nome ?? ""
        let sceltoAssente = MotoriEve.generativo(qwen, locale: .nonDisponibile("no")) == nil
        let ripiego = MotoriEve.scelto(qwen, locale: .nonDisponibile("no")) is MotoreSintesi
        controlla(sceltoPronto == "Qwen sul Mac" && sceltoAssente && ripiego, "Qwen: scelto se è pronto, altrimenti la sintesi")
        if MotoriEve.apple?.disponibilita.pronto != true {
            qwen.motore = .automatico
            controlla(MotoriEve.generativo(qwen, locale: .pronto)?.nome == "Qwen sul Mac", "Qwen: in automatico, senza il modello Apple risponde Qwen")
        }
        var lontano = ImpostazioniEve()
        lontano.indirizzoLocale = "http://10.0.0.5:11434"
        let attesa = DispatchSemaphore(value: 0)
        final class Esito: @unchecked Sendable { var d = DisponibilitaEve.pronto }
        let esito = Esito()
        let altroComputer = lontano
        Task.detached {
            esito.d = await MotoreLocale.verifica(altroComputer)
            let qui = await MotoreLocale.verifica(ImpostazioniEve())
            print("INFO Qwen sul Mac (Ollama) su questo server: \(qui.motivo ?? "pronto")")
            attesa.signal()
        }
        attesa.wait()
        controlla(!esito.d.pronto && (esito.d.motivo ?? "").contains("127.0.0.1"), "Qwen: un indirizzo di un altro computer è rifiutato senza collegarsi")
        let vecchieQwen = try? JSONDecoder().decode(ImpostazioniEve.self, from: Data(#"{"motore":"apple"}"#.utf8))
        let qwenPrima = vecchieQwen ?? ImpostazioniEve()
        controlla(qwenPrima.modelloLocale == "qwen3:4b" && qwenPrima.indirizzoLocale == "http://127.0.0.1:11434", "Qwen: impostazioni di prima con i valori predefiniti")

        // Ascolto e voce con riconoscimento e microfono finti: tempi brevi, niente audio
        func attendi(_ secondi: TimeInterval, finche condizione: () -> Bool = { false }) {
            let fine = Date().addingTimeInterval(secondi)
            while !condizione() && Date() < fine { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        }
        let tempiBrevi = AscoltoEve.Tempi(pausa: 0.2, attesaMassima: 2, durataMassima: 5, attesaFinale: 1.5, attesaPreparazione: 1, attesaScaricamento: 2)

        // Ascolto 1: lo stato «si prepara», la pausa che aspetta il riconoscimento, il testo arrivato tardi
        let mic1 = MicrofonoFinto(), finta1 = TrascrizioneFinta()
        finta1.risposta = "che appuntamenti ho domani"
        finta1.ritardo = 0.3
        let a1 = AscoltoEve(prepara: { _, _ in .success(finta1) }, microfono: mic1, permessi: { $0(nil) })
        a1.tempi = tempiBrevi
        var frase1: String?
        var problema1: String?
        a1.concluso = { frase1 = $0 }
        a1.problema = { problema1 = $0 }
        a1.avvia(.automatico)
        controlla(a1.siPrepara, "Ascolto: prima del microfono lo stato è «si prepara»")
        attendi(1) { mic1.acceso }
        controlla(mic1.acceso && a1.stato == .ascolta, "Ascolto: microfono acceso dopo la preparazione")
        mic1.suona(0.5); attendi(0.1)
        mic1.suona(0); attendi(0.3); mic1.suona(0); attendi(0.05)
        controlla(a1.stato == .ascolta, "Ascolto: senza risposte la pausa breve non chiude la frase")
        attendi(0.5); mic1.suona(0); attendi(0.05)
        controlla(a1.stato == .capisce && finta1.finita, "Ascolto: alla pausa lunga chiede il testo definitivo")
        attendi(2) { frase1 != nil }
        controlla(frase1 == "che appuntamenti ho domani" && problema1 == nil && a1.stato == .fermo, "Ascolto: il testo arrivato dopo la pausa viene mandato")

        // Ascolto 2: riconoscimento muto
        let mic2 = MicrofonoFinto(), finta2 = TrascrizioneFinta()
        let a2 = AscoltoEve(prepara: { _, _ in .success(finta2) }, microfono: mic2, permessi: { $0(nil) })
        a2.tempi = tempiBrevi
        var problema2: String?
        a2.problema = { problema2 = $0 }
        a2.avvia(.nuovo)
        attendi(1) { mic2.acceso }
        mic2.suona(0.5); attendi(0.1)
        a2.ferma(invia: true)   // come il pulsante
        attendi(3) { problema2 != nil }
        controlla((problema2 ?? "").hasPrefix("Ti ho sentito ma") && a2.fallimento == .senzaParole && finta2.annullata,
                  "Ascolto: riconoscimento muto → «ti ho sentito ma…» dopo l'attesa finale")

        // Ascolto 3: preparazione che non torna
        let mic3 = MicrofonoFinto()
        let a3 = AscoltoEve(prepara: { _, _ in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            return .failure(ErroreEve(messaggio: "troppo tardi"))
        }, microfono: mic3, permessi: { $0(nil) })
        a3.tempi = tempiBrevi
        var problema3: String?
        a3.problema = { problema3 = $0 }
        a3.avvia(.automatico)
        attendi(2.5) { problema3 != nil }
        controlla(a3.fallimento == .nonPronto && !mic3.acceso && (problema3 ?? "").hasPrefix("Il riconoscimento non è pronto"),
                  "Ascolto: se il riconoscimento non è pronto in tempo lo si dice, senza accendere il microfono")

        // Ascolto 4: il pulsante durante la preparazione annulla e basta
        let a4 = AscoltoEve(prepara: { _, _ in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return .success(TrascrizioneFinta())
        }, microfono: MicrofonoFinto(), permessi: { $0(nil) })
        var problema4: String?
        a4.problema = { problema4 = $0 }
        a4.avvia()
        attendi(0.1)
        a4.ferma(invia: true)
        controlla(a4.stato == .fermo && problema4 == nil, "Ascolto: il pulsante durante la preparazione annulla senza parlare di microfono")

        // Ascolto 5: microfono che non si accende → la riga rossa resta
        let mic5 = MicrofonoFinto()
        mic5.guasto = "Il microfono non si è avviato: prova"
        let a5 = AscoltoEve(prepara: { _, _ in .success(TrascrizioneFinta()) }, microfono: mic5, permessi: { $0(nil) })
        var problema5: String?
        a5.problema = { problema5 = $0 }
        a5.avvia()
        attendi(1) { problema5 != nil }
        controlla(a5.stato == .nonDisponibile(mic5.guasto ?? "") && a5.fallimento == .microfono, "Ascolto: microfono guasto → stato «non disponibile» con il motivo")

        // Voce: le frasi vecchie non spengono quella nuova; con niente da dire «finito» parte comunque
        let voce = VoceEve(muta: true)
        var finiti = 0
        voce.finito = { finiti += 1 }
        voce.di("Ciao, sono Eve.", voce: nil, velocita: 1)
        voce.speechSynthesizer(AVSpeechSynthesizer(), didCancel: AVSpeechUtterance(string: "vecchia"))
        attendi(0.05)
        controlla(voce.parla && finiti == 0, "Voce: l'annullamento di una frase vecchia non spegne quella nuova")
        if let c = voce.corrente { voce.speechSynthesizer(AVSpeechSynthesizer(), didFinish: c) }
        attendi(0.05)
        controlla(!voce.parla && finiti == 1, "Voce: la fine della frase corrente spegne «parla» e chiama «finito»")
        voce.di("", voce: nil, velocita: 1)
        attendi(0.05)
        controlla(finiti == 2, "Voce: con niente da dire «finito» parte comunque")

        // Dettatura e domande: inviare spegne la dettatura, i comandi contano come domande partite
        let d = StatoShell(persistente: false)
        d.dati.impostazioni.eve.motore = .sintesi
        d.dettaturaAttiva = true
        controlla(d.chiediEve("Fammi un riepilogo del cliente") && !d.dettaturaAttiva, "Dettatura: inviare da tastiera la spegne e la domanda parte")
        controlla(!d.chiediEve("   "), "Eve: una domanda vuota non parte")
        d.dettaturaAttiva = true
        d.dettaturaNonPartita()
        let titoloNonPartita: String = d.conversazione(d.clienteAttivoId).last?.titolo ?? ""
        controlla(!d.dettaturaAttiva && !d.usaDettatura && titoloNonPartita == "La dettatura del Mac non è partita",
                  "Dettatura: se non parte, Eve lo scrive subito")
        d.clienteAttivoId = "giulia"
        controlla(d.chiediEve("parliamo di Marco Bianchi") && d.clienteAttivoId == "marco", "Eve: un comando che cambia cliente conta come domanda partita")
        d.ripiegoAscolto = .classico
        d.usaDettatura = true
        d.azzeraRipieghiAscolto()
        controlla(d.ripiegoAscolto == nil && !d.usaDettatura, "Ascolto: cambiare riconoscimento azzera i ripieghi")
        controlla(SceltaRiconoscimento.catenaAutomatica.last == .classico, "Ascolto: la catena automatica finisce con la dettatura classica")
        let scelteVecchie = (try? JSONDecoder().decode(ImpostazioniEve.self, from: Data(#"{"riconoscimento":"sconosciuto"}"#.utf8))) ?? ImpostazioniEve()
        controlla(scelteVecchie.riconoscimento == .automatico && !scelteVecchie.mostraPassaggiVoce, "Impostazioni: un riconoscimento sconosciuto torna ad automatico")

        // Diagnostica: tempi, ambiente, impostazioni
        DiagnosticaVoce.inizia("Prova diagnostica")
        DiagnosticaVoce.annota("seconda riga")
        let riepilogo = DiagnosticaVoce.riepilogo(d.dati.impostazioni.eve)
        let testoDiagnostica = DiagnosticaVoce.testo
        controlla(testoDiagnostica.contains("+ 0.") && testoDiagnostica.contains("seconda riga") && riepilogo.contains("riconoscimento automatico") && riepilogo.contains("Permessi"),
                  "Voce: la diagnostica riporta i tempi dei passaggi, l'ambiente e le impostazioni")

        // Prova del riconoscimento: finisce sempre con un esito, anche se la voce non chiude
        let provaDettatura = ProvaRiconoscimento()
        var esitoDettatura: String?
        provaDettatura.esegui(.dettatura) { esitoDettatura = $0 }
        attendi(ProvaRiconoscimento.attesaVoce + 10) { esitoDettatura != nil }
        controlla((esitoDettatura ?? "").contains("non si prova qui"), "Prova del riconoscimento: dà sempre un esito (\(esitoDettatura ?? "nessuno"))")

        // Prova del riconoscimento senza microfono (sul server di build solo informativa: niente permessi)
        let provaVoce = ProvaRiconoscimento()
        var esitoVoce: String?
        provaVoce.esegui(.classico) { esitoVoce = $0 }
        let scadenza = Date().addingTimeInterval(50)
        while esitoVoce == nil && Date() < scadenza { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
        print("INFO Prova del riconoscimento sul server: \(esitoVoce ?? "nessun esito in 50 secondi")")
        let diagnostica = DiagnosticaVoce.testo
        controlla(diagnostica.hasPrefix("Prisma · diagnostica dell'ascolto"), "Voce: la diagnostica dell'ascolto si può copiare")

        print("INFO Modello Apple su questo Mac: \(MotoriEve.motivoAppleNonDisponibile ?? "disponibile")")
        if errori == 0 {
            print("OK: Eve verificata")
            return 0
        }
        print("ERRORE: \(errori) verifiche di Eve non riuscite")
        return 1
    }

    /// Excel letto direttamente, righe incollate, clienti nuovi creati con le posizioni, schede prodotto collegate.
    static func provaImportazioniRapide(_ stato: StatoShell) -> [(Bool, String)] {
        var esiti: [(Bool, String)] = []
        func controlla(_ ok: Bool, _ d: String) { esiti.append((ok, d)) }

        // Il foglio di un .xlsx: stringhe condivise, celle vuote saltate, numeri e date di Excel
        let condivise = """
        <?xml version="1.0" encoding="UTF-8"?><sst xmlns="x"><si><t>Contraente</t></si><si><t>Prodotto</t></si><si><t>Premio</t></si>\
        <si><t>Decorrenza</t></si><si><r><t>Mario </t></r><r><t>Nuovo</t></r></si><si><t>Piano Alleanza Futuro</t></si></sst>
        """
        let foglio = """
        <?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="x"><sheetData>\
        <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="E1" t="s"><v>3</v></c></row>\
        <row r="2"><c r="A2" t="s"><v>4</v></c><c r="B2" t="s"><v>5</v></c><c r="C2"><v>1234.5</v></c><c r="E2"><v>45292</v></c></row>\
        </sheetData></worksheet>
        """
        let lette = FoglioExcel.righe(foglioXML: Data(foglio.utf8), condivisi: FoglioExcel.stringheCondivise(Data(condivise.utf8)))
        controlla(lette.count == 2 && lette[1] == ["Mario Nuovo", "Piano Alleanza Futuro", "1234,5", "", "45292"],
                  "Excel: celle, stringhe condivise a pezzi, colonna vuota, numero con la virgola (\(lette))")
        let data = ImportaClienti.data("45292")
        let giorno = data.map { Calendar.current.dateComponents([.year, .month, .day], from: $0) }
        controlla(giorno?.year == 2024 && giorno?.month == 1 && giorno?.day == 1,
                  "Excel: data come numero di serie (45292 = 1° gennaio 2024)")
        controlla(ImportaClienti.data("1985") == nil && FoglioExcel.colonna("AB12") == 27, "Excel: un anno da solo non è una data; colonna AB = 27")

        // Un .xlsx vero, compresso con zip e riletto con unzip
        let cartella = FileManager.default.temporaryDirectory.appendingPathComponent("prova-xlsx-\(UUID().uuidString)")
        let fm = FileManager.default
        try? fm.createDirectory(at: cartella.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: cartella.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try? Data(foglio.utf8).write(to: cartella.appendingPathComponent("xl/worksheets/foglio.xml"))
        try? Data(condivise.utf8).write(to: cartella.appendingPathComponent("xl/sharedStrings.xml"))
        try? Data(#"<workbook xmlns:r="r"><sheets><sheet name="Polizze" sheetId="1" r:id="rId7"/></sheets></workbook>"#.utf8)
            .write(to: cartella.appendingPathComponent("xl/workbook.xml"))
        try? Data(#"<Relationships><Relationship Id="rId7" Target="worksheets/foglio.xml"/></Relationships>"#.utf8)
            .write(to: cartella.appendingPathComponent("xl/_rels/workbook.xml.rels"))
        let file = cartella.appendingPathComponent("polizze.xlsx")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = cartella
        zip.arguments = ["-q", "-r", file.path, "xl"]
        try? zip.run()
        zip.waitUntilExit()
        let daFile = FoglioExcel.righe(file)
        controlla(daFile?.count == 2 && daFile?.last?.first == "Mario Nuovo", "Excel: .xlsx aperto senza Excel, primo foglio dalle relazioni (\(daFile ?? []))")

        // Le stesse righe come posizioni: cliente nuovo, scheda prodotto collegata, premio e data
        var scheda = Prodotto(nome: "Piano Alleanza Futuro", canale: .alleanza, area: .risparmio)
        scheda.costoAnnuo = 1.4
        scheda.sri = 2
        scheda.tipologia = "Polizza rivalutabile (Ramo I)"
        if let righe = daFile {
            let pos = ImportaPosizioni.daRighe(righe, clienti: stato.clienti, posizioni: stato.posizioni, prodotti: [scheda], canale: .indipendente).posizioni
            let p = pos.first?.posizione
            controlla(pos.count == 1 && pos[0].nuovoCliente?.nome == "Mario Nuovo" && pos[0].prodotto == scheda.nome
                      && p?.canale == .alleanza && p?.area == .risparmio && p?.costoAnnuo == 1.4 && p?.sri == 2 && p?.prodottoId == scheda.id
                      && p?.premio == 1_234.5 && p?.decorrenza != nil,
                      "Importa posizioni da Excel: cliente nuovo, canale e costi dalla scheda prodotto, premio e decorrenza")
            controlla(ImportaPosizioni.sembraPosizioni(righe) && !ImportaPosizioni.sembraPosizioni([["Nome", "Cognome", "Email"]]),
                      "Trascina: una tabella con il prodotto va in Posizioni, una di contatti in Clienti")
        }
        try? fm.removeItem(at: cartella)

        // Righe incollate da Excel (tabulazioni): due polizze dello stesso cliente nuovo → un solo cliente
        let appunti = "Cliente\tCodice fiscale\tProdotto\tN. polizza\tControvalore\n"
            + "Bruno Fittizio\tFTTBRN70A01H501Z\tPiano Alleanza Futuro\tAF-1\t5.000,00\n"
            + "Fittizio Bruno\tFTTBRN70A01H501Z\tTemporanea caso morte\tAF-2\t\n"
        if let incollate = ImportaPosizioni.incollate(appunti, clienti: stato.clienti, posizioni: stato.posizioni, prodotti: [scheda]) {
            let nuovi = Dictionary(incollate.posizioni.compactMap { x in x.nuovoCliente.map { (ImportaPosizioni.segnapostoNuovo($0), $0) } },
                                   uniquingKeysWith: { a, _ in a })
            let elenco = incollate.posizioni.map { x -> Posizione in
                var p = x.posizione
                if let n = x.nuovoCliente { p.clienteId = ImportaPosizioni.segnapostoNuovo(n) }
                return p
            }
            let clientiPrima = stato.clienti.count
            let posizioniPrima = stato.posizioni.count
            let creati = stato.aggiungiPosizioniImportate(elenco, nuoviClienti: nuovi)
            let bruno = stato.clienti.first { $0.codiceFiscale == "FTTBRN70A01H501Z" }
            controlla(incollate.file == "appunti" && creati == 1 && stato.clienti.count == clientiPrima + 1 && stato.posizioni.count == posizioniPrima + 2
                      && bruno.map { b in stato.posizioni.filter { $0.clienteId == b.id }.count } == 2,
                      "Incolla da Excel: due polizze, un solo cliente nuovo con il codice fiscale, posizioni collegate a lui")
            if let b = bruno {
                stato.dati.posizioni.removeAll { $0.clienteId == b.id }
                stato.dati.clienti.removeAll { $0.id == b.id }
            }
        } else {
            controlla(false, "Incolla da Excel: righe a tabulazioni lette")
        }
        let contatti = ImportaClienti.incollati("Nome\tCognome\tEmail\nCarla\tProva\tcarla@example.it\n", rubrica: stato.clienti)
        controlla(contatti?.clienti.first?.nome == "Carla Prova" && contatti?.clienti.first?.email == "carla@example.it",
                  "Incolla da Excel: righe di contatti in Clienti")
        return esiti
    }
}

// MARK: - Finti per le prove dell'ascolto

/// Un riconoscimento che risponde a comando: dopo `finisci` consegna `risposta` con `ritardo` (nil: resta muto).
private final class TrascrizioneFinta: TrascrizioneEve {
    let nome = "riconoscimento finto"
    let scelta = SceltaRiconoscimento.classico
    var aggiornamento: ((String?, Bool, String?) -> Void)?
    var pezzi = 0
    var finita = false
    var annullata = false
    var risposta: String?
    var ritardo: TimeInterval = 0

    func aggiungi(_ buffer: AVAudioPCMBuffer) { pezzi += 1 }

    func finisci() {
        finita = true
        guard let r = risposta else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + ritardo) { [weak self] in
            self?.aggiornamento?(r, false, nil)
            self?.aggiornamento?(nil, true, nil)
        }
    }

    func annulla() { annullata = true }
}

/// Un microfono senza audio: `suona` manda un picco come farebbe il tap.
private final class MicrofonoFinto: MicrofonoEve {
    var acceso = false
    var guasto: String?
    private var livello: ((Float) -> Void)?

    func accendi(consegna: @escaping (AVAudioPCMBuffer) -> Void, livello: @escaping (Float) -> Void) -> String? {
        if let guasto { return guasto }
        acceso = true
        self.livello = livello
        return nil
    }

    func spegni() { acceso = false }
    func suona(_ picco: Float) { livello?(picco) }
}
