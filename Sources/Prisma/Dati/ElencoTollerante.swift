import Foundation

/// Un elenco letto elemento per elemento: un elemento illeggibile si salta, gli altri restano.
/// (Un `decode` fallito non fa avanzare il contenitore: si consuma l'elemento con `Scartato`.)
/// Lo usano la griglia dell'esperienza (`EsperienzaProdotti`) e, dal giro 4, le schede di adeguatezza.
struct ElencoTollerante<Elemento: Decodable>: Decodable {
    var elementi: [Elemento] = []

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        while !c.isAtEnd {
            if let e = try? c.decode(Elemento.self) {
                elementi.append(e)
            } else if (try? c.decodeNil()) == true {
                // Un valore nullo: `decodeNil` lo ha già consumato
                continue
            } else if (try? c.decode(Scartato.self)) == nil {
                break
            }
        }
    }

    /// Consuma un elemento qualunque senza leggerlo.
    private struct Scartato: Decodable {
        init(from decoder: Decoder) throws {}
    }
}
