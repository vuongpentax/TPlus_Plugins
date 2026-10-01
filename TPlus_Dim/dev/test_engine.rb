def assert(value,message); raise message unless value; end
def rejects(message)
  begin; yield; rescue ArgumentError; return; end
  raise message
end
def add_dim(model)
  dim=Sketchup::DimensionLinear.new; model.entities << dim; dim
end
def apply_test(model,overrides={})
  config=TPlus::Dim::Engine.validate(TPlus::Dim::DEFAULTS.merge(overrides))
  TPlus::Dim::Engine.apply(model,config,TPlus::Dim::Engine.token(model,config))
end
def run_engine_tests
  dim_module=TPlus::Dim; engine=dim_module::Engine; custom=dim_module::CustomDim
  assert(!dim_module::FontBook.layout('Ø800 · 90°',dim_module::DEFAULTS).empty?,'Bundled drawing symbols unavailable')
  model=Sketchup::FakeModel.new
  rejects('Empty targets without profile accepted') { apply_test(model,'save_profile'=>false) }
  apply_test(model)
  assert(model.layers.keys.sort==['T+_DIM','T+_TEXT'] && dim_module::Profile.read(model)['auto_new'],'File profile not persisted')
  dim=add_dim(model); outsider=add_dim(model); model.selection << dim
  config=dim_module::DEFAULTS.dup; stale=engine.token(model,config)
  rejects('Scope toggle reused token') { engine.apply(model,config.merge('include_dim'=>false),stale) }
  result=apply_test(model)
  view=custom.partner(dim)
  assert(view && dim.hidden? && !view.hidden? && result[:fonts]==1,'Custom conversion failed')
  assert(dim.arrow_type==2 && view.layer=='T+_DIM' && outsider.material.nil?,'Default dot/tag/selected-only failed')
  assert(model.selection==[view],'Conversion did not keep visible dim selected')
  assert([dim.material.color.red,dim.material.color.green,dim.material.color.blue]==[0,0,255],'Default blue failed')
  model.selection.clear; model.selection << view
  assert(engine.context(model,config)['dimensions']==1,'Custom view unrecognized')
  apply_test(model,'font_bold'=>true)
  assert(JSON.parse(view.get_attribute(custom::DICT,'config'))['font_bold'],'Custom font style update failed')
  assert(model.entities.select { |e| custom.view?(e) }.length==1,'Repeated Apply duplicated visual')
  copy=view.copy_to(model.entities); copy.definition.instances << copy; model.entities << copy
  assert(custom.partner(copy).nil?,'Visual-only copy linked to original source')
  model.selection.clear; model.selection << copy
  rejects('Visual-only copy may mutate original source') { apply_test(model) }
  token=engine.context(model,config)['delete_token']; engine.delete(model,config,token,'dimensions')
  assert(dim.valid? && view.valid?,'Deleting visual-only copy erased original pair')
  model.selection.clear; model.selection << view
  before=view.get_attribute(custom::DICT,'signature')
  dim.end_point=Geom::Point3d.new(1000.mm,0,0)
  updates=custom.updates(model); assert(updates.any? { |a| a[0]==:render },'Measurement change undetected')
  custom.refresh(model,updates)
  assert(before!=view.get_attribute(custom::DICT,'signature') && custom.updates(model).empty?,'Measurement refresh unstable')
  old=dim.material; apply_test(model,'dim_color'=>'#CC3300')
  assert([old.color.red,old.color.green,old.color.blue]==[0,0,255],'Shared material recolored')
  apply_test(model,'custom_dim'=>false)
  assert(!view.valid? && !dim.hidden? && model.selection.include?(dim),'Cannot restore native dim')
  apply_test(model); view=custom.partner(dim)
  token=engine.context(model,config)['delete_token']; result=engine.delete(model,config,token,'dimensions')
  assert(result[:dimensions]==1 && !view.valid? && !dim.valid? && outsider.valid?,'Paired delete failed')

  model=Sketchup::FakeModel.new; original=Sketchup::DimensionLinear.new
  nested_def=Sketchup::Definition.new(model,[original]); model.definitions << nested_def
  nested=Sketchup::ComponentInstance.new(nested_def,2)
  parent_def=Sketchup::Definition.new(model,[nested]); model.definitions << parent_def
  selected=Sketchup::ComponentInstance.new(parent_def); unselected=Sketchup::ComponentInstance.new(parent_def)
  model.entities << selected; model.entities << unselected; model.selection << selected
  result=apply_test(model,'change_offset'=>true,'offset_mm'=>100,'reset_text'=>true)
  updated=selected.definition.entities[0].definition.entities.find { |e| e.is_a?(Sketchup::DimensionLinear) }
  assert(result[:unique]==2 && original.material.nil? && !original.hidden? && unselected.definition==parent_def,'Nested/shared conversion leaked')
  assert((updated.offset_vector.length*2-100.mm).abs<1e-8,'Scaled offset failed')
  selected.locked=true
  rejects('Locked selection mutable') { apply_test(model,'save_profile'=>false) }
  selected.locked=false
  model.active_path=[unselected]; another=Sketchup::ComponentInstance.new(parent_def)
  rejects('Shared active edit path accepted') { apply_test(model) }
  model.active_path=nil
  edge=Sketchup::Edge.new([Geom::Point3d.new(0,0,0),Geom::Point3d.new(1,0,0)])
  child=selected.definition.entities[0]; child.definition.entities << edge; updated.hidden=true
  token=engine.context(model,config)['delete_token']
  extra=Sketchup::Text.new; child.definition.entities << extra
  rejects('Deep content changed but stale delete token accepted') { engine.delete(model,config,token,'both') }
  token=engine.context(model,config)['delete_token']
  result=engine.delete(model,config.merge('deep'=>false),token,'both')
  assert(result[:dimensions]==1 && result[:texts]==1 && edge.valid? && original.valid?,'Deep delete erased geometry/unselected source')

  model=Sketchup::FakeModel.new; text=Sketchup::Text.new; screen=Sketchup::Text.new; screen.leader=false
  model.entities << text; model.entities << screen; model.selection.concat([text,screen])
  result=apply_test(model,'include_dim'=>false)
  assert(result[:texts]==2 && result[:fonts]==1 && result[:fonts_skipped]==1,'Leader/screen text capability incorrect')
  assert(custom.partner(text).layer=='T+_TEXT' && screen.layer=='T+_TEXT' && screen.arrow_type==2,'Text dot/tag failed')
  apply_test(model,'change_units'=>true,'precision'=>2,'show_unit'=>false)
  assert(model.options['UnitsOptions']=={'LengthUnit'=>2,'LengthFormat'=>0,'LengthPrecision'=>2,'SuppressUnitsDisplay'=>true},'Unit profile failed')

  model=Sketchup::FakeModel.new; apply_test(model)
  service=dim_module::ProfileService.for_model(model); added=add_dim(model)
  service.added(model.entities,added)
  assert(!added.hidden? && custom.partner(added).nil?,'Mutation inside onElementAdded')
  service.committed; UI.drain
  assert(added.hidden? && custom.partner(added) && model.operation_flags.last[3]==true,'Future manual dim not styled transparently')
  new_dim=add_dim(model); service.added(model.entities,new_dim); service.committed; service.history_changed; UI.drain
  assert(!new_dim.hidden?,'Undo did not clear pending work')
  dim_module::Profile.write(model,config.merge('auto_new'=>false)); service.reconfigure
  new_dim=add_dim(model); service.added(model.entities,new_dim); service.committed; UI.drain
  assert(!new_dim.hidden?,'Disabled auto mode converted new dim')
  service.dispose

  model=Sketchup::FakeModel.new; dim=add_dim(model); model.selection << dim
  dim.define_singleton_method(:arrow_type=) { |_| raise 'native setter failed' }
  begin; apply_test(model); rescue RuntimeError => e; raise unless e.message=='native setter failed'; end
  assert(model.aborts==1,'Explicit apply failure did not abort')
  rejects('Bad size accepted') { engine.validate(config.merge('size_pt'=>0)) }
  rejects('Unknown font accepted') { engine.validate(config.merge('font'=>'Missing')) }
  rejects('Bad precision accepted') { engine.validate(config.merge('precision'=>1.5)) }
  model=Sketchup::FakeModel.new; text=Sketchup::Text.new; text.text="\u{1F600}"; model.entities << text
  begin; custom.convert(text,config,nil,model); rescue ArgumentError; end
  assert(!text.hidden? && !custom.source?(text) && model.entities.none? { |e| custom.view?(e) },'Failed glyph left a broken source/display pair')
  puts 'PASS: custom conversion/reapply, glyph geometry, measurement refresh, blue/dot/tags, shared/nested isolation, deep paired deletion, model profile, future draw/Undo queue, units, rollback and validation'
end
