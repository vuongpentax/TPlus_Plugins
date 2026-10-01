# T+ Cabinet — Codex handoff

Đọc file này trước khi sửa mã. Đây là trạng thái dự án tại ngày 2026-10-01, cập nhật Reload và đồng bộ riêng T+ Cabinet ở beta 6.

## Mục tiêu hiện tại

Xây dựng plugin SketchUp **T+ Cabinet** để dựng tủ đúng kết cấu thực tế trong SketchUp. Giai đoạn hiện tại chỉ tập trung dựng hình và cập nhật tham số. Chưa làm BOM, nhãn sản xuất, nesting, DXF/CNC hay thư viện phụ kiện.

Người dùng gọi là **Dừa**, làm thiết kế nội thất và 3D tại T+ Architecture. Trao đổi bằng tiếng Việt, ưu tiên câu trả lời ngắn, rõ và đưa file RBZ để thử trực tiếp.

## Mốc đang dùng

- Phiên bản: `4.3.0-beta.6`
- RBZ gần nhất: `outputs/tplus_cabinet_modeling/TPlus_Cabinet_v4.3.0-beta.6.rbz`
- Source ZIP: `outputs/tplus_cabinet_modeling/TPlus_Cabinet_v4.3.0-beta.6_source.zip`
- Mã nguồn đang chạy: `cabinet_work/`
- Loader: `cabinet_work/tplus_cabinet.rb`
- Entry point thật: `cabinet_work/TPlus_Cabinet/main43.rb`
- Engine hình học: `cabinet_work/TPlus_Cabinet/geometry_engine.rb`
- Quy tắc và kiểm tra tham số: `cabinet_work/TPlus_Cabinet/modeling_rules.rb`
- Hình học cơ bản, vật liệu, cánh kính: `cabinet_work/TPlus_Cabinet/modeling.rb`
- Giá trị mặc định: `cabinet_work/TPlus_Cabinet/defaults.rb`
- Giao diện đóng gói: `cabinet_work/TPlus_Cabinet/TPlus_Cabinet_UI.html`
- Hướng dẫn người dùng: `cabinet_work/TPlus_Cabinet/HUONG_DAN.txt`
- Hai tiện ích EXPLODE/UNTAG: `cabinet_work/TPlus_Cabinet/utilities.rb`
- Reload: `cabinet_work/TPlus_Cabinet/reload.rb`
- Đồng bộ SketchUp 2022: `cabinet_dev/sync_sketchup_2022.ps1`

File `main.rb` trong thư mục runtime là mã 4.2.4 cũ, không nằm trong gói RBZ. Không đổi entry point về `main.rb`. `utilities.rb` đã được khôi phục, điều chỉnh và nạp từ `main43.rb` ở beta 5. Manifest ban đầu `HANDOFF_MANIFEST.json` là dấu vết gói nhập beta 4, không phải checksum của bản đang phát triển.

## Các quyết định đã chốt

### Cấu tạo thùng

- Kích thước W/D/H là phủ bì.
- Hồi chạy suốt; nóc và đáy kẹp giữa hai hồi.
- Hậu có ba lựa chọn: Âm, Phủ, Không.
- Hậu âm ngậm vào hồi mặc định bằng nửa chiều dày ván; có thể tắt tự động để nhập riêng. Độ ngậm độc lập với độ lùi hậu.
- Mô hình chỉ biểu diễn phần tấm hậu giao vào hồi; chưa khoét rãnh CNC thật trên hồi.
- Tủ hai tầng mặc định **Xà Dưới**. Cấu tạo **Xà Trên** đã sửa theo mẫu Dynamic Component: tấm đáy tầng trên và xà ngang trước/sau tại đường phân tầng.
- Module độc lập phải có hồi đôi tại mối nối.

### Ngăn kéo

- `Số cụm` là 1 hoặc 2 cụm cạnh nhau trong cùng một khoang tủ.
- `Số tầng mỗi cụm` là số mặt/ngăn kéo theo chiều đứng, độc lập với số cụm.
- Hai cụm có một hồi giữa riêng.
- Két âm có diềm hai bên mặc định 50 mm, dày bằng ván.
- Khoảng hông két so với hồi = bản diềm − chiều dày ván. Ví dụ diềm 50, ván 20 thì hông cách hồi 30.
- Độ lùi mặt két âm mặc định 50 mm, được nhập riêng.
- Chiều sâu két là **phủ bì**. Nhập 400 mm với ván 17 mm thì hồi phía sau diềm sâu 383 mm.
- Giá trị chiều sâu két bằng 0 nghĩa là tự lấy chiều sâu khả dụng.
- Hai xà trước/sau nằm ngang ở đáy két, bản mặc định 50 mm.
- Xà đón mặt hộc độc lập, có bật/tắt, chiều cao và độ hạ so với dưới nóc.
- Ba kiểu đáy thùng hộc: `Âm hai bên` (mặc định), `Âm bốn phía`, `Phủ dưới`.
- Hai kiểu đáy âm biểu diễn phần ngậm bằng nửa dày vách; chưa khoét rãnh thật trên vách.
- Mặt ngăn kéo nằm tag `T+_CANH`; thùng ngăn kéo Untagged.
- Ký hiệu mặt hộc dùng Construction Guides để người dùng có thể Delete Guides.

