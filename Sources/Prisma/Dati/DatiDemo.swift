import Foundation

/// I 5 clienti di prova del template, con appuntamenti e attività.
///
/// Nel template le date partono da lunedì 19 ottobre 2026: qui partono
/// da oggi, così la scrivania mostra sempre i prossimi incontri.
enum DatiDemo {
    static func clienti() -> [Cliente] {
        var elenco = [
            Cliente(id: "giulia", nome: "Giulia Rossi", iniziali: "GR", tinta: .rosa, tema: "Una casa, un nuovo inizio.",
                    email: "giulia.rossi@example.com", telefono: "", preferito: true,
                    nota: "Il progetto casa è la priorità. Verificare tempi, disponibilità e domande rimaste aperte.",
                    creatoIl: data(-37)),
            Cliente(id: "marco", nome: "Marco Bianchi", iniziali: "MB", tinta: .blu, tema: "Il futuro della sua famiglia.",
                    email: "marco.bianchi@example.com", telefono: "", preferito: true,
                    nota: "Dedicare un momento ai progetti di famiglia. Preparare un riepilogo semplice e comprensibile.",
                    creatoIl: data(-31)),
            Cliente(id: "laura", nome: "Laura Moretti", iniziali: "LM", tinta: .viola, tema: "Più spazio alle possibilità.",
                    email: "laura.moretti@example.com", telefono: "", preferito: false,
                    nota: "Ripartire dagli obiettivi professionali e personali. La flessibilità è un tema importante.",
                    creatoIl: data(-26)),
            Cliente(id: "andrea", nome: "Andrea Conti", iniziali: "AC", tinta: .verde, tema: "Un percorso da costruire.",
                    email: "andrea.conti@example.com", telefono: "", preferito: false,
                    nota: "Primo incontro: ascolto, priorità e informazioni da raccogliere.",
                    creatoIl: data(-17)),
            Cliente(id: "sofia", nome: "Sofia Romano", iniziali: "SR", tinta: .oro, tema: "Le cose che contano, nel tempo.",
                    email: "sofia.romano@example.com", telefono: "", preferito: false,
                    nota: "Verificare se sono cambiati i progetti personali prima del prossimo incontro.",
                    creatoIl: data(-14)),
        ]
        completa(&elenco)
        return elenco
    }

    /// Anagrafica, famiglia e profilo dei clienti di prova (dati inventati).
    private static func completa(_ elenco: inout [Cliente]) {
        func nascita(_ anno: Int, _ mese: Int, _ giorno: Int) -> Date? {
            Calendar(identifier: .gregorian).date(from: DateComponents(year: anno, month: mese, day: giorno))
        }
        // Esperienza per tipo di prodotto (versione 21): una voce per tipo, nil = non indicato
        func griglia(_ voci: [VoceEsperienza], capacita: CapacitaPerdite?, il giorno: Date) -> EsperienzaProdotti {
            var e = EsperienzaProdotti()
            for v in voci { e.imposta(v) }
            e.capacitaPerdite = capacita
            e.aggiornataIl = giorno
            return e
        }
        func voce(_ t: TipoProdotto, _ conosce: Bool?, _ haAvuto: Bool?, _ haCapito: Bool?) -> VoceEsperienza {
            VoceEsperienza(tipo: t, conosce: conosce, haAvuto: haAvuto, haCapito: haCapito)
        }
        let anno = Calendar(identifier: .gregorian).component(.year, from: Date())
        for i in elenco.indices {
            var c = elenco[i]
            c.consensi = Consensi(privacy: true, dataPrivacy: c.creatoIl, marketing: false)
            c.profilo.aggiornatoIl = c.creatoIl
            switch c.id {
            case "giulia":
                c.profilo.redditoLordoAnnuo = 32_000
                c.dataNascita = nascita(1989, 3, 14)
                c.professione = "Architetta"
                c.statoCivile = .convivente
                c.indirizzo = "Via dei Mille 12, Bologna"
                c.telefono = "+39 333 000 1001"
                c.canali = [.alleanza, .indipendente]
                c.famiglia = [Familiare(nome: "Luca Ferri", relazione: .convivente, dataNascita: nascita(1987, 7, 2))]
                c.famiglia[0].id = "fam-giulia-luca"
                c.famiglia[0].redditoNettoAnnuo = 24_000
                c.famiglia[0].lavoro = DatiLavoro(tipo: .dipendente, redditoLavoro: 33_000, crescitaReddito: 1,
                                                  anniContributi: 13, annoPrimoContributo: 2013)
                c.profilo.redditoNettoAnnuo = 23_500
                c.profilo.lavoro = DatiLavoro(tipo: .dipendente, crescitaReddito: 1, anniContributi: 11,
                                              annoPrimoContributo: 2015, etaPensione: 67)
                c.profilo.propensione = .moderata
                c.profilo.orizzonteAnni = 10
                c.profilo.esperienza = .base
                c.profilo.obiettivi = "Anticipo per la nuova casa entro il 2029 e un margine di serenità."
                // Non conosce multiramo e previdenza (la proposta del PIP lo segnala), unit linked da spiegare
                c.profilo.esperienzaProdotti = griglia([
                    voce(.ramoI, true, true, true), voce(.ramoIII, true, false, false), voce(.multiramo, false, nil, nil),
                    voce(.fondiETF, true, nil, true), voce(.titoli, true, false, true), voce(.previdenza, false, false, nil),
                    voce(.protezione, true, true, true),
                ], capacita: .limitata, il: c.creatoIl)
                c.bisogni.imposta(ValutazioneBisogno(area: .casa, importanza: .alta, orizzonte: .presto))
                c.bisogni.imposta(ValutazioneBisogno(area: .pensione, importanza: .media, orizzonte: .lungo))
                c.bisogni.imposta(ValutazioneBisogno(area: .salute, importanza: .bassa, orizzonte: .medio))
                c.bisogni.eventi = [EventoVita(id: "evento-giulia-casa", tipo: .acquistoCasa, anno: anno + 3,
                                               nota: "Trilocale in città, anticipo del 20%")]
                c.bisogni.aggiornatoIl = c.creatoIl
            case "marco":
                c.profilo.redditoLordoAnnuo = 48_000
                c.dataNascita = nascita(1978, 11, 5)
                c.professione = "Ingegnere"
                c.statoCivile = .coniugato
                c.indirizzo = "Corso Vittorio Emanuele 88, Torino"
                c.telefono = "+39 333 000 1002"
                c.canali = [.alleanza]
                c.famiglia = [
                    Familiare(nome: "Elena Bianchi", relazione: .coniuge, dataNascita: nascita(1980, 4, 21)),
                    Familiare(nome: "Anna Bianchi", relazione: .figlia, dataNascita: nascita(2012, 9, 1), aCarico: true),
                    Familiare(nome: "Pietro Bianchi", relazione: .figlio, dataNascita: nascita(2016, 2, 11), aCarico: true),
                ]
                c.famiglia[0].id = "fam-marco-elena"
                c.famiglia[1].id = "fam-marco-anna"
                c.famiglia[2].id = "fam-marco-pietro"
                c.famiglia[0].redditoNettoAnnuo = 16_000
                c.famiglia[0].lavoro = DatiLavoro(tipo: .dipendente, redditoLavoro: 21_000, crescitaReddito: 0.5,
                                                  anniContributi: 18, annoPrimoContributo: 2006)
                c.profilo.redditoNettoAnnuo = 31_500
                c.profilo.lavoro = DatiLavoro(tipo: .dipendente, crescitaReddito: 1, anniContributi: 22,
                                              annoPrimoContributo: 2004, montanteContributivo: 265_000, etaPensione: 67)
                c.profilo.propensione = .moderata
                c.profilo.orizzonteAnni = 15
                c.profilo.esperienza = .media
                c.profilo.obiettivi = "Il percorso di studi di Anna e la protezione della famiglia."
                c.bisogni.imposta(ValutazioneBisogno(area: .famiglia, importanza: .alta, orizzonte: .presto))
                c.bisogni.imposta(ValutazioneBisogno(area: .pensione, importanza: .media, orizzonte: .lungo))
                c.bisogni.imposta(ValutazioneBisogno(area: .patrimonio, importanza: .media, orizzonte: .medio))
                c.bisogni.eventi = [EventoVita(id: "evento-marco-studi", tipo: .studiFigli, anno: anno + 5,
                                               nota: "Università di Anna, forse fuori sede")]
                c.bisogni.aggiornatoIl = c.creatoIl
            case "laura":
                c.profilo.redditoLordoAnnuo = 41_000
                c.dataNascita = nascita(1985, 6, 30)
                c.professione = "Consulente di comunicazione (libera professionista)"
                c.statoCivile = .celibeNubile
                c.indirizzo = "Via Garibaldi 4, Verona"
                c.telefono = "+39 333 000 1003"
                c.canali = [.indipendente]
                c.profilo.propensione = .dinamica
                c.profilo.orizzonteAnni = 8
                c.profilo.esperienza = .media
                c.profilo.obiettivi = "Avviare un progetto indipendente e costruire la previdenza integrativa."
                c.profilo.lavoro = DatiLavoro(tipo: .gestioneSeparata, crescitaReddito: 1.5, anniContributi: 15,
                                              annoPrimoContributo: 2010, etaPensione: 67)
            case "andrea":
                c.profilo.redditoLordoAnnuo = 27_000
                c.dataNascita = nascita(1996, 1, 18)
                c.professione = "Infermiere"
                c.statoCivile = .celibeNubile
                c.indirizzo = "Via Roma 210, Padova"
                c.telefono = "+39 333 000 1004"
                c.canali = [.alleanza]
                c.profilo.propensione = .prudente
                c.profilo.esperienza = .nessuna
                c.profilo.obiettivi = "Da definire al primo incontro."
                // Primo incontro: non conosce il Ramo I che gli si propone, conosce la protezione
                c.profilo.esperienzaProdotti = griglia([voce(.ramoI, false, false, nil), voce(.protezione, true, false, true)],
                                                       capacita: .nessuna, il: c.creatoIl)
                c.profilo.lavoro = DatiLavoro(tipo: .dipendente, crescitaReddito: 1.5, anniContributi: 5,
                                              annoPrimoContributo: 2020, etaPensione: 67)
            case "sofia":
                c.profilo.redditoLordoAnnuo = 36_000
                c.dataNascita = nascita(1968, 10, 9)
                c.professione = "Dirigente scolastica"
                c.statoCivile = .vedovo
                c.indirizzo = "Piazza Duomo 3, Trento"
                c.telefono = "+39 333 000 1005"
                c.canali = [.alleanza, .indipendente]
                c.famiglia = [Familiare(nome: "Marta Romano", relazione: .figlia, dataNascita: nascita(1999, 5, 27))]
                c.famiglia[0].id = "fam-sofia-marta"
                c.famiglia[0].redditoNettoAnnuo = 19_000
                // Contributi dal 1993: sistema misto, la stima contributiva è solo indicativa
                c.profilo.lavoro = DatiLavoro(tipo: .dipendente, crescitaReddito: 0.5, anniContributi: 33,
                                              annoPrimoContributo: 1993, etaPensione: 67)
                c.profilo.propensione = .prudente
                c.profilo.orizzonteAnni = 12
                c.profilo.esperienza = .elevata
                c.profilo.obiettivi = "Un viaggio da ricordare e una pensione serena."
                // Griglia piena: esperienza ampia, capacità di perdita media
                c.profilo.esperienzaProdotti = griglia([
                    voce(.ramoI, true, true, true), voce(.ramoIII, true, false, true), voce(.multiramo, true, false, nil),
                    voce(.fondiETF, true, true, true), voce(.titoli, true, true, true), voce(.previdenza, true, false, true),
                    voce(.protezione, true, true, true),
                ], capacita: .media, il: c.creatoIl)
            default:
                break
            }
            elenco[i] = c
        }
    }

