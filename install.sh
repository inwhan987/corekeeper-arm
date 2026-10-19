#!/bin/bash
# =====================================================================
#  코어키퍼 ARM 서버 설치
#
#  대상   : ARM64(aarch64) 우분투 22.04 / 24.04
#           오라클 Ampere A1 · 라즈베리파이 5
#  사용법 : bash install.sh [월드백업.tar.gz]
#           (sudo 로 실행하지 마세요 — 필요한 곳에서만 스크립트가 씁니다)
#
#  순서   : 질문 → 설치 → 게임 내려받기 → 크론 등록 → 서버 시작
#           질문은 처음 2분 안에 끝나고, 그 뒤로는 자리를 떠도 됩니다.
# =====================================================================
set -e

REPO=https://github.com/inwhan987/corekeeper-arm
DIR="$HOME/corekeeper"
RESTORE="$1"

# ------------------------------------------------------------ 사전 점검
if [ "$(uname -m)" != "aarch64" ]; then
  echo "!! ARM64(aarch64) 전용입니다. 현재: $(uname -m)"
  exit 1
fi
[ "$(id -u)" = "0" ] && { echo "!! sudo 없이 실행해주세요:  bash install.sh"; exit 1; }
[ -n "$RESTORE" ] && [ ! -f "$RESTORE" ] && { echo "!! 백업 파일이 없습니다: $RESTORE"; exit 1; }

# ARM CPU 자동 판별 (Box64 빌드 선택용)
PAGE=$(getconf PAGESIZE 2>/dev/null || echo 4096)
MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || true)
if echo "$MODEL" | grep -qi "Raspberry Pi 5"; then
  [ "$PAGE" = "16384" ] && ARM64_DEVICE=rpi5_16k || ARM64_DEVICE=rpi5
elif lscpu 2>/dev/null | grep -qiE "Neoverse-N1|Ampere"; then
  ARM64_DEVICE=adlink
else
  ARM64_DEVICE=generic
fi

# 스크립트 옆에 files/ 가 있으면 그것을, 없으면 저장소를 내려받아 쓴다
HERE=$(cd "$(dirname "$0")" && pwd)
if [ -d "$HERE/files" ]; then
  SRC="$HERE"
else
  echo "저장소를 내려받습니다: $REPO"
  sudo apt-get update -y >/dev/null
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git >/dev/null
  SRC=$(mktemp -d)/repo
  git clone --depth 1 "$REPO" "$SRC"
fi

ask(){
  local ans
  if [ -r /dev/tty ]; then read -r -p "$1" ans < /dev/tty; else read -r -p "$1" ans; fi
  echo "${ans:-$2}"
}
asksecret(){
  local ans
  if [ -r /dev/tty ]; then read -r -s -p "$1" ans < /dev/tty; else read -r -s -p "$1" ans; fi
  echo >&2; echo "$ans"
}

# ================================================================ 질문
echo
echo "  CPU: $ARM64_DEVICE  (페이지 ${PAGE}B)"

REMOVE_PAL=n
if sudo docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx palworld-fex \
   || [ -d "$HOME/pal-fex" ]; then
  echo
  echo "================ 기존 서버 ================"
  echo "팰월드 서버가 발견됐습니다 (~/pal-fex)."
  echo "지우면 팰월드 월드·설정·크론이 전부 삭제됩니다. 되돌릴 수 없습니다."
  REMOVE_PAL=$(ask "팰월드를 지울까요? (y/N)          : " "n")
fi

echo
echo "================ 월드 설정 ================"
WORLD_NAME=$(ask   "월드 이름        [코어키퍼 서버] : " "코어키퍼 서버")
echo "  모드 — 0:일반  1:하드  2:크리에이티브  4:캐주얼"
WORLD_MODE=$(ask   "월드 모드                   [0] : " "0")
MAX_PLAYERS=$(ask  "최대 인원                   [8] : " "8")

echo
echo "================ 접속 설정 ================"
SERVER_PORT=$(ask  "직접 접속 포트 (UDP)    [27015] : " "27015")
PASSWORD=$(asksecret "접속 비밀번호 (없으면 엔터)     : ")
WEBHOOK=$(ask      "디스코드 웹후크 (없으면 엔터)   : " "")

