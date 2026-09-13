# New Relic 画面ガイド

このドキュメントは、この検証アプリ（`newrelic-observability-lab`）と New Relic の各画面を対応づけたものです。  
画面の英語表記と意味を併記します。日付ごとの学習計画ではなく、**何をどの順で身につけるか** を書きます。

対象読者: New Relic で **エラー率** と **スケーリング（負荷に対する余裕）** を見られるようになりたい新卒 SRE。

まだ一度も New Relic の画面を触っていないなら、先に [first-run.md](first-run.md) を手を動かしながら読んでください。こちらは全体像と順序の整理用です。

---

## 1. このプロダクトが New Relic 上で何になるか

実世界のプロダクトでは、ユーザー操作 → API → 決済や DB など複数のサービスに分かれます。このリポジトリも同じ形です。

```text
ユーザー操作（iOS のボタン）
    → mini-app-api        注文 API（このプロダクトの本体）
        → mini-app-payments   決済の依存サービス（モック）
```

| プロダクト上の実体 | New Relic 上の名前 | 画面の入口 |
|---|---|---|
| Docker の API コンテナ | `mini-app-api` | APM & Services |
| Docker の payments コンテナ | `mini-app-payments` | APM & Services |
| iOS アプリ（トークン設定時のみ） | 自分で付けた Mobile アプリ名 | Mobile |
| 1 回の HTTP リクエスト | Transaction（トランザクション） | APM の Transactions |
| API から payments への呼び出し | Span（スパン） / External call | Distributed tracing |
| アプリが出した JSON ログ | Log（ログ） | Logs |
| 例外や 5xx | Error（エラー） | Errors inbox / APM Errors |

New Relic は「アプリを手動登録する場所」ではありません。エージェントがデータを送ると、上の名前が自動で現れます。

---

## 2. SRE が最初に覚えるべき見方（Golden Signals）

現場で障害やスケールを判断するときは、まず次の 4 つを見ます。Google SRE の **Golden Signals**（ゴールデンシグナル / 黄金信号）です。

| 英語 | 読み | 意味 | このプロダクトで再現する方法 | New Relic で見る場所 |
|---|---|---|---|---|
| Latency | レイテンシ | 遅さ。1 リクエストに何秒かかるか | 「遅い注文」ボタン / `POST /orders/slow` | APM Summary の Response time、Transactions |
| Traffic | トラフィック | 量。今どれだけリクエストが来ているか | ボタンを連打する、`verify-api.sh` を繰り返す | APM Summary の Throughput |
| Errors | エラー | 失敗の割合 | 「サーバーエラー」「決済依存の失敗」 | Summary の Error rate、Errors inbox |
| Saturation | サチュレーション | 飽和。CPU・メモリ・スレッドなど「余裕がどれだけ残っているか」 | この検証アプリ単体では出にくい。実務の本番で重要 | Infrastructure、APM の Instances / Hosts |

**エラー率** は Errors ÷ Traffic です。エラー件数だけ見ると判断を誤ります。リクエストが増えただけなのか、本当に壊れ始めたのかを Throughput とセットで見ます。

**スケーリング** は「Traffic が増えたとき、Latency と Saturation が悪化していないか」です。エラー率が低くても、レスポンスが伸びていればスケール不足のサインです。

---

## 3. 左メニュー全体（英語とその意味）

ログイン直後の左側です。UI の翻訳で表記が揺れることがあります（例: APM & Services / APM & Serviços）。英語の意味で覚えてください。

