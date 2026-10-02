def assert(ok,message); raise message unless ok; end
def close(a,b); (a-b).abs < 0.0001; end
def panels(entities, offset=[0,0,0], result=[])
  entities.each do |e|
    tr=offset.zip(e.transformation.offset).map { |a,b| a+b }
    if e.is_a?(Sketchup::Group)
      faces=e.entities.grep(Sketchup::Face)
      unless faces.empty?
        pts=faces.flat_map(&:points).map { |p| p.zip(tr).map { |a,b| (a+b)*25.4 } }
        low=(0..2).map { |i| pts.map { |p| p[i] }.min }; high=(0..2).map { |i| pts.map { |p| p[i] }.max }
        result << {name:e.name, low:low, high:high, size:high.zip(low).map { |a,b| a-b }, group:e}
      end
      panels(e.entities,tr,result)
    end
  end
  result
end
def build(changes={})
  p=VGD_Cabinet::ModelingRules.normalize(changes,VGD_Cabinet.default_params)
  ents=Sketchup::Entities.new
  VGD_Cabinet::Modeling.draw(ents,p)
  values=panels(ents)
  assert(values.all? { |v| v[:size].all? { |n| n.finite? && n>0 } },'Invalid panel size')
  [p,values,ents]
end
def rejected(changes)
  VGD_Cabinet::ModelingRules.normalize(changes,VGD_Cabinet.default_params)
  raise 'Expected validation error'
rescue VGD_Cabinet::ModelingRules::Invalid
  true
end
metal_params={'door_style'=>'Kính khung kim loại','front_bevel'=>true}
['Cánh Lọt Hồi','Cánh Lọt Lòng','Cánh Phủ toàn bộ','Cánh Phủ Hồi Trái','Cánh Phủ Hồi Phải'].each do |style|
  _,metal_parts=build(metal_params.merge('opt_door'=>style))
  frames=metal_parts.select { |part| part[:name]=='Khung Kim Loại' }
  glasses=metal_parts.select { |part| part[:name]=='Kính' }
  assert(frames.length==2 && glasses.length==2,'Expected two complete glass doors')
  frames.zip(glasses).each do |frame,glass|
    assert(close(frame[:size][1],20)&&close(glass[:size][1],5),'Separate frame/glass depth')
    assert(close(glass[:size][0],frame[:size][0]-40)&&close(glass[:size][2],frame[:size][2]-40),'Glass opening not following frame')
    assert(close(glass[:low][1]-frame[:low][1],7.5),'Glass not centered')
    assert(frame[:group].entities.grep(Sketchup::Face).size==4,'Four plain extrusions expected in frame test stub')
    assert(frame[:group].material!=glass[:group].material,'Materials must remain separate')
  end
  total_depth=metal_parts.map { |part| part[:high][1] }.max-metal_parts.map { |part| part[:low][1] }.min
  assert(close(total_depth,600),'Metal door changed overall cabinet depth')
end
_,metal_parts=build(metal_params.merge('w'=>2400,'module_mode'=>'Độc lập','module_widths'=>'800;800;800','h'=>2700,'h_bottom'=>2100,'metal_frame_width'=>30,'metal_frame_depth'=>25,'glass_thickness'=>6))
assert(metal_parts.count { |p| p[:name]=='Kính' }==12,'Glass doors missing in independent modules / tiers')
glass=metal_parts.find { |p| p[:name]=='Kính' };frame=metal_parts.find { |p| p[:name]=='Khung Kim Loại' }
assert(close(glass[:size][0],frame[:size][0]-60)&&close(glass[:low][1]-frame[:low][1],9.5),'Custom frame sizes ignored')
material=Sketchup.active_model.materials['VGD Khung Đen'];material.color=:user_color
build(metal_params)
assert(material.color==:user_color,'User material edit overwritten')
rejected(metal_params.merge('glass_thickness'=>25))
rejected(metal_params.merge('metal_frame_width'=>0))
begin
  build(metal_params.merge('metal_frame_width'=>300))
  raise 'Oversized frame should reject, not silently omit doors'
