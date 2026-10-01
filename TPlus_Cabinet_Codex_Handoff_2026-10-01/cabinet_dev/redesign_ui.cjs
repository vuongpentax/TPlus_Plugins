// One-time migration from the retained beta.1 UI; preserves field IDs and callbacks.
const fs=require('fs');
const {JSDOM}=require('jsdom');
const dom=new JSDOM(fs.readFileSync('cabinet_dev/ui_beta1.html','utf8'));
const d=dom.window.document;
const q=s=>d.querySelector(s);
const el=(tag,attrs={},html='')=>{const e=d.createElement(tag);for(const [k,v]of Object.entries(attrs))e.setAttribute(k,v);e.innerHTML=html;return e};
const originals=Object.fromEntries([...d.querySelectorAll('[id]')].map(e=>[e.id,e]));
const get=id=>originals[id]||d.getElementById(id);
const field=id=>get(id).closest('.form-group,.checkbox-row');
const section=(title)=>el('section',{class:'settings-section'},'<h3>'+title+'</h3>');
const details=(title,id)=>el('details',{class:'advanced',...(id?{id}:{})},'<summary>'+title+'</summary>');
const scripts=[...d.querySelectorAll('script')];
const header=q('.header');header.querySelector('.header-left').innerHTML='<span>T+ CABINET <small>4.3 · beta 4</small></span>';
const preset=q('.preset-section');const save=details('Lưu / xóa mẫu tủ');save.querySelector('summary').textContent='Lưu / xóa mẫu tủ';save.append(q('.preset-row'));preset.append(save);
const dim=q('#card_dim .card-body');
const frame=[...d.querySelectorAll('#card_frame .subsection')];
const bevel=q('.card:not([id]) .card-body');
const doors=q('#card_doors .card-body');
const drawers=q('#card_drawers .card-body');
const over=q('#card_overheight .card-body');
const status=q('#model_status');status.removeAttribute('style');
const live=field('live_update');live.removeAttribute('style');live.querySelector('label').textContent='Tự cập nhật khi sửa thông số';
const update=q('#btn_update');update.textContent='Cập nhật';
const draw=q('[onclick="drawToolCabinet()"]');draw.textContent='Vẽ 3 điểm';
const place=q('[onclick="placeCabinet()"]');place.removeAttribute('style');place.textContent='Đặt tủ mới';place.id='btn_place';
d.body.replaceChildren(header);
const context=el('div',{class:'context-bar'},'<span id="selection_mode">Tạo tủ mới</span><span id="size_summary"></span>');d.body.append(context);
const workspace=el('div',{class:'workspace'}),nav=el('nav',{class:'side-menu','aria-label':'Nhóm thông số'}),content=el('main',{id:'settings_content'});
workspace.append(nav,content);d.body.append(workspace);
const panels={};
const paths=['M3 5h18v14H3z M9 5v14 M15 5v14','M4 3h16v18H4z M4 7h16 M4 17h16','M3 3h18v18H3z M11 3v18 M11 10h10 M3 15h8','M4 3h16v18H4z M12 3v18 M9 11v3 M15 11v3','M3 3h18v18H3z M3 9h18 M3 15h18 M10 6h4 M10 12h4 M10 18h4'];
[['general','Tổng thể'],['frame','Thùng tủ'],['compartments','Chia khoang'],['doors','Cánh tủ'],['drawers','Ngăn kéo']].forEach(([id,title],i)=>{
 const b=el('button',{type:'button',class:'menu-button','data-page':id,'aria-controls':'page_'+id,onclick:"selectPage('"+id+"')"},'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="'+paths[i]+'"/></svg><span>'+title+'</span>');nav.append(b);
 const p=el('section',{id:'page_'+id,class:'menu-page',hidden:''},'<h2>'+title+'</h2>');panels[id]=p;content.append(p);
});
nav.append(el('div',{class:'menu-note'},'DỰNG HÌNH<br><span>Đơn vị: mm</span>'));
const tabs=(parent,group,items)=>{const bar=el('div',{class:'subnav','aria-label':'Mục '+group});parent.append(bar);const out={};items.forEach(([id,title],i)=>{bar.append(el('button',{type:'button','data-subgroup':group,'data-subtab':id,onclick:"selectSubpage('"+group+"','"+id+"')",'aria-controls':'sub_'+group+'_'+id},title));const p=el('div',{id:'sub_'+group+'_'+id,'data-subpanel':group,hidden:''});parent.append(p);out[id]=p});return out};
panels.general.append(preset);
const dimensions=section('Kích thước phủ bì');dimensions.append(dim);panels.general.append(dimensions);
const snap=field('snap_step');snap.remove();
const modules=section('Ghép module');['module_mode','module_widths','module_target_w'].forEach(id=>modules.append(field(id)));const moduleHint=frame[4].querySelector('p');moduleHint.id='module_hint';modules.append(moduleHint);panels.general.append(modules);
const genAdv=details('Nâng cao · bước bắt khi vẽ');genAdv.append(snap);panels.general.append(genAdv);
panels.general.append(el('p',{class:'hint'},'W/D/H gồm cánh và hậu; chiều cao gồm chân và nẹp.'));
const f=tabs(panels.frame,'frame',[['sides','Hông'],['caps','Nóc–đáy'],['back','Hậu'],['base','Chân']]);
f.sides.append(frame[0]);f.caps.append(frame[2]);f.back.append(frame[1]);f.base.append(frame[3]);
f.back.append(el('div',{class:'checkbox-row'},'<input type="checkbox" id="back_groove_auto" checked><label for="back_groove_auto">Ngậm hậu = ½ dày hồi</label>'));
f.back.append(el('div',{class:'form-group'},'<label for="back_groove_depth">Ngậm hậu mỗi bên (mm)</label><input type="number" id="back_groove_depth" value="8.75" min="0" step="0.5">'));
const c=tabs(panels.compartments,'compartments',[['dividers','Vách đứng'],['shelves','Đợt ngang'],['tiers','Chia tầng']]);
['div_count','div_pos','auto_divider_wide','max_compartment_w'].forEach(id=>c.dividers.append(field(id)));
['shelf_count','shelf_type','shelf_side_clearance','shelf_front_setback'].forEach(id=>c.shelves.append(field(id)));c.tiers.append(over);
c.dividers.append(el('p',{class:'hint'},'Vách và đợt áp dụng trong từng module.'));
const dt=tabs(panels.doors,'doors',[['front','Cấu tạo cánh'],['glass','Khung/kính'],['handle','Mép móc tay']]);dt.front.append(doors);dt.handle.append(bevel);
const doorFields=el('div',{id:'door_fields'});[...doors.children].slice(1).forEach(x=>doorFields.append(x));doors.append(doorFields);
doorFields.prepend(el('div',{class:'form-group'},'<label for="door_style">Kiểu dựng</label><select id="door_style" onchange="refreshContextUI();if(this.value===\'Kính khung kim loại\')selectSubpage(\'doors\',\'glass\')"><option>Ván phẳng</option><option>Kính khung kim loại</option></select>'));
dt.glass.append(el('p',{class:'hint'},'Cánh kính khung kim loại. Khung 4 cạnh và kính giữa chiều dày; dùng chung khe cánh.'));
[['metal_frame_width','Bản khung',20],['metal_frame_depth','Dày khung',20],['glass_thickness','Dày kính',5]].forEach(([id,label,n])=>dt.glass.append(el('div',{class:'form-group'},'<label for="'+id+'">'+label+' (mm)</label><input type="number" id="'+id+'" value="'+n+'" min="1" step="0.5">')));
dt.glass.append(el('div',{class:'preset-row'},[20,30,40].map(n=>'<button type="button" class="btn-secondary" onclick="document.getElementById(\'metal_frame_width\').value='+n+';debouncedUpdateCabinet()">Bản '+n+'</button>').join('')));
[['metal_finish','Màu khung',['Đen','Champagne','Inox']],['glass_finish','Màu kính',['Trong','Trà','Xám']]].forEach(([id,label,options])=>dt.glass.append(el('div',{class:'form-group'},'<label for="'+id+'">'+label+'</label><select id="'+id+'">'+options.map(v=>'<option>'+v+'</option>').join('')+'</select>')));
dt.glass.append(el('p',{class:'hint'},'Áp dụng cho các cánh mở của tủ đang chỉnh. Màu khung và kính là hai material riêng trong SketchUp.'));
dt.handle.append(el('p',{class:'hint'},'Vát mép chỉ dùng cho cánh ván và mặt ngăn kéo; không áp dụng cho cánh kính khung kim loại.'));
// A commonly used top gap stays available without opening four separate edge gaps.
const topGap=el('div',{class:'form-group',id:'simple_top_gap'},'<label for="door_top_gap">Khe trên / móc tay</label>');
const topInput=get('door_top_gap');topInput.type='number';topInput.step='0.5';topInput.setAttribute('oninput',"document.getElementById('door_gap_top').value=this.value");topGap.append(topInput);get('door_gap_simple_ui').append(topGap);
dt.handle.append(el('p',{class:'hint'},'Vát mép dùng chung cho cánh và mặt ngăn kéo. Xà chặn ở đây dành cho cánh; xà che khe mặt hộc nằm trong Ngăn kéo.'));
panels.drawers.append(drawers);
const drawerFields=el('div',{id:'drawer_fields'});[...drawers.children].slice(2).forEach(x=>drawerFields.append(x));drawers.append(drawerFields);
const existingDrawerFields=[...drawerFields.children];
const dr=tabs(drawerFields,'drawers',[['layout','Bố trí'],['frame','Khung két'],['front','Mặt hộc'],['box','Thùng hộc']]);
existingDrawerFields.forEach(x=>dr.layout.append(x));
dr.layout.prepend(el('div',{class:'form-group'},'<label for="drawer_columns">Cụm trong mỗi khoang</label><select id="drawer_columns"><option value="1">1 cụm</option><option value="2">2 cụm cạnh nhau</option></select>'));
get('drawer_count').closest('.form-group').querySelector('label').textContent='Số tầng mỗi cụm';
['group_drawer_inner_offset','group_drawer_hinge_sp','drawer_hinge_sp_hint'].forEach(id=>dr.frame.append(get(id)));
[['drawer_frame_depth','Sâu két phủ bì (0 = tự động)',0],['drawer_frame_rail_width','Bản xà đáy trước/sau',50]].forEach(([id,label,n])=>dr.frame.append(el('div',{class:'form-group'},'<label for="'+id+'">'+label+'</label><input type="number" id="'+id+'" value="'+n+'" min="0" step="0.5">')));
dr.frame.append(el('div',{class:'checkbox-row'},'<input type="checkbox" id="drawer_frame_stop_rail" checked><label for="drawer_frame_stop_rail">Xà đón mặt hộc</label>'));
[['drawer_frame_stop_rail_h','Cao xà đón',50],['drawer_frame_stop_rail_drop','Hạ xà so với dưới nóc',0]].forEach(([id,label,n])=>dr.frame.append(el('div',{class:'form-group'},'<label for="'+id+'">'+label+'</label><input type="number" id="'+id+'" value="'+n+'" min="0" step="0.5">')));
dr.box.append(el('div',{class:'form-group'},'<label for="drawer_bottom_mode">Kiểu đáy hộc</label><select id="drawer_bottom_mode"><option>Âm hai bên</option><option>Âm bốn phía</option><option>Phủ dưới</option></select>'));
dr.front.append(get('group_drawer_gap'));
const box=section('Kết cấu và khoảng hở');dr.box.append(box);
['drawer_ray_space','drawer_back_clearance','drawer_box_bottom_lift','drawer_box_top_clearance','drawer_bottom_offset','drawer_box_t','drawer_bottom_t'].forEach(id=>box.append(field(id)));
const rails=details('Xà che khe mặt ngăn kéo');rails.id='drawer_rail_details';['group_drawer_backing_rail','group_drawer_backing_rail_h','drawer_backing_hint'].forEach(id=>rails.append(get(id)));dr.front.append(rails);
dr.front.append(el('button',{type:'button',class:'btn-secondary link-button',onclick:"selectPage('doors');selectSubpage('doors','handle')"},'Chỉnh vát mép mặt hộc →'));
const footer=el('footer',{class:'fixed-actions'});footer.append(status,live);const actions=el('div',{class:'action-bar'});actions.append(place,draw,update);footer.append(actions);d.body.append(footer);
// Associate every existing text label with its original input for easier clicking.
d.querySelectorAll('.form-group').forEach(g=>{const l=g.querySelector('label'),i=g.querySelector('input,select');if(l&&i&&!l.htmlFor)l.htmlFor=i.id});
d.querySelectorAll('.sub-title').forEach(e=>e.remove());
d.querySelectorAll('.card-body').forEach(e=>e.classList.remove('card-body'));
d.body.append(...scripts);
const css=fs.readFileSync('cabinet_dev/menu.css','utf8');d.head.append(el('style',{},css));
const js=fs.readFileSync('cabinet_dev/menu.js','utf8');scripts[0].textContent=js+'\n'+scripts[0].textContent;
let html=dom.serialize();
html=html.replace('T+_Cabinet UI v4.3.0 beta','T+ Cabinet 4.3.0-beta.6');
html=html.replace("document.getElementById('btn_update').disabled = !selectedPid;","document.getElementById('btn_update').disabled = !selectedPid;\n      document.getElementById('selection_mode').textContent = selectedPid ? 'Đang sửa tủ đã chọn' : 'Tạo tủ mới';");
html=html.replace('        renderDrawerGapUI();\n      } finally', '        renderDrawerGapUI();\n        refreshContextUI();\n      } finally');
html=html.replace("      initTheme();", "      initMenu();\n      initTheme();");
html=html.replaceAll('-- Chọn Preset --','-- Chọn mẫu tủ --');
html=html.replace('        back_mode:', `        door_style: document.getElementById('door_style').value,
        metal_frame_width: getNumValue('metal_frame_width',20),
        metal_frame_depth: getNumValue('metal_frame_depth',20),
        glass_thickness: getNumValue('glass_thickness',5),
        metal_finish: document.getElementById('metal_finish').value,
        glass_finish: document.getElementById('glass_finish').value,
        back_mode:`);
html=html.replaceAll('🌙','Tối').replaceAll('☀️','Sáng');
html=html.replace('        back_mode:', `        back_groove_auto: document.getElementById('back_groove_auto').checked,
        back_groove_depth: getNumValue('back_groove_depth',8.75),
        drawer_columns: getNumValue('drawer_columns',1),
        drawer_frame_depth: getNumValue('drawer_frame_depth',0),
        drawer_frame_rail_width: getNumValue('drawer_frame_rail_width',50),
        drawer_frame_stop_rail: document.getElementById('drawer_frame_stop_rail').checked,
        drawer_frame_stop_rail_h: getNumValue('drawer_frame_stop_rail_h',50),
        drawer_frame_stop_rail_drop: getNumValue('drawer_frame_stop_rail_drop',0),
        drawer_bottom_mode: document.getElementById('drawer_bottom_mode').value,
        back_mode:`);
fs.writeFileSync('cabinet_work/TPlus_Cabinet/TPlus_Cabinet_UI.html',html);
console.log('UI migrated; original control count:',new JSDOM(fs.readFileSync('cabinet_dev/ui_beta1.html','utf8')).window.document.querySelectorAll('input,select').length,'new:',d.querySelectorAll('input,select').length);