| 英語（画面） | 意味 | 役割 | このプロダクトとの紐づけ | 今勉強するか |
|---|---|---|---|---|
| **APM & Services** | Application Performance Monitoring / アプリケーション性能監視 | 各サービスの遅さ・量・エラーを見る本丸 | `mini-app-api` と `mini-app-payments` が並ぶ | **必須** |
| **Errors inbox** | エラー受信箱 | 例外や失敗を一覧し、未対応エラーを潰す | `/chaos/error` や決済失敗がここに出る | **必須** |
| **Logs** | ログ | アプリが出した文字列を検索する | `http_request` / `order_created` / `chaos_server_error` | **必須** |
| **Traces** または **Distributed tracing** | 分散トレーシング | 1 リクエストがサービスを横断する様子 | 注文作成で api → payments | **必須** |
| **Query your data** | データを問い合わせる | NRQL で自分で数字を出す | エラー率、P95、エンドポイント別件数 | **必須** |
| **Dashboards** | ダッシュボード | よく見るグラフを 1 画面に固定する | 自作の「エラー率とレイテンシ」ボード | 必須の次 |
| **Alerts** | アラート | しきい値を超えたら通知する | エラー率 5% 超、P95 1 秒超など | 必須の次 |
| **Infrastructure** | インフラストラクチャ | ホスト / コンテナの CPU・メモリ・ディスク | このリポジトリでは Infra エージェント未導入。実務のスケール判断で使う | 後で |
| **Kubernetes** | クバネティス | クラスタ・Pod・Deployment の状態 | このリポジトリには無い。本番が k8s なら必須 | 後で |
| **Mobile** | モバイル | スマホアプリのクラッシュ、画面操作、HTTP | iOS に Application Token を入れたときだけ | 後で |
| **Browser** | ブラウザ | Web フロントのページ表示速度 | このリポジトリには Web 画面が無い | 今は不要 |
| **Synthetic monitoring** | 外形監視 | 外から URL を定期的に叩いて死活を見る | `/health` を監視対象にできる。無料枠は月 500 回 | 後で |
| **Integrations & Agents** | 連携とエージェント | 新しいデータソースを入れる案内 | すでに計装済みなので普段は使わない | 今は不要 |
| **All capabilities** | すべての機能 | New Relic 全機能の一覧 | 迷子になったときの目次 | 参照用 |
| **Catalogs** | カタログ | サービスやスコアカードの目録 | この検証規模では使わない | 今は不要 |

---

## 4. APM でサービスを開いたあとの各画面

**APM & Services** で `mini-app-api` をクリックすると、そのサービスの中に入ります。SRE の日常の大半はここです。

### Summary（サマリー / 概要）

| 英語 | 意味 |
|---|---|
| Summary | 概要。最初に開く総合ページ |
| Response time | 応答時間。平均やパーセンタイルで遅さを見る |
| Throughput | スループット。1 分あたり何件処理したか（rpm = requests per minute） |
| Error rate | エラー率。失敗したリクエストの割合 |
| Apdex | アプリの満足度スコア。しきい値より速い割合 |
| Web transactions | ブラウザやアプリから来た HTTP の処理 |
| Non-web transactions | バッチやバックグラウンド処理。このアプリではほぼ出ない |

**役割:** 「今、遅いか・壊れているか・量は多いか」を 10 秒で判断する。  
**このプロダクト:** 通常注文を押すと Throughput が上がる。遅い注文で Response time が伸びる。サーバーエラーで Error rate が上がる。

実務でも障害初動は Summary です。詳細に潜る前に、4 信号のどれが崩れているかを決めます。

### Transactions（トランザクション）

| 英語 | 意味 |
|---|---|
| Transaction | 1 つの処理単位。このアプリでは 1 HTTP リクエスト |
| Transaction name | 処理名。例: `WebTransaction/Expressjs/POST//orders` |
| Most time consuming | 合計で一番時間を食っている処理 |
| Slowest average | 1 件あたりが一番遅い処理 |
| Throughput | その Transaction の回数 |
| Trace | その 1 回分の詳細記録 |

**役割:** 「どの API が遅いか / 失敗しているか」を特定する。  
**このプロダクト:**

| 操作 | だいたいの Transaction |
|---|---|
| ヘルスチェック | `GET /health` |
| 注文を作成 | `POST /orders` |
| 注文を取得 | `GET /orders/:id` |
| 遅い注文 | `POST /orders/slow` |
| サーバーエラー | `POST /chaos/error` |
| 決済依存の失敗 | `POST /chaos/dependency` |

SRE は「サービス全体が遅い」ではなく、「`/orders/slow` だけ遅い」と言えるようになります。スケール判断も、全体平均ではなく **エンドポイント別** で見ます。

### Distributed tracing（分散トレーシング）

| 英語 | 意味 |
|---|---|
| Trace | 1 リクエスト全体の旅路 |
| Span | その旅路の 1 区間（api 内の処理、payments 呼び出しなど） |
| Root span | 最初の区間。通常は api が受けた HTTP |
| Duration | その区間にかかった時間 |
| Error span | 失敗した区間 |
| Service map | サービス同士の呼び出し関係図 |

**役割:** 「遅さや失敗が自前のコードか、依存先か」を切り分ける。  
**このプロダクト:**

- 「注文を作成」→ `mini-app-api` の span の下に `mini-app-payments` の `/charge` が出る
- 「決済依存の失敗」→ payments 側が 503、api が 502 で終わる
- 「遅い注文」→ api 側の span が約 2 秒。payments は普通

実務のスケーリングでは、「自サービスを増やせばよいか、下流（決済・DB）がボトルネックか」をここで決めます。下流が飽和しているのに api だけ増やすと、エラーが増えることがあります。

