# Cross-model behavior without a SketchUp kernel. No simulated version label
# is counted as a native SketchUp compatibility test.
s = VGD::Scenes; transfer = s::SceneTransfer
previous_model = Sketchup.active_model
a = Sketchup::Model.new; b = Sketchup::Model.new
Sketchup.active_model = a
a.active_view.camera = Sketchup::Camera.new(Geom::Point3d.new(400,200,300), Geom::Point3d.new(10,20,30), Geom::Vector3d.new(0,0,1), true)
a.active_view.camera.aspect_ratio = 1.5; a.active_view.camera.fov = 48
perspective = a.pages.add("Tủ O'Brien", PAGE_USE_CAMERA)
s::SceneFrame.store(perspective, 'width'=>1800, 'height'=>1200, 'margin'=>8)
a.active_view.camera = Sketchup::Camera.new(Geom::Point3d.new(0,0,500), Geom::Point3d.new(0,0,0), Geom::Vector3d.new(0,1,0), false)
a.active_view.camera.aspect_ratio = 0.75; a.active_view.camera.height = 345
top = a.pages.add('TOP', PAGE_USE_CAMERA)
s::SceneFrame.store(top, 'width'=>1200, 'height'=>1600, 'margin'=>12)
source_state = [a.active_view.camera, a.entities.to_a, a.selection.to_a]
bundle = transfer.bundle(a)
assert(bundle['scenes'].length == 2 && bundle['scenes'][0]['camera']['perspective'], 'Mixed-camera bundle missing')
assert([a.active_view.camera,a.entities.to_a,a.selection.to_a] == source_state, 'Copy changed geometry/view/selection')
stable_id = bundle['scenes'][0]['id']; perspective.name = 'Nguồn đổi tên'
assert(transfer.bundle(a)['scenes'][0]['id'] == stable_id, 'Source rename changed transfer identity')

Sketchup.active_model = b
untouched = b.pages.add('Không đổi', PAGE_USE_CAMERA)
untouched.set_attribute('OtherPlugin', 'private', 'preserve')
b.pages.selected_page = untouched
before_camera = b.active_view.camera
result = transfer.apply(b, bundle, bundle['scenes'].map { |e| e['id'] }, 'new')
assert(result[:success] && b.pages.length == 3, 'Import did not create two scenes')
assert(b.pages.selected_page == untouched && b.active_view.camera.equal?(before_camera), 'Import changed the composed live view')
imported = result[:ids].map { |id| s::SceneStore.find(b,id) }
assert(imported[0].camera.eye == perspective.camera.eye && imported[0].camera.target == perspective.camera.target && near(imported[0].camera.fov,48), 'Perspective camera changed')
assert(imported[1].camera.up == top.camera.up && !imported[1].camera.perspective? && near(imported[1].camera.height,345), 'Parallel camera/roll/height changed')
assert(s::SceneFrame.read(imported[1],s::DEFAULTS) == {'width'=>1200,'height'=>1600,'margin'=>12.0}, 'Portrait frame changed')
assert(imported.none? { |page| s::SceneStore.owned?(page) || page.get_attribute(s::DICT,'source') }, 'Imported invalid geometry/source ownership')
assert(untouched.get_attribute('OtherPlugin','private') == 'preserve' && untouched.name == 'Không đổi', 'Transfer modified unrelated scene/dictionary')
assert(s::SceneStore.list(b).find { |e| e[:id] == imported[0].persistent_id.to_s }[:imported], 'Imported badge missing')

imported[0].name = 'Tên tùy chỉnh ở B'
perspective.camera.set(Geom::Point3d.new(900,700,500), perspective.camera.target, perspective.camera.up)
new_bundle = transfer.bundle(a)
imported[0].use_rendering_options = true
imported[0].saved[:rendering]['Other setting'] = 'stay'
imported[0].set_attribute(s::DICT,'owner','VGD Scenes')
imported[0].set_attribute(s::DICT,'source','{"paths":[[888]],"kind":"ISO"}')
result = transfer.apply(b,new_bundle,[stable_id],'update')
assert(b.pages.length == 3 && result[:ids] == [imported[0].persistent_id.to_s], 'Renamed destination duplicated instead of matching ID')
assert(imported[0].name == 'Tên tùy chỉnh ở B' && imported[0].camera.eye == perspective.camera.eye, 'Sync changed custom target name or missed camera')
assert(imported[0].saved[:rendering]['Other setting'] == 'stay' && imported[0].get_attribute(s::DICT,'source') == '{"paths":[[888]],"kind":"ISO"}', 'Camera sync replaced display/source data')
assert(imported[0].get_attribute(s::DICT,'camera_custom') && b.active_view.camera.equal?(before_camera), 'Imported source camera not marked custom or live camera changed')
assert(transfer.apply(b,new_bundle,[stable_id],'skip')[:ids].empty? && b.pages.length == 3, 'Skip changed existing destination')
count = b.pages.length
transfer.apply(b,bundle,[stable_id],'new')
assert(b.pages.length == count+1, 'Create-new ignored a matching ID')
transfer.bundle(b) # Repeated new imports must remain exportable with distinct IDs.
rejects('ambiguous ID match') { transfer.apply(b,new_bundle,[stable_id],'update') }
bundle['scenes'][0]['name'] = 'Tên tùy chỉnh ở B'
assert(transfer.apply(b,bundle,[stable_id],'update')[:ids] == [imported[0].persistent_id.to_s], 'Unique exact name did not resolve duplicate origin')