### Cánh

- Cánh ván phẳng và cánh kính khung kim loại.
- Cánh kính gồm đúng hai phần nhẹ: bốn thanh khung và một tấm kính.
- Mặc định: bản khung 20 mm, dày khung 20 mm, kính 5 mm; có preset bản 20/30/40 và nhập tự do.
- Kính nằm giữa chiều dày cánh, tự đổi theo W × H lọt lòng.
- Khung và kính dùng hai vật liệu riêng.
- Tên nhóm: `Khung Kim Loại`, `Kính`.
- Tên vật liệu: `T+ Khung Đen`, `T+ Khung Champagne`, `T+ Khung Inox`, `T+ Kính Trong`, `T+ Kính Trà`, `T+ Kính Xám`.
- Không dùng chữ `Concept` trong tên hiển thị, tên nhóm hoặc tên vật liệu.
- Không dựng rãnh kính, gioăng, nẹp, profile hay liên kết góc.

### Giao diện

- Giao diện dạng menu trái tương tự cách tổ chức của Archiwood để giảm cuộn.
- Các trang: Tổng thể / Thùng tủ / Chia khoang / Cánh tủ / Ngăn kéo.
- Ngăn kéo có bốn tab: Bố trí / Khung két / Mặt hộc / Thùng hộc.
- Thanh Đặt tủ mới / Vẽ 3 điểm / Cập nhật luôn nằm phía dưới.
- `cabinet_dev/redesign_ui.cjs` là generator đang dùng để dựng lại HTML từ `ui_beta1.html`, `menu.css`, `menu.js`. Nếu sửa generator hoặc menu source, chạy lại generator trước khi đóng gói.

## Dynamic Component tham chiếu

- File JSON do plugin exporter tạo: `upload/01-TPlus_DC_Nhieu_component_20260929_224056.json`.
- Công cụ xuất DC: `dc_export_work/`.
- JSON có 6 root, 46 definition, 83 container record và khoảng 574 công thức/thuộc tính.
- Dùng công thức và cấu trúc làm tham chiếu; không sao chép mù giá trị lưu cũ vì một số thuộc tính D không khớp hình học.
- Các hàm DC như `dad()`, `dadx()`, `dady()` không được giả định là Ruby chuẩn.

## Hai tiện ích đã xác nhận và khôi phục (beta 5)

- Dừa xác nhận khôi phục `T+_EXPLODE` (icon `combine.svg`) và `T+_UNTAG` (icon `untag.svg`) trong cùng extension Cabinet; toolbar có 3 nút và submenu Extensions có 3 lệnh.
- EXPLODE chỉ chạy trên Group/Component được chọn. Không còn tự xử lý toàn bộ file khi bỏ chọn.
- EXPLODE giữ tủ cha, rã nhóm lồng trung gian, chuyển component tấm thành group độc lập, xóa chi tiết ẩn và chạy bộ FixIt 101 kế thừa.
- Chỉ loại bỏ hai dictionary DC `dynamic_attributes` và `SU_InstanceSet`. Giữ các thuộc tính `TPlus_Cabinet` của tủ cha, kể cả version; giữ dictionary khác trên tủ cha và tấm khi chuyển sang group. Tên/tag/transformation/material được giữ.
- UNTAG đưa mọi đối tượng con về `model.layers[0]` (Untagged), giữ tag cha, thuộc tính và hình học. Không xóa mục trong danh sách Tags.
- Hai lệnh tách definition dùng chung trước khi xử lý để không ảnh hưởng bản copy ngoài vùng chọn. Có một SketchUp operation; gặp đối tượng khóa hoặc lỗi rã nhóm sẽ abort.
- EXPLODE chọn lại group tủ sau chuyển đổi và đồng bộ bảng tham số. Cập nhật tủ sau đó dựng lại hình và tag theo quy tắc Cabinet, có thể thay sửa tay.
- `utilities_stub.rb`, `test_utilities.rb`, `test_commands.rb` kiểm tra logic và callback. Không coi fixture là bằng chứng native Undo/manifold hoặc FixIt 101.

## Kiểm tra và đóng gói

Chạy từ thư mục gốc dự án. Cài dependency một lần bằng `pnpm install --dir cabinet_dev --frozen-lockfile` hoặc `npm install --prefix cabinet_dev`:

```bash
node cabinet_dev/check_ruby.cjs
node cabinet_dev/redesign_ui.cjs
node cabinet_dev/test_dom.cjs
node cabinet_dev/test_payload.cjs
node cabinet_dev/test_ui.cjs
python cabinet_dev/package_menu.py
```

Dependency Ruby WASM/JSDOM nằm trong `cabinet_dev/node_modules` theo `package.json` và `pnpm-lock.yaml`. Beta 5 đã bỏ đường dẫn `/tmp/tplus_ruby` kế thừa. Playwright lấy từ biến `CODEX_PRIMARY_RUNTIME_NODE_MODULES`; UI test dùng Chrome đã cài, hoặc executable trong `TPLUS_BROWSER_PATH`. Không đóng `node_modules` vào source ZIP.

`check_ruby.cjs` dùng Ruby 3.2 WebAssembly và SketchUp API stub. Nó kiểm tra cú pháp, kích thước, cấu tạo, preset và các lỗi đầu vào. `test_dom.cjs` kiểm tra hành vi giao diện. `test_payload.cjs` bảo đảm tham số cũ vẫn tương thích. `test_ui.cjs` chạy Chromium và chụp ảnh giao diện.

Khi đóng gói, chỉ các file được liệt kê trong `cabinet_dev/package_menu.py` đi vào RBZ. Sau khi tăng phiên bản phải đổi đồng bộ:

- `cabinet_work/tplus_cabinet.rb`
- `cabinet_work/TPlus_Cabinet/main43.rb`
- title/header trong UI hoặc generator
- `cabinet_dev/package_menu.py`
- `cabinet_work/TPlus_Cabinet/HUONG_DAN.txt`

## Cập nhật trực tiếp đã được Dừa cho phép (beta 6)

- Chỉ T+ Cabinet của dự án này. Dừa nghiêm cấm đụng tới plugin khác; không đồng bộ/nạp lại plugin khác và không triển khai sang SketchUp 2023/2024 nếu chưa được yêu cầu riêng.
- Target đã xác định: `C:/Users/PC/AppData/Roaming/SketchUp/SketchUp 2022/SketchUp/Plugins`. Runtime là `TPlus_Cabinet/`, loader là `tplus_cabinet.rb`.
- `sync_sketchup_2022.ps1` dùng danh sách 15 file cố định, kiểm tra target/source không là symlink/junction, kiểm tra loader nhánh 4.3, sao lưu trước khi ghi và đối chiếu SHA256. Không bulk-copy Plugins, không xóa file cũ/dư. Khi lỗi copy, hoàn tác chỉ các file thuộc danh sách vừa ghi.
- Backup/receipt nằm trong `outputs/sketchup_2022_backups/`. `-VerifyOnly` chỉ đọc/so sánh, không ghi file.
- Workflow: sửa nguồn, chạy kiểm tra liên quan, xuất RBZ/source ZIP, chạy `& ./cabinet_dev/sync_sketchup_2022.ps1`, rồi Dừa bấm `Extensions > T+ Cabinet — Tiện ích > T+ — Nạp lại mã (Reload)`.
- Kích hoạt trên beta 4 đang mở: `load 'C:/Users/PC/AppData/Roaming/SketchUp/SketchUp 2022/SketchUp/Plugins/TPlus_Cabinet/reload.rb'`, sau đó `TPlus_Cabinet.reload_extension` trong Ruby Console; không tự điều khiển/đóng tiến trình SketchUp.
- Reload chỉ Kernel.load đúng các file Ruby T+ được liệt kê, không xóa `$LOADED_FEATURES`/`$loaded_files`, không quét/nạp plugin khác, không dựng lại model hay hủy tool của plugin khác.
- Bảng T+ cũ được đóng, đúng observer T+ được gỡ, bảng được mở lại nếu trước đó đang mở. Callback đóng sử dụng reference của chính dialog để không xóa nhầm dialog mới.
- Tái dùng toolbar beta 4 khi kích hoạt nóng; menu/toolbar/handler được đăng ký một lần. Menu Dựng hình giữ vị trí top-level; menu Tiện ích chứa EXPLODE/UNTAG/Reload.
- Extension Manager có thể giữ metadata bản cũ trong phiên đang mở; phiên bản trong bảng T+ là runtime đã Reload. Cần restart nếu đổi bộ nạp/entry point hay cấu trúc class/menu lớn.
- `test_reload.rb` dùng source runtime thật trong filesystem fixture, kiểm tra nâng beta 4, dependency/HTML mới, whitelist, UI không trùng, observer khác giữ nguyên, lỗi syntax/missing giữ bảng cũ. Không coi đây là native SketchUp test.
- Ngày 2026-10-01 đã triển khai beta 6 vào đúng target 2022: 9 file thay đổi, 15 file đối chiếu SHA256 đạt. Receipt/sao lưu: `outputs/sketchup_2022_backups/20261001_111238_a324b521/SYNC_REPORT.json` (trạng thái VERIFIED). Không triển khai plugin khác hoặc bản SketchUp khác.
- Chưa thực thi hai dòng Ruby Console trong SketchUp thực tế. Khi giao việc, yêu cầu Dừa kích hoạt một lần trong mỗi tiến trình SketchUp 2022 đang mở; sau đó dùng menu Reload. Các bộ kiểm tra tự động đều đạt, gồm Ruby/hình học/tiện ích/Reload, DOM, payload và UI Chrome.

