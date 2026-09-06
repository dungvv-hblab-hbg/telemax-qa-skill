#!/usr/bin/env python3
"""
recalc.py — Tính lại công thức trong file .xlsx sau khi openpyxl ghi.

Vì sao cần: openpyxl XOÁ giá trị cache của công thức khi save. File vẫn mở được,
nhưng mọi ô Summary (COUNTA/COUNTIF) sẽ trống cho tới khi có thứ gì đó tính lại.
Script này mở file bằng LibreOffice headless và ghi lại — LibreOffice buộc phải
tính công thức vì không còn cache để đọc.

Chạy sau MỌI lần build.py hoặc write_defects.py ghi file.

Cách dùng:
    python recalc.py <file.xlsx> [timeout_giây]

Exit code:
    0 = tính lại xong
    1 = không tính lại được (thiếu LibreOffice, timeout, file lỗi)
        -> file GỐC không bị đụng tới; mở bằng Excel một lần cũng có tác dụng
           tương đương.
"""
import os
import shutil
import subprocess
import sys
import tempfile

# LibreOffice khởi động nguội mất ~10–20s; 60s đủ cho file test case vài trăm dòng.
DEFAULT_TIMEOUT = 60

# Thứ tự dò: tên lệnh phổ biến trên Linux/macOS/Windows-WSL.
SOFFICE_CANDIDATES = (
    "soffice",
    "libreoffice",
    "/Applications/LibreOffice.app/Contents/MacOS/soffice",
    "/usr/bin/soffice",
)


def find_soffice():
    """Trả về đường dẫn LibreOffice, hoặc None nếu không có."""
    for name in SOFFICE_CANDIDATES:
        path = shutil.which(name) if os.sep not in name else (name if os.path.exists(name) else None)
        if path:
            return path
    return None


def fail(msg):
    print(f"RECALC FAILED: {msg}", file=sys.stderr)
    print(
        "File gốc KHÔNG bị thay đổi. Cách thay thế: mở file bằng Excel hoặc "
        "LibreOffice một lần rồi lưu lại — Summary sẽ tự tính.",
        file=sys.stderr,
    )
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        fail("thiếu tham số. Cách dùng: python recalc.py <file.xlsx> [timeout]")

    target = os.path.abspath(sys.argv[1])
    timeout = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_TIMEOUT

    if not os.path.exists(target):
        fail(f"không thấy file {target}")
    if not target.lower().endswith((".xlsx", ".xlsm")):
        fail(f"chỉ nhận .xlsx/.xlsm, nhận được {target}")

    soffice = find_soffice()
    if not soffice:
        fail(
            "không tìm thấy LibreOffice (soffice). Cài đặt: "
            "Ubuntu `sudo apt install libreoffice-calc` · macOS `brew install --cask libreoffice`"
        )

    with tempfile.TemporaryDirectory() as tmp:
        # -env:UserInstallation tách profile riêng -> chạy được cả khi người dùng
        # đang mở LibreOffice bằng giao diện.
        profile = os.path.join(tmp, "profile")
        cmd = [
            soffice,
            f"-env:UserInstallation=file://{profile}",
            "--headless",
            "--norestore",
            "--convert-to",
            "xlsx:Calc MS Excel 2007 XML",
            "--outdir",
            tmp,
            target,
        ]
        try:
            proc = subprocess.run(cmd, capture_output=True, timeout=timeout, text=True)
        except subprocess.TimeoutExpired:
            fail(f"LibreOffice không xong trong {timeout}s. Thử tăng timeout.")
        except OSError as e:
            fail(f"không chạy được LibreOffice: {e}")

        produced = os.path.join(tmp, os.path.basename(target))
        if not os.path.exists(produced):
            detail = (proc.stderr or proc.stdout or "").strip()[:400]
            fail(f"LibreOffice không sinh ra file. Chi tiết: {detail or 'không có output'}")

        # Chỉ ghi đè khi đã chắc chắn có file hợp lệ -> lỗi giữa chừng không mất bản gốc.
        shutil.copyfile(produced, target)

    print(f"OK: đã tính lại công thức trong {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
