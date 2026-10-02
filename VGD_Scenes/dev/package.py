from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parent.parent
version = re.search(r"VERSION = '([^']+)'", (root / 'runtime/vgd_scenes.rb').read_text(encoding='utf-8')).group(1)
target = root / f'VGD_Scenes_v{version}.rbz'
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted((root / 'runtime').rglob('*')):
        if path.is_file():
            archive.write(path, path.relative_to(root / 'runtime').as_posix())
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    for name in archive.namelist():
        assert archive.read(name) == (root / 'runtime' / name).read_bytes()
print(f'Packaged and verified: {target}')
