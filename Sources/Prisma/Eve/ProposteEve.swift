import Foundation

/// Spunto «Cosa proporre al cliente?»: dalle analisi di Prisma (protezione, liquidità, previdenza,
/// obiettivi, scadenze) Eve ricava le azioni da fare, in ordine di urgenza, ciascuna con il perché e
/// le cifre. Ogni azione diventa un'attività o una bozza di proposta in Posizioni: decide il consulente.
extension MotoreSintesi {
    static let massimoProposte = 6

    func proposte(_ f: FonteEve) -> RispostaEve {
        let elenco = Self.calcolaProposte(f)
        guard !elenco.isEmpty else {
            return RispostaEve(titolo: "Niente di nuovo da proporre",
                               testo: "Per \(f.cliente.nome) le analisi non mostrano scoperture: protezione, riserva, pensione e obiettivi sono in ordine o hanno già una proposta aperta. Conviene rivedere il quadro al prossimo resoconto.")
        }
        let righe = elenco.enumerated().map { "\($0.offset + 1). \($0.element.titolo) — \($0.element.perche)" }
        let gia = f.posizioni.filter { $0.stato == .proposta && $0.esito != .rifiutata && $0.esito != .accettata }
        var testo = righe.joined(separator: "\n")
        if !gia.isEmpty { testo += "\n\nGià in proposta: \(gia.map { "\($0.nome) (\($0.canale.nomeBreve))" }.joined(separator: ", "))." }
        testo += "\n\nOgni azione diventa un'attività o una bozza di proposta da completare in Posizioni: prodotto, canale e cifre li scegli tu."
        return RispostaEve(titolo: "Cosa proporre a \(f.cliente.nome)", testo: testo, proposte: elenco)
    }

