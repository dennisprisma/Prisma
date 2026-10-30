#if os(macOS)
import Foundation

/// Prova della mini finestra di Eve (dentro `Prisma --prova-eve`): il gesto di ⌥ Spazio, i cinque stati e i passaggi,
/// il contesto, le cifre di Prisma con il canale, la stessa conversazione dell'app Eve e «non pronta» senza risposte inventate.
enum ProvaMiniEve {
    static func esegui(_ controlla: (Bool, String) -> Void) {
        gesto(controlla)
        stati(controlla)
        flusso(controlla)
        nonPronta(controlla)
    }

    /// ⌥ Spazio: premuto e lasciato = scrivi; tenuto = parla, lasciato = risponde; le ripetizioni non contano.
    private static func gesto(_ controlla: (Bool, String) -> Void) {
        let t0 = Date()
        var g = GestoScorciatoia()
        _ = g.premi(t0)
        controlla(g.rilascia(t0.addingTimeInterval(0.12)) == .scrivi, "Mini Eve: ⌥ Spazio premuto una volta apre per scrivere")
        _ = g.premi(t0)
        controlla(g.tieni(t0.addingTimeInterval(0.1)) == .nessuno, "Mini Eve: prima della soglia non ascolta")
        controlla(g.premi(t0.addingTimeInterval(0.2)) == .nessuno, "Mini Eve: la ripetizione del tasto non conta")
        controlla(g.tieni(t0.addingTimeInterval(g.soglia + 0.01)) == .iniziaAParlare, "Mini Eve: ⌥ Spazio tenuto premuto = parla")
        controlla(g.tieni(t0.addingTimeInterval(g.soglia + 0.5)) == .nessuno, "Mini Eve: l'ascolto parte una volta sola")
        controlla(g.rilascia(t0.addingTimeInterval(2)) == .finisciDiParlare, "Mini Eve: rilasciato = Eve risponde")
        controlla(g.rilascia(t0.addingTimeInterval(3)) == .nessuno, "Mini Eve: un rilascio senza pressione non fa niente")
    }

    /// Le due forme della superficie e i passaggi tra gli stati.
    private static func stati(_ controlla: (Bool, String) -> Void) {
        let m = Tema.Misura.MiniEve.self
        controlla(m.larghezzaCapsula == 440 && m.altezzaCapsula == 72 && m.larghezzaScheda == 460, "Mini Eve: capsula 440 × 72, scheda 460")
        controlla(Tema.Moto.MiniEve.durataForma == 0.55, "Mini Eve: il cambio di forma dura 0,55 s")
        controlla(FaseMiniEve.allCases.filter(\.capsula) == [.ascolta, .pensa, .nonPronta], "Mini Eve: capsula mentre ascolta, pensa e si sveglia")
        let mini = StatoMiniEve()
        controlla(!mini.aperta, "Mini Eve: chiusa all'avvio")
        mini.apri(.scrivi, contesto: nil)
        controlla(mini.aperta && mini.visibile && mini.fase == .scrivi && mini.larghezza == m.larghezzaScheda, "Mini Eve: si apre per scrivere (scheda)")
        mini.vai(.ascolta)
        controlla(mini.fase == .ascolta && mini.larghezza == m.larghezzaCapsula, "Mini Eve: ascolta (capsula)")
        mini.pensa("Domanda", passi: ["Uno…", "Due…"])
        controlla(mini.fase == .pensa && mini.passo == "Uno…" && mini.domanda == "Domanda", "Mini Eve: pensa con il primo passo e la domanda")
        mini.rispondi(testo: "Ecco", titolo: nil, cifre: CifreMiniEve(), inArrivo: true)
        controlla(mini.fase == .risponde && mini.inArrivo && mini.larghezza == m.larghezzaScheda, "Mini Eve: la risposta che arriva apre la scheda")
        mini.rispondi(testo: "Ecco tutto", titolo: nil, cifre: CifreMiniEve(), inArrivo: false)
        controlla(mini.risposta == "Ecco tutto" && !mini.inArrivo, "Mini Eve: la risposta finita resta nella scheda")
        mini.nonPronta(motivo: nil)
        controlla(mini.fase == .nonPronta && mini.fase.capsula, "Mini Eve: non pronta (capsula)")
        mini.chiudi()
        controlla(!mini.visibile && mini.aperta, "Mini Eve: Esc comincia l'uscita")
        mini.riposa()
        controlla(!mini.aperta && mini.fase == .scrivi && mini.risposta.isEmpty, "Mini Eve: a riposo dopo l'uscita")
    }

