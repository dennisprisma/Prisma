#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

/// Un testo dell'archivio che si scrive qui e passa allo stato poco dopo l'ultimo tasto (come le Note,
/// dopo `AppNote.attesaNota`): ogni lettera ridisegna solo il campo, non tutta Prisma. Cambiato da fuori
/// (Eve, un ripristino) mentre non si scrive, vale l'archivio. Chi lo usa gli dà un `.id` per oggetto
/// (cliente, incontro, documento): cambiando oggetto la bozza riparte da quello nuovo e la scrittura in
/// attesa va a quello vecchio. Le azioni che leggono subito il testo dall'archivio chiamano prima
/// `TestiRinviati.scriviOra()`.
///
///     TestoRinviato(testo: Binding(get: { c.nota }, set: { stato.aggiornaNota(c.id, $0) }),
///                   salvaOra: { stato.salvaOra() }) { bozza in
///         TextEditor(text: bozza)
///     }
///     .id(c.id)
struct TestoRinviato<Campo: View>: View {
    @Binding var testo: String
    /// Chiamata alla chiusura di Prisma dopo aver scritto la bozza in attesa (di solito `stato.salvaOra`).
    let salvaOra: () -> Void
    let campo: (Binding<String>) -> Campo
    @State private var bozza: String
    @State private var scrittura = Rinvio()

    init(testo: Binding<String>, salvaOra: @escaping () -> Void = {},
         @ViewBuilder campo: @escaping (Binding<String>) -> Campo) {
        _testo = testo
        self.salvaOra = salvaOra
        self.campo = campo
        _bozza = State(initialValue: testo.wrappedValue)
    }

    var body: some View {
        campo($bozza)
            .onChange(of: bozza) { nuovo in
                // Tornati al testo dell'archivio senza nulla in attesa: non c'è niente da scrivere
                guard nuovo != testo || scrittura.inAttesa else { return }
                let legame = $testo
                let rinvio = scrittura
                let chiave = ObjectIdentifier(rinvio)
                rinvio.dopo(AppNote.attesaNota) {
                    TestiRinviati.togli(chiave)
                    if legame.wrappedValue != nuovo { legame.wrappedValue = nuovo }
                }
                TestiRinviati.registra(chiave) { [weak rinvio] in rinvio?.subito() }
            }
            // Cambiato da fuori mentre non si scrive: vale l'archivio
            .onChange(of: testo) { esterno in
                if !scrittura.inAttesa && esterno != bozza { bozza = esterno }
            }
            .onDisappear { scrittura.subito() }
            #if os(macOS)
            // Chiudendo Prisma entro l'attesa: si scrive e si salva di nuovo
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                guard scrittura.inAttesa else { return }
                scrittura.subito()
                salvaOra()
            }
            #elseif os(iOS)
            // Su iPhone e iPad l'app non riceve un preavviso di chiusura: si scrive e si salva quando va
            // in secondo piano, prima che il sistema possa chiuderla o bloccare il dispositivo
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                guard scrittura.inAttesa else { return }
                scrittura.subito()
                salvaOra()
            }
            #endif
    }
}

/// Le scritture in attesa di tutti i `TestoRinviato`: le azioni che leggono il testo dall'archivio
/// (per esempio «Ai prossimi passi», che ricava le proposte dagli appunti) le fanno prima con `scriviOra()`.
/// Si usa solo dal thread principale.
enum TestiRinviati {
    nonisolated(unsafe) private static var inAttesa: [ObjectIdentifier: () -> Void] = [:]

    /// Scrive subito nell'archivio tutti i testi in attesa.
    static func scriviOra() {
        guard !inAttesa.isEmpty else { return }
        let tutte = inAttesa
        inAttesa = [:]
        for scrivi in tutte.values { scrivi() }
    }

    static func registra(_ chiave: ObjectIdentifier, _ scrivi: @escaping () -> Void) {
        inAttesa[chiave] = scrivi
    }

    static func togli(_ chiave: ObjectIdentifier) {
        inAttesa[chiave] = nil
    }
}
