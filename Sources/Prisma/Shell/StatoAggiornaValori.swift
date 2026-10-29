#if os(macOS)
import AppKit
#endif
import SwiftUI

/// Il pannello «Aggiorna i valori» in Posizioni (specifica 8): apertura, lettura del file o degli appunti,
/// registrazione dopo un backup e passaggio all'importazione normale. La sessione sta in `aggiornaValori`
/// (StatoShell); lo stato della vista (scelte, esclusioni, caselle della griglia) resta nella vista.
extension StatoShell {
    /// Apre il pannello sulla griglia (o sulla scheda già aperta), nel dossier sul solo cliente attivo.
    func apriAggiornaValori(scheda: AggiornaValori.Scheda = .griglia) {
        // In modo cliente il pannello non si apre: è un lavoro del consulente e mostra numeri di più clienti
        guard !inModoCliente else { return }
        posizioneInDettaglio = nil
        if aggiornaValori != nil {
            aggiornaValori?.scheda = scheda
        } else {
            aggiornaValori = AggiornaValori.Sessione(scheda: scheda, soloCliente: portafoglio ? nil : clienteAttivoId)
        }
        apri(.posizioni)
    }

    /// Dall'importazione: il pannello sull'elenco con le stesse righe (proposta = true).
    func apriAggiornaValori(da i: ImportazionePosizioni) {
        guard !inModoCliente else { return }
        guard let s = AggiornaValori.sessione(tabella: i.righe, file: i.file, dataComune: Date(), proposta: true) else {
            mostraAvviso(TestiAggiornaValori.fileSenzaValori)
            return
        }
        posizioneInDettaglio = nil
        aggiornaValori = s
        apri(.posizioni)
    }

    /// NSOpenPanel con `tipiTabelle` (come importaPosizioniDaFile) → `ImportaClienti.righe(url)` → sessione.
    @MainActor
    func scegliFileValori() {
        #if os(macOS)
        let pannello = NSOpenPanel()
        pannello.allowedContentTypes = Self.tipiTabelle
        pannello.allowsMultipleSelection = false
        pannello.message = TestiAggiornaValori.messaggioApertura
        guard pannello.runModal() == .OK, let url = pannello.url else { return }
        guard let tabella = ImportaClienti.righe(url) else {
            mostraAvviso(TestiAggiornaValori.fileSenzaValori)
            return
        }
        apriElencoValori(tabella: tabella, file: url.lastPathComponent)
        #elseif os(iOS)
        // Su iPhone e iPad il file si sceglierà con `.fileImporter` nella vista (giro 2)
        mostraAvviso(StatoShell.soloSulMacPerOra)
        #endif
    }

    /// Appunti (come incollaDaExcel) → `ImportaClienti.righeCSV` → sessione.
    @MainActor
    func incollaValoriDaExcel() {
        guard let testo = Appunti.testo, testo.contains("\n") || testo.contains("\t") else {
            mostraAvviso(TestiAggiornaValori.appuntiVuoti)
            return
        }
        apriElencoValori(tabella: ImportaClienti.righeCSV(testo), file: "appunti")
    }

    /// Una sessione nuova sull'elenco: sostituisce la precedente (e chiude un riepilogo aperto).
    private func apriElencoValori(tabella: [[String]], file: String) {
        guard let s = AggiornaValori.sessione(tabella: tabella, file: file, dataComune: Date()) else {
            mostraAvviso(TestiAggiornaValori.fileSenzaValori)
            return
        }
        posizioneInDettaglio = nil
        aggiornaValori = s
        apri(.posizioni)
    }

    /// Registra gli esiti scelti, dopo un backup; il riepilogo va nella sessione aperta.
    func registraValoriInBlocco(_ esiti: [AggiornaValori.Esito], esclusi: Set<Int>) {
        guard !solaLettura, AggiornaValori.daRegistrare(esiti, esclusi: esclusi) > 0 else { return }
        // Un campo che rinvia la scrittura altrove nell'app va nell'archivio prima del backup
        TestiRinviati.scriviOra()
        dopoUnBackup(nota: "prima dell'aggiornamento dei valori", annullata: "Aggiornamento annullato") { [weak self] conBackup in
            guard let self else { return }
            let r = self.applicaValoriInBlocco(esiti, esclusi: esclusi)
            self.mostraAvviso(TestiAggiornaValori.avviso(r, backup: conBackup))
        }
    }

    /// La parte senza backup (prove e archivio in memoria).
    @discardableResult
    func applicaValoriInBlocco(_ esiti: [AggiornaValori.Esito], esclusi: Set<Int>) -> AggiornaValori.Riepilogo {
        let r = AggiornaValori.applica(esiti, esclusi: esclusi, a: &dati.posizioni)
        aggiornaValori?.riepilogo = r
        return r
    }

    /// Le righe del file (tutte, o solo quelle non trovate) nell'importazione normale (modulo di Posizioni).
    func importaComeNuove(soloRighe: Set<Int>? = nil) {
        guard let s = aggiornaValori, let testa = s.tabella.first else { return }
        // L'id di una riga è il suo posto nella tabella, sotto l'intestazione
        let scelte = s.tabella.indices.dropFirst().filter { soloRighe?.contains($0) ?? true }.map { s.tabella[$0] }
        let righe = [testa] + scelte
        let letto = ImportaPosizioni.daRighe(righe, clienti: clienti, posizioni: posizioni, prodotti: dati.prodotti)
        guard !letto.posizioni.isEmpty else {
            mostraAvviso(TestiAggiornaValori.nessunaPosizione)
            return
        }
        importazionePosizioni = ImportazionePosizioni(file: s.file, colonne: letto.colonne, posizioni: letto.posizioni, righe: righe)
    }
}
