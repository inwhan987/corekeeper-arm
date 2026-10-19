#!/bin/bash
# =====================================================================
#  checkupdate.sh — 설치된 빌드와 스팀 최신 빌드를 비교한다
#
#    checkupdate.sh            결과만 출력
#    checkupdate.sh --notify   새 빌드면 디스코드 알림 (빌드당 1회)
#
#  종료 코드 : 0=최신  1=업데이트있음  2=확인실패
# =====================================================================
source "$(dirname "$(readlink -f "$0")")/lib.sh"

CUR=$(installed_build)
NEW=$(latest_build)

if [ -z "$CUR" ] || [ -z "$NEW" ]; then
  echo "확인 실패 (설치=${CUR:-?} / 최신=${NEW:-?})"
  exit 2
fi

if [ "$CUR" = "$NEW" ]; then
  echo "최신입니다 (빌드 $CUR)"
  rm -f "$STATE/update.notified"
  exit 0
fi

echo "업데이트 있음:  설치 $CUR  ->  최신 $NEW"
echo "  적용:  ckup   또는   ck update-game"

if [ "$1" = "--notify" ]; then
  [ "$(cat "$STATE/update.notified" 2>/dev/null)" = "$NEW" ] && exit 1
  send "🔔 코어키퍼 업데이트 발견" "설치된 빌드: \`$CUR\`
최신 빌드: \`$NEW\`

새벽 정기 점검 때 자동으로 적용됩니다.
지금 바로 적용하려면 서버에서 \`ckup\` 을 실행하세요." "$C_INFO"
  echo "$NEW" > "$STATE/update.notified"
fi
exit 1
