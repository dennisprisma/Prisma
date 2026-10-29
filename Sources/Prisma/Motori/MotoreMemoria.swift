import Foundation

// Riesame con memoria (specifica 12): la fotografia delle cifre chiave del cliente a ogni riesame e, al riesame
// successivo, che cosa è cambiato. Motore puro: niente `Date()` dentro i calcoli, le date arrivano da fuori.
// I testi stanno in TestiMemoria.swift, lo stato in Shell/StatoMemoriaRiesame.swift.

/// Completezza dei dati da fotografare (dalla specifica 7: percentuale e nome del livello).
struct DatiCompletezzaFoto: Equatable {
    let percentuale: Int
    let livello: String
}

/// Una cifra chiave cambiata tra due fotografie.
struct VariazioneRiesame: Identifiable, Hashable {
    enum Tema: Int, CaseIterable, Comparable {
        case profilo, famiglia, semafori, pensione, protezione, obiettivi, patrimonio, completezza, conformita

        static func < (a: Tema, b: Tema) -> Bool { a.rawValue < b.rawValue }

        var nome: String {
            switch self {
            case .profilo: return "Profilo"
            case .famiglia: return "Famiglia"
            case .semafori: return "Check-up"
            case .pensione: return "Pensione"
            case .protezione: return "Protezione"
            case .obiettivi: return "Obiettivi"
            case .patrimonio: return "Patrimonio"
            case .completezza: return "Dati"
            case .conformita: return "In regola"
            }
        }
    }

    /// Meglio o peggio per il cliente; neutro quando non si può dire (profilo, famiglia, patrimonio, semafori grigi).
    enum Verso { case meglio, peggio, neutro }

    let tema: Tema
    /// Chiave stabile («pensione.divario», «famiglia.ingresso.f-sofia»…): serve da id e nelle prove.
    let chiave: String
    /// La frase: «Divario pensione da 640 a 410 €/mese».
    let testo: String
    /// Valore di prima e di oggi in breve, per le tabelle: «640 €/mese», «410 €/mese»; «—» se non c'era.
    let prima: String
    let oggi: String
    /// «−230 €/mese», «+9.500 €», «+15 punti»; nil per le variazioni non numeriche.
    let differenza: String?
    let verso: Verso
    /// true se il numero è salito, false se è sceso, nil se non è un numero (per la freccia).
    let aumento: Bool?
    var canale: Canale? = nil

    var id: String { chiave }
}

/// La memoria del riesame di un cliente: la fotografia di oggi, quella con cui si confronta e le variazioni.
struct MemoriaRiesame: Equatable {
    let clienteId: String
    let oggi: Date
    /// Calcolata adesso, non salvata.
    let attuale: FotografiaRiesame
    /// La fotografia salvata più recente scattata almeno `giorniTraRiesami` giorni prima di oggi.
    let precedente: FotografiaRiesame?
    let variazioni: [VariazioneRiesame]
    /// Le fotografie salvate del cliente, dalla più recente.
    let cronologia: [FotografiaRiesame]

    var primoRiesame: Bool { precedente == nil }
    var meglio: Int { variazioni.filter { $0.verso == .meglio }.count }
    var peggio: Int { variazioni.filter { $0.verso == .peggio }.count }
}

