import Combine
import Foundation

// La mini finestra di Eve (Design/eve-mini.html): Eve compare sopra quello che stai facendo, ascolta, pensa
// guardando il cliente e l'app aperti, poi risponde con le cifre di Prisma e il passo successivo.
// Qui ci sono solo lo stato e i calcoli (uguali su ogni piattaforma, provati da `--prova-eve`); il pannello,
// la scorciatoia ⌥ Spazio e il disegno sono solo sul Mac (Shell/MiniEve*.swift).

/// I cinque stati della mini finestra.
enum FaseMiniEve: String, CaseIterable {
    /// Ti ascolta: capsula con la sfera, la frase che si scrive e l'onda della voce.
    case ascolta
    /// Pensa: capsula con i passi («Apro il dossier di Giulia…») e la domanda sotto.
    case pensa
    /// Risponde: la scheda con la risposta, le cifre di Prisma, la fonte e i pulsanti.
    case risponde
    /// Pronta per scrivere: la scheda con il campo, gli spunti e le domande recenti.
    case scrivi
    /// Qwen non è pronto: «Mi sto svegliando…», nessuna risposta inventata.
    case nonPronta

    /// Capsula (440 × 72) o scheda (460, alta quanto serve).
    var capsula: Bool { self == .ascolta || self == .pensa || self == .nonPronta }
}

/// Da dove parte Eve: il cliente e l'app aperti (il gettone che si può togliere).
struct ContestoMiniEve: Equatable {
    var clienteId: String
    var nome: String
    var iniziali: String
    var tinta: TintaAvatar
    /// L'app in primo piano («Posizioni»), se ce n'è una.
    var app: String?
}

/// Una riga della risposta: una posizione con il suo canale e la cifra calcolata da Prisma.
struct RigaMiniEve: Identifiable, Equatable {
    var id: String
    var titolo: String
    var sotto: String
    var canale: Canale
    var importo: Double
    var valore: String
    var data: Date?
}

/// La linea del tempo delle scadenze (prossimi 12 mesi).
struct LineaTempoMiniEve: Equatable {
    var titolo: String
    var totale: String
    /// Il primo giorno del mese corrente: la linea parte da qui («oggi» è il puntino).
    var inizio: Date
    var oggi: Date
    /// Le scadenze, con la loro posizione nei mesi (0…12).
    var punti: [Punto]
    /// Un obiettivo oltre l'orizzonte («casa 2029 →»).
    var oltre: String?

    struct Punto: Equatable {
        var mesi: Double
        var importo: Double
        var canale: Canale
        var etichetta: String
        var giorno: String
    }
}

/// Un pulsante della risposta: porta in un'app di Prisma e chiude la mini finestra.
struct AzioneMiniEve: Identifiable, Equatable {
    enum Tipo: Equatable {
        case posizioni
        case agenda
        case prospetto(SceltaProspetto)
        case azioneEve(AzioneEve)
    }

    var titolo: String
    /// Simbolo SF.
    var simbolo: String
    var tipo: Tipo
    var primaria = false
    var id: String { titolo }
}

/// Uno spunto: la domanda da mandare (con lo spunto di Prisma, se c'è).
struct SpuntoMiniEve: Identifiable, Equatable {
    var testo: String
    var simbolo: String
    var domanda: String
    var spunto: SpuntoEve?
    var portafoglio: SpuntoPortafoglio?
    var id: String { testo }
}

/// Le cifre che accompagnano la risposta: le calcola Prisma, mai il modello.
struct CifreMiniEve: Equatable {
    var righe: [RigaMiniEve] = []
    var linea: LineaTempoMiniEve?
    /// «Cifre dai calcoli di Posizioni · calcolate oggi alle 10:52».
    var fonte: String?
    var azioni: [AzioneMiniEve] = []
    var seguiti: [SpuntoMiniEve] = []

