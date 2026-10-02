# Cơ sở cấu tạo pano · 2026-10-03

- [CMT: ABC's of Panel Door Construction](https://www.cmtorangetools.com/downloads/5790/326/324_the_abc_s_of_panel_door_construction_usa.pdf): cánh gồm đố đứng, thanh ngang và tấm giữa; kích thước tấm cộng phần lưỡi/ngậm ở hai cạnh. Ví dụ khung 3/4 inch dày, 2-1/4 inch bản. Điều chỉnh theo chiều dày vật liệu và dao. Không sao chép kích thước mộng của một bộ dao thành tiêu chuẩn chung.
- [WOOD: Dealing with Wood Movement](https://www.woodmagazine.com/woodworking-how-to/wood-preparation/dealing-with-wood-movement): pano gỗ đặc được giữ trong rãnh và có khoảng chuyển động theo thớ, không cố định toàn cạnh vào khung.
- [Rockler: Arched-top raised panel door](https://www.rockler.com/learn/how-to-make-an-arch-top-raised-panel-door): ví dụ rãnh 3/8 inch và bản đố 2-1/4 inch; chiều dài thanh ngang tính thêm phần liên kết. Plugin chưa mô phỏng cope-and-stick/mộng góc.

Áp dụng thiết kế: phiên bản này là pano phẳng khung gỗ với rãnh thẳng. Mặc định chỉnh được 60 × 20 mm, pano 6, rãnh 8, khe 1 mm/cạnh. Kích thước trên là lựa chọn thiết kế gần các ví dụ khung, không được gán thành quy chuẩn.

Công thức mô hình: rộng pano = rộng cánh − 2 bản đố + 2(rãnh − khe). Cao ô = (cao cánh − 2 bản thanh ngang − (số ô−1) bản giữa)/số ô; cao pano = cao ô + 2(rãnh − khe). Tấm nằm giữa chiều dày; groove mở ở cạnh trong khung, không chồng hình học với tấm. Khung/pano là các phần riêng.

Giới hạn: chưa soi profile trang trí, đắp nẹp, pano nổi hoặc mộng góc/CNC/BOM. Khe co giãn phải chỉnh theo vật liệu/độ ẩm; mặc định 1 mm không bảo đảm cho mọi khổ pano gỗ đặc.
