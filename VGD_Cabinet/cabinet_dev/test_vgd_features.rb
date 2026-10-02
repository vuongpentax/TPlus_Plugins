p=VGD_Cabinet.default_params
assert(p['shadow_gap_h']==20,'Ceiling strip must be 20')
%w[door_gap door_top_gap door_gap_outer door_gap_left door_gap_right door_gap_top door_gap_bottom door_gap_between drawer_gap_outer drawer_gap_left drawer_gap_right drawer_gap_top drawer_gap_bottom].each { |k| assert(p[k]==0,"Default #{k} must be zero") }
assert(p['drawer_gap']==25 && p['drawer_gap_between']==25 && p['mid_door_gap']==25,'Tier gaps must remain 25')
_,parts=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'front_bevel'=>true,'drawer_bevel'=>false))
fronts=parts.select { |v| v[:name].start_with?('Mặt Ngăn Kéo') }
assert(fronts.all? { |v| v[:group].entities.grep(Sketchup::Face).first.points.size==8 },'Door handle changed drawers')
_,parts=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'front_bevel'=>false,'drawer_bevel'=>true))
assert(parts.select { |v| v[:name].start_with?('Mặt Ngăn Kéo') }.all? { |v| v[:group].entities.grep(Sketchup::Face).first.points.size==10 },'Drawer handle not beveled')
assert(parts.select { |v| v[:name].start_with?('Cánh') }.all? { |v| v[:group].entities.grep(Sketchup::Face).first.points.size==8 },'Drawer handle changed doors')
old=VGD_Cabinet::ModelingRules.normalize({'front_bevel'=>true,'bevel_lip'=>3},p)
assert(old['drawer_bevel'] && old['drawer_bevel_lip']==3 && old['handle_split_v1'],'Legacy shared handle migration failed')
_,items=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'door_stop_rail'=>true,'drawer_backing_rail'=>false))
assert(items.any? { |v| v[:name].start_with?('Xà Chặn Cánh') } && items.none? { |v| v[:name].start_with?('Xà Che Khe Ngăn Kéo') },'Door stop rail changed drawer rail')
_,items=build(p.merge('opt_drawer'=>'Lộ','drawer_count'=>2,'door_stop_rail'=>false,'drawer_backing_rail'=>true))
assert(items.none? { |v| v[:name].start_with?('Xà Chặn Cánh') } && items.any? { |v| v[:name].start_with?('Xà Che Khe Ngăn Kéo') },'Drawer rail changed door rail')

['Cánh Lọt Hồi','Cánh Lọt Lòng','Cánh Phủ toàn bộ','Cánh Phủ Hồi Trái','Cánh Phủ Hồi Phải'].each do |style|
  normalized,items=build('door_style'=>'Pano khung gỗ','opt_door'=>style,'pano_panel_count'=>2)
  panels=items.select { |v| v[:name].start_with?('Pano ') }
  left=items.select { |v| v[:name]=='Đố Pano Trái' }
  assert(panels.size==4 && left.size==2,'Missing separate pano pieces')
  dimensions=VGD_Cabinet::Modeling.pano_sizes(items.find { |v| v[:name]=='Thanh Pano Dưới' }[:size][0]+120,left.first[:size][2],normalized)
  assert(close(panels.first[:size][0],dimensions[:panel_w]) && close(panels.first[:size][2],dimensions[:panel_h]),'Groove/capture/expansion sizing incorrect')
  assert(close(panels.first[:size][1],6),'Panel thickness wrong')
  assert(left.first[:group].entities.grep(Sketchup::Face).first.points.size==16,'Stile groove missing')
  total_depth=items.map { |v| v[:high][1] }.max-items.map { |v| v[:low][1] }.min
  assert(close(total_depth,600),'Pano changed overall cabinet depth')
end
_,items=build(p.merge('door_style'=>'Pano khung gỗ','front_bevel'=>true,'pano_panel_count'=>3,'pano_stile_width'=>70,'pano_depth'=>22,'pano_panel_thickness'=>8))
assert(items.count { |v| v[:name].start_with?('Pano ') }==6,'Custom/multiple panels failed')
assert(items.find { |v| v[:name]=='Thanh Pano Trên' }[:group].entities.grep(Sketchup::Face).first.points.size==18,'Pano top rail bevel missing')
_,items=build('door_style'=>'Pano khung gỗ','w'=>1600,'module_mode'=>'Độc lập','module_widths'=>'800;800','h'=>2700,'h_bottom'=>2100)
assert(items.count { |v| v[:name].start_with?('Pano ') }==8,'Pano missing across modules and tiers')
rejected('door_style'=>'Pano khung gỗ','pano_panel_thickness'=>20)
rejected('door_style'=>'Pano khung gỗ','pano_clearance'=>8)
rejected('door_style'=>'Pano khung gỗ','pano_panel_count'=>1.5)
begin
  build('door_style'=>'Pano khung gỗ','pano_stile_width'=>300)
  raise 'Oversized pano frame accepted'
rescue VGD_Cabinet::ModelingRules::Invalid
end
puts 'PASS VGD features: zero/default tier gaps, independent handles/legacy migration, real pano grooves/capture/clearance, 5 door modes, custom thickness, modules/tiers and invalid sizes'
