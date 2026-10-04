# Docker

Phase0 の課題5の入口（2026-10-05）と、J-Quants の取得ツール（PR #6）で使ったこと。

## 用語・コマンド

| 用語・コマンド | 一言でいうと |
|---|---|
| イメージ | コンテナの**設計図**（レシピ）。1つあれば何個でも作れる。消さない限り残る |
| コンテナ | 設計図から作った**実物**（作った1皿）。終われば捨ててよい |
| Docker daemon（`dockerd`） | 裏で動いている本体。`systemctl status docker` の `Main PID` がこれ |
| Docker client（`docker` コマンド） | 窓口。打ったコマンドを daemon に頼む |
| Docker Hub | 設計図の置き場（ネット上）。手元に無い設計図はここから取ってくる |
| `docker run --rm X` | 設計図 X から実物を作って動かし、**終わったら実物を消す** |
| `docker images` | 設計図の一覧（`IMAGE`＝名前:版、`ID`、`DISK USAGE`＝容量、`EXTRA` の `U`＝使用中） |
| `docker ps -a` | 実物の一覧（`-a`＝止まっているものも全部）。空なら実物は0個 |
| `docker image rm X` | 設計図を消す |
| `docker compose run --rm app …` | `compose.yaml` に書いた設定で実物を作って動かし、終わったら消す |

- `docker run hello-world` の英文の1〜4＝窓口が本体に頼む → 設計図を取ってくる → 実物を作って動かす → 結果を画面に出す
- プログラミングでいうと、イメージ＝クラス、コンテナ＝インスタンス

## つまずいたところ

| 日付 | 最初の理解 | 正しい理解 |
|---|---|---|
| 10/5 | `docker images` と `docker ps -a` の見方が分からない | images＝設計図、ps＝実物。`--rm` で実物は消えたので ps は空、設計図は残る |
| 10/5 | `smb-data-ops-app` と `data-ml-lab-app` は別物？ | 同じ中身の古い名前の残り。compose はフォルダ名で名前を付けるので、`name: data-ml-lab` を書く前に作った分が残っていた（10/5 に削除） |

## 使い道

- **データは実物の中に置かない**：実物は毎回捨てられるので、DB のデータは名前付きボリューム（実物の外の保管場所）に置く
- **秘密は環境変数ではなく secrets で渡す**：環境変数は `docker inspect` で見える（PR #6）
- **「動くか」の確認**：`systemctl is-active docker`（本体）→ `docker run --rm hello-world`（窓口から本体まで一通り）
