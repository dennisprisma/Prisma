import Foundation
import Security

/// La password dei backup nel Portachiavi di login del Mac (in Accesso Portachiavi: «Prisma backup»).
/// Mai nell'archivio né nelle preferenze: l'archivio finisce nei backup.
/// Niente portachiavi «data protection»: con la firma ad-hoc di Prisma darebbe l'errore -34018.
/// Dopo un aggiornamento di Prisma il Mac può chiedere una volta il permesso di leggerla.
/// Le prove non lo usano mai (la password si passa direttamente a `GestoreBackup`).
enum PortachiaviBackup {
    static let servizio = "Prisma backup"
    static let conto = "password dei backup"
    static let etichetta = "Prisma – password dei backup"

    private static var ricerca: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: servizio,
         kSecAttrAccount as String: conto]
    }

    /// Salva (o sostituisce) la password. false se il Portachiavi non l'ha accettata.
    @discardableResult
    static func salva(_ password: String) -> Bool {
        let valore = Data(password.utf8)
        let modifica: [String: Any] = [kSecValueData as String: valore]
        let aggiornata = SecItemUpdate(ricerca as CFDictionary, modifica as CFDictionary)
        if aggiornata == errSecSuccess { return true }
        if aggiornata != errSecItemNotFound { _ = SecItemDelete(ricerca as CFDictionary) }
        var nuova = ricerca
        nuova[kSecValueData as String] = valore
        nuova[kSecAttrLabel as String] = etichetta
        return SecItemAdd(nuova as CFDictionary, nil) == errSecSuccess
    }

    /// La password salvata (nil se non c'è o se il Mac non ne ha dato il permesso).
    static func leggi() -> String? {
        var domanda = ricerca
        domanda[kSecReturnData as String] = true
        domanda[kSecMatchLimit as String] = kSecMatchLimitOne
        var risultato: CFTypeRef?
        guard SecItemCopyMatching(domanda as CFDictionary, &risultato) == errSecSuccess,
              let dati = risultato as? Data,
              let password = String(data: dati, encoding: .utf8), !password.isEmpty else { return nil }
        return password
    }

    static func elimina() {
        _ = SecItemDelete(ricerca as CFDictionary)
    }
}
