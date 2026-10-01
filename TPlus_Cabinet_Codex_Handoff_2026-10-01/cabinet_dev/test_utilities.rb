def assert(ok, message); raise message unless ok; end
def dc(entity)
  entity.set_attribute('dynamic_attributes', 'lenx', 800)
  entity.set_attribute('SU_InstanceSet', 'id', 123)
end
def assert_clean(entity)
  [entity, entity.definition].each do |item|
    assert(!item.attribute_dictionaries.key?('dynamic_attributes'), 'DC dictionary remains')
    assert(!item.attribute_dictionaries.key?('SU_InstanceSet'), 'SU_InstanceSet remains')
  end
end
def fixture_cabinet
  model = Sketchup.reset
  definition = Sketchup::Definition.new('Tủ tham chiếu')
  definition.set_attribute('TPlus_Cabinet', 'is_cabinet', true)
  definition.set_attribute('TPlus_Cabinet', 'params_json', '{"w":800}')
  definition.set_attribute('TPlus_Cabinet', 'params', {'w' => 800})
  definition.set_attribute('TPlus_Cabinet', 'version', '4.3.0-beta.4')
  definition.set_attribute('OtherPlugin', 'keep', 'definition data')
  dc(definition)
  top = model.entities.add_instance(definition, Geom::Transformation.new([100, 200, 300]))
  top.name = 'Tủ A'; top.layer = Sketchup::Layer.new('T+_CABINET'); top.material = :wood
  top.set_attribute('OtherPlugin', 'keep', 'instance override'); dc(top)
  wrapper = definition.entities.add_group; wrapper.name = 'Thùng Ngăn Kéo'
  wrapper.transformation = Geom::Transformation.new([10, 0, 0]); dc(wrapper)
  panel_def = Sketchup::Definition.new('Hồi Hộc')
  dc(panel_def)
  raw = panel_def.entities.attach(Sketchup::ConstructionPoint.new)
  raw.layer = Sketchup::Layer.new('Raw dirty')
  panel = wrapper.entities.add_instance(panel_def, Geom::Transformation.new([0, 20, 0]))
  panel.material = :paint; panel.layer = Sketchup::Layer.new('T+_CANH'); dc(panel)
  panel.set_attribute('OtherPlugin', 'keep', 'panel data')
  hidden = definition.entities.add_group; hidden.name = 'Khối ẩn'; hidden.hidden = true
  # Copy of both top-level and nested definitions outside the selected scope.
  sibling = model.entities.add_instance(definition, Geom::Transformation.new([900, 0, 0]))
  sibling.name = 'Tủ B'
  external_panel = model.entities.add_instance(panel_def, Geom::Transformation.new)
  unrelated = model.entities.add_group; unrelated.name = 'Không chọn'
  [model, top, sibling, external_panel, unrelated]
end

model, top, sibling, external_panel, unrelated = fixture_cabinet
model.selection.add(top)
TPlusExplode.execute_explode
assert(model.operations == 1 && model.commits == 1 && model.aborts == 0, 'EXPLODE transaction')
result = model.selection.first
assert(model.selection.size == 1 && result.is_a?(Sketchup::Group), 'Selection must follow replacement group')
assert(!top.valid? && result.valid?, 'Top component was not replaced')
assert(result.name == 'Tủ A' && result.layer.name == 'T+_CABINET' && result.material == :wood, 'Top name/tag/material lost')
assert(result.transformation.offset == [100, 200, 300], 'Top transform lost')
%w[is_cabinet params_json params version].each do |key|
  assert(result.get_attribute('TPlus_Cabinet', key) == sibling.definition.get_attribute('TPlus_Cabinet', key), "Lost T+ parameter: #{key}")
