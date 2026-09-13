# はじめての 30 分（画面をたどるだけ）

New Relic を初めて触る人向けに、**押す → 見る** だけを順番に書いたものです。  
用語の説明や、画面ごとの役割は [new-relic-sre.md](new-relic-sre.md) にあります。

前提: `docker compose up -d` が動いていて、`.env` に License Key が入っていること。

---

## 0. 共通のつまずきポイント

先にこれだけ覚えてください。ここで詰まる人がいちばん多いです。

| 症状 | 原因 | 直し方 |
|---|---|---|
| APM に何も出ない | データがまだ届いていない | 1〜3 分待つ。ボタンをもう何回か押す |
| グラフが平ら | 見ている時間帯がずれている | 画面右上の時間範囲を **Last 30 minutes**（直近 30 分）にする |
| 数字が動いた気がしない | リクエストが少なすぎる | `make load` でまとめて送る |
| アプリ名が出てこない | キーが違う | `docker compose logs api` に `401` が無いか見る |

New Relic の画面は、**自分でアプリを登録しません**。データが届くと `mini-app-api` が勝手に現れます。

---

## 1. まず量を出す（2 分）

1 回リクエストしただけでは、グラフはほぼ動きません。最初に人工的な負荷をかけます。

```bash
make load
```

60 件のリクエストが飛びます。終わったら 1〜3 分待ちます。

---

## 2. サービスが出ているか見る（3 分）

1. [https://one.newrelic.com](https://one.newrelic.com) を開く
2. 左メニューの **APM & Services**（アプリ性能監視）をクリック
3. 一覧に次の 2 つが出ていることを確認する

```text
mini-app-api        ← 注文 API（このプロダクトの本体）
mini-app-payments   ← 決済サービス（api から呼ばれる）
```

出ていなければ、時間範囲を **Last 30 minutes** にしてリロードしてください。

---

## 3. Summary を読む（5 分）

`mini-app-api` をクリックすると **Summary**（概要）が開きます。  
SRE が障害時に最初に見る画面です。次の 3 つだけ探してください。

| 画面の英語 | 意味 | 今どうなっているか |
|---|---|---|
| Throughput | 1 分あたりの処理件数 | さっきの 60 件で山ができている |
| Response time | 応答時間 | まだ速いはず |
| Error rate | エラー率 | **0%** のはず |

「量は増えたが、遅くもなっていないし壊れてもいない」= 健全な状態です。この形を先に覚えます。

---

## 4. 壊れた状態と比べる（5 分）

今度はエラーを混ぜます。

```bash
make load-errors
```

100 件のうち約 30 件が失敗します。1〜3 分待ってから Summary を見ます。

- **Error rate** が 0% から **30% 前後** に上がる
- **Throughput** も上がっている（失敗もリクエストとして数えられる）

ここが重要です。**エラーの「件数」ではなく「率」で見ます。**  
アクセスが 10 倍になればエラー件数も 10 倍になりますが、率が変わらなければ健全さは変わっていません。

---

## 5. どこが壊れているか特定する（5 分）

1. 左の **Errors inbox**（エラー受信箱）を開く
2. エラーが 2 種類あることを確認する

| エラー | 何が起きたか |
|---|---|
| `intentional_server_error` | api 自身が 500 を返した。原因は自分のコード |
| `payment_failed` | 決済サービスが落ちて api が 502 を返した。原因は呼び先 |

3. どちらかをクリックして **Stack trace**（落ちた場所）を見る
4. 同じ画面から **Logs**（ログ）に飛べることを確認する

「同じ 5xx でも、自分のせいか他人のせいかは違う」と言えたらここは合格です。

---

## 6. 遅さとエラーは別物だと確かめる（5 分）

iOS アプリで **「4. わざと遅くする」** を数回押します。アプリを使わないならこちらでも同じです。

```bash
curl -X POST http://127.0.0.1:8080/orders/slow \
  -H 'content-type: application/json' \
  -d '{"sku":"slow-item","quantity":1}'
```

Summary を見ると:

- **Response time** が伸びる
- **Error rate** は上がらない

壊れてはいませんが、ユーザーは待たされています。これが **Latency の問題** です。  
「エラーが出ていないから問題なし」と判断しないための練習です。

次に **Transactions**（処理の一覧）を開き、遅いのが `POST /orders/slow` **だけ** だと確認します。サービス全体が遅いわけではありません。

---

## 7. サービスをまたいで追う（5 分）

1. `mini-app-api` の左メニューから **Distributed tracing**（分散トレーシング）を開く
2. 失敗したトレース（赤いもの）をクリック
3. 上下に並ぶ帯（**span** / 区間）を見る

```text
mini-app-api  POST /orders          ← 最初に受けた区間
  └ mini-app-payments  POST /charge ← ここが赤ければ決済のせい
```

- `/chaos/dependency` の場合 → payments 側が赤い
- `/orders/slow` の場合 → api 側の帯が長い。payments は普通

これが「自分のサービスか、呼び先か」の切り分けです。実務でいちばん使います。

---

## 8. 自分で数字を出す（5 分）

1. 左メニューの **Query your data**（データを問い合わせる）を開く
2. 次を貼って実行する

```sql
SELECT percentage(count(*), WHERE error IS true) FROM Transaction
WHERE appName = 'mini-app-api'
SINCE 30 minutes ago TIMESERIES
```

エラー率のグラフが出ます。Summary で見たものと同じ数字です。  
**グラフの裏では、いつもこういうクエリが動いています。**

続けてこれも実行します。エンドポイントごとの遅さです。

```sql
SELECT average(duration), percentile(duration, 95), count(*) FROM Transaction
WHERE appName = 'mini-app-api'
FACET name SINCE 30 minutes ago
```

`percentile(duration, 95)` は **P95**、遅い側 5% のラインです。  
平均だけ見ると、一部だけ極端に遅い状態を見逃します。SRE は P95 を見ます。

---

## 9. ここまでで言えるようになること

次の 5 つを自分の言葉で言えたら、最初の 30 分は達成です。

1. `mini-app-api` と `mini-app-payments` の関係
2. Throughput・Response time・Error rate の違い
3. エラー「件数」と「率」の違い
4. 遅い（Latency）と壊れている（Errors）の違い
5. 原因が自サービスか、呼び先かの見分け方

---

## 次にやること

[new-relic-sre.md](new-relic-sre.md) の「段階 D 以降」に進みます。

- ダッシュボードを 1 枚作る
- アラートを 1 本設定する
- スケーリング判断（Traffic が増えたときに何が悪化するか）
