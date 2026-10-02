# Bàn giao VGD Scenes

## Yêu cầu người dùng

Thương hiệu chính **VGD**; giao diện theo theme T+ (nâu/trắng/than, sáng/tối). Ưu tiên tạo scene đối tượng nhanh theo view cơ bản; mặt cắt tùy chỉnh; quản lý/đặt tên/xóa/update/chọn scene xuất; PNG/JPG theo scene vào folder hoặc một PDF nhiều trang; PNG nền trong suốt; frame/grid hỗ trợ camera. Mục tiêu SketchUp 2022. Nghiêm cấm ảnh hưởng plugin khác.

## Bản hiện tại

Runtime 1.0.4 độc lập `VGD::Scenes`, loader `vgd_scenes.rb`, thư mục `vgd_scenes/`. Không dùng namespace TPlus, không monkey patch, không observers, không tự hiện toolbar, không phụ thuộc Node/Python hoặc Internet.

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

RBZ là ZIP của **nội dung runtime/** (loader và thư mục ngang hàng), không bọc thêm thư mục runtime. Khi runtime thay đổi, tạo lại RBZ; RBZ 1.0.4 tương ứng runtime hiện tại; bản 1.0.0 giữ để tham khảo.

## Thay đổi 1.0.1

- Mặt cắt ở từng leaf Group/Component; world plane được chuyển về local bằng inverse point và transpose normal, đúng với xoay/lồng/mirror/nonuniform scale. Cụm nhiều đối tượng có plane riêng trong từng leaf.
- Make Unique leaf dùng chung trước khi thêm plane. Từ chối đối tượng khóa hoặc nằm trong cha dùng chung; yêu cầu Make Unique cha để không ảnh hưởng bản khác. Không tự Make Unique cha vì có thể đổi persistent IDs của nguồn lồng.
- Plane root của 1.0.0 được giữ để không phá scene cũ; cập nhật scene mặt cắt sẽ tạo plane bên trong và lưu root inactive cho scene đó. Không xóa plane ngoại lai. Snapshot sâu phục hồi active sections của mọi context.
- Camera direction cùng chiều world normal sau flip để nhìn từ phía bỏ vào phần giữ.
- Source update tạo lại tên theo mẫu lưu. Tạo/cập nhật view đổi tên tất cả scene cùng exact paths, gồm SECTION; name_index được lưu cho scene mới. Scene cũ dùng thứ tự trang khi chưa có name_index.
- UI giải thích vector XYZ và source update. Các tên sửa tay bị thay khi source/view update.
- Kiểm thử WASM/fixture gồm plane local, camera hai hướng, shared instance, cụm, rename scene và export restore. Chưa xác minh trên SketchUp native với bản 1.0.1.

## Thay đổi 1.0.2

- Ô nhập tỷ lệ rộng:cao, preset 3:4 và nút ⇄ giữa ô rộng/cao; swap áp dụng ngay vào view hiện tại.
- Geometry.fit_current giữ hướng nhìn, roll và chế độ parallel/perspective. Căn bounding corners theo camera hiện tại và lề; perspective dùng fov_is_height? để xét hai trục; không chuyển về ISO.
- SceneFrame lưu width/height/margin trong attribute frame của từng page. Áp dụng khung/căn lề cập nhật chỉ PAGE_USE_CAMERA và frame ở selected_page trong Undo operation; không capture visibility/section. Lưu view và source update giữ frame riêng.
- Scene cũ chưa có frame: suy từ page.camera.aspect_ratio và kích thước nguồn/batch. Dialog nạp khung khi chuyển scene; không ghi đè draft khi poll cùng scene.
- Export dùng kích thước riêng từng scene và camera đã lưu. PDF đặt mỗi ảnh theo tỷ lệ riêng trên khổ giấy batch; không phải tỷ lệ in kỹ thuật cố định.
- Bỏ VGD_export_report.json vì chỉ thông báo kết quả. Progress/errors vẫn hiển thị trong dialog; thông số frame lưu trong model, không cần sidecar JSON.
- WASM và browser tests qua với current-view fit/perspective, mixed PNG/JPG/PDF frames, swap/input/scene-switch và không xuất JSON. Chưa xác minh native SU22/LayOut với 1.0.2.

## Thay đổi 1.0.3

- Căn lề/fit và swap tỷ lệ là preview; không page.update, không scene frame attribute, không model working_frame write hoặc Undo operation. Chỉ Áp dụng khung lưu camera/frame (Lưu view vẫn là thao tác lưu chủ động).
- toggle_frame chỉ đặt camera.aspect_ratio=0 để trả view native, hoặc preview lại ratio; không sửa page camera/frame. grid chỉ toggle FrameTool, không áp khung, không lưu scene. FrameTool chỉ vẽ lưới, không vẽ viền khung; grid vẫn chạy trên viewport khi frame off. Esc tắt lưới, giữ trạng thái camera/frame.
- UI/state tách frame_active (live camera aspect > 0) và grid_active. Export tiếp tục dùng camera/frame của scene đã lưu, không preview hiện tại.
- quick_views chỉ ISO/TOP/FRONT/RIGHT. quick_views.svg khác icon bảng điều khiển, được thêm vào allowlist deploy (12 file riêng VGD).
- Bản 1.0.3 kiểm thử fixture và browser; chưa kiểm chứng native SU22.

## Thay đổi 1.0.4

- UI ratio_locked: nút khóa tỷ lệ; giữ lockedAspect gốc, cập nhật chiều kia khi nhập kích thước, không tạo scene/preview tự động.
- export_scale chỉ là hệ số batch; không lưu vào SceneFrame width/height. ExportJob preflight kích thước từng page trong initializer trước khi thay camera; mọi kích thước được nhân, làm tròn, giới hạn 1–12000 mỗi chiều/64MP. PDF ảnh sắc nét hơn theo scale nhưng khổ giấy/layout giữ nguyên.
- Main preflight trước hộp chọn nơi lưu. output_directory(root, opts, date=Time.now) tạo root/[YYYY.MM.DD]/PNG|JPG|PDF. PDF giữ savepanel để đặt tên; chuyển file vào thư mục loại và đánh số chống ghi đè.
- date_folder dùng ngày địa phương tại lúc chuẩn bị đường dẫn, không thay đổi giữa các scene. Không có JSON sidecar.
- Các bản cài và WASM/browser tests nằm trong outputs, không đưa lên GitHub. Runtime 1.0.4 gồm 12 file, chưa kiểm chứng native SU22/LayOut.
