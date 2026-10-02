# VGD_Cabinet · bàn giao 2026-10-03

Phiên bản 4.4.0-beta.1. Active source: cabinet_work/vgd_cabinet.rb, cabinet_work/VGD_Cabinet/main43.rb. Generator: cabinet_dev/redesign_ui.cjs từ ui_beta1/menu.css/menu.js. Bản T+ trong TPlus_Cabinet_Codex_Handoff_2026-10-01 giữ làm tham chiếu, không deploy nữa.

Yêu cầu mới và cách dùng: README.md. Nghiên cứu pano: PANO_RESEARCH.md. Giữ nguyên các quy tắc thùng/két/hậu/cánh kính/EXPLODE/UNTAG trong handoff cũ; cập nhật thương hiệu và các mặc định theo yêu cầu mới.

preset_store.rb lưu JSON schema 1 ở APPDATA/VGD/SketchUp/VGD_Cabinet, độc lập bản SketchUp/plugin, có khóa file/backup/ghi tạm/rename/đọc đối chiếu. Chỉ migrate read_default('TPlus_Cabinet','presets_v43') khi chưa có file mới/backup. Không reset danh sách sau reload; deletion mẫu mặc định cũng được lưu.

Model dictionary mới VGD_Cabinet; đọc fallback TPlus_Cabinet để sửa model cũ. Stamp angle cũ được xóa sau khi cập nhật để không áp phép quay hai lần. front_bevel/bevel_lip là cánh; drawer_bevel/drawer_bevel_lip là hộc; handle_split_v1 đánh dấu payload đã tách. Pano riêng module pano.rb.

Chạy từ VGD_Cabinet:
node cabinet_dev/check_ruby.cjs
node cabinet_dev/redesign_ui.cjs
node cabinet_dev/test_dom.cjs
node cabinet_dev/test_payload.cjs
node cabinet_dev/test_ui.cjs
python cabinet_dev/test_deploy.py
python cabinet_dev/package_menu.py

check_ruby tạo thư mục preset_fixture trong outputs, host filesystem qua WASI; flock mô phỏng. UI cần CODEX_PRIMARY_RUNTIME_NODE_MODULES chứa Playwright và Edge. Đóng gói whitelist 17 file. Source ZIP gồm test/generator/docs và validation, không cache/cấu hình người dùng. Installer chỉ SU2022, legacy loader T+ sao lưu rồi tắt, runtime T+ cũ để nguyên cho phục hồi.

Không có native SketchUp test trong phiên này. Đổi namespace phải restart SketchUp; không cố nóng thay module T+ trong model đang làm.
