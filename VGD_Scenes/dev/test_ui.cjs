const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
const assert=(ok,text)=>{if(!ok)throw Error(text);};
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.VGD_BROWSER_EXECUTABLE ? {executablePath:process.env.VGD_BROWSER_EXECUTABLE} : {channel:'chrome'})});
 try{
  const page=await browser.newPage({viewport:{width:640,height:780}});page.setDefaultTimeout(7000);
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{window.calls=[];window.sketchup={ready:()=>calls.push({action:'ready'}),action:payload=>calls.push(JSON.parse(payload))};});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_scenes/dialog.html')).href);
  const settings={project:'',template:'<OBJECT>_<VIEW>',views:['ISO','TOP','FRONT','RIGHT'],axis_mode:'local',grouping:'combined',isolate:true,width:1920,height:1080,margin:10,grid:'thirds',format:'png',transparent:false,paper:'A4_L',section_axis:'Y',section_percent:50,section_offset:0,section_flip:false,section_name:'A-A',normal_x:0,normal_y:1,normal_z:0,ratio_locked:false,export_scale:1,date_folder:false};
  const scenes=[{id:'101',name:"Tủ O'Brien",owned:true,kind:'ISO',selected:true},{id:'102',name:'<img src=x onerror="window.injected=true">',owned:true,kind:'SECTION'},{id:'103',name:'Scene cũ',owned:false}];
  const state={model:'model-a',title:'VGD test',selection:1,editing:false,busy:false,grid_active:false,settings,scenes};
  const receive=async(event,data)=>page.evaluate(([event,data])=>VGDScenes.receive(event,data),[event,data]);
  const sync=async(changes={})=>receive('state',{...state,...changes});
  const last=()=>page.evaluate(()=>calls.filter(c=>c.action!=='refresh').at(-1));
  assert(await page.locator('#generate').isDisabled(),'Generate enabled before ready');
  await sync();await page.click('#preset6');await page.click('#generate');let call=await last();
  assert(call.action==='generate'&&call.settings.views.length===6&&call.model==='model-a','Six-view payload incorrect');
  assert(await page.locator('#generate').isDisabled(),'Double generate possible');await sync();
  await page.click('[data-tab="scenes"]');
  assert(await page.locator('#sceneList img').count()===0&&!await page.evaluate(()=>window.injected),'Scene name rendered executable HTML');
  await page.locator('.scene-row').first().locator('input').check();
  await page.locator('.scene-row').first().locator('.row-action').first().click();await page.fill('#renameInput','Tên mới "A"');await page.click('#modalConfirm');call=await last();
  assert(call.action==='rename'&&call.id==='101'&&call.name==='Tên mới "A"','Rename uses unsafe names instead of IDs');await sync();
  await page.locator('.scene-row').first().locator('.scene-name').click();assert((await last()).action==='visit','Visit missing');await sync();
  await page.locator('.scene-row').first().locator('.row-action').last().click();await page.click('#modalCancel');assert((await last()).action==='visit','Cancel capture mutated scene');
  await page.click('#selectAll');assert(await page.locator('#update').isDisabled(),'Foreign source update enabled');
  await page.click('#delete');assert((await last()).action==='visit','Opening delete mutated');await page.click('#modalConfirm');call=await last();assert(call.action==='delete'&&call.ids.length===3,'Batch deletion scope wrong');await sync();
  await page.click('#goExport');await page.selectOption('#format','jpg');assert(await page.locator('#transparent').isDisabled(),'JPEG alpha option enabled');
  await page.selectOption('#format','pdf');assert(await page.locator('#paperLabel').isVisible(),'PDF paper hidden');
  await page.click('#exportButton');call=await last();assert(call.action==='export'&&call.ids.length===3&&call.settings.format==='pdf','Selected PDF export payload wrong');
  await receive('started',{total:3});await receive('progress',{current:1,total:3,name:"Tủ O'Brien"});assert(await page.locator('#cancel').isVisible(),'Cancel not available');
  await page.click('#cancel');assert((await last()).action==='cancel','Cancel not sent');
  await receive('exported',{success:false,cancelled:true,message:'Đã hủy xuất',errors:[]});await sync();assert(await page.locator('#cancel').isHidden(),'Cancel busy state not cleared');
  await receive('result',null);assert((await page.locator('#status').innerText()).includes('không thành công'),'Null result not handled');
  await page.click('[data-tab="sections"]');await page.selectOption('#section_axis','CUSTOM');await page.fill('#normal_y','0');await page.click('#section');assert((await page.locator('#status').innerText()).includes('không được bằng 0'),'Zero section vector accepted');
  await page.fill('#normal_y','1');await page.fill('#section_percent','75');await page.check('#section_flip');await page.click('#section');call=await last();assert(call.action==='section'&&call.settings.section_percent===75&&call.settings.section_flip,'Custom cut payload missing');await sync();
  await page.click('[data-tab="export"]');await page.selectOption('#ratio','16:9');await page.click('#swapRatio');call=await last();
  assert(call.action==='preview'&&call.settings.width===1080&&call.settings.height===1920&&await page.locator('#ratioInput').inputValue()==='9:16','Ratio swap did not preview portrait camera');await sync();
  await page.click('#swapRatio');call=await last();assert(call.settings.width===1920&&call.settings.height===1080,'Ratio swap not reversible');await sync();
  await page.click('#lockRatio');await page.fill('#width','3840');assert(await page.locator('#height').inputValue()==='2160','Width edit did not keep locked ratio');
  await page.fill('#height','720');assert(await page.locator('#width').inputValue()==='1280','Height edit did not keep locked ratio');
  await page.fill('#width','1000');await page.fill('#width','1920');assert(await page.locator('#height').inputValue()==='1080','Locked ratio drifted after rounded edit');
  await page.click('#swapRatio');await sync();await page.fill('#width','1080');assert(await page.locator('#height').inputValue()==='1920','Swap did not reverse locked ratio');await page.click('#swapRatio');await sync();
  await page.click('#lockRatio');await page.fill('#width','1600');assert(await page.locator('#height').inputValue()==='1080','Unlocked dimensions linked');await page.selectOption('#ratio','16:9');
  await page.fill('#ratioInput','3:4');await page.click('#frame');call=await last();assert(call.action==='frame'&&call.settings.width===1440&&call.settings.height===1920,'Custom ratio input not applied');await sync();
  await page.fill('#ratioInput','0:4');await page.click('#frame');assert((await page.locator('#status').innerText()).includes('hợp lệ'),'Invalid ratio accepted');await page.fill('#ratioInput','1:1');
  await page.selectOption('#ratio','1:1');await page.click('#frame');call=await last();assert(call.action==='frame'&&call.settings.width===1500&&call.settings.height===1500,'Frame ratio not applied');await sync();
  await sync({current_frame:{width:1200,height:1600,margin:25},scenes:scenes.map(scene=>({...scene,selected:scene.id==='102'}))});
  assert(await page.locator('#width').inputValue()==='1200'&&await page.locator('#ratioInput').inputValue()==='3:4'&&await page.locator('#margin').inputValue()==='25','Scene switch did not restore saved frame');await sync();
  await page.fill('#width','0');await page.click('#exportButton');assert((await page.locator('#status').innerText()).includes('100–12000'),'Bad dimensions accepted');await page.fill('#width','1920');
  await receive('frame',{frame_active:true,grid_active:false});assert(await page.locator('#toggleFrame').innerText()==='Tắt khung'&&await page.locator('#toggleGrid').innerText()==='Bật lưới','Frame/grid controls not independent');
  await page.click('#toggleFrame');assert((await last()).action==='toggle_frame','Frame toggle action missing');await sync();
  await page.click('#toggleGrid');assert((await last()).action==='grid','Grid toggle action missing');await sync();
  await page.click('#fit');assert((await last()).action==='fit','Fit preview action missing');await sync();
  await page.fill('#export_scale','2');await page.check('#date_folder');await page.click('#exportButton');call=await last();assert(call.settings.export_scale===2&&call.settings.date_folder,'Batch scale/date option not sent');await sync();
  await page.fill('#export_scale','0');await page.click('#exportButton');assert((await page.locator('#status').innerText()).includes('lớn hơn 0'),'Zero export scale accepted');await page.fill('#export_scale','0.5');
  await page.click('[data-tab="views"]');await page.fill('#project','DRAFT');await sync({selection:0});assert(await page.locator('#project').inputValue()==='DRAFT','Refresh erased UI draft');assert(await page.locator('#fit').isDisabled(),'Empty selection fit allowed');
  await sync({model:'model-b',selection:1,settings:{...settings,project:'SECOND'},scenes:[]});assert(await page.locator('#project').inputValue()==='SECOND'&&await page.locator('#exportButton').isDisabled(),'Model switch retained old draft/IDs');
  await sync();
  const out=path.resolve(__dirname,'../outputs');fs.mkdirSync(out,{recursive:true});
  // Transfer commands retain selection scope and preview before changing B.
  await page.click('[data-tab="scenes"]');
  await page.click('#copyScenes');call=await last();assert(call.action==='copyScenes'&&call.ids.length===0,'Copy-current fallback payload wrong');await sync();
  await page.click('#selectAll');await page.click('#copyScenes');call=await last();assert(call.ids.length===3,'Copy selection scope wrong');await sync();
  await page.selectOption('#sceneScope','all');await page.click('#saveScenes');call=await last();assert(call.action==='saveScenes'&&call.scope==='all','All-scene bundle scope wrong');await sync();
  await page.click('#pasteScenes');assert((await last()).action==='pasteScenes','Paste command missing');await sync();
  const transfer={token:'preview-token',title:'File A <img src=x>',scenes:[{id:'a'.repeat(32),name:'<img src=x onerror="window.injected=true">',match:'Tên riêng ở B'},{id:'b'.repeat(32),name:'TOP · Tủ',match:null}]};
  await sync({transfer});assert(await page.locator('#transferModal').isVisible()&&await page.locator('#transferMode').inputValue()==='new','Transfer did not default to create-new preview');
  assert(await page.locator('#transferList img').count()===0&&!await page.evaluate(()=>window.injected),'Transfer name rendered HTML');
  await page.click('#transferNone');assert(await page.locator('#transferApply').isDisabled(),'Empty transfer can apply');await page.click('#transferAll');
  await page.selectOption('#transferMode','update');assert((await page.locator('#transferList').innerText()).includes('Cập nhật: Tên riêng ở B'),'Matching destination not shown');
  await page.locator('#transferList input').last().uncheck();await sync({transfer});assert(await page.locator('#transferList input:checked').count()===1,'Refresh erased transfer choice');
  await page.click('#transferApply');call=await last();assert(call.action==='applyTransfer'&&call.token===transfer.token&&call.ids.length===1&&call.mode==='update','Transfer apply scope/token/mode incorrect');
  assert(await page.locator('#transferApply').isDisabled(),'Double import allowed');
  await receive('result',{success:false,message:'Thử lỗi để giữ lựa chọn'});await sync({transfer});assert(await page.locator('#transferModal').isVisible(),'Failed import closed preview');
  for(const [width,height] of [[640,780],[460,540]]){
    await page.setViewportSize({width,height});
    const bounds=await page.locator('.transfer-card').boundingBox();assert(bounds.x>=0&&bounds.y>=0&&bounds.x+bounds.width<=width&&bounds.y+bounds.height<=height,'Transfer dialog clipped');
    const applyBounds=await page.locator('#transferApply').boundingBox();assert(applyBounds.y+applyBounds.height<=height,'Transfer apply outside window');
    await page.screenshot({path:path.join(out,`VGD_transfer_${width}.png`)});
  }
  await page.click('#transferCancel');assert((await last()).action==='cancelTransfer'&&await page.locator('#transferModal').isHidden(),'Transfer cancel mutated/retained preview');await sync();
  await sync({transfer});await sync({model:'model-b',transfer:null});assert(await page.locator('#transferModal').isHidden(),'Model switch kept transfer preview');await sync();
  await page.setViewportSize({width:640,height:780});await sync({transfer});await page.keyboard.press('Escape');assert((await last()).action==='cancelTransfer','Escape did not cancel transfer');await sync();
  for(const [width,height] of [[640,780],[460,540]]){
   await page.setViewportSize({width,height});
   for(const tab of ['views','sections','scenes','export']){
    await page.click('[data-tab="'+tab+'"]');
    const layout=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,footer:document.querySelector('footer').getBoundingClientRect().bottom<=innerHeight,pane:document.querySelector('main').scrollWidth<=document.querySelector('main').clientWidth}));
    assert(!layout.overflow&&layout.footer&&layout.pane,'Layout clipped: '+width+'/'+tab);
   }
  }
  await page.setViewportSize({width:640,height:780});await receive('result',{success:true,message:'Sẵn sàng · Chọn đối tượng, tạo view và chọn scene để xuất.'});await page.click('[data-tab="views"]');await page.screenshot({path:path.join(out,'VGD_light.png')});
  await page.click('#theme');await page.screenshot({path:path.join(out,'VGD_dark.png')});
  await page.click('[data-tab="scenes"]');await page.screenshot({path:path.join(out,'VGD_scenes.png')});
  await page.click('[data-tab="sections"]');await page.screenshot({path:path.join(out,'VGD_section.png')});
  await page.click('[data-tab="export"]');await page.selectOption('#ratio','16:9');await page.screenshot({path:path.join(out,'VGD_export.png')});
  await sync({transfer});await page.screenshot({path:path.join(out,'VGD_transfer_dark.png')});
  assert(errors.length===0,'Browser errors: '+errors.join(';'));
  console.log('PASS: safe Unicode/HTML scene names, ID actions, confirmation/cancel, selected PDF/JPG/PNG scope, custom section, frame, validation, draft/model switching, transfer preview/scope/token/update/cancel/failure, responsive light/dark UI');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
