# VGD Scenes 1.2.1 — SketchUp 2022–2026.2

Plugin tạo view đối tượng, mặt cắt tùy chỉnh, quản lý scene và xuất ảnh/PDF. Thương hiệu VGD, giao diện sáng/tối dùng bảng màu nâu, trắng và than theo theme T+.

## Đã cài trên máy

- Loader: `%APPDATA%/SketchUp/SketchUp 2022/SketchUp/Plugins/vgd_scenes.rb`
- Thư mục riêng: `.../Plugins/vgd_scenes/`
- Loader scene T+ cũ được sao lưu và đổi thành `tplus_scenes_to_layout.rb.vgd-disabled`; chỉ có hiệu lực tắt ở lần khởi động SketchUp kế tiếp.
- Bộ cài chỉ ghi 17 file riêng của VGD Scenes. Không sửa thư mục `tplus`, plugin Cabinet/Dim hoặc bố trí toolbar khác; script đối chiếu hash tất cả file plugin khác trước/sau và lưu báo cáo trong `outputs/install_*/`.
- Lượt cài 1.1.0 ngày 03/10/2026: 16 file khớp runtime; **7.914 file plugin khác không đổi**. Backup: `outputs/install_20261003_111743_242/`.
- Lượt cài 1.2.0 ngày 03/10/2026: 17 file khớp runtime; **7.939 file plugin khác không đổi**. Backup: `outputs/install_20261003_171852_481/`.
- Lượt cài 1.2.1 ngày 03/10/2026: 17 file khớp runtime; **7.994 file plugin khác không đổi**. Backup: `outputs/install_20261003_183241_486/`.
- Báo cáo và bản sao loader cũ nằm trong `outputs/install_*/` trên máy đã cài, không đưa lên GitHub.

Hãy lưu công việc và khởi động lại SketchUp khi thuận tiện. Mở **Extensions → VGD Scenes → VGD Scenes · Bảng điều khiển**. Nếu muốn toolbar, chọn **Hiện thanh công cụ VGD Scenes** trong menu này.

### Cập nhật view bằng một nút

Toolbar có năm nút: bảng điều khiển, 4 view nhanh, **Cập nhật view hiện tại**, **Copy scene hiện tại**, **Paste scenes**. Chọn scene, chỉnh camera/khung/mặt cắt rồi bấm nút thứ ba (máy ảnh/mũi tên vòng) để lưu vào scene đang chọn. Không cần mở bảng hoặc chọn đối tượng; giữ tên scene. Các lệnh cũng có trong **Extensions → VGD Scenes** để gán phím tắt.

Lệnh lưu camera, hiển thị, mặt cắt và khung giống **Lưu view** trong bảng. Khi chưa có scene đang chọn, đang edit Group/Component hoặc đang xuất, lệnh báo lý do và không cập nhật.

### Chuyển góc scene từ A sang B

1. Trong file A, lưu view vừa chỉnh vào scene. **Copy scenes** ở mục Scene lấy các scene đã đánh dấu; nếu chưa đánh dấu thì lấy scene đang mở. Copy trên toolbar luôn lấy riêng scene đang mở.
2. Mở file B, bấm **Paste scenes**. Chọn scene trong bảng xem trước và cách xử lý trùng: **Tạo mới** (mặc định, thêm số vào tên), **Cập nhật** hoặc **Bỏ qua**.
3. Cập nhật khớp ID trước, rồi tên chính xác; giữ tên/thứ tự ở B. ID nguồn ổn định qua rename/Save As. Khi nhiều scene cùng khớp mà tên không phân biệt được, plugin từ chối tự chọn. Nếu scene đích đổi sau preview, Paste/Nhập lại.
4. Mang sang máy khác: chọn **Toàn bộ scene trong model** hoặc **Scene đã đánh dấu**, bấm **Xuất bộ scene…**. Ở B dùng **Nhập bộ scene…** với tệp `.vgdscenes.json`. Tệp đã có không bị ghi đè.

Chuyển camera perspective/parallel, vị trí/hướng/roll, FOV hoặc chiều cao parallel và khung width/height/margin. Camera chưa khóa tỷ lệ được cố định theo khung xuất của scene để bố cục không phụ thuộc cửa sổ máy đích. Dùng tọa độ thế giới (inch theo API), không tự căn theo đối tượng: A/B cần cùng gốc và hướng trục. Scene nhập mới chỉ lưu camera, không nhận source paths/hình học từ A. Cập nhật scene VGD sẵn có giữ nguồn của B để dùng Cập nhật từ đối tượng khi chủ động yêu cầu.

