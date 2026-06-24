#!/usr/bin/env bash
#
# new-agent.sh — scaffold คนงาน (stage) ใหม่บนสายพาน จาก template กลาง
#
# สร้างโฟลเดอร์ agents/<NN-name>/ พร้อม CLAUDE.md + persona.md (เติมจาก shared/templates/)
# และ output/.gitkeep  —  ไม่ทับของเดิมถ้ามีอยู่แล้ว
# จบด้วยพิมพ์คำสั่งที่ต้องไปเติมเองใน STAGES=(...) ของ orchestrator/run_pipeline.sh
#
# ใช้งาน:
#   scripts/new-agent.sh <NN-name> [--first]
#
# ตัวอย่าง:
#   scripts/new-agent.sh 06-export
#   scripts/new-agent.sh 01-ingest --first      # --first = สร้างโฟลเดอร์ input/ ให้ด้วย (ตัวเริ่มสาย)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL_DIR="$ROOT/shared/templates"

log() { printf '\033[1;34m[new-agent]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[new-agent:ERROR]\033[0m %s\n' "$*" >&2; }

NAME="${1:-}"
WITH_INPUT=0
[[ "${2:-}" == "--first" ]] && WITH_INPUT=1

if [[ -z "$NAME" ]]; then
  echo "usage: $0 <NN-name> [--first]   (เช่น 06-export)" >&2
  exit 2
fi
# ชื่อต้องเป็นรูปแบบ NN-name (เลขสองหลัก ขีด ชื่อ a-z0-9-)
if [[ ! "$NAME" =~ ^[0-9]{2}-[a-z0-9-]+$ ]]; then
  err "ชื่อ stage ต้องเป็นรูปแบบ NN-name เช่น 06-export (เลขสองหลัก-ชื่อพิมพ์เล็ก)"
  exit 2
fi

DIR="$ROOT/agents/$NAME"
if [[ -e "$DIR" ]]; then
  err "มี agents/$NAME อยู่แล้ว — ไม่ทับของเดิม (ลบเองก่อนถ้าต้องการสร้างใหม่)"
  exit 1
fi
for t in agent-CLAUDE.template.md agent-persona.template.md; do
  [[ -f "$TPL_DIR/$t" ]] || { err "ไม่พบ template: $TPL_DIR/$t"; exit 1; }
done

mkdir -p "$DIR/output"
: > "$DIR/output/.gitkeep"
if [[ $WITH_INPUT -eq 1 ]]; then
  mkdir -p "$DIR/input"
  : > "$DIR/input/.gitkeep"
fi

# เติม placeholder ที่รู้แน่ ({{STAGE}}) — ที่เหลือปล่อยให้กรอกเอง
sed "s/{{STAGE}}/$NAME/g" "$TPL_DIR/agent-CLAUDE.template.md"  > "$DIR/CLAUDE.md"
sed "s/{{STAGE}}/$NAME/g" "$TPL_DIR/agent-persona.template.md" > "$DIR/persona.md"

log "✔ สร้าง agents/$NAME แล้ว (CLAUDE.md + persona.md + output/$([[ $WITH_INPUT -eq 1 ]] && echo ' + input/'))"
echo
log "ขั้นต่อไป (ทำเอง):"
echo "  1) เปิด agents/$NAME/persona.md  → แทน {{NICKNAME}} {{ROLE}} {{UPSTREAM}} และกรอกตัวตนคนงาน"
echo "  2) เปิด agents/$NAME/CLAUDE.md   → แทน {{TITLE}} {{SHORT_DESC}} {{ONE_LINE_JOB}} {{UPSTREAM}} ฯลฯ + เขียน 'สิ่งที่ต้องทำ'"
echo "  3) เติมชื่อขั้นลง STAGES ใน orchestrator/run_pipeline.sh เช่น:"
echo "       STAGES=(01-ingest 02-refine 03-enrich 04-validate $NAME 05-seed)"
echo "     (วางให้ถูกลำดับสายพาน — ตัวก่อนหน้าใน STAGES คือ upstream ของ $NAME)"
