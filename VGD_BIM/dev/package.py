from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parent.parent
target = root / 'VGD_BIM_Lite_v0.1.0-alpha.rbz'
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted((root / 'runtime').rglob('*')):
        if path.is_file():
            archive.write(path, path.relative_to(root / 'runtime').as_posix())
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    for name in archive.namelist():
        assert archive.read(name) == (root / 'runtime' / name).read_bytes()
(root / 'PACKAGE_SHA256.json').write_text(json.dumps({target.name: hashlib.sha256(target.read_bytes()).hexdigest()}, indent=2) + '\n', encoding='utf-8')
print(f'Packaged and verified: {target}')
