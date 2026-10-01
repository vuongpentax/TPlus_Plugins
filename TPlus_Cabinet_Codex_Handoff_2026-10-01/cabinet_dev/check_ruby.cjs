const fs=require('fs');
const {DefaultRubyVM}=require('@ruby/wasm-wasi/dist/node');
(async()=>{
 const wasm=await WebAssembly.compile(fs.readFileSync(require.resolve('@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm')));
 const {vm}=await DefaultRubyVM(wasm);
 const root='cabinet_work/TPlus_Cabinet/';
 for(const name of fs.readdirSync(root).filter(n=>n.endsWith('.rb'))){
   vm.eval('RubyVM::InstructionSequence.compile('+JSON.stringify(fs.readFileSync(root+name,'utf8')).replace(/#/g,'\\#')+')');
   console.log('Syntax OK:',name);
 }
 vm.eval(fs.readFileSync('cabinet_dev/sketchup_stub.rb','utf8'));
 for(const name of ['geometry_engine.rb','modeling_rules.rb','modeling.rb','defaults.rb'])vm.eval(fs.readFileSync(root+name,'utf8'));
 vm.eval(fs.readFileSync('cabinet_dev/test_geometry.rb','utf8'));
 const main=fs.readFileSync(root+'main43.rb','utf8').replace(/^require(?:_relative)? .*$/gm,'');
 vm.eval(main);
 vm.eval('raise "Update stamped!" unless TPlus_Cabinet.update_selected_cabinet({}).nil?; raise "Operation started without selection" unless Sketchup.active_model.operations==0; puts "PASS: update without selection does not create or mutate"');
 const defaults=vm.eval('require "json"; JSON.generate(TPlus_Cabinet.default_params)').toString();
 fs.writeFileSync('cabinet_dev/defaults.json',defaults);
 const presets=vm.eval('JSON.generate(TPlus_Cabinet.presets)').toString();
 fs.writeFileSync('cabinet_dev/presets.json',presets);
 vm.eval('TPlus_Cabinet.presets.each { |name,p| TPlus_Cabinet.normalize(p); puts "PASS preset: #{name}" }');
 vm.eval('$stdout.flush');
 const {vm:utilitiesVM}=await DefaultRubyVM(wasm);
 utilitiesVM.eval(fs.readFileSync('cabinet_dev/utilities_stub.rb','utf8'));
 utilitiesVM.eval(fs.readFileSync(root+'utilities.rb','utf8'));
 utilitiesVM.eval(fs.readFileSync('cabinet_dev/test_utilities.rb','utf8'));
 utilitiesVM.eval(main);
 utilitiesVM.eval(fs.readFileSync('cabinet_dev/test_commands.rb','utf8'));
 utilitiesVM.eval('$stdout.flush');
 const {vm:reloadVM}=await DefaultRubyVM(wasm);
 reloadVM.eval('require "json"');
 const runtimeSources=Object.fromEntries(fs.readdirSync(root).filter(n=>n.endsWith('.rb')||n==='TPlus_Cabinet_UI.html').map(name=>['/tplus/'+name,fs.readFileSync(root+name,'utf8')]));
 const rubyLiteral=value=>JSON.stringify(value).replace(/#/g,'\\#');
 reloadVM.eval('$fixture_sources=JSON.parse('+rubyLiteral(JSON.stringify(runtimeSources))+')');
 reloadVM.eval(fs.readFileSync('cabinet_dev/utilities_stub.rb','utf8'));
 reloadVM.eval(fs.readFileSync('cabinet_dev/test_reload.rb','utf8'));
 reloadVM.eval('$stdout.flush');
})().catch(e=>{console.error(e);process.exitCode=1});
