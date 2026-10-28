import Foundation

// Proprietario: G2 (ciclo di vita). I token in più della schermata di benvenuto; gli altri sono in Movimento.swift.

extension Tema.Moto.Sblocco {
    /// Il luccichio di «scorri per entrare»: una passata ogni 3,2 s (come prima), disegnata al massimo
    /// 30 volte al secondo e ferma con «Riduci movimento».
    static let periodoLuccichio: Double = 3.2
    static let intervalloLuccichio: Double = 1.0 / 30
    /// La scritta si spegne più in fretta della corsa: con la manopola a 1/1,6 della corsa è già sparita.
    static let spegnimentoScritta: Double = 1.6
}
