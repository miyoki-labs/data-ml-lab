#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"

wait_max=${COLLECT_WAIT_MAX:-120}
wait_step=${COLLECT_WAIT_STEP:-5}
interval=${COLLECT_INTERVAL:-15}
log_file="logs/collect-$(date +%Y%m%d).log"
mkdir -p logs

emit() {
  local line=$1
  printf '%s\n' "$line"
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$line" >> "$log_file"
}

run_sql() {
  # NOCOUNT＝「(N rows affected)」を出させない（数字だけを受け取るため）
  local query="SET NOCOUNT ON; $1"
  local output status
  set +e
  output=$(docker exec mssql bash -c 'export SQLCMDPASSWORD="$MSSQL_SA_PASSWORD"; /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -d lab -b -h -1 -W -Q "$1"' bash "$query" 2>/dev/null)
  status=$?
  set -e
  if ((status != 0)); then
    return "$status"
  fi
  printf '%s' "$output"
}

is_running=$(docker inspect -f '{{.State.Running}}' mssql 2>/dev/null || true)
if [[ $is_running != true ]]; then
  docker start mssql >/dev/null 2>&1 || true
fi

ready=0
elapsed=0
while ((elapsed < wait_max)); do
  if run_sql 'SELECT 1' >/dev/null; then
    ready=1
    break
  fi
  sleep "$wait_step"
  elapsed=$((elapsed + wait_step))
done

if ((ready == 0)); then
  emit START
  emit 'mssql not ready'
  emit 'END exit=3'
  exit 3
fi

codes=()
invalid_lines=0
while IFS= read -r code || [[ -n $code ]]; do
  code=${code%$'\r'}
  [[ -z ${code//[[:space:]]/} || $code == \#* ]] && continue
  # fetch_one と同じ形だけ受け付ける（それ以外の文字列を画面やログに出さないため）
  if [[ $code =~ ^[0-9A-Z]{4,5}$ ]]; then
    codes+=("$code")
  else
    invalid_lines=$((invalid_lines + 1))
  fi
done < collector/codes.txt

if ((${#codes[@]} == 0)); then
  emit START
  if ((invalid_lines > 0)); then
    emit 'invalid line in collector/codes.txt'
    emit 'END exit=1'
    exit 1
  fi
  emit 'no codes in collector/codes.txt'
  emit 'END exit=2'
  exit 2
fi

emit START

schema_query="IF OBJECT_ID('prices_raw', 'U') IS NULL CREATE TABLE prices_raw ([Date] VARCHAR(20), [Code] VARCHAR(10), O VARCHAR(30), H VARCHAR(30), L VARCHAR(30), C VARCHAR(30), UL VARCHAR(30), LL VARCHAR(30), Vo VARCHAR(30), Va VARCHAR(30), AdjFactor VARCHAR(30), AdjO VARCHAR(30), AdjH VARCHAR(30), AdjL VARCHAR(30), AdjC VARCHAR(30), AdjVo VARCHAR(30), MktCap VARCHAR(30), ExRT VARCHAR(30)); IF OBJECT_ID('prices', 'U') IS NULL CREATE TABLE prices (code VARCHAR(5) NOT NULL, trade_date DATE NOT NULL, open_price DECIMAL(12,2), high_price DECIMAL(12,2), low_price DECIMAL(12,2), close_price DECIMAL(12,2), volume BIGINT, CONSTRAINT PK_prices PRIMARY KEY (code, trade_date));"
if ! run_sql "$schema_query" >/dev/null; then
  emit 'mssql not ready'
  emit 'END exit=3'
  exit 3
fi

failed=0
if ((invalid_lines > 0)); then
  emit 'invalid line in collector/codes.txt'
  failed=1
fi
first=1
for code in "${codes[@]}"; do
  if ((first == 0)); then
    sleep "$interval"
  fi
  first=0

  csv="data/bars_${code}.csv"
  fetch_status=0
  docker compose run --rm app python -m collector.fetch_one "$code" --save "$csv" >/dev/null 2>&1 || fetch_status=$?
  if ((fetch_status != 0)); then
    emit "$code FAILED stage=fetch exit=$fetch_status"
    failed=1
    continue
  fi

  fetched=$(($(wc -l < "$csv") - 1))
  load_status=0
  # BULK INSERT は列の位置で入れるので、見出しが想定と違えば取り込まない（値が別の列に静かに入るのを防ぐ）
  header=$(head -n 1 "$csv")
  if [[ ${header%$'\r'} != "Date,Code,O,H,L,C,UL,LL,Vo,Va,AdjFactor,AdjO,AdjH,AdjL,AdjC,AdjVo,MktCap,ExRT" ]]; then
    load_status=4
  else
    docker cp "$csv" "mssql:/tmp/bars_${code}.csv" >/dev/null 2>&1 || load_status=$?
  fi
  if ((load_status == 0)); then
    load_query="TRUNCATE TABLE prices_raw; BULK INSERT prices_raw FROM '/tmp/bars_${code}.csv' WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a'); INSERT INTO prices (code, trade_date, open_price, high_price, low_price, close_price, volume) SELECT r.Code, CAST(r.[Date] AS DATE), CAST(r.O AS DECIMAL(12,2)), CAST(r.H AS DECIMAL(12,2)), CAST(r.L AS DECIMAL(12,2)), CAST(r.C AS DECIMAL(12,2)), CAST(CAST(r.Vo AS DECIMAL(20,2)) AS BIGINT) FROM prices_raw r WHERE NOT EXISTS (SELECT 1 FROM prices p WHERE p.code = r.Code AND p.trade_date = CAST(r.[Date] AS DATE)); SELECT @@ROWCOUNT;"
    inserted=$(run_sql "$load_query" 2>/dev/null) || load_status=$?
    inserted=${inserted//$'\r'/}
    inserted=${inserted//$'\n'/}
    inserted=${inserted//[[:space:]]/}
    if ((load_status == 0)) && [[ ! $inserted =~ ^[0-9]+$ ]]; then
      load_status=5
    fi
  fi
  if ((load_status != 0)); then
    emit "$code FAILED stage=load exit=$load_status"
    failed=1
    continue
  fi
  emit "$code fetched=$fetched inserted=$inserted"
done

total=$(run_sql 'SELECT COUNT(*) FROM prices' 2>/dev/null) || {
  emit 'mssql not ready'
  emit 'END exit=3'
  exit 3
}
total=${total//$'\r'/}
total=${total//$'\n'/}
total=${total//[[:space:]]/}
if [[ ! $total =~ ^[0-9]+$ ]]; then
  emit 'mssql not ready'
  emit 'END exit=3'
  exit 3
fi
emit "total rows=$total"
if ((failed != 0)); then
  emit 'END exit=1'
  exit 1
fi
emit 'END exit=0'
