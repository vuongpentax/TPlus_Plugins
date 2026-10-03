# frozen_string_literal: true
previous_model = Sketchup.active_model
s = VGD::Scenes; store = s::SceneStore; camera = s::CameraControl
m = Sketchup::Model.new; Sketchup.active_model = m
pages = %w[A B C].map { |name| m.pages.add(name, PAGE_USE_CAMERA) }
ids = pages.map { |page| page.persistent_id.to_s }
pages.each { |page| page.set_attribute('OtherPlugin', 'link', page.persistent_id) }
m.pages.selected_page = pages[1]
saved = pages.map(&:saved); view = m.active_view.camera
assert(store.reorder(m, ids[2], ids[0], ids)[:success], 'Private reorder failed')
assert(store.ordered(m) == [pages[2],pages[0],pages[1]], 'VGD order incorrect')
assert(m.pages == pages && m.pages.selected_page == pages[1] && m.active_view.camera.equal?(view), 'Reorder changed native tabs/current camera')
assert(pages.map(&:saved) == saved && pages.all? { |p| p.valid? && p.get_attribute('OtherPlugin','link') == p.persistent_id }, 'Reorder changed scene identity/state/foreign links')
assert(m.events.last == [:commit], 'Private order not in operation')
order = store.list(m).map { |entry| entry[:id] }
rejects('stale reorder') { store.reorder(m, ids[0], nil, ids) }
rejects('missing drop target') { store.reorder(m, ids[0], 'deleted', order) }
before = m.events.length
store.reorder(m, ids[2], ids[2], order)
assert(m.events.length == before, 'No-op reorder dirtied SKP')
m.active_path = [Object.new]
rejects('reorder editing') { store.reorder(m, ids[0], nil, order) }; m.active_path = nil

# Serialization fallback, native additions/deletions and rename do not need an observer.
stored = m.get_attribute(s::DICT,'scene_order')
m.set_attribute(s::DICT,'scene_order',JSON.parse(stored).to_json)
assert(store.ordered(m).map(&:persistent_id) == [pages[2],pages[0],pages[1]].map(&:persistent_id), 'Stored order lost on read')
pages[0].name = 'A renamed'
new_page = m.pages.add('D', PAGE_USE_CAMERA)
assert(store.ordered(m).last == new_page, 'New scene not appended')
m.pages.erase(new_page)
['{bad', '{}', '[1]', '["x","x"]'].each do |invalid|
  m.set_attribute(s::DICT,'scene_order',invalid)
  assert(store.ordered(m) == pages, 'Malformed stored order not safely ignored')
end
m.set_attribute(s::DICT,'scene_order',stored)
assert(s::SceneTransfer.bundle(m)['scenes'].map { |entry| entry['name'] } == ['C','A renamed','B'], 'JSON/copy ignored VGD order')
FileUtils.mkdir_p('/tmp/private-order')
UI.next_directory = '/tmp/private-order'
s.export_selected(m, {'ids'=>ids.reverse, 'settings'=>s::DEFAULTS})
assert(s.instance_variable_get(:@job).instance_variable_get(:@pages) == [pages[2],pages[0],pages[1]], 'Export follows checkbox/native order')
UI.drain
assert(['01_C.png','02_A renamed.png','03_B.png'].all? { |name| File.file?(File.join('/tmp/private-order/PNG',name)) }, 'Image numbering not VGD order')
UI.next_savepanel = '/tmp/private-order/ordered.pdf'
s.export_selected(m, {'ids'=>ids.reverse, 'settings'=>s::DEFAULTS.merge('format'=>'pdf')}); UI.drain
assert(Layout.documents.last.pages.map(&:name) == ['C','A renamed','B'], 'PDF pages not VGD order')
assert(m.pages == pages && m.pages.selected_page == pages[1], 'Export reordered native scene tabs')
puts 'PASS: persisted private order, native IDs/cameras/foreign links preserved, stale/edit/no-op guards, new/renamed/malformed lists, copy/JSON/PNG/PDF use VGD order'

