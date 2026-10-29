import SwiftUI

/// Il modulo delle date di conformità del cliente («In regola · Giulia Rossi»): questionari e adeguata verifica
/// per canale, documento d'identità, privacy e consenso commerciale, voci non richieste. Lavora su una copia
/// della conformità e la scrive nella scheda solo al salvataggio (vuota: nil). Non sa niente di Eve né dei PDF.
struct ModuloConformita: View {
    @Environment(\.dismiss) private var chiudi
    @State private var bozza: Cliente
    @State private var conformita: ConformitaCliente
    let regole: RegoleConformita
    let salva: (Cliente) -> Void

    init(bozza: Cliente, regole: RegoleConformita, salva: @escaping (Cliente) -> Void) {
        _bozza = State(initialValue: bozza)
        _conformita = State(initialValue: bozza.conformita ?? ConformitaCliente())
        self.regole = regole
        self.salva = salva
    }

    /// La data proposta quando si spunta una data: oggi, a minuti interi come il resto dell'archivio.
    private var oggi: Date { Appuntamento.alMinuto(Date()) }

    var body: some View {
        let m = Tema.Misura.Conformita.self
        CorniceModulo(titolo: "In regola · \(bozza.nome)") {
            VStack(alignment: .leading, spacing: m.spazioSezioniModulo) {
                ForEach(Canale.allCases) { canale in
                    sezioneCanale(canale)
                }
                sezioneDocumento
                sezioneConsensi
                sezioneNonRichieste
            }
        } piede: {
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro())
                .keyboardShortcut(.cancelAction)
            Button("Salva") {
                var c = bozza
                c.conformita = MotoreConformita.normalizzata(conformita)
                salva(c)
                chiudi()
            }
            .buttonStyle(StileBlu())
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Rubrica.modulo.width, height: Misure.Rubrica.modulo.height)
    }

    // MARK: - Sezioni

    /// Questionario e adeguata verifica di un canale, con l'etichetta del canale in testa.
    private func sezioneCanale(_ c: Canale) -> some View {
        let m = Tema.Misura.Conformita.self
        let q = questionario(c)
        let v = verifica(c)
        return VStack(alignment: .leading, spacing: m.spazioCampiModulo) {
            EtichettaCanale(canale: c)
            CampoModulo(etichetta: "Questionario compilato il") {
                CampoDataFacoltativa(data: q.compilatoIl, predefinita: oggi)
            }
            CampoModulo(etichetta: "Validità") {
                MenuTendina(selezione: q.validitaMesi, opzioni: opzioniValidita(c), larghezza: m.tendinaValidita)
            }
            CampoModulo(etichetta: "Profilo risultante") {
                TextField("Come scritto sul questionario", text: testo(q.esito)).textFieldStyle(.roundedBorder)
            }
            CampoModulo(etichetta: "Adeguata verifica il") {
                CampoDataFacoltativa(data: v.eseguitaIl, predefinita: oggi)
            }
            CampoModulo(etichetta: "Rischio") {
                MenuTendina(selezione: v.rischio, opzioni: opzioniRischio, larghezza: m.tendinaRischio)
            }
        }
    }

    private var sezioneDocumento: some View {
        let m = Tema.Misura.Conformita.self
        let d = documento
        let proposta = scadenzaProposta
        return VStack(alignment: .leading, spacing: m.spazioCampiModulo) {
            OcchielloSezione(titolo: "Documento d'identità")
            CampoModulo(etichetta: "Tipo") {
                MenuTendina(selezione: d.tipo, opzioni: opzioniDocumento, larghezza: m.tendinaDocumento)
            }
            CampoModulo(etichetta: "Numero") {
                TextField("", text: testo(d.numero))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: m.campoNumero)
            }
            CampoModulo(etichetta: "Rilasciato il") {
                CampoDataFacoltativa(data: d.rilasciatoIl, predefinita: oggi)
            }
            CampoModulo(etichetta: "Scadenza") {
                HStack(spacing: m.spazioCampoPulsante) {
                    CampoDataFacoltativa(data: d.scadenza, predefinita: proposta ?? oggi)
                    Button("Calcola dal rilascio") { d.scadenza.wrappedValue = proposta }
                        .buttonStyle(StileCuoioChiaro())
                        .disabled(proposta == nil)
                        .help("Carta d'identità e passaporto: la scadenza di legge dalla data di rilascio")
                }
            }
            Text("Carta d'identità: 10 anni per i maggiorenni, fino al compleanno successivo. Controlla sempre la data stampata sul documento.")
                .font(Tema.Testo.Inserimento.nota)
                .foregroundColor(Tema.Colore.Inserimento.nota)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sezioneConsensi: some View {
        let m = Tema.Misura.Conformita.self
        return VStack(alignment: .leading, spacing: m.spazioCampiModulo) {
            OcchielloSezione(titolo: "Privacy e comunicazioni")
            CampoModulo(etichetta: "Privacy") {
                Toggle("Consenso al trattamento dei dati raccolto", isOn: Binding(
                    get: { bozza.consensi.privacy },
                    set: { bozza.consensi.privacy = $0; if $0, bozza.consensi.dataPrivacy == nil { bozza.consensi.dataPrivacy = oggi } }
                ))
                .stileCasella()
            }
            CampoModulo(etichetta: "Firmata il") {
                CampoDataFacoltativa(data: $bozza.consensi.dataPrivacy, predefinita: oggi)
            }
            CampoModulo(etichetta: "Commerciale") {
                Toggle("Consenso alle comunicazioni commerciali", isOn: Binding(
                    get: { bozza.consensi.marketing },
                    set: { bozza.consensi.marketing = $0; bozza.consensi.dataMarketing = oggi }
                ))
                .stileCasella()
            }
            CampoModulo(etichetta: "Dato o tolto il") {
                CampoDataFacoltativa(data: $bozza.consensi.dataMarketing, predefinita: oggi)
            }
        }
    }

    private var sezioneNonRichieste: some View {
        let m = Tema.Misura.Conformita.self
        let tipi = VoceConformita.Tipo.allCases.filter { $0 != .privacy }
        return VStack(alignment: .leading, spacing: m.spazioCampiModulo) {
            GruppoCampi(titolo: "Non richiesti per questo cliente",
                        spiegazione: "Le voci spuntate escono dalle scadenze, dalle notifiche e dal riesame. L'informativa privacy serve sempre.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: m.colonnaCasella), alignment: .leading)],
                      alignment: .leading, spacing: m.spazioCampiModulo) {
                ForEach(tipi, id: \.self) { t in
                    Toggle(TestiConformita.maiuscola(TestiConformita.nomeBreve(t)), isOn: nonRichiesta(t))
                        .stileCasella()
                }
            }
        }
    }

    // MARK: - Collegamenti alla bozza

    /// Il questionario di un canale (un record vuoto se manca: al salvataggio torna nil).
    private func questionario(_ c: Canale) -> Binding<QuestionarioAdeguatezza> {
        Binding(get: { conformita.questionario(c) ?? QuestionarioAdeguatezza() },
                set: { conformita.impostaQuestionario($0, canale: c) })
    }

    /// L'adeguata verifica di un canale.
    private func verifica(_ c: Canale) -> Binding<AdeguataVerifica> {
        Binding(get: { conformita.verifica(c) ?? AdeguataVerifica() },
                set: { conformita.impostaVerifica($0, canale: c) })
    }

    private var documento: Binding<DocumentoIdentita> {
        Binding(get: { conformita.documento ?? DocumentoIdentita() },
                set: { conformita.documento = $0 })
    }

    /// Un testo facoltativo: vuoto = nil.
    private func testo(_ b: Binding<String?>) -> Binding<String> {
        Binding(get: { b.wrappedValue ?? "" },
                set: { b.wrappedValue = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 })
    }

    /// Una voce segnata «non richiesta per questo cliente».
    private func nonRichiesta(_ t: VoceConformita.Tipo) -> Binding<Bool> {
        Binding(get: { conformita.nonRichiesta(t.rawValue) },
                set: { attiva in
                    var elenco = (conformita.nonRichieste ?? []).filter { $0 != t.rawValue }
                    if attiva { elenco.append(t.rawValue) }
                    // Nell'ordine della scheda, come le voci
                    let ordine = VoceConformita.Tipo.allCases.map(\.rawValue)
                    elenco.sort { (ordine.firstIndex(of: $0) ?? ordine.count) < (ordine.firstIndex(of: $1) ?? ordine.count) }
                    conformita.nonRichieste = elenco.isEmpty ? nil : elenco
                })
    }

    // MARK: - Opzioni

    /// Validità del questionario: come in Impostazioni o da 1 a 5 anni (più quella registrata, se è un'altra).
    private func opzioniValidita(_ c: Canale) -> [(Int?, String)] {
        var mesi = [12, 24, 36, 48, 60]
        if let attuale = conformita.questionario(c)?.validitaMesi, !mesi.contains(attuale) {
            mesi.append(attuale)
            mesi.sort()
        }
        let predefinita = "Come in Impostazioni (\(TestiConformita.durata(regole.mesiQuestionario(c))))"
        let scelte: [(Int?, String)] = mesi.map { m -> (Int?, String) in (Optional(m), TestiConformita.durata(m)) }
        return [(Int?.none, predefinita)] + scelte
    }

    /// Il rischio: con la periodicità dell'adeguata verifica di Impostazioni.
    private var opzioniRischio: [(RischioRiciclaggio?, String)] {
        let voci: [(RischioRiciclaggio?, String)] = RischioRiciclaggio.allCases.map { r -> (RischioRiciclaggio?, String) in
            let ogni = TestiConformita.durata(MotoreConformita.mesi(regole.mesiVerifica(r)))
            return (Optional(r), "\(r.nome) · ogni \(ogni)" + (r == .alto ? " (rafforzata)" : ""))
        }
        return [(RischioRiciclaggio?.none, "Non indicato")] + voci
    }

    /// Il tipo di documento: «Non indicato» e i quattro tipi.
    private var opzioniDocumento: [(TipoDocumentoIdentita?, String)] {
        let tipi: [(TipoDocumentoIdentita?, String)] = TipoDocumentoIdentita.allCases.map { t -> (TipoDocumentoIdentita?, String) in
            (Optional(t), t.nome)
        }
        return [(TipoDocumentoIdentita?.none, "Non indicato")] + tipi
    }

    /// La scadenza di legge dalla data di rilascio (carta d'identità e passaporto), nil se non si può stimare.
    private var scadenzaProposta: Date? {
        guard let d = conformita.documento, let tipo = d.tipo, let rilascio = d.rilasciatoIl else { return nil }
        guard let s = MotoreConformita.scadenzaProposta(tipo: tipo, rilascio: rilascio, nascita: bozza.dataNascita) else { return nil }
        return Appuntamento.alMinuto(s)
    }
}
