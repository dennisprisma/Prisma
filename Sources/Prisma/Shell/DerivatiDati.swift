import Foundation

// Proprietario: G3 (calcoli nei body).

/// Dati ricavati dall'archivio e tenuti da parte finché non cambiano i dati dei calcoli (`versioneCalcoli`: una
/// nota, Eve, l'aspetto o il cliente attivo non contano), il giorno o la modalità cliente: una classe, così si
/// aggiorna dai getter senza pubblicare StatoShell. Ogni voce si calcola alla prima richiesta dopo un
/// cambiamento, non tutte insieme. Si usa solo dal thread principale.
final class DerivatiDati {
    /// Ciò da cui dipende tutto il resto: con una chiave nuova si riparte da zero.
    struct Chiave: Equatable {
        let versione: Int
        let giorno: Date
        let modo: String?
    }

    /// Il riesame dipende anche dal confronto aperto in Prospetti e dall'orizzonte della sostituzione (fonte di Eve).
    struct ChiaveRiesame: Equatable {
        let prospetto: SceltaProspetto?
        let orizzonte: Int?
        let ora: Int
    }

    struct ChiavePortafoglio: Equatable {
        let canale: Canale?
        let area: AreaPosizione?
        let ora: Int
    }

    /// Tutto ciò che cambia un documento di Prospetti oltre ai dati dei calcoli, al giorno e alla modalità cliente.
    struct ChiaveDocumento: Equatable {
        let scelta: SceltaProspetto
        /// Le note del taccuino (`versioneNote`): le legge il fascicolo dell'incontro.
        let note: Int
        let prospetto: SceltaProspetto?
        let cliente: String
        let orizzonteConfronto: Int?
        let orizzonteSostituzione: Int?
        let fascicolo: Set<TipoProspetto>
        let appuntamento: String?
        let ora: Int
    }

    /// Le parti del Portafoglio che non dipendono dai filtri di canale e area.
    struct PortafoglioComune {
        let daRicontattare: [Portafoglio.DaRicontattare]
        let dovuti: [RiesameDovuto]
        let fine: [FineAnno]
        let attenzioni: [Attenzione]
    }

    /// L'ora corrente come numero intero: i calcoli che guardano «adesso» (prossimo appuntamento, riesami
    /// dovuti) si rifanno almeno una volta all'ora anche se i dati non cambiano.
    static func ora(_ data: Date = Date()) -> Int { Int(data.timeIntervalSinceReferenceDate / 3600) }

    // Le voci si leggono e si scrivono solo dalle estensioni di StatoShell (G3)
    var chiave: Chiave?
    var clientiPerId: [String: Cliente]?
    var posizioniPerCliente: [String: [Posizione]]?
    var prossimi: [Appuntamento]?
    var diOggi: [Appuntamento]?
    var aperte: [Attivita]?
    var riepilogoTutte: RiepilogoPosizioni?
    var riepiloghiCliente: [String: RiepilogoPosizioni] = [:]
    var dossier: [String: AnalisiDossier] = [:]
    var coerenze: [String: EsitoCoerenza] = [:]
    var fisco: [String: FiscoPolizzeCliente] = [:]
    var chiaveRiesami: ChiaveRiesame?
    var riesami: [String: Riesame?] = [:]
    var portafoglioComune: (ora: Int, valore: PortafoglioComune)?
    var portafoglio: (chiave: ChiavePortafoglio, valore: Portafoglio)?
    var documento: (chiave: ChiaveDocumento, valore: DocumentoStampabile?)?
    /// Completezza dei dati per l'analisi, per cliente (StatoCompletezza.swift).
    var completezze: [String: CompletezzaCliente] = [:]
    /// Le proposte ferme, con l'ora del calcolo (StatoSeguito.swift).
    var seguito: (ora: Int, valore: [PropostaInSospeso])?
    /// Le scadenze di conformità («In regola»), per cliente (StatoConformita.swift).
    var conformita: [String: EsitoConformita] = [:]
    /// Le occasioni per intervallo di date e filtro (AgendaOccasioni.swift).
    var occasioni: [ChiaveOccasioni: [Occasione]] = [:]
    /// Il numero dell'ultima impaginazione del documento di Prospetti: cambia solo quando il documento si
    /// impagina di nuovo, quindi dice alle pagine sul tavolo se sono ancora le stesse. Non si azzera con la
    /// chiave e viene da un contatore comune a tutti gli stati, così due documenti non hanno mai lo stesso numero.
    private(set) var generazioneDocumento = 0
    nonisolated(unsafe) private static var ultimaGenerazione = 0

