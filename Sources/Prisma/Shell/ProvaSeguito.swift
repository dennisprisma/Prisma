import Foundation

/// Prove del seguito delle proposte che hanno bisogno di `StatoShell` (giro 3, specifica 5, §7.3): chiusura
/// dell'appuntamento, esito, proposte ferme in cache, notifiche, bozza della telefonata. Chiamate da
/// `ProvaCarico.esegui()` accanto a `ProvaPromemoria.verifiche()`; ogni controllo parte da uno stato di prova
/// nuovo, con date relative a oggi. Le descrizioni hanno già il prefisso «Seguito: ».
@MainActor
enum ProvaSeguito {
    static let pip = "pos-giulia-piano-previdenziale-integrativo"
    static let obbligazionario = "pos-sofia-obbligazionario-a-scadenza-2030"
    static let infortuniLaura = "pos-laura-infortuni-e-invalidità-professionale"
    static let studiAnna = "pos-marco-piano-per-gli-studi-di-anna"

    static func verifiche() -> [(Bool, String)] {
        var esiti: [(Bool, String)] = []
        func controlla(_ ok: Bool, _ descrizione: String) {
            esiti.append((ok, "Seguito: " + descrizione))
        }
        let cal = Calendar.current
        let adesso = Date()
        let oggi = cal.startOfDay(for: adesso)
        func giorno(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: oggi) ?? oggi }
        func posizione(_ s: StatoShell, _ id: String) -> Posizione? { s.dati.posizioni.first { $0.id == id } }
        func evento(_ s: StatoShell, _ id: String) -> Appuntamento? { s.dati.appuntamenti.first { $0.id == id } }

