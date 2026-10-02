require 'sketchup.rb'
require 'extensions.rb'

module VGD_Cabinet
  unless file_loaded?(__FILE__)
    ex = SketchupExtension.new('VGD_Cabinet v4.4.0-beta.1', 'VGD_Cabinet/main43.rb')
    ex.description = 'Dựng hình tủ gỗ công nghiệp theo logic kết cấu sản xuất cho SketchUp 2022/2024; bản dựng hình chạy thử.'
    ex.version     = '4.4.0-beta.1'
    ex.copyright   = 'VGD_CABINET Team 2026'
    ex.creator     = 'VGD_CABINET'
    Sketchup.register_extension(ex, true)
    file_loaded(__FILE__)
  end
end
