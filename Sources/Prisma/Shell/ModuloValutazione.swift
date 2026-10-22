import SwiftUI

/// Modulo di una valutazione d'investimento: premio, intestatari, ipotesi dei tre scenari e testi
/// del consulente. Le cifre le calcola Prisma; qui si scelgono le ipotesi e si scrive il perché.
struct ModuloValutazione: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.dismiss) var chiudi
    @State var bozza: ValutazioneInvestimento
    let nuova: Bool

    private static let numero = FloatingPointFormatStyle<Double>.number.locale(Formati.italiano)

    private var condizioni: CondizioniContratto? { stato.prodotto(bozza.prodottoId)?.condizioni }

    var body: some View {
        CorniceModulo(titolo: nuova ? "Nuova valutazione d'investimento" : "Modifica la valutazione") {
            VStack(alignment: .leading, spacing: 14) {
                CampoModulo(etichetta: "Prodotto") {
                    Picker("", selection: Binding(get: { bozza.prodottoId }, set: cambiaProdotto)) {
                        ForEach(stato.prodottiValutabili) { Text($0.nome).tag($0.id) }
                    }
                    .labelsHidden().frame(width: 300)
                }
                CampoModulo(etichetta: "Intestatari") {
                    TextField("Per esempio Marco ed Elena Bianchi", text: $bozza.intestatari).textFieldStyle(.roundedBorder)
                }
                CampoModulo(etichetta: "Premio unico") {
                    HStack(spacing: 6) {
                        TextField("", value: $bozza.premio, format: Self.numero).textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing).frame(width: 110)
                        Text("€").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                    }
                }
                CampoModulo(etichetta: "Data del documento") {
                    DatePicker("", selection: $bozza.data, displayedComponents: .date).labelsHidden().frame(width: 140)
                }
                CampoModulo(etichetta: "Anni di riscatto") {
                    Stepper(value: $bozza.anni, in: 2...10) {
                        Text("dal \((bozza.anni > 0 ? 2 : 1))° al \(bozza.anni + 1)° anno").font(Tipo.campoValore)
                    }
                }
                CampoModulo(etichetta: "Perché investe") {
                    VStack(alignment: .leading, spacing: 3) {
                        CampoTestoLungo(testo: $bozza.esigenza)
                        Text("Apre la seconda pagina del report. Per esempio: «Volete far crescere € 50.000, ma potreste averne bisogno già tra uno o due anni.»")
                            .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let c = condizioni {
                    ForEach(TipoScenario.allCases) { t in scenario(t, c) }
                }
                CampoModulo(etichetta: "Scenario centrale") {
                    VStack(alignment: .leading, spacing: 3) {
                        CampoTestoLungo(testo: $bozza.notaScenarioCentrale)
                        Text("Perché lo scenario intermedio usa quel rendimento (riquadro della terza pagina del report).")
                            .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    }
                }
                CampoModulo(etichetta: "Il tuo consiglio") {
                    VStack(alignment: .leading, spacing: 3) {
                        CampoTestoLungo(testo: $bozza.consiglio)
                        Text("Se lo lasci vuoto, Prisma propone una frase ricavata dai numeri del primo riscatto.")
                            .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    }
                }
            }
        } piede: {
            if !nuova {
                Button("Elimina") {
                    stato.eliminaValutazione(bozza.id)
                    chiudi()
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
            }
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button(nuova ? "Crea" : "Salva") {
                var v = bozza
                v.intestatari = v.intestatari.trimmingCharacters(in: .whitespacesAndNewlines)
                stato.salvaValutazione(v)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(bozza.premio <= 0 || bozza.intestatari.trimmingCharacters(in: .whitespaces).isEmpty || condizioni == nil)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Analisi.modulo.width, height: Misure.Analisi.modulo.height)
    }

    private func cambiaProdotto(_ id: String) {
        bozza.prodottoId = id
        if let c = stato.prodotto(id)?.condizioni { bozza.scenari = ValutazioneInvestimento.ipotesiDiPartenza(c) }
    }

    /// Le valutazioni hanno sempre i tre scenari (anche quelle lette dall'archivio).
    private func indice(_ t: TipoScenario) -> Int {
        bozza.scenari.firstIndex { $0.tipo == t } ?? 0
    }

    private func scenario(_ t: TipoScenario, _ c: CondizioniContratto) -> some View {
        let i = indice(t)
        return CampoModulo(etichetta: "Scenario \(t.nome.lowercased())") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(c.componenti) { p in
                    HStack(spacing: 6) {
                        Text(p.tipo == .gestioneSeparata ? "Gestione separata, lordo" : "Fondo Interno, netto")
                            .font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario).frame(width: 160, alignment: .leading)
                        TextField("", value: Binding(get: { bozza.scenari[i].rendimenti[p.id] ?? 0 },
                                                     set: { bozza.scenari[i].rendimenti[p.id] = $0 }), format: Self.numero)
                            .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 70)
                        Text("% l'anno").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                    }
                }
                TextField("Perché questa ipotesi (prospetto, pagina 4)", text: $bozza.scenari[i].perche, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...3)
                TextField("Come va, in una frase per il cliente (report)", text: $bozza.scenari[i].racconto, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...3)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 4).fill(Colori.Documento.prisma.scenarioFondo(t)))
        }
    }
}