    /// Cosa mostrare sotto la risposta a questa domanda. Senza cliente (contesto tolto) o in conversazione
    /// niente cifre: solo gli spunti per continuare.
    static func calcola(domanda: String, fonte f: FonteEve?, modalita: ModalitaEve, app: String?, oggi: Date = Date()) -> CifreMiniEve {
        var c = CifreMiniEve()
        guard let f, modalita == .lavoro else {
            c.seguiti = f == nil ? spuntiPortafoglio : [spunto(.riepilogo), spunto(.prossimiPassi)]
            return c
        }
        let t = NucleoEve.semplice(domanda)
        let argomento = SpuntoEve.argomento(domanda) ?? SpuntoEve.da(domanda)
        let suScadenze = argomento == .scadenze || argomento == .liquidita
            || ["scad", "svincol", "in arrivo", "prossimi mesi"].contains { t.contains($0) }
        let calcolate = Formati.ora.string(from: oggi)
        if suScadenze {
            let limite = Calendar.current.date(byAdding: .month, value: Tema.Misura.MiniEve.mesiLineaTempo, to: oggi) ?? oggi
            let inScadenza = f.posizioni
                .filter { $0.stato == .inEssere && ($0.scadenza.map { $0 >= Calendar.current.startOfDay(for: oggi) && $0 <= limite } ?? false) }
                .sorted { ($0.scadenza ?? oggi) < ($1.scadenza ?? oggi) }
            c.righe = inScadenza.map { riga($0, sotto: "Scade il \(Formati.giornoMese.string(from: $0.scadenza ?? oggi))") }
            if !inScadenza.isEmpty { c.linea = linea(inScadenza, fonte: f, oggi: oggi, limite: limite) }
            c.fonte = "Cifre dai calcoli di Posizioni · calcolate oggi alle \(calcolate)"
            c.azioni = [AzioneMiniEve(titolo: "Apri in Posizioni", simbolo: "arrow.up.forward", tipo: .posizioni, primaria: true),
                        AzioneMiniEve(titolo: "Fissa incontro", simbolo: "calendar", tipo: .agenda),
                        AzioneMiniEve(titolo: "Prospetto", simbolo: "doc", tipo: .prospetto(.liquidita(report: false)))]
            c.seguiti = [spunto(.liquidita, testo: "Cosa fare della liquidità?", simbolo: "house"),
                         spunto(.obiettivi, testo: "A che punto sono gli obiettivi?", simbolo: "chart.line.uptrend.xyaxis")]
            return c
        }
        // Le posizioni del cliente, quando la domanda parla di patrimonio, posizioni o canali
        let suPosizioni = ["posizion", "portafogl", "patrimon", "investiment", "polizz", "alleanza", "indipendent", "riepilog",
                           "riassum", "dossier", "check", "quanto ha", "valore"].contains { t.contains($0) }
            || f.posizioni.contains { p in NucleoEve.semplice(p.nome).count > 4 && t.contains(NucleoEve.semplice(p.nome)) }
        if suPosizioni {
            let nominate = f.posizioni.filter { p in t.contains(NucleoEve.semplice(p.nome)) }
            let elenco = nominate.isEmpty
                ? Array(f.posizioni.filter { $0.stato == .inEssere && !$0.area.passivo }.sorted { $0.valore > $1.valore }.prefix(3))
                : nominate
            c.righe = elenco.map { riga($0, sotto: $0.tipologia.isEmpty ? $0.area.nome : $0.tipologia) }
        }
        c.fonte = "Cifre dai calcoli di \(app ?? "Prisma") · calcolate oggi alle \(calcolate)"
        c.azioni = [AzioneMiniEve(titolo: "Apri in Posizioni", simbolo: "arrow.up.forward", tipo: .posizioni, primaria: true),
                    AzioneMiniEve(titolo: "Fissa incontro", simbolo: "calendar", tipo: .agenda),
                    AzioneMiniEve(titolo: "Prospetto", simbolo: "doc", tipo: .prospetto(prospetto(argomento)))]
        c.seguiti = argomento == .prossimiPassi ? [spunto(.checkUp), spunto(.proposte)] : [spunto(.prossimiPassi), spunto(.scadenze)]
        return c
    }

    /// Il prospetto più vicino all'argomento della domanda.
    static func prospetto(_ s: SpuntoEve?) -> SceltaProspetto {
        switch s {
        case .pensione?: return .previdenza(report: false)
        case .protezione?: return .protezione(report: false)
        case .costi?: return .costi(report: false)
        case .resistenza?: return .resistenza(report: false)
        case .successione?: return .successione(report: false)
        case .checkUp?: return .checkUp(report: false)
        case .liquidita?, .scadenze?: return .liquidita(report: false)
        default: return .resoconto(report: false)
        }
    }

