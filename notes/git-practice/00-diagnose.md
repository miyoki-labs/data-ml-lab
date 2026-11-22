# 00 診断 — 荒れたフォルダを「読むだけ」で把握する

## 場面

久しぶりに作業フォルダを開いたら、`main` は「手元が先・origin も先」らしい。枝がいくつもあり、
別フォルダに作った作業場（worktree）も残っているようだ。**何も書き換える前に、まず状態を数字で言えるようにする。**

道具は 4 つ。すべて読み取りだけで、何も壊れません。

| 知りたいこと | コマンド |
|---|---|
| 手元と origin のズレ・未コミット | `git status -sb` |
| 枝の一覧と、それぞれの上流 | `git branch -vv` |
| 作業場の一覧 | `git worktree list` |
| 履歴の形 | `git log --graph --oneline --all --decorate` |

## 見本

練習場（`C:/GitPractice/work`）で実行した結果です。

```powershell
cd C:/GitPractice/work
git status -sb
```

```text
## main...origin/main [ahead 3, behind 3]
 M notes.md
?? scratch.txt
```

読み方：`ahead 3, behind 3` ＝手元に origin へ出していない commit が 3 つ・origin にだけある commit が 3 つ（**分岐**）。
` M` は変更済みで未 commit、`??` は git が追跡していないファイル。

```powershell
git branch -vv
```

```text
  feature/merged-gone fec6101 [origin/feature/merged-gone: gone] feature: note
+ hotfix/gone         51fbc7b (C:/GitPractice/wt-gone) README: add usage line
+ hotfix/leftover     c2670ee (C:/GitPractice/wt-leftover) hotfix: note
* main                51fbc7b [origin/main: ahead 3, behind 3] README: add usage line
  wip/no-upstream     4560b64 wip: memo
```

読み方：先頭の `*`＝いま居る枝、`+`＝別の作業場で開いている枝。`[…: gone]`＝上流の枝が origin から消えている。
角括弧が **無い**枝（`wip/no-upstream`）＝上流の指定が無い（push 先が決まっていない）。

```powershell
git worktree list
```

```text
C:/GitPractice/work         51fbc7b [main]
C:/GitPractice/wt-gone      51fbc7b [hotfix/gone] prunable
C:/GitPractice/wt-leftover  c2670ee [hotfix/leftover]
```

読み方：`prunable`＝記録は残っているがフォルダが無い（片付け候補）。

## 穴あき

下の `____` を埋めて実行してください。ヒントは右。

| 目的 | コマンド | ヒント |
|---|---|---|
| 短く・枝の情報つきで状態を見る | `git status ____` | 2 つの短縮オプションの組み合わせ（`notes/git.md`） |
| 上流の名前まで枝を見る | `git branch ____` | `-v` を 2 回 |
| 全部の枝を 1 枚の図で見る | `git log --graph --oneline ____ --decorate` | 「すべての参照」を表すオプション |
| 作業場を機械が読みやすい形で見る | `git worktree list ____` | 英語の `porcelain`（陶器）＝「出力の形が変わらない」の意味 |

## 予想

**コマンドを打つ前に**、下の 5 つを紙かメモに書いてください（ここが一番効きます）。

1. `main` は origin より ahead が **何**、behind が **何** か
2. 上流の指定が無い枝は **何本**（名前も）
3. 上流が `gone` の枝は **何本**
4. worktree は **何個**（`prunable` は何個）
5. 「二重」（同じ変更の commit）は、`log --graph` の図からどこにありそうか

そのあとで 4 つのコマンドを実行し、見比べる。外れたところが、この章でいちばん学べるところです。
答え合わせの見本は [run-log.md](run-log.md) の「00」（予想を書いてから開く）。

### 本物のリポジトリでやるとき

同じ 4 つを、自分の作業フォルダで **読むだけ**で使えます。注意：

- `git fetch` は書き換えの一種（origin の最新を取り込む）。ズレの数が変わるので、**fetch の前後どちらで数えたか**を書いておく。
- 数字を表にするなら、「測れなかった項目」は空欄ではなく **「測れていない」**と書く（0 件と読み違えない）。

## 自分の 1 行

> この章で分かったこと（自分の言葉で 1 行）：
>
> ＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿

（例の書き出し：「`git status -sb` の `ahead N, behind M` は……」）
