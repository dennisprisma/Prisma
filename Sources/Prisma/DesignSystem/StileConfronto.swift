import Foundation

/// Il foglio del confronto tra modelli di Eve (una pagina HTML sul Mac): carta chiara e colori fissi e opachi
/// come i documenti di Prisma (Carta.swift), una colonna per modello.
enum StileConfronto {
    static let css = """
    body { background: #fffefa; color: #3f413b; font: 14px/1.5 -apple-system, "SF Pro Text", "Helvetica Neue", sans-serif; margin: 32px; }
    h1 { color: #293c4c; font-size: 24px; margin: 0 0 4px; }
    h2 { color: #293c4c; font-size: 17px; margin: 32px 0 6px; padding-top: 12px; border-top: 1px solid #ddd8ca; }
    .nota { color: #81847d; font-size: 12px; }
    .domanda { color: #3f413b; margin: 0 0 12px; font-style: italic; }
    table { border-collapse: collapse; margin: 12px 0; }
    th, td { border-bottom: 1px solid #e8e4d8; padding: 6px 12px; text-align: left; }
    th { color: #395269; font-weight: 600; }
    .colonne { display: grid; grid-auto-flow: column; grid-auto-columns: minmax(260px, 1fr); gap: 14px; }
    .colonna { background: #fbfaf5; border: 1px solid #d9d5c9; border-radius: 10px; padding: 12px 14px; }
    .colonna h3 { color: #293c4c; font-size: 14px; margin: 0 0 2px; }
    .colonna p { white-space: pre-wrap; margin: 8px 0 0; }
    .errore { color: #6b5426; background: #fbf3df; border: 1px solid #e2c98f; border-radius: 6px; padding: 6px 8px; }
    """
}
