# T+ Dim · 1.1.0-beta.2

Plugin chuẩn hóa Dim/Text có sẵn, tạo dim riêng T+ quản lý font và lưu quy chuẩn vào model. Một gói dành cho SketchUp 2022 trở lên trên Windows. Giao diện theo font, màu sáng/tối và icon T+ Cabinet.

## Sử dụng

1. Quét chọn Dim/Text hoặc Group/Component chứa chúng, mở Extensions → T+ Dim.
2. Chọn thông số. Mặc định: font UTM Avo 10 pt, chấm dot, màu #0000FF, tag T+_DIM / T+_TEXT.
3. Bấm ÁP DỤNG QUY CHUẨN. Quy chuẩn được ghi vào model; Ctrl+S lưu cùng file SKP.
4. Khi “Tự chuẩn hóa” đã lưu bật, Dimension/Text mới tạo bằng công cụ thủ công được chuẩn hóa sau khi thao tác vẽ hoàn thành. Không tự đổi các đối tượng cũ ngoài vùng chọn.
5. Mục Dọn Dim/Text có nút xóa Dim, Text hoặc cả hai. Đếm đối tượng và xác nhận trước khi xóa. Luôn quét sâu, bao gồm hidden/tag ẩn. Bỏ qua nhóm khóa.

Lưu quy chuẩn được phép khi chưa chọn đối tượng. Bỏ “Tự chuẩn hóa” rồi Áp dụng để tắt trong file. Bỏ “Lưu quy chuẩn” chỉ áp dụng vùng chọn và giữ quy chuẩn đã lưu trước đó. Không tự ghi đè SKP trên đĩa.

## Dim riêng T+

UTM Avo, Roboto, Roboto Condensed đều có bốn kiểu thường/đậm/nghiêng/đậm nghiêng. Dữ liệu nét chữ được đóng gói thành lưới tam giác; dựng trực tiếp thành chữ phẳng trong model, không tra font hệ thống, không cần cài font Windows. Cỡ chữ là chiều cao vật lý: 10 pt ≈ 3,53 mm; thay đổi theo mức zoom.

Dim native giữ nguyên trong cùng ngữ cảnh, được ẩn làm nguồn đo và giữ liên kết hình học sẵn có. Group T+ là phần hiển thị; thông số font/diện mạo lưu trên từng dim. Sau transaction, plugin kiểm tra nguồn và dựng lại khi điểm đo, offset, chữ hoặc hình học radial thay đổi. Nội dung nhập đè được giữ trừ khi bật “Trả chữ dim về giá trị đo thực”. Liên kết vốn không có hoặc đã mất của dim gốc không được tự suy đoán.

Dim T+ dùng chữ phẳng theo mặt phẳng dim, không tự xoay theo camera. Muốn chữ luôn theo màn hình, chọn dạng native. Bỏ “Dùng dim riêng T+” rồi Áp dụng sẽ trả nguồn về native. Text có leader có thể dùng chữ T+; Text gắn cố định vào viewport giữ dạng native để giữ vị trí màn hình. SU 2022–2026.1 chỉnh font Text viewport qua Model Info; từ 2026.2 dùng Text#font= khi API có sẵn. Các nút Model Info dành cho chế độ native.

Xóa bằng plugin sẽ xóa cả nguồn ẩn và hình T+ của đối tượng đã chọn. Nếu người dùng xóa riêng hình T+ bằng công cụ SketchUp, nguồn sẽ hiện lại sau transaction. Nếu xóa nguồn, hình T+ được giữ và đánh dấu mất liên kết. Khi cần sao chép, sao chép nhóm cha chứa cả nguồn và hình; bản sao riêng Group hiển thị sẽ không được phép sửa/xóa nhầm nguồn của bản gốc.

## Phạm vi

