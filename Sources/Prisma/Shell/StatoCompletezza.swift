import Foundation

// Completezza dei dati per l'analisi (specifica 7): richieste di apertura dei moduli sul campo, dati segnati
// «non pertinenti» e il calcolo tenuto da parte in DerivatiDati. Le proprietà pubblicate
// `richiestaCompletamento` e `fuocoAnalisi` stanno in StatoShell.swift; `completezze` in DerivatiDati.swift.

/// Chiede a Clienti o Posizioni di aprire il modulo su un campo (si consuma appena letta).
struct RichiestaCompletamento: Identifiable, Equatable {
    let id = UUID()
    let clienteId: String
    let destinazione: DestinazioneCompletezza
}

/// Il campo dell'Analisi 360 da evidenziare (si toglie lasciando quell'area).
struct FuocoAnalisi: Equatable {
    let area: AreaAnalisi
    /// L'etichetta del campo (`CampoIpotesi`), identica a quella di AppAnalisi360.
    let campo: String

    /// L'id della riga evidenziata, per portarla in vista.
    static let idCampo = "fuoco-analisi"
}

extension StatoShell {
    /// La completezza dei dati di un cliente (Panoramica, Analisi 360, documenti): si rifà solo se cambiano i dati
    /// dei calcoli, il giorno o la modalità cliente. La chiave versioneCalcoli copre clienti, posizioni e Analisi 360.
    func completezzaCliente(_ id: String) -> CompletezzaCliente? {
        let d = derivatiValidi()
        if let c = d.completezze[id] { return c }
        guard let cl = cliente(id) else { return nil }
        let c = MotoreCompletezza.calcola(cliente: cl, posizioni: posizioniCliente(id), analisi: dati.analisi[id],
                                          oggi: Calendar.current.startOfDay(for: Date()))
        d.completezze[id] = c
        return c
    }

    /// Apre il posto giusto per completare una voce: il modulo del cliente o del familiare sul campo, l'area
    /// dell'Analisi 360 con il campo evidenziato, il modulo della posizione o il suo dettaglio.
    func apriCompletamento(_ v: VoceCompletezza, cliente id: String) {
        switch v.destinazione {
        case .cliente, .familiare:
            clienteAttivoId = id
            richiestaCompletamento = RichiestaCompletamento(clienteId: id, destinazione: v.destinazione)
            apri(.clienti)
        case .analisi360(let area, let campo):
            clienteAttivoId = id
            // Prima il fuoco, poi l'area: cambiando area si toglie il fuoco di un'altra
            fuocoAnalisi = FuocoAnalisi(area: area, campo: campo)
            areaAnalisi = area
            apri(.analisi360)
        case .posizione:
            portafoglio = false
            clienteAttivoId = id
            richiestaCompletamento = RichiestaCompletamento(clienteId: id, destinazione: v.destinazione)
            apri(.posizioni)
        case .dettaglioPosizione(let pid, let ancora):
            guard let p = posizioniCliente(id).first(where: { $0.id == pid }) else { return }
            apriPosizione(p)
            // Dopo l'apertura del dettaglio (anche apriPosizione aspetta un giro)
            DispatchQueue.main.async { self.ancoraPosizioni = ancora }
        }
    }

    /// Segna una voce come «non pertinente» per il cliente: esce dal punteggio (data al minuto, come l'archivio).
    func segnaDatoNonPertinente(_ voce: String, cliente id: String) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == id }) else { return }
        var segnate = dati.clienti[i].datiNonPertinenti ?? [:]
        segnate[voce] = Appuntamento.alMinuto(Date())
        dati.clienti[i].datiNonPertinenti = segnate
    }

    /// Tutte le voci segnate «non pertinenti» del cliente tornano a contare.
    func ripristinaDatiNonPertinenti(_ id: String) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == id }), dati.clienti[i].datiNonPertinenti != nil else { return }
        dati.clienti[i].datiNonPertinenti = nil
    }
}
