#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

// MARK: - Componenti dell'app Documenti (giro 5)
// Non sono i componenti dei fogli stampati (quelli stanno in ComponentiDocumenti.swift): qui ci sono l'elenco stile
// Finder, la fonte di un dato, i banner, il menu delle azioni, il vuoto iniziale e il rilascio dei file.

/// Il tipo del documento in un quadrato arrotondato (elenco e barra del dettaglio).
struct TesseraDocumento: View {
    let categoria: CategoriaDocumento
    var grande = false

    var body: some View {
        let lato = grande ? Tema.Misura.Documenti.tesseraGrande : Tema.Misura.Documenti.tessera
        Image(systemName: categoria.simbolo)
            .font(grande ? Tema.Testo.Documenti.simboloTesseraGrande : Tema.Testo.Documenti.simboloTessera)
            .foregroundColor(Tema.Colore.Documenti.simbolo)
            .frame(width: lato, height: lato)
            .background { FormaVetro.arrotondata(Tema.Raggio.Documenti.tessera).fill(Tema.Colore.Documenti.tessera) }
    }
}

/// Il titolo di un gruppo dell'elenco (come le sezioni della barra laterale) con il conteggio.
struct TestataGruppoDocumenti: View {
    let titolo: String
    let conteggio: Int

    var body: some View {
        HStack(spacing: Tema.Misura.Documenti.spazioStatoRiga) {
            Text(titolo)
                .font(Tema.Testo.occhiello)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
                .lineLimit(1)
            Spacer(minLength: Tema.Misura.Documenti.spazioStatoRiga)
            Text("\(conteggio)")
                .font(Tema.Testo.chipPiccolo)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
        }
        .padding(Tema.Misura.Documenti.testataGruppo)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Una riga dell'elenco dei documenti: tessera, titolo con il segno «da leggere», pagine e data, stato e collegamento.
struct RigaDocumento: View {
    let voce: MotoreDocumenti.Voce
    /// «p. 3 · …» quando la ricerca ha trovato le parole solo nel testo del documento.
    var nelTesto: String? = nil
    let attiva: Bool
    let daLeggere: Bool

    var body: some View {
        let m = Tema.Misura.Documenti.self
        let d = voce.documento
        HStack(alignment: .top, spacing: m.spazioRiga) {
            TesseraDocumento(categoria: d.genere)
            VStack(alignment: .leading, spacing: m.spazioTestiRiga) {
                // Il titolo va su due righe e si tronca in coda, non a metà
                HStack(alignment: .firstTextBaseline, spacing: m.spazioStatoRiga) {
                    if daLeggere {
                        Circle()
                            .strokeBorder(Tema.Colore.Documenti.nuovo, lineWidth: m.bordoNuovo)
                            .frame(width: m.puntoNuovo, height: m.puntoNuovo)
                            .help("Da leggere")
                    }
                    Text(d.titolo)
                        .font(Tema.Testo.titolo)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(Self.meta(d))
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                statoECollegamento
                if let nelTesto {
                    Text(nelTesto)
                        .font(Tema.Testo.didascalia)
                        .foregroundColor(Tema.Colore.inchiostroTerziario)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(m.rigaElenco)
        .voceElencoStrumento(attiva: attiva)
    }

    /// La terza riga, solo se serve: lo stato che chiede attenzione e il collegamento con il canale. Se il nome
    /// collegato non entra resta l'icona del collegamento, con il nome nell'aiuto.
    @ViewBuilder private var statoECollegamento: some View {
        let stato = voce.indicatori.stato
        let mostraStato: Bool = {
            switch stato {
            case .inLettura, .illeggibile, .conDifferenze: return true
            default: return false
            }
        }()
        if mostraStato || voce.nomeCollegato != nil {
            ViewThatFits(in: .horizontal) {
                rigaStato(stato, conNome: true)
                rigaStato(stato, conNome: false)
            }
        }
    }

    private func rigaStato(_ stato: MotoreDocumenti.Stato, conNome: Bool) -> some View {
        HStack(spacing: Tema.Misura.Documenti.spazioStatoRiga) {
            switch stato {
            case .inLettura:
                ProgressView().controlSize(.mini)
                Text(stato.etichetta)
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
            case .conDifferenze:
                Pillola(testo: stato.etichetta, tono: .attenzione)
            case .illeggibile:
                Pillola(testo: stato.etichetta, tono: .errore)
            default:
                EmptyView()
            }
            if let nome = voce.nomeCollegato {
                Image(systemName: "link")
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
                    .help(nome)
                if conNome {
                    Text(nome)
                        .font(Tema.Testo.didascalia)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .lineLimit(1)
                }
                if let canale = voce.canale {
                    EtichettaCanale(canale: canale, compatta: true)
                }
            }
        }
    }

    /// «3 pagine · 1 ott» (con l'anno se non è quello in corso) e « · scansione» se letto dalle immagini.
    static func meta(_ d: Documento, oggi: Date = Date()) -> String {
        let cal = Calendar.current
        var parti: [String] = []
        if d.pagine > 0 { parti.append("\(d.pagine) \(d.pagine == 1 ? "pagina" : "pagine")") }
        var data = Formati.giornoMeseBreve.string(from: d.importatoIl)
        if !cal.isDate(d.importatoIl, equalTo: oggi, toGranularity: .year) { data += " \(cal.component(.year, from: d.importatoIl))" }
        parti.append(data)
        if d.pagineOCR > 0 { parti.append("scansione") }
        return parti.joined(separator: " · ")
    }
}

/// La fonte di un dato: «p. 2» (o «p. 2 · Qwen», «a mano»). Un clic porta l'anteprima a quella pagina e ne
/// illumina la riga.
struct FonteDato: View {
    let campo: CampoEstratto
    let azione: () -> Void

    private var testo: String {
        guard campo.pagina > 0 else { return "a mano" }
        return campo.origine.contains("Qwen") ? "p. \(campo.pagina) · Qwen" : "p. \(campo.pagina)"
    }

    var body: some View {
        Button(action: azione) {
            Text(testo)
                .font(Tema.Testo.pill)
                .foregroundColor(campo.pagina > 0 ? Colori.Colonna.collegamento : Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
                .padding(Tema.Misura.Documenti.fonte)
                .background { FormaVetro.capsula.fill(Tema.Colore.pozzetto) }
                .fixedSize()
        }
        .buttonStyle(StileSemplice())
        .disabled(campo.pagina <= 0)
        .help(campo.estratto.isEmpty ? "Scritto a mano" : "«\(campo.estratto)»")
    }
}

/// Il banner in cima alla scheda dei dati: una frase e, se serve, il pulsante che risolve.
struct BannerDocumento: View {
    enum Tono { case informazione, attenzione, errore }

    let tono: Tono
    let simbolo: String
    let testo: String
    var pulsante: String? = nil
    var attivo = true
    var azione: () -> Void = {}

    private var colori: (fondo: Color, simbolo: Color) {
        let c = Tema.Colore.Documenti.self
        switch tono {
        case .informazione: return (c.fondoBanner, c.simboloBanner)
        case .attenzione: return (c.fondoBannerAttenzione, c.simboloBannerAttenzione)
        case .errore: return (c.fondoBannerErrore, c.simboloBannerErrore)
        }
    }

    var body: some View {
        let m = Tema.Misura.Documenti.self
        HStack(alignment: .center, spacing: m.spazioBanner) {
            Image(systemName: simbolo)
                .font(Tema.Testo.Documenti.simboloBanner)
                .foregroundColor(colori.simbolo)
            Text(testo)
                .font(Tema.Testo.corpo)
                .foregroundColor(Tema.Colore.inchiostro)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: m.spazioStatoRiga)
            if let pulsante {
                Button(pulsante, action: azione)
                    .buttonStyle(StileVetro(margine: m.pulsante))
                    .disabled(!attivo)
                    .fixedSize()
            }
        }
        .padding(m.banner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FormaVetro.arrotondata(Tema.Raggio.Documenti.banner).fill(colori.fondo) }
    }
}

// MARK: - Menu delle azioni

/// Una voce del menu delle azioni: un'azione (spuntata o no, attiva o no), un titolo di sezione o un separatore.
struct VoceMenuAzioni {
    enum Genere {
        case azione(() -> Void)
        case titolo
        case separatore
    }

    let titolo: String
    var spuntata = false
    var attiva = true
    let genere: Genere

    static func azione(_ titolo: String, spuntata: Bool = false, attiva: Bool = true,
                       _ fai: @escaping () -> Void) -> VoceMenuAzioni {
        VoceMenuAzioni(titolo: titolo, spuntata: spuntata, attiva: attiva, genere: .azione(fai))
    }

    static func sezione(_ titolo: String) -> VoceMenuAzioni {
        VoceMenuAzioni(titolo: titolo, attiva: false, genere: .titolo)
    }

    static var separatore: VoceMenuAzioni { VoceMenuAzioni(titolo: "", genere: .separatore) }
}

/// Un pulsante di vetro che apre il menu del Mac con azioni, titoli di sezione disattivi e separatori (come
/// `MenuTendina`, ma per comandi). Le voci si calcolano al clic: sono sempre quelle di adesso.
struct MenuAzioni<Etichetta: View>: View {
    let voci: () -> [VoceMenuAzioni]
    var margine: EdgeInsets = Tema.Misura.Documenti.pulsante
    /// Compatta (28 pt) nelle righe; `.normale` (32 pt) nelle barre accanto agli altri pulsanti.
    var taglia: TagliaPulsante = .compatta
    @ViewBuilder let etichetta: () -> Etichetta

    var body: some View {
        #if os(macOS)
        Button(action: apri) {
            etichetta()
        }
        .buttonStyle(StileVetro(margine: margine, taglia: taglia))
        #elseif os(iOS)
        // Su iPhone e iPad un `Menu` di sistema con le stesse voci: titoli disattivi, separatori e spunte
        Menu {
            let elenco = voci()
            ForEach(Array(elenco.enumerated()), id: \.offset) { voce in
                vocePerMenu(voce.element)
            }
        } label: {
            etichetta()
        }
        .menuStyle(.button)
        .buttonStyle(StileVetro(margine: margine, taglia: taglia))
        #endif
    }

    #if os(iOS)
    /// Una voce del `Menu` di iPhone e iPad.
    @ViewBuilder private func vocePerMenu(_ v: VoceMenuAzioni) -> some View {
        switch v.genere {
        case .separatore:
            Divider()
        case .titolo:
            Text(verbatim: v.titolo)
        case .azione(let fai):
            Button(action: fai) {
                if v.spuntata {
                    Label(v.titolo, systemImage: "checkmark")
                } else {
                    Text(verbatim: v.titolo)
                }
            }
            .disabled(!v.attiva)
        }
    }
    #endif

    #if os(macOS)
    /// Il menu del Mac: modale finché non si sceglie, quindi il bersaglio delle voci vive abbastanza.
    private func apri() {
        let elenco = voci()
        let menu = NSMenu()
        menu.autoenablesItems = false
        let bersaglio = BersaglioMenuAzioni { i in
            guard i >= 0, i < elenco.count, case .azione(let fai) = elenco[i].genere else { return }
            fai()
        }
        for (i, v) in elenco.enumerated() {
            switch v.genere {
            case .separatore:
                menu.addItem(NSMenuItem.separator())
            case .titolo:
                let voce = NSMenuItem(title: v.titolo, action: nil, keyEquivalent: "")
                voce.isEnabled = false
                menu.addItem(voce)
            case .azione:
                let voce = NSMenuItem(title: v.titolo, action: #selector(BersaglioMenuAzioni.scegli(_:)), keyEquivalent: "")
                voce.target = bersaglio
                voce.tag = i
                voce.state = v.spuntata ? .on : .off
                voce.isEnabled = v.attiva
                menu.addItem(voce)
            }
        }
        _ = withExtendedLifetime(bersaglio) {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }
    #endif
}

#if os(macOS)
private final class BersaglioMenuAzioni: NSObject {
    let scelto: (Int) -> Void
    init(_ scelto: @escaping (Int) -> Void) { self.scelto = scelto }
    @objc func scegli(_ voce: NSMenuItem) { scelto(voce.tag) }
}
#endif

// MARK: - Vuoto iniziale e rilascio

/// Il cliente non ha documenti: che cosa fare, in tre passi, e il pulsante per sceglierli dal Mac.
struct VuotoDocumenti: View {
    let nome: String
    let importa: () -> Void

    var body: some View {
        let m = Tema.Misura.Documenti.self
        VStack(spacing: m.spazioVuoto) {
            Image(systemName: "tray.and.arrow.down")
                .font(Tema.Testo.Strumenti.iconaRilascio)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
            Text("Nessun documento di \(nome)")
                .font(Tema.Testo.sezione)
                .foregroundColor(Tema.Colore.inchiostro)
                .multilineTextAlignment(.center)
            Text("Trascina qui i documenti del cliente, o sceglili dal Mac. Prisma li legge sul Mac, trova i dati con la pagina da cui vengono e ti dice cosa non torna con il dossier.")
                .font(Tema.Testo.corpo)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: m.spazioRiga) {
                passo(1, "Aggiungi", "KID, polizze, estratti conto, documenti d'identità, questionari. PDF, foto o scansioni.")
                passo(2, "Leggi", "Prisma legge il testo, anche delle scansioni, e scrive accanto a ogni cifra la sua pagina.")
                passo(3, "Collega", "Colleghi il documento a una posizione o a una scheda: Prisma confronta e ti mostra le differenze.")
            }
            .fixedSize(horizontal: false, vertical: true)
            Button(action: importa) {
                Label("Scegli i file…", systemImage: "doc.badge.plus")
            }
            .buttonStyle(StileBlu(taglia: .grande))
            Text("I file vengono copiati nell'archivio di Prisma su questo Mac e finiscono nei backup. Nessun file lascia il computer.")
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: m.vuotoLarghezza)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func passo(_ numero: Int, _ titolo: String, _ testo: String) -> some View {
        let m = Tema.Misura.Documenti.self
        return VStack(alignment: .leading, spacing: m.spazioStatoRiga) {
            HStack(spacing: m.spazioBarra) {
                Text("\(numero)")
                    .font(Tema.Testo.Documenti.numeroPasso)
                    .foregroundColor(Tema.Colore.Documenti.testoPasso)
                    .frame(width: m.cerchioPasso, height: m.cerchioPasso)
                    .background { Circle().fill(Tema.Colore.Documenti.passo) }
                Text(titolo)
                    .font(Tema.Testo.titolo)
                    .foregroundColor(Tema.Colore.inchiostro)
            }
            Text(testo)
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(m.marginePasso)
        .frame(width: m.passoVuoto, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .riquadroStrumento()
    }
}

/// I file trascinati sopra i Documenti: la cornice tratteggiata e, al centro, la capsula con il nome del cliente.
struct RilascioDocumenti: View {
    let nome: String

    var body: some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.Strumenti.rilascio)
        ZStack {
            forma
                .strokeBorder(Tema.Colore.accento,
                              style: StrokeStyle(lineWidth: Tema.Misura.Strumenti.bordoRilascio, dash: Tema.Misura.Strumenti.trattiRilascio))
                .background { forma.fill(Tema.Colore.Strumenti.rilascio) }
            HStack(spacing: Tema.Misura.Documenti.spazioBarra) {
                Image(systemName: "plus.circle.fill")
                    .font(Tema.Testo.Documenti.simboloBanner)
                    .foregroundColor(Tema.Colore.accento)
                Text("Rilascia per aggiungere ai documenti di \(nome)")
                    .font(Tema.Testo.titolo)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineLimit(1)
            }
            .padding(Tema.Misura.Documenti.capsulaRilascio)
            .vetro(.chip, forma: .capsula)
        }
        .allowsHitTesting(false)
    }
}