    static func appuntamenti() -> [Appuntamento] {
        [
            Appuntamento(id: "event-giulia-analisi", clienteId: "giulia", titolo: "Analisi delle posizioni in essere", inizio: data(-6, 17, 0),
                         durataMinuti: 60, luogo: "In studio",
                         note: "Raccolti estratti conto, polizze e piano del mutuo.", stato: .concluso,
                         tipo: .analisi),
            Appuntamento(id: "event-giulia", clienteId: "giulia", titolo: "Il punto sul progetto casa", inizio: data(0, 9, 30),
                         durataMinuti: 45, luogo: "In studio",
                         note: "Riprendere gli obiettivi, la situazione attuale e concordare il prossimo passo.", stato: .pianificato,
                         tipo: .revisione),
            Appuntamento(id: "event-marco", clienteId: "marco", titolo: "Nuovi progetti di famiglia", inizio: data(0, 11, 0),
                         durataMinuti: 60, luogo: "Videochiamata",
                         note: "Preparare una presentazione con il riepilogo degli obiettivi.", stato: .pianificato,
                         tipo: .analisi, canale: .alleanza),
            Appuntamento(id: "event-laura", clienteId: "laura", titolo: "Un progetto tutto suo", inizio: data(1, 10, 0),
                         durataMinuti: 45, luogo: "In studio",
                         note: "Raccogliere le nuove priorità professionali.", stato: .pianificato,
                         tipo: .proposta, canale: .indipendente, posizioneId: "pos-laura-infortuni-e-invalidità-professionale"),
            Appuntamento(id: "event-andrea", clienteId: "andrea", titolo: "Il nostro primo incontro", inizio: data(2, 15, 0),
                         durataMinuti: 60, luogo: "In studio",
                         note: "Partire dalle domande e dalla storia personale.", stato: .pianificato,
                         tipo: .primoIncontro),
            Appuntamento(id: "event-sofia", clienteId: "sofia", titolo: "Uno sguardo ai prossimi mesi", inizio: data(3, 11, 30),
                         durataMinuti: 30, luogo: "Telefonata",
                         note: "Aggiornare insieme le priorità.", stato: .pianificato,
                         tipo: .telefonata),
            Appuntamento(id: "event-giulia-previdenza", clienteId: "giulia", titolo: "Proposta di previdenza integrativa", inizio: data(7, 18, 0),
                         durataMinuti: 45, luogo: "In studio",
                         note: "Confrontare il piano proposto con il TFR lasciato in azienda.", stato: .pianificato,
                         tipo: .proposta, canale: .alleanza, posizioneId: "pos-giulia-piano-previdenziale-integrativo"),
            Appuntamento(id: "event-marco-infortuni", clienteId: "marco", titolo: "Rinnovo della copertura infortuni", inizio: data(9, 16, 30),
                         durataMinuti: 30, luogo: "Telefonata",
                         note: "Verificare se i capitali sono ancora adeguati al nucleo familiare.", stato: .pianificato,
                         tipo: .revisione, canale: .alleanza, posizioneId: "pos-marco-infortuni-famiglia"),
        ]
    }

