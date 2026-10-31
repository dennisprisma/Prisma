#if os(macOS)
import AppKit
import SwiftUI

/// La mini finestra di Eve (Design/eve-mini.html): una sola superficie di vetro che cambia forma.
/// Capsula 440 × 72 mentre ascolta, pensa o si sveglia; scheda 460, alta quanto serve, quando risponde e per scrivere.
/// Il passaggio è una molla di 0,55 s (con «Riduci movimento» una dissolvenza breve).
struct VistaMiniEve: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mini: StatoMiniEve
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea
    /// Entrata e uscita (opacità, un po' più in alto e più piccola).
    @State private var mostrata = false

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        superficie
            .padding(EdgeInsets(top: m.margineOmbraSopra, leading: m.margineOmbraLati, bottom: m.margineOmbraSotto, trailing: m.margineOmbraLati))
            .frame(width: m.larghezzaScheda + 2 * m.margineOmbraLati, alignment: .topTrailing)
            .frame(maxHeight: .infinity, alignment: .top)
            .onAppear {
                guard !modoIstantanea else { return mostrata = mini.visibile }
                withAnimation(movimentoRidotto ? Tema.Moto.MiniEve.ridotto : Tema.Moto.MiniEve.entrata) { mostrata = mini.visibile }
            }
            .onChange(of: mini.visibile) { v in
                withAnimation(v ? (movimentoRidotto ? Tema.Moto.MiniEve.ridotto : Tema.Moto.MiniEve.entrata) : Tema.Moto.MiniEve.uscita) {
                    mostrata = v
                }
            }
    }

    private var superficie: some View {
        let m = Tema.Misura.MiniEve.self
        let capsula = mini.fase.capsula
        let raggio = capsula ? m.altezzaCapsula / 2 : Tema.Raggio.MiniEve.scheda
        let forma = FormaVetro.arrotondata(raggio)
        let moto: Animation? = modoIstantanea ? nil : (movimentoRidotto ? Tema.Moto.MiniEve.ridotto : Tema.Moto.MiniEve.forma)
        return contenuto
            .frame(width: mini.larghezza)
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(forma)
            .vetro(.pannello, forma: forma, riempimento: Tema.Colore.MiniEve.fondo)
            .animation(moto, value: mini.fase)
            .animation(moto, value: mini.inArrivo)
            .opacity(mostrata ? 1 : 0)
            .scaleEffect(mostrata || movimentoRidotto ? 1 : m.scalaUscita, anchor: .topTrailing)
            .offset(y: mostrata || movimentoRidotto ? 0 : m.salitaUscita)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Eve")
    }

    @ViewBuilder
    private var contenuto: some View {
        Group {
            switch mini.fase {
            case .ascolta: CapsulaAscolto()
            case .pensa: CapsulaPensa()
            case .nonPronta: CapsulaNonPronta()
            case .risponde: SchedaRisposta()
            case .scrivi: SchedaScrivi()
            }
        }
        .id(mini.fase)
        .transition(.opacity)
    }
}

// MARK: - Capsule

/// Ti ascolto…: la sfera e l'onda seguono il livello della voce, la frase si scrive mentre parli.
private struct CapsulaAscolto: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mini: StatoMiniEve

    var body: some View {
        if stato.persistente {
            OsservaAscoltoMini(ascolto: stato.ascoltoEve) { capsula($0) }
        } else {
            capsula(stato.voceIstantanea ?? StatoVoce(ascolta: true))
        }
    }

    private func capsula(_ v: StatoVoce) -> some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        let livello = CGFloat(v.livello)
        return HStack(spacing: m.spazioCapsula) {
            SferaAcquaEve(lato: m.sferaCapsula, livello: livello, velocita: Tema.Moto.MiniEve.velocitaAscolto)
            VStack(alignment: .leading, spacing: m.spazioSotto) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(v.trascritto.isEmpty ? "Ti ascolto…" : v.trascritto)
                        .foregroundColor(v.trascritto.isEmpty ? c.testoTerziario : c.testo)
                        .lineLimit(2)
                    CursoreMiniEve()
                }
                .font(Tema.Testo.MiniEve.frase)
                Text(v.prepara ? (v.nota ?? "Mi preparo ad ascoltarti…") : sotto)
                    .font(Tema.Testo.MiniEve.sotto)
                    .foregroundColor(c.testoTerziario)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            OndaMiniEve(livello: livello, attiva: v.ascolta && !v.prepara)
            TastoTondoMiniEve(simbolo: "xmark", aiuto: "Chiudi · Esc") { stato.chiudiMiniEve() }
        }
        .padding(Tema.Misura.MiniEve.margineCapsula)
        .frame(minHeight: m.altezzaCapsula)
    }

    private var sotto: String {
        guard let c = mini.contesto else { return "Su tutto il portafoglio" }
        return "Su \(c.nome)" + (c.app.map { " · \($0)" } ?? "")
    }
}

/// Segue l'ascolto e ridisegna solo la capsula.
private struct OsservaAscoltoMini<C: View>: View {
    @ObservedObject var ascolto: AscoltoEve
    let contenuto: (StatoVoce) -> C

    var body: some View {
        contenuto(StatoVoce(ascolta: ascolto.ascolta, prepara: ascolto.siPrepara, trascritto: ascolto.trascritto,
                            livello: ascolto.livello, nota: ascolto.nota))
    }
}

