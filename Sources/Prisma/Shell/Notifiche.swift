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
        func nome(_ id: String) -> String { stato.cliente(id)?.nome ?? "Senza cliente" }
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
        for a in dati.appuntamenti where a.stato == .pianificato && a.fine <= oggi && a.fine > cal.date(byAdding: .day, value: -giorniAvanti, to: inizio) ?? inizio {
            elenco.append(Notifica(id: "esito-\(a.id)", gruppo: .daFare, app: .agenda,
                                   titolo: "Com'è andato «\(a.titolo)»?",
                                   dettaglio: "\(nome(a.clienteId)) · \(Formati.giornoMese.string(from: a.inizio)): segna l'esito in agenda",
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

    func alternaNotifiche() {
        pannelloNotifiche.toggle()
        if pannelloNotifiche {
            ricalcolaNotifiche()
            pannelloSpazi = false
            notificheViste.formUnion(notifiche.map(\.id))
        }
    }

    func apriNotifica(_ n: Notifica) {
        pannelloNotifiche = false
        if let d = n.destinazione {
            vai(a: d)
        } else if n.id.hasPrefix("ricontattare-") || n.id.hasPrefix("fineanno-") {
            // Più clienti da ricontattare o con spazio deducibile: l'elenco è nel Portafoglio
            portafoglio = true
            posizioneInDettaglio = nil
            apri(.posizioni)
        } else {
            apri(n.app)
        }
    }
}
