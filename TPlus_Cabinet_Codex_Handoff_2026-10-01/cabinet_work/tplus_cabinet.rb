require 'sketchup.rb'
require 'extensions.rb'

module TPlus_Cabinet
  unless file_loaded?(__FILE__)
    ex = SketchupExtension.new('T+_CABINET v4.3.0-beta.6', 'TPlus_Cabinet/main43.rb')
    ex.description = 'Dựng hình tủ gỗ công nghiệp theo logic kết cấu sản xuất cho SketchUp 2022/2024; bản dựng hình chạy thử.'
    ex.version     = '4.3.0-beta.6'
    ex.copyright   = 'T+_CABINET Team 2026'
    ex.creator     = 'T+_CABINET'
    Sketchup.register_extension(ex, true)
    file_loaded(__FILE__)
  end
end