/// Eve pensa: i passi scorrono con un luccichio, la domanda sotto.
private struct CapsulaPensa: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mini: StatoMiniEve

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        HStack(spacing: m.spazioCapsula) {
            SferaAcquaEve(lato: m.sferaCapsula, velocita: Tema.Moto.MiniEve.velocitaPensiero)
            VStack(alignment: .leading, spacing: m.spazioSotto) {
                LuccichioMiniEve(testo: mini.passo)
                Text(mini.domanda)
                    .font(Tema.Testo.MiniEve.sotto)
                    .foregroundColor(Tema.Colore.MiniEve.testoTerziario)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TastoTondoMiniEve(simbolo: "xmark", aiuto: "Chiudi · Esc") { stato.chiudiMiniEve() }
        }
        .padding(m.margineCapsula)
        .frame(minHeight: m.altezzaCapsula)
    }
}

/// Qwen non è pronto: «Mi sto svegliando…», la barra di avanzamento e Riprova. Nessuna risposta inventata.
private struct CapsulaNonPronta: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mini: StatoMiniEve

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        HStack(spacing: m.spazioCapsula) {
            SferaAcquaEve(lato: m.sferaCapsula, spenta: true)
            VStack(alignment: .leading, spacing: m.spazioSotto) {
                Text("Mi sto svegliando…")
                    .font(Tema.Testo.MiniEve.fraseSveglia)
                    .foregroundColor(c.testo)
                Text(mini.motivoNonPronta ?? "Qwen si avvia sul Mac, qualche secondo e ci sono. Non invento nulla nel frattempo.")
                    .font(Tema.Testo.MiniEve.sotto)
                    .foregroundColor(c.testoTerziario)
                    .fixedSize(horizontal: false, vertical: true)
                AvanzamentoMiniEve(attivo: mini.preparazioneInCorso || mini.motivoNonPronta == nil)
                    .padding(.top, m.spazioAvanzamento - m.spazioSotto)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PulsanteMiniEve(titolo: "Riprova") { stato.riprovaMiniEve() }
            TastoTondoMiniEve(simbolo: "xmark", aiuto: "Chiudi · Esc") { stato.chiudiMiniEve() }
        }
        .padding(m.margineCapsula)
        .frame(minHeight: m.altezzaCapsula)
    }
}

// MARK: - Schede

/// La risposta: la domanda in alto, il testo, le cifre di Prisma con il canale, la fonte, i pulsanti e gli spunti.
private struct SchedaRisposta: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mini: StatoMiniEve

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: m.spazioTesta) {
                SferaAcquaEve(lato: m.sferaScheda, velocita: mini.inArrivo ? Tema.Moto.MiniEve.velocitaPensiero : 1)
                VStack(alignment: .leading, spacing: m.spazioDomanda) {
                    HStack(spacing: m.spazioFonte) {
                        Text(mini.inArrivo ? "Eve" : "Eve · ora")
                        if mini.inArrivo { ParlaMiniEve() }
                    }
                    .font(Tema.Testo.MiniEve.autore)
                    .foregroundColor(c.testoTerziario)
                    Text(mini.domanda)
                        .font(Tema.Testo.MiniEve.domanda)
                        .foregroundColor(c.testo)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TastoTondoMiniEve(simbolo: "arrow.up.forward", aiuto: "Continua nell'app Eve") { stato.apriInEveDaMiniEve() }
                TastoTondoMiniEve(simbolo: "xmark", aiuto: "Chiudi · Esc") { stato.chiudiMiniEve() }
            }
            .padding(m.margineTesta)
            // Il corpo scorre se la risposta è lunga: la scheda non supera l'altezza massima
            ScrollView(.vertical) { corpo }
                .frame(maxHeight: corpoMassimo)
            CampoMiniEve(segnaposto: "Chiedi altro a Eve…")
            PiedeMiniEve()
        }
    }

    /// Lo spazio del corpo: l'altezza disponibile sullo schermo meno testa, campo e piede. La scheda è alta quanto
    /// serve; scorre solo se la risposta non sta nello schermo.
    private var corpoMassimo: CGFloat { mini.altezzaMassima - Tema.Misura.MiniEve.cornice }

    private var corpo: some View {
        let m = Tema.Misura.MiniEve.self
        let cifre = mini.cifre
        let mostra = !mini.inArrivo
        return VStack(alignment: .leading, spacing: 0) {
            if let t = mini.titolo, t == "Eve non ha potuto rispondere" || t == "Qwen non è pronto" {
                Text(t)
                    .font(Tema.Testo.MiniEve.rispostaForte)
                    .foregroundColor(Tema.Colore.MiniEve.testo)
                    .padding(.bottom, m.spazioSotto * 2)
            }
            TestoRispostaMiniEve(testo: mini.risposta)
            if mostra {
                Group {
                    // .reveal del template: linea del tempo, righe, fonte, pulsanti e spunti salgono uno dopo l'altro
                    if let l = cifre.linea { LineaTempoVista(linea: l).padding(.top, m.spazioBlocchi).comparsaMiniEve(0) }
                    if !cifre.righe.isEmpty { RigheMiniEve(righe: cifre.righe).padding(.top, m.spazioRighe).comparsaMiniEve(1) }
                    if let f = cifre.fonte {
                        HStack(spacing: m.spazioFonte) {
                            Image(systemName: "doc.text").font(.system(size: m.simboloFonte))
                            Text(f).lineLimit(1)
                        }
                        .font(Tema.Testo.MiniEve.fonte)
                        .foregroundColor(Tema.Colore.MiniEve.testoTerziario)
                        .padding(.top, m.spazioRighe)
                        .comparsaMiniEve(2)
                    }
                    if !cifre.azioni.isEmpty {
                        DisposizioneAcapoRicerca(spazio: m.spazioPulsante) {
                            ForEach(cifre.azioni) { a in
                                PulsanteMiniEve(titolo: a.titolo, simbolo: a.simbolo, primario: a.primaria) { stato.eseguiMiniEve(a) }
                            }
                        }
                        .padding(.top, m.spazioBlocchi)
                        .comparsaMiniEve(3)
                    }
                    if !cifre.seguiti.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            EtichettaMiniEve(testo: "Puoi chiedermi anche")
                            DisposizioneAcapoRicerca(spazio: m.spazioSpunti) {
                                ForEach(cifre.seguiti) { s in SpuntoMiniEveVista(spunto: s) }
                            }
                        }
                        .comparsaMiniEve(4)
                    }
                }
            }
        }
        .padding(m.margineCorpo)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Tema.Moto.MiniEve.comparsa, value: mostra)
    }
}

