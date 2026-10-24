import Foundation

/// Gli spunti di analisi della sintesi dai dati: leggono gli stessi motori dei prospetti e dei report
/// (check-up, resoconto, previdenza, protezione, liquidità, obiettivi, sostituzione), così Eve e i
/// documenti dicono le stesse cifre. Le risposte sono per il consulente, non per il cliente.
extension MotoreSintesi {

    func checkUp(_ f: FonteEve) -> RispostaEve {
        let e = MotoreCheckUp.calcola(cliente: f.cliente, posizioni: f.posizioni, analisi: f.analisi, obiettivi: f.obiettivi)
        let grigi = e.indicatori.filter { $0.semaforo == .grigio }.count
        let daRaccogliere = grigi > 0 ? ", \(grigi) con dati da raccogliere." : "."
        var parti = ["Semaforo: \(e.verdi.count) in ordine, \(e.gialli.count) da migliorare, \(e.rossi.count) da affrontare" + daRaccogliere]
        let ordinati = e.indicatori.sorted { $0.semaforo.urgenza < $1.semaforo.urgenza }
        parti.append(ordinati.map { "• \($0.titolo) — \($0.semaforo.nome.lowercased()): \($0.valore). \($0.azione)" }.joined(separator: "\n"))
        if !e.proposte.isEmpty { parti.append("Proposte già aperte: \(e.proposte.prefix(3).map { "\($0.nome) (\($0.canale.nomeBreve))" }.joined(separator: ", ")).") }
        parti.append(documento("Check-up"))
        return RispostaEve(titolo: "Check-up di \(f.cliente.nome)", testo: parti.joined(separator: "\n\n"))
    }

    func resoconto(_ f: FonteEve) -> RispostaEve {
        let e = MotoreResoconto.calcola(f.posizioni, cliente: f.cliente.nome, prodotti: f.prodotti, data: f.oggi)
        guard !e.finanziarie.isEmpty else {
            return RispostaEve(titolo: "Nessun investimento in essere",
                               testo: "\(f.cliente.nome) non ha posizioni finanziarie in essere: il resoconto riporta solo coperture, liquidità e debiti. Le trovi in Posizioni.")
        }
        let annuo = e.rendimentoAnnuo.map { ", \(CifreDoc.variazione($0)) l'anno" } ?? ""
        var parti = ["Investito \(CifreDoc.euro(e.versato)), valore oggi \(CifreDoc.euro(e.valoreFinanziario)): risultato \(CifreDoc.euroSegno(e.risultato)) (\(CifreDoc.variazione(e.risultatoPercento)))\(annuo)."]
        if let v = e.variazione12, let vp = e.variazione12Percento {
            parti.append("Ultimi 12 mesi: \(CifreDoc.euroSegno(v)) (\(CifreDoc.variazione(vp))).")
        }
        parti.append("Se chiudesse tutto oggi incasserebbe \(CifreDoc.euroCentesimi(e.nettoFinanziario)) netti: imposte \(CifreDoc.euroCentesimi(e.imposteFinanziarie))"
            + (e.penaliFinanziarie > 0 ? ", penali e bollo \(CifreDoc.euroCentesimi(e.penaliFinanziarie))" : "") + ".")
        var costi = "Costi di un anno: \(CifreDoc.euroCentesimi(e.costoGestione)) di gestione"
        if e.costoTrattenuto > 0 { costi += ", \(CifreDoc.euroCentesimi(e.costoTrattenuto)) trattenuti sul rendimento" }
        if e.costoBollo > 0 { costi += ", \(CifreDoc.euroCentesimi(e.costoBollo)) di bollo" }
        parti.append(costi + (e.rendimentoNettoAnnuo.map { ". Rendimento annuo al netto dei costi: \(CifreDoc.variazione($0))." } ?? "."))
        let voci = e.finanziarie.sorted { $0.valore > $1.valore }.prefix(5).map { v -> String in
            var r = "• \(v.posizione.nome) (\(v.posizione.canale.nomeBreve)): \(CifreDoc.euro(v.valore))"
            if v.risultato != nil { r += ", \(TestiResoconto.risultato(v.risultato, v.risultatoPercento))" }
            r += ", netto oggi \(CifreDoc.euroCentesimi(v.fisco.netto))"
            return r
        }
        parti.append(voci.joined(separator: "\n"))
        // Rispetto all'atteso, dallo storico dei valori
        let andamenti = e.finanziarie.compactMap { v in MotoreAndamento.calcola(v.posizione).map { (v.posizione, $0) } }
        if !andamenti.isEmpty {
            parti.append("Com'è andata rispetto all'atteso (al netto dei costi, tolti i versamenti):\n" + andamenti.map { p, a in
                var r = "• \(p.nome): " + (a.rendimentoAnnuo.map { "\(CifreDoc.variazione($0)) l'anno" } ?? "\(CifreDoc.variazione(a.rendimentoPeriodo)) in \(Int((a.anni * 12).rounded())) mesi")
                if let g = a.giudizio, let s = a.scarto { r += ", \(g.nome)" + (g == .inLinea ? "" : " (\(MotoreAndamento.punti(s)))") }
                return r
            }.joined(separator: "\n"))
        }
        parti.append(documento("Resoconto"))
        return RispostaEve(titolo: "Le posizioni di \(f.cliente.nome)", testo: parti.joined(separator: "\n\n"))
    }

