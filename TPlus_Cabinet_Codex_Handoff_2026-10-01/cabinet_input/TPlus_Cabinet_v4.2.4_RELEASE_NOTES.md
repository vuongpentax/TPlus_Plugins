# T+ CABINET v4.2.4

## Mục tiêu bản cập nhật

Sửa đúng 3 điểm theo kiểm tra thực tế trong SketchUp:

1. Ký hiệu mặt ngăn kéo phải là **Guide/Construction Line kiểu Tape Measure**, chéo từ góc trên-trái xuống góc dưới-phải, nằm bên trong chính group `Mặt Ngăn Kéo`.
2. Khung ngăn kéo âm phải đúng cấu tạo **hông + diềm phủ + diềm trước + diềm sau + đợt nóc + xà che khe khi cần**, trong đó `50 mm` là **bề rộng diềm**, không phải chiều dày.
3. `Mặt Ngăn Kéo` dùng tag `T+_CANH`; component/thùng/hộc kéo và raw geometry để `Untagged`.

## Thay đổi chính

### Guide mặt ngăn kéo
- Dùng `ConstructionLine` finite bằng 2 `Point3d`, đúng kiểu Guide của Tape Measure trong SketchUp.
- Điểm đầu: góc trên-trái của mặt drawer.
- Điểm cuối: góc dưới-phải.
- Guide nằm **bên trong group mặt drawer**, vì vậy đi theo drawer khi Dynamic Component trượt ra.
- Guide thuộc tag `T+_KY HIEU`.
- Không thêm nút bật/tắt; có thể xóa bằng lệnh Delete Guides của SketchUp.

### Tag drawer
- Group `Mặt Ngăn Kéo #` → `T+_CANH`.
- Component `Ngăn Kéo_DC`, vách trái/phải, đầu, đuôi, đáy → `Untagged`.
- Raw faces/edges của các tấm drawer được ép về `Untagged` để tránh nhiễm Active Tag hiện tại.

### Khung ngăn kéo âm
Mặc định:
- `Độ lùi mặt = 50 mm`.
- `Rộng diềm = 50 mm`.

Cấu tạo:
- `Hông Khung Ngăn Kéo Âm Trái/Phải`: dày đúng theo `t`.
- `Diềm Phủ Hông ... Trái/Phải`: rộng 50 mm, dày đúng theo `t`, phủ trước cạnh hông.
- Với `t = 20 mm`, `diềm = 50 mm` → hông khung nằm cách hồi tủ `30 mm`.
- `Diềm Trước` và `Diềm Sau`: sửa thành thanh **đứng trong mặt phẳng XZ**, cao 50 mm, dày `t`; không còn là tấm nằm ngang sâu 50 mm.
- Giữ `Đợt Nóc Khung Ngăn Kéo Âm`.
- Giữ `Xà Che Khe Ngăn Kéo` tùy chọn cho cấu tạo tay móc/khe lớn.

## Kiểm tra đã chạy

- Ruby syntax: PASS.
- UI render: PASS.
- JavaScript syntax: PASS.
- Duplicate HTML IDs: không có.
- Geometry regression: PASS.
- Drawer guide finite + nằm trong mặt drawer: PASS.
- `Mặt Ngăn Kéo = T+_CANH`, thùng drawer = Untagged: PASS.
- Khung drawer âm `t=20`, diềm `50` → hông lùi `30`: PASS.
- Diềm đứng trái/phải: rộng `50`, dày `20`: PASS.
- Diềm trước/sau: cao `50`, dày `20`: PASS.
- Độ lùi mặt drawer âm mặc định `50`: PASS.
- Xà che khe: PASS.

## Gợi ý test trong SketchUp 2022

1. Tạo tủ có 2–3 ngăn kéo lộ; kiểm tra nét guide chéo trên từng mặt drawer.
2. Chọn component drawer và kéo Dynamic Component; guide phải đi theo mặt drawer.
3. Bật/tắt tag `T+_KY HIEU`; chỉ ký hiệu guide thay đổi hiển thị.
4. Kiểm tra Entity Info: `Mặt Ngăn Kéo` = `T+_CANH`; các tấm thùng = `Untagged`.
5. Tạo drawer Âm: `t=20`, `diềm=50`, `độ lùi mặt=50`; bật X-Ray để kiểm tra hông/diềm/diềm trước-sau/xà che.
