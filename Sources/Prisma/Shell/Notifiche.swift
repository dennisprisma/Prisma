import Foundation

/// Centro notifiche: le cose che chiedono attenzione, ricavate dai dati dell'archivio
/// (niente promemoria da impostare a mano). Ogni notifica porta dove si risolve.
struct Notifica: Identifiable, Hashable {
    enum Gruppo: Int, CaseIterable, Identifiable {
        case daFare, oggi, prossimi, daSistemare

        var id: Int { rawValue }

        var titolo: String {
            switch self {
            case .daFare: return "DA RECUPERARE"
            case .oggi: return "OGGI"
            case .prossimi: return "NEI PROSSIMI GIORNI"
            case .daSistemare: return "DA SISTEMARE"
            }
        }
    }

    /// Stabile tra un calcolo e l'altro: serve a sapere quali sono già state viste.
    let id: String
    let gruppo: Gruppo
    let app: AppPrisma
    let titolo: String
    let dettaglio: String
    let data: Date
    var canale: Canale?
    var destinazione: DestinazioneRicerca?
    /// Per le notifiche di un cliente: la scheda del dossier da aprire (nil: la Panoramica).
    var schedaCliente: SchedaCliente? = nil
    /// Per le notifiche di più clienti: il testo della ricerca ⌘K da aprire.
    var testoRicerca: String? = nil
}

enum MotoreNotifiche {
    /// Quanti giorni avanti guardano scadenze e compleanni.
    static let giorniAvanti = 30
    static let giorniCompleanno = 7
    static let massimoPerGruppo = 8

