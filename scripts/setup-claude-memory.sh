#!/usr/bin/env bash
# setup-claude-memory.sh — ชี้ auto-memory ของ Claude Code มาที่ memory/ ใน repo นี้
#
# ทำไมต้องมี: ตัว setting `autoMemoryDirectory` เดินทางข้าม git แบบอัตโนมัติไม่ได้
# (กฎ workspace-trust ของ Claude Code) ดังนั้นบนเครื่องใหม่ให้รัน script นี้ 1 ครั้ง
# มันจะคำนวณ path ของ repo เอง (ไม่ฝัง path เครื่องไหนลง git) แล้วเขียน
# .claude/settings.local.json (ไฟล์นี้ถูก gitignore — เป็น machine-local)
#
# วิธีใช้:  ./scripts/setup-claude-memory.sh

set -euo pipefail

# repo root = โฟลเดอร์แม่ของ scripts/ (คำนวณตอนรัน → machine-independent)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$ROOT/.claude" "$ROOT/memory"

SETTINGS="$ROOT/.claude/settings.local.json"
cat > "$SETTINGS" <<EOF
{
  "autoMemoryDirectory": "$ROOT/memory"
}
EOF

echo "✅ ตั้งค่า auto-memory เรียบร้อย"
echo "   settings : $SETTINGS  (gitignored)"
echo "   memory   : $ROOT/memory"
echo ""
echo "เปิด Claude Code session ใหม่ในโฟลเดอร์นี้ แล้ว memory จะอ่าน/เขียนที่ memory/ ของ repo"
