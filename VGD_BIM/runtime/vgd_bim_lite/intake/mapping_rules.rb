require 'json'
module VGD
  module BIM
    module MappingRules
      DICTIONARY = 'VGD_BIM_RULES'.freeze
      TYPES = %w[definition_name instance_name tag material].freeze
      def self.read(model = Sketchup.active_model)
        rules = JSON.parse(model.get_attribute(DICTIONARY, 'json', '[]'))
        raise ArgumentError, 'Rules must be an array' unless rules.is_a?(Array)
        rules.select do |rule|
          begin
            rule.is_a?(Hash) && TYPES.include?(rule['source_type']) && !rule['source_value'].to_s.strip.empty? && Schema.normalize(rule.fetch('data')).is_a?(Hash)
          rescue StandardError
            false
          end
        end
      rescue JSON::ParserError, TypeError, ArgumentError
        BIM.log('Invalid mapping rules JSON; rules ignored')
        []
      end
      def self.save(rules, model = Sketchup.active_model, operation = true)
        raise ArgumentError, 'Rules must be an array' unless rules.is_a?(Array)
        clean = rules.map do |rule|
          raise ArgumentError, 'Invalid source type' unless TYPES.include?(rule['source_type'])
          raise ArgumentError, 'Source value required' if rule['source_value'].to_s.strip.empty?
          {'source_type' => rule['source_type'], 'source_value' => rule['source_value'].to_s.strip,
           'data' => Schema.normalize(rule.fetch('data'))}
        end
        action = lambda { model.set_attribute(DICTIONARY, 'json', JSON.generate(clean)) }
        operation ? Data.transaction(model, 'VGD Mapping Rules', &action) : action.call
        clean
      end
      def self.upsert(rule, model = Sketchup.active_model, operation = true)
        rules = read(model).reject { |r| r['source_type'] == rule['source_type'] && r['source_value'] == rule['source_value'] }
        save(rules + [rule], model, operation)
      end
      def self.export_file(path)
        File.write(path, JSON.pretty_generate(read))
      end
      def self.import_file(path)
        save(JSON.parse(File.read(path, encoding: 'UTF-8')))
      end
    end
  end
end