    /// Un documento impaginato adesso: prende un numero nuovo.
    func nuovaGenerazioneDocumento() {
        DerivatiDati.ultimaGenerazione &+= 1
        generazioneDocumento = DerivatiDati.ultimaGenerazione
    }

    /// Dati dei calcoli, giorno o modalità cliente cambiati: si dimentica tutto (non il numero del documento).
    func azzera(_ nuova: Chiave) {
        chiave = nuova
        clientiPerId = nil
        posizioniPerCliente = nil
        prossimi = nil
        diOggi = nil
        aperte = nil
        riepilogoTutte = nil
        riepiloghiCliente = [:]
        dossier = [:]
        coerenze = [:]
        fisco = [:]
        chiaveRiesami = nil
        riesami = [:]
        portafoglioComune = nil
        portafoglio = nil
        documento = nil
        completezze = [:]
        seguito = nil
        conformita = [:]
        occasioni = [:]
    }
}

extension StatoShell {
    /// I dati ricavati validi per lo stato di adesso (azzerati se i dati dei calcoli, il giorno o la modalità
    /// cliente sono cambiati).
    func derivatiValidi() -> DerivatiDati {
        let k = DerivatiDati.Chiave(versione: versioneCalcoli, giorno: Calendar.current.startOfDay(for: Date()), modo: modoCliente)
        if derivati.chiave != k { derivati.azzera(k) }
        return derivati
    }

    /// Il cliente con questo id tra quelli visibili (in modalità cliente solo il suo): ricerca in un dizionario.
    func cliente(_ id: String) -> Cliente? {
        let d = derivatiValidi()
        if let mappa = d.clientiPerId { return mappa[id] }
        // Con due clienti con lo stesso id vale il primo, come con `first(where:)`
        let mappa = Dictionary(clienti.map { ($0.id, $0) }, uniquingKeysWith: { primo, _ in primo })
        d.clientiPerId = mappa
        return mappa[id]
    }

    /// Lo stesso di `cliente(_:)`, per chi cerca un cliente per id fuori dalle viste (notifiche).
    func clientePerId(_ id: String) -> Cliente? { cliente(id) }

    var prossimiAppuntamenti: [Appuntamento] {
        let d = derivatiValidi()
        if let elenco = d.prossimi { return elenco }
        let inizio = Calendar.current.startOfDay(for: Date())
        let elenco = appuntamenti
            .filter { $0.inizio >= inizio && $0.stato == .pianificato }
            .sorted { $0.inizio < $1.inizio }
        d.prossimi = elenco
        return elenco
    }

    var appuntamentiDiOggi: [Appuntamento] {
        let d = derivatiValidi()
        if let elenco = d.diOggi { return elenco }
        let elenco = appuntamenti.filter { Calendar.current.isDateInToday($0.inizio) && $0.stato == .pianificato }
        d.diOggi = elenco
        return elenco
    }

    var attivitaAperte: [Attivita] {
        let d = derivatiValidi()
        if let elenco = d.aperte { return elenco }
        let elenco = attivita.filter { !$0.completata }.sorted { $0.scadenza < $1.scadenza }
        d.aperte = elenco
        return elenco
    }

    /// Le posizioni di un cliente, dall'archivio intero (anche fuori dalla modalità cliente).
    func posizioniCliente(_ id: String) -> [Posizione] {
        let d = derivatiValidi()
        if let gruppi = d.posizioniPerCliente { return gruppi[id] ?? [] }
        let gruppi = Dictionary(grouping: dati.posizioni, by: \.clienteId)
        d.posizioniPerCliente = gruppi
        return gruppi[id] ?? []
    }

