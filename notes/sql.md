# SQL

Phase1 の入口（2026-10-07）。SQL Server 2022 を Docker で立てて、MySQL（XAMPP）との違いを試したこと。10/11 に `WHERE`・`ORDER BY`・`GROUP BY`・`INSERT`・`UPDATE`。11/7 に `JOIN`。

## 用語・コマンド

| 用語・コマンド | 一言でいうと |
|---|---|
| SQL Server Developer 版 | 全機能入りで無料。ただし**開発とテスト用**で、本番サーバーには使えない（Microsoft Learn「Editions and supported features of SQL Server 2022」で確認・2026-10-06） |
| `docker run -d --name mssql -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest` | SQL Server を立てる。`ACCEPT_EULA=Y`＝ライセンスに同意。`-e 変数名`（値なし）＝手元の変数をそのまま渡す＝パスワードが履歴に残らない。1433＝SQL Server の決まったポート |
| `sqlcmd` | SQL を送って結果を受け取る**クライアント**（コンテナの中の `/opt/mssql-tools18/bin/sqlcmd`）。現場の SSMS も立場は同じ |
| `-C` | 自分用の仮の証明書をそのまま信じる（手元の練習用） |
| `SELECT 1;` | 表が無くても返る、いちばん小さな SQL。返れば「動いている・つながる・ログインできる」を一度に確かめられる |
| `-d lab` | DB `lab` の中で実行する |
| `docker start mssql` | 止まったコンテナを、同じ中身のまま起こす（データも残る） |

### 書く順番と、行を足す・直す（10/11）

**SELECT → FROM → WHERE → GROUP BY → ORDER BY**＝「決めて、出して、除いて、まとめて、並べる」（料理：何を作るか決める → 冷蔵庫から出す → 傷んだのを除く → 種類ごとにまとめる → 皿に並べる）。入れ替えるとエラーになる。⚠️ 実際に処理される順番は FROM → WHERE → GROUP BY → SELECT → ORDER BY で、書く順とは違う。

| 書き方 | 一言でいうと |
|---|---|
| `WHERE minutes > 30` | 条件に合う行だけ残す。`>` はより大きい（30 は入らない）、`>=` は以上（30 も入る） |
| `ORDER BY study_date DESC` | 並べ替える。`DESC`＝大きい順・新しい順、付けなければ小さい順 |
| `GROUP BY study_date` ＋ `SUM(minutes) AS total` | 同じ日付の行を1つにまとめて合計する。`AS`＝結果の列に付ける別名 |
| `INSERT INTO study_log VALUES (5, '2026-10-08', 60), (...)` | 行を足す。カンマで区切れば何行でも |
| `UPDATE study_log SET minutes = 45 WHERE id = 4` | 行を書き換える。**WHERE を忘れると全部の行が変わる** |
| `sq -d lab -Q "..."` | `-d`＝使う DB（database）、`-Q`＝この SQL を実行して終わる（小文字の `-q` は実行後も残る） |

### JOIN（2つの表を日付でつなぐ・11/7）

| 書き方 | 一言でいうと |
|---|---|
| `FROM trading_calendar AS c INNER JOIN prices AS p ON p.trade_date = c.trade_date` | 両方に相手がいる行だけ残す。相手のいない行は黙って落ちる（カレンダー 500 日 × prices 503 行 → 500 行） |
| `LEFT JOIN` | 左の行は全部残す。右に相手がいなければ、右側の列が `NULL` になる |
| `WHERE 右.キー IS NULL` | 相手がいない行だけ拾う。`= NULL` では拾えない（`NULL` は「不明」なので、`=` で比べると常に真にならない） |

