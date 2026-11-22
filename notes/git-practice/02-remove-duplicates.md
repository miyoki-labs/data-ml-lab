# 02 二重を外す — 退避の印 → `pull --rebase --autostash` → `range-diff`

## 場面

01 で、手元の 2 つは origin にある変更と二重だと分かりました。手元の `README: add usage line` だけが本当に自分の変更です。
さらに作業ツリーには未コミットの変更（`notes.md`）が残っています。

目標：**二重の 2 件を外し、自分の 1 件と未コミットの変更を無事に残したまま、origin の上に乗せ直す。**
書き換えるので、**先に戻れる印を付け、あとで「残すものが残った」ことを機械的に確かめる**のが手順の中心です。

> ⚠️ この章は **練習場だけ**で行います。本物のリポジトリでは、他の人（や別の作業場）が触っているかもしれない commit のハッシュを変えることになります。
> 本物でやるなら「未 push の commit が全部 24 時間より古い・ロックファイルが無い・上流がある」を確かめてからです（実際の片付けは別の機会に、予想を書いてから）。

## 見本

```powershell
cd C:/GitPractice/work

# 1. 退避の印（戻れる目印）。作業は進まない・ただの別名
git branch backup/before-rebase

# 2. origin の上に乗せ直す。二重は自動で飛ばされ、未コミットは一時退避→元に戻る
git pull --rebase --autostash
```

```text
Created autostash: e50435e
warning: skipped previously applied commit 4c11187
warning: skipped previously applied commit 97b24ae
hint: use --reapply-cherry-picks to include skipped commits
hint: Disable this message with "git config set advice.skippedCherryPicks false"
Rebasing (1/1)
Applied autostash.
Successfully rebased and updated refs/heads/main.
```

`skipped previously applied commit` が「二重を外した」印。`Created autostash` と `Applied autostash` が対になっていれば、未コミットの変更も戻っています。

### 確かめる（3 点）

```powershell
git status -sb                       # ① 作業ツリーが前と同じか
git cherry -v origin/main main       # ② 残ったのは本当に自分の変更だけか
git range-diff backup/before-rebase~1..backup/before-rebase origin/main..main   # ③ 残した 1 件の中身が前後で同じか
```

```text
## main...origin/main [ahead 1]
 M notes.md
?? scratch.txt
---
+ 16f6fc957940943c84c42e33cedf306b319c7b7b README: add usage line
---
1:  51fbc7b = 1:  16f6fc9 README: add usage line
```

読み方：
- ① `ahead 1`（二重の分が消えた）。`M notes.md` と `?? scratch.txt` は前と同じ＝未コミットは無事。
- ② `+` が 1 本だけ ＝ 残ったのは自分の変更。`-` が 0 本なので二重はもう無い。
- ③ `=` ＝ 退避の枝の 1 件と、rebase 後の 1 件は**中身が同じ**（ハッシュだけが変わった：`51fbc7b` → `16f6fc9`。rebase 後のハッシュは実行するたびに変わります）。

おまけ（二重が「対になって消える」ようすを一覧で見る）：

```powershell
git range-diff origin/main...backup/before-rebase
```

```text
1:  131432e = 1:  4c11187 report: add weekly total
2:  b373d34 = 2:  97b24ae add summary draft
3:  0d7fed6 < -:  ------- add changelog
-:  ------- > 3:  51fbc7b README: add usage line
```

`=` で対になっているのが二重、`<` は origin にだけ・`>` は退避の枝にだけある変更です。

## 穴あき

| 目的 | コマンド | ヒント |
|---|---|---|
| 戻れる目印の枝を作る | `git ____ backup/before-rebase` | 枝を作る（切り替えはしない）コマンド |
| 未コミットを自動で退避しつつ乗せ直す | `git pull ____ --autostash` | 「再び土台にする」を意味するオプション |
| 前後で中身が同じかを commit の組で比べる | `git ____ <旧の範囲> <新の範囲>` | 「範囲」と「差分」をつないだ名前 |
| 退避に使われた一時 stash が残っていないか | `git ____ list` | 「隠す」を意味する英語 |

## 予想

**打つ前に**書いてください。

1. `pull --rebase` のあと、`git log --oneline origin/main..main` は **何件**になるか
2. その 1 件のハッシュは `51fbc7b` の **まま**か・**変わる**か（理由を 1 行）
3. `notes.md` の未コミットの変更は、実行後に **残る**か・**消える**か
4. `range-diff` の記号は `=`・`<`・`>`・`!` のどれが出るか（`!` は「同じ件名だが中身が違う」）

もし **コンフリクトで止まったら**：`git rebase --abort` で元に戻せます（本物でも、まず止めて報告）。コンフリクトは 06 章で練習します。

実行ログ＝[run-log.md](run-log.md)「02」。

## 自分の 1 行

> 履歴を書き換える前に「退避の印」を付ける理由と、書き換えたあとに確かめる 3 点を 1 行で：
>
> ＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿
