# corekeeper-arm — 작업 인수인계

오라클 클라우드 무료 ARM 서버(Ampere A1)에서 코어키퍼 전용 서버를 돌리는 설치기·운영 도구 저장소.
이 저장소의 설치기로 실제 서버 한 대가 운영 중이다. 서버 접속 정보는 `CLAUDE.local.md` (커밋 안 함).

## 사용자와 일하는 방식

- 사용자는 한국어로 대화한다. 답도 한국어로, 짧고 단계별로.
- 서버 명령은 그대로 붙여넣을 수 있는 블록으로. 긴 내용은 heredoc 으로 파일을 만든다
  (예전에 nano 붙여넣기가 깨진 적이 있음).
- 서버를 바꾸기 전에 무엇을 바꾸는지 먼저 말한다. 월드 데이터(`server-data`)를 지우는 작업은 반드시 확인받는다.
- 비밀값(디스코드 웹후크, 접속·관리자 비밀번호, mod.io API 키)은 커밋하지 않는다. 대화에 출력하지도 않는다.
- 추측한 내용은 추측이라고 말한다. 가능하면 서버 로그나 모드 소스 코드로 확인한다.

## 서버 구성

| 항목 | 값 |
|---|---|
| 호스트 | Oracle Ampere A1 (Neoverse-N1, 4 OCPU / 24GB), Ubuntu 22.04 aarch64 |
| 도커 | 도커 공식 `docker-ce` (우분투 `docker.io` 와 충돌하므로 설치기는 이미 있으면 건너뜀) |
| 작업 폴더 | `~/corekeeper` (서버의 `ubuntu` 사용자) |
| 컨테이너 | `core-keeper-dedicated` |
| 이미지 | `ghcr.io/lianye-scythe/core-keeper-dedicated:fex` |
| 접속 | IP 직접 접속, UDP 27015 (오라클 보안 목록에 규칙 있음) |
| 게임 버전 | 1.3.0.6 (월드 생성 버전 Ck130) |

```
~/corekeeper/
├── core.env           설정 (비밀값 포함, chmod 600)
├── .env               SERVER_PORT 만 — compose 포트 치환용 (ck 가 자동 생성)
├── docker-compose.yml
├── ck lib.sh watchdog.sh checkupdate.sh nightly.sh annotate-coreenhance.py
├── server-data/       월드 · 모드 설정 (진짜 데이터)
├── server-files/      게임 본체 + 모드 (지워도 다시 받음)
├── fex-cache/ mesa-cache/ update-control/
├── backups/           월드 백업 7개
└── .state/            env.applied, installed_build, update.notified, maintenance 등
```

## 왜 이렇게 되어 있나 (중요한 결정)

- **Box64 이미지(`escaping/core-keeper-dedicated`)는 안 됨.** 오라클 A1 에서
  `Start initializing all managers` 직후 `__tls_get_addr` 세그폴트(코드 139)로 무한 재시작.
  그 이미지의 이슈 #108 #111 과 같은 증상. 오라클용 `adlink` 빌드도 현재 빠져 있음. root(PUID=0)는 이미지가 거부.
- **FEX 이미지 + `FEX_MULTIBLOCK=1` `FEX_MAXINST=16` 필수.** 이 둘이 없으면 FEX 도 같은 지점에서 죽는다
  (Lianye-Scythe/core-keeper-dedicated-fex 의 fex/RESULTS.md). `docker-compose.yml` 의 `environment:` 에 고정.
- **`UPDATE_GATE_ENABLED=true`** — 평소 기동 때 DepotDownloader 파일 검사(천여 개)를 건너뛴다.
  업데이트는 `update-control/apply-update` 에 현재 epoch 초(`date +%s`)를 쓰고 재시작할 때만.
  1시간 넘은 허가는 무시되고, 사용 후 컨테이너가 지운다. `ck update-game` 이 이 방식으로 동작.
- **새벽 점검은 재시작하지 않음.** 코어키퍼는 팰월드 같은 메모리 누수가 없고 재시작이 10분 넘게 걸리므로
  `nightly.sh` 기본 = 월드 백업 + 업데이트 있을 때만 `update-game`. 매일 재시작은 `--restart`.
- **기동 완료 판정은 로그로.** `wait_ready` 는 기준 시각 이후 `docker logs` 에 `Listening on ip`
  (직접 접속 모드) 가 뜨면 완료, `Segmentation fault` 면 크래시. 직접 접속 모드에서는 `GameID.txt` 가 안 생긴다.