### Errors / Errors inbox（エラー）

| 英語 | 意味 |
|---|---|
| Errors inbox | エラーをチケットのように集約した受信箱 |
| Error rate | エラー率 |
| Exception | 例外。コードが throw したもの |
| Stack trace | スタックトレース。どの行で落ちたか |
| Fingerprint / Group | 同じ種類のエラーをまとめたグループ |
| Occurrence | そのエラーが何回起きたか |

**役割:** 「何のエラーが、どれくらい、いつから出ているか」を見る。  
**このプロダクト:**

- 「サーバーエラー」→ api の意図的な 500 / `intentional_server_error`
- 「決済依存の失敗」→ payments の 503 と、api の 502 `payment_failed`

件数ではなく **Error rate** を見る習慣を先につけます。デプロイ直後に率だけ跳ねたら、変更が原因である可能性が高いです。

### Logs（ログ）

| 英語 | 意味 |
|---|---|
| Logs | ログ本文の検索画面 |
| Logs in context | トレースやエラー画面から、同じリクエストのログへ飛ぶこと |
| Attribute | ログに付いた項目。`requestId`、`path`、`status` など |
| Query | 絞り込み条件 |

**役割:** APM の「遅い / 失敗」に対して、当時の詳細メッセージを読む。  
**このプロダクト:** ログは JSON です。画面の `request.id` と同じ値が `requestId` で入ります。

よく使う絞り込み:

- `requestId:（画面に出た ID）`
- `message:chaos_server_error`
- `path:/orders/slow`
- `service:mini-app-api`

APM → エラー → ログ、の順で辿れると、現場の初動と同じです。

### External services（外部サービス）

| 英語 | 意味 |
|---|---|
| External services | 自分のサービスが呼んでいる外の HTTP / gRPC |

**役割:** 依存先ごとの遅さとエラーを見る。  
**このプロダクト:** `mini-app-api` から見た `mini-app-payments` がここに相当します。  
スケール時は「外部依存の待ち時間」が Latency の大半を占めることがよくあります。

### Databases（データベース）

| 英語 | 意味 |
|---|---|
| Databases | DB クエリの回数と遅さ |

**役割:** N+1 や遅い SQL を見つける。  
**このプロダクト:** DB を使っていないので、この画面は空かほぼ出ません。実務ではスケールの本命になりやすいです。

### Service map（サービスマップ）

| 英語 | 意味 |
|---|---|
| Service map | サービス間の呼び出しを地図にしたもの |

**役割:** 依存関係の全体像。障害の影響範囲を説明するときに使う。  
**このプロダクト:** `mini-app-api` と `mini-app-payments` が線でつながります。

### Instances / Hosts / JVMs（インスタンス）

| 英語 | 意味 |
|---|---|
| Instance | そのサービスのプロセス 1 つ（コンテナ 1 つに近い） |
| Host | そのプロセスが乗っているマシン |
| Scale out | 台数を増やす水平スケール |
| Scale up | 1 台の CPU / メモリを増やす垂直スケール |

**役割:** 「何台で処理しているか」「特定の 1 台だけ悪いか」を見る。  
**このプロダクト:** Docker で api は 1 コンテナだけなので、インスタンスは 1 つです。  
実務のスケーリング判断は、Throughput が増えているのに Instance 数が足りず Latency / Saturation が悪化していないか、を見ます。

このリポジトリで Infrastructure を入れていなければ、CPU やメモリはここだけでは足りません。本番では Infra エージェントか Kubernetes 連携がセットになります。

---

## 5. ボタン操作と画面の対応

再現 → 画面で見つける、が勉強の基本動作です。

| アプリのボタン | 実際の呼び出し | 主に見る画面 | 期待する変化 |
|---|---|---|---|
| ヘルスチェック | `GET /health` | APM Transactions、（任意）Synthetics | 速く、エラーなし |
| 注文を作成 | `POST /orders` → `POST /charge` | Distributed tracing、Service map | 2 サービスにまたがる成功トレース |
| 注文を取得 | `GET /orders/:id` | Transactions、Logs の `requestId` | 作成した注文が読める |
| 遅い注文 | `POST /orders/slow`（2 秒待ち） | Summary の Response time、Transactions | Latency が悪化。Error rate は増えない |
| サーバーエラー | `POST /chaos/error` | Errors inbox、Error rate、Logs | 5xx と例外。Traffic は増える |
| 決済依存の失敗 | `POST /chaos/dependency` | Distributed tracing の Error span、External services | 失敗の責任が payments 側にある |