    /// Il quadro di tutte le posizioni visibili (widget Scadenze e Portafoglio clienti).
    var riepilogoTuttePosizioni: RiepilogoPosizioni {
        let d = derivatiValidi()
        if let r = d.riepilogoTutte { return r }
        let r = RiepilogoPosizioni(posizioni)
        d.riepilogoTutte = r
        return r
    }

    /// Il quadro delle posizioni di un cliente (widget del cliente in primo piano).
    func riepilogoPosizioniCliente(_ id: String) -> RiepilogoPosizioni {
        let d = derivatiValidi()
        if let r = d.riepiloghiCliente[id] { return r }
        let r = RiepilogoPosizioni(posizioniCliente(id))
        d.riepiloghiCliente[id] = r
        return r
    }

    /// La coerenza con il profilo delle posizioni del cliente (pannello del dossier e dettaglio delle proposte).
    func coerenzaCliente(_ c: Cliente) -> EsitoCoerenza {
        let d = derivatiValidi()
        if let e = d.coerenze[c.id] { return e }
        let e = MotoreCoerenza.calcola(cliente: c, posizioni: posizioniCliente(c.id), prodotti: dati.prodotti)
        d.coerenze[c.id] = e
        return e
    }

    /// Il fisco delle polizze di un cliente (Analisi 360): detrazioni, capitali al decesso, bollo, deducibilità.
    func fiscoPolizze(_ c: Cliente) -> FiscoPolizzeCliente {
        let d = derivatiValidi()
        if let f = d.fisco[c.id] { return f }
        let f = FiscoPolizze.riepilogo(cliente: c, posizioni: posizioniCliente(c.id))
        d.fisco[c.id] = f
        return f
    }

    /// Il riesame annuale di un cliente (nil se il cliente non c'è): passa da tutta la fonte di Eve,
    /// quindi si calcola una volta sola per dati, ora, confronto aperto e orizzonte della sostituzione.
    func riesameCliente(_ id: String) -> Riesame? {
        let d = derivatiValidi()
        let k = DerivatiDati.ChiaveRiesame(prospetto: prospetto, orizzonte: orizzonteSostituzione, ora: DerivatiDati.ora())
        if d.chiaveRiesami != k {
            d.chiaveRiesami = k
            d.riesami = [:]
        }
        if let memorizzato = d.riesami[id] { return memorizzato }
        let r = fonteEve(id).map { MotoreRiesame.calcola($0, conformita: conformitaCliente(id), occasioni: occasioniRiesame(id)) }
        d.riesami[id] = .some(r)
        return r
    }

    /// Ciò che il Portafoglio di Posizioni mostra di tutti i clienti, a prescindere dai filtri: chi ricontattare,
    /// i riesami dovuti, lo spazio deducibile di fine anno e le cose da sistemare nei dossier.
    func portafoglioComune() -> DerivatiDati.PortafoglioComune {
        let d = derivatiValidi()
        let ora = DerivatiDati.ora()
        if let c = d.portafoglioComune, c.ora == ora { return c.valore }
        let v = DerivatiDati.PortafoglioComune(
            daRicontattare: MotorePortafoglio.daRicontattare(posizioni, clienti: clienti, appuntamenti: appuntamenti, incontri: dati.incontri),
            dovuti: MotoreRiesame.dovuti(clienti: clienti, posizioni: posizioni, appuntamenti: appuntamenti, incontri: dati.incontri),
            fine: MotoreFineAnno.conSpazio(clienti: clienti, posizioni: posizioni),
            attenzioni: MotoreAttenzioni.calcola(clienti: clienti, posizioni: posizioni))
        d.portafoglioComune = (ora, v)
        return v
    }

