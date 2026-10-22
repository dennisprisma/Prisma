import AppKit
import Combine
import SwiftUI

/// Stato della finestra Prisma: dati dell'archivio, finestre interne, backup, avvisi.
enum VistaAgenda: Hashable { case settimana, mese }

enum FiltroAttivita: Hashable { case aperte, completate, tutte }

enum SchedaSimulazioni: Hashable { case simulatore, scenari }

enum SchedaIncontro: Hashable { case preparazione, ascolto, passi }

/// Ciò che si può mettere a confronto: una posizione (in essere o proposta) o uno scenario salvato.
enum VoceConfronto: Hashable {
    case posizione(String)
    case simulazione(String)
}

final class StatoShell: ObservableObject {
    struct Finestra: Identifiable, Equatable {
        let app: AppPrisma
        var id: AppPrisma { app }
        /// Cornice quando non è ingrandita, nelle coordinate dell'area delle finestre.
        var cornice: CGRect
        var ingrandita = true
        var ridotta = false
    }

    /// Dati dell'archivio locale: ogni modifica viene salvata da sola.
    @Published var dati: DatiPrisma

    /// Finestre aperte; l'ultima è quella in primo piano.
    @Published private(set) var finestre: [Finestra] = []
    @Published private(set) var avviso: String?
    @Published var schermoIntero = false
    @Published var schedaImpostazioni: SchedaImpostazioni = .esperienza
    @Published var schedaCliente: SchedaCliente = .panoramica
    /// Posizione aperta nel dettaglio (usata anche dalle istantanee).
    @Published var posizioneInDettaglio: String?
    /// Il pulsante dell'intestazione di Posizioni chiede di aprire il modulo (nuova posizione o proposta).
    @Published var richiestaNuovaPosizione: StatoPosizione?
    /// Il pulsante "Nuovo cliente" dell'intestazione chiede alla rubrica di aprire il modulo.
    @Published var richiestaNuovoCliente = false

    // Agenda e Attività (stato delle viste, non salvato)
    /// Giornata aperta in agenda.
    @Published var giornoAgenda = Calendar.current.startOfDay(for: Date())
    @Published var vistaAgenda: VistaAgenda = .settimana
    @Published var appuntamentoSelezionato: String?
    /// nil = tutti i clienti.
    @Published var filtroClienteAgenda: String?
    @Published var attivitaSelezionata: String?
    @Published var filtroStatoAttivita: FiltroAttivita = .aperte
    @Published var filtroClienteAttivita: String?
    @Published var filtroPrioritaAttivita: Attivita.Priorita?
    /// Il pulsante dell'intestazione di Attività chiede di aprire il modulo.
    @Published var richiestaNuovaAttivita = false

    // Strumenti di analisi (stato delle viste, non salvato)
    /// Area aperta in Analisi 360 (nil = panoramica).
    @Published var areaAnalisi: AreaAnalisi?
    /// Ipotesi sul tavolo del simulatore.
    @Published var bozzaSimulazione: Simulazione?
    @Published var schedaSimulazioni: SchedaSimulazioni = .simulatore
    /// Scenari scelti per il confronto nella scheda Scenari.
    @Published var scenariConfrontati: Set<String> = []
    @Published var confrontoA: VoceConfronto?
    @Published var confrontoB: VoceConfronto?
    /// Orizzonte comune del confronto (nil = ognuno il suo).
    @Published var orizzonteConfronto: Int?
    /// Orizzonte scelto per la sostituzione (nil: la durata della proposta o l'orizzonte del cliente).
    @Published var orizzonteSostituzione: Int?

    // Incontri
    @Published var incontroAperto: String?
    @Published var schedaIncontro: SchedaIncontro = .preparazione
    /// Proposte ricavate dagli appunti (per incontro) e quelle scelte per entrare nel dossier.
    @Published var proposteIncontro: [String: [PropostaIncontro]] = [:]
    @Published var proposteScelte: Set<String> = []
    @Published var estrazioneInCorso = false

    // Prodotti e Obiettivi
    @Published var prodottoSelezionato: String?
    @Published var filtroCanaleProdotti: Canale?
    @Published var filtroAreaProdotti: AreaPosizione?
    @Published var obiettivoSelezionato: String?

    // Documenti
    @Published var documentoSelezionato: String?
    @Published var documentiInLettura: Set<String> = []

    // Prospetti e report
    /// Prospetto scelto (nil = quadro delle posizioni del cliente attivo).
    @Published var prospetto: SceltaProspetto?
    /// Valutazione aperta nel modulo di modifica.
    @Published var valutazioneInModifica: ValutazioneInvestimento?
    private var testiDocumenti: [String: [String]] = [:]

    // Eve
    @Published var eveInCorso = false
    @Published var domandaEve = ""
    /// Conversazioni non conservate nell'archivio (se l'utente lo sceglie nelle impostazioni).
    @Published var conversazioniTemporanee: [String: [MessaggioEve]] = [:]

    // Backup
    @Published private(set) var elencoBackup: [VoceBackup] = []
    @Published private(set) var backupInCorso = false

