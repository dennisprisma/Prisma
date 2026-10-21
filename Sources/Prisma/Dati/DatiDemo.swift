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
        let anno = Calendar(identifier: .gregorian).component(.year, from: Date())
        for i in elenco.indices {
            var c = elenco[i]
            c.consensi = Consensi(privacy: true, dataPrivacy: c.creatoIl, marketing: false)
            c.profilo.aggiornatoIl = c.creatoIl
            switch c.id {
            case "giulia":
                c.dataNascita = nascita(1989, 3, 14)
                c.professione = "Architetta"
                c.statoCivile = .convivente
                c.indirizzo = "Via dei Mille 12, Bologna"
                c.telefono = "+39 333 000 1001"
                c.canali = [.alleanza, .indipendente]
                c.famiglia = [Familiare(nome: "Luca Ferri", relazione: .convivente, dataNascita: nascita(1987, 7, 2))]
                c.profilo.propensione = .moderata
                c.profilo.orizzonteAnni = 10
                c.profilo.esperienza = .base
                c.profilo.obiettivi = "Anticipo per la nuova casa entro il 2029 e un margine di serenità."
                c.bisogni.imposta(ValutazioneBisogno(area: .casa, importanza: .alta, orizzonte: .presto))
                c.bisogni.imposta(ValutazioneBisogno(area: .pensione, importanza: .media, orizzonte: .lungo))
                c.bisogni.imposta(ValutazioneBisogno(area: .salute, importanza: .bassa, orizzonte: .medio))
                c.bisogni.eventi = [EventoVita(id: "evento-giulia-casa", tipo: .acquistoCasa, anno: anno + 3,
                                               nota: "Trilocale in città, anticipo del 20%")]
                c.bisogni.aggiornatoIl = c.creatoIl
            case "marco":
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
            case "andrea":
                c.dataNascita = nascita(1996, 1, 18)
                c.professione = "Infermiere"
                c.statoCivile = .celibeNubile
                c.indirizzo = "Via Roma 210, Padova"
                c.telefono = "+39 333 000 1004"
                c.canali = [.alleanza]
                c.profilo.propensione = .prudente
                c.profilo.esperienza = .nessuna
                c.profilo.obiettivi = "Da definire al primo incontro."
            case "sofia":
                c.dataNascita = nascita(1968, 10, 9)
                c.professione = "Dirigente scolastica"
                c.statoCivile = .vedovo
                c.indirizzo = "Piazza Duomo 3, Trento"
                c.telefono = "+39 333 000 1005"
                c.canali = [.alleanza, .indipendente]
                c.famiglia = [Familiare(nome: "Marta Romano", relazione: .figlia, dataNascita: nascita(1999, 5, 27))]
                c.profilo.propensione = .prudente
                c.profilo.orizzonteAnni = 12
                c.profilo.esperienza = .elevata
                c.profilo.obiettivi = "Un viaggio da ricordare e una pensione serena."
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
            },
            p("prodotto-previdenza-pip", "Piano previdenziale integrativo", .alleanza, .previdenza) {
                $0.emittente = alleanza; $0.tipologia = "Piano individuale pensionistico (PIP)"
                $0.rendimentoAtteso = 3.5; $0.costoIngresso = 2; $0.costoAnnuo = 1.4; $0.aliquotaFiscale = 15; $0.sri = 3
                $0.garanzie = "Gestione separata con garanzia di restituzione dei versamenti al pensionamento."
                $0.liquidabilita = "Anticipazioni e riscatti nei casi previsti dalla normativa sulla previdenza complementare."
            },
            p("prodotto-multiramo", "Polizza multiramo", .alleanza, .investimento) {
                $0.emittente = alleanza; $0.tipologia = "Polizza multiramo (Ramo I e Ramo III)"
                $0.rendimentoAtteso = 4; $0.costoIngresso = 1; $0.costoAnnuo = 1.8; $0.aliquotaFiscale = 24; $0.sri = 3
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
            },
        ]
    }

    /// Obiettivi di prova di Giulia e Marco.
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
        return [
            // Giulia Rossi: entrambi i canali
            p("giulia", .alleanza, .inEssere, .risparmio, "Piano di risparmio rivalutabile") {
                $0.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"; $0.emittente = alleanza
                $0.numeroContratto = "AL-2022-104851"; $0.contraente = "Giulia Rossi"; $0.assicurato = "Giulia Rossi"
                $0.beneficiari = "Eredi legittimi"; $0.decorrenza = anni(-4); $0.scadenza = anni(11)
                $0.premio = 150; $0.frequenza = .mensile; $0.totaleVersato = 7_200; $0.controvalore = 7_650
                $0.rendimentoAtteso = 2.5; $0.costoIngresso = 3; $0.costoAnnuo = 1.2; $0.aliquotaFiscale = 20
                $0.garanzie = "Capitale garantito a scadenza e in caso di decesso; consolidamento annuo dei rendimenti."
            },
            p("giulia", .alleanza, .inEssere, .protezione, "Temporanea caso morte") {
                $0.tipologia = "Temporanea caso morte a capitale costante"; $0.emittente = alleanza
                $0.numeroContratto = "AL-2023-220417"; $0.contraente = "Giulia Rossi"; $0.assicurato = "Giulia Rossi"
                $0.beneficiari = "Luca Ferri"; $0.decorrenza = anni(-2); $0.scadenza = anni(20)
                $0.premio = 22; $0.frequenza = .mensile; $0.capitaleAssicurato = 150_000; $0.rischio = .vita
                $0.controvalore = 0
            },
            p("giulia", .indipendente, .inEssere, .investimento, "ETF azionario globale") {
                $0.tipologia = "ETF con piano di accumulo"; $0.emittente = "Banca online"
                $0.decorrenza = anni(-3); $0.versamentoIniziale = 20_000; $0.premio = 300; $0.frequenza = .mensile
                $0.totaleVersato = 30_800; $0.controvalore = 36_400
                $0.rendimentoAtteso = 5; $0.costoAnnuo = 0.2; $0.aliquotaFiscale = 26; $0.sri = 4
            },
            p("giulia", .indipendente, .inEssere, .investimento, "Fondo obbligazionario euro") {
                $0.tipologia = "Fondo comune obbligazionario"; $0.emittente = "SGR indipendente"
                $0.decorrenza = anni(-2); $0.versamentoIniziale = 20_000; $0.totaleVersato = 20_000; $0.controvalore = 21_000
                $0.rendimentoAtteso = 3; $0.costoAnnuo = 1.1; $0.aliquotaFiscale = 20; $0.sri = 2
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
                $0.rendimentoAtteso = 2.8; $0.costoAnnuo = 1.3; $0.aliquotaFiscale = 20
            },
            p("marco", .alleanza, .inEssere, .investimento, "Polizza multiramo") {
                $0.tipologia = "Polizza multiramo (Ramo I e Ramo III)"; $0.emittente = alleanza
                $0.numeroContratto = "AL-2021-118842"; $0.decorrenza = anni(-5); $0.versamentoIniziale = 60_000
                $0.totaleVersato = 60_000; $0.controvalore = 62_000
                $0.rendimentoAtteso = 4; $0.costoAnnuo = 1.8; $0.aliquotaFiscale = 24; $0.sri = 3
            },
            p("marco", .alleanza, .inEssere, .protezione, "Temporanea caso morte") {
                $0.tipologia = "Temporanea caso morte a capitale costante"; $0.emittente = alleanza
                $0.beneficiari = "Elena Bianchi"; $0.decorrenza = anni(-3); $0.scadenza = anni(15)
                $0.premio = 45; $0.frequenza = .mensile; $0.capitaleAssicurato = 300_000; $0.rischio = .vita; $0.controvalore = 0
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
                $0.totaleVersato = 30_000; $0.controvalore = 38_000
                $0.rendimentoAtteso = 3.2; $0.costoAnnuo = 1.5; $0.aliquotaFiscale = 15
            },
            p("marco", .alleanza, .inEssere, .liquidita, "Liquidità") { $0.controvalore = 35_000 },
            p("marco", .alleanza, .inEssere, .immobili, "Casa di abitazione") { $0.controvalore = 280_000 },
            p("marco", .alleanza, .inEssere, .debiti, "Mutuo casa") {
                $0.tipologia = "Mutuo a tasso variabile"; $0.scadenza = anni(16); $0.premio = 890; $0.frequenza = .mensile
                $0.controvalore = 130_000
            },
            p("marco", .alleanza, .proposta, .risparmio, "Piano per gli studi di Anna") {
                $0.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"; $0.emittente = alleanza
                $0.contraente = "Marco Bianchi"; $0.assicurato = "Anna Bianchi"; $0.scadenza = anni(6)
                $0.premio = 200; $0.frequenza = .mensile
                $0.rendimentoAtteso = 2.5; $0.costoIngresso = 3; $0.costoAnnuo = 1.2; $0.aliquotaFiscale = 20
                $0.esito = .bozza
            },

            // Laura Moretti: indipendente
            p("laura", .indipendente, .inEssere, .previdenza, "Fondo pensione aperto") {
                $0.tipologia = "Fondo pensione aperto, comparto bilanciato"; $0.emittente = "Gestore indipendente"
                $0.decorrenza = anni(-4); $0.scadenza = anni(26); $0.premio = 150; $0.frequenza = .mensile
                $0.totaleVersato = 14_400; $0.controvalore = 18_000
                $0.rendimentoAtteso = 4; $0.costoAnnuo = 0.8; $0.aliquotaFiscale = 15
            },
            p("laura", .indipendente, .inEssere, .investimento, "ETF azionario globale") {
                $0.tipologia = "ETF"; $0.emittente = "Banca online"; $0.decorrenza = anni(-3)
                $0.versamentoIniziale = 22_000; $0.totaleVersato = 22_000; $0.controvalore = 27_000
                $0.rendimentoAtteso = 5; $0.costoAnnuo = 0.2; $0.aliquotaFiscale = 26; $0.sri = 4
            },
            p("laura", .indipendente, .inEssere, .liquidita, "Liquidità") { $0.controvalore = 19_000 },
            p("laura", .indipendente, .inEssere, .debiti, "Prestito personale") {
                $0.scadenza = anni(2); $0.premio = 260; $0.frequenza = .mensile; $0.controvalore = 6_000
            },
            p("laura", .indipendente, .proposta, .protezione, "Infortuni e invalidità professionale") {
                $0.tipologia = "Polizza infortuni e invalidità permanente"; $0.emittente = "Compagnia (mercato)"
                $0.premio = 420; $0.frequenza = .annuale; $0.capitaleAssicurato = 150_000; $0.rischio = .invalidita
                $0.controvalore = 0; $0.esito = .bozza
            },

            // Andrea Conti: primo incontro, Alleanza
            p("andrea", .alleanza, .inEssere, .liquidita, "Liquidità") { $0.controvalore = 12_000 },
            p("andrea", .alleanza, .proposta, .risparmio, "Piano di risparmio rivalutabile") {
                $0.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"; $0.emittente = alleanza
                $0.scadenza = anni(15); $0.premio = 100; $0.frequenza = .mensile
                $0.rendimentoAtteso = 2.5; $0.costoIngresso = 3; $0.costoAnnuo = 1.2; $0.aliquotaFiscale = 20
                $0.esito = .bozza
            },
            p("andrea", .alleanza, .proposta, .protezione, "Temporanea caso morte") {
                $0.tipologia = "Temporanea caso morte a capitale costante"; $0.emittente = alleanza
                $0.scadenza = anni(25); $0.premio = 12; $0.frequenza = .mensile; $0.capitaleAssicurato = 100_000
                $0.rischio = .vita; $0.controvalore = 0; $0.esito = .bozza
            },

            // Sofia Romano: entrambi i canali
            p("sofia", .alleanza, .inEssere, .risparmio, "Polizza rivalutabile") {
                $0.tipologia = "Polizza rivalutabile a premio unico (Ramo I)"; $0.emittente = alleanza
                $0.numeroContratto = "AL-2016-009311"; $0.decorrenza = anni(-10); $0.scadenza = data(70)
                $0.versamentoIniziale = 35_000; $0.totaleVersato = 35_000; $0.controvalore = 41_000
                $0.rendimentoAtteso = 2.5; $0.costoAnnuo = 1.3; $0.aliquotaFiscale = 20
                $0.note = "In scadenza: valutare il reinvestimento."
            },
            p("sofia", .alleanza, .inEssere, .protezione, "Non autosufficienza") {
                $0.tipologia = "Polizza LTC a vita intera"; $0.emittente = alleanza; $0.decorrenza = anni(-5)
                $0.premio = 600; $0.frequenza = .annuale; $0.capitaleAssicurato = 30_000; $0.rischio = .ltc; $0.controvalore = 0
            },
            p("sofia", .indipendente, .inEssere, .investimento, "Portafoglio di fondi") {
                $0.tipologia = "Fondi comuni bilanciati"; $0.emittente = "SGR indipendenti"; $0.decorrenza = anni(-6)
                $0.versamentoIniziale = 28_000; $0.totaleVersato = 28_000; $0.controvalore = 32_000
                $0.rendimentoAtteso = 3.5; $0.costoAnnuo = 1.4; $0.aliquotaFiscale = 26; $0.sri = 3
            },
            p("sofia", .indipendente, .inEssere, .liquidita, "Liquidità") { $0.controvalore = 27_000 },
            p("sofia", .indipendente, .inEssere, .immobili, "Casa di abitazione") { $0.controvalore = 180_000 },
            p("sofia", .indipendente, .inEssere, .debiti, "Mutuo") { $0.scadenza = anni(8); $0.premio = 480; $0.frequenza = .mensile; $0.controvalore = 40_000 },
            p("sofia", .indipendente, .proposta, .investimento, "Obbligazionario a scadenza 2030") {
                $0.tipologia = "Fondo obbligazionario a scadenza"; $0.emittente = "SGR indipendente"
                $0.scadenza = anni(4); $0.versamentoIniziale = 40_000
                $0.rendimentoAtteso = 3.2; $0.costoAnnuo = 0.6; $0.aliquotaFiscale = 20; $0.sri = 2
                $0.esito = .presentata; $0.note = "Ipotesi di reinvestimento della polizza in scadenza."
            },
        ]
    }

    private static func anni(_ n: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .year, value: n, to: data(0)) ?? Date()
    }

    /// Oggi + `giorni`, all'ora indicata.
    private static func data(_ giorni: Int, _ ora: Int = 9, _ minuti: Int = 0) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let oggi = cal.startOfDay(for: Date())
        let giorno = cal.date(byAdding: .day, value: giorni, to: oggi) ?? oggi
        return cal.date(bySettingHour: ora, minute: minuti, second: 0, of: giorno) ?? giorno
    }
}
