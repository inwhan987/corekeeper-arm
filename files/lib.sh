# shellcheck shell=bash
# =====================================================================
#  lib.sh — 공통 함수. ck · watchdog.sh · checkupdate.sh · nightly.sh 가
#  source 해서 씁니다. 직접 실행하는 파일이 아닙니다.
# =====================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVF="$DIR/core.env"
CON=core-keeper-dedicated
APPID=1963720
STATE="$DIR/.state";       mkdir -p "$STATE"
BACKUP_DIR="$DIR/backups"; mkdir -p "$BACKUP_DIR"
D="sudo docker"

getenv(){ grep -E "^$1=" "$ENVF" 2>/dev/null | tail -1 | cut -d= -f2-; }
HOOK=$(getenv DISCORD_WEBHOOK_URL)

# ------------------------------------------------------------- 디스코드
send(){   # send <제목> <내용> <색상>
  [ -n "$HOOK" ] || return 0
  python3 -c '
import sys, json, datetime
print(json.dumps({"embeds":[{"title":sys.argv[1],"description":sys.argv[2],
 "color":int(sys.argv[3]),
 "timestamp":datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00","Z")}]}))
' "$1" "$2" "$3" | curl -s -m 10 -H "Content-Type: application/json" --data-binary @- "$HOOK" >/dev/null
}
C_INFO=16752640   # 주황
C_BAD=15158332    # 빨강
C_OK=3066993      # 초록

# ----------------------------------------------------------------- 상태
running(){ [ "$($D inspect -f '{{.State.Running}}' "$CON" 2>/dev/null)" = "true" ]; }
server_proc(){ pgrep -f CoreKeeperServer >/dev/null 2>&1; }

public_ip(){
  local ip
  ip=$(cat "$STATE/public_ip" 2>/dev/null)
  [ -n "$ip" ] && { echo "$ip"; return; }
  ip=$(curl -s -m 8 ifconfig.me 2>/dev/null)
  [ -n "$ip" ] && echo "$ip" > "$STATE/public_ip"
  echo "${ip:-<서버IP>}"
}

game_id(){ cat "$DIR/server-files/GameID.txt" 2>/dev/null | tr -d '\r\n '; }

connect_info(){
  local port; port=$(getenv SERVER_PORT)
  if [ -n "$port" ]; then
    echo "직접 접속  $(public_ip):$port"
  else
    echo "게임 ID   $(game_id)"
  fi
}

# ----------------------------------------------------------------- 빌드
latest_build(){
  curl -s -m 15 "https://api.steamcmd.net/v1/info/${APPID}" 2>/dev/null \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['${APPID}']['depots']['branches']['public']['buildid'])" 2>/dev/null
}
installed_build(){
  # SteamCMD 로 받았으면 appmanifest 에, Depot Downloader 면 우리가 남긴 기록에 있다
  local b
  b=$(grep -m1 '"buildid"' "$DIR/server-files/steamapps/appmanifest_${APPID}.acf" 2>/dev/null \
      | tr -d '"' | awk '{print $2}')
  [ -n "$b" ] || b=$(cat "$STATE/installed_build" 2>/dev/null)
  echo "$b"
}
record_build(){ local b; b=$(latest_build); [ -n "$b" ] && echo "$b" > "$STATE/installed_build"; return 0; }

# ------------------------------------------------------------ 기동 대기
now_utc(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

wait_ready(){   # wait_ready <최대초> <기준시각>  — 기준시각 이후 로그에 "접속 대기" 가 뜰 때까지
  # 에뮬레이션 + 모드 컴파일 때문에 10분 넘게 걸릴 수 있다
  local max=${1:-3600} since=${2:-$(now_utc)} t=0
  while [ $t -lt "$max" ]; do
    if $D logs --since "$since" "$CON" 2>&1 \
         | grep -qE "Listening on ip|Started session|Game ID"; then
      return 0
    fi
    if $D logs --since "$since" "$CON" 2>&1 | grep -qE "Segmentation fault|SIGSEGV"; then
      return 2     # 기동 중 크래시
    fi
    sleep 15; t=$((t + 15))
    [ $((t % 60)) -eq 0 ] && printf "."
  done
  return 1
}

# ------------------------------------------------------- 업데이트 허가
# UPDATE_GATE_ENABLED=true 이면 컨테이너는 평소 업데이트 확인(파일 검사)을 건너뛰고,
# 이 파일에 1시간 이내의 시각이 적혀 있을 때만 업데이트한다. 사용 후 컨테이너가 지운다.
grant_update(){
  mkdir -p "$DIR/update-control"
  date +%s > "$DIR/update-control/apply-update"
}

# ----------------------------------------------------------------- 백업
backup_world(){   # 월드 백업 — 최근 7개만 보관
  [ -d "$DIR/server-data" ] || return 0
  local ts f
  ts=$(date +%Y%m%d_%H%M%S)
  f="$BACKUP_DIR/world_$ts.tar.gz"
  sudo tar czf "$f" -C "$DIR" server-data 2>/dev/null || return 1
  sudo chown "$(id -u):$(id -g)" "$f"
  ls -1t "$BACKUP_DIR"/world_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
  echo "$f"
}
