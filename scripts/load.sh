#!/usr/bin/env bash
# New Relic のグラフを動かすための負荷スクリプト。
# 1 回だけリクエストしてもエラー率やスループットは読めないので、まとめて送る。
#
#   ./scripts/load.sh              60 件を正常系だけで送る
#   ./scripts/load.sh 100          件数を変える
#   ./scripts/load.sh 100 30       100 件のうち約 30% を失敗させる
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
TOTAL="${1:-60}"
ERROR_PERCENT="${2:-0}"

if ! curl -sS -m 3 -o /dev/null "${BASE_URL}/health"; then
  echo "API に接続できません: ${BASE_URL}" >&2
  echo "先に docker compose up -d を実行してください。" >&2
  exit 1
fi

echo "送信先 : ${BASE_URL}"
echo "件数   : ${TOTAL}"
echo "失敗率 : 約 ${ERROR_PERCENT}%"
echo

post() {
  local action="$1" path="$2" body="${3:-}"
  local args=(-sS -o /dev/null -w '%{http_code}'
    -X POST
    -H 'content-type: application/json'
    -H 'x-client-platform: script'
    -H "x-client-action: ${action}")

  if [[ -n "${body}" ]]; then
    args+=(-d "${body}")
  fi

  curl "${args[@]}" "${BASE_URL}${path}"
}

get() {
  curl -sS -o /dev/null -w '%{http_code}' \
    -H 'x-client-platform: script' \
    -H "x-client-action: $1" \
    "${BASE_URL}$2"
}

success=0
failure=0
started=$(date +%s)

for ((i = 1; i <= TOTAL; i++)); do
  # 0〜99 の値を作り、ERROR_PERCENT 未満なら失敗系を送る。
  bucket=$((RANDOM % 100))

  if ((bucket < ERROR_PERCENT)); then
    if ((bucket % 2 == 0)); then
      status="$(post chaos_error /chaos/error)"
    else
      status="$(post chaos_dependency /chaos/dependency '{"sku":"fail-item","quantity":1}')"
    fi
  else
    case $((i % 3)) in
      0) status="$(get health /health)" ;;
      1) status="$(post create_order /orders '{"sku":"demo-item","quantity":1}')" ;;
      *) status="$(post create_order /orders '{"sku":"bulk-item","quantity":2}')" ;;
    esac
  fi

  if [[ "${status}" =~ ^2 ]]; then
    success=$((success + 1))
  else
    failure=$((failure + 1))
  fi

  printf '\r進捗 %d/%d  成功 %d  失敗 %d' "${i}" "${TOTAL}" "${success}" "${failure}"
done

elapsed=$(($(date +%s) - started))
rate=0
if ((TOTAL > 0)); then
  rate=$((failure * 100 / TOTAL))
fi

echo
echo
echo "完了: ${TOTAL} 件 / ${elapsed} 秒"
echo "エラー率: ${rate}%"
echo
echo "New Relic の APM & Services → mini-app-api を開き、"
echo "右上の時間範囲を Last 30 minutes にして Throughput と Error rate を見てください。"
echo "反映には 1〜3 分かかります。"
