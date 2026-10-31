### Fluidità · commit 9510c1e

Tempi del thread principale. Mediana e massimo = aggiornamento (mediana e massimo su 3 giri, 2 con le app pesanti, dopo un giro di riscaldamento) + un disegno per azione. Aggiornamento = azione, run loop e impaginazione; disegno = cacheDisplay completo; prima volta = aggiornamento del giro di riscaldamento; avvisi = objectWillChange di StatoShell (app e widget) e di StatoFinestre (shell, dock, barra, pannelli) durante l'azione.

| Scenario | Azione | Mediana | Massimo | Aggiornamento | Disegno | Prima volta | Avvisi StatoShell | Avvisi StatoFinestre |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 5 clienti | avvio (stato, dati e primo disegno) | 2331 ms | 4273 ms | 1008 ms | 1322 ms | — | — | — |
| 5 clienti | apri Clienti | 2272 ms | 2318 ms | 671 ms | 1601 ms | 986 ms | 0 | 2 |
| 5 clienti | chiudi Clienti | 1426 ms | 1447 ms | 83 ms | 1343 ms | 106 ms | 0 | 1 |
| 5 clienti | apri Posizioni | 2497 ms | 2848 ms | 963 ms | 1534 ms | 1307 ms | 0 | 2 |
| 5 clienti | chiudi Posizioni | 1467 ms | 1498 ms | 121 ms | 1347 ms | 123 ms | 0 | 1 |
| 5 clienti | apri Analisi 360 | 1646 ms | 1646 ms | 211 ms | 1435 ms | 334 ms | 0 | 2 |
| 5 clienti | chiudi Analisi 360 | 1499 ms | 1568 ms | 58 ms | 1441 ms | 58 ms | 0 | 1 |
| 5 clienti | apri Incontri | 1880 ms | 1886 ms | 234 ms | 1645 ms | 332 ms | 0 | 2 |
| 5 clienti | chiudi Incontri | 1543 ms | 1559 ms | 59 ms | 1484 ms | 76 ms | 0 | 1 |
| 5 clienti | apri Obiettivi | 1707 ms | 1718 ms | 330 ms | 1377 ms | 433 ms | 0 | 2 |
| 5 clienti | chiudi Obiettivi | 1264 ms | 1268 ms | 64 ms | 1199 ms | 81 ms | 0 | 1 |
| 5 clienti | apri Confronti | 1654 ms | 1665 ms | 309 ms | 1345 ms | 321 ms | 0 | 2 |
| 5 clienti | chiudi Confronti | 1397 ms | 1401 ms | 54 ms | 1344 ms | 64 ms | 0 | 1 |
| 5 clienti | apri Prodotti | 2389 ms | 2519 ms | 910 ms | 1480 ms | 1040 ms | 0 | 2 |
| 5 clienti | chiudi Prodotti | 1418 ms | 1450 ms | 65 ms | 1353 ms | 84 ms | 0 | 1 |
| 5 clienti | apri Simulazioni | 1845 ms | 1904 ms | 455 ms | 1390 ms | 488 ms | 0 | 2 |
| 5 clienti | chiudi Simulazioni | 1444 ms | 1449 ms | 73 ms | 1370 ms | 72 ms | 0 | 1 |
| 5 clienti | apri Agenda | 2117 ms | 2143 ms | 293 ms | 1824 ms | 407 ms | 0 | 2 |
| 5 clienti | chiudi Agenda | 1303 ms | 1307 ms | 71 ms | 1232 ms | 72 ms | 0 | 1 |
| 5 clienti | apri Attività | 1707 ms | 1713 ms | 205 ms | 1502 ms | 218 ms | 0 | 2 |
| 5 clienti | chiudi Attività | 1357 ms | 1358 ms | 71 ms | 1286 ms | 66 ms | 0 | 1 |
| 5 clienti | apri Note | 2095 ms | 2297 ms | 230 ms | 1864 ms | 1131 ms | 0 | 2 |
| 5 clienti | chiudi Note | 1477 ms | 1481 ms | 62 ms | 1415 ms | 83 ms | 0 | 1 |
| 5 clienti | apri Documenti | 2715 ms | 2854 ms | 993 ms | 1722 ms | 1381 ms | 0 | 2 |
| 5 clienti | chiudi Documenti | 1486 ms | 1501 ms | 90 ms | 1396 ms | 111 ms | 0 | 1 |
| 5 clienti | apri Prospetti e report | 2281 ms | 2794 ms | 821 ms | 1460 ms | 503 ms | 0 | 2 |
| 5 clienti | chiudi Prospetti e report | 1453 ms | 1595 ms | 170 ms | 1282 ms | 73 ms | 0 | 1 |
| 5 clienti | apri Eve | 2393 ms | 2474 ms | 266 ms | 2127 ms | 1085 ms | 0 | 2 |
| 5 clienti | chiudi Eve | 1280 ms | 1281 ms | 59 ms | 1221 ms | 85 ms | 0 | 1 |
| 5 clienti | apri Ricerca | 1205 ms | 1211 ms | 70 ms | 1136 ms | 241 ms | 0 | 2 |
| 5 clienti | chiudi Ricerca | 1119 ms | 1124 ms | 54 ms | 1065 ms | 64 ms | 0 | 1 |
| 5 clienti | apri Impostazioni | 2394 ms | 2397 ms | 843 ms | 1551 ms | 963 ms | 0 | 2 |
| 5 clienti | chiudi Impostazioni | 1169 ms | 1181 ms | 90 ms | 1079 ms | 115 ms | 0 | 1 |
| 5 clienti | passa all'app sotto (2 aperte) | 1595 ms | 1598 ms | 31 ms | 1563 ms | 38 ms | 0 | 1 |
| 5 clienti | riduci Posizioni | 1436 ms | 1479 ms | 112 ms | 1325 ms | 101 ms | 0 | 2 |
| 5 clienti | ripristina Posizioni | 1808 ms | 1822 ms | 280 ms | 1528 ms | 292 ms | 0 | 2 |
| 5 clienti | riduci a finestra Clienti | 1627 ms | 1635 ms | 155 ms | 1472 ms | 192 ms | 0 | 2 |
| 5 clienti | ingrandisci Clienti | 1704 ms | 1707 ms | 179 ms | 1525 ms | 185 ms | 0 | 1 |
| 5 clienti | blocca (schermata di benvenuto) | 663 ms | 665 ms | 36 ms | 627 ms | 52 ms | 0 | 2 |
| 5 clienti | sblocca | 1889 ms | 1890 ms | 25 ms | 1864 ms | 22 ms | 0 | 2 |
| 5 clienti | apri il centro notifiche | 1697 ms | 1705 ms | 99 ms | 1597 ms | 477 ms | 0 | 1 |
| 5 clienti | chiudi il centro notifiche | 1603 ms | 1610 ms | 25 ms | 1577 ms | 28 ms | 0 | 1 |
| 5 clienti | apri la ricerca (⌘K) | 2143 ms | 2167 ms | 465 ms | 1678 ms | 407 ms | 1 | 1 |
| 5 clienti | chiudi la ricerca (⌘K) | 1678 ms | 1682 ms | 69 ms | 1609 ms | 69 ms | 0 | 1 |
| 5 clienti | aspetto scuro | 2395 ms | 2455 ms | 861 ms | 1534 ms | 814 ms | 1 | 0 |
| 5 clienti | aspetto chiaro | 2393 ms | 2463 ms | 891 ms | 1502 ms | 977 ms | 1 | 0 |
| 5 clienti | modifica una nota (un tasto) | 1713 ms | 1771 ms | 302 ms | 1410 ms | 298 ms | 1 | 0 |
| 5 clienti | annulla la modifica | 1947 ms | 1954 ms | 378 ms | 1569 ms | 290 ms | 1 | 0 |
| 5 clienti | mostra la scrivania | 1598 ms | 1646 ms | 401 ms | 1197 ms | 383 ms | 0 | 2 |
| 5 clienti | riapri le app (2) | 2807 ms | 2834 ms | 753 ms | 2054 ms | 618 ms | 0 | 4 |
| 5 clienti | sposta Clienti (un passo) | 1850 ms | 1850 ms | 25 ms | 1825 ms | 24 ms | 0 | 1 |
| 5 clienti | apri gli spazi di lavoro | 2048 ms | 2058 ms | 125 ms | 1923 ms | 156 ms | 0 | 1 |
| 5 clienti | chiudi gli spazi di lavoro | 1813 ms | 1814 ms | 39 ms | 1774 ms | 44 ms | 0 | 1 |
| 5 clienti | apri «Le tue app aperte» | 2085 ms | 2108 ms | 58 ms | 2027 ms | 70 ms | 0 | 1 |
| 5 clienti | chiudi «Le tue app aperte» | 1821 ms | 1834 ms | 33 ms | 1788 ms | 25 ms | 0 | 1 |
| 200 clienti | avvio (stato, dati e primo disegno) | 1753 ms | 1849 ms | 844 ms | 909 ms | — | — | — |
| 200 clienti | apre 4 app pesanti (prima volta) | 5336 ms | 5336 ms | 3147 ms | 2189 ms | — | 1 | 8 |
| 200 clienti | chiudi Clienti | 2016 ms | 2018 ms | 79 ms | 1937 ms | 169 ms | 0 | 1 |
| 200 clienti | apri Clienti | 2769 ms | 2813 ms | 548 ms | 2221 ms | 584 ms | 0 | 2 |
| 200 clienti | chiudi Posizioni | 2000 ms | 2001 ms | 180 ms | 1820 ms | 216 ms | 0 | 1 |
| 200 clienti | apri Posizioni | 3379 ms | 3394 ms | 1128 ms | 2251 ms | 1179 ms | 0 | 2 |
| 200 clienti | apri Analisi 360 | 2836 ms | 2862 ms | 214 ms | 2621 ms | 214 ms | 0 | 2 |
| 200 clienti | chiudi Analisi 360 | 2324 ms | 2327 ms | 60 ms | 2265 ms | 58 ms | 0 | 1 |
| 200 clienti | apri Incontri | 3157 ms | 3172 ms | 252 ms | 2905 ms | 183 ms | 0 | 2 |
| 200 clienti | chiudi Incontri | 3280 ms | 3289 ms | 74 ms | 3206 ms | 85 ms | 0 | 1 |
| 200 clienti | apri Obiettivi | 4213 ms | 4326 ms | 385 ms | 3828 ms | 270 ms | 0 | 2 |
| 200 clienti | chiudi Obiettivi | 3023 ms | 3026 ms | 64 ms | 2959 ms | 86 ms | 0 | 1 |
| 200 clienti | apri Confronti | 3380 ms | 3388 ms | 324 ms | 3057 ms | 321 ms | 0 | 2 |
| 200 clienti | chiudi Confronti | 2668 ms | 2673 ms | 71 ms | 2598 ms | 69 ms | 0 | 1 |
| 200 clienti | apri Prodotti | 4494 ms | 4710 ms | 1279 ms | 3216 ms | 1137 ms | 0 | 2 |
| 200 clienti | chiudi Prodotti | 3238 ms | 3257 ms | 172 ms | 3066 ms | 96 ms | 0 | 1 |
| 200 clienti | apri Simulazioni | 3307 ms | 3344 ms | 432 ms | 2876 ms | 548 ms | 0 | 2 |
| 200 clienti | chiudi Simulazioni | 2687 ms | 2690 ms | 92 ms | 2595 ms | 101 ms | 0 | 1 |
| 200 clienti | chiudi Agenda | 2257 ms | 2283 ms | 111 ms | 2147 ms | 134 ms | 0 | 1 |
| 200 clienti | apri Agenda | 3442 ms | 3446 ms | 346 ms | 3096 ms | 412 ms | 0 | 2 |
| 200 clienti | apri Attività | 3715 ms | 3789 ms | 264 ms | 3452 ms | 240 ms | 0 | 2 |
| 200 clienti | chiudi Attività | 3082 ms | 3083 ms | 74 ms | 3009 ms | 74 ms | 0 | 1 |
| 200 clienti | apri Note | 3385 ms | 3424 ms | 208 ms | 3177 ms | 837 ms | 0 | 2 |
| 200 clienti | chiudi Note | 3173 ms | 3187 ms | 107 ms | 3066 ms | 73 ms | 0 | 1 |
| 200 clienti | apri Documenti | 4702 ms | 4766 ms | 1260 ms | 3442 ms | 1140 ms | 0 | 2 |
| 200 clienti | chiudi Documenti | 3419 ms | 3456 ms | 228 ms | 3191 ms | 113 ms | 0 | 1 |
| 200 clienti | chiudi Prospetti e report | 2726 ms | 2755 ms | 110 ms | 2616 ms | 153 ms | 0 | 1 |
| 200 clienti | apri Prospetti e report | 4125 ms | 4221 ms | 591 ms | 3533 ms | 506 ms | 0 | 2 |
| 200 clienti | apri Eve | 5637 ms | 5664 ms | 256 ms | 5381 ms | 316 ms | 0 | 2 |
| 200 clienti | chiudi Eve | 2762 ms | 2762 ms | 91 ms | 2672 ms | 95 ms | 0 | 1 |
| 200 clienti | apri Ricerca | 3317 ms | 3398 ms | 195 ms | 3122 ms | 113 ms | 0 | 2 |
| 200 clienti | chiudi Ricerca | 3013 ms | 3056 ms | 111 ms | 2902 ms | 203 ms | 0 | 1 |
| 200 clienti | apri Impostazioni | 3884 ms | 3913 ms | 902 ms | 2983 ms | 848 ms | 0 | 2 |
| 200 clienti | chiudi Impostazioni | 2480 ms | 2483 ms | 111 ms | 2369 ms | 173 ms | 0 | 1 |
| 200 clienti | passa all'app sotto (4 aperte) | 2370 ms | 2370 ms | 53 ms | 2317 ms | 45 ms | 0 | 1 |
| 200 clienti | riduci Posizioni | 2258 ms | 2309 ms | 221 ms | 2037 ms | 204 ms | 0 | 2 |
| 200 clienti | ripristina Posizioni | 2828 ms | 2880 ms | 352 ms | 2476 ms | 326 ms | 0 | 2 |
| 200 clienti | riduci a finestra Clienti | 4259 ms | 4298 ms | 244 ms | 4016 ms | 253 ms | 0 | 2 |
| 200 clienti | ingrandisci Clienti | 4165 ms | 4197 ms | 306 ms | 3859 ms | 288 ms | 0 | 1 |
| 200 clienti | blocca (schermata di benvenuto) | 944 ms | 949 ms | 62 ms | 882 ms | 72 ms | 0 | 2 |
| 200 clienti | sblocca | 2816 ms | 2824 ms | 58 ms | 2758 ms | 58 ms | 0 | 2 |
| 200 clienti | apri il centro notifiche | 3137 ms | 3158 ms | 263 ms | 2874 ms | 706 ms | 0 | 1 |
| 200 clienti | chiudi il centro notifiche | 2827 ms | 2829 ms | 49 ms | 2779 ms | 48 ms | 0 | 1 |
| 200 clienti | apri la ricerca (⌘K) | 3389 ms | 3485 ms | 713 ms | 2676 ms | 588 ms | 1 | 1 |
| 200 clienti | chiudi la ricerca (⌘K) | 2881 ms | 2945 ms | 120 ms | 2761 ms | 174 ms | 0 | 1 |
| 200 clienti | aspetto scuro | 4738 ms | 4771 ms | 1580 ms | 3159 ms | 2115 ms | 1 | 0 |
| 200 clienti | aspetto chiaro | 4659 ms | 4713 ms | 1962 ms | 2697 ms | 1835 ms | 1 | 0 |
| 200 clienti | modifica una nota (un tasto) | 3157 ms | 3177 ms | 545 ms | 2612 ms | 632 ms | 1 | 0 |
| 200 clienti | annulla la modifica | 3100 ms | 3109 ms | 539 ms | 2560 ms | 525 ms | 1 | 0 |
| 200 clienti | mostra la scrivania | 1539 ms | 1549 ms | 373 ms | 1166 ms | 478 ms | 0 | 2 |
| 200 clienti | riapri le app (4) | 3329 ms | 3344 ms | 695 ms | 2633 ms | 683 ms | 0 | 8 |
| 200 clienti | sposta Clienti (un passo) | 2513 ms | 2514 ms | 41 ms | 2473 ms | 48 ms | 0 | 1 |
| 200 clienti | apri gli spazi di lavoro | 2884 ms | 2907 ms | 126 ms | 2758 ms | 117 ms | 0 | 1 |
| 200 clienti | chiudi gli spazi di lavoro | 2834 ms | 2839 ms | 69 ms | 2765 ms | 62 ms | 0 | 1 |
| 200 clienti | apri «Le tue app aperte» | 2623 ms | 2641 ms | 111 ms | 2512 ms | 129 ms | 0 | 1 |
| 200 clienti | chiudi «Le tue app aperte» | 2348 ms | 2352 ms | 42 ms | 2306 ms | 51 ms | 0 | 1 |

Memoria: all'inizio: 86 MB residenti, 76 MB di impronta · 5 clienti, dopo l'avvio: 210 MB residenti, 166 MB di impronta · 5 clienti, dopo il giro delle app: 285 MB residenti, 203 MB di impronta · 5 clienti, alla fine (shell aperta): 402 MB residenti, 309 MB di impronta · dopo lo scenario con 5 clienti (shell chiusa): 309 MB residenti, 214 MB di impronta · 200 clienti, dopo l'avvio: 361 MB residenti, 324 MB di impronta · 200 clienti, dopo il giro delle app: 448 MB residenti, 284 MB di impronta · 200 clienti, alla fine (shell aperta): 450 MB residenti, 281 MB di impronta · dopo lo scenario con 200 clienti (shell chiusa): 380 MB residenti, 217 MB di impronta.

Memoria alla fine: 380 MB residenti, 217 MB di impronta · durata della prova: 407.6 s.
