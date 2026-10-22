import Foundation

/// Uno scenario salvato del simulatore, nel dossier del cliente.
struct Simulazione: Identifiable, Codable, Hashable {
    var id = "sim-\(UUID().uuidString.prefix(8).lowercased())"
    var clienteId: String
    var titolo: String
    var creataIl = Date()
    var capitale: Double = 10_000
    var versamentoMensile: Double = 100
    var anni = 10
    var rendimento = IpotesiCalcolo.rendimentoPredefinito
    var costoIngresso: Double = 0
    var costoAnnuo: Double = 0
    var aliquota = IpotesiCalcolo.aliquotaPredefinita
    var inflazione = IpotesiCalcolo.inflazione
    /// Canale su cui si ragiona (nil = non indicato).
    var canale: Canale?
    /// Posizione da cui è partita l'ipotesi.
    var posizioneId: String?

    init(clienteId: String, titolo: String) {
        self.clienteId = clienteId
        self.titolo = titolo
    }

    /// Ipotesi ricavata da una posizione (stessi dati della sua proiezione).
    init(posizione p: Posizione, orizzonteCliente: Int?) {
        let q = ParametriProiezione(posizione: p, orizzonteCliente: orizzonteCliente)
        clienteId = p.clienteId
        titolo = p.nome
        capitale = q.capitaleIniziale
        versamentoMensile = (p.premioAnnuo / 12).rounded()
        anni = q.anni
        rendimento = q.rendimento
        costoIngresso = q.costoIngresso
        costoAnnuo = q.costoAnnuo
        aliquota = q.aliquotaFiscale
        canale = p.canale
        posizioneId = p.id
    }

    var parametri: ParametriProiezione {
        ParametriProiezione(capitaleIniziale: capitale, versamento: versamentoMensile, frequenza: .mensile, anni: anni,
                            rendimento: rendimento, costoIngresso: costoIngresso, costoAnnuo: costoAnnuo,
                            aliquotaFiscale: aliquota, inflazione: inflazione)
    }

    /// Stessi numeri (per capire se il simulatore è cambiato rispetto allo scenario salvato).
    func stesseIpotesi(_ o: Simulazione) -> Bool {
        capitale == o.capitale && versamentoMensile == o.versamentoMensile && anni == o.anni && rendimento == o.rendimento
            && costoIngresso == o.costoIngresso && costoAnnuo == o.costoAnnuo && aliquota == o.aliquota
            && inflazione == o.inflazione && canale == o.canale
    }

    private enum CodingKeys: String, CodingKey {
        case id, clienteId, titolo, creataIl, capitale, versamentoMensile, anni, rendimento, costoIngresso, costoAnnuo
        case aliquota, inflazione, canale, posizioneId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        clienteId = try c.decode(String.self, forKey: .clienteId)
        titolo = try c.decodeIfPresent(String.self, forKey: .titolo) ?? "Scenario"
        creataIl = try c.decodeIfPresent(Date.self, forKey: .creataIl) ?? Date()
        capitale = try c.decodeIfPresent(Double.self, forKey: .capitale) ?? 0
        versamentoMensile = try c.decodeIfPresent(Double.self, forKey: .versamentoMensile) ?? 0
        anni = try c.decodeIfPresent(Int.self, forKey: .anni) ?? 10
        rendimento = try c.decodeIfPresent(Double.self, forKey: .rendimento) ?? IpotesiCalcolo.rendimentoPredefinito
        costoIngresso = try c.decodeIfPresent(Double.self, forKey: .costoIngresso) ?? 0
        costoAnnuo = try c.decodeIfPresent(Double.self, forKey: .costoAnnuo) ?? 0
        aliquota = try c.decodeIfPresent(Double.self, forKey: .aliquota) ?? IpotesiCalcolo.aliquotaPredefinita
        inflazione = try c.decodeIfPresent(Double.self, forKey: .inflazione) ?? IpotesiCalcolo.inflazione
        canale = try c.decodeIfPresent(Canale.self, forKey: .canale)
        posizioneId = try c.decodeIfPresent(String.self, forKey: .posizioneId)
    }
}

