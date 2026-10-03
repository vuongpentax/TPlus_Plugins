# Bàn giao VGD Scenes

## Yêu cầu người dùng

Thương hiệu chính **VGD**; giao diện theo theme T+ (nâu/trắng/than, sáng/tối). Ưu tiên tạo scene đối tượng nhanh theo view cơ bản; mặt cắt tùy chỉnh; quản lý/đặt tên/xóa/update/chọn scene xuất; PNG/JPG theo scene vào folder hoặc một PDF nhiều trang; PNG nền trong suốt; frame/grid hỗ trợ camera. Mục tiêu SketchUp 2022. Nghiêm cấm ảnh hưởng plugin khác.

## Bản hiện tại

Runtime 1.1.0 độc lập `VGD::Scenes`, loader `vgd_scenes.rb`, thư mục `vgd_scenes/`. Mục tiêu Windows SU2022–2026.2. Không dùng namespace TPlus, không monkey patch, không observers, không tự hiện toolbar, không phụ thuộc Node/Python hoặc Internet.

- `utils.rb`: kiểm tra thông số, operation/Undo, filename, ViewState để phục hồi view.
- `geometry.rb`: persistent paths, transform tích lũy/local axes, fit camera, vị trí/vector mặt cắt.
- `scenes.rb`: ID scene, metadata riêng, update không trùng, override cô lập theo scene, section lưu trước page.update; rename/capture/delete.
- `frame.rb`: Tool draw2d cho SU22, khung tỷ lệ/lưới; tạm ẩn khi xuất.
- `export.rb`: timer theo scene, write_image, PDF bằng Layout::Document + Layout::Image, kiểm tra kết quả, hủy và phục hồi view.
- `main.rb`: menu/toolbar/HtmlDialog/callback; `dialog.html/css/js`: giao diện, textContent và ID scene.

PDF là raster một ảnh mỗi trang, không phải viewport/vector có tỷ lệ kỹ thuật. PNG trong suốt bỏ nền SketchUp, không xóa hình học sàn/tường. Lệnh update từ nguồn refit lại camera; capture lưu bố cục thủ công. Khi xóa scene mặt cắt, giữ mặt phẳng VGD để không làm hỏng scene khác dùng chung. Không dimension tự động hoặc xuất hồ sơ LayOut kỹ thuật.

## Kiểm tra và việc cần tiếp tục

8 file runtime Ruby đã kiểm tra cú pháp/fixture bằng Ruby WASM 3.2 và DLL Ruby 2.7.2 của SU22 (console process riêng); giao diện Chromium 640×780 và 460×540. Xem `dev/test_engine.rb`, `dev/test_transfer.rb`, `dev/test_ui.cjs`. `npm install` trong `dev` rồi `npm test`; Node20+/Chrome. Có SU22/Python: `python VGD_Scenes/dev/check_ruby27.py` từ root repo. Không xem fixture hoặc chạy DLL là bằng chứng kernel SketchUp native hoạt động.

**Ưu tiên tiếp theo: kiểm thử thực tế SU22/Ruby 2.7.2 và LayOut API.** Lần thử riêng ghi nhận SU 22.0.316/Ruby 2.7.2 nhưng guard model không rỗng đã dừng trước khi thay đổi; người dùng dừng điều khiển máy bằng Esc. Chưa có bằng chứng native tạo scene/export thành công. `dev/native_smoke.rb` chỉ được chạy ở phiên thử với model rỗng; guard từ chối model có geometry/pages hoặc path, không được bỏ guard để chạy trong bản vẽ đang làm. Có thể template SketchUp có người mẫu nên không rỗng; chuẩn bị model thử sạch bằng thao tác được phép trước khi chạy.

Kiểm tra camera theo đối tượng xoay/lồng/mirror, section đang active khi lưu, PNG alpha, PDF số trang và nội dung thực, restore sau hủy/lỗi, thao tác scene ngoài VGD chỉ khi được chọn. SketchUp 2022 không có Overlay API; dùng Tool. Không dùng SectionPlane.deactivate hoặc Entities.bounds. Cẩn thận Styles.selected_style= đối với active_style trên SU trước 2025.

## Cài và phạm vi bảo vệ

`dev/deploy.ps1` mặc định dùng APPDATA/SU22 và allowlist 16 file; bản khác dùng `-PluginRoot` hoặc RBZ. Có backup/rollback file VGD, hash trước/sau file khác. `-RetireLegacy` chỉ tắt đúng loader Scenes T+ có hash review, không sửa `tplus/`. Lượt đầu 1.0.0: 11 file/7.713 file khác không đổi. Lượt 1.0.5: 13 file/7.914 file khác không đổi. Báo cáo cài mới ở outputs/install_*/install_report.json; bỏ qua Git.

