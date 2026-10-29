import SwiftUI

// MARK: - Gettoni della griglia dell'esperienza (Clienti › Profilo)

extension Tema.Misura {
    /// Griglia dell'esperienza per tipo di prodotto (Clienti › Profilo).
    enum Esperienza {
        static let colonnaTipo: CGFloat = 200
        static let colonnaDomanda: CGFloat = 78
        static let colonnaLivello: CGFloat = 124
        static let casella = CGSize(width: 52, height: 22)
        static let margineCella = EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        static let spazioSezione: CGFloat = 10
        static let spazioColonnaPrisma: CGFloat = 6
        static let larghezzaCapacita: CGFloat = 470
        /// Spazio tra la riga di spiegazione e il pulsante del metodo, e tra le righe del piede.
        static let spazioRiga: CGFloat = 8
        /// Spazio tra l'etichetta della capacità e il suo testo.
        static let spazioCapacita: CGFloat = 4
    }
}

extension Tema.Colore {
    enum Esperienza {
        static let si = Tema.Colore.fondoInEssere
        static let testoSi = Tema.Colore.testoInEssere
        /// «No» a «conosce» o «ha capito»: un problema.
        static let no = Tema.Colore.Componenti.fondoErrore
        static let testoNo = Tema.Colore.scadenzaOra
        /// «No» a «ha avuto»: un'informazione, non un problema.
        static let noNeutro = Tema.Colore.pozzettoScuro
        static let testoNoNeutro = Tema.Colore.inchiostroSecondario
        static let vuota = Tema.Colore.pozzetto
        static let testoVuota = Tema.Colore.inchiostroTerziario
        static let bordoCasella = Tema.Colore.separatore
    }
}

extension Tema.Testo {
    enum Esperienza {
        static let casella = Tema.Testo.pill
    }
}

extension Tema.Raggio {
    enum Esperienza {
        static let casella: CGFloat = Tema.Raggio.tasto
    }
}

extension LivelloEsperienza {
    /// Il tono della pillola del livello: verde se lo conosce, ambra da spiegare, rosso se non lo conosce.
    var tono: Pillola.Tono {
        switch self {
        case .esperto, .conosce: return .ok
        case .daSpiegare: return .attenzione
        case .nonConosce: return .errore
        case .daChiedere: return .neutro
        }
    }
}

// MARK: - Componenti puri

/// Una casella a tre stati: «Sì», «No», «—». Un clic passa al successivo (— → Sì → No → —).
struct CasellaEsperienza: View {
    let valore: Bool?
    let domanda: DomandaEsperienza
    let tipo: TipoProdotto
    let cambia: (Bool?) -> Void

    private typealias C = Tema.Colore.Esperienza
    private typealias M = Tema.Misura.Esperienza

    static func successivo(_ v: Bool?) -> Bool? { v == nil ? true : (v == true ? false : nil) }

    private var testo: String {
        switch valore {
        case .some(true): return "Sì"
        case .some(false): return "No"
        case .none: return "—"
        }
    }

    private var statoAttuale: String {
        switch valore {
        case .some(true): return "sì"
        case .some(false): return "no"
        case .none: return "non indicato"
        }
    }

    private var colori: (fondo: Color, testo: Color) {
        switch valore {
        case .some(true): return (C.si, C.testoSi)
        // Non averlo avuto non è un problema: grigio, non rosso
        case .some(false): return domanda == .haAvuto ? (C.noNeutro, C.testoNoNeutro) : (C.no, C.testoNo)
        case .none: return (C.vuota, C.testoVuota)
        }
    }

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: Tema.Raggio.Esperienza.casella, style: .continuous)
        Button { cambia(Self.successivo(valore)) } label: {
            Text(testo)
                .font(Tema.Testo.Esperienza.casella)
                .foregroundColor(colori.testo)
                .frame(width: M.casella.width, height: M.casella.height)
                .background { forma.fill(colori.fondo) }
                .overlay { forma.strokeBorder(C.bordoCasella, lineWidth: Tema.Misura.filo).allowsHitTesting(false) }
                .animation(Movimenti.curva(Tema.Moto.Controlli.segmenti), value: valore)
        }
        .buttonStyle(StileSemplice())
        .help("\(domanda.titolo) · \(tipo.nome): \(domanda.domanda) Ora: \(statoAttuale). Clic per cambiare.")
    }
}