    /// Il portafoglio di tutti i clienti con i filtri di canale e area (chi ricontattare non dipende dai filtri).
    func riepilogoPortafoglio(canale: Canale?, area: AreaPosizione?) -> Portafoglio {
        let d = derivatiValidi()
        let k = DerivatiDati.ChiavePortafoglio(canale: canale, area: area, ora: DerivatiDati.ora())
        if let c = d.portafoglio, c.chiave == k { return c.valore }
        let filtrate = posizioni.filter { (canale == nil || $0.canale == canale) && (area == nil || $0.area == area) }
        var p = MotorePortafoglio.calcola(filtrate, clienti: clienti, appuntamenti: appuntamenti, incontri: dati.incontri)
        p.daRicontattare = portafoglioComune().daRicontattare
        d.portafoglio = (k, p)
        return p
    }

    /// Il documento di Prospetti per una scelta, impaginato una volta sola finché non cambia qualcosa che conta
    /// (dati, note, cliente, orizzonti, fascicolo, giorno, ora): il body di Prospetti lo chiede a ogni disegno.
    func documentoProspettoInCache(_ scelta: SceltaProspetto) -> DocumentoStampabile? {
        let d = derivatiValidi()
        let k = DerivatiDati.ChiaveDocumento(scelta: scelta, note: versioneNote, prospetto: prospetto, cliente: clienteAttivoId,
                                             orizzonteConfronto: orizzonteConfronto, orizzonteSostituzione: orizzonteSostituzione,
                                             fascicolo: sceltaFascicolo, appuntamento: fascicoloAppuntamento, ora: DerivatiDati.ora())
        if let c = d.documento, c.chiave == k { return c.valore }
        let documento = documentoProspetto(scelta)
        d.documento = (k, documento)
        d.nuovaGenerazioneDocumento()
        return documento
    }

    /// Il numero dell'impaginazione del documento di Prospetti restituito per ultimo da
    /// `documentoProspettoInCache` (lo stesso finché il documento viene dalla cache).
    var generazioneDocumento: Int { derivati.generazioneDocumento }

    /// La chiave delle viste che mostrano dati ricavati, per le sottoviste `Equatable` che non osservano StatoShell.
    var chiaveVista: ChiaveVista {
        ChiaveVista(calcoli: versioneCalcoli, giorno: Calendar.current.startOfDay(for: Date()),
                    ora: DerivatiDati.ora(), modo: modoCliente)
    }
}

/// Ciò da cui dipendono le viste che mostrano dati ricavati: la chiave delle sottoviste `Equatable` che non
/// osservano StatoShell (versione dei calcoli, giorno, ora intera come `DerivatiDati.ora`, modalità cliente).
/// Con la stessa chiave le cache di DerivatiDati danno gli stessi valori, quindi la vista è la stessa.
struct ChiaveVista: Equatable {
    let calcoli: Int
    let giorno: Date
    let ora: Int
    let modo: String?
}

extension DatiPrisma {
    /// Uguali in tutto ciò che entra nei calcoli e nei documenti. Non contano le note del taccuino (hanno la loro
    /// versione), le conversazioni con Eve, gli spazi di lavoro, il cliente attivo (le cache sono per cliente) e
    /// le impostazioni che cambiano solo l'aspetto, Eve, il backup e i promemoria. Gli array e i dizionari non
    /// toccati condividono la memoria con quelli di prima e si confrontano in O(1).
    func stessiCalcoli(di altro: DatiPrisma) -> Bool {
        var a = self
        var b = altro
        a.note = []
        b.note = []
        a.conversazioni = [:]
        b.conversazioni = [:]
        a.spazi = []
        b.spazi = []
        b.clienteAttivoId = a.clienteAttivoId
        b.impostazioni.aspetto = a.impostazioni.aspetto
        b.impostazioni.sfondoAnimato = a.impostazioni.sfondoAnimato
        b.impostazioni.pioggia = a.impostazioni.pioggia
        b.impostazioni.guidaNascosta = a.impostazioni.guidaNascosta
        b.impostazioni.backup = a.impostazioni.backup
        b.impostazioni.promemoria = a.impostazioni.promemoria
        b.impostazioni.eve = a.impostazioni.eve
        // Le schede di adeguatezza e l'elenco dei documenti da consegnare non entrano in nessun calcolo in cache
        a.schedeAdeguatezza = []; b.schedeAdeguatezza = []
        b.impostazioni.consegna = a.impostazioni.consegna
        return a == b
    }
}
