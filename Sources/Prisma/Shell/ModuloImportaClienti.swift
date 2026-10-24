import SwiftUI

/// L'anteprima dei contatti letti da un file: si sceglie chi importare (i doppioni partono esclusi)
/// e Prisma li aggiunge alla rubrica dopo un backup.
struct ModuloImportaClienti: View {
    @Environment(\.dismiss) var chiudi
    @EnvironmentObject var stato: StatoShell
    let importazione: ImportazioneClienti
    @State private var esclusi: Set<UUID>

    init(importazione: ImportazioneClienti) {
        self.importazione = importazione
        _esclusi = State(initialValue: Set(importazione.clienti.filter { $0.doppione != nil }.map(\.id)))
    }

    private var scelti: [ClienteImportato] { importazione.clienti.filter { !esclusi.contains($0.id) } }

    var body: some View {
        CorniceModulo(titolo: "Importa clienti") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Da «\(importazione.file)»: \(importazione.clienti.count) contatti"
                     + (importazione.colonne.isEmpty ? "." : ". Colonne riconosciute: \(importazione.colonne.map(\.nome).joined(separator: ", ")).")
                     + " Togli la spunta a chi non è un cliente; i doppioni partono esclusi.")
                    .font(Tipo.campoEtichetta)
                    .foregroundColor(Colori.Rubrica.secondario)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Tutti") { esclusi = [] }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                    Button("Nessuno") { esclusi = Set(importazione.clienti.map(\.id)) }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                    Spacer()
                }
                VStack(spacing: 0) {
                    ForEach(importazione.clienti) { c in
                        riga(c)
                    }
                }
                .overlay(Rectangle().strokeBorder(Colori.Analisi.tabellaBordo, lineWidth: 1))
            }
        } piede: {
            Text("Prima dell'importazione Prisma salva un backup.")
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Rubrica.secondario)
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button(scelti.count == 1 ? "Importa 1 cliente" : "Importa \(scelti.count) clienti") {
                stato.importaClienti(scelti)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(scelti.isEmpty || stato.solaLettura)
            .opacity(scelti.isEmpty ? 0.5 : 1)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Analisi.moduloImporta.width, height: Misure.Analisi.moduloImporta.height)
    }

    private func riga(_ c: ClienteImportato) -> some View {
        let incluso = !esclusi.contains(c.id)
        let dettagli = [c.telefono, c.email, c.dataNascita.map { "nato il \(Formati.dataBreve.string(from: $0))" } ?? "",
                        c.codiceFiscale, c.indirizzo].filter { !$0.isEmpty }.joined(separator: " · ")
        return Button {
            if incluso { esclusi.insert(c.id) } else { esclusi.remove(c.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: incluso ? "checkmark.square.fill" : "square")
                    .foregroundColor(incluso ? Colori.Analisi.navBasso : Colori.Analisi.kpiNota)
                AvatarCliente(iniziali: Cliente.iniziali(di: c.nome), tinta: TintaAvatar.blu.colori, lato: Misure.Rubrica.avatarElenco)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                    Text(dettagli.isEmpty ? "solo il nome" : dettagli).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let d = c.doppione {
                    Text(d).font(Tipo.chip).foregroundColor(Colori.Analisi.attenzioneTesto).lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .opacity(incluso ? 1 : 0.55)
        }
        .buttonStyle(StileSemplice())
        .bordoBasso(Colori.Analisi.tabellaRiga)
    }
}
