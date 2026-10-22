import Foundation

/// Un piano previdenziale (in essere o proposto) portato fino alla pensione.
struct PianoPrevidenza: Identifiable {
    let posizione: Posizione
    var id: String { posizione.id }
    var proposta: Bool { posizione.stato == .proposta }
    /// Anni di partecipazione oggi e alla pensione (contano dalla prima adesione a qualsiasi forma).
    let anniOggi: Int
    let anniAllaPensione: Int
    let valoreOggi: Double
    let versamentoAnnuo: Double
    /// Rendimento usato, al netto dell'imposta sui rendimenti dentro il fondo.
    let rendimentoNetto: Double
    /// Montante alla pensione, prima dell'imposta sulla prestazione.
    let montante: Double
    /// Contributi versati in tutto (passati e futuri) e la parte dedotta, che si tassa alla prestazione.
    let versatoTotale: Double
    let dedotti: Double
    let aliquota: Double
    let imposta: Double
    var netto: Double { montante - imposta }
    /// Netto in euro di oggi e rendita mensile che permette negli anni di integrazione.
    let nettoReale: Double
    let renditaMensile: Double
    let punti: [PuntoProiezione]
}

/// Il piano pensionistico del cliente: divario, piani, vantaggio fiscale, scenari.
struct EsitoPianoPrevidenziale {
    let eta: Int
    let etaPensione: Int
    var anniAccumulo: Int { max(0, etaPensione - eta) }
    let redditoDesiderato: Double
    let pensionePubblica: Double
    var divario: Double { max(0, redditoDesiderato - pensionePubblica) }
    let anniIntegrazione: Int
    let piani: [PianoPrevidenza]
    var inEssere: [PianoPrevidenza] { piani.filter { !$0.proposta } }
    var proposte: [PianoPrevidenza] { piani.filter(\.proposta) }

    var renditaInEssere: Double { inEssere.reduce(0) { $0 + $1.renditaMensile } }
    var renditaProposte: Double { proposte.reduce(0) { $0 + $1.renditaMensile } }
    var divarioResiduo: Double { max(0, divario - renditaInEssere) }
    var divarioConProposte: Double { max(0, divario - renditaInEssere - renditaProposte) }
    /// Versamento mensile in più che coprirebbe il divario che resta anche con le proposte.
    let versamentoMancante: Double?
    let rendimentoReale: Double

    // Fisco dei versamenti
    let reddito: Double?
    let aliquotaMarginale: Double?
    var contributiInEssere: Double { inEssere.reduce(0) { $0 + $1.versamentoAnnuo } }
    var contributiProposte: Double { proposte.reduce(0) { $0 + $1.versamentoAnnuo } }
    var deducibiliOggi: Double { min(RegoleFiscali.limiteDeducibilita, contributiInEssere) }
    var deducibiliConProposte: Double { min(RegoleFiscali.limiteDeducibilita, contributiInEssere + contributiProposte) }
    var risparmioOggi: Double { reddito.map { RegoleFiscali.risparmioDeduzione(reddito: $0, deduzione: deducibiliOggi) } ?? 0 }
    var risparmioConProposte: Double { reddito.map { RegoleFiscali.risparmioDeduzione(reddito: $0, deduzione: deducibiliConProposte) } ?? 0 }
    var spazioResiduo: Double { max(0, RegoleFiscali.limiteDeducibilita - contributiInEssere - contributiProposte) }
    /// IRPEF in più risparmiata usando tutto lo spazio che resta.
    var risparmioPossibile: Double {
        reddito.map { RegoleFiscali.risparmioDeduzione(reddito: $0, deduzione: RegoleFiscali.limiteDeducibilita) } .map { $0 - risparmioConProposte } ?? 0
    }
    /// Quanto costa davvero versare: contributi meno il risparmio d'imposta, al mese.
    var costoNettoMensile: Double { (contributiInEssere + contributiProposte - risparmioConProposte) / 12 }

    /// Montante complessivo anno per anno: solo i piani in essere e con le proposte.
    let serieInEssere: [Double]
    let serieConProposte: [Double]
    /// Rendita mensile complessiva con le proposte, con rendimenti più bassi, attesi o più alti.
    let scenari: [(nome: String, scarto: Double, rendita: Double)]
    let note: [String]
}

