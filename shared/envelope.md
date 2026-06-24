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
| `status` | `"ok"` \| `"error"` | สถานะของงาน ณ ขั้นนี้ ถ้า `error` ปลายทางควรหยุด/ข้าม |
| `data` | object | เนื้อหาหลัก แต่ละขั้นปรับปรุง/ต่อยอด `data` ของขั้นก่อน |
| `issues` | array | ปัญหา/คำเตือนที่พบ (ใช้มากในขั้น validate) แต่ละ entry เช่น `{ "field": "...", "level": "warn\|error", "message": "..." }` |
| `history` | array | ประวัติทุกขั้นที่ผ่านมา — **ต่อท้ายเท่านั้น ห้ามลบของเดิม** |

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