    /// Le azioni, in ordine di urgenza; salta quelle che hanno già una proposta aperta nella stessa area.
    static func calcolaProposte(_ f: FonteEve) -> [PropostaEve] {
        var elenco: [PropostaEve] = []
        let aperte = f.posizioni.filter { $0.stato == .proposta && $0.esito != .rifiutata && $0.esito != .accettata }
        func giaProposta(_ area: AreaPosizione, _ rischio: RischioCoperto? = nil) -> Bool {
            aperte.contains { $0.area == area && (rischio == nil || $0.rischio == rischio) }
        }

        // 1. La famiglia in caso di morte
        let prot = MotoreProtezioneFamiglia.calcola(f.posizioni, cliente: f.cliente, analisi: f.analisi.protezione, data: f.oggi)
        let vita = prot.tutele.first { $0.rischio == .vita }
        if prot.divarioConProposte >= 1_000, vita?.importante != false, !giaProposta(.protezione, .vita) {
            let capitale = arrotonda(prot.divarioConProposte, a: 5_000)
            elenco.append(PropostaEve(id: "protezione-vita", titolo: "Copertura caso morte di circa \(CifreDoc.euro(capitale))",
                                      perche: "alla famiglia servirebbero \(CifreDoc.euro(prot.fabbisogno)), le coperture in essere valgono \(CifreDoc.euro(prot.capitaleVita)).",
                                      area: .protezione, rischio: .vita, capitale: capitale))
        }
        // 2. Invalidità e malattia
        let invalidita = prot.tutele.first { $0.rischio == .invalidita }
        if prot.riservaMancante >= 1_000, invalidita?.stato == .scoperto, !giaProposta(.protezione, .invalidita) {
            elenco.append(PropostaEve(id: "protezione-invalidita", titolo: "Tutela per invalidità e malattia",
                                      perche: "in caso di stop al lavoro mancherebbero \(CifreDoc.euro(prot.ammanco)) al mese; alla riserva per \(prot.ipotesi.mesiRiserva) mesi mancano \(CifreDoc.euro(prot.riservaMancante)).",
                                      area: .protezione, rischio: .invalidita))
        }
        // 3. La riserva di emergenza
        let liq = MotoreLiquidita.calcola(f.posizioni, obiettivi: f.obiettivi, analisi: f.analisi.protezione, prodotti: f.prodotti, data: f.oggi)
        let mancaRiserva = liq.riservaNecessaria - liq.totale
        if mancaRiserva >= 500, !giaProposta(.liquidita) {
            let mensile = arrotonda(mancaRiserva / 12, a: 10)
            elenco.append(PropostaEve(id: "liquidita-riserva", titolo: "Costruire la riserva di emergenza",
                                      perche: "servono \(CifreDoc.euro(liq.riservaNecessaria)) (\(liq.mesiRiserva) mesi di spese), tra conti e capitali in arrivo nei prossimi \(IpotesiLiquidita.finestraMesi) mesi ce ne sono \(CifreDoc.euro(liq.totale)): circa \(CifreDoc.euro(mensile)) al mese per un anno.",
                                      area: .liquidita, versamentoMensile: mensile, importo: mancaRiserva))
        }
        // 4. La pensione
        let prev = MotorePrevidenza.calcola(f.posizioni, cliente: f.cliente, analisi: f.analisi.previdenza, data: f.oggi)
        if prev.divarioConProposte >= 50, let v = prev.versamentoMancante, v >= 10, !giaProposta(.previdenza) {
            let mensile = arrotonda(v, a: 10)
            var perche = "alla pensione mancano \(CifreDoc.euro(prev.divarioConProposte)) al mese rispetto al reddito desiderato"
            if let reddito = prev.reddito, let a = prev.aliquotaMarginale, prev.spazioResiduo > 0 {
                let deducibile = min(mensile * 12, prev.spazioResiduo)
                let risparmio = RegoleFiscali.risparmioDeduzione(reddito: reddito, deduzione: prev.deducibiliConProposte + deducibile) - prev.risparmioConProposte
                perche += "; i versamenti si deducono: circa \(CifreDoc.euro(risparmio)) l'anno di IRPEF in meno (aliquota marginale del \(CifreDoc.condizione(a)))"
            }
            elenco.append(PropostaEve(id: "previdenza", titolo: "Piano previdenziale da \(CifreDoc.euro(mensile)) al mese", perche: perche + ".",
                                      area: .previdenza, versamentoMensile: mensile))
        }
        // 5. Gli obiettivi scoperti
        for o in f.obiettivi.sorted(by: { $0.priorita > $1.priorita }) {
            let e = MotoreObiettivo.calcola(o, posizioni: f.posizioni, data: f.oggi)
            guard e.mancante >= 500, let v = e.versamentoNecessario, v >= 10 else { continue }
            let mensile = arrotonda(v, a: 10)
            elenco.append(PropostaEve(id: "obiettivo-\(o.id)", titolo: "Piano di accumulo per «\(o.titolo)», \(CifreDoc.euro(mensile)) al mese",
                                      perche: "così si arriva a \(CifreDoc.euro(e.proiezione)) su \(CifreDoc.euro(e.importoScadenza)) entro il \(CifreDoc.data(o.scadenza)); mancano \(CifreDoc.euro(e.mancante)).",
                                      area: .risparmio, versamentoMensile: mensile))
        }
        // 6. Il capitale in eccesso rispetto alla riserva
        if liq.eccedenza >= 5_000, !giaProposta(.investimento) {
            let importo = arrotonda(liq.eccedenza, a: 1_000)
            elenco.append(PropostaEve(id: "liquidita-destinare", titolo: "Far lavorare \(CifreDoc.euro(importo)) oltre la riserva",
                                      perche: "fermi sul conto, in \(IpotesiLiquidita.anniConfronto) anni perderebbero circa \(CifreDoc.euro(liq.totale > 0 ? liq.perditaFermo * importo / liq.totale : 0)) di potere d'acquisto.",
                                      area: .investimento, importo: importo))
        }
        // 7. I capitali in scadenza
        for s in liq.scadenze {
            elenco.append(PropostaEve(id: "scadenza-\(s.posizione.id)", titolo: "Decidere il reinvestimento di \(s.posizione.nome)",
                                      perche: "\(s.scaduto ? "è scaduta il" : "scade il") \(CifreDoc.data(s.data)) e libera \(CifreDoc.euroCentesimi(s.netto)) netti (\(s.posizione.canale.nomeBreve))."))
        }
        // Niente doppioni delle bozze già preparate con Eve
        return Array(elenco.filter { p in !aperte.contains { $0.nome == p.titolo } }.prefix(massimoProposte))
    }

    private static func arrotonda(_ v: Double, a passo: Double) -> Double {
        max(passo, (v / passo).rounded() * passo)
    }
}
