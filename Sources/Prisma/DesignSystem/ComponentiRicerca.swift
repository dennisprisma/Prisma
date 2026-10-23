import SwiftUI

// «Cerca ovunque»: tabella raggruppata alla maniera di iOS 5 (fondo a righe sottili, intestazioni
// incise, celle bianche arrotondate, selezione blu lucida).

extension Colori {
    enum Ricerca {
        static let fondoAlto = Color(hex: "#d3d8de")
        static let fondoBasso = Color(hex: "#c5ccd4")
        static let righe = Color(r: 255, g: 255, b: 255, a: 0.18)
        static let barraAlto = Color(hex: "#e8ebee")
        static let barraBasso = Color(hex: "#b9c1ca")
        static let barraBordo = Color(hex: "#8d97a3")
        static let barraLuce = Color(r: 255, g: 255, b: 255, a: 0.7)
        static let campoBordo = Color(hex: "#8e959d")
        static let lente = Color(hex: "#8a919a")
        static let tasto = Color(hex: "#6c7580")
        static let sezione = Color(hex: "#4c566c")
        static let sezioneIncisione = Color(r: 255, g: 255, b: 255, a: 0.8)
        static let cella = Color.white
        static let cellaBordo = Color(hex: "#abb2ba")
        static let separatore = Color(hex: "#e0e0e0")
        static let titolo = Color(hex: "#1f2328")
        static let dettaglio = Color(hex: "#6d7480")
        static let estratto = Color(hex: "#3d5a80")
        static let freccia = Color(hex: "#9aa1aa")
        static let selezioneAlto = Color(hex: "#058cf5")
        static let selezioneBasso = Color(hex: "#015fe6")
        static let selezioneTesto = Color.white
        static let selezioneDettaglio = Color(hex: "#dce9fb")
        static let vuotoTitolo = Color(hex: "#4c566c")
        static let vuotoTesto = Color(hex: "#6d7480")
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
        static let campoAltezza: CGFloat = 32
        static let campoRaggio: CGFloat = 16
        static let barraMargine = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        static let raggioCella: CGFloat = 9
        static let icona: CGFloat = 30
        static let margineRiga = EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        static let spazioSezioni: CGFloat = 16
        static let margineContenuto: CGFloat = 16
        static let righeFondo: CGFloat = 7
    }
}

extension Tipo {
    static let ricercaCampo = Tipo.sistema(15)
    static let ricercaSezione = Tipo.sistema(13, .bold)
    static let ricercaTitolo = Tipo.sistema(13, .semibold)
    static let ricercaDettaglio = Tipo.sistema(11)
    static let ricercaEstratto = Tipo.sistema(11).italic()
    static let ricercaTasto = Tipo.sistema(11, .medium)
}

/// Fondo a righe verticali sottili della tabella raggruppata di iOS.
struct FondoRicerca: View {
    var body: some View {
        ZStack {
            Gradienti.fondoRicerca
            RigheRicerca().fill(Colori.Ricerca.righe)
        }
    }
}

/// Le righe verticali del fondo (una forma, non un Canvas: niente Metal).
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
            Text("›")
                .font(Tipo.rubricaFreccia)
                .foregroundColor(selezionata ? Colori.Ricerca.selezioneTesto : Colori.Ricerca.freccia)
        }
        .padding(Misure.Ricerca.margineRiga)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selezionata ? AnyShapeStyle(Gradienti.selezioneRicerca) : AnyShapeStyle(Colori.Ricerca.cella))
        .contentShape(Rectangle())
    }
}
