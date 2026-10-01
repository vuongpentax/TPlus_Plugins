(function () {
  'use strict';
  var context = null, initialized = false, busy = false, modelId = null, deletion = null;
  var checkboxKeys = ['deep', 'include_dim', 'include_text', 'change_color', 'change_offset', 'reset_text', 'change_units', 'show_unit', 'assign_tags', 'save_profile', 'auto_new', 'change_font', 'font_bold', 'font_italic', 'custom_dim'];
  var valueKeys = ['dim_color', 'text_color', 'arrow', 'text_arrow', 'alignment', 'position', 'offset_mm', 'unit', 'precision', 'font', 'size_pt'];
  var el = function (id) { return document.getElementById(id); };
  function call(action, payload) {
    if (window.sketchup && typeof window.sketchup[action] === 'function') { window.sketchup[action](payload); return true; }
    return false;
  }
  function status(message, error) { el('model_status').textContent = message; el('model_status').classList.toggle('error', !!error); }
  function applicable() { return context && !context.blocked && (context.can_apply || (context.can_save_profile && (el('save_profile').checked || el('change_units').checked))); }
  function updateButton() {
    el('apply').disabled = busy || !applicable();
    document.querySelectorAll('[data-delete]').forEach(function(button) {
      var count = context ? (button.dataset.delete === 'dimensions' ? context.delete_dimensions : button.dataset.delete === 'texts' ? context.delete_texts : context.delete_dimensions + context.delete_texts) : 0;
      button.disabled = busy || !context || !context.can_delete || !count;
    });
  }
  function sample() {
    el('dim_hex').textContent = el('dim_color').value.toUpperCase();
    el('text_hex').textContent = el('text_color').value.toUpperCase();
    var color = el('change_color').checked ? el('dim_color').value : (document.body.classList.contains('dark') ? '#E2E8F0' : '#222222');
    el('sample-lines').style.stroke = color; el('sample-label').style.fill = color;
    var markup = '', arrow = el('arrow').value;
    if (arrow === 'slash' || arrow === 'keep') markup = '<path d="M33 41l10-12M257 41l10-12"/>';
    if (arrow === 'dot') markup = '<circle cx="38" cy="35" r="3" fill="currentColor"/><circle cx="262" cy="35" r="3" fill="currentColor"/>';
    if (arrow === 'closed' || arrow === 'open') markup = '<path d="M48 31l-10 4 10 4' + (arrow === 'closed' ? 'z' : '') + 'M252 31l10 4-10 4' + (arrow === 'closed' ? 'z' : '') + '"' + (arrow === 'closed' ? ' fill="currentColor"' : '') + '/>';
    el('sample-arrows').innerHTML = markup; el('sample-arrows').style.color = color;
  }
  function controls() {
    el('dim_color').disabled = !el('change_color').checked;
    el('offset_mm').disabled = !el('change_offset').checked;
    el('text_color').disabled = !el('include_text').checked;
    el('alignment').querySelector('[value="screen"]').disabled = el('custom_dim').checked;
    if (el('custom_dim').checked && el('alignment').value === 'screen') el('alignment').value = 'aligned';
    el('position').disabled = el('alignment').value === 'screen';
    el('unit_fields').disabled = !el('change_units').checked;
    el('font_preview').style.fontFamily = el('font').value;
    el('font_preview').style.fontWeight = el('font_bold').checked ? '700' : '400';
    el('font_preview').style.fontStyle = el('font_italic').checked ? 'italic' : 'normal';
    el('font_preview').style.color = el('text_color').value;
    el('sample-label').style.fontFamily = el('font').value;
    el('sample-label').style.fontWeight = el('font_bold').checked ? '700' : '400';
    el('sample-label').style.fontStyle = el('font_italic').checked ? 'italic' : 'normal';
    el('size_hint').textContent = el('size_pt').value + ' pt = ' + (Number(el('size_pt').value) * 25.4 / 72).toFixed(2) + ' mm trong model. Chữ phẳng thay đổi theo mức zoom.';
    el('auto_new').disabled = !el('save_profile').checked;
    updateButton();
    sample();
  }
  function refresh() {
    context = null; updateButton();
    deletion = null; el('delete_confirm').hidden = true;
    if (!call('refresh', JSON.stringify({deep: el('deep').checked, include_dim: el('include_dim').checked, include_text: el('include_text').checked}))) {
      status('Bản xem trước giao diện. Vùng chọn và áp dụng hoạt động trong SketchUp.');
    }
  }
  function receive(next, settings) {
    if (next.model_id !== modelId) { initialized = false; modelId = next.model_id; }
    if (!context || context.delete_token !== next.delete_token) { deletion = null; el('delete_confirm').hidden = true; }
    context = next; busy = false;
    if (!initialized) {
      checkboxKeys.forEach(function (key) { if (settings[key] !== undefined) el(key).checked = settings[key]; });
      valueKeys.forEach(function (key) { if (settings[key] !== undefined) el(key).value = settings[key]; });
      initialized = true;
    }
    var summary = next.dimensions + ' dim';
    if (el('include_text').checked) summary += ' · ' + next.texts + ' text';
    el('selection_mode').textContent = next.selected ? summary + ' trong vùng chọn' : 'Chọn dim trong model';
    el('scope_note').textContent = next.shared > 0
      ? 'Có nhóm/component dùng chung. Plugin sẽ tách riêng phần được chọn trước khi cập nhật.'
      : 'Nhóm dùng chung được tách riêng khi cập nhật để giữ đúng phạm vi vùng chọn.';
    el('delete_summary').textContent = (next.delete_dimensions || 0) + ' dim · ' + (next.delete_texts || 0) + ' text, kể cả cấp ẩn sâu.';
    el('profile_status').textContent = next.profile_active ? 'Quy chuẩn trong file đang tự áp dụng cho đối tượng mới.' : 'Tự chuẩn hóa chưa bật trong file này.';
    status(next.blocked || (next.can_apply ? 'Sẵn sàng áp dụng cho vùng chọn.' + (next.locked ? ' Bỏ qua ' + next.locked + ' nhóm khóa.' : '') : 'Quét chọn dim hoặc nhóm chứa dim trong SketchUp.'), !!next.blocked);
    controls(); updateButton();
  }
  function payload() {
    var data = {context_token: context && context.context_token};
    checkboxKeys.forEach(function (key) { data[key] = el(key).checked; });
    valueKeys.forEach(function (key) { data[key] = el(key).value; });
    if (data.change_offset) {
      var offset = Number(data.offset_mm);
      if (!data.offset_mm.trim() || !Number.isFinite(offset) || offset <= 0 || offset > 1000000) throw new Error('Nhập khoảng cách dim lớn hơn 0 và không quá 1.000.000 mm.');
      data.offset_mm = offset;
    }
    data.precision = Number(data.precision);
    data.size_pt = Number(data.size_pt);
    if (!Number.isFinite(data.size_pt) || data.size_pt < 1 || data.size_pt > 1000) throw new Error('Cỡ chữ phải từ 1 đến 1000 pt.');
    return data;
  }
  function apply() {
    if (!applicable() || busy) return;
    try {
      var data = payload(); busy = true; updateButton(); status('Đang chuẩn hóa vùng chọn…');
      if (!call('apply', JSON.stringify(data))) { busy = false; updateButton(); status('Bản xem trước giao diện. Áp dụng hoạt động trong SketchUp.'); }
    } catch (error) { busy = false; updateButton(); status(error.message, true); }
  }
  function theme(dark) { document.body.classList.toggle('dark', dark); el('theme').textContent = dark ? 'Sáng' : 'Tối'; sample(); }
  document.querySelectorAll('[data-page]').forEach(function (button) {
    button.addEventListener('click', function () {
      document.querySelectorAll('[data-page]').forEach(function (other) { if (other === button) other.setAttribute('aria-current', 'page'); else other.removeAttribute('aria-current'); });
      document.querySelectorAll('[data-panel]').forEach(function (panel) { panel.hidden = panel.dataset.panel !== button.dataset.page; });
      el('settings_content').scrollTop = 0;
    });
  });
  el('theme').addEventListener('click', function () { var dark = !document.body.classList.contains('dark'); theme(dark); try { localStorage.setItem('tplus_theme', dark ? 'dark' : 'light'); } catch (_error) {} });
  el('refresh').addEventListener('click', refresh);
  el('apply').addEventListener('click', apply);
  el('close').addEventListener('click', function () { if (!call('close')) status('Đóng tab xem trước để kết thúc.'); });
  el('dim_info').addEventListener('click', function () { if (!call('model_info', 'Dimensions')) status('Model Info → Dimensions mở trong SketchUp.'); });
  el('text_info').addEventListener('click', function () { if (!call('model_info', 'Text')) status('Model Info → Text mở trong SketchUp.'); });
  document.querySelectorAll('[data-delete]').forEach(function(button) {
    button.addEventListener('click', function() {
      if (!context || button.disabled) return;
      deletion = {kind: button.dataset.delete, delete_token: context.delete_token};
      var dim = deletion.kind !== 'texts' ? context.delete_dimensions : 0;
      var text = deletion.kind !== 'dimensions' ? context.delete_texts : 0;
      el('delete_question').textContent = 'Xóa ' + dim + ' dim và ' + text + ' text trong vùng chọn này?';
      el('delete_confirm').hidden = false;
    });
  });
  el('delete_cancel').addEventListener('click', function() { deletion=null; el('delete_confirm').hidden=true; });
  el('delete_commit').addEventListener('click', function() {
    if (!deletion || busy || !context || deletion.delete_token !== context.delete_token) return;
    busy=true; updateButton();
    if (!call('delete', JSON.stringify(deletion))) { busy=false; updateButton(); status('Nút xóa hoạt động trong SketchUp.'); }
    deletion=null; el('delete_confirm').hidden=true;
  });
  document.addEventListener('change', function (event) { controls(); if (['deep','include_dim','include_text'].indexOf(event.target.id) >= 0) refresh(); });
  document.addEventListener('input', controls);
  window.TPlusDim = {receive: receive, status: status};
  try { theme(localStorage.getItem('tplus_theme') === 'dark'); } catch (_error) { theme(false); }
  controls();
  if (!call('ready')) status('Bản xem trước giao diện. Chọn và áp dụng dim trong SketchUp 2022.');
})();
