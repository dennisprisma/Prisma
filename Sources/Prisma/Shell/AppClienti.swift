import SwiftUI

/// App Clienti: rubrica in carta (indice a sinistra) e dossier del cliente a schede.
struct AppClienti: View {
    @EnvironmentObject var stato: StatoShell
    @State var ricerca = ""
    @State var soloPreferiti = false
    @State var modulo: Cliente?
    @State var familiare: ModificaFamiliare?

    private var elenco: [Cliente] {
        let testo = ricerca.trimmingCharacters(in: .whitespaces).lowercased()
        return stato.clienti
            .filter { !soloPreferiti || $0.preferito }
            .filter { testo.isEmpty || $0.nome.lowercased().contains(testo) || $0.tema.lowercased().contains(testo) }
            .sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending }
    }

    var body: some View {
        HStack(spacing: 0) {
            indice
                .frame(width: Misure.Rubrica.indice)
            dossier
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .leading) {
                    LinearGradient(colors: [Colori.Rubrica.divisoreOmbra, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 5)
                        .allowsHitTesting(false)
                }
        }
        .background(Colori.Rubrica.carta)
        .clipShape(RoundedRectangle(cornerRadius: Misure.Rubrica.raggioLibro))
        .overlay(RoundedRectangle(cornerRadius: Misure.Rubrica.raggioLibro).strokeBorder(Colori.Rubrica.libroBordo, lineWidth: 1))
        .shadow(color: Colori.Rubrica.libroRiflesso, radius: 0, x: 0, y: 1)
        .ombraCSS(Colori.Rubrica.libroOmbra, y: 2, sfocatura: 3)
        .sheet(item: $modulo) { c in
            ModuloCliente(
                bozza: c,
                nuovo: !stato.clienti.contains { $0.id == c.id },
                salva: { stato.salvaCliente($0) },
                elimina: { stato.eliminaCliente(c.id) }
            )
        }
        .sheet(item: $stato.importazione) { i in
            ModuloImportaClienti(importazione: i)
                .environmentObject(stato)
        }
        .sheet(item: $familiare) { m in
            ModuloFamiliare(modifica: m, salva: salvaFamiliare, elimina: eliminaFamiliare)
        }
        .onAppear { controllaRichiesta(stato.richiestaNuovoCliente) }
        .onChange(of: stato.richiestaNuovoCliente) { controllaRichiesta($0) }
    }

    private func controllaRichiesta(_ richiesta: Bool) {
        guard richiesta else { return }
        stato.richiestaNuovoCliente = false
        modulo = Cliente.nuovo(tinta: stato.prossimaTinta)
    }

    // MARK: - Indice

    private var indice: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RUBRICA")
                    .font(Tipo.indiceTitolo)
                    .tracking(0.6)
                    .foregroundColor(Colori.Rubrica.indiceTitolo)
                    .incisione(Color.white.opacity(0.53))
                Spacer()
                Text("\(stato.clienti.count)")
                    .font(Tipo.contatore)
                    .foregroundColor(Colori.Rubrica.contatoreTesto)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Gradienti.contatoreRubrica))
                    .overlay(Capsule().strokeBorder(Colori.Rubrica.contatoreBordo, lineWidth: 1))
            }
            .padding(EdgeInsets(top: 9, leading: 13, bottom: 7, trailing: 13))

            CampoRicerca(testo: $ricerca, segnaposto: "Cerca nome o progetto")
                .padding(.horizontal, 11)
            Segmentato(opzioni: [(false, "Tutti"), (true, "★ Preferiti")], selezione: $soloPreferiti)
                .padding(EdgeInsets(top: 7, leading: 11, bottom: 7, trailing: 11))

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(elenco) { c in
                        RigaRubrica(cliente: c, selezionato: c.id == stato.clienteAttivoId) {
                            stato.clienteAttivoId = c.id
                        }
                    }
                    if elenco.isEmpty {
                        Text(ricerca.isEmpty ? "Nessun cliente in rubrica." : "Nessun cliente trovato.")
                            .font(Tipo.rubricaTema)
                            .foregroundColor(Colori.Rubrica.rigaTema)
                            .padding(16)
                    }
                }
            }
            Text("\(stato.clienti.count) \(stato.clienti.count == 1 ? "contatto" : "contatti") · sempre a portata di mano")
                .font(Tipo.rubricaPiede)
                .tracking(0.6)
                .foregroundColor(Colori.Rubrica.piede)
                .incisione(Color.white.opacity(0.47))
                .multilineTextAlignment(.center)
                .padding(8)
                .frame(maxWidth: .infinity)
                .bordoAlto(Colori.Rubrica.piedeBordo)
        }
    }

    // MARK: - Dossier

    @ViewBuilder private var dossier: some View {
        if let c = stato.clienteAttivo {
            VStack(spacing: 0) {
                IntestazioneDossier(cliente: c) { modulo = c }
                SchedeRubrica(opzioni: SchedaCliente.allCases.map { ($0, $0.titolo) }, selezione: $stato.schedaCliente)
                ScrollView {
                    Group {
                        switch stato.schedaCliente {
                        case .panoramica: PanoramicaCliente(cliente: c)
                        case .bisogni: BisogniCliente(cliente: c)
                        case .anagrafica: anagrafica(c)
                        case .famiglia: famiglia(c)
                        case .profilo: profilo(c)
                        case .note: note(c)
                        }
                    }
                    .padding(Misure.Rubrica.margineContenuto)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            VStack(spacing: 10) {
                IconaApp(app: .clienti, lato: Misure.Scrivania.icona)
                Text("La rubrica è vuota.").font(Tipo.pannelloTitolo).foregroundColor(Colori.Rubrica.testo)
                Text("Aggiungi il primo cliente con \"Nuovo cliente\".").font(Tipo.pannelloTesto).foregroundColor(Colori.Rubrica.secondario)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func anagrafica(_ c: Cliente) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloSezione(titolo: "Dati personali")
                RigaCampo(etichetta: "Nome e cognome", valore: c.nome)
                RigaCampo(etichetta: "Data di nascita",
                          valore: c.dataNascita.map { "\(Formati.dataEstesa.string(from: $0))\(c.eta.map { " · \($0) anni" } ?? "")" } ?? "")
                RigaCampo(etichetta: "Codice fiscale", valore: c.codiceFiscale)
                RigaCampo(etichetta: "Professione", valore: c.professione)
                RigaCampo(etichetta: "Stato civile", valore: c.statoCivile?.nome ?? "")
            }
            VStack(alignment: .leading, spacing: 4) {
                OcchielloSezione(titolo: "Contatti")
                RigaCampo(etichetta: "Email", valore: c.email)
                RigaCampo(etichetta: "Telefono", valore: c.telefono)
                RigaCampo(etichetta: "Indirizzo", valore: c.indirizzo)
                RigaCampo(etichetta: "In rubrica dal", valore: Formati.dataEstesa.string(from: c.creatoIl))
            }
            Button("Modifica la scheda") { modulo = c }
                .buttonStyle(StileCuoioChiaro())
        }
    }

    private func famiglia(_ c: Cliente) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            OcchielloSezione(titolo: "Nucleo familiare",
                             nota: c.famiglia.isEmpty ? "Solo il cliente" : "\(c.famiglia.count + 1) persone con il cliente")
            if c.famiglia.isEmpty {
                Text("Nessun familiare indicato. Il nucleo familiare serve per le analisi di protezione e previdenza.")
                    .font(Tipo.rubricaTema)
                    .foregroundColor(Colori.Rubrica.secondario)
                    .padding(.vertical, 8)
            }
            ForEach(c.famiglia) { f in
                HStack(spacing: 12) {
                    AvatarCliente(iniziali: Cliente.iniziali(di: f.nome), tinta: c.tinta.colori, lato: Misure.Rubrica.avatarElenco)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.nome).font(Tipo.rubricaNome).foregroundColor(Colori.Rubrica.rigaNome)
                        Text([f.relazione.nome, f.eta.map { "\($0) anni" }, f.aCarico ? "a carico" : nil, f.nota.isEmpty ? nil : f.nota]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(Tipo.rubricaTema)
                            .foregroundColor(Colori.Rubrica.rigaTema)
                    }
                    Spacer()
                    Button("Modifica") { familiare = ModificaFamiliare(clienteId: c.id, familiare: f, nuovo: false) }
                        .buttonStyle(StileCuoioChiaro())
                }
                .padding(.vertical, 8)
                .bordoBasso(Colori.Rubrica.filo)
            }
            Button("＋ Aggiungi un familiare") {
                familiare = ModificaFamiliare(clienteId: c.id, familiare: Familiare(nome: "", relazione: .coniuge), nuovo: true)
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
            .padding(.top, 6)
        }
    }

    private func profilo(_ c: Cliente) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloSezione(titolo: "Profilo dell'investitore",
                                 nota: c.profilo.aggiornatoIl.map { "Aggiornato il \(Formati.dataEstesa.string(from: $0))" })
                RigaCampo(etichetta: "Propensione al rischio", valore: c.profilo.propensione?.nome ?? "")
                RigaCampo(etichetta: "Orizzonte temporale", valore: c.profilo.orizzonteAnni.map { "\($0) anni" } ?? "")
                RigaCampo(etichetta: "Esperienza finanziaria", valore: c.profilo.esperienza?.nome ?? "")
                RigaCampo(etichetta: "Reddito lordo annuo", valore: c.profilo.redditoLordoAnnuo.map { Formati.euro($0) } ?? "")
                RigaCampo(etichetta: "Obiettivi principali", valore: c.profilo.obiettivi)
            }
            VStack(alignment: .leading, spacing: 4) {
                OcchielloSezione(titolo: "Canali")
                HStack(spacing: 8) {
                    if c.canali.isEmpty {
                        Text("Nessun canale indicato").font(Tipo.campoValore).foregroundColor(Colori.Rubrica.secondario)
                    }
                    ForEach(c.canali) { EtichettaCanale(canale: $0) }
                }
                .padding(.vertical, 8)
            }
            VStack(alignment: .leading, spacing: 4) {
                OcchielloSezione(titolo: "Consensi")
                RigaCampo(etichetta: "Privacy", valore: c.consensi.privacy
                          ? "Sì" + (c.consensi.dataPrivacy.map { ", dal \(Formati.dataEstesa.string(from: $0))" } ?? "")
                          : "Non raccolto")
                RigaCampo(etichetta: "Comunicazioni commerciali", valore: c.consensi.marketing ? "Sì" : "No")
            }
            Text("Il profilo orienta le analisi di Posizioni. Non sostituisce i questionari di adeguatezza ufficiali.")
                .font(Tipo.rubricaTema)
                .foregroundColor(Colori.Rubrica.secondario)
            Button("Modifica il profilo") { modulo = c }
                .buttonStyle(StileCuoioChiaro())
        }
    }

    private func note(_ c: Cliente) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            OcchielloSezione(titolo: "Da ricordare", nota: "Si salva da sola")
            TextEditor(text: Binding(get: { c.nota }, set: { stato.aggiornaNota(c.id, $0) }))
                .font(Tipo.campoValore)
                .foregroundColor(Colori.Rubrica.testo)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .padding(10)
                .frame(minHeight: 260)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Rubrica.schedaAppBordo, lineWidth: 1))
            OcchielloSezione(titolo: "Nel taccuino", nota: "Le note dell'app Note")
                .padding(.top, 8)
            let note = stato.noteCliente(c.id).filter { !$0.vuota }
            if note.isEmpty {
                Text("Nessuna nota per \(c.nome). Gli appunti degli incontri trovano posto nel taccuino.")
                    .font(Tipo.rubricaTema)
                    .foregroundColor(Colori.Rubrica.secondario)
            } else {
                ForEach(note) { n in
                    Button { stato.vai(a: .nota(n.id)) } label: {
                        HStack(spacing: 8) {
                            if n.fissata { Text("◆").font(Tipo.noteVoceData).foregroundColor(Colori.Note.fissata) }
                            Text(n.titoloMostrato).font(Tipo.campoValore).foregroundColor(Colori.Rubrica.testo).lineLimit(1)
                            Spacer()
                            Text(Formati.giornoMeseBreve.string(from: n.aggiornataIl)).font(Tipo.rubricaTema).foregroundColor(Colori.Rubrica.secondario)
                            Text("›").font(Tipo.rubricaFreccia).foregroundColor(Colori.Rubrica.rigaFreccia)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(StileSemplice())
                    .bordoBasso(Colori.Rubrica.rigaBordo)
                }
            }
            Button("＋ Nuova nota per \(c.nome)") {
                stato.filtroClienteNote = c.id
                stato.nuovaNota(clienteId: c.id)
                stato.apri(.note)
            }
            .buttonStyle(StileCuoioChiaro())
        }
    }

    // MARK: - Familiari

    private func salvaFamiliare(_ m: ModificaFamiliare) {
        guard var c = stato.cliente(m.clienteId) else { return }
        if let i = c.famiglia.firstIndex(where: { $0.id == m.familiare.id }) {
            c.famiglia[i] = m.familiare
        } else {
            c.famiglia.append(m.familiare)
        }
        stato.salvaCliente(c)
    }

    private func eliminaFamiliare(_ m: ModificaFamiliare) {
        guard var c = stato.cliente(m.clienteId) else { return }
        c.famiglia.removeAll { $0.id == m.familiare.id }
        stato.salvaCliente(c)
    }
}

