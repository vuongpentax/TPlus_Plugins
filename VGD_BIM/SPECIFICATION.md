# VGD BIM Lite v0.1
## Master Technical Specification for Codex

---

# 1. Mục tiêu

Xây dựng **VGD BIM Lite cho SketchUp**.

Đây không phải hệ BIM đầy đủ như Revit hoặc Archicad.

Mục tiêu của VGD BIM Lite là tạo một **lớp dữ liệu chuẩn hóa cho SketchUp**, để có thể:

- sử dụng với model được dựng theo chuẩn VGD,
- sử dụng với file SketchUp của đối tác,
- đọc model cũ chưa có dữ liệu VGD,
- chuẩn hóa model bên ngoài,
- chuẩn bị nền cho bóc khối lượng,
- chuẩn bị nền cho BOQ và Excel,
- dùng chung dữ liệu giữa các plugin VGD trong tương lai.

Pipeline tổng thể:

```text
SKETCHUP MODEL
      ↓
VGD BIM LITE
      ↓
VGD DATA
      ↓
VGD QUANTITY
      ↓
BOQ
      ↓
EXCEL / PRICING
```

Trong phase hiện tại chỉ làm:

```text
VGD BIM Lite Core
+
VGD Intake
+
Validation
```

Chưa làm VGD Quantity hoàn chỉnh.

---

# 2. Tên hệ thống

Tên chính thức:

```text
VGD BIM Lite
```

Namespace Ruby:

```ruby
module VGD
  module BIM
  end
end
```

Không sử dụng các tên cũ:

```text
T+
TPlus
TPLUS
```

trong namespace, UI, plugin mới, schema hoặc attribute dictionary.

---

# 3. Nguyên tắc kiến trúc

VGD BIM Lite không phải một plugin chỉ dùng cho model VGD.

Nó phải đóng vai trò:

```text
Lớp chuẩn hóa dữ liệu giữa mọi SketchUp model và hệ sinh thái VGD.
```

Kiến trúc:

```text
VGD BIM Lite
│
├── Core
│   ├── Schema
│   ├── Data API
│   ├── Geometry
│   ├── Scanner
│   └── Validator
│
├── Intake
│   ├── Raw Scanner
│   ├── Detection
│   ├── Mapping
│   ├── Mapping Rules
│   └── Converter
│
└── UI
    ├── BIM Information
    ├── Scan Model
    ├── Map / Convert
    └── Validation
```

VGD Intake không phải plugin độc lập.

Nó là module của VGD BIM Lite và dùng chung:

```text
Schema
Data API
Scanner
Validator
UI system
```

---

# 4. Ba trạng thái dữ liệu

VGD BIM Lite phải phân biệt rõ 3 loại dữ liệu.

## 4.1 VGD Native

Đối tượng đã có:

```text
Attribute Dictionary = VGD_BIM
```

Đây là nguồn dữ liệu đáng tin cậy nhất.

Priority:

```text
1
```

---

## 4.2 Mapped Data

Model bên ngoài được user mapping và xác nhận.

Sau khi Convert, plugin ghi VGD_BIM attributes.

Priority:

```text
2
```

Sau khi convert xong có thể coi entity là VGD-compatible.

---

## 4.3 Raw Data

Dữ liệu đọc trực tiếp từ model:

```text
Material
Tag
Instance Name
Definition Name
Geometry
Bounding Box
Face Area
Edge Length
```

Raw Data không được coi là BIM Data chính thức.

Dùng để:

```text
Preview
Scan
Suggest
Raw Quantity
Mapping
```

Priority:

```text
3
```

---

# 5. Priority Rule

Khi sau này Quantity xử lý entity:

```text
VGD Native
    ↓
Mapped VGD Data
    ↓
Raw / Heuristic
```

Không cho heuristic override dữ liệu VGD mà user đã xác nhận.

---

# 6. Attribute Dictionary

Dictionary chính:

```ruby
"VGD_BIM"
```

