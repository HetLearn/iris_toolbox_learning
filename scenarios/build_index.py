"""Write scenarios/sw07/INDEX.csv, one row per scenario file in the folders of scenarios/sw07/.

    "C:\\Program Files\\Python314\\python.exe" scenarios/build_index.py

Python 3, standard library only; reads the .m files as text (nothing is run). Since 2026-10-18
(track H1) the scenario files sit in subfolders (base, app1_peak ... app6_history,
var1_re_variant ... var4_gain, eval); the round 1-2 files are in archive/2026-10-18_rounds1-2/.
Columns:
  folder       subfolder of scenarios/sw07/ that holds the file
  id           cfg.id set in the file (else the file name)
  parent       the function called in the first `cfg = <fn>();` line, or none (`cfg = struct();`)
  options      every `cfg.<path> = <value>` the file sets other than id, title, description and
               compare_with, as `path = value`, semicolon-separated (inherited options are not listed)
  compare_with the value set in the file ('' = inherited from the parent)
  has_results  results/<id>/results.mat exists (evaluation variants: their parts exist in
               results/eval_sw07_v3/parts/eval_<id>_p<k>/)
  title        cfg.title set in the file ('' = inherited)
The script checks that the row count equals the number of .m files and exits with status 1 if not.
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCEN = ROOT / "scenarios" / "sw07"
RES = ROOT / "results"
EVAL_PARTS = RES / "eval_sw07_v3" / "parts"
SKIP = {"id", "title", "description", "compare_with"}


def strip_comment(line):
    """Remove a % comment, ignoring % inside single-quoted strings ('' is an escaped quote)."""
    out, i, in_str = [], 0, False
    while i < len(line):
        ch = line[i]
        if in_str:
            if ch == "'" and i + 1 < len(line) and line[i + 1] == "'":
                out.append("''")
                i += 2
                continue
            if ch == "'":
                in_str = False
        else:
            if ch == "%":
                break
            if ch == "'":
                prev = out[-1] if out else " "
                if not (prev.isalnum() or prev in ")]}._'"):
                    in_str = True        # otherwise a transpose
        out.append(ch)
        i += 1
    return "".join(out).rstrip()


def statements(text):
    """Code statements with '...' continuations joined, comments removed."""
    stmts, cur = [], ""
    for raw in text.splitlines():
        code = strip_comment(raw)
        if not code.strip():
            if cur:
                stmts.append(cur.strip())
                cur = ""
            continue
        if code.rstrip().endswith("..."):
            cur += code.rstrip()[:-3] + " "
            continue
        cur += code
        stmts.append(cur.strip())
        cur = ""
    if cur.strip():
        stmts.append(cur.strip())
    return [re.sub(r"\s+", " ", s) for s in stmts]


def literal(value):
    """Text of a MATLAB char literal or [ 'a' 'b' ] concatenation; else the value as written."""
    v = value.strip()
    parts = re.findall(r"'((?:[^']|'')*)'", v)
    rest = re.sub(r"'((?:[^']|'')*)'", "", v).strip()
    if parts and rest in ("", "[]", "[ ]", "[,]") or (parts and re.fullmatch(r"\[[\s,]*\]", rest or "[]")):
        return "".join(p.replace("''", "'") for p in parts)
    return v


def main():
    files = sorted(f for f in SCEN.rglob("*.m"))
    rows = []
    for f in files:
        st = statements(f.read_text(encoding="utf-8", errors="replace"))
        parent, opts, cmp_, title, cid = "none", [], "", "", ""
        for s in st:
            m = re.match(r"^cfg\s*=\s*([A-Za-z]\w*)\s*\(\s*\)\s*;?$", s)
            if m and parent == "none" and not opts:
                parent = "none" if m.group(1) == "struct" else m.group(1)
                continue
            m = re.match(r"^cfg\.([A-Za-z][\w.]*(?:\([^)]*\))?(?:\.[A-Za-z]\w*)*)\s*=(?!=)\s*(.*?);?$", s)
            if not m:
                continue
            path, val = m.group(1), m.group(2).strip()
            if path == "id":
                cid = literal(val)
            elif path == "title":
                title = literal(val)
            elif path == "compare_with":
                cmp_ = val
            elif path not in SKIP:
                opts.append(f"{path} = {val}")
        rid = cid or f.stem
        if cid and cid != f.stem:
            print(f"warning: {f.name} sets cfg.id = '{cid}'", file=sys.stderr)
        folder = f.parent.relative_to(SCEN).as_posix()
        has = (RES / rid / "results.mat").exists() or any(EVAL_PARTS.glob(f"eval_{rid}_p*/errors_long.csv"))
        rows.append(dict(folder=folder, id=rid, parent=parent, options="; ".join(opts),
                         compare_with=cmp_, has_results=str(has).lower(), title=title))
    out = SCEN / "INDEX.csv"
    cols = ["folder", "id", "parent", "options", "compare_with", "has_results", "title"]
    with out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow(r)
    n = len(rows)
    by = {}
    for r in rows:
        by[r["folder"]] = by.get(r["folder"], 0) + 1
    print(f"{out}: {n} rows, {len(files)} .m files under {SCEN}: {'OK' if n == len(files) else 'MISMATCH'}")
    print("rows by folder: " + ", ".join(f"{a} {c}" for a, c in sorted(by.items())))
    print(f"with results: {sum(r['has_results'] == 'true' for r in rows)}")
    return 0 if n == len(files) else 1


if __name__ == "__main__":
    sys.exit(main())
