#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
original_codes=$test_root/original-codes.txt
cp "$root_dir/collector/codes.txt" "$original_codes"
mkdir -p "$test_root/scripts" "$test_root/collector" "$test_root/data" "$test_root/logs"
cp "$root_dir/scripts/collect_daily.sh" "$test_root/scripts/collect_daily.sh"
chmod +x "$test_root/scripts/collect_daily.sh"
trap 'rm -rf "$test_root"' EXIT

snapshot_tree() {
  local dir=$1
  if [[ ! -d $dir ]]; then
    printf 'MISSING\n'
    return
  fi
  find "$dir" -mindepth 1 -printf '%y %p %s\n' | sort
  while IFS= read -r file; do
    sha256sum "$file"
  done < <(find "$dir" -type f -print | sort)
}

snapshot_tree "$root_dir/data" > "$test_root/real-data.before"
snapshot_tree "$root_dir/logs" > "$test_root/real-logs.before"
fake_docker_log=$test_root/docker.log
fake_sleep_log=$test_root/sleep.log

assert_contains() { grep -Eq "$2" "$1"; }
assert_not_contains() { ! grep -Eq "$2" "$1"; }
assert_status() { [[ $1 -eq $2 ]]; }

cat > "$test_root/docker" <<'FAKE_DOCKER'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${FAKE_DOCKER_LOG:?}"
printf 'PRICE-123.4\n' >&2
case "$1" in
  inspect) printf 'false\n' ;;
  start) printf 'mssql\n' ;;
  exec)
    query=${*: -1}
    if [[ ${FAKE_READY:-1} == 0 ]]; then exit 1; fi
    # 本物の sqlcmd と同じく、NOCOUNT が無ければ「(N rows affected)」を混ぜる
    if [[ $query == 'SET NOCOUNT ON; '* ]]; then
      query=${query#'SET NOCOUNT ON; '}
    else
      printf '(1 rows affected)\n'
    fi
    if [[ $query == 'SELECT 1' ]]; then printf '1\n'; exit 0; fi
    if [[ ${FAKE_LOAD_FAIL:-0} == 1 && $query == *'BULK INSERT'* ]]; then exit 8; fi
    if [[ $query == *'COUNT(*)'* ]]; then printf '2\n'; else printf '1\n'; fi
    ;;
  cp)
    ;;
  compose)
    if [[ ${FAKE_FETCH_FAIL_CODE:-} == 25590 && $* == *'25590'* ]]; then exit 7; fi
    save_path=${*: -1}
    mkdir -p "$(dirname "$save_path")"
    if [[ ${FAKE_BAD_HEADER:-0} == 1 ]]; then
      printf 'Date,Code,Vo,O,H,L,C\n' > "$save_path"
    else
      printf 'Date,Code,O,H,L,C,UL,LL,Vo,Va,AdjFactor,AdjO,AdjH,AdjL,AdjC,AdjVo,MktCap,ExRT\n' > "$save_path"
    fi
    ;;
esac
FAKE_DOCKER
chmod +x "$test_root/docker"
cat > "$test_root/sleep" <<'FAKE_SLEEP'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "${FAKE_SLEEP_LOG:?}"
FAKE_SLEEP
chmod +x "$test_root/sleep"

run_case() {
  local name=$1 codes=$2 expected=$3
  printf '%s\n' "$codes" > "$test_root/collector/codes.txt"
  rm -rf "$test_root/logs" "$test_root/data"
  mkdir -p "$test_root/logs" "$test_root/data"
  : > "$fake_docker_log"
  : > "$fake_sleep_log"
  set +e
  PATH="$test_root:$PATH" FAKE_DOCKER_LOG="$fake_docker_log" FAKE_SLEEP_LOG="$fake_sleep_log" COLLECT_WAIT_MAX=2 COLLECT_WAIT_STEP=1 COLLECT_INTERVAL=7 "$test_root/scripts/collect_daily.sh" > "$test_root/$name.out"
  status=$?
  set -e
  assert_status "$status" "$expected"
  log_file="$test_root/logs/collect-$(date +%Y%m%d).log"
  if grep -Ev '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{4} (START|[0-9A-Z]+ fetched=[0-9]+ inserted=[0-9]+|[0-9A-Z]+ FAILED stage=(fetch|load) exit=[0-9]+|total rows=[0-9]+|END exit=[0-9]+|no codes in collector/codes.txt|invalid line in collector/codes.txt|mssql not ready)$' "$log_file" | grep -q .; then
    return 1
  fi
  assert_not_contains "$log_file" 'PRICE-[0-9.]+'
  cmp -s "$original_codes" "$root_dir/collector/codes.txt"
}