Dùng SketchUp Attribute Dictionary.

Không sử dụng SketchUp Classification.

Không bắt buộc Dynamic Components.

Không phụ thuộc plugin bên ngoài.

---

# 7. VGD BIM Schema v1

Các field:

```text
schema_version

category
item_type

code
description

unit
quantity_method

zone
floor

include_boq

finish_code

manufacturer
model_number

note
```

---

# 8. schema_version

Type:

```text
Integer
```

Default:

```text
1
```

---

# 9. category

Allowed values:

```text
architecture
finish
furniture
electrical
equipment
plumbing
hvac
other
```

Không dùng category quá chi tiết.

---

# 10. item_type

String.

Ví dụ:

```text
wall
floor
ceiling

paint
tile
stone
wood_floor
glass

wardrobe
kitchen_base
kitchen_upper
tv_cabinet
lavabo_cabinet
bed
table
chair

light
switch
socket

sanitary
appliance

air_conditioner
```

Không hard-code item_type thành danh sách đóng tuyệt đối.

Phải dễ mở rộng.

---

# 11. code

String.

Ví dụ:

```text
PA-01
FUR-WD-01
EL-SOC-01
EQ-KIT-01
```

Có thể để trống.

Code là mã nghiệp vụ.

Không dùng SketchUp Entity ID làm Code.

---

# 12. description

String.

Ví dụ:

```text
Sơn nước tường
Tủ áo Master
Ổ cắm đôi
Downlight D90
```

Nếu:

```text
include_boq = true
```

description là required field.

---

# 13. unit

Internal values:

```text
m2
m
m3
pcs
set
lot
kg
none
```

UI có thể hiển thị:

```text
m²
md
m³
cái
bộ
lô
kg
-
```

Data bên trong vẫn dùng internal value.

---

# 14. quantity_method

Allowed values:

```text
area
length
volume
count
assembly
manual
```

---

## area

Dùng cho:

```text
paint
tile
stone
floor finish
wall finish
ceiling finish
glass
```

---

## length

Dùng cho:

```text
skirting
LED strip
trim
profile
moulding
```

---

## volume

Dùng cho:

```text
concrete
bulk material
```

Không phải ưu tiên trong v0.1.

---

## count

Dùng cho:

```text
light
switch
socket
sanitary equipment
appliance
loose furniture
```

---

## assembly

Dùng cho:

```text
wardrobe
kitchen cabinet
door
lavabo cabinet
custom furniture
```

Sau này có thể lấy:

```text
Width
Depth
Height
Count
```

---

## manual

Quantity do user nhập thủ công trong phase sau.

---

# 15. zone

String.

Ví dụ:

```text
LIVING
DINING
KITCHEN
MASTER
BEDROOM_01
BEDROOM_02
WC_MASTER
BALCONY
```

v0.1:

```text
manual assign only
```

Chưa cần tự detect Room.

---

# 16. floor

String.

Ví dụ:

```text
L01
L02
L03
ROOF
BASEMENT
```

v0.1 nhập thủ công.

---

# 17. include_boq

Boolean:

```text
true
false
```

Default:

```text
true
```

Dùng để bỏ qua:

```text
decor
proxy
reference
helper object
temporary geometry
```

---

# 18. finish_code

String.

Ví dụ:

```text
PA-01
ST-01
TL-02
WD-03
```

Dùng để liên kết finish schedule trong tương lai.

---

# 19. manufacturer

String.

Ví dụ:

```text
Schneider
Dulux
Teka
Hafele
```

Optional.

---

# 20. model_number

String.

Ví dụ:

```text
AvatarOn
RVU 20046 GBK
```

Optional.

---

# 21. note

String.

Free text.

---

# 22. Entity Support

Core v0.1 hỗ trợ VGD Attributes trực tiếp trên:

```ruby
Sketchup::Group
Sketchup::ComponentInstance
```

Không bắt buộc ghi VGD_BIM vào raw Face hoặc Edge.

