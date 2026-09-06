#!/usr/bin/env python3
"""
write_defects.py — Quản lý sheet "Defects & Follow-ups" trong file test case.

Ba chế độ, phục vụ luồng tạo bug có human-in-the-loop:

1) --mode fill      : SAU khi chạy test, với mỗi case Fail/Blocked ở sheet Test
   Cases, APPEND một dòng vào sheet Defects. Điền sẵn TC ID, Section, Title,
   Round, Priority, và Actual Result (agent truyền vào từ log test).

2) --mode read      : SAU khi người dùng review (đánh dấu Fix Status, sửa Actual),
   trả JSON các dòng CẦN TẠO BUG. Kèm Steps/Expected ghép từ sheet Test Cases.

3) --mode writeback : ghi ClickUp ticket ID về file sau khi đã tạo bug.

Ranh giới: script chỉ đọc/ghi ô Excel. Nó KHÔNG chạy test (agent làm, truyền
Actual vào), KHÔNG tạo bug (agent gọi ClickUp), KHÔNG quyết dòng nào bỏ.

────────────────────────────────────────────────────────────────────────────
BA QUY TẮC AN TOÀN (đừng bỏ, mỗi cái từng gây mất dữ liệu thật)

1. LUÔN APPEND, không lấp lỗ trống.
   Dòng mới ghi sau dòng CUỐI CÙNG có TC ID, không phải ô trống đầu tiên. Nếu
   lấp lỗ, một dòng bị xoá ở giữa sẽ khiến lần fill sau đè mất các dòng bên dưới
   (kèm Actual người dùng đã review).

2. KHOÁ THEO TC ID, không theo số dòng.
   writeback nhận {tc_id: ticket_id}. Số dòng lệch ngay khi người dùng chèn/xoá
   một dòng trong Excel giữa read và writeback → Ticket ID gắn nhầm case.

3. KHÔNG dùng "xoá dòng" làm tín hiệu từ chối.
   Muốn nói "case này không tạo bug", người dùng đặt Fix Status = "Won't fix"
   (giá trị đã có sẵn trong dropdown cột K). Xoá dòng không giữ được ý định:
   case vẫn Fail và chưa có Bug ID nên lần fill sau nó quay lại.
────────────────────────────────────────────────────────────────────────────

Map cột sheet Defects:
  A #  · B TC ID · C Section · D Title · E Description · F Round · G Priority
  · H Actual Result/Reason · I Bug ID/Ticket · J Assignee · K Fix Status
Map cột sheet Test Cases:
  A ID · B Section · C Type · D Priority · E Title · F Precond · G Steps
  · H Data · I Expected · J Round1 Result · K Round1 BugID · L Round2 Result
  · M Round2 BugID · N Note
"""
import argparse
import json
import shutil
import sys

import openpyxl

DEF_START = 4        # dòng data Defects bắt đầu (header 1-3)
TC_START = 6         # dòng data Test Cases bắt đầu
FAILED = ("Fail", "Blocked")
MANUAL_MARK = "[MANUAL]"   # Note bắt đầu bằng chuỗi này = case chờ chạy tay, không phải defect


# ---------------------------------------------------------------- đọc
def load_testcases(ws_tc):
    """Trả dict theo TC ID: {id: {...}} từ sheet Test Cases (bỏ divider).

    Nếu gặp TC ID trùng thì báo lỗi và dừng: dict sẽ nuốt mất bản trước, và bản
    bị nuốt có thể chính là dòng đang Fail.
    """
    out = {}
    dupes = []
    for r in range(TC_START, ws_tc.max_row + 1):
        tid = ws_tc.cell(r, 1).value
        if not tid or not str(tid).startswith("TC-"):
            continue                      # bỏ divider / dòng trống
        if tid in out:
            dupes.append((tid, out[tid]["row"], r))
            continue
        out[tid] = {
            "row": r,
            "section": ws_tc.cell(r, 2).value,
            "priority": ws_tc.cell(r, 4).value,
            "title": ws_tc.cell(r, 5).value,
            "steps": ws_tc.cell(r, 7).value,
            "expected": ws_tc.cell(r, 9).value,
            "r1_result": ws_tc.cell(r, 10).value,
            "r1_bug": ws_tc.cell(r, 11).value,
            "r2_result": ws_tc.cell(r, 12).value,
            "r2_bug": ws_tc.cell(r, 13).value,
            "note": ws_tc.cell(r, 14).value or "",
        }
    if dupes:
        msg = "; ".join(f"{t} ở row {a} và {b}" for t, a, b in dupes)
        print(f"LỖI: TC ID trùng trong sheet Test Cases ({msg}). "
              f"Sửa cho duy nhất rồi chạy lại — ID trùng làm bỏ sót case fail.", file=sys.stderr)
        sys.exit(1)
    return out


