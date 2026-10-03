'use strict';
document.addEventListener('DOMContentLoaded', () => {
  const $ = id => document.getElementById(id);
  const settingsKeys = ['project','template','axis_mode','grouping','isolate','width','height','margin','grid','format','transparent','paper','section_axis','section_percent','section_offset','section_flip','section_name','normal_x','normal_y','normal_z','ratio_locked','export_scale','date_folder'];
  const numeric = new Set(['width','height','margin','section_percent','section_offset','normal_x','normal_y','normal_z','export_scale']);
  const booleans = new Set(['isolate','transparent','section_flip','ratio_locked','date_folder']);
  let context = null, busy = false, selected = new Set(), pendingModal = null, lastPath = null;
  let transfer = null, transferSelected = new Set();
  const primaryActions = {views:$('generate'),sections:$('section'),export:$('exportButton')};
  Object.values(primaryActions).forEach(button => $('primarySlot').append(button));
  Object.entries(primaryActions).forEach(([name,button]) => {button.hidden=name!=='views';});
  let theme = 'light';
  try { theme = localStorage.getItem('VGD.Scenes.Theme') || 'light'; } catch (_) {}
  document.body.classList.toggle('dark', theme === 'dark');
  function status(message, error = false) { $('status').textContent = message || 'Thao tác không thành công.'; $('status').classList.toggle('error', error); }
  function settings() {
    applyRatioInput();
    const out = {};
    for (const key of settingsKeys) out[key] = booleans.has(key) ? $(key).checked : numeric.has(key) ? Number($(key).value) : $(key).value;
    out.views = [...document.querySelectorAll('[data-view][aria-pressed=true]')].map(button => button.dataset.view);
    if (settingsKeys.filter(key => numeric.has(key)).some(key => !Number.isFinite(out[key]) || $(key).value.trim() === '')) throw Error('Điền đầy đủ các thông số số.');
    if (out.width < 100 || out.height < 100 || out.width > 12000 || out.height > 12000 || out.width*out.height > 64000000) throw Error('Kích thước ảnh: 100–12000 px, tối đa 64 triệu pixel.');
    if (out.margin < 0 || out.margin > 100) throw Error('Lề cần nằm trong 0–100%.');
    if (out.section_percent < 0 || out.section_percent > 100) throw Error('Vị trí cắt cần nằm trong 0–100%.');
    if (!(out.export_scale > 0)) throw Error('Scale xuất phải lớn hơn 0.');
    return out;
  }
  function enable() {
    document.querySelectorAll('button:not(#theme):not(#modalCancel):not(#modalConfirm):not(#cancel):not(#openFolder)').forEach(button => { button.disabled = !context || busy; });
    document.querySelectorAll('[data-needs-selection]').forEach(button => { button.disabled = !context || busy || context.selection === 0; });
    document.querySelectorAll('[data-needs-scenes]').forEach(button => { button.disabled = !context || busy || selected.size === 0; });
    $('update').disabled = !context || busy || selected.size === 0 || context.scenes.some(scene => selected.has(scene.id) && !scene.owned);
    $('selectedCount').textContent = selected.size + ' đã chọn';
    $('exportSelection').textContent = selected.size ? selected.size + ' scene đã chọn · Xuất theo thứ tự trong model.' : 'Chưa chọn scene. Đánh dấu trong mục Scene.';
    $('cancel').hidden = !busy;
    $('openFolder').hidden = !lastPath || busy;
    document.querySelectorAll('#sceneList input').forEach(input => { input.disabled = busy; });
    $('copyScenes').disabled = !context || busy || (!selected.size && !context.scenes.some(scene => scene.selected));
    $('saveScenes').disabled = !context || busy || ($('sceneScope').value === 'all' ? !context.scenes.length : !selected.size);
    $('transferApply').disabled = !context || busy || !transfer || !transferSelected.size;
    document.querySelectorAll('#transferList input').forEach(input => { input.disabled = busy; });
  }
  function send(action, extra = {}, lock = true) {
    if (!context || (busy && !['cancel','refresh'].includes(action))) return;
    if (!window.sketchup) { status('Bản xem trước: thao tác thực hiện trong SketchUp.'); return; }
    if (lock) { busy = true; enable(); }
    window.sketchup.action(JSON.stringify({ action, model: context.model, ...extra }));
  }
  function runSettings(action) { try { const opts = settings(); if (action === 'generate' && !opts.views.length) throw Error('Chọn ít nhất một góc nhìn.'); if (action === 'section' && !opts.section_name.trim()) throw Error('Điền tên mặt cắt.'); if (action === 'section' && opts.section_axis === 'CUSTOM' && ![opts.normal_x,opts.normal_y,opts.normal_z].some(n => Math.abs(n)>1e-9)) throw Error('Vector pháp tuyến không được bằng 0.'); send(action, { settings: opts }); } catch (error) { status(error.message, true); } }
  function tab(name) {
    document.querySelectorAll('.tab').forEach(panel => { panel.hidden = panel.id !== name; });
    document.querySelectorAll('[data-tab]').forEach(button => button.setAttribute('aria-selected', String(button.dataset.tab === name)));
    document.querySelector('main').scrollTop = 0;
    Object.entries(primaryActions).forEach(([key,button]) => {button.hidden=key!==name;});
  }
  function filtered() { if (!context) return []; const query = $('search').value.toLocaleLowerCase(); return context.scenes.filter(scene => (!$('onlyVGD').checked || scene.owned || scene.imported) && scene.name.toLocaleLowerCase().includes(query)); }
  function modal(title, text, callback, value) {
    pendingModal = callback; $('modalTitle').textContent = title; $('modalText').textContent = text;
    $('renameInput').hidden = value === undefined; $('renameInput').value = value || '';
    $('modal').hidden = false; (value === undefined ? $('modalCancel') : $('renameInput')).focus();
    if (value !== undefined) $('renameInput').select();
  }
  function closeModal() { $('modal').hidden = true; pendingModal = null; }
  function clearTransfer() { transfer = null; transferSelected.clear(); $('transferModal').hidden = true; }
  function renderTransfer() {
    const list = $('transferList'); list.replaceChildren();
    if (!transfer) return;
    const mode = $('transferMode').value;
    for (const scene of transfer.scenes) {
      const row = document.createElement('div'); row.className = 'transfer-row';
      const label = document.createElement('label');
      const check = document.createElement('input'); check.type = 'checkbox'; check.checked = transferSelected.has(scene.id); check.setAttribute('aria-label','Nhập ' + scene.name);
      check.addEventListener('change', () => { check.checked ? transferSelected.add(scene.id) : transferSelected.delete(scene.id); renderTransfer(); });
      const name = document.createElement('span'); name.className = 'transfer-name'; name.textContent = scene.name; name.title = scene.name;
      const detail = document.createElement('small'); detail.textContent = mode === 'new' ? 'Tạo mới' : scene.ambiguous ? 'Trùng nhiều · cần kiểm tra' : scene.match ? (mode === 'skip' ? 'Bỏ qua: ' : 'Cập nhật: ') + scene.match : 'Tạo mới'; detail.title = detail.textContent;
      label.append(check,name); row.append(label,detail); list.append(row);
    }
    $('transferCount').textContent = transferSelected.size + '/' + transfer.scenes.length + ' đã chọn'; enable();
  }
  function showTransfer(data) {
    if (!data) { clearTransfer(); return; }
    if (transfer && transfer.token === data.token) return;
    closeModal(); tab('scenes'); transfer = data; transferSelected = new Set(data.scenes.map(scene => scene.id)); $('transferMode').value = 'new';
    $('transferSource').textContent = (data.title || 'Model chưa lưu') + ' · ' + data.scenes.length + ' góc nhìn';
    $('transferModal').hidden = false; renderTransfer(); $('transferMode').focus();
  }
  function render() {
    const list = $('sceneList'); list.replaceChildren(); const scenes = filtered();
    if (!scenes.length) { const empty = document.createElement('div'); empty.className = 'empty'; empty.textContent = context && context.scenes.length ? 'Không có scene khớp bộ lọc.' : 'Chưa có scene. Tạo ở mục Góc nhìn hoặc Mặt cắt.'; list.append(empty); }
    for (const scene of scenes) {
      const row = document.createElement('div'); row.className = 'scene-row' + (scene.selected ? ' current' : '');
      const check = document.createElement('input'); check.type = 'checkbox'; check.checked = selected.has(scene.id); check.setAttribute('aria-label','Chọn ' + scene.name);
      check.addEventListener('change', () => { check.checked ? selected.add(scene.id) : selected.delete(scene.id); enable(); });
      const name = document.createElement('button'); name.className = 'scene-name'; name.textContent = scene.name; name.title = scene.name; name.addEventListener('click', () => send('visit',{id:scene.id}));
      const badge = document.createElement('span'); badge.className = 'badge'; badge.textContent = scene.owned ? (scene.kind === 'SECTION' ? 'VGD · Cắt' : 'VGD') : scene.imported ? 'VGD · Nhập' : 'Scene';
      const rename = document.createElement('button'); rename.className = 'row-action'; rename.textContent = 'Tên'; rename.title = 'Đổi tên scene'; rename.addEventListener('click', () => modal('Đổi tên scene',scene.name,() => send('rename',{id:scene.id,name:$('renameInput').value.trim()}),scene.name));
      const capture = document.createElement('button'); capture.className = 'row-action'; capture.textContent = 'Lưu view'; capture.title = 'Cập nhật scene bằng góc nhìn hiện tại'; capture.addEventListener('click', () => modal('Lưu góc nhìn hiện tại','Cập nhật camera, visibility và mặt cắt hiện tại vào “' + scene.name + '”?',() => send('capture',{id:scene.id})));
      row.append(check,name,badge,rename,capture); list.append(row);
    }
    enable();
  }
  function showFormat() { const isPng = $('format').value === 'png'; $('transparent').disabled = !isPng; $('transparentLabel').style.opacity = isPng ? '1' : '.45'; $('alphaHint').hidden = !isPng; $('paperLabel').hidden = $('format').value !== 'pdf'; }
  function frameStatus(frameActive, gridActive) {
    $('toggleFrame').setAttribute('aria-pressed',String(frameActive)); $('toggleFrame').textContent = frameActive ? 'Tắt khung' : 'Bật khung';
    $('toggleGrid').setAttribute('aria-pressed',String(gridActive)); $('toggleGrid').textContent = gridActive ? 'Tắt lưới' : 'Bật lưới';
  }
  function lockStatus() {
    const locked = $('ratio_locked').checked;
    $('lockRatio').setAttribute('aria-pressed',String(locked));
    $('lockRatio').textContent = locked ? 'Tỷ lệ đã khóa' : 'Khóa tỷ lệ';
  }
  window.VGDScenes = { receive(event, data) {
    if (event === 'state' && data && Array.isArray(data.scenes)) {
      const changed = !context || context.model !== data.model;
      const currentId = value => value && value.scenes.find(scene => scene.selected)?.id;
      const frameChanged = changed || currentId(context) !== currentId(data);
      if (changed) { selected.clear(); closeModal(); clearTransfer(); lastPath = null; for (const key of settingsKeys) if (data.settings[key] !== undefined) booleans.has(key) ? $(key).checked = data.settings[key] : $(key).value = data.settings[key]; document.querySelectorAll('[data-view]').forEach(button => button.setAttribute('aria-pressed',String(data.settings.views.includes(button.dataset.view)))); }
      context = data; busy = !!data.busy; selected = new Set([...selected].filter(id => data.scenes.some(scene => scene.id === id)));
      if (frameChanged && data.current_frame) {
        ['width','height','margin'].forEach(key => { $(key).value = data.current_frame[key]; });
      }
      if (frameChanged) syncRatio();
      $('selection').textContent = data.selection ? data.selection + ' đối tượng đang chọn' + (data.editing ? ' · đang edit group' : '') : 'Chọn Group / Component trong model';
      $('modelTitle').textContent = data.title; $('sceneCount').textContent = String(data.scenes.length);
      $('customNormal').hidden = $('section_axis').value !== 'CUSTOM'; $('sectionSlider').value = $('section_percent').value;
      frameStatus(!!data.frame_active, !!data.grid_active); lockStatus(); showFormat(); render(); showTransfer(data.transfer);
    } else if (event === 'frame' && data) { frameStatus(!!data.frame_active, !!data.grid_active);
    } else if (event === 'result') {
      busy = false; status(data && data.message, !(data && (data.success || data.cancelled)));
      if (data && data.ids) selected = new Set(data.ids);
      enable();
    } else if (event === 'started') {
      busy = true; lastPath = null; $('progress').hidden = false; $('progress').value = 0; $('progress').max = data.total; status('Đang xuất ' + data.total + ' scene…'); enable();
    } else if (event === 'progress' && data) {
      $('progress').value = data.current; status('Đang xuất ' + data.current + '/' + data.total + ': ' + data.name);
    } else if (event === 'exported') {
      busy = false; $('progress').hidden = true; lastPath = data && data.path;
      const detail = data && data.errors && data.errors.length ? '\n' + data.errors.map(error => error.page + ': ' + error.error).join('\n') : '';
      status((data && data.message || 'Xuất không thành công.') + detail, !(data && (data.success || data.cancelled))); enable();
    }
  }};
  document.querySelectorAll('[data-tab]').forEach(button => button.addEventListener('click', () => tab(button.dataset.tab)));
  document.querySelectorAll('[data-view]').forEach(button => button.addEventListener('click', () => button.setAttribute('aria-pressed',String(button.getAttribute('aria-pressed') !== 'true'))));
  function preset(views) { document.querySelectorAll('[data-view]').forEach(button => button.setAttribute('aria-pressed',String(views.includes(button.dataset.view)))); }
  $('preset4').addEventListener('click', () => preset(['ISO','TOP','FRONT','RIGHT'])); $('preset6').addEventListener('click', () => preset(['ISO','TOP','FRONT','RIGHT','BACK','LEFT'])); $('presetNone').addEventListener('click', () => preset([]));
  $('generate').addEventListener('click', () => runSettings('generate')); $('section').addEventListener('click', () => runSettings('section'));
  ['frame','fit'].forEach(action => $(action).addEventListener('click', () => runSettings(action))); $('toggleGrid').addEventListener('click', () => runSettings('grid'));
  $('toggleFrame').addEventListener('click', () => runSettings('toggle_frame'));
  $('section_axis').addEventListener('change', () => { $('customNormal').hidden = $('section_axis').value !== 'CUSTOM'; });
  $('sectionSlider').addEventListener('input', () => { $('section_percent').value = $('sectionSlider').value; }); $('section_percent').addEventListener('input', () => { $('sectionSlider').value = $('section_percent').value; });
  $('search').addEventListener('input', render); $('onlyVGD').addEventListener('change', render);
  $('selectAll').addEventListener('click', () => { filtered().forEach(scene => selected.add(scene.id)); render(); }); $('selectNone').addEventListener('click', () => { selected.clear(); render(); });
  $('update').addEventListener('click', () => modal('Cập nhật từ đối tượng','Đổi tên và căn lại ' + selected.size + ' scene VGD theo tên, hình học và thiết lập nguồn đã lưu; không cần chọn lại đối tượng. Bố cục camera chỉnh tay sẽ được thay bằng góc tự động.',() => send('update',{ids:[...selected]})));
  $('delete').addEventListener('click', () => modal('Xóa scene đã chọn','Xóa ' + selected.size + ' scene đã đánh dấu?',() => send('delete',{ids:[...selected]})));
  $('goExport').addEventListener('click', () => tab('export')); $('exportButton').addEventListener('click', () => { try { send('export',{ids:[...selected],settings:settings()}); } catch (error) { status(error.message,true); } });
  $('copyScenes').addEventListener('click', () => send('copyScenes',{ids:[...selected]}));
  $('saveScenes').addEventListener('click', () => send('saveScenes',{ids:[...selected],scope:$('sceneScope').value}));
  ['pasteScenes','loadScenes'].forEach(action => $(action).addEventListener('click', () => send(action)));
  $('sceneScope').addEventListener('change',enable);
  $('transferMode').addEventListener('change',renderTransfer);
  $('transferAll').addEventListener('click', () => { if (transfer) transferSelected = new Set(transfer.scenes.map(scene => scene.id)); renderTransfer(); });
  $('transferNone').addEventListener('click', () => { transferSelected.clear(); renderTransfer(); });
  $('transferCancel').addEventListener('click', () => { if (!busy) { clearTransfer(); send('cancelTransfer'); } });
  $('transferApply').addEventListener('click', () => { if (transfer) send('applyTransfer',{token:transfer.token,ids:[...transferSelected],mode:$('transferMode').value}); });
  $('cancel').addEventListener('click', () => send('cancel',{},false)); $('refresh').addEventListener('click', () => send('refresh',{},false));
  $('openFolder').addEventListener('click', () => { if (window.sketchup && lastPath) send('openOutput',{path:lastPath},false); });
  $('format').addEventListener('change',showFormat);
  const ratios = {'16:9':[1920,1080],'4:3':[1600,1200],'3:4':[1200,1600],'1:1':[1500,1500],'9:16':[1080,1920],'A4_L':[2480,1754],'A4_P':[1754,2480]};
  let ratioDirty = false;
  let lockedAspect = 16/9, lockedRatioText = '16:9';
  function syncRatio(updateLock = true) {
    const width = Number($('width').value), height = Number($('height').value);
    if (!(width > 0 && height > 0)) return;
    const gcd = (a,b) => b ? gcd(b,a%b) : a;
    const divisor = gcd(Math.round(width),Math.round(height));
    $('ratioInput').value = Math.round(width)/divisor + ':' + Math.round(height)/divisor;
    if (updateLock) { lockedAspect = width/height; lockedRatioText = $('ratioInput').value; }
    else if ($('ratio_locked').checked) $('ratioInput').value = lockedRatioText;
    const match = Object.entries(ratios).find(([,pair]) => Math.abs(width/height-pair[0]/pair[1]) < 0.000001);
    $('ratio').value = match ? match[0] : 'CUSTOM';
    ratioDirty = false;
  }
  function applyRatioInput() {
    if (!ratioDirty) return;
    const match = $('ratioInput').value.trim().match(/^(\d+(?:\.\d+)?)\s*[:\/]\s*(\d+(?:\.\d+)?)$/);
    if (!match || !(Number(match[1]) > 0 && Number(match[2]) > 0)) throw Error('Nhập tỷ lệ rộng:cao hợp lệ, ví dụ 3:4 hoặc 16:9.');
    const aspect = Number(match[1])/Number(match[2]);
    const edge = Math.max(Number($('width').value),Number($('height').value)) || 1920;
    const width = Math.round(aspect >= 1 ? edge : edge*aspect), height = Math.round(aspect >= 1 ? edge/aspect : edge);
    if (width < 100 || height < 100 || width > 12000 || height > 12000 || width*height > 64000000) throw Error('Tỷ lệ tạo kích thước ngoài 100–12000 px hoặc vượt 64 triệu pixel.');
    $('width').value = width; $('height').value = height; syncRatio();
    lockedAspect = aspect; lockedRatioText = match[1]+':'+match[2];
    if ($('ratio_locked').checked) $('ratioInput').value = lockedRatioText;
  }
  $('ratioInput').addEventListener('input', () => { ratioDirty = true; });
  $('ratioInput').addEventListener('change', () => { try { applyRatioInput(); } catch(error) { status(error.message,true); } });
  $('ratioInput').addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); try { applyRatioInput(); } catch(error) { status(error.message,true); } } });
  $('ratio').addEventListener('change', () => { const pair = ratios[$('ratio').value]; if (pair) { $('width').value=pair[0]; $('height').value=pair[1]; syncRatio(); } });
  $('swapRatio').addEventListener('click', () => { try {
    applyRatioInput(); const aspect = lockedAspect, text = lockedRatioText;
    const width = $('width').value; $('width').value = $('height').value; $('height').value = width; syncRatio();
    if ($('ratio_locked').checked) { lockedAspect = 1/aspect; lockedRatioText = text.split(':').reverse().join(':'); $('ratioInput').value = lockedRatioText; }
    runSettings('preview');
  } catch(error) { status(error.message,true); } });
  $('lockRatio').addEventListener('click', () => { try { applyRatioInput(); $('ratio_locked').checked = !$('ratio_locked').checked; syncRatio(); lockStatus(); } catch(error) { status(error.message,true); } });
  ['width','height'].forEach(key => $(key).addEventListener('input', () => {
    const value = Number($(key).value);
    if ($('ratio_locked').checked && Number.isFinite(value) && value > 0) {
      $(key === 'width' ? 'height' : 'width').value = Math.round(key === 'width' ? value/lockedAspect : value*lockedAspect);
    }
    syncRatio(!$('ratio_locked').checked);
  }));
  $('modalCancel').addEventListener('click',closeModal); $('modalConfirm').addEventListener('click', () => { const action = pendingModal; if (action) action(); closeModal(); });
  document.addEventListener('keydown',event => { if (event.key === 'Escape') { closeModal(); if (!$('transferModal').hidden && !busy) $('transferCancel').click(); } if (event.key === 'Enter' && !$('modal').hidden && document.activeElement === $('renameInput')) $('modalConfirm').click(); });
  $('theme').addEventListener('click', () => { document.body.classList.toggle('dark'); try { localStorage.setItem('VGD.Scenes.Theme',document.body.classList.contains('dark')?'dark':'light'); } catch (_) {} });
  enable(); showFormat();
  if (window.sketchup) window.sketchup.ready();
  setInterval(() => { if (context && !busy && $('modal').hidden && window.sketchup) send('refresh',{},false); },2000);
});
