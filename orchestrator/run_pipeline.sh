#!/usr/bin/env bash
#
# run_pipeline.sh — Orchestrator ของ AI Factory Blueprint
#
# รัน agent 5 ตัวต่อกันเป็นสายพาน (01-ingest → 05-seed) ด้วย Claude Code headless (`claude -p`)
# แต่ละ agent อ่าน CLAUDE.md ของโฟลเดอร์ตัวเองอัตโนมัติ, อ่าน input จาก output ของ agent ก่อนหน้า,
# แล้วเขียน output/<JOB_ID>.json ของตัวเอง  Orchestrator จะตรวจว่าไฟล์ออกมาจริงก่อนไปขั้นถัดไป
#
# ใช้งาน:
#   ./orchestrator/run_pipeline.sh <JOB_ID> [--from <stage>]
#
# ตัวอย่าง:
#   ./orchestrator/run_pipeline.sh job-2026-0001
#   ./orchestrator/run_pipeline.sh job-2026-0001 --from 03-enrich
#
# ตัวแปร env ที่ปรับได้:
#   CLAUDE_BIN          คำสั่ง claude (default: claude)
#   PERMISSION_MODE     โหมดสิทธิ์ของ claude -p (default: acceptEdits)
#                       * stage 05-seed ต้องรัน seed_db.sh -> ใช้ bypassPermissions ถ้าต้องการรันอัตโนมัติเต็มรูปแบบ
#   MODEL               โมเดล (default: ปล่อยให้ claude เลือกเอง)
#   MAX_RETRIES         เพดานจำนวนครั้งที่ gate ตีงานกลับได้ต่อด่าน (default: 2) — กัน reject loop วนไม่จบ
#
# Reject loop: ถ้า stage ใดเขียน output ที่มี status="rejected" + reject_to="<stage ก่อนหน้า>"
#   orchestrator จะกระโดดกลับไปรัน stage นั้นใหม่ (นับครั้งต่อด่าน, ครบ MAX_RETRIES แล้วหยุด)
set -euo pipefail

# ---------- args ----------
JOB_ID="${1:-}"
if [[ -z "$JOB_ID" || "$JOB_ID" == --* ]]; then
  echo "usage: $0 <JOB_ID> [--from <stage>]" >&2
  exit 2
fi
shift || true

FROM_STAGE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM_STAGE="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ---------- paths & config ----------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$ROOT/agents"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PERMISSION_MODE="${PERMISSION_MODE:-acceptEdits}"
MODEL="${MODEL:-}"
MAX_RETRIES="${MAX_RETRIES:-2}"

# ลำดับ agent บนสายพาน
STAGES=(01-ingest 02-refine 03-enrich 04-validate 05-seed)

log() { printf '\033[1;34m[pipeline]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[pipeline:ERROR]\033[0m %s\n' "$*" >&2; }

# prompt เฉพาะของแต่ละ stage (บอก context — รายละเอียดงานอยู่ใน CLAUDE.md)
stage_prompt() {
  local stage="$1" prev="$2"
  if [[ "$stage" == "01-ingest" ]]; then
    echo "JOB_ID=$JOB_ID. คุณคือ agent ตัวแรก อ่านไฟล์ดิบจากโฟลเดอร์ input/ (มองหา input/$JOB_ID.json ก่อน) ทำงานตาม CLAUDE.md ในโฟลเดอร์นี้ แล้วเขียนผลลง output/$JOB_ID.json"
  else
    echo "JOB_ID=$JOB_ID. อ่าน input จาก ../$prev/output/$JOB_ID.json (อ่านอย่างเดียว ห้ามแก้) ทำงานตาม CLAUDE.md ในโฟลเดอร์นี้ แล้วเขียนผลลง output/$JOB_ID.json เท่านั้น"
  fi
}

# อ่าน field ระดับบนสุดจาก envelope JSON (python3 — เลี่ยง jq ที่อาจไม่ติดตั้ง)
json_field() {  # $1=file $2=key
  python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))
except Exception: print("")' "$1" "$2"
}

