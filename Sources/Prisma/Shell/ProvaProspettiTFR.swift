import Foundation
import PDFKit

/// Prova del prospetto e del report «TFR in azienda o nel fondo» (giro 6, specifica 11 §8.3), dentro
/// `Prisma --prova-prospetti`: il prospetto ha 2 pagine, il report almeno 4 (copertina e 3 slide) senza contributi
/// e almeno 5 con i contributi; i PDF si creano e, con la cartella indicata, si salvano.
/// La chiama `ProvaProspetti.esegui` prima del riepilogo, con la sua funzione di verifica.
@MainActor
enum ProvaProspettiTFR {
    static func esegui(_ verifica: (String, Bool, String) -> Void, cartella: URL?) {
        let stato = StatoShell(persistente: false)
        stato.clienteAttivoId = "marco"
        let ipotesi = stato.ipotesiTFR("marco")
        verifica("TFR: le ipotesi di Marco partono dal suo dossier", ipotesi.retribuzione > 0 && ipotesi.contributoLavoratore == 0,
                 "retribuzione \(Int(ipotesi.retribuzione)), \(ipotesi.anni) anni")

        for report in [false, true] {
            let genere = report ? "report" : "prospetto"
            guard let d = stato.documentoTFR(report: report) else {
                verifica("TFR: \(genere) di Marco composto", false, "")
                continue
            }
            if report {
                verifica("TFR: report di Marco con almeno 4 pagine", d.pagine.count >= 4, "\(d.pagine.count) pagine")
            } else {
                verifica("TFR: prospetto di Marco di 2 pagine", d.pagine.count == 2, "\(d.pagine.count) pagine")
            }
            guard let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) else {
                verifica("TFR: PDF del \(genere) di Marco creato", false, "")
                continue
            }
            verifica("TFR: PDF del \(genere) di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count,
                     "\(documento.pageCount) pagine, \(pdf.count / 1024) KB")
            let testo = ProvaProspetti.spazi(StampaCarta.testo(pdf).joined(separator: "\n"))
            verifica("TFR: nel PDF del \(genere) il nome del cliente", testo.contains(d.cliente), "")
            if !report {
                verifica("TFR: nel prospetto «Netto alla pensione» e il metodo",
                         testo.contains("Netto alla pensione") && testo.contains("Come si calcola"), "")
            }
            if let cartella { try? pdf.write(to: cartella.appendingPathComponent("tfr-marco-\(genere).pdf")) }
        }

        // Con i contributi del lavoratore e del datore: una slide in più nel report e una colonna in più nel prospetto
        var conContributi = ipotesi
        conContributi.contributoLavoratore = 1.2
        conContributi.contributoDatore = 1.6
        stato.salvaIpotesiTFR("marco", conContributi)
        verifica("TFR: le ipotesi salvate si rileggono", stato.ipotesiTFR("marco") == conContributi, "")
        if let d = stato.documentoTFR(report: true) {
            verifica("TFR: report con i contributi di almeno 5 pagine", d.pagine.count >= 5, "\(d.pagine.count) pagine")
            if let pdf = StampaCarta.pdf(d), let documento = PDFDocument(data: pdf) {
                verifica("TFR: PDF del report con i contributi di \(d.pagine.count) pagine", documento.pageCount == d.pagine.count,
                         "\(documento.pageCount) pagine")
                if let cartella { try? pdf.write(to: cartella.appendingPathComponent("tfr-marco-report-contributi.pdf")) }
            } else {
                verifica("TFR: PDF del report con i contributi creato", false, "")
            }
        } else {
            verifica("TFR: report con i contributi composto", false, "")
        }
        if let d = stato.documentoTFR(report: false), let pdf = StampaCarta.pdf(d) {
            verifica("TFR: prospetto con i contributi di 2 pagine", d.pagine.count == 2, "\(d.pagine.count) pagine")
            if let cartella { try? pdf.write(to: cartella.appendingPathComponent("tfr-marco-prospetto-contributi.pdf")) }
        } else {
            verifica("TFR: prospetto con i contributi creato", false, "")
        }

        // Ripartire dai dati del cliente toglie le ipotesi salvate
        stato.ripartiTFR("marco")
        verifica("TFR: «Riparti dai dati del cliente» toglie le ipotesi salvate",
                 stato.dati.confrontiTFR["marco"] == nil && stato.ipotesiTFR("marco") == ipotesi, "")

        // Senza retribuzione non c'è documento
        var vuote = ipotesi
        vuote.retribuzione = 0
        stato.salvaIpotesiTFR("marco", vuote)
        verifica("TFR: senza retribuzione nessun documento", stato.documentoTFR(report: false) == nil, "")
        stato.ripartiTFR("marco")
    }
}
