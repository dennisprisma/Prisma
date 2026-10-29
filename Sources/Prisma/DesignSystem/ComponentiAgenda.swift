import SwiftUI

extension Tema.Misura.Componenti {
    /// Pulsanti delle azioni del dettaglio: solo il margine laterale, l'altezza la dà la taglia.
    static let margineAzione = EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
}

extension Tema.Testo.Componenti {
    /// Il giorno nella tessera grande dell'agenda.
    static let giornoTarghetta = Tema.Testo.sf(28, .semibold, arrotondato: true)
}

/// Calendario dell'agenda: settimane da lunedì, nomi italiani.
enum CalendarioAgenda {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Formati.italiano
        c.firstWeekday = 2
        return c
    }()

    static let nomiGiorni = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]

    static func lunedi(di giorno: Date) -> Date {
        cal.dateInterval(of: .weekOfYear, for: giorno)?.start ?? cal.startOfDay(for: giorno)
    }

    static func giorni(settimanaDi giorno: Date) -> [Date] {
        let inizio = lunedi(di: giorno)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: inizio) }
    }

    /// Le settimane (da lunedì) che coprono il mese del giorno indicato.
    static func settimane(meseDi giorno: Date) -> [[Date]] {
        guard let mese = cal.dateInterval(of: .month, for: giorno) else { return [giorni(settimanaDi: giorno)] }
        var settimane: [[Date]] = []
        var inizio = lunedi(di: mese.start)
        while inizio < mese.end {
            settimane.append(giorni(settimanaDi: inizio))
            inizio = cal.date(byAdding: .day, value: 7, to: inizio) ?? mese.end
        }
        return settimane
    }

    /// "1h 30m", "45 min".
    static func durata(_ minuti: Int) -> String {
        guard minuti >= 60 else { return "\(minuti) min" }
        return minuti % 60 == 0 ? "\(minuti / 60)h" : "\(minuti / 60)h \(minuti % 60)m"
    }
}

/// Fascia in testa all'agenda: una scheda del tema (.card) che si stende per tutta la larghezza.
struct CuoioAgenda<Contenuto: View>: View {
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        contenuto()
            .padding(Misure.Agenda.cuoioMargine)
            .frame(maxWidth: .infinity)
            .vetro(.sottile, forma: .arrotondata(Tema.Raggio.scheda))
    }
}

/// Tessera con la data del giorno (.dt in grande): mese rosso, giorno, giorno della settimana.
struct TarghettaData: View {
    let giorno: Date

    var body: some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.tessera)
        VStack(spacing: 0) {
            Text(Formati.meseBreve.string(from: giorno).uppercased())
                .font(Tema.Testo.meseTessera)
                .tracking(Tema.Testo.spaziatura(0.04, 9.5))
                .foregroundColor(Tema.Colore.rosso)
                .padding(.top, 6)
            Text(Formati.giorno.string(from: giorno))
                .font(Tema.Testo.Componenti.giornoTarghetta)
                .foregroundColor(Tema.Colore.inchiostro)
            Text(Formati.giornoSettimana.string(from: giorno))
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 6)
        }
        .frame(width: Misure.Agenda.targhetta)
        .background { forma.fill(Tema.Colore.tesseraData).ombraTema(Tema.Ombra.tesseraData) }
        .overlay { forma.strokeBorder(Tema.Colore.bordoChip, lineWidth: Tema.Misura.filo).allowsHitTesting(false) }
    }
}

/// Gli anelli della rilegatura non ci sono più nel tema: resta lo spazio, vuoto.
struct AnelliAgenda: View {
    var body: some View {
        Color.clear
            .frame(height: Misure.Agenda.anello.height)
            .allowsHitTesting(false)
    }
}

/// Righe orizzontali della carta, a passo fisso.
struct Rigatura: Shape {
    let passo: CGFloat
    var inizio: CGFloat = 0

    func path(in r: CGRect) -> Path {
        var p = Path()
        var y = r.minY + inizio + passo - 1
        while y < r.maxY {
            p.addRect(CGRect(x: r.minX, y: y, width: r.width, height: 1))
            y += passo
        }
        return p
    }
}

/// Voce "etichetta · valore" del dettaglio (.kv del tema).
struct VoceDettaglio<Valore: View>: View {
    let etichetta: String
    var larghezza: CGFloat = Misure.Agenda.etichettaVoce
    var coloreEtichetta: Color = Tema.Colore.inchiostroSecondario
    var coloreBordo: Color = Tema.Colore.separatore
    @ViewBuilder let valore: () -> Valore

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(etichetta)
                .font(Tema.Testo.corpo)
                .foregroundColor(coloreEtichetta)
                .frame(width: larghezza, alignment: .leading)
            valore()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(coloreBordo).frame(height: Tema.Misura.filo)
        }
    }
}

/// Etichetta di stato in capsula ("✓ Concluso", "Scade"), come le pillole del tema.
struct EtichettaStato: View {
    let testo: String
    let colore: Color
    let fondo: Color

    var body: some View {
        Text(testo)
            .font(Tema.Testo.pill)
            .foregroundColor(colore)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: Tema.Misura.pill)
            .background { FormaVetro.capsula.fill(fondo) }
            .fixedSize()
    }
}

/// Pulsante che riempie la sua cella (azioni del dettaglio), in vetro da 32 pt con l'icona davanti.
/// `principale`: l'azione consigliata, in vetro con il colore dell'accento (il blu resta uno per finestra,
/// nell'intestazione o nella barra). Un glifo davanti al titolo («＋ », «✦ », «✓ ») diventa l'icona SF
/// corrispondente e una freccia in coda (« →») si toglie: il titolo resta lo stesso, senza il glifo.
struct PulsanteAzione: View {
    let titolo: String
    var principale = false
    /// Simbolo SF davanti al titolo (i glifi come "▤" nel font di sistema diventano quadratini).
    var simbolo: String? = nil
    let azione: () -> Void

    /// I glifi di testo che diventano icone SF (davanti al titolo).
    static let glifi: [(String, String)] = [("＋", "plus"), ("+", "plus"), ("✦", "sparkles"), ("✓", "checkmark"),
                                             ("▶", "play.fill")]

    /// Titolo senza glifi e simbolo da mettere davanti (quello dato, o quello del glifo).
    static func separa(_ titolo: String, simbolo: String?) -> (titolo: String, simbolo: String?) {
        var testo = titolo.trimmingCharacters(in: .whitespaces)
        var icona = simbolo
        for (glifo, nome) in glifi where testo.hasPrefix(glifo + " ") {
            testo = String(testo.dropFirst(glifo.count)).trimmingCharacters(in: .whitespaces)
            if icona == nil { icona = nome }
            break
        }
        for coda in [" →", " ›"] where testo.hasSuffix(coda) {
            testo = String(testo.dropLast(coda.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        return (testo, icona)
    }

    var body: some View {
        let parti = PulsanteAzione.separa(titolo, simbolo: simbolo)
        Button(action: azione) {
            Group {
                if let icona = parti.simbolo {
                    Label(parti.titolo, systemImage: icona)
                } else {
                    Text(parti.titolo)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(StileVetro(margine: Tema.Misura.Componenti.margineAzione, taglia: .normale, accento: principale))
    }
}
