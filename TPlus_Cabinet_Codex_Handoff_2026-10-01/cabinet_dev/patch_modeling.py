from pathlib import Path
import re
root=Path('cabinet_work/TPlus_Cabinet')
s=Path('cabinet_dev/geometry_original.rb').read_text()
s=s.replace("        t_back = [0.mm, p['t_back'].to_f.mm].max", "        t_back = p['back_mode'] == 'Không' ? 0.mm : [0.mm, p['t_back'].to_f.mm].max\n        back_overlay = p['back_mode'] == 'Phủ'")
s=s.replace('        d_cabinet = is_phu ? (d_input - t) : d_input','        d_cabinet = (is_phu ? (d_input - t) : d_input) - (back_overlay ? t_back : 0.mm)')
s=s.replace('        back_space = (t_back > 0 ? (back_recess + t_back) : 0.mm)','        back_space = (t_back > 0 && !back_overlay ? (back_recess + t_back) : 0.mm)')
needle='''        create_back_boards = ->(start_x, z_start, z_h, div_x_positions_arr) {
'''
assert needle in s
s=s.replace(needle,needle+'''          if back_overlay
            low = z_start <= plinth_h + t + 0.01.mm ? 0.mm : z_start - t
            high = z_start + z_h
            high = h if (high - (h-shadow_gap_h-t)).abs < 0.01.mm
            create_board.call("Tấm Hậu Phủ", w, t_back, high-low, 0.mm, d_cabinet, low)
            next
          end
''')
needle='''              pts = [[face_x, 0.mm, 0.mm], [face_x + dx, 0.mm, 0.mm], [face_x + dx, dy, 0.mm], [face_x, dy, 0.mm]]
              f = board_group.entities.add_face(pts)
              if f
                f.reverse! if f.normal.z < 0
                f.pushpull(dz)
              end'''
assert s.count(needle)==2
s=s.replace(needle,"              Modeling.front_solid(board_group.entities, face_x, dx, dy, dz, p)",1)
s=re.sub(r'board_group.entities.add_cline\((\[.*?\]), (\[.*?\])\)',r'board_group.entities.add_cline(Geom::Point3d.new(\1), Geom::Point3d.new(\2))',s)
needle='''                pts = [[0.mm, 0.mm, 0.mm], [dx, 0.mm, 0.mm], [dx, dy, 0.mm], [0.mm, dy, 0.mm]]
                f = b_grp.entities.add_face(pts)
                if f
                  f.reverse! if f.normal.z < 0
                  f.pushpull(dz)
                end'''
assert needle in s
s=s.replace(needle,'''                if b_name.start_with?("Mặt Ngăn Kéo")
                  Modeling.front_solid(b_grp.entities, 0.mm, dx, dy, dz, p)
                else
                  Modeling.front_solid(b_grp.entities, 0.mm, dx, dy, dz, p.merge('front_bevel'=>false))
                end''')
# Do not commit a partly built cabinet if any primitive fails.
s=re.sub(r'(rescue\n\s+\w+\.erase! if \w+\.valid?\n\s+)return nil',r'\1raise',s)
s=s.replace('          return nil if dx < 0.001.inch || dy < 0.001.inch || dz < 0.001.inch',"          raise ModelingRules::Invalid, \"Tấm #{name} có kích thước không hợp lệ.\" if dx < 0.001.inch || dy < 0.001.inch || dz < 0.001.inch")
(root/'geometry_engine.rb').write_text(s)

p=root/'draw_tool.rb';s=p.read_text()
s=s.replace('snapped = (val_mm.abs / 50.0).round * 50.0\n      snapped = 50.0 if snapped < 50.0','step = (@params[\'snap_step\'] || 50).to_f\n      snapped = (val_mm.abs / step).round * step\n      snapped = step if snapped < step')
# Existing 3-point preview is in world coordinates. Transform finished placement into edit context.
s=s.replace('TPlus_Cabinet.create_new_cabinet_at(@params, tr)','TPlus_Cabinet.create_new_cabinet_at(@params, Sketchup.active_model.edit_transform.inverse * tr)')
p.write_text(s)

s=Path('cabinet_dev/ui_original.html').read_text().replace('v4.2.4','v4.3.0 beta')
s=s.replace('<button class="btn-update" onclick="updateCabinet(true)">🔄 CẬP NHẬT</button>', '<button class="btn-update" id="btn_update" onclick="updateCabinet(true)" disabled>CẬP NHẬT TỦ</button>')
s=s.replace('  <div class="master-switch-container">','''  <button class="btn-tool" style="margin:8px;width:calc(100% - 16px)" onclick="placeCabinet()">ĐẶT TỦ MỚI THEO KÍCH THƯỚC</button>
  <div id="model_status" role="status" style="padding:8px 12px;line-height:1.5">Chọn mẫu hoặc nhập kích thước rồi đặt tủ mới.</div>
  <div class="checkbox-row" style="padding:0 12px"><input id="live_update" type="checkbox"><label for="live_update">Tự cập nhật tủ đang chọn khi sửa ô</label></div>
  <div style="padding:6px 12px;font-size:11px">W/D/H: phủ bì gồm cánh và hậu; H gồm chân và nẹp. Đơn vị mm.</div>
  <div class="master-switch-container">''',1)
