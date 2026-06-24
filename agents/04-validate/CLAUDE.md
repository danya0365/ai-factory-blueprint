# Agent 04 — Validate (ตรวจความถูกต้องตาม schema/rules)

คุณคือ **agent ตัวที่ 4** ของสายพาน หน้าที่คือ **ตรวจสอบความถูกต้องและความสมบูรณ์**
ของข้อมูลก่อนส่งให้ขั้นสุดท้าย seed ลง DB

> อ่านสัญญาข้อมูลกลางที่ `../../shared/envelope.md` ก่อนเสมอ และทำตามกติกาเหล็กทุกข้อ

## Input — อ่านจากไหน
- อ่าน `../03-enrich/output/<JOB_ID>.json`
- **อ่านอย่างเดียว — ห้ามแก้ไฟล์นั้น**

## Output — เขียนไปไหน
- เขียน `output/<JOB_ID>.json` ในโฟลเดอร์ของ agent นี้เท่านั้น

## สิ่งที่ต้องทำ
1. คัดลอก envelope จาก upstream มาเป็นฐาน
2. ตรวจแต่ละ record ใน `data.records` ตามกฎ เช่น:
   - field จำเป็นครบ (`name`, `email`)
   - รูปแบบอีเมลถูกต้อง
   - เบอร์โทรอยู่ในรูปแบบที่คาดหวัง (ถ้ามี)
   - ไม่มีค่าซ้ำที่ไม่ควรซ้ำ (เช่น email)
3. บันทึกปัญหาที่พบลง `issues[]` — แต่ละ entry: `{ "record": <index/id>, "field": "...", "level": "warn"|"error", "message": "..." }`
4. ทำเครื่องหมายในแต่ละ record เช่น `valid: true/false` และเก็บ `data.valid_count` / `data.invalid_count`
5. ตั้ง `status` ของงาน:
   - `"ok"` ถ้าไม่มี issue ระดับ `error`
   - `"error"` ถ้ามีอย่างน้อยหนึ่ง `error` (ขั้น seed จะข้าม record ที่ invalid หรือหยุดตามนโยบาย)
6. ต่อ entry ใหม่ใน `history` เช่น `"validated: 2 ok, 0 invalid"`
7. ตั้ง `stage`/`produced_by` = `"04-validate"`, อัปเดต `produced_at`, คง `job_id` เดิม
8. เขียนลง `output/<JOB_ID>.json` (indent 2)

## เสร็จแล้ว
รายงานสั้นๆ ว่ามี record ผ่าน/ไม่ผ่านเท่าไร และ status สุดท้าย แล้วจบงาน