def latest_round(info):
    """Round mới nhất CÓ kết quả và kết quả đó là gì.

    Trả (round_number, result) hoặc (None, None). Xét round 2 trước round 1: nếu
    round 2 đã Pass thì case đã được fix, KHÔNG tạo defect nữa.
    """
    if info["r2_result"] not in (None, "", "Not Run"):
        return 2, info["r2_result"]
    if info["r1_result"] not in (None, "", "Not Run"):
        return 1, info["r1_result"]
    return None, None


def defect_rows(ws_def):
    """Trả list (row, tc_id) của mọi dòng defect đang có, theo thứ tự."""
    return [(r, ws_def.cell(r, 2).value)
            for r in range(DEF_START, ws_def.max_row + 1)
            if ws_def.cell(r, 2).value]


def next_defect_row(ws_def):
    """Row để APPEND: sau dòng CUỐI CÙNG có TC ID. Không bao giờ lấp lỗ trống."""
    rows = defect_rows(ws_def)
    return (rows[-1][0] + 1) if rows else DEF_START


def find_defect_row(ws_def, tc_id):
    for r, tid in defect_rows(ws_def):
        if tid == tc_id:
            return r
    return None


# ---------------------------------------------------------------- fill
def mode_fill(wb, actuals):
    """actuals: dict {TC_ID: actual_text} do agent truyền (kết quả thật khi fail)."""
    ws_tc = wb["Test Cases"]
    ws_def = wb["Defects & Follow-ups"]
    tcs = load_testcases(ws_tc)

    existing = {tid for _, tid in defect_rows(ws_def)}
    r = next_defect_row(ws_def)
    seq = len(existing) + 1

    added, skipped = [], []
    for tid, info in tcs.items():
        rnd, res = latest_round(info)

        if res not in FAILED:
            continue                                   # chưa chạy, hoặc đã Pass ở round mới nhất
        if str(info["note"]).strip().startswith(MANUAL_MARK):
            skipped.append({"tc_id": tid, "reason": "case chờ chạy tay ([MANUAL]), không phải defect"})
            continue
        if info["r1_bug"] or info["r2_bug"]:
            skipped.append({"tc_id": tid, "reason": "đã có Bug ID ở sheet Test Cases"})
            continue
        if tid in existing:
            skipped.append({"tc_id": tid, "reason": "đã có dòng trong sheet Defects"})
            continue

        ws_def.cell(r, 1, seq)                         # A  #
        ws_def.cell(r, 2, tid)                         # B  TC ID
        ws_def.cell(r, 3, info["section"])             # C  Section
        ws_def.cell(r, 4, info["title"])               # D  Title
        #                                                 E  Description (agent tổng hợp khi tạo bug)
        ws_def.cell(r, 6, f"Round {rnd}")              # F  Round
        ws_def.cell(r, 7, info["priority"])            # G  Priority
        ws_def.cell(r, 8, actuals.get(tid, ""))        # H  Actual Result (agent điền từ log)
        #                                                 I  Bug ID trống = chưa tạo bug
        #                                                 K  Fix Status trống = chưa quyết
        added.append(tid)
        r += 1
        seq += 1
    return added, skipped


# ---------------------------------------------------------------- read
def mode_read(wb):
    """Đọc Defects sau review: trả các dòng CẦN TẠO BUG.

    Bỏ qua: dòng đã có Bug ID, và dòng người dùng đã đánh Fix Status (thường là
    "Won't fix") — đó là cách nói "không tạo bug cho case này".
    """
    ws_tc = wb["Test Cases"]
    ws_def = wb["Defects & Follow-ups"]
    tcs = load_testcases(ws_tc)

    to_create, skipped = [], []
    for r, tid in defect_rows(ws_def):
        if ws_def.cell(r, 9).value:                    # I  Bug ID/Ticket
            skipped.append({"tc_id": tid, "reason": "đã có Bug ID"})
            continue
        fix_status = ws_def.cell(r, 11).value           # K  Fix Status
        if fix_status:
            skipped.append({"tc_id": tid, "reason": f"người dùng đặt Fix Status = '{fix_status}'"})
            continue
        tc = tcs.get(tid, {})
        to_create.append({
            "tc_id": tid,                               # KHOÁ CHÍNH cho writeback
            "defect_row": r,                            # chỉ để tham khảo, đừng khoá theo nó
            "section": ws_def.cell(r, 3).value,
            "title": ws_def.cell(r, 4).value,
            "description": ws_def.cell(r, 5).value or "",
            "round": ws_def.cell(r, 6).value,
            "priority": ws_def.cell(r, 7).value,
            "actual": ws_def.cell(r, 8).value or "",
            "steps": tc.get("steps", ""),               # Steps to reproduce <- Test Steps
            "expected": tc.get("expected", ""),         # Expected <- Expected Result
        })
    return to_create, skipped


