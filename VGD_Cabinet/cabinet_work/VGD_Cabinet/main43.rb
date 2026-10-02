# frozen_string_literal: true
require 'sketchup.rb'
require 'json'
require_relative 'geometry_engine'
require_relative 'modeling_rules'
require_relative 'modeling'
require_relative 'defaults'
require_relative 'ui_renderer'
require_relative 'draw_tool'
require_relative 'utilities'
require_relative 'reload'
require_relative 'preset_store'
module VGD_Cabinet
  remove_const(:VERSION) if const_defined?(:VERSION, false)
  VERSION = '4.4.0-beta.1'
  class CabinetSelectionObserver < Sketchup::SelectionObserver
    def onSelectionBulkChange(_s); VGD_Cabinet.sync_current_selection; end
    def onSelectionAdded(_s,_e); VGD_Cabinet.sync_current_selection; end
    def onSelectionRemoved(_s,_e); VGD_Cabinet.sync_current_selection; end
    def onSelectionCleared(_s); VGD_Cabinet.sync_current_selection; end
  end
  class PlacementTool
    def initialize(p); @p=p; @ip=Sketchup::InputPoint.new; end
    def activate; Sketchup.status_text='Click để đặt tủ theo trục của ngữ cảnh hiện tại; Esc để hủy.'; end
    def onMouseMove(_flags,x,y,view); @ip.pick(view,x,y); view.invalidate; end
    def draw(view); @ip.draw(view) if @ip.valid?; end
    def onLButtonDown(_flags,x,y,view)
      @ip.pick(view,x,y)
      return unless @ip.valid?
      model=Sketchup.active_model
      point=@ip.position.transform(model.edit_transform.inverse)
      VGD_Cabinet.create_new_cabinet_at(@p,Geom::Transformation.translation(point.to_a))
      model.select_tool(nil)
    end
    def onCancel(_reason,_view); Sketchup.active_model.select_tool(nil); end
  end
  class << self
    attr_accessor :dialog
    def is_updating_from_ui?; @busy == true; end
    def dialog_visible?; @dialog && @dialog.visible?; end
    def is_cabinet_entity?(e)
      return false unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      %w[VGD_Cabinet TPlus_Cabinet].any? { |dict| e.get_attribute(dict,'is_cabinet',false) || e.definition.get_attribute(dict,'is_cabinet',false) }
    end
    def find_cabinet_instance
      selection=Sketchup.active_model.selection
      return nil unless selection.length == 1
      e=selection.first
      is_cabinet_entity?(e) ? e : nil
    end
    def get_cabinet_params(e)
      json=%w[VGD_Cabinet TPlus_Cabinet].map { |dict| e.get_attribute(dict,'params_json',nil) || e.definition.get_attribute(dict,'params_json',nil) }.compact.first
      parsed=json ? JSON.parse(json) : nil
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end
    def set_cabinet_params(e,p)
      e.set_attribute('VGD_Cabinet','is_cabinet',true)
      e.set_attribute('VGD_Cabinet','params_json',JSON.generate(p))
      e.set_attribute('VGD_Cabinet','version',VERSION)
    end
    def report_error(e)
      text=e.is_a?(ModelingRules::Invalid) ? e.message : "Không dựng được tủ: #{e.message}"
      puts "VGD Cabinet #{e.class}: #{e.message}\n#{Array(e.backtrace).first(5).join("\n")}" unless e.is_a?(ModelingRules::Invalid)
      dialog_visible? ? @dialog.execute_script("showModelStatus(#{text.to_json},true);") : UI.messagebox(text)
      nil
    end
    def normalize(p); ModelingRules.normalize(p,default_params); end
    def draw_geometry(entities,p); Modeling.draw(entities,p); end
    def create_new_cabinet(p)
      Sketchup.active_model.select_tool(PlacementTool.new(normalize(p)))
    rescue => e
      report_error(e)
    end
    def create_new_cabinet_at(p,transform)
      p=normalize(p); model=Sketchup.active_model
      @busy=true; active_tag=model.active_layer; started=false
      begin
        model.start_operation('VGD Dựng tủ',true); started=true
        model.active_layer=model.layers[0]
        definition=model.definitions.add('VGD_CABINET')
        draw_geometry(definition.entities,p); set_cabinet_params(definition,p)
        tr=transform.is_a?(Geom::Transformation) ? transform : Geom::Transformation.new(transform)
        inst=model.active_entities.add_instance(definition,tr); inst.name='Tủ VGD'
        inst.layer=model.layers['VGD_CABINET'] || model.layers.add('VGD_CABINET')
        set_cabinet_params(inst,p)
        model.selection.clear; model.selection.add(inst)
        model.commit_operation; started=false
      rescue => e
        model.abort_operation if started
        return report_error(e)
      ensure
        model.active_layer=active_tag; @busy=false
      end
      sync_current_selection
      inst
    rescue => e
      report_error(e)
    end
    def update_selected_cabinet(input)
      model=Sketchup.active_model; inst=find_cabinet_instance
      raise ModelingRules::Invalid,'Chọn đúng một tủ VGD để cập nhật. Dùng ĐẶT TỦ MỚI để tạo tủ.' unless inst
      raise ModelingRules::Invalid,'Tủ đang khóa. Hãy mở khóa trước khi sửa.' if inst.locked?
      raise ModelingRules::Invalid,'Đã đổi file SketchUp. Mở lại bảng VGD để đọc tủ của file hiện tại.' unless input['__model_guid'].to_s == model.guid.to_s
      raise ModelingRules::Invalid,'Đối tượng chọn đã thay đổi. Hãy sửa lại thông số của tủ đang chọn.' unless input['__target_pid'].to_s == inst.persistent_id.to_s
      p=normalize(input)
      tr=inst.transformation; axes=[tr.xaxis,tr.yaxis,tr.zaxis]
      raise ModelingRules::Invalid,'Tủ có tỷ lệ bằng 0; khôi phục Scale trước khi sửa.' if axes.any? { |a| a.length < 1e-8 }
      normalized=axes.map(&:normalize)
      raise ModelingRules::Invalid,'Tủ bị xiên (skew); khôi phục phép biến đổi trước khi sửa.' if normalized.combination(2).any? { |a,b| a.dot(b).abs > 1e-6 }
      @busy=true; active_tag=model.active_layer; started=false
      begin
        model.start_operation('VGD Cập nhật tủ',true); started=true
        model.active_layer=model.layers[0]
        inst.make_unique if inst.definition.instances.size > 1
        definition=inst.definition
        stamp=definition.get_attribute('VGD_Cabinet','stamp_angle',nil) || definition.get_attribute('TPlus_Cabinet','stamp_angle','0')
        stamp=stamp.to_f
        local_tr=Geom::Transformation.axes(tr.origin,*normalized)
        local_tr=local_tr * Geom::Transformation.rotation(ORIGIN,Z_AXIS,stamp) if stamp.abs > 1e-8
        inst.transformation=local_tr
        definition.entities.clear!; draw_geometry(definition.entities,p)
        definition.delete_attribute('VGD_Cabinet','stamp_angle')
        definition.delete_attribute('TPlus_Cabinet','stamp_angle')
        set_cabinet_params(definition,p); set_cabinet_params(inst,p)
        inst.layer=model.layers['VGD_CABINET'] || model.layers.add('VGD_CABINET')
        model.commit_operation; started=false
      rescue => e
        model.abort_operation if started
        return report_error(e)
      ensure
        model.active_layer=active_tag; @busy=false
      end
      sync_current_selection
    rescue => e
      report_error(e)
    end
    def send_params_to_ui(p)
      @dialog.execute_script("updateFormFromRuby(#{p.to_json});") if dialog_visible?
    end
    def sync_current_selection
      return if @busy || !dialog_visible?
      inst=find_cabinet_instance
      unless inst
        @dialog.execute_script('setSelectedCabinet(null);'); return
      end
      p=get_cabinet_params(inst); return unless p
      p=default_params.merge(ModelingRules.migrate(p)); tr=inst.transformation
      p['w']*=tr.xaxis.length; p['d']*=tr.yaxis.length; p['h']*=tr.zaxis.length
      p['__target_pid']=inst.persistent_id.to_s
      p['__model_guid']=Sketchup.active_model.guid.to_s
      send_params_to_ui(p)
    end
    def builtin_presets
      {
        'Tủ áo 800' => default_params.merge('d'=>600,'shelf_count'=>1),
        'Tủ áo 3 module độc lập' => default_params.merge('w'=>2400,'module_mode'=>'Độc lập','module_widths'=>'800;800;800','shelf_count'=>1),
        'Tủ áo hai tầng' => default_params.merge('w'=>1600,'h'=>2700,'is_overheight'=>true,'h_bottom'=>2100,'module_mode'=>'Độc lập','module_widths'=>'800;800','shelf_count'=>1,'shelf_count_top'=>1),
        'Tủ bếp dưới' => default_params.merge('h'=>810,'shadow_gap_h'=>0,'plinth_h'=>100,'opt_door'=>'Cánh Phủ toàn bộ'),
        'Tủ 3 hộc kéo lộ' => default_params.merge('h'=>810,'shadow_gap_h'=>0,'opt_door'=>'Không Cánh','opt_drawer'=>'Lộ','is_full_drawer'=>true,'drawer_count'=>3),
        'Tủ hộc kéo âm' => default_params.merge('t'=>20,'opt_drawer'=>'Âm','drawer_hinge_sp'=>50,'drawer_inner_offset'=>50,'drawer_count'=>2),
        'Kệ mở' => default_params.merge('h'=>1200,'d'=>350,'shadow_gap_h'=>0,'opt_door'=>'Không Cánh','shelf_count'=>3)
      }
    end
    def preset_store
      path=File.join(ENV['APPDATA'] || File.join(Dir.home,'Library','Application Support'),
        'VGD','SketchUp','VGD_Cabinet','presets_v1.json')
      @preset_store ||= PresetStore.new(path, defaults: -> { builtin_presets }, legacy: -> { legacy_presets(path) })
    end
    def legacy_presets(path)
      # Read-only migration. Preserve malformed old data rather than blocking the UI.
      raw=Sketchup.read_default('TPlus_Cabinet','presets_v43','{}').to_s
      parsed=JSON.parse(raw)
      raise ArgumentError,'Mẫu T+ cũ sai định dạng.' unless parsed.is_a?(Hash)
      parsed
    rescue JSON::ParserError, ArgumentError => error
      backup=path+'.tplus-unreadable-'+SecureRandom.hex(4)+'.txt'
      File.open(backup,'wx') { |f| f.write(raw); f.flush; f.fsync }
      @preset_migration_warning="Mẫu T+ cũ không đọc được; đã giữ dữ liệu gốc tại #{backup}. Các mẫu mới vẫn lưu được."
      puts "VGD_Cabinet: #{@preset_migration_warning} (#{error.message})"
      {}
    end
    def presets
      preset_store.load
    end
    def show_dialog
      if dialog_visible?
        if @observed_model != Sketchup.active_model
          @observed_model.selection.remove_observer(@observer) rescue nil
          @observed_model=Sketchup.active_model
          @observed_model.selection.add_observer(@observer)
        end
        @dialog.bring_to_front; sync_current_selection; return
      end
      @dialog=UI::HtmlDialog.new(dialog_title:"VGD_Cabinet #{VERSION} — Dựng hình",preferences_key:'VGD_Cabinet.Modeling43Menu',scrollable:false,resizable:true,width:560,height:680,min_width:480,min_height:460,style:UI::HtmlDialog::STYLE_DIALOG)
      @dialog.set_html(UIRenderer.render(default_params,presets,default_params))
      @observed_model=Sketchup.active_model; @observer=CabinetSelectionObserver.new
      @observed_model.selection.add_observer(@observer)
      current_dialog=@dialog; observed_model=@observed_model; observer=@observer
      @dialog.set_on_closed do
        observed_model.selection.remove_observer(observer) rescue nil
        if @dialog.equal?(current_dialog)
          @dialog=nil; @observed_model=nil; @observer=nil
        end
      end
      @dialog.add_action_callback('ready') do
        sync_current_selection
        @dialog.execute_script("showModelStatus(#{@preset_migration_warning.to_json},true);") if @preset_migration_warning
      end
      @dialog.add_action_callback('create_cabinet') { |_,p| create_new_cabinet(p) }
      @dialog.add_action_callback('update_cabinet') { |_,p| update_selected_cabinet(p) }
      @dialog.add_action_callback('draw_cabinet_tool') do |_,p|
        begin
          Sketchup.active_model.select_tool(CabinetDrawTool.new(normalize(p)))
        rescue => e
          report_error(e)
        end
      end
      @dialog.add_action_callback('save_preset') do |_,data|
        begin
          raise ModelingRules::Invalid,'Dữ liệu mẫu không hợp lệ.' unless data.is_a?(Hash)
          action=data['action'] || 'create'
          raise ModelingRules::Invalid,'Chọn Tạo mới, Cập nhật hoặc Đổi tên.' unless %w[create update rename].include?(action)
          params=%w[create update].include?(action) ? normalize(data['params']) : nil
          values=preset_store.change(action,data['name'],data['source_name'],params)
          @dialog.execute_script("updatePresetList(#{values.to_json.dump},#{data['name'].to_s.strip.to_json});")
          @dialog.execute_script("document.getElementById('preset_name').value='';showModelStatus('Đã lưu mẫu.',false);")
        rescue => e
          report_error(e)
        end
      end
      @dialog.add_action_callback('delete_preset') do |_,name|
        begin
          values=preset_store.change('delete',name)
          @dialog.execute_script("updatePresetList(#{values.to_json.dump},'');")
        rescue => e
          report_error(e)
        end
      end
      @dialog.show
    end
  end
  def self.install_commands
    return if @commands_installed
    existing_toolbar=@toolbar
    existing_commands=[]
    existing_toolbar.each { |item| existing_commands << item if item.is_a?(UI::Command) } if existing_toolbar
    command=existing_commands.find { |item| item.menu_text.include?('Dựng hình') }
    unless command
      command=UI::Command.new('VGD Cabinet — Dựng hình') { show_dialog }
      UI.menu('Extensions').add_item(command)
    end
    icon=File.join(__dir__,'logo.svg')
    command.small_icon=icon; command.large_icon=icon
    command.tooltip="VGD Cabinet #{VERSION} — Dựng hình kỹ thuật"
    explode_command=existing_commands.find { |item| item.menu_text.include?('VGD_EXPLODE') }
    explode_command ||= UI::Command.new('VGD_EXPLODE (Rã Nhóm Lồng Tủ & Xóa Khối Ẩn)') { VGDExplode.execute_explode }
    explode_icon=File.join(__dir__,'combine.svg')
    explode_command.small_icon=explode_icon; explode_command.large_icon=explode_icon
    explode_command.tooltip='VGD_EXPLODE: Rã nhóm lồng, làm sạch thuộc tính DC'
    explode_command.status_bar_text='Xử lý vùng chọn: giữ từng tấm độc lập và tủ cha, xóa chi tiết ẩn, dọn hình học'
    untag_command=existing_commands.find { |item| item.menu_text.include?('VGD_UNTAG') }
    untag_command ||= UI::Command.new('VGD_UNTAG (Xóa Tag Con, Giữ Tag Cha)') { VGDUntag.clean_selected_tags }
    untag_icon=File.join(__dir__,'untag.svg')
    untag_command.small_icon=untag_icon; untag_command.large_icon=untag_icon
    untag_command.tooltip='VGD_UNTAG: Xóa tag đối tượng con'
    untag_command.status_bar_text='Đưa mọi đối tượng con về Untagged, giữ nguyên tag cha ngoài cùng'
    reload_command=UI::Command.new('VGD — Nạp lại mã (Reload)') { reload_extension }
    reload_command.tooltip='Nạp lại riêng mã Ruby và giao diện VGD Cabinet'
    reload_command.status_bar_text='Sau khi đồng bộ mã: thoát công cụ đang vẽ, bấm Reload để nhận bản cập nhật VGD Cabinet'
    menu=UI.menu('Extensions').add_submenu('VGD Cabinet — Tiện ích')
    [explode_command,untag_command].each { |item| menu.add_item(item) unless existing_commands.include?(item) }
    menu.add_item(reload_command)
    @toolbar ||= UI::Toolbar.new('VGD Cabinet — Dựng hình')
    [command,explode_command,untag_command].each { |item| @toolbar.add_item(item) unless existing_commands.include?(item) }
    @toolbar.restore
    unless file_loaded?(__FILE__)
      UI.add_context_menu_handler do |context_menu|
        context_menu.add_item('VGD — Sửa tủ đang chọn') { show_dialog } if find_cabinet_instance
      end
      file_loaded(__FILE__)
    end
    @commands_installed=true
    @reload_command=reload_command
  end
  install_commands if @toolbar || !file_loaded?(__FILE__)
end
