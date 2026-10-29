import Foundation

/// Ciò che la striscia «Riesami del mese» dell'Agenda mostra.
struct RiesamiDelMese {
    let mese: Date
    let daFissare: [RiesameDovuto]
    /// Revisioni periodiche già in agenda nel mese (qualunque stato).
    let fissati: [Appuntamento]
    /// Niente da mostrare: la striscia non compare.
    var vuota: Bool { daFissare.isEmpty && fissati.isEmpty }
    static func nessuno(_ mese: Date) -> RiesamiDelMese { .init(mese: mese, daFissare: [], fissati: []) }
}

/// La bozza di un riesame con lo spazio trovato (nil = nessuno spazio libero: data proposta come prima).
struct RiesamePianificato: Identifiable {
    let appuntamento: Appuntamento
    let spazio: SpazioLibero?
    var id: String { appuntamento.id }

    /// La riga in testa al modulo («Primo spazio libero negli orari di lavoro: …»).
    func spiegazione(orari: OrariLavoro) -> String {
        guard let s = spazio else {
            let settimane = MotorePianificazione.giorniRicerca / 7
            return "Nessuno spazio libero di un'ora nelle prossime \(settimane) settimane: scegli tu data e ora."
        }
        let quando = "\(Formati.dataLunga.string(from: s.inizio)) alle \(Formati.ora.string(from: s.inizio))"
        let saltati: String
        switch s.giorniPieni {
        case 0: saltati = ""
        case 1: saltati = " · 1 giorno pieno saltato"
        default: saltati = " · \(s.giorniPieni) giorni pieni saltati"
        }
        return "Primo spazio libero negli orari di lavoro (\(orari.descrizione)): \(quando)\(saltati)"
    }
}

extension StatoShell {
    /// I riesami del mese del giorno indicato, per l'Agenda (filtrati sul cliente dell'agenda).
    /// In modalità cliente nessuno: la striscia è uno strumento del consulente. Un calcolo leggero, una passata.
    func riesamiDelMese(_ giorno: Date, oggi: Date = Date()) -> RiesamiDelMese {
        let cal = MotorePianificazione.calendario
        guard let intervallo = cal.dateInterval(of: .month, for: giorno) else { return .nessuno(cal.startOfDay(for: giorno)) }
        guard modoCliente == nil else { return .nessuno(intervallo.start) }
        let filtro = filtroClienteAgenda
        // Un mese passato non ha riesami da fissare: si salta il calcolo dei dovuti
        let corrente = cal.dateInterval(of: .month, for: oggi)?.start ?? oggi
        var daFissare: [RiesameDovuto] = []
        if intervallo.start >= corrente {
            let n = MotorePianificazione.mesiOrizzonte(mese: giorno, oggi: oggi, cal: cal)
            // Lo spazio e gli ultimi contatti si guardano su tutto l'archivio (`dati.appuntamenti`)
            let tutti = MotoreRiesame.dovuti(clienti: clienti, posizioni: posizioni, appuntamenti: dati.appuntamenti,
                                             incontri: dati.incontri, oggi: oggi, mesiAvanti: n)
            daFissare = MotorePianificazione.delMese(tutti, mese: giorno, oggi: oggi, cal: cal)
                .filter { (d: RiesameDovuto) -> Bool in filtro.map { d.id == $0 } ?? true }
        }
        // Condizioni separate: il controllo dei tipi resta leggero
        let fissati: [Appuntamento] = dati.appuntamenti
            .filter { (a: Appuntamento) -> Bool in
                guard a.tipo == TipoAppuntamento.revisione else { return false }
                guard a.inizio >= intervallo.start, a.inizio < intervallo.end else { return false }
                if let f = filtro { return a.clienteId == f }
                return true
            }
            .sorted { $0.inizio < $1.inizio }
        return RiesamiDelMese(mese: intervallo.start, daFissare: daFissare, fissati: fissati)
    }

    /// Il riesame di un cliente nel primo spazio libero, da completare nel modulo dell'agenda.
    /// `mese`: il mese mostrato in Agenda (si cerca da lì in poi, mai prima di domani).
    /// Lo spazio si cerca sempre su tutti gli appuntamenti dell'archivio, anche in modalità cliente.
    func pianificaRiesame(_ clienteId: String, mese: Date? = nil, oggi: Date = Date()) -> RiesamePianificato? {
        guard let f = fonteEve(clienteId), let r = riesameCliente(clienteId) else { return nil }
        let cal = MotorePianificazione.calendario
        let orari = dati.impostazioni.orari
        var da = cal.date(byAdding: .day, value: MotorePianificazione.preavvisoGiorni, to: cal.startOfDay(for: oggi)) ?? oggi
        if let mese, let inizio = cal.dateInterval(of: .month, for: mese)?.start, inizio > da { da = inizio }
        let spazio = MotorePianificazione.primoSpazio(durata: MotorePianificazione.durataRiesame, da: da,
                                                      appuntamenti: dati.appuntamenti, orari: orari)
        var a: Appuntamento
        if let s = spazio {
            a = Appuntamento.nuovo(clienteId: clienteId, giorno: s.inizio)
            a.inizio = s.inizio
        } else {
            // Come prima: il primo giorno lavorativo tra una settimana, alle 9:30 (si sceglie a mano nel modulo).
            // Al massimo 14 giri: con un solo giorno di lavoro festivo per settimane il ciclo non gira all'infinito
            var giorno = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: oggi)) ?? oggi
            var giri = 0
            while !MotorePianificazione.lavorativo(giorno, orari: orari) && giri < 14 {
                giorno = cal.date(byAdding: .day, value: 1, to: giorno) ?? giorno
                giri += 1
            }
            a = Appuntamento.nuovo(clienteId: clienteId, giorno: giorno)
        }
        a.titolo = "Riesame annuale"
        a.tipo = .revisione
        a.durataMinuti = MotorePianificazione.durataRiesame
        a.luogo = "In studio"
        a.canale = MotorePianificazione.canale(f.posizioni, cliente: f.cliente)
        a.posizioneId = MotorePianificazione.posizioneDaDiscutere(r)
        let dovuto = r.ultimoContatto.flatMap { cal.date(byAdding: .month, value: MotoreRiesame.mesiRiesame, to: $0) }
        a.note = MotorePianificazione.noteRiesame(punti: r.punti, canali: MotorePianificazione.canali(f.posizioni),
                                                  canale: a.canale, ultimoContatto: r.ultimoContatto,
                                                  dovutoDal: dovuto, oggi: oggi)
        // Memoria del riesame: l'ordine del giorno si apre con le variazioni dal riesame precedente
        // (senza fotografie del cliente le note restano com'erano e la memoria non si calcola)
        if dati.fotografie.contains(where: { $0.clienteId == clienteId }) {
            a.note = MotoreMemoria.apriConVariazioni(a.note, memoria: memoriaRiesame(clienteId))
        }
        return RiesamePianificato(appuntamento: a, spazio: spazio)
    }
}
