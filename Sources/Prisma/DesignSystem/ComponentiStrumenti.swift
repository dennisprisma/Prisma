import SwiftUI

// MARK: - Cornice degli strumenti di analisi

/// Struttura comune di Posizioni, Simulazioni, Confronti e Analisi 360:
/// elenco laterale ardesia, area di lavoro bianca, barra di stato in basso.
struct CorniceStrumento<Rail: View, Contenuto: View>: View {
    let notaStato: String
    var notaDestra = ""
    @ViewBuilder let rail: () -> Rail
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    rail()
                    Spacer(minLength: 0)
                    ArchivioLocaleRail()
                }
                .padding(Misure.Analisi.margineRail)
                .frame(width: Misure.Analisi.rail)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Gradienti.railAnalisi)
                .bordoDestro(Colori.Analisi.kpiBordo)
                contenuto()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Colori.Analisi.principale)
            }
            HStack(spacing: 10) {
                Circle().fill(Colori.Analisi.statoLuce).frame(width: 8, height: 8)
                Text(notaStato).lineLimit(1)
                Spacer()
                Text(notaDestra).lineLimit(1)
            }
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Analisi.kpiNota)
            .incisione(.white)
            .padding(.horizontal, 12)
            .frame(height: Misure.Analisi.barraStato)
            .background(Gradienti.barraStato)
            .bordoAlto(Colori.Analisi.statoBordo)
        }
        .overlay(Rectangle().strokeBorder(Colori.Analisi.kpiBordo, lineWidth: 1))
    }
}

/// "Dossier di …" in cima all'elenco laterale, con la scelta del cliente.
struct DossierRail: View {
    @EnvironmentObject var stato: StatoShell
    @State var scelta = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DOSSIER DI").font(Tipo.railEtichetta).foregroundColor(Colori.Analisi.railEtichetta)
            Button { scelta = true } label: {
                HStack(spacing: 5) {
                    Text(stato.clienteAttivo?.nome ?? "Nessun cliente").font(Tipo.railTitolo)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Colori.Analisi.railTesto)
            }
            .buttonStyle(StileSemplice())
            .popover(isPresented: $scelta, arrowEdge: .trailing) { ElencoClienti(aperto: $scelta) }
            Text(stato.clienteAttivo?.tema ?? "").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
        }
        .incisione(.white)
        .padding(EdgeInsets(top: 9, leading: 2, bottom: 9, trailing: 2))
        .frame(maxWidth: .infinity, alignment: .leading)
        .bordoBasso(Colori.Analisi.railFilo)
    }
}

struct ArchivioLocaleRail: View {
    var body: some View {
        HStack(spacing: 8) {
            SimboloLucchetto()
                .stroke(Colori.Analisi.railEtichetta, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 15, height: 15)
            VStack(alignment: .leading, spacing: 1) {
                Text("ARCHIVIO LOCALE").font(Tipo.chip).foregroundColor(Colori.Analisi.railEtichetta)
                Text("Solo su questo Mac").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.railTesto)
            }
        }
        .incisione(.white)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bordoAlto(Colori.Analisi.railFilo)
    }
}

/// Collegamenti alle altre app di analisi, in fondo all'elenco laterale.
struct CollegatiRail: View {
    @EnvironmentObject var stato: StatoShell
    let app: [AppPrisma]

    var body: some View {
        EtichettaRail(testo: "Collegati")
        VStack(spacing: 0) {
            ForEach(app) { a in
                VoceNavigazione(titolo: a.titolo, attiva: false) { stato.apri(a) }
            }
        }
    }
}

// MARK: - Intestazioni e testi

/// Occhiello, titolo e sottotitolo di una pagina di risultati (.plan-result-top).
struct TitoloStrumento: View {
    let occhiello: String
    let titolo: String
    var testo: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(occhiello.uppercased())
                .font(Tipo.strumentoOcchiello)
                .tracking(0.4)
                .foregroundColor(Colori.Strumenti.occhiello)
            Text(titolo)
                .font(Tipo.strumentoTitolo)
                .foregroundColor(Colori.Strumenti.titolo)
            if let testo {
                Text(testo)
                    .font(Tipo.strumentoTesto)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .incisione(.white)
    }
}

