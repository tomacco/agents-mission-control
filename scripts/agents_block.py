"""agents_block - read and write ONE tool's marked block in a shared instruction file (AGENTS.md, CLAUDE.md).

    python3 agents_block.py upsert <file> <name> [--body-file F]   body from F or stdin; creates the file if missing
    python3 agents_block.py get <file> <name>                      print the block body; exit 1 if absent
    python3 agents_block.py sha <file> <name>                      sha256 of the block body; exit 1 if absent

Convention: a tool owns only the text between `<!-- <name>:start -->` and `<!-- <name>:end -->`. Everything outside
any block belongs to the humans (or to other tools' blocks) and is never touched. Upsert is idempotent: it replaces
the block in place, or appends it once. Stdlib only.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
from pathlib import Path


def markers(name: str) -> tuple[str, str]:
    return f"<!-- {name}:start -->", f"<!-- {name}:end -->"


def pattern(name: str) -> re.Pattern:
    start, end = map(re.escape, markers(name))
    return re.compile(rf"^{start}[ \t]*\n(.*?)^{end}[ \t]*$", re.S | re.M)


def get(text: str, name: str) -> str | None:
    found = pattern(name).findall(text)
    if len(found) > 1:
        raise SystemExit(f"agents_block: {len(found)} '{name}' blocks; keep exactly one")
    return found[0].rstrip("\n") if found else None


def upsert(text: str, name: str, body: str) -> str:
    start, end = markers(name)
    block = f"{start}\n{body.strip()}\n{end}"
    if get(text, name) is not None:
        return pattern(name).sub(lambda _: block, text, count=1)
    return (text.rstrip("\n") + "\n\n" if text.strip() else "") + block + "\n"


def write_atomic(path: Path, text: str) -> None:
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("cmd", choices=["upsert", "get", "sha"])
    p.add_argument("file", type=Path)
    p.add_argument("name")
    p.add_argument("--body-file", type=Path)
    a = p.parse_args()
    text = a.file.read_text(encoding="utf-8") if a.file.exists() else ""
    if a.cmd == "upsert":
        body = a.body_file.read_text(encoding="utf-8") if a.body_file else sys.stdin.read()
        write_atomic(a.file, upsert(text, a.name, body))
        return
    body = get(text, a.name)
    if body is None:
        sys.exit(1)
    print(body if a.cmd == "get" else hashlib.sha256(body.encode("utf-8")).hexdigest())


if __name__ == "__main__":
    main()
