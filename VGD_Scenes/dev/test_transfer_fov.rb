# Regression: physical FOVs can cross 1..120 when measured on the other axis.
s = VGD::Scenes; transfer = s::SceneTransfer
previous_model = Sketchup.active_model
m = Sketchup::Model.new; Sketchup.active_model = m
page = m.pages.add('Tall interior',PAGE_USE_CAMERA)
page.camera.perspective = true
page.camera.aspect_ratio = 0.25; page.camera.vertical_fov = false; page.camera.fov = 100
source_angle = page.camera.fov
s::SceneFrame.store(page,'width'=>1000,'height'=>4000,'margin'=>10)
data = transfer.bundle(m)
assert(data['scenes'][0]['camera']['fov'] == source_angle && data['scenes'][0]['camera']['fov_vertical'] == false, 'Export changed source lens data')
assert(page.camera.fov == 100 && !page.camera.fov_is_height?, 'JSON export mutated source camera')
FileUtils.mkdir_p('/tmp/fov-transfer')
transfer.write('/tmp/fov-transfer/tall.json',data)
read = transfer.read('/tmp/fov-transfer/tall.json')
converted = transfer.camera(read['scenes'][0]['camera'])
expected = Math.atan(Math.tan(100*Math::PI/360)/0.25)*360/Math::PI
assert(expected > 120 && near(converted.fov,expected), 'Tall FOV was rejected or clamped')
assert(converted.image_width == 0 && near(converted.aspect_ratio,0.25), 'Wide-angle setter changed film width/frame')
rejects('strict native setter') { converted.fov = expected }
failed = Sketchup::Camera.new(page.camera.eye,page.camera.target,page.camera.up,true)
failed.image_width = 42
def failed.focal_length=(_value); raise 'Lens API failed'; end
rejects('lens API failure') { s.set_camera_fov(failed,expected) }
assert(failed.image_width == 42,'Failed lens setter did not restore image width')
clamped = Sketchup::Camera.new(page.camera.eye,page.camera.target,page.camera.up,true)
def clamped.focal_length=(_value); @fov = 120; end
rejects('native lens clamp') { s.set_camera_fov(clamped,expected) }
destination = Sketchup::Model.new; Sketchup.active_model = destination
result = transfer.apply(destination,read,[data['scenes'][0]['id']],'new')
imported = s::SceneStore.find(destination,result[:ids].first)
assert(near(imported.camera.fov,expected) && imported.camera.eye == page.camera.eye && imported.camera.target == page.camera.target, 'New-scene import lost wide lens/pose')
again = transfer.bundle(destination)
roundtrip = transfer.camera(again['scenes'][0]['camera'])
assert(near(roundtrip.fov,expected), 'Re-export of >120 FOV not portable')
result = transfer.apply(destination,read,[data['scenes'][0]['id']],'update')
assert(result[:ids] == [imported.persistent_id.to_s] && near(imported.camera.fov,expected), 'Update import lost wide lens')

# Very wide frames can produce a valid converted FOV smaller than 1 degree.
low = Marshal.load(Marshal.dump(read))
low['scenes'][0]['camera'].merge!('fov'=>1.0,'aspect'=>120.0,'fov_vertical'=>false)
low['scenes'][0]['frame'] = {'width'=>12000,'height'=>100,'margin'=>10}
transfer.write('/tmp/fov-transfer/low.json',low)
small = transfer.camera(transfer.read('/tmp/fov-transfer/low.json')['scenes'][0]['camera'])
assert(small.fov > 0 && small.fov < 1 && near(small.fov,Math.atan(Math.tan(Math::PI/360)/120)*360/Math::PI), 'Sub-degree lens was rejected or clamped')
s.set_camera_fov(small,120); assert(small.fov == 120,'120 degree boundary failed')
s.set_camera_fov(small,1); assert(small.fov == 1,'1 degree boundary failed')
[0,-1,180,181,Float::NAN,Float::INFINITY,'45'].each do |angle|
  invalid = Marshal.load(Marshal.dump(read)); invalid['scenes'][0]['camera']['fov'] = angle
  rejects('invalid physical FOV') { transfer.validate(invalid) }
end
invalid = Marshal.load(Marshal.dump(read)); invalid['scenes'][0]['camera']['fov'] = 180
begin
  transfer.validate(invalid); raise 'Invalid FOV accepted'
rescue ArgumentError => error
  assert(error.message.include?('Tall interior') && error.message.include?('FOV'), 'Validation failed without scene name')
end
events = destination.events.length; camera = destination.active_view.camera
rejects('preflight invalid camera') { transfer.apply(destination,invalid,[invalid['scenes'][0]['id']],'new') }
assert(destination.events.length == events && destination.active_view.camera.equal?(camera), 'Invalid import modified model')

# Copy/export restoration and eye elevation share the same lens handling.
assert(near(s.camera_copy(converted).fov,expected), 'Camera copy cannot preserve >120 lens')
Sketchup.active_model = m
s::CameraControl.elevation(m,{'mode'=>'absolute','z'=>1600,'keep_direction'=>true})
# Live camera differs from the saved tall source; test the tall source explicitly.
m.active_view.camera = page.camera
s::CameraControl.elevation(m,{'mode'=>'absolute','z'=>1700,'keep_direction'=>true})
assert(near(m.active_view.camera.fov,expected), 'Elevation cannot preserve cross-axis wide lens')
Sketchup.active_model = previous_model
puts 'PASS: JSON tall/wide frames, >120/sub-degree equivalent FOV without clamping, source camera intact, import/update/re-export/copy/elevation, strict native setter and invalid-lens/name/preflight guards'