# ---------------------------------------------------------------- writeback
def mode_writeback(wb, mapping):
    """Ghi ClickUp ticket ID (TLM-xxxx) về file. mapping: {tc_id: ticket_id}.

    Khoá theo TC ID chứ KHÔNG theo số dòng: chỉ cần người dùng chèn/xoá một dòng
    giữa read và writeback là index dòng lệch và Ticket ID gắn nhầm case.
    """
    ws_def = wb["Defects & Follow-ups"]
    ws_tc = wb["Test Cases"]
    tcs = load_testcases(ws_tc)

    written, failed = [], []
    for tc_id, ticket in mapping.items():
        r = find_defect_row(ws_def, tc_id)
        if r is None:
            failed.append({"tc_id": tc_id, "reason": "không tìm thấy dòng defect cho TC ID này"})
            continue
        ws_def.cell(r, 9).value = ticket                # I  Bug ID/Ticket

        info = tcs.get(tc_id)
        tc_col = None
        if info:
            rr = info["row"]
            rnd, res = latest_round(info)
            if res in FAILED:
                tc_col = 13 if rnd == 2 else 11         # M round2 / K round1
                ws_tc.cell(rr, tc_col).value = ticket
        written.append({"tc_id": tc_id, "defect_row": r, "ticket": ticket,
                        "test_cases_col": tc_col})
    return written, failed


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    ap.add_argument("--mode", required=True, choices=["fill", "read", "writeback"])
    ap.add_argument("--actuals", default="{}", help='JSON {TC_ID: actual_text} cho mode fill')
    ap.add_argument("--bugmap", default="{}", help='JSON {TC_ID: ticket_id} cho mode writeback')
    ap.add_argument("--no-backup", action="store_true",
                    help="Bỏ qua backup .bak (KHÔNG khuyến khích)")
    args = ap.parse_args()

    writes = args.mode in ("fill", "writeback")
    if writes and not args.no_backup:
        shutil.copy2(args.file, args.file + ".bak")

    wb = openpyxl.load_workbook(args.file)

    if args.mode == "fill":
        added, skipped = mode_fill(wb, json.loads(args.actuals))
        wb.save(args.file)
        result = {
            "mode": "fill", "defect_rows_added": added, "skipped": skipped,
            "note": ("Actual đã điền từ log. Người dùng review sheet Defects: sửa Actual nếu sai, "
                     "và đặt Fix Status = \"Won't fix\" cho case KHÔNG muốn tạo bug "
                     "(đừng xoá dòng — xoá dòng không giữ được ý định)."),
            "backup": None if args.no_backup else args.file + ".bak",
            "reminder": "openpyxl xoá cache công thức khi save — chạy recalc.py để Summary hiện số lại.",
        }
    elif args.mode == "read":
        rows, skipped = mode_read(wb)
        result = {
            "mode": "read", "bugs_to_create": rows, "skipped": skipped,
            "note": ("Mỗi phần tử là 1 bug cần tạo trên ClickUp. Sau khi tạo, gọi "
                     "--mode writeback --bugmap '{\"TC-A-001\": \"TLM-1234\"}' (khoá theo TC ID)."),
        }
    else:
        written, failed = mode_writeback(wb, json.loads(args.bugmap))
        wb.save(args.file)
        result = {
            "mode": "writeback", "written": written, "failed": failed,
            "note": ("Đã ghi ticket ID vào cột Bug ID/Ticket (Defects) và cạnh Result của round "
                     "fail (Test Cases). Retest sẽ bỏ qua các case này."),
            "backup": None if args.no_backup else args.file + ".bak",
            "reminder": "Chạy recalc.py để Summary tính lại.",
        }

    print(json.dumps(result, ensure_ascii=False, indent=2))
    if result.get("failed"):
        sys.exit(2)


if __name__ == "__main__":
    main()
