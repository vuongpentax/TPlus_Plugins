from pathlib import Path
p=Path('cabinet_work/TPlus_Cabinet/geometry_engine.rb');s=p.read_text()
a=s.index('          if div_x_positions_arr && !div_x_positions_arr.empty?',s.index('create_back_boards ='))
b=s.index('\n        }',a)
s=s[:a]+'''          groove = (p['back_groove_auto'] ? t / 2.0 : p['back_groove_depth'].to_f.mm)
          divs = (div_x_positions_arr || []).sort
          starts = [start_x] + divs.map { |position| position + t }
          ends = divs + [start_x + inner_w]
          starts.zip(ends).each_with_index do |(left, right), index|
            name = divs.empty? ? 'Tấm Hậu' : "Tấm Hậu Khoang #{index+1}"
            create_board.call(name, right-left+2*groove, t_back, z_h, left-groove, d_cabinet-back_recess-t_back, z_start)
          end'''+s[b:]
s=s.replace('frame_side_d = [1.mm, sub_d - (t * 2.0)].max','frame_side_d = sub_d - t')
s=s.replace('sub_d = [1.mm, (y_inner + d_inner) - sub_y].max', '''available_frame_depth = (y_inner + d_inner) - sub_y
            sub_d = (effective_opt_drawer == "Âm" && p['drawer_frame_depth'].to_f > 0) ? p['drawer_frame_depth'].to_f.mm : available_frame_depth
            raise ModelingRules::Invalid, 'Chiều sâu két vượt khoảng trống trong tủ.' if sub_d > available_frame_depth + 0.01.mm''')
a=s.index('              # Diềm TRƯỚC / SAU là các thanh đứng')
b=s.index('\n            else\n              ceiling_limit_z',a)
s=s[:a]+'''              rail_width = p['drawer_frame_rail_width'].to_f.mm
              raise ModelingRules::Invalid, 'Két quá nông cho hai xà đáy.' if sub_d < t+2*rail_width
              create_board.call('Xà Đáy Két Trước', frame_clear_w, rail_width, t, frame_clear_x, sub_y+t, dr_z_bot)
              create_board.call('Xà Đáy Két Sau', frame_clear_w, rail_width, t, frame_clear_x, sub_y+sub_d-rail_width, dr_z_bot)
              if p['drawer_frame_stop_rail']
                stop_h = p['drawer_frame_stop_rail_h'].to_f.mm
                stop_z = frame_top_z-stop_h-p['drawer_frame_stop_rail_drop'].to_f.mm
                raise ModelingRules::Invalid, 'Xà đón quá thấp, cấn xà đáy két.' if stop_z < dr_z_bot+t
                create_board.call('Xà Đón Mặt Hộc', frame_clear_w, t, stop_h, frame_clear_x, sub_y+t, stop_z)
              end'''+s[b:]
a=s.index('\n            lower_front_top_z =',s.index('effective_opt_drawer ='))
s=s[:a]+'''
            columns = p['drawer_columns'].to_i
            parent_drawer_x = dr_x_inner
            parent_drawer_width = dr_w_inner
            parent_trim = sub_side_w
            column_width = (parent_drawer_width-2*parent_trim-(columns-1)*t)/columns
            if columns == 2
              create_board.call('Hồi Giữa Két', t, sub_d-t, dr_h_inner-2*t,
                parent_drawer_x+parent_trim+column_width, sub_y+t, dr_z_bot+t)
            end
            (0...columns).each do |column_index|
              if columns == 2
                dr_x_inner = parent_drawer_x+parent_trim+column_index*(column_width+t)
                dr_w_inner = column_width
                sub_side_w = 0.mm
              end
'''+s[a:]
s=s.replace('            if effective_opt_drawer == "Âm"\n              dr_front_w', '            if effective_opt_drawer == "Âm" || columns == 2\n              dr_front_w')
s=s.replace('cavity_back_y = y_inner + d_inner','cavity_back_y = sub_y + sub_d')
s=s.replace('min_bz = [z_bot + t, fz].max + drawer_box_bottom_lift','min_bz = [z_bot + t, fz, (effective_opt_drawer == "Âm" ? dr_z_bot+t : dr_z_bot)].max + drawer_box_bottom_lift')
s=s.replace('              bz = min_bz\n              box_h = [10.mm, max_box_top - bz].max', '''              if effective_opt_drawer == "Âm" && p['drawer_frame_stop_rail']
                # If a drawer envelope meets the head rail, keep its box below it.
                stop_z = frame_top_z-p['drawer_frame_stop_rail_h'].to_f.mm-p['drawer_frame_stop_rail_drop'].to_f.mm
                stop_top = stop_z+p['drawer_frame_stop_rail_h'].to_f.mm
                max_box_top = [max_box_top, stop_z-drawer_box_top_clearance].min if min_bz < stop_top && max_box_top > stop_z
              end
              bz = min_bz
              box_h = max_box_top-bz
              raise ModelingRules::Invalid, 'Hộc quá thấp hoặc cấn xà đón; chỉnh cao khoang, xà hoặc số tầng.' if box_h <= drawer_bottom_offset+drawer_bottom_t+5.mm''')
