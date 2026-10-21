import SwiftUI

// MARK: - Pulsanti

/// Pulsante di vetro della scrivania (.os-glass-button).
struct StileVetro: ButtonStyle {
    var margine = Misure.Pulsante.vetroMargine

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tipo.pulsanteVetro)
            .foregroundColor(Colori.Pulsante.testo)
            .incisione(Colori.Barra.incisione)
            .padding(margine)
            .background(
                RoundedRectangle(cornerRadius: Misure.Pulsante.raggio).fill(Gradienti.vetro)
            )
            .luceInterna(.white, raggio: Misure.Pulsante.raggio)
            .overlay(RoundedRectangle(cornerRadius: Misure.Pulsante.raggio).strokeBorder(Colori.Pulsante.vetroBordo, lineWidth: 1))
            .ombraCSS(Colori.Pulsante.vetroOmbra, y: 1, sfocatura: 2)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .contentShape(Rectangle())
    }
}

/// Pulsante principale blu iOS 5 (--ios5-button-bg).
struct StileBlu: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tipo.pulsanteBlu)
            .foregroundColor(.white)
            .incisione(Colori.Pulsante.bluIncisione, y: -1)
            .padding(Misure.Pulsante.bluMargine)
            .background(RoundedRectangle(cornerRadius: Misure.Pulsante.raggioBlu).fill(Gradienti.pulsanteBlu))
            .luceInterna(Colori.Pulsante.bluLuce, raggio: Misure.Pulsante.raggioBlu)
            .overlay(RoundedRectangle(cornerRadius: Misure.Pulsante.raggioBlu).strokeBorder(Colori.Pulsante.bluBordo, lineWidth: 1))
            .shadow(color: Colori.Pulsante.bluRiflesso, radius: 0, x: 0, y: 1)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .contentShape(Rectangle())
    }
}

/// Pulsante senza decorazioni che si scurisce appena alla pressione.
struct StileSemplice: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Controllo a segmenti

/// Controllo a segmenti grafite (Lion), come le schede della colonna della scrivania.
struct Segmentato<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(opzioni.enumerated()), id: \.offset) { indice, opzione in
                let attivo = opzione.0 == selezione
                Button {
                    selezione = opzione.0
                } label: {
                    Text(opzione.1)
                        .font(Tipo.colonnaScheda)
                        .foregroundColor(attivo ? .white : Colori.Pulsante.testo)
                        .incisione(attivo ? Color.black.opacity(0.25) : Colori.Barra.incisione, y: attivo ? -1 : 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(attivo ? AnyShapeStyle(Gradienti.segmentoAttivo) : AnyShapeStyle(Gradienti.vetro))
                        .overlay(alignment: .top) {
                            if attivo {
                                LinearGradient(colors: [Colori.Pulsante.segmentoAttivoOmbra, .clear], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 3)
                            } else {
                                Rectangle().fill(Color.white).frame(height: 1)
                            }
                        }
                }
                .buttonStyle(StileSemplice())
                if indice < opzioni.count - 1 {
                    Rectangle().fill(Colori.Pulsante.segmentoBordo).frame(width: 1)
                }
            }
        }
        .frame(height: Misure.Colonna.schedeAltezza)
        .clipShape(RoundedRectangle(cornerRadius: Misure.Colonna.schedeRaggio))
        .overlay(RoundedRectangle(cornerRadius: Misure.Colonna.schedeRaggio).strokeBorder(Colori.Pulsante.segmentoBordo, lineWidth: 1))
    }
}

// MARK: - Badge

/// Badge rosso lucido con il numero (app e notifiche).
struct Badge: View {
    let numero: Int
    var grande = true

