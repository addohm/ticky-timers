"""Package the addon for release: release/Ticky-<version>.zip, with the Ticky folder at
its top level and nothing else (what CurseForge, Wago and players unzipping into
Interface\\AddOns expect), plus the license (GPLv3) inside it as Ticky/LICENSE.txt. The packaged
Build.lua says the commit it was made from, so /ticky debug in an installed copy names it; the
repo's copy stays "dev".

usage: python tools/package.py    (from a clean checkout of the commit to release)
"""
import pathlib
import subprocess
import sys
import time
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
ADDON = REPO / "Ticky"


def git(*args):
    return subprocess.check_output(["git", "-C", str(REPO), *args], text=True).strip()


if git("status", "--porcelain", "--", "Ticky"):
    sys.exit("Ticky/ has uncommitted changes: commit them first, so the package matches a commit.")
commit = git("rev-parse", "--short", "HEAD")
version = next(line.split(":", 1)[1].strip() for line in (ADDON / "Ticky.toc").read_text().splitlines()
               if line.startswith("## Version:"))
out = REPO / "release" / f"Ticky-{version}.zip"  # the commit is inside, in Build.lua
out.parent.mkdir(exist_ok=True)

build = ('local ADDON, ns = ...\n\n'
         '-- Which build this is: the commit this package was made from (the repo copy says "dev").\n'
         f'ns.Build = "{commit}"\n')
now = time.localtime()[:6]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    folders = sorted({p.parent for p in ADDON.rglob("*") if p.is_file()})
    for folder in folders:
        z.writestr(zipfile.ZipInfo(folder.relative_to(REPO).as_posix() + "/", date_time=now), "")
    for path in sorted(p for p in ADDON.rglob("*") if p.is_file()):
        name = path.relative_to(REPO).as_posix()
        if name == "Ticky/Build.lua":
            z.writestr(name, build)
        else:
            z.write(path, name)
    z.write(REPO / "LICENSE", "Ticky/LICENSE.txt")  # the GPL travels with the program
print(f"{out.relative_to(REPO)} (build {commit}, version {version})")
