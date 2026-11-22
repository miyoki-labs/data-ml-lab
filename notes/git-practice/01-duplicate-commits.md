# 01 二重 commit — 「同じ変更なのにハッシュが違う」を見分ける

## 場面

00 で `ahead 3, behind 3` と出ました。手元の 3 つと origin の 3 つは、**全部が別の変更**とは限りません。
別の経路（別の作業場・別の人・`cherry-pick`）で同じ変更が入っていると、**中身は同じなのにハッシュが違う commit** が両側に並びます。これを「二重」と呼びます。

二重のまま `merge` すると同じ変更が 2 回並び、`rebase` すると git が自動で外してくれます。
**外す前に、本当に二重か（＝変更の中身が同じか）を自分の目で確かめる**のがこの章です。

## 見本

```powershell
cd C:/GitPractice/work
git log --oneline origin/main..main     # 手元だけにある
git log --oneline main..origin/main     # origin だけにある
```

```text
51fbc7b README: add usage line
97b24ae add summary draft
4c11187 report: add weekly total
---
0d7fed6 add changelog
b373d34 add summary draft
131432e report: add weekly total
```

件名が同じ組（`report: add weekly total` と `add summary draft`）が怪しい。件名は同じでも**別物**のことがあるので、中身で確かめます。

### ① `git cherry` ＝「origin に同じ変更があるか」を 1 行ずつ

```powershell
git cherry -v origin/main main
```

```text
- 4c11187fafe72f11b550d287c24bd97e16e38427 report: add weekly total
- 97b24aeecf11e342629566a1bb19656a9e993677 add summary draft
+ 51fbc7be8681039dde9edd483892fbfdfb37a093 README: add usage line
```

`-`＝上流に**同じ変更がある**（二重）、`+`＝上流に**無い**（本当に自分だけの変更）。

### ② `patch-id` ＝「変更の指紋」を並べて見る

```powershell
git show 4c11187 | git patch-id --stable
git show 131432e | git patch-id --stable
```

```text
4fc7570ff2d8cead2e595871750c0be395c27f06 4c11187fafe72f11b550d287c24bd97e16e38427
4fc7570ff2d8cead2e595871750c0be395c27f06 131432ef1a2db5f469467369cc69fd8a018509ea
```

左の列（指紋）が一致 ＝同じ変更。`git cherry` は内部でこの比較をしています。

### ③ ハッシュが違う理由

```powershell
git log -1 --format='%h author=%ad committer=%cd parent=%p' --date=iso 4c11187
git log -1 --format='%h author=%ad committer=%cd parent=%p' --date=iso 131432e
```

```text
4c11187 author=2026-11-01 10:40:00 +0900 committer=2026-11-01 10:40:00 +0900 parent=a08393b
131432e author=2026-11-01 10:40:00 +0900 committer=2026-11-01 11:10:00 +0900 parent=a08393b
```

親も変更の中身も作者の日時も同じで、**コミッター日時だけ**が違う。ハッシュは「commit の全項目」から計算されるので、1 項目の違いで別物になります。

## 穴あき

| 目的 | コマンド | ヒント |
|---|---|---|
| 手元だけにある commit を出す | `git log --oneline ____..main` | 比べる相手（上流）の名前 |
| 上流にあるか、変更の中身で調べる | `git ____ -v origin/main main` | 「サクランボを摘む」を意味する英語（`cherry-pick` の仲間） |
| 変更の指紋を出す | `git show <hash> \| git ____ --stable` | 「パッチ」＋「ID」の 2 語をつなげた名前 |
| commit の中身（親・作者・コミッター）を生で見る | `git cat-file ____ <hash>` | 「中身を整形して表示」の 1 文字オプション |

## 予想

**打つ前に**書いてください。

1. `git cherry -v origin/main main` は **何行**出て、`-` と `+` は **それぞれ何個**か
2. 件名が同じ 2 組の `patch-id` は、**一致する**か（理由も 1 行）
3. 手元の `README: add usage line` に対応する commit は origin に **あるか**（`+` か `-` か）
4. `cat-file -p` で 2 つの commit を比べたとき、**違う行はどれか**（`tree`・`parent`・`author`・`committer`・件名のうち）

予想のあと、見本と同じコマンドを実行して見比べます。
実行ログ＝[run-log.md](run-log.md)「01」。

## 自分の 1 行

> 二重 commit を見分けるときの手順を、自分の言葉で 1 行（「件名」ではなく何で判断するか）：
>
> ＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿
