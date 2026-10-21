import SwiftUI

/// Cornice dei moduli (.os-dialog): barra del titolo grigia, contenuto, piede con i pulsanti.
struct CorniceModulo<Contenuto: View, Piede: View>: View {
    let titolo: String
    @ViewBuilder let contenuto: () -> Contenuto
    @ViewBuilder let piede: () -> Piede

    var body: some View {
        VStack(spacing: 0) {
            Text(titolo)
                .font(Tipo.moduloTitolo)
                .foregroundColor(Colori.Finestra.titoloTesto)
                .incisione(Colori.Finestra.titoloIncisione)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(LinearGradient.verticale(Colori.Modulo.titoloAlto, Colori.Modulo.titoloBasso))
                .bordoBasso(Colori.Modulo.titoloBordo)
            ScrollView {
                contenuto()
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Colori.Rubrica.carta)
            HStack(spacing: 9) {
                piede()
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(LinearGradient.verticale(Colori.Modulo.piedeAlto, Colori.Modulo.piedeBasso))
            .bordoAlto(Colori.Modulo.piedeBordo)
        }
    }
}

/// Riga di un modulo: etichetta a sinistra, controllo a destra.
struct CampoModulo<Controllo: View>: View {
    let etichetta: String
    @ViewBuilder let controllo: () -> Controllo

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(etichetta)
                .font(Tipo.campoEtichetta)
                .foregroundColor(Colori.Rubrica.secondario)
                .frame(width: 150, alignment: .trailing)
            controllo()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Data facoltativa: interruttore "indicata" e selettore della data.
struct CampoDataFacoltativa: View {
    @Binding var data: Date?
    var predefinita: Date

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Indicata", isOn: Binding(get: { data != nil }, set: { data = $0 ? (data ?? predefinita) : nil }))
                .toggleStyle(.checkbox)
            if data != nil {
                DatePicker("", selection: Binding(get: { data ?? predefinita }, set: { data = $0 }), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .environment(\.locale, Formati.italiano)
            }
        }
    }
}

// MARK: - Modulo del cliente

struct ModuloCliente: View {
    @Environment(\.dismiss) var chiudi
    @State var bozza: Cliente
    let nuovo: Bool
    let salva: (Cliente) -> Void
    let elimina: () -> Void
    @State var confermaEliminazione = false

