import SwiftUI

/// L'anteprima delle posizioni lette da un CSV: abbinate ai clienti, con canale e area proposti.
/// Chi non ha un cliente in rubrica, o è già in Posizioni, parte escluso.
struct ModuloImportaPosizioni: View {
    @Environment(\.dismiss) var chiudi
    @EnvironmentObject var stato: StatoShell
    let importazione: ImportazionePosizioni
    @State private var esclusi: Set<UUID>
    /// Il canale per le righe che non lo dicono (la compagnia non è Alleanza e manca la colonna).
    @State private var canale: Canale = .alleanza
    /// L'area corretta a mano, riga per riga.
    @State private var aree: [UUID: AreaPosizione] = [:]

    init(importazione: ImportazionePosizioni) {
        self.importazione = importazione
        _esclusi = State(initialValue: Set(importazione.posizioni.filter { $0.problema != nil }.map(\.id)))
    }

    private func finale(_ x: PosizioneImportata) -> Posizione {
        var p = x.posizione
        if !x.canaleDalFile {
            p.canale = canale
            if canale == .indipendente, p.emittente == "Alleanza Assicurazioni" { p.emittente = "" }
        }
        if let a = aree[x.id] {
            p.area = a
            p.rischio = a == .protezione ? (p.rischio ?? ImportaPosizioni.rischio(p.nome + " " + p.tipologia)) : nil
        }
        return p
    }

    private var scelte: [Posizione] {
        importazione.posizioni.filter { !esclusi.contains($0.id) && $0.cliente != nil }.map(finale)
    }

    var body: some View {
        CorniceModulo(titolo: "Importa posizioni") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Da «\(importazione.file)»: \(importazione.posizioni.count) righe. Colonne riconosciute: \(importazione.colonne.map(\.nome).joined(separator: ", ")).")
                    .font(Tipo.campoEtichetta)
                    .foregroundColor(Colori.Rubrica.secondario)
                    .fixedSize(horizontal: false, vertical: true)
                if importazione.posizioni.contains(where: { !$0.canaleDalFile }) {
                    HStack(spacing: 10) {
                        Text("Canale delle righe che non lo indicano")
                            .font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.testo)
                        SegmentiAnalisi(opzioni: [(Canale.alleanza, "Alleanza"), (.indipendente, "Indipendente")], selezione: $canale)
                            .frame(width: 240)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(importazione.posizioni) { x in riga(x) }
                }
                .overlay(Rectangle().strokeBorder(Colori.Analisi.tabellaBordo, lineWidth: 1))
                Text("Area e canale si possono correggere anche dopo, nella scheda di ogni posizione. Il controvalore entra con la data del file o di oggi: è il primo punto dell'andamento.")
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } piede: {
            Text("Prima dell'importazione Prisma salva un backup.")
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Rubrica.secondario)
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button(scelte.count == 1 ? "Importa 1 posizione" : "Importa \(scelte.count) posizioni") {
                stato.importaPosizioni(scelte)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(scelte.isEmpty || stato.solaLettura)
            .opacity(scelte.isEmpty ? 0.5 : 1)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Analisi.moduloImportaPosizioni.width, height: Misure.Analisi.moduloImportaPosizioni.height)
    }

    private func riga(_ x: PosizioneImportata) -> some View {
        let p = finale(x)
        let incluso = !esclusi.contains(x.id) && x.cliente != nil
        let cifre = [p.numeroContratto.isEmpty ? "" : "n. \(p.numeroContratto)",
                     p.controvalore.map { "valore \(Formati.euro($0))" } ?? "",
                     p.premioAnnuo > 0 ? "\(Formati.euro(p.premio)) \(p.frequenza.nome.lowercased())" : "",
                     p.scadenza.map { "scade il \(Formati.dataBreve.string(from: $0))" } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
        return HStack(spacing: 10) {
            Button {
                if esclusi.contains(x.id) { esclusi.remove(x.id) } else { esclusi.insert(x.id) }
            } label: {
                Image(systemName: incluso ? "checkmark.square.fill" : "square")
                    .foregroundColor(incluso ? Colori.Analisi.navBasso : Colori.Analisi.kpiNota)
            }
            .buttonStyle(StileSemplice())
            .disabled(x.cliente == nil)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(p.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                    EtichettaCanale(canale: p.canale, compatta: true)
                }
                Text((x.cliente?.nome ?? x.clienteNelFile) + (cifre.isEmpty ? "" : " · " + cifre))
                    .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let problema = x.problema {
                Text(problema).font(Tipo.chip).foregroundColor(Colori.Analisi.attenzioneTesto).lineLimit(1)
            }
            Picker("", selection: Binding(get: { aree[x.id] ?? p.area }, set: { aree[x.id] = $0 })) {
                ForEach(AreaPosizione.allCases) { Text($0.nome).tag($0) }
            }
            .labelsHidden()
            .frame(width: 130)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .opacity(incluso ? 1 : 0.55)
        .bordoBasso(Colori.Analisi.tabellaRiga)
    }
}
