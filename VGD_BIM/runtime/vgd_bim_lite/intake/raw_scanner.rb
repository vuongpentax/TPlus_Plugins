module VGD
  module BIM
    module RawScanner
      def self.identity(entity)
        {entity_type: entity.is_a?(Sketchup::Group) ? 'Group' : 'Component',
         instance_name: entity.name.to_s, definition_name: Geometry.definition(entity).name.to_s,
         tag: entity.layer ? entity.layer.name : '', material: entity.material ? entity.material.display_name : ''}
      end
      def self.report(records, model = Sketchup.active_model)
        containers = records.select { |r| Data.supported?(r[:entity]) }
        materials = Hash.new { |h, k| h[k] = {material: k, area: 0.0, back_area: 0.0, faces: 0} }
        faces = 0
        edges = 0
        length = 0.0
        records.each do |r|
          begin
          e = r[:entity]
          next unless e.valid?
          if e.is_a?(Sketchup::Face)
            faces += 1
            material = r[:material]
            name = material ? material.display_name : '(Unpainted)'
            area = Geometry.face_area(e, r[:transform])
            materials[name][:area] += area
            materials[name][:faces] += 1
            if e.back_material
              materials[e.back_material.display_name][:back_area] += area
            end
          elsif e.is_a?(Sketchup::Edge)
            edges += 1
            length += Geometry.edge_length(e, r[:transform])
          end
          rescue StandardError => error
            BIM.log("Raw geometry inspection failed: #{error.message}")
          end
        end
        grouped = containers.group_by { |r| Geometry.definition(r[:entity]) }
        components = grouped.map do |definition, occurrences|
          raw = identity(occurrences.first[:entity])
          dimensions = occurrences.map { |r| Geometry.dimensions(r[:entity], r[:transform]) }
          raw.merge(instances: occurrences.size, dimensions: dimensions.first,
                    dimension_variants: dimensions.uniq.size,
                    tags: occurrences.map { |r| identity(r[:entity])[:tag] }.uniq,
                    names: occurrences.map { |r| r[:entity].name }.uniq)
        end
        bim = containers.count { |r| Data.has_data?(r[:entity]) }
        {summary: {groups: containers.count { |r| r[:entity].is_a?(Sketchup::Group) },
                   components: containers.count { |r| r[:entity].is_a?(Sketchup::ComponentInstance) && !r[:entity].is_a?(Sketchup::Group) },
                   definitions: grouped.size, materials: model.materials.size, tags: model.layers.size,
                   vgd_objects: bim, unclassified: containers.size - bim,
                   coverage: containers.empty? ? 0 : (100.0 * bim / containers.size).round(1),
                   raw_faces: faces, raw_edges: edges, edge_length_m: length},
         components: components, materials: materials.values, label: 'RAW QUANTITY / RAW GEOMETRY',
         area_note: 'Front area includes inherited instance material. Back area is reported separately; no BOQ deductions.'}
      end
    end
  end
end
