import SwiftUI

/// Scheda "Bisogni" del dossier: conoscere il cliente senza un questionario lungo.
/// 1. bisogni rilevati dai dati (con il motivo), da confermare o scartare;
/// 2. mappa delle sei aree di vita: due tocchi per area (quanto conta, entro quando);
/// 3. eventi di vita, che generano da soli i bisogni collegati.
/// Il risultato è la ruota dei bisogni, che orienta l'Analisi 360 e la traccia di Eve.
struct BisogniCliente: View {
    @EnvironmentObject var stato: StatoShell
    let cliente: Cliente
    @State var mostraScartati = false

    private var profilo: ProfiloBisogni { cliente.bisogni }

    var body: some View {
        let rilevati = stato.bisogniRilevati(cliente.id)
        let ruota = MotoreBisogni.ruota(rilevati, profilo: profilo)
        let priorita = MotoreBisogni.priorita(rilevati, profilo: profilo)
        VStack(alignment: .leading, spacing: 18) {
            OcchielloSezione(titolo: "La ruota dei bisogni",
                             nota: profilo.aggiornatoIl.map { "Aggiornata il \(Formati.dataEstesa.string(from: $0))" } ?? "Da costruire con il cliente")
            HStack(alignment: .top, spacing: 24) {
                RuotaBisogni(punteggi: ruota)
                    .frame(width: Misure.Bisogni.ruota, height: Misure.Bisogni.ruota)
                prioritaVista(priorita, ruota: ruota, rilevati: rilevati)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            rilevatiVista(rilevati)

            OcchielloSezione(titolo: "La mappa del cliente", nota: "Per ogni area: quanto conta e entro quando")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(AreaBisogno.allCases) { a in
                    CartaBisogno(area: a, valutazione: profilo.valutazione(a)) { v in
                        stato.aggiornaBisogni(cliente.id) { $0.imposta(v) }
                    }
                }
            }

            eventiVista

            Text("È il profilo del consulente per capire la persona: non sostituisce i questionari di adeguatezza ufficiali (MiFID, IVASS).")
                .font(Tipo.rubricaTema)
                .foregroundColor(Colori.Rubrica.secondario)
        }
    }

    // MARK: - Priorità

