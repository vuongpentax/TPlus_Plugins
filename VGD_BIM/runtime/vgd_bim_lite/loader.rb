require 'sketchup.rb'
require 'json'
module VGD
  module BIM
    ROOT = File.dirname(__FILE__).freeze
    @log_counts = Hash.new(0)
    def self.log(message)
      return if @log_counts.values.inject(0, :+) >= 100
      @log_counts[message] += 1
      puts "[VGD BIM] #{message}" if @log_counts[message] <= 3
    end
    def self.presets
      @presets ||= JSON.parse(File.read(File.join(ROOT, 'config', 'presets.json'), encoding: 'UTF-8'))
    end
    def self.open_panel(mode)
      @panels ||= {}
      if @panels[mode] && @panels[mode].visible?
        @panels[mode].show
        return
      end
      @panels[mode] = UI::Dialog.new(mode)
      @panels[mode].show
    end
  end
end
%w[core/schema core/data core/geometry core/scanner core/validator intake/mapping_rules intake/detector intake/raw_scanner intake/mapping intake/converter ui/dialog ui/information_dialog ui/scan_dialog ui/mapping_dialog ui/validation_dialog].each { |file| require File.join(VGD::BIM::ROOT, file) }
unless file_loaded?(__FILE__)
  menu = ::UI.menu('Extensions').add_submenu('VGD').add_submenu('BIM Lite')
  actions = [['BIM Information', 'information'], ['Scan Model', 'scan'], ['Map / Convert Model', 'mapping'], ['Convert Selection', 'convert_selection'], ['Validate Selection', 'validate_selection'], ['Validate Model', 'validate_model'], ['Mapping Rules', 'rules']]
  actions.each { |name, mode| menu.add_item(name) { VGD::BIM.open_panel(mode) } }
  menu.add_item('About') { ::UI.messagebox("VGD BIM Lite #{VGD::BIM::VERSION}\nCore / Intake / Validation\nSketchUp 2022+\nVGD") }
  ::UI.add_context_menu_handler do |context|
    if Sketchup.active_model.selection.any? { |e| VGD::BIM::Data.supported?(e) }
      context.add_item('VGD BIM Information') { VGD::BIM.open_panel('information') }
      context.add_item('Convert to VGD') { VGD::BIM.open_panel('convert_selection') }
    end
  end
  toolbar = ::UI::Toolbar.new('VGD BIM Lite')
  [['BIM Information', 'information', 'information.svg'], ['Scan / Validate', 'scan', 'scan.svg']].each do |name, mode, icon|
    command = ::UI::Command.new(name) { VGD::BIM.open_panel(mode) }
    command.tooltip = name
    command.status_bar_text = "VGD BIM Lite: #{name}"
    command.small_icon = command.large_icon = File.join(VGD::BIM::ROOT, 'assets', 'icons', icon)
    toolbar.add_item(command)
  end
  toolbar.restore
  file_loaded(__FILE__)
end
