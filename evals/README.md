# Evals — Telemax QA Harness

Hướng dẫn test đầy đủ (4 tầng, phép thử phá hoại, bảng chẩn đoán lỗi):
xem [../docs/TESTING.md](../docs/TESTING.md).

Tầng 0 chạy được ngay, không cần MCP:

```bash
bash .claude/scripts/smoke-scripts.sh
```


Ba kịch bản đo xem harness có làm đúng thứ nó hứa không. Chưa có runner tự động;
chạy tay: mở một session Claude Code sạch trong repo, chạy `query`, rồi đối chiếu
từng dòng `expected_behavior`.

Cách dùng đúng theo tài liệu skill best practices: **chạy baseline trước** (không
bật skill) để biết Claude tự làm được tới đâu, rồi so với kết quả có skill. Chỗ nào
có skill vẫn hỏng thì đó là chỗ skill cần sửa, không phải chỗ cần thêm chữ.

| File | Đo cái gì | Skill liên quan |
|---|---|---|
| `01-checklist-structure.json` | Checklist có đúng cấu trúc + nhãn nguồn + mục G khi có diff | `checklist-format`, `git-diff-scope` |
| `02-build-traceability.json` | build.py chặn đúng, Traceability bắt được AC hở | `testcase-template`, `common-validate` |
| `03-defects-manual-guard.json` | Case `[MANUAL]` không đẻ ra bug rác; `Won't fix` được tôn trọng | `testcase-template`, `clickup-bug-format` |
| `04-input-gate.json` | Thiếu đầu vào thì hỏi/xác nhận, không tự đoán | cả 4 chặng |
| `05-prod-safety.json` | Hàng rào `@prod-safe`: không chạy case ghi dữ liệu lên production | `playwright-export` |

Kịch bản 03 là cái đáng giá nhất: nó test đúng chỗ từng gây bug rác gửi cho dev.

Ghi lại kết quả mỗi lần chạy (model nào, pass/fail từng dòng) vào `results/` để so
qua các phiên bản. Tài liệu khuyến nghị test trên cả Haiku, Sonnet và Opus —
`test-analyst` và `testcase-writer` đang gán `model: opus`, `test-runner` và
`bug-filer` gán `sonnet`, nên tối thiểu phải xanh trên hai model đó.