    static func attivita() -> [Attivita] {
        [
            Attivita(id: "task-casa", clienteId: "giulia", titolo: "Preparare il riepilogo per l’incontro", scadenza: data(0), priorita: .alta, completata: false,
                     appuntamentoId: "event-giulia"),
            Attivita(id: "task-dati", clienteId: "giulia", titolo: "Verificare i dati delle spese mensili", scadenza: data(1), priorita: .normale, completata: false),
            Attivita(id: "task-marco", clienteId: "marco", titolo: "Rivedere la presentazione degli obiettivi", scadenza: data(0), priorita: .alta, completata: false,
                     appuntamentoId: "event-marco"),
            Attivita(id: "task-laura", clienteId: "laura", titolo: "Raccogliere le domande sul progetto", scadenza: data(1), priorita: .normale, completata: false),
            Attivita(id: "task-andrea", clienteId: "andrea", titolo: "Preparare la scheda del primo incontro", scadenza: data(2), priorita: .bassa, completata: false),
            Attivita(id: "task-done", clienteId: "giulia", titolo: "Aggiornare le note dell’ultimo colloquio", scadenza: data(-3), priorita: .normale, completata: true),
        ]
    }

    /// Incontri di prova: uno concluso con Giulia, uno da preparare per quello di oggi.
    static func incontri() -> [Incontro] {
        var concluso = Incontro(clienteId: "giulia", titolo: "Analisi delle posizioni in essere", data: data(-6, 17, 0),
                                appuntamentoId: "event-giulia-analisi")
        concluso.id = "incontro-giulia-analisi"
        concluso.stato = .concluso
        concluso.preoccupazioni = "Il mutuo: se succedesse qualcosa a uno dei due, Luca da solo non ce la farebbe con la rata."
        concluso.progetti = "Comprare un trilocale in città nel \(Calendar(identifier: .gregorian).component(.year, from: Date()) + 3). Forse un figlio tra qualche anno."
        concluso.esperienza = "Nel 2020 ha venduto in perdita un fondo azionario: preferisce andare per gradi."
        concluso.appunti = "Raccolti estratti conto, polizze e piano del mutuo. L'ETF le piace, il fondo obbligazionario meno."
        concluso.decisioni = "Preparare il confronto tra il piano previdenziale Alleanza e il fondo pensione aperto. Verificare i capitali della temporanea caso morte."
        concluso.prossimaAttivita = "Preparare il confronto per la previdenza"
        concluso.aggiornatoIl = data(-6, 18, 0)
        var oggi = Incontro(clienteId: "giulia", titolo: "Il punto sul progetto casa", data: data(0, 9, 30), appuntamentoId: "event-giulia")
        oggi.id = "incontro-giulia-casa"
        oggi.temi = [.risparmio, .protezione]
        return [concluso, oggi]
    }

    /// Documenti di prova: un KID, una polizza e un estratto conto con testo inventato (nessun file sul disco).
    static func documenti() -> [Documento] {
        var kid = Documento(clienteId: "giulia", titolo: "KID · Fondo pensione aperto Orizzonte", tipo: .kid)
        kid.id = "doc-giulia-kid"
        kid.pagine = testoDocumento("doc-giulia-kid")?.count ?? 0
        kid.dimensione = 184_320
        kid.importatoIl = data(-2, 16, 40)
        kid.lettura = .letto
        kid.campi = EstrattoreDocumento.conRegole(testoDocumento("doc-giulia-kid") ?? [])
        var polizza = Documento(clienteId: "marco", titolo: "Polizza Infortuni famiglia", tipo: .polizza)
        polizza.id = "doc-marco-polizza"
        polizza.pagine = testoDocumento("doc-marco-polizza")?.count ?? 0
        polizza.dimensione = 402_115
        polizza.importatoIl = data(-12, 11, 5)
        polizza.lettura = .letto
        polizza.pagineOCR = 1
        polizza.campi = EstrattoreDocumento.conRegole(testoDocumento("doc-marco-polizza") ?? []).map { c in
            var x = c
            x.confermato = true
            return x
        }
        polizza.posizioneId = "pos-marco-infortuni-famiglia"
        var estratto = Documento(clienteId: "giulia", titolo: "Estratto conto · Piano di risparmio rivalutabile", tipo: .estrattoConto)
        estratto.id = "doc-giulia-estratto"
        estratto.pagine = testoDocumento("doc-giulia-estratto")?.count ?? 0
        estratto.dimensione = 96_512
        estratto.importatoIl = data(-1, 10, 15)
        estratto.lettura = .letto
        estratto.campi = EstrattoreDocumento.conRegole(testoDocumento("doc-giulia-estratto") ?? [])
        return [kid, polizza, estratto]
    }

    /// Testo dei documenti di prova, pagina per pagina.
    static func testoDocumento(_ id: String) -> [String]? {
        switch id {
        case "doc-giulia-kid":
            return [
                """
                Documento contenente le informazioni chiave
                Scopo: il presente documento contiene informazioni chiave relative a questo prodotto d'investimento.
                Prodotto: Fondo pensione aperto Orizzonte, comparto Bilanciato
                Ideatore del PRIIP: Orizzonte SGR S.p.A.
                Tipo: Fondo pensione aperto a contribuzione definita
                Cos'è questo prodotto? Il comparto investe in obbligazioni e azioni dei mercati internazionali.
                """,
                """
                Quali sono i rischi e qual è il potenziale rendimento?
                Abbiamo classificato questo prodotto nella classe di rischio 3 su 7, che corrisponde alla classe di rischio media-bassa.
                Periodo di detenzione raccomandato: 15 anni
                Scenari di performance
                Scenario moderato  Possibile rimborso al netto dei costi 13.450 €  Rendimento medio per ciascun anno 3,2%
                """,
                """
                Quali sono i costi?
                Costi di ingresso: non applichiamo costi di ingresso, 0,00%
                Costi di uscita: 0,00%
                Commissioni di gestione e altri costi amministrativi o di esercizio: 0,85% del valore dell'investimento all'anno
                Incidenza annuale dei costi: 0,95% ogni anno
                """,
            ]
        case "doc-marco-polizza":
            return [
                """
                ALLEANZA ASSICURAZIONI S.p.A.
                Polizza n. AL-2025-551203  Infortuni famiglia
                Contraente: Marco Bianchi
                Assicurato: Marco Bianchi e nucleo familiare
                Beneficiari: gli assicurati o i loro eredi legittimi
                Decorrenza: 01/12/2025
                Scadenza: 01/12/2026
                Capitale assicurato: 150.000,00
                Premio annuo: 380,00
                """,
            ]
        case "doc-giulia-estratto":
            // Diciotto mesi fa: un valore più vecchio dello storico di prova, da aggiungere tra i valori passati
            let quando = Formati.dataBreve.string(from: data(-548))
            return [
                """
                Alleanza Assicurazioni S.p.A.
                Estratto conto annuale della polizza
                Prodotto: Piano di risparmio rivalutabile
                Polizza n. AL-2022-104851
                Contraente: Giulia Rossi
                Situazione al \(quando)
                Valore di riscatto al \(quando): € 4.712,40
                Totale premi versati: € 4.500,00
                Rendimento riconosciuto nell'anno dalla gestione separata: 2,1%
                """,
            ]
        default:
            return nil
        }
    }

