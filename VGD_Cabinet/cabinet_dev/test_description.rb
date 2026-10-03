def description_packet(changes={})
  packet=VGD_Cabinet::DescriptionImport.example
  packet['parameters']=packet['parameters'].merge(changes)
  packet
end
def description_rejected(packet)
  VGD_Cabinet::DescriptionImport.parse(packet.is_a?(String) ? packet : JSON.generate(packet))
  raise 'Invalid description accepted'
rescue VGD_Cabinet::ModelingRules::Invalid
  true
end
examples=[{}, {'opt_door'=>'Không Cánh','shelf_count'=>3},
  {'h'=>810,'shadow_gap_h'=>0,'shelf_count'=>0,'opt_door'=>'Không Cánh','opt_drawer'=>'Lộ','is_full_drawer'=>true,'drawer_count'=>3},
  {'door_style'=>'Kính khung kim loại'}, {'door_style'=>'Pano khung gỗ','pano_panel_count'=>2},
  {'w'=>1500,'module_mode'=>'Độc lập','module_widths'=>'700;800'},
  {'h'=>2700,'is_overheight'=>true,'h_bottom'=>2100},
  {'w'=>1500,'div_count'=>2,'auto_door_count'=>true},
  {'opt_top'=>'Đỉnh Phủ Hồi','shadow_gap_h'=>20}]
$description_cases=examples.map do |changes|
  packet=description_packet(changes)
  parsed=VGD_Cabinet::DescriptionImport.parse(JSON.generate(packet))
  entities=Sketchup::Entities.new
  VGD_Cabinet::Modeling.draw(entities,parsed['parameters'])
  assert(panels(entities).all? { |part| part[:size].all? { |n| n.finite? && n>0 } },'Imported invalid geometry')
  {'packet'=>packet,'result'=>parsed}
end
p=$description_cases.first['result']['parameters']
assert(p['auto_door_count']==false && p['handle_split_v1'] && !p['drawer_bevel'],'Explicit door count/migration leak')
bevel=VGD_Cabinet::DescriptionImport.parse(JSON.generate(description_packet('front_bevel'=>true)))['parameters']
assert(bevel['front_bevel'] && !bevel['drawer_bevel'],'New import migrated drawer handle')
packet=description_packet('div_count'=>2)
assert(!VGD_Cabinet::DescriptionImport.parse(JSON.generate(packet))['parameters']['auto_divider_wide'],'Explicit divider count lost')
packet=description_packet
packet['units']='cm'; description_rejected(packet)
packet=description_packet;packet['schema_version']=2;description_rejected(packet)
packet=description_packet;packet['parameters'].delete('d');description_rejected(packet)
%w[__target_pid modules typo].each { |k| description_rejected(description_packet(k=>1)) }
description_rejected(description_packet('w'=>'800'))
description_rejected(description_packet('auto_door_count'=>'false'))
description_rejected(description_packet('opt_top'=>'bogus'))
description_rejected(description_packet('drawer_count'=>1.5))
description_rejected(description_packet('w'=>1500,'module_mode'=>'Độc lập','module_widths'=>'800;800'))
description_rejected(description_packet('door_style'=>'Pano khung gỗ','pano_panel_thickness'=>25))
description_rejected(description_packet('handle_split_v1'=>false))
description_rejected('{"format":"a","format":"b"}')
description_rejected('x'*200_001)
description_rejected('Không phải JSON')
packet=description_packet;packet['estimated_fields']=['typo'];description_rejected(packet)
packet=description_packet;packet['assumptions']=[{}];description_rejected(packet)
packet=description_packet;packet['unsupported_features']=['Mỗi module một kiểu cánh']
assert(!VGD_Cabinet::DescriptionImport.parse(JSON.generate(packet))['can_apply'],'Unsupported silently discarded')
partial_packet=JSON.parse($partial_description_json)
partial_result=VGD_Cabinet::DescriptionImport.parse($partial_description_json)
assert(partial_result['can_apply_partial'] && !partial_result['can_apply'],'Partial preview flags wrong')
def partial_rejected(text, **args)
  VGD_Cabinet::DescriptionImport.for_apply(text,**args)
  raise 'Partial import without valid approval accepted'
rescue VGD_Cabinet::ModelingRules::Invalid
  true