/// Calcoli del piano previdenziale. Importi mensili in euro di oggi, come nell'Analisi 360.
enum MotorePrevidenza {
    static func calcola(_ posizioni: [Posizione], cliente: Cliente?, analisi: IpotesiPrevidenza, data: Date = Date()) -> EsitoPianoPrevidenziale {
        let eta = cliente?.eta ?? analisi.eta
        let etaPensione = max(eta, analisi.etaPensione)
        let anni = max(0, etaPensione - eta)
        let mesi = Double(max(1, analisi.anniIntegrazione) * 12)
        var note: [String] = []

        let previdenza = posizioni.filter { $0.regime == .previdenza && $0.stato != .chiusa && !($0.stato == .proposta && $0.esito == .rifiutata) }
            .sorted { ($0.stato == .inEssere ? 0 : 1, $0.nome) < ($1.stato == .inEssere ? 0 : 1, $1.nome) }
        let inEssere = previdenza.filter { $0.stato == .inEssere }
        // La partecipazione conta dalla prima adesione a qualsiasi forma complementare
        let anniGia = inEssere.map { MotoreFiscale.anniPartecipazione($0, data: data) }.max() ?? 0
        let contributiTotali = previdenza.reduce(0) { $0 + $1.premioAnnuo }
        let quotaDedotta = contributiTotali > RegoleFiscali.limiteDeducibilita ? RegoleFiscali.limiteDeducibilita / contributiTotali : 1
        if quotaDedotta < 1 {
            note.append("I versamenti superano il limite di deducibilità di \(CifreDoc.euroCentesimi(RegoleFiscali.limiteDeducibilita)) l'anno: la parte in eccesso non si deduce e non si tassa alla prestazione.")
        }

        func piano(_ p: Posizione, scarto: Double) -> PianoPrevidenza {
            let lordo = (p.rendimentoAtteso ?? IpotesiCalcolo.rendimentoPredefinito) + scarto
            // I rendimenti si tassano ogni anno dentro il fondo, sul risultato al netto dei costi
            let netto = RegoleFiscali.rendimentoNettoPrevidenza(lordo: lordo, costo: p.costoComplessivo ?? 0)
            let inEssere = p.stato == .inEssere
            let capitale = inEssere ? p.valore : p.versamentoIniziale
            let par = ParametriProiezione(capitaleIniziale: capitale, versamento: p.premio, frequenza: p.frequenza, anni: anni,
                                          rendimento: netto, costoIngresso: p.costoIngresso ?? 0, costoAnnuo: 0,
                                          aliquotaFiscale: 0, inflazione: 0, ingressoSulCapitale: !inEssere)
            let e = MotoreProiezione.calcola(par)
            let gia = inEssere ? MotoreFiscale.anniPartecipazione(p, data: data) : anniGia
            let versatoPassato = inEssere ? (p.totaleVersato ?? p.versamentoIniziale) : 0
            let futuri = e.versato - (inEssere ? capitale : 0)
            let dedottiPassati = max(0, versatoPassato - (p.contributiNonDedotti ?? 0))
            let dedotti = min(e.lordo, dedottiPassati + futuri * quotaDedotta)
            let aliquota = RegoleFiscali.aliquotaPrevidenza(anni: gia + anni)
            let imposta = MotoreFiscale.centesimi(max(0, dedotti) * aliquota / 100)
            let reale = (e.lordo - imposta) / pow(1 + IpotesiCalcolo.inflazione / 100, Double(anni))
            return PianoPrevidenza(posizione: p, anniOggi: gia, anniAllaPensione: gia + anni, valoreOggi: capitale,
                                   versamentoAnnuo: p.premioAnnuo, rendimentoNetto: netto, montante: e.lordo,
                                   versatoTotale: versatoPassato + futuri, dedotti: dedotti, aliquota: aliquota, imposta: imposta,
                                   nettoReale: reale, renditaMensile: reale / mesi, punti: e.punti)
        }

        let piani = previdenza.map { piano($0, scarto: 0) }
        func serie(_ elenco: [PianoPrevidenza]) -> [Double] {
            (0...anni).map { y in elenco.reduce(0) { $0 + ($1.punti[min(y, $1.punti.count - 1)].valore) } }
        }
        let ampiezza = IpotesiCalcolo.ampiezzaScenari
        let scenari = [("Prudente", -ampiezza), ("Atteso", 0.0), ("Favorevole", ampiezza)].map { voce -> (nome: String, scarto: Double, rendita: Double) in
            let (nome, scarto) = voce
            let elenco = scarto == 0 ? piani : previdenza.map { piano($0, scarto: scarto) }
            return (nome, scarto, elenco.reduce(0) { $0 + $1.renditaMensile })
        }

        // Quanto servirebbe in più, al mese, per coprire il divario che resta
        let divario = max(0, analisi.redditoDesiderato - analisi.pensionePubblica)
        let coperto = piani.reduce(0) { $0 + $1.renditaMensile }
        let resta = max(0, divario - coperto)
        var mancante: Double?
        if resta > 0.5 && anni > 0 {
            let par = ParametriProiezione(capitaleIniziale: 0, versamento: 0, frequenza: .mensile, anni: anni,
                                          rendimento: analisi.rendimentoReale, aliquotaFiscale: 0, inflazione: 0)
            mancante = MotoreAnalisi.versamentoNecessario(par, obiettivo: resta * mesi)
        } else if resta > 0.5 {
            note.append("La pensione è già raggiunta: non c'è più tempo per accumulare.")
        }

        let reddito = cliente?.profilo.redditoLordoAnnuo
        if reddito == nil { note.append("Reddito lordo annuo non indicato nel profilo: il risparmio d'imposta non si può calcolare.") }
        if piani.contains(where: { $0.posizione.contributiNonDedotti == nil && !$0.proposta }) {
            note.append("Dove non sono indicati i contributi non dedotti si considerano tutti dedotti.")
        }
        note.append("Rendimenti dei piani al netto dell'imposta del \(CifreDoc.condizione(RegoleFiscali.previdenzaRendimenti)) che il fondo paga ogni anno; importi riportati in euro di oggi con un'inflazione del \(CifreDoc.condizione(IpotesiCalcolo.inflazione)) annuo.")
        note.append("Rendita indicativa: il netto alla pensione diviso per \(analisi.anniIntegrazione) anni di integrazione, senza rivalutazione; la rendita vera dipende dai coefficienti di conversione del piano.")

        return EsitoPianoPrevidenziale(
            eta: eta, etaPensione: etaPensione, redditoDesiderato: analisi.redditoDesiderato, pensionePubblica: analisi.pensionePubblica,
            anniIntegrazione: analisi.anniIntegrazione, piani: piani, versamentoMancante: mancante, rendimentoReale: analisi.rendimentoReale,
            reddito: reddito, aliquotaMarginale: reddito.map { RegoleFiscali.aliquotaMarginale(reddito: $0) },
            serieInEssere: serie(piani.filter { !$0.proposta }), serieConProposte: serie(piani),
            scenari: scenari, note: note)
    }
}
