#!/usr/bin/env bash
#
# new-factory.sh — โคลน blueprint ทั้งโรงไปตั้งเป็น "โรงงานใหม่" ที่ <dest-dir>
#
# ก๊อปโครงทั้งหมด (shared/, orchestrator/, scripts/, agents/, .gitignore, README, CLAUDE.md)
# แล้ว **ตัด artifact/ของเฉพาะเครื่องออก** (.git, output ที่รันแล้ว, mock db, memory ส่วนตัว,
# .claude/settings.local.json) — โรงงานใหม่จึงพร้อมรัน demo ได้ทันที แล้วค่อยปรับแต่ง
# จบด้วยวาง FACTORY_TODO.md เป็นเช็กลิสต์สิ่งที่ต้องแก้
#
# ใช้งาน:
#   scripts/new-factory.sh <dest-dir>
#
# ตัวอย่าง:
#   scripts/new-factory.sh ../my-new-factory
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\033[1;34m[new-factory]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[new-factory:ERROR]\033[0m %s\n' "$*" >&2; }

DEST="${1:-}"
if [[ -z "$DEST" ]]; then
  echo "usage: $0 <dest-dir>" >&2
  exit 2
fi
if [[ -e "$DEST" ]]; then
  err "ปลายทาง '$DEST' มีอยู่แล้ว — เลือกที่ว่างที่ยังไม่มี"
  exit 1
fi

# ---------- copy ทั้งโครง ----------
cp -R "$ROOT" "$DEST"
DEST="$(cd "$DEST" && pwd)"   # absolute

# ---------- ตัด artifact / ของเฉพาะเครื่อง ----------
rm -rf "$DEST/.git"
rm -rf "$DEST/agents/05-seed/db"
rm -rf "$DEST/memory"
rm -f  "$DEST/.claude/settings.local.json"
# ล้างผลรันใน output/ ทุก agent แต่คง .gitkeep ไว้
find "$DEST/agents" -path '*/output/*' ! -name '.gitkeep' -type f -delete 2>/dev/null || true
# ล้าง log เก่า
find "$DEST" -name '*.log' -type f -delete 2>/dev/null || true

# ---------- เช็กลิสต์ปรับแต่ง ----------
cat > "$DEST/FACTORY_TODO.md" <<'TODO'
# โรงงานใหม่ — เช็กลิสต์ปรับแต่ง

โครงนี้โคลนมาจาก ai-factory-blueprint แล้ว **รัน demo ได้ทันที**:
`./orchestrator/run_pipeline.sh job-2026-0001`  (ต้องตั้ง CLAUDE_BIN ถ้า claude ไม่อยู่บน PATH)

เมื่อพร้อมปรับเป็น use case จริง:

- [ ] แก้ `CLAUDE.md` (root) — ชื่อ/เป้าหมายโรงงานใหม่
- [ ] แก้ `shared/foreman.md` — ตัวตน foreman ของโรงนี้ (ถ้าต้องการ)
- [ ] ปรับบทบาท + persona ของ agent แต่ละตัวใน `agents/*/CLAUDE.md` + `agents/*/persona.md`
      ให้ตรงงานจริง (หรือสร้างใหม่ด้วย `scripts/new-agent.sh <NN-name>`)
- [ ] ปรับ `STAGES=(...)` ใน `orchestrator/run_pipeline.sh` ให้ตรงกับ agent ที่มีจริง
- [ ] วางไฟล์ดิบของจริงไว้ที่ `agents/01-ingest/input/`
- [ ] เปลี่ยน `agents/05-seed/seed_db.sh` จาก stub → DB/API จริง (คง interface: stdin JSON → stdout JSON)
- [ ] `git init` แล้ว commit ครั้งแรก
- [ ] ลบไฟล์นี้เมื่อปรับเสร็จ
TODO

log "✅ สร้างโรงงานใหม่ที่ $DEST"
log "ลองรัน demo:  cd $DEST && ./orchestrator/run_pipeline.sh job-2026-0001"
log "รายการที่ต้องปรับ: $DEST/FACTORY_TODO.md"
