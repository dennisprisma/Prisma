#if os(iOS)
import Foundation

/// La prova del dock di iPhone e iPad (`--prova-dock`, esito in Documents/esito-prova-dock.txt come le altre prove):
/// - il lato delle icone di `fitDock` resta fra il minimo e il massimo e il dock sta nello schermo meno 12 punti,
///   alle larghezze vere di iPhone (6 elementi) e iPad (17 elementi, verticale e orizzontale);
/// - i nomi sotto le icone ci sono sull'iPhone e sull'iPad in orizzontale, non sull'iPad in verticale;
/// - il dock dell'iPhone e «Tutte le app» insieme hanno tutte le app, ognuna una volta; in modo cliente solo quelle
///   consentite.
@MainActor
enum ProvaDockMobile {
    private typealias D = Tema.Misura.Mobile.Dock

    static func esegui() -> Int32 {
        var errori: [String] = []
        func verifica(_ nome: String, _ ok: Bool) {
            print("\(ok ? "OK    " : "ERRORE") \(nome)")
            if !ok { errori.append(nome) }
        }

        // 6 elementi: Scrivania, Clienti, Posizioni, Agenda, Attività, Tutte le app
        let telefono = DisposizioneDockMobile.appTelefono.count + 2
        // 17 elementi: Scrivania e le 16 app
        let iPad = AppPrisma.allCases.count + 1
        let casi: [(CGFloat, Int, CGFloat)] = [
            (375, telefono, D.massimoTelefono), (393, telefono, D.massimoTelefono),
            (402, telefono, D.massimoTelefono), (440, telefono, D.massimoTelefono),
            (744, iPad, D.massimoiPad), (834, iPad, D.massimoiPad), (1032, iPad, D.massimoiPad),
            (1210, iPad, D.massimoiPad), (1376, iPad, D.massimoiPad),
        ]
        for (w, n, massimo) in casi {
            let lato = DisposizioneDockMobile.lato(elementi: n, larghezza: w, massimo: massimo)
            let larghezza = DisposizioneDockMobile.larghezza(elementi: n, lato: lato)
            verifica("lato fra \(D.minimo) e \(massimo) a \(Int(w)) pt (\(n) elementi): \(lato)", lato >= D.minimo && lato <= massimo)
            verifica("dock largo \(Int(larghezza.rounded())) ≤ \(Int(w - D.bordo)) a \(Int(w)) pt", larghezza <= w - D.bordo)
        }
        func nomi(_ w: CGFloat, _ n: Int, _ massimo: CGFloat) -> Bool {
            DisposizioneDockMobile.conNomi(lato: DisposizioneDockMobile.lato(elementi: n, larghezza: w, massimo: massimo))
        }
        verifica("nomi sotto le icone sull'iPhone (393)", nomi(393, telefono, D.massimoTelefono))
        verifica("nomi sotto le icone sull'iPad in orizzontale (1376)", nomi(1376, iPad, D.massimoiPad))
        verifica("niente nomi sull'iPad in verticale (834)", !nomi(834, iPad, D.massimoiPad))
        verifica("niente nomi sull'iPad mini in verticale (744)", !nomi(744, iPad, D.massimoiPad))

        // Dock dell'iPhone + «Tutte le app» = tutte le app, ognuna una volta (in «Tutte le app» ci sono tutte)
        let tutte = Set(AppPrisma.allCases)
        let nelDock = DisposizioneDockMobile.app(.telefono, consentita: { _ in true })
        verifica("il dock dell'iPhone non ripete le app", Set(nelDock).count == nelDock.count)
        verifica("il dock dell'iPhone ha solo app di Prisma", Set(nelDock).isSubset(of: tutte))
        verifica("il dock dell'iPad ha tutte le app", Set(DisposizioneDockMobile.app(.iPad, consentita: { _ in true })) == tutte)

        // In modo cliente solo le app consentite (Note, Ricerca, Impostazioni no)
        let consentita: (AppPrisma) -> Bool = { !StatoShell.appRiservate.contains($0) }
        let telefonoCliente = DisposizioneDockMobile.app(.telefono, consentita: consentita)
        let iPadCliente = DisposizioneDockMobile.app(.iPad, consentita: consentita)
        verifica("modo cliente: niente app riservate nel dock dell'iPhone",
                 telefonoCliente.allSatisfy(consentita))
        verifica("modo cliente: niente app riservate nel dock dell'iPad",
                 Set(iPadCliente) == tutte.subtracting(StatoShell.appRiservate))

        if errori.isEmpty {
            print("Prova del dock: tutto a posto")
            return 0
        }
        print("Prova del dock: \(errori.count) errori: \(errori.joined(separator: "; "))")
        return 1
    }
}
#endif