画面右上の時間範囲（**Since last 30 minutes** = 直近 30 分）を、操作した直後に合わせてください。古い時間帯を見ると「何も起きていない」ように見えます。

---

## 6. Query your data（NRQL）で見るべき指標

画面のグラフは、裏で NRQL（New Relic Query Language / ニューレリックの問い合わせ言語）が動いています。SRE はグラフを見るだけでなく、自分で問える必要があります。

| 英語 | 意味 |
|---|---|
| SELECT | 何を集計するか |
| FROM Transaction | トランザクションデータから |
| WHERE | 絞り込み |
| FACET | グループ分け（エンドポイント別など） |
| SINCE | いつから |
| percentile / P95 | 遅い側 5% のライン。平均より障害に敏感 |
| rate / percentage | 割合 |

エラー率（必須）:

```sql
SELECT percentage(count(*), WHERE error IS true) FROM Transaction
WHERE appName = 'mini-app-api'
SINCE 30 minutes ago
TIMESERIES
```

エンドポイント別の遅さ（必須）:

```sql
SELECT average(duration), percentile(duration, 95), count(*) FROM Transaction
WHERE appName = 'mini-app-api'
FACET name
SINCE 30 minutes ago
```

失敗している URI:

```sql
SELECT count(*) FROM Transaction
WHERE appName = 'mini-app-api' AND error IS true
FACET request.uri
SINCE 1 hour ago
```

特定リクエストの追跡（アプリ画面の `request.id` を使う）:

```sql
SELECT * FROM Transaction
WHERE request.id = 'ここに画面のID'
SINCE 1 hour ago
```

Traffic（スケールの「需要」）:

```sql
SELECT rate(count(*), 1 minute) FROM Transaction
WHERE appName = 'mini-app-api'
SINCE 1 hour ago
TIMESERIES
```

P95 は平均より重要です。平均は速いリクエストに引っ張られ、一部だけ極端に遅い状態を隠します。スケール不足はまず P95 / P99 に出ます。

---

## 7. 勉強する順序（段階）

Day 1、Day 2 のような日程ではなく、**前の段階ができてから次へ進む** 順序です。飛ばすと、画面は触れても判断できません。

### 段階 A — 地図を持つ

目的: New Relic のどこに、このプロダクトの何があるかを言える。

身につけること:

- 左メニューの英語と意味（このドキュメント 3 章）
- `mini-app-api` / `mini-app-payments` の区別
- ボタンと Transaction の対応（5 章）

できたかの基準:

- APM から目的のサービスを迷わず開ける
- 「注文を作成」がどのサービスを通るか、口頭で説明できる

### 段階 B — ゴールデンシグナルを読む

目的: エラー率とレイテンシと量を、Summary で読み取れる。

身につけること:

- Latency / Traffic / Errors の違い
- Error rate と Error count の違い
- 「遅い注文」と「サーバーエラー」で、崩れる信号が違うこと
- 時間範囲の合わせ方

できたかの基準:

- Summary を見て「今は量の問題か、遅さか、失敗か」を一文で言える
- エラー件数が多いだけでは「障害」と言わない

### 段階 C — 原因の切り分け

目的: どのエンドポイントか、自サービスか依存先かを特定できる。

身につけること:

- Transactions で遅い / 失敗している名前を特定する
- Distributed tracing で span を読む
- Errors inbox からログへ飛ぶ
- `request.id` で 1 リクエストを横断する

できたかの基準:

- 「決済依存の失敗」を、api のバグではなく payments の失敗だと説明できる
- 「遅い注文」を、payments ではなく api 内の待ちだと説明できる

### 段階 D — 自分で数字を出す

目的: 画面のプリセットに頼らず、NRQL でエラー率と P95 を出せる。

身につけること:

- `percentage`、`percentile`、`FACET`、`TIMESERIES`
- エンドポイント別とサービス全体の使い分け
- ダッシュボードにエラー率・P95・Throughput を 3 つ置く

できたかの基準:

- 何も見ずにエラー率の NRQL を書ける
- ダッシュボードだけで「平常 / 注意」を判断できる

### 段階 E — 気づける状態にする

目的: 見て発見するのではなく、閾値超過で気づく。

身につけること:

- Alerts の条件（Error rate、P95）
- 通知先（まずは自分のメールでよい）
- 誤報（ノイズ）と見逃しのトレードオフ
- Synthetics で `/health` を外から見る（任意）

できたかの基準:

- 「サーバーエラー」を連打するとアラートが発火する
- 発火条件を人に説明できる

### 段階 F — スケーリング判断（実務の本丸）

目的: 負荷が増えたときに、足すものを判断できる。

