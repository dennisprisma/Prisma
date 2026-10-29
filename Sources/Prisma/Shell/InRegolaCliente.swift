import SwiftUI

/// La scheda «In regola» del dossier (Clienti): le date di conformità del cliente per canale, cosa è scaduto,
/// cosa scade entro 30 o 60 giorni e cosa manca, con un clic per rinnovare o correggere. È un promemoria del
/// consulente: fanno fede i moduli firmati. Resta visibile anche in modalità cliente (sono dati suoi).
struct InRegolaCliente: View {
    @EnvironmentObject var stato: StatoShell
    let cliente: Cliente
    @State private var modifica: Cliente?

    var body: some View {
        let m = Tema.Misura.Conformita.self
        VStack(alignment: .leading, spacing: m.spazioGruppi) {
            if let e = stato.conformitaCliente(cliente.id) {
                OcchielloSezione(titolo: "Scadenze di conformità", nota: "Al \(TestiConformita.data(e.oggi))")
                FasciaMetriche(metriche: [
                    .init(etichetta: "Scadute", valore: "\(e.scadute.count)",
                          nota: e.scadute.first.map { TestiConformita.nomeBreveMaiuscolo($0) } ?? "Nessuna"),
                    .init(etichetta: "In scadenza", valore: "\(e.inScadenza.count)", nota: "entro 60 giorni"),
                    .init(etichetta: "Da raccogliere", valore: "\(e.mancanti.count)", nota: "non registrate in Prisma"),
                ])
                ForEach(canaliMostrati(e)) { canale in
                    bloccoCanale(e, canale)
                }
                VStack(alignment: .leading, spacing: m.spazioIntestazione) {
                    OcchielloSezione(titolo: "Per tutti i canali")
                    VStack(spacing: 0) {
                        ForEach([VoceConformita.Tipo.documento, .privacy, .commerciale], id: \.self) { t in
                            if let v = e.voce(t) { riga(v, e) }
                        }
                    }
                }
                piede
            }
        }
        .sheet(item: $modifica) { c in
            ModuloConformita(bozza: c, regole: stato.dati.impostazioni.conformita, salva: { stato.salvaCliente($0) })
        }
    }

    /// I canali da mostrare: quelli con almeno una voce richiesta o un dato già registrato.
    private func canaliMostrati(_ e: EsitoConformita) -> [Canale] {
        Canale.allCases.filter { c in
            let richiesta = e.voci.contains { $0.canale == c && $0.stato != .nonRichiesta }
            let registrata = e.cliente.conformita?.questionario(c) != nil || e.cliente.conformita?.verifica(c) != nil
            return richiesta || registrata
        }
    }

    /// Il blocco di un canale: l'etichetta completa del canale (vetro blu con il logo, vetro cuoio con la firma)
    /// e le righe del questionario e dell'adeguata verifica.
    private func bloccoCanale(_ e: EsitoConformita, _ c: Canale) -> some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Conformita.spazioIntestazione) {
            EtichettaCanale(canale: c)
            VStack(spacing: 0) {
                ForEach([VoceConformita.Tipo.questionarioDi(c), .verificaDi(c)], id: \.self) { t in
                    if let v = e.voce(t) { riga(v, e) }
                }
            }
        }
    }

    /// La riga di una voce: pillola dello stato, «Rinnovato oggi» per le voci rinnovabili da sistemare, «Modifica».
    private func riga(_ v: VoceConformita, _ e: EsitoConformita) -> some View {
        let rinnovabile = (v.tipo.questionario || v.tipo.verifica || v.tipo == .commerciale)
            && (v.stato == .scaduta || v.stato == .entro30 || v.stato == .entro60)
        let id = cliente.id
        return RigaConformita(titolo: TestiConformita.nome(v.tipo),
                              dettaglio: TestiConformita.dettaglio(v, cliente: e.cliente),
                              pillola: TestiConformita.etichetta(v),
                              tono: v.stato.tono) {
            if rinnovabile {
                Button { stato.rinnovaOggi(id, v.tipo) } label: { Label("Rinnovato oggi", systemImage: "checkmark") }
                    .buttonStyle(StileCuoioChiaro())
                    .help("Mette la data di oggi e lascia il resto com'è")
            }
            Button { apriModulo() } label: { Label("Modifica", systemImage: "pencil") }
                .buttonStyle(StileVetro(margine: Tema.Misura.Conformita.margineAzione))
        }
    }

    /// Il piede: il modulo delle date, l'avvertenza e il metodo con le fonti.
    private var piede: some View {
        let m = Tema.Misura.Conformita.self
        return VStack(alignment: .leading, spacing: m.spazioPiede) {
            Button { apriModulo() } label: { Label("Aggiorna le date", systemImage: "calendar") }
                .buttonStyle(StileCuoioChiaro())
            Text(TestiConformita.avvertenza)
                .font(Tema.Testo.Conformita.fonte)
                .foregroundColor(Tema.Colore.Conformita.fonte)
                .fixedSize(horizontal: false, vertical: true)
            SezioneRipiegabile("Come si calcola e fonti", nota: nil) {
                ForEach(TestiConformita.metodo, id: \.self) { frase in
                    Text(frase)
                        .font(Tema.Testo.Conformita.dettaglio)
                        .foregroundColor(Tema.Colore.Conformita.dettaglio)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(TestiConformita.fonti, id: \.titolo) { f in
                    VStack(alignment: .leading, spacing: Tema.Misura.Conformita.spazioTesto) {
                        Text(f.titolo)
                            .font(Tema.Testo.Conformita.titoloFonte)
                            .foregroundColor(Tema.Colore.Conformita.titolo)
                        Text(f.testo)
                            .font(Tema.Testo.Conformita.fonte)
                            .foregroundColor(Tema.Colore.Conformita.fonte)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(.top, Tema.Misura.Conformita.spazioFonti)
                }
            }
        }
    }

    /// Apre il modulo con la scheda aggiornata del cliente.
    private func apriModulo() {
        // La nota «Da ricordare» in attesa entra prima nella scheda: il modulo la salverebbe com'era
        TestiRinviati.scriviOra()
        modifica = stato.cliente(cliente.id) ?? cliente
    }
}

// MARK: - Riquadro della Panoramica

/// Il riquadro «In regola» della Panoramica del cliente: compare solo se c'è qualcosa da sistemare.
struct RiquadroInRegola: View {
    @EnvironmentObject var stato: StatoShell
    let clienteId: String

    var body: some View {
        if let e = stato.conformitaCliente(clienteId), let peggiore = e.daSistemare.first {
            let voci = e.daSistemare
            let n = voci.count
            let m = Tema.Misura.Conformita.self
            VStack(alignment: .leading, spacing: m.spazioRiquadro) {
                OcchielloSezione(titolo: "In regola", nota: "\(n) \(n == 1 ? "voce" : "voci") da sistemare")
                HStack(alignment: .center, spacing: m.spazioRiga) {
                    Pillola(testo: TestiConformita.etichetta(peggiore), tono: peggiore.stato.tono)
                    Text(TestiConformita.maiuscola(voci.prefix(2).map { TestiConformita.breve($0) }.joined(separator: "; "))
                         + (n > 2 ? "…" : "."))
                        .font(Tema.Testo.Conformita.titolo)
                        .foregroundColor(Tema.Colore.Conformita.titolo)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { stato.apriInRegola(clienteId) } label: {
                        HStack(spacing: Tema.Misura.Componenti.spazioSimboloPulsante) {
                            Text("Apri «In regola»")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(StileCollegamento())
                }
            }
        }
    }
}
