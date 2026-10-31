# Git・GitHub

2026-09-30〜の PR の流れと、Learn Git Branching（2026-10-03・10-04・10-31）と、手元での再現（2026-10-31）で学んだこと。

## 用語・コマンド

### 基本の部品

| 用語 | 一言でいうと | 実物の見え方 |
|---|---|---|
| コミット | 作業の保存点。**名前は無く、ID（ハッシュ）だけがある** | `8693d3d`（本当は40文字。先頭7文字で表示） |
| ブランチ | コミットに貼った**動く名札** | `main`・`docs/xxx` |
| HEAD | **今いる場所**の目印 | `HEAD -> main`＝main という名札の上にいる |
| detached HEAD | 名札ではなく**コミットに直接**いる状態。ここで commit すると見失いやすい | `git checkout 8693d3d` |
| `^`・`~3` | 1つ前・3つ前（相対リファレンス） | `HEAD~3` |

例え：コミット＝地図上の住所、ブランチ＝住所に立てた看板、HEAD＝現在地のピン。

### 履歴を動かす

| コマンド | 一言でいうと | 履歴を書き換えるか |
|---|---|---|
| `git merge` | 2本の枝を合流させるコミットを作る。分岐と合流が履歴に残る | 書き換えない |
| `git rebase` | 自分のコミットを相手の先に**作り直して**付け替える（`C2'` の `'`＝作り直し）。一本道になる | **書き換える** |
| `git rebase -i` | 作り直すときに並べ替え・まとめる（squash）・捨てる（drop）・メッセージ修正（reword）を指示する | **書き換える** |
| `git cherry-pick X` | X をコピーして今いる場所の下に付ける | 書き換えない |
| `git reset` | 名札を前のコミットへ戻す（ページを破り取る） | **書き換える** |
| `git revert X` | X を打ち消すコミットを新しく足す（取り消しを書き足す） | 書き換えない |
| `git branch -f 名札 行き先` | 名札を指定のコミットへ動かす（**名札と行き先の2つ**を書く） | − |

**ルール**：履歴を書き換える操作（rebase・reset・rebase -i）は、**まだ push していない自分のコミットにだけ**使う。共有済みのものは revert で直す。

### リモート（GitHub）

| 用語・コマンド | 一言でいうと |
|---|---|
| `origin` | GitHub 側のリポジトリにつけた呼び名 |
| `origin/main`（教材では `o/main`） | 「**最後に GitHub を見たとき**、main はここだった」というメモ。GitHub と通信したときにしか動かない |
| `git clone` | GitHub の中身を手元に丸ごとコピーし、つながりも作る |
| `git fetch` | GitHub を見に行って、**メモだけ**更新する。自分の main は動かさない |
| `git pull` | 既定の設定では fetch ＋ merge（`pull.rebase=true` などの設定や `--rebase` の指定があれば fetch ＋ rebase） |
| `git pull --rebase` | fetch ＋ rebase（一本道にする） |
| `git push` | 自分のコミットを GitHub へ送る |
| `git fetch --prune` | GitHub でもう消えたブランチのメモを掃除する |
| `git ls-remote --heads origin` | メモではなく **GitHub に直接**ブランチを聞く |
| `git init --bare 名前.git` | **作業フォルダの無い、保管専用**のリポジトリを作る。みんなが push してくる共有の倉庫で、中で直接編集しない（push とぶつかるため）。GitHub の中にあるのもこの形 |

- `git status -sb` の1行目 `## main...origin/main [ahead 13, behind 7]`＝手元が13先、GitHub が7先＝**分岐（diverged）**
- `non-fast-forward`＝GitHub が先に進んでいるのに、古いメモのまま push しようとした
- `A && B`＝A が成功したら B を実行する（シェルのつなぎ。Git の機能ではない）
- `git branch -a` の色：緑＝手元のブランチ、赤＝GitHub 側のメモ。`*`＝今ここ、`+`＝別の作業フォルダ（worktree）で使用中

