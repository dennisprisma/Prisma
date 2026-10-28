import SwiftUI

// «Cerca ovunque» nel tema Liquid Glass: campo in pozzetto, risultati raggruppati in schede chiare,
// voce scelta con l'accento al 18% (.spot e .sr-i del tema).

extension Colori {
    enum Ricerca {
        static let fondoAlto = Color.clear
        static let fondoBasso = Color.clear
        static let righe = Color.clear
        static let barraAlto = Color.clear
        static let barraBasso = Color.clear
        static let barraBordo = Tema.Colore.separatore
        static let barraLuce = Color.clear
        static let campoBordo = Tema.Colore.separatore
        static let lente = Tema.Colore.inchiostroTerziario
        static let tasto = Tema.Colore.inchiostroSecondario
        static let sezione = Tema.Colore.inchiostroSecondario
        static let sezioneIncisione = Color.clear
        static let cella = Tema.Colore.scheda
        static let cellaBordo = Tema.Colore.bordoScheda
        static let separatore = Tema.Colore.separatore
        static let titolo = Tema.Colore.inchiostro
        static let dettaglio = Tema.Colore.inchiostroSecondario
        static let estratto = Tema.Colore.inchiostroSecondario
        static let freccia = Tema.Colore.inchiostroTerziario
        static let selezioneAlto = Tema.Colore.selezioneRicerca
        static let selezioneBasso = Tema.Colore.selezioneRicerca
        static let selezioneTesto = Tema.Colore.inchiostro
        static let selezioneDettaglio = Tema.Colore.inchiostroSecondario
        static let vuotoTitolo = Tema.Colore.inchiostroSecondario
        static let vuotoTesto = Tema.Colore.inchiostroTerziario
    }
}

extension Gradienti {
    static let fondoRicerca = LinearGradient.verticale(Colori.Ricerca.fondoAlto, Colori.Ricerca.fondoBasso)
    static let barraRicerca = LinearGradient.verticale(Colori.Ricerca.barraAlto, Colori.Ricerca.barraBasso)
    static let selezioneRicerca = LinearGradient.verticale(Colori.Ricerca.selezioneAlto, Colori.Ricerca.selezioneBasso)
}

extension Misure {
    enum Ricerca {
        static let larghezzaMassima: CGFloat = 720
        static let campoAltezza: CGFloat = 36
        static let campoRaggio: CGFloat = 18
        static let barraMargine = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        static let raggioCella: CGFloat = Tema.Raggio.gruppo
        static let icona: CGFloat = 28
        static let margineRiga = EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
        static let spazioSezioni: CGFloat = 16
        static let margineContenuto: CGFloat = 16
        static let righeFondo: CGFloat = 7
    }
}

extension Tipo {
    static let ricercaCampo = Tema.Testo.sf(16)
    static let ricercaSezione = Tema.Testo.sf(11.5, .semibold)
    static let ricercaTitolo = Tema.Testo.sf(13, .semibold)
    static let ricercaDettaglio = Tema.Testo.sf(12)
    static let ricercaEstratto = Tema.Testo.sf(12).italic()
    static let ricercaTasto = Tema.Testo.tasto
}

/// Fondo dei risultati: nessuna trama, si vede il vetro della finestra.
struct FondoRicerca: View {
    var body: some View {
        Color.clear
    }
}

/// Righe verticali del vecchio fondo a righe (resta per compatibilità: oggi il fondo è trasparente).
struct RigheRicerca: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = rect.minX
        while x < rect.maxX {
            p.addRect(CGRect(x: x, y: rect.minY, width: 2, height: rect.height))
            x += Misure.Ricerca.righeFondo
        }
        return p
    }
}

/// Una riga dei risultati: icona dell'app, titolo, dettaglio, riga trovata e canale.
/// Scelta: accento al 18% (.sr-i del tema); al passaggio del mouse un velo leggero.
struct RigaRicerca: View {
    let risultato: RisultatoRicerca
    let selezionata: Bool

    var body: some View {
        HStack(spacing: 10) {
            IconaApp(app: risultato.app, lato: Misure.Ricerca.icona)
            VStack(alignment: .leading, spacing: 2) {
                Text(risultato.titolo)
                    .font(Tipo.ricercaTitolo)
                    .foregroundColor(selezionata ? Colori.Ricerca.selezioneTesto : Colori.Ricerca.titolo)
                if !risultato.dettaglio.isEmpty {
                    Text(risultato.dettaglio)
                        .font(Tipo.ricercaDettaglio)
                        .foregroundColor(selezionata ? Colori.Ricerca.selezioneDettaglio : Colori.Ricerca.dettaglio)
                }
                if let e = risultato.estratto {
                    Text(e)
                        .font(Tipo.ricercaEstratto)
                        .foregroundColor(selezionata ? Colori.Ricerca.selezioneDettaglio : Colori.Ricerca.estratto)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            if let c = risultato.canale { EtichettaCanale(canale: c, compatta: true) }
            Image(systemName: "chevron.right")
                .font(Tema.Testo.Componenti.frecciaRiga)
                .foregroundColor(Colori.Ricerca.freccia)
        }
        .padding(Misure.Ricerca.margineRiga)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fondoPassaggio(.arrotondata(Tema.Raggio.voceRicerca), sopra: Tema.Colore.rigaSopra,
                        selezionata: selezionata, selezione: Tema.Colore.selezioneRicerca)
        .background(Colori.Ricerca.cella)
        .contentShape(Rectangle())
    }
}