Raw Face / Edge vẫn được VGD Intake và VGD Quantity đọc riêng.

---

# 23. SketchUp Data và VGD Data phải tách nhau

VGD không được dùng Tag làm BIM database.

Tag dùng cho:

```text
visibility
organization
display
```

Material dùng cho:

```text
surface material
finish detection
quantity support
```

Instance Name dùng cho:

```text
human-readable identification
```

VGD_BIM mới là dữ liệu BIM chuẩn.

---

# 24. Data API

Tạo:

```ruby
VGD::BIM::Data
```

API ví dụ:

```ruby
VGD::BIM::Data.get(entity, :category)

VGD::BIM::Data.set(entity, :category, "furniture")

VGD::BIM::Data.read(entity)

VGD::BIM::Data.update(entity, hash)

VGD::BIM::Data.clear(entity)

VGD::BIM::Data.has_data?(entity)

VGD::BIM::Data.valid?(entity)
```

UI không được thao tác AttributeDictionary trực tiếp.

Tất cả read/write qua Data API.

---

# 25. Geometry API

Tạo:

```ruby
VGD::BIM::Geometry
```

Methods tối thiểu:

```ruby
width(entity)
depth(entity)
height(entity)

dimensions(entity)

face_area(entity)
edge_length(entity)
```

Output dimension dùng mm.

Area có thể chuẩn hóa sang m² khi cần.

Length có thể chuẩn hóa sang m.

---

# 26. Transformation

Phải hỗ trợ:

```text
translation
rotation
scale
mirrored instance
nested transform
```

Không giả định entity nằm tại model root.

Không giả định component chưa scale.

---

# 27. Nested Entities

Scanner phải recursive.

Ví dụ:

```text
Apartment
  └─ Master Bedroom
       └─ Furniture
            └─ Wardrobe
```

VGD Scanner phải tìm được Wardrobe.

Không chỉ scan:

```ruby
model.entities
```

---

# 28. Scanner

Tạo:

```ruby
VGD::BIM::Scanner
```

Methods dự kiến:

```ruby
all_entities
all_bim_entities

by_category(category)
by_item_type(item_type)
by_zone(zone)
by_floor(floor)

scan_selection
scan_model
```

Scanner phải tránh duplicate processing của component definitions.

Cần phân biệt:

```text
Definition
Instance
Nested instance
```

---

# 29. VGD BIM Information Panel

Sử dụng:

```ruby
UI::HtmlDialog
```

Không dùng:

```ruby
UI::WebDialog
```

Panel:

```text
VGD BIM INFORMATION
```

Fields:

```text
Category
Item Type

Code
Description

Unit
Quantity Method

Zone
Floor

Finish Code

Manufacturer
Model Number

Include in BOQ

Note
```

Buttons:

```text
APPLY
CLEAR VGD DATA
```

---

# 30. SketchUp Data Read-only

Trong Information Panel hiển thị thêm:

```text
SKETCHUP DATA
```

Ví dụ:

```text
Entity Type
Component

Instance Name
Tủ áo Master

Definition Name
WARDROBE_MASTER

Tag
FURNITURE

Material
Oak Veneer

Dimensions
W 3200
D 600
H 2700
```

Các dữ liệu này chỉ read-only.

Không tự ghi ngược vào VGD_BIM.

---

# 31. Multi-selection Edit

Phải hỗ trợ chọn nhiều Group/Component.

Ví dụ:

```text
Selected Objects: 28
```

Apply:

```text
category = electrical
item_type = socket
unit = pcs
quantity_method = count
```

cho toàn bộ selection.

---

# 32. Không overwrite ngoài ý muốn

Multi-edit cần hỗ trợ:

```text
Keep Existing
Set Value
Clear Value
```

Hoặc đơn giản hơn:

```text
☑ Update Category
☐ Update Code
☐ Update Description
☑ Update Zone
```

Chỉ field được enable mới update.

---

# 33. Preset System

Chuẩn bị preset architecture từ đầu.

Không hard-code preset sâu trong UI.

