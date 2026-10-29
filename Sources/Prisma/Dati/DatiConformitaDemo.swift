import Foundation

// Le scadenze di conformità dei dati di prova («In regola», specifica 3): date relative a oggi, così le
// schermate mostrano sempre una varietà di stati. Ogni data sta ad almeno 13 giorni da una soglia (0, 30, 60
// giorni), quindi i salti di fine mese non cambiano lo stato. Le scadute stanno tra −40 e −62 giorni circa e la
// voce entro 30 giorni a +20: nel Centro notifiche restano dopo l'attività scaduta e la posizione a +10 giorni
// che `--prova-eve` cerca.

extension DatiDemo {
    /// Le scadenze di conformità dei 5 clienti di prova, relative a oggi: una varietà di stati per le schermate.
    static func completaConformita(_ elenco: inout [Cliente]) {
        let cal = Calendar(identifier: .gregorian)
        let oggi = cal.startOfDay(for: Date())
        /// L'inizio di oggi meno `mesi`, più `giorni`, alle 9:00 (secondi interi, come l'archivio).
        func fa(_ mesi: Int, _ giorni: Int = 0) -> Date {
            let m = cal.date(byAdding: .month, value: -mesi, to: oggi) ?? oggi
            let g = cal.date(byAdding: .day, value: giorni, to: m) ?? m
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: g) ?? g
        }
        for i in elenco.indices {
            var k = ConformitaCliente()
            var c = elenco[i]
            switch c.id {
            case "giulia":
                // Questionario Alleanza entro 60 giorni, documento entro 30, consenso commerciale scaduto
                k.questionarioAlleanza = QuestionarioAdeguatezza(compilatoIl: fa(36, 45), esito: "Moderato")
                k.questionarioIndipendente = QuestionarioAdeguatezza(compilatoIl: fa(8), esito: "Moderato")
                k.verificaAlleanza = AdeguataVerifica(eseguitaIl: fa(14), rischio: .basso)
                k.verificaIndipendente = AdeguataVerifica(eseguitaIl: fa(14), rischio: .basso)
                k.documento = DocumentoIdentita(tipo: .cartaIdentita, numero: "CA12345AB", rilasciatoIl: fa(120, 20),
                                                scadenza: fa(0, 20))
                c.consensi.marketing = true
                c.consensi.dataMarketing = fa(26)
            case "marco":
                // Questionario e adeguata verifica Alleanza scaduti
                k.questionarioAlleanza = QuestionarioAdeguatezza(compilatoIl: fa(36, -40), esito: "Moderato")
                k.verificaAlleanza = AdeguataVerifica(eseguitaIl: fa(26), rischio: .medio)
                k.documento = DocumentoIdentita(tipo: .passaporto, numero: "YA0000000", rilasciatoIl: fa(84), scadenza: fa(-36))
            case "laura":
                // Tutto in regola
                k.questionarioIndipendente = QuestionarioAdeguatezza(compilatoIl: fa(5), esito: "Dinamico")
                k.verificaIndipendente = AdeguataVerifica(eseguitaIl: fa(10), rischio: .basso)
                k.documento = DocumentoIdentita(tipo: .patente, numero: "U1A000000", rilasciatoIl: fa(72), scadenza: fa(-48))
            case "sofia":
                // Documento scaduto, adeguata verifica Alleanza entro 60 giorni
                k.questionarioAlleanza = QuestionarioAdeguatezza(compilatoIl: fa(20), esito: "Prudente")
                k.questionarioIndipendente = QuestionarioAdeguatezza(compilatoIl: fa(20), esito: "Prudente")
                k.verificaAlleanza = AdeguataVerifica(eseguitaIl: fa(10, -15), rischio: .alto)
                k.verificaIndipendente = AdeguataVerifica(eseguitaIl: fa(6), rischio: .alto)
                k.documento = DocumentoIdentita(tipo: .cartaIdentita, numero: "CA76543CD", rilasciatoIl: fa(120, -50),
                                                scadenza: fa(0, -50))
                c.consensi.marketing = true
                c.consensi.dataMarketing = fa(3)
            default:
                // andrea: primo incontro, niente di registrato (tre voci da raccogliere)
                break
            }
            c.conformita = k == ConformitaCliente() ? nil : k
            elenco[i] = c
        }
    }
}

extension ClientiFittizi {
    /// Scadenze dei clienti fittizi, ricavate dall'indice (deterministiche): questionari in regola, adeguata
    /// verifica con il rischio a rotazione (le più vecchie con rischio alto risultano scadute), documento
    /// scaduto, vicino o lontano secondo l'indice, data del consenso commerciale.
    static func completaConformita(_ c: inout Cliente, indice: Int) {
        let cal = Calendar(identifier: .gregorian)
        let oggi = cal.startOfDay(for: Date())
        /// Oggi + `giorni`, alle 9:00 (secondi interi).
        func giorno(_ giorni: Int) -> Date {
            let g = cal.date(byAdding: .day, value: giorni, to: oggi) ?? oggi
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: g) ?? g
        }
        let rischi: [RischioRiciclaggio] = [.basso, .medio, .alto]
        var k = ConformitaCliente()
        for canale in c.canali {
            k.impostaQuestionario(QuestionarioAdeguatezza(compilatoIl: c.creatoIl), canale: canale)
            k.impostaVerifica(AdeguataVerifica(eseguitaIl: c.creatoIl, rischio: rischi[indice % 3]), canale: canale)
        }
        let scadenza: Date
        switch indice % 10 {
        case 0: scadenza = giorno(-20)
        case 3: scadenza = giorno(18)
        case 6: scadenza = giorno(45)
        default: scadenza = cal.date(byAdding: .year, value: 2 + indice % 7, to: giorno(0)) ?? giorno(0)
        }
        let rilascio = cal.date(byAdding: .year, value: -10, to: scadenza) ?? scadenza
        k.documento = DocumentoIdentita(tipo: .cartaIdentita, numero: "CA\(10_000 + indice * 313)FZ",
                                        rilasciatoIl: rilascio, scadenza: scadenza)
        c.conformita = k
        if c.consensi.marketing { c.consensi.dataMarketing = c.creatoIl }
    }
}
