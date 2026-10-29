import SwiftUI

private typealias D = Misure.Documento

// Le «ipotesi stimate» nei documenti (completezza dei dati): quali dati mancano, sono stimati o vecchi e
// che cosa usano le cifre al loro posto. Una pagina nel prospetto per il consulente (previdenza, protezione,
// check-up) e una slide nel report per il cliente, con il tu. Su carta: colori opachi e fissi della tavolozza
// dei documenti, niente vetro; il canale di ogni posizione resta sempre indicato.
// Le voci arrivano già scelte e ordinate da `CompletezzaCliente.ipotesi(per:)`.

/// I testi delle «ipotesi stimate» nei documenti (le stesse frasi le cerca `ProvaProspettiCompletezza`).
enum TestiIpotesiStimate {
    static let titoloProspetto = "Dati mancanti e ipotesi stimate"
    static let occhielloReport = "Prima di decidere"
    static let titoloReport = "Le ipotesi da confermare insieme"
    static let sottotitoloReport = "Alcune cifre si basano su stime: con questi dati diventano più precise."
    static let colonnaDato = "Dato"
    static let colonnaStato = "Stato"
    static let colonnaIpotesi = "Ipotesi usata"
    static let colonnaCanale = "Canale"
    /// Cella senza valore (le voci del cliente non hanno un canale).
    static let vuoto = "—"

    /// "Completezza dei dati per l'analisi: 77%. Le cifre di questo prospetto usano…"; senza percentuale solo la seconda frase.
    static func introduzione(_ percentuale: Int?) -> String {
        let cifre = "Le cifre di questo prospetto usano le ipotesi qui sotto al posto dei dati che mancano."
        guard let p = percentuale else { return cifre }
        return "Completezza dei dati per l'analisi: \(p)%. " + cifre
    }

    /// "…e altre 3" (prospetto) o "…e altre 3, nel prospetto di dettaglio." (report).
    static func altre(_ n: Int, report: Bool) -> String {
        report ? "…e altre \(n), nel prospetto di dettaglio." : "…e altre \(n)"
    }

    /// Il titolo di una voce diviso in dato e posizione: "Costi del KID · Piano Alfa" → ("Costi del KID", "Piano Alfa").
    /// Le voci del cliente restano intere.
    static func parti(_ v: VoceCompletezza) -> (dato: String, posizione: String) {
        guard v.posizioneId != nil, let r = v.titolo.range(of: " · ") else { return (v.titolo, "") }
        return (String(v.titolo[..<r.lowerBound]), String(v.titolo[r.upperBound...]))
    }
}

extension PaletteDocumento {
    /// Lo stato di un dato su carta: manca in rosso, da aggiornare in ocra, stimato in blu.
    fileprivate func statoDato(_ s: StatoDato) -> Color {
        switch s {
        case .mancante: return negativo
        case .daAggiornare: return fondoInterno
        case .stimato: return intermedio
        case .completo: return positivo
        }
    }
}

// MARK: - Prospetto (A4 verticale, per il consulente)

/// Il corpo di una pagina del prospetto, dentro `FoglioProspetto`: la tabella dei dati da completare
/// (dato, stato, ipotesi usata, canale) e il metodo del punteggio.
struct PaginaIpotesiStimate: View {
    private typealias T = Tipo.Documento
    @Environment(\.paletteDocumento) private var C
    let voci: [VoceCompletezza]
    /// La completezza dei dati del cliente (0–100); nil se non è indicata.
    let percentuale: Int?