/// Fotografie, confronti e registrazione delle fotografie dei riesami.
enum MotoreMemoria {
    /// Due fotografie a meno di 30 giorni sono lo stesso riesame (preparazione e incontro): la nuova sostituisce
    /// la vecchia; il confronto si fa con una fotografia di almeno 30 giorni prima.
    static let giorniTraRiesami = 30
    /// Fotografie tenute per cliente: oltre, si toglie la più vecchia (minimizzazione, GDPR art. 5).
    static let massimoPerCliente = 20
    // Soglie sotto cui una differenza non è una variazione (scelte di Prisma, non norme)
    static let sogliaDivarioPensione = 20.0      // €/mese
    static let sogliaAmmanco = 50.0              // €/mese
    static let sogliaCasoMorte = 5_000.0         // €
    static let sogliaPatrimonio = 500.0          // € (e insieme…)
    static let sogliaPatrimonioQuota = 0.02      // …il 2% del valore di prima (se il valore di prima è 0 basta la soglia in euro)
    static let sogliaPuntiObiettivo = 5          // punti percentuali, sulle percentuali intere
    static let sogliaPuntiCompletezza = 5        // punti percentuali (o un cambio di livello)
    /// Variazioni nelle note dell'appuntamento; le altre sono nel prospetto.
    static let massimoAgenda = 6
    /// Fotografie salvate nella tabella «Cronologia dei riesami» del prospetto (più la colonna di oggi).
    static let massimoCronologiaProspetto = 4
    /// Variazioni mostrate prima di «Mostra tutte» (scheda Riesami) e nei riquadri brevi.
    static let massimoScheda = 8
    static let massimoBreve = 4

    /// La prima riga delle note del riesame (MotorePianificazione.noteRiesame): resta sempre identica.
    static let rigaOrdineDelGiorno = "Ordine del giorno:"

    // MARK: - Fotografia

    /// La fotografia delle cifre di oggi. `posizioni` e `obiettivi` sono già quelli del cliente (come in FonteEve).
    static func fotografia(cliente: Cliente, posizioni: [Posizione], analisi: Analisi360, obiettivi: [Obiettivo],
                           oggi: Date, origine: FotografiaRiesame.Origine,
                           completezza: DatiCompletezzaFoto? = nil,
                           conformita: [FotografiaRiesame.VoceConformitaFoto]? = nil,
                           cal: Calendar = .current) -> FotografiaRiesame {
        let r = RiepilogoPosizioni(posizioni)
        let prev = MotorePrevidenza.calcola(posizioni, cliente: cliente, analisi: analisi.previdenza, data: oggi)
        let prot = MotoreAnalisi.protezione(analisi.protezione, posizioni: posizioni)
        let check = MotoreCheckUp.calcola(cliente: cliente, posizioni: posizioni, analisi: analisi, obiettivi: obiettivi)

        var f = FotografiaRiesame(clienteId: cliente.id, data: cal.startOfDay(for: oggi))
        f.origini = [origine.rawValue]
        // Profilo
        f.propensione = cliente.profilo.propensione?.rawValue
        f.orizzonteAnni = cliente.profilo.orizzonteAnni
        f.esperienza = cliente.profilo.esperienza?.rawValue
        f.profiloAggiornatoIl = cliente.profilo.aggiornatoIl
        // Famiglia
        f.statoCivile = cliente.statoCivile?.rawValue
        f.famiglia = cliente.famiglia.map {
            FotografiaRiesame.FamiliareFoto(id: $0.id, nome: $0.nome, relazione: $0.relazione.rawValue, aCarico: $0.aCarico)
        }
        // Semafori del check-up, nell'ordine del motore
        f.semafori = check.indicatori.map {
            FotografiaRiesame.SemaforoFoto(id: $0.id, titolo: $0.titolo, colore: $0.semaforo.rawValue, valore: $0.valore)
        }
        // Pensione (€/mese, in euro di oggi)
        f.redditoDesiderato = finito(prev.redditoDesiderato)
        f.pensionePubblica = finito(prev.pensionePubblica)
        f.renditaPiani = finito(prev.renditaInEssere)
        f.divarioPensione = finito(prev.divarioResiduo)
        // Protezione: le stesse cifre dei semafori «morte» e «invalidita»
        f.fabbisognoCasoMorte = finito(prot.fabbisogno)
        f.capitaleCasoMorte = finito(prot.capitaleVita)
        f.scopertoCasoMorte = finito(prot.divario)
        f.ammancoInvalidita = finito(prot.ammanco)
        // Obiettivi
        f.obiettivi = obiettivi.map { o in
            let a = AvanzamentoObiettivo(o, posizioni: posizioni)
            return FotografiaRiesame.ObiettivoFoto(id: o.id, titolo: o.titolo, importo: finito(o.importo) ?? 0,
                                                    scadenza: o.scadenza, quota: finito(a.quota) ?? 0)
        }
        // Patrimonio in essere per canale (debiti esclusi dal per canale)
        f.patrimonioAlleanza = finito(r.perCanale[.alleanza] ?? 0) ?? 0
        f.patrimonioIndipendente = finito(r.perCanale[.indipendente] ?? 0) ?? 0
        f.debiti = finito(r.debiti) ?? 0
        f.proposteAperte = r.proposteAperte
        // Completezza (giro 3) e conformità (giro 4), se rilevate
        f.completezza = completezza?.percentuale
        f.livelloCompletezza = completezza?.livello
        f.conformita = conformita
        return f
    }

