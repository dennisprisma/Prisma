import Foundation

/// Trenta clienti fittizi completi, in aggiunta ai 5 del template: per vedere Prisma piena e per fare a Eve
/// domande vere (scadenze, coperture, pensione, portafoglio). Persone, polizze e cifre sono inventate;
/// i prodotti Alleanza sono quelli della scheda di prova. Generati sempre uguali (niente caso), con le date
/// che partono da oggi così agenda, scadenze e storico restano attuali.
enum ClientiFittizi {
    /// I clienti fittizi hanno l'id che comincia così: si riconoscono e si tolgono insieme a quelli di prova.
    static let prefisso = "prova-"

    static var ids: Set<String> { Set(profili.map { prefisso + $0.chiave }) }

    /// I dati di prova completi: i 5 del template più i clienti fittizi.
    static func completi() -> DatiPrisma {
        var d = DatiPrisma.demo()
        aggiungi(a: &d)
        return d
    }

    static func aggiungi(a d: inout DatiPrisma) {
        let tinte: [TintaAvatar] = [.blu, .rosa, .verde, .viola, .oro]
        for (n, p) in profili.enumerated() {
            let id = prefisso + p.chiave
            d.clienti.append(cliente(p, id: id, tinta: tinte[n % tinte.count], indice: n))
            let posizioni = DatiDemo.conRilevazioni(p.voci.enumerated().map { i, v in posizione(v, cliente: id, nome: p.nomeCompleto, indice: i) })
            d.posizioni.append(contentsOf: posizioni)
            d.appuntamenti.append(contentsOf: appuntamenti(p, id: id, indice: n, posizioni: posizioni))
            d.attivita.append(contentsOf: attivita(p, id: id, indice: n))
            if let o = p.obiettivo {
                var x = Obiettivo(clienteId: id, titolo: o.titolo, area: o.area, importo: o.importo, scadenza: anni(o.anni))
                x.id = "obiettivo-\(id)"
                x.priorita = .alta
                x.accantonato = o.accantonato
                x.creatoIl = giorno(-40 - n)
                d.obiettivi.append(x)
            }
            if let t = p.taccuino {
                d.note.append(Nota(id: "nota-\(id)", clienteId: id, titolo: t.titolo, testo: t.testo, fissata: false,
                                   creataIl: giorno(-10 - n % 20, 15), aggiornataIl: giorno(-10 - n % 20, 15, 30)))
            }
            if let a = p.incontro {
                var i = Incontro(clienteId: id, titolo: "Analisi delle posizioni in essere", data: giorno(-20 - n % 15, 17))
                i.id = "incontro-\(id)"
                i.stato = .concluso
                i.preoccupazioni = a.preoccupazioni
                i.progetti = a.progetti
                i.appunti = a.appunti
                i.decisioni = a.decisioni
                i.aggiornatoIl = giorno(-20 - n % 15, 18)
                d.incontri.append(i)
            }
        }
    }

    // MARK: - Il cliente

    private static func cliente(_ p: Profilo, id: String, tinta: TintaAvatar, indice: Int) -> Cliente {
        var c = Cliente(id: id, nome: p.nomeCompleto, iniziali: Cliente.iniziali(di: p.nomeCompleto), tinta: tinta, tema: p.tema,
                        email: "\(p.nome.lowercased().filter(\.isLetter)).\(p.cognome.lowercased().filter(\.isLetter))@example.com",
                        telefono: "+39 333 100 \(String(format: "%04d", 1000 + indice * 37))", preferito: indice % 9 == 0,
                        nota: p.nota, creatoIl: giorno(-400 + indice * 11))
        c.dataNascita = data(p.nascita.0, p.nascita.1, p.nascita.2)
        c.professione = p.professione
        c.statoCivile = p.statoCivile
        c.indirizzo = p.indirizzo
        c.canali = p.canali
        c.famiglia = p.famiglia.map { Familiare(nome: $0.nome, relazione: $0.relazione, dataNascita: data($0.anno, 6, 15), aCarico: $0.aCarico) }
        c.consensi = Consensi(privacy: true, dataPrivacy: c.creatoIl, marketing: indice % 3 == 0)
        c.profilo.propensione = p.propensione
        c.profilo.esperienza = p.esperienza
        c.profilo.orizzonteAnni = p.orizzonte
        c.profilo.redditoLordoAnnuo = p.reddito
        c.profilo.obiettivi = p.obiettiviTesto
        c.profilo.aggiornatoIl = giorno(-60 + indice)
        for b in p.bisogni { c.bisogni.imposta(ValutazioneBisogno(area: b.0, importanza: b.1, orizzonte: b.2)) }
        if let e = p.evento {
            c.bisogni.eventi = [EventoVita(id: "evento-\(id)", tipo: e.tipo, anno: annoCorrente + e.traAnni, nota: e.nota)]
        }
        c.bisogni.aggiornatoIl = giorno(-60 + indice)
        return c
    }

    // MARK: - Le posizioni

    /// Una posizione del cliente, con versato e valore coerenti con gli anni trascorsi.
    indirect enum Voce {
        /// Alleanza: piano di risparmio rivalutabile a premi mensili.
        case risparmio(mensile: Double, da: Int, durata: Int)
        /// Alleanza: rivalutabile a premio unico.
        case premioUnico(Double, da: Int, durata: Int)
        /// Alleanza: piano individuale pensionistico.
        case pip(mensile: Double, da: Int, finoA: Int)
        /// Alleanza: temporanea caso morte.
        case tcm(capitale: Double, mensile: Double, da: Int, durata: Int)
        /// Alleanza: infortuni, rinnovo annuale tra `scade` giorni.
        case infortuni(capitale: Double, annuo: Double, scade: Int)
        /// Alleanza: non autosufficienza (rendita annua).
        case ltc(rendita: Double, annuo: Double, da: Int)
        /// Alleanza: multiramo a premio unico.
        case multiramo(Double, da: Int)
        /// Indipendente: ETF con eventuale piano di accumulo.
        case etf(iniziale: Double, mensile: Double, da: Int)
        /// Indipendente: fondi comuni bilanciati.
        case fondi(Double, da: Int)
        /// Indipendente: titoli di Stato con scadenza tra `scade` giorni.
        case btp(Double, da: Int, scade: Int)
        /// Indipendente: fondo pensione aperto.
        case fondoPensione(mensile: Double, da: Int, finoA: Int)
        case liquidita(Double)
        case casa(Double)
        case mutuo(residuo: Double, rata: Double, anni: Int)
        case prestito(residuo: Double, rata: Double, anni: Int)
        /// Una proposta (stato «proposta») con il suo esito.
        case proposta(Voce, EsitoProposta)
    }

    private static let alleanza = "Alleanza Assicurazioni"

