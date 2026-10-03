# frozen_string_literal: true
MB_YESNO = 4 unless defined?(MB_YESNO)
IDYES = 6 unless defined?(IDYES)
previous_model = Sketchup.active_model
s = VGD::Scenes; frames = s::SceneFrame
m = Sketchup::Model.new; Sketchup.active_model = m
pages = ['VGD ISO','Old native section','Two-point','Unused camera','No frame'].each_with_index.map do |name,i|
  m.active_view.camera = Sketchup::Camera.new(Geom::Point3d.new(7,-90,60+i),Geom::Point3d.new(7,0,15),Geom::Vector3d.new(0,0,1),i != 1)
  m.active_view.camera.aspect_ratio = i == 4 ? 0 : [16.0/9,0.75,1,2][i]
  page = m.pages.add(name,PAGE_USE_CAMERA)
  frames.store(page,s::DEFAULTS.merge('width'=>1200+i*100,'height'=>1600))
  page.set_attribute('OtherPlugin','link',i)
  page.use_style = true; page.use_section_planes = true; page.use_hidden_layers = true
  page
end
pages.first.set_attribute(s::DICT,'owner','VGD Scenes')
pages[2].camera.two_point = true; pages[2].camera.vertical_fov = false
pages[3].use_camera = false
m.pages.selected_page = pages.first
live = Sketchup::Camera.new(Geom::Point3d.new(1,2,3),Geom::Point3d.new(4,5,6),Geom::Vector3d.new(0,0,1),true)
live.aspect_ratio = 1.2; live.two_point = true; m.active_view.camera = live
ratios = pages.map { |p| p.camera.aspect_ratio }
details = pages.map { |p| [p.persistent_id,p.name,p.use_camera,p.use_style,p.use_section_planes,p.use_hidden_layers,p.camera.eye.to_a,p.camera.target.to_a,p.camera.up.to_a,p.camera.perspective?,p.camera.fov,p.camera.height,p.camera.is_2d?,p.camera.fov_is_height?,p.get_attribute(s::DICT,'frame'),p.get_attribute('OtherPlugin','link'),p.saved[:rendering],p.saved[:sections]] }
assert(frames.cleanup_state(m) == {count:4,restore:false}, 'Cleanup scope missing native/unused scene')
assert(frames.cleanup(m)[:success] && pages.all? { |p| p.camera.aspect_ratio == 0 } && m.active_view.camera.aspect_ratio == 0, 'Saved scene or live gray bars remain')
assert(m.pages == pages && m.pages.selected_page == pages.first && m.active_view.camera.eye == live.eye && live.two_point, 'Cleanup moved/switches scene or reconstructed live camera')
after = pages.map { |p| [p.persistent_id,p.name,p.use_camera,p.use_style,p.use_section_planes,p.use_hidden_layers,p.camera.eye.to_a,p.camera.target.to_a,p.camera.up.to_a,p.camera.perspective?,p.camera.fov,p.camera.height,p.camera.is_2d?,p.camera.fov_is_height?,p.get_attribute(s::DICT,'frame'),p.get_attribute('OtherPlugin','link'),p.saved[:rendering],p.saved[:sections]] }
assert(after == details, 'Cleanup changed scene state/camera details/foreign attributes/frame size')
assert(frames.cleanup_state(m) == {count:0,restore:true}, 'Restore backup missing')
backup = m.get_attribute(s::DICT,frames::BACKUP_KEY); before = m.events.length
frames.cleanup(m)
assert(m.events.length == before && m.get_attribute(s::DICT,frames::BACKUP_KEY) == backup, 'Repeat cleanup replaced original backup')
frames.cleanup(m,true)
assert(pages.map { |p| p.camera.aspect_ratio } == ratios && near(m.active_view.camera.aspect_ratio,1.2) && !frames.cleanup_state(m)[:restore], 'Restore lost original scene/live ratios')

# Preserve output sizes and do not automatically re-lock saved scenes during export.
frames.cleanup(m)
FileUtils.mkdir_p('/tmp/unlocked-frames'); UI.next_directory = '/tmp/unlocked-frames'
s.export_selected(m,{'ids'=>[pages.first.persistent_id.to_s,pages[1].persistent_id.to_s],'settings'=>s::DEFAULTS}); UI.drain
assert(m.active_view.writes.last(2).map { |w| [w[:width],w[:height]] } == [[1200,1600],[1300,1600]], 'Cleanup lost per-scene export resolution')
assert(pages.all? { |p| p.camera.aspect_ratio == 0 } && m.active_view.camera.aspect_ratio == 0, 'Export reintroduced saved gray bars')
frames.cleanup(m,true)

# Explicit rollback is required on SU22 where native Undo does not restore scene cameras.
pages[1].camera.fail_aspect_once = true
before = m.get_attribute(s::DICT,frames::BACKUP_KEY)
rejects('partial cleanup failure') { frames.cleanup(m) }
assert(pages.map { |p| p.camera.aspect_ratio } == ratios && near(m.active_view.camera.aspect_ratio,1.2) && m.get_attribute(s::DICT,frames::BACKUP_KEY) == before, 'Cleanup failure not rolled back')
assert(m.events.last == [:abort], 'Failed cleanup committed')
frames.cleanup(m); saved_backup = m.get_attribute(s::DICT,frames::BACKUP_KEY)
pages[1].camera.fail_aspect_once = true
rejects('partial restore failure') { frames.cleanup(m,true) }
assert(pages.all? { |p| p.camera.aspect_ratio == 0 } && m.get_attribute(s::DICT,frames::BACKUP_KEY) == saved_backup, 'Failed restore lost backup or left partial frames')
pages[2].camera.aspect_ratio = 2.25; m.pages.erase(pages[3])
frames.cleanup(m,true)
assert(pages[2].camera.aspect_ratio == 2.25, 'Restore overwrote subsequently edited frame')

m.active_path = [Object.new]; count = m.events.length
rejects('editing cleanup') { frames.cleanup(m) }; assert(m.events.length == count,'Editing guard wrote model'); m.active_path = nil
s.instance_variable_set(:@job,Object.new)
assert(!s.dispatch('removeAllFrames',{'model'=>m.object_id.to_s})[:success], 'Export-busy cleanup allowed'); s.instance_variable_set(:@job,nil)
assert(!s.dispatch('removeAllFrames',{'model'=>'another-model'})[:success], 'Stale model cleanup allowed')
UI.next_confirmation = 7
assert(s.cleanup_frames_command[:cancelled] && m.events.length == count, 'Cancelled native-menu cleanup changed model')
UI.next_confirmation = IDYES
assert(s.cleanup_frames_command[:success] && frames.cleanup_state(m)[:count] == 0, 'Native-menu command failed')
assert(s.cleanup_frames_command(true)[:success], 'Native-menu restore failed')
Sketchup.active_model = previous_model
puts 'PASS: all-scene/live gray-frame removal, native/two-point/unused cameras, ID/lens/flags/cuts/frame sizes preserved, repeat/restore/export, partial-write rollback and edit/busy/model/menu-cancel guards'
