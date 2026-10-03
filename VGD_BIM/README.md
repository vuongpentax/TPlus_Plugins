# VGD BIM Lite v0.1.0-alpha

Plugin **VGD_BIM** cho SketchUp 2022+ / Windows. Phase 1: Core, Intake, Mapping và Validation. Namespace `VGD::BIM`; dữ liệu Group/ComponentInstance lưu trong dictionary `VGD_BIM` của file SKP.

## Cài đặt

Trong SketchUp, mở **Extensions → Extension Manager → Install Extension**, chọn `VGD_BIM_Lite_v0.1.0-alpha.rbz`. Khởi động lại SketchUp. Menu: **Extensions → VGD → BIM Lite**. Có toolbar hai nút và context menu cho Group/Component.

Hoặc chạy `dev/deploy.ps1` để cài nguồn runtime vào Plugins của SketchUp 2022. Script chỉ copy file plugin này, sao lưu file cũ và kiểm tra SHA256. `-PluginRoot` chọn bản SketchUp khác; `-VerifyOnly` kiểm tra cài đặt.

## Sử dụng

1. Chọn Group/Component → **BIM Information**. Chọn preset hoặc bật checkbox các field cần đổi → **APPLY**. Field không bật giữ nguyên; field text bật và để trống được xóa. Các đối tượng khóa được bỏ qua. **CLEAR VGD DATA** chỉ xóa metadata.
2. **Scan Model** đọc cả model, gồm nested instances, faces, edges và material kế thừa. Component report đếm occurrence thực tế, bao gồm shared nested component. W/D/H theo trục local sau transformation, dùng mm.
3. **Map / Convert Model** gom theo definition và material. Gợi ý dựa trên VGD đã có → rule → definition name → instance name → tag → material. Keyword chỉ là gợi ý. **Edit / Apply** → chỉnh field → **Preview Convert** → **Confirm Convert** mới ghi dữ liệu. Native/mapped/manual data hiện có không bị convert ghi đè.
4. **Convert Selection** áp dụng workflow preview cho Group/Component đang chọn. Mỗi batch ghi metadata trong một Undo operation. Không sửa geometry, tên, tag hoặc material.
5. **Validate Selection / Model** kiểm tra schema, required fields, enum và unit/method. Click kết quả để mở editing context đúng occurrence rồi chọn/zoom entity. Entity bị xóa sau scan được báo và yêu cầu refresh.
6. **Mapping Rules** chỉnh JSON, Export/Import giữa model. Rules lưu JSON trong dictionary model `VGD_BIM_RULES`, hỗ trợ Undo và tồn tại cùng SKP. Material mapping chỉ ghi rule, không gán BIM data vào raw face.

## Ý nghĩa dữ liệu và giới hạn

- `SOURCE`: `VGD`, `MAPPED`, `RAW`, `MANUAL`. Source lưu trong metadata `_source`, tách khỏi schema nghiệp vụ v1.
- Raw faces/edges/material area là **RAW QUANTITY / RAW GEOMETRY**, chưa phải BOQ. Front area và back-painted area tách riêng để tránh cộng hai mặt thành một khối lượng. Area là diện tích hình học, chưa trừ phần che khuất/hao hụt.
- Nested entity trong shared component definition dùng chung metadata giữa các parent occurrences. Preview nói rõ số entity được ghi và số occurrences bị ảnh hưởng. Plugin không make_unique để giữ nguyên geometry. Nếu bất kỳ occurrence của entity có ancestor khóa, convert bỏ qua entity đó.
- `Scanner.all_entities` / `all_bim_entities` trả về entity duy nhất để đọc/ghi; `scan_model` / `scan_selection` trả occurrence records `{entity, path, transform, material, locked}`. Quantity tương lai phải dùng occurrence records để không thiếu repeated nested instances.
- `Geometry.dimensions(entity, record[:transform])` đo đúng nested occurrence. Không truyền transform thì dùng transformation của instance trong parent context; vì shared nested entity có nhiều đường dẫn, không tự suy đoán parent occurrence.
- W/D/H là độ dài bounding box local theo các trục đã transform, không phải world-aligned bounding box khi quay. Đây là kích thước thích hợp để nhận diện đồ nội thất.
- Scan chạy theo từng đợt qua timer, không scan toàn model khi selection thay đổi. Tổng hợp báo cáo diễn ra sau scan; model rất lớn vẫn có thể cần thời gian ở bước tổng hợp. Refresh hoặc đóng panel hủy scan hiện tại.
- Preset mặc định không gán description: người dùng cần nhập mô tả để đạt ready khi include_boq=true. Item type là chuỗi mở rộng.
- Plugin chưa ký phát hành; tuân theo chính sách loading extensions hiện tại của SketchUp.

Không triển khai Quantity hoàn chỉnh, BOQ, Excel, Pricing, IFC, room detection hoặc Cabinet BOM trong phase này. Không sửa VGD Cabinet.

## API

```ruby
VGD::BIM::Data.update(entity, category: 'furniture', item_type: 'wardrobe',
  description: 'Tủ áo Master', unit: 'set', quantity_method: 'assembly')
VGD::BIM::Data.get(entity, :category)
VGD::BIM::Data.read(entity)
VGD::BIM::Data.has_data?(entity)
VGD::BIM::Data.valid?(entity)
VGD::BIM::Data.clear(entity)

VGD::BIM::Scanner.scan_model.each do |record|
  next unless VGD::BIM::Data.has_data?(record[:entity])
  dimensions = VGD::BIM::Geometry.dimensions(record[:entity], record[:transform])
end
```

`Data.update/set/clear` tạo operation riêng. API batch nội bộ dùng `Data.transaction { Data.write(...) }` để chỉ có một Undo; tránh lồng operations. UI chỉ truy cập BIM attributes qua Data API.

## Kiểm thử

- `node dev/check_ruby.cjs`: compile Ruby và chạy test Core/affine geometry/scanner bằng Ruby WASM 3.2; simulation không thay thế SketchUp kernel. Dependency dùng lại dev toolchain trong repository Cabinet; runtime plugin không phụ thuộc thư viện ngoài.
- `dev/test_ui.cjs`: Playwright + Edge headless; biến `VGD_PLAYWRIGHT_MODULE` trỏ tới Playwright nếu không cài local.
- `dev/native_smoke.rb`: chạy trong **tiến trình SketchUp mới, model trống** qua `-RubyStartup`, hoặc `load` trong Ruby Console của model trống. Refuse model có geometry/path để bảo vệ file đang làm. Tạo model test theo đặc tả, kiểm tra Undo, geometry, nested selection, save/reopen, ghi `outputs/native_SU22/native_report.json` và SKP test.
- `dev/package.py`: tạo RBZ, kiểm tra từng byte trong archive và ghi SHA256.

Đọc `VALIDATION.md` để biết phần nào đã thực sự được kiểm chứng trong bản alpha này.