end
assert(result.get_attribute('OtherPlugin', 'keep') == 'instance override', 'Other dictionaries or overrides lost')
assert_clean(result)
assert(result.entities.size == 1, 'Hidden group remains or wrapper not flattened')
panel = result.entities.first
assert(panel.is_a?(Sketchup::Group) && panel.name == 'Hồi Hộc', 'Independent panel group missing')
assert(panel.material == :paint && panel.layer.name == 'T+_CANH', 'Panel material/tag lost')
assert(panel.transformation.offset == [10, 20, 0], 'Nested transform lost')
assert(panel.get_attribute('OtherPlugin', 'keep') == 'panel data', 'Panel attributes lost')
assert_clean(panel)
assert(panel.entities.first.layer == model.layers[0], 'Raw geometry not Untagged')
assert(sibling.definition.entities.size == 2 && sibling.definition.entities.any?(&:hidden?), 'Copy geometry changed')
assert(sibling.definition.attribute_dictionaries.key?('dynamic_attributes'), 'Copy DC attributes changed')
assert(external_panel.definition.attribute_dictionaries.key?('dynamic_attributes'), 'Shared child definition changed')
assert(external_panel.definition.entities.first.layer.name == 'Raw dirty', 'External panel tags changed')
assert(unrelated.valid? && unrelated.name == 'Không chọn', 'Unselected object changed')
puts 'PASS EXPLODE: selected scope, flattening, independent groups, hidden removal, transforms/materials, DC removal, all T+ fields, other dictionaries, shared copies, selection, transaction'

model = Sketchup.reset
group = model.entities.add_group; group.name = 'Tủ group'; group.layer = Sketchup::Layer.new('Cha')
group.set_attribute('TPlus_Cabinet', 'is_cabinet', true); dc(group)
leaf = group.entities.add_group; leaf.name = 'Tấm'; dc(leaf)
model.selection.add(group); TPlusExplode.execute_explode
assert(model.selection.first.equal?(group), 'Existing group should stay the selected root')
assert_clean(group); assert_clean(group.entities.first)
puts 'PASS EXPLODE: existing group root and leaf retained'

model, top, sibling, external_panel, unrelated = fixture_cabinet
model.selection.add(top); TPlusUntag.clean_selected_tags
assert(top.layer.name == 'T+_CABINET', 'UNTAG changed root tag')
walker = proc do |entity|
  entity.definition.entities.each do |child|
    assert(child.layer == model.layers[0], 'Descendant tag remains')
    walker.call(child) if TPlusUtilityScope.container?(child)
  end
end
walker.call(top)
assert(top.attribute_dictionaries.key?('dynamic_attributes'), 'UNTAG removed attributes')
assert(top.definition.entities.any?(&:hidden?), 'UNTAG deleted hidden geometry')
assert(sibling.definition.entities.first.definition.entities.first.layer.name == 'T+_CANH', 'UNTAG changed another copy')
assert(external_panel.definition.entities.first.layer.name == 'Raw dirty', 'UNTAG changed external nested copy')
assert(model.operations == 1 && model.commits == 1 && model.aborts == 0, 'UNTAG transaction')
puts 'PASS UNTAG: every descendant Untagged, parent tag/DC attributes/hidden geometry retained, shared copies isolated, transaction'

[TPlusExplode.method(:execute_explode), TPlusUntag.method(:clean_selected_tags)].each do |command|
  model = Sketchup.reset
  untouched = model.entities.add_group
  command.call
  assert(model.operations == 0 && untouched.valid?, 'Empty selection mutated the model')
  model.selection.add(Sketchup::ConstructionPoint.new)
  command.call
  assert(model.operations == 0, 'Raw-only selection started an operation')
  model = Sketchup.reset
  locked = model.entities.add_group; locked.locked = true; model.selection.add(locked)
  command.call
  assert(model.aborts == 1 && model.commits == 0, 'Locked target must abort')
  assert(UI.messages.last.include?('khóa'), 'Missing locked-object explanation')
  model = Sketchup.reset
  top = model.entities.add_group; top.entities.add_group.locked = true; model.selection.add(top)
  command.call
  assert(model.aborts == 1 && model.commits == 0, 'Locked descendant must abort')
end
model = Sketchup.reset
top = model.entities.add_group
broken = top.entities.add_group; broken.name = 'FAIL_EXPLODE'; broken.entities.add_group
model.selection.add(top); TPlusExplode.execute_explode
assert(model.aborts == 1 && model.commits == 0, 'Failed explode must abort, not loop or report success')
puts 'PASS guards: no selection, raw-only selection, locked targets/descendants, failed explode abort'
