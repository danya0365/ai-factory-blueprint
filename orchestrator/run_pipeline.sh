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

# ---------- run ----------
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || { err "ไม่พบคำสั่ง '$CLAUDE_BIN' บน PATH (ตั้ง CLAUDE_BIN ได้)"; exit 1; }

log "เริ่ม pipeline job=$JOB_ID  (permission-mode=$PERMISSION_MODE${MODEL:+, model=$MODEL})"
started=0
prev=""

for stage in "${STAGES[@]}"; do
  # ข้ามจนกว่าจะถึง --from
  if [[ -n "$FROM_STAGE" && $started -eq 0 ]]; then
    if [[ "$stage" == "$FROM_STAGE" ]]; then started=1; else prev="$stage"; continue; fi
  fi

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
  prev="$stage"
done

log "✅ pipeline เสร็จสมบูรณ์ job=$JOB_ID"
log "ผลสุดท้าย: $AGENTS_DIR/05-seed/output/$JOB_ID.json"
log "mock db:   $AGENTS_DIR/05-seed/db/seeded.jsonl"
