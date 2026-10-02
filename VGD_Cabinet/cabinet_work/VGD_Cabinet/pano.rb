# frozen_string_literal: true
module VGD_Cabinet
  module Modeling
    module_function
    def pano_sizes(width,height,p)
      b=p['pano_stile_width']; r=p['pano_rail_width']; m=p['pano_mid_rail']; n=p['pano_panel_count'].to_i
      opening_w=width-2*b
      opening_h=(height-2*r-(n-1)*m)/n
      raise ModelingRules::Invalid,'Cánh pano quá nhỏ cho bản khung/số ô đã chọn.' unless opening_w>1 && opening_h>1
      capture=p['pano_groove_depth']-p['pano_clearance']
      {opening_w:opening_w,opening_h:opening_h,panel_w:opening_w+2*capture,panel_h:opening_h+2*capture}
    end
    def profile_part(entities,name,points,axis,extrusion,material)
      group=entities.add_group; group.name=name; group.material=material
      face=group.entities.add_face(points)
      raise ModelingRules::Invalid,'Không tạo được tiết diện khung pano.' unless face
      normal=axis==:x ? face.normal.x : face.normal.z
      face.reverse! if normal<0
      face.pushpull(extrusion)
      group
    end
    def pano_rail(entities,name,x,z,width,depth,breadth,groove,gy,pt,bottom,top,bevel,lip,material)
      # Closed YZ profile with real straight panel grooves, and optional top back bevel.
      points=[[0,0]]
      points += [[gy,0],[gy,groove],[gy+pt,groove],[gy+pt,0]] if bottom
      points << [depth,0]
      if bevel
        points += [[depth,breadth-(depth-lip)],[lip,breadth]]
      else
        points << [depth,breadth]
      end
      points += [[gy+pt,breadth],[gy+pt,breadth-groove],[gy,breadth-groove],[gy,breadth]] if top
      points << [0,breadth]
      profile_part(entities,name,points.map { |y,v| [x,y,z+v] },:x,width,material)
    end
    def pano_front(entities,x,width,depth,height,p)
      sizes=pano_sizes(width.to_f*25.4,height.to_f*25.4,p)
      b=p['pano_stile_width'].mm; r=p['pano_rail_width'].mm; m=p['pano_mid_rail'].mm
      g=p['pano_groove_depth'].mm; c=p['pano_clearance'].mm; pt=p['pano_panel_thickness'].mm
      gy=(depth-pt)/2; n=p['pano_panel_count'].to_i; opening_h=sizes[:opening_h].mm
      frame=concept_material('VGD Khung Pano',[185,144,94]); panel=concept_material('VGD Pano',[205,169,120])
      left=[[x,0,0],[x+b,0,0],[x+b,gy,0],[x+b-g,gy,0],
            [x+b-g,gy+pt,0],[x+b,gy+pt,0],[x+b,depth,0],[x,depth,0]]
      right=left.map { |px,y,z| [2*x+width-px,y,z] }
      profile_part(entities,'Đố Pano Trái',left,:z,height,frame)
      profile_part(entities,'Đố Pano Phải',right,:z,height,frame)
      pano_rail(entities,'Thanh Pano Dưới',x+b,0,width-2*b,depth,r,g,gy,pt,false,true,false,0,frame)
      pano_rail(entities,'Thanh Pano Trên',x+b,height-r,width-2*b,depth,r,g,gy,pt,true,false,p['front_bevel'],p['bevel_lip'].mm,frame)
      n.times do |index|
        z=r+index*(opening_h+m)
        group=entities.add_group; group.name="Pano #{index+1}"; group.material=panel
        concept_box(group.entities,x+b-g+c,gy,z-g+c,sizes[:panel_w].mm,pt,sizes[:panel_h].mm,panel)
        if index<n-1
          pano_rail(entities,"Thanh Giữa Pano #{index+1}",x+b,z+opening_h,width-2*b,depth,m,g,gy,pt,true,true,false,0,frame)
        end
      end
    end
  end
end
