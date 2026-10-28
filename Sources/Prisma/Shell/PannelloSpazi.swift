import SwiftUI

/// Il pannello «Spazi di lavoro»: gli spazi pronti e quelli salvati, con la miniatura della
/// disposizione; in fondo si salvano le finestre aperte come nuovo spazio.
struct PannelloSpazi: View {
    @EnvironmentObject var stato: StatoShell
    /// Le finestre aperte, da salvare come spazio.
    @EnvironmentObject var sistema: StatoFinestre
    @State private var nome = ""

    var body: some View {
        ZStack {
            Colori.Spazi.velo
                .contentShape(Rectangle())
                .onTapGesture { stato.pannelloSpazi = false }
            VStack(spacing: 0) {
                intestazione
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Misure.Spazi.margine) {
                            gruppo("PRONTI", SpazioLavoro.predefiniti)
                            if !stato.dati.spazi.isEmpty { gruppo("I TUOI SPAZI", stato.dati.spazi) }
                        }
                        .padding(Misure.Spazi.margine)
                    }
                    piede
                }
                .clipShape(FormaVetro.arrotondata(Misure.Spazi.raggioInterno))
            }
            .padding(Misure.Spazi.cornice)
            .frame(width: Misure.Spazi.pannello.width, height: Misure.Spazi.pannello.height)
            // Vetro del pannello con riempimento coprente: la finestra dietro non si legge attraverso
            .vetro(.pannello, forma: .arrotondata(Misure.Spazi.raggio), riempimento: Colori.Spazi.fondo)
            // La scheda scende dall'alto, come Mission Control; il velo e il contenitore fanno solo l'opacità
            .entrataScheda(Tema.Moto.Pannelli.spazi, scala: Tema.Moto.Pannelli.spaziScala, ancora: .top)
        }
        .onExitCommand { stato.pannelloSpazi = false }
    }

    private var intestazione: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Spazi di lavoro").font(Tipo.spaziTitolo).foregroundColor(Colori.Spazi.titolo)
                Text("Le app che ti servono, già disposte: si riaprono con un clic.")
                    .font(Tipo.spaziSottotitolo).foregroundColor(Colori.Spazi.sottotitolo)
            }
            Spacer()
            Button("Chiudi") { stato.pannelloSpazi = false }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private func gruppo(_ titolo: String, _ spazi: [SpazioLavoro]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo)
                .font(Tipo.spaziSezione)
                .foregroundColor(Colori.Spazi.sezione)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Misure.Spazi.colonna), spacing: Misure.Spazi.spazioSchede, alignment: .top)],
                      alignment: .leading, spacing: Misure.Spazi.spazioSchede) {
                ForEach(spazi) { scheda($0) }
            }
        }
    }

    private func scheda(_ s: SpazioLavoro) -> some View {
        Button { stato.apriSpazio(s) } label: {
            VStack(alignment: .leading, spacing: 6) {
                MiniaturaSpazio(spazio: s)
                Text(s.nome)
                    .font(Tipo.spaziNome)
                    .foregroundColor(Colori.Spazi.nome)
                    .lineLimit(1)
                Text(s.app.map(\.titolo).joined(separator: " · "))
                    .font(Tipo.spaziApp)
                    .foregroundColor(Colori.Spazi.app)
                    .lineLimit(1)
            }
            .padding(Misure.Spazi.margineScheda)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Scheda del tema (.card), evidenziata al passaggio del mouse
            .fondoPassaggio(.arrotondata(Misure.Spazi.raggioScheda), sopra: Colori.Spazi.schedaSopra)
            .vetro(.sottile, forma: .arrotondata(Misure.Spazi.raggioScheda))
            .contentShape(FormaVetro.arrotondata(Misure.Spazi.raggioScheda))
        }
        .buttonStyle(StileSemplice())
        .help("Apri lo spazio «\(s.nome)»")
        .overlay(alignment: .topTrailing) {
            if !s.predefinito {
                Button { stato.eliminaSpazio(s.id) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Colori.Spazi.elimina)
                }
                .buttonStyle(StileSemplice())
                .help("Elimina lo spazio")
                .padding(4)
            }
        }
    }

    private var piede: some View {
        HStack(spacing: 10) {
            if sistema.visibili.isEmpty {
                Text("Apri e disponi le app che ti servono, poi salvale qui come spazio.")
                    .font(Tipo.spaziSottotitolo)
                    .foregroundColor(Colori.Spazi.piedeTesto)
            } else {
                Text("Salva le finestre aperte (\(sistema.visibili.map(\.app.titolo).joined(separator: ", ")))")
                    .font(Tipo.spaziSottotitolo)
                    .foregroundColor(Colori.Spazi.piedeTesto)
                    .lineLimit(1)
                Spacer(minLength: 8)
                TextField("Nome dello spazio", text: $nome)
                    .campoTesto()
                    .frame(width: Misure.Spazi.campoNome)
                    .onSubmit(salva)
                Button("Salva", action: salva)
                    .buttonStyle(StileBlu())
                    .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Misure.Spazi.margine)
        .padding(.vertical, 10)
        .bordoAlto(Colori.Spazi.piedeBordo)
    }

    private func salva() {
        if stato.salvaSpazio(nome: nome) != nil { nome = "" }
    }
}