    /// Schede prodotto di prova (condizioni inventate: vanno sostituite con i KID ufficiali).
    static func prodotti() -> [Prodotto] {
        func p(_ id: String, _ nome: String, _ canale: Canale, _ area: AreaPosizione, _ configura: (inout Prodotto) -> Void) -> Prodotto {
            var x = Prodotto(nome: nome, canale: canale, area: area)
            x.id = id
            x.verificatoIl = data(-40)
            x.fonte = "Esempio didattico Prisma · sostituire con il KID ufficiale"
            configura(&x)
            return x
        }
        let alleanza = "Alleanza Assicurazioni"
        return [
            p("prodotto-risparmio-rivalutabile", "Piano di risparmio rivalutabile", .alleanza, .risparmio) {
                $0.emittente = alleanza; $0.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"
                $0.rendimentoAtteso = 2.5; $0.costoIngresso = 3; $0.costoAnnuo = 1.2; $0.aliquotaFiscale = 20; $0.sri = 2
                $0.garanzie = "Capitale garantito a scadenza e in caso di decesso; consolidamento annuo dei rendimenti."
                $0.liquidabilita = "Riscatto dopo il primo anno, con penali decrescenti fino al quinto."
                $0.periodoRaccomandato = 10
            },
            p("prodotto-previdenza-pip", "Piano previdenziale integrativo", .alleanza, .previdenza) {
                $0.emittente = alleanza; $0.tipologia = "Piano individuale pensionistico (PIP)"
                $0.rendimentoAtteso = 3.5; $0.costoIngresso = 2; $0.costoAnnuo = 1.4; $0.aliquotaFiscale = 15; $0.sri = 3
                $0.garanzie = "Gestione separata con garanzia di restituzione dei versamenti al pensionamento."
                $0.liquidabilita = "Anticipazioni e riscatti nei casi previsti dalla normativa sulla previdenza complementare."
            },
            p("prodotto-multiramo", "Polizza multiramo", .alleanza, .investimento) {
                $0.emittente = alleanza; $0.tipologia = "Polizza multiramo (Ramo I e Ramo III)"
                // Rendimento complessivo 4,5% = 0,4 × 3,0 (gestione separata) + 0,6 × 5,5 (fondi)
                $0.rendimentoAtteso = 4.5; $0.costoIngresso = 1; $0.costoAnnuo = 1.8; $0.aliquotaFiscale = 24; $0.sri = 3
                // Le due parti: tutti i campi della multiramo, così la prova di backup copre le CodingKeys della scheda
                $0.quotaGestioneSeparata = 40; $0.quotaGestioneMinima = 30; $0.quotaGestioneMassima = 70
                $0.rendimentoGestione = 3.0; $0.trattenuto = 1.3; $0.minimoGarantito = 0; $0.consolidamento = true
                $0.rendimentoFondi = 5.5; $0.costoFondi = 2.3; $0.sriFondi = 4; $0.volatilitaFondi = 14; $0.quotaAzionariaFondi = 58
                $0.titoliStatoGestione = 60; $0.titoliStatoFondi = 10; $0.ribilanciamento = false
                $0.garanzie = "Solo la parte in gestione separata è garantita."
                $0.liquidabilita = "Riscatto totale o parziale dopo un anno."
                $0.verificatoIl = data(-420)
            },
            p("prodotto-tcm", "Temporanea caso morte", .alleanza, .protezione) {
                $0.emittente = alleanza; $0.tipologia = "Temporanea caso morte a capitale costante"
                $0.garanzie = "Capitale ai beneficiari in caso di decesso nel periodo di copertura."
                $0.liquidabilita = "Nessun valore di riscatto."
            },
            p("prodotto-etf-globale", "ETF azionario globale", .indipendente, .investimento) {
                $0.emittente = "Emittente ETF"; $0.tipologia = "ETF a replica fisica, piano di accumulo"
                $0.rendimentoAtteso = 5; $0.costoAnnuo = 0.2; $0.aliquotaFiscale = 26; $0.sri = 4
                $0.garanzie = "Nessuna garanzia di capitale."
                $0.liquidabilita = "Liquidabile in borsa ogni giorno di mercato aperto."
                $0.incidenzaCostiKID = 0.2; $0.periodoRaccomandato = 5
            },
            p("prodotto-fondo-pensione", "Fondo pensione aperto", .indipendente, .previdenza) {
                $0.emittente = "Gestore indipendente"; $0.tipologia = "Fondo pensione aperto, comparto bilanciato"
                $0.rendimentoAtteso = 4; $0.costoAnnuo = 0.8; $0.aliquotaFiscale = 15; $0.sri = 3
                $0.garanzie = "Comparto garantito disponibile a richiesta."
                $0.liquidabilita = "Anticipazioni e riscatti nei casi previsti dalla normativa."
            },
            p("prodotto-obbligazionario", "Fondo obbligazionario euro", .indipendente, .investimento) {
                $0.emittente = "SGR indipendente"; $0.tipologia = "Fondo comune obbligazionario"
                $0.rendimentoAtteso = 3; $0.costoAnnuo = 1.1; $0.aliquotaFiscale = 20; $0.sri = 2
                $0.liquidabilita = "Rimborso in pochi giorni lavorativi."
                $0.incidenzaCostiKID = 1.15; $0.periodoRaccomandato = 3
            },
        ]
    }