### プルリクエスト（PR）

| | 何をする | 誰が決める |
|---|---|---|
| push | **場所の移動**（手元 → GitHub の自分のブランチ）。main は変わらない | 自分 |
| PR → マージ | **ブランチ間の移動**（GitHub の中で、自分のブランチ → main）。「main に取り込んでください」と人に出す申請 | main の管理者・レビューする人 |

- 名前の由来＝「私のリポジトリのブランチを、あなたの方から pull してください」というお願い
- squash マージ＝ブランチのコミットを1つにまとめて main に載せる（このリポジトリは「PR 1本＝main の1行」）

## 出力の見方

見るのは **3 種類だけ**。

1. `[ブランチ ハッシュ] メッセージ`＝commit ができた証拠
2. `To …`／`From …` の下の **`古い..新しい`** の行＝何がどこからどこへ動いたか
3. `error:`／`hint:`＝問題と対処（hint は対処法をそのまま書いてくれている）

**読み飛ばしてよい**：`Enumerating`／`Counting`／`Compressing`／`Writing objects`（送信の進捗）、`LF will be replaced by CRLF`（Windows の改行コードの自動変換の注意）、`You appear to have cloned an empty repository`（空の倉庫を clone した＝作りたてなら当然）。

| 出力 | 意味 |
|---|---|
| `[master (root-commit) dfaf6e4] C1` | master で commit した。`root-commit`＝履歴の最初。`dfaf6e4`＝commit の ID（パズルの C1） |
| `1 file changed, 1 insertion(+)` | 1 ファイル、1 行増えた |
| `create mode 100644 a.txt` | 新しいファイルができた（100644＝ふつうのファイル） |
| `* [new branch] HEAD -> master` | 今いる場所を、相手側に master という**新しいブランチとして**作った |
| `branch 'master' set up to track 'origin/master'` | master と origin/master が組になった（`push -u` の効果）。次から `git push` だけで送れる |
| `* [new branch] master -> origin/master`（From の下） | 相手の master を取ってきて、手元に origin/master（パズルの o/main）として置いた |
| `dfaf6e4..cdcfd88 master -> master` | **一番大事**。master が dfaf6e4 から cdcfd88 へ進んだ |
| `! [rejected] master -> master (fetch first)` | `!`＝失敗。相手に知らない commit がある＝先に取ってきて |
| `Successfully rebased and updated refs/heads/master.` | 自分の commit を積み直した。`refs/heads/master`＝手元の master の正式名 |

`git log --oneline --graph --all` の読み方＝**上が新しく下が古い**（パズルの図の上下逆）。`*` が commit 1 つ、`( )` の中がラベル。`HEAD -> master, origin/master` が同じ行＝パズルで `main*` と `o/main` が同じ丸に付いている状態。

## つまずいたところ

