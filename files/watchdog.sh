#!/bin/bash
# =====================================================================
#  watchdog.sh — 호스트에서 서버를 지켜본다
#
#  컨테이너가 죽으면 안쪽의 알림 기능도 같이 죽어 아무것도 못 보냅니다.
#  그래서 바깥에서 감시합니다. 도커가 자동 복구하는 짧은 크래시로는
#  울리지 않도록, 연속 2회(=20분) 비정상일 때만 알립니다.
#  업데이트 중(.state/maintenance 가 1시간 이내)이면 건너뜁니다.
# =====================================================================
source "$(dirname "$(readlink -f "$0")")/lib.sh"

M="$STATE/maintenance"
if [ -f "$M" ] && [ -n "$(find "$M" -mmin -60 2>/dev/null)" ]; then
  exit 0
fi

RUN=$($D inspect -f '{{.State.Running}}' "$CON" 2>/dev/null)
if server_proc; then PROC=up; else PROC=down; fi
echo "${RUN:-missing}/$PROC" > "$STATE/health"

if [ "$RUN" != "true" ] || [ "$PROC" != "up" ]; then
  S=$(( $(cat "$STATE/strikes" 2>/dev/null || echo 0) + 1 ))
  echo "$S" > "$STATE/strikes"
  if [ "$S" -ge 2 ] && [ ! -f "$STATE/alerted" ]; then
    send "⚠️ 서버 이상" "컨테이너: \`${RUN:-없음}\` / 게임 프로세스: \`$PROC\`
20분 넘게 비정상입니다. 서버에서 \`ck status\` 로 확인해주세요." "$C_BAD"
    touch "$STATE/alerted"
  fi
else
  if [ -f "$STATE/alerted" ]; then
    send "✅ 서버 복구" "다시 정상으로 돌아왔습니다." "$C_OK"
    rm -f "$STATE/alerted"
  fi
  rm -f "$STATE/strikes"
fi
