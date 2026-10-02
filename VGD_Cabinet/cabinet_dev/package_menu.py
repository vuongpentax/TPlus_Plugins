from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
import json

root = Path(__file__).resolve().parents[1]
out = root / 'outputs/vgd_cabinet_modeling'
out.mkdir(parents=True, exist_ok=True)
version = '4.4.0-beta.1'
files = ['vgd_cabinet.rb'] + ['VGD_Cabinet/' + name for name in [
    'main43.rb', 'geometry_engine.rb', 'modeling_rules.rb', 'modeling.rb', 'pano.rb', 'preset_store.rb',
    'defaults.rb', 'draw_tool.rb', 'ui_renderer.rb', 'VGD_Cabinet_UI.html',
    'utilities.rb', 'reload.rb', 'combine.svg', 'untag.svg', 'logo.svg', 'HUONG_DAN.txt']]
rbz = out / f'VGD_Cabinet_v{version}.rbz'
source = out / f'VGD_Cabinet_v{version}_source.zip'
with ZipFile(rbz, 'w', ZIP_DEFLATED) as z:
    for file in files:
        z.write(root / 'cabinet_work' / file, file)
with ZipFile(source, 'w', ZIP_DEFLATED) as z:
    for file in files:
        z.write(root / 'cabinet_work' / file, 'cabinet_work/' + file)
    for file in ['check_ruby.cjs', 'dependencies.cjs', 'sketchup_stub.rb', 'test_geometry.rb', 'test_vgd_features.rb', 'test_presets.rb', 'test_deploy.py',
                 'test_dom.cjs', 'test_payload.cjs', 'test_ui.cjs',
                 'defaults.json', 'presets.json', 'redesign_ui.cjs',
                 'ui_beta1.html', 'menu.css', 'menu.js', 'package_menu.py',
                 'utilities_stub.rb', 'test_utilities.rb', 'test_commands.rb',
                 'package.json', 'pnpm-lock.yaml', 'test_reload.rb', 'sync_sketchup_2022.ps1']:
        z.write(root / 'cabinet_dev' / file, 'cabinet_dev/' + file)
    z.write(root / 'CODEX_HANDOFF.md', 'CODEX_HANDOFF.md')
    z.write(root / 'AGENTS.md', 'AGENTS.md')
    for file in ['README.md','PANO_RESEARCH.md','VALIDATION.json']:
        z.write(root/file,file)
    z.writestr('TESTS.txt', '''VGD Cabinet 4.4.0-beta.1 — source and verification

Runtime used: Node 24, Ruby 3.2 WebAssembly, JSDOM, Playwright + local Edge.
Tests run from the extracted root folder.
Task dependencies: pnpm install --dir cabinet_dev --frozen-lockfile
Playwright is resolved from CODEX_PRIMARY_RUNTIME_NODE_MODULES.
Set that environment variable to the directory containing the Playwright package.
test_ui.cjs uses installed Edge; VGD_BROWSER_PATH can specify another executable.
node cabinet_dev/check_ruby.cjs
node cabinet_dev/redesign_ui.cjs
node cabinet_dev/test_dom.cjs
node cabinet_dev/test_payload.cjs
node cabinet_dev/test_ui.cjs
python3 cabinet_dev/package_menu.py

redesign_ui.cjs rebuilds the current static HTML from ui_beta1.html plus menu.css/menu.js.
The Ruby API stub verifies dimensions and parameter logic, not the native SketchUp kernel.
Utility fixtures verify selected scope, conversion, transforms, attributes, shared copies,
tag recursion, failure transactions and menu/toolbar callbacks; not native geometry repair.
Reload fixture evaluates real runtime files to verify dependency/HTML refresh, beta 4
bootstrap, menu/toolbar idempotence, VGD observer cleanup, foreign-observer preservation,
syntax preflight and the exact own-file reload list. No native hot-reload is claimed.
sync_sketchup_2022.ps1 deploys only the 17 listed VGD Cabinet files to the fixed 2022 path,
backing up changed existing files and verifying SHA256. It does not deploy other plugins.
No native SketchUp run was available. See HUONG_DAN.txt for manual acceptance checks.
''')
for path in [rbz, source]:
    with ZipFile(path) as z:
        assert z.testzip() is None
    print(path, path.stat().st_size, hashlib.sha256(path.read_bytes()).hexdigest())
with ZipFile(rbz) as z:
    assert set(z.namelist())==set(files)
    assert all(z.read(name)==(root/'cabinet_work'/name).read_bytes() for name in files)
(out/'SHA256.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [rbz,source]},indent=2),encoding='utf-8')