    private static func posizione(_ v: Voce, cliente: String, nome: String, indice: Int) -> Posizione {
        var proposta = false
        var esito: EsitoProposta?
        var voce = v
        if case .proposta(let interna, let e) = v {
            voce = interna
            proposta = true
            esito = e
        }
        var p: Posizione
        func nuova(_ canale: Canale, _ area: AreaPosizione, _ titolo: String) -> Posizione {
            var x = Posizione(clienteId: cliente, canale: canale, stato: proposta ? .proposta : .inEssere, area: area, nome: titolo)
            x.id = "pos-\(cliente)-\(indice)"
            x.creataIl = giorno(-30 - indice)
            x.dataValore = giorno(-5)
            x.esito = esito
            if canale == .alleanza {
                x.emittente = alleanza
                x.contraente = nome
                x.assicurato = nome
                if !proposta { x.numeroContratto = "AL-\(annoCorrente - 3)-\(String(format: "%06d", abs(cliente.hashValueStabile + indice * 7919) % 1_000_000))" }
            }
            return x
        }
        switch voce {
        case .risparmio(let mensile, let da, let durata):
            p = nuova(.alleanza, .risparmio, "Piano di risparmio rivalutabile")
            p.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"
            p.premio = mensile; p.frequenza = .mensile
            p.decorrenza = anni(-da); p.scadenza = anni(durata - da)
            p.beneficiari = "Eredi legittimi"
            p.rendimentoAtteso = 2.5; p.costoIngresso = 3; p.trattenuto = 1.2; p.quotaTitoliStato = 60; p.aliquotaFiscale = 20
            p.prodottoId = "prodotto-risparmio-rivalutabile"
            p.garanzie = "Capitale garantito a scadenza e in caso di decesso; consolidamento annuo dei rendimenti."
            valori(&p, versato: mensile * 12 * Double(da), crescita: 0.018, anni: da)
        case .premioUnico(let importo, let da, let durata):
            p = nuova(.alleanza, .risparmio, "Polizza rivalutabile a premio unico")
            p.tipologia = "Polizza rivalutabile a premio unico (Ramo I)"
            p.versamentoIniziale = importo
            p.decorrenza = anni(-da); p.scadenza = anni(durata - da)
            p.beneficiari = "Eredi legittimi"
            p.rendimentoAtteso = 2.6; p.trattenuto = 1.3; p.quotaTitoliStato = 60; p.aliquotaFiscale = 20
            valori(&p, versato: importo, crescita: 0.019, anni: da)
        case .pip(let mensile, let da, let finoA):
            p = nuova(.alleanza, .previdenza, "Piano individuale pensionistico")
            p.tipologia = "Piano individuale pensionistico (PIP)"
            p.premio = mensile; p.frequenza = .mensile
            p.decorrenza = anni(-da); p.scadenza = anni(finoA)
            p.rendimentoAtteso = 3.5; p.costoIngresso = 2; p.costoAnnuo = 1.4; p.aliquotaFiscale = 15
            p.prodottoId = "prodotto-previdenza-pip"
            valori(&p, versato: mensile * 12 * Double(da), crescita: 0.03, anni: da)
        case .tcm(let capitale, let mensile, let da, let durata):
            p = nuova(.alleanza, .protezione, "Temporanea caso morte")
            p.tipologia = "Temporanea caso morte a capitale costante"
            p.premio = mensile; p.frequenza = .mensile
            p.decorrenza = anni(-da); p.scadenza = anni(durata - da)
            p.capitaleAssicurato = capitale; p.rischio = .vita; p.controvalore = 0
            p.prodottoId = "prodotto-tcm"
        case .infortuni(let capitale, let annuo, let scade):
            p = nuova(.alleanza, .protezione, "Infortuni")
            p.tipologia = "Polizza infortuni con invalidità permanente"
            p.premio = annuo; p.frequenza = .annuale
            p.decorrenza = giorno(scade - 365); p.scadenza = giorno(scade)
            p.capitaleAssicurato = capitale; p.rischio = .infortuni; p.controvalore = 0
            p.note = "Rinnovo annuale: verificare le somme assicurate."
        case .ltc(let rendita, let annuo, let da):
            p = nuova(.alleanza, .protezione, "Non autosufficienza")
            p.tipologia = "Polizza LTC a vita intera"
            p.premio = annuo; p.frequenza = .annuale
            p.decorrenza = anni(-da)
            p.capitaleAssicurato = rendita; p.rischio = .ltc; p.controvalore = 0
        case .multiramo(let importo, let da):
            p = nuova(.alleanza, .investimento, "Polizza multiramo")
            p.tipologia = "Polizza multiramo (Ramo I e Ramo III)"
            p.versamentoIniziale = importo
            p.decorrenza = anni(-da)
            p.rendimentoAtteso = 4; p.costoIngresso = 1; p.costoAnnuo = 1.8; p.aliquotaFiscale = 24; p.sri = 3
            p.quotaGestioneSeparata = 40
            p.prodottoId = "prodotto-multiramo"
            valori(&p, versato: importo, crescita: 0.028, anni: da)
        case .etf(let iniziale, let mensile, let da):
            p = nuova(.indipendente, .investimento, "ETF azionario globale")
            p.tipologia = mensile > 0 ? "ETF con piano di accumulo" : "ETF a replica fisica"
            p.emittente = "Banca online"
            p.versamentoIniziale = iniziale; p.premio = mensile; p.frequenza = mensile > 0 ? .mensile : .unica
            p.decorrenza = anni(-da)
            p.rendimentoAtteso = 5; p.costoAnnuo = 0.2; p.aliquotaFiscale = 26; p.sri = 4
            p.prodottoId = "prodotto-etf-globale"
            valori(&p, versato: iniziale + mensile * 12 * Double(da), crescita: 0.055, anni: da)
        case .fondi(let importo, let da):
            p = nuova(.indipendente, .investimento, "Fondi bilanciati")
            p.tipologia = "Fondi comuni bilanciati"; p.emittente = "SGR indipendenti"
            p.versamentoIniziale = importo
            p.decorrenza = anni(-da)
            p.rendimentoAtteso = 3.5; p.costoAnnuo = 1.6; p.costoIngresso = 2; p.aliquotaFiscale = 26; p.sri = 3
            valori(&p, versato: importo, crescita: 0.025, anni: da)
        case .btp(let importo, let da, let scade):
            p = nuova(.indipendente, .investimento, "Titoli di Stato")
            p.tipologia = "BTP a tasso fisso"; p.emittente = "Repubblica Italiana"
            p.versamentoIniziale = importo
            p.decorrenza = anni(-da); p.scadenza = giorno(scade)
            p.rendimentoAtteso = 3; p.costoAnnuo = 0.1; p.aliquotaFiscale = 12.5; p.sri = 2
            p.quotaTitoliStato = 100
            valori(&p, versato: importo, crescita: 0.01, anni: da)
        case .fondoPensione(let mensile, let da, let finoA):
            p = nuova(.indipendente, .previdenza, "Fondo pensione aperto")
            p.tipologia = "Fondo pensione aperto, comparto bilanciato"; p.emittente = "Gestore indipendente"
            p.premio = mensile; p.frequenza = .mensile
            p.decorrenza = anni(-da); p.scadenza = anni(finoA)
            p.rendimentoAtteso = 4; p.costoAnnuo = 0.8; p.aliquotaFiscale = 15
            p.prodottoId = "prodotto-fondo-pensione"
            valori(&p, versato: mensile * 12 * Double(da), crescita: 0.035, anni: da)
        case .liquidita(let importo):
            p = nuova(.indipendente, .liquidita, "Conto corrente e deposito")
            p.emittente = "Banca"; p.controvalore = importo
        case .casa(let valore):
            p = nuova(.indipendente, .immobili, "Casa di abitazione")
            p.controvalore = valore
        case .mutuo(let residuo, let rata, let n):
            p = nuova(.indipendente, .debiti, "Mutuo casa")
            p.tipologia = "Mutuo a tasso fisso"; p.emittente = "Banca"
            p.premio = rata; p.frequenza = .mensile; p.scadenza = anni(n); p.controvalore = residuo
        case .prestito(let residuo, let rata, let n):
            p = nuova(.indipendente, .debiti, "Prestito personale")
            p.emittente = "Finanziaria"
            p.premio = rata; p.frequenza = .mensile; p.scadenza = anni(n); p.controvalore = residuo
        case .proposta:
            p = nuova(.indipendente, .liquidita, "Proposta")
        }
        if proposta {
            // Una proposta non ha ancora numero, valore né storico
            p.numeroContratto = ""
            p.controvalore = p.area == .protezione ? 0 : nil
            p.totaleVersato = nil
            p.decorrenza = nil
            p.dataValore = nil
            if p.esito == .presentata { p.note = "Presentata all'ultimo incontro: in attesa di risposta." }
        }
        return p
    }

