import Foundation

/// Controlli dei riesami in Agenda che hanno bisogno di `StatoShell` (dentro `Prisma --prova-carico`): la striscia
/// «Riesami del mese», «Pianifica» con lo spazio libero, il canale e l'ordine del giorno, la bozza di Portafoglio e
/// Prospetti, gli orari personalizzati, la modalità cliente e i mesi passati (S1–S11). Tutto relativo a `Date()`:
/// riproducibile a qualunque ora del server. Ogni gruppo di controlli usa uno stato nuovo, preparato con `prepara`.
@MainActor
enum ProvaRiesamiAgenda {
    /// Prepara i dati di prova: Marco (Alleanza) visto 12 mesi e 20 giorni fa, Laura (indipendente) 13 mesi fa,
    /// Sofia (tutti e due i canali) mai incontrata; nessuno dei tre ha appuntamenti futuri. Lo usano anche le istantanee.
    nonisolated static func prepara(_ s: StatoShell, oggi: Date = Date()) {
        let cal = Calendar.current
        let inizio = cal.startOfDay(for: oggi)
        let tre: Set<String> = ["marco", "laura", "sofia"]
        func passato(mesi: Int, giorni: Int) -> Date {
            let m = cal.date(byAdding: .month, value: -mesi, to: inizio) ?? inizio
            let g = cal.date(byAdding: .day, value: -giorni, to: m) ?? m
            return cal.date(bySettingHour: 10, minute: 0, second: 0, of: g) ?? g
        }
        var d = s.dati
        d.appuntamenti.removeAll { tre.contains($0.clienteId) }
        d.incontri.removeAll { tre.contains($0.clienteId) }
        d.appuntamenti.append(Appuntamento(id: "riesame-prova-marco", clienteId: "marco", titolo: "Revisione delle posizioni",
                                           inizio: passato(mesi: 12, giorni: 20), durataMinuti: 60, luogo: "In studio",
                                           note: "", stato: .concluso, tipo: .revisione, canale: .alleanza))
        d.appuntamenti.append(Appuntamento(id: "riesame-prova-laura", clienteId: "laura", titolo: "Revisione delle posizioni",
                                           inizio: passato(mesi: 13, giorni: 0), durataMinuti: 60, luogo: "In studio",
                                           note: "", stato: .concluso, tipo: .revisione, canale: .indipendente))
        s.dati = d
        s.giornoAgenda = inizio
        s.vistaAgenda = .settimana
        s.filtroClienteAgenda = nil
    }

