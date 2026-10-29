import SwiftUI

private typealias M = Tema.Misura.Adeguatezza
private typealias K = Tema.Colore.Adeguatezza

/// Impostazioni › Proposte (giro 4, specifica 1): l'elenco dei documenti da consegnare prima della firma, per
/// canale. Si accendono, si spengono, si modificano, se ne aggiungono, si torna all'elenco di Prisma. Le spunte
/// si mettono nella scheda di adeguatezza di ogni proposta.
struct ImpostazioniProposte: View {
    @EnvironmentObject var stato: StatoShell
    /// La voce aperta nel popover di modifica (anche quella appena aggiunta).
    @State private var inModifica: String?
    @State private var confermaRipristino = false

    var body: some View {
        VStack(alignment: .leading, spacing: Misure.Impostazioni.spazioGruppi) {
            Text("Per ogni proposta Prisma prepara l'elenco dei documenti del suo canale, secondo il tipo di prodotto. Le spunte si mettono nella scheda di adeguatezza della proposta. L'elenco è un promemoria: verifica sempre la documentazione richiesta dalla compagnia o dall'intermediario.")
                .font(Tipo.informazioniTesto)
                .foregroundColor(Colori.Impostazioni.nota)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Canale.allCases) { c in
                gruppo(c)
            }
            GruppoImpostazioni(titolo: "Elenco di Prisma") {
                RigaImpostazione(titolo: "Ripristina l'elenco di Prisma",
                                 sottotitolo: "Torna ai documenti predefiniti dei due canali: le spunte già messe nelle schede restano.",
                                 ultima: true) {
                    ValoreRiga(testo: "Ripristina") { confermaRipristino = true }
                }
            }
        }
        .alert("Ripristinare l'elenco di Prisma?", isPresented: $confermaRipristino) {
            Button("Annulla", role: .cancel) {}
            Button("Ripristina", role: .destructive) { stato.ripristinaDocumentiConsegna() }
        } message: {
            Text("I documenti aggiunti o modificati tornano quelli predefiniti dei due canali. Le spunte già messe nelle schede di adeguatezza restano.")
        }
    }

    private func gruppo(_ c: Canale) -> some View {
        let voci = stato.dati.impostazioni.consegna.voci(c)
        let attive = voci.filter(\.attiva).count
        return GruppoImpostazioni(titolo: "Documenti da consegnare · \(c.nomeBreve)") {
            RigaImpostazione(titolo: attive == 1 ? "1 documento attivo su \(voci.count)" : "\(attive) documenti attivi su \(voci.count)",
                             sottotitolo: "Quelli spenti non compaiono nelle schede delle proposte") {
                EtichettaCanale(canale: c)
            }
            ForEach(voci) { v in
                riga(v)
            }
            RigaImpostazione(titolo: "Aggiungi un documento", ultima: true) {
                ValoreRiga(testo: "Aggiungi") { aggiungi(c) }
            }
        }
    }

    private func riga(_ v: VoceDocumento) -> some View {
        let aperto = Binding<Bool>(get: { inModifica == v.id },
                                   set: { if !$0, inModifica == v.id { inModifica = nil } })
        return RigaImpostazione(titolo: v.titolo, sottotitolo: Self.sottotitolo(v)) {
            HStack(spacing: M.spazioPulsanti) {
                ValoreRiga(testo: "Modifica") { inModifica = v.id }
                    .popover(isPresented: aperto, arrowEdge: .leading) {
                        ModuloVoceDocumento(voceId: v.id) { inModifica = nil }
                            .environmentObject(stato)
                    }
                Toggle("", isOn: legameVoce(stato, v.id, \.attiva, true))
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
        }
    }

    /// «Regolamento IVASS n. 40/2018 · Polizze d'investimento (Ramo I, III, multiramo) · solo se sostituisce un contratto».
    static func sottotitolo(_ v: VoceDocumento) -> String {
        let parti: [String?] = [v.dettaglio.isEmpty ? nil : v.dettaglio, v.perTipo?.nome ?? "Tutte le proposte",
                                v.soloSostituzione ? "solo se sostituisce un contratto" : nil]
        return parti.compactMap { $0 }.joined(separator: " · ")
    }

    private func aggiungi(_ c: Canale) {
        let id = "voce-\(UUID().uuidString.prefix(8).lowercased())"
        stato.dati.impostazioni.consegna.voci.append(VoceDocumento(id: id, canale: c, titolo: "Nuovo documento"))
        inModifica = id
    }
}

/// Un campo di una voce dell'elenco, cercata per id (l'elenco può cambiare mentre il popover è aperto).
private func legameVoce<V>(_ stato: StatoShell, _ id: String, _ chiave: WritableKeyPath<VoceDocumento, V>,
                           _ predefinito: V) -> Binding<V> {
    Binding<V>(
        get: { stato.dati.impostazioni.consegna.voci.first { $0.id == id }?[keyPath: chiave] ?? predefinito },
        set: { nuovo in
            guard let i = stato.dati.impostazioni.consegna.voci.firstIndex(where: { $0.id == id }) else { return }
            stato.dati.impostazioni.consegna.voci[i][keyPath: chiave] = nuovo
        })
}

/// Il popover di una voce: titolo, riferimento, per quali proposte, solo in sostituzione, elimina.
private struct ModuloVoceDocumento: View {
    @EnvironmentObject var stato: StatoShell
    let voceId: String
    let chiudi: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: M.spazioPopover) {
            campo("Documento") {
                TestoRinviato(testo: legameVoce(stato, voceId, \.titolo, ""), salvaOra: { stato.salvaOra() }) { bozza in
                    TextField("Documento", text: bozza)
                        .campoTesto()
                }
            }
            campo("Riferimento o nota") {
                TestoRinviato(testo: legameVoce(stato, voceId, \.dettaglio, ""), salvaOra: { stato.salvaOra() }) { bozza in
                    TextField("Riferimento o nota", text: bozza)
                        .campoTesto()
                }
            }
            campo("Per") {
                MenuTendina(selezione: legameVoce(stato, voceId, \.perTipo, nil), opzioni: Self.opzioniPer, larghezza: M.menuPer)
            }
            HStack(spacing: M.spazioPulsanti) {
                Text("Solo quando sostituisce un contratto")
                    .font(Tipo.strumentoTesto)
                    .foregroundColor(K.testo)
                Spacer(minLength: 0)
                Toggle("", isOn: legameVoce(stato, voceId, \.soloSostituzione, false))
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
            HStack {
                Button {
                    stato.dati.impostazioni.consegna.voci.removeAll { $0.id == voceId }
                    chiudi()
                } label: {
                    Text("Elimina").foregroundColor(K.elimina)
                }
                .buttonStyle(StileVetro(margine: M.marginePulsante))
                Spacer()
                Button("Fatto") { chiudi() }
                    .buttonStyle(StileBlu())
            }
        }
        .padding(M.marginePopover)
        .frame(width: M.larghezzaPopover, alignment: .leading)
        .id(voceId)
    }

    private func campo<Contenuto: View>(_ titolo: String, @ViewBuilder _ contenuto: () -> Contenuto) -> some View {
        VStack(alignment: .leading, spacing: M.spazioCampo) {
            Text(titolo)
                .font(Tipo.chip)
                .foregroundColor(K.nota)
            contenuto()
        }
    }

    static let opzioniPer: [(AmbitoConsegna?, String)] =
        [(nil, "Tutte le proposte")] + AmbitoConsegna.allCases.map { (Optional($0), $0.nome) }
}
