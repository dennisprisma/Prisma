import Foundation

/// Prove dell'app Documenti (specifica «Documenti», casi D1–D18): regole nuove di lettura, categoria dal testo, stato
/// dei documenti, canale e area proposti, elenco con raccolte e ricerca, scheda leggibile, confronto dei documenti del
/// cliente (identità e questionari) con il dossier e lettura tollerante dell'archivio. Chiamata da
/// `ProvaCalcoli.esegui()`: gli errori si sommano. I testi di prova stanno qui (`static`): li usano anche le istantanee.
enum ProvaCalcoliDocumenti {

    // MARK: - Documenti di prova (anche per le istantanee)

    /// Il KID 2026 della polizza multiramo di Alleanza (12.280 € = 10.000 × 1,026^8).
    static let kidMultiramo = [
        """
        Documento contenente le informazioni chiave
        Prodotto: Polizza multiramo
        Ideatore del PRIIP: Alleanza Assicurazioni S.p.A.
        Tipo: Polizza multiramo (Ramo I e Ramo III)
        Data di realizzazione del documento: 01/10/2026
        """,
        """
        Quali sono i rischi e qual è il potenziale rendimento?
        Abbiamo classificato questo prodotto nella classe di rischio 4 su 7, che corrisponde alla classe di rischio media.
        Periodo di detenzione raccomandato: 8 anni
        Scenari di performance
        Scenario moderato  Possibile rimborso al netto dei costi 12.280 €  Rendimento medio per ciascun anno 2,6%
        """,
        """
        Quali sono i costi?
        Costi di ingresso: 1,00% dell'importo pagato
        Costi di uscita: 0,00%
        Commissioni di gestione e altri costi amministrativi o di esercizio: 2,05% del valore dell'investimento all'anno
        Incidenza annuale dei costi: 2,40% ogni anno
        """,
    ]

    /// La carta d'identità di Giulia («RSSGLI89C54A944H»: il carattere di controllo H è calcolato in `calcoli_documenti.py`).
    static let identita = ["""
        REPUBBLICA ITALIANA · Carta d'identità elettronica
        Carta d'identità n. CA12345AB
        Cognome e nome: Rossi Giulia
        Codice fiscale: RSSGLI89C54A944H
        Data di rilascio: 05/03/2020
        Scadenza: 14/03/2030
        """]

    /// Un questionario di adeguatezza senza canale scritto.
    static let questionario = ["""
        Questionario di adeguatezza (profilazione del cliente)
        Data di compilazione: 12/02/2026
        Profilo di rischio: moderato
        Orizzonte temporale dell'investimento: 10 anni
        """]

    /// Un documento di prova senza file, con i dati delle regole tutti confermati e la categoria dal testo.
    static func documento(_ id: String, cliente: String, titolo: String, tipo: Documento.Tipo, pagine: [String]) -> Documento {
        var d = Documento(clienteId: cliente, titolo: titolo, tipo: tipo)
        d.id = id
        d.pagine = pagine.count
        d.lettura = .letto
        d.campi = EstrattoreDocumento.conRegole(pagine).map { c in
            var x = c
            x.confermato = true
            return x
        }
        d.categoria = MotoreDocumenti.categoriaProbabile(pagine, tipo: tipo)
        return d
    }

    // MARK: - Prove

    static func esegui(_ verifica: VerificaCalcoli) {
        regoleNuove(verifica)
        categorie(verifica)
        statoECanale(verifica)
        elencoERicerca(verifica)
        schedaLeggibile(verifica)
        documentiDelCliente(verifica)
        archivio(verifica)
    }

    // MARK: - Aiuti

    /// Il giorno delle prove: 29 ottobre 2026.
    private static var oggi: Date { AiutiProva.data(2026, 10, 29) }

    private static let cal = Calendar(identifier: .gregorian)

