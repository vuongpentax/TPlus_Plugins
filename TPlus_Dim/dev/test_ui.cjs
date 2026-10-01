const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const {chromium}=require('C:/Users/PC/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert=(value,message)=>{if(!value)throw Error(message);};
(async()=>{
  const browser=await chromium.launch({headless:true,channel:'chrome'});
  try {
    const page=await browser.newPage({viewport:{width:580,height:680}});
    page.setDefaultTimeout(8000);
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.addInitScript(()=>{window.calls=[];window.sketchup=new Proxy({},{get:(_,action)=>payload=>calls.push({action,payload})});});
    await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/TPlus_Dim/dialog.html')).href);
    const context={model_id:'file-a',dimensions:12,texts:3,selected:2,locked:0,shared:1,blocked:null,can_apply:true,can_save_profile:true,can_delete:true,delete_dimensions:14,delete_texts:5,context_token:'selection-a',delete_token:'delete-a',profile_active:false};
    const receive=async(c={},settings={})=>page.evaluate(([c,s])=>TPlusDim.receive(c,s),[{...context,...c},settings]);
    const last=async()=>page.evaluate(()=>calls.at(-1));
    assert(await page.locator('#apply').isDisabled(),'Unsynchronized apply enabled');
    await receive();await page.click('#apply');
    let call=await last(),data=JSON.parse(call.payload);
    assert(call.action==='apply' && data.arrow==='dot' && data.text_arrow==='dot' && data.dim_color==='#0000ff' && data.text_color==='#0000ff','Default dot/blue wrong');
    assert(data.font==='UTM Avo' && data.include_dim && data.include_text && data.assign_tags && data.save_profile && data.auto_new && data.custom_dim,'Defaults/profile/custom payload wrong');
    assert(await page.locator('#apply').isDisabled(),'Duplicate apply enabled');
    await receive();await page.selectOption('#arrow','closed');await receive({}, {arrow:'slash'});
    assert(await page.locator('#arrow').inputValue()==='closed','Selection sync overwrote draft');
    await page.uncheck('#include_dim');assert(await page.locator('#apply').isDisabled(),'Scope toggle kept stale token');
    call=await last();assert(call.action==='refresh' && !JSON.parse(call.payload).include_dim,'Dimension scope missing');
    await receive({dimensions:0,context_token:'text-only'});
    await page.click('[data-page="text"]');await page.selectOption('#font','Roboto');await page.check('#font_bold');await page.check('#font_italic');
    await page.fill('#size_pt','0');await page.click('#apply');assert((await page.locator('#model_status').innerText()).includes('1 đến 1000'),'Invalid size accepted');
    await page.fill('#size_pt','12');await page.click('#apply');data=JSON.parse((await last()).payload);
    assert(data.font==='Roboto' && data.font_bold && data.font_italic && data.size_pt===12,'Font style payload missing');
    await receive();await page.click('[data-page="cleanup"]');
    await page.click('[data-delete="both"]');assert(await page.locator('#delete_confirm').isVisible(),'Delete confirmation missing');
    assert((await last()).action==='apply','Opening confirmation sent delete');
    await receive({delete_token:'delete-b'});assert(await page.locator('#delete_confirm').isHidden(),'Stale delete confirmation retained');
    await page.click('[data-delete="dimensions"]');await page.click('#delete_commit');
    call=await last();data=JSON.parse(call.payload);assert(call.action==='delete' && data.kind==='dimensions' && data.delete_token==='delete-b','Delete kind/token wrong');
    await receive({model_id:'file-b',dimensions:0,texts:0,selected:0,can_apply:false,delete_dimensions:0,delete_texts:0}, {font:'UTM Avo',font_bold:false,font_italic:false,include_dim:true});
    assert(await page.locator('#font').inputValue()==='UTM Avo','Model switch retained previous file profile');
    assert(await page.locator('#apply').isEnabled(),'Saving empty model profile disabled');
    await page.click('[data-page="units"]');await page.uncheck('#save_profile');
    assert(await page.locator('#apply').isDisabled(),'Empty targets without profile allowed');
    await page.check('#save_profile');await page.uncheck('#auto_new');await page.click('#apply');
    data=JSON.parse((await last()).payload);assert(data.save_profile && !data.auto_new,'Cannot disable future styling');
    await receive({blocked:'Ngữ cảnh dùng chung',can_save_profile:false,can_apply:false});assert(await page.locator('#apply').isDisabled(),'Blocked context enabled');
    await receive({model_id:'preview',profile_active:true}, {font:'UTM Avo',size_pt:10,font_bold:false,font_italic:false,arrow:'dot',include_dim:true,include_text:true});
    const fonts=await page.evaluate(async()=>{
      let counts=[];for(const family of ['UTM Avo','Roboto','Roboto Condensed'])for(const style of ['normal 400','normal 700','italic 400','italic 700'])counts.push((await document.fonts.load(style+' 16px "'+family+'"','Kích thước tủ 800')).length);return counts;
    });assert(fonts.length===12 && fonts.every(n=>n>0),'Bundled font file missing');
    for(const [width,height] of [[580,680],[470,530]]) {
      await page.setViewportSize({width,height});
      for(const panel of ['dimension','text','units','cleanup']) {
        await page.click('[data-page="'+panel+'"]');
        const layout=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,footer:document.querySelector('footer').getBoundingClientRect().bottom<=innerHeight,pane:document.querySelector('main').scrollWidth<=document.querySelector('main').clientWidth}));
        assert(!layout.overflow && layout.footer && layout.pane,'Clipped layout '+width+'/'+panel);
      }
    }
    await page.setViewportSize({width:580,height:680});
    const output=path.resolve(__dirname,'../outputs');fs.mkdirSync(output,{recursive:true});
    await page.click('[data-page="dimension"]');await page.screenshot({path:path.join(output,'dialog_light.png')});
    await page.click('#theme');await page.screenshot({path:path.join(output,'dialog_dark.png')});
    for(const [panel,file] of [['text','dialog_font.png'],['units','dialog_profile.png'],['cleanup','dialog_delete.png']]) {await page.click('[data-page="'+panel+'"]');await page.screenshot({path:path.join(output,file)});}
    assert(errors.length===0,errors.join(';'));
    console.log('PASS: default dot/blue, all 12 bundled fonts, font/style payload, custom mode, profile/empty selection/model switching, stale scope/delete confirmation, light/dark/responsive UI');
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