    static func calcola(_ stato: StatoShell, oggi: Date = Date()) -> [Notifica] {
        let cal = Calendar.current
        let inizio = cal.startOfDay(for: oggi)
        let domani = cal.date(byAdding: .day, value: 1, to: inizio) ?? inizio
        let limite = cal.date(byAdding: .day, value: giorniAvanti, to: inizio) ?? inizio
        let dati = stato.dati
        // I nomi per id una volta sola (i clienti visibili, come `cliente(_:)`: in modalità cliente solo il suo)
        let nomi = Dictionary(stato.clienti.map { ($0.id, $0.nome) }, uniquingKeysWith: { primo, _ in primo })
        func nome(_ id: String) -> String { nomi[id] ?? "Senza cliente" }
        var elenco: [Notifica] = []

        // Appuntamenti di oggi, ancora da fare
        // (anche uno iniziato ieri sera e ancora in corso)
        for a in dati.appuntamenti where a.stato == .pianificato && a.inizio < domani && a.fine > oggi && a.fine > inizio {
            elenco.append(Notifica(id: "appuntamento-\(a.id)", gruppo: .oggi, app: .agenda,
                                   titolo: "Alle \(Formati.ora.string(from: a.inizio)) · \(a.titolo)",
                                   dettaglio: [nome(a.clienteId), a.luogo].filter { !$0.isEmpty }.joined(separator: " · "),
                                   data: a.inizio, canale: a.canale, destinazione: .appuntamento(a.id)))
        }
        // Appuntamenti passati senza esito
        // (anche quelli di oggi, appena finiti)
        // Le proposte ancora aperte, per id: un appuntamento di proposta o di firma chiede com'è finita
        var proposteAperte: [String: Posizione] = [:]
        for p in dati.posizioni where p.stato == .proposta && p.esito != .accettata && p.esito != .rifiutata {
            // Con due posizioni con lo stesso id vale la prima
            if proposteAperte[p.id] == nil { proposteAperte[p.id] = p }
        }
        for a in dati.appuntamenti where a.stato == .pianificato && a.fine <= oggi && a.fine > cal.date(byAdding: .day, value: -giorniAvanti, to: inizio) ?? inizio {
            var proposta: Posizione?
            if MotoreSeguitoProposte.tipiConEsito.contains(a.tipo), let pid = a.posizioneId { proposta = proposteAperte[pid] }
            let dettaglioEsito: String
            if let proposta {
                dettaglioEsito = TestiSeguito.esitoAppuntamento(cliente: nome(a.clienteId), giorno: a.inizio, proposta: proposta)
            } else {
                dettaglioEsito = "\(nome(a.clienteId)) · \(Formati.giornoMese.string(from: a.inizio)): segna l'esito in agenda"
            }
            elenco.append(Notifica(id: "esito-\(a.id)", gruppo: .daFare, app: .agenda,
                                   titolo: "Com'è andato «\(a.titolo)»?",
                                   dettaglio: dettaglioEsito,
                                   data: a.inizio, canale: a.canale, destinazione: .appuntamento(a.id)))
        }
        // Attività scadute e di oggi
        for t in dati.attivita where !t.completata && t.scadenza < domani {
            let scaduta = t.scadenza < inizio
            elenco.append(Notifica(id: "attivita-\(t.id)", gruppo: scaduta ? .daFare : .oggi, app: .attivita,
                                   titolo: t.titolo,
                                   dettaglio: "\(nome(t.clienteId)) · \(scaduta ? "scaduta il \(Formati.giornoMese.string(from: t.scadenza))" : "da fare oggi")\(t.priorita == .alta ? " · priorità alta" : "")",
                                   data: t.scadenza, destinazione: .attivita(t.id)))
        }
        // Posizioni in scadenza: il capitale da reinvestire, la copertura da rinnovare
        for p in dati.posizioni where p.stato == .inEssere {
            guard let s = p.scadenza, s >= inizio, s <= limite else { continue }
            let giorni = cal.dateComponents([.day], from: inizio, to: cal.startOfDay(for: s)).day ?? 0
            elenco.append(Notifica(id: "scadenza-\(p.id)-\(Int(s.timeIntervalSince1970))", gruppo: giorni == 0 ? .oggi : .prossimi, app: .posizioni,
                                   titolo: "\(p.nome) \(giorni == 0 ? "scade oggi" : "scade tra \(giorni) \(giorni == 1 ? "giorno" : "giorni")")",
                                   dettaglio: "\(nome(p.clienteId)) · \(Formati.dataEstesa.string(from: s))",
                                   data: s, canale: p.canale, destinazione: .posizione(p.id)))
        }
        // Posizioni scadute ma ancora in essere: capitale da reinvestire o stato da aggiornare
        let indietro = cal.date(byAdding: .day, value: -3 * giorniAvanti, to: inizio) ?? inizio
        for p in dati.posizioni where p.stato == .inEssere {
            guard let s = p.scadenza, s < inizio, s >= indietro else { continue }
            elenco.append(Notifica(id: "scaduta-\(p.id)-\(Int(s.timeIntervalSince1970))", gruppo: .daFare, app: .posizioni,
                                   titolo: "\(p.nome) è scaduta il \(Formati.giornoMese.string(from: s))",
                                   dettaglio: "\(nome(p.clienteId)) · reinvestimento o stato da aggiornare",
                                   data: s, canale: p.canale, destinazione: .posizione(p.id)))
        }
        // Proposte ferme: presentate da più dei giorni del seguito senza un appuntamento in agenda, o rimandate e da
        // riprendere. Una voce sola per tutte, come i clienti da ricontattare (apre il Portafoglio)
        let sogliaSeguito = dati.impostazioni.giorniSeguitoProposte
        let ferme = MotoreSeguitoProposte.inSospeso(posizioni: dati.posizioni, clienti: dati.clienti, appuntamenti: dati.appuntamenti,
                                                    attivita: dati.attivita, adesso: oggi, soglia: sogliaSeguito)
        if ferme.count == 1, let s = ferme.first {
            let p = s.posizione
            // Il giorno in cui è diventata ferma (le riprese: il giorno scelto); l'id si rinnova se viene ripresentata
            var ferma = s.dal
            if s.fonte != .ripresa { ferma = cal.date(byAdding: .day, value: sogliaSeguito, to: s.dal) ?? s.dal }
            elenco.append(Notifica(id: "seguito-\(p.id)-\(Int(s.dal.timeIntervalSince1970))", gruppo: .daFare, app: .posizioni,
                                   titolo: TestiSeguito.titoloNotifica(s),
                                   dettaglio: "\(s.cliente.nome) · \(TestiSeguito.riga(s))",
                                   data: ferma, canale: p.canale, destinazione: .posizione(p.id)))
        } else if let primo = ferme.first {
            let stessoCanale = ferme.allSatisfy { $0.posizione.canale == primo.posizione.canale }
            let canaleFerme: Canale? = stessoCanale ? primo.posizione.canale : nil
            let idFerme = "seguito-" + ferme.map(\.id).joined(separator: ",")
            elenco.append(Notifica(id: idFerme, gruppo: .daFare, app: .posizioni,
                                   titolo: TestiSeguito.aspettano(ferme.count),
                                   dettaglio: TestiSeguito.piuFerma(primo),
                                   data: inizio, canale: canaleFerme, destinazione: nil))
        }
        // Compleanni dei clienti
        for c in dati.clienti {
            guard let nascita = c.dataNascita, let prossimo = prossimoCompleanno(nascita, da: inizio, cal: cal) else { continue }
            let giorni = cal.dateComponents([.day], from: inizio, to: prossimo).day ?? 99
            guard giorni <= giorniCompleanno else { continue }
            // Gli anni che compie (anche chi è nato il 29 febbraio e festeggia il 28)
            let anni = cal.component(.year, from: prossimo) - cal.component(.year, from: nascita)
            elenco.append(Notifica(id: "compleanno-\(c.id)-\(cal.component(.year, from: prossimo))", gruppo: giorni == 0 ? .oggi : .prossimi, app: .clienti,
                                   titolo: giorni == 0 ? "Oggi \(c.nome) compie \(anni) anni" : "\(c.nome) compie \(anni) anni",
                                   dettaglio: giorni == 0 ? "Un pensiero fa piacere" : Formati.dataLunga.string(from: prossimo),
                                   data: prossimo, destinazione: .cliente(c.id)))
        }
        // Documenti con dati letti da confermare
        for d in dati.documenti where d.lettura == .letto {
            let mancano = d.campi.filter { !$0.confermato }.count
            guard mancano > 0, d.tipo != .prospetto, d.tipo != .report else { continue }
            elenco.append(Notifica(id: "documento-\(d.id)", gruppo: .daSistemare, app: .documenti,
                                   titolo: "\(mancano) \(mancano == 1 ? "dato da confermare" : "dati da confermare") in «\(d.titolo)»",
                                   dettaglio: nome(d.clienteId), data: d.importatoIl, destinazione: .documento(d.id)))
        }
        // Estratti conto con il valore confermato ma non ancora nello storico della posizione
        for d in dati.documenti where d.lettura == .letto && ValoriDaDocumento.pertinente(d) {
            guard let v = ValoriDaDocumento.valore(d),
                  let p = ValoriDaDocumento.posizioneProbabile(d, tra: dati.posizioni), !ValoriDaDocumento.registrato(v, in: p) else { continue }
            elenco.append(Notifica(id: "valore-\(d.id)-\(Int(v.data.timeIntervalSince1970))", gruppo: .daSistemare, app: .documenti,
                                   titolo: "Valore di «\(p.nome)» da registrare",
                                   dettaglio: "\(nome(d.clienteId)) · \(Formati.euro(v.valore)) al \(Formati.dataEstesa.string(from: v.data)), da «\(d.titolo)»",
                                   data: d.importatoIl, canale: p.canale, destinazione: .documento(d.id)))
        }
        // Schede prodotto da verificare (condizioni vecchie di un anno)
        let daVerificare = dati.prodotti.filter(\.daVerificare)
        if let primo = daVerificare.first {
            elenco.append(Notifica(id: "prodotti-\(daVerificare.count)", gruppo: .daSistemare, app: .prodotti,
                                   titolo: daVerificare.count == 1 ? "Scheda «\(primo.nome)» da verificare" : "\(daVerificare.count) schede prodotto da verificare",
                                   dettaglio: "Condizioni controllate più di un anno fa", data: inizio,
                                   canale: daVerificare.count == 1 ? primo.canale : nil,
                                   destinazione: daVerificare.count == 1 ? .prodotto(primo.id) : .app(.prodotti)))
        }
        // Clienti da ricontattare (nessun contatto da mesi e niente in agenda): una voce sola, apre il Portafoglio
        let richiamare = MotorePortafoglio.daRicontattare(dati.posizioni, clienti: dati.clienti, appuntamenti: dati.appuntamenti,
                                                          incontri: dati.incontri, oggi: oggi)
        if let primo = richiamare.first {
            elenco.append(Notifica(id: "ricontattare-\(richiamare.map(\.id).joined(separator: ","))", gruppo: .daSistemare, app: .clienti,
                                   titolo: richiamare.count == 1 ? "\(primo.cliente.nome) è da ricontattare" : "\(richiamare.count) clienti da ricontattare",
                                   dettaglio: primo.motivo ?? (primo.riesameScaduto ? "Riesame annuale scaduto: preparalo da Prospetti e report"
                                                                                    : "Nessun contatto da \(Portafoglio.mesiSenzaContatto) mesi e niente in agenda"),
                                   data: inizio, destinazione: richiamare.count == 1 ? .cliente(primo.id) : nil))
        }
        // Polizze e previdenza senza beneficiari: il capitale andrebbe agli eredi legittimi
        let perCliente = Dictionary(grouping: dati.posizioni.filter { $0.stato == .inEssere }, by: \.clienteId)
        let senzaBeneficiari = dati.clienti.filter { c in
            guard let mie = perCliente[c.id] else { return false }
            return mie.contains { p in
                MotoreSuccessione.classifica(p).1 == .beneficiari && p.senzaBeneficiari
                    && abs(MotoreSuccessione.classifica(p).0) > 0.5
            }
        }
        if let primo = senzaBeneficiari.first {
            elenco.append(Notifica(id: "beneficiari-\(senzaBeneficiari.map(\.id).joined(separator: ","))", gruppo: .daSistemare, app: .posizioni,
                                   titolo: senzaBeneficiari.count == 1 ? "\(primo.nome): beneficiari da indicare" : "\(senzaBeneficiari.count) clienti con beneficiari da indicare",
                                   dettaglio: "Polizze o previdenza senza beneficiari: il capitale andrebbe agli eredi legittimi",
                                   data: inizio, destinazione: nil))
        }
        // Proposte di un tipo che il cliente dice di non conoscere (griglia dell'esperienza nel profilo)
        let ignoti = MotoreEsperienza.daSegnalare(clienti: dati.clienti, posizioni: dati.posizioni, prodotti: dati.prodotti)
        if let primo = ignoti.first {
            // Una sola proposta di un solo cliente: la notifica porta alla proposta
            var una: Posizione?
            if ignoti.count == 1, primo.proposte.count == 1 { una = primo.proposte.first }
            var idProposte: [String] = []
            for voce in ignoti { idProposte += voce.proposte.map(\.id) }
            let titoloEsperienza: String
            if ignoti.count == 1 {
                titoloEsperienza = "\(primo.cliente.nome): proposta di un tipo che non conosce"
            } else {
                titoloEsperienza = "\(ignoti.count) clienti con proposte di tipi che non conoscono"
            }
            let dettaglioEsperienza: String
            var destinazioneEsperienza: DestinazioneRicerca?
            if let una {
                dettaglioEsperienza = "\(una.nome): spiegalo prima di presentarla"
                destinazioneEsperienza = .posizione(una.id)
            } else {
                let nomiIgnoti = ignoti.map { $0.cliente.nome }.joined(separator: ", ")
                dettaglioEsperienza = "Spiega il prodotto prima di presentarlo: " + nomiIgnoti
            }
            elenco.append(Notifica(id: "esperienza-" + idProposte.joined(separator: ","),
                                   gruppo: .daSistemare, app: .posizioni,
                                   titolo: titoloEsperienza,
                                   dettaglio: dettaglioEsperienza,
                                   data: inizio, canale: una?.canale,
                                   destinazione: destinazioneEsperienza))
        }
        // Schede di adeguatezza incomplete: firma da segnare su una proposta già accettata o documenti da consegnare
        // su una proposta presentata. Solo dove la scheda esiste (i dati di prova non ne hanno).
        let incomplete = MotoreAdeguatezza.daCompletare(schede: dati.schedeAdeguatezza, posizioni: dati.posizioni,
                                                        voci: dati.impostazioni.consegna.voci, prodotti: dati.prodotti)
        if let prima = incomplete.first {
            let p = prima.posizione
            let motivo: String
            switch prima.motivo {
            case .firma: motivo = "proposta accettata: segna la firma della scheda"
            case .documenti(let m): motivo = m == 1 ? "1 documento da consegnare" : "\(m) documenti da consegnare"
            }
            let titoloAdeguatezza = incomplete.count == 1 ? "Scheda di adeguatezza di «\(p.nome)» da completare"
                                                          : "\(incomplete.count) schede di adeguatezza da completare"
            let destinazioneAdeguatezza: DestinazioneRicerca = incomplete.count == 1 ? .posizione(p.id) : .app(.posizioni)
            elenco.append(Notifica(id: "adeguatezza-" + incomplete.map(\.posizione.id).joined(separator: ","),
                                   gruppo: .daSistemare, app: .posizioni,
                                   titolo: titoloAdeguatezza,
                                   dettaglio: "\(nome(p.clienteId)) · \(motivo)", data: inizio,
                                   canale: incomplete.count == 1 ? p.canale : nil,
                                   destinazione: destinazioneAdeguatezza))
        }
        // Fine anno: clienti che possono ancora dedurre versando alla previdenza (negli ultimi due mesi dell'anno)
        let deducibili = !MotoreFineAnno.ultimiGiorni(oggi) ? [] : MotoreFineAnno.conSpazio(clienti: dati.clienti, posizioni: dati.posizioni, oggi: oggi)
            .filter { f in f.scadenze.contains { $0.tipo == .deduzione && MotoreFineAnno.vicina($0, oggi: oggi) } }
        if let primo = deducibili.first {
            let anno = cal.component(.year, from: oggi)
            elenco.append(Notifica(id: "fineanno-\(anno)-\(deducibili.map(\.id).joined(separator: ","))", gruppo: .daSistemare, app: .posizioni,
                                   titolo: deducibili.count == 1 ? "\(primo.cliente.nome) può ancora dedurre \(Formati.euro(primo.spazio))"
                                                                 : "\(deducibili.count) clienti possono ancora dedurre",
                                   dettaglio: "Versamenti alla previdenza entro il 31 dicembre" + (primo.risparmioPossibile >= 1 ? " · fino a \(Formati.euro(primo.risparmioPossibile)) di IRPEF in meno" : ""),
                                   data: inizio))
        }
        // Occasioni: date in cui cambia qualcosa nelle posizioni e nella famiglia, entro l'anticipo scelto (MotoreOccasioni).
        // Passano da `stato.occasioni`, cioè dai clienti visibili: in modalità cliente non escono i nomi degli altri
        let sceltaOccasioni = dati.impostazioni.occasioni
        let fineOccasioni = cal.date(byAdding: .day, value: sceltaOccasioni.anticipoGiorni + 1, to: inizio) ?? inizio
        let vicine = MotoreOccasioni.daNotificare(stato.occasioni(da: inizio, a: fineOccasioni), oggi: oggi,
                                                  anticipoGiorni: sceltaOccasioni.anticipoGiorni, cal: cal)
        // Le importanti una per una (al massimo 3), le altre in una voce sola: le notifiche non si riempiono di occasioni
        let singole = Array(vicine.filter { $0.importanza == .alta }.prefix(3))
        let altre = vicine.filter { o in !singole.contains(o) }
        for o in singole + (altre.count == 1 ? altre : []) {
            let giorni = cal.dateComponents([.day], from: inizio, to: cal.startOfDay(for: o.data)).day ?? 0
            let quando: String
            if giorni == 0 {
                quando = "oggi"
            } else if giorni == 1 {
                quando = "domani"
            } else {
                quando = "tra \(giorni) giorni, \(Formati.dataEstesa.string(from: o.data))"
            }
            elenco.append(Notifica(id: "occasione-\(o.id)", gruppo: giorni == 0 ? .oggi : .prossimi, app: .agenda,
                                   titolo: o.titolo,
                                   dettaglio: "\(nome(o.clienteId)) · \(quando)",
                                   data: o.data, canale: o.canale, destinazione: nil))
        }
        if altre.count > 1, let primaAltra = altre.first {
            let canali = Set(altre.compactMap(\.canale))
            let titoliAltre = altre.prefix(2).map(\.titolo).joined(separator: " · ")
            elenco.append(Notifica(id: "occasioni-" + altre.map(\.id).joined(separator: ","), gruppo: .prossimi, app: .agenda,
                                   titolo: "\(altre.count) occasioni nei prossimi \(sceltaOccasioni.anticipoGiorni) giorni",
                                   dettaglio: titoliAltre + (altre.count > 2 ? " e altre" : ""),
                                   data: primaAltra.data, canale: canali.count == 1 ? canali.first : nil, destinazione: nil))
        }
        // Conformità: questionari, documento, adeguata verifica e consensi scaduti o in scadenza (MotoreConformita).
        // Solo i clienti visibili: in modalità cliente non escono i nomi degli altri
        let esitiConformita = stato.conformitaClienti(oggi: oggi)
        for a in MotoreConformita.avvisi(esitiConformita, oggi: oggi) {
            let gruppoConformita: Notifica.Gruppo
            switch a.urgenza {
            case .scaduta: gruppoConformita = .daFare
            case .entro30: gruppoConformita = a.giorni == 0 ? .oggi : .prossimi
            case .entro60: gruppoConformita = .daSistemare
            }
            elenco.append(Notifica(id: a.id, gruppo: gruppoConformita, app: .clienti, titolo: a.titolo, dettaglio: a.dettaglio,
                                   data: a.data, canale: a.canale,
                                   destinazione: a.clienteId.map { DestinazioneRicerca.cliente($0) },
                                   schedaCliente: a.clienteId == nil ? nil : .inRegola, testoRicerca: a.testoRicerca))
        }
        // Backup
        let b = dati.impostazioni.backup
        if let errore = b.ultimoErrore {
            elenco.append(Notifica(id: "backup-errore", gruppo: .daFare, app: .impostazioni,
                                   titolo: "L'ultimo backup non è riuscito", dettaglio: errore,
                                   data: b.ultimoTentativo ?? inizio, destinazione: .app(.impostazioni)))
        } else if b.inRitardo {
            elenco.append(Notifica(id: "backup-ritardo", gruppo: .daFare, app: .impostazioni,
                                   titolo: "Backup in ritardo",
                                   dettaglio: b.ultimo.map { "L'ultimo è del \(Formati.dataEstesa.string(from: $0))" } ?? "Non c'è ancora un backup",
                                   data: b.ultimo ?? inizio, destinazione: .app(.impostazioni)))
        }

        // In ogni gruppo prima le più vicine; tra le cose da recuperare il backup in cima, poi le più recenti
        return Notifica.Gruppo.allCases.flatMap { g in
            elenco.filter { $0.gruppo == g }.sorted { a, b in
                guard g == .daFare else { return a.data < b.data }
                if a.app == .impostazioni, b.app != .impostazioni { return true }
                if b.app == .impostazioni, a.app != .impostazioni { return false }
                return a.data > b.data
            }.prefix(massimoPerGruppo)
        }
    }