end
partial_rejected($partial_description_json)
partial_rejected($partial_description_json,allow_partial:true)
partial_rejected($partial_description_json,allow_partial:'true',acknowledged_features:partial_packet['unsupported_features'])
partial_rejected($partial_description_json,allow_partial:true,acknowledged_features:[])
partial_rejected($partial_description_json,allow_partial:true,acknowledged_features:partial_packet['unsupported_features'].reverse)
approved=VGD_Cabinet::DescriptionImport.for_apply($partial_description_json,allow_partial:true,acknowledged_features:partial_packet['unsupported_features'])
assert(approved['parameters']['w']==2200 && approved['parameters']['h_top']==580,'Partial silently changed width/tier rule')
bad=Marshal.load(Marshal.dump(partial_packet));bad['parameters']['d']=10
partial_rejected(JSON.generate(bad),allow_partial:true,acknowledged_features:bad['unsupported_features'])
bad=Marshal.load(Marshal.dump(partial_packet));bad['parameters']['modules']=[]
partial_rejected(JSON.generate(bad),allow_partial:true,acknowledged_features:bad['unsupported_features'])
entities=Sketchup::Entities.new
VGD_Cabinet::Modeling.draw(entities,approved['parameters'])
assert(panels(entities).all? { |part| part[:size].all? { |n| n.finite? && n>0 } },'Partial fixture invalid geometry')
$description_cases << {'packet'=>partial_packet,'result'=>approved}
raw=JSON.generate(description_packet)
assert(VGD_Cabinet::DescriptionImport.parse("```json\n#{raw}\n```")['can_apply'],'Fenced JSON rejected')
class DescriptionDialogFixture
  attr_reader :scripts
  def initialize;@scripts=[];end
  def visible?;true;end
  def execute_script(script);@scripts<<script;end
end
dialog=DescriptionDialogFixture.new
VGD_Cabinet.dialog=dialog
before=Sketchup.active_model.operations
VGD_Cabinet.preview_description({'text'=>raw,'request_id'=>7})
assert(!VGD_Cabinet.instance_variable_get(:@description_draft),'Preview created draft')
VGD_Cabinet.apply_description({'text'=>raw+' ','request_id'=>7})
assert(!VGD_Cabinet.instance_variable_get(:@description_draft),'Stale input applied')
VGD_Cabinet.apply_description({'text'=>raw,'request_id'=>7})
assert(VGD_Cabinet.instance_variable_get(:@description_draft),'Draft not active')
count=dialog.scripts.size
VGD_Cabinet.sync_current_selection
assert(dialog.scripts.size==count,'Selection overwrote imported draft')
VGD_Cabinet.update_selected_cabinet({})
assert(dialog.scripts.last.include?('Đang tạo tủ từ mô tả'),'Draft did not block update')
assert(Sketchup.active_model.operations==before,'Import mutated model')
VGD_Cabinet.leave_description_draft
assert(!VGD_Cabinet.instance_variable_get(:@description_draft),'Exit did not release draft')
assert(dialog.scripts.any? { |script| script=='leaveDescriptionDraft();' },'Exit not sent to UI')
VGD_Cabinet.preview_description({'text'=>$partial_description_json,'request_id'=>8})
VGD_Cabinet.apply_description({'text'=>$partial_description_json,'request_id'=>8,'allow_partial'=>true})
assert(!VGD_Cabinet.instance_variable_get(:@description_draft),'Callback allowed missing acknowledgment')
VGD_Cabinet.apply_description({'text'=>$partial_description_json,'request_id'=>9,'allow_partial'=>true,'acknowledged_features'=>partial_packet['unsupported_features']})
assert(!VGD_Cabinet.instance_variable_get(:@description_draft),'Callback allowed stale partial preview')
VGD_Cabinet.apply_description({'text'=>$partial_description_json,'request_id'=>8,'allow_partial'=>true,'acknowledged_features'=>partial_packet['unsupported_features']})
assert(VGD_Cabinet.instance_variable_get(:@description_draft),'Approved partial callback failed')
assert(dialog.scripts.last.include?('Khoang kệ mở bên trái'),'Omissions lost in Ruby/UI callback')
assert(Sketchup.active_model.operations==before,'Partial import mutated model')
VGD_Cabinet.leave_description_draft
VGD_Cabinet.dialog=nil
puts 'PASS description: 10 geometry configurations including exact user JSON, partial import requires exact explicit acknowledgment, missing/stale/reordered approval rejected, invalid geometry/unknown params still blocked, strict validation and draft isolation; no model operation'