Group/Component dùng chung được tách riêng trước khi cập nhật/xóa, kể cả cấp lồng nhau. Không chỉnh trong edit context thuộc definition dùng chung: đóng edit và chọn nhóm cha. Nhóm khóa được bỏ qua. Khoảng cách chỉ áp dụng dim thẳng, tính theo mm toàn model qua transform; hướng đặt giữ nguyên. Đổi đơn vị là lựa chọn riêng cho toàn model, mặc định tắt khi mở dialog; chuyển chiều dài sang Decimal.

Quy chuẩn và phần hiển thị đã dựng lưu trong SKP. Máy khác vẫn xem được chữ dạng hình học; phải nạp plugin để tự cập nhật số đo và dùng quy chuẩn khi vẽ mới. Chưa tối ưu cho file có hàng nghìn dim; từng transaction kiểm tra các dim T+ trong model.

## Toolbar và nạp bản mới

Plugin giữ tên toolbar “T+ Dim”; không gọi Show/Restore/Hide lúc khởi động hoặc nạp lại. Có thể bật chủ động bằng Extensions → Hiện toolbar T+ Dim. Không chỉnh registry của toolbar, bố cục toolbar hoặc plugin khác; tùy chọn T+ Dim chỉ lưu dưới khóa riêng của plugin.

Không cần khởi động lại SketchUp để nạp bản beta này. Trong Ruby Console chạy đúng một lệnh chỉ nạp mã T+ Dim:

```ruby
load 'C:/Users/PC/AppData/Roaming/SketchUp/SketchUp 2022/SketchUp/Plugins/TPlus_Dim/reload.rb'
```

Các lần sau có thể dùng Extensions → Nạp lại T+ Dim. Script giữ lại toolbar/command đang có, dừng rồi gắn lại observer riêng của plugin. Với SU 2023+ cài RBZ qua Extension Manager; chưa triển khai vào các phiên bản khác trên máy.

## Kiểm tra và giới hạn bản beta

Ruby syntax và fixture qua Ruby WASM 3.2: chuyển/reapply/khôi phục native, dựng glyph, phát hiện thay đổi số đo, quy chuẩn model, queue sau transaction/Undo, blue/dot/tag, shared/nested isolation, xóa cặp và chống vùng chọn cũ. Fixture không mô phỏng hoàn chỉnh kernel SketchUp.

Chrome headless: đủ 12 file font, payload, confirmation xóa, token cũ, đổi file, lưu quy chuẩn khi vùng chọn trống, theme và layout 580×680 / 470×530. Sinh dữ liệu font: kiểm tra diện tích tam giác bằng diện tích glyph, gồm tiếng Việt.

**Chưa kiểm chứng native beta 2**: dựng mặt chữ rất nhỏ, điểm đo thực khi Stretch/Scale, dim radial, Save/Open và Undo/Redo trong SU2022/2024. Không mở/khởi động lại SketchUp trong lần nâng này để giữ bố cục toolbar hiện tại. `dev/native_smoke.rb` dành cho model kiểm tra riêng, chỉ chạy chủ động; không lấy test mô phỏng làm bằng chứng native.

## Phát triển

- `node dev/check_ruby.cjs`: syntax, engine/profile/custom fixture và toolbar startup/reload.
- `node dev/test_ui.cjs`: browser UI/payload/font/layout, chỉ mở Chrome headless riêng.
- `dev/build_fonts.py`: fontTools + Shapely 2.1 trong dev/vendor; nguồn font và SHA256 tại outputs/FONT_PROVENANCE.json. Runtime không cần Python/Node/dependency này.
- `dev/package.py`: RBZ và source ZIP, loại dev/vendor.
- `dev/deploy.ps1`: đồng bộ đúng danh sách file T+ vào SU2022, sao lưu và kiểm tra SHA256. Không đụng T+ Cabinet.

API tham khảo: [Dimension](https://ruby.sketchup.com/Sketchup/Dimension.html), [DimensionLinear](https://ruby.sketchup.com/Sketchup/DimensionLinear.html), [Text](https://ruby.sketchup.com/Sketchup/Text.html).
