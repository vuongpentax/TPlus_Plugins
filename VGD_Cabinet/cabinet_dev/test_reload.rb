# Virtual file fixture: actual runtime source is evaluated on each Kernel.load.
# No native SketchUp execution or filesystem deployment is claimed by this test.
def assert(ok, message); raise message unless ok; end
$fixture_loads = []
class << File
  alias_method :fixture_realpath, :realpath
  alias_method :fixture_read, :read
  def realpath(path, *)
    expanded = expand_path(path)
    return expanded if expanded == '/vgd' || $fixture_sources.key?(expanded)
    raise Errno::ENOENT, expanded if expanded.start_with?('/vgd/')
    fixture_realpath(path)
  end
  def read(path, **options)
    return $fixture_sources.fetch(path) if $fixture_sources.key?(path)
    fixture_read(path, **options)
  end
end
class << Kernel
  alias_method :fixture_original_load, :load
  def load(path, *)
    if $fixture_sources.key?(path)
      $fixture_loads << path
      source = $fixture_sources.fetch(path).gsub(/\r\n?/, "\n").gsub(/^require_relative .*$/, '').gsub(/^require 'sketchup.rb'$/, '')
      eval(source, TOPLEVEL_BINDING, path)
      true
    else
      raise "Attempted to load a file outside VGD Cabinet: #{path}"
    end
  end
end
module AnotherPluginFixture
  @reload_count = 0
  class << self; attr_reader :reload_count; end
end

# Start with the beta 4 menu/toolbar already present and its file guard set.
module VGD_Cabinet
  VERSION = '4.3.0-beta.4'
  def self.show_dialog; end
  def self.dialog_visible?; @dialog && @dialog.visible?; end
  def self.is_updating_from_ui?; @busy == true; end
  @toolbar = UI::Toolbar.new('VGD Cabinet — Dựng hình')
  old_command = UI::Command.new('VGD Cabinet — Dựng hình') { show_dialog }
  @toolbar.add_item(old_command)
  UI.menu('Extensions').add_item(old_command)
end
file_loaded('/vgd/main43.rb')
old_toolbar = UI.toolbars.first
old_main_command = old_toolbar.items.first
old_model = Sketchup.active_model
foreign_observer = Object.new
old_observer = Object.new
old_model.selection.add_observer(foreign_observer)
old_model.selection.add_observer(old_observer)
old_dialog = UI::HtmlDialog.new
old_dialog.show
old_dialog.set_on_closed { VGD_Cabinet.instance_variable_set(:@dialog, nil) }
VGD_Cabinet.instance_variable_set(:@dialog, old_dialog)
VGD_Cabinet.instance_variable_set(:@observed_model, old_model)
VGD_Cabinet.instance_variable_set(:@observer, old_observer)
Kernel.load('/vgd/reload.rb')
assert(VGD_Cabinet.reload_extension, 'Beta 4 bootstrap reload failed')
assert(VGD_Cabinet::VERSION == '4.4.0-beta.1', 'Version did not update')
assert(UI.toolbars.size == 1 && old_toolbar.items.size == 3, 'Beta 4 toolbar duplicated or utilities missing')
assert(old_toolbar.items.first.equal?(old_main_command), 'Beta 4 draw command replaced')
assert(UI.menus.fetch('Extensions').items.size == 2, 'Beta 4 draw menu duplicated')
assert(!old_dialog.visible? && VGD_Cabinet.dialog_visible?, 'Dialog was not closed/reopened')
assert(!old_model.selection.observers.include?(old_observer), 'Old VGD observer leaked')
assert(old_model.selection.observers.include?(foreign_observer), 'Other plugin observer removed')
assert(old_model.selection.observers.size == 2, 'Expected only foreign and new VGD observers')
assert(UI.context_handlers.empty?, 'Context handler duplicated during beta 4 migration')
new_dialog = VGD_Cabinet.dialog
old_dialog.closed_callback.call
assert(VGD_Cabinet.dialog.equal?(new_dialog), 'Late old close callback cleared the new dialog')
puts 'PASS reload bootstrap: beta 4 toolbar reused, utilities/reload added, dialog recreated, old VGD observer detached, foreign observer retained'

# Change code and HTML on disk, invoke the actual menu callback, and reload twice.
defaults_original = $fixture_sources.fetch('/vgd/defaults.rb')
$fixture_sources['/vgd/defaults.rb'] = defaults_original.sub('"w" => 800.0', '"w" => 901.0')
$fixture_sources['/vgd/VGD_Cabinet_UI.html'] += '<!-- reload fixture sentinel -->'
menu = UI.menus.fetch('Extensions').items.last
2.times do
  $fixture_loads.clear
  assert(menu.items.last.call, 'Reload menu failed')
  assert(VGD_Cabinet.default_params['w'] == 901.0, 'Updated dependency was cached')
  assert(VGD_Cabinet.dialog.html.include?('reload fixture sentinel'), 'Updated HTML was cached')
  assert(UI.toolbars.size == 1 && old_toolbar.items.size == 3 && menu.items.size == 3, 'Reload duplicated UI')
  assert(old_model.selection.observers.size == 2, 'Reload leaked or removed observers')
  expected = ['/vgd/reload.rb'] + VGD_Cabinet::Development.ruby_files.map { |name| '/vgd/' + name }
  assert($fixture_loads == expected, 'Reload did not load exactly the owned whitelist in dependency order')
end
assert(AnotherPluginFixture.reload_count == 0, 'Another plugin was reloaded')
assert(old_model.operations == 0, 'Reload mutated model geometry')
puts 'PASS reload: real updated dependency/HTML, repeated loads, exact own-file list, stable menus/toolbar/observers, no model operation or foreign reload'

# Syntax/missing files fail before the existing dialog or observer is disturbed.
original_main = $fixture_sources.fetch('/vgd/main43.rb')
$fixture_sources['/vgd/main43.rb'] = 'module BadSyntax'
previous_dialog = VGD_Cabinet.dialog
$fixture_loads.clear
assert(!VGD_Cabinet.reload_extension, 'Syntax error should fail')
assert(VGD_Cabinet.dialog.equal?(previous_dialog) && previous_dialog.visible?, 'Syntax failure closed working dialog')
assert($fixture_loads == ['/vgd/reload.rb'], 'Runtime files executed before syntax validation')
$fixture_sources['/vgd/main43.rb'] = original_main
missing = $fixture_sources.delete('/vgd/defaults.rb')
assert(!VGD_Cabinet.reload_extension, 'Missing file should fail')
assert(VGD_Cabinet.dialog.equal?(previous_dialog) && old_model.selection.observers.size == 2, 'Missing file disturbed UI/observer')
$fixture_sources['/vgd/defaults.rb'] = missing
VGD_Cabinet.instance_variable_set(:@busy, true)
$fixture_loads.clear
assert(!VGD_Cabinet.reload_extension && $fixture_loads.empty?, 'Reload during model update not blocked')
VGD_Cabinet.instance_variable_set(:@busy, false)
assert(VGD_Cabinet.reload_extension, 'Reload guard did not recover after failure')
puts 'PASS reload guards: syntax/missing files preserve working UI, busy operation blocked, later reload recovers'
