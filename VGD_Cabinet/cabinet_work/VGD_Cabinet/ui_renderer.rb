# frozen_string_literal: true

module VGD_Cabinet
  module UIRenderer
    remove_const(:TEMPLATE_PATH) if const_defined?(:TEMPLATE_PATH, false)
    TEMPLATE_PATH = File.join(__dir__, 'VGD_Cabinet_UI.html').freeze

    class << self
      def render(data, presets, defaults)
        template = File.read(TEMPLATE_PATH, mode: 'r:BOM|UTF-8')
        template
          .gsub('#{presets_json}') { JSON.generate(presets.to_json).gsub('<', '\u003c') }
          .gsub('#{default_json}') { JSON.generate(defaults.to_json).gsub('<', '\u003c') }
          .gsub('#{initial_json}') { JSON.generate(data.to_json).gsub('<', '\u003c') }
      rescue => e
        warn("VGD_CABINET UI error: #{e.class}: #{e.message}")
        '<html><body><h3>VGD_CABINET</h3><p>Không thể nạp giao diện.</p></body></html>'
      end
    end
  end
end