## Trạng thái kiểm tra beta 4

Đã đạt kiểm tra tự động:

- Ruby syntax và quy tắc hình học.
- Một/hai cụm ngăn kéo, chiều sâu két phủ bì 400 mm, xà đáy ngang, xà đón độc lập.
- Ba kiểu đáy hộc.
- Hậu ngậm hồi tự động và nhập riêng.
- Cấu tạo Xà Trên.
- Cánh kính, kích thước khung/kính và hai material độc lập.
- Tạo mới, cập nhật đúng đối tượng, preset, payload cũ, ID giao diện, responsive 560×640 và 480×420.

Chưa chạy trực tiếp trong SketchUp 2022/2024. Vì vậy chưa xác nhận bằng native SketchUp kernel về manifold/solid, Undo, vật liệu sau update, công cụ 3 điểm và hành vi khi lưu/mở lại file.

## Trạng thái kiểm tra beta 5

- Đạt Ruby syntax, bộ kiểm tra hình học/tham số/preset cũ và bộ fixture tiện ích mới.
- Đạt DOM, tương thích payload beta 1 và UI Chromium (Chrome cài trên Windows), gồm responsive 560×640 và 480×420.
- Fixture kiểm tra vùng chọn, chuyển group, flatten, chi tiết ẩn, transformation/material, thuộc tính T+ và dictionary khác, bản copy ngoài vùng chọn, UNTAG đệ quy, operation và callback menu/toolbar.
- Chưa có kiểm tra trực tiếp trong SketchUp. Phải thử cả hai tiện ích trên bản copy model, đặc biệt FixIt 101, Undo/Redo và cập nhật tủ sau EXPLODE.

## Việc nên làm tiếp

1. Kích hoạt beta 6/Reload trên SketchUp 2022 bằng Ruby Console rồi chạy bộ thử trong `HUONG_DAN.txt`, gồm toolbar, hai tiện ích và Reload nhiều lần. SketchUp 2024 chỉ thử khi Dừa yêu cầu riêng.
2. Kiểm tra X-Ray các giao điểm: hồi giữa két hai cụm với xà đón, đáy hộc âm, hậu âm với vách đứng, Xà Trên tại đường phân tầng.
3. Kiểm tra tên Outliner, tag và material sau tạo mới, cập nhật, copy tủ rồi cập nhật một bản.
4. Nếu có lỗi native, yêu cầu người dùng gửi ảnh, toàn bộ thông số đang nhập và nội dung Window > Ruby Console.
5. Chỉ sau khi cấu tạo ổn định mới mở rộng tủ bếp, cánh ván lộng kính, cánh inox/profile chi tiết, BOM/CNC.

## Quy tắc làm việc tiếp

- Không tự ý mở rộng sang sản xuất, BOM hoặc CNC ở giai đoạn này.
- Không hỏi lại các quyết định đã ghi ở trên.
- Khi thay đổi kết cấu, thêm kiểm tra có ý nghĩa cho kích thước và quan hệ hình học tương ứng.
- Luôn tạo RBZ mới để Dừa thử, giữ source ZIP đi kèm.
- Không tuyên bố đã chạy SketchUp nếu chỉ chạy API stub.
- Ưu tiên sửa mã trong `cabinet_work` và test/generator trong `cabinet_dev`; không chỉnh các snapshot `*_original`, `*_beta*` trừ khi cần đối chiếu.

## Prompt khởi động nhanh cho Codex

> Hãy đọc `CODEX_HANDOFF.md` và `AGENTS.md`, sau đó kiểm tra trạng thái T+ Cabinet 4.3.0-beta.6. Mã đang chạy nằm trong `cabinet_work`, test và đóng gói nằm trong `cabinet_dev`, Dynamic Component tham chiếu nằm trong `upload`. Chỉ triển khai/nạp lại T+ Cabinet, nghiêm cấm sửa plugin khác. Giữ toàn bộ quyết định kết cấu đã chốt, chạy kiểm tra liên quan và xuất RBZ cùng source ZIP sau mỗi mốc có thể thử; đồng bộ riêng T+ Cabinet vào SketchUp 2022 bằng script đã có.