    private func prioritaVista(_ elenco: [AreaBisogno], ruota: [AreaBisogno: Importanza], rilevati: [BisognoRilevato]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if elenco.isEmpty {
                Text("La ruota è ancora vuota.").font(Tipo.bisognoTitolo).foregroundColor(Colori.Rubrica.testo)
                Text("Conferma i bisogni rilevati dai dati o indica con il cliente quanto conta ogni area: bastano due tocchi per area.")
                    .font(Tipo.bisognoTesto)
                    .foregroundColor(Colori.Rubrica.secondario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(elenco.prefix(3).enumerated()), id: \.element) { i, a in
                let importanza = ruota[a] ?? .nessuna
                let v = profilo.valutazione(a)
                let motivo = rilevati.first { $0.area == a && profilo.esiti[$0.id] != false }
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(Tipo.prioritaNumero).foregroundColor(Colori.Bisogni.area(a)).frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(a.nome).font(Tipo.bisognoTitolo).foregroundColor(Colori.Rubrica.testo)
                            Text(importanza.nome.uppercased())
                                .font(Tipo.bisognoArea)
                                .foregroundColor(Tema.Colore.Componenti.testoSuColore)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background { FormaVetro.capsula.fill(Colori.Bisogni.importanza(importanza)) }
                            if let o = v.orizzonte, v.importanza != .nessuna {
                                Text(o.nome).font(Tipo.bisognoNota).foregroundColor(Colori.Rubrica.secondario)
                            }
                        }
                        Text(motivo.map { "\($0.titolo): \(Self.minuscola($0.motivo))" } ?? "Indicato dal cliente.")
                            .font(Tipo.bisognoTesto)
                            .foregroundColor(Colori.Rubrica.secondario)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            stato.clienteAttivoId = cliente.id
                            stato.areaAnalisi = a.areaAnalisi
                            stato.apri(.analisi360)
                        } label: {
                            HStack(spacing: Tema.Misura.Componenti.spazioSimboloPulsante) {
                                Text("Analizza in Analisi 360 · \(a.areaAnalisi.nome)")
                                Image(systemName: "chevron.right")
                            }
                        }
                        .buttonStyle(StileCollegamento())
                    }
                }
            }
        }
    }

    // MARK: - Rilevati

    @ViewBuilder private func rilevatiVista(_ rilevati: [BisognoRilevato]) -> some View {
        let attivi = rilevati.filter { profilo.esiti[$0.id] != false }
        let scartati = rilevati.filter { profilo.esiti[$0.id] == false }
        OcchielloSezione(titolo: "Rilevati dai dati", nota: rilevati.isEmpty ? "Nessun segnale nei dati" : "Conferma o scarta: la ruota si aggiorna")
        if rilevati.isEmpty {
            Text("Più dati inserisci (famiglia, posizioni, Analisi 360), più Prisma riesce a suggerire i bisogni.")
                .font(Tipo.bisognoTesto)
                .foregroundColor(Colori.Rubrica.secondario)
        }
        VStack(spacing: 8) {
            ForEach(attivi) { b in
                rigaRilevato(b, confermato: profilo.esiti[b.id] == true)
            }
            if !scartati.isEmpty {
                Button(mostraScartati ? "Nascondi gli scartati" : "\(scartati.count) \(scartati.count == 1 ? "scartato" : "scartati") · mostra") {
                    mostraScartati.toggle()
                }
                .buttonStyle(StileSemplice())
                .font(Tipo.bisognoNota)
                .foregroundColor(Colori.Rubrica.secondario)
                .frame(maxWidth: .infinity, alignment: .leading)
                if mostraScartati {
                    ForEach(scartati) { b in
                        HStack {
                            Text(b.titolo).font(Tipo.bisognoTesto).strikethrough().foregroundColor(Colori.Bisogni.scartato)
                            Spacer()
                            Button("Ripristina") { stato.aggiornaBisogni(cliente.id) { $0.esiti[b.id] = nil } }
                                .buttonStyle(StileCuoioChiaro())
                        }
                    }
                }
            }
        }
    }

    private func rigaRilevato(_ b: BisognoRilevato, confermato: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: b.area.simbolo)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Tema.Colore.Componenti.testoSuColore)
                .frame(width: Misure.Bisogni.icona, height: Misure.Bisogni.icona)
                .background { FormaVetro.arrotondata(Tema.Raggio.Dossier.iconaBisogno).fill(Colori.Bisogni.area(b.area)) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(b.titolo).font(Tipo.bisognoTitolo).foregroundColor(Colori.Rubrica.testo)
                    Text(b.area.nome.uppercased()).font(Tipo.bisognoArea).foregroundColor(Colori.Bisogni.area(b.area))
                }
                Text(b.motivo)
                    .font(Tipo.bisognoTesto)
                    .foregroundColor(Colori.Rubrica.secondario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if confermato {
                HStack(spacing: 6) {
                    Label("Confermato", systemImage: "checkmark").font(Tipo.bisognoNota).foregroundColor(Colori.Bisogni.confermato)
                    Button("Annulla") { stato.aggiornaBisogni(cliente.id) { $0.esiti[b.id] = nil } }
                        .buttonStyle(StileSemplice())
                        .font(Tipo.bisognoNota)
                        .foregroundColor(Colori.Rubrica.secondario)
                }
            } else {
                HStack(spacing: 6) {
                    // Il blu dell'app è «Nuovo cliente»: qui la conferma è il vetro d'accento, non un altro blu
                    Button { stato.aggiornaBisogni(cliente.id) { $0.esiti[b.id] = false } } label: {
                        Label("Scarta", systemImage: "xmark")
                    }
                    .buttonStyle(StileVetro(taglia: .compatta))
                    Button { stato.aggiornaBisogni(cliente.id) { $0.esiti[b.id] = true } } label: {
                        Label("Conferma", systemImage: "checkmark")
                    }
                    .buttonStyle(StileVetro(taglia: .compatta, accento: true))
                }
            }
        }
        .padding(10)
        .vetro(.sottile, forma: .arrotondata(Misure.Bisogni.raggioCarta),
               riempimento: confermato ? Colori.Bisogni.confermatoFondo : Colori.Bisogni.cartaFondo)
    }

    // MARK: - Eventi di vita

    private var eventiVista: some View {
        let anno = Calendar(identifier: .gregorian).component(.year, from: Date())
        return VStack(alignment: .leading, spacing: 8) {
            OcchielloSezione(titolo: "Eventi di vita", nota: "Un tocco per aggiungerli: i bisogni collegati compaiono da soli")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(EventoVita.Tipo.allCases.filter { $0 != .altro }) { t in
                    Button {
                        stato.aggiornaBisogni(cliente.id) { $0.eventi.append(EventoVita(tipo: t, anno: anno + 1)) }
                    } label: {
                        Label(t.nome, systemImage: "plus")
                            .font(Tipo.bisognoTesto)
                            .foregroundColor(Colori.Bisogni.chipTesto)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vetro(.chip, forma: .capsula, riempimento: Colori.Bisogni.chipFondo)
                    }
                    .buttonStyle(StileSemplice())
                }
            }
            ForEach(profilo.eventi.sorted { $0.anno < $1.anno }) { e in
                HStack(spacing: 10) {
                    Text(e.tipo.nome).font(Tipo.bisognoTitolo).foregroundColor(Colori.Rubrica.testo).frame(width: 190, alignment: .leading)
                    Stepper(value: Binding(get: { e.anno }, set: { nuovo in
                        stato.aggiornaBisogni(cliente.id) { p in
                            if let i = p.eventi.firstIndex(where: { $0.id == e.id }) { p.eventi[i].anno = nuovo }
                        }
                    }), in: (anno - 30)...(anno + 40)) {
                        Text(verbatim: "\(e.anno)").font(Tipo.bisognoTesto).foregroundColor(Colori.Rubrica.testo).monospacedDigit()
                    }
                    .frame(width: 110)
                    // La nota passa al profilo poco dopo l'ultimo tasto, non a ogni lettera
                    TestoRinviato(testo: Binding(get: { e.nota }, set: { nuova in
                        stato.aggiornaBisogni(cliente.id) { p in
                            if let i = p.eventi.firstIndex(where: { $0.id == e.id }) { p.eventi[i].nota = nuova }
                        }
                    }), salvaOra: { stato.salvaOra() }) { bozza in
                        TextField("Nota", text: bozza)
                            .campoTesto()
                    }
                    .id("\(cliente.id)-\(e.id)")
                    Button("Togli") {
                        stato.aggiornaBisogni(cliente.id) { $0.eventi.removeAll { $0.id == e.id } }
                    }
                    .buttonStyle(StileCuoioChiaro())
                }
                .padding(.vertical, 4)
                .bordoBasso(Colori.Rubrica.filo)
            }
        }
    }

    /// Il motivo dopo i due punti comincia in minuscolo, salvo le sigle ("SRI", "TFR").
    static func minuscola(_ s: String) -> String {
        let due = Array(s.prefix(2))
        if due.count == 2, due[1].isUppercase { return s }
        return s.prefix(1).lowercased() + s.dropFirst()
    }
}

