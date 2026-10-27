import Foundation

/// Le ipotesi della protezione per persona (oltre a quelle del nucleo, `IpotesiProtezione`).
struct IpotesiPersona: Equatable {
    /// Età fino a cui un figlio resta a carico, se per il familiare non è indicata.
    var etaFineCarico = 25
    /// Un familiare non autosufficiente ha bisogno di sostegno per tutta la vita: fino a questa età.
    var etaFineSostegnoAVita = 85
    /// Età di pensione se nei dati del lavoro non è indicata: fin lì c'è reddito da sostituire.
    var etaPensione = RegolePensione.etaVecchiaia
    /// Non autosufficienza: spesa mensile per l'assistenza e anni per cui serve (ipotesi prudenti).
    var spesaAssistenzaMensile = 1_500.0
    var anniAssistenza = 5
}

/// Il fabbisogno di protezione di una persona che porta reddito in famiglia: caso morte, invalidità e
/// non autosufficienza, confrontati con le coperture di cui quella persona è l'assicurato.
struct FabbisognoPersona: Identifiable {
    /// Un familiare che dipende da questa persona e per quanti anni.
    struct Dipendente: Identifiable {
        let id: String
        let nome: String
        let eta: Int?
        let anni: Int
        let aVita: Bool
    }

    let id: String
    let nome: String
    /// nil per il cliente.
    let relazione: Familiare.Relazione?
    let eta: Int?
    /// Reddito netto annuo portato in famiglia e la sua quota sul reddito del nucleo (0–1).
    let redditoNetto: Double
    /// true se il reddito netto non è indicato ed è stimato dal fabbisogno dell'Analisi 360.
    let redditoStimato: Bool
    let quotaReddito: Double

    // Caso morte
    /// Debiti residui a carico di questa persona (con la quota del cointestato).
    let debiti: Double
    /// Durata residua più lunga dei debiti a suo carico, in mesi.
    let mesiDebiti: Int?
    let speseImmediate: Double
    /// Sostegno annuo alla famiglia: fabbisogno mensile × 12 × quota del reddito.
    let sostegnoAnnuo: Double
    let anniSostegno: Int
    let dipendenti: [Dipendente]
    let capitaleDisponibile: Double
    var sostegno: Double { sostegnoAnnuo * Double(anniSostegno) }
    var fabbisognoMorte: Double { max(0, debiti + speseImmediate + sostegno - capitaleDisponibile) }
    let capitaleMorte: Double
    let capitaleMorteProposte: Double
    var divarioMorte: Double { max(0, fabbisognoMorte - capitaleMorte) }
    var divarioMorteConProposte: Double { max(0, fabbisognoMorte - capitaleMorte - capitaleMorteProposte) }
    /// Anni per cui serve la copertura caso morte: la durata più lunga tra debiti e sostegno.
    var anniCopertura: Int { max(anniSostegno, ((mesiDebiti ?? 0) + 11) / 12) }

    // Invalidità
    let anniAllaPensione: Int
    /// Entrate che restano in caso di invalidità (annue).
    let entrateSostitutive: Double
    var fabbisognoInvalidita: Double { max(0, redditoNetto - entrateSostitutive) * Double(anniAllaPensione) }
    let capitaleInvalidita: Double
    let capitaleInvaliditaProposte: Double
    var divarioInvalidita: Double { max(0, fabbisognoInvalidita - capitaleInvalidita) }
    var divarioInvaliditaConProposte: Double { max(0, fabbisognoInvalidita - capitaleInvalidita - capitaleInvaliditaProposte) }

    // Non autosufficienza
    let fabbisognoLTC: Double
    let capitaleLTC: Double
    let capitaleLTCProposte: Double
    var divarioLTC: Double { max(0, fabbisognoLTC - capitaleLTC) }
    var divarioLTCConProposte: Double { max(0, fabbisognoLTC - capitaleLTC - capitaleLTCProposte) }

    /// Infortuni: solo indicativo (pagano solo se l'invalidità viene da un infortunio).
    let capitaleInfortuni: Double
    /// Coperture in essere e proposte aperte di cui questa persona è l'assicurato.
    let coperture: [Posizione]
    let proposte: [Posizione]
    var avvisi: [String]
}

