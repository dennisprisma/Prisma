#if os(iOS)
import SwiftUI

// Le app dell'iPhone in sola lettura che arrivano col giro 3 (nella finestra di vetro sopra la scrivania): Attività,
// Note, Documenti e Impostazioni. Le cifre e i testi sono quelli del Mac; il canale resta sempre in vista.

private typealias M = Tema.Misura.Mobile

// MARK: - Attività

/// Le attività aperte, per scadenza: scadute, oggi, domani, più avanti. La casella è ferma (si spunta sul Mac).
struct AttivitaTelefono: View {
    @EnvironmentObject var stato: StatoShell

    private enum Gruppo: Int, CaseIterable, Identifiable {
        case scadute, oggi, domani, avanti
        var id: Int { rawValue }
        var titolo: String {
            switch self {
            case .scadute: return "Scadute"
            case .oggi: return "Oggi"
            case .domani: return "Domani"
            case .avanti: return "Più avanti"
            }
        }
    }

    var body: some View {
        let aperte = stato.attivitaAperte.sorted { $0.scadenza < $1.scadenza }
        FondoTelefono {
            if aperte.isEmpty {
                VuotoTelefono(testo: "Tutto fatto: nessuna attività aperta.")
            }
            ForEach(Gruppo.allCases) { gruppo in
                let delGruppo = aperte.filter { Self.gruppo(di: $0) == gruppo }
                if !delGruppo.isEmpty {
                    SezioneTelefono(titolo: gruppo.titolo)
                    ForEach(delGruppo) { attivita in
                        RigaAttivitaTelefono(attivita: attivita, scaduta: gruppo == .scadute)
                    }
                }
            }
        }
        .navigationTitle("Attività")
    }

    private static func gruppo(di a: Attivita) -> Gruppo {
        let cal = Calendar.current
        if a.scadenza < cal.startOfDay(for: Date()) { return .scadute }
        if cal.isDateInToday(a.scadenza) { return .oggi }
        if cal.isDateInTomorrow(a.scadenza) { return .domani }
        return .avanti
    }
}

