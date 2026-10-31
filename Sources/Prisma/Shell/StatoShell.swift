#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import Combine
import SwiftUI

/// Stato della finestra Prisma: dati dell'archivio, finestre interne, backup, avvisi.
enum VistaAgenda: Hashable { case settimana, mese, occasioni }

enum FiltroAttivita: Hashable { case aperte, completate, tutte }

enum SchedaSimulazioni: Hashable { case simulatore, scenari, tfr }

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
    @Published var dati: DatiPrisma {
        didSet {
            versioneDati &+= 1
            // Gli array non toccati condividono la memoria con i vecchi: confrontarli costa O(1)
            if dati.note != oldValue.note { versioneNote &+= 1 }
            if !dati.stessiCalcoli(di: oldValue) { versioneCalcoli &+= 1 }
        }
    }
    /// Cresce a ogni modifica dei dati (salvataggio, segno della cache del dossier per Eve). Non pubblicata.
    private(set) var versioneDati = 0
    /// Cresce quando cambia qualcosa che entra nei calcoli e nei documenti: tutto tranne le note del taccuino,
    /// le conversazioni con Eve, gli spazi di lavoro, il cliente attivo e le impostazioni che non toccano i
    /// calcoli (DatiPrisma.stessiCalcoli). È la chiave delle cache di DerivatiDati. Non pubblicata.
    private(set) var versioneCalcoli = 0
    /// Cresce quando cambiano le note del taccuino (le leggono i documenti, per esempio il fascicolo). Non pubblicata.
    private(set) var versioneNote = 0

    /// Finestre interne, pannelli e blocco (StatoShellFinestre.swift ne inoltra le proprietà con i nomi di sempre):
    /// cambiarli non pubblica StatoShell, così le app aperte e i widget non si ricalcolano.
    let sistema = StatoFinestre()
    /// Titoli e abilitazioni del menu Vai (li osserva solo ComandiPrisma).
    let menu = StatoMenu()
    /// Dati ricavati dall'archivio, tenuti da parte per `versioneCalcoli` (DerivatiDati.swift).
    let derivati = DerivatiDati()

    @Published private(set) var avviso: String?
    @Published var schermoIntero = false
    @Published var schedaImpostazioni: SchedaImpostazioni = .esperienza
    @Published var schedaCliente: SchedaCliente = .panoramica
    /// Posizione aperta nel dettaglio (usata anche dalle istantanee).
    @Published var posizioneInDettaglio: String?
    /// Il pannello del dossier Posizioni a cui scorrere ("resistenza", "costi"); si consuma appena raggiunto.
    @Published var ancoraPosizioni: String?
    /// Il gruppo delle Impostazioni a cui scorrere ("impostazioni-conformita", "impostazioni-occasioni"); si consuma appena raggiunto.
    @Published var ancoraImpostazioni: String?
    /// I report spuntati per il fascicolo dell'incontro (per la sessione).
    @Published var sceltaFascicolo: Set<TipoProspetto> = TipoProspetto.fascicoloPredefinito
    /// L'appuntamento per cui si prepara il fascicolo (dà la data e il tipo d'incontro alla copertina).
    @Published var fascicoloAppuntamento: String?
    /// Il documento mostrato a tutto schermo all'incontro (nil se non si presenta).
    @Published var presentazione: Presentazione?
    /// L'ultima analisi del dossier calcolata, con la versione dei dati (non pubblicata). La cache vera è in
    /// DerivatiDati: questa resta come segno per la prova di Eve.
    var cacheDossier: (chiave: Int, valore: AnalisiDossier)?
    /// Posizioni mostra il portafoglio di tutti i clienti invece del dossier del cliente attivo.
    // Il portafoglio parla di tutti i clienti: in modalità cliente resta chiuso
    @Published var portafoglio = false { didSet { if portafoglio && modoCliente != nil { portafoglio = false } } }
    /// Modalità cliente: lo schermo girato verso il cliente mostra solo il suo dossier (id del cliente).
    @Published var modoCliente: String?
    /// Il pulsante dell'intestazione di Posizioni chiede di aprire il modulo (nuova posizione o proposta).
    @Published var richiestaNuovaPosizione: StatoPosizione?
    /// Il pulsante "Nuovo cliente" dell'intestazione chiede alla rubrica di aprire il modulo.
    @Published var richiestaNuovoCliente = false
    /// Completezza dei dati: chiede a Clienti o Posizioni di aprire il modulo su un campo (si consuma appena letta).
    @Published var richiestaCompletamento: RichiestaCompletamento?
    /// Completezza dei dati: il campo dell'Analisi 360 da evidenziare (si toglie lasciando quell'area).
    @Published var fuocoAnalisi: FuocoAnalisi?
    /// Seguito delle proposte: il modulo dell'esito da mostrare, con l'app che lo presenta.
    @Published var richiestaEsito: RichiestaEsito?
    /// Contatti letti da un file, in attesa di conferma nell'anteprima della rubrica.
    @Published var importazione: ImportazioneClienti?
    /// Posizioni lette da un file, in attesa di conferma in Posizioni.
    @Published var importazionePosizioni: ImportazionePosizioni?
    /// Il pannello «Aggiorna i valori» in Posizioni (elenco della compagnia o griglia dei valori fermi).
    @Published var aggiornaValori: AggiornaValori.Sessione?

    // Agenda e Attività (stato delle viste, non salvato)
    /// Giornata aperta in agenda.
    @Published var giornoAgenda = Calendar.current.startOfDay(for: Date())
    @Published var vistaAgenda: VistaAgenda = .settimana
    @Published var appuntamentoSelezionato: String?
    /// nil = tutti i clienti.
    @Published var filtroClienteAgenda: String?
    /// L'occasione scelta in Agenda (calendario delle occasioni): non si salva.
    @Published var occasioneSelezionata: Occasione?
    /// Il gruppo di tipi della vista «Occasioni» (nil = tutti): non si salva.
    @Published var gruppoOccasioniAgenda: GruppoOccasione?
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

    // Centro notifiche (il pannello aperto o chiuso sta in `sistema`)
    /// Le notifiche, ricalcolate poco dopo ogni modifica dei dati e una volta al minuto
    /// (non a ogni disegno della barra in alto).
    @Published private(set) var notifiche: [Notifica] = []
    private var timerNotifiche: Timer?
    /// Le notifiche già viste in questa sessione (la campanella conta le altre).
    @Published var notificheViste: Set<String> = []
    /// Promemoria del Mac: il permesso di macOS (nil finché non si sa, e sempre nelle istantanee e nelle prove).
    @Published var permessoPromemoria: PermessoPromemoria?

    /// Eve parla del portafoglio (tutti i clienti) invece che del cliente attivo.
    @Published var evePortafoglio = false { didSet { if evePortafoglio && modoCliente != nil { evePortafoglio = false } } }

    // Ricerca (⌘K)
    @Published var testoRicerca = ""
    /// Cresce a ogni ⌘K: la Ricerca rimette il cursore nel campo.
    @Published var richiestaFuocoRicerca = 0

    // Documenti
    @Published var documentoSelezionato: String?
    /// Raccolta, filtri, scheda e pagina dell'anteprima dell'app Documenti.
    @Published var vistaDocumenti = VistaDocumenti()
    @Published var documentiInLettura: Set<String> = []

    // Prospetti e report
    /// Prospetto scelto (nil = quadro delle posizioni del cliente attivo).
    @Published var prospetto: SceltaProspetto?
    /// Valutazione aperta nel modulo di modifica.
    @Published var valutazioneInModifica: ValutazioneInvestimento?
    private var testiDocumenti = MemoriaTesti()

    // Eve
    @Published var eveInCorso = false
    @Published var domandaEve = "" { didSet { if dettaturaAttiva, domandaEve != oldValue { dettaturaCambiata() } } }
    /// Conversazioni non conservate nell'archivio (se l'utente lo sceglie nelle impostazioni).
    @Published var conversazioniTemporanee: [String: [MessaggioEve]] = [:]
    /// La voce e l'orecchio di Eve: nascono alla prima parola (niente microfono finché non serve).
    /// Chi vuole solo fermarli (blocco, Eve chiusa) usa `…SeNata`/`…SeNato`, così non li fa nascere.
    private(set) var voceEveSeNata: VoceEve?
    private(set) var ascoltoEveSeNato: AscoltoEve?
    var voceEve: VoceEve {
        if let v = voceEveSeNata { return v }
        let v = VoceEve()
        voceEveSeNata = v
        return v
    }
    var ascoltoEve: AscoltoEve {
        if let a = ascoltoEveSeNato { return a }
        let a = AscoltoEve()
        ascoltoEveSeNato = a
        return a
    }
    /// La prossima risposta di Eve si dice anche a voce (la domanda è arrivata a voce).
    var rispostaAVoce = false
    /// Conversazione a voce in corso: dopo ogni risposta Eve torna ad ascoltare, finché non le dici «basta».
    @Published var conversazioneAVoce = false
    /// Qwen sul Mac (Ollama): pronto o perché no. Si aggiorna con `verificaMotoreLocale()`.
    @Published var disponibilitaLocale = DisponibilitaEve.nonDisponibile("Ollama non ancora verificato.")
    /// La risposta di Eve mentre arriva (osservata solo dalla bolla in arrivo).
    let flussoEve = FlussoEve()
    /// La mini finestra di Eve (⌥ Spazio, sfera nella barra): osservata solo dal suo pannello e dalla sfera.
    let miniEve = StatoMiniEve()
    /// La risposta in corso: si interrompe con una nuova conversazione.
    var compitoEve: Task<Void, Never>?
    /// Il confronto tra modelli (Impostazioni › Eve): a che punto è, e dove sta l'ultimo rapporto.
    @Published var avanzamentoConfronto: String?
    @Published var rapportoConfronto: URL?
    /// Nelle istantanee e nelle prove, dove Qwen non c'è: Eve risponde subito con i calcoli di Prisma.
    var rispostePreparate = false
    /// L'appuntamento chiesto a Eve a cui manca ancora il giorno o l'ora: la prossima frase lo completa.
    var appuntamentoInSospeso: Appuntamento.Bozza?
    /// La dettatura di macOS nel campo di Eve: ogni richiesta la avvia; la frase parte da sola alla pausa.
    @Published var richiestaDettatura = 0
    @Published var dettaturaAttiva = false
    /// In automatico, dopo un fallimento: il riconoscimento con cui riprovare, quelli ancora da provare, poi la dettatura di macOS.
    var ripiegoAscolto: SceltaRiconoscimento?
    var ripieghiRimasti: [SceltaRiconoscimento]?
    var usaDettatura = false
    var lavoroDettatura: DispatchWorkItem?
    /// La dettatura di macOS ha già scritto qualcosa in questa richiesta (per la diagnostica).
    var dettaturaHaScritto = false
    /// L'esito dell'ultima prova del riconoscimento e del microfono (dalle impostazioni), la prova in corso.
    @Published var esitoProvaRiconoscimento: String?
    @Published var esitoProvaMicrofono: String?
    var provaInCorso: ProvaRiconoscimento?
    /// Modalità diagnostica: l'ultimo passaggio dell'ascolto o della voce, mostrato sotto il campo di Eve.
    @Published var passaggioVoce: String?
    /// Nelle istantanee: lo stato della voce da mostrare (non c'è microfono).
    var voceIstantanea: StatoVoce?

    // Backup
    @Published private(set) var elencoBackup: [VoceBackup] = []
    @Published private(set) var backupInCorso = false
    /// La password dei backup per questa sessione (dal Portachiavi o appena scritta): mai nell'archivio.
    private var passwordBackupInMemoria: String?
    /// Il Portachiavi si legge da solo una volta per sessione (il Mac può chiedere il permesso):
    /// i backup automatici non lo richiedono a ogni controllo.
    private var portachiaviLetto = false
    /// Impostazioni › Archivio: si apre la richiesta della password dei backup.
    @Published var chiediPasswordBackup = false
    /// Un backup protetto da ripristinare, in attesa della password.
    @Published var ripristinoDaSbloccare: RichiestaPasswordBackup?

    /// Area delle finestre interne (sotto la barra, sopra il dock), aggiornata dalla vista. Non pubblicata:
    /// la shell disegna le finestre con la sua area (ShellView), questa serve alle azioni (aprire, spostare, affiancare).
    var area: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 700)

    /// false nelle istantanee: niente disco, niente animazioni.
    let persistente: Bool

    private var lavoroAvviso: DispatchWorkItem?
    /// Le sottoscrizioni dello stato (anche quelle di RipresaSistema.swift).
    var abbonamenti = Set<AnyCancellable>()
    #if os(macOS)
    /// Il controllo del backup automatico, quando il Mac è libero (al posto di un timer orario).
    private var attivitaBackup: NSBackgroundActivityScheduler?
    #endif
    /// Il salvataggio in background (Archivio.swift): generazione 0 = i dati letti all'avvio.
    private let salvataggio = SalvataggioArchivio()
    private var salvataggioSospeso = false
    /// Stop del Mac o schermo spento (RipresaSistema.swift): i lavori a tempo aspettano il risveglio.
    private(set) var lavoriInPausa = false
    private var ripresaLavori: DispatchWorkItem?
    /// Archivio di una versione più recente di Prisma: niente salvataggi né backup automatici.
    private(set) var solaLettura = false
    /// Archivio di una versione più recente: neanche il ripristino di un backup è sicuro.
    private(set) var ripristinoBloccato = false

    init(persistente: Bool = true) {
        self.persistente = persistente
        if persistente {
            // La lettura parte già in PrismaApp.init (AvvioArchivio): qui di solito è pronta
            let avvio = AvvioArchivio.attendi()
            let caricati = avvio.esito
            dati = caricati.dati
            // Prisma si apre sempre sulla schermata di benvenuto (mai nelle istantanee e nelle prove):
            // prima del primo disegno e prima di collegaMenu, così il menu Vai nasce già spento
            sistema.bloccato = true
            sistema.bloccatoStabile = true
            // Prima di disegnare qualcosa: i caratteri dell'interfaccia nascono con questa misura
            Tipo.fattore = caricati.dati.impostazioni.dimensioneTesto.fattore
            salvataggioSospeso = caricati.solaLettura
            solaLettura = caricati.solaLettura
            ripristinoBloccato = caricati.bloccaRipristino
            copieNonLeggibili = avvio.copieNonLeggibili
            if let a = caricati.avviso {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.mostraAvviso(a) }
            }
            // Una pagina nuova rimasta vuota alla chiusura non torna come «Bozza»
            if dati.note.contains(where: \.vuota) { dati.note.removeAll(where: \.vuota) }
            avviaSalvataggio()
            #if os(macOS)
            avviaBackupAutomatico()
            #elseif os(iOS)
            // Su iPhone e iPad niente backup automatico: i dati arrivano dal backup del Mac
            #endif
            preparaEve()
            DiagnosticaVoce.osservatore = { [weak self] riga in self?.passaggioVoce = riga }
            aggiornaElencoBackup()
            // Promemoria del Mac: solo qui, con l'archivio sul disco (mai nelle istantanee e nelle prove)
            avviaPromemoria()
            #if os(macOS)
            // L'aspetto scelto vale prima del primo disegno: niente lampo chiaro con l'aspetto scuro
            NSApplication.shared.appearance = StatoShell.aspettoMac(dati.impostazioni.aspetto)
            // Stop del Mac e risveglio (RipresaSistema.swift)
            avviaRipresa()
            // La mini finestra di Eve: ⌥ Spazio da qualsiasi app (PannelloMiniEve.swift)
            ControlloMiniEve.condiviso.avvia(stato: self)
            // Il ponte di Eve per iPhone e iPad (ServerPonteEve.swift): acceso solo se scelto in Impostazioni › Eve
            $dati.map(\.impostazioni.eve).removeDuplicates()
                .sink { ServerPonteEve.condiviso.aggiorna($0) }
                .store(in: &abbonamenti)
            #elseif os(iOS)
            // Su iPhone e iPad l'aspetto lo dà `.preferredColorScheme` della radice (StatoMobile);
            // background e ritorno in primo piano (RipresaSistema.swift)
            avviaRipresa()
            #endif
            // I file rimasti da un'importazione interrotta vanno nel Cestino (il disco lavora in background);
            // solo con l'archivio letto senza intoppi (con un archivio recuperato o di prova i file servono ancora)
            if caricati.avviso == nil, !caricati.solaLettura, copieNonLeggibili == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + StatoShell.attesaPulizia) { [weak self] in
                    guard let self, !self.lavoriInPausa else { return }
                    self.pulisciDocumentiOrfaniInBackground()
                }
            }
        } else {
            dati = DatiPrisma.demo()
        }
        avviaNotifiche()
        collegaMenu()
    }

    deinit {
        // Il run loop trattiene il timer: senza questo resterebbe acceso dopo uno stato delle prove o delle istantanee
        timerNotifiche?.invalidate()
    }

    /// Il menu Vai segue blocco, modalità cliente, presentazione e conversazione a voce, senza osservare StatoShell.
    private func collegaMenu() {
        Publishers.CombineLatest4(sistema.$bloccato, $modoCliente.map { $0 != nil },
                                  $presentazione.map { $0 != nil }, $conversazioneAVoce)
            .sink { [weak self] b, m, p, v in
                self?.menu.aggiorna(bloccato: b, inModoCliente: m, inPresentazione: p, conversazioneAVoce: v)
            }
            .store(in: &abbonamenti)
    }

    #if os(macOS)
    /// L'aspetto da dare all'app (nil = segue il Mac); come `AspettoInterfaccia.aspettoMac`, fuori dal MainActor.
    static func aspettoMac(_ aspetto: AspettoInterfaccia) -> NSAppearance? {
        switch aspetto {
        case .automatico: return nil
        case .chiaro: return NSAppearance(named: .aqua)
        case .scuro: return NSAppearance(named: .darkAqua)
        }
    }
    #elseif os(iOS)
    /// Per le funzioni legate ai pannelli e alle finestre del Mac, che su iPhone e iPad arrivano nei prossimi giri.
    static let soloSulMacPerOra = "Su iPhone e iPad questa funzione non c'è ancora: usala da Prisma sul Mac."
    /// Il file da scegliere con `.fileImporter` (al posto di NSOpenPanel del Mac): lo presenta il guscio
    /// dell'iPad (GuscioiPad), poi StatoMobile.importa passa la copia a `importaClienti(da:)` e simili.
    @Published var sceltaFileMobile: SceltaFileMobile?
    #endif

    // MARK: - Lettura

    // In modalità cliente le app vedono solo il cliente davanti a te: gli altri non compaiono da nessuna parte
    var clienti: [Cliente] { modoCliente.map { id in dati.clienti.filter { $0.id == id } } ?? dati.clienti }
    var appuntamenti: [Appuntamento] { modoCliente.map { id in dati.appuntamenti.filter { $0.clienteId == id } } ?? dati.appuntamenti }
    var attivita: [Attivita] { modoCliente.map { id in dati.attivita.filter { $0.clienteId == id } } ?? dati.attivita }
    var nomeUtente: String { dati.impostazioni.nomeUtente }
    var inizialiUtente: String { dati.impostazioni.inizialiUtente }

    /// In modalità cliente il cliente attivo resta quello mostrato: nessun percorso porta a un altro dossier.
    var clienteAttivoId: String {
        get { modoCliente ?? dati.clienteAttivoId }
        set {
            guard modoCliente == nil else { return }
            // Il fascicolo preparato per l'appuntamento di un cliente non segue un altro cliente
            if newValue != dati.clienteAttivoId { fascicoloAppuntamento = nil }
            dati.clienteAttivoId = newValue
        }
    }

    var clienteAttivo: Cliente? { clienti.first { $0.id == clienteAttivoId } }

    /// Di chi parla la finestra di un'app: il suo cliente, tutti i clienti (filtri vuoti, portafoglio)
    /// o nil se l'app non riguarda i clienti. Le app del dossier mostrano il cliente attivo;
    /// Agenda, Attività e Note il cliente del loro filtro.
    func contesto(di app: AppPrisma) -> String? {
        let attivo = clienteAttivo?.nome ?? "Nessun cliente"
        let tutti = "Tutti i clienti"
        let delPortafoglio = "Portafoglio · tutti i clienti"
        func filtro(_ id: String?) -> String {
            guard let id else { return tutti }
            return cliente(id)?.nome ?? tutti
        }
        switch app {
        case .clienti, .analisi360, .obiettivi, .simulazioni, .confronti, .documenti, .incontri:
            return attivo
        case .posizioni:
            return portafoglio ? delPortafoglio : attivo
        case .eve:
            return evePortafoglio ? delPortafoglio : attivo
        case .presentazioni:
            return sceltaProspetto.tipo == .portafoglio ? delPortafoglio : attivo
        case .agenda:
            return filtro(filtroClienteAgenda)
        case .attivita:
            return filtro(filtroClienteAttivita)
        case .note:
            return filtro(filtroClienteNote)
        case .prodotti:
            return "Catalogo dei prodotti"
        case .ricerca:
            return testoRicerca.isEmpty ? nil : "«\(testoRicerca)»"
        case .impostazioni:
            return nil
        }
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
        dati.schedeAdeguatezza.removeAll { $0.clienteId == id }
        dati.fotografie.removeAll { $0.clienteId == id }
        dati.confrontiTFR[id] = nil
        for d in dati.documenti where d.clienteId == id { rimuoviFile(d) }
        dati.documenti.removeAll { $0.clienteId == id }
        if modoCliente == id { modoCliente = nil }
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

    func salvaPosizione(_ posizione: Posizione) {
        if let i = dati.posizioni.firstIndex(where: { $0.id == posizione.id }) {
            // Il valore che cambia resta nello storico, per il resoconto
            var nuova = posizione
            nuova.registraValorePrecedente(dati.posizioni[i])
            // Seguito delle proposte: date di presentazione e di esito quando cambia l'esito
            MotoreSeguitoProposte.registraCambio(da: dati.posizioni[i], a: &nuova, adesso: Posizione.oggiArrotondato)
            dati.posizioni[i] = nuova
        } else {
            var nuova = posizione
            MotoreSeguitoProposte.registraCambio(da: nil, a: &nuova, adesso: Posizione.oggiArrotondato)
            dati.posizioni.append(nuova)
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
        dati.schedeAdeguatezza.removeAll { $0.posizioneId == id }
        // I commenti dei confronti che la usavano
        dati.commenti.removeAll { $0.id.hasPrefix("sostituzione·") && $0.id.components(separatedBy: "·").contains(id) }
    }

    /// Una proposta accettata diventa una posizione in essere, con i dati proposti dal seguito (decorrenza,
    /// primo valore, versato). L'interfaccia apre il modulo dell'esito; questa resta per chi la chiama.
    func attivaProposta(_ id: String) {
        guard let p = dati.posizioni.first(where: { $0.id == id }) else { return }
        chiudiProposta(id, .accettata(datiAccettazione(p, appuntamento: nil)), appuntamentoId: nil)
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

    func aggiornaDocumento(_ id: String, _ cambia: (inout Documento) -> Void) {
        guard let i = dati.documenti.firstIndex(where: { $0.id == id }) else { return }
        cambia(&dati.documenti[i])
    }

    /// Il testo di un documento senza file (documenti di prova delle istantanee e delle prove): resta nella memoria dei
    /// testi come quelli letti dal disco.
    func memorizzaTesto(_ id: String, _ pagine: [String]) { testiDocumenti[id] = pagine }

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

    /// Legge il testo (PDFKit, poi Vision per le scansioni) e cerca i dati; Qwen completa.
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
                    let categoria = MotoreDocumenti.categoriaProbabile(esito.pagine, tipo: x.tipo)
                    // Identità e questionari restano `.altro` per Eve; gli altri prendono il tipo dal testo
                    if x.tipo == .altro, categoria != .identita, categoria != .questionario {
                        x.tipo = EstrattoreDocumento.tipoProbabile(esito.pagine)
                    }
                    // Rileggendo, la categoria scelta dal consulente resta
                    if x.categoria == nil { x.categoria = categoria }
                    // Rileggendo, i dati già confermati (e corretti a mano) restano
                    x.campi = EstrattoreDocumento.unisci(x.campi.filter(\.confermato), campi)
                }
                self.completaConModello(id, pagine: esito.pagine, trovati: campi)
            }
        }
    }

    /// Qwen legge le prime pagine e propone i campi che le regole non hanno trovato.
    private func completaConModello(_ id: String, pagine: [String], trovati: [CampoEstratto]) {
        guard let modello = generativo, trovati.count < CampoDocumento.allCases.count else {
            documentiInLettura.remove(id)
            return
        }
        Task { @MainActor in
            var trovatiModello: [CampoEstratto] = []
            for (n, pagina) in pagine.prefix(6).enumerated() where pagina.count > 80 {
                if let r = try? await modello.genera(istruzioni: EstrattoreDocumento.istruzioniModello,
                                                     richiesta: "PAGINA \(n + 1)\n" + String(pagina.prefix(3_000))) {
                    trovatiModello += EstrattoreDocumento.daRisposta(r, pagina: n + 1)
                }
            }
            // Contro lo stato di adesso: conferme e correzioni fatte durante la lettura restano
            self.aggiornaDocumento(id) { $0.campi = EstrattoreDocumento.unisci($0.campi, trovatiModello) }
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
        let orfani = Self.fileOrfani(usati: fileUsati(), radice: Archivio.cartellaDocumenti)
        return Self.togli(orfani.file, cartelle: orfani.cartelle, nelCestino: nelCestino)
    }

    /// La stessa pulizia, all'avvio, con il disco in background: i file usati si contano sul thread principale,
    /// cartella e Cestino si toccano fuori. Se nel frattempo i documenti cambiano (un'importazione) si rinuncia:
    /// i file creati dopo l'elenco non ne fanno parte, e quelli di prima sono di nuovo controllati qui.
    func pulisciDocumentiOrfaniInBackground() {
        guard persistente, !solaLettura, documentiInLettura.isEmpty else { return }
        let usati = fileUsati()
        let impronta = dati.documenti.map(\.file)
        let radice = Archivio.cartellaDocumenti
        DispatchQueue.global(qos: .utility).async {
            let orfani = StatoShell.fileOrfani(usati: usati, radice: radice)
            guard !orfani.file.isEmpty || !orfani.cartelle.isEmpty else { return }
            DispatchQueue.main.async {
                guard !self.solaLettura, self.documentiInLettura.isEmpty, self.dati.documenti.map(\.file) == impronta else { return }
                DispatchQueue.global(qos: .utility).async {
                    let tolti = StatoShell.togli(orfani.file, cartelle: orfani.cartelle, nelCestino: true)
                    guard tolti > 0 else { return }
                    DispatchQueue.main.async {
                        self.mostraAvviso("\(tolti) \(tolti == 1 ? "file non più usato spostato" : "file non più usati spostati") nel Cestino")
                    }
                }
            }
        }
    }

    /// I file (e i testi letti) dei documenti dell'archivio.
    private func fileUsati() -> [URL] {
        dati.documenti.flatMap { d in [urlDocumento(d), urlTesto(d)].compactMap { $0 } }
    }

    /// I file della cartella Documenti che nessun documento usa, e le cartelle (le più esterne prima).
    /// Solo disco: va bene anche fuori dal thread principale.
    private static func fileOrfani(usati: [URL], radice: URL) -> (file: [URL], cartelle: [URL]) {
        let usati = Set(usati.map { $0.resolvingSymlinksInPath().path })
        guard let elenco = FileManager.default.enumerator(at: radice.standardizedFileURL,
                                                          includingPropertiesForKeys: [.isRegularFileKey]) else { return ([], []) }
        var file: [URL] = []
        var cartelle: [URL] = []
        for case let u as URL in elenco {
            guard (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                cartelle.append(u)
                continue
            }
            if !usati.contains(u.resolvingSymlinksInPath().path) { file.append(u) }
        }
        return (file, cartelle)
    }

    /// Toglie i file (nel Cestino o del tutto) e le cartelle rimaste vuote; restituisce quanti file ha tolto.
    private static func togli(_ file: [URL], cartelle: [URL], nelCestino: Bool) -> Int {
        let fm = FileManager.default
        var tolti = 0
        for u in file {
            if nelCestino {
                if (try? fm.trashItem(at: u, resultingItemURL: nil)) != nil { tolti += 1 }
            } else if (try? fm.removeItem(at: u)) != nil {
                tolti += 1
            }
        }
        // Le cartelle dei clienti rimaste vuote (le più interne prima). rmdir non toglie mai una cartella
        // in cui nel frattempo è arrivato un file
        for c in cartelle.reversed() {
            let dentro = (try? fm.contentsOfDirectory(atPath: c.path)) ?? ["?"]
            guard dentro.allSatisfy({ $0 == ".DS_Store" }) else { continue }
            if !dentro.isEmpty { try? fm.removeItem(at: c.appendingPathComponent(".DS_Store")) }
            _ = rmdir(c.path)
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
        case .costi(let report)?:
            return .costi(report: report)
        case .successione(let report)?:
            return .successione(report: report)
        case .patrimonio(let report)?:
            return .patrimonio(report: report)
        case .fascicolo?:
            return .fascicolo
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
            // Le ipotesi stimate della completezza: pagina (prospetto) o slide (report) in più
            let k = completezzaCliente(clienteAttivoId)
            return DocumentoStampabile(testiCheckUp(clienteAttivoId), report: report, commento: testoCommento(scelta),
                                       ipotesi: k?.ipotesi(per: .checkUp) ?? [], percentuale: k?.percentuale)
        }
        if case .liquidita(let report) = scelta {
            return DocumentoStampabile(testiLiquidita(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        if case .fascicolo = scelta { return documentoFascicolo() }
        if case .patrimonio(let report) = scelta {
            return DocumentoStampabile(testiPatrimonio(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        if case .successione(let report) = scelta {
            return DocumentoStampabile(testiSuccessione(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        if case .costi(let report) = scelta {
            return DocumentoStampabile(testiCosti(clienteAttivoId), report: report, commento: testoCommento(scelta), prodotti: dati.prodotti)
        }
        if case .resistenza(let report) = scelta {
            return DocumentoStampabile(testiResistenza(clienteAttivoId), report: report, commento: testoCommento(scelta))
        }
        if case .protezione(let report) = scelta {
            // Le ipotesi stimate della completezza: pagina (prospetto) o slide (report) in più
            let k = completezzaCliente(clienteAttivoId)
            return DocumentoStampabile(testiProtezione(clienteAttivoId), report: report, commento: testoCommento(scelta),
                                       ipotesi: k?.ipotesi(per: .protezione) ?? [], percentuale: k?.percentuale)
        }
        if case .previdenza(let report) = scelta {
            // Le ipotesi stimate della completezza: pagina (prospetto) o slide (report) in più
            let k = completezzaCliente(clienteAttivoId)
            return DocumentoStampabile(testiPrevidenza(clienteAttivoId), report: report, commento: testoCommento(scelta),
                                       ipotesi: k?.ipotesi(per: .previdenza) ?? [], percentuale: k?.percentuale)
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

    /// I testi e i numeri del patrimonio nel tempo di un cliente (lo stesso calcolo del pannello in Posizioni).
    func testiPatrimonio(_ id: String) -> TestiPatrimonio {
        let mie = posizioniCliente(id)
        return TestiPatrimonio(MotorePatrimonio.calcola(mie, obiettivi: obiettiviCliente(id)), posizioni: mie, cliente: cliente(id))
    }

    /// I testi e i numeri del passaggio generazionale di un cliente (lo stesso calcolo del pannello in Posizioni).
    func testiSuccessione(_ id: String) -> TestiSuccessione {
        let c = self.cliente(id)
        let s = c.map { MotoreSuccessione.calcola(cliente: $0, posizioni: posizioniCliente(id)) }
            ?? Successione(voci: [], eredi: [], attivoAsse: 0, debiti: 0, fuoriAsse: 0, immobili: 0, ipocatastali: 0, primaCasa: false, conviventeEscluso: nil, avvisi: [])
        return TestiSuccessione(s, cliente: c)
    }

    /// I testi e i numeri del costo degli investimenti di un cliente (lo stesso calcolo del pannello in Posizioni).
    func testiCosti(_ id: String) -> TestiCosti {
        TestiCosti(MotoreCosti.calcola(posizioniCliente(id), prodotti: dati.prodotti, cliente: id), cliente: self.cliente(id))
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
        if case .riesame = scelta { return fonteEve(clienteAttivoId).map { CompositoreProspetti.riesame($0, conformita: conformitaCliente(clienteAttivoId), occasioni: occasioniRiesame(clienteAttivoId), memoria: memoriaRiesame(clienteAttivoId)) } }
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
        // Il RIY del KID è un'incidenza complessiva, non il costo corrente: resta nel suo campo, mai come costo annuo
        p.costoAnnuo = EstrattoreDocumento.numero(d.confermato(.costoAnnuo))
        p.incidenzaCostiKID = EstrattoreDocumento.numero(d.confermato(.incidenzaCosti))
        p.periodoRaccomandato = Self.anniDaDocumento(d.confermato(.periodoDetenzione))
        p.fonte = "\(d.titolo) (\(d.tipo.breve), importato il \(Formati.dataBreve.string(from: d.importatoIl)))"
        p.verificatoIl = Calendar.current.startOfDay(for: Date())
        if let anni = d.confermato(.periodoDetenzione) { p.note = "Periodo di detenzione raccomandato: \(anni) anni." }
        // Il rendimento atteso di Prisma è lordo: lo scenario moderato del KID è netto (i costi si conterebbero due volte)
        if let lordo = MotoreConfrontoDossier.rendimentoLordo(d, soloConfermati: true) {
            p.rendimentoAtteso = (lordo.valore * 100).rounded() / 100
            if lordo.fonte == .stima {
                p.note = (p.note + " Rendimento lordo stimato da Prisma dallo scenario moderato del KID (netto).")
                    .trimmingCharacters(in: .whitespaces)
            }
        } else {
            p.rendimentoAtteso = nil
        }
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
        p.costoUscita = EstrattoreDocumento.numero(d.confermato(.costoUscita))
        p.incidenzaCostiKID = EstrattoreDocumento.numero(d.confermato(.incidenzaCosti))
        p.periodoRaccomandato = Self.anniDaDocumento(d.confermato(.periodoDetenzione))
        p.sri = d.confermato(.sri).flatMap { Int($0.prefix(1)) }
        p.note = "Dati dal documento «\(d.titolo)», da completare."
        salvaPosizione(p)
        aggiornaDocumento(id) { $0.posizioneId = p.id }
        apriPosizione(p)
    }

    /// Gli anni del periodo di detenzione raccomandato letti da un documento («5» o «5 anni»), tra 1 e 60.
    static func anniDaDocumento(_ testo: String?) -> Int? {
        guard let testo else { return nil }
        let cifre = testo.trimmingCharacters(in: .whitespaces).prefix(while: { $0.isASCII && $0.isNumber })
        guard let anni = Int(String(cifre)), anni >= 1, anni <= 60 else { return nil }
        return anni
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
        posizioni.filter { $0.prodottoId == id }
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

    /// Legge gli appunti: regole di Prisma subito, Qwen (se è pronto) si aggiunge.
    func estraiProposte(_ i: Incontro) {
        let altro = [i.progetti, i.esperienza, i.appunti, i.decisioni].filter { !$0.isEmpty }.joined(separator: "\n")
        let regole = EstrattoreIncontro.conRegole(altro, preoccupazioni: i.preoccupazioni)
        proposteIncontro[i.id] = regole
        proposteScelte = Set(regole.map(\.id))
        guard persistente, let modello = generativo, !i.vuoto else { return }
        estrazioneInCorso = true
        let testo = i.testoAscolto
        Task { @MainActor in
            if let risposta = try? await modello.genera(istruzioni: EstrattoreIncontro.istruzioniModello,
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
            // Seguito delle proposte: Incontri chiede l'esito della proposta presentata
            segnaConclusione(dati.appuntamenti[k].id, origine: .incontri)
        }
        i.stato = .concluso
        // Riesame con memoria: l'incontro di riesame concluso salva la fotografia delle cifre chiave
        if incontroDiRiesame(i) { fotografaRiesame(i.clienteId, origine: .incontro, avviso: false) }
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

    /// Qwen sul Mac, pronto o no: nome, descrizione e stato per la striscia di Eve.
    var qwen: MotoreLocale { MotoriEve.qwen(dati.impostazioni.eve, locale: disponibilitaLocale) }
    /// Qwen se è pronto; nil se Ollama è spento o manca il modello.
    var generativo: (MotoreEve & MotoreGenerativo)? { MotoriEve.generativo(dati.impostazioni.eve, locale: disponibilitaLocale) }

    /// Eve risponde con Qwen. Se l'ultima verifica non l'ha trovato pronto, prima chiede di nuovo a Ollama
    /// (magari è stato appena aperto); se ancora non c'è, Eve lo dice e non risponde.
    private func conQwen(cliente id: String, _ poi: @escaping ((MotoreEve & MotoreGenerativo)) -> Void) {
        if let m = generativo {
            poi(m)
            return
        }
        let eve = dati.impostazioni.eve
        eveInCorso = true
        Task { @MainActor in
            let d = await MotoreLocale.verifica(eve)
            if self.disponibilitaLocale != d { self.disponibilitaLocale = d }
            self.eveInCorso = false
            if let m = self.generativo { poi(m) } else { self.qwenNonPronto(cliente: id) }
        }
    }

    /// Il messaggio di Eve quando Qwen non c'è: il motivo e cosa fare.
    func qwenNonPronto(cliente id: String) {
        let motivo = disponibilitaLocale.motivo ?? "Qwen non risponde."
        aggiungiMessaggio(MessaggioEve(autore: .eve, testo: motivo + " Eve risponde solo con Qwen: quando è pronto, rifai la domanda.",
                                       titolo: "Qwen non è pronto", motore: "Prisma"), cliente: id)
    }

    /// Chiede a Ollama, sul Mac, se Qwen è pronto (all'avvio, aprendo Eve e dalle impostazioni).
    func verificaMotoreLocale() {
        guard persistente else { return }
        let eve = dati.impostazioni.eve
        Task {
            let d = await MotoreLocale.verifica(eve)
            DispatchQueue.main.async { if self.disponibilitaLocale != d { self.disponibilitaLocale = d } }
        }
    }

    /// All'avvio, qualche secondo dopo la finestra: se serve apre Ollama e carica il modello (solo sul Mac).
    func preparaEve() {
        guard persistente else { return }
        #if os(macOS)
        guard dati.impostazioni.eve.prontaAllAvvio else { return verificaMotoreLocale() }
        DispatchQueue.main.asyncAfter(deadline: .now() + StatoShell.attesaPreparazioneEve) { [weak self] in
            guard let self else { return }
            let eve = self.dati.impostazioni.eve
            Task.detached(priority: .utility) {
                let d = await AvvioModello.prepara(eve)
                await MainActor.run { if self.disponibilitaLocale != d { self.disponibilitaLocale = d } }
            }
        }
        #else
        verificaMotoreLocale()
        #endif
    }

    static let attesaPreparazioneEve: TimeInterval = 3

    /// Dove si trova il consulente: per la riga di contesto di Eve.
    func ambienteEve(cliente id: String) -> AmbienteEve {
        AmbienteEve(oggi: Date(), appAperte: finestre.map { $0.app.titolo }, cliente: cliente(id)?.nome)
    }

    func conversazione(_ id: String) -> [MessaggioEve] {
        dati.impostazioni.eve.conservaConversazioni ? (dati.conversazioni[id] ?? []) : (conversazioniTemporanee[id] ?? [])
    }

    func aggiungiMessaggio(_ m: MessaggioEve, cliente id: String, parla: Bool = true) {
        var elenco = conversazione(id)
        elenco.append(m)
        elenco = Array(elenco.suffix(Self.massimoMessaggi))
        if dati.impostazioni.eve.conservaConversazioni {
            dati.conversazioni[id] = elenco
        } else {
            conversazioniTemporanee[id] = elenco
        }
        if m.autore == .eve, parla { parlaRisposta(m) }
    }

    func nuovaConversazione() {
        let id = evePortafoglio ? EvePortafoglio.chiave : clienteAttivoId
        // Una risposta ancora in arrivo si ferma qui
        compitoEve?.cancel()
        compitoEve = nil
        dati.conversazioni[id] = nil
        conversazioniTemporanee[id] = nil
    }

    /// Una domanda a Eve sul portafoglio (tutti i clienti). Le cifre sono quelle della vista Portafoglio;
    /// Qwen le racconta senza cambiarle (se cambia una cifra restano quelle di Prisma).
    @discardableResult
    func chiediEvePortafoglio(_ domanda: String, spunto: SpuntoPortafoglio? = nil, breve: Bool = false) -> Bool {
        let testo = domanda.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testo.isEmpty, !eveInCorso else { return false }
        // La domanda parte da tastiera o da uno spunto: la dettatura del Mac si spegne (anche per i comandi)
        if dettaturaAttiva { chiudiDettatura() }
        if spunto == nil, eseguiComandoEve(testo) { return true }
        let id = EvePortafoglio.chiave
        aggiungiMessaggio(MessaggioEve(autore: .utente, testo: testo), cliente: id)
        domandaEve = ""
        let argomento = spunto ?? SpuntoPortafoglio.da(testo)
        let bozza = EvePortafoglio.risposta(argomento, domanda: testo, dati: dati)
        if rispostePreparate {
            aggiungiMessaggio(MessaggioEve(autore: .eve, testo: bozza.testo, titolo: bozza.titolo, motore: MotoriEve.sintesi.nome), cliente: id)
            return true
        }
        let scheda = EvePortafoglio.scheda(dati)
        let istruzioni = (IstruzioniEve.testo("chat") ?? "") + "\nQui parli del portafoglio del consulente (tutti i clienti), non di un singolo cliente."
            + (breve ? "\n\n" + IstruzioniEve.mini : "")
        let richiesta = "SCHEDA DEL PORTAFOGLIO (calcolata da Prisma)\n\(scheda)\n\nBOZZA PREPARATA DA PRISMA (numeri esatti: non cambiarli e non aggiungerne)\n\(bozza.testo)\n\nDOMANDA DEL CONSULENTE: \(testo)"
        conQwen(cliente: id) { modello in
            self.eveInCorso = true
            Task { @MainActor in
                do {
                    let t = try await modello.genera(istruzioni: istruzioni, richiesta: richiesta)
                    let pulito = t.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    // Ogni cifra della risposta deve venire dalla scheda o dalla bozza: altrimenti restano le cifre di Prisma
                    let fedele = !pulito.isEmpty && CommentoEve.numeriConservati(bozza: scheda + "\n" + bozza.testo, testo: pulito)
                    self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: fedele ? pulito : bozza.testo, titolo: bozza.titolo,
                                                        motore: fedele ? modello.nome : MotoriEve.sintesi.nome), cliente: id)
                } catch {
                    self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: error.localizedDescription,
                                                        titolo: "Eve non ha potuto rispondere", motore: modello.nome), cliente: id)
                }
                self.eveInCorso = false
            }
        }
        return true
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
    /// cosa resta da verificare. Qwen la rende discorsiva sulle stesse cifre.
    func spiegaDocumentoConEve(_ docId: String) {
        guard !eveInCorso, let d = documento(docId) else { return }
        clienteAttivoId = d.clienteId
        let id = d.clienteId
        guard let fonte = fonteEve(id) else { return }
        apri(.eve)
        let domanda = "Spiegami il documento «\(d.titolo)»"
        let bozza = MotoriEve.sintesi.documento(d, fonte: fonte)
        aggiungiMessaggio(MessaggioEve(autore: .utente, testo: domanda), cliente: id)
        if rispostePreparate {
            aggiungiMessaggio(MessaggioEve(autore: .eve, testo: bozza.testo, titolo: bozza.titolo, motore: MotoriEve.sintesi.nome), cliente: id)
            return
        }
        // Al modello: la bozza con i dati esatti e un estratto delle prime pagine, entro la sua finestra
        let estratto = String(testoDocumento(d).joined(separator: "\n").prefix(ContestoEve.limiteCalcoli))
        let richiesta = "DOMANDA DEL CONSULENTE\n\(domanda)\n\nBOZZA PREPARATA DA PRISMA (dati estratti con la pagina: non cambiarli e non aggiungerne)\n"
            + String(bozza.testo.prefix(ContestoEve.limiteCalcoli))
            + "\n\nESTRATTO DEL DOCUMENTO\n\(estratto)\n\nSpiega il documento al consulente in modo ordinato, con le pagine, e segnala cosa verificare."
        conQwen(cliente: id) { modello in
            self.eveInCorso = true
            Task { @MainActor in
                do {
                    let r = try await modello.genera(istruzioni: IstruzioniEve.chat, richiesta: richiesta).trimmingCharacters(in: .whitespacesAndNewlines)
                    // Cifre diverse da quelle del documento: restano i dati estratti da Prisma, con le pagine
                    let fedele = !r.isEmpty && CommentoEve.numeriConservati(bozza: bozza.testo + "\n" + estratto, testo: r)
                    self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: fedele ? r : bozza.testo, titolo: bozza.titolo,
                                                        motore: fedele ? modello.nome : MotoriEve.sintesi.nome), cliente: id)
                } catch {
                    self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: error.localizedDescription,
                                                        titolo: "Eve non ha potuto rispondere", motore: modello.nome), cliente: id)
                }
                self.eveInCorso = false
            }
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
        case .patrimonio:
            let t = testiPatrimonio(id)
            return CommentoEve.bozza(nome: nome, apertura: "ti lascio il percorso del tuo patrimonio nei prossimi anni: dove ti porta la strada di oggi e dove potresti arrivare con le proposte che abbiamo visto.",
                                     punti: t.sintesi, passo: t.prossimiPassi.first)
        case .successione:
            let t = testiSuccessione(id)
            return CommentoEve.bozza(nome: nome, apertura: "ti lascio il quadro di come passerebbe il tuo patrimonio alla tua famiglia: cosa arriva subito, cosa con la successione e cosa conviene sistemare oggi.",
                                     punti: t.sintesi, passo: t.prossimiPassi.first)
        case .costi:
            let t = testiCosti(id)
            return CommentoEve.bozza(nome: nome, apertura: "ti lascio il quadro dei costi dei tuoi investimenti: quanto paghi, quanto pesa nel tempo e cosa ricevi in cambio.",
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
        case .posizione, .confronto, .valutazione, .portafoglio, .riesame, .fascicolo:
            return nil
        }
    }

    /// Fa scrivere a Eve il commento del report aperto (il consulente poi lo rilegge e lo modifica).
    func scriviCommentoConEve(_ scelta: SceltaProspetto) {
        guard !eveInCorso, let bozza = bozzaCommento(scelta) else { return }
        let id = clienteAttivoId
        if rispostePreparate {
            salvaCommento(scelta, testo: bozza, bozzaDi: MotoriEve.sintesi.nome)
            return
        }
        guard let modello = generativo else {
            verificaMotoreLocale()
            mostraAvviso((disponibilitaLocale.motivo ?? "Qwen non risponde.") + " Il commento lo scrive Eve con Qwen: quando è pronto, riprova.")
            return
        }
        eveInCorso = true
        Task { @MainActor in
            let r = await CommentoEve.scrivi(bozza: bozza, modello: modello)
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
    @discardableResult
    func chiediEve(_ domanda: String, spunto: SpuntoEve? = nil, breve: Bool = false) -> Bool {
        let testo = domanda.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testo.isEmpty, !eveInCorso else { return false }
        // La domanda parte da tastiera o da uno spunto: la dettatura del Mac si spegne (anche per i comandi)
        if dettaturaAttiva { chiudiDettatura() }
        if spunto == nil, eseguiComandoEve(testo) { return true }
        let id = clienteAttivoId
        guard let fonte = fonteEve(id) else { return false }
        let storia = conversazione(id)
        aggiungiMessaggio(MessaggioEve(autore: .utente, testo: testo), cliente: id)
        domandaEve = ""
        let richiesta = RichiestaEve(domanda: testo, spunto: spunto ?? SpuntoEve.da(testo), fonte: fonte, storia: storia)
        if rispostePreparate {
            let r = MotoriEve.sintesi.componi(richiesta)
            aggiungiMessaggio(MessaggioEve(autore: .eve, testo: r.testo, titolo: r.titolo, motore: MotoriEve.sintesi.nome, proposte: r.proposte), cliente: id)
            return true
        }
        // Le azioni proposte restano quelle calcolate da Prisma, anche quando il testo lo scrive Qwen
        let proposte = richiesta.spunto == .proposte ? MotoriEve.sintesi.componi(richiesta).proposte : nil
        var ambiente = ambienteEve(cliente: id)
        ambiente.breve = breve
        let piano = NucleoEve.piano(richiesta, impostazioni: dati.impostazioni.eve, ambiente: ambiente)
        conQwen(cliente: id) { _ in
            // La risposta arriva a pezzi e si vede mentre Eve la scrive (FlussoEve, bolla in arrivo)
            let motore = self.qwen
            self.eveInCorso = true
            let generazione = self.flussoEve.inizia(piano.scelta, motore: motore.nome)
            self.compitoEve = Task { @MainActor in
                do {
                    // I pezzi arrivano fuori dal thread principale: la bolla si aggiorna sul principale
                    let r = try await motore.scrivi(piano) { p in
                        DispatchQueue.main.async { self.flussoEve.aggiorna(p, generazione: generazione) }
                    }
                    var m = MessaggioEve(autore: .eve, testo: r.testo, motore: motore.nome, proposte: proposte)
                    m.modalita = piano.scelta.modalita
                    self.aggiungiMessaggio(m, cliente: id)
                } catch is CancellationError {
                    // Nuova conversazione: la risposta interrotta non resta
                } catch {
                    self.aggiungiMessaggio(MessaggioEve(autore: .eve, testo: error.localizedDescription,
                                                        titolo: "Eve non ha potuto rispondere", motore: motore.nome, proposte: proposte), cliente: id)
                }
                self.flussoEve.chiudi()
                self.eveInCorso = false
                self.compitoEve = nil
            }
        }
        return true
    }

    // MARK: - Confronto tra modelli

    /// Le stesse domande di prova ai modelli scelti in Impostazioni › Eve, sui dati di prova: il rapporto
    /// (una pagina con le risposte e i tempi affiancati) si apre a confronto finito.
    func confrontaModelli() {
        #if os(macOS)
        guard avanzamentoConfronto == nil else { return }
        let modelli = ConfrontoModelli.elenco(dati.impostazioni.eve.modelliConfronto)
        guard !modelli.isEmpty else { return mostraAvviso("Scrivi i modelli da confrontare, separati da virgole.") }
        // I dati di prova di Prisma, mai quelli dei clienti veri
        guard let fonte = StatoShell(persistente: false).fonteEve(ConfrontoModelli.clienteProva) else { return }
        let eve = dati.impostazioni.eve
        avanzamentoConfronto = "Preparo il confronto…"
        Task { @MainActor in
            let r = await ConfrontoModelli.esegui(modelli: modelli, eve: eve, fonte: fonte) { passo in
                Task { @MainActor in self.avanzamentoConfronto = passo }
            }
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("Confronto modelli di Eve.html")
            do {
                try ConfrontoModelli.html(r).write(to: file, atomically: true, encoding: .utf8)
                self.rapportoConfronto = file
                NSWorkspace.shared.open(file)
            } catch {
                self.mostraAvviso("Il rapporto del confronto non si è potuto salvare: \(error.localizedDescription)")
            }
            self.avanzamentoConfronto = nil
        }
        #else
        mostraAvviso(StatoShell.soloSulMacPerOra)
        #endif
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
        // Le occasioni, se lo strato è acceso: un passaggio solo, dalla memoria (AgendaOccasioni.swift)
        if dati.impostazioni.occasioni.inAgenda {
            for o in occasioni(da: inizio, a: fine) where filtro == nil || o.clienteId == filtro {
                indice.occasioniPerGiorno[cal.startOfDay(for: o.data), default: []].append(o)
            }
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
        occasioneSelezionata = nil
        // L'elenco delle occasioni non mostra gli appuntamenti: si torna alla settimana
        if vistaAgenda == .occasioni { vistaAgenda = .settimana }
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

    /// La bozza dell'incontro di riesame: un'ora nel primo spazio libero degli orari di lavoro (da domani),
    /// con canale e ordine del giorno nelle note. Si completa nel modulo dell'agenda.
    func bozzaRiesame(_ clienteId: String, oggi: Date = Date()) -> Appuntamento? {
        pianificaRiesame(clienteId, oggi: oggi)?.appuntamento
    }

    func salvaAppuntamento(_ a: Appuntamento) {
        var x = a
        x.titolo = x.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        x.luogo = x.luogo.trimmingCharacters(in: .whitespacesAndNewlines)
        // Lo stato di prima: «Incontro concluso» acceso nel modulo chiede l'esito della proposta
        let prima = dati.appuntamenti.first { $0.id == x.id }?.stato
        if let i = dati.appuntamenti.firstIndex(where: { $0.id == x.id }) {
            dati.appuntamenti[i] = x
        } else {
            dati.appuntamenti.append(x)
        }
        if prima == .pianificato && x.stato == .concluso { segnaConclusione(x.id) }
        giornoAgenda = Calendar.current.startOfDay(for: x.inizio)
        appuntamentoSelezionato = x.id
        occasioneSelezionata = nil
        // L'appuntamento salvato (anche quello preparato da un'occasione) si vede nella sua settimana
        if vistaAgenda == .occasioni { vistaAgenda = .settimana }
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
        // Seguito delle proposte: la proposta presentata e l'eventuale ripresa completata
        if dati.appuntamenti[i].stato == .concluso { segnaConclusione(id) }
        // Riesame con memoria: un riesame già avvenuto, segnato concluso, salva la fotografia
        let a = dati.appuntamenti[i]
        if a.stato == .concluso, a.tipo == .revisione, a.inizio <= Date() { fotografaRiesame(a.clienteId, origine: .appuntamento) }
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
        avviaTimerNotifiche()
    }

    /// Gli appuntamenti finiscono e i giorni cambiano anche senza toccare i dati: un ricalcolo al minuto,
    /// con la tolleranza che lascia a macOS raggruppare i risvegli.
    private func avviaTimerNotifiche() {
        timerNotifiche?.invalidate()
        let timer = Timer(timeInterval: StatoShell.intervalloNotifiche, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.ricalcolaNotifiche() }
        }
        timer.tolerance = StatoShell.tolleranzaNotifiche
        RunLoop.main.add(timer, forMode: .default)
        timerNotifiche = timer
    }

    func ricalcolaNotifiche() {
        let nuove = MotoreNotifiche.calcola(self)
        if nuove != notifiche { notifiche = nuove }
    }

    /// Promemoria del Mac (vedi PromemoriaMac.swift): solo dentro Prisma.app con l'archivio sul disco.
    /// All'avvio legge il permesso senza chiederlo; poi ricalcola dopo le modifiche, al cambio di giorno
    /// e tornando a Prisma.
    private func avviaPromemoria() {
        guard persistente, PromemoriaMac.disponibili else { return }
        PromemoriaMac.condiviso.collega(self)
        if dati.impostazioni.promemoria.attivi {
            aggiornaPromemoria()
        } else {
            // Spenti: niente promemoria rimasti da una sessione di prima
            PromemoriaMac.condiviso.spegni()
        }
        aggiornaPermessoPromemoria()
        $dati
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.aggiornaPromemoria() }
            .store(in: &abbonamenti)
        // Dopo lo stop del Mac li ricalcola la ripresa dei lavori (RipresaSistema.swift)
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !self.lavoriInPausa else { return }
                self.aggiornaPromemoria()
            }
            .store(in: &abbonamenti)
        // Tornando a Prisma (⌘Tab) al massimo una volta ogni mezzo minuto; il calcolo è in background
        #if os(macOS)
        let tornaAttiva = NSApplication.didBecomeActiveNotification
        #elseif os(iOS)
        let tornaAttiva = UIApplication.didBecomeActiveNotification
        #endif
        NotificationCenter.default.publisher(for: tornaAttiva)
            .receive(on: DispatchQueue.main)
            .throttle(for: .seconds(StatoShell.intervalloRitornoAttivo), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self, !self.lavoriInPausa else { return }
                self.aggiornaPermessoPromemoria()
                self.aggiornaPromemoria()
            }
            .store(in: &abbonamenti)
    }

    // MARK: - Salvataggio

    /// Salva l'archivio 0,8 s dopo l'ultima modifica, in background (codifica e scrittura non fermano le
    /// animazioni), e alla chiusura dell'app. Dati non cambiati dall'ultimo salvataggio non si riscrivono.
    private func avviaSalvataggio() {
        $dati
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.scrivi() }
            .store(in: &abbonamenti)
        #if os(macOS)
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                // La finestra sparisce subito; poi si finisce di salvare (niente, se i dati non sono cambiati)
                NSApplication.shared.windows.forEach { $0.orderOut(nil) }
                self?.salvaOra()
            }
            .store(in: &abbonamenti)
        #elseif os(iOS)
        // Su iPhone e iPad la chiusura non si annuncia: si salva quando Prisma va in background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.salvaOra() }
            .store(in: &abbonamenti)
        #endif
    }

    /// Salva adesso e aspetta: quando torna, l'archivio sul disco è aggiornato. Lo usano backup,
    /// ripristino, riapertura e chiusura.
    func salvaOra() {
        guard persistente, !salvataggioSospeso else { return }
        scrivi()
        salvataggio.attendi()
    }

    /// Accoda il salvataggio dei dati di adesso (niente, se questa generazione è già sul disco o in coda).
    private func scrivi() {
        guard persistente, !salvataggioSospeso else { return }
        // DatiPrisma è un valore: la copia va alla coda senza rischi, e la coda non legge mai `self.dati`
        salvataggio.accoda(dati, generazione: versioneDati) { [weak self] errore in
            self?.mostraAvviso("Salvataggio non riuscito: \(errore.localizedDescription)")
        }
    }

    // MARK: - Lavori a tempo e stop del Mac

    /// Il primo controllo del backup automatico dopo l'avvio (lontano dalla pulizia dei documenti).
    static let primoControlloBackup: Double = 45
    /// La pulizia dei documenti non più usati, dopo l'avvio.
    static let attesaPulizia: Double = 5
    /// Il backup automatico si controlla circa una volta l'ora, quando il Mac è libero.
    static let intervalloBackup: Double = 3600
    static let tolleranzaBackup: Double = 900
    /// Notifiche ricalcolate una volta al minuto.
    static let intervalloNotifiche: Double = 60
    static let tolleranzaNotifiche: Double = 10
    /// Tornando a Prisma i promemoria si ricalcolano al massimo ogni 30 s.
    static let intervalloRitornoAttivo = 30
    /// Dopo il risveglio del Mac i controlli aspettano un minuto: il risveglio resta libero.
    static let attesaDopoRisveglio: Double = 60

    /// Prima dello stop del Mac (o con lo schermo spento): timer fermi, controlli rimandati, dati cambiati
    /// accodati per il disco.
    func sospendiLavoriATempo() {
        ripresaLavori?.cancel()
        ripresaLavori = nil
        scrivi()
        guard !lavoriInPausa else { return }
        lavoriInPausa = true
        timerNotifiche?.invalidate()
        timerNotifiche = nil
    }

    /// Dopo il risveglio: tra `attesa` secondi ripartono notifiche, promemoria e controllo del backup.
    func riprendiLavoriATempo(dopo attesa: Double) {
        guard lavoriInPausa else { return }
        ripresaLavori?.cancel()
        let lavoro = DispatchWorkItem { [weak self] in
            guard let self, self.lavoriInPausa else { return }
            self.ripresaLavori = nil
            self.lavoriInPausa = false
            self.avviaTimerNotifiche()
            self.ricalcolaNotifiche()
            self.aggiornaPromemoria()
            self.controllaBackupAutomatico()
        }
        ripresaLavori = lavoro
        DispatchQueue.main.asyncAfter(deadline: .now() + attesa, execute: lavoro)
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

    // MARK: - Password dei backup

    /// La password con cui proteggere i backup (nil = backup non protetti). Con la protezione
    /// attiva e la password non disponibile lancia `.passwordNonDisponibile`: niente backup in chiaro.
    /// - riprova: false per i backup automatici (il Portachiavi non si richiede a ogni controllo).
    func passwordPerBackup(riprova: Bool = true) throws -> String? {
        guard dati.impostazioni.backup.cifrato else { return nil }
        guard let password = passwordBackupNota(riprova: riprova) else { throw ErroreBackup.passwordNonDisponibile }
        return password
    }

    /// La password dei backup se è nota: in memoria, altrimenti dal Portachiavi (mai nelle prove
    /// e nelle istantanee).
    private func passwordBackupNota(riprova: Bool) -> String? {
        if let password = passwordBackupInMemoria { return password }
        guard persistente, riprova || !portachiaviLetto else { return nil }
        portachiaviLetto = true
        passwordBackupInMemoria = PortachiaviBackup.leggi()
        return passwordBackupInMemoria
    }

    /// Imposta o cambia la password dei backup: vale dai prossimi backup.
    /// false se è troppo corta o se il Portachiavi non l'ha salvata.
    @discardableResult
    func impostaPasswordBackup(_ password: String) -> Bool {
        guard password.count >= ImpostazioniBackup.lunghezzaMinimaPassword else { return false }
        if persistente, !PortachiaviBackup.salva(password) { return false }
        let cambio = dati.impostazioni.backup.cifrato
        passwordBackupInMemoria = password
        portachiaviLetto = true
        dati.impostazioni.backup.protetto = true
        if dati.impostazioni.backup.ultimoErrore == ErroreBackup.passwordNonDisponibile.localizedDescription {
            dati.impostazioni.backup.ultimoErrore = nil
        }
        mostraAvviso(cambio ? "Password dei backup cambiata: vale dai prossimi backup."
                            : "Backup protetti: da ora si aprono solo con la password.")
        return true
    }

    /// Toglie la protezione: i prossimi backup sono .zip in chiaro; quelli protetti restano protetti.
    func togliPasswordBackup() {
        if persistente { PortachiaviBackup.elimina() }
        passwordBackupInMemoria = nil
        dati.impostazioni.backup.protetto = false
        if dati.impostazioni.backup.ultimoErrore == ErroreBackup.passwordNonDisponibile.localizedDescription {
            dati.impostazioni.backup.ultimoErrore = nil
        }
        mostraAvviso("Password tolta: i prossimi backup non sono protetti. Quelli già protetti si aprono con la loro password.")
    }

    /// Apre Impostazioni › Archivio con la richiesta della password dei backup.
    private func chiediPasswordBackupInImpostazioni() {
        schedaImpostazioni = .archivio
        apri(.impostazioni)
        // Dopo l'apertura della finestra, perché la richiesta abbia dove comparire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.chiediPasswordBackup = true }
    }

    /// Un'operazione che prima salva un backup di sicurezza si ferma se il backup protetto non si può fare.
    private func annullaSenzaPassword(_ errore: Error, _ operazione: String) {
        mostraAvviso("\(operazione): \(errore.localizedDescription)")
        chiediPasswordBackupInImpostazioni()
    }

    /// Chiede la password di un backup protetto da ripristinare (dopo che la conferma si è chiusa).
    private func chiediPasswordRipristino(_ url: URL, messaggio: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.ripristinoDaSbloccare = RichiestaPasswordBackup(url: url, messaggio: messaggio)
        }
    }

    /// Crea un backup completo della cartella dell'archivio.
    func creaBackup(automatico: Bool = false) {
        guard persistente, !backupInCorso else { return }
        // Con la protezione attiva il backup si fa solo con la password, mai in chiaro
        let password: String?
        do {
            password = try passwordPerBackup(riprova: !automatico)
        } catch {
            let giaSegnalato = dati.impostazioni.backup.ultimoErrore == error.localizedDescription
            dati.impostazioni.backup.ultimoTentativo = Date()
            dati.impostazioni.backup.ultimoErrore = error.localizedDescription
            if !automatico || !giaSegnalato { mostraAvviso("Backup non fatto: \(error.localizedDescription)") }
            if !automatico { chiediPasswordBackupInImpostazioni() }
            return
        }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        dati.impostazioni.backup.ultimoTentativo = Date()
        DispatchQueue.global(qos: .utility).async {
            do {
                let url = try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione,
                                                 nota: automatico ? GestoreBackup.notaAutomatico : nil, creaCartella: creaCartella,
                                                 password: password)
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
    /// Un backup protetto si apre con `password scritta` (dalla richiesta) o con la password dei
    /// backup; se nessuna lo apre si chiede la password.
    func ripristina(_ zip: URL, password scritta: String? = nil) {
        guard persistente, !backupInCorso else { return }
        guard !ripristinoBloccato else { mostraAvviso("Archivio in sola lettura: apri l'ultima versione di Prisma per ripristinare."); return }
        // Riconosciuto dal contenuto: anche un backup protetto rinominato
        let protetto = CifraturaBackup.cifrato(zip)
        let daPortachiavi = protetto && scritta == nil
        let chiave: String? = protetto ? (scritta ?? passwordBackupNota(riprova: true)) : nil
        if protetto, chiave == nil {
            chiediPasswordRipristino(zip, messaggio: "«\(zip.lastPathComponent)» è protetto: scrivi la password con cui è stato fatto.")
            return
        }
        // La copia di sicurezza di prima del ripristino segue la protezione di oggi
        let perSicurezza: String?
        do {
            perSicurezza = try passwordPerBackup()
        } catch {
            annullaSenzaPassword(error, "Ripristino annullato")
            return
        }
        salvaOra()
        salvataggioSospeso = true
        // Nessuna scrittura in coda deve arrivare sopra la cartella ripristinata
        salvataggio.attendi()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        // Le impostazioni di backup e il nome restano quelli di oggi, non quelli del backup
        let backupDiOggi = dati.impostazioni.backup
        let nome = (dati.impostazioni.nomeUtente, dati.impostazioni.inizialiUtente)
        DispatchQueue.global(qos: .userInitiated).async {
            var estratta: URL?
            do {
                let estratto = try GestoreBackup.estrai(zip, password: chiave)
                estratta = estratto.cartella
                try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima del ripristino",
                                       creaCartella: creaCartella, proteggi: zip, password: perSicurezza)
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
                    if (error as? ErroreBackup)?.passwordSbagliata == true {
                        self.chiediPasswordRipristino(zip, messaggio: daPortachiavi
                            ? "La password dei backup salvata su questo Mac non apre «\(zip.lastPathComponent)»: forse è stato fatto con una password di prima. Scrivila qui."
                            : "La password non è corretta: riprova.")
                    } else {
                        self.mostraAvviso("Ripristino non riuscito: \(error.localizedDescription)")
                    }
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
    /// I 5 clienti del template e i 30 clienti fittizi: si tolgono insieme.
    static let clientiDiProva: Set<String> = Set(DatiDemo.clienti().map(\.id)).union(ClientiFittizi.ids)
    var haDatiDiProva: Bool { dati.clienti.contains { Self.clientiDiProva.contains($0.id) } }

    /// Toglie i 5 clienti di prova con tutti i loro dati (e le schede prodotto di esempio non usate),
    /// lasciando i clienti veri. Prima salva un backup.
    func togliDatiDiProva() {
        guard persistente, !backupInCorso, !solaLettura else { return }
        let password: String?
        do {
            password = try passwordPerBackup()
        } catch {
            annullaSenzaPassword(error, "Operazione annullata")
            return
        }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima di togliere i dati di prova",
                                                        creaCartella: creaCartella, password: password) }
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
        let password: String?
        do {
            password = try passwordPerBackup()
        } catch {
            annullaSenzaPassword(error, "Operazione annullata")
            return
        }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima dell'importazione dei clienti",
                                                        creaCartella: creaCartella, password: password) }
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

    /// Importa in Posizioni quelle scelte (da CSV, Excel o righe incollate), con i clienti nuovi da creare
    /// in rubrica (chiave: il segnaposto in `clienteId`). Prima salva un backup dello stato attuale.
    func importaPosizioni(_ elenco: [Posizione], nuoviClienti: [String: ClienteImportato] = [:]) {
        guard !elenco.isEmpty, !solaLettura else { return }
        guard persistente else {
            aggiungiPosizioniImportate(elenco, nuoviClienti: nuoviClienti)
            return
        }
        guard !backupInCorso else { return }
        let password: String?
        do {
            password = try passwordPerBackup()
        } catch {
            annullaSenzaPassword(error, "Operazione annullata")
            return
        }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima dell'importazione delle posizioni",
                                                        creaCartella: creaCartella, password: password) }
            DispatchQueue.main.async {
                self.backupInCorso = false
                switch esito {
                case .success:
                    let creati = self.aggiungiPosizioniImportate(elenco, nuoviClienti: nuoviClienti)
                    self.aggiornaElencoBackup()
                    let clienti = Set(elenco.map(\.clienteId)).count
                    let nuovi = creati == 0 ? "" : creati == 1 ? " Un cliente nuovo aggiunto in rubrica." : " \(creati) clienti nuovi aggiunti in rubrica."
                    self.mostraAvviso("\(elenco.count) \(elenco.count == 1 ? "posizione importata" : "posizioni importate") per \(clienti) \(clienti == 1 ? "cliente" : "clienti")."
                                      + nuovi + " Lo stato precedente è salvato in un backup.")
                case .failure(let e):
                    self.mostraAvviso("Importazione annullata, backup non riuscito: \(e.localizedDescription)")
                }
            }
        }
    }

    /// La parte senza backup (usata anche dalle prove): crea i clienti nuovi e dà alle loro posizioni il loro id.
    /// Restituisce quanti clienti ha creato.
    @discardableResult
    func aggiungiPosizioniImportate(_ elenco: [Posizione], nuoviClienti: [String: ClienteImportato]) -> Int {
        var ids: [String: String] = [:]
        for (chiave, nuovo) in nuoviClienti.sorted(by: { $0.value.nome < $1.value.nome })
        where elenco.contains(where: { $0.clienteId == chiave }) {
            let c = nuovo.cliente(tinta: prossimaTinta)
            dati.clienti.append(c)
            ids[chiave] = c.id
        }
        dati.posizioni.append(contentsOf: elenco.compactMap { p in
            guard p.clienteId.hasPrefix("nuovo:") else { return p }
            guard let id = ids[p.clienteId] else { return nil }
            var q = p
            q.clienteId = id
            return q
        })
        return ids.count
    }

    /// Esegue `operazione` dopo un backup di sicurezza (come l'importazione); senza archivio la esegue subito.
    /// Restituisce false se non è partita (backup in corso, password mancante).
    @discardableResult
    func dopoUnBackup(nota: String, annullata: String, _ operazione: @escaping (_ conBackup: Bool) -> Void) -> Bool {
        guard persistente else {
            operazione(false)
            return true
        }
        guard !backupInCorso else { return false }
        let password: String?
        do {
            password = try passwordPerBackup()
        } catch {
            annullaSenzaPassword(error, annullata)
            return false
        }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: nota,
                                                        creaCartella: creaCartella, password: password) }
            DispatchQueue.main.async {
                self.backupInCorso = false
                switch esito {
                case .success:
                    operazione(true)
                    self.aggiornaElencoBackup()
                case .failure(let e):
                    self.mostraAvviso(TestiAggiornaValori.annullato(e.localizedDescription))
                }
            }
        }
        return true
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

    /// Torna ai dati di prova (con backup di sicurezza dello stato attuale): i 5 clienti del template,
    /// oppure con `completi` anche i 30 clienti fittizi.
    func ripristinaDatiDiProva(completi: Bool = false) {
        guard persistente, !backupInCorso, !solaLettura else { return }
        let password: String?
        do {
            password = try passwordPerBackup()
        } catch {
            annullaSenzaPassword(error, "Operazione annullata")
            return
        }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        let creaCartella = cartellaBackupPredefinita
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima dei dati di prova",
                                                        creaCartella: creaCartella, password: password) }
            DispatchQueue.main.async {
                self.backupInCorso = false
                switch esito {
                case .success:
                    var demo = completi ? ClientiFittizi.completi() : DatiPrisma.demo()
                    demo.impostazioni = self.dati.impostazioni
                    self.dati = demo
                    self.azzeraNote()
                    // I file dei clienti veri restano nel backup appena fatto, non nell'archivio
                    self.pulisciDocumentiOrfani()
                    self.aggiornaElencoBackup()
                    self.mostraAvviso((completi ? "\(demo.clienti.count) clienti di prova caricati." : "Dati di prova ripristinati.")
                                      + " Lo stato precedente è salvato in un backup.")
                case .failure(let e):
                    self.mostraAvviso("Operazione annullata, backup non riuscito: \(e.localizedDescription)")
                }
            }
        }
    }

    #if os(macOS)
    /// Backup automatico settimanale: un controllo poco dopo l'avvio, poi circa ogni ora quando il Mac è
    /// libero (lo decide macOS, che raggruppa i lavori e non li fa cadere tutti sul risveglio).
    private func avviaBackupAutomatico() {
        DispatchQueue.main.asyncAfter(deadline: .now() + StatoShell.primoControlloBackup) { [weak self] in
            guard let self, !self.lavoriInPausa else { return }
            self.controllaBackupAutomatico()
        }
        let attivita = NSBackgroundActivityScheduler(identifier: "local.prisma.backup-automatico")
        attivita.repeats = true
        attivita.interval = StatoShell.intervalloBackup
        attivita.tolerance = StatoShell.tolleranzaBackup
        attivita.qualityOfService = .utility
        attivita.schedule { [weak self] fatto in
            DispatchQueue.main.async {
                guard let self else {
                    fatto(.finished)
                    return
                }
                // Durante lo stop del Mac si rimanda: lo rifà la ripresa dei lavori
                guard !self.lavoriInPausa else {
                    fatto(.deferred)
                    return
                }
                self.controllaBackupAutomatico()
                fatto(.finished)
            }
        }
        attivitaBackup = attivita
    }
    #endif

    private func controllaBackupAutomatico() {
        #if os(macOS)
        let b = dati.impostazioni.backup
        // Con un archivio non leggibile da sistemare i backup automatici non sostituiscono quelli buoni
        // (il conto si aggiorna all'avvio, dopo un ripristino e quando il consulente le segna come gestite)
        guard persistente, b.automatico, !solaLettura, copieNonLeggibili == 0, !backupInCorso,
              let prossimo = b.prossimo, prossimo <= Date() else { return }
        // Backup protetti: il Portachiavi si legge (una volta per sessione) fuori dal thread principale
        if b.cifrato, passwordBackupInMemoria == nil, !portachiaviLetto {
            portachiaviLetto = true
            DispatchQueue.global(qos: .utility).async {
                let password = PortachiaviBackup.leggi()
                DispatchQueue.main.async {
                    if self.passwordBackupInMemoria == nil { self.passwordBackupInMemoria = password }
                    self.creaBackup(automatico: true)
                }
            }
            return
        }
        creaBackup(automatico: true)
        #elseif os(iOS)
        // Su iPhone e iPad niente backup automatico (anche se le impostazioni arrivate dal Mac lo chiedono):
        // la fonte dei dati è il Mac
        #endif
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
        #if os(macOS)
        (NSApp.keyWindow ?? NSApp.windows.first)?.toggleFullScreen(nil)
        #elseif os(iOS)
        // Su iPhone e iPad Prisma è già a tutto schermo
        #endif
    }
}

enum SchedaImpostazioni: Hashable {
    case esperienza, proposte, archivio, scorciatoie
    /// Metri di confronto dei rendimenti (dalla versione 24 dell'archivio).
    case riferimenti
}

enum SchedaCliente: String, CaseIterable, Hashable {
    case panoramica, bisogni, anagrafica, famiglia, profilo, inRegola, note
    /// Cronologia delle fotografie dei riesami (dalla versione 24 dell'archivio).
    case riesami

    var titolo: String {
        switch self {
        case .panoramica: return "Panoramica"
        case .bisogni: return "Bisogni"
        case .anagrafica: return "Anagrafica"
        case .famiglia: return "Famiglia"
        case .profilo: return "Profilo"
        case .inRegola: return "In regola"
        case .note: return "Note"
        case .riesami: return "Riesami"
        }
    }
}
