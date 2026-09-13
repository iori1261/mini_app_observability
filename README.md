# mini_app_observability

**New Relic を「触って覚える」ための練習用アプリです。**

ボタンを押すと、本物のサービス障害（遅延・サーバーエラー・依存先の停止）がその場で再現され、
New Relic の画面でどう見えるかを確認できます。無料枠だけで動きます。

オブザーバビリティを学びたいけれど、
「本番を壊すわけにはいかない」「New Relic の画面が英語だらけでどこを見ればいいか分からない」
という人のために作っています。

---

## 何ができるか

アプリのボタンを押す → Docker 上の API が動く → New Relic に記録が残る、という流れを一通り体験できます。


| 学べること            | このアプリでの再現方法                            |
| ---------------- | -------------------------------------- |
| **APM**（アプリ性能監視） | 注文 API のレイテンシ・スループット・エラー率を見る           |
| **分散トレーシング**     | 注文 API → 決済サービスへの呼び出しを 1 本の線で追う        |
| **エラー追跡**        | 意図的に 500 を出し、Errors inbox とスタックトレースを見る |
| **依存先の障害**       | 決済サービスだけ落として、「自分のバグではない」と切り分ける         |
| **ログ連携**         | `request.id` で、1 リクエストの APM とログを突き合わせる |
| **エラー率の読み方**     | 約 30% 失敗する負荷を流し、率として観測する               |
| **NRQL**         | 画面に出るクエリをコピーして、自分で数字を出す                |
| **モバイル監視**（任意）   | iOS アプリ側の操作・HTTP・クラッシュを見る              |


ボタンを押すたびに、画面に「**何が起きたか**」「**New Relic のどの画面をどの順に開くか**」
「**そのまま貼れる NRQL**」が日本語で表示されます。英語の画面名には訳を添えています。

---



## 構成

iOS アプリは Docker では動きません。Docker が動かすのは API 側だけです。

```text
iOS アプリ（Xcode / シミュレータ）
        │  ボタンを押す
        ▼
   API  :8080        ← New Relic 上の名前: mini-app-api
        │  決済を呼ぶ
        ▼
 payments :4000      ← New Relic 上の名前: mini-app-payments
        │
        ▼
     New Relic
```

iOS を使わず、ターミナルの `curl` だけでも全機能を試せます。Mac や Xcode が無くても学習できます。

---



## 必要なもの


| 必須                | 用途                |
| ----------------- | ----------------- |
| Docker Desktop    | API と決済サービスを動かす   |
| New Relic 無料アカウント | データを見る。クレジットカード不要 |



| 任意          | 用途                 |
| ----------- | ------------------ |
| Xcode 15 以降 | iOS アプリから操作したい場合のみ |


---



## 使い方



### 1. API を起動する

```bash
git clone https://github.com/iori1261/mini_app_observability.git
cd mini_app_observability
cp .env.example .env
docker compose up --build -d
```

動いているか確認します。

```bash
curl http://127.0.0.1:8080/health
# => {"status":"ok","service":"api",...}
```

この時点では New Relic には何も送られません。API 単体の確認はできます。

```bash
make verify   # 全シナリオを 1 回ずつ実行して結果を表示
```



### 2. New Relic に繋ぐ

