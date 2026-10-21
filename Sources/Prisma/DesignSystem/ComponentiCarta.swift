import AppKit
import SwiftUI

private typealias M = Misure.Carta

// MARK: - Impaginazione

/// Un blocco già collocato in pagina, con l'altezza che la vista deve rispettare.
struct BloccoImpaginato: Identifiable {
    let id: Int
    let blocco: BloccoProspetto
    let altezza: CGFloat
}

/// Divide un prospetto in pagine A4. Le altezze sono calcolate prima di disegnare (i testi con
/// le misure di AppKit), così nessuna riga viene tagliata: le tabelle lunghe continuano nella
/// pagina successiva ripetendo l'intestazione e un titolo di sezione non resta mai in fondo da solo.
enum ImpaginatoreProspetto {
    static func pagine(_ c: ContenutoProspetto) -> [[BloccoImpaginato]] {
        func utile(_ prima: Bool) -> CGFloat {
            M.pagina.height - M.margineAlto - M.margineBasso - M.piede - (prima ? M.testataPrima : M.testataCorrente)
        }
        var pagine: [[BloccoImpaginato]] = [[]]
        var resto = utile(true)
        var progressivo = 0
        func metti(_ b: BloccoProspetto, _ h: CGFloat) {
            pagine[pagine.count - 1].append(BloccoImpaginato(id: progressivo, blocco: b, altezza: h))
            progressivo += 1
            resto -= h + M.spazioBlocchi
        }
        func nuovaPagina() {
            pagine.append([])
            resto = utile(false)
        }
        var paginaVuota: Bool { pagine[pagine.count - 1].isEmpty }

        for (i, b) in c.blocchi.enumerated() {
            switch b {
            case .tabella(let t):
                var inizio = 0
                while true {
                    let restanti = t.righe.count - inizio
                    let totale: CGFloat = t.totale == nil ? 0 : M.rigaTotale
                    let tutte = M.testaTabella + CGFloat(restanti) * M.rigaTabella + totale
                    if tutte <= resto {
                        metti(.tabella(parte(t, da: inizio, a: t.righe.count, ultima: true)), tutte)
                        break
                    }
                    let entrano = Int(floor((resto - M.testaTabella) / M.rigaTabella))
                    if entrano < min(M.righeMinime, restanti) && !paginaVuota {
                        nuovaPagina()
                        continue
                    }
                    // Almeno due righe passano alla pagina dopo, per non lasciare una riga sola
                    var n = max(1, min(entrano, restanti))
                    if restanti - n < 2 { n = max(1, restanti - 2) }
                    metti(.tabella(parte(t, da: inizio, a: inizio + n, ultima: false)), M.testaTabella + CGFloat(n) * M.rigaTabella)
                    inizio += n
                    nuovaPagina()
                }
            case .sezione:
                // Il titolo resta con l'inizio del blocco che segue
                let seguito = i + 1 < c.blocchi.count ? altezzaMinima(c.blocchi[i + 1]) : 0
                if M.sezione + M.spazioBlocchi + seguito > resto && !paginaVuota { nuovaPagina() }
                metti(b, M.sezione)
            default:
                let h = altezza(b)
                if h > resto && !paginaVuota { nuovaPagina() }
                metti(b, h)
            }
        }
        return pagine.filter { !$0.isEmpty }
    }

    private static func parte(_ t: TabellaProspetto, da: Int, a: Int, ultima: Bool) -> TabellaProspetto {
        TabellaProspetto(colonne: t.colonne, righe: Array(t.righe[da..<a]), totale: ultima ? t.totale : nil,
                         evidenzia: Set(t.evidenzia.compactMap { $0 >= da && $0 < a ? $0 - da : nil }))
    }

