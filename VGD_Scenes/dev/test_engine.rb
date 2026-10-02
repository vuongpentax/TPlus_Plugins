def assert(value,message);raise message unless value;end
def near(a,b);(a-b).abs<0.00001;end
def rejects(label)
  begin;yield;rescue StandardError;return;end
  raise "Did not reject: #{label}"
end
def product(model, width=1000.0/25.4, depth=600.0/25.4, height=800.0/25.4, name='Tủ')
  bounds=Geom::BoundingBox.new.add([Geom::Point3d.new(0,0,0),Geom::Point3d.new(width,depth,height)])
  group=Sketchup::Group.new(Sketchup::Definition.new(bounds,Sketchup::Entities.new,'Tủ nguồn'),name);group.layer=model.layers.first;model.entities << group;group
end
module TestScenes;S=VGD::Scenes;end
s=TestScenes::S
opts=s.options({})
rejects('bad size'){s.options('width'=>0)}
rejects('huge memory'){s.options('width'=>12000,'height'=>12000)}
rejects('nonfinite'){s.options('margin'=>Float::NAN)}
rejects('bad view'){s.options('views'=>['NOPE'])}
assert(s.clean_filename('../A:B\\C')=='.._A_B_C','Unsafe filename handling')
assert(s.clean_filename('CON')=='_CON','Reserved Windows name')
assert(s.clean_filename('Tủ O\'Brien')=="Tủ O'Brien",'Unicode lost')
model=Sketchup.active_model;target=product(model);other=product(model,10,10,10,'Khác');model.selection.add(target)
target.transformation=Geom::Transformation.rotation_z(45)
data=s::Geometry.target(model,[[target.persistent_id]],'local')
cam=s::Geometry.fit(model,data,'FRONT',opts)
assert(near(cam.height,[800.0/25.4,(1000.0/25.4)/(1920.0/1080)].max*1.1),'Rotated camera uses inflated world bbox')
point,normal=s::Geometry.section(data,opts)
assert(near((point-data[:center]).dot(normal),0),'Center cut position wrong')
cut_opts=opts.merge('section_percent'=>0,'section_offset'=>25.4)
point,normal=s::Geometry.section(data,cut_opts)
assert(near((point-data[:center]).dot(normal),-300.0/25.4+1),'Local cut percentage/mm offset wrong')
_,reversed=s::Geometry.section(data,opts.merge('section_flip'=>true))
assert(near(normal.dot(reversed),-1),'Cut reverse wrong')
rejects('zero normal'){s::Geometry.section(data,opts.merge('section_axis'=>'CUSTOM','normal_y'=>0))}
parent=product(model);parent.transformation=Geom::Transformation.translation(200,100,30)
child=product(model);model.entities.delete(child);parent.definition.entities << child;child.transformation=Geom::Transformation.scaling(-2,1.5,1)
nested=s::Geometry.target(model,[[parent.persistent_id,child.persistent_id]],'local')
assert(near(nested[:center].x,200-1000.0/25.4),'Nested/mirrored transform wrong')
assert(near(nested[:axes][0].x,-1),'Mirror direction lost')
puts 'PASS: validation, Unicode filenames, rotated/local fit, custom cuts, nested/mirrored transforms'
foreign=model.pages.add('Tủ_ISO');foreign.update(0)
root_plane=model.entities.add_section_plane([Geom::Point3d.new(0,0,0),Geom::Vector3d.new(0,1,0)]);root_plane.name='Foreign cut';model.entities.active_section_plane=root_plane
rendering=model.rendering_options.dup
result=s::SceneStore.generate(model,opts)
assert(result[:ids].length==4 && model.pages.length==5,'Wrong scene count')
assert(foreign.name=='Tủ_ISO' && !s::SceneStore.owned?(foreign),'Overwrote foreign scene')
assert(model.pages.find { |p| p.persistent_id.to_s==result[:ids][0] }.name=='Tủ_ISO (2)','Collision not protected')
s::SceneStore.generate(model,opts)
assert(model.pages.length==5,'Repeated generation duplicates scenes')
model.entities.active_section_plane=root_plane;model.rendering_options.replace(rendering)
section=s::SceneStore.generate(model,opts,true)
page=s::SceneStore.find(model,section[:ids].first)
assert(page.saved[:plane].nil? && page.saved[:sections].any? { |entities,plane| entities.equal?(target.entities) && plane },'Cut not stored inside target before capture')
assert(other.entities.grep(Sketchup::SectionPlane).empty?,'Cut leaked into other object')
plane_count=target.entities.grep(Sketchup::SectionPlane).length
s::SceneStore.generate(model,opts.merge('section_percent'=>60),true)
assert(target.entities.grep(Sketchup::SectionPlane).length==plane_count,'Update duplicates cut planes')
snapshot=s::ViewState.new(model);saved_camera=model.active_view.camera.eye.to_a;other.hidden=false;model.layers.first.visible=false;model.entities.active_section_plane=root_plane;snapshot.restore
assert(model.active_view.camera.eye.to_a==saved_camera && model.layers.first.visible?,'State restoration failed')
assert(model.events.count { |event| event[0]==:commit }==4,'Missing operations')
target.name='Tủ đổi tên'
s::SceneStore.generate(model,opts.merge('views'=>['FRONT']))
assert(result[:ids].all? { |pid| s::SceneStore.find(model,pid).name.start_with?('Tủ đổi tên_') },'Partial refresh did not rename all object views')
assert(page.name=='Tủ đổi tên_SEC_A-A','View refresh did not rename section scene')
assert(foreign.name=='Tủ_ISO','Rename changed foreign scene')
target.name='Tủ lần hai';s::SceneStore.update_sources(model,[page.persistent_id.to_s])
assert(page.name=='Tủ lần hai_SEC_A-A','Source refresh did not rename scene')
section_data=s::Geometry.target(model,[[target.persistent_id]],'local')
[false,true].each do |flip|
  s::SceneStore.generate(model,opts.merge('section_flip'=>flip),true)
  _point,cut_normal=s::Geometry.section(section_data,opts.merge('section_flip'=>flip))
  direction=(page.saved[:camera].target-page.saved[:camera].eye).normalize
  assert(near(direction.dot(cut_normal),1),'Camera faces retained backside instead of cut opening')
