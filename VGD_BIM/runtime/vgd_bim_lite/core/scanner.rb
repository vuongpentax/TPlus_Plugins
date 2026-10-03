module VGD
  module BIM
    module Scanner
      # Each record is an occurrence path, not a global definition visited flag.
      # Shared nested entities are measured once per physical parent occurrence.
      def self.walk(entities, transform = Geom::Transformation.new, path = [], ancestors = [], material = nil, locked = false, &block)
        stack = [[entities.to_enum, transform, path, ancestors, material, locked]]
        until stack.empty?
          iterator, transform, path, ancestors, material, locked = stack.last
          begin
            entity = iterator.next
          rescue StopIteration
            stack.pop
            next
          end
          begin
            next unless entity.valid?
            container = Data.supported?(entity)
            world = container ? transform * entity.transformation : transform
            current_path = path + [entity]
            inherited = entity.respond_to?(:material) && entity.material ? entity.material : material
            current_locked = locked || (container && entity.locked?)
            block.call(entity: entity, transform: world, path: current_path, material: inherited, locked: current_locked)
            next unless container
            definition = Geometry.definition(entity)
            next if ancestors.include?(definition)
            stack << [definition.entities.to_enum, world, current_path, ancestors + [definition], inherited, current_locked]
          rescue StandardError => error
            BIM.log("Failed to inspect entity: #{error.message}")
          end
        end
      end
      def self.scan_model(model = Sketchup.active_model)
        records = []
        walk(model.entities) { |record| records << record }
        records
      end
      def self.scan_selection(model = Sketchup.active_model)
        records = []
        path = model.active_path || []
        inherited = path.reverse.find { |e| e.material }
        walk(model.selection.to_a, model.edit_transform, path, [], inherited && inherited.material, path.any?(&:locked?)) { |record| records << record }
        records
      end
      def self.all_entities; scan_model.map { |r| r[:entity] }.select { |e| Data.supported?(e) }.uniq; end
      def self.all_bim_entities; all_entities.select { |e| Data.has_data?(e) }; end
      def self.by_category(value); all_bim_entities.select { |e| Data.get(e, :category) == value }; end
      def self.by_item_type(value); all_bim_entities.select { |e| Data.get(e, :item_type) == value }; end
      def self.by_zone(value); all_bim_entities.select { |e| Data.get(e, :zone) == value }; end
      def self.by_floor(value); all_bim_entities.select { |e| Data.get(e, :floor) == value }; end
    end
  end
end
