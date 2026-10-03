model = Sketchup.active_model
model.entities = Sketchup::Entities.new
model.materials = []
model.layers = []
leaf_entities = Sketchup::Entities.new
leaf = Sketchup::Definition.new('O_CAM_DOI', Geom::Box.new(120.0/25.4,30.0/25.4,80.0/25.4),leaf_entities)
leaf_entities.parent = leaf
child = Sketchup::ComponentInstance.new(model, leaf)
child.transformation = Geom::Transformation.scaling(2,3,4)
parent_entities = Sketchup::Entities.new([child])
parent_definition = Sketchup::Definition.new('Parent',Geom::Box.new(1,1,1),parent_entities)
parent_entities.parent = parent_definition
first = Sketchup::ComponentInstance.new(model,parent_definition)
first.transformation = Geom::Transformation.rotation_z(35)*Geom::Transformation.scaling(-2,1,1)
second = Sketchup::ComponentInstance.new(model,parent_definition)
model.entities.concat([first,second])
face=Sketchup::Face.new
face.material=Struct.new(:display_name).new('SON TUONG')
model.entities << face
model.entities << Sketchup::Edge.new
records=VGD::BIM::Scanner.scan_model(model)
occurrences=records.select { |r| r[:entity]==child }
assert(occurrences.size==2,'Shared child occurrence count incorrect')
dimensions=VGD::BIM::Geometry.dimensions(child,occurrences.first[:transform])
assert((dimensions[:width]-480).abs<1e-6 && (dimensions[:depth]-90).abs<1e-6 && (dimensions[:height]-320).abs<1e-6,'Mirrored nested rotated dimensions incorrect')
assert((VGD::BIM::Geometry.face_area(face,Geom::Transformation.scaling(-2,3,1))-12).abs<1e-6,'Nonuniform mirrored face area wrong')
assert((VGD::BIM::Geometry.edge_length(model.entities.last,Geom::Transformation.scaling(2,3,1))-2).abs<1e-6,'Scaled edge length wrong')
raw=VGD::BIM::RawScanner.report(records,model)
assert(raw[:components].find { |r| r[:definition_name]=='O_CAM_DOI' }[:instances]==2,'Definition report deduplicated physical occurrences')
assert((raw[:materials].first[:area]-2).abs<1e-6,'Raw area wrong')
assert(VGD::BIM::Scanner.all_entities.count { |e| e==child }==1,'Entity API did not deduplicate shared objects')
# Thousands of levels must not depend on the Ruby call stack.
deep=child
2000.times do |i|
  entities=Sketchup::Entities.new([deep]);definition=Sketchup::Definition.new("Level#{i}",Geom::Box.new(1,1,1),entities);entities.parent=definition
  deep=Sketchup::ComponentInstance.new(model,definition)
end
model.entities=Sketchup::Entities.new([deep])
assert(VGD::BIM::Scanner.scan_model(model).size==2001,'Deep nesting scan failed')
# A malformed recursive definition terminates instead of recursing forever.
recursive_entities=Sketchup::Entities.new
recursive=Sketchup::Definition.new('Cycle',Geom::Box.new(1,1,1),recursive_entities)
cycle=Sketchup::ComponentInstance.new(model,recursive);recursive_entities.parent=recursive;recursive_entities << cycle
model.entities=Sketchup::Entities.new([cycle])
assert(VGD::BIM::Scanner.scan_model(model).size==2,'Cycle guard failed')
puts 'PASS: simulated nested affine transforms, mirrored area, edge length, occurrence reports, 2000-level nesting, recursive definition guard'