    /// Area disponibile per le finestre (sotto la barra, sopra il dock), aggiornata dalla vista.
    var area: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 700)

    /// false nelle istantanee: niente disco, niente animazioni.
    let persistente: Bool

    private var lavoroAvviso: DispatchWorkItem?
    private var abbonamenti = Set<AnyCancellable>()
    private var timerBackup: Timer?
    private var salvataggioSospeso = false

    init(persistente: Bool = true) {
        self.persistente = persistente
        if persistente {
            let caricati = Archivio.carica()
            dati = caricati.dati
            if let a = caricati.avviso {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.mostraAvviso(a) }
            }
            avviaSalvataggio()
            avviaBackupAutomatico()
            aggiornaElencoBackup()
        } else {
            dati = DatiPrisma.demo()
        }
    }

    // MARK: - Lettura

    var clienti: [Cliente] { dati.clienti }
    var appuntamenti: [Appuntamento] { dati.appuntamenti }
    var attivita: [Attivita] { dati.attivita }
    var nomeUtente: String { dati.impostazioni.nomeUtente }
    var inizialiUtente: String { dati.impostazioni.inizialiUtente }

    var clienteAttivoId: String {
        get { dati.clienteAttivoId }
        set { dati.clienteAttivoId = newValue }
    }

    var clienteAttivo: Cliente? { clienti.first { $0.id == clienteAttivoId } }

    var finestreVisibili: [Finestra] { finestre.filter { !$0.ridotta } }

    /// App in primo piano (nil = scrivania).
    var appAttiva: AppPrisma? { finestreVisibili.last?.app }

    func aperta(_ app: AppPrisma) -> Bool { finestre.contains { $0.app == app } }

    func cliente(_ id: String) -> Cliente? { clienti.first { $0.id == id } }

    var prossimiAppuntamenti: [Appuntamento] {
        let inizio = Calendar.current.startOfDay(for: Date())
        return appuntamenti
            .filter { $0.inizio >= inizio && $0.stato == .pianificato }
            .sorted { $0.inizio < $1.inizio }
    }

    var appuntamentiDiOggi: [Appuntamento] {
        appuntamenti.filter { Calendar.current.isDateInToday($0.inizio) && $0.stato == .pianificato }
    }

    var attivitaAperte: [Attivita] {
        attivita.filter { !$0.completata }.sorted { $0.scadenza < $1.scadenza }
    }

    // MARK: - Finestre

    private func anima(_ cambia: () -> Void) {
        if persistente { withAnimation(Animazioni.apertura, cambia) } else { cambia() }
    }

    func apri(_ app: AppPrisma) {
        anima {
            if let i = finestre.firstIndex(where: { $0.app == app }) {
                var f = finestre.remove(at: i)
                f.ridotta = false
                finestre.append(f)
            } else {
                finestre.append(Finestra(app: app, cornice: corniceIniziale()))
            }
        }
        if app == .impostazioni { aggiornaElencoBackup() }
    }

    func primoPiano(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), i != finestre.count - 1 else { return }
        let f = finestre.remove(at: i)
        finestre.append(f)
    }

    func chiudi(_ app: AppPrisma) {
        anima { finestre.removeAll { $0.app == app } }
    }

    func riduci(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }) else { return }
        anima { finestre[i].ridotta = true }
    }

    func alternaIngrandimento(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }) else { return }
        anima {
            finestre[i].ingrandita.toggle()
            if !finestre[i].ingrandita {
                finestre[i].cornice = limita(finestre[i].cornice)
            }
        }
        primoPiano(app)
    }

    /// Riduce tutte le finestre e mostra la scrivania.
    func mostraScrivania() {
        anima {
            for i in finestre.indices { finestre[i].ridotta = true }
        }
    }

    func sposta(_ app: AppPrisma, origine: CGPoint) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), !finestre[i].ingrandita else { return }
        var c = finestre[i].cornice
        c.origin = origine
        finestre[i].cornice = limita(c)
    }

    func ridimensiona(_ app: AppPrisma, dimensione: CGSize) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), !finestre[i].ingrandita else { return }
        var c = finestre[i].cornice
        c.size = CGSize(width: max(Misure.Finestra.minima.width, dimensione.width),
                        height: max(Misure.Finestra.minima.height, dimensione.height))
        finestre[i].cornice = limita(c)
    }

    /// Cornice effettiva da disegnare.
    func cornice(di f: Finestra) -> CGRect {
        f.ingrandita ? CGRect(origin: .zero, size: area.size) : limita(f.cornice)
    }

    private func corniceIniziale() -> CGRect {
        let l = max(Misure.Finestra.minima.width, area.width * 0.72)
        let a = max(Misure.Finestra.minima.height, area.height * 0.8)
        let passo = CGFloat(finestre.count % 6) * 24
        return CGRect(x: (area.width - l) / 2 + passo, y: (area.height - a) / 3 + passo, width: l, height: a)
    }

    /// Tiene la finestra dentro l'area (la barra del titolo resta sempre raggiungibile).
    private func limita(_ c: CGRect) -> CGRect {
        var r = c
        r.size.width = min(r.width, area.width)
        r.size.height = min(r.height, area.height)
        r.origin.x = min(max(r.minX, 0), area.width - r.width)
        r.origin.y = min(max(r.minY, 0), area.height - r.height)
        return r
    }

    // MARK: - Clienti

    /// Aggiunge o aggiorna un cliente e lo mette in primo piano.
    func salvaCliente(_ cliente: Cliente) {
        var c = cliente
        c.nome = c.nome.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.iniziali.trimmingCharacters(in: .whitespaces).isEmpty { c.iniziali = Cliente.iniziali(di: c.nome) }
        if let i = dati.clienti.firstIndex(where: { $0.id == c.id }) {
            dati.clienti[i] = c
        } else {
            dati.clienti.append(c)
        }
        dati.clienteAttivoId = c.id
    }

    /// Elimina un cliente con i suoi appuntamenti e attività.
    func eliminaCliente(_ id: String) {
        dati.clienti.removeAll { $0.id == id }
        dati.appuntamenti.removeAll { $0.clienteId == id }
        dati.attivita.removeAll { $0.clienteId == id }
        dati.posizioni.removeAll { $0.clienteId == id }
        dati.simulazioni.removeAll { $0.clienteId == id }
        dati.analisi[id] = nil
        dati.conversazioni[id] = nil
        dati.incontri.removeAll { $0.clienteId == id }
        dati.obiettivi.removeAll { $0.clienteId == id }
        dati.valutazioni.removeAll { $0.clienteId == id }
        for d in dati.documenti where d.clienteId == id { rimuoviFile(d) }
        dati.documenti.removeAll { $0.clienteId == id }
        if dati.clienteAttivoId == id {
            dati.clienteAttivoId = dati.clienti.first?.id ?? ""
        }
    }

    func alternaPreferito(_ id: String) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == id }) else { return }
        dati.clienti[i].preferito.toggle()
    }

    func aggiornaNota(_ id: String, _ testo: String) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == id }), dati.clienti[i].nota != testo else { return }
        dati.clienti[i].nota = testo
    }

    /// Tinta per un nuovo cliente, a rotazione.
    var prossimaTinta: TintaAvatar {
        let tinte: [TintaAvatar] = [.blu, .rosa, .verde, .viola, .oro]
        return tinte[dati.clienti.count % tinte.count]
    }

    func appuntamentiCliente(_ id: String) -> [Appuntamento] {
        appuntamenti.filter { $0.clienteId == id }.sorted { $0.inizio < $1.inizio }
    }

    func attivitaCliente(_ id: String) -> [Attivita] {
        attivita.filter { $0.clienteId == id }.sorted { $0.scadenza < $1.scadenza }
    }

    // MARK: - Posizioni

    var posizioni: [Posizione] { dati.posizioni }

    func posizioniCliente(_ id: String) -> [Posizione] {
        dati.posizioni.filter { $0.clienteId == id }
    }

    func salvaPosizione(_ posizione: Posizione) {
        if let i = dati.posizioni.firstIndex(where: { $0.id == posizione.id }) {
            // Il valore che cambia resta nello storico, per il resoconto
            var nuova = posizione
            nuova.registraValorePrecedente(dati.posizioni[i])
            dati.posizioni[i] = nuova
        } else {
            dati.posizioni.append(posizione)
        }
    }

    func eliminaPosizione(_ id: String) {
        dati.posizioni.removeAll { $0.id == id }
    }

    /// Una proposta accettata diventa una posizione in essere.
    func attivaProposta(_ id: String) {
        guard let i = dati.posizioni.firstIndex(where: { $0.id == id }) else { return }
        dati.posizioni[i].stato = .inEssere
        dati.posizioni[i].esito = .accettata
        if dati.posizioni[i].decorrenza == nil { dati.posizioni[i].decorrenza = Date() }
        if dati.posizioni[i].totaleVersato == nil { dati.posizioni[i].totaleVersato = dati.posizioni[i].versamentoIniziale }
        if dati.posizioni[i].controvalore == nil { dati.posizioni[i].controvalore = dati.posizioni[i].versamentoIniziale }
    }

    /// Apre una posizione nel dettaglio di Posizioni.
    func apriPosizione(_ p: Posizione) {
        clienteAttivoId = p.clienteId
        apri(.posizioni)
        // Dopo il cambio di cliente, che in Posizioni chiude il dettaglio aperto
        DispatchQueue.main.async { self.posizioneInDettaglio = p.id }
    }

    func apriCliente(_ id: String) {
        clienteAttivoId = id
        schedaCliente = .panoramica
        apri(.clienti)
    }

    /// Posizioni in essere che scadono nel giorno indicato (lo scadenzario dell'agenda).
    func scadenzeDelGiorno(_ giorno: Date) -> [Posizione] {
        let cal = Calendar.current
        return dati.posizioni.filter { p in
            guard p.stato == .inEssere, let s = p.scadenza else { return false }
            return cal.isDate(s, inSameDayAs: giorno) && (filtroClienteAgenda == nil || p.clienteId == filtroClienteAgenda)
        }
    }

    // MARK: - Documenti

    func documentiCliente(_ id: String) -> [Documento] {
        dati.documenti.filter { $0.clienteId == id }.sorted { $0.importatoIl > $1.importatoIl }
    }

    func documento(_ id: String?) -> Documento? {
        guard let id else { return nil }
        return dati.documenti.first { $0.id == id }
    }

    func urlDocumento(_ d: Documento) -> URL? {
        d.file.map { Archivio.cartellaDocumenti.appendingPathComponent($0) }
    }

    private func urlTesto(_ d: Documento) -> URL? {
        urlDocumento(d).map { $0.deletingPathExtension().appendingPathExtension("txt") }
    }

    /// Testo del documento, pagina per pagina (dal file accanto al documento o dai dati di prova).
    func testoDocumento(_ d: Documento) -> [String] {
        if let t = testiDocumenti[d.id] { return t }
        var pagine = DatiDemo.testoDocumento(d.id) ?? []
        if pagine.isEmpty, let url = urlTesto(d), let t = try? String(contentsOf: url, encoding: .utf8) {
            pagine = t.components(separatedBy: LetturaDocumenti.separatorePagine)
        }
        testiDocumenti[d.id] = pagine
        return pagine
    }

    private func aggiornaDocumento(_ id: String, _ cambia: (inout Documento) -> Void) {
        guard let i = dati.documenti.firstIndex(where: { $0.id == id }) else { return }
        cambia(&dati.documenti[i])
    }

    /// Copia i file nella cartella Documenti del cliente e li legge.
    func importaDocumenti(_ urls: [URL]) {
        guard persistente else { return }
        let fm = FileManager.default
        let cliente = clienteAttivoId
        let cartella = Archivio.cartellaDocumenti.appendingPathComponent(cliente, isDirectory: true)
        try? fm.createDirectory(at: cartella, withIntermediateDirectories: true)
        var ultimo: String?
        for url in urls where LetturaDocumenti.estensioniAccettate.contains(url.pathExtension.lowercased()) {
            var d = Documento(clienteId: cliente, titolo: url.deletingPathExtension().lastPathComponent, tipo: .altro)
            d.importatoIl = Appuntamento.alMinuto(Date())
            let nome = "\(d.id).\(url.pathExtension.lowercased())"
            let destinazione = cartella.appendingPathComponent(nome)
            do {
                try fm.copyItem(at: url, to: destinazione)
            } catch {
                mostraAvviso("Non riesco a copiare \(url.lastPathComponent): \(error.localizedDescription)")
                continue
            }
            d.file = "\(cliente)/\(nome)"
            d.dimensione = (try? fm.attributesOfItem(atPath: destinazione.path)[.size] as? Int64) ?? 0
            dati.documenti.append(d)
            ultimo = d.id
            leggiDocumento(d.id)
        }
        if let ultimo { documentoSelezionato = ultimo }
    }

    /// Legge il testo (PDFKit, poi Vision per le scansioni) e cerca i dati; il modello Apple completa.
    func leggiDocumento(_ id: String) {
        guard let d = documento(id), let url = urlDocumento(d), let testo = urlTesto(d) else { return }
        documentiInLettura.insert(id)
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = LetturaDocumenti.leggi(url)
            if let esito {
                try? esito.pagine.joined(separator: LetturaDocumenti.separatorePagine).write(to: testo, atomically: true, encoding: .utf8)
            }
            DispatchQueue.main.async {
                guard let esito else {
                    self.aggiornaDocumento(id) { $0.lettura = .illeggibile }
                    self.documentiInLettura.remove(id)
                    self.mostraAvviso("Non riesco a leggere \(d.titolo)")
                    return
                }
                self.testiDocumenti[id] = esito.pagine
                let campi = EstrattoreDocumento.conRegole(esito.pagine)
                self.aggiornaDocumento(id) { x in
                    x.pagine = esito.pagine.count
                    x.pagineOCR = esito.pagineOCR
                    x.lettura = esito.pagine.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .illeggibile : .letto
                    if x.tipo == .altro { x.tipo = EstrattoreDocumento.tipoProbabile(esito.pagine) }
                    x.campi = campi
                }
                self.completaConModello(id, pagine: esito.pagine, trovati: campi)
            }
        }
    }

    /// Il modello Apple legge le prime pagine e propone i campi che le regole non hanno trovato.
    private func completaConModello(_ id: String, pagine: [String], trovati: [CampoEstratto]) {
        guard dati.impostazioni.eve.motore != .sintesi, MotoriEve.motivoAppleNonDisponibile == nil,
              trovati.count < CampoDocumento.allCases.count else {
            documentiInLettura.remove(id)
            return
        }
        Task { @MainActor in
            var modello: [CampoEstratto] = []
            for (n, pagina) in pagine.prefix(6).enumerated() where pagina.count > 80 {
                if let r = try? await MotoriEve.generaConApple(istruzioni: EstrattoreDocumento.istruzioniModello,
                                                               richiesta: "PAGINA \(n + 1)\n" + String(pagina.prefix(3_000))) {
                    modello += EstrattoreDocumento.daRisposta(r, pagina: n + 1)
                }
            }
            let uniti = EstrattoreDocumento.unisci(trovati, modello)
            self.aggiornaDocumento(id) { $0.campi = uniti }
            self.documentiInLettura.remove(id)
        }
    }

    func confermaCampo(_ id: String, _ chiave: CampoDocumento, _ si: Bool) {
        aggiornaDocumento(id) { d in
            if let i = d.campi.firstIndex(where: { $0.chiave == chiave }) { d.campi[i].confermato = si }
        }
    }

    func modificaCampo(_ id: String, _ chiave: CampoDocumento, valore: String) {
        aggiornaDocumento(id) { d in
            if let i = d.campi.firstIndex(where: { $0.chiave == chiave }) {
                d.campi[i].valore = valore
                d.campi[i].confermato = true
            }
        }
    }

    func rinominaDocumento(_ id: String, titolo: String, tipo: Documento.Tipo) {
        aggiornaDocumento(id) { $0.titolo = titolo; $0.tipo = tipo }
    }

    private func rimuoviFile(_ d: Documento) {
        guard persistente else { return }
        if let u = urlDocumento(d) { try? FileManager.default.removeItem(at: u) }
        if let t = urlTesto(d) { try? FileManager.default.removeItem(at: t) }
    }

    func eliminaDocumento(_ id: String) {
        guard let d = documento(id) else { return }
        rimuoviFile(d)
        dati.documenti.removeAll { $0.id == id }
        testiDocumenti[id] = nil
        if documentoSelezionato == id { documentoSelezionato = nil }
    }

    // MARK: - Prospetti

    /// Il prospetto da mostrare per il cliente attivo. Una scelta di un altro cliente torna alla prima
    /// valutazione del cliente, o al resoconto delle posizioni se non ne ha.
    var sceltaProspetto: SceltaProspetto {
        let predefinita: SceltaProspetto = valutazioniCliente(clienteAttivoId).first.map { .valutazione($0.id, report: false) } ?? .resoconto(report: false)
        switch prospetto {
        case .posizione(let id)? where posizioni.contains(where: { $0.id == id && $0.clienteId == clienteAttivoId }):
            return .posizione(id)
        case .valutazione(let id, let report)?:
            // Se la valutazione non è di questo cliente, la sua prima; se non ne ha, la pagina vuota con "Nuova valutazione"
            let elenco = valutazioniCliente(clienteAttivoId)
            return .valutazione(elenco.contains { $0.id == id } ? id : (elenco.first?.id ?? ""), report: report)
        case .resoconto(let report)?:
            return .resoconto(report: report)
        case .previdenza(let report)?:
            return .previdenza(report: report)
        case .protezione(let report)?:
            return .protezione(report: report)
        case .sostituzione(let a, let b, let report)?:
            let mie = posizioniCliente(clienteAttivoId)
            if a != b, mie.contains(where: { $0.id == a }), mie.contains(where: { $0.id == b }) { return .sostituzione(a, b, report: report) }
            let coppia = MotoreSostituzione.coppia(mie)
            return .sostituzione(coppia?.0 ?? "", coppia?.1 ?? "", report: report)
        case .confronto(let a, let b)?:
            let voci = ElementoConfronto.elenco(dati, cliente: clienteAttivoId)
            if voci.contains(where: { $0.voce == a }) && voci.contains(where: { $0.voce == b }) { return .confronto(a, b) }
            return predefinita
        default:
            return predefinita
        }
    }

    /// Il documento da mostrare e stampare per una scelta.
    func documentoProspetto(_ scelta: SceltaProspetto) -> DocumentoStampabile? {
        if case .valutazione(let id, let report) = scelta {
            return valutazione(id).flatMap(testiValutazione).map { DocumentoStampabile($0, report: report) }
        }
        if case .sostituzione(let a, let b, let report) = scelta {
            return testiSostituzione(a, b).map { DocumentoStampabile($0, report: report) }
        }
        if case .protezione(let report) = scelta {
            return DocumentoStampabile(testiProtezione(clienteAttivoId), report: report)
        }
        if case .previdenza(let report) = scelta {
            return DocumentoStampabile(testiPrevidenza(clienteAttivoId), report: report)
        }
        if case .resoconto(let report) = scelta {
            return DocumentoStampabile(testiResoconto(clienteAttivoId), report: report)
        }
        return contenutoProspetto(scelta).map { DocumentoStampabile($0) }
    }

    /// I testi e i numeri della protezione della famiglia di un cliente (ipotesi dall'Analisi 360).
    func testiProtezione(_ id: String) -> TestiProtezione {
        let intestatario = self.cliente(id)
        let e = MotoreProtezioneFamiglia.calcola(posizioniCliente(id), cliente: intestatario, analisi: analisi360(id).protezione)
        return TestiProtezione(e, cliente: intestatario)
    }

    /// I testi e i numeri del piano previdenziale di un cliente (ipotesi dall'Analisi 360).
    func testiPrevidenza(_ id: String) -> TestiPrevidenza {
        let intestatario = self.cliente(id)
        let e = MotorePrevidenza.calcola(posizioniCliente(id), cliente: intestatario, analisi: analisi360(id).previdenza)
        return TestiPrevidenza(e, cliente: intestatario)
    }

    /// I testi e i numeri della sostituzione di `a` con `b` (o del confronto tra due proposte).
    func testiSostituzione(_ a: String, _ b: String) -> TestiSostituzione? {
        guard a != b, let pa = posizioni.first(where: { $0.id == a }), let pb = posizioni.first(where: { $0.id == b }) else { return nil }
        let intestatario = self.cliente(pa.clienteId)
        let e = MotoreSostituzione.calcola(attuale: pa, alternativa: pb, prodotti: dati.prodotti, anni: orizzonteSostituzione,
                                           orizzonteCliente: intestatario?.profilo.orizzonteAnni)
        return TestiSostituzione(e, cliente: intestatario)
    }

    /// I testi e i numeri del resoconto delle posizioni in essere di un cliente.
    func testiResoconto(_ cliente: String) -> TestiResoconto {
        TestiResoconto(posizioniCliente(cliente), cliente: self.cliente(cliente), prodotti: dati.prodotti)
    }

    func contenutoProspetto(_ scelta: SceltaProspetto) -> ContenutoProspetto? {
        CompositoreProspetti.componi(scelta, dati: dati, cliente: clienteAttivoId, orizzonteConfronto: orizzonteConfronto)
    }

    /// Apre Prospetti e report su una scelta precisa (dal dettaglio di una posizione o da Confronti).
    func apriProspetto(_ scelta: SceltaProspetto) {
        prospetto = scelta
        apri(.presentazioni)
    }

    /// Il confronto proposto di partenza: quello aperto in Confronti o la proposta contro la posizione in essere.
    func confrontoPredefinito() -> SceltaProspetto? {
        let voci = ElementoConfronto.elenco(dati, cliente: clienteAttivoId)
        let coppia = ElementoConfronto.coppia(voci, a: confrontoA, b: confrontoB, posizioni: posizioniCliente(clienteAttivoId))
        guard let a = coppia.0, let b = coppia.1 else { return nil }
        return .confronto(a.voce, b.voce)
    }

    /// Salva il PDF nella cartella Documenti del cliente: entra nei backup e si ritrova in Documenti.
    @discardableResult
    func archiviaProspetto(_ pdf: Data, documento: DocumentoStampabile) -> String? {
        let cliente = clienteAttivoId
        var d = Documento(clienteId: cliente, titolo: "\(documento.genere) · \(documento.titolo)", tipo: documento.tipo)
        d.importatoIl = Appuntamento.alMinuto(Date())
        d.lettura = .letto
        let pagine = StampaCarta.testo(pdf)
        d.pagine = pagine.count
        d.dimensione = Int64(pdf.count)
        if persistente {
            let cartella = Archivio.cartellaDocumenti.appendingPathComponent(cliente, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
                try pdf.write(to: cartella.appendingPathComponent("\(d.id).pdf"))
                try? pagine.joined(separator: LetturaDocumenti.separatorePagine)
                    .write(to: cartella.appendingPathComponent("\(d.id).txt"), atomically: true, encoding: .utf8)
            } catch {
                mostraAvviso("Non riesco a salvare il prospetto: \(error.localizedDescription)")
                return nil
            }
            d.file = "\(cliente)/\(d.id).pdf"
        }
        testiDocumenti[d.id] = pagine
        dati.documenti.append(d)
        return d.id
    }

    // MARK: - Valutazioni d'investimento

    func valutazioniCliente(_ id: String) -> [ValutazioneInvestimento] {
        dati.valutazioni.filter { $0.clienteId == id }.sorted { $0.creataIl > $1.creataIl }
    }

    func valutazione(_ id: String?) -> ValutazioneInvestimento? {
        guard let id else { return nil }
        return dati.valutazioni.first { $0.id == id }
    }

    /// I testi e i calcoli di una valutazione (serve un prodotto con le condizioni del contratto).
    func testiValutazione(_ v: ValutazioneInvestimento) -> TestiValutazione? {
        guard let p = prodotto(v.prodottoId), let c = p.condizioni else { return nil }
        return TestiValutazione(v, prodotto: p, condizioni: c)
    }

    /// Prodotti con le condizioni dettagliate, utilizzabili per una valutazione.
    var prodottiValutabili: [Prodotto] { dati.prodotti.filter { $0.condizioni != nil }.sorted { $0.nome < $1.nome } }

    func salvaValutazione(_ v: ValutazioneInvestimento) {
        if let i = dati.valutazioni.firstIndex(where: { $0.id == v.id }) {
            dati.valutazioni[i] = v
        } else {
            dati.valutazioni.append(v)
        }
        prospetto = .valutazione(v.id, report: false)
    }

    func eliminaValutazione(_ id: String) {
        dati.valutazioni.removeAll { $0.id == id }
        if case .valutazione(id, _)? = prospetto { prospetto = nil }
    }

    /// Dal dettaglio di una proposta: apre la sua valutazione o ne prepara una nuova.
    func valutaPosizione(_ p: Posizione) {
        clienteAttivoId = p.clienteId
        if let v = dati.valutazioni.first(where: { $0.posizioneId == p.id }) {
            apriProspetto(.valutazione(v.id, report: false))
        } else if let v = nuovaValutazione(posizione: p) {
            apri(.presentazioni)
            valutazioneInModifica = v
        }
    }

    /// Dalla scheda prodotto: una nuova valutazione per il cliente attivo, da completare nel modulo.
    func valutaProdotto(_ id: String) {
        guard let v = nuovaValutazione(prodotto: id) else { return }
        apri(.presentazioni)
        valutazioneInModifica = v
    }

    /// Una nuova valutazione per il cliente attivo, con ipotesi di partenza da rivedere.
    func nuovaValutazione(prodotto id: String? = nil, posizione: Posizione? = nil) -> ValutazioneInvestimento? {
        guard let p = prodotto(id ?? posizione?.prodottoId) ?? prodottiValutabili.first, let c = p.condizioni else { return nil }
        let cliente = clienteAttivoId
        var v = ValutazioneInvestimento(clienteId: cliente, intestatari: self.cliente(cliente)?.nome ?? "", prodottoId: p.id,
                                        premio: posizione.map { $0.versamentoIniziale > 0 ? $0.versamentoIniziale : 10_000 } ?? 10_000)
        v.posizioneId = posizione?.id
        v.data = Calendar.current.startOfDay(for: Date())
        v.creataIl = Appuntamento.alMinuto(Date())
        v.scenari = ValutazioneInvestimento.ipotesiDiPartenza(c)
        return v
    }

    /// Scheda prodotto con i soli dati confermati.
    func creaProdotto(da id: String, canale: Canale, area: AreaPosizione) {
        guard let d = documento(id) else { return }
        var p = Prodotto(nome: d.confermato(.nomeProdotto) ?? d.titolo, canale: canale, area: area)
        p.emittente = d.confermato(.emittente) ?? ""
        p.tipologia = d.confermato(.tipologia) ?? ""
        p.sri = d.confermato(.sri).flatMap { Int($0.prefix(1)) }
        p.costoIngresso = EstrattoreDocumento.numero(d.confermato(.costoIngresso))
        p.costoAnnuo = EstrattoreDocumento.numero(d.confermato(.costoAnnuo)) ?? EstrattoreDocumento.numero(d.confermato(.incidenzaCosti))
        p.rendimentoAtteso = EstrattoreDocumento.numero(d.confermato(.rendimentoModerato))
        p.fonte = "\(d.titolo) (\(d.tipo.breve), importato il \(Formati.dataBreve.string(from: d.importatoIl)))"
        p.verificatoIl = Calendar.current.startOfDay(for: Date())
        if let anni = d.confermato(.periodoDetenzione) { p.note = "Periodo di detenzione raccomandato: \(anni) anni." }
        salvaProdotto(p)
        aggiornaDocumento(id) { $0.prodottoId = p.id }
        mostraAvviso("Scheda prodotto creata: \(p.nome)")
    }

    /// Posizione in essere del cliente con i soli dati confermati.
    func creaPosizione(da id: String, canale: Canale, area: AreaPosizione) {
        guard let d = documento(id) else { return }
        var p = Posizione(clienteId: d.clienteId, canale: canale, stato: .inEssere, area: area, nome: d.confermato(.nomeProdotto) ?? d.titolo)
        p.emittente = d.confermato(.emittente) ?? (canale == .alleanza ? "Alleanza Assicurazioni" : "")
        p.tipologia = d.confermato(.tipologia) ?? ""
        p.numeroContratto = d.confermato(.numeroContratto) ?? ""
        p.contraente = d.confermato(.contraente) ?? ""
        p.assicurato = d.confermato(.assicurato) ?? ""
        p.beneficiari = d.confermato(.beneficiari) ?? ""
        p.decorrenza = EstrattoreDocumento.data(d.confermato(.decorrenza))
        p.scadenza = EstrattoreDocumento.data(d.confermato(.scadenza))
        if let premio = EstrattoreDocumento.numero(d.confermato(.premio)) {
            p.premio = premio
            p.frequenza = .annuale
        }
        p.capitaleAssicurato = EstrattoreDocumento.numero(d.confermato(.capitaleAssicurato))
        p.controvalore = EstrattoreDocumento.numero(d.confermato(.controvalore))
        p.costoAnnuo = EstrattoreDocumento.numero(d.confermato(.costoAnnuo))
        p.costoIngresso = EstrattoreDocumento.numero(d.confermato(.costoIngresso))
        p.sri = d.confermato(.sri).flatMap { Int($0.prefix(1)) }
        p.note = "Dati dal documento «\(d.titolo)», da completare."
        salvaPosizione(p)
        aggiornaDocumento(id) { $0.posizioneId = p.id }
        apriPosizione(p)
    }

    // MARK: - Prodotti

    var prodotti: [Prodotto] { dati.prodotti.sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending } }

    func prodotto(_ id: String?) -> Prodotto? {
        guard let id else { return nil }
        return dati.prodotti.first { $0.id == id }
    }

    func salvaProdotto(_ p: Prodotto) {
        if let i = dati.prodotti.firstIndex(where: { $0.id == p.id }) { dati.prodotti[i] = p } else { dati.prodotti.append(p) }
        prodottoSelezionato = p.id
    }

    func eliminaProdotto(_ id: String) {
        dati.prodotti.removeAll { $0.id == id }
        for i in dati.posizioni.indices where dati.posizioni[i].prodottoId == id { dati.posizioni[i].prodottoId = nil }
        if prodottoSelezionato == id { prodottoSelezionato = nil }
    }

    /// Posizioni e proposte (di tutti i clienti) nate da una scheda.
    func posizioniDelProdotto(_ id: String) -> [Posizione] {
        dati.posizioni.filter { $0.prodottoId == id }
    }

    /// Crea una proposta per il cliente attivo con le condizioni della scheda e la apre in Posizioni.
    func proponi(_ p: Prodotto) {
        let proposta = p.proposta(per: clienteAttivoId)
        salvaPosizione(proposta)
        apriPosizione(proposta)
        mostraAvviso("Proposta creata per \(clienteAttivo?.nome ?? "il cliente"): completa importi e durata")
    }

    func simula(_ p: Prodotto) {
        var s = Simulazione(clienteId: clienteAttivoId, titolo: p.nome)
        s.capitale = 10_000
        s.versamentoMensile = 100
        s.rendimento = p.rendimentoAtteso ?? IpotesiCalcolo.rendimentoPredefinito
        s.costoIngresso = p.costoIngresso ?? 0
        s.costoAnnuo = p.costoAnnuo ?? 0
        s.aliquota = p.aliquotaFiscale ?? IpotesiCalcolo.aliquotaPredefinita
        s.canale = p.canale
        bozzaSimulazione = s
        schedaSimulazioni = .simulatore
        apri(.simulazioni)
    }

    // MARK: - Obiettivi

    func obiettiviCliente(_ id: String) -> [Obiettivo] {
        dati.obiettivi.filter { $0.clienteId == id }.sorted {
            $0.priorita != $1.priorita ? $0.priorita > $1.priorita : $0.scadenza < $1.scadenza
        }
    }

    func salvaObiettivo(_ o: Obiettivo) {
        if let i = dati.obiettivi.firstIndex(where: { $0.id == o.id }) { dati.obiettivi[i] = o } else { dati.obiettivi.append(o) }
        obiettivoSelezionato = o.id
    }

    func eliminaObiettivo(_ id: String) {
        dati.obiettivi.removeAll { $0.id == id }
        if obiettivoSelezionato == id { obiettivoSelezionato = nil }
    }

    /// Porta l'obiettivo nel simulatore: capitale già da parte e il versamento necessario.
    func simula(_ o: Obiettivo) {
        let a = AvanzamentoObiettivo(o, posizioni: posizioniCliente(o.clienteId))
        var s = Simulazione(clienteId: o.clienteId, titolo: o.titolo)
        s.capitale = a.accantonato
        s.versamentoMensile = ((a.versamentoNecessario ?? 0) / 10).rounded(.up) * 10
        s.anni = max(1, Int((Double(o.mesiMancanti) / 12).rounded(.up)))
        s.rendimento = o.rendimento
        s.aliquota = 0
        s.inflazione = 0
        clienteAttivoId = o.clienteId
        bozzaSimulazione = s
        schedaSimulazioni = .simulatore
        apri(.simulazioni)
    }

    // MARK: - Incontri

    func incontriCliente(_ id: String) -> [Incontro] {
        dati.incontri.filter { $0.clienteId == id }.sorted { $0.data > $1.data }
    }

    func incontro(_ id: String?) -> Incontro? {
        guard let id else { return nil }
        return dati.incontri.first { $0.id == id }
    }

    func salvaIncontro(_ i: Incontro) {
        var x = i
        x.aggiornatoIl = Appuntamento.alMinuto(Date())
        if let k = dati.incontri.firstIndex(where: { $0.id == x.id }) {
            dati.incontri[k] = x
        } else {
            dati.incontri.append(x)
        }
    }

    func eliminaIncontro(_ id: String) {
        dati.incontri.removeAll { $0.id == id }
        if incontroAperto == id { incontroAperto = nil }
    }

    /// Nuovo incontro: dal prossimo appuntamento del cliente, con i temi delle sue priorità.
    func nuovoIncontro(cliente id: String, appuntamento: Appuntamento? = nil) {
        let a = appuntamento ?? prossimiAppuntamenti.first { $0.clienteId == id }
        var i = Incontro(clienteId: id, titolo: a?.titolo ?? "Incontro di consulenza", data: a?.inizio ?? Appuntamento.alMinuto(Date()),
                         appuntamentoId: a?.id)
        if let c = cliente(id) {
            let priorita = MotoreBisogni.priorita(bisogniRilevati(id), profilo: c.bisogni).map(\.areaAnalisi)
            var temi: [AreaAnalisi] = []
            for t in priorita where !temi.contains(t) { temi.append(t) }
            if !temi.isEmpty { i.temi = temi }
        }
        salvaIncontro(i)
        incontroAperto = i.id
        schedaIncontro = .preparazione
    }

    /// Apre l'incontro legato a un appuntamento (lo crea se manca).
    func apriIncontro(per a: Appuntamento) {
        clienteAttivoId = a.clienteId
        if let i = dati.incontri.first(where: { $0.appuntamentoId == a.id }) {
            incontroAperto = i.id
            schedaIncontro = i.stato == .concluso ? .passi : .preparazione
        } else {
            nuovoIncontro(cliente: a.clienteId, appuntamento: a)
        }
        apri(.incontri)
    }

    /// Legge gli appunti: regole di Prisma subito, il modello Apple (se c'è) si aggiunge.
    func estraiProposte(_ i: Incontro) {
        let altro = [i.progetti, i.esperienza, i.appunti, i.decisioni].filter { !$0.isEmpty }.joined(separator: "\n")
        let regole = EstrattoreIncontro.conRegole(altro, preoccupazioni: i.preoccupazioni)
        proposteIncontro[i.id] = regole
        proposteScelte = Set(regole.map(\.id))
        guard persistente, dati.impostazioni.eve.motore != .sintesi, MotoriEve.motivoAppleNonDisponibile == nil, !i.vuoto else { return }
        estrazioneInCorso = true
        let testo = i.testoAscolto
        Task { @MainActor in
            if let risposta = try? await MotoriEve.generaConApple(istruzioni: EstrattoreIncontro.istruzioniModello,
                                                                    richiesta: "APPUNTI DELL'INCONTRO\n" + testo) {
                let modello = EstrattoreIncontro.daRisposta(risposta)
                let unite = EstrattoreIncontro.unisci(regole, modello)
                self.proposteIncontro[i.id] = unite
                self.proposteScelte.formUnion(modello.map(\.id))
            }
            self.estrazioneInCorso = false
        }
    }

    /// Chiude l'incontro: le proposte scelte entrano nel profilo, nascono attività e seguito in agenda.
    func chiudiIncontro(_ id: String) {
        guard var i = incontro(id) else { return }
        let scelte = (proposteIncontro[id] ?? []).filter { proposteScelte.contains($0.id) }
        aggiornaBisogni(i.clienteId) { p in
            for s in scelte {
                switch s.tipo {
                case .bisogno(let area, let importanza):
                    var v = p.valutazione(area)
                    if importanza > v.importanza { v.importanza = importanza }
                    if v.orizzonte == nil { v.orizzonte = .medio }
                    p.imposta(v)
                case .evento(let tipo, let anno):
                    if !p.eventi.contains(where: { $0.tipo == tipo && $0.anno == anno }) {
                        p.eventi.append(EventoVita(tipo: tipo, anno: anno, nota: String(s.fonte.prefix(120))))
                    }
                case .attivita:
                    break
                }
            }
        }
        let scadenza = i.scadenzaAttivita ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        for s in scelte {
            if case .attivita(let titolo) = s.tipo {
                var t = Attivita.nuova(clienteId: i.clienteId, scadenza: scadenza)
                t.titolo = titolo
                t.appuntamentoId = i.appuntamentoId
                t.note = "Dall'incontro «\(i.titolo)»"
                dati.attivita.append(t)
            }
        }
        let attivita = i.prossimaAttivita.trimmingCharacters(in: .whitespacesAndNewlines)
        if !attivita.isEmpty {
            var t = Attivita.nuova(clienteId: i.clienteId, scadenza: scadenza)
            t.titolo = attivita
            t.appuntamentoId = i.appuntamentoId
            t.priorita = .alta
            t.note = i.decisioni
            dati.attivita.append(t)
            i.attivitaCreataId = t.id
        }
        if let quando = i.prossimoIncontro {
            var a = Appuntamento.nuovo(clienteId: i.clienteId, giorno: quando)
            a.inizio = Appuntamento.alMinuto(quando)
            a.titolo = "Seguito · \(i.titolo)"
            a.note = i.decisioni
            a.tipo = .revisione
            dati.appuntamenti.append(a)
            i.appuntamentoCreatoId = a.id
        }
        if let k = dati.appuntamenti.firstIndex(where: { $0.id == i.appuntamentoId }) {
            dati.appuntamenti[k].stato = .concluso
        }
        i.stato = .concluso
        salvaIncontro(i)
        proposteIncontro[id] = nil
        mostraAvviso("Incontro archiviato: profilo, attività e agenda aggiornati")
    }

    // MARK: - Profilo dei bisogni

    func bisogniRilevati(_ id: String) -> [BisognoRilevato] {
        guard let c = cliente(id) else { return [] }
        return MotoreBisogni.rileva(cliente: c, posizioni: posizioniCliente(id), analisi: analisi360(id))
    }

    /// Modifica il profilo dei bisogni del cliente e ne segna la data.
    func aggiornaBisogni(_ id: String, _ cambia: (inout ProfiloBisogni) -> Void) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == id }) else { return }
        var p = dati.clienti[i].bisogni
        cambia(&p)
        p.aggiornatoIl = Appuntamento.alMinuto(Date())
        dati.clienti[i].bisogni = p
    }

    // MARK: - Strumenti di analisi

    func simulazioniCliente(_ id: String) -> [Simulazione] {
        dati.simulazioni.filter { $0.clienteId == id }.sorted { $0.creataIl > $1.creataIl }
    }

    func salvaSimulazione(_ s: Simulazione) {
        if let i = dati.simulazioni.firstIndex(where: { $0.id == s.id }) {
            dati.simulazioni[i] = s
        } else {
            dati.simulazioni.append(s)
        }
    }

    func eliminaSimulazione(_ id: String) {
        dati.simulazioni.removeAll { $0.id == id }
        scenariConfrontati.remove(id)
        if confrontoA == .simulazione(id) { confrontoA = nil }
        if confrontoB == .simulazione(id) { confrontoB = nil }
    }

    /// Apre il simulatore con le ipotesi di una posizione.
    func simula(_ p: Posizione) {
        clienteAttivoId = p.clienteId
        bozzaSimulazione = Simulazione(posizione: p, orizzonteCliente: cliente(p.clienteId)?.profilo.orizzonteAnni)
        schedaSimulazioni = .simulatore
        apri(.simulazioni)
    }

    /// Apre Confronti con una posizione da una parte; dall'altra la proposta (o la posizione) più vicina.
    func confronta(_ p: Posizione) {
        clienteAttivoId = p.clienteId
        let altre = posizioniCliente(p.clienteId).filter { $0.id != p.id && $0.area.proiettabile && $0.stato != .chiusa }
        let opposte = altre.filter { $0.stato != p.stato }
        let altra = opposte.first { $0.area == p.area } ?? altre.first { $0.area == p.area } ?? opposte.first ?? altre.first
        confrontoA = .posizione(p.id)
        confrontoB = altra.map { .posizione($0.id) }
        orizzonteConfronto = nil
        apri(.confronti)
    }

    /// Analisi 360 del cliente: quella salvata o, se manca, una prima stesura dalle posizioni.
    func analisi360(_ id: String) -> Analisi360 {
        dati.analisi[id] ?? Analisi360(cliente: cliente(id), posizioni: posizioniCliente(id))
    }

    func analisiSalvata(_ id: String) -> Bool { dati.analisi[id] != nil }

    func salvaAnalisi(_ id: String, _ a: Analisi360) {
        var x = a
        x.aggiornataIl = Appuntamento.alMinuto(Date())
        dati.analisi[id] = x
    }

    /// Riparte dai dati delle posizioni (l'analisi salvata viene tolta).
    func ricalcolaAnalisi(_ id: String) {
        dati.analisi[id] = nil
    }

    // MARK: - Eve

    /// Messaggi conservati per cliente.
    static let massimoMessaggi = 60

    var motoreEve: MotoreEve { MotoriEve.scelto(dati.impostazioni.eve.motore) }

    func conversazione(_ id: String) -> [MessaggioEve] {
        dati.impostazioni.eve.conservaConversazioni ? (dati.conversazioni[id] ?? []) : (conversazioniTemporanee[id] ?? [])
    }

    private func aggiungiMessaggio(_ m: MessaggioEve, cliente id: String) {
        var elenco = conversazione(id)
        elenco.append(m)
        elenco = Array(elenco.suffix(Self.massimoMessaggi))
        if dati.impostazioni.eve.conservaConversazioni {
            dati.conversazioni[id] = elenco
        } else {
            conversazioniTemporanee[id] = elenco
        }
    }

    func nuovaConversazione() {
        dati.conversazioni[clienteAttivoId] = nil
        conversazioniTemporanee[clienteAttivoId] = nil
    }

    /// Ciò che Eve sa del cliente: dati del dossier e risultati dei motori di Prisma.
    func fonteEve(_ id: String) -> FonteEve? {
        guard let c = cliente(id) else { return nil }
        return FonteEve(oggi: Date(), nomeUtente: nomeUtente, cliente: c, posizioni: posizioniCliente(id),
                        appuntamenti: appuntamentiCliente(id), attivita: attivitaCliente(id),
                        analisi: analisi360(id), analisiSalvata: analisiSalvata(id), simulazioni: simulazioniCliente(id),
                        incontri: incontriCliente(id), obiettivi: obiettiviCliente(id))
    }

    /// Manda una domanda a Eve per il cliente attivo.
    func chiediEve(_ domanda: String, spunto: SpuntoEve? = nil) {
        let testo = domanda.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = clienteAttivoId
        guard !testo.isEmpty, !eveInCorso, let fonte = fonteEve(id) else { return }
        let storia = conversazione(id)
        aggiungiMessaggio(MessaggioEve(autore: .utente, testo: testo), cliente: id)
        domandaEve = ""
        let richiesta = RichiestaEve(domanda: testo, spunto: spunto ?? SpuntoEve.da(testo), fonte: fonte, storia: storia)
        let motore = motoreEve
        if let sintesi = motore as? MotoreSintesi {
            let r = sintesi.componi(richiesta)
            aggiungiMessaggio(MessaggioEve(autore: .eve, testo: r.testo, titolo: r.titolo, motore: motore.nome), cliente: id)
            return
        }
        eveInCorso = true
        Task { @MainActor in
            do {
                let r = try await motore.rispondi(richiesta)
                self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: r.testo, titolo: r.titolo, motore: motore.nome), cliente: id)
            } catch {
                // Se il modello non risponde, per gli spunti c'è comunque la sintesi dai dati.
                let riserva = richiesta.spunto != nil ? "\n\nIntanto, dai dati del dossier:\n\n" + MotoriEve.sintesi.componi(richiesta).testo : ""
                self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: error.localizedDescription + riserva,
                                                    titolo: "Eve non ha potuto rispondere", motore: MotoriEve.sintesi.nome), cliente: id)
            }
            self.eveInCorso = false
        }
    }

    /// Trasforma una risposta di Eve in un'attività per il cliente.
    func attivitaDaEve(_ m: MessaggioEve) {
        var t = Attivita.nuova(clienteId: clienteAttivoId,
                               scadenza: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
        t.titolo = m.titolo ?? String(m.testo.prefix(80))
        t.note = m.testo
        dati.attivita.append(t)
        mostraAvviso("Attività aggiunta: \(t.titolo)")
    }

    /// Aggiunge una risposta di Eve alla nota del cliente.
    func notaDaEve(_ m: MessaggioEve) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == clienteAttivoId }) else { return }
        let aggiunta = (m.titolo.map { $0 + "\n" } ?? "") + m.testo
        dati.clienti[i].nota = dati.clienti[i].nota.isEmpty ? aggiunta : dati.clienti[i].nota + "\n\n" + aggiunta
        mostraAvviso("Aggiunto alla nota di \(dati.clienti[i].nome)")
    }

    // MARK: - Agenda

    /// Appuntamenti del giorno, filtrati per cliente, in ordine d'orario.
    func appuntamentiDelGiorno(_ giorno: Date) -> [Appuntamento] {
        let cal = Calendar.current
        return appuntamenti
            .filter { cal.isDate($0.inizio, inSameDayAs: giorno) && (filtroClienteAgenda == nil || $0.clienteId == filtroClienteAgenda) }
            .sorted { $0.inizio < $1.inizio }
    }

    func appuntamento(_ id: String?) -> Appuntamento? {
        guard let id else { return nil }
        return appuntamenti.first { $0.id == id }
    }

    /// Mostra in agenda il giorno di un appuntamento e lo seleziona.
    func mostraInAgenda(_ a: Appuntamento) {
        giornoAgenda = Calendar.current.startOfDay(for: a.inizio)
        appuntamentoSelezionato = a.id
        if filtroClienteAgenda != nil && filtroClienteAgenda != a.clienteId { filtroClienteAgenda = nil }
        apri(.agenda)
    }

    func salvaAppuntamento(_ a: Appuntamento) {
        var x = a
        x.titolo = x.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        x.luogo = x.luogo.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = dati.appuntamenti.firstIndex(where: { $0.id == x.id }) {
            dati.appuntamenti[i] = x
        } else {
            dati.appuntamenti.append(x)
        }
        giornoAgenda = Calendar.current.startOfDay(for: x.inizio)
        appuntamentoSelezionato = x.id
        if filtroClienteAgenda != nil && filtroClienteAgenda != x.clienteId { filtroClienteAgenda = x.clienteId }
    }

    /// Elimina un appuntamento; le attività collegate restano, senza collegamento.
    func eliminaAppuntamento(_ id: String) {
        dati.appuntamenti.removeAll { $0.id == id }
        for i in dati.attivita.indices where dati.attivita[i].appuntamentoId == id {
            dati.attivita[i].appuntamentoId = nil
        }
        if appuntamentoSelezionato == id { appuntamentoSelezionato = nil }
    }

    func alternaConcluso(_ id: String) {
        guard let i = dati.appuntamenti.firstIndex(where: { $0.id == id }) else { return }
        dati.appuntamenti[i].stato = dati.appuntamenti[i].stato == .concluso ? .pianificato : .concluso
    }

    // MARK: - Attività

    func alternaCompletata(_ id: String) {
        guard let i = dati.attivita.firstIndex(where: { $0.id == id }) else { return }
        dati.attivita[i].completata.toggle()
    }

    func salvaAttivita(_ a: Attivita) {
        var x = a
        x.titolo = x.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = dati.attivita.firstIndex(where: { $0.id == x.id }) {
            dati.attivita[i] = x
        } else {
            dati.attivita.append(x)
        }
        attivitaSelezionata = x.id
        if filtroClienteAttivita != nil && filtroClienteAttivita != x.clienteId { filtroClienteAttivita = x.clienteId }
        if filtroPrioritaAttivita != nil && filtroPrioritaAttivita != x.priorita { filtroPrioritaAttivita = nil }
        if filtroStatoAttivita == .completate && !x.completata { filtroStatoAttivita = .aperte }
    }

    func eliminaAttivita(_ id: String) {
        dati.attivita.removeAll { $0.id == id }
        if attivitaSelezionata == id { attivitaSelezionata = nil }
    }

    func attivitaCollegate(_ appuntamentoId: String) -> [Attivita] {
        attivita.filter { $0.appuntamentoId == appuntamentoId }.sorted { $0.scadenza < $1.scadenza }
    }

    // MARK: - Salvataggio

    /// Salva l'archivio 0,8 s dopo l'ultima modifica e alla chiusura dell'app.
    private func avviaSalvataggio() {
        $dati
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(800), scheduler: DispatchQueue.main)
            .sink { [weak self] d in
                guard let self, !self.salvataggioSospeso else { return }
                self.scrivi(d)
            }
            .store(in: &abbonamenti)
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.salvaOra() }
            .store(in: &abbonamenti)
    }

    func salvaOra() {
        guard persistente, !salvataggioSospeso else { return }
        scrivi(dati)
    }

    private func scrivi(_ d: DatiPrisma) {
        do {
            try Archivio.salva(d)
        } catch {
            mostraAvviso("Salvataggio non riuscito: \(error.localizedDescription)")
        }
    }

    // MARK: - Backup

    var cartellaBackup: URL {
        dati.impostazioni.backup.cartella.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Archivio.cartellaBackupPredefinita
    }

    /// true se i backup stanno ancora sullo stesso Mac dell'archivio.
    var cartellaBackupPredefinita: Bool { dati.impostazioni.backup.cartella == nil }

    func scegliCartellaBackup(_ url: URL) {
        dati.impostazioni.backup.cartella = url.path
        aggiornaElencoBackup()
    }

    func aggiornaElencoBackup() {
        guard persistente else { return }
        let cartella = cartellaBackup
        DispatchQueue.global(qos: .utility).async {
            let elenco = GestoreBackup.elenca(cartella)
            DispatchQueue.main.async { self.elencoBackup = elenco }
        }
    }

    /// Crea un backup completo della cartella dell'archivio.
    func creaBackup(automatico: Bool = false) {
        guard persistente, !backupInCorso else { return }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        DispatchQueue.global(qos: .utility).async {
            do {
                let url = try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione,
                                                 nota: automatico ? "automatico" : nil)
                DispatchQueue.main.async {
                    self.backupInCorso = false
                    self.dati.impostazioni.backup.ultimo = Date()
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("Backup creato: \(url.lastPathComponent)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.backupInCorso = false
                    self.mostraAvviso("Backup non riuscito: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Ripristina un backup. Prima salva una copia di sicurezza dello stato attuale.
    func ripristina(_ zip: URL) {
        guard persistente, !backupInCorso else { return }
        salvaOra()
        salvataggioSospeso = true
        backupInCorso = true
        let destinazione = cartellaBackup
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let estratto = try GestoreBackup.estrai(zip)
                try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima del ripristino")
                try GestoreBackup.sostituisci(cartellaDati: Archivio.cartella, con: estratto.cartella)
                DispatchQueue.main.async {
                    self.dati = estratto.dati
                    self.salvataggioSospeso = false
                    self.backupInCorso = false
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("Ripristino completato. Lo stato precedente è salvato in un backup.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.salvataggioSospeso = false
                    self.backupInCorso = false
                    self.mostraAvviso("Ripristino non riuscito: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Torna ai 5 clienti di prova (con backup di sicurezza dello stato attuale).
    func ripristinaDatiDiProva() {
        guard persistente, !backupInCorso else { return }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima dei dati di prova") }
            DispatchQueue.main.async {
                self.backupInCorso = false
                switch esito {
                case .success:
                    var demo = DatiPrisma.demo()
                    demo.impostazioni = self.dati.impostazioni
                    self.dati = demo
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("Dati di prova ripristinati. Lo stato precedente è salvato in un backup.")
                case .failure(let e):
                    self.mostraAvviso("Operazione annullata, backup non riuscito: \(e.localizedDescription)")
                }
            }
        }
    }

    /// Backup automatico settimanale: controllo all'avvio e poi ogni ora.
    private func avviaBackupAutomatico() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.controllaBackupAutomatico() }
        timerBackup = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.controllaBackupAutomatico()
        }
    }

    private func controllaBackupAutomatico() {
        let b = dati.impostazioni.backup
        guard b.automatico, let prossimo = b.prossimo, prossimo <= Date() else { return }
        creaBackup(automatico: true)
    }

    // MARK: - Avvisi

    func mostraAvviso(_ testo: String) {
        lavoroAvviso?.cancel()
        withAnimation(Animazioni.avviso) { avviso = testo }
        let lavoro = DispatchWorkItem { [weak self] in
            withAnimation(Animazioni.avviso) { self?.avviso = nil }
        }
        lavoroAvviso = lavoro
        DispatchQueue.main.asyncAfter(deadline: .now() + Animazioni.durataAvviso, execute: lavoro)
    }

    func alternaSchermoIntero() {
        (NSApp.keyWindow ?? NSApp.windows.first)?.toggleFullScreen(nil)
    }
}

enum SchedaImpostazioni: Hashable {
    case esperienza, archivio, scorciatoie
}

enum SchedaCliente: String, CaseIterable, Hashable {
    case panoramica, bisogni, anagrafica, famiglia, profilo, note

    var titolo: String {
        switch self {
        case .panoramica: return "Panoramica"
        case .bisogni: return "Bisogni"
        case .anagrafica: return "Anagrafica"
        case .famiglia: return "Famiglia"
        case .profilo: return "Profilo"
        case .note: return "Note"
        }
    }
}
