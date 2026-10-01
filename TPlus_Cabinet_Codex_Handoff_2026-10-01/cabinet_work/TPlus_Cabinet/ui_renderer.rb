# frozen_string_literal: true

module TPlus_Cabinet
  module UIRenderer
    remove_const(:TEMPLATE_PATH) if const_defined?(:TEMPLATE_PATH, false)
    TEMPLATE_PATH = File.join(__dir__, 'TPlus_Cabinet_UI.html').freeze

    class << self
      def render(data, presets, defaults)
        template = File.read(TEMPLATE_PATH, mode: 'r:BOM|UTF-8')
        template
          .gsub('#{presets_json}') { JSON.generate(presets.to_json).gsub('<', '\u003c') }
          .gsub('#{default_json}') { JSON.generate(defaults.to_json).gsub('<', '\u003c') }
          .gsub('#{initial_json}') { JSON.generate(data.to_json).gsub('<', '\u003c') }
      rescue => e
        warn("T+_CABINET UI error: #{e.class}: #{e.message}")
        '<html><body><h3>T+_CABINET</h3><p>Không thể nạp giao diện.</p></body></html>'
      end
    end
  end
end