- **설정 변경 알림** — `ck apply` 가 이전 적용본과 `core.env` 를 비교하고, 각 키 위의 한국어 주석을 이름으로 써서
  디스코드로 보낸다. 비밀값 키(PASSWORD/WEBHOOK/TOKEN/KEY)는 "변경됨"으로만.
- 게임 안 공지 기능이 없어서 재시작 예고는 못 한다 (팰월드 때와 다름).

## 모드

mod.io 에서 받는다 (`MODS_ENABLED`, `MODIO_API_KEY`, `MODIO_API_URL`, `MODS`). 현재 서버:

```
MODS=core-lib,generalconfigmenu,coreenhance,instantportalcharge,eternaloreboulders,betterminimap
```

설치된 버전: CoreLib 5.0.0, General Mod Config Menu 1.4.2, CoreEnhance 1.4.8, InstantPortalCharge 1.4.4,
Eternal Ore Boulders 1.0.2r1, Better Minimap 1.0.1.

- 사용자 게임은 스팀 창작마당에서 받은 모드를 쓴다. 서버(mod.io)와 구성이 다르면 접속 시
  `RpcSystem received bad protocol version` 으로 튕긴다. 실제로 모드 없이 접속했다가 이걸로 튕긴 적 있음.
- Korean Pixel Font 는 mod.io 에 없어서 서버에 못 넣는다 (화면 전용이라 필요도 없음).
- 모드는 기동할 때마다 다시 받고 **컴파일**한다. 에뮬레이션이라 이게 기동 시간의 큰 부분.
- 모드 설정은 `server-data/mods/<모드>/` 에 있어서 재시작해도 유지된다.
  CoreEnhance 설정 `server-data/mods/CoreEnhance/Config.cfg` 에는 `annotate-coreenhance.py` 로 한국어 주석을 단다
  (멱등, 같은 폴더에 `설정_설명.txt` 도 생성). 주석 뜻은 서버에 있는 모드 소스 코드로 확인했다
  (`server-files/CoreKeeperServer_Data/StreamingAssets/Mods/coreenhance/Scripts/`). `ArenaValue` 단위만 미확인.

## 로그에서 무시해도 되는 것

`Xbox won't like it`, `couldn't load ... .asmdef from asset bundle`, `Ignoring invalid [Unity.Entities.UpdateAfterAttribute]`,
`failed get internal IP`, `flock ... errno = 13`, `[S_API FAIL] ... SteamNetworkingUtils004`,
가끔 뜨는 `[ServerUpdateFrequencyTracker] ... 17 out of 1195 host frames` (1~2% 수준이면 정상).

## 남은 작업

1. 이 저장소 최신판을 깃허브(`inwhan987/corekeeper-arm`)에 반영.
2. 운영 중인 서버에 새 스크립트 반영: `files/` 의 lib.sh ck nightly.sh checkupdate.sh watchdog.sh
   annotate-coreenhance.py 를 `~/corekeeper/` 로 받고, `core.env` 에 `UPDATE_GATE_ENABLED=true` 추가,
   `record_build` 로 현재 빌드 기록, `ck apply && ck wait` 로 재시작 시간 측정.
   (서버는 이미지를 손으로 FEX 로 바꾼 상태라 `docker-compose.yml` 은 저장소 것과 내용이 같다.)
3. `crontab -l` 에 watchdog / checkupdate / nightly 3줄이 있는지 확인. 첫 설치가 SSH 끊김으로 중간에 멈췄을 수 있음.
4. 오라클 보안 목록의 UDP 8211(예전 팰월드) 규칙 삭제 — 사용자가 콘솔에서.
5. mod.io API 키 재발급 권장 (대화에 노출됐었음).
6. 장시간 안정성 관찰. FEX 이미지는 장시간 운영이 검증되지 않았다. 끊기면 `ck log` 로 원인 확인.

## 이전 이력

같은 서버에서 원래 팰월드를 FEX(`supersunho/palworld-server`)로 돌렸다 (`inwhan987/palworld-arm` 저장소).
코어키퍼 설치기가 팰월드를 지웠다. 팰월드 쪽 경험: 오라클 보안 목록의 "소스 포트 범위"에 값을 넣으면
모든 접속이 막힌다(비워야 함), iptables ACCEPT 는 REJECT 보다 위에 있어야 한다.

## 검증 방법

- 셸: `bash -n`, `shellcheck -S warning -e SC1091,SC2155,SC2034`
- 흐름: `sudo`/`docker`/`curl` 을 가짜 스크립트로 바꿔 PATH 앞에 두고 `ck update-game -y`, `nightly.sh`,
  `wait_ready` 크래시 감지를 돌려본다.
