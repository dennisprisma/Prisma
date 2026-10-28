import SwiftUI

/// La composizione di una multiramo (o di una unit linked), nel modulo della posizione e in quello della
/// scheda prodotto: la quota in gestione separata con il cursore e la barra a due colori, poi due colonne
/// affiancate con i dati della gestione separata e dei fondi, il ribilanciamento e una nota.
/// Ogni campo vuoto vale «non indicato»: Prisma lo ricava o lo stima, e lo dichiara.
/// Per la unit linked pura (`conGestione == false`) c'è solo la colonna dei fondi, legata dal chiamante ai
/// campi di sempre della posizione (rendimento atteso, costo annuo, SRI, volatilità, azioni, titoli di Stato).
struct SezioneComposizione: View {
    /// Quota in gestione separata (`quotaGestioneSeparata`, 0–100).
    @Binding var quotaGestione: Double?
    @Binding var rendimentoGestione: Double?
    @Binding var trattenuto: Double?
    @Binding var retrocessione: Double?
    @Binding var minimoGarantito: Double?
    @Binding var consolidamento: Bool?
    @Binding var titoliStatoGestione: Double?
    @Binding var rendimentoFondi: Double?
    @Binding var costoFondi: Double?
    @Binding var sriFondi: Int?
    @Binding var volatilitaFondi: Double?
    @Binding var quotaAzionariaFondi: Double?
    @Binding var titoliStatoFondi: Double?
    @Binding var ribilanciamento: Bool?
    /// false per la unit linked pura: solo la colonna dei fondi.
    var conGestione: Bool
    /// Quota in gestione separata ammessa dalla scheda (0–100): fuori, un avviso (non un blocco).
    var limiti: ClosedRange<Double>? = nil
    /// Valore del contratto, per mostrare gli euro delle due parti.
    var valoreTotale: Double? = nil
    /// «1,70% l'anno su un lordo ipotizzato del 3,00%»: lo calcola il chiamante.
    var accreditato: String? = nil
    /// Nota sotto il cursore della quota (per esempio: posizione in essere senza la quota dell'estratto conto).
    var notaQuota: String? = nil

    private typealias M = Tema.Misura.Multiramo
    private typealias C = Tema.Colore.Multiramo

