# Validation — 2026-10-03

## Đã pass

- Compile tất cả Ruby runtime/dev sources bằng Ruby WASM 3.2. Runtime viết theo cú pháp Ruby 2.7 để target SketchUp 2022.
- Core simulation: schema/enum/boolean, default fields, partial updates, clear, required fields, unit-method mismatch, UNCLASSIFIED, source priority, JSON rules, Vietnamese keywords, native data preservation, entity deduplication, one-operation batch và abort khi write lỗi.
- Geometry/scanner simulation: nested transform kết hợp mirror/rotation/nonuniform scale, transformed face area/edge length, raw reports đếm physical occurrences, unique entity API, 2.000 cấp lồng nhau và recursive definition guard.
- Playwright + Microsoft Edge headless: multi-edit chỉ ghi field enabled, preset không đổi description ngoài ý muốn, entity name không inject HTML, preview/cancel/confirm, validation row gửi đúng target index, invalid JSON rules, selection trống, dark/light, compact layout không overflow. Đã kiểm tra ảnh panel light.
- Deploy vào fixture Plugins: 24 files byte/hash match. Deploy thật vào SketchUp 2022 Plugins: 24 files hash match, có INSTALL_REPORT và backup trong `outputs/install_*`.
- RBZ archive kiểm tra CRC và đối chiếu từng byte với runtime. SHA256 trong `PACKAGE_SHA256.json`.

## Chưa được xác nhận trên SketchUp kernel

Đã khởi chạy một tiến trình SketchUp 2022 riêng bằng `-RubyStartup dev/native_smoke.rb`, nhưng phiên kiểm tra chưa sinh `native_report.json`. Windows Computer Use helper không đọc được cửa sổ: `foreground window did not report a process id`, sau đó `FrameArrived timed out: timed out waiting on channel`. Vì vậy **không coi native smoke test đã pass**.

Các phần còn cần chạy test thực tế: load extension/menu/toolbar/HtmlDialog; native scaled/nested geometry; Undo thật; click validation chọn nested occurrence; save/reopen metadata; dirty model thật. Cài nguồn đã được xác minh; cần khởi động lại SketchUp để nạp bản mới.

Để kiểm chứng, chạy `dev/native_smoke.rb` trong một SketchUp process mới với model trống. Script sẽ tạo fixture gồm wardrobe, 10 sockets, 6 lights, lavabo cabinet, raw wall, unclassified/empty group, shared nested và scaled component; kiểm tra metadata/Undo/reopen và ghi báo cáo. Không chạy trên file đang làm.

Đây là v0.1-alpha để review kiến trúc/schema và kiểm tra SKP thực tế; chưa xác nhận đạt toàn bộ completion criteria của bản đặc tả.
