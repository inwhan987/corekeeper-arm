import sys, re, os
SEC = {
 "Accelerate": "가속 — 시간이 걸리는 것들을 빠르게",
 "Automation": "자동화",
 "Infinity":   "무한 — 닳거나 소모되는 것을 무한으로",
 "Misc":       "기타 편의 기능",
 "Pet":        "펫",
 "Quick":      "빠른 조작",
}
KO = {
 "Merchant": "상인 재고 갱신 가속 — 방식은 아래 MerchantValue 로 정함",
 "MerchantValue": "0 = 물건을 사면 바로 재고 갱신 / 180~3500 = 갱신 대기를 최대 이 값으로 줄임 (180 미만은 180, 단위는 초로 보임)",
 "Plant": "작물 성장 가속",
 "Crafting": "기다려야 하는 제작·생산 전부 가속",
 "Casting": "게이지가 차야 쓰이는 아이템을 바로 사용 (시전 시간 0)",
 "Portal": "포털·웨이포인트 충전 가속 — InstantPortalCharge 모드와 같은 기능",
 "Level": "스킬 경험치 배율 켜기",
 "CraftingAnimals": "Crafting 가속을 동물 관련 생산에도 적용 (Crafting 이 true 일 때만 의미 있음)",
 "CraftingFishingNet": "Crafting 가속을 낚시 그물에도 적용 (Crafting 이 true 일 때만 의미 있음)",
 "LevelValue": "스킬 경험치 배율 1~100배 (Level 이 true 일 때)",
 "Door": "문 자동 열림·닫힘",
 "FishingNetNoCritter": "낚시 그물에 벌레·잡생물 안 걸리게",
 "FishingNetCanGetItem": "낚시 그물로 아이템도 얻게",
 "GoldenPlantToSeed": "황금 작물에서 씨앗 얻기",
 "FishingNetCanGetItemValue": "낚시 그물 아이템 확률 0~0.5",
 "GoldenPlantToSeedValue": "황금 작물에서 얻는 씨앗 개수 0~8",
 "Durability": "장비 내구도 무한",
 "Boulder": "광석 바위 무한 — Eternal Ore Boulders 모드와 같은 기능이라 false 권장",
 "Arena": "투기장 반복 — 투기장 상태를 기록해뒀다가 되돌림 (포털·웨이포인트·플레이어·무덤은 제외)",
 "BossScan": "처치한 보스 기록을 다뤄서 보스를 다시 찾거나 잡을 수 있게 함",
 "ArenaValue": "투기장 복구 계산에 쓰는 값 100~9999 (정확한 단위는 미확인)",
 "BossScanValue": "true 면 돌아다니는 보스만 대상",
 "IgnoreRayChecksForPickup": "벽 너머 아이템도 주울 수 있음",
 "DeathNoDrop": "죽어도 아이템 안 떨어뜨림",
 "ChainMining": "연쇄 채굴 — 광석·나무를 한 번에",
 "ContainerDisplay": "상자 안 내용 표시 (화면용 — 게임 안 메뉴에서 바꿔도 됨)",
 "ModifySledgeRange": "해머 공격 범위 변경 켜기",
 "ExtraInventory": "인벤토리 칸 추가 켜기",
 "ProjectileTimerMultiple": "투사체 지속 시간 늘리기",
 "ChainMiningAdsorption": "연쇄 채굴한 아이템 자동으로 빨아들임",
 "ChainMiningNeedPlayer": "플레이어가 직접 부쉈을 때만 연쇄 (드릴·폭탄 등으로 부순 건 연쇄 안 함)",
 "ChainMiningGiveExp": "연쇄 채굴로도 채굴 경험치 획득",
 "ChainMiningTarget": "연쇄 대상 — OreOnly 광석만 / WoodOnly 나무만 / OreAndWood 둘 다",
 "ModifySledgeRangeValue": "해머 범위 1.4~5 (ModifySledgeRange 가 true 일 때)",
 "ExtraInventoryValue": "추가할 인벤토리 줄 수 1~10 (ExtraInventory 가 true 일 때)",
 "ProjectileTimerMultipleValue": "투사체 지속 시간 배율 1~10배",
 "TalentDisplay": "펫 재능 표시 (화면용)",
 "ResetSkin": "펫 외형 초기화 가능",
 "RollSkill": "펫 스킬 다시 뽑기",
 "MoveChestContent": "상자 내용 한 번에 옮기기 (단축키)",
 "OpenLockedChest": "잠긴 상자 바로 열기",
 "OpenLockedMelody": "멜로디 잠금 바로 열기",
}
TAG = "# 한글: "
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().split("\n")
lines = [l for l in lines if not l.strip().startswith("# 한글")]   # 다시 실행해도 중복 안 생기게
out, cur, guide = [], None, []
for l in lines:
    s = l.strip()
    m = re.match(r"^\[(\w+)\]$", s)
    if m:
        cur = m.group(1)
        out.append(l)
        if cur in SEC:
            out.append(TAG + SEC[cur])
            guide.append(f"\n[{cur}]  {SEC[cur]}")
        continue
    m = re.match(r"^(\w+)\s*=\s*(.*)$", s)
    if m and m.group(1) in KO:
        k, v = m.group(1), m.group(2)
        i = len(out)
        while i > 0 and out[i-1].startswith("#") and not out[i-1].startswith(TAG):
            i -= 1
        out.insert(i, TAG + KO[k])
        guide.append(f"  {k} = {v}\n      {KO[k]}")
    out.append(l)
open(p, "w", encoding="utf-8").write("\n".join(out))
g = os.path.join(os.path.dirname(os.path.abspath(p)), "설정_설명.txt")
open(g, "w", encoding="utf-8").write(
    "CoreEnhance 설정 설명 (모드가 Config.cfg 를 다시 쓰면서 한글 주석을 지워도 이 파일은 남습니다)\n"
    "값을 바꾸려면 Config.cfg 를 고친 뒤  ~/corekeeper/ck restart\n" + "\n".join(guide) + "\n")
print(f"주석 {sum(1 for x in out if x.startswith(TAG))}개 추가 → {p}")
print(f"설명 파일 → {g}")
