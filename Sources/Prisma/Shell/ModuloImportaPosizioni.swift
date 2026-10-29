import SwiftUI

/// L'anteprima delle posizioni lette da un CSV: abbinate ai clienti, con canale e area proposti.
/// Chi non è in rubrica si aggiunge come cliente nuovo (si può escludere); chi è già in Posizioni parte escluso.
struct ModuloImportaPosizioni: View {
    @Environment(\.dismiss) var chiudi
    @EnvironmentObject var stato: StatoShell
    let importazione: ImportazionePosizioni
    @State private var esclusi: Set<UUID>
    /// Il canale per le righe che non lo dicono (la compagnia non è Alleanza e manca la colonna).
    @State private var canale: Canale = .alleanza
    /// L'area corretta a mano, riga per riga.
    @State private var aree: [UUID: AreaPosizione] = [:]
    /// Aggiungere in rubrica i clienti che nel file ci sono e in Prisma no.
    @State private var creaClienti = true

    init(importazione: ImportazionePosizioni) {
        self.importazione = importazione
        _esclusi = State(initialValue: Set(importazione.posizioni.filter { $0.problema != nil }.map(\.id)))
    }

    private func finale(_ x: PosizioneImportata) -> Posizione {
        var p = x.posizione
        if let nuovo = x.nuovoCliente { p.clienteId = ImportaPosizioni.segnapostoNuovo(nuovo) }
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

    private func importabile(_ x: PosizioneImportata) -> Bool {
        !esclusi.contains(x.id) && (x.cliente != nil || (creaClienti && x.nuovoCliente != nil))
    }

    private var scelte: [Posizione] { importazione.posizioni.filter(importabile).map(finale) }

    /// I clienti nuovi, uno per codice fiscale o nome, solo per le righe scelte.
    private var nuoviClienti: [String: ClienteImportato] {
        guard creaClienti else { return [:] }
        var elenco: [String: ClienteImportato] = [:]
        for x in importazione.posizioni where importabile(x) {
            if let n = x.nuovoCliente { elenco[ImportaPosizioni.segnapostoNuovo(n)] = elenco[ImportaPosizioni.segnapostoNuovo(n)] ?? n }
        }
        return elenco
    }

    /// Quanti clienti nuovi ci sono nel file, scelti o no.
    private var clientiNelFile: Int {
        Set(importazione.posizioni.compactMap { $0.nuovoCliente.map(ImportaPosizioni.segnapostoNuovo) }).count
    }

    var body: some View {
        CorniceModulo(titolo: "Importa posizioni") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Da «\(importazione.file)»: \(importazione.posizioni.count) righe. Colonne riconosciute: \(importazione.colonne.map(\.nome).joined(separator: ", ")).")
                    .font(Tipo.campoEtichetta)
                    .foregroundColor(Colori.Rubrica.secondario)
                    .fixedSize(horizontal: false, vertical: true)
                if clientiNelFile > 0 {
                    Toggle(isOn: $creaClienti) {
                        Text(clientiNelFile == 1 ? "Aggiungi in rubrica il cliente che non c'è ancora"
                                                 : "Aggiungi in rubrica i \(clientiNelFile) clienti che non ci sono ancora")
                            .font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.testo)
                    }
                    .toggleStyle(.checkbox)
                }
                if importazione.posizioni.contains(where: { !$0.canaleDalFile }) {
                    HStack(spacing: 10) {
                        Text("Canale delle righe che non lo indicano")
                            .font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.testo)
                        SegmentiAnalisi(opzioni: [(Canale.alleanza, "Alleanza"), (.indipendente, "Indipendente")], selezione: $canale)
                            .frame(width: 240)
                    }
                }
                // Righe di posizioni già in Prisma, con i valori: si possono aggiornare invece di importarle
                let gia = importazione.posizioni.filter { $0.problema == ImportaPosizioni.giaPresente }.count
                if gia > 0 && importazione.colonne.contains(.controvalore) {
                    HStack(spacing: Tema.Misura.AggiornaValori.spazioComandi) {
                        Text(TestiAggiornaValori.bannerImportazione(gia))
                            .font(Tipo.campoEtichetta)
                            .foregroundColor(Colori.Rubrica.testo)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Tema.Misura.AggiornaValori.spazioComandi)
                        Button(TestiAggiornaValori.aggiornaLoroValori) {
                            stato.apriAggiornaValori(da: importazione)
                            chiudi()
                        }
                        .buttonStyle(StileVetro(margine: Tema.Misura.AggiornaValori.marginePulsante))
                        .fixedSize()
                    }
                    .padding(Tema.Misura.AggiornaValori.margineRiquadro)
                    .riquadroStrumento()
                }
                VStack(spacing: 0) {
                    ForEach(importazione.posizioni) { x in riga(x) }
                }
                .contornoTabella()
                Text("Quando il nome del prodotto corrisponde a una scheda di Prodotti, costi, rendimento e rischio vengono dalla scheda. Area e canale si possono correggere anche dopo, nella scheda di ogni posizione. Il controvalore entra con la data del file o di oggi: è il primo punto dell'andamento.")
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
                stato.importaPosizioni(scelte, nuoviClienti: nuoviClienti)
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
        let incluso = importabile(x)
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
            .disabled(x.cliente == nil && (x.nuovoCliente == nil || !creaClienti))
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
            } else if x.nuovoCliente != nil {
                Text(creaClienti ? "cliente nuovo" : "cliente non in rubrica")
                    .font(Tipo.chip).foregroundColor(creaClienti ? Colori.Analisi.kpiNota : Colori.Analisi.attenzioneTesto).lineLimit(1)
            } else if let scheda = x.prodotto {
                Text("dalla scheda «\(scheda)»").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
            }
            MenuTendina(selezione: Binding(get: { aree[x.id] ?? p.area }, set: { aree[x.id] = $0 }),
                        opzioni: AreaPosizione.allCases.map { ($0, $0.nome) },
                        stile: .carta, larghezza: 130)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .opacity(incluso ? 1 : 0.55)
        .bordoBasso(Colori.Analisi.tabellaRiga)
    }
}
