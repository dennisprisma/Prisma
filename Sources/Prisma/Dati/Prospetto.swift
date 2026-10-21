import Foundation

/// Cosa si vuole stampare: i prospetti sono per il consulente (dettagliati, un tema alla volta),
/// i report per il cliente (essenziali e leggibili, nella fase successiva).
enum SceltaProspetto: Hashable {
    /// Tutte le posizioni del cliente, in essere e in proposta.
    case quadro
    /// Una posizione o una proposta, in ogni dettaglio.
    case posizione(String)
    /// Due voci del dossier fianco a fianco.
    case confronto(VoceConfronto, VoceConfronto)
    /// Report per il cliente: la sua situazione, i suoi progetti, i prossimi passi.
    case reportQuadro
    /// Report per il cliente: una proposta spiegata in parole semplici.
    case reportProposta(String)

    var tipo: TipoProspetto {
        switch self {
        case .quadro: return .quadro
        case .posizione: return .posizione
        case .confronto: return .confronto
        case .reportQuadro: return .reportQuadro
        case .reportProposta: return .reportProposta
        }
    }
}

enum TipoProspetto: String, CaseIterable, Identifiable {
    case quadro, posizione, confronto, reportQuadro, reportProposta

    var id: String { rawValue }

    /// I report si consegnano al cliente; i prospetti sono il dettaglio per il consulente.
    var perCliente: Bool { self == .reportQuadro || self == .reportProposta }

    var nome: String {
        switch self {
        case .quadro: return "Quadro delle posizioni"
        case .posizione: return "Posizione o proposta"
        case .confronto: return "Confronto"
        case .reportQuadro: return "Il quadro del cliente"
        case .reportProposta: return "Una proposta"
        }
    }

    var descrizione: String {
        switch self {
        case .quadro: return "Patrimonio, canali, aree, ogni posizione, coperture, proposte, scadenze e obiettivi."
        case .posizione: return "Contratto, costi, proiezione anno per anno nei tre scenari, fonti e pagine dei documenti."
        case .confronto: return "Ipotesi ed esiti a fronte, differenze anno per anno, peso dei costi."
        case .reportQuadro: return "Le sue priorità, il punto di partenza, i progetti e i prossimi passi. Poche cifre, scritte grandi."
        case .reportProposta: return "Che cos'è, a che cosa serve, quanto si versa, cosa può diventare, costi e rischio in parole semplici."
        }
    }
}

/// Il contenuto di un prospetto, già calcolato: l'impaginazione lo divide in pagine A4.
struct ContenutoProspetto {
    var occhiello: String
    var titolo: String
    var sottotitolo: String
    var cliente: String
    var data = Date()
    /// Canale in evidenza nell'intestazione (nil se il prospetto riguarda entrambi).
    var canale: Canale?
    /// Secondo canale, per i confronti tra Alleanza e indipendente.
    var canaleSecondo: Canale?
    /// true per i report da consegnare al cliente.
    var perCliente = false
    var blocchi: [BloccoProspetto]

    var genere: String { perCliente ? "Report per il cliente" : "Prospetto di dettaglio" }
}

/// Una barra orizzontale dei report (ripartizioni, avanzamento degli obiettivi).
struct BarraProspetto: Hashable {
    var etichetta: String
    var valore: String
    /// Riempimento 0–1.
    var quota: Double
    var nota = ""
    var canale: Canale? = nil
}

/// Una cella di tabella. Il canale si stampa come etichetta (blu Alleanza, cuoio indipendente).
struct CellaProspetto: Hashable {
    var testo: String
    var canale: Canale?
    var forte = false
    var tenue = false

    static func t(_ s: String) -> CellaProspetto { CellaProspetto(testo: s) }
    static func f(_ s: String) -> CellaProspetto { CellaProspetto(testo: s, forte: true) }
    static func n(_ s: String) -> CellaProspetto { CellaProspetto(testo: s, tenue: true) }
    static func c(_ canale: Canale) -> CellaProspetto { CellaProspetto(testo: canale.nomeBreve, canale: canale) }
}

struct ColonnaProspetto: Hashable {
    var titolo: String
    /// Peso relativo della larghezza.
    var peso: Double = 1
    var destra = false
}

struct TabellaProspetto: Hashable {
    var colonne: [ColonnaProspetto]
    var righe: [[CellaProspetto]]
    /// Riga finale in grassetto (totali), ripetuta solo nell'ultima parte.
    var totale: [CellaProspetto]?
    /// Righe da evidenziare (per esempio l'anno della scadenza).
    var evidenzia: Set<Int> = []
}

struct IndicatoreProspetto: Hashable {
    var etichetta: String
    var valore: String
    var nota = ""
}

struct SerieGraficoProspetto: Hashable {
    enum Tono: String { case prudente, atteso, favorevole, primo, secondo }
    var nome: String
    var tono: Tono
    var punti: [PuntoProiezione]
}

extension PuntoProiezione: Hashable {
    func hash(into h: inout Hasher) {
        h.combine(anno)
        h.combine(versato)
        h.combine(valore)
    }
}

enum BloccoProspetto: Hashable {
    /// Titolo di sezione numerato ("01 · Dati del contratto").
    case sezione(numero: String, titolo: String)
    case indicatori([IndicatoreProspetto])
    /// Coppie etichetta e valore, su due colonne.
    case voci([CampoVoce])
    case tabella(TabellaProspetto)
    case grafico([SerieGraficoProspetto])
    case testo(String)
    /// Riquadro di avvertenza (ipotesi predefinite, dati mancanti).
    case avviso(String)
    /// Metodo di calcolo e avvertenze finali, in corpo piccolo.
    case nota(String)

    // Blocchi dei report per il cliente: caratteri grandi, poche cose per volta.
    /// Titolo di capitolo, come le slide del template ("Prima dei numeri, ci sei tu.").
    case capitolo(numero: String, titolo: String)
    /// Paragrafo in corpo grande.
    case paragrafo(String)
    /// Due, tre o quattro cifre in evidenza.
    case cifre([IndicatoreProspetto])
    case barre([BarraProspetto])
    /// Scala del rischio da 1 a 7 (SRI del KID).
    case rischio(Int)
    /// Elenco puntato in corpo grande.
    case punti([String])
    /// Chiusura con il nome del consulente e i canali.
    case firma(nome: String, canali: [Canale])
}

struct CampoVoce: Hashable {
    var etichetta: String
    var valore: String
    var canale: Canale? = nil
}

extension BloccoProspetto {
    /// Titoli di sezione e di capitolo: non devono restare soli in fondo alla pagina.
    var eTitolo: Bool {
        switch self {
        case .sezione, .capitolo: return true
        default: return false
        }
    }
}
