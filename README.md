# TPlus Plugins

Kho mã nguồn để tiếp tục phát triển plugin trên nhiều máy.

- `TPlus_Dim/`: mã nguồn, font, công cụ phát triển và gói T+ Dim.
- `TPlus_Cabinet_Codex_Handoff_2026-10-01/`: mã nguồn, tài liệu bàn giao, công cụ phát triển và gói T+ Cabinet. Đọc `AGENTS.md` và `CODEX_HANDOFF.md` trước khi sửa.

## Mở trên máy khác

Clone lần đầu:

```powershell
git clone https://github.com/vuongpentax/TPlus_Plugins.git
cd TPlus_Plugins
```

Mở thư mục `TPlus_Plugins` làm dự án trong Codex. Mã nguồn và gói RBZ được lưu trong repository; việc cài plugin vào SketchUp phải thực hiện riêng trên từng máy theo hướng dẫn của mỗi plugin.

Trước khi bắt đầu làm, nếu thư mục làm việc sạch:

```powershell
git pull --ff-only
```

Sau khi làm xong, kiểm tra file thay đổi rồi lưu và gửi lên GitHub:

```powershell
git status
git add .
git commit -m "Cap nhat plugin"
git push
```

Chỉ chuyển máy sau khi push thành công. Nếu Git báo xung đột hoặc có thay đổi chưa lưu, xử lý các thay đổi đó trước khi pull.

## Công cụ phát triển

Cache, `node_modules`, thư viện Python tại `TPlus_Dim/dev/vendor`, log và bản sao lưu cài đặt tạm không được lưu trong Git. Các công cụ Node cần cài dependency theo `cabinet_dev/package.json` và lockfile của dự án Cabinet.

Runtime T+ Dim không cần các thư viện Python này. Khi cần chạy lại `dev/build_fonts.py`, cài fontTools và Shapely 2.1 vào `TPlus_Dim/dev/vendor` theo tài liệu trong `TPlus_Dim/README.md`.