Preset có thể dùng Ruby hash v0.1.

Sau này chuyển JSON.

Preset ví dụ:

```ruby
{
  name: "Socket",
  category: "electrical",
  item_type: "socket",
  unit: "pcs",
  quantity_method: "count",
  include_boq: true
}
```

---

# 34. Preset mặc định

## Wardrobe

```text
category = furniture
item_type = wardrobe
unit = set
quantity_method = assembly
include_boq = true
```

## Kitchen Base

```text
category = furniture
item_type = kitchen_base
unit = set
quantity_method = assembly
include_boq = true
```

## Kitchen Upper

```text
category = furniture
item_type = kitchen_upper
unit = set
quantity_method = assembly
include_boq = true
```

## Socket

```text
category = electrical
item_type = socket
unit = pcs
quantity_method = count
include_boq = true
```

## Switch

```text
category = electrical
item_type = switch
unit = pcs
quantity_method = count
include_boq = true
```

## Light

```text
category = electrical
item_type = light
unit = pcs
quantity_method = count
include_boq = true
```

## Wall Paint

```text
category = finish
item_type = paint
unit = m2
quantity_method = area
include_boq = true
```

---

# 35. VGD Intake

VGD Intake dùng để xử lý:

```text
model đối tác
model cũ
downloaded model
model chưa theo chuẩn VGD
dirty model
```

Pipeline:

```text
MODEL
↓
SCAN
↓
RAW DATA
↓
DETECTION
↓
MAPPING
↓
CONVERT
↓
VGD DATA
```

---

# 36. Scan Model

Menu:

```text
Scan Model
```

Scan:

```text
Groups
Components
Definitions
Materials
Tags
Instance Names
Definition Names
Bounding Boxes
VGD Attributes
Raw Faces
```

Kết quả ví dụ:

```text
VGD MODEL SCAN

Groups                 214
Component Instances    486
Definitions             73
Materials               54
Tags                    32

VGD Objects            148
Unclassified Objects   552

VGD Coverage           21%
```

Entity chưa có VGD không phải ERROR.

Status:

```text
UNCLASSIFIED
```

---

# 37. Raw Component Report

Model chưa convert vẫn phải đọc được:

```text
Definition Name
Instance Name
Instance Count
Tag
Material
W
D
H
```

Ví dụ:

```text
DOUBLE_SOCKET
Instances = 28
```

---

# 38. Raw Material Report

Model chưa có VGD vẫn phải đọc Material Area.

Ví dụ:

| Material | Raw Face Area |
|---|---:|
| Son Tuong | 184.52 m² |
| Go San | 72.24 m² |
| Marble | 28.65 m² |

Phải ghi rõ:

```text
RAW QUANTITY
```

Không gọi đây là BOQ chuẩn.

---

# 39. Raw Geometry

Nếu file đối tác chỉ có raw faces:

```text
Faces
Edges
Materials
```

VGD Intake có thể đọc:

```text
Face Area
Edge Length
Material
```

Nhưng phải đánh dấu:

```text
RAW GEOMETRY
```

Không tự group geometry.

Không tự biến raw face thành BIM Object.

---

# 40. Detection

VGD Intake có thể suggest classification dựa trên:

```text
VGD Attribute
Mapping Rule
Definition Name
Instance Name
Tag
Material
Geometry
```

Priority:

```text
1. VGD_BIM
2. Mapping Rules
3. Definition Name
4. Instance Name
5. Tag
6. Material
7. Geometry
```

---

# 41. Keyword Detection

Keyword chỉ dùng để suggest.

Ví dụ:

```text
socket
outlet
ổ cắm
o cam
ocam
```

suggest:

```text
Electrical
Socket
pcs
Count
```

Ví dụ:

```text
switch
công tắc
cong tac
```

suggest:

```text
Electrical
Switch
pcs
Count
```

Ví dụ:

```text
wardrobe
closet
tu ao
tủ áo
```

suggest:

```text
Furniture
Wardrobe
set
Assembly
```

Không auto-convert silently.

---

# 42. Confidence

Mỗi suggestion nên có confidence:

```text
HIGH
MEDIUM
LOW
```

hoặc:

```text
0–100%
```

Ví dụ:

```text
Definition: DOUBLE_SOCKET
Tag: ELECTRICAL

Suggestion:
Electrical > Socket

Confidence:
HIGH
```

Geometry-only inference:

```text
LOW
```

---

# 43. Group Mapping

Không bắt user map từng instance.

Ví dụ:

```text
Definition:
DOUBLE_SOCKET

Instances:
42
```

UI hiển thị một row.

User map một lần.

Apply cho tất cả instance của definition đó nếu user chọn.

---

# 44. Mapping UI

Bảng ví dụ:

| Source | Instances | Suggested Type | Method | Status |
|---|---:|---|---|---|
| O_CAM_DOI | 28 | Electrical / Socket | Count | Ready |
| CT_2N | 12 | Electrical / Switch | Count | Ready |
| TU_AO | 4 | Furniture / Wardrobe | Assembly | Review |
| SON_TUONG | — | Finish / Paint | Area | Review |

Actions:

```text
Edit
Apply
Ignore
Convert
```

---

# 45. Mapping Rules

Sau khi user xác nhận mapping:

```text
O_CAM_DOI
```

→

```text
category = electrical
item_type = socket
unit = pcs
quantity_method = count
```

có thể lưu thành Mapping Rule.

Lần sau gặp nguồn giống nhau plugin tự suggest rule.

---

# 46. Mapping Rule Structure

Ví dụ:

```ruby
{
  source_type: "definition_name",
  source_value: "O_CAM_DOI",

  category: "electrical",
  item_type: "socket",
  unit: "pcs",
  quantity_method: "count"
}
```

Rules nên lưu JSON.

Không hard-code toàn bộ rule trong Ruby.

---

# 47. Material Mapping

Cho phép:

```text
Material:
SON TUONG TRANG
```

map thành:

```text
category = finish
item_type = paint
description = Sơn nước tường
unit = m2
quantity_method = area
finish_code = PA-01
```

Material Mapping không bắt buộc ghi VGD_BIM vào từng Face.

Có thể lưu Mapping Rule riêng.

---

# 48. Convert to VGD

Sau khi user xác nhận:

```text
Convert
```

plugin ghi:

```text
VGD_BIM
```

Attributes vào:

```text
Group
ComponentInstance
```

Không thay đổi geometry.

Không:

```text
explode
regroup
move
rotate
scale
rename
change tag
change material
```

---

# 49. Convert Preview

Trước khi convert:

```text
PREVIEW

42 objects will be updated.

Category:
Electrical

Item Type:
Socket

Unit:
pcs

Quantity Method:
Count

Geometry will NOT be changed.
```

User xác nhận rồi mới ghi attributes.

---

# 50. Convert Selection

Cho phép:

```text
Select objects in SketchUp
→ VGD Convert Selection
```

Rồi gán:

```text
Category
Item Type
Unit
Quantity Method
Zone
Floor
```

---

# 51. Batch Convert

Cho phép:

```text
Definition:
DOUBLE_SOCKET

Convert All Instances
```

Ví dụ:

```text
42 instances
```

gán trong một operation.

---

# 52. Undo

Mọi operation ghi dữ liệu phải support Undo.

Ví dụ:

```ruby
model.start_operation("VGD BIM Update", true)
```

và:

```ruby
model.commit_operation
```

Một batch convert chỉ tạo một Undo step.

---

# 53. Validator

Tạo:

```ruby
VGD::BIM::Validator
```

Validate:

```text
Selection
Model
```

---

# 54. Required Fields

Nếu:

```text
include_boq = true
```

required:

```text
category
item_type
description
unit
quantity_method
```

Optional:

```text
code
zone
floor
finish_code
manufacturer
model_number
note
```

---

# 55. Validation Rules