    /// Altezza che deve stare nella stessa pagina del titolo di sezione che lo precede.
    private static func altezzaMinima(_ b: BloccoProspetto) -> CGFloat {
        if case .tabella(let t) = b {
            let righe = min(t.righe.count, M.righeMinime)
            return M.testaTabella + CGFloat(righe) * M.rigaTabella + (t.righe.count <= M.righeMinime && t.totale != nil ? M.rigaTotale : 0)
        }
        return min(altezza(b), 140)
    }

    static func altezza(_ b: BloccoProspetto) -> CGFloat {
        let w = M.larghezzaUtile
        switch b {
        case .sezione: return M.sezione
        case .indicatori: return M.indicatori
        case .voci(let v): return righeVoci(v).reduce(0) { $0 + altezzaRigaVoci($1) }
        case .tabella(let t):
            return M.testaTabella + CGFloat(t.righe.count) * M.rigaTabella + (t.totale == nil ? 0 : M.rigaTotale)
        case .grafico: return M.grafico + M.legenda
        case .testo(let s): return altezzaTesto(s, font: Tipo.Carta.nsTesto, larghezza: w, interlinea: M.interlinea)
        case .avviso(let s):
            return altezzaTesto(s, font: Tipo.Carta.nsTesto, larghezza: larghezzaAvviso, interlinea: M.interlinea) + M.riquadroMargine * 2
        case .nota(let s): return altezzaTesto(s, font: Tipo.Carta.nsNota, larghezza: w, interlinea: 1.5) + 7
        }
    }

    static var larghezzaAvviso: CGFloat { M.larghezzaUtile - M.riquadroMargine * 2 - 20 }
    static var larghezzaVoce: CGFloat { (M.larghezzaUtile - M.colonnaVoci) / 2 }

    static func righeVoci(_ v: [CampoVoce]) -> [[CampoVoce]] {
        stride(from: 0, to: v.count, by: 2).map { Array(v[$0..<min($0 + 2, v.count)]) }
    }

    static func altezzaRigaVoci(_ riga: [CampoVoce]) -> CGFloat {
        let valore = riga.map { c -> CGFloat in
            c.canale != nil ? 15 : altezzaTesto(c.valore, font: Tipo.Carta.nsVoceValore, larghezza: larghezzaVoce, interlinea: M.interlinea)
        }.max() ?? 12
        return M.voceMargine * 2 + M.voceEtichetta + 2 + valore
    }

    /// Altezza di un testo a capo automatico. Si misura su una colonna un po' più stretta
    /// di quella disegnata: il testo a schermo va a capo al più nello stesso punto, mai dopo.
    static func altezzaTesto(_ s: String, font: NSFont, larghezza: CGFloat, interlinea: CGFloat) -> CGFloat {
        let stile = NSMutableParagraphStyle()
        stile.lineSpacing = interlinea
        let r = (s as NSString).boundingRect(with: NSSize(width: larghezza - 6, height: .greatestFiniteMagnitude),
                                             options: [.usesLineFragmentOrigin, .usesFontLeading],
                                             attributes: [.font: font, .paragraphStyle: stile])
        return ceil(r.height) + 3
    }
}

// MARK: - La pagina

