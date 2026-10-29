import SwiftUI

// MARK: - Gettoni dell'app Documenti (tema Liquid Glass, giro 5)
// I fogli stampati hanno i loro gettoni in ComponentiDocumenti.swift e StileDocumenti.swift: questi sono solo
// dell'app (elenco stile Finder, anteprima, scheda dei dati, confronto dei documenti del cliente).

extension Tema.Misura {
    /// Misure dell'app Documenti.
    enum Documenti {
        /// Colonna dei dati accanto all'anteprima.
        static let scheda: CGFloat = 420
        /// La stessa colonna quando mostra il confronto con il dossier: la tabella ha bisogno di più spazio.
        static let schedaConfronto: CGFloat = 560
        /// Sotto questa larghezza la colonna dei dati non si stringe più.
        static let schedaMinima: CGFloat = 300
        static let anteprimaMinima: CGFloat = 340
        /// Sotto questa larghezza del dettaglio l'anteprima si nasconde da sola.
        static let minimoConAnteprima: CGFloat = 780
        /// Tessera del tipo nell'elenco e, più grande, nella barra del dettaglio.
        static let tessera: CGFloat = 30
        static let tesseraGrande: CGFloat = 38
        /// Segno «da leggere»: un cerchio vuoto (non un pallino blu, che si confonderebbe con Alleanza).
        static let puntoNuovo: CGFloat = 8
        static let bordoNuovo: CGFloat = 1.5
        /// Righe dell'elenco.
        static let rigaElenco = EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 10)
        static let spazioRiga: CGFloat = 10
        static let spazioTestiRiga: CGFloat = 2
        static let spazioStatoRiga: CGFloat = 5
        static let testataGruppo = EdgeInsets(top: 12, leading: 14, bottom: 4, trailing: 12)
        /// Barra del dettaglio: margini, spazio tra le righe e tra gli elementi di una riga.
        static let barraDettaglio = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 12)
        static let spazioRigheBarra: CGFloat = 6
        static let spazioBarra: CGFloat = 8
        static let pulsante = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        static let pulsanteIcona = EdgeInsets(top: 4, leading: 7, bottom: 4, trailing: 7)
        static let menuCategoria: CGFloat = 170
        /// Colonna dei dati: margini, spazio tra le sezioni, righe.
        static let margineScheda = EdgeInsets(top: 12, leading: 14, bottom: 18, trailing: 14)
        static let spazioSezioni: CGFloat = 12
        static let occhielloSezione = EdgeInsets(top: 10, leading: 12, bottom: 4, trailing: 12)
        static let noteSezione = EdgeInsets(top: 4, leading: 12, bottom: 10, trailing: 12)
        static let spazioNote: CGFloat = 4
        static let rigaDato = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 10)
        static let spazioRigaDato: CGFloat = 8
        static let etichettaDato: CGFloat = 132
        /// Spunta del dato (cerchio vuoto o pieno) e matita della correzione.
        static let spuntaDato: CGFloat = 18
        /// Fonte «p. 2»: margini della capsula.
        static let fonte = EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)
        /// Banner in cima alla scheda.
        static let banner = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        static let spazioBanner: CGFloat = 10
        /// Dati non trovati: larghezza minima di un gettone e campo del popover «Aggiungi».
        static let chipMancante: CGFloat = 150
        static let spazioChip: CGFloat = 6
        static let campoAggiungi: CGFloat = 220
        static let popover = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        /// Il foglio dell'anteprima: proporzione A4, margini del foglio e del tavolo, larghezza massima.
        static let rapportoA4: CGFloat = 210.0 / 297.0
        static let margineFoglio = EdgeInsets(top: 22, leading: 26, bottom: 22, trailing: 26)
        static let margineTavolo: CGFloat = 20
        static let foglioMassimo: CGFloat = 640
        static let spazioRigheFoglio: CGFloat = 1
        static let margineRigaFoglio: CGFloat = 3
        static let spazioNotaFoglio: CGFloat = 10
        /// Scheda «Testo»: il testo letto nel riquadro.
        static let riquadroTesto = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        /// Barra delle pagine sotto il foglio.
        static let barraPagine: CGFloat = 32
        static let marginePagine: CGFloat = 12
        static let spazioPagine: CGFloat = 10
        // Tabella dei documenti del cliente (§6.7): quella di KID e polizze usa i gettoni della specifica 9
        static let spuntaConfronto: CGFloat = 26
        static let colonnaDatoConfronto: CGFloat = 132
        static let colonnaEsito: CGFloat = 104
        static let spazioConfronto: CGFloat = 12
        /// Modulo «Crea da un documento».
        static let modulo: CGFloat = 340
        static let margineModulo = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        static let spazioModulo: CGFloat = 12
        static let menuArea: CGFloat = 240
        /// Vuoto iniziale e rilascio.
        static let vuotoLarghezza: CGFloat = 600
        static let passoVuoto: CGFloat = 180
        static let spazioVuoto: CGFloat = 14
        static let cerchioPasso: CGFloat = 22
        static let marginePasso = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        static let capsulaRilascio = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 18)
        /// «Nessun documento con questi filtri».
        static let spazioNessuno: CGFloat = 10
    }
}