    /// Il prossimo compleanno da oggi (oggi compreso); il 29 febbraio negli anni non bisestili è il 28.
    static func prossimoCompleanno(_ nascita: Date, da inizio: Date, cal: Calendar) -> Date? {
        let g = cal.dateComponents([.month, .day], from: nascita)
        let anno = cal.component(.year, from: inizio)
        for a in [anno, anno + 1] {
            var c = DateComponents(year: a, month: g.month, day: g.day)
            if g.month == 2, g.day == 29, cal.date(from: DateComponents(year: a, month: 2, day: 29)).map({ cal.component(.day, from: $0) }) != 29 {
                c.day = 28
            }
            if let d = cal.date(from: c), d >= inizio { return d }
        }
        return nil
    }
}

extension StatoShell {
    /// Le notifiche non ancora viste (il numero sulla campanella).
    var notificheNuove: Int {
        notifiche.filter { $0.gruppo != .daSistemare && !notificheViste.contains($0.id) }.count
    }

    /// Apre o chiude il centro notifiche. Il pannello si apre subito; nell'app le notifiche si ricalcolano
    /// al giro dopo, così il calcolo non cade sul primo fotogramma dell'entrata (nelle istantanee e nelle
    /// prove subito, perché la schermata ferma le mostri già aggiornate).
    func alternaNotifiche() {
        pannelloNotifiche.toggle()
        guard pannelloNotifiche else { return }
        if pannelloSpazi { pannelloSpazi = false }
        guard persistente else {
            ricalcolaNotifiche()
            segnaNotificheViste()
            return
        }
        segnaNotificheViste()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pannelloNotifiche else { return }
            self.ricalcolaNotifiche()
            // Quelle arrivate con il ricalcolo sono già sotto gli occhi
            self.segnaNotificheViste()
        }
    }

    /// Le notifiche di adesso sono viste (lo stato cambia solo se ce n'è una nuova: niente ridisegni inutili).
    private func segnaNotificheViste() {
        let nuove = notifiche.map(\.id).filter { !notificheViste.contains($0) }
        if !nuove.isEmpty { notificheViste.formUnion(nuove) }
    }

    /// Le scadenze di conformità dei clienti visibili; per oggi tenute da parte come gli altri dati ricavati
    /// (la chiave comprende il giorno e la versione dei calcoli), per un altro giorno calcolate ogni volta.
    /// Il centro notifiche si ricalcola a ogni disegno della barra.
    func conformitaClienti(oggi: Date) -> [EsitoConformita] {
        guard Calendar.current.isDateInToday(oggi) else {
            return MotoreConformita.calcola(clienti: clienti, posizioni: dati.posizioni,
                                            regole: dati.impostazioni.conformita, oggi: oggi)
        }
        let d = derivatiValidi()
        if let elenco = d.conformitaClienti { return elenco }
        let elenco = MotoreConformita.calcola(clienti: clienti, posizioni: dati.posizioni,
                                              regole: dati.impostazioni.conformita, oggi: oggi)
        d.conformitaClienti = elenco
        return elenco
    }

    func apriNotifica(_ n: Notifica) {
        // Prima l'apertura animata dell'app, poi la chiusura del pannello (senza animazione propria)
        defer { if pannelloNotifiche { pannelloNotifiche = false } }
        // Più clienti (conformità): la ricerca ⌘K con il filtro già scritto
        if let t = n.testoRicerca {
            pannelloNotifiche = false
            testoRicerca = t
            cercaOvunque()
            return
        }
        if let d = n.destinazione {
            vai(a: d)
            // Un cliente solo: la scheda del dossier dopo l'apertura (`apriCliente` mette la Panoramica)
            if let s = n.schedaCliente { schedaCliente = s }
        } else if n.id.hasPrefix("beneficiari-"), let id = n.id.dropFirst("beneficiari-".count).split(separator: ",").first,
                  !n.id.contains(",") {
            // Un cliente solo: il suo passaggio generazionale in Posizioni
            clienteAttivoId = String(id)
            portafoglio = false
            posizioneInDettaglio = nil
            ancoraPosizioni = "successione"
            apri(.posizioni)
        } else if n.id.hasPrefix("beneficiari-") {
            // Più clienti: l'elenco «Da sistemare nei dossier» nel Portafoglio
            portafoglio = true
            posizioneInDettaglio = nil
            ancoraPosizioni = "attenzioni"
            apri(.posizioni)
        } else if n.id.hasPrefix("seguito-") {
            // Più proposte ferme: l'elenco «Proposte da riprendere» nel Portafoglio
            portafoglio = true
            posizioneInDettaglio = nil
            ancoraPosizioni = "seguito"
            apri(.posizioni)
        } else if n.id.hasPrefix("ricontattare-") || n.id.hasPrefix("fineanno-") {
            // Più clienti da ricontattare o con spazio deducibile: l'elenco è nel Portafoglio
            portafoglio = true
            posizioneInDettaglio = nil
            apri(.posizioni)
        } else if n.id.hasPrefix("occasione-") {
            // Un'occasione: la vista «Occasioni» dell'Agenda con l'occasione selezionata
            mostraOccasione(String(n.id.dropFirst("occasione-".count)))
        } else if n.id.hasPrefix("occasioni-") {
            // Più occasioni: la vista «Occasioni» da oggi, senza filtri («occasione-» non è il prefisso di «occasioni-»)
            filtroClienteAgenda = nil
            gruppoOccasioniAgenda = nil
            occasioneSelezionata = nil
            giornoAgenda = Calendar.current.startOfDay(for: Date())
            vistaAgenda = .occasioni
            apri(.agenda)
        } else {
            apri(n.app)
        }
    }
}