/// Riquadro color crema con il metodo di calcolo o un'avvertenza (.plan-method-note).
struct NotaMetodo: View {
    let testo: String
    var titolo: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let titolo {
                Text(titolo.uppercased()).font(Tipo.chip).tracking(0.5)
            }
            Text(testo)
                .font(Tipo.metodo)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(Colori.Strumenti.metodoTesto)
        .padding(EdgeInsets(top: 9, leading: 11, bottom: 9, trailing: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 2).fill(Colori.Strumenti.metodoFondo))
        .luceInterna(.white, raggio: 2)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Colori.Strumenti.metodoBordo, lineWidth: 1))
    }
}

/// Voce della legenda di un grafico.
struct LegendaLinea: View {
    let colore: Color
    let testo: String
    var tratteggio = false

    var body: some View {
        HStack(spacing: 6) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 4))
                p.addLine(to: CGPoint(x: 18, y: 4))
            }
            .stroke(colore, style: StrokeStyle(lineWidth: 2, dash: tratteggio ? [4, 3] : []))
            .frame(width: 18, height: 8)
            Text(testo).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
        }
    }
}

/// Schede dei risultati (.plan-result-nav): Sintesi, Coperture, Metodo…
struct SchedeRisultati<Valore: Hashable, Destra: View>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore
    @ViewBuilder let destra: () -> Destra

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(opzioni.enumerated()), id: \.offset) { _, o in
                let attiva = o.0 == selezione
                Button { selezione = o.0 } label: {
                    Text(o.1)
                        .font(Tipo.schedaRisultati)
                        .foregroundColor(attiva ? Colori.Strumenti.schedaAttivaTesto : Colori.Strumenti.schedaTesto)
                        .incisione(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background {
                            if attiva {
                                RoundedRectangle(cornerRadius: 3).fill(Gradienti.schedaRisultatiAttiva)
                                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Strumenti.schedaAttivaBordo, lineWidth: 1))
                            }
                        }
                }
                .buttonStyle(StileSemplice())
            }
            Spacer(minLength: 0)
            destra()
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Gradienti.schedeRisultati)
        .luceInterna(.white)
        .bordoBasso(Colori.Strumenti.schedeBordo)
    }
}

// MARK: - Campi delle ipotesi

/// Riga del pannello delle ipotesi: etichetta, campo numerico, unità (.plan-input).
struct CampoIpotesi: View {
    let etichetta: String
    @Binding var valore: Double
    var unita = "€"
    var nota: String? = nil
    var intervallo: ClosedRange<Double> = 0...1_000_000_000

    private static let formato = FloatingPointFormatStyle<Double>.number.locale(Formati.italiano).precision(.fractionLength(0...2))

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(etichetta).font(Tipo.ipotesiCampo).foregroundColor(Colori.Strumenti.ipotesiTesto)
                if let nota {
                    Text(nota).font(Tipo.ipotesiNota).foregroundColor(Colori.Strumenti.ipotesiNota)
                }
            }
            Spacer(minLength: 4)
            TextField("", value: Binding(get: { valore },
                                         set: { valore = min(max($0, intervallo.lowerBound), intervallo.upperBound) }),
                      format: Self.formato)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: Misure.Strumenti.campo)
            Text(unita)
                .font(Tipo.ipotesiNota)
                .foregroundColor(Colori.Strumenti.ipotesiNota)
                .frame(width: 34, alignment: .leading)
        }
        .padding(.vertical, 6)
        .bordoBasso(Colori.Strumenti.ipotesiRiga)
    }
}

/// Variante intera di CampoIpotesi (anni, età, mesi).
struct CampoIpotesiIntero: View {
    let etichetta: String
    @Binding var valore: Int
    var unita = "anni"
    var nota: String? = nil
    var intervallo: ClosedRange<Int> = 0...100

    var body: some View {
        CampoIpotesi(etichetta: etichetta,
                     valore: Binding(get: { Double(valore) },
                                     set: { valore = min(max(Int($0.rounded()), intervallo.lowerBound), intervallo.upperBound) }),
                     unita: unita, nota: nota,
                     intervallo: Double(intervallo.lowerBound)...Double(intervallo.upperBound))
    }
}

// MARK: - Tabelle

/// Cella d'intestazione di una tabella (.plan-table thead).
struct CellaTesta: View {
    let testo: String
    var larghezza: CGFloat? = nil
    var destra = false

