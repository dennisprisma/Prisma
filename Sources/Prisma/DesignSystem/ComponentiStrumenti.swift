import SwiftUI

// MARK: - Gettoni degli strumenti di analisi

extension Tema.Misura.Componenti {
    /// Barra laterale staccata dentro la finestra (.side): margini interni e stacco dai bordi.
    static let margineLaterale = EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)
    static let staccoLaterale = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0)
    /// Barra di stato in fondo: spia e margine laterale.
    static let spiaStato: CGFloat = 7
    static let margineBarraStato: CGFloat = 14
    /// Barra delle schede dei risultati.
    static let barraSchede: CGFloat = 44
    static let margineSchede: CGFloat = 12
    /// Campo numerico delle ipotesi.
    static let campoNumerico: CGFloat = 28
    static let margineCampoNumerico: CGFloat = 8
    /// Scheda della tabella (.tbl dentro una .card): margini attorno alle righe.
    static let margineTabella = EdgeInsets(top: 6, leading: 6, bottom: 4, trailing: 6)
    /// Riquadro della nota sul metodo.
    static let notaMetodo = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
    /// Il lucchetto dell'archivio locale.
    static let lucchetto: CGFloat = 13
}

extension Tema.Testo.Componenti {
    /// Occhiello delle pagine (.app-h: 12/500).
    static let occhielloPagina = Tema.Testo.sf(12, .medium)
    /// Cifre nelle tabelle e nei campi.
    static let numero = Tema.Testo.sf(13).monospacedDigit()
    /// Cifra grande del simulatore.
    static let numeroGrande = Tema.Testo.sf(15, .semibold).monospacedDigit()
}

// MARK: - Cornice degli strumenti di analisi

/// Struttura comune di Posizioni, Simulazioni, Confronti e Analisi 360: barra laterale staccata in vetro,
/// area di lavoro sul vetro della finestra, barra di stato in basso.
struct CorniceStrumento<Rail: View, Contenuto: View>: View {
    let notaStato: String
    var notaDestra = ""
    @ViewBuilder let rail: () -> Rail
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        let m = Tema.Misura.Componenti.self
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    // L'elenco scorre se è lungo: la finestra non si allunga mai sotto il dock
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) { rail() }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ArchivioLocaleRail()
                }
                .padding(m.margineLaterale)
                .frame(width: Misure.Analisi.rail)
                .frame(maxHeight: .infinity, alignment: .top)
                .vetro(.laterale, forma: .arrotondata(Tema.Raggio.laterale))
                .padding(m.staccoLaterale)
                contenuto()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 8) {
                Circle().fill(Tema.Colore.verde).frame(width: m.spiaStato, height: m.spiaStato)
                Text(notaStato).lineLimit(1)
                Spacer()
                Text(notaDestra).lineLimit(1)
            }
            .font(Tema.Testo.didascalia)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .padding(.horizontal, m.margineBarraStato)
            .frame(height: Misure.Analisi.barraStato)
            .overlay(alignment: .top) {
                Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
            }
        }
    }
}

/// "Dossier di …" in cima all'elenco laterale, con la scelta del cliente.
struct DossierRail: View {
    @EnvironmentObject var stato: StatoShell
    @State var scelta = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Dossier di").font(Tema.Testo.occhiello).foregroundColor(Tema.Colore.inchiostroTerziario)
            Button { scelta = true } label: {
                HStack(spacing: 5) {
                    Text(stato.clienteAttivo?.nome ?? "Nessun cliente").font(Tema.Testo.titolo)
                    Image(systemName: "chevron.down").font(Tema.Testo.Componenti.frecciaTendina)
                }
                .foregroundColor(Tema.Colore.inchiostro)
            }
            .buttonStyle(StileSemplice())
            .popover(isPresented: $scelta, arrowEdge: .trailing) { ElencoClienti(aperto: $scelta) }
            Text(stato.clienteAttivo?.tema ?? "")
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 9, trailing: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
        }
    }
}