/// Pronta per scrivere: il gettone del contesto, il campo, gli spunti del cliente, la giornata e i recenti.
private struct SchedaScrivi: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mini: StatoMiniEve

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: m.spazioTesta) {
                SferaAcquaEve(lato: m.sferaScheda)
                Group {
                    if let c = mini.contesto {
                        GettoneContestoMiniEve(contesto: c, togli: stato.inModoCliente ? nil : { stato.togliContestoMiniEve() })
                    } else {
                        Text("Su tutto il portafoglio")
                            .font(Tema.Testo.MiniEve.gettone)
                            .foregroundColor(Tema.Colore.MiniEve.testoSecondario)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TastoTondoMiniEve(simbolo: "xmark", aiuto: "Chiudi · Esc") { stato.chiudiMiniEve() }
            }
            .padding(m.margineTesta)
            CampoMiniEve(segnaposto: "Chiedi a Eve, o tieni premuto ⌥ Spazio e parla…", fuoco: true)
            VStack(alignment: .leading, spacing: 0) {
                if let n = mini.nota {
                    Text(n)
                        .font(Tema.Testo.MiniEve.sotto)
                        .foregroundColor(Tema.Colore.MiniEve.testoSecondario)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, m.spazioRighe)
                }
                if let c = mini.contesto {
                    sezione("Su \(c.nome)", CifreMiniEve.spuntiCliente)
                }
                if !stato.inModoCliente {
                    sezione(mini.contesto == nil ? "Il portafoglio" : "La tua giornata",
                            mini.contesto == nil ? Array(CifreMiniEve.spuntiGiornata.prefix(1)) + CifreMiniEve.spuntiPortafoglio : CifreMiniEve.spuntiGiornata)
                    let recenti = stato.recentiMiniEve()
                    if !recenti.isEmpty {
                        EtichettaMiniEve(testo: "Recenti")
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(recenti) { r in RecenteMiniEve(messaggio: r) }
                        }
                    }
                }
            }
            .padding(EdgeInsets(top: 2, leading: m.margineCorpo.leading, bottom: m.margineCorpo.bottom, trailing: m.margineCorpo.trailing))
            PiedeMiniEve()
        }
    }

    private func sezione(_ titolo: String, _ spunti: [SpuntoMiniEve]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            EtichettaMiniEve(testo: titolo)
            DisposizioneAcapoRicerca(spazio: Tema.Misura.MiniEve.spazioSpunti) {
                ForEach(spunti) { s in SpuntoMiniEveVista(spunto: s) }
            }
        }
    }
}

// MARK: - Pezzi della scheda

/// Il testo della risposta, con le cifre in grassetto (come nel template).
private struct TestoRispostaMiniEve: View {
    let testo: String
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea
    /// Le parole già scritte: la risposta si scrive una parola alla volta, come se Eve parlasse (.answer .w).
    /// Mentre Qwen scrive il testo cresce a blocchi; qui le parole lo seguono con un ritmo regolare.
    @State private var scritte = 0
    @State private var precedente = ""

    private var parole: [Substring] { testo.split(separator: " ", omittingEmptySubsequences: false) }

    var body: some View {
        let tutte = parole
        let n = (movimentoRidotto || modoIstantanea) ? tutte.count : min(scritte, tutte.count)
        let visibile = tutte.prefix(n).joined(separator: " ")
        let resto = n < tutte.count ? " " + tutte.dropFirst(n).joined(separator: " ") : ""
        // Il resto c'è già ma trasparente: la scheda non cambia altezza a ogni parola
        return (TestoRispostaMiniEve.conCifre(visibile) + Text(resto).foregroundColor(.clear))
            .font(Tema.Testo.MiniEve.risposta)
            .foregroundColor(Tema.Colore.MiniEve.testo)
            .lineSpacing(Tema.Misura.MiniEve.interlinea / 2)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: testo) {
                // Una risposta nuova riparte da capo; una che cresce continua da dove era arrivata
                if !testo.hasPrefix(precedente) { scritte = 0 }
                precedente = testo
                let totale = parole.count
                while scritte < totale && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: Tema.Moto.MiniEve.parola)
                    scritte += 1
                }
            }
    }

    private static let cifre = try? NSRegularExpression(pattern: #"€\s?\d[\d.,]*|\d[\d.,]*\s?(?:%|€|euro\b)|\b\d+\s(?:posizion[ei]|mesi|anni|scadenze)\b"#)

    /// Le cifre (euro, percentuali, quantità) in grassetto, il resto normale.
    static func conCifre(_ s: String) -> Text {
        guard let r = cifre else { return Text(s) }
        let ns = s as NSString
        var esito = Text("")
        var da = 0
        for m in r.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > da { esito = esito + Text(ns.substring(with: NSRange(location: da, length: m.range.location - da))) }
            esito = esito + Text(ns.substring(with: m.range)).font(Tema.Testo.MiniEve.rispostaForte)
            da = m.range.location + m.range.length
        }
        if da < ns.length { esito = esito + Text(ns.substring(from: da)) }
        return esito
    }
}