// MARK: - Promemoria del Mac

/// Un promemoria per il Centro notifiche del Mac, ricavato dai dati come le notifiche qui sopra.
/// Calcolo puro, senza UserNotifications: lo controlla `ProvaPromemoria`, lo consegna `PromemoriaMac`.
/// Nei testi niente cifre patrimoniali: il nome del cliente (se scelto) e cosa fare.
struct PromemoriaPianificato: Equatable {
    /// Comincia con «prisma-» e contiene la data: se un appuntamento si sposta l'id cambia e il vecchio si toglie.
    let id: String
    let titolo: String
    let corpo: String
    /// Raggruppa i promemoria nel Centro notifiche: agenda, attivita, posizioni, clienti, occasioni.
    let gruppo: String
    /// Quando arriva.
    let data: Date
    /// Dove porta il clic.
    let destinazione: DestinazioneRicerca?
}

extension MotoreNotifiche {
    /// Gli identificativi dei promemoria di Prisma nel Centro notifiche.
    static let prefissoPromemoria = "prisma-"
    /// macOS tiene al massimo 64 promemoria in sospeso per app: Prisma pianifica i 50 più vicini.
    static let massimoPromemoria = 50
    /// Attività, scadenze e compleanni arrivano a quest'ora del giorno.
    static let oraPromemoria = 9
    /// Le scadenze delle posizioni in essere: 30 e 7 giorni prima e il giorno stesso.
    static let giorniPrimaScadenza = [30, 7, 0]