echo
echo "================ 자동 관리 ================"
CRON_HOUR=$(ask    "정기 점검 시각 (0~23)       [5] : " "5")
AUTO_UPDATE=$(ask  "업데이트 자동 적용? (y/n)   [y] : " "y")
CHECK_MIN=$(ask    "업데이트 확인 (매시 몇 분) [30] : " "30")

case "$WORLD_MODE"  in 0|1|2|4) ;; *) WORLD_MODE=0 ;; esac
case "$MAX_PLAYERS" in ''|*[!0-9]*) MAX_PLAYERS=8 ;; esac
case "$SERVER_PORT" in ''|*[!0-9]*) SERVER_PORT=27015 ;; esac
case "$CRON_HOUR"   in ''|*[!0-9]*) CRON_HOUR=5 ;; esac
[ "$CRON_HOUR" -gt 23 ] && CRON_HOUR=5
case "$CHECK_MIN"   in ''|*[!0-9]*) CHECK_MIN=30 ;; esac
[ "$CHECK_MIN" -gt 59 ] && CHECK_MIN=30
PASSWORD=${PASSWORD:0:28}

echo
echo "입력이 끝났습니다. 여기서부터는 자동으로 진행됩니다 (10~40분)."

# ============================================================ 1. 패키지
echo
echo "===== [1/7] 패키지 설치 ====="
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
     curl python3 tar ca-certificates procps
# 도커가 이미 있으면 건드리지 않는다
# (도커 공식 docker-ce 와 우분투 docker.io 는 함께 설치할 수 없음)
if ! command -v docker >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
fi
if ! sudo docker compose version >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-v2 2>/dev/null \
    || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent || true
sudo systemctl enable --now docker

# ============================================================ 2. 팰월드 정리
echo
echo "===== [2/7] 기존 서버 정리 ====="
if [ "$REMOVE_PAL" = "y" ] || [ "$REMOVE_PAL" = "Y" ]; then
  if [ -f "$HOME/pal-fex/docker-compose.yml" ]; then
    (cd "$HOME/pal-fex" && sudo docker compose down -v) || true
  fi
  sudo docker rm -f palworld-fex 2>/dev/null || true
  sudo docker volume rm pal-fex_pal-data pal-fex_pal-backups pal-fex_pal-logs 2>/dev/null || true
  sudo docker image rm supersunho/palworld-server:latest 2>/dev/null || true
  sudo rm -rf "$HOME/pal-fex" "$HOME/pal-backup"
  crontab -l 2>/dev/null | grep -v "pal-fex" | crontab - || true
  sed -i '/pal-fex/d' "$HOME/.bashrc" 2>/dev/null || true
  while sudo iptables -D INPUT -m state --state NEW -p udp --dport 8211 -j ACCEPT 2>/dev/null; do :; done
  echo "팰월드 제거 완료"
else
  echo "건너뜀"
fi

# ============================================================ 3. 파일
echo
echo "===== [3/7] 파일 배치 ====="
mkdir -p "$DIR/server-files" "$DIR/server-data"
for f in docker-compose.yml lib.sh ck watchdog.sh checkupdate.sh nightly.sh; do
  cp "$SRC/files/$f" "$DIR/"
