import Foundation

/// Cosa si vuole stampare. I prospetti sono per il consulente (dettagliati, un tema alla volta);
/// la valutazione di un investimento ha anche il report da lasciare al cliente.
enum SceltaProspetto: Hashable {
    /// Resoconto delle posizioni in essere: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case resoconto(report: Bool)
    /// Sostituzione di una posizione in essere con un'alternativa (o confronto tra due proposte):
    /// prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case sostituzione(String, String, report: Bool)
    /// Piano previdenziale: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case previdenza(report: Bool)
    /// Una posizione o una proposta, in ogni dettaglio.
    case posizione(String)
    /// Due voci del dossier fianco a fianco.
    case confronto(VoceConfronto, VoceConfronto)
    /// Valutazione di un investimento: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case valutazione(String, report: Bool)

    var tipo: TipoProspetto {
        switch self {
        case .resoconto: return .resoconto
        case .sostituzione: return .sostituzione
        case .previdenza: return .previdenza
        case .posizione: return .posizione
        case .confronto: return .confronto
        case .valutazione: return .valutazione
        }
    }
}

enum TipoProspetto: String, CaseIterable, Identifiable {
    case valutazione, resoconto, sostituzione, previdenza, posizione, confronto

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .resoconto: return "Resoconto delle posizioni in essere"
        case .sostituzione: return "Sostituzione o confronto"
        case .previdenza: return "Piano previdenziale"
        case .posizione: return "Posizione o proposta"
        case .confronto: return "Confronto"
        case .valutazione: return "Valutazione di un investimento"
        }
    }

    var descrizione: String {
        switch self {
        case .sostituzione: return "Restare o cambiare: l'uscita di oggi con penali e imposte, il netto anno per anno delle due strade, il pareggio, tre scenari, costi e caratteristiche. Anche tra due proposte. Prospetto per te, report per il cliente."
        case .previdenza: return "Divario tra reddito desiderato e pensione pubblica, piani portati alla pensione con l'aliquota di allora, risparmio IRPEF dei versamenti, uscite anticipate, versamento che manca. Prospetto per te, report per il cliente."
        case .resoconto: return "Cosa ha il cliente e come sta andando: versato, valore, risultato e rendimento di ogni posizione, ultimi 12 mesi, tutele, debiti, scadenze e costi. Prospetto per te, report per il cliente."
        case .posizione: return "Contratto, costi, proiezione anno per anno nei tre scenari, fonti e pagine dei documenti."
        case .confronto: return "Ipotesi ed esiti a fronte, differenze anno per anno, peso dei costi."
        case .valutazione: return "Il cliente valuta un investimento: incassi netti anno per anno in tre scenari, penali, costi, imposte, confronto con il KID. Prospetto per te, report per il cliente."
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

    var genere: String { "Prospetto di dettaglio" }
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

extension BloccoProspetto {
    /// I titoli di sezione non devono restare soli in fondo alla pagina.
    var eTitolo: Bool {
        switch self {
        case .sezione: return true
        default: return false
        }
    }
}
