#!/usr/bin/env bash
# Istantanee di Prisma nel simulatore iOS con `simctl io screenshot` (fedele: vetro, ombre, barre).
#
# Uso: Supporto/iOS/istantanee.sh <udid> <cartella uscita> [elenco scene]
#   Crea <cartella uscita>/chiaro/*.png e <cartella uscita>/scuro/*.png.
#   [elenco scene]: facoltativo, nomi separati da virgole passati all'app così come sono.
#
# Sincronizzazione a file tra app e script (un solo avvio per aspetto, nessun riavvio per scena):
#   1. lo script avvia Prisma con --istantanee-ios [elenco];
#   2. per ogni scena l'app la mostra, aspetta che il disegno si fermi e scrive (in modo atomico)
#      Documents/scena-pronta.txt con il nome della scena (es. «1-benvenuto»);
#   3. lo script legge il nome, cancella scena-pronta.txt, scatta <nome>.png e crea
#      Documents/scatto-fatto.txt;
#   4. l'app aspetta scatto-fatto.txt, lo cancella e passa alla scena successiva;
#   5. alla fine l'app scrive Documents/esito-istantanee-ios.txt («OK» o «ERRORE …») ed esce.
# Prisma resta sull'aspetto «automatico»: chiaro e scuro li sceglie `simctl ui appearance`.
set -o pipefail

if [ $# -lt 2 ]; then
    echo "Uso: $0 <udid> <cartella uscita> [elenco scene]" >&2
    exit 2
fi

UDID="$1"
USCITA="$2"
ELENCO="${3:-}"
BID="${PRISMA_BID:-local.prisma}"
ATTESA_PRIMA="${PRISMA_ATTESA_PRIMA:-180}"   # secondi per la prima scena (primo avvio, dati di prova)
ATTESA_SCENA="${PRISMA_ATTESA_SCENA:-60}"    # secondi per ciascuna delle altre
MAX_SCENE=200

DATI="$(xcrun simctl get_app_container "$UDID" "$BID" data)" || {
    echo "::error::Contenitore dati di $BID non trovato: l'app è installata?"
    exit 1
}
DOC="$DATI/Documents"
mkdir -p "$DOC"

# Barra di stato fissa: le istantanee di due build si confrontano senza differenze inutili
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 || true

ERRORI=0

# aspetta_file <file> <secondi> <pid>: 0 se il file compare, 1 se scade il tempo o l'app esce
aspetta_file() {
    local file="$1" limite="$2" pid="$3" inizio=$SECONDS
    while [ $((SECONDS - inizio)) -lt "$limite" ]; do
        [ -s "$file" ] && return 0
        # L'app ha finito (o si è chiusa): il file non arriverà più
        [ -f "$DOC/esito-istantanee-ios.txt" ] && return 1
        kill -0 "$pid" 2>/dev/null || { [ -s "$file" ] && return 0; return 1; }
        sleep 0.3
    done
    return 1
}

scatta_aspetto() {
    local aspetto="$1" cartella="$2"
    # Il registro dell'app resta fuori dalle anteprime pubblicate
    local registro="${RUNNER_TEMP:-/tmp}/istantanee-$UDID-$aspetto.log"
    mkdir -p "$cartella"
    rm -f "$DOC/scena-pronta.txt" "$DOC/scatto-fatto.txt" "$DOC/esito-istantanee-ios.txt"

    xcrun simctl ui "$UDID" appearance "$aspetto"
    sleep 1

    local argomenti=(--istantanee-ios)
    [ -n "$ELENCO" ] && argomenti+=("$ELENCO")

    # In background con la console: l'uscita dell'app finisce nel registro (utile se si chiude)
    xcrun simctl launch --console-pty --terminate-running-process "$UDID" "$BID" "${argomenti[@]}" \
        < /dev/null > "$registro" 2>&1 &
    local pid=$!

    local n=0 attesa="$ATTESA_PRIMA"
    while [ "$n" -lt "$MAX_SCENE" ]; do
        if ! aspetta_file "$DOC/scena-pronta.txt" "$attesa" "$pid"; then
            break
        fi
        local nome
        nome="$(head -1 "$DOC/scena-pronta.txt" | tr -d '\r' | tr -c 'A-Za-z0-9._-' '_' | sed 's/_*$//')"
        rm -f "$DOC/scena-pronta.txt"
        [ -n "$nome" ] || nome="scena-$n"
        if xcrun simctl io "$UDID" screenshot --type=png "$cartella/$nome.png" > /dev/null 2>&1; then
            echo "  $aspetto/$nome.png"
        else
            echo "::warning::Scatto non riuscito: $aspetto/$nome"
            ERRORI=$((ERRORI + 1))
        fi
        echo "$nome" > "$DOC/scatto-fatto.txt"
        n=$((n + 1))
        attesa="$ATTESA_SCENA"
    done

    # L'app scrive l'esito ed esce; se resta appesa la si chiude
    local inizio=$SECONDS
    while kill -0 "$pid" 2>/dev/null && [ $((SECONDS - inizio)) -lt 30 ]; do sleep 0.5; done
    if kill -0 "$pid" 2>/dev/null; then
        xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
        kill "$pid" 2>/dev/null || true
    fi
    wait "$pid" 2>/dev/null

    local esito="$DOC/esito-istantanee-ios.txt"
    if [ "$n" -gt 0 ] && [ -f "$esito" ] && head -1 "$esito" | grep -q '^OK'; then
        echo "Istantanee $aspetto: $n scene"
    else
        echo "::error::Istantanee $aspetto non riuscite ($n scene scattate): $(head -c 400 "$esito" 2>/dev/null || echo 'nessun esito scritto')"
        echo "Ultime righe dell'app:"
        tail -40 "$registro" || true
        ERRORI=$((ERRORI + 1))
    fi
}

mkdir -p "$USCITA"
scatta_aspetto light "$USCITA/chiaro"
scatta_aspetto dark "$USCITA/scuro"
xcrun simctl ui "$UDID" appearance light || true
xcrun simctl status_bar "$UDID" clear || true

ls -la "$USCITA" "$USCITA/chiaro" "$USCITA/scuro" 2>/dev/null || true
[ "$ERRORI" = 0 ] || exit 1
