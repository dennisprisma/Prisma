import SwiftUI

/// Cornice dei moduli (tema Liquid Glass): testa con il titolo, contenuto su una scheda chiara,
/// piede con i pulsanti; fili da 0,5 pt, colori che seguono l'aspetto chiaro o scuro.
struct CorniceModulo<Contenuto: View, Piede: View>: View {
    let titolo: String
    @ViewBuilder let contenuto: () -> Contenuto
    @ViewBuilder let piede: () -> Piede

    var body: some View {
        let m = Tema.Misura.PannelliShell.self
        VStack(spacing: 0) {
            Text(titolo)
                .font(Tema.Testo.PannelliShell.titoloModulo)
                .foregroundColor(Tema.Colore.inchiostro)
                .frame(maxWidth: .infinity)
                .frame(height: m.testaModulo)
                .bordoBasso(Tema.Colore.separatore)
            ScrollView {
                contenuto()
                    .padding(m.margineModulo)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Tema.Colore.scheda)
            HStack(spacing: m.spazioPiedeModulo) {
                piede()
            }
            .padding(.horizontal, m.marginePiedeModulo)
            .frame(height: m.piedeModulo)
            .frame(maxWidth: .infinity)
            .bordoAlto(Tema.Colore.separatore)
        }
        .background(Tema.Colore.finestraPiena)
    }
}