/// La linea del tempo delle scadenze (.tl): 12 mesi, il puntino di oggi, un'asta per scadenza nel colore del canale.
private struct LineaTempoVista: View {
    let linea: LineaTempoMiniEve

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(linea.titolo.uppercased())
                    .font(Tema.Testo.MiniEve.occhiello)
                    .tracking(Tema.Testo.MiniEve.spaziaturaOcchiello)
                    .foregroundColor(c.testoTerziario)
                Spacer(minLength: 8)
                Text(linea.totale)
                    .font(Tema.Testo.MiniEve.totale)
                    .foregroundColor(c.testo)
            }
            GeometryReader { g in disegno(larghezza: g.size.width) }
                .frame(height: m.altezzaLineaTempo)
        }
        .padding(m.margineLineaTempo)
        .background(RoundedRectangle(cornerRadius: Tema.Raggio.MiniEve.lineaTempo, style: .continuous).fill(c.scheda))
        .overlay(RoundedRectangle(cornerRadius: Tema.Raggio.MiniEve.lineaTempo, style: .continuous)
            .strokeBorder(c.bordoScheda, lineWidth: Tema.Misura.filo))
    }

    /// Le misure della linea in una larghezza: margini di 10, dodici mesi uguali.
    private struct Scala {
        let x0: CGFloat
        let x1: CGFloat
        let y: CGFloat
        let passo: CGFloat
        func x(_ mesi: Double) -> CGFloat { x0 + passo * CGFloat(mesi) }
    }

    private func disegno(larghezza w: CGFloat) -> some View {
        let m = Tema.Misura.MiniEve.self
        let s = Scala(x0: 10, x1: w - 10, y: m.asseLineaTempo, passo: (w - 20) / CGFloat(m.mesiLineaTempo))
        return ZStack(alignment: .topLeading) {
            asse(s)
            mesi(s)
            oggi(s)
            ForEach(Array(linea.punti.enumerated()), id: \.offset) { i, p in
                // .pin del template: ogni asta cresce dall'asse con una molla, una dopo l'altra
                CrescitaMiniEve(indice: i, ancora: UnitPoint(x: s.x(p.mesi) / max(w, 1), y: s.y / m.altezzaLineaTempo)) {
                    punto(p, s)
                }
            }
            if let o = linea.oltre { oltre(o, s) }
        }
    }

    private func asse(_ s: Scala) -> some View {
        let m = Tema.Misura.MiniEve.self
        return Path { p in
            p.move(to: CGPoint(x: s.x0, y: s.y))
            p.addLine(to: CGPoint(x: s.x1, y: s.y))
            for i in 0..<m.mesiLineaTempo {
                p.move(to: CGPoint(x: s.x(Double(i)), y: s.y - m.tacca))
                p.addLine(to: CGPoint(x: s.x(Double(i)), y: s.y + m.tacca))
            }
        }
        .stroke(Tema.Colore.MiniEve.separatore, lineWidth: 1)
    }

    private func mesi(_ s: Scala) -> some View {
        let m = Tema.Misura.MiniEve.self
        let cal = Calendar.current
        return ForEach(0..<m.mesiLineaTempo, id: \.self) { i in
            Text(Formati.meseBreve.string(from: cal.date(byAdding: .month, value: i, to: linea.inizio) ?? linea.inizio).lowercased())
                .font(Tema.Testo.MiniEve.mese)
                .foregroundColor(Tema.Colore.MiniEve.testoTerziario)
                .fixedSize()
                .position(x: s.x(Double(i)) + s.passo / 2, y: s.y + 11)
        }
    }

    private func oggi(_ s: Scala) -> some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        let xo = s.x(mesiDa(linea.inizio, a: linea.oggi))
        return ZStack(alignment: .topLeading) {
            Circle().fill(c.accento)
                .frame(width: m.puntoOggi * 2, height: m.puntoOggi * 2)
                .position(x: xo, y: s.y)
            Text("oggi").font(Tema.Testo.MiniEve.oggi).foregroundColor(c.accento)
                .fixedSize()
                .position(x: xo + 16, y: s.y - 10)
        }
    }

    private func punto(_ p: LineaTempoMiniEve.Punto, _ s: Scala) -> some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        let massimo = max(linea.punti.map(\.importo).max() ?? 1, 1)
        let h = m.astaMinima + CGFloat((max(p.importo, 0) / massimo).squareRoot()) * m.astaVariabile
        let px = s.x(p.mesi)
        let colore = Tema.Colore.canale(p.canale)
        return ZStack(alignment: .topLeading) {
            Path { q in
                q.move(to: CGPoint(x: px, y: s.y))
                q.addLine(to: CGPoint(x: px, y: s.y - h))
            }
            .stroke(colore, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            Circle().fill(colore)
                .overlay(Circle().stroke(c.bordoPunto, lineWidth: 1.5))
                .frame(width: m.puntoScadenza * 2, height: m.puntoScadenza * 2)
                .position(x: px, y: s.y - h)
            Text(p.etichetta).font(Tema.Testo.MiniEve.importoPunto).foregroundColor(c.testo)
                .fixedSize()
                .position(x: px, y: s.y - h - 20)
            Text(p.giorno).font(Tema.Testo.MiniEve.dataPunto).foregroundColor(c.testoSecondario)
                .fixedSize()
                .position(x: px, y: s.y - h - 10)
        }
    }

    private func oltre(_ testo: String, _ s: Scala) -> some View {
        let c = Tema.Colore.MiniEve.self
        return ZStack(alignment: .topLeading) {
            Text(testo).font(Tema.Testo.MiniEve.dataPunto).foregroundColor(c.testoSecondario)
                .fixedSize()
                .frame(width: 160, alignment: .trailing)
                .position(x: s.x1 - 2 - 80, y: s.y - 38)
            Path { q in
                q.move(to: CGPoint(x: s.x1 - 60, y: s.y - 28))
                q.addLine(to: CGPoint(x: s.x1, y: s.y - 28))
            }
            .stroke(c.testoTerziario, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        }
    }

    private func mesiDa(_ inizio: Date, a d: Date) -> Double {
        let cal = Calendar.current
        let giorni = Double(cal.range(of: .day, in: .month, for: inizio)?.count ?? 30)
        return Double(cal.dateComponents([.day], from: inizio, to: d).day ?? 0) / giorni
    }
}

