import SwiftUI

// Completezza dei dati per l'analisi (specifica 7): il riquadro della Panoramica del cliente.
// Viste pure, senza StatoShell: le azioni arrivano da chi le usa (AppClienti).

/// «Dati per l'analisi» nella Panoramica del cliente: percentuale e livello, barra, analisi che girano su
/// ipotesi, le voci da completare (le prime cinque, poi «Mostra tutte») e le voci segnate «non pertinenti».
/// Vetro sottile come le tessere di FasciaMetriche.
struct RiquadroCompletezza: View {
    let completezza: CompletezzaCliente
    let completa: (VoceCompletezza) -> Void
    let escludi: (VoceCompletezza) -> Void
    let ripristina: () -> Void
    @State private var tutte = false

    var body: some View {
        let c = completezza
        let m = Tema.Misura.Completezza.self
        VStack(alignment: .leading, spacing: m.spazioBlocchi) {
            testa(c)
            BarraCompletezza(quota: c.quota, livello: c.livello)
            if c.daCompletare.isEmpty {
                HStack(spacing: m.spazioRiga) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Tema.Colore.Completezza.completo)
                    Text(TestiCompletezza.tuttoCompleto)
                        .font(Tema.Testo.corpo)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: m.spazioTesto) {
                    Text(TestiCompletezza.riepilogo(c))
                    Text(TestiCompletezza.toccate(c))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(mostrate(c)) { v in
                        RigaVoceCompletezza(voce: v, completa: { completa(v) }, escludi: { escludi(v) })
                    }
                }
            }
            piede(c)
        }
        .padding(m.riquadro)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.tessera))
    }

    /// Le voci in vista: le prime `massimoPanoramica`, o tutte.
    private func mostrate(_ c: CompletezzaCliente) -> [VoceCompletezza] {
        tutte ? c.daCompletare : Array(c.daCompletare.prefix(MotoreCompletezza.massimoPanoramica))
    }

    private func testa(_ c: CompletezzaCliente) -> some View {
        HStack(alignment: .center, spacing: Tema.Misura.Completezza.spazioRiga) {
            Text(TestiCompletezza.occhiello)
                .font(Tema.Testo.occhiello)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
            Spacer(minLength: Tema.Misura.Completezza.spazioRiga)
            Pillola(testo: c.livello.nome, tono: tono(c.livello))
            Text(verbatim: "\(c.percentuale)%")
                .font(Tema.Testo.Completezza.percentuale)
                .foregroundColor(Tema.Colore.Completezza.livello(c.livello))
                .help(TestiCompletezza.metodo)
        }
    }

    @ViewBuilder private func piede(_ c: CompletezzaCliente) -> some View {
        let molte = c.daCompletare.count > MotoreCompletezza.massimoPanoramica
        if molte || !c.escluse.isEmpty {
            HStack(spacing: Tema.Misura.Completezza.spazioRiga) {
                if molte {
                    Button(tutte ? TestiCompletezza.mostraMeno : TestiCompletezza.mostraTutte(c.daCompletare.count)) {
                        withAnimation(Tema.Moto.sezioneRipiegabile) { tutte.toggle() }
                    }
                    .buttonStyle(StileSemplice())
                    .font(Tema.Testo.Completezza.collegamento)
                    .foregroundColor(Tema.Colore.Completezza.collegamento)
                }
                Spacer(minLength: 0)
                if !c.escluse.isEmpty {
                    Text(TestiCompletezza.escluse(c.escluse.count) + " ·")
                        .font(Tema.Testo.didascalia)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                    Button(TestiCompletezza.ripristina, action: ripristina)
                        .buttonStyle(StileSemplice())
                        .font(Tema.Testo.Completezza.collegamento)
                        .foregroundColor(Tema.Colore.Completezza.collegamento)
                        .help(TestiCompletezza.aiutoRipristina)
                }
            }
        }
    }

    private func tono(_ l: LivelloCompletezza) -> Pillola.Tono {
        switch l {
        case .completo: return .ok
        case .parziale: return .attenzione
        case .scarso: return .errore
        }
    }
}

