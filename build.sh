#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/FS25_Src"
OUT_DIR="$SCRIPT_DIR/dist"
ZIP_PATH="$OUT_DIR/FS25_LeasingExtension.zip"

if [ ! -d "$SRC_DIR" ]; then
  echo "Missing source directory: $SRC_DIR" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -f "$ZIP_PATH"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/LeasingExtension-staging.XXXXXX")"
cp -R "$SRC_DIR"/. "$STAGING_DIR/"

(zip -r "$ZIP_PATH" . -x '*.DS_Store' -x '*.bak' -x '*.log' >/dev/null) || {
  cd "$STAGING_DIR" && zip -r "$ZIP_PATH" . -x '*.DS_Store' -x '*.bak' -x '*.log' >/dev/null
}

rm -rf "$STAGING_DIR"

echo "Created: $ZIP_PATH"