1. [New Relic](https://newrelic.com/) で無料アカウントを作る
2. [one.newrelic.com/api-keys](https://one.newrelic.com/api-keys) を開く
3. **画面右上にある自分のアイコンCreate a key** → Key type は **Ingest - License** を選ぶ
4. 作成直後に表示されるキー全体をコピーする

> 一覧に出ている **Key ID** は鍵ではありません。これを貼ると `401 invalid license key` になります。
> User key（`NRAK-` で始まる）も違います。

1. `.env` に貼る

```bash
NEW_RELIC_LICENSE_KEY=ここにキー
```

1. 入れ直す

```bash
docker compose down && docker compose up -d
docker compose logs api | head -20
```

`Your license key appears to be invalid` が出ていなければ成功です。

### 3. データを出して画面を見る

1 回リクエストしただけでは、グラフはほとんど動きません。まとめて送ります。

```bash
make load          # 60 件、失敗なし     → Throughput が上がる
make load-errors   # 100 件、約 30% 失敗 → Error rate が 30% 前後になる
```

1〜3 分待ってから、New Relic の **APM & Services** を開きます。
`mini-app-api` と `mini-app-payments` が自動で現れます（手動登録は不要です）。

画面右上の時間範囲は **Last 30 minutes** にしてください。ここを合わせないと「何も出ていない」ように見えます。

**初めての方は [docs/first-run.md](docs/first-run.md) を開いてください。**
押す順番と見る画面だけを並べた 30 分のハンズオンです。

### 4. iOS アプリから操作する（任意）

```bash
open ios/MiniAppObservability.xcodeproj
```

Signing の Team を自分の Apple ID にして、シミュレータで実行します。
New Relic Mobile も使う場合は、下の「モバイル監視を有効にする」を参照してください。

---



## ボタンの一覧

アプリは 3 ステップに分かれています。ターミナル派は右の `curl` で同じことができます。

### STEP 1 画面の場所を覚える


| ボタン        | 呼び出す API                        | 見る画面                            |
| ---------- | ------------------------------- | ------------------------------- |
| 動いているか確認する | `GET /health`                   | APM の Transactions              |
| 注文する       | `POST /orders` → `POST /charge` | Distributed tracing、Service map |
| 直前の注文を読む   | `GET /orders/:id`               | `request.id` で 1 件を追う           |




### STEP 2 わざと壊して違いを見る


| ボタン        | 呼び出す API                 | 崩れる指標                 |
| ---------- | ------------------------ | --------------------- |
| わざと遅くする    | `POST /orders/slow`      | Latency のみ。エラー率は上がらない |
| サーバー側を壊す   | `POST /chaos/error`      | Errors。原因は api の中     |
| 決済サービスを落とす | `POST /chaos/dependency` | Errors。原因は payments 側 |


「遅い」と「壊れている」が別物だと分かることが、この STEP の目的です。

### STEP 3 グラフを動かす


| ボタン          | 内容             | 見る指標                            |
| ------------ | -------------- | ------------------------------- |
| 正常な負荷を流す     | 60 件、失敗なし      | Throughput が上がり、Error rate は 0% |
| エラーを混ぜた負荷を流す | 40 件、約 30% が失敗 | Error rate が 30% 前後             |


```bash
./scripts/load.sh 200 10   # 件数と失敗率を自分で指定する
```

手元に出る「エラー率」と New Relic の Error rate が一致するか、見比べてください。

---



## ドキュメント


| ファイル                                           | 内容                     |
| ---------------------------------------------- | ---------------------- |
| [docs/first-run.md](docs/first-run.md)         | はじめての 30 分。押す順番と見る画面だけ |
| [docs/new-relic-sre.md](docs/new-relic-sre.md) | 各画面の役割、英語の意味、勉強する順序    |


`docs/new-relic-sre.md` には、左メニューの英語表記と日本語の意味、
APM 内の各画面が何のためにあるか、SRE として何をどの順に身につけるかをまとめています。

---



## モバイル監視を有効にする（任意）

バックエンドの License Key とは**別のキー**が必要です。

1. New Relic で **Add Data → Mobile → iOS** を選び、アプリを追加する
2. 発行された **Application Token** をコピーする
3. Xcode で File → Add Package Dependencies に
  `https://github.com/newrelic/newrelic-ios-agent-spm` を追加する
4. Xcode の **Product → Scheme → Edit Scheme → Run → Arguments** を開く
5. **Environment Variables** に `NEW_RELIC_APP_TOKEN` を追加してトークンを貼る
6. アプリを再起動する

> **トークンをソースコードに直接書かないでください。**
> `AppConfig.swift` は追跡されているため、書き込むとそのまま公開されます。
>
> スキームの設定は通常 `xcuserdata`（`.gitignore` 済み）に保存されます。
> ただし Edit Scheme 画面で **「Shared」にチェックを入れると** `xcshareddata` **に移動し、
> 本来は共有される場所になります。** チェックは入れないでください。
> 事故に備えて `**/xcshareddata/xcschemes/` も `.gitignore` に入れてあります。

有効にすると、ボタン操作が Interaction・Breadcrumb・カスタムイベント `ButtonTap` として送られます。

---



## セキュリティ上の注意

このリポジトリは**学習用**です。そのまま本番やインターネットに公開しないでください。

### 絶対にコミットしないもの


| 種類                       | 置き場所            | 保護                                                        |
| ------------------------ | --------------- | --------------------------------------------------------- |
| New Relic License Key    | `.env`          | `.gitignore` 済み                                           |
| Mobile Application Token | Xcode スキームの環境変数 | `xcuserdata` と `xcshareddata/xcschemes` は `.gitignore` 済み |


`.env` をコピーして使ってください。`.env.example` のみが追跡されます。

キーを誤って公開してしまった場合は、[API keys](https://one.newrelic.com/api-keys) で
**そのキーを削除して作り直して**ください。リポジトリから消すだけでは足りません。

GitHub の **Settings → Code security** で **Secret scanning** と **Push protection** を
有効にしておくと、事故を事前に止められます。

### インターネットに晒してはいけない理由

`/chaos/error` と `/chaos/dependency` は、**誰でも叩けるとサービスを壊せる**エンドポイントです。
そのため既定では API を `127.0.0.1`（自分の Mac のみ）に公開しています。

```yaml
# docker-compose.yml
- "${API_BIND:-127.0.0.1}:8080:8080"
```

iPhone 実機から繋ぐときだけ、`.env` で一時的に広げてください。

```bash
API_BIND=0.0.0.0
```

> この API には認証がありません。`0.0.0.0` にすると、**同じ Wi-Fi にいる誰でも**
> `/chaos/*` を叩いてエラーを注入できます。カフェや社内など共有ネットワークでは避けて、
> 実機テストが終わったら行を消して `docker compose up -d` で戻してください。



### 意図的にそうしている設定

学習用途のため、本番なら避ける設定をあえて使っています。**流用しないでください。**


| 設定           | 場所                        | 本番でどうすべきか                                   |
| ------------ | ------------------------- | ------------------------------------------- |
| 認証なしの API    | `apps/backend/src/api.js` | 認証・レート制限を入れる                                |
| 障害注入エンドポイント  | `/chaos/*`                | 本番には置かない                                    |
| HTTP 平文通信を許可 | `ios/.../Info.plist`      | HTTPS を使う。例外は `127.0.0.1` と localhost に限定済み |


次の防御は最初から入れています。

- API は既定で `127.0.0.1` のみに公開
- **CORS は既定で無効**。有効にすると、あなたが開いた任意の Web ページから `/chaos/`* を起動できてしまうため
- 受け取ったヘッダーと `sku` は長さを制限（New Relic の取り込み量を無駄に消費させないため）
- リクエストボディは 16 KB まで
- コンテナは非 root ユーザー（`node`）で実行
- 依存は `npm ci` で lockfile 固定



### 依存パッケージ

clone 後に一度確認することをおすすめします。

```bash
cd apps/backend && npm audit
```

---



## 無料枠について

New Relic の無料枠は、このアプリの規模なら十分に余裕があります。

- 月 100 GB までのデータ取り込み（超えると取り込みが止まる）
- Full Platform ユーザー 1 名、Basic ユーザーは無制限
- データ保持は最短 8 日程度
- Synthetic チェックは月 500 回

負荷スクリプトを無限ループで回さない限り、上限に当たることはまずありません。

---



## ディレクトリ

```text
apps/backend    Docker で動く API と決済サービス（Node.js / Express）
ios             SwiftUI の練習用アプリ
scripts         verify-api.sh（疎通確認）と load.sh（負荷生成）
docs            New Relic の画面ガイド
```

---



## よくあるつまずき


| 症状                        | 原因と対処                                                   |
| ------------------------- | ------------------------------------------------------- |
| APM に何も出ない                | 1〜3 分待つ。時間範囲を Last 30 minutes に                         |
| `401 invalid license key` | Key ID や User key を貼っている。Ingest - License を作り直す         |
| グラフが平らなまま                 | リクエストが少ない。`make load` を実行する                             |
| iOS から繋がらない               | シミュレータは `127.0.0.1`。実機は `API_BIND=0.0.0.0` と LAN IP が必要 |
| ポートが使用中                   | `docker compose down` してから起動し直す                         |


---



## ライセンス

[MIT License](LICENSE)。学習用のサンプルです。自由に fork して改変してください。

ただし `/chaos/*` のような障害注入エンドポイントや、CORS 全許可などの設定を
そのまま本番へ持ち込まないでください。上の「セキュリティ上の注意」に代替案を書いています。