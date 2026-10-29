import SwiftUI

// MARK: - Esito della proposta (giro 3, specifica 5)
// Il modulo che chiude una proposta: accettata (con decorrenza, primo valore e versato), rifiutata o rimandata
// con il motivo, oppure «ci deve pensare». Compatto nel dettaglio dell'Agenda (RiquadroEsitoProposta), largo
// nel foglio di Posizioni e Incontri (ModuloEsitoProposta).

/// Il modulo dell'esito: quattro passi, stato locale. La conferma la decide chi lo usa (`stato.chiudiProposta`).
struct FormEsitoProposta: View {
    let posizione: Posizione
    let appuntamento: Appuntamento?
    /// Etichette sopra i campi (riquadro dell'Agenda) invece che a sinistra (`CampoModulo`).
    let compatto: Bool
    /// I giorni del seguito (Impostazioni), per la nota sotto le scelte.
    let giorniSeguito: Int
    let conferma: (EsitoScelto) -> Void
    var chiudi: (() -> Void)? = nil

    @State private var passo: PassoEsito
    @State private var dati: DatiAccettazione
    @State private var motivo: MotivoEsito?
    @State private var nota = ""
    @State private var mesiRipresa = MotoreSeguitoProposte.ripresaPredefinitaMesi

    init(posizione: Posizione, appuntamento: Appuntamento?, passoIniziale: PassoEsito, compatto: Bool,
         datiProposti: DatiAccettazione, giorniSeguito: Int,
         conferma: @escaping (EsitoScelto) -> Void, chiudi: (() -> Void)? = nil) {
        self.posizione = posizione
        self.appuntamento = appuntamento
        self.compatto = compatto
        self.giorniSeguito = giorniSeguito
        self.conferma = conferma
        self.chiudi = chiudi
        _passo = State(initialValue: passoIniziale)
        _dati = State(initialValue: datiProposti)
    }

