import SwiftUI

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

/// Fascia in cuoio chiaro cucito dell'agenda (.ag-leather).
struct CuoioAgenda<Contenuto: View>: View {
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        let forma = RettangoloAngoli(altoSinistra: Misure.Agenda.cuoioRaggio, altoDestra: Misure.Agenda.cuoioRaggio)
        contenuto()
            .padding(Misure.Agenda.cuoioMargine)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Gradienti.cuoioAgenda
                    Materiale.Trama(nome: "Grana")
                }
                .clipShape(forma)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Colori.Agenda.cuoioCucitura, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .shadow(color: Colori.Agenda.cuoioCucituraOmbra, radius: 0, x: 0, y: 1)
                    .opacity(0.8)
                    .padding(Misure.Agenda.cucitura)
                    .allowsHitTesting(false)
            )
            .luceInterna(Colori.Agenda.cuoioLuce, raggio: Misure.Agenda.cuoioRaggio)
            .ombraInternaBasso(Colori.Agenda.cuoioLuceBasso)
            .overlay(forma.stroke(Colori.Agenda.cuoioBordo, lineWidth: 1))
    }
}

/// Targhetta con la data, leggermente ruotata (.ag-date-badge).
struct TarghettaData: View {
    let giorno: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(Formati.meseBreve.string(from: giorno).uppercased())
                .font(Tipo.targhettaMese)
                .tracking(1.5)
                .foregroundColor(.white)
                .incisione(Colori.Agenda.targhettaRossoIncisione, y: -1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Gradienti.targhettaRossa)
                .luceInterna(Colori.Agenda.targhettaRossoLuce)
                .bordoBasso(Colori.Agenda.targhettaRossoBordo)
            Text(Formati.giorno.string(from: giorno))
                .font(Tipo.targhettaGiorno)
                .foregroundColor(Colori.Agenda.targhettaTesto)
                .padding(.top, 1)
            Text(Formati.giornoSettimana.string(from: giorno))
                .font(Tipo.targhettaSettimana)
                .foregroundColor(Colori.Agenda.targhettaTesto)
                .padding(.bottom, 4)
        }
        .frame(width: Misure.Agenda.targhetta)
        .background(Colori.Agenda.targhettaCarta)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Colori.Agenda.targhettaBordo, lineWidth: 1))
        .shadow(color: Colori.Agenda.targhettaOmbra1, radius: 0, x: 0, y: 1)
        .shadow(color: Colori.Agenda.targhettaOmbra2, radius: 0, x: 0, y: 2)
        .ombraCSS(Colori.Agenda.targhettaOmbra3, x: 1, y: 3, sfocatura: 3)
        .rotationEffect(.degrees(3))
    }
}

/// Anelli cromati della rilegatura (.ag-rings).
struct AnelliAgenda: View {
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<Misure.Agenda.anelli, id: \.self) { i in
                    if i > 0 { Spacer(minLength: 0) }
                    RoundedRectangle(cornerRadius: Misure.Agenda.anello.width / 2)
                        .fill(Gradienti.anelloAgenda)
                        .overlay(RoundedRectangle(cornerRadius: Misure.Agenda.anello.width / 2)
                            .strokeBorder(Colori.Agenda.anelloBordo, lineWidth: 1))
                        .luceInterna(Color.white.opacity(0.45), raggio: Misure.Agenda.anello.width / 2)
                        .frame(width: Misure.Agenda.anello.width, height: Misure.Agenda.anello.height)
                        .ombraCSS(Colori.Agenda.anelloOmbra, x: 1, y: 1, sfocatura: 2)
                }
            }
            .padding(.horizontal, geo.size.width * Misure.Agenda.rientroAnelli)
        }
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

/// Voce "etichetta · valore" del dettaglio (le righe <dl> del template).
struct VoceDettaglio<Valore: View>: View {
    let etichetta: String
    var larghezza: CGFloat = Misure.Agenda.etichettaVoce
    var coloreEtichetta = Colori.Agenda.voceEtichetta
    var coloreBordo = Colori.Agenda.voceBordo
    @ViewBuilder let valore: () -> Valore

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(etichetta)
                .font(Tipo.voceEtichetta)
                .foregroundColor(coloreEtichetta)
                .frame(width: larghezza, alignment: .leading)
            valore()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .bordoBasso(coloreBordo)
    }
}

/// Etichetta minuscola in maiuscoletto ("✓ Concluso", "Scade").
struct EtichettaStato: View {
    let testo: String
    let colore: Color
    let fondo: Color

    var body: some View {
        Text(testo.uppercased())
            .font(Tipo.etichettaStato)
            .tracking(0.4)
            .foregroundColor(colore)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 3).fill(fondo))
            .fixedSize()
    }
}

/// Pulsante di vetro che riempie la sua cella (azioni del dettaglio).
struct PulsanteAzione: View {
    let titolo: String
    var principale = false
    let azione: () -> Void

    var body: some View {
        if principale {
            Button(action: azione) {
                Text(titolo).lineLimit(1).frame(maxWidth: .infinity)
            }
            .buttonStyle(StileBlu())
        } else {
            Button(action: azione) {
                Text(titolo).font(Tipo.pulsantePiccolo).lineLimit(1).frame(maxWidth: .infinity)
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)))
        }
    }
}
