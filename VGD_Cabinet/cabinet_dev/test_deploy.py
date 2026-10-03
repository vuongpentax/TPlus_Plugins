from pathlib import Path
import json,os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
outputs=root/'outputs'; outputs.mkdir(exist_ok=True)
shell=Path(os.environ.get('VGD_POWERSHELL_PATH',r'C:/Users/TUNG/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'))
with tempfile.TemporaryDirectory(prefix='deploy_fixture_',dir=outputs) as directory:
    fixture=Path(directory).resolve()
    assert fixture.is_relative_to(outputs.resolve())
    plugins=fixture/'SketchUp/SketchUp 2022/SketchUp/Plugins'; plugins.mkdir(parents=True)
    legacy=plugins/'tplus_cabinet.rb'
    previous=b"module TPlus_Cabinet\nend\n# TPlus_Cabinet/main43.rb\n"
    legacy.write_bytes(previous)
    other=plugins/'vgd_dim.rb'; other.write_bytes(b'DIM MUST NOT CHANGE')
    data=fixture/'VGD/SketchUp/VGD_Cabinet/presets_v1.json'; data.parent.mkdir(parents=True); data.write_bytes(b'USER PRESETS MUST NOT CHANGE')
    def deploy(*args):
        return subprocess.run([str(shell),'-NoProfile','-File',str(root/'cabinet_dev/sync_sketchup_2022.ps1'),*args],env=dict(os.environ,APPDATA=str(fixture)),capture_output=True,text=True,encoding='utf-8')
    result=deploy('-VerifyOnly'); assert result.returncode==0,result.stderr
    assert legacy.read_bytes()==previous and not (plugins/'vgd_cabinet.rb').exists()
    result=deploy(); assert result.returncode==0,result.stderr
    assert not legacy.exists()
    files=['vgd_cabinet.rb']+['VGD_Cabinet/'+n for n in ['main43.rb','geometry_engine.rb','modeling_rules.rb','modeling.rb','pano.rb','preset_store.rb','description_import.rb','defaults.rb','draw_tool.rb','ui_renderer.rb','VGD_Cabinet_UI.html','utilities.rb','reload.rb','combine.svg','untag.svg','logo.svg','HUONG_DAN.txt']]
    for name in files: assert (plugins/name).read_bytes()==(root/'cabinet_work'/name).read_bytes(),name
    reports=[json.loads(p.read_text(encoding='utf-8-sig')) for p in outputs.glob('install_*/INSTALL_REPORT.json')]
    receipt=next(r for r in reports if r['Target']==str(plugins))
    assert receipt['Status']=='VERIFIED' and Path(receipt['LegacyBackup']).read_bytes()==previous
    result=deploy(); assert result.returncode==0,result.stderr
    before={name:(plugins/name).read_bytes() for name in files}
    legacy.write_bytes(b'FOREIGN LOADER')
    result=deploy(); assert result.returncode!=0 and legacy.read_bytes()==b'FOREIGN LOADER'
    assert all((plugins/name).read_bytes()==value for name,value in before.items())
    legacy.unlink(); (plugins/'vgd_cabinet.rb').write_bytes(b'FOREIGN VGD LOADER')
    result=deploy(); assert result.returncode!=0
    assert (plugins/'vgd_cabinet.rb').read_bytes()==b'FOREIGN VGD LOADER'
    assert other.read_bytes()==b'DIM MUST NOT CHANGE' and data.read_bytes()==b'USER PRESETS MUST NOT CHANGE'
print('PASS: Cabinet deploy dry-run, 18 files, legacy backup/retirement, repeat, foreign-loader guards, other plugins and user preset data untouched')