    /// La stessa, dalla fonte del cliente: `f.cliente`, `f.posizioni`, `f.analisi`, `f.obiettivi`, `f.oggi`.
    static func fotografia(_ f: FonteEve, origine: FotografiaRiesame.Origine, completezza: DatiCompletezzaFoto? = nil,
                           conformita: [FotografiaRiesame.VoceConformitaFoto]? = nil) -> FotografiaRiesame {
        fotografia(cliente: f.cliente, posizioni: f.posizioni, analisi: f.analisi, obiettivi: f.obiettivi,
                   oggi: f.oggi, origine: origine, completezza: completezza, conformita: conformita)
    }

    // MARK: - Cronologia e precedente

    /// Le fotografie del cliente, dalla più recente (a parità di giorno, l'ordine dell'elenco).
    static func cronologia(_ fotografie: [FotografiaRiesame], cliente: String) -> [FotografiaRiesame] {
        fotografie.enumerated()
            .filter { $0.element.clienteId == cliente }
            .sorted { a, b in
                if a.element.data != b.element.data { return a.element.data > b.element.data }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    /// La più recente con `startOfDay(data) <= startOfDay(oggi) − giorniTraRiesami giorni`; nil se non ce n'è.
    static func precedente(_ fotografie: [FotografiaRiesame], cliente: String, oggi: Date,
                           cal: Calendar = .current) -> FotografiaRiesame? {
        let inizio = cal.startOfDay(for: oggi)
        guard let limite = cal.date(byAdding: .day, value: -giorniTraRiesami, to: inizio) else { return nil }
        return cronologia(fotografie, cliente: cliente).first { cal.startOfDay(for: $0.data) <= limite }
    }

    /// Memoria completa: precedente, variazioni dalla precedente alla attuale, cronologia.
    static func memoria(attuale: FotografiaRiesame, fotografie: [FotografiaRiesame], oggi: Date,
                        cal: Calendar = .current) -> MemoriaRiesame {
        let p = precedente(fotografie, cliente: attuale.clienteId, oggi: oggi, cal: cal)
        return MemoriaRiesame(clienteId: attuale.clienteId, oggi: oggi, attuale: attuale, precedente: p,
                              variazioni: p.map { variazioni(da: $0, a: attuale) } ?? [],
                              cronologia: cronologia(fotografie, cliente: attuale.clienteId))
    }

    // MARK: - Variazioni

    /// Le variazioni da `prima` a `oggi`, ordinate per tema e, dentro il tema, nell'ordine delle regole (§3.4).
    static func variazioni(da prima: FotografiaRiesame, a oggi: FotografiaRiesame) -> [VariazioneRiesame] {
        var v: [VariazioneRiesame] = []
        v += variazioniProfilo(prima, oggi)
        v += variazioniFamiglia(prima, oggi)
        v += variazioniSemafori(prima, oggi)
        v += variazioniPensioneProtezione(prima, oggi)
        v += variazioniObiettivi(prima, oggi)
        v += variazioniPatrimonio(prima, oggi)
        v += variazioniCompletezza(prima, oggi)
        v += variazioniConformita(prima, oggi)
        // Le regole producono già l'ordine giusto; l'ordinamento stabile per tema lo garantisce comunque
        return v.enumerated()
            .sorted { ($0.element.tema.rawValue, $0.offset) < ($1.element.tema.rawValue, $1.offset) }
            .map(\.element)
    }

    private typealias T = TestiMemoria

    /// Regole 1–3: propensione, orizzonte, esperienza (verso neutro, nessuna freccia).
    private static func variazioniProfilo(_ p: FotografiaRiesame, _ o: FotografiaRiesame) -> [VariazioneRiesame] {
        var v: [VariazioneRiesame] = []
        func tre(_ chiave: String, _ etichetta: String, _ prima: String?, _ oggi: String?, nome: (String) -> String) {
            guard prima != oggi else { return }
            let testo: String
            switch (prima, oggi) {
            case (.some(let a), .some(let b)): testo = "\(etichetta) da \(nome(a)) a \(nome(b))"
            case (.none, .some(let b)): testo = "\(etichetta) indicata: \(nome(b))"
            case (.some(let a), .none): testo = "\(etichetta) non più indicata (era \(nome(a)))"
            case (.none, .none): return
            }
            v.append(VariazioneRiesame(tema: .profilo, chiave: chiave, testo: testo,
                                       prima: prima.map(nome) ?? T.vuoto, oggi: oggi.map(nome) ?? T.vuoto,
                                       differenza: nil, verso: .neutro, aumento: nil))
        }
        tre("profilo.propensione", "Propensione", p.propensione, o.propensione, nome: T.propensione)
        if let b = o.orizzonteAnni, b != p.orizzonteAnni {
            let testo = p.orizzonteAnni.map { "Orizzonte da \($0) a \(T.anni(b))" } ?? "Orizzonte indicato: \(T.anni(b))"
            v.append(VariazioneRiesame(tema: .profilo, chiave: "profilo.orizzonte", testo: testo,
                                       prima: p.orizzonteAnni.map(T.anni) ?? T.vuoto, oggi: T.anni(b),
                                       differenza: nil, verso: .neutro, aumento: nil))
        }
        tre("profilo.esperienza", "Esperienza", p.esperienza, o.esperienza, nome: T.esperienza)
        return v
    }

    /// Regole 4–7: stato civile, chi entra, chi esce, chi diventa (o non è più) a carico.
    private static func variazioniFamiglia(_ p: FotografiaRiesame, _ o: FotografiaRiesame) -> [VariazioneRiesame] {
        typealias F = FotografiaRiesame.FamiliareFoto
        var v: [VariazioneRiesame] = []
        func neutra(_ chiave: String, _ testo: String, _ prima: String, _ oggi: String) {
            v.append(VariazioneRiesame(tema: .famiglia, chiave: chiave, testo: testo, prima: prima, oggi: oggi,
                                       differenza: nil, verso: .neutro, aumento: nil))
        }
        if let a = p.statoCivile, let b = o.statoCivile, a != b {
            neutra("famiglia.statoCivile", "Stato civile da \(T.statoCivile(a)) a \(T.statoCivile(b))",
                   T.statoCivile(a), T.statoCivile(b))
        }
        /// Lo stesso familiare: per id; se l'id manca, per nome e relazione senza maiuscole.
        func stesso(_ x: F, _ y: F) -> Bool {
            if !x.id.isEmpty && !y.id.isEmpty { return x.id == y.id }
            return x.nome.lowercased() == y.nome.lowercased() && x.relazione.lowercased() == y.relazione.lowercased()
        }
        func chiave(_ x: F) -> String { x.id.isEmpty ? x.nome.lowercased() : x.id }
        func nome(_ x: F) -> String { x.nome.isEmpty ? T.relazione(x.relazione) : x.nome }
        func descrizione(_ x: F) -> String { T.relazione(x.relazione) + (x.aCarico ? ", a carico" : "") }
        for x in o.famiglia where !p.famiglia.contains(where: { stesso($0, x) }) {
            neutra("famiglia.ingresso.\(chiave(x))", "In famiglia: \(nome(x)) (\(descrizione(x)))", T.vuoto, descrizione(x))
        }
        for x in p.famiglia where !o.famiglia.contains(where: { stesso($0, x) }) {
            neutra("famiglia.uscita.\(chiave(x))", "Non più in famiglia: \(nome(x)) (\(T.relazione(x.relazione)))",
                   T.relazione(x.relazione), T.vuoto)
        }
        for x in o.famiglia {
            guard let y = p.famiglia.first(where: { stesso($0, x) }), y.aCarico != x.aCarico else { continue }
            neutra("famiglia.aCarico.\(chiave(x))", x.aCarico ? "\(nome(x)) ora è a carico" : "\(nome(x)) non è più a carico",
                   y.aCarico ? "a carico" : "non a carico", x.aCarico ? "a carico" : "non a carico")
        }
        return v
    }

    /// Regola 8: i semafori di oggi che prima avevano un altro colore.
    private static func variazioniSemafori(_ p: FotografiaRiesame, _ o: FotografiaRiesame) -> [VariazioneRiesame] {
        var v: [VariazioneRiesame] = []
        func breve(_ s: FotografiaRiesame.SemaforoFoto) -> String {
            T.colore(s.colore) + (s.valore.isEmpty ? "" : " · \(s.valore)")
        }
        for s in o.semafori {
            guard let prima = p.semaforo(s.id), prima.colore != s.colore else { continue }
            let verso: VariazioneRiesame.Verso
            if let a = Semaforo(rawValue: prima.colore), let b = Semaforo(rawValue: s.colore), a != .grigio, b != .grigio {
                verso = b.urgenza > a.urgenza ? .meglio : (b.urgenza < a.urgenza ? .peggio : .neutro)
            } else {
                verso = .neutro
            }
            let titolo = s.titolo.isEmpty ? (prima.titolo.isEmpty ? s.id : prima.titolo) : s.titolo
            v.append(VariazioneRiesame(tema: .semafori, chiave: "semaforo.\(s.id)",
                                       testo: "Semaforo «\(titolo)» da \(T.colore(prima.colore)) a \(T.colore(s.colore))",
                                       prima: breve(prima), oggi: breve(s), differenza: nil, verso: verso, aumento: nil))
        }
        return v
    }

    /// Una cifra in euro (o €/mese) che conta sopra una soglia: sceso → meglio (divario, scoperto, ammanco, debiti).
    private static func importo(_ tema: VariazioneRiesame.Tema, _ chiave: String, _ etichetta: String,
                                _ prima: Double, _ oggi: Double, unita: String, scesoMeglio: Bool?,
                                canale: Canale? = nil) -> VariazioneRiesame {
        let d = oggi - prima
        let verso: VariazioneRiesame.Verso
        if let scesoMeglio, d != 0 {
            verso = (d < 0) == scesoMeglio ? .meglio : .peggio
        } else {
            verso = .neutro
        }
        return VariazioneRiesame(tema: tema, chiave: chiave,
                                 testo: "\(etichetta) da \(T.cifra(prima)) a \(T.cifra(oggi)) \(unita)",
                                 prima: "\(T.cifra(prima)) \(unita)", oggi: "\(T.cifra(oggi)) \(unita)",
                                 differenza: T.differenza(d, unita: unita), verso: verso,
                                 aumento: d == 0 ? nil : d > 0, canale: canale)
    }

    /// Regole 9–11: divario pensione, scoperto caso morte, ammanco in caso di invalidità.
    private static func variazioniPensioneProtezione(_ p: FotografiaRiesame, _ o: FotografiaRiesame) -> [VariazioneRiesame] {
        var v: [VariazioneRiesame] = []
        if let a = p.divarioPensione, let b = o.divarioPensione, abs(b - a) >= sogliaDivarioPensione {
            v.append(importo(.pensione, "pensione.divario", "Divario pensione", a, b, unita: T.euroMese, scesoMeglio: true))
        }
        if let a = p.scopertoCasoMorte, let b = o.scopertoCasoMorte, abs(b - a) >= sogliaCasoMorte {
            v.append(importo(.protezione, "protezione.scoperto", "Scoperto caso morte", a, b, unita: T.euroUnita, scesoMeglio: true))
        }
        if let a = p.ammancoInvalidita, let b = o.ammancoInvalidita, abs(b - a) >= sogliaAmmanco {
            v.append(importo(.protezione, "protezione.ammanco", "Ammanco in caso di invalidità", a, b,
                             unita: T.euroMese, scesoMeglio: true))
        }
        return v
    }

    /// Regole 12–14: avanzamento degli obiettivi (sulle percentuali intere), obiettivi nuovi e tolti.
    private static func variazioniObiettivi(_ p: FotografiaRiesame, _ o: FotografiaRiesame) -> [VariazioneRiesame] {
        typealias O = FotografiaRiesame.ObiettivoFoto
        var v: [VariazioneRiesame] = []
        func stesso(_ x: O, _ y: O) -> Bool {
            if !x.id.isEmpty && !y.id.isEmpty { return x.id == y.id }
            return x.titolo.lowercased() == y.titolo.lowercased()
        }
        func chiave(_ x: O) -> String { x.id.isEmpty ? x.titolo.lowercased() : x.id }
        func breve(_ x: O) -> String { "\(T.percento(x.quota))% di \(T.cifra(x.importo)) \(T.euroUnita)" }
        for x in o.obiettivi {
            if let y = p.obiettivi.first(where: { stesso($0, x) }) {
                let a = T.percento(y.quota)
                let b = T.percento(x.quota)
                guard abs(b - a) >= sogliaPuntiObiettivo else { continue }
                v.append(VariazioneRiesame(tema: .obiettivi, chiave: "obiettivo.\(chiave(x))",
                                           testo: "Obiettivo «\(x.titolo)» \(T.dal(a)) \(T.al(b))",
                                           prima: "\(a)%", oggi: "\(b)%", differenza: T.punti(b - a),
                                           verso: b > a ? .meglio : .peggio, aumento: b > a))
            } else {
                v.append(VariazioneRiesame(tema: .obiettivi, chiave: "obiettivo.nuovo.\(chiave(x))",
                                           testo: "Nuovo obiettivo «\(x.titolo)»: \(T.cifra(x.importo)) \(T.euroUnita), raggiunto \(T.al(T.percento(x.quota)))",
                                           prima: T.vuoto, oggi: breve(x), differenza: nil, verso: .neutro, aumento: nil))
            }
        }
        for y in p.obiettivi where !o.obiettivi.contains(where: { stesso($0, y) }) {
            v.append(VariazioneRiesame(tema: .obiettivi, chiave: "obiettivo.tolto.\(chiave(y))",
                                       testo: "Obiettivo «\(y.titolo)» tolto (era \(T.al(T.percento(y.quota))))",
                                       prima: breve(y), oggi: T.vuoto, differenza: nil, verso: .neutro, aumento: nil))
        }
        return v
    }

    /// Una differenza di patrimonio (o di debiti) che conta: almeno 500 € e almeno il 2% del valore di prima.
    static func patrimonioCambiato(da prima: Double, a oggi: Double) -> Bool {
        let d = abs(oggi - prima)
        return d >= sogliaPatrimonio && (prima == 0 || d / abs(prima) >= sogliaPatrimonioQuota)
    }

    /// Regole 15–16: patrimonio per canale (non si giudica) e debiti (sceso → meglio).
    private static func variazioniPatrimonio(_ p: FotografiaRiesame, _ o: FotografiaRiesame) -> [VariazioneRiesame] {
        var v: [VariazioneRiesame] = []
        for c in Canale.allCases where patrimonioCambiato(da: p.patrimonio(c), a: o.patrimonio(c)) {
            v.append(importo(.patrimonio, "patrimonio.\(c.rawValue)", "Patrimonio \(c.nomeBreve)", p.patrimonio(c), o.patrimonio(c),
                             unita: T.euroUnita, scesoMeglio: nil, canale: c))
        }
        if patrimonioCambiato(da: p.debiti, a: o.debiti) {
            v.append(importo(.patrimonio, "patrimonio.debiti", "Debiti", p.debiti, o.debiti, unita: T.euroUnita, scesoMeglio: true))
        }
        return v
    }

    /// Regola 17: completezza dei dati (punti o cambio di livello), solo se rilevata nelle due fotografie.
    private static func variazioniCompletezza(_ p: FotografiaRiesame, _ o: FotografiaRiesame) -> [VariazioneRiesame] {
        guard let a = p.completezza, let b = o.completezza else { return [] }
        let livelloCambiato: Bool = {
            guard let la = p.livelloCompletezza, let lb = o.livelloCompletezza else { return false }
            return la != lb
        }()
        guard abs(b - a) >= sogliaPuntiCompletezza || livelloCambiato else { return [] }
        func breve(_ n: Int, _ livello: String?) -> String {
            guard livelloCambiato, let livello else { return "\(n)%" }
            return "\(n)% · \(livello)"
        }
        return [VariazioneRiesame(tema: .completezza, chiave: "completezza",
                                  testo: "Completezza dei dati \(T.dal(a)) \(T.al(b))",
                                  prima: breve(a, p.livelloCompletezza), oggi: breve(b, o.livelloCompletezza),
                                  differenza: b == a ? nil : T.punti(b - a),
                                  verso: b > a ? .meglio : (b < a ? .peggio : .neutro),
                                  aumento: b == a ? nil : b > a)]
    }

    /// Il grado di uno stato di conformità (più alto = meglio); nil se sconosciuto.
    static func gradoConformita(_ stato: String) -> Int? {
        switch stato {
        case "scaduta": return 0
        case "mancante": return 1
        case "entro30", "entro60": return 2
        case "inRegola": return 3
        default: return nil
        }
    }

    /// Regola 18: le voci di conformità di oggi che prima avevano un'altra etichetta (solo se rilevata nei due lati).
    private static func variazioniConformita(_ p: FotografiaRiesame, _ o: FotografiaRiesame) -> [VariazioneRiesame] {
        guard let prima = p.conformita, let oggi = o.conformita else { return [] }
        var v: [VariazioneRiesame] = []
        for x in oggi {
            guard let y = prima.first(where: { $0.tipo == x.tipo }) else { continue }
            let a = T.statoConformita(y.stato)
            let b = T.statoConformita(x.stato)
            guard a != b else { continue }
            let verso: VariazioneRiesame.Verso
            if let ga = gradoConformita(y.stato), let gb = gradoConformita(x.stato), ga != gb {
                verso = gb > ga ? .meglio : .peggio
            } else {
                verso = .neutro
            }
            let titolo = x.titolo.isEmpty ? (y.titolo.isEmpty ? x.tipo : y.titolo) : x.titolo
            let canale = x.canale ?? y.canale
            let suffisso = canale.map { $0 == .alleanza ? " Alleanza" : " indipendente" } ?? ""
            v.append(VariazioneRiesame(tema: .conformita, chiave: "conformita.\(x.tipo)",
                                       testo: "\(titolo)\(suffisso): da \(a) a \(b)",
                                       prima: a, oggi: b, differenza: nil, verso: verso, aumento: nil, canale: canale))
        }
        return v
    }

    // MARK: - Registrazione

    /// Aggiunge `nuova` all'elenco (di tutti i clienti) con le regole del §3.5 e restituisce l'elenco nuovo:
    /// una fotografia dello stesso cliente a meno di `giorniTraRiesami` giorni viene sostituita (stesso posto, stesso
    /// id, origini unite); oltre `massimoPerCliente` si tolgono le più vecchie. Gli altri clienti non si toccano.
    static func registra(_ nuova: FotografiaRiesame, in elenco: [FotografiaRiesame],
                         cal: Calendar = .current) -> [FotografiaRiesame] {
        var risultato = elenco
        let giorno = cal.startOfDay(for: nuova.data)
        // La più recente dello stesso cliente tra 0 e 29 giorni prima della nuova
        let candidata = risultato.indices
            .filter { i in
                guard risultato[i].clienteId == nuova.clienteId,
                      let g = cal.dateComponents([.day], from: cal.startOfDay(for: risultato[i].data), to: giorno).day else { return false }
                return g >= 0 && g < giorniTraRiesami
            }
            .max { a, b in
                risultato[a].data != risultato[b].data ? risultato[a].data < risultato[b].data : a < b
            }
        if let i = candidata {
            let vecchia = risultato[i]
            var unita = nuova
            unita.id = vecchia.id
            var origini: [String] = []
            for o in vecchia.origini + nuova.origini where !origini.contains(o) { origini.append(o) }
            unita.origini = origini
            risultato[i] = unita
        } else {
            risultato.append(nuova)
        }
        // Tetto per cliente: via le più vecchie (per data; a parità, la prima dell'elenco)
        let mie = risultato.indices.filter { risultato[$0].clienteId == nuova.clienteId }
        if mie.count > massimoPerCliente {
            let ordinate = mie.sorted { a, b in
                risultato[a].data != risultato[b].data ? risultato[a].data < risultato[b].data : a < b
            }
            let via = Set(ordinate.prefix(mie.count - massimoPerCliente))
            risultato = risultato.enumerated().filter { !via.contains($0.offset) }.map(\.element)
        }
        return risultato
    }

    // MARK: - Ordine del giorno

    /// Le note dell'appuntamento con le variazioni in testa (§3.6). Note invariate se `memoria` è nil, se è il primo
    /// riesame o se la prima riga non è «Ordine del giorno:».
    static func apriConVariazioni(_ note: String, memoria: MemoriaRiesame?, massimo: Int = massimoAgenda) -> String {
        guard let m = memoria, let p = m.precedente else { return note }
        let righe = note.components(separatedBy: "\n")
        guard righe.first == rigaOrdineDelGiorno else { return note }
        var nuove = [rigaOrdineDelGiorno]
        if m.variazioni.isEmpty {
            nuove.append(T.nessunaVariazione(data: p.data))
        } else {
            nuove.append("Cosa è cambiato dal riesame del \(T.data(p.data)):")
            let quante = max(0, massimo)
            for v in m.variazioni.prefix(quante) { nuove.append("• \(v.testo)") }
            let resto = m.variazioni.count - quante
            if resto == 1 {
                nuove.append("…e un'altra variazione nel prospetto del riesame.")
            } else if resto > 1 {
                nuove.append("…e altre \(resto) variazioni nel prospetto del riesame.")
            }
        }
        nuove.append("Punti da trattare:")
        nuove += righe.dropFirst()
        return nuove.joined(separator: "\n")
    }

    // MARK: - Aiuti

    /// Un numero finito (NaN e infiniti → nil): niente cifre impossibili nelle fotografie.
    static func finito(_ v: Double) -> Double? { v.isFinite ? v : nil }
}