/// Le posizioni citate (.rows): nome e nota, il canale, la cifra e la data.
private struct RigheMiniEve: View {
    let righe: [RigaMiniEve]

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        VStack(spacing: 0) {
            ForEach(Array(righe.enumerated()), id: \.element.id) { i, r in
                HStack(spacing: m.spazioRiga) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.titolo).font(Tema.Testo.MiniEve.rigaTitolo).foregroundColor(c.testo).lineLimit(1)
                        Text(r.sotto).font(Tema.Testo.MiniEve.rigaSotto).foregroundColor(c.testoSecondario).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    CapsulaCanale(canale: r.canale, compatta: true)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(r.valore).font(Tema.Testo.MiniEve.rigaValore).foregroundColor(c.testo)
                        if let d = r.data {
                            Text("\(Formati.giornoMeseBreve.string(from: d)) \(Formati.formato("yyyy").string(from: d))")
                                .font(Tema.Testo.MiniEve.rigaData).foregroundColor(c.testoSecondario)
                        }
                    }
                }
                .padding(m.margineRiga)
                .overlay(alignment: .top) {
                    if i > 0 { Rectangle().fill(c.separatore).frame(height: Tema.Misura.filo) }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: Tema.Raggio.MiniEve.righe, style: .continuous).fill(c.scheda))
        .overlay(RoundedRectangle(cornerRadius: Tema.Raggio.MiniEve.righe, style: .continuous).strokeBorder(c.bordoScheda, lineWidth: Tema.Misura.filo))
        .clipShape(RoundedRectangle(cornerRadius: Tema.Raggio.MiniEve.righe, style: .continuous))
    }
}

/// Il campo (.composer): «Chiedi altro a Eve…», il tasto ⏎ e il microfono.
private struct CampoMiniEve: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mini: StatoMiniEve
    let segnaposto: String
    var fuoco = false
    @FocusState private var attivo: Bool

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        HStack(spacing: m.spazioCampo) {
            TextField(segnaposto, text: $mini.testo)
                .textFieldStyle(.plain)
                .font(Tema.Testo.MiniEve.campo)
                .foregroundColor(c.testo)
                .focused($attivo)
                .frame(height: m.altezzaCampo)
                .onSubmit { stato.inviaMiniEve(DomandaMiniEve(testo: mini.testo)) }
            TastoMiniEve(testo: "⏎")
            Button { stato.alternaAscoltoMiniEve() } label: {
                Image(systemName: "mic")
                    .font(.system(size: m.simboloMicrofono, weight: .semibold))
                    .foregroundColor(c.testoSuAccento)
                    .frame(width: m.microfono, height: m.microfono)
                    .background(Circle().fill(c.accento))
            }
            .buttonStyle(StilePressioneMiniEve())
            .help("Parla (o tieni premuto ⌥ Spazio)")
        }
        .padding(m.margineCampo)
        .background(Capsule(style: .continuous).fill(c.scheda))
        .overlay(Capsule(style: .continuous).strokeBorder(c.bordoScheda, lineWidth: Tema.Misura.filo))
        .overlay(Capsule(style: .continuous).stroke(c.accento.opacity(attivo ? 0.28 : 0), lineWidth: m.anelloCampo).padding(-m.anelloCampo / 2))
        .padding(m.margineScrittura)
        .onAppear {
            guard fuoco else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { attivo = true }
        }
    }
}

/// Il piede (.foot): in locale sul Mac, le scorciatoie.
private struct PiedeMiniEve: View {
    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(c.inLocale).frame(width: m.spiaLocale, height: m.spiaLocale)
                    .background(Circle().fill(c.inLocale.opacity(0.18)).padding(-m.aloneSpia))
                Text("In locale sul Mac")
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                TastoMiniEve(testo: "⌥ Spazio")
                Text("parla ·")
                TastoMiniEve(testo: "esc")
                Text("chiudi")
            }
        }
        .font(Tema.Testo.MiniEve.piede)
        .foregroundColor(c.testoTerziario)
        .padding(m.marginePiede)
    }
}