    /// L'andamento di una posizione nominata nella domanda («come va la polizza Futuro Sereno?»).
    func andamento(_ p: Posizione, _ f: FonteEve) -> RispostaEve {
        guard let a = MotoreAndamento.calcola(p) else {
            return RispostaEve(titolo: p.nome,
                               testo: "Di \(p.nome) c'è un solo valore registrato: per l'andamento servono almeno due valori. In Posizioni, nella scheda della posizione, puoi aggiungere i valori passati dagli estratti conto (Storico dei valori → «＋ Valore passato»).")
        }
        var parti = [MotoreAndamento.sintesi(a, nome: p.nome)]
        let periodi = a.periodi.suffix(4).map { q in
            "• \(Formati.dataBreve.string(from: q.dal)) – \(Formati.dataBreve.string(from: q.al)): \(CifreDoc.euroSegno(q.guadagno))"
                + (q.rendimento.map { " (\(CifreDoc.variazione($0)))" } ?? "") + (q.stimati ? ", versamenti stimati" : "")
        }
        parti.append("Periodo per periodo:\n" + periodi.joined(separator: "\n"))
        if a.giudizio == .sotto {
            parti.append("Prima di parlarne con \(f.cliente.nome): controlla costi e composizione (\(p.costoComplessivo.map { "costo annuo \(CifreDoc.percento($0))" } ?? "costo annuo non indicato")), e se ha senso un confronto con un'alternativa (spunto «Conviene restare o cambiare?»).")
        }
        return RispostaEve(titolo: "Andamento di \(p.nome)", testo: parti.joined(separator: "\n\n"))
    }

