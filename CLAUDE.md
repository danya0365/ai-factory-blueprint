# AI Factory Blueprint — Project Context

> ไฟล์นี้คือ **บริบทโปรเจกต์** ที่ Claude Code โหลดอัตโนมัติเมื่อเปิด session ในโฟลเดอร์นี้
> เก็บใน git → ย้ายเครื่อง/clone ใหม่แล้วยังคุยเรื่องเดิมต่อได้ทันที
> (รายละเอียดวิธีใช้เต็มอยู่ที่ [README.md](README.md); สัญญาข้อมูลอยู่ที่ [shared/envelope.md](shared/envelope.md))

## ผู้ช่วยประจำโรงงาน

ผู้ช่วยที่คุมโปรเจกต์นี้รับบทเป็น **Foreman (ช่างหมาย)** — ฟอร์แมนคุมไลน์ผลิต ที่คุยกับเจ้าของโรงงาน
วางแผน สั่งสายพานเดิน และตรวจคุณภาพ (ไม่ใช่คนงานในสายพาน — คนงานคือ agent 01–05)
ตัวตน บทบาท น้ำเสียง และ skill เต็มอยู่ที่ [shared/foreman.md](shared/foreman.md)

@shared/foreman.md

## โปรเจกต์นี้คืออะไร

ระบบ orchestrate **AI agent หลายตัวให้ทำงานต่อกันเป็นสายพานโรงงาน** (upstream → final)
แต่ละ agent ("โรงงาน") รับงานจากตัวก่อนหน้า ประมวลผล แล้วบันทึกผลเป็นไฟล์ใหม่ในโฟลเดอร์ของตัวเอง

```
input/ → 01-ingest → 02-refine → 03-enrich → 04-validate → 05-seed → DB (stub)
```

- งานหนึ่ง = `JOB_ID` หนึ่งตัว ไหลผ่านทั้งสาย ชื่อไฟล์ผลลัพธ์เป็น `<JOB_ID>.json` เสมอ
- แต่ละ agent คือ **Claude Code headless** (`claude -p`) ที่อ่าน `CLAUDE.md` ของโฟลเดอร์ตัวเองเป็นคำสั่งงาน
- ทุกไฟล์ใช้ envelope เดียวกัน: `job_id`, `stage`, `produced_by`, `produced_at`, `status`, `data`, `issues`, `history`

## กติกาเหล็ก (ห้ามละเมิด)

1. agent อ่าน input จาก `output/` ของ agent ก่อนหน้า — **อ่านอย่างเดียว**
2. เขียนผลลง `output/<JOB_ID>.json` ของ **โฟลเดอร์ตัวเองเท่านั้น** — **ห้ามแก้ไฟล์ของ agent อื่น**
3. คัดลอก envelope จาก upstream → ต่อยอด `data`/`issues` → ต่อ entry ใน `history` (ห้ามลบของเดิม) → อัปเดต `stage`/`produced_by`/`produced_at`
4. `job_id` คงที่ตลอดสาย

## โครงสร้าง

```
orchestrator/run_pipeline.sh   # orchestrator: รัน claude -p ทีละ agent ตามลำดับ + ตรวจ output
shared/envelope.md             # data contract
agents/01-ingest/   CLAUDE.md, input/(+sample), output/   # ตัวเริ่ม: ไฟล์ดิบ → envelope
agents/02-refine/   CLAUDE.md, output/                    # ทำความสะอาด/normalize/ตัดซ้ำ
agents/03-enrich/   CLAUDE.md, output/                    # เติม/derive fields
agents/04-validate/ CLAUDE.md, output/                    # ตรวจ schema/rules
agents/05-seed/     CLAUDE.md, seed_db.sh, db/, output/   # แปลงเป็น seed → เขียน DB (stub)
```

> root `CLAUDE.md` (ไฟล์นี้) = ภาพรวมโปรเจกต์; `agents/*/CLAUDE.md` = บทบาทเฉพาะของแต่ละ agent; `shared/foreman.md` = ตัวตนผู้ช่วยที่คุมสายพาน — เสริมกัน ไม่ชนกัน

## วิธีรัน

```bash
./orchestrator/run_pipeline.sh job-2026-0001
```

**Gotchas สำคัญ:**
- `claude` CLI อาจ**ไม่อยู่บน PATH** (เช่นรันผ่าน VSCode extension) → ตั้ง `CLAUDE_BIN=/path/to/claude`
- ขั้น `05-seed` ต้องรัน bash (`seed_db.sh`) → ใช้ `PERMISSION_MODE=bypassPermissions` เวลารันอัตโนมัติเต็มรูปแบบ
- ผลรัน (`agents/*/output/*.json`) และ mock db (`agents/05-seed/db/`) ถูก `.gitignore` ไว้ (เป็น artifact สร้างใหม่ได้)

## สถานะปัจจุบัน (อัปเดต 2026-06-24)

- ✅ Blueprint ครบ 5 agent + orchestrator + data contract
- ✅ ทดสอบ end-to-end ด้วย `job-2026-0001` ผ่าน (3 raw → dedup เหลือ 2 → seed 2, history ครบ 5 ขั้น, input ไม่ถูกแก้)
- ✅ `.gitignore` ตั้งค่าแล้ว (artifact/secrets/noise)
- ⏳ DB ยังเป็น **stub** (`seed_db.sh` เขียน mock db) — ยังไม่ต่อของจริง
- ⏳ ยังไม่ได้ `git commit` ครั้งแรก

## สิ่งที่อาจทำต่อ

- เปลี่ยน `agents/05-seed/seed_db.sh` จาก stub → API/DB จริง (คง interface: รับ JSON ทาง stdin, คืน response JSON)
- เพิ่มโหมด **watch**: จับไฟล์ใหม่ใน `agents/01-ingest/input/` แล้วรัน pipeline อัตโนมัติ
- ปรับบทบาท agent ให้ตรง use case จริง (ปัจจุบันเป็น blueprint กลางๆ: ingest→refine→enrich→validate→seed)
- เพิ่ม agent ในสายพาน: สร้างโฟลเดอร์ `agents/NN-ชื่อ/` + CLAUDE.md + `output/` แล้วเพิ่มชื่อใน `STAGES` ของ `run_pipeline.sh`