/// La griglia dei 7 tipi × 3 domande, con livello e posizioni in Prisma.
struct GrigliaEsperienza: View {
    let esperienza: EsperienzaProdotti?
    let inEssere: [TipoProdotto: [Posizione]]
    let suggerimenti: [SuggerimentoEsperienza]
    let rispondi: (TipoProdotto, DomandaEsperienza, Bool?) -> Void

    private typealias M = Tema.Misura.Esperienza

    var body: some View {
        VStack(spacing: 0) {
            testa
            ForEach(Array(TipoProdotto.allCases.enumerated()), id: \.element) { i, t in
                riga(t, indice: i)
            }
        }
        .contornoTabella()
    }

    private var testa: some View {
        HStack(spacing: 0) {
            Text("Tipo di prodotto").frame(width: M.colonnaTipo, alignment: .leading)
            ForEach(DomandaEsperienza.allCases) { d in
                Text(d.titolo).frame(width: M.colonnaDomanda)
            }
            Text("Livello").frame(width: M.colonnaLivello, alignment: .leading)
            Text("In Prisma").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(Tipo.tabellaTesta)
        .foregroundColor(Colori.Analisi.tabellaTesta)
        .lineLimit(1)
        .padding(M.margineCella)
        .background(Colori.Analisi.tabellaTestaAlto)
        .bordoBasso(Colori.Analisi.tabellaRiga)
    }

    private func riga(_ t: TipoProdotto, indice i: Int) -> some View {
        let voce = esperienza?.voce(t) ?? VoceEsperienza(tipo: t)
        let livello = MotoreEsperienza.livello(voce)
        return HStack(spacing: 0) {
            Text(t.nome)
                .font(Tipo.tabellaCellaForte)
                .foregroundColor(Colori.Analisi.tabellaTesto)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: M.colonnaTipo, alignment: .leading)
                .help(t.esempi)
            ForEach(DomandaEsperienza.allCases) { d in
                CasellaEsperienza(valore: voce[d], domanda: d, tipo: t) { rispondi(t, d, $0) }
                    .frame(width: M.colonnaDomanda)
            }
            HStack(spacing: 0) {
                Pillola(testo: livello.nome, tono: livello.tono)
            }
            .frame(width: M.colonnaLivello, alignment: .leading)
            inPrisma(t)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(M.margineCella)
        .background(i % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
        .bordoBasso(Colori.Analisi.tabellaRiga)
    }

    /// Le posizioni in essere di quel tipo con il loro canale e, se serve, il suggerimento «ha avuto».
    @ViewBuilder private func inPrisma(_ t: TipoProdotto) -> some View {
        let posizioni = inEssere[t] ?? []
        let suggerimento = suggerimenti.first { $0.tipo == t }
        if posizioni.isEmpty && suggerimento == nil {
            Text("—").font(Tipo.chip).foregroundColor(Tema.Colore.inchiostroTerziario)
        } else {
            VStack(alignment: .leading, spacing: M.spazioColonnaPrisma) {
                if !posizioni.isEmpty {
                    HStack(spacing: M.spazioColonnaPrisma) {
                        Text("\(posizioni.count) in essere")
                            .font(Tipo.chip)
                            .foregroundColor(Colori.Analisi.tabellaTesto)
                            .lineLimit(1)
                        // Il canale resta riconoscibile accanto alle posizioni
                        ForEach(Canale.allCases.filter { c in posizioni.contains { $0.canale == c } }) { c in
                            EtichettaCanale(canale: c, compatta: true)
                        }
                    }
                }
                if let s = suggerimento {
                    Button("Segna \"ha avuto\"") { rispondi(t, .haAvuto, true) }
                        .buttonStyle(StileSemplice())
                        .font(Tipo.colonnaCollegamento)
                        .foregroundColor(Colori.Colonna.collegamento)
                        .help("Già in Prisma: " + s.posizioni.map(\.nome).joined(separator: ", "))
                }
            }
        }
    }
}
