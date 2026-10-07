# SQL

Phase1 の入口（2026-10-07）。SQL Server 2022 を Docker で立てて、MySQL（XAMPP）との違いを試したこと。

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
| 10/7 | alias の中で `bin\sqlcmd` と打ったら `binsqlcmd: no such file` | alias の中身は使うときにもう一度シェルが読み直す。そのとき `\s` の `\` は消費されて消える。長いコマンドは手で打たずにコピーし、`alias sq` で中身を確かめる |
| 10/7 | `Login failed for user 'sa'` が続く＝何が悪いか分からない | 画面のエラーは「失敗した」だけ。理由はサーバー側のログにある（表の下のコマンドの `Reason:`）。今回はコンテナが覚えているパスワードを使う形に変えたら通った＝打ち直した値が違っていた可能性が高い（⚠️ `Reason:` の行そのものは見ていない） |

```bash
docker logs mssql 2>&1 | grep "Login failed" | tail -2
```

## 使い道

- 現場の DB に触る前に、手元で同じ SQL Server を試す。壊しても `docker rm` で作り直せる
- ネットの SQL を貼って `Incorrect syntax near ...` が出たら、まず MySQL の書き方ではないかを疑う
- ログインできないと言われたら、サーバーのログで `Reason:` を先に見る
- AWS の RDS（マネージド DB）は、この「立てる・管理する」を AWS が代わりにやってくれるもの、と比べて理解できる
