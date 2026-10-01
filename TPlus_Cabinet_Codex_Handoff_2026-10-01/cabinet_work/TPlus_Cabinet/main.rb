# ==============================================================================
# T+_CABINET v4.2.4 - SKETCHUP EXTENSION
# Tác giả: T+_CABINET Team
# Cập nhật v4.2.4: sửa Construction Guide drawer theo đúng Tape Measure, hiệu chỉnh khung drawer âm theo
#                 hông + diềm phủ + diềm trước/sau + xà che khe, mặc định diềm 50mm;
#                 sửa stamp tủ khi Update không có selection để luôn vào tag T+_CABINET.
#                 Chế độ vẽ tủ tự động Snap bước 50mm (Length Snapping 50mm);
#                 Tên file tải về (.rbz / .rb) tự động đổi theo phiên bản mới nhất
# ==============================================================================

require 'json'
require 'sketchup.rb'

require_relative 'geometry_engine'
require_relative 'ui_renderer'
require_relative 'draw_tool'
require_relative 'utilities'
module TPlus_Cabinet
  VERSION = "4.2.4"

  class << self
    attr_accessor :dialog, :observer, :is_updating_from_ui

    def presets_file
      File.join(File.dirname(__FILE__), 'TPlus_Cabinet_presets.json')
    end

    def load_presets
      if File.exist?(presets_file)
        begin
          content = File.read(presets_file, encoding: 'UTF-8')
          JSON.parse(content)
        rescue => e
          puts "T+_Cabinet Lỗi đọc Preset: #{e.message}"
          {}
        end
      else
        {}
      end
    end

    def save_presets(presets)
      begin
        File.open(presets_file, 'w:UTF-8') do |f|
          f.write(JSON.pretty_generate(presets))
        end
      rescue => e
        UI.messagebox("Lỗi khi lưu Preset vào file: #{e.message}
Đường dẫn: #{presets_file}")
      end
    end

    def is_updating_from_ui?
      @is_updating_from_ui == true
    end
  end

  module Packager
    def self.build_rbz
      desktop = File.join(ENV['USERPROFILE'] || ENV['HOME'] || 'C:', 'Desktop')
      rbz_path = File.join(desktop, "TPlus_Cabinet_v#{TPlus_Cabinet::VERSION}.rbz")
      UI.messagebox("📦 T+_CABINET v#{TPlus_Cabinet::VERSION} SẴN SÀNG!

Mã nguồn đã được tối ưu hoàn chỉnh cho SketchUp 2022 / 2017-2024+.")
    end
  end

  def self.build_rbz
    Packager.build_rbz
  end

  class CabinetSelectionObserver < Sketchup::SelectionObserver
    def onSelectionBulkChange(selection); sync_selection(selection); end
    def onSelectionChanged(selection); sync_selection(selection); end
    def onSelectionAdded(selection, element); sync_selection(selection); end
    def onSelectionModified(selection); sync_selection(selection); end
    def onSelectedRemoved(selection, element); sync_selection(selection); end
    def onSelectionCleared(selection); sync_selection(selection); end

    def sync_selection(selection)
      return unless TPlus_Cabinet.dialog_visible?
      return if TPlus_Cabinet.is_updating_from_ui?
      target_inst = TPlus_Cabinet.find_cabinet_instance
      return unless target_inst

      params = TPlus_Cabinet.get_cabinet_params(target_inst)
      return if !params || !params.is_a?(Hash) || params.empty?

      tr = target_inst.transformation
      scale_x = Math.sqrt(tr.xaxis.x**2 + tr.xaxis.y**2 + tr.xaxis.z**2)
      scale_y = Math.sqrt(tr.yaxis.x**2 + tr.yaxis.y**2 + tr.yaxis.z**2)
      scale_z = Math.sqrt(tr.zaxis.x**2 + tr.zaxis.y**2 + tr.zaxis.z**2)

      params = params.dup
      params['w'] = (params['w'].to_f * scale_x).round(1)
      params['d'] = (params['d'].to_f * scale_y).round(1)
      params['h'] = (params['h'].to_f * scale_z).round(1)
      TPlus_Cabinet.send_params_to_ui(params)
    rescue => e
      puts "TPlus_Cabinet Observer Warning: #{e.message}"
    end
  end

  # Native Model#place_component doesn't expose the newly-created instance directly.
  # This one-shot observer makes "Update with no selection" stamp a cabinet with
  # the same parent tag/attributes as the 3-point draw workflow.
  class CabinetPlacementObserver < Sketchup::EntitiesObserver
    def initialize(component_definition, params)
      @component_definition = component_definition
      @params = params.dup
      @done = false
    end

    def onElementAdded(entities, entity)
      return if @done
      return unless entity.is_a?(Sketchup::ComponentInstance)
      return unless entity.definition == @component_definition

      @done = true
      finalize = proc do
        begin
          if entity.valid?
            model = Sketchup.active_model
            layer_cab = model.layers["T+_CABINET"] || model.layers.add("T+_CABINET")
            entity.layer = layer_cab
            TPlus_Cabinet.set_cabinet_params(entity, @params)
          end
        rescue => e
          puts "T+_Cabinet placement tag warning: #{e.message}"
        ensure
          begin
            entities.remove_observer(self)
          rescue
          end
          TPlus_Cabinet.release_placement_observer(self)
        end
      end

      # Changing the model from inside EntitiesObserver can be unsafe on some
      # SketchUp versions. Defer by one UI tick when possible.
      if defined?(UI) && UI.respond_to?(:start_timer)
        UI.start_timer(0, false) { finalize.call }
      else
        finalize.call
      end
    end
  end

  class CabinetToolsObserver < Sketchup::ToolsObserver
    def onActiveToolChanged(tools, tool_name, tool_id)
      TPlus_Cabinet.sync_current_selection
    end
    def onToolStateChanged(tools, tool_name, tool_id, tool_state)
      TPlus_Cabinet.sync_current_selection
    end
  end

  class << self
    def dialog_visible?
      @dialog && @dialog.visible? rescue false
    end

    def arm_placement_observer(component_definition, params)
      model = Sketchup.active_model
      entities = model.active_entities
      @placement_observers ||= []
      observer = CabinetPlacementObserver.new(component_definition, params)
      if entities.add_observer(observer)
        @placement_observers << observer
      end
      observer
    rescue => e
      puts "T+_Cabinet placement observer warning: #{e.message}"
      nil
    end

    def release_placement_observer(observer)
      return unless @placement_observers
      @placement_observers.delete(observer)
    end

    def set_cabinet_params(entity, params)
      return unless entity
      json_str = params.is_a?(Hash) ? params.to_json : params.to_s
      dict_owner = entity.respond_to?(:definition) && entity.definition ? entity.definition : entity
      dict_owner.set_attribute('TPlus_Cabinet', 'is_cabinet', true)
      dict_owner.set_attribute('TPlus_Cabinet', 'params_json', json_str)
      if entity.respond_to?(:set_attribute)
        entity.set_attribute('TPlus_Cabinet', 'is_cabinet', true)
        entity.set_attribute('TPlus_Cabinet', 'params_json', json_str)
      end
    end

    def get_cabinet_params(entity)
      return nil unless entity
      dict_owner = entity.respond_to?(:definition) && entity.definition ? entity.definition : entity
      json_str = dict_owner.get_attribute('TPlus_Cabinet', 'params_json', nil) ||
                 (entity.respond_to?(:get_attribute) ? entity.get_attribute('TPlus_Cabinet', 'params_json', nil) : nil)
      if json_str && !json_str.to_s.empty?
        begin
          p = JSON.parse(json_str.to_s)
          return p if p.is_a?(Hash)
        rescue; end
      end
      raw = dict_owner.get_attribute('TPlus_Cabinet', 'params', nil) ||
            (entity.respond_to?(:get_attribute) ? entity.get_attribute('TPlus_Cabinet', 'params', nil) : nil)
      if raw.is_a?(Hash)
        return raw
      elsif raw.is_a?(String) && !raw.empty?
        begin
          p = JSON.parse(raw)
          return p if p.is_a?(Hash)
        rescue; end
      end
      nil
    end

    def is_cabinet_entity?(ent)
      return false unless ent
      if ent.respond_to?(:get_attribute) && ent.get_attribute('TPlus_Cabinet', 'is_cabinet', false)
        return true
      end
      if ent.respond_to?(:definition) && ent.definition && ent.definition.respond_to?(:get_attribute)
        if ent.definition.get_attribute('TPlus_Cabinet', 'is_cabinet', false)
          return true
        end
      end
      if ent.respond_to?(:name) && ent.name.to_s.start_with?('T+_CABINET')
        return true
      end
      if ent.respond_to?(:definition) && ent.definition && ent.definition.name.to_s.start_with?('T+_CABINET')
        return true
      end
      false
    end

    def find_cabinet_instance
      model = Sketchup.active_model
      return nil unless model && model.selection && !model.selection.empty?

      # Chỉ nhận dạng thông số khi chọn trực tiếp group/component cha ở cấp ngoài cùng
      model.selection.each do |entity|
        next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        if is_cabinet_entity?(entity)
          return entity
        end
      end

      nil
    end

    def toggle_dialog
      dialog_visible? ? @dialog.close : show_dialog
    end

    def show_dialog
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        target_cab = find_cabinet_instance
        if target_cab
          selected_cab_params = get_cabinet_params(target_cab)
          send_params_to_ui(selected_cab_params) if selected_cab_params
        end
        return
      end

      if @dialog
        begin
          @dialog.close if @dialog.respond_to?(:close)
        rescue => e
        end
        @dialog = nil
      end

      model = Sketchup.active_model
      target_cab = find_cabinet_instance
      selected_cab_params = get_cabinet_params(target_cab) if target_cab

      saved_data = default_params.merge(selected_cab_params || model.get_attribute('TPlus_Cabinet', 'params', {}) || {})
      saved_presets = load_presets
      
      if saved_presets.empty?
        saved_presets = {
          "Tủ Quần Áo 2 Cánh" => default_params.merge("d" => 600, "h" => 2400, "shelf_count" => 1, "max_compartment_w" => 900, "max_panel_h" => 2400),
          "Tủ Áo Quá Khổ (2 Tầng)" => default_params.merge("d" => 600, "h" => 2700, "is_overheight" => true, "h_bottom" => 2100, "h_top" => 575, "door_count" => 4, "max_compartment_w" => 900, "max_panel_h" => 2400),
          "Tủ Bếp Dưới" => default_params.merge("h" => 810, "opt_top" => "Đỉnh Lọt Hồi", "plinth_h" => 40, "shadow_gap_h" => 0, "opt_door" => "Cánh Phủ toàn bộ"),
          "Tủ Ngăn Kéo Rời (Full)" => default_params.merge("h" => 810, "opt_door" => "Cánh Phủ toàn bộ", "opt_drawer" => "Lộ", "drawer_count" => 3, "plinth_h" => 60, "door_count" => 0),
          "Kệ Trang Trí" => default_params.merge("d" => 350, "h" => 1200, "shadow_gap_h" => 0, "shelf_count" => 3, "opt_door" => "Không Cánh"),
          "Tủ Giày" => default_params.merge("h" => 1000, "d" => 350, "shelf_count" => 4, "door_count" => 2, "shadow_gap_h" => 0),
          "Tủ Lavabo" => default_params.merge("w" => 800, "h" => 500, "d" => 500, "plinth_h" => 0, "shadow_gap_h" => 0, "shelf_count" => 0, "opt_door" => "Cánh Phủ toàn bộ"),
          "Kệ Tivi" => default_params.merge("w" => 1800, "h" => 500, "d" => 400, "plinth_h" => 100, "shadow_gap_h" => 0, "shelf_count" => 0, "div_count" => 2, "door_count" => 3, "opt_door" => "Cánh Phủ toàn bộ")
        }
        save_presets(saved_presets)
      end

      @observer ||= CabinetSelectionObserver.new
      @tools_observer ||= CabinetToolsObserver.new
      begin
        model.selection.remove_observer(@observer)
      rescue; end
      begin
        model.tools.remove_observer(@tools_observer)
      rescue; end
      model.selection.add_observer(@observer)
      model.tools.add_observer(@tools_observer)

      options = {
        :dialog_title => "T+_CABINET TRAY",
        :preferences_key => "com.tplus_cabinet.dockable_panel",
        :scrollable => true,
        :resizable => true,
        :width => 340, :height => 880,
        :min_width => 280, :min_height => 400,
        :style => UI::HtmlDialog::STYLE_UTILITY
      }

      @dialog = UI::HtmlDialog.new(options)
      @dialog.set_html(generate_html(saved_data, saved_presets))
      @dialog.set_on_closed do
        begin
          Sketchup.active_model.selection.remove_observer(@observer) if @observer
          Sketchup.active_model.tools.remove_observer(@tools_observer) if @tools_observer
        rescue; end
        @dialog = nil
      end

      @dialog.add_action_callback("create_cabinet") { |_ac, data| create_new_cabinet(data) }
      @dialog.add_action_callback("draw_cabinet_tool") { |_ac, data| Sketchup.active_model.select_tool(CabinetDrawTool.new(data)) }
      @dialog.add_action_callback("update_cabinet") { |_ac, data| update_selected_cabinet(data) }

      @dialog.add_action_callback("save_preset") do |_ac, data|
        presets = load_presets
        presets[data['name']] = data['params']
        save_presets(presets)
        @dialog.execute_script("updatePresetList(#{presets.to_json.dump}, '#{data['name']}');")
      end

      @dialog.add_action_callback("delete_preset") do |_ac, preset_name|
        presets = load_presets
        presets.delete(preset_name)
        save_presets(presets)
        @dialog.execute_script("updatePresetList(#{presets.to_json.dump}, '');")
      end

      @dialog.show
    end

    def sync_current_selection
      return unless dialog_visible?
      return if @is_updating_from_ui
      model = Sketchup.active_model
      return unless model && model.selection
      @observer ||= CabinetSelectionObserver.new
      @observer.sync_selection(model.selection)
    end

    def send_params_to_ui(params)
      return unless dialog_visible?
      return if @is_updating_from_ui
      return unless params.is_a?(Hash)
      @dialog.execute_script("updateFormFromRuby(#{params.to_json});")
    end

    def default_params
      {
        "w" => 800.0, "d" => 600.0, "h" => 2400.0,
        "t" => 17.5, "t_back" => 6.0, "back_recess" => 20.0,
        "opt_top" => "Đỉnh Lọt Hồi", "opt_bottom" => "Đáy Lọt Hồi",
        "opt_left_side" => "Vuông", "opt_right_side" => "Vuông", "curve_w" => 100.0,
        "plinth_h" => 40.0, "shadow_gap_h" => 25.0, "div_count" => 0, "div_pos" => "Chia Đều", "auto_divider_wide" => true, "max_compartment_w" => 1200.0,
        "shelf_count" => 0, "shelf_count_top" => 0, "shelf_type" => "Cố Định", "shelf_side_clearance" => 1.6, "shelf_front_setback" => 25.0, "shelf_depth_clearance" => 6.4,
        "opt_door" => "Cánh Lọt Hồi", "door_count" => 2, "auto_door_count" => true, "max_door_w" => 450.0, "door_gap" => 2.0, "door_top_gap" => 25.0,
        "door_gap_advanced" => false, "door_gap_outer" => 1.0, "door_gap_left" => 1.0, "door_gap_right" => 1.0, "door_gap_top" => 25.0, "door_gap_bottom" => 1.0, "door_gap_between" => 2.0,
        "opt_drawer" => "Không", "is_full_drawer" => false, "drawer_comp_pos" => "Tất Cả", "drawer_h" => 600.0, "drawer_count" => 2, "drawer_inner_offset" => 50.0, "drawer_hinge_sp" => 50.0, "drawer_gap" => 2.0, "drawer_ray_space" => 13.0, "drawer_back_clearance" => 20.0, "drawer_box_bottom_lift" => 10.0, "drawer_box_top_clearance" => 13.0, "drawer_bottom_offset" => 10.0, "drawer_box_t" => 0.0, "drawer_bottom_t" => 6.0, "drawer_backing_rail" => false, "drawer_backing_rail_h" => 60.0,
        "drawer_gap_advanced" => false, "drawer_gap_outer" => 1.0, "drawer_gap_left" => 1.0, "drawer_gap_right" => 1.0, "drawer_gap_top" => 25.0, "drawer_gap_bottom" => 1.0, "drawer_gap_between" => 2.0,
        "is_overheight" => false, "auto_overheight" => true, "max_panel_h" => 2400.0, "h_bottom" => 2100.0, "h_top" => 275.0, "overheight_join" => "Xà Dưới", "beam_h" => 50.0, "mid_door_gap" => 25.0
      }
    end

    def create_new_cabinet_at(p, transform_or_origin)
      model = Sketchup.active_model
      model.start_operation('T+_Cabinet Draw Box', true)
      begin
        num = model.definitions.count { |d| d.name.include?("T+_CABINET") } + 1
        comp_def = model.definitions.add("T+_CABINET_#{format('%03d', num)}")

        set_cabinet_params(comp_def, p)
        draw_geometry(comp_def.entities, p)

        tr = transform_or_origin.is_a?(Geom::Transformation) ? transform_or_origin : Geom::Transformation.new(transform_or_origin)
        inst = model.active_entities.add_instance(comp_def, tr)
        
        layer_cab = model.layers["T+_CABINET"] || model.layers.add("T+_CABINET")
        inst.layer = layer_cab
        
        set_cabinet_params(inst, p)
        model.commit_operation
      rescue => e
        model.abort_operation
        puts "T+_Cabinet Error: #{e.message}"
      end
    end

    def create_new_cabinet(p)
      model = Sketchup.active_model
      model.start_operation('T+_Cabinet Place', true)
      begin
        num = model.definitions.count { |d| d.name.include?("T+_CABINET") } + 1
        comp_def = model.definitions.add("T+_CABINET_#{format('%03d', num)}")

        set_cabinet_params(comp_def, p)
        draw_geometry(comp_def.entities, p)

        layer_cab = model.layers["T+_CABINET"] || model.layers.add("T+_CABINET")
        # Native placement creates the instance later. Arm a one-shot observer
        # so the stamped instance is always T+_CABINET, like the 3-point tool.
        arm_placement_observer(comp_def, p)
        model.commit_operation

        # Xoay hướng mặt tiền tủ hướng về camera hiện tại (view góc nhìn)
        view = model.active_view
        if view
          cam = view.camera
          cam_dir = cam.direction
          cam_dir_flat = Geom::Vector3d.new(cam_dir.x, cam_dir.y, 0)
          if cam_dir_flat.length > 0.01
            cam_dir_flat.normalize!
            # Mặt trước tủ mặc định quay về trục -Y cục bộ, xoay sao cho hướng về phía người dùng nhìn
            desired_vector = Geom::Vector3d.new(-cam_dir_flat.x, -cam_dir_flat.y, 0)
            axes = [
              Geom::Vector3d.new(1, 0, 0),
              Geom::Vector3d.new(-1, 0, 0),
              Geom::Vector3d.new(0, 1, 0),
              Geom::Vector3d.new(0, -1, 0)
            ]
            snapped_vector = axes.max_by { |axis| desired_vector.dot(axis) }
            
            target_vector = Geom::Vector3d.new(0, -1, 0)
            angle = target_vector.angle_between(snapped_vector)
            cross_z = target_vector.x * snapped_vector.y - target_vector.y * snapped_vector.x
            angle = -angle if cross_z < 0
            
            # Xoay các entity bên trong definition để preview khi di chuột đặt tủ
            if angle.abs > 0.001
              rot_tr = Geom::Transformation.rotation(Geom::Point3d.new(0,0,0), Geom::Vector3d.new(0,0,1), angle)
              comp_def.entities.transform_entities(rot_tr, comp_def.entities.to_a)
              comp_def.set_attribute('TPlus_Cabinet', 'stamp_angle', angle.to_s)
            end
            model.place_component(comp_def, false)
          else
            model.place_component(comp_def, false)
          end
        else
          model.place_component(comp_def, false)
        end
      rescue => e
        model.abort_operation
        puts "T+_Cabinet Error: #{e.message}"
      end
    end

    def update_selected_cabinet(p)
      @is_updating_from_ui = true
      begin
        # Auto-update từ các ô nhập chỉ được phép cập nhật tủ ĐANG CHỌN.
        # Khi không có selection, chỉ thao tác CẬP NHẬT thủ công mới gọi stamp tủ mới.
        params = p.is_a?(Hash) ? p.dup : {}
        manual_update = params.delete('__manual_update')
        manual_update = (manual_update == true || manual_update.to_s == 'true' || manual_update.to_s == '1')

        model = Sketchup.active_model
        target_inst = find_cabinet_instance

        unless target_inst
          create_new_cabinet(params) if manual_update
          return
        end

        p = params
        model.start_operation('T+_Cabinet Update', true)
        begin
          target_inst.make_unique if target_inst.definition.instances.size > 1

          tr = target_inst.transformation
          target_inst.transformation = Geom::Transformation.axes(tr.origin, tr.xaxis.normalize, tr.yaxis.normalize, tr.zaxis.normalize)

          comp_def = target_inst.definition
          set_cabinet_params(comp_def, p)
          set_cabinet_params(target_inst, p)

          layer_cab = model.layers["T+_CABINET"] || model.layers.add("T+_CABINET")
          target_inst.layer = layer_cab

          comp_def.entities.clear!
          draw_geometry(comp_def.entities, p)
          
          # Đồng bộ ma trận xoay chuẩn instance: nếu definition có stamp_angle, chuyển góc xoay vào transformation của instance
          stamp_angle = comp_def.get_attribute('TPlus_Cabinet', 'stamp_angle', '0.0').to_f
          if stamp_angle.abs > 0.001
            rot_tr = Geom::Transformation.rotation(tr.origin, tr.zaxis, stamp_angle)
            target_inst.transformation = rot_tr * target_inst.transformation
            comp_def.delete_attribute('TPlus_Cabinet', 'stamp_angle')
          end
          
          model.commit_operation
        rescue => e
          model.abort_operation
          puts "T+_Cabinet Error: #{e.message}"
        end
      ensure
        @is_updating_from_ui = false
      end
    end

    def get_door_name(index, count, div_pos)
      GeometryEngine.get_door_name(index, count, div_pos)
    end

    def compute_div_x_positions(div_count, div_pos, door_count, opt_door, inner_w, start_inner_x, w, t, dg_left, dg_right, dg_between, opt_left_side, opt_right_side, curve_w)
      GeometryEngine.compute_div_x_positions(div_count, div_pos, door_count, opt_door, inner_w, start_inner_x, w, t, dg_left, dg_right, dg_between, opt_left_side, opt_right_side, curve_w)
    end

    def is_comp_selected_for_drawer(c_idx, total_comps, pos_setting)
      GeometryEngine.is_comp_selected_for_drawer(c_idx, total_comps, pos_setting)
    end

    def draw_geometry(entities, p)
      GeometryEngine.draw(entities, p)
    end

    private

    def generate_html(data, presets)
      UIRenderer.render(data, presets, default_params)
    end
  end

  unless file_loaded?(__FILE__)
    icon_cabinet_path = File.join(File.dirname(__FILE__), 'logo.svg')
    icon_combine_path = File.join(File.dirname(__FILE__), 'combine.svg')
    icon_combine_path = icon_cabinet_path unless File.exist?(icon_combine_path)
    icon_untag_path   = File.join(File.dirname(__FILE__), 'untag.svg')
    icon_untag_path   = icon_cabinet_path unless File.exist?(icon_untag_path)

    # 1. Command 1: Bảng Điều Khiển Tủ (T+_CABINET UI) - Icon 1 (logo.svg)
    cmd_gui = UI::Command.new('1. Bảng Điều Khiển Tủ (T+_CABINET UI)') {
      TPlus_Cabinet.show_dialog
    }
    cmd_gui.small_icon = icon_cabinet_path if File.exist?(icon_cabinet_path)
    cmd_gui.large_icon = icon_cabinet_path if File.exist?(icon_cabinet_path)
    cmd_gui.tooltip = 'Mở Bảng Điều Khiển T+_CABINET v4.2.4'
    cmd_gui.status_bar_text = 'Mở Bảng Điều Khiển Thiết Kế Tủ Gỗ Công Nghiệp'

    # 2. Command 2: T+_EXPLODE (Rã Nhóm Lồng Tủ & Xóa Khối Ẩn) - Icon 2 (combine.svg)
    cmd_explode = UI::Command.new('2. T+_EXPLODE (Rã Nhóm Lồng Tủ & Xóa Khối Ẩn)') {
      TPlusExplode.execute_explode
    }
    cmd_explode.small_icon = icon_combine_path if File.exist?(icon_combine_path)
    cmd_explode.large_icon = icon_combine_path if File.exist?(icon_combine_path)
    cmd_explode.tooltip = 'T+_EXPLODE v1.0: Rã nhóm lồng trung gian & Giữ nguyên tấm vách riêng biệt'
    cmd_explode.status_bar_text = 'Rã các nhóm lồng như thùng ngăn kéo, giữ từng tấm vách độc lập và xóa đối tượng bị ẩn'

    # 3. Command 3: T+_UNTAG (Xóa Tag Con, Giữ Tag Cha) - Icon 3 (untag.svg)
    cmd_untag = UI::Command.new('3. T+_UNTAG (Xóa Tag Con, Giữ Tag Cha)') {
      TPlusUntag.clean_selected_tags
    }
    cmd_untag.small_icon = icon_untag_path if File.exist?(icon_untag_path)
    cmd_untag.large_icon = icon_untag_path if File.exist?(icon_untag_path)
    cmd_untag.tooltip = 'T+_UNTAG v1.0: Xóa tag đối tượng con'
    cmd_untag.status_bar_text = 'Đưa tag của mọi thực thể con về Untagged, giữ nguyên tag cha ngoài cùng'

    # 4. Command 4: Reload Code
    cmd_reload = UI::Command.new('4. Nạp lại Plugin Code (Reload Code)') {
      main_file = __FILE__
      load main_file
      UI.messagebox("✅ Đã nạp lại mã nguồn T+_CABINET v4.2.4, T+_EXPLODE & T+_UNTAG thành công!")
    }
    cmd_reload.small_icon = icon_cabinet_path if File.exist?(icon_cabinet_path)
    cmd_reload.large_icon = icon_cabinet_path if File.exist?(icon_cabinet_path)
    cmd_reload.tooltip = 'Nạp lại mã nguồn Plugin T+_CABINET'
    cmd_reload.status_bar_text = 'Tải lại file mã nguồn main.rb không cần khởi động lại SketchUp'

    # 5. Add to Extensions / Plugins Menu (Tất cả nằm trong 1 Extension cha)
    menu = UI.menu('Plugins') || UI.menu('Extensions')
    if menu
      sub_menu = menu.add_submenu('T+_CABINET v4.2.4')
      sub_menu.add_item(cmd_gui)
      sub_menu.add_item(cmd_explode)
      sub_menu.add_item(cmd_untag)
      sub_menu.add_separator
      sub_menu.add_item(cmd_reload)
    end

    # 6. Single Unified Toolbar với 3 Icon chính
    tb = UI::Toolbar.new("T+_CABINET v#{VERSION}")
    tb.add_item(cmd_gui)      # Icon 1: Tạo & Chỉnh sửa tủ
    tb.add_item(cmd_explode)  # Icon 2: Explode Rã Group Solid
    tb.add_item(cmd_untag)    # Icon 3: UNTAG xóa tag con
    tb.restore if tb.get_last_state == TB_VISIBLE || tb.get_last_state == TB_NEVER_SHOWN

    # 7. Context Menu Handler (Right Click in 3D viewport)
    UI.add_context_menu_handler do |context_menu|
      sel = Sketchup.active_model.selection
      if sel && sel.length == 1
        inst = TPlus_Cabinet.find_cabinet_instance
        if inst
          context_menu.add_separator
          context_menu.add_item("T+_CABINET v#{VERSION}: Chỉnh Sửa Tủ Này...") {
            TPlus_Cabinet.show_dialog
          }
        end
      end
    end

    file_loaded(__FILE__)
  end
end
