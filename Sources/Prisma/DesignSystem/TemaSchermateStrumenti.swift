import SwiftUI

// MARK: - Gettoni delle schermate degli strumenti (tema Liquid Glass)
// Analisi 360, Simulazioni, Confronti, Prodotti, Obiettivi, Incontri, Documenti, Prospetti e report,
// Ricerca e Impostazioni: quello che non sta tra i gettoni comuni del tema.

extension Tema.Colore {
    /// Colori delle schermate degli strumenti.
    enum Strumenti {
        /// Il tavolo attorno ai fogli nelle anteprime dei prospetti e dei report: un grigio freddo in chiaro,
        /// la notte del cielo in scuro. I fogli restano chiari (sono la carta del PDF).
        static let tavoloAlto = Color.dinamico(chiaro: Color(hex: "#DFE4E8"), scuro: Color(hex: "#0B1A24"))
        static let tavoloBasso = Color.dinamico(chiaro: Color(hex: "#E9ECEF"), scuro: Color(hex: "#0E202B"))
        /// Ombra dei fogli sul tavolo: più decisa in scuro, perché il foglio chiaro non «galleggi».
        static let ombraFoglio = Color.dinamico(chiaro: Color(r: 38, g: 52, b: 53, a: 0.18),
                                                scuro: Color(r: 0, g: 0, b: 0, a: 0.5))
        /// Fondo dei file trascinati sopra i Documenti (accento appena accennato).
        static let rilascio: Color = Tema.Colore.accento.opacity(0.06)
    }
}

extension Tema.Raggio {
    /// Raggi delle schermate degli strumenti.
    enum Strumenti {
        /// Schede delle aree (Analisi 360), degli obiettivi, delle due voci dei Confronti, carte degli Incontri.
        static let scheda: CGFloat = Tema.Raggio.scheda
        /// Riquadri dentro le schede: risultato del simulatore, pannelli d'uso dei Documenti, testo letto.
        static let riquadro: CGFloat = Tema.Raggio.kpi
        /// Righe scelte negli elenchi interni (prodotti, documenti, valutazioni, posizioni, obiettivi).
        static let voceElenco: CGFloat = Tema.Raggio.voceLaterale
        /// Proposte ricavate dagli appunti degli Incontri.
        static let proposta: CGFloat = Tema.Raggio.riga
        /// Campi di testo su più righe (appunti, commento del report).
        static let campoLungo: CGFloat = Tema.Raggio.miniatura
        /// Caselle dei rischi coperti e scoperti (Analisi 360 · Protezione).
        static let casellaRischio: CGFloat = Tema.Raggio.miniatura
        /// Etichetta della priorità sugli obiettivi.
        static let priorita: CGFloat = Tema.Raggio.tasto
        /// Cornice tratteggiata dei file trascinati sopra i Documenti.
        static let rilascio: CGFloat = Tema.Raggio.scheda
    }
}

extension Tema.Misura {
    /// Misure delle schermate degli strumenti.
    enum Strumenti {
        /// Barretta colorata dell'area dentro le schede: larghezza, stacco dal bordo sinistro e dall'alto/basso.
        static let barretta: CGFloat = 3
        static let staccoBarretta: CGFloat = 6
        static let margineBarretta: CGFloat = 12
        /// Contorno d'accento della scheda scelta (obiettivi).
        static let bordoScelta: CGFloat = 2
        /// Elenchi interni a voci arrotondate: margine ai lati e spazio tra le voci.
        static let margineElenco: CGFloat = 6
        static let spazioVoci: CGFloat = 2
        /// Cornice tratteggiata dei file trascinati sopra i Documenti.
        static let bordoRilascio: CGFloat = 2
        static let trattiRilascio: [CGFloat] = [8, 5]
        /// Spazio tra i fogli sul tavolo delle anteprime e margine sopra e sotto.
        static let spazioFogli: CGFloat = 22
        static let margineTavolo: CGFloat = 20
        /// Schede delle quattro aree nella panoramica di Analisi 360: altezza minima (riempiono la pagina
        /// invece di lasciare un vuoto sotto), riga d'intestazione alta uguale con o senza priorità e spazio tra le sue voci.
        static let schedaAreaPanoramica: CGFloat = 190
        static let testataSchedaArea: CGFloat = 16
        static let spazioTestataArea: CGFloat = 8
    }
}

