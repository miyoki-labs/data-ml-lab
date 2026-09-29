# Phase0: Linux と Docker に慣れる（2026-10）

目的は「操作に慣れる」こと。暗記ではなく、**自分で打って、結果を読めるようになる**のが到達点。

## 作業場所のルール

理由は 2026-09-30 にこの PC の設定を見て決めた。設定が変わったら見直す。

| 何を | どこで | なぜ |
|---|---|---|
| 課題の手を動かす部分 | Ubuntu の `~/lab/phase0/`（リポジトリの外・消してよい） | この PC の `/mnt/c` は `metadata` オプション無しでマウントされている（`mount \| grep /mnt/c` で確認）＝`chmod` の結果が残らない |
| メモ・スクリプトの保管 | このリポジトリ（Windows 側のフォルダ） | 査読ゲート（pre-push）の `core.hooksPath` は Windows 側の git にだけ設定してある |
| git の commit / push | Windows 側（PowerShell か Claude Code） | 同上。Ubuntu 側の git には `core.hooksPath` を設定していない＝そこから push するとゲートを通らない |
| Docker のデータ | 名前付きボリューム（`docker volume`） | Microsoft の WSL ドキュメントは、Linux のツールで扱うファイルは Linux 側に置くことを推奨している（性能のため） |

## 課題（上から順に）

各課題の「できた」は、判定コマンドの結果で決める。

### 1. ファイル操作と権限

- やること: `~/lab/phase0/` を作り、ファイルを作る・コピーする・消す。`ls -l` の左端（`-rw-r--r--`）を読めるようにする。`chmod` で実行権限を付け外しする
- 判定: `ls -l` の出力の1行を、所有者・グループ・その他の権限に分けて口で説明できる／`chmod +x` した自作スクリプトが `./hello.sh` で動く

### 2. パイプとテキスト処理

- やること: `grep`・`sort`・`uniq -c`・`awk` を `|` でつなぐ
- 判定: 次の1行を、左から順に「各段で何が起きているか」を説明しながら打てる。出力は「回数 単語」が最大5行（当日のログの単語が5種類未満なら、その数だけ）
  ```bash
  journalctl -u docker --since today --no-pager -o cat | LC_ALL=C tr -cs 'A-Za-z' '\n' | LC_ALL=C sort | uniq -c | sort -rn | head -5
  ```
  （権限のエラーが出たら `journalctl` の前に `sudo` を付ける。単語＝半角英字 A〜Z・a〜z の連続。`LC_ALL=C` は言語設定による違いを無くすため）

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