/// La barra della completezza: capsula in pozzetto riempita fino alla quota, nel colore del livello.
struct BarraCompletezza: View {
    let quota: Double
    let livello: LivelloCompletezza

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.Colore.Completezza.traccia)
                Capsule().fill(Tema.Colore.Completezza.livello(livello))
                    .frame(width: g.size.width * min(max(quota, 0), 1))
            }
        }
        .frame(height: Tema.Misura.Completezza.barra)
        .animation(Tema.Moto.sezioneRipiegabile, value: quota)
        .accessibilityElement()
        .accessibilityLabel(TestiCompletezza.occhiello)
        .accessibilityValue(Text(verbatim: "\(Int((quota * 100).rounded()))%"))
    }
}

/// Una voce da completare: pallino dello stato, titolo e ipotesi usata, analisi toccate, canale della
/// posizione (sempre riconoscibile), «Completa» e la croce «non pertinente».
/// Chip, canale e pulsanti restano interi: se la riga non basta si tolgono prima i chip delle analisi,
/// poi chip, canale e azioni scendono in una seconda riga sotto il testo.
struct RigaVoceCompletezza: View {
    let voce: VoceCompletezza
    let completa: () -> Void
    let escludi: () -> Void

    var body: some View {
        let m = Tema.Misura.Completezza.self
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: m.spazioRiga) {
                pallino
                testo
                chipAnalisi
                azioni
            }
            HStack(alignment: .center, spacing: m.spazioRiga) {
                pallino
                testo
                azioni
            }
            dueRighe
        }
        .padding(.vertical, m.margineVoce)
        .contentShape(Rectangle())
        .help(voce.perche)
    }

    /// La riga stretta: il testo sopra, sotto (rientrati sotto il testo) chip, canale e azioni.
    private var dueRighe: some View {
        let m = Tema.Misura.Completezza.self
        return VStack(alignment: .leading, spacing: m.spazioRighe) {
            HStack(alignment: .center, spacing: m.spazioRiga) {
                pallino
                testo
            }
            HStack(alignment: .center, spacing: m.spazioRiga) {
                chipAnalisi
                Spacer(minLength: 0)
                azioni
            }
            .padding(.leading, m.pallino + m.spazioRiga)
        }
    }

    private var pallino: some View {
        let m = Tema.Misura.Completezza.self
        return Circle()
            .fill(Tema.Colore.Completezza.stato(voce.stato))
            .frame(width: m.pallino, height: m.pallino)
            .help(voce.stato.nome)
    }

    /// Titolo e ipotesi: prendono lo spazio che resta. La larghezza ideale è fissa, così la scelta della
    /// disposizione non dipende dalla lunghezza dell'ipotesi (che va a capo).
    private var testo: some View {
        let m = Tema.Misura.Completezza.self
        return VStack(alignment: .leading, spacing: m.spazioTesto) {
            Text(voce.titolo)
                .font(Tema.Testo.corpo)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
            if !voce.ipotesi.isEmpty {
                Text(voce.ipotesi)
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(m.righeIpotesi)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minWidth: m.testoVoceMinimo, idealWidth: m.testoVoceIdeale, maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var chipAnalisi: some View {
        let m = Tema.Misura.Completezza.self
        return HStack(spacing: m.spazioRiga) {
            ForEach(voce.analisiOrdinate.prefix(m.chipPerVoce)) { a in
                Chip(testo: a.nome)
            }
        }
        .fixedSize()
    }

    /// Canale della posizione, «Completa» e la croce: sempre interi.
    private var azioni: some View {
        let m = Tema.Misura.Completezza.self
        return HStack(alignment: .center, spacing: m.spazioRiga) {
            if let canale = voce.canale {
                EtichettaCanale(canale: canale, compatta: true)
            }
            Button(TestiCompletezza.completa, action: completa)
                .buttonStyle(StileVetro(margine: m.marginePulsante))
                .help(TestiCompletezza.aiutoCompleta)
            Button(action: escludi) {
                Image(systemName: "xmark")
                    .font(Tema.Testo.Completezza.croce)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
            }
            .buttonStyle(StileSemplice())
            .help(TestiCompletezza.aiutoNonPertinente)
            .accessibilityLabel(TestiCompletezza.nonPertinente)
        }
        .fixedSize()
    }
}