Các lỗi cơ bản:

```text
Missing Category

Missing Item Type

Missing Description

Missing Unit

Missing Quantity Method
```

Mismatch:

```text
quantity_method = area
unit != m2
```

```text
quantity_method = length
unit != m
```

```text
quantity_method = volume
unit != m3
```

```text
quantity_method = count
unit not in pcs/set/lot
```

---

# 56. Validation Severity

Dùng:

```text
ERROR
WARNING
INFO
```

Ví dụ:

```text
ERROR
Missing Unit
```

```text
WARNING
Missing Code
```

```text
INFO
Zone not assigned
```

---

# 57. Validation Results UI

Ví dụ:

```text
VGD BIM VALIDATION

Objects Scanned: 428

Valid: 386
Warnings: 31
Errors: 11
```

List:

```text
[ERROR]
Tủ áo Master

Missing Unit
```

---

# 58. Click Result → Select Entity

Đây là requirement bắt buộc.

Click row validation:

```text
→ SketchUp selection clear
→ select target entity
→ optionally zoom to entity
```

Nếu entity không còn tồn tại thì handle gracefully.

---

# 59. Status Indicator

Information panel hiển thị:

```text
VGD READY
```

hoặc:

```text
INCOMPLETE
```

hoặc:

```text
ERROR
```

Dựa trên Validator.

---

# 60. Dirty Model Support

Scanner không được crash với:

```text
Unnamed Group
Default Tag
Missing Material
Nested Components
Scaled Components
Mirrored Components
Exploded Faces
Duplicated Definitions
Deep Nesting
Empty Groups
Locked Groups
```

---

# 61. Reliability / Data Source

Chuẩn bị field hoặc runtime metadata:

```text
SOURCE
```

Possible values:

```text
VGD
MAPPED
RAW
MANUAL
```

Không nhất thiết ghi source vào mọi entity trong v0.1.

Nhưng architecture phải support.

Sau này Excel có thể biết quantity đến từ đâu.

---

# 62. Không khóa SketchUp file

File sau khi dùng VGD BIM Lite vẫn là file SketchUp bình thường.

Người không cài VGD vẫn:

```text
mở file được
edit geometry được
thấy material
thấy tag
thấy component
```

Chỉ không đọc được VGD metadata bằng UI.

---

# 63. Menu

Menu:

```text
Extensions
└─ VGD
   └─ BIM Lite
      ├─ BIM Information
      ├─ Scan Model
      ├─ Map / Convert Model
      ├─ Convert Selection
      ├─ Validate Selection
      ├─ Validate Model
      ├─ Mapping Rules
      └─ About
```

---

# 64. Context Menu

Right-click Group/Component:

```text
VGD BIM Information
```

Optional:

```text
Convert to VGD
```

---

# 65. Toolbar

v0.1 chỉ cần:

```text
BIM Information
Scan / Validate
```

Không tạo toolbar quá nhiều icon.

---

# 66. File Structure

Đề xuất:

```text
VGD_BIM_Lite/

vgd_bim_lite.rb

vgd_bim_lite/
  loader.rb

  core/
    schema.rb
    data.rb
    geometry.rb
    scanner.rb
    validator.rb

  intake/
    raw_scanner.rb
    detector.rb
    mapping.rb
    mapping_rules.rb
    converter.rb

  ui/
    information_dialog.rb
    scan_dialog.rb
    mapping_dialog.rb
    validation_dialog.rb

  html/
    information/
      index.html
      app.js
      style.css

    scan/
      index.html
      app.js
      style.css

    mapping/
      index.html
      app.js
      style.css

    validation/
      index.html
      app.js
      style.css

  config/
    presets.json
    mapping_rules.json

  assets/
    icons/
```

Có thể điều chỉnh cấu trúc nếu cần, nhưng phải giữ module separation.

---

# 67. SketchUp Compatibility

Target:

```text
SketchUp 2022+
Windows
```

Ruby phải tương thích với Ruby version trong SketchUp 2022.

