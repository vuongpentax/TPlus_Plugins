def assert(value, message); raise message unless value; end
def rejects(message)
  begin; yield; rescue ArgumentError; return; end
  raise message
end
model = Sketchup.active_model
entity = Sketchup::Group.new(model)
data = VGD::BIM::Data
assert(!data.has_data?(entity), 'Raw entity classified accidentally')
assert(VGD::BIM::Validator.inspect_entity(entity).first[:message] == 'UNCLASSIFIED', 'Raw should not be error')
data.update(entity, category: 'furniture', item_type: 'wardrobe', description: 'Tủ áo', unit: 'set', quantity_method: 'assembly', zone: 'MASTER')
assert(data.valid?(entity), 'Native metadata invalid')
assert(data.get(entity, :include_boq) == true && data.get(entity, :schema_version) == 1, 'Defaults missing')
data.set(entity, :zone, 'LIVING')
assert(data.get(entity, :description) == 'Tủ áo', 'Partial update overwrote description')
rejects('Non-boolean accepted') { data.set(entity, :include_boq, 'false') }
assert(model.aborts == 1, 'Failed write did not abort operation')
rejects('Invalid category accepted') { VGD::BIM::Schema.normalize(category: 'cabinet') }
rejects('Unknown field accepted') { VGD::BIM::Schema.normalize(price: '100') }
data.update(entity, unit: 'm2', quantity_method: 'count')
assert(!data.valid?(entity), 'Count/m2 mismatch not detected')
data.clear(entity)
assert(!data.has_data?(entity), 'Clear failed')
suggestion = VGD::BIM::Detector.suggest({definition_name: 'O_CAM_DOI'})
assert(suggestion[:data][:item_type] == 'socket' && suggestion[:confidence] == 'HIGH', 'Vietnamese keyword detection failed')
assert(VGD::BIM::Detector.suggest({definition_name: 'TU_AO'})[:data][:item_type] == 'wardrobe', 'Wardrobe detection failed')
assert(VGD::BIM::Detector.suggest({definition_name: 'lightweight'})[:data].empty?, 'Substring false positive')
rule = {'source_type' => 'definition_name', 'source_value' => 'O_CAM_DOI', 'data' => {'category' => 'other', 'item_type' => 'custom'}}
VGD::BIM::MappingRules.upsert(rule)
assert(VGD::BIM::Detector.suggest({definition_name: 'O_CAM_DOI'})[:data][:item_type] == 'custom', 'Rule did not outrank keyword')
data.update(entity, category: 'furniture', item_type: 'custom_native')
assert(VGD::BIM::Detector.suggest({definition_name: 'O_CAM_DOI'}, entity)[:data][:item_type] == 'custom_native', 'Heuristic overrode native')
sockets = 10.times.map { Sketchup::ComponentInstance.new(model) }
records = sockets.map { |e| {entity: e, locked: false} }
records << records.first
records << {entity: entity, locked: false}
values = {category: 'electrical', item_type: 'socket', description: 'Ổ cắm đôi', unit: 'pcs', quantity_method: 'count'}
before = model.commits
plan = VGD::BIM::Converter.convert(records, values)
assert(plan[:entities].size == 10 && model.commits == before + 1, 'Batch must commit once and deduplicate')
assert(sockets.all? { |e| data.source(e) == 'MAPPED' && data.valid?(e) }, 'Mapped metadata invalid')
assert(data.get(entity, :item_type) == 'custom_native', 'Conversion overwrote native')
raw = Sketchup::Group.new(model)
assert(VGD::BIM::Converter.preview([{entity: raw, locked: false}, {entity: raw, locked: true}], values)[:entities].empty?, 'Shared locked parent not protected')
puts 'PASS: schema, defaults, partial edits, validation, source priority, rules, batch conversion, lock protection, operation rollback'
