import Foundation

// MARK: - Seguito delle proposte (giro 3, specifica 5)
// Motore puro: niente SwiftUI e niente `Date()`. Ogni funzione riceve `adesso`; i giorni si contano sul
// calendario (`startOfDay` e `dateComponents([.day])`), mai dividendo per 86.400: le prove attraversano il
// cambio dell'ora del 25 ottobre 2026.

/// Una proposta ferma: da recuperare.
struct PropostaInSospeso: Identifiable, Hashable {
    enum Motivo: Hashable { case senzaRisposta, daRiprendere }
    /// Da dove viene la data da cui si contano i giorni.
    enum Fonte: Hashable { case presentazione, ultimoContatto, esito, ripresa, creazione }

    let posizione: Posizione
    let cliente: Cliente
    let motivo: Motivo
    let dal: Date
    let fonte: Fonte
    /// Giorni interi da `dal` a oggi.
    let giorni: Int
    /// Ferma da più del doppio della soglia (le «da riprendere» con data: oltre la soglia): in rosso.
    let urgente: Bool

    var id: String { posizione.id }
}

/// Il passo del modulo dell'esito (vive nel motore perché lo decide `passoIniziale`).
enum PassoEsito: Hashable { case scelta, accettata, rifiutata, rimandata }

/// I dati per passare in essere una proposta accettata.
struct DatiAccettazione: Equatable {
    var decorrenza: Date
    /// Controvalore alla decorrenza (nil per protezione e debiti).
    var primoValore: Double?
    /// Primo premio o versamento pagato.
    var versato: Double?
    var scadenza: Date?
    /// Solo previdenza: data della prima adesione a una forma complementare (D.Lgs. 252/2005, art. 11 c. 6).
    var primaAdesione: Date?
    var nota = ""
}

/// Cosa si sceglie chiudendo una proposta.
enum EsitoScelto: Equatable {
    case accettata(DatiAccettazione)
    case rifiutata(motivo: MotivoEsito?, nota: String)
    case rimandata(al: Date, motivo: MotivoEsito?, nota: String)
    /// «Ci deve pensare»: resta presentata.
    case inAttesa
}

/// Un controllo sui dati dell'accettazione.
struct AvvisoEsito: Hashable {
    let testo: String
    /// true: il pulsante «Passa in essere» resta spento.
    let bloccante: Bool
}

/// Motivi di rifiuto e di rinvio e tempo di decisione delle proposte (Portafoglio).
struct StatisticheEsiti: Equatable {
    /// Dal motivo più frequente; a parità, in ordine di `MotivoEsito.allCases`.
    let motiviRifiuto: [(motivo: MotivoEsito, volte: Int)]
    let motiviRinvio: [(motivo: MotivoEsito, volte: Int)]
    /// Media dei giorni da `presentataIl` a `esitoIl` delle proposte accettate o rifiutate che hanno entrambe le date.
    let giorniMediDecisione: Double?
    /// Quante proposte entrano nella media.
    let decise: Int

    /// Nessun dato da mostrare.
    var vuote: Bool { motiviRifiuto.isEmpty && motiviRinvio.isEmpty && giorniMediDecisione == nil }

    // Scritto a mano: le tuple non sono Equatable
    // (Spezzato in passi: un'unica espressione con tante closure e `==` rallenta troppo il controllo dei tipi.)
    static func == (a: StatisticheEsiti, b: StatisticheEsiti) -> Bool {
        guard a.giorniMediDecisione == b.giorniMediDecisione, a.decise == b.decise else { return false }
        return stessi(a.motiviRifiuto, b.motiviRifiuto) && stessi(a.motiviRinvio, b.motiviRinvio)
    }

    private static func stessi(_ x: [(motivo: MotivoEsito, volte: Int)], _ y: [(motivo: MotivoEsito, volte: Int)]) -> Bool {
        guard x.count == y.count else { return false }
        for (p, q) in zip(x, y) where p.motivo != q.motivo || p.volte != q.volte { return false }
        return true
    }
}

