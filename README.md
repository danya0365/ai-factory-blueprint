# AI Factory Blueprint — สายพานโรงงาน AI agent

ระบบ orchestrate **AI agent หลายตัวให้ทำงานต่อกันเป็นลำดับ** เหมือนสายพานในโรงงาน
แต่ละ agent ("โรงงาน") รับงานจาก agent ตัวก่อนหน้า ประมวลผล แล้วบันทึกผล **เป็นไฟล์ใหม่ในโฟลเดอร์ของตัวเอง**

```
input/  →  01-ingest  →  02-refine  →  03-enrich  →  04-validate  →  05-seed  →  DB (stub)
              │             │             │              │              │
           output/       output/       output/        output/        output/   + mock db
          job.json      job.json      job.json       job.json       job.json
```

## หลักการ

- งานหนึ่งงาน = `JOB_ID` หนึ่งตัว ที่ไหลผ่านทั้งสายพาน ชื่อไฟล์ผลลัพธ์เป็น `<JOB_ID>.json` เสมอ
- แต่ละ agent คือ **Claude Code headless** (`claude -p`) ที่อ่าน `CLAUDE.md` ของโฟลเดอร์ตัวเองเป็นคำสั่งงาน
- **กติกาเหล็ก**: agent อ่าน input จาก output ของ agent ก่อนหน้า (อ่านอย่างเดียว) และ **เขียนเฉพาะโฟลเดอร์ตัวเอง** — ห้ามแก้ข้อมูลของ agent ตัวอื่น ทำให้ทุกขั้นมีสำเนาของตัวเอง ตรวจสอบย้อนหลังได้ครบ
- ทุกไฟล์ใช้ **envelope เดียวกัน** ดูสัญญาข้อมูลที่ [`shared/envelope.md`](shared/envelope.md)

## โครงสร้าง

```
ai-factory-blueprint/
├── orchestrator/run_pipeline.sh   # ตัว orchestrator: รัน claude -p ทีละ agent ตามลำดับ
├── shared/envelope.md             # data contract ที่ทุก agent ใช้ร่วมกัน
├── shared/foreman.md              # persona ของผู้ช่วย "Foreman (ช่างหมาย)" ที่คุมสายพาน (โหลดทุก session)
└── agents/
    ├── 01-ingest/   CLAUDE.md, input/, output/   # ตัวเริ่ม: รับไฟล์ดิบ → envelope
    ├── 02-refine/   CLAUDE.md, output/           # ทำความสะอาด/normalize/ตัดซ้ำ
    ├── 03-enrich/   CLAUDE.md, output/           # เติม/derive fields
    ├── 04-validate/ CLAUDE.md, output/           # ตรวจ schema/rules
    └── 05-seed/     CLAUDE.md, output/, seed_db.sh, db/   # แปลงเป็น seed → เขียน DB (stub)
```

## วิธีใช้

1. วางไฟล์ดิบลงใน `agents/01-ingest/input/` ตั้งชื่อ `<JOB_ID>.json` (มีตัวอย่าง `job-2026-0001.json` ให้แล้ว)
2. รัน orchestrator:

   ```bash
   ./orchestrator/run_pipeline.sh job-2026-0001
   ```

3. ผลลัพธ์แต่ละขั้นอยู่ที่ `agents/<stage>/output/<JOB_ID>.json` และผลสุดท้าย + mock db อยู่ที่ `agents/05-seed/`

### ตัวเลือก

```bash
./orchestrator/run_pipeline.sh job-2026-0001 --from 03-enrich   # รันต่อจากกลางสาย
```

ตัวแปร env ที่ปรับได้ (ดูหัวสคริปต์):

| env | ค่าเริ่มต้น | หมายเหตุ |
|-----|-----------|----------|
| `CLAUDE_BIN` | `claude` | path ของ Claude Code CLI — **ตั้งค่านี้ถ้า `claude` ไม่อยู่บน PATH** |
| `PERMISSION_MODE` | `acceptEdits` | สิทธิ์ของ `claude -p`; ขั้น `05-seed` ต้องรัน `seed_db.sh` (bash) — ใช้ `bypassPermissions` ถ้าจะรันอัตโนมัติเต็มรูปแบบ |
| `MODEL` | (ปล่อยว่าง) | บังคับโมเดล เช่น `claude-opus-4-8` |

> **หมายเหตุ**: ถ้า `claude` ไม่อยู่บน PATH (เช่นรันผ่าน VSCode extension)
> ให้ตั้ง `CLAUDE_BIN=/path/to/claude ./orchestrator/run_pipeline.sh <JOB_ID>`

## การต่อ DB จริง

ตอนนี้ขั้น seed เขียนลง **mock db** (`agents/05-seed/db/seeded.jsonl`) ผ่าน `seed_db.sh`
เปลี่ยนเป็นของจริงโดยแก้แค่ `seed_db.sh` ให้ยิง REST API / เขียน Postgres ฯลฯ
โดย **คง interface เดิม** (รับ JSON ทาง stdin, คืน response JSON) — สายพานและ CLAUDE.md ไม่ต้องแก้

## เพิ่ม agent ใหม่ในสายพาน

1. สร้างโฟลเดอร์ `agents/NN-ชื่อ/` พร้อม `CLAUDE.md` และ `output/`
2. ให้ CLAUDE.md อ่านจาก `../<stage-ก่อนหน้า>/output/<JOB_ID>.json` และเขียน `output/<JOB_ID>.json`
3. เพิ่มชื่อ stage ลงในอาเรย์ `STAGES` ใน `orchestrator/run_pipeline.sh`