end
local_point,local_normal=s::Geometry.local_plane(nested[:resolved].first[1],point,normal)
world_point=local_point.transform(nested[:resolved].first[1])
assert(near((world_point-point).length,0),'Plane position lost under nested transform')
local_tangent=local_normal.cross(Geom::Vector3d.new(0,0,1))
world_tangent=local_point.offset(local_tangent,5).transform(nested[:resolved].first[1])-world_point
assert(near(world_tangent.dot(normal),0),'Plane normal incorrect under mirror/nonuniform scale')
shared=product(model,30,20,10,'Bản chọn');copy=Sketchup::ComponentInstance.new(shared.definition,'Bản khác');copy.layer=model.layers.first;model.entities << copy
model.selection.clear;model.selection.add(shared)
shared_result=s::SceneStore.generate(model,opts,true)
assert(shared.definition!=copy.definition && copy.definition.entities.grep(Sketchup::SectionPlane).empty?,'Cut changed another component instance')
shared_page=s::SceneStore.find(model,shared_result[:ids].first)
assert(shared_page.saved[:sections].any? { |entities,plane| entities.equal?(shared.entities) && plane },'Unique cut was not captured')
model.selection.clear;model.selection.add([target,other])
combined=s::SceneStore.generate(model,opts,true);combined_page=s::SceneStore.find(model,combined[:ids].first)
assert([target.entities,other.entities].all? { |entities| combined_page.saved[:sections].any? { |context,plane| context.equal?(entities) && plane } },'Combined cut not scoped to each object')
assert(model.entities.grep(Sketchup::SectionPlane)==[root_plane],'New section plane leaked to model root')
model.selection.clear;model.selection.add(target)
legacy=model.entities.add_section_plane([Geom::Point3d.new(0,0,0),Geom::Vector3d.new(0,1,0)])
legacy.set_attribute(s::DICT,'owner','VGD Scenes');legacy.set_attribute(s::DICT,'scene_pid',page.persistent_id.to_s)
model.entities.active_section_plane=legacy
before_local=target.entities.active_section_plane
s::SceneStore.update_sources(model,[page.persistent_id.to_s])
assert(legacy.valid? && page.saved[:plane].nil?,'Legacy root cut still active in updated section scene or erased')
assert(model.entities.active_section_plane==legacy && target.entities.active_section_plane==before_local,'Source update failed to restore local/root active cut')
parent_copy=Sketchup::ComponentInstance.new(parent.definition,'Cha bản sao');model.entities << parent_copy
rejects('shared ancestor'){s::Geometry.validate_section_target(nested)}
puts 'PASS: rename all source scenes, source-refresh rename, section camera both directions, local mirrored/scaled plane, shared instance isolation, combined local cuts'
rejects('manual foreign regenerate'){s::SceneStore.update_sources(model,[foreign.persistent_id.to_s])}
id=result[:ids][0];s::SceneStore.rename(model,id,"Tủ O'Brien");assert(s::SceneStore.find(model,id).name=="Tủ O'Brien",'ID rename failed')
s::SceneStore.capture(model,id)
update_page=s::SceneStore.find(model,id);update_page.fail=true
rejects('failed native capture'){s::SceneStore.update_sources(model,[id])}
assert(model.events.last[0]==:abort,'Failed scene not aborted');update_page.fail=false
count=model.pages.length;s::SceneStore.delete(model,[id]);assert(model.pages.length==count-1 && foreign.valid?,'Delete touched unrelated scene')
assert(root_plane.valid?,'Foreign plane erased')
puts 'PASS: owned scene updates, name collisions, cut-before-capture, no duplicate cuts, explicit ID operations, abort invocation'
FileUtils.mkdir_p('/tmp/vgd-tests')
export_pages=model.pages.first(2);model.pages.selected_page=foreign
model.layers.first.visible=false;other.hidden=true;model.entities.active_section_plane=root_plane
camera=s.camera_copy(model.active_view.camera);options_before=model.options['PageOptions'].dup
events=[];job=s::ExportJob.new(model,export_pages,opts.merge('transparent'=>true),'/tmp/vgd-tests',lambda { |event,payload| events << [event,payload] })
job.start;UI.drain
done=events.last[1];assert(done[:success] && done[:count]==2,"PNG batch failed: #{done.inspect}")
assert(model.active_view.writes.last[:transparent],'PNG alpha flag lost')
assert(model.pages.selected_page==foreign && model.entities.active_section_plane==root_plane && !model.layers.first.visible? && other.hidden?,'Export failed to restore original view')
assert(model.active_view.camera.eye==camera.eye && model.options['PageOptions']==options_before,'Export camera/animation not restored')
model.active_view.fail_write=true
events=[];job=s::ExportJob.new(model,export_pages,opts,'/tmp/vgd-tests',lambda { |event,payload| events << [event,payload] });job.start;UI.drain
assert(!events.last[1][:success] && events.last[1][:errors].length==2,'Failed write reported success')
events=[];job=s::ExportJob.new(model,export_pages,opts.merge('format'=>'pdf'),'/tmp/vgd-tests/fail.pdf',lambda { |event,payload| events << [event,payload] });job.start;UI.drain
assert(!File.exist?('/tmp/vgd-tests/fail.pdf') && !events.last[1][:success],'Partial PDF emitted')
model.active_view.fail_write=false
events=[];job=s::ExportJob.new(model,export_pages,opts.merge('format'=>'jpg','transparent'=>true),'/tmp/vgd-tests',lambda { |event,payload| events << [event,payload] });job.start;UI.drain
assert(events.last[1][:success] && !model.active_view.writes.last[:transparent],'JPEG alpha flag wrong')
events=[];job=s::ExportJob.new(model,export_pages,opts.merge('format'=>'pdf'),'/tmp/vgd-tests/full.pdf',lambda { |event,payload| events << [event,payload] });job.start;UI.drain
doc=Layout.documents.last;assert(events.last[1][:success] && doc.pages.length==2 && doc.pages.all? { |p| p.images.length==1 },'PDF scene-page assembly wrong')
image=doc.pages.first.images.first;assert(near(image.bounds.width/image.bounds.height,1920.0/1080),'PDF image stretched')
events=[];job=s::ExportJob.new(model,export_pages,opts,'/tmp/vgd-tests',lambda { |event,payload| events << [event,payload] });job.start;job.cancel;UI.drain
assert(events.last[1][:cancelled] && events.last[1][:count]==0 && !s::FrameTool.suspended,'Cancel failed cleanup')
assert(UI.toolbars.length==1 && UI.toolbars.first.events==[:add,:add],'Startup changed toolbar visibility')
puts 'PASS: selected-scene PNG/JPG alpha rules, failure reporting, cancelled cleanup, state restoration, mock PDF pages/aspect, own toolbar only'

