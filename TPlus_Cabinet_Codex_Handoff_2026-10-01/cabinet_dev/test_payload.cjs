const fs=require('fs'),assert=require('assert');
const {JSDOM}=require('jsdom');
const defaults=JSON.parse(fs.readFileSync('cabinet_dev/defaults.json'));
const presets=JSON.parse(fs.readFileSync('cabinet_dev/presets.json'));
function open(path){let html=fs.readFileSync(path,'utf8');for(const [key,data] of [['presets_json',presets],['default_json',defaults],['initial_json',defaults]])html=html.replace('#{'+key+'}',()=>JSON.stringify(JSON.stringify(data)).replace(/</g,'\\u003c'));return new JSDOM(html,{runScripts:'dangerously',url:'https://tplus.test'});}
const old=open('cabinet_dev/ui_beta1.html'),now=open('cabinet_work/TPlus_Cabinet/TPlus_Cabinet_UI.html');
setTimeout(()=>{try{
  const oldIDs=[...old.window.document.querySelectorAll('input,select')].map(e=>e.id).filter(id=>id!=='master_card_toggle').sort();
  const newKeys=['door_style','metal_frame_width','metal_frame_depth','glass_thickness','metal_finish','glass_finish','back_groove_auto','back_groove_depth','drawer_columns','drawer_frame_depth','drawer_frame_rail_width','drawer_frame_stop_rail','drawer_frame_stop_rail_h','drawer_frame_stop_rail_drop','drawer_bottom_mode'];
  const newIDs=[...now.window.document.querySelectorAll('input,select')].map(e=>e.id).filter(id=>!newKeys.includes(id)).sort();
  assert.deepStrictEqual(newIDs,oldIDs,'Missing/extra parameter controls');
  for(const [name,params] of Object.entries({defaults,...presets})){
    old.window.updateFormFromRuby(params);now.window.updateFormFromRuby(params);
    const a=JSON.parse(JSON.stringify(old.window.getFormData())),b=JSON.parse(JSON.stringify(now.window.getFormData()));
    newKeys.forEach(key=>delete b[key]);
    assert.deepStrictEqual(b,a,'Existing modeling parameters changed: '+name);
  }
  console.log('PASS: all parameter IDs preserved, payloads match beta.1 for defaults and 7 presets');
}catch(e){console.error(e);process.exitCode=1}finally{old.window.close();now.window.close()}},650);
