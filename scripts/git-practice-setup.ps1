<#
.SYNOPSIS
  実戦形式 Git 教材（notes/git-practice/）の練習場を作る。本物のリポジトリには触らない。

.DESCRIPTION
  Root（既定 C:/GitPractice）の下に、荒れたリポジトリを丸ごと作る。
    origin.git            保管専用（GitHub の代わり）
    work                  練習する作業フォルダ
                          ・main が origin と分岐している（手元が先・origin も先）
                          ・同じ内容で別ハッシュのコミットがある（二重）
                          ・上流なしの枝／上流が消えた枝（gone）がある
                          ・未コミットの変更と未追跡のファイルがある
    other                 「別の人」の作業フォルダ（origin へ先に push する役）
    wt-leftover / wt-gone work の別の作業フォルダ（wt-gone はフォルダを消してある）
  日付を固定しているので、同じ手順なら同じハッシュになる。
  練習場の git にだけ、フック（core.hooksPath）を空にする設定を入れる。本物の push の関所に引っかからないため。

.EXAMPLE
  pwsh -File scripts/git-practice-setup.ps1
  pwsh -File scripts/git-practice-setup.ps1 -Force    # 作り直す（Root の中身は消える）
#>
param(
  [string]$Root = 'C:/GitPractice',
  [switch]$Force
)
$ErrorActionPreference = 'Stop'

# git を呼んで、失敗したら止める（出力は文字列で返す）
function G {
  $o = & git @args 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ('git ' + ($args -join ' ') + ' が失敗: ' + (($o | ForEach-Object { "$_" }) -join [Environment]::NewLine))
  }
  $o | ForEach-Object { "$_" }
}

$Root = $Root -replace '\\', '/'
$marker = "$Root/.git-practice-sandbox"

if (Test-Path -LiteralPath $Root) {
  if (-not $Force) { throw "$Root はもうあります。作り直すなら -Force（中身は消えます）" }
  if (-not (Test-Path -LiteralPath $marker)) { throw "$Root に目印ファイルが無いので消しません（練習場ではない可能性）" }
  Remove-Item -LiteralPath $Root -Recurse -Force
}
New-Item -ItemType Directory -Path $Root -Force | Out-Null

# 別の git リポジトリの中に作ると入れ子になる＝止める
& git -C $Root rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -eq 0) {
  Remove-Item -LiteralPath $Root -Force
  throw "$Root は別の git リポジトリの中です。リポジトリの外を -Root に指定してください"
}
[IO.File]::WriteAllText($marker, "git practice sandbox`n")
$hooks = "$Root/.nohooks"
New-Item -ItemType Directory -Path $hooks | Out-Null

$nl = [string][char]10
$script:clock = [datetimeoffset]::new(2026, 11, 1, 10, 0, 0, [timespan]::FromHours(9))
function Get-NextDate {
  $script:clock = $script:clock.AddMinutes(10)
  $script:clock.ToString("yyyy-MM-dd'T'HH:mm:sszzz", [Globalization.CultureInfo]::InvariantCulture)
}

function Set-Identity([string]$Dir) {
  G -C $Dir config user.name 'Practice User' | Out-Null
  G -C $Dir config user.email 'practice@example.invalid' | Out-Null
  G -C $Dir config core.hooksPath $hooks | Out-Null
  G -C $Dir config core.autocrlf false | Out-Null
  G -C $Dir config commit.gpgsign false | Out-Null
  G -C $Dir config pull.rebase false | Out-Null
}

# ファイルを書いて、そのファイルだけを commit する（日付は固定の時計で進める）
function Save-Commit([string]$Dir, [string]$File, [string]$Text, [string]$Message, [switch]$Append) {
  $path = "$Dir/$File"
  if ($Append) { [IO.File]::AppendAllText($path, $Text + $nl) } else { [IO.File]::WriteAllText($path, $Text + $nl) }
  $d = Get-NextDate
  $env:GIT_AUTHOR_DATE = $d
  $env:GIT_COMMITTER_DATE = $d
  try {
    G -C $Dir add $File | Out-Null
    G -C $Dir commit -q -m $Message | Out-Null
  } finally {
    Remove-Item Env:GIT_AUTHOR_DATE, Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
  }
}

$origin = "$Root/origin.git"
$work = "$Root/work"
$other = "$Root/other"

# 1. 保管専用の origin と、最初の 3 コミット
G init -q --bare -b main $origin | Out-Null
G init -q -b main $work | Out-Null
Set-Identity $work
Save-Commit $work 'README.md' '# practice' 'init: README'
Save-Commit $work 'report.txt' 'report: line 1' 'add report'
Save-Commit $work 'notes.md' '# notes' 'add notes'
G -C $work remote add origin $origin | Out-Null
G -C $work push -q -u origin main | Out-Null

# 2. 「別の人」の作業フォルダ
# 改行の自動変換を clone の時点から切る（後から切ると checkout 済みのファイルが「変更あり」に見える）
G clone -q -c core.autocrlf=false $origin $other | Out-Null
Set-Identity $other

# 3. work に、まだ push していないコミットを 3 つ（L1・L2・L3）
Save-Commit $work 'report.txt' 'weekly total: 120' 'report: add weekly total' -Append
Save-Commit $work 'summary.txt' 'summary: first draft' 'add summary draft'
Save-Commit $work 'README.md' 'usage: see notes.md' 'README: add usage line' -Append
$l1 = G -C $work rev-parse 'HEAD~2'
$l2 = G -C $work rev-parse 'HEAD~1'

# 4. other が L1・L2 を cherry-pick して先に push する（＝二重）＋ other だけの 1 件
G -C $other fetch -q $work main | Out-Null
foreach ($sha in @($l1, $l2)) {
  $env:GIT_COMMITTER_DATE = Get-NextDate
  try { G -C $other cherry-pick $sha | Out-Null } finally { Remove-Item Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue }
}
Save-Commit $other 'changelog.txt' 'changelog: start' 'add changelog'
G -C $other push -q origin main | Out-Null
G -C $work fetch -q origin | Out-Null

# 5. 上流なしの枝
G -C $work switch -q -c wip/no-upstream | Out-Null
Save-Commit $work 'wip.txt' 'wip memo' 'wip: memo'
G -C $work switch -q main | Out-Null

# 6. 上流が消えた枝（gone）：push して、other が origin 側で消し、work が prune する
G -C $work switch -q -c feature/merged-gone | Out-Null
Save-Commit $work 'feature.txt' 'feature note' 'feature: note'
G -C $work push -q -u origin feature/merged-gone | Out-Null
G -C $work switch -q main | Out-Null
G -C $other push -q origin --delete feature/merged-gone | Out-Null
G -C $work fetch -q --prune | Out-Null

# 7. worktree の残り：wt-leftover は生きている／wt-gone はフォルダを消してある
G -C $work worktree add -q "$Root/wt-leftover" -b hotfix/leftover | Out-Null
Save-Commit "$Root/wt-leftover" 'hotfix.txt' 'hotfix note' 'hotfix: note'
G -C $work worktree add -q "$Root/wt-gone" -b hotfix/gone | Out-Null
Remove-Item -LiteralPath "$Root/wt-gone" -Recurse -Force

# 8. 未コミットの変更と未追跡のファイル
[IO.File]::AppendAllText("$work/notes.md", 'TODO: next week' + $nl)
[IO.File]::WriteAllText("$work/scratch.txt", 'scratch' + $nl)

Write-Output "練習場ができました: $Root"
Write-Output "  作業フォルダ: $work"
Write-Output "  次は notes/git-practice/00-diagnose.md を開いて、予想を書いてから確かめてください"
