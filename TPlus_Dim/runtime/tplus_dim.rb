# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module TPlus
  module Dim
    VERSION = '1.1.0-beta.2'.freeze unless const_defined?(:VERSION)
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('T+ Dim', 'TPlus_Dim/main')
      extension.description = 'Chuẩn hóa, gán tag, xóa sâu Dim/Text và lưu quy chuẩn theo file. SketchUp 2022 trở lên.'
      extension.version = VERSION
      extension.creator = 'T+'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