    var body: some View {
        let mostrate = Array(voci.prefix(MotoreCompletezza.massimoProspetto))
        let altre = voci.count - mostrate.count
        return VStack(alignment: .leading, spacing: D.spazio) {
            SezioneProspetto(titolo: TestiIpotesiStimate.titoloProspetto,
                             testo: Text(verbatim: TestiIpotesiStimate.introduzione(percentuale)))
            VStack(alignment: .leading, spacing: D.spazio / 2) {
                TabellaDoc(larghezza: FoglioProspetto<EmptyView>.larghezza,
                           colonne: [ColonnaDoc(titolo: TestiIpotesiStimate.colonnaDato, peso: 1.8, destra: false),
                                     ColonnaDoc(titolo: TestiIpotesiStimate.colonnaStato, peso: 0.8, destra: false),
                                     ColonnaDoc(titolo: TestiIpotesiStimate.colonnaIpotesi, peso: 3.2, destra: false),
                                     // Larga quanto l'etichetta compatta dell'indipendente
                                     ColonnaDoc(titolo: TestiIpotesiStimate.colonnaCanale, peso: 1.2, destra: false)],
                           righe: mostrate.map { riga($0) }, fontTesta: T.pTabellaTesta, altezzaTesta: D.rigaTabellaProspetto)
                if altre > 0 {
                    Text(verbatim: TestiIpotesiStimate.altre(altre, report: false)).font(T.pNotaLeggibile).foregroundColor(C.tenue)
                }
            }
            Text(verbatim: TestiCompletezza.metodo).font(T.pNotaLeggibile).foregroundColor(C.tenue)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Una voce: il dato (con la posizione sotto), lo stato nel suo colore, l'ipotesi usata, il canale.
    private func riga(_ v: VoceCompletezza) -> RigaDoc {
        let parti = TestiIpotesiStimate.parti(v)
        var dato = CellaDoc(parti.dato, sotto: parti.posizione, font: T.pTabellaForte)
        dato.fontSotto = T.pNotaLeggibile
        dato.righe = 2
        var ipotesi = CellaDoc(v.ipotesi.isEmpty ? TestiIpotesiStimate.vuoto : v.ipotesi, font: T.pTabella)
        ipotesi.righe = 2
        // Il canale come etichetta compatta da stampa (blu Alleanza, cuoio indipendente), come nelle altre tabelle
        let canale: CellaDoc
        if let c = v.canale {
            var cella = CellaDoc(c.nomeBreve, font: T.pTabellaForte)
            cella.canale = c
            canale = cella
        } else {
            canale = CellaDoc(TestiIpotesiStimate.vuoto, colore: C.tenue, font: T.pTabella)
        }
        return RigaDoc(celle: [dato, CellaDoc(v.stato.nome, colore: C.statoDato(v.stato), font: T.pTabellaForte), ipotesi, canale],
                       altezza: D.rigaTabellaProspetto * 2)
    }
}

// MARK: - Report (A4 orizzontale, per il cliente)

/// La slide del report: le ipotesi da confermare con il cliente, con il tu, su due colonne.
/// Solo le voci con il testo per il cliente (`ipotesiCliente`); quelle di una posizione portano il canale.
struct SlideIpotesiStimate: View {
    private typealias T = Tipo.Report
    @Environment(\.paletteDocumento) private var C
    let voci: [VoceCompletezza]

    /// La slide da mettere prima della sintesi, se c'è almeno un'ipotesi da dire al cliente (altrimenti nessuna).
    nonisolated static func slide(_ ipotesi: [VoceCompletezza]) -> [AnyView] {
        let perCliente = ipotesi.filter { !$0.ipotesiCliente.isEmpty }
        return perCliente.isEmpty ? [] : [AnyView(SlideIpotesiStimate(voci: perCliente))]
    }

    var body: some View {
        let perCliente = voci.filter { !$0.ipotesiCliente.isEmpty }
        let mostrate = Array(perCliente.prefix(MotoreCompletezza.massimoReport))
        let altre = perCliente.count - mostrate.count
        let coppie = stride(from: 0, to: mostrate.count, by: 2).map { Array(mostrate[$0..<min($0 + 2, mostrate.count)]) }
        return VStack(alignment: .leading, spacing: D.spazio) {
            TestaReport(occhiello: TestiIpotesiStimate.occhielloReport, titolo: TestiIpotesiStimate.titoloReport,
                        sottotitolo: TestiIpotesiStimate.sottotitoloReport)
            VStack(spacing: D.spazio) {
                ForEach(Array(coppie.enumerated()), id: \.offset) { _, coppia in
                    HStack(alignment: .top, spacing: D.spazio) {
                        ForEach(Array(coppia.enumerated()), id: \.offset) { _, v in riquadro(v) }
                        if coppia.count < 2 { Color.clear.frame(maxWidth: .infinity) }
                    }
                    // I due riquadri della riga alti uguali
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            if altre > 0 {
                Text(verbatim: TestiIpotesiStimate.altre(altre, report: true)).font(T.piccolo).foregroundColor(C.tenue)
            }
        }
    }

    private func riquadro(_ v: VoceCompletezza) -> some View {
        VStack(alignment: .leading, spacing: D.spazio / 2) {
            HStack(alignment: .firstTextBaseline, spacing: D.spazio) {
                Text(verbatim: v.stato.nome.uppercased()).font(T.occhiello).tracking(D.tracciatoOcchiello)
                    .foregroundColor(C.statoDato(v.stato))
                Spacer(minLength: 0)
                // Il canale della posizione: l'etichetta compatta da stampa
                if let c = v.canale {
                    EtichettaCanale(canale: c, compatta: true)
                }
            }
            Text(verbatim: v.ipotesiCliente).font(T.corpo).foregroundColor(C.testo)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(D.spazio)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .riquadroDoc()
    }
}