    static func riga(_ p: Posizione, sotto: String) -> RigaMiniEve {
        let importo = p.area == .protezione ? (p.capitaleAssicurato ?? p.valore) : p.valore
        return RigaMiniEve(id: p.id, titolo: p.nome, sotto: sotto, canale: p.canale, importo: importo,
                           valore: Formati.euro(importo), data: p.scadenza)
    }

    private static func linea(_ elenco: [Posizione], fonte f: FonteEve, oggi: Date, limite: Date) -> LineaTempoMiniEve {
        let cal = Calendar.current
        let inizio = cal.date(from: cal.dateComponents([.year, .month], from: oggi)) ?? oggi
        func mesi(_ d: Date) -> Double {
            let m = cal.dateComponents([.month], from: inizio, to: d).month ?? 0
            let inizioMese = cal.date(byAdding: .month, value: m, to: inizio) ?? inizio
            let giorni = Double(cal.range(of: .day, in: .month, for: inizioMese)?.count ?? 30)
            let giorno = Double((cal.dateComponents([.day], from: inizioMese, to: d).day ?? 0))
            return Double(m) + giorno / giorni
        }
        let punti = elenco.map { p in
            LineaTempoMiniEve.Punto(mesi: mesi(p.scadenza ?? oggi), importo: p.valore, canale: p.canale,
                                    etichetta: Formati.euro(p.valore), giorno: Formati.giornoMeseBreve.string(from: p.scadenza ?? oggi))
        }
        // Il primo obiettivo oltre l'orizzonte: «casa 2029 →»
        let oltre = f.obiettivi.filter { $0.scadenza > limite }.min { $0.scadenza < $1.scadenza }.map {
            "\($0.titolo.split(separator: " ").prefix(2).joined(separator: " ").lowercased()) \(Formati.formato("yyyy").string(from: $0.scadenza)) →"
        }
        return LineaTempoMiniEve(titolo: "In scadenza · prossimi 12 mesi", totale: Formati.euro(elenco.reduce(0) { $0 + $1.valore }),
                                 inizio: inizio, oggi: oggi, punti: punti, oltre: oltre)
    }

    // MARK: - Spunti

    static func spunto(_ s: SpuntoEve, testo: String? = nil, simbolo: String? = nil) -> SpuntoMiniEve {
        SpuntoMiniEve(testo: testo ?? s.domanda, simbolo: simbolo ?? simboloSpunto(s), domanda: s.domanda, spunto: s)
    }

    static func simboloSpunto(_ s: SpuntoEve) -> String {
        switch s {
        case .riepilogo: return "sparkle"
        case .scadenze: return "clock"
        case .checkUp, .resoconto, .obiettivi: return "chart.line.uptrend.xyaxis"
        case .incontro: return "calendar"
        case .documenti: return "doc"
        case .liquidita: return "house"
        case .prossimiPassi: return "checkmark"
        default: return "sparkle"
        }
    }

    /// «Su Giulia Rossi»: gli spunti del cliente nella scheda per scrivere.
    static let spuntiCliente: [SpuntoMiniEve] = [
        spunto(.riepilogo, testo: "Riassumi il dossier", simbolo: "sparkle"),
        spunto(.scadenze, testo: "Cosa scade?", simbolo: "clock"),
        spunto(.checkUp, testo: "Check-up completo", simbolo: "chart.line.uptrend.xyaxis"),
        spunto(.incontro, testo: "Prepara l'incontro", simbolo: "calendar"),
    ]

    /// «La tua giornata»: l'agenda di oggi e il portafoglio.
    static let spuntiGiornata: [SpuntoMiniEve] = [
        SpuntoMiniEve(testo: "Cosa ho oggi?", simbolo: "calendar", domanda: "Cosa ho oggi?"),
        SpuntoMiniEve(testo: "Chi ricontattare", simbolo: "person.2", domanda: SpuntoPortafoglio.ricontattare.domanda, portafoglio: .ricontattare),
        SpuntoMiniEve(testo: "Cosa scade nel portafoglio", simbolo: "doc", domanda: SpuntoPortafoglio.scadenze.domanda, portafoglio: .scadenze),
    ]

