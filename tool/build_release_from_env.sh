#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy .env.example to .env first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${API_BASE_URL:?API_BASE_URL must be set in $ENV_FILE}"

flutter build apk \
  --release \
  --flavor full \
  --dart-define=API_BASE_URL="$API_BASE_URL"
