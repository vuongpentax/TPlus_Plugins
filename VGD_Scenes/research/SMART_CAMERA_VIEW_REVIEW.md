# Nghiên cứu Smart Camera View 3 cho VGD Scenes

Ngày 03/10/2026. Chỉ đọc file/tài liệu và đối chiếu API/mã hiện tại; chưa chạy MAXScript, chưa mở thí nghiệm SketchUp, chưa sửa runtime, chưa cài thêm.

## Phạm vi và bằng chứng

File người dùng cung cấp: `C:/Users/PC/AppData/Local/Autodesk/3dsMax/2024 - 64bit/ENU/scripts/D95 DESIGN/Smart Camera View 3/Smart_Camera_View_3.mse`, 117.499 byte. SHA256: `B456AC7C2D2B95CB237A653A572F4EC8FE67E2415B57E0C2F695165C0B71701E`.

Đây là file nhị phân `.mse`; [Autodesk xác nhận đây là MAXScript mã hóa](https://help.autodesk.com/cloudhelp/2022/ENU/MAXScript-Help/files/MAXScript-Introduction/General-MAXScript-Topics/GUID-6736979B-D33A-4968-8BD2-FE2365A3A539.html). Không đọc được thuật toán nguồn bằng cách xem text, nên báo cáo không phải review implementation bên trong và không xác nhận phiên bản chính xác của file cục bộ.

Thư mục có bốn ảnh icon và `start.ms`. Launcher tham chiếu `SmartCameraView3.mse`, trong khi file hiện có tên `Smart_Camera_View_3.mse`. Đây là khác biệt tên cần kiểm tra nếu dùng riêng launcher đó; chưa kết luận script đang dùng trong Max bị lỗi, vì macro đang sử dụng có thể gọi đường dẫn khác. Không sửa file D95.

[Hướng dẫn chính thức D95](https://d95design.com/product/smart-camera-view-3/) mô tả quản lý camera, tên, khung, canh camera và xuất hàng loạt; tài liệu hiện có thể khác bản người dùng cài. Những mục tham chiếu cho nghiên cứu: chọn theo tên/tỷ lệ, đổi tên nhiều camera, thông số khung riêng, FOV/tiêu cự, canh trục, lưới tùy chỉnh, Overscan, Lite Mode, clipping và DOF. Phần dưới là đề xuất riêng cho VGD, dựa trên mã VGD Scenes 1.2.0 và API SketchUp; không chuyển mã MAXScript sang Ruby.

## Khác biệt cần thiết kế đúng

Camera trong Max là đối tượng của scene; scene SketchUp lưu trạng thái view và các thiết lập khác. VGD nên làm việc trên ID scene và camera đã lưu, không thêm camera/target hình học vào bản vẽ. Khi đổi FOV/khung/cao độ phải phân biệt view xem trước, scene đang mở và tập scene đã đánh dấu để xuất.

Tên dùng tiếng Việt và tên do người dùng chỉnh là dữ liệu cần giữ. Không nên ép bỏ dấu/cấm khoảng trắng chỉ để giống phần mềm tham chiếu. Tên ảnh xuất có thể được làm sạch riêng mà không đổi tên scene.

## Đối chiếu với bản hiện tại

| Nhóm khả năng | VGD Scenes 1.2.0 hiện tại | Hướng đề xuất cho SU |
|---|---|---|
| Khung riêng và chuyển view | Camera và width/height/margin riêng từng scene; đổi scene nạp khung | Hiện `1920×1080 · 16:9` ở dòng scene, dùng badge riêng để giữ tên ngắn |
| Chọn/lọc scene | Tìm tên, chỉ VGD, chọn đang lọc, checkbox xuất, kéo thứ tự riêng, ↑/↓ | Thêm nhóm tùy chọn và bộ lọc tỷ lệ/phối cảnh; luôn phân biệt scene đang mở và scene đánh dấu |
| Đặt tên hàng loạt | Mẫu tên lúc tạo; đổi tên từng scene | Preview tên cũ → mới, prefix/suffix, số bắt đầu, padding, thay chuỗi; áp dụng chỉ ID đã chọn |
| Khung hàng loạt | Áp dụng khung vào scene đang mở; scale riêng cho lượt xuất | Áp dụng preset vào scene đánh dấu; Copy/Paste chỉ khung, không đổi camera position/visibility/cut |
| FOV/tiêu cự | Camera giữ FOV khi lưu/copy nhưng bảng chưa có ô chỉnh | Thêm FOV độ hoặc tiêu cự mm, chế độ Perspective; xem trước rồi Update view |
| Canh camera | Có view cơ bản theo trục thế giới/đối tượng; fit giữ hướng; cao độ mắt | Thêm giữ mắt/giữ điểm nhìn, chỉnh hướng ngang, loại roll; snap hướng theo trục/hướng tùy chọn |
| Lưới | 1/3, tâm, vàng, 4×4 | Thêm hàng/cột tùy chọn, đường chéo, màu/độ mờ; lưới chỉ hỗ trợ viewport |
| Xuất | PNG/JPG/PDF theo thứ tự VGD; scale/ngày/khung riêng | Preset xuất có tên, preview tên và đường dẫn trước khi xuất, nút mở thư mục tùy chọn |
| Giao diện gọn | HtmlDialog theme VGD/T+, bốn tab | Chế độ gọn: danh sách + Update + Xuất, mở rộng phần thông số khi cần |
| Overscan | Scale hiện tại chỉ tăng pixel; lề fit thay vị trí camera | Thử riêng mở rộng vùng thấy bằng FOV/ortho height, giữ mắt/hướng/tâm; không gọi scale pixel là Overscan |

## Khả năng API và giới hạn

**FOV/tiêu cự, điểm nhìn, canh camera:** [Camera API](https://ruby.sketchup.com/Sketchup/Camera.html) có `fov=`, `focal_length=`, `image_width`, `set(eye,target,up)` từ các phiên bản trước SU22. FOV chỉ áp dụng Perspective; Parallel chỉnh chiều cao vùng nhìn. Tiêu cự phụ thuộc image_width, nên cần quy ước rõ trước khi hiển thị mm hoặc preset 24/35/50. Đồng thời xử lý FOV ngang/dọc và tỷ lệ ảnh để đổi đơn vị không làm nhảy bố cục. Đây là đánh giá khả thi, chưa có implementation/test cho tính năng mới.

Canh mắt và target cùng cao độ tạo hướng nhìn ngang; chỉnh up có thể loại roll cho perspective thường. Điều đó không thay thế đầy đủ lens shift/two-point. Camera hai điểm/Match Photo có thông số đọc nhưng thiếu setter tương ứng đầy đủ để tái tạo chính xác; giữ giới hạn hiện tại đến khi có thử nghiệm chứng minh khác.

**Lưới và thông tin:** [View API](https://ruby.sketchup.com/Sketchup/View.html) cho vẽ 2D/text. Có thể mở rộng FrameTool hiện tại trên SU22. Tool trên SU22 có thể bị thay khi người dùng chọn tool khác; không nên hứa lưới luôn hiện trong mọi thao tác như overlay ở các bản mới. Thông tin tên/kích thước của VGD cần tạm ẩn khi xuất.

**Panel gọn:** [HtmlDialog](https://ruby.sketchup.com/UI/HtmlDialog.html) có các kiểu cửa sổ, gồm utility với thanh tiêu đề nhỏ. Tài liệu không có cơ chế đăng ký panel Ruby vào Default Tray; vì vậy phương án khả thi trước mắt là cửa sổ VGD gọn nhớ vị trí/kích thước, không cam kết dock giống Max hoặc tray gốc.

**Clipping:** [Issue #311 của SketchUp](https://github.com/SketchUp/api-issue-tracker/issues/311) vẫn mở. Hộp Camera Windows ẩn không đồng nghĩa có setter Near/Far Ruby ổn định. Không đưa điều khiển cửa sổ ẩn hoặc bộ nhớ native vào plugin chính. Bộ mẫu `dev/clipping_lab.rb` vẫn chưa được thử thành công. Cần chứng minh viewport, scene persistence, PNG/JPG/PDF và restore trên model mẫu trước.

**DOF/render preset:** Camera Ruby không công bố bộ aperture/focus/DOF cho viewport tương đương camera render trong Max. `write_image` xuất view SketchUp; để có ảnh DOF/render thật phải khảo sát API của renderer cụ thể. Chưa chọn renderer, chưa có căn cứ làm tính năng chung cho V-Ray/Enscape/D5 hay các engine khác.

**Khóa camera:** có thể đặt cờ bảo vệ scene để lệnh VGD từ chối ghi nhầm; cờ này không ngăn người dùng Orbit hoặc update trong SketchUp gốc. Không dùng hook toàn cục để chặn công cụ khác.

## Năm bổ sung nên ưu tiên

1. **Thông tin ở dòng scene:** kích thước, tỷ lệ, loại camera và nhóm; lọc nhanh theo chúng. Dữ liệu mở rộng dùng riêng attribute VGD. Với scene cũ, đánh dấu khung suy ra thay vì giả định tất cả đều đã lưu kích thước rõ ràng.
2. **Đổi tên nhiều scene có preview:** dùng chính thứ tự riêng VGD để đánh số; kiểm tra tên trùng. Cân nhắc cờ giữ tên sửa tay vì source-update hiện tạo lại tên theo mẫu. Cờ đó phải do người dùng chủ động chọn, không âm thầm đổi hành vi đã có.
3. **Camera dễ chỉnh:** FOV/tiêu cự cạnh cao độ, giữ mắt/target, hướng ngang/loại roll cho camera thường. Xem trước và lưu scene là hai nút rõ ràng.
4. **Preset và khung hàng loạt:** đặt tên preset, chọn đúng scene đích, chỉ đổi frame/lens khi được yêu cầu. Copy/Paste khung có scope riêng với Copy/Paste scene hiện tại.
5. **Chế độ bảng gọn:** danh sách scene và nút Update/Xuất luôn dễ thấy; thông số nằm trong nhóm mở rộng. Giữ thương hiệu VGD và bảng màu T+, không chép icon hoặc giao diện của D95.

Lưới tùy chỉnh và preset xuất có thể theo sau. Overscan/clipping nên là nhánh thử riêng. DOF, render farm, quản lý keyframe/modifier, khóa nhiều viewport hoặc tự tắt máy chưa phù hợp phạm vi VGD Scenes hiện tại.

## Điều kiện trước khi triển khai

Giữ ID, thứ tự scene SketchUp và liên kết ngoài; không xóa/tạo lại scene để chỉnh. Chỉ ghi attribute của VGD và scene người dùng chọn. Batch có preview/scope, preflight và rollback; trên SU22 không chỉ dựa vào Undo của camera scene. Camera preview không tự ghi scene. Không sửa thư mục T+, Cabinet/Dim, file D95 hoặc preset renderer. Cài bằng allowlist và đối chiếu hash như hiện tại.

Khi được duyệt phạm vi mới, thử trên model mẫu cả Perspective/Parallel, FOV ngang/dọc, scene ngoại lai, tên Unicode/trùng, Undo/rollback và export khung hỗn hợp. Chỉ sau khi kiểm chứng mới tích hợp/cài. Báo cáo này chưa thực thi các bước đó.
