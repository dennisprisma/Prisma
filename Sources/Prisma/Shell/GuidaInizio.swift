import AppKit
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

    @MainActor
    func importaClientiDaFile() {
        let pannello = NSOpenPanel()
        pannello.allowedContentTypes = [.vCard, .commaSeparatedText, .tabSeparatedText, .plainText]
        pannello.allowsMultipleSelection = false
        pannello.message = "Un file vCard (dall'app Contatti: seleziona i contatti e trascinali sulla scrivania) o un CSV esportato da Excel o Numbers. Il file resta sul Mac."
        guard pannello.runModal() == .OK, let url = pannello.url else { return }
        if let lettura = ImportaClienti.leggi(url, rubrica: clienti) {
            apri(.clienti)
            importazione = lettura
        } else {
            mostraAvviso("Nel file non ho trovato contatti con un nome. Per Excel salva come CSV, con i nomi delle colonne nella prima riga.")
        }
    }

    @MainActor
    func importaPosizioniDaFile() {
        let pannello = NSOpenPanel()
        pannello.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .plainText]
        pannello.allowsMultipleSelection = false
        pannello.message = "Un CSV con una posizione per riga e i nomi delle colonne nella prima (da Excel o Numbers: «Salva come» CSV). I clienti devono essere già in rubrica."
        guard pannello.runModal() == .OK, let url = pannello.url else { return }
        if let lettura = ImportaPosizioni.leggi(url, clienti: clienti, posizioni: posizioni) {
            apri(.posizioni)
            importazionePosizioni = lettura
        } else {
            mostraAvviso("Nel file non ho trovato posizioni: servono almeno il prodotto o il numero di contratto, con i nomi delle colonne nella prima riga.")
        }
    }
}

/// La striscia della guida sulla scrivania: a che punto sei e il prossimo passo.
struct StrisciaGuida: View {
    @EnvironmentObject var stato: StatoShell
    @State private var elenco = false

    var body: some View {
        let passi = stato.passiGuida
        let fatti = passi.filter(\.fatto).count
        let prossimo = passi.first { !$0.fatto }
        HStack(spacing: 12) {
            Text("✦").font(Tipo.contenuto(14, .bold)).foregroundColor(Colori.Widget.guidaSimbolo)
            Text("Comincia con i tuoi dati · \(fatti) di \(passi.count)")
                .font(Tipo.sistema(11, .semibold)).foregroundColor(Colori.Pulsante.testo)
            Text(prossimo.map { "Prossimo passo: \($0.titolo.prefix(1).lowercased() + $0.titolo.dropFirst())." } ?? "Fatto tutto.")
                .font(Tipo.sistema(11)).foregroundColor(Colori.Widget.secondario)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let p = prossimo {
                Button(p.pulsante) { stato.eseguiPasso(p.azione) }
                    .buttonStyle(StileBlu())
            }
            Button("Tutti i passi") { elenco = true }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
            Button {
                stato.dati.impostazioni.guidaNascosta = true
            } label: {
                Text("✕").font(Tipo.chip).foregroundColor(Colori.Widget.secondario)
            }
            .buttonStyle(StileSemplice())
            .help("Nascondi la guida (torna da Impostazioni → Esperienza)")
        }
        .incisione(Color.white.opacity(0.6))
        .padding(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 8))
        // Una barra di bezel, come i pulsanti di vetro: non una banda bianca che spezza la scrivania
        .frame(maxWidth: .infinity)
        .frame(height: Misure.Widget.striscia)
        .background(RoundedRectangle(cornerRadius: Misure.Pulsante.raggio).fill(Gradienti.vetro))
        .luceInterna(.white, raggio: Misure.Pulsante.raggio)
        .overlay(RoundedRectangle(cornerRadius: Misure.Pulsante.raggio).strokeBorder(Colori.Pulsante.vetroBordo, lineWidth: 1))
        .ombraCSS(Colori.Pulsante.vetroOmbra, y: 1, sfocatura: 2)
        .popover(isPresented: $elenco, arrowEdge: .bottom) { ElencoGuida().environmentObject(stato) }
    }
}

/// Tutti i passi della guida, con il pulsante per ciascuno.
struct ElencoGuida: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Comincia con i tuoi dati").font(Tipo.rigaTitolo).padding(.bottom, 8)
            ForEach(Array(stato.passiGuida.enumerated()), id: \.element.id) { i, p in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: p.fatto ? "checkmark.circle.fill" : "\(i + 1).circle")
                        .foregroundColor(p.fatto ? Colori.Analisi.okTesto : Colori.Analisi.navBasso)
                        .font(Tipo.contenuto(15, .regular))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.titolo).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                            .strikethrough(p.fatto, color: Colori.Analisi.kpiNota)
                        Text(p.dettaglio).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
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
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
        }
        .padding(16)
        .frame(width: Misure.Widget.elencoGuida)
    }
}