a=s.index('              make_dr_board.call("Vách Ngăn Kéo Trái')
b=s.index('\n      \n              dr_inst =',a)
s=s[:a]+'''              mode = p['drawer_bottom_mode']
              overlay_bottom = mode == 'Phủ dưới'
              bottom_z = overlay_bottom ? bz : bz+drawer_bottom_offset
              side_z = overlay_bottom ? bz+drawer_bottom_t : bz
              end_z = mode == 'Âm hai bên' ? bottom_z+drawer_bottom_t : side_z
              side_h = bz+box_h-side_z
              end_h = bz+box_h-end_z
              make_dr_board.call("Vách Ngăn Kéo Trái #{i+1}", drawer_box_t, box_d, side_h, box_x, by, side_z)
              make_dr_board.call("Vách Ngăn Kéo Phải #{i+1}", drawer_box_t, box_d, side_h, box_x+box_w-drawer_box_t, by, side_z)
              make_dr_board.call("Đầu Ngăn Kéo #{i+1}", box_w-2*drawer_box_t, drawer_box_t, end_h, box_x+drawer_box_t, by, end_z)
              make_dr_board.call("Đuôi Ngăn Kéo #{i+1}", box_w-2*drawer_box_t, drawer_box_t, end_h, box_x+drawer_box_t, by+box_d-drawer_box_t, end_z)
              inset_x = overlay_bottom ? 0.mm : drawer_box_t/2.0
              inset_y = mode == 'Âm bốn phía' ? drawer_box_t/2.0 : 0.mm
              make_dr_board.call("Đáy Ngăn Kéo #{i+1}", box_w-2*inset_x, box_d-2*inset_y, drawer_bottom_t, box_x+inset_x, by+inset_y, bottom_z)
'''+s[b:]
s=s.replace('dr_inst.name = "Ngăn Kéo #{i+1}_DC"','dr_inst.name = "Ngăn Kéo Khoang #{c_idx+1} Cụm #{column_index+1} Tầng #{i+1}"')
a=s.index('\n        if truthy_param?(p, \'door_stop_rail\'')
s=s[:a]+'\n        end # drawer columns\n'+s[a:]
s=s.replace('create_horizontal_panel.call("Tấm Nóc Dưới", top_is_lot, top_w, start_top_x, d_top_bot, y_top_bot, z_junction - t)\n            create_board.call("Tấm Xà Đứng Trên"','create_horizontal_panel.call("Tấm Đáy Trên", bot_is_lot, bot_w, start_bot_x, d_top_bot, y_top_bot, z_junction - t)\n            create_board.call("Tấm Xà Đứng Trên"')
s=s.replace('create_board.call("Tấm Xà Ngang Trên", inner_w, beam_h, t, start_inner_x, y_inner + d_inner - beam_h, z_junction)','create_board.call("Xà Ngang Trên Sau", inner_w, beam_h, t, start_inner_x, y_inner + d_inner - beam_h, z_junction)\n            create_board.call("Xà Ngang Trên Trước", inner_w, beam_h, t, start_inner_x, y_inner+t, z_junction)')
s=s.replace('pts = [[t, 0.mm], [d_inner, 0.mm], [d_inner, h_inner_top], [0.mm, h_inner_top], [0.mm, beam_h], [t, beam_h]]','pts = [[t, beam_h], [t, t], [t+beam_h, t], [t+beam_h, 0.mm], [d_inner-beam_h, 0.mm], [d_inner-beam_h, t], [d_inner, t], [d_inner, h_inner_top], [0.mm, h_inner_top], [0.mm, beam_h]]')
p.write_text(s)
