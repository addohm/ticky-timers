"""Syntax-check Ticky's Lua files and confirm the TOC lists exactly the Lua files that exist.

usage: python tools/check_lua.py            (checks Ticky/*.lua and Ticky/Ticky.toc)
needs: the lupa package (an embedded Lua): pip install lupa

lupa embeds Lua 5.4/5.5, not WoW's Lua 5.1, so this catches syntax errors only. It does not catch
5.1-incompatible syntax like goto, //, or bitwise operators; avoid those by convention.
"""
import pathlib
import sys

try:
    from lupa import LuaRuntime
except ImportError:
    sys.exit("lupa is not installed: pip install lupa")

root = pathlib.Path(__file__).resolve().parent.parent / "Ticky"
lua = LuaRuntime()
compile_chunk = lua.eval("function(src, name) local f, err = load(src, '@' .. name); return f ~= nil, err end")

failed = False
for path in sorted(root.glob("*.lua")):
    ok, err = compile_chunk(path.read_text(encoding="utf-8"), path.name)
    print(f"{path.name}: {'OK' if ok else err}")
    failed |= not ok

toc = [line.strip() for line in (root / "Ticky.toc").read_text(encoding="utf-8").splitlines()
       if line.strip().endswith(".lua") and not line.startswith("#")]
on_disk = sorted(p.name for p in root.glob("*.lua"))
missing = [f for f in toc if f not in on_disk]
unlisted = [f for f in on_disk if f not in toc]
if missing or unlisted:
    failed = True
    print(f"Ticky.toc mismatch: listed but missing {missing}, present but unlisted {unlisted}")
else:
    print(f"Ticky.toc: OK ({', '.join(toc)})")

sys.exit(1 if failed else 0)