extension Tema.Raggio {
    /// Raggi dell'app Documenti.
    enum Documenti {
        static let tessera: CGFloat = Tema.Raggio.miniatura
        static let foglio: CGFloat = 3
        static let banner: CGFloat = Tema.Raggio.tessera
        /// La riga del dato evidenziato (scheda, testo e foglio).
        static let evidenza: CGFloat = Tema.Raggio.tasto
    }
}

extension Tema.Colore {
    /// Colori dell'app Documenti.
    enum Documenti {
        /// Il cerchio vuoto «da leggere»: inchiostro, fuori dalla coppia blu Alleanza / cuoio indipendente.
        static let nuovo = Tema.Colore.inchiostroSecondario
        static let tessera = Tema.Colore.pozzetto
        static let simbolo = Tema.Colore.inchiostroSecondario
        static let daControllare = Tema.Colore.accento
        static let confermato = Tema.Colore.inchiostroTerziario
        /// Valore che non torna (arancio del tema).
        static let diverso = Tema.Colore.testoProposta
        static let daAggiungere = Tema.Colore.accento
        /// Riga della fonte (scheda, testo, foglio ricostruito).
        static let evidenzia: Color = Tema.Colore.accento.opacity(0.18)
        /// Fisso: sta sul foglio bianco del PDF.
        static let evidenziaPDF = Color(r: 0, g: 122, b: 255, a: 0.28)
        /// Banner: informazione, attenzione (cose che non tornano), errore.
        static let fondoBanner: Color = Tema.Colore.accento.opacity(0.08)
        static let fondoBannerAttenzione: Color = Tema.Colore.fondoProposta
        static let fondoBannerErrore: Color = Tema.Colore.Componenti.fondoErrore
        static let simboloBanner = Tema.Colore.accento
        static let simboloBannerAttenzione = Tema.Colore.testoProposta
        static let simboloBannerErrore = Tema.Colore.scadenzaOra
        /// Numero dei passi del vuoto iniziale.
        static let passo = Tema.Colore.accento
        static let testoPasso = Tema.Colore.Componenti.testoSuColore
        // Il foglio dell'anteprima è carta: colori fissi, uguali in chiaro e in scuro
        static let foglio = Color.white
        static let testoFoglio = Color(hex: "#1D1D1F")
        static let notaFoglio = Color(hex: "#86868B")
        static let evidenziaFoglio = Color(r: 0, g: 122, b: 255, a: 0.16)
    }
}

extension Tema.Testo {
    /// Caratteri dell'app Documenti.
    enum Documenti {
        static let titolo = Tema.Testo.sf(17, .bold)
        static let valore = Tema.Testo.sf(13).monospacedDigit()
        static let simboloTessera = Tema.Testo.sf(14)
        static let simboloTesseraGrande = Tema.Testo.sf(18)
        static let testoFoglio = Font.system(size: 10.5 * Tipo.fattore, design: .default)
        static let notaFoglio = Font.system(size: 9.5 * Tipo.fattore, design: .default)
        static let numeroPasso = Tema.Testo.sf(12, .bold)
        static let simboloBanner = Tema.Testo.sf(15)
        static let spunta = Tema.Testo.sf(14)
    }
}
