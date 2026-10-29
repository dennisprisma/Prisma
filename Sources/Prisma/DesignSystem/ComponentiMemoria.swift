import SwiftUI

// Componenti della memoria del riesame (specifica 12, giro 6): righe delle variazioni, pannello in vetro,
// pallini dei semafori, linea del tempo delle fotografie. Solo schermate: il PDF usa i blocchi del prospetto.

/// Una variazione: freccia nel colore del verso, testo, etichetta del canale, differenza. Aiuto: «Prima: … · Oggi: …».
/// Solo la freccia e la differenza sono colorate: il testo resta inchiostro, così la riga si legge anche senza colori.
struct RigaVariazione: View {
    let variazione: VariazioneRiesame
    /// Riquadri brevi: senza differenza, testo secondario.
    var compatta = false

    private var simbolo: String {
        switch variazione.aumento {
        case true?: return "arrow.up.right"
        case false?: return "arrow.down.right"
        case nil: return "arrow.left.arrow.right"
        }
    }

    var body: some View {
        let m = Tema.Misura.Memoria.self
        let colore = Tema.Colore.Memoria.verso(variazione.verso)
        HStack(alignment: .firstTextBaseline, spacing: m.spazioRiga) {
            Image(systemName: simbolo)
                .font(Tema.Testo.Memoria.simbolo)
                .foregroundColor(colore)
                .frame(width: m.colonnaSimbolo)
            Text(variazione.testo)
                .font(compatta ? Tema.Testo.secondario : Tema.Testo.corpo)
                .foregroundColor(Tema.Colore.Memoria.testo)
                .fixedSize(horizontal: false, vertical: true)
            if compatta {
                if let c = variazione.canale { EtichettaCanale(canale: c, compatta: true) }
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: m.staccoMinimo)
                if let c = variazione.canale { EtichettaCanale(canale: c, compatta: true) }
                Text(variazione.differenza ?? "")
                    .font(Tema.Testo.Memoria.differenza)
                    .foregroundColor(colore)
                    .lineLimit(1)
                    .frame(minWidth: m.colonnaDifferenza, alignment: .trailing)
            }
        }
        .help("Prima: \(variazione.prima) · Oggi: \(variazione.oggi)")
    }
}

/// L'elenco delle variazioni in una carta di vetro, con «Mostra tutte (n)» / «Mostra meno» oltre `massimo`.
struct PannelloVariazioni: View {
    let variazioni: [VariazioneRiesame]
    let massimo: Int
    /// Riga in testa (il riassunto: «13 variazioni: 6 in meglio, 1 in peggio.»).
    var intestazione: String? = nil
    /// Il testo al posto dell'elenco quando non ci sono variazioni.
    var vuoto: String? = nil
    @State private var tutte = false

    var body: some View {
        let m = Tema.Misura.Memoria.self
        let mostrate = tutte ? variazioni : Array(variazioni.prefix(massimo))
        VStack(alignment: .leading, spacing: m.righePannello) {
            if let intestazione, !variazioni.isEmpty {
                Text(intestazione)
                    .font(Tema.Testo.secondario)
                    .foregroundColor(Tema.Colore.Memoria.secondario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if variazioni.isEmpty, let vuoto {
                Text(vuoto)
                    .font(Tema.Testo.corpo)
                    .foregroundColor(Tema.Colore.Memoria.secondario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(mostrate.enumerated()), id: \.element.id) { i, v in
                if i > 0 || intestazione != nil { filo }
                RigaVariazione(variazione: v)
            }
            if variazioni.count > massimo {
                filo
                Button(tutte ? TestiMemoria.mostraMeno : TestiMemoria.mostraTutte(n: variazioni.count)) { tutte.toggle() }
                    .buttonStyle(StileSemplice())
                    .font(Tema.Testo.Memoria.collegamento)
                    .foregroundColor(Tema.Colore.Memoria.collegamento)
            }
        }
        .padding(m.marginePannello)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Memoria.pannello))
    }

    private var filo: some View {
        Rectangle().fill(Tema.Colore.Memoria.linea).frame(height: Tema.Misura.filo)
    }
}

/// Pallini dei semafori: n rossi, n gialli, n verdi (gettoni Tema.Colore.Memoria.semaforo). Tutti a zero: «—».
struct PalliniSemafori: View {
    let rossi: Int
    let gialli: Int
    let verdi: Int