s=s.replace('<div class="sub-title">HẬU</div>','''<div class="sub-title">HẬU</div>
        <div class="form-group"><label>Kiểu hậu</label><select id="back_mode"><option>Âm</option><option>Phủ</option><option>Không</option></select></div>''')
s=s.replace('<div class="sub-title">CHIA KHOANG</div>','''<div class="sub-title">MODULE VÀ CHIA KHOANG</div>
        <div class="form-group"><label>Kiểu ghép</label><select id="module_mode"><option>Chung vách</option><option>Độc lập</option></select></div>
        <div class="form-group"><label>Rộng từng module</label><input id="module_widths" type="text" placeholder="800;800;800"></div>
        <div class="form-group"><label>Rộng mục tiêu</label><input id="module_target_w" type="number" value="800"></div>
        <p style="font-size:11px;line-height:1.5">Module độc lập có hai hồi riêng. Để trống danh sách để chia đều theo rộng mục tiêu. Cánh, đợt và hộc được áp dụng cho từng module.</p>''')
s=s.replace('<div class="form-group"><label>Chiều rộng (W)</label>', '''<div class="form-group"><label>Bước bắt khi vẽ</label><input type="number" id="snap_step" value="50" min="1" max="100"></div>
      <div class="form-group"><label>Chiều rộng (W)</label>''')
s=s.replace('  <div class="card" id="card_frame">','''  <div class="card expanded">
    <div class="card-header">MÉP MÓC TAY</div><div class="card-body">
      <div class="checkbox-row"><input id="front_bevel" type="checkbox"><label for="front_bevel">Vát 45° mép trên cánh và mặt hộc</label></div>
      <div class="form-group"><label>Mép giữ lại (mm)</label><input id="bevel_lip" type="number" value="2" step="0.5"></div>
      <p style="font-size:11px">Vát tạo hình thật. Với hộc lộ, đặt khe giữa 20–25 mm và bật xà che khe khi cần.</p>
    </div>
  </div>
  <div class="card" id="card_frame">''')
s=s.replace('    var updateTimer = null;', '''    var updateTimer = null;
    var selectedPid = null;
    function showModelStatus(text, error) {
      var el = document.getElementById('model_status');
      el.textContent = text; el.style.color = error ? '#c33434' : '';
    }
    function setSelectedCabinet(pid) {
      selectedPid = pid || null;
      if (updateTimer) { clearTimeout(updateTimer); updateTimer = null; }
      document.getElementById('btn_update').disabled = !selectedPid;
      showModelStatus(selectedPid ? 'Đã chọn tủ T+. Nhập thông số rồi bấm CẬP NHẬT TỦ.' : 'Chưa chọn tủ. Dùng ĐẶT TỦ MỚI hoặc VẼ 3 ĐIỂM.', false);
    }
    function placeCabinet() {
      if (updateTimer) clearTimeout(updateTimer);
      if (window.sketchup) window.sketchup.create_cabinet(getFormData());
    }''')
s=s.replace('    function debouncedUpdateCabinet() {','''    function debouncedUpdateCabinet() {
      if (!selectedPid || !document.getElementById('live_update').checked) return;''')
s=s.replace('        w: getNumValue(\'w\', 800),','''        __target_pid: selectedPid,
        back_mode: document.getElementById('back_mode').value,
        module_mode: document.getElementById('module_mode').value,
        module_widths: document.getElementById('module_widths').value,
        module_target_w: getNumValue('module_target_w',800),
        front_bevel: document.getElementById('front_bevel').checked,
        bevel_lip: getNumValue('bevel_lip',2),
        snap_step: getNumValue('snap_step',50),
        w: getNumValue('w', 800),''')
s=s.replace('      if (!params) return;','      if (!params) return;\n      if (params.__target_pid !== undefined) setSelectedCabinet(params.__target_pid);',1)
s=s.replace('    function updateCabinet(isUserManualAction) {','''    function updateCabinet(isUserManualAction) {
      if (!selectedPid) { if (isUserManualAction) showModelStatus('Chọn một tủ T+ để cập nhật, hoặc bấm ĐẶT TỦ MỚI.',true); return; }''')
s=s.replace('      updateCabinet(true);\n    }\n\n    function updatePresetList','      showModelStatus(\'Đã nạp mẫu. Bấm ĐẶT TỦ MỚI hoặc CẬP NHẬT TỦ.\',false);\n    }\n\n    function updatePresetList')
s=s.replace('      initTheme();','      initTheme();\n      setSelectedCabinet(null);',1)
s=s.replace("      updateFormFromRuby((initialParams && Object.keys(initialParams).length) ? initialParams : defaultParams);","      updateFormFromRuby((initialParams && Object.keys(initialParams).length) ? initialParams : defaultParams);\n      if (window.sketchup) window.sketchup.ready();")
# Retain typed dimensions until explicit apply. Required number inputs cannot silently fall back.
s=s.replace("if (window.sketchup) {\n        var data = getFormData();","if (window.sketchup) {\n        var data = getFormData();")
(root/'TPlus_Cabinet_UI.html').write_text(s)

loader=Path('cabinet_work/tplus_cabinet.rb')
s=loader.read_text().replace('4.2.4','4.3.0-beta.1').replace('TPlus_Cabinet/main.rb','TPlus_Cabinet/main43.rb').replace('SketchUp 2017-2024+','SketchUp 2022/2024; bản dựng hình chạy thử')
loader.write_text(s)
