module VGD
  module BIM
    module Detector
      KEYWORDS = {
        'socket' => ['socket', 'outlet', 'o cam', 'ocam', 'ổ cắm'],
        'switch' => ['switch', 'cong tac', 'công tắc'],
        'wardrobe' => ['wardrobe', 'closet', 'tu ao', 'tủ áo'],
        'kitchen_base' => ['kitchen base', 'tu bep duoi', 'tủ bếp dưới'],
        'kitchen_upper' => ['kitchen upper', 'tu bep tren', 'tủ bếp trên'],
        'light' => ['downlight', 'light', 'den', 'đèn'],
        'paint' => ['paint', 'son tuong', 'sơn tường']
      }.freeze
      def self.normalize(value)
        value.to_s.downcase.tr('_-', '  ').gsub(/\s+/, ' ').strip
      end
      def self.suggest(raw, entity = nil, rules = MappingRules.read)
        return {data: Data.read(entity), source: Data.source(entity), confidence: 'HIGH', reason: 'Confirmed VGD data'} if entity && Data.has_data?(entity)
        %w[definition_name instance_name tag material].each do |source|
          rule = rules.find { |r| r['source_type'] == source && normalize(r['source_value']) == normalize(raw[source.to_sym]) }
          return {data: Schema.normalize(rule['data']), source: 'RULE', confidence: 'HIGH', reason: "Mapping rule: #{source}"} if rule
        end
        %i[definition_name instance_name tag material].each do |source|
          name = normalize(raw[source])
          KEYWORDS.each do |type, keywords|
            next unless keywords.any? { |word| /(?:^|\s)#{Regexp.escape(normalize(word))}(?:$|\s)/.match?(name) }
            preset = BIM.presets.find { |p| p['item_type'] == type }
            next unless preset
            return {data: Schema.normalize(preset.reject { |k, _| k == 'name' }), source: 'HEURISTIC', confidence: %i[definition_name instance_name].include?(source) ? 'HIGH' : 'MEDIUM', reason: "Keyword: #{source}"}
          end
        end
        {data: {}, source: 'RAW', confidence: 'LOW', reason: 'Manual classification required'}
      end
    end
  end
end
