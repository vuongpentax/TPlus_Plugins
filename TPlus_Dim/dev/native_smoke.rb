# encoding: UTF-8
# Explicit test only: run in a dedicated NEW/fixture model. Never launch/restart SketchUp automatically.
require 'json'
task_root = File.expand_path('..', __dir__)
report_path = File.join(task_root, 'outputs', 'NATIVE_SU2022.json')
File.write(report_path, JSON.pretty_generate({status: 'STARTING', version: Sketchup.version, ruby: RUBY_VERSION}))
UI.start_timer(2.0, false) do
  checks = []
  begin
    raise 'Chỉ kiểm tra trên SketchUp 2022.' unless Sketchup.version.to_i == 22
    model = Sketchup.active_model
    fixture_input = File.join(task_root, 'outputs', 'native_fixture_input.skp')
    is_fixture = File.expand_path(model.path).tr('\\', '/').downcase == fixture_input.tr('\\', '/').downcase
    raise 'Từ chối thay đổi file người dùng đang mở.' unless (model.path.empty? || is_fixture) && !model.modified?
    load File.join(task_root, 'runtime', 'TPlus_Dim', 'main.rb') unless defined?(TPlus::Dim::Engine)
    engine = TPlus::Dim::Engine
    config = TPlus::Dim::DEFAULTS.dup
    assert_check = lambda do |name, &block|
      raise "FAIL: #{name}" unless block.call
      checks << name
    end
    model.start_operation('T+ Dim · Tạo model kiểm tra riêng', true)
    direct = model.entities.add_dimension_linear([0,0,0], [800.mm,0,0], [0,80.mm,0])
    outside = model.entities.add_dimension_linear([0,-300.mm,0], [600.mm,-300.mm,0], [0,-80.mm,0])
    definition = model.definitions.add('TPlusDim_Test_Component')
    inner = definition.entities.add_dimension_linear([0,0,0], [400.mm,0,0], [0,50.mm,0])
    inner.text = 'OS'
    nested_definition = model.definitions.add('TPlusDim_Test_Parent')
    nested_definition.entities.add_instance(definition, Geom::Transformation.scaling(2.0))
    selected = model.entities.add_instance(nested_definition, Geom::Transformation.translation([0,400.mm,0]))
    unselected = model.entities.add_instance(nested_definition, Geom::Transformation.translation([0,900.mm,0]))
    locked = model.entities.add_group
    locked.entities.add_dimension_linear([0,0,0], [200.mm,0,0], [0,20.mm,0])
    locked.locked = true
    model.commit_operation
    model.selection.clear
    model.selection.add([direct, selected, locked])
    context = engine.context(model, config)
    assert_check.call('Quét sâu đúng vùng chọn; bỏ qua nhóm khóa') { context['dimensions'] == 2 && context['locked'] == 1 }
    config.merge!('alignment'=>'aligned', 'position'=>'above', 'change_offset'=>true, 'offset_mm'=>100.0, 'reset_text'=>true)
    before_outside = outside.material
    result = TPlus::Dim::ProfileService.for_model(model).with_paused { engine.apply(model, config, engine.token(model, config)) }
    updated = selected.definition.entities.grep(Sketchup::ComponentInstance).first.definition.entities.grep(Sketchup::DimensionLinear).first
    assert_check.call('Native setter màu, chấm dot và hướng chữ') { direct.material && direct.arrow_type == Sketchup::Dimension::ARROW_DOT && direct.has_aligned_text? }
    display = TPlus::Dim::CustomDim.partner(direct)
    assert_check.call('Tạo dim T+ từ font đóng gói và giữ nguồn ẩn') { display && direct.hidden? && display.entities.length > 0 && display.layer.name == 'T+_DIM' }
    assert_check.call('Lưu quy chuẩn model') { TPlus::Dim::Profile.read(model)['font'] == 'UTM Avo' }
    assert_check.call('Dim ngoài vùng chọn giữ nguyên') { outside.material == before_outside && inner.material.nil? && inner.text == 'OS' }
    assert_check.call('Component lồng nhau được tách riêng') { result[:unique] == 2 && selected.definition != unselected.definition }
    world_vector = updated.offset_vector.transform(selected.transformation * selected.definition.entities.grep(Sketchup::ComponentInstance).first.transformation)
    assert_check.call('Khoảng cách native trong component scale = 100 mm') { (world_vector.length - 100.mm).abs < 0.001.mm }
    assert_check.call('Vị trí chữ native') { updated.aligned_text_position == Sketchup::DimensionLinear::ALIGNED_TEXT_ABOVE }
    assert_check.call('Xóa nội dung nhập đè') { updated.text != 'OS' }
    # Actual kernel undo must restore definition identity and override text.
    Sketchup.undo
    assert_check.call('Native Undo khôi phục component và dim') { selected.definition == unselected.definition && inner.text == 'OS' && direct.material.nil? }
    model.selection.clear
    config['save_profile'] = false
    begin
      engine.apply(model, config, engine.token(model, config))
      raise 'Vùng chọn trống vẫn được áp dụng.'
    rescue ArgumentError
      checks << 'Vùng chọn trống bị từ chối'
    end
    model.selection.add([direct, selected])
    model.active_view.zoom_extents
    File.write(report_path, JSON.pretty_generate({status:'PASS',version:Sketchup.version,ruby:RUBY_VERSION,checks:checks,notes:'Model kiểm tra riêng, không chỉnh các file người dùng đã mở.'}))
    TPlus::Dim.show_dialog
  rescue StandardError => error
    File.write(report_path, JSON.pretty_generate({status:'FAIL',version:Sketchup.version,ruby:RUBY_VERSION,checks:checks,error:error.message,backtrace:error.backtrace}))
    puts "[T+ Dim native test] #{error.message}"
  end
end