# Preview moves world Z, with explicit save through existing Update View only.
original = Sketchup::Camera.new(Geom::Point3d.new(12,-80,1500/25.4),Geom::Point3d.new(12,0,1400/25.4),Geom::Vector3d.new(0,0,1),true)
original.aspect_ratio = 1.5; original.fov = 48
m.active_view.camera = original
saved_camera = pages[1].camera
before = m.events.length
result = camera.elevation(m, {'mode'=>'absolute','z'=>2100,'keep_direction'=>true})
preview = m.active_view.camera
assert(result[:success] && near(preview.eye.z*25.4,2100), 'Absolute eye Z incorrect')
assert(preview.eye.x == original.eye.x && preview.eye.y == original.eye.y && near(preview.target.z-original.target.z,600/25.4), 'Keep direction moved XY or did not translate target')
assert((preview.target-preview.eye) == (original.target-original.eye) && preview.up == original.up && preview.perspective? && preview.fov == 48 && preview.aspect_ratio == 1.5, 'Elevation changed lens/projection/roll/direction')
assert(m.events.length == before && pages[1].camera.equal?(saved_camera), 'Preview saved scene or created operation')
assert(near(camera.state(m)[:eye_z_mm],2100), 'State not reporting live eye Z')
camera.elevation(m, {'mode'=>'floor','floor'=>3200,'height'=>1500,'keep_direction'=>false})
assert(near(m.active_view.camera.eye.z*25.4,4700) && m.active_view.camera.target == preview.target, 'Floor + Eye Height or keep-target incorrect')
assert(s.capture_current_view[:success] && near(pages[1].camera.eye.z*25.4,4700), 'Update view did not save elevation')
parallel = Sketchup::Camera.new(original.eye,original.target,original.up,false); parallel.height = 999; parallel.aspect_ratio = 0
m.active_view.camera = parallel
camera.elevation(m, {'mode'=>'absolute','z'=>-250,'keep_direction'=>true})
assert(!m.active_view.camera.perspective? && m.active_view.camera.height == 999 && m.active_view.camera.aspect_ratio == 0 && near(m.active_view.camera.eye.z*25.4,-250), 'Parallel elevation changed viewport height/unlocked aspect')
original.vertical_fov = false; m.active_view.camera = original
camera.elevation(m, {'mode'=>'absolute','z'=>1600,'keep_direction'=>true})
assert(near(m.active_view.camera.fov,Math.atan(Math.tan(48*Math::PI/360)/1.5)*360/Math::PI), 'Horizontal FOV framing not preserved')
original.vertical_fov = true
%w[bad].each { |mode| rejects('bad mode') { camera.elevation(m, {'mode'=>mode,'z'=>100,'keep_direction'=>true}) } }
[nil, Float::NAN, Float::INFINITY, 1e10].each { |z| rejects('bad Z') { camera.elevation(m, {'mode'=>'absolute','z'=>z,'keep_direction'=>true}) } }
rejects('negative eye height') { camera.elevation(m, {'mode'=>'floor','floor'=>0,'height'=>-1,'keep_direction'=>true}) }
rejects('invalid bool') { camera.elevation(m, {'mode'=>'absolute','z'=>1500,'keep_direction'=>'true'}) }
m.active_view.camera = original; original.two_point = true
assert(!camera.state(m)[:supported], 'Two-point not disabled')
rejects('two-point') { camera.elevation(m, {'mode'=>'absolute','z'=>1500,'keep_direction'=>true}) }; original.two_point = false
m.active_path = [Object.new]
rejects('camera editing') { camera.elevation(m, {'mode'=>'absolute','z'=>1500,'keep_direction'=>true}) }; m.active_path = nil
s.instance_variable_set(:@job,Object.new)
assert(!s.dispatch('cameraElevation', {'model'=>m.object_id.to_s,'camera'=>{'mode'=>'absolute','z'=>2500,'keep_direction'=>true}})[:success], 'Busy elevation allowed')
s.instance_variable_set(:@job,nil)
assert(s.dispatch('cameraElevation', {'model'=>m.object_id.to_s,'camera'=>{'mode'=>'absolute','z'=>2500,'keep_direction'=>true}})[:success], 'Elevation callback failed')
assert(m.pages == pages && pages.all? { |p| p.get_attribute('OtherPlugin','link') == p.persistent_id }, 'Camera changed other scene identity/link')
Sketchup.active_model = previous_model
puts 'PASS: absolute/floor eye Z, keep direction/target, preview until toolbar save, perspective/parallel/FOV, invalid/two-point/edit/busy guards'