/// Il gettone del contesto (.ctx-chip): l'avatar, il cliente, l'app e la ✕ per toglierlo.
private struct GettoneContestoMiniEve: View {
    let contesto: ContestoMiniEve
    let togli: (() -> Void)?

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        let tinta = contesto.tinta.colori
        HStack(spacing: m.spazioGettone) {
            Text(contesto.iniziali)
                .font(Tema.Testo.MiniEve.avatarGettone)
                .foregroundColor(tinta.testo)
                .frame(width: m.avatarGettone, height: m.avatarGettone)
                .background(Circle().fill(Gradienti.avatar(tinta)))
            (Text(contesto.nome).font(Tema.Testo.MiniEve.gettone).foregroundColor(c.testo)
             + Text(contesto.app.map { " · \($0)" } ?? "").font(Tema.Testo.MiniEve.gettoneApp).foregroundColor(c.testoSecondario))
                .lineLimit(1)
            if let togli {
                Button(action: togli) {
                    Image(systemName: "xmark")
                        .font(.system(size: m.simboloTogli, weight: .bold))
                        .foregroundColor(c.testoSecondario)
                        .frame(width: m.togliGettone, height: m.togliGettone)
                        .background(Circle().fill(c.pozzetto))
                }
                .buttonStyle(StileSemplice())
                .help("Togli il contesto: Eve parla di tutto il portafoglio")
            }
        }
        .padding(.horizontal, m.margineGettone)
        .frame(height: m.gettone)
        .background(Capsule(style: .continuous).fill(c.chip))
        .overlay(Capsule(style: .continuous).strokeBorder(c.bordoChip, lineWidth: Tema.Misura.filo))
        .fixedSize()
        .help("Eve parte da ciò che hai aperto")
    }
}

/// Una domanda recente (.recent).
private struct RecenteMiniEve: View {
    @EnvironmentObject var stato: StatoShell
    let messaggio: MessaggioEve
    @State private var sopra = false

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        Button { stato.inviaMiniEve(DomandaMiniEve(testo: messaggio.testo)) } label: {
            HStack(spacing: m.spazioRecente) {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: m.simboloPulsante)).foregroundColor(c.testoTerziario)
                Text(messaggio.testo).font(Tema.Testo.MiniEve.recente).foregroundColor(c.testo).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Formati.giornoRelativo(messaggio.data)).font(Tema.Testo.MiniEve.quando).foregroundColor(c.testoTerziario)
            }
            .padding(m.margineRecente)
            .background(RoundedRectangle(cornerRadius: Tema.Raggio.MiniEve.recente, style: .continuous).fill(sopra ? c.pozzetto : .clear))
            .padding(.horizontal, -m.margineRecente.leading)
        }
        .buttonStyle(StileSemplice())
        .onHover { sopra = $0 }
    }
}

/// Uno spunto (.sugg button): pozzetto a capsula con il simbolo blu.
private struct SpuntoMiniEveVista: View {
    @EnvironmentObject var stato: StatoShell
    let spunto: SpuntoMiniEve
    @State private var sopra = false

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        Button {
            stato.inviaMiniEve(DomandaMiniEve(testo: spunto.domanda, spunto: spunto.spunto, portafoglio: spunto.portafoglio))
        } label: {
            HStack(spacing: m.spazioSpunti) {
                Image(systemName: spunto.simbolo).font(.system(size: m.simboloPulsante)).foregroundColor(c.link)
                Text(spunto.testo).font(Tema.Testo.MiniEve.spunto).foregroundColor(c.testo).lineLimit(1)
            }
            .padding(.horizontal, m.margineSpunto)
            .frame(height: m.spunto)
            .background(Capsule(style: .continuous).fill(sopra ? c.pozzettoSopra : c.pozzetto))
            .overlay(Capsule(style: .continuous).strokeBorder(c.separatore, lineWidth: Tema.Misura.filo))
        }
        .buttonStyle(StilePressioneMiniEve())
        .onHover { sopra = $0 }
    }
}

private struct EtichettaMiniEve: View {
    let testo: String

    var body: some View {
        Text(testo.uppercased())
            .font(Tema.Testo.MiniEve.etichetta)
            .tracking(Tema.Testo.MiniEve.spaziaturaEtichetta)
            .foregroundColor(Tema.Colore.MiniEve.testoTerziario)
            .padding(Tema.Misura.MiniEve.margineEtichetta)
    }
}

// MARK: - Controlli

