menu = UI.menus.fetch('Extensions').items.last
toolbar = UI.toolbars.last
assert(menu.items.size == 3 && toolbar.items.size == 3, 'Expected three menu and toolbar commands')
assert(menu.items.first(2) == toolbar.items.drop(1), 'Utility menu and toolbar mismatch')
assert(menu.items[0].name.include?('T+_EXPLODE') && menu.items[1].name.include?('T+_UNTAG'), 'Restored names missing')
assert(menu.items[0].small_icon.end_with?('combine.svg'), 'Wrong combine icon')
assert(menu.items[1].large_icon.end_with?('untag.svg'), 'Wrong untag icon')
assert(menu.items[2].name.include?('Reload'), 'Reload command missing')
model = Sketchup.reset
top = model.entities.add_group; dc(top); model.selection.add(top)
menu.items[0].call
assert_clean(top)
assert(model.commits == 1, 'EXPLODE menu callback not connected')
child = top.entities.add_group; child.layer = Sketchup::Layer.new('Con')
menu.items[1].call
assert(child.layer == model.layers[0] && model.commits == 2, 'UNTAG menu callback not connected')
TPlus_Cabinet.install_commands
assert(UI.toolbars.size == 1 && toolbar.items.size == 3, 'Duplicate toolbar after reinstall')
assert(menu.items.size == 3 && UI.context_handlers.size == 1, 'Duplicate menus or context handlers')
puts 'PASS commands: three toolbar buttons, utility/reload menu, correct icons, callbacks, no duplicate UI'
