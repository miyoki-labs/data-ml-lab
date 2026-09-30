# collector

J-Quants API（V2）から日足を取得する。株価の値とキーは出力しない。

## 準備

WSL の Ubuntu に `~/.secrets/jquants.env`（権限 600）を置き、`JQUANTS_API_KEY=<キー>` の1行を書く。コンテナには compose の `secrets` で読み取り専用で渡る。

## 使い方（Ubuntu で、このリポジトリのフォルダから）

```bash
docker compose run --rm app python -m collector.fetch_one <銘柄コード>
```

出力は「コード 件数 最初の日付 最後の日付」の1行。失敗時の終了コードは `collector/fetch_one.py` の `EXIT_*`。

## テスト（API を呼ばない）

```bash
docker compose run --rm test
```

## キー漏れの検査

```bash
docker compose run --rm test scripts/check-secret-leak.sh --selftest
scripts/check-secret-leak.sh --key-file ~/.secrets/jquants.env --root .
```
