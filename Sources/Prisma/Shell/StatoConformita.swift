import Foundation

// Scadenze di conformità («In regola», specifica 3): il calcolo tenuto da parte in DerivatiDati (la voce
// `conformita` sta in DerivatiDati.swift), le scritture sulla scheda del cliente e l'apertura della scheda.

extension StatoShell {
    /// L'esito di conformità di un cliente visibile, calcolato una volta per dati dei calcoli e giorno.
    /// Le regole di Impostazioni entrano nei dati dei calcoli: cambiandole, la cache si rifà da sola.
    func conformitaCliente(_ id: String) -> EsitoConformita? {
        let d = derivatiValidi()
        if let e = d.conformita[id] { return e }
        guard let c = cliente(id) else { return nil }
        let e = MotoreConformita.calcola(cliente: c, posizioni: posizioniCliente(id), regole: dati.impostazioni.conformita)
        d.conformita[id] = e
        return e
    }

    /// Scrive con una funzione su `dati.clienti[i]` (come `alternaPreferito`): salvataggio e versione dei calcoli
    /// seguono la strada di sempre. Una conformità che resta vuota torna nil; senza cambiamenti non si scrive niente.
    func aggiornaConformita(_ clienteId: String, _ modifica: (inout ConformitaCliente, inout Consensi) -> Void) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == clienteId }) else { return }
        var cliente = dati.clienti[i]
        var conformita = cliente.conformita ?? ConformitaCliente()
        var consensi = cliente.consensi
        modifica(&conformita, &consensi)
        cliente.conformita = MotoreConformita.normalizzata(conformita)
        cliente.consensi = consensi
        guard cliente != dati.clienti[i] else { return }
        dati.clienti[i] = cliente
    }

    /// Mette la data di oggi (inizio del giorno, minuti interi) alla voce, lasciando il resto: validità, rischio
    /// ed esito restano come sono. Il documento non cambia (serve la nuova scadenza: si usa il modulo).
    func rinnovaOggi(_ clienteId: String, _ tipo: VoceConformita.Tipo) {
        let oggi = Appuntamento.alMinuto(Calendar.current.startOfDay(for: Date()))
        aggiornaConformita(clienteId) { conformita, consensi in
            switch tipo {
            case .questionarioAlleanza, .questionarioIndipendente:
                guard let canale = tipo.canale else { return }
                var q = conformita.questionario(canale) ?? QuestionarioAdeguatezza()
                q.compilatoIl = oggi
                conformita.impostaQuestionario(q, canale: canale)
            case .verificaAlleanza, .verificaIndipendente:
                guard let canale = tipo.canale else { return }
                // Il record nasce se mancava (rischio non indicato: periodicità del rischio medio)
                var v = conformita.verifica(canale) ?? AdeguataVerifica()
                v.eseguitaIl = oggi
                conformita.impostaVerifica(v, canale: canale)
            case .commerciale:
                consensi.dataMarketing = oggi
            case .privacy:
                consensi.privacy = true
                consensi.dataPrivacy = oggi
            case .documento:
                break
            }
        }
    }

    /// Apre Clienti sulla scheda «In regola» del cliente.
    func apriInRegola(_ clienteId: String) {
        clienteAttivoId = clienteId
        schedaCliente = .inRegola
        apri(.clienti)
    }
}
