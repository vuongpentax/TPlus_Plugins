module VGD
  module BIM
    module Mapping
      def self.rows(records)
        rules = MappingRules.read
        containers = records.select { |r| Data.supported?(r[:entity]) }
        containers.group_by { |r| Geometry.definition(r[:entity]) }.map do |definition, occurrences|
          blocked = occurrences.select { |r| r[:locked] }.map { |r| r[:entity] }
          eligible = occurrences.reject { |r| Data.has_data?(r[:entity]) || blocked.include?(r[:entity]) }
          sample = eligible.first || occurrences.first
          raw = RawScanner.identity(sample[:entity])
          suggestion = Detector.suggest(raw, sample[:entity], rules)
          {source_type: 'definition_name', source_value: definition.name.to_s,
           instances: occurrences.size, eligible: eligible.map { |r| r[:entity] }.uniq.size,
           protected: occurrences.size - eligible.size, occurrences: occurrences,
           suggestion: suggestion, raw: raw, kind: 'object',
           status: eligible.empty? ? 'PROTECTED' : suggestion[:confidence] == 'HIGH' ? 'READY' : 'REVIEW'}
        end
      end
      def self.material_rows(report)
        report[:materials].reject { |r| r[:material] == '(Unpainted)' }.map do |material|
          {source_type: 'material', source_value: material[:material], kind: 'material', instances: material[:faces], eligible: 0,
           protected: 0, occurrences: [], raw: material,
           suggestion: Detector.suggest({material: material[:material]}), status: 'REVIEW'}
        end
      end
    end
  end
end
