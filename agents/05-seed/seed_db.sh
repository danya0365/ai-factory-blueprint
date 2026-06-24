#!/usr/bin/env bash
#
# seed_db.sh — STUB ของการเขียนลง DB จริง
#
# Interface (คงไว้เมื่อต่อ DB จริง):
#   - รับ seed payload เป็น JSON ทาง stdin
#   - argument $1 = JOB_ID
#   - เขียน record ลง mock db: agents/05-seed/db/seeded.jsonl (append, 1 บรรทัด/record)
#   - เขียน log: agents/05-seed/db/seed.log
#   - คืน response JSON ทาง stdout เช่น: {"ok":true,"written":2,"db":"mock","job_id":"..."}
#
# เปลี่ยนเป็นของจริง: แทนที่ส่วน "WRITE TO DB" ด้วยการยิง REST API / เขียน Postgres ฯลฯ
# โดยยังรับ JSON ทาง stdin และคืน response JSON เหมือนเดิม
set -euo pipefail

JOB_ID="${1:-unknown-job}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="$SCRIPT_DIR/db"
DB_FILE="$DB_DIR/seeded.jsonl"
LOG_FILE="$DB_DIR/seed.log"
mkdir -p "$DB_DIR"

PAYLOAD="$(cat)"   # อ่าน seed payload (JSON) จาก stdin
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---- WRITE TO DB (stub) ----
# รองรับ payload เป็น array ของ records หรือ object ที่มี key "seed"/"records"
# ส่ง payload เข้าทาง env var (PAYLOAD) เพราะ stdin ถูกใช้โหลดสคริปต์ python อยู่แล้ว
WRITTEN=$(PAYLOAD="$PAYLOAD" python3 - "$JOB_ID" "$DB_FILE" "$TS" <<'PY'
import os, sys, json
job_id, db_file, ts = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.loads(os.environ.get("PAYLOAD", ""))
except Exception:
    data = []
# หา list ของ records
if isinstance(data, dict):
    records = data.get("seed") or data.get("records") or [data]
elif isinstance(data, list):
    records = data
else:
    records = []
with open(db_file, "a", encoding="utf-8") as f:
    for r in records:
        f.write(json.dumps({"job_id": job_id, "seeded_at": ts, "record": r}, ensure_ascii=False) + "\n")
print(len(records))
PY
)
# ----------------------------

echo "[$TS] job=$JOB_ID seeded=$WRITTEN -> $DB_FILE" >> "$LOG_FILE"

# response JSON
printf '{"ok":true,"written":%s,"db":"mock","job_id":"%s","at":"%s"}\n' "$WRITTEN" "$JOB_ID" "$TS"
