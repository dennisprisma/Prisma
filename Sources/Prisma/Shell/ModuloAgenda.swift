import SwiftUI

/// Modulo per creare o modificare un appuntamento.
struct ModuloAppuntamento: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.dismiss) var chiudi
    @State var bozza: Appuntamento
    let nuovo: Bool
    let salva: (Appuntamento) -> Void
    let elimina: () -> Void
    /// La riga in testa a «Quando e dove» (dopo «Pianifica» della striscia dei riesami); nil = nessuna.
    var spiegazione: String? = nil
    @State var confermaEliminazione = false

    private var valido: Bool {
        !bozza.titolo.trimmingCharacters(in: .whitespaces).isEmpty && stato.cliente(bozza.clienteId) != nil
    }

    var body: some View {
        CorniceModulo(titolo: nuovo ? "Nuovo appuntamento" : "Modifica appuntamento") {
            VStack(alignment: .leading, spacing: 20) {
                sezione("L'incontro") {
                    CampoModulo(etichetta: "Titolo") {
                        TextField("Per esempio Revisione del piano annuale", text: $bozza.titolo).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Cliente") {
                        Picker("", selection: $bozza.clienteId) {
                            ForEach(stato.clienti) { c in Text(c.nome).tag(c.id) }
                        }
                        .labelsHidden()
                        .frame(width: 240)
                        .onChange(of: bozza.clienteId) { _ in bozza.posizioneId = nil }
                    }
                    CampoModulo(etichetta: "Tipo") {
                        Picker("", selection: $bozza.tipo) {
                            ForEach(TipoAppuntamento.allCases) { Text($0.nome).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 240)
                    }
                    CampoModulo(etichetta: "Canale") {
                        HStack(spacing: 14) {
                            sceltaCanale(nil)
                            ForEach(Canale.allCases) { c in sceltaCanale(c) }
                        }
                    }
                }
                sezione("Quando e dove") {
                    if let spiegazione {
                        Text(spiegazione)
                            .font(Tipo.kpiNota)
                            .foregroundColor(Colori.Analisi.kpiNota)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    CampoModulo(etichetta: "Data e ora") {
                        VStack(alignment: .leading, spacing: Misure.RiesamiAgenda.spazioRighe) {
                            DatePicker("", selection: $bozza.inizio, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.field)
                                .environment(\.locale, Formati.italiano)
                            avvisiOrario
                        }
                    }
                    CampoModulo(etichetta: "Durata") {
                        Stepper(value: $bozza.durataMinuti, in: 5...480, step: 5) {
                            Text("\(bozza.durataMinuti) minuti").font(Tipo.campoValore).foregroundColor(Colori.Rubrica.testo)
                        }
                    }
                    CampoModulo(etichetta: "Luogo o collegamento") {
                        TextField("In studio, telefono, videochiamata…", text: $bozza.luogo).textFieldStyle(.roundedBorder)
                    }
                    if !nuovo {
                        CampoModulo(etichetta: "Stato") {
                            Toggle("Incontro concluso", isOn: Binding(get: { bozza.stato == .concluso },
                                                                      set: { bozza.stato = $0 ? .concluso : .pianificato }))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
                sezione("Di cosa si parla") {
                    CampoModulo(etichetta: "Posizione collegata") {
                        Picker("", selection: $bozza.posizioneId) {
                            Text("Nessuna").tag(String?.none)
                            ForEach(stato.posizioniCliente(bozza.clienteId)) { p in
                                Text("\(p.stato == .proposta ? "Proposta · " : "")\(p.nome) (\(p.canale.nomeBreve))").tag(Optional(p.id))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 320)
                    }
                    CampoModulo(etichetta: "Note per l'incontro") {
                        CampoTestoLungo(testo: $bozza.note)
                    }
                }
            }
        } piede: {
            if !nuovo {
                Button { confermaEliminazione = true } label: {
                    Label("Elimina…", systemImage: "trash").foregroundColor(Colori.Rubrica.pericolo)
                }
                .buttonStyle(StileVetro())
            }
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro())
                .keyboardShortcut(.cancelAction)
            Button(nuovo ? "Crea appuntamento" : "Salva modifiche") {
                var a = bozza
                // Minuti interi: l'archivio JSON non conserva le frazioni di secondo
                a.inizio = Appuntamento.alMinuto(a.inizio)
                salva(a)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(!valido)
            .opacity(valido ? 1 : 0.5)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Agenda.modulo.width, height: Misure.Agenda.modulo.height)
        .alert("Eliminare questo appuntamento?", isPresented: $confermaEliminazione) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                elimina()
                chiudi()
            }
        } message: {
            Text("Le attività collegate restano nel tuo elenco. Se serve, potrai recuperarlo da un backup.")
        }
    }

    /// Avvisi calcolati dal vivo a ogni cambio della bozza, per qualunque appuntamento: si sovrappone a un altro
    /// (di qualunque cliente) o cade fuori dagli orari di lavoro. Avvisano soltanto: si può salvare lo stesso.
    @ViewBuilder private var avvisiOrario: some View {
        let accavallati = MotorePianificazione.sovrapposti(bozza, in: stato.dati.appuntamenti)
        let orari = stato.dati.impostazioni.orari
        if let primo = accavallati.first {
            // In modalità cliente il nome di un altro cliente non compare
            let nome = stato.cliente(primo.clienteId)?.nome ?? "un altro cliente"
            let altri = accavallati.count - 1
            let orario = "\(Formati.ora.string(from: primo.inizio))–\(Formati.ora.string(from: primo.fine))"
            let seguito: String = altri > 0 ? " e ad altri \(altri)" : ""
            let avviso: String = "⚠︎ Si sovrappone a «\(primo.titolo)» con \(nome) (\(orario))" + seguito
            Text(avviso)
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.attenzioneTesto)
                .fixedSize(horizontal: false, vertical: true)
        }
        if MotorePianificazione.fuoriOrario(bozza, orari: orari) {
            Text("Fuori dagli orari di lavoro (\(orari.descrizione))")
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sceltaCanale(_ c: Canale?) -> some View {
        Button { bozza.canale = c } label: {
            HStack(spacing: 6) {
                Image(systemName: bozza.canale == c ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(Colori.Analisi.navBasso)
                if let c {
                    EtichettaCanale(canale: c, compatta: true)
                } else {
                    Text("Non indicato").font(Tipo.campoValore).foregroundColor(Colori.Rubrica.testo)
                }
            }
        }
        .buttonStyle(StileSemplice())
    }

    private func sezione<C: View>(_ titolo: String, @ViewBuilder _ contenuto: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OcchielloSezione(titolo: titolo)
            contenuto()
        }
    }
}

/// Modulo per creare o modificare un'attività.
struct ModuloAttivita: View {
    @EnvironmentObject var stato: StatoShell
    @Environment(\.dismiss) var chiudi
    @State var bozza: Attivita
    let nuova: Bool
    let salva: (Attivita) -> Void
    let elimina: () -> Void
    @State var confermaEliminazione = false

    private var valida: Bool {
        !bozza.titolo.trimmingCharacters(in: .whitespaces).isEmpty && stato.cliente(bozza.clienteId) != nil
    }

    var body: some View {
        CorniceModulo(titolo: nuova ? "Nuova attività" : "Modifica attività") {
            VStack(alignment: .leading, spacing: 14) {
                CampoModulo(etichetta: "Cosa c'è da fare?") {
                    TextField("Per esempio Preparare il riepilogo per il cliente", text: $bozza.titolo).textFieldStyle(.roundedBorder)
                }
                CampoModulo(etichetta: "Cliente") {
                    Picker("", selection: $bozza.clienteId) {
                        ForEach(stato.clienti) { c in Text(c.nome).tag(c.id) }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                }
                CampoModulo(etichetta: "Scadenza") {
                    DatePicker("", selection: $bozza.scadenza, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .environment(\.locale, Formati.italiano)
                }
                CampoModulo(etichetta: "Priorità") {
                    Picker("", selection: $bozza.priorita) {
                        ForEach(Attivita.Priorita.allCases) { Text($0.nome).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
                CampoModulo(etichetta: "Note") {
                    CampoTestoLungo(testo: $bozza.note)
                }
                if let e = stato.appuntamento(bozza.appuntamentoId) {
                    CampoModulo(etichetta: "Appuntamento") {
                        Text("\(e.titolo) · \(Formati.giornoMese.string(from: e.inizio)), \(Formati.ora.string(from: e.inizio))")
                            .font(Tipo.campoValore)
                            .foregroundColor(Colori.Rubrica.secondario)
                    }
                }
            }
        } piede: {
            if !nuova {
                Button { confermaEliminazione = true } label: {
                    Label("Elimina…", systemImage: "trash").foregroundColor(Colori.Rubrica.pericolo)
                }
                .buttonStyle(StileVetro())
            }
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro())
                .keyboardShortcut(.cancelAction)
            Button(nuova ? "Crea attività" : "Salva modifiche") {
                var t = bozza
                t.scadenza = Calendar.current.startOfDay(for: t.scadenza)
                salva(t)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(!valida)
            .opacity(valida ? 1 : 0.5)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Attivita.modulo.width, height: Misure.Attivita.modulo.height)
        .alert("Eliminare questa attività?", isPresented: $confermaEliminazione) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                elimina()
                chiudi()
            }
        } message: {
            Text("Se serve, potrai recuperarla da un backup.")
        }
    }
}

/// Testo su più righe con la cornice dei campi.
struct CampoTestoLungo: View {
    @Binding var testo: String

    var body: some View {
        TextEditor(text: $testo)
            .font(Tipo.campoValore)
            .frame(height: 84)
            .overlay {
                FormaVetro.arrotondata(Tema.Raggio.Dossier.campoLungo)
                    .strokeBorder(Tema.Colore.separatore, lineWidth: Tema.Misura.filo)
                    .allowsHitTesting(false)
            }
    }
}
