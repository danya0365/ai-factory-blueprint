# memory/ — คลังความจำของ Foreman (เก็บใน git, เดินทางข้ามเครื่องได้)

โฟลเดอร์นี้คือ **auto-memory** ของ Claude Code สำหรับโปรเจกต์นี้
ปกติ Claude Code เก็บ memory ไว้ที่ `~/.claude/projects/<hash>/memory/` (machine-local → ย้ายเครื่องแล้วหาย)
เราย้ายมาไว้ใน repo ตรงนี้แทน เพื่อให้ **commit เข้า git แล้ว clone ไปเครื่องไหนก็ตามไปด้วย**

- `MEMORY.md` — index ที่โหลดทุก session (1 บรรทัดต่อ 1 memory)
- `*.md` ไฟล์อื่น — memory แยกเรื่องละไฟล์ โหลดเมื่อเกี่ยวข้อง

## ⚠️ ตั้งค่าครั้งเดียวบนเครื่องใหม่ (สำคัญ)

ตัว setting ที่ชี้ memory มาที่นี่ **เดินทางผ่าน git ไม่ได้** (กฎ workspace-trust ของ Claude Code:
project `.claude/settings.json`/`settings.local.json` ที่มาจาก clone ต้องผ่าน trust ก่อน
ถึงจะ honored — และ `autoMemoryDirectory` รองรับเฉพาะ absolute path หรือ `~/`)

ดังนั้นพอ clone ไปเครื่องใหม่ ให้รัน script นี้ **ครั้งเดียว** (มันคำนวณ path ของ repo เองให้):

```bash
./scripts/setup-claude-memory.sh
```

script จะสร้าง `.claude/settings.local.json` (gitignored) ด้วย absolute path ของ repo บนเครื่องนั้น
ทำครั้งเดียวจบ — หลังจากนั้น Claude Code จะอ่าน/เขียน memory ที่โฟลเดอร์นี้ และเนื้อหา memory
จะ sync ผ่าน git ตามปกติ (ตัว path เครื่องอยู่ใน settings.local.json ที่ไม่ถูก commit → ไม่มี path
เฉพาะเครื่องหลุดลง git)