    static let spuntiPortafoglio: [SpuntoMiniEve] = [
        SpuntoMiniEve(testo: "Il quadro del portafoglio", simbolo: "sparkle", domanda: SpuntoPortafoglio.quadro.domanda, portafoglio: .quadro),
        SpuntoMiniEve(testo: "Chi ricontattare", simbolo: "person.2", domanda: SpuntoPortafoglio.ricontattare.domanda, portafoglio: .ricontattare),
    ]
}

/// ⌥ Spazio: tenuto premuto = parla (rilasciato = Eve risponde), premuto una volta = si apre per scrivere.
struct GestoScorciatoia {
    enum Esito: Equatable {
        case nessuno
        /// Premuto e lasciato subito: la mini finestra si apre per scrivere.
        case scrivi
        /// Tenuto premuto oltre la soglia: Eve ascolta.
        case iniziaAParlare
        /// Lasciato dopo aver parlato: Eve chiude la frase e risponde.
        case finisciDiParlare
    }

    var soglia = Tema.Moto.MiniEve.sogliaTenuto
    private(set) var premutoAlle: Date?
    private(set) var parla = false

    /// Il tasto giù (le ripetizioni della tastiera non contano).
    mutating func premi(_ t: Date) -> Esito {
        guard premutoAlle == nil else { return .nessuno }
        premutoAlle = t
        parla = false
        return .nessuno
    }

    /// Il controllo dopo la soglia, con il tasto ancora giù.
    mutating func tieni(_ t: Date) -> Esito {
        guard let p = premutoAlle, !parla, t.timeIntervalSince(p) >= soglia else { return .nessuno }
        parla = true
        return .iniziaAParlare
    }

    /// Il tasto su.
    mutating func rilascia(_ t: Date) -> Esito {
        guard premutoAlle != nil else { return .nessuno }
        premutoAlle = nil
        if parla {
            parla = false
            return .finisciDiParlare
        }
        return .scrivi
    }
}

/// Una domanda alla mini finestra: il testo, lo spunto di Prisma (cliente o portafoglio) e se è arrivata a voce.
struct DomandaMiniEve: Equatable {
    var testo: String
    var spunto: SpuntoEve?
    var portafoglio: SpuntoPortafoglio?
    var aVoce = false
}

/// Lo stato della mini finestra: lo osservano solo il pannello e la sfera nella barra.
final class StatoMiniEve: ObservableObject {
    @Published var aperta = false
    /// true appena si apre, false appena comincia a chiudersi: guida l'entrata e l'uscita.
    @Published var visibile = false
    @Published var fase = FaseMiniEve.scrivi
    /// Il gettone del contesto: nil se l'hai tolto (Eve parla del portafoglio).
    @Published var contesto: ContestoMiniEve?
    /// La domanda in corso (detta o scritta).
    @Published var domanda = ""
    /// Il campo per scrivere.
    @Published var testo = ""
    /// Il passo che Eve sta facendo mentre pensa.
    @Published var passo = ""
    /// La risposta: il testo (che cresce mentre arriva), le cifre di Prisma e il motore.
    @Published var risposta = ""
    @Published var titolo: String?
    @Published var cifre = CifreMiniEve()
    /// La risposta sta ancora arrivando (le barrette accanto a «Eve»).
    @Published var inArrivo = false
    /// Un avviso breve sopra gli spunti (per esempio «Non ti ho sentito»).
    @Published var nota: String?
    /// «Mi sto svegliando…»: perché Qwen non è pronto, se la preparazione non è riuscita.
    @Published var motivoNonPronta: String?
    @Published var preparazioneInCorso = false
    /// L'altezza naturale del contenuto (la superficie la segue con la molla).
    @Published var altezza = Tema.Misura.MiniEve.altezzaCapsula

    /// I passi di «pensa», uno dopo l'altro.
    var passi: [String] = []
    /// La conversazione in cui finisce la domanda (il cliente o il portafoglio): la stessa dell'app Eve.
    var chiave = ""
    /// Quanti messaggi aveva la conversazione prima della domanda.
    var messaggiPrima = 0
    /// La domanda in attesa che Qwen si svegli: «Riprova» (o Qwen pronto) la manda.
    var pendente: DomandaMiniEve?
    /// La domanda è arrivata a voce, dalla mini finestra (l'ascolto è suo).
    var ascoltoMio = false
    var gesto = GestoScorciatoia()
    var abbonamenti = Set<AnyCancellable>()
    var timerPassi: Timer?