# Name-only matching for a legacy destination, preserving its native flags.
c = Sketchup::Model.new; Sketchup.active_model = c
legacy = c.pages.add('TOP',PAGE_USE_CAMERA); legacy.use_hidden_objects = true
legacy.set_attribute('OtherPlugin','private',123)
count = c.pages.length
assert(transfer.apply(c,new_bundle,[new_bundle['scenes'][1]['id']],'update')[:ids] == [legacy.persistent_id.to_s] && c.pages.length == count, 'Exact-name sync did not update legacy destination')
assert(legacy.use_hidden_objects && legacy.get_attribute('OtherPlugin','private') == 123, 'Legacy update replaced unrelated flags/attributes')
expected = transfer.preview(c,new_bundle,'t')[:scenes].each_with_object({}) { |entry,hash| hash[entry[:id]] = entry[:target_id] }
origin = legacy.get_attribute(s::DICT,'transfer_origin'); legacy.delete_attribute(s::DICT,'transfer_origin')
legacy.name = 'B đổi tên sau preview'
rejects('destination changed after preview') { transfer.apply(c,new_bundle,[new_bundle['scenes'][1]['id']],'update',expected) }
legacy.name = 'TOP'; legacy.set_attribute(s::DICT,'transfer_origin',origin)

# All cameras are validated before writes; failure midway restores old scenes
# even on a fixture whose abort_operation does not perform native rollback.
d = Sketchup::Model.new; Sketchup.active_model = d
first = d.pages.add('Nguồn đổi tên',PAGE_USE_CAMERA)
second = d.pages.add('TOP',PAGE_USE_CAMERA)
first_camera = transfer.camera_data(first.camera)
second.camera.fail_set_once = true
rejects('partial write') { transfer.apply(d,new_bundle,new_bundle['scenes'].map { |e| e['id'] },'update') }
assert(transfer.camera_data(first.camera) == first_camera && first.get_attribute(s::DICT,'frame').nil? && d.pages.length == 2, 'Failed import did not restore previous camera/frame')
assert(d.events.last[0] == :abort, 'Failed import committed transaction')
# Exercise a created page before a later setter fails.
second.camera.fail_set_once = true
rejects('new then failed update') { transfer.apply(d,new_bundle,new_bundle['scenes'].map { |e| e['id'] },'update') } # Both still update.
d.pages.erase(first)
second.camera.fail_set_once = true
rejects('new page rollback') { transfer.apply(d,new_bundle,new_bundle['scenes'].map { |e| e['id'] },'update') }
assert(d.pages.length == 1 && d.pages.first == second, 'Partial import leaked a new scene')

invalid = Marshal.load(Marshal.dump(new_bundle)); invalid['scenes'][1]['camera']['up'] = [0,0,0]
before_events = d.events.length
rejects('invalid vector') { transfer.apply(d,invalid,invalid['scenes'].map { |e| e['id'] },'new') }
assert(d.events.length == before_events && d.pages.length == 1, 'Invalid bundle changed destination')
%w[format version].each do |key|
  invalid = Marshal.load(Marshal.dump(new_bundle)); invalid[key] = 'unsupported'
  rejects('wrong schema') { transfer.validate(invalid) }
end
invalid = Marshal.load(Marshal.dump(new_bundle)); invalid['scenes'][0]['camera']['eye'][0] = Float::NAN
rejects('NaN coordinate') { transfer.validate(invalid) }
invalid = Marshal.load(Marshal.dump(new_bundle)); invalid['scenes'][0]['frame']['width'] = 12001
rejects('bad frame') { transfer.validate(invalid) }
rejects('unknown selected ID') { transfer.apply(d,new_bundle,['not-in-bundle'],'new') }
rejects('unknown mode') { transfer.apply(d,new_bundle,[stable_id],'replaceAll') }
d.active_path = [Object.new]
rejects('edit context') { transfer.apply(d,new_bundle,[stable_id],'new') }; d.active_path = nil
perspective.camera.two_point = true
rejects('two-point source') { transfer.bundle(a) }; perspective.camera.two_point = false
second.camera.two_point = true
rejects('two-point target') { transfer.apply(d,new_bundle,[new_bundle['scenes'][1]['id']],'update') }; second.camera.two_point = false

