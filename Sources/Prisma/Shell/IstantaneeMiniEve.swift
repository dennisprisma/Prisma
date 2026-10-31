#if os(macOS)
import Foundation

/// Le istantanee della mini finestra di Eve: i cinque stati del template (Design/eve-mini.html), chiari e scuri,
/// sopra Posizioni di Giulia Rossi. Le cifre vengono dai calcoli di Prisma sui dati di prova.
extension Istantanee {
    nonisolated static let domandaMiniEve = "Cosa ha Giulia in scadenza nei prossimi mesi?"

    nonisolated static var sceneMiniEve: [(nome: String, prepara: (StatoShell) -> Void)] {
        let stati: [(String, (StatoShell) -> Void)] = [
            ("240-eve-mini-ascolta", { s in
                preparaMiniEve(s)
                s.voceIstantanea = StatoVoce(ascolta: true, trascritto: domandaMiniEve, livello: 0.55)
                s.apriMiniEve(.ascolta)
            }),
            ("241-eve-mini-pensa", { s in
                preparaMiniEve(s)
                s.apriMiniEve(.scrivi)
                s.miniEve.pensa(domandaMiniEve, passi: StatoMiniEve.passi(domanda: domandaMiniEve, fonte: s.fonteEve("giulia"), modalita: .lavoro))
            }),
            ("242-eve-mini-risposta", { s in
                preparaMiniEve(s)
                s.apriMiniEve(.scrivi)
                // Lo spunto delle scadenze: la risposta preparata è breve e sotto si vedono linea del tempo e righe
                s.inviaMiniEve(DomandaMiniEve(testo: domandaMiniEve, spunto: .scadenze))
                // Nell'app la risposta della mini finestra la scrive Qwen, breve (Eve/Istruzioni/mini.md); qui, senza
                // Qwen, una risposta breve come quella: le cifre sotto restano quelle calcolate da Prisma
                let m = s.miniEve
                let totale = m.cifre.linea?.totale ?? ""
                m.rispondi(testo: "Nei prossimi 12 mesi Giulia ha 2 posizioni in scadenza, per \(totale) in tutto: il conto deposito a gennaio e il piano di risparmio a marzo. È liquidità che può andare verso l'anticipo della casa: ne parlerei con lei prima di gennaio.",
                           titolo: nil, cifre: m.cifre, inArrivo: false)
            }),
            ("243-eve-mini-scrivi", { s in
                preparaMiniEve(s)
                s.apriMiniEve(.scrivi)
            }),
            ("244-eve-mini-nonpronta", { s in
                preparaMiniEve(s)
                // Qwen non c'è: niente risposte preparate, la domanda resta da parte
                s.rispostePreparate = false
                s.apriMiniEve(.scrivi)
                s.inviaMiniEve(DomandaMiniEve(testo: domandaMiniEve))
            }),
        ]
        return stati.flatMap { nome, prepara in [(nome: nome, prepara: prepara), (nome: nome + "-scuro", prepara: prepara)] }
    }

    /// Giulia in Posizioni, due scadenze nei prossimi mesi (una per canale) e due domande recenti.
    nonisolated static func preparaMiniEve(_ s: StatoShell) {
        let cal = Calendar.current
        let oggi = Date()
        func tra(_ mesi: Int, giorni: Int) -> Date? {
            cal.date(byAdding: .day, value: giorni, to: cal.date(byAdding: .month, value: mesi, to: oggi) ?? oggi)
        }
        for (id, mesi, giorni) in [("pos-giulia-conto-corrente-e-conto-deposito", 2, 12), ("pos-giulia-piano-di-risparmio-rivalutabile", 4, 3)] {
            if let i = s.dati.posizioni.firstIndex(where: { $0.id == id }) { s.dati.posizioni[i].scadenza = tra(mesi, giorni: giorni) }
        }
        s.rispostePreparate = true
        var ieri = MessaggioEve(autore: .utente, testo: "Differenza tra i due PIP di Marco Bianchi")
        ieri.data = cal.date(byAdding: .day, value: -1, to: oggi) ?? oggi
        var prima = MessaggioEve(autore: .utente, testo: "Cosa dice il KID del fondo Orizzonte?")
        prima.data = cal.date(byAdding: .day, value: -3, to: oggi) ?? oggi
        s.aggiungiMessaggio(prima, cliente: "giulia", parla: false)
        s.aggiungiMessaggio(ieri, cliente: "marco", parla: false)
        s.clienteAttivoId = "giulia"
        s.apri(.posizioni)
        // Lo schermo delle istantanee (900 punti): la scheda si allunga fin quasi in fondo, come sul Mac
        let m = Tema.Misura.MiniEve.self
        s.miniEve.altezzaMassima = Istantanee.altezzaSchermoMiniEve - Tema.Misura.barra - m.distanzaBarra - m.margineSchermo - m.margineOmbraSotto
    }

    nonisolated static let altezzaSchermoMiniEve: CGFloat = 900
}
#endif
