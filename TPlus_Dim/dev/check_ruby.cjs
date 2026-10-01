const fs = require('fs');
const path = require('path');
const deps = path.resolve(__dirname, '../../TPlus_Cabinet_Codex_Handoff_2026-10-01/cabinet_dev/node_modules');
const {DefaultRubyVM} = require(path.join(deps, '@ruby/wasm-wasi/dist/cjs/node.js'));
(async () => {
  const wasm = await WebAssembly.compile(fs.readFileSync(require.resolve(path.join(deps, '@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm'))));
  const {vm} = await DefaultRubyVM(wasm);
  const root = path.resolve(__dirname, '../runtime');
  const files = ['tplus_dim.rb', ...fs.readdirSync(path.join(root,'TPlus_Dim')).filter(f=>f.endsWith('.rb')).map(f=>'TPlus_Dim/'+f)];
  const rubyLiteral = value => JSON.stringify(value).replace(/#/g, '\\#');
  for (const file of files) {
    vm.eval('RubyVM::InstructionSequence.compile(' + rubyLiteral(fs.readFileSync(path.join(root, file), 'utf8')) + ')');
    console.log('Syntax OK:', file);
  }
  vm.eval(fs.readFileSync(path.join(__dirname, 'test_fixture.rb'), 'utf8'));
  for(const name of ['defaults','font_book','custom_dim','engine','profile']) vm.eval(fs.readFileSync(path.join(root,'TPlus_Dim',name+'.rb'),'utf8'));
  const words='0123456789.,- mmKích thước tủOSØ°×·±';
  vm.eval('TPlus::Dim::FontBook.instance_variable_set(:@meshes, {})');
  for(const name of ['UTM-Avo','UTM-Avobold','Roboto-Regular']) {
    const data=JSON.parse(fs.readFileSync(path.join(root,'TPlus_Dim/fonts',name+'.json'),'utf8'));
    data.glyphs=Object.fromEntries([...new Set([...words].map(c=>String(c.codePointAt(0))))].map(k=>[k,data.glyphs[k]]));
    vm.eval('TPlus::Dim::FontBook.instance_variable_get(:@meshes)['+rubyLiteral(name)+'] = JSON.parse('+rubyLiteral(JSON.stringify(data))+')');
  }
  vm.eval(fs.readFileSync(path.join(__dirname, 'test_engine.rb'), 'utf8'));
  vm.eval('run_engine_tests; $stdout.flush');
  const main=fs.readFileSync(path.join(root,'TPlus_Dim/main.rb'),'utf8').replace(/^require[^\n]*\n/gm,'');
  vm.eval(main); vm.eval(main);
  vm.eval('raise "Toolbar changed at startup/reload" unless UI.toolbars.length == 1 && UI.toolbars.first.events == [:add]; puts "PASS: startup/reload creates one toolbar, never show/restore/hide"; $stdout.flush');
})().catch(error => {console.error(error); process.exitCode = 1;});