rescue VGD_Cabinet::ModelingRules::Invalid
end
puts 'PASS: concept glass doors, 5 overlay/inset modes, centered glass, two materials, custom sizes, tiers/modules, invalid dimensions, edited materials preserved'
p,parts=build
_,structure=build('opt_drawer'=>'Âm','drawer_columns'=>2,'drawer_frame_depth'=>400,'t'=>17,'auto_divider_wide'=>false,'auto_door_count'=>false,'door_count'=>2)
assert(structure.count { |v| v[:name].start_with?('Mặt Ngăn Kéo') }==4,'Two columns with two tiers must make four drawers')
frame_top=structure.find { |v| v[:name]=='Đợt Nóc Khung Ngăn Kéo Âm' }
frame_side=structure.find { |v| v[:name]=='Hông Khung Ngăn Kéo Âm Trái' }
assert(close(frame_top[:size][1],400)&&close(frame_side[:size][1],383),'M2 depth must be overall 400, side 383')
assert(structure.count { |v| v[:name]=='Hồi Giữa Két' }==1,'Missing central divider within one cabinet bay')
rail=structure.find { |v| v[:name]=='Xà Đáy Két Trước' }
assert(close(rail[:size][1],50)&&close(rail[:size][2],17),'Base rail must be horizontal')
assert(structure.any? { |v| v[:name]=='Xà Đón Mặt Hộc' },'Missing independent head rail')
back=structure.find { |v| v[:name]=='Tấm Hậu' }
assert(close(back[:size][0],783),'Automatic back embed must be half side thickness')
_,custom_back=build('t'=>20,'back_groove_auto'=>false,'back_groove_depth'=>5)
assert(close(custom_back.find { |v| v[:name]=='Tấm Hậu' }[:size][0],770),'Custom back embed ignored')
['Âm hai bên','Âm bốn phía','Phủ dưới'].each do |mode|
  _,items=build('opt_drawer'=>'Âm','drawer_columns'=>1,'drawer_frame_depth'=>400,'drawer_bottom_mode'=>mode)
  left=items.find { |v| v[:name]=='Vách Ngăn Kéo Trái 1' };right=items.find { |v| v[:name]=='Vách Ngăn Kéo Phải 1' }
  bottom=items.find { |v| v[:name]=='Đáy Ngăn Kéo 1' };front=items.find { |v| v[:name]=='Đầu Ngăn Kéo 1' }
  total=right[:high][0]-left[:low][0]
  assert(close(bottom[:size][0],mode=='Phủ dưới' ? total : total-17.5),'Wrong bottom width')
  assert(close(bottom[:size][1],mode=='Âm bốn phía' ? left[:size][1]-17.5 : left[:size][1]),'Wrong bottom depth')
  assert(close(front[:low][2],bottom[:high][2]),'End panel must sit above bottom') if mode=='Âm hai bên'
  assert(close(left[:low][2],bottom[:high][2]),'Overlay bottom must sit below sides') if mode=='Phủ dưới'
end
_,joint=build('h'=>2700,'h_bottom'=>2100,'overheight_join'=>'Xà Trên')
assert(joint.any? { |v| v[:name]=='Xà Ngang Trên Trước' }&&joint.any? { |v| v[:name]=='Xà Ngang Trên Sau' },'Upper joint missing horizontal rails')
assert(joint.any? { |v| v[:name]=='Tấm Đáy Trên' }&&!joint.any? { |v| v[:name]=='Tấm Nóc Dưới' },'Upper joint plate ownership incorrect')
rejected('drawer_columns'=>3)
rejected('opt_drawer'=>'Âm','drawer_frame_depth'=>800)
puts 'PASS: two drawer columns, 400 overall frame depth, horizontal base rails, independent head rail, back embed, all three bottom modes, upper joint'
bottom=parts.find { |v| v[:name]=='Tấm Đáy' }
assert(close(bottom[:size][0],765),'800 with 17.5 sides must have 765 bottom')
assert(close(parts.find { |v| v[:name]=='Hồi Trái' }[:size][2],2400),'Continuous side height')
puts 'PASS: actual thickness and sandwiched bottom'
p,parts,ents=build('w'=>2400,'module_mode'=>'Độc lập','module_widths'=>'800;800;800')
assert(ents.size==3,'3 independent modules expected')
assert(parts.count { |v| ['Hồi Trái','Hồi Phải'].include?(v[:name]) }==6,'Independent modules require six sides')
assert(close(parts.map { |v| v[:high][0] }.max,2400),'Module width sum')
puts 'PASS: independent modules and overall width'
['Âm','Phủ','Không'].each do |mode|
 _,pts=build('back_mode'=>mode,'opt_door'=>'Cánh Phủ toàn bộ')
 depth=pts.map { |v| v[:high][1] }.max-pts.map { |v| v[:low][1] }.min
 assert(close(depth,600),"Overall depth failed #{mode}: #{depth}")
 assert(pts.none? { |v| v[:name].include?('Hậu') },'No-back produced a back') if mode=='Không'
 puts "PASS: back #{mode}, overall depth 600"
