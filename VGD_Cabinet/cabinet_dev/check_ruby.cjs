const fs=require('fs');
const {DefaultRubyVM}=require('./dependencies.cjs').load('@ruby/wasm-wasi/dist/node');
const path=require('path'),{WASI}=require('wasi');
const {RubyVM}=require('./dependencies.cjs').load('@ruby/wasm-wasi/dist/vm');
(async()=>{
 const wasm=await WebAssembly.compile(fs.readFileSync(require('./dependencies.cjs').resolve('@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm')));
 const fixture=fs.mkdtempSync(path.resolve('outputs/preset_fixture_'));
 const makeVM=async()=>{
   const wasi=new WASI({version:'preview1',returnOnExit:true,env:{APPDATA:'/tmp/appdata'},preopens:{'/tmp':fixture}});
   const result=await RubyVM.instantiateModule({module:wasm,wasip1:wasi});
   // WASI lacks flock. Only this primitive is simulated; JSON IO is host-backed.
   result.vm.eval('class File; def flock(_); 0; end; end');
   return result;
 };
 const {vm}=await makeVM();
 const root='cabinet_work/VGD_Cabinet/';
 vm.eval('RubyVM::InstructionSequence.compile('+JSON.stringify(fs.readFileSync('cabinet_work/vgd_cabinet.rb','utf8'))+')');
 for(const name of fs.readdirSync(root).filter(n=>n.endsWith('.rb'))){
   vm.eval('RubyVM::InstructionSequence.compile('+JSON.stringify(fs.readFileSync(root+name,'utf8')).replace(/#/g,'\\#')+')');
   console.log('Syntax OK:',name);
 }
 vm.eval(fs.readFileSync('cabinet_dev/sketchup_stub.rb','utf8'));
 for(const name of ['geometry_engine.rb','modeling_rules.rb','pano.rb','modeling.rb','defaults.rb','preset_store.rb','description_import.rb'])vm.eval(fs.readFileSync(root+name,'utf8').replace(/^require_relative .*$/gm,''));
 vm.eval(fs.readFileSync('cabinet_dev/test_geometry.rb','utf8'));
 vm.eval(fs.readFileSync('cabinet_dev/test_vgd_features.rb','utf8'));
 const main=fs.readFileSync(root+'main43.rb','utf8').replace(/^require(?:_relative)? .*$/gm,'');
 vm.eval(main);
 vm.eval('$partial_description_json='+JSON.stringify(fs.readFileSync('cabinet_dev/description_partial_fixture.json','utf8')).replace(/#/g,'\\#'));
 vm.eval(fs.readFileSync('cabinet_dev/test_description.rb','utf8'));
 fs.writeFileSync('outputs/description_cases.json',vm.eval('JSON.generate($description_cases)').toString());
 vm.eval(fs.readFileSync('cabinet_dev/test_presets.rb','utf8'));
 const {vm:restartVM}=await makeVM();
 restartVM.eval(fs.readFileSync(root+'preset_store.rb','utf8'));
 restartVM.eval("store=VGD_Cabinet::PresetStore.new('/tmp/vgd-presets-test/presets.json',defaults: -> { raise 'Unexpected reset' },legacy: -> { raise 'Unexpected migration' }); raise 'New VM lost saved data' unless store.load['Mẫu nhiều 9']['w']==949; puts 'PASS: preset JSON survives a new Ruby VM using the same host-backed directory'; $stdout.flush");
 vm.eval('raise "Update stamped!" unless VGD_Cabinet.update_selected_cabinet({}).nil?; raise "Operation started without selection" unless Sketchup.active_model.operations==0; puts "PASS: update without selection does not create or mutate"');
 const defaults=vm.eval('require "json"; JSON.generate(VGD_Cabinet.default_params)').toString();
 fs.writeFileSync('cabinet_dev/defaults.json',defaults);
 const presets=vm.eval('JSON.generate(VGD_Cabinet.builtin_presets)').toString();
 fs.writeFileSync('cabinet_dev/presets.json',presets);
 vm.eval('VGD_Cabinet.presets.each { |name,p| VGD_Cabinet.normalize(p); puts "PASS preset: #{name}" }');
 vm.eval('$stdout.flush');
 const {vm:utilitiesVM}=await makeVM();
 utilitiesVM.eval(fs.readFileSync('cabinet_dev/utilities_stub.rb','utf8'));
 utilitiesVM.eval(fs.readFileSync(root+'utilities.rb','utf8'));
 utilitiesVM.eval(fs.readFileSync('cabinet_dev/test_utilities.rb','utf8'));
 utilitiesVM.eval(main);
 utilitiesVM.eval(fs.readFileSync('cabinet_dev/test_commands.rb','utf8'));
 utilitiesVM.eval('$stdout.flush');
 const {vm:reloadVM}=await makeVM();
 reloadVM.eval('require "json"');
 const runtimeSources=Object.fromEntries(fs.readdirSync(root).filter(n=>n.endsWith('.rb')||n==='VGD_Cabinet_UI.html').map(name=>['/vgd/'+name,fs.readFileSync(root+name,'utf8')]));
 const rubyLiteral=value=>JSON.stringify(value).replace(/#/g,'\\#');
 reloadVM.eval('$fixture_sources=JSON.parse('+rubyLiteral(JSON.stringify(runtimeSources))+')');
 reloadVM.eval(fs.readFileSync('cabinet_dev/utilities_stub.rb','utf8'));
 try { reloadVM.eval(fs.readFileSync('cabinet_dev/test_reload.rb','utf8')); }
 catch(error) { reloadVM.eval('$stdout.flush'); throw error; }
 reloadVM.eval('$stdout.flush');
})().catch(e=>{console.error(e);process.exitCode=1});