/// Una pagina A4 di un prospetto, identica a schermo e nel PDF.
struct PaginaCarta: View {
    let contenuto: ContenutoProspetto
    let blocchi: [BloccoImpaginato]
    let numero: Int
    let totale: Int
    var genere = "Prospetto di dettaglio"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if numero == 1 { testataPrima } else { testataCorrente }
            }
            .frame(width: M.larghezzaUtile, height: numero == 1 ? M.testataPrima : M.testataCorrente, alignment: .topLeading)
            VStack(alignment: .leading, spacing: M.spazioBlocchi) {
                ForEach(blocchi) { b in
                    BloccoCarta(blocco: b.blocco)
                        .frame(width: M.larghezzaUtile, height: b.altezza, alignment: .topLeading)
                }
            }
            Spacer(minLength: 0)
            piede
        }
        .padding(EdgeInsets(top: M.margineAlto, leading: M.margineLato, bottom: M.margineBasso, trailing: M.margineLato))
        .frame(width: M.pagina.width, height: M.pagina.height)
        .background(Colori.Carta.foglio)
        .environment(\.colorScheme, .light)
    }

    private var testataPrima: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(verbatim: "◈").font(Tipo.Carta.marchio).foregroundColor(Colori.Carta.intestazione)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "PRISMA").font(Tipo.Carta.testata).tracking(3).foregroundColor(Colori.Carta.intestazione)
                    Text(verbatim: genere.uppercased()).font(Tipo.Carta.testataPiccola).tracking(1.5).foregroundColor(Colori.Carta.intestazione)
                }
                Spacer()
                Text(verbatim: Formati.dataEstesa.string(from: contenuto.data)).font(Tipo.Carta.data).foregroundColor(Colori.Carta.testoTenue)
            }
            .padding(.bottom, 9)
            Rectangle().fill(Colori.Carta.filettoForte).frame(height: 2)
            Text(verbatim: contenuto.occhiello.uppercased())
                .font(Tipo.Carta.occhiello).tracking(1.2).foregroundColor(Colori.Carta.numeroSezione)
                .padding(.top, 14)
            Text(verbatim: contenuto.titolo)
                .font(Tipo.Carta.titolo).foregroundColor(Colori.Carta.titolo)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.top, 4)
            Text(verbatim: contenuto.sottotitolo)
                .font(Tipo.Carta.sottotitolo).foregroundColor(Colori.Carta.testoTenue)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.top, 2)
            HStack(spacing: 8) {
                Text(verbatim: "CLIENTE").font(Tipo.Carta.voceEtichetta).tracking(0.6).foregroundColor(Colori.Carta.testoTenue)
                Text(verbatim: contenuto.cliente).font(Tipo.Carta.firma.weight(.bold)).foregroundColor(Colori.Carta.titolo)
                Spacer()
                if let c = contenuto.canale { EtichettaCanale(canale: c) }
                if let c = contenuto.canaleSecondo { EtichettaCanale(canale: c) }
            }
            .frame(height: 24)
            .padding(.top, 10)
            .padding(.bottom, 7)
            Rectangle().fill(Colori.Carta.filetto).frame(height: 1)
        }
    }

    private var testataCorrente: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Text(verbatim: "◈ PRISMA").font(Tipo.Carta.corrente).tracking(2).foregroundColor(Colori.Carta.intestazione)
                Text(verbatim: "· \(contenuto.titolo)").font(Tipo.Carta.corrente).foregroundColor(Colori.Carta.testoTenue).lineLimit(1)
                Spacer()
                Text(verbatim: contenuto.cliente).font(Tipo.Carta.corrente).foregroundColor(Colori.Carta.testoTenue)
            }
            Rectangle().fill(Colori.Carta.filettoForte).frame(height: 1)
        }
    }

    private var piede: some View {
        VStack(spacing: 5) {
            Rectangle().fill(Colori.Carta.filetto).frame(height: 1)
            HStack {
                Text(verbatim: "Prisma · \(genere.lowercased()) · \(contenuto.cliente) · \(Formati.dataBreve.string(from: contenuto.data))")
                Spacer()
                Text(verbatim: "Pagina \(numero) di \(totale)")
            }
            .font(Tipo.Carta.piede)
            .tracking(0.4)
            .foregroundColor(Colori.Carta.piede)
        }
        .frame(height: M.piede, alignment: .bottom)
    }
}

// MARK: - I blocchi

struct BloccoCarta: View {
    let blocco: BloccoProspetto