end
_,parts=build('h'=>2700,'is_overheight'=>true,'h_bottom'=>2100,'shelf_count_top'=>1)
sides=parts.select { |v| v[:name].start_with?('Hồi Trái','Hồi Phải') }
assert(sides.size==4 && sides.all? { |v| v[:size][2]<=2400 },'Height split invalid')
puts 'PASS: overheight splits side panels'
_,parts=build('door_stop_rail'=>true,'front_bevel'=>true,'door_top_gap'=>25)
assert(parts.any? { |v| v[:name].start_with?('Xà Chặn Cánh') },'Door rail missing')
front=parts.find { |v| v[:name]=='Cánh Trái' }
assert(close(front[:high][2],2400-VGD_Cabinet.default_params['shadow_gap_h']-25),'Top front gap ignored')
_,parts=build('h'=>2700,'is_overheight'=>true,'h_bottom'=>2100,'door_stop_rail'=>true)
assert(parts.any? { |v| v[:name].start_with?('Xà Chặn Cánh') },'Upper rail missing')
puts 'PASS: door top gap, bevel and stop rails'
_,parts=build('opt_drawer'=>'Âm','t'=>20,'drawer_hinge_sp'=>50,'drawer_inner_offset'=>50)
side=parts.find { |v| v[:name]=='Hông Khung Ngăn Kéo Âm Trái' }
trim=parts.find { |v| v[:name]=='Diềm Phủ Hông Ngăn Kéo Âm Trái' }
assert(close(side[:low][0]-20,30),'Concealed drawer side offset must be 30')
assert(close(trim[:size][0],50) && close(trim[:size][1],20),'Trim width and thickness mixed')
assert(parts.select { |v| v[:name].start_with?('Mặt Ngăn Kéo') }.all? { |v| v[:group].layer=='VGD_CANH' },'Front tags')
puts 'PASS: concealed drawer 50 mm trim, 20 mm material, 30 mm side gap'
_,parts=build('h'=>810,'shadow_gap_h'=>0,'opt_door'=>'Không Cánh','opt_drawer'=>'Lộ','is_full_drawer'=>true,'drawer_count'=>3,'front_bevel'=>true,'drawer_gap'=>25,'drawer_backing_rail'=>true)
fronts=parts.select { |v| v[:name].start_with?('Mặt Ngăn Kéo') }
assert(fronts.size==3,'Drawer count')
assert(fronts.all? { |v| v[:group].entities.grep(Sketchup::ConstructionLine).size==1 },'Exactly one guide per front')
assert(fronts.all? { |v| v[:group].entities.grep(Sketchup::Face).first.points.size==10 },'Bevel section missing')
puts 'PASS: beveled drawer fronts, guides, backing rails'
[{ 'w'=>30 },{'t'=>0},{'module_mode'=>'Độc lập','module_widths'=>'700;700'}, {'drawer_count'=>1.5},{'opt_drawer'=>'Âm','drawer_hinge_sp'=>390},{'d'=>100,'back_recess'=>100},{'shelf_count'=>20,'h'=>200},{'front_bevel'=>true,'bevel_lip'=>30}].each { |c| rejected(c) }
puts 'PASS: eight invalid configurations rejected'