身につけること:

- Traffic 増に対する Latency / Error rate / Saturation の変化
- Instance 数と 1 台あたりの処理量
- 依存先（payments、DB、外部 API）が先に飽和していないか
- Scale out（台数）と Scale up（サイズ）の使い分け
- Kubernetes なら Pod CPU、HPA、Throttle、再起動
- Infrastructure の CPU / メモリ / ディスク / ネットワーク

この検証アプリで足りないもの:

- 本物の負荷（同時接続の増加）
- CPU・メモリのメトリクス（Infra 未導入）
- レプリカ数の変化

足りない部分は、職場のステージングで「負荷試験中の APM + Infra + k8s」を見せてもらうのが最短です。このアプリでは **判断の型** だけ先に固定します。

スケール判断の型:

1. Traffic は増えているか（需要）
2. Error rate は悪化しているか（壊れているか）
3. P95 Latency は悪化しているか（足りないか）
4. 遅いのはどの Transaction か
5. 自サービス内か、External / DB か
6. Saturation（CPU など）は天井近いか
7. 足すのは api の台数か、下流の容量か

### 段階 G — モバイルと外形監視（余裕があれば）

- Mobile: ユーザー端末側の失敗。API は成功なのにアプリだけ失敗、を見る
- Synthetics: ユーザーがいなくても `/health` で死活を見る
- Browser: このプロダクトには無い。Web 担当になったら学ぶ

SRE の本業は段階 B〜F です。G は担当プロダクトがモバイル / Web のときに足します。

---

## 8. 実務で画面を開いたときの問い

どの画面にいても、次の順で答えます。これがスキルの本体です。

1. **今、何が起きているか** — 遅い / 失敗 / 量が多い / 余裕が無い  
2. **いつからか** — デプロイ直後か、徐々か、突発か  
3. **どこか** — サービス名、Transaction 名、依存先  
4. **誰が困っているか** — 全ユーザーか、特定 API だけか  
5. **自分たちは何を足す / 戻すのか** — ロールバック、スケールアウト、依存先の確認  

英語の画面名を暗記すること自体が目的ではありません。画面は、この問いに答えるための道具です。

---

## 9. 用語集（画面でよく出る英語）

| 英語 | 意味 |
|---|---|
| Agent | アプリやホストに入れて、New Relic へデータを送るプログラム |
| APM | アプリケーション性能監視 |
| Apdex | 体感速度のスコア。T 秒以内なら満足、それ以上は我慢 / 不満 |
| Attribute | 付属情報。`request.id` や `appName` など |
| Collector | エージェントがデータを送る New Relic 側の受付 |
| Duration | かかった時間（秒） |
| Entity | New Relic が管理する対象。サービス、ホスト、アプリなど |
| Event | 1 件のデータ。Transaction や Log もイベントの一種 |
| Facet | 項目ごとの内訳 |
| Golden Signals | Latency / Traffic / Errors / Saturation の 4 指標 |
| Incident | アラート条件を満たして開いたインシデント |
| Ingest | データの取り込み。無料枠は月 100 GB |
| License key | バックエンドがデータを送るための鍵 |
| NRQL | New Relic のクエリ言語 |
| P95 / P99 | 遅い側から 5% / 1% のライン |
| rpm | 1 分あたりのリクエスト数 |
| Saturation | 飽和。資源の余裕のなさ |
| SLA / SLO / SLI | 約束 / 目標 / その測り方。エラー率やレイテンシが SLI になる |
| Span | トレースの 1 区間 |
| Throughput | 処理量 |
| Time picker | 右上の時間範囲 |
| Trace | 1 リクエストの全体 |
| Transaction | APM 上の 1 処理 |
| Web request | HTTP として来たリクエスト |

---

## 10. このリポジトリで見えないもの（職場で聞くこと）

正確に把握するために、無いものは無いと覚えます。

| 職場でよく見るもの | このリポジトリ | 誰に聞くか |
|---|---|---|
| ホスト CPU / メモリ | 未計装 | Infra エージェント、またはコンテナ基盤の担当 |
| Kubernetes の HPA / Pod 数 | 無し | プラットフォーム / SRE 先輩 |
| 本番のエラー予算（Error budget） | 無し | チームの SLO ドキュメント |
| デプロイマーカー | 未設定 | CI/CD と APM の連携担当 |
| オンコール通知 | 未設定 | PagerDuty / Slack 連携 |

検証アプリで身につけるのは「画面の役割」と「判断の順序」です。数字の絶対値（何 % で重大か）は、職場の SLO に合わせて上書きしてください。
