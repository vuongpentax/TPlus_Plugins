module VGD
  module BIM
    module Data
      def self.supported?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end
      def self.has_data?(entity)
        supported?(entity) && !!entity.attribute_dictionary(Schema::DICTIONARY, false)
      end
      def self.read(entity)
        return {} unless has_data?(entity)
        Schema::FIELDS.each_with_object({}) { |key, h| h[key] = entity.get_attribute(Schema::DICTIONARY, key.to_s, Schema::DEFAULTS[key]) }
      end
      def self.get(entity, key)
        read(entity)[key.to_sym]
      end
      def self.transaction(model, name = 'VGD BIM Update')
        model.start_operation(name, true)
        begin
          result = yield
          model.commit_operation
          result
        rescue StandardError
          model.abort_operation
          raise
        end
      end
      def self.write(entity, values, source)
        raise ArgumentError, 'Unsupported entity' unless supported?(entity) && entity.valid?
        raise ArgumentError, 'Locked entity' if entity.locked?
        values = Schema.normalize(values)
        values = Schema::DEFAULTS.merge(values) unless has_data?(entity)
        values.each { |key, value| entity.set_attribute(Schema::DICTIONARY, key.to_s, value) }
        entity.set_attribute(Schema::DICTIONARY, '_source', source)
        read(entity)
      end
      def self.update(entity, values)
        transaction(entity.model) { write(entity, values, source(entity) == 'RAW' ? 'MANUAL' : source(entity)) }
      end
      def self.set(entity, key, value)
        update(entity, key => value)
      end
      def self.clear(entity)
        transaction(entity.model, 'VGD BIM Clear') { erase(entity) }
      end
      def self.erase(entity)
        raise ArgumentError, 'Locked entity' if entity.locked?
        entity.delete_attribute(Schema::DICTIONARY)
      end
      def self.source(entity)
        has_data?(entity) ? entity.get_attribute(Schema::DICTIONARY, '_source', 'VGD') : 'RAW'
      end
      def self.valid?(entity)
        has_data?(entity) && Validator.inspect_entity(entity).none? { |issue| issue[:severity] == 'ERROR' }
      end
    end
  end
end
