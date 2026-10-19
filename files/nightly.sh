#!/bin/bash
# =====================================================================
#  nightly.sh — 정기 점검
#
#    nightly.sh                 월드 백업 → 업데이트 있으면 적용 (없으면 재시작 안 함)
#    nightly.sh --only-update   업데이트 있을 때만 적용 (백업은 update-game 안에서 함)
#    nightly.sh --restart       월드 백업 → 업데이트 있으면 적용, 없으면 재시작
#
#  코어키퍼는 팰월드 같은 메모리 누수가 없어서 매일 재시작할 필요가 없고,
#  재시작이 10분 넘게 걸리므로 기본값은 "업데이트 있을 때만" 입니다.
# =====================================================================
source "$(dirname "$(readlink -f "$0")")/lib.sh"
MODE=default
case "$1" in --only-update) MODE=only ;; --restart) MODE=restart ;; esac

if [ "$MODE" != "only" ]; then
  echo "=== $(date '+%F %T') 월드 백업 ==="
  backup_world || echo "!! 백업 실패"
fi

bash "$DIR/checkupdate.sh"   # 0=최신  1=업데이트있음  2=확인실패
rc=$?

if [ "$rc" = "1" ]; then
  echo "=== $(date '+%F %T') 업데이트 발견 -> update-game ==="
  bash "$DIR/ck" update-game -y
  exit $?
fi

if [ "$MODE" = "restart" ]; then
  echo "=== $(date '+%F %T') 정기 재시작 ==="
  bash "$DIR/ck" restart
  exit 0
fi

[ "$rc" != "0" ] && { echo "버전 확인 실패 - 아무것도 하지 않음"; exit 2; }
echo "이미 최신 - 재시작하지 않음"
exit 0
