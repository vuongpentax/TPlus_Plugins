const fs=require('fs'),path=require('path');
const deps=path.resolve(__dirname,'../../TPlus_Cabinet_Codex_Handoff_2026-10-01/cabinet_dev/node_modules');
const {RubyVM}=require(path.join(deps,'@ruby/wasm-wasi/dist/cjs/vm.js'));
const {WASI}=require('wasi');
(async()=>{
 const wasm=await WebAssembly.compile(fs.readFileSync(require.resolve(path.join(deps,'@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm'))));
 const output=path.resolve(__dirname,'../outputs');fs.mkdirSync(output,{recursive:true});
 const wasi=new WASI({version:'preview1',returnOnExit:true,preopens:{'/tmp':output}});
 const {vm}=await RubyVM.instantiateModule({module:wasm,wasip1:wasi});
 const root=path.resolve(__dirname,'../runtime');const files=[];
 function walk(dir){for(const item of fs.readdirSync(dir,{withFileTypes:true})){const name=path.join(dir,item.name);if(item.isDirectory())walk(name);else if(name.endsWith('.rb'))files.push(name);}}
 walk(root);walk(__dirname);
 const literal=v=>JSON.stringify(v).replace(/#/g,'\\#');
 for(const file of files){vm.eval('RubyVM::InstructionSequence.compile('+literal(fs.readFileSync(file,'utf8'))+')');console.log('Syntax OK:',path.relative(root,file));}
 vm.eval(fs.readFileSync(path.join(__dirname,'fixture.rb'),'utf8'));
 for(const file of ['core/schema','core/data','core/validator','intake/mapping_rules','intake/detector','intake/converter'])vm.eval(fs.readFileSync(path.join(root,'vgd_bim_lite',file+'.rb'),'utf8'));
 vm.eval(fs.readFileSync(path.join(__dirname,'test_core.rb'),'utf8'));vm.eval('$stdout.flush');
 vm.eval(fs.readFileSync(path.join(__dirname,'geometry_fixture.rb'),'utf8'));
 for(const file of ['core/geometry','core/scanner','intake/raw_scanner','intake/mapping'])vm.eval(fs.readFileSync(path.join(root,'vgd_bim_lite',file+'.rb'),'utf8'));
 vm.eval(fs.readFileSync(path.join(__dirname,'test_geometry.rb'),'utf8'));vm.eval('$stdout.flush');
})().catch(error=>{console.error(error);process.exitCode=1});
