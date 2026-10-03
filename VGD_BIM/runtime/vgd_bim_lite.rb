require 'sketchup.rb'
require 'extensions.rb'
module VGD
  module BIM
    VERSION = '0.1.0-alpha'.freeze
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('VGD BIM Lite', 'vgd_bim_lite/loader')
      extension.description = 'Core BIM metadata, model intake, mapping and validation.'
      extension.version = VERSION
      extension.creator = 'VGD'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