// MARK: - Carta di un'area

struct CartaBisogno: View {
    let area: AreaBisogno
    let valutazione: ValutazioneBisogno
    let cambia: (ValutazioneBisogno) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: area.simbolo)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Tema.Colore.Componenti.testoSuColore)
                    .frame(width: Misure.Bisogni.icona, height: Misure.Bisogni.icona)
                    .background { FormaVetro.arrotondata(Tema.Raggio.Dossier.iconaBisogno).fill(Colori.Bisogni.area(area)) }
                Text(area.nome).font(Tipo.bisognoTitolo).foregroundColor(Colori.Rubrica.testo).lineLimit(1)
            }
            Text(area.domanda)
                .font(Tipo.bisognoNota)
                .foregroundColor(Colori.Rubrica.secondario)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            SegmentiAnalisi(opzioni: Importanza.allCases.map { ($0, $0.nome) },
                            selezione: Binding(get: { valutazione.importanza }, set: { i in
                                var v = valutazione
                                v.importanza = i
                                if i == .nessuna { v.orizzonte = nil } else if v.orizzonte == nil { v.orizzonte = .medio }
                                cambia(v)
                            }))
            SegmentiAnalisi(opzioni: [(OrizzonteBisogno?.none, "—")] + OrizzonteBisogno.allCases.map { (Optional($0), $0.nome) },
                            selezione: Binding(get: { valutazione.orizzonte }, set: { o in
                                var v = valutazione
                                v.orizzonte = o
                                if o != nil && v.importanza == .nessuna { v.importanza = .media }
                                cambia(v)
                            }))
                .opacity(valutazione.importanza == .nessuna ? 0.55 : 1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Colori.Bisogni.importanza(valutazione.importanza)).frame(height: valutazione.importanza == .nessuna ? 0 : 3)
                .clipShape(RettangoloAngoli(altoSinistra: Misure.Bisogni.raggioCarta, altoDestra: Misure.Bisogni.raggioCarta))
        }
        .vetro(.sottile, forma: .arrotondata(Misure.Bisogni.raggioCarta), riempimento: Colori.Bisogni.cartaFondo)
    }
}

