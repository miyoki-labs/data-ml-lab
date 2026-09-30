#!/usr/bin/env bash
# API キーの値が、リポジトリのファイルとログに何件含まれるかを数える（キーの値は表示しない）。
#   使い方: check-secret-leak.sh [--key-file F] [--root DIR] [LOG ...]
#           check-secret-leak.sh --selftest   # ダミーのキーを検出できるかの対照
#   終了コード: 0 漏れ0件（selftest は検出できた）／1 漏れあり（selftest は検出できなかった）／2 検査できない
set -uo pipefail

key_file=/run/secrets/jquants_env
root=/app
selftest=0
logs=()

while (($#)); do
  case "$1" in
    --key-file | --root)
      if (($# < 2)); then echo "$1 に値が無い" >&2; exit 2; fi
      [[ $1 == --key-file ]] && key_file=$2 || root=$2
      shift 2
      ;;
    --selftest) selftest=1; shift ;;
    -*) echo "未知のオプション: $1" >&2; exit 2 ;;
    *) logs+=("$1"); shift ;;
  esac
done

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
pattern=$workdir/pattern

# キーの行がちょうど1行・値が空でないときだけ検査する（読めないまま「0件」で合格にしない）
load_key() {
  local count
  count=$(grep -c '^JQUANTS_API_KEY=' "$1" 2>/dev/null) || true
  if [[ $count != 1 ]]; then echo "キーを1つに特定できない（検査できない）" >&2; exit 2; fi
  sed -n 's/^JQUANTS_API_KEY=//p' "$1" | tr -d '"\r' > "$pattern"
  if [[ -z $(tr -d '[:space:]' < "$pattern") ]]; then echo "キーの値が空（検査できない）" >&2; exit 2; fi
}

count_in() {
  grep -rFo -f "$pattern" --exclude-dir=.git -- "$@" 2>/dev/null | wc -l
}

if ((selftest)); then
  echo 'JQUANTS_API_KEY=DUMMY-LEAK-CANARY-0001' > "$workdir/key"
  echo 'something printed DUMMY-LEAK-CANARY-0001 by mistake' > "$workdir/log"
  load_key "$workdir/key"
  found=$(count_in "$workdir/log")
  if ((found >= 1)); then echo "対照: ダミーのキーを検出できた（${found}件）"; exit 0; fi
  echo "対照: ダミーのキーを検出できなかった" >&2
  exit 1
fi

for log in "${logs[@]}"; do
  if [[ ! -f $log ]]; then echo "ログが無い: $log" >&2; exit 2; fi
done
if [[ ! -d $root ]]; then echo "検査する場所が無い: $root" >&2; exit 2; fi

load_key "$key_file"
in_root=$(count_in "$root")
in_logs=0
if ((${#logs[@]})); then in_logs=$(count_in "${logs[@]}"); fi

echo "ファイル: ${in_root}件 ／ ログ: ${in_logs}件"
if ((in_root + in_logs > 0)); then exit 1; fi
exit 0