/// Una persona che porta reddito in famiglia (il cliente ha `familiare` nil).
private struct PersonaConReddito {
    let id: String
    let nome: String
    let familiare: Familiare?
    let netto: Double
    let stimato: Bool
}

extension MotoreProtezioneFamiglia {
    /// Il fabbisogno per ogni persona che porta reddito: il cliente (sempre) e i familiari con un reddito netto.
    /// Non cambia il fabbisogno del nucleo di `calcola`: è un'analisi affiancata. Calcolo leggero.
    static func perPersona(_ posizioni: [Posizione], cliente: Cliente, analisi: IpotesiProtezione, data: Date = Date(),
                           ipotesi: IpotesiPersona = IpotesiPersona()) -> [FabbisognoPersona] {
        let oggi = Calendar.current.startOfDay(for: data)
        let coperture = posizioni.filter { $0.area == .protezione && $0.stato == .inEssere && ($0.scadenza.map { $0 >= oggi } ?? true) }
        let proposte = posizioni.filter { $0.area == .protezione && $0.stato == .proposta && $0.esito != .rifiutata && $0.esito != .accettata }
        let debiti = posizioni.filter { $0.area == .debiti && $0.stato == .inEssere }
        let famiglia = cliente.famiglia

        // Chi porta reddito
        let nettoCliente = cliente.profilo.redditoNettoAnnuo
        var persone = [PersonaConReddito(id: cliente.id, nome: cliente.nome, familiare: nil,
                                         netto: max(0, nettoCliente ?? analisi.fabbisognoMensile * 12), stimato: nettoCliente == nil)]
        for f in famiglia where (f.redditoNettoAnnuo ?? 0) > 0 {
            persone.append(PersonaConReddito(id: f.id, nome: f.nome, familiare: f, netto: f.redditoNettoAnnuo ?? 0, stimato: false))
        }
        let totale = persone.reduce(0) { $0 + $1.netto }
        let partner: Set<Familiare.Relazione> = [.coniuge, .convivente]
        let figli: Set<Familiare.Relazione> = [.figlio, .figlia]

        return persone.map { persona -> FabbisognoPersona in
            let eCliente = persona.familiare == nil
            let eta = MotorePensionePubblica.etaAl(eCliente ? cliente.dataNascita : persona.familiare?.dataNascita, data)
            let quota = totale > 0 ? persona.netto / totale : (eCliente ? 1 : 0)
            var avvisi: [String] = []

            // Chi dipende da questa persona e per quanti anni
            var dipendenti: [FabbisognoPersona.Dipendente] = []
            for f in famiglia where f.id != persona.id {
                let aVita = f.nonAutosufficiente == true
                let e = MotorePensionePubblica.etaAl(f.dataNascita, data)
                let figlio = figli.contains(f.relazione)
                let fine = f.etaFineCarico ?? ipotesi.etaFineCarico
                let senzaReddito = (f.redditoNettoAnnuo ?? 0) <= 0
                guard aVita || (senzaReddito && (f.aCarico || (figlio && (e ?? 99) < fine))) else { continue }
                let anni: Int
                if let e {
                    if aVita { anni = max(0, ipotesi.etaFineSostegnoAVita - e) }
                    else if f.etaFineCarico != nil || figlio { anni = max(0, fine - e) }
                    else { anni = analisi.anniSostegno }
                } else {
                    anni = analisi.anniSostegno
                }
                dipendenti.append(FabbisognoPersona.Dipendente(id: f.id, nome: f.nome, eta: e, anni: anni, aVita: aVita))
            }
            // Se resta il partner, almeno gli anni di sostegno dell'Analisi 360
            let restaPartner = eCliente ? famiglia.contains(where: { partner.contains($0.relazione) })
                                        : partner.contains(persona.familiare?.relazione ?? .altro)
            let anniSostegno = max(dipendenti.map(\.anni).max() ?? 0, restaPartner ? analisi.anniSostegno : 0)

            // Debiti a suo carico: il cliente per la sua quota, il partner per la quota restante dei cointestati
            var quotaDebiti = 0.0
            var mesiDebiti: Int?
            for d in debiti {
                let delCliente = min(max(d.quotaDebito ?? 100, 0), 100) / 100
                let parte: Double
                if eCliente { parte = delCliente }
                else if partner.contains(persona.familiare?.relazione ?? .altro), d.quotaDebito != nil { parte = 1 - delCliente }
                else { parte = 0 }
                guard parte > 0 else { continue }
                quotaDebiti += max(0, d.valore) * parte
                if let m = d.mesiResidui(al: data) { mesiDebiti = max(mesiDebiti ?? 0, m) }
            }

            // Le coperture di cui è l'assicurato
            let sue = coperture.filter { MotoreProtezioneFamiglia.assicurato($0, cliente: cliente) == persona.id }
            let sueProposte = proposte.filter { MotoreProtezioneFamiglia.assicurato($0, cliente: cliente) == persona.id }
            func capitale(_ elenco: [Posizione], _ r: RischioCoperto) -> Double {
                elenco.filter { ($0.rischio ?? .altro) == r }.reduce(0) { $0 + MotoreProtezioneFamiglia.capitaleAttuale($1, al: data) }
            }
            for c in sue + sueProposte where c.assicuratoId == nil {
                avvisi.append(c.assicurato.isEmpty
                    ? "«\(c.nome)»: assicurato non indicato, attribuita al cliente."
                    : "«\(c.nome)»: assicurato riconosciuto dal nome; collega la persona nella posizione.")
            }

            // Invalidità: il reddito da sostituire fino alla pensione
            let etaPensione = (eCliente ? cliente.profilo.lavoro?.etaPensione : persona.familiare?.lavoro?.etaPensione) ?? ipotesi.etaPensione
            let anniAllaPensione = eta.map { max(0, etaPensione - $0) } ?? 0
            if eta == nil { avvisi.append("Data di nascita di \(persona.nome) mancante: invalidità non calcolata.") }
            let entrate = eCliente ? max(0, analisi.entrateSostitutive) * 12 : 0

            var esito = FabbisognoPersona(
                id: persona.id, nome: persona.nome, relazione: persona.familiare?.relazione, eta: eta,
                redditoNetto: persona.netto, redditoStimato: persona.stimato, quotaReddito: quota,
                debiti: quotaDebiti, mesiDebiti: mesiDebiti, speseImmediate: max(0, analisi.speseImmediate),
                sostegnoAnnuo: max(0, analisi.fabbisognoMensile) * 12 * quota, anniSostegno: anniSostegno, dipendenti: dipendenti,
                capitaleDisponibile: max(0, analisi.capitaleDisponibile),
                capitaleMorte: capitale(sue, .vita), capitaleMorteProposte: capitale(sueProposte, .vita),
                anniAllaPensione: anniAllaPensione, entrateSostitutive: entrate,
                capitaleInvalidita: capitale(sue, .invalidita), capitaleInvaliditaProposte: capitale(sueProposte, .invalidita),
                fabbisognoLTC: max(0, ipotesi.spesaAssistenzaMensile) * 12 * Double(max(0, ipotesi.anniAssistenza)),
                capitaleLTC: capitale(sue, .ltc), capitaleLTCProposte: capitale(sueProposte, .ltc),
                capitaleInfortuni: capitale(sue, .infortuni), coperture: sue, proposte: sueProposte, avvisi: avvisi)

            // Avvisi sulle cifre
            if esito.capitaleMorte == 0 && esito.fabbisognoMorte >= 1 && quota > 0 {
                esito.avvisi.append("Nessuna copertura caso morte su \(persona.nome), che porta il \(CifreDoc.percento(quota * 100, decimali: 0)) del reddito familiare.")
            }
            if let fine = Calendar.current.date(byAdding: .year, value: esito.anniCopertura, to: data) {
                for c in sue where c.rischio == .vita {
                    if let s = c.scadenza, s < fine {
                        esito.avvisi.append("\(c.nome) scade il \(CifreDoc.dataBreve(s)), prima dei \(esito.anniCopertura) anni che servono tra debiti e familiari a carico.")
                    }
                }
            }
            for c in sue where c.rischio == .vita && c.capitaleDecrescente == true {
                let oggiCapitale = MotoreProtezioneFamiglia.capitaleAttuale(c, al: data)
                if oggiCapitale + 0.5 < esito.debiti {
                    esito.avvisi.append("\(c.nome): capitale decrescente oggi di circa \(CifreDoc.euro(oggiCapitale)), sotto i debiti a carico (\(CifreDoc.euro(esito.debiti))).")
                }
            }
            return esito
        }
    }

