# Run with SketchUp.exe -RubyStartup <absolute path> in a separate empty process.
require 'sketchup.rb'
require 'json'
require 'fileutils'
module VGDBIMNativeTest
  ROOT = File.expand_path('..', __dir__)
  OUTPUT = File.join(ROOT, 'outputs', 'native_SU22')
  FileUtils.mkdir_p(OUTPUT)
  def self.check(value, message); raise message unless value; end
  def self.near(value, expected); check((value - expected).abs < 0.001, "#{value} != #{expected}"); end
  def self.box(entities, w, d, h)
    face = entities.add_face([0,0,0], [w.mm,0,0], [w.mm,d.mm,0], [0,d.mm,0])
    face.reverse! if face.normal.z < 0
    face.pushpull(h.mm)
  end
  def self.report(data)
    File.write(File.join(OUTPUT, 'native_report.json'), JSON.pretty_generate(data))
  end
  def self.run
    model = Sketchup.active_model
    check(model.path.empty? && model.entities.count.zero?, 'Refuse user/non-empty model')
    require File.join(ROOT, 'runtime', 'vgd_bim_lite.rb')
    require File.join(ROOT, 'runtime', 'vgd_bim_lite', 'loader.rb')
    data = VGD::BIM::Data
    results = {success: false, version: Sketchup.version, ruby: RUBY_VERSION, tests: []}
    model.start_operation('VGD BIM Test Fixture', true)
    wardrobe = model.entities.add_group
    wardrobe.name = 'Tủ áo Master'
    box(wardrobe.entities, 3200, 600, 2700)
    socket = model.definitions.add('O_CAM_DOI')
    box(socket.entities, 120, 30, 80)
    sockets = 10.times.map { |i| model.entities.add_instance(socket, Geom::Transformation.translation([i*200.mm,0,0])) }
    light = model.definitions.add('DOWNLIGHT_D90')
    box(light.entities, 90, 90, 40)
    6.times { |i| model.entities.add_instance(light, Geom::Transformation.translation([i*200.mm,1000.mm,0])) }
    lavabo = model.entities.add_group
    lavabo.name = 'Lavabo Cabinet'
    box(lavabo.entities, 1000, 550, 800)
    raw = model.entities.add_face([0,3000.mm,0], [1000.mm,3000.mm,0], [1000.mm,5000.mm,0], [0,5000.mm,0])
    material = model.materials.add('SON TUONG')
    raw.material = material
    unnamed = model.entities.add_group
    box(unnamed.entities, 10, 20, 30)
    empty = model.entities.add_group
    parent_definition = model.definitions.add('NESTED_PARENT')
    child = parent_definition.entities.add_instance(socket, Geom::Transformation.scaling(2,3,4))
    parent1 = model.entities.add_instance(parent_definition, Geom::Transformation.rotation(ORIGIN,Z_AXIS,35.degrees) * Geom::Transformation.scaling(-2,1,1))
    parent2 = model.entities.add_instance(parent_definition, Geom::Transformation.translation([5000.mm,0,0]))
    scaled = model.entities.add_instance(socket, Geom::Transformation.scaling(2,3,4))
    model.commit_operation
    data.update(wardrobe, category: 'furniture', item_type: 'wardrobe', description: 'Tủ áo Master', unit: 'set', quantity_method: 'assembly', zone: 'MASTER', floor: 'L02')
    check(data.valid?(wardrobe), 'Native wardrobe invalid')
    results[:tests] << 'native VGD data / schema / validator'
    values = {category: 'electrical', item_type: 'socket', description: 'Ổ cắm đôi', unit: 'pcs', quantity_method: 'count', zone: 'MASTER'}
    geometry_before = sockets.map { |e| [e.transformation.to_a, e.name, e.layer.name, e.material, e.definition.entities.count] }
    VGD::BIM::Converter.convert(sockets.map { |e| {entity: e, locked: false} }, values)
    check(sockets.all? { |e| data.valid?(e) && data.source(e) == 'MAPPED' }, 'Batch conversion failed')
    check(geometry_before == sockets.map { |e| [e.transformation.to_a, e.name, e.layer.name, e.material, e.definition.entities.count] }, 'Conversion mutated geometry')
    model.undo
    check(sockets.none? { |e| data.has_data?(e) }, 'Batch Undo did not revert all objects')
    results[:tests] << '10-instance batch conversion / one Undo / geometry invariance'
    VGD::BIM::Converter.convert(sockets.map { |e| {entity: e, locked: false} }, values)
    data.set(sockets.first, :unit, 'm2')
    check(!data.valid?(sockets.first), 'Unit mismatch not detected')
    model.undo
    check(data.valid?(sockets.first), 'Single update Undo failed')
    records = VGD::BIM::Scanner.scan_model(model)
    occurrences = records.select { |r| r[:entity] == child }
    check(occurrences.size == 2, 'Shared nested occurrences missing or duplicated')
    dimension = VGD::BIM::Geometry.dimensions(child, occurrences.find { |r| r[:path].first == parent1 }[:transform])
    near(dimension[:width], 480); near(dimension[:depth], 90); near(dimension[:height], 320)
    dimension = VGD::BIM::Geometry.dimensions(scaled)
    near(dimension[:width], 240); near(dimension[:depth], 90); near(dimension[:height], 320)
    near(VGD::BIM::Geometry.face_area(raw), 2.0)
    results[:tests] << 'recursive occurrence scan / scaled mirrored rotated nested dimensions / metric area'
    raw_report = VGD::BIM::RawScanner.report(records, model)
    paint_report = raw_report[:materials].find { |r| r[:material] == 'SON TUONG' }
    near(paint_report[:area], 2.0)
    socket_report = raw_report[:components].find { |r| r[:definition_name] == 'O_CAM_DOI' }
    check(socket_report[:instances] == 13, 'Raw component occurrence count wrong')
    check(VGD::BIM::Detector.suggest({definition_name: 'O_CAM_DOI'})[:confidence] == 'HIGH', 'Detection failed')
    results[:tests] << 'raw material / component reports / Vietnamese detection'
    rule = {'source_type' => 'material', 'source_value' => 'SON TUONG', 'data' => {'category' => 'finish', 'item_type' => 'paint', 'description' => 'Sơn nước tường', 'unit' => 'm2', 'quantity_method' => 'area'}}
    VGD::BIM::MappingRules.upsert(rule)
    parent1.locked = true
    check(VGD::BIM::Converter.preview(VGD::BIM::Scanner.scan_model(model).select { |r| r[:entity] == child }, values)[:entities].empty?, 'Locked shared occurrence not protected')
    parent1.locked = false
    results[:tests] << 'JSON material rules / shared nested lock protection'
    panel = VGD::BIM::UI::Dialog.new('validate_model')
    validation = VGD::BIM::Validator.validate(records)
    panel.instance_variable_set(:@model, model)
    panel.instance_variable_set(:@validation, validation)
    index = validation.index { |r| r[:entity] == child && r[:path].first == parent2 }
    panel.select_entity(index)
    check(model.selection.include?(child) && model.active_path == [parent2], 'Validation did not select nested occurrence')
    model.active_path = nil
    results[:tests] << 'validation row selects correct nested occurrence and zooms'
    path = File.join(OUTPUT, 'VGD_BIM_Test_Model.skp')
    check(model.save(path), 'Fixture save failed')
    check(Sketchup.open_file(path), 'Fixture reopen failed')
    model = Sketchup.active_model
    check(VGD::BIM::Scanner.all_bim_entities.any? { |e| data.get(e, :description) == 'Tủ áo Master' }, 'Metadata did not persist')
    check(VGD::BIM::MappingRules.read.any? { |r| r['source_value'] == 'SON TUONG' }, 'Rules did not persist')
    results[:tests] << 'SKP save / reopen metadata and mapping rules persist'
    results[:success] = true
    report(results)
    # The separate fixture process stays open for inspection; user's existing process is untouched.
    VGD::BIM.open_panel('information')
  rescue Exception => error
    report({success: false, version: Sketchup.version, ruby: RUBY_VERSION, error: error.message, backtrace: error.backtrace})
    puts "[VGD BIM] Native test failed: #{error.message}"
  end
end
UI.start_timer(3, false) { VGDBIMNativeTest.run }