// MARK: - Ruota

/// Sei spicchi, uno per area: più conta, più lo spicchio è pieno e colorato.
struct RuotaBisogni: View {
    let punteggi: [AreaBisogno: Importanza]

    var body: some View {
        GeometryReader { geo in
            let lato = min(geo.size.width, geo.size.height)
            let centro = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let esterno = lato / 2
            let interno = esterno * Misure.Bisogni.foro
            let aree = AreaBisogno.allCases
            let ampiezza = 360.0 / Double(aree.count)
            ZStack {
                Circle().fill(Colori.Bisogni.ruotaFondo)
                Circle().strokeBorder(Colori.Bisogni.ruotaBordo, lineWidth: Tema.Misura.filo)
                ForEach(Array(aree.enumerated()), id: \.element) { i, a in
                    let p: Double = Double((punteggi[a] ?? .nessuna).rawValue) / 3
                    let raggio: CGFloat = interno + (esterno - interno) * CGFloat(0.25 + 0.75 * p)
                    let inizio = Angle.degrees(-90 + ampiezza * Double(i) + 1.5)
                    let fine = Angle.degrees(-90 + ampiezza * Double(i + 1) - 1.5)
                    Path { path in
                        path.addArc(center: centro, radius: raggio, startAngle: inizio, endAngle: fine, clockwise: false)
                        path.addArc(center: centro, radius: interno, startAngle: fine, endAngle: inizio, clockwise: true)
                        path.closeSubpath()
                    }
                    .fill(Colori.Bisogni.area(a).opacity(p == 0 ? 0.25 : 0.45 + 0.55 * p))
                    let medio = (-90 + ampiezza * (Double(i) + 0.5)) * Double.pi / 180
                    let distanza: CGFloat = interno + (esterno - interno) * 0.42
                    let px: CGFloat = centro.x + CGFloat(cos(medio)) * distanza
                    let py: CGFloat = centro.y + CGFloat(sin(medio)) * distanza
                    Image(systemName: a.simbolo)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Tema.Colore.Componenti.testoSuColore)
                        .position(x: px, y: py)
                }
                Circle().fill(Tema.Colore.scheda).frame(width: interno * 2 - 4, height: interno * 2 - 4)
                    .overlay(Circle().strokeBorder(Colori.Bisogni.ruotaBordo, lineWidth: Tema.Misura.filo))
                    .position(centro)
                VStack(spacing: 1) {
                    Text("PRIMA").font(Tipo.ruotaCentro).foregroundColor(Colori.Rubrica.secondario)
                    Text(primaArea?.nome.components(separatedBy: " ").first ?? "—")
                        .font(Tipo.ruotaValore)
                        .foregroundColor(primaArea.map { Colori.Bisogni.area($0) } ?? Colori.Rubrica.secondario)
                }
                .position(centro)
            }
        }
    }

    private var primaArea: AreaBisogno? {
        AreaBisogno.allCases
            .filter { (punteggi[$0] ?? .nessuna) > .nessuna }
            .max { (punteggi[$0] ?? .nessuna) < (punteggi[$1] ?? .nessuna) }
    }
}