    var body: some View {
        let lato = grande ? Misure.Scrivania.badge : Misure.Barra.badge
        let bordo: CGFloat = grande ? 2 : 1
        Text("\(numero)")
            .font(grande ? Tipo.badgeGrande : Tipo.badgePiccolo)
            .foregroundColor(.white)
            .incisione(grande ? Colori.Badge.grandeIncisione : Colori.Badge.piccoloIncisione, y: -1)
            .frame(minWidth: lato, minHeight: lato)
            .padding(.horizontal, numero > 9 ? 3 : 0)
            .background(Capsule().fill(grande ? Gradienti.badgeGrande : Gradienti.badgePiccolo))
            .overlay(alignment: .top) {
                if grande {
                    Capsule().fill(Colori.Badge.grandeLuce).frame(height: 1).padding(.horizontal, 5).padding(.top, bordo)
                }
            }
            .overlay(Capsule().strokeBorder(Color.white, lineWidth: bordo))
            .ombraCSS(Colori.Badge.ombra, y: grande ? 2 : 1, sfocatura: grande ? 4 : 2)
            .fixedSize()
    }
}

// MARK: - Semafori della finestra

struct Semafori: View {
    let attiva: Bool
    let chiudi: () -> Void
    let riduci: () -> Void
    let ingrandisci: () -> Void
    @State var sopra = false

    var body: some View {
        HStack(spacing: Misure.Finestra.spazioSemafori) {
            pulsante(Colori.Semafori.chiudi, (0, 0.45, 0.95), Colori.Semafori.chiudiBordo, "×", chiudi)
            pulsante(Colori.Semafori.riduci, (0, 0.48, 0.95), Colori.Semafori.riduciBordo, "−", riduci)
            pulsante(Colori.Semafori.ingrandisci, (0, 0.46, 0.95), Colori.Semafori.ingrandisciBordo, "+", ingrandisci)
        }
        .onHover { sopra = $0 }
    }

    private func pulsante(_ colori: [Color], _ fermate: (CGFloat, CGFloat, CGFloat), _ bordo: Color,
                          _ simbolo: String, _ azione: @escaping () -> Void) -> some View {
        let lato = Misure.Finestra.semaforo
        let colorato = attiva || sopra
        return Button(action: azione) {
            ZStack {
                if colorato {
                    Circle().fill(Gradienti.semaforo(colori, fermate: fermate, lato: lato))
                } else {
                    Circle().fill(LinearGradient.verticale(Colori.Semafori.inattivoAlto, Colori.Semafori.inattivoBasso))
                }
                // inset 0 1px 1px #fff8 / inset 0 -1px 1px #0003
                Circle().strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.5), .clear, Color.black.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                ).padding(1)
                Circle().strokeBorder(colorato ? bordo : Colori.Semafori.inattivoBordo, lineWidth: 1)
                if sopra {
                    Text(simbolo).font(Tipo.semaforo).foregroundColor(Colori.Semafori.simbolo).offset(y: -0.5)
                }
            }
            .frame(width: lato, height: lato)
            .shadow(color: Color.white.opacity(0.5), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(StileSemplice())
    }
}

// MARK: - Avatar

struct AvatarCliente: View {
    let iniziali: String
    let tinta: Colori.Avatar.Tinta
    var lato: CGFloat = Misure.Colonna.avatar

    var body: some View {
        Text(iniziali)
            .font(Tipo.contenuto(lato * 0.33, .medium))
            .foregroundColor(tinta.testo)
            .incisione(Color.white.opacity(0.76))
            .frame(width: lato, height: lato)
            .background(Circle().fill(Gradienti.avatar(tinta)))
            .overlay(alignment: .top) {
                Circle().trim(from: 0.6, to: 0.9).stroke(Colori.Avatar.luce, lineWidth: 1).padding(1.5)
            }
            .overlay(Circle().strokeBorder(tinta.bordo, lineWidth: 1))
            .ombraCSS(Colori.Avatar.ombra, y: 1, sfocatura: 2)
    }
}

// MARK: - Piastrella data (agenda della scrivania)

