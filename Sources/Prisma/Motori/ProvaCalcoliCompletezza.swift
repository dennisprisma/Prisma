import Foundation

/// Prove della completezza dei dati per l'analisi (specifica 7, casi C1–C18): punteggio, livello, ordine,
/// voci del cliente e delle posizioni, dati non pertinenti, ipotesi per documento, lettura tollerante.
/// Chiamata da `ProvaCalcoli.esegui()` dopo `ProvaCalcoliMultiramo`: gli errori si sommano.
enum ProvaCalcoliCompletezza {
    static func esegui(_ verifica: VerificaCalcoli) {
        let oggi = AiutiProva.oggi
        let cal = Calendar.current
        func mesi(_ n: Int) -> Date { cal.date(byAdding: .month, value: n, to: oggi) ?? oggi }
        func calcola(_ c: Cliente, _ p: [Posizione] = [], _ a: Analisi360? = nil) -> CompletezzaCliente {
            MotoreCompletezza.calcola(cliente: c, posizioni: p, analisi: a, oggi: oggi)
        }
        func voce(_ k: CompletezzaCliente, _ id: String) -> VoceCompletezza? { k.voci.first { $0.id == id } }

        let vuoto = Cliente(id: "prova", nome: "Prova Vuota", iniziali: "PV", tinta: .blu, tema: "", email: "", telefono: "",
                            preferito: false, nota: "", creatoIl: oggi)
        var completo = vuoto
        completo.nome = "Prova Completa"
        completo.dataNascita = AiutiProva.data(1980, 5, 10)
        completo.statoCivile = .coniugato
        completo.profilo.redditoLordoAnnuo = 40_000
        completo.profilo.redditoNettoAnnuo = 28_000
        completo.profilo.lavoro = DatiLavoro(tipo: .dipendente, redditoLavoro: 40_000, anniContributi: 20,
                                             annoPrimoContributo: 2006, montanteContributivo: 200_000)
        completo.profilo.propensione = .moderata
        completo.profilo.aggiornatoIl = mesi(-5)
        completo.profilo.orizzonteAnni = 10
        var confermata = Analisi360()
        confermata.confermate = [.previdenza, .protezione]

        let etf = AiutiProva.posizione("ETF prova", .investimento, 10_000) { $0.tipologia = "ETF" }
        var etfCompleto = etf
        etfCompleto.dataValore = mesi(-3)
        etfCompleto.costoAnnuo = 0.2
        etfCompleto.sri = 4
        etfCompleto.rendimentoAtteso = 5

        // C1. Cliente vuoto, senza posizioni né analisi: pesi 3+1+3+2+3+2+2+2 = 18, crediti 0,5 × 9 = 4,5
        let c1 = calcola(vuoto)
        verifica("C1 Completezza: cliente vuoto al 25% (4,5 / 18)", Double(c1.percentuale), 25)
        verifica.vero("C1 Completezza: livello «Da completare»", c1.livello == .scarso)
        verifica("C1 Completezza: 4 mancano", Double(c1.mancanti), 4)
        verifica("C1 Completezza: 4 stimati", Double(c1.stimati), 4)
        verifica("C1 Completezza: nessuno da aggiornare", Double(c1.daAggiornare), 0)

        // C2. Ordine: prima i mancanti, poi il peso, poi il titolo
        verifica.vero("C2 Completezza: ordine delle voci da completare",
                      c1.daCompletare.map(\.id) == ["nascita", "redditoLordo", "lavoro", "statoCivile", "fabbisogno",
                                                     "pensionePubblica", "redditoDesiderato", "redditoNetto"])

        // C3. Con un ETF senza data del valore, costi, SRI e rendimento: 6 / 27
        let c3 = calcola(vuoto, [etf])
        verifica("C3 Completezza: con un ETF nudo al 22% (6 / 27)", Double(c3.percentuale), 22)
        verifica("C3 Completezza: 7 mancano", Double(c3.mancanti), 7)
        verifica("C3 Completezza: 1 da aggiornare", Double(c3.daAggiornare), 1)
        verifica("C3 Completezza: 6 stimati", Double(c3.stimati), 6)
        verifica.vero("C3 Completezza: i costi dell'ETF portano il suo canale", voce(c3, "costi:\(etf.id)")?.canale == .indipendente)

        // C4. Tutto completo, analisi confermata
        let c4 = calcola(completo, [etfCompleto], confermata)
        verifica("C4 Completezza: tutto completo al 100%", Double(c4.percentuale), 100)
        verifica.vero("C4 Completezza: livello «Dati completi»", c4.livello == .completo)
        verifica.vero("C4 Completezza: niente da completare", c4.daCompletare.isEmpty)

        // C5. Senza l'analisi salvata: fabbisogno, reddito desiderato e pensione stimati (23,5 / 27)
        let c5 = calcola(completo, [etfCompleto])
        verifica("C5 Completezza: senza analisi salvata all'87%", Double(c5.percentuale), 87)
        verifica.vero("C5 Completezza: livello «Quasi completi»", c5.livello == .parziale)

        // C6. Valore dell'ETF vecchio di 13 mesi / di 11 mesi
        do {
            var vecchio = etfCompleto
            vecchio.dataValore = mesi(-13)
            let k = calcola(completo, [vecchio], confermata)
            verifica("C6 Completezza: valore di 13 mesi fa al 98%", Double(k.percentuale), 98)
            verifica.vero("C6 Completezza: valore da aggiornare", voce(k, "valore:\(vecchio.id)")?.stato == .daAggiornare)
            vecchio.dataValore = mesi(-11)
            verifica("C6 Completezza: valore di 11 mesi fa al 100%", Double(calcola(completo, [vecchio], confermata).percentuale), 100)
        }

        // C7. Profilo aggiornato 25 mesi fa / 23 mesi fa
        do {
            var c = completo
            c.profilo.aggiornatoIl = mesi(-25)
            let k = calcola(c, [etfCompleto], confermata)
            verifica("C7 Completezza: profilo di 25 mesi fa al 94%", Double(k.percentuale), 94)
            verifica.vero("C7 Completezza: ancora «Dati completi»", k.livello == .completo)
            c.profilo.aggiornatoIl = mesi(-23)
            verifica("C7 Completezza: profilo di 23 mesi fa al 100%", Double(calcola(c, [etfCompleto], confermata).percentuale), 100)
        }

        // C8. Lavoro segnato «non pertinente»: fuori dal punteggio (4,5 / 16)
        do {
            var c = vuoto
            c.datiNonPertinenti = ["lavoro": oggi]
            let k = calcola(c)
            verifica("C8 Completezza: lavoro non pertinente al 28%", Double(k.percentuale), 28)
            verifica("C8 Completezza: una voce esclusa", Double(k.escluse.count), 1)
            verifica.vero("C8 Completezza: il lavoro non è tra le voci", voce(k, "lavoro") == nil)
        }

        // C9. Con una TCM in essere senza beneficiari (30 / 32), poi con i beneficiari
        do {
            var tcm = AiutiProva.posizione("TCM prova", .protezione, 0) {
                $0.rischio = .vita
                $0.capitaleAssicurato = 150_000
                $0.scadenza = cal.date(byAdding: .year, value: 10, to: oggi)
                $0.beneficiari = ""
            }
            let k = calcola(completo, [etfCompleto, tcm], confermata)
            verifica("C9 Completezza: TCM senza beneficiari al 94%", Double(k.percentuale), 94)
            verifica.vero("C9 Completezza: beneficiari mancanti", voce(k, "beneficiari:\(tcm.id)")?.stato == .mancante)
            tcm.beneficiari = "Coniuge"
            verifica("C9 Completezza: con i beneficiari al 100%", Double(calcola(completo, [etfCompleto, tcm], confermata).percentuale), 100)
        }

        // C10. Settant'anni: la previdenza non è più pertinente (5,5 / 12)
        do {
            var c = vuoto
            c.dataNascita = cal.date(byAdding: .year, value: -70, to: oggi)
            let k = calcola(c)
            verifica("C10 Completezza: a 70 anni al 46%", Double(k.percentuale), 46)
            verifica.vero("C10 Completezza: niente reddito desiderato, pensione pubblica e lavoro",
                          voce(k, "redditoDesiderato") == nil && voce(k, "pensionePubblica") == nil && voce(k, "lavoro") == nil)
        }

        // C11. Le ipotesi dichiarate da ogni documento
        verifica.vero("C11 Completezza: ipotesi del piano previdenziale",
                      Set(c1.ipotesi(per: .previdenza).map(\.id)) == ["nascita", "redditoLordo", "redditoDesiderato", "pensionePubblica", "lavoro"])
        verifica.vero("C11 Completezza: ipotesi della protezione",
                      Set(c1.ipotesi(per: .protezione).map(\.id)) == ["nascita", "statoCivile", "redditoNetto", "fabbisogno"])
        verifica("C11 Completezza: il check-up le dichiara tutte", Double(c1.ipotesi(per: .checkUp).count), 8)

        // C12. Un figlio a carico senza data di nascita (4,5 / 19)
        do {
            var c = vuoto
            let figlio = Familiare(nome: "Luca Prova", relazione: .figlio, aCarico: true)
            c.famiglia = [figlio]
            let k = calcola(c)
            verifica("C12 Completezza: figlio a carico senza data al 24%", Double(k.percentuale), 24)
            let v = voce(k, "familiare:\(figlio.id)")
            verifica.vero("C12 Completezza: data del figlio mancante", v?.stato == .mancante)
            verifica.vero("C12 Completezza: si completa nel modulo del familiare", v?.destinazione == .familiare(figlio.id))
        }

        // C13. Senza montante / con contributi dal 1995 (sistema misto): lavoro stimato (26 / 27)
        do {
            var c = completo
            c.profilo.lavoro?.montanteContributivo = nil
            let k = calcola(c, [etfCompleto], confermata)
            verifica("C13 Completezza: senza montante al 96%", Double(k.percentuale), 96)
            verifica.vero("C13 Completezza: lavoro stimato senza montante", voce(k, "lavoro")?.stato == .stimato)
            var m = completo
            m.profilo.lavoro?.annoPrimoContributo = 1995
            let km = calcola(m, [etfCompleto], confermata)
            verifica("C13 Completezza: sistema misto al 96%", Double(km.percentuale), 96)
            verifica.vero("C13 Completezza: lavoro stimato con il sistema misto", voce(km, "lavoro")?.stato == .stimato)
        }

        // C14. Il solo costo d'ingresso basta (la regola di MotoreCosti)
        do {
            var p = etf
            p.costoIngresso = 1
            verifica.vero("C14 Completezza: costo d'ingresso indicato", voce(calcola(vuoto, [p]), "costi:\(p.id)")?.stato == .completo)
        }

        // C15. Proposte: aperta in bozza o rimandata sì, rifiutata no; posizione chiusa no
        do {
            func proposta(_ esito: EsitoProposta) -> Posizione {
                var p = etf
                p.stato = .proposta
                p.esito = esito
                return p
            }
            let bozza = proposta(.bozza)
            verifica.vero("C15 Completezza: proposta in bozza senza costi", voce(calcola(vuoto, [bozza]), "costi:\(bozza.id)") != nil)
            let rimandata = proposta(.rimandata)
            verifica.vero("C15 Completezza: la proposta rimandata resta aperta",
                          voce(calcola(vuoto, [rimandata]), "costi:\(rimandata.id)") != nil)
            let rifiutata = proposta(.rifiutata)
            verifica.vero("C15 Completezza: nessuna voce per la proposta rifiutata",
                          !calcola(vuoto, [rifiutata]).voci.contains { $0.posizioneId == rifiutata.id })
            var chiusa = etf
            chiusa.stato = .chiusa
            verifica.vero("C15 Completezza: nessuna voce per la posizione chiusa",
                          !calcola(vuoto, [chiusa]).voci.contains { $0.posizioneId == chiusa.id })
        }

        // C16. Archivio: i dati non pertinenti si conservano, mancano negli archivi di prima, un valore rotto non scarta il cliente
        do {
            var c = vuoto
            c.datiNonPertinenti = ["costi:x": oggi]
            let dati = try Archivio.codificatore.encode(c)
            let riletto = try Archivio.decodificatore.decode(Cliente.self, from: dati)
            verifica.vero("C16 Completezza: dati non pertinenti conservati nell'archivio", riletto == c)
            var dizionario = (try JSONSerialization.jsonObject(with: dati) as? [String: Any]) ?? [:]
            dizionario.removeValue(forKey: "datiNonPertinenti")
            let senza = try Archivio.decodificatore.decode(Cliente.self, from: JSONSerialization.data(withJSONObject: dizionario))
            verifica.vero("C16 Completezza: archivio senza la chiave, nessun dato escluso", senza.datiNonPertinenti == nil)
            dizionario["datiNonPertinenti"] = 5
            let rotto = try Archivio.decodificatore.decode(Cliente.self, from: JSONSerialization.data(withJSONObject: dizionario))
            verifica.vero("C16 Completezza: valore malformato, cliente letto e campo vuoto",
                          rotto.id == c.id && rotto.datiNonPertinenti == nil)
        } catch {
            verifica.vero("C16 Completezza: lettura e scrittura del cliente (\(error))", false)
        }

        // C17. Multiramo senza la quota in gestione separata (stimata al 50%) / con la quota del 40%
        do {
            var mr = AiutiProva.posizione("Multiramo prova", .investimento, 20_000) { $0.tipologia = "Multiramo" }
            verifica.vero("C17 Completezza: quota in gestione separata stimata",
                          voce(calcola(vuoto, [mr]), "quotaGestione:\(mr.id)")?.stato == .stimato)
            mr.quotaGestioneSeparata = 40
            verifica.vero("C17 Completezza: quota in gestione separata indicata",
                          voce(calcola(vuoto, [mr]), "quotaGestione:\(mr.id)")?.stato == .completo)
        }

        // C18. Dove si completa: il fabbisogno nell'Analisi 360, i costi nel modulo della posizione
        verifica.vero("C18 Completezza: il fabbisogno si completa nell'Analisi 360",
                      voce(c1, "fabbisogno")?.destinazione == .analisi360(.protezione, campo: "Fabbisogno della famiglia"))
        verifica.vero("C18 Completezza: i costi si completano sul costo annuo della posizione",
                      voce(c3, "costi:\(etf.id)")?.destinazione == .posizione(etf.id, campo: "Costo annuo"))
    }
}
