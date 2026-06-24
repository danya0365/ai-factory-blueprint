#!/usr/bin/env bash
#
# test_pipeline.sh — golden test แบบ integration: รันทั้งสายพานบน fixture แล้ว assert ผลลัพธ์
#
# fixture: tests/fixtures/job-test-0001.json (dirty 3 records — มี Somchai ซ้ำ 1)
# คาดหวัง: ingest 3 → refine/seed เหลือ 2 (dedup 1) → validate 2 ok → history ครบ 5 ขั้น
# ปิดท้ายด้วยเรียก inspect_envelope.sh ยืนยันกติกาเหล็ก
#
# ต้องมี claude CLI:  ตั้ง CLAUDE_BIN ถ้า claude ไม่อยู่บน PATH
#   CLAUDE_BIN=/path/to/claude scripts/test_pipeline.sh
#
# env: PERMISSION_MODE (default bypassPermissions — เพราะ 05-seed ต้องรัน seed_db.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOB_ID="job-test-0001"
FIXTURE="$ROOT/tests/fixtures/$JOB_ID.json"
INPUT_COPY="$ROOT/agents/01-ingest/input/$JOB_ID.json"
export PERMISSION_MODE="${PERMISSION_MODE:-bypassPermissions}"

log()  { printf '\033[1;34m[test]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[test:FAIL]\033[0m %s\n' "$*" >&2; }
pass() { printf '\033[1;32m[test:PASS]\033[0m %s\n' "$*"; }

[[ -f "$FIXTURE" ]] || { err "ไม่พบ fixture: $FIXTURE"; exit 1; }

# วาง fixture เข้า input ของ ingest แล้วเก็บกวาดออกตอนจบ (ไม่ให้รก repo)
cleanup() { rm -f "$INPUT_COPY"; }
trap cleanup EXIT
cp "$FIXTURE" "$INPUT_COPY"

log "รัน pipeline บน fixture $JOB_ID (permission-mode=$PERMISSION_MODE)"
"$ROOT/orchestrator/run_pipeline.sh" "$JOB_ID"

# ---------- assert ----------
log "ตรวจผลลัพธ์ที่คาดหวัง..."
JOB_ID="$JOB_ID" ROOT="$ROOT" python3 <<'PY'
import os, sys, json
root, job = os.environ["ROOT"], os.environ["JOB_ID"]
def load(stage):
    p = os.path.join(root, "agents", stage, "output", f"{job}.json")
    if not os.path.isfile(p):
        print(f"  ✗ ไม่พบ output: {p}"); sys.exit(1)
    return json.load(open(p, encoding="utf-8"))

fails = []
ing = load("01-ingest")
ref = load("02-refine")
val = load("04-validate")
seed = load("05-seed")

def check(cond, msg):
    print(("  ✓ " if cond else "  ✗ ") + msg)
    if not cond: fails.append(msg)

check(ing["data"].get("record_count") == 3, f"ingest record_count == 3 (ได้ {ing['data'].get('record_count')})")
check(ref["data"].get("record_count") == 2, f"refine record_count == 2 หลัง dedup (ได้ {ref['data'].get('record_count')})")
check(val["data"].get("valid_count") == 2, f"validate valid_count == 2 (ได้ {val['data'].get('valid_count')})")
check(val["data"].get("invalid_count", 0) == 0, f"validate invalid_count == 0 (ได้ {val['data'].get('invalid_count')})")
dbr = seed["data"].get("db_result", {})
check(dbr.get("written") == 2, f"seed written == 2 (ได้ {dbr.get('written')})")
hist_stages = [h.get("stage") for h in seed.get("history", [])]
check(hist_stages == ["01-ingest","02-refine","03-enrich","04-validate","05-seed"],
      f"history ครบ 5 ขั้นตามลำดับ (ได้ {hist_stages})")

sys.exit(1 if fails else 0)
PY
ASSERT_RC=$?

log "เรียก Line Inspector ยืนยันกติกาเหล็ก..."
"$ROOT/scripts/inspect_envelope.sh" "$JOB_ID"
INSPECT_RC=$?

if [[ $ASSERT_RC -eq 0 && $INSPECT_RC -eq 0 ]]; then
  pass "golden test ผ่านครบ (3→2→2 + history 5 ขั้น + envelope ถูกกติกา)"
  exit 0
else
  err "golden test ไม่ผ่าน (assert_rc=$ASSERT_RC inspect_rc=$INSPECT_RC)"
  exit 1
fi