/// Pulsante di vetro (.btn), o pieno dell'accento (.btn.primary).
private struct PulsanteMiniEve: View {
    let titolo: String
    var simbolo: String?
    var primario = false
    let azione: () -> Void
    @State private var sopra = false

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        Button(action: azione) {
            HStack(spacing: m.spazioPulsante) {
                if let simbolo { Image(systemName: simbolo).font(.system(size: m.simboloPulsante, weight: .medium)) }
                Text(titolo).lineLimit(1)
            }
            .font(Tema.Testo.MiniEve.pulsante)
            .foregroundColor(primario ? c.testoSuAccento : c.testo)
            .padding(.horizontal, m.marginePulsante)
            .frame(height: m.pulsante)
            .background(Capsule(style: .continuous).fill(primario ? c.accento : (sopra ? c.chipSopra : c.chip)))
            .overlay(Capsule(style: .continuous).strokeBorder(primario ? Color.clear : c.bordoChip, lineWidth: Tema.Misura.filo))
            .overlay(alignment: .top) {
                Capsule(style: .continuous).trim(from: 0.6, to: 0.9).stroke(primario ? Color.white.opacity(0.35) : c.lucePulsante, lineWidth: 1)
                    .padding(1).allowsHitTesting(false)
            }
            .ombraTema(primario ? Tema.Ombra.pulsantePrimario : Tema.Ombra.pulsante)
            .fixedSize()
        }
        .buttonStyle(StilePressioneMiniEve())
        .onHover { sopra = $0 }
    }
}

/// Pulsante tondo (.ico): ✕ e la freccia verso l'app Eve.
private struct TastoTondoMiniEve: View {
    let simbolo: String
    let aiuto: String
    let azione: () -> Void
    @State private var sopra = false

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let c = Tema.Colore.MiniEve.self
        Button(action: azione) {
            Image(systemName: simbolo)
                .font(.system(size: m.simboloIco, weight: .semibold))
                .foregroundColor(sopra ? c.testo : c.testoSecondario)
                .frame(width: m.ico, height: m.ico)
                .background(Circle().fill(sopra ? c.pozzettoSopra : c.pozzetto))
        }
        .buttonStyle(StilePressioneMiniEve())
        .onHover { sopra = $0 }
        .help(aiuto)
        .accessibilityLabel(aiuto)
    }
}

/// Il tasto di una scorciatoia (.kb).
private struct TastoMiniEve: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(Tema.Testo.MiniEve.tasto)
            .foregroundColor(Tema.Colore.MiniEve.testoSecondario)
            .padding(Tema.Misura.MiniEve.margineTasto)
            .background(RoundedRectangle(cornerRadius: Tema.Raggio.MiniEve.tasto, style: .continuous).fill(Tema.Colore.MiniEve.pozzetto))
    }
}

/// La pressione del tema: un rimbalzo appena più piccolo.
private struct StilePressioneMiniEve: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Tema.Moto.molla, value: configuration.isPressed)
    }
}

// MARK: - Movimenti piccoli

/// .reveal: un blocco della risposta sale di 6 punti e compare, dopo i blocchi prima di lui (0,16 s l'uno).
private struct ComparsaMiniEve: ViewModifier {
    let indice: Int
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea
    @State private var visibile = false

    func body(content: Content) -> some View {
        let fermo = movimentoRidotto || modoIstantanea
        content
            .opacity(fermo || visibile ? 1 : 0)
            .offset(y: fermo || visibile ? 0 : Tema.Misura.MiniEve.salitaComparsa)
            .onAppear {
                guard !fermo else { return }
                withAnimation(Tema.Moto.MiniEve.comparsa.delay(Tema.Moto.MiniEve.ritardoBlocco * Double(indice))) { visibile = true }
            }
    }
}

extension View {
    fileprivate func comparsaMiniEve(_ indice: Int) -> some View { modifier(ComparsaMiniEve(indice: indice)) }
}

/// .pin: l'asta di una scadenza cresce dall'asse con una molla, dopo la comparsa della linea del tempo.
private struct CrescitaMiniEve<Contenuto: View>: View {
    let indice: Int
    let ancora: UnitPoint
    @ViewBuilder let contenuto: () -> Contenuto
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea
    @State private var cresciuta = false

    var body: some View {
        let fermo = movimentoRidotto || modoIstantanea
        contenuto()
            .scaleEffect(x: 1, y: fermo || cresciuta ? 1 : 0.001, anchor: ancora)
            .opacity(fermo || cresciuta ? 1 : 0)
            .onAppear {
                guard !fermo else { return }
                withAnimation(Tema.Moto.MiniEve.asta.delay(Tema.Moto.MiniEve.ritardoAsta + Tema.Moto.MiniEve.passoAsta * Double(indice))) {
                    cresciuta = true
                }
            }
    }
}

/// Il cursore che lampeggia (.caret).
private struct CursoreMiniEve: View {
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let fermo = movimentoRidotto || modoIstantanea
        TimelineView(.periodic(from: .now, by: Tema.Moto.MiniEve.lampeggio / 2)) { t in
            let acceso = fermo || Int(t.date.timeIntervalSinceReferenceDate / (Tema.Moto.MiniEve.lampeggio / 2)) % 2 == 0
            Rectangle()
                .fill(Tema.Colore.MiniEve.cursore)
                .frame(width: m.cursore.width, height: m.cursore.height)
                .opacity(acceso ? 1 : 0)
        }
        .frame(width: m.cursore.width, height: m.cursore.height)
    }
}

