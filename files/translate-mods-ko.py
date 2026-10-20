"""모드 게임 안 메뉴를 한글로 바꿔주는 스크립트 (각자 게임하는 PC 에서 실행).

모드 번들(*_Windows.assetbundle) 안 번역표에는 언어 칸이 13개 있는데 중국어·영어만 채워져 있음.
비어 있는 칸에 mod-ko.json 의 한글을 채워 넣음 → 게임 언어가 한국어면 한글로 보임.

준비:  pip install UnityPy
사용:  python translate-mods-ko.py              (Steam 워크숍 폴더 자동으로 찾음)
       python translate-mods-ko.py <폴더|번들> ...  (직접 지정)
       python translate-mods-ko.py --english    (게임 언어가 영어여도 한글로 보이게 영어 칸까지 덮어씀)
       python translate-mods-ko.py --restore    (원래대로 되돌림)

- 처음 바꿀 때 원본을 <번들>.orig 로 남김. 다시 실행하면 원본에서 새로 만듦(번역표 고친 걸 반영).
- Steam 이 모드를 업데이트하면 원래대로 돌아오니 그때 다시 실행.
- 게임이 켜져 있으면 끄고 실행.
"""
import argparse, hashlib, json, os, re, shutil, sys

APP_ID = "1621690"   # Core Keeper
ZH, EN = 0, 2        # 번역표에서 중국어·영어 칸 번호 (번들 안 내용으로 확인함)
HERE = os.path.dirname(os.path.abspath(__file__))


def steam_workshop_dirs():
    roots = [r"C:\Program Files (x86)\Steam", r"C:\Program Files\Steam"]
    for steam in list(roots):
        vdf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
        if os.path.isfile(vdf):
            roots += [p.replace("\\\\", "\\") for p in re.findall(r'"path"\s+"([^"]+)"', open(vdf, encoding="utf-8").read())]
    seen = []
    for r in roots:
        d = os.path.join(r, "steamapps", "workshop", "content", APP_ID)
        if os.path.isdir(d) and os.path.normcase(d) not in map(os.path.normcase, seen):
            seen.append(d)
    return seen


def find_bundles(paths):
    for p in paths:
        if os.path.isfile(p):
            yield p
            continue
        for root, _, files in os.walk(p):
            for f in files:
                if f.endswith("_Windows.assetbundle"):
                    yield os.path.join(root, f)


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def patch(bundle, table, english, used):
    import UnityPy
    orig, mark = bundle + ".orig", bundle + ".ko"
    patched_before = os.path.isfile(mark) and os.path.isfile(orig) and open(mark).read().strip() == sha(bundle)
    # 처음이거나 Steam 이 새 버전으로 바꿔놓은 경우 → 지금 파일이 원본
    # 파일 경로로 열면 UnityPy 가 파일을 잡고 있어서 윈도우에서 지우거나 덮어쓰지 못함 → 메모리로 읽어서 넘김
    with open(orig if patched_before else bundle, "rb") as f:
        env = UnityPy.load(f.read())
    count = 0
    for path, obj in env.container.items():
        if "/TextDataBlock/" not in path:
            continue
        if hasattr(obj, "deref"):   # UnityPy 새 버전은 container 값이 PPtr
            obj = obj.deref()
        key = path.split("/TextDataBlock/", 1)[1].rsplit(".asset", 1)[0]
        if key not in table:
            continue
        used.add(key)
        title, desc = table[key]
        tree = obj.read_typetree()
        for i, v in enumerate(tree["m_localizedTexts"]["values"]):
            if i == ZH or (i == EN and not english):
                continue
            if i != EN and (v["title"] or v["description"]):
                continue            # 모드가 원래 갖고 있는 다른 언어 번역은 건드리지 않음
            v["title"], v["description"] = title, desc
        obj.save_typetree(tree)
        count += 1
    if not count:
        return 0
    if not patched_before:
        shutil.copy2(bundle, orig)
    tmp = bundle + ".tmp"
    with open(tmp, "wb") as f:
        f.write(env.file.save(packer="lz4"))
    os.replace(tmp, bundle)
    open(mark, "w").write(sha(bundle))
    return count


def restore(bundle):
    orig, mark = bundle + ".orig", bundle + ".ko"
    if not os.path.isfile(orig):
        return False
    if os.path.isfile(mark) and open(mark).read().strip() == sha(bundle):
        shutil.copy2(orig, bundle)  # 우리가 바꾼 그대로일 때만 되돌림 (Steam 이 업데이트했으면 그게 최신)
    os.remove(orig)
    if os.path.isfile(mark):
        os.remove(mark)
    return True


def main():
    ap = argparse.ArgumentParser(description="모드 메뉴 한글 패치")
    ap.add_argument("paths", nargs="*", help="워크숍 폴더나 번들 파일 (안 주면 자동으로 찾음)")
    ap.add_argument("--table", default=os.path.join(HERE, "mod-ko.json"))
    ap.add_argument("--english", action="store_true", help="영어 칸도 한글로 덮어씀")
    ap.add_argument("--restore", action="store_true", help="원래대로 되돌림")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    paths = a.paths or steam_workshop_dirs()
    if not paths:
        sys.exit("Core Keeper 워크숍 폴더를 못 찾음 — 폴더를 직접 적어줘 (…\\steamapps\\workshop\\content\\1621690)")
    bundles = list(find_bundles(paths))

    if a.restore:
        for b in bundles:
            if restore(b):
                print("되돌림:", b)
        return

    try:
        import UnityPy  # noqa: F401
    except ImportError:
        sys.exit("UnityPy 가 없음 — 먼저 실행:  pip install UnityPy")
    table = {k: v for k, v in json.load(open(a.table, encoding="utf-8")).items() if not k.startswith("_")}
    used = set()
    for b in bundles:
        n = patch(b, table, a.english, used)
        if n:
            print(f"한글 {n}개 넣음: {b}")
    for k in sorted(set(table) - used):
        print("번들에서 못 찾은 항목:", k)


if __name__ == "__main__":
    main()
