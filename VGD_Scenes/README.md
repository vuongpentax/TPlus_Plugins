# VGD Scenes 1.0.0 — SketchUp 2022

Plugin tạo view đối tượng, mặt cắt tùy chỉnh, quản lý scene và xuất ảnh/PDF. Thương hiệu VGD, giao diện sáng/tối dùng bảng màu nâu, trắng và than theo theme T+.

## Đã cài trên máy

- Loader: `%APPDATA%/SketchUp/SketchUp 2022/SketchUp/Plugins/vgd_scenes.rb`
- Thư mục riêng: `.../Plugins/vgd_scenes/`
- Loader scene T+ cũ được sao lưu và đổi thành `tplus_scenes_to_layout.rb.vgd-disabled`; chỉ có hiệu lực tắt ở lần khởi động SketchUp kế tiếp.
- Không sửa thư mục `tplus`, plugin Cabinet/Dim hoặc bố trí toolbar khác. Đối chiếu trước/sau cài: **7.713 file khác, 0 thay đổi**.
- Báo cáo và bản sao loader cũ nằm trong `outputs/install_*/` trên máy đã cài, không đưa lên GitHub.

Hãy lưu công việc và khởi động lại SketchUp khi thuận tiện. Mở **Extensions → VGD Scenes → VGD Scenes · Bảng điều khiển**. Nếu muốn toolbar, chọn **Hiện thanh công cụ VGD Scenes** trong menu này.

## Cách dùng

1. Chọn Group/Component. Trong **Góc nhìn**, chọn view, hệ trục theo đối tượng hoặc thế giới, gộp cụm hoặc từng đối tượng. Bấm **Tạo / Cập nhật góc nhìn**. Có ISO và sáu hướng tiêu chuẩn; lặp lại cùng đối tượng/view sẽ cập nhật scene VGD tương ứng.
2. Trong **Mặt cắt**, chọn X/Y/Z hoặc vector riêng; đặt vị trí theo phần trăm, dịch thêm bằng mm, đảo hướng và tên mặt cắt. Mỗi tên mặt cắt có scene riêng; chạy lại cùng tên sẽ cập nhật.
3. Trong **Scene**, bấm tên để mở, đánh dấu scene cần xuất, đổi tên, xóa hoặc lưu view hiện tại. **Cập nhật từ nguồn** tính lại camera/mặt cắt từ đối tượng VGD; **Lưu view** giữ bố cục bạn vừa chỉnh. Xóa/cập nhật có Undo.
4. Trong **Xuất & Khung**, đặt kích thước ảnh, tỷ lệ và lề. Áp khung hoặc fit đối tượng; bật lưới 1/3, giữa, tỷ lệ vàng hoặc 4×4. Orbit bằng chuột giữa; Esc tắt lưới. Bấm **Lưu view** ở scene sau khi canh camera để lưu bố cục.
5. Đánh dấu scene và xuất PNG/JPG vào thư mục, hoặc một PDF nhiều trang theo thứ tự scene trong model. Chọn A4/A3 ngang/dọc. File đã có sẽ được thêm số, không ghi đè. Có tiến độ, hủy và báo cáo lỗi xuất ảnh.

## Những điểm cần biết

- PNG trong suốt bỏ nền SketchUp; không tự xóa mặt sàn, tường hay vật thể trong hình. JPG/PDF dùng nền bình thường.
- PDF chứa một ảnh của mỗi scene trên một trang, giữ tỷ lệ và chừa lề 10 mm. Đây là PDF hình ảnh, không phải bản vẽ vector có tỷ lệ in kỹ thuật.
- Khung/lưới hỗ trợ bố cục trong cửa sổ model; lưới được tạm ẩn khi xuất.
- Khi xuất, đóng chế độ edit Group/Component và giữ model ổn định. Plugin phục hồi camera, trạng thái hiển thị và mặt cắt sau tác vụ.
- Scene ngoài VGD được liệt kê và có thể xuất. Đổi tên/xóa/lưu view chỉ thực hiện với scene bạn chủ động chọn; cập nhật theo đối tượng chỉ áp dụng scene VGD.
- Khi xóa scene mặt cắt, mặt phẳng cắt VGD được giữ lại để tránh làm hỏng scene khác có thể dùng chung nó. Không xóa mặt cắt của plugin khác.
- Không có chức năng dimension tự động hoặc chuyển viewport sang LayOut; phạm vi bản này tập trung vào scene và xuất hình theo yêu cầu.

## Kiểm tra đã thực hiện

- Kiểm tra cú pháp 7 file Ruby và chạy kiểm tra engine bằng Ruby WASM 3.2 với mô hình API: hệ trục xoay/lồng/phản chiếu, mặt cắt tùy chỉnh, scene không trùng, đổi tên/xóa/update, khôi phục view và xuất/hủy/lỗi/PDF.
- Kiểm tra giao diện bằng Chromium: tên có dấu/nháy/ký tự HTML, ID scene, lựa chọn xuất, xác nhận thao tác, đổi model, kích thước 640×780 và 460×540.
- Cài và kiểm tra hash 11 file VGD; 7.713 file khác không đổi.
- **Chưa hoàn tất kiểm tra engine trong SketchUp 2022 thật.** Script thử đã chạy trên SU22 22.0.316 / Ruby 2.7.2 nhưng dừng ở điều kiện bảo vệ model không rỗng, trước khi tạo hình/scene. Điều khiển máy sau đó được người dùng dừng bằng Esc. Kiểm tra WASM và Chromium không thay thế kiểm thử Ruby 2.7/CEF/LayOut thực tế trong SU22.

Mã nguồn runtime nằm trong `runtime/`; kiểm tra và script cài giới hạn phạm vi nằm trong `dev/`. RBZ chỉ đóng gói runtime, không chứa bộ test hoặc thư viện ngoài.

## Tiếp tục trên máy ở nhà

```powershell
git clone https://github.com/vuongpentax/TPlus_Plugins.git
cd TPlus_Plugins
```

Kho riêng tư: đăng nhập tài khoản GitHub có quyền truy cập khi Git yêu cầu. Mở thư mục repository trong Codex và yêu cầu tiếp tục `VGD_Scenes`, đọc `CODEX_HANDOFF.md` trước. Nếu đã clone, chạy `git pull --ff-only` khi không có thay đổi chưa lưu.

Để cài trên máy mới, dùng SketchUp **Window → Extension Manager → Install Extension**, chọn `VGD_Scenes/VGD_Scenes_v1.0.0.rbz`. Hoặc chạy script giới hạn phạm vi:

```powershell
.\VGD_Scenes\dev\deploy.ps1 -VerifyOnly
.\VGD_Scenes\dev\deploy.ps1
```

Script mặc định dùng APPDATA của tài khoản hiện tại, chỉ cài 11 file VGD. Nếu muốn tắt loader Scenes T+ cũ đã được kiểm tra, thêm `-RetireLegacy`; script từ chối loader khác hash. Không tác động thư mục `tplus` dùng chung.

Kiểm tra mã/giao diện với Node.js 20 trở lên và Google Chrome:

```powershell
cd VGD_Scenes\dev
npm install
npm test
```

Thư viện Node chỉ phục vụ kiểm tra, không cần cho runtime SketchUp. Không đưa `node_modules`, file xuất thử hoặc bản sao cài đặt lên Git. Sau khi sửa và kiểm tra, commit rồi push trước khi chuyển máy.
