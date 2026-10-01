const fs=require('fs');
const {DefaultRubyVM}=require('/tmp/tplus_export_test/node_modules/@ruby/wasm-wasi/dist/cjs/node.js');
(async()=>{
 const {vm}=await DefaultRubyVM(await WebAssembly.compile(fs.readFileSync('/tmp/tplus_export_test/node_modules/@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm')));
 for(const path of ['dc_export_work/tplus_dc_exporter.rb','dc_export_work/tplus_dc_exporter/main.rb']){
  vm.eval('RubyVM::InstructionSequence.compile('+JSON.stringify(fs.readFileSync(path,'utf8')).replace(/#/g,'\\#')+')');
  console.log('Syntax OK:',path);
 }
 vm.eval(fs.readFileSync('dc_export_dev/test_export.rb','utf8'));
 vm.eval(fs.readFileSync('dc_export_work/tplus_dc_exporter/main.rb','utf8').replace(/^require 'sketchup.rb'$/m,''));
 vm.eval('run_tests; $stdout.flush');
})().catch(e=>{console.error(e);process.exitCode=1});
