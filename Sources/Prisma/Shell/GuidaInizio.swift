#if os(macOS)
import AppKit
#endif
import SwiftUI
import UniformTypeIdentifiers

/// Un passo della guida «Comincia con i tuoi dati»: si spunta da solo quando è fatto.
struct PassoGuida: Identifiable {
    enum Azione { case cartellaBackup, importaClienti, importaPosizioni, togliProva, passwordPDF, primoBackup }

    let azione: Azione
    let titolo: String
    let dettaglio: String
    let pulsante: String
    let fatto: Bool

    var id: String { titolo }
}

extension StatoShell {
    /// I passi per passare dai clienti di prova ai propri, nell'ordine consigliato.
    var passiGuida: [PassoGuida] {
        let veri = dati.clienti.contains { !Self.clientiDiProva.contains($0.id) }
        let posizioniVere = dati.posizioni.contains { !Self.clientiDiProva.contains($0.clienteId) }
        let b = dati.impostazioni.backup
        return [
            PassoGuida(azione: .cartellaBackup, titolo: "Scegli dove salvare i backup",
                       dettaglio: "Una cartella su iCloud Drive o su un disco esterno: se il Mac si guasta, i dati dei clienti restano al sicuro.",
                       pulsante: "Scegli la cartella", fatto: b.cartella != nil),
            PassoGuida(azione: .importaClienti, titolo: "Porta i tuoi clienti",
                       dettaglio: "Dall'app Contatti (vCard) o da un CSV di Excel; uno alla volta con «Nuovo cliente».",
                       pulsante: "Importa i clienti", fatto: veri),
            PassoGuida(azione: .importaPosizioni, titolo: "Porta le loro posizioni",
                       dettaglio: "Da un CSV con l'elenco delle polizze e dei prodotti; o una per una, anche dai documenti.",
                       pulsante: "Importa le posizioni", fatto: posizioniVere),
            PassoGuida(azione: .togliProva, titolo: "Togli i clienti di prova",
                       dettaglio: "Giulia, Marco, Laura, Andrea e Sofia escono con tutti i loro dati; prima Prisma fa un backup.",
                       pulsante: "Toglili", fatto: !haDatiDiProva),
            PassoGuida(azione: .passwordPDF, titolo: "Proteggi i PDF per i clienti",
                       dettaglio: "La password proposta salvando prospetti e report: data di nascita o codice fiscale del cliente.",
                       pulsante: "Attiva", fatto: dati.impostazioni.pdf.proteggi),
            PassoGuida(azione: .primoBackup, titolo: "Fai il primo backup",
                       dettaglio: "Da qui in poi ci pensa Prisma ogni settimana (si conservano le ultime 8 copie).",
                       pulsante: "Crea il backup", fatto: b.ultimo != nil && b.cartella != nil),
        ]
    }

    /// La guida si vede finché non è finita o finché non la nascondi (e mai in sola lettura).
    var guidaVisibile: Bool {
        !solaLettura && !dati.impostazioni.guidaNascosta && passiGuida.contains { !$0.fatto }
    }

    @MainActor
    func eseguiPasso(_ a: PassoGuida.Azione) {
        switch a {
        case .cartellaBackup:
            schedaImpostazioni = .archivio
            apri(.impostazioni)
        case .importaClienti:
            importaClientiDaFile()
        case .importaPosizioni:
            apri(.posizioni)
            importaPosizioniDaFile()
        case .togliProva:
            schedaImpostazioni = .archivio
            apri(.impostazioni)
        case .passwordPDF:
            dati.impostazioni.pdf.proteggi = true
            schedaImpostazioni = .esperienza
            apri(.impostazioni)
            mostraAvviso("Password dei PDF attiva: scegli qui da quale dato del cliente ricavarla.")
        case .primoBackup:
            if dati.impostazioni.backup.cartella == nil {
                schedaImpostazioni = .archivio
                apri(.impostazioni)
                mostraAvviso("Prima scegli la cartella dei backup, poi «Crea backup».")
            } else {
                creaBackup()
            }
        }
    }

    // MARK: - Importazioni da file

    /// I tipi di file tabellari: CSV, testo a tabulazioni ed Excel (.xlsx).
    static var tipiTabelle: [UTType] {
        [.commaSeparatedText, .tabSeparatedText, .plainText] + [UTType(filenameExtension: "xlsx")].compactMap { $0 }
    }

