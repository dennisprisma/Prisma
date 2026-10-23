import SwiftUI

/// Il pannello «Spazi di lavoro»: gli spazi pronti e quelli salvati, con la miniatura della
/// disposizione; in fondo si salvano le finestre aperte come nuovo spazio.
struct PannelloSpazi: View {
    @EnvironmentObject var stato: StatoShell
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
                .background(Colori.Spazi.interno)
                .clipShape(RoundedRectangle(cornerRadius: Misure.Spazi.raggioInterno))
                .overlay(RoundedRectangle(cornerRadius: Misure.Spazi.raggioInterno).strokeBorder(Colori.Spazi.internoBordo, lineWidth: 1))
            }
            .padding(Misure.Spazi.cornice)
            .background(RoundedRectangle(cornerRadius: Misure.Spazi.raggio).fill(Gradienti.corniceSpazi))
            .luceInterna(Colori.Spazi.corniceLuce, raggio: Misure.Spazi.raggio)
            .overlay(RoundedRectangle(cornerRadius: Misure.Spazi.raggio).strokeBorder(Colori.Spazi.corniceBordo, lineWidth: 1))
            .ombraCSS(Colori.Spazi.schedaOmbra, y: 8, sfocatura: 24)
            .frame(width: Misure.Spazi.pannello.width, height: Misure.Spazi.pannello.height)
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
            .incisione(Colori.Spazi.titoloIncisione, y: -1)
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
                .incisione(Colori.Spazi.sezioneIncisione)
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
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Misure.Spazi.raggioScheda).fill(Colori.Spazi.scheda))
            .overlay(RoundedRectangle(cornerRadius: Misure.Spazi.raggioScheda).strokeBorder(Colori.Spazi.schedaBordo, lineWidth: 1))
            .ombraCSS(Colori.Spazi.schedaOmbra, y: 1, sfocatura: 2)
            .contentShape(Rectangle())
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
            if stato.finestreVisibili.isEmpty {
                Text("Apri e disponi le app che ti servono, poi salvale qui come spazio.")
                    .font(Tipo.spaziSottotitolo)
                    .foregroundColor(Colori.Spazi.piedeTesto)
            } else {
                Text("Salva le finestre aperte (\(stato.finestreVisibili.map(\.app.titolo).joined(separator: ", ")))")
                    .font(Tipo.spaziSottotitolo)
                    .foregroundColor(Colori.Spazi.piedeTesto)
                    .lineLimit(1)
                Spacer(minLength: 8)
                TextField("Nome dello spazio", text: $nome)
                    .textFieldStyle(.roundedBorder)
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
        .background(Colori.Spazi.piede)
        .bordoAlto(Colori.Spazi.piedeBordo)
    }

    private func salva() {
        if stato.salvaSpazio(nome: nome) != nil { nome = "" }
    }
}