- 型＝「あるはずの表を左に置く → `ON` で結ぶ列を決める → 拾いたい行を `IS NULL` で決める」
- 左右を逆にすると、`NULL` が出る側が変わる。カレンダーを左にした欠け探しは 0 件、prices を左にすると 8/12〜14 の 3 日が `NULL` で出た（カレンダーを 8/10 で区切ったため。欠けではない）
- 銘柄が増えると、`INNER JOIN` の件数は銘柄の数だけ増える。`AND p.code = '…'` を足して、銘柄ごとに数える
- `NOT EXISTS`（前回の欠け探し）と `LEFT JOIN … IS NULL` は、同じ答えが出る別の書き方
- 練習用の表は Docker の DB の中だけ（trading_calendar・market_holidays）。リポジトリには保存していない

### MySQL（XAMPP）との違い

| やりたいこと | MySQL | SQL Server |
|---|---|---|
| 先頭から○行 | `... LIMIT 2` | `SELECT TOP 2 ...` |
| 番号の自動採番 | `AUTO_INCREMENT` | `IDENTITY(1,1)`（開始値・増やす幅） |
| 今の日時 | `NOW()` | `GETDATE()`（日付だけ＝`CAST(GETDATE() AS DATE)`） |
| 決まったポート | 3306 | 1433 |
| よく使うクライアント | phpMyAdmin | SSMS・`sqlcmd` |

- SQL Server で `LIMIT` を打つと `Incorrect syntax near 'LIMIT'`。`near` の後ろの単語の**手前**で文法が崩れた、という意味

### 別名（毎回の長いコマンドを短く）

```bash
alias sq='docker exec -i mssql bash -c "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C \"\$@\"" --'
```

- パスワードは**コンテナが覚えているもの**を中で読む（`\$` で手元では展開させない）＝窓を開け直しても打ち直さなくてよい
- `"$@"` と最後の `--` ＝ `sq` の後ろの `-d lab -Q "..."` を、そのまま `sqlcmd` へ引き継ぐ

## つまずいたところ

| 日付 | 最初の理解 | 正しい理解 |
|---|---|---|
| 11/7 | `LEFT JOIN` すると、`NULL` が必ず出る | `NULL` は「右に相手がいない行」にだけ出る。カレンダーを左にした今回は欠けが 0 件なので、`NULL` は 1 つも出なかった（それが正しい結果）。`NULL` を見たいときは左右を逆にする |
| 10/7 | alias の中で `bin\sqlcmd` と打ったら `binsqlcmd: no such file` | alias の中身は使うときにもう一度シェルが読み直す。そのとき `\s` の `\` は消費されて消える。長いコマンドは手で打たずにコピーし、`alias sq` で中身を確かめる |
| 10/11 | 「30分より長い日を、日付の新しい順に」を `WHERE minutes >= 30 ORDER BY minutes DESC` と書いた | SQL の形は正しい。お題の読み取りが2か所違った＝「より長い」は `>`、「日付の新しい順」は `ORDER BY study_date DESC` |
| 10/11 | `-d` と `-Q` は「そういうもの」として打っていた | `sq` は別名で、中身は `sqlcmd -S localhost -U sa -P ... -C`。`-d lab`＝lab の中で、`-Q`＝この SQL を実行して終わる |
| 10/7 | `Login failed for user 'sa'` が続く＝何が悪いか分からない | 画面のエラーは「失敗した」だけ。理由はサーバー側のログにある（表の下のコマンドの `Reason:`）。今回はコンテナが覚えているパスワードを使う形に変えたら通った＝打ち直した値が違っていた可能性が高い（⚠️ `Reason:` の行そのものは見ていない） |

```bash
docker logs mssql 2>&1 | grep "Login failed" | tail -2
```

## 使い道

- 現場の DB に触る前に、手元で同じ SQL Server を試す。壊しても `docker rm` で作り直せる
- ネットの SQL を貼って `Incorrect syntax near ...` が出たら、まず MySQL の書き方ではないかを疑う
- ログインできないと言われたら、サーバーのログで `Reason:` を先に見る
- AWS の RDS（マネージド DB）は、この「立てる・管理する」を AWS が代わりにやってくれるもの、と比べて理解できる
