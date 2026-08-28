#!/usr/bin/python3
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
HYPR = REPO / "desktop/hypr"
ENTRYPOINT = HYPR / "hyprland.lua"


def main():
    source = ENTRYPOINT.read_text(encoding="utf-8")
    if 'require("hyprland")' in source or "require('hyprland')" in source:
        raise SystemExit("hyprland.lua recursively requires its own module name")

    lua = shutil.which("lua")
    if lua:
        harness = "\n".join(
            [
                "local proxy",
                "proxy = setmetatable({}, {",
                "  __index = function() return proxy end,",
                "  __call = function() return proxy end,",
                "})",
                "hl = proxy",
                'local root = assert(os.getenv("INFINITY_HYPR_ROOT"))',
                'package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path',
                'local loaded, result = pcall(dofile, root .. "/hyprland.lua")',
                "if not loaded then error(result) end",
                'if result ~= hl then error("hyprland.lua did not return the injected hl runtime") end',
            ]
        )
        with tempfile.TemporaryDirectory(prefix="infinity-hypr-bootstrap-") as home:
            result = subprocess.run(
                [lua, "-e", harness],
                cwd=REPO,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=os.environ | {"HOME": home, "INFINITY_HYPR_ROOT": str(HYPR)},
            )
        if result.returncode:
            raise SystemExit(result.stdout + result.stderr)

    print("ok: Hyprland Lua bootstrap avoids entrypoint recursion")


if __name__ == "__main__":
    main()