    var body: some View {
        let m = Tema.Misura.Memoria.self
        if rossi + gialli + verdi == 0 {
            Text("—").font(Tema.Testo.Memoria.cifra).foregroundColor(Tema.Colore.Memoria.secondario)
        } else {
            HStack(spacing: m.spazioGruppiPallini) {
                gruppo(rossi, .rosso)
                gruppo(gialli, .giallo)
                gruppo(verdi, .verde)
            }
        }
    }

    @ViewBuilder private func gruppo(_ n: Int, _ s: Semaforo) -> some View {
        if n > 0 {
            let m = Tema.Misura.Memoria.self
            HStack(spacing: m.spazioPallini) {
                ForEach(0..<n, id: \.self) { _ in
                    Circle()
                        .fill(Tema.Colore.Memoria.semaforo(s))
                        .frame(width: m.pallinoSemaforo, height: m.pallinoSemaforo)
                }
            }
        }
    }
}

/// Una cifra della scheda della fotografia: etichetta (o etichetta del canale) e valore.
struct CifraFotografia<Etichetta: View>: View {
    @ViewBuilder let etichetta: () -> Etichetta
    let valore: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Memoria.spazioCifra) {
            etichetta()
            Text(valore)
                .font(Tema.Testo.Memoria.cifra)
                .foregroundColor(Tema.Colore.Memoria.testo)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension CifraFotografia where Etichetta == EtichettaCifra {
    /// Una cifra con l'etichetta di testo («Divario pensione»).
    init(_ titolo: String, valore: String) {
        self.init(etichetta: { EtichettaCifra(titolo: titolo) }, valore: valore)
    }
}

/// L'etichetta di testo di una cifra della scheda.
struct EtichettaCifra: View {
    let titolo: String

    var body: some View {
        Text(titolo)
            .font(Tema.Testo.didascalia)
            .foregroundColor(Tema.Colore.Memoria.secondario)
            .lineLimit(1)
    }
}

/// La linea del tempo delle fotografie: pallino, filo e scheda per ciascuna, dalla più recente.
/// Ogni scheda si confronta con quella che la segue nell'elenco (la fotografia precedente).
struct LineaTempoRiesami: View {
    /// Dalla più recente.
    let fotografie: [FotografiaRiesame]
    let elimina: (FotografiaRiesame) -> Void

    var body: some View {
        let m = Tema.Misura.Memoria.self
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(fotografie.enumerated()), id: \.element.id) { i, f in
                let ultimaDellElenco = i == fotografie.count - 1
                HStack(alignment: .top, spacing: 0) {
                    Color.clear.frame(width: m.colonnaLinea, height: m.pallino)
                    SchedaFotografia(foto: f, precedente: ultimaDellElenco ? nil : fotografie[i + 1],
                                     ultima: i == 0, elimina: { elimina(f) })
                }
                .padding(.bottom, ultimaDellElenco ? 0 : m.spazioSchede)
                // Pallino e filo nella colonna di sinistra: il filo unisce i pallini da una scheda all'altra
                .background(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        segmento(visibile: i > 0)
                            .frame(height: m.marginePannello)
                        Circle()
                            .fill(i == 0 ? Tema.Colore.Memoria.pallinoUltima : Tema.Colore.Memoria.pallino)
                            .frame(width: m.pallino, height: m.pallino)
                            .frame(height: m.altezzaPallino)
                        segmento(visibile: !ultimaDellElenco)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: m.colonnaLinea)
                }
            }
        }
    }

    private func segmento(visibile: Bool) -> some View {
        Rectangle()
            .fill(visibile ? Tema.Colore.Memoria.linea : Color.clear)
            .frame(width: Tema.Misura.Memoria.linea)
    }
}

/// La scheda di una fotografia nella linea del tempo: data, da quanto, origini, cifre chiave e, chiuso
/// di partenza, che cosa è cambiato rispetto alla fotografia precedente.
struct SchedaFotografia: View {
    @EnvironmentObject var stato: StatoShell
    let foto: FotografiaRiesame
    /// La fotografia salvata prima di questa (nil per la più vecchia).
    let precedente: FotografiaRiesame?
    /// true per la più recente.
    let ultima: Bool
    let elimina: () -> Void
    @State private var aperto = false

