#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
  customer) port=8301;; retailer) port=8302;; rider) port=8303;; admin) port=8304;;
  *) echo "Usage: bash scripts/run_app.sh {customer|retailer|rider|admin}" >&2; exit 2;;
esac
if [[ ! -f "$root/.env" ]]; then
  echo "Copy .env.example to .env first." >&2; exit 1
fi
cd "$root/apps/$1"
"${FLUTTER_BIN:-flutter}" pub get
exec "${FLUTTER_BIN:-flutter}" run -d chrome --web-port="$port" --dart-define-from-file="$root/.env"
