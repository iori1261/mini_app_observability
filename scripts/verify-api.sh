#!/usr/bin/env bash
# 各シナリオを 1 回ずつ叩いて、API が期待どおり動くか確認する。
# New Relic に繋ぐ前の疎通確認にも使える。
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

# 固定パスだと他のユーザーやプロセスと衝突するので、専用の一時ファイルを作る。
BODY_FILE="$(mktemp "${TMPDIR:-/tmp}/nr-verify-body.XXXXXX")"
trap 'rm -f "${BODY_FILE}"' EXIT

request() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -D - -o "${BODY_FILE}"
    -X "${method}"
    -H 'x-client-platform: script'
    -H 'x-client-action: verify')

  if [[ -n "${body}" ]]; then
    args+=(-H 'content-type: application/json' -d "${body}")
  fi

  echo
  echo "==> ${method} ${path}"
  curl "${args[@]}" "${BASE_URL}${path}"
  echo
  python3 -m json.tool "${BODY_FILE}"
}

request GET /health

ORDER_JSON="$(curl -sS -X POST "${BASE_URL}/orders" \
  -H 'content-type: application/json' \
  -d '{"sku":"demo-item","quantity":1}')"
echo
echo "==> created order"
python3 -m json.tool <<<"${ORDER_JSON}"

ORDER_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<<"${ORDER_JSON}")"
request GET "/orders/${ORDER_ID}"
request POST /orders/slow '{"sku":"slow-item","quantity":1}'
request POST /chaos/error
request POST /chaos/dependency '{"sku":"fail-item","quantity":1}'

echo
echo "API verification finished"