struct ModificaFamiliare: Identifiable {
    let id = UUID()
    let clienteId: String
    var familiare: Familiare
    let nuovo: Bool
}

// MARK: - Riga della rubrica

struct RigaRubrica: View {
    let cliente: Cliente
    let selezionato: Bool
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 10) {
                AvatarCliente(iniziali: cliente.iniziali, tinta: cliente.tinta.colori, lato: Misure.Rubrica.avatarElenco)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cliente.nome)
                        .font(Tipo.rubricaNome)
                        .foregroundColor(selezionato ? .white : Colori.Rubrica.rigaNome)
                    Text(cliente.tema)
                        .font(Tipo.rubricaTema)
                        .foregroundColor(selezionato ? Colori.Rubrica.selezioneTema : Colori.Rubrica.rigaTema)
                }
                .lineLimit(1)
                .incisione(selezionato ? Colori.Rubrica.selezioneIncisione : .clear, y: -1)
                Spacer(minLength: 2)
                if cliente.preferito {
                    Text("★")
                        .font(Tipo.contenuto(14, .bold))
                        .foregroundColor(selezionato ? Colori.Rubrica.stellaSelezione : Colori.Rubrica.stella)
                } else {
                    Text("›")
                        .font(Tipo.rubricaFreccia)
                        .foregroundColor(selezionato ? .white : Colori.Rubrica.rigaFreccia)
                }
            }
            .padding(Misure.Rubrica.margineRiga)
            .frame(maxWidth: .infinity)
            .background(selezionato ? AnyShapeStyle(Gradienti.selezioneRubrica) : AnyShapeStyle(Color.clear))
            .bordoAlto(selezionato ? Colori.Rubrica.selezioneBordoAlto : Colori.Rubrica.rigaLuce)
            .bordoBasso(selezionato ? Colori.Rubrica.selezioneBordoBasso : Colori.Rubrica.rigaBordo)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }
}

