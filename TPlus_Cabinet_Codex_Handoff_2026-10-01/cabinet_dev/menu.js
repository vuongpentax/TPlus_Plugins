// Menu navigation never sends modeling callbacks or changes parameter values.
function selectPage(name) {
  var page=document.getElementById('page_'+name);if(!page)return;
  document.querySelectorAll('.menu-page').forEach(function(p){p.hidden=p!==page;});
  document.querySelectorAll('[data-page]').forEach(function(b){if(b.dataset.page===name)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
  document.getElementById('settings_content').scrollTop=0;
  try{localStorage.setItem('tplus_menu_page',name);}catch(e){}
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
  byId('door_fields').hidden=byId('opt_door').value==='Không Cánh';
  var glass=byId('door_style').value==='Kính khung kim loại'&&byId('opt_door').value!=='Không Cánh';
  document.querySelector('[data-subgroup="doors"][data-subtab="glass"]').hidden=!glass;
  if(!glass&&!byId('sub_doors_glass').hidden)selectSubpage('doors','front');
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
  var saved='general';try{saved=localStorage.getItem('tplus_menu_page')||saved;}catch(e){}
  selectPage(document.getElementById('page_'+saved)?saved:'general');
  selectSubpage('frame','sides');selectSubpage('compartments','dividers');selectSubpage('doors','front');selectSubpage('drawers','layout');
  document.addEventListener('input',refreshContextUI);document.addEventListener('change',refreshContextUI);
  refreshContextUI();
}
