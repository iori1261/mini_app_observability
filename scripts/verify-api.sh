#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

request() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  echo
  echo "==> ${method} ${path}"
  if [[ -n "${body}" ]]; then
    curl -sS -D - -o /tmp/nr-verify-body.json \
      -X "${method}" \
      -H "content-type: application/json" \
      -H "x-client-platform: script" \
      -H "x-client-action: verify" \
      -d "${body}" \
      "${BASE_URL}${path}"
  else
    curl -sS -D - -o /tmp/nr-verify-body.json \
      -X "${method}" \
      -H "x-client-platform: script" \
      -H "x-client-action: verify" \
      "${BASE_URL}${path}"
  fi
  echo
  python3 -m json.tool /tmp/nr-verify-body.json
}

request GET /health
ORDER_JSON="$(curl -sS -X POST "${BASE_URL}/orders" -H "content-type: application/json" -d '{"sku":"demo-item","quantity":1}')"
echo
echo "==> created order"
python3 -m json.tool <<<"${ORDER_JSON}"
ORDER_ID="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["id"])' <<<"${ORDER_JSON}")"
request GET "/orders/${ORDER_ID}"
request POST /orders/slow '{"sku":"slow-item","quantity":1}'
request POST /chaos/error
request POST /chaos/dependency '{"sku":"fail-item","quantity":1}'
echo
echo "API verification finished"
