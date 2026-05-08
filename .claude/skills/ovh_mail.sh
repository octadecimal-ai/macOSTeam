#!/usr/bin/env bash
# Skill: OVH Mail — tworzenie i usuwanie skrzynek e-mail przez OVH API v1.
#
# Wywołanie:
#   ovh_mail.sh create <email> <password> [quota_mb]
#   ovh_mail.sh delete <email>
#   ovh_mail.sh list <domain>
#   ovh_mail.sh info <email>
#
# Zmienne środowiskowe (lub pobierane z Bitwarden SM przez bws_helper.sh):
#   OVH_APP_KEY       — klucz aplikacji OVH
#   OVH_APP_SECRET    — sekret aplikacji OVH
#   OVH_CONSUMER_KEY  — consumer key (po autoryzacji OAuth)
#   OVH_ENDPOINT      — endpoint API (domyślnie: ovh-eu)
#
# Przykład:
#   OVH_APP_KEY=xxx OVH_APP_SECRET=yyy OVH_CONSUMER_KEY=zzz \
#     ovh_mail.sh create bigbrother@octadecimal.pl "HasloTymczasowe123!" 2048

set -euo pipefail

ACTION="${1:-}"
TARGET="${2:-}"
ARG3="${3:-}"
ARG4="${4:-}"

OVH_ENDPOINT="${OVH_ENDPOINT:-ovh-eu}"
OVH_API_BASE="https://eu.api.ovh.com/1.0"

# --- Sprawdzenie zależności ---
if ! command -v curl &>/dev/null; then
  echo "Błąd: curl jest wymagany" >&2
  exit 1
fi
if ! command -v python3 &>/dev/null; then
  echo "Błąd: python3 jest wymagany" >&2
  exit 1
fi

# --- Walidacja credentiali ---
check_credentials() {
  if [[ -z "${OVH_APP_KEY:-}" || -z "${OVH_APP_SECRET:-}" || -z "${OVH_CONSUMER_KEY:-}" ]]; then
    echo "Błąd: wymagane zmienne OVH_APP_KEY, OVH_APP_SECRET, OVH_CONSUMER_KEY" >&2
    echo "Ustaw je w środowisku lub użyj bws_helper.sh do pobrania z Bitwarden SM" >&2
    exit 1
  fi
}

# --- Podpis OVH API (SHA1 HMAC) ---
ovh_request() {
  local method="$1"
  local path="$2"
  local body="${3:-}"

  local timestamp
  timestamp=$(python3 -c "import time; print(int(time.time()))")

  local signature_raw="${OVH_APP_SECRET}+${OVH_CONSUMER_KEY}+${method}+${OVH_API_BASE}${path}+${body}+${timestamp}"
  local signature
  signature=$(echo -n "$signature_raw" | python3 -c "
import sys, hashlib
data = sys.stdin.read()
print('\$1\$' + hashlib.sha1(data.encode()).hexdigest())
")

  local curl_args=(
    -s -S
    -H "X-Ovh-Application: ${OVH_APP_KEY}"
    -H "X-Ovh-Consumer: ${OVH_CONSUMER_KEY}"
    -H "X-Ovh-Signature: ${signature}"
    -H "X-Ovh-Timestamp: ${timestamp}"
    -H "Content-Type: application/json"
    -X "$method"
  )

  if [[ -n "$body" ]]; then
    curl_args+=(-d "$body")
  fi

  curl "${curl_args[@]}" "${OVH_API_BASE}${path}"
}

# --- Wyodrębnij domenę i lokalną część ---
parse_email() {
  local email="$1"
  if [[ "$email" != *@* ]]; then
    echo "Błąd: '$email' nie jest poprawnym adresem e-mail" >&2
    exit 1
  fi
  MAIL_LOCAL="${email%%@*}"
  MAIL_DOMAIN="${email##*@}"
}

# --- Akcje ---
case "$ACTION" in
  create)
    check_credentials
    if [[ -z "$TARGET" || -z "$ARG3" ]]; then
      echo "Użycie: $0 create <email> <hasło> [quota_mb]" >&2
      exit 1
    fi
    parse_email "$TARGET"
    local_part="$MAIL_LOCAL"
    domain="$MAIL_DOMAIN"
    password="$ARG3"
    quota="${ARG4:-1024}"

    body=$(python3 -c "
import json
print(json.dumps({
    'accountName': '${local_part}',
    'password': '${password}',
    'size': int('${quota}') * 1024 * 1024
}))
")

    response=$(ovh_request POST "/email/domain/${domain}/account" "$body")

    if echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'message' not in d else 1)" 2>/dev/null; then
      echo "OK: skrzynka '${TARGET}' utworzona [quota: ${quota} MB]"
    else
      error=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message', d))" 2>/dev/null || echo "$response")
      echo "Błąd API: $error" >&2
      exit 1
    fi
    ;;

  delete)
    check_credentials
    if [[ -z "$TARGET" ]]; then
      echo "Użycie: $0 delete <email>" >&2
      exit 1
    fi
    parse_email "$TARGET"
    local_part="$MAIL_LOCAL"
    domain="$MAIL_DOMAIN"

    response=$(ovh_request DELETE "/email/domain/${domain}/account/${local_part}")

    if echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'message' not in d else 1)" 2>/dev/null; then
      echo "OK: skrzynka '${TARGET}' usunięta"
    else
      error=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message', d))" 2>/dev/null || echo "$response")
      echo "Błąd API: $error" >&2
      exit 1
    fi
    ;;

  list)
    check_credentials
    if [[ -z "$TARGET" ]]; then
      echo "Użycie: $0 list <domena>" >&2
      exit 1
    fi
    domain="$TARGET"

    response=$(ovh_request GET "/email/domain/${domain}/account")
    echo "=== Skrzynki dla ${domain} ==="
    echo "$response" | python3 -c "
import sys, json
accounts = json.load(sys.stdin)
if isinstance(accounts, list):
    for a in sorted(accounts):
        print(f'  {a}@${domain}')
else:
    print(accounts)
"
    ;;

  info)
    check_credentials
    if [[ -z "$TARGET" ]]; then
      echo "Użycie: $0 info <email>" >&2
      exit 1
    fi
    parse_email "$TARGET"
    local_part="$MAIL_LOCAL"
    domain="$MAIL_DOMAIN"

    response=$(ovh_request GET "/email/domain/${domain}/account/${local_part}")
    echo "$response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'message' in d:
    print('Błąd:', d['message'])
else:
    print(f'Skrzynka: {d.get(\"accountName\", \"?\")}@${domain}')
    size_mb = d.get('size', 0) // (1024*1024)
    used_mb = d.get('currentUsage', 0) // (1024*1024)
    print(f'Quota:    {used_mb} MB / {size_mb} MB')
    print(f'Status:   {d.get(\"state\", \"?\")}')
"
    ;;

  *)
    echo "Użycie: $0 <create|delete|list|info> ..." >&2
    exit 1
    ;;
esac
