# Agent 05 — Seed (ตัวสุดท้าย: แปลงเป็น seed → เรียก API/DB)

คุณคือ **agent ตัวสุดท้าย** ของสายพาน หน้าที่คือ แปลงข้อมูลที่ผ่านการตรวจแล้วเป็น **seed payload**
แล้วเขียนลงฐานข้อมูลผ่าน API

> ตอนนี้การเขียน DB จริงถูก **stub ไว้ก่อน** ด้วยสคริปต์ `seed_db.sh` (เขียนลง mock db + log)
> ค่อยเปลี่ยนเป็น endpoint/DB จริงภายหลัง
>
> อ่านสัญญาข้อมูลกลางที่ `../../shared/envelope.md` ก่อนเสมอ และทำตามกติกาเหล็กทุกข้อ

## Input — อ่านจากไหน
- อ่าน `../04-validate/output/<JOB_ID>.json`
- **อ่านอย่างเดียว — ห้ามแก้ไฟล์นั้น**

## Output — เขียนไปไหน
- เขียน `output/<JOB_ID>.json` ในโฟลเดอร์ของ agent นี้เท่านั้น

## สิ่งที่ต้องทำ
1. คัดลอก envelope จาก upstream มาเป็นฐาน
2. ถ้า upstream `status` = `"error"` → ตัดสินใจตามนโยบาย: seed เฉพาะ record ที่ `valid: true` และบันทึกที่ข้ามไว้ใน `issues`
3. แปลง record ที่ผ่านเป็น **seed payload** (รูปแบบที่ DB ต้องการ) เก็บใน `data.seed`
4. เรียก stub: `./seed_db.sh <JOB_ID>` โดยส่ง seed payload เข้าทาง stdin (JSON)
   - สคริปต์จะเขียนลง mock db (`db/seeded.jsonl`) และคืน response JSON เช่น `{ "ok": true, "written": N, "db": "mock" }`
5. เก็บ response ลง `data.db_result`
6. ต่อ entry ใหม่ใน `history` เช่น `"seeded 2 records to mock db"`
7. ตั้ง `stage`/`produced_by` = `"05-seed"`, อัปเดต `produced_at`, ตั้ง `status` final (`ok`/`error`), คง `job_id` เดิม
8. เขียนลง `output/<JOB_ID>.json` (indent 2)

## การต่อ DB จริงในอนาคต
แก้เฉพาะ `seed_db.sh` ให้ยิง REST API / เขียน DB จริง โดย **คง interface เดิม** (รับ JSON ทาง stdin, คืน response JSON) — ส่วน CLAUDE.md และสายพานไม่ต้องแก้

## เสร็จแล้ว
รายงานสั้นๆ ว่า seed ลง DB ไปกี่ record, ผลลัพธ์ db อะไร แล้วจบงาน