    /// Gli importi di `Formati` hanno lo spazio non separabile prima di «€»: nei confronti vale come uno spazio.
    private static func spazi(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private static func campo(_ campi: [CampoEstratto], _ k: CampoDocumento) -> CampoEstratto? {
        campi.first { $0.chiave == k }
    }

    private static func stessoGiorno(_ a: Date?, _ b: Date) -> Bool {
        guard let a else { return false }
        return Calendar.current.isDate(a, inSameDayAs: b)
    }

    private static func clienteGiulia() -> Cliente? { DatiDemo.clienti().first { $0.id == "giulia" } }

    private static var nuovi: [CampoDocumento] {
        [.isin, .dataDocumento, .rendimentoPrimaCosti, .numeroDocumento, .intestatario, .codiceFiscale, .dataRilascio,
         .profiloRischio, .orizzonte]
    }

    // MARK: - D1–D6 Lettura

    private static func regoleNuove(_ verifica: VerificaCalcoli) {
        // D1. Il KID della multiramo
        let k = EstrattoreDocumento.conRegole(kidMultiramo)
        func n(_ c: CampoDocumento) -> Double { EstrattoreDocumento.numero(campo(k, c)?.valore) ?? -99 }
        verifica("D1 KID multiramo: 11 dati", Double(k.count), 11)
        verifica.vero("D1 KID multiramo: SRI «4» a pagina 2", campo(k, .sri)?.valore == "4" && campo(k, .sri)?.pagina == 2)
        verifica("D1 KID multiramo: periodo 8 anni", n(.periodoDetenzione), 8)
        verifica("D1 KID multiramo: costo d'ingresso", n(.costoIngresso), 1)
        verifica("D1 KID multiramo: costo d'uscita", n(.costoUscita), 0)
        verifica("D1 KID multiramo: costi correnti", n(.costoAnnuo), 2.05, tolleranza: 0.000_1)
        verifica("D1 KID multiramo: incidenza dei costi", n(.incidenzaCosti), 2.4, tolleranza: 0.000_1)
        verifica("D1 KID multiramo: scenario moderato", n(.rendimentoModerato), 2.6, tolleranza: 0.000_1)
        verifica.vero("D1 KID multiramo: data del documento a pagina 1",
                      campo(k, .dataDocumento)?.valore == "01/10/2026" && campo(k, .dataDocumento)?.pagina == 1)
        verifica.vero("D1 KID multiramo: nome del prodotto", campo(k, .nomeProdotto)?.valore == "Polizza multiramo")
        verifica.vero("D1 KID multiramo: ideatore", campo(k, .emittente)?.valore == "Alleanza Assicurazioni S.p.A.")
        verifica.vero("D1 KID multiramo: tipologia", campo(k, .tipologia)?.valore == "Polizza multiramo (Ramo I e Ramo III)")
        verifica.vero("D1 KID multiramo: nessun numero di contratto", campo(k, .numeroContratto) == nil)

        // D2. I tre documenti di prova non cambiano
        for id in ["doc-giulia-kid", "doc-marco-polizza", "doc-giulia-estratto"] {
            let c = EstrattoreDocumento.conRegole(DatiDemo.testoDocumento(id) ?? [])
            verifica.vero("D2 \(id): nessuno dei dati nuovi", !c.contains { nuovi.contains($0.chiave) })
        }
        verifica("D2 KID di Giulia: 10 dati", Double(EstrattoreDocumento.conRegole(DatiDemo.testoDocumento("doc-giulia-kid") ?? []).count), 10)
        verifica("D2 Estratto di Giulia: 6 dati", Double(EstrattoreDocumento.conRegole(DatiDemo.testoDocumento("doc-giulia-estratto") ?? []).count), 6)

        // D3. Il KID 2023 della prova 17b: il rendimento «prima dei costi»
        let kid2023 = [
            """
            Documento contenente le informazioni chiave
            Nome del prodotto: Esempio Multiramo Futuro – Classe B
            Nome dell'ideatore del PRIIP: Esempio Vita S.p.A. – Gruppo Esempio
            Tipo: Contratto di assicurazione sulla vita multiramo
            """,
            """
            Indicatore di rischio
            Abbiamo classificato questo prodotto al livello 4 su 7, che corrisponde alla classe di rischio media.
            Periodo di detenzione raccomandato:
            8 anni
            Scenario moderato   Possibile rimborso al netto dei costi   9.870 EUR   12.410 EUR
            Rendimento medio per ciascun anno   -1,3%   2,7%
            """,
            """
            Andamento dei costi nel tempo
            Costi totali   410 EUR   1.540 EUR
            Incidenza annuale dei costi (*)   4,1%   1,9% ogni anno
            (*) Dimostra come i costi riducono il rendimento ogni anno: se si esce al termine del periodo il rendimento è del 4,6% prima dei costi.
            Composizione dei costi
            Costi di ingresso   2,5% dell'importo pagato al momento della sottoscrizione
            Costi di uscita   Non addebitiamo una commissione di uscita per questo prodotto
            Commissioni di gestione e altri costi amministrativi o di esercizio   1,60% del valore dell'investimento all'anno
            """,
        ]
        let k23 = EstrattoreDocumento.conRegole(kid2023)
        func n23(_ c: CampoDocumento) -> Double { EstrattoreDocumento.numero(campo(k23, c)?.valore) ?? -99 }
        verifica("D3 KID 2023: rendimento prima dei costi", n23(.rendimentoPrimaCosti), 4.6, tolleranza: 0.000_1)
        verifica.vero("D3 KID 2023: nome e ideatore invariati",
                      campo(k23, .nomeProdotto)?.valore == "Esempio Multiramo Futuro" && campo(k23, .emittente)?.valore == "Esempio Vita S.p.A.")
        verifica("D3 KID 2023: SRI invariato", n23(.sri), 4)
        verifica("D3 KID 2023: periodo invariato", n23(.periodoDetenzione), 8)
        verifica("D3 KID 2023: scenario moderato invariato", n23(.rendimentoModerato), 2.7, tolleranza: 0.000_1)
        verifica("D3 KID 2023: incidenza invariata", n23(.incidenzaCosti), 1.9, tolleranza: 0.000_1)

        // D4. ISIN
        verifica.vero("D4 ISIN «Codice ISIN: IT0005439275»",
                      campo(EstrattoreDocumento.conRegole(["Codice ISIN: IT0005439275"]), .isin)?.valore == "IT0005439275")
        verifica.vero("D4 ISIN in minuscolo diventa maiuscolo",
                      campo(EstrattoreDocumento.conRegole(["ISIN: lu1234567890"]), .isin)?.valore == "LU1234567890")
        verifica.vero("D4 ISIN troppo corto: nessun dato",
                      campo(EstrattoreDocumento.conRegole(["Codice ISIN: IT00054"]), .isin) == nil)
        // Le risposte di Qwen: codici con la forma giusta, date vere, anni dalle cifre iniziali
        let qwen = EstrattoreDocumento.daRisposta("isin|it0005439275\ncodiceFiscale|RSSGLI89\norizzonte|10 anni\ndataRilascio|31/02/2020\nrendimentoPrimaCosti|4,6%", pagina: 1)
        verifica.vero("D4 Qwen: ISIN in maiuscolo, orizzonte «10», rendimento «4,6»; scartati codice fiscale e data impossibile",
                      qwen.map(\.valore) == ["IT0005439275", "10", "4,6"])

        // D5. Documento d'identità
        let i = EstrattoreDocumento.conRegole(identita)
        verifica.vero("D5 Identità: numero del documento", campo(i, .numeroDocumento)?.valore == "CA12345AB")
        verifica.vero("D5 Identità: intestatario", campo(i, .intestatario)?.valore == "Rossi Giulia")
        verifica.vero("D5 Identità: codice fiscale", campo(i, .codiceFiscale)?.valore == "RSSGLI89C54A944H")
        verifica.vero("D5 Identità: data di rilascio", campo(i, .dataRilascio)?.valore == "05/03/2020")
        verifica.vero("D5 Identità: scadenza", campo(i, .scadenza)?.valore == "14/03/2030")
        verifica.vero("D5 Identità: nessun numero di contratto", campo(i, .numeroContratto) == nil)
        verifica.vero("D5 Identità: per Eve resta «altro»", EstrattoreDocumento.tipoProbabile(identita) == .altro)
        verifica.vero("D5 Identità: categoria", MotoreDocumenti.categoriaProbabile(identita, tipo: .altro) == .identita)

        // D6. Questionario
        let q = EstrattoreDocumento.conRegole(questionario)
        verifica.vero("D6 Questionario: data", campo(q, .dataDocumento)?.valore == "12/02/2026")
        verifica.vero("D6 Questionario: profilo «moderato»", campo(q, .profiloRischio)?.valore == "moderato")
        verifica.vero("D6 Questionario: orizzonte «10»", campo(q, .orizzonte)?.valore == "10")
        verifica.vero("D6 Questionario: categoria", MotoreDocumenti.categoriaProbabile(questionario, tipo: .altro) == .questionario)
        verifica.vero("D6 Questionario: per Eve resta «altro»", EstrattoreDocumento.tipoProbabile(questionario) == .altro)
    }

    // MARK: - D7–D8 Categoria e tipo

    private static func categorie(_ verifica: VerificaCalcoli) {
        let kidGiulia = DatiDemo.testoDocumento("doc-giulia-kid") ?? []
        verifica.vero("D7 Categoria: KID di Giulia", MotoreDocumenti.categoriaProbabile(kidGiulia, tipo: .altro) == .kid)
        verifica.vero("D7 Categoria: polizza di Marco",
                      MotoreDocumenti.categoriaProbabile(DatiDemo.testoDocumento("doc-marco-polizza") ?? [], tipo: .altro) == .contratto)
        verifica.vero("D7 Categoria: estratto di Giulia",
                      MotoreDocumenti.categoriaProbabile(DatiDemo.testoDocumento("doc-giulia-estratto") ?? [], tipo: .altro) == .estratto)
        verifica.vero("D7 Categoria: una fattura", MotoreDocumenti.categoriaProbabile(["Fattura n. 12 del 3/2/2026"], tipo: .altro) == .altro)
        verifica.vero("D7 Categoria: un report è sempre di Prisma", MotoreDocumenti.categoriaProbabile(identita, tipo: .report) == .prisma)
        var conQuestionario = kidGiulia
        if !conQuestionario.isEmpty { conQuestionario[0] += "\nquestionario" }
        verifica.vero("D7 Categoria: il KID prevale sui segni del questionario",
                      MotoreDocumenti.categoriaProbabile(conQuestionario, tipo: .altro) == .kid)

        // D8. Categoria e tipo
        verifica.vero("D8 Contratto da una proposta resta proposta", CategoriaDocumento.contratto.tipo(da: .proposta) == .proposta)
        verifica.vero("D8 Contratto da «altro» diventa polizza", CategoriaDocumento.contratto.tipo(da: .altro) == .polizza)
        verifica.vero("D8 Identità: per Eve è «altro»", CategoriaDocumento.identita.tipo(da: .kid) == .altro)
        verifica.vero("D8 Un estratto conto senza categoria è un estratto",
                      Documento(clienteId: "a", titolo: "x", tipo: .estrattoConto).genere == .estratto)
        var report = Documento(clienteId: "a", titolo: "x", tipo: .report)
        report.categoria = .altro
        verifica.vero("D8 Un report resta di Prisma anche con un'altra categoria", report.genere == .prisma)
        let generi = DatiDemo.documenti().map(\.genere)
        verifica.vero("D8 I tre documenti di prova: KID, contratto, estratto", generi == [.kid, .contratto, .estratto])
        let docIdentita = documento("d-i", cliente: "giulia", titolo: "Carta d'identità", tipo: .altro, pagine: identita)
        let docQuestionario = documento("d-q", cliente: "giulia", titolo: "Questionario", tipo: .altro, pagine: questionario)
        let docKID = documento("d-k", cliente: "marco", titolo: "KID", tipo: .kid, pagine: kidMultiramo)
        verifica.vero("D8 Del cliente: identità e questionario sì, KID no",
                      MotoreDocumenti.delCliente(docIdentita) && MotoreDocumenti.delCliente(docQuestionario) && !MotoreDocumenti.delCliente(docKID))
    }

    // MARK: - D9–D10 Stato, canale e area

    private static func statoECanale(_ verifica: VerificaCalcoli) {
        var d = Documento(clienteId: "a", titolo: "KID", tipo: .kid)
        d.lettura = .letto
        d.campi = [CampoEstratto(chiave: .sri, valore: "3", pagina: 2), CampoEstratto(chiave: .costoAnnuo, valore: "1,20", pagina: 3)]
        func stato(_ x: Documento, inLettura: Bool = false, collegato: Bool = false, differenze: Int = 0) -> MotoreDocumenti.Stato {
            MotoreDocumenti.indicatori(x, inLettura: inLettura, collegato: collegato, differenze: differenze).stato
        }
        verifica.vero("D9 Stato: in lettura", stato(d, inLettura: true) == .inLettura)
        var illeggibile = d
        illeggibile.lettura = .illeggibile
        verifica.vero("D9 Stato: illeggibile", stato(illeggibile, differenze: 2) == .illeggibile)
        verifica.vero("D9 Stato: le differenze prima dei dati da controllare", stato(d, collegato: true, differenze: 2) == .conDifferenze(2))
        verifica.vero("D9 Stato: dati da controllare senza differenze", stato(d, collegato: true) == .daLeggere)
        verifica("D9 Stato: dati da controllare", Double(MotoreDocumenti.indicatori(d, inLettura: false, collegato: true, differenze: 0).daControllare), 2)
        var confermato = d
        for i in confermato.campi.indices { confermato.campi[i].confermato = true }
        verifica.vero("D9 Stato: tutto confermato e collegato", stato(confermato, collegato: true) == .collegato)
        verifica.vero("D9 Stato: tutto confermato, non collegato", stato(confermato) == .letto)
        var nonLetto = Documento(clienteId: "a", titolo: "Nuovo", tipo: .altro)
        nonLetto.lettura = .daLeggere
        verifica.vero("D9 Stato: non ancora letto", stato(nonLetto) == .daLeggere)
        let ind = MotoreDocumenti.indicatori(d, inLettura: false, collegato: false, differenze: 0)
        verifica.vero("D9 Testi dello stato", ind.stato.etichetta == "Da leggere" && ind.stato.nota(ind, nome: nil) == "2 dati da controllare"
                      && MotoreDocumenti.Stato.conDifferenze(1).etichetta == "1 differenza")

        // D10. Canale e area proposti
        let kid = documento("d-kid", cliente: "marco", titolo: "KID 2026 · Polizza multiramo", tipo: .kid, pagine: kidMultiramo)
        let scheda = DatiDemo.prodotti().first { $0.id == "prodotto-multiramo" }
        let a = MotoreDocumenti.canaleEArea(kid, posizione: nil, prodotto: scheda)
        verifica.vero("D10 KID multiramo con la scheda: Alleanza, investimento", scheda != nil && a.canale == .alleanza && a.area == .investimento)
        let documenti = DatiDemo.documenti()
        if let kidGiulia = documenti.first(where: { $0.id == "doc-giulia-kid" }) {
            let b = MotoreDocumenti.canaleEArea(kidGiulia, posizione: nil, prodotto: nil)
            verifica.vero("D10 KID di Giulia senza bersaglio: indipendente, previdenza", b.canale == .indipendente && b.area == .previdenza)
        } else {
            verifica.vero("D10 KID di Giulia presente", false)
        }
        let infortuni = DatiDemo.posizioni().first { $0.id == "pos-marco-infortuni-famiglia" }
        if let polizza = documenti.first(where: { $0.id == "doc-marco-polizza" }), let infortuni {
            let c = MotoreDocumenti.canaleEArea(polizza, posizione: infortuni, prodotto: nil)
            verifica.vero("D10 Polizza di Marco con la posizione: Alleanza, protezione", c.canale == .alleanza && c.area == .protezione)
        } else {
            verifica.vero("D10 Polizza e posizione di Marco presenti", false)
        }
    }

    // MARK: - D11 Elenco, raccolte e ricerca

    private static func elencoERicerca(_ verifica: VerificaCalcoli) {
        verifica.vero("D11 Testo normale: forma societaria via",
                      MotoreDocumenti.normale("Alleanza Assicurazioni S.p.A.") == "alleanza assicurazioni"
                      && MotoreDocumenti.normale("Orizzonte SGR S.p.A.") == "orizzonte sgr"
                      && MotoreDocumenti.normale("Polizza multiramo (Ramo I e Ramo III)") == "polizza multiramo ramo i e ramo iii")
        verifica.vero("D11 Testo compatto", MotoreDocumenti.compatto("AL-2022/104851") == "AL2022104851")
        verifica.vero("D11 Parole come insieme", MotoreDocumenti.parole("Rossi Giulia") == MotoreDocumenti.parole("Giulia Rossi"))

        guard let polizza = DatiDemo.documenti().first(where: { $0.id == "doc-marco-polizza" }) else {
            verifica.vero("D11 Polizza di Marco presente", false)
            return
        }
        let kid = documento("d-kid", cliente: "marco", titolo: "KID 2026 · Polizza multiramo", tipo: .kid, pagine: kidMultiramo)
        let voci = [
            MotoreDocumenti.Voce(documento: polizza,
                                 indicatori: MotoreDocumenti.indicatori(polizza, inLettura: false, collegato: true, differenze: 3),
                                 canale: .alleanza, nomeCollegato: "Infortuni famiglia"),
            MotoreDocumenti.Voce(documento: kid,
                                 indicatori: MotoreDocumenti.indicatori(kid, inLettura: false, collegato: true, differenze: 2),
                                 canale: .alleanza, nomeCollegato: "Polizza multiramo"),
        ]
        func pagine(_ d: Documento) -> [String] { d.id == "d-kid" ? kidMultiramo : (DatiDemo.testoDocumento(d.id) ?? []) }
        func cerca(_ f: MotoreDocumenti.Filtro) -> [MotoreDocumenti.Gruppo] { MotoreDocumenti.elenco(voci, filtro: f, pagine: pagine) }
        func gruppiConTesto(_ t: String) -> [MotoreDocumenti.Gruppo] {
            var f = MotoreDocumenti.Filtro()
            f.testo = t
            return cerca(f)
        }
        func conTesto(_ t: String) -> [MotoreDocumenti.VoceTrovata] { gruppiConTesto(t).flatMap(\.voci) }

        verifica.vero("D11 Tutti: gruppi KID e contratti", cerca(MotoreDocumenti.Filtro()).map(\.categoria) == [.kid, .contratto])
        var differenze = MotoreDocumenti.Filtro()
        differenze.raccolta = .conDifferenze
        verifica("D11 Cosa non torna: 2 documenti", Double(cerca(differenze).flatMap(\.voci).count), 2)
        verifica.vero("D11 «infortuni»: solo la polizza (dal titolo)", conTesto("infortuni").map(\.id) == ["doc-marco-polizza"])
        verifica.vero("D11 «AL-2025»: la polizza (dal numero)", conTesto("AL-2025").map(\.id) == ["doc-marco-polizza"])
        let importo = conTesto("importo pagato")
        verifica.vero("D11 «importo pagato»: il KID, dalla pagina 3",
                      importo.map(\.id) == ["d-kid"] && importo.first?.nelTesto?.hasPrefix("p. 3 ·") == true)
        verifica.vero("D11 «garanzia»: nessun gruppo", gruppiConTesto("garanzia").isEmpty)
        var soloKID = MotoreDocumenti.Filtro()
        soloKID.categoria = .kid
        verifica("D11 Categoria KID: 1 documento", Double(cerca(soloKID).flatMap(\.voci).count), 1)
        var alleanza = MotoreDocumenti.Filtro()
        alleanza.canale = .alleanza
        verifica("D11 Canale Alleanza: 2 documenti", Double(cerca(alleanza).flatMap(\.voci).count), 2)
        verifica("D11 Conteggi: cosa non torna", Double(MotoreDocumenti.conteggi(voci).raccolte[.conDifferenze] ?? 0), 2)
    }

    // MARK: - D12–D14 La scheda leggibile

    private static func schedaLeggibile(_ verifica: VerificaCalcoli) {
        let documenti = DatiDemo.documenti()
        if let kid = documenti.first(where: { $0.id == "doc-giulia-kid" }), let giulia = clienteGiulia() {
            let s = MotoreDocumenti.scheda(kid, cliente: giulia, oggi: oggi)
            verifica.vero("D12 Scheda del KID: chi, che cosa, cifre, costi, rischio", s.map(\.sezione) == [.chi, .cosa, .cifre, .costi, .rischio])
            verifica.vero("D12 Scheda del KID: righe 1, 2, 1, 4, 2", s.map(\.righe.count) == [1, 2, 1, 4, 2])
            let rischio = s.first { $0.sezione == .rischio }
            let costi = s.first { $0.sezione == .costi }
            verifica.vero("D12 SRI: «Classe 3 su 7: medio-bassa.»",
                          rischio?.righe.first { $0.campo.chiave == .sri }?.nota == "Classe 3 su 7: medio-bassa.")
            verifica.vero("D12 Rischio adatto alla propensione moderata",
                          rischio?.note.contains("Adatto a una propensione moderata (fino a 3).") == true)
            verifica.vero("D12 Periodo più lungo dell'orizzonte",
                          rischio?.note.contains("Più lungo dell'orizzonte di Giulia Rossi (10 anni): uscire prima può costare.") == true)
            verifica.vero("D12 Costi nel tempo",
                          costi?.note.contains("Su 15 anni i costi tolgono circa 0,95 punti di rendimento ogni anno.") == true)
            verifica.vero("D12 Rendimento lordo stimato 4,08%", costi?.note.contains { $0.contains("4,08%") } == true)
        } else {
            verifica.vero("D12 KID e cliente Giulia presenti", false)
        }

        // D13. I dati attesi che mancano
        if let kid = documenti.first(where: { $0.id == "doc-giulia-kid" }), let polizza = documenti.first(where: { $0.id == "doc-marco-polizza" }) {
            verifica.vero("D13 KID di Giulia: niente da aggiungere", MotoreDocumenti.mancanti(kid).isEmpty)
            verifica.vero("D13 Polizza di Marco: manca il nome del prodotto", MotoreDocumenti.mancanti(polizza) == [.nomeProdotto])
        }
        let docIdentita = documento("d-i", cliente: "giulia", titolo: "Carta d'identità", tipo: .altro, pagine: identita)
        verifica.vero("D13 Identità: niente da aggiungere", MotoreDocumenti.mancanti(docIdentita).isEmpty)

        // D14. I valori da leggere
        func t(_ k: CampoDocumento, _ v: String, _ estratto: String = "") -> String {
            spazi(MotoreDocumenti.testo(CampoEstratto(chiave: k, valore: v, pagina: 1, estratto: estratto)))
        }
        verifica.vero("D14 Premio annuo", t(.premio, "380,00", "Premio annuo: 380,00") == "380 € l'anno")
        verifica.vero("D14 Capitale senza centesimi", t(.capitaleAssicurato, "150.000,00") == "150.000 €")
        verifica.vero("D14 Controvalore con i centesimi", t(.controvalore, "4.712,40") == "4.712,40 €")
        verifica.vero("D14 Percentuale", t(.costoAnnuo, "0,85") == "0,85%")
        verifica.vero("D14 SRI", t(.sri, "3") == "3 su 7")
        verifica.vero("D14 Anni", t(.periodoDetenzione, "15") == "15 anni")
        verifica.vero("D14 Data estesa", t(.decorrenza, "01/12/2025") == "1 dicembre 2025")
    }

    // MARK: - D15–D17 Identità e questionari contro il dossier

    private static func documentiDelCliente(_ verifica: VerificaCalcoli) {
        guard var giulia = clienteGiulia() else {
            verifica.vero("D15 Cliente Giulia presente", false)
            return
        }
        // Come nella specifica: nessuna data di conformità e nessun codice fiscale nel dossier
        giulia.conformita = nil
        giulia.codiceFiscale = ""
        typealias Riga = MotoreDocumenti.RigaCliente
        func riga(_ r: [Riga], _ c: CampoDocumento) -> Riga? { r.first { $0.campo == c } }

        // D15. Questionario
        let q = documento("d-q", cliente: "giulia", titolo: "Questionario di adeguatezza", tipo: .altro, pagine: questionario)
        // Condizioni a pezzi (funzioni con i tipi scritti): il controllo dei tipi resta rapido
        func nuovaConNota(_ r: Riga?) -> Bool {
            guard let r, r.esito == MotoreDocumenti.RigaCliente.Esito.nuovo, !r.aggiornabile else { return false }
            return r.nota == MotoreDocumenti.notaScegliCanale
        }
        func nuovaAggiornabile(_ r: Riga?) -> Bool {
            guard let r else { return false }
            return r.esito == MotoreDocumenti.RigaCliente.Esito.nuovo && r.aggiornabile
        }
        let senzaCanale = MotoreDocumenti.righeCliente(q, cliente: giulia, canale: nil, oggi: oggi)
        verifica.vero("D15 Senza canale: data e profilo nuovi, non aggiornabili, con la nota",
                      nuovaConNota(riga(senzaCanale, .dataDocumento)) && nuovaConNota(riga(senzaCanale, .profiloRischio)))
        verifica.vero("D15 Senza canale: orizzonte uguale", riga(senzaCanale, .orizzonte)?.esito == .uguale)
        let conAlleanza = MotoreDocumenti.righeCliente(q, cliente: giulia, canale: .alleanza, oggi: oggi)
        verifica.vero("D15 Con Alleanza: data e profilo nuovi, aggiornabili",
                      nuovaAggiornabile(riga(conAlleanza, .dataDocumento)) && nuovaAggiornabile(riga(conAlleanza, .profiloRischio)))
        var g = giulia
        let applicati = MotoreDocumenti.applicaCliente([.dataDocumento, .profiloRischio], da: q, a: &g, canale: .alleanza)
        verifica.vero("D15 Applicati data e profilo", applicati == [.dataDocumento, .profiloRischio])
        verifica.vero("D15 Questionario Alleanza compilato il 12/02/2026",
                      stessoGiorno(g.conformita?.questionarioAlleanza?.compilatoIl, AiutiProva.data(2026, 2, 12)))
        verifica.vero("D15 Esito «Moderato» e propensione moderata",
                      g.conformita?.questionarioAlleanza?.esito == "Moderato" && g.profilo.propensione == .moderata)
        var dinamico = q
        for i in dinamico.campi.indices {
            if dinamico.campi[i].chiave == .profiloRischio { dinamico.campi[i].valore = "dinamico" }
            if dinamico.campi[i].chiave == .orizzonte { dinamico.campi[i].valore = "15" }
        }
        let cambiato = MotoreDocumenti.righeCliente(dinamico, cliente: g, canale: .alleanza, oggi: oggi)
        verifica.vero("D15 «Dinamico» e 15 anni: profilo e orizzonte diversi",
                      riga(cambiato, .profiloRischio)?.esito == .diverso && riga(cambiato, .orizzonte)?.esito == .diverso)
        MotoreDocumenti.applicaCliente([.profiloRischio, .orizzonte], da: dinamico, a: &g, canale: .alleanza)
        let dinamica: Bool = g.profilo.propensione == ProfiloInvestitore.Propensione.dinamica && g.profilo.orizzonteAnni == 15
        verifica.vero("D15 Applicati: propensione dinamica, 15 anni, esito «Dinamico»",
                      dinamica && g.conformita?.questionarioAlleanza?.esito == "Dinamico")
        typealias Propensione = ProfiloInvestitore.Propensione
        let paroleNote: Bool = MotoreDocumenti.propensione("Medio-alto") == Propensione.dinamica
            && MotoreDocumenti.propensione("conservativo") == Propensione.prudente
        let paroleAltre: Bool = MotoreDocumenti.propensione("aggressivo") == Propensione.aggressiva
            && MotoreDocumenti.propensione("boh") == nil
        verifica.vero("D15 Parole del questionario", paroleNote && paroleAltre)
        var boh = q
        for i in boh.campi.indices where boh.campi[i].chiave == .profiloRischio { boh.campi[i].valore = "boh" }
        verifica.vero("D15 Parola non riconosciuta: da verificare",
                      riga(MotoreDocumenti.righeCliente(boh, cliente: giulia, canale: .alleanza, oggi: oggi), .profiloRischio)?.esito == .indicativo)

        // D16. Documento d'identità
        let i = documento("d-i", cliente: "giulia", titolo: "Carta d'identità di Giulia Rossi", tipo: .altro, pagine: identita)
        let righe = MotoreDocumenti.righeCliente(i, cliente: giulia, canale: nil, oggi: oggi)
        verifica.vero("D16 Numero, rilascio, scadenza e codice fiscale nuovi",
                      [CampoDocumento.numeroDocumento, .dataRilascio, .scadenza, .codiceFiscale].allSatisfy { riga(righe, $0)?.esito == .nuovo })
        verifica.vero("D16 Intestatario «Rossi Giulia» uguale a «Giulia Rossi»", riga(righe, .intestatario)?.esito == .uguale)
        var gi = giulia
        MotoreDocumenti.applicaCliente(Set(CampoDocumento.allCases), da: i, a: &gi, canale: nil)
        let doc = gi.conformita?.documento
        verifica.vero("D16 Numero del documento in «In regola»", doc?.numero == "CA12345AB")
        verifica.vero("D16 Rilasciato il 05/03/2020", stessoGiorno(doc?.rilasciatoIl, AiutiProva.data(2020, 3, 5)))
        verifica.vero("D16 Scade il 14/03/2030", stessoGiorno(doc?.scadenza, AiutiProva.data(2030, 3, 14)))
        verifica.vero("D16 Carta d'identità", doc?.tipo == .cartaIdentita)
        verifica.vero("D16 Codice fiscale nel dossier", gi.codiceFiscale == "RSSGLI89C54A944H")
        var bianchi = giulia
        bianchi.nome = "Giulia Bianchi"
        let rb = riga(MotoreDocumenti.righeCliente(i, cliente: bianchi, canale: nil, oggi: oggi), .intestatario)
        verifica.vero("D16 Nome diverso: da verificare, non aggiornabile", rb?.esito == .indicativo && rb?.aggiornabile == false)
        var daConfermare = i
        for k in daConfermare.campi.indices where daConfermare.campi[k].chiave == .scadenza { daConfermare.campi[k].confermato = false }
        let rs = riga(MotoreDocumenti.righeCliente(daConfermare, cliente: giulia, canale: nil, oggi: oggi), .scadenza)
        verifica.vero("D16 Scadenza da confermare: non aggiornabile", rs?.esito == .daConfermare && rs?.aggiornabile == false)

        // D17. Tipo d'identità e canale del questionario
        verifica.vero("D17 «Passaporto di Giulia»",
                      MotoreDocumenti.tipoIdentita(Documento(clienteId: "giulia", titolo: "Passaporto di Giulia", tipo: .altro)) == .passaporto)
        verifica.vero("D17 Carta d'identità dai dati letti", MotoreDocumenti.tipoIdentita(i) == .cartaIdentita)
        verifica.vero("D17 «Fattura»: nessun tipo", MotoreDocumenti.tipoIdentita(Documento(clienteId: "giulia", titolo: "Fattura", tipo: .altro)) == nil)
        var qAlleanza = q
        qAlleanza.titolo = "Questionario di adeguatezza · Alleanza Assicurazioni"
        verifica.vero("D17 Questionario Alleanza", MotoreDocumenti.canaleQuestionario(qAlleanza) == .alleanza)
        var qMifid = q
        qMifid.titolo = "Questionario MiFID"
        verifica.vero("D17 Questionario MiFID: indipendente", MotoreDocumenti.canaleQuestionario(qMifid) == .indipendente)
        verifica.vero("D17 Questionario senza canale scritto", MotoreDocumenti.canaleQuestionario(q) == nil)
    }

    // MARK: - D18 Archivio

    private static func archivio(_ verifica: VerificaCalcoli) {
        let json = #"{"id":"d","clienteId":"a","titolo":"KID","tipo":"kid","campi":[{"chiave":"sri","valore":"3","pagina":2,"estratto":"","origine":"Regole di Prisma","confermato":true},{"chiave":"inventato","valore":"x","pagina":1}]}"#
        let letto = try? JSONDecoder().decode(Documento.self, from: Data(json.utf8))
        verifica.vero("D18 Archivio di prima: il documento si legge", letto != nil)
        verifica.vero("D18 Senza categoria: dal tipo", letto?.categoria == nil && letto?.genere == .kid)
        verifica("D18 Un dato sconosciuto si salta, gli altri restano", Double(letto?.campi.count ?? 0), 1)
        verifica.vero("D18 Nessuna voce lasciata come in Prisma", letto != nil && letto?.vociTenute == nil)
        let futuro = json.replacingOccurrences(of: #""tipo":"kid""#, with: #""tipo":"futuro""#)
        let nuovo = try? JSONDecoder().decode(Documento.self, from: Data(futuro.utf8))
        verifica.vero("D18 Un tipo sconosciuto diventa «altro» e il documento resta", nuovo?.tipo == .altro)

        var d = Documento(clienteId: "giulia", titolo: "Carta d'identità", tipo: .altro)
        d.importatoIl = AiutiProva.data(2026, 10, 1)
        d.categoria = .identita
        let riletto = (try? JSONEncoder().encode(d)).flatMap { try? JSONDecoder().decode(Documento.self, from: $0) }
        verifica.vero("D18 La categoria torna uguale", riletto == d && riletto?.categoria == .identita)
    }
}
