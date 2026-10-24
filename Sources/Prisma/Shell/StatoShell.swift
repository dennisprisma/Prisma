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
    /// Posizioni mostra il portafoglio di tutti i clienti invece del dossier del cliente attivo.
    // Il portafoglio parla di tutti i clienti: in modalità cliente resta chiuso
    @Published var portafoglio = false { didSet { if portafoglio && modoCliente != nil { portafoglio = false } } }
    /// Modalità cliente: lo schermo girato verso il cliente mostra solo il suo dossier (id del cliente).
    @Published var modoCliente: String?
    /// Il pulsante dell'intestazione di Posizioni chiede di aprire il modulo (nuova posizione o proposta).
    @Published var richiestaNuovaPosizione: StatoPosizione?
    /// Il pulsante "Nuovo cliente" dell'intestazione chiede alla rubrica di aprire il modulo.
    @Published var richiestaNuovoCliente = false
    /// Contatti letti da un file, in attesa di conferma nell'anteprima della rubrica.
    @Published var importazione: ImportazioneClienti?
    /// Posizioni lette da un file, in attesa di conferma in Posizioni.
    @Published var importazionePosizioni: ImportazionePosizioni?

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

    // Note
    @Published var notaSelezionata: String?
    /// La pagina nuova appena aperta: se resta vuota non entra nel taccuino.
    private var bozzaNota: String?
    /// nil = tutti i clienti.
    @Published var filtroClienteNote: String?
    @Published var ricercaNote = ""

    // Centro notifiche
    @Published var pannelloNotifiche = false
    /// Le notifiche, ricalcolate poco dopo ogni modifica dei dati e una volta al minuto
    /// (non a ogni disegno della barra in alto).
    @Published private(set) var notifiche: [Notifica] = []
    private var timerNotifiche: Timer?
    /// Le notifiche già viste in questa sessione (la campanella conta le altre).
    @Published var notificheViste: Set<String> = []

    /// Eve parla del portafoglio (tutti i clienti) invece che del cliente attivo.
    @Published var evePortafoglio = false { didSet { if evePortafoglio && modoCliente != nil { evePortafoglio = false } } }

    /// La schermata di benvenuto copre le finestre (il lucchetto in alto).
    @Published var bloccato = false
    @Published var pannelloAppAperte = false

    /// Il pannello degli spazi di lavoro è aperto.
    @Published var pannelloSpazi = false

    // Ricerca (⌘K)
    @Published var testoRicerca = ""
    /// Cresce a ogni ⌘K: la Ricerca rimette il cursore nel campo.
    @Published var richiestaFuocoRicerca = 0

    // Documenti
    @Published var documentoSelezionato: String?
    @Published var documentiInLettura: Set<String> = []

    // Prospetti e report
    /// Prospetto scelto (nil = quadro delle posizioni del cliente attivo).
    @Published var prospetto: SceltaProspetto?
    /// Valutazione aperta nel modulo di modifica.
    @Published var valutazioneInModifica: ValutazioneInvestimento?
    private var testiDocumenti = MemoriaTesti()

    // Eve
    @Published var eveInCorso = false
    @Published var domandaEve = ""
    /// Conversazioni non conservate nell'archivio (se l'utente lo sceglie nelle impostazioni).
    @Published var conversazioniTemporanee: [String: [MessaggioEve]] = [:]

    // Backup
    @Published private(set) var elencoBackup: [VoceBackup] = []
    @Published private(set) var backupInCorso = false

    /// Area disponibile per le finestre (sotto la barra, sopra il dock), aggiornata dalla vista.
    /// Area delle finestre interne (sotto la barra, sopra il dock). Pubblicata: quando cambia la
    /// dimensione della finestra di Prisma le finestre interne si ridisegnano subito, senza finire sotto il dock.
    @Published var area: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 700)

    /// false nelle istantanee: niente disco, niente animazioni.
    let persistente: Bool

    private var lavoroAvviso: DispatchWorkItem?
    private var abbonamenti = Set<AnyCancellable>()
    private var timerBackup: Timer?
    private var salvataggioSospeso = false
    /// Archivio di una versione più recente di Prisma: niente salvataggi né backup automatici.
    private(set) var solaLettura = false
    /// Archivio di una versione più recente: neanche il ripristino di un backup è sicuro.
    private(set) var ripristinoBloccato = false

    init(persistente: Bool = true) {
        self.persistente = persistente
        if persistente {
            let caricati = Archivio.carica()
            dati = caricati.dati
            // Prima di disegnare qualcosa: i caratteri dell'interfaccia nascono con questa misura
            Tipo.fattore = caricati.dati.impostazioni.dimensioneTesto.fattore
            salvataggioSospeso = caricati.solaLettura
            solaLettura = caricati.solaLettura
            ripristinoBloccato = caricati.bloccaRipristino
            copieNonLeggibili = Archivio.copieNonLeggibili.count
            if let a = caricati.avviso {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.mostraAvviso(a) }
            }
            // Una pagina nuova rimasta vuota alla chiusura non torna come «Bozza»
            if dati.note.contains(where: \.vuota) { dati.note.removeAll(where: \.vuota) }
            avviaSalvataggio()
            avviaBackupAutomatico()
            aggiornaElencoBackup()
            // I file rimasti da un'importazione interrotta vanno nel Cestino; solo con l'archivio
            // letto senza intoppi (con un archivio recuperato o di prova i file servono ancora)
            if caricati.avviso == nil, !caricati.solaLettura, copieNonLeggibili == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard let self, self.documentiInLettura.isEmpty else { return }
                    let tolti = self.pulisciDocumentiOrfani(nelCestino: true)
                    if tolti > 0 { self.mostraAvviso("\(tolti) \(tolti == 1 ? "file non più usato spostato" : "file non più usati spostati") nel Cestino") }
                }
            }
        } else {
            dati = DatiPrisma.demo()
        }
        avviaNotifiche()
    }

    // MARK: - Lettura

    // In modalità cliente le app vedono solo il cliente davanti a te: gli altri non compaiono da nessuna parte
    var clienti: [Cliente] { modoCliente.map { id in dati.clienti.filter { $0.id == id } } ?? dati.clienti }
    var appuntamenti: [Appuntamento] { modoCliente.map { id in dati.appuntamenti.filter { $0.clienteId == id } } ?? dati.appuntamenti }
    var attivita: [Attivita] { modoCliente.map { id in dati.attivita.filter { $0.clienteId == id } } ?? dati.attivita }
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
        guard appConsentita(app) else {
            mostraAvviso("In modalità cliente \(app.titolo) non si apre: mostra i dati di altri clienti.")
            return
        }
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
    /// Mostra la schermata di benvenuto sopra tutto (chiude i pannelli aperti).
    func blocca() {
        pannelloNotifiche = false
        pannelloSpazi = false
        pannelloAppAperte = false
        // Dalla schermata di blocco si torna sempre a Prisma completo
        modoCliente = nil
        anima { bloccato = true }
    }

    func mostraScrivania() {
        anima {
            for i in finestre.indices { finestre[i].ridotta = true }
        }
    }

    // MARK: - Spazi di lavoro

    /// Gli spazi pronti e quelli salvati dal consulente.
    var spaziDiLavoro: [SpazioLavoro] { SpazioLavoro.predefiniti + dati.spazi }

    /// L'area che avranno le finestre: con una finestra aperta il dock si nasconde e lo spazio cresce.
    private var areaConFinestre: CGRect {
        guard finestreVisibili.isEmpty else { return area }
        var a = area
        a.size.height += Misure.Dock.riservato - Misure.Dock.riservatoNascosto
        return a
    }

    /// Cornice di una finestra dello spazio nell'area, con un piccolo stacco tra finestre affiancate.
    private func cornice(da f: FinestraSpazio, in area: CGRect) -> CGRect {
        let r = CGRect(x: f.x * area.width, y: f.y * area.height, width: f.larghezza * area.width, height: f.altezza * area.height)
            .insetBy(dx: Misure.Spazi.stacco / 2, dy: Misure.Spazi.stacco / 2)
        return limita(CGRect(origin: r.origin, size: CGSize(width: max(r.width, Misure.Finestra.minima.width),
                                                           height: max(r.height, Misure.Finestra.minima.height))), in: area)
    }

    /// Apre lo spazio: le sue app, disposte come salvate, al posto delle finestre aperte.
    func apriSpazio(_ s: SpazioLavoro) {
        let area = areaConFinestre
        pannelloSpazi = false
        anima {
            finestre = s.finestre.map { f in
                Finestra(app: f.app, cornice: cornice(da: f, in: area), ingrandita: f.ingrandita)
            }
        }
        if s.finestre.contains(where: { $0.app == .impostazioni }) { aggiornaElencoBackup() }
    }

    /// Salva le finestre aperte come nuovo spazio (dalla più in fondo a quella in primo piano).
    @discardableResult
    func salvaSpazio(nome: String) -> SpazioLavoro? {
        let n = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !finestreVisibili.isEmpty, area.width > 0, area.height > 0 else { return nil }
        let elenco = finestreVisibili.map { f -> FinestraSpazio in
            guard !f.ingrandita else { return .intera(f.app) }
            // Lo stacco tra finestre affiancate si toglie qui e si rimette alla riapertura
            let c = cornice(di: f).insetBy(dx: -Misure.Spazi.stacco / 2, dy: -Misure.Spazi.stacco / 2)
            return FinestraSpazio(app: f.app, x: c.minX / area.width, y: c.minY / area.height,
                                  larghezza: c.width / area.width, altezza: c.height / area.height)
        }
        let spazio = SpazioLavoro(nome: String(n.prefix(Misure.Spazi.nomeMassimo)), finestre: elenco)
        dati.spazi.append(spazio)
        mostraAvviso("Spazio «\(spazio.nome)» salvato.")
        return spazio
    }

    func eliminaSpazio(_ id: String) {
        dati.spazi.removeAll { $0.id == id }
    }

    /// ◫ nella barra del titolo: la finestra a sinistra e quella sotto di lei a destra.
    func affianca(_ app: AppPrisma) {
        let visibili = finestreVisibili
        guard let altra = visibili.last(where: { $0.app != app }) else {
            mostraAvviso("Apri un'altra app dal dock per affiancarla a questa.")
            return
        }
        guard let i = finestre.firstIndex(where: { $0.app == app }),
              let j = finestre.firstIndex(where: { $0.app == altra.app }) else { return }
        anima {
            finestre[i].ingrandita = false
            finestre[i].cornice = cornice(da: .sinistra(app), in: area)
            finestre[j].ingrandita = false
            finestre[j].cornice = cornice(da: .destra(altra.app), in: area)
        }
        primoPiano(app)
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
    func cornice(di f: Finestra) -> CGRect { cornice(di: f, in: area) }

    /// Cornice dentro un'area precisa: il disegno usa la stessa area in cui mette le finestre,
    /// così una finestra non è mai più alta del suo spazio (e la barra del titolo resta visibile).
    func cornice(di f: Finestra, in area: CGRect) -> CGRect {
        f.ingrandita ? CGRect(origin: .zero, size: area.size) : limita(f.cornice, in: area)
    }

    private func corniceIniziale() -> CGRect {
        let l = max(Misure.Finestra.minima.width, area.width * 0.72)
        let a = max(Misure.Finestra.minima.height, area.height * 0.8)
        let passo = CGFloat(finestre.count % 6) * 24
        return CGRect(x: (area.width - l) / 2 + passo, y: (area.height - a) / 3 + passo, width: l, height: a)
    }

    /// Tiene la finestra dentro l'area (la barra del titolo resta sempre raggiungibile).
    private func limita(_ c: CGRect) -> CGRect { limita(c, in: area) }

    private func limita(_ c: CGRect, in area: CGRect) -> CGRect {
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
        dati.commenti.removeAll { $0.clienteId == id }
        dati.note.removeAll { $0.clienteId == id }
        dati.incontri.removeAll { $0.clienteId == id }
        dati.obiettivi.removeAll { $0.clienteId == id }
        dati.valutazioni.removeAll { $0.clienteId == id }
        for d in dati.documenti where d.clienteId == id { rimuoviFile(d) }
        dati.documenti.removeAll { $0.clienteId == id }
        if dati.clienteAttivoId == id {
            dati.clienteAttivoId = dati.clienti.first?.id ?? ""
        }
        azzeraNote()
    }

    // MARK: - Note

    func nota(_ id: String?) -> Nota? {
        guard let id else { return nil }
        return dati.note.first { $0.id == id }
    }

    func noteCliente(_ id: String) -> [Nota] {
        dati.note.filter { $0.clienteId == id }.sorted(by: Nota.ordina)
    }

    /// L'elenco dell'app Note: filtro per cliente e ricerca (ogni parola, senza badare ad accenti).
    var noteFiltrate: [Nota] {
        let parole = MotoreRicerca.parole(ricercaNote)
        return dati.note
            .filter { filtroClienteNote == nil || $0.clienteId == filtroClienteNote }
            .filter { n in parole.allSatisfy { MotoreRicerca.contiene(n.titolo, $0) || MotoreRicerca.contiene(n.testo, $0) } }
            .sorted(by: Nota.ordina)
    }

    /// Apre una pagina nuova per il cliente (quello del filtro, o il cliente attivo).
    @discardableResult
    func nuovaNota(clienteId: String? = nil) -> Nota? {
        let filtro = filtroClienteNote.flatMap { cliente($0)?.id }
        guard let cliente = clienteId ?? filtro ?? clienti.first(where: { $0.id == clienteAttivoId })?.id ?? clienti.first?.id else {
            mostraAvviso("Aggiungi prima un cliente: ogni nota appartiene a una persona.")
            return nil
        }
        togliNoteVuote()
        let n = Nota(clienteId: cliente, titolo: "", testo: "")
        dati.note.append(n)
        bozzaNota = n.id
        ricercaNote = ""
        if filtroClienteNote != nil && filtroClienteNote != cliente { filtroClienteNote = cliente }
        notaSelezionata = n.id
        return n
    }

    /// Scegli una nota: le pagine nuove lasciate vuote non restano nel taccuino.
    func scegliNota(_ id: String?) {
        guard id != notaSelezionata else { return }
        togliNoteVuote(tranne: id)
        notaSelezionata = id
    }

    /// Toglie la pagina nuova lasciata vuota (una nota esistente svuotata per riscriverla resta).
    private func togliNoteVuote(tranne id: String? = nil) {
        guard let b = bozzaNota, b != id else { return }
        dati.note.removeAll { $0.id == b && $0.vuota }
        bozzaNota = nil
    }

    /// Dopo un cliente eliminato o un archivio ripristinato, filtro e selezione delle note ripartono.
    private func azzeraNote() {
        // Anche agenda e attività: un filtro su un cliente che non c'è più mostrerebbe pagine vuote
        if let f = filtroClienteAgenda, cliente(f) == nil { filtroClienteAgenda = nil }
        if let f = filtroClienteAttivita, cliente(f) == nil { filtroClienteAttivita = nil }
        if let f = filtroClienteNote, cliente(f) == nil { filtroClienteNote = nil }
        if nota(notaSelezionata) == nil { notaSelezionata = nil }
        bozzaNota = nil
    }

    /// Modifica una nota; la data di aggiornamento cambia solo se cambia qualcosa.
    func modificaNota(_ id: String, _ cambia: (inout Nota) -> Void) {
        guard let i = dati.note.firstIndex(where: { $0.id == id }) else { return }
        var n = dati.note[i]
        cambia(&n)
        n.titolo = String(n.titolo.prefix(Nota.limiteTitolo))
        guard n != dati.note[i] else { return }
        // Cambiato il cliente, il filtro lo segue: la nota resta sotto gli occhi (non se ne apre un'altra)
        if n.clienteId != dati.note[i].clienteId, filtroClienteNote != nil { filtroClienteNote = n.clienteId }
        if !n.vuota, n.id == bozzaNota { bozzaNota = nil }
        if n.titolo != dati.note[i].titolo || n.testo != dati.note[i].testo || n.clienteId != dati.note[i].clienteId {
            n.aggiornataIl = Nota.adesso
        }
        dati.note[i] = n
    }

    func eliminaNota(_ id: String) {
        dati.note.removeAll { $0.id == id }
        if notaSelezionata == id { notaSelezionata = nil }
    }

    /// Dall'appunto alla prossima azione: la bozza di un'attività per il cliente della nota
    /// (si completa e si salva nel modulo delle attività).
    func bozzaAttivitaDaNota(_ id: String) -> Attivita? {
        guard let n = nota(id) else { return nil }
        var a = Attivita.nuova(clienteId: n.clienteId)
        a.titolo = n.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        a.note = "Dalla nota «\(n.titoloMostrato)»."
        return a
    }

    /// Il testo da esportare: titolo, cliente, data e testo.
    func testoEsportato(_ n: Nota) -> String {
        [n.titoloMostrato, "\(cliente(n.clienteId)?.nome ?? "") · aggiornata il \(Formati.dataEstesa.string(from: n.aggiornataIl))", "", n.testo]
            .joined(separator: "\n")
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

    var posizioni: [Posizione] { modoCliente.map { id in dati.posizioni.filter { $0.clienteId == id } } ?? dati.posizioni }

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

    /// Aggiunge allo storico un valore passato; uno dello stesso giorno viene sostituito.
    func aggiungiRilevazione(_ r: Rilevazione, a id: String) {
        guard let i = dati.posizioni.firstIndex(where: { $0.id == id }) else { return }
        let cal = Calendar.current
        // A mezzogiorno e a secondi interi, come il resto dell'archivio
        let giorno = cal.date(bySettingHour: 12, minute: 0, second: 0, of: r.data) ?? r.data
        var elenco = dati.posizioni[i].rilevazioni ?? []
        elenco.removeAll { cal.isDate($0.data, inSameDayAs: giorno) }
        elenco.append(Rilevazione(data: Date(timeIntervalSinceReferenceDate: giorno.timeIntervalSinceReferenceDate.rounded(.down)),
                                  controvalore: r.controvalore, versato: r.versato))
        dati.posizioni[i].rilevazioni = elenco.sorted { $0.data < $1.data }
    }

    /// Toglie dallo storico il valore passato di quel giorno (il valore attuale resta).
    func eliminaRilevazione(_ data: Date, da id: String) {
        guard let i = dati.posizioni.firstIndex(where: { $0.id == id }) else { return }
        dati.posizioni[i].rilevazioni?.removeAll { Calendar.current.isDate($0.data, inSameDayAs: data) }
    }

    func eliminaPosizione(_ id: String) {
        dati.posizioni.removeAll { $0.id == id }
        // I commenti dei confronti che la usavano
        dati.commenti.removeAll { $0.id.hasPrefix("sostituzione·") && $0.id.components(separatedBy: "·").contains(id) }
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
        portafoglio = false
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
        return posizioni.filter { p in
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
    /// Restano in memoria solo i testi usati di recente; la ricerca (`memorizza: false`) legge
    /// gli altri dal disco senza tenerli, così l'archivio intero non finisce in memoria.
    func testoDocumento(_ d: Documento, memorizza: Bool = true) -> [String] {
        if let t = testiDocumenti[d.id] {
            if memorizza { testiDocumenti[d.id] = t }
            return t
        }
        var pagine = DatiDemo.testoDocumento(d.id) ?? []
        if pagine.isEmpty, let url = urlTesto(d), let t = try? String(contentsOf: url, encoding: .utf8) {
            pagine = t.components(separatedBy: LetturaDocumenti.separatorePagine)
        }
        if memorizza { testiDocumenti[d.id] = pagine }
        return pagine
    }

    private func aggiornaDocumento(_ id: String, _ cambia: (inout Documento) -> Void) {
        guard let i = dati.documenti.firstIndex(where: { $0.id == id }) else { return }
        cambia(&dati.documenti[i])
    }

    /// Copia i file nella cartella Documenti del cliente e li legge.
    func importaDocumenti(_ urls: [URL]) {
        guard persistente else { return }
        guard !solaLettura else {
            mostraAvviso("Archivio in sola lettura: aggiorna Prisma per importare documenti.")
            return
        }
        let cliente = clienteAttivoId
        guard self.cliente(cliente) != nil else {
            mostraAvviso("Scegli prima un cliente: ogni documento va nella sua cartella.")
            return
        }
        let fm = FileManager.default
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

    private static let codaLettura = DispatchQueue(label: "prisma.lettura-documenti", qos: .userInitiated)

    /// Legge il testo (PDFKit, poi Vision per le scansioni) e cerca i dati; il modello Apple completa.
    func leggiDocumento(_ id: String) {
        guard !solaLettura, let d = documento(id), let url = urlDocumento(d), let testo = urlTesto(d) else { return }
        documentiInLettura.insert(id)
        // Un documento alla volta: tante scansioni insieme pesano sulla memoria di un Mac da 8 GB
        Self.codaLettura.async {
            let esito = LetturaDocumenti.leggi(url)
            DispatchQueue.main.async {
                // Il documento può essere stato eliminato durante la lettura: niente testo orfano
                guard self.documento(id) != nil else {
                    self.documentiInLettura.remove(id)
                    return
                }
                if let esito {
                    try? esito.pagine.joined(separator: LetturaDocumenti.separatorePagine).write(to: testo, atomically: true, encoding: .utf8)
                }
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
                    // Rileggendo, i dati già confermati (e corretti a mano) restano
                    x.campi = EstrattoreDocumento.unisci(x.campi.filter(\.confermato), campi)
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
            // Contro lo stato di adesso: conferme e correzioni fatte durante la lettura restano
            self.aggiornaDocumento(id) { $0.campi = EstrattoreDocumento.unisci($0.campi, modello) }
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
        // In sola lettura (archivio di una versione più nuova) i file restano: l'archivio vero li usa ancora
        guard persistente, !solaLettura else { return }
        if let u = urlDocumento(d) { try? FileManager.default.removeItem(at: u) }
        if let t = urlTesto(d) { try? FileManager.default.removeItem(at: t) }
    }

    /// Elimina dalla cartella Documenti i file che nessun documento dell'archivio usa più
    /// (con `nelCestino` li sposta nel Cestino del Mac, da dove si possono ancora riprendere).
    /// Restituisce quanti file ha tolto.
    @discardableResult
    func pulisciDocumentiOrfani(nelCestino: Bool = false) -> Int {
        guard persistente, !solaLettura else { return 0 }
        let fm = FileManager.default
        let radice = Archivio.cartellaDocumenti.standardizedFileURL
        var usati = Set<String>()
        for d in dati.documenti {
            if let u = urlDocumento(d) { usati.insert(u.resolvingSymlinksInPath().path) }
            if let t = urlTesto(d) { usati.insert(t.resolvingSymlinksInPath().path) }
        }
        guard let elenco = fm.enumerator(at: radice, includingPropertiesForKeys: [.isRegularFileKey]) else { return 0 }
        var tolti = 0
        var cartelle: [URL] = []
        for case let u as URL in elenco {
            guard (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                cartelle.append(u)
                continue
            }
            guard !usati.contains(u.resolvingSymlinksInPath().path) else { continue }
            if nelCestino {
                if (try? fm.trashItem(at: u, resultingItemURL: nil)) != nil { tolti += 1 }
            } else if (try? fm.removeItem(at: u)) != nil {
                tolti += 1
            }
        }
        // Le cartelle dei clienti rimaste vuote (le più interne prima)
        for c in cartelle.reversed() where ((try? fm.contentsOfDirectory(atPath: c.path)) ?? ["?"]).filter({ $0 != ".DS_Store" }).isEmpty {
            try? fm.removeItem(at: c)
        }
        return tolti
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
        case .liquidita(let report)?:
            return .liquidita(report: report)
        case .checkUp(let report)?:
            return .checkUp(report: report)
        case .resistenza(let report)?:
            return .resistenza(report: report)
        case .obiettivo(let id, let report)?:
            let elenco = obiettiviCliente(clienteAttivoId)
            return .obiettivo(elenco.contains { $0.id == id } ? id : (elenco.first?.id ?? ""), report: report)
        case .sostituzione(let a, let b, let report)?:
            let mie = posizioniCliente(clienteAttivoId)
            if a != b, mie.contains(where: { $0.id == a }), mie.contains(where: { $0.id == b }) { return .sostituzione(a, b, report: report) }
            let coppia = MotoreSostituzione.coppia(mie)
            return .sostituzione(coppia?.0 ?? "", coppia?.1 ?? "", report: report)
        case .portafoglio?:
            return .portafoglio
        case .riesame?:
            return .riesame
        case .confronto(let a, let b)?:
            let voci = ElementoConfronto.elenco(dati, cliente: clienteAttivoId)
            if voci.contains(where: { $0.voce == a }) && voci.contains(where: { $0.voce == b }) { return .confronto(a, b) }
            return predefinita
        default:
            return predefinita
        }
    }

    /// Il testo del commento da stampare nel report (nil nei prospetti e se non c'è).
    private func testoCommento(_ scelta: SceltaProspetto) -> String? {
        scelta.conCommento ? commento(scelta)?.testo : nil
    }

    /// Il documento da mostrare e stampare per una scelta.
    func documentoProspetto(_ scelta: SceltaProspetto) -> DocumentoStampabile? {
        if case .valutazione(let id, let report) = scelta {
            return valutazione(id).flatMap(testiValutazione).map { DocumentoStampabile($0, report: report) }
        }
        if case .sostituzione(let a, let b, let report) = scelta {
            return testiSostituzione(a, b).map { DocumentoStampabile($0, report: report, commento: testoCommento(scelta)) }
        }
        if case .obiettivo(let id, let report) = scelta {
            return testiObiettivo(id).map { DocumentoStampabile($0, report: report, commento: testoCommento(scelta)) }
        }
        if case .checkUp(let report) = scelta {
            return DocumentoStampabile(testiCheckUp(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        if case .liquidita(let report) = scelta {
            return DocumentoStampabile(testiLiquidita(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        if case .resistenza(let report) = scelta {
            return DocumentoStampabile(testiResistenza(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        if case .protezione(let report) = scelta {
            return DocumentoStampabile(testiProtezione(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        if case .previdenza(let report) = scelta {
            return DocumentoStampabile(testiPrevidenza(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        if case .resoconto(let report) = scelta {
            return DocumentoStampabile(testiResoconto(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        return contenutoProspetto(scelta).map { DocumentoStampabile($0) }
    }

    /// I testi e i numeri del check-up del primo incontro di un cliente.
    func testiCheckUp(_ id: String) -> TestiCheckUp {
        TestiCheckUp(MotoreCheckUp.calcola(cliente: self.cliente(id), posizioni: posizioniCliente(id), analisi: analisi360(id), obiettivi: obiettiviCliente(id)))
    }

    /// I testi e i numeri della prova di resistenza di un cliente (lo stesso calcolo del pannello in Posizioni).
    func testiResistenza(_ id: String) -> TestiResistenza {
        let c = self.cliente(id)
        return TestiResistenza(MotoreResistenza.calcola(posizioniCliente(id), profilo: c?.profilo), cliente: c)
    }

    /// I testi e i numeri del capitale in scadenza e della liquidità di un cliente.
    func testiLiquidita(_ id: String) -> TestiLiquidita {
        let e = MotoreLiquidita.calcola(posizioniCliente(id), obiettivi: obiettiviCliente(id), analisi: analisi360(id).protezione, prodotti: dati.prodotti)
        return TestiLiquidita(e, cliente: self.cliente(id))
    }

    /// I testi e i numeri del piano per un obiettivo, con il quadro degli altri obiettivi del cliente.
    func testiObiettivo(_ id: String) -> TestiObiettivo? {
        guard let o = dati.obiettivi.first(where: { $0.id == id }) else { return nil }
        let mie = posizioniCliente(o.clienteId)
        let altri = obiettiviCliente(o.clienteId).map { ($0, AvanzamentoObiettivo($0, posizioni: mie)) }
        return TestiObiettivo(MotoreObiettivo.calcola(o, posizioni: mie), cliente: self.cliente(o.clienteId), altri: altri)
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
        if case .riesame = scelta { return fonteEve(clienteAttivoId).map { CompositoreProspetti.riesame($0) } }
        return CompositoreProspetti.componi(scelta, dati: dati, cliente: clienteAttivoId, orizzonteConfronto: orizzonteConfronto)
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
        let titolo = "\(documento.genere) · \(documento.titolo)"
        // Lo stesso documento archiviato di nuovo nello stesso giorno sostituisce la copia di prima
        if let vecchio = dati.documenti.first(where: { $0.clienteId == cliente && $0.titolo == titolo && Calendar.current.isDateInToday($0.importatoIl) }) {
            eliminaDocumento(vecchio.id)
        }
        var d = Documento(clienteId: cliente, titolo: titolo, tipo: documento.tipo)
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
        // Il valore di un estratto conto con la sua data e il versato: lo storico parte da lì
        if let v = ValoriDaDocumento.valore(d) {
            p.dataValore = v.data
            p.totaleVersato = v.versato
        }
        p.costoAnnuo = EstrattoreDocumento.numero(d.confermato(.costoAnnuo))
        p.costoIngresso = EstrattoreDocumento.numero(d.confermato(.costoIngresso))
        p.sri = d.confermato(.sri).flatMap { Int($0.prefix(1)) }
        p.note = "Dati dal documento «\(d.titolo)», da completare."
        salvaPosizione(p)
        aggiornaDocumento(id) { $0.posizioneId = p.id }
        apriPosizione(p)
    }

    /// Porta nella posizione il valore confermato di un estratto conto e collega il documento.
    func registraValore(daDocumento id: String, posizione pid: String) {
        guard !solaLettura, let d = documento(id), let v = ValoriDaDocumento.valore(d),
              let i = dati.posizioni.firstIndex(where: { $0.id == pid }) else { return }
        let esito = ValoriDaDocumento.applica(v, a: &dati.posizioni[i])
        aggiornaDocumento(id) { $0.posizioneId = pid }
        let quando = Formati.dataEstesa.string(from: v.data)
        mostraAvviso(esito == .attuale ? "Valore attuale di «\(dati.posizioni[i].nome)» aggiornato al \(quando)"
                                       : "Valore del \(quando) aggiunto allo storico di «\(dati.posizioni[i].nome)»")
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
        dati.commenti.removeAll { $0.id == "obiettivo·\(id)" }
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
        let id = evePortafoglio ? EvePortafoglio.chiave : clienteAttivoId
        dati.conversazioni[id] = nil
        conversazioniTemporanee[id] = nil
    }

    /// Una domanda a Eve sul portafoglio (tutti i clienti). Le cifre sono quelle della vista Portafoglio;
    /// il modello Apple, se c'è, riscrive la risposta senza cambiarle (altrimenti resta la sintesi).
    func chiediEvePortafoglio(_ domanda: String, spunto: SpuntoPortafoglio? = nil) {
        let testo = domanda.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testo.isEmpty, !eveInCorso else { return }
        let id = EvePortafoglio.chiave
        aggiungiMessaggio(MessaggioEve(autore: .utente, testo: testo), cliente: id)
        domandaEve = ""
        let argomento = spunto ?? SpuntoPortafoglio.da(testo)
        let bozza = EvePortafoglio.risposta(argomento, domanda: testo, dati: dati)
        guard !(motoreEve is MotoreSintesi) else {
            aggiungiMessaggio(MessaggioEve(autore: .eve, testo: bozza.testo, titolo: bozza.titolo, motore: MotoriEve.sintesi.nome), cliente: id)
            return
        }
        let scheda = EvePortafoglio.scheda(dati)
        let istruzioni = (IstruzioniEve.testo("chat") ?? "") + "\nQui parli del portafoglio del consulente (tutti i clienti), non di un singolo cliente."
        let richiesta = "SCHEDA DEL PORTAFOGLIO (calcolata da Prisma)\n\(scheda)\n\nBOZZA PREPARATA DA PRISMA (numeri esatti: non cambiarli e non aggiungerne)\n\(bozza.testo)\n\nDOMANDA DEL CONSULENTE: \(testo)"
        eveInCorso = true
        Task { @MainActor in
            var risposta = bozza.testo
            var motore = MotoriEve.sintesi.nome
            if let t = try? await MotoriEve.generaConApple(istruzioni: istruzioni, richiesta: richiesta) {
                let pulito = t.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                // Ogni cifra della risposta deve venire dalla scheda o dalla bozza
                if !pulito.isEmpty, CommentoEve.numeriConservati(bozza: scheda + "\n" + bozza.testo, testo: pulito) {
                    risposta = pulito
                    motore = "Modello Apple"
                }
            }
            self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: risposta, titolo: bozza.titolo, motore: motore), cliente: id)
            self.eveInCorso = false
        }
    }

    /// Ciò che Eve sa del cliente: dati del dossier e risultati dei motori di Prisma.
    func fonteEve(_ id: String) -> FonteEve? {
        guard let c = cliente(id) else { return nil }
        return FonteEve(oggi: Date(), nomeUtente: nomeUtente, cliente: c, posizioni: posizioniCliente(id),
                        appuntamenti: appuntamentiCliente(id), attivita: attivitaCliente(id),
                        analisi: analisi360(id), analisiSalvata: analisiSalvata(id), simulazioni: simulazioniCliente(id),
                        incontri: incontriCliente(id), obiettivi: obiettiviCliente(id), prodotti: dati.prodotti, documenti: documentiCliente(id),
                        note: noteCliente(id).filter { !$0.vuota }, confronto: confrontoEve(id), anniConfronto: orizzonteSostituzione)
    }

    /// Il confronto aperto in Prospetti e report, se riguarda questo cliente.
    private func confrontoEve(_ id: String) -> (attuale: String, alternativa: String)? {
        guard case .sostituzione(let a, let b, _)? = prospetto,
              posizioni.contains(where: { $0.id == a && $0.clienteId == id }) else { return nil }
        return (a, b)
    }

    /// Fa spiegare a Eve un documento del cliente: dati con la pagina, confronto con il dossier,
    /// cosa resta da verificare. Con il modello Apple la spiegazione diventa discorsiva sulle stesse cifre.
    func spiegaDocumentoConEve(_ docId: String) {
        guard !eveInCorso, let d = documento(docId) else { return }
        clienteAttivoId = d.clienteId
        let id = d.clienteId
        guard let fonte = fonteEve(id) else { return }
        apri(.eve)
        let domanda = "Spiegami il documento «\(d.titolo)»"
        let bozza = MotoriEve.sintesi.documento(d, fonte: fonte)
        aggiungiMessaggio(MessaggioEve(autore: .utente, testo: domanda), cliente: id)
        let motore = motoreEve
        guard !(motore is MotoreSintesi), !d.campi.isEmpty else {
            aggiungiMessaggio(MessaggioEve(autore: .eve, testo: bozza.testo, titolo: bozza.titolo, motore: MotoriEve.sintesi.nome), cliente: id)
            return
        }
        // Al modello: la bozza con i dati esatti e un estratto delle prime pagine, entro la sua finestra
        let estratto = String(testoDocumento(d).joined(separator: "\n").prefix(ContestoEve.limiteCalcoli))
        let richiesta = "DOMANDA DEL CONSULENTE\n\(domanda)\n\nBOZZA PREPARATA DA PRISMA (dati estratti con la pagina: non cambiarli e non aggiungerne)\n"
            + String(bozza.testo.prefix(ContestoEve.limiteCalcoli))
            + "\n\nESTRATTO DEL DOCUMENTO\n\(estratto)\n\nSpiega il documento al consulente in modo ordinato, con le pagine, e segnala cosa verificare."
        eveInCorso = true
        Task { @MainActor in
            var testo = bozza.testo
            var nome = MotoriEve.sintesi.nome
            if let r = try? await MotoriEve.generaConApple(istruzioni: IstruzioniEve.chat, richiesta: richiesta),
               !r.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               CommentoEve.numeriConservati(bozza: bozza.testo + "\n" + estratto, testo: r) {
                testo = r.trimmingCharacters(in: .whitespacesAndNewlines)
                nome = "Modello Apple"
            }
            self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: testo, titolo: bozza.titolo, motore: nome), cliente: id)
            self.eveInCorso = false
        }
    }

    // MARK: - Commento del consulente nei report

    func commento(_ scelta: SceltaProspetto) -> CommentoReport? {
        guard let chiave = scelta.chiaveCommento(cliente: clienteAttivoId) else { return nil }
        return dati.commenti.first { $0.id == chiave }
    }

    func salvaCommento(_ scelta: SceltaProspetto, testo: String, bozzaDi: String? = nil) {
        guard let chiave = scelta.chiaveCommento(cliente: clienteAttivoId) else { return }
        let pulito = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        dati.commenti.removeAll { $0.id == chiave }
        guard !pulito.isEmpty else { return }
        dati.commenti.append(CommentoReport(id: chiave, clienteId: clienteAttivoId, testo: String(pulito.prefix(CommentoEve.limite)),
                                            bozzaDi: bozzaDi, aggiornatoIl: Appuntamento.alMinuto(Date())))
    }

    /// La bozza del commento composta dai testi del documento (stesse frasi e cifre del report).
    func bozzaCommento(_ scelta: SceltaProspetto) -> String? {
        let id = clienteAttivoId
        let nome = cliente(id)?.nome ?? ""
        switch scelta {
        case .checkUp:
            let t = testiCheckUp(id)
            return CommentoEve.bozza(nome: nome, apertura: "ti lascio la prima fotografia della tua situazione che abbiamo costruito insieme: cosa è in ordine e da dove conviene partire.",
                                     punti: t.sintesi, passo: t.prossimiPassi.first)
        case .resoconto:
            let t = testiResoconto(id)
            return CommentoEve.bozza(nome: nome, apertura: "ecco il punto sulle tue posizioni: cosa hai, come stanno andando, quanto costano e quanto incasseresti oggi al netto delle imposte.",
                                     punti: t.sintesi, passo: t.prossimiPassi.first)
        case .previdenza:
            let t = testiPrevidenza(id)
            return CommentoEve.bozza(nome: nome, apertura: "ti lascio il quadro della tua pensione: quanto potrebbe mancare, quanto aggiungono i tuoi piani e quanto ti restituisce il fisco sui versamenti.",
                                     punti: t.sintesi, passo: t.prossimiPassi.first)
        case .protezione:
            let t = testiProtezione(id)
            return CommentoEve.bozza(nome: nome, apertura: "ti lascio il quadro della protezione della tua famiglia: cosa è già coperto e cosa ancora no.",
                                     punti: t.sintesi, passo: t.prossimiPassi.first)
        case .resistenza:
            let t = testiResistenza(id)
            return CommentoEve.bozza(nome: nome, apertura: "ti lascio la prova di resistenza dei tuoi risparmi: cosa potrebbe succedere in tre anni difficili e se è una perdita che puoi sopportare.",
                                     punti: t.sintesi, passo: t.prossimiPassi.first)
        case .liquidita:
            let t = testiLiquidita(id)
            return CommentoEve.bozza(nome: nome, apertura: "ti lascio qualche idea su come far lavorare il capitale che arriva e la liquidità che hai, secondo quando ti servirà.",
                                     punti: t.sintesi, passo: t.prossimiPassi.first)
        case .obiettivo(let oid, _):
            guard let t = testiObiettivo(oid) else { return nil }
            return CommentoEve.bozza(nome: nome, apertura: "ecco il punto sul tuo obiettivo «\(t.o.titolo)»: dove sei, dove arrivi e cosa serve per raggiungerlo.",
                                     punti: t.sintesi, passo: t.prossimiPassi.first)
        case .sostituzione(let a, let b, _):
            guard let t = testiSostituzione(a, b) else { return nil }
            let punti = [("Il verdetto", t.titoloVerdetto + "."), ("Le cifre", t.sottotitoloVerdetto)].filter { !$0.1.isEmpty }
            return CommentoEve.bozza(nome: nome, apertura: t.e.sostituzione ? "ti lascio il confronto tra restare in \(t.a.nome) e passare a \(t.b.nome), con quello che costa uscire e quello che rende ciascuna strada."
                                                                            : "ti lascio il confronto tra \(t.a.nome) e \(t.b.nome), al netto di costi e imposte.",
                                     punti: punti, passo: t.prossimiPassi.first)
        case .posizione, .confronto, .valutazione, .portafoglio, .riesame:
            return nil
        }
    }

    /// Fa scrivere a Eve il commento del report aperto (il consulente poi lo rilegge e lo modifica).
    func scriviCommentoConEve(_ scelta: SceltaProspetto) {
        guard !eveInCorso, let bozza = bozzaCommento(scelta) else { return }
        let preferenza = dati.impostazioni.eve.motore
        let id = clienteAttivoId
        if preferenza == .sintesi || MotoriEve.motivoAppleNonDisponibile != nil {
            salvaCommento(scelta, testo: bozza, bozzaDi: MotoriEve.sintesi.nome)
            return
        }
        eveInCorso = true
        Task { @MainActor in
            let r = await CommentoEve.scrivi(bozza: bozza, preferenza: preferenza)
            if self.clienteAttivoId == id { self.salvaCommento(scelta, testo: r.testo, bozzaDi: r.motore) }
            self.eveInCorso = false
        }
    }

    /// Fa spiegare a Eve il documento aperto in Prospetti e report.
    func chiediEveDelDocumento(_ scelta: SceltaProspetto) {
        guard let s = scelta.spuntoEve else { return }
        apri(.eve)
        chiediEve(s.domanda, spunto: s)
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
            aggiungiMessaggio(MessaggioEve(autore: .eve, testo: r.testo, titolo: r.titolo, motore: motore.nome, proposte: r.proposte), cliente: id)
            return
        }
        // Le azioni proposte restano quelle calcolate da Prisma, anche quando il testo lo scrive il modello
        let proposte = richiesta.spunto == .proposte ? MotoriEve.sintesi.componi(richiesta).proposte : nil
        eveInCorso = true
        Task { @MainActor in
            do {
                let r = try await motore.rispondi(richiesta)
                self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: r.testo, titolo: r.titolo, motore: motore.nome, proposte: proposte), cliente: id)
            } catch {
                // Se il modello non risponde, per gli spunti c'è comunque la sintesi dai dati.
                let riserva = richiesta.spunto != nil ? "\n\nIntanto, dai dati del dossier:\n\n" + MotoriEve.sintesi.componi(richiesta).testo : ""
                self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: error.localizedDescription + riserva,
                                                    titolo: "Eve non ha potuto rispondere", motore: MotoriEve.sintesi.nome, proposte: proposte), cliente: id)
            }
            self.eveInCorso = false
        }
    }

    // MARK: - Proposte di Eve

    /// Un'azione proposta da Eve diventa un'attività del cliente (entro una settimana).
    func attivitaDaProposta(_ p: PropostaEve, messaggio: String) {
        var t = Attivita.nuova(clienteId: clienteAttivoId,
                               scadenza: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
        t.titolo = p.titolo
        t.note = "Proposta da Eve: \(p.perche)"
        dati.attivita.append(t)
        aggiornaProposta(p.id, messaggio: messaggio) { $0.attivitaId = t.id }
        mostraAvviso("Attività aggiunta: \(t.titolo)")
    }

    /// Un'azione proposta da Eve diventa una bozza di proposta in Posizioni, da completare.
    func posizioneDaProposta(_ p: PropostaEve, messaggio: String) {
        if let id = p.posizioneId, let esistente = posizioni.first(where: { $0.id == id }) {
            apriPosizione(esistente)
            return
        }
        guard let area = p.area else { return }
        let canali = cliente(clienteAttivoId)?.canali ?? []
        let canale = canali.contains(.alleanza) || canali.isEmpty ? Canale.alleanza : canali[0]
        var nuova = Posizione(clienteId: clienteAttivoId, canale: canale, stato: .proposta, area: area, nome: p.titolo)
        nuova.esito = .bozza
        nuova.rischio = p.rischio
        nuova.capitaleAssicurato = p.capitale
        if let v = p.versamentoMensile {
            nuova.premio = v
            nuova.frequenza = .mensile
        }
        if let i = p.importo, p.versamentoMensile == nil { nuova.versamentoIniziale = i }
        nuova.note = "Preparata con Eve: \(p.perche) Scegli prodotto e canale e completa i dati."
        salvaPosizione(nuova)
        aggiornaProposta(p.id, messaggio: messaggio) { $0.posizioneId = nuova.id }
        apriPosizione(nuova)
    }

    private func aggiornaProposta(_ id: String, messaggio: String, _ modifica: (inout PropostaEve) -> Void) {
        let cliente = clienteAttivoId
        func aggiorna(_ elenco: inout [MessaggioEve]) {
            guard let m = elenco.firstIndex(where: { $0.id == messaggio }),
                  let i = elenco[m].proposte?.firstIndex(where: { $0.id == id }) else { return }
            modifica(&elenco[m].proposte![i])
        }
        if dati.impostazioni.eve.conservaConversazioni {
            var elenco = dati.conversazioni[cliente] ?? []
            aggiorna(&elenco)
            dati.conversazioni[cliente] = elenco
        } else {
            var elenco = conversazioniTemporanee[cliente] ?? []
            aggiorna(&elenco)
            conversazioniTemporanee[cliente] = elenco
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

    /// Appuntamenti (filtrati per cliente) e scadenze dei giorni indicati, raggruppati per giorno
    /// in un solo passaggio: la settimana o il mese dell'agenda non rileggono l'archivio per ogni casella.
    func giorniAgenda(_ giorni: [Date]) -> GiorniAgenda {
        let cal = Calendar.current
        var indice = GiorniAgenda()
        guard let primo = giorni.min(), let ultimo = giorni.max() else { return indice }
        let inizio = cal.startOfDay(for: primo)
        let fine = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: ultimo)) ?? inizio
        let filtro = filtroClienteAgenda
        for a in appuntamenti where a.inizio >= inizio && a.inizio < fine && (filtro == nil || a.clienteId == filtro) {
            indice.perGiorno[cal.startOfDay(for: a.inizio), default: []].append(a)
        }
        for k in indice.perGiorno.keys { indice.perGiorno[k]?.sort { $0.inizio < $1.inizio } }
        for p in posizioni where p.stato == .inEssere && (filtro == nil || p.clienteId == filtro) {
            guard let s = p.scadenza, s >= inizio, s < fine else { continue }
            indice.scadenzePerGiorno[cal.startOfDay(for: s), default: []].append(p)
        }
        return indice
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

    /// La bozza dell'appuntamento per richiamare un cliente: una telefonata il prossimo giorno
    /// lavorativo, con il motivo e l'ultimo contatto nelle note. Si completa nel modulo dell'agenda.
    func bozzaRicontatto(_ d: Portafoglio.DaRicontattare, oggi: Date = Date()) -> Appuntamento {
        let cal = Calendar.current
        var giorno = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: oggi)) ?? oggi
        while cal.isDateInWeekend(giorno) { giorno = cal.date(byAdding: .day, value: 1, to: giorno) ?? giorno }
        var a = Appuntamento.nuovo(clienteId: d.cliente.id, giorno: giorno)
        a.titolo = d.motivo.map { "Ci risentiamo: \($0)" } ?? "Ci risentiamo"
        a.tipo = .telefonata
        a.luogo = "Telefonata"
        a.durataMinuti = 20
        a.note = [d.motivo.map { "Motivo: \($0)." },
                  d.ultimoContatto.map { "Ultimo contatto il \(Formati.dataEstesa.string(from: $0))." } ?? "Nessun incontro registrato in Prisma."]
            .compactMap { $0 }.joined(separator: " ")
        return a
    }

    /// La bozza dell'incontro di riesame: un'ora, in ufficio, il primo giorno lavorativo tra una settimana,
    /// con l'ordine del giorno nelle note. Si completa nel modulo dell'agenda.
    func bozzaRiesame(_ clienteId: String, oggi: Date = Date()) -> Appuntamento? {
        guard let f = fonteEve(clienteId) else { return nil }
        let r = MotoreRiesame.calcola(f)
        let cal = Calendar.current
        var giorno = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: oggi)) ?? oggi
        while cal.isDateInWeekend(giorno) { giorno = cal.date(byAdding: .day, value: 1, to: giorno) ?? giorno }
        var a = Appuntamento.nuovo(clienteId: clienteId, giorno: giorno)
        a.titolo = "Riesame annuale"
        a.tipo = .revisione
        a.durataMinuti = 60
        a.note = MotoreRiesame.agenda(r)
        return a
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

    // MARK: - Notifiche

    private func avviaNotifiche() {
        ricalcolaNotifiche()
        $dati
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.ricalcolaNotifiche() }
            .store(in: &abbonamenti)
        // Gli appuntamenti finiscono e i giorni cambiano anche senza toccare i dati
        timerNotifiche = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.ricalcolaNotifiche() }
        }
    }

    func ricalcolaNotifiche() {
        let nuove = MotoreNotifiche.calcola(self)
        if nuove != notifiche { notifiche = nuove }
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
        // Dentro la cartella dell'archivio ogni backup conterrebbe i precedenti e il ripristino li cancellerebbe
        let archivio = Archivio.cartella.standardizedFileURL.path
        let scelta = url.standardizedFileURL.path
        guard scelta != archivio, !scelta.hasPrefix(archivio + "/") else {
            mostraAvviso("Scegli una cartella fuori dalla cartella di Prisma, meglio su iCloud Drive o su un disco esterno.")
            return
        }
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
        let creaCartella = cartellaBackupPredefinita
        dati.impostazioni.backup.ultimoTentativo = Date()
        DispatchQueue.global(qos: .utility).async {
            do {
                let url = try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione,
                                                 nota: automatico ? GestoreBackup.notaAutomatico : nil, creaCartella: creaCartella)
                DispatchQueue.main.async {
                    self.backupInCorso = false
                    self.dati.impostazioni.backup.ultimo = Date()
                    self.dati.impostazioni.backup.ultimoErrore = nil
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("Backup creato: \(url.lastPathComponent)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.backupInCorso = false
                    self.dati.impostazioni.backup.ultimoErrore = error.localizedDescription
                    self.mostraAvviso("Backup non riuscito: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Ripristina un backup. Prima salva una copia di sicurezza dello stato attuale.
    func ripristina(_ zip: URL) {
        guard persistente, !backupInCorso else { return }
        guard !ripristinoBloccato else { mostraAvviso("Archivio in sola lettura: apri l'ultima versione di Prisma per ripristinare."); return }
        salvaOra()
        salvataggioSospeso = true
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        // Le impostazioni di backup e il nome restano quelli di oggi, non quelli del backup
        let backupDiOggi = dati.impostazioni.backup
        let nome = (dati.impostazioni.nomeUtente, dati.impostazioni.inizialiUtente)
        DispatchQueue.global(qos: .userInitiated).async {
            var estratta: URL?
            do {
                let estratto = try GestoreBackup.estrai(zip)
                estratta = estratto.cartella
                try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima del ripristino",
                                       creaCartella: creaCartella, proteggi: zip)
                try GestoreBackup.sostituisci(cartellaDati: Archivio.cartella, con: estratto.cartella)
                Archivio.segnaCopieGestite()
                DispatchQueue.main.async {
                    self.aggiornaCopieNonLeggibili()
                    var d = estratto.dati
                    d.impostazioni.backup = backupDiOggi
                    d.impostazioni.nomeUtente = nome.0
                    d.impostazioni.inizialiUtente = nome.1
                    self.dati = d
                    self.testiDocumenti = MemoriaTesti()
                    self.documentoSelezionato = nil
                    self.azzeraNote()
                    self.solaLettura = false
                    self.salvataggioSospeso = false
                    self.salvaOra()
                    self.backupInCorso = false
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("Ripristino completato. Lo stato precedente è salvato in un backup.")
                }
            } catch {
                if let estratta { GestoreBackup.pulisciEstrazione(estratta) }
                DispatchQueue.main.async {
                    self.salvataggioSospeso = self.solaLettura
                    self.backupInCorso = false
                    self.mostraAvviso("Ripristino non riuscito: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Copie di archivi non leggibili da sistemare (i backup automatici sono fermi).
    @Published private(set) var copieNonLeggibili = 0

    /// Il consulente ha controllato: i dati di oggi vanno bene, i backup automatici ripartono.
    func riprendiBackupAutomatici() {
        Archivio.segnaCopieGestite()
        aggiornaCopieNonLeggibili()
        controllaBackupAutomatico()
    }

    func aggiornaCopieNonLeggibili() {
        guard persistente else { return }
        copieNonLeggibili = Archivio.copieNonLeggibili.count
    }

    /// Gli identificativi dei clienti di prova.
    static let clientiDiProva: Set<String> = Set(DatiDemo.clienti().map(\.id))
    var haDatiDiProva: Bool { dati.clienti.contains { Self.clientiDiProva.contains($0.id) } }

    /// Toglie i 5 clienti di prova con tutti i loro dati (e le schede prodotto di esempio non usate),
    /// lasciando i clienti veri. Prima salva un backup.
    func togliDatiDiProva() {
        guard persistente, !backupInCorso, !solaLettura else { return }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima di togliere i dati di prova",
                                                        creaCartella: creaCartella) }
            DispatchQueue.main.async {
                self.backupInCorso = false
                switch esito {
                case .success:
                    self.rimuoviDatiDiProva()
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("Clienti di prova tolti. Lo stato precedente è salvato in un backup.")
                case .failure(let e):
                    self.mostraAvviso("Operazione annullata, backup non riuscito: \(e.localizedDescription)")
                }
            }
        }
    }

    /// Importa in rubrica i clienti scelti (da vCard o CSV). Prima salva un backup dello stato attuale.
    func importaClienti(_ elenco: [ClienteImportato]) {
        guard !elenco.isEmpty, !solaLettura else { return }
        guard persistente else {
            aggiungiImportati(elenco)
            return
        }
        guard !backupInCorso else { return }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima dell'importazione dei clienti",
                                                        creaCartella: creaCartella) }
            DispatchQueue.main.async {
                self.backupInCorso = false
                switch esito {
                case .success:
                    self.aggiungiImportati(elenco)
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("\(elenco.count) \(elenco.count == 1 ? "cliente importato" : "clienti importati"). Lo stato precedente è salvato in un backup."
                                      + (self.haDatiDiProva ? " I clienti di prova si tolgono da Impostazioni → Archivio." : ""))
                case .failure(let e):
                    self.mostraAvviso("Importazione annullata, backup non riuscito: \(e.localizedDescription)")
                }
            }
        }
    }

    /// Importa in Posizioni quelle scelte (da CSV). Prima salva un backup dello stato attuale.
    func importaPosizioni(_ elenco: [Posizione]) {
        guard !elenco.isEmpty, !solaLettura else { return }
        guard persistente else {
            dati.posizioni.append(contentsOf: elenco)
            return
        }
        guard !backupInCorso else { return }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima dell'importazione delle posizioni",
                                                        creaCartella: creaCartella) }
            DispatchQueue.main.async {
                self.backupInCorso = false
                switch esito {
                case .success:
                    self.dati.posizioni.append(contentsOf: elenco)
                    self.aggiornaElencoBackup()
                    let clienti = Set(elenco.map(\.clienteId)).count
                    self.mostraAvviso("\(elenco.count) \(elenco.count == 1 ? "posizione importata" : "posizioni importate") per \(clienti) \(clienti == 1 ? "cliente" : "clienti"). Lo stato precedente è salvato in un backup.")
                case .failure(let e):
                    self.mostraAvviso("Importazione annullata, backup non riuscito: \(e.localizedDescription)")
                }
            }
        }
    }

    /// La parte senza backup (usata anche dalle prove): ogni cliente con la sua tinta, il primo in primo piano.
    func aggiungiImportati(_ elenco: [ClienteImportato]) {
        for x in elenco {
            dati.clienti.append(x.cliente(tinta: prossimaTinta))
        }
        if let primo = elenco.first, let c = dati.clienti.last(where: { $0.nome == primo.nome }) { dati.clienteAttivoId = c.id }
    }

    /// La parte senza backup (usata anche dalle prove).
    func rimuoviDatiDiProva() {
        for id in Self.clientiDiProva { eliminaCliente(id) }
        let esempi = Set((DatiDemo.prodotti() + [DatiDemo.orizzonteValore()]).map(\.id))
        let usati = Set(dati.posizioni.compactMap(\.prodottoId) + dati.valutazioni.map(\.prodottoId))
        dati.prodotti.removeAll { esempi.contains($0.id) && !usati.contains($0.id) }
        if dati.clienti.first(where: { $0.id == dati.clienteAttivoId }) == nil {
            dati.clienteAttivoId = dati.clienti.first?.id ?? ""
        }
    }

    /// Torna ai 5 clienti di prova (con backup di sicurezza dello stato attuale).
    func ripristinaDatiDiProva() {
        guard persistente, !backupInCorso, !solaLettura else { return }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima dei dati di prova",
                                                        creaCartella: creaCartella) }
            DispatchQueue.main.async {
                self.backupInCorso = false
                switch esito {
                case .success:
                    var demo = DatiPrisma.demo()
                    demo.impostazioni = self.dati.impostazioni
                    self.dati = demo
                    self.azzeraNote()
                    // I file dei clienti veri restano nel backup appena fatto, non nell'archivio
                    self.pulisciDocumentiOrfani()
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
        // Con un archivio non leggibile da sistemare i backup automatici non sostituiscono quelli buoni
        guard b.automatico, !solaLettura, Archivio.copieNonLeggibili.isEmpty, let prossimo = b.prossimo, prossimo <= Date() else { return }
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
