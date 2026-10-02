# frozen_string_literal: true
module VGD_Cabinet
  module ModelingRules
    class Invalid < StandardError; end
    module_function

    def migrate(input)
      p=input.dup
      unless p['handle_split_v1']
        p['drawer_bevel']=p['front_bevel'] if p.key?('front_bevel') && !p.key?('drawer_bevel')
        p['drawer_bevel_lip']=p['bevel_lip'] if p.key?('bevel_lip') && !p.key?('drawer_bevel_lip')
      end
      p['handle_split_v1']=true
      p
    end

    def normalize(input, defaults)
      raise Invalid, 'Thông số tủ không hợp lệ.' unless input.is_a?(Hash)
      p = defaults.merge(migrate(input).reject { |k, _| k.start_with?('__') })
      defaults.each do |key, value|
        if value.is_a?(Numeric)
          begin
            p[key] = Float(p[key])
          rescue ArgumentError, TypeError
            raise Invalid, "#{key}: cần nhập một số."
          end
          raise Invalid, "#{key}: giá trị phải hữu hạn và không âm." unless p[key].finite? && p[key] >= 0
        elsif value == true || value == false
          p[key] = [true, 'true', 1, '1'].include?(p[key])
        end
      end
      %w[div_count shelf_count shelf_count_top door_count drawer_count].each do |k|
        raise Invalid, "#{k}: nhập số nguyên từ 0 đến 20." unless p[k] == p[k].to_i && p[k] <= 20
        p[k] = p[k].to_i
      end
      %w[w d h].each { |k| raise Invalid, "#{k.upcase}: nhập từ 100 đến 5000 mm." unless p[k].between?(100, 5000) }
      raise Invalid, 'Dày ván phải từ 3 đến 60 mm.' unless p['t'].between?(3, 60)
      raise Invalid, 'Số cụm ngăn kéo phải là 1 hoặc 2.' unless [1,2].include?(p['drawer_columns'])
      raise Invalid, 'Chọn kiểu đáy hộc hợp lệ.' unless ['Âm hai bên','Âm bốn phía','Phủ dưới'].include?(p['drawer_bottom_mode'])
      raise Invalid, 'Độ ngậm hậu không được lớn hơn dày hồi.' if !p['back_groove_auto'] && p['back_groove_depth'] > p['t']
      raise Invalid, 'Chọn kiểu dựng cánh hợp lệ.' unless ['Ván phẳng','Kính khung kim loại','Pano khung gỗ'].include?(p['door_style'])
      if p['door_style']=='Pano khung gỗ'
        %w[pano_stile_width pano_rail_width pano_depth pano_panel_thickness pano_groove_depth pano_mid_rail].each do |key|
          raise Invalid,"#{key}: phải từ 1 mm." unless p[key]>=1
        end
        raise Invalid,'Pano phải mỏng hơn khung để còn hai má rãnh.' unless p['pano_panel_thickness']<p['pano_depth']
        raise Invalid,'Ngậm rãnh phải lớn hơn khe co giãn và nhỏ hơn nửa bản khung.' unless p['pano_groove_depth']>p['pano_clearance'] && p['pano_groove_depth']<[p['pano_stile_width'],p['pano_rail_width'],p['pano_mid_rail']].min/2
        raise Invalid,'Số ô pano phải là số nguyên từ 1 đến 6.' unless p['pano_panel_count']==p['pano_panel_count'].to_i && p['pano_panel_count'].between?(1,6)
      end
      if p['door_style'] == 'Kính khung kim loại'
        %w[metal_frame_width metal_frame_depth glass_thickness].each do |key|
          raise Invalid, "#{key}: nhập từ 1 mm trở lên." unless p[key] >= 1
        end
        raise Invalid, 'Kính không được dày hơn khung.' if p['glass_thickness'] > p['metal_frame_depth']
        raise Invalid, 'Chọn màu khung hợp lệ.' unless ['Đen','Champagne','Inox'].include?(p['metal_finish'])
        raise Invalid, 'Chọn màu kính hợp lệ.' unless ['Trong','Trà','Xám'].include?(p['glass_finish'])
      end
      raise Invalid, 'Giới hạn cao tấm phải lớn hơn 100 mm.' unless p['max_panel_h'] > 100
      raise Invalid, 'Ngưỡng khoang và cánh phải lớn hơn 50 mm.' unless p['max_compartment_w'] > 50 && p['max_door_w'] > 50
      raise Invalid, 'Bước bắt kích thước phải từ 1 đến 100 mm.' unless p['snap_step'].between?(1, 100)
      raise Invalid, 'Chọn kiểu hậu hợp lệ.' unless ['Âm', 'Phủ', 'Không'].include?(p['back_mode'])
      raise Invalid, 'Chọn kiểu chia module hợp lệ.' unless ['Chung vách', 'Độc lập'].include?(p['module_mode'])
      raise Invalid, 'Dày hậu phải nhỏ hơn chiều sâu tủ.' unless p['t_back'] < p['d']
      widths(p).each_with_index do |w, index|
        one = p.merge('w' => w, 'module_mode' => 'Chung vách')
        one['opt_left_side'] = 'Vuông' if index > 0
        one['opt_right_side'] = 'Vuông' if index < widths(p).size - 1
        validate_single(one)
      end
      p
    end

    def widths(p)
      return [p['w']] unless p['module_mode'] == 'Độc lập'
      raw = p['module_widths'].to_s.strip
      if raw.empty?
        raise Invalid, 'Rộng module mục tiêu phải lớn hơn 100 mm.' unless p['module_target_w'] > 100
        count = (p['w'] / p['module_target_w']).ceil
        return Array.new(count, p['w'] / count.to_f)
      end
      values = raw.split(/[;+\s]+/).map do |s|
        begin
          Float(s.tr(',', '.'))
        rescue ArgumentError
          raise Invalid, 'Danh sách module: nhập ví dụ 800;800;800 (mm).'
        end
      end
      raise Invalid, 'Cần từ 1 đến 20 module, mỗi module rộng hơn 100 mm.' unless values.size.between?(1, 20) && values.all? { |n| n.finite? && n > 100 }
      raise Invalid, "Tổng module #{values.sum.round(2)} mm khác rộng tủ #{p['w']} mm." if (values.sum - p['w']).abs > 0.01
      values
    end

    def validate_single(p)
      t = p['t']; w = p['w']; h = p['h']; d = p['d']
      left = p['opt_left_side'] == 'Bo Cong' ? [p['curve_w'], t].max : t
      right = p['opt_right_side'] == 'Bo Cong' ? [p['curve_w'], t].max : t
      raise Invalid, 'Rộng tủ không đủ cho hai hồi.' unless w > left + right + 20
      raise Invalid, 'Bán kính bo không được lớn hơn chiều sâu.' if [left, right].max > d
      overlay = p['opt_door'].to_s.include?('Phủ') || (p['opt_door'] == 'Không Cánh' && (p['opt_drawer'] == 'Lộ' || p['is_full_drawer']))
      front = overlay || ['Cánh Lọt Hồi', 'Cánh Lọt Lòng'].include?(p['opt_door']) ? Modeling.door_depth_mm(p) : 0
      back = p['back_mode'] == 'Không' ? 0 : p['t_back'] + (p['back_mode'] == 'Âm' ? p['back_recess'] : 0)
      clear_d = d - front - back
      raise Invalid, 'Chiều sâu không đủ sau khi trừ cánh, hậu và độ lùi hậu.' unless clear_d > 30
      raise Invalid, 'Đợt lùi quá sâu so với lòng tủ.' if p['shelf_type'] == 'Di Động' && p['shelf_count'] > 0 && p['shelf_front_setback'] >= d - back - t
      divs = GeometryEngine.effective_divider_count_mm(p, w)
      if divs > 0 && p['back_mode']=='Âm' && !p['back_groove_auto'] && p['back_groove_depth'] > t/2
        raise Invalid, 'Hậu chia tại hồi giữa: mỗi bên chỉ được ngậm tối đa nửa dày hồi để không chồng tấm.'
      end
      doors = GeometryEngine.effective_door_count_mm(p, w)
      gap_left = p[p['door_gap_advanced'] ? 'door_gap_left' : 'door_gap_outer']
      gap_right = p[p['door_gap_advanced'] ? 'door_gap_right' : 'door_gap_outer']
      gap_between = p[p['door_gap_advanced'] ? 'door_gap_between' : 'door_gap']
      positions = GeometryEngine.compute_div_x_positions(divs, p['div_pos'], doors, p['opt_door'], w-left-right, left, w, t, gap_left, gap_right, gap_between, p['opt_left_side'], p['opt_right_side'], p['curve_w'])
      bounds = [left] + positions + [w-right]
      bays = bounds.each_cons(2).with_index.map { |(a,b), i| b-a-(i > 0 ? t : 0) }
      raise Invalid, 'Khoang quá hẹp: giảm số hồi/cánh hoặc tăng rộng tủ.' unless bays.all? { |b| b > 20 }
      if p['shelf_type'] == 'Di Động' && p['shelf_count'] > 0
        raise Invalid, 'Khe đợt lớn hơn rộng khoang.' if bays.min <= 2*p['shelf_side_clearance']+10
      end
      split = GeometryEngine.resolve_overheight_mm(p, h)
      shadow = p['opt_top'] == 'Đỉnh Lọt Hồi' ? p['shadow_gap_h'] : 0
      clear_h = h - shadow - p['plinth_h'] - 2*t
      raise Invalid, 'Chân/nẹp/nóc đáy chiếm hết chiều cao tủ.' unless clear_h > 30
      if split[:is_overheight]
        if p['overheight_join']=='Xà Trên' && clear_d <= 2*p['beam_h']+t
          raise Invalid, 'Chiều sâu không đủ cho xà trước và sau ở mối nối tầng.'
        end
        lower = split[:h_bottom]
        raise Invalid, 'Hai tầng vẫn vượt khổ tấm; giảm chiều cao hoặc tăng giới hạn tấm.' if lower > p['max_panel_h']+t || h-lower > p['max_panel_h']+t
        clear_h = lower - p['plinth_h'] - 2*t
        upper_clear = h - shadow - lower - 2*t
        raise Invalid, 'Tầng trên không đủ chỗ cho đợt.' if upper_clear <= (p['shelf_count_top']+1)*t
      end
      drawer = p['opt_drawer'] != 'Không' || p['is_full_drawer']
      used_h = drawer ? (p['is_full_drawer'] ? clear_h : [p['drawer_h'], clear_h].min) : 0
      raise Invalid, 'Không đủ khoảng cao để bố trí số đợt đã chọn.' if p['shelf_count'] > 0 && clear_h-used_h <= p['shelf_count']*t+10
      if doors > 0
        if p['door_stop_rail']
          rail_h=p['door_stop_rail_h']
          raise Invalid, 'Xà chặn cánh phải cao ít nhất bằng dày ván.' unless rail_h >= t
          top_gap=(clear_h-used_h-p['shelf_count']*t)/(p['shelf_count']+1)
          raise Invalid, 'Xà chặn cánh cấn đợt hoặc hộc. Giảm cao xà/số đợt.' unless top_gap > rail_h
          if split[:is_overheight]
            upper_gap=(upper_clear-p['shelf_count_top']*t)/(p['shelf_count_top']+1)
            raise Invalid, 'Xà chặn cánh tầng trên cấn đợt.' unless upper_gap > rail_h
          end
        end
        raise Invalid, 'Khe cánh quá lớn so với chiều rộng.' if w-left-right-gap_left-gap_right-gap_between*(doors-1) <= doors*10
        raise Invalid, 'Khe trên/dưới lớn hơn chiều cao cánh.' if p['door_gap_advanced'] && p['door_gap_top']+p['door_gap_bottom'] >= clear_h-10
      end
      if drawer
        raise Invalid, 'Bản xà đáy két phải từ 1 mm.' unless p['drawer_frame_rail_width'] >= 1
        if p['opt_drawer']=='Âm' && p['drawer_frame_stop_rail']
          raise Invalid, 'Cao xà đón phải từ 1 mm.' unless p['drawer_frame_stop_rail_h'] >= 1
        end
        raise Invalid, 'Số ngăn kéo phải từ 1 đến 20.' unless p['drawer_count'] >= 1
        bt = p['drawer_box_t'] > 0 ? p['drawer_box_t'] : t
        trim = p['opt_drawer'] == 'Âm' ? [p['drawer_hinge_sp'],t].max : 0
        selected = bays.each_with_index.select { |_,i| GeometryEngine.is_comp_selected_for_drawer(i,bays.size,p['drawer_comp_pos']) }.map(&:first)
        opening=(selected.min-2*trim-(p['drawer_columns']-1)*t)/p['drawer_columns']
        raise Invalid, 'Không đủ rộng cho các cụm ngăn kéo, ray và hông hộc.' if opening-2*p['drawer_ray_space'] <= 2*bt+10
        setback = p['opt_drawer'] == 'Âm' ? p['drawer_inner_offset'] : 0
        if p['opt_drawer']=='Âm' && p['drawer_frame_depth']>0
          raise Invalid, 'Sâu két phủ bì vượt khoảng trống trong tủ.' if p['drawer_frame_depth']>clear_d-setback
          raise Invalid, 'Sâu két không đủ cho thùng hộc và khoảng hở sau.' if p['drawer_frame_depth']<=3*bt+p['drawer_back_clearance']+10
        end
        raise Invalid, 'Không đủ sâu cho thùng ngăn kéo.' if clear_d-setback-p['drawer_back_clearance'] <= 3*bt+10
        gh = p[p['drawer_gap_advanced'] ? 'drawer_gap_between' : 'drawer_gap']
        gt = p[p['drawer_gap_advanced'] ? 'drawer_gap_top' : 'drawer_gap_outer']
        gb = p[p['drawer_gap_advanced'] ? 'drawer_gap_bottom' : 'drawer_gap_outer']
        fh = (used_h-t-gt-gb-gh*(p['drawer_count']-1))/p['drawer_count']
        min_h = p['drawer_box_bottom_lift']+p['drawer_box_top_clearance']+p['drawer_bottom_offset']+p['drawer_bottom_t']+5
        raise Invalid, 'Ngăn kéo quá thấp cho đáy và các khoảng hở đã nhập.' unless fh > min_h
      end
      if p['front_bevel']
        door_t=Modeling.door_depth_mm(p)
        raise Invalid, 'Mép móc tay cánh phải nhỏ hơn dày cánh.' unless p['bevel_lip'] > 0 && p['bevel_lip'] < door_t
        if p['door_style']=='Pano khung gỗ'
          raise Invalid,'Bản thanh trên pano quá nhỏ cho móc tay và rãnh.' unless p['pano_rail_width']>door_t-p['bevel_lip']+p['pano_groove_depth']
        end
      end
      if p['drawer_bevel']
        raise Invalid,'Mép móc tay hộc phải nhỏ hơn dày mặt hộc.' unless p['drawer_bevel_lip']>0 && p['drawer_bevel_lip']<t
      end
      true
    end
  end
end