private struct RigaAttivitaTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let attivita: Attivita
    let scaduta: Bool

    var body: some View {
        HStack(alignment: .top, spacing: M.spazioRiga) {
            CasellaSpunta(spuntata: attivita.completata)
                .padding(.top, M.spazioTesto)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                Text(attivita.titolo)
                    .font(Tipo.Mobile.rigaNome)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .fixedSize(horizontal: false, vertical: true)
                Text(dettaglio)
                    .font(Tipo.Mobile.rigaDettaglio)
                    .foregroundColor(scaduta ? Tema.Colore.scadenzaOra : Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                if attivita.priorita == .alta {
                    Text("Priorità alta")
                        .font(Tipo.Mobile.stato)
                        .foregroundColor(Tema.Colore.scadenzaVicina)
                }
            }
            Spacer(minLength: 0)
        }
        .schedaTelefono()
        .accessibilityElement(children: .combine)
    }

    private var dettaglio: String {
        let cliente = stato.cliente(attivita.clienteId)?.nome
        let quando = "\(Formati.giornoRelativo(attivita.scadenza))"
        return [cliente, quando].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

// MARK: - Note

/// Le note del taccuino, le fissate in cima e poi dalla più recente; un tocco apre il testo intero.
struct NoteTelefono: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let note = stato.dati.note.filter { !$0.vuota }.sorted(by: Nota.ordina)
        FondoTelefono {
            if note.isEmpty {
                VuotoTelefono(testo: "Nessuna nota: le note si scrivono in Prisma sul Mac.")
            }
            ForEach(note) { nota in
                NavigationLink {
                    DettaglioNotaTelefono(notaId: nota.id)
                } label: {
                    RigaNotaTelefono(nota: nota)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Note")
    }
}

private struct RigaNotaTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let nota: Nota

    var body: some View {
        HStack(alignment: .top, spacing: M.spazioRiga) {
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                HStack(spacing: M.spazioTesto * 2) {
                    if nota.fissata {
                        Image(systemName: "pin.fill")
                            .font(Tipo.Mobile.etichetta)
                            .foregroundColor(Tema.Colore.accento)
                    }
                    Text(nota.titoloMostrato)
                        .font(Tipo.Mobile.rigaNome)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .lineLimit(1)
                }
                Text(nota.anteprima)
                    .font(Tipo.Mobile.rigaDettaglio)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(2)
                Text([stato.cliente(nota.clienteId)?.nome, Formati.dataBreve.string(from: nota.aggiornataIl)]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(Tipo.Mobile.rigaDettaglio)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(Tipo.Mobile.etichetta)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
        }
        .schedaTelefono()
    }
}

private struct DettaglioNotaTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let notaId: String

    var body: some View {
        let nota = stato.dati.note.first { $0.id == notaId }
        FondoTelefono {
            if let nota {
                VStack(alignment: .leading, spacing: M.spazioRiga) {
                    Text(nota.titoloMostrato)
                        .font(Tipo.Mobile.titolo)
                        .foregroundColor(Tema.Colore.inchiostro)
                    if let cliente = stato.cliente(nota.clienteId) {
                        DatoTelefono("Cliente", cliente.nome)
                    }
                    DatoTelefono("Aggiornata", Formati.dataBreve.string(from: nota.aggiornataIl))
                }
                .schedaTelefono()
                if !nota.testo.isEmpty {
                    Text(nota.testo)
                        .font(Tipo.Mobile.corpo)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .schedaTelefono()
                }
            } else {
                VuotoTelefono(testo: "Questa nota non c'è più nell'archivio.")
            }
        }
        .navigationTitle(nota?.titoloMostrato ?? "Nota")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Documenti

/// I documenti dei clienti (KID, polizze, estratti, prospetti), per cliente: prima quello in primo piano.
struct DocumentiTelefono: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let attivo = stato.clienteAttivoId
        let clienti = stato.clienti.sorted { a, b in
            a.id == attivo ? true : b.id == attivo ? false : a.nome.localizedCaseInsensitiveCompare(b.nome) == .orderedAscending
        }
        let documenti = stato.dati.documenti
        FondoTelefono {
            if documenti.isEmpty {
                VuotoTelefono(testo: "Nessun documento: si importano in Prisma sul Mac.")
            }
            ForEach(clienti) { cliente in
                let delCliente = documenti.filter { $0.clienteId == cliente.id }.sorted { $0.importatoIl > $1.importatoIl }
                if !delCliente.isEmpty {
                    SezioneTelefono(titolo: cliente.nome)
                    ForEach(delCliente) { documento in
                        RigaDocumentoTelefono(documento: documento)
                    }
                }
            }
        }
        .navigationTitle("Documenti")
    }
}

struct RigaDocumentoTelefono: View {
    @EnvironmentObject var stato: StatoShell
    let documento: Documento

    var body: some View {
        HStack(spacing: M.spazioRiga) {
            Image(systemName: documento.tipo.creatoDaPrisma ? "doc.richtext" : "doc.text")
                .font(Tipo.Mobile.titolo)
                .foregroundColor(Tema.Colore.accento)
                .frame(width: M.iconaLaterale)
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                Text(documento.titolo)
                    .font(Tipo.Mobile.rigaNome)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineLimit(2)
                Text(dettaglio)
                    .font(Tipo.Mobile.rigaDettaglio)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                if let canale = canale {
                    EtichettaCanale(canale: canale, compatta: true)
                }
            }
            Spacer(minLength: 0)
        }
        .schedaTelefono()
        .accessibilityElement(children: .combine)
    }

    private var dettaglio: String {
        var parti = [documento.tipo.breve, Formati.dataBreve.string(from: documento.importatoIl)]
        if documento.pagine > 0 { parti.append(documento.pagine == 1 ? "1 pagina" : "\(documento.pagine) pagine") }
        return parti.joined(separator: " · ")
    }

    /// Il canale della posizione collegata, se c'è: Alleanza o indipendente sempre riconoscibile.
    private var canale: Canale? {
        guard let id = documento.posizioneId else { return nil }
        return stato.posizioni.first { $0.id == id }?.canale
    }
}

// MARK: - Impostazioni