// MARK: - Analisi 360

/// Le quattro aree dell'Analisi 360.
enum AreaAnalisi: String, Codable, CaseIterable, Identifiable {
    case previdenza, protezione, investimenti, risparmio

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .previdenza: return "Previdenza"
        case .protezione: return "Protezione"
        case .investimenti: return "Investimenti"
        case .risparmio: return "Risparmio"
        }
    }

    var numero: String {
        switch self {
        case .previdenza: return "01"
        case .protezione: return "02"
        case .investimenti: return "03"
        case .risparmio: return "04"
        }
    }

    /// Area delle posizioni da cui si ricavano i dati.
    var areaPosizioni: AreaPosizione {
        switch self {
        case .previdenza: return .previdenza
        case .protezione: return .protezione
        case .investimenti: return .investimento
        case .risparmio: return .risparmio
        }
    }
}

/// Ipotesi di previdenza (importi mensili netti in euro di oggi).
struct IpotesiPrevidenza: Codable, Equatable {
    var eta = 40
    var etaPensione = 67
    var redditoDesiderato: Double = 2_200
    var pensionePubblica: Double = 1_400
    /// Montante già accumulato nei piani previdenziali.
    var capitale: Double = 0
    var versamentoMensile: Double = 0
    /// Rendimento annuo netto reale (già al netto di costi, imposte e inflazione).
    var rendimentoReale = 1.5
    var anniIntegrazione = 25
}

/// Ipotesi di protezione del nucleo. Le coperture si leggono dalle posizioni.
struct IpotesiProtezione: Codable, Equatable {
    var fabbisognoMensile: Double = 1_800
    var anniSostegno = 10
    var debiti: Double = 0
    var speseImmediate: Double = 15_000
    var capitaleDisponibile: Double = 10_000
    var entrateSostitutive: Double = 600
    var mesiRiserva = 12
    var riserva: Double = 5_000
}

/// Ipotesi di investimento (stesso modello delle posizioni).
struct IpotesiInvestimento: Codable, Equatable {
    var capitale: Double = 20_000
    var versamentoMensile: Double = 0
    var anni = 10
    var rendimento = 4.0
    var costoIngresso = 0.0
    var costoAnnuo = 1.0
    var aliquota = IpotesiCalcolo.aliquotaPredefinita
    var inflazione = IpotesiCalcolo.inflazione
    /// Calo improvviso dei mercati da mettere alla prova, in percentuale.
    var calo = 20.0

    var parametri: ParametriProiezione {
        ParametriProiezione(capitaleIniziale: capitale, versamento: versamentoMensile, frequenza: .mensile, anni: anni,
                            rendimento: rendimento, costoIngresso: costoIngresso, costoAnnuo: costoAnnuo,
                            aliquotaFiscale: aliquota, inflazione: inflazione)
    }
}

/// Ipotesi di risparmio per un obiettivo (in euro di oggi).
struct IpotesiRisparmio: Codable, Equatable {
    var obiettivo: Double = 50_000
    var capitale: Double = 5_000
    var versamentoMensile: Double = 250
    var anni = 10
    var rendimento = 3.0
    var costoIngresso = 0.0
    var costoAnnuo = 1.0
    var aliquota = IpotesiCalcolo.aliquotaPredefinita
    var inflazione = IpotesiCalcolo.inflazione

    var parametri: ParametriProiezione {
        ParametriProiezione(capitaleIniziale: capitale, versamento: versamentoMensile, frequenza: .mensile, anni: anni,
                            rendimento: rendimento, costoIngresso: costoIngresso, costoAnnuo: costoAnnuo,
                            aliquotaFiscale: aliquota, inflazione: inflazione)
    }
}