/// In fondo all'elenco laterale: i dati restano su questo Mac.
struct ArchivioLocaleRail: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
                .frame(width: Tema.Misura.Componenti.lucchetto)
            VStack(alignment: .leading, spacing: 1) {
                Text("Archivio locale").font(Tema.Testo.occhiello).foregroundColor(Tema.Colore.inchiostroSecondario)
                Text("Solo su questo Mac").font(Tema.Testo.didascalia).foregroundColor(Tema.Colore.inchiostroTerziario)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
        }
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
                VoceNavigazione(titolo: a.titolo, attiva: false) {
                    // Dalle app del cliente, Posizioni apre il suo dossier (non il portafoglio)
                    if a == .posizioni { stato.portafoglio = false }
                    stato.apri(a)
                }
            }
        }
    }
}

// MARK: - Intestazioni e testi

/// Occhiello, titolo e sottotitolo di una pagina di risultati (.app-h del tema).
struct TitoloStrumento: View {
    let occhiello: String
    let titolo: String
    var testo: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(occhiello)
                .font(Tema.Testo.Componenti.occhielloPagina)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
            Text(titolo)
                .font(Tema.Testo.titoloImpostazioni)
                .tracking(Tema.Testo.spaziaturaTitoloMedio)
                .foregroundColor(Tema.Colore.inchiostro)
            if let testo {
                Text(testo)
                    .font(Tema.Testo.corpo)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Riquadro con il metodo di calcolo o un'avvertenza: pozzetto arrotondato, testo secondario.
struct NotaMetodo: View {
    let testo: String
    var titolo: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let titolo {
                Text(titolo).font(Tema.Testo.occhiello).foregroundColor(Tema.Colore.inchiostro)
            }
            Text(testo)
                .font(Tema.Testo.secondario)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tema.Misura.Componenti.notaMetodo)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FormaVetro.arrotondata(Tema.Raggio.tessera).fill(Tema.Colore.pozzetto) }
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
            .stroke(colore, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: tratteggio ? [4, 3] : []))
            .frame(width: 18, height: 8)
            Text(testo).font(Tema.Testo.didascalia).foregroundColor(Tema.Colore.inchiostroSecondario)
        }
    }
}

/// Schede dei risultati (Sintesi, Coperture, Metodo…): controllo a segmenti del tema e, a destra, gli strumenti.
struct SchedeRisultati<Valore: Hashable, Destra: View>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore
    @ViewBuilder let destra: () -> Destra

    var body: some View {
        HStack(spacing: 8) {
            ControlloSegmenti(opzioni: opzioni, selezione: $selezione)
            Spacer(minLength: 0)
            destra()
        }
        .padding(.horizontal, Tema.Misura.Componenti.margineSchede)
        .frame(height: Tema.Misura.Componenti.barraSchede)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
        }
    }
}

// MARK: - Campi delle ipotesi

/// Riga del pannello delle ipotesi: etichetta, campo numerico in pozzetto, unità.
struct CampoIpotesi: View {
    let etichetta: String
    @Binding var valore: Double
    var unita = "€"
    var nota: String? = nil
    var intervallo: ClosedRange<Double> = 0...1_000_000_000

    private static let formato = FloatingPointFormatStyle<Double>.number.locale(Formati.localeImporti).precision(.fractionLength(0...2))

    var body: some View {
        let m = Tema.Misura.Componenti.self
        let forma = FormaVetro.arrotondata(Tema.Raggio.miniatura)
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(etichetta).font(Tema.Testo.corpo).foregroundColor(Tema.Colore.inchiostro)
                if let nota {
                    Text(nota).font(Tema.Testo.didascalia).foregroundColor(Tema.Colore.inchiostroSecondario)
                }
            }
            Spacer(minLength: 4)
            TextField("", value: Binding(get: { valore },
                                         set: { valore = min(max($0, intervallo.lowerBound), intervallo.upperBound) }),
                      format: Self.formato)
                .textFieldStyle(.plain)
                .font(Tema.Testo.Componenti.numero)
                .foregroundColor(Tema.Colore.inchiostro)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, m.margineCampoNumerico)
                .frame(width: Misure.Strumenti.campo, height: m.campoNumerico)
                .background { forma.fill(Tema.Colore.pozzetto) }
                .overlay { forma.strokeBorder(Tema.Colore.separatore, lineWidth: Tema.Misura.filo).allowsHitTesting(false) }
            Text(unita)
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: Misure.Strumenti.unita, alignment: .leading)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
        }
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

/// Cella d'intestazione di una tabella (.tbl th: 11,5/600, inchiostro secondario).
struct CellaTesta: View {
    let testo: String
    var larghezza: CGFloat? = nil
    var destra = false