    static func verifiche() -> [(Bool, String)] {
        var esiti: [(Bool, String)] = []
        func controlla(_ ok: Bool, _ descrizione: String) {
            esiti.append((ok, "Riesami in Agenda: " + descrizione))
        }
        let cal = MotorePianificazione.calendario
        let adesso = Date()
        let domani = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: adesso)) ?? adesso
        func nuovo() -> StatoShell {
            let s = StatoShell(persistente: false)
            prepara(s, oggi: adesso)
            return s
        }
        /// Le revisioni periodiche già in agenda nel giorno.
        func revisioni(_ s: StatoShell, giorno: Date) -> Int {
            s.dati.appuntamenti.filter { (a: Appuntamento) -> Bool in
                a.tipo == TipoAppuntamento.revisione && cal.isDate(a.inizio, inSameDayAs: giorno)
            }.count
        }

        // S1 Chi è da fissare nel mese, nell'ordine giusto
        do {
            let s = nuovo()
            let ids = s.riesamiDelMese(adesso).daFissare.map(\.id)
            controlla(ids == ["sofia", "laura", "marco"],
                      "S1 da fissare nel mese: prima chi non è mai stato incontrato, poi chi aspetta da più tempo (\(ids.joined(separator: ", ")))")
        }

        // S2 Laura: un'ora di riesame indipendente nel primo spazio libero
        do {
            let s = nuovo()
            if let p = s.pianificaRiesame("laura", oggi: adesso) {
                let a = p.appuntamento
                // Condizioni separate: il controllo dei tipi resta leggero
                let titoloOk = a.titolo == "Riesame annuale"
                let revisione = a.tipo == TipoAppuntamento.revisione
                controlla(titoloOk && revisione && a.durataMinuti == 60, "S2 Laura: «Riesame annuale», revisione periodica di 60 minuti")
                controlla(a.canale == .indipendente, "S2 Laura: canale indipendente")
                controlla(a.note.hasPrefix("Ordine del giorno:"), "S2 Laura: l'ordine del giorno nelle note")
                controlla(p.spazio != nil && a.inizio >= domani, "S2 Laura: spazio libero trovato, da domani")
                controlla(MotorePianificazione.sovrapposti(a, in: s.dati.appuntamenti, margine: 15).isEmpty,
                          "S2 Laura: nessuna sovrapposizione con margine 15")
                controlla(!MotorePianificazione.fuoriOrario(a, orari: s.dati.impostazioni.orari), "S2 Laura: dentro gli orari di lavoro")
            } else {
                controlla(false, "S2 Laura: nessuna bozza del riesame")
            }
        }

        // S3 Marco: canale Alleanza e la polizza in scadenza di cui parlare
        do {
            let s = nuovo()
            if let a = s.pianificaRiesame("marco", oggi: adesso)?.appuntamento {
                controlla(a.canale == .alleanza, "S3 Marco: canale Alleanza")
                controlla(a.posizioneId == "pos-marco-infortuni-famiglia",
                          "S3 Marco: si parla di «Infortuni famiglia», che scade tra 45 giorni (\(a.posizioneId ?? "nessuna"))")
                controlla(a.note.contains("Canale: Alleanza Assicurazioni."), "S3 Marco: canale nelle note")
            } else {
                controlla(false, "S3 Marco: nessuna bozza del riesame")
            }
        }

        // S4 Sofia: tutti e due i canali, mai incontrata
        do {
            let s = nuovo()
            if let a = s.pianificaRiesame("sofia", oggi: adesso)?.appuntamento {
                controlla(a.canale == nil, "S4 Sofia: canale entrambi (nessuno indicato)")
                controlla(a.note.contains("Canale: Alleanza e indipendente"), "S4 Sofia: tutti e due i canali nelle note")
                controlla(a.note.contains("Nessun incontro registrato in Prisma"), "S4 Sofia: primo riesame nelle note")
            } else {
                controlla(false, "S4 Sofia: nessuna bozza del riesame")
            }
        }

        // S5 Dopo il salvataggio Laura esce dalla striscia (ed entra tra i fissati, se nel mese)
        do {
            let s = nuovo()
            if let a = s.pianificaRiesame("laura", oggi: adesso)?.appuntamento {
                s.salvaAppuntamento(a)
                let r = s.riesamiDelMese(adesso)
                controlla(!r.daFissare.contains { $0.id == "laura" }, "S5 Laura fissata: non è più da fissare")
                if cal.isDate(a.inizio, equalTo: adesso, toGranularity: .month) {
                    controlla(r.fissati.contains { $0.id == a.id }, "S5 Laura fissata nel mese: tra le revisioni in agenda")
                }
            } else {
                controlla(false, "S5 Laura: nessuna bozza del riesame")
            }
        }

        // S6 In sequenza: lo spazio di Marco non si sovrappone a quello di Laura
        do {
            let s = nuovo()
            if let laura = s.pianificaRiesame("laura", oggi: adesso)?.appuntamento {
                s.salvaAppuntamento(laura)
                if let marco = s.pianificaRiesame("marco", oggi: adesso)?.appuntamento {
                    controlla(MotorePianificazione.sovrapposti(marco, in: [laura], margine: 15).isEmpty,
                              "S6 Marco dopo Laura: nessuna sovrapposizione con margine 15")
                } else {
                    controlla(false, "S6 Marco: nessuna bozza del riesame")
                }
            } else {
                controlla(false, "S6 Laura: nessuna bozza del riesame")
            }
        }

        // S7 Limite giornaliero: dopo Laura e Marco, Sofia va in un giorno con meno di due riesami
        do {
            let s = nuovo()
            for id in ["laura", "marco"] {
                if let a = s.pianificaRiesame(id, oggi: adesso)?.appuntamento { s.salvaAppuntamento(a) }
            }
            if let p = s.pianificaRiesame("sofia", oggi: adesso), p.spazio != nil {
                let gia = revisioni(s, giorno: p.appuntamento.inizio)
                controlla(gia < s.dati.impostazioni.orari.riesamiAlGiorno,
                          "S7 Sofia: nel suo giorno \(gia) riesami già in agenda (limite \(s.dati.impostazioni.orari.riesamiAlGiorno))")
            } else {
                controlla(false, "S7 Sofia: nessuno spazio per il riesame")
            }
        }

        // S8 La bozza di Portafoglio e Prospetti: gli stessi controlli di --prova-eve
        do {
            let s = nuovo()
            if let a = s.bozzaRiesame("giulia") {
                let revisione = a.tipo == TipoAppuntamento.revisione
                controlla(revisione && a.durataMinuti == 60, "S8 Giulia: revisione periodica di 60 minuti")
                controlla(a.note.hasPrefix("Ordine del giorno"), "S8 Giulia: l'ordine del giorno nelle note")
                controlla(!cal.isDateInWeekend(a.inizio) && a.inizio > Date(), "S8 Giulia: in un giorno feriale, nel futuro")
            } else {
                controlla(false, "S8 Giulia: nessuna bozza del riesame")
            }
        }

        // S9 Orari personalizzati: solo il mercoledì
        do {
            let s = nuovo()
            s.dati.impostazioni.orari.giorni = [4]
            if let p = s.pianificaRiesame("laura", oggi: adesso), p.spazio != nil {
                controlla(cal.component(.weekday, from: p.appuntamento.inizio) == 4, "S9 Solo il mercoledì: il riesame di Laura cade di mercoledì")
            } else {
                controlla(false, "S9 Solo il mercoledì: nessuno spazio per il riesame di Laura")
            }
        }

        // S10 Modalità cliente: la striscia è uno strumento del consulente
        do {
            let s = nuovo()
            s.modoCliente = "laura"
            controlla(s.riesamiDelMese(adesso).vuota, "S10 In modalità cliente la striscia non compare")
        }

        // S11 Un mese passato non ha riesami da fissare
        do {
            let s = nuovo()
            let scorso = cal.date(byAdding: .month, value: -1, to: adesso) ?? adesso
            controlla(s.riesamiDelMese(scorso, oggi: adesso).daFissare.isEmpty, "S11 Mese scorso: nessun riesame da fissare")
        }

        return esiti
    }
}