Không sử dụng language feature không support.

---

# 68. UI

Ưu tiên:

```text
compact
clean
fast
easy to understand
```

Không cần UI phức tạp.

Không ưu tiên animation.

Dark/light compatible nếu làm được đơn giản.

---

# 69. Performance

Không scan toàn model mỗi khi user click entity.

Information panel chỉ đọc selection hiện tại.

Full scan chỉ chạy khi user:

```text
Scan Model
Validate Model
```

Large models phải tránh freeze lâu nhất có thể.

---

# 70. Error Handling

Plugin không được crash nếu entity lỗi.

Logging prefix:

```text
[VGD BIM]
```

Ví dụ:

```text
[VGD BIM] Failed to inspect entity 12345
```

Không spam Ruby Console vô hạn.

---

# 71. Không thay đổi Geometry

VGD BIM Lite Core tuyệt đối không tự:

```text
move geometry
scale
rotate
explode
regroup
delete
rename object
assign material
change tag
```

Chỉ đọc geometry và ghi VGD metadata.

---

# 72. VGD Cabinet Compatibility

Không sửa VGD Cabinet trong phase này.

Nhưng VGD Cabinet sau này phải có thể ghi:

```text
category = furniture
item_type = wardrobe
unit = set
quantity_method = assembly
```

VGD Quantity sẽ đọc trực tiếp.

---

# 73. Chuẩn bị cho VGD Quantity

Quantity phase sau có thể gọi:

```ruby
entities = VGD::BIM::Scanner.all_bim_entities
```

Sau đó:

```ruby
entities.each do |entity|
  data = VGD::BIM::Data.read(entity)

  case data[:quantity_method]

  when "count"
  when "area"
  when "length"
  when "volume"
  when "assembly"
  when "manual"
  end
end
```

---

# 74. VGD Quantity Phase 2

KHÔNG IMPLEMENT trong v0.1.

Chỉ chuẩn bị architecture.

Dự kiến:

```text
Material Area
Component Count
Furniture W/D/H
Finish Area
Electrical Count
Equipment Count
Zone Summary
Floor Summary
```

---

# 75. BOQ Phase 3

KHÔNG IMPLEMENT trong v0.1.

Dự kiến nhóm:

```text
ARCHITECTURE
FINISH
FURNITURE
ELECTRICAL
EQUIPMENT
PLUMBING
HVAC
```

---

# 76. Pricing Phase 4

Không lưu giá trực tiếp trên mỗi entity.

Model lưu:

```text
code
description
quantity
unit
```

Price database riêng lưu:

```text
code
material_price
labor_price
unit
```

---

# 77. Excel Phase sau

Dự kiến workbook:

```text
00_SUMMARY
01_BOQ
02_FURNITURE
03_FINISH
04_ELECTRICAL
05_EQUIPMENT
06_ROOM
99_CHECK
```

Không implement trong v0.1.

---

# 78. Recommended User Workflow

## File VGD

```text
Model
↓
Assign VGD Data
↓
Validate
↓
Quantity
```

---

## File đối tác

```text
Open File
↓
Scan Model
↓
Review Raw Data
↓
Review Materials
↓
Review Components
↓
Map Important Items
↓
Convert to VGD
↓
Validate
↓
Quantity
```

Không bắt user sửa toàn bộ model trước.

---

# 79. Test Model

Tạo test model gồm:

```text
1 Group Wardrobe

10 Component Socket

6 Component Downlight

1 Group Lavabo Cabinet

1 Raw Geometry Wall

1 Group không có VGD Data

1 Nested Component

1 Scaled Component
```

---

# 80. Test Native VGD

Wardrobe:

```text
category = furniture
item_type = wardrobe
description = Tủ áo Master
unit = set
quantity_method = assembly
zone = MASTER
floor = L02
```

Expected:

```text
VALID
```

---

# 81. Test Multi Edit

Select 10 sockets.

Apply:

