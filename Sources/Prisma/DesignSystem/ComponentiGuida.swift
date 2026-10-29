import SwiftUI

// Proprietario: G7 (guida). Le «i» accanto alle parole tecniche, i vuoti che spiegano che cosa fare,
// il percorso tipico e i puntini delle pagine dell'introduzione. Gettoni in TemaGuida.swift.

/// La «i» accanto a un'etichetta tecnica: il suggerimento dice la riga breve, il clic apre la scheda della parola.
/// Sui documenti (`\.etichetteStampa`) non c'è. Lo stato si legge solo nell'azione, mai nel `body`.
struct InfoTermine: View {
    @EnvironmentObject var stato: StatoShell
    let voce: VoceGlossario
    @State private var aperta = false
    @Environment(\.etichetteStampa) private var stampa

    var body: some View {
        if !stampa {
            let m = Tema.Misura.Guida.self
            Button { aperta.toggle() } label: {
                Image(systemName: "info.circle")
                    .font(Tema.Testo.Guida.info)
                    .foregroundColor(Tema.Colore.Guida.info)
                    .frame(width: m.infoTocco, height: m.infoTocco)
                    // Area di clic di 28 pt senza alzare la riga
                    .contentShape(Rectangle().inset(by: -Tema.Misura.Componenti.allargamentoClic))
            }
            .buttonStyle(StileSemplice())
            .help("\(voce.termine): \(voce.breve)")
            .accessibilityLabel("Che cosa vuol dire \(voce.termine)")
            .popover(isPresented: $aperta, arrowEdge: .bottom) {
                SchedaTermine(voce: voce) {
                    aperta = false
                    stato.apriGuida(.glossario(voce.chiave))
                }
            }
        }
    }
}

/// Il popover della «i»: termine, per esteso, spiegazione, esempio, «Apri nel glossario».
struct SchedaTermine: View {
    let voce: VoceGlossario
    let apriGlossario: () -> Void

    var body: some View {
        let m = Tema.Misura.Guida.self
        VStack(alignment: .leading, spacing: m.spazioScheda) {
            VStack(alignment: .leading, spacing: m.spazioTermine) {
                Text(voce.termine)
                    .font(Tema.Testo.Guida.titoloApp)
                    .foregroundColor(Tema.Colore.inchiostro)
                if let esteso = voce.perEsteso {
                    Text(esteso)
                        .font(Tema.Testo.Guida.perEsteso)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
            }
            Text(voce.breve)
                .font(Tema.Testo.titolo)
                .foregroundColor(Tema.Colore.inchiostro)
                .fixedSize(horizontal: false, vertical: true)
            Text(voce.spiegazione)
                .font(Tema.Testo.corpo)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineSpacing(Tema.Testo.Guida.interlinea)
                .fixedSize(horizontal: false, vertical: true)
            if let esempio = voce.esempio {
                EsempioGuida(testo: esempio)
            }
            Button(action: apriGlossario) {
                Label("Apri nel glossario", systemImage: "book")
            }
            .buttonStyle(StileCollegamento())
        }
        .padding(m.margineScheda)
        .frame(width: m.schedaTermine, alignment: .leading)
    }
}

/// «Per esempio»: il pozzetto con le cifre di una voce.
struct EsempioGuida: View {
    let testo: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Guida.spazioEsempio) {
            Text("PER ESEMPIO")
                .font(Tema.Testo.occhiello)
                .foregroundColor(Tema.Colore.Guida.titoloBlocco)
            Text(testo)
                .font(Tema.Testo.corpo)
                .foregroundColor(Tema.Colore.inchiostro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tema.Misura.Guida.esempioMargine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Tema.Raggio.Guida.esempio, style: .continuous)
                .fill(Tema.Colore.Guida.fondoEsempio)
        }
    }
}

/// Un'etichetta che mette da sé la «i» se il suo testo ha una voce nel glossario.
struct EtichettaConTermine: View {
    let testo: String
    let font: Font
    let colore: Color
    /// Righe al massimo del testo (nil: senza limite).
    var righe: Int? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Tema.Misura.Guida.spazioInfo) {
            Text(testo)
                .font(font)
                .foregroundColor(colore)
                .lineLimit(righe)
            if let v = Glossario.voce(perEtichetta: testo) {
                InfoTermine(voce: v)
            }
        }
    }
}

/// Vuoto iniziale che spiega: icona, titolo, perché serve, tre passi, pulsante principale e, se serve, uno
/// secondario. Si mostra solo quando non c'è proprio niente (non quando un filtro non trova risultati).
struct VuotoGuidato: View {
    /// Simbolo SF.
    let icona: String
    let titolo: String
    let perche: String
    /// (titolo breve, frase): esattamente 3.
    let passi: [(String, String)]
    let pulsante: String
    let azione: () -> Void
    var secondario: (String, () -> Void)? = nil