/// Impostazioni sull'iPhone: l'aspetto (chiaro, scuro, automatico), l'acqua della scrivania e la pioggia, poi
/// l'archivio (il backup dal Mac e quello da rimandare al Mac). Le altre scelte stanno in Prisma sul Mac.
struct ImpostazioniTelefono: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        FondoTelefono {
            SezioneTelefono(titolo: "Aspetto")
            VStack(alignment: .leading, spacing: M.spazioRiga) {
                scelta("Aspetto", sottotitolo: "Automatico segue l'iPhone, di giorno e di sera") {
                    Picker("Aspetto", selection: $stato.dati.impostazioni.aspetto) {
                        ForEach(AspettoInterfaccia.allCases) { Text($0.nome).tag($0) }
                    }
                }
                scelta("Sfondo", sottotitolo: "L'acqua della scrivania con le gocce al rallentatore") {
                    Picker("Sfondo", selection: $stato.dati.impostazioni.sfondoAnimato) {
                        Text("Animato").tag(true)
                        Text("Fermo").tag(false)
                    }
                }
                scelta("Pioggia", sottotitolo: stato.dati.impostazioni.sfondoAnimato ? "Quante gocce cadono sull'acqua"
                                                                                     : "Con lo sfondo fermo non piove") {
                    Picker("Pioggia", selection: $stato.dati.impostazioni.pioggia) {
                        ForEach(IntensitaPioggia.allCases) { Text($0.nome).tag($0) }
                    }
                    .disabled(!stato.dati.impostazioni.sfondoAnimato)
                }
            }
            .schedaTelefono()

            SezioneTelefono(titolo: "Eve")
            VStack(alignment: .leading, spacing: M.spazioRiga) {
                VStack(alignment: .leading, spacing: M.spazioTesto * 2) {
                    Text("Codice del Mac")
                        .font(Tipo.Mobile.rigaNome)
                        .foregroundColor(Tema.Colore.inchiostro)
                    Text(stato.dati.impostazioni.eve.ponte.abbinato
                         ? (stato.disponibilitaLocale.motivo ?? "Collegata: Eve risponde con Qwen del tuo Mac, in Wi‑Fi e cifrato")
                         : "Sul Mac apri Impostazioni › Eve, attiva «iPhone e iPad» e scrivi qui il codice che compare (arriva anche aprendo un backup del Mac)")
                        .font(Tipo.Mobile.rigaDettaglio)
                        .foregroundColor(stato.disponibilitaLocale.pronto ? Tema.Colore.Mobile.riuscita : Tema.Colore.inchiostroSecondario)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("ABCD-EFGH-JKLM", text: $stato.dati.impostazioni.eve.ponte.codice)
                        .font(Tipo.Mobile.rigaValore)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { stato.verificaMotoreLocale() }
                        .padding(.horizontal, M.margineRiga.leading)
                        .frame(height: M.altezzaControllo)
                        .background(RoundedRectangle(cornerRadius: Tema.Raggio.Mobile.riga, style: .continuous).fill(Tema.Colore.pozzetto))
                }
                Button { stato.verificaMotoreLocale() } label: {
                    Label("Collega al Mac", systemImage: "arrow.clockwise")
                        .font(Tipo.Mobile.pulsante)
                        .frame(maxWidth: .infinity, minHeight: M.altezzaControllo)
                }
                .buttonStyle(StileVetro())
            }
            .schedaTelefono()

            SezioneTelefono(titolo: "Archivio")
            ArchivioMobile()
        }
        .navigationTitle("Impostazioni")
    }

    private func scelta<C: View>(_ titolo: String, sottotitolo: String, @ViewBuilder _ controllo: () -> C) -> some View {
        VStack(alignment: .leading, spacing: M.spazioTesto * 2) {
            Text(titolo)
                .font(Tipo.Mobile.rigaNome)
                .foregroundColor(Tema.Colore.inchiostro)
            Text(sottotitolo)
                .font(Tipo.Mobile.rigaDettaglio)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .fixedSize(horizontal: false, vertical: true)
            controllo()
                .pickerStyle(.segmented)
        }
    }
}
#endif
