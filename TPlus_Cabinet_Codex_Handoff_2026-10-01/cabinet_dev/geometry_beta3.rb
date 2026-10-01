# frozen_string_literal: true

# T+ CABINET Geometry Engine
# Focus: production-correct carcass geometry. No BOM / labels / cutting-list logic.
module TPlus_Cabinet
  module GeometryEngine
    class << self
      # Shared rule helpers used by both the final geometry engine and the interactive preview.
      # Values are expressed in millimetres so these calculations stay independent from
      # SketchUp's internal inch-based Length class.
      def truthy_param?(p, key, default = false)
        value = p.key?(key) ? p[key] : default
        value == true || value.to_s.strip.downcase == 'true' || value.to_s == '1'
      end

      def effective_door_count_mm(p, w_mm)
        opt_door = p['opt_door'] || 'Không Cánh'
        is_full_drawer = truthy_param?(p, 'is_full_drawer', false)
        return 0 if is_full_drawer || opt_door == 'Không Cánh'

        unless truthy_param?(p, 'auto_door_count', false)
          count = p['door_count'].to_i
          return count > 0 ? count : 2
        end

        t_mm = [1.0, p['t'].to_f].max
        curve_mm = [0.0, p['curve_w'].to_f].max
        curve_mm = [curve_mm, t_mm].max if p['opt_left_side'] == 'Bo Cong' || p['opt_right_side'] == 'Bo Cong'
        max_door_w_mm = p['max_door_w'].to_f
        max_door_w_mm = 450.0 if max_door_w_mm <= 0.1

        left_w = p['opt_left_side'] == 'Bo Cong' ? curve_mm : t_mm
        right_w = p['opt_right_side'] == 'Bo Cong' ? curve_mm : t_mm
        avail_w = w_mm.to_f
        case opt_door
        when 'Cánh Lọt Hồi', 'Cánh Lọt Lòng'
          avail_w -= (left_w + right_w)
        when 'Cánh Phủ Hồi Trái'
          avail_w -= right_w
        when 'Cánh Phủ Hồi Phải'
          avail_w -= left_w
        when 'Cánh Phủ toàn bộ'
          avail_w -= (p['opt_left_side'] == 'Bo Cong' ? curve_mm : 0.0)
          avail_w -= (p['opt_right_side'] == 'Bo Cong' ? curve_mm : 0.0)
        end
        avail_w = [1.0, avail_w].max
        [1, (avail_w / max_door_w_mm).ceil].max
      end

      def required_divider_count_mm(p, w_mm)
        return 0 unless truthy_param?(p, 'auto_divider_wide', true)

        t_mm = [1.0, p['t'].to_f].max
        curve_mm = [0.0, p['curve_w'].to_f].max
        curve_mm = [curve_mm, t_mm].max if p['opt_left_side'] == 'Bo Cong' || p['opt_right_side'] == 'Bo Cong'
        left_w = p['opt_left_side'] == 'Bo Cong' ? curve_mm : t_mm
        right_w = p['opt_right_side'] == 'Bo Cong' ? curve_mm : t_mm
        inner_w = [1.0, w_mm.to_f - left_w - right_w].max
        max_compartment_w = p['max_compartment_w'].to_f
        max_compartment_w = 1200.0 if max_compartment_w <= 0.0

        count = 0
        while count < 20
          clear_w = (inner_w - count * t_mm) / (count + 1).to_f
          break if clear_w <= max_compartment_w
          count += 1
        end
        count
      end

      def effective_divider_count_mm(p, w_mm)
        door_count = effective_door_count_mm(p, w_mm)
        div_count = [0, p['div_count'].to_i].max

        if truthy_param?(p, 'auto_door_count', false) && door_count > 0
          div_count = door_count <= 2 ? 0 : ((door_count - 1) / 2.0).floor
        elsif (door_count == 3 || door_count == 4) && div_count == 0
          div_count = 1
        end

        [div_count, required_divider_count_mm(p, w_mm)].max
      end

      def resolve_overheight_mm(p, h_mm)
        h_mm = [10.0, h_mm.to_f].max
        t_mm = [1.0, p['t'].to_f].max
        max_panel_h = p['max_panel_h'].to_f
        max_panel_h = 2400.0 if max_panel_h <= 0.0
        auto_overheight = truthy_param?(p, 'auto_overheight', true)
        requested = truthy_param?(p, 'is_overheight', false)
        is_overheight = requested || (auto_overheight && h_mm > max_panel_h)
        return { :is_overheight => false, :h_bottom => nil } unless is_overheight

        top_is_lot = (p['opt_top'] == 'Đỉnh Lọt Hồi')
        bot_is_lot = (p['opt_bottom'] == 'Đáy Lọt Hồi')
        shadow_gap_h = top_is_lot ? [0.0, p['shadow_gap_h'].to_f].max : 0.0
        plinth_h = [0.0, p['plinth_h'].to_f].max
        join_type = p['overheight_join'] || 'Xà Dưới'
        z_top_cabinet = [0.0, h_mm - shadow_gap_h].max

        h_bottom = p['h_bottom'].to_f
        h_bottom = [2100.0, max_panel_h].min if h_bottom <= 0.0
        min_module_h = [100.0, (t_mm * 2.0) + 20.0].max

        if z_top_cabinet > min_module_h * 2.0
          lower_min = min_module_h
          lower_max = z_top_cabinet - min_module_h

          if auto_overheight
            lower_has_top = (join_type != 'Xà Dưới')
            upper_has_bottom = (join_type != 'Xà Trên')
            lower_side_start = bot_is_lot ? 0.0 : (plinth_h + t_mm)
            lower_end_adjust = (lower_has_top && !top_is_lot) ? t_mm : 0.0
            upper_start_adjust = (upper_has_bottom && !bot_is_lot) ? t_mm : 0.0
            upper_side_end = top_is_lot ? h_mm : (z_top_cabinet - t_mm)

            sheet_lower_min = upper_side_end - upper_start_adjust - max_panel_h
            sheet_lower_max = max_panel_h + lower_side_start + lower_end_adjust
            candidate_min = [lower_min, sheet_lower_min].max
            candidate_max = [lower_max, sheet_lower_max].min
            if candidate_max >= candidate_min
              lower_min = candidate_min
              lower_max = candidate_max
            end
          end

          h_bottom = [[h_bottom, lower_min].max, lower_max].min if lower_max >= lower_min
        else
          h_bottom = z_top_cabinet / 2.0
        end

        { :is_overheight => true, :h_bottom => h_bottom }
      end

      def get_door_name(index, count, div_pos)
        if count == 1
          "Cánh Trái"
        elsif count.even?
          index.even? ? "Cánh Trái" : "Cánh Phải"
        else
          if div_pos == 'Bên Trái'
            index == 0 ? "Cánh Trái" : (index.odd? ? "Cánh Trái" : "Cánh Phải")
          else
            index == count - 1 ? "Cánh Phải" : (index.even? ? "Cánh Trái" : "Cánh Phải")
          end
        end
      end
      
      def compute_div_x_positions(div_count, div_pos, door_count, opt_door, inner_w, start_inner_x, w, t, dg_left, dg_right, dg_between, opt_left_side, opt_right_side, curve_w)
        div_x_positions = []
        if opt_door != "Không Cánh" && door_count > 0
          left_door_inset = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Trái"].include?(opt_door) ? ((opt_left_side == "Bo Cong") ? curve_w : 0.mm) : start_inner_x
          right_door_inset = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Phải"].include?(opt_door) ? ((opt_right_side == "Bo Cong") ? curve_w : 0.mm) : (w - inner_w - start_inner_x)
          door_w_total = w - left_door_inset - right_door_inset
          start_door_x = left_door_inset + dg_left
          single_door_w = (door_w_total - dg_left - dg_right - (dg_between * (door_count - 1))) / door_count.to_f
          
          gap_centers = []
          (1...door_count).each { |i| gap_centers << start_door_x + i * single_door_w + (i - 0.5) * dg_between }
          
          if div_count > 0 && div_count < door_count
            c = div_count + 1
            d = door_count
            arr = []
            if c * 2 >= d && d >= c
              arr = Array.new(c, 2)
              diff = c * 2 - d
              if diff > 0
                if div_pos == "Bên Trái"; (0...diff).each { |i| arr[i] = 1 }
                elsif div_pos == "Bên Phải"; (0...diff).each { |i| arr[c - 1 - i] = 1 }
                else start_idx = (c - diff) / 2; (0...diff).each { |i| arr[start_idx + i] = 1 }; end
              end
            else
              arr = Array.new(c, d / c)
              rem = d % c
              if rem > 0
                if div_pos == "Bên Trái"; (0...rem).each { |i| arr[c - 1 - i] += 1 }
                elsif div_pos == "Bên Phải"; (0...rem).each { |i| arr[i] += 1 }
                else start_idx = (c - rem) / 2; (0...rem).each { |i| arr[start_idx + i] += 1 }; end
              end
            end
            
            curr_doors = 0
            (0...div_count).each do |i|
              curr_doors += arr[i]
              idx = curr_doors - 1
              div_x_positions << gap_centers[idx] - t / 2.0 if idx >= 0 && idx < gap_centers.length
            end
          end
        end
        
        if div_x_positions.empty? && div_count > 0
          if div_count == 1
            avail = inner_w - t
            if div_pos == "Bên Trái"; div_x_positions << start_inner_x + (avail * (1.0 / 3.0))
            elsif div_pos == "Bên Phải"; div_x_positions << start_inner_x + (avail * (2.0 / 3.0))
            else div_x_positions << start_inner_x + (avail * 0.5); end
          elsif div_count > 1
            comp = (inner_w - (div_count * t)) / (div_count + 1).to_f
            (1..div_count).each { |i| div_x_positions << start_inner_x + (comp * i) + (t * (i - 1)) }
          end
        end
        div_x_positions
      end
      
      def is_comp_selected_for_drawer(c_idx, total_comps, pos_setting)
        return true if pos_setting.nil? || pos_setting == 'Tất Cả' || total_comps <= 1
        if pos_setting == 'Trái'
          c_idx == 0
        elsif pos_setting == 'Phải'
          c_idx == total_comps - 1
        elsif pos_setting == 'Giữa'
          return c_idx == 0 if total_comps == 2
          c_idx > 0 && c_idx < total_comps - 1
        else
          true
        end
      end
      
      def draw(entities, p)
        w = [5000.mm, [10.mm, p['w'].to_f.mm].max].min
        d_input = [5000.mm, [10.mm, p['d'].to_f.mm].max].min
        h = [5000.mm, [10.mm, p['h'].to_f.mm].max].min
        t = [1.mm, p['t'].to_f.mm].max
        t_back = p['back_mode'] == 'Không' ? 0.mm : [0.mm, p['t_back'].to_f.mm].max
        back_overlay = p['back_mode'] == 'Phủ'
        back_recess = [0.mm, p['back_recess'].to_f.mm].max
        opt_left_side = p['opt_left_side'] || 'Vuông'
        opt_right_side = p['opt_right_side'] || 'Vuông'
        curve_w = [0.mm, p['curve_w'].to_f.mm].max
        curve_w = [curve_w, t].max if opt_left_side == 'Bo Cong' || opt_right_side == 'Bo Cong'
        plinth_h = [0.mm, p['plinth_h'].to_f.mm].max
        shadow_gap_h = [0.mm, p['shadow_gap_h'].to_f.mm].max
        div_count = [0, p['div_count'].to_i].max; shelf_count = [0, p['shelf_count'].to_i].max
        shelf_count_top = p['shelf_count_top'] ? [0, p['shelf_count_top'].to_i].max : 0
        shelf_type = p['shelf_type'] || 'Cố Định'
        shelf_adjustable = (shelf_type == 'Di Động')
        shelf_side_clearance = [0.mm, (p['shelf_side_clearance'] ? p['shelf_side_clearance'].to_f.mm : 1.6.mm)].max
        # Đợt di động: T+ mặc định lùi mép trước 25 mm để tránh bản lề/cánh.
        # Giữ fallback shelf_depth_clearance để đọc được tủ/preset cũ v4.2.0.
        shelf_front_setback = if p.key?('shelf_front_setback')
                                [0.mm, p['shelf_front_setback'].to_f.mm].max
                              elsif p.key?('shelf_depth_clearance')
                                [0.mm, p['shelf_depth_clearance'].to_f.mm].max
                              else
                                25.mm
                              end
        div_pos = p['div_pos'] || 'Chia Đều'
      
        opt_door = p['opt_door']
        auto_door = p['auto_door_count'] == true || p['auto_door_count'].to_s == 'true'
        max_door_w = (p['max_door_w'] || 450.0).to_f.mm
        max_door_w = 450.0.mm if max_door_w <= 0.1.mm
      
        opt_drawer = p['opt_drawer'] || 'Không'
        is_full_drawer = p['is_full_drawer'] == true || p['is_full_drawer'].to_s == 'true'
        drawer_comp_pos = p['drawer_comp_pos'] || 'Tất Cả'
        drawer_h_param = is_full_drawer ? 10000.mm : (p['drawer_h'] ? p['drawer_h'].to_f.mm : 600.mm)
        drawer_count_val = [[1, (p['drawer_count'] ? p['drawer_count'].to_i : 3)].max, 20].min
        drawer_inner_offset = (p['drawer_inner_offset'] ? p['drawer_inner_offset'].to_f.mm : 50.mm)
        drawer_hinge_sp = [0.mm, (p['drawer_hinge_sp'] ? p['drawer_hinge_sp'].to_f.mm : 50.mm)].max
        drawer_gap = (p['drawer_gap'] ? p['drawer_gap'].to_f.mm : 25.mm)
        drawer_ray_space = [0.mm, (p['drawer_ray_space'] ? p['drawer_ray_space'].to_f.mm : 13.mm)].max
        # Khoảng hở phía sau thùng ngăn kéo. Không hard-code theo một hệ ray cụ thể:
        # ray âm / ray bi / tandem có yêu cầu chiều sâu khác nhau.
        drawer_back_clearance = [0.mm, (p['drawer_back_clearance'] ? p['drawer_back_clearance'].to_f.mm : 20.mm)].max
        # Đáy ngăn kéo được nâng khỏi mép dưới vách để mô phỏng cấu tạo đáy âm/rãnh.
        drawer_bottom_offset = [0.mm, (p['drawer_bottom_offset'] ? p['drawer_bottom_offset'].to_f.mm : 10.mm)].max
        # Vertical envelope of the drawer box relative to its front/opening. Defaults are close
        # to common concealed-runner requirements, but remain adjustable because hardware varies.
        drawer_box_bottom_lift = [0.mm, (p['drawer_box_bottom_lift'] ? p['drawer_box_bottom_lift'].to_f.mm : 10.mm)].max
        drawer_box_top_clearance = [0.mm, (p['drawer_box_top_clearance'] ? p['drawer_box_top_clearance'].to_f.mm : 13.mm)].max
        drawer_box_t_raw = p['drawer_box_t'] ? p['drawer_box_t'].to_f : 0.0
        drawer_box_t = drawer_box_t_raw > 0.0 ? drawer_box_t_raw.mm : t
        drawer_bottom_t = [1.mm, (p['drawer_bottom_t'] ? p['drawer_bottom_t'].to_f.mm : 6.mm)].max
        # Xà che/chặn khe giữa các mặt ngăn kéo: dùng khi có khe tay móc âm 45°
        # hoặc bất kỳ cấu tạo nào cần nền che phía sau khe. Không ép bật cho mọi drawer.
        drawer_backing_rail = truthy_param?(p, 'drawer_backing_rail', false)
        drawer_backing_rail_h = [t, (p['drawer_backing_rail_h'] ? p['drawer_backing_rail_h'].to_f.mm : 60.mm)].max
      
        if is_full_drawer || opt_door == "Không Cánh"
          door_count = 0
        elsif auto_door
          left_w = (opt_left_side == "Bo Cong") ? curve_w : t
          right_w = (opt_right_side == "Bo Cong") ? curve_w : t
          avail_w = w
          if opt_door == "Cánh Lọt Hồi" || opt_door == "Cánh Lọt Lòng"
            avail_w = [1.mm, w - left_w - right_w].max
          elsif opt_door == "Cánh Phủ Hồi Trái"
            avail_w = [1.mm, w - right_w].max
          elsif opt_door == "Cánh Phủ Hồi Phải"
            avail_w = [1.mm, w - left_w].max
          elsif opt_door == "Cánh Phủ toàn bộ"
            inset_l = (opt_left_side == "Bo Cong") ? curve_w : 0.mm
            inset_r = (opt_right_side == "Bo Cong") ? curve_w : 0.mm
            avail_w = [1.mm, w - inset_l - inset_r].max
          end
          door_count = [1, (avail_w / max_door_w).ceil].max
          div_count = door_count <= 2 ? 0 : ((door_count - 1) / 2.0).floor
        elsif opt_door == "Không Cánh"
          door_count = 0
        else
          door_count = p['door_count'].to_i
          door_count = 2 if door_count <= 0
        end
        gap = p['door_gap'].to_f.mm
      
        door_gap_advanced = p['door_gap_advanced'] == true || p['door_gap_advanced'].to_s == 'true'
        if door_gap_advanced
          dg_left = p['door_gap_left'].to_f.mm
          dg_right = p['door_gap_right'].to_f.mm
          dg_top = p['door_gap_top'].to_f.mm
          dg_bottom = p['door_gap_bottom'].to_f.mm
          dg_between = p['door_gap_between'].to_f.mm
        else
          dg_outer = p['door_gap_outer'].to_f.mm
          dg_left = dg_outer
          dg_right = dg_outer
          dg_top = (p['door_top_gap'] || dg_outer.to_f * 25.4).to_f.mm
          dg_bottom = dg_outer
          dg_between = gap
        end
      
        drawer_gap_advanced = p['drawer_gap_advanced'] == true || p['drawer_gap_advanced'].to_s == 'true'
        if drawer_gap_advanced
          drg_left = p['drawer_gap_left'].to_f.mm
          drg_right = p['drawer_gap_right'].to_f.mm
          drg_top = p['drawer_gap_top'].to_f.mm
          drg_bottom = p['drawer_gap_bottom'].to_f.mm
          drg_between = p['drawer_gap_between'].to_f.mm
        else
          drg_outer = p['drawer_gap_outer'].to_f.mm
          drg_left = drg_outer
          drg_right = drg_outer
          drg_top = drg_outer
          drg_bottom = drg_outer
          drg_between = drawer_gap
        end
      
        # Quy tắc chiều cao được giải bằng cùng một helper với Draw Tool để preview và geometry không lệch nhau.
        overheight_rule = resolve_overheight_mm(p, h.to_f * 25.4)
        is_overheight = overheight_rule[:is_overheight]
        auto_overheight = truthy_param?(p, 'auto_overheight', true)
        max_panel_h = [(p['max_panel_h'] || 2400.0).to_f.mm, 1.mm].max

        required_dividers = required_divider_count_mm(p, w.to_f * 25.4)
        div_count = [div_count, required_dividers].max
      
        join_type = p['overheight_join'] || 'Xà Dưới'
        mid_door_gap = (p['mid_door_gap'] || 25.0).to_f.mm
        door_top_gap = (p['door_top_gap'] || p['mid_door_gap'] || 25.0).to_f.mm
        beam_h = p['beam_h'] ? p['beam_h'].to_f.mm : (mid_door_gap + 25.0.mm)
      
        if door_count == 3 && div_count == 0
          div_count = 1; div_pos = 'Bên Trái' if div_pos == 'Chia Đều'
        elsif door_count == 4 && div_count == 0
          div_count = 1; div_pos = 'Chia Đều'
        end
      
        is_phu = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Trái", "Cánh Phủ Hồi Phải"].include?(opt_door) || (opt_door == "Không Cánh" && (opt_drawer == "Lộ" || is_full_drawer))
        door_t = Modeling.door_depth_mm(p).mm
        d_cabinet = (is_phu ? (d_input - door_t) : d_input) - (back_overlay ? t_back : 0.mm)
      
        case opt_door
        when "Cánh Lọt Hồi"
          y_side = 0.mm; d_side = d_cabinet
          y_top_bot = door_t; d_top_bot = d_cabinet - door_t; y_inner = door_t
        when "Cánh Lọt Lòng"
          y_side = 0.mm; d_side = d_cabinet
          y_top_bot = 0.mm; d_top_bot = d_cabinet; y_inner = door_t
        else
          y_side = 0.mm; d_side = d_cabinet
          y_top_bot = 0.mm; d_top_bot = d_cabinet; y_inner = 0.mm
        end
      
        y_side_left = y_side
        d_side_left = d_side
        y_side_right = y_side
        d_side_right = d_side
      
        if ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Trái"].include?(opt_door)
          if opt_left_side == 'Bo Cong'
            y_side_left = -door_t
            d_side_left = d_side + door_t
          end
        elsif opt_door == "Cánh Phủ Hồi Phải"
          y_side_left = -door_t
          d_side_left = d_side + door_t
        end
      
        if ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Phải"].include?(opt_door)
          if opt_right_side == 'Bo Cong'
            y_side_right = -door_t
            d_side_right = d_side + door_t
          end
        elsif opt_door == "Cánh Phủ Hồi Trái"
          y_side_right = -door_t
          d_side_right = d_side + door_t
        end
      
        back_space = (t_back > 0 && !back_overlay ? (back_recess + t_back) : 0.mm)
        d_inner = d_cabinet - y_inner - back_space
        left_w = (opt_left_side == 'Bo Cong') ? curve_w : t
        right_w = (opt_right_side == 'Bo Cong') ? curve_w : t
      
        top_is_lot = (p['opt_top'] == "Đỉnh Lọt Hồi")
        bot_is_lot = (p['opt_bottom'] == "Đáy Lọt Hồi")
        shadow_gap_h = 0.mm unless top_is_lot
      
        top_w = top_is_lot ? (w - left_w - right_w) : w
        start_top_x = top_is_lot ? left_w : 0.mm
        bot_w = bot_is_lot ? (w - left_w - right_w) : w
        start_bot_x = bot_is_lot ? left_w : 0.mm
        inner_w = w - left_w - right_w; start_inner_x = left_w
      
        create_curved_board = ->(name, w_block, d_block, h_block, x, y, z, r_block, is_left) {
          r_block = [r_block, d_block, w_block].min
          return nil if w_block < 0.001.inch || d_block < 0.001.inch || h_block < 0.001.inch
          group = entities.add_group
          group.name = name
          begin
            pts = []
            num_segments = 24
            if is_left
              pts << Geom::Point3d.new(w_block, d_block, 0.mm)
              pts << Geom::Point3d.new(w_block, 0.mm, 0.mm)
              
              center_x = r_block
              center_y = r_block
              (0..num_segments).each do |i|
                angle = (Math::PI * 1.5) - (Math::PI / 2.0) * (i.to_f / num_segments)
                pts << Geom::Point3d.new(center_x + r_block * Math.cos(angle), center_y + r_block * Math.sin(angle), 0.mm)
              end
              pts << Geom::Point3d.new(0.mm, d_block, 0.mm)
            else
              pts << Geom::Point3d.new(0.mm, d_block, 0.mm)
              pts << Geom::Point3d.new(w_block, d_block, 0.mm)
              
              center_x = w_block - r_block
              center_y = r_block
              (0..num_segments).each do |i|
                angle = 0.0 - (Math::PI / 2.0) * (i.to_f / num_segments)
                pts << Geom::Point3d.new(center_x + r_block * Math.cos(angle), center_y + r_block * Math.sin(angle), 0.mm)
              end
              pts << Geom::Point3d.new(0.mm, 0.mm, 0.mm)
            end
            
            pts.uniq! { |pt| [pt.x.round(6), pt.y.round(6), pt.z.round(6)] }
            f = group.entities.add_face(pts)
            if f
              f.reverse! if f.normal.z < 0
              f.pushpull(h_block)
              
              # Check if it went downwards (Z < 0)
              min_z = group.entities.grep(Sketchup::Face).map { |face| face.vertices.map { |v| v.position.z } }.flatten.min
              if min_z < -0.001.inch
                group.entities.transform_entities(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -min_z)), group.entities.to_a)
              end
              
              group.entities.grep(Sketchup::Edge).each do |edge|
                if edge.start.position.x == edge.end.position.x && edge.start.position.y == edge.end.position.y
                  px = edge.start.position.x
                  py = edge.start.position.y
                  is_start_tangent = (px - (is_left ? r_block : (w_block - r_block))).abs < 0.001.inch && py < 0.001.inch
                  is_end_tangent = (px - (is_left ? 0.mm : w_block)).abs < 0.001.inch && (py - r_block).abs < 0.001.inch
                  
                  in_curve = if is_left
                               px < r_block - 0.001.inch && py < r_block - 0.001.inch
                             else
                               px > w_block - r_block - 0.001.inch && py < r_block - 0.001.inch
                             end
                  
                  if in_curve && !is_start_tangent && !is_end_tangent
                    edge.soft = true
                    edge.smooth = true
                  end
                end
              end
            end
            group.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x, y, z)))
            return group
          rescue
            group.erase! if group.valid?
            return nil
          end
        }
      
        create_board = ->(name, dx, dy, dz, x, y, z, align=:left, is_door=false) {
          raise ModelingRules::Invalid, "Tấm #{name} có kích thước không hợp lệ." if dx < 0.001.inch || dy < 0.001.inch || dz < 0.001.inch
          
          if is_door
            outer_group = entities.add_group
            board_group = outer_group.entities.add_group
            board_group.name = name
            begin
              face_x = (align == :right) ? -dx : 0.mm
              Modeling.door_front(board_group.entities, face_x, dx, dy, dz, p)
              
              layer_guide = Sketchup.active_model.layers["T+_KY HIEU"] || Sketchup.active_model.layers.add("T+_KY HIEU")
              if name.include?("Trái")
                c1 = board_group.entities.add_cline(Geom::Point3d.new([face_x + dx, 0.mm, dz]), Geom::Point3d.new([face_x, 0.mm, dz / 2.0]))
                c2 = board_group.entities.add_cline(Geom::Point3d.new([face_x + dx, 0.mm, 0.mm]), Geom::Point3d.new([face_x, 0.mm, dz / 2.0]))
              elsif name.include?("Phải")
                c1 = board_group.entities.add_cline(Geom::Point3d.new([face_x, 0.mm, dz]), Geom::Point3d.new([face_x + dx, 0.mm, dz / 2.0]))
                c2 = board_group.entities.add_cline(Geom::Point3d.new([face_x, 0.mm, 0.mm]), Geom::Point3d.new([face_x + dx, 0.mm, dz / 2.0]))
              else
                c1 = board_group.entities.add_cline(Geom::Point3d.new([face_x + dx, 0.mm, dz]), Geom::Point3d.new([face_x, 0.mm, dz / 2.0]))
                c2 = board_group.entities.add_cline(Geom::Point3d.new([face_x + dx, 0.mm, 0.mm]), Geom::Point3d.new([face_x, 0.mm, dz / 2.0]))
              end
              c1.layer = layer_guide; c2.layer = layer_guide
      
              inst = outer_group.to_component
              inst.definition.name = name + "_DC"
              
              layer_door = Sketchup.active_model.layers["T+_CANH"] || Sketchup.active_model.layers.add("T+_CANH")
              inst.layer = layer_door
      
              pos_x = (align == :right) ? (x + dx) : x
              inst.transform!(Geom::Transformation.translation(Geom::Vector3d.new(pos_x, y, z)))
              return inst
            rescue
              outer_group.erase! if outer_group.valid?
              raise
            end
          else
            board_group = entities.add_group; board_group.name = name
            begin
              face_x = (align == :right) ? -dx : 0.mm
              pts = [[face_x, 0.mm, 0.mm], [face_x + dx, 0.mm, 0.mm], [face_x + dx, dy, 0.mm], [face_x, dy, 0.mm]]
              f = board_group.entities.add_face(pts)
              if f
                f.reverse! if f.normal.z < 0
                f.pushpull(dz)
              end
              
              pos_x = (align == :right) ? (x + dx) : x
              board_group.transform!(Geom::Transformation.translation(Geom::Vector3d.new(pos_x, y, z)))
              return board_group
            rescue
              board_group.erase! if board_group.valid?
              return nil
            end
          end
        }
      
        # Helper chia hậu chuẩn theo vị trí tâm hồi giữa (che khuất điểm nối sau hồi)
              create_yz_board = ->(name, dx, x, y, z, pts_yz, align=:left) {
          board_group = entities.add_group; board_group.name = name
          begin
            face_x = (align == :right) ? -dx : 0.mm
            pts3d = pts_yz.map { |py, pz| [face_x, py, pz] }
            f = board_group.entities.add_face(pts3d)
            if f
              f.reverse! if f.normal.x < 0
              f.pushpull(dx)
            end
            pos_x = (align == :right) ? (x + dx) : x
            board_group.transform!(Geom::Transformation.translation(Geom::Vector3d.new(pos_x, y, z)))
            return board_group
          rescue
            board_group.erase! if board_group.valid?
            return nil
          end
        }
      
        create_back_boards = ->(start_x, z_start, z_h, div_x_positions_arr) {
          if back_overlay
            low = z_start <= plinth_h + t + 0.01.mm ? 0.mm : z_start - t
            high = z_start + z_h
            high = h if (high - (h-shadow_gap_h-t)).abs < 0.01.mm
            create_board.call("Tấm Hậu Phủ", w, t_back, high-low, 0.mm, d_cabinet, low)
            next
          end
          if div_x_positions_arr && !div_x_positions_arr.empty?
            # Sắp xếp các tọa độ hồi giữa theo thứ tự từ trái qua phải
            sorted_divs = div_x_positions_arr.sort
            x_cursor = start_x
            
            sorted_divs.each_with_index do |div_x, idx|
              # Tâm của hồi giữa nằm tại div_x + t/2.0
              center_of_div = div_x + (t / 2.0)
              segment_width = center_of_div - x_cursor
              if segment_width > 0.001.inch
                create_board.call("Tấm Hậu Khoang #{idx + 1}", segment_width, t_back, z_h, x_cursor, d_cabinet - back_recess - t_back, z_start)
              end
              x_cursor = center_of_div
            end
            # Khoang cuối cùng bên phải
            right_width = (start_x + inner_w) - x_cursor
            if right_width > 0.001.inch
              create_board.call("Tấm Hậu Khoang Cuối", right_width, t_back, z_h, x_cursor, d_cabinet - back_recess - t_back, z_start)
            end
          else
            # Không tự tạo mối nối hậu lộ thiên khi không có hồi giữa. Nếu cần chia hậu,
            # người dựng nên tạo hồi giữa để đường nối được đỡ/che đúng kết cấu.
            create_board.call("Tấm Hậu", inner_w, t_back, z_h, start_x, d_cabinet - back_recess - t_back, z_start)
          end
        }
      
        create_top_curved_board = ->(name, w_block, d_block, h_block, x, y, z, r_l, r_r) {
          r_l = [r_l, d_block, w_block].min
          r_r = [r_r, d_block, w_block].min
          return nil if w_block < 0.001.inch || d_block < 0.001.inch || h_block < 0.001.inch
          group = entities.add_group
          group.name = name
          begin
            pts = []
            num_segments = 24
      
            pts << Geom::Point3d.new(0.mm, d_block, 0.mm)
            pts << Geom::Point3d.new(w_block, d_block, 0.mm)
      
            if r_r > 0.001.inch
              center_x = w_block - r_r
              center_y = r_r
              (0..num_segments).each do |i|
                angle = 0.0 - (Math::PI / 2.0) * (i.to_f / num_segments)
                pts << Geom::Point3d.new(center_x + r_r * Math.cos(angle), center_y + r_r * Math.sin(angle), 0.mm)
              end
            else
              pts << Geom::Point3d.new(w_block, 0.mm, 0.mm)
            end
      
            if r_l > 0.001.inch
              center_x = r_l
              center_y = r_l
              (0..num_segments).each do |i|
                angle = (Math::PI * 1.5) - (Math::PI / 2.0) * (i.to_f / num_segments)
                pts << Geom::Point3d.new(center_x + r_l * Math.cos(angle), center_y + r_l * Math.sin(angle), 0.mm)
              end
            else
              pts << Geom::Point3d.new(0.mm, 0.mm, 0.mm)
            end
      
            pts.uniq! { |pt| [pt.x.round(6), pt.y.round(6), pt.z.round(6)] }
            f = group.entities.add_face(pts)
            if f
              f.reverse! if f.normal.z < 0
              f.pushpull(h_block)
      
              min_z = group.entities.grep(Sketchup::Face).map { |face| face.vertices.map { |v| v.position.z } }.flatten.min
              if min_z < -0.001.inch
                group.entities.transform_entities(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -min_z)), group.entities.to_a)
              end
      
              group.entities.grep(Sketchup::Edge).each do |edge|
                if edge.start.position.x == edge.end.position.x && edge.start.position.y == edge.end.position.y
                  px = edge.start.position.x
                  py = edge.start.position.y
      
                  in_left_curve = (r_l > 0.001.inch) && (px < r_l - 0.001.inch) && (py < r_l - 0.001.inch)
                  in_right_curve = (r_r > 0.001.inch) && (px > w_block - r_r + 0.001.inch) && (py < r_r - 0.001.inch)
      
                  is_tangent = false
                  if r_l > 0.001.inch
                    is_tangent ||= (px - r_l).abs < 0.001.inch && py < 0.001.inch
                    is_tangent ||= px < 0.001.inch && (py - r_l).abs < 0.001.inch
                  end
                  if r_r > 0.001.inch
                    is_tangent ||= (px - (w_block - r_r)).abs < 0.001.inch && py < 0.001.inch
                    is_tangent ||= (px - w_block).abs < 0.001.inch && (py - r_r).abs < 0.001.inch
                  end
      
                  if (in_left_curve || in_right_curve) && !is_tangent
                    edge.soft = true
                    edge.smooth = true
                  end
                end
              end
            end
            group.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x, y, z)))
            return group
          rescue
            group.erase! if group.valid?
            return nil
          end
        }
      
        # Horizontal carcass panel helper. Cover panels follow the rounded side outline
        # instead of leaving a square front corner outside a curved end panel. Inset panels
        # remain rectangular because they sit between the side panels.
        create_horizontal_panel = ->(name, is_inset, panel_w, start_x, panel_d, panel_y, z_pos) {
          if is_inset
            create_board.call(name, panel_w, panel_d, t, start_x, panel_y, z_pos)
          else
            r_left = (opt_left_side == 'Bo Cong') ? curve_w : 0.mm
            r_right = (opt_right_side == 'Bo Cong') ? curve_w : 0.mm
            if r_left > 0.001.inch || r_right > 0.001.inch
              create_top_curved_board.call(name, w, panel_d, t, 0.mm, panel_y, z_pos, r_left, r_right)
            else
              create_board.call(name, w, panel_d, t, 0.mm, panel_y, z_pos)
            end
          end
        }

        create_top_board = ->(name, z_pos) {
          if top_is_lot
            create_board.call(name, top_w, d_top_bot, t, start_top_x, y_top_bot, z_pos)
          else
            has_overlay_door = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Trái", "Cánh Phủ Hồi Phải"].include?(opt_door) ||
                               (opt_door == "Không Cánh" && (opt_drawer == "Lộ" || is_full_drawer))
            cur_top_y = has_overlay_door ? -door_t : 0.mm
            cur_top_d = has_overlay_door ? (d_cabinet + door_t) : d_cabinet
      
            r_left = (opt_left_side == 'Bo Cong') ? curve_w : 0.mm
            r_right = (opt_right_side == 'Bo Cong') ? curve_w : 0.mm
      
            if r_left > 0.001.inch || r_right > 0.001.inch
              create_top_curved_board.call(name, w, cur_top_d, t, 0.mm, cur_top_y, z_pos, r_left, r_right)
            else
              create_board.call(name, w, cur_top_d, t, 0.mm, cur_top_y, z_pos)
            end
          end
        }
      
        div_x_positions = compute_div_x_positions(div_count, div_pos, door_count, opt_door, inner_w, start_inner_x, w, t, dg_left, dg_right, dg_between, opt_left_side, opt_right_side, curve_w)
      
        if is_overheight
          h_bot_val = overheight_rule[:h_bottom].to_f.mm
          z_top_cabinet = h - shadow_gap_h
          h_bottom = h_bot_val
          z_junction = h_bot_val
          z_bot = plinth_h
          z_top = z_top_cabinet - t
      
          side_bot_z_start = bot_is_lot ? 0.mm : (plinth_h + t)
          lower_has_top = (join_type != 'Xà Dưới')
          # Tấm nóc phủ hồi chiếm chiều dày tại mối nối; hồi dưới phải dừng dưới tấm nóc.
          side_bot_z_end = (lower_has_top && !top_is_lot) ? (z_junction - t) : z_junction
          side_bot_dz = [0.001.inch, side_bot_z_end - side_bot_z_start].max
      
          if opt_left_side == 'Bo Cong'
            create_curved_board.call("Hồi Trái Dưới Bo Cong", curve_w, d_side_left, side_bot_dz, 0.mm, y_side_left, side_bot_z_start, curve_w, true)
          else
            create_board.call("Hồi Trái Dưới", t, d_side_left, side_bot_dz, 0.mm, y_side_left, side_bot_z_start)
          end
          if opt_right_side == 'Bo Cong'
            create_curved_board.call("Hồi Phải Dưới Bo Cong", curve_w, d_side_right, side_bot_dz, w - curve_w, y_side_right, side_bot_z_start, curve_w, false)
          else
            create_board.call("Hồi Phải Dưới", t, d_side_right, side_bot_dz, w - t, y_side_right, side_bot_z_start)
          end
      
          bot_recess_y = y_top_bot
          bot_recess_d = d_top_bot
          create_horizontal_panel.call("Tấm Đáy Dưới", bot_is_lot, bot_w, start_bot_x, bot_recess_d, bot_recess_y, plinth_h)
      
          if join_type == 'Đấu Cục Đỉnh'
            create_horizontal_panel.call("Tấm Nóc Dưới", top_is_lot, top_w, start_top_x, d_top_bot, y_top_bot, z_junction - t)
            # Removed Xà Che Khoảng Hở per user request
          elsif join_type == 'Xà Trên'
            create_horizontal_panel.call("Tấm Nóc Dưới", top_is_lot, top_w, start_top_x, d_top_bot, y_top_bot, z_junction - t)
            create_board.call("Tấm Xà Đứng Trên", inner_w, t, beam_h, start_inner_x, y_inner, z_junction)
            create_board.call("Tấm Xà Ngang Trên", inner_w, beam_h, t, start_inner_x, y_inner + d_inner - beam_h, z_junction)
          elsif join_type == 'Xà Dưới'
            create_board.call("Tấm Xà Đứng Dưới Trước", inner_w, t, beam_h, start_inner_x, y_inner, z_junction - beam_h)
            create_board.call("Tấm Xà Đứng Dưới Sau", inner_w, t, beam_h, start_inner_x, y_inner + d_inner - t, z_junction - beam_h)
          end
      
          if plinth_h > 0
            create_board.call("Len Chân Trước", inner_w, t, plinth_h, start_inner_x, y_inner, 0)
            create_board.call("Len Chân Sau", inner_w, t, plinth_h, start_inner_x, d_cabinet - t, 0)
          end
      
          z_bot_inner = plinth_h + t; z_top_inner_bot = (join_type == 'Xà Dưới') ? z_junction : (z_junction - t)
          h_inner_bot = [0.001.inch, z_top_inner_bot - z_bot_inner].max
          create_back_boards.call(start_inner_x, z_bot_inner, h_inner_bot, div_x_positions) if t_back > 0
      
          div_x_positions.each do |x_div|
            if join_type == 'Xà Dưới'
              pts = [[0.mm, 0.mm], [d_inner, 0.mm], [d_inner, h_inner_bot - beam_h], [d_inner - t, h_inner_bot - beam_h], [d_inner - t, h_inner_bot], [t, h_inner_bot], [t, h_inner_bot - beam_h], [0.mm, h_inner_bot - beam_h]]
              create_yz_board.call("Hồi Giữa Dưới", t, x_div, y_inner, z_bot_inner, pts)
            else
              create_board.call("Hồi Giữa Dưới", t, d_inner, h_inner_bot, x_div, y_inner, z_bot_inner)
            end
          end
      
          dr_h_inner_calc = (opt_drawer != "Không") ? [drawer_h_param, h_inner_bot].min : h_inner_bot
          if shelf_count > 0
            bounds_x = [start_inner_x] + div_x_positions + [start_inner_x + inner_w]
            comp_count = bounds_x.length - 1
            (0...comp_count).each do |c|
              x_left = bounds_x[c] + (c > 0 ? t : 0.mm); x_right = bounds_x[c + 1]
              comp_width = x_right - x_left
              next if comp_width <= 0
              has_drawer_here = opt_drawer != "Không" && is_comp_selected_for_drawer(c, comp_count, drawer_comp_pos)
              avail_h_bot = has_drawer_here ? [0.mm, h_inner_bot - dr_h_inner_calc].max : h_inner_bot
              start_z_bot = has_drawer_here ? (z_bot_inner + dr_h_inner_calc) : z_bot_inner
              gap_shelf = (avail_h_bot - (shelf_count * t)) / (shelf_count + 1).to_f
              if gap_shelf > 0
                (1..shelf_count).each { |s| begin
                    sh_clear_x = shelf_adjustable ? shelf_side_clearance : 0.mm
                    sh_front_setback = shelf_adjustable ? shelf_front_setback : 0.mm
                    sh_w = [1.mm, comp_width - sh_clear_x * 2].max
                    sh_y = shelf_adjustable ? [y_inner, sh_front_setback].max : y_inner
                    sh_d = [1.mm, (y_inner + d_inner) - sh_y].max
                    sh_name = shelf_adjustable ? "Đợt Di Động Dưới" : "Đợt Ngang Dưới"
                    create_board.call(sh_name, sh_w, sh_d, t, x_left + sh_clear_x, sh_y, start_z_bot + (gap_shelf * s) + (t * (s - 1)))
                  end }
              end
            end
          end
      
          upper_has_bottom = (join_type != 'Xà Trên')
          # Tấm đáy phủ hồi chiếm chiều dày tại mối nối; hồi trên phải bắt đầu phía trên tấm đáy.
          side_top_z_start = (upper_has_bottom && !bot_is_lot) ? (z_junction + t) : z_junction
          side_top_z_end = top_is_lot ? h : (z_top_cabinet - t)
          side_top_dz = [0.001.inch, side_top_z_end - side_top_z_start].max
      
          if opt_left_side == 'Bo Cong'
            create_curved_board.call("Hồi Trái Trên Bo Cong", curve_w, d_side_left, side_top_dz, 0.mm, y_side_left, side_top_z_start, curve_w, true)
          else
            create_board.call("Hồi Trái Trên", t, d_side_left, side_top_dz, 0.mm, y_side_left, side_top_z_start)
          end
          if opt_right_side == 'Bo Cong'
            create_curved_board.call("Hồi Phải Trên Bo Cong", curve_w, d_side_right, side_top_dz, w - curve_w, y_side_right, side_top_z_start, curve_w, false)
          else
            create_board.call("Hồi Phải Trên", t, d_side_right, side_top_dz, w - t, y_side_right, side_top_z_start)
          end
      
          if join_type == 'Đấu Cục Đỉnh' || join_type == 'Xà Dưới'
            create_horizontal_panel.call("Tấm Đáy Trên", bot_is_lot, bot_w, start_bot_x, d_top_bot, y_top_bot, z_junction)
          end
          create_top_board.call("Tấm Nóc Trên", z_top_cabinet - t)
          shadow_w = top_is_lot ? inner_w : w
          shadow_x = top_is_lot ? start_inner_x : 0.mm
          create_board.call("Nẹp Tách Trần", shadow_w, t, shadow_gap_h, shadow_x, y_top_bot, h - shadow_gap_h) if shadow_gap_h > 0
      
          z_bot_inner_top = (join_type == 'Xà Trên') ? z_junction : (z_junction + t)
          h_inner_top = [0.001.inch, (z_top_cabinet - t) - z_bot_inner_top].max
          create_back_boards.call(start_inner_x, z_bot_inner_top, h_inner_top, div_x_positions) if t_back > 0
      
          div_x_positions.each do |x_div|
            if join_type == 'Xà Trên'
              pts = [[t, 0.mm], [d_inner, 0.mm], [d_inner, h_inner_top], [0.mm, h_inner_top], [0.mm, beam_h], [t, beam_h]]
              create_yz_board.call("Hồi Giữa Trên", t, x_div, y_inner, z_bot_inner_top, pts)
            else
              create_board.call("Hồi Giữa Trên", t, d_inner, h_inner_top, x_div, y_inner, z_bot_inner_top)
            end
          end
      
          if shelf_count_top > 0
            bounds_x = [start_inner_x] + div_x_positions + [start_inner_x + inner_w]
            (0...(bounds_x.length - 1)).each do |c|
              x_left = bounds_x[c] + (c > 0 ? t : 0.mm); x_right = bounds_x[c + 1]
              comp_width = x_right - x_left
              next if comp_width <= 0
              gap_shelf_top = (h_inner_top - (shelf_count_top * t)) / (shelf_count_top + 1).to_f
              if gap_shelf_top > 0
                (1..shelf_count_top).each { |s| begin
                    sh_clear_x = shelf_adjustable ? shelf_side_clearance : 0.mm
                    sh_front_setback = shelf_adjustable ? shelf_front_setback : 0.mm
                    sh_w = [1.mm, comp_width - sh_clear_x * 2].max
                    sh_y = shelf_adjustable ? [y_inner, sh_front_setback].max : y_inner
                    sh_d = [1.mm, (y_inner + d_inner) - sh_y].max
                    sh_name = shelf_adjustable ? "Đợt Di Động Trên" : "Đợt Ngang Trên"
                    create_board.call(sh_name, sh_w, sh_d, t, x_left + sh_clear_x, sh_y, z_bot_inner_top + (gap_shelf_top * s) + (t * (s - 1)))
                  end }
              end
            end
          end
      
          if opt_door != "Không Cánh" && !is_full_drawer && door_count > 0
            left_door_inset = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Trái"].include?(opt_door) ? ((opt_left_side == "Bo Cong") ? curve_w : 0.mm) : start_inner_x
            right_door_inset = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Phải"].include?(opt_door) ? ((opt_right_side == "Bo Cong") ? curve_w : 0.mm) : (w - inner_w - start_inner_x)
            door_w_total = w - left_door_inset - right_door_inset
            start_door_x = left_door_inset + dg_left
            door_y = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Trái", "Cánh Phủ Hồi Phải"].include?(opt_door) ? -door_t : 0.mm
            single_door_w = (door_w_total - dg_left - dg_right - (dg_between * (door_count - 1))) / door_count.to_f
            if single_door_w > 0
              door_bot_z = plinth_h + dg_bottom
              if join_type == 'Xà Trên' || join_type == 'Xà trên'
                door_bot_max_z = z_junction
                door_top_z = z_junction + mid_door_gap
              elsif join_type == 'Xà Dưới' || join_type == 'Xà dưới'
                door_bot_max_z = z_junction - mid_door_gap
                door_top_z = z_junction
              else
                door_bot_max_z = z_junction - (mid_door_gap / 2.0)
                door_top_z = z_junction + (mid_door_gap / 2.0)
              end
              door_bot_h = [0.001.inch, door_bot_max_z - door_bot_z].max
              
              if opt_door == "Cánh Lọt Lòng"
                door_top_max_z = z_top_cabinet - t - dg_top
              else
                door_top_max_z = top_is_lot ? (z_top_cabinet - dg_top) : (z_top_cabinet - t - dg_top)
              end
              door_top_h = [0.001.inch, door_top_max_z - door_top_z].max
              
              comp_bounds = []
              bounds_x = [start_inner_x] + div_x_positions + [start_inner_x + inner_w]
              (0...(bounds_x.length - 1)).each do |c|
                x_l = bounds_x[c] + (c > 0 ? t : 0.mm)
                x_r = bounds_x[c + 1]
                comp_bounds << { startX: x_l, width: x_r - x_l } if (x_r - x_l) > 0.001.inch
              end
              
              (0...door_count).each do |i|
                d_x = start_door_x + i * (single_door_w + dg_between)
                d_name = get_door_name(i, door_count, div_pos)
                d_align = d_name.include?("Phải") ? :right : :left
                
                current_bot_z = door_bot_z
                current_bot_h = door_bot_h
                
                if opt_drawer == 'Lộ' && comp_bounds.length > 0
                  door_center_x = d_x + single_door_w / 2.0
                  c_idx = comp_bounds.find_index { |cb| door_center_x >= cb[:startX] && door_center_x <= cb[:startX] + cb[:width] }
                  if c_idx && is_comp_selected_for_drawer(c_idx, comp_bounds.length, drawer_comp_pos)
                    new_bot_z = z_bot + dr_h_inner_calc - t
                    door_bot_top = current_bot_z + current_bot_h
                    current_bot_h = door_bot_top - new_bot_z
                    current_bot_z = new_bot_z
                  end
                end
                
                if current_bot_h > 0
                  d_inst_bot = create_board.call("#{d_name} Dưới", single_door_w, door_t, current_bot_h, d_x, door_y, current_bot_z, d_align, true)
                end
                d_inst_top = create_board.call("#{d_name} Trên", single_door_w, door_t, door_top_h, d_x, door_y, door_top_z, d_align, true)
                
                if d_inst_bot && d_name.include?("Trái")
                  anim_l = 'ANIMATE("RotZ", 0, -45, -85)'
                  d_inst_bot.definition.set_attribute('dynamic_attributes', 'onclick', anim_l); d_inst_bot.set_attribute('dynamic_attributes', 'onclick', anim_l)
                  d_inst_bot.definition.set_attribute('dynamic_attributes', 'onClick', anim_l); d_inst_bot.set_attribute('dynamic_attributes', 'onClick', anim_l)
                  d_inst_bot.definition.set_attribute('dynamic_attributes', '_onclick_formula', anim_l); d_inst_bot.set_attribute('dynamic_attributes', '_onclick_formula', anim_l)
                elsif d_inst_bot && d_name.include?("Phải")
                  anim_r = 'ANIMATE("RotZ", 0, 45, 85)'
                  d_inst_bot.definition.set_attribute('dynamic_attributes', 'onclick', anim_r); d_inst_bot.set_attribute('dynamic_attributes', 'onclick', anim_r)
                  d_inst_bot.definition.set_attribute('dynamic_attributes', 'onClick', anim_r); d_inst_bot.set_attribute('dynamic_attributes', 'onClick', anim_r)
                  d_inst_bot.definition.set_attribute('dynamic_attributes', '_onclick_formula', anim_r); d_inst_bot.set_attribute('dynamic_attributes', '_onclick_formula', anim_r)
                end
                if d_inst_top && d_name.include?("Trái")
                  anim_l = 'ANIMATE("RotZ", 0, -45, -85)'
                  d_inst_top.definition.set_attribute('dynamic_attributes', 'onclick', anim_l); d_inst_top.set_attribute('dynamic_attributes', 'onclick', anim_l)
                  d_inst_top.definition.set_attribute('dynamic_attributes', 'onClick', anim_l); d_inst_top.set_attribute('dynamic_attributes', 'onClick', anim_l)
                  d_inst_top.definition.set_attribute('dynamic_attributes', '_onclick_formula', anim_l); d_inst_top.set_attribute('dynamic_attributes', '_onclick_formula', anim_l)
                elsif d_inst_top && d_name.include?("Phải")
                  anim_r = 'ANIMATE("RotZ", 0, 45, 85)'
                  d_inst_top.definition.set_attribute('dynamic_attributes', 'onclick', anim_r); d_inst_top.set_attribute('dynamic_attributes', 'onclick', anim_r)
                  d_inst_top.definition.set_attribute('dynamic_attributes', 'onClick', anim_r); d_inst_top.set_attribute('dynamic_attributes', 'onClick', anim_r)
                  d_inst_top.definition.set_attribute('dynamic_attributes', '_onclick_formula', anim_r); d_inst_top.set_attribute('dynamic_attributes', '_onclick_formula', anim_r)
                end
              end
            end
          end
        else
          z_bot = plinth_h; z_top = h - t - shadow_gap_h
          side_z_start = bot_is_lot ? 0.mm : (plinth_h + t); side_z_end = top_is_lot ? h : z_top; side_dz = side_z_end - side_z_start
      
          if opt_left_side == 'Bo Cong'
            create_curved_board.call("Hồi Trái Bo Cong", curve_w, d_side_left, side_dz, 0.mm, y_side_left, side_z_start, curve_w, true)
          else
            create_board.call("Hồi Trái", t, d_side_left, side_dz, 0.mm, y_side_left, side_z_start)
          end
          if opt_right_side == 'Bo Cong'
            create_curved_board.call("Hồi Phải Bo Cong", curve_w, d_side_right, side_dz, w - curve_w, y_side_right, side_z_start, curve_w, false)
          else
            create_board.call("Hồi Phải", t, d_side_right, side_dz, w - t, y_side_right, side_z_start)
          end
          create_horizontal_panel.call("Tấm Đáy", bot_is_lot, bot_w, start_bot_x, d_top_bot, y_top_bot, z_bot)
          create_top_board.call("Tấm Nóc", z_top)
          shadow_w = top_is_lot ? inner_w : w
          shadow_x = top_is_lot ? start_inner_x : 0.mm
          create_board.call("Nẹp Tách Trần", shadow_w, t, shadow_gap_h, shadow_x, y_top_bot, h - shadow_gap_h) if shadow_gap_h > 0
          if plinth_h > 0
            create_board.call("Len Chân Trước", inner_w, t, plinth_h, start_inner_x, y_inner, 0)
            create_board.call("Len Chân Sau", inner_w, t, plinth_h, start_inner_x, d_cabinet - t, 0)
          end
          create_back_boards.call(start_inner_x, z_bot + t, z_top - (z_bot + t), div_x_positions) if t_back > 0
      
          div_x_positions.each { |x_div| create_board.call("Hồi Giữa", t, d_inner, z_top - (z_bot + t), x_div, y_inner, z_bot + t) }
      
          full_inner_h = [0.001.inch, z_top - (z_bot + t)].max
          dr_h_inner_calc = (opt_drawer != "Không") ? [drawer_h_param, full_inner_h].min : full_inner_h
          if shelf_count > 0
            bounds_x = [start_inner_x] + div_x_positions + [start_inner_x + inner_w]
            comp_count = bounds_x.length - 1
            (0...comp_count).each do |c|
              x_left = bounds_x[c] + (c > 0 ? t : 0.mm); x_right = bounds_x[c + 1]; comp_width = x_right - x_left
              next if comp_width <= 0
              has_drawer_here = opt_drawer != "Không" && is_comp_selected_for_drawer(c, comp_count, drawer_comp_pos)
              avail_shelf_h = has_drawer_here ? [0.mm, full_inner_h - dr_h_inner_calc].max : full_inner_h
              start_shelf_z = has_drawer_here ? (z_bot + t + dr_h_inner_calc) : (z_bot + t)
              gap_shelf = (avail_shelf_h - (shelf_count * t)) / (shelf_count + 1).to_f
              if gap_shelf > 0
                (1..shelf_count).each { |s| begin
                    sh_clear_x = shelf_adjustable ? shelf_side_clearance : 0.mm
                    sh_front_setback = shelf_adjustable ? shelf_front_setback : 0.mm
                    sh_w = [1.mm, comp_width - sh_clear_x * 2].max
                    sh_y = shelf_adjustable ? [y_inner, sh_front_setback].max : y_inner
                    sh_d = [1.mm, (y_inner + d_inner) - sh_y].max
                    sh_name = shelf_adjustable ? "Đợt Di Động" : "Đợt Ngang"
                    create_board.call(sh_name, sh_w, sh_d, t, x_left + sh_clear_x, sh_y, start_shelf_z + (gap_shelf * s) + (t * (s - 1)))
                  end }
              end
            end
          end
      
          if opt_door != "Không Cánh" && !is_full_drawer && door_count > 0
            left_door_inset = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Trái"].include?(opt_door) ? ((opt_left_side == "Bo Cong") ? curve_w : 0.mm) : start_inner_x
            right_door_inset = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Phải"].include?(opt_door) ? ((opt_right_side == "Bo Cong") ? curve_w : 0.mm) : (w - inner_w - start_inner_x)
            door_w_total = w - left_door_inset - right_door_inset
            start_door_x = left_door_inset + dg_left
            case opt_door
            when "Cánh Phủ toàn bộ", "Cánh Phủ Hồi Trái", "Cánh Phủ Hồi Phải"
              door_top_z = top_is_lot ? (h - shadow_gap_h - dg_top) : (z_top - dg_top)
              door_z = plinth_h + dg_bottom
              door_h = [0.001.inch, door_top_z - door_z].max
              door_y = -door_t
            when "Cánh Lọt Hồi"
              door_top_z = top_is_lot ? (h - shadow_gap_h - dg_top) : (z_top - dg_top)
              door_z = z_bot + dg_bottom
              door_h = [0.001.inch, door_top_z - door_z].max
              door_y = 0.mm
            when "Cánh Lọt Lòng"
              door_top_z = z_top - dg_top
              door_z = z_bot + t + dg_bottom
              door_h = [0.001.inch, door_top_z - door_z].max
              door_y = 0.mm
            end
            single_door_w = (door_w_total - dg_left - dg_right - (dg_between * (door_count - 1))) / door_count.to_f
            if single_door_w > 0 && door_h > 0
              
              comp_bounds = []
              bounds_x = [start_inner_x] + div_x_positions + [start_inner_x + inner_w]
              (0...(bounds_x.length - 1)).each do |c|
                x_l = bounds_x[c] + (c > 0 ? t : 0.mm)
                x_r = bounds_x[c + 1]
                comp_bounds << { startX: x_l, width: x_r - x_l } if (x_r - x_l) > 0.001.inch
              end
              
              (0...door_count).each do |i|
                d_x = start_door_x + i * (single_door_w + dg_between)
                door_name = get_door_name(i, door_count, div_pos)
                door_align = door_name.include?("Phải") ? :right : :left
                
                current_door_z = door_z
                current_door_h = door_h
                
                if opt_drawer == 'Lộ' && comp_bounds.length > 0
                  door_center_x = d_x + single_door_w / 2.0
                  c_idx = comp_bounds.find_index { |cb| door_center_x >= cb[:startX] && door_center_x <= cb[:startX] + cb[:width] }
                  if c_idx && is_comp_selected_for_drawer(c_idx, comp_bounds.length, drawer_comp_pos)
                    new_door_z = z_bot + dr_h_inner_calc - t
                    door_top = current_door_z + current_door_h
                    current_door_h = door_top - new_door_z
                    current_door_z = new_door_z
                  end
                end
                
                if current_door_h > 0
                  door_inst = create_board.call(door_name, single_door_w, door_t, current_door_h, d_x, door_y, current_door_z, door_align, true)
                  
                  if door_inst && door_name.include?("Trái")
                    anim_l = 'ANIMATE("RotZ", 0, -45, -85)'
                    door_inst.definition.set_attribute('dynamic_attributes', 'onclick', anim_l); door_inst.set_attribute('dynamic_attributes', 'onclick', anim_l)
                    door_inst.definition.set_attribute('dynamic_attributes', 'onClick', anim_l); door_inst.set_attribute('dynamic_attributes', 'onClick', anim_l)
                    door_inst.definition.set_attribute('dynamic_attributes', '_onclick_formula', anim_l); door_inst.set_attribute('dynamic_attributes', '_onclick_formula', anim_l)
                  elsif door_inst && door_name.include?("Phải")
                    anim_r = 'ANIMATE("RotZ", 0, 45, 85)'
                    door_inst.definition.set_attribute('dynamic_attributes', 'onclick', anim_r); door_inst.set_attribute('dynamic_attributes', 'onclick', anim_r)
                    door_inst.definition.set_attribute('dynamic_attributes', 'onClick', anim_r); door_inst.set_attribute('dynamic_attributes', 'onClick', anim_r)
                    door_inst.definition.set_attribute('dynamic_attributes', '_onclick_formula', anim_r); door_inst.set_attribute('dynamic_attributes', '_onclick_formula', anim_r)
                  end
                end
              end
            end
          end
        end
        
        
        effective_opt_drawer = is_full_drawer ? ((opt_drawer == "Âm") ? "Âm" : "Lộ") : opt_drawer
        if effective_opt_drawer != "Không"
          drawer_section_top_z = is_overheight ? z_top_inner_bot : z_top
          max_h_avail = is_overheight ? h_inner_bot : (z_top - (z_bot + t))
          dr_h_inner = [drawer_h_param, max_h_avail].min
          dr_z_bot = (effective_opt_drawer == "Lộ") ? z_bot : (z_bot + t)
      
          comp_bounds = []
          bounds_x = [start_inner_x] + div_x_positions + [start_inner_x + inner_w]
          (0...(bounds_x.length - 1)).each do |c|
            x_l = bounds_x[c] + (c > 0 ? t : 0.mm)
            x_r = bounds_x[c + 1]
            comp_bounds << { startX: x_l, width: x_r - x_l } if (x_r - x_l) > 0.001.inch
          end
      
          total_comps = comp_bounds.length
          comp_bounds.each_with_index do |cb, c_idx|
            next unless is_comp_selected_for_drawer(c_idx, total_comps, drawer_comp_pos)
      
            dr_w_inner = cb[:width]
            dr_x_inner = cb[:startX]
      
            # KHUNG NGĂN KÉO ÂM (T+ workflow)
            # drawer_hinge_sp = BỀ RỘNG DIỀM, mặc định 50mm; KHÔNG phải chiều dày.
            # Diềm đứng phủ lên cạnh trước của hông khung. Hông khung vẫn dày đúng = t.
            # Vì diềm rộng 50 phủ lên hông dày 20 => hông nằm cách hồi tủ 30mm.
            # Toàn bộ mặt/khung drawer âm lùi khỏi mép trước theo drawer_inner_offset (mặc định 50mm).
            if effective_opt_drawer == "Âm"
              max_trim_w = [t, (dr_w_inner / 2.0) - 1.mm].max
              sub_side_w = [[drawer_hinge_sp, t].max, max_trim_w].min
            else
              sub_side_w = 0.mm
            end
            dr_y_front = (effective_opt_drawer == "Âm") ? (y_inner + drawer_inner_offset) : (is_phu ? -t : 0.mm)
            sub_y = (effective_opt_drawer == "Âm") ? dr_y_front : (dr_y_front + t)
            sub_d = [1.mm, (y_inner + d_inner) - sub_y].max

            if effective_opt_drawer == "Âm"
              frame_h = [t, dr_h_inner - t].max
              frame_side_offset = [0.mm, sub_side_w - t].max
              frame_side_y = sub_y + t
              frame_side_d = [1.mm, sub_d - (t * 2.0)].max
              frame_clear_x = dr_x_inner + sub_side_w
              frame_clear_w = [1.mm, dr_w_inner - (sub_side_w * 2.0)].max
              frame_top_z = dr_z_bot + dr_h_inner - t

              # Đợt nóc phủ toàn bộ khung drawer âm.
              create_board.call("Đợt Nóc Khung Ngăn Kéo Âm", dr_w_inner, sub_d, t, dr_x_inner, sub_y, frame_top_z)

              # Hai hông thật của khung: dày đúng = t, nằm phía sau diềm đứng.
              create_board.call(
                "Hông Khung Ngăn Kéo Âm Trái",
                t, frame_side_d, frame_h,
                dr_x_inner + frame_side_offset, frame_side_y, dr_z_bot
              )
              create_board.call(
                "Hông Khung Ngăn Kéo Âm Phải",
                t, frame_side_d, frame_h,
                dr_x_inner + dr_w_inner - frame_side_offset - t, frame_side_y, dr_z_bot
              )

              # Hai DIỀM ĐỨNG rộng drawer_hinge_sp (mặc định 50), dày = t.
              # Diềm phủ qua cạnh trước của hông, không làm hông dày lên.
              create_board.call(
                "Diềm Phủ Hông Ngăn Kéo Âm Trái",
                sub_side_w, t, frame_h,
                dr_x_inner, sub_y, dr_z_bot
              )
              create_board.call(
                "Diềm Phủ Hông Ngăn Kéo Âm Phải",
                sub_side_w, t, frame_h,
                dr_x_inner + dr_w_inner - sub_side_w, sub_y, dr_z_bot
              )

              # Diềm TRƯỚC / SAU là các thanh đứng theo mặt phẳng XZ: cao = bề rộng diềm, dày = t.
              # Chúng khóa hai hông thành một khung như hình X-Ray thực tế, thay cho kiểu tấm nằm ngang
              # sâu 50mm của bản trước.
              frame_rail_h = [[drawer_hinge_sp, t].max, frame_h].min
              frame_rail_z = [dr_z_bot, frame_top_z - frame_rail_h].max
              create_board.call(
                "Diềm Trước Khung Ngăn Kéo Âm",
                frame_clear_w, t, frame_rail_h,
                frame_clear_x, sub_y, frame_rail_z
              )
              create_board.call(
                "Diềm Sau Khung Ngăn Kéo Âm",
                frame_clear_w, t, frame_rail_h,
                frame_clear_x, (y_inner + d_inner) - t, frame_rail_z
              )
            else
              ceiling_limit_z = drawer_section_top_z
              if dr_z_bot + dr_h_inner < (ceiling_limit_z - t - 0.001.inch)
                create_board.call("Đợt Nóc Ngăn Kéo", dr_w_inner, sub_d, t, dr_x_inner, sub_y, dr_z_bot + dr_h_inner - t)
              end
            end
      
            lower_front_top_z = if is_overheight
                                  if join_type == 'Xà Dưới' || join_type == 'Xà dưới'
                                    z_junction - mid_door_gap
                                  elsif join_type == 'Đấu Cục Đỉnh'
                                    z_junction - (mid_door_gap / 2.0)
                                  else
                                    z_junction
                                  end
                                else
                                  top_is_lot ? (h - shadow_gap_h) : z_top
                                end

            if effective_opt_drawer == "Lộ"
              if is_full_drawer
                top_z_limit = lower_front_top_z
                fz_start = plinth_h + drg_bottom
                dr_span_h = top_z_limit - plinth_h
              else
                fz_start = z_bot + drg_bottom
                dr_span_h = dr_h_inner - t
              end
              dr_front_h = [1.mm, (dr_span_h - drg_top - drg_bottom - (drg_between * (drawer_count_val - 1))) / drawer_count_val.to_f].max
            else
              fz_start = dr_z_bot + drg_bottom
              dr_span_h = is_full_drawer ? (lower_front_top_z - dr_z_bot) : (dr_h_inner - t)
              dr_front_h = [1.mm, (dr_span_h - drg_top - drg_bottom - (drg_between * (drawer_count_val - 1))) / drawer_count_val.to_f].max
            end
      
            if effective_opt_drawer == "Âm"
              dr_front_w = [1.mm, dr_w_inner - sub_side_w * 2 - drg_left - drg_right].max
              dr_front_x = dr_x_inner + sub_side_w + drg_left
            else
              is_overlay_l = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Trái"].include?(opt_door) || (opt_door == "Không Cánh" && effective_opt_drawer == "Lộ")
              is_overlay_r = ["Cánh Phủ toàn bộ", "Cánh Phủ Hồi Phải"].include?(opt_door) || (opt_door == "Không Cánh" && effective_opt_drawer == "Lộ")
              if total_comps == 1
                left_door_inset = is_overlay_l ? ((opt_left_side == "Bo Cong") ? curve_w : 0.mm) : dr_x_inner
                right_door_inset = is_overlay_r ? ((opt_right_side == "Bo Cong") ? curve_w : 0.mm) : (w - dr_w_inner - dr_x_inner)
                dr_front_w = [1.mm, w - left_door_inset - right_door_inset - drg_left - drg_right].max
                dr_front_x = left_door_inset + drg_left
              else
                if c_idx == 0
                  left_door_inset = is_overlay_l ? ((opt_left_side == "Bo Cong") ? curve_w : 0.mm) : dr_x_inner
                  left_x = left_door_inset + drg_left
                  right_x = dr_x_inner + dr_w_inner + t / 2.0 - drg_right
                elsif c_idx == total_comps - 1
                  right_door_inset = is_overlay_r ? ((opt_right_side == "Bo Cong") ? curve_w : 0.mm) : (w - dr_w_inner - dr_x_inner)
                  left_x = dr_x_inner - t / 2.0 + drg_left
                  right_x = w - right_door_inset - drg_right
                else
                  left_x = dr_x_inner - t / 2.0 + drg_left
                  right_x = dr_x_inner + dr_w_inner + t / 2.0 - drg_right
                end
                dr_front_x = left_x
                dr_front_w = [10.mm, right_x - left_x].max
              end
            end
      
            box_x = dr_x_inner + sub_side_w + drawer_ray_space
            box_w = [1.mm, (dr_w_inner - sub_side_w * 2) - (drawer_ray_space * 2)].max
            box_y = dr_y_front + t
            cavity_back_y = y_inner + d_inner
            box_d = [1.mm, cavity_back_y - box_y - drawer_back_clearance].max

            # Xà che/chặn nằm phía sau đúng tâm khe giữa hai mặt ngăn kéo.
            # Đây là cấu kiện thực, không phải guide: dùng cho tay móc âm/vát 45° có khe 20–25 mm
            # hoặc bất kỳ cấu tạo nào người dùng muốn che nền phía sau khe.
            backing_rails = []
            if drawer_backing_rail && drawer_count_val > 1
              rail_w = (effective_opt_drawer == "Âm") ? [1.mm, dr_w_inner - sub_side_w * 2].max : dr_w_inner
              rail_x = (effective_opt_drawer == "Âm") ? (dr_x_inner + sub_side_w) : dr_x_inner
              rail_y = dr_y_front + t
              (0...(drawer_count_val - 1)).each do |ri|
                gap_center_z = fz_start + (ri + 1) * dr_front_h + ri * drg_between + (drg_between / 2.0)
                rail_z = gap_center_z - (drawer_backing_rail_h / 2.0)
                # Giữ xà trong vùng drawer section để không xuyên đáy/nóc khoang.
                min_rail_z = dr_z_bot
                max_rail_z = [dr_z_bot, drawer_section_top_z - drawer_backing_rail_h].max
                rail_z = [[rail_z, min_rail_z].max, max_rail_z].min
                create_board.call("Xà Che Khe Ngăn Kéo #{ri + 1}", rail_w, t, drawer_backing_rail_h, rail_x, rail_y, rail_z)
                backing_rails << { :z => rail_z, :h => drawer_backing_rail_h }
              end
            end
      
            (0...drawer_count_val).each do |i|
              fz = fz_start + i * (dr_front_h + drg_between)
              cur_dr_h = dr_front_h
      
              dr_grp = entities.add_group
              dr_grp.name = "Bộ Ngăn Kéo #{i+1}"
              begin
                dr_grp.layer = Sketchup.active_model.layers[0]
              rescue
              end
              dr_ents = dr_grp.entities
      
              make_dr_board = ->(b_name, dx, dy, dz, bx, by, bz) {
                b_grp = dr_ents.add_group
                b_grp.name = b_name
                begin
                  b_grp.layer = Sketchup.active_model.layers[0]
                rescue
                end
                if b_name.start_with?("Mặt Ngăn Kéo")
                  Modeling.front_solid(b_grp.entities, 0.mm, dx, dy, dz, p)
                else
                  Modeling.front_solid(b_grp.entities, 0.mm, dx, dy, dz, p.merge('front_bevel'=>false))
                end
                # Raw geometry luôn Untagged; chỉ group Mặt Ngăn Kéo mới được gán T+_CANH.
                begin
                  untagged = Sketchup.active_model.layers[0]
                  b_grp.entities.each { |e| e.layer = untagged if e.respond_to?(:layer=) }
                rescue
                end
                b_grp.transform!(Geom::Transformation.translation(Geom::Vector3d.new(bx, by, bz)))
                b_grp
              }
      
              front_grp = make_dr_board.call("Mặt Ngăn Kéo #{i+1}", dr_front_w, t, cur_dr_h, dr_front_x, dr_y_front, fz)

              # Mặt ngăn kéo là cấu kiện cánh: chỉ riêng panel mặt nằm trên tag T+_CANH.
              # Thùng/hộc kéo và component cha luôn để Untagged để không làm bẩn hệ tag cấu kiện.
              if front_grp && front_grp.valid?
                begin
                  model = Sketchup.active_model
                  layer_door = model.layers["T+_CANH"] || model.layers.add("T+_CANH")
                  layer_guide = model.layers["T+_KY HIEU"] || model.layers.add("T+_KY HIEU")
                  front_grp.layer = layer_door

                  # Ký hiệu mặt ngăn kéo: 1 Construction Guide chéo từ góc trên-trái
                  # xuống góc dưới-phải. Guide nằm TRONG group mặt ngăn kéo nên khi drawer
                  # chạy Dynamic Component, ký hiệu luôn đi theo đúng mặt cánh.
                  # Dùng ConstructionLine thật để người dùng có thể xóa hàng loạt bằng Delete Guides của SketchUp.
                  gy = -0.1.mm
                  guide_start = Geom::Point3d.new(0.mm, gy, cur_dr_h)
                  guide_end = Geom::Point3d.new(dr_front_w, gy, 0.mm)
                  # Hai Point3d => finite ConstructionLine đúng kiểu Tape Measure Guide.
                  guide = front_grp.entities.add_cline(guide_start, guide_end)
                  guide.layer = layer_guide if guide
                rescue => e
                  puts "T+_Cabinet drawer guide warning: #{e.message}"
                end
              end
      
              # Keep each box inside the vertical envelope of its own drawer opening/front.
              # This replaces the old fake 40/60 mm "rail planes", which were not real parts or
              # universal hardware requirements.
              min_bz = [z_bot + t, fz].max + drawer_box_bottom_lift
              max_box_top = [fz + cur_dr_h - drawer_box_top_clearance, drawer_section_top_z - drawer_box_top_clearance].min
              # Nếu có xà che/chặn khe, thùng drawer phải nằm giữa các xà thay vì xuyên qua chúng.
              if drawer_backing_rail
                if i > 0 && backing_rails[i - 1]
                  prev_rail = backing_rails[i - 1]
                  min_bz = [min_bz, prev_rail[:z] + prev_rail[:h] + drawer_box_bottom_lift].max
                end
                if i < backing_rails.length && backing_rails[i]
                  next_rail = backing_rails[i]
                  max_box_top = [max_box_top, next_rail[:z] - drawer_box_top_clearance].min
                end
              end
              bz = min_bz
              box_h = [10.mm, max_box_top - bz].max
              by = box_y
              make_dr_board.call("Vách Ngăn Kéo Trái #{i+1}", drawer_box_t, box_d, box_h, box_x, by, bz)
              make_dr_board.call("Vách Ngăn Kéo Phải #{i+1}", drawer_box_t, box_d, box_h, box_x + box_w - drawer_box_t, by, bz)
              make_dr_board.call("Đầu Ngăn Kéo #{i+1}", [1.mm, box_w - drawer_box_t*2].max, drawer_box_t, box_h, box_x + drawer_box_t, by, bz)
              make_dr_board.call("Đuôi Ngăn Kéo #{i+1}", [1.mm, box_w - drawer_box_t*2].max, drawer_box_t, box_h, box_x + drawer_box_t, by + box_d - drawer_box_t, bz)
              bottom_z = [bz + drawer_bottom_offset, bz + box_h - drawer_bottom_t].min
              make_dr_board.call("Đáy Ngăn Kéo #{i+1}", [1.mm, box_w - drawer_box_t*2].max, [1.mm, box_d - drawer_box_t*2].max, drawer_bottom_t, box_x + drawer_box_t, by + drawer_box_t, bottom_z)
      
              dr_inst = dr_grp.to_component
              dr_inst.definition.name = "Ngăn Kéo_DC"
              dr_inst.name = "Ngăn Kéo #{i+1}_DC"
              begin
                model = Sketchup.active_model
                untagged = model.layers[0]
                layer_door = model.layers["T+_CANH"] || model.layers.add("T+_CANH")
                layer_guide = model.layers["T+_KY HIEU"] || model.layers.add("T+_KY HIEU")
                dr_inst.layer = untagged

                # Chuẩn hóa lại tag sau khi convert group cha thành component:
                # - Component Ngăn Kéo_DC và toàn bộ thùng: Untagged
                # - Chỉ Mặt Ngăn Kéo: T+_CANH
                # - ConstructionLine chéo nằm bên trong chính group mặt: T+_KY HIEU
                dr_inst.definition.entities.each do |child|
                  next unless child.is_a?(Sketchup::Group)
                  if child.name.to_s.start_with?("Mặt Ngăn Kéo")
                    child.layer = layer_door
                    guides = child.entities.to_a.select { |e| e.is_a?(Sketchup::ConstructionLine) }
                    if guides.empty?
                      guide_start = Geom::Point3d.new(0.mm, -0.1.mm, cur_dr_h)
                      guide_end = Geom::Point3d.new(dr_front_w, -0.1.mm, 0.mm)
                      guide = child.entities.add_cline(guide_start, guide_end)
                      guide.layer = layer_guide if guide
                    else
                      guides.each { |g| g.layer = layer_guide }
                    end
                  else
                    child.layer = untagged
                  end
                end
              rescue => e
                puts "T+_Cabinet drawer tag normalization warning: #{e.message}"
              end

              y0 = (-d_cabinet).to_f.round(4)
              y1 = (-d_cabinet - 200.mm).to_f.round(4)
              y2 = (-d_cabinet - 300.mm).to_f.round(4)
              y3 = (-d_cabinet - 400.mm).to_f.round(4)
      
              anim_formula = 'ANIMATE("Y", ' + y0.to_s + ', ' + y1.to_s + ', ' + y2.to_s + ', ' + y3.to_s + ')'
              [dr_inst.definition, dr_inst].each do |obj|
                obj.set_attribute('dynamic_attributes', 'y', y0)
                obj.set_attribute('dynamic_attributes', '_y_formula', y0.to_s)
                obj.set_attribute('dynamic_attributes', '_y_format', 'FLOAT')
                obj.set_attribute('dynamic_attributes', '_y_units', 'INCHES')
                obj.set_attribute('dynamic_attributes', '_y_access', 'NONE')
                obj.set_attribute('dynamic_attributes', 'onclick', anim_formula)
                obj.set_attribute('dynamic_attributes', 'onClick', anim_formula)
                obj.set_attribute('dynamic_attributes', '_onclick_formula', anim_formula)
                obj.set_attribute('dynamic_attributes', '_onclick_label', 'Kéo Ngăn Kéo (Slide)')
              end
            end
          end
        end
      
        if truthy_param?(p, 'door_stop_rail', false) && door_count > 0
          rail_height = p['door_stop_rail_h'].to_f.mm
          tops = [z_top]
          tops << z_top_inner_bot if is_overheight && join_type != 'Xà Dưới'
          bounds = [start_inner_x] + div_x_positions + [start_inner_x + inner_w]
          tops.each_with_index do |top, level|
            bounds.each_cons(2).with_index do |(a,b), index|
              a += t if index > 0
              create_board.call("Xà Chặn Cánh #{level+1}.#{index+1}", b-a, t, rail_height, a, y_inner+2.mm, top-rail_height)
            end
          end
        end
        tr_shift = Geom::Transformation.translation(Geom::Vector3d.new(0, -d_cabinet, 0))
        entities.transform_entities(tr_shift, entities.to_a)
      end
      
    end
  end
end
