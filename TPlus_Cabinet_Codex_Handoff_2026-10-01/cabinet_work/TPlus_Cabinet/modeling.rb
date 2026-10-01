# frozen_string_literal: true
module TPlus_Cabinet
  module Modeling
    module_function
    def metal_glass?(p)
      p['door_style'] == 'Kính khung kim loại'
    end
    def door_depth_mm(p)
      metal_glass?(p) && p['opt_door'] != 'Không Cánh' && !p['is_full_drawer'] ? p['metal_frame_depth'].to_f : p['t'].to_f
    end
    def concept_material(name, rgb, alpha=1.0)
      materials = Sketchup.active_model.materials
      # Reuse existing swatches without overwriting colors edited by the user.
      return materials[name] if materials[name]
      legacy = name.sub('T+ Khung ', 'T+ Concept | Khung | ').sub('T+ Kính ', 'T+ Concept | Kính | ')
      if materials[legacy]
        material = materials[legacy]
        material.name = name
        return material
      end
      material = materials.add(name)
      material.color = Sketchup::Color.new(*rgb)
      material.alpha = alpha
      material
    end
    def concept_box(entities, x, y, z, w, depth, height, material)
      face = entities.add_face([[x,y,z],[x+w,y,z],[x+w,y+depth,z],[x,y+depth,z]])
      raise 'Không dựng được phần cánh concept.' unless face
      face.reverse! if face.normal.z < 0
      face.pushpull(height)
    end
    def door_front(entities, x, width, depth, height, p)
      return front_solid(entities,x,width,depth,height,p) unless metal_glass?(p)
      border = p['metal_frame_width'].to_f.mm
      glass_t = p['glass_thickness'].to_f.mm
      if width <= 2*border + 0.1.mm || height <= 2*border + 0.1.mm
        raise ModelingRules::Invalid, 'Bản khung quá lớn: cánh phải còn ô kính rộng và cao lớn hơn 0,1 mm.'
      end
      raise ModelingRules::Invalid, 'Kính không được dày hơn khung.' if glass_t > depth
      metal_colors = {'Đen'=>[40,40,40], 'Champagne'=>[190,166,124], 'Inox'=>[180,185,190]}
      glass_colors = {'Trong'=>[210,232,235], 'Trà'=>[142,105,73], 'Xám'=>[115,128,140]}
      metal = concept_material("T+ Khung #{p['metal_finish']}",metal_colors.fetch(p['metal_finish']))
      glass = concept_material("T+ Kính #{p['glass_finish']}",glass_colors.fetch(p['glass_finish']),0.30)
      # Two material groups only. Four simple bars, without overlapping corners.
      frame_group = entities.add_group
      frame_group.name = 'Khung Kim Loại'
      frame_group.material = metal
      concept_box(frame_group.entities,x,0,0,border,depth,height,metal)
      concept_box(frame_group.entities,x+width-border,0,0,border,depth,height,metal)
      concept_box(frame_group.entities,x+border,0,0,width-2*border,depth,border,metal)
      concept_box(frame_group.entities,x+border,0,height-border,width-2*border,depth,border,metal)
      glass_group = entities.add_group
      glass_group.name = 'Kính'
      glass_group.material = glass
      concept_box(glass_group.entities,x+border,(depth-glass_t)/2,border,width-2*border,glass_t,height-2*border,glass)
    end
    def front_solid(entities, x, dx, dy, dz, p)
      if p['front_bevel']
        cut = dy - p['bevel_lip'].to_f.mm
        raise ModelingRules::Invalid, 'Chiều cao mặt quá nhỏ để vát 45°.' unless dz > cut
        pts = [[x,0,0],[x,dy,0],[x,dy,dz-cut],[x,p['bevel_lip'].to_f.mm,dz],[x,0,dz]]
        f = entities.add_face(pts)
        raise 'Không dựng được tiết diện vát.' unless f
        f.reverse! if f.normal.x < 0
        f.pushpull(dx)
      else
        f = entities.add_face([[x,0,0],[x+dx,0,0],[x+dx,dy,0],[x,dy,0]])
        raise 'Không dựng được mặt tấm.' unless f
        f.reverse! if f.normal.z < 0
        f.pushpull(dz)
      end
    end
    def clean_tags(entities)
      model = Sketchup.active_model
      entities.each do |e|
        if e.is_a?(Sketchup::ConstructionLine)
          e.layer = model.layers['T+_KY HIEU'] || model.layers.add('T+_KY HIEU')
        elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          front = e.name.to_s.start_with?('Mặt Ngăn Kéo') || (e.respond_to?(:definition) && e.definition.name.to_s.start_with?('Cánh'))
          e.layer = front ? (model.layers['T+_CANH'] || model.layers.add('T+_CANH')) : model.layers[0]
          clean_tags(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities)
        elsif e.respond_to?(:layer=)
          e.layer = model.layers[0]
        end
      end
    end
    def draw(entities, p)
      widths = ModelingRules.widths(p)
      if p['module_mode'] == 'Độc lập'
        x = 0.0
        widths.each_with_index do |width, index|
          group = entities.add_group
          group.name = "Module #{format('%02d',index+1)} — #{width.round(1)} mm"
          child = p.merge('w'=>width, 'module_mode'=>'Chung vách')
          child['opt_left_side'] = 'Vuông' if index > 0
          child['opt_right_side'] = 'Vuông' if index < widths.size-1
          GeometryEngine.draw(group.entities, child)
          group.transform!(Geom::Transformation.translation([x.mm,0,0]))
          x += width
        end
      else
        GeometryEngine.draw(entities,p)
      end
      clean_tags(entities)
    end
  end
end
