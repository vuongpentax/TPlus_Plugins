from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib

root = Path(__file__).resolve().parents[1]
out = root / 'outputs/tplus_cabinet_modeling'
out.mkdir(parents=True, exist_ok=True)
version = '4.3.0-beta.6'
files = ['tplus_cabinet.rb'] + ['TPlus_Cabinet/' + name for name in [
    'main43.rb', 'geometry_engine.rb', 'modeling_rules.rb', 'modeling.rb',
    'defaults.rb', 'draw_tool.rb', 'ui_renderer.rb', 'TPlus_Cabinet_UI.html',
    'utilities.rb', 'reload.rb', 'combine.svg', 'untag.svg', 'logo.svg', 'HUONG_DAN.txt']]
rbz = out / f'TPlus_Cabinet_v{version}.rbz'
source = out / f'TPlus_Cabinet_v{version}_source.zip'
with ZipFile(rbz, 'w', ZIP_DEFLATED) as z:
    for file in files:
        z.write(root / 'cabinet_work' / file, file)
with ZipFile(source, 'w', ZIP_DEFLATED) as z:
    for file in files:
        z.write(root / 'cabinet_work' / file, 'cabinet_work/' + file)
    for file in ['check_ruby.cjs', 'sketchup_stub.rb', 'test_geometry.rb',
                 'test_dom.cjs', 'test_payload.cjs', 'test_ui.cjs',
                 'defaults.json', 'presets.json', 'redesign_ui.cjs',
                 'ui_beta1.html', 'menu.css', 'menu.js', 'package_menu.py',
                 'utilities_stub.rb', 'test_utilities.rb', 'test_commands.rb',
                 'package.json', 'pnpm-lock.yaml', 'test_reload.rb', 'sync_sketchup_2022.ps1']:
        z.write(root / 'cabinet_dev' / file, 'cabinet_dev/' + file)
    z.write(root / 'CODEX_HANDOFF.md', 'CODEX_HANDOFF.md')
    z.write(root / 'AGENTS.md', 'AGENTS.md')
    z.writestr('TESTS.txt', '''T+ Cabinet 4.3.0-beta.6 — source and verification

Runtime used: Node 24, Ruby 3.2 WebAssembly, JSDOM, Playwright + local Chrome.
Tests run from the extracted root folder.
Task dependencies: pnpm install --dir cabinet_dev --frozen-lockfile
Playwright is resolved from CODEX_PRIMARY_RUNTIME_NODE_MODULES.
Set that environment variable to the directory containing the Playwright package.
test_ui.cjs uses installed Chrome; TPLUS_BROWSER_PATH can specify another executable.
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
bootstrap, menu/toolbar idempotence, T+ observer cleanup, foreign-observer preservation,
syntax preflight and the exact own-file reload list. No native hot-reload is claimed.
sync_sketchup_2022.ps1 deploys only the 15 listed T+ Cabinet files to the fixed 2022 path,
backing up changed existing files and verifying SHA256. It does not deploy other plugins.
No native SketchUp run was available. See HUONG_DAN.txt for manual acceptance checks.
''')
for path in [rbz, source]:
    with ZipFile(path) as z:
        assert z.testzip() is None
    print(path, path.stat().st_size, hashlib.sha256(path.read_bytes()).hexdigest())
