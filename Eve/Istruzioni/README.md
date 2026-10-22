# Istruzioni di Eve

- `chat.md`: istruzioni di sistema della conversazione. L'app le legge da `Prisma.app/Contents/Resources/Eve/Istruzioni/` (il workflow le copia lì) e vi aggiunge la scheda compatta del cliente preparata da Prisma (`ContestoEve`).

- `estrazione.md`: istruzioni per leggere gli appunti degli Incontri e proporre bisogni, eventi di vita e attività in un formato a righe che l'app controlla (`EstrattoreIncontro`). Le proposte vanno sempre confermate dal consulente.

- `commento.md`: istruzioni per scrivere il commento del consulente che apre i report per il cliente (pagina «Due parole per te»). Il modello riscrive la bozza composta da Prisma con le cifre del report; se compare una cifra che non è nella bozza, l'app tiene la bozza (`CommentoEve`). Il consulente rilegge e salva.

- `documenti.md`: istruzioni per leggere una pagina di KID, polizza o estratto conto e completare i campi che le regole di Prisma (`EstrattoreDocumento`) non hanno trovato. Ogni dato va confermato dal consulente, con la pagina di riferimento.

Modificare qui il testo cambia il comportamento di Eve alla build successiva, senza toccare il codice.
Tenere il testo corto: il modello Apple ha una finestra di circa 4.000 token per istruzioni, scheda, storia e risposta.
