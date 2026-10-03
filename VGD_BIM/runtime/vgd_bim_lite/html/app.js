'use strict';
const $ = id => document.getElementById(id);
let config = {}, mappingRows = [], activeRow = null, selectionCount = 0;
const labels = {category:'Category',item_type:'Item Type',code:'Code',description:'Description',unit:'Unit',quantity_method:'Quantity Method',zone:'Zone',floor:'Floor',include_boq:'Include in BOQ',finish_code:'Finish Code',manufacturer:'Manufacturer',model_number:'Model Number',note:'Note'};
const unitLabels = {m2:'m²',m:'md',m3:'m³',pcs:'cái',set:'bộ',lot:'lô',kg:'kg',none:'—'};
function node(tag, text, cls) {const el = document.createElement(tag); if(text !== undefined) el.textContent = text; if(cls) el.className = cls; return el;}
function call(name, ...args) {if(window.sketchup && window.sketchup[name]) window.sketchup[name](...args);}
function message(text, error=false) {$('message').textContent=text; $('message').className=error?'error':'';}
function card(title) {const c=node('section',undefined,'card'); c.append(node('h2',title)); $('content').append(c); return c;}
function button(text, handler, cls) {const b=node('button',text,cls); b.onclick=()=>{try{handler()}catch(error){message(error.message,true)}}; return b;}
function badge(text) {return node('span',text,'badge '+(text==='ERROR'?'error':text==='WARNING'?'warning':''));}
function table(parent, headers, rows, render) {const wrap=node('div',undefined,'table-wrap'),t=node('table'),head=node('thead'),tr=node('tr'); headers.forEach(h=>tr.append(node('th',h)));head.append(tr);t.append(head);const body=node('tbody');rows.forEach((row,i)=>{const tr=node('tr');render(row,tr,i);body.append(tr)});t.append(body);wrap.append(t);parent.append(wrap);return body;}
function cell(tr,value) {const td=node('td');value instanceof Node?td.append(value):td.textContent=value==null?'':String(value);tr.append(td);return td;}
function metrics(values) {const wrap=node('div',undefined,'metrics');Object.entries(values).forEach(([k,v])=>{const m=node('div',undefined,'metric');m.append(node('b',String(v)),node('span',k));wrap.append(m)});$('content').append(wrap);}
function fields(parent,values,enable=false) {
  const preset=node('select');preset.append(new Option('Chọn preset…',''));(config.presets||[]).forEach((p,i)=>preset.append(new Option(p.name,String(i))));parent.append(preset);
  const grid=node('div',undefined,'fields');parent.append(grid);
  Object.keys(labels).forEach(key=>{
    const row=node('div',undefined,'field'),check=node('input');check.type='checkbox';check.id='update-'+key;check.checked=enable && Object.prototype.hasOwnProperty.call(values,key);
    const body=node('div'),label=node('label',labels[key]);label.htmlFor='field-'+key;let input;
    const options=key==='category'?config.categories:key==='unit'?config.units:key==='quantity_method'?config.methods:key==='include_boq'?['true','false']:null;
    if(options){input=node('select');input.append(new Option(values[key]===null?'— Mixed / Keep Existing —':'—',''));options.forEach(value=>input.append(new Option(unitLabels[value]||value,value)));}
    else {input=node(key==='note'?'textarea':'input');if(key!=='note')input.type='text';input.placeholder=values[key]===null?'Mixed — keep existing':'';}
    input.id='field-'+key;input.value=values[key]==null?'':String(values[key]);input.disabled=!check.checked;
    check.onchange=()=>{input.disabled=!check.checked};input.oninput=()=>{check.checked=true};body.append(label,input);row.append(check,body);grid.append(row);
  });
  preset.onchange=()=>{if(preset.value==='')return;const data=config.presets[Number(preset.value)];Object.keys(labels).forEach(key=>{if(!Object.prototype.hasOwnProperty.call(data,key))return;$('update-'+key).checked=true;$('field-'+key).disabled=false;$('field-'+key).value=String(data[key]);});};
  parent.append(node('p','Chỉ trường được đánh dấu mới cập nhật. Bỏ dấu để giữ giá trị hiện có; nhập trống để xóa giá trị.','muted hint'));
}
function formData() {const data={};Object.keys(labels).forEach(key=>{if(!$('update-'+key).checked)return;const value=$('field-'+key).value;if(key==='include_boq'&&value==='')throw Error('Chọn true hoặc false cho Include in BOQ.');data[key]=key==='include_boq'?value==='true':value});return data;}
function information(data) {
  $('content').replaceChildren();selectionCount=data.count;activeRow=null;
  const c=card(config.mode==='convert_selection'?'CONVERT SELECTION':'VGD BIM INFORMATION');c.append(node('p',`Selected Objects: ${data.count}`));fields(c,data.fields,false);
  const actions=node('footer');const convert=config.mode==='convert_selection';const apply=button(convert?'Preview Convert':'APPLY',()=>call(convert?'preview_convert':'apply',JSON.stringify(convert?{data:formData()}:formData())),'primary');apply.disabled=!data.count;actions.append(apply);if(!convert)actions.append(button('CLEAR VGD DATA',()=>call('clear')));c.append(actions);
  const raw=card('SKETCHUP DATA · READ ONLY');
  table(raw,['Type / Source','Instance / Definition','Tag / Material','W × D × H (mm)','Status'],data.objects,(r,tr)=>{cell(tr,`${r.entity_type} / ${r.source}`);cell(tr,`${r.instance_name||'(Unnamed)'} / ${r.definition_name}`);cell(tr,`${r.tag} / ${r.material||'—'}`);cell(tr,Object.values(r.dimensions).map(n=>n.toFixed(1)).join(' × '));cell(tr,badge(r.locked?'LOCKED':r.status));});
}
function scan(data) {
  $('content').replaceChildren();metrics(data.summary);const components=card('RAW COMPONENT REPORT');
  table(components,['Definition','Instance Name','Instances','Tag / Material','W × D × H (mm)'],data.components,(r,tr)=>{cell(tr,r.definition_name||'(Unnamed)');cell(tr,r.names.join(', '));cell(tr,r.instances);cell(tr,r.tags.join(', ')+' / '+(r.material||'—'));cell(tr,Object.values(r.dimensions).map(n=>n.toFixed(1)).join(' × ')+(r.dimension_variants>1?` (${r.dimension_variants} variants)`:''));});
  const materials=card('RAW QUANTITY · MATERIAL AREA');materials.append(node('p',data.area_note,'muted hint'));table(materials,['Material','Front Area (m²)','Back Area (m²)','Front Faces'],data.materials,(r,tr)=>{cell(tr,r.material);cell(tr,r.area.toFixed(3));cell(tr,r.back_area.toFixed(3));cell(tr,r.faces);});
}
function editMapping(row) {
  activeRow=row;const old=$('mapping-editor');if(old)old.remove();const c=card(`MAP: ${row.source_value||'(Unnamed definition)'}`);c.id='mapping-editor';c.append(node('p',`${row.instances} occurrences · ${row.eligible} writable objects · ${row.protected} protected occurrences`));fields(c,row.suggestion.data,true);
  const save=node('input');save.type='checkbox';save.id='save-rule';save.checked=row.kind==='material';const label=node('label',' Save reusable Mapping Rule');label.prepend(save);c.append(label);
  const actions=node('footer');actions.append(button(row.kind==='material'?'Preview Material Rule':'Preview Convert',()=>call('preview_convert',JSON.stringify({index:row.index,data:formData(),save_rule:save.checked})),'primary'));c.append(actions);c.scrollIntoView({behavior:'auto',block:'start'});
}
function mapping(data) {
  mappingRows=data;activeRow=null;$('content').replaceChildren();const c=card('MAP / CONVERT MODEL');c.append(node('p','Xem gợi ý, chỉnh dữ liệu, rồi Preview → Confirm Convert. VGD hiện có và đối tượng khóa được bảo vệ. Material chỉ lưu rule.','muted hint'));
  const search=node('input');search.type='search';search.placeholder='Filter source…';search.className='search';c.append(search);
  const body=table(c,['Source','Instances / Eligible','Suggestion','Confidence / Source','Status','Actions'],data,(r,tr)=>{cell(tr,`${r.source_value||'(Unnamed)'} (${r.kind})`);cell(tr,`${r.instances} / ${r.eligible}`);cell(tr,`${r.suggestion.data.category||'—'} / ${r.suggestion.data.item_type||'—'} / ${r.suggestion.data.quantity_method||'—'}`);cell(tr,`${r.suggestion.confidence} / ${r.suggestion.source}`);cell(tr,badge(r.status||'REVIEW'));const actions=node('div',undefined,'actions');actions.append(button('Edit / Apply',()=>editMapping(r)),button('Ignore',()=>{tr.classList.toggle('ignored')}));cell(tr,actions);});
  search.oninput=()=>Array.from(body.children).forEach((tr,i)=>{tr.hidden=!data[i].source_value.toLowerCase().includes(search.value.toLowerCase())});
}
function validation(data) {
  $('content').replaceChildren();const count=severity=>data.filter(r=>r.issues.some(i=>i.severity===severity)).length;
  metrics({'Objects Scanned':data.length,'Valid':data.filter(r=>r.status==='VGD READY').length,'Warnings':count('WARNING'),'Errors':count('ERROR'),'Unclassified':data.filter(r=>r.status==='UNCLASSIFIED').length});const c=card('VGD BIM VALIDATION');c.append(node('p','Click kết quả để mở đúng đường dẫn lồng nhau và chọn đối tượng trong SketchUp.','muted'));
  table(c,['Status','Object / Path','Issues'],data,(r,tr)=>{tr.className='clickable';tr.onclick=()=>call('select_entity',r.index);cell(tr,badge(r.status));cell(tr,r.instance_name||r.definition_name||r.path||'(Unnamed)');const issues=node('div');r.issues.forEach(i=>{const p=node('p');p.append(badge(i.severity),document.createTextNode(' '+i.message));issues.append(p)});cell(tr,issues);});
}
function rules(data) {
  $('content').replaceChildren();const c=card('MAPPING RULES · JSON');c.append(node('p','Rules lưu cùng file SketchUp; Export/Import để dùng trên model khác. source_type: definition_name, instance_name, tag, material.','muted hint'));const text=node('textarea');text.id='rules-json';text.className='rules';text.value=JSON.stringify(data,null,2);c.append(text);const actions=node('footer');actions.append(button('Save Rules',()=>{try{call('save_rules',JSON.stringify(JSON.parse(text.value)))}catch(e){message(e.message,true)}},'primary'),button('Export JSON',()=>call('export_rules')),button('Import JSON',()=>call('import_rules')));c.append(actions);
}
window.VGD={receive(event,data){
  if(event==='config'){config=data;$('subtitle').textContent=`${data.version} · ${data.mode.replace(/_/g,' ')}`;document.querySelectorAll('[data-mode]').forEach(b=>b.classList.toggle('active',b.dataset.mode===data.mode));$('preview').close();message('');}
  if(event==='information')information(data);
  if(event==='scan')scan(data);
  if(event==='mapping')mapping(data);
  if(event==='validation')validation(data);
  if(event==='rules')rules(data);
  if(event==='progress')message(`Scanning… ${data.count} entities`);
  if(['scan','mapping','validation','rules','information'].includes(event))message('');
  if(event==='message')message(data.error||data.text,!!data.error);
  if(event==='preview'){
    const p=$('preview-content');p.replaceChildren();p.append(node('p',`${data.objects} objects will be updated (${data.occurrences} occurrences); ${data.skipped} skipped.`));if(data.material)p.append(node('p','Material rule only. Raw faces remain raw geometry.'));if(data.shared)p.append(node('p','Nested attributes belong to the shared definition entity: all parent occurrences of that entity receive the same metadata.'));p.append(node('p',data.rule?'Mapping Rule will be saved.':''),node('pre',JSON.stringify(data.data,null,2)),node('p','Geometry, names, tags and materials remain unchanged.'));$('confirm-preview').disabled=false;$('preview').showModal();
  }
}};
$('refresh').onclick=()=>call('refresh');$('cancel-preview').onclick=()=>$('preview').close();$('confirm-preview').onclick=()=>{$('confirm-preview').disabled=true;$('preview').close();call('confirm_convert')};document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>call('open_panel',b.dataset.mode));
document.addEventListener('DOMContentLoaded',()=>call('ready'));
