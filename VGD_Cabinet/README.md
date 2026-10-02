# VGD_Cabinet · 4.4.0-beta.1

VGD_Cabinet thay tên T+ Cabinet trong hệ sinh thái VGD.

- Preset lưu ở dữ liệu người dùng, ngoài thư mục Plugins; có backup và ghi qua file tạm. Tạo mới, Cập nhật mẫu đã chọn và Đổi tên là ba lệnh riêng. Tên trùng bị chặn, không đè mẫu khác.
- Lần mở đầu đọc mẫu T+ cũ từ Preferences; không ghi lại Preferences T+. Các mẫu đã có giữ thông số của chúng, mặc định mới áp cho tủ mới/mẫu mặc định mới.
- Nẹp trần mặc định 20 mm. Khe cánh đơn giản/chi tiết và biên mặt hộc 0 mm. Khe giữa tầng hộc và hai tầng tủ 25 mm.
- Móc tay cánh và mặt hộc độc lập; xà chặn cánh ở Cánh tủ, xà đón/xà che khe hộc ở Ngăn kéo.
- Cánh Pano khung gỗ: bản đố, bản thanh ngang, dày khung, dày pano, sâu rãnh, khe co giãn, số ô và bản thanh chia giữa. Khung và tấm giữa dùng vật liệu riêng. Có rãnh ngậm thật, chưa dựng mộng góc/profile soi trang trí.

## Cài máy nhà

Gói mới nằm trong outputs/vgd_cabinet_modeling. Chạy cabinet_dev/sync_sketchup_2022.ps1 để cài đúng 17 file, sao lưu và tắt loader T+ cũ; không sửa plugin khác. Dữ liệu preset không bị bộ cài ghi đè.

**Khởi động lại SketchUp 2022 sau khi đổi thương hiệu**, vì module/menu/bộ nạp khác tên. Sau đó dùng Extensions → VGD Cabinet — Tiện ích → VGD — Nạp lại mã cho các lần sửa tiếp. Không tự đóng model đang làm.

Tủ T+ cũ vẫn được nhận diện qua dictionary TPlus_Cabinet và có thể cập nhật bằng VGD. Tủ mới dùng tag VGD_CABINET / VGD_CANH / VGD_KY HIEU.

## Preset

Chọn mẫu để nạp. Nhập tên rồi Tạo mới để lưu cấu hình hiện tại thành mẫu khác. Cập nhật mẫu đã chọn chỉ đổi cấu hình của đúng mẫu. Đổi tên lấy tên mới trong ô nhập, giữ cấu hình đã lưu; nếu tên trùng mẫu khác thao tác dừng.

File dữ liệu: %APPDATA%/VGD/SketchUp/VGD_Cabinet/presets_v1.json, kèm .bak. Khi file chính hỏng có thể đọc bản backup gần nhất; lỗi ghi không báo lưu thành công. Thư viện này thuộc máy đang dùng; mang file dữ liệu sang máy khác nếu cần dùng chung mẫu.

## Pano

Mặc định thiết kế: bản khung 60, dày 20, pano phẳng 6, ngậm 8, khe co giãn 1 mm mỗi cạnh, một ô. Đây là điểm bắt đầu chỉnh sửa, không phải tiêu chuẩn bắt buộc cho mọi vật liệu.

Kích thước tấm pano = ô lọt lòng + 2 × (sâu rãnh − khe co giãn). Số ô chia đều theo chiều cao, trừ bản thanh chia giữa. Với gỗ tự nhiên cần chỉnh khe theo loài gỗ và độ ẩm; với MDF/plywood chỉnh theo thiết kế.

## Kiểm thử

Node + Ruby WASM, JSDOM, Playwright/Edge và bộ cài PowerShell có kiểm tra tự động. File preset được ghi/đọc trên filesystem Windows qua WASI và được mở lại bởi Ruby VM mới; riêng flock bị mô phỏng do WASI không hỗ trợ. Chưa xác nhận trực tiếp native SketchUp: hình học solid/manifold, Undo, thao tác preset sau restart SketchUp hoặc lưu/mở SKP.

Xem VALIDATION.json và PANO_RESEARCH.md. Dependencies: pnpm install --dir cabinet_dev --frozen-lockfile; trong kho có thể dùng dependency cache của handoff T+ cũ. Không đóng gói node_modules, preset người dùng hoặc backup cài đặt.
