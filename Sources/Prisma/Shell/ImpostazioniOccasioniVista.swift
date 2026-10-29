import SwiftUI

/// Impostazioni › Esperienza › Occasioni: lo strato nel calendario, l'anticipo di notifiche e promemoria,
/// i gruppi di tipi accesi e le età limite di TCM e LTC. Si salva con le altre impostazioni e vale subito.
/// AppImpostazioni la mette dopo la conformità e prima dei promemoria, con `.id("impostazioni-occasioni")`.
struct GruppoOccasioniImpostazioni: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let m = Misure.Occasioni.self
        GruppoImpostazioni(titolo: "Occasioni") {
            RigaImpostazione(titolo: "Nel calendario",
                             sottotitolo: "Le date in cui cambia qualcosa nella settimana e nel mese dell'Agenda; la vista «Occasioni» c'è sempre") {
                Toggle("", isOn: $stato.dati.impostazioni.occasioni.inAgenda)
                    .toggleStyle(StileInterruttore())
                    .labelsHidden()
            }
            RigaImpostazione(titolo: "Anticipo", sottotitolo: "Nel Centro notifiche e nei promemoria del Mac: quanti giorni prima") {
                MenuTendina(selezione: $stato.dati.impostazioni.occasioni.anticipoGiorni,
                            opzioni: ImpostazioniOccasioni.anticipi.map { ($0, "\($0) giorni prima") },
                            larghezza: m.menuImpostazioni)
            }
            rigaGruppo(.contratti, "Contratti",
                       "Fine del blocco di riscatto, penali finite, periodo del KID, ricorrenza della gestione separata")
            rigaGruppo(.previdenza, "Previdenza", "8 anni per le anticipazioni, aliquota che scende, 5 anni alla pensione")
            rigaGruppo(.famiglia, "Famiglia", "Figli maggiorenni e fine del carico")
            rigaGruppo(.protezione, "Protezione", "Caso morte sotto il debito residuo, ultimi anni per TCM e LTC")
            RigaImpostazione(titolo: "Età limite delle coperture",
                             sottotitolo: "Oltre queste età di solito non si sottoscrivono: controlla quelle del prodotto") {
                HStack(spacing: m.spazioEta) {
                    etichetta("TCM")
                    MenuTendina(selezione: $stato.dati.impostazioni.occasioni.etaLimiteTCM,
                                opzioni: ImpostazioniOccasioni.etaLimiti.map { ($0, "\($0) anni") },
                                larghezza: m.menuEta)
                    etichetta("LTC")
                    MenuTendina(selezione: $stato.dati.impostazioni.occasioni.etaLimiteLTC,
                                opzioni: ImpostazioniOccasioni.etaLimiti.map { ($0, "\($0) anni") },
                                larghezza: m.menuEta)
                }
            }
            rigaGruppo(.fisco, "Fisco", "Deduzioni entro il 31 dicembre, contributi non dedotti, detrazioni dei premi e bollo",
                       ultima: true)
        }
    }

    /// Un interruttore per gruppo di tipi: acceso se almeno un tipo del gruppo è acceso.
    private func rigaGruppo(_ g: GruppoOccasione, _ titolo: String, _ sottotitolo: String, ultima: Bool = false) -> some View {
        RigaImpostazione(titolo: titolo, sottotitolo: sottotitolo, ultima: ultima) {
            Toggle("", isOn: Binding(get: { stato.dati.impostazioni.occasioni.attivo(g) },
                                     set: { stato.dati.impostazioni.occasioni.imposta(g, attivo: $0) }))
                .toggleStyle(StileInterruttore())
                .labelsHidden()
        }
    }

    private func etichetta(_ testo: String) -> some View {
        Text(testo)
            .font(Tema.Testo.secondario)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
    }
}