/// Riga di un modulo: etichetta a sinistra, controllo a destra.
struct CampoModulo<Controllo: View>: View {
    let etichetta: String
    @ViewBuilder let controllo: () -> Controllo

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tema.Misura.PannelliShell.spazioCampoModulo) {
            Text(etichetta)
                .font(Tipo.campoEtichetta)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .frame(width: Tema.Misura.PannelliShell.etichettaModulo, alignment: .trailing)
            controllo()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Data facoltativa: interruttore "indicata" e selettore della data.
struct CampoDataFacoltativa: View {
    @Binding var data: Date?
    var predefinita: Date
    /// Il testo accanto alla casella ("Indicata" nei moduli, "Entro una data" negli incontri).
    var etichetta = "Indicata"
    /// Il carattere della casella (nil: quello del contesto).
    var font: Font? = nil

    var body: some View {
        HStack(spacing: 10) {
            Toggle(etichetta, isOn: Binding(get: { data != nil }, set: { data = $0 ? (data ?? predefinita) : nil }))
                .toggleStyle(.checkbox)
                .font(font)
            if data != nil {
                DatePicker("", selection: Binding(get: { data ?? predefinita }, set: { data = $0 }), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .environment(\.locale, Formati.italiano)
            }
        }
    }
}

// MARK: - Dati per l'analisi: sezioni ripiegabili e campi facoltativi

/// Sezione ripiegabile dei moduli («Dati per l'analisi»): chiusa all'inizio, per non appesantire il
/// modulo. La nota nella testa dice quanti dati sono già indicati.
struct SezioneRipiegabile<Contenuto: View>: View {
    let titolo: String
    let nota: String?
    let contenuto: () -> Contenuto
    @State private var aperta: Bool

    init(_ titolo: String, nota: String? = nil, aperta: Bool = false, @ViewBuilder contenuto: @escaping () -> Contenuto) {
        self.titolo = titolo
        self.nota = nota
        self.contenuto = contenuto
        _aperta = State(initialValue: aperta)
    }

    var body: some View {
        let m = Tema.Misura.Inserimento.self
        VStack(alignment: .leading, spacing: m.spazioSezione) {
            Button {
                withAnimation(Tema.Moto.sezioneRipiegabile) { aperta.toggle() }
            } label: {
                HStack(spacing: m.spazioTesta) {
                    Image(systemName: "chevron.right")
                        .font(Tema.Testo.Inserimento.freccia)
                        .foregroundColor(Tema.Colore.Inserimento.freccia)
                        .rotationEffect(.degrees(aperta ? 90 : 0))
                        .frame(width: m.freccia)
                    Text(titolo)
                        .font(Tema.Testo.Inserimento.titolo)
                        .foregroundColor(Tema.Colore.Inserimento.titolo)
                    Spacer(minLength: m.spazioTesta)
                    if let nota {
                        Text(nota)
                            .font(Tema.Testo.Inserimento.nota)
                            .foregroundColor(Tema.Colore.Inserimento.nota)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(StileSemplice())
            .help(aperta ? "Chiudi la sezione" : "Apri la sezione")
            if aperta {
                VStack(alignment: .leading, spacing: m.spazioCampi) {
                    contenuto()
                }
                .padding(m.margineSezione)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Tema.Raggio.Inserimento.sezione, style: .continuous)
                        .fill(Tema.Colore.Inserimento.fondoSezione)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Tema.Raggio.Inserimento.sezione, style: .continuous)
                        .strokeBorder(Tema.Colore.Inserimento.bordoSezione, lineWidth: Tema.Misura.filo)
                )
            }
        }
    }
}

/// Testi comuni delle sezioni «Dati per l'analisi».
enum DatiPerAnalisi {
    /// Nota nella testa della sezione: «facoltativi» o quanti dati sono indicati.
    static func nota(_ indicati: Int) -> String {
        switch indicati {
        case 0: return "facoltativi"
        case 1: return "1 dato indicato"
        default: return "\(indicati) dati indicati"
        }
    }

    /// Quanti valori sono indicati tra quelli passati.
    static func conta(_ valori: [Bool]) -> Int { valori.filter { $0 }.count }
}

/// Sottotitolo di un gruppo di campi dentro una sezione ripiegabile, con la frase che spiega a cosa serve.
struct GruppoCampi: View {
    let titolo: String
    var spiegazione: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioGruppo) {
            Text(titolo)
                .font(Tema.Testo.Inserimento.gruppo)
                .foregroundColor(Tema.Colore.inchiostro)
            if let spiegazione {
                Text(spiegazione)
                    .font(Tema.Testo.Inserimento.nota)
                    .foregroundColor(Tema.Colore.Inserimento.nota)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, Tema.Misura.Inserimento.sopraGruppo)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Cifra facoltativa con la sua unità: vuota = non indicata (nil).
struct CampoCifraFacoltativa: View {
    @Binding var valore: Double?
    let unita: String
    var larghezza: CGFloat = Tema.Misura.Inserimento.campoPercento

    private static let formato = FloatingPointFormatStyle<Double>.number.locale(Formati.italiano)

    var body: some View {
        HStack(spacing: Tema.Misura.Inserimento.spazioUnita) {
            TextField("—", value: $valore, format: Self.formato)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: larghezza)
            Text(unita)
                .font(Tipo.campoEtichetta)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Numero intero facoltativo (anni, mesi, un anno di calendario) con la sua unità: vuoto = nil.
/// Senza separatore delle migliaia, perché il 1996 resti «1996».
struct CampoInteroFacoltativo: View {
    @Binding var valore: Int?
    let unita: String
    var larghezza: CGFloat = Tema.Misura.Inserimento.campoAnni

    private static let formato = IntegerFormatStyle<Int>.number.grouping(.never)

    var body: some View {
        HStack(spacing: Tema.Misura.Inserimento.spazioUnita) {
            TextField("—", value: $valore, format: Self.formato)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: larghezza)
            Text(unita)
                .font(Tipo.campoEtichetta)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension DatiLavoro {
    /// Quanti dati del lavoro sono indicati (per la nota della sezione).
    var datiIndicati: Int {
        DatiPerAnalisi.conta([tipo != nil, aliquotaContributiva != nil, redditoLavoro != nil, crescitaReddito != nil,
                              anniContributi != nil, annoPrimoContributo != nil, montanteContributivo != nil,
                              etaPensione != nil])
    }
}

/// Lavoro e contributi di una persona (cliente o familiare), per la pensione pubblica stimata con il
/// metodo contributivo. Tutti facoltativi: se si svuotano tutti, il dato torna «non indicato» (nil).
/// Sotto i campi, la stima che ne esce, presentata come stima.
struct CampiLavoro: View {
    @Binding var lavoro: DatiLavoro?
    /// Data di nascita della persona, per l'età da cui parte la stima.
    let nascita: Date?
    /// Reddito lordo di ripiego se il reddito da lavoro manca (per il cliente: quello del profilo).
    var redditoRipiego: Double? = nil
    /// Unità e ripiego del reddito da lavoro.
    var notaReddito = "€ lordi l'anno"
    /// Unità e ripiego dell'età di pensione.
    var notaEtaPensione = "anni · se vuota, 67"

    var body: some View {
        let m = Tema.Misura.Inserimento.self
        VStack(alignment: .leading, spacing: m.spazioCampi) {
            CampoModulo(etichetta: "Tipo di lavoratore") {
                MenuTendina(selezione: tipo, opzioni: opzioniTipo, larghezza: m.tendinaLavoro)
            }
            CampoModulo(etichetta: "Aliquota contributiva") {
                CampoCifraFacoltativa(valore: campo(\.aliquotaContributiva), unita: notaAliquota)
            }
            CampoModulo(etichetta: "Reddito da lavoro") {
                CampoCifraFacoltativa(valore: campo(\.redditoLavoro), unita: notaReddito, larghezza: m.campoEuro)
            }
            CampoModulo(etichetta: "Crescita del reddito") {
                CampoCifraFacoltativa(valore: campo(\.crescitaReddito), unita: "% l'anno, oltre l'inflazione")
            }
            CampoModulo(etichetta: "Anni di contributi") {
                CampoCifraFacoltativa(valore: campo(\.anniContributi), unita: "anni già versati")
            }
            CampoModulo(etichetta: "Primo contributo") {
                CampoInteroFacoltativo(valore: campo(\.annoPrimoContributo), unita: "anno · prima del 1996 il sistema è misto")
            }
            CampoModulo(etichetta: "Montante contributivo") {
                CampoCifraFacoltativa(valore: campo(\.montanteContributivo), unita: "€ dall'estratto conto INPS", larghezza: m.campoEuro)
            }
            CampoModulo(etichetta: "Età di pensione") {
                CampoInteroFacoltativo(valore: campo(\.etaPensione), unita: notaEtaPensione)
            }
            CampoModulo(etichetta: "Pensione stimata") { vistaStima }
        }
    }

    private var vistaStima: some View {
        let s = stima
        return VStack(alignment: .leading, spacing: Tema.Misura.Inserimento.spazioGruppo) {
            if let valore = s.valore {
                Text(valore)
                    .font(Tema.Testo.Inserimento.stima)
                    .foregroundColor(Tema.Colore.Inserimento.stima)
            }
            Text(s.nota)
                .font(Tema.Testo.Inserimento.nota)
                .foregroundColor(Tema.Colore.Inserimento.nota)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Un campo del lavoro: scrive nel dato, e se tutto torna vuoto il lavoro torna nil.
    private func campo<T>(_ chiave: WritableKeyPath<DatiLavoro, T>) -> Binding<T> {
        Binding(
            get: { (lavoro ?? DatiLavoro())[keyPath: chiave] },
            set: { nuovo in
                var l = lavoro ?? DatiLavoro()
                l[keyPath: chiave] = nuovo
                lavoro = l == DatiLavoro() ? nil : l
            }
        )
    }

    /// Le voci della tendina del tipo di lavoratore: prima «Non indicato».
    private var opzioniTipo: [(TipoLavoratore?, String)] {
        let tipi: [(TipoLavoratore?, String)] = TipoLavoratore.allCases.map { t in (Optional(t), t.nome) }
        return [(nil, "Non indicato")] + tipi
    }

    /// Il tipo di lavoratore precompila l'aliquota di legge, finché il consulente non ne scrive una sua.
    private var tipo: Binding<TipoLavoratore?> {
        Binding(
            get: { lavoro?.tipo },
            set: { nuovo in
                var l = lavoro ?? DatiLavoro()
                let precedente: Double? = l.tipo?.aliquotaPredefinita
                if l.aliquotaContributiva == nil || l.aliquotaContributiva == precedente {
                    l.aliquotaContributiva = nuovo?.aliquotaPredefinita
                }
                l.tipo = nuovo
                lavoro = l == DatiLavoro() ? nil : l
            }
        )
    }

    private var notaAliquota: String {
        guard let t = lavoro?.tipo else { return "% del reddito lordo" }
        guard let a = t.aliquotaPredefinita else { return "% del reddito lordo · le casse hanno regole proprie: indicala tu" }
        return "% del reddito lordo · di legge \(Formati.percentuale(a))"
    }

    /// La stima che esce dai dati (o il motivo per cui non si può fare), in una riga e una nota.
    private var stima: (valore: String?, nota: String) {
        if let motivo = MotorePensionePubblica.motivoAssente(lavoro, reddito: redditoRipiego) { return (nil, motivo) }
        guard let l = lavoro, let eta = MotorePensionePubblica.etaAl(nascita, Date()) else {
            return (nil, "Serve la data di nascita per stimare la pensione.")
        }
        guard let s = MotorePensionePubblica.stima(lavoro: l, eta: eta, etaPensione: l.etaPensione ?? RegolePensione.etaVecchiaia,
                                                   reddito: redditoRipiego) else {
            return (nil, "Con questi dati la stima non si può fare.")
        }
        var nota = "Stima con il metodo contributivo, in euro di oggi su 13 mensilità: non sostituisce l'estratto conto INPS."
        if !s.requisitoRaggiunto { nota += " Con questi anni di contributi i requisiti non sono ancora raggiunti." }
        if s.sistemaMisto { nota += " Contributi prima del 1996: sistema misto, cifra solo indicativa." }
        return ("circa \(Formati.euro(s.nettaMensile)) netti al mese a \(s.etaPensione) anni", nota)
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

    /// Quanti dati per l'analisi sono indicati (reddito netto e lavoro).
    private var datiAnalisi: Int {
        (bozza.profilo.redditoNettoAnnuo == nil ? 0 : 1) + (bozza.profilo.lavoro?.datiIndicati ?? 0)
    }

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
                        MenuTendina(selezione: $bozza.statoCivile,
                                    opzioni: [(StatoCivile?.none, "Non indicato")] + StatoCivile.allCases.map { (Optional($0), $0.nome) },
                                    larghezza: 220)
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
                        MenuTendina(selezione: $bozza.profilo.propensione,
                                    opzioni: [(ProfiloInvestitore.Propensione?.none, "Non indicata")]
                                        + ProfiloInvestitore.Propensione.allCases.map { (Optional($0), $0.nome) },
                                    larghezza: 220)
                    }
                    CampoModulo(etichetta: "Orizzonte (anni)") {
                        TextField("", value: $bozza.profilo.orizzonteAnni, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    CampoModulo(etichetta: "Reddito lordo annuo") {
                        HStack(spacing: 6) {
                            TextField("—", value: $bozza.profilo.redditoLordoAnnuo, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                            Text("€ · per l'aliquota IRPEF e la deducibilità").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
                        }
                    }
                    CampoModulo(etichetta: "Esperienza finanziaria") {
                        MenuTendina(selezione: $bozza.profilo.esperienza,
                                    opzioni: [(ProfiloInvestitore.Esperienza?.none, "Non indicata")]
                                        + ProfiloInvestitore.Esperienza.allCases.map { (Optional($0), $0.nome) },
                                    larghezza: 220)
                    }
                    CampoModulo(etichetta: "Obiettivi principali") {
                        TextField("", text: $bozza.profilo.obiettivi).textFieldStyle(.roundedBorder)
                    }
                }
                SezioneRipiegabile("Dati per l'analisi · reddito, lavoro e pensione", nota: DatiPerAnalisi.nota(datiAnalisi)) {
                    Text("Facoltativi: servono alla pensione pubblica stimata e alla protezione di ogni persona della famiglia. Lascia vuoto quello che non sai.")
                        .font(Tema.Testo.Inserimento.nota).foregroundColor(Tema.Colore.Inserimento.nota)
                        .fixedSize(horizontal: false, vertical: true)
                    CampoModulo(etichetta: "Reddito netto in famiglia") {
                        CampoCifraFacoltativa(valore: $bozza.profilo.redditoNettoAnnuo,
                                              unita: "€ netti l'anno · se vuoto si stima dal lordo",
                                              larghezza: Tema.Misura.Inserimento.campoEuro)
                    }
                    GruppoCampi(titolo: "Lavoro e contributi",
                                spiegazione: "Per stimare la pensione pubblica con il metodo contributivo. Il montante dell'estratto conto INPS rende la stima più precisa degli anni di contributi.")
                    CampiLavoro(lavoro: $bozza.profilo.lavoro,
                                nascita: bozza.dataNascita,
                                redditoRipiego: bozza.profilo.redditoLordoAnnuo,
                                notaReddito: "€ lordi l'anno · se vuoto, il reddito lordo del profilo",
                                notaEtaPensione: "anni · se vuota, quella dell'Analisi 360")
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

    /// Quanti dati per l'analisi sono indicati.
    private var datiAnalisi: Int {
        let f = modifica.familiare
        return DatiPerAnalisi.conta([f.redditoNettoAnnuo != nil, f.nonAutosufficiente != nil, f.etaFineCarico != nil])
            + (f.lavoro?.datiIndicati ?? 0)
    }

    var body: some View {
        CorniceModulo(titolo: modifica.nuovo ? "Aggiungi un familiare" : "Modifica il familiare") {
            VStack(alignment: .leading, spacing: 12) {
                CampoModulo(etichetta: "Nome e cognome") {
                    TextField("", text: $modifica.familiare.nome).textFieldStyle(.roundedBorder)
                }
                CampoModulo(etichetta: "Relazione") {
                    MenuTendina(selezione: $modifica.familiare.relazione,
                                opzioni: Familiare.Relazione.allCases.map { ($0, $0.nome) }, larghezza: 220)
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
                SezioneRipiegabile("Dati per l'analisi · reddito, sostegno e pensione", nota: DatiPerAnalisi.nota(datiAnalisi)) {
                    Text("Facoltativi: servono alla protezione per persona (chi porta reddito, chi va sostenuto e fino a quando) e alla pensione stimata.")
                        .font(Tema.Testo.Inserimento.nota).foregroundColor(Tema.Colore.Inserimento.nota)
                        .fixedSize(horizontal: false, vertical: true)
                    CampoModulo(etichetta: "Reddito netto in famiglia") {
                        CampoCifraFacoltativa(valore: $modifica.familiare.redditoNettoAnnuo,
                                              unita: "€ netti l'anno · vuoto = nessun reddito",
                                              larghezza: Tema.Misura.Inserimento.campoEuro)
                    }
                    CampoModulo(etichetta: "Non autosufficiente") {
                        Toggle("Non autosufficiente o con disabilità: il sostegno serve per tutta la vita",
                               isOn: Binding(get: { modifica.familiare.nonAutosufficiente == true },
                                             set: { modifica.familiare.nonAutosufficiente = $0 ? true : nil }))
                            .toggleStyle(.checkbox)
                    }
                    CampoModulo(etichetta: "A carico fino a") {
                        CampoInteroFacoltativo(valore: $modifica.familiare.etaFineCarico, unita: "anni · se vuoto, 25 per i figli")
                    }
                    GruppoCampi(titolo: "Lavoro e contributi",
                                spiegazione: "Per stimare la sua pensione pubblica con il metodo contributivo (serve la data di nascita).")
                    CampiLavoro(lavoro: $modifica.familiare.lavoro,
                                nascita: modifica.familiare.dataNascita)
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
        .frame(width: Misure.Rubrica.modulo.width, height: Tema.Misura.Inserimento.moduloFamiliare)
    }
}
