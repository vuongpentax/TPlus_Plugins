# VGD_Cabinet · 4.4.0-beta.2.1

VGD_Cabinet thay tên T+ Cabinet trong hệ sinh thái VGD.

## Beta 2 · Dựng từ mô tả

Mở **Dựng từ mô tả → Hướng dẫn cho ChatGPT**, copy hướng dẫn và gửi cùng ảnh + rộng/sâu/cao mong muốn. ChatGPT trả về khối JSON; dán vào plugin, bấm **Kiểm tra → Áp dụng cho tủ mới → Đặt tủ mới**. Có **Nạp ví dụ** để thử không cần ảnh/API key.

Plugin đọc cấu hình, không tự phân tích ảnh hoặc hiểu văn xuôi. Bắt buộc đơn vị mm và đủ w/d/h; kiểm tra kiểu dữ liệu, tên thông số, lựa chọn và giới hạn hình học. Xem trước hiện kích thước/module, giả định, trường ước lượng, các giá trị mặc định và toàn bộ cấu hình. Không suy đoán số đo thật từ ảnh.

Áp dụng tạo bản nháp riêng, tắt live update, không tự dựng/sửa model/lưu preset. Thay đổi vùng chọn không ghi đè bản nháp. Muốn sửa tủ cũ: Dựng từ mô tả → Trở lại tủ đang chọn. Đặt thành công thì bảng trở lại theo tủ vừa dựng. Reload/đóng bảng sẽ bỏ bản nháp chưa đặt; thư viện mẫu đã lưu không bị ảnh hưởng.

Beta 2 chỉ nhập những cấu tạo bộ dựng hiện hỗ trợ. Các module có thể khác rộng nhưng dùng chung cánh/đợt/hộc. Số cánh/vách hoặc tầng đã khai báo tắt tự động tương ứng nếu cấu hình không chủ động bật. Móc tay mới luôn độc lập, không áp quy tắc migrate mẫu T+ cũ.

Hotfix beta 2.1: khi `unsupported_features` không rỗng, áp dụng đầy đủ vẫn bị khóa nhưng có **Dựng phần được hỗ trợ**. Hộp xác nhận liệt kê toàn bộ phần bỏ qua, kích thước và số khoang/cánh. Phải đồng ý rõ ràng mới nạp bản nháp; hủy không thay đổi bảng/model. Backend kiểm tra lại JSON và đúng danh sách xác nhận. Sai đơn vị/kích thước/kiểu dữ liệu/tên tham số vẫn bị chặn, kể cả ở chế độ cơ bản.

Chiều rộng/sâu/cao giữ nguyên cho tủ cơ bản; không tự trừ phần kệ trái hay chừa chi tiết chưa hỗ trợ. Ví dụ JSON 2200 × 600 × 2700 dùng nguyên rộng 2200; `h_top` từ 560 được tính lại thành 580 theo nẹp mặc định 20 và tầng dưới 2100. Muốn chừa kệ, sửa rộng tủ cơ bản và kiểm tra lại trước khi đặt. Bản nháp có cảnh báo rõ đang bỏ qua chi tiết, không phải bản dựng đầy đủ từ ảnh.

- Preset lưu ở dữ liệu người dùng, ngoài thư mục Plugins; có backup và ghi qua file tạm. Tạo mới, Cập nhật mẫu đã chọn và Đổi tên là ba lệnh riêng. Tên trùng bị chặn, không đè mẫu khác.
- Lần mở đầu đọc mẫu T+ cũ từ Preferences; không ghi lại Preferences T+. Các mẫu đã có giữ thông số của chúng, mặc định mới áp cho tủ mới/mẫu mặc định mới.
- Nẹp trần mặc định 20 mm. Khe cánh đơn giản/chi tiết và biên mặt hộc 0 mm. Khe giữa tầng hộc và hai tầng tủ 25 mm.
- Móc tay cánh và mặt hộc độc lập; xà chặn cánh ở Cánh tủ, xà đón/xà che khe hộc ở Ngăn kéo.
- Cánh Pano khung gỗ: bản đố, bản thanh ngang, dày khung, dày pano, sâu rãnh, khe co giãn, số ô và bản thanh chia giữa. Khung và tấm giữa dùng vật liệu riêng. Có rãnh ngậm thật, chưa dựng mộng góc/profile soi trang trí.

## Cài máy nhà

Gói mới nằm trong outputs/vgd_cabinet_modeling. Chạy cabinet_dev/sync_sketchup_2022.ps1 để cài đúng 18 file, sao lưu và tắt loader T+ cũ; không sửa plugin khác. Dữ liệu preset không bị bộ cài ghi đè.

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
