# frozen_string_literal: true
require 'sketchup.rb'
require 'extensions.rb'
module VGD
  module Scenes
    VERSION = '1.2.2'.freeze unless const_defined?(:VERSION, false)
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD Scenes', File.join(__dir__, 'vgd_scenes', 'main'))
      extension.description = 'Tạo và quản lý scene đối tượng, mặt cắt tùy chỉnh, khung camera và xuất PNG/JPG/PDF.'
      extension.version = VERSION
      extension.creator = 'VGD'
      extension.copyright = '2026 VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