    @MainActor
    func importaClientiDaFile() {
        #if os(macOS)
        let pannello = NSOpenPanel()
        pannello.allowedContentTypes = [.vCard] + Self.tipiTabelle
        pannello.allowsMultipleSelection = false
        pannello.message = "Un file vCard (dall'app Contatti: seleziona i contatti e trascinali sulla scrivania), un foglio Excel o un CSV. Il file resta sul Mac."
        guard pannello.runModal() == .OK, let url = pannello.url else { return }
        importaClienti(da: url)
        #elseif os(iOS)
        // Su iPhone e iPad il file si sceglie con `.fileImporter` (GuscioiPad), poi `importaClienti(da:)` sulla copia
        guard !solaLettura else { return }
        sceltaFileMobile = .clienti
        #endif
    }

    @MainActor
    func importaClienti(da url: URL) {
        if let lettura = ImportaClienti.leggi(url, rubrica: clienti) {
            apri(.clienti)
            importazione = lettura
        } else {
            mostraAvviso("Nel file non ho trovato contatti con un nome: servono i nomi delle colonne nella prima riga (Nome, Cognome, Codice fiscale…).")
        }
    }

    @MainActor
    func importaPosizioniDaFile() {
        #if os(macOS)
        let pannello = NSOpenPanel()
        pannello.allowedContentTypes = Self.tipiTabelle
        pannello.allowsMultipleSelection = false
        pannello.message = "Un foglio Excel o un CSV con una posizione per riga e i nomi delle colonne nella prima. I clienti che non sono in rubrica si aggiungono insieme."
        guard pannello.runModal() == .OK, let url = pannello.url else { return }
        importaPosizioni(da: url)
        #elseif os(iOS)
        // Su iPhone e iPad il file si sceglie con `.fileImporter` (GuscioiPad), poi `importaPosizioni(da:)` sulla copia
        guard !solaLettura else { return }
        sceltaFileMobile = .posizioni
        #endif
    }

    @MainActor
    func importaPosizioni(da url: URL) {
        if let lettura = ImportaPosizioni.leggi(url, clienti: clienti, posizioni: posizioni, prodotti: dati.prodotti) {
            apri(.posizioni)
            // Quasi tutte posizioni che Prisma ha già, con i valori: si propone di aggiornarli
            if ImportaPosizioni.propostoAggiornamento(lettura) { apriAggiornaValori(da: lettura) } else { importazionePosizioni = lettura }
        } else {
            mostraAvviso("Nel file non ho trovato posizioni: servono almeno il prodotto o il numero di contratto, con i nomi delle colonne nella prima riga.")
        }
    }

    /// Righe copiate da Excel o Numbers (intestazione compresa): clienti o posizioni, secondo le colonne.
    @MainActor
    func incollaDaExcel(posizioni preferite: Bool) {
        guard !solaLettura else { return }
        guard let testo = Appunti.testo, testo.contains("\n") || testo.contains("\t") else {
            mostraAvviso("Negli appunti non ci sono righe di tabella. In Excel seleziona le righe con l'intestazione, ⌘C, poi «Incolla da Excel».")
            return
        }
        let righe = ImportaClienti.righeCSV(testo)
        if preferite || ImportaPosizioni.sembraPosizioni(righe),
           let lettura = ImportaPosizioni.incollate(testo, clienti: clienti, posizioni: posizioni, prodotti: dati.prodotti) {
            apri(.posizioni)
            if ImportaPosizioni.propostoAggiornamento(lettura) { apriAggiornaValori(da: lettura) } else { importazionePosizioni = lettura }
        } else if let lettura = ImportaClienti.incollati(testo, rubrica: clienti) {
            apri(.clienti)
            importazione = lettura
        } else {
            mostraAvviso("Nelle righe copiate non ho riconosciuto le colonne: copia anche la riga dell'intestazione (Cliente, Prodotto, Numero polizza…).")
        }
    }

