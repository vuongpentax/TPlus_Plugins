from pathlib import Path
import zipfile
import hashlib
import json

root = Path(__file__).resolve().parent.parent
output = root / 'outputs'
output.mkdir(exist_ok=True)
version = '1.1.0-beta.2'
rbz = output / f'TPlus_Dim_v{version}.rbz'
source = output / f'TPlus_Dim_v{version}_source.zip'
with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted((root / 'runtime').rglob('*')):
        if file.is_file():
            archive.write(file, file.relative_to(root / 'runtime').as_posix())
with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED) as archive:
    for folder in ['runtime', 'dev']:
        for file in sorted((root / folder).rglob('*')):
            if file.is_file() and '__pycache__' not in file.parts and 'vendor' not in file.parts:
                archive.write(file, file.relative_to(root).as_posix())
    for name in ['README.md', 'AGENTS.md', 'FONT_NOTES.md']:
        archive.write(root / name, name)
    for name in ['FONT_PROVENANCE.json','VALIDATION.json']:
        archive.write(output/name,'outputs/'+name)
for file in [rbz, source]:
    with zipfile.ZipFile(file) as archive:
        assert archive.testzip() is None
manifest = {file.name: hashlib.sha256(file.read_bytes()).hexdigest() for file in [rbz, source]}
(output / 'PACKAGES_SHA256.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps(manifest, indent=2))