| 日付 | 最初の理解 | 正しい理解 |
|---|---|---|
| 10/3 | リベース＝統合したうえで一本化する | 統合ではなく、自分のコミットを相手の先に**付け替えて作り直す** |
| 10/3 | `bugFix` は C4 にあるコミット | `bugFix` はブランチ（**C4 に貼られた名札**） |
| 10/3 | HEAD＝checkout で編集できる状態のもの | HEAD＝**今いる場所の目印**。次の commit がその続きにできる |
| 10/3 | `git branch -f main^` でエラー | `git branch -f` は**名札と行き先の2つ**を書く（`git branch -f main C6`）。1つだと「`main^` という名札を作れ」と読まれる |
| 10/3 | revert＝なかったことにしたうえで更新 | 元のコミットは**残したまま**、打ち消すコミットを新しく足す |
| 10/4 | C4 に checkout すれば C5' の下にコミットできる | checkout は**立ち位置を動かすだけ**でコミットは動かない。コミットを置き直すのは rebase か cherry-pick |
| 10/4 | 擬似的なチーム作業は、先に GitHub が進んでから clone する | 先に clone → GitHub が進む → 自分も進む → 取り込んで合流。C4 が C1 から枝分かれしている＝C4 を作ったとき C2・C3 を知らなかった |
| 10/4 | 赤いブランチは問題がある？ | 赤は GitHub 側のメモの色。警告ではない |
| 10/10 | 1週間空いたら `-f` と `-b` が何だったか分からなくなった | `-f`＝force（強制）。`branch -f` は手元の名札を動かすだけ（安全）、`push -f` は GitHub の履歴を上書き（危険）。`checkout -b 枝`＝枝を作って移る（b＝branch。`switch -c` も同じ） |
| 10/10 | 同じ箇所を編集していたら、あとから rebase したほうに上書きされる？ | 上書きされない。同じ行がぶつかると rebase が**止まる**（コンフリクト）。`<<<<<<<` と `>>>>>>>` の間を直して `git add` → `git rebase --continue`、やめるなら `--abort`。Learn Git Branching はファイルの中身を持たないので起きない |
| 9/30 | `git update-index --chmod=+x` のあと pathspec 付きで commit すれば実行権限が入る | pathspec 付きの commit は HEAD から取り直すので落ちる。`git commit -i -- <file>` を使い、`git ls-tree HEAD` で**commit の中身**を確かめる |
| 10/31 | `git init --bare` が何をしているか分からない | 作業フォルダの無い共有倉庫を作る。GitHub の中身と同じ形なので、PC の中に小さな GitHub を作れる |
| 10/31 | パズルは分かるが実務のイメージが湧かない | side＝PR のブランチ、リモートに増えた C8＝スマホや夜間タスクなど**自分以外**が入れた変更、push を断られる＝実際に起きる場面。手で打つ merge は実務ではほとんど GitHub の Merge ボタンが代わりにやる |
| 10/31 | rebase しても commit は同じもの | rebase の前後でハッシュが変わる（`f687ffd` → `1a877b3`）。親が変わると別の commit として作り直される＝パズルの `C2'` の `'` の正体 |

## 使い道

- **作業を始める前**：`git fetch` → `git status -sb` で ahead/behind を見る（古いメモのまま始めない）
- **押すとき**：`git pull --rebase && git push` を**1行で間を空けずに**（`;` ではなく `&&`）
- **分岐は避けきれない**：小さく commit してこまめに push、ブランチは短く使ってすぐ PR → マージ＝小さいうちに合わせる
- **直すとき**：push 済みなら revert、まだなら rebase -i や reset
- **表示がおかしいとき**：メモ（`git branch -a`）ではなく実物（`git ls-remote`）を見る

### 手元で再現する練習（`~/git-lab`・15〜20 分）

GitHub を使わず PC の中だけで「自分・他の人・倉庫」を作り、push を断られる → 立て直す、を再現する。Git Bash で 1 行ずつ。

```bash
mkdir ~/git-lab && cd ~/git-lab && git init --bare remote.git && git clone remote.git me && git clone remote.git other
cd ~/git-lab/me && echo "a" > a.txt && git add a.txt && git commit -m "C1" && git push -u origin HEAD
cd ~/git-lab/other && git pull && echo "b" > b.txt && git add b.txt && git commit -m "C8 by other" && git push
cd ~/git-lab/me && echo "c" > c.txt && git add c.txt && git commit -m "C2 by me" && git push
git pull --rebase && git push
git log --oneline --graph --all
```

- 4 行目で `[rejected]` が出る（パズルでリモートに C8 があった状態）。5 行目で立て直す。
- 6 行目で一直線に並べば rebase が効いている。5 行目を `git pull --no-rebase` にすると合流点ができる（`--no-rebase` を付けないと `pull.rebase` の設定しだいで rebase になることがある）。
- やり直すときは `rm -rf ~/git-lab` で消してから 1 行目へ。
- 3 行目の `git pull` が `There is no tracking information` で止まったら、`git pull origin master` と `git push -u origin HEAD` に置き換える（Git 2.49 では空の倉庫の clone でも追跡先が設定され、そのまま通った）。
