# 実行ログ（答え合わせ用）

> ⚠️ **各章の「予想」を書いてから開く**こと。先に見ると予想の練習になりません。
> 取得：2026-11-21・git 2.49.0.windows.1・PowerShell 7.7・`scripts/git-practice-setup.ps1` で作った練習場。
> 日付を固定しているので、同じ手順なら 00・01 のハッシュは同じになります（rebase 後のハッシュは実行時刻で変わる）。
> 章を通した順＝作る → 00 → 01 → 02（02 で練習場が書き換わるので、やり直すなら `-Force`）。

## 00 診断

`git status -sb`

```text
## main...origin/main [ahead 3, behind 3]
 M notes.md
?? scratch.txt
```

`git branch -vv`

```text
  feature/merged-gone fec6101 [origin/feature/merged-gone: gone] feature: note
+ hotfix/gone         51fbc7b (C:/GitPractice/wt-gone) README: add usage line
+ hotfix/leftover     c2670ee (C:/GitPractice/wt-leftover) hotfix: note
* main                51fbc7b [origin/main: ahead 3, behind 3] README: add usage line
  wip/no-upstream     4560b64 wip: memo
```

`git worktree list`

```text
C:/GitPractice/work         51fbc7b [main]
C:/GitPractice/wt-gone      51fbc7b [hotfix/gone] prunable
C:/GitPractice/wt-leftover  c2670ee [hotfix/leftover]
```

`git worktree list --porcelain`（穴あきの答え。機械が読む用）

```text
worktree C:/GitPractice/wt-gone
HEAD 51fbc7be8681039dde9edd483892fbfdfb37a093
branch refs/heads/hotfix/gone
prunable gitdir file points to non-existent location
```

`git log --graph --oneline --all --decorate`

```text
* c2670ee (hotfix/leftover) hotfix: note
| * fec6101 (feature/merged-gone) feature: note
|/  
| * 4560b64 (wip/no-upstream) wip: memo
|/  
* 51fbc7b (HEAD -> main, hotfix/gone) README: add usage line
* 97b24ae add summary draft
* 4c11187 report: add weekly total
| * 0d7fed6 (origin/main, origin/HEAD) add changelog
| * b373d34 add summary draft
| * 131432e report: add weekly total
|/  
* a08393b add notes
* 830ac05 add report
* ddc818a init: README
```

予想欄の答え：ahead **3**・behind **3** ／ 上流なしの枝 **1 本**（`wip/no-upstream`）／ gone **1 本**（`feature/merged-gone`）／ worktree **3 個**（`prunable` は 1 個）／ 二重は図の左右に並ぶ同じ件名の組（`report: add weekly total`・`add summary draft`）。

## 01 二重 commit

`git cherry -v origin/main main`

```text
- 4c11187fafe72f11b550d287c24bd97e16e38427 report: add weekly total
- 97b24aeecf11e342629566a1bb19656a9e993677 add summary draft
+ 51fbc7be8681039dde9edd483892fbfdfb37a093 README: add usage line
```

`git show <hash> | git patch-id --stable`（同じ件名の組は一致・別の件名は不一致）

```text
4fc7570ff2d8cead2e595871750c0be395c27f06 4c11187fafe72f11b550d287c24bd97e16e38427
4fc7570ff2d8cead2e595871750c0be395c27f06 131432ef1a2db5f469467369cc69fd8a018509ea
da2ebfed0592c7d855b41d863bf470f11ea717ac 51fbc7be8681039dde9edd483892fbfdfb37a093   ← README の commit（origin に同じ指紋が無い）
6acff384dbe071efc5a0112c658c1672a4d8d9a4 0d7fed66f8c6db8215e33a9abdcfb9e1d8ff8136   ← changelog（origin にだけある）
```

`git cat-file -p`（2 つの commit の違いは `committer` の 1 行だけ）

```text
tree ecbaf087aede6f41da09c3830935943e0fadf5e6
parent a08393bbfc0f851a457025f57ec33aabdaeecd9e
author Practice User <practice@example.invalid> 1793497200 +0900
committer Practice User <practice@example.invalid> 1793497200 +0900      ← 4c11187（手元）

committer Practice User <practice@example.invalid> 1793499000 +0900      ← 131432e（origin）
```

予想欄の答え：3 行・`-` が 2 個、`+` が 1 個 ／ 2 組とも一致 ／ README の commit は origin に無い（`+`）／ 違うのは `committer` の行だけ。

## 02 二重を外す

```text
$ git branch backup/before-rebase
$ git branch --list 'backup/*' -v
  backup/before-rebase 51fbc7b README: add usage line

$ git pull --rebase --autostash
Created autostash: e50435e
warning: skipped previously applied commit 4c11187
warning: skipped previously applied commit 97b24ae
hint: use --reapply-cherry-picks to include skipped commits
hint: Disable this message with "git config set advice.skippedCherryPicks false"
Rebasing (1/1)
Applied autostash.
Successfully rebased and updated refs/heads/main.

$ git status -sb
## main...origin/main [ahead 1]
 M notes.md
?? scratch.txt

$ git cherry -v origin/main main
+ 16f6fc957940943c84c42e33cedf306b319c7b7b README: add usage line

$ git range-diff backup/before-rebase~1..backup/before-rebase origin/main..main
1:  51fbc7b = 1:  16f6fc9 README: add usage line

$ git range-diff origin/main...backup/before-rebase
1:  131432e = 1:  4c11187 report: add weekly total
2:  b373d34 = 2:  97b24ae add summary draft
3:  0d7fed6 < -:  ------- add changelog
-:  ------- > 3:  51fbc7b README: add usage line

$ git stash list
（出力なし＝autostash は戻して消えた）
```

予想欄の答え：1 件 ／ ハッシュは**変わる**（親が変わるため。中身は同じ）／ 未コミットは**残る** ／ `=`（`!` ではない）。

## スクリプトの安全装置（確認済み）

- `-Force` なしで再実行 → 「もうあります」で停止。
- 目印ファイル（`.git-practice-sandbox`）の無いフォルダに `-Force` → 消さずに停止（捨てフォルダで検証・中身は残った）。
- 別の git リポジトリの中を `-Root` にすると停止（入れ子の防止）。※この経路は未検証。
