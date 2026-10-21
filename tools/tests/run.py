"""Run Ticky's behaviour tests: each tools/tests/test_*.lua in a fresh mocked Forever client.

usage: python tools/tests/run.py [name ...]      (names like "hold" for test_hold.lua)
needs: pip install lupa

Each test gets its own Lua 5.1 state: mock.lua, then the addon's files in .toc order (with
ADDON, ns), then the test, which calls MOCK.start(), drives events and MOCK.update(), and records
results with MOCK.check(). Exit code 1 if any check fails or a test errors.
"""
import pathlib
import sys

try:
    from lupa import lua51
except ImportError:
    sys.exit("lupa is not installed: pip install lupa")

HERE = pathlib.Path(__file__).resolve().parent
ADDON = HERE.parent.parent / "Ticky"


def run(test):
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute((HERE / "mock.lua").read_text(encoding="utf-8"))
    lua.execute("NS = {}")
    load = lua.eval("function(code, name) local f, e = loadstring(code, '@' .. name); if not f then error(e) end; return f end")
    toc = [line.strip() for line in (ADDON / "Ticky.toc").read_text(encoding="utf-8").splitlines()
           if line.strip().endswith(".lua") and not line.startswith("#")]
    for name in toc:
        load((ADDON / name).read_text(encoding="utf-8"), name)("Ticky", lua.eval("NS"))
    lua.execute(test.read_text(encoding="utf-8"))
    mock = lua.eval("MOCK")
    unknown = sorted(mock.unknown.keys())
    return mock.passes, mock.fails, unknown


names = sys.argv[1:]
tests = [HERE / f"test_{n}.lua" for n in names] if names else sorted(HERE.glob("test_*.lua"))
failed = False
for test in tests:
    try:
        passes, fails, unknown = run(test)
    except Exception as e:  # a Lua error in the addon or the test
        print(f"{test.stem}: ERROR {e}")
        failed = True
        continue
    print(f"{test.stem}: {passes} passed, {fails} failed" + (f" | unmodelled: {', '.join(unknown)}" if unknown else ""))
    failed |= fails > 0
sys.exit(1 if failed else 0)