# Horizontal FOV conversion and unlocked output frames.
perspective.camera.vertical_fov = false
horizontal_bundle = transfer.bundle(a,[perspective.persistent_id.to_s])
converted = transfer.camera(horizontal_bundle['scenes'][0]['camera'])
assert(near(converted.fov,Math.atan(Math.tan(48*Math::PI/360)/1.5)*360/Math::PI), 'Horizontal FOV not converted')
perspective.camera.vertical_fov = true; perspective.camera.aspect_ratio = 0
assert(near(transfer.bundle(a,[perspective.persistent_id.to_s])['scenes'][0]['camera']['aspect'],1.5), 'Unlocked camera did not use portable output frame')

ENV['APPDATA'] = '/tmp/transfer-profile'
FileUtils.mkdir_p(File.dirname(transfer.clipboard_path))
transfer.write(transfer.clipboard_path,new_bundle,true)
assert(transfer.read(transfer.clipboard_path) == new_bundle, 'Private cross-process clipboard round-trip failed')
transfer.write(transfer.clipboard_path,bundle,true)
assert(transfer.read(transfer.clipboard_path) == bundle, 'Clipboard replacement failed')
FileUtils.mkdir_p('/tmp/scene-bundles')
transfer.write('/tmp/scene-bundles/roundtrip.vgdscenes.json',new_bundle)
rejects('existing export file') { transfer.write('/tmp/scene-bundles/roundtrip.vgdscenes.json',bundle) }
assert(transfer.read('/tmp/scene-bundles/roundtrip.vgdscenes.json') == new_bundle, 'Existing export was overwritten')
File.binwrite('/tmp/scene-bundles/bad.json','{"format":')
rejects('invalid JSON') { transfer.read('/tmp/scene-bundles/bad.json') }
File.binwrite('/tmp/scene-bundles/large.json','x'*(transfer::MAX_BYTES+1))
rejects('oversize JSON') { transfer.read('/tmp/scene-bundles/large.json') }

# Native command routing plus pending-preview model identity and busy guards.
Sketchup.active_model = a; a.pages.selected_page = perspective
assert(s.transfer_command('copyScenes')[:success], 'Toolbar copy failed')
assert(transfer.read(transfer.clipboard_path)['scenes'].length == 1, 'Toolbar copy selected wrong scope')
UI.next_savepanel = '/tmp/scene-bundles/all'; s.transfer_export(a,{'scope'=>'all'},false)
assert(transfer.read('/tmp/scene-bundles/all.vgdscenes.json')['scenes'].length == 2, 'Save-all exported wrong scope')
UI.next_openpanel = '/tmp/scene-bundles/all.vgdscenes.json'
Sketchup.active_model = c
assert(s.dispatch('loadScenes',{'model'=>c.object_id.to_s})[:success], 'Load command failed')
pending = s.state[:transfer]
assert(pending[:scenes].length == 2, 'Pending preview missing')
Sketchup.active_model = d
assert(!s.dispatch('applyTransfer',{'model'=>d.object_id.to_s,'token'=>pending[:token],'ids'=>[stable_id],'mode'=>'new'})[:success], 'Model switch accepted stale transfer')
assert(s.state[:transfer].nil?, 'Different model exposed stale preview')
Sketchup.active_model = c; s.instance_variable_set(:@job,Object.new)
assert(!s.dispatch('applyTransfer',{'model'=>c.object_id.to_s,'token'=>pending[:token],'ids'=>[stable_id],'mode'=>'new'})[:success], 'Busy export allowed transfer')
s.instance_variable_set(:@job,nil)
assert(!s.dispatch('applyTransfer',{'model'=>c.object_id.to_s,'token'=>'stale','ids'=>[stable_id],'mode'=>'new'})[:success], 'Stale preview token accepted')
assert(s.dispatch('applyTransfer',{'model'=>c.object_id.to_s,'token'=>pending[:token],'ids'=>[stable_id],'mode'=>'new'})[:success], 'Valid preview did not apply')
assert(s.state[:transfer].nil?, 'Completed preview retained')
UI.next_savepanel = nil
assert(s.transfer_export(c,{'scope'=>'all'},false)[:cancelled], 'Cancelled picker not respected')
Sketchup.active_model = previous_model
puts 'PASS: portable mixed cameras/frames, stable rename sync, legacy exact-name sync, create/update/skip, unrelated state preserved, explicit old-version rollback, strict JSON/geometry validation, two-point rejection, FOV conversion, cross-process clipboard, native routing and model/busy/token guards'