    /// Un file trascinato su Prisma va dove serve: PDF e immagini in Documenti, vCard in Clienti,
    /// tabelle in Posizioni se hanno prodotti o importi, altrimenti in Clienti.
    @MainActor
    func importaFileTrascinati(_ urls: [URL]) {
        guard !solaLettura else { return }
        let documenti = urls.filter { ["pdf", "png", "jpg", "jpeg", "tiff", "tif", "heic"].contains($0.pathExtension.lowercased()) }
        if !documenti.isEmpty {
            apri(.documenti)
            importaDocumenti(documenti)
        }
        // Le tabelle e i contatti: un'anteprima per volta, la prima
        if let url = urls.first(where: { !documenti.contains($0) }) {
            switch url.pathExtension.lowercased() {
            case "vcf":
                importaClienti(da: url)
            case "csv", "txt", "tsv", "xlsx":
                if let righe = ImportaClienti.righe(url), ImportaPosizioni.sembraPosizioni(righe) {
                    importaPosizioni(da: url)
                } else {
                    importaClienti(da: url)
                }
            case "xls", "numbers":
                mostraAvviso("«\(url.lastPathComponent)»: da Numbers o dal vecchio Excel salva come .xlsx o CSV, poi trascinalo di nuovo.")
            default:
                mostraAvviso("«\(url.lastPathComponent)» non è un file che Prisma sa importare.")
            }
        }
    }
}

/// La striscia della guida sulla scrivania: a che punto sei e il prossimo passo,
/// in una capsula di vetro leggero come i pulsanti della scrivania.
struct StrisciaGuida: View {
    @EnvironmentObject var stato: StatoShell
    @State private var elenco = false

    var body: some View {
        let passi = stato.passiGuida
        let fatti = passi.filter(\.fatto).count
        let prossimo = passi.first { !$0.fatto }
        HStack(spacing: Tema.Misura.PannelliShell.guidaSpazio) {
            Text("✦").font(Tema.Testo.PannelliShell.simboloGuida).foregroundColor(Tema.Colore.accento)
            Text("Comincia con i tuoi dati · \(fatti) di \(passi.count)")
                .font(Tema.Testo.PannelliShell.titoloGuida).foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
            Text(prossimo.map { "Prossimo passo: \($0.titolo.prefix(1).lowercased() + $0.titolo.dropFirst())." } ?? "Fatto tutto.")
                .font(Tema.Testo.PannelliShell.testoGuida).foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
            Spacer(minLength: 8)
            // La striscia della scrivania è alta 34 pt: pulsanti compatti (28), come nelle righe
            if let p = prossimo {
                Button(p.pulsante) { stato.eseguiPasso(p.azione) }
                    .buttonStyle(StileBlu(taglia: .compatta))
                    .fixedSize()
            }
            Button { elenco = true } label: { Label("Tutti i passi", systemImage: "list.bullet") }
                .buttonStyle(StileVetro(taglia: .compatta))
                .fixedSize()
            PulsanteIcona(simbolo: "xmark", aiuto: "Nascondi la guida (torna da Impostazioni → Esperienza)",
                          taglia: .compatta, vetro: false) {
                stato.dati.impostazioni.guidaNascosta = true
            }
        }
        .padding(Tema.Misura.PannelliShell.guida)
        .frame(maxWidth: .infinity)
        .frame(height: Misure.Widget.striscia)
        .vetro(.leggero, forma: .capsula)
        .popover(isPresented: $elenco, arrowEdge: .bottom) { ElencoGuida().environmentObject(stato) }
    }
}

/// Tutti i passi della guida, con il pulsante per ciascuno.
struct ElencoGuida: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Comincia con i tuoi dati")
                .font(Tema.Testo.titolo)
                .foregroundColor(Tema.Colore.inchiostro)
                .padding(.bottom, 8)
            ForEach(Array(stato.passiGuida.enumerated()), id: \.element.id) { i, p in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: p.fatto ? "checkmark.circle.fill" : "\(i + 1).circle")
                        .foregroundColor(p.fatto ? Tema.Colore.testoInEssere : Tema.Colore.inchiostroTerziario)
                        .font(Tipo.contenuto(15, .regular))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.titolo).font(Tema.Testo.titolo).foregroundColor(Tema.Colore.inchiostro)
                            .strikethrough(p.fatto, color: Tema.Colore.inchiostroSecondario)
                        Text(p.dettaglio).font(Tema.Testo.didascalia).foregroundColor(Tema.Colore.inchiostroSecondario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if !p.fatto {
                        Button(p.pulsante) { stato.eseguiPasso(p.azione) }
                            .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                            .fixedSize()
                    }
                }
                .padding(.vertical, 7)
                .bordoBasso(Tema.Colore.separatore)
            }
        }
        .padding(16)
        .frame(width: Misure.Widget.elencoGuida)
    }
}
