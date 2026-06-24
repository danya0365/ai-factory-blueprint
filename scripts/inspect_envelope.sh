#!/usr/bin/env bash
#
# inspect_envelope.sh — Line Inspector ตัวจริง: ตรวจ envelope ทุกขั้นของ JOB_ID ว่าครบกติกาเหล็ก
#
# READ-ONLY ทั้งหมด — ไม่แตะไฟล์ใดๆ  ไล่อ่าน agents/*/output/<JOB_ID>.json ตามลำดับสาย แล้วเช็ก:
#   - job_id ตรงกันทุกขั้น และตรงกับที่ขอ
#   - stage / produced_by ตรงกับชื่อโฟลเดอร์
#   - produced_at เป็น ISO-8601, status ∈ {ok,error,rejected}
#   - history ต่อเนื่อง ไม่ขาด ไม่ถูกลบ (ขั้นก่อนหน้าทั้งหมดยังอยู่ตามลำดับ + entry ล่าสุดเป็นขั้นนี้)
#
# ใช้งาน:
#   scripts/inspect_envelope.sh <JOB_ID>
#
# exit code: 0 = ผ่านหมด, 1 = พบปัญหา, 2 = ใช้งานผิด/ไม่พบไฟล์
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$ROOT/agents"

JOB_ID="${1:-}"
if [[ -z "$JOB_ID" ]]; then
  echo "usage: $0 <JOB_ID>" >&2
  exit 2
fi

# เก็บไฟล์ output ของ job นี้จากทุก agent เรียงตามชื่อโฟลเดอร์ (NN-prefix → เรียง = ลำดับสายพาน)
# ใช้ while-read แทน mapfile เพื่อรองรับ bash 3.2 (macOS default)
FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(find "$AGENTS_DIR" -maxdepth 3 -path "*/output/$JOB_ID.json" -type f | sort)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "ไม่พบ output ของ job '$JOB_ID' ใน agents/*/output/ — ยังไม่ได้รัน?" >&2
  exit 2
fi

JOB_ID="$JOB_ID" python3 - "${FILES[@]}" <<'PY'
import os, sys, json, re

job_id = os.environ["JOB_ID"]
files = sys.argv[1:]
ISO = re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$')
VALID_STATUS = {"ok", "error", "rejected"}

# ลำดับ stage ตามโฟลเดอร์ (parent ของ output/)
chain = [os.path.basename(os.path.dirname(os.path.dirname(f))) for f in files]

ok_all = True
print(f"\033[1mLine Inspector — job={job_id}  ({len(files)} stage)\033[0m")

def is_subsequence(sub, seq):
    it = iter(seq)
    return all(any(x == y for y in it) for x in sub)

for i, f in enumerate(files):
    stage = chain[i]
    problems = []
    try:
        env = json.load(open(f, encoding="utf-8"))
    except Exception as e:
        print(f"  \033[1;31m⚠ {stage}\033[0m : อ่าน JSON ไม่ได้ — {e}")
        ok_all = False
        continue

    if env.get("job_id") != job_id:
        problems.append(f"job_id = {env.get('job_id')!r} (ควรเป็น {job_id!r})")
    if env.get("stage") != stage:
        problems.append(f"stage = {env.get('stage')!r} (ควรเป็น {stage!r} ตามโฟลเดอร์)")
    if env.get("produced_by") != stage:
        problems.append(f"produced_by = {env.get('produced_by')!r} (ควรเป็น {stage!r})")
    pa = env.get("produced_at", "")
    if not isinstance(pa, str) or not ISO.match(pa):
        problems.append(f"produced_at = {pa!r} ไม่ใช่ ISO-8601")
    if env.get("status") not in VALID_STATUS:
        problems.append(f"status = {env.get('status')!r} (ต้องเป็น {sorted(VALID_STATUS)})")

    hist = env.get("history")
    if not isinstance(hist, list) or not hist:
        problems.append("history ว่างหรือไม่ใช่ list")
    else:
        hist_stages = [h.get("stage") for h in hist if isinstance(h, dict)]
        # ขั้นก่อนหน้าทั้งหมด (รวมขั้นนี้) ต้องยังอยู่ใน history ตามลำดับ = ไม่ถูกลบ/ไม่ขาด
        if not is_subsequence(chain[:i+1], hist_stages):
            problems.append(f"history ขาดช่วง/ผิดลำดับ: มี {hist_stages} ควรคลุม {chain[:i+1]}")
        if hist_stages and hist_stages[-1] != stage:
            problems.append(f"history entry ล่าสุด = {hist_stages[-1]!r} (ควรเป็นขั้นนี้ {stage!r})")
        for h in hist:
            if isinstance(h, dict) and not ISO.match(str(h.get("at", ""))):
                problems.append(f"history[{stage}] เวลา 'at' ไม่ใช่ ISO-8601: {h.get('at')!r}")
                break

    if problems:
        ok_all = False
        print(f"  \033[1;31m⚠ {stage}\033[0m")
        for p in problems:
            print(f"      - {p}")
    else:
        print(f"  \033[1;32m✅ {stage}\033[0m")

if ok_all:
    print("\033[1;32m✅ ผ่านทุกขั้น — envelope ครบกติกาเหล็ก\033[0m")
    sys.exit(0)
else:
    print("\033[1;31m⚠ พบปัญหา — ดูรายการด้านบน\033[0m")
    sys.exit(1)
PY
