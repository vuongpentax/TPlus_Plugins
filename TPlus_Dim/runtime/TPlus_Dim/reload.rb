# encoding: UTF-8
# Explicit Ruby Console entry point; touches only this extension, preserving its toolbar.
require 'sketchup.rb'
files=%w[defaults font_book custom_dim engine profile main].map { |name| File.join(__dir__,name+'.rb') }
files.each { |path| RubyVM::InstructionSequence.compile_file(path) }
if defined?(TPlus::Dim)
  dialog=TPlus::Dim.instance_variable_get(:@dialog)
  dialog.close if dialog
  TPlus::Dim::ProfileService.shutdown if defined?(TPlus::Dim::ProfileService)
  TPlus::Dim.send(:remove_const,:DEFAULTS) if TPlus::Dim.const_defined?(:DEFAULTS,false)
  TPlus::Dim.send(:remove_const,:VERSION) if TPlus::Dim.const_defined?(:VERSION,false)
  TPlus::Dim.const_set(:VERSION,'1.1.0-beta.2'.freeze)
end
files.each { |path| load path }
TPlus::Dim.show_dialog