    var body: some View {
        switch blocco {
        case .sezione(let numero, let titolo):
            VStack(alignment: .leading, spacing: 5) {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(verbatim: numero).font(Tipo.Carta.numeroSezione).foregroundColor(Colori.Carta.numeroSezione)
                    Text(verbatim: titolo).font(Tipo.Carta.sezione).foregroundColor(Colori.Carta.titolo)
                }
                Rectangle().fill(Colori.Carta.filetto).frame(height: 1)
            }
        case .indicatori(let elenco):
            HStack(spacing: 8) {
                ForEach(Array(elenco.enumerated()), id: \.offset) { _, x in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: x.etichetta.uppercased()).font(Tipo.Carta.indicatoreEtichetta).tracking(0.6)
                            .foregroundColor(Colori.Carta.testoTenue).lineLimit(1).minimumScaleFactor(0.8)
                        Text(verbatim: x.valore).font(Tipo.Carta.indicatoreValore).foregroundColor(Colori.Carta.titolo)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(verbatim: x.nota).font(Tipo.Carta.indicatoreNota).foregroundColor(Colori.Carta.testoTenue)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .padding(M.riquadroMargine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: M.raggio).fill(Colori.Carta.riquadro))
                    .overlay(RoundedRectangle(cornerRadius: M.raggio).strokeBorder(Colori.Carta.riquadroBordo, lineWidth: 0.8))
                }
            }
        case .voci(let voci):
            VStack(spacing: 0) {
                ForEach(Array(ImpaginatoreProspetto.righeVoci(voci).enumerated()), id: \.offset) { _, riga in
                    HStack(alignment: .top, spacing: M.colonnaVoci) {
                        ForEach(Array(riga.enumerated()), id: \.offset) { _, c in voce(c) }
                        if riga.count == 1 { Color.clear.frame(width: ImpaginatoreProspetto.larghezzaVoce) }
                    }
                    .frame(height: ImpaginatoreProspetto.altezzaRigaVoci(riga), alignment: .top)
                    .overlay(Rectangle().fill(Colori.Carta.filettoRiga).frame(height: 0.6), alignment: .bottom)
                }
            }
        case .tabella(let t):
            TabellaCarta(tabella: t)
        case .grafico(let serie):
            GraficoCarta(serie: serie)
        case .testo(let s):
            Text(verbatim: s).font(Tipo.Carta.testo).lineSpacing(M.interlinea).foregroundColor(Colori.Carta.testo)
                .fixedSize(horizontal: false, vertical: true)
        case .avviso(let s):
            HStack(alignment: .top, spacing: 8) {
                Text(verbatim: "!").font(Tipo.Carta.tabellaForte).foregroundColor(.white)
                    .frame(width: 12, height: 12)
                    .background(Circle().fill(Colori.Carta.avvisoTesto))
                Text(verbatim: s).font(Tipo.Carta.testo).lineSpacing(M.interlinea).foregroundColor(Colori.Carta.avvisoTesto)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: ImpaginatoreProspetto.larghezzaAvviso, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(M.riquadroMargine)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: M.raggio).fill(Colori.Carta.avvisoFondo))
            .overlay(RoundedRectangle(cornerRadius: M.raggio).strokeBorder(Colori.Carta.avvisoBordo, lineWidth: 0.8))
        case .nota(let s):
            VStack(alignment: .leading, spacing: 5) {
                Rectangle().fill(Colori.Carta.filetto).frame(height: 0.6)
                Text(verbatim: s).font(Tipo.Carta.nota).lineSpacing(1.5).foregroundColor(Colori.Carta.piede)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func voce(_ c: CampoVoce) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: c.etichetta.uppercased()).font(Tipo.Carta.voceEtichetta).tracking(0.5)
                .foregroundColor(Colori.Carta.testoTenue).lineLimit(1)
                .frame(height: M.voceEtichetta, alignment: .leading)
            if let canale = c.canale {
                EtichettaCanale(canale: canale, compatta: true)
            } else {
                Text(verbatim: c.valore).font(Tipo.Carta.voceValore).lineSpacing(M.interlinea).foregroundColor(Colori.Carta.testo)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, M.voceMargine)
        .frame(width: ImpaginatoreProspetto.larghezzaVoce, alignment: .topLeading)
    }
}

