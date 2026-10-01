# Virtual file fixture: actual runtime source is evaluated on each Kernel.load.
# No native SketchUp execution or filesystem deployment is claimed by this test.
def assert(ok, message); raise message unless ok; end
$fixture_loads = []
class << File
  alias_method :fixture_realpath, :realpath
  alias_method :fixture_read, :read
  def realpath(path, *)
    expanded = expand_path(path)
    return expanded if expanded == '/tplus' || $fixture_sources.key?(expanded)
    raise Errno::ENOENT, expanded if expanded.start_with?('/tplus/')
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
      source = $fixture_sources.fetch(path).gsub(/^require_relative .*$/, '').gsub(/^require 'sketchup.rb'$/, '')
      eval(source, TOPLEVEL_BINDING, path)
      true
    else
      raise "Attempted to load a file outside T+ Cabinet: #{path}"
    end
  end
end
module AnotherPluginFixture
  @reload_count = 0
  class << self; attr_reader :reload_count; end
end

# Start with the beta 4 menu/toolbar already present and its file guard set.
module TPlus_Cabinet
  VERSION = '4.3.0-beta.4'
  def self.show_dialog; end
  def self.dialog_visible?; @dialog && @dialog.visible?; end
  def self.is_updating_from_ui?; @busy == true; end
  @toolbar = UI::Toolbar.new('T+ Cabinet — Dựng hình')
  old_command = UI::Command.new('T+ Cabinet — Dựng hình') { show_dialog }
  @toolbar.add_item(old_command)
  UI.menu('Extensions').add_item(old_command)
end
file_loaded('/tplus/main43.rb')
old_toolbar = UI.toolbars.first
old_main_command = old_toolbar.items.first
old_model = Sketchup.active_model
foreign_observer = Object.new
old_observer = Object.new
old_model.selection.add_observer(foreign_observer)
old_model.selection.add_observer(old_observer)
old_dialog = UI::HtmlDialog.new
old_dialog.show
old_dialog.set_on_closed { TPlus_Cabinet.instance_variable_set(:@dialog, nil) }
TPlus_Cabinet.instance_variable_set(:@dialog, old_dialog)
TPlus_Cabinet.instance_variable_set(:@observed_model, old_model)
TPlus_Cabinet.instance_variable_set(:@observer, old_observer)
Kernel.load('/tplus/reload.rb')
assert(TPlus_Cabinet.reload_extension, 'Beta 4 bootstrap reload failed')
assert(TPlus_Cabinet::VERSION == '4.3.0-beta.6', 'Version did not update')
assert(UI.toolbars.size == 1 && old_toolbar.items.size == 3, 'Beta 4 toolbar duplicated or utilities missing')
assert(old_toolbar.items.first.equal?(old_main_command), 'Beta 4 draw command replaced')
assert(UI.menus.fetch('Extensions').items.size == 2, 'Beta 4 draw menu duplicated')
assert(!old_dialog.visible? && TPlus_Cabinet.dialog_visible?, 'Dialog was not closed/reopened')
assert(!old_model.selection.observers.include?(old_observer), 'Old T+ observer leaked')
assert(old_model.selection.observers.include?(foreign_observer), 'Other plugin observer removed')
assert(old_model.selection.observers.size == 2, 'Expected only foreign and new T+ observers')
assert(UI.context_handlers.empty?, 'Context handler duplicated during beta 4 migration')
new_dialog = TPlus_Cabinet.dialog
old_dialog.closed_callback.call
assert(TPlus_Cabinet.dialog.equal?(new_dialog), 'Late old close callback cleared the new dialog')
puts 'PASS reload bootstrap: beta 4 toolbar reused, utilities/reload added, dialog recreated, old T+ observer detached, foreign observer retained'

# Change code and HTML on disk, invoke the actual menu callback, and reload twice.
defaults_original = $fixture_sources.fetch('/tplus/defaults.rb')
$fixture_sources['/tplus/defaults.rb'] = defaults_original.sub('"w" => 800.0', '"w" => 901.0')
$fixture_sources['/tplus/TPlus_Cabinet_UI.html'] += '<!-- reload fixture sentinel -->'
menu = UI.menus.fetch('Extensions').items.last
2.times do
  $fixture_loads.clear
  assert(menu.items.last.call, 'Reload menu failed')
  assert(TPlus_Cabinet.default_params['w'] == 901.0, 'Updated dependency was cached')
  assert(TPlus_Cabinet.dialog.html.include?('reload fixture sentinel'), 'Updated HTML was cached')
  assert(UI.toolbars.size == 1 && old_toolbar.items.size == 3 && menu.items.size == 3, 'Reload duplicated UI')
  assert(old_model.selection.observers.size == 2, 'Reload leaked or removed observers')
  expected = ['/tplus/reload.rb'] + TPlus_Cabinet::Development.ruby_files.map { |name| '/tplus/' + name }
  assert($fixture_loads == expected, 'Reload did not load exactly the owned whitelist in dependency order')
end
assert(AnotherPluginFixture.reload_count == 0, 'Another plugin was reloaded')
assert(old_model.operations == 0, 'Reload mutated model geometry')
puts 'PASS reload: real updated dependency/HTML, repeated loads, exact own-file list, stable menus/toolbar/observers, no model operation or foreign reload'

# Syntax/missing files fail before the existing dialog or observer is disturbed.
original_main = $fixture_sources.fetch('/tplus/main43.rb')
$fixture_sources['/tplus/main43.rb'] = 'module BadSyntax'
previous_dialog = TPlus_Cabinet.dialog
$fixture_loads.clear
assert(!TPlus_Cabinet.reload_extension, 'Syntax error should fail')
assert(TPlus_Cabinet.dialog.equal?(previous_dialog) && previous_dialog.visible?, 'Syntax failure closed working dialog')
assert($fixture_loads == ['/tplus/reload.rb'], 'Runtime files executed before syntax validation')
$fixture_sources['/tplus/main43.rb'] = original_main
missing = $fixture_sources.delete('/tplus/defaults.rb')
assert(!TPlus_Cabinet.reload_extension, 'Missing file should fail')
assert(TPlus_Cabinet.dialog.equal?(previous_dialog) && old_model.selection.observers.size == 2, 'Missing file disturbed UI/observer')
$fixture_sources['/tplus/defaults.rb'] = missing
TPlus_Cabinet.instance_variable_set(:@busy, true)
$fixture_loads.clear
assert(!TPlus_Cabinet.reload_extension && $fixture_loads.empty?, 'Reload during model update not blocked')
TPlus_Cabinet.instance_variable_set(:@busy, false)
assert(TPlus_Cabinet.reload_extension, 'Reload guard did not recover after failure')
puts 'PASS reload guards: syntax/missing files preserve working UI, busy operation blocked, later reload recovers'
