#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=${1:-/etc/wireguard}
mkdir -p "$OUT_DIR"
umask 077
if [ ! -f "$OUT_DIR/privatekey" ]; then
  wg genkey | tee "$OUT_DIR/privatekey" | wg pubkey > "$OUT_DIR/publickey"
  echo "Generated keys in $OUT_DIR"
else
  echo "Keys already exist in $OUT_DIR"
fi

echo "Public key:"
cat "$OUT_DIR/publickey"