/// Tabella su carta: intestazione con filetto forte, righe alterne, totale in grassetto.
struct TabellaCarta: View {
    let tabella: TabellaProspetto

    private var larghezze: [CGFloat] {
        let somma = tabella.colonne.reduce(0) { $0 + $1.peso }
        return tabella.colonne.map { CGFloat($0.peso / max(somma, 0.01)) * M.larghezzaUtile }
    }

    var body: some View {
        let w = larghezze
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(tabella.colonne.enumerated()), id: \.offset) { i, c in
                    Text(verbatim: c.titolo.uppercased()).font(Tipo.Carta.tabellaTesta).tracking(0.5)
                        .foregroundColor(Colori.Carta.intestazione).lineLimit(1).minimumScaleFactor(0.7)
                        .frame(width: max(0, w[i] - 8), alignment: c.destra ? .trailing : .leading)
                        .padding(.horizontal, 4)
                }
            }
            .frame(height: M.testaTabella, alignment: .bottom)
            .overlay(Rectangle().fill(Colori.Carta.filettoForte).frame(height: 1), alignment: .bottom)
            ForEach(Array(tabella.righe.enumerated()), id: \.offset) { r, riga in
                rigaVista(riga, larghezze: w)
                    .frame(height: M.rigaTabella)
                    .background(tabella.evidenzia.contains(r) ? Colori.Carta.evidenza : (r % 2 == 1 ? Colori.Carta.zebra : Color.clear))
                    .overlay(Rectangle().fill(Colori.Carta.filettoRiga).frame(height: 0.5), alignment: .bottom)
            }
            if let totale = tabella.totale {
                rigaVista(totale.map { cella -> CellaProspetto in
                    var c = cella
                    c.forte = true
                    return c
                }, larghezze: w)
                    .frame(height: M.rigaTotale)
                    .overlay(Rectangle().fill(Colori.Carta.filettoForte).frame(height: 0.8), alignment: .top)
            }
        }
    }

    private func rigaVista(_ riga: [CellaProspetto], larghezze w: [CGFloat]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(tabella.colonne.enumerated()), id: \.offset) { i, colonna in
                cella(i < riga.count ? riga[i] : .t(""), destra: colonna.destra)
                    .frame(width: max(0, w[i] - 8), alignment: colonna.destra ? .trailing : .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    @ViewBuilder private func cella(_ c: CellaProspetto, destra: Bool) -> some View {
        if let canale = c.canale {
            EtichettaCanale(canale: canale, compatta: true)
                .scaleEffect(M.scalaEtichetta, anchor: destra ? .trailing : .leading)
        } else {
            Text(verbatim: c.testo)
                .font(c.forte ? Tipo.Carta.tabellaForte : Tipo.Carta.tabella)
                .foregroundColor(c.tenue ? Colori.Carta.testoTenue : Colori.Carta.testo)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
        }
    }
}

/// Grafico di proiezione su carta: linee nette, griglia leggera, versato tratteggiato.
struct GraficoCarta: View {
    let serie: [SerieGraficoProspetto]

    static func colore(_ t: SerieGraficoProspetto.Tono) -> Color {
        switch t {
        case .atteso, .primo: return Colori.Carta.atteso
        case .prudente, .secondo: return Colori.Carta.prudente
        case .favorevole: return Colori.Carta.favorevole
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let sinistra: CGFloat = 46
                let basso: CGFloat = 14
                let w = max(1, geo.size.width - sinistra - 4)
                let h = max(1, geo.size.height - basso - 4)
                let tutti = serie.flatMap(\.punti)
                let massimo = max(tutti.map { max($0.valore, $0.versato) }.max() ?? 1, 1) * 1.06
                let anni = max(tutti.map(\.anno).max() ?? 1, 1)
                let x: (Int) -> CGFloat = { sinistra + CGFloat($0) / CGFloat(anni) * w }
                let y: (Double) -> CGFloat = { 4 + h - CGFloat($0 / massimo) * h }
                ZStack(alignment: .topLeading) {
                    ForEach(0...4, id: \.self) { i in
                        let v = massimo * Double(i) / 4
                        Path { p in
                            p.move(to: CGPoint(x: sinistra, y: y(v)))
                            p.addLine(to: CGPoint(x: sinistra + w, y: y(v)))
                        }
                        .stroke(Colori.Carta.griglia, lineWidth: 0.6)
                        Text(verbatim: Formati.euroBreve(v)).font(Tipo.Carta.assi).foregroundColor(Colori.Carta.testoTenue)
                            .frame(width: sinistra - 6, alignment: .trailing)
                            .position(x: (sinistra - 6) / 2, y: y(v))
                    }
                    ForEach(etichetteAnni(anni), id: \.self) { a in
                        Text(verbatim: a == 0 ? "Oggi" : "+\(a)").font(Tipo.Carta.assi).foregroundColor(Colori.Carta.testoTenue)
                            .position(x: x(a), y: geo.size.height - basso / 2)
                    }
                    if let base = serie.first(where: { $0.tono == .atteso }) ?? serie.first {
                        Path { p in
                            for (i, pt) in base.punti.enumerated() {
                                let q = CGPoint(x: x(pt.anno), y: y(pt.versato))
                                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                            }
                        }
                        .stroke(Colori.Carta.versato, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    ForEach(Array(serie.enumerated()), id: \.offset) { _, s in
                        Path { p in
                            for (i, pt) in s.punti.enumerated() {
                                let q = CGPoint(x: x(pt.anno), y: y(pt.valore))
                                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                            }
                        }
                        .stroke(Self.colore(s.tono), style: StrokeStyle(lineWidth: s.tono == .atteso || s.tono == .primo ? 1.8 : 1.2, lineJoin: .round))
                    }
                }
            }
            .frame(height: M.grafico)
            HStack(spacing: 14) {
                ForEach(Array(serie.enumerated()), id: \.offset) { _, s in
                    HStack(spacing: 5) {
                        Rectangle().fill(Self.colore(s.tono)).frame(width: 14, height: 2)
                        Text(verbatim: s.nome).font(Tipo.Carta.assi).foregroundColor(Colori.Carta.testo).lineLimit(1)
                    }
                }
                HStack(spacing: 5) {
                    Rectangle().stroke(Colori.Carta.versato, style: StrokeStyle(lineWidth: 1, dash: [3, 2])).frame(width: 14, height: 0.5)
                    Text(verbatim: "Versato").font(Tipo.Carta.assi).foregroundColor(Colori.Carta.testo)
                }
                Spacer(minLength: 0)
            }
            .frame(height: M.legenda - 4)
        }
    }

    private func etichetteAnni(_ anni: Int) -> [Int] {
        let passo = max(1, Int((Double(anni) / 8).rounded(.up)))
        var elenco = Array(stride(from: 0, to: anni, by: passo))
        elenco.append(anni)
        return elenco
    }
}

// MARK: - Il tavolo dell'anteprima

/// Le pagine su un tavolo di lino chiaro, come la sala di lettura dei Documenti del template.
struct TavoloCarta: View {
    let contenuto: ContenutoProspetto
    var genere = "Prospetto di dettaglio"
    var scala: CGFloat = 1

    var body: some View {
        let pagine = ImpaginatoreProspetto.pagine(contenuto)
        VStack(spacing: 22) {
            ForEach(Array(pagine.enumerated()), id: \.offset) { i, p in
                PaginaCarta(contenuto: contenuto, blocchi: p, numero: i + 1, totale: pagine.count, genere: genere)
                    .scaleEffect(scala, anchor: .top)
                    .frame(width: M.pagina.width * scala, height: M.pagina.height * scala, alignment: .top)
                    .shadow(color: Colori.Carta.ombraFoglio, radius: 5, x: 0, y: 3)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}