    var body: some View {
        Text(testo)
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
            .incisione(.white)
            .lineLimit(1)
            .padding(Misure.Analisi.testaMargine)
            .frame(maxWidth: larghezza == nil ? .infinity : nil, alignment: destra ? .trailing : .leading)
            .frame(width: larghezza, alignment: destra ? .trailing : .leading)
    }
}

/// Cella di una tabella, testo o numero.
struct CellaTabella: View {
    let testo: String
    var larghezza: CGFloat? = nil
    var destra = false
    var forte = false
    var colore = Colori.Analisi.tabellaTesto

    var body: some View {
        Text(testo)
            .font(destra ? Tipo.numeroTabella : (forte ? Tipo.tabellaCellaForte : Tipo.tabellaCella))
            .foregroundColor(colore)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(Misure.Analisi.cellaMargine)
            .frame(maxWidth: larghezza == nil ? .infinity : nil, alignment: destra ? .trailing : .leading)
            .frame(width: larghezza, alignment: destra ? .trailing : .leading)
    }
}

/// Tabella a righe alternate con intestazione grigia.
struct TabellaStrumento<Testa: View, Righe: View>: View {
    @ViewBuilder let testa: () -> Testa
    @ViewBuilder let righe: () -> Righe

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) { testa() }
                .background(Gradienti.testaTabella)
                .bordoBasso(Colori.Analisi.tabellaTestaBordo)
            righe()
        }
        .overlay(Rectangle().strokeBorder(Colori.Analisi.tabellaBordo, lineWidth: 1))
    }
}

/// Una riga di TabellaStrumento.
struct RigaStrumento<Contenuto: View>: View {
    let indice: Int
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        HStack(spacing: 0) { contenuto() }
            .background(indice % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
            .bordoBasso(Colori.Analisi.tabellaRiga)
    }
}

// MARK: - Display a cristalli liquidi

/// Valore del simulatore in un display verde a cristalli liquidi (.fin-value-control).
struct DisplayLCD: View {
    @Binding var valore: Double
    let unita: String
    let intervallo: ClosedRange<Double>
    var decimali = 0

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: Binding(get: { valore },
                                         set: { valore = min(max($0, intervallo.lowerBound), intervallo.upperBound) }),
                      format: FloatingPointFormatStyle<Double>.number.locale(Formati.localeImporti)
                        .precision(.fractionLength(0...decimali)))
                .textFieldStyle(.plain)
                .font(Tipo.lcd)
                .foregroundColor(Colori.Strumenti.lcdTesto)
                .multilineTextAlignment(.trailing)
                .shadow(color: Colori.Strumenti.lcdLuce, radius: 0, x: 0, y: 1)
            Text(unita)
                .font(Tipo.lcdUnita)
                .foregroundColor(Colori.Strumenti.lcdTesto.opacity(0.8))
        }
        .padding(.horizontal, 7)
        .frame(width: Misure.Strumenti.lcd.width, height: Misure.Strumenti.lcd.height)
        .background(RoundedRectangle(cornerRadius: Misure.Strumenti.raggio).fill(Gradienti.lcd))
        .overlay(alignment: .top) {
            LinearGradient(colors: [Colori.Strumenti.lcdOmbra, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 4)
                .clipShape(RoundedRectangle(cornerRadius: Misure.Strumenti.raggio))
                .allowsHitTesting(false)
        }
        .overlay(RoundedRectangle(cornerRadius: Misure.Strumenti.raggio).strokeBorder(Colori.Strumenti.lcdBordo, lineWidth: 1))
        .shadow(color: .white, radius: 0, x: 0, y: 1)
    }
}

/// Un comando del simulatore: etichetta, display e cursore (.fin-control).
struct ComandoSimulatore: View {
    let etichetta: String
    @Binding var valore: Double
    let unita: String
    let intervallo: ClosedRange<Double>
    let passo: Double
    var decimali = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(etichetta)
                    .font(Tipo.consoleEtichetta)
                    .foregroundColor(Colori.Strumenti.consoleEtichetta)
                    .incisione(.white)
                Spacer(minLength: 6)
                DisplayLCD(valore: $valore, unita: unita, intervallo: intervallo, decimali: decimali)
            }
            Slider(value: Binding(get: { min(max(valore, intervallo.lowerBound), intervallo.upperBound) },
                                  set: { valore = ($0 / passo).rounded() * passo }),
                   in: intervallo)
                .controlSize(.small)
        }
    }
}
