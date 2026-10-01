# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module TPlus
  module DCExporter
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('T+ DC Exporter', 'tplus_dc_exporter/main')
      extension.description = 'Xuất thuộc tính, công thức và cấu trúc component/group đang chọn thành JSON. Chỉ đọc mô hình.'
      extension.version = '1.0.0'
      extension.creator = 'T+ Architecture'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
