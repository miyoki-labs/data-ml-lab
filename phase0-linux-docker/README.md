# Phase0: Linux と Docker に慣れる（2026-10）

目的は「操作に慣れる」こと。暗記ではなく、**自分で打って、結果を読めるようになる**のが到達点。

## 作業場所のルール

| 何を | どこで | なぜ |
|---|---|---|
| 課題の手を動かす部分 | Ubuntu の `~/lab/phase0/`（リポジトリの外・消してよい） | `/mnt/c` は権限（`chmod`）が保存されず、ファイル操作も遅い |
| メモ・スクリプトの保管 | このリポジトリ（Windows 側 `C:/Miyoki/個人/smb-data-ops`） | 査読ゲート（pre-push）が Windows 側の git にだけ掛かっている |
| git の commit / push | Windows 側（PowerShell か Claude Code） | 同上。Ubuntu の git から push するとゲートを通らない |
| Docker のデータ | 名前付きボリューム（`docker volume`） | `/mnt/c` をマウントすると遅く、ファイル変更の通知も届かない |

## 課題（上から順に）

各課題の「できた」は、判定コマンドの結果で決める。

### 1. ファイル操作と権限

- やること: `~/lab/phase0/` を作り、ファイルを作る・コピーする・消す。`ls -l` の左端（`-rw-r--r--`）を読めるようにする。`chmod` で実行権限を付け外しする
- 判定: `ls -l` の出力の1行を、所有者・グループ・その他の権限に分けて口で説明できる／`chmod +x` した自作スクリプトが `./hello.sh` で動く

### 2. パイプとテキスト処理

- やること: `grep`・`sort`・`uniq -c`・`awk` を `|` でつなぐ
- 判定: `journalctl --since today` の出力から、出現回数の多い上位5単語を1行のコマンドで出せる

### 3. プロセスとサービス

- やること: `ps`・`top`・`systemctl status docker`・`journalctl -u docker` で「いま何が動いているか」を読む
- 判定: `systemctl is-active docker` が `active` を返す理由を、`systemctl status docker` の出力を指して説明できる

### 4. シェルスクリプトと定期実行（12/1 の自動収集の予行）

- やること: 日時をファイルに1行追記するスクリプトを書き、`crontab -e` で5分ごとに動かす。止め方も確かめる
- 判定: 追記先のファイルに、5分間隔の行が3行以上並ぶ／`crontab -l` から消したあと、行が増えなくなる

### 5. Docker

- やること: `docker run` → `Dockerfile` を書いて `docker build` → `compose.yaml` で Postgres を立てる（データは名前付きボリューム）
- 判定: `docker compose up -d` のあと `docker compose exec db psql -U postgres -c 'select 1'` が `1` を返す／`docker compose down` → `up -d` でデータが残る

## AI の使い方の練習（全課題共通）

各課題のあと、[`docs/ai-usage-log.md`](../docs/ai-usage-log.md) に1行記録する。Phase0 で身につけたい型は3つ。

1. **聞く前に `--help` と `man` を見る**（AI を使わない判断も練習のうち）
2. **貼るのは「打ったコマンド・エラーの該当行・期待した結果」だけ**（ログ全文を貼らない）
3. **1課題＝1会話**。課題が変わったら会話を新しくする（前の課題の文脈を毎回読み直させない）
