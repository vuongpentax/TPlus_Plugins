# Bộ font T+ Dim

Font do người dùng yêu cầu, lấy từ các file font đã có trên máy: UTM Avo, Roboto, Roboto Condensed, đủ bốn kiểu. TTF gốc được giữ nguyên để preview trong HtmlDialog; JSON lưới tam giác phục vụ chữ T+ trực tiếp trong model.

Chi tiết nguồn, family, copyright, license metadata và SHA256 nằm trong outputs/FONT_PROVENANCE.json của source ZIP. Metadata UTM Avo ghi tác giả Michael Dinh Kien; Roboto/Roboto Condensed ghi Google. Ghi nhận này là nguồn gốc dữ liệu, không tự bổ sung tuyên bố quyền phân phối ngoài nội dung metadata.

Các đường cong glyph được lấy mẫu và chia tam giác, giữ lỗ chữ bằng constrained Delaunay triangulation; kiểm tra tổng diện tích cho từng ký tự. Dùng toàn bộ cmap của từng TTF, gồm tiếng Việt. UTM Avo thiếu một số ký hiệu bản vẽ (Ø, °, ×, ·, ±…); lấy các ký hiệu này từ Roboto cùng kiểu trong bộ đóng gói. Ký tự khác bị thiếu sẽ báo rõ để đổi font, không tra font hệ thống.

Runtime chữ T+ không gọi add_3d_text, không đăng ký font Windows. Chỉ khi sử dụng Text#font= native của SU2026.2+, bộ font được nạp riêng trong tiến trình SketchUp qua AddFontResourceExW/FR_PRIVATE; không cài font toàn hệ thống hoặc ghi registry. Tích hợp native này chưa được thử trong SU2026.2.
