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
    /// Protezione della famiglia: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case protezione(report: Bool)
    /// Piano per un obiettivo del cliente: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case obiettivo(String, report: Bool)
    /// Capitale in scadenza e liquidità: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case liquidita(report: Bool)
    /// Check-up del primo incontro: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case checkUp(report: Bool)
    /// Prova di resistenza del patrimonio: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case resistenza(report: Bool)
    /// Il costo degli investimenti: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case costi(report: Bool)
    /// Il passaggio generazionale: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case successione(report: Bool)
    /// Una posizione o una proposta, in ogni dettaglio.
    case posizione(String)
    /// Due voci del dossier fianco a fianco.
    case confronto(VoceConfronto, VoceConfronto)
    /// Valutazione di un investimento: prospetto (A4 verticale) o report per il cliente (A4 orizzontale).
    case valutazione(String, report: Bool)
    /// Il portafoglio del consulente: tutti i clienti insieme (solo prospetto, per te).
    case portafoglio
    /// Il riesame annuale del cliente: preparazione dell'incontro di revisione (solo prospetto, per te).
    case riesame

    var tipo: TipoProspetto {
        switch self {
        case .resoconto: return .resoconto
        case .sostituzione: return .sostituzione
        case .previdenza: return .previdenza
        case .protezione: return .protezione
        case .obiettivo: return .obiettivo
        case .liquidita: return .liquidita
        case .checkUp: return .checkUp
        case .resistenza: return .resistenza
        case .costi: return .costi
        case .successione: return .successione
        case .posizione: return .posizione
        case .confronto: return .confronto
        case .valutazione: return .valutazione
        case .portafoglio: return .portafoglio
        case .riesame: return .riesame
        }
    }
}

