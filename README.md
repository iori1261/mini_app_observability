# mini_app_observability

Swift の小さな検証アプリから、Docker 上の API を叩いて New Relic の Mobile / APM / Logs / Distributed Tracing を学ぶためのリポジトリです。

iOS アプリ自体は Docker では動きません。Docker は API と決済モックだけを動かします。シミュレータから `http://127.0.0.1:8080` へ接続します。

```text
iOS アプリ（Xcode / Simulator）
        │  ボタンを押す
        ▼
   API :8080   （APM: mini-app-api）
        │
        ▼
 payments :4000（APM: mini-app-payments）
        │
        ▼
     New Relic
```

## 必要なもの

- Docker Desktop
- Xcode 15 以降（iOS 17）
- New Relic 無料アカウント（後からでも可）

キーは 2 種類あります。混ぜないでください。

| 用途 | 名前 | 設定場所 |
|---|---|---|
| バックエンド APM / Logs | License Key | `.env` の `NEW_RELIC_LICENSE_KEY` |
| iOS Mobile | Application Token | `ios/MiniAppObservability/AppConfig.swift` |

License Key が空でも API は起動します。Application Token が空でもボタンからの API 確認はできます。

New Relic が初めてなら [docs/first-run.md](docs/first-run.md) から読んでください。押す順番と見る画面だけを並べた 30 分のハンズオンです。

各画面の役割、英語の意味、このプロダクトとの対応、勉強する順序は [docs/new-relic-sre.md](docs/new-relic-sre.md) にあります。

## 起動手順

### 1. API を Docker で起動する

```bash
cp .env.example .env
# New Relic を使う場合は .env に License Key を入れる
docker compose up --build
```

別ターミナルで疎通確認できます。

```bash
make verify
```

### 2. iOS アプリを開く

```bash
open ios/MiniAppObservability.xcodeproj
```

Signing の Team を自分の Apple ID に変更して、iPhone シミュレータで実行します。

実機で試す場合は、`AppConfig.swift` の URL を Mac の LAN IP に変えます。

```swift
static let apiBaseURL = URL(string: "http://192.168.1.12:8080")!
```

### 3. New Relic Mobile を入れる（任意）

1. New Relic で Mobile App を追加し、iOS の Application Token を発行する
2. Xcode の File > Add Package Dependencies で  
   `https://github.com/newrelic/newrelic-ios-agent-spm` を追加する
3. `AppConfig.swift` の `newRelicAppToken` にトークンを入れる
4. アプリを再起動する

エージェントは `AppDelegate` の先頭で起動します。`URLSession` の HTTP は自動計装されます。ボタン操作は Interaction / Breadcrumb / カスタムイベント `ButtonTap` としても送ります。

## ボタンと New Relic で見ること

アプリは 3 ステップに分かれています。ボタンを押すと、結果カードに **何が起きたか**、**New Relic のどの画面をどの順に開くか**、**そのまま貼れる NRQL** が出ます。

### STEP 1 画面の場所を覚える

| ボタン | 呼び出す API | 見る画面 |
|---|---|---|
| 動いているか確認する | `GET /health` | APM の Transactions |
| 注文する | `POST /orders` → `POST /charge` | Distributed tracing、Service map |
| 直前の注文を読む | `GET /orders/:id` | `request.id` で 1 件を追う |

### STEP 2 わざと壊して違いを見る

| ボタン | 呼び出す API | 崩れる指標 |
|---|---|---|
| わざと遅くする | `POST /orders/slow` | Latency のみ。エラー率は上がらない |
| サーバー側を壊す | `POST /chaos/error` | Errors。原因は api の中 |
| 決済サービスを落とす | `POST /chaos/dependency` | Errors。原因は payments 側 |

### STEP 3 グラフを動かす

1 回押しただけではエラー率もスループットも読めません。まとめて送ります。

| ボタン | 内容 | 見る指標 |
|---|---|---|
| 正常な負荷を流す | 60 件、失敗なし | Throughput が上がり、Error rate は 0% |
| エラーを混ぜた負荷を流す | 40 件、約 30% が失敗 | Error rate が 30% 前後 |

ターミナルでも同じことができます。

```bash
make load          # 60 件、正常系のみ
make load-errors   # 100 件、約 30% を失敗させる

./scripts/load.sh 200 10   # 件数と失敗率を指定する
```

手元に出る「エラー率」と、New Relic の Error rate が同じ数字になるか見比べてください。反映まで 1〜3 分かかります。画面右上の時間範囲は **Last 30 minutes** にします。

## NRQL の例

```sql
SELECT average(duration) FROM Transaction
WHERE appName = 'mini-app-api'
FACET name SINCE 30 minutes ago
```

```sql
SELECT count(*) FROM Transaction
WHERE error IS true AND appName = 'mini-app-api'
FACET request.uri SINCE 1 hour ago
```

```sql
SELECT count(*) FROM ButtonTap
FACET name, success SINCE 1 hour ago
```

## 無料枠で気をつけること

- 月 100 GB までの取り込み。このアプリ程度なら通常は問題になりません
- デバッグログの全量送信はしない
- License Key と Application Token はコミットしない

## ディレクトリ

```text
apps/backend    Docker で動く API と payments
ios             SwiftUI 検証アプリ
scripts         API の疎通確認（verify-api.sh）と負荷生成（load.sh）
docs            New Relic の画面ガイド
```