    private var finanziaria: Bool { posizione.area != .protezione && posizione.area != .debiti }
    private var firma: Bool { appuntamento?.tipo == .firma }
    private var notaPulita: String { nota.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// La data della ripresa per i mesi scelti, a mezzogiorno.
    private var dataRipresa: Date {
        ValoriDaDocumento.mezzogiorno(Calendar.current.date(byAdding: .month, value: mesiRipresa, to: Date()) ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Misure.Seguito.spazio) {
            testa
            switch passo {
            case .scelta: scelta
            case .accettata: accettata
            case .rifiutata: rifiutata
            case .rimandata: rimandata
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Testa

    private var testa: some View {
        VStack(alignment: .leading, spacing: Misure.Seguito.spazioCampo) {
            Text(TestiSeguito.occhiello)
                .font(Tipo.dettaglioOcchiello)
                .foregroundColor(Colori.Seguito.testoRichiesta)
            HStack(alignment: .firstTextBaseline, spacing: Misure.Seguito.spazio) {
                Text(TestiSeguito.titolo(posizione))
                    .font(compatto ? Tipo.voceValore.weight(.semibold) : Tipo.eventoTitolo)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .fixedSize(horizontal: false, vertical: true)
                EtichettaCanale(canale: posizione.canale, compatta: true)
            }
        }
    }

    // MARK: - Passo «scelta»

    private var scelta: some View {
        VStack(alignment: .leading, spacing: Misure.Seguito.spazio) {
            HStack(spacing: Misure.Seguito.spazio) {
                PulsanteAzione(titolo: TestiSeguito.sceltaAccettata, principale: true) { passo = .accettata }
                PulsanteAzione(titolo: TestiSeguito.sceltaRimandata) {
                    motivo = nil
                    passo = .rimandata
                }
            }
            HStack(spacing: Misure.Seguito.spazio) {
                PulsanteAzione(titolo: TestiSeguito.sceltaRifiutata) {
                    motivo = nil
                    passo = .rifiutata
                }
                PulsanteAzione(titolo: TestiSeguito.sceltaInAttesa) { conferma(.inAttesa) }
            }
            testoNota(TestiSeguito.notaInAttesa(giorni: giorniSeguito))
        }
    }

    // MARK: - Passo «accettata»

    private var accettata: some View {
        let avvisi = MotoreSeguitoProposte.verifica(dati, posizione: posizione, adesso: Date())
        let bloccato = avvisi.contains { $0.bloccante }
        let recesso = MotoreSeguitoProposte.fineRecesso(posizione, firma: appuntamento?.inizio ?? Date())
        return VStack(alignment: .leading, spacing: Misure.Seguito.spazio) {
            CampoEsito(etichetta: "Decorrenza", compatto: compatto) {
                DatePicker("", selection: $dati.decorrenza, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .environment(\.locale, Formati.italiano)
            }
            if finanziaria {
                CampoEsito(etichetta: "Primo valore", compatto: compatto) {
                    CampoEuroEsito(valore: $dati.primoValore)
                }
            }
            CampoEsito(etichetta: posizione.area == .protezione ? "Primo premio pagato" : "Versato", compatto: compatto) {
                CampoEuroEsito(valore: $dati.versato)
            }
            CampoEsito(etichetta: "Scadenza", compatto: compatto) {
                VStack(alignment: .leading, spacing: Misure.Seguito.spazioCampo) {
                    CampoDataFacoltativa(data: $dati.scadenza, predefinita: dati.decorrenza)
                    if posizione.scadenza != nil && dati.scadenza != nil {
                        testoNota(TestiSeguito.notaScadenza(anni: MotoreSeguitoProposte.anniDurata(posizione)))
                    }
                }
            }
            if posizione.area == .previdenza {
                CampoEsito(etichetta: "Prima adesione", compatto: compatto) {
                    VStack(alignment: .leading, spacing: Misure.Seguito.spazioCampo) {
                        DatePicker("", selection: Binding(get: { dati.primaAdesione ?? dati.decorrenza },
                                                          set: { dati.primaAdesione = ValoriDaDocumento.mezzogiorno($0) }),
                                   displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.field)
                            .environment(\.locale, Formati.italiano)
                        testoNota(TestiSeguito.notaPrimaAdesione)
                    }
                }
            }
            if let recesso { testoNota(TestiSeguito.recesso(recesso)) }
            ForEach(avvisi, id: \.self) { a in
                Text(a.testo)
                    .font(Tipo.kpiNota)
                    .foregroundColor(a.bloccante ? Colori.Seguito.bloccante : Colori.Seguito.avviso)
                    .fixedSize(horizontal: false, vertical: true)
            }
            testoNota(TestiSeguito.antiriciclaggio)
            HStack(spacing: Misure.Seguito.spazio) {
                PulsanteAzione(titolo: firma ? TestiSeguito.nonFirmato : TestiSeguito.indietro) { passo = .scelta }
                PulsanteAzione(titolo: TestiSeguito.passaInEssere, principale: true) {
                    var d = dati
                    d.decorrenza = ValoriDaDocumento.mezzogiorno(d.decorrenza)
                    d.scadenza = d.scadenza.map(ValoriDaDocumento.mezzogiorno)
                    conferma(.accettata(d))
                }
                .disabled(bloccato)
                .opacity(bloccato ? 0.5 : 1)
            }
        }
        // La scadenza segue la decorrenza: la durata della proposta resta la stessa
        .onChange(of: dati.decorrenza) { nuova in
            if dati.scadenza != nil, let s = MotoreSeguitoProposte.scadenzaSpostata(posizione, decorrenza: nuova) {
                dati.scadenza = s
            }
        }
    }

    // MARK: - Passo «rifiutata»

    private var rifiutata: some View {
        VStack(alignment: .leading, spacing: Misure.Seguito.spazio) {
            CampoEsito(etichetta: "Motivo", compatto: compatto) {
                MenuTendina(selezione: $motivo, opzioni: opzioni(MotivoEsito.perRifiuto))
            }
            CampoEsito(etichetta: "Nota", compatto: compatto) {
                TextField(TestiSeguito.nota, text: $nota).campoTesto()
            }
            testoNota(TestiSeguito.notaRifiuto)
            HStack(spacing: Misure.Seguito.spazio) {
                PulsanteAzione(titolo: TestiSeguito.indietro) { passo = .scelta }
                PulsanteAzione(titolo: TestiSeguito.segnaRifiutata, principale: true) {
                    conferma(.rifiutata(motivo: motivo, nota: notaPulita))
                }
            }
        }
    }

    // MARK: - Passo «rimandata»

    private var rimandata: some View {
        VStack(alignment: .leading, spacing: Misure.Seguito.spazio) {
            CampoEsito(etichetta: "Da riprendere tra", compatto: compatto) {
                VStack(alignment: .leading, spacing: Misure.Seguito.spazioCampo) {
                    ControlloSegmenti(opzioni: MotoreSeguitoProposte.sceltaRipresaMesi.map { ($0, TestiSeguito.mesiRipresa($0)) },
                                      selezione: $mesiRipresa, compatto: compatto)
                    Text(TestiSeguito.daRiprendere(dataRipresa))
                        .font(Tipo.voceEtichetta)
                        .foregroundColor(Tema.Colore.inchiostro)
                }
            }
            CampoEsito(etichetta: "Motivo", compatto: compatto) {
                MenuTendina(selezione: $motivo, opzioni: opzioni(MotivoEsito.perRinvio))
            }
            CampoEsito(etichetta: "Nota", compatto: compatto) {
                TextField(TestiSeguito.nota, text: $nota).campoTesto()
            }
            testoNota(TestiSeguito.creaAttivita(posizione))
            HStack(spacing: Misure.Seguito.spazio) {
                PulsanteAzione(titolo: TestiSeguito.indietro) { passo = .scelta }
                PulsanteAzione(titolo: TestiSeguito.rimanda, principale: true) {
                    conferma(.rimandata(al: dataRipresa, motivo: motivo, nota: notaPulita))
                }
            }
        }
    }

    // MARK: - Aiuti

    /// «Motivo non indicato» e le voci del passo.
    private func opzioni(_ voci: [MotivoEsito]) -> [(MotivoEsito?, String)] {
        var tutte: [(MotivoEsito?, String)] = [(nil, TestiSeguito.motivoNonIndicato)]
        for v in voci { tutte.append((v, v.nome)) }
        return tutte
    }

    private func testoNota(_ testo: String) -> some View {
        Text(testo)
            .font(Tipo.kpiNota)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Un campo del modulo dell'esito. Compatto (riquadro dell'Agenda): con spazio sufficiente una griglia «etichetta |
/// campo», altrimenti l'etichetta sopra il campo. Largo (foglio): `CampoModulo`, con l'etichetta a sinistra.
private struct CampoEsito<Controllo: View>: View {
    let etichetta: String
    let compatto: Bool
    @ViewBuilder let controllo: () -> Controllo

    var body: some View {
        if compatto {
            // Il campo dichiara una larghezza ideale fissa: le note sotto i campi non decidono la scelta,
            // così tutte le righe del modulo prendono la stessa disposizione
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Misure.Seguito.spazio) {
                    testoEtichetta
                        .frame(width: Misure.Seguito.etichettaGriglia, alignment: .leading)
                    controllo()
                        .frame(idealWidth: Misure.Seguito.campoGriglia, maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: Misure.Seguito.spazioCampo) {
                    testoEtichetta
                    controllo()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            CampoModulo(etichetta: etichetta, controllo: controllo)
        }
    }

    private var testoEtichetta: some View {
        Text(etichetta)
            .font(Tipo.voceEtichetta)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Una cifra in euro nel pozzetto del tema (`.campoTesto()`), con «€» dentro il pozzetto: vuota = non indicata.
private struct CampoEuroEsito: View {
    @Binding var valore: Double?

    private static let formato = FloatingPointFormatStyle<Double>.number.locale(Formati.italiano)

    var body: some View {
        HStack(spacing: Misure.Seguito.spazioCampo) {
            TextField("—", value: $valore, format: Self.formato)
                .multilineTextAlignment(.trailing)
            Text("€")
                .foregroundColor(Tema.Colore.inchiostroSecondario)
        }
        .campoTesto()
        .frame(width: Misure.Seguito.campoEuro)
    }
}

/// La richiesta dell'esito nel dettaglio di un appuntamento concluso (Agenda, Incontri): il modulo compatto
/// in un riquadro di vetro color proposta.
struct RiquadroEsitoProposta: View {
    @EnvironmentObject var stato: StatoShell
    let appuntamento: Appuntamento
    let posizione: Posizione
    let passoIniziale: PassoEsito

    var body: some View {
        FormEsitoProposta(posizione: posizione, appuntamento: appuntamento, passoIniziale: passoIniziale, compatto: true,
                          datiProposti: stato.datiAccettazione(posizione, appuntamento: appuntamento),
                          giorniSeguito: stato.dati.impostazioni.giorniSeguitoProposte,
                          conferma: { e in stato.chiudiProposta(posizione.id, e, appuntamentoId: appuntamento.id) })
            // Un'altra proposta o un altro appuntamento: il modulo riparte dalla scelta
            .id(posizione.id + "·" + appuntamento.id)
            .padding(Misure.Seguito.margineRiquadro)
            .frame(maxWidth: .infinity, alignment: .leading)
            .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Dossier.riquadro), riempimento: Colori.Seguito.fondoRichiesta)
    }
}

/// Il foglio dell'esito (Posizioni e Incontri), aperto da `stato.richiestaEsito`.
struct ModuloEsitoProposta: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.dismiss) private var chiudiFoglio
    let richiesta: RichiestaEsito

    var body: some View {
        let p = stato.dati.posizioni.first { $0.id == richiesta.posizioneId }
        let a: Appuntamento? = richiesta.appuntamentoId.flatMap { id in stato.dati.appuntamenti.first(where: { $0.id == id }) }
        CorniceModulo(titolo: "Esito della proposta") {
            if let p {
                FormEsitoProposta(posizione: p, appuntamento: a, passoIniziale: richiesta.passo, compatto: false,
                                  datiProposti: stato.datiAccettazione(p, appuntamento: a),
                                  giorniSeguito: stato.dati.impostazioni.giorniSeguitoProposte,
                                  conferma: { e in stato.chiudiProposta(p.id, e, appuntamentoId: richiesta.appuntamentoId) },
                                  chiudi: { chiudi() })
            }
        } piede: {
            Spacer()
            Button("Chiudi") { chiudi() }
                .buttonStyle(StileVetro())
                .keyboardShortcut(.cancelAction)
        }
        .frame(width: Misure.Seguito.modulo.width, height: Misure.Seguito.modulo.height)
    }

    private func chiudi() {
        stato.richiestaEsito = nil
        chiudiFoglio()
    }
}