```text
category = electrical
item_type = socket
description = Ổ cắm đôi
unit = pcs
quantity_method = count
zone = MASTER
```

Expected:

```text
10 entities updated
```

Undo:

```text
Ctrl + Z
```

Expected:

```text
all 10 reverted
```

---

# 82. Test Validation

Change socket:

```text
unit = m2
```

Expected:

```text
ERROR

quantity_method = count
unit = m2
```

---

# 83. Test External Model

Definition:

```text
O_CAM_DOI
```

Tag:

```text
ELEC
```

Instances:

```text
28
```

Expected:

```text
Suggested:

category = electrical
item_type = socket
unit = pcs
quantity_method = count

Confidence = HIGH
```

User confirms.

Convert:

```text
28 instances receive VGD_BIM data
```

Geometry remains unchanged.

---

# 84. Test Raw Material

Material:

```text
SON TUONG
```

applied to raw Faces.

Expected Raw Scan:

```text
Material:
SON TUONG

Total Raw Area:
XX.XX m2
```

No VGD conversion required.

---

# 85. Completion Criteria v0.1-alpha

v0.1-alpha đạt khi:

```text
✓ Plugin load được trên SketchUp 2022+

✓ Namespace sạch VGD::BIM

✓ Attribute Dictionary hoạt động

✓ Data API hoạt động

✓ Group / Component lưu VGD Data

✓ Reopen SketchUp file data vẫn còn

✓ BIM Information hoạt động

✓ Multi Edit hoạt động

✓ Undo hoạt động

✓ Bounding Box đúng với scaled/nested entities

✓ Scan Model hoạt động

✓ Raw Component report hoạt động

✓ Raw Material report hoạt động

✓ Detection suggest hoạt động

✓ Mapping hoạt động

✓ Batch Convert hoạt động

✓ Convert không thay geometry

✓ Validator hoạt động

✓ Validation click select đúng entity

✓ Dirty model không crash plugin
```

---

# 86. Không làm trong v0.1-alpha

Không implement:

```text
VGD Quantity hoàn chỉnh

Excel export

BOQ

Pricing

IFC

Archicad sync

Automatic room detection

Automatic wall detection

Automatic electrical circuit detection

Full furniture construction breakdown

Cabinet BOM
```

---

# 87. Nguyên tắc phát triển

Thứ tự ưu tiên:

```text
Stable Data
↓
External Model Compatibility
↓
Validation
↓
Quantity Accuracy
↓
BOQ
↓
Excel
↓
Pricing
```

Không ưu tiên UI đẹp hơn data architecture.

Không làm BIM quá nặng.

VGD BIM Lite phải phục vụ workflow SketchUp nội thất thực tế.

---

# 88. Yêu cầu dành cho Codex

Implement theo phase.

Phase hiện tại:

```text
PHASE 1 — VGD BIM Lite v0.1-alpha
```

Thứ tự:

```text
1. Plugin Loader
2. Namespace
3. Schema
4. Data API
5. Geometry
6. Scanner
7. BIM Information UI
8. Multi Edit
9. Validator
10. Scan Model
11. Raw Reports
12. Detection
13. Mapping Rules
14. Converter
15. Validation UI
```

Sau khi hoàn thành các phần trên:

```text
STOP.
```

Không tự phát triển tiếp:

```text
VGD Quantity
BOQ
Excel
Pricing
```

Trước tiên cần review kiến trúc, schema và test trên file SketchUp thực tế.

---

# 89. Mục tiêu cuối cùng của hệ thống

VGD BIM Lite không chỉ là:

```text
Chuẩn dựng model của VGD.
```

Mà phải là:

```text
Lớp trung gian chuẩn hóa mọi model SketchUp
để các công cụ VGD có thể đọc,
kiểm tra,
bóc khối lượng
và xuất dữ liệu đáng tin cậy.
```

Mục tiêu dài hạn:

```text
SketchUp Model
→ VGD BIM
→ VGD Quantity
→ BOQ
→ Excel
→ Báo giá
```