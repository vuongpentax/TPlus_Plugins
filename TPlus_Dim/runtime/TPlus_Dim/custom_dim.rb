# encoding: UTF-8
require 'securerandom'
module TPlus
  module Dim
    module CustomDim
      extend self
      DICT = 'TPlus_Dim_Custom'.freeze unless const_defined?(:DICT, false)

      def kind(entity)
        entity.get_attribute(DICT, 'kind', nil) if entity.respond_to?(:get_attribute)
      end

      def view?(entity); %w[dimension text].include?(kind(entity)); end
      def source?(entity); kind(entity) == 'source'; end

      def collection(entity)
        parent = entity.parent
        parent.respond_to?(:entities) ? parent.entities : parent
      end

      def partner(entity)
        id = entity.get_attribute(DICT, 'pair', nil)
        return nil unless id
        matching = collection(entity).select do |candidate|
          candidate.valid? && candidate != entity &&
            candidate.get_attribute(DICT, 'pair', nil) == id &&
            (source?(entity) ? view?(candidate) : source?(candidate))
        end
        if source?(entity)
          matching.min_by(&:persistent_id)
        else
          native=matching.first
          return nil unless native
          displays=collection(entity).select { |e| e.valid? && view?(e) && e.get_attribute(DICT,'pair',nil)==id }
          displays.min_by(&:persistent_id)==entity ? native : nil
        end
      end

      def redundant_source?(entity)
        source?(entity) && partner(entity)
      end

      def source(entity); view?(entity) ? partner(entity) : entity; end

      def unit_value(length, config)
        divisor = {'mm'=>1.0/25.4,'cm'=>10.0/25.4,'m'=>1000.0/25.4,'inch'=>1.0,'ft'=>12.0}.fetch(config['unit'])
        value = format("%.#{config['precision']}f", length/divisor)
        config['show_unit'] ? "#{value} #{config['unit']}" : value
      end

      def scaled(vector, distance)
        result = vector.clone
        result.length = distance
        result
      end

      def endpoints(native)
        [native.start[1], native.end[1]]
      end

      def axes(native, model)
        if native.is_a?(Sketchup::DimensionLinear)
          a,b = endpoints(native); delta=b-a; y=native.offset_vector
          y = model.active_view.camera.up if y.length < 1.0e-9
          y.normalize!
          projection = Geom::Vector3d.new(y.x*delta.dot(y), y.y*delta.dot(y), y.z*delta.dot(y))
          x=delta-projection
          raise ArgumentError, 'Dim có chiều đo bằng 0; không chuyển sang dim T+.' if x.length < 1.0e-9
          x.normalize!
          z=x.cross(y); z.normalize!
          [x,y,z]
        else
          camera=model.active_view.camera
          transform=model.edit_transform.inverse
          x=camera.xaxis.transform(transform); y=camera.up.transform(transform)
          x.normalize!; y.normalize!; z=x.cross(y); z.normalize!
          [x,y,z]
        end
      end

      def label(native, config, length)
        text=native.text.to_s
        text.empty? ? unit_value(length,config) : text
      end

      def snapshot(native, config, frame)
        if native.is_a?(Sketchup::DimensionLinear)
          a,b=endpoints(native); x,y,z=frame
          delta=b-a; offset=native.offset_vector
          q1=a+offset
          q2=q1+Geom::Vector3d.new(x.x*delta.dot(x),x.y*delta.dot(x),x.z*delta.dot(x))
          [a.to_a,b.to_a,offset.to_a,native.text.to_s,native.arrow_type, config, q1.to_a,q2.to_a]
        elsif native.is_a?(Sketchup::DimensionRadial)
          [native.leader_points.map(&:to_a),native.arc_curve.radius,native.text.to_s,native.arrow_type,config]
        else
          [native.point.to_a,native.vector.to_a,native.text.to_s,native.arrow_type,config]
        end
      end

      def arrow(entities, point, direction, frame, size, type, material)
        return if type == Sketchup::Dimension::ARROW_NONE
        y,z=frame[1],frame[2]
        if type == Sketchup::Dimension::ARROW_DOT
          dot=entities.add_group
          dot.set_attribute(DICT,'kind','geometry')
          center=Geom::Point3d.new(point.to_a.map { |v| v*1000.0 })
          circle=dot.entities.add_circle(center,z,size*120.0,16)
          face=dot.entities.add_face(circle)
          face.material=face.back_material=material if face
          dot.entities.each { |e| e.hidden=true if e.is_a?(Sketchup::Edge) }
          dot.transformation=Geom::Transformation.scaling(0.001)
        elsif type == Sketchup::Dimension::ARROW_SLASH
          diagonal=direction+y; diagonal.normalize!
          line(entities,point-scaled(diagonal,size*0.25),point+scaled(diagonal,size*0.25),frame,size,material)
        else
          tip=point+scaled(direction,size*0.45)
          left=tip+scaled(y,size*0.14); right=tip-scaled(y,size*0.14)
          if type == Sketchup::Dimension::ARROW_CLOSED
            filled_face(entities,[point,left,right],material)
          else
            line(entities,left,point,frame,size,material)
            line(entities,point,right,frame,size,material)
          end
        end
      end

      def line(entities,a,b,frame,size,material)
        direction=b-a
        return if direction.length<1.0e-9
        side=direction.cross(frame[2])
        return if side.length<1.0e-9
        side.length=size*0.015
        # Filled ribbons preserve color without changing the model's global edge mode.
        filled_face(entities,[a+side,b+side,b-side,a-side],material)
      end

      def filled_face(entities,points,material)
        group=entities.add_group
        group.set_attribute(DICT,'kind','geometry')
        large=points.map { |p| Geom::Point3d.new(p.to_a.map { |v| v*1000.0 }) }
        face=group.entities.add_face(large)
        raise ArgumentError, 'SketchUp không dựng được mặt đường dim.' unless face
        face.material=face.back_material=material
        group.entities.each { |e| e.hidden=true if e.is_a?(Sketchup::Edge) }
        group.transformation=Geom::Transformation.scaling(0.001)
      end

      def render(view, native, config, material)
        frame=view.get_attribute(DICT,'axes').map { |v| Geom::Vector3d.new(v) }
        height=config['size_pt'].to_f/72.0
        position=config['position']
        if position=='keep' && native.is_a?(Sketchup::DimensionLinear)
          position={Sketchup::DimensionLinear::ALIGNED_TEXT_ABOVE=>'above',Sketchup::DimensionLinear::ALIGNED_TEXT_CENTER=>'center',Sketchup::DimensionLinear::ALIGNED_TEXT_OUTSIDE=>'outside'}[native.aligned_text_position] || 'above'
        end
        entities=view.entities
        # Build first in a temporary child. Replace the old display only after success.
        display=entities.add_group
        display.set_attribute(DICT,'kind','geometry')
        display.material=material
        geometry=display.entities
        x,y,z=frame
        if native.is_a?(Sketchup::DimensionLinear)
          a,b=endpoints(native); delta=b-a; q1=a+native.offset_vector
          q2=q1+Geom::Vector3d.new(x.x*delta.dot(x),x.y*delta.dot(x),x.z*delta.dot(x))
          distance=q1.distance(q2)
          line(geometry,a,q1,frame,height,material)
          line(geometry,b,q2,frame,height,material)
          center=Geom::Point3d.linear_combination(0.5,q1,0.5,q2)
          text=label(native,config,distance)
          location=center+scaled(y,height*0.35)
          type=native.arrow_type
          arrow(geometry,q1,x,frame,height,type,material)
          arrow(geometry,q2,x.reverse,frame,height,type,material)
        elsif native.is_a?(Sketchup::DimensionRadial)
          points=native.leader_points
          line(geometry,points[0],points[1],frame,height,material)
          text=label(native,config,native.arc_curve.radius)
          # Preserve the native label; never infer radius/diameter just from a full circle.
          line(geometry,points[1],points[2],frame,height,material) if text.match?(/\A\s*(DIA|DIAM|Ø|⌀)/i)
          center=points[0]; location=center+scaled(y,height*0.35)
          q1=q2=nil
          arrow(geometry,points[1],points[1].vector_to(points[0]).normalize,frame,height,native.arrow_type,material)
        else
          center=native.point+native.vector; location=center
          line(geometry,native.point,center,frame,height,material) if native.vector.length>1.0e-9
          text=native.text.to_s; q1=q2=nil
          arrow(geometry,native.point,native.vector.normalize,frame,height,native.arrow_type,material) if native.vector.length>1.0e-9
        end
        letters=geometry.add_group
        letters.set_attribute(DICT,'kind','geometry')
        FontBook.draw(letters.entities,text,config,material)
        bounds=letters.bounds
        width=bounds.width
        # Align glyph baseline/center in the dimension plane.
        shift=Geom::Transformation.translation([-bounds.center.x,-bounds.min.y,0])
        location=center if position=='center'
        location=q2+scaled(x,width*0.6+height) if position=='outside' && q2
        letters.transformation=Geom::Transformation.axes(location,x,y,z)*shift
        if q1 && q2
          if position=='center' && width+height < distance
            line(geometry,q1,center-scaled(x,width*0.5+height*0.2),frame,height,material)
            line(geometry,center+scaled(x,width*0.5+height*0.2),q2,frame,height,material)
          else
            line(geometry,q1,q2,frame,height,material)
          end
        end
        geometry.each do |e|
          e.material=material if e.respond_to?(:material=)
          e.hidden=true if e.is_a?(Sketchup::Edge) && !e.is_a?(Sketchup::Face)
        end
        entities.to_a.each { |e| e.erase! if e != display }
        view.set_attribute(DICT,'signature',JSON.generate(snapshot(native,config,frame)))
        view.set_attribute(DICT,'config',JSON.generate(config))
        view.set_attribute(DICT,'state','linked')
        native.hidden=true
        view
      rescue StandardError
        display.erase! if display && display.valid?
        raise
      end

      def convert(native, config, material, model)
        return nil if native.is_a?(Sketchup::Text) && !native.has_leader?
        view=partner(native) if source?(native)
        original_hidden=native.hidden?
        created=false
        unless view
          view=collection(native).add_group
          created=true
          view.name=native.is_a?(Sketchup::Text) ? 'T+ Text' : 'T+ Dim'
          pair=SecureRandom.uuid
          view.set_attribute(DICT,'kind',native.is_a?(Sketchup::Text) ? 'text' : 'dimension')
          view.set_attribute(DICT,'pair',pair)
          view.set_attribute(DICT,'axes',axes(native,model).map(&:to_a))
          view.hidden=native.hidden?
          native.set_attribute(DICT,'original_hidden',native.hidden?)
          native.set_attribute(DICT,'kind','source')
          native.set_attribute(DICT,'pair',pair)
        end
        # Recompute the plane after endpoint/offset edits; preserve Text's initial plane.
        view.make_unique if view.definition.instances.length > 1
        view.set_attribute(DICT,'axes',axes(native,model).map(&:to_a)) if native.is_a?(Sketchup::DimensionLinear)
        render(view,native,config,material)
        view.layer=native.layer
        view.material=material
        view
      rescue StandardError
        if created
          view.erase! if view && view.valid?
          native.delete_attribute(DICT) if native && native.valid?
          native.hidden=original_hidden if native && native.valid?
        end
        raise
      end

      def erase(entity)
        other=partner(entity)
        other.erase! if other && other.valid?
        entity.erase! if entity.valid?
      end

      def restore(native)
        view=partner(native)
        view.erase! if view && view.valid?
        native.hidden=native.get_attribute(DICT,'original_hidden',false)
        native.delete_attribute(DICT)
        native
      end

      def collections(model)
        [model.entities]+model.definitions.reject { |d| d.instances.any? { |i| view?(i) || kind(i)=='geometry' || i.locked? } }.map(&:entities)
      end

      def updates(model)
        actions=[]
        collections(model).each do |entities|
          entities.each do |entity|
            next unless entity.valid?
            if view?(entity)
              next if entity.locked?
              native=partner(entity)
              unless native
                actions << [:orphan,entity] unless entity.get_attribute(DICT,'state')=='orphan'
                next
              end
              config=JSON.parse(entity.get_attribute(DICT,'config'))
              frame=entity.get_attribute(DICT,'axes').map { |v| Geom::Vector3d.new(v) }
              signature=JSON.generate(snapshot(native,config,frame))
              actions << [:render,entity,native,config] if signature != entity.get_attribute(DICT,'signature')
            elsif source?(entity) && !partner(entity)
              actions << [:restore,entity]
            end
          end
        end
        actions
      end

      def refresh(model, actions)
        actions.each do |action,view,native,config|
          next unless view.valid?
          case action
          when :render
            color=native.is_a?(Sketchup::Text) ? config['text_color'] : config['dim_color']
            material=native.material
            material ||= Engine.color_material(model,color,'DIM') if config['change_color'] || native.is_a?(Sketchup::Text)
            convert(native,config,material,model)
          when :restore
            view.hidden=view.get_attribute(DICT,'original_hidden',false)
            view.delete_attribute(DICT)
          when :orphan
            view.set_attribute(DICT,'state','orphan')
            puts '[T+ Dim] Dim T+ mất nguồn đo; giữ hình hiển thị, cần liên kết/vẽ lại.'
          end
        end
      end
    end
  end
end
