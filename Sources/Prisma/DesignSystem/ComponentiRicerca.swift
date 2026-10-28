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

// MARK: - Pannello ⌘K (come Spotlight)

/// L'icona di un risultato: avatar per i clienti, tessera con il simbolo per le azioni, icona dell'app per il resto.
struct IconaRisultatoRicerca: View {
    let risultato: RisultatoRicerca
    /// Il cliente del risultato (solo per il gruppo Clienti).
    var cliente: Cliente?
    var lato: CGFloat = Misure.Spotlight.icona

    var body: some View {
        if let c = cliente {
            AvatarCliente(iniziali: c.iniziali, tinta: c.tinta.colori, lato: lato)
        } else if let a = risultato.azione {
            TesseraAzioneRicerca(simbolo: a.simbolo, lato: lato)
        } else {
            IconaApp(app: risultato.app, lato: lato)
        }
    }
}

/// Tessera neutra con il simbolo di un'azione rapida, alta quanto le icone delle app.
struct TesseraAzioneRicerca: View {
    let simbolo: String
    let lato: CGFloat

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: Tema.Raggio.iconaApp(lato), style: .continuous)
        Image(systemName: simbolo)
            .font(lato > Misure.Spotlight.icona ? Tipo.spotlightSimboloAnteprima : Tipo.spotlightSimboloAzione)
            .foregroundColor(Colori.Spotlight.simboloAzione)
            .frame(width: lato, height: lato)
            .background(forma.fill(Colori.Spotlight.tesseraAzione))
            .overlay(forma.strokeBorder(Colori.Spotlight.separatore, lineWidth: Tema.Misura.filo))
    }
}

/// Una riga dei risultati del pannello (.sr-i): icona, titolo, dettaglio, riga trovata e pallino del canale.
/// Scelta: accento al 18%; al passaggio un velo leggero.
struct RigaSpotlight: View {
    let risultato: RisultatoRicerca
    let selezionata: Bool
    var cliente: Cliente?

    var body: some View {
        let m = Misure.Spotlight.self
        HStack(spacing: m.rigaSpazio) {
            IconaRisultatoRicerca(risultato: risultato, cliente: cliente)
            VStack(alignment: .leading, spacing: m.rigaTestoSpazio) {
                Text(risultato.titolo)
                    .font(Tipo.spotlightTitolo)
                    .foregroundColor(Colori.Spotlight.titolo)
                if !risultato.dettaglio.isEmpty {
                    Text(risultato.dettaglio)
                        .font(Tipo.spotlightDettaglio)
                        .foregroundColor(Colori.Spotlight.dettaglio)
                }
                if let e = risultato.estratto {
                    Text(e)
                        .font(Tipo.spotlightEstratto)
                        .foregroundColor(Colori.Spotlight.estratto)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            // Nella riga stretta il canale resta il suo colore (versione compatta)
            if let c = risultato.canale {
                Circle()
                    .fill(Tema.Colore.canale(c))
                    .frame(width: Tema.Misura.pallinoCanale, height: Tema.Misura.pallinoCanale)
                    .help(c.nome)
            }
        }
        .padding(m.rigaMargine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fondoPassaggio(.arrotondata(Tema.Raggio.voceRicerca), sopra: Colori.Spotlight.sopra,
                        selezionata: selezionata, selezione: Colori.Spotlight.selezione)
        .contentShape(Rectangle())
    }
}

/// Pillola del pannello: un suggerimento da toccare (pozzetto), un filtro riconosciuto (accento) o a metà (arancio).
struct PillolaSpotlight: View {
    enum Tono { case suggerimento, filtro, incompleto }

    let testo: String
    var nota: String? = nil
    var tono: Tono = .suggerimento
    /// Non privato: con uno stato privato l'inizializzatore per membri non si vedrebbe dagli altri file.
    @State var sopra = false

    var body: some View {
        let m = Misure.Spotlight.self
        let colori: (fondo: Color, testo: Color) = {
            switch tono {
            case .suggerimento: return (sopra ? Colori.Spotlight.pillolaSopra : Colori.Spotlight.pillola, Colori.Spotlight.pillolaTesto)
            case .filtro: return (Colori.Spotlight.filtro, Colori.Spotlight.filtroTesto)
            case .incompleto: return (Colori.Spotlight.incompleto, Colori.Spotlight.incompletoTesto)
            }
        }()
        HStack(spacing: m.pillolaSpazio) {
            Text(testo).font(Tipo.spotlightPillola).foregroundColor(colori.testo)
            if let nota {
                Text(nota).font(Tipo.spotlightPillolaNota).foregroundColor(Colori.Spotlight.pillolaNota)
            }
        }
        .lineLimit(1)
        .padding(m.pillolaMargine)
        .frame(minHeight: m.pillolaAltezza)
        .background(FormaVetro.capsula.fill(colori.fondo))
        .fixedSize()
        .onHover { sopra = $0 }
    }
}

/// Il totale di un canale nei risultati filtrati: capsula in vetro del colore del canale (blu Alleanza con il
/// simbolo, cuoio indipendente), numero di posizioni e valore.
struct TotaleCanaleSpotlight: View {
    let totale: TotaleCanaleRicerca

    var body: some View {
        let c = totale.canale
        HStack(spacing: Misure.Spotlight.totaleSpazio) {
            EtichettaCanale(canale: c, compatta: true)
            Text("\(totale.numero) · \(Formati.euro(totale.valore))")
                .font(Tipo.spotlightPillola)
                .foregroundColor(Tema.Colore.canale(c))
                .monospacedDigit()
        }
        .lineLimit(1)
        .fixedSize()
    }
}

/// Una cifra dell'anteprima: etichetta a sinistra, valore a destra, filo sotto.
struct CifraAnteprimaRicerca: View {
    let etichetta: String
    let valore: String
    var ultima = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(etichetta)
                .font(Tipo.spotlightCifraEtichetta)
                .foregroundColor(Colori.Spotlight.etichettaCifra)
            Spacer(minLength: Misure.Spotlight.rigaSpazio)
            Text(valore)
                .font(Tipo.spotlightCifraValore)
                .foregroundColor(Colori.Spotlight.valoreCifra)
                .multilineTextAlignment(.trailing)
        }
        .lineLimit(1)
        .padding(.vertical, Misure.Spotlight.cifraMargineVerticale)
        .bordoBasso(ultima ? Color.clear : Colori.Spotlight.separatore)
    }
}