    /// L'id della persona assicurata da una copertura: `assicuratoId` se è del cliente o di un familiare,
    /// altrimenti il nome scritto in `assicurato`, altrimenti il cliente (di solito contraente e assicurato).
    static func assicurato(_ p: Posizione, cliente: Cliente) -> String {
        if let id = p.assicuratoId, id == cliente.id || cliente.famiglia.contains(where: { $0.id == id }) { return id }
        let testo = normalizzato(p.assicurato)
        guard !testo.isEmpty else { return cliente.id }
        if normalizzato(cliente.nome) == testo { return cliente.id }
        if let f = cliente.famiglia.first(where: { normalizzato($0.nome) == testo }) { return f.id }
        if let f = cliente.famiglia.first(where: { x -> Bool in
            let n = normalizzato(x.nome)
            return !n.isEmpty && testo.contains(n)
        }) { return f.id }
        return cliente.id
    }

    /// Capitale assicurato alla data: per le coperture a capitale decrescente cala in linea retta dalla
    /// decorrenza alla scadenza (stima: il piano vero è nelle condizioni di polizza).
    static func capitaleAttuale(_ p: Posizione, al data: Date) -> Double {
        let capitale = max(0, p.capitaleAssicurato ?? 0)
        guard p.capitaleDecrescente == true, let inizio = p.decorrenza, let fine = p.scadenza else { return capitale }
        let totale = Calendar.current.dateComponents([.month], from: inizio, to: fine).month ?? 0
        guard totale > 0 else { return capitale }
        let residui = min(totale, max(0, p.mesiResidui(al: data) ?? 0))
        return capitale * Double(residui) / Double(totale)
    }

