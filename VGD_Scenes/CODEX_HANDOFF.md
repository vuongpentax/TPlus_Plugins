# Bàn giao VGD Scenes

## Yêu cầu người dùng

Thương hiệu chính **VGD**; giao diện theo theme T+ (nâu/trắng/than, sáng/tối). Ưu tiên tạo scene đối tượng nhanh theo view cơ bản; mặt cắt tùy chỉnh; quản lý/đặt tên/xóa/update/chọn scene xuất; PNG/JPG theo scene vào folder hoặc một PDF nhiều trang; PNG nền trong suốt; frame/grid hỗ trợ camera. Mục tiêu SketchUp 2022. Nghiêm cấm ảnh hưởng plugin khác.

## Bản hiện tại

Runtime 1.0.0 độc lập `VGD::Scenes`, loader `vgd_scenes.rb`, thư mục `vgd_scenes/`. Không dùng namespace TPlus, không monkey patch, không observers, không tự hiện toolbar, không phụ thuộc Node/Python hoặc Internet.

- `utils.rb`: kiểm tra thông số, operation/Undo, filename, ViewState để phục hồi view.
- `geometry.rb`: persistent paths, transform tích lũy/local axes, fit camera, vị trí/vector mặt cắt.
- `scenes.rb`: ID scene, metadata riêng, update không trùng, override cô lập theo scene, section lưu trước page.update; rename/capture/delete.
- `frame.rb`: Tool draw2d cho SU22, khung tỷ lệ/lưới; tạm ẩn khi xuất.
- `export.rb`: timer theo scene, write_image, PDF bằng Layout::Document + Layout::Image, kiểm tra kết quả, hủy và phục hồi view.
- `main.rb`: menu/toolbar/HtmlDialog/callback; `dialog.html/css/js`: giao diện, textContent và ID scene.

PDF là raster một ảnh mỗi trang, không phải viewport/vector có tỷ lệ kỹ thuật. PNG trong suốt bỏ nền SketchUp, không xóa hình học sàn/tường. Lệnh update từ nguồn refit lại camera; capture lưu bố cục thủ công. Khi xóa scene mặt cắt, giữ mặt phẳng VGD để không làm hỏng scene khác dùng chung. Không dimension tự động hoặc xuất hồ sơ LayOut kỹ thuật.

## Kiểm tra và việc cần tiếp tục

7 file Ruby đã kiểm tra cú pháp bằng Ruby WASM 3.2, engine qua fixture API; giao diện qua Chromium ở 640×780 và 460×540. Xem `dev/test_engine.rb`, `dev/test_ui.cjs`. `npm install` trong `dev` rồi `npm test`; cần Node 20+ và Chrome. Không xem fixture là bằng chứng engine SketchUp native hoạt động.

**Ưu tiên tiếp theo: kiểm thử thực tế SU22/Ruby 2.7.2 và LayOut API.** Lần thử riêng ghi nhận SU 22.0.316/Ruby 2.7.2 nhưng guard model không rỗng đã dừng trước khi thay đổi; người dùng dừng điều khiển máy bằng Esc. Chưa có bằng chứng native tạo scene/export thành công. `dev/native_smoke.rb` chỉ được chạy ở phiên thử với model rỗng; guard từ chối model có geometry/pages hoặc path, không được bỏ guard để chạy trong bản vẽ đang làm. Có thể template SketchUp có người mẫu nên không rỗng; chuẩn bị model thử sạch bằng thao tác được phép trước khi chạy.

Kiểm tra camera theo đối tượng xoay/lồng/mirror, section đang active khi lưu, PNG alpha, PDF số trang và nội dung thực, restore sau hủy/lỗi, thao tác scene ngoài VGD chỉ khi được chọn. SketchUp 2022 không có Overlay API; dùng Tool. Không dùng SectionPlane.deactivate hoặc Entities.bounds. Cẩn thận Styles.selected_style= đối với active_style trên SU trước 2025.

## Cài và phạm vi bảo vệ

`dev/deploy.ps1` dùng APPDATA hiện tại và allowlist 11 file. Có backup và rollback file VGD, hash trước/sau các file khác. `-RetireLegacy` chỉ tắt đúng loader Scenes T+ có hash đã review, không sửa `tplus/`. Trên máy ban đầu đã cài 11 file, tắt loader cũ bằng đổi đuôi `.rb.vgd-disabled`, đối chiếu 7.713 file khác: 0 thay đổi. Backup/outputs ở máy cài, bỏ qua Git.

RBZ là ZIP của **nội dung runtime/** (loader và thư mục ngang hàng), không bọc thêm thư mục runtime. Khi runtime thay đổi, tạo lại RBZ; bản RBZ đã commit tương ứng runtime 1.0.0 hiện tại.
