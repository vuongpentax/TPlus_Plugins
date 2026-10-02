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
assert(page.saved[:plane] && page.saved[:plane]!=root_plane,'Scene stored before own cut')
plane_count=model.entities.grep(Sketchup::SectionPlane).length
s::SceneStore.generate(model,opts.merge('section_percent'=>60),true)
assert(model.entities.grep(Sketchup::SectionPlane).length==plane_count,'Update duplicates cut planes')
snapshot=s::ViewState.new(model);saved_camera=model.active_view.camera.eye.to_a;other.hidden=false;model.layers.first.visible=false;model.entities.active_section_plane=root_plane;snapshot.restore
assert(model.active_view.camera.eye.to_a==saved_camera && model.layers.first.visible?,'State restoration failed')
assert(model.events.count { |event| event[0]==:commit }==4,'Missing operations')
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