enum MotoreSeguitoProposte {
    static let tipiConEsito: Set<TipoAppuntamento> = [.proposta, .firma]
    /// Una decorrenza oltre un mese da oggi si blocca: l'esito si segna quando il contratto sta per partire.
    static let giorniDecorrenzaFutura = 31
    /// Decorrenza più vecchia di così: avviso (lo storico va completato con «Valore passato»).
    static let giorniDecorrenzaPassata = 365
    /// Scarto oltre il quale il primo valore «si discosta» dal versato.
    static let scartoPrimoValore = 0.20
    /// Mesi della ripresa che si possono scegliere per una rimandata; 3 di partenza.
    static let sceltaRipresaMesi = [1, 3, 6, 12]
    static let ripresaPredefinitaMesi = 3
    /// Recesso dalle polizze vita: 30 giorni (art. 177 D.Lgs. 209/2005).
    static let giorniRecessoVita = 30

    /// Giorni di calendario da `a` a `b` (negativi se `b` viene prima).
    static func giorni(da a: Date, a b: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
    }

    // MARK: - Proposte ferme

    /// Le proposte presentate da più di `soglia` giorni senza un appuntamento in agenda e le rimandate arrivate
    /// alla data di ripresa, dalla più ferma. In O(P + A + T): regge i 200 clienti di `--prova-carico`.
    static func inSospeso(posizioni: [Posizione], clienti: [Cliente], appuntamenti: [Appuntamento],
                          attivita: [Attivita], adesso: Date, soglia: Int) -> [PropostaInSospeso] {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: adesso)
        let clientiPerId = Dictionary(clienti.map { ($0.id, $0) }, uniquingKeysWith: { primo, _ in primo })
        var futuriPerCliente: [String: [Appuntamento]] = [:]
        var passatiPerPosizione: [String: [Appuntamento]] = [:]
        for a in appuntamenti {
            if a.stato == .pianificato && a.inizio >= adesso { futuriPerCliente[a.clienteId, default: []].append(a) }
            if let pid = a.posizioneId, a.inizio < adesso { passatiPerPosizione[pid, default: []].append(a) }
        }
        var aperte = Set<String>()
        for t in attivita where !t.completata { aperte.insert(t.id) }

