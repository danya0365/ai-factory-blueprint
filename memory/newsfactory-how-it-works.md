---
name: newsfactory-how-it-works
description: "How the NewsFactory project (/Users/marosdeeuma/NewsFactory) works — an 18-stage AI content pipeline; reference so we don't rescan the whole folder each session"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 131fe7d0-4534-4b24-be16-4c35f88c56d6
---

**NewsFactory** = โรงงานผลิตข่าวการเงิน/Forex อัตโนมัติ ที่ `/Users/marosdeeuma/NewsFactory` (โปรเจกต์แยก คนละ repo กับ ai-factory-blueprint). รับ market data ดิบ → ปั่นเป็นบทความหลายภาษา ตรวจ fact + ไฮไลต์ + รูปปก → publish ขึ้น API. โครงสร้างเดียวกับสายพานเรา (input/→output/ ต่อกันทีละ stage) แต่ใหญ่กว่ามาก: **18 stage** เทียบกับเรา 5.

## สายพาน 18 ขั้น
01 collect_data (เก็บข่าว) → 02 bannarak (แยกหมวด) → 03 choose_topic → 04 editor_check_topic (gate, reject loop กลับ 03) → 05 deep_research → 06 fact_checker → 07 seo_keyword → 08 angle_planing → 09 angle_check → 10 choose_writer → 11 writer_team (20 นักเขียน W01–W20) → 12 editor_check_content → 13 highlight → 14 translator (แปล 20 ภาษา) → 15 transtale_check → 16 image_check → 17 publish_prepare → 18 api_post → 📤 REST POST ไป api-seed-news

## โครงสร้าง/รูปแบบ
- ทุก stage: `NN_factory/input/job-<id>/` และ `output/job-<id>/` — handoff แบบ **copy-only** (ก๊อปต่อ ไม่ลบของเดิม) เหมือนกติกาเหล็กเรา
- แต่ละ stage มี `CLAUDE.md` เป็นบทคำสั่งงาน (เหมือนเรา)
- job id รูปแบบ `job-yyyymmddhhmmss`
- output สุดท้ายไป `output/job-<id>/` ที่ root: `article-draft.md` + `hero.png` + `publish-result.json`

## Agents / orchestration
- **agent มีตัวตน/ชื่อจริงทุกตัว** เก็บใน `/Agents/NN_<name>_<thai>/` พร้อม `persona.md` + `role.md` + `rule.md` + `memory.md`. ชื่อเช่น บัวลอย(01), มะม่วง(02), วัลฮัลลา(03), โมริ(04), TFA(05), Alabiz(10)
- **orchestrator = Wapol (วาโป)** — ตำแหน่งเดียวกับ Foreman ของเรา (คุมไลน์ ไม่ลงไปทำงานเอง) แต่ใช้ **PowerShell** `_tools/wapol-run.ps1` (Action: New / Status / Handoff / TransitionNote) ส่วนเราใช้ bash `run_pipeline.sh`
- factory map: `_tools/wapol-factories.json`; performance baseline + interrupt policy (soft 1.25x / hard 1.5x token/เวลา): `_tools/wapol-run-baseline.json` + `Agents/00_Wapol/WAPOL_RUNBOOK.md`
- stage ใช้ Claude Code CLI หลายโมเดล (Opus/Sonnet/Haiku) บางขั้นใช้ Python (06 FastAPI fact-checker ที่ localhost:8010, 18 publish.py) และ Node.js (16 image gen ผ่าน OpenAI DALL-E + Sharp)

## เทียบกับ ai-factory-blueprint (เรา) — ดูคู่กับ [[newsfactory-vs-our-blueprint]] ถ้ามี
- มันไปไกลกว่า: persona ครบทุก agent, baseline/interrupt tracking, multi-language, 18 stage
- เรามีที่มันไม่มี: **git version control** (มันไม่ใช่ repo เลย), **data contract กลาง** `envelope.md` เดียวร้อยทั้งสาย (มันใช้ contract เฉพาะแต่ละ stage แยกกัน), **orchestrator รันรวดเดียวจบ** `run_pipeline.sh` (มันสั่ง handoff ทีละขั้นด้วยมือ)

## สถานะ (ตอนสำรวจ 2026-06-24)
ทำงานได้จริง — job ล่าสุด `job-20260610081907` (บทความ "Brent $105 Is a Forecast, Not Spot") ไหลครบ 18 stage, publish สำเร็จ articleId:4 status:draft. ยังไม่เป็น git repo, ยังไม่มี central DB/logging, stage 02/07/09/15/17 doc ยังน้อย, 14 translator กำลัง migrate เป็น `14New/`.