    /// Dalla domanda alla risposta, sui dati di prova: contesto, cifre, canali, fonte, pulsanti e conversazione.
    private static func flusso(_ controlla: (Bool, String) -> Void) {
        let s = StatoShell(persistente: false)
        Istantanee.preparaMiniEve(s)
        let contesto = s.contestoMiniEve()
        controlla(contesto?.nome == "Giulia Rossi" && contesto?.app == "Posizioni", "Mini Eve: il contesto è il cliente e l'app aperti")
        let f = s.fonteEve("giulia")
        let passi = StatoMiniEve.passi(domanda: Istantanee.domandaMiniEve, fonte: f, modalita: .lavoro)
        controlla(passi.first == "Apro il dossier di Giulia…" && passi.contains { $0.contains("Alleanza e indipendenti") },
                  "Mini Eve: i passi di «pensa» vengono dai dati del cliente")

        s.apriMiniEve(.scrivi)
        let prima = s.conversazione("giulia").count
        s.inviaMiniEve(DomandaMiniEve(testo: Istantanee.domandaMiniEve))
        let mini = s.miniEve
        controlla(mini.fase == .risponde && !mini.risposta.isEmpty, "Mini Eve: la domanda arriva alla risposta")
        controlla(s.conversazione("giulia").count == prima + 2 && mini.chiave == "giulia",
                  "Mini Eve: domanda e risposta nella stessa conversazione dell'app Eve")
        let attese = (f?.posizioni ?? []).filter { p in
            ["pos-giulia-conto-corrente-e-conto-deposito", "pos-giulia-piano-di-risparmio-rivalutabile"].contains(p.id)
        }
        let righe = mini.cifre.righe
        controlla(righe.count >= 2 && Set(righe.map(\.canale)) == [.alleanza, .indipendente], "Mini Eve: le scadenze con il loro canale")
        controlla(attese.allSatisfy { p in righe.contains { $0.id == p.id && $0.valore == Formati.euro(p.valore) } },
                  "Mini Eve: le cifre sono quelle calcolate da Prisma")
        controlla(mini.cifre.linea?.punti.count == righe.count && mini.cifre.linea?.oltre?.contains("→") == true,
                  "Mini Eve: la linea del tempo con le scadenze e l'obiettivo oltre l'orizzonte")
        controlla(mini.cifre.fonte?.hasPrefix("Cifre dai calcoli di Posizioni") == true, "Mini Eve: la riga della fonte")
        controlla(mini.cifre.azioni.first?.primaria == true && mini.cifre.azioni.first?.tipo == .posizioni, "Mini Eve: il primo pulsante porta in Posizioni")
        controlla(!mini.cifre.seguiti.isEmpty, "Mini Eve: gli spunti per continuare")

        // Un pulsante porta nell'app e chiude la mini finestra
        s.apri(.agenda)
        if let a = mini.cifre.azioni.first { s.eseguiMiniEve(a) }
        controlla(s.appAttiva == .posizioni && !mini.visibile && !mini.aperta, "Mini Eve: «Apri in Posizioni» apre l'app e chiude Eve")

        // La freccia: la stessa conversazione nell'app Eve completa
        s.apriMiniEve(.scrivi)
        s.inviaMiniEve(DomandaMiniEve(testo: "Fammi un riepilogo del cliente", spunto: .riepilogo))
        s.apriInEveDaMiniEve()
        controlla(s.appAttiva == .eve && !s.evePortafoglio && s.clienteAttivoId == "giulia" && !mini.aperta,
                  "Mini Eve: la freccia apre la conversazione nell'app Eve")

        // Senza gettone Eve parla del portafoglio
        s.apriMiniEve(.scrivi)
        s.togliContestoMiniEve()
        controlla(mini.contesto == nil, "Mini Eve: il gettone del contesto si toglie")
        s.inviaMiniEve(DomandaMiniEve(testo: SpuntoPortafoglio.ricontattare.domanda, portafoglio: .ricontattare))
        controlla(mini.chiave == EvePortafoglio.chiave && mini.fase == .risponde && mini.cifre.righe.isEmpty,
                  "Mini Eve: senza contesto la domanda va al portafoglio, senza cifre di un cliente")
        s.chiudiMiniEve()

        // In conversazione niente cifre
        let generale = CifreMiniEve.calcola(domanda: "Cos'è l'inflazione?", fonte: f, modalita: .conversazione, app: "Posizioni")
        controlla(generale.righe.isEmpty && generale.fonte == nil && generale.azioni.isEmpty, "Mini Eve: in conversazione niente cifre né fonte")

        // In modalità cliente il gettone resta (mai i dati di altri clienti)
        s.entraModoCliente()
        s.apriMiniEve(.scrivi)
        s.togliContestoMiniEve()
        controlla(mini.contesto != nil && s.recentiMiniEve().isEmpty, "Mini Eve: in modalità cliente il contesto non si toglie e niente recenti")
        s.chiudiMiniEve()
    }

    /// Qwen non è pronto: «Mi sto svegliando…», la domanda resta da parte, nessuna risposta inventata.
    private static func nonPronta(_ controlla: (Bool, String) -> Void) {
        let s = StatoShell(persistente: false)
        Istantanee.preparaMiniEve(s)
        s.rispostePreparate = false
        s.apriMiniEve(.scrivi)
        let prima = s.conversazione("giulia").count
        s.inviaMiniEve(DomandaMiniEve(testo: Istantanee.domandaMiniEve))
        let mini = s.miniEve
        controlla(mini.fase == .nonPronta && mini.pendente?.testo == Istantanee.domandaMiniEve, "Mini Eve: Qwen non pronto → «Mi sto svegliando…»")
        controlla(s.conversazione("giulia").count == prima && mini.risposta.isEmpty, "Mini Eve: non pronta, nessuna risposta inventata")
        s.riprovaMiniEve()
        controlla(mini.fase == .nonPronta, "Mini Eve: Riprova con Qwen ancora spento resta in attesa")
        // Qwen pronto (qui: le risposte preparate): Riprova manda la domanda rimasta da parte
        s.rispostePreparate = true
        s.riprovaMiniEve()
        controlla(mini.fase == .risponde && mini.pendente == nil && s.conversazione("giulia").count == prima + 2,
                  "Mini Eve: Riprova manda la domanda quando Qwen è pronto")
    }
}
#endif
