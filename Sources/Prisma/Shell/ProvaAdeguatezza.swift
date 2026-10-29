import Foundation
import PDFKit

/// Prove della scheda di adeguatezza che hanno bisogno di `StatoShell` (giro 4, specifica 1, §9.3–9.4): la
/// scheda di Sofia e quella di Andrea, il PDF, consegne e firma, il centro notifiche, le eliminazioni,
/// l'elenco dei documenti e i tempi (V1–V9). `verifiche()` la chiama `ProvaCarico.esegui()` (con il prefisso
/// «Adeguatezza: »); `provaProspetti` la chiama `ProvaProspetti.esegui`. Ogni gruppo usa uno stato nuovo.
@MainActor
enum ProvaAdeguatezza {
    nonisolated static let sofia = "pos-sofia-obbligazionario-a-scadenza-2030"
    nonisolated static let polizzaSofia = "pos-sofia-polizza-rivalutabile"
    nonisolated static let andrea = "pos-andrea-piano-di-risparmio-rivalutabile"
    /// Le voci consegnate ieri nella scheda di Sofia.
    nonisolated static let consegnateSofia = ["ind-informativa", "ind-contratto", "ind-profilo", "ind-kid"]
    /// Tempo massimo del centro notifiche con 200 schede incomplete.
    static let limiteNotifiche = 0.5

