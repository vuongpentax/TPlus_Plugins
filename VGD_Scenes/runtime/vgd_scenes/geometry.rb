# frozen_string_literal: true
module VGD
  module Scenes
    module Geometry
      def self.instance?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      def self.selection_paths(model)
        selected = model.selection.to_a.select { |e| instance?(e) && e.valid? }
        raise ArgumentError, 'Chọn ít nhất một Group hoặc Component trước.' if selected.empty?
        raise ArgumentError, 'Chỉ chọn Group/Component; bỏ geometry rời khỏi vùng chọn.' unless selected.length == model.selection.length
        prefix = model.active_path || []
        selected.map { |entity| (prefix + [entity]).map(&:persistent_id) }
      end

      def self.resolve(model, ids)
        transform = Geom::Transformation.new
        path = []
        entities = model.entities
        ids.each do |pid|
          entity = entities.find { |item| item.respond_to?(:persistent_id) && item.persistent_id == pid.to_i }
          raise ArgumentError, 'Đối tượng nguồn đã bị xóa hoặc thay thế. Hãy tạo bộ scene mới.' unless entity && instance?(entity)
          path << entity
          transform = transform * entity.transformation
          entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
        end
        raise ArgumentError, 'Không có đối tượng nguồn' if path.empty?
        [path, transform, entities]
      end

      def self.target(model, paths, axis_mode)
        resolved = paths.map { |ids| resolve(model, ids) }
        points = resolved.flat_map do |path, transform, _entities|
          bounds = path.last.definition.bounds
          raise ArgumentError, 'Đối tượng rỗng không có hình học.' if bounds.empty?
          (0..7).map { |index| bounds.corner(index).transform(transform) }
        end
        frame = axis_mode == 'local' ? resolved.first[1] : Geom::Transformation.new
        axes = [frame.xaxis.normalize, frame.yaxis.normalize, frame.zaxis.normalize]
        # Orthogonal axes retain mirrored orientation without scaling the camera vectors.
        raise ArgumentError, 'Transform không hợp lệ hoặc có trục suy biến.' if axes.any? { |v| v.length < 1e-9 }
        if axes[0].dot(axes[1]).abs > 0.001 || axes[0].dot(axes[2]).abs > 0.001 || axes[1].dot(axes[2]).abs > 0.001
          raise ArgumentError, 'Transform bị shear; chọn trục mô hình để tạo view.'
        end
        center = Geom::BoundingBox.new.add(points).center
        leaf = resolved.first[0].last
        name = leaf.name.to_s.strip
        name = leaf.definition.name.to_s.strip if name.empty? && leaf.respond_to?(:definition)
        name = 'Đối tượng' if name.empty?
        name = "#{name}_Cụm#{paths.length}" if paths.length > 1
        { points: points, axes: axes, center: center, name: name, resolved: resolved, paths: paths }
      end

      def self.vector(axes, coords)
        Geom::Vector3d.new(
          axes.each_with_index.inject(0.0) { |sum, (v, i)| sum + v.x * coords[i] },
          axes.each_with_index.inject(0.0) { |sum, (v, i)| sum + v.y * coords[i] },
          axes.each_with_index.inject(0.0) { |sum, (v, i)| sum + v.z * coords[i] }
        ).normalize
      end

      def self.view_vectors(target, kind, normal = nil)
        axes = target[:axes]
        coords, up = case kind
                     when 'FRONT' then [[0, 1, 0], [0, 0, 1]]
                     when 'BACK' then [[0, -1, 0], [0, 0, 1]]
                     when 'RIGHT' then [[-1, 0, 0], [0, 0, 1]]
                     when 'LEFT' then [[1, 0, 0], [0, 0, 1]]
                     when 'TOP' then [[0, 0, -1], [0, 1, 0]]
                     when 'BOTTOM' then [[0, 0, 1], [0, -1, 0]]
                     else [[-1, 1, -1], [0, 0, 1]]
                     end
        # SketchUp removes the half-space opposite the plane normal. Look from
        # that removed side toward the retained geometry, including after flip.
        direction = normal ? normal.normalize : vector(axes, coords)
        up_vector = vector(axes, up)
        up_vector = axes[1] if direction.cross(up_vector).length < 0.001
        up_vector = axes[0] if direction.cross(up_vector).length < 0.001
        right = direction.cross(up_vector).normalize
        { direction: direction, up: right.cross(direction).normalize, right: right }
      end

      def self.fit(model, target, kind, options, normal = nil)
        v = view_vectors(target, kind, normal)
        center = target[:center]
        projections = target[:points].map do |point|
          delta = point - center
          [delta.dot(v[:right]), delta.dot(v[:up]), delta.dot(v[:direction])]
        end
        ranges = (0..2).map { |axis| values = projections.map { |p| p[axis] }; [values.min, values.max] }
        width = [ranges[0][1] - ranges[0][0], 0.01].max
        height = [ranges[1][1] - ranges[1][0], 0.01].max
        depth = ranges[2][1] - ranges[2][0]
        aspect = options['width'].to_f / options['height']
        target_point = center.offset(v[:right], (ranges[0][0] + ranges[0][1]) / 2.0).offset(v[:up], (ranges[1][0] + ranges[1][1]) / 2.0)
        camera = Sketchup::Camera.new(target_point.offset(v[:direction].reverse, [depth * 2.0, 100.0].max), target_point, v[:up], false)
        camera.height = [height, width / aspect].max * (1.0 + options['margin'] / 100.0)
        camera.aspect_ratio = aspect
        model.active_view.camera = camera
        camera
      end

      def self.section(target, options)
        axis = options['section_axis']
        coords = axis == 'CUSTOM' ? %w[normal_x normal_y normal_z].map { |k| options[k] } : { 'X' => [1, 0, 0], 'Y' => [0, 1, 0], 'Z' => [0, 0, 1] }.fetch(axis)
        raise ArgumentError, 'Vector pháp tuyến không được bằng 0.' if coords.all? { |n| n.abs < 1e-9 }
        normal = vector(target[:axes], coords)
        center = target[:center]
        projections = target[:points].map { |point| (point - center).dot(normal) }
        distance = projections.min + (projections.max - projections.min) * options['section_percent'] / 100.0 + options['section_offset'] / 25.4
        point = center.offset(normal, distance)
        normal = normal.reverse if options['section_flip']
        [point, normal]
      end

      def self.fit_current(model, target, options)
        original = model.active_view.camera
        direction = (original.target - original.eye).normalize
        right = direction.cross(original.up).normalize
        up = right.cross(direction).normalize
        center = target[:center]
        projected = target[:points].map { |p| d = p - center; [d.dot(right), d.dot(up), d.dot(direction)] }
        aspect = options['width'].to_f / options['height']
        padding = 1.0 + options['margin'] / 100.0
        if original.perspective?
          # Query after assigning the aspect: SketchUp may measure FOV on either axis.
          probe = Scenes.camera_copy(original); probe.aspect_ratio = aspect
          tangent = Math.tan(probe.fov * Math::PI / 360.0)
          tan_y = probe.fov_is_height? ? tangent : tangent / aspect
          tan_x = tan_y * aspect
          distance = projected.map { |x,y,z| [x.abs * padding / tan_x - z, y.abs * padding / tan_y - z, 0.01 - z].max }.max
          camera = Sketchup::Camera.new(center.offset(direction.reverse, distance), center, up, true)
          camera.aspect_ratio = aspect; camera.fov = probe.fov
        else
          min_x, max_x = projected.map { |p| p[0] }.minmax
          min_y, max_y = projected.map { |p| p[1] }.minmax
          width = max_x - min_x
          height = max_y - min_y
          depth = projected.map { |p| p[2] }.minmax.inject { |a,b| b-a }
          target_point = center.offset(right, (min_x + max_x) / 2.0).offset(up, (min_y + max_y) / 2.0)
          camera = Sketchup::Camera.new(target_point.offset(direction.reverse, [depth * 2, 100.0].max), target_point, up, false)
          camera.height = [height, width / aspect, 0.01].max * padding
          camera.aspect_ratio = aspect
        end
        model.active_view.camera = camera
        camera
      end

      def self.local_plane(transform, point, normal)
        # Plane normals are covectors: world -> local uses T transpose.
        # Inverse-transforming a vector fails with nonuniform scale/mirroring.
        local_normal = Geom::Vector3d.new(normal.dot(transform.xaxis), normal.dot(transform.yaxis), normal.dot(transform.zaxis)).normalize
        [point.transform(transform.inverse), local_normal]
      end

      def self.validate_section_target(target)
        target[:resolved].each do |path, _transform, _entities|
          raise ArgumentError, 'Mở khóa đối tượng trước khi tạo mặt cắt.' if path.any? { |item| item.locked? }
          if path[0...-1].any? { |item| item.definition.instances.length > 1 }
            raise ArgumentError, 'Group/Component cha có nhiều bản sao. Make Unique đối tượng cha trước khi tạo mặt cắt bên trong.'
          end
        end
      end

      def self.unique_section_target(model, target, opts, snapshot)
        target[:resolved].each do |path, _transform, _entities|
          leaf = path.last
          next unless leaf.definition.instances.length > 1
          label = leaf.name.to_s.empty? ? leaf.definition.name : leaf.name
          leaf.make_unique
          leaf.name = label if leaf.name.to_s.empty?
          snapshot.collect_entities(leaf.definition.entities, true)
        end
        target(model, target[:paths], opts['axis_mode'])
      end
    end
  end
end
