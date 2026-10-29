import AppKit
import SwiftUI

/// Modalità istantanea (`Prisma --istantanee <cartella>`): disegna le schermate principali
/// in PNG senza aprire finestre e senza toccare l'archivio. La usa il workflow di build
/// per pubblicare le anteprime a ogni modifica.
@MainActor
enum Istantanee {
    static let dimensione = CGSize(width: 1440, height: 900)
    /// Schermo più basso (MacBook con il dock di macOS e la barra dei menu): le scene che finiscono
    /// con "-schermo-basso" si disegnano a questa misura.
    static let dimensioneBassa = CGSize(width: 1280, height: 760)

    static let scene: [(nome: String, prepara: (StatoShell) -> Void)] = [
        ("1-scrivania", { _ in }),
        ("2-posizioni", { $0.apri(.posizioni) }),
        ("3-impostazioni-archivio", { s in
            s.apri(.impostazioni)
            s.schedaImpostazioni = .archivio
        }),
        ("4-finestra-non-ingrandita", { s in
            s.apri(.prodotti)
            s.alternaIngrandimento(.prodotti)
        }),
        ("5-clienti-panoramica", { $0.apri(.clienti) }),
        ("6-clienti-famiglia", { s in
            s.clienteAttivoId = "marco"
            s.schedaCliente = .famiglia
            s.apri(.clienti)
        }),
        ("7-clienti-profilo", { s in
            s.clienteAttivoId = "sofia"
            s.schedaCliente = .profilo
            s.apri(.clienti)
        }),
        ("8-posizioni-dettaglio", { s in
            s.posizioneInDettaglio = "pos-giulia-etf-azionario-globale"
            s.apri(.posizioni)
        }),
        ("9-posizioni-marco", { s in
            s.clienteAttivoId = "marco"
            s.apri(.posizioni)
        }),
        ("10-posizioni-copertura", { s in
            s.clienteAttivoId = "marco"
            s.posizioneInDettaglio = "pos-marco-infortuni-famiglia"
            s.apri(.posizioni)
        }),
        ("11-agenda", { s in
            s.appuntamentoSelezionato = "event-marco"
            s.apri(.agenda)
        }),
        ("12-agenda-mese-scadenza", { s in
            if let d = s.posizioni.first(where: { $0.id == "pos-marco-infortuni-famiglia" })?.scadenza {
                s.giornoAgenda = Calendar.current.startOfDay(for: d)
            }
            s.vistaAgenda = .mese
            s.apri(.agenda)
        }),
        ("13-attivita", { s in
            s.attivitaSelezionata = "task-casa"
            s.apri(.attivita)
        }),
        ("14-simulazioni", { s in
            if let p = s.posizioni.first(where: { $0.id == "pos-giulia-etf-azionario-globale" }) { s.simula(p) }
        }),
        ("15-simulazioni-scenari", { s in
            s.schedaSimulazioni = .scenari
            s.apri(.simulazioni)
        }),
        ("16-confronti", { s in
            s.clienteAttivoId = "marco"
            s.apri(.confronti)
        }),
        ("17-analisi360", { $0.apri(.analisi360) }),
        ("20-clienti-bisogni", { s in
            s.clienteAttivoId = "marco"
            s.schedaCliente = .bisogni
            s.apri(.clienti)
        }),
        ("21-incontri-ascolto", { s in
            s.clienteAttivoId = "giulia"
            s.incontroAperto = "incontro-giulia-analisi"
            s.schedaIncontro = .ascolto
            s.apri(.incontri)
        }),
        ("22-incontri-passi", { s in
            s.clienteAttivoId = "giulia"
            if var i = s.incontro("incontro-giulia-analisi") {
                // Si riapre l'incontro di prova per mostrare le proposte ricavate dagli appunti
                i.stato = .preparazione
                s.salvaIncontro(i)
                s.estraiProposte(i)
            }
            s.incontroAperto = "incontro-giulia-analisi"
            s.schedaIncontro = .passi
            s.apri(.incontri)
        }),
        ("23-prodotti", { s in
            s.prodottoSelezionato = "prodotto-previdenza-pip"
            s.apri(.prodotti)
        }),
        ("24-obiettivi", { s in
            s.clienteAttivoId = "giulia"
            s.obiettivoSelezionato = "obiettivo-giulia-casa"
            s.apri(.obiettivi)
        }),
        ("27-prospetto-proposta", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.posizione("pos-giulia-piano-previdenziale-integrativo"))
        }),
        ("28-resoconto-prospetto", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.resoconto(report: false))
        }),
        ("33-resoconto-report", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.resoconto(report: true))
        }),
        ("29-prospetto-confronto", { s in
            s.clienteAttivoId = "marco"
            if let c = s.confrontoPredefinito() { s.apriProspetto(c) }
        }),
        ("32-prodotti-condizioni", { s in
            s.prodottoSelezionato = "prodotto-orizzonte-valore"
            s.apri(.prodotti)
        }),
        ("30-valutazione-prospetto", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.valutazione("val-marco-orizzonte", report: false))
        }),
        ("31-valutazione-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.valutazione("val-marco-orizzonte", report: true))
        }),
        ("34-sostituzione-prospetto", { s in
            s.clienteAttivoId = "sofia"
            s.apriProspetto(.sostituzione("", "", report: false))
        }),
        ("35-sostituzione-report", { s in
            s.clienteAttivoId = "sofia"
            s.apriProspetto(.sostituzione("", "", report: true))
        }),
        ("36-previdenza-prospetto", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.previdenza(report: false))
        }),
        ("37-previdenza-report", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.previdenza(report: true))
        }),
        ("38-protezione-prospetto", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.protezione(report: false))
        }),
        ("39-protezione-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.protezione(report: true))
        }),
        ("40-obiettivo-prospetto", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.obiettivo("obiettivo-giulia-casa", report: false))
        }),
        ("41-obiettivo-report", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.obiettivo("obiettivo-giulia-casa", report: true))
        }),
        ("42-liquidita-prospetto", { s in
            s.clienteAttivoId = "sofia"
            s.apriProspetto(.liquidita(report: false))
        }),
        ("43-liquidita-report", { s in
            s.clienteAttivoId = "sofia"
            s.apriProspetto(.liquidita(report: true))
        }),
        ("44-checkup-prospetto", { s in
            s.clienteAttivoId = "andrea"
            s.apriProspetto(.checkUp(report: false))
        }),
        ("45-checkup-report", { s in
            s.clienteAttivoId = "andrea"
            s.apriProspetto(.checkUp(report: true))
        }),
        ("25-documenti-kid", { s in
            s.clienteAttivoId = "giulia"
            s.documentoSelezionato = "doc-giulia-kid"
            s.apri(.documenti)
        }),
        ("71-posizioni-resistenza", { s in
            // Marco, profilo moderato: la prova di resistenza sotto la ripartizione
            s.clienteAttivoId = "marco"
            s.apri(.posizioni)
        }),
        ("72-eve-resistenza", { s in
            s.clienteAttivoId = "marco"
            s.rispostePreparate = true
            s.chiediEve(SpuntoEve.resistenza.domanda, spunto: .resistenza)
            s.apri(.eve)
        }),
        ("73-resistenza-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.resistenza(report: true))
        }),
        ("74-posizioni-costi", { s in
            // Giulia: il dossier scorre fino al pannello dei costi
            s.clienteAttivoId = "giulia"
            s.apri(.posizioni)
            s.ancoraPosizioni = "costi"
        }),
        ("75-costi-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.costi(report: true))
        }),
        ("76-posizioni-successione", { s in
            // Giulia: convivente senza tutele e polizza agli «eredi legittimi»
            s.clienteAttivoId = "giulia"
            s.apri(.posizioni)
            s.ancoraPosizioni = "successione"
        }),
        ("77-successione-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.successione(report: true))
        }),
        ("78-portafoglio-da-sistemare", { s in
            s.portafoglio = true
            s.apri(.posizioni)
            s.ancoraPosizioni = "attenzioni"
        }),
        ("79-posizioni-patrimonio", { s in
            // Marco: il patrimonio nel tempo, com'è oggi e con la proposta aperta
            s.clienteAttivoId = "marco"
            s.apri(.posizioni)
            s.ancoraPosizioni = "patrimonio"
        }),
        ("80-patrimonio-report", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.patrimonio(report: true))
        }),
        ("81-fascicolo", { s in
            s.clienteAttivoId = "marco"
            s.apriProspetto(.fascicolo)
        }),
        ("82-agenda-fascicolo", { s in
            // Dall'appuntamento di Marco: il fascicolo con i report adatti alla revisione
            if let a = s.appuntamenti.first(where: { $0.clienteId == "marco" && $0.stato == .pianificato }) { s.preparaFascicolo(per: a) }
        }),
        ("83-presentazione", { s in
            // Il patrimonio di Marco mostrato all'incontro: seconda pagina, a tutta finestra
            s.clienteAttivoId = "marco"
            if let d = s.documentoProspetto(.patrimonio(report: true)) {
                s.presenta(d)
                s.paginaSeguente()
            }
        }),
        ("84-eve-ascolta", { s in
            // Una conversazione a voce: Eve ha risposto e ora ascolta la frase successiva
            s.rispostePreparate = true
            s.clienteAttivoId = "marco"
            s.chiediEve(SpuntoEve.resistenza.domanda, spunto: .resistenza)
            s.conversazioneAVoce = true
            s.voceIstantanea = StatoVoce(ascolta: true, trascritto: "Va bene, e quanto pesano i costi del suo piano pensione", livello: 0.6)
            s.apri(.eve)
        }),
        ("86-eve-comandi", { s in
            // Eve fa le cose: un appuntamento, un promemoria e l'agenda di domani, dalla conversazione
            s.rispostePreparate = true
            s.clienteAttivoId = "marco"
            s.chiediEve("Fissa una telefonata con Marco domani alle 15")
            s.chiediEve("Ricordami di mandargli il KID del PIP venerdì")
            s.chiediEve("Cosa ho domani?")
            s.apri(.eve)
        }),
        ("87-clienti-fittizi", { s in
            // I 35 clienti di prova completi: rubrica piena e un cliente inventato aperto
            s.dati = ClientiFittizi.completi()
            s.clienteAttivoId = ClientiFittizi.prefisso + "ferraro"
            s.apri(.clienti)
        }),
        ("88-portafoglio-fittizi", { s in
            s.dati = ClientiFittizi.completi()
            s.portafoglio = true
            s.apri(.posizioni)
        }),
        ("85-impostazioni-voce", { s in
            s.schedaImpostazioni = .esperienza
            s.apri(.impostazioni)
        }),
        ("70-modo-cliente", { s in
            // Lo schermo girato verso Marco: solo il suo dossier, niente degli altri clienti
            s.clienteAttivoId = "marco"
            s.entraModoCliente()
            s.apri(.posizioni)
        }),
        ("69-riesame-prospetto", { s in
            s.clienteAttivoId = "giulia"
            s.apriProspetto(.riesame)
        }),
        ("68-documenti-estratto", { s in
            // Estratto conto confermato: il valore pronto per lo storico del piano di risparmio
            s.clienteAttivoId = "giulia"
            s.documentoSelezionato = "doc-giulia-estratto"
            if let d = s.documento("doc-giulia-estratto") { for c in d.campi { s.confermaCampo(d.id, c.chiave, true) } }
            s.apri(.documenti)
        }),
        ("26-documenti-polizza", { s in
            s.clienteAttivoId = "marco"
            s.documentoSelezionato = "doc-marco-polizza"
            s.apri(.documenti)
        }),
        ("19-eve", { s in
            s.rispostePreparate = true
            s.clienteAttivoId = "giulia"
            s.chiediEve(SpuntoEve.incontro.domanda, spunto: .incontro)
            s.apri(.eve)
        }),
        ("48-report-commento", { s in
            s.rispostePreparate = true
            s.clienteAttivoId = "giulia"
            s.prospetto = .checkUp(report: true)
            s.scriviCommentoConEve(.checkUp(report: true))
            s.apri(.presentazioni)
        }),
        ("50-eve-proposte", { s in
            s.rispostePreparate = true
            s.clienteAttivoId = "giulia"
            s.chiediEve(SpuntoEve.proposte.domanda, spunto: .proposte)
            s.apri(.eve)
        }),
        ("49-eve-documento", { s in
            s.rispostePreparate = true
            s.spiegaDocumentoConEve("doc-marco-polizza")
        }),
        ("46-eve-pensione", { s in
            s.rispostePreparate = true
            s.clienteAttivoId = "marco"
            s.prospetto = .previdenza(report: false)
            s.chiediEveDelDocumento(.previdenza(report: false))
        }),
        ("47-eve-checkup", { s in
            s.rispostePreparate = true
            s.clienteAttivoId = "giulia"
            s.chiediEve(SpuntoEve.checkUp.domanda, spunto: .checkUp)
            s.apri(.eve)
        }),
        ("53-ricerca", { s in
            s.testoRicerca = "marco"
            s.cercaOvunque()
        }),
        ("54-ricerca-documento", { s in
            // Il pannello ⌘K sopra un'app aperta (non sulla scrivania vuota)
            s.clienteAttivoId = "marco"
            s.apri(.clienti)
            s.testoRicerca = "scopo investimento"
            s.cercaOvunque()
        }),
        ("55-spazio-incontro", { s in
            s.area = ShellView.area(per: dimensione, dockNascosto: false)
            s.clienteAttivoId = "marco"
            s.apriSpazio(SpazioLavoro.predefiniti[0])
        }),
        ("57-spazio-analisi", { s in
            s.area = ShellView.area(per: dimensione, dockNascosto: false)
            s.clienteAttivoId = "marco"
            s.apriSpazio(SpazioLavoro.predefiniti[1])
        }),
        ("58-spazio-giornata", { s in
            s.area = ShellView.area(per: dimensione, dockNascosto: false)
            s.apriSpazio(SpazioLavoro.predefiniti[2])
        }),
        ("56-spazi", { s in
            s.area = ShellView.area(per: dimensione, dockNascosto: false)
            s.dati.spazi = [SpazioLavoro(nome: "Revisione annuale", finestre: [.destra(.documenti), .sinistra(.posizioni)])]
            s.apri(.agenda)
            s.pannelloSpazi = true
        }),
        ("60-note", { s in
            s.scegliNota("nota-giulia")
            s.apri(.note)
        }),
        ("61-clienti-note", { s in
            s.clienteAttivoId = "marco"
            s.schedaCliente = .note
            s.apri(.clienti)
        }),
        ("62-notifiche", { s in
            if let i = s.dati.posizioni.firstIndex(where: { $0.stato == .inEssere && $0.canale == .alleanza }) {
                s.dati.posizioni[i].scadenza = Calendar.current.date(byAdding: .day, value: 12, to: Calendar.current.startOfDay(for: Date()))
            }
            s.alternaNotifiche()
        }),
        ("63-benvenuto", { s in
            s.apri(.clienti)
            s.blocca()
        }),
        ("64-app-aperte", { s in
            // Ogni scheda con il suo contesto: Agenda filtrata su Marco, Note su Sofia, Posizioni sul
            // portafoglio, Prodotti senza cliente, Clienti sul cliente attivo
            s.filtroClienteAgenda = "marco"
            s.filtroClienteNote = "sofia"
            s.apri(.agenda)
            s.apri(.note)
            s.portafoglio = true
            s.apri(.posizioni)
            s.apri(.prodotti)
            s.apri(.clienti)
            s.riduci(.agenda)
            s.pannelloAppAperte = true
        }),
        ("65-portafoglio", { s in
            s.portafoglio = true
            s.apri(.posizioni)
        }),
        ("66-prospetto-portafoglio", { s in
            s.apriProspetto(.portafoglio)
        }),
        ("67-eve-portafoglio", { s in
            s.rispostePreparate = true
            s.evePortafoglio = true
            s.chiediEvePortafoglio(SpuntoPortafoglio.quadro.domanda, spunto: .quadro)
            s.chiediEvePortafoglio(SpuntoPortafoglio.settimana.domanda, spunto: .settimana)
            s.apri(.eve)
        }),
        ("51-scrivania-schermo-basso", { _ in }),
        ("52-eve-schermo-basso", { s in
            s.clienteAttivoId = "giulia"
            s.apri(.eve)
        }),
        ("18-analisi360-protezione", { s in
            s.clienteAttivoId = "marco"
            s.areaAnalisi = .protezione
            s.apri(.analisi360)
        }),
        // Le impostazioni di aspetto (chiaro, scuro, sfondo, pioggia)
        ("90-impostazioni-aspetto", { s in
            s.apri(.impostazioni)
            s.schedaImpostazioni = .esperienza
        }),
        // Le analisi nuove dei motori: Posizioni (dettaglio, crisi, coerenza) e le schermate degli altri temi
        ("91-posizioni-rendimento-versamenti", { s in
            // Giulia, ETF: il rendimento dei suoi versamenti accanto a quello del prodotto
            s.clienteAttivoId = "giulia"
            s.posizioneInDettaglio = "pos-giulia-etf-azionario-globale"
            s.apri(.posizioni)
            s.ancoraPosizioni = "dettaglio-andamento"
        }),
        ("92-posizioni-gestione-separata", { s in
            // Giulia, piano rivalutabile: gestione separata, costi come nel KID, quota azionaria
            s.clienteAttivoId = "giulia"
            s.posizioneInDettaglio = "pos-giulia-piano-di-risparmio-rivalutabile"
            s.apri(.posizioni)
        }),
        ("93-posizioni-riscatto-penali", { s in
            // Andrea, proposta con penali e 12 mesi di blocco: il riscatto anno per anno
            s.clienteAttivoId = "andrea"
            s.posizioneInDettaglio = "pos-andrea-piano-di-risparmio-rivalutabile"
            s.apri(.posizioni)
            s.ancoraPosizioni = "dettaglio-riscatto"
        }),
        ("94-posizioni-kid-proposta", { s in
            // Sofia, proposta obbligazionaria: costi calcolati come nel KID contro il RIY dichiarato
            s.clienteAttivoId = "sofia"
            s.posizioneInDettaglio = "pos-sofia-obbligazionario-a-scadenza-2030"
            s.apri(.posizioni)
        }),
        ("95-posizioni-crisi", { s in
            // Giulia: le crisi del 2008, 2020 e 2022 nella prova di resistenza
            s.clienteAttivoId = "giulia"
            s.apri(.posizioni)
            s.ancoraPosizioni = "resistenza"
        }),
        ("96-posizioni-coerenza", { s in
            // Marco: tutto su Alleanza, la concentrazione nel pannello della coerenza con il profilo
            s.clienteAttivoId = "marco"
            s.apri(.posizioni)
            s.ancoraPosizioni = "coerenza"
        }),
        ("97-posizioni-coerenza-giulia", { s in
            // Giulia: le crisi vere oltre il profilo e le proposte aperte
            s.clienteAttivoId = "giulia"
            s.apri(.posizioni)
            s.ancoraPosizioni = "coerenza"
        }),
        ("98-obiettivo-probabilita", { s in
            // Marco, gli studi di Anna: la probabilità di arrivarci (scenari con le probabilità). Solo per la scena
            // la polizza multiramo lavora per l'obiettivo: senza una posizione che oscilla non ci sono probabilità
            s.clienteAttivoId = "marco"
            if let i = s.dati.obiettivi.firstIndex(where: { $0.id == "obiettivo-marco-studi" }) {
                s.dati.obiettivi[i].posizioniCollegate = ["pos-marco-polizza-multiramo"]
            }
            s.obiettivoSelezionato = "obiettivo-marco-studi"
            s.apri(.obiettivi)
        }),
        ("99-analisi360-pensione", { s in
            // Marco: la pensione pubblica stimata con il contributivo
            s.clienteAttivoId = "marco"
            s.areaAnalisi = .previdenza
            s.apri(.analisi360)
        }),
        ("100-analisi360-protezione-persone", { s in
            // Giulia e Luca: la protezione persona per persona
            s.clienteAttivoId = "giulia"
            s.areaAnalisi = .protezione
            s.apri(.analisi360)
        }),
        ("101-resistenza-prospetto", { s in
            // Giulia: il prospetto della prova di resistenza, seconda pagina (le crisi del passato), a tutta finestra
            s.clienteAttivoId = "giulia"
            if let d = s.documentoProspetto(.resistenza(report: false)) {
                s.presenta(d)
                s.paginaSeguente()
            }
        }),
        ("102-costi-prospetto", { s in
            // Giulia: il prospetto dei costi, seconda pagina (l'incidenza come nel KID), a tutta finestra
            s.clienteAttivoId = "giulia"
            if let d = s.documentoProspetto(.costi(report: false)) {
                s.presenta(d)
                s.paginaSeguente()
            }
        }),
        ("103-ricerca-filtri", { s in
            // Ricerca per criterio: filtri riconosciuti, totali per canale e anteprima della prima posizione
            s.testoRicerca = "sri>3 canale:alleanza"
            s.cercaOvunque()
        }),
        ("104-ricerca-salvate", { s in
            // Pannello vuoto: le ricerche salvate e i filtri da provare
            s.dati.impostazioni.ricercheSalvate = [RicercaSalvata(nome: "Proposte aperte", testo: "stato:proposta"),
                                                   RicercaSalvata(nome: "Senza previdenza", testo: "senza:previdenza"),
                                                   RicercaSalvata(nome: "Scadenze Alleanza 2027", testo: "scade:2027 canale:alleanza")]
            s.testoRicerca = ""
            s.cercaOvunque()
        }),
        ("105-incontri-preparazione", { s in
            // La preparazione dell'incontro di oggi (le quattro schede, le priorità del cliente e «L'ultima volta»)
            s.clienteAttivoId = "giulia"
            s.incontroAperto = "incontro-giulia-casa"
            s.schedaIncontro = .preparazione
            s.apri(.incontri)
        }),
        ("106-posizioni-multiramo", { s in
            // Marco: la multiramo a due parti, la composizione, la parte in gestione separata e i fondi
            s.clienteAttivoId = "marco"
            s.posizioneInDettaglio = "pos-marco-polizza-multiramo"
            s.apri(.posizioni)
            s.ancoraPosizioni = "dettaglio-composizione"
        }),
        // Giro 3 · completezza dei dati per l'analisi (specifica 7)
        ("110-clienti-completezza", { s in
            // Andrea (primo incontro): dati per l'analisi al 77%, l'orizzonte manca, fabbisogno e pensione stimati
            s.clienteAttivoId = "andrea"
            s.schedaCliente = .panoramica
            s.apri(.clienti)
        }),
        ("111-analisi360-ipotesi-stimate", { s in
            // La pensione pubblica evidenziata, «stimato» accanto alle ipotesi predefinite
            s.clienteAttivoId = "andrea"
            s.fuocoAnalisi = FuocoAnalisi(area: .previdenza, campo: TestiCompletezza.campoPensionePubblica)
            s.areaAnalisi = .previdenza
            s.apri(.analisi360)
        }),
        ("112-prospetto-ipotesi-stimate", { s in
            // Check-up di Andrea: l'ultima pagina, i dati mancanti e le ipotesi stimate
            s.clienteAttivoId = "andrea"
            // `0..<max(0, n − 1)`: con `1..<n` un documento vuoto farebbe un intervallo non valido
            if let d = s.documentoProspetto(.checkUp(report: false)) {
                s.presenta(d)
                for _ in 0..<max(0, d.pagine.count - 1) { s.paginaSeguente() }
            }
        }),
        ("113-report-ipotesi-stimate", { s in
            // Report del check-up: la slide «Le ipotesi da confermare insieme» (prima della sintesi)
            s.clienteAttivoId = "andrea"
            if let d = s.documentoProspetto(.checkUp(report: true)) {
                s.presenta(d)
                for _ in 0..<max(0, d.pagine.count - 2) { s.paginaSeguente() }
            }
        }),
        // Giro 3 · seguito delle proposte (specifica 5)
        ("114-agenda-esito-proposta", { s in
            // Laura: la proposta presentata ieri, il riquadro «Com'è andata…» con le quattro scelte
            Istantanee.concludiIeri(s, "event-laura", ore: 10)
            s.apri(.agenda)
        }),
        ("115-agenda-firma-decorrenza", { s in
            // Giulia: la firma del PIP ieri, il passo «Accettata» con decorrenza, versato e primo valore
            if let i = s.dati.appuntamenti.firstIndex(where: { $0.id == "event-giulia-previdenza" }) {
                s.dati.appuntamenti[i].tipo = .firma
            }
            Istantanee.concludiIeri(s, "event-giulia-previdenza", ore: 18)
            s.apri(.agenda)
        }),
        ("116-portafoglio-seguito", { s in
            // «Proposte da riprendere»: Sofia 34 giorni, Giulia 25, Andrea da riprendere; motivi e tempo medio
            Istantanee.preparaSeguito(s)
            s.portafoglio = true
            s.ancoraPosizioni = "seguito"
            s.apri(.posizioni)
        }),
        ("117-notifiche-seguito", { s in
            // «3 proposte aspettano una risposta» in DA RECUPERARE
            Istantanee.preparaSeguito(s)
            s.alternaNotifiche()
        }),
        ("118-scrivania-seguito", { s in
            // La riga «3 proposte aspettano una risposta» nel giorno del widget Agenda
            Istantanee.preparaSeguito(s)
        }),
        ("119-posizioni-esito-rimandata", { s in
            // Andrea: «Esito della proposta: Rimandata · da riprendere il …» e i pulsanti dell'esito
            Istantanee.preparaSeguito(s)
            s.clienteAttivoId = "andrea"
            s.posizioneInDettaglio = "pos-andrea-piano-di-risparmio-rivalutabile"
            s.apri(.posizioni)
        }),
        // Giro 3 · esperienza per tipo di prodotto (specifica 2)
        ("120-clienti-esperienza", { s in
            // Giulia: la griglia per tipo, la capacità «fino al 10%», il suggerimento sui fondi e l'esperienza suggerita
            s.clienteAttivoId = "giulia"
            s.schedaCliente = .profilo
            s.apri(.clienti)
        }),
        ("121-posizioni-proposta-esperienza", { s in
            // Andrea: la proposta di Ramo I che non conosce, con la pillola «Esperienza» e l'etichetta blu Alleanza
            s.clienteAttivoId = "andrea"
            s.posizioneInDettaglio = "pos-andrea-piano-di-risparmio-rivalutabile"
            s.apri(.posizioni)
        }),
        ("122-posizioni-coerenza-esperienza", { s in
            // Giulia: «Coerenza con il profilo» con l'esperienza sul PIP tra i punti da rivedere
            s.clienteAttivoId = "giulia"
            s.apri(.posizioni)
            s.ancoraPosizioni = "coerenza"
        }),
        // Giro 3 · riesami del mese in Agenda (specifica 6)
        ("124-agenda-riesami-mese", { s in
            // La striscia «Riesami del mese»: Sofia mai incontrata, Laura e Marco scaduti
            ProvaRiesamiAgenda.prepara(s)
            s.apri(.agenda)
        }),
        ("125-agenda-riesame-pianificato", { s in
            // «Pianifica» per Laura: il riesame nel primo spazio libero, con canale e ordine del giorno
            ProvaRiesamiAgenda.prepara(s)
            if let p = s.pianificaRiesame("laura") { s.salvaAppuntamento(p.appuntamento) }
            s.apri(.agenda)
        }),
        ("126-impostazioni-orari", { s in
            // Il gruppo «Orari di lavoro» nella scheda Esperienza
            s.schedaImpostazioni = .esperienza
            s.apri(.impostazioni)
        }),
        ("127-agenda-riesami-schermo-basso", { s in
            // Finestra bassa (1280×760): fascia e striscia compatte su una riga
            ProvaRiesamiAgenda.prepara(s)
            s.apri(.agenda)
        }),
        // Le scene in aspetto scuro: il suffisso "-scuro" le disegna così (vedi genera)
        ("53-ricerca-scuro", { s in
            s.apri(.posizioni)
            s.testoRicerca = "marco"
            s.cercaOvunque()
        }),
        ("92-posizioni-gestione-separata-scuro", { s in
            s.clienteAttivoId = "giulia"
            s.posizioneInDettaglio = "pos-giulia-piano-di-risparmio-rivalutabile"
            s.apri(.posizioni)
        }),
        ("106-posizioni-multiramo-scuro", { s in
            // La stessa scena della multiramo di Marco, in aspetto scuro (vetro delle due parti)
            s.clienteAttivoId = "marco"
            s.posizioneInDettaglio = "pos-marco-polizza-multiramo"
            s.apri(.posizioni)
            s.ancoraPosizioni = "dettaglio-composizione"
        }),
        ("110-clienti-completezza-scuro", { s in
            s.clienteAttivoId = "andrea"
            s.schedaCliente = .panoramica
            s.apri(.clienti)
        }),
        ("114-agenda-esito-proposta-scuro", { s in
            Istantanee.concludiIeri(s, "event-laura", ore: 10)
            s.apri(.agenda)
        }),
        ("116-portafoglio-seguito-scuro", { s in
            Istantanee.preparaSeguito(s)
            s.portafoglio = true
            s.ancoraPosizioni = "seguito"
            s.apri(.posizioni)
        }),
        ("120-clienti-esperienza-scuro", { s in
            s.clienteAttivoId = "giulia"
            s.schedaCliente = .profilo
            s.apri(.clienti)
        }),
        ("124-agenda-riesami-mese-scuro", { s in
            ProvaRiesamiAgenda.prepara(s)
            s.apri(.agenda)
        }),
        ("1-scrivania-scuro", { _ in }),
        ("2-posizioni-scuro", { $0.apri(.posizioni) }),
        ("4-finestra-non-ingrandita-scuro", { s in
            s.apri(.clienti)
            s.alternaIngrandimento(.clienti)
        }),
        ("5-clienti-panoramica-scuro", { $0.apri(.clienti) }),
        ("63-benvenuto-scuro", { s in
            s.apri(.clienti)
            s.blocca()
        }),
        ("64-app-aperte-scuro", { s in
            s.filtroClienteAgenda = "marco"
            s.apri(.agenda)
            s.apri(.clienti)
            s.pannelloAppAperte = true
        }),
        ("90-impostazioni-aspetto-scuro", { s in
            s.apri(.impostazioni)
            s.schedaImpostazioni = .esperienza
        }),
    ]

    /// Seguito delle proposte (scene 114 e 115): l'appuntamento spostato a ieri all'ora data e concluso, come
    /// dall'agenda; il giorno e l'appuntamento restano aperti nel dettaglio.
    nonisolated private static func concludiIeri(_ s: StatoShell, _ id: String, ore: Int) {
        let cal = Calendar.current
        let ieri = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())) ?? Date()
        guard let i = s.dati.appuntamenti.firstIndex(where: { $0.id == id }) else { return }
        s.dati.appuntamenti[i].inizio = cal.date(bySettingHour: ore, minute: 0, second: 0, of: ieri) ?? ieri
        s.dati.appuntamenti[i].stato = .pianificato
        s.alternaConcluso(id)
        s.giornoAgenda = ieri
        s.appuntamentoSelezionato = id
    }

    /// Seguito delle proposte (scene 116–119): proposte ferme, una rimandata, una rifiutata e una accettata,
    /// con date relative a oggi (riproducibili a qualunque ora del server).
    nonisolated private static func preparaSeguito(_ s: StatoShell) {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: Date())
        func g(_ n: Int) -> Date { ValoriDaDocumento.mezzogiorno(cal.date(byAdding: .day, value: n, to: oggi) ?? oggi) }
        var d = s.dati
        // Nessun appuntamento futuro di Giulia, Sofia e Andrea: le loro proposte sono ferme
        let clienti: Set<String> = ["giulia", "sofia", "andrea"]
        d.appuntamenti.removeAll { clienti.contains($0.clienteId) && $0.inizio >= oggi }
        func cambia(_ id: String, _ modifica: (inout Posizione, inout SeguitoProposta) -> Void) {
            guard let i = d.posizioni.firstIndex(where: { $0.id == id }) else { return }
            var seguito = d.posizioni[i].seguito ?? SeguitoProposta()
            modifica(&d.posizioni[i], &seguito)
            d.posizioni[i].seguito = seguito
        }
        cambia("pos-sofia-obbligazionario-a-scadenza-2030") { _, sg in sg.presentataIl = g(-34) }
        cambia("pos-giulia-piano-previdenziale-integrativo") { _, sg in sg.presentataIl = g(-25) }
        cambia("pos-andrea-piano-di-risparmio-rivalutabile") { p, sg in
            p.esito = .rimandata
            sg.esitoIl = g(-95)
            sg.riprendereIl = g(-5)
            sg.motivo = .liquidita
        }
        cambia("pos-andrea-temporanea-caso-morte") { p, sg in
            p.esito = .rifiutata
            sg.motivo = .costo
            sg.presentataIl = g(-30)
            sg.esitoIl = g(-10)
        }
        cambia("pos-giulia-etf-azionario-globale") { p, sg in
            p.esito = .accettata
            sg.presentataIl = g(-60)
            sg.esitoIl = g(-40)
        }
        s.dati = d
    }

    /// Metodi di disegno, in ordine di preferenza sul server di build:
    /// - "finestra": NSHostingView in una finestra fuori schermo + cacheDisplay (senza Metal)
    /// - "livello": come sopra, ma con CALayer.render(in:)
    /// - "renderer": ImageRenderer di SwiftUI (richiede Metal)
    static func genera(in cartella: URL, metodo: String, solo: Set<String>? = nil) -> Int32 {
        _ = NSApplication.shared
        // I PNG non catturano i materiali di sistema né il vetro di macOS 26: vetro disegnato, più coprente
        Vetro.semplificato = true
        do {
            try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        } catch {
            print("ERRORE: cartella delle istantanee non creata: \(error.localizedDescription)")
            return 1
        }
        for scena in scene where solo?.contains(scena.nome) ?? true {
            // Un pool per scena: senza il ciclo degli eventi (si esce in PrismaApp.init) niente lo svuoterebbe,
            // e stato, finestra e bitmap di ogni scena resterebbero in memoria fino all'ultima istantanea
            let riuscita: Bool = autoreleasepool { () -> Bool in
                let stato = StatoShell(persistente: false)
                let misura = scena.nome.hasSuffix("-schermo-basso") ? dimensioneBassa : dimensione
                // Le scene "-scuro" in aspetto scuro: finestra, ambiente SwiftUI e impostazione
                let scuro = scena.nome.hasSuffix("-scuro")
                if scuro { stato.dati.impostazioni.aspetto = .scuro }
                scena.prepara(stato)
                stato.area = ShellView.area(per: misura, dockNascosto: !stato.finestreVisibili.isEmpty)
                let vista = ShellView()
                    .environmentObject(stato)
                    .environment(\.modoIstantanea, true)
                    .environment(\.colorScheme, scuro ? .dark : .light)
                    .frame(width: misura.width, height: misura.height)
                let aspetto = NSAppearance(named: scuro ? .darkAqua : .aqua)
                let png: Data?
                switch metodo {
                case "renderer": png = conRenderer(vista, aspetto: aspetto)
                case "livello": png = conFinestra(vista, livello: true, misura: misura, aspetto: aspetto)
                default: png = conFinestra(vista, livello: false, misura: misura, aspetto: aspetto)
                }
                guard let png else {
                    print("ERRORE: istantanea \(scena.nome) non disegnata (metodo \(metodo))")
                    return false
                }
                do {
                    try png.write(to: cartella.appendingPathComponent("\(scena.nome).png"))
                    print("OK: \(scena.nome).png (metodo \(metodo))")
                } catch {
                    print("ERRORE: \(scena.nome).png non salvata: \(error.localizedDescription)")
                    return false
                }
                return true
            }
            guard riuscita else { return 1 }
        }
        return 0
    }

    /// Disegna con l'aspetto dato (chiaro o scuro): i colori dinamici del tema si risolvono così.
    private static func conAspetto(_ aspetto: NSAppearance?, _ disegna: () -> Void) {
        if let aspetto {
            aspetto.performAsCurrentDrawingAppearance(disegna)
        } else {
            disegna()
        }
    }

    private static func conRenderer<V: View>(_ vista: V, aspetto: NSAppearance?) -> Data? {
        let renderer = ImageRenderer(content: vista)
        renderer.scale = 2
        var immagine: CGImage?
        conAspetto(aspetto) { immagine = renderer.cgImage }
        guard let cg = immagine else { return nil }
        return pngVerificato(NSBitmapImageRep(cgImage: cg))
    }

    private static func conFinestra<V: View>(_ vista: V, livello: Bool, misura: CGSize, aspetto: NSAppearance?) -> Data? {
        let host = NSHostingView(rootView: vista)
        host.frame = NSRect(origin: .zero, size: misura)
        host.appearance = aspetto
        let finestra = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        finestra.appearance = aspetto
        finestra.contentView = host
        finestra.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        finestra.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        defer {
            finestra.orderOut(nil)
            // Il contenuto (e con lui lo stato della scena) si libera con la scena, dopo il disegno
            finestra.contentView = nil
        }

        if livello {
            let scala: CGFloat = 2
            guard let strato = host.layer,
                  let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                             pixelsWide: Int(misura.width * scala), pixelsHigh: Int(misura.height * scala),
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let contesto = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
            let cg = contesto.cgContext
            cg.scaleBy(x: scala, y: scala)
            if host.isFlipped {
                cg.translateBy(x: 0, y: misura.height)
                cg.scaleBy(x: 1, y: -1)
            }
            conAspetto(aspetto) { strato.render(in: cg) }
            return pngVerificato(rep)
        }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        conAspetto(aspetto) { host.cacheDisplay(in: host.bounds, to: rep) }
        return pngVerificato(rep)
    }

    /// Scarta le immagini vuote (tutte dello stesso colore): vuol dire che il metodo non disegna.
    private static func pngVerificato(_ rep: NSBitmapImageRep) -> Data? {
        let campioni = [(0.1, 0.1), (0.5, 0.5), (0.9, 0.2), (0.3, 0.8), (0.7, 0.95), (0.5, 0.02)]
        let colori = campioni.compactMap { c in
            rep.colorAt(x: Int(Double(rep.pixelsWide) * c.0), y: Int(Double(rep.pixelsHigh) * c.1))?.usingColorSpace(.deviceRGB)
        }
        let diversi = Set(colori.map { "\(Int($0.redComponent * 255))-\(Int($0.greenComponent * 255))-\(Int($0.blueComponent * 255))" })
        guard diversi.count > 1 else {
            print("ATTENZIONE: immagine vuota")
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}

private struct ChiaveModoIstantanea: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// true quando la vista viene disegnata per un'istantanea (niente viste AppKit).
    var modoIstantanea: Bool {
        get { self[ChiaveModoIstantanea.self] }
        set { self[ChiaveModoIstantanea.self] = newValue }
    }
}