    /// Versato e valore di oggi: crescita annua composta, arrotondata alle decine.
    private static func valori(_ p: inout Posizione, versato: Double, crescita: Double, anni: Int) {
        guard versato > 0 else { return }
        p.totaleVersato = versato
        // I premi ricorrenti hanno lavorato in media metà del tempo
        let tempo = p.premio > 0 && p.versamentoIniziale == 0 ? Double(anni) / 2 : Double(anni)
        p.controvalore = (versato * pow(1 + crescita, tempo) / 10).rounded() * 10
    }

    // MARK: - Agenda, attività

    private static func appuntamenti(_ p: Profilo, id: String, indice n: Int, posizioni: [Posizione]) -> [Appuntamento] {
        let luoghi = ["In studio", "Videochiamata", "A casa del cliente", "In studio", "Telefonata"]
        var elenco: [Appuntamento] = []
        // Uno passato, concluso
        elenco.append(Appuntamento(id: "event-\(id)-passato", clienteId: id, titolo: "Revisione delle posizioni",
                                   inizio: giorno(-15 - (n * 7) % 60, 9 + n % 8, n % 2 == 0 ? 0 : 30), durataMinuti: 60,
                                   luogo: luoghi[n % luoghi.count], note: "Aggiornati valori e coperture.", stato: .concluso, tipo: .revisione))
        // Uno nelle prossime settimane: sulla proposta aperta, sulla scadenza vicina o una revisione
        let inScadenza = posizioni.first { $0.stato == .inEssere && ($0.scadenza.map { $0 < giorno(90) && $0 > Date() } ?? false) }
        let aperta = posizioni.first { $0.stato == .proposta && $0.esito != .rifiutata }
        let quando = giorno(1 + (n * 5) % 35, 9 + (n * 3) % 9, n % 3 == 0 ? 30 : 0)
        if let s = inScadenza {
            elenco.append(Appuntamento(id: "event-\(id)", clienteId: id, titolo: "Scadenza di «\(s.nome)»", inizio: quando, durataMinuti: 45,
                                       luogo: luoghi[(n + 1) % luoghi.count], note: "Decidere come proseguire: rinnovo o reinvestimento.",
                                       stato: .pianificato, tipo: .revisione, canale: s.canale, posizioneId: s.id))
        } else if let a = aperta {
            elenco.append(Appuntamento(id: "event-\(id)", clienteId: id, titolo: "Presentazione: \(a.nome)", inizio: quando, durataMinuti: 45,
                                       luogo: luoghi[(n + 1) % luoghi.count], note: "Portare il prospetto e il confronto con la situazione attuale.",
                                       stato: .pianificato, tipo: .proposta, canale: a.canale, posizioneId: a.id))
        } else if n % 2 == 0 {
            elenco.append(Appuntamento(id: "event-\(id)", clienteId: id, titolo: "Revisione annuale", inizio: quando, durataMinuti: 60,
                                       luogo: luoghi[(n + 2) % luoghi.count], note: "Rivedere obiettivi e profilo.", stato: .pianificato, tipo: .revisione))
        }
        return elenco
    }

    private static func attivita(_ p: Profilo, id: String, indice n: Int) -> [Attivita] {
        var elenco = [Attivita(id: "task-\(id)", clienteId: id, titolo: p.daFare, scadenza: giorno((n * 3) % 14 - 2),
                               priorita: n % 4 == 0 ? .alta : .normale, completata: false)]
        if n % 3 == 1 {
            elenco.append(Attivita(id: "task-\(id)-fatto", clienteId: id, titolo: "Inviare il resoconto dell'ultimo incontro",
                                   scadenza: giorno(-12), priorita: .normale, completata: true))
        }
        return elenco
    }

    // MARK: - Date