model.selection.clear;model.selection.add(target)
frames=s::SceneStore.generate(model,opts.merge('views'=>%w[TOP ISO]))
top_page,iso_page=frames[:ids].map { |pid| s::SceneStore.find(model,pid) }
model.pages.selected_page=top_page
direction=(model.active_view.camera.target-model.active_view.camera.eye).normalize
up=model.active_view.camera.up
portrait=opts.merge('width'=>1200,'height'=>1600,'margin'=>25)
saved_rendering=top_page.saved[:rendering].dup
saved_frame=s::SceneFrame.read(top_page,opts)
saved_camera=top_page.camera
before_operations=model.events.length
model.rendering_options['DisplaySectionCuts']=!saved_rendering['DisplaySectionCuts']
s.apply_frame(model,portrait,true)
assert(s::SceneFrame.read(top_page,opts)==saved_frame && top_page.camera.equal?(saved_camera) && model.events.length==before_operations,'Fit preview saved scene or started an operation')
assert(top_page.saved[:rendering]==saved_rendering,'Applying frame captured unrelated rendering changes')
fitted=model.active_view.camera
assert((fitted.target-fitted.eye).normalize==direction && fitted.up==up && !fitted.perspective?,'Frame fit changed TOP view orientation/projection')
assert(near(fitted.aspect_ratio,0.75),'Frame fit ignored portrait aspect')
s.apply_frame(model,portrait)
assert(s::SceneFrame.read(top_page,opts)==portrait.select { |key,_| %w[width height margin].include?(key) },'Current scene frame not saved')
s::SceneStore.capture(model,top_page.persistent_id.to_s)
s::SceneStore.update_sources(model,[top_page.persistent_id.to_s])
assert(s::SceneFrame.read(top_page,opts)['width']==1200 && near(top_page.camera.aspect_ratio,0.75),'Source update/capture discarded per-scene frame')
model.pages.selected_page=iso_page;s.apply_frame(model,opts)
FileUtils.mkdir_p('/tmp/mixed-frames')
events=[];job=s::ExportJob.new(model,[top_page,iso_page],opts.merge('width'=>2400,'height'=>2400),'/tmp/mixed-frames',lambda { |event,payload| events << [event,payload] });job.start;UI.drain
assert(events.last[1][:success],'Mixed frame image export failed')
sizes=model.active_view.writes.last(2).map { |write| [write[:width],write[:height]] }
assert(sizes==[[1200,1600],[1920,1080]],'Export replaced per-scene sizes with batch size')
events=[];job=s::ExportJob.new(model,[top_page,iso_page],opts.merge('format'=>'jpg'),'/tmp/mixed-frames',lambda { |event,payload| events << [event,payload] });job.start;UI.drain
assert(events.last[1][:success] && model.active_view.writes.last(2).map { |write| [write[:width],write[:height]] }==sizes,'JPG lost per-scene sizes')
events=[];job=s::ExportJob.new(model,[top_page,iso_page],opts.merge('format'=>'pdf','width'=>2400,'height'=>2400),'/tmp/mixed-frames/mixed.pdf',lambda { |event,payload| events << [event,payload] });job.start;UI.drain
assert(events.last[1][:success],'Mixed frame PDF failed')
pdf_ratios=Layout.documents.last.pages.map { |p| image=p.images.first;image.bounds.width/image.bounds.height }
assert(near(pdf_ratios[0],0.75) && near(pdf_ratios[1],16.0/9),'PDF used a single aspect for all scenes')
perspective=Sketchup::Camera.new(Geom::Point3d.new(100,-100,80),Geom::Point3d.new(0,0,0),Geom::Vector3d.new(0,0,1),true);perspective.fov=50
model.active_view.camera=perspective
direction=(perspective.target-perspective.eye).normalize
s.apply_frame(model,portrait,true);fitted=model.active_view.camera
assert(fitted.perspective? && near(fitted.fov,50) && (fitted.target-fitted.eye).normalize==direction,'Perspective fit changed direction/FOV/projection')
right=direction.cross(fitted.up).normalize;tan_y=Math.tan(fitted.fov*Math::PI/360);tan_x=tan_y*fitted.aspect_ratio
points=s::Geometry.target(model,[[target.persistent_id]],'local')[:points]
assert(points.all? { |point| delta=point-fitted.eye;z=delta.dot(direction);z>0 && delta.dot(right).abs <= z*tan_x/1.25+1e-6 && delta.dot(fitted.up).abs <= z*tan_y/1.25+1e-6 },'Perspective frame clipped object or ignored margin')
puts 'PASS: current TOP/orthographic and perspective fit, saved per-scene frame/capture/source update, mixed PNG/JPG/PDF sizes/aspects, no report JSON'
model.active_view.camera=Sketchup::Camera.new(Geom::Point3d.new(100,-100,80),Geom::Point3d.new(0,0,0),Geom::Vector3d.new(0,0,1),false)
other.transformation=Geom::Transformation.translation(200,50,90)
model.selection.clear;model.selection.add([target,other])
s.apply_frame(model,portrait,true);fitted=model.active_view.camera
direction=(fitted.target-fitted.eye).normalize;right=direction.cross(fitted.up).normalize
points=s::Geometry.target(model,[[target.persistent_id],[other.persistent_id]],'local')[:points]
assert(points.all? { |point| d=point-fitted.target;d.dot(right).abs <= fitted.height*fitted.aspect_ratio/2/1.25+1e-6 && d.dot(fitted.up).abs <= fitted.height/2/1.25+1e-6 },'Off-center multi-object fit clipped corners')
saved_frame=s::SceneFrame.read(iso_page,opts);saved_camera=iso_page.camera
s.apply_frame(model,portrait,false,false)
assert(iso_page.camera.equal?(saved_camera) && s::SceneFrame.read(iso_page,opts)==saved_frame,'Ratio preview saved scene')
s.toggle_frame(model,portrait)
assert(model.active_view.camera.aspect_ratio==0 && iso_page.camera.equal?(saved_camera),'Frame off changed saved scene or did not restore native viewport')
payload={'model'=>model.object_id.to_s,'settings'=>portrait}
assert(s.dispatch('grid',payload)[:success] && s::FrameTool.active? && model.active_view.camera.aspect_ratio==0,'Grid on enabled/saved frame')
s.toggle_frame(model,portrait)
assert(s::FrameTool.active? && near(model.active_view.camera.aspect_ratio,0.75),'Frame on turned off grid')
assert(s.dispatch('grid',payload)[:success] && !s::FrameTool.active? && near(model.active_view.camera.aspect_ratio,0.75),'Grid off disabled frame')
quick=product(model,20,30,40,'Nhanh');model.selection.clear;model.selection.add(quick)
before_count=model.pages.length;s.quick_views
quick_pages=model.pages.select { |page| s::SceneStore.owned?(page) && s::SceneStore.metadata(page)['paths']==[[quick.persistent_id]] }
assert(model.pages.length==before_count+4 && quick_pages.map { |page| s::SceneStore.metadata(page)['kind'] }.sort==%w[FRONT ISO RIGHT TOP],'Toolbar quick action not four views')
commands=UI.toolbars.first.commands
assert(commands[0].small_icon!=commands[1].small_icon && commands[1].small_icon.end_with?('quick_views.svg'),'Quick toolbar icon not distinct')
export_page=quick_pages.first
saved_eye=export_page.camera.eye
events=[];job=s::ExportJob.new(model,[export_page],portrait,'/tmp/mixed-frames',lambda { |event,payload| events << [event,payload] });job.start;UI.tick
model.active_view.camera=Sketchup::Camera.new(Geom::Point3d.new(900,900,900),Geom::Point3d.new(0,0,0),Geom::Vector3d.new(0,0,1),false)
UI.drain
assert(events.last[1][:success] && model.active_view.last_written_camera.eye==saved_eye,'Export captured live preview instead of saved scene camera')
puts 'PASS: fit/swap preview without saving, native viewport frame off, independent frame/grid switches, four quick views and distinct SVG icon'
rejects('zero scale'){s.options('export_scale'=>0)}
rejects('nan scale'){s.options('export_scale'=>Float::NAN)}
assert(s.export_dimensions({'width'=>1920,'height'=>1080},2)=={'width'=>3840,'height'=>2160},'Scale 2 dimensions wrong')
assert(s.export_dimensions({'width'=>1920,'height'=>1080},0.5)=={'width'=>960,'height'=>540},'Scale 0.5 dimensions wrong')
rejects('oversize scale'){s.export_dimensions({'width'=>1920,'height'=>1080},10)}
FileUtils.mkdir_p('/tmp/scaled-exports')
stored=s::SceneFrame.read(export_page,opts)
[0.5,2,1.25].each do |scale|
  events=[];scaled=opts.merge('export_scale'=>scale)
  job=s::ExportJob.new(model,[export_page],scaled,'/tmp/scaled-exports',lambda { |event,payload| events << [event,payload] });job.start;UI.drain
  write=model.active_view.writes.last;expected=s.export_dimensions(stored,scale)
  assert(events.last[1][:success] && [write[:width],write[:height]]==[expected['width'],expected['height']],'Arbitrary scale not applied at export')
  assert(s::SceneFrame.read(export_page,opts)==stored,'Export scale changed scene dimensions')