extension Tema.Testo {
    /// Caratteri delle schermate degli strumenti.
    enum Strumenti {
        /// Casella di spunta disegnata (proposte degli Incontri).
        static let spunta = Tema.Testo.sf(14)
        /// Icona del tipo di documento nell'elenco dei Documenti.
        static let iconaDocumento = Tema.Testo.sf(16)
        /// Il vassoio della zona di rilascio dei Documenti.
        static let iconaRilascio = Tema.Testo.sf(40, .light)
        /// Il testo letto da un documento, pagina per pagina (a spaziatura fissa).
        static let testoLetto = Font.system(size: 12 * Tipo.fattore, design: .monospaced)
    }
}

extension Tema.Ombra {
    /// Ombre delle schermate degli strumenti.
    enum Strumenti {
        /// Il foglio sul tavolo delle anteprime (0 3px 10px).
        static let foglio = StratoOmbra(colore: Tema.Colore.Strumenti.ombraFoglio, y: 3, sfocatura: 10)
    }
}

extension View {
    /// Scheda di un'area o di un obiettivo (Analisi 360, Obiettivi, Confronti): vetro sottile arrotondato
    /// del tema con la barretta colorata dell'area dentro il bordo sinistro; con `scelta` il contorno d'accento.
    /// Va messo dopo padding e frame del contenuto, come `.vetro`.
    func schedaColorata(_ colore: Color, scelta: Bool = false, raggio: CGFloat = Tema.Raggio.Strumenti.scheda) -> some View {
        let forma = FormaVetro.arrotondata(raggio)
        let m = Tema.Misura.Strumenti.self
        return self
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(colore)
                    .frame(width: m.barretta)
                    .padding(.vertical, m.margineBarretta)
                    .padding(.leading, m.staccoBarretta)
                    .allowsHitTesting(false)
            }
            .vetro(.sottile, forma: forma)
            .overlay {
                if scelta {
                    forma.strokeBorder(Tema.Colore.accento, lineWidth: m.bordoScelta).allowsHitTesting(false)
                }
            }
    }

    /// Voce di un elenco interno (prodotti, documenti, valutazioni…): fondo leggero al passaggio,
    /// accento al 17% se scelta, angoli arrotondati e un piccolo stacco ai lati (niente più fascia piena).
    func voceElencoStrumento(attiva: Bool) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .fondoPassaggio(.arrotondata(Tema.Raggio.Strumenti.voceElenco), sopra: Tema.Colore.rigaSopra, selezionata: attiva)
            .contentShape(Rectangle())
            .padding(.horizontal, Tema.Misura.Strumenti.margineElenco)
            .padding(.vertical, Tema.Misura.Strumenti.spazioVoci / 2)
    }

    /// Riquadro dentro una pagina degli strumenti: vetro sottile del tema (scheda chiara o scura secondo l'aspetto).
    func riquadroStrumento(raggio: CGFloat = Tema.Raggio.Strumenti.riquadro) -> some View {
        vetro(.sottile, forma: .arrotondata(raggio))
    }

    /// Campo di testo su più righe (appunti, commento): pozzetto arrotondato del tema con il filo sottile.
    func pozzettoTestoLungo(raggio: CGFloat = Tema.Raggio.Strumenti.campoLungo) -> some View {
        let forma = FormaVetro.arrotondata(raggio)
        return self
            .background { forma.fill(Tema.Colore.pozzetto) }
            .overlay { forma.strokeBorder(Tema.Colore.separatore, lineWidth: Tema.Misura.filo).allowsHitTesting(false) }
    }
}