    var larghezza: CGFloat { fase.capsula ? Tema.Misura.MiniEve.larghezzaCapsula : Tema.Misura.MiniEve.larghezzaScheda }

    /// Si apre in uno stato (da chiusa o già aperta).
    func apri(_ f: FaseMiniEve, contesto c: ContestoMiniEve?) {
        if !aperta { contesto = c }
        nota = nil
        aperta = true
        visibile = true
        vai(f)
    }

    func vai(_ f: FaseMiniEve) {
        if f != .pensa { fermaPassi() }
        if f == .scrivi || f == .ascolta {
            risposta = ""
            titolo = nil
            cifre = CifreMiniEve()
            inArrivo = false
        }
        if f != .nonPronta {
            motivoNonPronta = nil
            preparazioneInCorso = false
        }
        fase = f
    }

    /// Eve comincia a pensare: i passi scorrono, l'ultimo resta.
    func pensa(_ domanda: String, passi elenco: [String]) {
        self.domanda = domanda
        passi = elenco.isEmpty ? ["Ci penso…"] : elenco
        passo = passi[0]
        vai(.pensa)
        fermaPassi()
        guard passi.count > 1 else { return }
        var i = 0
        timerPassi = Timer.scheduledTimer(withTimeInterval: Tema.Moto.MiniEve.passoPensiero, repeats: true) { [weak self] t in
            guard let self else { return t.invalidate() }
            i += 1
            guard i < self.passi.count else { return t.invalidate() }
            self.passo = self.passi[i]
        }
    }

    func fermaPassi() {
        timerPassi?.invalidate()
        timerPassi = nil
    }

    /// La risposta comincia ad arrivare (o è arrivata tutta): si passa alla scheda.
    func rispondi(testo t: String, titolo: String?, cifre c: CifreMiniEve, inArrivo arriva: Bool) {
        if fase != .risponde {
            fermaPassi()
            fase = .risponde
        }
        if cifre != c { cifre = c }
        if risposta != t { risposta = t }
        if self.titolo != titolo { self.titolo = titolo }
        if inArrivo != arriva { inArrivo = arriva }
    }

    /// Qwen non è pronto: la domanda resta da parte (Riprova la manda), nessuna risposta.
    func nonPronta(motivo: String?) {
        fermaPassi()
        motivoNonPronta = motivo
        vai(.nonPronta)
    }

    /// Comincia a chiudersi (l'uscita dura 0,3 s, poi `aperta` torna false).
    func chiudi() {
        fermaPassi()
        visibile = false
        abbonamenti.removeAll()
        ascoltoMio = false
    }

    /// Finita l'uscita: tutto torna a riposo (il gettone del contesto si rilegge alla prossima apertura).
    func riposa() {
        aperta = false
        testo = ""
        nota = nil
        vai(.scrivi)
        altezza = Tema.Misura.MiniEve.altezzaCapsula
    }

    /// I passi di «pensa» per questa domanda, dai dati veri del cliente.
    static func passi(domanda: String, fonte f: FonteEve?, modalita: ModalitaEve) -> [String] {
        guard modalita == .lavoro else { return ["Ci penso…"] }
        guard let f else { return ["Apro il portafoglio…", "Leggo i clienti e le scadenze…", "Preparo le cifre di Prisma…"] }
        let nome = f.cliente.nome.split(separator: " ").first.map(String.init) ?? f.cliente.nome
        let inEssere = f.posizioni.filter { $0.stato == .inEssere }
        let canali = Set(inEssere.map(\.canale))
        let quali = canali.count > 1 ? ", Alleanza e indipendenti" : (canali.first.map { $0 == .alleanza ? ", Alleanza" : ", indipendenti" } ?? "")
        let posizioni = inEssere.count == 1 ? "1 posizione" : "\(inEssere.count) posizioni"
        let t = NucleoEve.semplice(domanda)
        let incrocio = t.contains("scad") ? "Incrocio scadenze e obiettivi…" : "Preparo le cifre di Prisma…"
        return ["Apro il dossier di \(nome)…", "Leggo \(posizioni)\(quali)…", incrocio]
    }
}