/// L'Analisi 360 di un cliente: le ipotesi delle quattro aree.
struct Analisi360: Codable, Equatable {
    var previdenza = IpotesiPrevidenza()
    var protezione = IpotesiProtezione()
    var investimenti = IpotesiInvestimento()
    var risparmio = IpotesiRisparmio()
    /// Aree confermate con il cliente (le altre sono ipotesi da verificare).
    var confermate: [AreaAnalisi] = []
    var note = ""
    var aggiornataIl: Date?

    init() {}

    /// Prima stesura ricavata dalle posizioni in essere e dall'anagrafica del cliente.
    init(cliente: Cliente?, posizioni: [Posizione]) {
        let inEssere = posizioni.filter { $0.stato == .inEssere }
        func dell(_ a: AreaPosizione) -> [Posizione] { inEssere.filter { $0.area == a } }
        func mensile(_ elenco: [Posizione]) -> Double { (elenco.reduce(0) { $0 + $1.premioAnnuo } / 12).rounded() }
        func media(_ elenco: [Posizione], _ valore: (Posizione) -> Double?) -> Double? {
            let pesati = elenco.compactMap { p in valore(p).map { ($0, max(p.valore, 1)) } }
            let peso = pesati.reduce(0) { $0 + $1.1 }
            guard peso > 0 else { return nil }
            return (pesati.reduce(0) { $0 + $1.0 * $1.1 } / peso * 10).rounded() / 10
        }

        if let eta = cliente?.eta { previdenza.eta = eta }
        previdenza.etaPensione = max(previdenza.eta, previdenza.etaPensione)
        let prev = dell(.previdenza)
        previdenza.capitale = prev.reduce(0) { $0 + $1.valore }
        previdenza.versamentoMensile = mensile(prev)

        protezione.debiti = dell(.debiti).reduce(0) { $0 + $1.valore }
        let liquidita = dell(.liquidita).reduce(0) { $0 + $1.valore }
        // Metà della liquidità resta ai superstiti, l'altra metà fa da riserva (da rivedere con il cliente).
        protezione.capitaleDisponibile = (liquidita / 2).rounded()
        protezione.riserva = (liquidita / 2).rounded()

        let inv = dell(.investimento)
        investimenti.capitale = inv.reduce(0) { $0 + $1.valore }
        investimenti.versamentoMensile = mensile(inv)
        if let r = media(inv, \.rendimentoAtteso) { investimenti.rendimento = r }
        if let c = media(inv, \.costoComplessivo) { investimenti.costoAnnuo = c }
        if let h = cliente?.profilo.orizzonteAnni { investimenti.anni = h }

        let ris = dell(.risparmio)
        risparmio.capitale = ris.reduce(0) { $0 + $1.valore }
        risparmio.versamentoMensile = mensile(ris)
        if let r = media(ris, \.rendimentoAtteso) { risparmio.rendimento = r }
        if let c = media(ris, \.costoComplessivo) { risparmio.costoAnnuo = c }
    }

    private enum CodingKeys: String, CodingKey {
        case previdenza, protezione, investimenti, risparmio, confermate, note, aggiornataIl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        previdenza = (try? c.decodeIfPresent(IpotesiPrevidenza.self, forKey: .previdenza)) ?? IpotesiPrevidenza()
        protezione = (try? c.decodeIfPresent(IpotesiProtezione.self, forKey: .protezione)) ?? IpotesiProtezione()
        investimenti = (try? c.decodeIfPresent(IpotesiInvestimento.self, forKey: .investimenti)) ?? IpotesiInvestimento()
        risparmio = (try? c.decodeIfPresent(IpotesiRisparmio.self, forKey: .risparmio)) ?? IpotesiRisparmio()
        confermate = try c.decodeIfPresent([AreaAnalisi].self, forKey: .confermate) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        aggiornataIl = try c.decodeIfPresent(Date.self, forKey: .aggiornataIl)
    }
}
