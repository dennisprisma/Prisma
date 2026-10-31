#if os(iOS)
import SwiftUI

/// Eve sull'iPhone: la conversazione dell'app Eve del Mac a tutta larghezza. Il contesto (di chi si parla e lo stato
/// di Qwen) sta in una riga in alto, gli spunti e il campo in basso. Risponde Qwen del Mac in Wi‑Fi (PonteEve):
/// se il Mac non c'è, Eve lo dice e non risponde. Le cifre le prepara Prisma, qui sul telefono.
struct EveTelefono: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile
    @FocusState private var campoAttivo: Bool

    private typealias M = Tema.Misura.EveTelefono
    private typealias C = Tema.Colore.EveChat

    private var chiave: String { stato.evePortafoglio ? EvePortafoglio.chiave : stato.clienteAttivoId }
    private var messaggi: [MessaggioEve] { stato.conversazione(chiave) }

    var body: some View {
        VStack(spacing: 0) {
            testata
            if !stato.disponibilitaLocale.pronto { avviso }
            messaggiVista
                .frame(maxHeight: .infinity)
            spunti
            scrittura
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { stato.nuovaConversazione() } label: { Image(systemName: "square.and.pencil") }
                    .disabled(messaggi.isEmpty && !stato.eveInCorso)
                    .accessibilityLabel("Nuova conversazione")
            }
        }
        .onAppear { if !stato.disponibilitaLocale.pronto { stato.verificaMotoreLocale() } }
    }

    // MARK: - In alto

    /// Di chi si parla (un cliente o tutto il portafoglio) e lo stato di Qwen sul Mac.
    private var testata: some View {
        HStack(spacing: M.spazioGettone) {
            Menu {
                Button { stato.evePortafoglio = true } label: { Label("Tutto il portafoglio", systemImage: "square.grid.2x2") }
                Section("Clienti") {
                    ForEach(stato.dati.clienti.sorted { $0.nome < $1.nome }) { c in
                        Button {
                            stato.evePortafoglio = false
                            stato.clienteAttivoId = c.id
                        } label: { Text(c.nome) }
                    }
                }
            } label: {
                HStack(spacing: M.spazioGettone) {
                    Text(stato.evePortafoglio ? "Tutto il portafoglio" : (stato.clienteAttivo?.nome ?? "Scegli un cliente"))
                        .lineLimit(1)
                    Image(systemName: "chevron.down").imageScale(.small)
                }
                .font(Tipo.Mobile.eveGettone)
                .foregroundColor(C.testo)
                .padding(.horizontal, M.margine * 0.75)
                .frame(height: M.gettone)
                .vetro(.chip, forma: .capsula)
            }
            Spacer(minLength: M.spazioGettone)
            HStack(spacing: M.spazioGettone) {
                Circle()
                    .fill(stato.disponibilitaLocale.pronto ? C.pronto : C.nonPronto)
                    .frame(width: M.pallino, height: M.pallino)
                Text(stato.disponibilitaLocale.pronto ? "Qwen sul Mac" : "Mac non collegato")
                    .font(Tipo.Mobile.eveStato)
                    .foregroundColor(C.testoSecondario)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, M.margine)
        .frame(height: M.testata)
    }

    /// Il Mac non risponde: perché e cosa fare, senza rispondere a caso.
    private var avviso: some View {
        VStack(alignment: .leading, spacing: M.spazioAvviso) {
            Text("Eve usa Qwen del tuo Mac")
                .font(Tipo.Mobile.eveAvvisoTitolo)
                .foregroundColor(C.testo)
            Text(stato.disponibilitaLocale.motivo ?? "Cerco il Mac in rete…")
                .font(Tipo.Mobile.eveAvviso)
                .foregroundColor(C.testoSecondario)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: M.spazioAvviso) {
                Button { stato.verificaMotoreLocale() } label: { Label("Riprova", systemImage: "arrow.clockwise") }
                    .buttonStyle(StileVetro())
                Button {
                    stato.schedaImpostazioni = .esperienza
                    mobile.apri(.impostazioni)
                } label: { Label("Codice del Mac", systemImage: "key") }
                    .buttonStyle(StileVetro())
            }
        }
        .padding(M.margineAvviso)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Mobile.scheda))
        .padding(.horizontal, M.margine)
        .padding(.bottom, M.spazioAvviso)
    }

    // MARK: - Conversazione

    private var messaggiVista: some View {
        ScrollViewReader { lettore in
            ScrollView {
                LazyVStack(spacing: M.spazioMessaggi) {
                    if messaggi.isEmpty && !stato.eveInCorso { benvenuto }
                    ForEach(messaggi) { msg in
                        NuvolaEve(messaggio: msg, nomeUtente: stato.nomeUtente, azioniCliente: !stato.evePortafoglio,
                                  creaAttivita: { stato.attivitaDaEve(msg) }, aggiungiNota: { stato.notaDaEve(msg) },
                                  attivitaProposta: { stato.attivitaDaProposta($0, messaggio: msg.id) },
                                  posizioneProposta: { stato.posizioneDaProposta($0, messaggio: msg.id) },
                                  apriAzione: { stato.apriAzioneEve($0) },
                                  annullaAzione: { stato.annullaAzioneEve($0, messaggio: msg.id) })
                            .id(msg.id)
                    }
                    if stato.eveInCorso {
                        NuvolaInArrivo(flusso: stato.flussoEve, portafoglio: stato.evePortafoglio) {
                            withAnimation { lettore.scrollTo("pensa", anchor: .top) }
                        }
                        .id("pensa")
                    }
                }
                .padding(.horizontal, M.margine)
                .padding(.vertical, M.spazioMessaggi)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messaggi.count) { _ in
                guard let ultimo = messaggi.last else { return }
                withAnimation { lettore.scrollTo(ultimo.id, anchor: ultimo.autore == .utente ? .bottom : .top) }
            }
            .onChange(of: stato.eveInCorso) { pensa in
                if pensa { withAnimation { lettore.scrollTo("pensa", anchor: .bottom) } }
            }
        }
    }

    private var benvenuto: some View {
        VStack(spacing: M.spazioAvviso) {
            SferaEve(lato: M.sferaBenvenuto, pensa: false)
                .padding(.bottom, M.spazioAvviso)
            Text("Le informazioni ci sono.\nTroviamo il filo.")
                .font(Tipo.Mobile.eveBenvenuto)
                .foregroundColor(C.testo)
            Text(stato.evePortafoglio
                 ? "Chiedimi del portafoglio: chi ricontattare, cosa scade, la settimana. Le cifre sono quelle di Prisma."
                 : "Chiedimi di \(stato.clienteAttivo?.nome ?? "un cliente"): un riassunto, il check-up, cosa scade, come preparare l'incontro.")
                .font(Tipo.Mobile.eveBenvenutoTesto)
                .foregroundColor(C.testoSecondario)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, M.margine * 2)
        .frame(maxWidth: .infinity)
    }

    // MARK: - In basso

    private var spunti: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: M.spazioSpunti) {
                if stato.evePortafoglio {
                    ForEach(SpuntoPortafoglio.allCases) { s in
                        Button { invia(s.domanda, portafoglio: s) } label: { PillolaSpuntoEve(simbolo: s.simbolo, testo: s.domanda) }
                            .buttonStyle(StileSemplice())
                    }
                } else {
                    ForEach(SpuntoEve.allCases) { s in
                        Button { invia(s.domanda, spunto: s) } label: { PillolaSpuntoEve(simbolo: s.simbolo, testo: s.domanda) }
                            .buttonStyle(StileSemplice())
                    }
                }
            }
            .padding(.horizontal, M.margine)
        }
        .disabled(stato.eveInCorso)
        .padding(.top, M.spazioAvviso)
    }

    private var scrittura: some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.EveChat.composer)
        let vuota = stato.domandaEve.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: M.spazioCampo) {
            TextField("Chiedi a Eve…", text: $stato.domandaEve, axis: .vertical)
                .font(Tipo.Mobile.eveCampo)
                .foregroundColor(C.testo)
                .lineLimit(1...5)
                .focused($campoAttivo)
                .submitLabel(.send)
                .onSubmit { invia(stato.domandaEve) }
                .frame(maxWidth: .infinity, minHeight: Tema.Misura.EveChat.tasto, alignment: .leading)
            Button { invia(stato.domandaEve) } label: { Image(systemName: "arrow.up") }
                .buttonStyle(StileTastoEve(aspetto: .invio))
                .disabled(stato.eveInCorso || vuota)
                .accessibilityLabel("Invia")
        }
        .padding(M.margineCampo)
        .frame(minHeight: M.campoMinimo)
        .background { forma.fill(C.composer) }
        .overlay { forma.strokeBorder(C.bordoComposer, lineWidth: Tema.Misura.filo).allowsHitTesting(false) }
        .padding(M.margineScrittura)
    }

    private func invia(_ testo: String, spunto: SpuntoEve? = nil, portafoglio: SpuntoPortafoglio? = nil) {
        let t = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !stato.eveInCorso else { return }
        campoAttivo = false
        if stato.evePortafoglio { stato.chiediEvePortafoglio(t, spunto: portafoglio) } else { stato.chiediEve(t, spunto: spunto) }
    }
}
#endif
