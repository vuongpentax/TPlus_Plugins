const fs=require('fs'),path=require('path');
const localDeps=path.resolve(__dirname,'node_modules');
const deps=fs.existsSync(path.join(localDeps,'@ruby/wasm-wasi')) ? localDeps : path.resolve(__dirname,'../../TPlus_Cabinet_Codex_Handoff_2026-10-01/cabinet_dev/node_modules');
const {RubyVM}=require(path.join(deps,'@ruby/wasm-wasi/dist/cjs/vm.js'));
const {WASI}=require('wasi');
(async()=>{
 const wasm=await WebAssembly.compile(fs.readFileSync(require.resolve(path.join(deps,'@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm'))));
 fs.mkdirSync(path.resolve(__dirname,'../outputs'),{recursive:true});
 const tmpRoot=fs.mkdtempSync(path.resolve(__dirname,'../outputs/wasm-test-'));
 const wasi=new WASI({version:'preview1',returnOnExit:true,preopens:{'/tmp':tmpRoot}});
 const {vm}=await RubyVM.instantiateModule({module:wasm,wasip1:wasi}),root=path.resolve(__dirname,'../runtime');
 const files=['vgd_scenes.rb',...fs.readdirSync(path.join(root,'vgd_scenes')).filter(f=>f.endsWith('.rb')).map(f=>'vgd_scenes/'+f)];
 const literal=value=>JSON.stringify(value).replace(/#/g,'\\#');
 for(const f of files){vm.eval('RubyVM::InstructionSequence.compile('+literal(fs.readFileSync(path.join(root,f),'utf8'))+')');console.log('Syntax OK:',f);}
 vm.eval(fs.readFileSync(path.join(__dirname,'fixture.rb'),'utf8'));
 for(const f of ['utils','geometry','scenes','frame','export','main'])vm.eval(fs.readFileSync(path.join(root,'vgd_scenes',f+'.rb'),'utf8').replace(/^require_relative[^\n]*\n/gm,'').replace(/^require 'sketchup.rb'\r?\n/gm,''));
 vm.eval(fs.readFileSync(path.join(__dirname,'test_engine.rb'),'utf8'));
 vm.eval('$stdout.flush');
 if(fs.readdirSync(path.join(tmpRoot,'mixed-frames')).some(name=>name.endsWith('.json')))throw Error('Unrequested report JSON emitted');
})().catch(e=>{console.error(e);process.exitCode=1;});