    var body: some View {
        // Nelle finestre basse il vuoto scorre invece di tagliarsi
        ViewThatFits(in: .vertical) {
            contenuto
            ScrollView { contenuto }
        }
    }

    private var contenuto: some View {
        let m = Tema.Misura.Guida.self
        return VStack(spacing: m.spazioVuoto) {
            Image(systemName: icona)
                .font(Tema.Testo.Guida.iconaVuoto)
                .foregroundColor(Tema.Colore.Guida.iconaVuoto)
                .frame(width: m.cerchioVuoto, height: m.cerchioVuoto)
                .background { Circle().fill(Tema.Colore.Guida.cerchioVuoto) }
                .accessibilityHidden(true)
            Text(titolo)
                .font(Tema.Testo.Guida.titoloVuoto)
                .foregroundColor(Tema.Colore.inchiostro)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(perche)
                .font(Tema.Testo.Guida.percheVuoto)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .multilineTextAlignment(.center)
                .lineSpacing(Tema.Testo.Guida.interlinea / 2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: m.spazioPasso) {
                ForEach(Array(passi.enumerated()), id: \.offset) { i, p in
                    passo(i + 1, p.0, p.1)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: m.spazioPasso) {
                if let s = secondario {
                    Button(action: s.1) { Text(s.0) }
                        .buttonStyle(StileVetro(taglia: .grande))
                }
                Button(action: azione) {
                    Label(pulsante, systemImage: pulsante.hasPrefix("Importa") ? "square.and.arrow.down" : "plus")
                }
                .buttonStyle(StileBlu(taglia: .grande))
            }
        }
        .padding(m.vuotoMargine)
        .frame(maxWidth: m.vuotoLarghezza)
        .frame(maxWidth: .infinity)
    }

    private func passo(_ numero: Int, _ titolo: String, _ testo: String) -> some View {
        let m = Tema.Misura.Guida.self
        return VStack(alignment: .leading, spacing: m.spazioScheda / 2) {
            HStack(spacing: m.spazioNumeroPasso) {
                NumeroPasso(numero: numero)
                Text(titolo)
                    .font(Tema.Testo.Guida.titoloPassoVuoto)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(testo)
                .font(Tema.Testo.Guida.testoPassoVuoto)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(m.esempioMargine)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .riquadroStrumento()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Passo \(numero): \(titolo). \(testo)")
    }
}

/// Il cerchio numerato di un passo (fondo d'accento, cifra bianca).
struct NumeroPasso: View {
    let numero: Int

    var body: some View {
        let lato = Tema.Misura.Guida.numeroPasso
        Text("\(numero)")
            .font(Tema.Testo.Guida.numeroPasso)
            .foregroundColor(Tema.Colore.Guida.numeroPassoTesto)
            .frame(width: lato, height: lato)
            .background { Circle().fill(Tema.Colore.Guida.numeroPasso) }
            .accessibilityHidden(true)
    }
}

/// Il percorso tipico di Prisma: Cliente → Posizioni → Analisi → Prospetto, quattro icone con il nome e le
/// frecce in mezzo.
struct PercorsoTipico: View {
    private static let tappe: [(AppPrisma, String)] = [
        (.clienti, "Il cliente"), (.posizioni, "Le posizioni"), (.analisi360, "L'analisi"), (.presentazioni, "Il prospetto"),
    ]

    var body: some View {
        let m = Tema.Misura.Guida.self
        HStack(alignment: .top, spacing: m.spazioPercorso) {
            ForEach(Array(PercorsoTipico.tappe.enumerated()), id: \.offset) { i, tappa in
                if i > 0 {
                    Image(systemName: "arrow.right")
                        .font(Tema.Testo.Guida.percorso)
                        .foregroundColor(Tema.Colore.Guida.frecciaPercorso)
                        .frame(height: m.iconaPercorso)
                        .accessibilityHidden(true)
                }
                VStack(spacing: m.spazioPercorsoNome) {
                    IconaApp(app: tappa.0, lato: m.iconaPercorso)
                    Text(tappa.1)
                        .font(Tema.Testo.Guida.percorso)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Il percorso tipico: il cliente, le sue posizioni, l'analisi, il prospetto.")
    }
}

/// I puntini delle pagine dell'introduzione: quello della pagina attuale si allunga.
struct PuntiPagine: View {
    let numero: Int
    let attuale: Int

    var body: some View {
        let m = Tema.Misura.Guida.self
        HStack(spacing: m.spazioPuntiPagina) {
            ForEach(0..<max(0, numero), id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(i == attuale ? Tema.Colore.Guida.puntoPaginaAttivo : Tema.Colore.Guida.puntoPagina)
                    .frame(width: i == attuale ? m.puntoPaginaAttivo : m.puntoPagina, height: m.puntoPagina)
            }
        }
        .animation(Movimenti.curva(Tema.Moto.Guida.pagina), value: attuale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pagina \(attuale + 1) di \(numero)")
    }
}
