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

    var tipo: TipoProspetto {
        switch self {
        case .quadro: return .quadro
        case .posizione: return .posizione
        case .confronto: return .confronto
        }
    }
}

enum TipoProspetto: String, CaseIterable, Identifiable {
    case quadro, posizione, confronto

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .quadro: return "Quadro delle posizioni"
        case .posizione: return "Posizione o proposta"
        case .confronto: return "Confronto"
        }
    }

    var descrizione: String {
        switch self {
        case .quadro: return "Patrimonio, canali, aree, ogni posizione, coperture, proposte, scadenze e obiettivi."
        case .posizione: return "Contratto, costi, proiezione anno per anno nei tre scenari, fonti e pagine dei documenti."
        case .confronto: return "Ipotesi ed esiti a fronte, differenze anno per anno, peso dei costi."
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
    var blocchi: [BloccoProspetto]
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
}

struct CampoVoce: Hashable {
    var etichetta: String
    var valore: String
    var canale: Canale? = nil
}