end
before_events=model.events.length;before_camera=model.active_view.camera
rejects('preflight too-large scene'){s::ExportJob.new(model,[export_page],opts.merge('export_scale'=>20),'/tmp/scaled-exports',lambda { |*_| })}
assert(model.events.length==before_events && model.active_view.camera.equal?(before_camera),'Invalid scale modified model')
events=[];job=s::ExportJob.new(model,[top_page,iso_page],opts.merge('format'=>'pdf','export_scale'=>2),'/tmp/scaled-exports/scaled.pdf',lambda { |event,payload| events << [event,payload] });job.start;UI.drain
assert(events.last[1][:success] && model.active_view.writes.last(2).map { |w| [w[:width],w[:height]] }==[[2400,3200],[3840,2160]],'PDF did not scale per-scene images')
ratios=Layout.documents.last.pages.map { |page| b=page.images.first.bounds;b.width/b.height }
assert(near(ratios[0],0.75) && near(ratios[1],16.0/9),'Scaled PDF changed frame aspect')
date=Time.utc(2026,10,3,12)
%w[png jpg pdf].each do |kind|
  directory=s.output_directory('/tmp/scaled-exports',opts.merge('format'=>kind,'date_folder'=>true),date)
  assert(directory=="/tmp/scaled-exports/2026.10.03/#{kind.upcase}" && File.directory?(directory),'Dated format folder wrong')
end
assert(s.output_directory('/tmp/scaled-exports',opts,date)=='/tmp/scaled-exports/PNG','Unticked date option still created day folder')
UI.next_directory='/tmp/scaled-exports'
s.export_selected(model,{'ids'=>[export_page.persistent_id.to_s],'settings'=>opts.merge('export_scale'=>0.5,'date_folder'=>true)})
UI.drain
assert(s.instance_variable_get(:@output_folder)=="/tmp/scaled-exports/#{Time.now.strftime('%Y.%m.%d')}/PNG",'Directory picker did not route dated PNG')
UI.next_savepanel='/tmp/scaled-exports/Final.PDF'
2.times do
  s.export_selected(model,{'ids'=>[export_page.persistent_id.to_s],'settings'=>opts.merge('format'=>'pdf','export_scale'=>2)})
  UI.drain
end
assert(File.file?('/tmp/scaled-exports/PDF/Final.pdf') && File.file?('/tmp/scaled-exports/PDF/Final_2.pdf'),'PDF path/type folder or no-overwrite numbering wrong')
puts 'PASS: arbitrary batch scale, per-scene/PDF aspect unchanged, preflight bounds, dated type folders, native-picker routing and collision numbering'