    /// La quota mostrata (0–100): quella indicata o la stima del 50%.
    private var quotaMostrata: Double {
        min(max(quotaGestione ?? Posizione.quotaGestionePredefinita, 0), 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: M.spazioRighe) {
            if conGestione { rigaQuota }
            // Due colonne affiancate; se non c'è posto per due colonne minime, una sopra l'altra
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: M.spazioColonne) {
                    if conGestione { colonna(colonnaGestione) }
                    colonna(colonnaFondi)
                }
                VStack(alignment: .leading, spacing: M.spazioColonne) {
                    if conGestione { colonnaGestione.modifier(FondoColonna()) }
                    colonnaFondi.modifier(FondoColonna())
                }
            }
            if conGestione { rigaRibilanciamento }
            Text(conGestione
                 ? "Campi vuoti: il rendimento mancante si ricava da quello complessivo, i costi dei fondi dal costo annuo. Basta un dato separato perché Prisma calcoli le due parti a sé."
                 : "Per una unit linked i dati dei fondi sono quelli del contratto: rendimento lordo prima dei costi, costi della compagnia e degli OICR, rischio dal KID.")
                .font(Tema.Testo.Multiramo.nota)
                .foregroundColor(C.nota)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Una colonna nella disposizione affiancata: larga almeno il minimo, poi metà dello spazio.
    private func colonna<V: View>(_ contenuto: V) -> some View {
        contenuto
            .modifier(FondoColonna())
            .frame(minWidth: M.colonnaMinima, idealWidth: M.colonnaMinima, maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Quota

    private var rigaQuota: some View {
        let cursore = Binding<Double>(
            get: { quotaMostrata },
            set: { quotaGestione = min(max(($0 / M.passoCursore).rounded() * M.passoCursore, 0), 100) }
        )
        return VStack(alignment: .leading, spacing: M.spazioBarra) {
            HStack(alignment: .center, spacing: M.spazioRiga) {
                Text("Gestione separata")
                    .font(Tipo.campoEtichetta)
                    .foregroundColor(C.etichetta)
                Slider(value: cursore, in: 0...100, step: M.passoCursore)
                    .frame(width: M.larghezzaCursore)
                CampoCifraFacoltativa(valore: $quotaGestione, unita: "%")
                if quotaGestione == nil {
                    Text("stimata")
                        .font(Tema.Testo.Multiramo.nota)
                        .foregroundColor(C.avviso)
                }
                Spacer(minLength: 0)
            }
            Text(riepilogoQuote)
                .font(Tema.Testo.Multiramo.quota)
                .foregroundColor(C.testoBarra)
            BarraComposizione(gestione: quotaMostrata / 100, conEtichette: false)
            if let avviso = avvisoLimiti {
                Text(avviso)
                    .font(Tema.Testo.Multiramo.nota)
                    .foregroundColor(C.avviso)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let notaQuota {
                Text(notaQuota)
                    .font(Tema.Testo.Multiramo.nota)
                    .foregroundColor(C.avviso)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// «40% gestione separata · 60% fondi», con gli euro delle due parti se c'è il valore.
    private var riepilogoQuote: String {
        let q = quotaMostrata
        let euro: (Double) -> String = { quota in
            guard let v = valoreTotale, v > 0 else { return "" }
            return " (\(Formati.euro(v * quota / 100)))"
        }
        return "\(Formati.percentuale(q)) gestione separata\(euro(q)) · \(Formati.percentuale(100 - q)) fondi\(euro(100 - q))"
    }

    /// Fuori dai limiti del contratto: «Il contratto ammette dal 30% al 70% in gestione separata».
    private var avvisoLimiti: String? {
        guard let l = limiti, !l.contains(quotaMostrata) else { return nil }
        if l.lowerBound == l.upperBound {
            return "Il contratto prevede il \(Formati.percentuale(l.lowerBound)) in gestione separata"
        }
        return "Il contratto ammette dal \(Formati.percentuale(l.lowerBound)) al \(Formati.percentuale(l.upperBound)) in gestione separata"
    }

    // MARK: - Colonne

    private var colonnaGestione: some View {
        VStack(alignment: .leading, spacing: M.spazioCampi) {
            testata(C.gestione, "Gestione separata", Formati.percentuale(quotaMostrata))
            campo("Rendimento lordo") {
                CampoCifraFacoltativa(valore: $rendimentoGestione, unita: "% annuo, prima del trattenuto")
            }
            campo("Trattenuto") {
                CampoCifraFacoltativa(valore: $trattenuto, unita: "punti l'anno")
            }
            campo("Retrocessione") {
                CampoCifraFacoltativa(valore: $retrocessione, unita: "% del lordo, al posto del trattenuto")
            }
            campo("Minimo garantito") {
                CampoCifraFacoltativa(valore: $minimoGarantito, unita: "% l'anno · 0 = solo il capitale")
            }
            campo("Consolidamento") {
                MenuTendina(selezione: $consolidamento,
                            opzioni: [(Bool?.none, "Non indicato · si considera annuo"),
                                      (Optional(true), "Annuo: l'accreditato non si perde"),
                                      (Optional(false), "Solo a scadenza o al decesso")])
            }
            campo("Titoli di Stato") {
                CampoCifraFacoltativa(valore: $titoliStatoGestione, unita: "% della gestione, al 12,5%")
            }
            if let accreditato {
                campo("Accreditato stimato") {
                    Text(accreditato)
                        .font(Tema.Testo.Multiramo.nota)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var colonnaFondi: some View {
        VStack(alignment: .leading, spacing: M.spazioCampi) {
            testata(C.fondi, "Fondi (Ramo III)", conGestione ? Formati.percentuale(100 - quotaMostrata) : nil)
            campo("Rendimento lordo") {
                CampoCifraFacoltativa(valore: $rendimentoFondi, unita: "% annuo, prima dei costi")
            }
            campo("Costi dei fondi") {
                CampoCifraFacoltativa(valore: $costoFondi, unita: "% l'anno: commissione della compagnia e OICR")
            }
            campo(conGestione ? "SRI dei fondi" : "Rischio (SRI)") {
                MenuTendina(selezione: $sriFondi,
                            opzioni: [(Int?.none, "Non indicato")] + (1...7).map { (Optional($0), "\($0)") },
                            larghezza: M.tendinaSRI)
            }
            campo("Volatilità") {
                CampoCifraFacoltativa(valore: $volatilitaFondi, unita: "% l'anno (deviazione standard)")
            }
            campo("Quota azionaria") {
                CampoCifraFacoltativa(valore: $quotaAzionariaFondi, unita: "% dei fondi")
            }
            campo("Titoli di Stato") {
                CampoCifraFacoltativa(valore: $titoliStatoFondi, unita: "% dei fondi, al 12,5%")
            }
        }
    }

    private func testata(_ colore: Color, _ nome: String, _ quota: String?) -> some View {
        HStack(alignment: .center, spacing: M.spazioRiga) {
            PallinoParte(colore: colore, testo: nome)
            Spacer(minLength: M.spazioRiga)
            if let quota {
                Text(quota)
                    .font(Tema.Testo.Multiramo.quota)
                    .foregroundColor(C.testoBarra)
            }
        }
    }

    /// Un campo della colonna: l'etichetta sopra, il controllo sotto (le colonne sono strette).
    private func campo<V: View>(_ etichetta: String, @ViewBuilder _ controllo: () -> V) -> some View {
        VStack(alignment: .leading, spacing: M.spazioEtichetta) {
            Text(etichetta)
                .font(Tipo.campoEtichetta)
                .foregroundColor(C.etichetta)
            controllo()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ribilanciamento

    private var rigaRibilanciamento: some View {
        let scelta = Binding<Bool>(
            get: { ribilanciamento == true },
            // «Nessuno» lascia nil se non era indicato: nil e false dicono la stessa cosa
            set: { annuo in ribilanciamento = annuo ? true : (ribilanciamento == nil ? nil : false) }
        )
        return HStack(alignment: .center, spacing: M.spazioRiga) {
            Text("Ribilanciamento")
                .font(Tipo.campoEtichetta)
                .foregroundColor(C.etichetta)
            MenuTendina(selezione: scelta,
                        opzioni: [(false, "Nessuno: le parti vanno per conto loro"),
                                  (true, "Annuo alla quota scelta (se il contratto lo prevede)")],
                        larghezza: M.tendinaRibilanciamento)
            Spacer(minLength: 0)
        }
    }
}

/// Fondo di una colonna della composizione: il pozzetto dei campi, con il filo, arrotondato come le sezioni.
private struct FondoColonna: ViewModifier {
    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: Tema.Raggio.Inserimento.sezione, style: .continuous)
        return content
            .padding(Tema.Misura.Multiramo.margineColonna)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(forma.fill(Tema.Colore.Multiramo.fondoColonna))
            .overlay(forma.strokeBorder(Tema.Colore.Multiramo.bordoColonna, lineWidth: Tema.Misura.filo))
    }
}
