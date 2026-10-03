"""Run fixture tests in SU22's Ruby DLL in a separate console process.

This does not launch SketchUp or load its geometry kernel. The only writes
are under this project's outputs directory. Windows / SU22 optional check.
"""
import ctypes
import json
import os
from pathlib import Path
import tempfile

root = Path(__file__).resolve().parent.parent
installation = Path(os.environ.get('VGD_SU22_ROOT', r'C:\Program Files\SketchUp\SketchUp 2022'))
stdlib = installation / 'Tools/RubyStdLib'
native = stdlib / 'platform_specific'
(root / 'outputs').mkdir(exist_ok=True)
temp_root = Path(tempfile.mkdtemp(prefix='ruby27-test-', dir=root / 'outputs')).as_posix()
handles = [os.add_dll_directory(str(installation)), os.add_dll_directory(str(native))]
ruby = ctypes.CDLL(str(installation / 'x64-msvcrt-ruby270.dll'))
value = ctypes.c_size_t
argc = ctypes.c_int(1)
argv_data = (ctypes.c_char_p * 2)(b'vgd-scenes-test', None)
argv = ctypes.cast(argv_data, ctypes.POINTER(ctypes.c_char_p))
ruby.ruby_sysinit.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.POINTER(ctypes.c_char_p))]
ruby.ruby_sysinit(ctypes.byref(argc), ctypes.byref(argv))
ruby.ruby_setup.restype = ctypes.c_int
if ruby.ruby_setup() != 0:
    raise RuntimeError('Could not initialize Ruby 2.7')
ruby.rb_eval_string_protect.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_int)]
ruby.rb_eval_string_protect.restype = value
ruby.rb_errinfo.restype = value
ruby.rb_inspect.argtypes = [value]
ruby.rb_inspect.restype = value
ruby.rb_string_value_cstr.argtypes = [ctypes.POINTER(value)]
ruby.rb_string_value_cstr.restype = ctypes.c_char_p


def evaluate(source):
    state = ctypes.c_int()
    source = "# encoding: UTF-8\nbegin\n" + source + "\nrescue Exception => error; warn error.full_message; raise; end"
    ruby.rb_eval_string_protect(source.encode('utf-8'), ctypes.byref(state))
    if state.value:
        error_value = value(ruby.rb_inspect(ruby.rb_errinfo()))
        detail = ruby.rb_string_value_cstr(ctypes.byref(error_value)).decode('utf-8', errors='replace')
        raise RuntimeError(detail)


try:
    evaluate('$LOAD_PATH.replace(' + json.dumps([stdlib.as_posix(), native.as_posix()]) + '); '
             'require "enc/encdb"; require "enc/trans/transdb"; '
             'Encoding.default_external=Encoding::UTF_8; '
             '$stdout.sync=true; $stderr.sync=true; puts "Embedded Ruby #{RUBY_VERSION}: fixture only"')
    runtime = root / 'runtime'
    for file in [runtime / 'vgd_scenes.rb', *sorted((runtime / 'vgd_scenes').glob('*.rb'))]:
        literal = json.dumps(file.read_text(encoding='utf-8'), ensure_ascii=False).replace('#', '\\#')
        evaluate('RubyVM::InstructionSequence.compile(' + literal + ')')
        print('Ruby 2.7 syntax OK:', file.name, flush=True)
    evaluate((root / 'dev/fixture.rb').read_text(encoding='utf-8'))
    for name in ['utils', 'geometry', 'scenes', 'frame', 'export', 'transfer', 'main']:
        source = (runtime / 'vgd_scenes' / (name + '.rb')).read_text(encoding='utf-8')
        source = '\n'.join(line for line in source.splitlines() if not line.startswith('require_relative ') and line != "require 'sketchup.rb'")
        evaluate(source)
    for name in ['test_engine.rb', 'test_transfer.rb']:
        source = (root / 'dev' / name).read_text(encoding='utf-8').replace('/tmp', temp_root)
        evaluate(source)
    print('PASS: actual Ruby 2.7.2 DLL with simulated SketchUp API; no native kernel test', flush=True)
finally:
    ruby.ruby_finalize()
