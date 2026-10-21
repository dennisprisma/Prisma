# Prisma
Financial Desk for Financial Advisor

App macOS nativa (SwiftUI, Swift Package Manager, senza Xcode) per uso personale.

## Build
La build avviene solo su GitHub Actions (`.github/workflows/build.yml`, runner `macos-15-intel`) a ogni push e pull request.
L'artifact scaricabile si chiama **Prisma** e contiene `Prisma.zip` con dentro `Prisma.app` (universale arm64 + x86_64, firma ad-hoc).

## Struttura
- `Sources/Prisma/` — codice dell'app
- `Sources/Prisma/Risorse/` — risorse (icone convertite da `Design/Icone`)
- `Design/template.html` — template grafico di riferimento
- `Design/Icone/` — icone originali (SVG) e `AppIcon.png` per l'icona dell'app

## Anteprime
A ogni push il workflow disegna le schermate principali (`Prisma --istantanee <cartella>`) e le pubblica sul branch `anteprime`.
