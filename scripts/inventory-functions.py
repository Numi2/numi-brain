#!/usr/bin/env python3
"""Read-only lexical inventory. It is not a compiler call graph or a dead-code proof.

Lists declarations, same-name lexical calls, source hashes and ownership hints.
Dynamic callbacks, reflection, overload resolution and string interpolation require
compiler/runtime inspection. No function is classified as removable automatically.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SUFFIXES = {".swift", ".metal", ".h", ".hpp", ".cpp", ".mm", ".c"}
TOKEN = re.compile(r"\b[A-Za-z_][A-Za-z_0-9]*\s*\(")
SWIFT = re.compile(r"\bfunc\s+([A-Za-z_][A-Za-z_0-9]*)\s*(?:<[^\n{]*>)?\s*\(")
KERNEL = re.compile(r"\bkernel\s+\w+\s+([A-Za-z_][A-Za-z_0-9]*)\s*\(")


def lexical_text(source: str) -> str:
    """Remove common comments/string literals, preserving offsets and line numbers."""
    out = list(source)
    i = 0
    while i < len(source):
        start = i
        if source.startswith("//", i):
            end = source.find("\n", i)
            i = len(source) if end < 0 else end
        elif source.startswith("/*", i):
            depth = 1
            i += 2
            while i < len(source) and depth:
                if source.startswith("/*", i):
                    depth += 1; i += 2
                elif source.startswith("*/", i):
                    depth -= 1; i += 2
                else:
                    i += 1
        elif source.startswith('"""', i):
            end = source.find('"""', i + 3)
            i = len(source) if end < 0 else end + 3
        elif source[i] == '"':
            i += 1
            while i < len(source):
                if source[i] == "\\":
                    i += 2
                elif source[i] == '"':
                    i += 1; break
                else:
                    i += 1
            i = min(i, len(source))
        else:
            i += 1; continue
        for j in range(start, i):
            if out[j] != "\n":
                out[j] = " "
    return "".join(out)


def owner(path: str) -> str:
    if "CLI/" in path:
        return "orchestration-interface"
    if "NumiBrainValidation/" in path or "NumiBrainQualification/" in path:
        return "offline-reference-or-diagnostic"
    if "NumiBrainMLX/" in path:
        return "off-rollout-learning"
    if "NumiBrainMetal/" in path:
        return "metal-runtime-or-adapter-review-required"
    if "NumiBrainCore/Experiments/" in path or "NumiBrainCore/Validation/" in path:
        return "retained-evidence-adapter"
    return "schema-runtime-or-native-abi-review-required"


def inventory(root: Path) -> dict[str, Any]:
    source_root = root / "Sources"
    if not source_root.is_dir():
        raise ValueError("repository must contain Sources/")
    files = []
    declarations = []
    calls: dict[str, list[dict[str, Any]]] = {}
    for path in sorted(source_root.rglob("*")):
        if path.suffix not in SUFFIXES or not path.is_file() or path.is_symlink():
            continue
        raw = path.read_bytes()
        if len(raw) > 8 * 1024 * 1024:
            raise ValueError(f"source exceeds 8 MiB: {path}")
        text = lexical_text(raw.decode("utf-8"))
        relative = str(path.relative_to(root))
        files.append({"path": relative, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)})
        matches = list(SWIFT.finditer(text)) if path.suffix == ".swift" else list(KERNEL.finditer(text))
        declaration_positions = {m.start(1) for m in matches}
        for match in matches:
            declarations.append({"path": relative, "line": text.count("\n", 0, match.start()) + 1,
                                 "symbol": match.group(1), "owner_hint": owner(relative)})
        for match in TOKEN.finditer(text):
            if match.start() in declaration_positions:
                continue
            symbol = match.group().split("(")[0].strip()
            calls.setdefault(symbol, []).append({"path": relative, "line": text.count("\n", 0, match.start()) + 1})
    for declaration in declarations:
        candidates = calls.get(declaration["symbol"], [])
        declaration["same_name_call_candidates"] = candidates[:100]
        declaration["same_name_call_candidate_count"] = len(candidates)
        declaration["removal_authorized"] = False
    return {"format_version": 1, "scope": "filesystem-lexical-inventory-not-runtime-coverage",
            "limitations": ["No overload resolution or dispatch analysis.",
                            "Native callbacks, operator overloads, constructors and generated/string-bound uses need separate review.",
                            "Missing lexical references do not establish unused or safe-to-remove code."],
            "files": files, "declarations": declarations}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.repo.resolve()
    output = args.output.resolve()
    if output == root or root / "Sources" in output.parents or root / "Tests" in output.parents:
        parser.error("output cannot replace repository source or tests")
    report = inventory(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Do not overwrite previous evidence: use a revision-specific output path.
    with output.open("x", encoding="utf-8") as file:
        json.dump(report, file, indent=2, sort_keys=True)
        file.write("\n")


if __name__ == "__main__":
    main()