struct PiastrellaData: View {
    let data: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(Formati.giorno.string(from: data))
                .font(Tipo.dataGiorno)
                .foregroundColor(Colori.Colonna.dataGiorno)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(Formati.meseBreve.string(from: data))
                .font(Tipo.dataMese)
                .foregroundColor(Colori.Colonna.dataMeseTesto)
                .frame(maxWidth: .infinity)
                .frame(height: Misure.Colonna.dataMese)
                .background(Gradienti.dataMese)
                .bordoAlto(Colori.Colonna.dataMeseBordo)
                .clipShape(RettangoloAngoli(bassoDestra: 2, bassoSinistra: 2))
                .padding([.horizontal, .bottom], 1)
        }
        .frame(width: Misure.Colonna.data.width, height: Misure.Colonna.data.height)
        .background(RoundedRectangle(cornerRadius: Misure.Colonna.dataRaggio).fill(Gradienti.data))
        .luceInterna(.white, raggio: Misure.Colonna.dataRaggio)
        .overlay(RoundedRectangle(cornerRadius: Misure.Colonna.dataRaggio).strokeBorder(Colori.Colonna.dataBordo, lineWidth: 1))
        .ombraCSS(Colori.Colonna.dataOmbra, y: 2, sfocatura: 2)
    }
}

// MARK: - Etichetta del canale

/// Canale di una posizione o di una proposta: sempre riconoscibile a colpo d'occhio.
struct EtichettaCanale: View {
    let canale: Canale
    var compatta = false

    var body: some View {
        let raggio: CGFloat = compatta ? 3 : Misure.Pulsante.raggioBlu
        HStack(spacing: compatta ? 4 : 6) {
            if canale == .alleanza {
                ImmagineRisorsa(percorso: "Loghi/Alleanza_simbolo.png", scala: 2)
                    .scaledToFit()
                    .frame(height: compatta ? 11 : 15)
            }
            Text(compatta ? canale.nomeBreve : canale.nome)
                .font(compatta ? Tipo.etichettaCanalePiccola : Tipo.etichettaCanale)
                .foregroundColor(.white)
                .incisione(canale == .alleanza ? Colori.Pulsante.bluIncisione : Colori.Pulsante.cuoioIncisione, y: -1)
                .lineLimit(1)
        }
        .padding(.horizontal, compatta ? 5 : 9)
        .padding(.vertical, compatta ? 2 : 4)
        .background(
            RoundedRectangle(cornerRadius: raggio)
                .fill(canale == .alleanza ? Gradienti.pulsanteBlu : Gradienti.pulsanteCuoio)
        )
        .luceInterna(Color.white.opacity(canale == .alleanza ? 0.33 : 0.45), raggio: raggio)
        .overlay(
            RoundedRectangle(cornerRadius: raggio)
                .strokeBorder(canale == .alleanza ? Colori.Pulsante.bluBordo : Colori.Pulsante.cuoioBordo, lineWidth: 1)
        )
        .fixedSize()
    }
}

// MARK: - Icone delle app

/// Icona di un'app. L'Agenda mostra la data del giorno, come su iOS 5.
struct IconaApp: View {
    let app: AppPrisma
    let lato: CGFloat

    var body: some View {
        Group {
            if app == .agenda {
                IconaAgenda(lato: lato)
            } else {
                ImmagineRisorsa(percorso: "Icone/\(app.icona).png")
            }
        }
        .frame(width: lato, height: lato)
    }
}

/// Icona Agenda: base senza data, mese e giorno scritti dall'app, vetro sopra.
/// Posizioni e proporzioni ricavate dai tracciati di Design/Icone/Agenda.svg (viewBox 256).
struct IconaAgenda: View {
    let lato: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { contesto in
            let oggi = contesto.date
            let u = lato / 256
            ZStack {
                ImmagineRisorsa(percorso: "Icone/Agenda_base.png")
                Text(Formati.meseBreve.string(from: oggi).uppercased())
                    .font(Tipo.agendaMese(lato))
                    .foregroundColor(Colori.Agenda.mese)
                    .shadow(color: Colori.Agenda.meseOmbra, radius: 0, x: 0, y: 1.2 * u)
                    .fixedSize()
                    .position(x: 128 * u, y: 40 * u + lato * 0.012)
                Text(Formati.giorno.string(from: oggi))
                    .font(Tipo.agendaGiorno(lato))
                    .foregroundStyle(Gradienti.agendaInchiostro)
                    .shadow(color: Color.black.opacity(0.2), radius: 0.25 * u, x: 0, y: 0.9 * u)
                    .fixedSize()
                    .position(x: 128.5 * u, y: 157.5 * u + lato * 0.058)
                ImmagineRisorsa(percorso: "Icone/Agenda_vetro.png")
            }
            .frame(width: lato, height: lato)
        }
    }
}