/// L'onda della voce (.wave): barre simmetriche guidate dal livello del microfono.
private struct OndaMiniEve: View {
    let livello: CGFloat
    let attiva: Bool
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let muove = attiva && !movimentoRidotto && !modoIstantanea
        TimelineView(.animation(minimumInterval: 1 / Tema.Moto.MiniEve.fotogrammi, paused: !muove)) { t in
            let k = muove ? t.date.timeIntervalSinceReferenceDate : 0.6
            HStack(spacing: m.spazioOnda) {
                ForEach(0..<m.barreOnda, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(colors: [Tema.Colore.MiniEve.accento, Tema.Colore.MiniEve.ondaFine], startPoint: .top, endPoint: .bottom))
                        .frame(width: m.barraOnda, height: altezza(i, k))
                }
            }
        }
        .frame(height: m.altezzaOnda)
        .fixedSize()
    }

    private func altezza(_ i: Int, _ k: Double) -> CGFloat {
        let m = Tema.Misura.MiniEve.self
        let n = CGFloat(m.barreOnda)
        let centro = 1 - abs(CGFloat(i) - (n - 1) / 2) / (n / 2)
        let rumore = 0.6 + 0.4 * abs(sin(k * 9 + Double(i) * 1.7))
        return m.barraOndaMinima + min(max(livello, 0), 1) * m.barraOndaVoce * (0.35 + 0.65 * centro) * CGFloat(rumore)
    }
}

/// Il passo di «pensa» con il luccichio che scorre (.shimmer).
private struct LuccichioMiniEve: View {
    let testo: String
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea

    var body: some View {
        let c = Tema.Colore.MiniEve.self
        let muove = !movimentoRidotto && !modoIstantanea
        TimelineView(.animation(minimumInterval: 1 / Tema.Moto.MiniEve.fotogrammi, paused: !muove)) { t in
            let fase = muove ? (t.date.timeIntervalSinceReferenceDate / Tema.Moto.MiniEve.luccichio).truncatingRemainder(dividingBy: 1) : 0.45
            let centro = -0.4 + 1.8 * fase
            Text(testo)
                .font(Tema.Testo.MiniEve.pensa)
                .lineLimit(1)
                .foregroundStyle(LinearGradient(stops: [.init(color: c.testoTerziario, location: 0), .init(color: c.testo, location: 0.5),
                                                        .init(color: c.testoTerziario, location: 1)],
                                                 startPoint: UnitPoint(x: centro - 0.5, y: 0.5), endPoint: UnitPoint(x: centro + 0.5, y: 0.5)))
        }
    }
}

/// Le barrette accanto a «Eve» mentre la risposta arriva (.speak).
private struct ParlaMiniEve: View {
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let muove = !movimentoRidotto && !modoIstantanea
        TimelineView(.animation(minimumInterval: 1 / Tema.Moto.MiniEve.fotogrammi, paused: !muove)) { t in
            let k = muove ? t.date.timeIntervalSinceReferenceDate : 0.3
            HStack(spacing: 1.5) {
                ForEach(0..<m.barreParla, id: \.self) { i in
                    let ritardo = [0, 0.2, 0.45][i]
                    let u = (k + ritardo).truncatingRemainder(dividingBy: 0.7) / 0.7
                    Capsule().fill(Tema.Colore.MiniEve.accento)
                        .frame(width: m.barraParla, height: 3 + (m.altezzaParla - 3) * CGFloat((1 - cos(2 * .pi * u)) / 2))
                }
            }
            .frame(height: m.altezzaParla)
        }
    }
}

/// La barra di avanzamento di «Mi sto svegliando…» (.prog).
private struct AvanzamentoMiniEve: View {
    let attivo: Bool
    @Environment(\.accessibilityReduceMotion) private var movimentoRidotto
    @Environment(\.modoIstantanea) private var modoIstantanea

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        let muove = attivo && !movimentoRidotto && !modoIstantanea
        GeometryReader { g in
            TimelineView(.animation(minimumInterval: 1 / Tema.Moto.MiniEve.fotogrammi, paused: !muove)) { t in
                let w = g.size.width * m.quotaAvanzamento
                let fase = muove ? (t.date.timeIntervalSinceReferenceDate / Tema.Moto.MiniEve.avanzamento).truncatingRemainder(dividingBy: 1) : 0.4
                let u = (1 - cos(.pi * fase)) / 2
                Capsule().fill(Tema.Colore.MiniEve.avanzamento)
                    .frame(width: w, height: m.barraAvanzamento)
                    .offset(x: -w + (g.size.width + w) * CGFloat(u))
            }
        }
        .frame(height: m.barraAvanzamento)
        .background(Capsule().fill(Tema.Colore.MiniEve.pozzetto))
        .clipShape(Capsule())
    }
}

// MARK: - La sfera nella barra superiore

/// La sfera di Eve nella capsula degli strumenti: apre e chiude la mini finestra (⌥ Spazio).
/// Ferma a riposo (niente consumi), viva mentre la mini finestra è aperta.
struct PulsanteSferaEve: View {
    @EnvironmentObject var stato: StatoShell
    @ObservedObject var mini: StatoMiniEve
    @State private var sopra = false

    var body: some View {
        let m = Tema.Misura.MiniEve.self
        Button { stato.alternaMiniEve() } label: {
            SferaAcquaEve(lato: m.sferaBarra, animata: mini.visibile)
                .frame(width: m.sferaPulsanteBarra, height: m.sferaPulsanteBarra)
                .frame(minWidth: Tema.Misura.Shell.pulsanteBarraMinimo, minHeight: Tema.Misura.pulsanteBarra)
                .background {
                    if mini.visibile || sopra { Capsule(style: .continuous).fill(Tema.Colore.MiniEve.sferaBarraAperta) }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(StileSemplice())
        .onHover { s in withAnimation(Tema.Moto.passaggio) { sopra = s } }
        .help("Eve · ⌥ Spazio (tieni premuto per parlare)")
        .accessibilityLabel("Chiama Eve")
    }
}
#endif