    var body: some View {
        Text(testo)
            .font(Tema.Testo.occhiello)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .lineLimit(1)
            .padding(Misure.Analisi.testaMargine)
            .frame(maxWidth: larghezza == nil ? .infinity : nil, alignment: destra ? .trailing : .leading)
            .frame(width: larghezza, alignment: destra ? .trailing : .leading)
    }
}

/// Cella di una tabella, testo o numero (i numeri a destra, cifre tabellari).
struct CellaTabella: View {
    let testo: String
    var larghezza: CGFloat? = nil
    var destra = false
    var forte = false
    var colore: Color = Tema.Colore.inchiostro

    var body: some View {
        Text(testo)
            .font(destra ? Tema.Testo.Componenti.numero : (forte ? Tema.Testo.titolo : Tema.Testo.corpo))
            .foregroundColor(colore)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(Misure.Analisi.cellaMargine)
            .frame(maxWidth: larghezza == nil ? .infinity : nil, alignment: destra ? .trailing : .leading)
            .frame(width: larghezza, alignment: destra ? .trailing : .leading)
    }
}

/// Tabella del tema (.tbl): dentro una scheda, intestazione senza fondo, separatori sottili.
struct TabellaStrumento<Testa: View, Righe: View>: View {
    @ViewBuilder let testa: () -> Testa
    @ViewBuilder let righe: () -> Righe

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) { testa() }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
                }
            righe()
        }
        .padding(Tema.Misura.Componenti.margineTabella)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.scheda))
    }
}

/// Una riga di TabellaStrumento: separatore sottile, fondo leggero al passaggio del mouse.
struct RigaStrumento<Contenuto: View>: View {
    let indice: Int
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        HStack(spacing: 0) { contenuto() }
            .fondoPassaggio(.arrotondata(Tema.Raggio.tasto), sopra: Tema.Colore.rigaSopra)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
            }
    }
}

// MARK: - Valori del simulatore

/// Valore del simulatore in un campo numerico grande, in pozzetto.
struct DisplayLCD: View {
    @Binding var valore: Double
    let unita: String
    let intervallo: ClosedRange<Double>
    var decimali = 0

    var body: some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.miniatura)
        HStack(spacing: 4) {
            TextField("", value: Binding(get: { valore },
                                         set: { valore = min(max($0, intervallo.lowerBound), intervallo.upperBound) }),
                      format: FloatingPointFormatStyle<Double>.number.locale(Formati.localeImporti)
                        .precision(.fractionLength(0...decimali)))
                .textFieldStyle(.plain)
                .font(Tema.Testo.Componenti.numeroGrande)
                .foregroundColor(Tema.Colore.inchiostro)
                .multilineTextAlignment(.trailing)
            Text(unita)
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
        }
        .padding(.horizontal, Tema.Misura.Componenti.margineCampoNumerico)
        .frame(width: Misure.Strumenti.lcd.width, height: max(Misure.Strumenti.lcd.height, Tema.Misura.Componenti.campoNumerico))
        .background { forma.fill(Tema.Colore.pozzetto) }
        .overlay { forma.strokeBorder(Tema.Colore.separatore, lineWidth: Tema.Misura.filo).allowsHitTesting(false) }
    }
}

/// Un comando del simulatore: etichetta, valore e cursore.
struct ComandoSimulatore: View {
    let etichetta: String
    @Binding var valore: Double
    let unita: String
    let intervallo: ClosedRange<Double>
    let passo: Double
    var decimali = 0
    /// Fine corsa del cursore, se più corta dell'intervallo (il valore accetta comunque tutto l'intervallo).
    var fineCursore: Double? = nil

    var body: some View {
        let corsa = intervallo.lowerBound...min(fineCursore ?? intervallo.upperBound, intervallo.upperBound)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(etichetta)
                    .font(Tema.Testo.corpo)
                    .foregroundColor(Tema.Colore.inchiostro)
                Spacer(minLength: 6)
                DisplayLCD(valore: $valore, unita: unita, intervallo: intervallo, decimali: decimali)
            }
            Slider(value: Binding(get: { min(max(valore, corsa.lowerBound), corsa.upperBound) },
                                  set: { valore = ($0 / passo).rounded() * passo }),
                   in: corsa)
                .controlSize(.small)
        }
    }
}
