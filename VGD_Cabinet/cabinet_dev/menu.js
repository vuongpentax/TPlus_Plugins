// Menu navigation never sends modeling callbacks or changes parameter values.
function selectPage(name) {
  var page=document.getElementById('page_'+name);if(!page)return;
  document.querySelectorAll('.menu-page').forEach(function(p){p.hidden=p!==page;});
  document.querySelectorAll('[data-page]').forEach(function(b){if(b.dataset.page===name)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
  document.getElementById('settings_content').scrollTop=0;
  try{localStorage.setItem('vgd_menu_page',name);}catch(e){}
}
function selectSubpage(group,name) {
  var page=document.getElementById('sub_'+group+'_'+name);if(!page)return;
  document.querySelectorAll('[data-subpanel="'+group+'"]').forEach(function(p){p.hidden=p!==page;});
  document.querySelectorAll('[data-subgroup="'+group+'"]').forEach(function(b){b.setAttribute('aria-pressed',String(b.dataset.subtab===name));});
  document.getElementById('settings_content').scrollTop=0;
}
function refreshContextUI() {
  var byId=function(id){return document.getElementById(id);};
  var showRow=function(id,yes){var e=byId(id);if(e)e.closest('.form-group').hidden=!yes;};
  var mode=byId('back_mode').value;
  showRow('t_back',mode!=='Không');showRow('back_recess',mode==='Âm');
  byId('back_groove_auto').closest('.checkbox-row').hidden=mode!=='Âm';
  showRow('back_groove_depth',mode==='Âm'&&!byId('back_groove_auto').checked);
  var independent=byId('module_mode').value==='Độc lập';
  showRow('module_widths',independent);showRow('module_target_w',independent&&byId('module_widths').value.trim()==='');
  byId('module_hint').hidden=!independent;
  showRow('curve_w',byId('opt_left_side').value==='Bo Cong'||byId('opt_right_side').value==='Bo Cong');
  showRow('bevel_lip',byId('front_bevel').checked);showRow('door_stop_rail_h',byId('door_stop_rail').checked);
  showRow('drawer_bevel_lip',byId('drawer_bevel').checked);
  byId('door_fields').hidden=byId('opt_door').value==='Không Cánh';
  var glass=byId('door_style').value==='Kính khung kim loại'&&byId('opt_door').value!=='Không Cánh';
  document.querySelector('[data-subgroup="doors"][data-subtab="glass"]').hidden=!glass;
  if(!glass&&!byId('sub_doors_glass').hidden)selectSubpage('doors','front');
  var pano=byId('door_style').value==='Pano khung gỗ'&&byId('opt_door').value!=='Không Cánh';
  document.querySelector('[data-subgroup="doors"][data-subtab="pano"]').hidden=!pano;
  if(!pano&&!byId('sub_doors_pano').hidden)selectSubpage('doors','front');
  showRow('pano_mid_rail',Number(byId('pano_panel_count').value)>1);
  showRow('max_door_w',byId('auto_door_count').checked);
  byId('drawer_fields').hidden=byId('opt_drawer').value==='Không';
  var frame=byId('opt_drawer').value==='Âm';
  document.querySelector('[data-subgroup="drawers"][data-subtab="frame"]').hidden=!frame;
  if(!frame&&!byId('sub_drawers_frame').hidden)selectSubpage('drawers','layout');
  showRow('drawer_frame_stop_rail_h',byId('drawer_frame_stop_rail').checked);
  showRow('drawer_frame_stop_rail_drop',byId('drawer_frame_stop_rail').checked);
  showRow('drawer_bottom_offset',byId('drawer_bottom_mode').value!=='Phủ dưới');
  showRow('shelf_type',Number(byId('shelf_count').value)>0);
  showRow('shelf_side_clearance',Number(byId('shelf_count').value)>0);
  showRow('shelf_front_setback',Number(byId('shelf_count').value)>0);
  byId('size_summary').textContent=['w','d','h'].map(function(id){return byId(id).value||'—';}).join(' × ')+' mm';
}
function initMenu() {
  var saved='general';try{saved=localStorage.getItem('vgd_menu_page')||saved;}catch(e){}
  selectPage(document.getElementById('page_'+saved)?saved:'general');
  selectSubpage('frame','sides');selectSubpage('compartments','dividers');selectSubpage('doors','front');selectSubpage('drawers','layout');
  document.addEventListener('input',refreshContextUI);document.addEventListener('change',refreshContextUI);
  refreshContextUI();
}

var descriptionContract=null, descriptionRequestId=0, descriptionPreview=null, descriptionDraftParams=null;
function receiveDescriptionContract(contract) { descriptionContract=contract; }
function invalidateDescriptionPreview() {
  descriptionRequestId++;descriptionPreview=null;
  document.getElementById('btn_description_apply').disabled=true;
  document.getElementById('btn_description_partial').disabled=true;
  document.getElementById('btn_description_partial').hidden=true;
  document.getElementById('description_review').textContent='Chưa kiểm tra / nội dung đã thay đổi.';
}
function insertDescriptionExample() {
  if(!descriptionContract){showModelStatus('Đợi plugin nạp hướng dẫn.',true);return;}
  document.getElementById('description_text').value=JSON.stringify(descriptionContract.example,null,2);
  invalidateDescriptionPreview();
}
function showDescriptionPrompt() {
  if(!descriptionContract){showModelStatus('Đợi plugin nạp hướng dẫn.',true);return;}
  var text='Phân tích ảnh tủ để dựng bằng VGD_Cabinet 4.4 beta 2. Hỏi tôi rộng/sâu/cao mong muốn nếu chưa có; không đo kích thước thật từ ảnh không có tỷ lệ. Chỉ xuất một khối JSON theo mẫu bên dưới, đơn vị mm. parameters chỉ dùng các tên trong danh sách mặc định; giữ đúng kiểu dữ liệu và giá trị lựa chọn. Không xuất mã Ruby/JavaScript. Các thông số không xác định có thể bỏ để plugin dùng mặc định, trừ w,d,h bắt buộc. Ghi giả định vào assumptions; tên thông số ước lượng có trong parameters vào estimated_fields. Cấu tạo chưa hỗ trợ ghi vào unsupported_features, không âm thầm lược bỏ. Các module chỉ khác rộng, dùng chung cấu hình cánh/đợt/hộc; không có modules dạng cây hay cấu hình riêng từng khoang. door_count là số cánh của từng module, drawer_count là số tầng mỗi cụm; không phải tổng cả tủ. Với số cánh/vách hoặc tầng đã chỉ định, không bật tự động tương ứng. Móc tay cánh front_bevel và móc tay hộc drawer_bevel độc lập. Kích thước phủ bì gồm cánh/hậu, cao gồm chân/nẹp.\n\nMẪU:\n'+JSON.stringify(descriptionContract.example,null,2)+'\n\nTHÔNG SỐ MẶC ĐỊNH (không phải số đo từ ảnh):\n'+JSON.stringify(descriptionContract.defaults,null,2)+'\n\nGIÁ TRỊ LỰA CHỌN HỢP LỆ:\n'+JSON.stringify(descriptionContract.enums,null,2);
  var box=document.getElementById('description_prompt_box'),area=document.getElementById('description_prompt');
  area.value=text;box.open=true;area.focus();area.select();
}
function checkDescription() {
  invalidateDescriptionPreview();
  document.getElementById('description_review').textContent='Đang kiểm tra…';
  if(window.sketchup)window.sketchup.preview_description({text:document.getElementById('description_text').value,request_id:descriptionRequestId});
}
function receiveDescriptionPreview(id,result) {
  if(id!==descriptionRequestId)return; // Ignore late replies after edits/new requests.
  descriptionPreview=result;
  var review=document.getElementById('description_review');review.replaceChildren();
  function line(text){var p=document.createElement('p');p.textContent=text;review.appendChild(p);}
  if(result.error){line(result.error);return;}
  line(result.summary);
  (result.module_summary||[]).forEach(function(s,i){line('Module '+(i+1)+': '+s);});
  line('Ước lượng: '+(result.estimated_fields.join(', ')||'không khai báo'));
  result.assumptions.forEach(function(s){line('Giả định: '+s);});
  (result.adjustments||[]).forEach(function(s){line('Quy tắc bộ dựng: '+s);});
  result.unsupported_features.forEach(function(s){line('Chưa hỗ trợ — sẽ bỏ qua nếu dựng cơ bản: '+s);});
  if(result.can_apply_partial)line('Có thể dựng phần cơ bản sau khi xác nhận bỏ qua. Kích thước w/d/h dùng nguyên cho tủ cơ bản, không tự trừ kệ bên hoặc chừa phần chưa hỗ trợ.');
  var details=document.createElement('details'),summary=document.createElement('summary');
  summary.textContent='Thông số không khai báo · mặc định/quy tắc ('+result.defaulted_fields.length+')';details.appendChild(summary);
  var pre=document.createElement('pre');pre.textContent=result.defaulted_fields.map(function(k){return k+': '+result.parameters[k];}).join('\n');details.appendChild(pre);review.appendChild(details);
  var all=document.createElement('details'),title=document.createElement('summary'),values=document.createElement('pre');
  title.textContent='Toàn bộ cấu hình đã kiểm tra';values.textContent=JSON.stringify(result.parameters,null,2);
  all.appendChild(title);all.appendChild(values);review.appendChild(all);
  document.getElementById('btn_description_apply').disabled=!result.can_apply;
  document.getElementById('btn_description_partial').hidden=!result.can_apply_partial;
  document.getElementById('btn_description_partial').disabled=!result.can_apply_partial;
}
function applyDescription(partial) {
  if(!descriptionPreview)return;
  var data={text:document.getElementById('description_text').value,request_id:descriptionRequestId};
  if(partial===true){
    if(!descriptionPreview.can_apply_partial)return;
    var message='DỰNG PHẦN CƠ BẢN, KHÔNG DỰNG ĐẦY ĐỦ MẪU ẢNH\n\n'+descriptionPreview.summary+'\n'+descriptionPreview.module_summary.join('\n')+'\n\nBỎ QUA:\n'+descriptionPreview.unsupported_features.map(function(s,i){return (i+1)+'. '+s;}).join('\n')+'\n\nDùng nguyên kích thước đã nhập cho tủ cơ bản. KHÔNG tự trừ chiều rộng kệ bên hoặc chừa phần chưa hỗ trợ. Kiểm tra/sửa kích thước trong bảng trước khi Đặt tủ mới.\n\nĐồng ý bỏ qua các mục trên và nạp bản nháp?';
    if(!window.confirm(message))return;
    data.allow_partial=true;data.acknowledged_features=descriptionPreview.unsupported_features.slice();
  }else if(!descriptionPreview.can_apply)return;
  document.getElementById('btn_description_apply').disabled=true;
  document.getElementById('btn_description_partial').disabled=true;
  if(window.sketchup)window.sketchup.apply_description(data);
}
function applyDescriptionDraft(params,omittedFeatures) {
  if(updateTimer){clearTimeout(updateTimer);updateTimer=null;}
  descriptionDraftParams=params;setSelectedCabinet(null);selectedModel=null;
  updateFormFromRuby(params);
  // Legacy auto-door UI calculates against total width, not each independent module.
  // Keep the validated values; geometry resolves automatic rules per module at placement.
  Object.keys(params).forEach(function(k){var e=document.getElementById(k);if(e){if(e.type==='checkbox')e.checked=params[k];else e.value=params[k];}});
  refreshContextUI();
  document.getElementById('preset_select').value='';
  document.getElementById('live_update').checked=false;
  var partial=Array.isArray(omittedFeatures)&&omittedFeatures.length>0;
  document.getElementById('selection_mode').textContent=partial?'Tủ cơ bản từ mô tả':'Tủ mới từ mô tả';
  var notice=document.getElementById('description_draft_notice');notice.hidden=!partial;
  notice.textContent=partial?'Dựng cơ bản · bỏ qua '+omittedFeatures.length+' chi tiết. Kích thước dùng nguyên, không tự chừa kệ bên. Xem danh sách trong Dựng từ mô tả; kiểm tra thông số trước khi đặt.':'';
  document.getElementById('btn_description_leave').hidden=false;
  showModelStatus('Đã nạp bản nháp. Kiểm tra thông số rồi bấm Đặt tủ mới; chưa thay đổi model.',false);
  selectPage('general');
}
function leaveDescriptionDraft() {
  descriptionDraftParams=null;
  document.getElementById('description_draft_notice').hidden=true;
  document.getElementById('btn_description_leave').hidden=true;
}
function returnToSelectedCabinet() {
  if(updateTimer){clearTimeout(updateTimer);updateTimer=null;}
  if(window.sketchup)window.sketchup.leave_description_draft(null);
}
