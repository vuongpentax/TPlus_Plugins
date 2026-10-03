module VGD
  module BIM
    module Validator
      def self.inspect_entity(entity)
        return [{severity: 'INFO', message: 'Entity no longer exists'}] unless entity.valid?
        return [{severity: 'INFO', message: 'UNCLASSIFIED'}] unless Data.has_data?(entity)
        data = Data.read(entity)
        issues = []
        add = lambda { |level, text| issues << {severity: level, message: text} }
        add.call('ERROR', 'Unsupported schema version') unless data[:schema_version] == 1
        add.call('ERROR', 'include_boq must be boolean') unless [true, false].include?(data[:include_boq])
        (Schema::FIELDS - %i[schema_version include_boq]).each { |key| add.call('ERROR', "#{key} must be a string") unless data[key].is_a?(String) }
        if data[:include_boq] == true
          %i[category item_type description unit quantity_method].each { |key| add.call('ERROR', "Missing #{key}") if data[key].to_s.strip.empty? }
        end
        {category: Schema::CATEGORIES, unit: Schema::UNITS, quantity_method: Schema::METHODS}.each do |key, allowed|
          add.call('ERROR', "Invalid #{key}") unless data[key].to_s.empty? || allowed.include?(data[key])
        end
        expected = {'area' => ['m2'], 'length' => ['m'], 'volume' => ['m3'], 'count' => %w[pcs set lot]}[data[:quantity_method]]
        add.call('ERROR', "#{data[:quantity_method]} requires #{expected.join('/')}") if expected && !expected.include?(data[:unit])
        add.call('WARNING', 'Missing Code') if data[:include_boq] && data[:code].to_s.empty?
        add.call('INFO', 'Zone not assigned') if data[:zone].to_s.empty?
        issues
      rescue StandardError => error
        BIM.log("Validation failed: #{error.message}")
        [{severity: 'ERROR', message: 'Unable to read BIM metadata'}]
      end
      def self.validate(records)
        records.select { |r| Data.supported?(r[:entity]) }.map do |record|
          issues = inspect_entity(record[:entity])
          errors = issues.select { |i| i[:severity] == 'ERROR' }
          status = if !Data.has_data?(record[:entity])
                     'UNCLASSIFIED'
                   elsif errors.empty?
                     'VGD READY'
                   elsif errors.all? { |i| i[:message].start_with?('Missing ') }
                     'INCOMPLETE'
                   else
                     'ERROR'
                   end
          record.merge(issues: issues, status: status)
        end
      end
      def self.selection; validate(Scanner.scan_selection); end
      def self.model; validate(Scanner.scan_model); end
    end
  end
end
