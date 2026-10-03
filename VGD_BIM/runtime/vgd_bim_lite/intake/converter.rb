module VGD
  module BIM
    module Converter
      def self.preview(records, values)
        values = Schema.normalize(values)
        blocked = records.select { |r| r[:locked] }.map { |r| r[:entity] }
        targets = records.select { |r| Data.supported?(r[:entity]) && r[:entity].valid? && !blocked.include?(r[:entity]) && !r[:entity].locked? && !Data.has_data?(r[:entity]) }
        {entities: targets.map { |r| r[:entity] }.uniq, occurrences: targets.size, values: values,
         skipped: records.size - targets.size}
      end
      def self.convert(records, values, rule = nil, model = Sketchup.active_model)
        plan = preview(records, values)
        Data.transaction(model, 'VGD BIM Convert') do
          plan[:entities].each { |entity| Data.write(entity, plan[:values], 'MAPPED') }
          MappingRules.upsert(rule, model, false) if rule
        end
        plan
      end
    end
  end
end