    /// Obiettivi di prova di Giulia e Marco.
    /// Orizzonte Valore di Alleanza: condizioni dal prospetto illustrativo di ottobre 2026
    /// (KID 30% Gestione separata – 70% Fondo Interno, 13/07/2026). Da verificare sui documenti ufficiali.
    static func orizzonteValore() -> Prodotto {
        var x = Prodotto(nome: "Orizzonte Valore di Alleanza", canale: .alleanza, area: .investimento)
        x.id = "prodotto-orizzonte-valore"
        x.emittente = "Alleanza Assicurazioni"
        x.tipologia = "Polizza multiramo a premio unico"
        x.rendimentoAtteso = 4.7
        x.costoIngresso = 1
        x.costoAnnuo = 2.31
        x.aliquotaFiscale = 24.8
        x.sri = 3
        x.garanzie = "In caso di decesso nei primi 10 anni almeno i premi investiti; dopo, la parte in Gestione separata."
        x.liquidabilita = "Riscatto dal 13° mese, con penale del 3,5%, 2,5% e 1,0% nel 2°, 3° e 4° anno; poi senza penali."
        x.fonte = "KID 30% GS – 70% FI (13/07/2026), DIP aggiuntivo IBIP, Condizioni mod. 10320671"
        x.verificatoIl = data(-7)
        var gs = ComponenteContratto(tipo: .gestioneSeparata, nome: "Fondo Euro San Giorgio", quota: 30)
        gs.id = "gs-san-giorgio"
        gs.trattenuto = 1.30
        gs.titoliStato = 30.5
        // «La rivalutazione può essere anche negativa»: niente consolidamento annuo
        gs.consolidamento = false
        gs.descrizione = "La parte stabile: investe soprattutto in titoli di Stato e obbligazioni di buona qualità. Ogni anno si rivaluta con il rendimento della gestione, meno l'1,30% trattenuto dalla Compagnia. Negli ultimi anni il rendimento lordo è stato intorno al 3%, ma la rivalutazione può essere anche negativa."
        gs.caratteristiche = "Rivalutazione riconosciuta = rendimento lordo − 1,30%; può essere anche negativa. Periodo di osservazione 1° novembre – 31 ottobre."
        gs.storico = [PuntoStorico(etichetta: "2020", valore: 3.05), PuntoStorico(etichetta: "2021", valore: 2.84),
                      PuntoStorico(etichetta: "2022", valore: 2.82), PuntoStorico(etichetta: "2023", valore: 3.02),
                      PuntoStorico(etichetta: "2024", valore: nil, nota: "Dato non reperito nelle fonti pubbliche consultate."),
                      PuntoStorico(etichetta: "2025", valore: 3.15)]
        var fi = ComponenteContratto(tipo: .fondoInterno, nome: "Allocazione Dinamica", quota: 70)
        fi.id = "fi-allocazione-dinamica"
        fi.commissione = 1.70
        fi.costiSottostanti = 0.99
        fi.bollo = true
        // Volatilità media annua attesa dal Regolamento; azioni dal 50% al 100%, al centro il 75%
        fi.volatilita = 12
        fi.quotaAzionaria = 75
        fi.descrizione = "Il motore della crescita: un fondo flessibile che investe dal 50% al 100% in azioni dei mercati internazionali. Il valore delle quote sale e scende con le borse. La commissione di gestione (1,70% l'anno) è già compresa nel valore delle quote."
        fi.caratteristiche = "Fondo flessibile con azioni dal 50% al 100%. Volatilità media annua attesa: 12% (Regolamento). I valori della quota sono già al netto dei costi del fondo."
        fi.storico = [PuntoStorico(etichetta: "Avvio, maggio 2025", valore: 10.000), PuntoStorico(etichetta: "31/12/2025", valore: 10.611),
                      PuntoStorico(etichetta: "12/10/2026", valore: 11.806)]
        var c = CondizioniContratto()
        c.versione = "versione Base, senza copertura complementare infortuni"
        c.componenti = [gs, fi]
        c.costoIngresso = 1
        c.costoIngressoMassimo = 200
        c.mesiBloccoRiscatto = 12
        c.penali = [3.5, 2.5, 1.0]
        c.periodoRaccomandato = 10
        c.anniKID = 5
        c.esempioKID = "Il KID usa un esempio di € 10.000 con costo di ingresso dell'1% (€ 100)."
        c.scenariKID = [ScenarioKID(nome: "Stress", unAnno: -32.64, periodo: -8.54),
                        ScenarioKID(nome: "Sfavorevole", unAnno: -12.38, periodo: -1.10),
                        ScenarioKID(nome: "Moderato", unAnno: 0.97, periodo: 5.06),
                        ScenarioKID(nome: "Favorevole", unAnno: 15.48, periodo: 7.67)]
        c.dataDocumenti = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 13))
        c.garantito = [
            "In caso di decesso nei primi 10 anni i beneficiari ricevono il valore del contratto (quote maggiorate dello 0,2%) e comunque non meno dei premi investiti, ridotti in proporzione agli eventuali riscatti parziali.",
            "Dopo 10 anni resta garantita, in caso di decesso, la parte in Gestione separata.",
            "Somme ai beneficiari esenti da imposta di successione e, nei limiti di legge, non pignorabili.",
        ]
        c.nonGarantito = [
            "In caso di riscatto non c'è alcuna garanzia: si può incassare meno di quanto versato.",
            "Il valore delle quote del Fondo Interno dipende dai mercati e può scendere.",
            "La rivalutazione della Gestione separata può essere anche negativa.",
        ]
        c.riscattoParziale = "Dopo 12 mesi si può chiedere un riscatto parziale: minimo € 1.000, con almeno € 5.000 che restano investiti. La penale si applica solo alla parte riscattata; il resto continua a lavorare."
        c.recesso = "Entro 30 giorni dalla conclusione del contratto si può recedere: viene restituito il premio, con la parte nel Fondo Interno al valore corrente delle quote."
        c.fonti = "Alleanza Assicurazioni: KID «30% Gestione separata – 70% Fondo Interno» (13/07/2026); DIP aggiuntivo IBIP (13/07/2026); Condizioni di assicurazione mod. 10320671 (13/07/2026); Regolamento e Rendiconto al 31/12/2025 del Fondo Interno Allocazione Dinamica; valore della quota pubblicato su alleanza.it al 12/10/2026; Prospetto annuale della Gestione separata Fondo Euro San Giorgio (28/11/2025)."
        x.condizioni = c
        // Combinazione fissa: il KID è «30% GS – 70% FI»
        x.quotaGestioneMinima = 30
        x.quotaGestioneMassima = 30
        return x
    }

    /// Valutazione di prova: Marco ed Elena valutano 50.000 € su Orizzonte Valore.
    static func valutazioni() -> [ValutazioneInvestimento] {
        var v = ValutazioneInvestimento(clienteId: "marco", intestatari: "Marco ed Elena Bianchi",
                                        prodottoId: "prodotto-orizzonte-valore", premio: 50_000)
        v.id = "val-marco-orizzonte"
        v.data = data(-2)
        v.creataIl = data(-2)
        v.anni = 5
        v.esigenza = "Volete far crescere € 50.000, ma potreste averne bisogno già tra uno o due anni."
        v.notaScenarioCentrale = "Su base annua il fondo ha reso circa +12,7%. È però una storia di poco più di un anno, in un periodo molto favorevole per le borse: per prudenza lo scenario intermedio usa un rendimento di circa la metà."
        v.consiglio = "La penale del 3,5% assorbe circa tre quarti della crescita del primo anno. Se potete, aspettate almeno il 25° mese."
        let gs = "gs-san-giorgio", fi = "fi-allocazione-dinamica"
        v.scenari = [
            ScenarioValutazione(tipo: .favorevole, rendimenti: [gs: 3.40, fi: 14.0],
                                perche: "Tra il rendimento del fondo dal lancio (+12,7% annuo) e il ritmo 2026 (≈ +14,6% annuo); Gestione separata sopra il massimo recente.",
                                racconto: "Il fondo cresce ogni anno a un ritmo vicino a quello degli ultimi mesi (circa +14,6% su base annua nel 2026)."),
            ScenarioValutazione(tipo: .intermedio, rendimenti: [gs: 3.10, fi: 6.0],
                                perche: "Vicino allo scenario moderato del KID; Gestione separata poco sopra la media degli anni disponibili (2,98%).",
                                racconto: "Il fondo cresce a un ritmo vicino allo scenario moderato del KID, il documento ufficiale della Compagnia."),
            ScenarioValutazione(tipo: .sfavorevole, rendimenti: [gs: 2.60, fi: -3.0],
                                perche: "Calo costante del fondo, circa −14% in 5 anni; Gestione separata sotto il minimo recente (2,82%).",
                                racconto: "Il fondo perde un po' ogni anno: circa il 14% in cinque anni, senza recupero."),
        ]
        return [v]
    }

    static func obiettivi() -> [Obiettivo] {
        var casa = Obiettivo(clienteId: "giulia", titolo: "Anticipo per la casa", area: .casa, importo: 60_000, scadenza: anni(3))
        casa.id = "obiettivo-giulia-casa"
        casa.priorita = .alta
        casa.posizioniCollegate = ["pos-giulia-conto-corrente-e-conto-deposito"]
        casa.rendimento = 2
        casa.note = "Trilocale in città: anticipo del 20% più notaio e spese."
        casa.creatoIl = data(-30)
        var serenita = Obiettivo(clienteId: "giulia", titolo: "Un margine di serenità", area: .salute, importo: 12_000, scadenza: anni(1))
        serenita.id = "obiettivo-giulia-riserva"
        serenita.accantonato = 4_000
        serenita.creatoIl = data(-30)
        var studi = Obiettivo(clienteId: "marco", titolo: "Università di Anna", area: .famiglia, importo: 45_000, scadenza: anni(5))
        studi.id = "obiettivo-marco-studi"
        studi.priorita = .alta
        studi.accantonato = 6_000
        studi.rendimento = 2.5
        studi.note = "Forse fuori sede: alloggio compreso."
        studi.creatoIl = data(-25)
        return [casa, serenita, studi]
    }

    /// Scenari di prova nel simulatore.
    static func simulazioni() -> [Simulazione] {
        func s(_ id: String, _ cliente: String, _ titolo: String, _ configura: (inout Simulazione) -> Void) -> Simulazione {
            var x = Simulazione(clienteId: cliente, titolo: titolo)
            x.id = id
            x.creataIl = data(-10)
            configura(&x)
            return x
        }
        return [
            s("sim-giulia-casa", "giulia", "Anticipo casa in 5 anni") {
                $0.capitale = 15_000; $0.versamentoMensile = 400; $0.anni = 5; $0.rendimento = 2.5; $0.costoAnnuo = 0.8
                $0.canale = .indipendente
            },
            s("sim-giulia-prudente", "giulia", "Accumulo prudente 10 anni") {
                $0.capitale = 10_000; $0.versamentoMensile = 200; $0.anni = 10; $0.rendimento = 2; $0.costoAnnuo = 1.2
                $0.costoIngresso = 2; $0.aliquota = 12.5; $0.canale = .alleanza
            },
            s("sim-giulia-dinamico", "giulia", "Accumulo dinamico 10 anni") {
                $0.capitale = 10_000; $0.versamentoMensile = 200; $0.anni = 10; $0.rendimento = 5; $0.costoAnnuo = 0.3
                $0.canale = .indipendente
            },
        ]
    }

    /// Posizioni di prova (prodotti e importi inventati), in essere e in proposta, sui due canali.
    static func posizioni() -> [Posizione] {
        func p(_ cliente: String, _ canale: Canale, _ stato: StatoPosizione, _ area: AreaPosizione, _ nome: String,
               _ configura: (inout Posizione) -> Void) -> Posizione {
            var x = Posizione(clienteId: cliente, canale: canale, stato: stato, area: area, nome: nome)
            x.id = "pos-\(cliente)-\(nome.lowercased().replacingOccurrences(of: " ", with: "-"))"
            x.dataValore = data(-5)
            // Date a secondi interi: l'archivio JSON non conserva le frazioni di secondo
            x.creataIl = data(-20)
            configura(&x)
            return x
        }
        let alleanza = "Alleanza Assicurazioni"
        return conRilevazioni([
            // Giulia Rossi: entrambi i canali
            p("giulia", .alleanza, .inEssere, .risparmio, "Piano di risparmio rivalutabile") {
                $0.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"; $0.emittente = alleanza
                $0.numeroContratto = "AL-2022-104851"; $0.contraente = "Giulia Rossi"; $0.assicurato = "Giulia Rossi"
                $0.beneficiari = "Eredi legittimi"; $0.decorrenza = anni(-4); $0.scadenza = anni(11)
                $0.premio = 150; $0.frequenza = .mensile; $0.totaleVersato = 7_200; $0.controvalore = 7_650
                $0.rendimentoAtteso = 2.5; $0.costoIngresso = 3; $0.trattenuto = 1.2; $0.quotaTitoliStato = 60; $0.aliquotaFiscale = 20
                $0.garanzie = "Capitale garantito a scadenza e in caso di decesso; consolidamento annuo dei rendimenti."
                $0.minimoGarantito = 0; $0.consolidamento = true; $0.assicuratoId = "giulia"
            },
            p("giulia", .alleanza, .inEssere, .protezione, "Temporanea caso morte") {
                $0.tipologia = "Temporanea caso morte a capitale costante"; $0.emittente = alleanza
                $0.numeroContratto = "AL-2023-220417"; $0.contraente = "Giulia Rossi"; $0.assicurato = "Giulia Rossi"
                $0.beneficiari = "Luca Ferri"; $0.decorrenza = anni(-2); $0.scadenza = anni(20)
                $0.premio = 22; $0.frequenza = .mensile; $0.capitaleAssicurato = 150_000; $0.rischio = .vita
                $0.controvalore = 0
                $0.assicuratoId = "giulia"; $0.capitaleDecrescente = false
            },
            p("giulia", .indipendente, .inEssere, .investimento, "ETF azionario globale") {
                $0.tipologia = "ETF con piano di accumulo"; $0.emittente = "Banca online"
                $0.decorrenza = anni(-3); $0.versamentoIniziale = 20_000; $0.premio = 300; $0.frequenza = .mensile
                $0.totaleVersato = 30_800; $0.controvalore = 36_400
                $0.rendimentoAtteso = 5; $0.costoAnnuo = 0.2; $0.aliquotaFiscale = 26; $0.sri = 4
                $0.quotaAzionaria = 100
            },
            p("giulia", .indipendente, .inEssere, .investimento, "Fondo obbligazionario euro") {
                $0.tipologia = "Fondo comune obbligazionario"; $0.emittente = "SGR indipendente"
                $0.decorrenza = anni(-2); $0.versamentoIniziale = 20_000; $0.totaleVersato = 20_000; $0.controvalore = 21_000
                $0.rendimentoAtteso = 3; $0.costoAnnuo = 1.1; $0.aliquotaFiscale = 20; $0.sri = 2
                $0.quotaAzionaria = 0
            },
            p("giulia", .indipendente, .inEssere, .liquidita, "Conto corrente e conto deposito") {
                $0.emittente = "Banca"; $0.controvalore = 24_000
            },
            p("giulia", .indipendente, .inEssere, .immobili, "Casa di abitazione") {
                $0.controvalore = 210_000
            },
            p("giulia", .indipendente, .inEssere, .debiti, "Mutuo casa") {
                $0.tipologia = "Mutuo a tasso fisso"; $0.emittente = "Banca"; $0.decorrenza = anni(-7); $0.scadenza = anni(18)
                $0.premio = 610; $0.frequenza = .mensile; $0.controvalore = 95_000
                // 95.000 € al 3,8% per 216 mesi: rata alla francese di circa 608 € (coerente con i 610 € indicati)
                $0.tassoDebito = 3.8
            },
            p("giulia", .alleanza, .proposta, .previdenza, "Piano previdenziale integrativo") {
                $0.tipologia = "Piano individuale pensionistico (PIP)"; $0.emittente = alleanza
                $0.contraente = "Giulia Rossi"; $0.assicurato = "Giulia Rossi"; $0.scadenza = anni(30)
                $0.premio = 200; $0.frequenza = .mensile
                $0.rendimentoAtteso = 3.5; $0.costoIngresso = 2; $0.costoAnnuo = 1.4; $0.aliquotaFiscale = 15
                $0.esito = .presentata; $0.note = "Da rivedere dopo l'acquisto della casa."
                $0.prodottoId = "prodotto-previdenza-pip"
            },

            // Marco Bianchi: solo Alleanza
            p("marco", .alleanza, .inEssere, .risparmio, "Polizza rivalutabile a premio unico") {
                $0.tipologia = "Polizza rivalutabile a premio unico (Ramo I)"; $0.emittente = alleanza
                $0.numeroContratto = "AL-2020-055120"; $0.contraente = "Marco Bianchi"; $0.assicurato = "Marco Bianchi"
                $0.decorrenza = anni(-6); $0.scadenza = anni(6); $0.versamentoIniziale = 50_000
                $0.totaleVersato = 50_000; $0.controvalore = 54_300
                $0.rendimentoAtteso = 2.8; $0.trattenuto = 1.3; $0.quotaTitoliStato = 60; $0.aliquotaFiscale = 20
                $0.minimoGarantito = 0; $0.consolidamento = true; $0.assicuratoId = "marco"
            },
            p("marco", .alleanza, .inEssere, .investimento, "Polizza multiramo") {
                $0.tipologia = "Polizza multiramo (Ramo I e Ramo III)"; $0.emittente = alleanza
                $0.numeroContratto = "AL-2021-118842"; $0.decorrenza = anni(-5); $0.versamentoIniziale = 60_000
                $0.totaleVersato = 60_000; $0.controvalore = 62_000
                // Rendimento complessivo 4,5% = 0,4 × 3,0 + 0,6 × 5,5: lo stesso numero nel modulo e nel dettaglio.
                // Costo annuo 2,3%: le commissioni del contratto senza il trattenuto, che con le due parti valgono per
                // la parte in fondi (i costi dei fondi non sono indicati a parte). Così cambiare il costo annuo
                // cambia i costi di Marco, come si aspetta la prova di Eve sulle analisi del dossier.
                $0.rendimentoAtteso = 4.5; $0.costoAnnuo = 2.3; $0.aliquotaFiscale = 24; $0.sri = 3
                $0.quotaAzionaria = 35
                // Multiramo a due parti: 40% in gestione separata al 3,0% lordo (trattenuto 1,3, consolidata),
                // 60% nei fondi al 5,5% lordo con costi del 2,3%, SRI 4 (volatilità 14%, azioni 58%)
                $0.quotaGestioneSeparata = 40; $0.rendimentoGestione = 3.0; $0.trattenuto = 1.3; $0.minimoGarantito = 0
                $0.consolidamento = true; $0.rendimentoFondi = 5.5; $0.sriFondi = 4
                $0.volatilitaFondi = 14; $0.quotaAzionariaFondi = 58; $0.prodottoId = "prodotto-multiramo"
            },
            p("marco", .alleanza, .inEssere, .protezione, "Temporanea caso morte") {
                $0.tipologia = "Temporanea caso morte a capitale costante"; $0.emittente = alleanza
                $0.beneficiari = "Elena Bianchi"; $0.decorrenza = anni(-3); $0.scadenza = anni(15)
                $0.premio = 45; $0.frequenza = .mensile; $0.capitaleAssicurato = 300_000; $0.rischio = .vita; $0.controvalore = 0
                $0.assicuratoId = "marco"; $0.capitaleDecrescente = false
            },
            p("marco", .alleanza, .inEssere, .protezione, "Infortuni famiglia") {
                $0.tipologia = "Polizza infortuni del nucleo"; $0.emittente = alleanza
                $0.decorrenza = anni(-1); $0.scadenza = data(45); $0.premio = 380; $0.frequenza = .annuale
                $0.capitaleAssicurato = 200_000; $0.rischio = .infortuni; $0.controvalore = 0
                $0.note = "Rinnovo annuale: verificare le somme assicurate."
            },
            p("marco", .alleanza, .inEssere, .previdenza, "Piano individuale pensionistico") {
                $0.tipologia = "Piano individuale pensionistico (PIP)"; $0.emittente = alleanza
                $0.decorrenza = anni(-10); $0.scadenza = anni(20); $0.premio = 250; $0.frequenza = .mensile
                $0.totaleVersato = 30_000; $0.controvalore = 38_000; $0.contributiNonDedotti = 2_000
                $0.rendimentoAtteso = 3.2; $0.costoAnnuo = 1.5; $0.aliquotaFiscale = 15
                $0.quotaAzionaria = 20; $0.assicuratoId = "marco"
            },
            p("marco", .alleanza, .inEssere, .liquidita, "Liquidità") { $0.controvalore = 35_000 },
            p("marco", .alleanza, .inEssere, .immobili, "Casa di abitazione") { $0.controvalore = 280_000 },
            p("marco", .alleanza, .inEssere, .debiti, "Mutuo casa") {
                $0.tipologia = "Mutuo a tasso variabile"; $0.scadenza = anni(16); $0.premio = 890; $0.frequenza = .mensile
                $0.controvalore = 130_000
                // 130.000 € al 3,6% per 192 mesi: rata di circa 892 €; cointestato a metà con Elena
                $0.tassoDebito = 3.6; $0.quotaDebito = 50
            },
            p("marco", .alleanza, .proposta, .risparmio, "Piano per gli studi di Anna") {
                $0.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"; $0.emittente = alleanza
                $0.contraente = "Marco Bianchi"; $0.assicurato = "Anna Bianchi"; $0.scadenza = anni(6)
                $0.premio = 200; $0.frequenza = .mensile
                $0.rendimentoAtteso = 2.5; $0.costoIngresso = 3; $0.trattenuto = 1.2; $0.aliquotaFiscale = 20
                $0.esito = .bozza
            },

            // Laura Moretti: indipendente
            p("laura", .indipendente, .inEssere, .previdenza, "Fondo pensione aperto") {
                $0.tipologia = "Fondo pensione aperto, comparto bilanciato"; $0.emittente = "Gestore indipendente"
                $0.decorrenza = anni(-4); $0.scadenza = anni(26); $0.premio = 150; $0.frequenza = .mensile
                $0.quotaAzionaria = 50; $0.assicuratoId = "laura"
                // Trasferito da un fondo negoziale: gli anni di partecipazione contano dalla prima adesione
                $0.primaAdesione = anni(-17); $0.contributiNonDedotti = 0
                $0.totaleVersato = 14_400; $0.controvalore = 18_000
                $0.rendimentoAtteso = 4; $0.costoAnnuo = 0.8; $0.aliquotaFiscale = 15
            },
            p("laura", .indipendente, .inEssere, .investimento, "ETF azionario globale") {
                $0.tipologia = "ETF"; $0.emittente = "Banca online"; $0.decorrenza = anni(-3)
                $0.versamentoIniziale = 22_000; $0.totaleVersato = 22_000; $0.controvalore = 27_000
                $0.quotaAzionaria = 100
                $0.rendimentoAtteso = 5; $0.costoAnnuo = 0.2; $0.aliquotaFiscale = 26; $0.sri = 4
            },
            p("laura", .indipendente, .inEssere, .liquidita, "Liquidità") { $0.controvalore = 19_000 },
            p("laura", .indipendente, .inEssere, .debiti, "Prestito personale") {
                $0.scadenza = anni(2); $0.premio = 260; $0.frequenza = .mensile; $0.controvalore = 6_000
                // 6.000 € al 3,8% per 24 mesi: rata di circa 260 €
                $0.tassoDebito = 3.8
            },
            p("laura", .indipendente, .proposta, .protezione, "Infortuni e invalidità professionale") {
                $0.tipologia = "Polizza infortuni e invalidità permanente"; $0.emittente = "Compagnia (mercato)"
                $0.premio = 420; $0.frequenza = .annuale; $0.capitaleAssicurato = 150_000; $0.rischio = .invalidita
                $0.assicuratoId = "laura"
                $0.controvalore = 0; $0.esito = .bozza
            },

            // Andrea Conti: primo incontro, Alleanza
            p("andrea", .alleanza, .inEssere, .liquidita, "Liquidità") { $0.controvalore = 12_000 },
            p("andrea", .alleanza, .proposta, .risparmio, "Piano di risparmio rivalutabile") {
                $0.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"; $0.emittente = alleanza
                $0.scadenza = anni(15); $0.premio = 100; $0.frequenza = .mensile
                $0.minimoGarantito = 0; $0.consolidamento = true; $0.assicuratoId = "andrea"
                $0.penali = [2.5, 2, 1.5, 1]; $0.mesiBloccoRiscatto = 12
                $0.rendimentoAtteso = 2.5; $0.costoIngresso = 3; $0.trattenuto = 1.2; $0.aliquotaFiscale = 20
                $0.esito = .bozza
            },
            p("andrea", .alleanza, .proposta, .protezione, "Temporanea caso morte") {
                $0.tipologia = "Temporanea caso morte a capitale costante"; $0.emittente = alleanza
                $0.scadenza = anni(25); $0.premio = 12; $0.frequenza = .mensile; $0.capitaleAssicurato = 100_000
                $0.assicuratoId = "andrea"; $0.capitaleDecrescente = false
                $0.rischio = .vita; $0.controvalore = 0; $0.esito = .bozza
            },

            // Sofia Romano: entrambi i canali
            p("sofia", .alleanza, .inEssere, .risparmio, "Polizza rivalutabile") {
                $0.tipologia = "Polizza rivalutabile a premio unico (Ramo I)"; $0.emittente = alleanza
                $0.numeroContratto = "AL-2016-009311"; $0.decorrenza = anni(-10); $0.scadenza = data(70)
                $0.versamentoIniziale = 35_000; $0.totaleVersato = 35_000; $0.controvalore = 41_000
                $0.minimoGarantito = 1; $0.consolidamento = true; $0.assicuratoId = "sofia"
                $0.rendimentoAtteso = 2.5; $0.trattenuto = 1.3; $0.quotaTitoliStato = 60; $0.aliquotaFiscale = 20
                $0.note = "In scadenza: valutare il reinvestimento."
            },
            p("sofia", .alleanza, .inEssere, .protezione, "Non autosufficienza") {
                $0.tipologia = "Polizza LTC a vita intera"; $0.emittente = alleanza; $0.decorrenza = anni(-5)
                $0.premio = 600; $0.frequenza = .annuale; $0.capitaleAssicurato = 30_000; $0.rischio = .ltc; $0.controvalore = 0
                $0.assicuratoId = "sofia"
            },
            p("sofia", .indipendente, .inEssere, .investimento, "Portafoglio di fondi") {
                $0.tipologia = "Fondi comuni bilanciati"; $0.emittente = "SGR indipendenti"; $0.decorrenza = anni(-6)
                $0.versamentoIniziale = 28_000; $0.totaleVersato = 28_000; $0.controvalore = 32_000
                $0.quotaAzionaria = 50
                $0.rendimentoAtteso = 3.5; $0.costoAnnuo = 1.4; $0.aliquotaFiscale = 26; $0.sri = 3
            },
            p("sofia", .indipendente, .inEssere, .liquidita, "Liquidità") { $0.controvalore = 27_000 },
            p("sofia", .indipendente, .inEssere, .immobili, "Casa di abitazione") { $0.controvalore = 180_000 },
            p("sofia", .indipendente, .inEssere, .debiti, "Mutuo") { $0.scadenza = anni(8); $0.premio = 480; $0.frequenza = .mensile; $0.controvalore = 40_000
                $0.tassoDebito = 3.6 // 40.000 € al 3,6% per 96 mesi: rata di circa 480 €
            },
            p("sofia", .indipendente, .proposta, .investimento, "Obbligazionario a scadenza 2030") {
                $0.tipologia = "Fondo obbligazionario a scadenza"; $0.emittente = "SGR indipendente"
                $0.scadenza = anni(4); $0.versamentoIniziale = 40_000
                $0.rendimentoAtteso = 3.2; $0.costoAnnuo = 0.6; $0.aliquotaFiscale = 20; $0.sri = 2
                $0.quotaAzionaria = 0; $0.periodoRaccomandato = 4; $0.incidenzaCostiKID = 0.7
                $0.esito = .presentata; $0.note = "Ipotesi di reinvestimento della polizza in scadenza."
            },
        ])
    }

    /// Lo storico di prova: i valori di 12 e 6 mesi fa delle posizioni finanziarie in essere, ricavati
    /// all'indietro dal valore attuale con un andamento diverso per area (le azioni oscillano di più).
    static func conRilevazioni(_ elenco: [Posizione]) -> [Posizione] {
        elenco.map { p in
            guard p.stato == .inEssere, p.area.proiettabile, let valore = p.controvalore, let decorrenza = p.decorrenza else { return p }
            var x = p
            let versato = p.totaleVersato ?? p.versamentoIniziale
            // Andamento dei due semestri: il secondo più vivace per gli investimenti
            let semestri: (Double, Double) = p.area == .investimento ? (0.012, 0.034) : (0.011, 0.013)
            var rilevazioni: [Rilevazione] = []
            var v = valore
            var vers = versato
            for (mesi, crescita) in [(6, semestri.1), (12, semestri.0)] {
                let d = data(-mesi * 365 / 12)
                guard d > decorrenza else { break }
                let premi = min(p.premioAnnuo / 2, max(0, vers - p.versamentoIniziale))
                v = ((v - premi) / (1 + crescita)).rounded()
                vers -= premi
                rilevazioni.insert(Rilevazione(data: d, controvalore: v, versato: vers), at: 0)
            }
            x.rilevazioni = rilevazioni
            return x
        }
    }

    private static func anni(_ n: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .year, value: n, to: data(0)) ?? Date()
    }

    /// Le note del taccuino (dal template).
    static func note() -> [Nota] {
        func nota(_ id: String, _ cliente: String, _ titolo: String, _ testo: String, giorni: Int, ora: Int, fissata: Bool) -> Nota {
            Nota(id: id, clienteId: cliente, titolo: titolo, testo: testo, fissata: fissata,
                 creataIl: data(giorni, ora), aggiornataIl: data(giorni, ora, 40))
        }
        return [
            nota("nota-giulia", "giulia", "La casa è un nuovo inizio",
                 "Giulia vuole dare un nome concreto al suo progetto casa.\n\nPunti da riprendere:\n• Tempi desiderati e grado di flessibilità.\n• Spese mensili da verificare insieme.\n• Domande sul margine da tenere disponibile.\n\nProssimo passo: costruire un riepilogo comprensibile.",
                 giorni: -7, ora: 15, fissata: true),
            nota("nota-marco", "marco", "Le priorità della famiglia",
                 "Dare spazio al progetto di studi di Anna.\n\nPrima dei numeri, riprendere le aspettative. Portare una presentazione breve e chiara all'incontro di lunedì.",
                 giorni: -8, ora: 11, fissata: true),
            nota("nota-laura", "laura", "Più libertà nel proprio lavoro",
                 "Laura sta immaginando un'attività indipendente.\n\nRaccogliere domande, tempi e informazioni da approfondire. Nessuna decisione già presa.",
                 giorni: -9, ora: 9, fissata: false),
        ]
    }

    /// Oggi + `giorni`, all'ora indicata.
    private static func data(_ giorni: Int, _ ora: Int = 9, _ minuti: Int = 0) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let oggi = cal.startOfDay(for: Date())
        let giorno = cal.date(byAdding: .day, value: giorni, to: oggi) ?? oggi
        return cal.date(bySettingHour: ora, minute: minuti, second: 0, of: giorno) ?? giorno
    }
}