// MARK: - Campo di ricerca

struct CampoRicerca: View {
    @Binding var testo: String
    let segnaposto: String

    var body: some View {
        HStack(spacing: 6) {
            Text("⌕").font(Tipo.contenuto(18)).foregroundColor(Colori.Rubrica.cerca)
            TextField(segnaposto, text: $testo)
                .textFieldStyle(.plain)
                .font(Tipo.sistema(12))
            if !testo.isEmpty {
                Button { testo = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Colori.Rubrica.cerca)
                }
                .buttonStyle(StileSemplice())
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))
        .overlay(alignment: .top) {
            LinearGradient(colors: [Color.black.opacity(0.13), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 2)
                .padding(.horizontal, 1)
                .allowsHitTesting(false)
        }
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Pulsante.segmentoBordo, lineWidth: 1))
        .shadow(color: Color.white.opacity(0.4), radius: 0, x: 0, y: 1)
    }
}

// MARK: - Intestazione del dossier

struct IntestazioneDossier: View {
    @EnvironmentObject var stato: StatoShell
    let cliente: Cliente
    let modifica: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarCliente(iniziali: cliente.iniziali, tinta: cliente.tinta.colori, lato: Misure.Rubrica.avatarProfilo)
                .padding(Misure.Rubrica.cornicesAvatar)
                .background(Circle().fill(Colori.Rubrica.avatarCornice))
                .ombraCSS(Colori.Rubrica.avatarOmbra, y: 1, sfocatura: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("DOSSIER PERSONALE")
                    .font(Tipo.profiloOcchiello)
                    .tracking(0.7)
                    .foregroundColor(Colori.Rubrica.profiloOcchiello)
                    .incisione(Colori.Rubrica.profiloOcchielloIncisione)
                Text(cliente.nome)
                    .font(Tipo.profiloNome)
                    .tracking(-0.5)
                    .foregroundColor(Colori.Rubrica.profiloNome)
                    .incisione(Colori.Rubrica.profiloNomeIncisione)
                Text(cliente.tema)
                    .font(Tipo.profiloTema)
                    .foregroundColor(Colori.Rubrica.profiloOcchiello)
                    .incisione(Colori.Rubrica.profiloOcchielloIncisione)
            }
            .lineLimit(1)
            Spacer()
            HStack(spacing: 6) {
                ForEach(cliente.canali) { EtichettaCanale(canale: $0, compatta: true) }
            }
            Button {
                stato.alternaPreferito(cliente.id)
            } label: {
                Text(cliente.preferito ? "★" : "☆")
                    .font(Tipo.stellaGrande)
                    .foregroundColor(cliente.preferito ? Colori.Rubrica.stellaGrande : Colori.Rubrica.stellaVuota)
                    .ombraCSS(Color.black.opacity(cliente.preferito ? 0.4 : 0), y: 1, sfocatura: 2)
            }
            .buttonStyle(StileSemplice())
            .help(cliente.preferito ? "Togli dai preferiti" : "Aggiungi ai preferiti")
            Button("Modifica", action: modifica)
                .buttonStyle(StileCuoioChiaro())
        }
        .padding(Misure.Rubrica.margineProfilo)
        .frame(minHeight: 86)
        .background(
            ZStack {
                Gradienti.selleria
                Materiale.Trama(nome: "Grana")
            }
        )
        .luceInterna(Colori.Rubrica.selleriaLuce, bordo: 0)
        .ombraInternaBasso(Colori.Rubrica.selleriaLuceBasso, spessore: 1, bordo: 3)
        .bordoBasso(Colori.Rubrica.selleriaBordo, spessore: 3)
    }
}