# หา index ของ stage ใน STAGES (คืน -1 ถ้าไม่เจอ)
stage_index() {  # $1=name
  local i
  for i in "${!STAGES[@]}"; do [[ "${STAGES[$i]}" == "$1" ]] && { echo "$i"; return; }; done
  echo "-1"
}

# ---------- run ----------
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || { err "ไม่พบคำสั่ง '$CLAUDE_BIN' บน PATH (ตั้ง CLAUDE_BIN ได้)"; exit 1; }

log "เริ่ม pipeline job=$JOB_ID  (permission-mode=$PERMISSION_MODE${MODEL:+, model=$MODEL}, max-retries=$MAX_RETRIES)"

# หา index เริ่ม (รองรับ --from)
start_idx=0
if [[ -n "$FROM_STAGE" ]]; then
  start_idx="$(stage_index "$FROM_STAGE")"
  [[ "$start_idx" -ge 0 ]] || { err "ไม่รู้จัก --from stage: $FROM_STAGE"; exit 1; }
fi

REJECTS=()   # indexed array นับรอบตีกลับ คีย์ด้วย index ของด่าน gate ใน STAGES (รองรับ bash 3.2)
i="$start_idx"

while [[ $i -lt ${#STAGES[@]} ]]; do
  stage="${STAGES[$i]}"
  prev=""; [[ $i -gt 0 ]] && prev="${STAGES[$((i-1))]}"
  dir="$AGENTS_DIR/$stage"
  out="$dir/output/$JOB_ID.json"
  [[ -d "$dir" ]] || { err "ไม่พบโฟลเดอร์ agent: $dir"; exit 1; }

  log "▶ $stage : เริ่มทำงาน"
  t0=$(date +%s)

  claude_args=(-p "$(stage_prompt "$stage" "$prev")" --permission-mode "$PERMISSION_MODE")
  [[ -n "$MODEL" ]] && claude_args+=(--model "$MODEL")

  ( cd "$dir" && "$CLAUDE_BIN" "${claude_args[@]}" ) || { err "$stage : claude -p ล้มเหลว"; exit 1; }

  # ตรวจว่า output ถูกสร้างจริงก่อนไปต่อ
  if [[ ! -f "$out" ]]; then
    err "$stage : ไม่พบไฟล์ output ที่คาดไว้: $out — หยุด pipeline"
    exit 1
  fi

  t1=$(date +%s)
  log "✔ $stage : เสร็จใน $((t1 - t0))s -> output/$JOB_ID.json"

  # ---- reject loop: gate ตีงานกลับ upstream ----
  if [[ "$(json_field "$out" status)" == "rejected" ]]; then
    target="$(json_field "$out" reject_to)"
    [[ -n "$target" ]] || { err "$stage : status=rejected แต่ไม่มี reject_to — หยุด"; exit 1; }
    tidx="$(stage_index "$target")"
    if [[ "$tidx" -lt 0 || "$tidx" -ge "$i" ]]; then
      err "$stage : reject_to='$target' ต้องเป็น stage ก่อนหน้าในสายเท่านั้น — หยุด"; exit 1
    fi
    REJECTS[$i]=$(( ${REJECTS[$i]:-0} + 1 ))
    if [[ ${REJECTS[$i]} -gt $MAX_RETRIES ]]; then
      err "$stage : ตีกลับครบเพดาน ($MAX_RETRIES รอบ) แล้วยังไม่ผ่าน — หยุด pipeline ที่ gate นี้ ⚠️"
      exit 1
    fi
    log "↩ $stage : ตีงานกลับไป $target (รอบ ${REJECTS[$i]}/$MAX_RETRIES)"
    i="$tidx"
    continue
  fi

  i=$(( i + 1 ))
done

log "✅ pipeline เสร็จสมบูรณ์ job=$JOB_ID"
log "ผลสุดท้าย: $AGENTS_DIR/05-seed/output/$JOB_ID.json"
log "mock db:   $AGENTS_DIR/05-seed/db/seeded.jsonl"