    /// Dati per le prove e le istantanee: Sofia con l'area pensione importante e la scheda della proposta
    /// obbligazionaria (sostituisce la polizza in scadenza, quattro documenti consegnati ieri, motivazione).
    /// Andrea resta senza scheda. Non tocca altro (nessun `Date()` nelle regole, solo per «ieri»).
    nonisolated static func prepara(_ s: StatoShell) {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: Date())
        let ieri = cal.date(byAdding: .day, value: -1, to: oggi) ?? oggi
        let alle10 = Appuntamento.alMinuto(cal.date(bySettingHour: 10, minute: 0, second: 0, of: ieri) ?? ieri)
        if let i = s.dati.clienti.firstIndex(where: { $0.id == "sofia" }) {
            s.dati.clienti[i].bisogni.imposta(ValutazioneBisogno(area: .pensione, importanza: .alta, orizzonte: .medio))
        }
        var scheda = SchedaAdeguatezza(posizioneId: sofia, clienteId: "sofia", creataIl: alle10)
        scheda.areaBisogno = .pensione
        scheda.posizioneSostituitaId = polizzaSofia
        scheda.fonte = .sostituzione
        scheda.motivazione = "Reinvestimento della polizza in scadenza in un fondo obbligazionario a scadenza 2030: rischio basso, durata di quattro anni dentro l'orizzonte indicato, costi correnti dello 0,6%. La liquidità per gli imprevisti resta com'è."
        scheda.consegne = consegnateSofia.map { ConsegnaDocumento(voceId: $0, consegnatoIl: alle10) }
        scheda.aggiornataIl = alle10
        s.dati.schedeAdeguatezza = [scheda]
    }

    private static func posizione(_ s: StatoShell, _ id: String) -> Posizione? {
        s.dati.posizioni.first { $0.id == id }
    }

    private static func notificheAdeguatezza(_ s: StatoShell) -> [Notifica] {
        MotoreNotifiche.calcola(s).filter { $0.id.hasPrefix("adeguatezza-") }
    }

    static func verifiche() -> [(Bool, String)] {
        var esiti: [(Bool, String)] = []
        func controlla(_ ok: Bool, _ descrizione: String) {
            esiti.append((ok, descrizione))
        }

        // V1 · Sofia preparata: sostituzione gialla, tutto il resto coerente, 4 documenti su 7
        do {
            let s = StatoShell(persistente: false)
            prepara(s)
            if let p = posizione(s, sofia), let e = s.esitoAdeguatezza(p) {
                controlla(e.complessivo == .giallo, "Sofia: complessivo da motivare (\(e.complessivo.rawValue))")
                controlla(e.controlli.map(\.tipo) == ControlloAdeguatezza.Tipo.allCases, "Sofia: sette controlli nell'ordine")
                let verdi: [ControlloAdeguatezza.Tipo] = [.rischio, .orizzonte, .esperienza, .bisogno, .liquidita, .concentrazione]
                let nonVerdi = verdi.filter { e.controllo($0)?.semaforo != .verde }.map(\.rawValue)
                controlla(nonVerdi.isEmpty, "Sofia: rischio, orizzonte, esperienza, bisogno, liquidità e concentrazione coerenti\(nonVerdi.isEmpty ? "" : " (non verdi: \(nonVerdi.joined(separator: ", ")))")")
                let s7 = e.controllo(.sostituzione)
                controlla(s7?.semaforo == .giallo, "Sofia: sostituzione della polizza da motivare (\(s7?.semaforo.rawValue ?? "assente"))")
                controlla(s7?.dettagli.contains { $0.contains("scade il") } == true, "Sofia: la polizza scade presto, valuta se attendere")
                controlla(s7?.dettagli.contains { $0.contains("Cambio di canale") } == true, "Sofia: cambio di canale da Alleanza a indipendente")
                controlla(e.consegnati == 4 && e.daConsegnare == 7, "Sofia: 4 documenti consegnati su 7 (\(e.consegnati) su \(e.daConsegnare))")
            } else {
                controlla(false, "Sofia: scheda calcolata")
            }
        }

        // V2 · Andrea, senza scheda: Ramo I che non conosce
        do {
            let s = StatoShell(persistente: false)
            if let p = posizione(s, andrea), let e = s.esitoAdeguatezza(p) {
                controlla(e.complessivo == .rosso, "Andrea: complessivo da rivedere (\(e.complessivo.rawValue))")
                controlla(e.controllo(.esperienza)?.semaforo == .rosso, "Andrea: esperienza da rivedere (non conosce il Ramo I)")
                controlla(e.controllo(.rischio)?.semaforo == .giallo && e.controllo(.rischio)?.stimato == true, "Andrea: SRI stimato")
                controlla(e.controllo(.orizzonte)?.semaforo == .grigio, "Andrea: orizzonte da completare")
                controlla(e.controllo(.bisogno)?.semaforo == .grigio, "Andrea: bisogno da completare")
                controlla(e.controllo(.liquidita)?.semaforo == .giallo, "Andrea: 12.000 € contro la riserva di 21.600 €, da motivare")
                controlla(e.documenti.count == 9, "Andrea: 9 documenti Alleanza per il Ramo I (\(e.documenti.count))")
            } else {
                controlla(false, "Andrea: scheda calcolata")
            }
        }

        // V3 · Il documento della scheda di Sofia
        do {
            let s = StatoShell(persistente: false)
            prepara(s)
            if let p = posizione(s, sofia), let d = s.documentoAdeguatezza(p) {
                controlla(d.genere == TestiAdeguatezza.genere && d.pagine.count == 2, "PDF di Sofia: «Scheda di adeguatezza», due pagine")
                controlla(StampaCarta.nomeFile(d).hasPrefix("Scheda di adeguatezza · Sofia Romano · Obbligazionario a scadenza 2030"),
                          "PDF di Sofia: nome del file")
            } else {
                controlla(false, "PDF di Sofia: documento creato")
            }
        }

        // V4 · Consegne e firma
        do {
            let s = StatoShell(persistente: false)
            prepara(s)
            if let p = posizione(s, sofia) {
                s.segnaConsegna(p, voce: "ind-costi", consegnato: true)
                controlla(s.esitoAdeguatezza(p)?.consegnati == 5, "Consegna: 5 documenti consegnati")
                s.firmaScheda(p)
                let firmata = s.schedaAdeguatezza(p.id)
                controlla(firmata?.firmataIl != nil && firmata?.esitiAllaFirma?.count == 7, "Firma: data e sette colori registrati")
                s.modificaScheda(p) { $0.motivazione = "x" }
                controlla(s.schedaAdeguatezza(p.id)?.motivazione != "x", "Firma: la scheda firmata non si modifica")
                s.togliFirmaScheda(p)
                let tolta = s.schedaAdeguatezza(p.id)
                controlla(tolta?.firmataIl == nil && tolta?.esitiAllaFirma == nil, "Firma tolta: data e colori cancellati")
            } else {
                controlla(false, "Consegne e firma: proposta di Sofia")
            }
        }

        // V5 · Centro notifiche: niente con i soli dati di prova, poi documenti, poi firma, poi niente
        do {
            let pulito = StatoShell(persistente: false)
            controlla(notificheAdeguatezza(pulito).isEmpty, "Notifiche: nessuna scheda da completare nei dati di prova")
            let s = StatoShell(persistente: false)
            prepara(s)
            let prima = notificheAdeguatezza(s)
            let n = prima.first
            controlla(prima.count == 1 && n?.gruppo == .daSistemare, "Notifiche: una voce da sistemare (\(prima.count))")
            controlla(n?.dettaglio.contains("3 documenti da consegnare") == true, "Notifiche: 3 documenti da consegnare")
            controlla(n?.canale == .indipendente && n?.destinazione == .posizione(sofia), "Notifiche: canale indipendente, apre la proposta")
            s.attivaProposta(sofia)
            let accettata = notificheAdeguatezza(s).first
            controlla(accettata?.dettaglio.contains("segna la firma") == true, "Notifiche: proposta accettata, segna la firma")
            if let p = posizione(s, sofia) { s.firmaScheda(p) }
            controlla(notificheAdeguatezza(s).isEmpty, "Notifiche: firmata, la voce sparisce")
        }

        // V6 · Eliminazioni
        do {
            let s = StatoShell(persistente: false)
            prepara(s)
            s.eliminaPosizione(sofia)
            controlla(s.dati.schedeAdeguatezza.isEmpty, "Eliminare la proposta toglie la scheda")
            let c = StatoShell(persistente: false)
            prepara(c)
            c.eliminaCliente("sofia")
            controlla(c.dati.schedeAdeguatezza.isEmpty, "Eliminare il cliente toglie le sue schede")
        }

        // V7 · Elenco dei documenti
        do {
            let s = StatoShell(persistente: false)
            controlla(s.dati.impostazioni.consegna.voci.count == 23, "Elenco dei documenti: 23 voci di Prisma")
            if let i = s.dati.impostazioni.consegna.voci.firstIndex(where: { $0.id == "all-antiriciclaggio" }) {
                s.dati.impostazioni.consegna.voci[i].attiva = false
            }
            let spento = posizione(s, andrea).flatMap { s.esitoAdeguatezza($0) }?.documenti.count
            controlla(spento == 8, "Antiriciclaggio spento: 8 documenti per Andrea (\(spento ?? -1))")
            s.ripristinaDocumentiConsegna()
            let ripristinato = posizione(s, andrea).flatMap { s.esitoAdeguatezza($0) }?.documenti.count
            controlla(s.dati.impostazioni.consegna.voci.count == 23 && ripristinato == 9,
                      "Elenco di Prisma ripristinato: 23 voci, 9 documenti per Andrea")
        }

        // V8 · Ordine e regole delle notifiche invariati
        do {
            let s = StatoShell(persistente: false)
            prepara(s)
            let elenco = MotoreNotifiche.calcola(s)
            let gruppi = elenco.map(\.gruppo.rawValue)
            controlla(gruppi == gruppi.sorted(), "Notifiche: gruppi nell'ordine")
            s.dati.impostazioni.backup.ultimoErrore = "Disco di backup non trovato"
            controlla(MotoreNotifiche.calcola(s).first?.id == "backup-errore", "Notifiche: il backup non riuscito resta il primo")
        }

        // V9 · Tempi con 200 clienti
        do {
            let s = StatoShell(persistente: false)
            if let dati = try? ProvaCarico.moltiplica(DatiPrisma.demo(), copie: ProvaCarico.copie) {
                s.dati = dati
                let proposte = s.dati.posizioni.filter { MotoreAdeguatezza.pertinente($0, scheda: nil) }
                var calcolate = 0
                let inizio = Date()
                for p in proposte where s.esitoAdeguatezza(p) != nil { calcolate += 1 }
                let durata = Date().timeIntervalSince(inizio)
                print("INFO Adeguatezza: \(calcolate) schede di \(s.dati.clienti.count) clienti in \(Int((durata * 1000).rounded())) ms")
                // 200 schede incomplete: la firma da segnare sulle posizioni in essere d'investimento e risparmio
                let adesso = Appuntamento.alMinuto(Date())
                s.dati.schedeAdeguatezza = s.dati.posizioni
                    .filter { $0.stato == .inEssere && $0.area.proiettabile }
                    .prefix(200)
                    .map { SchedaAdeguatezza(posizioneId: $0.id, clienteId: $0.clienteId, creataIl: adesso) }
                let schede = s.dati.schedeAdeguatezza.count
                let inizioNotifiche = Date()
                _ = MotoreNotifiche.calcola(s)
                let tempoNotifiche = Date().timeIntervalSince(inizioNotifiche)
                controlla(schede == 200 && tempoNotifiche < limiteNotifiche,
                          "Centro notifiche con \(schede) schede incomplete in \(Int((tempoNotifiche * 1000).rounded())) ms (limite \(Int(limiteNotifiche * 1000)) ms)")
            } else {
                controlla(false, "Tempi: archivio con 200 clienti")
            }
        }

        return esiti
    }

    /// Dentro `Prisma --prova-prospetti`: la scheda di Sofia (indipendente, con le scelte) e quella di Andrea
    /// (Alleanza, senza scheda): due pagine A4 verticali, canale riconoscibile, firme e avvertenza prudente.
    static func provaProspetti(_ verifica: (String, Bool, String) -> Void, cartella: URL?) {
        let statoScheda = StatoShell(persistente: false)
        prepara(statoScheda)
        let casi: [(nome: String, cliente: String, id: String, canale: String, esito: String)] = [
            ("adeguatezza-sofia", "Sofia Romano", sofia, "Denis Vicenzoni · Consulenza finanziaria",
             TestiAdeguatezza.complessivo(.giallo)),
            ("adeguatezza-andrea", "Andrea Conti", andrea, "Alleanza", TestiAdeguatezza.complessivo(.rosso)),
        ]
        for caso in casi {
            guard let p = posizione(statoScheda, caso.id), let d = statoScheda.documentoAdeguatezza(p) else {
                verifica("Scheda di adeguatezza \(caso.nome): documento creato", false, "")
                continue
            }
            verifica("Scheda di adeguatezza \(caso.nome): A4 verticale, due pagine",
                     d.formato == Misure.Documento.prospetto && d.pagine.count == 2, "\(d.pagine.count) pagine")
            guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                verifica("Scheda di adeguatezza \(caso.nome): PDF creato", false, "")
                continue
            }
            verifica("Scheda di adeguatezza \(caso.nome): PDF di 2 pagine", documento.pageCount == 2, "\(documento.pageCount) pagine")
            let testo = ProvaProspetti.spazi(StampaCarta.testo(pdf).joined(separator: " "))
            for atteso in ["Scheda di adeguatezza", caso.cliente, caso.canale, "Firma del cliente", "Luogo e data",
                           "non è un parere legale", caso.esito] {
                verifica("Scheda di adeguatezza \(caso.nome): «\(atteso)»", testo.contains(atteso), "")
            }
            if let cartella { try? pdf.write(to: cartella.appendingPathComponent("\(caso.nome).pdf")) }
        }
    }
}