    /// La posizione in essere nominata nella domanda: tutto il nome, o tutte le sue parole lunghe.
    static func posizioneNominata(_ domanda: String, in posizioni: [Posizione]) -> Posizione? {
        func piega(_ s: String) -> String { s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano) }
        let d = piega(domanda)
        let candidate = posizioni.filter { $0.stato == .inEssere && !$0.nome.isEmpty }
        if let p = candidate.filter({ d.contains(piega($0.nome)) }).max(by: { $0.nome.count < $1.nome.count }) { return p }
        return candidate.first { p in
            let parole = piega(p.nome).split { !$0.isLetter && !$0.isNumber }.filter { $0.count >= 4 }
            return parole.count >= 2 && parole.allSatisfy { d.contains($0) }
        }
    }

    func pensione(_ f: FonteEve) -> RispostaEve {
        let e = MotorePrevidenza.calcola(f.posizioni, cliente: f.cliente, analisi: f.analisi.previdenza, data: f.oggi)
        var parti: [String] = []
        parti.append(e.divario < 1
            ? "A \(e.etaPensione) anni la pensione pubblica stimata (\(mese(e.pensionePubblica))) copre il reddito desiderato."
            : "A \(e.etaPensione) anni, tra \(e.anniAccumulo) anni, mancano \(mese(e.divario)): desidera \(mese(e.redditoDesiderato)), la pensione pubblica stimata è \(mese(e.pensionePubblica)).")
        if !e.inEssere.isEmpty {
            parti.append("I piani in essere aggiungono \(mese(e.renditaInEssere)); restano \(mese(e.divarioResiduo)).")
        }
        if !e.proposte.isEmpty {
            parti.append("Con la proposta \(e.proposte.map(\.posizione.nome).joined(separator: ", ")) altri \(mese(e.renditaProposte)): restano \(mese(e.divarioConProposte)).")
        } else if let v = e.versamentoMancante, e.divarioResiduo >= 1 {
            parti.append("Per colmare il resto servono circa \(CifreDoc.euro(v)) al mese in più.")
        }
        if let a = e.aliquotaMarginale {
            parti.append("Fisco: aliquota IRPEF marginale \(CifreDoc.condizione(a)); deduce \(CifreDoc.euroCentesimi(e.deducibiliOggi)) l'anno e risparmia \(CifreDoc.euroCentesimi(e.risparmioOggi)) di IRPEF"
                + (e.spazioResiduo > 0.5 ? "; resta uno spazio deducibile di \(CifreDoc.euroCentesimi(e.spazioResiduo)) (altri \(CifreDoc.euroCentesimi(e.risparmioPossibile)) di risparmio)." : "."))
        } else {
            parti.append("Manca il reddito lordo annuo nel profilo: senza non calcolo il risparmio IRPEF dei versamenti.")
        }
        // Aliquote sulle uscite, causa per causa, al centesimo (D.Lgs. 252/2005)
        for p in f.posizioni where p.stato == .inEssere && p.regime == .previdenza {
            let fisco = MotoreFiscale.calcola(p, prodotto: prodotto(p, f), data: f.oggi)
            var righe = ["\(p.nome) (\(p.canale.nomeBreve)), \(fisco.anniPartecipazione ?? 0) anni di partecipazione, valore \(CifreDoc.euroCentesimi(fisco.valore)):"]
            for u in fisco.uscite {
                righe.append(u.possibile
                    ? "• \(u.causa.nomeBreve): fino a \(CifreDoc.euroCentesimi(u.importo)), aliquota \(CifreDoc.percento(u.aliquota, decimali: 2)), imposta \(CifreDoc.euroCentesimi(u.imposta)), netto \(CifreDoc.euroCentesimi(u.netto))"
                    : "• \(u.causa.nomeBreve): non ancora possibile (servono \(u.causa.anniRichiesti ?? 0) anni di iscrizione)")
            }
            if let g = fisco.gradini.first {
                righe.append("L'aliquota agevolata scende al \(CifreDoc.percento(g.aliquota, decimali: 2)) dal \(CifreDoc.data(g.dal)), poi di 0,30 punti l'anno fino al 9%.")
            }
            parti.append(righe.joined(separator: "\n"))
        }
        parti.append(documento("Piano previdenziale"))
        return RispostaEve(titolo: "La pensione di \(f.cliente.nome)", testo: parti.joined(separator: "\n\n"))
    }

    func protezioneFamiglia(_ f: FonteEve) -> RispostaEve {
        let e = MotoreProtezioneFamiglia.calcola(f.posizioni, cliente: f.cliente, analisi: f.analisi.protezione)
        let i = e.ipotesi
        var parti = ["Caso morte: alla famiglia servirebbero \(CifreDoc.euro(e.fabbisogno)) (debiti \(CifreDoc.euro(i.debiti)), spese immediate \(CifreDoc.euro(i.speseImmediate)), \(CifreDoc.euro(i.fabbisognoMensile)) al mese per \(i.anniSostegno) anni, meno \(CifreDoc.euro(i.capitaleDisponibile)) disponibili)."]
        parti.append(e.divario > 0
            ? "Coperture in essere \(CifreDoc.euro(e.capitaleVita)): mancano \(CifreDoc.euro(e.divario))" + (e.divarioConProposte < e.divario ? ", con le proposte \(CifreDoc.euro(e.divarioConProposte))." : ".")
            : "Le coperture caso morte in essere (\(CifreDoc.euro(e.capitaleVita))) bastano per il fabbisogno stimato.")
        if e.riservaMancante > 0 {
            parti.append("Invalidità o malattia lunga: mancherebbero \(CifreDoc.euro(e.ammanco)) al mese; per \(i.mesiRiserva) mesi serve una riserva di \(CifreDoc.euro(e.riservaNecessaria)), ne mancano \(CifreDoc.euro(e.riservaMancante)).")
        }
        let scoperte = e.tutele.filter { $0.importante && $0.stato != .coperto }
        if !scoperte.isEmpty {
            parti.append("Tutele importanti non coperte:\n" + scoperte.map { "• \($0.rischio.nome)\($0.stato == .inProposta ? " (in proposta)" : "")\($0.perche.isEmpty ? "" : ": \($0.perche)")" }.joined(separator: "\n"))
        }
        if e.premiAnnui > 0 {
            parti.append("Premi delle coperture \(CifreDoc.euroCentesimi(e.premiAnnui)) l'anno" + (e.detrazione > 0 ? ", detrazione IRPEF del 19% di \(CifreDoc.euroCentesimi(e.detrazione))." : "."))
        }
        parti.append(contentsOf: e.avvisi.prefix(2).map(\.testo))
        parti.append("Esclusioni, carenze e massimali vanno letti nelle condizioni di polizza. " + documento("Protezione della famiglia"))
        return RispostaEve(titolo: "La protezione di \(f.cliente.nome)", testo: parti.joined(separator: "\n\n"))
    }

    func liquidita(_ f: FonteEve) -> RispostaEve {
        let e = MotoreLiquidita.calcola(f.posizioni, obiettivi: f.obiettivi, analisi: f.analisi.protezione, prodotti: f.prodotti, data: f.oggi)
        var parti = ["Liquidità oggi \(CifreDoc.euro(e.liquiditaAttuale))" + (e.scadenze.isEmpty ? "; nessun capitale in scadenza nei prossimi \(IpotesiLiquidita.finestraMesi) mesi." : ".")]
        for s in e.scadenze {
            parti.append("\(s.posizione.nome) (\(s.posizione.canale.nomeBreve)) \(s.scaduto ? "è scaduta il" : "scade il") \(CifreDoc.data(s.data)): incassa \(CifreDoc.euroCentesimi(s.netto)) netti (imposte \(CifreDoc.euroCentesimi(s.fisco.imposta + s.fisco.bolloMaturato))).")
        }
        parti.append("Riserva da tenere: \(CifreDoc.euro(e.riservaNecessaria)) (\(e.mesiRiserva) mesi di spese da \(CifreDoc.euro(e.fabbisognoMensile))). "
            + (e.eccedenza > 0 ? "Restano \(CifreDoc.euro(e.eccedenza)) da destinare." : "Il totale non supera la riserva."))
        let pieni = e.salvadanai.filter { $0.importo >= 1 }
        if !pieni.isEmpty {
            parti.append("Salvadanai:\n" + pieni.map { "• \($0.titolo): \(CifreDoc.euro($0.importo)) (\($0.orizzonte))" }.joined(separator: "\n"))
        }
        if e.vantaggioDestinare > 1 {
            parti.append("In \(IpotesiLiquidita.anniConfronto) anni, lasciato fermo il capitale perde \(CifreDoc.euro(e.perditaFermo)) di potere d'acquisto; destinato così ne guadagna \(CifreDoc.euro(e.vantaggioDestinare)) in più.")
        }
        parti.append(documento("Capitale in scadenza e liquidità"))
        return RispostaEve(titolo: "La liquidità di \(f.cliente.nome)", testo: parti.joined(separator: "\n\n"))
    }

    func obiettivi(_ f: FonteEve) -> RispostaEve {
        guard !f.obiettivi.isEmpty else {
            return RispostaEve(titolo: "Nessun obiettivo",
                               testo: "\(f.cliente.nome) non ha ancora obiettivi. Si fissano in Obiettivi: importo, data e posizioni collegate; poi calcolo il piano.")
        }
        let righe = f.obiettivi.prefix(4).map { o -> String in
            let e = MotoreObiettivo.calcola(o, posizioni: f.posizioni, data: f.oggi)
            var r = "• \(o.titolo): \(CifreDoc.euro(o.importo)) entro il \(CifreDoc.data(o.scadenza)) (\(CifreDoc.euro(e.importoScadenza)) con l'inflazione). "
                + "Si arriva a \(CifreDoc.euro(e.proiezione)), il \(CifreDoc.percento(e.copertura * 100, decimali: 0))"
            if e.mancante >= 1 {
                r += "; mancano \(CifreDoc.euro(e.mancante))"
                if let v = e.versamentoNecessario { r += ", servono \(CifreDoc.euro(v)) al mese in più" }
            }
            return r + "."
        }
        return RispostaEve(titolo: "Gli obiettivi di \(f.cliente.nome)",
                           testo: righe.joined(separator: "\n") + "\n\n" + documento("Piano obiettivo"))
    }

    func cambiare(_ f: FonteEve) -> RispostaEve {
        let scelta = f.confronto.map { [$0.attuale, $0.alternativa] } ?? MotoreSostituzione.coppia(f.posizioni).map { [$0.0, $0.1] } ?? []
        guard scelta.count == 2, let pa = f.posizioni.first(where: { $0.id == scelta[0] }),
              let pb = f.posizioni.first(where: { $0.id == scelta[1] }) else {
            return RispostaEve(titolo: "Niente da confrontare",
                               testo: "Per valutare se restare o cambiare servono una posizione in essere e una proposta (o due posizioni finanziarie). Si preparano in Posizioni.")
        }
        let e = MotoreSostituzione.calcola(attuale: pa, alternativa: pb, prodotti: f.prodotti, anni: f.anniConfronto, orizzonteCliente: f.cliente.profilo.orizzonteAnni, data: f.oggi)
        let periodo = e.anni == 1 ? "1 anno" : "\(e.anni) anni"
        var parti = [e.sostituzione
            ? "Restare in \(pa.nome) (\(pa.canale.nomeBreve)) o passare a \(pb.nome) (\(pb.canale.nomeBreve)), su \(periodo)."
            : "Confronto tra \(pa.nome) (\(pa.canale.nomeBreve)) e \(pb.nome) (\(pb.canale.nomeBreve)), su \(periodo)."]
        if e.sostituzione, e.costoUscita > 0 {
            var uscita = "Uscire oggi costa \(CifreDoc.euroCentesimi(e.costoUscita))"
            var voci: [String] = []
            if e.penaleUscita > 0 { voci.append("penale \(CifreDoc.euroCentesimi(e.penaleUscita))") }
            if e.impostaUscita > 0 { voci.append("imposte \(CifreDoc.euroCentesimi(e.impostaUscita))") }
            if e.bolloUscita > 0 { voci.append("bollo \(CifreDoc.euroCentesimi(e.bolloUscita))") }
            if e.ingressoCambio > 0 { voci.append("ingresso \(CifreDoc.euroCentesimi(e.ingressoCambio))") }
            if !voci.isEmpty { uscita += " (\(voci.joined(separator: ", ")))" }
            parti.append(uscita + (e.trasferimento ? ": è un trasferimento tra fondi pensione, senza imposte." : "."))
        }
        if let fine = e.finale {
            let meglio = fine.differenza > 0 ? (e.sostituzione ? "Cambiare" : pb.nome) : (e.sostituzione ? "Restare" : pa.nome)
            var recupero = "."
            if let anno = e.pareggio, fine.differenza > 0, e.sostituzione { recupero = "; il costo dell'uscita si recupera dal \(anno)° anno." }
            parti.append("Netto a fine periodo, scenario centrale: \(CifreDoc.euro(fine.nettoResto)) contro \(CifreDoc.euro(fine.nettoCambio)). \(meglio) rende \(CifreDoc.euro(abs(fine.differenza))) in più\(recupero)")
        }
        if !e.scenari.isEmpty {
            parti.append("Scenari: " + e.scenari.map { "\($0.nome.lowercased()) \(CifreDoc.euroSegno($0.differenza))" }.joined(separator: ", ") + " a favore di \(e.sostituzione ? "cambiare" : pb.nome).")
        }
        parti.append("È una simulazione con rendimenti ipotetici: verifica KID e condizioni. " + documento("Sostituzione o confronto"))
        return RispostaEve(titolo: e.sostituzione ? "Restare o cambiare: \(pa.nome)" : "Confronto: \(pa.nome) e \(pb.nome)",
                           testo: parti.joined(separator: "\n\n"))
    }

    // MARK: - Aiuti

    private func mese(_ v: Double) -> String { "\(CifreDoc.euro(v)) al mese" }

    private func prodotto(_ p: Posizione, _ f: FonteEve) -> Prodotto? {
        p.prodottoId.flatMap { id in f.prodotti.first { $0.id == id } }
    }

    /// Dove trovare il documento con le stesse cifre.
    private func documento(_ nome: String) -> String {
        "Il prospetto e il report «\(nome)» sono in Prospetti e report."
    }
}