enum TipoProspetto: String, CaseIterable, Identifiable {
    case valutazione, resoconto, sostituzione, previdenza, protezione, obiettivo, liquidita, checkUp, resistenza, costi, successione, posizione, confronto, portafoglio, riesame

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .resoconto: return "Resoconto delle posizioni in essere"
        case .sostituzione: return "Sostituzione o confronto"
        case .previdenza: return "Piano previdenziale"
        case .protezione: return "Protezione della famiglia"
        case .obiettivo: return "Piano obiettivo"
        case .liquidita: return "Capitale in scadenza e liquidità"
        case .checkUp: return "Check-up primo incontro"
        case .resistenza: return "Prova di resistenza"
        case .costi: return "Il costo degli investimenti"
        case .successione: return "Passaggio generazionale"
        case .posizione: return "Posizione o proposta"
        case .confronto: return "Confronto"
        case .valutazione: return "Valutazione di un investimento"
        case .portafoglio: return "Il tuo portafoglio"
        case .riesame: return "Riesame annuale"
        }
    }

    var descrizione: String {
        switch self {
        case .sostituzione: return "Restare o cambiare: l'uscita di oggi con penali e imposte, il netto anno per anno delle due strade, il pareggio, tre scenari, costi e caratteristiche. Anche tra due proposte. Prospetto per te, report per il cliente."
        case .previdenza: return "Divario tra reddito desiderato e pensione pubblica, piani portati alla pensione con l'aliquota di allora, risparmio IRPEF dei versamenti, uscite anticipate, versamento che manca. Prospetto per te, report per il cliente."
        case .protezione: return "Fabbisogno caso morte e divario, invalidità e riserva, mappa dei rischi coperti e scoperti, coperture per canale, premi e detrazione del 19%. Prospetto per te, report per il cliente."
        case .obiettivo: return "Un obiettivo del cliente: importo rivalutato alla scadenza, posizioni collegate portate a quella data, quota raggiunta, quattro strade per arrivarci, scenari, quadro di tutti gli obiettivi. Prospetto per te, report per il cliente."
        case .liquidita: return "Capitali in scadenza nei prossimi 12 mesi al netto delle imposte, liquidità, riserva di emergenza, quattro salvadanai per orizzonte legati agli obiettivi, costo di lasciare fermi i soldi. Prospetto per te, report per il cliente."
        case .checkUp: return "Chi è il cliente, la fotografia del patrimonio, il semaforo di sette aree (riserva, famiglia, invalidità, pensione, risparmi, debiti, obiettivi), i bisogni rilevati e da dove partire. Prospetto per te, report per il cliente."
        case .successione: return "Se mancasse oggi, senza testamento: cosa va ai beneficiari (polizze, coperture, previdenza) e cosa agli eredi, con quali tempi, le quote, le imposte e cosa sistemare (beneficiari, convivente, minorenni). Prospetto per te, report per il cliente."
        case .costi: return "Quanto costano le posizioni finanziarie: costo annuo e d'ingresso, costi di quest'anno, quanto tolgono in 10 e 20 anni con il grafico con e senza costi, cosa offrono in cambio, alternative a parità di rischio. Prospetto per te, report per il cliente."
        case .resistenza: return "Il patrimonio in tre anni difficili: mercati in forte calo secondo l'indicatore di rischio, inflazione alta per tre anni, immobili in calo; la perdita confrontata con quella che il profilo sopporta e la parte al riparo. Prospetto per te, report per il cliente."
        case .resoconto: return "Cosa ha il cliente e come sta andando: versato, valore, risultato e rendimento di ogni posizione, ultimi 12 mesi, tutele, debiti, scadenze e costi. Prospetto per te, report per il cliente."
        case .posizione: return "Contratto, costi, proiezione anno per anno nei tre scenari, fonti e pagine dei documenti."
        case .confronto: return "Ipotesi ed esiti a fronte, differenze anno per anno, peso dei costi."
        case .valutazione: return "Il cliente valuta un investimento: incassi netti anno per anno in tre scenari, penali, costi, imposte, confronto con il KID. Prospetto per te, report per il cliente."
        case .portafoglio: return "Tutti i clienti insieme: patrimonio seguito per canale e per area, clienti dal più seguito, scadenze dei prossimi 12 mesi, concentrazione per emittente, proposte per esito. Solo per te."
        case .riesame: return "Per preparare l'incontro di revisione: ordine del giorno, com'è andata ogni posizione rispetto all'atteso, scadenze, obiettivi, aree del check-up, proposte aperte e domande da fare. Per te, con l'incontro da fissare."
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

/// Il commento del consulente in un report per il cliente: Eve scrive la bozza dalle cifre del
/// documento, il consulente la rilegge e la modifica. Compare nella pagina dopo la copertina.
struct CommentoReport: Codable, Equatable, Identifiable {
    /// Chiave del documento (vedi `SceltaProspetto.chiaveCommento`).
    var id: String
    var clienteId: String
    var testo: String
    /// Chi ha scritto la prima stesura ("Modello Apple", "Sintesi dai dati"); nil se scritto a mano.
    var bozzaDi: String?
    var aggiornatoIl = Date()
}

extension SceltaProspetto {
    /// true per i report dei documenti di analisi, che possono avere il commento del consulente.
    var conCommento: Bool {
        switch self {
        case .resoconto(let r), .previdenza(let r), .protezione(let r), .liquidita(let r), .checkUp(let r), .resistenza(let r), .costi(let r), .successione(let r): return r
        case .sostituzione(_, _, let r), .obiettivo(_, let r): return r
        case .posizione, .confronto, .valutazione, .portafoglio, .riesame: return false
        }
    }

    /// Dove si conserva il commento: lo stesso documento, per lo stesso cliente, ritrova il suo testo.
    func chiaveCommento(cliente: String) -> String? {
        switch self {
        case .resoconto: return "resoconto·\(cliente)"
        case .previdenza: return "previdenza·\(cliente)"
        case .protezione: return "protezione·\(cliente)"
        case .liquidita: return "liquidita·\(cliente)"
        case .checkUp: return "checkUp·\(cliente)"
        case .resistenza: return "resistenza·\(cliente)"
        case .costi: return "costi·\(cliente)"
        case .successione: return "successione·\(cliente)"
        case .sostituzione(let a, let b, _): return a.isEmpty || b.isEmpty ? nil : "sostituzione·\(a)·\(b)"
        case .obiettivo(let id, _): return id.isEmpty ? nil : "obiettivo·\(id)"
        case .posizione, .confronto, .valutazione, .portafoglio, .riesame: return nil
        }
    }
}