        var elenco: [PropostaInSospeso] = []
        for p in posizioni where p.stato == .proposta {
            guard let esito = p.esito, esito == .presentata || esito == .rimandata,
                  let cliente = clientiPerId[p.clienteId] else { continue }
            // Seguito in agenda: un appuntamento futuro del cliente non collegato a un'altra posizione
            if (futuriPerCliente[p.clienteId] ?? []).contains(where: { $0.posizioneId == nil || $0.posizioneId == p.id }) { continue }
            let rimandata = esito == .rimandata
            if rimandata {
                // La ricorda già l'attività della ripresa (widget «Da fare», notifica dell'attività scaduta)
                if let t = p.seguito?.attivitaId, aperte.contains(t) { continue }
                if let ripresa = p.seguito?.riprendereIl {
                    // La data l'ha scelta il consulente: niente soglia
                    guard cal.startOfDay(for: ripresa) <= oggi else { continue }
                    let g = giorni(da: ripresa, a: adesso)
                    elenco.append(PropostaInSospeso(posizione: p, cliente: cliente, motivo: .daRiprendere, dal: ripresa,
                                                    fonte: .ripresa, giorni: g, urgente: g > soglia))
                    continue
                }
            }
            let rif = riferimento(p, passatiCollegati: passatiPerPosizione[p.id] ?? [])
            let g = giorni(da: rif.data, a: adesso)
            // «Più di N giorni»: con N = 21, 21 giorni non bastano e 22 sì
            guard g > soglia else { continue }
            elenco.append(PropostaInSospeso(posizione: p, cliente: cliente, motivo: rimandata ? .daRiprendere : .senzaRisposta,
                                            dal: rif.data, fonte: rif.fonte, giorni: g, urgente: g > 2 * soglia))
        }
        return elenco.sorted { a, b in
            if a.giorni != b.giorni { return a.giorni > b.giorni }
            if a.cliente.nome != b.cliente.nome { return a.cliente.nome.localizedCompare(b.cliente.nome) == .orderedAscending }
            return a.posizione.nome.localizedCompare(b.posizione.nome) == .orderedAscending
        }
    }

    /// La data da cui si contano i giorni: la più recente tra presentazione, esito (solo per le rimandate) e
    /// ultimo appuntamento passato collegato; senza nessuna, l'inserimento (gli archivi di prima funzionano così).
    static func riferimento(_ p: Posizione, passatiCollegati: [Appuntamento]) -> (data: Date, fonte: PropostaInSospeso.Fonte) {
        var migliore: (data: Date, fonte: PropostaInSospeso.Fonte)?
        func considera(_ d: Date?, _ f: PropostaInSospeso.Fonte) {
            guard let d else { return }
            if let m = migliore, m.data >= d { return }
            migliore = (data: d, fonte: f)
        }
        considera(p.seguito?.presentataIl, .presentazione)
        if p.esito == .rimandata { considera(p.seguito?.esitoIl, .esito) }
        considera(passatiCollegati.map(\.inizio).max(), .ultimoContatto)
        if let m = migliore { return m }
        return (data: p.creataIl, fonte: .creazione)
    }

    // MARK: - Chiusura dell'appuntamento

    /// Va chiesto l'esito della proposta collegata a questo appuntamento concluso.
    static func richiedeEsito(_ a: Appuntamento, posizione: Posizione?) -> Bool {
        guard let p = posizione, a.stato == .concluso, tipiConEsito.contains(a.tipo),
              p.id == a.posizioneId, p.stato == .proposta else { return false }
        let esito = p.esito ?? .bozza
        guard esito == .bozza || esito == .presentata || esito == .rimandata else { return false }
        return p.seguito?.appuntamentoEsitoId != a.id
    }

    /// Da dove parte il modulo dell'esito: per una Firma da «Accettata», altrimenti dalla scelta.
    static func passoIniziale(_ a: Appuntamento?) -> PassoEsito {
        a?.tipo == .firma ? .accettata : .scelta
    }

    /// Un appuntamento di proposta o di firma appena concluso: la proposta collegata risulta presentata.
    static func dopoConclusione(_ a: Appuntamento, posizione p: inout Posizione) {
        guard tipiConEsito.contains(a.tipo), a.posizioneId == p.id, p.stato == .proposta,
              p.esito != .accettata, p.esito != .rifiutata else { return }
        var s = p.seguito ?? SeguitoProposta()
        switch p.esito ?? .bozza {
        case .bozza:
            p.esito = .presentata
        case .rimandata:
            // Ripresentata: la ripresa è fatta
            p.esito = .presentata
            s.riprendereIl = nil
        default:
            break
        }
        s.presentataIl = max(s.presentataIl ?? a.inizio, a.inizio)
        p.seguito = s.vuoto ? nil : s
    }

    /// Le modifiche fatte a mano con «Modifica» (ModuloPosizione): date di presentazione e di esito.
    static func registraCambio(da prima: Posizione?, a p: inout Posizione, adesso: Date) {
        let primaEsito = prima?.esito
        var s = p.seguito ?? SeguitoProposta()
        if p.esito == .presentata && primaEsito != .presentata { s.presentataIl = adesso }
        if let e = p.esito, e == .accettata || e == .rifiutata || e == .rimandata, e != primaEsito { s.esitoIl = adesso }
        if primaEsito == .rimandata && p.esito != .rimandata { s.riprendereIl = nil }
        p.seguito = s.vuoto ? nil : s
    }

    // MARK: - Accettazione

    /// Il primo versamento: l'iniziale se c'è, altrimenti il premio periodico.
    static func primoVersamento(_ p: Posizione) -> Double? {
        if p.versamentoIniziale > 0 { return p.versamentoIniziale }
        if p.frequenza != .unica && p.premio > 0 { return p.premio }
        return nil
    }

    /// I dati proposti nel passo «Accettata»: si cambiano nel modulo.
    static func datiProposti(_ p: Posizione, appuntamento: Appuntamento?, altre: [Posizione], adesso: Date) -> DatiAccettazione {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: adesso)
        let minimo = cal.date(byAdding: .day, value: -giorniDecorrenzaPassata, to: oggi) ?? oggi
        let massimo = cal.date(byAdding: .day, value: giorniDecorrenzaFutura, to: oggi) ?? oggi
        let base: Date
        if let d = p.decorrenza, cal.startOfDay(for: d) >= minimo, cal.startOfDay(for: d) <= massimo {
            base = d
        } else if let a = appuntamento {
            base = a.inizio
        } else {
            base = adesso
        }
        let decorrenza = ValoriDaDocumento.mezzogiorno(base)
        let versato = primoVersamento(p)
        var primoValore: Double?
        if p.area != .protezione && p.area != .debiti, let v = versato {
            primoValore = (v * (1 - (p.costoIngresso ?? 0) / 100) * 100).rounded() / 100
        }
        var d = DatiAccettazione(decorrenza: decorrenza, primoValore: primoValore, versato: versato,
                                 scadenza: scadenzaSpostata(p, decorrenza: decorrenza))
        if p.area == .previdenza {
            // Gli anni di partecipazione contano anche se maturati in un'altra forma (D.Lgs. 252/2005, art. 11 c. 6)
            var date: [Date] = p.primaAdesione.map { [$0] } ?? []
            for o in altre where o.id != p.id && o.clienteId == p.clienteId && o.area == .previdenza && o.stato == .inEssere {
                if let x = o.primaAdesione ?? o.decorrenza { date.append(x) }
            }
            d.primaAdesione = date.min().map(ValoriDaDocumento.mezzogiorno) ?? decorrenza
        }
        return d
    }

    /// La scadenza spostata come la decorrenza: la durata della proposta resta la stessa.
    static func scadenzaSpostata(_ p: Posizione, decorrenza: Date) -> Date? {
        guard let scadenza = p.scadenza else { return nil }
        let cal = Calendar.current
        let rif = p.decorrenza ?? p.creataIl
        let durata = cal.dateComponents([.month, .day], from: cal.startOfDay(for: rif), to: cal.startOfDay(for: scadenza))
        return cal.date(byAdding: durata, to: decorrenza).map(ValoriDaDocumento.mezzogiorno)
    }

    /// La durata della proposta in anni interi (per la nota della scadenza spostata); nil senza scadenza.
    static func anniDurata(_ p: Posizione) -> Int? {
        guard let scadenza = p.scadenza else { return nil }
        let cal = Calendar.current
        let rif = p.decorrenza ?? p.creataIl
        let mesi = cal.dateComponents([.month], from: cal.startOfDay(for: rif), to: cal.startOfDay(for: scadenza)).month ?? 0
        return mesi > 0 ? Int((Double(mesi) / 12).rounded()) : nil
    }

    /// I controlli sui dati dell'accettazione: i bloccanti spengono «Passa in essere».
    static func verifica(_ d: DatiAccettazione, posizione p: Posizione, adesso: Date) -> [AvvisoEsito] {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: adesso)
        let decorrenza = cal.startOfDay(for: d.decorrenza)
        var avvisi: [AvvisoEsito] = []
        // B1–B4: bloccanti
        if let massimo = cal.date(byAdding: .day, value: giorniDecorrenzaFutura, to: oggi), decorrenza > massimo {
            avvisi.append(AvvisoEsito(testo: TestiSeguito.avvisoDecorrenzaFutura, bloccante: true))
        }
        if (d.primoValore ?? 0) < 0 || (d.versato ?? 0) < 0 {
            avvisi.append(AvvisoEsito(testo: TestiSeguito.avvisoNegativi, bloccante: true))
        }
        if let s = d.scadenza, cal.startOfDay(for: s) <= decorrenza {
            avvisi.append(AvvisoEsito(testo: TestiSeguito.avvisoScadenza, bloccante: true))
        }
        if p.area == .previdenza, let a = d.primaAdesione, cal.startOfDay(for: a) > decorrenza {
            avvisi.append(AvvisoEsito(testo: TestiSeguito.avvisoPrimaAdesione, bloccante: true))
        }
        // A1–A3: avvisi
        if let minimo = cal.date(byAdding: .day, value: -giorniDecorrenzaPassata, to: oggi), decorrenza < minimo {
            avvisi.append(AvvisoEsito(testo: TestiSeguito.avvisoDecorrenzaVecchia, bloccante: false))
        }
        if let v = d.versato, v > 0, let pv = d.primoValore, abs(pv - v) / v > scartoPrimoValore {
            avvisi.append(AvvisoEsito(testo: TestiSeguito.avvisoScarto, bloccante: false))
        }
        if p.area.proiettabile && d.primoValore == nil && d.versato == nil {
            avvisi.append(AvvisoEsito(testo: TestiSeguito.avvisoSenzaValori, bloccante: false))
        }
        return avvisi
    }

    // MARK: - Esito

    /// Applica l'esito; per «rimandata» restituisce l'attività da aggiungere (il suo id è già in `seguito.attivitaId`).
    static func applica(_ e: EsitoScelto, a p: inout Posizione, appuntamentoId: String?, adesso: Date) -> Attivita? {
        var s = p.seguito ?? SeguitoProposta()
        var nuova: Attivita?
        switch e {
        case .accettata(let d):
            p.stato = .inEssere
            p.esito = .accettata
            p.decorrenza = d.decorrenza
            p.scadenza = d.scadenza
            if p.area != .protezione && p.area != .debiti {
                // Il valore all'avvio del contratto (anche con la decorrenza futura, al massimo di un mese)
                p.controvalore = d.primoValore
                p.dataValore = d.primoValore == nil ? nil : d.decorrenza
            }
            p.totaleVersato = d.versato
            if p.area == .previdenza { p.primaAdesione = d.primaAdesione }
            // Le rilevazioni restano: i valori della proposta non sono storia
            s.esitoIl = adesso
            s.nota = d.nota
            s.riprendereIl = nil
            s.appuntamentoEsitoId = appuntamentoId
        case .rifiutata(let motivo, let nota):
            // Lo stato resta «proposta»: la rifiutata resta nel dossier e nel tasso di accettazione
            p.esito = .rifiutata
            s.esitoIl = adesso
            s.motivo = motivo
            s.nota = nota
            s.riprendereIl = nil
            s.appuntamentoEsitoId = appuntamentoId
        case .rimandata(let al, let motivo, let nota):
            p.esito = .rimandata
            s.esitoIl = adesso
            s.riprendereIl = ValoriDaDocumento.mezzogiorno(al)
            s.motivo = motivo
            s.nota = nota
            s.appuntamentoEsitoId = appuntamentoId
            var t = Attivita.nuova(clienteId: p.clienteId, scadenza: al)
            t.titolo = TestiSeguito.titoloRipresa(p)
            t.priorita = .normale
            t.note = TestiSeguito.noteRipresa(adesso: adesso, motivo: motivo, nota: nota)
            t.appuntamentoId = appuntamentoId
            s.attivitaId = t.id
            nuova = t
        case .inAttesa:
            p.esito = .presentata
            s.presentataIl = s.presentataIl ?? adesso
            s.appuntamentoEsitoId = appuntamentoId
        }
        p.seguito = s.vuoto ? nil : s
        return nuova
    }

    /// Fine del recesso dalle polizze vita e dai PIP: 30 giorni dalla firma (art. 177 D.Lgs. 209/2005).
    /// Indicativa: la conclusione del contratto la comunica la compagnia. nil per fondi, ETF, danni e infortuni.
    static func fineRecesso(_ p: Posizione, firma: Date) -> Date? {
        let vita = p.regime == .polizza || (p.area == .protezione && p.rischio == .vita)
        let t = p.tipologia.lowercased()
        let pip = p.regime == .previdenza && (t.contains("pip") || t.contains("individuale pensionistic"))
        guard vita || pip else { return nil }
        return Calendar.current.date(byAdding: .day, value: giorniRecessoVita, to: firma)
    }

    // MARK: - Analisi

    /// Motivi delle rifiutate e delle rimandate (quelle con il motivo) e tempo medio di decisione.
    static func statistiche(_ posizioni: [Posizione]) -> StatisticheEsiti {
        var rifiuto: [MotivoEsito: Int] = [:]
        var rinvio: [MotivoEsito: Int] = [:]
        var tempi: [Int] = []
        for p in posizioni {
            if let m = p.seguito?.motivo {
                if p.esito == .rifiutata { rifiuto[m, default: 0] += 1 }
                if p.esito == .rimandata { rinvio[m, default: 0] += 1 }
            }
            if p.esito == .accettata || p.esito == .rifiutata,
               let presentata = p.seguito?.presentataIl, let esito = p.seguito?.esitoIl {
                tempi.append(max(0, giorni(da: presentata, a: esito)))
            }
        }
        func ordina(_ conta: [MotivoEsito: Int]) -> [(motivo: MotivoEsito, volte: Int)] {
            var voci: [(motivo: MotivoEsito, volte: Int)] = []
            for m in MotivoEsito.allCases {
                if let n = conta[m] { voci.append((motivo: m, volte: n)) }
            }
            // Ordinamento stabile: a parità di volte resta l'ordine di `MotivoEsito.allCases`
            let numerate: [(indice: Int, voce: (motivo: MotivoEsito, volte: Int))] = voci.enumerated().map { (indice: $0.offset, voce: $0.element) }
            let ordinate = numerate.sorted { a, b in
                a.voce.volte != b.voce.volte ? a.voce.volte > b.voce.volte : a.indice < b.indice
            }
            return ordinate.map { $0.voce }
        }
        return StatisticheEsiti(motiviRifiuto: ordina(rifiuto), motiviRinvio: ordina(rinvio),
                                giorniMediDecisione: tempi.isEmpty ? nil : Double(tempi.reduce(0, +)) / Double(tempi.count),
                                decise: tempi.count)
    }
}
