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
├── orchestrator/run_pipeline.sh   # ตัว orchestrator: รัน claude -p ทีละ agent + reject loop
├── shared/envelope.md             # data contract ที่ทุก agent ใช้ร่วมกัน (+ Reject loop)
├── shared/foreman.md              # persona ของผู้ช่วย "Foreman (ช่างหมาย)" ที่คุมสายพาน (โหลดทุก session)
├── shared/templates/              # แม่แบบ persona + CLAUDE.md สำหรับสร้าง agent ใหม่
├── scripts/
│   ├── new-agent.sh               # scaffold stage ใหม่จาก template
│   ├── new-factory.sh             # โคลน blueprint ทั้งโรงไปเป็นโรงงานใหม่
│   ├── inspect_envelope.sh        # Line Inspector: ตรวจ envelope ทุกขั้น (read-only)
│   └── test_pipeline.sh           # golden test: รันสายพานบน fixture แล้ว assert ผล
├── tests/fixtures/                # fixture สำหรับ golden test
└── agents/
    ├── 01-ingest/   CLAUDE.md, persona.md(ปุ้ย), input/, output/   # ตัวเริ่ม: รับไฟล์ดิบ → envelope
    ├── 02-refine/   CLAUDE.md, persona.md(กวาง), output/           # ทำความสะอาด/normalize/ตัดซ้ำ
    ├── 03-enrich/   CLAUDE.md, persona.md(พูน), output/            # เติม/derive fields
    ├── 04-validate/ CLAUDE.md, persona.md(เข้ม), output/           # ตรวจ schema/rules
    ├── 05-seed/     CLAUDE.md, persona.md(ปลาย), output/, seed_db.sh, db/   # seed → เขียน DB (stub)
    └── _blueprint-gate/  CLAUDE.md, persona.md(ด่าน)              # อะไหล่: gate ที่ตีงานกลับ (reject loop)
```

> คนงานแต่ละตัวมี **persona.md** (ตัวตน/ชื่อคนไทย) import เข้า CLAUDE.md ด้วย `@persona.md`
> เหมือนที่ root import `@shared/foreman.md`

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

ใช้ scaffold script (เร็วสุด):

```bash
scripts/new-agent.sh 06-export          # สร้าง agents/06-export/ จาก template (CLAUDE.md + persona.md + output/)
scripts/new-agent.sh 01-ingest --first  # --first = สร้างโฟลเดอร์ input/ ให้ด้วย (ตัวเริ่มสาย)
```

แล้วทำตามที่สคริปต์บอก: กรอก persona/ใบสั่งงาน (แทน placeholder) + เติมชื่อ stage ลง `STAGES`
ใน `orchestrator/run_pipeline.sh` (วางให้ถูกลำดับ — ตัวก่อนหน้าใน `STAGES` คือ upstream)

## ตรวจคุณภาพ + ทดสอบ

```bash
scripts/inspect_envelope.sh job-2026-0001   # ตรวจ envelope ทุกขั้น (read-only): job_id คงที่, history ต่อเนื่อง, stage ตรงโฟลเดอร์
CLAUDE_BIN=/path/to/claude scripts/test_pipeline.sh   # golden test: รันสายพานบน fixture แล้ว assert (3→2→2, history 5 ขั้น)
```

## QC loop (เด้งงานกลับไปแก้)

โดยปกติสายพานเดินหน้าทางเดียว ถ้าต้องการ gate ที่ **ตีงานกลับไปแก้ที่ขั้นก่อน**:

1. ก๊อป `agents/_blueprint-gate/` เป็น `agents/NN-gate/` (เช่น `045-gate`) แล้วปรับเกณฑ์ตรวจใน CLAUDE.md
2. เติมชื่อลง `STAGES` ในตำแหน่งที่ต้องการคั่น
3. เมื่อ gate ตั้ง `status:"rejected"` + `reject_to:"<stage ก่อนหน้า>"` → orchestrator วนกลับไปทำใหม่
   (เพดาน `MAX_RETRIES` default 2 กันวนไม่จบ) — ดูรายละเอียดสัญญาที่ [`shared/envelope.md`](shared/envelope.md) หัวข้อ Reject loop

## สร้างโรงงานใหม่จาก blueprint นี้

```bash
scripts/new-factory.sh ../my-new-factory   # โคลนทั้งโรง ตัด artifact/ของเฉพาะเครื่องออก พร้อมรัน demo
```

แล้วเปิด `FACTORY_TODO.md` ในโรงงานใหม่ ทำตามเช็กลิสต์ปรับแต่ง
