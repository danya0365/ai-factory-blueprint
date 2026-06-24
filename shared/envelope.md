# Data Contract — Job Envelope

ทุก agent ในสายพานนี้สื่อสารกันผ่านไฟล์ `[job_id].json` ที่ใช้ **โครงสร้าง envelope เดียวกัน**
นี่คือสัญญา (contract) ที่ทุก agent ต้องเคารพ เพื่อให้ต่อกันได้และตรวจสอบย้อนหลังได้

---

## โครงสร้าง

```json
{
  "job_id": "job-2026-0001",
  "stage": "02-refine",
  "produced_by": "02-refine",
  "produced_at": "2026-06-24T10:00:00Z",
  "status": "ok",
  "data": {
    "...": "ผลลัพธ์หลักของขั้นนี้ — รูปแบบขึ้นกับ use case"
  },
  "issues": [],
  "history": [
    { "stage": "01-ingest", "at": "2026-06-24T09:59:00Z", "note": "ingested 3 records from sample-job.json" },
    { "stage": "02-refine", "at": "2026-06-24T10:00:00Z", "note": "deduped 1, normalized emails" }
  ]
}
```

## ความหมายของแต่ละ field

| field | ชนิด | ความหมาย |
|-------|------|----------|
| `job_id` | string | รหัสงานที่ไหลผ่านทั้งสายพาน **ห้ามเปลี่ยน** หลังจากขั้น ingest กำหนดแล้ว |
| `stage` | string | ชื่อขั้นล่าสุดที่ผลิตไฟล์นี้ (เช่น `01-ingest`, `02-refine`, ...) |
| `produced_by` | string | agent ที่เขียนไฟล์นี้ (เท่ากับ `stage` ในทางปฏิบัติ) |
| `produced_at` | string (ISO-8601 UTC) | เวลาที่ผลิตไฟล์นี้ |
| `status` | `"ok"` \| `"error"` \| `"rejected"` | สถานะของงาน ณ ขั้นนี้ ถ้า `error` ปลายทางควรหยุด/ข้าม; `"rejected"` ใช้โดย gate agent เพื่อตีงานกลับ upstream (ดู Reject loop) |
| `data` | object | เนื้อหาหลัก แต่ละขั้นปรับปรุง/ต่อยอด `data` ของขั้นก่อน |
| `issues` | array | ปัญหา/คำเตือนที่พบ (ใช้มากในขั้น validate) แต่ละ entry เช่น `{ "field": "...", "level": "warn\|error", "message": "..." }` |
| `history` | array | ประวัติทุกขั้นที่ผ่านมา — **ต่อท้ายเท่านั้น ห้ามลบของเดิม** |
| `reject_to` | string *(optional)* | ใช้คู่กับ `status:"rejected"` เท่านั้น — ชื่อ stage ปลายทางที่ต้องการให้สายพานวนกลับไปทำใหม่ (เช่น `"02-refine"`) |
| `attempts` | number *(optional)* | จำนวนรอบที่ job นี้ถูกตีกลับมาทำซ้ำ — orchestrator เป็นคนเพิ่มค่า ใช้กันวนไม่จบ |

> **Backward-compatible:** `reject_to` / `attempts` เป็น field เสริม — envelope ที่ไม่มีสอง field นี้
> ยัง valid 100% สายพานปกติ (ไม่มี gate) ไม่ต้องสนใจมันเลย

---

## กติกาเหล็ก (ทุก agent ต้องทำตาม)

1. **อ่านจาก upstream เท่านั้น เขียนลงโฟลเดอร์ของตัวเองเท่านั้น**
   - อ่านไฟล์ `[job_id].json` จาก `output/` ของ agent ก่อนหน้า (หรือ `input/` สำหรับ `01-ingest`)
   - เขียนผลลง `output/[job_id].json` ของ **โฟลเดอร์ตัวเอง** เท่านั้น
2. **ห้ามแก้ไฟล์ของ agent ตัวอื่นโดยเด็ดขาด** — ไม่ว่า upstream หรือ downstream
3. **คัดลอกแล้วต่อยอด**: เริ่มจาก envelope ของ upstream → ปรับ `data`/`issues` ตามหน้าที่ →
   ต่อ entry ใหม่ใน `history` → อัปเดต `stage`, `produced_by`, `produced_at` → เขียนเป็นไฟล์ใหม่
4. **`job_id` คงที่ตลอดสาย** — ชื่อไฟล์ output ต้องเป็น `[job_id].json` เสมอ
5. **ห้ามทิ้ง `history` เดิม** — ต้องเห็นเส้นทางครบทุกขั้นในไฟล์ของขั้นสุดท้าย
6. เวลาทั้งหมดเป็น UTC รูปแบบ ISO-8601 (`YYYY-MM-DDTHH:MM:SSZ`)

---

## Reject loop (optional) — สำหรับ gate agent

โดยปกติสายพานเดินหน้าทางเดียว แต่ถ้าต้องการ **QC แบบมี loop** (เด้งงานกลับไปแก้ที่ขั้นก่อน)
ใช้กลไกนี้ (ตัวอย่างแม่แบบที่ [agents/_blueprint-gate/](../agents/_blueprint-gate/)):

- gate agent ที่ตรวจแล้ว **ไม่ผ่าน** ให้ตั้ง `status: "rejected"` + `reject_to: "<stage ปลายทาง>"`
  (เช่น `"02-refine"`) แล้วต่อ `history`/`issues` ตามปกติ — **ยังเขียนแค่ output ของตัวเอง ไม่แก้ของใคร**
- orchestrator เห็น `status:"rejected"` + `reject_to` → **กระโดดกลับ** ไปรัน stage นั้นใหม่,
  เพิ่ม `attempts` ขึ้น 1
- มี **เพดาน** `MAX_RETRIES` (default 2) กันวนไม่จบ — ครบเพดานแล้ว orchestrator หยุดและรายงาน
- ขั้นที่ถูกตีกลับ อ่าน `issues` เพื่อรู้ว่าต้องแก้อะไร แล้วผลิตใหม่ตามกติกาเดิม (history ต่อเนื่อง ไม่ลบของเก่า)
