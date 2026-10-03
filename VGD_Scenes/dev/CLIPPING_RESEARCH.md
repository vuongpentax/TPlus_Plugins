# Clipping — thí nghiệm riêng, chưa tích hợp

Ngày 03/10/2026. Ruby Camera API không công bố setter Near/Far. Yêu cầu API vẫn mở tại [SketchUp issue #311](https://github.com/SketchUp/api-issue-tracker/issues/311); Windows có hộp Camera ẩn qua `Sketchup.send_action(10624)`. Tham khảo [Camera API](https://ruby.sketchup.com/Sketchup/Camera.html). Không dùng section plane giả làm clipping trong bản chính.

**Trạng thái:** fixture và giao diện bản 1.2.0 đã qua kiểm tra. Kiểm tra clipping trong SketchUp bị người dùng dừng bằng Esc; chưa có kết quả hình ảnh hoặc xác nhận Force/Near, scene persistence, PNG/PDF. Không gọi đây là tính năng đã chạy được. `clipping_lab.rb` chỉ là bộ dựng mẫu để tiếp tục thử, chưa chạy trong kernel; không thuộc runtime/RBZ/allowlist cài.

Lần thử kế tiếp dùng một process SU22 riêng, model mới chưa lưu và hoàn toàn rỗng, không dùng bản vẽ thật. Script từ chối model có đường dẫn, geometry, scene hoặc edit context. Trong Ruby Console của process thử:

```ruby
load 'C:/Users/PC/Documents/ChatGPT/Plugins/VGD_Scenes/dev/clipping_lab.rb'
VGD::ScenesClippingLab.build
VGD::ScenesClippingLab.open_debug
```

Mẫu phòng 3000×4000×2800 mm, tường trước dày 100 mm. Mắt ngoài phòng y=-700 mm; tường nằm cách mắt 700–800 mm (27.56–31.50 inch theo API). Có scene đối chứng mắt trong phòng. Không tạo mặt cắt. Sau khi kiểm tra đơn vị thực tế của hộp Camera, thử Force/Near nhỏ hơn 700 mm và lớn hơn 800 mm, chụp bằng `VGD::ScenesClippingLab.snapshot('near_above_wall')`. File mẫu/ảnh/metrics chỉ ghi `outputs/clipping_lab/`, không ghi đè snapshot đã có.

Cần xác minh trước tích hợp:

- Bỏ tường trước trong viewport mà không xóa geometry hoặc thêm section.
- Ảnh `write_image` có cùng clipping với viewport; thử PNG/JPG/PDF và frame/grid.
- Chuyển hai scene, đổi camera, Orbit, mở lại SKP; xác định clipping lưu theo scene, view hay process.
- Tắt Force và đóng hộp Camera trả trạng thái bình thường; không thay view/model của process khác.
- Kiểm tra trên SU22 và bản mới; không dùng tự động click hộp ẩn trong runtime. Nếu không có setter ổn định để gắn scene và restore khi xuất, giữ công cụ này ngoài bản chính.