Bản này chưa chuyển Tags, style, đối tượng ẩn, mặt cắt hoặc animation; cập nhật giữ thiết lập đó ở B. Từ chối hai điểm/Match Photo vì API không có setter đầy đủ để phục hồi chính xác. Giới hạn 1.000 scene/8 MB; kiểm tra JSON trước khi đổi model.

Clipboard riêng ở `%APPDATA%/VGD/Scenes/scene_clipboard_v1.json`, dùng giữa các process/phiên bản SketchUp trên cùng tài khoản Windows; không dùng clipboard hệ thống. Copy/xuất lần đầu gán attribute ID riêng vào scene nguồn, nên SKP có thể hiện đã sửa; lưu SKP để giữ ID khi mở lại.

### Bỏ khung xám trước khi gửi SKP (1.2.1)

Trong **Xuất & Khung → Gửi file SketchUp**, bấm **Bỏ khung xám tất cả scene**, xác nhận rồi lưu SKP. Hoặc dùng **Extensions → VGD Scenes → VGD · Bỏ khung xám tất cả scene để gửi SKP** mà không mở bảng. Lệnh áp dụng toàn bộ scene trong model, kể cả scene ngoài VGD và scene không được đánh dấu xuất, cùng view hiện tại.

Lệnh đặt `camera.aspect_ratio = 0` trên camera gốc của từng scene theo [Camera API](https://ruby.sketchup.com/Sketchup/Camera.html). Người nhận không cần VGD để xem scene không còn dải xám. Khung nhìn theo tỷ lệ cửa sổ SketchUp của họ nên vùng thấy ở mép có thể rộng/hẹp hơn; kích thước xuất VGD đã lưu vẫn được giữ. Lệnh không cập nhật toàn bộ scene, không đổi vị trí/hướng camera, tên/ID/thứ tự, Tags/style/mặt cắt và không xóa geometry. Không tự lưu/ghi đè SKP.

**Khôi phục khung đã bỏ** dùng backup tỷ lệ riêng lưu cùng SKP. Cần lệnh này trên SU22–25 vì camera scene không có Undo đầy đủ như [SU2026](https://ruby.sketchup.com/Sketchup/Page.html). Khôi phục bỏ qua scene đã xóa hoặc đã chỉnh lại tỷ lệ khác 0; không bật lại lưới. Khi xuất VGD, ảnh vẫn dùng kích thước đã lưu mà không khóa lại camera của scene; bấm Áp dụng khung/Update view sau này có thể lưu khung trở lại, nên chạy Bỏ khung lần cuối trước khi gửi. Có rollback rõ ràng khi lỗi và chặn edit/export/model đã đổi.

Kiểm tra Ruby 2.7.2 DLL và WASM3.2 fixture + Chromium đã qua, gồm rollback lỗi giữa chừng, camera hai điểm không bị dựng lại, native scene/flags/frame size, restore/export, scope toàn model và hủy xác nhận. Chưa kiểm chứng lệnh trong kernel SketchUp thật.

### Sắp xếp và cao độ camera (1.2.0)

- Kéo nút ba sọc cuối dòng scene để đổi thứ tự **riêng trong bảng VGD**. Thứ tự được lưu cùng SKP, có Undo; PNG/JPG, các trang PDF và Copy/Xuất JSON dùng thứ tự này, không phụ thuộc thứ tự tick checkbox. Thanh scene, ID và liên kết scene SketchUp giữ nguyên trên mọi phiên bản. Scene mới thêm từ SketchUp được đặt cuối bảng; xóa/đổi tên vẫn nhận đúng ID. Khi đang lọc, thả trên/dưới một scene lấy vị trí của scene đó trong danh sách đầy đủ, không xóa scene đang ẩn bởi bộ lọc.
- Bấm tên scene rồi dùng ↑/↓ trong bảng để chuyển theo danh sách đang lọc. Không thêm shortcut vào SketchUp; PageUp/PageDown của SU giữ nguyên. Không bắt mũi tên khi đang gõ, ở checkbox, hộp xác nhận, đang xuất hoặc edit Group/Component.
- **Xuất & Khung → Cao độ mắt camera**: nhập Z tuyệt đối hoặc cao độ sàn + Eye Height, đơn vị mm theo trục Z thế giới. Ví dụ sàn +3200 và Eye Height 1500 cho mắt +4700 mm. Giữ hướng nhìn di chuyển cả mắt và điểm nhìn cùng độ cao; bỏ tick giữ điểm nhìn hiện tại. Hỗ trợ Perspective/Parallel; không dùng chiều cao khung Parallel làm Eye Height.
- **Xem trước cao độ** chỉ đổi view hiện tại. Bấm nút **Cập nhật view** trên toolbar hoặc **Lưu view** để lưu scene; xuất tiếp tục dùng camera đã lưu. Hai điểm/Match Photo và edit context được chặn.
- Clipping chưa tích hợp. [Báo cáo thí nghiệm](dev/CLIPPING_RESEARCH.md) và `dev/clipping_lab.rb` nằm riêng, không cài vào SU. Người dùng dừng Computer Use bằng Esc nên chưa kiểm chứng Force/Near trên model mẫu.

### Tương thích phiên bản

Mục tiêu Windows: SketchUp Desktop **2022, 2023, 2024, 2025 và 2026 đến 2026.2**; mốc hiện hành theo [release notes 2026.2](https://help.sketchup.com/en/sketchup-desktop-20262). Không dùng Overlay API hoặc clipboard API chỉ có ở bản mới, không cần thư viện native ngoài.

- Đã chạy cú pháp và bộ fixture với DLL Ruby **2.7.2 đi kèm SU22** trong process console riêng và Ruby WASM **3.2**. Hai bộ kiểm tra không điều khiển SketchUp đang mở.
- `vpwidth/vpheight` và `draw2d` dùng cùng hệ pixel trên từng phiên bản; SU2025+ đổi cả hai sang logical pixels theo [View API](https://ruby.sketchup.com/Sketchup/View.html).
- Chỉnh scene được bọc operation cho SU2026. Với SU22–25, không đảm bảo Undo camera scene; nhập có backup camera/attribute và rollback rõ ràng khi lỗi. Khác biệt theo [Page API](https://ruby.sketchup.com/Sketchup/Page.html).
- **Chưa chạy plugin trong kernel SketchUp thực tế trên tất cả các bản này.** Cần kiểm tra camera/mặt cắt/PNG/PDF và toolbar trên SU22 cùng các bản mới trước khi xác nhận đầy đủ.

## Cách dùng

1. Chọn Group/Component. Trong **Góc nhìn**, chọn view, hệ trục theo đối tượng hoặc thế giới, gộp cụm hoặc từng đối tượng. Bấm **Tạo / Cập nhật góc nhìn**. Có ISO và sáu hướng tiêu chuẩn; lặp lại cùng đối tượng/view sẽ cập nhật scene VGD tương ứng và đổi tên tất cả scene VGD của bộ đối tượng đó theo tên mới, kể cả view không đang chọn và scene mặt cắt. Tên theo mẫu đã lưu; tên sửa tay sẽ được tạo lại khi cập nhật.
2. Trong **Mặt cắt**, chọn X/Y/Z hoặc vector riêng; đặt vị trí theo phần trăm, dịch thêm bằng mm, đảo hướng và tên mặt cắt. Mỗi tên mặt cắt có scene riêng; chạy lại cùng tên sẽ cập nhật. Mặt cắt nằm bên trong từng Group/Component được chọn, không thêm mặt cắt ở cấp model. Component/Group dùng chung sẽ Make Unique bản chọn; với đối tượng nằm trong cha dùng chung, Make Unique cha trước. Camera luôn nhìn từ phía đã bỏ vào phần còn lại, kể cả khi đảo phía cắt.
3. Trong **Scene**, bấm tên để mở, đánh dấu scene cần xuất, đổi tên, xóa hoặc lưu view hiện tại. **Cập nhật từ đối tượng** tính lại camera/mặt cắt và tên scene từ đối tượng nguồn bằng thông số đã lưu, không cần chọn lại đối tượng; **Lưu view** giữ bố cục bạn vừa chỉnh. Undo scene tùy phiên bản SketchUp; xem mục Tương thích.
4. Trong **Xuất & Khung**, chọn preset hoặc nhập tỷ lệ rộng:cao như `3:4`. Nút **⇄** đổi ngang/dọc để xem trước. **Căn lề view hiện tại** chỉ căn và preview, giữ hướng nhìn/phối cảnh; không lưu scene. Bấm **Áp dụng khung** để lưu camera và kích thước riêng vào scene đang mở. **Bật/Tắt khung** đổi giữa khung tỷ lệ và khung nhìn đầy cửa sổ SketchUp; không đổi scene đã lưu. **Bật/Tắt lưới** độc lập, Esc tắt lưới. Sau khi Orbit/canh tay có thể dùng **Lưu view** để chủ động lưu bố cục.
5. Đánh dấu scene và xuất PNG/JPG vào thư mục, hoặc PDF nhiều trang theo thứ tự riêng trong bảng VGD. Mỗi scene dùng kích thước và bố cục đã lưu riêng (ví dụ TOP 1200×1600, ISO 1920×1080). PDF giữ đúng tỷ lệ từng ảnh trên khổ giấy A4/A3 ngang/dọc đã chọn. Scene cũ chưa lưu kích thước được suy từ khung camera và độ phân giải nguồn/batch. File đã có được thêm số, không ghi đè. Tiến độ và lỗi hiển thị trong dialog; không tạo JSON báo cáo cạnh ảnh.

## Những điểm cần biết

- PNG trong suốt bỏ nền SketchUp; không tự xóa mặt sàn, tường hay vật thể trong hình. JPG/PDF dùng nền bình thường.
- PDF chứa một ảnh của mỗi scene trên một trang, giữ tỷ lệ và chừa lề 10 mm. Đây là PDF hình ảnh, không phải bản vẽ vector có tỷ lệ in kỹ thuật.
- Khung/lưới hỗ trợ bố cục trong cửa sổ model; lưới được tạm ẩn khi xuất.
- Khi xuất, đóng chế độ edit Group/Component và giữ model ổn định. Plugin phục hồi camera, trạng thái hiển thị và mặt cắt sau tác vụ.
- Scene ngoài VGD được liệt kê và có thể xuất. Đổi tên/xóa/lưu view chỉ thực hiện với scene bạn chủ động chọn; cập nhật theo đối tượng chỉ áp dụng scene VGD.
- Khi xóa scene mặt cắt, mặt phẳng cắt VGD được giữ lại để tránh làm hỏng scene khác có thể dùng chung nó. Không xóa mặt cắt của plugin khác.
- Không có chức năng dimension tự động hoặc chuyển viewport sang LayOut; phạm vi bản này tập trung vào scene và xuất hình theo yêu cầu.

## Kiểm tra đã thực hiện

- Kiểm tra cú pháp 9 file runtime Ruby, engine fixture trên Ruby 2.7.2 của SU22 và WASM 3.2: tính năng trước, chuyển giữa model, camera/khung, rename/ID/tên trùng, tạo/cập nhật/bỏ qua, rollback khi lỗi, FOV ngang, JSON lỗi/quá lớn và clipboard qua file.
- Giao diện Chromium: Unicode/HTML, ID, scope xuất/nhập, xác nhận/hủy/lỗi, đổi model, token preview, sáng/tối, 640×780 và 460×540.
- Cài bằng allowlist 17 file và kiểm tra hash các plugin khác. Báo cáo thực tế ở backup lượt cài trong outputs.
- **Chưa hoàn tất kiểm tra engine trong SketchUp 2022 thật.** Script thử đã chạy trên SU22 22.0.316 / Ruby 2.7.2 nhưng dừng ở điều kiện bảo vệ model không rỗng, trước khi tạo hình/scene. Điều khiển máy sau đó được người dùng dừng bằng Esc. Kiểm tra WASM và Chromium không thay thế kiểm thử Ruby 2.7/CEF/LayOut thực tế trong SU22.

Mã nguồn runtime nằm trong `runtime/`; kiểm tra và script cài giới hạn phạm vi nằm trong `dev/`. RBZ chỉ đóng gói runtime, không chứa bộ test hoặc thư viện ngoài.

## Tiếp tục trên máy ở nhà

```powershell
git clone https://github.com/vuongpentax/TPlus_Plugins.git
cd TPlus_Plugins
```

Kho công khai; cần quyền ghi khi push. Mở repository trong Codex và yêu cầu tiếp tục `VGD_Scenes`, đọc `CODEX_HANDOFF.md` trước. Nếu đã clone, chạy `git pull --ff-only` khi không có thay đổi chưa lưu.

Để cài trên máy mới, dùng SketchUp **Window → Extension Manager → Install Extension**, chọn `VGD_Scenes/VGD_Scenes_v1.2.1.rbz`. Hoặc chạy script giới hạn phạm vi:

```powershell
.\VGD_Scenes\dev\deploy.ps1 -VerifyOnly
.\VGD_Scenes\dev\deploy.ps1
```

Script mặc định cài SU22 bằng APPDATA của tài khoản hiện tại, chỉ cài 17 file VGD. Với bản khác, cài RBZ trong Extension Manager của đúng bản SketchUp hoặc truyền `-PluginRoot` đến Plugins của bản đó. `-RetireLegacy` chỉ tắt loader Scenes T+ đã review đúng hash. Không sửa `tplus` dùng chung.

Kiểm tra mã/giao diện với Node.js 20 trở lên và Google Chrome:

```powershell
cd VGD_Scenes\dev
npm install
npm test
```

Thư viện Node chỉ phục vụ kiểm tra, không cần cho runtime SketchUp. Không đưa `node_modules`, file xuất thử hoặc bản sao cài đặt lên Git. Sau khi sửa và kiểm tra, commit rồi push trước khi chuyển máy.

Có SU22 tại đường dẫn mặc định và Python 3.8+: chạy `python VGD_Scenes/dev/check_ruby27.py` từ root repo để kiểm tra thêm bằng Ruby 2.7.2. Đường dẫn SU22 khác có thể đặt qua biến `VGD_SU22_ROOT`. DLL chỉ dùng trong console test, không đóng gói vào runtime.

## Vector XYZ và cập nhật từ đối tượng

Vector XYZ chỉ hướng vuông góc với mặt phẳng cắt trong hệ trục đã chọn ở Góc nhìn. (0,1,0) là Y; (1,1,0) là hướng chéo 45° giữa X/Y. (2,2,0) có cùng hướng (1,1,0), không làm cắt sâu hơn. Không dùng (0,0,0). Vị trí dùng % và dịch thêm mm; đảo phía cắt không đổi vị trí.

Cập nhật từ đối tượng: đánh dấu scene VGD trong danh sách rồi bấm nút. Plugin tìm lại đối tượng nguồn đã ghi bằng persistent paths, đọc hình học/transform/tên hiện tại, căn camera và mặt cắt theo các thông số lưu lúc tạo scene, rồi đổi tên theo mẫu. Nếu đã sửa thông số trên bảng và muốn áp dụng thông số mới, chọn đối tượng và dùng Tạo/Cập nhật tương ứng. Camera canh tay sẽ bị thay khi cập nhật từ đối tượng; dùng Lưu view để giữ bố cục tay.

Mặt cắt cấp model từ 1.0.0 vẫn giữ cho scene cũ. Đánh dấu scene mặt cắt cũ và Cập nhật từ đối tượng để chuyển scene đó sang mặt cắt bên trong đối tượng.

## Tạo nhanh 4 view

Nút toolbar với icon bốn ô tạo/cập nhật ISO, TOP, FRONT, RIGHT từ đối tượng chọn. Nút bảng điều khiển dùng icon riêng như cũ. Bộ 6 view chuẩn vẫn có trong bảng điều khiển nếu chủ động chọn.

## Khóa tỷ lệ, scale và thư mục xuất (1.0.4)

- Bấm Khóa tỷ lệ để giữ tỷ lệ rộng:cao; nhập rộng hoặc cao thì chiều kia tự nhảy theo. Tắt khóa để nhập độc lập. Pixel làm tròn đến số nguyên; tỷ lệ khóa gốc được giữ khi nhập liên tiếp.
- Scale xuất ảnh chỉ nhân độ phân giải đầu ra của từng scene, không sửa camera/frame trong model. Ví dụ 1920×1080 scale 2 thành 3840×2160; scale 0.5 thành 960×540. Áp dụng PNG/JPG và ảnh đặt trong PDF; khổ giấy PDF giữ nguyên. Cho số dương tùy ý trong giới hạn 1–12000 px mỗi chiều và tối đa 64 triệu pixel sau scale. Kiểm tra toàn bộ scene trước khi xuất.
- Nơi lưu luôn có thư mục loại PNG/JPG/PDF. Tick Tạo thư mục ngày sẽ dùng ngày địa phương máy lúc bắt đầu xuất, ví dụ thư mục chọn/2026.10.03/PNG. PDF chọn tên ở hộp lưu như trước rồi được đặt trong thư mục PDF tương ứng. Không ghi đè file đã có.