RBZ là ZIP của **nội dung runtime/** (loader và thư mục ngang hàng), không bọc thêm thư mục runtime. Khi runtime thay đổi, tạo lại RBZ; RBZ 1.1.0 tương ứng runtime hiện tại; các bản cũ giữ để tham khảo.

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

## Thay đổi 1.0.5

- Thêm nút thứ ba trên toolbar và menu: **Cập nhật view hiện tại**, icon `update_view.svg` (máy ảnh/mũi tên vòng). `capture_current_view` gọi SceneStore.capture theo persistent ID của selected_page trong active_model; không mở bảng. Giữ tên và source metadata, lưu camera/hiển thị/mặt cắt/khung, có Undo. Áp dụng scene VGD hoặc scene native người dùng chủ động chọn.
- Chặn trước operation khi chưa có selected_page hợp lệ, đang edit Group/Component hoặc có export job; lỗi báo messagebox, thành công báo status bar. Không có popup xác nhận cho lượt lưu thành công.
- Allowlist cài tăng lên 13 file; chỉ thêm update_view.svg trong thư mục VGD riêng. Bộ test gọi chính UI::Command.proc: camera phối cảnh/bố cục, chỉ scene được chọn, giữ tên/source, không mở bảng, scene ngoài VGD, missing/invalid/edit/busy/failure guards và abort.
- Kiểm tra cú pháp/fixture WASM đã qua; chưa kiểm thử icon/callback trong SU22 native. Để nạp toolbar mới, khởi động lại SketchUp; không tự đóng model hay tạo lại toolbar trong phiên đang làm.

## Thay đổi 1.1.0 và tương thích SU22–2026.2

- `transfer.rb`: schema JSON VGD.Scenes.Transfer v1, tối đa 1.000 scene/8 MB; vector/finite/FOV/frame/name/ID validation trước mọi thay đổi. Chỉ camera/khung, không export owner/source paths/entity PID/cut geometry/style/Tags. Tọa độ inch/world, A/B cần cùng gốc/hướng; chưa relative-anchor hoặc two-point/Match Photo (center_2d/scale_2d không có setters).
- Scene nguồn có transfer_id ổn định qua rename/Save As; gán lần đầu trong operation, cần lưu SKP để giữ qua reopen. Scene nhập mới có transfer_id riêng và transfer_origin nguồn, nên nhập Tạo mới nhiều lần vẫn xuất được. Match origin/ID trước rồi exact-name; ambiguity và hai nguồn khớp một đích bị từ chối. Update giữ tên/order/source/visibility/cuts đích, đánh camera_custom cho scene owned. Imported badge được tính từ transfer_origin; imported mới không được coi là source-owned.
- Clipboard private APPDATA/VGD/Scenes/scene_clipboard_v1.json để SU22 và nhiều process/bản dùng chung; không dùng UI.get/set_clipboard_data (chỉ có SU2023.1+). File JSON có schema check, atomic replace clipboard; xuất riêng exclusive-create/no overwrite.
- Main có copy/paste/save/load/apply/cancelTransfer; Ruby giữ payload + model object + token + preview target IDs. Model/token đổi hoặc target match khác preview sẽ từ chối; @job/edit guards. Preview cache và index ID/name tránh quét native attributes toàn bộ cho mỗi scene ở mỗi poll.
- Toolbar 5 nút: panel/4-view/update-view/copy-current/paste. Copy-current không mở panel; Paste/Load mở panel và preview. Trong Scene: copy selected (fallback current), xuất selected/all, nhập checklist new/update/skip (default new). JS dùng textContent/ID/token, giữ chọn khi refresh, hủy/Esc, chặn double-submit và model switch.
- New page được tạo với PAGE_USE_CAMERA; update sửa trực tiếp Page#camera để giữ các thiết lập khác. API hỗ trợ SU22. Operation là bắt buộc cho scene edits SU2026; SU22–25 camera scene không có native Undo tương đương, nên transfer tự backup và rollback camera/attrs + erase created pages nếu lỗi. Không hứa Undo toàn bộ scene cho SU cũ.
- Target current xác minh release notes SU2026.2 ngày 2026-10-03. Ruby2.7-compatible syntax; actual SU22 Ruby2.7.2 DLL chạy trong console process với fixture đã qua; Ruby3.2 WASM/Chromium đã qua. `check_ruby27.py` không launch SketchUp/kernel, không đụng model đang làm; ghi test data chỉ trong outputs. SU2025 vpwidth/vpheight và draw2d đổi đồng thời sang logical pixels nên grid không scale tay thêm. **Chưa xác minh native các phiên bản SU2022–2026.2.**
- Allowlist deploy 16 file, thêm transfer.rb/copy_scene.svg/paste_scene.svg. Chỉ cài SU22 theo yêu cầu hiện tại; không tự copy vào bản khác hoặc thay plugin khác. Dev native_smoke sửa kiểm tra scoped section vốn còn API plane_for cũ.
- Đã cài 1.1.0 SU22 lúc 2026-10-03 11:17 +07:00, backup outputs/install_20261003_111743_242; 16 file khớp nguồn, 7.914 file khác hash không đổi; legacy_loader_retired=false (đã tắt từ trước). Toolbar mới cần restart SU; không thay đổi phiên model đang mở.
