#!/usr/bin/env bash
# Prove di Prisma nel simulatore iOS (Prisma.app già installata sul dispositivo acceso).
#
# Uso: Supporto/iOS/prove.sh <udid> [prova …]
#   Senza elenco esegue tutte le prove del giro 1:
#     verifica-risorse prova-calcoli prova-prospetti prova-carico prova-backup prova-eve prova-dock backup-ditto
#   «prova-dock» (giro 3): il lato delle icone del dock di iPhone e iPad (fitDock del tema) e le app del dock.
#   «backup-ditto» è una sequenza: l'app prepara un archivio di prova (--prepara-campione-backup),
#   lo script lo comprime con ditto sul runner (gli stessi argomenti di Backup.swift) e l'app lo
#   cifra, decifra, estrae con LettoreZip e ripristina (--prova-backup-ditto <zip>).
#
# Esito: il codice d'uscita di `simctl launch` non è quello dell'app. Ogni prova scrive
# Documents/esito-<prova>.txt (prima riga «OK» oppure «ERRORE …», EsitoProva.scrivi);
# file mancante = prova fallita. Lo script prosegue con le altre prove ed esce con 1 se
# almeno una è fallita.
set -o pipefail

if [ $# -lt 1 ]; then
    echo "Uso: $0 <udid> [prova …]" >&2
    exit 2
fi

UDID="$1"
shift
BID="${PRISMA_BID:-local.prisma}"
LIMITE="${PRISMA_LIMITE_PROVA:-600}"   # secondi per prova
if [ $# -gt 0 ]; then
    PROVE=("$@")
else
    PROVE=(verifica-risorse prova-calcoli prova-prospetti prova-carico prova-backup prova-eve prova-dock backup-ditto)
fi

# macOS non ha `timeout`: un'app bloccata non deve bloccare il job fino al limite di GitHub
corri() { perl -e 'alarm shift; exec @ARGV' "$@"; }

DATI="$(xcrun simctl get_app_container "$UDID" "$BID" data)" || {
    echo "::error::Contenitore dati di $BID non trovato: l'app è installata?"
    exit 1
}
DOC="$DATI/Documents"
mkdir -p "$DOC"
echo "Contenitore dati: $DATI"

FALLITE=()
RIEPILOGO=()

# lancia <nome> [argomenti…]: avvia Prisma con --<nome> e legge Documents/esito-<nome>.txt
lancia() {
    local nome="$1"
    shift
    local esito="$DOC/esito-$nome.txt"
    local inizio=$SECONDS
    rm -f "$esito"
    echo "::group::$nome"
    corri "$LIMITE" xcrun simctl launch --console-pty --terminate-running-process \
        "$UDID" "$BID" "--$nome" "$@" < /dev/null
    local codice=$?   # subito dopo il lancio: è l'uscita di simctl (142 = tempo scaduto)
    echo "::endgroup::"
    local durata=$((SECONDS - inizio))
    [ "$codice" = 142 ] && echo "$nome: tempo massimo di $LIMITE s superato"
    if [ -f "$esito" ] && head -1 "$esito" | grep -q '^OK'; then
        echo "$nome: OK (${durata} s)"
        RIEPILOGO+=("| $nome | OK | ${durata} s |")
        return 0
    fi
    local motivo
    if [ -f "$esito" ]; then
        motivo="$(head -c 400 "$esito" | tr '\n|' ' /')"
    else
        motivo="nessun esito scritto (uscita di simctl $codice)"
    fi
    echo "::error::$nome fallita su iOS: $motivo"
    [ -f "$esito" ] && cat "$esito"
    FALLITE+=("$nome")
    RIEPILOGO+=("| $nome | ERRORE: $motivo | ${durata} s |")
    return 1
}

backup_ditto() {
    lancia prepara-campione-backup || return 1
    local campione="$DOC/campione/Prisma"
    local zip="$DOC/campione.zip"
    if [ ! -d "$campione" ]; then
        echo "::error::prepara-campione-backup non ha creato $campione"
        FALLITE+=("prova-backup-ditto")
        RIEPILOGO+=("| prova-backup-ditto | ERRORE: campione mancante | – |")
        return 1
    fi
    rm -f "$zip"
    # Gli stessi argomenti di Backup.swift: descrittori di dati, deflate, __MACOSX/
    ditto -c -k --sequesterRsrc --keepParent "$campione" "$zip"
    ls -la "$zip"
    lancia prova-backup-ditto "$zip"
}

for prova in "${PROVE[@]}"; do
    if [ "$prova" = backup-ditto ]; then
        backup_ditto
    else
        lancia "$prova"
    fi
done

# Riepilogo leggibile nella pagina della build
{
    echo "### Prove iOS · $(xcrun simctl list devices -j | jq -r --arg u "$UDID" '.devices[][] | select(.udid==$u) | .name' 2>/dev/null)"
    echo
    echo "| Prova | Esito | Tempo |"
    echo "|---|---|---|"
    printf '%s\n' "${RIEPILOGO[@]}"
    echo
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

if [ ${#FALLITE[@]} -gt 0 ]; then
    echo "::error::Prove iOS fallite: ${FALLITE[*]}"
    exit 1
fi
echo "Tutte le prove iOS sono riuscite"
