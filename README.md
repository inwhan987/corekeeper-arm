# corekeeper-arm

ARM64 리눅스(오라클 Ampere A1 · 라즈베리파이 5)에서 **코어키퍼 전용 서버**를 한 줄로 세우는 설치 스크립트.

코어키퍼 서버는 x86 전용이라 ARM에서는 그냥 돌지 않습니다. Box64 에뮬레이션이 들어간 [`escaping/core-keeper-dedicated`](https://hub.docker.com/r/escaping/core-keeper-dedicated) 이미지를 쓰고, 그 위에 운영 도구를 얹습니다. CPU 종류(오라클 A1 / 라즈베리파이 5)는 설치 스크립트가 알아서 판별합니다.

## 설치

Ubuntu 22.04 / 24.04 (ARM64) 서버에 SSH로 접속한 뒤:

```bash
curl -fsSL https://raw.githubusercontent.com/inwhan987/corekeeper-arm/main/install.sh -o install.sh
bash install.sh
```

`sudo` 를 붙이지 마세요. 필요한 곳에서만 스크립트가 씁니다.

처음 2분 동안 질문에 답하면, 그 뒤는 자리를 떠도 됩니다. 게임 내려받기가 끝나면 서버가 자동으로 켜집니다.

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

## 명령

| 명령 | 하는 일 |
|---|---|
| `ck apply` | 설정 적용 — **바뀐 항목을 디스코드로 알림** |
| `ck start` / `stop` / `restart` | 켜기 / 끄기 / 재시작 |
| `ck status` | 상태 · 접속 정보 · 빌드 · 백업 수 |
| `ck log` | 로그 |
| `ck backup` | 월드 백업 (최근 7개 보관) |
| `ck update` | 도커 이미지 업데이트 |
| `ck update-game` | 게임 본체 재설치 — **월드는 그대로** |
| `ckup` | 업데이트가 **있을 때만** 즉시 적용 |

## 자동 관리

| 주기 | 하는 일 |
|---|---|
| 10분 | `watchdog.sh` — 20분 넘게 비정상일 때만 알림 |
| 매시 | `checkupdate.sh --notify` — 새 빌드면 한 번만 알림 |
| 매일 | `nightly.sh` — 월드 백업 → 업데이트 있으면 적용, 없으면 재시작 |

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
├── core.env          설정 (비밀번호·웹후크 포함 — 커밋 금지)
├── server-data/      월드 · 설정 — 이게 진짜 데이터
├── server-files/     게임 본체 — 지워도 다시 받음
└── backups/          월드 백업 7개
```

## 알아둘 것

- 코어키퍼 서버에는 게임 안 공지 기능이 없어서, 재시작 전에 "60초 뒤 재시작" 같은 예고를 띄울 수 없습니다. 디스코드 알림으로 대신합니다.
- `core.env` 에는 비밀번호와 웹후크가 평문으로 들어갑니다. 이 저장소에 커밋하지 마세요 (`.gitignore` 에 들어 있음).
