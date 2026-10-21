# corekeeper-arm

ARM64 리눅스(오라클 Ampere A1)에서 **코어키퍼 전용 서버**를 한 줄로 세우는 설치 스크립트.

코어키퍼 서버는 x86 전용이라 ARM에서는 그냥 돌지 않습니다. 여기서는 FEX 에뮬레이션 이미지
[`ghcr.io/lianye-scythe/core-keeper-dedicated:fex`](https://github.com/Lianye-Scythe/core-keeper-dedicated-fex)
를 쓰고, 그 위에 운영 도구(관리 명령, 설정 변경 알림, 백업, 자동 업데이트, 감시)를 얹습니다.

> Box64 기반 이미지(`escaping/core-keeper-dedicated`)는 오라클 A1에서 기동 중 세그폴트(코드 139)로
> 계속 재시작해서 쓰지 않습니다. FEX 이미지도 `FEX_MULTIBLOCK=1` · `FEX_MAXINST=16` 설정이 있어야
> 같은 지점을 넘어갑니다 (`files/docker-compose.yml` 에 들어 있음).

## 설치

Ubuntu 22.04 / 24.04 (ARM64) 서버에 SSH로 접속한 뒤:

```bash
curl -fsSL https://raw.githubusercontent.com/inwhan987/corekeeper-arm/main/install.sh -o install.sh
bash install.sh
```

`sudo` 를 붙이지 마세요. 필요한 곳에서만 스크립트가 씁니다.
SSH가 끊겨도 계속 돌게 하려면 `tmux new -s ck` 안에서 실행하세요.

처음 몇 분 동안 질문에 답하면 그 뒤는 자리를 떠도 됩니다.
게임 내려받기와 모드 컴파일까지 끝나면 서버가 자동으로 켜집니다. **첫 설치는 20~60분** 걸립니다.

같은 서버에 예전 팰월드(`~/pal-fex`)가 있으면 지울지 물어봅니다.

## 접속

게임 → **참가** → **직접 연결** → 서버 IP · 포트(기본 27015) · 비밀번호.

클라우드 콘솔에서 인바운드 규칙을 직접 추가해야 합니다.

| | |
|---|---|
| IP 프로토콜 | UDP |
| 대상 포트 범위 | 27015 |
| 소스 CIDR | 0.0.0.0/0 |
| 소스 포트 범위 | **비워둘 것** |

## 모드

서버는 **mod.io** 에서 모드를 받습니다. 설치 중에 물어보고, 나중에 `core.env` 에서 바꿀 수 있습니다.

```
MODS_ENABLED=true
MODIO_API_KEY=...                          # mod.io → 계정 → API Access
MODIO_API_URL=https://u-숫자.modapi.io/v1
MODS=core-lib,generalconfigmenu,coreenhance,instantportalcharge
```

- 모드 ID는 mod.io 주소의 마지막 부분입니다. (`mod.io/g/corekeeper/m/core-lib` → `core-lib`)
- 의존 모드는 자동으로 안 받아집니다. `core-lib` 같은 기반 모드도 직접 넣으세요.
- 내 게임과 서버의 모드 구성이 다르면 접속 시 `bad protocol version` 으로 튕깁니다.
- 글꼴처럼 화면만 바꾸는 모드는 서버에 없어도 됩니다. 넣었다가 서버가 안 켜지면 그런 모드부터 빼세요.

### 모드 설정 메뉴 한글로 보기

게임 안 모드 설정 메뉴(ESC → 설정 → 모드 설정)는 중국어·영어만 들어 있습니다.
각자 **게임하는 PC** 에서 아래를 실행하면 한글로 나옵니다 (게임은 끄고, 게임 언어는 한국어).

```
pip install UnityPy
python files/translate-mods-ko.py
```

- Steam 창작마당 폴더를 알아서 찾아 CoreEnhance·General Mod Config Menu 번들에 한글을 넣습니다. 번역은 `files/mod-ko.json`.
- 원본은 옆에 `.orig` 로 남습니다. 되돌리기: `python files/translate-mods-ko.py --restore`
- 모드가 업데이트되면 영어로 돌아오니 다시 실행하세요. 게임 언어가 영어라면 `--english` 를 붙이세요.

## 명령

| 명령 | 하는 일 |
|---|---|
| `ck apply` | 설정 적용 — **바뀐 항목을 디스코드로 알림** |
| `ck wait` | 서버가 접속 가능해질 때까지 기다리기 |
| `ck start` / `stop` / `restart` | 켜기 / 끄기 / 재시작 |
| `ck status` | 상태 · 접속 정보 · 빌드 · 백업 수 |
| `ck log` | 로그 |
| `ck backup` | 월드 백업 (최근 7개 보관) |
| `ck update` | 도커 이미지 업데이트 |
| `ck update-game` | 게임 업데이트 — 백업 → 업데이트 허가 → 재시작 |
| `ckup` | 업데이트가 **있을 때만** 즉시 적용 |

## 재시작이 오래 걸리는 이유

에뮬레이션으로 유니티 게임을 띄우는 데다, 모드가 있으면 켤 때마다 모드를 컴파일합니다.
**재시작 한 번에 10분 이상** 걸릴 수 있습니다.

그래서 두 가지를 줄여 두었습니다.

- **켤 때 업데이트 확인 생략** — `UPDATE_GATE_ENABLED=true`. 평소에는 게임 파일 천여 개 검사를 건너뛰고,
  `ck update-game` 이 `update-control/apply-update` 에 허가(현재 시각)를 써 둔 경우에만 업데이트합니다.
- **매일 재시작 안 함** — 코어키퍼는 팰월드 같은 메모리 누수가 없어서, 새벽 점검은 백업과
  업데이트 확인만 하고 업데이트가 있을 때만 재시작합니다. 매일 재시작하려면 크론의
  `nightly.sh` 를 `nightly.sh --restart` 로 바꾸세요.

## 자동 관리

| 주기 | 하는 일 |
|---|---|
| 10분 | `watchdog.sh` — 20분 넘게 비정상일 때만 알림 |
| 매시 | `checkupdate.sh --notify` — 새 빌드면 한 번만 알림 |
| 매일 | `nightly.sh` — 월드 백업 → 업데이트 있으면 적용 |

## 디스코드 알림

| 상황 | 보내는 쪽 |
|---|---|
| 🟢 서버 시작 · 🔴 종료 · 👋 입장 · 🚪 퇴장 | 이미지 기본 기능 (입장·퇴장은 기본 꺼짐) |
| 🔧 설정 변경 목록 | `ck apply` |
| 🔔 새 빌드 발견 · ✅ 업데이트 완료 | `checkupdate.sh` · `ck update-game` |
| ⚠️ 서버 이상 · ✅ 복구 | `watchdog.sh` |

## 파일 위치

```
~/corekeeper/
├── core.env          설정 (비밀번호·웹후크·API 키 포함 — 커밋 금지)
├── server-data/      월드 · 설정 — 이게 진짜 데이터
├── server-files/     게임 본체 — 지워도 다시 받음
├── fex-cache/        에뮬레이터 번역 캐시 — 두 번째 기동부터 빨라짐
├── update-control/   업데이트 허가 파일
└── backups/          월드 백업 7개
```

## 알아둘 것

- FEX 이미지는 오라클 A1에서 기동과 짧은 멀티플레이까지 검증됐지만, **장시간 안정성은 아직 검증되지 않았습니다**
  ([테스트 기록](https://github.com/Lianye-Scythe/core-keeper-dedicated-fex/blob/main/fex/RESULTS.md)).
  갑자기 끊기면 워치독이 디스코드로 알립니다.
- 코어키퍼 서버에는 게임 안 공지 기능이 없어서, 재시작 전에 게임 안에서 예고를 띄울 수 없습니다.
  대신 `ck apply` · `stop` · `restart` · `update-game` 은 접속자가 있으면 디스코드로 예고하고
  모두 나갈 때까지 최대 5분 기다립니다 (1분 남으면 한 번 더 알림). 바로 하려면 `--now`.
- `core.env` 에는 비밀번호, 웹후크, API 키가 평문으로 들어갑니다. 이 저장소에 커밋하지 마세요 (`.gitignore` 에 들어 있음).