bash -n "$root_dir/scripts/collect_daily.sh"
run_case success $'25590\n\n# ignored\n12340' 0
assert_contains "$test_root/success.out" '^25590 fetched=0 inserted=1$'
assert_contains "$test_root/success.out" '^12340 fetched=0 inserted=1$'
assert_contains "$test_root/success.out" '^total rows=2$'
assert_contains "$test_root/success.out" '^END exit=0$'
[[ $(wc -l < "$fake_sleep_log") -eq 1 ]] && [[ $(<"$fake_sleep_log") == 7 ]]

export FAKE_FETCH_FAIL_CODE=25590
run_case fetch_fail $'25590\n12340' 1
unset FAKE_FETCH_FAIL_CODE
assert_contains "$test_root/fetch_fail.out" '^25590 FAILED stage=fetch exit=7$'
assert_contains "$test_root/fetch_fail.out" '^12340 fetched=0 inserted=1$'

export FAKE_LOAD_FAIL=1
run_case load_fail $'25590\n12340' 1
unset FAKE_LOAD_FAIL
export FAKE_BAD_HEADER=1
run_case bad_header $'25590' 1
unset FAKE_BAD_HEADER
assert_contains "$test_root/bad_header.out" '^25590 FAILED stage=load exit=4$'
assert_contains "$test_root/load_fail.out" '^25590 FAILED stage=load exit=8$'
assert_contains "$test_root/load_fail.out" '^12340 FAILED stage=load exit=8$'

run_case invalid_line $'BAD!\n25590' 1
assert_contains "$test_root/invalid_line.out" '^invalid line in collector/codes.txt$'
assert_contains "$test_root/invalid_line.out" '^25590 fetched=0 inserted=1$'
assert_not_contains "$test_root/invalid_line.out" 'BAD!'
run_case only_invalid $'BAD!\n# ignored' 1
assert_contains "$test_root/only_invalid.out" '^invalid line in collector/codes.txt$'
assert_contains "$test_root/only_invalid.out" '^END exit=1$'
assert_not_contains "$test_root/only_invalid.out" 'BAD!'
run_case no_codes $'\n# ignored' 2
assert_contains "$test_root/no_codes.out" '^no codes in collector/codes.txt$'

set +e
: > "$fake_docker_log"
PATH="$test_root:$PATH" FAKE_DOCKER_LOG="$fake_docker_log" FAKE_SLEEP_LOG="$fake_sleep_log" FAKE_READY=0 COLLECT_WAIT_MAX=2 COLLECT_WAIT_STEP=1 "$test_root/scripts/collect_daily.sh" > "$test_root/not_ready.out"
status=$?
set -e
assert_status "$status" 3
assert_contains "$test_root/not_ready.out" '^mssql not ready$'
[[ $(grep -c '^exec ' "$fake_docker_log") -le 2 ]]

for output in "$test_root"/*.out; do
  assert_not_contains "$output" 'PRICE-[0-9.]+'
done
snapshot_tree "$root_dir/data" > "$test_root/real-data.after"
snapshot_tree "$root_dir/logs" > "$test_root/real-logs.after"
cmp -s "$test_root/real-data.before" "$test_root/real-data.after"
cmp -s "$test_root/real-logs.before" "$test_root/real-logs.after"
cmp -s "$original_codes" "$root_dir/collector/codes.txt"
printf 'PASS\n'