// MARK: - Avviso temporaneo (#os-toast)

struct VistaAvviso: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(Tipo.avviso)
            .foregroundColor(Colori.Avvisi.testo)
            .incisione(.black, y: -1)
            .padding(Misure.Avvisi.margine)
            .background(RoundedRectangle(cornerRadius: Misure.Avvisi.raggio).fill(Gradienti.avviso))
            .luceInterna(Colori.Avvisi.luce, raggio: Misure.Avvisi.raggio)
            .overlay(RoundedRectangle(cornerRadius: Misure.Avvisi.raggio).strokeBorder(Colori.Avvisi.bordo, lineWidth: 1))
            .ombraCSS(Colori.Avvisi.ombra, y: 4, sfocatura: 14)
    }
}

// MARK: - Formati

enum Formati {
    static let italiano = Locale(identifier: "it_IT")

    static func formato(_ schema: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = italiano
        f.dateFormat = schema
        return f
    }

    static let giorno = formato("d")
    static let meseBreve = formato("MMM")
    static let barraData = formato("EEE d MMM")
    static let ora = formato("HH:mm")
    static let dataOra = formato("d MMM yyyy, HH:mm")
    static let dataLunga = formato("EEEE d MMMM")
    static let giornoSettimana = formato("EEEE")
    static let dataEstesa = formato("d MMMM yyyy")
    static let dataBreve = formato("dd/MM/yyyy")
    /// Data proposta quando si indica una data di nascita (1 gennaio 1980).
    static let dataPredefinitaNascita = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1980, month: 1, day: 1)) ?? Date()
    static let meseAnno = formato("MMMM yyyy")
    /// Per i nomi dei file (nessun carattere vietato dal Finder).
    static let nomeFile = formato("yyyy-MM-dd HH.mm.ss")

    /// Per gli importi: separatori italiani (punto per le migliaia, virgola per i decimali), ma con il
    /// punto anche sulle cifre a quattro (7.650 €). Le regole it_IT non lo mettono sotto i 10.000;
    /// quelle tedesche sì, con gli stessi separatori e il simbolo dopo l'importo.
    static let localeImporti = Locale(identifier: "de_DE")

    static let euroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = localeImporti
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.maximumFractionDigits = 0
        return f
    }()

    static let numeroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = localeImporti
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f
    }()

    /// "12.345 €"
    static func euro(_ valore: Double) -> String {
        euroFormatter.string(from: NSNumber(value: valore.rounded())) ?? "\(Int(valore)) €"
    }

    static let euroDecimaliFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = localeImporti
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// "1,47 €"
    static func euroDecimali(_ valore: Double) -> String {
        euroDecimaliFormatter.string(from: NSNumber(value: valore)) ?? euro(valore)
    }

    /// "12,3k €" per gli assi dei grafici.
    static func euroBreve(_ valore: Double) -> String {
        abs(valore) >= 1000 ? "\(numeroFormatter.string(from: NSNumber(value: (valore / 1000).rounded())) ?? "")k €" : euro(valore)
    }

    /// "2,5%"
    static func percentuale(_ valore: Double) -> String {
        "\(numeroFormatter.string(from: NSNumber(value: valore)) ?? "\(valore)")%"
    }

    static func dimensione(_ byte: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: byte)
    }
}