    var body: some View {
        let m = Tema.Misura.Memoria.self
        VStack(alignment: .leading, spacing: m.spazioScheda) {
            testata
            cifre
            piede
        }
        .padding(m.marginePannello)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Memoria.scheda))
        .contextMenu {
            Button(TestiMemoria.eliminaQuestaMenu) { elimina() }
                .disabled(stato.solaLettura)
        }
    }

    private var testata: some View {
        let m = Tema.Misura.Memoria.self
        let mesi = TestiMemoria.mesi(da: foto.data, a: Date(), cal: Calendar.current)
        return HStack(alignment: .center, spacing: m.spazioTestata) {
            Text(Formati.dataEstesa.string(from: foto.data))
                .font(Tema.Testo.titolo)
                .foregroundColor(Tema.Colore.Memoria.testo)
                .lineLimit(1)
            Text(TestiMemoria.tempoFa(mesi: mesi))
                .font(Tema.Testo.secondario)
                .foregroundColor(Tema.Colore.Memoria.secondario)
                .lineLimit(1)
            HStack(spacing: m.pillole) {
                ForEach(Array(foto.origini.enumerated()), id: \.offset) { _, raw in
                    if let o = FotografiaRiesame.Origine(rawValue: raw) {
                        Pillola(testo: TestiMemoria.origine(o), tono: .neutro)
                            .help(TestiMemoria.origineEstesa(o))
                    } else {
                        // Un'origine di una versione futura di Prisma: si mostra com'è
                        Pillola(testo: raw, tono: .neutro)
                    }
                }
            }
            Spacer(minLength: 0)
            Button { elimina() } label: {
                Image(systemName: "trash").font(Tema.Testo.Memoria.elimina)
            }
            .buttonStyle(StileSemplice())
            .foregroundColor(Tema.Colore.Memoria.secondario)
            .help(TestiMemoria.eliminaQuesta)
            .disabled(stato.solaLettura)
        }
    }

    private var cifre: some View {
        let m = Tema.Misura.Memoria.self
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: m.colonnaCifra), spacing: m.spazioCifre)],
                         alignment: .leading, spacing: m.spazioCifre) {
            CifraFotografia(TestiMemoria.cifre.propensione, valore: TestiMemoria.propensioneBreve(foto.propensione))
            CifraFotografia(TestiMemoria.cifre.divarioPensione, valore: TestiMemoria.euroAlMese(foto.divarioPensione))
            CifraFotografia(TestiMemoria.cifre.scopertoCasoMorte, valore: TestiMemoria.euro(foto.scopertoCasoMorte))
            // Il patrimonio sempre diviso per canale, con l'etichetta del canale
            CifraFotografia(etichetta: { EtichettaCanale(canale: .alleanza, compatta: true) },
                            valore: TestiMemoria.euro(foto.patrimonioAlleanza))
            CifraFotografia(etichetta: { EtichettaCanale(canale: .indipendente, compatta: true) },
                            valore: TestiMemoria.euro(foto.patrimonioIndipendente))
            if foto.debiti > 0 {
                CifraFotografia(TestiMemoria.cifre.debiti, valore: TestiMemoria.euro(foto.debiti))
            }
            VStack(alignment: .leading, spacing: m.spazioCifra) {
                EtichettaCifra(titolo: TestiMemoria.cifre.semafori)
                PalliniSemafori(rossi: foto.conta(.rosso), gialli: foto.conta(.giallo), verdi: foto.conta(.verde))
                    .frame(minHeight: m.altezzaPallino, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(TestiMemoria.semafori(f: foto))
            if foto.completezza != nil {
                CifraFotografia(TestiMemoria.cifre.datiAnalisi, valore: TestiMemoria.completezzaBreve(f: foto))
            }
            if foto.conformita != nil {
                CifraFotografia(TestiMemoria.cifre.inRegola, valore: TestiMemoria.conformitaBreve(n: foto.conformitaDaSistemare))
            }
        }
    }

    @ViewBuilder private var piede: some View {
        if let p = precedente {
            // Due fotografie salvate: il confronto è un confronto di cifre già pronte, senza motori
            let variazioni = MotoreMemoria.variazioni(da: p, a: foto)
            DisclosureGroup(isExpanded: $aperto) {
                VStack(alignment: .leading, spacing: Tema.Misura.Memoria.righeCompatte) {
                    ForEach(variazioni) { v in
                        RigaVariazione(variazione: v, compatta: true)
                    }
                }
                .padding(.top, Tema.Misura.Memoria.righeCompatte)
            } label: {
                Text(TestiMemoria.rispettoA(data: p.data, n: variazioni.count))
                    .font(Tema.Testo.secondario)
                    .foregroundColor(Tema.Colore.Memoria.secondario)
            }
            .disabled(variazioni.isEmpty)
        }
    }
}