    /// Rata mensile di un finanziamento alla francese (capitale residuo, tasso annuo nominale %, mesi residui).
    static func rataDebito(capitale: Double, tasso: Double?, mesi: Int) -> Double {
        guard mesi > 0, capitale > 0 else { return 0 }
        let i = max(0, tasso ?? 0) / 100 / 12
        guard i > 0 else { return capitale / Double(mesi) }
        return capitale * i / (1 - pow(1 + i, -Double(mesi)))
    }

    /// Debito residuo dopo `dopo` mesi, con il piano alla francese (senza tasso: rimborso in quote uguali).
    static func debitoResiduo(capitale: Double, tasso: Double?, mesi: Int, dopo: Int) -> Double {
        guard mesi > 0, capitale > 0 else { return 0 }
        let k = min(max(dopo, 0), mesi)
        let i = max(0, tasso ?? 0) / 100 / 12
        guard i > 0 else { return capitale * Double(mesi - k) / Double(mesi) }
        let tutti = pow(1 + i, Double(mesi))
        let passati = pow(1 + i, Double(k))
        return capitale * (tutti - passati) / (tutti - 1)
    }

    /// Debito residuo a ogni anniversario da oggi (indice 0 = oggi) alla fine: per confrontarlo con il capitale
    /// delle coperture caso morte (costante o decrescente). Senza scadenza solo il valore di oggi.
    static func pianoDebito(_ d: Posizione, al data: Date = Date()) -> [Double] {
        let capitale = max(0, d.valore)
        guard let mesi = d.mesiResidui(al: data), mesi > 0 else { return [capitale] }
        let anni = (mesi + 11) / 12
        return (0...anni).map { MotoreProtezioneFamiglia.debitoResiduo(capitale: capitale, tasso: d.tassoDebito, mesi: mesi, dopo: $0 * 12) }
    }

    /// Minuscole e spazi semplici, per confrontare i nomi.
    private static func normalizzato(_ s: String) -> String {
        s.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