// MARK: - Panoramica

struct PanoramicaCliente: View {
    @EnvironmentObject var stato: StatoShell
    let cliente: Cliente

    var body: some View {
        let prossimo = stato.prossimiAppuntamenti.first { $0.clienteId == cliente.id }
        let aperte = stato.attivitaCliente(cliente.id).filter { !$0.completata }
        let aCarico = cliente.famiglia.filter(\.aCarico).count
        VStack(alignment: .leading, spacing: 14) {
            OcchielloSezione(titolo: "Il quadro d'insieme", nota: "Una scheda, tutte le app.")
            FasciaMetriche(metriche: [
                .init(etichetta: "Età", valore: cliente.eta.map { "\($0) anni" } ?? "—",
                      nota: cliente.professione.isEmpty ? "Professione non indicata" : cliente.professione),
                .init(etichetta: "Nucleo familiare", valore: "\(cliente.famiglia.count + 1) \(cliente.famiglia.isEmpty ? "persona" : "persone")",
                      nota: aCarico == 0 ? "Nessuno a carico" : "\(aCarico) a carico"),
                .init(etichetta: "Da seguire", valore: "\(aperte.count) \(aperte.count == 1 ? "attività" : "attività")",
                      nota: prossimo.map { "Prossimo incontro \(Formati.giorno.string(from: $0.inizio)) \(Formati.meseBreve.string(from: $0.inizio)), \(Formati.ora.string(from: $0.inizio))" }
                          ?? "Nessun incontro in programma"),
            ])
            if !cliente.nota.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    OcchielloSezione(titolo: "Da ricordare")
                    Text(cliente.nota)
                        .font(Tipo.campoValore)
                        .foregroundColor(Colori.Rubrica.testo)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            riesame
            OcchielloSezione(titolo: "Il dossier collegato")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Misure.Rubrica.schedaAppMinima), spacing: 8)], spacing: 8) {
                collegamento(.posizioni, "In essere e in proposta")
                collegamento(.analisi360, "Previdenza, protezione, investimenti")
                collegamento(.incontri, "Appunti, decisioni e seguiti")
                collegamento(.obiettivi, "I progetti da realizzare")
                collegamento(.agenda, "Appuntamenti", conteggio: stato.appuntamentiCliente(cliente.id).count)
                collegamento(.attivita, "Azioni ancora aperte", conteggio: aperte.count)
                collegamento(.documenti, "Il materiale del dossier")
                collegamento(.note, "Appunti e idee")
                collegamento(.presentazioni, "Prospetti in PDF")
                collegamento(.eve, "Ragiona su questo cliente")
            }
        }
    }

    /// Il riesame annuale, quando è dovuto: quanti punti ci sono da trattare e il prospetto per prepararlo.
    @ViewBuilder private var riesame: some View {
        if let f = stato.fonteEve(cliente.id) {
            let r = MotoreRiesame.calcola(f)
            if r.dovuto, r.prossimo == nil, !r.punti.isEmpty {
                let alta = r.punti.filter { $0.priorita == .alta }.count
                VStack(alignment: .leading, spacing: 6) {
                    OcchielloSezione(titolo: "Riesame annuale", nota: r.ultimoContatto.map { "Ultimo incontro il \(Formati.dataEstesa.string(from: $0))" } ?? "Nessun incontro registrato")
                    HStack(alignment: .center, spacing: 12) {
                        Text("\(r.punti.count) punti da trattare" + (alta > 0 ? ", \(alta) con priorità alta" : "") + ": " + r.punti.prefix(2).map(\.titolo).joined(separator: "; ") + (r.punti.count > 2 ? "…" : "."))
                            .font(Tipo.campoValore)
                            .foregroundColor(Colori.Rubrica.testo)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("Prepara il riesame") {
                            stato.clienteAttivoId = cliente.id
                            stato.apriProspetto(.riesame)
                        }
                        .buttonStyle(StileCuoioChiaro())
                    }
                }
            }
        }
    }

    private func collegamento(_ app: AppPrisma, _ sottotitolo: String, conteggio: Int? = nil) -> some View {
        SchedaAppCollegata(app: app, sottotitolo: sottotitolo, conteggio: conteggio) {
            stato.clienteAttivoId = cliente.id
            stato.apri(app)
        }
    }
}
