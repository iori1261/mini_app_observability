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

New Relic の各画面の役割、英語の意味、このプロダクトとの対応、勉強する順序は [docs/new-relic-sre.md](docs/new-relic-sre.md) にまとめています。

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

| ボタン | 呼び出す API | 確認場所 |
|---|---|---|
| ヘルスチェック | `GET /health` | Mobile HTTP、APM Transaction |
| 注文を作成 | `POST /orders` → `POST /charge` | Distributed tracing、サービスマップ |
| 注文を取得 | `GET /orders/:id` | カスタム属性 `request.id` |
| 遅い注文 | `POST /orders/slow` | Mobile duration、APM レイテンシ |
| サーバーエラー | `POST /chaos/error` | Errors inbox、error rate |
| 決済依存の失敗 | `POST /chaos/dependency` | payments の失敗 span |

画面上にも `HTTP` / `時間` / `request.id` / レスポンス本文が出ます。同じ `request.id` で Mobile と APM を突き合わせられます。

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
scripts         API の curl 確認
```
