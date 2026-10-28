import SwiftUI

// MARK: - Barra della composizione di una multiramo

/// La barra a due colori di una multiramo: gestione separata e fondi, larghi come le quote, staccati e
/// arrotondati come la barra dei canali. Sopra, se richiesto, le etichette «Gestione separata 40% · 24.800 €»
/// e «Fondi 60% · 37.200 €».
struct BarraComposizione: View {
    /// Quota (0–1) in gestione separata.
    let gestione: Double
    /// Euro della parte in gestione separata e dei fondi (nil: solo le quote).
    var euroGestione: Double? = nil
    var euroFondi: Double? = nil
    /// false: solo la barra (per esempio sotto il cursore della quota, che ha già il suo riepilogo).
    var conEtichette = true

    private typealias M = Tema.Misura.Multiramo
    private typealias C = Tema.Colore.Multiramo

    private var quotaLimitata: Double { min(max(gestione, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: M.spazioBarra) {
            if conEtichette {
                HStack(alignment: .firstTextBaseline, spacing: M.spazioRiga) {
                    etichetta(C.gestione, "Gestione separata", quotaLimitata, euroGestione)
                    Spacer(minLength: M.spazioRiga)
                    etichetta(C.fondi, "Fondi", 1 - quotaLimitata, euroFondi)
                }
            }
            barra
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gestione separata \(Self.percento(quotaLimitata)), fondi \(Self.percento(1 - quotaLimitata))")
    }

    private var barra: some View {
        GeometryReader { geo in
            let q = quotaLimitata
            let stacco: CGFloat = (q > 0 && q < 1) ? M.staccoBarra : 0
            let utile = max(0, geo.size.width - stacco)
            HStack(spacing: stacco) {
                if q > 0 {
                    RoundedRectangle(cornerRadius: M.raggioBarra, style: .continuous)
                        .fill(C.gestione)
                        .frame(width: q < 1 ? utile * CGFloat(q) : utile)
                }
                if q < 1 {
                    RoundedRectangle(cornerRadius: M.raggioBarra, style: .continuous)
                        .fill(C.fondi)
                }
            }
        }
        .frame(height: M.barra)
    }

    private func etichetta(_ colore: Color, _ nome: String, _ q: Double, _ euro: Double?) -> some View {
        HStack(alignment: .center, spacing: M.spazioEtichetta * 2) {
            Circle()
                .fill(colore)
                .frame(width: M.pallino, height: M.pallino)
            Text("\(nome) \(Self.percento(q))" + (euro.map { " · \(Formati.euro($0))" } ?? ""))
                .font(Tema.Testo.Multiramo.barra)
                .foregroundColor(C.testoBarra)
                .lineLimit(1)
        }
    }

    /// "40%": la quota (0–1) in percentuale.
    static func percento(_ q: Double) -> String { Formati.percentuale(q * 100) }
}

/// Il pallino del colore di una parte con il suo nome: testata delle colonne e legende.
struct PallinoParte: View {
    let colore: Color
    let testo: String

    var body: some View {
        HStack(alignment: .center, spacing: Tema.Misura.Multiramo.spazioEtichetta * 2) {
            Circle()
                .fill(colore)
                .frame(width: Tema.Misura.Multiramo.pallino, height: Tema.Misura.Multiramo.pallino)
            Text(testo)
                .font(Tema.Testo.Multiramo.testataColonna)
                .foregroundColor(Tema.Colore.inchiostro)
        }
    }
}