    /// I promemoria futuri (dopo `adesso`), dal più vicino, al massimo `massimoPromemoria`.
    /// Guarda tutti i clienti (non solo quello della modalità cliente) e non legge `impostazioni.attivi`:
    /// se e quando consegnarli lo decide chi chiama.
    static func promemoria(_ dati: DatiPrisma, impostazioni: ImpostazioniPromemoria,
                           adesso: Date = Date(), cal: Calendar = .current) -> [PromemoriaPianificato] {
        let scelte = impostazioni
        let nomi = Dictionary(dati.clienti.map { ($0.id, $0.nome) }, uniquingKeysWith: { primo, _ in primo })
        func nome(_ id: String) -> String? {
            guard let n = nomi[id], !n.isEmpty else { return nil }
            return n
        }
        func allOra(_ giorno: Date) -> Date? {
            cal.date(bySettingHour: oraPromemoria, minute: 0, second: 0, of: giorno)
        }
        func epoca(_ d: Date) -> Int { Int(d.timeIntervalSince1970) }
        let dettagli = "apri Prisma per i dettagli"
        var elenco: [PromemoriaPianificato] = []

        // Appuntamenti ancora da fare: qualche minuto prima dell'inizio
        if scelte.appuntamenti {
            let anticipo = ImpostazioniPromemoria.nomeAnticipo(scelte.anticipoMinuti)
            for a in dati.appuntamenti where a.stato == .pianificato {
                let quando = Appuntamento.alMinuto(a.inizio.addingTimeInterval(-TimeInterval(scelte.anticipoMinuti * 60)))
                guard quando > adesso else { continue }
                let ora = Formati.ora.string(from: a.inizio)
                let cosa = a.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
                let titolo: String
                let corpo: String
                if scelte.nomiClienti {
                    titolo = "Alle \(ora) · \(cosa.isEmpty ? a.tipo.nome : cosa)"
                    corpo = ["Tra \(anticipo)", nome(a.clienteId) ?? "", a.luogo.trimmingCharacters(in: .whitespacesAndNewlines)]
                        .filter { !$0.isEmpty }.joined(separator: " · ")
                } else {
                    titolo = "Appuntamento alle \(ora)"
                    corpo = "Tra \(anticipo) · \(dettagli)"
                }
                elenco.append(PromemoriaPianificato(id: "\(prefissoPromemoria)appuntamento-\(a.id)-\(epoca(quando))",
                                                    titolo: titolo, corpo: corpo, gruppo: "agenda",
                                                    data: quando, destinazione: .appuntamento(a.id)))
            }
        }
        // Attività da fare: la mattina del giorno di scadenza
        if scelte.attivita {
            for t in dati.attivita where !t.completata {
                guard let quando = allOra(cal.startOfDay(for: t.scadenza)), quando > adesso else { continue }
                let cosa = t.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
                let titolo: String
                var parti: [String] = []
                if scelte.nomiClienti {
                    titolo = cosa.isEmpty ? "Un'attività da fare oggi" : cosa
                    if let n = nome(t.clienteId) {
                        parti = [n, "da fare oggi"]
                    } else {
                        parti = ["Da fare oggi"]
                    }
                } else {
                    titolo = "Un'attività da fare oggi"
                    parti = ["Apri Prisma per i dettagli"]
                }
                if t.priorita == .alta { parti.append("priorità alta") }
                elenco.append(PromemoriaPianificato(id: "\(prefissoPromemoria)attivita-\(t.id)-\(epoca(quando))",
                                                    titolo: titolo, corpo: parti.joined(separator: " · "), gruppo: "attivita",
                                                    data: quando, destinazione: .attivita(t.id)))
            }
        }
        // Posizioni in essere che scadono: il capitale da reinvestire, la copertura da rinnovare
        if scelte.scadenze {
            for p in dati.posizioni where p.stato == .inEssere {
                guard let scadenza = p.scadenza else { continue }
                let giornoScadenza = cal.startOfDay(for: scadenza)
                for giorni in giorniPrimaScadenza {
                    guard let giorno = cal.date(byAdding: .day, value: -giorni, to: giornoScadenza),
                          let quando = allOra(giorno), quando > adesso else { continue }
                    let fra = giorni == 0 ? "scade oggi" : "scade tra \(giorni) giorni"
                    let cosa = p.nome.trimmingCharacters(in: .whitespacesAndNewlines)
                    let titolo: String
                    let corpo: String
                    if scelte.nomiClienti {
                        titolo = "\(cosa.isEmpty ? "Una posizione" : cosa) \(fra)"
                        corpo = [nome(p.clienteId) ?? "", p.canale.nomeBreve, Formati.dataEstesa.string(from: scadenza)]
                            .filter { !$0.isEmpty }.joined(separator: " · ")
                    } else {
                        titolo = "Una posizione \(fra)"
                        corpo = "\(p.canale.nomeBreve) · \(dettagli)"
                    }
                    elenco.append(PromemoriaPianificato(id: "\(prefissoPromemoria)scadenza-\(p.id)-\(giorni)-\(epoca(scadenza))",
                                                        titolo: titolo, corpo: corpo, gruppo: "posizioni",
                                                        data: quando, destinazione: .posizione(p.id)))
                }
            }
        }
        // Compleanni dei clienti: la mattina del giorno
        if scelte.compleanni {
            let oggi = cal.startOfDay(for: adesso)
            for c in dati.clienti {
                guard let nascita = c.dataNascita, let giorno = prossimoCompleanno(nascita, da: oggi, cal: cal),
                      let quando = allOra(giorno), quando > adesso else { continue }
                let anno = cal.component(.year, from: giorno)
                let anni = anno - cal.component(.year, from: nascita)
                guard anni > 0 else { continue }
                let titolo = scelte.nomiClienti && !c.nome.isEmpty ? "Oggi \(c.nome) compie \(anni) anni" : "Oggi un cliente compie gli anni"
                let corpo = scelte.nomiClienti ? "Un pensiero fa piacere" : "Apri Prisma per vedere chi"
                elenco.append(PromemoriaPianificato(id: "\(prefissoPromemoria)compleanno-\(c.id)-\(anno)",
                                                    titolo: titolo, corpo: corpo, gruppo: "clienti",
                                                    data: quando, destinazione: .cliente(c.id)))
            }
        }
        // Occasioni: N giorni prima (anticipo in Impostazioni › Occasioni) e il giorno stesso, alle 9; niente cifre
        if scelte.occasioni {
            let regole = dati.impostazioni.occasioni
            let fino = cal.date(byAdding: .day, value: RegoleOccasioni.giorniPromemoria, to: adesso) ?? adesso
            let occasioni = MotoreOccasioni.calcola(clienti: dati.clienti, posizioni: dati.posizioni, prodotti: dati.prodotti,
                                                    da: adesso, a: fino, regole: regole, oggi: adesso, cal: cal)
                .filter(MotoreOccasioni.perPromemoria)
            let giorniPrima = Array(Set([regole.anticipoGiorni, 0])).sorted(by: >)
            for o in occasioni {
                for giorni in giorniPrima {
                    guard let giorno = cal.date(byAdding: .day, value: -giorni, to: cal.startOfDay(for: o.data)),
                          let quando = allOra(giorno), quando > adesso else { continue }
                    let fra = giorni == 0 ? "Oggi" : "Tra \(giorni) giorni"
                    let titolo = scelte.nomiClienti ? o.titolo : TestiOccasioni.titoloAnonimo(o)
                    let corpo: String
                    if scelte.nomiClienti {
                        corpo = [fra, nome(o.clienteId) ?? "", o.canale?.nomeBreve ?? "", Formati.dataEstesa.string(from: o.data)]
                            .filter { !$0.isEmpty }.joined(separator: " · ")
                    } else {
                        corpo = [fra, o.canale?.nomeBreve ?? "", dettagli].filter { !$0.isEmpty }.joined(separator: " · ")
                    }
                    let destinazione = o.posizioneId.map { DestinazioneRicerca.posizione($0) } ?? DestinazioneRicerca.cliente(o.clienteId)
                    elenco.append(PromemoriaPianificato(id: "\(prefissoPromemoria)occasione-\(o.id)-\(giorni)",
                                                        titolo: titolo, corpo: corpo, gruppo: "occasioni",
                                                        data: quando, destinazione: destinazione))
                }
            }
        }

        // Dal più vicino; un identificativo una volta sola; al massimo `massimoPromemoria`
        let ordinati = elenco.sorted { a, b in a.data != b.data ? a.data < b.data : a.id < b.id }
        var visti = Set<String>()
        var scelti: [PromemoriaPianificato] = []
        for v in ordinati {
            guard visti.insert(v.id).inserted else { continue }
            scelti.append(v)
            if scelti.count == massimoPromemoria { break }
        }
        return scelti
    }
}
