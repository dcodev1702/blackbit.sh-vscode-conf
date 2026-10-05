#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.blackbit"
LOADER_SOURCE="$SOURCE_DIR/.blackbit/load-blackbit-key.sh"
LOADER_TARGET="$TARGET_DIR/load-blackbit-key.sh"
ENV_FILE="$SOURCE_DIR/.env"

if [[ ! -f "$LOADER_SOURCE" ]]; then
    echo "ERROR: Loader source not found: $LOADER_SOURCE" >&2
    exit 1
fi

echo "Installing BlackBit credential helper..."
echo "Target: $LOADER_TARGET"

mkdir -p "$TARGET_DIR"
chmod 700 "$TARGET_DIR"

install -m 700 "$LOADER_SOURCE" "$LOADER_TARGET"

if [[ -f "$ENV_FILE" ]]; then
    chmod 600 "$ENV_FILE"
fi

echo
echo "Installed:"
ls -ld "$TARGET_DIR"
ls -l "$LOADER_TARGET"

echo
if [[ -f "$ENV_FILE" ]]; then
    echo "API key file (contents not read or shown):"
    ls -l "$ENV_FILE"
else
    echo "No .env found. Create $ENV_FILE containing:"
    echo
    echo "  BLACKBIT_API_KEY='your-blackbit-api-key'"
    echo
    echo "then run: chmod 600 \"$ENV_FILE\""
fi

if [[ "$ENV_FILE" != "$HOME/BlackBit-VSCode-Ubuntu/.env" ]]; then
    echo
    echo "This package is not in ~/BlackBit-VSCode-Ubuntu, so point the loader at it:"
    echo
    echo "  export BLACKBIT_ENV_FILE=\"$ENV_FILE\""
fi

echo
echo "Load the key from .env into the current terminal with:"
echo
echo "  source ~/.blackbit/load-blackbit-key.sh"
echo
echo "Then validate the BlackBit models with:"
echo
echo "  ./test-blackbit-models.sh"
