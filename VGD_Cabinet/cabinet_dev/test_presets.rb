store_class=VGD_Cabinet::PresetStore
path='/tmp/vgd-presets-test/presets.json'
legacy={'Mẫu tiếng Việt'=>{'w'=>901,'front_bevel'=>true}}
store=store_class.new(path,defaults: -> { VGD_Cabinet.builtin_presets },legacy: -> { legacy })
VGD_Cabinet.instance_variable_set(:@preset_store,store)
values=store.load
assert(values['Mẫu tiếng Việt']['w']==901,'Legacy presets missing')
assert(values['Tủ áo 800']['door_gap']==0,'Built-in defaults outdated')
params=VGD_Cabinet.normalize(VGD_Cabinet.default_params.merge('w'=>920,'__target_pid'=>'42'))
store.change('create','Khách A',nil,params)
reopened=store_class.new(path,defaults: -> { raise 'Must not reset defaults' },legacy: -> { raise 'Must not re-import old prefs' })
assert(reopened.load['Khách A']['w']==920 && !reopened.load['Khách A'].key?('__target_pid'),'Preset lost on reopening')
before=File.read(path)
begin
  reopened.change('create','KHÁCH A',nil,params); raise 'Collision allowed'
rescue VGD_Cabinet::ModelingRules::Invalid
end
assert(File.read(path)==before,'Create collision overwrote saved data')
reopened.change('rename','Tên mới','Khách A')
assert(!reopened.load.key?('Khách A') && reopened.load['Tên mới']['w']==920,'Rename lost values/old name retained')
begin
  reopened.change('rename','Tủ áo 800','Tên mới'); raise 'Rename collision allowed'
rescue VGD_Cabinet::ModelingRules::Invalid
end
assert(reopened.load['Tên mới']['w']==920,'Rename collision deleted source')
reopened.change('update','Tên mới','Tên mới',params.merge('w'=>930))
assert(reopened.load['Tên mới']['w']==930,'Explicit update failed')
reopened.change('delete','Tủ áo 800')
assert(!reopened.load.key?('Tủ áo 800'),'Deleted built-in resurrected')
assert(File.file?(path+'.bak'),'Backup missing')
File.write(path,'broken json')
assert(reopened.load.is_a?(Hash) && reopened.load.key?('Tên mới'),'Backup recovery failed')
reopened.change('create','Sau phục hồi',nil,params)
assert(reopened.load.key?('Sau phục hồi'),'Cannot save after recovery')
before=File.read(path)
class << File
  alias_method :preset_original_rename, :rename
  def rename(*); raise Errno::EACCES,'Simulated write failure'; end
end
begin
  reopened.change('create','Lỗi ghi',nil,params)
  raise 'Failed write reported success'
rescue Errno::EACCES
ensure
  class << File; alias_method :rename, :preset_original_rename; end
end
assert(File.read(path)==before && !reopened.load.key?('Lỗi ghi'),'Failed write damaged existing presets')
10.times { |i| reopened.change('create',"Mẫu nhiều #{i}",nil,params.merge('w'=>940+i)) }
assert(File.size(path)>20000,'Large preset library not exercised')
class << Sketchup
  alias_method :preset_previous_read_default, :read_default
  def read_default(*); '{broken legacy'; end
end
begin
  migrated=VGD_Cabinet.legacy_presets(path)
  assert(migrated=={} && VGD_Cabinet.instance_variable_get(:@preset_migration_warning),'Malformed old data blocked startup or no warning')
  backup=VGD_Cabinet.instance_variable_get(:@preset_migration_warning).match(/tại (.*)\. Các mẫu/)[1]
  assert(File.read(backup)=='{broken legacy','Malformed legacy data not preserved')
ensure
  class << Sketchup; alias_method :read_default, :preset_previous_read_default; end
end
puts 'PASS preset files: initial T+ migration, restart/reload, explicit create/update/rename/delete, collision protection, no target metadata, deleted built-in, backup recovery'