    private var valido: Bool { !bozza.nome.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        CorniceModulo(titolo: nuovo ? "Aggiungi un cliente" : "Modifica la scheda") {
            VStack(alignment: .leading, spacing: 20) {
                sezione("Anagrafica") {
                    CampoModulo(etichetta: "Nome e cognome") {
                        TextField("Per esempio Giulia Rossi", text: $bozza.nome).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Progetto principale") {
                        TextField("Una frase che lo ricordi", text: $bozza.tema).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Data di nascita") {
                        CampoDataFacoltativa(data: $bozza.dataNascita, predefinita: Formati.dataPredefinitaNascita)
                    }
                    CampoModulo(etichetta: "Codice fiscale") {
                        TextField("", text: $bozza.codiceFiscale).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Professione") {
                        TextField("", text: $bozza.professione).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Stato civile") {
                        Picker("", selection: $bozza.statoCivile) {
                            Text("Non indicato").tag(StatoCivile?.none)
                            ForEach(StatoCivile.allCases) { Text($0.nome).tag(Optional($0)) }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }
                sezione("Contatti") {
                    CampoModulo(etichetta: "Email") {
                        TextField("", text: $bozza.email).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Telefono") {
                        TextField("", text: $bozza.telefono).textFieldStyle(.roundedBorder)
                    }
                    CampoModulo(etichetta: "Indirizzo") {
                        TextField("", text: $bozza.indirizzo).textFieldStyle(.roundedBorder)
                    }
                }
                sezione("Canali e preferenze") {
                    CampoModulo(etichetta: "Seguito come") {
                        HStack(spacing: 16) {
                            ForEach(Canale.allCases) { canale in
                                Toggle(isOn: Binding(
                                    get: { bozza.canali.contains(canale) },
                                    set: { attivo in
                                        bozza.canali.removeAll { $0 == canale }
                                        if attivo { bozza.canali.append(canale) }
                                        bozza.canali.sort { $0.rawValue < $1.rawValue }
                                    }
                                )) {
                                    EtichettaCanale(canale: canale, compatta: true)
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                    CampoModulo(etichetta: "Preferito") {
                        Toggle("Mostra tra i preferiti", isOn: $bozza.preferito).toggleStyle(.checkbox)
                    }
                }
                sezione("Profilo dell'investitore") {
                    CampoModulo(etichetta: "Propensione al rischio") {
                        Picker("", selection: $bozza.profilo.propensione) {
                            Text("Non indicata").tag(ProfiloInvestitore.Propensione?.none)
                            ForEach(ProfiloInvestitore.Propensione.allCases) { Text($0.nome).tag(Optional($0)) }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    CampoModulo(etichetta: "Orizzonte (anni)") {
                        TextField("", value: $bozza.profilo.orizzonteAnni, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    CampoModulo(etichetta: "Esperienza finanziaria") {
                        Picker("", selection: $bozza.profilo.esperienza) {
                            Text("Non indicata").tag(ProfiloInvestitore.Esperienza?.none)
                            ForEach(ProfiloInvestitore.Esperienza.allCases) { Text($0.nome).tag(Optional($0)) }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    CampoModulo(etichetta: "Obiettivi principali") {
                        TextField("", text: $bozza.profilo.obiettivi).textFieldStyle(.roundedBorder)
                    }
                }
                sezione("Consensi") {
                    CampoModulo(etichetta: "Privacy") {
                        Toggle("Consenso al trattamento dei dati raccolto", isOn: Binding(
                            get: { bozza.consensi.privacy },
                            set: { bozza.consensi.privacy = $0; if $0, bozza.consensi.dataPrivacy == nil { bozza.consensi.dataPrivacy = Date() } }
                        ))
                        .toggleStyle(.checkbox)
                    }
                    CampoModulo(etichetta: "Commerciale") {
                        Toggle("Consenso alle comunicazioni commerciali", isOn: $bozza.consensi.marketing).toggleStyle(.checkbox)
                    }
                }
            }
        } piede: {
            if !nuovo {
                Button { confermaEliminazione = true } label: {
                    Text("Elimina il cliente…").foregroundColor(Colori.Rubrica.pericolo)
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
            }
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button(nuovo ? "Aggiungi" : "Salva") {
                var c = bozza
                if c.profilo != ProfiloInvestitore() { c.profilo.aggiornatoIl = Date() }
                salva(c)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(!valido)
            .opacity(valido ? 1 : 0.5)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Rubrica.modulo.width, height: Misure.Rubrica.modulo.height)
        .alert("Eliminare \(bozza.nome)?", isPresented: $confermaEliminazione) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                elimina()
                chiudi()
            }
        } message: {
            Text("La scheda, gli appuntamenti e le attività del cliente verranno eliminati. Se serve, potrai recuperarli da un backup.")
        }
    }

    private func sezione<C: View>(_ titolo: String, @ViewBuilder _ contenuto: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OcchielloSezione(titolo: titolo)
            contenuto()
        }
    }
}

// MARK: - Modulo del familiare

struct ModuloFamiliare: View {
    @Environment(\.dismiss) var chiudi
    @State var modifica: ModificaFamiliare
    let salva: (ModificaFamiliare) -> Void
    let elimina: (ModificaFamiliare) -> Void

    init(modifica: ModificaFamiliare, salva: @escaping (ModificaFamiliare) -> Void, elimina: @escaping (ModificaFamiliare) -> Void) {
        _modifica = State(initialValue: modifica)
        self.salva = salva
        self.elimina = elimina
    }

    private var valido: Bool { !modifica.familiare.nome.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        CorniceModulo(titolo: modifica.nuovo ? "Aggiungi un familiare" : "Modifica il familiare") {
            VStack(alignment: .leading, spacing: 12) {
                CampoModulo(etichetta: "Nome e cognome") {
                    TextField("", text: $modifica.familiare.nome).textFieldStyle(.roundedBorder)
                }
                CampoModulo(etichetta: "Relazione") {
                    Picker("", selection: $modifica.familiare.relazione) {
                        ForEach(Familiare.Relazione.allCases) { Text($0.nome).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
                CampoModulo(etichetta: "Data di nascita") {
                    CampoDataFacoltativa(data: $modifica.familiare.dataNascita, predefinita: Formati.dataPredefinitaNascita)
                }
                CampoModulo(etichetta: "A carico") {
                    Toggle("Fiscalmente o economicamente a carico", isOn: $modifica.familiare.aCarico).toggleStyle(.checkbox)
                }
                CampoModulo(etichetta: "Nota") {
                    TextField("", text: $modifica.familiare.nota).textFieldStyle(.roundedBorder)
                }
            }
        } piede: {
            if !modifica.nuovo {
                Button {
                    elimina(modifica)
                    chiudi()
                } label: {
                    Text("Elimina").foregroundColor(Colori.Rubrica.pericolo)
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
            }
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button(modifica.nuovo ? "Aggiungi" : "Salva") {
                salva(modifica)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(!valido)
            .opacity(valido ? 1 : 0.5)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Rubrica.modulo.width, height: 380)
    }
}