        /// L'appuntamento di Laura spostato a ieri alle 10 e concluso (la sua proposta di infortuni, ancora bozza).
        func lauraConclusa() -> (StatoShell, Date) {
            let s = StatoShell(persistente: false)
            let ieri10 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: giorno(-1)) ?? giorno(-1)
            if let k = s.dati.appuntamenti.firstIndex(where: { $0.id == "event-laura" }) { s.dati.appuntamenti[k].inizio = ieri10 }
            s.alternaConcluso("event-laura")
            return (s, ieri10)
        }

        /// La PIP di Giulia presentata da `giorni` giorni, senza appuntamenti futuri di Giulia.
        func pipFerma(_ s: StatoShell, giorni: Int) {
            s.dati.appuntamenti.removeAll { $0.clienteId == "giulia" && $0.inizio >= oggi }
            if let i = s.dati.posizioni.firstIndex(where: { $0.id == pip }) {
                var seguito = SeguitoProposta()
                seguito.presentataIl = ValoriDaDocumento.mezzogiorno(giorno(-giorni))
                s.dati.posizioni[i].esito = .presentata
                s.dati.posizioni[i].seguito = seguito
            }
        }

        // 1. Concludere una presentazione segna la proposta come presentata e chiede l'esito
        do {
            let (s, ieri10) = lauraConclusa()
            let p = posizione(s, infortuniLaura)
            let a = evento(s, "event-laura")
            let presentata = p?.esito == EsitoProposta.presentata
            let quando = p?.seguito?.presentataIl == ieri10
            controlla(presentata && quando, "appuntamento di proposta concluso: proposta di Laura presentata il giorno dell'incontro")
            controlla(a.flatMap { s.propostaDaChiudere($0) } != nil, "il dettaglio dell'appuntamento chiede l'esito")
        }

        // 2. Accettata con i dati veri
        do {
            let (s, _) = lauraConclusa()
            if let p = posizione(s, infortuniLaura), let a = evento(s, "event-laura") {
                let decorrenza = ValoriDaDocumento.mezzogiorno(giorno(5))
                var d = s.datiAccettazione(p, appuntamento: a)
                d.decorrenza = decorrenza
                d.versato = 380
                d.scadenza = nil
                s.chiudiProposta(p.id, .accettata(d), appuntamentoId: a.id)
                let dopo = posizione(s, infortuniLaura)
                // Condizioni separate: il controllo dei tipi resta leggero
                let inEssere = dopo?.stato == StatoPosizione.inEssere
                let stessaDecorrenza = dopo?.decorrenza == decorrenza
                let versato: Double? = dopo?.totaleVersato
                controlla(inEssere && stessaDecorrenza && versato == 380.0,
                          "accettata: in essere con la decorrenza scelta e 380 € versati")
                controlla(evento(s, "event-laura").flatMap { s.propostaDaChiudere($0) } == nil, "accettata: l'esito non si chiede più")
            } else {
                controlla(false, "proposta e appuntamento di Laura")
            }
        }

        // 3. attivaProposta (compatibilità): i dati proposti, non più «versamento iniziale senza costi»
        do {
            let s = StatoShell(persistente: false)
            if let p = posizione(s, obbligazionario) {
                let atteso = s.datiAccettazione(p, appuntamento: nil)
                s.attivaProposta(p.id)
                let dopo = posizione(s, obbligazionario)
                // Condizioni separate: il controllo dei tipi resta leggero
                let inEssere = dopo?.stato == StatoPosizione.inEssere
                let decorrenzaOk = dopo?.decorrenza == atteso.decorrenza
                let versatoOk = dopo?.totaleVersato == atteso.versato
                let valoreOk = dopo?.controvalore == atteso.primoValore
                let scadenzaOk = dopo?.scadenza == atteso.scadenza
                controlla(inEssere && decorrenzaOk && versatoOk && valoreOk && scadenzaOk,
                          "attivaProposta usa i dati proposti (decorrenza a mezzogiorno, scadenza spostata)")
            } else {
                controlla(false, "proposta di Sofia")
            }
        }

        // 4. Rimandata: l'attività della ripresa e fuori dalle proposte ferme
        do {
            let s = StatoShell(persistente: false)
            pipFerma(s, giorni: 30)
            if let p = posizione(s, pip) {
                let prima = s.dati.attivita.count
                s.chiudiProposta(p.id, .rimandata(al: ValoriDaDocumento.mezzogiorno(giorno(90)), motivo: .tempi, nota: ""), appuntamentoId: nil)
                let titolo = TestiSeguito.titoloRipresa(p)
                let t = s.dati.attivita.first { $0.titolo == titolo && !$0.completata }
                controlla(s.dati.attivita.count == prima + 1 && t != nil, "rimandata: un'attività «\(titolo)» in più")
                controlla(t != nil && posizione(s, pip)?.seguito?.attivitaId == t?.id, "rimandata: l'attività è quella del seguito")
                controlla(!s.proposteInSospeso.contains { $0.id == pip }, "rimandata: non è tra le proposte ferme")
            } else {
                controlla(false, "PIP di Giulia")
            }
        }

        // 5. Presentata da 30 giorni senza appuntamenti: ferma, con la sua notifica
        do {
            let s = StatoShell(persistente: false)
            pipFerma(s, giorni: 30)
            let ferma = s.proposteInSospeso.first { $0.id == pip }
            controlla(ferma?.giorni == 30, "PIP presentata da 30 giorni senza appuntamenti: ferma da \(ferma?.giorni ?? -1) giorni")
            let n = MotoreNotifiche.calcola(s).first { $0.id.hasPrefix("seguito-\(pip)-") }
            // Condizioni separate: il controllo dei tipi resta leggero
            let daFare = n?.gruppo == Notifica.Gruppo.daFare
            let alleanza = n?.canale == Canale.alleanza
            let apreProposta = n?.destinazione == DestinazioneRicerca.posizione(pip)
            controlla(daFare && alleanza && apreProposta, "notifica da recuperare, canale Alleanza, apre la proposta")
        }

        // 6. Con 45 giorni non è ferma (e la cache si rifà cambiando l'impostazione)
        do {
            let s = StatoShell(persistente: false)
            pipFerma(s, giorni: 30)
            let con21 = s.proposteInSospeso.contains { $0.id == pip }
            s.dati.impostazioni.giorniSeguitoProposte = 45
            controlla(con21 && !s.proposteInSospeso.contains { $0.id == pip }, "con 45 giorni la PIP non è ferma (cache rifatta)")
        }

        // 7. Due proposte ferme: una notifica sola che apre il Portafoglio
        do {
            let s = StatoShell(persistente: false)
            pipFerma(s, giorni: 30)
            s.dati.appuntamenti.removeAll { $0.clienteId == "sofia" && $0.inizio >= oggi }
            if let i = s.dati.posizioni.firstIndex(where: { $0.id == obbligazionario }) {
                var presentata = SeguitoProposta()
                presentata.presentataIl = ValoriDaDocumento.mezzogiorno(giorno(-34))
                s.dati.posizioni[i].seguito = presentata
            }
            let seguito = MotoreNotifiche.calcola(s).filter { $0.id.hasPrefix("seguito-") }
            let unaSola = seguito.count == 1
            let dueId = seguito.first?.id.contains(",") ?? false
            let senzaDestinazione = seguito.first.map { $0.destinazione == nil } ?? false
            controlla(unaSola && dueId && senzaDestinazione, "due proposte ferme: una notifica sola (\(seguito.count))")
            if let n = seguito.first {
                s.apriNotifica(n)
                let ancora = s.ancoraPosizioni == "seguito"
                let inPosizioni = s.appAttiva == AppPrisma.posizioni
                controlla(s.portafoglio && ancora && inPosizioni, "la notifica apre «Proposte da riprendere» nel Portafoglio")
            }
        }

        // 8. «Fissa»: la telefonata di seguito toglie la proposta dall'elenco
        do {
            let s = StatoShell(persistente: false)
            pipFerma(s, giorni: 30)
            if let ferma = s.proposteInSospeso.first(where: { $0.id == pip }) {
                let bozza = s.bozzaSeguito(ferma)
                let presentazione = bozza.tipo == TipoAppuntamento.proposta
                let collegata = bozza.posizioneId == pip
                let feriale = bozza.inizio > adesso && !cal.isDateInWeekend(bozza.inizio)
                controlla(presentazione && collegata && feriale,
                          "la bozza del seguito: presentazione collegata alla proposta, un giorno lavorativo")
                s.salvaAppuntamento(bozza)
                controlla(!s.proposteInSospeso.contains { $0.id == pip }, "fissato il seguito, la proposta esce dall'elenco")
            } else {
                controlla(false, "PIP ferma per la bozza del seguito")
            }
        }

        // 9. Una bozza segnata a mano come presentata
        do {
            let s = StatoShell(persistente: false)
            if var p = posizione(s, studiAnna) {
                p.esito = .presentata
                s.salvaPosizione(p)
                controlla(posizione(s, studiAnna)?.seguito?.presentataIl != nil, "presentata a mano: data della presentazione segnata")
            } else {
                controlla(false, "proposta di Marco")
            }
        }

        // 10. Le regole delle notifiche restano (lo specchio dei controlli di --prova-eve)
        do {
            let s = StatoShell(persistente: false)
            let mattina = cal.date(bySettingHour: 8, minute: 0, second: 0, of: adesso) ?? adesso
            if let d = s.documento("doc-giulia-estratto") {
                for c in d.campi { s.confermaCampo(d.id, c.chiave, true) }
            }
            s.dati.appuntamenti.removeAll { $0.clienteId == "laura" }
            s.dati.incontri.removeAll { $0.clienteId == "laura" }
            s.dati.impostazioni.backup.ultimoErrore = "Disco esterno non collegato"
            let n = MotoreNotifiche.calcola(s, oggi: mattina)
            controlla(zip(n, n.dropFirst()).allSatisfy { $0.gruppo.rawValue <= $1.gruppo.rawValue }, "notifiche ancora in ordine di gruppo")
            let primaDaFare = n.first { $0.gruppo == Notifica.Gruppo.daFare }
            controlla(primaDaFare?.id == "backup-errore", "il backup non riuscito resta in cima")
            controlla(n.contains { $0.id.hasPrefix("valore-") }, "resta la notifica del valore da registrare")
            controlla(n.contains { $0.id.hasPrefix("ricontattare-") && $0.titolo.contains("Laura Moretti") }, "resta Laura da ricontattare")
            controlla(n.contains { $0.id.hasPrefix("beneficiari-") && $0.id.contains("marco") }, "restano i beneficiari di Marco")
        }

        // 12. Dati di prova intatti: nessuna proposta ferma, nessuna notifica del seguito (garanzia per --prova-eve)
        do {
            let s = StatoShell(persistente: false)
            controlla(s.proposteInSospeso.isEmpty, "dati di prova: nessuna proposta ferma")
            controlla(!MotoreNotifiche.calcola(s).contains { $0.id.hasPrefix("seguito-") }, "dati di prova: nessuna notifica del seguito")
        }

        // 11. Le proposte ferme di 200 clienti: in cache alla seconda lettura
        do {
            let s = StatoShell(persistente: false)
            if let molti = try? ProvaCarico.moltiplica(DatiPrisma.demo(), copie: ProvaCarico.copie) {
                s.dati = molti
                let inizio = Date()
                let prima = s.proposteInSospeso.count
                let calcolo = Date().timeIntervalSince(inizio)
                let ripresa = Date()
                let seconda = s.proposteInSospeso.count
                let cache = Date().timeIntervalSince(ripresa)
                print("INFO Seguito: proposte ferme di \(molti.clienti.count) clienti in \(String(format: "%.3f", calcolo)) s, dalla cache in \(String(format: "%.4f", cache)) s")
                controlla(prima == seconda && cache < ProvaCarico.limiteCache,
                          "proposte ferme dalla cache in \(String(format: "%.4f", cache)) s (limite \(ProvaCarico.limiteCache) s)")
            } else {
                controlla(false, "archivio con \(ProvaCarico.copie) copie dei clienti di prova")
            }
        }
        return esiti
    }
}