done
chmod +x "$DIR/ck" "$DIR"/*.sh

WORLD_NAME="$WORLD_NAME" WORLD_MODE="$WORLD_MODE" MAX_PLAYERS="$MAX_PLAYERS" \
SERVER_PORT="$SERVER_PORT" PASSWORD="$PASSWORD" ARM64_DEVICE="$ARM64_DEVICE" \
PUID="$(id -u)" PGID="$(id -g)" WEBHOOK="$WEBHOOK" \
python3 - "$SRC/files/env.template" "$DIR/core.env" <<'PYEOF'
import os, sys
t = open(sys.argv[1], encoding="utf-8").read()
for key, env in [("WORLD_NAME","WORLD_NAME"), ("WORLD_MODE","WORLD_MODE"),
                 ("MAX_PLAYERS","MAX_PLAYERS"), ("SERVER_PORT","SERVER_PORT"),
                 ("PASSWORD","PASSWORD"), ("ARM64_DEVICE","ARM64_DEVICE"),
                 ("PUID","PUID"), ("PGID","PGID"), ("DISCORD_WEBHOOK","WEBHOOK")]:
    t = t.replace(f"__{key}__", os.environ.get(env, ""))
open(sys.argv[2], "w", encoding="utf-8").write(t)
PYEOF
chmod 600 "$DIR/core.env"
echo "SERVER_PORT=$SERVER_PORT" > "$DIR/.env"
echo "설정 파일: $DIR/core.env"

if [ -n "$RESTORE" ]; then
  echo "월드 복원: $RESTORE"
  sudo tar xzf "$(readlink -f "$RESTORE")" -C "$DIR"
fi
sudo chown -R "$(id -u):$(id -g)" "$DIR"

# ============================================================ 4. 기동
echo
echo "===== [4/7] 첫 기동 — 게임 내려받기 ====="
cd "$DIR"
sudo docker compose pull
sudo docker compose up -d
# shellcheck source=files/lib.sh
source "$DIR/lib.sh"
printf "서버가 뜰 때까지 대기 (최대 40분)"
if wait_ready 2400; then
  echo " 완료"
else
  echo
  echo "!! 40분이 지나도 서버가 뜨지 않았습니다."
  echo "   cd $DIR && sudo docker compose logs -f   로 확인하세요."
  exit 1
fi
record_build
cp "$DIR/core.env" "$STATE/env.applied"

# ============================================================ 5. 크론
echo
echo "===== [5/7] 자동 관리 등록 ====="
if [ "$AUTO_UPDATE" = "y" ] || [ "$AUTO_UPDATE" = "Y" ]; then
  NIGHT="$DIR/nightly.sh"
else
  NIGHT="$DIR/ck restart"
fi
{ crontab -l 2>/dev/null | grep -v "$DIR/" | grep -v '^PATH=' || true
  echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  echo "*/10 * * * * $DIR/watchdog.sh >/dev/null 2>&1"
  echo "$CHECK_MIN * * * * $DIR/checkupdate.sh --notify >/dev/null 2>&1"
  echo "0 $CRON_HOUR * * * $NIGHT >> $DIR/nightly.log 2>&1"
} | crontab -
crontab -l

sed -i '/corekeeper\/ck/d; /corekeeper\/nightly/d' "$HOME/.bashrc" 2>/dev/null || true
echo "alias ck='$DIR/ck'"                           >> "$HOME/.bashrc"
echo "alias ckup='$DIR/nightly.sh --only-update'"   >> "$HOME/.bashrc"

# ============================================================ 6. 방화벽
echo
echo "===== [6/7] 방화벽 (UDP $SERVER_PORT) ====="
sudo iptables -C INPUT -m state --state NEW -p udp --dport "$SERVER_PORT" -j ACCEPT 2>/dev/null \
  || sudo iptables -I INPUT 5 -m state --state NEW -p udp --dport "$SERVER_PORT" -j ACCEPT
sudo netfilter-persistent save 2>/dev/null || true

# ============================================================ 7. 마무리
echo
echo "===== [7/7] 완료 ====="
IP=$(public_ip)
echo
echo "================================================================"
echo " 코어키퍼 서버가 켜졌습니다"
echo
echo "   접속        : 게임 → 참가 → 직접 연결"
echo "   주소        : $IP"
echo "   포트        : $SERVER_PORT"
echo "   비밀번호    : $( [ -n "$PASSWORD" ] && echo '(입력하신 값)' || echo '없음' )"
echo "   정기 점검   : 매일 ${CRON_HOUR}시"
echo
echo "   상태 확인   : ck status"
echo "   설정 변경   : nano $DIR/core.env  →  ck apply"
echo "   업데이트    : ckup"
echo
echo " ⚠ 클라우드 콘솔에서 인바운드 규칙을 직접 추가해야 접속됩니다:"
echo "   프로토콜 UDP / 대상 포트 $SERVER_PORT / 소스 CIDR 0.0.0.0/0"
echo "   * 소스 포트 범위는 반드시 비워둘 것"
echo
echo " 별칭(ck, ckup)을 바로 쓰려면:  source ~/.bashrc"
echo "================================================================"