    private static var annoCorrente: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) }

    private static func data(_ anno: Int, _ mese: Int, _ giorno: Int) -> Date? {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: anno, month: mese, day: giorno, hour: 12))
    }

    /// Oggi + `giorni`, all'ora indicata (secondi interi: l'archivio non conserva le frazioni).
    private static func giorno(_ giorni: Int, _ ora: Int = 9, _ minuti: Int = 0) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let oggi = cal.startOfDay(for: Date())
        let g = cal.date(byAdding: .day, value: giorni, to: oggi) ?? oggi
        return cal.date(bySettingHour: ora, minute: minuti, second: 0, of: g) ?? g
    }

    private static func anni(_ n: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .year, value: n, to: giorno(0)) ?? Date()
    }

    // MARK: - I profili

    struct Profilo {
        let chiave: String
        let nome: String
        let cognome: String
        let nascita: (Int, Int, Int)
        let professione: String
        let indirizzo: String
        let statoCivile: StatoCivile
        var famiglia: [(nome: String, relazione: Familiare.Relazione, anno: Int, aCarico: Bool)] = []
        let reddito: Double
        let propensione: ProfiloInvestitore.Propensione
        let esperienza: ProfiloInvestitore.Esperienza
        let orizzonte: Int
        let canali: [Canale]
        let tema: String
        let nota: String
        let obiettiviTesto: String
        var bisogni: [(AreaBisogno, Importanza, OrizzonteBisogno)] = []
        var evento: (tipo: EventoVita.Tipo, traAnni: Int, nota: String)?
        let voci: [Voce]
        var obiettivo: (titolo: String, area: AreaBisogno, importo: Double, anni: Int, accantonato: Double)?
        let daFare: String
        var taccuino: (titolo: String, testo: String)?
        var incontro: (preoccupazioni: String, progetti: String, appunti: String, decisioni: String)?

        var nomeCompleto: String { "\(nome) \(cognome)" }
    }

    /// I profili, aggiunti uno alla volta (un unico elenco letterale peserebbe troppo sul compilatore).
    static let profili: [Profilo] = {
        var a: [Profilo] = []
        a.append(Profilo(chiave: "ferraro", nome: "Paolo", cognome: "Ferraro", nascita: (1972, 4, 12), professione: "Artigiano (falegname)",
                indirizzo: "Via Cavour 18, Vicenza", statoCivile: .coniugato,
                famiglia: [("Silvia Ferraro", .coniuge, 1975, false), ("Matteo Ferraro", .figlio, 2006, true), ("Chiara Ferraro", .figlia, 2010, true)],
                reddito: 45_000, propensione: .moderata, esperienza: .base, orizzonte: 12, canali: [.alleanza],
                tema: "La bottega e i ragazzi.", nota: "Lavoratore autonomo: reddito variabile, attenzione all'invalidità.",
                obiettiviTesto: "Proteggere il reddito e gli studi dei figli.",
                bisogni: [(.lavoro, .alta, .presto), (.famiglia, .alta, .medio), (.pensione, .media, .lungo)],
                evento: (.studiFigli, 1, "Matteo all'università a Padova"),
                voci: [.risparmio(mensile: 200, da: 6, durata: 15), .tcm(capitale: 200_000, mensile: 38, da: 4, durata: 20),
                       .infortuni(capitale: 250_000, annuo: 520, scade: 34), .pip(mensile: 150, da: 8, finoA: 14),
                       .liquidita(28_000), .casa(320_000), .mutuo(residuo: 62_000, rata: 540, anni: 9)],
                obiettivo: ("Università di Matteo", .famiglia, 40_000, 5, 9_000), daFare: "Verificare la copertura invalidità da lavoro autonomo",
                taccuino: ("Reddito da proteggere", "Paolo lavora da solo: se si fa male si ferma la bottega.\n\nValutare una copertura per l'invalidità temporanea. Silvia lavora part-time."),
                incontro: ("Se mi faccio male in bottega, chi paga il mutuo?", "Matteo all'università il prossimo anno.",
                           "Polizza infortuni in scadenza tra un mese. Nessuna diaria per inabilità temporanea.",
                           "Preparare il rinnovo infortuni con la diaria.")))
        a.append(Profilo(chiave: "galli", nome: "Federica", cognome: "Galli", nascita: (1990, 9, 3), professione: "Insegnante di scuola primaria",
                indirizzo: "Via Mazzini 7, Bergamo", statoCivile: .convivente,
                famiglia: [("Davide Sala", .convivente, 1988, false)],
                reddito: 29_000, propensione: .prudente, esperienza: .base, orizzonte: 8, canali: [.alleanza],
                tema: "Un passo alla volta.", nota: "Vuole comprare casa con il compagno nei prossimi due anni.",
                obiettiviTesto: "Anticipo per la casa e un fondo per gli imprevisti.",
                bisogni: [(.casa, .alta, .presto), (.salute, .media, .medio)], evento: (.acquistoCasa, 2, "Bilocale vicino alla scuola"),
                voci: [.risparmio(mensile: 120, da: 3, durata: 10), .liquidita(18_500), .proposta(.tcm(capitale: 150_000, mensile: 14, da: 0, durata: 25), .presentata)],
                obiettivo: ("Anticipo per la casa", .casa, 35_000, 2, 18_000), daFare: "Chiedere la simulazione del mutuo alla banca",
                taccuino: ("Casa con Davide", "Convivono da tre anni, non sposati: Davide non sarebbe erede.\n\nRicordare il tema beneficiari nella temporanea.")))
        a.append(Profilo(chiave: "marchetti", nome: "Roberto", cognome: "Marchetti", nascita: (1961, 1, 25), professione: "Funzionario di banca",
                indirizzo: "Corso Italia 41, Firenze", statoCivile: .coniugato,
                famiglia: [("Patrizia Marchetti", .coniuge, 1963, false)],
                reddito: 68_000, propensione: .moderata, esperienza: .elevata, orizzonte: 15, canali: [.alleanza, .indipendente],
                tema: "Verso la pensione.", nota: "Pensione tra due anni: decidere cosa fare del TFR.",
                obiettiviTesto: "Integrare la pensione e organizzare il passaggio ai figli.",
                bisogni: [(.pensione, .alta, .presto), (.patrimonio, .alta, .medio)], evento: (.pensione, 2, "Uscita con 42 anni di contributi"),
                voci: [.premioUnico(80_000, da: 9, durata: 12), .multiramo(100_000, da: 4), .pip(mensile: 300, da: 15, finoA: 2),
                       .ltc(rendita: 18_000, annuo: 900, da: 6), .fondi(60_000, da: 7), .btp(50_000, da: 3, scade: 75),
                       .liquidita(45_000), .casa(450_000)],
                obiettivo: ("Integrazione della pensione", .pensione, 150_000, 2, 120_000), daFare: "Preparare il confronto rendita / capitale del PIP",
                taccuino: ("TFR e pensione", "Roberto riceverà circa 120.000 € di TFR.\n\nIpotesi: una parte in rendita, una parte per i nipoti. BTP in scadenza tra due mesi."),
                incontro: ("Non voglio che la pensione cambi il nostro tenore di vita.", "Viaggi, la casa al mare per i nipoti.",
                           "BTP in scadenza a breve, PIP quasi a riscatto, polizza a premio unico a metà durata.",
                           "Simulare l'uscita del PIP e il reinvestimento dei BTP.")))
        a.append(Profilo(chiave: "russo", nome: "Antonio", cognome: "Russo", nascita: (1983, 7, 19), professione: "Titolare di ristorante",
                indirizzo: "Via Toledo 120, Napoli", statoCivile: .coniugato,
                famiglia: [("Maria Russo", .coniuge, 1985, false), ("Luigi Russo", .figlio, 2014, true), ("Sara Russo", .figlia, 2018, true), ("Gino Russo", .genitore, 1951, true)],
                reddito: 75_000, propensione: .dinamica, esperienza: .media, orizzonte: 15, canali: [.alleanza, .indipendente],
                tema: "Il locale e la famiglia allargata.", nota: "Molta liquidità sul conto dell'attività, poca protezione.",
                obiettiviTesto: "Mettere al sicuro la famiglia e far crescere il patrimonio.",
                bisogni: [(.famiglia, .alta, .presto), (.lavoro, .alta, .presto), (.salute, .media, .medio)],
                voci: [.etf(iniziale: 30_000, mensile: 500, da: 2), .liquidita(95_000), .casa(380_000), .mutuo(residuo: 140_000, rata: 980, anni: 18),
                       .proposta(.tcm(capitale: 400_000, mensile: 55, da: 0, durata: 20), .presentata),
                       .proposta(.multiramo(60_000, da: 0), .bozza)],
                daFare: "Calcolare il fabbisogno caso morte con il padre a carico",
                taccuino: ("Troppa liquidità", "Sul conto ci sono quasi 100.000 € fermi.\n\nAntonio teme di non averli disponibili per il locale: tenere una riserva di 6 mesi di costi."),
                incontro: ("Se mi succede qualcosa, Maria da sola con il locale e due bambini.", "Ampliare il ristorante tra tre anni.",
                           "Nessuna copertura vita, mutuo di 140.000 €. Liquidità alta.", "Proporre la temporanea e un piano per la liquidità in eccesso.")))
        a.append(Profilo(chiave: "colombo", nome: "Elisa", cognome: "Colombo", nascita: (1994, 2, 8), professione: "Sviluppatrice software",
                indirizzo: "Via Paolo Sarpi 22, Milano", statoCivile: .celibeNubile,
                reddito: 46_000, propensione: .dinamica, esperienza: .media, orizzonte: 20, canali: [.indipendente],
                tema: "Libertà finanziaria.", nota: "Investe da sola con gli ETF, cerca un parere sulla previdenza.",
                obiettiviTesto: "Indipendenza finanziaria a 55 anni.",
                bisogni: [(.pensione, .media, .lungo), (.patrimonio, .media, .lungo)],
                voci: [.etf(iniziale: 15_000, mensile: 600, da: 4), .fondoPensione(mensile: 100, da: 2, finoA: 35), .liquidita(22_000),
                       .proposta(.pip(mensile: 200, da: 0, finoA: 35), .rifiutata)],
                obiettivo: ("Capitale per l'indipendenza", .patrimonio, 500_000, 23, 70_000), daFare: "Mandare il confronto costi fondo pensione / ETF"))
        a.append(Profilo(chiave: "esposito", nome: "Giovanna", cognome: "Esposito", nascita: (1957, 11, 30), professione: "Pensionata (ex commerciante)",
                indirizzo: "Viale Michelangelo 5, Salerno", statoCivile: .vedovo,
                famiglia: [("Francesco Esposito", .figlio, 1982, false), ("Anna Esposito", .figlia, 1986, false)],
                reddito: 22_000, propensione: .prudente, esperienza: .base, orizzonte: 10, canali: [.alleanza],
                tema: "Serenità e i nipoti.", nota: "Vuole lasciare qualcosa ai nipoti senza complicazioni.",
                obiettiviTesto: "Rendita sicura e passaggio ai figli.",
                bisogni: [(.patrimonio, .alta, .medio), (.salute, .alta, .presto)],
                voci: [.premioUnico(60_000, da: 8, durata: 10), .premioUnico(40_000, da: 2, durata: 10), .ltc(rendita: 12_000, annuo: 1_100, da: 4),
                       .liquidita(35_000), .casa(240_000)],
                daFare: "Verificare i beneficiari delle due polizze",
                taccuino: ("Beneficiari", "Giovanna vuole dividere in parti uguali tra Francesco e Anna.\n\nControllare che i beneficiari non siano «eredi legittimi» generici.")))
        a.append(Profilo(chiave: "ricci", nome: "Stefano", cognome: "Ricci", nascita: (1979, 5, 2), professione: "Medico ospedaliero",
                indirizzo: "Via Indipendenza 60, Bologna", statoCivile: .divorziato,
                famiglia: [("Giorgia Ricci", .figlia, 2011, true)],
                reddito: 82_000, propensione: .moderata, esperienza: .media, orizzonte: 15, canali: [.alleanza, .indipendente],
                tema: "Giorgia prima di tutto.", nota: "Divorziato: assegno di mantenimento per Giorgia fino ai 25 anni.",
                obiettiviTesto: "Proteggere Giorgia e ridurre le tasse con la previdenza.",
                bisogni: [(.famiglia, .alta, .medio), (.pensione, .alta, .lungo)], evento: (.studiFigli, 5, "Giorgia, forse medicina"),
                voci: [.tcm(capitale: 300_000, mensile: 42, da: 5, durata: 15), .pip(mensile: 400, da: 6, finoA: 21), .fondi(45_000, da: 5),
                       .etf(iniziale: 20_000, mensile: 0, da: 3), .liquidita(30_000), .casa(290_000), .mutuo(residuo: 110_000, rata: 760, anni: 15)],
                obiettivo: ("Studi di Giorgia", .famiglia, 60_000, 5, 15_000), daFare: "Aggiornare i beneficiari della temporanea dopo il divorzio",
                incontro: ("I beneficiari della vita sono ancora quelli di prima del divorzio.", "Medicina per Giorgia, fuori città.",
                           "Temporanea con beneficiario l'ex moglie. PIP con versamenti alti: deduzione piena.", "Cambiare i beneficiari in favore di Giorgia.")))
        a.append(Profilo(chiave: "fontana", nome: "Martina", cognome: "Fontana", nascita: (1987, 8, 14), professione: "Commercialista",
                indirizzo: "Via XX Settembre 15, Genova", statoCivile: .coniugato,
                famiglia: [("Alessio Fontana", .coniuge, 1985, false), ("Leonardo Fontana", .figlio, 2021, true)],
                reddito: 58_000, propensione: .moderata, esperienza: .elevata, orizzonte: 18, canali: [.indipendente],
                tema: "Ordine nei conti di famiglia.", nota: "Molto precisa: vuole sempre i costi in euro.",
                obiettiviTesto: "Accumulo per Leonardo e previdenza per entrambi.",
                bisogni: [(.famiglia, .media, .lungo), (.pensione, .media, .lungo), (.casa, .bassa, .medio)],
                evento: (.figlioInArrivo, 1, "Secondo figlio in arrivo"),
                voci: [.fondoPensione(mensile: 250, da: 8, finoA: 28), .etf(iniziale: 10_000, mensile: 250, da: 3), .btp(30_000, da: 2, scade: 900),
                       .liquidita(40_000), .casa(410_000), .mutuo(residuo: 190_000, rata: 1_050, anni: 22)],
                obiettivo: ("Accumulo per Leonardo", .famiglia, 30_000, 15, 4_000), daFare: "Rivedere le coperture con il secondo figlio in arrivo"))
        a.append(Profilo(chiave: "conti-l", nome: "Luca", cognome: "Conti", nascita: (1998, 12, 1), professione: "Magazziniere",
                indirizzo: "Via Roma 3, Treviso", statoCivile: .celibeNubile,
                reddito: 24_000, propensione: .prudente, esperienza: .nessuna, orizzonte: 10, canali: [.alleanza],
                tema: "Il primo risparmio.", nota: "Cugino di Andrea Conti. Primo contratto a tempo indeterminato.",
                obiettiviTesto: "Mettere da parte qualcosa ogni mese.",
                bisogni: [(.casa, .media, .medio), (.lavoro, .bassa, .medio)],
                voci: [.risparmio(mensile: 60, da: 1, durata: 10), .liquidita(6_000), .proposta(.pip(mensile: 50, da: 0, finoA: 40), .bozza)],
                daFare: "Spiegare il TFR nel fondo pensione"))
        a.append(Profilo(chiave: "greco", nome: "Valentina", cognome: "Greco", nascita: (1976, 3, 22), professione: "Farmacista titolare",
                indirizzo: "Via Etnea 210, Catania", statoCivile: .coniugato,
                famiglia: [("Carlo Greco", .coniuge, 1972, false), ("Irene Greco", .figlia, 2005, false), ("Marco Greco", .figlio, 2008, true)],
                reddito: 95_000, propensione: .moderata, esperienza: .elevata, orizzonte: 20, canali: [.alleanza, .indipendente],
                tema: "La farmacia e il futuro dei figli.", nota: "Pensa a come passare la farmacia ai figli.",
                obiettiviTesto: "Successione dell'attività e tutela della famiglia.",
                bisogni: [(.patrimonio, .alta, .medio), (.lavoro, .media, .medio), (.pensione, .media, .lungo)],
                voci: [.multiramo(150_000, da: 5), .premioUnico(100_000, da: 6, durata: 15), .tcm(capitale: 500_000, mensile: 85, da: 6, durata: 20),
                       .ltc(rendita: 24_000, annuo: 1_300, da: 3), .fondi(120_000, da: 8), .btp(80_000, da: 4, scade: 600),
                       .liquidita(70_000), .casa(620_000)],
                daFare: "Preparare il prospetto di successione",
                taccuino: ("Successione della farmacia", "Irene studia farmacia. Marco no.\n\nValutare polizze con beneficiario Marco per bilanciare le quote.")))
        a.append(Profilo(chiave: "lombardi", nome: "Giorgio", cognome: "Lombardi", nascita: (1969, 6, 6), professione: "Operaio specializzato",
                indirizzo: "Via Matteotti 90, Brescia", statoCivile: .coniugato,
                famiglia: [("Rita Lombardi", .coniuge, 1971, false), ("Simone Lombardi", .figlio, 2000, false)],
                reddito: 34_000, propensione: .prudente, esperienza: .base, orizzonte: 10, canali: [.alleanza],
                tema: "Arrivare alla pensione tranquillo.", nota: "Cliente storico, paga sempre puntuale.",
                obiettiviTesto: "Pensione serena e la casa finita di pagare.",
                bisogni: [(.pensione, .alta, .medio), (.salute, .media, .medio)],
                voci: [.risparmio(mensile: 150, da: 14, durata: 15), .pip(mensile: 120, da: 12, finoA: 9), .infortuni(capitale: 150_000, annuo: 310, scade: 58),
                       .liquidita(15_000), .casa(210_000), .mutuo(residuo: 18_000, rata: 420, anni: 4)],
                daFare: "Avvisare della scadenza del piano di risparmio l'anno prossimo"))
        a.append(Profilo(chiave: "barbieri", nome: "Chiara", cognome: "Barbieri", nascita: (1992, 10, 17), professione: "Fisioterapista (partita IVA)",
                indirizzo: "Via Emilia 300, Modena", statoCivile: .convivente,
                famiglia: [("Nicola Rossi", .convivente, 1990, false)],
                reddito: 31_000, propensione: .moderata, esperienza: .base, orizzonte: 12, canali: [.alleanza],
                tema: "Il suo studio, le sue regole.", nota: "Partita IVA forfettaria: nessun TFR, previdenza da costruire.",
                obiettiviTesto: "Costruire la pensione e proteggere il reddito.",
                bisogni: [(.lavoro, .alta, .presto), (.pensione, .alta, .lungo)], evento: (.avvioAttivita, 1, "Studio proprio con un collega"),
                voci: [.pip(mensile: 100, da: 2, finoA: 32), .liquidita(14_000),
                       .proposta(.infortuni(capitale: 200_000, annuo: 380, scade: 365), .presentata)],
                daFare: "Confrontare infortuni con diaria e invalidità da malattia"))
        a.append(Profilo(chiave: "moretti-f", nome: "Francesco", cognome: "Moretti", nascita: (1965, 2, 28), professione: "Imprenditore edile",
                indirizzo: "Via Garibaldi 33, Verona", statoCivile: .separato,
                famiglia: [("Tommaso Moretti", .figlio, 1996, false), ("Laura Moretti", .figlia, 1985, false)],
                reddito: 120_000, propensione: .dinamica, esperienza: .elevata, orizzonte: 15, canali: [.alleanza, .indipendente],
                tema: "Il patrimonio da riorganizzare.", nota: "Padre di Laura Moretti. Separato, patrimonio da riordinare.",
                obiettiviTesto: "Riorganizzare il patrimonio e tutelare i figli dopo la separazione.",
                bisogni: [(.patrimonio, .alta, .presto), (.pensione, .media, .medio)], evento: (.separazione, 0, "Separazione in corso"),
                voci: [.multiramo(200_000, da: 3), .etf(iniziale: 80_000, mensile: 0, da: 5), .fondi(150_000, da: 10), .btp(100_000, da: 2, scade: 45),
                       .tcm(capitale: 600_000, mensile: 140, da: 8, durata: 15), .liquidita(130_000), .casa(780_000),
                       .proposta(.premioUnico(150_000, da: 0, durata: 10), .presentata)],
                daFare: "Coordinarsi con l'avvocato per i beneficiari",
                incontro: ("Con la separazione non voglio che i figli restino scoperti.", "Ridurre l'attività tra cinque anni.",
                           "BTP in scadenza tra 45 giorni, molta liquidità, TCM con beneficiaria la moglie.", "Rivedere beneficiari e reinvestire i BTP.")))
        a.append(Profilo(chiave: "santoro", nome: "Alessia", cognome: "Santoro", nascita: (1985, 12, 24), professione: "Impiegata amministrativa",
                indirizzo: "Via Sparano 12, Bari", statoCivile: .coniugato,
                famiglia: [("Michele Santoro", .coniuge, 1983, false), ("Giulia Santoro", .figlia, 2015, true), ("Pietro Santoro", .figlio, 2019, true)],
                reddito: 28_000, propensione: .prudente, esperienza: .base, orizzonte: 12, canali: [.alleanza],
                tema: "Due bambini e un bilancio da far quadrare.", nota: "Budget stretto: proposte da pochi euro al mese.",
                obiettiviTesto: "Risparmio per i figli e protezione essenziale.",
                bisogni: [(.famiglia, .alta, .lungo), (.salute, .media, .medio)],
                voci: [.risparmio(mensile: 80, da: 5, durata: 15), .tcm(capitale: 150_000, mensile: 18, da: 3, durata: 20), .liquidita(9_000),
                       .casa(190_000), .mutuo(residuo: 120_000, rata: 650, anni: 20)],
                obiettivo: ("Un gruzzolo per i bambini", .famiglia, 20_000, 12, 5_500), daFare: "Chiedere se Michele ha coperture in azienda"))
        a.append(Profilo(chiave: "mariani", nome: "Davide", cognome: "Mariani", nascita: (1975, 8, 9), professione: "Agente di commercio",
                indirizzo: "Via Flaminia 70, Rimini", statoCivile: .coniugato,
                famiglia: [("Elena Mariani", .coniuge, 1977, false), ("Sofia Mariani", .figlia, 2009, true)],
                reddito: 52_000, propensione: .moderata, esperienza: .media, orizzonte: 12, canali: [.alleanza, .indipendente],
                tema: "Sempre in viaggio.", nota: "Usa molto l'auto: attenzione agli infortuni.",
                obiettiviTesto: "Proteggere il reddito e far crescere i risparmi.",
                bisogni: [(.lavoro, .alta, .presto), (.famiglia, .media, .medio)],
                voci: [.infortuni(capitale: 300_000, annuo: 640, scade: 20), .tcm(capitale: 250_000, mensile: 40, da: 6, durata: 15),
                       .fondi(40_000, da: 4), .pip(mensile: 200, da: 7, finoA: 16), .liquidita(25_000), .casa(300_000)],
                daFare: "Rinnovo infortuni: verificare il capitale con il nuovo reddito"))
        a.append(Profilo(chiave: "rinaldi", nome: "Monica", cognome: "Rinaldi", nascita: (1970, 4, 4), professione: "Dirigente d'azienda",
                indirizzo: "Corso Buenos Aires 90, Milano", statoCivile: .celibeNubile,
                reddito: 130_000, propensione: .dinamica, esperienza: .elevata, orizzonte: 15, canali: [.indipendente],
                tema: "Il tempo per sé.", nota: "Vuole smettere di lavorare a 60 anni.",
                obiettiviTesto: "Uscita anticipata dal lavoro e rendita.",
                bisogni: [(.pensione, .alta, .medio), (.salute, .media, .medio)], evento: (.pensione, 4, "Uscita anticipata"),
                voci: [.etf(iniziale: 100_000, mensile: 1_000, da: 6), .fondi(80_000, da: 9), .fondoPensione(mensile: 450, da: 15, finoA: 4),
                       .btp(120_000, da: 3, scade: 1_400), .liquidita(60_000), .casa(650_000)],
                obiettivo: ("Uscire dal lavoro a 60 anni", .pensione, 600_000, 4, 420_000), daFare: "Simulare il ponte fino alla pensione pubblica"))
        a.append(Profilo(chiave: "costa", nome: "Matteo", cognome: "Costa", nascita: (1996, 3, 11), professione: "Ingegnere junior",
                indirizzo: "Via Po 14, Torino", statoCivile: .convivente,
                famiglia: [("Beatrice Neri", .convivente, 1997, false)],
                reddito: 34_000, propensione: .dinamica, esperienza: .base, orizzonte: 25, canali: [.indipendente],
                tema: "Tutto davanti.", nota: "Primo lavoro, vuole cominciare bene.",
                obiettiviTesto: "Accumulo di lungo periodo e casa.",
                bisogni: [(.casa, .media, .medio), (.pensione, .bassa, .lungo)], evento: (.matrimonio, 2, "Matrimonio con Beatrice"),
                voci: [.etf(iniziale: 5_000, mensile: 300, da: 1), .liquidita(12_000), .proposta(.fondoPensione(mensile: 100, da: 0, finoA: 38), .presentata)],
                daFare: "Mandare il confronto fondo pensione con TFR"))
        a.append(Profilo(chiave: "gallo", nome: "Rosa", cognome: "Gallo", nascita: (1952, 7, 21), professione: "Pensionata (ex insegnante)",
                indirizzo: "Via Libertà 8, Palermo", statoCivile: .vedovo,
                famiglia: [("Enzo Gallo", .figlio, 1978, false)],
                reddito: 26_000, propensione: .prudente, esperienza: .base, orizzonte: 6, canali: [.alleanza],
                tema: "Tranquillità.", nota: "Preferisce parlare al telefono con il figlio presente.",
                obiettiviTesto: "Nessun rischio, disponibilità per le spese di salute.",
                bisogni: [(.salute, .alta, .presto), (.patrimonio, .media, .medio)],
                voci: [.premioUnico(50_000, da: 10, durata: 10), .liquidita(40_000), .casa(160_000),
                       .proposta(.ltc(rendita: 12_000, annuo: 1_800, da: 0), .rifiutata)],
                daFare: "Polizza a premio unico in scadenza: proporre il reinvestimento"))
        a.append(Profilo(chiave: "bruno", nome: "Simone", cognome: "Bruno", nascita: (1981, 9, 29), professione: "Vigile del fuoco",
                indirizzo: "Via Nizza 50, Cuneo", statoCivile: .coniugato,
                famiglia: [("Laura Bruno", .coniuge, 1983, false), ("Elia Bruno", .figlio, 2013, true)],
                reddito: 36_000, propensione: .moderata, esperienza: .base, orizzonte: 15, canali: [.alleanza],
                tema: "Chi protegge gli altri.", nota: "Lavoro a rischio: alcune coperture escludono la professione.",
                obiettiviTesto: "Protezione e risparmio per Elia.",
                bisogni: [(.famiglia, .alta, .medio), (.salute, .alta, .presto)],
                voci: [.tcm(capitale: 250_000, mensile: 48, da: 5, durata: 20), .risparmio(mensile: 100, da: 5, durata: 15), .pip(mensile: 80, da: 4, finoA: 22),
                       .liquidita(11_000), .casa(230_000), .mutuo(residuo: 95_000, rata: 590, anni: 16)],
                obiettivo: ("Risparmio per Elia", .famiglia, 25_000, 10, 6_000), daFare: "Verificare le esclusioni professionali dell'infortuni"))
        a.append(Profilo(chiave: "deluca", nome: "Sara", cognome: "De Luca", nascita: (1988, 1, 15), professione: "Avvocata",
                indirizzo: "Via del Corso 200, Roma", statoCivile: .celibeNubile,
                reddito: 64_000, propensione: .moderata, esperienza: .media, orizzonte: 15, canali: [.alleanza, .indipendente],
                tema: "Indipendente in tutto.", nota: "Libera professionista: Cassa Forense, vuole integrare.",
                obiettiviTesto: "Integrare la pensione della Cassa e comprare uno studio.",
                bisogni: [(.pensione, .alta, .lungo), (.lavoro, .media, .medio), (.casa, .media, .medio)],
                voci: [.pip(mensile: 350, da: 4, finoA: 28), .etf(iniziale: 25_000, mensile: 400, da: 3), .liquidita(35_000),
                       .proposta(.infortuni(capitale: 250_000, annuo: 450, scade: 365), .bozza)],
                obiettivo: ("Studio professionale", .lavoro, 80_000, 6, 20_000), daFare: "Preparare la proposta invalidità per liberi professionisti"))
        a.append(Profilo(chiave: "marino", nome: "Enrico", cognome: "Marino", nascita: (1958, 5, 17), professione: "Pensionato (ex dirigente pubblico)",
                indirizzo: "Lungomare 11, Pescara", statoCivile: .coniugato,
                famiglia: [("Teresa Marino", .coniuge, 1960, false), ("Paola Marino", .figlia, 1987, false), ("Ugo Marino", .figlio, 1990, false)],
                reddito: 48_000, propensione: .prudente, esperienza: .media, orizzonte: 10, canali: [.alleanza, .indipendente],
                tema: "Il patrimonio di una vita.", nota: "Vuole aiutare i figli con la casa già ora.",
                obiettiviTesto: "Donazione ai figli e rendita per sé.",
                bisogni: [(.patrimonio, .alta, .presto), (.salute, .media, .medio)], evento: (.eredita, 0, "Donazione ai figli per la casa"),
                voci: [.premioUnico(120_000, da: 7, durata: 10), .multiramo(80_000, da: 2), .btp(90_000, da: 5, scade: 200), .fondi(70_000, da: 12),
                       .ltc(rendita: 20_000, annuo: 1_500, da: 5), .liquidita(55_000), .casa(400_000)],
                daFare: "Calcolare le imposte sulla donazione ai figli",
                taccuino: ("Donazione", "Enrico vuole dare 80.000 € a Paola per la casa.\n\nVerificare franchigie e alternativa polizza con beneficiario.")))
        a.append(Profilo(chiave: "ferri", nome: "Ilaria", cognome: "Ferri", nascita: (1993, 6, 30), professione: "Infermiera",
                indirizzo: "Via Saragozza 40, Bologna", statoCivile: .coniugato,
                famiglia: [("Andrea Ferri", .coniuge, 1992, false)],
                reddito: 30_000, propensione: .prudente, esperienza: .nessuna, orizzonte: 10, canali: [.alleanza],
                tema: "Una famiglia da costruire.", nota: "Sorella di Luca Ferri (compagno di Giulia Rossi).",
                obiettiviTesto: "Prepararsi all'arrivo di un figlio.",
                bisogni: [(.famiglia, .alta, .presto), (.casa, .media, .medio)], evento: (.figlioInArrivo, 0, "Primo figlio in arrivo"),
                voci: [.risparmio(mensile: 100, da: 2, durata: 12), .liquidita(16_000), .proposta(.tcm(capitale: 200_000, mensile: 16, da: 0, durata: 25), .presentata)],
                daFare: "Proporre la temporanea prima della nascita"))
        a.append(Profilo(chiave: "caruso", nome: "Michele", cognome: "Caruso", nascita: (1974, 10, 3), professione: "Autotrasportatore",
                indirizzo: "Via Appia 150, Latina", statoCivile: .coniugato,
                famiglia: [("Daniela Caruso", .coniuge, 1976, false), ("Kevin Caruso", .figlio, 2007, true)],
                reddito: 40_000, propensione: .prudente, esperienza: .nessuna, orizzonte: 10, canali: [.alleanza],
                tema: "Sempre sulla strada.", nota: "Ha solo la polizza infortuni: molto da costruire.",
                obiettiviTesto: "Sicurezza per la famiglia.",
                bisogni: [(.salute, .alta, .presto), (.famiglia, .alta, .medio), (.pensione, .media, .lungo)],
                voci: [.infortuni(capitale: 200_000, annuo: 720, scade: 12), .liquidita(8_000), .casa(150_000), .prestito(residuo: 9_000, rata: 280, anni: 3),
                       .proposta(.pip(mensile: 100, da: 0, finoA: 14), .bozza)],
                daFare: "Rinnovo infortuni tra pochi giorni: chiamarlo"))
        a.append(Profilo(chiave: "ferrara", nome: "Beatrice", cognome: "Ferrara", nascita: (1980, 3, 3), professione: "Architetta d'interni",
                indirizzo: "Via Manzoni 25, Como", statoCivile: .divorziato,
                famiglia: [("Pietro Ferrara", .figlio, 2012, true), ("Lia Ferrara", .figlia, 2015, true)],
                reddito: 55_000, propensione: .moderata, esperienza: .media, orizzonte: 15, canali: [.indipendente],
                tema: "Ripartire da sé.", nota: "Dopo il divorzio vuole rifare tutto il piano.",
                obiettiviTesto: "Sicurezza per i figli e indipendenza.",
                bisogni: [(.famiglia, .alta, .presto), (.casa, .alta, .medio), (.pensione, .media, .lungo)], evento: (.separazione, 0, "Divorzio concluso"),
                voci: [.fondi(70_000, da: 6), .etf(iniziale: 0, mensile: 300, da: 2), .liquidita(48_000),
                       .proposta(.tcm(capitale: 300_000, mensile: 30, da: 0, durata: 20), .bozza)],
                obiettivo: ("Casa tutta sua", .casa, 90_000, 3, 48_000), daFare: "Rifare il profilo dell'investitore dopo il divorzio"))
        a.append(Profilo(chiave: "rizzo", nome: "Gianluca", cognome: "Rizzo", nascita: (1967, 12, 12), professione: "Commerciante (abbigliamento)",
                indirizzo: "Via Roma 77, Lecce", statoCivile: .coniugato,
                famiglia: [("Carmela Rizzo", .coniuge, 1969, false), ("Fabio Rizzo", .figlio, 1995, false)],
                reddito: 60_000, propensione: .moderata, esperienza: .media, orizzonte: 12, canali: [.alleanza],
                tema: "Il negozio di famiglia.", nota: "Fabio lavora in negozio: pensare al passaggio.",
                obiettiviTesto: "Pensione e passaggio del negozio a Fabio.",
                bisogni: [(.pensione, .alta, .medio), (.patrimonio, .media, .medio)],
                voci: [.pip(mensile: 300, da: 10, finoA: 10), .premioUnico(70_000, da: 5, durata: 10), .multiramo(50_000, da: 3),
                       .tcm(capitale: 200_000, mensile: 60, da: 7, durata: 12), .liquidita(38_000), .casa(280_000)],
                daFare: "Proposta: aumentare il PIP per sfruttare la deduzione"))
        a.append(Profilo(chiave: "longo", nome: "Noemi", cognome: "Longo", nascita: (1999, 4, 26), professione: "Studentessa lavoratrice",
                indirizzo: "Via Dante 9, Trieste", statoCivile: .celibeNubile,
                reddito: 14_000, propensione: .moderata, esperienza: .nessuna, orizzonte: 10, canali: [.indipendente],
                tema: "Imparare a risparmiare.", nota: "Figlia di un cliente di Laura Moretti. Molto curiosa.",
                obiettiviTesto: "Capire come funziona il risparmio.",
                bisogni: [(.lavoro, .media, .medio)],
                voci: [.etf(iniziale: 0, mensile: 50, da: 1), .liquidita(4_500)],
                daFare: "Mandare la guida sugli ETF"))
        a.append(Profilo(chiave: "giordano", nome: "Carlo", cognome: "Giordano", nascita: (1963, 8, 1), professione: "Agricoltore",
                indirizzo: "Strada Provinciale 12, Asti", statoCivile: .coniugato,
                famiglia: [("Lucia Giordano", .coniuge, 1965, false), ("Marta Giordano", .figlia, 1990, false)],
                reddito: 38_000, propensione: .prudente, esperienza: .base, orizzonte: 10, canali: [.alleanza],
                tema: "La terra e chi verrà dopo.", nota: "Patrimonio quasi tutto in terreni e casa.",
                obiettiviTesto: "Passare l'azienda agricola a Marta.",
                bisogni: [(.patrimonio, .alta, .medio), (.pensione, .media, .medio)],
                voci: [.premioUnico(40_000, da: 4, durata: 10), .risparmio(mensile: 120, da: 9, durata: 12), .infortuni(capitale: 150_000, annuo: 480, scade: 80),
                       .liquidita(22_000), .casa(520_000)],
                daFare: "Spiegare la polizza come strumento di successione"))
        a.append(Profilo(chiave: "pellegrini", nome: "Anna", cognome: "Pellegrini", nascita: (1977, 11, 11), professione: "Medico di base",
                indirizzo: "Via Nazionale 66, Perugia", statoCivile: .coniugato,
                famiglia: [("Luca Pellegrini", .coniuge, 1975, false), ("Emma Pellegrini", .figlia, 2008, true), ("Noah Pellegrini", .figlio, 2011, true)],
                reddito: 88_000, propensione: .moderata, esperienza: .media, orizzonte: 15, canali: [.alleanza, .indipendente],
                tema: "Una famiglia numerosa di progetti.", nota: "Due figli verso l'università, mutuo quasi estinto.",
                obiettiviTesto: "Studi dei figli e integrazione ENPAM.",
                bisogni: [(.famiglia, .alta, .medio), (.pensione, .media, .lungo)], evento: (.studiFigli, 2, "Emma all'università"),
                voci: [.pip(mensile: 400, da: 9, finoA: 18), .tcm(capitale: 400_000, mensile: 70, da: 8, durata: 15), .fondi(90_000, da: 7),
                       .etf(iniziale: 30_000, mensile: 300, da: 4), .liquidita(50_000), .casa(480_000), .mutuo(residuo: 25_000, rata: 900, anni: 2)],
                obiettivo: ("Università di Emma e Noah", .famiglia, 100_000, 3, 40_000), daFare: "Preparare il resoconto annuale"))
        a.append(Profilo(chiave: "fabbri", nome: "Tommaso", cognome: "Fabbri", nascita: (1985, 5, 5), professione: "Cuoco",
                indirizzo: "Via Senese 100, Siena", statoCivile: .celibeNubile,
                reddito: 26_000, propensione: .dinamica, esperienza: .base, orizzonte: 15, canali: [.alleanza],
                tema: "Il sogno di un locale tutto suo.", nota: "Vuole aprire un'osteria entro cinque anni.",
                obiettiviTesto: "Capitale per aprire un locale.",
                bisogni: [(.lavoro, .alta, .medio)], evento: (.avvioAttivita, 5, "Osteria a Siena"),
                voci: [.multiramo(20_000, da: 2), .risparmio(mensile: 150, da: 3, durata: 10), .liquidita(9_000)],
                obiettivo: ("Aprire l'osteria", .lavoro, 70_000, 5, 29_000), daFare: "Simulare quanto serve versare al mese"))
        a.append(Profilo(chiave: "villa", nome: "Lorenza", cognome: "Villa", nascita: (1966, 9, 9), professione: "Impiegata comunale",
                indirizzo: "Via Vittorio Veneto 21, Lecco", statoCivile: .coniugato,
                famiglia: [("Mauro Villa", .coniuge, 1964, false), ("Giada Villa", .figlia, 1998, false)],
                reddito: 33_000, propensione: .prudente, esperienza: .base, orizzonte: 8, canali: [.alleanza],
                tema: "Pensare anche a sé.", nota: "La madre è non autosufficiente: costi di assistenza alti.",
                obiettiviTesto: "Tutelarsi dalla non autosufficienza.",
                bisogni: [(.salute, .alta, .presto), (.pensione, .media, .medio)],
                voci: [.risparmio(mensile: 100, da: 12, durata: 15), .pip(mensile: 100, da: 10, finoA: 8), .liquidita(20_000), .casa(250_000),
                       .proposta(.ltc(rendita: 15_000, annuo: 980, da: 0), .presentata)],
                daFare: "Rispondere alle domande sulla LTC"))
        return a
    }()
}

private extension String {
    /// Un numero stabile da una stringa (lo `hashValue` di Swift cambia a ogni avvio).
    var hashValueStabile: Int {
        unicodeScalars.reduce(5381) { ($0 &* 33 &+ Int($1.value)) & 0x7fff_ffff }
    }
}
